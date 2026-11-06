-- ============================================================================
-- CMANDILI / Amana — Recherche de plats tolérante aux fautes (pg_trgm)
--
-- Appliquer avec
--   supabase db query --linked --file supabase/migrations/20261106120000_recherche_plats_floue.sql
--   supabase migration repair --status applied 20261106120000 --linked
-- Ne pas passer par `supabase db push`.
--
-- ── POURQUOI ────────────────────────────────────────────────────────────────
-- Les deux fonctions IA cherchaient les plats par sous-chaîne exacte
-- (ILIKE '%mot%' ou une regex). « calzone » ne trouvait pas un plat saisi
-- « calzine », et un mot-clé collé (« malfouf thon et calzone ») ne trouvait
-- rien du tout. Le chat remplissait alors le carrousel avec les 20 plats les
-- moins chers (koucha, eau minérale...).
--
-- ── CE QUE FAIT CE FICHIER ──────────────────────────────────────────────────
--   1. Active pg_trgm et unaccent dans le schéma `extensions`.
--   2. public.search_normalize(text) : minuscules, sans accents, ponctuation
--      remplacée par des espaces, espaces en trop retirés. IMMUTABLE (enveloppe
--      unaccent avec son dictionnaire qualifié) pour pouvoir l'indexer.
--   3. Deux index GIN trigrammes sur vendor_items : le nom brut et le nom
--      normalisé. À 444 lignes le planificateur lit la table en entier de
--      toute façon ; les index servent quand le catalogue grandira.
--   4. public.search_dishes(...) : UN plat demandé -> les plats disponibles qui
--      lui correspondent, avec un score. Utilisée par ai-chat et ai-search.
--
-- ── RÈGLE DE CORRESPONDANCE ─────────────────────────────────────────────────
-- La demande et chaque plat sont normalisés puis coupés en mots. Les mots
-- outils (et, w, de, au, la...) sont ignorés. Un plat correspond si CHAQUE mot
-- de la demande ressemble à un mot de son nom ou de sa section de menu :
--   mot identique                              -> 1
--   mot de la demande contenu dans un mot du plat (≥ 3 lettres) -> 0,95
--   sinon similarity() de pg_trgm entre les deux mots
-- et le plus mauvais de ces scores doit atteindre p_threshold (0,4 par
-- défaut). « malfouf thon » trouve donc « Malfouf Thon » mais pas
-- « Malfouf Jambon » ni « Sandwich Thon ». similarity('calzone','calzine')
-- vaut 0,45. La comparaison se fait mot à mot et non sur la phrase entière :
-- la phrase entière noie une faute d'une lettre dans les autres mots du nom.
--
-- p_match_description : un mot peut aussi être trouvé tel quel dans la
--   description (score 0,5). ai-search l'active (comportement d'avant) ;
--   ai-chat non, pour ne montrer que des plats dont le NOM correspond.
-- p_ignore_unknown_words : un mot qui ne ressemble à aucun plat disponible du
--   catalogue est ignoré au lieu de tout bloquer. Sert au mode dégradé (sans
--   IA), qui cherche directement dans la phrase de l'utilisateur :
--   « n7eb pizza » -> « n7eb » n'existe dans aucun plat -> on cherche « pizza ».
-- p_open_only : le chat ne montre que les restaurants ouverts ; la Recherche
--   IA garde les fermés (affichés grisés, après les ouverts).
-- Le budget et les filtres épicé / végétarien sont appliqués ici, sur `price`
-- comme les recherches existantes.
--
-- ── DROITS ──────────────────────────────────────────────────────────────────
-- search_dishes : authenticated et service_role seulement (les fonctions
-- Edge appellent avec la clé service_role).
-- search_normalize garde le EXECUTE par défaut : l'index l'évalue à chaque
-- INSERT/UPDATE de vendor_items, quel que soit le rôle qui écrit (app
-- partenaire, admin, triggers). Le retirer à anon/authenticated ferait
-- échouer l'ajout d'un article par un partenaire.
-- ============================================================================

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- ── 1. Normalisation ────────────────────────────────────────────────────────

create or replace function public.search_normalize(p_text text)
returns text
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select btrim(regexp_replace(
           lower(extensions.unaccent('extensions.unaccent'::regdictionary, p_text)),
           '[[:space:][:punct:]]+', ' ', 'g'))
$$;

comment on function public.search_normalize(text) is
  'Minuscules, sans accents, ponctuation -> espace. IMMUTABLE pour les index trigrammes. Voir 20261106120000.';

-- ── 2. Index trigrammes ─────────────────────────────────────────────────────

create index if not exists vendor_items_name_trgm_idx
  on public.vendor_items using gin (name extensions.gin_trgm_ops);

create index if not exists vendor_items_name_norm_trgm_idx
  on public.vendor_items using gin (public.search_normalize(name) extensions.gin_trgm_ops);

-- ── 3. Recherche d'un plat ──────────────────────────────────────────────────

create or replace function public.search_dishes(
  p_query                text,
  p_max_price            numeric default null,
  p_min_price            numeric default null,
  p_spicy                boolean default null,
  p_vegetarian           boolean default null,
  p_open_only            boolean default true,
  p_match_description    boolean default false,
  p_ignore_unknown_words boolean default false,
  p_threshold            real    default 0.4,
  p_limit                integer default 20
)
returns table (
  id                           uuid,
  name                         text,
  description                  text,
  price                        numeric,
  discount_price               numeric,
  image_url                    text,
  category                     text,
  is_spicy                     boolean,
  is_vegetarian                boolean,
  preparation_time             integer,
  restaurant_id                uuid,
  restaurant_name              text,
  restaurant_image_url         text,
  restaurant_rating            numeric,
  restaurant_delivery_time_min integer,
  restaurant_delivery_fee      numeric,
  restaurant_is_open           boolean,
  score                        real
)
language sql
stable
set search_path = ''
as $$
  with
  -- Les mots de la demande, normalisés, sans mots outils.
  query_words as (
    select distinct w
    from unnest(string_to_array(public.search_normalize(coalesce(p_query, '')), ' ')) as w
    where w <> ''
      and (length(w) >= 2 or w ~ '^[0-9]+$')
      and w <> all (array[
        -- français
        'et', 'ou', 'de', 'du', 'des', 'la', 'le', 'les', 'un', 'une', 'au',
        'aux', 'avec', 'en', 'pour', 'je', 'veux', 'voudrais', 'svp', 'stp',
        -- derja (latin)
        'w', 'wala', 'walla', 'el', 'fi', 'bel', 'bil', 'mta3', 'mte3',
        'n7eb', 'nheb', 'n7ebb', 'nhebb', 'aatini', 'a3tini', 'jibli',
        -- anglais
        'and', 'or', 'the', 'an', 'of', 'with', 'want', 'please',
        -- arabe
        'و', 'في', 'من'
      ])
  ),
  -- Chaque plat disponible et ses mots (nom + section du menu).
  dish as (
    select fi.id, fi.name, fi.description, fi.price, fi.discount_price,
           fi.image_url, fi.category, fi.is_spicy, fi.is_vegetarian,
           fi.preparation_time, fi.restaurant_id,
           r.name              as r_name,
           r.image_url         as r_image_url,
           r.rating            as r_rating,
           r.delivery_time_min as r_delivery_time_min,
           r.delivery_fee      as r_delivery_fee,
           r.is_open           as r_is_open,
           string_to_array(
             public.search_normalize(fi.name || ' ' || coalesce(fi.category, '')),
             ' ') as words,
           case when p_match_description
                then public.search_normalize(coalesce(fi.description, ''))
           end as description_norm
    from public.food_items fi
    join public.restaurants r on r.id = fi.restaurant_id
    where fi.is_available
  ),
  -- Score de chaque mot de la demande contre chaque plat.
  pair as (
    select d.id, q.w,
           greatest(
             (select max(case
                           when hw = q.w then 1.0
                           when length(q.w) >= 3 and position(q.w in hw) > 0 then 0.95
                           else extensions.similarity(q.w, hw)
                         end)
              from unnest(d.words) as hw),
             case when d.description_norm is not null
                       and length(q.w) >= 3
                       and position(q.w in d.description_norm) > 0
                  then 0.5 else 0 end
           )::real as s
    from dish d
    cross join query_words q
  ),
  -- Les mots qui comptent : tous, ou seulement ceux qui ressemblent à au moins
  -- un plat du catalogue en mode p_ignore_unknown_words.
  needed as (
    select q.w
    from query_words q
    where not p_ignore_unknown_words
       or exists (select 1 from pair p where p.w = q.w and p.s >= p_threshold)
  ),
  scored as (
    select p.id, min(p.s) as worst, avg(p.s)::real as mean
    from pair p
    where p.w in (select w from needed)
    group by p.id
  )
  select d.id, d.name, d.description, d.price, d.discount_price, d.image_url,
         d.category, d.is_spicy, d.is_vegetarian, d.preparation_time,
         d.restaurant_id, d.r_name, d.r_image_url, d.r_rating,
         d.r_delivery_time_min, d.r_delivery_fee, d.r_is_open, s.mean
  from scored s
  join dish d on d.id = s.id
  where exists (select 1 from needed)
    and s.worst >= p_threshold
    and (not p_open_only or d.r_is_open)
    and (p_max_price is null or d.price <= p_max_price)
    and (p_min_price is null or d.price >= p_min_price)
    and (p_spicy is not true or d.is_spicy)
    and (p_vegetarian is not true or d.is_vegetarian)
  order by s.mean desc, d.r_is_open desc, d.price asc, d.id
  limit greatest(1, least(coalesce(p_limit, 20), 200))
$$;

comment on function public.search_dishes(text, numeric, numeric, boolean, boolean, boolean, boolean, boolean, real, integer) is
  'Un plat demandé -> plats disponibles correspondants (mot à mot, pg_trgm). Utilisée par ai-chat et ai-search. Voir 20261106120000.';

revoke all on function public.search_dishes(text, numeric, numeric, boolean, boolean, boolean, boolean, boolean, real, integer)
  from public, anon;
grant execute on function public.search_dishes(text, numeric, numeric, boolean, boolean, boolean, boolean, boolean, real, integer)
  to authenticated, service_role;
