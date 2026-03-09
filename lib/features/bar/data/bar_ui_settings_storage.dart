import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_language.dart';
import '../domain/models/catalog_data_source.dart';
import '../domain/models/measurement_system.dart';

class BarUiSettings {
  const BarUiSettings({
    this.visitorMode = false,
    this.barMenuOnlyMode = false,
    this.powerSavingMode = false,
    this.catalogDataSource,
    this.appLanguage = AppLanguage.system,
    this.measurementSystem = MeasurementSystem.flOz,
  });

  final bool visitorMode;
  final bool barMenuOnlyMode;
  final bool powerSavingMode;
  final CatalogDataSource? catalogDataSource;
  final AppLanguage appLanguage;
  final MeasurementSystem measurementSystem;

  BarUiSettings copyWith({
    bool? visitorMode,
    bool? barMenuOnlyMode,
    bool? powerSavingMode,
    CatalogDataSource? catalogDataSource,
    AppLanguage? appLanguage,
    MeasurementSystem? measurementSystem,
    bool clearCatalogDataSource = false,
  }) {
    return BarUiSettings(
      visitorMode: visitorMode ?? this.visitorMode,
      barMenuOnlyMode: barMenuOnlyMode ?? this.barMenuOnlyMode,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
      catalogDataSource: clearCatalogDataSource
          ? null
          : (catalogDataSource ?? this.catalogDataSource),
      appLanguage: appLanguage ?? this.appLanguage,
      measurementSystem: measurementSystem ?? this.measurementSystem,
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
  static const String powerSavingModeKey = 'bar_ui_power_saving_mode';
  static const String catalogDataSourceKey = 'bar_ui_catalog_data_source';
  static const String appLanguageKey = 'bar_ui_app_language';
  static const String measurementSystemKey = 'bar_ui_measurement_system';

  final SharedPreferences _preferences;

  @override
  BarUiSettings readSettings() {
    final sourceRaw = _preferences.getString(catalogDataSourceKey);
    return BarUiSettings(
      visitorMode: _preferences.getBool(visitorModeKey) ?? false,
      barMenuOnlyMode: _preferences.getBool(barMenuOnlyModeKey) ?? false,
      powerSavingMode: _preferences.getBool(powerSavingModeKey) ?? false,
      catalogDataSource: CatalogDataSourceX.tryParse(sourceRaw),
      appLanguage: AppLanguageX.fromStorage(
        _preferences.getString(appLanguageKey),
      ),
      measurementSystem: MeasurementSystemX.fromStorage(
        _preferences.getString(measurementSystemKey),
      ),
    );
  }

  @override
  Future<void> writeSettings(BarUiSettings settings) async {
    final futures = <Future<void>>[
      _preferences.setBool(visitorModeKey, settings.visitorMode),
      _preferences.setBool(barMenuOnlyModeKey, settings.barMenuOnlyMode),
      _preferences.setBool(powerSavingModeKey, settings.powerSavingMode),
      _preferences.setString(appLanguageKey, settings.appLanguage.storageValue),
      _preferences.setString(
        measurementSystemKey,
        settings.measurementSystem.storageValue,
      ),
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
