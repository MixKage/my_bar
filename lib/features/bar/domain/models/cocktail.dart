import 'package:flutter/foundation.dart';

import 'cocktail_tags.dart';

@immutable
class Cocktail {
  const Cocktail({
    required this.id,
    required this.name,
    required this.image,
    required this.ingredients,
    required this.description,
    required this.tags,
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

    return Cocktail(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      image: (json['image'] as String? ?? '').trim(),
      ingredients: ingredients,
      description: (json['description'] as String? ?? '').trim(),
      tags: tags,
    );
  }

  final String id;
  final String name;
  final String image;
  final List<String> ingredients;
  final String description;
  final List<String> tags;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'image': image,
      'ingredients': ingredients,
      'description': description,
      'tags': tags,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Cocktail &&
            other.id == id &&
            other.name == name &&
            other.image == image &&
            listEquals(other.ingredients, ingredients) &&
            other.description == description &&
            listEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      image,
      Object.hashAll(ingredients),
      description,
      Object.hashAll(tags),
    );
  }
}
