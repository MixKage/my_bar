import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/bar_catalog.dart';
import 'bar_catalog_json_codec.dart';

abstract class BarCatalogStorage {
  BarCatalog? readCatalog();
  Future<void> writeCatalog(BarCatalog catalog);
}

class SharedPreferencesBarCatalogStorage implements BarCatalogStorage {
  SharedPreferencesBarCatalogStorage(
    this._preferences, {
    this.codec = const BarCatalogJsonCodec(),
  });

  static const String storageKey = 'bar_catalog_v1';

  final SharedPreferences _preferences;
  final BarCatalogJsonCodec codec;

  @override
  BarCatalog? readCatalog() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return codec.decode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> writeCatalog(BarCatalog catalog) {
    return _preferences.setString(storageKey, codec.encode(catalog));
  }
}

class InMemoryBarCatalogStorage implements BarCatalogStorage {
  InMemoryBarCatalogStorage({BarCatalog? initial}) : _catalog = initial;

  BarCatalog? _catalog;

  @override
  BarCatalog? readCatalog() => _catalog;

  @override
  Future<void> writeCatalog(BarCatalog catalog) async {
    _catalog = catalog;
  }
}
