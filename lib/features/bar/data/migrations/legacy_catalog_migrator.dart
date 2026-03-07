import '../../domain/models/bar_catalog.dart';
import '../models/catalog_layer_models.dart';
import '../utils/catalog_id_utils.dart';

class LegacyCatalogMigrationResult {
  const LegacyCatalogMigrationResult({
    required this.localData,
    required this.overridesData,
  });

  final LocalCatalogData localData;
  final OverridesCatalogData overridesData;

  bool get isEmpty => localData.isEmpty && overridesData.isEmpty;
}

class LegacyCatalogMigrator {
  const LegacyCatalogMigrator({required this.externalBaseline});

  final ExternalCatalogData externalBaseline;

  LegacyCatalogMigrationResult migrate(BarCatalog legacyCatalog) {
    final externalIngredientsById = <String, ExternalIngredient>{
      for (final item in externalBaseline.ingredients) item.ingredient.id: item,
    };
    final externalCocktailsById = <String, ExternalCocktail>{
      for (final item in externalBaseline.cocktails) item.cocktail.id: item,
    };

    final localIngredients = <LocalIngredient>[];
    final localCocktails = <LocalCocktail>[];
    final ingredientOverrides = <IngredientOverride>[];
    final cocktailOverrides = <CocktailOverride>[];

    final localIngredientIds = <String>{};
    for (final ingredient in legacyCatalog.ingredients) {
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

    final importedIngredientIds = legacyCatalog.ingredients
        .map((ingredient) => ingredient.id)
        .toSet();
    for (final external in externalBaseline.ingredients) {
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

    final localCocktailIds = <String>{};
    for (final cocktail in legacyCatalog.cocktails) {
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

    final importedCocktailIds = legacyCatalog.cocktails
        .map((cocktail) => cocktail.id)
        .toSet();
    for (final external in externalBaseline.cocktails) {
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

    return LegacyCatalogMigrationResult(
      localData: LocalCatalogData(
        ingredients: localIngredients,
        cocktails: localCocktails,
      ),
      overridesData: OverridesCatalogData(
        ingredientOverrides: ingredientOverrides,
        cocktailOverrides: cocktailOverrides,
      ),
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
}
