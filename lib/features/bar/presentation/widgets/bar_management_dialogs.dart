import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_glass_types.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';

@immutable
class AddIngredientInput {
  const AddIngredientInput({
    required this.name,
    required this.category,
    required this.image,
    required this.isDecoration,
    required this.isOptional,
  });

  final String name;
  final String category;
  final String image;
  final bool isDecoration;
  final bool isOptional;
}

@immutable
class AddCocktailInput {
  const AddCocktailInput({
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
}

const List<String> kIngredientUnits = <String>[
  '',
  'мл',
  'л',
  'ч.ложка',
  'ч.ложки',
  'ст.ложка',
  'ст.ложки',
  'долька',
  'шт',
  'капля',
  'по вкусу',
];

Future<AddIngredientInput?> showAddIngredientDialog(BuildContext context) {
  return _showIngredientDialog(
    context,
    title: 'Новый ингредиент',
    actionLabel: 'Добавить',
  );
}

Future<AddIngredientInput?> showEditIngredientDialog(
  BuildContext context, {
  required Ingredient ingredient,
}) {
  return _showIngredientDialog(
    context,
    title: 'Редактировать ингредиент',
    actionLabel: 'Сохранить',
    initialIngredient: ingredient,
  );
}

Future<AddIngredientInput?> _showIngredientDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  Ingredient? initialIngredient,
}) async {
  final nameController = TextEditingController(
    text: initialIngredient?.name ?? '',
  );
  final categoryController = TextEditingController(
    text: initialIngredient?.category ?? '',
  );
  final imageController = TextEditingController(
    text: initialIngredient?.image ?? '',
  );
  var isDecoration = initialIngredient?.isDecoration ?? false;
  var isOptional = initialIngredient?.isOptional ?? false;

  final result = await showDialog<AddIngredientInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF14182B),
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _DialogTextField(
                    controller: nameController,
                    label: 'Название*',
                    hint: 'Например, Кампари',
                  ),
                  const SizedBox(height: 12),
                  _DialogTextField(
                    controller: categoryController,
                    label: 'Категория',
                    hint: 'Ликёры',
                  ),
                  const SizedBox(height: 12),
                  _DialogTextField(
                    controller: imageController,
                    label: 'Фото (URL или путь файла)',
                    hint: 'https://... или /storage/.../photo.jpg',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
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
                      setState(() => imageController.text = path.trim());
                    },
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Выбрать с устройства'),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    value: isDecoration,
                    activeColor: const Color(0xFF7F89FF),
                    title: const Text('Украшение'),
                    subtitle: const Text(
                      'Не обязателен для доступности коктейля',
                    ),
                    onChanged: (value) {
                      setState(() => isDecoration = value ?? false);
                    },
                  ),
                  CheckboxListTile(
                    dense: true,
                    value: isOptional,
                    activeColor: const Color(0xFF7F89FF),
                    title: const Text('Опционально'),
                    subtitle: const Text(
                      'Можно пропустить при проверке ингредиентов',
                    ),
                    onChanged: (value) {
                      setState(() => isOptional = value ?? false);
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    AddIngredientInput(
                      name: nameController.text,
                      category: categoryController.text,
                      image: imageController.text,
                      isDecoration: isDecoration,
                      isOptional: isOptional,
                    ),
                  );
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  categoryController.dispose();
  imageController.dispose();
  return result;
}

Future<AddCocktailInput?> showAddCocktailDialog(
  BuildContext context,
  List<Ingredient> ingredients,
) {
  return _showCocktailDialog(
    context,
    ingredients: ingredients,
    title: 'Новый коктейль',
    actionLabel: 'Добавить',
  );
}

Future<AddCocktailInput?> showEditCocktailDialog(
  BuildContext context,
  List<Ingredient> ingredients, {
  required Cocktail cocktail,
}) {
  return _showCocktailDialog(
    context,
    ingredients: ingredients,
    title: 'Редактировать коктейль',
    actionLabel: 'Сохранить',
    initialCocktail: cocktail,
  );
}

Future<AddCocktailInput?> _showCocktailDialog(
  BuildContext context, {
  required List<Ingredient> ingredients,
  required String title,
  required String actionLabel,
  Cocktail? initialCocktail,
}) async {
  final nameController = TextEditingController(
    text: initialCocktail?.name ?? '',
  );
  final descriptionController = TextEditingController(
    text: initialCocktail?.description ?? '',
  );
  final preparationController = TextEditingController(
    text: _stepsToNumberedText(
      initialCocktail?.preparationSteps ?? const <String>[],
    ),
  );
  final imageController = TextEditingController(
    text: initialCocktail?.image ?? '',
  );

  final ingredientNamesById = <String, String>{
    for (final ingredient in ingredients) ingredient.id: ingredient.name,
  };

  final selectedIngredientIds =
      initialCocktail?.ingredients
          .where(ingredientNamesById.containsKey)
          .toSet() ??
      <String>{};

  final selectedSubstitutionsByIngredient = <String, Set<String>>{};
  for (final entry
      in initialCocktail?.ingredientSubstitutions.entries ??
          const Iterable<MapEntry<String, List<String>>>.empty()) {
    if (!selectedIngredientIds.contains(entry.key)) {
      continue;
    }
    final cleaned = entry.value
        .where((id) => ingredientNamesById.containsKey(id))
        .toSet();
    if (cleaned.isNotEmpty) {
      selectedSubstitutionsByIngredient[entry.key] = cleaned;
    }
  }

  final ingredientAmounts = <String, String>{};
  for (final entry
      in initialCocktail?.ingredientAmounts.entries ??
          const Iterable<MapEntry<String, String>>.empty()) {
    if (!selectedIngredientIds.contains(entry.key)) {
      continue;
    }
    if (entry.value.trim().isNotEmpty) {
      ingredientAmounts[entry.key] = entry.value.trim();
    }
  }

  final ingredientUnits = <String, String>{};
  for (final entry
      in initialCocktail?.ingredientUnits.entries ??
          const Iterable<MapEntry<String, String>>.empty()) {
    if (!selectedIngredientIds.contains(entry.key)) {
      continue;
    }
    if (entry.value.trim().isNotEmpty) {
      ingredientUnits[entry.key] = entry.value.trim();
    }
  }

  final optionalIngredientIds =
      initialCocktail?.optionalIngredients
          .where(selectedIngredientIds.contains)
          .toSet() ??
      <String>{};
  final decorationIngredientIds =
      initialCocktail?.decorationIngredients
          .where(selectedIngredientIds.contains)
          .toSet() ??
      <String>{};

  final selectedTags =
      initialCocktail?.tags.toSet() ?? <String>{kUserCocktailTag};
  var selectedGlassType =
      initialCocktail?.glassType ?? kDefaultCocktailGlassType;

  final amountControllers = <String, TextEditingController>{
    for (final ingredientId in selectedIngredientIds)
      ingredientId: TextEditingController(
        text: ingredientAmounts[ingredientId] ?? '',
      ),
  };

  final result = await showDialog<AddCocktailInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void removeIngredientState(String ingredientId) {
            selectedIngredientIds.remove(ingredientId);
            selectedSubstitutionsByIngredient.remove(ingredientId);
            optionalIngredientIds.remove(ingredientId);
            decorationIngredientIds.remove(ingredientId);
            ingredientAmounts.remove(ingredientId);
            ingredientUnits.remove(ingredientId);
            amountControllers.remove(ingredientId)?.dispose();
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF14182B),
            title: Text(title),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _DialogTextField(
                      controller: nameController,
                      label: 'Название*',
                      hint: 'Например, Негрони',
                    ),
                    const SizedBox(height: 12),
                    _DialogTextField(
                      controller: descriptionController,
                      label: 'Описание',
                      hint: 'Кампари, Джин, Вермут',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _DialogTextField(
                      controller: preparationController,
                      label: 'Шаги приготовления*',
                      hint:
                          '1. Наполните бокал льдом\n2. Добавьте ингредиенты\n3. Украсьте и подавайте',
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    _DialogTextField(
                      controller: imageController,
                      label: 'Фото (URL или путь файла)',
                      hint: 'https://... или /storage/.../photo.jpg',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
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
                        setState(() => imageController.text = path.trim());
                      },
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Выбрать с устройства'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGlassType,
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
                        setState(() => selectedGlassType = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ингредиенты*',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x334C5C8F)),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: ingredients
                            .map((ingredient) {
                              final selected = selectedIngredientIds.contains(
                                ingredient.id,
                              );
                              return CheckboxListTile(
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: selected,
                                activeColor: const Color(0xFF7F89FF),
                                title: Text(ingredient.name),
                                subtitle: Text(
                                  ingredient.category,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    if (value ?? false) {
                                      selectedIngredientIds.add(ingredient.id);
                                      amountControllers.putIfAbsent(
                                        ingredient.id,
                                        () => TextEditingController(
                                          text:
                                              ingredientAmounts[ingredient
                                                  .id] ??
                                              '',
                                        ),
                                      );
                                    } else {
                                      removeIngredientState(ingredient.id);
                                    }
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                    if (selectedIngredientIds.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      const Text(
                        'Параметры ингредиентов',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...ingredients
                          .where(
                            (item) => selectedIngredientIds.contains(item.id),
                          )
                          .toList(growable: false)
                          .map((item) {
                            final substitutions =
                                selectedSubstitutionsByIngredient[item.id] ??
                                const <String>{};
                            final substitutionsText = substitutions.isEmpty
                                ? 'Без замен'
                                : substitutions
                                      .map(
                                        (id) => ingredientNamesById[id] ?? id,
                                      )
                                      .join(', ');

                            final amountController =
                                amountControllers[item.id] ??
                                (amountControllers[item.id] =
                                    TextEditingController(
                                      text: ingredientAmounts[item.id] ?? '',
                                    ));

                            final rawUnit = ingredientUnits[item.id] ?? '';
                            final safeUnit = kIngredientUnits.contains(rawUnit)
                                ? rawUnit
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0x334C5C8F),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Удалить из рецепта',
                                        onPressed: () {
                                          setState(() {
                                            removeIngredientState(item.id);
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: TextField(
                                          controller: amountController,
                                          onChanged: (value) {
                                            final normalized = value.trim();
                                            if (normalized.isEmpty) {
                                              ingredientAmounts.remove(item.id);
                                            } else {
                                              ingredientAmounts[item.id] =
                                                  normalized;
                                            }
                                          },
                                          decoration: InputDecoration(
                                            labelText: 'Количество',
                                            hintText: '50',
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: safeUnit,
                                          isExpanded: true,
                                          dropdownColor: const Color(
                                            0xFF1D2240,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Единица',
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          items: kIngredientUnits
                                              .map(
                                                (unit) =>
                                                    DropdownMenuItem<String>(
                                                      value: unit,
                                                      child: Text(
                                                        unit.isEmpty
                                                            ? 'Без единицы'
                                                            : unit,
                                                      ),
                                                    ),
                                              )
                                              .toList(growable: false),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                ingredientUnits.remove(item.id);
                                              } else {
                                                ingredientUnits[item.id] =
                                                    value;
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
                                        selected: optionalIngredientIds
                                            .contains(item.id),
                                        label: const Text('Опционально'),
                                        selectedColor: const Color(0x335E83FF),
                                        onSelected: (value) {
                                          setState(() {
                                            if (value) {
                                              optionalIngredientIds.add(
                                                item.id,
                                              );
                                            } else {
                                              optionalIngredientIds.remove(
                                                item.id,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      FilterChip(
                                        selected: decorationIngredientIds
                                            .contains(item.id),
                                        label: const Text('Украшение'),
                                        selectedColor: const Color(0x333FC1E5),
                                        onSelected: (value) {
                                          setState(() {
                                            if (value) {
                                              decorationIngredientIds.add(
                                                item.id,
                                              );
                                            } else {
                                              decorationIngredientIds.remove(
                                                item.id,
                                              );
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
                                      onPressed: () async {
                                        final updated =
                                            await showDialog<Set<String>>(
                                              context: context,
                                              builder: (context) {
                                                return _IngredientSubstitutionsDialog(
                                                  allIngredients: ingredients,
                                                  sourceIngredient: item,
                                                  selectedIds: substitutions,
                                                );
                                              },
                                            );
                                        if (updated == null) {
                                          return;
                                        }
                                        setState(() {
                                          if (updated.isEmpty) {
                                            selectedSubstitutionsByIngredient
                                                .remove(item.id);
                                          } else {
                                            selectedSubstitutionsByIngredient[item
                                                    .id] =
                                                updated;
                                          }
                                        });
                                      },
                                      child: Text(
                                        substitutions.isEmpty
                                            ? 'Добавить замену'
                                            : 'Изменить',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
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
                            final selected = selectedTags.contains(tag);
                            return FilterChip(
                              selected: selected,
                              label: Text(tag),
                              selectedColor: const Color(0x336D78FF),
                              checkmarkColor: const Color(0xFFC6CEFF),
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    selectedTags.add(tag);
                                  } else {
                                    selectedTags.remove(tag);
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
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final normalizedSubstitutions = <String, Set<String>>{};
                  for (final entry
                      in selectedSubstitutionsByIngredient.entries) {
                    if (!selectedIngredientIds.contains(entry.key)) {
                      continue;
                    }
                    final cleaned = entry.value
                        .where(
                          (id) =>
                              id != entry.key &&
                              ingredientNamesById.containsKey(id),
                        )
                        .toSet();
                    if (cleaned.isNotEmpty) {
                      normalizedSubstitutions[entry.key] = cleaned;
                    }
                  }

                  final normalizedAmounts = <String, String>{};
                  for (final entry in ingredientAmounts.entries) {
                    if (!selectedIngredientIds.contains(entry.key)) {
                      continue;
                    }
                    final value = entry.value.trim();
                    if (value.isNotEmpty) {
                      normalizedAmounts[entry.key] = value;
                    }
                  }

                  final normalizedUnits = <String, String>{};
                  for (final entry in ingredientUnits.entries) {
                    if (!selectedIngredientIds.contains(entry.key)) {
                      continue;
                    }
                    final value = entry.value.trim();
                    if (value.isNotEmpty) {
                      normalizedUnits[entry.key] = value;
                    }
                  }

                  Navigator.of(context).pop(
                    AddCocktailInput(
                      name: nameController.text,
                      description: descriptionController.text,
                      preparationSteps: parsePreparationStepsText(
                        preparationController.text,
                      ),
                      image: imageController.text,
                      glassType: selectedGlassType,
                      ingredientIds: Set<String>.from(selectedIngredientIds),
                      ingredientSubstitutions: normalizedSubstitutions,
                      ingredientAmounts: normalizedAmounts,
                      ingredientUnits: normalizedUnits,
                      optionalIngredientIds: optionalIngredientIds
                          .where(selectedIngredientIds.contains)
                          .toSet(),
                      decorationIngredientIds: decorationIngredientIds
                          .where(selectedIngredientIds.contains)
                          .toSet(),
                      tags: Set<String>.from(selectedTags),
                    ),
                  );
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    },
  );

  for (final controller in amountControllers.values) {
    controller.dispose();
  }
  nameController.dispose();
  descriptionController.dispose();
  preparationController.dispose();
  imageController.dispose();

  return result;
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

List<String> parsePreparationStepsText(String source) {
  final lines = source
      .split('\n')
      .map(_normalizePreparationLine)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return lines;
}

String _normalizePreparationLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final withoutIndex = trimmed.replaceFirst(RegExp(r'^\d+\s*[\.)-]?\s*'), '');
  return withoutIndex.trim();
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

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
