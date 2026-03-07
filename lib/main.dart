import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/my_bar_app.dart';
import 'core/localization/app_language.dart';
import 'features/bar/data/bar_catalog_json_codec.dart';
import 'features/bar/data/bar_catalog_storage.dart';
import 'features/bar/data/bar_ui_settings_storage.dart';
import 'features/bar/data/catalog_overrides_storage.dart';
import 'features/bar/data/external_catalog_cache_storage.dart';
import 'features/bar/data/ingredient_selection_storage.dart';
import 'features/bar/data/local_catalog_storage.dart';
import 'features/bar/data/models/catalog_layer_models.dart';
import 'features/bar/data/providers/external_bar_data_provider.dart';
import 'features/bar/data/repositories/bar_catalog_repository.dart';
import 'features/bar/domain/models/bar_catalog.dart';
import 'features/bar/domain/models/catalog_data_source.dart';
import 'features/bar/domain/models/cocktail.dart';
import 'features/bar/domain/models/ingredient.dart';

export 'app/my_bar_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await _bootstrapApp();
  runApp(
    MyBarApp(
      selectionStorage: bootstrap.selectionStorage,
      settingsStorage: bootstrap.settingsStorage,
      catalogRepository: bootstrap.catalogRepository,
      externalProviderSelector: bootstrap.externalProviderSelector,
      initialSnapshot: bootstrap.initialSnapshot,
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
    final settingsStorage = SharedPreferencesBarUiSettingsStorage(preferences);

    final localStorage = SharedPreferencesLocalCatalogStorage(preferences);
    final overridesStorage = SharedPreferencesCatalogOverridesStorage(
      preferences,
    );
    final externalCacheStorage = SharedPreferencesExternalCatalogCacheStorage(
      preferences,
    );

    final legacyStorage = SharedPreferencesBarCatalogStorage(preferences);
    final legacyCatalog = legacyStorage.readCatalog();
    final templateCatalog = await _loadTemplateCatalog(codec);

    final externalProviders = _buildExternalProviderBundle(
      settingsStorage: settingsStorage,
    );
    final externalProviderSelector = SelectableExternalBarDataProvider(
      seedProvider: externalProviders.seedProvider,
      bootstrapDefaultProvider: externalProviders.bootstrapDefaultProvider,
      bootstrapDefaultDataSource: externalProviders.bootstrapDefaultDataSource,
      theCocktailDbProvider: externalProviders.theCocktailDbProvider,
    );
    final repository = BarCatalogRepository(
      externalProvider: externalProviderSelector,
      externalCacheStorage: externalCacheStorage,
      localStorage: localStorage,
      overridesStorage: overridesStorage,
      templateCatalog: templateCatalog,
    );

    final initialSnapshot = await repository.initialize(
      legacyCatalog: legacyCatalog,
    );

    return _BootstrapData(
      selectionStorage: selectionStorage,
      settingsStorage: settingsStorage,
      catalogRepository: repository,
      externalProviderSelector: externalProviderSelector,
      initialSnapshot: initialSnapshot,
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

    final templateCatalog = await _safeFallbackCatalog(codec);
    final fallbackSeedProvider = JsonAssetExternalBarDataProvider(
      assetPath: 'assets/data/bar_template.json',
    );
    final fallbackSelector = SelectableExternalBarDataProvider(
      seedProvider: fallbackSeedProvider,
      bootstrapDefaultProvider: fallbackSeedProvider,
      bootstrapDefaultDataSource: CatalogDataSource.seed,
    );
    final fallbackRepository = BarCatalogRepository(
      externalProvider: fallbackSelector,
      externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
      localStorage: InMemoryLocalCatalogStorage(),
      overridesStorage: InMemoryCatalogOverridesStorage(),
      templateCatalog: templateCatalog,
    );

    final fallbackSnapshot = await fallbackRepository.initialize();

    return _BootstrapData(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      settingsStorage: InMemoryBarUiSettingsStorage(),
      catalogRepository: fallbackRepository,
      externalProviderSelector: fallbackSelector,
      initialSnapshot: fallbackSnapshot,
    );
  }
}

_ExternalProviderBundle _buildExternalProviderBundle({
  required BarUiSettingsStorage settingsStorage,
}) {
  final assetProvider = LocalizedJsonAssetExternalBarDataProvider(
    defaultAssetPath: 'assets/data/bar_template.json',
    russianAssetPath: 'assets/data/bar_template_ru.json',
    useRussianCatalogResolver: () =>
        _shouldUseRussianCatalog(settingsStorage.readSettings().appLanguage),
    sourceIdValue: 'asset_template',
  );
  return _ExternalProviderBundle(
    seedProvider: assetProvider,
    bootstrapDefaultProvider: assetProvider,
    bootstrapDefaultDataSource: CatalogDataSource.seed,
    theCocktailDbProvider: null,
  );
}

bool _shouldUseRussianCatalog(AppLanguage appLanguage) {
  switch (appLanguage) {
    case AppLanguage.russian:
      return true;
    case AppLanguage.english:
      return false;
    case AppLanguage.system:
      final localeLanguageCode = WidgetsBinding
          .instance
          .platformDispatcher
          .locale
          .languageCode
          .toLowerCase();
      return localeLanguageCode == 'ru';
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
    required this.settingsStorage,
    required this.catalogRepository,
    required this.externalProviderSelector,
    required this.initialSnapshot,
  });

  final IngredientSelectionStorage selectionStorage;
  final BarUiSettingsStorage settingsStorage;
  final BarCatalogRepository catalogRepository;
  final SelectableExternalBarDataProvider externalProviderSelector;
  final UnifiedCatalogSnapshot initialSnapshot;
}

class _ExternalProviderBundle {
  const _ExternalProviderBundle({
    required this.seedProvider,
    required this.bootstrapDefaultProvider,
    required this.bootstrapDefaultDataSource,
    required this.theCocktailDbProvider,
  });

  final ExternalBarDataProvider seedProvider;
  final ExternalBarDataProvider bootstrapDefaultProvider;
  final CatalogDataSource bootstrapDefaultDataSource;
  final ExternalBarDataProvider? theCocktailDbProvider;
}
