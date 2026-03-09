import 'package:flutter/widgets.dart';

import '../../features/bar/domain/models/catalog_data_source.dart';
import '../../features/bar/domain/models/measurement_system.dart';
import 'app_language.dart';

extension AppLocalizationX on BuildContext {
  bool get isEnglish =>
      Localizations.maybeLocaleOf(this)?.languageCode.toLowerCase() == 'en';

  String tr(String ru, String en) => isEnglish ? en : ru;

  String appLanguageLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return tr('Системный', 'System');
      case AppLanguage.russian:
        return tr('Русский', 'Russian');
      case AppLanguage.english:
        return tr('Английский', 'English');
    }
  }

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

  String cocktailTagLabel(String tag) =>
      _cocktailTagLabels[tag]?[isEnglish] ?? tag;

  String cocktailGlassTypeLabel(String glassType) =>
      _cocktailGlassLabels[glassType]?[isEnglish] ?? glassType;

  String ingredientUnitLabel(String unit) =>
      _ingredientUnitLabels[unit]?[isEnglish] ?? unit;

  String localizeErrorMessage(String source) {
    return _errorMessageLabels[source]?[isEnglish] ?? source;
  }
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
    };

const Map<String, _LocalizedLabel> _errorMessageLabels =
    <String, _LocalizedLabel>{
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
    };

class _LocalizedLabel {
  const _LocalizedLabel({required this.ru, required this.en});

  final String ru;
  final String en;

  String operator [](bool isEnglish) => isEnglish ? en : ru;
}
