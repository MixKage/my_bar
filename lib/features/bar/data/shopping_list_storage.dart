import 'package:shared_preferences/shared_preferences.dart';

abstract class ShoppingListStorage {
  Set<String> readIngredientIds();
  Future<void> writeIngredientIds(Set<String> ingredientIds);
}

class SharedPreferencesShoppingListStorage implements ShoppingListStorage {
  SharedPreferencesShoppingListStorage(this._preferences);

  static const String storageKey = 'shopping_list_ingredient_ids';

  final SharedPreferences _preferences;

  @override
  Set<String> readIngredientIds() {
    return (_preferences.getStringList(storageKey) ?? const <String>[]).toSet();
  }

  @override
  Future<void> writeIngredientIds(Set<String> ingredientIds) {
    final sortedIds = ingredientIds.toList()..sort();
    return _preferences.setStringList(storageKey, sortedIds);
  }
}

class InMemoryShoppingListStorage implements ShoppingListStorage {
  InMemoryShoppingListStorage({Set<String> initial = const <String>{}})
    : _ingredientIds = Set<String>.from(initial);

  Set<String> _ingredientIds;

  @override
  Set<String> readIngredientIds() => Set<String>.from(_ingredientIds);

  @override
  Future<void> writeIngredientIds(Set<String> ingredientIds) async {
    _ingredientIds = Set<String>.from(ingredientIds);
  }
}
