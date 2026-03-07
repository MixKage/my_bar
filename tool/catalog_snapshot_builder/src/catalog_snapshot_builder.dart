import 'dart:convert';

import 'package:my_bar/features/bar/data/adapters/catalog_normalizers.dart';
import 'package:my_bar/features/bar/data/adapters/the_cocktail_db_normalizer.dart';
import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/data/models/catalog_layer_models.dart';
import 'package:my_bar/features/bar/data/utils/catalog_id_utils.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';

import 'catalog_import_source.dart';

class CatalogSnapshotBuilderOptions {
  const CatalogSnapshotBuilderOptions({
    this.strict = false,
    this.failOnUnresolvedMapping = false,
    this.pretty = false,
  });

  final bool strict;
  final bool failOnUnresolvedMapping;
  final bool pretty;
}

class CatalogSnapshotBuildSummary {
  const CatalogSnapshotBuildSummary({
    required this.importedIngredients,
    required this.importedCocktails,
    required this.invalidCocktailsDropped,
    required this.unresolvedIngredientMappings,
    required this.duplicatesRemoved,
  });

  final int importedIngredients;
  final int importedCocktails;
  final int invalidCocktailsDropped;
  final int unresolvedIngredientMappings;
  final int duplicatesRemoved;

  Map<String, Object> toJson() {
    return <String, Object>{
      'importedIngredients': importedIngredients,
      'importedCocktails': importedCocktails,
      'invalidCocktailsDropped': invalidCocktailsDropped,
      'unresolvedIngredientMappings': unresolvedIngredientMappings,
      'duplicatesRemoved': duplicatesRemoved,
    };
  }

  String prettyPrint() {
    return <String>[
      'Imported ingredients: $importedIngredients',
      'Imported cocktails: $importedCocktails',
      'Invalid cocktails dropped: $invalidCocktailsDropped',
      'Unresolved ingredient mappings: $unresolvedIngredientMappings',
      'Duplicates removed: $duplicatesRemoved',
    ].join('\n');
  }
}

class CatalogSnapshotBuildResult {
  const CatalogSnapshotBuildResult({
    required this.snapshotJson,
    required this.snapshotMap,
    required this.summary,
  });

  final String snapshotJson;
  final Map<String, dynamic> snapshotMap;
  final CatalogSnapshotBuildSummary summary;
}

class CatalogSnapshotBuilder {
  CatalogSnapshotBuilder({
    this.codec = const BarCatalogJsonCodec(),
    this.generatorVersion = '1',
  });

  final BarCatalogJsonCodec codec;
  final String generatorVersion;

  CatalogSnapshotBuildResult build({
    required CatalogImportPayload payload,
    required BarCatalog mappingTemplateCatalog,
    required CatalogSnapshotBuilderOptions options,
    DateTime? generatedAtUtc,
  }) {
    final ingredientMapper = IngredientCanonicalMapper.fromKnownIngredients(
      mappingTemplateCatalog.ingredients,
    );
    final knownIngredientIds = mappingTemplateCatalog.ingredientIds;
    final rawCocktailsBySourceId = _indexRawBySourceId(
      payload.cocktails,
      candidates: const <String>['idDrink', 'sourceId', 'id'],
    );
    final rawIngredientsBySourceId = _indexRawBySourceId(
      payload.ingredients,
      candidates: const <String>['idIngredient', 'sourceId', 'id', 'name'],
    );

    final normalizedIngredients = _normalizeIngredients(
      payload: payload,
      ingredientMapper: ingredientMapper,
    );
    final normalizedCocktails = _normalizeCocktails(
      payload: payload,
      mappingTemplateCatalog: mappingTemplateCatalog,
      ingredientMapper: ingredientMapper,
    );

    final dedupedBySourceIngredients = _dedupeIngredientsBySourceId(
      normalizedIngredients,
    );
    final dedupedBySourceCocktails = _dedupeCocktailsBySourceId(
      normalizedCocktails,
    );
    final sourceLevelDuplicatesRemoved =
        _countRawDuplicatesBySourceId(
          payload.ingredients,
          keys: const <String>['idIngredient', 'sourceId', 'id', 'name'],
        ) +
        _countRawDuplicatesBySourceId(
          payload.cocktails,
          keys: const <String>['idDrink', 'sourceId', 'id', 'name'],
        );

    final unresolvedMappings = dedupedBySourceIngredients
        .where((item) => !knownIngredientIds.contains(item.ingredient.id))
        .map(
          (item) => <String, String>{
            'sourceId': item.identity.sourceId,
            'sourceName': item.ingredient.name,
            'resolvedCanonicalKey': item.ingredient.id,
          },
        )
        .toList(growable: false);

    final ingredientById = <String, ExternalIngredient>{};
    for (final ingredient in dedupedBySourceIngredients) {
      ingredientById.putIfAbsent(ingredient.ingredient.id, () => ingredient);
    }
    final ingredientIdLevelDuplicatesRemoved =
        dedupedBySourceIngredients.length - ingredientById.length;

    final sanitizedCocktailsResult = _sanitizeCocktails(
      cocktails: dedupedBySourceCocktails,
      availableIngredientIds: ingredientById.keys.toSet(),
      strict: options.strict,
    );

    final cocktailById = <String, ExternalCocktail>{};
    for (final cocktail in sanitizedCocktailsResult.cocktails) {
      cocktailById.putIfAbsent(cocktail.cocktail.id, () => cocktail);
    }
    final cocktailIdLevelDuplicatesRemoved =
        sanitizedCocktailsResult.cocktails.length - cocktailById.length;

    final finalIngredients =
        ingredientById.values
            .map((item) => item.ingredient)
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final finalCocktails =
        cocktailById.values.map((item) => item.cocktail).toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final validationCatalog = BarCatalog(
      ingredients: finalIngredients,
      cocktails: finalCocktails,
    );
    final validationEncoded = codec.encode(validationCatalog, pretty: false);
    codec.decode(validationEncoded);

    final metadata = <String, dynamic>{
      'schema': 'my_bar_catalog_snapshot',
      'generatorVersion': generatorVersion,
      'generatedAt': (generatedAtUtc ?? DateTime.now().toUtc())
          .toIso8601String(),
      'source': payload.sourceName,
      'sourceId': payload.sourceId,
      'stats': CatalogSnapshotBuildSummary(
        importedIngredients: finalIngredients.length,
        importedCocktails: finalCocktails.length,
        invalidCocktailsDropped: sanitizedCocktailsResult.invalidDropped,
        unresolvedIngredientMappings: unresolvedMappings.length,
        duplicatesRemoved:
            sourceLevelDuplicatesRemoved +
            ingredientIdLevelDuplicatesRemoved +
            cocktailIdLevelDuplicatesRemoved,
      ).toJson(),
      if (unresolvedMappings.isNotEmpty)
        'unresolvedMappings': unresolvedMappings,
    };

    final ingredientMaps =
        ingredientById.values
            .map(
              (item) => _serializeIngredient(
                item,
                rawSource: rawIngredientsBySourceId[item.identity.sourceId],
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
          );
    final cocktailMaps =
        cocktailById.values
            .map(
              (item) => _serializeCocktail(
                item,
                rawSource: rawCocktailsBySourceId[item.identity.sourceId],
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
          );

    if (options.failOnUnresolvedMapping && unresolvedMappings.isNotEmpty) {
      throw StateError(
        'Found ${unresolvedMappings.length} unresolved ingredient mapping(s).',
      );
    }

    final snapshotMap = <String, dynamic>{
      'metadata': metadata,
      'ingredients': ingredientMaps,
      'cocktails': cocktailMaps,
    };
    final snapshotJson = options.pretty
        ? const JsonEncoder.withIndent('  ').convert(snapshotMap)
        : jsonEncode(snapshotMap);

    final summary = CatalogSnapshotBuildSummary(
      importedIngredients: finalIngredients.length,
      importedCocktails: finalCocktails.length,
      invalidCocktailsDropped: sanitizedCocktailsResult.invalidDropped,
      unresolvedIngredientMappings: unresolvedMappings.length,
      duplicatesRemoved:
          sourceLevelDuplicatesRemoved +
          ingredientIdLevelDuplicatesRemoved +
          cocktailIdLevelDuplicatesRemoved,
    );

    return CatalogSnapshotBuildResult(
      snapshotJson: snapshotJson,
      snapshotMap: snapshotMap,
      summary: summary,
    );
  }

  List<ExternalIngredient> _normalizeIngredients({
    required CatalogImportPayload payload,
    required IngredientCanonicalMapper ingredientMapper,
  }) {
    switch (payload.format) {
      case CatalogImportFormat.generic:
        return payload.ingredients
            .map(
              (raw) => normalizeExternalIngredient(
                raw,
                source: payload.sourceId,
                ingredientMapper: ingredientMapper,
              ),
            )
            .toList(growable: false);
      case CatalogImportFormat.theCocktailDb:
        return normalizeTheCocktailDbIngredients(
          rawIngredients: payload.ingredients,
          source: payload.sourceId,
          ingredientMapper: ingredientMapper,
        );
    }
  }

  List<ExternalCocktail> _normalizeCocktails({
    required CatalogImportPayload payload,
    required BarCatalog mappingTemplateCatalog,
    required IngredientCanonicalMapper ingredientMapper,
  }) {
    switch (payload.format) {
      case CatalogImportFormat.generic:
        return payload.cocktails
            .map(
              (raw) => normalizeExternalCocktail(
                raw,
                source: payload.sourceId,
                ingredientMapper: ingredientMapper,
              ),
            )
            .toList(growable: false);
      case CatalogImportFormat.theCocktailDb:
        return normalizeTheCocktailDbCocktails(
          rawCocktails: payload.cocktails,
          source: payload.sourceId,
          ingredientMapper: ingredientMapper,
          knownCocktails: mappingTemplateCatalog.cocktails,
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

  _SanitizedCocktailsResult _sanitizeCocktails({
    required List<ExternalCocktail> cocktails,
    required Set<String> availableIngredientIds,
    required bool strict,
  }) {
    final normalized = <ExternalCocktail>[];
    var invalidDropped = 0;

    for (final item in cocktails) {
      final cocktail = item.cocktail;
      final unknownIngredients = cocktail.ingredients
          .where(
            (ingredientId) => !availableIngredientIds.contains(ingredientId),
          )
          .toList(growable: false);

      if (cocktail.id.trim().isEmpty ||
          cocktail.name.trim().isEmpty ||
          cocktail.ingredients.isEmpty) {
        invalidDropped++;
        continue;
      }

      if (unknownIngredients.isNotEmpty && strict) {
        invalidDropped++;
        continue;
      }

      if (unknownIngredients.isEmpty) {
        normalized.add(item);
        continue;
      }

      final filteredIngredients = cocktail.ingredients
          .where(availableIngredientIds.contains)
          .toList(growable: false);
      if (filteredIngredients.isEmpty) {
        invalidDropped++;
        continue;
      }

      final filteredSubstitutions = <String, List<String>>{};
      for (final entry in cocktail.ingredientSubstitutions.entries) {
        if (!filteredIngredients.contains(entry.key)) {
          continue;
        }
        final filtered =
            entry.value
                .where(availableIngredientIds.contains)
                .where((substitutionId) => substitutionId != entry.key)
                .toSet()
                .toList(growable: false)
              ..sort();
        if (filtered.isNotEmpty) {
          filteredSubstitutions[entry.key] = filtered;
        }
      }

      final filteredAmounts = <String, String>{
        for (final entry in cocktail.ingredientAmounts.entries)
          if (filteredIngredients.contains(entry.key)) entry.key: entry.value,
      };
      final filteredUnits = <String, String>{
        for (final entry in cocktail.ingredientUnits.entries)
          if (filteredIngredients.contains(entry.key)) entry.key: entry.value,
      };
      final filteredOptional = cocktail.optionalIngredients
          .where(filteredIngredients.contains)
          .toList(growable: false);
      final filteredDecoration = cocktail.decorationIngredients
          .where(filteredIngredients.contains)
          .toList(growable: false);

      final sanitizedCocktail = Cocktail(
        id: cocktail.id,
        name: cocktail.name,
        image: cocktail.image,
        ingredients: filteredIngredients,
        description: cocktail.description,
        preparationSteps: cocktail.preparationSteps,
        glassType: cocktail.glassType,
        tags: cocktail.tags,
        ingredientSubstitutions: filteredSubstitutions,
        ingredientAmounts: filteredAmounts,
        ingredientUnits: filteredUnits,
        optionalIngredients: filteredOptional,
        decorationIngredients: filteredDecoration,
        isFavorite: cocktail.isFavorite,
      );

      normalized.add(
        ExternalCocktail(identity: item.identity, cocktail: sanitizedCocktail),
      );
    }

    return _SanitizedCocktailsResult(
      cocktails: normalized,
      invalidDropped: invalidDropped,
    );
  }

  Map<String, dynamic> _serializeIngredient(
    ExternalIngredient ingredient, {
    Map<String, dynamic>? rawSource,
  }) {
    final map = <String, dynamic>{
      ...ingredient.ingredient.toJson(),
      'source': ingredient.identity.source,
      'sourceId': ingredient.identity.sourceId,
      'canonicalSlug': ingredient.identity.canonicalSlug,
      'displayName': ingredient.ingredient.name,
      'imageUrl': ingredient.ingredient.image,
      if (ingredient.aliases.isNotEmpty) 'aliases': ingredient.aliases,
    };

    final sourceType = _firstNonEmptyString(<Object?>[
      rawSource?['strType'],
      rawSource?['type'],
      rawSource?['kind'],
    ]);
    if (sourceType.isNotEmpty) {
      map['sourceType'] = sourceType;
    }

    return map;
  }

  Map<String, dynamic> _serializeCocktail(
    ExternalCocktail cocktail, {
    Map<String, dynamic>? rawSource,
  }) {
    final category = _firstNonEmptyString(<Object?>[
      rawSource?['strCategory'],
      rawSource?['category'],
    ]);
    final alcoholicLabel = _firstNonEmptyString(<Object?>[
      rawSource?['strAlcoholic'],
      rawSource?['alcoholic'],
    ]);
    final garnish = _firstNonEmptyString(<Object?>[
      rawSource?['strGarnish'],
      rawSource?['garnish'],
    ]);
    final alternateName = _firstNonEmptyString(<Object?>[
      rawSource?['strDrinkAlternate'],
      rawSource?['alternateName'],
    ]);
    final aliases = <String>{
      cocktail.cocktail.name,
      if (alternateName.isNotEmpty) alternateName,
    }.toList(growable: false);

    final map = <String, dynamic>{
      ...cocktail.cocktail.toJson(),
      'source': cocktail.identity.source,
      'sourceId': cocktail.identity.sourceId,
      'canonicalSlug': cocktail.identity.canonicalSlug,
      'imageUrl': cocktail.cocktail.image,
      if (category.isNotEmpty) 'category': category,
      if (alcoholicLabel.isNotEmpty) 'alcoholicLabel': alcoholicLabel,
      if (garnish.isNotEmpty) 'garnish': garnish,
      'aliases': aliases,
      if (rawSource != null)
        'sourceMetadata': <String, dynamic>{
          'strCategory': rawSource['strCategory'],
          'strAlcoholic': rawSource['strAlcoholic'],
          'strGlass': rawSource['strGlass'],
          'strTags': rawSource['strTags'],
        },
    };

    final alcoholicFlag = _parseAlcoholicFlag(alcoholicLabel);
    if (alcoholicFlag != null) {
      map['isAlcoholic'] = alcoholicFlag;
      map['isNonAlcoholic'] = !alcoholicFlag;
    }

    return map;
  }

  Map<String, Map<String, dynamic>> _indexRawBySourceId(
    List<Map<String, dynamic>> items, {
    required List<String> candidates,
  }) {
    final bySourceId = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final sourceId = _firstNonEmptyString(
        candidates.map((candidate) => item[candidate]),
      );
      if (sourceId.isEmpty) {
        continue;
      }
      bySourceId.putIfAbsent(sourceId, () => item);
    }
    return bySourceId;
  }

  int _countRawDuplicatesBySourceId(
    List<Map<String, dynamic>> items, {
    required List<String> keys,
  }) {
    final seen = <String>{};
    var duplicates = 0;
    for (final item in items) {
      final sourceId = _firstNonEmptyString(keys.map((key) => item[key]));
      if (sourceId.isEmpty) {
        continue;
      }
      if (!seen.add(sourceId)) {
        duplicates++;
      }
    }
    return duplicates;
  }

  bool? _parseAlcoholicFlag(String source) {
    final normalized = normalizeKey(source);
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('non_alcoholic')) {
      return false;
    }
    if (normalized.contains('alcoholic')) {
      return true;
    }
    return null;
  }
}

class _SanitizedCocktailsResult {
  const _SanitizedCocktailsResult({
    required this.cocktails,
    required this.invalidDropped,
  });

  final List<ExternalCocktail> cocktails;
  final int invalidDropped;
}

String _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}
