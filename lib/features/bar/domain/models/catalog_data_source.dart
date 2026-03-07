enum CatalogDataSource { seed, theCocktailDb }

extension CatalogDataSourceX on CatalogDataSource {
  String get storageValue {
    switch (this) {
      case CatalogDataSource.seed:
        return 'seed';
      case CatalogDataSource.theCocktailDb:
        return 'thecocktaildb';
    }
  }

  String get title {
    switch (this) {
      case CatalogDataSource.seed:
        return 'Встроенная база';
      case CatalogDataSource.theCocktailDb:
        return 'TheCocktailDB';
    }
  }

  String get description {
    switch (this) {
      case CatalogDataSource.seed:
        return 'Работает офлайн, стабильный встроенный каталог.';
      case CatalogDataSource.theCocktailDb:
        return 'Загружает внешний каталог из сети с fallback на кэш и seed.';
    }
  }

  static CatalogDataSource? tryParse(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'seed':
        return CatalogDataSource.seed;
      case 'thecocktaildb':
        return CatalogDataSource.theCocktailDb;
      default:
        return null;
    }
  }
}
