import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_editor_page.dart';

void main() {
  const ingredients = <Ingredient>[
    Ingredient(
      id: 'gin',
      name: 'Джин',
      category: 'Крепкий алкоголь',
      image: '',
    ),
  ];

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
