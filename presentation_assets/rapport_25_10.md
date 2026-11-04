# Amana — rapport du 25/10/2026

Branche : `adam-branch` (client `7fd0912`, livreur `8c16624`, partenaire `9b7a669`, admin `5e17b4b`).
Base : projet Supabase live, **lecture seule** (uniquement des `SELECT`).

Comment lire les sources :
- `fichier:ligne` = code du dépôt ;
- « fonction live X » = définition lue sur le live avec `SELECT pg_get_functiondef(...)` ;
- « SELECT live » = requête de lecture lancée le 25/10 sur la base de production ;
- « non vérifiable » = je n'ai pas pu le prouver.

---

## 1. Tests

| App | Commande (lancée dans le dossier de l'app) | Résultat |
|---|---|---|
| Client (`cmandili/`) | `flutter test` | **327 / 327** réussis |
| Livreur (`cmandili_driver/`) | `flutter test` | **37 / 37** réussis |
| Partenaire (`cmandili_partner/`) | `flutter test` | **24 / 24** réussis |
| Admin (`cmandili_admin/`) | `npm test` (= `node --test "lib/**/*.test.ts"`, `cmandili_admin/package.json`) | **107 / 107** réussis |
| **Total** | | **495 / 495** réussis, 0 échec |

En plus de ces tests automatiques, le harnais SQL de suppression de compte
(`supabase/tests/account_deletion_test.sql`, tests T1 à T15) passe sur le live
dans une transaction annulée. Il a tourné une première fois le 25/10, avant
cette passe en lecture seule, et n'a pas été relancé ici.

---

## 2. L'argent

### 2.0 Le principe en une phrase

Le client paie **tout en espèces** au livreur. La plateforme ne touche pas cet
argent : elle prend ses commissions sur des **portefeuilles prépayés** que le
commerçant et le livreur rechargent à l'avance.

- Seul moyen de paiement proposé : `'cash'` (`lib/features/checkout/presentation/checkout/checkout_controller.dart:148`).
- Les 173 commandes du live sont toutes en `cash` (SELECT live sur `orders.payment_method`).
- Le commerçant reçoit le prix des articles en espèces par le livreur, et le
  portefeuille ne sert qu'à prélever la commission. C'est ce que dit le
  commentaire de la fonction live `generate_settlements_on_delivery`. La remise
  physique de l'argent elle-même est **non vérifiable** dans le code.

### 2.1 Les commissions

| Qui paie | Taux live | Calculé sur | Clé dans `global_settings` |
|---|---|---|---|
| Commerçant | **10 %** | le sous-total des articles (`subtotal`) | `default_restaurant_commission_rate` = `0.10` |
| Livreur | **23 %** | les frais de livraison (`delivery_fee`) | `default_driver_commission_rate` = `0.23` |

Source des taux : SELECT live sur `public.global_settings`.

- **Où c'est rangé :** dans la table `global_settings`, sous les clés ci-dessus.
- **Par catégorie ? Non.** La fonction live `generate_settlements_on_delivery`
  lit un seul taux commerçant (`default_restaurant_commission_rate`), pour tous
  les commerces.
  - Une clé `default_supermarket_commission_rate` = `0.10` existe, mais aucune
    fonction du live ne la lit (SELECT live sur `pg_proc.prosrc` : aucun résultat).
- **Si le commerçant livre lui-même** (`self_delivery`) : pas de commission
  livreur (fonction live `generate_settlements_on_delivery`).
- **Qui peut changer les taux :** seulement l'administrateur, depuis l'app admin.
  - La route `cmandili_admin/app/api/settings/route.ts` vérifie que l'utilisateur
    est admin (`requireAdmin`, ligne 6).
  - Elle refuse un taux hors de ]0 ; 1[ (lignes 13-14).
  - Elle écrit avec la clé service (`supabaseAdmin`, lignes 45-47).
  - Les apps ne peuvent pas modifier ces taux : `global_settings` n'a qu'une
    policy de **lecture** (`global_settings_select`, RLS activée ; SELECT live
    sur `pg_policies`).

### 2.2 Quand l'argent bouge

1. **À la livraison**, le trigger `on_order_delivered_settlements` (AFTER, sur
   `orders`) lance `generate_settlements_on_delivery` (SELECT live sur
   `pg_trigger`). Elle n'agit que si la commande passe à `delivered` et qu'elle
   est payée en `cash`. Elle :
   - calcule commission commerçant = `subtotal × 10 %` et commission livreur =
     `delivery_fee × 23 %` (`supabase/migrations/20260814090000_loyalty_at_checkout.sql:191` et `:195`) ;
   - inscrit ces deux montants sur la commande (`platform_fee`, `driver_fee_cut`) ;
   - crée une ligne **négative** dans `settlements` pour le commerçant et une pour
     le livreur (type `commission_deduction`) ;
   - si c'est une commande fidélité, crée une ligne **positive** pour le livreur
     (type `loyalty_subsidy`, voir 2.4).
2. **Chaque ligne de `settlements`** déclenche `update_wallet_balance`, qui
   ajoute le montant au solde du portefeuille (trigger
   `on_new_settlement_update_wallet` ; fonction live `update_wallet_balance`).
3. **Quand le solde touche 0**, le trigger `enforce_prepaid_block_trigger` sur
   `wallets` lance `enforce_prepaid_block` (fonction live ;
   `supabase/migrations/20260818190000_low_balance_warning.sql:47`). Si le
   compte est livreur ou partenaire et que le solde est ≤ `prepaid_min_balance`
   (= `0`, SELECT live) :
   - le portefeuille passe `blocked` ;
   - `drivers.is_blocked` / `partners.is_blocked` passe à `true` : le compte ne
     reçoit plus de commandes ;
   - une notification « Solde épuisé — compte bloqué » est envoyée une seule fois ;
   - dès que le solde repasse au-dessus de 0, le compte se débloque tout seul,
     sauf s'il avait été bloqué à la main.
4. **Alerte avant blocage :** un push « solde faible » part quand le solde
   descend dans la zone 2 à 4 DT (même fonction, ligne 88 du fichier ci-dessus).
5. **Recharger :** c'est l'admin qui ajoute une ligne `manual_topup` positive
   (`cmandili_admin/app/api/wallet/topup/route.ts:6` et `:77`).

### 2.3 Les frais de livraison

| Type de commande | Formule | Source |
|---|---|---|
| Restaurant et autres commerces | **3,500 DT jusqu'à 3 km, puis +0,500 DT par km en plus** | `lib/core/utils/delivery_fee.dart:13-15` et `:37-47` |
| Colis | Même formule | `lib/features/courier/presentation/courier/courier_controller.dart:433` |
| Supermarché | **Forfait 5 DT** | `lib/core/utils/delivery_fee.dart:22` ; `lib/features/cart/providers/cart_provider.dart:134` |
| Facture | **Forfait 5 DT** | `lib/features/facture/presentation/facture/facture_controller.dart:98` |

- La distance est celle de l'**itinéraire routier**
  (`LocationService.calculateRouteDistance`, `lib/core/utils/delivery_fee.dart:64`).
  Si elle est inconnue, le client paie le minimum de 3,500 DT.
- **Exemple à 5 km :** 3,500 + 2 × 0,500 = **4,500 DT**.
- **Calculé où ? Dans l'app client**, au moment de la commande
  (`checkout_controller.dart:339`).
  - Le serveur ne recalcule pas le prix de base.
  - Il ne fait que le réduire pour la fidélité (fonction live
    `apply_loyalty_at_checkout`, voir 2.4).
- Le réglage `rush_hour_multiplier` (= `1.0`) existe, mais **rien ne l'utilise** :
  aucune fonction du live (SELECT live sur `pg_proc.prosrc`) et aucune des apps
  (recherche dans `lib/` des trois apps Flutter).

### 2.4 La fidélité (5ᵉ commande = livraison à moitié prix, 10ᵉ = gratuite)

Source : fonction live `apply_loyalty_at_checkout` (trigger
`on_order_insert_loyalty`, BEFORE INSERT ;
`supabase/migrations/20260930090000_order_type_per_category.sql:110-121`) et
fonction live `release_loyalty_slot_on_cancel`.

- **Une commande compte au moment où elle est passée, pas à la livraison.** Le
  compteur `loyalty_customer_progress.delivered_count` monte à chaque nouvelle
  commande, malgré son nom.
- **Un seul compteur par client, pour tous les services** : repas, colis,
  facture, fleurs, cadeaux, électronique…
  - Seuls les types `supermarket`, `grocery` et `billPayment` sont exclus.
  - Les factures du live ont le type `facture` (SELECT live sur
    `orders.order_type`), elles **comptent donc** aussi.
- **Les paliers :**
  - compteur multiple de 10 → livraison **gratuite** ;
  - sinon, multiple de 5 → livraison **à moitié prix** (`20260814090000_loyalty_at_checkout.sql:80` et `:83`).
- **Pas de remise à zéro :** le cycle continue (15ᵉ = moitié, 20ᵉ = gratuite, etc.).
- **Annulation :**
  - si on annule la commande qui avait la remise, son tour est rendu (le
    compteur baisse de 1) ;
  - si on annule une commande normale, elle **reste comptée**.
- **Ce qui baisse :** seulement les frais de livraison, et donc le total.
- **Qui paie la remise ? La plateforme, à 100 %.** Le livreur encaisse moins en
  espèces, mais `generate_settlements_on_delivery` le rembourse :
  - subvention = remise × (1 − 23 %) = **77 % de la remise** (`20260814090000_loyalty_at_checkout.sql:244`) ;
  - la règle des 77 % est confirmée : c'est exactement 1 − le taux livreur ;
  - avec la commission qu'il paie déjà sur les frais réduits, le livreur garde
    **le même net qu'une livraison normale** (voir le tableau 2.7).

### 2.5 Happy Hour et promotions sur les articles

**Qui les crée :** le commerçant, dans l'app partenaire. Chaque catégorie de
commerce a un mode (`cmandili_partner/lib/core/providers/shop_settings_provider.dart:37`) :

| Mode | Pour qui | Ce que fait le commerçant | Source |
|---|---|---|---|
| **Happy Hour** | restaurants, boulangeries | met un **prix réduit**, avec une heure de fin et un nombre de portions s'il le veut | `cmandili_partner/lib/features/menu/data/menu_repository.dart:193-206` |
| **Promo en %** | autres commerces | met un **pourcentage**, avec une date de début et de fin s'il le veut | `menu_repository.dart:246-277` |

**Les limites :**
- **Plafond 70 %** (`global_settings.max_discount_percent` = `70`, SELECT live) :
  appliqué **seulement par l'app partenaire, et seulement aux promos en %**
  (`cmandili_partner/lib/features/menu/presentation/promo_setup/promo_setup_controller.dart:148-152`).
  - Le Happy Hour demande juste un prix entre 0 et le prix normal
    (`.../happy_hour_setup/happy_hour_setup_controller.dart:152-156`).
  - La base accepte jusqu'à 100 % (contrainte `vendor_items_discount_percent_check`).
  - Aucune fonction du live ne lit `max_discount_percent` (SELECT live).
- **Portions limitées :** le trigger `on_order_item_consume_happy_hour` (fonction
  live `consume_happy_hour_quantity`) décompte les portions vendues et arrête
  l'offre à 0.

**Tâches cron, chaque minute (SELECT live sur `cron.job`) :**

| Tâche | Ce qu'elle fait |
|---|---|
| `activate_scheduled_promotions` | pose le prix réduit à l'heure de début |
| `clear_expired_promotions` | efface les promos dont la date de fin est passée |
| `disable_happy_hour` | éteint l'ancien Happy Hour à horaire (`is_happy_hour`) après `happy_hour_end` |

**La notification `push-happy-hour` :**
- La fonction Edge est déployée (`supabase functions list`).
- Elle devait être appelée par un trigger `on_happy_hour_started`
  (`supabase/migrations/20260926130000_happy_hour_push.sql:21-50`).
- **Ce trigger n'existe pas sur le live** : la fonction `notify_happy_hour_started`
  est absente, `vendor_items` n'a aucun trigger utilisateur, et pg_stat_statements
  n'a aucune trace de sa création (SELECT live). **Aucun push Happy Hour ne part
  aujourd'hui.**

**La commission est calculée sur le prix réduit.**
- Le panier prend le prix réduit (`lib/features/cart/data/models/cart_item.dart:123-128`,
  `lib/core/models/vendor.dart:153-159`).
- Ce prix devient le `subtotal` de la commande, sur lequel on prend 10 %
  (`20260814090000_loyalty_at_checkout.sql:191`).

**Qui paie la remise ? Surtout le commerçant.** Il reçoit le prix réduit en
espèces et paie 10 % de ce prix réduit. Pour 6 DT de remise, il perd 5,400 DT et
la plateforme 0,600 DT (voir 2.7).

### 2.6 Les codes promo

Source : fonction live `apply_promo_code(uuid, text, jsonb, boolean)`
(`supabase/migrations/20260929100000_promo_codes_phase3.sql:96` et suivantes)
et SELECT live sur `promo_codes`.

| Règle | Détail |
|---|---|
| Types | `percentage` ou `fixed` (contrainte live). Le % est arrondi au millime, le montant fixe ne dépasse jamais le total concerné. |
| Commande minimale | `min_order_amount` |
| Limites | `max_uses` (au total) et `max_uses_per_customer` (par client, compté dans `user_promo_usages`) |
| Dates | `valid_from` et `expires_at` |
| 1ʳᵉ commande | `first_order_only` : refusé si le client a déjà une commande non annulée (`promo_codes_phase3.sql:223`) |
| Articles concernés | seulement les articles **qui ne sont pas déjà en promo** ou en Happy Hour (`promo_codes_phase3.sql:281-294`) ; si tout le panier est déjà en promo, le code est refusé |
| Frais de livraison | **jamais** : le code ne touche que les articles |
| Contrôle du prix | le serveur relit les prix lui-même ; l'app envoie les lignes du panier, pas un montant (`checkout_controller.dart:276`) |

**Qui les crée :**
- l'admin, depuis l'app admin (`cmandili_admin/app/api/promos/route.ts:7` vérifie
  l'admin, lignes 11-28 pour les champs) ;
- les apps ne peuvent que **lire** les codes actifs (policies live sur `promo_codes`) ;
- `first_order_only` **ne peut pas être réglé** depuis l'app admin (aucune
  occurrence dans `cmandili_admin/app`, `lib` ni `components`) : seulement en SQL. Aujourd'hui, 3 codes
  existent, tous en %, dont 1 réservé à la 1ʳᵉ commande (SELECT live).

**Qui paie la remise ? Le commerçant, à 90 %.**
- Le sous-total réduit est enregistré sur la commande
  (`checkout_controller.dart:390`). Le commerçant reçoit donc moins.
- Rien ne le rembourse : seule `generate_settlements_on_delivery` écrit dans
  `settlements`, et il n'existe aucun type « promo » (SELECT live sur `pg_proc`
  et sur la contrainte `settlements_type_check`).
- La plateforme perd seulement 10 % de la remise, parce qu'elle prend sa
  commission sur un montant plus petit.
- **Le livreur n'est pas touché :** ses frais ne changent pas.

> À dire franchement au jury : un code promo est créé par la plateforme mais,
> dans le code actuel, il est payé surtout par le commerçant.

### 2.7 Exemples chiffrés : un repas de 30 DT livré à 5 km

**Hypothèses :**
- frais de livraison 4,500 DT (2.3) ;
- commissions 10 % / 23 % ;
- Happy Hour : le commerçant met l'article à 24 DT (−20 %) ;
- code promo −10 % sur un article qui n'est pas en promo.

Les montants arrondis ont été calculés sur le live avec le même type
`NUMERIC(12,3)` que la fonction (SELECT live). Exemple : 2,25 × 0,23 = 0,5175 →
**0,518**.

| Cas | Le client paie (espèces) | Le commerçant reçoit | Commission commerçant | Net commerçant | Le livreur encaisse | Commission livreur | Subvention fidélité | Net livreur | Gain net plateforme |
|---|---|---|---|---|---|---|---|---|---|
| Normal | 34,500 | 30,000 | 3,000 | **27,000** | 4,500 | 1,035 | — | **3,465** | **4,035** |
| 5ᵉ commande (½ livraison) | 32,250 | 30,000 | 3,000 | **27,000** | 2,250 | 0,518 | +1,733 | **3,465** | **1,785** |
| 10ᵉ commande (livraison offerte) | 30,000 | 30,000 | 3,000 | **27,000** | 0,000 | 0,000 | +3,465 | **3,465** | **−0,465** |
| Happy Hour −20 % (24 DT) | 28,500 | 24,000 | 2,400 | **21,600** | 4,500 | 1,035 | — | **3,465** | **3,435** |
| Code promo −10 % | 31,500 | 27,000 | 2,700 | **24,300** | 4,500 | 1,035 | — | **3,465** | **3,735** |

Comment lire le tableau :
- **Le livreur gagne toujours 3,465 DT**, avec ou sans remise : la fidélité est
  compensée, et les promos ne touchent pas ses frais.
- **Fidélité :** c'est la plateforme qui paie. À la 10ᵉ commande, elle perd
  0,465 DT : elle verse 3,465 au livreur et ne gagne que 3,000 de commission.
- **Happy Hour et code promo :** c'est surtout le commerçant qui paie (−5,400 et
  −2,700 DT par rapport au cas normal). La plateforme ne perd que 0,600 et 0,300 DT.
- Gain net plateforme = commissions prélevées − subventions versées.

---

## 3. À exécuter dans la base

### 3.1 État des trois migrations sur le live (SELECT live)

`supabase_migrations.schema_migrations` n'a **aucune** ligne depuis le
01/10/2026 : on ne peut pas s'y fier. Chaque fichier a donc été vérifié par ce
qu'il crée.

| Migration | Ce qu'elle fait (en une phrase) | Sur le live ? | Preuve |
|---|---|---|---|
| `20261017090000_account_deletion.sql` | Crée la suppression de compte côté serveur : journal, blocages, anonymisation, purges, et protège l'historique en passant les liens en RESTRICT. | **Non** | `account_deletion_execute`, la table `account_deletions` et `profiles.deleted_at` sont absents ; `settlements_user_id_fkey` est encore en CASCADE |
| `20261022130000_record_live_user_fk_set_null.sql` | Écrit dans le dépôt que trois liens (commandes, paiements, primes) sont en SET NULL, comme sur le live. | **Jamais lancée, mais son effet est déjà là** | les trois liens sont en SET NULL et nullables ; aucune trace du fichier dans pg_stat_statements |
| `20261025120000_delete_my_account_via_account_deletion.sql` | Réécrit `delete_my_account()` (l'ancienne version de Firas) pour qu'elle passe par les contrôles de la suppression de compte. | **Non** | le corps live est encore celui de Firas (md5 `08f27a47…`) et n'appelle pas `account_deletion_execute` |

La trace pg_stat_statements n'est pas parfaite : elle a déjà perdu des entrées
(compteur `dealloc` = 3).

### 3.2 Ce qu'il faut appliquer ou déployer, dans l'ordre

Pour que le bouton « Supprimer mon compte » des apps d'`adam-branch` (client,
livreur, partenaire) marche de bout en bout :

1. **SQL :** `20261017090000_account_deletion.sql`. Elle crée
   `account_deletion_check` (appelée par les apps) et `account_deletion_execute`
   (appelée par l'Edge Function).
2. **SQL :** `20261022130000_record_live_user_fk_set_null.sql`. Elle ne change
   rien sur le live : c'est une vérification.
3. **SQL :** `20261025120000_delete_my_account_via_account_deletion.sql`. Elle
   ferme l'ancienne porte `delete_my_account()` et a besoin de l'étape 1.
4. **Déployer les Edge Functions** (terminal). Aujourd'hui, ni l'une ni l'autre
   n'apparaît dans `supabase functions list` :
   - `delete-account`, appelée par les apps ;
   - `purge-deleted-accounts`, la purge de nuit.

   Les deux sont en `verify_jwt = true` (`supabase/config.toml:42-50`).
5. **Le secret de la purge**, avec la même valeur des deux côtés
   (en-tête de `supabase/scripts/20261022_schedule_account_purge.sql`) :
   - `PURGE_CRON_SECRET` dans les secrets des fonctions ;
   - `purge_cron_secret` dans le Vault.

   Aujourd'hui : absent des deux côtés (`supabase secrets list` et SELECT live
   sur `vault.secrets`).
6. **SQL :** `supabase/scripts/20261022_schedule_account_purge.sql`, qui
   planifie la purge chaque nuit à 03:17 UTC. Aujourd'hui : pas de tâche
   `account_deletion_purge` dans `cron.job`.
7. **Les apps :** installer les builds d'`adam-branch`. Le serveur demande de
   s'être reconnecté depuis moins de 5 minutes ; l'écran le fait.

À part, sans lien avec la suppression :
`20261025150000_package_photos_delete_own_folder.sql` (3.3).

### 3.3 Nouvelle migration : `supabase/migrations/20261025150000_package_photos_delete_own_folder.sql`

**Le problème (SELECT live sur `pg_policies`) :** la policy
`package_photos_delete_own` autorise `bucket_id = 'package-photos' AND auth.uid() IS NOT NULL`.
N'importe quel compte connecté peut donc effacer **toutes** les photos de colis
et de factures des autres.

**La correction :** on ne peut effacer un fichier que s'il est dans **son**
dossier (`<user_id>/...`) **et** que c'est **soi** qui l'a déposé (`owner_id`).

**Pourquoi ça ne casse rien :**
- les apps rangent toujours les photos sous `<user_id>/`
  (`lib/core/data/package_photo_storage.dart:15` et `:28`) ;
- sur le live, les 25 fichiers du bucket respectent les deux conditions (SELECT live) ;
- les apps d'`adam-branch` ne suppriment jamais dans ce bucket ;
- les Edge Functions passent par la clé service, qui n'est pas soumise à ces policies.

**Où la lancer :** dans le **SQL Editor du dashboard**. Les policies de
`storage.objects` existantes y ont été créées (rôle `supabase_admin` d'après
pg_stat_statements). La table appartient à `supabase_storage_admin`, et la CLI
pourrait être refusée.

**Non lancée.** Seule la requête de vérification a tourné, en lecture : elle
répond aujourd'hui `policy_ok = false`, ce qui est normal avant la correction.

### 3.4 Ce que je dois lancer moi-même, dans l'ordre

Avant de commencer, lire chaque fichier dans l'éditeur. Après chaque étape,
lancer la vérification et comparer avec le résultat attendu.

1. **SQL Editor** : coller et lancer `supabase/migrations/20261017090000_account_deletion.sql`.

   ```sql
   select to_regprocedure('public.account_deletion_execute(uuid,text)') is not null as fonction_ok,
          to_regclass('public.account_deletions') is not null as journal_ok,
          (select confdeltype from pg_constraint where conname = 'settlements_user_id_fkey') = 'r' as lien_restrict;
   ```
   Attendu : `true`, `true`, `true`.

2. **SQL Editor** : lancer `supabase/migrations/20261022130000_record_live_user_fk_set_null.sql`.

   ```sql
   select conname, confdeltype from pg_constraint
    where conname in ('orders_user_id_fkey', 'payments_user_id_fkey', 'loyalty_driver_payouts_customer_id_fkey');
   ```
   Attendu : 3 lignes, toutes avec `n` (SET NULL).

3. **SQL Editor** : lancer `supabase/migrations/20261025120000_delete_my_account_via_account_deletion.sql`.

   ```sql
   select position('account_deletion_execute' in prosrc) > 0 as passe_par_les_controles
     from pg_proc where oid = 'public.delete_my_account()'::regprocedure;
   ```
   Attendu : `true`.

4. **SQL Editor** (contrôle complet, sans risque : le fichier finit par
   `rollback`) : lancer `supabase/tests/account_deletion_test.sql`.
   Attendu en dernière ligne :
   `T1 ok; T2 ok; T3 ok; T10 ok; T4 ok; T5 ok; T11 ok; T6 ok; T7 ok; T12 ok; T13 ok; T14 ok; T8 ok; T9 ok; T15 ok`.

5. **Terminal** : `supabase functions deploy delete-account`, puis
   `supabase functions deploy purge-deleted-accounts`.

   Vérification : `supabase functions list` montre les deux, en `ACTIVE`.

6. **Terminal + SQL Editor** : choisir une valeur secrète, puis la poser des deux côtés :
   - `supabase secrets set PURGE_CRON_SECRET=<valeur>` (terminal) ;
   - `select vault.create_secret('<valeur>', 'purge_cron_secret');` (SQL Editor).

   ```sql
   select count(*) as secret_present from vault.secrets where name = 'purge_cron_secret';
   ```
   Attendu : `1`. Vérifier aussi que `supabase secrets list` montre `PURGE_CRON_SECRET`.

7. **SQL Editor** : lancer `supabase/scripts/20261022_schedule_account_purge.sql`.

   ```sql
   select jobname, schedule, active from cron.job where jobname = 'account_deletion_purge';
   ```
   Attendu : 1 ligne, `17 3 * * *`, `true`.

8. **SQL Editor** : lancer `supabase/migrations/20261025150000_package_photos_delete_own_folder.sql`.
   La vérification est déjà à la fin du fichier.
   Attendu : 1 ligne, `policy_ok = true`, `delete_policies_on_bucket = 1`.

9. *(Facultatif, terminal)* Inscrire les fichiers dans l'historique des migrations :
   `supabase migration repair --status applied 20261017090000 20261022130000 20261025120000 20261025150000`.
   Ne pas utiliser `supabase db push`.

Quand plus aucun build de Firas n'appelle `delete_my_account()` (à vérifier dans
Play Console : client 1.0.2+5, livreur issu du commit `79ae1f5`), une seule
ligne suffira : `drop function if exists public.delete_my_account();`.
