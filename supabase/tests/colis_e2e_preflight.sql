-- ============================================================================
-- CMANDILI — Avant un test Colis de bout en bout : qui recevrait l'offre ?
--
-- LECTURE SEULE. Aucun BEGIN, aucune écriture, rien à annuler. À lancer dans
-- le SQL Editor JUSTE AVANT de passer la commande de test, puis à relancer
-- après si vous voulez voir la trace des offres.
--
-- POURQUOI. Une commande Colis part en cascade (waterfall) vers les livreurs
-- EN LIGNE situés dans un rayon de 7 km du point de ramassage, un à la fois,
-- 15 secondes chacun, du plus proche au plus loin. Tant qu'un vrai livreur est
-- en ligne près du point choisi, il peut recevoir l'offre avant le livreur de
-- test — et accepter une course qui n'existe pas.
--
-- Ce fichier ne change RIEN au dispatch. La requête 2 appelle la même fonction
-- que l'Edge Function, avec les mêmes paramètres, pour vous montrer la liste
-- exacte de ceux qui seraient sollicités. C'est un constat, pas un réglage.
--
-- ⚠️ À MODIFIER : les coordonnées du point de RAMASSAGE que vous allez saisir
-- dans l'app client. Elles n'apparaissent qu'une fois, dans la requête 2.
-- Par défaut : la dernière position connue du livreur de test.
-- ============================================================================


-- ── 1. Qui est en ligne, maintenant, partout ───────────────────────────────
-- Un livreur « en ligne » dont la position date d'hier est en ligne quand
-- même pour la base : c'est is_online qui compte, pas la fraîcheur du GPS.
-- La colonne position_datee_de_minutes dit s'il est vraiment là.
select p.full_name                                        as livreur,
       p.phone                                            as telephone,
       d.id                                               as driver_id,
       d.is_blocked                                       as bloque,
       round(extract(epoch from (now() - d.last_location_update)) / 60)
                                                          as position_datee_de_minutes,
       d.current_lat, d.current_lng,
       coalesce(w.status, 'active')                       as wallet,
       public.driver_is_verified(d.id)                    as verifie
  from public.drivers d
  left join public.profiles p on p.id = d.user_id
  left join public.wallets  w on w.user_id = d.user_id
 where d.is_online
 order by p.full_name;

-- Lecture : S'IL N'Y A QUE LE LIVREUR DE TEST, vous pouvez lancer le test.
-- Sinon, demandez aux autres de se mettre hors ligne, ou attendez — ne touchez
-- pas à leur is_online depuis le dashboard, ils sont peut-être en course.


-- ── 2. Qui recevrait réellement l'offre pour ce point de ramassage ─────────
-- Même fonction, même rayon (7 km, DRIVER_FANOUT_RADIUS_KM) que
-- supabase/functions/push-on-order-status. L'ordre de la liste est l'ordre des
-- offres : le premier est sollicité d'abord, 15 secondes, puis le suivant.
select row_number() over (order by c.distance_km) as rang_de_l_offre,
       p.full_name                                as livreur,
       p.phone                                    as telephone,
       round(c.distance_km::numeric, 2)           as distance_km
  from (values (35.6755183::double precision, 10.1082311::double precision)) as point(lat, lng),
       lateral public.nearby_online_drivers(point.lat, point.lng, 7) as c
  left join public.profiles p on p.id = c.user_id
 order by c.distance_km;

-- Lecture : CETTE liste est celle qui compte. Si elle ne contient que le
-- livreur de test, aucune offre ne peut partir ailleurs. Si elle est vide, le
-- livreur de test ne recevra rien — vérifiez la requête 3.


-- ── 3. Le livreur de test est-il prêt ? ────────────────────────────────────
-- Cinq conditions, et il faut les cinq pour recevoir une offre Colis.
select p.full_name                                  as livreur,
       d.id                                          as driver_id,
       d.is_online                                   as en_ligne,
       not d.is_blocked                              as non_bloque,
       (d.current_lat is not null and d.current_lng is not null)
                                                     as a_une_position,
       coalesce(w.status, 'active') = 'active'       as wallet_actif,
       public.driver_is_verified(d.id)               as verifie,
       -- Un jeton de notification : sans lui l'offre ne s'affiche pas, même
       -- si la base le considère éligible.
       exists (select 1 from public.device_tokens t where t.user_id = d.user_id)
                                                     as a_un_jeton_push,
       coalesce(public.platform_setting('driver_verification_required'), 'off')
                                                     as durcissement,
       coalesce(public.platform_setting('colis_proof_enforcement'), 'soft')
                                                     as preuves_colis
  from public.drivers d
  left join public.profiles p on p.id = d.user_id
  left join public.wallets  w on w.user_id = d.user_id
 where d.user_id = (select id from auth.users where email = 'ademcherif209+aymen@gmail.com');

-- Lecture : les six booléens doivent être true. `verifie` vaut true même sans
-- dossier tant que durcissement = off — c'est voulu, et c'est ce qui permet de
-- tester avec un compte sans CIN.


-- ── 4. APRÈS la commande : la trace des offres ─────────────────────────────
-- À relancer une fois le test terminé. Remonte les 5 derniers colis.
-- order_type = 'courier' : c'est la valeur réellement portée par les colis en
-- base (vérifié sur les 10 dernières commandes à colis), pas 'colis'.
select o.id,
       o.created_at,
       o.status,
       o.order_type,
       pd.full_name                      as livreur_assigne,
       o.assigned_driver_id,
       o.assignment_expires_at,
       array_length(o.passed_driver_ids, 1) as offres_refusees_ou_expirees,
       o.no_driver_notified_at           as aucun_livreur_a,
       o.driver_offer_distance_km,
       o.driver_offer_is_fallback
  from public.orders o
  left join public.drivers dr on dr.id = o.driver_id
  left join public.profiles pd on pd.id = dr.user_id
 where o.order_type = 'courier'
 order by o.created_at desc
 limit 5;

-- Lecture : passed_driver_ids liste ceux qui ont laissé passer l'offre. S'il
-- contient un vrai livreur, c'est qu'il était en ligne au moment du test —
-- l'offre lui a bien été présentée, et la requête 1 avait de quoi le dire.
