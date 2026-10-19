import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/features/bar/cubit/bar_cubit.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/data/catalog_overrides_storage.dart';
import 'package:my_bar/features/bar/data/external_catalog_cache_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/data/local_catalog_storage.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/data/repositories/bar_catalog_repository.dart';
import 'package:my_bar/features/bar/data/shopping_list_storage.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/catalog_data_source.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

void main() {
  test(
    'a slow earlier language load cannot overwrite the latest choice',
    () async {
      final harness = await _createHarness();
      addTearDown(harness.cubit.close);
      final emittedRecipeNames = <String>[];
      final subscription = harness.cubit.stream.listen(
        (state) => emittedRecipeNames.add(state.cocktails.single.name),
      );
      addTearDown(subscription.cancel);

      final blocked = harness.provider.blockNextSnapshot();
      addTearDown(blocked.unblock);
      final spanish = harness.cubit.setAppLanguage(AppLanguage.spanish);
      await blocked.started.future.timeout(const Duration(seconds: 5));
      expect(harness.provider.loadedLanguages.last, 'es');

      final french = harness.cubit.setAppLanguage(AppLanguage.french);
      expect(harness.cubit.state.appLanguage, AppLanguage.french);
      // The older load is still in progress while the user's latest choice is
      // already visible. Its result must never replace the catalog on screen.
      blocked.unblock();
      await Future.wait<void>([spanish, french]);

      expect(harness.cubit.state.appLanguage, AppLanguage.french);
      expect(harness.settings.readSettings().appLanguage, AppLanguage.french);
      expect(harness.cubit.state.cocktails.single.name, 'Recipe fr');
      expect(
        harness.cubit.state.ingredients.map((ingredient) => ingredient.name),
        containsAll(<String>['Gin fr', 'Vermouth fr']),
      );
      expect(
        harness.repository.snapshot.cocktailItems.single.name,
        'Recipe fr',
      );
      expect(emittedRecipeNames, isNot(contains('Recipe es')));
      expect(harness.provider.loadedLanguages, <String>['en', 'es', 'fr']);
    },
  );

  test(
    'system locale refresh keeps selections, favorites and user edits',
    () async {
      var systemCode = 'en';
      final harness = await _createHarness(
        appLanguage: AppLanguage.system,
        systemLanguageResolver: () => systemCode,
      );
      addTearDown(harness.cubit.close);
      await harness.cubit.toggleIngredient('gin');
      await harness.cubit.toggleShoppingIngredient('vermouth');
      await harness.cubit.toggleCocktailFavorite('recipe');
      await harness.cubit.updateCocktailPreparation(
        cocktailId: 'recipe',
        preparationSteps: <String>['My preparation note'],
      );
      await harness.cubit.updateIngredient(
        ingredientId: 'gin',
        name: 'My gin',
        category: 'Spirits',
        image: '',
      );

      systemCode = 'es';
      await harness.cubit.refreshLocalizedCatalog();

      final state = harness.cubit.state;
      expect(state.appLanguage, AppLanguage.system);
      expect(harness.settings.readSettings().appLanguage, AppLanguage.system);
      expect(state.selectedIngredientIds, <String>{'gin'});
      expect(state.shoppingIngredientIds, <String>{'vermouth'});
      expect(harness.selection.readSelectedIngredientIds(), <String>{'gin'});
      expect(harness.shopping.readIngredientIds(), <String>{'vermouth'});
      expect(state.cocktails.single.name, 'Recipe es');
      expect(state.cocktails.single.isFavorite, isTrue);
      expect(state.cocktails.single.preparationSteps, <String>[
        'My preparation note',
      ]);
      expect(state.ingredientsById['gin']!.name, 'My gin');
      expect(state.ingredientsById['vermouth']!.name, 'Vermouth es');
      expect(harness.repository.hasUserChanges, isTrue);
    },
  );

  test(
    'favorite during a superseded load does not pin stale recipe text',
    () async {
      final harness = await _createHarness();
      addTearDown(harness.cubit.close);
      final blockedSpanish = harness.provider.blockNextSnapshot();
      addTearDown(blockedSpanish.unblock);
      final spanish = harness.cubit.setAppLanguage(AppLanguage.spanish);
      await blockedSpanish.started.future.timeout(const Duration(seconds: 5));

      final blockedFrench = harness.provider.blockNextSnapshot();
      addTearDown(blockedFrench.unblock);
      final french = harness.cubit.setAppLanguage(AppLanguage.french);
      blockedSpanish.unblock();
      await blockedFrench.started.future.timeout(const Duration(seconds: 5));
      await harness.cubit.toggleCocktailFavorite('recipe');
      blockedFrench.unblock();
      await Future.wait<void>([spanish, french]);

      expect(harness.cubit.state.cocktails.single.isFavorite, isTrue);
      expect(harness.cubit.state.cocktails.single.name, 'Recipe fr');
      expect(
        harness.cubit.state.cocktails.single.description,
        'Description fr',
      );
      expect(harness.cubit.state.cocktails.single.preparationSteps, <String>[
        'Stir fr',
      ]);
    },
  );
}

Future<_Harness> _createHarness({
  AppLanguage appLanguage = AppLanguage.english,
  String Function()? systemLanguageResolver,
}) async {
  final settings = InMemoryBarUiSettingsStorage(
    initial: BarUiSettings(appLanguage: appLanguage),
  );
  final selection = InMemoryIngredientSelectionStorage();
  final shopping = InMemoryShoppingListStorage();
  final provider = _LocalizedSnapshotProvider(() {
    final language = settings.readSettings().appLanguage;
    return language == AppLanguage.system
        ? systemLanguageResolver!()
        : language.locale!.languageCode;
  });
  final selector = SelectableExternalBarDataProvider(
    seedProvider: provider,
    bootstrapDefaultProvider: provider,
    bootstrapDefaultDataSource: CatalogDataSource.seed,
  );
  final repository = BarCatalogRepository(
    externalProvider: selector,
    externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
    localStorage: InMemoryLocalCatalogStorage(),
    overridesStorage: InMemoryCatalogOverridesStorage(),
    templateCatalog: _catalog('en'),
  );
  final snapshot = await repository.initialize();
  final cubit = BarCubit(
    selectionStorage: selection,
    shoppingListStorage: shopping,
    settingsStorage: settings,
    catalogRepository: repository,
    externalProviderSelector: selector,
    initialSnapshot: snapshot,
  );
  return _Harness(cubit, provider, settings, selection, shopping, repository);
}

class _Harness {
  const _Harness(
    this.cubit,
    this.provider,
    this.settings,
    this.selection,
    this.shopping,
    this.repository,
  );

  final BarCubit cubit;
  final _LocalizedSnapshotProvider provider;
  final InMemoryBarUiSettingsStorage settings;
  final InMemoryIngredientSelectionStorage selection;
  final InMemoryShoppingListStorage shopping;
  final BarCatalogRepository repository;
}

class _BlockedSnapshot {
  final started = Completer<void>();
  final _released = Completer<void>();

  void unblock() {
    if (!_released.isCompleted) _released.complete();
  }
}

class _LocalizedSnapshotProvider
    implements ExternalBarDataProvider, CatalogSnapshotProvider {
  _LocalizedSnapshotProvider(this.languageResolver);

  final String Function() languageResolver;
  final List<String> loadedLanguages = <String>[];
  _BlockedSnapshot? _blocked;

  _BlockedSnapshot blockNextSnapshot() {
    final blocked = _BlockedSnapshot();
    _blocked = blocked;
    return blocked;
  }

  @override
  String get sourceId => 'localized_test';

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<ExternalCatalogPayload> fetchCatalogSnapshot() async {
    final code = languageResolver();
    loadedLanguages.add(code);
    final blocked = _blocked;
    _blocked = null;
    if (blocked != null) {
      blocked.started.complete();
      await blocked._released.future;
    }
    final catalog = _catalog(code);
    return ExternalCatalogPayload(
      ingredients: catalog.ingredients.map((item) => item.toJson()).toList(),
      cocktails: catalog.cocktails.map((item) => item.toJson()).toList(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() =>
      throw StateError('The repository must use an atomic catalog snapshot');

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() =>
      throw StateError('The repository must use an atomic catalog snapshot');
}

BarCatalog _catalog(String code) => BarCatalog(
  ingredients: <Ingredient>[
    Ingredient(id: 'gin', name: 'Gin $code', category: 'Spirits', image: ''),
    Ingredient(
      id: 'vermouth',
      name: 'Vermouth $code',
      category: 'Aperitifs',
      image: '',
    ),
  ],
  cocktails: <Cocktail>[
    Cocktail(
      id: 'recipe',
      name: 'Recipe $code',
      image: '',
      ingredients: const <String>['gin', 'vermouth'],
      description: 'Description $code',
      preparationSteps: <String>['Stir $code'],
      glassType: 'Рокс',
      tags: const <String>[],
      ingredientAmounts: const <String, String>{'gin': '50', 'vermouth': '10'},
      ingredientUnits: const <String, String>{'gin': 'мл', 'vermouth': 'мл'},
    ),
  ],
);
