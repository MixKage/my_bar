import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/domain/models/catalog_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists catalog data source setting', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesBarUiSettingsStorage(preferences);

    await storage.writeSettings(
      const BarUiSettings(
        visitorMode: true,
        barMenuOnlyMode: true,
        powerSavingMode: true,
        catalogDataSource: CatalogDataSource.theCocktailDb,
        appLanguage: AppLanguage.english,
      ),
    );

    final settings = storage.readSettings();
    expect(settings.visitorMode, isTrue);
    expect(settings.barMenuOnlyMode, isTrue);
    expect(settings.powerSavingMode, isTrue);
    expect(settings.catalogDataSource, CatalogDataSource.theCocktailDb);
    expect(settings.appLanguage, AppLanguage.english);
  });

  test('keeps catalog source null when it was not selected', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesBarUiSettingsStorage(preferences);

    await storage.writeSettings(
      const BarUiSettings(visitorMode: false, barMenuOnlyMode: false),
    );

    final settings = storage.readSettings();
    expect(settings.catalogDataSource, isNull);
    expect(settings.powerSavingMode, isFalse);
    expect(settings.appLanguage, AppLanguage.system);
  });
}
