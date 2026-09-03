import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
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
}
