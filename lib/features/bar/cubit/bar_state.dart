import 'package:flutter/foundation.dart';

import '../../../core/localization/app_language.dart';
import '../domain/models/bar_catalog.dart';
import '../domain/models/catalog_data_source.dart';
import '../domain/models/catalog_entity_origin.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/ingredient.dart';
import '../domain/models/measurement_system.dart';

@immutable
class BarState {
  BarState({
    required List<Ingredient> ingredients,
    required List<Cocktail> cocktails,
    Set<String> selectedIngredientIds = const <String>{},
    Set<String> shoppingIngredientIds = const <String>{},
    Map<String, CatalogEntityOrigin> ingredientOrigins =
        const <String, CatalogEntityOrigin>{},
    Map<String, CatalogEntityOrigin> cocktailOrigins =
        const <String, CatalogEntityOrigin>{},
    this.catalogDataSource = CatalogDataSource.seed,
    this.isTheCocktailDbAvailable = false,
    this.externalSourceAvailable = false,
    this.visitorMode = false,
    this.barMenuOnlyMode = false,
    this.powerSavingMode = false,
    this.systemPowerSavingMode = false,
    this.appLanguage = AppLanguage.system,
    this.measurementSystem = MeasurementSystem.flOz,
  }) : ingredients = List<Ingredient>.unmodifiable(ingredients),
       cocktails = List<Cocktail>.unmodifiable(cocktails),
       selectedIngredientIds = Set<String>.unmodifiable(selectedIngredientIds),
       shoppingIngredientIds = Set<String>.unmodifiable(shoppingIngredientIds),
       ingredientOrigins = Map<String, CatalogEntityOrigin>.unmodifiable(
         ingredientOrigins,
       ),
       cocktailOrigins = Map<String, CatalogEntityOrigin>.unmodifiable(
         cocktailOrigins,
       );

  final List<Ingredient> ingredients;
  final List<Cocktail> cocktails;
  final Set<String> selectedIngredientIds;
  final Set<String> shoppingIngredientIds;
  final Map<String, CatalogEntityOrigin> ingredientOrigins;
  final Map<String, CatalogEntityOrigin> cocktailOrigins;
  final CatalogDataSource catalogDataSource;
  final bool isTheCocktailDbAvailable;
  final bool externalSourceAvailable;
  final bool visitorMode;
  final bool barMenuOnlyMode;
  final bool powerSavingMode;
  final bool systemPowerSavingMode;
  final AppLanguage appLanguage;
  final MeasurementSystem measurementSystem;

  bool get effectivePowerSavingMode => powerSavingMode || systemPowerSavingMode;

  Map<String, Ingredient> get ingredientsById {
    return <String, Ingredient>{
      for (final ingredient in ingredients) ingredient.id: ingredient,
    };
  }

  Set<String> get ingredientIds => ingredientsById.keys.toSet();

  List<Cocktail> get availableCocktails {
    final ingredientMap = ingredientsById;
    return cocktails
        .where(
          (cocktail) => _isCocktailAvailable(
            cocktail: cocktail,
            availableIngredientIds: selectedIngredientIds,
            ingredientMap: ingredientMap,
          ),
        )
        .toList(growable: false);
  }

  bool isCocktailAvailable(
    Cocktail cocktail, {
    Set<String>? availableIngredientIds,
  }) {
    return _isCocktailAvailable(
      cocktail: cocktail,
      availableIngredientIds: availableIngredientIds ?? selectedIngredientIds,
      ingredientMap: ingredientsById,
    );
  }

  bool _isCocktailAvailable({
    required Cocktail cocktail,
    required Set<String> availableIngredientIds,
    required Map<String, Ingredient> ingredientMap,
  }) {
    return cocktail.ingredients.every((ingredientId) {
      if (availableIngredientIds.contains(ingredientId)) {
        return true;
      }
      final substitutions =
          cocktail.ingredientSubstitutions[ingredientId] ?? const <String>[];
      if (substitutions.any(availableIngredientIds.contains)) {
        return true;
      }
      if (cocktail.isIngredientOptional(ingredientId) ||
          cocktail.isIngredientDecoration(ingredientId)) {
        return true;
      }
      final ingredient = ingredientMap[ingredientId];
      return ingredient?.isOptional == true || ingredient?.isDecoration == true;
    });
  }

  Set<String> missingIngredientIdsFor(Cocktail cocktail) {
    final missing = <String>{};
    final ingredientMap = ingredientsById;
    for (final ingredientId in cocktail.ingredients) {
      if (selectedIngredientIds.contains(ingredientId)) {
        continue;
      }
      final substitutions =
          cocktail.ingredientSubstitutions[ingredientId] ?? const <String>[];
      if (substitutions.any(selectedIngredientIds.contains)) {
        continue;
      }
      if (cocktail.isIngredientOptional(ingredientId) ||
          cocktail.isIngredientDecoration(ingredientId)) {
        continue;
      }
      final ingredient = ingredientMap[ingredientId];
      if (ingredient?.isOptional == true || ingredient?.isDecoration == true) {
        continue;
      }
      missing.add(ingredientId);
    }
    return missing;
  }

  int cocktailsUnlockedByAdding(String ingredientId) {
    return unlockCountsByIngredientId[ingredientId] ?? 0;
  }

  int favoriteCocktailsUnlockedByAdding(String ingredientId) {
    return favoriteUnlockCountsByIngredientId[ingredientId] ?? 0;
  }

  Map<String, int> get unlockCountsByIngredientId {
    return _buildUnlockCounts(favoritesOnly: false);
  }

  Map<String, int> get favoriteUnlockCountsByIngredientId {
    return _buildUnlockCounts(favoritesOnly: true);
  }

  Map<String, int> _buildUnlockCounts({required bool favoritesOnly}) {
    final knownIngredientIds = ingredientIds;
    final ingredientMap = ingredientsById;
    final counts = <String, int>{
      for (final id in knownIngredientIds)
        if (!selectedIngredientIds.contains(id)) id: 0,
    };

    for (final cocktail in cocktails) {
      if (favoritesOnly && !cocktail.isFavorite) {
        continue;
      }
      Set<String>? candidates;
      var alreadyAvailable = true;

      for (final ingredientId in cocktail.ingredients) {
        if (selectedIngredientIds.contains(ingredientId)) {
          continue;
        }
        final substitutions =
            cocktail.ingredientSubstitutions[ingredientId] ?? const <String>[];
        if (substitutions.any(selectedIngredientIds.contains)) {
          continue;
        }
        if (cocktail.isIngredientOptional(ingredientId) ||
            cocktail.isIngredientDecoration(ingredientId)) {
          continue;
        }
        final ingredient = ingredientMap[ingredientId];
        if (ingredient?.isOptional == true ||
            ingredient?.isDecoration == true) {
          continue;
        }

        alreadyAvailable = false;
        final slotCandidates = <String>{ingredientId, ...substitutions}
          ..retainWhere(
            (id) =>
                knownIngredientIds.contains(id) &&
                !selectedIngredientIds.contains(id),
          );
        candidates = candidates == null
            ? slotCandidates
            : candidates.intersection(slotCandidates);
        if (candidates.isEmpty) {
          break;
        }
      }

      if (alreadyAvailable || candidates == null) {
        continue;
      }
      for (final candidate in candidates) {
        counts[candidate] = (counts[candidate] ?? 0) + 1;
      }
    }
    return counts;
  }

  BarCatalog get catalog {
    return BarCatalog(ingredients: ingredients, cocktails: cocktails);
  }

  BarState copyWith({
    List<Ingredient>? ingredients,
    List<Cocktail>? cocktails,
    Set<String>? selectedIngredientIds,
    Set<String>? shoppingIngredientIds,
    Map<String, CatalogEntityOrigin>? ingredientOrigins,
    Map<String, CatalogEntityOrigin>? cocktailOrigins,
    CatalogDataSource? catalogDataSource,
    bool? isTheCocktailDbAvailable,
    bool? externalSourceAvailable,
    bool? visitorMode,
    bool? barMenuOnlyMode,
    bool? powerSavingMode,
    bool? systemPowerSavingMode,
    AppLanguage? appLanguage,
    MeasurementSystem? measurementSystem,
  }) {
    return BarState(
      ingredients: ingredients ?? this.ingredients,
      cocktails: cocktails ?? this.cocktails,
      selectedIngredientIds:
          selectedIngredientIds ?? this.selectedIngredientIds,
      shoppingIngredientIds:
          shoppingIngredientIds ?? this.shoppingIngredientIds,
      ingredientOrigins: ingredientOrigins ?? this.ingredientOrigins,
      cocktailOrigins: cocktailOrigins ?? this.cocktailOrigins,
      catalogDataSource: catalogDataSource ?? this.catalogDataSource,
      isTheCocktailDbAvailable:
          isTheCocktailDbAvailable ?? this.isTheCocktailDbAvailable,
      externalSourceAvailable:
          externalSourceAvailable ?? this.externalSourceAvailable,
      visitorMode: visitorMode ?? this.visitorMode,
      barMenuOnlyMode: barMenuOnlyMode ?? this.barMenuOnlyMode,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
      systemPowerSavingMode:
          systemPowerSavingMode ?? this.systemPowerSavingMode,
      appLanguage: appLanguage ?? this.appLanguage,
      measurementSystem: measurementSystem ?? this.measurementSystem,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BarState &&
            listEquals(other.ingredients, ingredients) &&
            listEquals(other.cocktails, cocktails) &&
            setEquals(other.selectedIngredientIds, selectedIngredientIds) &&
            setEquals(other.shoppingIngredientIds, shoppingIngredientIds) &&
            mapEquals(other.ingredientOrigins, ingredientOrigins) &&
            mapEquals(other.cocktailOrigins, cocktailOrigins) &&
            other.catalogDataSource == catalogDataSource &&
            other.isTheCocktailDbAvailable == isTheCocktailDbAvailable &&
            other.externalSourceAvailable == externalSourceAvailable &&
            other.visitorMode == visitorMode &&
            other.barMenuOnlyMode == barMenuOnlyMode &&
            other.powerSavingMode == powerSavingMode &&
            other.systemPowerSavingMode == systemPowerSavingMode &&
            other.appLanguage == appLanguage &&
            other.measurementSystem == measurementSystem;
  }

  @override
  int get hashCode {
    final selectedIds = selectedIngredientIds.toList()..sort();
    final shoppingIds = shoppingIngredientIds.toList()..sort();
    return Object.hash(
      Object.hashAll(ingredients),
      Object.hashAll(cocktails),
      Object.hashAll(selectedIds),
      Object.hashAll(shoppingIds),
      Object.hashAll(ingredientOrigins.entries),
      Object.hashAll(cocktailOrigins.entries),
      catalogDataSource,
      isTheCocktailDbAvailable,
      externalSourceAvailable,
      visitorMode,
      barMenuOnlyMode,
      powerSavingMode,
      systemPowerSavingMode,
      appLanguage,
      measurementSystem,
    );
  }
}
