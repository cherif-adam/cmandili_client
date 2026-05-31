# Cmandili — Résumé ta3 el Projet

Cmandili houwa platform mta3 livraison ml mekla w courses, mabni b **Flutter**. Fih **4 applications** (client, livreur, partenaire, admin central) w el backend mta3hom mabni b **Supabase** (Postgres + Edge Functions). El notifications b **Firebase FCM**, w el cartes w el géolocalisation b **Mapbox**.

---

## 1. El Stack (chnowa msta3mlin)

| Niveau | Technologie |
|---|---|
| Applications mobile | Flutter (Dart), Riverpod bech ynajem el state |
| Backend | Supabase (Postgres, Auth, RLS, Edge Functions b Deno/TypeScript) |
| Notifications | Firebase Cloud Messaging + `flutter_local_notifications` |
| Cartes w GPS | Mapbox (`mapbox_maps_flutter`), `geolocator`, `geocoding` |
| Authentification | Supabase Auth — Email/password, Google, Apple Sign-In |
| **AI Chat** | **OpenRouter API (Gemini 2.0 Flash) — appel direct men Flutter, bla Edge Function** |
| Lougha | 3arbi, Français, Anglais (`AppLocalizations`) |
| Thème | Light / Dark b `themeProvider` |

---

## 2. El 3 applications

### 2.1 [cmandili_mobile](cmandili_mobile/) — Application el Client
Hethi houwa el app eli ynajem feha el client yetlob mekla wala courses.

**Features** ([lib/features/](cmandili_mobile/lib/features/)): `auth`, `home`, `restaurant`, `supermarket`, `cart`, `checkout`, `orders`, `bills`, `favorites`, `happy_hour`, `courier`, `notifications`, `profile`.

**El flow:** El client yshouf el restaurants wala el supermarchés → yzid el produits fil panier → yzarbet (yhott el adresse w yekhles cash) → ytabe3 el commande mta3o live 3al carte Mapbox bech yshouf el livreur win wsel → 3andou centre notifications fil app.

**Point d'entrée** ([main.dart](cmandili_mobile/lib/main.dart)): yhayyi el `.env`, ye3mel set lel Mapbox token, yinitialisi Supabase + Firebase fi nafs el waqt, w ba3d ye3mel `PushService.initialize()` ki yikhles el premier frame. El routing 3la 7sib `authStateProvider`.

---

### 2.2 [cmandili_driver](cmandili_driver/) — Application el Livreur
Application bech el livreur ynajem yekhdem w yelivri el commandes.

**Features** ([lib/features/](cmandili_driver/lib/features/)): `auth`, `home` (commandes disponibles), `orders`, `profile` (info véhicule), `earnings`, `notifications`.

**El flow:** El livreur yodkhol → mejbour ywarri info el véhicule mta3o el louwla → yshouf el commandes ready eli qrib menou → yaccepti → yruh lel restaurant → yruh lel client → ya3mel mark "delivered" → yetzed lou fi earnings.

**El haja el spéciale:** [BackgroundLocationService](cmandili_driver/lib/core/services/background_location_service.dart) — service Android **foreground** ya3mel notification persistente, w kol 10 secondes ye3mel push lel position GPS lel `drivers.current_lat/current_lng` w lel `deliveries`. Yokra el credentials mta3 Supabase men SharedPreferences 5atter el service ye5dem fi isolate okhra.

**Point d'entrée** ([main.dart](cmandili_driver/lib/main.dart)): kima el mobile + yhott el credentials Supabase fi SharedPreferences + ybadi el `BackgroundLocationService`. `_PostAuthGate` yverifi `vehicle_type` qbal ma yfawet el livreur lel `HomeScreen`.

---

### 2.3 [cmandili_partner](cmandili_partner/) — Application el Restaurant / Supermarché
Application lel partenaire bech ynajem el commandes w el menu.

**Features** ([lib/features/](cmandili_partner/lib/features/)): `auth`, `home` (dashboard), `menu` (CRUD lel produits + promotions), `orders` (gestion el statut), `profile`, `reports`, `notifications`.

**El flow:** El partenaire yodkhol → yshouf el commandes el jdod (pending) → yconfirmi → ya3mel mark "preparing" → ba3d "ready" (w hethi tdeclencher el fan-out lel livreurs) → ynajem ybeddel el menu, el prix, el disponibilité, w yzid promotions happy-hour.

**Point d'entrée** ([main.dart](cmandili_partner/lib/main.dart)): boot 3adi — el Mapbox msta3mel ghir fi screen el order tracking.

**OpenRouter fil partner**: [lib/core/config/openrouter_config.dart](cmandili_partner/lib/core/config/openrouter_config.dart) — yokra `OPENROUTER_API_KEY` men `.env`. Mosta3mel fi AI Menu Scanner (vision) bech yenrégistri el produits automatiquement men photo. Model: `google/gemini-2.0-flash-001`.

---

### 2.4 [cmandili_admin](cmandili_admin/) — Application el Admin / Central
Application lel admin (plateforme centrale) bech ytabe3 el operations, el finances, w el commissions en temps réel.

**Features** ([lib/features/](cmandili_admin/lib/features/)): `dashboard` (glassmorphism UI, fl_chart area charts, heatmap), `partners` (master-detail view mta3 les restaurants + calcul automatique ta3 10% commission 3la subtotal), `drivers` (calcul commission b formule tunisienne: 3.500 TND base + 0.750 TND l kol km > 4km, admin yekhou 23% menha).

**El flow:** El admin yodkhol → yshouf el dashboard el principal (Premium Fintech UI b accent Orange) → ytabe3 el Live Sync mta3 el commandes w el drivers → yodkhol lel partners wala drivers bech yshouf les détails w les montants exacts b precision 3 decimales (millimes TND).

**Point d'entrée** ([main.dart](cmandili_admin/lib/main.dart)): routing b `go_router` (ShellRoute lel sidebar) w state b `flutter_riverpod`.

---

## 3. Backend Supabase ([supabase/](supabase/))

### 3.1 El tables el principaux

| Table | Wechni dorha |
|---|---|
| `profiles` | Info el user (yet3amel automatiquement men `auth.users`) |
| `partners` | Les owners; yrabbet `user_id` ma3 `entity_id` (restaurant wala supermarché) |
| `restaurants`, `supermarkets` | Catalogues fihom location, rating, frais livraison, `is_open` |
| `food_items`, `grocery_items` | Menu / produits ma3 `discount_price`, `is_available` |
| `drivers` | Profil livreur + **position live** (`current_lat/lng`, `is_online`, info véhicule) |
| `orders` | El header mta3 el commande b `status`, `delivery_address` (JSONB), totals |
| `order_items` | Lignes el commande + `options` mta3 customisation (JSONB) |
| `deliveries` | Ligne livraison ma3a coordonnées live |
| `payments` | Paiements (taw cash) |
| `notifications` | Log el notifications fil app (title, message, type, data, is_read) |
| `device_tokens` | Tokens FCM 7asb el device, marbout b user |
| `support_tickets` | Support el client |
| **`chat_messages`** | **Historique el AI chat — colonnes: `id`, `user_id`, `text`, `is_user`, `created_at`. RLS active: kol user yshouf ghir el messages mta3o.** |

### 3.2 El RLS (Row Level Security)
- Kol user yshouf ghir el orders w notifications mta3o.
- El partenaire yshouf ghir el orders mta3 `entity_id` mta3o.
- El livreur yshouf el orders `pending`/`ready` + el deliveries mta3o.
- El catalogues (restaurants, food_items...) lecture publique.
- `chat_messages`: SELECT + INSERT + DELETE ghir lel `user_id` mta3 el user el connecté.

### 3.3 Triggers w RPCs
- `handle_new_user()` — yinjam ligne `profiles` ki user jdid yenrégistri.
- `handle_order_status_timestamps()` — yhott `confirmed_at`, `ready_at` automatiquement.
- `notify_fcm_on_order_status()` — y3ayyet lel edge function ki status el commande ybeddel (yroute el push lel client / partenaire / livreur assigné).
- `notify_fcm_fanout_ready_order()` — ki commande tewla "ready", ye3mel broadcast lel livreurs online qrib.
- `haversine_km(lat1,lng1,lat2,lng2)` — distance bla ma yostakhdem PostGIS.
- `nearby_online_drivers(p_lat, p_lng, p_radius_km)` — RPC yraj3a 50 livreur online el aqrab.

### 3.4 Migrations ([supabase/migrations/](supabase/migrations/))
- `20260424_push_geo_fanout.sql` — fan-out géo + haversine + RPC.
- `20260425_inline_edge_function_url.sql` / `20260426_set_edge_function_settings.sql` — settings edge function.
- `20260505_notifications_message_column.sql` — réparation schéma notifications.
- `20260507_order_notifications_and_customer_info.sql` — refinements 3al notifications + info client.
- `20260511_admin_commissions_and_settlements.sql` — TND 3-decimal precision (millimes), systeme ta3 commissions lel restaurants (10%) w drivers (23%), w table `settlements` lel payouts.
- **`chat_messages` — mish migration fichier, SQL script mosta3mel directement fil Supabase SQL Editor (shouf section 7 lta7t).**

### 3.5 Edge Functions
[`push-on-order-status`](supabase/functions/push-on-order-status/) (Deno/TS) ye5dem 2 modes:
1. **Mode status-change**: yroute el FCM b texte spécifique lel client, partenaire, w livreur assigné.
2. **Mode fan-out lel livreurs**: y3ayyet lel RPC `nearby_online_drivers`, w ybe3eth push lkol livreur fi `DRIVER_FANOUT_RADIUS_KM`.
3. Authentification: yesigni RSA-JWT men `FCM_SERVICE_ACCOUNT_JSON` (base64 fil env), w ybe3eth POST lel FCM v1 API.

[`ai-search`](supabase/functions/ai-search/) (Deno/TS) — edge function lel AI search (text + image modes b OpenRouter). **Mish mosta3mla fi el chat taw** (virtualization issues m3a Docker). Mosta3mla ghir lel `AiSearchScreen` (sparkle icon fil search bar).

---

## 4. Patterns moshtarka bin el 3 applications

- **State**: Riverpod fi koll blasa (`authStateProvider` ka `StreamProvider<User?>`, providers spécifiques fi koll feature).
- **Push**: nafs structure el `PushService` fi koll app — yenrégistri token FCM fi `device_tokens`, foreground b notifications locales, background b FCM payload + trigger Supabase.
- **Cartes**: token public Mapbox `pk.*` fil `.env`; token secret `sk.*` ghir fi `~/.netrc` (iOS) wala `gradle.properties` (Android, **mish trackable** — shouf commit `c4f0ccd`).
- **Models**: maktoubin b lid + chwaya `freezed_annotation`/`json_annotation` (fi app partenaire).
- **Ordre el boot** (fi koll app): `.env` → token Mapbox → `Supabase.initialize` + `Firebase.initializeApp` parallèle → `runApp(ProviderScope(...))` → ba3d el premier frame `PushService.initialize()`.
- **OpenRouter**: mosta3mel fi `cmandili_partner` (AI menu scanner) w `cmandili_mobile` (AI chat). El key `OPENROUTER_API_KEY` fil `.env` mta3 chaque app.

---

## 5. Etat el khedma taw

Branch: `main`. Fama modifications fi koll application + jouj migrations **mish committés**:

- `supabase/migrations/20260505_notifications_message_column.sql`
- `supabase/migrations/20260507_order_notifications_and_customer_info.sql`
- `supabase/migrations/20260511_admin_commissions_and_settlements.sql`

Hathom ydabbrou table `notifications`, schéma orders/customer-info, w el logic mta3 el commissions (10% restaurants, 23% drivers) ma3a TND 3-decimals. Lazem ytapplikew fel Supabase manuel.

Fi `cmandili_admin`, 9amna b création ta3 architecture complète b `riverpod`, `go_router`, w UI premium Glassmorphism (Dark mode + Orange accent) ma3a dashboards lel restaurants w drivers.

**Session 2026-05-23 — AI Chat mzouwa7 w operational.** Shouf section 7 lta7t lel détails complets.

---

## 6. Navigation sri3a

- Entry el client: [cmandili_mobile/lib/main.dart](cmandili_mobile/lib/main.dart)
- Entry el livreur: [cmandili_driver/lib/main.dart](cmandili_driver/lib/main.dart)
- Entry el partenaire: [cmandili_partner/lib/main.dart](cmandili_partner/lib/main.dart)
- GPS background lel livreur: [cmandili_driver/lib/core/services/background_location_service.dart](cmandili_driver/lib/core/services/background_location_service.dart)
- Edge function lel push: [supabase/functions/push-on-order-status/](supabase/functions/push-on-order-status/)
- Migrations: [supabase/migrations/](supabase/migrations/)
- **AI Chat screen**: [cmandili_mobile/lib/screens/ai_chat_screen.dart](cmandili_mobile/lib/screens/ai_chat_screen.dart)
- **AI Chat service**: [cmandili_mobile/lib/services/ai_chat_service.dart](cmandili_mobile/lib/services/ai_chat_service.dart)
- **Chat message model**: [cmandili_mobile/lib/models/chat_message.dart](cmandili_mobile/lib/models/chat_message.dart)

---

## 7. AI Chat — Cmandili Assistant (implémenté 2026-05-23)

### 7.1 Architecture choisie

L'approche Edge Function (Docker/Supabase) a été **abandonnée** à cause de problèmes de virtualisation. Tout tourne maintenant **directement dans Flutter** via des appels HTTP à OpenRouter.

```
User message
     │
     ▼
AiChatService._callOpenRouter()   ← POST https://openrouter.ai/api/v1/chat/completions
     │                               Model: google/gemini-2.0-flash-001
     │                               System prompt → strict JSON response
     ▼
_AiIntent.parse()                 ← Décode le JSON, strip markdown fences
     │
     ├──► _persistMessages()      ← Supabase INSERT dans chat_messages (fire-and-forget)
     │
     ├──► intent == "greeting" / "general"
     │         └─► ChatMessage(text: aiReply, products: [])
     │
     └──► intent == "search_food"
               └─► _queryFoodItems()   ← Supabase SELECT food_items ⨯ restaurants
                         └─► ChatMessage(text: aiReply, products: [...])
```

### 7.2 Fichiers modifiés / créés

| Fichier | Changement |
|---|---|
| [home_screen.dart](cmandili_mobile/lib/features/home/presentation/home_screen.dart) | Ajout `FloatingActionButton` violet (`0xFF6C3DE1`) qui navigue vers `AiChatScreen`. Padding bottom `screenHeight * 0.1` pour éviter le chevauchement avec la nav bar flottante. `heroTag: 'ai_chat_fab'`. |
| [ai_chat_screen.dart](cmandili_mobile/lib/screens/ai_chat_screen.dart) | Écran de chat complet. `_buildProductImage()` gère les URLs invalides (`file:///`, null, relative) avec `errorBuilder` + placeholder icône restaurant. Dispose du `TextEditingController`. |
| [ai_chat_service.dart](cmandili_mobile/lib/services/ai_chat_service.dart) | Service entièrement réécrit. Appel OpenRouter direct, parse `_AiIntent`, persist dans `chat_messages`, query `food_items` si `search_food`. |
| [chat_message.dart](cmandili_mobile/lib/models/chat_message.dart) | Inchangé. `ProductResult` a les champs: `type` (required), `id` (required), `name`, `description`, `price`, `currency`, `imageUrl`, `sourceName`. |

### 7.3 AiChatService — points clés

```dart
// Import obligatoire dans pubspec.yaml (déjà présent via partner app):
// http: ^x.x.x
// flutter_dotenv: ^x.x.x
// supabase_flutter: ^x.x.x

// .env de cmandili_mobile doit contenir:
// OPENROUTER_API_KEY=sk-or-v1-...
// OPENROUTER_CHAT_MODEL=google/gemini-2.0-flash-001  (optionnel)
```

**Résolution des image_url**: si l'URL commence par `http(s)://` → utilisée telle quelle. Si relative → préfixée par `https://hoqlxxtphskgxktqjpfu.supabase.co/storage/v1/object/public/`. Si null/vide → `null` (placeholder affiché).

**Persist messages**: fire-and-forget (`unawaited`), silencieux si l'user n'est pas connecté. INSERT 2 lignes à la fois (user turn + AI turn).

**Food query**: utilise `Supabase.instance.client.from('food_items').select(...)` avec join `restaurants(...)`. Filtres: `is_spicy`, `is_vegetarian`, `price` (lte/gte), `preparation_time` (lte 20 si fast), `category` (ilike), `keyword` (or name/description ilike). Limit 20, order by price ASC.

### 7.4 System prompt résumé

Le prompt instruit Gemini de:
1. **Détecter la langue** (Derja / Français / Anglais) et répondre dans la même langue.
2. **Retourner un JSON strict** avec les champs: `message`, `intent`, `category`, `spicy`, `vegetarian`, `max_price`, `min_price`, `delivery_time`, `keyword`.
3. **Gérer les salutations**: `intent: "greeting"` → pas de recherche DB, `results: []`.
4. **Gérer `general`**: réponse conversationnelle sans recherche.
5. **Glossaire Derja** intégré: `7arra`=spicy, `fissa3`=fast, `ma tfoutch X dinar`=max_price, etc.

### 7.5 Table chat_messages — SQL

```sql
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text       text        NOT NULL,
  is_user    boolean     NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS chat_messages_user_id_created_at_idx
  ON public.chat_messages (user_id, created_at DESC);
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own chat messages"   ON public.chat_messages FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own chat messages" ON public.chat_messages FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users delete own chat messages" ON public.chat_messages FOR DELETE USING (auth.uid() = user_id);
```

**Status**: SQL appliqué ✅ / à appliquer ⬜ (cocher quand fait)

### 7.6 Prochaines étapes possibles

- [ ] Ajouter un bouton "Effacer l'historique" dans `AiChatScreen` qui DELETE les messages de `chat_messages`.
- [ ] Charger l'historique existant depuis `chat_messages` au démarrage de l'écran.
- [ ] Tapper sur un `ProductCard` → naviguer vers le restaurant correspondant.
- [ ] Ajouter directement au panier depuis le chat.
- [ ] Améliorer le design de `AiChatScreen` pour matcher le style glassmorphism du reste de l'app.
