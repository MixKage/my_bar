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

class _CocktailEditorPageState extends State<CocktailEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _preparationController;
  late final TextEditingController _imageController;

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

  bool _allowPop = false;

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
          backgroundColor: const Color(0xFF161B30),
          title: Text(title),
          leading: IconButton(
            tooltip: 'Назад',
            onPressed: _requestExit,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Сохранить'),
              ),
            ),
          ],
        ),
        body: NeonBackground(
          topGlow: const Color(0xFFFF5BB0),
          bottomGlow: const Color(0xFF6A70FF),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _EditorTextField(
                    controller: _nameController,
                    label: 'Название*',
                    hint: 'Например, Негрони',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _EditorTextField(
                    controller: _descriptionController,
                    label: 'Описание',
                    hint: 'Кампари, Джин, Вермут',
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _EditorTextField(
                    controller: _preparationController,
                    label: 'Шаги приготовления*',
                    hint:
                        '1. Наполните бокал льдом\n2. Добавьте ингредиенты\n3. Украсьте и подавайте',
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _EditorTextField(
                    controller: _imageController,
                    label: 'Фото (URL или путь файла)',
                    hint: 'https://... или /storage/.../photo.jpg',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickImageFromDevice,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Выбрать с устройства'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGlassType,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1D2240),
                    decoration: InputDecoration(
                      labelText: 'Тип бокала*',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                      setState(() => _selectedGlassType = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ингредиенты*',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x334C5C8F)),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: _ingredients
                          .map((ingredient) {
                            final selected = _selectedIngredientIds.contains(
                              ingredient.id,
                            );
                            return CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: selected,
                              activeColor: const Color(0xFF7F89FF),
                              title: Text(ingredient.name),
                              subtitle: Text(
                                ingredient.category,
                                style: const TextStyle(fontSize: 12),
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
                  if (_selectedIngredientIds.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    const Text(
                      'Параметры ингредиентов',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._ingredients
                        .where(
                          (item) => _selectedIngredientIds.contains(item.id),
                        )
                        .map(_buildIngredientOptionsCard),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Теги',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCocktailTags
                        .map((tag) {
                          final selected = _selectedTags.contains(tag);
                          return FilterChip(
                            selected: selected,
                            label: Text(tag),
                            selectedColor: const Color(0x336D78FF),
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
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestExit,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отмена'),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334C5C8F)),
      ),
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
                child: TextField(
                  controller: amountController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Количество',
                    hintText: '50',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: safeUnit,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1D2240),
                  decoration: InputDecoration(
                    labelText: 'Единица',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                selectedColor: const Color(0x335E83FF),
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
                selectedColor: const Color(0x333FC1E5),
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
        return;
      }
      _selectedIngredientIds.remove(ingredientId);
      _selectedSubstitutionsByIngredient.remove(ingredientId);
      _optionalIngredientIds.remove(ingredientId);
      _decorationIngredientIds.remove(ingredientId);
      _ingredientUnits.remove(ingredientId);
      _amountControllers.remove(ingredientId)?.dispose();
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
    _popWithResult(_buildDraft().toInput());
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
        child: Container(
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x334C5C8F)),
          ),
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
    required this.label,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
