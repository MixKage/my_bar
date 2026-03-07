import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/catalog_layer_models.dart';

abstract class LocalCatalogStorage {
  LocalCatalogData read();
  Future<void> write(LocalCatalogData data);
}

class SharedPreferencesLocalCatalogStorage implements LocalCatalogStorage {
  SharedPreferencesLocalCatalogStorage(this._preferences);

  static const String storageKey = 'bar_local_catalog_v2';

  final SharedPreferences _preferences;

  @override
  LocalCatalogData read() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return LocalCatalogData.empty();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return LocalCatalogData.empty();
      }
      return LocalCatalogData.fromJson(decoded);
    } catch (_) {
      return LocalCatalogData.empty();
    }
  }

  @override
  Future<void> write(LocalCatalogData data) {
    return _preferences.setString(storageKey, jsonEncode(data.toJson()));
  }
}

class InMemoryLocalCatalogStorage implements LocalCatalogStorage {
  InMemoryLocalCatalogStorage({LocalCatalogData? initial})
    : _data = initial ?? LocalCatalogData.empty();

  LocalCatalogData _data;

  @override
  LocalCatalogData read() => _data;

  @override
  Future<void> write(LocalCatalogData data) async {
    _data = data;
  }
}
