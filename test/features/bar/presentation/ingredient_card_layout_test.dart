import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/presentation/pages/raw_bar_page.dart';

void main() {
  for (final locale in AppLanguageX.supportedLocales) {
    testWidgets('${locale.languageCode} ingredient card grows for large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      var selectionCount = 0;
      var editCount = 0;
      const cardKey = ValueKey('ingredient-card');
      final name = switch (locale.languageCode) {
        'ar' => 'مكونات ومشروبات منزلية طويلة الاسم',
        'hi' => 'घर पर उपलब्ध लंबा नाम वाली सामग्री',
        'zh' => '用于制作家庭鸡尾酒的长名称原料',
        'ja' => '自宅でカクテルを作るための材料',
        'ko' => '집에서 칵테일을 만들기 위한 재료',
        'ru' => 'Ингредиент с очень длинным названием',
        _ => 'A home bar ingredient with a very long name',
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          locale: locale,
          supportedLocales: AppLanguageX.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                IngredientCard(
                  key: cardKey,
                  ingredient: Ingredient(
                    id: 'fixture',
                    name: name,
                    category: 'Газировка и безалкогольные миксеры',
                    image: '',
                    isDecoration: true,
                    isOptional: true,
                  ),
                  cocktails: const [],
                  selected: true,
                  allowSelection: true,
                  powerSavingMode: true,
                  onTap: () => selectionCount++,
                  onLongPress: () {},
                  onEdit: () => editCount++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(cardKey));
      expect(card.height, greaterThan(116));
      final title = tester.getRect(find.text(name));
      expect(title.top, greaterThanOrEqualTo(card.top + 12));
      expect(title.bottom, lessThan(card.bottom));
      expect(tester.widget<Text>(find.text(name)).maxLines, isNull);
      final edit = find.byIcon(Icons.edit_outlined);
      expect(
        tester.getRect(edit).center.dy,
        inInclusiveRange(card.top, card.bottom),
      );
      await tester.tap(edit);
      await tester.pump();
      expect(editCount, 1);
      expect(selectionCount, 0);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      expect(selectionCount, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact ingredient card retains its existing baseline height', (
    tester,
  ) async {
    const cardKey = ValueKey('compact-card');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              IngredientCard(
                key: cardKey,
                ingredient: const Ingredient(
                  id: 'gin',
                  name: 'Gin',
                  category: 'Spirits',
                  image: '',
                ),
                cocktails: const [],
                selected: false,
                allowSelection: true,
                powerSavingMode: true,
                onTap: () {},
                onLongPress: () {},
                onEdit: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    // The original 116 px content plus the unchanged 1.7 px border on each edge.
    expect(tester.getSize(find.byKey(cardKey)).height, closeTo(119.4, 0.01));
    expect(tester.takeException(), isNull);
  });
}
