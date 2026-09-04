import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_bar/core/widgets/bar_pressable.dart';
import 'package:my_bar/features/bar/data/onboarding_storage.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';
import 'package:my_bar/features/bar/presentation/pages/bar_menu_page.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_details_page.dart';
import 'package:my_bar/features/bar/presentation/pages/onboarding_page.dart';
import 'package:my_bar/features/bar/presentation/pages/party_mode_page.dart';
import 'package:my_bar/features/bar/presentation/pages/raw_bar_page.dart';
import 'package:my_bar/features/bar/presentation/pages/surprise_cocktail_page.dart';

const _cocktails = <Cocktail>[
  Cocktail(
    id: 'first',
    name: 'Первый',
    image: '',
    ingredients: ['gin'],
    description: '',
    preparationSteps: ['Перемешать.'],
    glassType: 'Мартини',
    tags: ['IBA'],
  ),
  Cocktail(
    id: 'second',
    name: 'Второй',
    image: '',
    ingredients: ['gin'],
    description: '',
    preparationSteps: ['Охладить.'],
    glassType: 'Мартини',
    tags: ['IBA'],
  ),
];
const _ingredients = <String, Ingredient>{
  'gin': Ingredient(
    id: 'gin',
    name: 'Джин',
    category: 'Крепкий алкоголь',
    image: '',
  ),
};

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pump();
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
}

Future<void> _openPartyPlan(
  WidgetTester tester,
  Future<void> Function(Iterable<String>) onAdd,
) async {
  await _pump(
    tester,
    PartyModePage(
      cocktails: _cocktails,
      ingredientsById: _ingredients,
      missingIngredientIdsByCocktailId: const {
        'first': {'gin'},
        'second': {'gin'},
      },
      measurementSystem: MeasurementSystem.ml,
      powerSavingMode: true,
      readOnly: false,
      onAddShoppingIngredients: onAdd,
    ),
  );
  await tester.tap(find.byType(CheckboxListTile).at(0));
  await tester.pump();
  await tester.tap(find.byType(CheckboxListTile).at(1));
  await _frames(tester);
  await tester.tap(find.text('Рассчитать · 2 порций'));
  await _frames(tester);
  await tester.ensureVisible(find.text('Добавить недостающее в покупки · 1'));
}

void main() {
  for (final scenario in <({String filter, Set<String> expected})>[
    (filter: 'Все · 3', expected: {'recipe_0', 'recipe_1', 'recipe_2'}),
    (filter: 'Можно сейчас · 1', expected: {'recipe_0'}),
    (filter: 'Не хватает 1 · 1', expected: {'recipe_1'}),
    (filter: 'Не хватает 2 · 1', expected: {'recipe_2'}),
  ]) {
    testWidgets('surprise respects the menu filter: ${scenario.filter}', (
      tester,
    ) async {
      const ids = ['gin', 'vermouth', 'vodka'];
      await _pump(
        tester,
        Scaffold(
          body: BarMenuPage(
            cocktails: List<Cocktail>.generate(
              3,
              (index) => Cocktail(
                id: 'recipe_$index',
                name: 'Рецепт $index',
                image: '',
                ingredients: ids.take(index + 1).toList(),
                description: '',
                preparationSteps: const ['Перемешать.'],
                glassType: 'Мартини',
                tags: const ['IBA'],
              ),
            ),
            selectedIngredientIds: const {'gin'},
            shoppingIngredientIds: const {},
            ingredientsById: {
              for (final id in ids)
                id: Ingredient(
                  id: id,
                  name: id,
                  category: 'Крепкий алкоголь',
                  image: '',
                ),
            },
            unlockCountsByIngredientId: const {},
            favoriteUnlockCountsByIngredientId: const {},
            visitorMode: true,
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
        ),
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, scenario.filter),
        140,
        scrollable: find.descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        ),
      );
      await _frames(tester);
      await tester.tap(find.text(scenario.filter));
      await _frames(tester);
      await tester.tap(find.text('Удиви меня'));
      await _frames(tester);
      final surprise = tester.widget<SurpriseCocktailPage>(
        find.byType(SurpriseCocktailPage),
      );
      expect(
        surprise.cocktails.map((cocktail) => cocktail.id).toSet(),
        scenario.expected,
      );
      final initial = tester
          .widget<CocktailDetailsPage>(find.byType(CocktailDetailsPage))
          .cocktail
          .id;
      expect(scenario.expected, contains(initial));
      if (scenario.expected.length > 1) {
        await tester.tap(find.text('Следующий коктейль'));
        await _frames(tester);
        final next = tester
            .widget<CocktailDetailsPage>(find.byType(CocktailDetailsPage))
            .cocktail
            .id;
        expect(scenario.expected, contains(next));
        expect(next, isNot(initial));
      }
    });
  }

  testWidgets(
    'party shopping confirms only after completion and prevents double submission',
    (tester) async {
      final saved = Completer<void>();
      final shoppingIds = <String>{};
      var calls = 0;
      await _openPartyPlan(tester, (ids) async {
        calls++;
        await saved.future;
        shoppingIds.addAll(ids);
      });
      await tester.tap(find.text('Добавить недостающее в покупки · 1'));
      await tester.pump();
      expect(find.text('Добавляем…'), findsOneWidget);
      expect(find.text('Добавлено в покупки · 1'), findsNothing);
      expect(
        tester
            .widget<BarActionButton>(
              find.widgetWithText(BarActionButton, 'Добавляем…'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Добавляем…'));
      expect(calls, 1);
      saved.complete();
      await _frames(tester);
      expect(shoppingIds, {'gin'});
      expect(find.text('Добавлено в покупки · 1'), findsOneWidget);
      expect(find.textContaining('теперь в разделе «Покупки»'), findsOneWidget);
      expect(find.text('Добавить недостающее в покупки · 1'), findsNothing);
      await _frames(tester);
      expect(find.text('Добавлено в покупки · 1'), findsOneWidget);
    },
  );

  testWidgets('party shopping failure is visible and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _openPartyPlan(tester, (_) async {
      if (++calls == 1) throw StateError('Storage unavailable');
    });
    await tester.tap(find.text('Добавить недостающее в покупки · 1'));
    await _frames(tester);
    expect(
      find.text('Не удалось добавить ингредиенты. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Добавлено в покупки · 1'), findsNothing);
    await tester.ensureVisible(find.text('Повторить добавление'));
    await tester.tap(find.text('Повторить добавление'));
    await _frames(tester);
    expect(calls, 2);
    expect(find.text('Добавлено в покупки · 1'), findsOneWidget);
    expect(find.text('Повторить добавление'), findsNothing);
  });

  testWidgets('party shopping completion is safe after closing the sheet', (
    tester,
  ) async {
    final saved = Completer<void>();
    await _openPartyPlan(tester, (_) => saved.future);
    await tester.tap(find.text('Добавить недостающее в покупки · 1'));
    await tester.pump();
    await tester.tap(find.byTooltip('Закрыть'));
    await _frames(tester);
    saved.complete();
    await _frames(tester);
    expect(find.text('План вечеринки'), findsNothing);
  });

  for (final powerSaving in [false, true]) {
    testWidgets(
      'party selection can toggle during layout animation (power=$powerSaving)',
      (tester) async {
        await _pump(
          tester,
          PartyModePage(
            cocktails: _cocktails,
            ingredientsById: _ingredients,
            missingIngredientIdsByCocktailId: const {
              'first': {},
              'second': {'gin'},
            },
            measurementSystem: MeasurementSystem.ml,
            powerSavingMode: powerSaving,
            readOnly: false,
            onAddShoppingIngredients: (_) async {},
          ),
        );
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.byType(CheckboxListTile).first);
        await _frames(tester);
        await tester.tap(find.text('Только доступные'));
        await _frames(tester);
        final chip = tester.widget<FilterChip>(find.byType(FilterChip));
        expect(chip.selected, isTrue);
        expect(chip.checkmarkColor, Colors.white);
        expect((chip.avatar! as Icon).color, Colors.white);
        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
      },
    );
  }

  testWidgets('sort sheet scrolls on a short screen with larger text', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: RawBarPage(
          ingredients: const [],
          cocktails: const [],
          selectedIngredientIds: const {},
          allowSelection: true,
          powerSavingMode: true,
          bottomOverlayPadding: 0,
          onToggleIngredient: (_) {},
          onEditIngredient: (_) async {},
          onManagePressed: () {},
        ),
      ),
      size: const Size(320, 568),
      textScale: 1.3,
    );
    await tester.tap(find.byTooltip('Фильтры'));
    await _frames(tester);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.activeThumbColor, const Color(0xFF8FA3FF));
    await tester.tap(find.text('Только то, что есть'));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -450),
    );
    await _frames(tester);
    expect(find.widgetWithText(BarActionButton, 'Применить'), findsOneWidget);
    await tester.tap(find.text('Применить'));
    await _frames(tester);
    expect(find.text('Только в наличии'), findsOneWidget);
  });

  testWidgets('menu only has quick actions; filters retain white selection', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: BarMenuPage(
          cocktails: _cocktails,
          selectedIngredientIds: const {},
          shoppingIngredientIds: const {},
          ingredientsById: _ingredients,
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
      ),
    );
    expect(find.textContaining('Бар готов'), findsNothing);
    expect(find.text('0/2'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(-900, 0));
    await _frames(tester);
    await tester.tap(find.text('Ещё фильтры'));
    await _frames(tester);
    await tester.tap(find.text('Только избранные'));
    await tester.tap(find.text('IBA').last);
    await _frames(tester);
    final favorite = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Только избранные'),
    );
    expect(favorite.selected, isTrue);
    expect((favorite.avatar! as Icon).color, Colors.white);
    final iba = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'IBA').last,
    );
    expect(iba.selected, isTrue);
    expect(iba.checkmarkColor, Colors.white);
  });

  testWidgets('surprise switches without repeat and remembers favorites', (
    tester,
  ) async {
    final favorites = <String>[];
    await _pump(
      tester,
      SurpriseCocktailPage(
        cocktails: _cocktails,
        initialCocktailId: 'first',
        missingIngredientsByCocktailId: const {},
        ingredientsById: _ingredients,
        visitorMode: true,
        measurementSystem: MeasurementSystem.ml,
        powerSavingMode: false,
        onEditCocktailPressed: (_) async {},
        onToggleFavoritePressed: favorites.add,
      ),
    );
    await tester.tap(find.byTooltip('В избранное'));
    await tester.tap(find.text('Следующий коктейль'));
    await _frames(tester);
    expect(
      tester
          .widget<CocktailDetailsPage>(find.byType(CocktailDetailsPage))
          .cocktail
          .id,
      'second',
    );
    await tester.tap(find.text('Следующий коктейль'));
    await _frames(tester);
    expect(
      tester
          .widget<CocktailDetailsPage>(find.byType(CocktailDetailsPage))
          .cocktail
          .id,
      'first',
    );
    expect(find.byTooltip('Убрать из избранного'), findsOneWidget);
    expect(favorites, ['first']);
  });

  testWidgets(
    'onboarding completes once, persists across recreation and settings writes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = SharedPreferencesOnboardingStorage(preferences);
      await _pump(
        tester,
        OnboardingGate(
          storage: storage,
          child: const Scaffold(body: Text('home')),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      );
      expect(find.text('Ваш домашний бар'), findsOneWidget);
      expect(find.textContaining('раздел «Ингредиенты»'), findsOneWidget);
      expect(find.textContaining('Фильтр «Можно сейчас»'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Далее'));
        await _frames(tester);
      }
      await tester.tap(find.text('Начать'));
      await _frames(tester);
      expect(storage.isCompleted, isTrue);
      await SharedPreferencesBarUiSettingsStorage(
        preferences,
      ).writeSettings(const BarUiSettings(powerSavingMode: true));
      expect(storage.isCompleted, isTrue);
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(
        tester,
        OnboardingGate(
          storage: SharedPreferencesOnboardingStorage(preferences),
          child: const Scaffold(body: Text('home')),
        ),
      );
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
    },
  );

  testWidgets('skipping onboarding persists completion too', (tester) async {
    final storage = InMemoryOnboardingStorage();
    await _pump(
      tester,
      OnboardingGate(
        storage: storage,
        child: const Scaffold(body: Text('home')),
      ),
    );
    await tester.tap(find.text('Пропустить'));
    await _frames(tester);
    expect(storage.isCompleted, isTrue);
    expect(find.text('home'), findsOneWidget);
  });
}
