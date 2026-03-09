import 'measurement_system.dart';

const List<String> kSupportedIngredientUnits = <String>[
  '',
  'мл',
  'л',
  'oz',
  'cl',
  'tsp',
  'tbsp',
  'shot',
  'part',
  'cup',
  'dash',
  'pinch',
  'ч.ложка',
  'ч.ложки',
  'ст.ложка',
  'ст.ложки',
  'долька',
  'шт',
  'капля',
  'по вкусу',
];

final Set<String> kSupportedIngredientUnitsSet = kSupportedIngredientUnits
    .toSet();

const Set<String> _volumeUnitTokens = <String>{'мл', 'л', 'oz', 'cl'};

class IngredientAmountPresentation {
  const IngredientAmountPresentation({
    required this.amount,
    required this.unit,
  });

  final String amount;
  final String unit;
}

String normalizeIngredientUnitToken(String source) {
  final unit = source.trim();
  if (unit.isEmpty) {
    return '';
  }
  if (kSupportedIngredientUnitsSet.contains(unit)) {
    return unit;
  }

  final normalized = _normalizeUnitKey(unit);
  return _unitAliasesByKey[normalized] ?? unit;
}

bool isVolumeIngredientUnit(String source) {
  final normalizedUnit = normalizeIngredientUnitToken(source);
  return _volumeUnitTokens.contains(normalizedUnit);
}

String unitTokenForMeasurementSystem(MeasurementSystem system) {
  switch (system) {
    case MeasurementSystem.flOz:
      return 'oz';
    case MeasurementSystem.ml:
      return 'мл';
    case MeasurementSystem.cl:
      return 'cl';
  }
}

IngredientAmountPresentation resolveIngredientAmountForMeasurementSystem({
  required String amount,
  required String unit,
  required MeasurementSystem measurementSystem,
}) {
  final rawAmount = amount.trim();
  final normalizedUnit = normalizeIngredientUnitToken(unit);
  if (normalizedUnit.isEmpty || !_volumeUnitTokens.contains(normalizedUnit)) {
    return IngredientAmountPresentation(
      amount: rawAmount,
      unit: normalizedUnit,
    );
  }

  final targetUnit = unitTokenForMeasurementSystem(measurementSystem);
  if (normalizedUnit == targetUnit || rawAmount.isEmpty) {
    return IngredientAmountPresentation(amount: rawAmount, unit: targetUnit);
  }

  final parsedRange = _parseNumericRange(rawAmount);
  if (parsedRange == null) {
    return IngredientAmountPresentation(
      amount: rawAmount,
      unit: normalizedUnit,
    );
  }

  final convertedStart = _convertVolume(
    value: parsedRange.start,
    fromUnit: normalizedUnit,
    toUnit: targetUnit,
  );
  final convertedEnd = parsedRange.end == null
      ? null
      : _convertVolume(
          value: parsedRange.end!,
          fromUnit: normalizedUnit,
          toUnit: targetUnit,
        );

  final formattedAmount = convertedEnd == null
      ? _formatAmount(convertedStart, measurementSystem)
      : '${_formatAmount(convertedStart, measurementSystem)}-'
            '${_formatAmount(convertedEnd, measurementSystem)}';
  return IngredientAmountPresentation(
    amount: formattedAmount,
    unit: targetUnit,
  );
}

double _convertVolume({
  required double value,
  required String fromUnit,
  required String toUnit,
}) {
  if (fromUnit == toUnit) {
    return value;
  }
  final valueInMilliliters = switch (fromUnit) {
    'oz' => value * 29.5735295625,
    'мл' => value,
    'cl' => value * 10,
    'л' => value * 1000,
    _ => value,
  };
  return switch (toUnit) {
    'oz' => valueInMilliliters / 29.5735295625,
    'мл' => valueInMilliliters,
    'cl' => valueInMilliliters / 10,
    'л' => valueInMilliliters / 1000,
    _ => value,
  };
}

String _formatAmount(double value, MeasurementSystem system) {
  switch (system) {
    case MeasurementSystem.flOz:
      return _formatFixed(value, fractionDigits: 2);
    case MeasurementSystem.ml:
      final rounded = value.roundToDouble();
      if (rounded == 0 && value > 0) {
        return _formatFixed(value, fractionDigits: 1);
      }
      return _formatFixed(rounded, fractionDigits: 0);
    case MeasurementSystem.cl:
      return _formatFixed(value, fractionDigits: 1);
  }
}

String _formatFixed(double value, {required int fractionDigits}) {
  final text = value.toStringAsFixed(fractionDigits);
  return text
      .replaceFirst(RegExp(r'([.,]\d*?[1-9])0+$'), r'$1')
      .replaceFirst(RegExp(r'[.,]0+$'), '')
      .replaceAll(',', '.');
}

_ParsedNumericRange? _parseNumericRange(String source) {
  final normalized = source
      .trim()
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('—', '-');
  if (normalized.isEmpty) {
    return null;
  }

  final rangeParts = normalized.split(RegExp(r'\s*-\s*'));
  if (rangeParts.length == 1) {
    final singleValue = _parseNumericToken(rangeParts.first);
    if (singleValue == null) {
      return null;
    }
    return _ParsedNumericRange(start: singleValue);
  }
  if (rangeParts.length == 2) {
    final left = _parseNumericToken(rangeParts.first);
    final right = _parseNumericToken(rangeParts.last);
    if (left == null || right == null) {
      return null;
    }
    return _ParsedNumericRange(start: left, end: right);
  }
  return null;
}

double? _parseNumericToken(String source) {
  final normalized = source.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final asDecimal = double.tryParse(normalized.replaceAll(',', '.'));
  if (asDecimal != null) {
    return asDecimal;
  }

  final mixedMatch = RegExp(
    r'^(\d+)\s+(\d+)\s*/\s*(\d+)$',
  ).firstMatch(normalized);
  if (mixedMatch != null) {
    final whole = int.parse(mixedMatch.group(1)!);
    final numerator = int.parse(mixedMatch.group(2)!);
    final denominator = int.parse(mixedMatch.group(3)!);
    if (denominator == 0) {
      return null;
    }
    return whole + (numerator / denominator);
  }

  final fractionMatch = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(normalized);
  if (fractionMatch != null) {
    final numerator = int.parse(fractionMatch.group(1)!);
    final denominator = int.parse(fractionMatch.group(2)!);
    if (denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }
  return null;
}

String _normalizeUnitKey(String source) {
  final lower = source.trim().toLowerCase();
  return lower
      .replaceAll('ё', 'е')
      .replaceAll(',', '')
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), '_');
}

class _ParsedNumericRange {
  const _ParsedNumericRange({required this.start, this.end});

  final double start;
  final double? end;
}

const Map<String, String> _unitAliasesByKey = <String, String>{
  'ml': 'мл',
  'milliliter': 'мл',
  'milliliters': 'мл',
  'millilitre': 'мл',
  'millilitres': 'мл',
  'l': 'л',
  'liter': 'л',
  'liters': 'л',
  'litre': 'л',
  'litres': 'л',
  'fl_oz': 'oz',
  'fl_ounce': 'oz',
  'fl_ounces': 'oz',
  'ounce': 'oz',
  'ounces': 'oz',
  'унц': 'oz',
  'унция': 'oz',
  'унции': 'oz',
  'cup': 'cup',
  'cups': 'cup',
  'чашка': 'cup',
  'shot': 'shot',
  'shots': 'shot',
  'шот': 'shot',
  'part': 'part',
  'parts': 'part',
  'часть': 'part',
  'dash': 'dash',
  'dashes': 'dash',
  'дэш': 'dash',
  'pinch': 'pinch',
  'pinches': 'pinch',
  'щепотка': 'pinch',
  'drop': 'капля',
  'drops': 'капля',
  'slice': 'долька',
  'slices': 'долька',
  'wedge': 'долька',
  'wedges': 'долька',
  'piece': 'шт',
  'pieces': 'шт',
  'to_taste': 'по вкусу',
};
