import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/search/app_search_query.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bar_pressable.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../../domain/models/measurement_system.dart';
import '../../domain/models/party_plan.dart';
import '../widgets/neon_background.dart';
import '../widgets/portion_selector.dart';

class PartyModePage extends StatefulWidget {
  const PartyModePage({
    required this.cocktails,
    required this.ingredientsById,
    required this.missingIngredientIdsByCocktailId,
    required this.measurementSystem,
    required this.powerSavingMode,
    required this.readOnly,
    required this.onAddShoppingIngredients,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Map<String, Ingredient> ingredientsById;
  final Map<String, Set<String>> missingIngredientIdsByCocktailId;
  final MeasurementSystem measurementSystem;
  final bool powerSavingMode;
  final bool readOnly;
  final Future<void> Function(Iterable<String> ingredientIds)
  onAddShoppingIngredients;

  @override
  State<PartyModePage> createState() => _PartyModePageState();
}

class _PartyModePageState extends State<PartyModePage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _servingsByCocktailId = <String, int>{};
  String _query = '';
  bool _readyOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = AppSearchQuery(_query);
    final filtered =
        widget.cocktails
            .where((cocktail) {
              final isReady =
                  widget
                      .missingIngredientIdsByCocktailId[cocktail.id]
                      ?.isEmpty ??
                  true;
              if (_readyOnly && !isReady) {
                return false;
              }
              return query.matchesAny(<String>[
                cocktail.name,
                cocktail.description,
                ...cocktail.tags,
                ...cocktail.ingredients.map(
                  (id) => widget.ingredientsById[id]?.name ?? id,
                ),
              ]);
            })
            .toList(growable: false)
          ..sort((left, right) {
            final leftMissing =
                widget.missingIngredientIdsByCocktailId[left.id]?.length ?? 0;
            final rightMissing =
                widget.missingIngredientIdsByCocktailId[right.id]?.length ?? 0;
            final missingCompare = leftMissing.compareTo(rightMissing);
            if (missingCompare != 0) {
              return missingCompare;
            }
            return left.name.toLowerCase().compareTo(right.name.toLowerCase());
          });
    final selectedCocktailCount = _servingsByCocktailId.length;
    final totalServings = _servingsByCocktailId.values.fold<int>(
      0,
      (sum, servings) => sum + servings,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NeonBackground(
        topGlow: const Color(0xFFFF5BB0),
        bottomGlow: const Color(0xFF6A70FF),
        reduceEffects: widget.powerSavingMode,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: context.tr('Назад', 'Back'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.tr('Режим вечеринки', 'Party mode'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            context.tr(
                              'Выберите коктейли и количество порций',
                              'Choose cocktails and serving counts',
                            ),
                            style: const TextStyle(
                              color: Color(0xFFB8C3E2),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.tr(
                      'Поиск коктейлей…',
                      'Search cocktails…',
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.tr('Очистить', 'Clear'),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: const Color(0xCC111528),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x55768BDA)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilterChip(
                      selected: _readyOnly,
                      checkmarkColor: Colors.white,
                      selectedColor: const Color(0x554F63CC),
                      labelStyle: const TextStyle(color: Colors.white),
                      avatar: const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(context.tr('Только доступные', 'Ready only')),
                      onSelected: (value) => setState(() => _readyOnly = value),
                    ),
                    if (selectedCocktailCount == 0)
                      TextButton.icon(
                        onPressed: _selectReadyCocktails,
                        icon: const Icon(Icons.playlist_add_check_rounded),
                        label: Text(
                          context.tr('Выбрать готовые', 'Select ready'),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: context.tr('Снять выбор', 'Clear selection'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(_servingsByCocktailId.clear);
                        },
                        icon: const Icon(Icons.deselect_rounded),
                      ),
                  ],
                ),
              ),
              _PartySelectionSummary(
                cocktailCount: selectedCocktailCount,
                servingCount: totalServings,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.search_off_rounded,
                              color: Color(0xFF8997BF),
                              size: 38,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.tr('Ничего не найдено', 'Nothing found'),
                              style: const TextStyle(color: Color(0xFFB8C3E2)),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _resetFilters,
                              child: Text(
                                context.tr('Сбросить фильтры', 'Reset filters'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cocktail = filtered[index];
                          return _PartyCocktailTile(
                            key: ValueKey<String>(cocktail.id),
                            cocktail: cocktail,
                            missingCount:
                                widget
                                    .missingIngredientIdsByCocktailId[cocktail
                                        .id]
                                    ?.length ??
                                0,
                            servings: _servingsByCocktailId[cocktail.id],
                            powerSavingMode: widget.powerSavingMode,
                            onSelected: (selected) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (selected) {
                                  _servingsByCocktailId[cocktail.id] = 1;
                                } else {
                                  _servingsByCocktailId.remove(cocktail.id);
                                }
                              });
                            },
                            onServingsChanged: (servings) {
                              setState(() {
                                _servingsByCocktailId[cocktail.id] = servings;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: BarActionButton(
          powerSavingMode: widget.powerSavingMode,
          onPressed: _servingsByCocktailId.isEmpty ? null : _showPartyPlan,
          icon: Icons.calculate_rounded,
          label: context.tr(
            'Рассчитать · $totalServings порций',
            'Calculate · $totalServings servings',
          ),
        ),
      ),
    );
  }

  void _selectReadyCocktails() {
    final ready = widget.cocktails.where((cocktail) {
      return widget.missingIngredientIdsByCocktailId[cocktail.id]?.isEmpty ??
          true;
    });
    HapticFeedback.mediumImpact();
    setState(() {
      for (final cocktail in ready) {
        _servingsByCocktailId.putIfAbsent(cocktail.id, () => 1);
      }
    });
  }

  void _resetFilters() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    setState(() {
      _query = '';
      _readyOnly = false;
    });
  }

  Future<void> _showPartyPlan() async {
    final cocktailsById = <String, Cocktail>{
      for (final cocktail in widget.cocktails) cocktail.id: cocktail,
    };
    final selections = _servingsByCocktailId.entries
        .map((entry) {
          final cocktail = cocktailsById[entry.key];
          if (cocktail == null) {
            return null;
          }
          return PartyCocktailSelection(
            cocktail: cocktail,
            servings: entry.value,
          );
        })
        .whereType<PartyCocktailSelection>()
        .toList(growable: false);
    final totals = buildPartyIngredientTotals(
      selections: selections,
      ingredientsById: widget.ingredientsById,
      measurementSystem: widget.measurementSystem,
    );
    final missingIds = <String>{
      for (final selection in selections)
        ...widget.missingIngredientIdsByCocktailId[selection.cocktail.id] ??
            const <String>{},
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF111528),
      builder: (sheetContext) => _PartyPlanSheet(
        selections: selections,
        totals: totals,
        missingIds: missingIds,
        readOnly: widget.readOnly,
        powerSavingMode: widget.powerSavingMode,
        ingredientsById: widget.ingredientsById,
        onAddMissingToShoppingList: () =>
            widget.onAddShoppingIngredients(missingIds),
      ),
    );
  }
}

class _PartyCocktailTile extends StatelessWidget {
  const _PartyCocktailTile({
    required this.cocktail,
    required this.missingCount,
    required this.servings,
    required this.powerSavingMode,
    required this.onSelected,
    required this.onServingsChanged,
    super.key,
  });

  final Cocktail cocktail;
  final int missingCount;
  final int? servings;
  final bool powerSavingMode;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onServingsChanged;

  @override
  Widget build(BuildContext context) {
    final selected = servings != null;
    return AnimatedContainer(
      duration: AppMotion.duration(
        context,
        AppMotion.standard,
        powerSavingMode: powerSavingMode,
      ),
      curve: AppMotion.enterCurve,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF202543) : const Color(0xCC15192D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF8B91FF) : const Color(0x334F5D88),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: <Widget>[
            CheckboxListTile(
              activeColor: const Color(0xFF596CA9),
              checkColor: Colors.white,
              value: selected,
              onChanged: (value) => onSelected(value ?? false),
              title: Text(
                cocktail.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                missingCount == 0
                    ? context.tr('Можно приготовить сейчас', 'Ready now')
                    : context.tr(
                        'Не хватает ингредиентов: $missingCount',
                        'Missing ingredients: $missingCount',
                      ),
                style: TextStyle(
                  color: missingCount == 0
                      ? const Color(0xFF8FFFD4)
                      : const Color(0xFFFFBDD8),
                  fontSize: 12,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: selected ? 1 : 0),
              duration: AppMotion.duration(
                context,
                AppMotion.standard,
                powerSavingMode: powerSavingMode,
              ),
              curve: AppMotion.enterCurve,
              builder: (context, value, child) => ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: value,
                  child: ExcludeFocus(
                    excluding: !selected,
                    child: ExcludeSemantics(
                      excluding: !selected,
                      child: IgnorePointer(ignoring: !selected, child: child),
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PortionSelector(
                    servings: servings ?? 1,
                    compact: true,
                    powerSavingMode: powerSavingMode,
                    onChanged: onServingsChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartySelectionSummary extends StatelessWidget {
  const _PartySelectionSummary({
    required this.cocktailCount,
    required this.servingCount,
  });

  final int cocktailCount;
  final int servingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xAA191E36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x445F70AE)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.celebration_rounded, color: Color(0xFFFF91CA)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cocktailCount == 0
                  ? context.tr(
                      'Добавьте коктейли в план',
                      'Add cocktails to your plan',
                    )
                  : context.tr(
                      'Коктейлей в плане: $cocktailCount',
                      '$cocktailCount cocktails in plan',
                    ),
              style: const TextStyle(
                color: Color(0xFFDDE4FA),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            context.tr('$servingCount порц.', '$servingCount serv.'),
            style: const TextStyle(
              color: Color(0xFF8FFFD4),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyPlanSheet extends StatelessWidget {
  const _PartyPlanSheet({
    required this.selections,
    required this.totals,
    required this.missingIds,
    required this.readOnly,
    required this.powerSavingMode,
    required this.ingredientsById,
    required this.onAddMissingToShoppingList,
  });

  final List<PartyCocktailSelection> selections;
  final List<PartyIngredientTotal> totals;
  final Set<String> missingIds;
  final bool readOnly;
  final bool powerSavingMode;
  final Map<String, Ingredient> ingredientsById;
  final Future<void> Function() onAddMissingToShoppingList;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.celebration_rounded,
                    color: Color(0xFFFF91CA),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('План вечеринки', 'Party plan'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Скопировать', 'Copy'),
                    onPressed: () => _copyPlan(context),
                    icon: const Icon(Icons.copy_rounded),
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: <Widget>[
                  Text(
                    context.tr('Коктейли', 'Cocktails'),
                    style: _sectionStyle,
                  ),
                  ...selections.map(
                    (selection) => Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '• ${selection.cocktail.name} × ${selection.servings}',
                        style: const TextStyle(color: Color(0xFFE1E6F8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('Нужно подготовить', 'Ingredients to prepare'),
                    style: _sectionStyle,
                  ),
                  ...totals.map(
                    (total) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        total.name,
                        style: const TextStyle(color: Color(0xFFE1E6F8)),
                      ),
                      trailing: Text(
                        total.label(
                          unitLabelResolver: context.ingredientUnitLabel,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF9CB1FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (missingIds.isNotEmpty && !readOnly) ...<Widget>[
                    const SizedBox(height: 14),
                    _AddMissingShoppingAction(
                      ingredientCount: missingIds.length,
                      powerSavingMode: powerSavingMode,
                      onAdd: onAddMissingToShoppingList,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPlan(BuildContext context) async {
    final buffer = StringBuffer()
      ..writeln(context.tr('План вечеринки «Мой Бар»', 'My Bar party plan'))
      ..writeln()
      ..writeln(context.tr('Коктейли:', 'Cocktails:'));
    for (final selection in selections) {
      buffer.writeln('• ${selection.cocktail.name} × ${selection.servings}');
    }
    buffer
      ..writeln()
      ..writeln(context.tr('Ингредиенты:', 'Ingredients:'));
    for (final total in totals) {
      buffer.writeln(
        '• ${total.name}: ${total.label(unitLabelResolver: context.ingredientUnitLabel)}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('План скопирован', 'Plan copied'))),
    );
  }

  static const TextStyle _sectionStyle = TextStyle(
    color: Color(0xFFFFA6D5),
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );
}

/// Feedback lives inside the sheet: a snackbar on the underlying Scaffold
/// can be obscured by the modal barrier.
class _AddMissingShoppingAction extends StatefulWidget {
  const _AddMissingShoppingAction({
    required this.ingredientCount,
    required this.powerSavingMode,
    required this.onAdd,
  });

  final int ingredientCount;
  final bool powerSavingMode;
  final Future<void> Function() onAdd;

  @override
  State<_AddMissingShoppingAction> createState() =>
      _AddMissingShoppingActionState();
}

class _AddMissingShoppingActionState extends State<_AddMissingShoppingAction> {
  bool _adding = false;
  bool _added = false;
  bool _failed = false;

  Future<void> _add() async {
    if (_adding || _added) return;
    setState(() {
      _adding = true;
      _failed = false;
    });
    try {
      await widget.onAdd();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _adding = false;
        _added = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.ingredientCount;
    if (_added) {
      return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x222CBA8E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x664BCDA0)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.check_circle_rounded, color: Color(0xFF8FFFD4)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr(
                        'Добавлено в покупки · $count',
                        'Added to shopping · $count',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF8FFFD4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Недостающие ингредиенты теперь в разделе «Покупки» барной карты.',
                        'The missing ingredients are now in Shopping in your bar menu.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFBDC7E5),
                        fontSize: 12,
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
    return Column(
      children: <Widget>[
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(
                context.tr(
                  'Не удалось добавить ингредиенты. Попробуйте ещё раз.',
                  'Could not add ingredients. Please try again.',
                ),
                style: const TextStyle(color: Color(0xFFFFB4AB)),
              ),
            ),
          ),
        Semantics(
          liveRegion: true,
          child: BarActionButton(
            onPressed: _adding ? null : _add,
            powerSavingMode: widget.powerSavingMode,
            icon: _adding
                ? Icons.hourglass_top_rounded
                : Icons.add_shopping_cart_rounded,
            label: _adding
                ? context.tr('Добавляем…', 'Adding…')
                : _failed
                ? context.tr('Повторить добавление', 'Try again')
                : context.tr(
                    'Добавить недостающее в покупки · $count',
                    'Add missing to shopping · $count',
                  ),
          ),
        ),
      ],
    );
  }
}
