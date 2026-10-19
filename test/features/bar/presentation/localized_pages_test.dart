import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';
import 'package:my_bar/features/bar/presentation/pages/bar_menu_page.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_details_page.dart';
import 'package:my_bar/features/bar/presentation/pages/party_mode_page.dart';

void main() {
  for (final locale in AppLanguageX.supportedLocales) {
    testWidgets('${locale.languageCode} recipe, menu and party fit a phone', (
      tester,
    ) async {
      final originalErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.library == 'rendering library' &&
            details.exceptionAsString().contains('overflowed')) {
          debugPrint(details.toString());
        }
        originalErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalErrorHandler);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = LocalizedJsonAssetExternalBarDataProvider(
        defaultAssetPath: 'assets/data/bar_template.json',
        russianAssetPath: 'assets/data/bar_template_ru.json',
        useRussianCatalogResolver: () => locale.languageCode == 'ru',
        languageCodeResolver: () => locale.languageCode,
      );
      final payload = (await tester.runAsync(provider.fetchCatalogSnapshot))!;
      final ingredients = {
        for (final item in payload.ingredients)
          item['id'] as String: Ingredient.fromJson(item),
      };
      final recipes = payload.cocktails
          .take(3)
          .map(Cocktail.fromJson)
          .toList(growable: false);
      final longAmountRecipe = Cocktail.fromJson(
        payload.cocktails.firstWhere((recipe) => recipe['id'] == 'cuba-libra'),
      );
      final pages = [
        BarMenuPage(
          cocktails: [longAmountRecipe, ...recipes],
          selectedIngredientIds: const {},
          shoppingIngredientIds: const {},
          ingredientsById: ingredients,
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
        ),
        for (final recipe in [recipes.first, longAmountRecipe])
          CocktailDetailsPage(
            cocktail: recipe,
            missingIngredientNames: const [],
            ingredientsById: ingredients,
            visitorMode: false,
            measurementSystem: MeasurementSystem.ml,
            powerSavingMode: true,
            onEditCocktailPressed: (_) async {},
            onToggleFavoritePressed: (_) {},
          ),
        PartyModePage(
          cocktails: recipes,
          ingredientsById: ingredients,
          missingIngredientIdsByCocktailId: const {},
          measurementSystem: MeasurementSystem.ml,
          powerSavingMode: true,
          readOnly: false,
          onAddShoppingIngredients: (_) async {},
        ),
      ];
      for (final page in pages) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            locale: locale,
            supportedLocales: AppLanguageX.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.35),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(body: page),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester.takeException(),
          isNull,
          reason: '${locale.languageCode}: ${page.runtimeType}',
        );
      }
    });
  }
}
