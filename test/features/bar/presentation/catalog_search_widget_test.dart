import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';
import 'package:my_bar/features/bar/presentation/pages/bar_menu_page.dart';
import 'package:my_bar/features/bar/presentation/pages/party_mode_page.dart';
import 'package:my_bar/features/bar/presentation/pages/raw_bar_page.dart';

void main() {
  testWidgets('Russian ingredient search finds a typo and English alias', (
    tester,
  ) async {
    const locale = Locale('ru');
    final catalog = await _loadCatalog(tester, locale);
    _phoneViewport(tester);
    await _pumpPage(
      tester,
      locale,
      _ingredientsPage([
        catalog.ingredients['orange']!,
        catalog.ingredients['juice_orange']!,
        catalog.ingredients['juice_apple']!,
      ]),
    );
    expect(_ingredient('orange'), findsOneWidget);
    expect(find.text('Апельсин'), findsOneWidget);
    expect(_ingredient('juice_apple'), findsOneWidget);

    for (final query in ['апелсин', 'orange']) {
      await _search(tester, query);
      expect(_ingredient('orange'), findsOneWidget, reason: query);
      expect(_ingredient('juice_apple'), findsNothing, reason: query);
    }
    await _search(tester, 'апельсиновый сок');
    expect(_ingredient('juice_orange'), findsOneWidget);
    expect(_ingredient('juice_apple'), findsNothing);

    await _search(tester, 'несуществующийингредиент');
    expect(find.byType(IngredientCard), findsNothing);
    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('cocktail and party searches keep the Old Fashioned aliases', (
    tester,
  ) async {
    const locale = Locale('ru');
    final catalog = await _loadCatalog(tester, locale);
    final cocktails = [
      catalog.cocktails['old-fashioned']!,
      catalog.cocktails['alexander']!,
    ];
    _phoneViewport(tester);
    await _pumpPage(tester, locale, _cocktailsPage(cocktails, catalog));
    expect(_cocktail('alexander'), findsOneWidget);
    for (final query in ['Старомодный', 'олд фэшн', 'old fasioned']) {
      await _search(tester, query);
      expect(_cocktail('old-fashioned'), findsOneWidget, reason: query);
      expect(_cocktail('alexander'), findsNothing, reason: query);
    }

    await _pumpPage(
      tester,
      locale,
      PartyModePage(
        cocktails: cocktails,
        ingredientsById: catalog.ingredients,
        missingIngredientIdsByCocktailId: const {},
        measurementSystem: MeasurementSystem.ml,
        powerSavingMode: true,
        readOnly: false,
        onAddShoppingIngredients: (_) async {},
      ),
    );
    const oldFashionedTile = ValueKey<String>('old-fashioned');
    const alexanderTile = ValueKey<String>('alexander');
    expect(find.byKey(alexanderTile), findsOneWidget);
    await _search(tester, 'старомодный');
    expect(find.byKey(oldFashionedTile), findsOneWidget);
    expect(find.byKey(alexanderTile), findsNothing);
  });

  for (final locale in AppLanguageX.supportedLocales) {
    final code = locale.languageCode;
    testWidgets('$code searches displayed ingredient and cocktail names', (
      tester,
    ) async {
      final catalog = await _loadCatalog(tester, locale);
      _phoneViewport(tester);
      final fruit = catalog.ingredients['orange']!;
      await _pumpPage(
        tester,
        locale,
        _ingredientsPage([fruit, catalog.ingredients['coffee']!]),
      );
      expect(_ingredient('coffee'), findsOneWidget);
      await _search(tester, fruit.name);
      expect(_ingredient('orange'), findsOneWidget);
      expect(_ingredient('coffee'), findsNothing);

      // Hindi uses the common English Mojito label. Test a Devanagari title
      // there so the old ASCII-only matcher cannot accidentally pass.
      final drinkId = code == 'hi' ? 'masala-chai' : 'mojito';
      final drink = catalog.cocktails[drinkId]!;
      await _pumpPage(
        tester,
        locale,
        _cocktailsPage([drink, catalog.cocktails['alexander']!], catalog),
      );
      expect(_cocktail('alexander'), findsOneWidget);
      await _search(tester, drink.name);
      expect(_cocktail(drinkId), findsOneWidget);
      expect(_cocktail('alexander'), findsNothing);
    });
  }
}

typedef _Catalog = ({
  Map<String, Ingredient> ingredients,
  Map<String, Cocktail> cocktails,
});

Future<_Catalog> _loadCatalog(WidgetTester tester, Locale locale) async {
  final provider = LocalizedJsonAssetExternalBarDataProvider(
    defaultAssetPath: 'assets/data/bar_template.json',
    russianAssetPath: 'assets/data/bar_template_ru.json',
    useRussianCatalogResolver: () => locale.languageCode == 'ru',
    languageCodeResolver: () => locale.languageCode,
  );
  final payload = (await tester.runAsync(provider.fetchCatalogSnapshot))!;
  return (
    ingredients: {
      for (final raw in payload.ingredients)
        raw['id'] as String: Ingredient.fromJson(raw),
    },
    cocktails: {
      for (final raw in payload.cocktails)
        raw['id'] as String: Cocktail.fromJson(raw),
    },
  );
}

void _phoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 920);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, Locale locale, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      locale: locale,
      supportedLocales: AppLanguageX.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(body: page),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  expect(tester.takeException(), isNull);
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(tester.takeException(), isNull);
}

Finder _ingredient(String id) => find.byWidgetPredicate(
  (widget) => widget is IngredientCard && widget.ingredient.id == id,
);

Finder _cocktail(String id) =>
    find.byKey(ValueKey<String>('cocktail_list_item_$id'));

RawBarPage _ingredientsPage(List<Ingredient> ingredients) => RawBarPage(
  ingredients: ingredients,
  cocktails: const [],
  selectedIngredientIds: const {},
  allowSelection: true,
  powerSavingMode: true,
  bottomOverlayPadding: 0,
  onToggleIngredient: (_) {},
  onEditIngredient: (_) async {},
  onManagePressed: () {},
);

BarMenuPage _cocktailsPage(List<Cocktail> cocktails, _Catalog catalog) =>
    BarMenuPage(
      cocktails: cocktails,
      selectedIngredientIds: const {},
      shoppingIngredientIds: const {},
      ingredientsById: catalog.ingredients,
      unlockCountsByIngredientId: const {},
      favoriteUnlockCountsByIngredientId: const {},
      visitorMode: false,
      measurementSystem: MeasurementSystem.ml,
      powerSavingMode: true,
      bottomOverlayPadding: 0,
      onManagePressed: () {},
      onEditCocktailPressed: (_) async {},
      onToggleFavoritePressed: (_) {},
      onToggleShoppingIngredient: (_) async {},
      onClearShoppingList: () async {},
      onAddShoppingIngredients: (_) async {},
      onMarkShoppingIngredientAsOwned: (_) async {},
    );
