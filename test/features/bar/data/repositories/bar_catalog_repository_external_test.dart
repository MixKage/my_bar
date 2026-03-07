import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/catalog_overrides_storage.dart';
import 'package:my_bar/features/bar/data/external_catalog_cache_storage.dart';
import 'package:my_bar/features/bar/data/local_catalog_storage.dart';
import 'package:my_bar/features/bar/data/models/catalog_layer_models.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/data/repositories/bar_catalog_repository.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/catalog_entity_origin.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

void main() {
  test('falls back to external cache when network provider fails', () async {
    final cachedData = ExternalCatalogData(
      source: 'cached_external',
      fetchedAt: DateTime.now().toUtc(),
      ingredients: <ExternalIngredient>[
        ExternalIngredient(
          identity: const CatalogIdentity(
            source: 'cached_external',
            sourceId: 'gin',
            canonicalSlug: 'gin',
          ),
          ingredient: const Ingredient(
            id: 'gin',
            name: 'Джин (кэш)',
            category: 'Крепкий алкоголь',
            image: '',
          ),
        ),
      ],
      cocktails: <ExternalCocktail>[
        ExternalCocktail(
          identity: const CatalogIdentity(
            source: 'cached_external',
            sourceId: 'martini',
            canonicalSlug: 'martini',
          ),
          cocktail: const Cocktail(
            id: 'martini',
            name: 'Мартини (кэш)',
            image: '',
            ingredients: <String>['gin'],
            description: 'Джин',
            preparationSteps: <String>['Смешайте.'],
            glassType: 'Мартини',
            tags: <String>['Крепкие'],
          ),
        ),
      ],
    );

    final repository = BarCatalogRepository(
      externalProvider: const _ThrowingProvider(),
      externalCacheStorage: InMemoryExternalCatalogCacheStorage(
        initial: cachedData,
      ),
      localStorage: InMemoryLocalCatalogStorage(),
      overridesStorage: InMemoryCatalogOverridesStorage(),
      templateCatalog: _templateCatalog,
    );

    final snapshot = await repository.initialize();

    expect(snapshot.externalSourceAvailable, isFalse);
    expect(snapshot.ingredientItems.single.name, 'Джин (кэш)');
    expect(snapshot.cocktailItems.single.name, 'Мартини (кэш)');
  });

  test('falls back to seed when network and cache are unavailable', () async {
    final repository = BarCatalogRepository(
      externalProvider: const _ThrowingProvider(),
      externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
      localStorage: InMemoryLocalCatalogStorage(),
      overridesStorage: InMemoryCatalogOverridesStorage(),
      templateCatalog: _templateCatalog,
    );

    final snapshot = await repository.initialize();

    expect(snapshot.externalSourceAvailable, isFalse);
    expect(
      snapshot.ingredientItems,
      hasLength(_templateCatalog.ingredients.length),
    );
    expect(
      snapshot.cocktailItems,
      hasLength(_templateCatalog.cocktails.length),
    );
  });

  test('keeps override after editing external cocktail', () async {
    final localStorage = InMemoryLocalCatalogStorage();
    final overridesStorage = InMemoryCatalogOverridesStorage();
    final cacheStorage = InMemoryExternalCatalogCacheStorage();

    final repository = BarCatalogRepository(
      externalProvider: _StaticGenericProvider(catalog: _templateCatalog),
      externalCacheStorage: cacheStorage,
      localStorage: localStorage,
      overridesStorage: overridesStorage,
      templateCatalog: _templateCatalog,
    );

    await repository.initialize();

    final baseCocktail = repository.snapshot.cocktailItems.single;
    final updated = Cocktail(
      id: baseCocktail.id,
      name: 'Мартини Авторский',
      image: baseCocktail.image,
      ingredients: baseCocktail.ingredients,
      description: baseCocktail.description,
      preparationSteps: baseCocktail.preparationSteps,
      glassType: baseCocktail.glassType,
      tags: baseCocktail.tags,
      ingredientSubstitutions: baseCocktail.ingredientSubstitutions,
      ingredientAmounts: baseCocktail.ingredientAmounts,
      ingredientUnits: baseCocktail.ingredientUnits,
      optionalIngredients: baseCocktail.optionalIngredients,
      decorationIngredients: baseCocktail.decorationIngredients,
      isFavorite: baseCocktail.isFavorite,
    );

    final updatedSnapshot = await repository.updateCocktail(updated);
    expect(updatedSnapshot.cocktailItems.single.name, 'Мартини Авторский');
    expect(
      updatedSnapshot.cocktailOrigins[updated.id],
      CatalogEntityOrigin.overridden,
    );

    final reloadedRepository = BarCatalogRepository(
      externalProvider: _StaticGenericProvider(catalog: _templateCatalog),
      externalCacheStorage: cacheStorage,
      localStorage: localStorage,
      overridesStorage: overridesStorage,
      templateCatalog: _templateCatalog,
    );

    final reloadedSnapshot = await reloadedRepository.initialize();
    expect(reloadedSnapshot.cocktailItems.single.name, 'Мартини Авторский');
    expect(
      reloadedSnapshot.cocktailOrigins[updated.id],
      CatalogEntityOrigin.overridden,
    );
  });

  test(
    'keeps local entities independent from external catalog refresh',
    () async {
      final localStorage = InMemoryLocalCatalogStorage();
      final overridesStorage = InMemoryCatalogOverridesStorage();
      final cacheStorage = InMemoryExternalCatalogCacheStorage();

      final repository = BarCatalogRepository(
        externalProvider: _StaticGenericProvider(catalog: _templateCatalog),
        externalCacheStorage: cacheStorage,
        localStorage: localStorage,
        overridesStorage: overridesStorage,
        templateCatalog: _templateCatalog,
      );

      await repository.initialize();
      await repository.addIngredient(
        const Ingredient(
          id: 'my_custom_ingredient',
          name: 'Мой ингредиент',
          category: 'Пользовательские',
          image: '',
        ),
      );

      final refreshedExternalCatalog = BarCatalog(
        ingredients: <Ingredient>[
          const Ingredient(
            id: 'vodka',
            name: 'Водка',
            category: 'Крепкий алкоголь',
            image: '',
          ),
        ],
        cocktails: <Cocktail>[
          const Cocktail(
            id: 'vodka-shot',
            name: 'Водка шот',
            image: '',
            ingredients: <String>['vodka'],
            description: 'Водка',
            preparationSteps: <String>['Подавайте охлаждённой.'],
            glassType: 'Шот',
            tags: <String>['Шоты'],
          ),
        ],
      );

      final reloadedRepository = BarCatalogRepository(
        externalProvider: _StaticGenericProvider(
          catalog: refreshedExternalCatalog,
        ),
        externalCacheStorage: cacheStorage,
        localStorage: localStorage,
        overridesStorage: overridesStorage,
        templateCatalog: _templateCatalog,
      );

      final snapshot = await reloadedRepository.initialize();

      final localIngredient = snapshot.ingredientItems.singleWhere(
        (item) => item.id == 'my_custom_ingredient',
      );
      expect(localIngredient.name, 'Мой ингредиент');
      expect(
        snapshot.ingredientOrigins['my_custom_ingredient'],
        CatalogEntityOrigin.local,
      );
    },
  );
}

class _StaticGenericProvider implements ExternalBarDataProvider {
  const _StaticGenericProvider({required this.catalog});

  final BarCatalog catalog;

  @override
  String get sourceId => 'test_generic';

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

class _ThrowingProvider implements ExternalBarDataProvider {
  const _ThrowingProvider();

  @override
  String get sourceId => 'throwing';

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    throw Exception('Network is unavailable');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    throw Exception('Network is unavailable');
  }
}

final _templateCatalog = BarCatalog(
  ingredients: <Ingredient>[
    const Ingredient(
      id: 'gin',
      name: 'Джин',
      category: 'Крепкий алкоголь',
      image: '',
    ),
  ],
  cocktails: <Cocktail>[
    const Cocktail(
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
