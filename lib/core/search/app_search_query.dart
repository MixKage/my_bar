import 'dart:math';

/// Unified app-level search query matcher with:
/// - normalization (case/punctuation/yo->e),
/// - Cyrillic/Latin transliteration,
/// - hard-coded bilingual synonym mapping,
/// - fuzzy matching (Levenshtein + Dice coefficient).
class AppSearchQuery {
  AppSearchQuery(String rawQuery)
    : _variants = _buildQueryVariants(rawQuery),
      _tokens = _buildQueryTokens(rawQuery);

  final Set<String> _variants;
  final Set<String> _tokens;

  bool get isEmpty => _variants.isEmpty;

  bool matchesAny(Iterable<String> texts) {
    if (isEmpty) {
      return true;
    }
    for (final text in texts) {
      if (matches(text)) {
        return true;
      }
    }
    return false;
  }

  bool matches(String text) {
    if (isEmpty) {
      return true;
    }

    final normalizedSource = _normalize(text);
    if (normalizedSource.isEmpty) {
      return false;
    }

    final sourceVariants = _buildSourceVariants(normalizedSource);
    for (final sourceVariant in sourceVariants) {
      for (final queryVariant in _variants) {
        if (sourceVariant.contains(queryVariant)) {
          return true;
        }
      }
    }

    if (_tokens.isEmpty) {
      return false;
    }

    final sourceTokens = <String>{};
    for (final sourceVariant in sourceVariants) {
      sourceTokens.addAll(_splitTokens(sourceVariant));
    }

    if (sourceTokens.isEmpty) {
      return false;
    }

    for (final queryToken in _tokens) {
      for (final sourceToken in sourceTokens) {
        if (_isFuzzyTokenMatch(queryToken, sourceToken)) {
          return true;
        }
      }
    }
    return false;
  }

  static Set<String> _buildQueryVariants(String rawQuery) {
    final normalized = _normalize(rawQuery);
    if (normalized.isEmpty) {
      return const <String>{};
    }

    final variants = <String>{normalized};
    final latin = _normalize(_cyrillicToLatin(normalized));
    final cyrillic = _normalize(_latinToCyrillic(normalized));
    if (latin.isNotEmpty) {
      variants.add(latin);
    }
    if (cyrillic.isNotEmpty) {
      variants.add(cyrillic);
    }

    _addDictionaryVariants(variants, normalized);
    _addDictionaryVariants(variants, latin);
    _addDictionaryVariants(variants, cyrillic);

    variants.removeWhere((value) => value.trim().isEmpty);
    return variants;
  }

  static Set<String> _buildQueryTokens(String rawQuery) {
    final tokens = <String>{};
    for (final variant in _buildQueryVariants(rawQuery)) {
      tokens.addAll(_splitTokens(variant));
    }
    tokens.removeWhere((token) => token.length < 3);
    return tokens;
  }

  static Set<String> _buildSourceVariants(String normalizedSource) {
    final variants = <String>{normalizedSource};
    final latin = _normalize(_cyrillicToLatin(normalizedSource));
    final cyrillic = _normalize(_latinToCyrillic(normalizedSource));
    if (latin.isNotEmpty) {
      variants.add(latin);
    }
    if (cyrillic.isNotEmpty) {
      variants.add(cyrillic);
    }
    return variants;
  }

  static void _addDictionaryVariants(Set<String> target, String source) {
    if (source.trim().isEmpty) {
      return;
    }
    final tokens = source
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return;
    }

    for (var index = 0; index < tokens.length; index += 1) {
      final token = tokens[index];
      final replacements = _hardSynonymMap[token];
      if (replacements == null || replacements.isEmpty) {
        continue;
      }
      for (final replacement in replacements) {
        final normalizedReplacement = _normalize(replacement);
        if (normalizedReplacement.isEmpty) {
          continue;
        }
        target.add(normalizedReplacement);
        final replacedTokens = List<String>.from(tokens);
        replacedTokens[index] = normalizedReplacement;
        target.add(replacedTokens.join(' '));
      }
    }
  }

  static bool _isFuzzyTokenMatch(String queryToken, String sourceToken) {
    if (queryToken == sourceToken) {
      return true;
    }

    if (queryToken.length < 3 || sourceToken.length < 3) {
      return false;
    }

    final maxDistance = queryToken.length <= 5 ? 1 : 2;
    if ((queryToken.length - sourceToken.length).abs() > maxDistance) {
      return false;
    }

    final levenshteinDistance = _levenshteinDistance(
      queryToken,
      sourceToken,
      maxDistance: maxDistance,
    );
    if (levenshteinDistance <= maxDistance) {
      return true;
    }

    return _diceCoefficient(queryToken, sourceToken) >= 0.74;
  }

  static int _levenshteinDistance(
    String left,
    String right, {
    required int maxDistance,
  }) {
    if (left == right) {
      return 0;
    }

    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    if ((left.length - right.length).abs() > maxDistance) {
      return maxDistance + 1;
    }

    var previous = List<int>.generate(right.length + 1, (index) => index);
    var current = List<int>.filled(right.length + 1, 0);

    for (var i = 1; i <= left.length; i += 1) {
      current[0] = i;
      var rowMin = current[0];

      final leftUnit = left.codeUnitAt(i - 1);
      for (var j = 1; j <= right.length; j += 1) {
        final rightUnit = right.codeUnitAt(j - 1);
        final substitutionCost = leftUnit == rightUnit ? 0 : 1;

        current[j] = min(
          min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + substitutionCost,
        );
        rowMin = min(rowMin, current[j]);
      }

      if (rowMin > maxDistance) {
        return maxDistance + 1;
      }

      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[right.length];
  }

  static double _diceCoefficient(String left, String right) {
    if (left == right) {
      return 1;
    }
    if (left.length < 2 || right.length < 2) {
      return 0;
    }

    final leftBigrams = _bigramCounts(left);
    final rightBigrams = _bigramCounts(right);

    var intersection = 0;
    for (final entry in leftBigrams.entries) {
      final rightCount = rightBigrams[entry.key];
      if (rightCount == null) {
        continue;
      }
      intersection += min(entry.value, rightCount);
    }

    final leftTotal = left.length - 1;
    final rightTotal = right.length - 1;
    if (leftTotal + rightTotal == 0) {
      return 0;
    }

    return (2 * intersection) / (leftTotal + rightTotal);
  }

  static Map<String, int> _bigramCounts(String input) {
    final counts = <String, int>{};
    for (var index = 0; index < input.length - 1; index += 1) {
      final bigram = input.substring(index, index + 2);
      counts[bigram] = (counts[bigram] ?? 0) + 1;
    }
    return counts;
  }

  static Set<String> _splitTokens(String value) {
    return value
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  static String _normalize(String value) {
    final lower = value.toLowerCase().replaceAll('ё', 'е');
    final withoutPunctuation = lower.replaceAll(_searchCleanupPattern, ' ');
    return withoutPunctuation.replaceAll(_multiSpacePattern, ' ').trim();
  }

  static String _cyrillicToLatin(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_cyrillicToLatinMap[char] ?? char);
    }
    return buffer.toString();
  }

  static String _latinToCyrillic(String value) {
    final normalized = value.toLowerCase();
    final buffer = StringBuffer();
    var index = 0;

    while (index < normalized.length) {
      var matched = false;
      for (final entry in _latinToCyrillicDigraphs) {
        final source = entry.$1;
        final replacement = entry.$2;
        if (!normalized.startsWith(source, index)) {
          continue;
        }
        buffer.write(replacement);
        index += source.length;
        matched = true;
        break;
      }

      if (matched) {
        continue;
      }

      final char = normalized[index];
      buffer.write(_latinToCyrillicSingles[char] ?? char);
      index += 1;
    }

    return buffer.toString();
  }

  static final RegExp _searchCleanupPattern = RegExp(r'[^a-z0-9а-я]+');
  static final RegExp _multiSpacePattern = RegExp(r'\s+');

  static const Map<String, String> _cyrillicToLatinMap = <String, String>{
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ж': 'zh',
    'з': 'z',
    'и': 'i',
    'й': 'y',
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
    'х': 'kh',
    'ц': 'ts',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'shch',
    'ъ': '',
    'ы': 'y',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
  };

  static const List<(String, String)> _latinToCyrillicDigraphs =
      <(String, String)>[
        ('shch', 'щ'),
        ('sch', 'щ'),
        ('yo', 'е'),
        ('zh', 'ж'),
        ('kh', 'х'),
        ('ts', 'ц'),
        ('ch', 'ч'),
        ('sh', 'ш'),
        ('yu', 'ю'),
        ('ya', 'я'),
        ('ye', 'е'),
      ];

  static const Map<String, String> _latinToCyrillicSingles = <String, String>{
    'a': 'а',
    'b': 'б',
    'c': 'к',
    'd': 'д',
    'e': 'е',
    'f': 'ф',
    'g': 'г',
    'h': 'х',
    'i': 'и',
    'j': 'й',
    'k': 'к',
    'l': 'л',
    'm': 'м',
    'n': 'н',
    'o': 'о',
    'p': 'п',
    'q': 'к',
    'r': 'р',
    's': 'с',
    't': 'т',
    'u': 'у',
    'v': 'в',
    'w': 'в',
    'x': 'кс',
    'y': 'ы',
    'z': 'з',
  };

  static const Map<String, List<String>> _hardSynonymMap =
      <String, List<String>>{
        'самбука': <String>['sambuca'],
        'sambuca': <String>['самбука'],
        'sambuka': <String>['sambuca', 'самбука'],
        'виски': <String>['whiskey', 'whisky'],
        'whiskey': <String>['виски', 'whisky'],
        'whisky': <String>['виски', 'whiskey'],
      };
}
