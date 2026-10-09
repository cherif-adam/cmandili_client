# Améliorations de la présentation Amana

Document écrit le 8 octobre 2026, après lecture du code des quatre
applications, des 92 migrations, des 5 Edge Functions et du mémoire.

**Règle que je me suis donnée :** chaque affirmation renvoie à un fichier et
une ligne. Quand je n'ai pas pu vérifier, j'écris « non vérifiable » et je dis
pourquoi. Aucun fichier du projet n'a été modifié : ce document est le seul
créé. Aucune requête d'écriture n'a été lancée.

---

# §1 — Top 10 des changements prioritaires

| # | Changement | Pourquoi c'est important |
|---|---|---|
| 1 | **Dire que vous avez des tests automatisés** | Vous en avez **46**, répartis dans 12 fichiers, plus un côté admin. Trois slides affirment le contraire. Vous vous dévalorisez sur un point que le jury valorise. |
| 2 | **Ajouter la majoration de 10 % sur les articles** (slide 18) | C'est votre **deuxième source de revenu** et elle n'apparaît nulle part. Un juré qui lit l'annexe A4 verra `c_markup = 1.10` et demandera. |
| 3 | **Nommer pg_cron et sa cadence de 10 secondes** (slides 14, 17, 31) | C'est le cœur distribué de votre dispatch. « Une tâche planifiée balaie les offres expirées toutes les 10 secondes » est bien plus fort que « le serveur passe au suivant ». |
| 4 | **Ajouter une slide « systèmes distribués »** (voir §4) | Vous passez un mastère *Réseaux et Applications Distribuées*. Le mot « distribué » n'apparaît qu'une fois, dans la conclusion. Tout le matériel existe dans le code. |
| 5 | **Retirer « jusqu'à 30 % chez Glovo »** (slide 4) | **Zéro** entrée Glovo dans votre bibliographie. Chiffre invérifiable sur une entreprise nommée : c'est le genre de phrase qu'un juré attaque. |
| 6 | **Chiffrer la sécurité** (slide 19) | « Règles RLS » est vague. **26 politiques sur 19 tables** est une preuve. |
| 7 | **Ajouter M. Firas Mzoughi sur la couverture** (slide 1) | Il figure sur la page de garde du mémoire comme encadrant professionnel. S'il est dans la salle, son absence se voit. |
| 8 | **Enrichir la slide chiffres** (slide 27) | Ajoutez 26 politiques RLS, 27 flux temps réel, 46 tests. Vos chiffres actuels décrivent la taille ; ceux-là décrivent la difficulté. |
| 9 | **Corriger « en vert / en indigo »** (slide 23) | Vous avez corrigé la slide 9, pas la 23. Les notes disent encore « l'application Livreur, en vert » : elle est bleue (`#2563EB`). |
| 10 | **Alléger quatre blocs de notes** (voir §6) | Vous êtes à ≈ 22,6 min avec la vidéo. C'est jouable mais sans marge. Les coupes proposées vous ramènent à ≈ 21 min. |

---

# §2 — Revue slide par slide

## Slide 1 · `cover` — **resserrer**

**Verdict :** garder la structure, compléter l'encadrement.

Un seul encadrant est cité. La page de garde du mémoire en porte deux
(`ameenPFE.tex:223-225`) :

> ✅ M<sup>me</sup> Olfa Harrabi — Encadrant Académique
> ✅ M. Firas Mzoughi — Encadrant Professionnel

**Texte proposé :**
- Encadré par
- M<sup>me</sup> Olfa Harrabi — encadrant académique
- M. Firas Mzoughi — encadrant professionnel

**Notes :** remplacer « Ce travail a été encadré par Mme Olfa Harrabi » par
« Ce travail a été encadré par M<sup>me</sup> Olfa Harrabi à l'institut, et
par M. Firas Mzoughi côté professionnel. »

---

## Slide 2 · `plan` — **garder**

Rien à changer. 28 s, bien calibré.

---

## Slide 3 · `d1` — **garder**

Transition de 3 s. Parfait.

---

## Slide 4 · `contexte` — **réécrire un point**

⚠️ **« Jusqu'à 30 % chez Glovo »** : aucune source. Votre bibliographie
contient `yassir_site`, `livrina_site` et `zigzag_site` — **zéro entrée
Glovo** (vérifié dans `bbbib.bib`). Le mémoire lui-même ne donne aucun
pourcentage : il écrit seulement « commissions élevées » (§1.5).

Vous ne pouvez pas sourcer ce chiffre. Et vous avez beaucoup mieux : **votre
propre taux est vérifiable**, lui.

**Texte proposé pour le point 03 :**
- Commissions lourdes
- Des taux qui pèsent sur le petit commerce. Amana : 10 %, réglable.

**Notes :** remplacer la phrase par
> Trois : les commissions des grandes plateformes sont un frein pour un petit
> commerçant de Kairouan. Chez Amana, le taux par défaut est de 10 % sur les
> articles, et l'administrateur peut le changer sans republier l'application.

Vous passez d'une accusation invérifiable à une preuve que vous maîtrisez.

✅ Les trois autres points sont conformes au chapitre 1 du mémoire.

---

## Slide 5 · `existant` — **garder**

✅ Conforme au tableau 1.1 du mémoire. Tableau lisible, message clair.

---

## Slide 6 · `problematique` — **garder**

Rien à changer.

---

## Slide 7 · `d2` — **garder**

---

## Slide 8 · `solution` — **garder**

✅ Les sept catégories de commerce sont exactes : `food`, `supermarket`,
`bakery`, `flowers`, `petshop`, `gifts`, `electronics`
(`20260928200000_promotions_phase1.sql`, colonne `discount_mode` de
`vendor_categories`).

---

## Slide 9 · `acteurs` — **garder**

✅ La phrase sur les couleurs est maintenant correcte (« C'est un repère de
lecture pour les slides : il ne reprend pas forcément les couleurs des
applications elles-mêmes »). Bien corrigé.

**Petit gain :** 53 s, c'est long pour une slide de présentation des acteurs.
Coupez « Et l'administrateur… aujourd'hui, c'est moi » — gardez-le pour la
slide 24 où il a plus de force.

---

## Slide 10 · `d3` — **garder**

---

## Slide 11 · `cas` — **garder**

✅ Vue simplifiée assumée, conforme aux figures 2.1 à 2.4.

---

## Slide 12 · `classes` — **resserrer**

✅ Le contenu est juste, y compris la phrase ajoutée sur la table d'articles
unique — c'est votre meilleur argument de conception.

⚠️ **70 secondes, c'est la deuxième plus longue note de la présentation.**
Pour un diagramme que le jury ne peut pas lire en détail, c'est trop.

**Notes resserrées (≈ 45 s) :**
> Voici le modèle de données, en version simplifiée. La classe centrale est
> Commande : elle porte le type — repas, supermarché, colis ou facture —, le
> statut, les montants, et les informations du dispatch. Client et Livreur
> héritent d'Utilisateur. Un choix important : CategorieCommerce n'est pas
> une étiquette, elle porte des règles, comme le mode de remise. Et une seule
> table d'articles sert les sept catégories : `food_items` et
> `grocery_items` sont des **vues** sur cette table. Ouvrir une huitième
> catégorie, c'est ajouter une ligne en base — aucune nouvelle table, aucune
> nouvelle version des applications.

Le mot « vues » est une précision technique gratuite qui montre que vous
savez de quoi vous parlez.

---

## Slide 13 · `archi` — **réécrire partiellement**

C'est ici que se joue votre note de mastère RAD. La slide décrit une
architecture ; elle ne dit pas ce qu'elle résout.

⚠️ « PostgreSQL » sans version : vous aviez « 17.6 », vous l'avez retiré.
Bonne décision — **la version n'est pas vérifiable depuis le dépôt**
(`supabase/config.toml` ne la fixe pas). Si vous voulez l'annoncer, ouvrez la
console Supabase avant la soutenance pour pouvoir la montrer.

**Ajout proposé en bas de slide (une ligne) :**
- Une seule source de vérité pour quatre clients : les règles d'accès et les
  calculs vivent dans la base, pas dans les applications.

**Notes — ajouter une phrase à la fin :**
> L'intérêt, pour un système distribué, est là : quatre clients différents
> lisent et écrivent la même base, et c'est elle qui arbitre. Les règles
> d'accès, le calcul des commissions, l'attribution des courses : tout est
> appliqué au même endroit, donc de la même façon pour les quatre
> applications.

---

## Slide 14 · `voyage` — **resserrer**

✅ Les 10 mètres sont maintenant corrects
(`cmandili_driver/lib/core/services/background_location_service.dart:339`).

⚠️ La parenthèse dans les notes (« Si le jury compare avec le mémoire, qui
indique 30 mètres… ») est une bonne précaution, mais **ne la dites pas
spontanément**. Gardez-la en réserve. Dire à voix haute « mon mémoire se
trompe » attire l'attention sur une erreur que le jury n'aurait peut-être pas
vue.

**Ajout fort à l'étape 3 :**
- 3 · Base — L'enregistre et lance l'attribution (fonction stockée + tâche
  planifiée toutes les 10 s)

**Notes — remplacer l'étape 3 par :**
> La base l'enregistre et déclenche l'attribution. Ce n'est pas l'application
> qui pilote : c'est une fonction stockée, relancée par une tâche planifiée
> qui balaie la base toutes les dix secondes.

---

## Slide 15 · `d4` — **garder**

---

## Slide 16 · `techno` — **garder**

✅ Riverpod vérifié (`flutter_riverpod: ^2.4.9` dans les trois `pubspec.yaml`).
✅ Passage de Mapbox à Google Maps attesté par le commit `e3c32e4`
« Replace Mapbox with Google Maps ».
✅ 167 commits (voir §5-h).

---

## Slide 17 · `dispatch` — **resserrer**

✅ Le contenu est maintenant exact, y compris la diffusion directe pour les
colis. Bonne correction.

⚠️ **95 secondes : la plus longue note de la présentation.** Et la parenthèse
sur le mémoire alourdit encore.

**Deux changements :**

1. Sortez la parenthèse des notes parlées. Mettez-la en note de secours, à
   utiliser seulement si on vous interroge.
2. Ajoutez le mécanisme réel — c'est ce qui vous distingue :

**Texte proposé, colonne de gauche, dernière ligne :**
- Une tâche planifiée balaie les offres expirées toutes les 10 s

**Notes resserrées (≈ 70 s) :**
> Premier défi : attribuer chaque commande à un livreur, automatiquement,
> même quand un livreur refuse ou ne répond pas. À gauche, une simulation.
> Le serveur propose la course au livreur connecté le plus proche, dans
> 7 kilomètres, avec 30 secondes pour répondre. L1 refuse, L2 ne répond pas,
> L3 refuse. Personne dans 7 km : le serveur élargit le rayon — une valeur
> que l'administrateur règle depuis le tableau de bord — et L4 accepte.
> [clic] Ce qui fait tourner tout cela, c'est une tâche planifiée dans la
> base : toutes les dix secondes, elle cherche les offres dont le délai est
> dépassé et les passe au livreur suivant. Aucune application n'intervient.
> [clic] Pour les colis et les factures, pas d'urgence de fraîcheur : la
> demande est visible tout de suite par tous les livreurs connectés, et le
> premier qui accepte la prend.

---

## Slide 18 · `argent` — **réécrire un point**

✅ Tout est vérifié : 3,5 DT / 3 km puis +0,5 DT/km
(`lib/core/utils/delivery_fee.dart:13,15`), 5 DT fixe (`:22`), 10 % et 23 %
(`generate_settlements_on_delivery`), blocage à solde ≤ 0 pour livreur **et**
commerçant (`20260805121032_prepaid_balance_model.sql:222-232`), plafond de
remise réglable avec 70 % par défaut.

⚠️ **Il manque votre deuxième source de revenu.** Le client paie les articles
**10 % plus cher** que le prix fixé par le commerçant :

```dart
// lib/core/utils/platform_pricing.dart:5
const double kPlatformMarkupRate = 0.10;
```

Le commentaire du fichier est sans ambiguïté : « Customers always pay base +
this markup; the partner and driver apps read the raw base price unchanged. »

Détail complet et exemple chiffré en §5-a. **Mettez-le sur la slide** : c'est
une décision de modèle économique, elle est défendable, et la cacher est plus
risqué que l'assumer.

**Texte proposé — remplacer le bloc « 10 % » par deux blocs :**
- **+10 %** — majoration sur le prix du commerçant, payée par le client
- **10 %** — commission prélevée au commerçant sur la commande

**Notes — ajouter après « tout est calculé par le serveur » :**
> La plateforme se rémunère de deux façons sur les articles. D'abord une
> majoration de 10 % : le client paie le prix du commerçant plus 10 %. Le
> commerçant, lui, voit toujours son prix d'origine dans son application.
> Ensuite une commission de 10 % prélevée sur la commande. Les deux taux sont
> réglables.

---

## Slide 19 · `securite` — **resserrer et chiffrer**

✅ La formulation sur les clés est maintenant juste.
✅ `verify_jwt = true` pour les cinq Edge Functions (`supabase/config.toml:21-37`).
✅ 15 routes admin sur 16 vérifient le rôle (voir §5-b).

⚠️ **88 secondes**, et la parenthèse sur la clé OpenRouter est à retirer de
l'oral (voir ci-dessous).

**Ce qui manque : des chiffres.** « Règles RLS » ne prouve rien. Ceci, si :

> ✅ **26 politiques RLS distinctes** sur **19 tables** protégées
> (comptage des `CREATE POLICY` et des `ENABLE ROW LEVEL SECURITY` dans les
> 92 migrations, dédoublonné par nom)

**Texte proposé, premier bloc :**
- Règles RLS
- 26 politiques sur 19 tables : la base filtre chaque requête selon le rôle

**Sur la parenthèse de la clé OpenRouter.** Vous avez écrit « À régler avant
la soutenance ». Deux cas :

- **Si vous l'avez retirée du `.env`** : supprimez la parenthèse des notes.
  Ne parlez pas d'un problème résolu.
- **Si elle est encore là** : retirez-la aujourd'hui, c'est une ligne. Puis
  supprimez la parenthèse.

Si le jury vous interroge sur les clés, la bonne réponse est celle du §7,
question 7.

---

## Slide 20 · `ia` — **garder, resserrer un peu**

✅ Tout est vérifié : OpenRouter principal et Gemini en secours
(`supabase/functions/ai-chat/index.ts:46-55`), relaxation progressive
(`ai-search/index.ts:278-320`, constante `RELAX_TIERS`), aucune trace de
`pgvector` ni d'embeddings dans tout le dépôt.

**Un ajout qui vaut le détour.** Votre invite système dit :

> « All four languages below are fully supported and EQUAL. English is a
> first-class choice, never a fallback. » (`ai-chat/index.ts:85`)

Vous gérez donc **quatre** langues (français, anglais, arabe, derja), pas
trois. La slide en annonce trois.

**Texte proposé, point 1 :**
- Demande libre : texte, photo ou voix, en français, anglais, arabe ou derja

---

## Slide 21 · `d5` — **garder**

---

## Slide 22 · `client` — **garder**

✅ 32 écrans, 3 langues d'interface (`lib/l10n/app_fr.arb`, `app_en.arb`,
`app_ar.arb`).

> Attention à ne pas confondre : **3 langues d'interface** (les fichiers de
> traduction) et **4 langues comprises par l'IA**. Les deux chiffres sont
> justes, dans leur contexte.

---

## Slide 23 · `livpart` — **corriger**

⚠️ Les notes disent encore « l'application Livreur, **en vert** » et
« l'application Commerçant, **en indigo** ». Vous avez corrigé la slide 9
mais pas celle-ci.

Couleurs réelles :

| Application | Couleur | Source |
|---|---|---|
| Client | `#059669` vert | `lib/core/theme/app_colors.dart:5` |
| Livreur | `#2563EB` **bleu** | `cmandili_driver/lib/core/theme/app_colors.dart:4` |
| Partenaire | `#4F46E5` indigo ✅ | `cmandili_partner/lib/core/theme/app_colors.dart:4` |

**Notes corrigées :** retirez simplement les deux mentions de couleur.
> À gauche, l'application Livreur. L'écran clé, c'est l'offre : 30 secondes
> pour accepter ou refuser. […] À droite, l'application Commerçant : les
> commandes reçues en temps réel, le formulaire de remise, et les
> statistiques.

---

## Slide 24 · `admin` — **garder**

✅ 24 pages, 16 routes API, 15 avec `requireAdmin` — la formulation actuelle
est exacte et honnête. Détail des 16 routes en §5-b.

**Ajout d'une phrase aux notes**, si vous voulez marquer un point :
> La seizième route est la déconnexion : elle ne vérifie pas le rôle, et
> c'est volontaire — il faut pouvoir se déconnecter même si on a perdu ses
> droits.

C'est exactement le genre de précision qui fait bonne impression.

---

## Slide 25 · `demo` — **garder**

Un seul conseil : **testez la lecture vidéo sur la machine de la salle**, et
gardez une copie sur clé USB, comme vos notes le disent déjà.

---

## Slide 26 · `d6` — **garder**

---

## Slide 27 · `chiffres` — **enrichir**

✅ Les huit chiffres sont exacts. Recomptage complet en §5-h.

⚠️ Ils décrivent la **taille** du projet, pas sa **difficulté**. Pour un jury
RAD, ajoutez-en trois :

| À ajouter | Valeur | Pourquoi ça parle |
|---|---|---|
| politiques RLS | **26** sur 19 tables | Sécurité mesurable |
| flux temps réel | **27** abonnements | Le côté distribué, chiffré |
| tests automatisés | **46** cas | Démonte l'idée « il n'a pas testé » |

**Notes — ajouter une phrase :**
> Et trois chiffres qui disent mieux la difficulté que le volume :
> 26 politiques de sécurité dans la base, 27 abonnements temps réel entre les
> applications et le serveur, et 46 tests automatisés.

---

## Slide 28 · `tests` — **réécrire**

C'est la slide où vous vous faites le plus de tort.

⚠️ Les notes disent : « Les tests sont manuels : c'est une limite que
j'assume, et la première de mes perspectives. »

**C'est faux.** Vous avez des tests automatisés. Comptage exact :

| Projet | Fichiers | Cas de test |
|---|---|---|
| Client (`test/`) | 8 | 38 |
| Livreur (`cmandili_driver/test/`) | 2 | 4 |
| Partenaire (`cmandili_partner/test/`) | 2 | 4 |
| **Total Flutter** | **12** | **46** |
| Admin (`cmandili_admin/lib/`) | 1 | script `npm test` déclaré |

Les fichiers ne sont pas des squelettes : `cart_vendor_test.dart` (6 cas),
`route_service_test.dart` (7 cas), `vendor_test.dart` (9 cas),
`venue_hours_test.dart` (7 cas), `auth_state_stream_test.dart` (3 cas),
`logout_navigation_test.dart` dans les trois applications.

**Texte proposé — ajouter un bloc à droite du tableau :**
- **46** tests automatisés
- 12 fichiers · panier, tarifs, horaires, authentification, navigation

**Notes corrigées :**
> [clic] À côté de ces six scénarios manuels, j'ai écrit 46 tests
> automatisés : ils couvrent le panier, le calcul des frais, les horaires
> d'ouverture, le flux d'authentification et la navigation après
> déconnexion. Ce qui manque encore, ce sont les tests de bout en bout —
> ceux qui rejoueraient un parcours complet sur un appareil. C'est la
> première de mes perspectives.

Vous passez de « je n'ai pas testé » à « j'ai testé les deux façons, voici ce
qui manque encore ». Ce n'est pas la même soutenance.

---

## Slide 29 · `bilan` — **corriger un point**

⚠️ « Ajouter des tests automatisés » est à reformuler, pour la même raison.

**Texte proposé :**
- Étendre les tests automatisés aux parcours complets

**Notes :** remplacer « ajouter des tests automatisés » par « étendre les
tests automatisés, qui couvrent aujourd'hui la logique métier, aux parcours
complets ».

---

## Slide 30 · `merci` — **garder la slide, réorganiser les notes**

✅ La slide elle-même est parfaite.

⚠️ Les notes font **445 mots** — c'est votre plus gros bloc, et il n'est pas
destiné à être lu. Ce sont des fiches de réponse.

**Deux conseils de forme :**

1. Séparez-les en deux : la phrase de clôture (15 s) d'un côté, les fiches de
   l'autre. Un seul bloc de 445 mots est illisible en situation.
2. Mettez à jour deux réponses :
   - **Tests manuels** → voir slide 28 ci-dessus.
   - **Comment choisissez-vous le livreur ?** → ajoutez la tâche planifiée :
     « …puis le suivant. C'est une tâche planifiée dans la base, qui tourne
     toutes les dix secondes, qui fait passer l'offre au livreur suivant. »

Dix questions supplémentaires, non couvertes par ces fiches, en §7.

---

## Slide 31 · `a1` — **garder, compléter**

✅ Les quatre points sont exacts : fonction stockée, rayon de repli réglable,
signal de vie toutes les 4 minutes
(`background_location_service.dart:366`), attribution atomique.

**Ajout proposé, un cinquième bloc :**
- Une tâche planifiée toutes les 10 secondes
- `cron.schedule('rotate-expired-offers', '10 seconds', …)` : c'est elle qui
  fait expirer une offre et la passe au suivant.

Référence : `20260818173500_schedule_rotate_expired_offers.sql:21-25`.

---

## Slide 32 · `a2` — **garder**

✅ Les trois lignes du tableau et l'explication du mécanisme sont exactes.
J'ai refait le calcul sur le code : voir §5 de `revue_presentation.md`. Bonne
correction.

---

## Slide 33 · `a3` — **garder**

✅ Les deux failles sont décrites exactement comme la migration corrective les
décrit (`20260921233000_fix_orders_anon_pii_exposure.sql`).

**Un chiffre à ajouter**, il est dans le commentaire du code : la vue
exposait **136 lignes sur 136** à un visiteur anonyme. Un chiffre précis vaut
mieux qu'un adjectif.

---

## Slide 34 · `a4` — **garder, préparer une réponse**

✅ « Extrait simplifié » est maintenant indiqué. Bien.

⚠️ **Préparez la question sur `c_markup`.** La vraie ligne 289 de la fonction
est :

```sql
v_unit := ROUND((COALESCE(v_variant, CASE WHEN v_on_promo
                 THEN v_item.discount_price ELSE v_item.price END)
                 + v_addons) * c_markup, 3);
```

Si un juré demande ce qu'est `c_markup`, voir la réponse prête en §5-a.

---

## Slide 35 · `a5` — **corriger une ligne**

⚠️ « Tests manuels, pas automatisés » est à remplacer.

**Texte proposé :**
- Pas de tests de bout en bout | 46 tests automatisés sur la logique métier,
  6 scénarios manuels ; les parcours complets restent à automatiser

---

## Slide 36 · `a6` — **garder**

---

# §3 — Points forts qui manquent

Sept choses existent dans votre code, impressionneraient ce jury, et ne sont
sur aucune slide.

### 1. Le calcul des prix est entièrement côté serveur — avec la preuve

Vous le dites slide 18 (« chaque dinar calculé par le serveur ») mais vous ne
le prouvez pas. La preuve tient en une phrase : la fonction `apply_promo_code`
**ignore le montant envoyé par le téléphone**. Elle reçoit la liste des
articles et recalcule tout depuis le catalogue
(`20260929100000_promo_codes_phase3.sql:270-295`).

**Où le mettre :** slide 18, une ligne en bas.
> Le serveur ne lit jamais le total annoncé par le téléphone : il reçoit les
> articles et recalcule.

### 2. 26 politiques RLS sur 19 tables

**Où :** slide 19 et slide 27.

### 3. 27 abonnements temps réel

23 flux `.stream()` et 4 canaux `.channel()` répartis sur les trois
applications mobiles (Client 12, Livreur 7, Partenaire 8).

**Où :** slide 13 ou la nouvelle slide du §4.

### 4. Les déclencheurs qui font respecter les règles métier

**25 déclencheurs** appliquent vos règles sans qu'aucune application ne
puisse les contourner :

- `generate_settlements_on_delivery` — commissions et subvention de fidélité
  au passage à « livrée » (`20260814090000_loyalty_at_checkout.sql:150`)
- `apply_loyalty_at_checkout` — compteur de fidélité et remise, **avant
  l'insertion** de la commande (`20260930090000_order_type_per_category.sql:94`)
- `enforce_prepaid_block` — blocage et déblocage automatiques
  (`20260805121032_prepaid_balance_model.sql:203`)

**Où :** slide 18, en une phrase.
> Ces règles ne sont pas dans les applications : ce sont des déclencheurs de
> base de données. Même en modifiant l'application, on ne peut pas les éviter.

### 5. Deux tâches planifiées dans la base

`rotate-expired-offers` toutes les 10 secondes, `auto-close-restaurants`
toutes les 5 minutes. Une troisième, `disable_happy_hour`, est mentionnée
dans un commentaire comme tournant chaque minute, mais elle n'est pas créée
par une migration — **non vérifiable** depuis le dépôt seul.

**Où :** slides 14, 17, 31.

### 6. L'application livreur tient quand le système Android la ferme

Vous avez un service d'arrière-plan avec un signal de vie toutes les
4 minutes, précisément parce que le flux GPS se tait quand le livreur est à
l'arrêt. Le commentaire du code explique le raisonnement complet
(`background_location_service.dart:352-365`). C'est de l'ingénierie réelle,
sur une contrainte réelle.

**Où :** nouvelle slide du §4, ou slide 31.

### 7. 46 tests automatisés

Voir slide 28.

---

# §4 — L'angle systèmes distribués

Vous passez un mastère **Réseaux et Applications Distribuées**. Le mot
« distribué » apparaît une seule fois dans toute la présentation, dans la
conclusion. C'est votre plus gros gisement de points.

La bonne nouvelle : **vous n'avez rien à inventer.** Tout est déjà dans le
code. Il faut le nommer.

## Ma recommandation : une slide neuve, en position 14 bis

Intercalez-la entre la slide 14 (le voyage d'une commande) et la slide 15. La
slide 14 raconte le parcours ; celle-ci explique ce que ce parcours pose comme
problèmes.

**Titre proposé :** `03 · Un système distribué — les cinq problèmes à résoudre`

| Problème | Ce que fait Amana |
|---|---|
| **Une seule vérité, quatre clients** | Les règles et les calculs vivent dans PostgreSQL : 26 politiques RLS, 25 déclencheurs |
| **Prévenir sans être interrogé** | 27 abonnements temps réel + notifications FCM : l'écran se met à jour tout seul |
| **Deux livreurs, une seule course** | Écriture conditionnelle : `UPDATE … WHERE driver_id IS NULL` — la base arbitre |
| **Un service externe tombe** | L'IA bascule sur un second fournisseur ; le reste de l'application continue |
| **Un téléphone se tait** | Signal de vie toutes les 4 min ; au-delà de 10 min, le livreur n'est plus sollicité |

**Notes proposées (≈ 55 s) :**

> Avant de passer à la réalisation, je voudrais nommer ce que ce schéma pose
> comme problèmes, parce que ce sont ceux d'un système distribué.
> [clic] Premier : quatre applications différentes lisent et écrivent les
> mêmes données. Il fallait une seule source de vérité. Les règles d'accès et
> les calculs sont dans la base — 26 politiques de sécurité, 25 déclencheurs.
> [clic] Deuxième : un client ne doit pas interroger le serveur en boucle
> pour savoir où en est sa commande. J'utilise 27 abonnements en temps réel,
> plus les notifications push.
> [clic] Troisième : deux livreurs peuvent accepter la même course à la même
> seconde. C'est la base qui arbitre, par une écriture conditionnelle.
> [clic] Quatrième : un service extérieur peut tomber. C'est arrivé — mon
> fournisseur d'IA principal est devenu inutilisable, et le second a pris le
> relais sans que rien d'autre ne s'arrête.
> [clic] Cinquième : un téléphone peut se taire sans prévenir. D'où un signal
> de vie toutes les quatre minutes.

## Si vous ne voulez pas ajouter de slide

Répartissez les cinq lignes :

- **Une seule vérité** → slide 13, en bas
- **Temps réel** → slide 14, dernière ligne
- **Concurrence** → slide 17, en bas
- **Tolérance aux pannes** → slide 20, dernière ligne
- **Signal de vie** → slide 31 (annexe A1)

C'est moins fort : le jury verra les morceaux, pas le raisonnement. Je
recommande la slide.

## Les points que vous devez pouvoir défendre à l'oral

**Latence.** La position part tous les 10 mètres ; les offres expirées sont
balayées toutes les 10 secondes ; le signal de vie est de 4 minutes et le
seuil hors ligne de 10 minutes. Ce sont des compromis entre fraîcheur de
l'information, batterie et coût.

**Mise à l'échelle — ses limites, soyez honnête.** `next_eligible_driver`
calcule la distance de Haversine **sur tous les livreurs connectés** à chaque
offre, sans index géographique. Avec quelques dizaines de livreurs à
Kairouan, c'est sans effet. Avec des milliers, il faudrait PostGIS et un index
spatial. Dire cela vous-même vaut mieux que de l'entendre.

**Perte de réseau.** Le livreur hors ligne ne reçoit pas la notification ;
l'offre expire au bout de 30 secondes et la tâche planifiée la passe au
suivant. Le système ne se bloque pas, il perd simplement un candidat.

---

# §5 — Réponses aux questions a à i

## a. `c_markup = 1.10` : définition, portée, bénéficiaire

**Deux endroits, cohérents entre eux.**

**Côté client (Flutter)** — `lib/core/utils/platform_pricing.dart:1-14` :

```dart
// Platform fee applied to all item prices in the client app.
// The base price stored in the DB (food_items.price / grocery_items.price)
// is what the restaurant/supermarket set. Customers always pay base + this
// markup; the partner and driver apps read the raw base price unchanged.
const double kPlatformMarkupRate = 0.10;

double applyPlatformMarkup(double basePrice) =>
    basePrice * (1 + kPlatformMarkupRate);
```

**Côté serveur (SQL)** — `20260929100000_promo_codes_phase3.sql:110` et `:289` :

```sql
c_markup CONSTANT NUMERIC := 1.10;
...
v_unit := ROUND((COALESCE(v_variant, CASE WHEN v_on_promo
                 THEN v_item.discount_price ELSE v_item.price END)
                 + v_addons) * c_markup, 3);
```

**Ce qu'il multiplie :** le prix de base de l'article, tel que le commerçant
l'a saisi, plus les suppléments. La constante SQL existe pour que le serveur
retrouve **exactement** le prix affiché au client quand il recalcule le panier
pour un code promo.

**Qui voit quoi :**

| Acteur | Prix vu | Preuve |
|---|---|---|
| Client | base × 1,10 | `applyPlatformMarkup` appelé dans le panier, la recherche IA, les offres (`cart_item.dart:134`, `search_result.dart:46`, `deals_tab.dart:48,64`) |
| Commerçant | base | commentaire `platform_pricing.dart:3-4` |
| Livreur | base | même commentaire |

**Qui reçoit la différence :** la plateforme. Le commerçant a fixé son prix et
raisonne dessus ; le client paie 10 % de plus ; l'écart ne revient à personne
d'autre.

**Exemple chiffré.** Un plat à **10,000 DT** fixé par le restaurant, livré à
5 km, commande ordinaire :

| Ligne | Montant | D'où ça vient |
|---|---|---|
| Prix du commerçant | 10,000 DT | `food_items.price` |
| Prix affiché au client | **11,000 DT** | × 1,10 |
| Frais de livraison | 4,500 DT | 3,500 + 2 × 0,500 |
| **Le client paie** | **15,500 DT** | |
| Majoration gardée | 1,000 DT | 11,000 − 10,000 |
| Commission commerçant (10 %) | 1,100 DT | `subtotal × 0,10` |
| Commission livreur (23 %) | 1,035 DT | `delivery_fee × 0,23` |
| **La plateforme encaisse** | **≈ 3,135 DT** | somme des trois |

> ⚠️ Une réserve. La commission du commerçant porte sur `NEW.subtotal`, qui
> contient déjà la majoration (`order_items.price` est stocké majoré — voir
> `platform_pricing.dart:10-13`). Les 1,100 DT sont donc calculés sur 11,000
> et non sur 10,000. Ce que le commerçant reçoit **en espèces** de la part du
> livreur n'est pas déterminable depuis le code : **non vérifiable**. Si le
> jury creuse, dites-le franchement et renvoyez au fonctionnement réel du
> terrain.

**Faut-il le mettre sur la slide « argent » ? Oui.** Trois raisons :

1. C'est la moitié de votre modèle économique sur les articles.
2. C'est visible dans l'extrait de l'annexe A4 que vous projetez déjà.
3. Une majoration assumée est banale en commerce ; une majoration découverte
   par le jury ressemble à une dissimulation.

**Phrase prête :**
> Sur les articles, la plateforme se rémunère deux fois : une majoration de
> 10 % payée par le client, et une commission de 10 % prélevée au commerçant.
> Le commerçant garde la maîtrise de son prix de vente, il voit toujours le
> sien.

---

## b. Les 16 routes API de l'administrateur

Commande : `find cmandili_admin/app/api -name route.ts | grep -v .next`

| # | Route | `requireAdmin` |
|---|---|---|
| 1 | `block` | ✅ |
| 2 | **`logout`** | ❌ |
| 3 | `promos` | ✅ |
| 4 | `promotions` | ✅ |
| 5 | `releve` | ✅ |
| 6 | `restaurants/categories` | ✅ |
| 7 | `restaurants/menu` | ✅ |
| 8 | `restaurants/toggle-ghost` | ✅ |
| 9 | `settings` | ✅ |
| 10 | `supermarkets/menu` | ✅ |
| 11 | `supermarkets/toggle-ghost` | ✅ |
| 12 | `support` | ✅ |
| 13 | `vendor-categories` | ✅ |
| 14 | `vendors` | ✅ |
| 15 | `vendors/items` | ✅ |
| 16 | `wallet/topup` | ✅ |

**La route sans contrôle : `logout`.** Voici son contenu entier
(`cmandili_admin/app/api/logout/route.ts:4-8`) :

```ts
export async function POST(_req: NextRequest) {
  const supabase = await createSupabaseServerClient()
  await supabase.auth.signOut()
  return NextResponse.redirect(new URL('/login', _req.url))
}
```

**Est-ce un oubli ou un choix ? Un choix, et le bon.** Elle ne lit aucune
donnée, n'en écrit aucune, et ne touche que la session de **celui qui
appelle**. Exiger le rôle admin pour se déconnecter créerait un piège : un
administrateur dont les droits viennent d'être retirés ne pourrait plus
fermer sa session.

**Risque : aucun.** Au pire, quelqu'un se déconnecte lui-même.

**Phrase prête :** celle de la slide 24 ci-dessus.

---

## c. Le modèle prépayé du commerçant

**Le solde, c'est quoi ?** Une ligne dans la table `wallets`, rattachée au
compte. La même table sert aux livreurs et aux commerçants.

**Qu'est-ce qui le fait baisser ?** Une seule chose : la commission. Au
passage d'une commande à « livrée » et en paiement espèces, le déclencheur
`generate_settlements_on_delivery` insère une ligne négative
(`20260814090000_loyalty_at_checkout.sql:198-210`) :

```sql
v_restaurant_commission := NEW.subtotal * v_restaurant_rate;  -- 10 %
INSERT INTO public.settlements (..., amount, type, ...)
VALUES (v_partner_user_id, 'restaurant', -v_restaurant_commission,
        'commission_deduction', ...);
```

Le commentaire du code est clair : le commerçant reçoit l'argent des articles
directement par le livreur ; le portefeuille ne suit **que** la commission due
à la plateforme.

**Quand le blocage se déclenche.** Fonction `enforce_prepaid_block`
(`20260805121032_prepaid_balance_model.sql:203-260`) :

```sql
SELECT COALESCE((SELECT setting_value::NUMERIC FROM public.global_settings
                  WHERE setting_key = 'prepaid_min_balance'), 0) INTO v_floor;
...
IF NEW.balance <= v_floor THEN
  NEW.status := 'blocked'; NEW.blocked_reason := 'balance';
  UPDATE public.partners SET is_blocked = TRUE WHERE user_id = NEW.user_id;
```

Donc : **dès que le solde atteint 0** (plancher réglable dans
`global_settings`). Le déblocage est automatique dès que le solde repasse
au-dessus — et seulement si le blocage venait du solde : un blocage manuel
posé par l'administrateur n'est pas levé tout seul (ligne 248).

**Ce que voit le commerçant.** Deux bandeaux dans son application :

- `cmandili_partner/lib/features/home/presentation/home_screen.dart:1506`
  → « Solde épuisé — vous ne recevez plus de commandes. »
- `:1508` → « Solde faible — pensez à recharger pour continuer »
- `cmandili_partner/lib/features/profile/presentation/payout_screen.dart:246`
  → carte « Solde prépayé »

> Le seuil exact du bandeau « Solde faible » n'est pas une constante nommée
> dans le code : **non vérifiable** sans dérouler l'arbre de widgets.

**Comment il recharge.** Il ne peut pas lui-même. Seul l'administrateur le
fait, par la route `POST /api/wallet/topup`
(`cmandili_admin/app/api/wallet/topup/route.ts:11,16`), qui exige
`requireAdmin()` et accepte `driver_id`, `partner_id` ou `client_id` plus un
montant. L'opération est tracée par `logAudit`.

C'est un choix défendable : la recharge correspond à un versement réel
d'argent, elle ne doit pas être déclarée par l'intéressé.

---

## d. Ce qui applique vraiment les 30 secondes et l'élargissement du rayon

**Trois pièces, et aucune n'est dans le téléphone.**

**1. L'horloge est posée en base.** Quand l'offre part, la fonction écrit une
date d'expiration (`20260915150000_driver_dispatch_fallback_radius.sql:143`) :

```sql
UPDATE public.orders
SET assigned_driver_id    = p_driver_id,
    assignment_expires_at = now() + make_interval(secs => p_window_seconds),
```

avec `p_window_seconds integer DEFAULT 30` (ligne 112).

**2. Une tâche planifiée balaie toutes les 10 secondes.**
`20260818173500_schedule_rotate_expired_offers.sql:21-25` :

```sql
SELECT cron.schedule(
  'rotate-expired-offers',
  '10 seconds',
  $$SELECT public.rotate_expired_offers();$$
);
```

`rotate_expired_offers()` cherche les commandes dont
`assignment_expires_at < now()`, ajoute le livreur à `passed_driver_ids`, et
appelle `next_eligible_driver` pour le suivant.

**3. L'élargissement du rayon est dans la même fonction**, pas dans le cron.
`dispatch_driver_for_order` (ligne 189 et suivantes) :

```sql
v_driver_id := public.next_eligible_driver(p_order_id, p_radius_km);  -- 7 km
IF v_driver_id IS NULL THEN
  v_driver_id := public.next_eligible_driver(p_order_id,
                   public.driver_fallback_radius_km());               -- 20 km
  v_used_fallback := v_driver_id IS NOT NULL;
END IF;
```

**Le compte à rebours affiché sur le téléphone du livreur** est purement
visuel :
`cmandili_driver/lib/features/orders/presentation/widgets/order_offer_dialog.dart:159`
→ `Timer.periodic(const Duration(seconds: 1), ...)`. Il ne décide de rien.

**Si le téléphone du livreur est hors ligne au moment de l'offre :** rien ne
se bloque. La notification FCM n'arrive pas, le livreur ne répond pas,
`assignment_expires_at` est dépassée au bout de 30 secondes, et le balayage
suivant — au plus tard 10 secondes après — passe l'offre au livreur suivant.
Le livreur injoignable est simplement ajouté à `passed_driver_ids`.

**C'est une excellente réponse de jury** : elle montre que vous avez conçu
pour la panne, pas seulement pour le cas nominal.

---

## e. Ce qui empêche deux livreurs de prendre la même course

**Pour les colis et factures (visibles par tous).** Une écriture
conditionnelle, côté application mais arbitrée par la base
(`cmandili_driver/lib/features/orders/presentation/available_orders_screen.dart:117-130`) :

```dart
// Atomically claim the order: only succeeds if driver_id is still null,
// so two drivers tapping Accept at the same time can't both win.
final claimed = await supabase
    .from('orders')
    .update({'driver_id': driverId})
    .eq('id', order.id)
    .isFilter('driver_id', null)
    .select('id');

if ((claimed as List).isEmpty) {
  throw "Cette commande vient d'être prise par un autre livreur.";
}
```

Cela produit un `UPDATE … WHERE id = ? AND driver_id IS NULL`. PostgreSQL
pose un verrou de ligne pendant la mise à jour : le second `UPDATE` attend,
puis réévalue la condition, qui est maintenant fausse. Il ne touche aucune
ligne, `claimed` est vide, et le second livreur voit le message. **Aucune
transaction explicite n'est nécessaire** : un `UPDATE` isolé est déjà atomique.

**Pour l'offre en cascade.** Deux gardes, côté serveur cette fois
(`20260915150000_driver_dispatch_fallback_radius.sql`) :

```sql
-- dispatch_driver_for_order, ligne 251
UPDATE public.orders
SET assigned_driver_id    = v_driver_id,
    assignment_expires_at = now() + make_interval(secs => p_window_secs)
WHERE id = p_order_id
  AND public.orders.driver_id IS NULL
  AND (assigned_driver_id IS NULL OR assignment_expires_at < now());

IF NOT FOUND THEN
  RETURN;   -- Lost the race — another process assigned first.
END IF;
```

```sql
-- offer_order_to_driver, ligne 143
UPDATE public.orders
SET assigned_driver_id = p_driver_id, ...
WHERE id = p_order_id
  AND driver_id IS NULL
RETURNING status INTO v_status;
```

La seconde garde protège contre une course entre la tâche planifiée et une
acceptation simultanée : si `v_status` est nul, l'offre n'est pas envoyée.

**La formule à retenir pour l'oral :** « Je ne fais pas confiance à l'ordre
d'arrivée. Chaque écriture porte sa propre condition, et c'est PostgreSQL qui
arbitre. »

---

## f. « Jusqu'à 30 % chez Glovo »

**Aucune entrée de votre bibliographie ne soutient ce chiffre.**
Recherche de « glovo » dans `bbbib.bib` : **0 occurrence**. Les trois entrées
concurrentes sont `yassir_site`, `livrina_site` et `zigzag_site`.

Le mémoire ne donne d'ailleurs aucun pourcentage : §1.5 écrit seulement
« Commissions élevées : les taux prélevés aux commerçants partenaires et
livreurs ».

**Formulation plus sûre, proposée :**

> **Commissions lourdes** — Des taux qui pèsent sur le petit commerce.
> Amana : 10 %, réglable par l'administrateur.

Vous remplacez un chiffre que vous ne pouvez pas défendre par un chiffre que
vous pouvez prouver en ouvrant votre tableau de bord.

**Si vous tenez à citer un concurrent**, il faut une source écrite et datée
(page tarifaire, article de presse) ajoutée à la bibliographie. Sans cela,
dites « des commissions nettement plus élevées », sans nom et sans chiffre.

---

## g. La page de garde du mémoire déposé

Extrait exact de `ameenPFE.tex:214-225` :

| Rôle | Nom |
|---|---|
| Élaboré par | **Adam Cherif** |
| Encadrant Académique | **M<sup>me</sup> Olfa Harrabi** |
| Encadrant Professionnel | **M. Firas Mzoughi** |

Également sur la page : Université de Kairouan, Institut Supérieur
d'Informatique et de Gestion de Kairouan, Mastère Professionnel « Réseaux et
Applications Distribuées », Année Universitaire 2025 / 2026.

**Aucun organisme d'accueil n'est nommé sur la page de garde** — recherche de
« organisme », « société », « entreprise », « stage effectué » dans tout le
mémoire : rien. Si le jury pose la question, répondez honnêtement : le projet
a été mené en autonomie, avec un encadrement professionnel.

---

## h. Recomptage des chiffres de la slide 27

Tous exacts. Commandes exécutées le 8 octobre 2026 :

| Chiffre | Valeur | Commande |
|---|---|---|
| Applications | **4** | 3 projets Flutter + 1 Next.js |
| Écrans et pages | **96** | 32 + 17 + 23 + 24 |
| — Client | 32 | `find lib -name '*_screen.dart' \| wc -l` |
| — Livreur | 17 | `find cmandili_driver/lib -name '*_screen.dart' \| wc -l` |
| — Partenaire | 23 | `find cmandili_partner/lib -name '*_screen.dart' \| wc -l` |
| — Admin | 24 | `find cmandili_admin/app -name 'page.tsx' \| grep -v .next \| wc -l` |
| Lignes de code | **76 713** | 32 266 + 14 145 + 19 083 + 11 219 (`.dart` hors `*.g.dart` et `app_localizations*`, `.ts`/`.tsx` hors `.next`) |
| Commits | **167** | `git rev-list --count HEAD` |
| Durée | **5 mois 12 j** | premier 2026-04-24, dernier 2026-10-06 |
| Migrations SQL | **92** | `ls supabase/migrations/*.sql \| wc -l` |
| Fonctions SQL | **42** | `CREATE [OR REPLACE] FUNCTION`, dédoublonné par nom |
| Triggers | **25** | `CREATE [OR REPLACE] TRIGGER`, dédoublonné par nom |
| Edge Functions | **5** | `ls -d supabase/functions/*/` |

**Une précaution.** Les 76 713 lignes comptent les commentaires et les lignes
vides. Votre code est très commenté. Dites « 76 000 lignes de fichiers
source », pas « de code » : si un juré lance `cloc`, il trouvera moins.

**Chiffres à ajouter (vérifiés) :** 26 politiques RLS, 19 tables protégées,
27 abonnements temps réel, 2 tâches planifiées, 46 tests automatisés.

---

## i. Les tests automatisés : vous en avez

**Oui — 46 cas de test, dans 12 fichiers.**

| Fichier | Cas |
|---|---|
| `test/vendor_test.dart` | 9 |
| `test/route_service_test.dart` | 7 |
| `test/venue_hours_test.dart` | 7 |
| `test/cart_vendor_test.dart` | 6 |
| `test/auth_state_stream_test.dart` | 3 |
| `test/widget_test.dart` | 3 |
| `test/logout_navigation_test.dart` | 2 |
| `test/auth_gate_navigation_test.dart` | 1 |
| `cmandili_driver/test/logout_navigation_test.dart` | 2 |
| `cmandili_driver/test/widget_test.dart` | 2 |
| `cmandili_partner/test/logout_navigation_test.dart` | 2 |
| `cmandili_partner/test/widget_test.dart` | 2 |
| **Total** | **46** |

Commande : `grep -cE "^\s*(test\|testWidgets)\(" <fichier>`

**Côté admin :** un fichier `cmandili_admin/lib/route-freshness.test.ts`, et
un script déclaré dans `package.json:10` :
`"test": "node --test \"lib/**/*.test.ts\""`.

**Côté SQL :** aucun. Pas de dossier `supabase/tests`, pas de pgTAP.

**Ce qui manque réellement**, et que vous pouvez annoncer comme perspective :
les tests de bout en bout — rejouer un parcours complet, du panier à la
livraison, sans intervention humaine.

---

# §6 — Minutage

Calcul fait sur le nombre de mots de vos notes, à 130 mots/minute en français.

## Temps actuel

| Bloc | Temps |
|---|---|
| Slides 1 à 29 | 19,1 min |
| Slide 30, phrase de clôture seule | 0,3 min |
| Vidéo (remplace les 50 s de notes de la slide 25) | +2,2 min |
| **Total estimé** | **≈ 22,6 min** |

Les notes de la slide 30 (445 mots, 3 min 25) sont des fiches de réponse, pas
du texte parlé : je ne les compte pas. Les 6 annexes (3,5 min) ne sont pas
jouées non plus.

**Vous tenez dans les 25 minutes.** Mais 22,6 min, c'est sans marge : on parle
plus lentement devant un jury, les transitions prennent du temps, et un
incident technique coûte une minute.

## Objectif : descendre à ≈ 21 min

Les cinq notes les plus longues :

| Slide | Temps actuel | Cible | Comment |
|---|---|---|---|
| 17 `dispatch` | 95 s | **70 s** | Sortir la parenthèse sur le mémoire ; ne pas raconter L1, L2, L3 un par un — l'animation le montre |
| 19 `securite` | 88 s | **65 s** | Retirer la parenthèse sur la clé OpenRouter ; fusionner les couches 2 et 3 en une phrase |
| 18 `argent` | 73 s | **70 s** | Déjà dense ; ajoutez la majoration (+10 s) mais coupez l'énumération des taux, qui est lisible à l'écran |
| 12 `classes` | 70 s | **45 s** | Version resserrée proposée slide 12 |
| 20 `ia` | 70 s | **55 s** | Couper « À droite, une vraie recherche et un vrai échange en derja » : les images parlent |

**Gain : environ 1 min 40.** Nouveau total : **≈ 21 min**, plus la nouvelle
slide du §4 (55 s) → **≈ 21,9 min**. Il vous reste 3 minutes de marge.

## Faut-il fusionner des slides ?

**Non.** Vos six transitions (3, 7, 10, 15, 21, 26) coûtent 25 secondes en
tout et structurent la présentation. Les garder.

La seule fusion envisageable serait 22 + 23 (Client + Livreur/Commerçant),
mais vous perdriez la respiration entre deux familles d'écrans. Je ne la
recommande pas.

## Conseil de répétition

Chronométrez-vous **deux fois** sur les slides 17, 18, 19 et 20 : elles
représentent à elles seules 5 minutes, soit un quart de votre temps. C'est là
que les dépassements se produisent.

---

# §7 — Dix questions probables du jury

Ces dix-là ne sont **pas** couvertes par vos fiches de la slide 30.

### 1. Pourquoi mettre la logique métier dans la base plutôt que dans un serveur applicatif ?

> Parce que quatre clients différents la partagent. Si le calcul des
> commissions vivait dans le téléphone, il faudrait l'écrire trois fois et
> republier à chaque changement de taux. Dans la base, il s'applique de la
> même façon pour tout le monde, et une règle ne peut pas être contournée en
> modifiant l'application. C'est aussi une limite : du PL/pgSQL se teste et se
> déboge moins facilement que du Dart.

### 2. Votre dispatch calcule la distance sur tous les livreurs à chaque offre. Ça tient à l'échelle ?

> Pas à grande échelle, non. `next_eligible_driver` calcule une distance de
> Haversine sur tous les livreurs connectés, sans index géographique. À
> Kairouan, avec quelques dizaines de livreurs, c'est sans effet mesurable.
> Au-delà, il faudrait PostGIS et un index spatial. C'est un choix assumé :
> j'ai optimisé pour la phase pilote, pas pour une échelle que je n'ai pas.

### 3. Une tâche planifiée toutes les 10 secondes : pourquoi pas un déclencheur, ou une notification ?

> Parce qu'une expiration n'est pas un événement : rien ne se produit dans la
> base quand 30 secondes passent. Il faut donc que quelqu'un vienne regarder.
> J'ai choisi 10 secondes comme compromis : un livreur attend au pire
> 40 secondes au lieu de 30, et la base fait six requêtes par minute, chacune
> limitée à 20 commandes.

### 4. Que se passe-t-il si votre tâche planifiée s'arrête ?

> Les offres n'expirent plus et les commandes restent assignées au premier
> livreur sollicité. J'ai prévu un repli partiel : la règle d'accès laisse les
> commandes non attribuées visibles de tous, ce que le commentaire du code
> appelle une dégradation gracieuse vers la diffusion. Mais une commande déjà
> assignée resterait bloquée. Une supervision de cette tâche manque.

### 5. Vos tests automatisés couvrent quoi exactement, et que ne couvrent-ils pas ?

> Ils couvrent la logique métier isolée : le calcul du panier, les frais de
> livraison, les horaires d'ouverture, le flux d'authentification, la
> navigation après déconnexion — 46 cas. Ce qu'ils ne couvrent pas, c'est le
> parcours complet, de la commande à la livraison, avec le serveur réel. Ces
> scénarios-là, je les ai rejoués à la main. Les automatiser est ma première
> perspective.

### 6. Pourquoi une majoration de 10 % en plus de la commission de 10 % ?

> Ce sont deux choses différentes. La majoration rémunère le service rendu au
> client : trouver, commander, faire livrer. La commission rémunère la mise en
> relation offerte au commerçant. Le commerçant garde la maîtrise de son prix
> de vente et le voit toujours inchangé dans son application. Les deux taux
> sont réglables depuis le tableau de bord.

### 7. Qu'est-ce qui empêche quelqu'un d'appeler directement vos Edge Functions ?

> La vérification du jeton : `verify_jwt = true` est posé pour les cinq
> fonctions. Soyons précis, cela écarte les appels anonymes, pas un
> utilisateur légitime qui abuserait du service — la clé publique de
> l'application est elle-même un jeton valide. C'est pour cela qu'une limite
> d'appels et un cache figurent dans mes perspectives.

### 8. Votre modèle prépayé : un livreur peut-il abandonner une course en cours quand il est bloqué ?

> Non, et c'est voulu. Le blocage pose un indicateur que seule la sélection du
> prochain livreur consulte. Une course déjà acceptée n'est pas interrompue :
> le livreur la termine et encaisse, c'est la commande suivante qu'il ne
> recevra pas. Interrompre une livraison en cours pénaliserait le client, pas
> le livreur.

### 9. Comment gérez-vous un client qui ferme l'application pendant sa livraison ?

> Rien n'est perdu. L'état vit dans la base, pas dans le téléphone. À la
> réouverture, l'application relit la commande et se réabonne au flux temps
> réel ; elle retrouve la position du livreur et le statut à jour. Les
> notifications push, elles, arrivent même application fermée — sauf sur
> certaines surcouches Android comme MIUI, une limite que j'ai documentée.

### 10. Si c'était à refaire, que changeriez-vous ?

> Deux choses. J'écrirais les tests automatisés en même temps que le code, pas
> après : plusieurs des anomalies trouvées à la main auraient été prises plus
> tôt. Et je mettrais en place une supervision du serveur dès le début —
> aujourd'hui, si une tâche planifiée s'arrête, je ne l'apprends qu'en
> observant un comportement anormal.

La question 10 revient très souvent. Une réponse préparée, précise et
autocritique y fait une excellente impression.

---

# §8 — Trois vérifications complémentaires

Ajouté le 8 octobre 2026. Les tests ont été **réellement exécutés**, pas lus.
Aucune écriture en base, aucun fichier du projet modifié.

---

## 8.1 — Les tests automatisés : exécution réelle

J'ai lancé `flutter test` dans les trois applications et `npm test` dans le
tableau de bord, puis chaque fichier séparément pour avoir le compte exact.

### Application Client — 38 tests, **tous passés**

| Fichier | Ce qu'il vérifie | Tests | Résultat |
|---|---|---|---|
| `vendor_test.dart` | Prix effectif d'un article selon sa promotion (active, expirée, sans date de fin), lecture d'une ligne de base incomplète, catalogue de repli, nom traduit | 9 | ✅ |
| `route_service_test.dart` | Distance d'un point à un itinéraire, détection de sortie de route, tolérance au tremblement GPS | 7 | ✅ |
| `venue_hours_test.dart` | Prochaine heure d'ouverture d'un commerce, conversion UTC → Tunis, passage de minuit, entrée invalide | 7 | ✅ |
| `cart_vendor_test.dart` | Ligne de panier : **la majoration est appliquée une seule fois**, sauvegarde et relecture, promotion expirée, panier mixte, fusion de deux lignes identiques | 6 | ✅ |
| `auth_state_stream_test.dart` | Le flux d'authentification survit à une erreur et voit la connexion suivante | 3 | ✅ |
| `widget_test.dart` | Paiement en espèces : clé de méthode, succès systématique, **CashGateway est la seule implémentation de PaymentGateway dans `lib/`** | 3 | ✅ |
| `logout_navigation_test.dart` | Reproduit le bug de déconnexion, puis vérifie le correctif | 2 | ✅ |
| `auth_gate_navigation_test.dart` | Changer `MaterialApp.home` met bien l'écran à jour | 1 | ✅ |

### Application Livreur — 4 tests, **tous passés**

| Fichier | Ce qu'il vérifie | Tests | Résultat |
|---|---|---|---|
| `logout_navigation_test.dart` | Bug de déconnexion puis correctif | 2 | ✅ |
| `widget_test.dart` | Formatage des montants : suffixe « DT », abréviation « K » au-dessus de 1000 | 2 | ✅ |

### Application Commerçant — 4 tests, **tous passés**

Identique au livreur : `logout_navigation_test.dart` (2) et `widget_test.dart` (2).

### Tableau de bord Administrateur — 7 tests, **tous passés**

Commande : `npm test` → `node --test "lib/**/*.test.ts"`

| Fichier | Ce qu'il vérifie | Tests | Résultat |
|---|---|---|---|
| `lib/route-freshness.test.ts` | Distance d'un livreur à son itinéraire, détection de sortie de route, tolérance au bruit GPS, itinéraire vide | 7 | ✅ |

### Aucun test n'est un squelette

C'est un point important, et il va contre l'intuition. Les fichiers nommés
`widget_test.dart` sont d'habitude le modèle livré par Flutter — le test du
compteur. **Ici, aucun des trois n'est le modèle d'origine** :

- Client : il vérifie que `CashGateway` est la **seule** implémentation de
  `PaymentGateway` dans tout `lib/`. C'est un test d'architecture : il casse
  si quelqu'un ajoute un moyen de paiement en douce.
- Livreur et Commerçant : formatage des montants en dinars.

Aucun test ignoré, aucun `skip`, aucune dépendance au réseau.

### Le chiffre à annoncer

| | |
|---|---|
| Tests Flutter | **46** |
| Tests Node (admin) | **7** |
| **Total** | **53** |
| **Échecs** | **0** |

> **Dites 53, pas 46.** Le chiffre de 46 que je vous avais donné venait d'un
> comptage de texte ; l'exécution réelle ajoute les 7 tests du tableau de
> bord. Et précisez « tous passent » : c'est vrai, je viens de les lancer.

**Correction à apporter à la slide 28 :**
- **53** tests automatisés — 46 Flutter, 7 côté tableau de bord
- 13 fichiers · panier, prix, horaires, itinéraires, authentification

---

## 8.2 — Majoration et commission : deux choses différentes

**Réponse courte : non, ce n'est pas la même chose.** Ce sont deux
prélèvements distincts, qui s'ajoutent.

### Les deux mécanismes, côte à côte

| | Majoration | Commission |
|---|---|---|
| Valeur | 10 % | 10 % |
| Où elle vit | `lib/core/utils/platform_pricing.dart:5` (constante Dart) | `global_settings.default_restaurant_commission_rate` (base) |
| Quand elle agit | À l'affichage, dans l'application Client | Au passage de la commande à « livrée » |
| Ce qu'elle touche | Le prix montré au client | Le portefeuille du commerçant |
| Qui peut la changer | Un développeur, avec une nouvelle version | L'administrateur, depuis le tableau de bord |
| Le commerçant la voit ? | Non | Oui, dans ses relevés |

Qu'elles vaillent toutes les deux 10 % est une **coïncidence de réglage**, pas
un lien technique. L'administrateur peut porter la commission à 15 % demain
sans que la majoration bouge.

### Une commande de 100 DT d'articles, tracée pas à pas

Hypothèse : le commerçant a fixé ses articles à **100,000 DT** au total, la
livraison fait 5 km, paiement en espèces, pas de fidélité ni de code promo.

**Étape 1 — Le commerçant saisit son prix.**
Stocké tel quel dans la base : **100,000 DT**.

**Étape 2 — Le client voit le prix majoré.**
`lib/core/utils/platform_pricing.dart:5-8`
```dart
const double kPlatformMarkupRate = 0.10;
double applyPlatformMarkup(double basePrice) =>
    basePrice * (1 + kPlatformMarkupRate);
```
Appelé pour chaque ligne de panier — `lib/features/cart/data/models/cart_item.dart:134` :
```dart
return applyPlatformMarkup(unitBase + addOns);
```
→ Le client voit **110,000 DT**.

> Ce comportement est testé : `test/cart_vendor_test.dart`, cas
> « price applies the platform markup once, like the other types ».

**Étape 3 — Les frais de livraison.**
`lib/core/utils/delivery_fee.dart:13,15` → 3,500 DT pour 3 km, puis
0,500 DT/km. Pour 5 km : 3,500 + 2 × 0,500 = **4,500 DT**.

**Étape 4 — Ce que le client paie.**
**110,000 + 4,500 = 114,500 DT**

**Étape 5 — Ce qui est écrit en base.**
`lib/features/orders/data/order_repository.dart:484-486` est explicite :
> « `order_items.price` is the CLIENT price — it was written from
> `CartItem.price`, which already includes the platform markup. »

Donc `order_items.price` et `orders.subtotal` valent **110,000**, pas 100,000
(`order_repository.dart:55` et `:104`).

**Étape 6 — Ce que voit le commerçant dans son application.**
Son prix d'origine, **100,000 DT**. Confirmé par le commentaire de
`platform_pricing.dart:3-4` (« the partner and driver apps read the raw base
price unchanged ») et par l'absence de tout appel à une majoration dans
`cmandili_partner/lib` et `cmandili_driver/lib` — vérifié, aucune occurrence.

**Étape 7 — Les prélèvements, à la livraison.**
`supabase/migrations/20260814090000_loyalty_at_checkout.sql:190-196` :
```sql
v_restaurant_commission := NEW.subtotal * v_restaurant_rate;   -- 110,000 × 0,10
v_driver_commission     := NEW.delivery_fee * v_driver_rate;   --   4,500 × 0,23
```

| Portefeuille | Mouvement | Montant |
|---|---|---|
| Commerçant | `commission_deduction` | **− 11,000 DT** |
| Livreur | `commission_deduction` | **− 1,035 DT** |

### Récapitulatif

| | Montant |
|---|---|
| Le client paie | **114,500 DT** |
| Le commerçant voit son prix | 100,000 DT |
| Prélevé au commerçant | − 11,000 DT |
| Prélevé au livreur | − 1,035 DT |
| **Revenu enregistré de la plateforme** | **12,035 DT** |
| Majoration encaissée en plus | 10,000 DT — voir la réserve ci-dessous |

### Deux points à savoir avant la soutenance

**1. La commission est calculée sur le prix majoré, pas sur le prix du
commerçant.** 11,000 DT, et non 10,000. Le commerçant paie donc 10 % d'un
prix qu'il n'a pas fixé. C'est une conséquence du fait que `subtotal` stocke
le prix client. Si un juré le remarque, assumez-le : c'est un choix de
calcul, pas une erreur — mais sachez le dire avant qu'on vous le dise.

**2. Le sort des 10,000 DT de majoration n'est pas dans le code.**
Le commentaire de `20260814090000_loyalty_at_checkout.sql:197-199` dit que
« le partenaire reçoit l'argent des articles directement par le livreur ; le
portefeuille ne suit que la commission ». Mais **nulle part le code ne dit si
le livreur remet 100,000 ou 110,000 au commerçant**. C'est une règle de
terrain, pas une règle codée : **non vérifiable** depuis le dépôt.

- Si le livreur remet 100,000 → la plateforme garde bien les 10,000.
- Si le livreur remet 110,000 → la majoration revient au commerçant et la
  plateforme ne gagne que les commissions.

**Préparez votre réponse.** Elle décide de votre modèle économique, et c'est
une question qu'un jury d'école de gestion-informatique posera.

**Phrase prête si on vous interroge :**
> La majoration est prélevée à l'affichage : le client paie 110 pour des
> articles à 100. Le commerçant garde son prix de référence et reçoit
> 100 ; la plateforme conserve les 10 de majoration, plus 10 % de commission.
> Le détail du reversement en espèces relève de la procédure
> d'exploitation, il n'est pas codé dans l'application.

---

## 8.3 — Les règles RLS : ce que je peux prouver, et ce que je ne peux pas

### Une limite à poser d'abord

**Je n'ai pas pu interroger la base en ligne.** Les deux clés publiques
présentes dans le dépôt renvoient une erreur 401 sur la description du schéma.
Je n'ai pas utilisé la clé `service_role` : elle donne tous les droits, et une
relecture n'en a pas besoin.

Tout ce qui suit vient donc des **92 migrations**, pas de la base réelle. Et
il y a un écart connu : **les premières tables du projet ont été créées avant
la mise en place du dossier `migrations`**. Leur activation RLS et leurs
politiques ne sont donc pas dans les fichiers.

Conséquence pratique : les chiffres ci-dessous sont des **minimums
vérifiables**, et une table « sans politique » ici veut dire « sans politique
visible dans les migrations », pas « sans protection ».

### Ce que les migrations montrent

| | Nombre |
|---|---|
| Relations référencées par les migrations | **30** (27 tables + 3 vues) |
| Tables créées par une migration | 17 |
| Vues créées par une migration | 3 — `food_items`, `grocery_items`, `orders_with_customer` |
| Tables avec `ENABLE ROW LEVEL SECURITY` | **19** |
| Tables avec au moins une politique | **20** |
| Politiques distinctes (par nom) | **49** |

> Le chiffre de **26 politiques** que je vous avais donné au §1 comptait les
> noms uniques toutes tables confondues ; certains noms se répètent d'une
> table à l'autre. Le comptage correct, politique par table, donne **49**.
> Utilisez 49 : il est plus juste et plus favorable.

### Les tables les mieux protégées

| Table | Politiques |
|---|---|
| `orders` | **10** |
| `drivers` | 3 |
| `saved_recipients` | 3 |
| `food_item_*` (4 tables d'options) | 2 chacune |
| `wallets`, `order_ratings`, `vendor_items`, `grocery_item_variants` | 2 chacune |

Dix politiques sur `orders` : c'est la table la plus sensible, et elle est la
plus encadrée. C'est un bon chiffre à citer.

### Tables avec RLS activée mais aucune politique dans les migrations

Trois cas, et **aucun n'est un risque** — au contraire :

| Table | Pourquoi ce n'est pas un problème |
|---|---|
| `audit_logs` | Journal d'activité. RLS activée **sans** politique = personne ne peut lire via l'API publique. Seul le `service_role` du tableau de bord y accède. C'est exactement ce qu'on veut d'un journal d'audit. |
| `generated_statements` | Relevés financiers générés. Même logique : lecture réservée au serveur. |
| `loyalty_driver_payouts` | Table héritée, plus alimentée (voir `20260814090000_loyalty_at_checkout.sql:235-237` : « Nothing inserts into it anymore »). Fermée, c'est le bon état. |

> **Rappel utile pour le jury.** Dans PostgreSQL, activer RLS **sans** écrire
> de politique revient à tout interdire, sauf au propriétaire et au
> `service_role`. Le danger est l'inverse : une table **sans RLS du tout**, ou
> une politique trop large — c'est exactement la faille n° 2 que vous avez
> trouvée et corrigée.

### Tables sans activation RLS visible dans les migrations

Six tables : `device_tokens`, `notifications`, `partners`, `restaurants`,
`supermarkets`, `user_addresses`, `vendor_categories`.

**Ce n'est pas la preuve qu'elles sont ouvertes.** Ce sont précisément les
tables historiques, créées avant le dossier `migrations` — leur RLS a été
posée depuis la console Supabase. `restaurants` et `supermarkets` sont même
des vues, pas des tables.

**Vérifiez-le vous-même avant la soutenance**, c'est deux minutes : dans la
console Supabase, onglet *Authentication → Policies*, la liste affiche chaque
table avec « RLS enabled » et le nombre de politiques. Faites une capture.
Si un juré demande « et les autres tables ? », vous ouvrez l'image.

### Ce que je recommande de dire

> La base compte une trentaine de relations. Dix-neuf tables ont RLS activée
> dans les migrations, avec 49 politiques — dont dix sur la seule table des
> commandes. Trois tables sensibles — journal d'audit, relevés financiers —
> ont RLS activée **sans aucune politique** : c'est volontaire, cela signifie
> que rien n'est lisible depuis l'API publique, seul le serveur y accède.

C'est honnête, c'est chiffré, et la dernière phrase montre que vous
comprenez le modèle de sécurité de PostgreSQL — pas seulement que vous
l'avez utilisé.
