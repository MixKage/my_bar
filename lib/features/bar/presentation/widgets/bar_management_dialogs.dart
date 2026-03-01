import 'package:flutter/material.dart';

import '../../domain/models/ingredient.dart';

@immutable
class AddIngredientInput {
  const AddIngredientInput({
    required this.name,
    required this.category,
    required this.image,
  });

  final String name;
  final String category;
  final String image;
}

@immutable
class AddCocktailInput {
  const AddCocktailInput({
    required this.name,
    required this.description,
    required this.image,
    required this.ingredientIds,
  });

  final String name;
  final String description;
  final String image;
  final Set<String> ingredientIds;
}

Future<AddIngredientInput?> showAddIngredientDialog(BuildContext context) {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final imageController = TextEditingController();

  return showDialog<AddIngredientInput>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF14182B),
        title: const Text('Новый ингредиент'),
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
                label: 'URL изображения',
                hint: 'https://...',
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
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      );
    },
  );
}

Future<AddCocktailInput?> showAddCocktailDialog(
  BuildContext context,
  List<Ingredient> ingredients,
) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final imageController = TextEditingController();
  final selectedIngredientIds = <String>{};

  return showDialog<AddCocktailInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF14182B),
            title: const Text('Новый коктейль'),
            content: SizedBox(
              width: 520,
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
                      controller: imageController,
                      label: 'URL изображения',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ингредиенты*',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
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
                                    } else {
                                      selectedIngredientIds.remove(
                                        ingredient.id,
                                      );
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
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    AddCocktailInput(
                      name: nameController.text,
                      description: descriptionController.text,
                      image: imageController.text,
                      ingredientIds: selectedIngredientIds,
                    ),
                  );
                },
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      );
    },
  );
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
