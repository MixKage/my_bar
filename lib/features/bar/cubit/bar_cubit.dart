import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_language.dart';
import '../data/bar_ui_settings_storage.dart';
import '../data/ingredient_selection_storage.dart';
import '../data/models/catalog_layer_models.dart';
import '../data/providers/external_bar_data_provider.dart';
import '../data/repositories/bar_catalog_repository.dart';
import '../domain/models/bar_catalog.dart';
import '../domain/models/catalog_data_source.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/cocktail_glass_types.dart';
import '../domain/models/cocktail_tags.dart';
import '../domain/models/ingredient.dart';
import 'bar_state.dart';

class BarCubit extends Cubit<BarState> {
  BarCubit({
    required IngredientSelectionStorage selectionStorage,
    required BarUiSettingsStorage settingsStorage,
    required BarCatalogRepository catalogRepository,
    required SelectableExternalBarDataProvider externalProviderSelector,
    required UnifiedCatalogSnapshot initialSnapshot,
  }) : _selectionStorage = selectionStorage,
       _settingsStorage = settingsStorage,
       _catalogRepository = catalogRepository,
       _externalProviderSelector = externalProviderSelector,
       super(
         (() {
           final settings = settingsStorage.readSettings();
           final ingredientIds = initialSnapshot.ingredientItems
               .map((item) => item.id)
               .toSet();
           return BarState(
             ingredients: initialSnapshot.ingredientItems,
             cocktails: initialSnapshot.cocktailItems,
             selectedIngredientIds: selectionStorage
                 .readSelectedIngredientIds()
                 .where(ingredientIds.contains)
                 .toSet(),
             ingredientOrigins: initialSnapshot.ingredientOrigins,
             cocktailOrigins: initialSnapshot.cocktailOrigins,
             catalogDataSource: externalProviderSelector.activeDataSource,
             isTheCocktailDbAvailable:
                 externalProviderSelector.isTheCocktailDbAvailable,
             externalSourceAvailable: initialSnapshot.externalSourceAvailable,
             visitorMode: settings.visitorMode,
             barMenuOnlyMode: settings.barMenuOnlyMode,
             powerSavingMode: settings.powerSavingMode,
             appLanguage: settings.appLanguage,
           );
         })(),
       ) {
    _selectedCatalogDataSource = settingsStorage
        .readSettings()
        .catalogDataSource;
  }

  final IngredientSelectionStorage _selectionStorage;
  final BarUiSettingsStorage _settingsStorage;
  final BarCatalogRepository _catalogRepository;
  final SelectableExternalBarDataProvider _externalProviderSelector;
  CatalogDataSource? _selectedCatalogDataSource;

  Future<void> toggleIngredient(String ingredientId) async {
    if (state.visitorMode) {
      return;
    }
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
    await _persistUiState(nextState);
  }

  Future<void> addIngredient({
    required String name,
    required String category,
    required String image,
    bool isDecoration = false,
    bool isOptional = false,
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
      isDecoration: isDecoration,
      isOptional: isOptional,
    );

    final snapshot = await _catalogRepository.addIngredient(ingredient);
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> updateIngredient({
    required String ingredientId,
    required String name,
    required String category,
    required String image,
    bool isDecoration = false,
    bool isOptional = false,
  }) async {
    if (state.visitorMode) {
      return;
    }

    final ingredientIndex = state.ingredients.indexWhere(
      (ingredient) => ingredient.id == ingredientId,
    );
    if (ingredientIndex < 0) {
      throw const FormatException('Ингредиент не найден.');
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Название ингредиента не может быть пустым.');
    }

    final normalizedCategory = category.trim().isEmpty
        ? 'Пользовательские'
        : category.trim();

    final currentIngredient = state.ingredients[ingredientIndex];
    final updatedIngredient = Ingredient(
      id: currentIngredient.id,
      name: normalizedName,
      category: normalizedCategory,
      image: image.trim(),
      isDecoration: isDecoration,
      isOptional: isOptional,
      glowColor: currentIngredient.glowColor,
      glowSecondaryColor: currentIngredient.glowSecondaryColor,
      glowOffsetX: currentIngredient.glowOffsetX,
      glowOffsetY: currentIngredient.glowOffsetY,
      glowScale: currentIngredient.glowScale,
      glowOpacity: currentIngredient.glowOpacity,
    );

    final snapshot = await _catalogRepository.updateIngredient(
      updatedIngredient,
    );
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> addCocktail({
    required String name,
    required String description,
    required List<String> preparationSteps,
    required String image,
    required String glassType,
    required Set<String> ingredientIds,
    Map<String, Set<String>> ingredientSubstitutions =
        const <String, Set<String>>{},
    Map<String, String> ingredientAmounts = const <String, String>{},
    Map<String, String> ingredientUnits = const <String, String>{},
    Set<String> optionalIngredientIds = const <String>{},
    Set<String> decorationIngredientIds = const <String>{},
    required Set<String> tags,
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
    final normalizedGlassType = glassType.trim().isEmpty
        ? kDefaultCocktailGlassType
        : glassType.trim();
    if (!kCocktailGlassTypes.contains(normalizedGlassType)) {
      throw const FormatException('Неизвестный тип бокала.');
    }

    final normalizedTags = tags.where(kCocktailTags.contains).toSet();
    if (normalizedTags.isEmpty) {
      normalizedTags.add(kUserCocktailTag);
    }

    final normalizedDescription = description.trim().isEmpty
        ? ingredientIds
              .map((id) => state.ingredientsById[id]?.name ?? id)
              .join(', ')
        : description.trim();
    final normalizedPreparationSteps = _normalizePreparationSteps(
      preparationSteps: preparationSteps,
      fallbackDescription: normalizedDescription,
    );
    final normalizedIngredientIds = _sortIngredientIds(ingredientIds);
    final normalizedSubstitutions = _normalizeIngredientSubstitutions(
      ingredientIds: ingredientIds,
      ingredientSubstitutions: ingredientSubstitutions,
    );
    final normalizedIngredientAmounts = _normalizeIngredientTextMap(
      ingredientIds: ingredientIds,
      sourceMap: ingredientAmounts,
      errorMessage:
          'Количество можно указать только для выбранных ингредиентов.',
    );
    final normalizedIngredientUnits = _normalizeIngredientTextMap(
      ingredientIds: ingredientIds,
      sourceMap: ingredientUnits,
      errorMessage:
          'Единицу измерения можно указать только для выбранных ингредиентов.',
    );
    final normalizedOptionalIngredientIds = _normalizeIngredientFlagIds(
      ingredientIds: ingredientIds,
      sourceIds: optionalIngredientIds,
      errorMessage:
          'Опциональными можно отметить только выбранные ингредиенты.',
    );
    final normalizedDecorationIngredientIds = _normalizeIngredientFlagIds(
      ingredientIds: ingredientIds,
      sourceIds: decorationIngredientIds,
      errorMessage: 'Украшением можно отметить только выбранные ингредиенты.',
    );

    final cocktail = Cocktail(
      id: _generateUniqueId(
        normalizedName,
        state.cocktails.map((item) => item.id).toSet(),
      ),
      name: normalizedName,
      image: image.trim(),
      ingredients: normalizedIngredientIds,
      description: normalizedDescription,
      preparationSteps: normalizedPreparationSteps,
      glassType: normalizedGlassType,
      tags: _sortTags(normalizedTags),
      ingredientSubstitutions: normalizedSubstitutions,
      ingredientAmounts: normalizedIngredientAmounts,
      ingredientUnits: normalizedIngredientUnits,
      optionalIngredients: normalizedOptionalIngredientIds,
      decorationIngredients: normalizedDecorationIngredientIds,
    );

    final snapshot = await _catalogRepository.addCocktail(cocktail);
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> updateCocktail({
    required String cocktailId,
    required String name,
    required String description,
    required List<String> preparationSteps,
    required String image,
    required String glassType,
    required Set<String> ingredientIds,
    Map<String, Set<String>> ingredientSubstitutions =
        const <String, Set<String>>{},
    Map<String, String> ingredientAmounts = const <String, String>{},
    Map<String, String> ingredientUnits = const <String, String>{},
    Set<String> optionalIngredientIds = const <String>{},
    Set<String> decorationIngredientIds = const <String>{},
    required Set<String> tags,
  }) async {
    final cocktailIndex = state.cocktails.indexWhere(
      (cocktail) => cocktail.id == cocktailId,
    );
    if (cocktailIndex < 0) {
      throw const FormatException('Коктейль не найден.');
    }

    final currentCocktail = state.cocktails[cocktailIndex];
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
    final normalizedGlassType = glassType.trim().isEmpty
        ? kDefaultCocktailGlassType
        : glassType.trim();
    if (!kCocktailGlassTypes.contains(normalizedGlassType)) {
      throw const FormatException('Неизвестный тип бокала.');
    }

    final normalizedTags = tags.where(kCocktailTags.contains).toSet();
    if (normalizedTags.isEmpty) {
      normalizedTags.add(kUserCocktailTag);
    }

    final normalizedDescription = description.trim().isEmpty
        ? ingredientIds
              .map((id) => state.ingredientsById[id]?.name ?? id)
              .join(', ')
        : description.trim();
    final normalizedPreparationSteps = _normalizePreparationSteps(
      preparationSteps: preparationSteps,
      fallbackDescription: normalizedDescription,
    );
    final normalizedIngredientIds = _sortIngredientIds(ingredientIds);
    final normalizedSubstitutions = _normalizeIngredientSubstitutions(
      ingredientIds: ingredientIds,
      ingredientSubstitutions: ingredientSubstitutions,
    );
    final normalizedIngredientAmounts = _normalizeIngredientTextMap(
      ingredientIds: ingredientIds,
      sourceMap: ingredientAmounts,
      errorMessage:
          'Количество можно указать только для выбранных ингредиентов.',
    );
    final normalizedIngredientUnits = _normalizeIngredientTextMap(
      ingredientIds: ingredientIds,
      sourceMap: ingredientUnits,
      errorMessage:
          'Единицу измерения можно указать только для выбранных ингредиентов.',
    );
    final normalizedOptionalIngredientIds = _normalizeIngredientFlagIds(
      ingredientIds: ingredientIds,
      sourceIds: optionalIngredientIds,
      errorMessage:
          'Опциональными можно отметить только выбранные ингредиенты.',
    );
    final normalizedDecorationIngredientIds = _normalizeIngredientFlagIds(
      ingredientIds: ingredientIds,
      sourceIds: decorationIngredientIds,
      errorMessage: 'Украшением можно отметить только выбранные ингредиенты.',
    );

    final updatedCocktail = Cocktail(
      id: currentCocktail.id,
      name: normalizedName,
      image: image.trim(),
      ingredients: normalizedIngredientIds,
      description: normalizedDescription,
      preparationSteps: normalizedPreparationSteps,
      glassType: normalizedGlassType,
      tags: _sortTags(normalizedTags),
      ingredientSubstitutions: normalizedSubstitutions,
      ingredientAmounts: normalizedIngredientAmounts,
      ingredientUnits: normalizedIngredientUnits,
      optionalIngredients: normalizedOptionalIngredientIds,
      decorationIngredients: normalizedDecorationIngredientIds,
      isFavorite: currentCocktail.isFavorite,
    );

    final snapshot = await _catalogRepository.updateCocktail(updatedCocktail);
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> updateCocktailPreparation({
    required String cocktailId,
    required List<String> preparationSteps,
  }) async {
    final cocktailIndex = state.cocktails.indexWhere(
      (cocktail) => cocktail.id == cocktailId,
    );
    if (cocktailIndex < 0) {
      throw const FormatException('Коктейль не найден.');
    }

    final currentCocktail = state.cocktails[cocktailIndex];
    final normalizedPreparationSteps = _normalizePreparationSteps(
      preparationSteps: preparationSteps,
      fallbackDescription: currentCocktail.description,
    );

    final updatedCocktail = Cocktail(
      id: currentCocktail.id,
      name: currentCocktail.name,
      image: currentCocktail.image,
      ingredients: currentCocktail.ingredients,
      description: currentCocktail.description,
      preparationSteps: normalizedPreparationSteps,
      glassType: currentCocktail.glassType,
      tags: currentCocktail.tags,
      ingredientSubstitutions: currentCocktail.ingredientSubstitutions,
      ingredientAmounts: currentCocktail.ingredientAmounts,
      ingredientUnits: currentCocktail.ingredientUnits,
      optionalIngredients: currentCocktail.optionalIngredients,
      decorationIngredients: currentCocktail.decorationIngredients,
      isFavorite: currentCocktail.isFavorite,
    );

    final snapshot = await _catalogRepository.updateCocktail(updatedCocktail);
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> removeCocktail(String cocktailId) async {
    if (state.visitorMode) {
      return;
    }
    final snapshot = await _catalogRepository.removeCocktail(cocktailId);
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> toggleCocktailFavorite(String cocktailId) async {
    final cocktailIndex = state.cocktails.indexWhere(
      (cocktail) => cocktail.id == cocktailId,
    );
    if (cocktailIndex < 0) {
      return;
    }

    final current = state.cocktails[cocktailIndex];
    final updated = Cocktail(
      id: current.id,
      name: current.name,
      image: current.image,
      ingredients: current.ingredients,
      description: current.description,
      preparationSteps: current.preparationSteps,
      glassType: current.glassType,
      tags: current.tags,
      ingredientSubstitutions: current.ingredientSubstitutions,
      ingredientAmounts: current.ingredientAmounts,
      ingredientUnits: current.ingredientUnits,
      optionalIngredients: current.optionalIngredients,
      decorationIngredients: current.decorationIngredients,
      isFavorite: !current.isFavorite,
    );

    final snapshot = await _catalogRepository.updateCocktail(updated);
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> setVisitorMode(bool enabled) async {
    final nextState = state.copyWith(visitorMode: enabled);
    emit(nextState);
    await _persistUiState(nextState);
  }

  Future<void> setBarMenuOnlyMode(bool enabled) async {
    final nextState = state.copyWith(barMenuOnlyMode: enabled);
    emit(nextState);
    await _persistUiState(nextState);
  }

  Future<void> setPowerSavingMode(bool enabled) async {
    final nextState = state.copyWith(powerSavingMode: enabled);
    emit(nextState);
    await _persistUiState(nextState);
  }

  void setSystemPowerSavingMode(bool enabled) {
    if (state.systemPowerSavingMode == enabled) {
      return;
    }
    emit(state.copyWith(systemPowerSavingMode: enabled));
  }

  Future<void> setCatalogDataSource(CatalogDataSource source) async {
    if (source == CatalogDataSource.theCocktailDb &&
        !_externalProviderSelector.isTheCocktailDbAvailable) {
      return;
    }

    _selectedCatalogDataSource = source;
    _externalProviderSelector.selectDataSource(source);

    final snapshot = await _catalogRepository.refreshExternalCatalog();
    await _applyCatalogSnapshot(snapshot);
  }

  Future<void> setAppLanguage(AppLanguage appLanguage) async {
    if (state.appLanguage == appLanguage) {
      return;
    }
    final nextState = state.copyWith(appLanguage: appLanguage);
    emit(nextState);
    await _persistUiState(nextState);

    if (_externalProviderSelector.activeDataSource == CatalogDataSource.seed) {
      final snapshot = await _catalogRepository.refreshExternalCatalog();
      await _applyCatalogSnapshot(snapshot);
    }
  }

  Future<void> importCatalog(BarCatalog catalog) async {
    final snapshot = await _catalogRepository.importCatalog(catalog);
    await _applyCatalogSnapshot(snapshot);
  }

  BarCatalog exportCatalog() {
    if (!_catalogRepository.hasUserChanges) {
      throw const FormatException('Барная карта не изменена');
    }
    return _catalogRepository.exportCatalog();
  }

  Future<void> _applyCatalogSnapshot(UnifiedCatalogSnapshot snapshot) async {
    final validSelection = state.selectedIngredientIds
        .where(snapshot.ingredientItems.map((item) => item.id).toSet().contains)
        .toSet();

    final nextState = state.copyWith(
      ingredients: snapshot.ingredientItems,
      cocktails: snapshot.cocktailItems,
      ingredientOrigins: snapshot.ingredientOrigins,
      cocktailOrigins: snapshot.cocktailOrigins,
      catalogDataSource: _externalProviderSelector.activeDataSource,
      isTheCocktailDbAvailable:
          _externalProviderSelector.isTheCocktailDbAvailable,
      externalSourceAvailable: snapshot.externalSourceAvailable,
      selectedIngredientIds: validSelection,
    );

    emit(nextState);
    await _persistUiState(nextState);
  }

  Future<void> _persistUiState(BarState currentState) async {
    await Future.wait<void>(<Future<void>>[
      _selectionStorage.writeSelectedIngredientIds(
        currentState.selectedIngredientIds,
      ),
      _settingsStorage.writeSettings(
        BarUiSettings(
          visitorMode: currentState.visitorMode,
          barMenuOnlyMode: currentState.barMenuOnlyMode,
          powerSavingMode: currentState.powerSavingMode,
          catalogDataSource: _selectedCatalogDataSource,
          appLanguage: currentState.appLanguage,
        ),
      ),
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

  List<String> _sortTags(Set<String> tags) {
    final sorted = tags.toList(growable: false)
      ..sort(
        (a, b) => kCocktailTags.indexOf(a).compareTo(kCocktailTags.indexOf(b)),
      );
    return sorted;
  }

  List<String> _normalizePreparationSteps({
    required List<String> preparationSteps,
    required String fallbackDescription,
  }) {
    final normalizedSteps = preparationSteps
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList(growable: false);
    if (normalizedSteps.isNotEmpty) {
      return normalizedSteps;
    }
    if (fallbackDescription.trim().isNotEmpty) {
      return <String>['Смешайте ингредиенты: ${fallbackDescription.trim()}'];
    }
    return <String>['Смешайте ингредиенты и подавайте.'];
  }

  Map<String, List<String>> _normalizeIngredientSubstitutions({
    required Set<String> ingredientIds,
    required Map<String, Set<String>> ingredientSubstitutions,
  }) {
    final normalized = <String, List<String>>{};
    final allIngredientIds = state.ingredientIds;

    for (final entry in ingredientSubstitutions.entries) {
      final sourceIngredientId = entry.key.trim();
      if (sourceIngredientId.isEmpty) {
        continue;
      }
      if (!ingredientIds.contains(sourceIngredientId)) {
        throw const FormatException(
          'Замены можно добавлять только для выбранных ингредиентов.',
        );
      }

      final cleanedSubstitutions = <String>{};
      for (final candidate in entry.value) {
        final candidateId = candidate.trim();
        if (candidateId.isEmpty) {
          continue;
        }
        if (candidateId == sourceIngredientId) {
          throw const FormatException(
            'Ингредиент не может быть заменой самому себе.',
          );
        }
        if (!allIngredientIds.contains(candidateId)) {
          throw const FormatException(
            'Список замен содержит неизвестный ингредиент.',
          );
        }
        cleanedSubstitutions.add(candidateId);
      }

      if (cleanedSubstitutions.isEmpty) {
        continue;
      }

      final sortedSubstitutions = cleanedSubstitutions.toList(growable: false)
        ..sort(
          (left, right) => (state.ingredientsById[left]?.name ?? left)
              .compareTo(state.ingredientsById[right]?.name ?? right),
        );
      normalized[sourceIngredientId] = sortedSubstitutions;
    }

    return normalized;
  }

  Map<String, String> _normalizeIngredientTextMap({
    required Set<String> ingredientIds,
    required Map<String, String> sourceMap,
    required String errorMessage,
  }) {
    final normalized = <String, String>{};
    for (final entry in sourceMap.entries) {
      final ingredientId = entry.key.trim();
      if (ingredientId.isEmpty) {
        continue;
      }
      if (!ingredientIds.contains(ingredientId)) {
        throw FormatException(errorMessage);
      }
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }
      normalized[ingredientId] = value;
    }
    return normalized;
  }

  List<String> _normalizeIngredientFlagIds({
    required Set<String> ingredientIds,
    required Set<String> sourceIds,
    required String errorMessage,
  }) {
    final normalized = <String>{};
    for (final id in sourceIds) {
      final ingredientId = id.trim();
      if (ingredientId.isEmpty) {
        continue;
      }
      if (!ingredientIds.contains(ingredientId)) {
        throw FormatException(errorMessage);
      }
      normalized.add(ingredientId);
    }
    return _sortIngredientIds(normalized);
  }

  List<String> _sortIngredientIds(Set<String> ingredientIds) {
    final sorted = ingredientIds.toList(growable: false)
      ..sort(
        (left, right) => (state.ingredientsById[left]?.name ?? left).compareTo(
          state.ingredientsById[right]?.name ?? right,
        ),
      );
    return sorted;
  }
}
