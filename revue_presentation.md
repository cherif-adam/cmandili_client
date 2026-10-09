# Revue de la présentation de soutenance — Amana

Relecture faite le 8 octobre 2026, en confrontant chaque affirmation des
36 slides et des notes de l'orateur au code réel : les quatre applications,
les 92 migrations Supabase, les 5 Edge Functions et le mémoire `ameenPFE.tex`
(149 pages).

**Méthode.** Rien n'est pris sur parole. Chaque verdict cite un fichier et un
numéro de ligne. Quand une migration redéfinit une fonction, c'est **la
dernière définition** qui fait foi, puisque les migrations s'appliquent dans
l'ordre des noms de fichiers. Quand je n'ai pas pu trouver de preuve dans le
dépôt, j'écris « non vérifiable » plutôt que de deviner.

**Deux remarques de forme.**
- `soutenance_amana.pdf` n'existe pas dans le dépôt : je n'ai donc pas pu
  contrôler le rendu visuel, seulement le contenu textuel fourni.
- Aucun fichier du projet n'a été modifié. Ce rapport est le seul fichier créé.

---

## 1. Tableau de synthèse

| # | Titre | Verdict | Raison courte |
|---|---|---|---|
| 1 | cover | ⚠️ | L'encadrant professionnel (M. Firas Mzoughi) figure sur la page de garde du mémoire mais pas sur la slide |
| 2 | plan | ✅ | — |
| 3 | d1 | ✅ | — |
| 4 | contexte | ⚠️ | « jusqu'à 30 % chez Glovo » : chiffre absent du mémoire et invérifiable depuis le dépôt |
| 5 | existant | ✅ | Conforme au tableau 1.1 du mémoire |
| 6 | problematique | ✅ | — |
| 7 | d2 | ✅ | — |
| 8 | solution | ✅ | 7 catégories de commerce + colis + facture : conforme |
| 9 | acteurs | ⚠️ | Le code couleur annoncé ne correspond pas aux couleurs réelles des applications |
| 10 | d3 | ✅ | — |
| 11 | cas | ✅ | Vue simplifiée assumée, conforme aux figures 2.1–2.4 |
| 12 | classes | ✅ | « 12 classes principales » annoncé comme vue simplifiée ; la figure 2.10 en compte 13 |
| 13 | archi | ⚠️ | La version de PostgreSQL n'est pas vérifiable depuis le dépôt |
| 14 | voyage | ❌ | « position tous les ~30 m » : le code filtre à **10 m** |
| 15 | d4 | ✅ | — |
| 16 | techno | ⚠️ | Même réserve sur « PostgreSQL 17.6 » ; le reste est exact |
| 17 | dispatch | ❌ | Le « palier 2 après 30 s » n'existe pas dans le code ; « livreurs libres » est inexact |
| 18 | argent | ⚠️ | « max 70 % » est la valeur **par défaut**, réglable de 1 à 99 % |
| 19 | securite | ❌ | « Les clés IA ne sont jamais dans l'application installée » : la clé OpenRouter est embarquée |
| 20 | ia | ✅ | JWT bien vérifié (au niveau plateforme), pas de recherche vectorielle : conforme |
| 21 | d5 | ✅ | — |
| 22 | client | ✅ | 32 écrans, 3 langues : exact |
| 23 | livpart | ⚠️ | « l'application Livreur, en vert » : elle est bleue dans le code |
| 24 | admin | ⚠️ | « 16 routes API, toutes protégées » : 15 sur 16 |
| 25 | demo | ✅ | — |
| 26 | d6 | ✅ | — |
| 27 | chiffres | ✅ | Les 8 chiffres recomptés tombent juste |
| 28 | tests | ✅ | 6 scénarios et correctif UTC conformes |
| 29 | bilan | ✅ | — |
| 30 | merci | ⚠️ | Les notes répètent l'erreur du dispatch à deux paliers |
| 31 | A1 | ❌ | Même problème que la slide 17 ; le reste (4 min, rayon de repli, atomicité) est exact |
| 32 | A2 | ⚠️ | Les 3,465 DT sont **justes**, mais le mécanisme décrit dans les notes est faux |
| 33 | A3 | ✅ | Les deux failles et leurs correctifs sont décrits exactement |
| 34 | A4 | ⚠️ | L'extrait est simplifié par rapport à la vraie fonction |
| 35 | A5 | ✅ | Limites honnêtes et vérifiées |
| 36 | A6 | ✅ | — |

**Bilan : 4 erreurs (❌), 11 imprécisions (⚠️), 21 slides exactes.**

---

## 2. Slide 14 — ❌ La position GPS n'est pas envoyée tous les 30 m

**Ce que dit la slide :** « Livreur — Envoie sa position tous les ~30 m »
**Ce que disent les notes :** « sa position est envoyée environ tous les 30 mètres »

**Ce que dit le code.** Le filtre de distance du flux GPS vaut 10 mètres dans
le service d'arrière-plan, celui qui alimente réellement le suivi en direct :

- `cmandili_driver/lib/core/services/background_location_service.dart:339` → `distanceFilter: 10`
- `cmandili_driver/lib/features/home/presentation/home_screen.dart:363` → `distanceFilter: 10`
- `cmandili_driver/lib/features/home/presentation/home_screen.dart:900` → `distanceFilter: 20`
- `cmandili_driver/lib/features/orders/presentation/order_tracking_screen.dart:181` → `distanceFilter: 5`

Aucune valeur de 30 n'existe nulle part dans les trois applications.

**Attention, le mémoire répète la même erreur** en quatre endroits
(lignes 961, 1185, 1567 et 1630 de `ameenPFE.tex`, soit les sections 2.4.3,
2.5.2, 3.5.5 et 3.5.6), ainsi que l'annexe « Paramètres de suivi GPS ». Si un
juré ouvre le code, l'écart se voit immédiatement.

**Phrase corrigée, prête à coller :**

> Le livreur envoie sa position dès qu'il s'est déplacé de 10 mètres.

Et pour les notes :

> Une fois la course acceptée, sa position part vers le serveur à chaque
> déplacement de dix mètres. Ce n'est pas une minuterie : le flux est filtré
> par la distance parcourue, donc un livreur à l'arrêt n'envoie rien.

---

## 3. Slides 17 et 31 (A1) — ❌ La diffusion « en deux paliers » n'existe pas

**Ce que dit la slide 17 :**
> Colis et factures — Diffusion en deux paliers
> Palier 1 : tous les livreurs libres
> Après 30 s, palier 2 : aussi ceux déjà en course

**Ce que dit le code.** Il n'existe ni colonne, ni fonction, ni tâche
planifiée qui mette en œuvre un second palier. La recherche de
`broadcast`, `tier`, `palier`, `second_tier`, `wave` dans les 92 migrations,
les 5 Edge Functions et les quatre applications ne renvoie que la relaxation
progressive de la recherche IA (`supabase/functions/ai-search/index.ts:278`),
qui n'a rien à voir.

Le mécanisme réel est le suivant, et il est plus simple :

1. **Repas et commerces.** Quand le commerçant accepte, l'Edge Function
   appelle le dispatch séquentiel :
   `supabase/functions/push-on-order-status/index.ts:665-672` →
   `dispatch_driver_for_order(p_order_id, fanoutRadius, p_window_secs: 30)`.
   Cette fonction (`20260915150000_driver_dispatch_fallback_radius.sql:189`)
   prend **un seul** livreur, le plus proche, et pose `assigned_driver_id`.
   La commande sort alors du vivier commun.

2. **Colis et factures.** Ils sont créés directement au statut `ready`
   (`lib/features/courier/presentation/courier_screen.dart:374` et
   `lib/features/facture/presentation/facture_screen.dart:220`) et ne passent
   jamais par `confirmed`. Le dispatch séquentiel n'est donc **jamais**
   appelé pour eux, et `assigned_driver_id` reste nul. La règle RLS
   `drivers_see_offers_and_unassigned`
   (`20260510_assignment_and_distance.sql:38-52`) les rend visibles à
   **tous** les livreurs connectés, dès la première seconde :

   ```sql
   (status IN ('pending','ready') AND assigned_driver_id IS NULL)
   ```

   L'application livreur les liste telles quelles
   (`cmandili_driver/lib/features/orders/providers/driver_orders_provider.dart:53,67`).

Donc : il y a bien **une diffusion simultanée à tout le monde**, mais elle est
immédiate et unique. Il n'y a pas de palier 2, et surtout **aucun filtre sur
« libre »** : un livreur déjà en course voit l'offre dès le départ, lui aussi.

**Ce qui reste exact sur ces deux slides :**

- Le livreur le plus proche dans 7 km : `next_eligible_driver` a bien
  `p_radius_km DOUBLE PRECISION DEFAULT 7` et trie par
  `haversine_km(...) ASC` (`20260613_driver_is_blocked.sql:11-47`). ✅
- 30 secondes pour accepter : `offer_order_to_driver` a
  `p_window_seconds integer DEFAULT 30`
  (`20260915150000_driver_dispatch_fallback_radius.sql:109-112`). ✅
- Refus ou silence → le suivant : `rotate_expired_offers` ajoute le livreur à
  `passed_driver_ids` puis rappelle `next_eligible_driver`
  (même fichier, ligne 277). ✅
- Rayon élargi réglable par l'admin : `driver_fallback_radius_km()` lit
  `global_settings.driver_fallback_radius_km`, **défaut 20 km**
  (`20260915150000_driver_dispatch_fallback_radius.sql:77-86`). ✅
- Attribution atomique : côté serveur
  `UPDATE ... WHERE id = p_order_id AND driver_id IS NULL`, et côté livreur
  `.update({'driver_id': driverId}).eq('id', order.id).isFilter('driver_id', null)`
  (`cmandili_driver/lib/features/orders/presentation/available_orders_screen.dart:121-130`). ✅
- Signal de vie toutes les 4 minutes :
  `Timer.periodic(const Duration(minutes: 4), ...)`
  (`cmandili_driver/lib/core/services/background_location_service.dart:366`). ✅
- Le livreur voit la distance avant d'accepter : `driver_offer_distance_km`
  est posée par `offer_order_to_driver`. ✅

**Phrase corrigée, prête à coller (slide 17, colonne de droite) :**

> **Colis et factures — Diffusion ouverte**
> La demande est visible par tous les livreurs connectés dès sa création
> Aucune offre nominative, aucun compte à rebours
> Le premier qui accepte gagne (atomique)

**Et pour les notes :**

> Pour les colis et les factures, il n'y a pas d'urgence de fraîcheur. La
> demande n'est proposée à personne en particulier : elle apparaît
> directement dans la liste de tous les livreurs connectés, et le premier qui
> accepte l'emporte. L'écriture est atomique — elle ne réussit que si aucun
> livreur n'a encore pris la course —, donc une demande ne peut jamais être
> attribuée deux fois.

**Même correction à faire dans le mémoire**, ligne 1626 (§3.5.4) et
ligne 1360 (description de la classe Commande, qui mentionne un « envoi en
deux paliers » inexistant).

---

## 4. Slide 19 — ❌ La clé IA est bien présente dans l'application installée

**Ce que dit la slide :**
> Clés sur le serveur — Les clés IA et service_role ne sont jamais dans
> l'application installée.

**Ce que dit le code.** La moitié de l'affirmation est vraie, l'autre est
fausse.

- `service_role` : aucune trace dans les trois applications mobiles. ✅
- Clé IA : le fichier `.env` de la racine contient bien une variable
  `OPENROUTER_API_KEY` (je ne reproduis évidemment pas sa valeur), **et ce
  fichier est déclaré comme asset Flutter** :

  ```yaml
  # pubspec.yaml:89-90
  assets:
    - .env
  ```

  Un asset est copié tel quel dans l'APK. N'importe qui peut décompresser
  l'APK et lire `assets/.env`.

À la décharge du projet : **aucun code Dart ne lit cette variable**. Les seuls
accès à `dotenv.env` côté client portent sur `SUPABASE_URL`,
`SUPABASE_ANON_KEY` et `GOOGLE_MAPS_API_KEY`
(`lib/core/config/supabase_config.dart:10,16`,
`lib/core/services/route_service.dart:80`,
`lib/core/utils/location_service.dart:116`,
`lib/core/widgets/map_address_picker.dart:194`). La clé est donc embarquée
par inadvertance, pas utilisée. Et elle est de toute façon invalide
(`supabase/functions/ai-search/index.ts:6` : « found to be a dead truncated
key »).

Mais la phrase telle qu'elle est écrite est fausse, et c'est exactement le
genre d'affirmation qu'un jury de sécurité vérifie.

**Phrase corrigée, prête à coller :**

> **Clés sur le serveur** — La clé `service_role` et les appels au
> fournisseur d'IA restent côté serveur : l'application ne parle qu'aux
> Edge Functions, jamais directement au modèle.

**Et dans les notes, remplacer la phrase « dans la première version, une clé
était dans l'application, je l'ai déplacée » par :**

> Troisième couche : les appels à l'IA passent tous par une Edge Function, de
> sorte que l'application n'a jamais besoin de la clé du fournisseur. Je dois
> préciser une chose : le fichier de configuration embarqué contient encore
> une variable de clé IA héritée de la première version, inutilisée par le
> code et désormais invalide. Elle doit être retirée du fichier avant la
> publication sur le Play Store.

**Action recommandée avant la soutenance** (hors de cette revue, à faire
vous-même) : retirer la ligne `OPENROUTER_API_KEY` du `.env` embarqué, ou
sortir `.env` de la liste des assets. C'est une correction d'une ligne.

---

## 5. Slide 30 (notes) et 17 — ❌ Réponse préparée au jury à corriger

**Ce que disent les notes de la slide 30 :**
> Comment choisissez-vous le livreur ? Le plus proche dans ~7 km, 30 s pour
> répondre, puis le suivant, puis un rayon élargi ; colis et factures en
> diffusion à deux paliers.

La dernière proposition est fausse (voir §3).

**Réponse corrigée, prête à apprendre :**

> Pour un repas ou une commande de commerce : le serveur choisit le livreur
> connecté le plus proche dans un rayon de 7 kilomètres et lui laisse
> 30 secondes. S'il refuse ou ne répond pas, il passe au suivant. Si personne
> n'est disponible dans 7 km, il élargit une fois le rayon, à une valeur que
> l'administrateur règle depuis le tableau de bord. Pour un colis ou une
> facture, c'est différent : la demande est visible par tous les livreurs
> connectés en même temps, et le premier qui accepte l'emporte.

---

## 6. Slide 32 (A2) — ⚠️ Le résultat est juste, le mécanisme décrit est faux

**Bonne nouvelle d'abord : les 3,465 DT sont exacts dans les trois cas.**
J'ai refait le calcul sur le code, pas sur le texte.

**Ce que disent les notes :**
> Commission livreur 23 % : 1,035 DT, il garde 3,465 DT. À la 5e commande le
> client paie 2,25 DT, à la 10e rien ; le livreur garde la même chose.
> *À vérifier dans le code avant la soutenance : la commission de 23 % est
> bien calculée sur les frais pleins dans le cas fidélité.*

**Réponse à votre question : non, la commission n'est pas calculée sur les
frais pleins.** Elle est calculée sur ce que le client a réellement payé, et
une subvention vient compenser. Le résultat final est identique, mais le
chemin est différent.

Les deux morceaux de code :

1. À la validation du panier, la remise de fidélité est **retranchée** du
   champ `delivery_fee` lui-même
   (`20260930090000_order_type_per_category.sql:94`, fonction
   `apply_loyalty_at_checkout`) :

   ```sql
   NEW.loyalty_discount_amount := v_discount;
   NEW.total        := NEW.total - v_discount;
   NEW.delivery_fee := NEW.delivery_fee - v_discount;   -- ← ici
   ```

2. À la livraison (`20260814090000_loyalty_at_checkout.sql:150`, fonction
   `generate_settlements_on_delivery`) :

   ```sql
   v_driver_commission := NEW.delivery_fee * v_driver_rate;      -- sur le montant REMISÉ
   ...
   v_subsidy := NEW.loyalty_discount_amount * (1 - v_driver_rate); -- 77 % de la remise
   ```

Le calcul complet pour une course à 5 km (frais pleins 4,500 DT) :

| Cas | `delivery_fee` stocké | Commission 23 % | Subvention 77 % | Net livreur |
|---|---|---|---|---|
| Ordinaire | 4,500 | 1,035 | — | **3,465** |
| 5ᵉ (moitié) | 2,250 | 0,5175 | 1,7325 | **3,465** |
| 10ᵉ (offerte) | 0,000 | 0,000 | 3,465 | **3,465** |

Le tableau de la slide A2 est donc **juste**. Seule l'explication orale est à
reformuler.

**Phrase corrigée, prête à coller dans les notes :**

> La commission de 23 % porte sur ce que le client a effectivement payé, pas
> sur le tarif plein. Quand la fidélité s'applique, la plateforme verse au
> livreur une subvention égale à 77 % de la remise accordée. Les deux
> mécanismes se compensent exactement : quel que soit le cas, le livreur
> touche 77 % du tarif plein, soit 3,465 dinars ici.

**Deux précisions à connaître sur la fidélité**, au cas où le jury creuse :

- Le compteur est incrémenté **à la création de la commande**, pas à la
  livraison (`apply_loyalty_at_checkout` est un trigger `BEFORE INSERT`).
- La fidélité **ne s'applique ni au supermarché ni aux factures** :
  `IF NEW.order_type NOT IN ('supermarket', 'grocery', 'billPayment')`. Les
  colis, eux, y ont droit. La slide 18 juxtapose « 5 DT fixe supermarché et
  factures » et « 5e · 10e commande » sans le dire.

---

## 7. Slide 18 — ⚠️ Le plafond de 70 % est un défaut, pas une limite

**Ce que dit la slide :** « pourcentage (max 70 %) pour les autres »

**Ce que dit le code.** 70 est la valeur **initiale** insérée par la
migration :

```sql
-- 20260928200000_promotions_phase1.sql:79
VALUES ('max_discount_percent', '70', ...)
```

mais l'administrateur peut la régler **de 1 à 99 %** :

```ts
// cmandili_admin/app/api/settings/route.ts:26-27
max_discount_percent < 1 ||
max_discount_percent > 99
```

**Phrase corrigée :**

> pourcentage pour les autres, plafonné à une valeur réglable par
> l'administrateur (70 % par défaut)

**Ce qui est exact sur cette slide :**

- Happy Hour pour restaurants et pâtisseries :
  `20260928200000_promotions_phase1.sql:211` →
  `WHERE id IN ('food','bakery') AND discount_mode = 'happy_hour'` ✅
- 3,5 DT pour 3 km puis +0,5 DT/km : `lib/core/utils/delivery_fee.dart:13,15` ✅
- 5 DT fixe : `kFlatDeliveryFee = 5.0` (`delivery_fee.dart:22`), utilisé par
  `facture_screen.dart:67` et `supermarket_detail_screen.dart:128` ✅
- 10 % commerçant, 23 % livreur, configurables :
  `generate_settlements_on_delivery` lit
  `default_restaurant_commission_rate` (défaut 0.10) et
  `default_driver_commission_rate` (défaut 0.23) dans `global_settings` ✅
- **Solde ≤ 0 → compte bloqué : exact** ✅ La fonction `enforce_prepaid_block`
  (`20260805121032_prepaid_balance_model.sql:203`) prend le plancher dans
  `global_settings.prepaid_min_balance`, **défaut 0**, et pose
  `drivers.is_blocked = TRUE`. Une migration antérieure bloquait à −50 DT,
  mais elle est explicitement retirée (ligne 268 : « Retire the old -50 TND
  driver-only rule »). Le déblocage est automatique dès que le solde repasse
  au-dessus du plancher.

> **Nuance utile :** le blocage s'applique aussi aux **commerçants**, pas
> seulement aux livreurs (même fonction, lignes 230-232). La slide ne parle
> que du livreur.

> **Point à corriger dans le mémoire :** lignes 1462 et 1702, le mémoire
> affirme qu'« un avertissement s'affiche lorsque le solde descend entre deux
> et quatre dinars ». Ce seuil n'existe plus : il venait de l'ancienne règle
> à −40 DT, supprimée en août. L'application livreur affiche bien un bandeau
> « Solde faible »
> (`cmandili_driver/lib/features/home/presentation/home_screen.dart:1143`),
> mais aucun seuil de 2 à 4 dinars n'est codé.

---

## 8. Slide 24 — ⚠️ 15 routes protégées sur 16

**Ce que dit la slide :** « 24 pages · 16 routes API », et les notes :
« toutes protégées par une vérification du rôle ».

**Ce que dit le code.** 16 routes existent, 15 appellent `requireAdmin()`.
La seule exception est `cmandili_admin/app/api/logout/route.ts` — ce qui est
normal : on n'a pas besoin d'être administrateur pour se déconnecter.

**Phrase corrigée pour les notes :**

> Au total, 24 pages et 16 routes API. Toutes les routes qui lisent ou
> modifient des données vérifient que l'appelant est administrateur ; seule
> la route de déconnexion ne le fait pas, et c'est voulu.

---

## 9. Slides 9 et 23 — ⚠️ Le code couleur annoncé n'est pas celui des applications

**Ce que disent les slides :** « Chaque application garde sa couleur dans la
suite : orange, vert, indigo et bleu ardoise » (slide 9), puis « l'application
Livreur, en vert » et « l'application Commerçant, en indigo » (slide 23).

**Ce que dit le code :**

| Application | Couleur réelle | Source |
|---|---|---|
| Client | `#059669` — vert émeraude | `lib/core/theme/app_colors.dart:5` |
| Livreur | `#2563EB` — bleu | `cmandili_driver/lib/core/theme/app_colors.dart:4` |
| Partenaire | `#4F46E5` — indigo | `cmandili_partner/lib/core/theme/app_colors.dart:4` |
| Administrateur | `#059669` — vert émeraude | `cmandili_admin/app/globals.css:20` |

Seul l'indigo du Partenaire correspond. Annoncer le Livreur « en vert » alors
que ses captures sont bleues crée un décalage visible pendant toute la
présentation.

**Deux options :**

1. Aligner la présentation sur les applications : Client vert, Livreur bleu,
   Partenaire indigo, Administrateur vert.
2. Garder vos couleurs et retirer la phrase « chaque application garde sa
   couleur », en la remplaçant par : « Dans cette présentation, chaque acteur
   a sa couleur, pour vous aider à suivre. »

La deuxième est plus simple si le thème du diaporama est déjà fait.

---

## 10. Slide 34 (A4) — ⚠️ L'extrait est simplifié

L'extrait affiché est fidèle dans l'esprit mais plus court que la vraie
fonction `apply_promo_code`
(`supabase/migrations/20260929100000_promo_codes_phase3.sql:281-295`).

Deux écarts :

1. La vraie condition commence par `v_variant IS NULL` — une ligne de panier
   portant une variante n'est jamais considérée comme en promotion.
2. Le prix unitaire réel est
   `ROUND((COALESCE(v_variant, CASE WHEN v_on_promo THEN discount_price ELSE price END) + v_addons) * c_markup, 3)`
   — il tient compte des variantes, des suppléments, d'une constante de
   majoration et d'un arrondi à trois décimales.

Les deux lignes qui portent le message (`v_subtotal` et `v_eligible`) sont,
elles, **exactes au caractère près**. ✅

Il suffit de changer le pied de slide : « Extrait **simplifié** de la fonction
serveur · section 3.8.5 du mémoire ».

> **Point à préparer :** la constante `c_markup CONSTANT NUMERIC := 1.10`
> (ligne 110 de la même migration) applique une majoration de 10 % sur les
> prix au moment où le serveur recalcule le panier. Elle n'apparaît ni dans
> les slides ni dans le mémoire. Si un juré lit l'extrait en entier, il
> demandera ce qu'elle fait. Préparez une phrase.

---

## 11. Slides 4, 13 et 16 — ⚠️ Trois affirmations non vérifiables

| Affirmation | Slide | Statut |
|---|---|---|
| « Jusqu'à 30 % chez Glovo » | 4 | **Non vérifiable.** Le chiffre n'est ni dans le code ni dans le mémoire — le mémoire dit seulement « commissions élevées », sans valeur. C'est une affirmation publique sur une entreprise nommée : si un juré demande la source, il faut pouvoir la citer. Sinon, dites « des commissions nettement plus élevées que les nôtres ». |
| « PostgreSQL 17.6 » | 13, 16 | **Non vérifiable depuis le dépôt.** `supabase/config.toml` ne fixe pas de version et aucune migration ne l'inscrit. Le mémoire l'affirme (§3.3.3). C'est sans doute juste, mais la preuve est dans la console Supabase, pas dans le code : ouvrez-la avant la soutenance si vous voulez pouvoir la montrer. |
| « 30 % » et « MIUI » (A5) | 35 | La limite MIUI est bien documentée comme telle dans le mémoire ✅, mais aucune trace dans le code — c'est une observation de terrain, à présenter comme telle. |

---

## 12. Slide 1 — ⚠️ Un encadrant manque

La page de garde du mémoire porte **deux** encadrants : Mme Olfa Harrabi
(encadrant académique) et M. Firas Mzoughi (encadrant professionnel). La
slide de couverture ne cite que la première. Un encadrant professionnel
présent dans la salle et absent de la couverture, cela se remarque.

---

## 13. Ce qui est exact et solide — à ne pas toucher

Je le note parce que c'est la majorité de la présentation, et que c'est vérifié :

- **Slide 20 (IA).** Tout est juste. `verify_jwt = true` est posé pour les
  cinq fonctions (`supabase/config.toml:21-37`), donc « vérifie le JWT » est
  exact même si le contrôle n'est pas écrit dans le corps de la fonction.
  OpenRouter principal et Gemini en secours :
  `supabase/functions/ai-chat/index.ts:46-55`. La relaxation progressive
  existe bien (`ai-search/index.ts:278-320`, `RELAX_TIERS`). Aucune trace de
  `pgvector` ni d'embeddings dans tout le dépôt — « pas de recherche
  vectorielle » est donc exact. La clé OpenRouter morte est documentée dans
  le code lui-même (`ai-search/index.ts:6`), ce qui rend votre honnêteté sur
  ce point d'autant plus solide.
- **Slide 33 (A3, sécurité).** Les deux failles sont décrites exactement
  comme la migration corrective les décrit
  (`20260921233000_fix_orders_anon_pii_exposure.sql`, lignes 4-14 pour la
  fuite A, ligne 75 pour `ALTER VIEW ... SET (security_invoker = true)`). Le
  commentaire du code dit même « 136 of 136 rows to anon » — un chiffre que
  vous pouvez citer s'il faut convaincre.
- **Slide 28 (tests).** Les six scénarios correspondent aux six
  sous-sections 5.2.1 à 5.2.6 du mémoire. Le correctif UTC est réel :
  33 appels à `.toUtc()` répartis sur les trois applications (11 côté client,
  16 côté livreur, 6 côté partenaire) — « dans les trois applications » est
  donc exact.
- **Slide 16.** Le passage de Mapbox à Google Maps est attesté par le commit
  `e3c32e4 "Replace Mapbox with Google Maps"`. Riverpod est bien présent
  (`flutter_riverpod: ^2.4.9` dans les trois `pubspec.yaml`).
- **Slide 5 (tableau comparatif).** Conforme au tableau 1.1 du mémoire.

---

## 14. Chiffres recomptés

Tous les chiffres de la slide 27 sont **exacts**. Voici la méthode pour
chacun, pour que vous puissiez la refaire devant le jury si on vous le
demande.

| Chiffre annoncé | Recompté | Verdict | Méthode |
|---|---|---|---|
| 4 applications | 4 | ✅ | 3 projets Flutter (`lib`, `cmandili_driver`, `cmandili_partner`) + 1 Next.js (`cmandili_admin`) |
| 96 écrans et pages | 96 | ✅ | 32 + 17 + 23 + 24, détail ci-dessous |
| — Client 32 | 32 | ✅ | `find lib -name '*_screen.dart' \| wc -l` |
| — Livreur 17 | 17 | ✅ | `find cmandili_driver/lib -name '*_screen.dart' \| wc -l` |
| — Partenaire 23 | 23 | ✅ | `find cmandili_partner/lib -name '*_screen.dart' \| wc -l` |
| — Admin 24 pages | 24 | ✅ | `find cmandili_admin/app -name 'page.tsx' \| grep -v .next \| wc -l` |
| 76 713 lignes | 76 713 | ✅ | Somme des `.dart` des trois apps (hors `*.g.dart` et `app_localizations*`) + `.ts`/`.tsx` de l'admin hors `.next` : 32 266 + 14 145 + 19 083 + 11 219 |
| 167 commits | 167 | ✅ | `git rev-list --count HEAD` |
| ~5,5 mois | 5 mois et 12 jours | ✅ | Premier commit 2026-04-24, dernier 2026-10-06 |
| 92 migrations SQL | 92 | ✅ | `ls supabase/migrations/*.sql \| wc -l` |
| 42 fonctions SQL | 42 | ✅ | `CREATE [OR REPLACE] FUNCTION` dans les migrations, dédoublonné par nom |
| 25 triggers | 25 | ✅ | `CREATE [OR REPLACE] TRIGGER` dans les migrations, dédoublonné par nom |
| 5 Edge Functions | 5 | ✅ | `ls -d supabase/functions/*/` → `ai-chat`, `ai-search`, `notify-partner-order`, `push-happy-hour`, `push-on-order-status` |
| 16 routes API admin | 16 | ✅ | `find cmandili_admin/app/api -name route.ts \| grep -v .next \| wc -l` (dont **15** avec `requireAdmin`) |
| 3 langues | 3 | ✅ | `lib/l10n/app_fr.arb`, `app_en.arb`, `app_ar.arb` (395, 400 et 395 clés) |

**Deux chiffres à nuancer si on vous pousse :**

- Les 76 713 lignes **incluent** commentaires et lignes vides. Le projet est
  abondamment commenté, donc le volume de code exécutable est plus bas.
  Dites « 76 000 lignes de fichiers source » plutôt que « de code ».
- Les **29 relations** (tables et vues) touchées par les migrations sont un
  **minimum** : les toutes premières tables ont été créées avant la mise en
  place du dossier `migrations`. Ne citez pas de total pour la base.

---

## 15. Questions probables du jury

Dix questions que le code appelle, avec une réponse courte.

**1. Que se passe-t-il si aucun livreur n'accepte, même après l'élargissement
du rayon ?**
> Le commerçant est prévenu. La fonction appelle
> `notify_partner_no_drivers` et la commande reste sans livreur plutôt que de
> boucler indéfiniment. C'était d'ailleurs un défaut corrigé en cours de
> route : avant, une commande qui n'avait jamais trouvé de premier livreur
> n'était jamais réessayée ni signalée.

**2. Deux livreurs appuient sur « Accepter » en même temps. Que se passe-t-il ?**
> Un seul gagne. La mise à jour s'écrit
> `UPDATE orders SET driver_id = ... WHERE id = ? AND driver_id IS NULL`.
> Le second reçoit un résultat vide et voit le message « Cette commande vient
> d'être prise par un autre livreur ». C'est PostgreSQL qui arbitre, pas
> l'application.

**3. Pourquoi mettre la logique métier dans la base plutôt que dans les
applications ?**
> Parce que quatre applications différentes la partagent. Si le calcul des
> commissions vivait dans le téléphone, il faudrait le réécrire trois fois et
> republier à chaque changement de taux. Dans la base, il s'applique de la
> même façon pour tout le monde, et l'administrateur change un taux sans
> nouvelle version.

**4. Un livreur peut-il truquer le montant qu'il doit à la plateforme ?**
> Non. Les commissions sont calculées par un déclencheur qui se déclenche au
> passage au statut « livrée », à partir de taux lus en base. Le téléphone
> n'envoie aucun montant. Pour les codes promo, c'est pareil : le serveur
> reçoit la liste des articles et recalcule le sous-total depuis le
> catalogue, il ne fait jamais confiance au total annoncé.

**5. Votre blocage à solde nul : que se passe-t-il pour une course déjà
acceptée ?**
> Le blocage pose `is_blocked = TRUE`, et cette colonne n'est lue que par la
> sélection du prochain livreur. Une course déjà acceptée n'est donc pas
> interrompue : le livreur la termine, et c'est seulement la commande
> suivante qu'il ne recevra pas.

**6. Comment savez-vous qu'un livreur est vraiment en ligne, et pas
simplement un téléphone éteint ?**
> Par un signal de vie. L'application réécrit la dernière position connue
> toutes les 4 minutes, même à l'arrêt. Le tableau de bord considère un
> livreur hors ligne au-delà de 10 minutes sans nouvelle. C'est une
> limite assumée : si le système Android ferme l'application, le livreur
> disparaît de la carte au bout de 10 minutes, pas immédiatement.

**7. Vous dites que l'IA garde ses clés côté serveur. Qu'est-ce qui empêche
quelqu'un d'appeler directement votre Edge Function ?**
> La vérification du jeton : les cinq fonctions ont `verify_jwt = true`.
> Cela dit, soyons précis : la clé publique de l'application est elle-même un
> jeton valide, donc le contrôle écarte les appels anonymes, pas un
> utilisateur légitime qui abuserait du service. C'est pour cela qu'une
> limite d'appels figure dans mes perspectives.

**8. Pourquoi la 5ᵉ commande ne coûte-t-elle rien de plus au livreur ?**
> Parce que la remise porte sur ce que paie le client, pas sur ce que touche
> le livreur. La plateforme verse au livreur une subvention égale à 77 % de
> la remise, exactement ce que la commission lui aurait laissé. Il touche
> 77 % du tarif plein dans tous les cas.

**9. Vos deux failles : comment savez-vous qu'il n'y en a pas une troisième ?**
> Je ne le sais pas, et je ne le prétends pas. Ce que j'ai fait est précis :
> j'ai rejoué toutes les requêtes avec la seule clé publique, celle qui est
> dans l'APK, pour voir ce qu'un inconnu peut lire. C'est ce qui a révélé les
> deux failles. Une relecture complète par un tiers reste à faire.

**10. Pourquoi des tests manuels et pas automatisés ?**
> Par arbitrage de temps. Six scénarios documentés, rejoués sur de vrais
> téléphones, avec résultat attendu et résultat observé — quatre anomalies
> trouvées et corrigées, dont le décalage d'une heure sur les fuseaux. Mais
> ces tests ne se rejouent pas tout seuls à chaque changement : c'est la
> première de mes perspectives.

---

## 16. Ce qui manque à la présentation

Quatre éléments présents dans le projet et absents du diaporama.

1. **La majoration de 10 % sur les articles** (`c_markup = 1.10`). C'est une
   règle économique réelle, visible dans l'extrait de l'annexe A4. Mieux vaut
   l'expliquer vous-même qu'y être amené.
2. **Le second encadrant**, M. Firas Mzoughi (voir §12).
3. **La notion de catégorie comme table porteuse de règles** est mentionnée
   slide 12, mais son effet le plus parlant ne l'est pas : `food_items` et
   `grocery_items` sont des **vues** sur une table d'articles unique. Ouvrir
   une huitième catégorie ne crée aucune table. C'est votre meilleur argument
   de conception, il tient en une phrase.
4. **Le blocage prépayé s'applique aussi aux commerçants** (voir §7).

---

## 17. Récapitulatif des corrections à faire

Par ordre d'importance.

| # | Où | Correction |
|---|---|---|
| 1 | Slide 19 | Retirer « les clés IA ne sont jamais dans l'application installée » — et retirer la clé du `.env` embarqué |
| 2 | Slides 17, 31, 30 | Supprimer le « palier 2 après 30 s » : la diffusion est unique et immédiate |
| 3 | Slide 14 | 30 m → **10 m** |
| 4 | Slide 18 | « max 70 % » → « 70 % par défaut, réglable de 1 à 99 % » |
| 5 | Slide 24 | « toutes protégées » → 15 routes sur 16 |
| 6 | Slide 32 notes | Expliquer la subvention de 77 %, pas « 23 % sur les frais pleins » |
| 7 | Slides 9, 23 | Aligner le code couleur, ou retirer la phrase qui le présente comme celui des apps |
| 8 | Slide 34 | Ajouter « extrait simplifié » |
| 9 | Slide 4 | Sourcer les 30 % de Glovo ou retirer le chiffre |
| 10 | Slide 1 | Ajouter M. Firas Mzoughi |

**Et dans le mémoire**, trois points à reprendre si vous en avez encore la
possibilité : le seuil GPS (30 m → 10 m, quatre endroits), la diffusion en
deux paliers (§3.5.4 et description de la classe Commande), et
l'avertissement « entre deux et quatre dinars » qui n'existe plus.
