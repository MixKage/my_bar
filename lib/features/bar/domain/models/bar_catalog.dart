import 'package:flutter/foundation.dart';

import 'cocktail.dart';
import 'ingredient.dart';

@immutable
class BarCatalog {
  BarCatalog({
    required List<Ingredient> ingredients,
    required List<Cocktail> cocktails,
  }) : ingredients = List<Ingredient>.unmodifiable(ingredients),
       cocktails = List<Cocktail>.unmodifiable(cocktails);

  final List<Ingredient> ingredients;
  final List<Cocktail> cocktails;

  Map<String, Ingredient> get ingredientsById {
    return <String, Ingredient>{
      for (final ingredient in ingredients) ingredient.id: ingredient,
    };
  }

  Set<String> get ingredientIds => ingredientsById.keys.toSet();

  BarCatalog copyWith({
    List<Ingredient>? ingredients,
    List<Cocktail>? cocktails,
  }) {
    return BarCatalog(
      ingredients: ingredients ?? this.ingredients,
      cocktails: cocktails ?? this.cocktails,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BarCatalog &&
            listEquals(other.ingredients, ingredients) &&
            listEquals(other.cocktails, cocktails);
  }

  @override
  int get hashCode => Object.hashAll(<Object>[...ingredients, ...cocktails]);
}
