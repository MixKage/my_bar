import 'dart:convert';

import '../domain/models/bar_catalog.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/cocktail_glass_types.dart';
import '../domain/models/cocktail_tags.dart';
import '../domain/models/ingredient.dart';

class BarCatalogJsonCodec {
  const BarCatalogJsonCodec();

  BarCatalog decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON корень должен быть объектом.');
    }
    return decodeMap(decoded);
  }

  BarCatalog decodeMap(Map<String, dynamic> map) {
    final ingredientsJson = map['ingredients'];
    final cocktailsJson = map['cocktails'];

    if (ingredientsJson is! List) {
      throw const FormatException('Поле "ingredients" должно быть массивом.');
    }
    if (cocktailsJson is! List) {
      throw const FormatException('Поле "cocktails" должно быть массивом.');
    }

    final ingredients = ingredientsJson
        .map((item) => Ingredient.fromJson(_castMap(item, 'ingredients')))
        .toList(growable: false);
    final cocktails = cocktailsJson
        .map((item) => Cocktail.fromJson(_castMap(item, 'cocktails')))
        .toList(growable: false);

    _validateUniqueIds(
      ingredients.map((ingredient) => ingredient.id),
      'ingredients',
    );
    _validateUniqueIds(cocktails.map((cocktail) => cocktail.id), 'cocktails');

    final ingredientIds = ingredients
        .map((ingredient) => ingredient.id)
        .toSet();
    for (final cocktail in cocktails) {
      if (cocktail.ingredients.any((id) => !ingredientIds.contains(id))) {
        throw FormatException(
          'Коктейль "${cocktail.name}" содержит неизвестные ингредиенты.',
        );
      }

      final invalidTag = cocktail.tags.firstWhere(
        (tag) => !kCocktailTags.contains(tag),
        orElse: () => '',
      );
      if (invalidTag.isNotEmpty) {
        throw FormatException(
          'Коктейль "${cocktail.name}" содержит неизвестный тег "$invalidTag".',
        );
      }

      if (!kCocktailGlassTypes.contains(cocktail.glassType)) {
        throw FormatException(
          'Коктейль "${cocktail.name}" содержит неизвестный тип бокала "${cocktail.glassType}".',
        );
      }

      for (final substitutionEntry
          in cocktail.ingredientSubstitutions.entries) {
        final sourceIngredientId = substitutionEntry.key;
        if (!cocktail.ingredients.contains(sourceIngredientId)) {
          throw FormatException(
            'Коктейль "${cocktail.name}" содержит замену для невыбранного ингредиента "$sourceIngredientId".',
          );
        }
        for (final substitutionId in substitutionEntry.value) {
          if (!ingredientIds.contains(substitutionId)) {
            throw FormatException(
              'Коктейль "${cocktail.name}" содержит неизвестный ингредиент-замену "$substitutionId".',
            );
          }
          if (substitutionId == sourceIngredientId) {
            throw FormatException(
              'Коктейль "${cocktail.name}" содержит замену ингредиента самого на себя.',
            );
          }
        }
      }

      for (final optionalIngredientId in cocktail.optionalIngredients) {
        if (!cocktail.ingredients.contains(optionalIngredientId)) {
          throw FormatException(
            'Коктейль "${cocktail.name}" содержит опциональный ингредиент "$optionalIngredientId", которого нет в составе.',
          );
        }
      }
      for (final decorationIngredientId in cocktail.decorationIngredients) {
        if (!cocktail.ingredients.contains(decorationIngredientId)) {
          throw FormatException(
            'Коктейль "${cocktail.name}" содержит ингредиент-украшение "$decorationIngredientId", которого нет в составе.',
          );
        }
      }
      for (final ingredientId in cocktail.ingredientAmounts.keys) {
        if (!cocktail.ingredients.contains(ingredientId)) {
          throw FormatException(
            'Коктейль "${cocktail.name}" содержит количество для неизвестного ингредиента "$ingredientId".',
          );
        }
      }
      for (final ingredientId in cocktail.ingredientUnits.keys) {
        if (!cocktail.ingredients.contains(ingredientId)) {
          throw FormatException(
            'Коктейль "${cocktail.name}" содержит единицу измерения для неизвестного ингредиента "$ingredientId".',
          );
        }
      }
    }

    return BarCatalog(ingredients: ingredients, cocktails: cocktails);
  }

  String encode(BarCatalog catalog, {bool pretty = true}) {
    final map = <String, dynamic>{
      'ingredients': catalog.ingredients
          .map((ingredient) => ingredient.toJson())
          .toList(growable: false),
      'cocktails': catalog.cocktails
          .map((cocktail) => cocktail.toJson())
          .toList(growable: false),
    };

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }

    return jsonEncode(map);
  }

  Map<String, dynamic> _castMap(Object? value, String fieldName) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw FormatException('Элемент "$fieldName" должен быть объектом.');
  }

  void _validateUniqueIds(Iterable<String> ids, String fieldName) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        throw FormatException('Повторяющийся id "$id" в "$fieldName".');
      }
    }
  }
}
