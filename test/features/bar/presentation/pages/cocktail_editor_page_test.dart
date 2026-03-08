import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_editor_page.dart';

const ingredients = <Ingredient>[
  Ingredient(id: 'gin', name: 'Джин', category: 'Крепкий алкоголь', image: ''),
  Ingredient(id: 'vermouth', name: 'Вермут', category: 'Аперитивы', image: ''),
];

const editingCocktail = Cocktail(
  id: 'martini',
  name: 'Мартини',
  image: '',
  ingredients: <String>['gin', 'vermouth'],
  description: 'Джин, сухой вермут',
  preparationSteps: <String>[
    'Охладите бокал.',
    'Смешайте ингредиенты и подавайте.',
  ],
  glassType: 'Мартини',
  tags: <String>['Крепкие'],
);

void main() {
  testWidgets('asks confirmation before leaving unsaved editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        supportedLocales: <Locale>[Locale('ru'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _TestHost(ingredients: ingredients),
      ),
    );

    await tester.tap(find.text('open-editor'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Новый коктейль');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Выйти без сохранения?'), findsOneWidget);

    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();

    expect(find.text('Создание коктейля'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    expect(find.text('open-editor'), findsOneWidget);
  });

  testWidgets('leaves editor immediately when no changes were made', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        supportedLocales: <Locale>[Locale('ru'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _TestHost(ingredients: ingredients),
      ),
    );

    await tester.tap(find.text('open-editor'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Выйти без сохранения?'), findsNothing);
    expect(find.text('open-editor'), findsOneWidget);
  });

  testWidgets('renders editor body on mobile layout', (tester) async {
    await _pumpEditor(
      tester,
      size: const Size(390, 844),
      home: const CocktailEditorPage.create(ingredients: ingredients),
    );

    expect(find.text('Название*'), findsOneWidget);
    expect(find.text('Шаги приготовления*'), findsOneWidget);
    expect(find.text('Ингредиенты*'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
  });

  testWidgets('renders editor body on desktop layout', (tester) async {
    await _pumpEditor(
      tester,
      size: const Size(1440, 900),
      home: const CocktailEditorPage.create(ingredients: ingredients),
    );

    expect(find.text('Название*'), findsOneWidget);
    expect(find.text('Шаги приготовления*'), findsOneWidget);
    expect(find.text('Ингредиенты*'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
  });

  testWidgets('renders editor body in edit mode on mobile layout', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      size: const Size(390, 844),
      home: const CocktailEditorPage.edit(
        ingredients: ingredients,
        initialCocktail: editingCocktail,
      ),
    );

    expect(find.text('Редактирование коктейля'), findsOneWidget);
    expect(find.text('Название*'), findsOneWidget);
    expect(find.text('Параметры ингредиентов'), findsOneWidget);
  });

  testWidgets('renders editor body in edit mode on desktop layout', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      size: const Size(1440, 900),
      home: const CocktailEditorPage.edit(
        ingredients: ingredients,
        initialCocktail: editingCocktail,
      ),
    );

    expect(find.text('Редактирование коктейля'), findsOneWidget);
    expect(find.text('Название*'), findsOneWidget);
    expect(find.text('Параметры ингредиентов'), findsOneWidget);
  });

  testWidgets('shows validation snackbar when required fields are empty', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      size: const Size(390, 844),
      home: const CocktailEditorPage.create(ingredients: ingredients),
    );

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Укажите название коктейля'), findsOneWidget);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required Size size,
  required Widget home,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.ingredients});

  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    CocktailEditorPage.create(ingredients: ingredients),
              ),
            );
          },
          child: const Text('open-editor'),
        ),
      ),
    );
  }
}
