import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';
import 'package:my_bar/features/bar/domain/models/party_plan.dart';

void main() {
  test('aggregates converted ingredient amounts for the party plan', () {
    const gin = Ingredient(
      id: 'gin',
      name: 'Gin',
      category: 'Spirits',
      image: '',
    );
    const garnish = Ingredient(
      id: 'garnish',
      name: 'Garnish',
      category: 'Decoration',
      image: '',
    );
    const first = Cocktail(
      id: 'first',
      name: 'First',
      image: '',
      ingredients: <String>['gin', 'garnish'],
      description: '',
      preparationSteps: <String>['Mix'],
      glassType: 'Рокс',
      tags: <String>['Крепкие'],
      ingredientAmounts: <String, String>{'gin': '50', 'garnish': 'по вкусу'},
      ingredientUnits: <String, String>{'gin': 'мл'},
    );
    const second = Cocktail(
      id: 'second',
      name: 'Second',
      image: '',
      ingredients: <String>['gin'],
      description: '',
      preparationSteps: <String>['Mix'],
      glassType: 'Рокс',
      tags: <String>['Крепкие'],
      ingredientAmounts: <String, String>{'gin': '1'},
      ingredientUnits: <String, String>{'gin': 'oz'},
    );

    final totals = buildPartyIngredientTotals(
      selections: const <PartyCocktailSelection>[
        PartyCocktailSelection(cocktail: first, servings: 2),
        PartyCocktailSelection(cocktail: second, servings: 1),
      ],
      ingredientsById: const <String, Ingredient>{
        'gin': gin,
        'garnish': garnish,
      },
      measurementSystem: MeasurementSystem.ml,
    );

    final ginTotal = totals.singleWhere((total) => total.ingredientId == 'gin');
    final garnishTotal = totals.singleWhere(
      (total) => total.ingredientId == 'garnish',
    );
    expect(ginTotal.amount, '130');
    expect(ginTotal.unit, 'мл');
    expect(garnishTotal.notes, <String>['по вкусу']);
  });
}
