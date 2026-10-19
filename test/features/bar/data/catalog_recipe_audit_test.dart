import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient_units.dart';

void main() {
  final catalogs = <String, Map<String, dynamic>>{
    for (final language in ['en', 'ru'])
      language:
          jsonDecode(
                File(
                  'assets/data/bar_template${language == 'en' ? '' : '_ru'}.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
  };

  for (final entry in catalogs.entries) {
    final language = entry.key;
    final raw = entry.value;
    final ingredients = (raw['ingredients'] as List)
        .cast<Map<String, dynamic>>();
    final recipes = (raw['cocktails'] as List)
        .map((json) => Cocktail.fromJson(json as Map<String, dynamic>))
        .toList();
    final byId = {for (final recipe in recipes) recipe.id: recipe};

    test('$language: every bundled recipe has complete usable measures', () {
      final ingredientIds = ingredients.map((json) => json['id']).toSet();
      expect(ingredientIds, hasLength(ingredients.length));
      expect(byId, hasLength(recipes.length));
      expect(recipes.length, greaterThanOrEqualTo(384));
      for (final recipe in recipes) {
        expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
        expect(recipe.preparationSteps, isNotEmpty, reason: recipe.id);
        for (final id in recipe.ingredients) {
          final label = '${recipe.id}/$id';
          expect(ingredientIds, contains(id), reason: label);
          final amount = recipe.ingredientAmounts[id]?.trim();
          expect(amount, isNotEmpty, reason: label);
          final unit = recipe.ingredientUnits[id] ?? '';
          expect(kSupportedIngredientUnitsSet, contains(unit), reason: label);
          final range = parseIngredientNumericRange(amount!);
          if (range != null) {
            expect(unit, isNotEmpty, reason: label);
            expect(range.start, greaterThan(0), reason: label);
            if (range.end != null) {
              expect(
                range.end!,
                greaterThanOrEqualTo(range.start),
                reason: label,
              );
            }
          }
        }
        for (final map in [recipe.ingredientAmounts, recipe.ingredientUnits]) {
          expect(recipe.ingredients, containsAll(map.keys), reason: recipe.id);
        }
        expect(
          recipe.ingredients,
          containsAll({
            ...recipe.optionalIngredients,
            ...recipe.decorationIngredients,
          }),
          reason: recipe.id,
        );
      }
    });

    test('$language: corrected classics retain their defining ingredients', () {
      final required = <String, List<String>>{
        'americano': ['soda_water'],
        'aviation': ['creme_de_violette'],
        'bellini': ['peach_puree', 'prosecco'],
        'espresso-martini': ['espresso'],
        'moscow-mule': ['ginger_beer'],
        'paloma': ['grapefruit_soda'],
        'penicillin': ['ginger'],
        'old-cuban': ['mint'],
        'pina-colada': ['juice_pineapple', 'cream_of_coconut'],
        'ramos-gin-fizz': ['lime', 'orange_flower_water'],
        'russian-spring-punch': ['prosecco'],
        'zombie': ['falernum', 'juice_grapefruit', 'cinnamon_syrup'],
      };
      for (final entry in required.entries) {
        expect(byId[entry.key]!.ingredients, containsAll(entry.value));
      }
      expect(byId['bellini']!.ingredients, isNot(contains('peach_schnapps')));
      expect(byId['moscow-mule']!.ingredients, isNot(contains('ginger_ale')));
      expect(byId['paloma']!.ingredients, isNot(contains('grape_soda')));
      expect(
        byId['penicillin']!.ingredients,
        isNot(contains('syrup_gingerbread')),
      );
    });

    test(
      '$language: decimal and batch quantities do not lose a factor of ten',
      () {
        final spice = byId['spice-75']!;
        expect(spice.ingredientAmounts['sugar'], '60');
        expect(spice.ingredientUnits['sugar'], 'g');
        expect(spice.ingredientAmounts['champagne'], '600');
        expect(spice.ingredientUnits['champagne'], 'мл');
        final toddy = byId['hot-toddy']!;
        expect(toddy.ingredientAmounts['water'], '400');
        final zizi = byId['zizi-coin-coin']!;
        expect(zizi.ingredientAmounts['cointreau'], '5');
        expect(zizi.ingredientUnits['cointreau'], 'cl');
        expect(zizi.preparationSteps.join(' '), isNot(contains('5 мл')));
      },
    );
  }

  test(
    'EN/RU recipes share IDs, numeric measures, units and ingredient roles',
    () {
      final en = (catalogs['en']!['cocktails'] as List)
          .map((json) => Cocktail.fromJson(json as Map<String, dynamic>))
          .toList();
      final ru = (catalogs['ru']!['cocktails'] as List)
          .map((json) => Cocktail.fromJson(json as Map<String, dynamic>))
          .toList();
      expect(ru.map((c) => c.id), en.map((c) => c.id));
      for (var index = 0; index < en.length; index++) {
        final a = en[index];
        final b = ru[index];
        expect(b.ingredients, a.ingredients, reason: a.id);
        expect(b.ingredientUnits, a.ingredientUnits, reason: a.id);
        expect(b.optionalIngredients, a.optionalIngredients, reason: a.id);
        expect(b.decorationIngredients, a.decorationIngredients, reason: a.id);
        for (final id in a.ingredients) {
          final amount = a.ingredientAmounts[id]!;
          if (parseIngredientNumericRange(amount) != null) {
            expect(b.ingredientAmounts[id], amount, reason: '${a.id}/$id');
          }
        }
      }
    },
  );
}
