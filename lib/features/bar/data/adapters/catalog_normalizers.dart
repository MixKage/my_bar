import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_glass_types.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';
import '../models/catalog_layer_models.dart';
import '../utils/catalog_id_utils.dart';

ExternalIngredient normalizeExternalIngredient(
  Map<String, dynamic> raw, {
  required String source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  final aliases = _parseAliases(raw);
  final explicitId = _firstNonEmptyString(<Object?>[
    raw['id'],
    raw['sourceId'],
    raw['internalKey'],
    raw['canonicalKey'],
  ]);
  final displayName = _firstNonEmptyString(<Object?>[
    raw['name'],
    raw['displayName'],
    raw['strIngredient'],
    explicitId,
  ]);
  final canonicalSlug = ingredientMapper.resolve(
    explicitId: explicitId,
    displayName: displayName,
    aliases: aliases,
  );

  final sourceId = _firstNonEmptyString(<Object?>[raw['sourceId'], explicitId]);
  final category = _firstNonEmptyString(<Object?>[
    raw['category'],
    raw['type'],
    raw['group'],
    'Ингредиенты',
  ]);
  final image = _firstNonEmptyString(<Object?>[
    raw['image'],
    raw['imageUrl'],
    raw['strIngredientThumb'],
    '',
  ]);

  return ExternalIngredient(
    identity: CatalogIdentity(
      source: source,
      sourceId: sourceId.isEmpty ? canonicalSlug : sourceId,
      canonicalSlug: canonicalSlug,
    ),
    ingredient: Ingredient(
      id: canonicalSlug,
      name: displayName,
      category: category,
      image: image,
      isDecoration: _parseBool(raw['isDecoration'] ?? raw['decoration']),
      isOptional: _parseBool(raw['isOptional'] ?? raw['optional']),
    ),
    aliases: aliases,
  );
}

ExternalCocktail normalizeExternalCocktail(
  Map<String, dynamic> raw, {
  required String source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  final explicitId = _firstNonEmptyString(<Object?>[
    raw['id'],
    raw['sourceId'],
    raw['strDrinkId'],
    raw['strDrinkID'],
  ]);
  final name = _firstNonEmptyString(<Object?>[
    raw['name'],
    raw['displayName'],
    raw['strDrink'],
    explicitId,
  ]);
  final explicitCanonical = _firstNonEmptyString(<Object?>[
    raw['canonicalKey'],
    explicitId,
  ]);
  final canonicalSlug = explicitCanonical.isNotEmpty
      ? explicitCanonical
      : canonicalFromValue(name);

  final extractedIngredients = _extractIngredientItems(
    raw: raw,
    ingredientMapper: ingredientMapper,
  );
  final normalizedIngredientIds = extractedIngredients.ingredientIds;

  final optionalIngredients = _normalizeIngredientIdList(
    source: raw['optionalIngredients'],
    ingredientMapper: ingredientMapper,
  );
  optionalIngredients.addAll(extractedIngredients.optionalIngredients);

  final decorationIngredients = _normalizeIngredientIdList(
    source: raw['decorationIngredients'],
    ingredientMapper: ingredientMapper,
  );
  decorationIngredients.addAll(extractedIngredients.decorationIngredients);

  final ingredientAmounts = _normalizeStringMap(
    source: raw['ingredientAmounts'],
    ingredientMapper: ingredientMapper,
  )..addAll(extractedIngredients.ingredientAmounts);
  final ingredientUnits = _normalizeStringMap(
    source: raw['ingredientUnits'],
    ingredientMapper: ingredientMapper,
  )..addAll(extractedIngredients.ingredientUnits);

  final substitutions = _normalizeSubstitutions(
    source: raw['ingredientSubstitutions'],
    ingredientMapper: ingredientMapper,
  )..addAll(extractedIngredients.ingredientSubstitutions);

  final normalizedDescription = _firstNonEmptyString(<Object?>[
    raw['description'],
    raw['instructions'],
    raw['strInstructions'],
    raw['strInstructionsRU'],
    normalizedIngredientIds.join(', '),
  ]);

  final preparationSteps = _extractPreparationSteps(
    raw: raw,
    fallbackDescription: normalizedDescription,
  );

  final rawGlassType = _firstNonEmptyString(<Object?>[
    raw['glassType'],
    raw['glass'],
    raw['strGlass'],
    kDefaultCocktailGlassType,
  ]);
  final glassType = _normalizeGlassType(rawGlassType);

  final tags = _extractTags(raw['tags']);

  final image = _firstNonEmptyString(<Object?>[
    raw['image'],
    raw['imageUrl'],
    raw['strDrinkThumb'],
    '',
  ]);

  final cocktail = Cocktail(
    id: canonicalSlug,
    name: name,
    image: image,
    ingredients: normalizedIngredientIds,
    description: normalizedDescription,
    preparationSteps: preparationSteps,
    glassType: glassType,
    tags: tags,
    ingredientSubstitutions: substitutions,
    ingredientAmounts: ingredientAmounts,
    ingredientUnits: ingredientUnits,
    optionalIngredients: optionalIngredients.toList(growable: false)..sort(),
    decorationIngredients: decorationIngredients.toList(growable: false)
      ..sort(),
    isFavorite: _parseBool(raw['isFavorite']),
  );

  return ExternalCocktail(
    identity: CatalogIdentity(
      source: source,
      sourceId: _firstNonEmptyString(<Object?>[
        raw['sourceId'],
        explicitId,
      ]).ifEmpty(canonicalSlug),
      canonicalSlug: canonicalSlug,
    ),
    cocktail: cocktail,
  );
}

LocalIngredient normalizeLocalIngredient(Map<String, dynamic> raw) {
  final ingredientMap = _castMap(raw['ingredient']);
  final ingredientSource = ingredientMap.isEmpty ? raw : ingredientMap;
  final ingredient = Ingredient.fromJson(ingredientSource);
  final localId = _firstNonEmptyString(<Object?>[
    raw['localId'],
    raw['id'],
    ingredient.id,
  ]);
  final canonicalSlug = _firstNonEmptyString(<Object?>[
    raw['canonicalSlug'],
    raw['canonicalKey'],
    ingredient.id,
    localId,
  ]);
  final normalizedIngredient = Ingredient(
    id: ingredient.id.isEmpty ? canonicalSlug : ingredient.id,
    name: ingredient.name,
    category: ingredient.category,
    image: ingredient.image,
    isDecoration: ingredient.isDecoration,
    isOptional: ingredient.isOptional,
  );

  return LocalIngredient(
    localId: localId.isEmpty ? normalizedIngredient.id : localId,
    canonicalSlug: canonicalSlug,
    ingredient: normalizedIngredient,
  );
}

LocalCocktail normalizeLocalCocktail(Map<String, dynamic> raw) {
  final cocktailMap = _castMap(raw['cocktail']);
  final cocktailSource = cocktailMap.isEmpty ? raw : cocktailMap;
  final cocktail = Cocktail.fromJson(cocktailSource);
  final localId = _firstNonEmptyString(<Object?>[
    raw['localId'],
    raw['id'],
    cocktail.id,
  ]);
  final canonicalSlug = _firstNonEmptyString(<Object?>[
    raw['canonicalSlug'],
    raw['canonicalKey'],
    cocktail.id,
    localId,
  ]);
  final normalizedCocktail = Cocktail(
    id: cocktail.id.isEmpty ? canonicalSlug : cocktail.id,
    name: cocktail.name,
    image: cocktail.image,
    ingredients: cocktail.ingredients,
    description: cocktail.description,
    preparationSteps: cocktail.preparationSteps,
    glassType: _normalizeGlassType(cocktail.glassType),
    tags: _normalizeTags(cocktail.tags),
    ingredientSubstitutions: cocktail.ingredientSubstitutions,
    ingredientAmounts: cocktail.ingredientAmounts,
    ingredientUnits: cocktail.ingredientUnits,
    optionalIngredients: cocktail.optionalIngredients,
    decorationIngredients: cocktail.decorationIngredients,
    isFavorite: cocktail.isFavorite,
  );

  return LocalCocktail(
    localId: localId.isEmpty ? normalizedCocktail.id : localId,
    canonicalSlug: canonicalSlug,
    cocktail: normalizedCocktail,
  );
}

Ingredient mergeIngredient(
  ExternalIngredient external,
  IngredientOverride? override,
) {
  if (override == null || override.patch.isEmpty) {
    return external.ingredient;
  }
  return override.patch.applyTo(external.ingredient);
}

Cocktail mergeCocktail(ExternalCocktail external, CocktailOverride? override) {
  if (override == null || override.patch.isEmpty) {
    return external.cocktail;
  }
  return override.patch.applyTo(external.cocktail);
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _ExtractedIngredientItems {
  _ExtractedIngredientItems({
    required this.ingredientIds,
    required this.optionalIngredients,
    required this.decorationIngredients,
    required this.ingredientAmounts,
    required this.ingredientUnits,
    required this.ingredientSubstitutions,
  });

  final List<String> ingredientIds;
  final Set<String> optionalIngredients;
  final Set<String> decorationIngredients;
  final Map<String, String> ingredientAmounts;
  final Map<String, String> ingredientUnits;
  final Map<String, List<String>> ingredientSubstitutions;
}

_ExtractedIngredientItems _extractIngredientItems({
  required Map<String, dynamic> raw,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  final ingredientIds = <String>[];
  final optionalIngredients = <String>{};
  final decorationIngredients = <String>{};
  final ingredientAmounts = <String, String>{};
  final ingredientUnits = <String, String>{};
  final ingredientSubstitutions = <String, List<String>>{};

  final rawIngredients = raw['ingredients'];
  if (rawIngredients is List) {
    for (final item in rawIngredients) {
      if (item is Map) {
        final itemMap = _castMap(item);
        final ingredientName = _firstNonEmptyString(<Object?>[
          itemMap['name'],
          itemMap['ingredient'],
          itemMap['id'],
          itemMap['ingredientId'],
        ]);
        final ingredientId = ingredientMapper.resolve(
          explicitId: _firstNonEmptyString(<Object?>[
            itemMap['id'],
            itemMap['ingredientId'],
          ]),
          displayName: ingredientName,
          aliases: const <String>[],
        );

        if (ingredientId.isEmpty || ingredientIds.contains(ingredientId)) {
          continue;
        }
        ingredientIds.add(ingredientId);

        if (_parseBool(itemMap['isOptional'] ?? itemMap['optional'])) {
          optionalIngredients.add(ingredientId);
        }
        if (_parseBool(itemMap['isDecoration'] ?? itemMap['decoration'])) {
          decorationIngredients.add(ingredientId);
        }

        final amount = _firstNonEmptyString(<Object?>[
          itemMap['amount'],
          itemMap['measure'],
        ]);
        if (amount.isNotEmpty) {
          ingredientAmounts[ingredientId] = amount;
        }

        final unit = _firstNonEmptyString(<Object?>[itemMap['unit']]);
        if (unit.isNotEmpty) {
          ingredientUnits[ingredientId] = unit;
        }

        final substitutions = _normalizeIngredientIdList(
          source: itemMap['substitutions'],
          ingredientMapper: ingredientMapper,
        );
        if (substitutions.isNotEmpty) {
          ingredientSubstitutions[ingredientId] = substitutions.toList()
            ..sort();
        }
      } else {
        final ingredientName = item.toString().trim();
        if (ingredientName.isEmpty) {
          continue;
        }
        final ingredientId = ingredientMapper.resolve(
          explicitId: ingredientName,
          displayName: ingredientName,
        );
        if (ingredientIds.contains(ingredientId)) {
          continue;
        }
        ingredientIds.add(ingredientId);
      }
    }
  }

  if (ingredientIds.isEmpty) {
    for (var index = 1; index <= 15; index++) {
      final ingredientName = _firstNonEmptyString(<Object?>[
        raw['strIngredient$index'],
      ]);
      if (ingredientName.isEmpty) {
        continue;
      }
      final ingredientId = ingredientMapper.resolve(
        explicitId: ingredientName,
        displayName: ingredientName,
      );
      if (ingredientIds.contains(ingredientId)) {
        continue;
      }
      ingredientIds.add(ingredientId);

      final measure = _firstNonEmptyString(<Object?>[raw['strMeasure$index']]);
      if (measure.isNotEmpty) {
        ingredientAmounts[ingredientId] = measure;
      }
    }
  }

  return _ExtractedIngredientItems(
    ingredientIds: ingredientIds,
    optionalIngredients: optionalIngredients,
    decorationIngredients: decorationIngredients,
    ingredientAmounts: ingredientAmounts,
    ingredientUnits: ingredientUnits,
    ingredientSubstitutions: ingredientSubstitutions,
  );
}

Map<String, List<String>> _normalizeSubstitutions({
  required Object? source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  if (source is! Map) {
    return <String, List<String>>{};
  }

  final substitutions = <String, List<String>>{};
  for (final entry in source.entries) {
    final sourceIngredientId = ingredientMapper.resolve(
      explicitId: entry.key.toString(),
      displayName: entry.key.toString(),
    );
    if (sourceIngredientId.isEmpty) {
      continue;
    }

    final values = _normalizeIngredientIdList(
      source: entry.value,
      ingredientMapper: ingredientMapper,
    );
    if (values.isEmpty) {
      continue;
    }
    substitutions[sourceIngredientId] = values.toList(growable: false)..sort();
  }

  return substitutions;
}

Map<String, String> _normalizeStringMap({
  required Object? source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  if (source is! Map) {
    return <String, String>{};
  }

  final result = <String, String>{};
  for (final entry in source.entries) {
    final ingredientId = ingredientMapper.resolve(
      explicitId: entry.key.toString(),
      displayName: entry.key.toString(),
    );
    if (ingredientId.isEmpty) {
      continue;
    }
    final value = entry.value.toString().trim();
    if (value.isEmpty) {
      continue;
    }
    result[ingredientId] = value;
  }

  return result;
}

Set<String> _normalizeIngredientIdList({
  required Object? source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  if (source is! List) {
    return <String>{};
  }

  final normalized = <String>{};
  for (final item in source) {
    final value = item.toString().trim();
    if (value.isEmpty) {
      continue;
    }
    normalized.add(
      ingredientMapper.resolve(explicitId: value, displayName: value),
    );
  }
  return normalized;
}

List<String> _extractTags(Object? value) {
  final rawValues = <String>[];

  if (value is List) {
    rawValues.addAll(
      value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty),
    );
  }

  if (value is String) {
    rawValues.addAll(
      value
          .split(RegExp(r'[,;|]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }

  final normalized = _normalizeTags(rawValues);
  if (normalized.isEmpty) {
    return <String>[kUserCocktailTag];
  }
  return normalized;
}

List<String> _normalizeTags(Iterable<String> tags) {
  final normalized = tags.where(kCocktailTags.contains).toSet().toList()
    ..sort(
      (left, right) =>
          kCocktailTags.indexOf(left).compareTo(kCocktailTags.indexOf(right)),
    );
  return normalized;
}

List<String> _extractPreparationSteps({
  required Map<String, dynamic> raw,
  required String fallbackDescription,
}) {
  final rawSteps = raw['preparationSteps'];
  if (rawSteps is List) {
    final steps = rawSteps
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (steps.isNotEmpty) {
      return steps;
    }
  }

  final instructions = _firstNonEmptyString(<Object?>[
    raw['instructions'],
    raw['strInstructions'],
    raw['description'],
  ]);

  if (instructions.isNotEmpty) {
    final splitSteps = instructions
        .split(RegExp(r'\n|\.\s+'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList(growable: false);
    if (splitSteps.isNotEmpty) {
      return splitSteps;
    }
  }

  if (fallbackDescription.trim().isNotEmpty) {
    return <String>['Смешайте ингредиенты: ${fallbackDescription.trim()}'];
  }

  return <String>['Смешайте ингредиенты и подавайте.'];
}

String _normalizeGlassType(String value) {
  if (kCocktailGlassTypes.contains(value)) {
    return value;
  }
  return kDefaultCocktailGlassType;
}

List<String> _parseAliases(Map<String, dynamic> raw) {
  final aliases = <String>{};
  final rawAliases = raw['aliases'];
  if (rawAliases is List) {
    aliases.addAll(
      rawAliases
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty),
    );
  }

  final altName = _firstNonEmptyString(<Object?>[raw['strIngredientAlt']]);
  if (altName.isNotEmpty) {
    aliases.add(altName);
  }

  return aliases.toList(growable: false);
}

String _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

bool _parseBool(Object? value) {
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

Map<String, dynamic> _castMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return <String, dynamic>{};
}
