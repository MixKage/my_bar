import 'package:meta/meta.dart';

import 'cocktail_glass_types.dart';
import 'cocktail_tags.dart';
import 'ingredient_units.dart';
import 'measurement_system.dart';

@immutable
class Cocktail {
  const Cocktail({
    required this.id,
    required this.name,
    required this.image,
    required this.ingredients,
    required this.description,
    required this.preparationSteps,
    required this.glassType,
    required this.tags,
    this.ingredientSubstitutions = const <String, List<String>>{},
    this.ingredientAmounts = const <String, String>{},
    this.ingredientUnits = const <String, String>{},
    this.optionalIngredients = const <String>[],
    this.decorationIngredients = const <String>[],
    this.isFavorite = false,
  });

  factory Cocktail.fromJson(Map<String, dynamic> json) {
    final ingredientsJson = json['ingredients'];
    final ingredients = ingredientsJson is List
        ? ingredientsJson.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final tagsJson = json['tags'];
    final parsedTags = tagsJson is List
        ? tagsJson.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final tags =
        parsedTags.where((tag) => tag.trim().isNotEmpty).toSet().toList()..sort(
          (a, b) =>
              kCocktailTags.indexOf(a).compareTo(kCocktailTags.indexOf(b)),
        );
    if (tags.isEmpty) {
      tags.add(kUserCocktailTag);
    }
    final glassType = (json['glassType'] as String?)?.trim().isNotEmpty ?? false
        ? (json['glassType'] as String).trim()
        : kDefaultCocktailGlassType;
    final preparationStepsJson = json['preparationSteps'];
    final preparationSteps = preparationStepsJson is List
        ? preparationStepsJson
              .map((item) => item.toString().trim())
              .where((step) => step.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final normalizedSteps = preparationSteps.isEmpty
        ? _fallbackPreparationSteps(
            ingredients: ingredients,
            description: (json['description'] as String? ?? '').trim(),
          )
        : preparationSteps;
    final substitutionsJson = json['ingredientSubstitutions'];
    final ingredientSubstitutions = _parseIngredientSubstitutions(
      substitutionsJson,
    );
    final ingredientAmounts = _parseStringMap(json['ingredientAmounts']);
    final ingredientUnits = _parseIngredientUnitsMap(json['ingredientUnits']);
    final optionalIngredients = _parseStringList(json['optionalIngredients']);
    final decorationIngredients = _parseStringList(
      json['decorationIngredients'],
    );

    return Cocktail(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      image: (json['image'] as String? ?? '').trim(),
      ingredients: ingredients,
      description: (json['description'] as String? ?? '').trim(),
      preparationSteps: normalizedSteps,
      glassType: glassType,
      tags: tags,
      ingredientSubstitutions: ingredientSubstitutions,
      ingredientAmounts: ingredientAmounts,
      ingredientUnits: ingredientUnits,
      optionalIngredients: optionalIngredients,
      decorationIngredients: decorationIngredients,
      isFavorite: _parseBool(json['isFavorite']),
    );
  }

  final String id;
  final String name;
  final String image;
  final List<String> ingredients;
  final String description;
  final List<String> preparationSteps;
  final String glassType;
  final List<String> tags;
  final Map<String, List<String>> ingredientSubstitutions;
  final Map<String, String> ingredientAmounts;
  final Map<String, String> ingredientUnits;
  final List<String> optionalIngredients;
  final List<String> decorationIngredients;
  final bool isFavorite;

  bool isIngredientOptional(String ingredientId) {
    return optionalIngredients.contains(ingredientId);
  }

  bool isIngredientDecoration(String ingredientId) {
    return decorationIngredients.contains(ingredientId);
  }

  String ingredientAmountLabel(
    String ingredientId, {
    MeasurementSystem? measurementSystem,
    String Function(String unit)? unitLabelResolver,
  }) {
    final amount = (ingredientAmounts[ingredientId] ?? '').trim();
    final unit = normalizeIngredientUnitToken(
      (ingredientUnits[ingredientId] ?? '').trim(),
    );
    final resolved = measurementSystem == null
        ? IngredientAmountPresentation(amount: amount, unit: unit)
        : resolveIngredientAmountForMeasurementSystem(
            amount: amount,
            unit: unit,
            measurementSystem: measurementSystem,
          );
    final resolvedUnit = unitLabelResolver == null
        ? resolved.unit
        : unitLabelResolver(resolved.unit);

    final normalizedAmount = resolved.amount.trim();
    final normalizedUnit = resolvedUnit.trim();
    if (normalizedAmount.isEmpty && normalizedUnit.isEmpty) {
      return '';
    }
    if (normalizedAmount.isEmpty) {
      return normalizedUnit;
    }
    if (normalizedUnit.isEmpty) {
      return normalizedAmount;
    }
    return '$normalizedAmount $normalizedUnit';
  }

  static Map<String, String> _parseIngredientUnitsMap(Object? value) {
    final raw = _parseStringMap(value);
    if (raw.isEmpty) {
      return raw;
    }
    final normalized = <String, String>{};
    for (final entry in raw.entries) {
      normalized[entry.key] = normalizeIngredientUnitToken(entry.value);
    }
    return normalized;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'image': image,
      'ingredients': ingredients,
      'description': description,
      'preparationSteps': preparationSteps,
      'glassType': glassType,
      'tags': tags,
      'ingredientSubstitutions': ingredientSubstitutions,
      'ingredientAmounts': ingredientAmounts,
      'ingredientUnits': ingredientUnits,
      'optionalIngredients': optionalIngredients,
      'decorationIngredients': decorationIngredients,
      'isFavorite': isFavorite,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Cocktail &&
            other.id == id &&
            other.name == name &&
            other.image == image &&
            _listEquals(other.ingredients, ingredients) &&
            other.description == description &&
            _listEquals(other.preparationSteps, preparationSteps) &&
            other.glassType == glassType &&
            _listEquals(other.tags, tags) &&
            _substitutionsEquals(
              other.ingredientSubstitutions,
              ingredientSubstitutions,
            ) &&
            _mapEquals(other.ingredientAmounts, ingredientAmounts) &&
            _mapEquals(other.ingredientUnits, ingredientUnits) &&
            _listEquals(other.optionalIngredients, optionalIngredients) &&
            _listEquals(other.decorationIngredients, decorationIngredients) &&
            other.isFavorite == isFavorite;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      image,
      Object.hashAll(ingredients),
      description,
      Object.hashAll(preparationSteps),
      glassType,
      Object.hashAll(tags),
      Object.hashAll(_substitutionsHashEntries(ingredientSubstitutions)),
      Object.hashAll(_stringMapHashEntries(ingredientAmounts)),
      Object.hashAll(_stringMapHashEntries(ingredientUnits)),
      Object.hashAll(optionalIngredients),
      Object.hashAll(decorationIngredients),
      isFavorite,
    );
  }

  static List<String> _fallbackPreparationSteps({
    required List<String> ingredients,
    required String description,
  }) {
    if (description.isNotEmpty) {
      return <String>['Смешайте ингредиенты: $description'];
    }
    if (ingredients.isNotEmpty) {
      return <String>['Смешайте ингредиенты и подавайте охлаждённым.'];
    }
    return <String>['Добавьте шаги приготовления.'];
  }

  static Map<String, List<String>> _parseIngredientSubstitutions(
    Object? value,
  ) {
    if (value is! Map) {
      return const <String, List<String>>{};
    }

    final result = <String, List<String>>{};
    for (final entry in value.entries) {
      final ingredientId = entry.key.toString().trim();
      if (ingredientId.isEmpty) {
        continue;
      }
      final rawSubstitutions = entry.value;
      if (rawSubstitutions is! List) {
        continue;
      }
      final substitutions =
          rawSubstitutions
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort();
      if (substitutions.isEmpty) {
        continue;
      }
      result[ingredientId] = substitutions;
    }

    return result;
  }

  static Map<String, String> _parseStringMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }

    final result = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final mapValue = entry.value.toString().trim();
      if (key.isEmpty || mapValue.isEmpty) {
        continue;
      }
      result[key] = mapValue;
    }
    return result;
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    final normalized =
        value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return normalized;
  }

  static bool _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'да';
    }
    return false;
  }

  static bool _substitutionsEquals(
    Map<String, List<String>> left,
    Map<String, List<String>> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      final rightValue = right[entry.key];
      if (rightValue == null || !_listEquals(entry.value, rightValue)) {
        return false;
      }
    }
    return true;
  }

  static Iterable<Object> _substitutionsHashEntries(
    Map<String, List<String>> substitutions,
  ) sync* {
    final keys = substitutions.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final values = substitutions[key] ?? const <String>[];
      yield Object.hash(key, Object.hashAll(values));
    }
  }

  static Iterable<Object> _stringMapHashEntries(
    Map<String, String> value,
  ) sync* {
    final keys = value.keys.toList(growable: false)..sort();
    for (final key in keys) {
      yield Object.hash(key, value[key]);
    }
  }
}

bool _listEquals<T>(List<T>? left, List<T>? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V>? left, Map<K, V>? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
