import '../../domain/models/ingredient.dart';

String normalizeKey(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String slugify(String value) {
  final buffer = StringBuffer();
  final alphaNumericPattern = RegExp('[a-z0-9а-яё]');
  var wasDash = false;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune).toLowerCase();
    final isAlphaNumeric = alphaNumericPattern.hasMatch(char);
    if (isAlphaNumeric) {
      buffer.write(_transliterate(char));
      wasDash = false;
    } else if (!wasDash) {
      buffer.write('-');
      wasDash = true;
    }
  }

  var slug = buffer.toString().replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    slug = 'item';
  }
  return slug;
}

String canonicalFromValue(String value) {
  final normalized = normalizeKey(value);
  if (normalized.isNotEmpty) {
    return normalized;
  }
  return normalizeKey(slugify(value));
}

String buildDeterministicUnifiedKey({
  required String source,
  required String sourceId,
}) {
  final normalizedSource = normalizeKey(source);
  final normalizedSourceId = normalizeKey(sourceId);
  if (normalizedSourceId.isEmpty) {
    return normalizedSource;
  }
  return '$normalizedSource:$normalizedSourceId';
}

String sortedTokenKey(String value) {
  final tokens =
      normalizeKey(
          value,
        ).split('_').where((token) => token.isNotEmpty).toList(growable: false)
        ..sort();
  return tokens.join('_');
}

class IngredientCanonicalMapper {
  IngredientCanonicalMapper.fromKnownIngredients(Iterable<Ingredient> items) {
    for (final ingredient in items) {
      _registerKnown(ingredient.id, ingredient.id);
      _registerKnown(ingredient.name, ingredient.id);
      _registerSortedTokens(ingredient.id, ingredient.id);
      _registerSortedTokens(ingredient.name, ingredient.id);
    }
  }

  final Map<String, String> _knownByNormalizedValue = <String, String>{};
  final Map<String, String> _knownBySortedTokens = <String, String>{};

  String resolve({
    String? explicitId,
    required String displayName,
    Iterable<String> aliases = const <String>[],
  }) {
    final candidates = <String>[?explicitId, displayName, ...aliases];

    for (final candidate in candidates) {
      final normalized = normalizeKey(candidate);
      if (normalized.isEmpty) {
        continue;
      }
      final mapped = _knownByNormalizedValue[normalized];
      if (mapped != null && mapped.isNotEmpty) {
        return mapped;
      }

      final sortedTokens = sortedTokenKey(candidate);
      final mappedByTokens = _knownBySortedTokens[sortedTokens];
      if (mappedByTokens != null && mappedByTokens.isNotEmpty) {
        return mappedByTokens;
      }
    }

    final explicitCanonical = normalizeKey(explicitId ?? '');
    if (explicitCanonical.isNotEmpty) {
      return explicitCanonical;
    }

    final displayCanonical = normalizeKey(displayName);
    if (displayCanonical.isNotEmpty) {
      return displayCanonical;
    }

    return normalizeKey(slugify(displayName));
  }

  void _registerKnown(String value, String ingredientId) {
    final normalized = normalizeKey(value);
    if (normalized.isEmpty) {
      return;
    }
    _knownByNormalizedValue.putIfAbsent(normalized, () => ingredientId);
  }

  void _registerSortedTokens(String value, String ingredientId) {
    final tokenKey = sortedTokenKey(value);
    if (tokenKey.isEmpty) {
      return;
    }
    _knownBySortedTokens.putIfAbsent(tokenKey, () => ingredientId);
  }
}

String _transliterate(String char) {
  const map = <String, String>{
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ё': 'e',
    'ж': 'zh',
    'з': 'z',
    'и': 'i',
    'й': 'i',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'h',
    'ц': 'c',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'sh',
    'ъ': '',
    'ы': 'y',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
  };

  return map[char] ?? char;
}
