import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/bar_catalog_storage.dart';
import '../data/ingredient_selection_storage.dart';
import '../domain/models/bar_catalog.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/ingredient.dart';
import 'bar_state.dart';

class BarCubit extends Cubit<BarState> {
  BarCubit({
    required IngredientSelectionStorage selectionStorage,
    required BarCatalogStorage catalogStorage,
    required BarCatalog initialCatalog,
    required BarCatalog templateCatalog,
  }) : _selectionStorage = selectionStorage,
       _catalogStorage = catalogStorage,
       _templateCatalog = templateCatalog,
       super(
         BarState(
           ingredients: initialCatalog.ingredients,
           cocktails: initialCatalog.cocktails,
           selectedIngredientIds: selectionStorage
               .readSelectedIngredientIds()
               .where(initialCatalog.ingredientIds.contains)
               .toSet(),
         ),
       );

  final IngredientSelectionStorage _selectionStorage;
  final BarCatalogStorage _catalogStorage;
  final BarCatalog _templateCatalog;

  Future<void> toggleIngredient(String ingredientId) async {
    if (!state.ingredientIds.contains(ingredientId)) {
      return;
    }

    final nextSelection = Set<String>.from(state.selectedIngredientIds);
    if (nextSelection.contains(ingredientId)) {
      nextSelection.remove(ingredientId);
    } else {
      nextSelection.add(ingredientId);
    }

    final nextState = state.copyWith(selectedIngredientIds: nextSelection);
    emit(nextState);
    await _persist(nextState);
  }

  Future<void> addIngredient({
    required String name,
    required String category,
    required String image,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Название ингредиента не может быть пустым.');
    }

    final normalizedCategory = category.trim().isEmpty
        ? 'Пользовательские'
        : category.trim();

    final ingredient = Ingredient(
      id: _generateUniqueId(normalizedName, state.ingredientIds),
      name: normalizedName,
      category: normalizedCategory,
      image: image.trim(),
    );

    final nextState = state.copyWith(
      ingredients: <Ingredient>[...state.ingredients, ingredient],
    );
    emit(nextState);
    await _persist(nextState);
  }

  Future<void> addCocktail({
    required String name,
    required String description,
    required String image,
    required Set<String> ingredientIds,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Название коктейля не может быть пустым.');
    }
    if (ingredientIds.isEmpty) {
      throw const FormatException(
        'Выбери хотя бы один ингредиент для коктейля.',
      );
    }
    if (!ingredientIds.every(state.ingredientIds.contains)) {
      throw const FormatException('Коктейль содержит неизвестные ингредиенты.');
    }

    final normalizedDescription = description.trim().isEmpty
        ? ingredientIds
              .map((id) => state.ingredientsById[id]?.name ?? id)
              .join(', ')
        : description.trim();

    final cocktail = Cocktail(
      id: _generateUniqueId(
        normalizedName,
        state.cocktails.map((item) => item.id).toSet(),
      ),
      name: normalizedName,
      image: image.trim(),
      ingredients: ingredientIds.toList(growable: false),
      description: normalizedDescription,
    );

    final nextState = state.copyWith(
      cocktails: <Cocktail>[...state.cocktails, cocktail],
    );
    emit(nextState);
    await _persist(nextState);
  }

  Future<void> importCatalog(BarCatalog catalog) async {
    final validSelection = state.selectedIngredientIds
        .where(catalog.ingredientIds.contains)
        .toSet();

    final nextState = BarState(
      ingredients: catalog.ingredients,
      cocktails: catalog.cocktails,
      selectedIngredientIds: validSelection,
    );

    emit(nextState);
    await _persist(nextState);
  }

  BarCatalog exportCatalog() {
    if (state.catalog == _templateCatalog) {
      throw const FormatException('Барная карта не изменена');
    }
    return state.catalog;
  }

  Future<void> _persist(BarState currentState) async {
    await Future.wait<void>(<Future<void>>[
      _selectionStorage.writeSelectedIngredientIds(
        currentState.selectedIngredientIds,
      ),
      _catalogStorage.writeCatalog(currentState.catalog),
    ]);
  }

  String _generateUniqueId(String value, Set<String> existingIds) {
    final base = _slugify(value);
    var candidate = base;
    var index = 1;
    while (existingIds.contains(candidate)) {
      candidate = '$base-$index';
      index++;
    }
    return candidate;
  }

  String _slugify(String value) {
    final buffer = StringBuffer();
    final alphaNumericPattern = RegExp('[a-z0-9а-яё]');
    var wasDash = false;

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune).toLowerCase();
      final isAlphaNumeric = alphaNumericPattern.hasMatch(char);
      if (isAlphaNumeric) {
        buffer.write(_transliterate(char));
        wasDash = false;
      } else if (!wasDash) {
        buffer.write('-');
        wasDash = true;
      }
    }

    var slug = buffer.toString().replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) {
      slug = 'item';
    }
    return slug;
  }

  String _transliterate(String char) {
    const map = <String, String>{
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'e',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'i',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'h',
      'ц': 'c',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'sh',
      'ъ': '',
      'ы': 'y',
      'ь': '',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya',
    };

    return map[char] ?? char;
  }
}
