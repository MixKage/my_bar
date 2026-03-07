import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/catalog_layer_models.dart';

abstract class CatalogOverridesStorage {
  OverridesCatalogData read();
  Future<void> write(OverridesCatalogData data);
}

class SharedPreferencesCatalogOverridesStorage
    implements CatalogOverridesStorage {
  SharedPreferencesCatalogOverridesStorage(this._preferences);

  static const String storageKey = 'bar_catalog_overrides_v2';

  final SharedPreferences _preferences;

  @override
  OverridesCatalogData read() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return OverridesCatalogData.empty();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return OverridesCatalogData.empty();
      }
      return OverridesCatalogData.fromJson(decoded);
    } catch (_) {
      return OverridesCatalogData.empty();
    }
  }

  @override
  Future<void> write(OverridesCatalogData data) {
    return _preferences.setString(storageKey, jsonEncode(data.toJson()));
  }
}

class InMemoryCatalogOverridesStorage implements CatalogOverridesStorage {
  InMemoryCatalogOverridesStorage({OverridesCatalogData? initial})
    : _data = initial ?? OverridesCatalogData.empty();

  OverridesCatalogData _data;

  @override
  OverridesCatalogData read() => _data;

  @override
  Future<void> write(OverridesCatalogData data) async {
    _data = data;
  }
}
