import 'package:flutter/foundation.dart';

import '../domain/models/bar_catalog.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/ingredient.dart';

@immutable
class BarState {
  BarState({
    required List<Ingredient> ingredients,
    required List<Cocktail> cocktails,
    Set<String> selectedIngredientIds = const <String>{},
  }) : ingredients = List<Ingredient>.unmodifiable(ingredients),
       cocktails = List<Cocktail>.unmodifiable(cocktails),
       selectedIngredientIds = Set<String>.unmodifiable(selectedIngredientIds);

  final List<Ingredient> ingredients;
  final List<Cocktail> cocktails;
  final Set<String> selectedIngredientIds;

  Map<String, Ingredient> get ingredientsById {
    return <String, Ingredient>{
      for (final ingredient in ingredients) ingredient.id: ingredient,
    };
  }

  Set<String> get ingredientIds => ingredientsById.keys.toSet();

  List<Cocktail> get availableCocktails {
    return cocktails
        .where((cocktail) {
          return cocktail.ingredients.every((ingredientId) {
            if (selectedIngredientIds.contains(ingredientId)) {
              return true;
            }
            final substitutions =
                cocktail.ingredientSubstitutions[ingredientId] ??
                const <String>[];
            if (substitutions.any(selectedIngredientIds.contains)) {
              return true;
            }
            if (cocktail.isIngredientOptional(ingredientId) ||
                cocktail.isIngredientDecoration(ingredientId)) {
              return true;
            }
            final ingredient = ingredientsById[ingredientId];
            if (ingredient == null) {
              return false;
            }
            return ingredient.isOptional || ingredient.isDecoration;
          });
        })
        .toList(growable: false);
  }

  BarCatalog get catalog {
    return BarCatalog(ingredients: ingredients, cocktails: cocktails);
  }

  BarState copyWith({
    List<Ingredient>? ingredients,
    List<Cocktail>? cocktails,
    Set<String>? selectedIngredientIds,
  }) {
    return BarState(
      ingredients: ingredients ?? this.ingredients,
      cocktails: cocktails ?? this.cocktails,
      selectedIngredientIds:
          selectedIngredientIds ?? this.selectedIngredientIds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BarState &&
            listEquals(other.ingredients, ingredients) &&
            listEquals(other.cocktails, cocktails) &&
            setEquals(other.selectedIngredientIds, selectedIngredientIds);
  }

  @override
  int get hashCode {
    final selectedIds = selectedIngredientIds.toList()..sort();
    return Object.hash(
      Object.hashAll(ingredients),
      Object.hashAll(cocktails),
      Object.hashAll(selectedIds),
    );
  }
}
