import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../cubit/bar_cubit.dart';
import '../data/bar_catalog_json_codec.dart';
import '../domain/models/cocktail.dart';
import 'pages/cocktail_editor_page.dart';
import 'pages/bar_menu_page.dart';
import 'pages/raw_bar_page.dart';
import 'widgets/bar_management_dialogs.dart';
import 'widgets/neon_bottom_navigation.dart';

class BarHomeShell extends StatefulWidget {
  const BarHomeShell({super.key});

  @override
  State<BarHomeShell> createState() => _BarHomeShellState();
}

class _BarHomeShellState extends State<BarHomeShell> {
  static const _jsonCodec = BarCatalogJsonCodec();

  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BarCubit>().state;
    final topInset = MediaQuery.paddingOf(context).top;
    final showOnlyBarMenu = state.barMenuOnlyMode;

    final pages = showOnlyBarMenu
        ? <Widget>[
            BarMenuPage(
              availableCocktails: state.availableCocktails,
              cocktailCount: state.cocktails.length,
              ingredientsById: state.ingredientsById,
              visitorMode: state.visitorMode,
              onManagePressed: () => _openBarManagement(),
              onEditCocktailPressed: _handleEditCocktail,
              onToggleFavoritePressed: _toggleFavorite,
            ),
          ]
        : <Widget>[
            RawBarPage(
              ingredients: state.ingredients,
              cocktails: state.cocktails,
              selectedIngredientIds: state.selectedIngredientIds,
              allowSelection: !state.visitorMode,
              onToggleIngredient: (id) => _toggleIngredient(id),
              onManagePressed: () => _openBarManagement(),
            ),
            BarMenuPage(
              availableCocktails: state.availableCocktails,
              cocktailCount: state.cocktails.length,
              ingredientsById: state.ingredientsById,
              visitorMode: state.visitorMode,
              onManagePressed: () => _openBarManagement(),
              onEditCocktailPressed: _handleEditCocktail,
              onToggleFavoritePressed: _toggleFavorite,
            ),
          ];

    final currentIndex = showOnlyBarMenu ? 0 : _currentTab;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            IndexedStack(index: currentIndex, children: pages),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 88,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF7D4BFF).withValues(alpha: 0.65),
                        const Color(0xFF7D4BFF).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!showOnlyBarMenu)
              Align(
                alignment: Alignment.bottomCenter,
                child: NeonBottomNavigation(
                  currentIndex: currentIndex,
                  onChanged: (index) => setState(() => _currentTab = index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleIngredient(String id) {
    return context.read<BarCubit>().toggleIngredient(id);
  }

  Future<void> _toggleFavorite(String cocktailId) {
    return context.read<BarCubit>().toggleCocktailFavorite(cocktailId);
  }

  Future<void> _openBarManagement() async {
    final action = await showModalBottomSheet<_BarManagementAction>(
      context: context,
      backgroundColor: const Color(0xFF161B2E),
      showDragHandle: true,
      builder: (context) {
        final isVisitorMode = context.read<BarCubit>().state.visitorMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!isVisitorMode) ...<Widget>[
                  ListTile(
                    leading: const Icon(Icons.add_box_rounded),
                    title: const Text('Добавить ингредиент'),
                    onTap: () => Navigator.pop(
                      context,
                      _BarManagementAction.addIngredient,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_bar_rounded),
                    title: const Text('Добавить коктейль'),
                    onTap: () => Navigator.pop(
                      context,
                      _BarManagementAction.addCocktail,
                    ),
                  ),
                  const Divider(height: 22),
                ],
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('Настройки'),
                  onTap: () =>
                      Navigator.pop(context, _BarManagementAction.settings),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('О приложении'),
                  onTap: () =>
                      Navigator.pop(context, _BarManagementAction.about),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _BarManagementAction.addIngredient:
        await _handleAddIngredient();
      case _BarManagementAction.addCocktail:
        await _handleAddCocktail();
      case _BarManagementAction.settings:
        await _openSettings();
      case _BarManagementAction.about:
        _showAbout();
    }
  }

  Future<void> _openSettings() async {
    final cubit = context.read<BarCubit>();
    var visitorMode = cubit.state.visitorMode;
    var barMenuOnlyMode = cubit.state.barMenuOnlyMode;

    final action = await showModalBottomSheet<_BarSettingsAction>(
      context: context,
      backgroundColor: const Color(0xFF161B2E),
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const ListTile(
                      leading: Icon(Icons.settings_suggest_rounded),
                      title: Text('Настройки барной карты'),
                    ),
                    SwitchListTile.adaptive(
                      value: visitorMode,
                      activeThumbColor: const Color(0xFF8FA3FF),
                      title: const Text('Режим посетителя'),
                      subtitle: const Text('Скрывает кнопки с редактированием'),
                      onChanged: (value) async {
                        setModalState(() => visitorMode = value);
                        await cubit.setVisitorMode(value);
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: barMenuOnlyMode,
                      activeThumbColor: const Color(0xFF8FA3FF),
                      title: const Text('Режим барной карты'),
                      subtitle: const Text(
                        'Показывает только страницу "Барная карта"',
                      ),
                      onChanged: (value) async {
                        setModalState(() => barMenuOnlyMode = value);
                        await cubit.setBarMenuOnlyMode(value);
                        if (value && mounted) {
                          setState(() => _currentTab = 1);
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      leading: const Icon(Icons.upload_file_rounded),
                      title: const Text('Импортировать барную карту'),
                      onTap: () =>
                          Navigator.pop(context, _BarSettingsAction.import),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text('Экспортировать барную карту'),
                      onTap: () =>
                          Navigator.pop(context, _BarSettingsAction.export),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _BarSettingsAction.import:
        await _handleImport();
      case _BarSettingsAction.export:
        await _handleExport();
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Мой Бар',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.local_bar_rounded),
      children: const <Widget>[
        Text('Приложение для управления домашним баром и подбором коктейлей.'),
      ],
    );
  }

  Future<void> _handleAddIngredient() async {
    final cubit = context.read<BarCubit>();
    final input = await showAddIngredientDialog(context);
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.addIngredient(
        name: input.name,
        category: input.category,
        image: input.image,
        isDecoration: input.isDecoration,
        isOptional: input.isOptional,
      );
      _showSnackBar('Ингредиент добавлен');
    } on FormatException catch (error) {
      _showSnackBar(error.message);
    }
  }

  Future<void> _handleAddCocktail() async {
    final cubit = context.read<BarCubit>();
    final ingredients = cubit.state.ingredients;
    if (ingredients.isEmpty) {
      _showSnackBar('Сначала добавь хотя бы один ингредиент');
      return;
    }

    final input = await Navigator.of(context).push<AddCocktailInput>(
      MaterialPageRoute<AddCocktailInput>(
        builder: (_) => CocktailEditorPage.create(ingredients: ingredients),
      ),
    );
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.addCocktail(
        name: input.name,
        description: input.description,
        preparationSteps: input.preparationSteps,
        image: input.image,
        glassType: input.glassType,
        ingredientIds: input.ingredientIds,
        ingredientSubstitutions: input.ingredientSubstitutions,
        ingredientAmounts: input.ingredientAmounts,
        ingredientUnits: input.ingredientUnits,
        optionalIngredientIds: input.optionalIngredientIds,
        decorationIngredientIds: input.decorationIngredientIds,
        tags: input.tags,
      );
      _showSnackBar('Коктейль добавлен');
    } on FormatException catch (error) {
      _showSnackBar(error.message);
    }
  }

  Future<void> _handleEditCocktail(Cocktail cocktail) async {
    final cubit = context.read<BarCubit>();
    final input = await Navigator.of(context).push<AddCocktailInput>(
      MaterialPageRoute<AddCocktailInput>(
        builder: (_) => CocktailEditorPage.edit(
          ingredients: cubit.state.ingredients,
          initialCocktail: cocktail,
        ),
      ),
    );
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.updateCocktail(
        cocktailId: cocktail.id,
        name: input.name,
        description: input.description,
        preparationSteps: input.preparationSteps,
        image: input.image,
        glassType: input.glassType,
        ingredientIds: input.ingredientIds,
        ingredientSubstitutions: input.ingredientSubstitutions,
        ingredientAmounts: input.ingredientAmounts,
        ingredientUnits: input.ingredientUnits,
        optionalIngredientIds: input.optionalIngredientIds,
        decorationIngredientIds: input.decorationIngredientIds,
        tags: input.tags,
      );
      _showSnackBar('Коктейль обновлён');
    } on FormatException catch (error) {
      _showSnackBar(error.message);
    }
  }

  Future<void> _handleImport() async {
    final cubit = context.read<BarCubit>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final content = await _readPickedFile(file);
      final catalog = _jsonCodec.decode(content);

      await cubit.importCatalog(catalog);
      _showSnackBar('Барная карта импортирована');
    } on FormatException catch (error) {
      _showSnackBar('Ошибка JSON: ${error.message}');
    } catch (error) {
      _showSnackBar('Не удалось импортировать файл: $error');
    }
  }

  Future<void> _handleExport() async {
    final cubit = context.read<BarCubit>();
    try {
      final catalog = cubit.exportCatalog();
      final payload = _jsonCodec.encode(catalog);
      final file = await _writeExportFile(payload);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'Экспорт барной карты "Мой Бар"',
        ),
      );

      _showSnackBar('Барная карта подготовлена к экспорту');
    } on FormatException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Не удалось экспортировать файл: $error');
    }
  }

  Future<String> _readPickedFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }

    throw const FormatException('Файл пустой или недоступен.');
  }

  Future<File> _writeExportFile(String payload) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/my_bar_map_$timestamp.json');
    await file.writeAsString(payload, flush: true);
    return file;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _BarManagementAction { addIngredient, addCocktail, settings, about }

enum _BarSettingsAction { import, export }
