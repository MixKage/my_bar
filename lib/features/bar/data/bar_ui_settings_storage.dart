import 'package:shared_preferences/shared_preferences.dart';

class BarUiSettings {
  const BarUiSettings({this.visitorMode = false, this.barMenuOnlyMode = false});

  final bool visitorMode;
  final bool barMenuOnlyMode;

  BarUiSettings copyWith({bool? visitorMode, bool? barMenuOnlyMode}) {
    return BarUiSettings(
      visitorMode: visitorMode ?? this.visitorMode,
      barMenuOnlyMode: barMenuOnlyMode ?? this.barMenuOnlyMode,
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

  final SharedPreferences _preferences;

  @override
  BarUiSettings readSettings() {
    return BarUiSettings(
      visitorMode: _preferences.getBool(visitorModeKey) ?? false,
      barMenuOnlyMode: _preferences.getBool(barMenuOnlyModeKey) ?? false,
    );
  }

  @override
  Future<void> writeSettings(BarUiSettings settings) async {
    await Future.wait<void>(<Future<void>>[
      _preferences.setBool(visitorModeKey, settings.visitorMode),
      _preferences.setBool(barMenuOnlyModeKey, settings.barMenuOnlyMode),
    ]);
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
