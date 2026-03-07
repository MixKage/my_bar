import 'package:meta/meta.dart';

@immutable
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    this.isDecoration = false,
    this.isOptional = false,
    this.glowColor = '',
    this.glowSecondaryColor,
    this.glowOffsetX = 0,
    this.glowOffsetY = 0,
    this.glowScale = 1,
    this.glowOpacity = 0.34,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      category: (json['category'] as String? ?? '').trim(),
      image: (json['image'] as String? ?? '').trim(),
      isDecoration: _parseBool(json['isDecoration'] ?? json['decoration']),
      isOptional: _parseBool(json['isOptional'] ?? json['optional']),
      glowColor: (json['glowColor'] as String? ?? '').trim(),
      glowSecondaryColor: (json['glowSecondaryColor'] as String?)?.trim(),
      glowOffsetX: _parseDouble(json['glowOffsetX']),
      glowOffsetY: _parseDouble(json['glowOffsetY']),
      glowScale: _parseDouble(json['glowScale'], fallback: 1),
      glowOpacity: _parseDouble(json['glowOpacity'], fallback: 0.34),
    );
  }

  final String id;
  final String name;
  final String category;
  final String image;
  final bool isDecoration;
  final bool isOptional;
  final String glowColor;
  final String? glowSecondaryColor;
  final double glowOffsetX;
  final double glowOffsetY;
  final double glowScale;
  final double glowOpacity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'image': image,
      'isDecoration': isDecoration,
      'isOptional': isOptional,
      if (glowColor.trim().isNotEmpty) 'glowColor': glowColor.trim(),
      if (glowSecondaryColor?.trim().isNotEmpty ?? false)
        'glowSecondaryColor': glowSecondaryColor!.trim(),
      'glowOffsetX': glowOffsetX,
      'glowOffsetY': glowOffsetY,
      'glowScale': glowScale,
      'glowOpacity': glowOpacity,
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
            other.isOptional == isOptional &&
            other.glowColor == glowColor &&
            other.glowSecondaryColor == glowSecondaryColor &&
            other.glowOffsetX == glowOffsetX &&
            other.glowOffsetY == glowOffsetY &&
            other.glowScale == glowScale &&
            other.glowOpacity == glowOpacity;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    image,
    isDecoration,
    isOptional,
    glowColor,
    glowSecondaryColor,
    glowOffsetX,
    glowOffsetY,
    glowScale,
    glowOpacity,
  );

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

  static double _parseDouble(Object? value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      final parsed = double.tryParse(normalized);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }
}
