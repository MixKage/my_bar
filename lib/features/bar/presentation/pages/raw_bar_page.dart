import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/search/app_search_query.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bar_network_image.dart';
import '../../../../core/widgets/bar_pressable.dart';
import '../../../../core/widgets/neon_scrollbar.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../widgets/neon_background.dart';

enum IngredientSortMode { alphabet, availability, category, demand }

extension on IngredientSortMode {
  String label(BuildContext context) {
    switch (this) {
      case IngredientSortMode.alphabet:
        return context.tr('По алфавиту', 'Alphabetical');
      case IngredientSortMode.availability:
        return context.tr('По наличию', 'By availability');
      case IngredientSortMode.category:
        return context.tr('По типу напитка', 'By drink type');
      case IngredientSortMode.demand:
        return context.tr('По востребованности', 'By demand');
    }
  }
}

class RawBarPage extends StatefulWidget {
  const RawBarPage({
    required this.ingredients,
    required this.cocktails,
    required this.selectedIngredientIds,
    required this.allowSelection,
    this.powerSavingMode = false,
    required this.bottomOverlayPadding,
    required this.onToggleIngredient,
    required this.onEditIngredient,
    required this.onManagePressed,
    super.key,
  });

  final List<Ingredient> ingredients;
  final List<Cocktail> cocktails;
  final Set<String> selectedIngredientIds;
  final bool allowSelection;
  final bool powerSavingMode;
  final double bottomOverlayPadding;
  final ValueChanged<String> onToggleIngredient;
  final Future<void> Function(Ingredient ingredient) onEditIngredient;
  final VoidCallback onManagePressed;

  @override
  State<RawBarPage> createState() => _RawBarPageState();
}

class _RawBarPageState extends State<RawBarPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _introSectionKey = GlobalKey();
  String _query = '';
  bool _isSearchPinned = false;
  double _searchPinProgress = 0;
  IngredientSortMode _sortMode = IngredientSortMode.alphabet;
  bool _selectedOnly = false;
  double _searchPinOffset = 0;
  bool _pinOffsetUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollChanged);
    _schedulePinOffsetUpdate();
  }

  @override
  void didUpdateWidget(covariant RawBarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allowSelection != widget.allowSelection ||
        oldWidget.ingredients.length != widget.ingredients.length) {
      _schedulePinOffsetUpdate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePinOffsetUpdate();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final horizontalPadding = resolveAdaptiveHorizontalPadding(
      context,
      maxContentWidth: 980,
    );
    final bottomContentPadding = widget.bottomOverlayPadding + 24;

    final searchQuery = AppSearchQuery(_query);
    final filteredIngredients = widget.ingredients
        .where(
          (ingredient) =>
              (!_selectedOnly ||
                  widget.selectedIngredientIds.contains(ingredient.id)) &&
              searchQuery.matchesAny(<String>[
                ingredient.name,
                ingredient.category,
                context.ingredientCategoryLabel(ingredient.category),
                ingredient.id,
              ]),
        )
        .toList(growable: false);
    final cocktailsByIngredient = _buildCocktailUsageMap(widget.cocktails);
    final sortedIngredients = _sortIngredients(
      filteredIngredients,
      cocktailsByIngredient,
    );
    final readyCocktailCount = _readyCocktailCount();

    return NeonBackground(
      topGlow: const Color(0xFF7D4BFF),
      bottomGlow: const Color(0xFF2AA6FF),
      reduceEffects: widget.powerSavingMode,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isSearchPinned ? 1 : 0,
              duration: widget.powerSavingMode
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: topInset + 88,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          const Color(0xFF7D4BFF).withValues(alpha: 0.8),
                          const Color(0xFF7D4BFF).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _searchPinProgress),
            duration: widget.powerSavingMode
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, visibility, child) {
              return NeonScrollbar(
                controller: _scrollController,
                visibility: visibility,
                child: child!,
              );
            },
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    key: _introSectionKey,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topInset + 14,
                      horizontalPadding,
                      0,
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                context.tr('Мой Бар', 'My Bar'),
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      foreground: Paint()
                                        ..shader =
                                            const LinearGradient(
                                              colors: <Color>[
                                                Color(0xFFCC9CFF),
                                                Color(0xFF67D5FF),
                                              ],
                                            ).createShader(
                                              const Rect.fromLTWH(
                                                0,
                                                0,
                                                200,
                                                80,
                                              ),
                                            ),
                                    ),
                              ),
                            ),
                            BarHeaderButton(
                              powerSavingMode: widget.powerSavingMode,
                              tooltip: context.tr('Фильтры', 'Filters'),
                              onPressed: _openSortModeSheet,
                              icon: Icons.filter_list_rounded,
                            ),
                            const SizedBox(width: 8),
                            BarHeaderButton(
                              powerSavingMode: widget.powerSavingMode,
                              tooltip: context.tr(
                                'Управление баром',
                                'Bar management',
                              ),
                              onPressed: widget.onManagePressed,
                              icon: Icons.tune_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            'Выбери бутылки и ингредиенты, которые уже есть дома',
                            'Select bottles and ingredients you already have at home',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFB8C1D9),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RawBarSummary(
                          selectedCount: widget.selectedIngredientIds.length,
                          totalCount: widget.ingredients.length,
                          readyCocktailCount: readyCocktailCount,
                          sortLabel: _sortMode.label(context),
                          selectedOnly: _selectedOnly,
                          powerSavingMode: widget.powerSavingMode,
                        ),
                        if (!widget.allowSelection)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              context.tr(
                                'Режим посетителя: отметка ингредиентов отключена',
                                'Visitor mode: ingredient selection is disabled',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF94A3CD),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _RawSearchHeaderDelegate(
                    topInset: topInset,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: _IngredientSearchField(
                        controller: _searchController,
                        powerSavingMode: widget.powerSavingMode,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        onClear: _query.isEmpty
                            ? null
                            : () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    14,
                    horizontalPadding,
                    bottomContentPadding,
                  ),
                  sliver: filteredIngredients.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 46),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.search_off_rounded,
                                    color: Color(0xFF8997BF),
                                    size: 36,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    context.tr(
                                      'Ничего не найдено',
                                      'Nothing found',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFFA8B0C8),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _resetSearchAndFilters,
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: Text(
                                      context.tr(
                                        'Сбросить фильтры',
                                        'Reset filters',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: sortedIngredients.length,
                          itemBuilder: (context, index) {
                            final ingredient = sortedIngredients[index];
                            final selected = widget.selectedIngredientIds
                                .contains(ingredient.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: IngredientCard(
                                ingredient: ingredient,
                                cocktails:
                                    cocktailsByIngredient[ingredient.id] ??
                                    const <Cocktail>[],
                                selected: selected,
                                allowSelection: widget.allowSelection,
                                powerSavingMode: widget.powerSavingMode,
                                onTap: widget.allowSelection
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        widget.onToggleIngredient(
                                          ingredient.id,
                                        );
                                      }
                                    : null,
                                onLongPress: widget.allowSelection
                                    ? () => widget.onEditIngredient(ingredient)
                                    : null,
                                onEdit: widget.allowSelection
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        widget.onEditIngredient(ingredient);
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateSearchPinOffset() {
    final context = _introSectionKey.currentContext;
    if (context == null) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    _searchPinOffset = box.size.height;
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }
    final offset = _scrollController.offset.clamp(0, double.infinity);
    final pinOffset = _searchPinOffset;
    final progress = pinOffset <= 0
        ? (offset > 0 ? 1.0 : 0.0)
        : (offset / pinOffset).clamp(0.0, 1.0);
    final pinned = progress >= 0.995;

    if (!mounted) {
      return;
    }

    final progressChanged = (_searchPinProgress - progress).abs() > 0.001;
    final pinnedChanged = _isSearchPinned != pinned;
    if (!progressChanged && !pinnedChanged) {
      return;
    }

    setState(() {
      _searchPinProgress = progress;
      _isSearchPinned = pinned;
    });
  }

  void _schedulePinOffsetUpdate() {
    if (_pinOffsetUpdateScheduled) {
      return;
    }
    _pinOffsetUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinOffsetUpdateScheduled = false;
      if (!mounted) {
        return;
      }
      _updateSearchPinOffset();
      _handleScrollChanged();
    });
  }

  Future<void> _openSortModeSheet() async {
    var draftSortMode = _sortMode;
    var draftSelectedOnly = _selectedOnly;
    final result = await showModalBottomSheet<_IngredientFilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF161B2E),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.filter_list_rounded),
                  title: Text(
                    context.tr('Показать и сортировать', 'Show and sort'),
                  ),
                ),
                SwitchListTile.adaptive(
                  activeThumbColor: const Color(0xFF8FA3FF),
                  value: draftSelectedOnly,
                  secondary: const Icon(Icons.inventory_2_rounded),
                  title: Text(
                    context.tr('Только то, что есть', 'Owned ingredients only'),
                  ),
                  onChanged: (value) =>
                      setSheetState(() => draftSelectedOnly = value),
                ),
                const Divider(color: Color(0x334F5D88)),
                ...IngredientSortMode.values.map(
                  (mode) => ListTile(
                    title: Text(mode.label(context)),
                    trailing: mode == draftSortMode
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF8FA3FF),
                          )
                        : const Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: Color(0xFF7C87AC),
                          ),
                    onTap: () => setSheetState(() => draftSortMode = mode),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: BarActionButton(
                      label: context.tr('Применить', 'Apply'),
                      icon: Icons.check_rounded,
                      powerSavingMode: widget.powerSavingMode,
                      onPressed: () => Navigator.of(sheetContext).pop(
                        _IngredientFilterSelection(
                          sortMode: draftSortMode,
                          selectedOnly: draftSelectedOnly,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _sortMode = result.sortMode;
      _selectedOnly = result.selectedOnly;
    });
  }

  void _resetSearchAndFilters() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedOnly = false;
    });
  }

  int _readyCocktailCount() {
    final ingredientsById = <String, Ingredient>{
      for (final ingredient in widget.ingredients) ingredient.id: ingredient,
    };
    return widget.cocktails.where((cocktail) {
      return cocktail.ingredients.every((ingredientId) {
        if (widget.selectedIngredientIds.contains(ingredientId) ||
            cocktail.isIngredientOptional(ingredientId) ||
            cocktail.isIngredientDecoration(ingredientId)) {
          return true;
        }
        final ingredient = ingredientsById[ingredientId];
        if (ingredient?.isOptional == true ||
            ingredient?.isDecoration == true) {
          return true;
        }
        final substitutions =
            cocktail.ingredientSubstitutions[ingredientId] ?? const <String>[];
        return substitutions.any(widget.selectedIngredientIds.contains);
      });
    }).length;
  }

  List<Ingredient> _sortIngredients(
    List<Ingredient> ingredients,
    Map<String, List<Cocktail>> cocktailsByIngredient,
  ) {
    final sorted = List<Ingredient>.from(ingredients);
    sorted.sort((left, right) {
      int compareByName() =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase());

      switch (_sortMode) {
        case IngredientSortMode.alphabet:
          return compareByName();
        case IngredientSortMode.availability:
          final leftSelected = widget.selectedIngredientIds.contains(left.id);
          final rightSelected = widget.selectedIngredientIds.contains(right.id);
          if (leftSelected != rightSelected) {
            return leftSelected ? -1 : 1;
          }
          return compareByName();
        case IngredientSortMode.category:
          final categoryCompare = context
              .ingredientCategoryLabel(left.category)
              .toLowerCase()
              .compareTo(
                context.ingredientCategoryLabel(right.category).toLowerCase(),
              );
          if (categoryCompare != 0) {
            return categoryCompare;
          }
          return compareByName();
        case IngredientSortMode.demand:
          final leftUsage = cocktailsByIngredient[left.id]?.length ?? 0;
          final rightUsage = cocktailsByIngredient[right.id]?.length ?? 0;
          if (leftUsage != rightUsage) {
            return rightUsage.compareTo(leftUsage);
          }
          return compareByName();
      }
    });
    return sorted;
  }

  Map<String, List<Cocktail>> _buildCocktailUsageMap(List<Cocktail> cocktails) {
    final usage = <String, List<Cocktail>>{};
    for (final cocktail in cocktails) {
      for (final ingredientId in cocktail.ingredients) {
        usage.putIfAbsent(ingredientId, () => <Cocktail>[]).add(cocktail);
      }
    }
    return usage;
  }
}

class _IngredientFilterSelection {
  const _IngredientFilterSelection({
    required this.sortMode,
    required this.selectedOnly,
  });

  final IngredientSortMode sortMode;
  final bool selectedOnly;
}

class _RawBarSummary extends StatelessWidget {
  const _RawBarSummary({
    required this.selectedCount,
    required this.totalCount,
    required this.readyCocktailCount,
    required this.sortLabel,
    required this.selectedOnly,
    required this.powerSavingMode,
  });

  final int selectedCount;
  final int totalCount;
  final int readyCocktailCount;
  final String sortLabel;
  final bool selectedOnly;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : selectedCount / totalCount;
    return Semantics(
      container: true,
      label: context.tr(
        'Выбрано ингредиентов: $selectedCount. Доступно коктейлей: $readyCocktailCount.',
        '$selectedCount ingredients selected. $readyCocktailCount cocktails ready.',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
        decoration: BoxDecoration(
          color: const Color(0xB815192C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x444D70B4)),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _RawBarMetric(
                    icon: Icons.inventory_2_rounded,
                    value: '$selectedCount',
                    label: context.tr('в наличии', 'in stock'),
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0x335B6C9D)),
                Expanded(
                  child: _RawBarMetric(
                    icon: Icons.local_bar_rounded,
                    value: '$readyCocktailCount',
                    label: context.tr('можно сделать', 'ready to make'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress.clamp(0, 1)),
                duration: AppMotion.duration(
                  context,
                  AppMotion.emphasized,
                  powerSavingMode: powerSavingMode,
                ),
                curve: AppMotion.enterCurve,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF29304C),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF67D5FF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.sort_rounded,
                  size: 14,
                  color: Color(0xFF8999C5),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    sortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8999C5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selectedOnly)
                  Text(
                    context.tr('Только в наличии', 'In stock only'),
                    style: const TextStyle(
                      color: Color(0xFF8FFFD4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RawBarMetric extends StatelessWidget {
  const _RawBarMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFF9AA8FF)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF9DA9CA), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IngredientSearchField extends StatelessWidget {
  const _IngredientSearchField({
    required this.controller,
    required this.powerSavingMode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool powerSavingMode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _RawSearchHeaderDelegate.searchFieldHeight,
      child: AnimatedGradientBorder(
        enabled: !powerSavingMode,
        showBorderWhenDisabled: true,
        disabledBorderColor: const Color(0xFF5568A8),
        colors: const <Color>[
          Color(0xFF6D5CFF),
          Color(0xFF52C7FF),
          Color(0xFF6D5CFF),
        ],
        borderRadius: BorderRadius.circular(18),
        borderWidth: 1.5,
        innerColor: const Color(0xFF111321),
        glowEffect: !powerSavingMode,
        glow: const AnimatedGradientBorderGlow(opacity: 0.6),
        child: Center(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 14),
              hintText: context.tr(
                'Поиск ингредиентов...',
                'Search ingredients...',
              ),
              hintStyle: TextStyle(color: Color(0xFF7180A7)),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFFA4B2DD)),
              prefixIconConstraints: BoxConstraints(
                minWidth: 42,
                minHeight: 42,
              ),
              suffixIcon: onClear == null
                  ? null
                  : IconButton(
                      tooltip: context.tr('Очистить', 'Clear'),
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RawSearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _RawSearchHeaderDelegate({required this.topInset, required this.child});

  final double topInset;
  final Widget child;

  static const double searchFieldHeight = 56;
  static const double _bottomSpacing = 8;

  @override
  double get minExtent => topInset + searchFieldHeight + _bottomSpacing;

  @override
  double get maxExtent => topInset + searchFieldHeight + _bottomSpacing;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, topInset, 0, _bottomSpacing),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _RawSearchHeaderDelegate oldDelegate) {
    return oldDelegate.topInset != topInset || oldDelegate.child != child;
  }
}

class IngredientCard extends StatelessWidget {
  const IngredientCard({
    required this.ingredient,
    required this.cocktails,
    required this.selected,
    required this.allowSelection,
    this.powerSavingMode = false,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    super.key,
  });

  final Ingredient ingredient;
  final List<Cocktail> cocktails;
  final bool selected;
  final bool allowSelection;
  final bool powerSavingMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: AppMotion.duration(
        context,
        AppMotion.quick,
        powerSavingMode: powerSavingMode,
      ),
      scale: powerSavingMode ? 1.0 : (selected ? 1.0 : 0.985),
      child: AnimatedGradientBorder(
        enabled: !powerSavingMode && selected,
        showBorderWhenDisabled: true,
        disabledBorderColor: powerSavingMode && selected
            ? const Color(0xFF6E86D8)
            : const Color(0xFF354067),
        glowEffect: !powerSavingMode && selected,
        glow: const AnimatedGradientBorderGlow(opacity: 0.5),
        borderRadius: BorderRadius.circular(22),
        borderWidth: 1.7,
        innerColor: const Color(0xFF15182B),
        colors: const <Color>[
          Color(0xFFBB7DFF),
          Color(0xFF49D1FF),
          Color(0xFFBB7DFF),
        ],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BarPressable(
            powerSavingMode: powerSavingMode,
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              height: 116,
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _IngredientImageThumb(ingredient: ingredient),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ingredient.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.ingredientCategoryLabel(
                              ingredient.category,
                            ),
                            style: const TextStyle(
                              color: Color(0xFFA4AFD3),
                              fontSize: 13,
                            ),
                          ),
                          if (ingredient.isDecoration || ingredient.isOptional)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: <Widget>[
                                  if (ingredient.isDecoration)
                                    _IngredientAttributePill(
                                      label: context.tr(
                                        'Украшение',
                                        'Decoration',
                                      ),
                                      color: Color(0xFF7CCBFF),
                                    ),
                                  if (ingredient.isOptional)
                                    _IngredientAttributePill(
                                      label: context.tr(
                                        'Опционально',
                                        'Optional',
                                      ),
                                      color: Color(0xFFB58BFF),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _cocktailHintText(context, cocktails),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC7CEF0),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        if (onEdit != null)
                          IconButton(
                            tooltip: context.tr(
                              'Изменить ингредиент',
                              'Edit ingredient',
                            ),
                            onPressed: onEdit,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: Color(0xFFA8B6DE),
                            ),
                          ),
                        AnimatedContainer(
                          duration: AppMotion.duration(
                            context,
                            AppMotion.standard,
                            powerSavingMode: powerSavingMode,
                          ),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: !allowSelection
                                ? const Color(0xFF2F3857)
                                : selected
                                ? const Color(0xFFB24EFF)
                                : const Color(0xFF242B46),
                            boxShadow: allowSelection && selected
                                ? const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x88B24EFF),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                          ),
                          child: AnimatedSwitcher(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.quick,
                              powerSavingMode: powerSavingMode,
                            ),
                            child: Icon(
                              !allowSelection
                                  ? Icons.lock_outline_rounded
                                  : selected
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              key: ValueKey<bool>(selected),
                              size: 20,
                              color: !allowSelection
                                  ? const Color(0xFFB8C4EB)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _cocktailHintText(BuildContext context, List<Cocktail> cocktails) {
    if (cocktails.isEmpty) {
      return context.tr(
        'Пока нет коктейлей с этим ингредиентом',
        'No cocktails with this ingredient yet',
      );
    }
    if (cocktails.length == 1) {
      return context.tr(
        'Приготовьте "${cocktails.first.name}"',
        'Make "${cocktails.first.name}"',
      );
    }
    if (context.isEnglish) {
      return 'Make ${cocktails.length} cocktails';
    }
    return 'Приготовьте ${cocktails.length} ${_cocktailWord(cocktails.length)}';
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
}

class _IngredientImageThumb extends StatelessWidget {
  const _IngredientImageThumb({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final glow = _IngredientGlowVisual.fromIngredient(ingredient);
    final layout = _kGlowOrbLayouts[glow.layoutIndex % _kGlowOrbLayouts.length];
    return SizedBox(
      width: 90,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Align(
            alignment: layout.primaryAnchor,
            child: Transform.translate(
              offset: Offset(
                glow.offsetX * 12 + layout.primaryBias.dx * 8,
                glow.offsetY * 10 + layout.primaryBias.dy * 6,
              ),
              child: SizedBox(
                width: 68 * glow.scale,
                height: 68 * glow.scale,
                child: _GlowOrb(color: glow.primary, opacity: glow.opacity),
              ),
            ),
          ),
          Align(
            alignment: layout.secondaryAnchor,
            child: Transform.translate(
              offset: Offset(
                -glow.offsetX * 10 + layout.secondaryBias.dx * 7,
                -glow.offsetY * 8 + layout.secondaryBias.dy * 6,
              ),
              child: SizedBox(
                width: 54 * (glow.scale * 0.94),
                height: 54 * (glow.scale * 0.94),
                child: _GlowOrb(
                  color: glow.secondary,
                  opacity: (glow.opacity * 0.78).clamp(0.16, 0.5),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BarNetworkImage(
                  imageUrl: ingredient.image,
                  loadingColor: const Color(0xFF8CA8FF),
                  loadingBackgroundColor: Colors.transparent,
                  errorWidget: const Icon(
                    Icons.local_bar_rounded,
                    color: Color(0xFF8FA3D8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: clampedOpacity),
            color.withValues(alpha: clampedOpacity * 0.45),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.58, 1],
        ),
      ),
    );
  }
}

class _IngredientGlowVisual {
  const _IngredientGlowVisual({
    required this.primary,
    required this.secondary,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.opacity,
    required this.layoutIndex,
  });

  factory _IngredientGlowVisual.fromIngredient(Ingredient ingredient) {
    final hash = _fnv1a32(ingredient.id);
    final fallbackHue = (hash % 360).toDouble();
    final fallbackPrimary = HSVColor.fromAHSV(
      1,
      fallbackHue,
      0.62,
      0.95,
    ).toColor();
    final fallbackSecondary = HSVColor.fromAHSV(
      1,
      (fallbackHue + 24) % 360,
      0.5,
      0.93,
    ).toColor();

    final primary = _parseHexColor(ingredient.glowColor) ?? fallbackPrimary;
    final secondary =
        _parseHexColor(ingredient.glowSecondaryColor ?? '') ??
        fallbackSecondary;

    return _IngredientGlowVisual(
      primary: primary,
      secondary: secondary,
      offsetX: ingredient.glowOffsetX.clamp(-0.6, 0.6),
      offsetY: ingredient.glowOffsetY.clamp(-0.6, 0.6),
      scale: ingredient.glowScale.clamp(0.7, 1.45),
      opacity: ingredient.glowOpacity.clamp(0.12, 0.56),
      layoutIndex: (hash >> 10) & 0x7FFFFFFF,
    );
  }

  final Color primary;
  final Color secondary;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double opacity;
  final int layoutIndex;
}

class _GlowOrbLayout {
  const _GlowOrbLayout({
    required this.primaryAnchor,
    required this.secondaryAnchor,
    required this.primaryBias,
    required this.secondaryBias,
  });

  final Alignment primaryAnchor;
  final Alignment secondaryAnchor;
  final Offset primaryBias;
  final Offset secondaryBias;
}

const List<_GlowOrbLayout> _kGlowOrbLayouts = <_GlowOrbLayout>[
  _GlowOrbLayout(
    primaryAnchor: Alignment.topLeft,
    secondaryAnchor: Alignment.bottomRight,
    primaryBias: Offset(-0.5, -0.45),
    secondaryBias: Offset(0.45, 0.4),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.topRight,
    secondaryAnchor: Alignment.bottomLeft,
    primaryBias: Offset(0.48, -0.42),
    secondaryBias: Offset(-0.42, 0.38),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.bottomLeft,
    secondaryAnchor: Alignment.topRight,
    primaryBias: Offset(-0.46, 0.44),
    secondaryBias: Offset(0.42, -0.4),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.bottomRight,
    secondaryAnchor: Alignment.topLeft,
    primaryBias: Offset(0.44, 0.4),
    secondaryBias: Offset(-0.44, -0.4),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.centerLeft,
    secondaryAnchor: Alignment.topRight,
    primaryBias: Offset(-0.52, 0.0),
    secondaryBias: Offset(0.4, -0.35),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.centerRight,
    secondaryAnchor: Alignment.bottomLeft,
    primaryBias: Offset(0.52, 0.0),
    secondaryBias: Offset(-0.38, 0.34),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.topCenter,
    secondaryAnchor: Alignment.bottomCenter,
    primaryBias: Offset(0.0, -0.5),
    secondaryBias: Offset(0.0, 0.42),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.bottomCenter,
    secondaryAnchor: Alignment.centerLeft,
    primaryBias: Offset(0.0, 0.46),
    secondaryBias: Offset(-0.4, -0.05),
  ),
  _GlowOrbLayout(
    primaryAnchor: Alignment.center,
    secondaryAnchor: Alignment.topLeft,
    primaryBias: Offset(0.0, 0.0),
    secondaryBias: Offset(-0.36, -0.36),
  ),
];

Color? _parseHexColor(String value) {
  final normalized = value.trim().replaceAll('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  if (normalized.length == 6) {
    return Color(0xFF000000 | parsed);
  }
  return Color(parsed);
}

int _fnv1a32(String source) {
  var hash = 0x811C9DC5;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

class _IngredientAttributePill extends StatelessWidget {
  const _IngredientAttributePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.96),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
