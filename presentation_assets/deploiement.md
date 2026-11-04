# Amana : comment le projet est déployé (état vérifié le 4 novembre 2026)

Ce document explique ce qui est en ligne aujourd'hui, où, et comment. Chaque affirmation donne sa **source** : un fichier (`fichier:ligne`), une commande en lecture seule, ou une requête `SELECT`. Quand je n'ai pas pu vérifier, c'est écrit **« non vérifiable »**.

Aucune clé ni aucun mot de passe n'apparaît ici : seulement des **noms**.

Remarque sur les sources :
- Les commandes `supabase ...` ont été lancées le 4 novembre 2026 avec la CLI Supabase 2.100.1, liée au projet `cmandili`.
- La Play Console, la console Google Cloud et la console Supabase demandaient une reconnexion. Je ne me suis pas reconnecté. Ce qui vient de ces consoles a donc été **constaté pendant les sessions de travail du 2 et 3 novembre**, d'après le fichier de passation `HANDOFF_2026-11-02.md`, et **n'a pas été revérifié aujourd'hui**.

---

## 1. Supabase (le backend)

### Projet
| Élément | Valeur | Source |
|---|---|---|
| Nom du projet | `cmandili` | `supabase projects list` (ligne marquée ●, projet lié) |
| Référence | `hoqlxxtphskgxktqjpfu` | `supabase projects list` ; `supabase/config.toml:1` |
| Région | **West EU (Ireland)** | `supabase projects list` |
| PostgreSQL | 17.6 | `supabase/.temp/postgres-version` (17.6.1.063) |
| Plan (Free ou Pro) | **non vérifiable** (la CLI ne l'affiche pas, la console demandait une connexion) | — |

L'organisation contient deux autres projets (« cherif-adam's Project », « SureSeat ») qui ne servent pas à Amana (`supabase projects list`).

### Migrations
- **Fichiers dans le dépôt :** 111 fichiers `.sql` dans `supabase/migrations/` (`ls | wc -l`).
- **Historique enregistré sur la base en ligne :** **48 versions**, de `20260424` à **`20261030120000`** (la plus récente, `order_items_legacy_mirror`).
  - Source : `SELECT count(*), min(version), max(version) FROM supabase_migrations.schema_migrations`.
- **Comparaison avec `supabase migration list` :**
  - 45 versions présentes des deux côtés.
  - 67 fichiers du dépôt sans trace dans l'historique en ligne.
  - 4 versions enregistrées en ligne sans fichier local : `20260906120000`, `20260906130000`, `20260907180000`, `20260919120000`.

**Attention : « non enregistré » ne veut pas dire « non appliqué ».** Une partie des migrations a été appliquée à la main (éditeur SQL) sans être enregistrée dans l'historique. J'ai vérifié par échantillon, avec un `SELECT` sur les objets créés :

| Migration (non enregistrée) | Ce qu'elle crée | Présent en ligne ? |
|---|---|---|
| `20260915090000_order_ratings` | table `order_ratings` | **oui** |
| `20261011120000_receipt_confirmation_and_driver_ratings` | colonne `orders.client_confirmation` | **oui** |
| `20261015090000_driver_verification` | colonne `contract_scan_path` | **oui** |
| `20261017120000_delete_my_account` | fonction `delete_my_account` | **oui** |
| `20260928200000_promotions_phase1` | colonne `discount_mode` | **oui** |
| `20261012093000_package_photos_private` | règle `package_photos_read_scoped` + bucket privé | **non** (voir section 7) |

Source : un `SELECT` sur `to_regclass`, `information_schema.columns`, `pg_proc`, `pg_policies` et `storage.buckets`.

Conclusion : l'historique officiel des migrations est **incomplet**. Pour savoir si une migration est appliquée, il faut tester ses objets en ligne. Plusieurs fichiers partagent aussi le même numéro de version (par exemple `20260929100000`, deux fichiers ; `ls | cut -d_ -f1 | uniq -d`). Un `supabase db push` serait donc risqué.

### Edge Functions déployées
Source : `supabase functions list`.

| Nom | Version | Dernier déploiement (UTC) | Code source |
|---|---|---|---|
| `ai-search` | 26 | 2026-10-30 17:35 | `supabase/functions/ai-search/` |
| `ai-chat` | 21 | 2026-10-29 16:32 | `supabase/functions/ai-chat/` |
| `delete-account` | 2 | 2026-10-25 22:07 | `supabase/functions/delete-account/` |
| `purge-deleted-accounts` | 2 | 2026-10-25 22:08 | `supabase/functions/purge-deleted-accounts/` |
| `push-on-order-status` | 37 | 2026-10-13 15:34 | `supabase/functions/push-on-order-status/` |
| `push-happy-hour` | 4 | 2026-09-29 16:00 | `supabase/functions/push-happy-hour/` |
| `scan-menu` | 41 | 2026-09-18 22:16 | **dans le dépôt partenaire** : `cmandili_partner/supabase/functions/scan-menu/` |
| `notify-partner-order` | 8 | 2026-05-31 19:03 | `supabase/functions/notify-partner-order/` |

Les 8 fonctions sont **ACTIVE**. Chaque fonction a son code source dans un dépôt.

### Tâches planifiées (pg_cron)
Source : `SELECT jobid, jobname, schedule, active FROM cron.job`. La colonne `command` n'est pas affichée, car elle peut contenir un secret.

| Tâche | Fréquence | Active |
|---|---|---|
| `disable_happy_hour` | chaque minute | oui |
| `auto-close-restaurants` | toutes les 5 min | oui |
| `rotate-expired-offers` | toutes les 10 s | oui |
| `escalate-parcel-tier` | toutes les 10 s | oui |
| `cmandili_cancel_stalled` | toutes les 5 min | oui |
| `cmandili_alert_stalled_deliveries` | toutes les 5 min | oui |
| `offline_stale_drivers` | chaque minute | oui |
| `clear_expired_promotions` | chaque minute | oui |
| `activate_scheduled_promotions` | chaque minute | oui |
| `drivers_auto_offline_stale` | chaque minute | oui |
| `orders_auto_confirm_receipt` | chaque minute | oui |
| `account_deletion_purge` | tous les jours à 03:17 UTC | oui |

12 tâches, toutes actives. Deux tâches ont des noms très proches (`offline_stale_drivers` et `drivers_auto_offline_stale`) : un doublon possible, à vérifier (leur contenu n'a pas été lu ici).

### Stockage (buckets)
Source : `SELECT id, public, file_size_limit FROM storage.buckets`.

| Bucket | Public ? |
|---|---|
| `avatars` | public |
| `items` | public |
| `menu-images` | public |
| `profiles` | public |
| `receipts` | public |
| `voice-messages` | public |
| `package-photos` | **public** (devrait être privé, voir section 7) |
| `colis-proofs` | privé |
| `driver-contracts` | privé |

Aucun bucket n'a de taille maximale de fichier (`file_size_limit` vide).

### Fournisseurs de connexion activés
Source : l'endpoint public `GET /auth/v1/settings` du projet, lu avec la clé publique anon, qui n'est pas affichée.
- **Activés :** e-mail, **Google**, **Apple**.
- **Non activés :** téléphone (SMS) et tous les autres fournisseurs.
- Inscription ouverte (`disable_signup: false`). Confirmation d'e-mail automatique (`mailer_autoconfirm: true`).

### Secrets des Edge Functions (noms seulement)
Source : `supabase secrets list`, colonne NAME uniquement.

- `FCM_SERVICE_ACCOUNT_JSON`
- `GEMINI_API_KEY`, `GEMINI_SYSTEM_PROMPT`
- `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`
- `PURGE_CRON_SECRET`, `SERVICE_ROLE_KEY`
- Fournis automatiquement par Supabase : `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`, `SUPABASE_JWKS`, `SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`

---

## 2. Applications mobiles (client, livreur, partenaire)

### Versions et Android
Les dépôts sont : client = racine `cmandili/`, livreur = `cmandili_driver/`, partenaire = `cmandili_partner/`.

| | Client | Livreur | Partenaire |
|---|---|---|---|
| Nom sur Android | `com.amana.mobile` (`android/app/build.gradle.kts:41`) | `com.amana.driver` (`cmandili_driver/android/app/build.gradle.kts:41`) | `com.amana.partner` (`cmandili_partner/android/app/build.gradle.kts:43`) |
| Version dans le code | **1.0.2+7** (`pubspec.yaml:4`) | **1.0.0+2** (`cmandili_driver/pubspec.yaml:4`) | **1.0.0+2** (`cmandili_partner/pubspec.yaml:4`) |
| minSdk | 24 (`build.gradle.kts:44`) | 24 (`build.gradle.kts:44`) | 24 (`build.gradle.kts:46`) |
| targetSdk | 36 (`build.gradle.kts:45`) | 36 (`build.gradle.kts:45`) | `flutter.targetSdkVersion` (`build.gradle.kts:47`), soit 36 d'après la page de release Play du 2 nov. |

Android 7.0 (API 24) est donc la version minimale.

### Comment on construit
- **Format :** **AAB** (Android App Bundle), le format exigé par Google Play.
- **Commande :** `flutter build appbundle --release --dart-define-from-file=dart_defines.json` (`cmandili_driver/README.md:14`, `cmandili_partner/README.md:211`).
- Le fichier `dart_defines.json` est **ignoré par git** (`.gitignore:100`). Il contient trois noms de variables : `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_API_KEY`.
- Les fichiers produits (2 novembre) sont dans `C:\Users\user\Desktop\amana-aab\`.

### Signature (clé d'upload Google Play)
- Chaque `build.gradle.kts` lit `android/key.properties`, qui est ignoré par git (`build.gradle.kts:12-19`). La clé est **une clé d'upload**. Google Play re-signe ensuite les apps avec sa propre clé (Play App Signing).
- Le client et le livreur partagent une clé d'upload (empreinte qui commence par `30:52`). Le partenaire a la sienne (empreinte qui commence par `A7:58`).
  - Source : `keytool -printcert` et la page « Signature d'application » de Play, constatés le 2 nov. (`HANDOFF_2026-11-02.md`, section 2).
- Une copie des clés existe dans `Desktop\amana-keys-backup\`. Sa copie **hors du PC est non vérifiable**.

### Comment les apps arrivent aux utilisateurs
- **Google Play, piste « Tests fermés » (Alpha), pays : Tunisie.** Les trois apps ont été envoyées en examen le 2 nov. Le 3 nov., les fiches étaient « En ligne » et le test fermé publié (`HANDOFF_2026-11-02.md:95`).
- **Pas encore en production.** Google exige d'abord **12 testeurs inscrits pendant 14 jours** sur chaque app. Le 3 nov., le client affichait **« 0 testeur actuellement inscrit »** (`HANDOFF_2026-11-02.md:95`). La liste `amana_client_list` contient 13 adresses.
- **État Play aujourd'hui : non vérifiable** (la session Play demandait une connexion).
- **Différence importante entre Play et le code actuel :** les versions envoyées à Play ont été construites **avant** la mise à jour Firebase du 2 nov.
  - Aujourd'hui, le code utilise `firebase_core ^3.15.2` et `firebase_messaging ^15.2.10` (`pubspec.yaml:30-31`, commit `817574f`).
  - La prochaine version Android devra donc être testée sur un vrai téléphone (notifications), et recevoir un nouveau numéro de build.
- Avant Play, les apps étaient testées par APK installé à la main (`AUDIT_REPORT.md:6`, `flutter build apk --release`).

### iOS
Source : `HANDOFF_2026-11-02.md:76-101`, sauf mention contraire.
- **Compte Apple Developer :** payé et actif, au nom de Firas.
- **Pas de Mac :** les apps iOS sont construites dans le cloud par **Codemagic**. Le dépôt de build est `FirasMzoughi/amana`, une copie des 3 apps. Chaque dépôt contient un `codemagic.yaml` qui lance `flutter build ipa --release` (`codemagic.yaml:41`).
- **Identifiants iOS :** `com.amanatunisia.mobile`, `.driver`, `.partner` (`codemagic.yaml:23` ; `PRODUCT_BUNDLE_IDENTIFIER` dans les 3 `ios/Runner.xcodeproj/project.pbxproj`). L'identifiant `com.amana.mobile` était déjà pris chez Apple.
- **Les 3 apps sont dans TestFlight** (test interne) depuis la nuit du 2 nov. : « Amana Tunisia » 1.0.2 (9), « Amana Partner » 1.0.0 (10), « Amana Driver » 1.0.0 (11).
- **Pas encore sur l'App Store.** Manquent : captures d'écran, confidentialité de l'app, prix et disponibilité, compte de démonstration pour l'examen, puis l'envoi en examen.
- **Test sur iPhone :** « Se connecter avec Apple » fonctionne dans l'app client. La connexion Google sur iPhone a été corrigée côté Supabase mais **n'a pas été retestée** (`HANDOFF_2026-11-02.md:92,97`).

---

## 3. Tableau de bord admin (Next.js)

- **Hébergement :** **aucune trace d'un hébergement en ligne**.
  - Le dépôt `cmandili_admin` ne contient ni `vercel.json`, ni dossier `.vercel`, ni `Dockerfile`, ni `netlify.toml` (`ls -a`).
  - La mention « Deploy on Vercel » du `README.md:32` est le texte par défaut de Next.js.
  - Le fichier `dev.log` montre qu'il tourne **en local** (`next dev`).
  - Un hébergement fait hors du dépôt reste **non vérifiable**.
- **Framework :** Next.js 16.2.9 (`package.json`).
- **Commandes** (`package.json`, `scripts`) :
  - Développement : `npm run dev` (`next dev`).
  - Production : `npm run build` puis `npm run start` (`next build`, `next start`).
  - Tests : `npm test`. Lint : `npm run lint`.
- **Variables d'environnement** (noms seulement, `.env.example` et `process.env` dans le code) :
  - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` (clé serveur, ne jamais l'exposer au navigateur)
  - `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`

---

## 4. Services externes

### Firebase
- **Projet :** `cmandili-c1ade` (`android/app/google-services.json`, champ `project_id`, identique dans les 3 apps).
- **Fichiers de config :**
  - Android : `android/app/google-services.json` dans chaque app. Il déclare 6 apps Android : `com.amana.*` et les anciennes `com.cmandili.*`.
  - Toutes plateformes : `lib/firebase_options.dart`.
  - Racine : `firebase.json`.
- **Usage :** les apps n'utilisent que `firebase_core` et `firebase_messaging` (`pubspec.yaml`). Firebase sert donc **uniquement aux notifications push (FCM)**.
  - Côté serveur, l'envoi passe par le secret `FCM_SERVICE_ACCOUNT_JSON` des Edge Functions (`supabase secrets list`).
  - La connexion Google n'utilise **pas** Firebase Auth : elle passe par `google_sign_in` puis Supabase Auth.

### Google Maps
- **API utilisées dans le code :**
  - Directions API : `lib/core/services/route_service.dart:87`, `lib/core/utils/location_service.dart:128`, et `route_service.dart:87` dans le livreur et le partenaire.
  - Places API, recherche texte : `lib/core/widgets/map_address_picker/address_choice_screen.dart:93`.
  - Maps JavaScript API dans l'admin : `cmandili_admin/components/LiveMap.tsx:100`.
  - Cartes natives via `google_maps_flutter`, c'est-à-dire Maps SDK Android et iOS.
- **Où sont les clés (noms seulement) :**
  - `GOOGLE_MAPS_API_KEY` via `dart_defines.json` (`lib/core/config/build_config.dart:17`).
  - `com.google.android.geo.API_KEY` dans les manifestes Android (`android/app/src/main/AndroidManifest.xml:54` ; livreur `:75` ; partenaire `:76`).
  - `GMSServices.provideAPIKey` dans `ios/Runner/AppDelegate.swift:14`.
  - `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` dans l'admin.
- **Remarque :** dans les manifestes Android et `AppDelegate.swift`, la clé est **écrite en clair dans des fichiers suivis par git**. C'est normal pour une clé Maps SDK mobile, à condition qu'elle soit **restreinte** (par app et par API).
- **Restrictions des clés : non vérifiable** (la console Google Cloud demandait une connexion).

### IA (OpenRouter et Gemini)
- Les clés vivent **uniquement côté serveur**, dans les secrets Supabase `OPENROUTER_API_KEY` et `GEMINI_API_KEY` (`supabase secrets list`).
  - Elles sont lues par `supabase/functions/ai-chat/index.ts:55,60` et `supabase/functions/ai-search/index.ts:53,56`.
  - Modèle par défaut : `google/gemini-2.5-flash` via OpenRouter, avec Gemini en secours (`ai-chat/index.ts:58,62`).
  - La fonction `scan-menu` (lecture d'une photo de menu) appelle directement Gemini avec `GEMINI_API_KEY` (`cmandili_partner/supabase/functions/scan-menu/index.ts:18,61`).
- **Aucune app ne contient ces clés.** Une recherche de « OPENROUTER » et « GEMINI » dans `lib/` des 3 apps et dans l'admin ne trouve rien.
- Un fichier local `.env`, ignoré par git (`.gitignore:85`), contient encore un nom `OPENROUTER_API_KEY`. Aucune app ne le lit : c'est un reste à supprimer.

---

## 5. Git : où est le code le plus récent ?
Source : `git fetch` puis `git rev-list --left-right --count @{u}...HEAD` dans chaque dépôt, le 4 nov.

| Dépôt | Branche | Dernier commit | Poussé ? |
|---|---|---|---|
| Client `github.com/cherif-adam/cmandili_client` | `adam-branch` | `a82197a` (2 nov.) iPhone seulement | **oui** (0 en avance, 0 en retard) |
| Livreur `github.com/cherif-adam/cmandili_driver` | `adam-branch` | `d32def7` (2 nov.) connexion Apple | **oui** |
| Partenaire `github.com/cherif-adam/cmandili_partner` | `adam-branch` | `dc08b31` (2 nov.) connexion Apple | **oui** |
| Admin `github.com/cherif-adam/cmandili_admin` | `adam-branch` | `a22d7d0` (26 oct.) | **oui** |

**Encore seulement en local :**
- Dans le dépôt client, des fichiers non suivis : `presentation_assets/` (dont ce document), `store_assets/`, `HANDOFF_2026-11-02.md`, `supabase/functions/ai-search/deno.lock`.
- Dans le livreur et le partenaire, seul `macos/Flutter/GeneratedPluginRegistrant.swift` diffère (fichier généré, sans importance).
- Le dépôt client référence d'anciennes versions des dépôts livreur, partenaire et admin (`git status` : « M cmandili_driver… »). Ce n'est qu'un pointeur : le code est bien sur GitHub dans chaque dépôt.
- La branche `main` existe mais n'est pas la branche de travail : tout le travail récent est sur `adam-branch`.
- Le build iOS utilise une copie séparée, `FirasMzoughi/amana` (`HANDOFF_2026-11-02.md:76`).

---

## 6. Étapes pour sortir une nouvelle version (dans l'ordre)

1. **Base de données (migration).**
   - Écrire `supabase/migrations/<date>_<nom>.sql`.
   - La tester d'abord dans une transaction annulée (`BEGIN … ROLLBACK`).
   - L'appliquer sur le projet en ligne, depuis l'éditeur SQL ou `supabase db query --linked -f fichier.sql`.
   - **L'enregistrer** dans l'historique (`supabase migration repair --status applied <version>`).
   - Vérifier par un `SELECT` que les objets existent.
   - Éviter `supabase db push`, car l'historique est incomplet (section 1).
2. **Edge Function** (si elle change) : `supabase functions deploy <nom>`. Vérifier avec `supabase functions list`, le numéro de version doit augmenter. Ajouter un secret si besoin : `supabase secrets set NOM=...`.
3. **Apps mobiles.**
   - Augmenter `version:` dans `pubspec.yaml`. Le numéro après le `+` doit monter.
   - Lancer les tests : `flutter test`.
   - Construire l'AAB : `flutter build appbundle --release --dart-define-from-file=dart_defines.json`, avec `key.properties` présent, sinon le build est signé en debug.
   - Importer l'AAB dans la Play Console (piste de test, puis production).
   - Pour iOS : pousser le code vers `FirasMzoughi/amana`, lancer le workflow Codemagic (`ios-client`, `ios-driver` ou `ios-partner`). Le build arrive dans App Store Connect, puis dans TestFlight, puis en examen Apple.
4. **Tableau de bord admin :** `npm run build` puis `npm run start` sur la machine qui l'héberge (aujourd'hui en local).

L'ordre compte : la base passe toujours en premier. Une app ne doit jamais appeler une colonne ou une fonction qui n'existe pas encore en ligne.

---

## 7. Ce qui n'est pas encore déployé ou reste en attente

| Sujet | État vérifié | Source |
|---|---|---|
| **Correctif `package_photos` (photos de colis privées)** | **NON appliqué.** Le bucket `package-photos` est **public**, l'ancienne règle de lecture ouverte `package_photos_read` existe, et la règle `package_photos_read_scoped` n'existe pas. | `SELECT` sur `storage.buckets` et `pg_policies` ; fichier `supabase/migrations/20261012093000_package_photos_private.sql:27,34` |
| Suppression de compte (migrations) | **Appliquée** : la fonction `delete_my_account` existe, et les versions `20261025120000` et `20261025150000` sont enregistrées. | `SELECT` sur `pg_proc` ; `supabase migration list` |
| Edge Function `delete-account` | **Déployée** (v2, 25 oct.) | `supabase functions list` |
| Purge des comptes supprimés | **Active** : fonction `purge-deleted-accounts` v2 et tâche cron `account_deletion_purge` à 03:17 UTC | `supabase functions list` ; `SELECT … FROM cron.job` |
| Historique des migrations | 67 fichiers sans trace en ligne. La plupart sont appliqués sans être enregistrés (section 1). | `supabase migration list` + `SELECT` |
| Production Google Play | En attente : 12 testeurs inscrits pendant 14 jours sur chaque app, puis demande d'accès en production. | `HANDOFF_2026-11-02.md:95,99` |
| Nouvelle version Android avec Firebase 3.15 / 15.2 | Code prêt mais pas encore publié. Notifications à tester sur un vrai téléphone. | `pubspec.yaml:30-31` ; commit `817574f` |
| App Store (iOS) | En TestFlight seulement. Fiches, captures et examen Apple pas encore faits. | `HANDOFF_2026-11-02.md:91,96` |
| Connexion Google sur iPhone | Corrigée côté Supabase, pas retestée | `HANDOFF_2026-11-02.md:97` |
| Révocation du jeton Apple à la suppression de compte (règle Apple 5.1.1(v)) | Pas fait | `HANDOFF_2026-11-02.md:102` |
| Hébergement en ligne de l'admin | Aucun (local seulement) | section 3 |
| Copie des clés de signature hors du PC | **non vérifiable** | `HANDOFF_2026-11-02.md`, section 7 |

---

## 8. Coûts mensuels

| Poste | Coût | Source |
|---|---|---|
| Supabase | **non vérifiable** (plan Free ou Pro non visible) | — |
| Compte développeur Google Play | Paiement unique, pas mensuel. Montant payé **non vérifiable**. | — |
| Compte Apple Developer | Abonnement annuel, actif au nom de Firas. Montant payé **non vérifiable**. | `HANDOFF_2026-11-02.md:76` |
| Codemagic (builds iOS) | Offre gratuite utilisée d'après les notes. Facturation **non vérifiable**. | `HANDOFF_2026-11-02.md:53` |
| IA (OpenRouter, Gemini) | **non vérifiable** (aucun accès aux tableaux de facturation) | — |
| Google Maps, Firebase | **non vérifiable** | — |

---

## 9. Schéma simple

```
   [App client]   [App livreur]   [App partenaire]      [PC admin : Next.js en local]
     Android + iOS (Flutter)                              navigateur
          |               |               |                     |
          +-------+-------+-------+-------+---------------------+
                          | HTTPS (clé publique anon + session utilisateur)
                          v
        +--------------------------------------------------+
        |  SUPABASE  (projet "cmandili", Irlande)          |
        |  - PostgreSQL 17 : tables, règles RLS, 12 cron   |
        |  - Auth : e-mail, Google, Apple                  |
        |  - Storage : 9 buckets (photos, reçus, contrats) |
        |  - 8 Edge Functions (Deno)                       |
        +--------------------------------------------------+
            |                  |                    |
            v                  v                    v
   [Firebase FCM]       [OpenRouter / Gemini]   [Google Maps]
   notifications push   recherche et chat IA    cartes (SDK dans les apps)
   vers les téléphones  (ai-search, ai-chat,    + Directions / Places
                         scan-menu)              appelées par les apps

   Distribution : Google Play (test fermé) pour Android,
                  Codemagic -> App Store Connect -> TestFlight pour iOS.
```
