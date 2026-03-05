import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/bar_catalog_storage.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows app shell with both tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MyBarApp(
        selectionStorage: SharedPreferencesIngredientSelectionStorage(
          preferences,
        ),
        catalogStorage: SharedPreferencesBarCatalogStorage(preferences),
        settingsStorage: SharedPreferencesBarUiSettingsStorage(preferences),
        initialCatalog: _testCatalog,
        templateCatalog: _testCatalog,
      ),
    );
    await tester.pump();

    expect(find.text('Мой Бар'), findsOneWidget);
    expect(find.text('Ингридиенты'), findsOneWidget);
    expect(find.text('Барная карта'), findsOneWidget);
  });

  testWidgets('restores selected ingredients from storage', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_ingredients': ['gin', 'vermouth'],
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MyBarApp(
        selectionStorage: SharedPreferencesIngredientSelectionStorage(
          preferences,
        ),
        catalogStorage: SharedPreferencesBarCatalogStorage(preferences),
        settingsStorage: SharedPreferencesBarUiSettingsStorage(preferences),
        initialCatalog: _testCatalog,
        templateCatalog: _testCatalog,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Барная карта'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Доступно 1 из 2'), findsOneWidget);
    expect(find.text('Мартини'), findsWidgets);
  });

  testWidgets('saves selected ingredients to storage', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MyBarApp(
        selectionStorage: SharedPreferencesIngredientSelectionStorage(
          preferences,
        ),
        catalogStorage: SharedPreferencesBarCatalogStorage(preferences),
        settingsStorage: SharedPreferencesBarUiSettingsStorage(preferences),
        initialCatalog: _testCatalog,
        templateCatalog: _testCatalog,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Водка'));
    await tester.pump(const Duration(milliseconds: 200));

    final persisted = await SharedPreferences.getInstance();
    final stored = persisted.getStringList('selected_ingredients') ?? [];
    expect(stored, contains('vodka'));
  });
}

final _testCatalog = BarCatalog(
  ingredients: <Ingredient>[
    Ingredient(
      id: 'vodka',
      name: 'Водка',
      category: 'Крепкий алкоголь',
      image: '',
    ),
    Ingredient(
      id: 'gin',
      name: 'Джин',
      category: 'Крепкий алкоголь',
      image: '',
    ),
    Ingredient(
      id: 'vermouth',
      name: 'Вермут',
      category: 'Аперитивы',
      image: '',
    ),
  ],
  cocktails: <Cocktail>[
    Cocktail(
      id: 'martini',
      name: 'Мартини',
      image: '',
      ingredients: <String>['gin', 'vermouth'],
      description: 'Джин, сухой вермут',
      preparationSteps: <String>[
        'Охладите бокал Мартини.',
        'Смешайте джин и вермут со льдом.',
        'Процедите в бокал.',
      ],
      glassType: 'Мартини',
      tags: <String>['IBA', 'Крепкие'],
    ),
    Cocktail(
      id: 'vodka-martini',
      name: 'Водка Мартини',
      image: '',
      ingredients: <String>['vodka', 'vermouth'],
      description: 'Водка, сухой вермут',
      preparationSteps: <String>[
        'Охладите бокал Мартини.',
        'Смешайте водку и вермут со льдом.',
        'Процедите и подавайте.',
      ],
      glassType: 'Мартини',
      tags: <String>['Крепкие'],
    ),
  ],
);
