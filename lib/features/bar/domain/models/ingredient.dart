import 'package:flutter/foundation.dart';

@immutable
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    this.isDecoration = false,
    this.isOptional = false,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      category: (json['category'] as String? ?? '').trim(),
      image: (json['image'] as String? ?? '').trim(),
      isDecoration: _parseBool(json['isDecoration'] ?? json['decoration']),
      isOptional: _parseBool(json['isOptional'] ?? json['optional']),
    );
  }

  final String id;
  final String name;
  final String category;
  final String image;
  final bool isDecoration;
  final bool isOptional;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'image': image,
      'isDecoration': isDecoration,
      'isOptional': isOptional,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Ingredient &&
            other.id == id &&
            other.name == name &&
            other.category == category &&
            other.image == image &&
            other.isDecoration == isDecoration &&
            other.isOptional == isOptional;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, category, image, isDecoration, isOptional);

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
}
