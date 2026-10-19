import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_details_page.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_editor_page.dart';

void main() {
  testWidgets('short landscape keeps the form above IME and restores actions', (
    tester,
  ) async {
    const editor = CocktailEditorPage.create(
      ingredients: [],
      powerSavingMode: true,
    );
    await _pump(
      tester,
      editor,
      size: const Size(844, 390),
      padding: const EdgeInsets.fromLTRB(44, 24, 0, 0),
      keyboardHeight: 220,
    );
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    expect(save, findsNothing);
    final form = find.byType(SingleChildScrollView).first;
    expect(tester.getRect(form).bottom, lessThanOrEqualTo(390 - 220));

    final name = find.byType(TextField).first;
    await tester.enterText(name, 'Landscape draft');
    await tester.pumpAndSettle();
    final photo = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          (widget.decoration?.hintText?.startsWith('https://') ?? false),
    );
    await tester.scrollUntilVisible(
      photo,
      60,
      scrollable: find
          .descendant(of: form, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(photo).bottom, lessThanOrEqualTo(390 - 220));

    await _pump(
      tester,
      editor,
      size: const Size(844, 390),
      padding: const EdgeInsets.fromLTRB(44, 24, 0, 24),
    );
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(390 - 24));
    expect(tester.getRect(save).top, greaterThanOrEqualTo(24 + 76));
    expect(tester.widget<TextField>(name).controller!.text, 'Landscape draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipe controls stay outside landscape cutouts and status bar', (
    tester,
  ) async {
    await _pump(
      tester,
      CocktailDetailsPage(
        cocktail: const Cocktail(
          id: 'test',
          name: 'Тестовый коктейль',
          image: '',
          ingredients: [],
          description: '',
          preparationSteps: ['Перемешать.'],
          glassType: 'Мартини',
          tags: [],
        ),
        missingIngredientNames: const [],
        ingredientsById: const {},
        visitorMode: true,
        measurementSystem: MeasurementSystem.ml,
        powerSavingMode: true,
        onEditCocktailPressed: (_) async {},
        onToggleFavoritePressed: (_) {},
      ),
      padding: const EdgeInsets.fromLTRB(44, 32, 20, 48),
    );
    final backButton = tester.getRect(find.byTooltip('Назад'));
    final favoriteButton = tester.getRect(find.byTooltip('В избранное'));
    expect(backButton.left, greaterThanOrEqualTo(44));
    expect(backButton.top, greaterThanOrEqualTo(32));
    expect(favoriteButton.right, lessThanOrEqualTo(390 - 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor actions clear system navigation and the full keyboard', (
    tester,
  ) async {
    const editor = CocktailEditorPage.create(
      ingredients: [],
      powerSavingMode: true,
    );
    await _pump(
      tester,
      editor,
      padding: const EdgeInsets.fromLTRB(28, 32, 20, 48),
    );
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    final cancel = find.widgetWithText(OutlinedButton, 'Отмена');
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(844 - 48));
    expect(tester.getRect(save).right, lessThanOrEqualTo(390 - 20));
    expect(tester.getRect(cancel).left, greaterThanOrEqualTo(28));

    // An IME taller than 35% of the screen must not cover the action bar.
    await _pump(
      tester,
      editor,
      padding: const EdgeInsets.fromLTRB(28, 32, 20, 0),
      keyboardHeight: 360,
    );
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(844 - 360));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required EdgeInsets padding,
  Size size = const Size(390, 844),
  double keyboardHeight = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: padding,
          viewPadding: padding,
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
