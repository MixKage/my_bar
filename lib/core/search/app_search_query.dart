import 'dart:math';

/// Search text is separate from the label a user sees on the card.
class AppSearchDocument {
  const AppSearchDocument({
    required this.name,
    this.aliases = const [],
    this.related = const [],
    this.details = const [],
  });

  final String name;
  final Iterable<String> aliases;
  final Iterable<String> related;
  final Iterable<String> details;
}

/// Offline Unicode search with phrase ranking, transliteration and typo tolerance.
class AppSearchQuery {
  AppSearchQuery(String rawQuery) : _query = _SearchText(_normalize(rawQuery));

  final _SearchText _query;
  final _fields = <String, _SearchText>{};
  final _tokenScores = <(String, String, bool, bool), int>{};

  bool get isEmpty => _query.value.isEmpty;

  bool matches(String text) => score(AppSearchDocument(name: text)) > 0;

  bool matchesAny(Iterable<String> texts) =>
      score(AppSearchDocument(name: '', aliases: texts)) > 0;

  /// Results of equal relevance preserve the caller's sort order.
  List<T> rank<T>(
    Iterable<T> items,
    AppSearchDocument Function(T item) describe,
  ) {
    if (isEmpty) return items.toList(growable: false);
    final ranked = <({T item, int order, int score})>[];
    for (final (index, item) in items.indexed) {
      final value = score(describe(item));
      if (value > 0) ranked.add((item: item, order: index, score: value));
    }
    ranked.sort((a, b) {
      final relevance = b.score.compareTo(a.score);
      return relevance == 0 ? a.order.compareTo(b.order) : relevance;
    });
    return ranked.map((entry) => entry.item).toList(growable: false);
  }

  /// Returns zero unless every query term is accounted for.
  int score(AppSearchDocument document) {
    if (isEmpty) return 1;
    final fields = <(_SearchText, int)>[
      (_field(document.name), 90),
      for (final text in document.aliases) (_field(text), 70),
      for (final text in document.related) (_field(text), 40),
      for (final text in document.details) (_field(text), 10),
    ];
    var best = 0;
    for (final (queryIndex, query) in _query.forms.indexed) {
      for (final (field, weight) in fields) {
        for (final (sourceIndex, source) in field.forms.indexed) {
          // Transliteration can erase a real spelling distinction (ь, ъ).
          // Prefer a literal name, alias or prefix before that fallback.
          final penalty = queryIndex == 0 && sourceIndex == 0 ? 0 : 250;
          if (source.value == query.value) {
            best = max(best, 1000 + weight - penalty);
          } else if (source.value.startsWith(query.value)) {
            best = max(best, 800 + weight - penalty);
          } else if (source.value.contains(' ${query.value}') ||
              (_unsegmented.hasMatch(query.value) &&
                  source.value.contains(query.value))) {
            best = max(best, 650 + weight - penalty);
          }
        }
      }
      if (best >= 800) continue;
      var total = 0;
      var weakest = 200;
      final allowShortPrefix = query.tokens.length == 1;
      for (final term in query.tokens) {
        var strongest = 0;
        for (final (field, weight) in fields) {
          for (final (sourceIndex, source) in field.forms.indexed) {
            for (final token in source.tokens) {
              final value = _tokenScores.putIfAbsent(
                (term, token, weight > 10, allowShortPrefix),
                () => _matchToken(
                  term,
                  token,
                  allowTypos: weight > 10,
                  allowShortPrefix: allowShortPrefix,
                ),
              );
              if (value > 0) {
                strongest = max(strongest, value + weight - sourceIndex * 8);
              }
            }
          }
        }
        if (strongest == 0) {
          weakest = 0;
          break;
        }
        weakest = min(weakest, strongest);
        total += strongest;
      }
      if (weakest > 0) {
        best = max(
          best,
          200 + weakest + total ~/ query.tokens.length - queryIndex * 10,
        );
      }
    }
    return best;
  }

  _SearchText _field(String value) =>
      _fields.putIfAbsent(value, () => _SearchText(_normalize(value)));

  static int _matchToken(
    String query,
    String source, {
    required bool allowTypos,
    required bool allowShortPrefix,
  }) {
    if (query == source ||
        (_equivalentTokens[query] ?? query) ==
            (_equivalentTokens[source] ?? source)) {
      return 100;
    }
    // Avoid matching "gin ginger" against Ginger Ale solely through "ginger".
    if ((source.startsWith(query) &&
            (allowShortPrefix || query.runes.length > 3)) ||
        (_unsegmented.hasMatch(query) && source.contains(query))) {
      return 75;
    }
    if (!allowTypos ||
        _hasNumber.hasMatch(query) ||
        _hasNumber.hasMatch(source)) {
      return 0;
    }

    final left = query.runes.toList(growable: false);
    final right = source.runes.toList(growable: false);
    final minimum = _unsegmented.hasMatch(query) ? 3 : 4;
    if (left.length < minimum || right.length < minimum - 1) return 0;
    final limit = left.length >= 6 ? 2 : 1;
    if ((left.length - right.length).abs() > limit) return 0;
    final distance = _editDistance(left, right, limit);
    return distance <= limit ? 49 - distance * 8 : 0;
  }

  // Adjacent transpositions count as one typo (e.g. "ornage").
  static int _editDistance(List<int> left, List<int> right, int limit) {
    var twoBack = List<int>.filled(right.length + 1, 0);
    var previous = List<int>.generate(right.length + 1, (index) => index);
    var current = List<int>.filled(right.length + 1, 0);
    for (var i = 1; i <= left.length; i++) {
      current[0] = i;
      var rowMin = i;
      for (var j = 1; j <= right.length; j++) {
        current[j] = min(
          min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1),
        );
        if (i > 1 &&
            j > 1 &&
            left[i - 1] == right[j - 2] &&
            left[i - 2] == right[j - 1]) {
          current[j] = min(current[j], twoBack[j - 2] + 1);
        }
        rowMin = min(rowMin, current[j]);
      }
      if (rowMin > limit) return limit + 1;
      final scratch = twoBack;
      twoBack = previous;
      previous = current;
      current = scratch;
    }
    return previous[right.length];
  }

  static String _normalize(String value) {
    final lower = value
        .toLowerCase()
        .replaceAllMapped(_possessive, (m) => m[1]!)
        .replaceAll('ё', 'е')
        .replaceAll('и\u0306', 'й')
        .replaceAllMapped(_latinCombiningMarks, (m) => m[1]!)
        .replaceAll(_arabicDecoration, '');
    final folded = StringBuffer();
    for (final rune in lower.runes) {
      final character = String.fromCharCode(rune);
      folded.write(_foldedLetters[character] ?? character);
    }
    return folded.toString().replaceAll(_separator, ' ').trim();
  }

  static final _separator = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
  static final _hasNumber = RegExp(r'\p{N}', unicode: true);
  static final _possessive = RegExp(r"([a-z])['’]s\b");
  static final _latinCombiningMarks = RegExp(r'([a-z])[\u0300-\u036f]+');
  static final _arabicDecoration = RegExp(
    r'[\u0610-\u061a\u0640\u064b-\u065f\u0670]',
  );
  static final _unsegmented = RegExp(
    r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',
  );
  static final _latin = RegExp(r'[a-z]');
  static final _cyrillic = RegExp(r'[а-я]');

  static const _foldedLetters = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ğ': 'g',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ı': 'i',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ø': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ş': 's',
    'ß': 'ss',
    'æ': 'ae',
    'œ': 'oe',
    'ł': 'l',
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
  };

  // These substitutions affect a single term, never the whole query.
  static const _equivalentTokens = {
    'самбука': 'sambuca',
    'sambuka': 'sambuca',
    'джин': 'gin',
    'dzhin': 'gin',
    'виски': 'whisky',
    'viski': 'whisky',
    'whiskey': 'whisky',
  };

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
}

class _SearchText {
  _SearchText(this.value);

  final String value;

  late final forms = <_SearchForm>[
    for (final variant in <String>{
      if (value.isNotEmpty) value,
      if (AppSearchQuery._cyrillic.hasMatch(value))
        AppSearchQuery._normalize(AppSearchQuery._cyrillicToLatin(value)),
      if (AppSearchQuery._latin.hasMatch(value))
        AppSearchQuery._normalize(AppSearchQuery._latinToCyrillic(value)),
    })
      if (variant.isNotEmpty) _SearchForm(variant),
  ];
}

class _SearchForm {
  _SearchForm(this.value);

  final String value;
  late final tokens = value.split(' ').toSet();
}
