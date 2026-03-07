import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/cubit/bar_cubit.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/data/catalog_overrides_storage.dart';
import 'package:my_bar/features/bar/data/external_catalog_cache_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/data/local_catalog_storage.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/data/repositories/bar_catalog_repository.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/catalog_data_source.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

void main() {
  test('switches source, reloads catalog, and keeps local entities', () async {
    final settingsStorage = InMemoryBarUiSettingsStorage();
    final seedProvider = _StaticProvider(
      source: 'seed_source',
      catalog: _seedCatalog,
    );
    final externalProvider = _StaticProvider(
      source: 'thecocktail_source',
      catalog: _externalCatalog,
    );

    final selector = SelectableExternalBarDataProvider(
      seedProvider: seedProvider,
      bootstrapDefaultProvider: seedProvider,
      bootstrapDefaultDataSource: CatalogDataSource.seed,
      theCocktailDbProvider: externalProvider,
    );

    final repository = BarCatalogRepository(
      externalProvider: selector,
      externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
      localStorage: InMemoryLocalCatalogStorage(),
      overridesStorage: InMemoryCatalogOverridesStorage(),
      templateCatalog: _seedCatalog,
    );

    final initialSnapshot = await repository.initialize();
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      settingsStorage: settingsStorage,
      catalogRepository: repository,
      externalProviderSelector: selector,
      initialSnapshot: initialSnapshot,
    );

    await cubit.addIngredient(
      name: 'Мой локальный ингредиент',
      category: 'Пользовательские',
      image: '',
    );

    await cubit.setCatalogDataSource(CatalogDataSource.theCocktailDb);

    expect(cubit.state.catalogDataSource, CatalogDataSource.theCocktailDb);
    expect(cubit.state.ingredients.any((item) => item.id == 'vodka'), isTrue);
    expect(
      cubit.state.ingredients.any(
        (item) => item.name == 'Мой локальный ингредиент',
      ),
      isTrue,
    );

    final persistedSettings = settingsStorage.readSettings();
    expect(
      persistedSettings.catalogDataSource,
      CatalogDataSource.theCocktailDb,
    );
  });

  test('keeps overrides after source switch roundtrip', () async {
    final seedProvider = _StaticProvider(
      source: 'seed_source',
      catalog: _seedCatalog,
    );
    final externalProvider = _StaticProvider(
      source: 'thecocktail_source',
      catalog: _externalCatalog,
    );

    final selector = SelectableExternalBarDataProvider(
      seedProvider: seedProvider,
      bootstrapDefaultProvider: seedProvider,
      bootstrapDefaultDataSource: CatalogDataSource.seed,
      theCocktailDbProvider: externalProvider,
    );

    final repository = BarCatalogRepository(
      externalProvider: selector,
      externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
      localStorage: InMemoryLocalCatalogStorage(),
      overridesStorage: InMemoryCatalogOverridesStorage(),
      templateCatalog: _seedCatalog,
    );

    final initialSnapshot = await repository.initialize();
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      catalogRepository: repository,
      externalProviderSelector: selector,
      initialSnapshot: initialSnapshot,
    );

    final baseCocktail = cubit.state.cocktails.singleWhere(
      (item) => item.id == 'martini',
    );

    await cubit.updateCocktail(
      cocktailId: baseCocktail.id,
      name: 'Мартини Домашний',
      description: baseCocktail.description,
      preparationSteps: baseCocktail.preparationSteps,
      image: baseCocktail.image,
      glassType: baseCocktail.glassType,
      ingredientIds: baseCocktail.ingredients.toSet(),
      ingredientSubstitutions: baseCocktail.ingredientSubstitutions.map(
        (key, value) => MapEntry(key, value.toSet()),
      ),
      ingredientAmounts: baseCocktail.ingredientAmounts,
      ingredientUnits: baseCocktail.ingredientUnits,
      optionalIngredientIds: baseCocktail.optionalIngredients.toSet(),
      decorationIngredientIds: baseCocktail.decorationIngredients.toSet(),
      tags: baseCocktail.tags.toSet(),
    );

    await cubit.setCatalogDataSource(CatalogDataSource.theCocktailDb);
    expect(
      cubit.state.cocktails.singleWhere((item) => item.id == 'martini').name,
      isNot('Мартини Домашний'),
    );

    await cubit.setCatalogDataSource(CatalogDataSource.seed);
    expect(
      cubit.state.cocktails.singleWhere((item) => item.id == 'martini').name,
      'Мартини Домашний',
    );
  });
}

class _StaticProvider implements ExternalBarDataProvider {
  const _StaticProvider({required this.source, required this.catalog});

  final String source;
  final BarCatalog catalog;

  @override
  String get sourceId => source;

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    return catalog.cocktails
        .map((item) => item.toJson())
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    return catalog.ingredients
        .map((item) => item.toJson())
        .toList(growable: false);
  }
}

final _seedCatalog = BarCatalog(
  ingredients: const <Ingredient>[
    Ingredient(
      id: 'gin',
      name: 'Джин',
      category: 'Крепкий алкоголь',
      image: '',
    ),
  ],
  cocktails: const <Cocktail>[
    Cocktail(
      id: 'martini',
      name: 'Мартини',
      image: '',
      ingredients: <String>['gin'],
      description: 'Джин',
      preparationSteps: <String>['Смешайте.'],
      glassType: 'Мартини',
      tags: <String>['Крепкие'],
    ),
  ],
);

final _externalCatalog = BarCatalog(
  ingredients: const <Ingredient>[
    Ingredient(
      id: 'vodka',
      name: 'Водка',
      category: 'Крепкий алкоголь',
      image: '',
    ),
  ],
  cocktails: const <Cocktail>[
    Cocktail(
      id: 'martini',
      name: 'Martini External',
      image: '',
      ingredients: <String>['vodka'],
      description: 'Водка',
      preparationSteps: <String>['Stir.'],
      glassType: 'Мартини',
      tags: <String>['Крепкие'],
    ),
  ],
);
