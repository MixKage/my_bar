import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/catalog_layer_models.dart';

abstract class ExternalCatalogCacheStorage {
  ExternalCatalogData? read();
  Future<void> write(ExternalCatalogData data);
}

class SharedPreferencesExternalCatalogCacheStorage
    implements ExternalCatalogCacheStorage {
  SharedPreferencesExternalCatalogCacheStorage(this._preferences);

  static const String storageKey = 'bar_external_catalog_cache_v2';

  final SharedPreferences _preferences;

  @override
  ExternalCatalogData? read() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ExternalCatalogData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(ExternalCatalogData data) {
    return _preferences.setString(storageKey, jsonEncode(data.toJson()));
  }
}

class InMemoryExternalCatalogCacheStorage
    implements ExternalCatalogCacheStorage {
  InMemoryExternalCatalogCacheStorage({ExternalCatalogData? initial})
    : _data = initial;

  ExternalCatalogData? _data;

  @override
  ExternalCatalogData? read() => _data;

  @override
  Future<void> write(ExternalCatalogData data) async {
    _data = data;
  }
}
