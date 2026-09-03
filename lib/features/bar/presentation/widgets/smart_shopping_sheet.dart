import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localization.dart';
import '../../domain/models/ingredient.dart';

class SmartShoppingSheet extends StatefulWidget {
  const SmartShoppingSheet({
    required this.ingredientsById,
    required this.selectedIngredientIds,
    required this.shoppingIngredientIds,
    required this.unlockCountsByIngredientId,
    required this.favoriteUnlockCountsByIngredientId,
    required this.readOnly,
    required this.onToggleIngredient,
    required this.onClear,
    required this.onMarkAsOwned,
    super.key,
  });

  final Map<String, Ingredient> ingredientsById;
  final Set<String> selectedIngredientIds;
  final Set<String> shoppingIngredientIds;
  final Map<String, int> unlockCountsByIngredientId;
  final Map<String, int> favoriteUnlockCountsByIngredientId;
  final bool readOnly;
  final Future<void> Function(String ingredientId) onToggleIngredient;
  final Future<void> Function() onClear;
  final Future<void> Function(String ingredientId) onMarkAsOwned;

  @override
  State<SmartShoppingSheet> createState() => _SmartShoppingSheetState();
}

class _SmartShoppingSheetState extends State<SmartShoppingSheet> {
  late final Set<String> _shoppingIds;

  @override
  void initState() {
    super.initState();
    _shoppingIds = Set<String>.from(widget.shoppingIngredientIds);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        widget.ingredientsById.values
            .where((ingredient) {
              return !widget.selectedIngredientIds.contains(ingredient.id) &&
                  !_shoppingIds.contains(ingredient.id) &&
                  (widget.unlockCountsByIngredientId[ingredient.id] ?? 0) > 0;
            })
            .toList(growable: false)
          ..sort(_compareIngredients);
    final shoppingItems =
        _shoppingIds
            .map((id) => widget.ingredientsById[id])
            .whereType<Ingredient>()
            .toList(growable: false)
          ..sort(_compareIngredients);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.shopping_basket_rounded,
                    color: Color(0xFFFF91CA),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.tr(
                            'Умный список покупок',
                            'Smart shopping list',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          context.tr(
                            'Выбирайте то, что откроет больше новых коктейлей',
                            'Choose ingredients that unlock more cocktails',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFAEB9DB),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Закрыть', 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x334F5D88)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: <Widget>[
                  _SectionHeader(
                    title: context.tr(
                      'В списке · ${shoppingItems.length}',
                      'In your list · ${shoppingItems.length}',
                    ),
                    trailing: shoppingItems.isEmpty
                        ? null
                        : Wrap(
                            spacing: 4,
                            children: <Widget>[
                              IconButton(
                                tooltip: context.tr('Скопировать', 'Copy'),
                                onPressed: () => _copyList(shoppingItems),
                                icon: const Icon(Icons.copy_rounded, size: 20),
                              ),
                              if (!widget.readOnly)
                                IconButton(
                                  tooltip: context.tr('Очистить', 'Clear'),
                                  onPressed: _clear,
                                  icon: const Icon(
                                    Icons.delete_sweep_outlined,
                                    size: 21,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (shoppingItems.isEmpty)
                    _EmptyShoppingList(readOnly: widget.readOnly)
                  else
                    ...shoppingItems.map(
                      (ingredient) => _ShoppingIngredientTile(
                        ingredient: ingredient,
                        unlockCount:
                            widget.unlockCountsByIngredientId[ingredient.id] ??
                            0,
                        favoriteUnlockCount:
                            widget.favoriteUnlockCountsByIngredientId[ingredient
                                .id] ??
                            0,
                        inShoppingList: true,
                        readOnly: widget.readOnly,
                        onToggle: () => _toggle(ingredient.id),
                        onMarkAsOwned: () => _markAsOwned(ingredient.id),
                      ),
                    ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: context.tr(
                      'Выгоднее всего докупить',
                      'Best ingredients to buy',
                    ),
                  ),
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        context.tr(
                          'Новых рекомендаций пока нет.',
                          'No new recommendations yet.',
                        ),
                        style: const TextStyle(color: Color(0xFFAEB9DB)),
                      ),
                    )
                  else
                    ...suggestions
                        .take(12)
                        .map(
                          (ingredient) => _ShoppingIngredientTile(
                            ingredient: ingredient,
                            unlockCount:
                                widget.unlockCountsByIngredientId[ingredient
                                    .id] ??
                                0,
                            favoriteUnlockCount:
                                widget
                                    .favoriteUnlockCountsByIngredientId[ingredient
                                    .id] ??
                                0,
                            inShoppingList: false,
                            readOnly: widget.readOnly,
                            onToggle: () => _toggle(ingredient.id),
                            onMarkAsOwned: null,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _compareIngredients(Ingredient left, Ingredient right) {
    final unlockCompare = (widget.unlockCountsByIngredientId[right.id] ?? 0)
        .compareTo(widget.unlockCountsByIngredientId[left.id] ?? 0);
    if (unlockCompare != 0) {
      return unlockCompare;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  Future<void> _toggle(String ingredientId) async {
    if (widget.readOnly) {
      return;
    }
    setState(() {
      if (!_shoppingIds.add(ingredientId)) {
        _shoppingIds.remove(ingredientId);
      }
    });
    await widget.onToggleIngredient(ingredientId);
  }

  Future<void> _markAsOwned(String ingredientId) async {
    if (widget.readOnly) {
      return;
    }
    setState(() => _shoppingIds.remove(ingredientId));
    await widget.onMarkAsOwned(ingredientId);
  }

  Future<void> _clear() async {
    setState(_shoppingIds.clear);
    await widget.onClear();
  }

  Future<void> _copyList(List<Ingredient> ingredients) async {
    final lines = <String>[
      context.tr('Список покупок «Мой Бар»', 'My Bar shopping list'),
      ...ingredients.map((ingredient) {
        final count = widget.unlockCountsByIngredientId[ingredient.id] ?? 0;
        return count > 0
            ? '• ${ingredient.name} — ${_unlockLabel(context, count)}'
            : '• ${ingredient.name}';
      }),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Список скопирован', 'List copied'))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFA6D5),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _EmptyShoppingList extends StatelessWidget {
  const _EmptyShoppingList({required this.readOnly});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x334F6BAF)),
      ),
      child: Text(
        readOnly
            ? context.tr('Список покупок пуст.', 'Your shopping list is empty.')
            : context.tr(
                'Добавьте ингредиенты из рекомендаций ниже.',
                'Add ingredients from the recommendations below.',
              ),
        style: const TextStyle(color: Color(0xFFBDC7E5)),
      ),
    );
  }
}

class _ShoppingIngredientTile extends StatelessWidget {
  const _ShoppingIngredientTile({
    required this.ingredient,
    required this.unlockCount,
    required this.favoriteUnlockCount,
    required this.inShoppingList,
    required this.readOnly,
    required this.onToggle,
    required this.onMarkAsOwned,
  });

  final Ingredient ingredient;
  final int unlockCount;
  final int favoriteUnlockCount;
  final bool inShoppingList;
  final bool readOnly;
  final VoidCallback onToggle;
  final VoidCallback? onMarkAsOwned;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171B30),
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: inShoppingList
              ? const Color(0x777E8FFF)
              : const Color(0x334F5D88),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.ingredientCategoryLabel(ingredient.category),
                    style: const TextStyle(
                      color: Color(0xFF9EABD1),
                      fontSize: 12,
                    ),
                  ),
                  if (unlockCount > 0) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      [
                        _unlockLabel(context, unlockCount),
                        if (favoriteUnlockCount > 0)
                          context.tr(
                            'из них $favoriteUnlockCount избранных',
                            '$favoriteUnlockCount favorites',
                          ),
                      ].join(' · '),
                      style: const TextStyle(
                        color: Color(0xFF8FFFD4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onMarkAsOwned != null && !readOnly)
              IconButton(
                tooltip: context.tr('Уже куплено', 'Mark as bought'),
                onPressed: onMarkAsOwned,
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF8FFFD4),
                ),
              ),
            IconButton(
              tooltip: inShoppingList
                  ? context.tr('Убрать из списка', 'Remove from list')
                  : context.tr('Добавить в список', 'Add to list'),
              onPressed: readOnly ? null : onToggle,
              icon: Icon(
                inShoppingList
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.add_shopping_cart_rounded,
                color: inShoppingList
                    ? const Color(0xFFFFA6D5)
                    : const Color(0xFF9CB1FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _unlockLabel(BuildContext context, int count) {
  if (context.isEnglish) {
    return 'Unlocks $count ${count == 1 ? 'cocktail' : 'cocktails'}';
  }
  return 'Откроет $count ${_cocktailWord(count)}';
}

String _cocktailWord(int count) {
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return 'коктейлей';
  }
  switch (count % 10) {
    case 1:
      return 'коктейль';
    case 2:
    case 3:
    case 4:
      return 'коктейля';
    default:
      return 'коктейлей';
  }
}
