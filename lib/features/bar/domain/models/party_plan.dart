import 'cocktail.dart';
import 'ingredient.dart';
import 'ingredient_units.dart';
import 'measurement_system.dart';

class PartyCocktailSelection {
  const PartyCocktailSelection({
    required this.cocktail,
    required this.servings,
  });

  final Cocktail cocktail;
  final int servings;
}

class PartyIngredientTotal {
  const PartyIngredientTotal({
    required this.ingredientId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.notes,
  });

  final String ingredientId;
  final String name;
  final String amount;
  final String unit;
  final List<String> notes;

  String label({String Function(String unit)? unitLabelResolver}) {
    final resolvedUnit = unitLabelResolver?.call(unit) ?? unit;
    final numeric = [
      amount,
      resolvedUnit,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return <String>[
      numeric,
      ...notes,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
  }
}

List<PartyIngredientTotal> buildPartyIngredientTotals({
  required List<PartyCocktailSelection> selections,
  required Map<String, Ingredient> ingredientsById,
  required MeasurementSystem measurementSystem,
}) {
  final accumulators = <String, _PartyTotalAccumulator>{};

  for (final selection in selections) {
    final servings = selection.servings.clamp(1, 50);
    for (final ingredientId in selection.cocktail.ingredients) {
      final presentation = resolveIngredientAmountForMeasurementSystem(
        amount: selection.cocktail.ingredientAmounts[ingredientId] ?? '',
        unit: selection.cocktail.ingredientUnits[ingredientId] ?? '',
        measurementSystem: measurementSystem,
      );
      final parsed = parseIngredientNumericRange(presentation.amount);
      final key = '$ingredientId\u0000${presentation.unit}';
      final accumulator = accumulators.putIfAbsent(
        key,
        () => _PartyTotalAccumulator(
          ingredientId: ingredientId,
          name: ingredientsById[ingredientId]?.name ?? ingredientId,
          unit: presentation.unit,
        ),
      );
      if (parsed != null) {
        final previousStart = accumulator.start;
        accumulator.start += parsed.start * servings;
        if (parsed.end != null) {
          accumulator.end =
              (accumulator.end ?? previousStart) + parsed.end! * servings;
        } else if (accumulator.end != null) {
          accumulator.end = accumulator.end! + parsed.start * servings;
        }
      } else {
        final note = presentation.amount.trim();
        if (note.isNotEmpty) {
          accumulator.notes.add(note);
        }
      }
    }
  }

  final totals =
      accumulators.values
          .map((accumulator) {
            final hasNumeric = accumulator.start > 0 || accumulator.end != null;
            final amount = !hasNumeric
                ? ''
                : accumulator.end == null
                ? formatIngredientNumber(accumulator.start)
                : '${formatIngredientNumber(accumulator.start)}-'
                      '${formatIngredientNumber(accumulator.end!)}';
            final notes = accumulator.notes.toList(growable: false)..sort();
            return PartyIngredientTotal(
              ingredientId: accumulator.ingredientId,
              name: accumulator.name,
              amount: amount,
              unit: accumulator.unit,
              notes: notes,
            );
          })
          .toList(growable: false)
        ..sort(
          (left, right) =>
              left.name.toLowerCase().compareTo(right.name.toLowerCase()),
        );
  return totals;
}

class _PartyTotalAccumulator {
  _PartyTotalAccumulator({
    required this.ingredientId,
    required this.name,
    required this.unit,
  });

  final String ingredientId;
  final String name;
  final String unit;
  double start = 0;
  double? end;
  final Set<String> notes = <String>{};
}
