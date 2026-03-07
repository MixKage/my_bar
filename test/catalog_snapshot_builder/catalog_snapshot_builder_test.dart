import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

import '../../tool/catalog_snapshot_builder/src/catalog_import_source.dart';
import '../../tool/catalog_snapshot_builder/src/catalog_snapshot_builder.dart';

void main() {
  final templateCatalog = BarCatalog(
    ingredients: const <Ingredient>[
      Ingredient(
        id: 'gin',
        name: 'Джин',
        category: 'Крепкий алкоголь',
        image: '',
      ),
      Ingredient(
        id: 'juice_orange',
        name: 'Апельсиновый сок',
        category: 'Соки',
        image: '',
      ),
    ],
    cocktails: const <Cocktail>[
      Cocktail(
        id: 'gin_fizz',
        name: 'Gin Fizz',
        image: '',
        ingredients: <String>['gin', 'juice_orange'],
        description: 'Джин и сок',
        preparationSteps: <String>['Смешайте и подавайте.'],
        glassType: 'Хайболл',
        tags: <String>['Крепкие'],
      ),
    ],
  );

  test(
    'normalizes cocktail ingredients and measures from TheCocktailDB raw',
    () {
      final payload = CatalogImportPayload(
        sourceName: 'thecocktaildb',
        sourceId: 'thecocktaildb_v1',
        format: CatalogImportFormat.theCocktailDb,
        ingredients: <Map<String, dynamic>>[
          <String, dynamic>{'idIngredient': '1', 'strIngredient1': 'Gin'},
          <String, dynamic>{
            'idIngredient': '2',
            'strIngredient1': 'Orange Juice',
          },
        ],
        cocktails: <Map<String, dynamic>>[
          <String, dynamic>{
            'idDrink': '11000',
            'strDrink': 'Gin Fizz',
            'strInstructions': 'Shake and serve.',
            'strIngredient1': 'Gin',
            'strMeasure1': '50 ml',
            'strIngredient2': 'Orange Juice',
            'strMeasure2': '100 ml',
            'strGlass': 'Highball glass',
            'strCategory': 'Cocktail',
            'strAlcoholic': 'Alcoholic',
            'strDrinkThumb': 'https://example.com/gin-fizz.jpg',
          },
        ],
      );

      final builder = CatalogSnapshotBuilder();
      final result = builder.build(
        payload: payload,
        mappingTemplateCatalog: templateCatalog,
        options: const CatalogSnapshotBuilderOptions(),
        generatedAtUtc: DateTime.utc(2026, 1, 1),
      );

      final cocktails = result.snapshotMap['cocktails'] as List<dynamic>;
      final cocktail = cocktails.single as Map<String, dynamic>;
      final ingredientAmounts =
          cocktail['ingredientAmounts'] as Map<String, dynamic>;
      final ingredientUnits =
          cocktail['ingredientUnits'] as Map<String, dynamic>;

      expect(
        cocktail['ingredients'],
        containsAll(<String>['gin', 'juice_orange']),
      );
      expect(ingredientAmounts['gin'], '50');
      expect(ingredientUnits['gin'], 'ml');
      expect(cocktail['sourceId'], '11000');

      final decoded = const BarCatalogJsonCodec().decode(result.snapshotJson);
      expect(decoded.cocktails, hasLength(1));
      expect(decoded.ingredients, hasLength(2));
    },
  );

  test('dedupes by sourceId and keeps deterministic entities', () {
    final payload = CatalogImportPayload(
      sourceName: 'thecocktaildb',
      sourceId: 'thecocktaildb_v1',
      format: CatalogImportFormat.theCocktailDb,
      ingredients: <Map<String, dynamic>>[
        <String, dynamic>{'idIngredient': '1', 'strIngredient1': 'Gin'},
        <String, dynamic>{'idIngredient': '1', 'strIngredient1': 'Gin'},
      ],
      cocktails: <Map<String, dynamic>>[
        <String, dynamic>{
          'idDrink': '11000',
          'strDrink': 'Gin Fizz',
          'strInstructions': 'Shake and serve.',
          'strIngredient1': 'Gin',
        },
        <String, dynamic>{
          'idDrink': '11000',
          'strDrink': 'Gin Fizz Duplicate',
          'strInstructions': 'Duplicate',
          'strIngredient1': 'Gin',
        },
      ],
    );

    final result = CatalogSnapshotBuilder().build(
      payload: payload,
      mappingTemplateCatalog: templateCatalog,
      options: const CatalogSnapshotBuilderOptions(),
      generatedAtUtc: DateTime.utc(2026, 1, 1),
    );

    expect(result.summary.importedIngredients, 1);
    expect(result.summary.importedCocktails, 1);
    expect(result.summary.duplicatesRemoved, greaterThanOrEqualTo(2));
  });

  test(
    'drops invalid cocktails in strict mode when ingredient references unresolved',
    () {
      final payload = CatalogImportPayload(
        sourceName: 'thecocktaildb',
        sourceId: 'thecocktaildb_v1',
        format: CatalogImportFormat.theCocktailDb,
        ingredients: <Map<String, dynamic>>[
          <String, dynamic>{'idIngredient': '1', 'strIngredient1': 'Gin'},
        ],
        cocktails: <Map<String, dynamic>>[
          <String, dynamic>{
            'idDrink': '11000',
            'strDrink': 'Broken Cocktail',
            'strInstructions': 'Shake and serve.',
            'strIngredient1': 'Gin',
            'strIngredient2': 'Unknown Ingredient',
          },
        ],
      );

      final result = CatalogSnapshotBuilder().build(
        payload: payload,
        mappingTemplateCatalog: templateCatalog,
        options: const CatalogSnapshotBuilderOptions(strict: true),
        generatedAtUtc: DateTime.utc(2026, 1, 1),
      );

      expect(result.summary.importedCocktails, 0);
      expect(result.summary.invalidCocktailsDropped, 1);
    },
  );

  test('fails when unresolved ingredient mappings are configured as fatal', () {
    final payload = CatalogImportPayload(
      sourceName: 'thecocktaildb',
      sourceId: 'thecocktaildb_v1',
      format: CatalogImportFormat.theCocktailDb,
      ingredients: <Map<String, dynamic>>[
        <String, dynamic>{
          'idIngredient': '90',
          'strIngredient1': 'Mystery Liqueur',
        },
      ],
      cocktails: const <Map<String, dynamic>>[],
    );

    expect(
      () => CatalogSnapshotBuilder().build(
        payload: payload,
        mappingTemplateCatalog: templateCatalog,
        options: const CatalogSnapshotBuilderOptions(
          failOnUnresolvedMapping: true,
        ),
        generatedAtUtc: DateTime.utc(2026, 1, 1),
      ),
      throwsStateError,
    );
  });
}
