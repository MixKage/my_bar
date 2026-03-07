import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/domain/models/catalog_data_source.dart';

void main() {
  final seedProvider = _StubProvider(source: 'seed_source');
  final theCocktailProvider = _StubProvider(
    source: 'thecocktail_source',
    format: ExternalProviderFormat.theCocktailDb,
  );

  test('uses bootstrap default when user setting is not set', () {
    final selector = SelectableExternalBarDataProvider(
      seedProvider: seedProvider,
      bootstrapDefaultProvider: theCocktailProvider,
      bootstrapDefaultDataSource: CatalogDataSource.theCocktailDb,
      theCocktailDbProvider: theCocktailProvider,
    );

    expect(selector.activeDataSource, CatalogDataSource.theCocktailDb);
    expect(selector.sourceId, 'thecocktail_source');
  });

  test('user setting seed has higher priority than bootstrap default', () {
    final selector = SelectableExternalBarDataProvider(
      seedProvider: seedProvider,
      bootstrapDefaultProvider: theCocktailProvider,
      bootstrapDefaultDataSource: CatalogDataSource.theCocktailDb,
      theCocktailDbProvider: theCocktailProvider,
      userSelectedDataSource: CatalogDataSource.seed,
    );

    expect(selector.activeDataSource, CatalogDataSource.seed);
    expect(selector.sourceId, 'seed_source');
  });

  test(
    'user setting thecocktaildb has higher priority than bootstrap seed',
    () {
      final selector = SelectableExternalBarDataProvider(
        seedProvider: seedProvider,
        bootstrapDefaultProvider: seedProvider,
        bootstrapDefaultDataSource: CatalogDataSource.seed,
        theCocktailDbProvider: theCocktailProvider,
        userSelectedDataSource: CatalogDataSource.theCocktailDb,
      );

      expect(selector.activeDataSource, CatalogDataSource.theCocktailDb);
      expect(selector.sourceId, 'thecocktail_source');
    },
  );

  test('falls back to seed when thecocktaildb is unavailable', () {
    final selector = SelectableExternalBarDataProvider(
      seedProvider: seedProvider,
      bootstrapDefaultProvider: seedProvider,
      bootstrapDefaultDataSource: CatalogDataSource.seed,
      userSelectedDataSource: CatalogDataSource.theCocktailDb,
    );

    expect(selector.activeDataSource, CatalogDataSource.seed);
    expect(selector.sourceId, 'seed_source');
    expect(selector.isTheCocktailDbAvailable, isFalse);
  });

  test('switches source at runtime', () {
    final selector = SelectableExternalBarDataProvider(
      seedProvider: seedProvider,
      bootstrapDefaultProvider: seedProvider,
      bootstrapDefaultDataSource: CatalogDataSource.seed,
      theCocktailDbProvider: theCocktailProvider,
    );

    final changed = selector.selectDataSource(CatalogDataSource.theCocktailDb);

    expect(changed, isTrue);
    expect(selector.activeDataSource, CatalogDataSource.theCocktailDb);
    expect(selector.sourceId, 'thecocktail_source');
  });
}

class _StubProvider implements ExternalBarDataProvider {
  const _StubProvider({
    required this.source,
    this.format = ExternalProviderFormat.generic,
  });

  final String source;

  @override
  final ExternalProviderFormat format;

  @override
  String get sourceId => source;

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    return const <Map<String, dynamic>>[];
  }
}
