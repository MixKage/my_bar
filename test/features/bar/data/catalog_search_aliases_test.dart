import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/search/app_search_query.dart';
import 'package:my_bar/features/bar/data/adapters/catalog_normalizers.dart';
import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/data/models/catalog_layer_models.dart';
import 'package:my_bar/features/bar/data/utils/catalog_id_utils.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';

void main() {
  final mapper = IngredientCanonicalMapper.fromKnownIngredients(const []);

  test(
    'imported alternative names survive normalization, edits and export',
    () {
      final ingredient = normalizeExternalIngredient(
        {
          'id': 'fruit-example',
          'name': 'Citrus example',
          'aliases': [' Orange ', 'Orange', ''],
        },
        source: 'example',
        ingredientMapper: mapper,
      ).ingredient;
      final cocktail = normalizeExternalCocktail(
        {
          'id': 'drink-example',
          'name': 'Aperitif example',
          'aliases': ['Happy hour'],
          'ingredients': [ingredient.id],
        },
        source: 'example',
        ingredientMapper: mapper,
      ).cocktail;

      final editedIngredient = const IngredientPatch(
        name: 'Citrus',
      ).applyTo(ingredient);
      final editedCocktail = const CocktailPatch(
        isFavorite: true,
      ).applyTo(cocktail);
      const codec = BarCatalogJsonCodec();
      final restored = codec.decode(
        codec.encode(
          BarCatalog(
            ingredients: [editedIngredient],
            cocktails: [editedCocktail],
          ),
        ),
      );
      expect(restored.ingredients.single.name, 'Citrus');
      expect(restored.ingredients.single.aliases, ['Orange']);
      expect(restored.cocktails.single.name, 'Aperitif example');
      expect(restored.cocktails.single.aliases, ['Happy hour']);
      expect(restored.cocktails.single.isFavorite, isTrue);
      expect(
        AppSearchQuery(
          'hapy hour',
        ).matchesAny(restored.cocktails.single.aliases),
        isTrue,
      );
    },
  );

  test('existing cached ingredient aliases remain searchable', () {
    final restored = ExternalIngredient.fromJson({
      'identity': {
        'source': 'example',
        'sourceId': 'citrus',
        'canonicalSlug': 'citrus',
      },
      'ingredient': {'id': 'citrus', 'name': 'Citrus'},
      'aliases': ['Orange'],
    });
    expect(restored.ingredient.aliases, ['Orange']);
  });
}
