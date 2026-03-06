import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_glass_types.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';
import '../widgets/bar_management_dialogs.dart';
import '../widgets/neon_background.dart';

class CocktailEditorPage extends StatefulWidget {
  const CocktailEditorPage.create({required this.ingredients, super.key})
    : initialCocktail = null;

  const CocktailEditorPage.edit({
    required this.ingredients,
    required this.initialCocktail,
    super.key,
  });

  final List<Ingredient> ingredients;
  final Cocktail? initialCocktail;

  bool get isEditing => initialCocktail != null;

  @override
  State<CocktailEditorPage> createState() => _CocktailEditorPageState();
}

enum _RequiredField { name, preparation, glass, ingredients }

class _CocktailEditorPageState extends State<CocktailEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _preparationController;
  late final TextEditingController _imageController;
  late final TextEditingController _ingredientSearchController;
  late final ScrollController _ingredientsScrollController;
  late final ScrollController _formScrollController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _descriptionFocusNode;
  late final FocusNode _preparationFocusNode;
  late final FocusNode _imageFocusNode;
  late final FocusNode _ingredientSearchFocusNode;

  late final List<Ingredient> _ingredients;
  late final Map<String, String> _ingredientNamesById;
  late final Set<String> _selectedIngredientIds;
  late final Map<String, Set<String>> _selectedSubstitutionsByIngredient;
  late final Map<String, String> _ingredientUnits;
  late final Set<String> _optionalIngredientIds;
  late final Set<String> _decorationIngredientIds;
  late final Set<String> _selectedTags;
  late String _selectedGlassType;
  late final Map<String, TextEditingController> _amountControllers;

  late final _CocktailDraft _initialDraft;
  final Set<_RequiredField> _invalidFields = <_RequiredField>{};
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _preparationFieldKey = GlobalKey();
  final GlobalKey _glassFieldKey = GlobalKey();
  final GlobalKey _ingredientsFieldKey = GlobalKey();

  bool _allowPop = false;
  String _ingredientSearchQuery = '';

  @override
  void initState() {
    super.initState();
    final initialCocktail = widget.initialCocktail;

    _ingredients = widget.ingredients.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    _ingredientNamesById = <String, String>{
      for (final ingredient in _ingredients) ingredient.id: ingredient.name,
    };

    _nameController = TextEditingController(text: initialCocktail?.name ?? '');
    _descriptionController = TextEditingController(
      text: initialCocktail?.description ?? '',
    );
    _preparationController = TextEditingController(
      text: _stepsToNumberedText(
        initialCocktail?.preparationSteps ?? const <String>[],
      ),
    );
    _imageController = TextEditingController(
      text: initialCocktail?.image ?? '',
    );
    _ingredientSearchController = TextEditingController();
    _ingredientsScrollController = ScrollController();
    _formScrollController = ScrollController();
    _nameFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _preparationFocusNode = FocusNode();
    _imageFocusNode = FocusNode();
    _ingredientSearchFocusNode = FocusNode();

    _selectedIngredientIds =
        initialCocktail?.ingredients
            .where(_ingredientNamesById.containsKey)
            .toSet() ??
        <String>{};

    _selectedSubstitutionsByIngredient = <String, Set<String>>{};
    for (final entry
        in initialCocktail?.ingredientSubstitutions.entries ??
            const Iterable<MapEntry<String, List<String>>>.empty()) {
      if (!_selectedIngredientIds.contains(entry.key)) {
        continue;
      }
      final cleaned = entry.value
          .where((id) => _ingredientNamesById.containsKey(id))
          .toSet();
      if (cleaned.isNotEmpty) {
        _selectedSubstitutionsByIngredient[entry.key] = cleaned;
      }
    }

    _ingredientUnits = <String, String>{};
    for (final entry
        in initialCocktail?.ingredientUnits.entries ??
            const Iterable<MapEntry<String, String>>.empty()) {
      if (!_selectedIngredientIds.contains(entry.key)) {
        continue;
      }
      final unit = entry.value.trim();
      if (unit.isNotEmpty) {
        _ingredientUnits[entry.key] = unit;
      }
    }

    _optionalIngredientIds =
        initialCocktail?.optionalIngredients
            .where(_selectedIngredientIds.contains)
            .toSet() ??
        <String>{};
    _decorationIngredientIds =
        initialCocktail?.decorationIngredients
            .where(_selectedIngredientIds.contains)
            .toSet() ??
        <String>{};

    _selectedTags = initialCocktail?.tags.toSet() ?? <String>{kUserCocktailTag};
    _selectedGlassType =
        initialCocktail?.glassType ?? kDefaultCocktailGlassType;

    _amountControllers = <String, TextEditingController>{
      for (final ingredientId in _selectedIngredientIds)
        ingredientId: TextEditingController(
          text: initialCocktail?.ingredientAmounts[ingredientId] ?? '',
        ),
    };

    _initialDraft = _buildDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _preparationController.dispose();
    _imageController.dispose();
    _ingredientSearchController.dispose();
    _ingredientsScrollController.dispose();
    _formScrollController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _preparationFocusNode.dispose();
    _imageFocusNode.dispose();
    _ingredientSearchFocusNode.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasUnsavedChanges => _buildDraft() != _initialDraft;

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? 'Редактирование коктейля'
        : 'Создание коктейля';
    final normalizedIngredientSearch = _ingredientSearchQuery
        .trim()
        .toLowerCase();
    final filteredIngredients = normalizedIngredientSearch.isEmpty
        ? _ingredients
        : _ingredients
              .where(
                (ingredient) =>
                    ingredient.name.toLowerCase().contains(
                      normalizedIngredientSearch,
                    ) ||
                    ingredient.category.toLowerCase().contains(
                      normalizedIngredientSearch,
                    ),
              )
              .toList(growable: false);

    return PopScope<AddCocktailInput?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          toolbarHeight: 76,
          centerTitle: true,
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: <Color>[Color(0xFFFFA6D8), Color(0xFF95D6FF)],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Настрой рецепт и состав',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFC8D2F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          flexibleSpace: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF7D4BFF).withValues(alpha: 0.52),
                        const Color(0xFF3D4D9C).withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  top: -18,
                  child: _AppBarGlowOrb(
                    size: 120,
                    color: const Color(0xFFB36BFF).withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  right: -14,
                  top: -12,
                  child: _AppBarGlowOrb(
                    size: 100,
                    color: const Color(0xFF53C9FF).withValues(alpha: 0.3),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 1.2,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0x00FFFFFF),
                          Color(0x66D4B3FF),
                          Color(0x66A7DDFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: NeonBackground(
          topGlow: const Color(0xFFFF5BB0),
          bottomGlow: const Color(0xFF6A70FF),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: _formScrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KeyedSubtree(
                    key: _nameFieldKey,
                    child: _EditorTextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      isInvalid: _invalidFields.contains(_RequiredField.name),
                      label: 'Название*',
                      hint: 'Например, Негрони',
                      onChanged: (_) {
                        setState(() {
                          if (_nameController.text.trim().isNotEmpty) {
                            _invalidFields.remove(_RequiredField.name);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EditorTextField(
                    controller: _descriptionController,
                    focusNode: _descriptionFocusNode,
                    isInvalid: false,
                    label: 'Описание',
                    hint: 'Кампари, Джин, Вермут',
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: _preparationFieldKey,
                    child: _EditorTextField(
                      controller: _preparationController,
                      focusNode: _preparationFocusNode,
                      isInvalid: _invalidFields.contains(
                        _RequiredField.preparation,
                      ),
                      label: 'Шаги приготовления*',
                      hint:
                          '1. Наполните бокал льдом\n2. Добавьте ингредиенты\n3. Украсьте и подавайте',
                      maxLines: 5,
                      onChanged: (_) {
                        setState(() {
                          if (parsePreparationStepsText(
                            _preparationController.text,
                          ).isNotEmpty) {
                            _invalidFields.remove(_RequiredField.preparation);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EditorTextField(
                    controller: _imageController,
                    focusNode: _imageFocusNode,
                    isInvalid: false,
                    label: 'Фото (URL или путь файла)',
                    hint: 'https://... или /storage/.../photo.jpg',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickImageFromDevice,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Выбрать с устройства'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0x55111425),
                      side: const BorderSide(color: Color(0x557A89BC)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle(text: 'Тип бокала*'),
                  const SizedBox(height: 6),
                  KeyedSubtree(
                    key: _glassFieldKey,
                    child: _FrostedPanel(
                      borderColor: _invalidFields.contains(_RequiredField.glass)
                          ? const Color(0xFFFF6B9A)
                          : null,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGlassType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1D2240),
                        decoration: _frostedInputDecoration(),
                        items: kCocktailGlassTypes
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedGlassType = value;
                            _invalidFields.remove(_RequiredField.glass);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle(text: 'Ингредиенты*'),
                  const SizedBox(height: 8),
                  KeyedSubtree(
                    key: _ingredientsFieldKey,
                    child: _FrostedPanel(
                      borderColor:
                          _invalidFields.contains(_RequiredField.ingredients)
                          ? const Color(0xFFFF6B9A)
                          : null,
                      child: SizedBox(
                        height: 320,
                        child: Column(
                          children: <Widget>[
                            _FrostedPanel(
                              borderRadius: BorderRadius.circular(12),
                              padding: EdgeInsets.zero,
                              child: TextField(
                                controller: _ingredientSearchController,
                                focusNode: _ingredientSearchFocusNode,
                                onChanged: (value) {
                                  setState(
                                    () => _ingredientSearchQuery = value,
                                  );
                                },
                                decoration:
                                    _frostedInputDecoration(
                                      hintText: 'Поиск ингредиентов...',
                                    ).copyWith(
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        color: Color(0xFFA4B2DD),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                            minWidth: 42,
                                            minHeight: 42,
                                          ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Scrollbar(
                                controller: _ingredientsScrollController,
                                thumbVisibility: true,
                                interactive: true,
                                radius: const Radius.circular(999),
                                thickness: 5,
                                child: ListView(
                                  controller: _ingredientsScrollController,
                                  children: filteredIngredients.isEmpty
                                      ? const <Widget>[
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 24,
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Ничего не найдено',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF9FAAD1),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ]
                                      : filteredIngredients
                                            .map((ingredient) {
                                              final selected =
                                                  _selectedIngredientIds
                                                      .contains(ingredient.id);
                                              return CheckboxListTile(
                                                dense: true,
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                                value: selected,
                                                activeColor: const Color(
                                                  0xFF7F89FF,
                                                ),
                                                title: Text(ingredient.name),
                                                subtitle: Text(
                                                  ingredient.category,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onChanged: (value) {
                                                  _toggleIngredientSelection(
                                                    ingredientId: ingredient.id,
                                                    selected: value ?? false,
                                                  );
                                                },
                                              );
                                            })
                                            .toList(growable: false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedIngredientIds.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    const _SectionTitle(text: 'Параметры ингредиентов'),
                    const SizedBox(height: 8),
                    ..._ingredients
                        .where(
                          (item) => _selectedIngredientIds.contains(item.id),
                        )
                        .map(_buildIngredientOptionsCard),
                  ],
                  const SizedBox(height: 14),
                  const _SectionTitle(text: 'Теги'),
                  const SizedBox(height: 8),
                  _FrostedPanel(
                    padding: const EdgeInsets.all(10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kCocktailTags
                          .map((tag) {
                            final selected = _selectedTags.contains(tag);
                            return FilterChip(
                              selected: selected,
                              label: Text(tag),
                              selectedColor: const Color(0x446D78FF),
                              backgroundColor: const Color(0x2218213C),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xAA7A89FF)
                                    : const Color(0x55758ABF),
                              ),
                              checkmarkColor: const Color(0xFFC6CEFF),
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: _FrostedPanel(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestExit,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отмена'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x557A89BC)),
                      backgroundColor: const Color(0x4412182F),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientOptionsCard(Ingredient ingredient) {
    final substitutions =
        _selectedSubstitutionsByIngredient[ingredient.id] ?? const <String>{};
    final substitutionsText = substitutions.isEmpty
        ? 'Без замен'
        : substitutions.map((id) => _ingredientNamesById[id] ?? id).join(', ');

    final amountController =
        _amountControllers[ingredient.id] ??
        (_amountControllers[ingredient.id] = TextEditingController());

    final rawUnit = _ingredientUnits[ingredient.id] ?? '';
    final safeUnit = kIngredientUnits.contains(rawUnit) ? rawUnit : '';

    return _FrostedPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  ingredient.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Удалить из рецепта',
                onPressed: () => _toggleIngredientSelection(
                  ingredientId: ingredient.id,
                  selected: false,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _FrostedPanel(
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: amountController,
                    onChanged: (_) => setState(() {}),
                    decoration: _frostedInputDecoration(
                      labelText: 'Количество',
                      hintText: '50',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FrostedPanel(
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.zero,
                  child: DropdownButtonFormField<String>(
                    initialValue: safeUnit,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1D2240),
                    decoration: _frostedInputDecoration(labelText: 'Единица'),
                    items: kIngredientUnits
                        .map(
                          (unit) => DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit.isEmpty ? 'Без единицы' : unit),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        if (value == null || value.isEmpty) {
                          _ingredientUnits.remove(ingredient.id);
                        } else {
                          _ingredientUnits[ingredient.id] = value;
                        }
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                selected: _optionalIngredientIds.contains(ingredient.id),
                label: const Text('Опционально'),
                selectedColor: const Color(0x445E83FF),
                backgroundColor: const Color(0x2218213C),
                side: BorderSide(
                  color: _optionalIngredientIds.contains(ingredient.id)
                      ? const Color(0xAA7A89FF)
                      : const Color(0x55758ABF),
                ),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _optionalIngredientIds.add(ingredient.id);
                    } else {
                      _optionalIngredientIds.remove(ingredient.id);
                    }
                  });
                },
              ),
              FilterChip(
                selected: _decorationIngredientIds.contains(ingredient.id),
                label: const Text('Украшение'),
                selectedColor: const Color(0x443FC1E5),
                backgroundColor: const Color(0x2218213C),
                side: BorderSide(
                  color: _decorationIngredientIds.contains(ingredient.id)
                      ? const Color(0xAA5CD0F6)
                      : const Color(0x55758ABF),
                ),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _decorationIngredientIds.add(ingredient.id);
                    } else {
                      _decorationIngredientIds.remove(ingredient.id);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Замены'),
            subtitle: Text(
              substitutionsText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: TextButton(
              onPressed: () => _editIngredientSubstitutions(ingredient),
              child: Text(
                substitutions.isEmpty ? 'Добавить замену' : 'Изменить',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleIngredientSelection({
    required String ingredientId,
    required bool selected,
  }) {
    setState(() {
      if (selected) {
        _selectedIngredientIds.add(ingredientId);
        _amountControllers.putIfAbsent(ingredientId, TextEditingController.new);
        _invalidFields.remove(_RequiredField.ingredients);
        return;
      }
      _selectedIngredientIds.remove(ingredientId);
      _selectedSubstitutionsByIngredient.remove(ingredientId);
      _optionalIngredientIds.remove(ingredientId);
      _decorationIngredientIds.remove(ingredientId);
      _ingredientUnits.remove(ingredientId);
      _amountControllers.remove(ingredientId)?.dispose();
      if (_selectedIngredientIds.isNotEmpty) {
        _invalidFields.remove(_RequiredField.ingredients);
      }
    });
  }

  Future<void> _editIngredientSubstitutions(Ingredient ingredient) async {
    final substitutions =
        _selectedSubstitutionsByIngredient[ingredient.id] ?? const <String>{};

    final updated = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return _IngredientSubstitutionsDialog(
          allIngredients: _ingredients,
          sourceIngredient: ingredient,
          selectedIds: substitutions,
        );
      },
    );
    if (updated == null) {
      return;
    }
    setState(() {
      if (updated.isEmpty) {
        _selectedSubstitutionsByIngredient.remove(ingredient.id);
      } else {
        _selectedSubstitutionsByIngredient[ingredient.id] = updated;
      }
    });
  }

  Future<void> _pickImageFromDevice() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    final path = picked.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    setState(() => _imageController.text = path.trim());
  }

  Future<void> _requestExit() async {
    if (!_hasUnsavedChanges) {
      _popWithResult();
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14182B),
          title: const Text('Выйти без сохранения?'),
          content: const Text(
            'У вас есть несохранённые изменения. Они будут потеряны.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (shouldLeave ?? false) {
      _popWithResult();
    }
  }

  void _submit() {
    final firstInvalidField = _validateBeforeSubmit();
    if (firstInvalidField != null) {
      _scrollToInvalidField(firstInvalidField);
      _showValidationError(firstInvalidField);
      return;
    }
    _popWithResult(_buildDraft().toInput());
  }

  _RequiredField? _validateBeforeSubmit() {
    final nextInvalidFields = <_RequiredField>{};

    if (_nameController.text.trim().isEmpty) {
      nextInvalidFields.add(_RequiredField.name);
    }
    if (parsePreparationStepsText(_preparationController.text).isEmpty) {
      nextInvalidFields.add(_RequiredField.preparation);
    }
    if (_selectedGlassType.trim().isEmpty) {
      nextInvalidFields.add(_RequiredField.glass);
    }
    if (_selectedIngredientIds.isEmpty) {
      nextInvalidFields.add(_RequiredField.ingredients);
    }

    if (nextInvalidFields.isEmpty) {
      if (_invalidFields.isNotEmpty) {
        setState(() => _invalidFields.clear());
      }
      return null;
    }

    setState(() {
      _invalidFields
        ..clear()
        ..addAll(nextInvalidFields);
    });

    for (final field in _RequiredField.values) {
      if (nextInvalidFields.contains(field)) {
        return field;
      }
    }
    return null;
  }

  Future<void> _scrollToInvalidField(_RequiredField field) async {
    final key = switch (field) {
      _RequiredField.name => _nameFieldKey,
      _RequiredField.preparation => _preparationFieldKey,
      _RequiredField.glass => _glassFieldKey,
      _RequiredField.ingredients => _ingredientsFieldKey,
    };

    final fieldContext = key.currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    }

    if (!mounted) {
      return;
    }

    switch (field) {
      case _RequiredField.name:
        _nameFocusNode.requestFocus();
        break;
      case _RequiredField.preparation:
        _preparationFocusNode.requestFocus();
        break;
      case _RequiredField.glass:
        FocusScope.of(context).unfocus();
        break;
      case _RequiredField.ingredients:
        _ingredientSearchFocusNode.requestFocus();
        break;
    }
  }

  void _showValidationError(_RequiredField field) {
    final message = switch (field) {
      _RequiredField.name => 'Укажите название коктейля',
      _RequiredField.preparation => 'Добавьте шаги приготовления',
      _RequiredField.glass => 'Выберите тип бокала',
      _RequiredField.ingredients => 'Выберите хотя бы один ингредиент',
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _popWithResult([AddCocktailInput? result]) {
    if (!mounted) {
      return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  _CocktailDraft _buildDraft() {
    final normalizedSubstitutions = <String, Set<String>>{};
    for (final entry in _selectedSubstitutionsByIngredient.entries) {
      if (!_selectedIngredientIds.contains(entry.key)) {
        continue;
      }
      final cleaned = entry.value
          .where(
            (id) => id != entry.key && _ingredientNamesById.containsKey(id),
          )
          .toSet();
      if (cleaned.isNotEmpty) {
        normalizedSubstitutions[entry.key] = cleaned;
      }
    }

    final normalizedAmounts = <String, String>{};
    for (final ingredientId in _selectedIngredientIds) {
      final value = _amountControllers[ingredientId]?.text.trim() ?? '';
      if (value.isNotEmpty) {
        normalizedAmounts[ingredientId] = value;
      }
    }

    final normalizedUnits = <String, String>{};
    for (final entry in _ingredientUnits.entries) {
      if (!_selectedIngredientIds.contains(entry.key)) {
        continue;
      }
      final value = entry.value.trim();
      if (value.isNotEmpty) {
        normalizedUnits[entry.key] = value;
      }
    }

    return _CocktailDraft(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      preparationSteps: parsePreparationStepsText(_preparationController.text),
      image: _imageController.text.trim(),
      glassType: _selectedGlassType,
      ingredientIds: Set<String>.from(_selectedIngredientIds),
      ingredientSubstitutions: normalizedSubstitutions,
      ingredientAmounts: normalizedAmounts,
      ingredientUnits: normalizedUnits,
      optionalIngredientIds: _optionalIngredientIds
          .where(_selectedIngredientIds.contains)
          .toSet(),
      decorationIngredientIds: _decorationIngredientIds
          .where(_selectedIngredientIds.contains)
          .toSet(),
      tags: Set<String>.from(_selectedTags),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, this.isInvalid = false});

  final String text;
  final bool isInvalid;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isInvalid ? const Color(0xFFFF89B3) : const Color(0xFFE4EAFF),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AppBarGlowOrb extends StatelessWidget {
  const _AppBarGlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color,
              blurRadius: size * 0.45,
              spreadRadius: size * 0.02,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _frostedInputDecoration({String? labelText, String? hintText}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _CocktailDraft {
  const _CocktailDraft({
    required this.name,
    required this.description,
    required this.preparationSteps,
    required this.image,
    required this.glassType,
    required this.ingredientIds,
    required this.ingredientSubstitutions,
    required this.ingredientAmounts,
    required this.ingredientUnits,
    required this.optionalIngredientIds,
    required this.decorationIngredientIds,
    required this.tags,
  });

  final String name;
  final String description;
  final List<String> preparationSteps;
  final String image;
  final String glassType;
  final Set<String> ingredientIds;
  final Map<String, Set<String>> ingredientSubstitutions;
  final Map<String, String> ingredientAmounts;
  final Map<String, String> ingredientUnits;
  final Set<String> optionalIngredientIds;
  final Set<String> decorationIngredientIds;
  final Set<String> tags;

  AddCocktailInput toInput() {
    return AddCocktailInput(
      name: name,
      description: description,
      preparationSteps: List<String>.from(preparationSteps),
      image: image,
      glassType: glassType,
      ingredientIds: Set<String>.from(ingredientIds),
      ingredientSubstitutions: <String, Set<String>>{
        for (final entry in ingredientSubstitutions.entries)
          entry.key: Set<String>.from(entry.value),
      },
      ingredientAmounts: Map<String, String>.from(ingredientAmounts),
      ingredientUnits: Map<String, String>.from(ingredientUnits),
      optionalIngredientIds: Set<String>.from(optionalIngredientIds),
      decorationIngredientIds: Set<String>.from(decorationIngredientIds),
      tags: Set<String>.from(tags),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _CocktailDraft &&
        other.name == name &&
        other.description == description &&
        listEquals(other.preparationSteps, preparationSteps) &&
        other.image == image &&
        other.glassType == glassType &&
        setEquals(other.ingredientIds, ingredientIds) &&
        _setMapEquals(other.ingredientSubstitutions, ingredientSubstitutions) &&
        mapEquals(other.ingredientAmounts, ingredientAmounts) &&
        mapEquals(other.ingredientUnits, ingredientUnits) &&
        setEquals(other.optionalIngredientIds, optionalIngredientIds) &&
        setEquals(other.decorationIngredientIds, decorationIngredientIds) &&
        setEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      description,
      Object.hashAll(preparationSteps),
      image,
      glassType,
      _stableSetHash(ingredientIds),
      _stableSetMapHash(ingredientSubstitutions),
      _stableStringMapHash(ingredientAmounts),
      _stableStringMapHash(ingredientUnits),
      _stableSetHash(optionalIngredientIds),
      _stableSetHash(decorationIngredientIds),
      _stableSetHash(tags),
    );
  }
}

class _IngredientSubstitutionsDialog extends StatefulWidget {
  const _IngredientSubstitutionsDialog({
    required this.allIngredients,
    required this.sourceIngredient,
    required this.selectedIds,
  });

  final List<Ingredient> allIngredients;
  final Ingredient sourceIngredient;
  final Set<String> selectedIds;

  @override
  State<_IngredientSubstitutionsDialog> createState() =>
      _IngredientSubstitutionsDialogState();
}

class _IngredientSubstitutionsDialogState
    extends State<_IngredientSubstitutionsDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final candidates =
        widget.allIngredients
            .where((item) => item.id != widget.sourceIngredient.id)
            .toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));

    return AlertDialog(
      backgroundColor: const Color(0xFF14182B),
      title: Text('Замены для "${widget.sourceIngredient.name}"'),
      content: SizedBox(
        width: 520,
        child: _FrostedPanel(
          constraints: const BoxConstraints(maxHeight: 320),
          padding: EdgeInsets.zero,
          child: ListView(
            shrinkWrap: true,
            children: candidates
                .map((candidate) {
                  final selected = _selected.contains(candidate.id);
                  return CheckboxListTile(
                    dense: true,
                    value: selected,
                    activeColor: const Color(0xFF7F89FF),
                    title: Text(candidate.name),
                    subtitle: Text(
                      candidate.category,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selected.add(candidate.id);
                        } else {
                          _selected.remove(candidate.id);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _EditorTextField extends StatelessWidget {
  const _EditorTextField({
    required this.controller,
    required this.focusNode,
    required this.isInvalid,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isInvalid;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(text: label, isInvalid: isInvalid),
        const SizedBox(height: 6),
        _FrostedPanel(
          padding: EdgeInsets.zero,
          borderColor: isInvalid ? const Color(0xFFFF6B9A) : null,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: _frostedInputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}

class _FrostedPanel extends StatelessWidget {
  const _FrostedPanel({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.margin,
    this.constraints,
    this.borderColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final Color? borderColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      constraints: constraints,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: const Color(0x7A111425),
              border: Border.all(color: borderColor ?? const Color(0x55758ABF)),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

String _stepsToNumberedText(List<String> steps) {
  if (steps.isEmpty) {
    return '';
  }
  return List<String>.generate(
    steps.length,
    (index) => '${index + 1}. ${steps[index]}',
    growable: false,
  ).join('\n');
}

bool _setMapEquals(Map<String, Set<String>> a, Map<String, Set<String>> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    final otherValue = b[entry.key];
    if (otherValue == null || !setEquals(entry.value, otherValue)) {
      return false;
    }
  }
  return true;
}

int _stableSetHash(Set<String> values) {
  final sorted = values.toList(growable: false)..sort();
  return Object.hashAll(sorted);
}

int _stableStringMapHash(Map<String, String> values) {
  final keys = values.keys.toList(growable: false)..sort();
  return Object.hashAll(keys.map((key) => Object.hash(key, values[key])));
}

int _stableSetMapHash(Map<String, Set<String>> values) {
  final keys = values.keys.toList(growable: false)..sort();
  return Object.hashAll(
    keys.map(
      (key) => Object.hash(key, _stableSetHash(values[key] ?? <String>{})),
    ),
  );
}
