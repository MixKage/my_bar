import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/cocktail_glass_types.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

import '../../tool/catalog_snapshot_builder/src/catalog_import_source.dart';
import '../../tool/catalog_snapshot_builder/src/catalog_snapshot_builder.dart';
import '../../tool/catalog_snapshot_builder/src/ingredient_glow_style_generator.dart';

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

  CatalogSnapshotBuilder createBuilder() {
    return CatalogSnapshotBuilder(
      glowStyleGenerator: IngredientGlowStyleGenerator(
        enableImageSampling: false,
      ),
    );
  }

  test(
    'normalizes cocktail ingredients and measures from TheCocktailDB raw',
    () async {
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

      final builder = createBuilder();
      final result = await builder.build(
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
      final ingredients = result.snapshotMap['ingredients'] as List<dynamic>;
      final ingredient = ingredients.first as Map<String, dynamic>;

      expect(
        cocktail['ingredients'],
        containsAll(<String>['gin', 'juice_orange']),
      );
      expect(ingredientAmounts['gin'], '50');
      expect(ingredientUnits['gin'], 'мл');
      expect(cocktail['sourceId'], '11000');
      expect((ingredient['glowColor'] as String?)?.isNotEmpty, isTrue);
      expect(ingredient.containsKey('glowOffsetX'), isTrue);
      expect(ingredient.containsKey('glowOffsetY'), isTrue);
      expect(ingredient.containsKey('glowScale'), isTrue);
      expect(ingredient.containsKey('glowOpacity'), isTrue);

      final decoded = const BarCatalogJsonCodec().decode(result.snapshotJson);
      expect(decoded.cocktails, hasLength(1));
      expect(decoded.ingredients, hasLength(2));
    },
  );

  test('dedupes by sourceId and keeps deterministic entities', () async {
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

    final result = await createBuilder().build(
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
    () async {
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

      final result = await createBuilder().build(
        payload: payload,
        mappingTemplateCatalog: templateCatalog,
        options: const CatalogSnapshotBuilderOptions(strict: true),
        generatedAtUtc: DateTime.utc(2026, 1, 1),
      );

      expect(result.summary.importedCocktails, 0);
      expect(result.summary.invalidCocktailsDropped, 1);
    },
  );

  test(
    'normalizes unsupported units and glasses to app-supported values',
    () async {
      final payload = CatalogImportPayload(
        sourceName: 'generic',
        sourceId: 'generic_v1',
        format: CatalogImportFormat.generic,
        ingredients: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'gin', 'name': 'Gin', 'category': 'Spirit'},
        ],
        cocktails: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'custom_gin',
            'name': 'Custom Gin',
            'ingredients': <String>['gin'],
            'ingredientAmounts': <String, String>{'gin': '2'},
            'ingredientUnits': <String, String>{'gin': 'ladles'},
            'glassType': 'Custom glass',
            'description': 'Mix',
            'preparationSteps': <String>['Mix'],
            'tags': <String>['Пользовательские'],
          },
        ],
      );

      final result = await createBuilder().build(
        payload: payload,
        mappingTemplateCatalog: templateCatalog,
        options: const CatalogSnapshotBuilderOptions(),
        generatedAtUtc: DateTime.utc(2026, 1, 1),
      );

      final cocktails = result.snapshotMap['cocktails'] as List<dynamic>;
      final cocktail = cocktails.single as Map<String, dynamic>;
      final amounts = cocktail['ingredientAmounts'] as Map<String, dynamic>;
      final units = cocktail['ingredientUnits'] as Map<String, dynamic>;

      expect(cocktail['glassType'], kDefaultCocktailGlassType);
      expect(amounts['gin'], '2 ladles');
      expect(units.containsKey('gin'), isFalse);
    },
  );

  test(
    'fails when unresolved ingredient mappings are configured as fatal',
    () async {
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
        () async => createBuilder().build(
          payload: payload,
          mappingTemplateCatalog: templateCatalog,
          options: const CatalogSnapshotBuilderOptions(
            failOnUnresolvedMapping: true,
          ),
          generatedAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}
