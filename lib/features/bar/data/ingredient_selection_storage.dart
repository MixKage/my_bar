import 'package:shared_preferences/shared_preferences.dart';

abstract class IngredientSelectionStorage {
  Set<String> readSelectedIngredientIds();
  Future<void> writeSelectedIngredientIds(Set<String> ingredientIds);
}

class SharedPreferencesIngredientSelectionStorage
    implements IngredientSelectionStorage {
  SharedPreferencesIngredientSelectionStorage(this._preferences);

  static const String storageKey = 'selected_ingredients';

  final SharedPreferences _preferences;

  @override
  Set<String> readSelectedIngredientIds() {
    return (_preferences.getStringList(storageKey) ?? const <String>[]).toSet();
  }

  @override
  Future<void> writeSelectedIngredientIds(Set<String> ingredientIds) {
    final sortedIds = ingredientIds.toList()..sort();
    return _preferences.setStringList(storageKey, sortedIds);
  }
}

class InMemoryIngredientSelectionStorage implements IngredientSelectionStorage {
  Set<String> _selectedIngredientIds;

  InMemoryIngredientSelectionStorage({Set<String> initial = const <String>{}})
    : _selectedIngredientIds = Set<String>.from(initial);

  @override
  Set<String> readSelectedIngredientIds() {
    return Set<String>.from(_selectedIngredientIds);
  }

  @override
  Future<void> writeSelectedIngredientIds(Set<String> ingredientIds) async {
    _selectedIngredientIds = Set<String>.from(ingredientIds);
  }
}
