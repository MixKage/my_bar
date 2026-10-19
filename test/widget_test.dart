import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/onboarding_storage.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/data/catalog_overrides_storage.dart';
import 'package:my_bar/features/bar/data/external_catalog_cache_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/data/local_catalog_storage.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/data/repositories/bar_catalog_repository.dart';
import 'package:my_bar/features/bar/data/shopping_list_storage.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/catalog_data_source.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/presentation/pages/bar_menu_page.dart';
import 'package:my_bar/features/bar/presentation/pages/surprise_cocktail_page.dart';
import 'package:my_bar/features/bar/presentation/pages/raw_bar_page.dart';
import 'package:my_bar/features/bar/presentation/widgets/neon_bottom_navigation.dart';
import 'package:my_bar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final bottomInset in [0.0, 34.0]) {
    for (final powerSavingMode in [false, true]) {
      testWidgets('bottom navigation keeps an 8-point gap above safe area '
          '(inset: $bottomInset, power saving: $powerSavingMode)', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.padding = FakeViewPadding(top: 47, bottom: bottomInset);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetPadding);
        SharedPreferences.setMockInitialValues({
          'bar_ui_app_language': 'ru',
          'bar_ui_power_saving_mode': powerSavingMode,
        });
        final preferences = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          await _buildApp(preferences: preferences, catalog: _testCatalog),
        );
        await tester.pump();
        // The neon border animates continuously when power saving is off.
        await tester.pump(const Duration(milliseconds: 400));

        final navigationPanel = find
            .descendant(
              of: find.byType(NeonBottomNavigation),
              matching: find.byType(ClipRRect),
            )
            .first;
        expect(
          tester.getRect(navigationPanel).bottom,
          closeTo(844 - bottomInset - 8, 0.01),
        );
        final expectedOverlayPadding =
            kNeonBottomNavigationHeight + bottomInset + 8;
        final ingredientsPage = tester.widget<RawBarPage>(
          find.byType(RawBarPage),
        );
        expect(ingredientsPage.powerSavingMode, powerSavingMode);
        expect(ingredientsPage.bottomOverlayPadding, expectedOverlayPadding);

        await tester.tap(find.text('Барная карта'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester
              .widget<BarMenuPage>(find.byType(BarMenuPage))
              .bottomOverlayPadding,
          expectedOverlayPadding,
        );
        expect(
          tester.getRect(navigationPanel).bottom,
          closeTo(844 - bottomInset - 8, 0.01),
        );
        expect(find.text('Доступно 0 из 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('hidden landscape menu can be restored beside a display cutout', (
    tester,
  ) async {
    // The side toggle has a continuous decorative border animation.
    Future<void> pumpShell() async {
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.padding = const FakeViewPadding(left: 64, top: 24, bottom: 24);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({
      'bar_ui_app_language': 'ru',
      'bar_ui_power_saving_mode': true,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
    );
    await pumpShell();

    await tester.tap(find.byTooltip('Скрыть меню'));
    await pumpShell();
    final handle = tester.getRect(find.byTooltip('Показать меню'));
    // The visible portion must extend beyond the system-obscured strip.
    expect(handle.right, greaterThan(64));
    await tester.tapAt(Offset(66, handle.center.dy));
    await pumpShell();
    expect(find.byTooltip('Скрыть меню'), findsOneWidget);

    await tester.tap(find.byTooltip('Скрыть меню'));
    await pumpShell();
    // Restoring via the edge swipe must also start inside the safe area.
    await tester.dragFrom(const Offset(82, 400), const Offset(80, 0));
    await pumpShell();
    expect(find.byTooltip('Скрыть меню'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell protects controls from system bars and display cutouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(
      left: 24,
      top: 32,
      right: 16,
      bottom: 48,
    );
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({
      'bar_ui_app_language': 'ru',
      'bar_ui_power_saving_mode': true,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
    );
    await tester.pumpAndSettle();

    final page = tester.getRect(find.byType(RawBarPage));
    final navigation = tester.getRect(find.byType(NeonBottomNavigation));
    expect(page.left, greaterThanOrEqualTo(24));
    expect(page.right, lessThanOrEqualTo(390 - 16));
    expect(
      tester.getTopLeft(find.text('Мой Бар')).dy,
      greaterThanOrEqualTo(32),
    );
    expect(navigation.left, greaterThanOrEqualTo(24));
    expect(navigation.right, lessThanOrEqualTo(390 - 16));
    expect(navigation.bottom, closeTo(844 - 48, 0.01));

    // Insets can change when switching navigation mode or rotating the phone.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(NeonBottomNavigation)).bottom,
      closeTo(844 - 24, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  for (final language in ['ru', 'en']) {
    testWidgets('developer website follows $language app language', (
      WidgetTester tester,
    ) async {
      final isEnglish = language == 'en';
      SharedPreferences.setMockInitialValues({
        'bar_ui_app_language': language,
        'bar_ui_power_saving_mode': true,
      });
      final preferences = await SharedPreferences.getInstance();
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });

      await tester.pumpWidget(
        await _buildApp(preferences: preferences, catalog: _testCatalog),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(isEnglish ? 'Bar management' : 'Управление баром'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(isEnglish ? 'About app' : 'О приложении'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.text(isEnglish ? 'Developer website' : 'Сайт разработчика'),
      );
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      expect(
        calls.single.arguments['url'],
        isEnglish ? 'https://logion-mobile.com' : 'https://logion-mobile.ru',
      );
      expect(calls.single.arguments['useSafariVC'], isFalse);
      expect(calls.single.arguments['useWebView'], isFalse);
    });
  }

  testWidgets('shows app shell with both tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'bar_ui_app_language': 'ru'});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
    );
    await tester.pump();

    expect(find.text('Мой Бар'), findsOneWidget);
    expect(find.text('Ингредиенты'), findsOneWidget);
    expect(find.text('Барная карта'), findsOneWidget);
    expect(find.text('можно сделать'), findsOneWidget);
    expect(find.byTooltip('Изменить ингредиент'), findsWidgets);
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

  testWidgets('shows almost-ready filters and smart shopping suggestions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_ingredients': <String>['gin'],
      'bar_ui_app_language': 'ru',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
    );
    await tester.pump();
    await tester.tap(find.text('Барная карта'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Не хватает 1 · 1'), findsOneWidget);
    expect(find.text('Не хватает 2 · 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Список покупок'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Умный список покупок'), findsOneWidget);
    expect(find.text('Вермут'), findsWidgets);
    expect(find.text('Откроет 1 коктейль'), findsOneWidget);

    expect(find.byTooltip('Добавить в список'), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить в список'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Очистить'));
    await tester.pump();
    expect(find.text('Очистить список?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
  });

  testWidgets('opens serving calculator, party mode and surprise cocktail', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_ingredients': <String>['gin', 'vermouth'],
      'bar_ui_app_language': 'ru',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      await _buildApp(preferences: preferences, catalog: _testCatalog),
    );
    await tester.pump();
    await tester.tap(find.text('Барная карта'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('1 порц.').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Калькулятор порций'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Вечеринка'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Режим вечеринки'), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Удиви меня'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final surprise = tester.widget<SurpriseCocktailPage>(
      find.byType(SurpriseCocktailPage),
    );
    expect(
      surprise.cocktails.map((cocktail) => cocktail.id),
      unorderedEquals(['martini', 'vodka-martini']),
    );
    expect(find.byTooltip('Увеличить'), findsOneWidget);
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
  final shoppingListStorage = SharedPreferencesShoppingListStorage(preferences);
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
    onboardingStorage: InMemoryOnboardingStorage(completed: true),
    selectionStorage: selectionStorage,
    settingsStorage: settingsStorage,
    shoppingListStorage: shoppingListStorage,
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
