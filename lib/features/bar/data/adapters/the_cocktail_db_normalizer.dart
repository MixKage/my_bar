import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_glass_types.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';
import '../models/catalog_layer_models.dart';
import '../utils/catalog_id_utils.dart';

List<ExternalIngredient> normalizeTheCocktailDbIngredients({
  required List<Map<String, dynamic>> rawIngredients,
  required String source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  final normalized = <ExternalIngredient>[];
  final seenSourceIds = <String>{};

  for (final raw in rawIngredients) {
    final ingredient = normalizeTheCocktailDbIngredientRaw(
      raw,
      source: source,
      ingredientMapper: ingredientMapper,
    );
    if (ingredient.identity.sourceId.isEmpty) {
      continue;
    }
    if (!seenSourceIds.add(ingredient.identity.sourceId)) {
      continue;
    }
    normalized.add(ingredient);
  }

  return normalized;
}

List<ExternalCocktail> normalizeTheCocktailDbCocktails({
  required List<Map<String, dynamic>> rawCocktails,
  required String source,
  required IngredientCanonicalMapper ingredientMapper,
  required Iterable<Cocktail> knownCocktails,
}) {
  final knownCocktailIdsByName = <String, String>{
    for (final cocktail in knownCocktails)
      normalizeKey(cocktail.name): cocktail.id,
  };

  final normalized = <ExternalCocktail>[];
  final usedCocktailIds = <String>{};
  final seenSourceIds = <String>{};

  for (final raw in rawCocktails) {
    final cocktail = normalizeTheCocktailDbCocktailRaw(
      raw,
      source: source,
      ingredientMapper: ingredientMapper,
      knownCocktailIdsByName: knownCocktailIdsByName,
      usedCocktailIds: usedCocktailIds,
    );

    if (cocktail.identity.sourceId.isEmpty) {
      continue;
    }
    if (!seenSourceIds.add(cocktail.identity.sourceId)) {
      continue;
    }

    normalized.add(cocktail);
  }

  return normalized;
}

ExternalIngredient normalizeTheCocktailDbIngredientRaw(
  Map<String, dynamic> raw, {
  required String source,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  final name = _firstNonEmptyString(<Object?>[
    raw['strIngredient1'],
    raw['strIngredient'],
    raw['name'],
    raw['ingredient'],
  ]);
  final sourceId = _firstNonEmptyString(<Object?>[
    raw['idIngredient'],
    raw['sourceId'],
    name,
  ]);

  final mappedKey = _resolveIngredientCanonicalKey(
    ingredientName: name,
    explicitId: _firstNonEmptyString(<Object?>[raw['id'], raw['canonicalKey']]),
    ingredientMapper: ingredientMapper,
  );

  final image = _firstNonEmptyString(<Object?>[
    raw['image'],
    raw['imageUrl'],
    _buildTheCocktailDbIngredientImage(name),
  ]);

  final category = _firstNonEmptyString(<Object?>[
    raw['strType'],
    raw['type'],
    'Ингредиенты',
  ]);

  return ExternalIngredient(
    identity: CatalogIdentity(
      source: source,
      sourceId: sourceId,
      canonicalSlug: mappedKey,
    ),
    ingredient: Ingredient(
      id: mappedKey,
      name: name,
      category: category,
      image: image,
    ),
    aliases: <String>[
      if (name.isNotEmpty) name,
      _firstNonEmptyString(<Object?>[raw['strIngredient']]),
    ].where((alias) => alias.trim().isNotEmpty).toSet().toList(growable: false),
  );
}

ExternalCocktail normalizeTheCocktailDbCocktailRaw(
  Map<String, dynamic> raw, {
  required String source,
  required IngredientCanonicalMapper ingredientMapper,
  required Map<String, String> knownCocktailIdsByName,
  required Set<String> usedCocktailIds,
}) {
  final sourceId = _firstNonEmptyString(<Object?>[
    raw['idDrink'],
    raw['sourceId'],
  ]);
  final name = _firstNonEmptyString(<Object?>[
    raw['strDrink'],
    raw['name'],
    sourceId,
  ]);

  final ingredients = <String>[];
  final ingredientAmounts = <String, String>{};
  final ingredientUnits = <String, String>{};

  for (var index = 1; index <= 15; index++) {
    final ingredientName = _firstNonEmptyString(<Object?>[
      raw['strIngredient$index'],
    ]);
    if (ingredientName.isEmpty) {
      continue;
    }

    final ingredientId = _resolveIngredientCanonicalKey(
      ingredientName: ingredientName,
      explicitId: ingredientName,
      ingredientMapper: ingredientMapper,
    );
    if (ingredientId.isEmpty || ingredients.contains(ingredientId)) {
      continue;
    }

    ingredients.add(ingredientId);

    final measure = _firstNonEmptyString(<Object?>[raw['strMeasure$index']]);
    if (measure.isEmpty) {
      continue;
    }

    final parsedMeasure = _parseMeasure(measure);
    if (parsedMeasure.amount.isNotEmpty) {
      ingredientAmounts[ingredientId] = parsedMeasure.amount;
    }
    if (parsedMeasure.unit.isNotEmpty) {
      ingredientUnits[ingredientId] = parsedMeasure.unit;
    }
  }

  final instructions = _firstNonEmptyString(<Object?>[
    raw['strInstructionsRU'],
    raw['strInstructions'],
    raw['instructions'],
  ]);
  final preparationSteps = _normalizeInstructions(instructions);

  final category = _firstNonEmptyString(<Object?>[
    raw['strCategory'],
    raw['category'],
  ]);
  final alcoholic = _firstNonEmptyString(<Object?>[
    raw['strAlcoholic'],
    raw['alcoholic'],
  ]);

  final tags = _normalizeTheCocktailDbTags(
    category: category,
    alcoholic: alcoholic,
    tagsRaw: _firstNonEmptyString(<Object?>[raw['strTags'], raw['tags']]),
    glassRaw: _firstNonEmptyString(<Object?>[raw['strGlass'], raw['glass']]),
  );

  final canonicalCandidate =
      knownCocktailIdsByName[normalizeKey(name)] ??
      _firstNonEmptyString(<Object?>[raw['canonicalKey'], raw['id']]);
  final cocktailId = _resolveCocktailId(
    name: name,
    canonicalCandidate: canonicalCandidate,
    sourceId: sourceId,
    usedCocktailIds: usedCocktailIds,
  );

  return ExternalCocktail(
    identity: CatalogIdentity(
      source: source,
      sourceId: sourceId,
      canonicalSlug: cocktailId,
    ),
    cocktail: Cocktail(
      id: cocktailId,
      name: name,
      image: _firstNonEmptyString(<Object?>[
        raw['strDrinkThumb'],
        raw['image'],
        raw['imageUrl'],
      ]),
      ingredients: ingredients,
      description: instructions,
      preparationSteps: preparationSteps,
      glassType: _mapTheCocktailDbGlass(
        _firstNonEmptyString(<Object?>[raw['strGlass'], raw['glass']]),
      ),
      tags: tags,
      ingredientAmounts: ingredientAmounts,
      ingredientUnits: ingredientUnits,
      ingredientSubstitutions: const <String, List<String>>{},
      optionalIngredients: const <String>[],
      decorationIngredients: const <String>[],
    ),
  );
}

String _resolveIngredientCanonicalKey({
  required String ingredientName,
  required String explicitId,
  required IngredientCanonicalMapper ingredientMapper,
}) {
  final mapped =
      _theCocktailDbIngredientExplicitMap[normalizeKey(ingredientName)];
  if (mapped != null && mapped.isNotEmpty) {
    return mapped;
  }

  return ingredientMapper.resolve(
    explicitId: explicitId,
    displayName: ingredientName,
    aliases: const <String>[],
  );
}

String _resolveCocktailId({
  required String name,
  required String canonicalCandidate,
  required String sourceId,
  required Set<String> usedCocktailIds,
}) {
  var id = canonicalCandidate.trim();
  if (id.isEmpty) {
    id = slugify(name);
  }
  if (id.isEmpty) {
    id = 'cocktail-$sourceId';
  }

  if (!usedCocktailIds.add(id)) {
    id = '$id-$sourceId';
  }
  usedCocktailIds.add(id);

  return id;
}

List<String> _normalizeTheCocktailDbTags({
  required String category,
  required String alcoholic,
  required String tagsRaw,
  required String glassRaw,
}) {
  final normalized = <String>{};

  final categoryKey = normalizeKey(category);
  final alcoholicKey = normalizeKey(alcoholic);
  final glassKey = normalizeKey(glassRaw);

  if (categoryKey.contains('iba') || tagsRaw.toLowerCase().contains('iba')) {
    normalized.add('IBA');
  }
  if (categoryKey.contains('shot') || glassKey.contains('shot')) {
    normalized.add('Шоты');
  }
  if (categoryKey.contains('punch') ||
      categoryKey.contains('long') ||
      glassKey.contains('highball') ||
      glassKey.contains('collins')) {
    normalized.add('Лонги');
  }

  if (alcoholicKey.contains('non_alcoholic')) {
    normalized.add('Безалкогольные');
  } else if (alcoholicKey.contains('optional_alcohol')) {
    normalized.add('Мягкие');
  } else if (alcoholicKey.contains('alcoholic')) {
    if (categoryKey.contains('shot')) {
      normalized.add('Крепкие');
    } else {
      normalized.add('Средней крепости');
    }
  }

  if (normalized.isEmpty) {
    normalized.add(kUserCocktailTag);
  }

  final sorted = normalized.toList(growable: false)
    ..sort(
      (left, right) =>
          kCocktailTags.indexOf(left).compareTo(kCocktailTags.indexOf(right)),
    );
  return sorted;
}

String _mapTheCocktailDbGlass(String rawGlass) {
  final mapped = _theCocktailDbGlassMap[normalizeKey(rawGlass)];
  if (mapped != null &&
      mapped.isNotEmpty &&
      kCocktailGlassTypes.contains(mapped)) {
    return mapped;
  }

  return kDefaultCocktailGlassType;
}

List<String> _normalizeInstructions(String instructions) {
  final trimmed = instructions.trim();
  if (trimmed.isEmpty) {
    return const <String>['Смешайте ингредиенты и подавайте.'];
  }

  final steps = trimmed
      .split(RegExp(r'\r?\n|\.\s+'))
      .map((step) => step.trim())
      .where((step) => step.isNotEmpty)
      .toList(growable: false);

  if (steps.isEmpty) {
    return <String>[trimmed];
  }

  return steps;
}

_ParsedMeasure _parseMeasure(String source) {
  final value = source.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) {
    return const _ParsedMeasure(amount: '', unit: '');
  }

  final normalizedValueKey = normalizeKey(value);
  if (normalizedValueKey.contains('to_taste') ||
      normalizedValueKey.contains('po_vkusu')) {
    return const _ParsedMeasure(amount: '', unit: 'по вкусу');
  }

  final match = RegExp(r'^([\d\s/.,¼½¾⅓⅔-]+)\s*(.*)$').firstMatch(value);
  if (match == null) {
    // Keep qualitative directives as amount text so we do not lose source data.
    return _ParsedMeasure(amount: value, unit: '');
  }

  final amount = (match.group(1) ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  final unitRaw = (match.group(2) ?? '').trim();

  if (amount.isEmpty) {
    return _ParsedMeasure(amount: value, unit: '');
  }

  final unit = _normalizeMeasureUnit(unitRaw);
  if (unit.isEmpty && unitRaw.isNotEmpty) {
    // Unknown unit token: keep full string in amount to preserve semantics.
    return _ParsedMeasure(amount: value, unit: '');
  }

  return _ParsedMeasure(amount: amount, unit: unit);
}

String _normalizeMeasureUnit(String source) {
  final normalized = normalizeKey(source);
  if (normalized.isEmpty) {
    return '';
  }

  final direct = _measureUnitAliases[normalized];
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }

  for (final entry in _measureUnitPrefixAliases.entries) {
    if (normalized.startsWith(entry.key)) {
      return entry.value;
    }
  }

  return '';
}

String _buildTheCocktailDbIngredientImage(String ingredientName) {
  final trimmed = ingredientName.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final encoded = Uri.encodeComponent(trimmed);
  return 'https://www.thecocktaildb.com/images/ingredients/$encoded.png';
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

class _ParsedMeasure {
  const _ParsedMeasure({required this.amount, required this.unit});

  final String amount;
  final String unit;
}

const Map<String, String> _measureUnitAliases = <String, String>{
  'ml': 'мл',
  'milliliter': 'мл',
  'milliliters': 'мл',
  'millilitre': 'мл',
  'millilitres': 'мл',
  'мл': 'мл',
  'l': 'л',
  'liter': 'л',
  'liters': 'л',
  'litre': 'л',
  'litres': 'л',
  'л': 'л',
  'cl': 'cl',
  'oz': 'oz',
  'ounce': 'oz',
  'ounces': 'oz',
  'fl_oz': 'oz',
  'tsp': 'tsp',
  'teaspoon': 'tsp',
  'teaspoons': 'tsp',
  'tbsp': 'tbsp',
  'tblsp': 'tbsp',
  'tablespoon': 'tbsp',
  'tablespoons': 'tbsp',
  'shot': 'shot',
  'shots': 'shot',
  'part': 'part',
  'parts': 'part',
  'cup': 'cup',
  'cups': 'cup',
  'dash': 'dash',
  'dashes': 'dash',
  'drop': 'капля',
  'drops': 'капля',
  'pinch': 'pinch',
  'pinches': 'pinch',
  'slice': 'долька',
  'slices': 'долька',
  'wedge': 'долька',
  'wedges': 'долька',
  'piece': 'шт',
  'pieces': 'шт',
  'cube': 'шт',
  'cubes': 'шт',
  'chunk': 'шт',
  'chunks': 'шт',
  'sprig': 'шт',
  'sprigs': 'шт',
  'stick': 'шт',
  'sticks': 'шт',
  'bottle': 'шт',
  'can': 'шт',
  'glass': 'шт',
  'jigger': 'шт',
  'jiggers': 'шт',
};

const Map<String, String> _measureUnitPrefixAliases = <String, String>{
  'ml_': 'мл',
  'milliliter_': 'мл',
  'l_': 'л',
  'liter_': 'л',
  'cl_': 'cl',
  'oz_': 'oz',
  'ounce_': 'oz',
  'fl_oz_': 'oz',
  'tsp_': 'tsp',
  'teaspoon_': 'tsp',
  'tbsp_': 'tbsp',
  'tblsp_': 'tbsp',
  'tablespoon_': 'tbsp',
  'shot_': 'shot',
  'part_': 'part',
  'cup_': 'cup',
  'dash_': 'dash',
  'drop_': 'капля',
  'pinch_': 'pinch',
  'slice_': 'долька',
  'wedge_': 'долька',
  'piece_': 'шт',
  'cube_': 'шт',
  'chunk_': 'шт',
  'sprig_': 'шт',
  'stick_': 'шт',
  'bottle_': 'шт',
  'can_': 'шт',
  'glass_': 'шт',
  'jigger_': 'шт',
};

const Map<String, String> _theCocktailDbGlassMap = <String, String>{
  'cocktail_glass': 'Мартини',
  'martini_glass': 'Мартини',
  'highball_glass': 'Хайболл',
  'old_fashioned_glass': 'Рокс',
  'collins_glass': 'Коллинз',
  'champagne_flute': 'Фужер',
  'shot_glass': 'Шот',
  'hurricane_glass': 'Харрикейн',
  'margarita_glass': 'Маргарита',
  'wine_glass': 'Винный бокал',
  'irish_coffee_cup': 'Ирландский стакан',
  'pint_glass': 'Пинта',
  'pitcher': 'Питчер',
  'coffee_mug': 'Кружка',
  'mug': 'Кружка',
  'snifter': 'Кубок',
  'brandy_snifter': 'Кубок',
  'whiskey_sour_glass': 'Рокс',
  'coupe_glass': 'Бокал шале',
};

const Map<String, String> _theCocktailDbIngredientExplicitMap =
    <String, String>{
      'dark_rum': 'rum_dark',
      'white_rum': 'rum_light',
      'light_rum': 'rum_light',
      'gold_rum': 'rum_gold',
      'aged_rum': 'rum_gold',
      'blended_whiskey': 'whiskey',
      'scotch_whisky': 'scotch',
      'dry_vermouth': 'vermouth_dry',
      'sweet_vermouth': 'vermouth_red',
      'red_vermouth': 'vermouth_red',
      'white_vermouth': 'vermouth_white',
      'orange_bitters': 'orange_bitter',
      'angostura_bitters': 'angostura_bitter',
      'peychaud_bitters': 'peychauds_bitter',
      'orange_juice': 'juice_orange',
      'grapefruit_juice': 'juice_grapefruit',
      'pineapple_juice': 'juice_pineapple',
      'cranberry_juice': 'juice_cranberry',
      'apple_juice': 'juice_apple',
      'tomato_juice': 'juice_tomato',
      'pomegranate_juice': 'juice_pomegranate',
      'blood_orange_juice': 'juice_blood_orange',
      'olive_juice': 'juice_olive',
      'passion_fruit_juice': 'juice_passion_fruit',
      'papaya_juice': 'juice_papaya',
      'lemon_juice': 'lemon',
      'lime_juice': 'lime',
      'sugar_syrup': 'syrup_sugar',
      'simple_syrup': 'syrup_sugar',
      'maple_syrup': 'syrup_maple',
      'mint_syrup': 'syrup_mint',
      'honey_syrup': 'syrup_honey',
      'chocolate_syrup': 'syrup_chocolate',
      'coconut_syrup': 'syrup_coconut',
      'strawberry_syrup': 'syrup_strawberry',
      'raspberry_syrup': 'syrup_raspberry',
      'almond_syrup': 'syrup_almond',
      'ginger_syrup': 'syrup_gingerbread',
      'coffee_liqueur': 'coffee_liqueur',
      'mint_leaves': 'mint',
      'lemon_peel': 'lemon',
      'lemon_wedge': 'lemon',
      'lime_wedge': 'lime',
      'orange_peel': 'orange',
    };
