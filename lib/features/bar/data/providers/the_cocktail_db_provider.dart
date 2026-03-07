import 'dart:convert';
import 'dart:io';

import '../utils/catalog_id_utils.dart';
import 'external_bar_data_provider.dart';

class TheCocktailDbExternalBarDataProvider implements ExternalBarDataProvider {
  TheCocktailDbExternalBarDataProvider({
    required this.baseUrl,
    this.sourceIdValue = 'thecocktaildb_v1',
    this.timeout = const Duration(seconds: 12),
    this.minRefreshInterval = const Duration(minutes: 15),
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Uri baseUrl;
  final String sourceIdValue;
  final Duration timeout;
  final Duration minRefreshInterval;
  final HttpClient Function() _httpClientFactory;

  _RawSnapshot? _cachedSnapshot;
  Future<_RawSnapshot>? _inFlightFetch;

  @override
  String get sourceId => sourceIdValue;

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.theCocktailDb;

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    final snapshot = await _loadSnapshot();
    return snapshot.cocktails;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    final snapshot = await _loadSnapshot();
    return snapshot.ingredients;
  }

  Future<_RawSnapshot> _loadSnapshot() async {
    final now = DateTime.now().toUtc();
    final cached = _cachedSnapshot;
    if (cached != null &&
        now.difference(cached.fetchedAt) < minRefreshInterval) {
      return cached;
    }

    final inFlight = _inFlightFetch;
    if (inFlight != null) {
      return inFlight;
    }

    final fetchFuture = _fetchSnapshot(now);
    _inFlightFetch = fetchFuture;

    try {
      final snapshot = await fetchFuture;
      _cachedSnapshot = snapshot;
      return snapshot;
    } finally {
      if (identical(_inFlightFetch, fetchFuture)) {
        _inFlightFetch = null;
      }
    }
  }

  Future<_RawSnapshot> _fetchSnapshot(DateTime nowUtc) async {
    final cocktails = await _fetchCocktailsByAlphabet();

    final ingredientNames = <String>{
      ...await _fetchIngredientNames(),
      ..._extractIngredientNamesFromCocktails(cocktails),
    };

    if (cocktails.isEmpty && ingredientNames.isEmpty) {
      throw const FormatException(
        'TheCocktailDB returned empty cocktails and ingredients payloads.',
      );
    }

    final ingredients =
        ingredientNames
            .where((item) => item.trim().isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );

    final ingredientMaps = ingredients
        .map(
          (name) => <String, dynamic>{
            'strIngredient1': name,
            'sourceId': normalizeKey(name),
            'image': _buildIngredientImageUrl(name),
          },
        )
        .toList(growable: false);

    return _RawSnapshot(
      fetchedAt: nowUtc,
      ingredients: ingredientMaps,
      cocktails: cocktails,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCocktailsByAlphabet() async {
    final cocktailsById = <String, Map<String, dynamic>>{};
    var letterFailures = 0;

    for (final letter in _alphabetLetters) {
      try {
        final response = await _getObject(
          endpoint: 'search.php',
          queryParameters: <String, String>{'f': letter},
        );

        for (final item in _parseObjectList(response['drinks'])) {
          final id = _readString(item, const <String>['idDrink', 'id']);
          if (id.isEmpty) {
            continue;
          }

          var normalizedItem = item;
          if (_requiresLookup(normalizedItem)) {
            final detailed = await _fetchCocktailById(id);
            if (detailed.isNotEmpty) {
              normalizedItem = detailed;
            }
          }

          cocktailsById.putIfAbsent(id, () => normalizedItem);
        }
      } catch (_) {
        letterFailures++;
      }
    }

    if (cocktailsById.isEmpty && letterFailures == _alphabetLetters.length) {
      throw const SocketException(
        'Failed to load cocktails from TheCocktailDB for all letters.',
      );
    }

    return cocktailsById.values.toList(growable: false);
  }

  Future<Map<String, dynamic>> _fetchCocktailById(String id) async {
    final response = await _getObject(
      endpoint: 'lookup.php',
      queryParameters: <String, String>{'i': id},
    );

    final items = _parseObjectList(response['drinks']);
    if (items.isEmpty) {
      return <String, dynamic>{};
    }

    return items.first;
  }

  Future<Set<String>> _fetchIngredientNames() async {
    try {
      final response = await _getObject(
        endpoint: 'list.php',
        queryParameters: const <String, String>{'i': 'list'},
      );

      return _parseObjectList(response['drinks'])
          .map(
            (item) => _readString(item, const <String>[
              'strIngredient1',
              'strIngredient',
              'name',
            ]),
          )
          .where((item) => item.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Set<String> _extractIngredientNamesFromCocktails(
    List<Map<String, dynamic>> cocktails,
  ) {
    final names = <String>{};

    for (final cocktail in cocktails) {
      for (var index = 1; index <= 15; index++) {
        final name = _readString(cocktail, <String>['strIngredient$index']);
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
    }

    return names;
  }

  bool _requiresLookup(Map<String, dynamic> cocktail) {
    final hasInstructions = _readString(cocktail, const <String>[
      'strInstructions',
    ]).isNotEmpty;
    final hasIngredient = _readString(cocktail, const <String>[
      'strIngredient1',
    ]).isNotEmpty;
    final hasGlass = _readString(cocktail, const <String>[
      'strGlass',
    ]).isNotEmpty;

    return !(hasInstructions && hasIngredient && hasGlass);
  }

  Future<Map<String, dynamic>> _getObject({
    required String endpoint,
    required Map<String, String> queryParameters,
  }) async {
    final requestUri = baseUrl
        .resolve(endpoint)
        .replace(queryParameters: queryParameters);

    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(requestUri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'TheCocktailDB request failed (${response.statusCode})',
          uri: requestUri,
        );
      }

      final payload = await utf8.decodeStream(response).timeout(timeout);
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const FormatException(
          'TheCocktailDB response root must be object',
        );
      }

      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } finally {
      client.close(force: true);
    }
  }

  String _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  List<Map<String, dynamic>> _parseObjectList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return item.map((key, value) => MapEntry(key.toString(), value));
          }
          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _buildIngredientImageUrl(String ingredientName) {
    final trimmed = ingredientName.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final encoded = Uri.encodeComponent(trimmed);
    return 'https://www.thecocktaildb.com/images/ingredients/$encoded.png';
  }
}

class _RawSnapshot {
  const _RawSnapshot({
    required this.fetchedAt,
    required this.ingredients,
    required this.cocktails,
  });

  final DateTime fetchedAt;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> cocktails;
}

const List<String> _alphabetLetters = <String>[
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
];
