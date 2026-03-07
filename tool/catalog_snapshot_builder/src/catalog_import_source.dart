import 'dart:convert';
import 'dart:io';

import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/data/utils/catalog_id_utils.dart';

enum CatalogImportFormat { generic, theCocktailDb }

class CatalogImportPayload {
  const CatalogImportPayload({
    required this.sourceName,
    required this.sourceId,
    required this.format,
    required this.ingredients,
    required this.cocktails,
  });

  final String sourceName;
  final String sourceId;
  final CatalogImportFormat format;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> cocktails;
}

abstract class CatalogImportSource {
  String get sourceName;

  Future<CatalogImportPayload> fetch();
}

class TheCocktailDbCatalogImportSource implements CatalogImportSource {
  TheCocktailDbCatalogImportSource({
    required this.baseUrl,
    this.apiKey = '1',
    this.timeout = const Duration(seconds: 16),
    this.sourceIdValue = 'thecocktaildb_v1',
  });

  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final String sourceIdValue;

  @override
  String get sourceName => 'thecocktaildb';

  @override
  Future<CatalogImportPayload> fetch() async {
    final resolvedBaseUrl = _resolveBaseUrl(baseUrl, apiKey);
    final uri = Uri.tryParse(resolvedBaseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException(
        'Invalid TheCocktailDB base URL: "$resolvedBaseUrl"',
      );
    }

    final cocktails = await _fetchCocktailsByAlphabet(uri);
    final ingredientNames = <String>{
      ...await _fetchIngredientNames(uri),
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

    return CatalogImportPayload(
      sourceName: sourceName,
      sourceId: sourceIdValue,
      format: CatalogImportFormat.theCocktailDb,
      ingredients: ingredientMaps,
      cocktails: cocktails,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCocktailsByAlphabet(
    Uri baseUrl,
  ) async {
    final cocktailsById = <String, Map<String, dynamic>>{};
    var letterFailures = 0;

    for (final letter in _alphabetLetters) {
      try {
        final response = await _getObject(
          baseUrl: baseUrl,
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
            final detailed = await _fetchCocktailById(baseUrl: baseUrl, id: id);
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

  Future<Map<String, dynamic>> _fetchCocktailById({
    required Uri baseUrl,
    required String id,
  }) async {
    final response = await _getObject(
      baseUrl: baseUrl,
      endpoint: 'lookup.php',
      queryParameters: <String, String>{'i': id},
    );
    final items = _parseObjectList(response['drinks']);
    return items.isEmpty ? <String, dynamic>{} : items.first;
  }

  Future<Set<String>> _fetchIngredientNames(Uri baseUrl) async {
    try {
      final response = await _getObject(
        baseUrl: baseUrl,
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
    required Uri baseUrl,
    required String endpoint,
    required Map<String, String> queryParameters,
  }) async {
    final requestUri = baseUrl
        .resolve(endpoint)
        .replace(queryParameters: queryParameters);
    final client = HttpClient();
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
    return 'https://www.thecocktaildb.com/images/ingredients/${Uri.encodeComponent(trimmed)}.png';
  }

  String _resolveBaseUrl(String baseUrl, String apiKey) {
    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isNotEmpty) {
      return normalizedBaseUrl;
    }
    final normalizedApiKey = apiKey.trim().isEmpty ? '1' : apiKey.trim();
    return 'https://www.thecocktaildb.com/api/json/v1/$normalizedApiKey/';
  }
}

class SeedJsonCatalogImportSource implements CatalogImportSource {
  SeedJsonCatalogImportSource({
    required this.inputPath,
    this.codec = const BarCatalogJsonCodec(),
  });

  final String inputPath;
  final BarCatalogJsonCodec codec;

  @override
  String get sourceName => 'seed';

  @override
  Future<CatalogImportPayload> fetch() async {
    final file = File(inputPath);
    if (!file.existsSync()) {
      throw FileSystemException(
        'Input seed file does not exist',
        file.absolute.path,
      );
    }
    final payload = await file.readAsString();
    final catalog = codec.decode(payload);

    final ingredients = catalog.ingredients
        .map((ingredient) => ingredient.toJson())
        .toList(growable: false);
    final cocktails = catalog.cocktails
        .map((cocktail) => cocktail.toJson())
        .toList(growable: false);

    return CatalogImportPayload(
      sourceName: sourceName,
      sourceId: 'seed_json',
      format: CatalogImportFormat.generic,
      ingredients: ingredients,
      cocktails: cocktails,
    );
  }
}

class HttpJsonCatalogImportSource implements CatalogImportSource {
  HttpJsonCatalogImportSource({
    required this.url,
    this.timeout = const Duration(seconds: 20),
  });

  final Uri url;
  final Duration timeout;

  @override
  String get sourceName => 'http-json';

  @override
  Future<CatalogImportPayload> fetch() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Snapshot source request failed with HTTP ${response.statusCode}',
          uri: url,
        );
      }
      final payload = await utf8.decodeStream(response).timeout(timeout);
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Snapshot source response root must be object',
        );
      }

      final ingredients = _parseObjectList(
        decoded['ingredients'],
        fieldName: 'ingredients',
      );
      final cocktails = _parseObjectList(
        decoded['cocktails'],
        fieldName: 'cocktails',
      );

      return CatalogImportPayload(
        sourceName: sourceName,
        sourceId: url.host,
        format: CatalogImportFormat.generic,
        ingredients: ingredients,
        cocktails: cocktails,
      );
    } finally {
      client.close(force: true);
    }
  }

  List<Map<String, dynamic>> _parseObjectList(
    Object? value, {
    required String fieldName,
  }) {
    if (value is! List) {
      throw FormatException('"$fieldName" must be list');
    }
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return item.map((key, mapValue) => MapEntry('$key', mapValue));
          }
          throw FormatException('"$fieldName" item must be object');
        })
        .toList(growable: false);
  }
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
