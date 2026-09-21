# HANDOFF — Projet Amana

Document généré le 2026-09-04 à partir d'une lecture directe des fichiers du dépôt `C:\Users\user\Desktop\cmandili` (4 applications + base Supabase + rapport LaTeX). Chaque fait est accompagné du fichier et de la ligne où il a été vérifié. Tout ce qui n'a pas pu être confirmé dans les fichiers est marqué **À VÉRIFIER**.

Ce document sert de contexte à un assistant IA qui n'a accès à aucun fichier du projet — il doit pouvoir répondre à des questions précises sur le projet sans rien inventer.

---

## SECTION 1 — Le projet en une page

**Amana** (anciennement "Cmandili") est une plateforme de livraison multiservices en phase pilote à Kairouan, Tunisie. Un client peut, depuis une seule application : commander un repas dans un restaurant partenaire, faire ses courses dans un supermarché partenaire, envoyer un colis à une autre personne (livraison entre particuliers, sans commerçant), ou faire payer une facture (Topnet, STEG, SONEDE, autre) par un livreur.

**Où en est le projet :** phase de test, pas encore publié. Citation exacte du rapport : *« Au moment de la rédaction de ce rapport, la plateforme Amana est déployée dans un cadre de test~: le backend Supabase est hébergé en ligne et accessible en continu [...] »* — `rapport_final.tex:1898`. Les 3 apps mobiles sont installées manuellement sur des téléphones Android pour les tests, aucune n'est publiée sur un store officiel (Google Play / App Store) — pas de citation ligne précise trouvée pour ce dernier point dans `rapport_final.tex` au moment de l'audit, **À VÉRIFIER** si cette phrase existe encore telle quelle.

**Les 4 applications :**

| Application | Rôle | Techno | Dossier |
|---|---|---|---|
| Client (`cmandili_mobile`) | Grand public — commande, suivi, colis, facture, assistant IA | Flutter | racine du dépôt, `lib/` |
| Livreur (`cmandili_driver`) | Réception d'offres, livraison, portefeuille | Flutter | `cmandili_driver/` |
| Partenaire (`cmandili_partner`) | Gestion du catalogue et des commandes reçues | Flutter | `cmandili_partner/` |
| Administrateur (`cmandili_admin`) | Supervision de la plateforme, tableau de bord web | Next.js/TypeScript | `cmandili_admin/` |

**Stack technique — versions réelles :**

| Élément | Version | Source |
|---|---|---|
| Flutter/Dart SDK (3 apps mobiles) | `'>=3.0.0 <4.0.0'` | `pubspec.yaml:7` (identique dans les 3 apps) |
| flutter_riverpod | `^2.4.9` | `pubspec.yaml:16` (identique dans les 3 apps) |
| supabase_flutter | `^2.3.0` | `pubspec.yaml:27` (client/partner), `:25` (driver) |
| mapbox_maps_flutter | `^2.3.0` | `pubspec.yaml:35` (client), `:28` (driver), `:30` (partner) |
| firebase_messaging | `^14.7.20` | `pubspec.yaml:31` (client), `:20` (driver/partner) |
| geolocator | `^10.1.0` | `pubspec.yaml:36` (client), `:29` (driver) — **absent du `pubspec.yaml` du partner**, aucun import `package:geolocator` trouvé dans `cmandili_partner/lib` |
| google_sign_in | `^6.1.6` | `pubspec.yaml:24` (toutes) |
| Next.js (admin) | `16.2.9` (fixe, sans `^`) | `cmandili_admin/package.json:17` |
| React (admin) | `19.2.4` | `cmandili_admin/package.json:18` |
| TypeScript (admin) | `^5` | `cmandili_admin/package.json:30` |
| @supabase/supabase-js (admin) | `^2.108.1` | `cmandili_admin/package.json:13` |
| @supabase/ssr (admin) | `^0.12.0` | `cmandili_admin/package.json:12` |
| Tailwind CSS (admin) | `^4` | `cmandili_admin/package.json:29` |
| PostgreSQL | **17.6** (corrigé) — voir discrépance en Section 3 | `rapport_final.tex:967`, confirmé par `cmandili_context.md:9` |

---

## SECTION 2 — Le contexte académique

**Diplôme :** Mastère Professionnel en Réseaux et Applications Distribuées — `rapport_final.tex:168`.
**Institution :** Institut Supérieur d'Informatique et de Gestion de Kairouan (ISIGK), Université de Kairouan — page de garde, `rapport_final.tex:99-115` (zone logo/en-tête).
**Étudiant :** Adam Cherif — `rapport_final.tex:176`.
**Encadreur :** Mme Olfa Harrabi — `rapport_final.tex:178` et `:191`.
**Jury (président, rapporteur) :** vide (`\hrulefill`) — `rapport_final.tex:189-190` — **À VÉRIFIER**, à compléter par l'étudiant.
**Date de soutenance :** vide (`\hrulefill`) — `rapport_final.tex:196` — **À VÉRIFIER**.
**Année universitaire :** 2025 / 2026 — `rapport_final.tex:199`.

Le fichier `.tex` lui-même marque 3 endroits comme non finalisés avec des commentaires `% VERIFIER` : l'intitulé exact du diplôme (`:166`), le sous-titre du mémoire (`:171`), et la composition du jury (`:187`).

**Fichier du rapport et taille :** deux fichiers `.tex` existent à la racine du dépôt. Comparaison :

| Critère | `rapport.tex` | `rapport_final.tex` |
|---|---|---|
| Taille | 91 403 octets, 1628 lignes | 137 652 octets, **2016 lignes** |
| Dernière modification | 2026-08-11 | 2026-08-26 (15 jours plus récent) |
| Nombre de `\chapter` | 4 | **8** (5 chapitres numérotés + intro + conclusion générale + annexes) |
| Bibliographie imprimée | absente | présente (`:1956`, `:1960`) |
| Conclusion générale | absente | présente (`:1930`) |
| Annexes | absentes | présentes (`:1965`) |
| Page de titre | générique, incomplète | formelle, avec diplôme/jury/sous-titre |

**`rapport_final.tex` est le fichier canonique** : plus complet et plus récent sur tous les critères. `rapport.tex` est une version antérieure incomplète, à ignorer.

Nombre de pages réel : **À VÉRIFIER — nécessite une compilation PDF**, non calculable depuis le texte source.

**Le plan officiel de l'encadrant : NON TROUVÉ dans les fichiers du dépôt.** Recherche faite dans les 6 fichiers markdown à la racine (`ARCHITECTURE_REPORT.md`, `AUDIT_REPORT.md`, `CMANDILI_FULL_DOCUMENTATION.md`, `RAPPORT_PFE_AMANA.md`, `RESUME.md`, `cmandili_context.md`) pour les motifs "encadr", "plan officiel", "chapitre", "structure du rapport", "sommaire" — zéro résultat pertinent dans les 6. **À VÉRIFIER / à fournir directement** — ce plan a été discuté verbalement dans une session de travail précédente avec un assistant IA mais n'a jamais été sauvegardé dans un fichier du dépôt. Si vous l'avez encore sous la main, collez-le directement dans la conversation avec l'autre assistant plutôt que de vous fier à ce document pour ça.

### Table des matières complète de `rapport_final.tex`, avec état par section

Légende : **rédigée** = paragraphes substantiels réels ; **ébauche** = titre présent mais contenu TODO/placeholder/une phrase.

**Introduction générale** (`:261`) — rédigée.

**Chapitre 1 — Cadre du projet et expression des besoins** (`:285`) — entièrement rédigé, 12 sections (Présentation générale, Contexte et enjeux, Présentation des services, Analyse des solutions existantes, Limites des solutions existantes, Solution proposée, Cahier des charges, Identification des acteurs, Besoins fonctionnels, Besoins non fonctionnels, Contraintes du projet, Méthodologie de travail, Conclusion) — toutes rédigées.

**Chapitre 2 — Analyse et conception du système** (`:642`) — entièrement rédigé, 8 sections (Identification des fonctionnalités, Diagramme de cas d'utilisation, Description des cas d'utilisation, Architecture générale, Modélisation des données, Diagrammes de séquence, Conception des interfaces, Conclusion) — toutes rédigées.

**Chapitre 3 — Réalisation technique** (`:1298`) — entièrement rédigé, 8 sections (Environnement de développement, Technologies utilisées, Organisation du code, Implémentation du back-end, Sécurité de l'application, Intégration de l'IA, Gestion des paiements/commissions/récompenses, Conclusion) — toutes rédigées.

**Chapitre 4 — Présentation des applications et des interfaces** (`:1443`) — texte entièrement rédigé, **mais captures d'écran très majoritairement manquantes** (détail en Section 6) :

| Section | Ligne | Texte | Captures illustrées |
|---|---|---|---|
| Application client | 1449 | rédigée | 4 sur 6 sous-sections |
| Application livreur | 1547 | rédigée | **0 sur 6** |
| Application partenaire | 1623 | rédigée | **0 sur 5** |
| Application administrateur | 1687 | rédigée | **0 sur 6** |
| Conclusion | 1781 | rédigée | — |

**Chapitre 5 — Tests, déploiement et maintenance** (`:1786`) — texte entièrement rédigé (Introduction, Tests fonctionnels avec 6 sous-tests, Tests des interfaces, Gestion des erreurs, Déploiement, Maintenance, Conclusion), **mais toutes les captures d'écran de ce chapitre sont en TODO** (0 image présente sur les 8 demandées).

**Conclusion générale** (`:1930`) — rédigée, 4 sous-sections (Récapitulatif, Principales fonctionnalités, Apports professionnels, Évolutions possibles).

**Annexes** (`:1965`) — état mixte :
- Captures d'écran supplémentaires (`:1969`) — **ébauche**, une phrase + TODO, rien d'autre.
- Extraits de code importants (`:1975`) — rédigée, 2 vrais extraits `verbatim`.
- Documentation technique complémentaire (`:2009`) — **ébauche**, une phrase + TODO, rien d'autre.

---

## SECTION 3 — Chiffres exacts dont dépend le rapport

| Donnée | Valeur réelle (code) | Source | Ce que dit le rapport | Écart ? |
|---|---|---|---|---|
| Délai avant réassignation (1ère offre) | **30 secondes** | `dispatch_driver_for_order(p_window_secs DEFAULT 30)`, `supabase/migrations/20260605_dispatch_on_confirmed.sql:85-89` (path principal) | « délai d'environ 30~secondes » — `rapport_final.tex:1368` | Correct pour la 1ère offre |
| Délai avant réassignation (offres suivantes) | **10 secondes** | `offer_order_to_driver(p_window_seconds DEFAULT 10)`, `supabase/migrations/20260510_assignment_and_distance.sql:109-112`, utilisé par `rotate_expired_offers()` pour toute réattribution après la 1ère | Le rapport ne mentionne que 30s, présenté comme valable pour toute la cascade | **OUI — le rapport dit 30s partout, mais seule la 1ère offre dure 30s ; chaque réattribution suivante ne dure que 10s.** À corriger avant la soutenance. |
| Rayon de recherche du livreur | **7 km** | `next_eligible_driver`, `supabase/migrations/20260510_assignment_and_distance.sql:61` ; confirmé identique dans 3 autres fichiers | « rayon d'environ 7~km » — `rapport_final.tex:1368` | Aucun écart |
| Fréquence/seuil de mise à jour GPS livreur | Pas d'intervalle de temps fixe — déclenchement uniquement après **30 mètres** de déplacement | `Geolocator.getPositionStream(distanceFilter: 30)`, `cmandili_driver/lib/core/services/background_location_service.dart:306-310` | « à chaque déplacement d'environ 30~mètres » — `rapport_final.tex:1368` | Aucun écart sur le service principal. Non mentionné : un second flux concurrent à `distanceFilter: 10` tourne aussi quand l'écran de suivi du livreur est ouvert (`cmandili_driver/lib/features/orders/presentation/order_tracking_screen.dart:108-112`) — nuance absente du rapport, pas forcément à corriger. |
| Intervalle de rotation des offres expirées (cron) | Toutes les **10 secondes** | job `rotate-expired-offers`, `supabase/migrations/20260818173500_schedule_rotate_expired_offers.sql:21-25` | Non chiffré explicitement dans le rapport | — |
| Commission partenaire | **10 %** | `supabase/migrations/20260628_dynamic_commission_rates.sql:13-20` (valeur courante, remplace un ancien défaut de 15 %) | « dix pour cent pour le partenaire » — `rapport_final.tex:1255` | Aucun écart |
| Commission livreur | **23 %** | idem | « vingt-trois pour cent pour le livreur » — `rapport_final.tex:1255` | Aucun écart |
| Solde minimum avant blocage livreur | **0 TND** (`global_settings.prepaid_min_balance`, défaut `'0'`) | `supabase/migrations/20260805121032_prepaid_balance_model.sql:87-90` | « son compte est automatiquement bloqué [...] si le solde [...] devient négatif ou nul » — `rapport_final.tex:1257` | Aucun écart |
| Seuil d'avertissement solde livreur | **entre 2 et 4 TND** | `OLD.balance > 4 AND NEW.balance BETWEEN 2 AND 4`, `supabase/migrations/20260818190000_low_balance_warning.sql:88` | « lorsque le solde descend entre deux et quatre dinars » — `rapport_final.tex:1257` | Aucun écart |
| Frais de livraison — base | **3,5 TND**, jusqu'à 3 km, +0,5 TND/km au-delà | `kDeliveryBaseFee=3.5`, `_kThresholdKm=3.0`, `_kPerKmSurcharge=0.5` — `lib/core/utils/delivery_fee.dart:13-15` | Non chiffré explicitement dans le rapport (formule décrite en général au chapitre 2, sans les valeurs) | — |
| Statuts de commande (8) | pending, confirmed, preparing, ready, pickedUp, onTheWay, delivered, cancelled | `cmandili_schema.sql:257-258` — **aucune `CREATE TABLE orders` dans `supabase/migrations/`, cette table préexiste à l'historique versionné**, source = export racine, pas les migrations | « huit statuts [...] en attente, confirmée, en préparation, prête, récupérée, en livraison, livrée et annulée » — `rapport_final.tex:1364` | Aucun écart sur le nombre et les noms |
| Types de commande (4) | food, courier, supermarket, facture | `orders_order_type_valid`, `supabase/migrations/20260623_facture_bill_payment.sql:26-28` | Décrits par les 4 services (repas/produits/colis/facture), pas nommés littéralement `order_type` | Aucun écart de fond |
| Programme de fidélité — mécanisme | **Paliers automatiques** : 5ᵉ commande livrée = -50 % sur les frais de livraison, 10ᵉ = livraison gratuite. Compte uniquement `food`/`courier`/`facture` (le supermarché ne compte pas). | `supabase/migrations/20260814090000_loyalty_at_checkout.sql:55-109, :66, :80-85` | « un programme de fidélité permet au client de cumuler des points à chaque commande, consultables et échangeables » — `rapport_final.tex:1436` | **OUI — écart de fond.** Le rapport décrit un système générique de points cumulables/échangeables ; le système réel n'a ni points ni échange, c'est une réduction automatique déclenchée à des paliers fixes (5ᵉ, 10ᵉ commande). À corriger avant la soutenance. |
| PostgreSQL — version | **17.6** | `rapport_final.tex:967`, confirmé par note de correction `cmandili_context.md:9` (« corrected 2026-07-19 [...] this doc previously said PG15, which was wrong ») | « PostgreSQL 17.6 » — `rapport_final.tex:967` | Aucun écart — **le rapport est correct**. Attention : certains commentaires dans d'anciens fichiers de migration mentionnent encore "PG15", c'est l'info obsolète, pas le rapport. |
| Nombre de tables | **16-17 `CREATE TABLE` trouvées dans `supabase/migrations/`** (compte statique, pas une introspection de la base réelle) — voir liste complète en note ci-dessous | grep exhaustif sur les 61 fichiers de migration | Non chiffré dans le rapport | **Ce chiffre est trompeur si cité tel quel** — les tables "cœur" (`orders`, `drivers`, `restaurants`, `supermarkets`, `partners`, `profiles`, etc.) n'ont **aucune** `CREATE TABLE` dans les migrations (elles préexistent à l'historique versionné) et ne sont donc pas comptées ici. Le vrai nombre de tables en base est nettement plus élevé. **À VÉRIFIER par une introspection directe de la base** avant de citer un chiffre dans le rapport. |

Note sur le nombre de tables : les 16-17 tables trouvées par `CREATE TABLE` dans les migrations sont : `wallets`, `food_item_variants`, `grocery_item_variants`, `global_settings`, `settlements`, `saved_recipients`, `promo_codes`, `user_promo_usages`, `audit_logs`, `generated_statements`, `loyalty_customer_progress`, `loyalty_driver_payouts`, `food_item_option_groups`, `food_item_options`, `food_item_option_group_links`, `restaurant_option_template_state`.

**Edge Functions Supabase (4) :**

| Nom | Rôle | Services externes appelés |
|---|---|---|
| `ai-chat` | Backend de l'assistant conversationnel : reçoit texte/photo + historique, renvoie un JSON structuré (message + intention) | OpenRouter (`https://openrouter.ai/api/v1/chat/completions`, `index.ts:55`), puis **Google Gemini en secours** (`generativelanguage.googleapis.com`, `:290`) |
| `ai-search` | Recherche IA de plats, mode texte ou photo, avec relâchement progressif des critères puis reclassement par LLM | OpenRouter (`:46`) primaire, Gemini en secours (`:134`) |
| `notify-partner-order` | Doit notifier un partenaire d'une nouvelle commande via FCM | Google FCM HTTP v1 (`:83`). **Suspecté mort/cassé** : interroge une table `partner_profiles` (`:38`) qui n'existe nulle part ailleurs dans tout le dépôt — probablement remplacée par la fonction suivante. |
| `push-on-order-status` | Le vrai centre nerveux des notifications : pousse les alertes commande à chaque changement de statut (client/partenaire/livreur), gère la cascade d'offres au livreur, l'alerte "aucun livreur disponible", l'alerte solde bas, et déclenche `dispatch_driver_for_order` quand une commande passe à `confirmed` | Google OAuth token (`:109`) puis Google FCM HTTP v1 (`:132`, `:183`) |

**Incohérences internes au code, à ne pas reproduire dans le rapport comme si elles fonctionnaient :**
- La colonne `partners.commission_rate` (taux de commission personnalisé par partenaire, éditable dans `cmandili_admin`) existe (`supabase/migrations/20260511_admin_commissions_and_settlements.sql:31-32`) mais **n'est jamais lue** par le déclencheur qui calcule réellement les commissions (`generate_settlements_on_delivery()`) — cette fonctionnalité semble décorative, pas active.
- Le tarif "colis" (`courier_screen.dart:370`) devrait selon un commentaire du code passer une base de 5 TND (`delivery_fee.dart:21`), mais l'appel réel ne le fait pas — un colis facture donc la même base de 3,5 TND qu'une commande de repas.
- Un job cron `disable_happy_hour` tourne en production (toutes les minutes) mais **aucun fichier de migration ne le définit** — dérive entre la base réelle et le contrôle de version (`supabase/migrations/20260818173500_schedule_rotate_expired_offers.sql:13`, mention en passant seulement).

---

## SECTION 4 — Comment le système fonctionne réellement

### Création de compte et connexion, par rôle

Les 3 apps mobiles branchent leur écran racine sur un `StreamProvider` nommé `authStateProvider` (chaque `main.dart`, ex. `lib/main.dart:60,82-87`).

**Client** (`lib/features/auth/`) : inscription = `AuthRepository.signUpWithEmail()` (`auth_repository.dart:71-86`) → `_supabase.auth.signUp(email, password, data:{'full_name'})`. Pas de rôle à choisir, aucune ligne créée dans une autre table. Connexion Google via `signInWithIdToken` (`:106-110`). Apple Sign-In implémenté mais pas branché à un bouton visible dans le code lu.

**Livreur** (`cmandili_driver/lib/features/auth/`) : formulaire d'inscription demande aussi le **téléphone**. `signUpWithEmail()` (`auth_repository.dart:67-84`) crée le compte Auth puis appelle `_ensureDriverRow()` (`:86-99`) qui fait un `upsert` dans `drivers` (`is_online:false`) + met à jour le téléphone dans `profiles`. Même chose après connexion Google. Apple Sign-In explicitement non implémenté (`throw UnimplementedError`, `:139-141`).

**Partenaire** (`cmandili_partner/lib/features/auth/`) : l'inscription impose de choisir un type — **Restaurant** ou **Supermarket** (bascule par défaut sur "restaurant", `auth_screen.dart:788,825`). `signUpWithEmail()` (`auth_repository.dart:68-109`) crée d'abord une ligne dans `restaurants` ou `supermarkets` (selon le type choisi) **avec seulement `name` et `is_open:true`** — aucune coordonnée GPS, aucune adresse — puis relie cette nouvelle ligne au compte via un `upsert` dans `partners` (`entity_id` = id de la ligne créée). **Important : chaque inscription partenaire crée systématiquement un NOUVEAU commerce, jamais une association à un commerce déjà existant créé par un admin.** Pour une connexion Google (pas de type connu à l'avance), un écran d'onboarding séparé (`partner_onboarding_screen.dart`) demande le nom et le type après coup.

### Passer une commande de repas (panier → base de données)

1. `restaurant_detail_screen.dart:645` ouvre la fiche produit.
2. `food_item_customization_sheet.dart:225-233` construit un `CartItem` et appelle `cartProvider.notifier.addItem()`.
3. `cart_provider.dart:38-54` — état 100 % local (`SharedPreferences`), aucun appel Supabase à cette étape.
4. `cart_screen.dart` → bouton "commander" → `checkout_screen.dart`.
5. `checkout_screen.dart:295-309` appelle `orderRepositoryProvider.createOrder(...)`.
6. **Écriture réelle en base** : `order_repository.dart:47-59` — un seul `INSERT` dans `orders` (statut initial `'pending'`), puis un `INSERT` par article de panier dans `order_items` (`:99-107`).
7. Paiement traité/enregistré côté client via `PaymentService` (`lib/core/payment/payment_service.dart`), en cas d'échec la commande est annulée (`cancelOrder`, statut → `cancelled`).
8. Le client est redirigé vers `OrderTrackingScreen`, qui s'abonne en direct au statut de la commande via `.stream(primaryKey:['id'])` sur `orders` (`order_repository.dart:209-220`, exposé par `order_provider.dart:8-11`) — pas de sondage, du vrai temps réel.

### Le dispatch en cascade

Quand une commande passe au statut `confirmed`, `push-on-order-status` (Edge Function) appelle la fonction stockée `dispatch_driver_for_order` (rayon 7 km, fenêtre 30 s pour la 1ère offre — voir Section 3). Si le livreur sollicité ne répond pas ou refuse, le job cron `rotate-expired-offers` (toutes les 10 s) détecte l'expiration et réattribue via `offer_order_to_driver`/`pass_order_offer` — mais avec une fenêtre de **10 secondes seulement** pour ces réattributions, pas 30. Toutes ces fonctions sont dans `supabase/migrations/`, principalement `20260510_assignment_and_distance.sql` et `20260605_dispatch_on_confirmed.sql`.

### Suivi en temps réel d'une livraison

Côté client (`order_tracking_screen.dart`) : deux abonnements Realtime en parallèle — un sur `deliveries` filtré par `order_id` (`:75-79`, donne `current_lat`/`current_lng`), un sur `drivers` filtré par l'id du livreur assigné (`:104-107`, sert de repli si `deliveries` n'a pas encore été écrit). Les coordonnées `(0,0)` sont ignorées par le code (placeholder).

Côté livreur : deux flux GPS séparés écrivent dans `drivers` ET `deliveries` — un service d'arrière-plan permanent (`distanceFilter: 30`, `background_location_service.dart:306-310`) et un flux plus précis actif seulement pendant l'écran de suivi du livreur (`distanceFilter: 10`, `order_tracking_screen.dart:108-112`, côté driver cette fois).

### Envoi d'un colis (P2P)

`courier_screen.dart` (aucun repository/provider dédié — appels Supabase directs dans l'écran). Champs : description du colis, téléphone expéditeur, nom/téléphone destinataire, adresses de collecte et dépôt, taille (petit/moyen/grand), photo optionnelle, case "mémoriser ce destinataire" (upsert dans `saved_recipients`). Prix estimé via `calculateDeliveryFee(distanceKm:)` — base 3,5 TND, +0,5 TND/km au-delà de 3 km (voir note de discrépance en Section 3 sur la base à 5 TND non appliquée). Insertion dans `orders` avec `order_type:'courier'`, `status:'ready'` (pas `'pending'` — pas de partenaire à faire confirmer).

### Paiement de facture

`facture_screen.dart` (même absence de repository/provider). Type de facture (Topnet/STEG/SONEDE/autre), référence, montant, téléphone, adresse client + adresse du bureau où le livreur doit payer, photo optionnelle. Frais fixe de **5,000 TND** (`_serviceFee`, `:63`), sans formule de distance. Insertion dans `orders` avec `order_type:'facture'`, `status:'ready'`. Un rappel programmé ~28 jours plus tard (`BillReminderService`).

### Assistant IA et recherche IA

Deux fonctionnalités distinctes côté client :
- **Assistant conversationnel** : `lib/services/ai_chat_service.dart` appelle `_supabase.functions.invoke('ai-chat', ...)` avec un timeout de 60 s ; le résultat structuré pilote ensuite des requêtes classiques (pas d'IA) sur `food_items`/`grocery_items` côté client.
- **Recherche IA** : `lib/features/ai_search/data/ai_search_repository.dart` appelle `_supabase.functions.invoke('ai-search', body:{'mode':'text'|'image', ...})`.

### Commissions et portefeuille livreur

Voir formule exacte en Section 3. Écran d'affichage côté livreur : `cmandili_driver/lib/features/earnings/presentation/earnings_screen.dart` — total par période (jour/semaine/mois) via RPC `get_driver_earnings`, plus détail par livraison ("Collecté / Commission / [Subvention fidélité] / Net").

### Programme de fidélité (paliers)

Mécanisme exact et écart avec le rapport détaillés en Section 3. Écran client : `lib/features/loyalty/presentation/loyalty_rewards_screen.dart` — grille de 10 tampons visualisant la progression vers le prochain palier.

---

## SECTION 5 — Architecture et organisation du code

**Couches et ce qui tourne où :**
- 3 apps Flutter (client/livreur/partenaire), chacune parlant directement à Supabase (pas de serveur applicatif intermédiaire côté mobile).
- 1 app web Next.js (admin), qui utilise la clé `service_role` de Supabase **côté serveur uniquement**, jamais exposée au navigateur.
- Backend entièrement Supabase : PostgreSQL 17.6, Auth, Realtime, Storage, 4 Edge Functions, RLS, triggers/fonctions stockées, 1 job cron confirmé en version contrôlée (`rotate-expired-offers`, 10 s) + au moins 2 autres jobs vivant seulement en base (`auto-close-restaurants` toutes les 5 min, `disable_happy_hour` toutes les minutes — ce dernier non versionné).

**Pattern data/providers/presentation dans les apps mobiles — audit honnête (pas uniforme) :**

| Feature | Client | Livreur | Partenaire |
|---|---|---|---|
| `auth` | conforme | conforme | conforme |
| `orders` (suivi) | **déroge** — `order_tracking_screen.dart` appelle Supabase directement | **déroge** — 3 écrans appellent Supabase directement | **déroge** — `order_tracking_screen.dart` appelle Supabase directement |
| `home` | — | **déroge** — pas de `providers/`, Supabase appelé directement dans l'écran | **déroge** — pas de `providers/`, Supabase appelé directement dans l'écran |
| `courier` (colis) | **déroge totalement** — ni `data/` ni `providers/` | — | — |
| `facture` | **déroge totalement** — ni `data/` ni `providers/` | — | — |
| `earnings` | — | **déroge totalement** — ni `data/` ni `providers/`, provider défini directement dans l'écran | — |
| `menu` | — | — | conforme |
| `cart` | conforme (mais sans repository — panier 100 % local, `SharedPreferences`, ce qui est normal ici) | — | — |
| `restaurant` | conforme | — | — |

**Conclusion honnête** : le pattern data/providers/presentation existe et est réel, mais **n'est pas appliqué uniformément**. `auth` est la seule feature propre dans les 3 apps. Les écrans de suivi de commande contournent systématiquement leur repository. Le colis, la facture et les gains livreur n'ont carrément pas de couche `data`/`providers` séparée — logique Supabase directement dans le widget d'écran.

**Admin (`cmandili_admin`)** : découpage MVC — `app/dashboard/` = les vues (11 pages : appareils, audit, clients, commandes, fidelite, finances, livreurs, parametres, promos, restaurants, supermarkets), `app/api/` = les contrôleurs (11 routes réparties sur 8 dossiers). Un helper central `requireAdmin()` (`lib/audit.ts:49-63`, vérifie `auth.getUser()` puis `profiles.is_admin` via un client service-role) est appelé par **10 des 11 routes** ; la seule exception (`app/api/logout/route.ts`) est documentée comme volontaire dans `proxy.ts:66-67` (le logout doit fonctionner même sans vérification admin). Un garde-fou supplémentaire au niveau `proxy.ts` (le nouveau nom de `middleware.ts` en Next 16) protège `/dashboard/:path*` et tout `/api/` sauf `/api/logout`.

**Ce que la base impose elle-même vs ce que les apps imposent :**
- Impose la base (triggers/fonctions stockées, indépendant de toute app) : le calcul et débit des commissions à la livraison, le blocage automatique d'un livreur à solde négatif, la réduction de fidélité aux paliers, la réattribution en cascade des offres, la fermeture automatique des commerces hors horaires.
- Impose les apps (rien côté base) : la formule des frais de livraison (calculée en Dart, simplement stockée telle quelle dans `orders.delivery_fee` — aucune contrainte SQL ne revérifie ce montant), le choix du rayon/de la fenêtre de dispatch (ce sont des paramètres par défaut de fonctions SQL, mais rien n'empêche un appel avec d'autres valeurs).

---

## SECTION 6 — L'état actuel du rapport

(Table des matières avec état déjà donnée en Section 2 — non répétée ici.)

### Toutes les figures actuellement dans le rapport (31 actives)

| Fichier | Ligne | Existe ? | Dossier |
|---|---|---|---|
| univk.jpg | 138 | oui | Image/ |
| isigk.png | 156 | oui | Image/ |
| image_repas.png | 307 | oui | images/ |
| image_supermarche.png | 319 | oui | images/ |
| colis.png | 331 | oui | images/ |
| facture.png | 343 | oui | images/ |
| yassir_interface_1.png | 362 | oui | rapport_diagrams/ |
| yassir_interface_2.png | 370 | oui | rapport_diagrams/ |
| livrina_interface.png | 381 | oui | rapport_diagrams/ |
| cas_utilisation_client_v2.png | 670 | oui | rapport_diagrams/ |
| cas_utilisation_partenaire_v2.png | 677 | oui | rapport_diagrams/ |
| cas_utilisation_livreur_v2.png | 684 | oui | rapport_diagrams/ |
| cas_utilisation_admin_v2.png | 691 | oui | rapport_diagrams/ |
| raffinement_passer_commande_v2.png | 733 | oui | rapport_diagrams/ |
| raffinement_suivre_commande_v2.png | 777 | oui | rapport_diagrams/ |
| raffinement_livraison_commande.png | 819 | oui | rapport_diagrams/ |
| raffinement_ajout_plat_jour.png | 868 | oui | rapport_diagrams/ |
| diagramme_classe_v2_full.png | 1119 | oui | rapport_diagrams/ |
| diagramme_sequence_authentification.png | 1204 | oui | rapport_diagrams/ |
| diagramme_sequence_creation_commande_v2.png | 1217 | oui | rapport_diagrams/ |
| diagramme_sequence_livraison_commande_v2.png | 1231 | oui | rapport_diagrams/ |
| diagramme_sequence_ajout_plat_jour_v2.png | 1244 | oui | rapport_diagrams/ |
| diagramme_sequence_commission_livraison.png | 1261 | oui | rapport_diagrams/ |
| diagramme_sequence_envoi_colis.png | 1278 | oui | rapport_diagrams/ |
| diagramme_architecture_ia.png | 1397 | oui | rapport_diagrams/ |
| client_auth.png | 1459 | oui | images/ |
| client_accueil.png | 1472 | oui | images/ |
| client_restaurant_detail.png | 1485 | oui | images/ |
| client_suivi_commande.png | 1520 | oui | images/ |
| client_assistant_ia.png | 1533 | oui | images/ |
| client_recherche_ia.png | 1540 | oui | images/ |

**Toutes les 31 figures actives existent bien sur disque.** Aucune anomalie de casse/accent/espace détectée.

### Images présentes sur disque mais jamais utilisées (12)

- `Image/logo_uml.jpg`
- `images/colis.jpg`, `images/facture.jpg`, `images/happy_hour_image.jpg`, `images/happy_hour_image.png`, `images/image_repas.jpg`, `images/image_supermarche.jpg`, `images/logo_client.jpg`, `images/logo_livreur.jpg`
- `rapport_diagrams/diagramme de sequence_ajout_plat_jour corrigé.png`, `rapport_diagrams/diagramme de sequence_creation_commande corrigé.png`, `rapport_diagrams/diagramme de sequence_livraison_commande corrigé.png` (anciennes versions, remplacées par les `_v2.png`)

Note : les fichiers `.jpg` dans `images/` (colis.jpg, facture.jpg, image_repas.jpg, image_supermarche.jpg) sont des versions compressées créées lors d'une session précédente pour résoudre un timeout de compilation sur texpage.io — elles ne sont **pas** référencées dans `rapport_final.tex` (qui utilise encore les `.png` d'origine, plus lourds). **À VÉRIFIER** : la version du rapport utilisée sur texpage.io peut différer de `rapport_final.tex` sur ce point précis.

### 30 captures d'écran encore manquantes (marqueurs TODO)

Chapitre 4 (interfaces) — 20 captures manquantes : authentification/accueil/panier/checkout côté client (2), authentification/disponibilité/commandes dispo/offre/suivi/revenus côté livreur (6), menu/ajout article/commande entrante/liste commandes/portefeuille côté partenaire (5), login/dashboard/clients/restaurants/livreurs/commandes/finances/paramètres côté admin (8, dont une ligne TODO couvre 2 images).

Chapitre 5 (tests) — 8 captures manquantes : une par test fonctionnel (authentification, création commande, acceptation livraison, suivi temps réel, envoi colis, assistant IA), une pour la comparaison petit/grand écran, une pour le tableau de bord Supabase en production.

Annexes — 2 lignes TODO génériques (captures et documentation complémentaires "à ajouter au fur et à mesure").

Détail ligne par ligne disponible sur demande — la liste complète des 30 lignes avec citation exacte a été produite lors de l'audit et peut être reconstituée en relisant `rapport_final.tex` autour des lignes 1496 à 2013.

### Autres problèmes connus

- **Bibliographie** : les 16 clés `\cite{}` utilisées correspondent exactement aux 16 entrées de `bbbib.bib` — aucun problème.
- **Titres dupliqués (sous-sections)** : "Authentification et inscription" (`:702` et `:1196`), "Livraison d'une commande" (`:815` et `:1225`), "Ajout d'un plat du jour" (`:864` et `:1238`), "Envoi d'un colis" (`:900` et `:1268`) — doublons **volontaires** (même scénario décrit une fois comme cas d'utilisation, une fois comme diagramme de séquence). "Authentification" (`:1453` et `:1551`) et "Suivi de la livraison" (`:1514` et `:1599`) — normal, une fois par application au chapitre 4. "Gestion des commandes" (`:1362` chapitre 3, `:1745` chapitre 4) — normal, contextes différents. **Aucun doublon accidentel détecté.**
- **Timeout de compilation sur texpage.io** : problème rencontré en dehors des fichiers versionnés (compilateur en ligne, plan gratuit limité à 30 secondes). Cause identifiée dans une session précédente : plusieurs images photographiques (`colis.png`, `facture.png`, `image_repas.png`, `image_supermarche.png`) pesaient 1,5 à 2,4 Mo chacune en PNG alors qu'il s'agit de photos, pas de captures d'écran — converties en `.jpg` (0,08 à 0,25 Mo chacune) pour réduire la charge. **Cette correction a été appliquée sur texpage.io, pas dans `rapport_final.tex` local** (voir note ci-dessus) — à re-synchroniser si `rapport_final.tex` est la version qui repart en compilation.
- **Deux fichiers `.tex`** coexistent (`rapport.tex` obsolète, `rapport_final.tex` canonique) — risque de travailler sur le mauvais fichier par erreur.

---

## SECTION 7 — Ce qu'il reste à faire

Ordre du plus bloquant au moins bloquant :

1. **Corriger les 2 écarts chiffrés identifiés en Section 3** (fenêtre de réattribution 10s vs "30s partout" ; mécanisme de fidélité par paliers vs "points cumulables/échangeables"). Nécessite de relire le code, pas de nouveau développement. ~30 min.
2. **Obtenir/prendre les 30 captures d'écran manquantes** (chapitres 4 et 5) — c'est le plus gros chantier restant, bloque une bonne partie du chapitre 4 et la totalité du chapitre 5 visuellement. Nécessite d'utiliser les 4 applications sur un vrai téléphone/navigateur. Prévoir plusieurs heures, en particulier pour rejouer des scénarios de test précis (acceptation d'une livraison avec 2 téléphones, coupure réseau pour le suivi temps réel, etc.).
3. **Compléter la page de titre** : intitulé exact du diplôme, sous-titre, composition du jury, date de soutenance (3 `% VERIFIER` dans le fichier). Juste de la saisie, quelques minutes une fois les infos en main.
4. **Rédiger "Captures d'écran supplémentaires" et "Documentation technique complémentaire"** en annexe, actuellement à l'état d'ébauche. Dépend des captures du point 2.
5. **Nettoyer les images inutilisées** (12 fichiers) et **décider si les versions `.jpg` compressées doivent remplacer les `.png` dans `rapport_final.tex`** pour éviter le problème de timeout à la prochaine compilation. Technique, rapide.
6. **Vérifier le nombre de pages réel** en compilant le PDF, pour s'assurer que le mémoire respecte les contraintes de longueur de l'établissement (si applicables — **à vérifier auprès de l'encadrant**).
7. **Retrouver et sauvegarder le plan officiel de l'encadrant** dans un fichier du dépôt, pour que ce document de handoff puisse un jour comparer objectivement le rapport à ce plan (actuellement impossible, voir Section 2).

---

## SECTION 8 — Ce qui a été mal compris ou corrigé par le passé

Peu de traces écrites de corrections répétées existent dans les fichiers eux-mêmes — l'essentiel de ce qui suit vient soit d'un seul fichier de notes internes (`cmandili_context.md`), soit des écarts déjà relevés en Section 3.

- **Nom du projet** : le projet s'appelait "Cmandili", renommé en "Amana" — `cmandili_context.md:43` documente ce changement. Attention à une variante orthographique : ce même fichier de notes internes écrit parfois "**Amena**" (`cmandili_context.md:43`) alors que le rapport et les autres documents utilisent systématiquement "**AMANA**" — ne pas introduire "Amena" dans le rapport, c'est une coquille des notes internes, pas le vrai nom.
- **Version de PostgreSQL** : une note interne signale explicitement une confusion passée — `cmandili_context.md:9` : « corrected 2026-07-19 [...] this doc previously said PG15, which was wrong/stale ». La version correcte et à jour est **17.6**, pas 15. Le rapport actuel dit déjà 17.6 — bon signe, mais un assistant qui n'aurait pas cette info pourrait être tenté de "corriger" vers 15 en se basant sur d'anciens commentaires de code, ce qui serait une régression.
- **Quel dossier contient le code réellement utilisé** : `cmandili_context.md:57` documente une confusion antérieure sur le point de savoir si `cmandili_mobile/` ou le `lib/` à la racine était le code "vivant" — la racine du dépôt est la bonne réponse actuellement, mais la note recommande explicitement de revérifier avec `git log`/`git status` en cas de doute plutôt que de faire confiance à une ancienne conclusion.
- **Fidélité décrite comme un système de points échangeables** : ce n'est pas une correction documentée dans les fichiers, mais l'écart trouvé en Section 3 suggère que c'est une erreur facile à refaire — le vrai mécanisme n'a ni points, ni échange, seulement des paliers automatiques.
- **Fenêtre de 30 secondes appliquée à toute la cascade de dispatch** : même remarque — écart trouvé en Section 3, à ne pas généraliser depuis la phrase actuelle du rapport.
