# Arrondi des montants à 50 millimes

*Préparé le 04/11/2026. Migration appliquée par vous le 04/11 dans le SQL Editor, puis vérifiée en lecture et enregistrée (`migration repair`). Code commité et poussé sur `adam-branch` : client `030fb46`, partenaire `631b548`, admin `f603fb6`.*

## 1. La règle

Chaque montant que le système calcule est arrondi au multiple de 50 millimes le plus proche, moitié vers le haut (0,805 → 0,800 ; 0,4025 → 0,400 ; 1,035 → 1,050 ; 2,375 → 2,400). Le pas est un réglage de l'admin, `money_rounding_step`, qui vaut 0,050 par défaut.

Les frais de livraison sont arrondis. À la 5e commande, le client paie `round_money(frais / 2)` ; à la 10e, il ne paie rien. Les commissions (10 % commerçant, 23 % livreur) sont arrondies.

La subvention fidélité n'est pas arrondie à part. Elle vaut ce qu'il faut pour que le livreur garde exactement ce qu'il garde sur une commande normale. Ainsi, la plateforme paie exactement la remise.

## 2. Ce qui change, et pourquoi

### Base de données : un seul fichier, non appliqué

Fichier : `supabase/migrations/20261104120000_arrondi_50_millimes.sql`. Chaque fonction part de sa définition **live** du 04/11 (`pg_get_functiondef`). Seules les lignes marquées `[arrondi 50 millimes]` changent.

| Où (ligne du fichier) | Changement | Pourquoi |
|---|---|---|
| `global_settings` (l. 59) | Nouvelle ligne `money_rounding_step = 0.050`, avec `ON CONFLICT DO NOTHING` | Le pas se règle comme les taux. Relancer le fichier n'écrase pas la valeur de l'admin. |
| `round_money(x)`, nouvelle (l. 70) | Renvoie `round(x / pas) × pas`, en `numeric(12,3)` | Une seule règle pour toute la base. Un réglage absent, illisible ou ≤ 0 vaut 0,050 : une faute de frappe dans l'admin ne bloque aucune commande. |
| `apply_loyalty_at_checkout` (l. 122) | Les frais sont arrondis à l'insertion, et `total` reçoit le même écart | Filet de sécurité : une ancienne version de l'app envoie 4,185 pour 4,37 km. Le serveur enregistre 4,200. |
| `apply_loyalty_at_checkout` (l. 148) | 5e commande : payé = `round_money(frais / 2)`, remise = frais − payé | Le client paie une somme ronde, et frais = payé + remise au millime. |
| `generate_settlements_on_delivery` (l. 215, 219) | Commission commerçant = `round_money(sous-total × 10 %)` ; commission livreur = `round_money(frais payés × 23 %)` | Des commissions en espèces réelles. |
| `generate_settlements_on_delivery` (l. 276) | Subvention = (frais − `round_money(frais × 23 %)`) − (frais payés − commission payée) | Le livreur garde la même somme dans les 3 cas, et la plateforme paie exactement la remise. |
| `apply_promo_code`, panier (l. 487) et ancienne signature (l. 601) | Remise en % = `round_money(...)`, jamais plus que le montant éligible | Une remise ronde. La règle « un code ne s'applique pas à un article déjà en promotion » n'est pas touchée. |
| Trigger `round_promo_prices` sur `vendor_items` (l. 633 à 654), nouveau | `discount_price` et `happy_hour_price` sont arrondis à l'écriture, sans jamais dépasser le prix normal | Couvre le Happy Hour, la promotion en %, et le cron `activate_scheduled_promotions`, qui calcule encore `round(prix × (1 − %), 3)` au millime. |

Fonctions vérifiées et **non modifiées** :

- `update_wallet_balance` : ajoute le montant du règlement tel quel, qui arrive désormais arrondi.
- `release_loyalty_slot_on_cancel` : touche seulement le compteur.
- `get_driver_earnings` : additionne les frais.
- `apply_customization_template_to_item` : ajoute un supplément fixe, sans taux, et son trigger est désactivé.
- L'index `settlements_once_per_order` : vérifié par le bloc de contrôle du fichier.

### Applications

Les modifications ne sont pas commitées et restent sur `adam-branch`, dans les 3 dépôts.

| App | Fichier : ligne | Changement |
|---|---|---|
| Client | `lib/core/utils/money.dart` (nouveau) | `roundMoney`, même règle qu'en SQL. Le calcul passe par des entiers, pour que 2,375 ou 1,75 × 0,23 tombent du même côté que dans Postgres. |
| Client | `lib/core/utils/delivery_fee.dart:48, 54` | Frais arrondis : 4,37 km donne 4,185 calculés et 4,200 facturés. Vaut pour le panier, le checkout et les colis. |
| Client | `lib/features/loyalty/data/loyalty_eligibility.dart:36-43` | `paidFee` / `discountOn` appliquent la règle serveur de la 5e et de la 10e commande. |
| Client | `checkout_controller.dart:129`, `courier_price_card.dart:101`, `facture_price_summary.dart:58` | L'aperçu fidélité suit cette règle (avant : frais × 0,5). |
| Partenaire | `lib/core/utils/money.dart` (nouveau) | La même fonction `roundMoney`. |
| Partenaire | `lib/core/utils/promo_price.dart:18` | Prix d'une promotion en % arrondi : 12,9 DT à −15 % donne 10,965 calculés et 10,950 affichés et enregistrés, comme le trigger. |
| Partenaire | `happy_hour_setup_controller.dart:111, 153, 161` | Prix Happy Hour arrondi (boutons %, enregistrement). Le contrôle porte sur le prix arrondi : 9,99 pour un plat à 10 DT devient 10,000, donc refusé. |
| Partenaire | `add_edit_item_controller.dart:223, 284, 440` | Même chose pour le Happy Hour quotidien de la fiche article. |
| Livreur | aucun | Les écrans de gains lisent la commission et la subvention écrites par la base (`driver_orders_provider.dart:206-240`, `delivery_card.dart:34-43`). |
| Admin | `lib/money-step.ts` (nouveau), `parametres/page.tsx`, `SettingsForm.tsx`, `api/settings/route.ts` | Le pas se règle dans Paramètres, entre 0,001 et 1 DT, en millimes entiers. |

L'admin ne calcule aucun montant : il additionne `platform_fee`, `driver_fee_cut` et les règlements écrits par la base. `profile_repository.dart`, `app/dashboard/page.tsx` et `CategoryRevenueTable.tsx` ne sont pas touchés.

## 3. Résultats : ancien → nouveau

Les valeurs viennent de la requête de l'annexe, lancée sur le live avec les vrais taux (23 % et 10 %) et un pas de 0,050. Le prix du repas est de 30 DT. Un seul nombre signifie que la valeur ne change pas.

| Cas | Client paie | Commerçant net | Commission livreur | Subvention | Livreur garde | Plateforme gagne |
|---|---|---|---|---|---|---|
| 3 km, normale | 33,500 | 27,000 | 0,805 → **0,800** | 0 | 2,695 → **2,700** | 3,805 → 3,800 |
| 3 km, 5e | 31,750 | 27,000 | 0,403 → **0,400** | 1,348 → **1,350** | 2,695 → **2,700** | 2,055 → 2,050 |
| 3 km, 10e | 30,000 | 27,000 | 0 | 2,695 → **2,700** | 2,695 → **2,700** | 0,305 → 0,300 |
| 5 km, normale | 34,500 | 27,000 | 1,035 → **1,050** | 0 | 3,465 → **3,450** | 4,035 → 4,050 |
| 5 km, 5e | 32,250 | 27,000 | 0,518 → **0,500** | 1,733 → **1,700** | 3,465 → **3,450** | 1,785 → 1,800 |
| 5 km, 10e | 30,000 | 27,000 | 0 | 3,465 → **3,450** | 3,465 → **3,450** | −0,465 → −0,450 |
| Happy Hour −20 % (24 DT), 5 km, normale | 28,500 | 21,600 | 1,035 → **1,050** | 0 | 3,465 → **3,450** | 3,435 → 3,450 |
| Happy Hour, 5 km, 5e | 26,250 | 21,600 | 0,518 → **0,500** | 1,733 → **1,700** | 3,465 → **3,450** | 1,185 → 1,200 |
| Happy Hour, 5 km, 10e | 24,000 | 21,600 | 0 | 3,465 → **3,450** | 3,465 → **3,450** | −1,065 → −1,050 |
| 4,37 km, normale (frais 4,185 → 4,200) | 34,185 → **34,200** | 27,000 | 0,963 → **0,950** | 0 | 3,222 → **3,250** | 3,963 → 3,950 |
| 4,37 km, 5e | 32,092 → **32,100** | 27,000 | 0,481 → **0,500** | 1,612 → **1,650** | 3,223 → **3,250** | 1,869 → 1,850 |
| 4,37 km, 10e | 30,000 | 27,000 | 0 | 3,222 → **3,250** | 3,222 → **3,250** | −0,222 → −0,250 |

À retenir :

- **Le livreur garde la même somme dans les 3 cas** : 2,700 à 3 km, 3,450 à 5 km, 3,250 à 4,37 km. Avec l'ancien calcul, 4,37 km donnait 3,222 / 3,223 / 3,222, soit un millime d'écart.
- **La plateforme paie exactement la remise** : 1,750 et 3,500 à 3 km ; 2,250 et 4,500 à 5 km.
- **L'arrondi ne joue pas toujours pour le livreur.** À 5 km, 1,035 devient 1,050 : le livreur garde 15 millimes de moins (3,450 au lieu de 3,465). À 3 km, il garde 5 millimes de plus. L'écart est d'au plus 25 millimes par commande, dans un sens ou dans l'autre.
- Le commerçant net ne bouge pas dans ces exemples, car 10 % de 30 ou de 24 est déjà rond. Sur un sous-total de 12,350 DT, la commission passe de 1,235 à 1,250.

Autres cas (calculés par la règle, voir §6) :

- Promotion −15 % sur 12,900 DT : 10,965 → 10,950.
- Code −10 % sur 12,350 DT éligibles : remise 1,235 → 1,250, sous-total 11,115 → 11,100.
- Repas en Happy Hour avec un code −10 % : le code est refusé, avant comme après.

Les commandes existantes ne changent pas (règle 6). Sur les 184 commandes du live, 44 frais de livraison, 30 commissions commerçant et 56 commissions livreur ne sont pas des multiples de 50 millimes ; elles restent telles quelles.

## 4. Tests

| Où | Résultat |
|---|---|
| Client, `flutter test` | **411 réussis, 0 échec**, dont 19 nouveaux dans `test/money_rounding_test.dart`. Ils couvrent les exemples de la règle, 3 km (3,500), 5 km (4,500) et 4,37 km (4,185 → 4,200). Ils vérifient aussi que toutes les distances de 0 à 25 km, tous les 10 m, donnent un multiple de 0,050, ainsi que le payé et la remise des 5e et 10e commandes et les totaux du checkout. |
| Partenaire, `flutter test` | **52 réussis, 0 échec**, dont 8 nouveaux dans `test/money_rounding_test.dart` : prix promo en %, Happy Hour, contrôle du prix arrondi. |
| Livreur | Non lancé : aucun fichier modifié. |
| Dry run complet (migration + vrais triggers) | **Prêt, à lancer par vous** : `presentation_assets/dry_run_arrondi.sql` (voir §5, étape 0). L'essai avec Docker est abandonné : Docker Desktop plante au démarrage sous Windows. |
| Admin, `npm test` | **112 réussis, 0 échec**, dont 5 nouveaux dans `lib/money-step.test.ts`. `tsc --noEmit` et `eslint` sont propres sur les fichiers modifiés. |
| Live, SELECT seulement | La requête de l'annexe (rien créé) passe tous ses contrôles sur les 12 cas : livreur identique dans chaque groupe, coût fidélité égal à la remise, montant payé par le client multiple de 0,050. Avec l'ancien calcul, ce dernier contrôle échoue à 4,37 km (34,185 et 32,092). |
| Live, SELECT seulement | Le contrôle de `rollback_arrondi.sql` donne `corps_identiques_au_live = 4` : les 4 corps copiés sont identiques aux fonctions live d'aujourd'hui (empreintes SHA-256). |
| Live, test réel (04/11, 22 h 46-47 UTC) | **Réussi.** 2 commandes de test (note « TEST ARRONDI 04/11 »), chacune en une seule transaction, de la création à la livraison, sur les comptes de test. A : 3 km, frais 3,500, livreur garde 2,700. B : frais envoyés 4,185 par une ancienne app, la base garde 4,200 ; c'est une 10e commande gratuite, le livreur garde 3,250. Dans les deux cas, le livreur garde frais − round_money(frais × 23 %), et tous les montants sont des multiples de 0,050. |

## 5. Appliquer, puis revenir en arrière

**Statut au 04/11 (vers 23 h 30) : étapes 1 à 4 faites.**

- Le dernier résultat de la migration est conforme : `fonctions_a_jour = 4`, `trigger_prix_promo = true`, `index_unique_intact = true`.
- Contrôle sur le live, en lecture :
  - `round_money` existe et le réglage vaut 0.050 ;
  - les 6 fonctions sont identiques au fichier ;
  - aucun reste de test (184 commandes, portefeuilles inchangés).
- La migration est enregistrée (`migration list` : `20261104120000` des deux côtés).
- Le code est commité et poussé.
- Reste l'étape 5 : publier les apps.

**0. Le dry run (rien n'est gardé) :** `presentation_assets/dry_run_arrondi.sql`. Il n'a pas été lancé avant la vraie migration, mais il reste utilisable : il ne change rien et teste les vrais triggers. Si l'éditeur affiche « Potential issue detected… `dry_run_resultats` », choisir **Run without RLS**. C'est une table `TEMP`, privée à votre session et supprimée au `ROLLBACK`.

Ce fichier contient la migration recopiée octet pour octet, entre `BEGIN` et un `ROLLBACK` final. Il teste ensuite, dans la même transaction :

- les prix promo, sur un plat de Seven pizza à 13,000 DT ;
- les vrais triggers de commande, sur les comptes de test : `client@gmail.com`, Seven pizza Kairouan (`seven@gmail.com`) et le livreur `ademcherif209+driver@gmail.com`, à 3 km et 5 km, en commande normale, 5e et 10e.

Rien ne sort de la base : les seuls appels externes de ces triggers passent par pg_net, qui n'envoie qu'après un COMMIT. Le projet n'a ni l'extension http ni dblink.

- **Comment le lancer :** dans le SQL Editor, avec le rôle `postgres` (celui par défaut), coller tout le fichier puis cliquer sur **Run**, à un moment calme. Pendant la seconde que dure le fichier, `vendor_items` est verrouillé en écriture.
- **Succès :** aucune erreur rouge, et un tableau de 19 lignes avec `ok = true` partout. La ligne 0, « TOUT EST BON », vaut `true`. Lignes 101 à 106 : le livreur garde 2.700 à 3 km et 3.450 à 5 km, dans les trois cas.
- **Échec :** une erreur rouge, et rien n'est gardé.
  - « DRY RUN EN ÉCHEC : … » liste chaque ligne fausse, avec l'attendu et l'obtenu.
  - « arrondi_50_millimes : … » vient du contrôle de la migration elle-même.
  - « SAVEPOINT can only be used in transaction blocks » : l'éditeur n'a pas lancé le fichier d'un seul bloc, et rien n'a été fait.
  - « ORDER_STATUS_SCOPE » ou « permission denied » : le rôle choisi n'est pas `postgres`.
- **Vérifier ensuite que rien n'est resté :** `select to_regprocedure('public.round_money(numeric)') is null as rien_garde;` doit répondre `true`.

**Fichier à lancer ensuite, pour de vrai :** `supabase/migrations/20261104120000_arrondi_50_millimes.sql`

1. Ouvrir Supabase, projet **cmandili**, **SQL Editor**, puis **New query**.
2. Coller tout le fichier et cliquer sur **Run**. Le dernier résultat doit donner :
   - `pas = 0.050`, `r_0_805 = 0.800`, `r_0_4025 = 0.400`, `r_1_035 = 1.050`, `r_2_375 = 2.400` ;
   - `fonctions_a_jour = 4`, `trigger_prix_promo = true`, `index_unique_intact = true`.

   Si le contrôle du fichier voit un écart, il lève une erreur et annule tout.
3. Enregistrer la migration, depuis le dossier `cmandili` :

   ```bash
   supabase migration repair --status applied 20261104120000 --linked
   ```

4. Relire puis committer le code. **Attention :** `git commit -am` ne prend pas les fichiers nouveaux. Les fichiers modifiés seraient commités sans `money.dart`, et les apps ne compileraient plus. Il faut ajouter aussi :
   - client : `lib/core/utils/money.dart`, `test/money_rounding_test.dart` et le fichier de migration ;
   - partenaire : `lib/core/utils/money.dart`, `test/money_rounding_test.dart` ;
   - admin : `lib/money-step.ts`, `lib/money-step.test.ts`.
5. Publier les nouvelles versions du client et du partenaire, puis redéployer l'admin. D'ici là, les anciennes versions peuvent afficher un aperçu qui diffère d'au plus 25 millimes, mais elles paient ce que calcule le serveur.

**Revenir en arrière :** lancer `presentation_assets/rollback_arrondi.sql` dans le SQL Editor.

- Il remet les 4 fonctions telles qu'elles étaient le 04/11 et supprime le trigger `round_promo_prices`.
- Résultat attendu : `corps_identiques_au_live = 4`, `fonctions_avec_round_money = 0`, `trigger_prix_promo = false`.
- `round_money` et le réglage restent, sans effet. Trois lignes commentées permettent de les retirer aussi.
- Les commandes et règlements écrits pendant l'arrondi restent tels quels.

## 6. Ce que je n'ai pas pu vérifier

- **La migration a tourné une fois, pour de vrai, sans dry run avant.** Deux commandes de test l'ont traversée le 04/11 (§4), aucune commande de client réel encore.
- **Seven pizza est bloqué depuis ce test.** Son portefeuille prépayé est passé de 0,001 à −3,799 DT, donc le compte est bloqué et les clients ne peuvent plus commander chez lui. Pour le débloquer, rechargez au moins 3,800 DT dans l'admin.
- **Docker abandonné.** L'essai sur une base jetable locale (04/11, avec votre accord) a échoué : Docker Desktop 4.74.0 plante au démarrage sur son fichier `AppData\Local\Docker\run\dockerInference`. Ni `Rename-Item`, ni `ren`, ni `mv` n'ont pu renommer ce fichier, et couper `EnableDockerAI` n'a rien changé. C'est un bug connu sous Windows. Le PostgreSQL installé sur ce PC ne contient que les outils en ligne de commande.
- **Le trigger des prix promo et la remise des codes promo** sont en place sur le live, mais aucune vraie promotion ni aucun code ne les a encore traversés. Le dry run teste le trigger des prix promo, pas les codes promo. Pour les codes, seule la formule a été vérifiée, et côté app partenaire, les tests Dart.
- **Écrans non ouverts.** La page Paramètres de l'admin demande une connexion admin, que je ne fais pas. Les apps n'ont pas été lancées sur un téléphone.
- **Commande créée avant la migration et livrée après :** ses commissions sont arrondies à la livraison, et le calcul garde la règle « le livreur garde la même somme ».
- **Si l'admin change le pas**, le serveur suit tout de suite. Les apps gardent 0,050 pour leurs aperçus (`kMoneyRoundingStep`) jusqu'à leur prochaine version ; le montant payé reste celui du serveur.
- **Prix saisis à la main, non arrondis :**
  - prix de base et variantes : 1 article sur 451 a un prix de base qui n'est pas un multiple de 0,050 ;
  - codes à montant fixe : il n'y en a aucun sur le live, les 3 codes sont en %.

## Annexe : la requête de vérification (lecture seule)

`round_money` y est écrit en ligne, car la fonction n'existe pas encore sur le live. Les colonnes `old_*` reprennent les formules live actuelles.

```sql
with rates as (
  select coalesce((select setting_value::numeric from public.global_settings
                    where setting_key = 'default_driver_commission_rate'), 0.23) as dr,
         coalesce((select setting_value::numeric from public.global_settings
                    where setting_key = 'default_restaurant_commission_rate'), 0.10) as mr,
         coalesce((select case when setting_value ~ '^\s*[0-9]*\.?[0-9]+\s*$' then trim(setting_value)::numeric end
                     from public.global_settings where setting_key = 'money_rounding_step'), 0.050) as step
),
cases (n, grp, label, price, hh_pct, km, milestone) as (values
  (1, 'A', '3 km, commande normale', 30.000, 0, 3.00, null),
  (2, 'A', '3 km, 5e commande',      30.000, 0, 3.00, 'half'),
  (3, 'A', '3 km, 10e commande',     30.000, 0, 3.00, 'free'),
  (4, 'B', '5 km, commande normale', 30.000, 0, 5.00, null),
  (5, 'B', '5 km, 5e commande',      30.000, 0, 5.00, 'half'),
  (6, 'B', '5 km, 10e commande',     30.000, 0, 5.00, 'free'),
  (7, 'C', 'Repas 30 DT Happy Hour -20 % (24 DT), 5 km, normale', 30.000, 20, 5.00, null),
  (8, 'C', 'Repas 30 DT Happy Hour -20 % (24 DT), 5 km, 5e',      30.000, 20, 5.00, 'half'),
  (9, 'C', 'Repas 30 DT Happy Hour -20 % (24 DT), 5 km, 10e',     30.000, 20, 5.00, 'free'),
  (10, 'D', '4,37 km, commande normale', 30.000, 0, 4.37, null),
  (11, 'D', '4,37 km, 5e commande',      30.000, 0, 4.37, 'half'),
  (12, 'D', '4,37 km, 10e commande',     30.000, 0, 4.37, 'free')
),
base as (
  select c.*, r.dr, r.mr, r.step,
         greatest(3.5 + greatest(c.km - 3, 0) * 0.5, 3.5) as fee_raw,
         round(c.price * (1 - c.hh_pct / 100.0), 3)       as sub_old
    from cases c cross join rates r
),
nouv as (
  select b.*,
         (round(b.fee_raw / b.step) * b.step)::numeric(12,3) as fee_new,
         least((round(b.price * (1 - b.hh_pct / 100.0) / b.step) * b.step)::numeric(12,3), b.price) as sub_new
    from base b
),
payes as (
  select n.*,
         case n.milestone when 'free' then 0::numeric
                          when 'half' then (round(n.fee_new * 0.5 / n.step) * n.step)::numeric(12,3)
                          else n.fee_new end as paid_new,
         case n.milestone when 'free' then n.fee_raw
                          when 'half' then round(n.fee_raw * 0.5, 3)
                          else 0 end as disc_old
    from nouv n
),
calc as (
  select p.*,
         p.fee_new - p.paid_new                                      as disc_new,
         (round(p.sub_new * p.mr / p.step) * p.step)::numeric(12,3)  as mcomm_new,
         (round(p.fee_new * p.dr / p.step) * p.step)::numeric(12,3)  as ncomm_new,
         (round(p.paid_new * p.dr / p.step) * p.step)::numeric(12,3) as pcomm_new,
         p.fee_raw - p.disc_old                                      as paid_old,
         round(p.sub_old * p.mr, 3)                                  as mcomm_old,
         round((p.fee_raw - p.disc_old) * p.dr, 3)                   as pcomm_old,
         case when p.milestone is null then 0 else round(p.disc_old * (1 - p.dr), 3) end as subs_old
    from payes p
),
fin as (
  select c.*,
         case when c.milestone is null then 0
              else (c.fee_new - c.ncomm_new) - (c.paid_new - c.pcomm_new) end as subs_new
    from calc c
),
res as (
  select f.n, f.grp, f.label,
         f.sub_new + f.paid_new                   as client_paie,
         f.sub_new - f.mcomm_new                  as commercant_net,
         f.pcomm_new                              as commission_livreur,
         f.subs_new                               as subvention,
         f.paid_new - f.pcomm_new + f.subs_new    as livreur_garde,
         f.mcomm_new + f.pcomm_new - f.subs_new   as plateforme,
         f.disc_new                               as remise,
         (f.ncomm_new - f.pcomm_new) + f.subs_new as cout_fidelite_plateforme,
         f.sub_old + f.paid_old                   as old_client_paie,
         f.sub_old - f.mcomm_old                  as old_commercant_net,
         f.pcomm_old                              as old_commission_livreur,
         f.subs_old                               as old_subvention,
         f.paid_old - f.pcomm_old + f.subs_old    as old_livreur_garde,
         f.mcomm_old + f.pcomm_old - f.subs_old   as old_plateforme
    from fin f
)
select r.*,
       (max(r.livreur_garde) over g = min(r.livreur_garde) over g) as livreur_garde_identique,
       (r.cout_fidelite_plateforme = r.remise)                     as cout_fidelite_egal_remise,
       (first_value(r.plateforme) over (partition by r.grp order by r.n) - r.plateforme = r.remise)
                                                                   as plateforme_perd_la_remise,
       (mod(r.client_paie * 1000, 50) = 0)                         as client_multiple_50,
       (mod(r.old_client_paie * 1000, 50) = 0)                     as old_client_multiple_50
  from res r
window g as (partition by r.grp)
 order by r.n;
```
