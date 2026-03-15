enum MapExplorerIntent {
  all,
  deals,
  rentals,
  services,
  food,
  miniStores,
  experiences,
  trending,
}

extension MapExplorerIntentX on MapExplorerIntent {
  String get label {
    switch (this) {
      case MapExplorerIntent.all:
        return 'All';
      case MapExplorerIntent.deals:
        return 'Deals';
      case MapExplorerIntent.rentals:
        return 'Rentals';
      case MapExplorerIntent.services:
        return 'Services';
      case MapExplorerIntent.food:
        return 'Food';
      case MapExplorerIntent.miniStores:
        return 'Mini Stores';
      case MapExplorerIntent.experiences:
        return 'Experiences';
      case MapExplorerIntent.trending:
        return 'Trending';
    }
  }

  String get wireValue {
    switch (this) {
      case MapExplorerIntent.all:
        return 'all';
      case MapExplorerIntent.deals:
        return 'deals';
      case MapExplorerIntent.rentals:
        return 'rentals';
      case MapExplorerIntent.services:
        return 'services';
      case MapExplorerIntent.food:
        return 'food';
      case MapExplorerIntent.miniStores:
        return 'miniStores';
      case MapExplorerIntent.experiences:
        return 'experiences';
      case MapExplorerIntent.trending:
        return 'trending';
    }
  }

  static MapExplorerIntent? fromWireValue(String? value) {
    switch (value) {
      case 'all':
        return MapExplorerIntent.all;
      case 'deals':
        return MapExplorerIntent.deals;
      case 'rentals':
        return MapExplorerIntent.rentals;
      case 'services':
        return MapExplorerIntent.services;
      case 'food':
        return MapExplorerIntent.food;
      case 'miniStores':
        return MapExplorerIntent.miniStores;
      case 'experiences':
        return MapExplorerIntent.experiences;
      case 'trending':
        return MapExplorerIntent.trending;
      default:
        return null;
    }
  }
}
