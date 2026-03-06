# Мой Бар (My Bar)

<p align="center">
  <img src="assets/icon.png" alt="My Bar Icon" width="96" height="96" />
</p>

Мобильное приложение на Flutter для управления домашним баром:

- отмечайте, какие ингредиенты у вас есть;
- получайте список доступных коктейлей;
- создавайте и редактируйте свои ингредиенты и коктейли;
- импортируйте и экспортируйте барную карту в JSON.

## Основные возможности

- `Сырой бар`: ингредиенты, поиск, сортировки, отметка наличия.
- `Барная карта`: доступные коктейли, список/плитка, теги, избранное.
- Неоновый UI: glow-эффекты, градиенты, кастомные tooltip, неоновый scrollbar.
- Неоновый стиль интерфейса достигается за счёт самописной библиотеки [animated_border_widgets](https://pub.dev/packages/animated_border_widgets), используемой для неоновых рамок и свечения.
- Редактирование ингредиентов: создание/изменение, включая фото по URL и из локального хранилища.
- Редактирование коктейлей: отдельная страница создания/изменения с полной настройкой рецепта.
- Логика рецептов: опциональные ингредиенты, ингредиенты-украшения, замены, количество и единицы измерения.
- Режимы интерфейса: `Режим посетителя` и `Режим барной карты`.
- Персистентность: выбранные ингредиенты, каталог и UI-настройки сохраняются между перезапусками.
- Импорт/экспорт JSON: полный каталог (ингредиенты + коктейли) с валидацией.
- Защита от пустого экспорта: ошибка `Барная карта не изменена`, если данных для экспорта нет.

## Технологический стек

- Flutter + Dart
- BLoC/Cubit (`flutter_bloc`)
- Локальное хранение: `shared_preferences`
- Импорт файлов: `file_picker`
- Экспорт/шаринг: `path_provider`, `share_plus`
- UI-эффекты: `animated_border_widgets`, `loading_animation_widget`, `google_fonts`

## Архитектура

Проект построен по слоям:

- `domain`: модели (`Ingredient`, `Cocktail`, `BarCatalog`) и константы тегов/типов бокалов.
- `data`: storage-абстракции + реализации на `SharedPreferences`, JSON-кодек барной карты.
- `cubit`: `BarCubit` и `BarState`, бизнес-логика доступности коктейлей и работы с каталогом.
- `presentation`: `BarHomeShell`, страницы и виджеты интерфейса.

Состояние приложения централизовано в `BarCubit` и сохраняется при каждом изменении.

## Структура проекта

Ключевые директории:

- `lib/app` - инициализация приложения.
- `lib/core` - тема, базовые виджеты, лоадеры, скроллбар.
- `lib/features/bar` - вся функциональность бара (data/domain/cubit/presentation).
- `assets/data/bar_template.json` - шаблонный каталог по умолчанию.
- `assets/icon.png` - исходная иконка приложения.
- `test/` - unit и widget тесты.

## Скриншоты

<table>
  <tr>
    <td align="center" valign="top">
      <img src="docs/screenshots/raw-bar.png" alt="Сырой бар" width="280" height="606" />
      <br />
      <sub><b>Сырой бар</b></sub>
      <br />
      <sub>Поиск, сортировки и наличие ингредиентов</sub>
    </td>
    <td align="center" valign="top">
      <img src="docs/screenshots/bar-menu-list.png" alt="Барная карта — список" width="280" height="606" />
      <br />
      <sub><b>Барная карта (список)</b></sub>
      <br />
      <sub>Раскрытая карточка коктейля и состав</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top">
      <img src="docs/screenshots/bar-menu-grid.png" alt="Барная карта — плитка" width="280" height="606" />
      <br />
      <sub><b>Барная карта (плитка)</b></sub>
      <br />
      <sub>Сеточный вид с быстрым просмотром</sub>
    </td>
    <td align="center" valign="top">
      <img src="docs/screenshots/cocktail-editor.png" alt="Редактор коктейля" width="280" height="606" />
      <br />
      <sub><b>Редактор коктейля</b></sub>
      <br />
      <sub>Создание и настройка рецепта</sub>
    </td>
  </tr>
</table>

## JSON формат барной карты

Файл импорта/экспорта имеет структуру:

```json
{
  "ingredients": [
    {
      "id": "vodka",
      "name": "Водка",
      "category": "Крепкий алкоголь",
      "image": "",
      "isDecoration": false,
      "isOptional": false
    }
  ],
  "cocktails": [
    {
      "id": "black-russian",
      "name": "Черный русский",
      "image": "",
      "ingredients": ["vodka", "coffee_liqueur"],
      "description": "Крепкий кофейный коктейль",
      "preparationSteps": [
        "Наполните рокс льдом",
        "Добавьте ингредиенты и аккуратно перемешайте"
      ],
      "glassType": "Рокс",
      "tags": ["Крепкие", "IBA"],
      "ingredientSubstitutions": {
        "coffee_liqueur": ["kahlua"]
      },
      "ingredientAmounts": {
        "vodka": "50",
        "coffee_liqueur": "20"
      },
      "ingredientUnits": {
        "vodka": "мл",
        "coffee_liqueur": "мл"
      },
      "optionalIngredients": [],
      "decorationIngredients": [],
      "isFavorite": false
    }
  ]
}
```

Валидация JSON выполняется в `BarCatalogJsonCodec`.

## Запуск проекта

### Требования

- Flutter stable
- Dart SDK `^3.10.8` (см. `pubspec.yaml`)
- Xcode (для iOS) / Android Studio + SDK (для Android)

### Установка и запуск

```bash
flutter pub get
flutter run
```

## Полезные команды

Проверка кода:

```bash
flutter analyze
```

Тесты:

```bash
flutter test
```

Обновить иконки приложения из `assets/icon.png`:

```bash
dart run flutter_launcher_icons
```

Если после смены иконки отображается старая версия, переустановите приложение на устройстве (удалить/установить заново).

## Экран управления баром

Меню `Управление баром`:

- Добавить ингредиент
- Добавить коктейль
- Настройки
- О приложении

В `Настройках`:

- Режим посетителя
- Режим барной карты
- Импортировать барную карту
- Экспортировать барную карту

## Лицензия

Проект распространяется по лицензии [MIT](LICENSE).

## Ссылки

- [animated_border_widgets](https://pub.dev/packages/animated_border_widgets)
- [LOGION](https://logion-web.ru/)
