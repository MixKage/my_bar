import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/models/catalog_data_source.dart';

abstract class IngredientDataProvider {
  Future<List<Map<String, dynamic>>> fetchIngredients();
}

abstract class CocktailDataProvider {
  Future<List<Map<String, dynamic>>> fetchCocktails();
}

abstract class ExternalBarDataProvider
    implements IngredientDataProvider, CocktailDataProvider {
  String get sourceId;
  ExternalProviderFormat get format;
}

enum ExternalProviderFormat { generic, theCocktailDb }

class JsonAssetExternalBarDataProvider implements ExternalBarDataProvider {
  JsonAssetExternalBarDataProvider({
    required this.assetPath,
    this.sourceIdValue = 'asset_template',
  });

  final String assetPath;
  final String sourceIdValue;

  @override
  String get sourceId => sourceIdValue;

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    final map = await _readCatalogMap();
    return _parseObjectList(map['ingredients'], 'ingredients');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    final map = await _readCatalogMap();
    return _parseObjectList(map['cocktails'], 'cocktails');
  }

  Future<Map<String, dynamic>> _readCatalogMap() async {
    final jsonString = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('JSON root must be object');
  }
}

class HttpJsonExternalBarDataProvider implements ExternalBarDataProvider {
  HttpJsonExternalBarDataProvider({
    required this.url,
    this.sourceIdValue = 'external_http_json',
    this.timeout = const Duration(seconds: 10),
  });

  final Uri url;
  final String sourceIdValue;
  final Duration timeout;

  @override
  String get sourceId => sourceIdValue;

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    final map = await _fetchCatalogMap();
    return _parseObjectList(map['ingredients'], 'ingredients');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    final map = await _fetchCatalogMap();
    return _parseObjectList(map['cocktails'], 'cocktails');
  }

  Future<Map<String, dynamic>> _fetchCatalogMap() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Catalog request failed with status: ${response.statusCode}',
          uri: url,
        );
      }

      final payload = await utf8.decodeStream(response).timeout(timeout);
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSON root must be object');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

class FallbackExternalBarDataProvider implements ExternalBarDataProvider {
  FallbackExternalBarDataProvider(this._providers)
    : assert(_providers.isNotEmpty, 'At least one provider is required');

  final List<ExternalBarDataProvider> _providers;
  ExternalBarDataProvider? _activeProvider;

  @override
  String get sourceId => _activeProvider?.sourceId ?? _providers.first.sourceId;

  @override
  ExternalProviderFormat get format =>
      _activeProvider?.format ?? _providers.first.format;

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async {
    final payload = await _fetchCombined();
    return payload.ingredients;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async {
    final payload = await _fetchCombined();
    return payload.cocktails;
  }

  Future<_FetchedPayload> _fetchCombined() async {
    Object? lastError;

    for (final provider in _providers) {
      try {
        final ingredients = await provider.fetchIngredients();
        final cocktails = await provider.fetchCocktails();
        _activeProvider = provider;
        return _FetchedPayload(
          sourceId: provider.sourceId,
          ingredients: ingredients,
          cocktails: cocktails,
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError('All external providers failed: $lastError');
  }
}

class SelectableExternalBarDataProvider implements ExternalBarDataProvider {
  SelectableExternalBarDataProvider({
    required ExternalBarDataProvider seedProvider,
    required ExternalBarDataProvider bootstrapDefaultProvider,
    required CatalogDataSource bootstrapDefaultDataSource,
    ExternalBarDataProvider? theCocktailDbProvider,
    CatalogDataSource? userSelectedDataSource,
  }) : _seedProvider = seedProvider,
       _bootstrapDefaultProvider = bootstrapDefaultProvider,
       _bootstrapDefaultDataSource = bootstrapDefaultDataSource,
       _theCocktailDbProvider = theCocktailDbProvider {
    _activeEntry = _resolveEntry(userSelectedDataSource);
    _userSelectedDataSource = userSelectedDataSource;
  }

  final ExternalBarDataProvider _seedProvider;
  final ExternalBarDataProvider _bootstrapDefaultProvider;
  final CatalogDataSource _bootstrapDefaultDataSource;
  final ExternalBarDataProvider? _theCocktailDbProvider;

  CatalogDataSource? _userSelectedDataSource;
  late _ActiveProviderEntry _activeEntry;

  bool get isTheCocktailDbAvailable => _theCocktailDbProvider != null;

  CatalogDataSource get activeDataSource => _activeEntry.dataSource;

  CatalogDataSource get defaultDataSource => _bootstrapDefaultDataSource;

  CatalogDataSource? get userSelectedDataSource => _userSelectedDataSource;

  CatalogDataSource resolveEffectiveDataSource(CatalogDataSource? requested) {
    return _resolveEntry(requested).dataSource;
  }

  bool selectDataSource(CatalogDataSource? selectedDataSource) {
    _userSelectedDataSource = selectedDataSource;
    final nextEntry = _resolveEntry(selectedDataSource);
    final changed =
        nextEntry.dataSource != _activeEntry.dataSource ||
        !identical(nextEntry.provider, _activeEntry.provider);
    _activeEntry = nextEntry;
    return changed;
  }

  @override
  String get sourceId => _activeEntry.provider.sourceId;

  @override
  ExternalProviderFormat get format => _activeEntry.provider.format;

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() {
    return _activeEntry.provider.fetchCocktails();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() {
    return _activeEntry.provider.fetchIngredients();
  }

  _ActiveProviderEntry _resolveEntry(CatalogDataSource? requested) {
    final userSelected = requested ?? _userSelectedDataSource;
    if (userSelected != null) {
      switch (userSelected) {
        case CatalogDataSource.seed:
          return _ActiveProviderEntry(
            dataSource: CatalogDataSource.seed,
            provider: _seedProvider,
          );
        case CatalogDataSource.theCocktailDb:
          final theCocktailDbProvider = _theCocktailDbProvider;
          if (theCocktailDbProvider != null) {
            return _ActiveProviderEntry(
              dataSource: CatalogDataSource.theCocktailDb,
              provider: theCocktailDbProvider,
            );
          }
          return _ActiveProviderEntry(
            dataSource: CatalogDataSource.seed,
            provider: _seedProvider,
          );
      }
    }

    if (_bootstrapDefaultDataSource == CatalogDataSource.theCocktailDb) {
      final theCocktailDbProvider = _theCocktailDbProvider;
      if (theCocktailDbProvider != null) {
        return _ActiveProviderEntry(
          dataSource: CatalogDataSource.theCocktailDb,
          provider: theCocktailDbProvider,
        );
      }
    }

    return _ActiveProviderEntry(
      dataSource: CatalogDataSource.seed,
      provider: _bootstrapDefaultProvider,
    );
  }
}

class _ActiveProviderEntry {
  const _ActiveProviderEntry({
    required this.dataSource,
    required this.provider,
  });

  final CatalogDataSource dataSource;
  final ExternalBarDataProvider provider;
}

class _FetchedPayload {
  const _FetchedPayload({
    required this.sourceId,
    required this.ingredients,
    required this.cocktails,
  });

  final String sourceId;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> cocktails;
}

List<Map<String, dynamic>> _parseObjectList(Object? value, String fieldName) {
  if (value is! List) {
    throw FormatException('"$fieldName" must be list');
  }

  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        }
        if (item is Map) {
          return item.map(
            (key, mapValue) => MapEntry(key.toString(), mapValue),
          );
        }
        throw FormatException('"$fieldName" item must be object');
      })
      .toList(growable: false);
}
