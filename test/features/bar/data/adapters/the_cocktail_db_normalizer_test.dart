import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/adapters/the_cocktail_db_normalizer.dart';
import 'package:my_bar/features/bar/data/utils/catalog_id_utils.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

void main() {
  test(
    'normalizes TheCocktailDB ingredient with explicit internal key mapping',
    () {
      final mapper =
          IngredientCanonicalMapper.fromKnownIngredients(<Ingredient>[
            const Ingredient(
              id: 'rum_dark',
              name: 'Тёмный ром',
              category: 'Крепкий алкоголь',
              image: '',
            ),
          ]);

      final ingredient = normalizeTheCocktailDbIngredientRaw(
        <String, dynamic>{'strIngredient1': 'Dark Rum'},
        source: 'thecocktaildb_v1',
        ingredientMapper: mapper,
      );

      expect(ingredient.ingredient.id, 'rum_dark');
      expect(ingredient.identity.sourceId, 'Dark Rum');
      expect(
        ingredient.ingredient.image,
        contains('https://www.thecocktaildb.com/images/ingredients/'),
      );
    },
  );

  test('normalizes TheCocktailDB cocktail and parses ingredients/measures', () {
    final mapper = IngredientCanonicalMapper.fromKnownIngredients(<Ingredient>[
      const Ingredient(
        id: 'rum_dark',
        name: 'Тёмный ром',
        category: 'Крепкий алкоголь',
        image: '',
      ),
      const Ingredient(id: 'lime', name: 'Лайм', category: 'Фрукты', image: ''),
      const Ingredient(id: 'mint', name: 'Мята', category: 'Травы', image: ''),
    ]);

    final cocktail = normalizeTheCocktailDbCocktailRaw(
      <String, dynamic>{
        'idDrink': '11000',
        'strDrink': 'Mojito',
        'strInstructions': 'Step one. Step two.',
        'strGlass': 'Highball glass',
        'strAlcoholic': 'Alcoholic',
        'strCategory': 'Ordinary Drink',
        'strIngredient1': 'Dark Rum',
        'strMeasure1': '1 1/2 oz',
        'strIngredient2': 'Lime Juice',
        'strMeasure2': '1 oz',
        'strIngredient3': 'Mint leaves',
        'strMeasure3': '6',
      },
      source: 'thecocktaildb_v1',
      ingredientMapper: mapper,
      knownCocktailIdsByName: <String, String>{'mojito': 'mojito'},
      usedCocktailIds: <String>{},
    );

    expect(cocktail.identity.sourceId, '11000');
    expect(cocktail.cocktail.id, 'mojito');
    expect(
      cocktail.cocktail.ingredients,
      containsAll(<String>['rum_dark', 'lime', 'mint']),
    );
    expect(cocktail.cocktail.ingredientAmounts['rum_dark'], '1 1/2');
    expect(cocktail.cocktail.ingredientUnits['rum_dark'], 'oz');
    expect(cocktail.cocktail.glassType, 'Хайболл');
    expect(cocktail.cocktail.preparationSteps, hasLength(2));
  });

  test('dedupes TheCocktailDB cocktails by sourceId', () {
    final mapper = IngredientCanonicalMapper.fromKnownIngredients(
      const <Ingredient>[],
    );

    final normalized = normalizeTheCocktailDbCocktails(
      rawCocktails: <Map<String, dynamic>>[
        <String, dynamic>{
          'idDrink': '42',
          'strDrink': 'Example Drink',
          'strInstructions': 'Mix.',
          'strGlass': 'Shot glass',
        },
        <String, dynamic>{
          'idDrink': '42',
          'strDrink': 'Example Drink Duplicate',
          'strInstructions': 'Mix.',
          'strGlass': 'Shot glass',
        },
      ],
      source: 'thecocktaildb_v1',
      ingredientMapper: mapper,
      knownCocktails: const <Cocktail>[],
    );

    expect(normalized, hasLength(1));
    expect(normalized.single.identity.sourceId, '42');
  });
}
