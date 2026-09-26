// Platform fee applied to all item prices in the client app.
// The base price stored in the DB (food_items.price / grocery_items.price)
// is what the restaurant/supermarket set. Customers always pay base + this
// markup; the partner and driver apps read the raw base price unchanged.
const double kPlatformMarkupRate = 0.10;

double applyPlatformMarkup(double basePrice) =>
    basePrice * (1 + kPlatformMarkupRate);

/// Inverse of [applyPlatformMarkup]. Needed when reading back a price that
/// was already stored with the markup baked in (e.g. `order_items.price`)
/// into a model whose price getter applies the markup itself.
double removePlatformMarkup(double clientPrice) =>
    clientPrice / (1 + kPlatformMarkupRate);
