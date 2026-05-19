enum GroceryCategory {
  vegetables,
  fruits,
  dairy,
  beverages,
  bakery,
  meat,
  snacks,
  household,
}

extension GroceryCategoryExtension on GroceryCategory {
  String get nameEn {
    switch (this) {
      case GroceryCategory.vegetables:
        return 'Vegetables';
      case GroceryCategory.fruits:
        return 'Fruits';
      case GroceryCategory.dairy:
        return 'Dairy';
      case GroceryCategory.beverages:
        return 'Beverages';
      case GroceryCategory.bakery:
        return 'Bakery';
      case GroceryCategory.meat:
        return 'Meat & Fish';
      case GroceryCategory.snacks:
        return 'Snacks';
      case GroceryCategory.household:
        return 'Household';
    }
  }

  String get nameAr {
    switch (this) {
      case GroceryCategory.vegetables:
        return 'خضروات';
      case GroceryCategory.fruits:
        return 'فواكه';
      case GroceryCategory.dairy:
        return 'منتجات الألبان';
      case GroceryCategory.beverages:
        return 'مشروبات';
      case GroceryCategory.bakery:
        return 'مخبوزات';
      case GroceryCategory.meat:
        return 'لحوم وأسماك';
      case GroceryCategory.snacks:
        return 'وجبات خفيفة';
      case GroceryCategory.household:
        return 'منتجات منزلية';
    }
  }

  String get nameFr {
    switch (this) {
      case GroceryCategory.vegetables:
        return 'Légumes';
      case GroceryCategory.fruits:
        return 'Fruits';
      case GroceryCategory.dairy:
        return 'Produits laitiers';
      case GroceryCategory.beverages:
        return 'Boissons';
      case GroceryCategory.bakery:
        return 'Boulangerie';
      case GroceryCategory.meat:
        return 'Viande et poisson';
      case GroceryCategory.snacks:
        return 'Snacks';
      case GroceryCategory.household:
        return 'Ménage';
    }
  }

  String get icon {
    switch (this) {
      case GroceryCategory.vegetables:
        return '🥬';
      case GroceryCategory.fruits:
        return '🍎';
      case GroceryCategory.dairy:
        return '🥛';
      case GroceryCategory.beverages:
        return '🥤';
      case GroceryCategory.bakery:
        return '🍞';
      case GroceryCategory.meat:
        return '🥩';
      case GroceryCategory.snacks:
        return '🍿';
      case GroceryCategory.household:
        return '🧹';
    }
  }
}
