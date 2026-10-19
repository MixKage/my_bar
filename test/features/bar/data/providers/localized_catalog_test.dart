import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source =
      jsonDecode(File('assets/data/bar_template.json').readAsStringSync())
          as Map<String, dynamic>;

  for (final locale in AppLanguageX.supportedLocales) {
    final code = locale.languageCode;
    test(
      'offline $code catalog keeps every recipe and its quantities',
      () async {
        final provider = LocalizedJsonAssetExternalBarDataProvider(
          defaultAssetPath: 'assets/data/bar_template.json',
          russianAssetPath: 'assets/data/bar_template_ru.json',
          useRussianCatalogResolver: () => code == 'ru',
          languageCodeResolver: () => code,
        );
        final ingredients = await provider.fetchIngredients();
        final cocktails = await provider.fetchCocktails();
        expect(
          ingredients.map((item) => item['id']),
          (source['ingredients'] as List).map((item) => item['id']),
        );
        expect(
          cocktails.map((item) => item['id']),
          (source['cocktails'] as List).map((item) => item['id']),
        );
        for (var i = 0; i < cocktails.length; i++) {
          final cocktail = cocktails[i];
          final original = source['cocktails'][i] as Map<String, dynamic>;
          expect(
            cocktail['name'],
            isNotEmpty,
            reason: '${cocktail['id']}: $code',
          );
          expect(cocktail['ingredients'], original['ingredients']);
          expect(cocktail['ingredientUnits'], original['ingredientUnits']);
          expect(
            (cocktail['preparationSteps'] as List).length,
            (original['preparationSteps'] as List).length,
            reason: '${cocktail['id']}: no steps lost in $code',
          );
          final amounts = original['ingredientAmounts'] as Map<String, dynamic>;
          for (final amount in amounts.entries) {
            if (!RegExp('[A-Za-z]').hasMatch(amount.value as String)) {
              expect(
                cocktail['ingredientAmounts'][amount.key],
                amount.value,
                reason: '${cocktail['id']}: numeric dose changed in $code',
              );
            }
          }
        }
        // Exercise the same strict codec used by import/export, not just JSON.
        const BarCatalogJsonCodec().decode(
          jsonEncode({'ingredients': ingredients, 'cocktails': cocktails}),
        );
      },
    );

    if (code == 'en' || code == 'ru') continue;
    test('$code translation overlay is complete and up to date', () {
      final overlay =
          jsonDecode(
                File(
                  'assets/data/catalog_localizations/$code.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        (overlay['ingredients'] as Map).keys,
        (source['ingredients'] as List).map((item) => item['id']),
      );
      expect(
        (overlay['cocktails'] as Map).keys,
        (source['cocktails'] as List).map((item) => item['id']),
      );
      expect(
        overlay['sourceTextChecksum'],
        _sourceChecksum(source),
        reason: 'Regenerate translations after editing the catalog',
      );
      for (final item in (overlay['cocktails'] as Map).values) {
        expect(item['description'], isNotEmpty);
        expect(item['preparationSteps'], everyElement(isNotEmpty));
      }
    });
  }

  test('switching language reuses the matching offline catalog', () async {
    var language = 'en';
    final provider = LocalizedJsonAssetExternalBarDataProvider(
      defaultAssetPath: 'assets/data/bar_template.json',
      russianAssetPath: 'assets/data/bar_template_ru.json',
      useRussianCatalogResolver: () => language == 'ru',
      languageCodeResolver: () => language,
    );
    final english = await provider.fetchIngredients();
    language = 'es';
    final spanish = await provider.fetchIngredients();
    language = 'en';
    final englishAgain = await provider.fetchIngredients();
    expect(englishAgain, english);
    expect(
      spanish.map((item) => item['id']),
      english.map((item) => item['id']),
    );
    expect(
      spanish.firstWhere((item) => item['id'] == 'vodka')['name'],
      isNotEmpty,
    );
    expect(
      spanish.any(
        (item) =>
            item['name'] !=
            english.firstWhere((e) => e['id'] == item['id'])['name'],
      ),
      isTrue,
    );
  });
}

String _sourceChecksum(Map<String, dynamic> catalog) {
  final texts = <String>{};
  for (final ingredient in catalog['ingredients'] as List) {
    texts.add(ingredient['name'] as String);
  }
  for (final cocktail in catalog['cocktails'] as List) {
    texts.addAll([
      cocktail['name'] as String,
      cocktail['description'] as String,
      ...(cocktail['preparationSteps'] as List).cast<String>(),
      ...(cocktail['ingredientAmounts'] as Map).values.cast<String>().where(
        (value) => RegExp('[A-Za-z]').hasMatch(value),
      ),
    ]);
  }
  texts.removeWhere((text) => text.trim().isEmpty);
  var checksum = 2166136261;
  for (final byte in utf8.encode(jsonEncode(texts.toList()))) {
    checksum = ((checksum ^ byte) * 16777619) & 0xffffffff;
  }
  return checksum.toRadixString(16).padLeft(8, '0');
}
