import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/core/localization/app_localization.dart';
import 'package:my_bar/core/localization/app_translations.dart';
import 'package:my_bar/features/bar/presentation/widgets/language_selector.dart';

void main() {
  test('Arabic home-bar labels preserve their recipe context', () {
    expect(translateAppText('ar', 'My Bar'), 'باري');
    expect(translateAppText('ar', 'in stock'), 'متوفر');
    expect(translateAppText('ar', 'ready to make'), 'جاهز للتحضير');
  });

  testWidgets('IBA remains the same catalog mark in every language', (
    tester,
  ) async {
    for (final locale in AppLanguageX.supportedLocales) {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLanguageX.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(capturedContext.cocktailTagLabel('IBA'), 'IBA', reason: '$locale');
    }
  });

  testWidgets('ingredient category is localized in english locale', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: AppLanguageX.supportedLocales,
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
        supportedLocales: AppLanguageX.supportedLocales,
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

  test('all bundled languages survive storage and regional variants', () {
    for (final language in AppLanguage.values) {
      expect(AppLanguageX.fromStorage(language.storageValue), language);
    }
    expect(AppLanguageX.fromStorage('pt-BR'), AppLanguage.portuguese);
    expect(AppLanguageX.fromStorage('zh_CN'), AppLanguage.chinese);
    expect(AppLanguageX.fromStorage('unknown'), AppLanguage.system);
    expect(
      AppLanguageX.resolveLocale([const Locale('uk')]),
      const Locale('en'),
    );
    expect(
      AppLanguageX.resolveLocale([const Locale('pt', 'BR')]),
      const Locale('pt'),
    );
    expect(
      AppLanguageX.resolveLocale([const Locale('ar', 'EG')]),
      const Locale('ar'),
    );
    expect(
      AppLanguageX.resolveLocale([const Locale('uk'), const Locale('es')]),
      const Locale('es'),
    );
  });

  test(
    'every language has complete offline UI strings and valid placeholders',
    () {
      final keys = appTranslations.values.first.keys.toSet();
      final placeholder = RegExp(r'\{\d+\}');
      List<String> tokens(String text) =>
          placeholder.allMatches(text).map((m) => m.group(0)!).toList()..sort();
      expect(appTranslations.length, 11);
      for (final dictionary in appTranslations.entries) {
        expect(dictionary.value.keys.toSet(), keys, reason: dictionary.key);
        for (final entry in dictionary.value.entries) {
          expect(
            entry.value.trim(),
            isNotEmpty,
            reason: '${dictionary.key}: ${entry.key}',
          );
          expect(
            tokens(entry.value),
            tokens(entry.key),
            reason: '${dictionary.key}: ${entry.key}',
          );
        }
        final servings = translateAppText(dictionary.key, 'Servings: 42');
        expect(servings, contains('42'));
        expect(servings, isNot(contains('{0}')));
        final missing = translateAppText(
          dictionary.key,
          'Missing: Lime, Gin and 7 more',
        );
        expect(missing, contains('Lime, Gin'));
        expect(missing, contains('7'));
        expect(missing, isNot(contains('{')));
        expect(
          translateAppText(dictionary.key, 'Ingredients'),
          isNot('Ingredients'),
        );
      }
      expect(translateAppText('unsupported', 'Ingredients'), 'Ingredients');
      expect(
        translateAppText('es', 'Custom user text 🥂'),
        'Custom user text 🥂',
      );
    },
  );

  testWidgets(
    'selector searches native names and returns the chosen language',
    (tester) async {
      AppLanguage? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLanguageX.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showLanguageSelector(
                  context,
                  selected: AppLanguage.spanish,
                  powerSavingMode: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '日本');
      await tester.pump();
      expect(find.text('日本語'), findsOneWidget);
      expect(find.text('Español'), findsNothing);
      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();
      expect(result, AppLanguage.japanese);
    },
  );

  testWidgets('Arabic selector supports RTL, a small screen and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(splashFactory: NoSplash.splashFactory),
        locale: const Locale('ar'),
        supportedLocales: AppLanguageX.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLanguageSelector(
                context,
                selected: AppLanguage.arabic,
                powerSavingMode: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.rtl,
    );
    await tester.enterText(find.byType(TextField), 'العربية');
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'العربية',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'nothing-matches');
    await tester.pump();
    expect(
      find.text(translateAppText('ar', 'No languages found')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'semantic labels and missing ingredients use the selected locale',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          locale: const Locale('fr'),
          supportedLocales: AppLanguageX.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Column(
              children: [
                Text(context.ingredientCategoryLabel('Крепкий алкоголь')),
                Text(context.cocktailTagLabel('Безалкогольные')),
                Text(context.tr('Не хватает: лайм', 'Missing: Lime')),
                Text(
                  context.localizeErrorMessage(
                    'Коктейль "Negroni" содержит неизвестный тег "xyz".',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(translateAppText('fr', 'Spirits')), findsOneWidget);
      expect(
        find.text(translateAppText('fr', 'Non-alcoholic')),
        findsOneWidget,
      );
      expect(
        find.text(translateAppText('fr', 'Missing: Lime')),
        findsOneWidget,
      );
      expect(
        find.text(
          translateAppText(
            'fr',
            'Cocktail "Negroni" contains an unknown tag "xyz".',
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
