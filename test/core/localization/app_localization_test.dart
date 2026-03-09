import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_localization.dart';

void main() {
  testWidgets('ingredient category is localized in english locale', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      capturedContext.ingredientCategoryLabel('Крепкий алкоголь'),
      'Spirits',
    );
    expect(
      capturedContext.ingredientCategoryLabel('Ликёры и аперитивы'),
      'Liqueurs and aperitifs',
    );
  });

  testWidgets('ingredient category is localized in russian locale', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      capturedContext.ingredientCategoryLabel('Spirits'),
      'Крепкий алкоголь',
    );
  });
}
