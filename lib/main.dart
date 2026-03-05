import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/my_bar_app.dart';
import 'features/bar/data/bar_catalog_json_codec.dart';
import 'features/bar/data/bar_catalog_storage.dart';
import 'features/bar/data/bar_ui_settings_storage.dart';
import 'features/bar/data/ingredient_selection_storage.dart';
import 'features/bar/domain/models/bar_catalog.dart';
import 'features/bar/domain/models/cocktail.dart';
import 'features/bar/domain/models/ingredient.dart';

export 'app/my_bar_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await _bootstrapApp();
  runApp(
    MyBarApp(
      selectionStorage: bootstrap.selectionStorage,
      catalogStorage: bootstrap.catalogStorage,
      settingsStorage: bootstrap.settingsStorage,
      initialCatalog: bootstrap.initialCatalog,
      templateCatalog: bootstrap.templateCatalog,
    ),
  );
}

Future<_BootstrapData> _bootstrapApp() async {
  final codec = const BarCatalogJsonCodec();

  try {
    final preferences = await SharedPreferences.getInstance();
    final selectionStorage = SharedPreferencesIngredientSelectionStorage(
      preferences,
    );
    final catalogStorage = SharedPreferencesBarCatalogStorage(preferences);
    final settingsStorage = SharedPreferencesBarUiSettingsStorage(preferences);

    final template = await _loadTemplateCatalog(codec);
    final storedCatalog = catalogStorage.readCatalog();

    return _BootstrapData(
      selectionStorage: selectionStorage,
      catalogStorage: catalogStorage,
      settingsStorage: settingsStorage,
      initialCatalog: storedCatalog ?? template,
      templateCatalog: template,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'my_bar bootstrap',
        context: ErrorDescription('while bootstrapping storages and template'),
      ),
    );

    final fallbackCatalog = await _safeFallbackCatalog(codec);
    return _BootstrapData(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(initial: fallbackCatalog),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      initialCatalog: fallbackCatalog,
      templateCatalog: fallbackCatalog,
    );
  }
}

Future<BarCatalog> _loadTemplateCatalog(BarCatalogJsonCodec codec) async {
  final json = await rootBundle.loadString('assets/data/bar_template.json');
  return codec.decode(json);
}

Future<BarCatalog> _safeFallbackCatalog(BarCatalogJsonCodec codec) async {
  try {
    return await _loadTemplateCatalog(codec);
  } catch (_) {
    return BarCatalog(ingredients: <Ingredient>[], cocktails: <Cocktail>[]);
  }
}

class _BootstrapData {
  const _BootstrapData({
    required this.selectionStorage,
    required this.catalogStorage,
    required this.settingsStorage,
    required this.initialCatalog,
    required this.templateCatalog,
  });

  final IngredientSelectionStorage selectionStorage;
  final BarCatalogStorage catalogStorage;
  final BarUiSettingsStorage settingsStorage;
  final BarCatalog initialCatalog;
  final BarCatalog templateCatalog;
}
