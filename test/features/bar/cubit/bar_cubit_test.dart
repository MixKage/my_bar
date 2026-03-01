import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/features/bar/cubit/bar_cubit.dart';
import 'package:my_bar/features/bar/data/bar_catalog_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

void main() {
  test('throws export error when bar catalog is unchanged', () {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    expect(() => cubit.exportCatalog(), throwsFormatException);
  });

  test('exports successfully when bar catalog was changed', () async {
    final cubit = BarCubit(
      selectionStorage: InMemoryIngredientSelectionStorage(),
      catalogStorage: InMemoryBarCatalogStorage(),
      initialCatalog: _templateCatalog,
      templateCatalog: _templateCatalog,
    );

    await cubit.addIngredient(name: 'Кампари', category: 'Ликёры', image: '');

    final exported = cubit.exportCatalog();
    expect(exported.ingredients.length, 3);
  });
}

final _templateCatalog = BarCatalog(
  ingredients: <Ingredient>[
    const Ingredient(
      id: 'gin',
      name: 'Джин',
      category: 'Крепкий алкоголь',
      image: '',
    ),
    const Ingredient(
      id: 'vermouth',
      name: 'Вермут',
      category: 'Аперитивы',
      image: '',
    ),
  ],
  cocktails: <Cocktail>[
    const Cocktail(
      id: 'martini',
      name: 'Мартини',
      image: '',
      ingredients: <String>['gin', 'vermouth'],
      description: 'Джин, сухой вермут',
      tags: <String>['IBA', 'Крепкие'],
    ),
  ],
);
