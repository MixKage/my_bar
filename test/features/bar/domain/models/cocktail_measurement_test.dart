import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient_units.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';

void main() {
  const cocktail = Cocktail(
    id: 'test',
    name: 'Test',
    image: '',
    ingredients: <String>['base', 'syrup', 'juice', 'aroma'],
    description: 'Test',
    preparationSteps: <String>['Mix'],
    glassType: 'Рокс',
    tags: <String>['Крепкие'],
    ingredientAmounts: <String, String>{
      'base': '1 1/2',
      'syrup': '40',
      'juice': '2',
      'aroma': '1',
    },
    ingredientUnits: <String, String>{
      'base': 'унц',
      'syrup': 'мл',
      'juice': 'oz',
      'aroma': 'dash',
    },
  );

  test('keeps original amount formatting for same volume system', () {
    expect(
      cocktail.ingredientAmountLabel(
        'base',
        measurementSystem: MeasurementSystem.flOz,
      ),
      '1 1/2 oz',
    );
  });

  test('converts volume units between systems', () {
    expect(
      cocktail.ingredientAmountLabel(
        'base',
        measurementSystem: MeasurementSystem.ml,
      ),
      '44 мл',
    );
    expect(
      cocktail.ingredientAmountLabel(
        'syrup',
        measurementSystem: MeasurementSystem.cl,
      ),
      '4 cl',
    );
  });

  test('applies custom unit label resolver after conversion', () {
    expect(
      cocktail.ingredientAmountLabel(
        'juice',
        measurementSystem: MeasurementSystem.flOz,
        unitLabelResolver: (unit) => unit == 'oz' ? 'fl oz' : unit,
      ),
      '2 fl oz',
    );
  });

  test('does not append the editor empty-unit label to recipe amounts', () {
    const recipe = Cocktail(
      id: 'free-form',
      name: 'Free-form amounts',
      image: '',
      ingredients: ['soda', 'mint', 'unknown'],
      description: '',
      preparationSteps: ['Mix'],
      glassType: 'Хайболл',
      tags: [],
      ingredientAmounts: {'soda': 'Top up', 'mint': '2'},
    );
    for (final entry in {
      'soda': 'Top up',
      'mint': '2',
      'unknown': '',
    }.entries) {
      expect(
        recipe.ingredientAmountLabel(
          entry.key,
          measurementSystem: MeasurementSystem.ml,
          unitLabelResolver: (_) => 'No unit',
          servings: 1,
        ),
        entry.value,
      );
    }
  });

  test('does not convert non-volume units', () {
    expect(
      cocktail.ingredientAmountLabel(
        'aroma',
        measurementSystem: MeasurementSystem.ml,
      ),
      '1 dash',
    );
  });

  test('scales numeric and fractional amounts by servings', () {
    expect(
      cocktail.ingredientAmountLabel(
        'base',
        measurementSystem: MeasurementSystem.flOz,
        servings: 4,
      ),
      '6 oz',
    );
    expect(
      cocktail.ingredientAmountLabel(
        'aroma',
        measurementSystem: MeasurementSystem.ml,
        servings: 3,
      ),
      '3 dash',
    );
  });

  test('normalizes gram aliases without treating weights as volume', () {
    for (final alias in <String>['g', 'гр', 'г', 'gram', 'grams', 'ГР.']) {
      expect(normalizeIngredientUnitToken(alias), 'g');
      expect(isVolumeIngredientUnit(alias), isFalse);
    }
  });

  test('keeps count, package and unspecified regional measures intact', () {
    const aliases = <String, String>{
      'sprigs': 'sprig',
      'leaves': 'leaf',
      'scoops': 'scoop',
      'twists': 'twist',
      'sticks': 'stick',
      'cubes': 'cube',
      'bottles': 'bottle',
      'cans': 'can',
      'packets': 'package',
      'inches': 'inch',
      'pounds': 'lb',
      'pints': 'pint',
      'quarts': 'qt',
      'gallons': 'gal',
      'handfuls': 'handful',
    };
    for (final entry in aliases.entries) {
      final presentation = resolveIngredientAmountForMeasurementSystem(
        amount: '1/2-1',
        unit: entry.key,
        measurementSystem: MeasurementSystem.ml,
      );
      expect(presentation.unit, entry.value);
      expect(kSupportedIngredientUnits, contains(entry.value));
      expect(presentation.amount, '1/2-1');
      expect(isVolumeIngredientUnit(entry.value), isFalse);
      expect(scaleIngredientAmount(presentation.amount, 4), '2-4');
    }
  });

  test('scales gram ranges without converting them to volume units', () {
    const weighted = Cocktail(
      id: 'weighted',
      name: 'Weighted',
      image: '',
      ingredients: <String>['sugar'],
      description: '',
      preparationSteps: <String>['Mix'],
      glassType: 'Рокс',
      tags: <String>[],
      ingredientAmounts: <String, String>{'sugar': '2 1/2–5'},
      ingredientUnits: <String, String>{'sugar': 'grams'},
    );

    for (final system in MeasurementSystem.values) {
      expect(
        weighted.ingredientAmountLabel(
          'sugar',
          measurementSystem: system,
          servings: 3,
        ),
        '7.5-15 g',
      );
    }
  });

  test('converts mixed fractions and decimal-comma volume ranges', () {
    final ounces = resolveIngredientAmountForMeasurementSystem(
      amount: '1 1/2–2',
      unit: 'fl oz',
      measurementSystem: MeasurementSystem.ml,
    );
    expect(ounces.amount, '44-59');
    expect(ounces.unit, 'мл');

    final centiliters = resolveIngredientAmountForMeasurementSystem(
      amount: '1,5—2',
      unit: 'cl',
      measurementSystem: MeasurementSystem.ml,
    );
    expect(centiliters.amount, '15-20');
    expect(centiliters.unit, 'мл');
  });

  test('formats decimal amounts without literal regular-expression groups', () {
    expect(formatIngredientNumber(7.5), '7.5');
    expect(formatIngredientNumber(7.25), '7.25');
    expect(formatIngredientNumber(7), '7');
    expect(scaleIngredientAmount('1/2', 3), '1.5');
    final ounces = resolveIngredientAmountForMeasurementSystem(
      amount: '4.437',
      unit: 'cl',
      measurementSystem: MeasurementSystem.flOz,
    );
    expect(ounces.amount, '1.5');
  });
}
