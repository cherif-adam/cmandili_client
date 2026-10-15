import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// A restaurant category, in the customer's language.
///
/// The values themselves ('Pizza', 'Italian', 'Fast Food'...) are what the
/// admin dashboard writes into `restaurants.categories` and what the filter
/// compares against, so they stay as they are; only what is shown changes.
/// A tag the shop typed itself is shown as written.
String cuisineLabel(AppLocalizations l, String value) {
  switch (value) {
    case 'All':
      return l.filterAll;
    case 'Pâtisseries':
      return l.cuisinePastry;
    case 'Pizza':
      return l.cuisinePizza;
    case 'Burgers':
      return l.cuisineBurgers;
    case 'Sushi':
      return l.cuisineSushi;
    case 'Mexican':
      return l.cuisineMexican;
    case 'Italian':
      return l.cuisineItalian;
    case 'Fast Food':
      return l.cuisineFastFood;
    default:
      return value;
  }
}
