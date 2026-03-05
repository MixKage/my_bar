import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/cubit/bar_cubit.dart';
import 'package:my_bar/features/bar/data/bar_catalog_storage.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

void main() {
  test('throws export error when bar catalog is unchanged', () {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    expect(() => cubit.exportCatalog(), throwsFormatException);
  });

  test('exports successfully when bar catalog was changed', () async {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    await cubit.addIngredient(name: 'Кампари', category: 'Ликёры', image: '');

    final exported = cubit.exportCatalog();
    expect(exported.ingredients.length, 3);
  });

  test('updates cocktail preparation steps', () async {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

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

      final cubit = BarCubit(
        selectionStorage: InMemoryIngredientSelectionStorage(),
        catalogStorage: InMemoryBarCatalogStorage(),
        settingsStorage: InMemoryBarUiSettingsStorage(),
        initialCatalog: catalog,
        templateCatalog: catalog,
      );

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

      final cubit = BarCubit(
        selectionStorage: InMemoryIngredientSelectionStorage(),
        catalogStorage: InMemoryBarCatalogStorage(),
        settingsStorage: InMemoryBarUiSettingsStorage(),
        initialCatalog: catalog,
        templateCatalog: catalog,
      );

      await cubit.toggleIngredient('vodka');
      await cubit.toggleIngredient('vermouth');

      expect(cubit.state.availableCocktails, hasLength(1));
      expect(cubit.state.availableCocktails.single.id, 'martini');
    },
  );

  test('updates cocktail core fields with full editor payload', () async {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

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
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    expect(cubit.state.cocktails.first.isFavorite, isFalse);
    await cubit.toggleCocktailFavorite('martini');
    expect(cubit.state.cocktails.first.isFavorite, isTrue);
    await cubit.toggleCocktailFavorite('martini');
    expect(cubit.state.cocktails.first.isFavorite, isFalse);
  });

  test('does not toggle ingredient when visitor mode is enabled', () async {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(
        initial: const BarUiSettings(visitorMode: true),
      ),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    await cubit.toggleIngredient('gin');

    expect(cubit.state.selectedIngredientIds, isEmpty);
  });

  test('persists visitor and bar menu only modes', () async {
    final settingsStorage = InMemoryBarUiSettingsStorage();
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      settingsStorage: settingsStorage,
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    await cubit.setVisitorMode(true);
    await cubit.setBarMenuOnlyMode(true);

    final persisted = settingsStorage.readSettings();
    expect(persisted.visitorMode, isTrue);
    expect(persisted.barMenuOnlyMode, isTrue);
  });
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
