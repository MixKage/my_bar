import 'package:flutter/widgets.dart';

import '../../features/bar/domain/models/catalog_data_source.dart';
import '../../features/bar/domain/models/measurement_system.dart';
import 'app_language.dart';
import 'app_translations.dart';

extension AppLocalizationX on BuildContext {
  bool get isEnglish =>
      Localizations.maybeLocaleOf(this)?.languageCode.toLowerCase() == 'en';

  bool get isRussian =>
      Localizations.maybeLocaleOf(this)?.languageCode.toLowerCase() == 'ru';

  String translateEnglish(String english) => translateAppText(
    Localizations.maybeLocaleOf(this)?.languageCode ?? 'en',
    english,
  );

  String tr(String ru, String en) => isRussian ? ru : translateEnglish(en);

  String appLanguageLabel(AppLanguage language) {
    if (language == AppLanguage.system) return tr('Системный', 'System');
    return language.nativeName;
  }

  String localizedLanguageName(AppLanguage language) => switch (language) {
    AppLanguage.system => tr('Системный', 'System'),
    AppLanguage.russian => tr('Русский', 'Russian'),
    AppLanguage.english => tr('Английский', 'English'),
    AppLanguage.spanish => tr('Испанский', 'Spanish'),
    AppLanguage.portuguese => tr('Португальский', 'Portuguese'),
    AppLanguage.german => tr('Немецкий', 'German'),
    AppLanguage.french => tr('Французский', 'French'),
    AppLanguage.italian => tr('Итальянский', 'Italian'),
    AppLanguage.turkish => tr('Турецкий', 'Turkish'),
    AppLanguage.chinese => tr('Китайский (упрощённый)', 'Chinese (Simplified)'),
    AppLanguage.japanese => tr('Японский', 'Japanese'),
    AppLanguage.korean => tr('Корейский', 'Korean'),
    AppLanguage.hindi => tr('Хинди', 'Hindi'),
    AppLanguage.arabic => tr('Арабский', 'Arabic'),
  };

  String measurementSystemLabel(MeasurementSystem system) {
    switch (system) {
      case MeasurementSystem.flOz:
        return 'fl oz';
      case MeasurementSystem.ml:
        return 'ml';
      case MeasurementSystem.cl:
        return 'cl';
    }
  }

  String catalogDataSourceTitle(CatalogDataSource source) {
    switch (source) {
      case CatalogDataSource.seed:
        return tr('Встроенная база', 'Built-in database');
      case CatalogDataSource.theCocktailDb:
        return 'TheCocktailDB';
    }
  }

  String catalogDataSourceDescription(CatalogDataSource source) {
    switch (source) {
      case CatalogDataSource.seed:
        return tr(
          'Работает офлайн, стабильный встроенный каталог.',
          'Works offline with a stable built-in catalog.',
        );
      case CatalogDataSource.theCocktailDb:
        return tr(
          'Загружает внешний каталог из сети с fallback на кэш и seed.',
          'Loads external catalog from network with cache/seed fallback.',
        );
    }
  }

  String cocktailTagLabel(String tag) => _label(_cocktailTagLabels[tag], tag);

  String cocktailGlassTypeLabel(String glassType) =>
      _label(_cocktailGlassLabels[glassType], glassType);

  String ingredientCategoryLabel(String category) {
    final normalizedCategory = _normalizeLocalizationKey(category);
    return _label(_ingredientCategoryLabels[normalizedCategory], category);
  }

  String ingredientUnitLabel(String unit) =>
      _label(_ingredientUnitLabels[unit], unit);

  String localizeErrorMessage(String source) {
    if (isRussian) return source;
    final label = _errorMessageLabels[source];
    if (label != null) return translateEnglish(label.en);
    for (final template in _errorTemplates) {
      final match = template.pattern.firstMatch(source);
      if (match == null) continue;
      final english = template.en.replaceAllMapped(
        RegExp(r'\{(\d+)\}'),
        (token) => match.group(int.parse(token[1]!) + 1) ?? '',
      );
      return translateEnglish(english);
    }
    return source;
  }

  String _label(_LocalizedLabel? label, String fallback) =>
      label == null ? fallback : tr(label.ru, label.en);
}

const Map<String, _LocalizedLabel> _cocktailTagLabels =
    <String, _LocalizedLabel>{
      'IBA': _LocalizedLabel(ru: 'IBA', en: 'IBA'),
      'Безалкогольные': _LocalizedLabel(
        ru: 'Безалкогольные',
        en: 'Non-alcoholic',
      ),
      'Крепкие': _LocalizedLabel(ru: 'Крепкие', en: 'Strong'),
      'Лонги': _LocalizedLabel(ru: 'Лонги', en: 'Long drinks'),
      'Мягкие': _LocalizedLabel(ru: 'Мягкие', en: 'Light'),
      'Пользовательские': _LocalizedLabel(ru: 'Пользовательские', en: 'Custom'),
      'Средней крепости': _LocalizedLabel(
        ru: 'Средней крепости',
        en: 'Medium strength',
      ),
      'Шоты': _LocalizedLabel(ru: 'Шоты', en: 'Shots'),
    };

const Map<String, _LocalizedLabel> _cocktailGlassLabels =
    <String, _LocalizedLabel>{
      'Бокал шале': _LocalizedLabel(ru: 'Бокал шале', en: 'Coupe glass'),
      'Винный бокал': _LocalizedLabel(ru: 'Винный бокал', en: 'Wine glass'),
      'Ирландский стакан': _LocalizedLabel(
        ru: 'Ирландский стакан',
        en: 'Irish glass',
      ),
      'Коллинз': _LocalizedLabel(ru: 'Коллинз', en: 'Collins'),
      'Кружка': _LocalizedLabel(ru: 'Кружка', en: 'Mug'),
      'Кубок': _LocalizedLabel(ru: 'Кубок', en: 'Goblet'),
      'Маргарита': _LocalizedLabel(ru: 'Маргарита', en: 'Margarita glass'),
      'Мартини': _LocalizedLabel(ru: 'Мартини', en: 'Martini glass'),
      'Пинта': _LocalizedLabel(ru: 'Пинта', en: 'Pint'),
      'Питчер': _LocalizedLabel(ru: 'Питчер', en: 'Pitcher'),
      'Рокс': _LocalizedLabel(ru: 'Рокс', en: 'Rocks'),
      'Рюмка': _LocalizedLabel(ru: 'Рюмка', en: 'Shot glass'),
      'Фужер': _LocalizedLabel(ru: 'Фужер', en: 'Flute'),
      'Хайболл': _LocalizedLabel(ru: 'Хайболл', en: 'Highball'),
      'Харрикейн': _LocalizedLabel(ru: 'Харрикейн', en: 'Hurricane'),
      'Шот': _LocalizedLabel(ru: 'Шот', en: 'Shot'),
    };

const Map<String, _LocalizedLabel> _ingredientUnitLabels =
    <String, _LocalizedLabel>{
      '': _LocalizedLabel(ru: 'Без единицы', en: 'No unit'),
      'ml': _LocalizedLabel(ru: 'мл', en: 'ml'),
      'мл': _LocalizedLabel(ru: 'мл', en: 'ml'),
      'l': _LocalizedLabel(ru: 'л', en: 'l'),
      'л': _LocalizedLabel(ru: 'л', en: 'l'),
      'oz': _LocalizedLabel(ru: 'унц', en: 'fl oz'),
      'fl oz': _LocalizedLabel(ru: 'унц', en: 'fl oz'),
      'унц': _LocalizedLabel(ru: 'унц', en: 'fl oz'),
      'cl': _LocalizedLabel(ru: 'cl', en: 'cl'),
      'tsp': _LocalizedLabel(ru: 'ч.ложка', en: 'tsp'),
      'tbsp': _LocalizedLabel(ru: 'ст.ложка', en: 'tbsp'),
      'shot': _LocalizedLabel(ru: 'шот', en: 'shot'),
      'шот': _LocalizedLabel(ru: 'шот', en: 'shot'),
      'part': _LocalizedLabel(ru: 'часть', en: 'part'),
      'часть': _LocalizedLabel(ru: 'часть', en: 'part'),
      'cup': _LocalizedLabel(ru: 'чашка', en: 'cup'),
      'чашка': _LocalizedLabel(ru: 'чашка', en: 'cup'),
      'dash': _LocalizedLabel(ru: 'дэш', en: 'dash'),
      'дэш': _LocalizedLabel(ru: 'дэш', en: 'dash'),
      'pinch': _LocalizedLabel(ru: 'щепотка', en: 'pinch'),
      'щепотка': _LocalizedLabel(ru: 'щепотка', en: 'pinch'),
      'ч.ложка': _LocalizedLabel(ru: 'ч.ложка', en: 'tsp'),
      'ч.ложки': _LocalizedLabel(ru: 'ч.ложки', en: 'tsp'),
      'ст.ложка': _LocalizedLabel(ru: 'ст.ложка', en: 'tbsp'),
      'ст.ложки': _LocalizedLabel(ru: 'ст.ложки', en: 'tbsp'),
      'долька': _LocalizedLabel(ru: 'долька', en: 'wedge'),
      'шт': _LocalizedLabel(ru: 'шт', en: 'pcs'),
      'капля': _LocalizedLabel(ru: 'капля', en: 'drop'),
      'по вкусу': _LocalizedLabel(ru: 'по вкусу', en: 'to taste'),
      'g': _LocalizedLabel(ru: 'г', en: 'g'),
      'gram': _LocalizedLabel(ru: 'г', en: 'g'),
      'sprig': _LocalizedLabel(ru: 'веточка', en: 'sprig'),
      'leaf': _LocalizedLabel(ru: 'лист', en: 'leaf'),
      'scoop': _LocalizedLabel(ru: 'шарик', en: 'scoop'),
      'twist': _LocalizedLabel(ru: 'полоска цедры', en: 'twist'),
      'stick': _LocalizedLabel(ru: 'палочка', en: 'stick'),
      'cube': _LocalizedLabel(ru: 'кубик', en: 'cube'),
      'bottle': _LocalizedLabel(ru: 'бутылка', en: 'bottle'),
      'can': _LocalizedLabel(ru: 'банка', en: 'can'),
      'package': _LocalizedLabel(ru: 'упаковка', en: 'package'),
      'inch': _LocalizedLabel(ru: 'дюйм', en: 'inch'),
      'lb': _LocalizedLabel(ru: 'фунт', en: 'lb'),
      'pint': _LocalizedLabel(ru: 'пинта', en: 'pint'),
      'qt': _LocalizedLabel(ru: 'кварта', en: 'qt'),
      'gal': _LocalizedLabel(ru: 'галлон', en: 'gal'),
      'handful': _LocalizedLabel(ru: 'горсть', en: 'handful'),
    };

const Map<String, _LocalizedLabel>
_ingredientCategoryLabels = <String, _LocalizedLabel>{
  'крепкий алкоголь': _LocalizedLabel(ru: 'Крепкий алкоголь', en: 'Spirits'),
  'spirits': _LocalizedLabel(ru: 'Крепкий алкоголь', en: 'Spirits'),
  'ликеры и аперитивы': _LocalizedLabel(
    ru: 'Ликёры и аперитивы',
    en: 'Liqueurs and aperitifs',
  ),
  'liqueurs and aperitifs': _LocalizedLabel(
    ru: 'Ликёры и аперитивы',
    en: 'Liqueurs and aperitifs',
  ),
  'специи травы и биттеры': _LocalizedLabel(
    ru: 'Специи, травы и биттеры',
    en: 'Spices, herbs and bitters',
  ),
  'spices herbs and bitters': _LocalizedLabel(
    ru: 'Специи, травы и биттеры',
    en: 'Spices, herbs and bitters',
  ),
  'газировка и безалкогольные миксеры': _LocalizedLabel(
    ru: 'Газировка и безалкогольные миксеры',
    en: 'Sodas and non-alcoholic mixers',
  ),
  'sodas and non alcoholic mixers': _LocalizedLabel(
    ru: 'Газировка и безалкогольные миксеры',
    en: 'Sodas and non-alcoholic mixers',
  ),
  'сиропы и подсластители': _LocalizedLabel(
    ru: 'Сиропы и подсластители',
    en: 'Syrups and sweeteners',
  ),
  'syrups and sweeteners': _LocalizedLabel(
    ru: 'Сиропы и подсластители',
    en: 'Syrups and sweeteners',
  ),
  'фрукты и ягоды': _LocalizedLabel(
    ru: 'Фрукты и ягоды',
    en: 'Fruits and berries',
  ),
  'fruits and berries': _LocalizedLabel(
    ru: 'Фрукты и ягоды',
    en: 'Fruits and berries',
  ),
  'молочные и сливочные': _LocalizedLabel(
    ru: 'Молочные и сливочные',
    en: 'Dairy and cream',
  ),
  'dairy and cream': _LocalizedLabel(
    ru: 'Молочные и сливочные',
    en: 'Dairy and cream',
  ),
  'соки и нектары': _LocalizedLabel(
    ru: 'Соки и нектары',
    en: 'Juices and nectars',
  ),
  'juices and nectars': _LocalizedLabel(
    ru: 'Соки и нектары',
    en: 'Juices and nectars',
  ),
  'пиво и сидр': _LocalizedLabel(ru: 'Пиво и сидр', en: 'Beer and cider'),
  'beer and cider': _LocalizedLabel(ru: 'Пиво и сидр', en: 'Beer and cider'),
  'вино и игристое': _LocalizedLabel(
    ru: 'Вино и игристое',
    en: 'Wine and sparkling',
  ),
  'wine and sparkling': _LocalizedLabel(
    ru: 'Вино и игристое',
    en: 'Wine and sparkling',
  ),
  'кофе чай и какао': _LocalizedLabel(
    ru: 'Кофе, чай и какао',
    en: 'Coffee, tea and cocoa',
  ),
  'coffee tea and cocoa': _LocalizedLabel(
    ru: 'Кофе, чай и какао',
    en: 'Coffee, tea and cocoa',
  ),
  'соусы и соленые добавки': _LocalizedLabel(
    ru: 'Соусы и солёные добавки',
    en: 'Sauces and savory additions',
  ),
  'sauces and savory additions': _LocalizedLabel(
    ru: 'Соусы и солёные добавки',
    en: 'Sauces and savory additions',
  ),
  'десертные ингредиенты': _LocalizedLabel(
    ru: 'Десертные ингредиенты',
    en: 'Dessert ingredients',
  ),
  'dessert ingredients': _LocalizedLabel(
    ru: 'Десертные ингредиенты',
    en: 'Dessert ingredients',
  ),
  'готовые смеси': _LocalizedLabel(ru: 'Готовые смеси', en: 'Premixes'),
  'premixes': _LocalizedLabel(ru: 'Готовые смеси', en: 'Premixes'),
};

const Map<String, _LocalizedLabel>
_errorMessageLabels = <String, _LocalizedLabel>{
  'Ингредиент не найден.': _LocalizedLabel(
    ru: 'Ингредиент не найден.',
    en: 'Ingredient not found.',
  ),
  'Коктейль не найден.': _LocalizedLabel(
    ru: 'Коктейль не найден.',
    en: 'Cocktail not found.',
  ),
  'Название ингредиента не может быть пустым.': _LocalizedLabel(
    ru: 'Название ингредиента не может быть пустым.',
    en: 'Ingredient name cannot be empty.',
  ),
  'Название коктейля не может быть пустым.': _LocalizedLabel(
    ru: 'Название коктейля не может быть пустым.',
    en: 'Cocktail name cannot be empty.',
  ),
  'Выбери хотя бы один ингредиент для коктейля.': _LocalizedLabel(
    ru: 'Выбери хотя бы один ингредиент для коктейля.',
    en: 'Choose at least one ingredient for the cocktail.',
  ),
  'Коктейль содержит неизвестные ингредиенты.': _LocalizedLabel(
    ru: 'Коктейль содержит неизвестные ингредиенты.',
    en: 'Cocktail contains unknown ingredients.',
  ),
  'Неизвестный тип бокала.': _LocalizedLabel(
    ru: 'Неизвестный тип бокала.',
    en: 'Unknown glass type.',
  ),
  'Барная карта не изменена': _LocalizedLabel(
    ru: 'Барная карта не изменена',
    en: 'Bar catalog has not been changed',
  ),
  'Файл пустой или недоступен.': _LocalizedLabel(
    ru: 'Файл пустой или недоступен.',
    en: 'File is empty or unavailable.',
  ),
  'JSON корень должен быть объектом.': _LocalizedLabel(
    ru: 'JSON корень должен быть объектом.',
    en: 'JSON root must be an object.',
  ),
  'Замены можно добавлять только для выбранных ингредиентов.': _LocalizedLabel(
    ru: 'Замены можно добавлять только для выбранных ингредиентов.',
    en: 'Substitutions can only be added for selected ingredients.',
  ),
  'Ингредиент не может быть заменой самому себе.': _LocalizedLabel(
    ru: 'Ингредиент не может быть заменой самому себе.',
    en: 'An ingredient cannot substitute itself.',
  ),
  'Список замен содержит неизвестный ингредиент.': _LocalizedLabel(
    ru: 'Список замен содержит неизвестный ингредиент.',
    en: 'The substitution list contains an unknown ingredient.',
  ),
  'Количество можно указать только для выбранных ингредиентов.':
      _LocalizedLabel(
        ru: 'Количество можно указать только для выбранных ингредиентов.',
        en: 'Amounts can only be set for selected ingredients.',
      ),
  'Единицу измерения можно указать только для выбранных ингредиентов.':
      _LocalizedLabel(
        ru: 'Единицу измерения можно указать только для выбранных ингредиентов.',
        en: 'Units can only be set for selected ingredients.',
      ),
  'Опциональными можно отметить только выбранные ингредиенты.': _LocalizedLabel(
    ru: 'Опциональными можно отметить только выбранные ингредиенты.',
    en: 'Only selected ingredients can be marked optional.',
  ),
  'Украшением можно отметить только выбранные ингредиенты.': _LocalizedLabel(
    ru: 'Украшением можно отметить только выбранные ингредиенты.',
    en: 'Only selected ingredients can be marked as garnish.',
  ),
};

final _errorTemplates = <_ErrorTemplate>[
  _ErrorTemplate(
    pattern: r'^Поле "(.+)" должно быть массивом\.$',
    en: 'Field "{0}" must be an array.',
  ),
  _ErrorTemplate(
    pattern: r'^Элемент "(.+)" должен быть объектом\.$',
    en: 'Item "{0}" must be an object.',
  ),
  _ErrorTemplate(
    pattern: r'^Повторяющийся id "(.+)" в "(.+)"\.$',
    en: 'Duplicate id "{0}" in "{1}".',
  ),
  _ErrorTemplate(
    pattern: r'^Коктейль "(.+)" содержит неизвестные ингредиенты\.$',
    en: 'Cocktail "{0}" contains unknown ingredients.',
  ),
  _ErrorTemplate(
    pattern: r'^Коктейль "(.+)" содержит неизвестный тег "(.+)"\.$',
    en: 'Cocktail "{0}" contains an unknown tag "{1}".',
  ),
  _ErrorTemplate(
    pattern: r'^Коктейль "(.+)" содержит неизвестный тип бокала "(.+)"\.$',
    en: 'Cocktail "{0}" contains an unknown glass type "{1}".',
  ),
  _ErrorTemplate(
    pattern:
        r'^Коктейль "(.+)" содержит замену для невыбранного ингредиента "(.+)"\.$',
    en: 'Cocktail "{0}" contains a substitution for unselected ingredient "{1}".',
  ),
  _ErrorTemplate(
    pattern:
        r'^Коктейль "(.+)" содержит неизвестный ингредиент-замену "(.+)"\.$',
    en: 'Cocktail "{0}" contains an unknown substitute ingredient "{1}".',
  ),
  _ErrorTemplate(
    pattern: r'^Коктейль "(.+)" содержит замену ингредиента самого на себя\.$',
    en: 'Cocktail "{0}" contains an ingredient substituted with itself.',
  ),
  _ErrorTemplate(
    pattern:
        r'^Коктейль "(.+)" содержит опциональный ингредиент "(.+)", которого нет в составе\.$',
    en: 'Cocktail "{0}" contains optional ingredient "{1}" that is not in the recipe.',
  ),
  _ErrorTemplate(
    pattern:
        r'^Коктейль "(.+)" содержит ингредиент-украшение "(.+)", которого нет в составе\.$',
    en: 'Cocktail "{0}" contains garnish ingredient "{1}" that is not in the recipe.',
  ),
  _ErrorTemplate(
    pattern:
        r'^Коктейль "(.+)" содержит количество для неизвестного ингредиента "(.+)"\.$',
    en: 'Cocktail "{0}" contains an amount for unknown ingredient "{1}".',
  ),
  _ErrorTemplate(
    pattern:
        r'^Коктейль "(.+)" содержит единицу измерения для неизвестного ингредиента "(.+)"\.$',
    en: 'Cocktail "{0}" contains a unit for unknown ingredient "{1}".',
  ),
];

class _ErrorTemplate {
  _ErrorTemplate({required String pattern, required this.en})
    : pattern = RegExp(pattern);
  final RegExp pattern;
  final String en;
}

class _LocalizedLabel {
  const _LocalizedLabel({required this.ru, required this.en});

  final String ru;
  final String en;
}

String _normalizeLocalizationKey(String value) {
  return value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-z0-9а-я]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
