# Amana : réponses vérifiées à 5 questions du jury (4 novembre 2026)

Ce document répond à cinq questions que le jury peut poser. Chaque affirmation donne sa **source**, et rien n'a été modifié.

Comment lire les sources :
- `fichier:ligne` : le code du dépôt (`cmandili/` = app client, `cmandili_driver/`, `cmandili_partner/`, `cmandili_admin/`).
- « fonction live X » : la définition lue sur la base en production avec `SELECT pg_get_functiondef(...)`, le 4 novembre 2026.
- « SELECT live » : une requête de **lecture** lancée le 4 novembre 2026 sur la base de production (`supabase db query --linked`).
- « non vérifiable » : je n'ai pas pu le prouver.

Aucune valeur de clé n'apparaît ici. Pour reconnaître une même clé à plusieurs endroits, j'ai comparé leurs empreintes (SHA-256) et je leur donne seulement un nom de code : Maps-1, Firebase-A, etc.

Ce document reprend `presentation_assets/rapport_25_10.md` (l'argent) et `presentation_assets/deploiement.md` (les secrets). **Tous les chiffres ont été recalculés le 4 novembre** : ceux du 25/10 sont confirmés à l'identique. Deux faits sont nouveaux : 184 commandes au lieu de 173, et un doublon de subvention corrigé le 28/10 (section 3).

---

## 1. Les clés d'API

### La réponse en chiffres
Amana utilise **10 identifiants** :
- **9 clés d'API**, vers 5 services : Supabase (3), Firebase (3), Google Maps (1), OpenRouter (1), Gemini (1) ;
- **1 secret interne**, qui sert à la purge nocturne des comptes supprimés.

Parmi ces 10 identifiants :
- **5 sont publics par conception** et peuvent se trouver dans une app. La clé Google Maps en fait partie, mais elle doit être restreinte.
- **5 sont secrets** et ne vivent **que sur le serveur**.

### La liste
| # | Nom | Service | Où elle vit | Public ou secret ? | Source |
|---|---|---|---|---|---|
| 1 | `SUPABASE_ANON_KEY` (nouveau format `sb_publishable_…`) | Supabase | **dans les 3 apps mobiles**, compilée dans le code ; dans 7 fonctions SQL qui appellent la fonction `push-on-order-status` ; dans la tâche cron de purge | **Publique par conception** : elle ne donne que les droits définis par les règles RLS | `lib/core/config/build_config.dart:14` (même ligne dans le livreur et le partenaire) ; trouvée dans `libapp.so` des 3 AAB (scan) ; SELECT live sur `pg_proc` et `cron.job` |
| 2 | `NEXT_PUBLIC_SUPABASE_ANON_KEY` (ancien format JWT, `role=anon`) | Supabase | **tableau de bord admin**, envoyée au navigateur | **Publique par conception** | `cmandili_admin/lib/supabase.ts:6` ; trouvée dans 4 fichiers de `cmandili_admin/.next/static` (scan) |
| 3 | `SUPABASE_SERVICE_ROLE_KEY` / `SERVICE_ROLE_KEY` (JWT `role=service_role`) | Supabase, accès total qui ignore les règles RLS | serveur seulement : secrets des Edge Functions, et `cmandili_admin/.env.local` sur le PC, lu uniquement par le code serveur de Next.js | **SECRÈTE** | `cmandili_admin/lib/supabase-admin.ts:13`, `cmandili_admin/proxy.ts:44` ; `supabase secrets list` ; la valeur du `.env.local` correspond au secret serveur `SERVICE_ROLE_KEY` (comparaison d'empreintes) |
| 4 | `GOOGLE_MAPS_API_KEY` (**une seule clé**, « Maps-1 ») | Google Maps : cartes, itinéraires (Directions), recherche d'adresse (Places), carte de l'admin | **dans les 3 apps** et dans l'admin (`NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`) | **Visible dans l'app, c'est inévitable** : elle doit donc être **restreinte** dans Google Cloud. Restrictions actuelles : **non vérifiable** | `lib/core/config/build_config.dart:17` ; `android/app/src/main/AndroidManifest.xml:55` ; `ios/Runner/AppDelegate.swift:14` ; `cmandili_admin/components/LiveMap.tsx:100` |
| 5 | Clé Firebase Android (« Firebase-A ») | Firebase, identifie le projet pour les notifications | dans les 3 apps (`google-services.json`, `firebase_options.dart`) | **Publique par conception** | `lib/firebase_options.dart:53` ; `android/app/google-services.json:23` |
| 6 | Clé Firebase iOS (« Firebase-I ») | Firebase | dans les 3 apps iOS | **Publique par conception** | `lib/firebase_options.dart:61` |
| 7 | `FCM_SERVICE_ACCOUNT_JSON` | Firebase Cloud Messaging : **envoyer** les notifications | serveur seulement | **SECRÈTE** | `supabase/functions/push-on-order-status/index.ts:401` ; `supabase/functions/push-happy-hour/index.ts:254` |
| 8 | `OPENROUTER_API_KEY` | OpenRouter (modèles d'IA) | serveur seulement | **SECRÈTE** | `supabase/functions/ai-chat/index.ts:55` ; `supabase/functions/ai-search/index.ts:53` |
| 9 | `GEMINI_API_KEY` | Google Gemini (IA ; secours d'OpenRouter et lecture des menus en photo) | serveur seulement | **SECRÈTE** | `ai-chat/index.ts:60` ; `ai-search/index.ts:56` ; `cmandili_partner/supabase/functions/scan-menu/index.ts:18` |
| 10 | `PURGE_CRON_SECRET` | interne : la tâche cron prouve à la fonction de purge qu'elle est bien la tâche cron | serveur seulement : secrets des fonctions, et coffre-fort de la base (Vault, nom `purge_cron_secret`) | **SECRÈTE** | `supabase/functions/purge-deleted-accounts` (lit `PURGE_CRON_SECRET`) ; SELECT live sur `vault.secrets` (nom seulement) et sur `cron.job` (la tâche `account_deletion_purge` lit le Vault) |

Variables **fournies automatiquement** par Supabase aux Edge Functions (`supabase secrets list`) :
- `SUPABASE_URL` : une adresse, pas une clé.
- `SUPABASE_DB_URL` : contient le mot de passe de la base, donc **secrète**.
- `SUPABASE_SECRET_KEYS` : **secrète**.
- `SUPABASE_PUBLISHABLE_KEYS` et `SUPABASE_JWKS` : publiques.

### Une clé secrète est-elle dans une app ou dans un `.env` livré avec une app ? **Non.**
Vérifié de six façons :
1. **Les fichiers envoyés à Google Play** (les 3 AAB de `C:\Users\user\Desktop\amana-aab\`) ne contiennent que les identifiants n° 1, 4 et 5 : clé publique Supabase, clé Maps, clé Firebase.
   - Aucune clé `service_role`, aucune clé OpenRouter, aucune clé privée.
   - Aucun fichier nommé `.env`, `dart_defines`, `key.properties`, `.jks`, `.p8` ou `.pem`.
   - Source : scan en lecture de chaque fichier des AAB.
2. **Les fichiers `.env`** du client, du livreur et du partenaire ne sont **pas livrés** :
   - ils sont ignorés par git (`git check-ignore`) ;
   - aucune app ne les déclare comme ressource (`pubspec.yaml`) ;
   - aucun code ne les lit (pas de `flutter_dotenv` ; recherche de `dotenv` dans `lib/` : rien).
3. **Le navigateur de l'admin** ne reçoit que la clé publique n° 2. La clé `service_role` n'est dans aucun fichier de `cmandili_admin/.next/static` (scan de 52 fichiers). Elle n'a pas le préfixe `NEXT_PUBLIC_`, donc Next.js ne l'envoie jamais au navigateur.
4. **Les fichiers suivis par git** dans les 4 dépôts ne contiennent que des clés publiques : la clé Maps, les clés Firebase, et la clé publique Supabase dans des migrations SQL et deux fichiers de documentation (scan de 1 651 fichiers).
5. **La base de données** ne contient aucune clé secrète en dur. 7 fonctions SQL et la tâche de purge contiennent seulement la clé **publique**, et la purge lit son secret dans le Vault (SELECT live sur `pg_proc` et `cron.job` : on n'a lu que le *rôle* de chaque clé, jamais sa valeur).
6. **iOS :** le fichier final (IPA) est construit sur Codemagic et n'est pas sur ce PC, donc **non vérifiable** directement. Mais le script de build n'y injecte que 3 valeurs : `SUPABASE_URL`, `SUPABASE_ANON_KEY` et `GOOGLE_MAPS_API_KEY` (`C:\Users\user\Desktop\amana\codemagic.yaml:30-32`).

### Ce qu'il faut savoir quand même
- **Il reste une ancienne clé OpenRouter dans `cmandili/.env`** (ligne 16), sur le PC seulement.
  - Elle n'est ni livrée ni dans git (point 2), et son empreinte est **différente** de la clé du serveur.
  - Il vaut mieux la supprimer du fichier et la révoquer chez OpenRouter. Je ne l'ai pas testée : **non vérifiable** qu'elle soit encore valide.
- **La clé Maps est écrite en clair** dans deux fichiers suivis par git (`AndroidManifest.xml:55`, `AppDelegate.swift:14`). C'est normal pour une clé de carte mobile, à condition qu'elle soit restreinte par app et par API (point non vérifiable).
- **La fonction `notify-partner-order` attend un secret `GOOGLE_SERVICE_ACCOUNT` qui n'existe pas** (`supabase/functions/notify-partner-order/index.ts:67-69` ; absent de `supabase secrets list`). Elle n'est appelée ni par la base (SELECT live sur `pg_proc` : seule `push-on-order-status` est appelée) ni par les apps. C'est donc une ancienne fonction **inutilisée**.
- **Secrets de construction**, qui ne servent pas pendant le fonctionnement de l'app :
  - clés de signature Android et leurs mots de passe (`android/key.properties`, ignoré par git) ;
  - clé de l'API App Store Connect (`APP_STORE_CONNECT_PRIVATE_KEY`) ;
  - clé de distribution iOS (`CERTIFICATE_PRIVATE_KEY_B64`).
  - Les deux dernières sont rangées dans Codemagic (`C:\Users\user\Desktop\amana\codemagic.yaml:49,148-156`).

> **À dire au jury :** « Amana utilise 10 identifiants : 9 clés vers cinq services (Supabase, Firebase, Google Maps, OpenRouter, Gemini) et un secret interne. Les apps ne contiennent que des clés publiques par conception, protégées par les règles d'accès de la base. Toutes les clés secrètes, comme la clé d'administration Supabase et les clés d'IA, restent sur le serveur. Je l'ai vérifié dans les fichiers réellement envoyés à Google Play. »

---

## 2. Ce qui rend Amana différent

Seulement ce qui existe vraiment dans le code, avec sa preuve. **Une comparaison chiffrée avec les autres applications de livraison est non vérifiable dans le code**, donc je n'en fais pas.

| Point fort | Preuve dans le code | Preuve dans les données réelles (SELECT live) |
|---|---|---|
| **Plusieurs services dans une seule app** : repas, épicerie, boulangerie, fleurs, animaux, cadeaux, électronique, colis, factures | 11 types de commande (`lib/features/orders/data/models/order.dart:25-37`) ; le type suit la catégorie de la boutique (`order.dart:51-70`) | 22 commerces dans 7 catégories. 184 commandes : repas 124, colis 28, cadeaux 14, factures 14, électronique 3, fleurs 1 |
| **Une seule carte de fidélité pour tous les services** : 5ᵉ commande = livraison à moitié prix, 10ᵉ = livraison offerte | fonction live `apply_loyalty_at_checkout` ; seuls supermarché, épicerie et `billPayment` sont exclus (`supabase/migrations/20260930090000_order_type_per_category.sql:121`) | 46 commandes ont reçu un palier de fidélité |
| **Colis entre particuliers, avec preuve de remise** | téléphones de l'expéditeur et du destinataire (`lib/features/courier/presentation/courier/courier_controller.dart:26-28`) ; photo du colis (`courier_controller.dart:110`) ; **code à 4 chiffres créé par le serveur et caché au livreur** (fonction live `colis_bootstrap_receipt`) ; livraison bloquée ou signalée sans photo ni code (fonction live `colis_enforce_proof`) ; preuves dans un bucket **privé** `colis-proofs` | 28 commandes colis, 7 livrées. **Honnêtement :** le contrôle est en mode « souple » (`colis_proof_enforcement = soft`), il signale sans bloquer. Seuls 2 reçus existent, tous deux « preuve manquante » |
| **Paiement des factures locales** par un livreur : STEG, SONEDE, Topnet | `lib/features/facture/data/bill_type.dart:4-10` ; forfait de 5 DT (`lib/core/utils/delivery_fee.dart:17-22`) | 14 commandes « facture », 5 livrées |
| **Assistant IA qui parle derja**, y compris écrit en lettres latines (« n7eb », « chnoua »…) | règles de langue de l'assistant (`supabase/functions/ai-chat/index.ts:109-141`) ; derja = langue « tn » distincte du français (`ai-chat/index.ts:363-366`) ; assistant « pour Kairouan » (`ai-chat/index.ts:90`) | fonctions `ai-chat` (v21) et `ai-search` (v26) déployées (`supabase functions list`, 04/11) |
| **Recherche intelligente** (« un plat sain pas cher… ») qui ne tombe jamais sur zéro résultat | `supabase/functions/ai-search/` (commit `b7c38ee`, « relaxation ladder ») ; secours d'OpenRouter vers Gemini (commit `8022792`) | — |
| **Le commerçant photographie son menu, l'IA le saisit** | `cmandili_partner/lib/features/menu/data/menu_repository.dart:436-457` ; `scan-menu/index.ts:18,61` (Gemini) | `scan-menu` v41 déployée |
| **Commission basse et simple** : 10 % pour le commerçant, 23 % des frais de livraison pour le livreur | fonction live `generate_settlements_on_delivery` | `global_settings` : `0.10` et `0.23` |
| **Pensé pour Kairouan et la Tunisie** | la carte s'ouvre sur Kairouan (`lib/core/widgets/map_address_picker.dart:49-50`) ; prix au millime (colonnes `NUMERIC(12,3)`) ; préfixe +216 imposé (commit `4b12587`) ; paiement **en espèces** seulement (`checkout_controller.dart:148`) ; app en arabe, français et anglais (9 fichiers `app_ar/fr/en.arb`) | 184 commandes sur 184 payées en espèces |
| **Message vocal joint à la commande**, pour qui préfère parler qu'écrire | `lib/features/cart/presentation/cart/widgets/voice_recorder_section.dart` ; envoi (`lib/features/orders/data/order_placement_repository.dart:171-181`) | bucket `voice-messages`. **Attention : il est public** (voir `deploiement.md`) |
| **Commerçants et livreurs sans compte bancaire** : portefeuille prépayé ; la commission est prélevée dessus | fonctions live `generate_settlements_on_delivery` et `update_wallet_balance` | 18 recharges manuelles (`settlements`, type `manual_topup`) |

### Le point le plus fort : **une seule app pour toutes les courses du quotidien à Kairouan**
C'est le seul point fort prouvé à la fois par le code et par les vraies commandes :
- dans le code, 11 types de commande et une seule carte de fidélité pour presque tous ;
- dans les données, des commandes réparties sur 6 types différents (repas, colis, factures, cadeaux, électronique, fleurs).

Dans une ville moyenne comme Kairouan, réunir repas, commerces, colis et factures (STEG, SONEDE, Topnet) dans une même app donne aussi plus de courses à chaque livreur. C'est ce qui rend le service viable en dehors des grandes villes.

> **À dire au jury :** « Amana n'est pas seulement une app de restaurants. On y commande un repas, on achète chez sept types de commerces, on envoie un colis à un particulier et on fait payer sa facture STEG ou SONEDE, le tout payé en espèces et avec une seule carte de fidélité. Il y a aussi un assistant IA qui comprend la derja, même écrite en lettres latines. »

---

## 3. Fidélité et livreur (exemple : livraison à 5 km)

### Les règles, lues dans le code en production
- **Frais à 5 km :** 3,500 DT jusqu'à 3 km, puis 0,500 DT par km, soit 3,500 + 2 × 0,500 = **4,500 DT** (`lib/core/utils/delivery_fee.dart:13-15, 37-47`).
- **5ᵉ commande :** les frais sont divisés par 2. **10ᵉ commande :** les frais tombent à 0.
  - Le serveur baisse lui-même les frais et le total au moment où la commande est créée (fonction live `apply_loyalty_at_checkout` ; `supabase/migrations/20260814090000_loyalty_at_checkout.sql:80,83`).
  - La remise est notée dans `loyalty_discount_amount`.
- **À la livraison** (fonction live `generate_settlements_on_delivery`) :
  - commission livreur = **23 % des frais de livraison réellement payés par le client** (`20260814090000_loyalty_at_checkout.sql:195`) ;
  - subvention versée au livreur = **remise × (1 − 23 %) = 77 % de la remise** (`20260814090000_loyalty_at_checkout.sql:244`).

### Les chiffres (calculés par la base, avec ses propres arrondis au millime)
| Cas | Le client paie la livraison | Le livreur encaisse | Commission prise | Subvention versée | **Ce que garde le livreur** |
|---|---|---|---|---|---|
| Commande normale | 4,500 | 4,500 | 1,035 (23 %) | — | **3,465** |
| 5ᵉ commande (½) | 2,250 | 2,250 | 0,518 (23 % de 2,250) | +1,733 (77 % de 2,250) | **3,465** |
| 10ᵉ commande (offerte) | 0,000 | 0,000 | 0,000 (23 % de 0) | +3,465 (77 % de 4,500) | **3,465** |

Source : SELECT live qui applique les formules des fonctions avec les taux de `global_settings` et le type `NUMERIC(12,3)`. Par exemple, 2,25 × 0,23 = 0,5175, arrondi à **0,518**. Le résultat est identique au tableau du 25/10.

### Les réponses
- **Quel pourcentage la plateforme prend-elle au livreur ?** Toujours **23 % de ce que le client paie pour la livraison** : 0,518 DT à la 5ᵉ, 0 DT à la 10ᵉ.
  - Mais elle lui reverse 77 % de la remise.
  - Au final, la plateforme **ne prend rien** au livreur sur ces commandes : elle lui **verse** 1,215 DT net à la 5ᵉ (1,733 − 0,518) et 3,465 DT à la 10ᵉ.
- **Que garde le livreur ?** **Exactement la même chose qu'une commande normale : 3,465 DT**, soit 77 % des frais normaux. La fidélité ne lui coûte rien.
- **Qui paie la remise ? La plateforme, à 100 %, au millime près :**
  - 5ᵉ commande : elle perd 0,517 DT de commission (1,035 − 0,518) et verse 1,733 DT de subvention, soit **2,250 DT**, exactement la remise ;
  - 10ᵉ commande : 1,035 + 3,465 = **4,500 DT**, exactement la remise.
- **La règle « 23 % de commission sur ce que le client paie vraiment, plus 77 % de la remise crédités au livreur » : CONFIRMÉE**, avec deux précisions :
  - les 23 % portent sur les **frais de livraison** payés, pas sur le total de la commande (le repas n'entre pas dans ce calcul) ;
  - les 77 % ne sont pas fixés à la main : c'est `1 − taux livreur`. Si l'admin change le taux, la subvention suit toute seule (`20260814090000_loyalty_at_checkout.sql:244`).

### Conditions (fonctions live)
- La subvention n'est versée que si la commande est payée en espèces, livrée, et qu'un livreur Amana est assigné.
- **Si le commerçant livre lui-même** (`self_delivery`), il n'y a ni commission ni subvention : c'est lui qui encaisse des frais réduits.
- **Une commande compte dès qu'elle est passée**, pas à la livraison. Annuler une commande « palier » rend le palier ; annuler une commande normale ne le rend pas (fonction live `release_loyalty_slot_on_cancel`).

### Vérification sur les vraies commandes (SELECT live, 04/11)
Sur les **9 commandes fidélité livrées**, **7 respectent exactement la règle** (commission et subvention au millime). Deux anomalies, toutes deux anciennes :
- **16/08** (pendant les tests, le jour même où la remise a été branchée dans l'app, commit `dacf6b2`) : commission notée 9,488 DT au lieu de 0,403, et pas de subvention.
- **09/10 :** subvention versée **deux fois** (2,696 DT au lieu de 1,348).
  - **C'est corrigé depuis le 28/10** : un index unique empêche désormais deux règlements du même type pour une même commande (`supabase/migrations/20261028120000_security_lockdown.sql:197`, index `settlements_once_per_order` présent sur le live).
- Il existe aussi une subvention du 18/09 (2,695 DT) sans commande associée.

> **À dire au jury :** « À la 5ᵉ et à la 10ᵉ commande, la plateforme prend toujours 23 % des frais que le client paie vraiment, mais elle reverse au livreur 77 % de la remise. Résultat : le livreur garde 3,465 DT dans tous les cas, comme une livraison normale. C'est la plateforme qui paie toute la remise de fidélité, au millime près. »

---

## 4. La méthodologie

### Ce que dit le rapport
- `RAPPORT_AMANA_FINAL.tex:620-650` décrit une démarche **« itérative et agile »** : des cycles courts qui aboutissent chacun à une fonctionnalité testable, en référence au Manifeste Agile.
- Le tableau des itérations (`RAPPORT_AMANA_FINAL.tex:652-665`) en annonce **4, de mai à août 2026**.
- Le mot « Scrum » n'apparaît dans **aucune** source du rapport. « Sprints » n'apparaît qu'une fois, de façon informelle (`RAPPORT_PFE_AMANA.md:129`). Les fichiers `.tex` n'en parlent pas (0 occurrence).

### Ce que montre l'historique git (les 4 dépôts, branche `adam-branch`)
| Indicateur | Valeur | Source |
|---|---|---|
| Commits | **590** (client 338, livreur 102, partenaire 104, admin 46) | `git rev-list --count HEAD` |
| Période | du **24/04/2026** au **02/11/2026** | `git log` |
| Régularité | des commits dans **27 semaines sur 29** | `git log --date=format:%G-W%V` |
| Rythme mensuel | avril 1 · mai 19 · juin 53 · juillet 43 · août 69 · **septembre 122 · octobre 244** · novembre (1ᵉʳ–2) 39 | `git log`, tous dépôts |
| Petits commits typés (`feat`, `fix`, `refactor`…) | **478 sur 590** (81 %) : 165 `fix`, 134 `feat`, 95 `refactor`, 61 `chore` | `git log --format=%s` |
| Équipe | 2 développeurs (Adam : 456 commits, Firas : 134), 31 fusions de branches | `git shortlog -sn`, `git rev-list --merges` |
| Versions marquées (tags git) | **0** | `git tag` |
| Déploiements successifs | `ai-search` en est à sa 26ᵉ version, `push-on-order-status` à la 37ᵉ, `scan-menu` à la 41ᵉ | `supabase functions list` |

**Un écart à connaître :** le tableau du rapport s'arrête en août, alors que **69 % des commits** (405 sur 590) datent de septembre à novembre. D'après les sujets les plus fréquents dans les messages de commit, trois itérations de plus apparaissent :
- **5 · septembre :** base de données, connexion, admin, catégories de commerces, offres.
- **6 · octobre :** colis avec preuve, suppression de compte, assistant IA, vérification des livreurs, publication Android.
- **7 · novembre :** publication iOS (30 commits « ios » les 1ᵉʳ et 2 novembre).

### L'étiquette honnête
**« Développement itératif et incrémental, inspiré des principes agiles, sans cadre Scrum formel. »**
- **Agile et itératif :** des livraisons très fréquentes, de petits incréments, et des corrections qui viennent des essais réels.
- **Pas Scrum :** il n'y a ni sprints planifiés, ni backlog, ni rétrospectives, ni rôles Scrum dans les documents ou le dépôt, et aucune version n'est marquée par un tag.

### Deux itérations concrètes tirées de l'historique
**Itération A : le programme de fidélité** (dépôt client)
1. 06/07 : tables et registre des paiements aux livreurs (`fd26fc2`), puis indicateur de progression (`d3a2eb7`).
2. 07/07 : carte à tampons animée et écran des récompenses (`a6e9663`).
3. 16/08 : la vraie remise est appliquée par le serveur au moment de la commande (`dacf6b2`).
4. 20/08 : correction d'un décalage d'un tampon (`4a40174`).
5. 28/10 : verrou contre le double paiement d'une subvention, après le doublon du 09/10 (`294fee2`, `20261028120000_security_lockdown.sql:197`).

On voit le cycle complet : construire, mettre en service, observer les vraies données, corriger.

**Itération B : la recherche intelligente** (dépôt client, fonction `ai-search`)
1. 04/08 : traduction, pluriels arabes, « échelle de relâchement » pour ne jamais rendre zéro résultat (`b7c38ee`), secours vers Gemini (`8022792`).
2. 21/08 : limite de longueur des réponses (`e75e17f`).
3. 13/10 : le budget n'est plus relâché (`9fdf1f4`).
4. 25/10 : le plat demandé l'emporte sur la catégorie devinée (`de07787`).
5. 30/10 : aucune boutique ne cache les autres (`b2d2e0f`), les boutiques fermées restent visibles après les ouvertes (`9029c34`).
6. 01/11 : un résultat ouvre la boutique directement sur le plat (`a2634b2`).

Chaque étape est un petit changement, testé puis redéployé : la fonction en est à sa 26ᵉ version.

> **À dire au jury :** « Nous avons suivi une démarche itérative et incrémentale inspirée de l'Agile, sans appliquer Scrum à la lettre : pas de sprints formels, mais de petites livraisons presque chaque semaine, 590 commits en 27 semaines sur 29. Par exemple, la fidélité a été construite en juillet, appliquée par le serveur en août, puis corrigée en octobre après avoir observé un vrai cas de double paiement. »

---

## 5. Toutes les remises en même temps

### L'ordre des calculs
1. **Prix de l'article.** Si l'article est en Happy Hour ou en promotion, le panier prend le **prix réduit**.
   - Sources : `lib/features/cart/data/models/cart_item.dart:123-128` ; `lib/core/models/vendor.dart:153-161`.
   - Le Happy Hour écrit ce prix réduit dans `discount_price` (`cmandili_partner/lib/features/menu/data/menu_repository.dart:200-205`).
2. **Code promo.** C'est le **serveur** qui le calcule, en relisant lui-même les prix (fonction live `apply_promo_code`).
   - Il ne s'applique **qu'aux articles qui ne sont pas déjà en promotion** (lignes 142-156 de la fonction).
   - **Si tous les articles du panier sont déjà en promotion, le code est refusé** avec le message « Vos articles sont déjà en promotion : le code ne s'applique pas » (lignes 174-182).
   - L'app reprend le sous-total renvoyé par le serveur (`lib/features/checkout/presentation/checkout/checkout_controller.dart:255-277, 390`).
3. **Frais de livraison.** L'app les calcule selon la distance (`checkout_controller.dart:339-343` ; `delivery_fee.dart:37-47`).
   - Le code promo **ne touche jamais** les frais de livraison.
4. **Fidélité.** Au moment où la commande est enregistrée, le trigger `on_order_insert_loyalty` (fonction live `apply_loyalty_at_checkout`) baisse les **frais de livraison** :
   - de 50 % à la 5ᵉ commande ;
   - de 100 % à la 10ᵉ.
5. **À la livraison**, les commissions et la subvention sont calculées (section 3) : commerçant 10 % du sous-total, livreur 23 % des frais payés, subvention 77 % de la remise.

### Ce qui se cumule et ce qui ne se cumule pas
| Combinaison | Possible ? | Source |
|---|---|---|
| Happy Hour + code promo **sur le même article** | **Non** : le code ignore les articles déjà en promo | fonction live `apply_promo_code`, l. 142-156 et 174-182 |
| Happy Hour sur un article + code promo sur **un autre** article du panier | Oui | idem, l. 154-156 |
| Happy Hour + fidélité | Oui : l'un baisse l'article, l'autre la livraison | `apply_loyalty_at_checkout` |
| Code promo + fidélité | Oui, pour la même raison | idem |
| Deux codes promo sur une commande | Non : un seul code par commande | `checkout_controller.dart:257-264` (`promoState.appliedCode`) |
| Fidélité sur une commande de supermarché ou d'épicerie | Non : ces types sont exclus | `20260930090000_order_type_per_category.sql:121` |

### Les plafonds
- **70 % maximum** pour une promotion en pourcentage, mais **seulement dans l'app partenaire** (`cmandili_partner/lib/features/menu/presentation/promo_setup/promo_setup_controller.dart:148-152` ; `global_settings.max_discount_percent = 70`).
  - La base accepte jusqu'à 100 % (contrainte `vendor_items_discount_percent_check`).
- **Happy Hour :** le prix doit être supérieur à 0 et inférieur au prix normal (`.../happy_hour_setup/happy_hour_setup_controller.dart:152-157`). Il n'y a pas de plafond en pourcentage.
- **Code promo :**
  - un montant fixe ne dépasse jamais le total des articles concernés (fonction live, l. 187) ;
  - le sous-total ne descend jamais sous 0 (l. 189) ;
  - le serveur exige seulement une valeur supérieure à 0 (contrainte `promo_codes_value_check`).
- **Fidélité :** au plus, les frais de livraison complets.
- **Il n'existe pas de plafond global** sur le total de toutes les remises réunies.

### Exemple : repas de 30 DT, Happy Hour −20 %, code −10 %, livraison à 5 km
- Le Happy Hour met le repas à **24,000 DT**.
- Le code −10 % est **refusé** : le seul article du panier est déjà en promotion.
- Un vrai code −10 % existe sur le live (SELECT live sur `promo_codes`).

| Cas | Le client paie | Le commerçant reçoit | Commission commerçant (10 %) | Net commerçant | Le livreur garde | Gain final plateforme |
|---|---|---|---|---|---|---|
| Référence : sans aucune remise | 34,500 | 30,000 | 3,000 | 27,000 | 3,465 | **4,035** |
| **5ᵉ commande** + Happy Hour (code refusé) | **26,250** (24,000 + 2,250) | 24,000 | 2,400 | **21,600** | **3,465** (2,250 − 0,518 + 1,733) | **1,185** (2,400 + 0,518 − 1,733) |
| **10ᵉ commande** + Happy Hour (code refusé) | **24,000** (24,000 + 0) | 24,000 | 2,400 | **21,600** | **3,465** (0 − 0 + 3,465) | **−1,065** (2,400 + 0 − 3,465) |

Source : SELECT live qui applique les formules et les arrondis des fonctions.

**Qui a payé quoi ?** (5ᵉ commande ; mêmes principes pour la 10ᵉ)
- **Happy Hour (6 DT de remise) :** le **commerçant** en paie 5,400 DT (90 %) et la plateforme 0,600 DT (10 %, parce que sa commission baisse).
- **Fidélité (2,250 DT de remise) :** la **plateforme** paie tout (0,517 DT de commission en moins + 1,733 DT de subvention).
- **Le livreur ne perd rien :** 3,465 DT dans tous les cas.
- **La plateforme** gagne 1,185 DT à la 5ᵉ commande et **perd 1,065 DT à la 10ᵉ**. Le gain final est égal aux commissions moins la subvention.

**Variante, pour voir le code promo s'appliquer :** le même repas en Happy Hour, plus un jus à 5 DT qui n'est pas en promotion.

| Cas | Remise du code (10 % de 5 DT) | Sous-total | Le client paie | Net commerçant | Le livreur garde | Gain final plateforme |
|---|---|---|---|---|---|---|
| 5ᵉ commande | 0,500 | 28,500 | 30,750 | 25,650 | 3,465 | 1,635 |
| 10ᵉ commande | 0,500 | 28,500 | 28,500 | 25,650 | 3,465 | −0,615 |

Source : même SELECT live.

> **À dire au jury :** « Les remises s'appliquent dans l'ordre : d'abord le prix Happy Hour de l'article, puis le code promo calculé par le serveur sur les autres articles seulement, enfin la fidélité qui baisse la livraison. Un code promo ne s'ajoute jamais à un Happy Hour sur le même plat. Pour un repas de 30 DT en Happy Hour livré à 5 km, le client paie 26,250 DT à sa 5ᵉ commande et 24 DT à sa 10ᵉ ; le livreur garde toujours 3,465 DT, le commerçant paie la remise Happy Hour et la plateforme paie la fidélité. »
