import 'package:flutter_test/flutter_test.dart';
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
import 'package:my_bar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows app shell with both tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'bar_ui_app_language': 'ru'});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
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
      'bar_ui_app_language': 'ru',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
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
    SharedPreferences.setMockInitialValues({'bar_ui_app_language': 'ru'});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
    );
    await tester.pump();

    await tester.tap(find.text('Водка'));
    await tester.pump(const Duration(milliseconds: 200));

    final persisted = await SharedPreferences.getInstance();
    final stored = persisted.getStringList('selected_ingredients') ?? [];
    expect(stored, contains('vodka'));
  });
}

Future<MyBarApp> _buildApp({
  required SharedPreferences preferences,
  required BarCatalog catalog,
}) async {
  final selectionStorage = SharedPreferencesIngredientSelectionStorage(
    preferences,
  );
  final settingsStorage = SharedPreferencesBarUiSettingsStorage(preferences);
  final seedProvider = _StaticExternalProvider(catalog: catalog);
  final selector = SelectableExternalBarDataProvider(
    seedProvider: seedProvider,
    bootstrapDefaultProvider: seedProvider,
    bootstrapDefaultDataSource: CatalogDataSource.seed,
  );

  final repository = BarCatalogRepository(
    externalProvider: selector,
    externalCacheStorage: SharedPreferencesExternalCatalogCacheStorage(
      preferences,
    ),
    localStorage: SharedPreferencesLocalCatalogStorage(preferences),
    overridesStorage: SharedPreferencesCatalogOverridesStorage(preferences),
    templateCatalog: catalog,
  );

  final snapshot = await repository.initialize();

  return MyBarApp(
    selectionStorage: selectionStorage,
    settingsStorage: settingsStorage,
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
