import 'package:flutter/foundation.dart';

@immutable
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      category: (json['category'] as String? ?? '').trim(),
      image: (json['image'] as String? ?? '').trim(),
    );
  }

  final String id;
  final String name;
  final String category;
  final String image;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'image': image,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Ingredient &&
            other.id == id &&
            other.name == name &&
            other.category == category &&
            other.image == image;
  }

  @override
  int get hashCode => Object.hash(id, name, category, image);
}
