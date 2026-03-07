import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/catalog_data_source.dart';

class BarUiSettings {
  const BarUiSettings({
    this.visitorMode = false,
    this.barMenuOnlyMode = false,
    this.catalogDataSource,
  });

  final bool visitorMode;
  final bool barMenuOnlyMode;
  final CatalogDataSource? catalogDataSource;

  BarUiSettings copyWith({
    bool? visitorMode,
    bool? barMenuOnlyMode,
    CatalogDataSource? catalogDataSource,
    bool clearCatalogDataSource = false,
  }) {
    return BarUiSettings(
      visitorMode: visitorMode ?? this.visitorMode,
      barMenuOnlyMode: barMenuOnlyMode ?? this.barMenuOnlyMode,
      catalogDataSource: clearCatalogDataSource
          ? null
          : (catalogDataSource ?? this.catalogDataSource),
    );
  }
}

abstract class BarUiSettingsStorage {
  BarUiSettings readSettings();
  Future<void> writeSettings(BarUiSettings settings);
}

class SharedPreferencesBarUiSettingsStorage implements BarUiSettingsStorage {
  SharedPreferencesBarUiSettingsStorage(this._preferences);

  static const String visitorModeKey = 'bar_ui_visitor_mode';
  static const String barMenuOnlyModeKey = 'bar_ui_bar_menu_only_mode';
  static const String catalogDataSourceKey = 'bar_ui_catalog_data_source';

  final SharedPreferences _preferences;

  @override
  BarUiSettings readSettings() {
    final sourceRaw = _preferences.getString(catalogDataSourceKey);
    return BarUiSettings(
      visitorMode: _preferences.getBool(visitorModeKey) ?? false,
      barMenuOnlyMode: _preferences.getBool(barMenuOnlyModeKey) ?? false,
      catalogDataSource: CatalogDataSourceX.tryParse(sourceRaw),
    );
  }

  @override
  Future<void> writeSettings(BarUiSettings settings) async {
    final futures = <Future<void>>[
      _preferences.setBool(visitorModeKey, settings.visitorMode),
      _preferences.setBool(barMenuOnlyModeKey, settings.barMenuOnlyMode),
    ];

    final catalogSource = settings.catalogDataSource;
    if (catalogSource == null) {
      futures.add(_preferences.remove(catalogDataSourceKey));
    } else {
      futures.add(
        _preferences.setString(
          catalogDataSourceKey,
          catalogSource.storageValue,
        ),
      );
    }

    await Future.wait<void>(futures);
  }
}

class InMemoryBarUiSettingsStorage implements BarUiSettingsStorage {
  InMemoryBarUiSettingsStorage({BarUiSettings? initial})
    : _settings = initial ?? const BarUiSettings();

  BarUiSettings _settings;

  @override
  BarUiSettings readSettings() => _settings;

  @override
  Future<void> writeSettings(BarUiSettings settings) async {
    _settings = settings;
  }
}
