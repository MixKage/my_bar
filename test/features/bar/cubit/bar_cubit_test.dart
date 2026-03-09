import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
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
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';

void main() {
  test('throws export error when bar catalog is unchanged', () async {
    final cubit = await _createCubit(templateCatalog: _templateCatalog);

    expect(() => cubit.exportCatalog(), throwsFormatException);
  });

  test('exports successfully when bar catalog was changed', () async {
    final cubit = await _createCubit(templateCatalog: _templateCatalog);

    await cubit.addIngredient(name: 'Кампари', category: 'Ликёры', image: '');

    final exported = cubit.exportCatalog();
    expect(exported.ingredients.length, 3);
  });

  test('updates cocktail preparation steps', () async {
    final cubit = await _createCubit(templateCatalog: _templateCatalog);

    await cubit.updateCocktailPreparation(
      cocktailId: 'martini',
      preparationSteps: <String>[
        'Наполните бокал льдом.',
        'Добавьте джин и вермут.',
        'Украсьте оливкой.',
      ],
    );

    final updated = cubit.state.cocktails.singleWhere(
      (cocktail) => cocktail.id == 'martini',
    );
    expect(updated.preparationSteps, hasLength(3));
    expect(updated.preparationSteps.first, 'Наполните бокал льдом.');
  });

  test(
    'treats optional and decoration ingredients as non-required for availability',
    () async {
      final catalog = BarCatalog(
        ingredients: <Ingredient>[
          const Ingredient(
            id: 'gin',
            name: 'Джин',
            category: 'Крепкий алкоголь',
            image: '',
          ),
          const Ingredient(
            id: 'lime',
            name: 'Лайм',
            category: 'Фрукты',
            image: '',
            isOptional: true,
          ),
          const Ingredient(
            id: 'mint',
            name: 'Мята',
            category: 'Травы',
            image: '',
            isDecoration: true,
          ),
        ],
        cocktails: <Cocktail>[
          const Cocktail(
            id: 'gin-smash',
            name: 'Gin Smash',
            image: '',
            ingredients: <String>['gin', 'lime', 'mint'],
            description: 'Джин, лайм, мята',
            preparationSteps: <String>['Смешайте и подавайте.'],
            glassType: 'Рокс',
            tags: <String>['Крепкие'],
          ),
        ],
      );

      final cubit = await _createCubit(templateCatalog: catalog);

      expect(cubit.state.availableCocktails, isEmpty);

      await cubit.toggleIngredient('gin');
      expect(cubit.state.availableCocktails, hasLength(1));
      expect(cubit.state.availableCocktails.single.id, 'gin-smash');
    },
  );

  test(
    'marks cocktail available when replacement ingredient is selected',
    () async {
      final catalog = BarCatalog(
        ingredients: <Ingredient>[
          const Ingredient(
            id: 'gin',
            name: 'Джин',
            category: 'Крепкий алкоголь',
            image: '',
          ),
          const Ingredient(
            id: 'vodka',
            name: 'Водка',
            category: 'Крепкий алкоголь',
            image: '',
          ),
          const Ingredient(
            id: 'vermouth',
            name: 'Вермут',
            category: 'Аперитивы',
            image: '',
          ),
        ],
        cocktails: <Cocktail>[
          const Cocktail(
            id: 'martini',
            name: 'Мартини',
            image: '',
            ingredients: <String>['gin', 'vermouth'],
            description: 'Джин, сухой вермут',
            preparationSteps: <String>['Смешайте ингредиенты и подавайте.'],
            glassType: 'Мартини',
            tags: <String>['Крепкие'],
            ingredientSubstitutions: <String, List<String>>{
              'gin': <String>['vodka'],
            },
          ),
        ],
      );

      final cubit = await _createCubit(templateCatalog: catalog);

      await cubit.toggleIngredient('vodka');
      await cubit.toggleIngredient('vermouth');

      expect(cubit.state.availableCocktails, hasLength(1));
      expect(cubit.state.availableCocktails.single.id, 'martini');
    },
  );

  test('updates cocktail core fields with full editor payload', () async {
    final cubit = await _createCubit(templateCatalog: _templateCatalog);

    await cubit.updateCocktail(
      cocktailId: 'martini',
      name: 'Сухой Мартини',
      description: 'Джин и вермут',
      preparationSteps: const <String>['Смешайте и подавайте охлаждённым.'],
      image: '/tmp/martini.jpg',
      glassType: 'Мартини',
      ingredientIds: const <String>{'gin', 'vermouth'},
      ingredientSubstitutions: const <String, Set<String>>{
        'gin': <String>{'vermouth'},
      },
      ingredientAmounts: const <String, String>{'gin': '50', 'vermouth': '10'},
      ingredientUnits: const <String, String>{'gin': 'мл', 'vermouth': 'мл'},
      optionalIngredientIds: const <String>{'vermouth'},
      decorationIngredientIds: const <String>{'vermouth'},
      tags: const <String>{'Крепкие'},
    );

    final cocktail = cubit.state.cocktails.singleWhere(
      (item) => item.id == 'martini',
    );
    expect(cocktail.name, 'Сухой Мартини');
    expect(cocktail.image, '/tmp/martini.jpg');
    expect(cocktail.ingredientAmountLabel('gin'), '50 мл');
    expect(cocktail.isIngredientOptional('vermouth'), isTrue);
    expect(cocktail.ingredientSubstitutions['gin'], contains('vermouth'));
  });

  test('toggles favorite flag for cocktail', () async {
    final cubit = await _createCubit(templateCatalog: _templateCatalog);

    expect(cubit.state.cocktails.first.isFavorite, isFalse);
    await cubit.toggleCocktailFavorite('martini');
    expect(cubit.state.cocktails.first.isFavorite, isTrue);
    await cubit.toggleCocktailFavorite('martini');
    expect(cubit.state.cocktails.first.isFavorite, isFalse);
  });

  test('does not toggle ingredient when visitor mode is enabled', () async {
    final cubit = await _createCubit(
      templateCatalog: _templateCatalog,
      settingsStorage: InMemoryBarUiSettingsStorage(
        initial: const BarUiSettings(visitorMode: true),
      ),
    );

    await cubit.toggleIngredient('gin');

    expect(cubit.state.selectedIngredientIds, isEmpty);
  });

  test('persists visitor, bar menu only and power saving modes', () async {
    final settingsStorage = InMemoryBarUiSettingsStorage();
    final cubit = await _createCubit(
      templateCatalog: _templateCatalog,
      settingsStorage: settingsStorage,
    );

    await cubit.setVisitorMode(true);
    await cubit.setBarMenuOnlyMode(true);
    await cubit.setPowerSavingMode(true);

    final persisted = settingsStorage.readSettings();
    expect(persisted.visitorMode, isTrue);
    expect(persisted.barMenuOnlyMode, isTrue);
    expect(persisted.powerSavingMode, isTrue);
  });

  test('persists selected app language', () async {
    final settingsStorage = InMemoryBarUiSettingsStorage();
    final cubit = await _createCubit(
      templateCatalog: _templateCatalog,
      settingsStorage: settingsStorage,
    );

    await cubit.setAppLanguage(AppLanguage.english);

    expect(cubit.state.appLanguage, AppLanguage.english);
    expect(settingsStorage.readSettings().appLanguage, AppLanguage.english);
  });

  test('persists selected measurement system', () async {
    final settingsStorage = InMemoryBarUiSettingsStorage();
    final cubit = await _createCubit(
      templateCatalog: _templateCatalog,
      settingsStorage: settingsStorage,
    );

    await cubit.setMeasurementSystem(MeasurementSystem.ml);

    expect(cubit.state.measurementSystem, MeasurementSystem.ml);
    expect(
      settingsStorage.readSettings().measurementSystem,
      MeasurementSystem.ml,
    );
  });

  test('updates ingredient fields', () async {
    final cubit = await _createCubit(templateCatalog: _templateCatalog);

    await cubit.updateIngredient(
      ingredientId: 'gin',
      name: 'Лондон Драй Джин',
      category: 'Крепкий алкоголь',
      image: '/tmp/gin.jpg',
      isDecoration: true,
      isOptional: true,
    );

    final ingredient = cubit.state.ingredients.singleWhere(
      (item) => item.id == 'gin',
    );
    expect(ingredient.name, 'Лондон Драй Джин');
    expect(ingredient.image, '/tmp/gin.jpg');
    expect(ingredient.isDecoration, isTrue);
    expect(ingredient.isOptional, isTrue);
  });

  test('does not update ingredient in visitor mode', () async {
    final cubit = await _createCubit(
      templateCatalog: _templateCatalog,
      settingsStorage: InMemoryBarUiSettingsStorage(
        initial: const BarUiSettings(visitorMode: true),
      ),
    );

    await cubit.updateIngredient(
      ingredientId: 'gin',
      name: 'Новый Джин',
      category: 'Крепкий алкоголь',
      image: '',
    );

    final ingredient = cubit.state.ingredients.singleWhere(
      (item) => item.id == 'gin',
    );
    expect(ingredient.name, 'Джин');
  });
}

Future<BarCubit> _createCubit({
  required BarCatalog templateCatalog,
  InMemoryIngredientSelectionStorage? selectionStorage,
  InMemoryBarUiSettingsStorage? settingsStorage,
}) async {
  final seedProvider = _StaticExternalProvider(catalog: templateCatalog);
  final selector = SelectableExternalBarDataProvider(
    seedProvider: seedProvider,
    bootstrapDefaultProvider: seedProvider,
    bootstrapDefaultDataSource: CatalogDataSource.seed,
  );
  final repository = BarCatalogRepository(
    externalProvider: selector,
    externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
    localStorage: InMemoryLocalCatalogStorage(),
    overridesStorage: InMemoryCatalogOverridesStorage(),
    templateCatalog: templateCatalog,
  );
  final snapshot = await repository.initialize();

  return BarCubit(
    selectionStorage: selectionStorage ?? InMemoryIngredientSelectionStorage(),
    settingsStorage: settingsStorage ?? InMemoryBarUiSettingsStorage(),
    catalogRepository: repository,
    externalProviderSelector: selector,
    initialSnapshot: snapshot,
  );
}

class _StaticExternalProvider implements ExternalBarDataProvider {
  const _StaticExternalProvider({required this.catalog});

  final BarCatalog catalog;

  @override
  String get sourceId => 'test_static';

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    return catalog.ingredients
        .map((ingredient) => ingredient.toJson())
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    return catalog.cocktails
        .map((cocktail) => cocktail.toJson())
        .toList(growable: false);
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
    const Ingredient(
      id: 'vermouth',
      name: 'Вермут',
      category: 'Аперитивы',
      image: '',
    ),
  ],
  cocktails: <Cocktail>[
    const Cocktail(
      id: 'martini',
      name: 'Мартини',
      image: '',
      ingredients: <String>['gin', 'vermouth'],
      description: 'Джин, сухой вермут',
      preparationSteps: <String>[
        'Охладите бокал Мартини.',
        'Перемешайте джин и вермут со льдом в смесительном стакане.',
        'Процедите в бокал и подавайте.',
      ],
      glassType: 'Мартини',
      tags: <String>['IBA', 'Крепкие'],
    ),
  ],
);
