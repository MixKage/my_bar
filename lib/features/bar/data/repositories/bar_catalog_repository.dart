import '../../domain/models/bar_catalog.dart';
import '../../domain/models/catalog_entity_origin.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../adapters/catalog_normalizers.dart';
import '../adapters/the_cocktail_db_normalizer.dart';
import '../catalog_overrides_storage.dart';
import '../external_catalog_cache_storage.dart';
import '../local_catalog_storage.dart';
import '../migrations/legacy_catalog_migrator.dart';
import '../models/catalog_layer_models.dart';
import '../providers/external_bar_data_provider.dart';
import '../utils/catalog_id_utils.dart';

class BarCatalogRepository {
  BarCatalogRepository({
    required ExternalBarDataProvider externalProvider,
    required ExternalCatalogCacheStorage externalCacheStorage,
    required LocalCatalogStorage localStorage,
    required CatalogOverridesStorage overridesStorage,
    required BarCatalog templateCatalog,
  }) : _externalProvider = externalProvider,
       _externalCacheStorage = externalCacheStorage,
       _localStorage = localStorage,
       _overridesStorage = overridesStorage,
       _templateCatalog = templateCatalog;

  final ExternalBarDataProvider _externalProvider;
  final ExternalCatalogCacheStorage _externalCacheStorage;
  final LocalCatalogStorage _localStorage;
  final CatalogOverridesStorage _overridesStorage;
  final BarCatalog _templateCatalog;

  ExternalCatalogData _externalData = ExternalCatalogData.empty(
    source: 'template_seed',
  );
  LocalCatalogData _localData = LocalCatalogData.empty();
  OverridesCatalogData _overridesData = OverridesCatalogData.empty();
  UnifiedCatalogSnapshot _snapshot = UnifiedCatalogSnapshot(
    ingredients: const <UnifiedIngredient>[],
    cocktails: const <UnifiedCocktail>[],
    externalSourceAvailable: false,
  );

  bool _isInitialized = false;

  UnifiedCatalogSnapshot get snapshot => _snapshot;

  bool get hasUserChanges => !_localData.isEmpty || !_overridesData.isEmpty;

  Future<UnifiedCatalogSnapshot> initialize({BarCatalog? legacyCatalog}) async {
    _localData = _localStorage.read();
    _overridesData = _sanitizeOverrides(_overridesStorage.read());

    final externalLoadResult = await _loadExternalData();
    _externalData = externalLoadResult.data;

    if (_localData.isEmpty && _overridesData.isEmpty && legacyCatalog != null) {
      final migrationBaseline = _externalData.isEmpty
          ? _toTemplateExternalData(source: 'template_seed')
          : _externalData;
      final migrationResult = LegacyCatalogMigrator(
        externalBaseline: migrationBaseline,
      ).migrate(legacyCatalog);

      if (!migrationResult.isEmpty) {
        _localData = migrationResult.localData;
        _overridesData = _sanitizeOverrides(migrationResult.overridesData);
        await _persistLocalAndOverrides();
      }
    }

    _snapshot = _composeSnapshot(
      externalSourceAvailable: externalLoadResult.externalSourceAvailable,
    );
    _isInitialized = true;
    return _snapshot;
  }

  Future<UnifiedCatalogSnapshot> addIngredient(Ingredient ingredient) async {
    _ensureInitialized();

    final localId = _createUniqueLocalId(
      prefix: 'ingredient',
      seed: ingredient.id,
      existing: _localData.ingredients.map((item) => item.localId).toSet(),
    );

    final localIngredient = LocalIngredient(
      localId: localId,
      canonicalSlug: canonicalFromValue(ingredient.id),
      ingredient: ingredient,
    );

    _localData = _localData.copyWith(
      ingredients: <LocalIngredient>[
        ..._localData.ingredients,
        localIngredient,
      ],
    );

    await _persistAndRefresh();
    return _snapshot;
  }

  Future<UnifiedCatalogSnapshot> updateIngredient(Ingredient ingredient) async {
    _ensureInitialized();

    final unifiedIngredient = _snapshot.ingredients.firstWhere(
      (item) => item.ingredient.id == ingredient.id,
      orElse: () => throw const FormatException('Ингредиент не найден.'),
    );

    if (unifiedIngredient.origin == CatalogEntityOrigin.local) {
      _localData = _localData.copyWith(
        ingredients: _localData.ingredients
            .map((item) {
              if (item.ingredient.id != ingredient.id) {
                return item;
              }
              return LocalIngredient(
                localId: item.localId,
                canonicalSlug: item.canonicalSlug,
                ingredient: ingredient,
              );
            })
            .toList(growable: false),
      );
      await _persistAndRefresh();
      return _snapshot;
    }

    final external = _externalData.ingredients.firstWhere(
      (item) => item.ingredient.id == ingredient.id,
      orElse: () => throw const FormatException('Ингредиент не найден.'),
    );

    final patch = IngredientPatch.fromDiff(
      baseline: external.ingredient,
      updated: ingredient,
    );

    final existing = _overridesData.ingredientOverrides
        .where((item) => item.key != external.identity.unifiedKey)
        .toList();

    if (!patch.isEmpty) {
      existing.add(
        IngredientOverride(
          source: external.identity.source,
          sourceId: external.identity.sourceId,
          patch: patch,
        ),
      );
    }

    _overridesData = _overridesData.copyWith(ingredientOverrides: existing);
    _overridesData = _sanitizeOverrides(_overridesData);

    await _persistAndRefresh();
    return _snapshot;
  }

  Future<UnifiedCatalogSnapshot> addCocktail(Cocktail cocktail) async {
    _ensureInitialized();

    final localId = _createUniqueLocalId(
      prefix: 'cocktail',
      seed: cocktail.id,
      existing: _localData.cocktails.map((item) => item.localId).toSet(),
    );

    final localCocktail = LocalCocktail(
      localId: localId,
      canonicalSlug: canonicalFromValue(cocktail.id),
      cocktail: cocktail,
    );

    _localData = _localData.copyWith(
      cocktails: <LocalCocktail>[..._localData.cocktails, localCocktail],
    );

    await _persistAndRefresh();
    return _snapshot;
  }

  Future<UnifiedCatalogSnapshot> updateCocktail(Cocktail cocktail) async {
    _ensureInitialized();

    final unifiedCocktail = _snapshot.cocktails.firstWhere(
      (item) => item.cocktail.id == cocktail.id,
      orElse: () => throw const FormatException('Коктейль не найден.'),
    );

    if (unifiedCocktail.origin == CatalogEntityOrigin.local) {
      _localData = _localData.copyWith(
        cocktails: _localData.cocktails
            .map((item) {
              if (item.cocktail.id != cocktail.id) {
                return item;
              }
              return LocalCocktail(
                localId: item.localId,
                canonicalSlug: item.canonicalSlug,
                cocktail: cocktail,
              );
            })
            .toList(growable: false),
      );
      await _persistAndRefresh();
      return _snapshot;
    }

    final external = _externalData.cocktails.firstWhere(
      (item) => item.cocktail.id == cocktail.id,
      orElse: () => throw const FormatException('Коктейль не найден.'),
    );

    final patch = CocktailPatch.fromDiff(
      baseline: external.cocktail,
      updated: cocktail,
    );

    final existing = _overridesData.cocktailOverrides
        .where((item) => item.key != external.identity.unifiedKey)
        .toList();

    if (!patch.isEmpty) {
      existing.add(
        CocktailOverride(
          source: external.identity.source,
          sourceId: external.identity.sourceId,
          patch: patch,
        ),
      );
    }

    _overridesData = _overridesData.copyWith(cocktailOverrides: existing);
    _overridesData = _sanitizeOverrides(_overridesData);

    await _persistAndRefresh();
    return _snapshot;
  }

  Future<UnifiedCatalogSnapshot> removeCocktail(String cocktailId) async {
    _ensureInitialized();

    final unifiedCocktail = _snapshot.cocktails.firstWhere(
      (item) => item.cocktail.id == cocktailId,
      orElse: () => throw const FormatException('Коктейль не найден.'),
    );

    if (unifiedCocktail.origin == CatalogEntityOrigin.local) {
      _localData = _localData.copyWith(
        cocktails: _localData.cocktails
            .where((item) => item.cocktail.id != cocktailId)
            .toList(growable: false),
      );
      await _persistAndRefresh();
      return _snapshot;
    }

    final external = _externalData.cocktails.firstWhere(
      (item) => item.cocktail.id == cocktailId,
      orElse: () => throw const FormatException('Коктейль не найден.'),
    );

    final remaining =
        _overridesData.cocktailOverrides
            .where((item) => item.key != external.identity.unifiedKey)
            .toList(growable: false)
          ..add(
            CocktailOverride(
              source: external.identity.source,
              sourceId: external.identity.sourceId,
              isHidden: true,
            ),
          );

    _overridesData = _sanitizeOverrides(
      _overridesData.copyWith(cocktailOverrides: remaining),
    );

    await _persistAndRefresh();
    return _snapshot;
  }

  Future<UnifiedCatalogSnapshot> importCatalog(BarCatalog catalog) async {
    _ensureInitialized();

    final externalIngredientsById = <String, ExternalIngredient>{
      for (final item in _externalData.ingredients) item.ingredient.id: item,
    };
    final externalCocktailsById = <String, ExternalCocktail>{
      for (final item in _externalData.cocktails) item.cocktail.id: item,
    };

    final localIngredients = <LocalIngredient>[];
    final ingredientOverrides = <IngredientOverride>[];
    final localIngredientIds = <String>{};
    for (final ingredient in catalog.ingredients) {
      final external = externalIngredientsById[ingredient.id];
      if (external == null) {
        final localId = _createUniqueLocalId(
          prefix: 'ingredient',
          seed: ingredient.id,
          existing: localIngredientIds,
        );
        localIngredientIds.add(localId);
        localIngredients.add(
          LocalIngredient(
            localId: localId,
            canonicalSlug: canonicalFromValue(ingredient.id),
            ingredient: ingredient,
          ),
        );
        continue;
      }

      final patch = IngredientPatch.fromDiff(
        baseline: external.ingredient,
        updated: ingredient,
      );
      if (patch.isEmpty) {
        continue;
      }
      ingredientOverrides.add(
        IngredientOverride(
          source: external.identity.source,
          sourceId: external.identity.sourceId,
          patch: patch,
        ),
      );
    }

    final importedIngredientIds = catalog.ingredients
        .map((ingredient) => ingredient.id)
        .toSet();
    for (final external in _externalData.ingredients) {
      if (importedIngredientIds.contains(external.ingredient.id)) {
        continue;
      }
      ingredientOverrides.add(
        IngredientOverride(
          source: external.identity.source,
          sourceId: external.identity.sourceId,
          isHidden: true,
        ),
      );
    }

    final localCocktails = <LocalCocktail>[];
    final cocktailOverrides = <CocktailOverride>[];
    final localCocktailIds = <String>{};
    for (final cocktail in catalog.cocktails) {
      final external = externalCocktailsById[cocktail.id];
      if (external == null) {
        final localId = _createUniqueLocalId(
          prefix: 'cocktail',
          seed: cocktail.id,
          existing: localCocktailIds,
        );
        localCocktailIds.add(localId);
        localCocktails.add(
          LocalCocktail(
            localId: localId,
            canonicalSlug: canonicalFromValue(cocktail.id),
            cocktail: cocktail,
          ),
        );
        continue;
      }

      final patch = CocktailPatch.fromDiff(
        baseline: external.cocktail,
        updated: cocktail,
      );
      if (patch.isEmpty) {
        continue;
      }
      cocktailOverrides.add(
        CocktailOverride(
          source: external.identity.source,
          sourceId: external.identity.sourceId,
          patch: patch,
        ),
      );
    }

    final importedCocktailIds = catalog.cocktails
        .map((cocktail) => cocktail.id)
        .toSet();
    for (final external in _externalData.cocktails) {
      if (importedCocktailIds.contains(external.cocktail.id)) {
        continue;
      }
      cocktailOverrides.add(
        CocktailOverride(
          source: external.identity.source,
          sourceId: external.identity.sourceId,
          isHidden: true,
        ),
      );
    }

    _localData = LocalCatalogData(
      ingredients: localIngredients,
      cocktails: localCocktails,
    );
    _overridesData = _sanitizeOverrides(
      OverridesCatalogData(
        ingredientOverrides: ingredientOverrides,
        cocktailOverrides: cocktailOverrides,
      ),
    );

    await _persistAndRefresh();
    return _snapshot;
  }

  BarCatalog exportCatalog() {
    _ensureInitialized();
    return _snapshot.toCatalog();
  }

  Future<UnifiedCatalogSnapshot> refreshExternalCatalog() async {
    _ensureInitialized();
    final externalLoadResult = await _loadExternalData();
    _externalData = externalLoadResult.data;
    _snapshot = _composeSnapshot(
      externalSourceAvailable: externalLoadResult.externalSourceAvailable,
    );
    return _snapshot;
  }

  Future<void> _persistAndRefresh() async {
    await _persistLocalAndOverrides();
    _snapshot = _composeSnapshot(
      externalSourceAvailable: _snapshot.externalSourceAvailable,
    );
  }

  Future<void> _persistLocalAndOverrides() async {
    await Future.wait<void>(<Future<void>>[
      _localStorage.write(_localData),
      _overridesStorage.write(_overridesData),
    ]);
  }

  OverridesCatalogData _sanitizeOverrides(OverridesCatalogData source) {
    final ingredientOverrides = source.ingredientOverrides
        .where((item) => !item.isEmpty)
        .toList(growable: false);
    final cocktailOverrides = source.cocktailOverrides
        .where((item) => !item.isEmpty)
        .toList(growable: false);

    return OverridesCatalogData(
      ingredientOverrides: ingredientOverrides,
      cocktailOverrides: cocktailOverrides,
    );
  }

  UnifiedCatalogSnapshot _composeSnapshot({
    required bool externalSourceAvailable,
  }) {
    final ingredientOverrideByKey = <String, IngredientOverride>{
      for (final item in _overridesData.ingredientOverrides) item.key: item,
    };
    final cocktailOverrideByKey = <String, CocktailOverride>{
      for (final item in _overridesData.cocktailOverrides) item.key: item,
    };

    final unifiedIngredientsById = <String, UnifiedIngredient>{};
    for (final external in _externalData.ingredients) {
      final override = ingredientOverrideByKey[external.identity.unifiedKey];
      if (override?.isHidden ?? false) {
        continue;
      }

      final mergedIngredient = mergeIngredient(external, override);
      final origin = override == null || override.patch.isEmpty
          ? CatalogEntityOrigin.external
          : CatalogEntityOrigin.overridden;

      unifiedIngredientsById[mergedIngredient.id] = UnifiedIngredient(
        identity: external.identity.copyWith(
          canonicalSlug: mergedIngredient.id,
        ),
        origin: origin,
        ingredient: mergedIngredient,
      );
    }

    for (final local in _localData.ingredients) {
      unifiedIngredientsById[local.ingredient.id] = UnifiedIngredient(
        identity: CatalogIdentity(
          source: 'local',
          sourceId: local.localId,
          canonicalSlug: local.canonicalSlug,
          localId: local.localId,
        ),
        origin: CatalogEntityOrigin.local,
        ingredient: local.ingredient,
      );
    }

    final sortedIngredients =
        unifiedIngredientsById.values.toList(growable: false)..sort(
          (left, right) => left.ingredient.name.toLowerCase().compareTo(
            right.ingredient.name.toLowerCase(),
          ),
        );

    final unifiedCocktailsById = <String, UnifiedCocktail>{};
    for (final external in _externalData.cocktails) {
      final override = cocktailOverrideByKey[external.identity.unifiedKey];
      if (override?.isHidden ?? false) {
        continue;
      }

      final mergedCocktail = mergeCocktail(external, override);
      final origin = override == null || override.patch.isEmpty
          ? CatalogEntityOrigin.external
          : CatalogEntityOrigin.overridden;

      unifiedCocktailsById[mergedCocktail.id] = UnifiedCocktail(
        identity: external.identity.copyWith(canonicalSlug: mergedCocktail.id),
        origin: origin,
        cocktail: mergedCocktail,
      );
    }

    for (final local in _localData.cocktails) {
      unifiedCocktailsById[local.cocktail.id] = UnifiedCocktail(
        identity: CatalogIdentity(
          source: 'local',
          sourceId: local.localId,
          canonicalSlug: local.canonicalSlug,
          localId: local.localId,
        ),
        origin: CatalogEntityOrigin.local,
        cocktail: local.cocktail,
      );
    }

    final sortedCocktails = unifiedCocktailsById.values.toList(growable: false)
      ..sort(
        (left, right) => left.cocktail.name.toLowerCase().compareTo(
          right.cocktail.name.toLowerCase(),
        ),
      );

    return UnifiedCatalogSnapshot(
      ingredients: sortedIngredients,
      cocktails: sortedCocktails,
      externalSourceAvailable: externalSourceAvailable,
    );
  }

  Future<_ExternalLoadResult> _loadExternalData() async {
    try {
      final rawIngredients = await _externalProvider.fetchIngredients();
      final templateMapper = IngredientCanonicalMapper.fromKnownIngredients(
        _templateCatalog.ingredients,
      );
      final normalizedIngredients = _normalizeIngredientsByProviderFormat(
        rawIngredients: rawIngredients,
        ingredientMapper: templateMapper,
      );

      final cocktailMapper =
          IngredientCanonicalMapper.fromKnownIngredients(<Ingredient>[
            ..._templateCatalog.ingredients,
            ...normalizedIngredients.map((item) => item.ingredient),
          ]);

      final rawCocktails = await _externalProvider.fetchCocktails();
      final normalizedCocktails = _normalizeCocktailsByProviderFormat(
        rawCocktails: rawCocktails,
        ingredientMapper: cocktailMapper,
      );

      final normalizedExternal = ExternalCatalogData(
        source: _externalProvider.sourceId,
        fetchedAt: DateTime.now().toUtc(),
        ingredients: _dedupeIngredientsBySourceId(normalizedIngredients),
        cocktails: _dedupeCocktailsBySourceId(normalizedCocktails),
      );

      await _externalCacheStorage.write(normalizedExternal);
      return _ExternalLoadResult(
        data: normalizedExternal,
        externalSourceAvailable: true,
      );
    } catch (_) {
      final cached = _externalCacheStorage.read();
      if (cached != null && !cached.isEmpty) {
        return _ExternalLoadResult(
          data: cached,
          externalSourceAvailable: false,
        );
      }

      return _ExternalLoadResult(
        data: _toTemplateExternalData(source: 'template_seed'),
        externalSourceAvailable: false,
      );
    }
  }

  List<ExternalIngredient> _normalizeIngredientsByProviderFormat({
    required List<Map<String, dynamic>> rawIngredients,
    required IngredientCanonicalMapper ingredientMapper,
  }) {
    switch (_externalProvider.format) {
      case ExternalProviderFormat.generic:
        return rawIngredients
            .map(
              (raw) => normalizeExternalIngredient(
                raw,
                source: _externalProvider.sourceId,
                ingredientMapper: ingredientMapper,
              ),
            )
            .toList(growable: false);
      case ExternalProviderFormat.theCocktailDb:
        return normalizeTheCocktailDbIngredients(
          rawIngredients: rawIngredients,
          source: _externalProvider.sourceId,
          ingredientMapper: ingredientMapper,
        );
    }
  }

  List<ExternalCocktail> _normalizeCocktailsByProviderFormat({
    required List<Map<String, dynamic>> rawCocktails,
    required IngredientCanonicalMapper ingredientMapper,
  }) {
    switch (_externalProvider.format) {
      case ExternalProviderFormat.generic:
        return rawCocktails
            .map(
              (raw) => normalizeExternalCocktail(
                raw,
                source: _externalProvider.sourceId,
                ingredientMapper: ingredientMapper,
              ),
            )
            .toList(growable: false);
      case ExternalProviderFormat.theCocktailDb:
        return normalizeTheCocktailDbCocktails(
          rawCocktails: rawCocktails,
          source: _externalProvider.sourceId,
          ingredientMapper: ingredientMapper,
          knownCocktails: _templateCatalog.cocktails,
        );
    }
  }

  List<ExternalIngredient> _dedupeIngredientsBySourceId(
    List<ExternalIngredient> source,
  ) {
    final unique = <String, ExternalIngredient>{};
    for (final ingredient in source) {
      unique.putIfAbsent(ingredient.identity.sourceId, () => ingredient);
    }
    return unique.values.toList(growable: false);
  }

  List<ExternalCocktail> _dedupeCocktailsBySourceId(
    List<ExternalCocktail> source,
  ) {
    final unique = <String, ExternalCocktail>{};
    for (final cocktail in source) {
      unique.putIfAbsent(cocktail.identity.sourceId, () => cocktail);
    }
    return unique.values.toList(growable: false);
  }

  ExternalCatalogData _toTemplateExternalData({required String source}) {
    final ingredients = _templateCatalog.ingredients
        .map(
          (ingredient) => ExternalIngredient(
            identity: CatalogIdentity(
              source: source,
              sourceId: ingredient.id,
              canonicalSlug: ingredient.id,
            ),
            ingredient: ingredient,
          ),
        )
        .toList(growable: false);

    final cocktails = _templateCatalog.cocktails
        .map(
          (cocktail) => ExternalCocktail(
            identity: CatalogIdentity(
              source: source,
              sourceId: cocktail.id,
              canonicalSlug: cocktail.id,
            ),
            cocktail: cocktail,
          ),
        )
        .toList(growable: false);

    return ExternalCatalogData(
      source: source,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      ingredients: ingredients,
      cocktails: cocktails,
    );
  }

  String _createUniqueLocalId({
    required String prefix,
    required String seed,
    required Set<String> existing,
  }) {
    final normalizedSeed = normalizeKey(seed);
    final base = '$prefix-${normalizedSeed.isEmpty ? 'item' : normalizedSeed}';
    var candidate = base;
    var index = 1;
    while (existing.contains(candidate)) {
      candidate = '$base-$index';
      index++;
    }
    return candidate;
  }

  void _ensureInitialized() {
    if (_isInitialized) {
      return;
    }
    throw StateError('BarCatalogRepository is not initialized');
  }
}

class _ExternalLoadResult {
  const _ExternalLoadResult({
    required this.data,
    required this.externalSourceAvailable,
  });

  final ExternalCatalogData data;
  final bool externalSourceAvailable;
}
