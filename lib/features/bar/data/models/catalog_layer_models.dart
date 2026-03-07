import 'package:flutter/foundation.dart';

import '../../domain/models/bar_catalog.dart';
import '../../domain/models/catalog_entity_origin.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../utils/catalog_id_utils.dart';

@immutable
class CatalogIdentity {
  const CatalogIdentity({
    required this.source,
    required this.sourceId,
    required this.canonicalSlug,
    this.localId,
  });

  factory CatalogIdentity.fromJson(Map<String, dynamic> json) {
    return CatalogIdentity(
      source: (json['source'] as String? ?? '').trim(),
      sourceId: (json['sourceId'] as String? ?? '').trim(),
      canonicalSlug: (json['canonicalSlug'] as String? ?? '').trim(),
      localId: (json['localId'] as String?)?.trim(),
    );
  }

  final String source;
  final String sourceId;
  final String canonicalSlug;
  final String? localId;

  String get unifiedKey =>
      buildDeterministicUnifiedKey(source: source, sourceId: sourceId);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source,
      'sourceId': sourceId,
      'canonicalSlug': canonicalSlug,
      if (localId != null && localId!.isNotEmpty) 'localId': localId,
    };
  }

  CatalogIdentity copyWith({
    String? source,
    String? sourceId,
    String? canonicalSlug,
    String? localId,
  }) {
    return CatalogIdentity(
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      canonicalSlug: canonicalSlug ?? this.canonicalSlug,
      localId: localId ?? this.localId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogIdentity &&
            other.source == source &&
            other.sourceId == sourceId &&
            other.canonicalSlug == canonicalSlug &&
            other.localId == localId;
  }

  @override
  int get hashCode => Object.hash(source, sourceId, canonicalSlug, localId);
}

@immutable
class ExternalIngredient {
  const ExternalIngredient({
    required this.identity,
    required this.ingredient,
    this.aliases = const <String>[],
  });

  factory ExternalIngredient.fromJson(Map<String, dynamic> json) {
    final aliasesJson = json['aliases'];
    final aliases = aliasesJson is List
        ? aliasesJson
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];

    return ExternalIngredient(
      identity: CatalogIdentity.fromJson(_castMap(json['identity'])),
      ingredient: Ingredient.fromJson(_castMap(json['ingredient'])),
      aliases: aliases,
    );
  }

  final CatalogIdentity identity;
  final Ingredient ingredient;
  final List<String> aliases;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'identity': identity.toJson(),
      'ingredient': ingredient.toJson(),
      'aliases': aliases,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExternalIngredient &&
            other.identity == identity &&
            other.ingredient == ingredient &&
            listEquals(other.aliases, aliases);
  }

  @override
  int get hashCode =>
      Object.hash(identity, ingredient, Object.hashAll(aliases));
}

@immutable
class ExternalCocktail {
  const ExternalCocktail({required this.identity, required this.cocktail});

  factory ExternalCocktail.fromJson(Map<String, dynamic> json) {
    return ExternalCocktail(
      identity: CatalogIdentity.fromJson(_castMap(json['identity'])),
      cocktail: Cocktail.fromJson(_castMap(json['cocktail'])),
    );
  }

  final CatalogIdentity identity;
  final Cocktail cocktail;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'identity': identity.toJson(),
      'cocktail': cocktail.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExternalCocktail &&
            other.identity == identity &&
            other.cocktail == cocktail;
  }

  @override
  int get hashCode => Object.hash(identity, cocktail);
}

@immutable
class LocalIngredient {
  const LocalIngredient({
    required this.localId,
    required this.canonicalSlug,
    required this.ingredient,
  });

  factory LocalIngredient.fromJson(Map<String, dynamic> json) {
    return LocalIngredient(
      localId: (json['localId'] as String? ?? '').trim(),
      canonicalSlug: (json['canonicalSlug'] as String? ?? '').trim(),
      ingredient: Ingredient.fromJson(_castMap(json['ingredient'])),
    );
  }

  final String localId;
  final String canonicalSlug;
  final Ingredient ingredient;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localId': localId,
      'canonicalSlug': canonicalSlug,
      'ingredient': ingredient.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocalIngredient &&
            other.localId == localId &&
            other.canonicalSlug == canonicalSlug &&
            other.ingredient == ingredient;
  }

  @override
  int get hashCode => Object.hash(localId, canonicalSlug, ingredient);
}

@immutable
class LocalCocktail {
  const LocalCocktail({
    required this.localId,
    required this.canonicalSlug,
    required this.cocktail,
  });

  factory LocalCocktail.fromJson(Map<String, dynamic> json) {
    return LocalCocktail(
      localId: (json['localId'] as String? ?? '').trim(),
      canonicalSlug: (json['canonicalSlug'] as String? ?? '').trim(),
      cocktail: Cocktail.fromJson(_castMap(json['cocktail'])),
    );
  }

  final String localId;
  final String canonicalSlug;
  final Cocktail cocktail;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localId': localId,
      'canonicalSlug': canonicalSlug,
      'cocktail': cocktail.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocalCocktail &&
            other.localId == localId &&
            other.canonicalSlug == canonicalSlug &&
            other.cocktail == cocktail;
  }

  @override
  int get hashCode => Object.hash(localId, canonicalSlug, cocktail);
}

@immutable
class IngredientPatch {
  const IngredientPatch({
    this.name,
    this.category,
    this.image,
    this.isDecoration,
    this.isOptional,
  });

  factory IngredientPatch.fromJson(Map<String, dynamic> json) {
    return IngredientPatch(
      name: (json['name'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim(),
      image: (json['image'] as String?)?.trim(),
      isDecoration: json['isDecoration'] is bool
          ? json['isDecoration'] as bool
          : null,
      isOptional: json['isOptional'] is bool
          ? json['isOptional'] as bool
          : null,
    );
  }

  factory IngredientPatch.fromDiff({
    required Ingredient baseline,
    required Ingredient updated,
  }) {
    return IngredientPatch(
      name: baseline.name == updated.name ? null : updated.name,
      category: baseline.category == updated.category ? null : updated.category,
      image: baseline.image == updated.image ? null : updated.image,
      isDecoration: baseline.isDecoration == updated.isDecoration
          ? null
          : updated.isDecoration,
      isOptional: baseline.isOptional == updated.isOptional
          ? null
          : updated.isOptional,
    );
  }

  final String? name;
  final String? category;
  final String? image;
  final bool? isDecoration;
  final bool? isOptional;

  bool get isEmpty {
    return name == null &&
        category == null &&
        image == null &&
        isDecoration == null &&
        isOptional == null;
  }

  Ingredient applyTo(Ingredient baseline) {
    return Ingredient(
      id: baseline.id,
      name: name ?? baseline.name,
      category: category ?? baseline.category,
      image: image ?? baseline.image,
      isDecoration: isDecoration ?? baseline.isDecoration,
      isOptional: isOptional ?? baseline.isOptional,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (image != null) 'image': image,
      if (isDecoration != null) 'isDecoration': isDecoration,
      if (isOptional != null) 'isOptional': isOptional,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is IngredientPatch &&
            other.name == name &&
            other.category == category &&
            other.image == image &&
            other.isDecoration == isDecoration &&
            other.isOptional == isOptional;
  }

  @override
  int get hashCode =>
      Object.hash(name, category, image, isDecoration, isOptional);
}

@immutable
class CocktailPatch {
  const CocktailPatch({
    this.name,
    this.image,
    this.ingredients,
    this.description,
    this.preparationSteps,
    this.glassType,
    this.tags,
    this.ingredientSubstitutions,
    this.ingredientAmounts,
    this.ingredientUnits,
    this.optionalIngredients,
    this.decorationIngredients,
    this.isFavorite,
  });

  factory CocktailPatch.fromJson(Map<String, dynamic> json) {
    return CocktailPatch(
      name: (json['name'] as String?)?.trim(),
      image: (json['image'] as String?)?.trim(),
      ingredients: _parseStringList(json['ingredients']),
      description: (json['description'] as String?)?.trim(),
      preparationSteps: _parseStringList(json['preparationSteps']),
      glassType: (json['glassType'] as String?)?.trim(),
      tags: _parseStringList(json['tags']),
      ingredientSubstitutions: _parseSubstitutionsMap(
        json['ingredientSubstitutions'],
      ),
      ingredientAmounts: _parseStringMap(json['ingredientAmounts']),
      ingredientUnits: _parseStringMap(json['ingredientUnits']),
      optionalIngredients: _parseStringList(json['optionalIngredients']),
      decorationIngredients: _parseStringList(json['decorationIngredients']),
      isFavorite: json['isFavorite'] is bool
          ? json['isFavorite'] as bool
          : null,
    );
  }

  factory CocktailPatch.fromDiff({
    required Cocktail baseline,
    required Cocktail updated,
  }) {
    return CocktailPatch(
      name: baseline.name == updated.name ? null : updated.name,
      image: baseline.image == updated.image ? null : updated.image,
      ingredients: listEquals(baseline.ingredients, updated.ingredients)
          ? null
          : updated.ingredients,
      description: baseline.description == updated.description
          ? null
          : updated.description,
      preparationSteps:
          listEquals(baseline.preparationSteps, updated.preparationSteps)
          ? null
          : updated.preparationSteps,
      glassType: baseline.glassType == updated.glassType
          ? null
          : updated.glassType,
      tags: listEquals(baseline.tags, updated.tags) ? null : updated.tags,
      ingredientSubstitutions:
          _substitutionsEqual(
            baseline.ingredientSubstitutions,
            updated.ingredientSubstitutions,
          )
          ? null
          : updated.ingredientSubstitutions,
      ingredientAmounts:
          mapEquals(baseline.ingredientAmounts, updated.ingredientAmounts)
          ? null
          : updated.ingredientAmounts,
      ingredientUnits:
          mapEquals(baseline.ingredientUnits, updated.ingredientUnits)
          ? null
          : updated.ingredientUnits,
      optionalIngredients:
          listEquals(baseline.optionalIngredients, updated.optionalIngredients)
          ? null
          : updated.optionalIngredients,
      decorationIngredients:
          listEquals(
            baseline.decorationIngredients,
            updated.decorationIngredients,
          )
          ? null
          : updated.decorationIngredients,
      isFavorite: baseline.isFavorite == updated.isFavorite
          ? null
          : updated.isFavorite,
    );
  }

  final String? name;
  final String? image;
  final List<String>? ingredients;
  final String? description;
  final List<String>? preparationSteps;
  final String? glassType;
  final List<String>? tags;
  final Map<String, List<String>>? ingredientSubstitutions;
  final Map<String, String>? ingredientAmounts;
  final Map<String, String>? ingredientUnits;
  final List<String>? optionalIngredients;
  final List<String>? decorationIngredients;
  final bool? isFavorite;

  bool get isEmpty {
    return name == null &&
        image == null &&
        ingredients == null &&
        description == null &&
        preparationSteps == null &&
        glassType == null &&
        tags == null &&
        ingredientSubstitutions == null &&
        ingredientAmounts == null &&
        ingredientUnits == null &&
        optionalIngredients == null &&
        decorationIngredients == null &&
        isFavorite == null;
  }

  Cocktail applyTo(Cocktail baseline) {
    return Cocktail(
      id: baseline.id,
      name: name ?? baseline.name,
      image: image ?? baseline.image,
      ingredients: ingredients ?? baseline.ingredients,
      description: description ?? baseline.description,
      preparationSteps: preparationSteps ?? baseline.preparationSteps,
      glassType: glassType ?? baseline.glassType,
      tags: tags ?? baseline.tags,
      ingredientSubstitutions:
          ingredientSubstitutions ?? baseline.ingredientSubstitutions,
      ingredientAmounts: ingredientAmounts ?? baseline.ingredientAmounts,
      ingredientUnits: ingredientUnits ?? baseline.ingredientUnits,
      optionalIngredients: optionalIngredients ?? baseline.optionalIngredients,
      decorationIngredients:
          decorationIngredients ?? baseline.decorationIngredients,
      isFavorite: isFavorite ?? baseline.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (image != null) 'image': image,
      if (ingredients != null) 'ingredients': ingredients,
      if (description != null) 'description': description,
      if (preparationSteps != null) 'preparationSteps': preparationSteps,
      if (glassType != null) 'glassType': glassType,
      if (tags != null) 'tags': tags,
      if (ingredientSubstitutions != null)
        'ingredientSubstitutions': ingredientSubstitutions,
      if (ingredientAmounts != null) 'ingredientAmounts': ingredientAmounts,
      if (ingredientUnits != null) 'ingredientUnits': ingredientUnits,
      if (optionalIngredients != null)
        'optionalIngredients': optionalIngredients,
      if (decorationIngredients != null)
        'decorationIngredients': decorationIngredients,
      if (isFavorite != null) 'isFavorite': isFavorite,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CocktailPatch &&
            other.name == name &&
            other.image == image &&
            listEquals(other.ingredients, ingredients) &&
            other.description == description &&
            listEquals(other.preparationSteps, preparationSteps) &&
            other.glassType == glassType &&
            listEquals(other.tags, tags) &&
            _substitutionsEqual(
              other.ingredientSubstitutions,
              ingredientSubstitutions,
            ) &&
            mapEquals(other.ingredientAmounts, ingredientAmounts) &&
            mapEquals(other.ingredientUnits, ingredientUnits) &&
            listEquals(other.optionalIngredients, optionalIngredients) &&
            listEquals(other.decorationIngredients, decorationIngredients) &&
            other.isFavorite == isFavorite;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      image,
      Object.hashAll(ingredients ?? const <String>[]),
      description,
      Object.hashAll(preparationSteps ?? const <String>[]),
      glassType,
      Object.hashAll(tags ?? const <String>[]),
      Object.hashAll(_substitutionHashEntries(ingredientSubstitutions)),
      Object.hashAll(_stringMapHashEntries(ingredientAmounts)),
      Object.hashAll(_stringMapHashEntries(ingredientUnits)),
      Object.hashAll(optionalIngredients ?? const <String>[]),
      Object.hashAll(decorationIngredients ?? const <String>[]),
      isFavorite,
    );
  }
}

@immutable
class IngredientOverride {
  const IngredientOverride({
    required this.source,
    required this.sourceId,
    this.patch = const IngredientPatch(),
    this.isHidden = false,
  });

  factory IngredientOverride.fromJson(Map<String, dynamic> json) {
    return IngredientOverride(
      source: (json['source'] as String? ?? '').trim(),
      sourceId: (json['sourceId'] as String? ?? '').trim(),
      patch: IngredientPatch.fromJson(_castMap(json['patch'] ?? const {})),
      isHidden: json['isHidden'] is bool ? json['isHidden'] as bool : false,
    );
  }

  final String source;
  final String sourceId;
  final IngredientPatch patch;
  final bool isHidden;

  String get key =>
      buildDeterministicUnifiedKey(source: source, sourceId: sourceId);

  bool get isEmpty => !isHidden && patch.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source,
      'sourceId': sourceId,
      'patch': patch.toJson(),
      'isHidden': isHidden,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is IngredientOverride &&
            other.source == source &&
            other.sourceId == sourceId &&
            other.patch == patch &&
            other.isHidden == isHidden;
  }

  @override
  int get hashCode => Object.hash(source, sourceId, patch, isHidden);
}

@immutable
class CocktailOverride {
  const CocktailOverride({
    required this.source,
    required this.sourceId,
    this.patch = const CocktailPatch(),
    this.isHidden = false,
  });

  factory CocktailOverride.fromJson(Map<String, dynamic> json) {
    return CocktailOverride(
      source: (json['source'] as String? ?? '').trim(),
      sourceId: (json['sourceId'] as String? ?? '').trim(),
      patch: CocktailPatch.fromJson(_castMap(json['patch'] ?? const {})),
      isHidden: json['isHidden'] is bool ? json['isHidden'] as bool : false,
    );
  }

  final String source;
  final String sourceId;
  final CocktailPatch patch;
  final bool isHidden;

  String get key =>
      buildDeterministicUnifiedKey(source: source, sourceId: sourceId);

  bool get isEmpty => !isHidden && patch.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source,
      'sourceId': sourceId,
      'patch': patch.toJson(),
      'isHidden': isHidden,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CocktailOverride &&
            other.source == source &&
            other.sourceId == sourceId &&
            other.patch == patch &&
            other.isHidden == isHidden;
  }

  @override
  int get hashCode => Object.hash(source, sourceId, patch, isHidden);
}

@immutable
class UnifiedIngredient {
  const UnifiedIngredient({
    required this.identity,
    required this.origin,
    required this.ingredient,
  });

  final CatalogIdentity identity;
  final CatalogEntityOrigin origin;
  final Ingredient ingredient;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UnifiedIngredient &&
            other.identity == identity &&
            other.origin == origin &&
            other.ingredient == ingredient;
  }

  @override
  int get hashCode => Object.hash(identity, origin, ingredient);
}

@immutable
class UnifiedCocktail {
  const UnifiedCocktail({
    required this.identity,
    required this.origin,
    required this.cocktail,
  });

  final CatalogIdentity identity;
  final CatalogEntityOrigin origin;
  final Cocktail cocktail;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UnifiedCocktail &&
            other.identity == identity &&
            other.origin == origin &&
            other.cocktail == cocktail;
  }

  @override
  int get hashCode => Object.hash(identity, origin, cocktail);
}

@immutable
class UnifiedCatalogSnapshot {
  UnifiedCatalogSnapshot({
    required List<UnifiedIngredient> ingredients,
    required List<UnifiedCocktail> cocktails,
    required this.externalSourceAvailable,
  }) : ingredients = List<UnifiedIngredient>.unmodifiable(ingredients),
       cocktails = List<UnifiedCocktail>.unmodifiable(cocktails);

  final List<UnifiedIngredient> ingredients;
  final List<UnifiedCocktail> cocktails;
  final bool externalSourceAvailable;

  List<Ingredient> get ingredientItems {
    return ingredients.map((item) => item.ingredient).toList(growable: false);
  }

  List<Cocktail> get cocktailItems {
    return cocktails.map((item) => item.cocktail).toList(growable: false);
  }

  Map<String, CatalogEntityOrigin> get ingredientOrigins {
    return <String, CatalogEntityOrigin>{
      for (final item in ingredients) item.ingredient.id: item.origin,
    };
  }

  Map<String, CatalogEntityOrigin> get cocktailOrigins {
    return <String, CatalogEntityOrigin>{
      for (final item in cocktails) item.cocktail.id: item.origin,
    };
  }

  Map<String, CatalogIdentity> get ingredientIdentities {
    return <String, CatalogIdentity>{
      for (final item in ingredients) item.ingredient.id: item.identity,
    };
  }

  Map<String, CatalogIdentity> get cocktailIdentities {
    return <String, CatalogIdentity>{
      for (final item in cocktails) item.cocktail.id: item.identity,
    };
  }

  BarCatalog toCatalog() {
    return BarCatalog(ingredients: ingredientItems, cocktails: cocktailItems);
  }
}

@immutable
class LocalCatalogData {
  LocalCatalogData({
    required List<LocalIngredient> ingredients,
    required List<LocalCocktail> cocktails,
  }) : ingredients = List<LocalIngredient>.unmodifiable(ingredients),
       cocktails = List<LocalCocktail>.unmodifiable(cocktails);

  factory LocalCatalogData.empty() {
    return LocalCatalogData(
      ingredients: const <LocalIngredient>[],
      cocktails: const <LocalCocktail>[],
    );
  }

  factory LocalCatalogData.fromJson(Map<String, dynamic> json) {
    final ingredientsJson = json['ingredients'];
    final cocktailsJson = json['cocktails'];

    final ingredients = ingredientsJson is List
        ? ingredientsJson
              .map((item) => LocalIngredient.fromJson(_castMap(item)))
              .toList(growable: false)
        : const <LocalIngredient>[];
    final cocktails = cocktailsJson is List
        ? cocktailsJson
              .map((item) => LocalCocktail.fromJson(_castMap(item)))
              .toList(growable: false)
        : const <LocalCocktail>[];

    return LocalCatalogData(ingredients: ingredients, cocktails: cocktails);
  }

  final List<LocalIngredient> ingredients;
  final List<LocalCocktail> cocktails;

  bool get isEmpty => ingredients.isEmpty && cocktails.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
      'cocktails': cocktails.map((item) => item.toJson()).toList(),
    };
  }

  LocalCatalogData copyWith({
    List<LocalIngredient>? ingredients,
    List<LocalCocktail>? cocktails,
  }) {
    return LocalCatalogData(
      ingredients: ingredients ?? this.ingredients,
      cocktails: cocktails ?? this.cocktails,
    );
  }
}

@immutable
class OverridesCatalogData {
  OverridesCatalogData({
    required List<IngredientOverride> ingredientOverrides,
    required List<CocktailOverride> cocktailOverrides,
  }) : ingredientOverrides = List<IngredientOverride>.unmodifiable(
         ingredientOverrides,
       ),
       cocktailOverrides = List<CocktailOverride>.unmodifiable(
         cocktailOverrides,
       );

  factory OverridesCatalogData.empty() {
    return OverridesCatalogData(
      ingredientOverrides: const <IngredientOverride>[],
      cocktailOverrides: const <CocktailOverride>[],
    );
  }

  factory OverridesCatalogData.fromJson(Map<String, dynamic> json) {
    final ingredientJson = json['ingredientOverrides'];
    final cocktailJson = json['cocktailOverrides'];

    final ingredientOverrides = ingredientJson is List
        ? ingredientJson
              .map((item) => IngredientOverride.fromJson(_castMap(item)))
              .toList(growable: false)
        : const <IngredientOverride>[];
    final cocktailOverrides = cocktailJson is List
        ? cocktailJson
              .map((item) => CocktailOverride.fromJson(_castMap(item)))
              .toList(growable: false)
        : const <CocktailOverride>[];

    return OverridesCatalogData(
      ingredientOverrides: ingredientOverrides,
      cocktailOverrides: cocktailOverrides,
    );
  }

  final List<IngredientOverride> ingredientOverrides;
  final List<CocktailOverride> cocktailOverrides;

  bool get isEmpty => ingredientOverrides.isEmpty && cocktailOverrides.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ingredientOverrides': ingredientOverrides
          .map((item) => item.toJson())
          .toList(),
      'cocktailOverrides': cocktailOverrides
          .map((item) => item.toJson())
          .toList(),
    };
  }

  OverridesCatalogData copyWith({
    List<IngredientOverride>? ingredientOverrides,
    List<CocktailOverride>? cocktailOverrides,
  }) {
    return OverridesCatalogData(
      ingredientOverrides: ingredientOverrides ?? this.ingredientOverrides,
      cocktailOverrides: cocktailOverrides ?? this.cocktailOverrides,
    );
  }
}

@immutable
class ExternalCatalogData {
  ExternalCatalogData({
    required this.source,
    required this.fetchedAt,
    required List<ExternalIngredient> ingredients,
    required List<ExternalCocktail> cocktails,
  }) : ingredients = List<ExternalIngredient>.unmodifiable(ingredients),
       cocktails = List<ExternalCocktail>.unmodifiable(cocktails);

  factory ExternalCatalogData.empty({required String source}) {
    return ExternalCatalogData(
      source: source,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ingredients: const <ExternalIngredient>[],
      cocktails: const <ExternalCocktail>[],
    );
  }

  factory ExternalCatalogData.fromJson(Map<String, dynamic> json) {
    final ingredientsJson = json['ingredients'];
    final cocktailsJson = json['cocktails'];

    final ingredients = ingredientsJson is List
        ? ingredientsJson
              .map((item) => ExternalIngredient.fromJson(_castMap(item)))
              .toList(growable: false)
        : const <ExternalIngredient>[];
    final cocktails = cocktailsJson is List
        ? cocktailsJson
              .map((item) => ExternalCocktail.fromJson(_castMap(item)))
              .toList(growable: false)
        : const <ExternalCocktail>[];

    return ExternalCatalogData(
      source: (json['source'] as String? ?? '').trim(),
      fetchedAt:
          DateTime.tryParse((json['fetchedAt'] as String? ?? '').trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ingredients: ingredients,
      cocktails: cocktails,
    );
  }

  final String source;
  final DateTime fetchedAt;
  final List<ExternalIngredient> ingredients;
  final List<ExternalCocktail> cocktails;

  bool get isEmpty => ingredients.isEmpty && cocktails.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source,
      'fetchedAt': fetchedAt.toIso8601String(),
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
      'cocktails': cocktails.map((item) => item.toJson()).toList(),
    };
  }
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

List<String>? _parseStringList(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    return const <String>[];
  }
  final normalized = value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return normalized;
}

Map<String, String>? _parseStringMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    return const <String, String>{};
  }

  final map = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final item = entry.value.toString().trim();
    if (key.isEmpty || item.isEmpty) {
      continue;
    }
    map[key] = item;
  }
  return map;
}

Map<String, List<String>>? _parseSubstitutionsMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    return const <String, List<String>>{};
  }

  final result = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) {
      continue;
    }
    final itemValue = entry.value;
    if (itemValue is! List) {
      continue;
    }
    final substitutions = itemValue
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (substitutions.isEmpty) {
      continue;
    }
    result[key] = substitutions;
  }
  return result;
}

bool _substitutionsEqual(
  Map<String, List<String>>? left,
  Map<String, List<String>>? right,
) {
  final normalizedLeft = left ?? const <String, List<String>>{};
  final normalizedRight = right ?? const <String, List<String>>{};
  if (normalizedLeft.length != normalizedRight.length) {
    return false;
  }

  for (final entry in normalizedLeft.entries) {
    final rightValue = normalizedRight[entry.key];
    if (rightValue == null || !listEquals(entry.value, rightValue)) {
      return false;
    }
  }

  return true;
}

Iterable<Object> _substitutionHashEntries(
  Map<String, List<String>>? source,
) sync* {
  final substitutions = source ?? const <String, List<String>>{};
  final keys = substitutions.keys.toList(growable: false)..sort();
  for (final key in keys) {
    final items = substitutions[key] ?? const <String>[];
    yield Object.hash(key, Object.hashAll(items));
  }
}

Iterable<Object> _stringMapHashEntries(Map<String, String>? source) sync* {
  final values = source ?? const <String, String>{};
  final keys = values.keys.toList(growable: false)..sort();
  for (final key in keys) {
    yield Object.hash(key, values[key]);
  }
}
