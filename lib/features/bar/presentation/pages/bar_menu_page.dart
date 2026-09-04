import 'dart:math';

import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/search/app_search_query.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bar_network_image.dart';
import '../../../../core/widgets/bar_pressable.dart';
import 'surprise_cocktail_page.dart';
import '../../../../core/widgets/neon_scrollbar.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';
import '../../domain/models/measurement_system.dart';
import 'cocktail_details_page.dart';
import 'party_mode_page.dart';
import '../widgets/cocktail_glass_icon.dart';
import '../widgets/neon_background.dart';
import '../widgets/portion_selector.dart';
import '../widgets/smart_shopping_sheet.dart';

enum MenuViewMode { list, grid }

enum CocktailAvailabilityFilter { all, ready, missingOne, missingTwo }

class BarMenuPage extends StatefulWidget {
  const BarMenuPage({
    required this.cocktails,
    required this.selectedIngredientIds,
    required this.shoppingIngredientIds,
    required this.ingredientsById,
    required this.unlockCountsByIngredientId,
    required this.favoriteUnlockCountsByIngredientId,
    required this.visitorMode,
    required this.measurementSystem,
    this.powerSavingMode = false,
    required this.bottomOverlayPadding,
    required this.onManagePressed,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    required this.onToggleShoppingIngredient,
    required this.onClearShoppingList,
    required this.onAddShoppingIngredients,
    required this.onMarkShoppingIngredientAsOwned,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Set<String> selectedIngredientIds;
  final Set<String> shoppingIngredientIds;
  final Map<String, Ingredient> ingredientsById;
  final Map<String, int> unlockCountsByIngredientId;
  final Map<String, int> favoriteUnlockCountsByIngredientId;
  final bool visitorMode;
  final MeasurementSystem measurementSystem;
  final bool powerSavingMode;
  final double bottomOverlayPadding;
  final VoidCallback onManagePressed;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;
  final Future<void> Function(String ingredientId) onToggleShoppingIngredient;
  final Future<void> Function() onClearShoppingList;
  final Future<void> Function(Iterable<String> ingredientIds)
  onAddShoppingIngredients;
  final Future<void> Function(String ingredientId)
  onMarkShoppingIngredientAsOwned;

  @override
  State<BarMenuPage> createState() => _BarMenuPageState();
}

class _BarMenuPageState extends State<BarMenuPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailsScrollController = ScrollController();
  MenuViewMode _viewMode = MenuViewMode.list;
  bool _isViewModeOverriddenByUser = false;
  String? _expandedCocktailId;
  String? _selectedGridCocktailId;
  final Set<String> _selectedTags = <String>{};
  bool _favoritesOnly = false;
  CocktailAvailabilityFilter _availabilityFilter =
      CocktailAvailabilityFilter.all;
  String _searchQuery = '';
  int _servings = 1;
  final Random _random = Random();
  String? _lastSurpriseCocktailId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isViewModeOverriddenByUser) {
      return;
    }
    _viewMode = isTabletLayout(context) ? MenuViewMode.grid : MenuViewMode.list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final horizontalPadding = resolveAdaptiveHorizontalPadding(
      context,
      maxContentWidth: 1320,
    );
    final bottomContentPadding = widget.bottomOverlayPadding + 24;

    final missingIngredientIdsByCocktailId = _buildMissingIngredientIdsMap(
      widget.cocktails,
    );
    final missingIngredientsByCocktailId = _buildMissingIngredientNamesMap(
      missingIngredientIdsByCocktailId,
    );
    final searchQuery = AppSearchQuery(_searchQuery);
    final hasSearchQuery = !searchQuery.isEmpty;
    final sortedCocktails = _sortCocktailsByAvailability(
      widget.cocktails,
      missingIngredientsByCocktailId,
    );
    final baseFilteredCocktails = _applyFilters(
      sortedCocktails,
      searchQuery: searchQuery,
    );
    final filteredCocktails = _applyAvailabilityFilter(
      baseFilteredCocktails,
      missingIngredientIdsByCocktailId,
    );
    final availabilityCounts = <CocktailAvailabilityFilter, int>{
      for (final filter in CocktailAvailabilityFilter.values)
        filter: _countForAvailabilityFilter(
          baseFilteredCocktails,
          missingIngredientIdsByCocktailId,
          filter,
        ),
    };
    final availableCocktailCount = baseFilteredCocktails.where((cocktail) {
      return missingIngredientIdsByCocktailId[cocktail.id]?.isEmpty ?? true;
    }).length;
    final totalCocktailCount = baseFilteredCocktails.length;
    final expandedId = _resolveExpandedId(filteredCocktails);
    final hasActiveFilters =
        _favoritesOnly ||
        _selectedTags.isNotEmpty ||
        hasSearchQuery ||
        _availabilityFilter != CocktailAvailabilityFilter.all;
    final additionalFilterCount =
        (_favoritesOnly ? 1 : 0) + _selectedTags.length;

    return NeonBackground(
      topGlow: const Color(0xFFFF5BB0),
      bottomGlow: const Color(0xFF6A70FF),
      reduceEffects: widget.powerSavingMode,
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topInset + 20,
              horizontalPadding,
              6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.tr('Барная карта', 'Bar Menu'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          shadows: const <Shadow>[
                            Shadow(color: Color(0x88FF55B0), blurRadius: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: AppMotion.duration(
                          context,
                          AppMotion.quick,
                          powerSavingMode: widget.powerSavingMode,
                        ),
                        child: Text(
                          context.tr(
                            'Доступно $availableCocktailCount из $totalCocktailCount',
                            'Available $availableCocktailCount of $totalCocktailCount',
                          ),
                          key: ValueKey<String>(
                            '${filteredCocktails.length}:$availableCocktailCount',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFCCD3E8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ViewModeSwitch(
                  mode: _viewMode,
                  powerSavingMode: widget.powerSavingMode,
                  onModeChanged: (mode) {
                    setState(() {
                      _isViewModeOverriddenByUser = true;
                      _viewMode = mode;
                    });
                  },
                ),
                const SizedBox(width: 8),
                BarHeaderButton(
                  powerSavingMode: widget.powerSavingMode,
                  tooltip: context.tr('Управление баром', 'Bar management'),
                  onPressed: widget.onManagePressed,
                  icon: Icons.tune_rounded,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              4,
              horizontalPadding,
              8,
            ),
            child: _MenuDashboardCard(
              shoppingCount: widget.shoppingIngredientIds.length,
              servings: _servings,
              powerSavingMode: widget.powerSavingMode,
              onSurprise: () => _surpriseMe(
                filteredCocktails,
                missingIngredientsByCocktailId,
              ),
              onParty: () => _openPartyMode(missingIngredientIdsByCocktailId),
              onShopping: _openShoppingList,
              onServings: _pickServings,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                ...CocktailAvailabilityFilter.values.map((filter) {
                  final selected = filter == _availabilityFilter;
                  final count = availabilityCounts[filter] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        _availabilityFilterIcon(filter),
                        size: 16,
                        color: selected
                            ? const Color(0xFFFFE5F3)
                            : const Color(0xFFC2CDEB),
                      ),
                      label: Text(
                        '${_availabilityFilterLabel(context, filter)} · $count',
                      ),
                      selectedColor: const Color(0x554F63CC),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF8FA3FF)
                            : const Color(0x3AD8DDF6),
                      ),
                      backgroundColor: const Color(0x221A2142),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFFFFE5F3)
                            : const Color(0xFFC2CDEB),
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() => _availabilityFilter = filter);
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    checkmarkColor: Colors.white,
                    selectedColor: const Color(0x554F63CC),
                    labelStyle: const TextStyle(color: Colors.white),
                    selected: additionalFilterCount > 0,
                    showCheckmark: false,
                    avatar: const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      additionalFilterCount == 0
                          ? context.tr('Ещё фильтры', 'More filters')
                          : context.tr(
                              'Ещё · $additionalFilterCount',
                              'More · $additionalFilterCount',
                            ),
                    ),
                    onSelected: (_) => _openCocktailFilters(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.cocktails.isEmpty
                ? NoCocktailsView(
                    bottomInsetCompensation: widget.bottomOverlayPadding,
                    horizontalPadding: horizontalPadding,
                    powerSavingMode: widget.powerSavingMode,
                  )
                : _viewMode == MenuViewMode.grid
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final isTabletSplitLayout = constraints.maxWidth >= 980;
                      if (!isTabletSplitLayout) {
                        return CocktailGrid(
                          cocktails: filteredCocktails,
                          missingIngredientsByCocktailId:
                              missingIngredientsByCocktailId,
                          horizontalPadding: horizontalPadding,
                          bottomPadding: bottomContentPadding,
                          scrollController: _scrollController,
                          searchController: _searchController,
                          hasSearchQuery: hasSearchQuery,
                          hasActiveFilters: hasActiveFilters,
                          onSearchChanged: _handleSearchChanged,
                          onSearchClear: _handleSearchClear,
                          onResetFilters: _resetAllFilters,
                          powerSavingMode: widget.powerSavingMode,
                          selectedCocktailId: _selectedGridCocktailId,
                          onOpenCocktailDetails: (cocktail) =>
                              _openCocktailDetailsPage(
                                cocktail: cocktail,
                                missingIngredientsByCocktailId:
                                    missingIngredientsByCocktailId,
                              ),
                          onToggleFavoritePressed:
                              widget.onToggleFavoritePressed,
                        );
                      }

                      final selectedCocktailId = _resolveGridSelectedId(
                        filteredCocktails,
                      );
                      Cocktail? selectedCocktail;
                      if (selectedCocktailId != null) {
                        for (final cocktail in filteredCocktails) {
                          if (cocktail.id == selectedCocktailId) {
                            selectedCocktail = cocktail;
                            break;
                          }
                        }
                      }
                      final selectedMissingIngredients =
                          selectedCocktail == null
                          ? const <String>[]
                          : (missingIngredientsByCocktailId[selectedCocktail
                                    .id] ??
                                const <String>[]);

                      return _TabletGridLayout(
                        grid: CocktailGrid(
                          cocktails: filteredCocktails,
                          missingIngredientsByCocktailId:
                              missingIngredientsByCocktailId,
                          horizontalPadding: horizontalPadding,
                          bottomPadding: bottomContentPadding,
                          scrollController: _scrollController,
                          searchController: _searchController,
                          hasSearchQuery: hasSearchQuery,
                          hasActiveFilters: hasActiveFilters,
                          onSearchChanged: _handleSearchChanged,
                          onSearchClear: _handleSearchClear,
                          onResetFilters: _resetAllFilters,
                          powerSavingMode: widget.powerSavingMode,
                          selectedCocktailId: selectedCocktailId,
                          onOpenCocktailDetails: (cocktail) {
                            setState(
                              () => _selectedGridCocktailId = cocktail.id,
                            );
                          },
                          onToggleFavoritePressed:
                              widget.onToggleFavoritePressed,
                        ),
                        detailsPanel: _TabletCocktailInstructionPanel(
                          cocktail: selectedCocktail,
                          missingIngredientNames: selectedMissingIngredients,
                          ingredientsById: widget.ingredientsById,
                          visitorMode: widget.visitorMode,
                          measurementSystem: widget.measurementSystem,
                          servings: _servings,
                          powerSavingMode: widget.powerSavingMode,
                          bottomPadding: bottomContentPadding,
                          scrollController: _detailsScrollController,
                          onEditCocktailPressed: widget.onEditCocktailPressed,
                          onToggleFavoritePressed:
                              widget.onToggleFavoritePressed,
                        ),
                      );
                    },
                  )
                : CocktailList(
                    cocktails: filteredCocktails,
                    missingIngredientsByCocktailId:
                        missingIngredientsByCocktailId,
                    ingredientsById: widget.ingredientsById,
                    visitorMode: widget.visitorMode,
                    measurementSystem: widget.measurementSystem,
                    servings: _servings,
                    powerSavingMode: widget.powerSavingMode,
                    horizontalPadding: horizontalPadding,
                    bottomPadding: bottomContentPadding,
                    scrollController: _scrollController,
                    searchController: _searchController,
                    hasSearchQuery: hasSearchQuery,
                    hasActiveFilters: hasActiveFilters,
                    onSearchChanged: _handleSearchChanged,
                    onSearchClear: _handleSearchClear,
                    onResetFilters: _resetAllFilters,
                    expandedId: expandedId,
                    onEditCocktailPressed: widget.onEditCocktailPressed,
                    onToggleFavoritePressed: widget.onToggleFavoritePressed,
                    onToggleExpanded: (id) {
                      setState(() {
                        _expandedCocktailId = expandedId == id ? null : id;
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Cocktail> _applyFilters(
    List<Cocktail> source, {
    required AppSearchQuery searchQuery,
  }) {
    var filtered = source;

    if (_favoritesOnly) {
      filtered = filtered
          .where((cocktail) => cocktail.isFavorite)
          .toList(growable: false);
    }

    if (_selectedTags.isNotEmpty) {
      filtered = filtered
          .where((cocktail) => cocktail.tags.any(_selectedTags.contains))
          .toList(growable: false);
    }

    if (searchQuery.isEmpty) {
      return filtered;
    }

    return filtered
        .where(
          (cocktail) =>
              _matchesSearchQuery(cocktail: cocktail, searchQuery: searchQuery),
        )
        .toList(growable: false);
  }

  List<Cocktail> _applyAvailabilityFilter(
    List<Cocktail> source,
    Map<String, Set<String>> missingIngredientIdsByCocktailId,
  ) {
    if (_availabilityFilter == CocktailAvailabilityFilter.all) {
      return source;
    }
    return source
        .where((cocktail) {
          final missingCount =
              missingIngredientIdsByCocktailId[cocktail.id]?.length ?? 0;
          return switch (_availabilityFilter) {
            CocktailAvailabilityFilter.all => true,
            CocktailAvailabilityFilter.ready => missingCount == 0,
            CocktailAvailabilityFilter.missingOne => missingCount == 1,
            CocktailAvailabilityFilter.missingTwo => missingCount == 2,
          };
        })
        .toList(growable: false);
  }

  int _countForAvailabilityFilter(
    List<Cocktail> source,
    Map<String, Set<String>> missingIngredientIdsByCocktailId,
    CocktailAvailabilityFilter filter,
  ) {
    if (filter == CocktailAvailabilityFilter.all) {
      return source.length;
    }
    return source.where((cocktail) {
      final missingCount =
          missingIngredientIdsByCocktailId[cocktail.id]?.length ?? 0;
      return switch (filter) {
        CocktailAvailabilityFilter.all => true,
        CocktailAvailabilityFilter.ready => missingCount == 0,
        CocktailAvailabilityFilter.missingOne => missingCount == 1,
        CocktailAvailabilityFilter.missingTwo => missingCount == 2,
      };
    }).length;
  }

  bool _matchesSearchQuery({
    required Cocktail cocktail,
    required AppSearchQuery searchQuery,
  }) {
    final candidateFields = <String>[
      cocktail.id,
      cocktail.name,
      cocktail.description,
      context.cocktailGlassTypeLabel(cocktail.glassType),
      ...cocktail.tags,
      ...cocktail.tags.map(context.cocktailTagLabel),
      ...cocktail.ingredients.map((ingredientId) {
        final ingredientName = widget.ingredientsById[ingredientId]?.name;
        if (ingredientName == null || ingredientName.isEmpty) {
          return ingredientId;
        }
        return '$ingredientName $ingredientId';
      }),
    ];

    return searchQuery.matchesAny(candidateFields);
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _handleSearchClear() {
    if (_searchQuery.trim().isEmpty && _searchController.text.isEmpty) {
      return;
    }
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<Cocktail> _sortCocktailsByAvailability(
    List<Cocktail> source,
    Map<String, List<String>> missingIngredientsByCocktailId,
  ) {
    final available = <Cocktail>[];
    final unavailable = <Cocktail>[];

    for (final cocktail in source) {
      final missing = missingIngredientsByCocktailId[cocktail.id];
      if (missing == null || missing.isEmpty) {
        available.add(cocktail);
      } else {
        unavailable.add(cocktail);
      }
    }

    unavailable.sort((a, b) {
      final missingA = missingIngredientsByCocktailId[a.id]?.length ?? 0;
      final missingB = missingIngredientsByCocktailId[b.id]?.length ?? 0;
      final missingCompare = missingA.compareTo(missingB);
      if (missingCompare != 0) {
        return missingCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return <Cocktail>[...available, ...unavailable];
  }

  String? _resolveExpandedId(List<Cocktail> cocktails) {
    if (cocktails.isEmpty) {
      return null;
    }

    final hasActive = cocktails.any(
      (cocktail) => cocktail.id == _expandedCocktailId,
    );
    return hasActive ? _expandedCocktailId : cocktails.first.id;
  }

  String? _resolveGridSelectedId(List<Cocktail> cocktails) {
    if (cocktails.isEmpty) {
      return null;
    }

    final hasActive = cocktails.any(
      (cocktail) => cocktail.id == _selectedGridCocktailId,
    );
    return hasActive ? _selectedGridCocktailId : cocktails.first.id;
  }

  Map<String, Set<String>> _buildMissingIngredientIdsMap(
    List<Cocktail> cocktails,
  ) {
    return <String, Set<String>>{
      for (final cocktail in cocktails)
        cocktail.id: _missingIngredientIdsForCocktail(cocktail),
    };
  }

  Map<String, List<String>> _buildMissingIngredientNamesMap(
    Map<String, Set<String>> missingIngredientIdsByCocktailId,
  ) {
    return <String, List<String>>{
      for (final entry in missingIngredientIdsByCocktailId.entries)
        entry.key: entry.value
            .map((id) => widget.ingredientsById[id]?.name ?? id)
            .toList(growable: false),
    };
  }

  Set<String> _missingIngredientIdsForCocktail(Cocktail cocktail) {
    final missing = <String>{};

    for (final ingredientId in cocktail.ingredients) {
      if (widget.selectedIngredientIds.contains(ingredientId)) {
        continue;
      }

      final substitutions =
          cocktail.ingredientSubstitutions[ingredientId] ?? const <String>[];
      if (substitutions.any(widget.selectedIngredientIds.contains)) {
        continue;
      }

      if (cocktail.isIngredientOptional(ingredientId) ||
          cocktail.isIngredientDecoration(ingredientId)) {
        continue;
      }

      final ingredient = widget.ingredientsById[ingredientId];
      if (ingredient == null) {
        missing.add(ingredientId);
        continue;
      }
      if (ingredient.isOptional || ingredient.isDecoration) {
        continue;
      }
      missing.add(ingredientId);
    }

    return missing;
  }

  String _availabilityFilterLabel(
    BuildContext context,
    CocktailAvailabilityFilter filter,
  ) {
    return switch (filter) {
      CocktailAvailabilityFilter.all => context.tr('Все', 'All'),
      CocktailAvailabilityFilter.ready => context.tr('Можно сейчас', 'Ready'),
      CocktailAvailabilityFilter.missingOne => context.tr(
        'Не хватает 1',
        'Missing 1',
      ),
      CocktailAvailabilityFilter.missingTwo => context.tr(
        'Не хватает 2',
        'Missing 2',
      ),
    };
  }

  IconData _availabilityFilterIcon(CocktailAvailabilityFilter filter) {
    return switch (filter) {
      CocktailAvailabilityFilter.all => Icons.local_bar_rounded,
      CocktailAvailabilityFilter.ready => Icons.check_circle_rounded,
      CocktailAvailabilityFilter.missingOne => Icons.looks_one_rounded,
      CocktailAvailabilityFilter.missingTwo => Icons.looks_two_rounded,
    };
  }

  Future<void> _openCocktailFilters() async {
    var draftFavoritesOnly = _favoritesOnly;
    final draftTags = Set<String>.from(_selectedTags);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF161B2E),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedCount = (draftFavoritesOnly ? 1 : 0) + draftTags.length;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          context.tr('Фильтры коктейлей', 'Cocktail filters'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (selectedCount > 0)
                        TextButton(
                          onPressed: () => setSheetState(() {
                            draftFavoritesOnly = false;
                            draftTags.clear();
                          }),
                          child: Text(context.tr('Сбросить', 'Reset')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Выберите любимые стили — результат обновится после применения.',
                      'Choose your favorite styles — results update after applying.',
                    ),
                    style: const TextStyle(color: Color(0xFFAEB9DB)),
                  ),
                  const SizedBox(height: 16),
                  FilterChip(
                    checkmarkColor: Colors.white,
                    selectedColor: const Color(0x554F63CC),
                    labelStyle: const TextStyle(color: Colors.white),
                    selected: draftFavoritesOnly,
                    avatar: Icon(
                      draftFavoritesOnly
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      context.tr('Только избранные', 'Favorites only'),
                    ),
                    onSelected: (value) =>
                        setSheetState(() => draftFavoritesOnly = value),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('Стиль и настроение', 'Style and mood'),
                    style: const TextStyle(
                      color: Color(0xFFFFA6D5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCocktailTags
                        .map((tag) {
                          final selected = draftTags.contains(tag);
                          return FilterChip(
                            checkmarkColor: Colors.white,
                            selectedColor: const Color(0x554F63CC),
                            labelStyle: const TextStyle(color: Colors.white),
                            selected: selected,
                            label: Text(context.cocktailTagLabel(tag)),
                            onSelected: (value) => setSheetState(() {
                              if (value) {
                                draftTags.add(tag);
                              } else {
                                draftTags.remove(tag);
                              }
                            }),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: BarActionButton(
                      powerSavingMode: widget.powerSavingMode,
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: Icons.check_rounded,
                      label: selectedCount == 0
                          ? context.tr('Показать все', 'Show all')
                          : context.tr(
                              'Применить · $selectedCount',
                              'Apply · $selectedCount',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted || changed != true) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _favoritesOnly = draftFavoritesOnly;
      _selectedTags
        ..clear()
        ..addAll(draftTags);
    });
  }

  void _resetAllFilters() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _favoritesOnly = false;
      _selectedTags.clear();
      _availabilityFilter = CocktailAvailabilityFilter.all;
    });
  }

  Future<void> _openShoppingList() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF101426),
      builder: (_) => SmartShoppingSheet(
        ingredientsById: widget.ingredientsById,
        selectedIngredientIds: widget.selectedIngredientIds,
        shoppingIngredientIds: widget.shoppingIngredientIds,
        unlockCountsByIngredientId: widget.unlockCountsByIngredientId,
        favoriteUnlockCountsByIngredientId:
            widget.favoriteUnlockCountsByIngredientId,
        readOnly: widget.visitorMode,
        powerSavingMode: widget.powerSavingMode,
        onToggleIngredient: widget.onToggleShoppingIngredient,
        onClear: widget.onClearShoppingList,
        onMarkAsOwned: widget.onMarkShoppingIngredientAsOwned,
      ),
    );
  }

  Future<void> _pickServings() async {
    var draft = _servings;
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF111528),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          context.tr(
                            'Калькулятор порций',
                            'Serving calculator',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Закрыть', 'Close'),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Количество во всех открытых рецептах будет пересчитано.',
                      'Amounts in opened recipes will be recalculated.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB8C3E2)),
                  ),
                  const SizedBox(height: 18),
                  PortionSelector(
                    servings: draft,
                    powerSavingMode: widget.powerSavingMode,
                    onChanged: (value) => setSheetState(() => draft = value),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: <int>[1, 2, 4, 6, 10]
                        .map((value) {
                          return ChoiceChip(
                            selected: draft == value,
                            label: Text('$value'),
                            onSelected: (_) =>
                                setSheetState(() => draft = value),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: BarActionButton(
                      powerSavingMode: widget.powerSavingMode,
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.of(sheetContext).pop(draft),
                      label: context.tr('Применить', 'Apply'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() => _servings = result);
    }
  }

  Future<void> _surpriseMe(
    List<Cocktail> candidates,
    Map<String, List<String>> missingIngredientsByCocktailId,
  ) async {
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Нет коктейлей под текущие фильтры',
              'No cocktails match the current filters',
            ),
          ),
        ),
      );
      return;
    }

    // The menu has already applied availability, search, and tag filters.
    // Use that exact selection for both the first and subsequent recipes.
    final pool = candidates;
    final initialPool = pool.length > 1
        ? pool.where((item) => item.id != _lastSurpriseCocktailId).toList()
        : pool;
    final cocktail = initialPool[_random.nextInt(initialPool.length)];
    _lastSurpriseCocktailId = cocktail.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SurpriseCocktailPage(
          cocktails: pool,
          initialCocktailId: cocktail.id,
          missingIngredientsByCocktailId: missingIngredientsByCocktailId,
          ingredientsById: widget.ingredientsById,
          visitorMode: widget.visitorMode,
          measurementSystem: widget.measurementSystem,
          powerSavingMode: widget.powerSavingMode,
          onEditCocktailPressed: widget.onEditCocktailPressed,
          onToggleFavoritePressed: widget.onToggleFavoritePressed,
        ),
      ),
    );
  }

  Future<void> _openPartyMode(
    Map<String, Set<String>> missingIngredientIdsByCocktailId,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PartyModePage(
          cocktails: widget.cocktails,
          ingredientsById: widget.ingredientsById,
          missingIngredientIdsByCocktailId: missingIngredientIdsByCocktailId,
          measurementSystem: widget.measurementSystem,
          powerSavingMode: widget.powerSavingMode,
          readOnly: widget.visitorMode,
          onAddShoppingIngredients: widget.onAddShoppingIngredients,
        ),
      ),
    );
  }

  Future<void> _openCocktailDetailsPage({
    required Cocktail cocktail,
    required Map<String, List<String>> missingIngredientsByCocktailId,
  }) async {
    final missingIngredients =
        missingIngredientsByCocktailId[cocktail.id] ?? const <String>[];
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CocktailDetailsPage(
          cocktail: cocktail,
          missingIngredientNames: missingIngredients,
          ingredientsById: widget.ingredientsById,
          visitorMode: widget.visitorMode,
          measurementSystem: widget.measurementSystem,
          powerSavingMode: widget.powerSavingMode,
          onEditCocktailPressed: widget.onEditCocktailPressed,
          onToggleFavoritePressed: widget.onToggleFavoritePressed,
        ),
      ),
    );
  }
}

class CocktailGrid extends StatelessWidget {
  const CocktailGrid({
    required this.cocktails,
    required this.missingIngredientsByCocktailId,
    required this.horizontalPadding,
    required this.bottomPadding,
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onResetFilters,
    required this.hasSearchQuery,
    required this.hasActiveFilters,
    required this.powerSavingMode,
    required this.onOpenCocktailDetails,
    required this.onToggleFavoritePressed,
    this.selectedCocktailId,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Map<String, List<String>> missingIngredientsByCocktailId;
  final double horizontalPadding;
  final double bottomPadding;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onResetFilters;
  final bool hasSearchQuery;
  final bool hasActiveFilters;
  final bool powerSavingMode;
  final ValueChanged<Cocktail> onOpenCocktailDetails;
  final ValueChanged<String> onToggleFavoritePressed;
  final String? selectedCocktailId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720 ? 3 : 2;
        return NeonScrollbar(
          controller: scrollController,
          child: CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  6,
                  horizontalPadding,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: _CocktailSearchField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    onClear: onSearchClear,
                    hasValue: hasSearchQuery,
                  ),
                ),
              ),
              if (cocktails.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding + 8,
                    4,
                    horizontalPadding + 8,
                    bottomPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _NoCocktailMatchesMessage(
                      hasSearchQuery: hasSearchQuery,
                      hasActiveFilters: hasActiveFilters,
                      onResetFilters: onResetFilters,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2 / 3,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final cocktail = cocktails[index];
                      final isSelected = selectedCocktailId == cocktail.id;
                      final missingIngredients =
                          missingIngredientsByCocktailId[cocktail.id] ??
                          const <String>[];
                      return AnimatedGradientBorder(
                        enabled: !powerSavingMode,
                        borderRadius: BorderRadius.circular(20),
                        borderWidth: isSelected ? 2.0 : 1.5,
                        innerColor: const Color(0xFF191B2E),
                        colors: const <Color>[
                          Color(0xFFFF7EC8),
                          Color(0xFF7F8FFF),
                          Color(0xFFFF7EC8),
                        ],
                        glowEffect: !powerSavingMode,
                        glow: AnimatedGradientBorderGlow(
                          opacity: isSelected ? 0.58 : 0.35,
                          outerBlurSigma: 14,
                        ),
                        child: BarPressable(
                          powerSavingMode: powerSavingMode,
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onOpenCocktailDetails(cocktail),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: Hero(
                                        tag: cocktailHeroTag(cocktail.id),
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(18),
                                              ),
                                          child: BarNetworkImage(
                                            imageUrl: cocktail.image,
                                            loadingColor: const Color(
                                              0xFFF5A3D8,
                                            ),
                                            loadingBackgroundColor: const Color(
                                              0xFF242A45,
                                            ),
                                            errorWidget: const ColoredBox(
                                              color: Color(0xFF242A45),
                                              child: Icon(
                                                Icons.local_bar_rounded,
                                                color: Color(0xFF8FA3D8),
                                                size: 38,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: _PressableFavoriteButton(
                                        tooltip: cocktail.isFavorite
                                            ? context.tr(
                                                'Убрать из избранного',
                                                'Remove from favorites',
                                              )
                                            : context.tr(
                                                'В избранное',
                                                'Add to favorites',
                                              ),
                                        isFavorite: cocktail.isFavorite,
                                        size: 36,
                                        inactiveBackgroundColor: const Color(
                                          0x44353C62,
                                        ),
                                        activeBackgroundColor: const Color(
                                          0x664A3E2E,
                                        ),
                                        inactiveIconColor: const Color(
                                          0xFFC8D3F8,
                                        ),
                                        activeIconColor: const Color(
                                          0xFFFFD37B,
                                        ),
                                        onPressed: () =>
                                            onToggleFavoritePressed(
                                              cocktail.id,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  12,
                                  10,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      cocktail.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: <Widget>[
                                        CocktailGlassIcon(
                                          glassType: cocktail.glassType,
                                          size: 13,
                                          color: const Color(0xFFACB8E6),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            context.cocktailGlassTypeLabel(
                                              cocktail.glassType,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFFACB8E6),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: cocktail.tags
                                          .take(2)
                                          .map((tag) => _TagPill(tag: tag))
                                          .toList(growable: false),
                                    ),
                                    const SizedBox(height: 6),
                                    _AvailabilityHint(
                                      missingIngredientNames:
                                          missingIngredients,
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: cocktails.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TabletGridLayout extends StatelessWidget {
  const _TabletGridLayout({required this.grid, required this.detailsPanel});

  final Widget grid;
  final Widget detailsPanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final detailsWidth = (constraints.maxWidth * 0.42).clamp(360.0, 520.0);
        return Row(
          children: <Widget>[
            Expanded(child: grid),
            const SizedBox(width: 12),
            SizedBox(width: detailsWidth, child: detailsPanel),
          ],
        );
      },
    );
  }
}

class _TabletCocktailInstructionPanel extends StatelessWidget {
  const _TabletCocktailInstructionPanel({
    required this.cocktail,
    required this.missingIngredientNames,
    required this.ingredientsById,
    required this.visitorMode,
    required this.measurementSystem,
    required this.servings,
    required this.powerSavingMode,
    required this.bottomPadding,
    required this.scrollController,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
  });

  final Cocktail? cocktail;
  final List<String> missingIngredientNames;
  final Map<String, Ingredient> ingredientsById;
  final bool visitorMode;
  final MeasurementSystem measurementSystem;
  final int servings;
  final bool powerSavingMode;
  final double bottomPadding;
  final ScrollController scrollController;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final selectedCocktail = cocktail;
    if (selectedCocktail == null) {
      return _TabletEmptyInstructionPanel(
        bottomPadding: bottomPadding,
        powerSavingMode: powerSavingMode,
      );
    }

    return NeonScrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(0, 6, 0, bottomPadding),
        child: AnimatedGradientBorder(
          enabled: !powerSavingMode,
          borderRadius: BorderRadius.circular(24),
          borderWidth: 1.8,
          innerColor: const Color(0xFF1A1D32),
          colors: const <Color>[
            Color(0xFFFF6FAF),
            Color(0xFF7E8BFF),
            Color(0xFFFF6FAF),
          ],
          glowEffect: !powerSavingMode,
          glow: const AnimatedGradientBorderGlow(opacity: 0.56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: BarNetworkImage(
                    imageUrl: selectedCocktail.image,
                    loadingColor: const Color(0xFFE6A8E3),
                    loadingBackgroundColor: const Color(0xFF2C2F4F),
                    errorWidget: const ColoredBox(
                      color: Color(0xFF2C2F4F),
                      child: Icon(
                        Icons.local_drink_rounded,
                        color: Color(0xFFB4BEEF),
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            selectedCocktail.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PressableFavoriteButton(
                          tooltip: selectedCocktail.isFavorite
                              ? context.tr(
                                  'Убрать из избранного',
                                  'Remove from favorites',
                                )
                              : context.tr('В избранное', 'Add to favorites'),
                          isFavorite: selectedCocktail.isFavorite,
                          size: 36,
                          inactiveBackgroundColor: const Color(0x22323B60),
                          activeBackgroundColor: const Color(0x663F3628),
                          inactiveIconColor: const Color(0xFFB8C4EE),
                          activeIconColor: const Color(0xFFFFC88A),
                          onPressed: () =>
                              onToggleFavoritePressed(selectedCocktail.id),
                        ),
                      ],
                    ),
                    if (selectedCocktail.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          selectedCocktail.description,
                          style: const TextStyle(
                            color: Color(0xFFC5CCE5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        CocktailGlassIcon(
                          glassType: selectedCocktail.glassType,
                          size: 15,
                          color: const Color(0xFFAEB9E8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.cocktailGlassTypeLabel(
                              selectedCocktail.glassType,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFAEB9E8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedCocktail.tags
                          .map((tag) => _TagPill(tag: tag))
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 8),
                    _AvailabilityHint(
                      missingIngredientNames: missingIngredientNames,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('Состав', 'Ingredients'),
                      style: const TextStyle(
                        color: Color(0xFFFF93CC),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...selectedCocktail.ingredients.map((ingredientId) {
                      final ingredient = ingredientsById[ingredientId];
                      final amount = selectedCocktail.ingredientAmountLabel(
                        ingredientId,
                        measurementSystem: measurementSystem,
                        unitLabelResolver: context.ingredientUnitLabel,
                        servings: servings,
                      );
                      final isOptional = selectedCocktail.isIngredientOptional(
                        ingredientId,
                      );
                      final isDecoration = selectedCocktail
                          .isIngredientDecoration(ingredientId);
                      final substitutions =
                          selectedCocktail
                              .ingredientSubstitutions[ingredientId] ??
                          const <String>[];
                      final substitutionsText = substitutions
                          .map((id) => ingredientsById[id]?.name ?? id)
                          .join(', ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.blur_circular_rounded,
                                  color: Color(0xFF7FA9FF),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ingredient?.name ?? ingredientId,
                                    style: const TextStyle(
                                      color: Color(0xFFE2E7F9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (amount.isNotEmpty)
                                  Text(
                                    amount,
                                    style: const TextStyle(
                                      color: Color(0xFFAEC1EE),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            if (isOptional || isDecoration)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 24,
                                  top: 2,
                                ),
                                child: Text(
                                  <String>[
                                    if (isOptional)
                                      context.tr('Опционально', 'Optional'),
                                    if (isDecoration)
                                      context.tr('Украшение', 'Decoration'),
                                  ].join(' • '),
                                  style: const TextStyle(
                                    color: Color(0xFFAFC3F2),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (substitutions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 24,
                                  top: 2,
                                ),
                                child: Text(
                                  context.tr(
                                    'Замена: $substitutionsText',
                                    'Substitute: $substitutionsText',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFAFC3F2),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Text(
                          context.tr('Приготовление', 'Preparation'),
                          style: const TextStyle(
                            color: Color(0xFFFF93CC),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (!visitorMode)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFB9DD),
                            ),
                            onPressed: () =>
                                onEditCocktailPressed(selectedCocktail),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: Text(context.tr('Редактировать', 'Edit')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...List<Widget>.generate(
                      selectedCocktail.preparationSteps.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${index + 1}. ${selectedCocktail.preparationSteps[index]}',
                          style: const TextStyle(
                            color: Color(0xFFE8ECFF),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                      growable: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletEmptyInstructionPanel extends StatelessWidget {
  const _TabletEmptyInstructionPanel({
    required this.bottomPadding,
    required this.powerSavingMode,
  });

  final double bottomPadding;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 6, 0, bottomPadding),
      child: AnimatedGradientBorder(
        enabled: !powerSavingMode,
        borderRadius: BorderRadius.circular(24),
        borderWidth: 1.2,
        innerColor: const Color(0xFF1A1D32),
        colors: const <Color>[
          Color(0x667E8BFF),
          Color(0x66FF6FAF),
          Color(0x667E8BFF),
        ],
        showBorderWhenDisabled: true,
        disabledBorderColor: const Color(0x553E4A78),
        disabledBorderWidth: 1.2,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.tr(
                'Выбери коктейль в сетке слева, чтобы открыть инструкцию приготовления.',
                'Select a cocktail in the left grid to open preparation instructions.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC8D3EF),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CocktailList extends StatelessWidget {
  const CocktailList({
    required this.cocktails,
    required this.missingIngredientsByCocktailId,
    required this.ingredientsById,
    required this.visitorMode,
    required this.measurementSystem,
    required this.servings,
    required this.powerSavingMode,
    required this.horizontalPadding,
    required this.bottomPadding,
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onResetFilters,
    required this.hasSearchQuery,
    required this.hasActiveFilters,
    required this.expandedId,
    required this.onToggleExpanded,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Map<String, List<String>> missingIngredientsByCocktailId;
  final Map<String, Ingredient> ingredientsById;
  final bool visitorMode;
  final MeasurementSystem measurementSystem;
  final int servings;
  final bool powerSavingMode;
  final double horizontalPadding;
  final double bottomPadding;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onResetFilters;
  final bool hasSearchQuery;
  final bool hasActiveFilters;
  final String? expandedId;
  final ValueChanged<String> onToggleExpanded;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return NeonScrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          6,
          horizontalPadding,
          bottomPadding,
        ),
        itemCount: cocktails.isEmpty ? 2 : cocktails.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CocktailSearchField(
                controller: searchController,
                onChanged: onSearchChanged,
                onClear: onSearchClear,
                hasValue: hasSearchQuery,
              ),
            );
          }

          if (cocktails.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: _NoCocktailMatchesMessage(
                hasSearchQuery: hasSearchQuery,
                hasActiveFilters: hasActiveFilters,
                onResetFilters: onResetFilters,
              ),
            );
          }

          final cocktail = cocktails[index - 1];
          final isExpanded = cocktail.id == expandedId;
          final missingIngredients =
              missingIngredientsByCocktailId[cocktail.id] ?? const <String>[];

          return Padding(
            key: ValueKey<String>('cocktail_list_item_${cocktail.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedGradientBorder(
              enabled: !powerSavingMode && isExpanded,
              showBorderWhenDisabled: true,
              disabledBorderColor: const Color(0xFF444B72),
              disabledBorderWidth: 1.1,
              borderRadius: BorderRadius.circular(24),
              borderWidth: 1.8,
              innerColor: const Color(0xFF1A1D32),
              colors: const <Color>[
                Color(0xFFFF6FAF),
                Color(0xFF7E8BFF),
                Color(0xFFFF6FAF),
              ],
              glowEffect: !powerSavingMode && isExpanded,
              glow: const AnimatedGradientBorderGlow(opacity: 0.58),
              child: BarPressable(
                powerSavingMode: powerSavingMode,
                borderRadius: BorderRadius.circular(24),
                onTap: () => onToggleExpanded(cocktail.id),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                      child: Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 76,
                              height: 76,
                              child: BarNetworkImage(
                                imageUrl: cocktail.image,
                                loadingColor: const Color(0xFFE6A8E3),
                                loadingBackgroundColor: const Color(0xFF2C2F4F),
                                errorWidget: const ColoredBox(
                                  color: Color(0xFF2C2F4F),
                                  child: Icon(
                                    Icons.local_drink_rounded,
                                    color: Color(0xFFB4BEEF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  cocktail.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cocktail.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFC5CCE5),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    CocktailGlassIcon(
                                      glassType: cocktail.glassType,
                                      size: 14,
                                      color: const Color(0xFFAEB9E8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        context.cocktailGlassTypeLabel(
                                          cocktail.glassType,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFAEB9E8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: cocktail.tags
                                      .map((tag) => _TagPill(tag: tag))
                                      .toList(growable: false),
                                ),
                                const SizedBox(height: 6),
                                _AvailabilityHint(
                                  missingIngredientNames: missingIngredients,
                                ),
                              ],
                            ),
                          ),
                          _PressableFavoriteButton(
                            tooltip: cocktail.isFavorite
                                ? context.tr(
                                    'Убрать из избранного',
                                    'Remove from favorites',
                                  )
                                : context.tr('В избранное', 'Add to favorites'),
                            isFavorite: cocktail.isFavorite,
                            size: 34,
                            inactiveBackgroundColor: const Color(0x22323B60),
                            activeBackgroundColor: const Color(0x663F3628),
                            inactiveIconColor: const Color(0xFFB8C4EE),
                            activeIconColor: const Color(0xFFFFC88A),
                            onPressed: () =>
                                onToggleFavoritePressed(cocktail.id),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFFFF7EC8),
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                    _AnimatedExpandSection(
                      expanded: isExpanded,
                      childBuilder: (context) => Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Divider(color: Color(0x33FF7EC8)),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                CocktailGlassIcon(
                                  glassType: cocktail.glassType,
                                  size: 17,
                                  color: const Color(0xFFFFB9DD),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr(
                                    'Бокал: ${context.cocktailGlassTypeLabel(cocktail.glassType)}',
                                    'Glass: ${context.cocktailGlassTypeLabel(cocktail.glassType)}',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFFFB9DD),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('Состав', 'Ingredients'),
                              style: const TextStyle(
                                color: Color(0xFFFF93CC),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...cocktail.ingredients.map((ingredientId) {
                              final ingredient = ingredientsById[ingredientId];
                              final amount = cocktail.ingredientAmountLabel(
                                ingredientId,
                                measurementSystem: measurementSystem,
                                unitLabelResolver: context.ingredientUnitLabel,
                                servings: servings,
                              );
                              final isOptional = cocktail.isIngredientOptional(
                                ingredientId,
                              );
                              final isDecoration = cocktail
                                  .isIngredientDecoration(ingredientId);
                              final substitutions =
                                  cocktail
                                      .ingredientSubstitutions[ingredientId] ??
                                  const <String>[];
                              final substitutionsText = substitutions
                                  .map((id) => ingredientsById[id]?.name ?? id)
                                  .join(', ');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons.blur_circular_rounded,
                                          color: Color(0xFF7FA9FF),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ingredient?.name ?? ingredientId,
                                            style: const TextStyle(
                                              color: Color(0xFFE2E7F9),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (amount.isNotEmpty) ...<Widget>[
                                          const SizedBox(width: 8),
                                          Text(
                                            amount,
                                            style: const TextStyle(
                                              color: Color(0xFFAEC1EE),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (isOptional || isDecoration)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 24,
                                          top: 2,
                                        ),
                                        child: Text(
                                          [
                                            if (isOptional)
                                              context.tr(
                                                'Опционально',
                                                'Optional',
                                              ),
                                            if (isDecoration)
                                              context.tr(
                                                'Украшение',
                                                'Decoration',
                                              ),
                                          ].join(' • '),
                                          style: const TextStyle(
                                            color: Color(0xFFAFC3F2),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (substitutions.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 24,
                                          top: 2,
                                        ),
                                        child: Text(
                                          context.tr(
                                            'Замена: $substitutionsText',
                                            'Substitute: $substitutionsText',
                                          ),
                                          style: const TextStyle(
                                            color: Color(0xFFAFC3F2),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Text(
                                  context.tr('Приготовление', 'Preparation'),
                                  style: const TextStyle(
                                    color: Color(0xFFFF93CC),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                if (!visitorMode)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFFB9DD),
                                    ),
                                    onPressed: () =>
                                        onEditCocktailPressed(cocktail),
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      context.tr('Редактировать', 'Edit'),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...List<Widget>.generate(
                              cocktail.preparationSteps.length,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${index + 1}. ${cocktail.preparationSteps[index]}',
                                  style: const TextStyle(
                                    color: Color(0xFFE8ECFF),
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              growable: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedExpandSection extends StatefulWidget {
  const _AnimatedExpandSection({
    required this.expanded,
    required this.childBuilder,
  });

  final bool expanded;
  final WidgetBuilder childBuilder;

  @override
  State<_AnimatedExpandSection> createState() => _AnimatedExpandSectionState();
}

class _AnimatedExpandSectionState extends State<_AnimatedExpandSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sizeFactor;
  late final Animation<double> _opacity;
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    _showChild = widget.expanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.expanded ? 1 : 0,
    );
    _sizeFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.14, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.85, curve: Curves.easeIn),
    );
    _controller.addStatusListener(_handleStatusChange);
  }

  @override
  void didUpdateWidget(covariant _AnimatedExpandSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) {
      return;
    }
    if (widget.expanded) {
      if (!_showChild) {
        setState(() => _showChild = true);
      }
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (!mounted) {
      return;
    }
    if (status == AnimationStatus.dismissed && !widget.expanded && _showChild) {
      setState(() => _showChild = false);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showChild && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        child: _showChild
            ? widget.childBuilder(context)
            : const SizedBox.shrink(),
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: _sizeFactor.value,
            child: FadeTransition(opacity: _opacity, child: child),
          );
        },
      ),
    );
  }
}

class _AvailabilityHint extends StatelessWidget {
  const _AvailabilityHint({
    required this.missingIngredientNames,
    this.maxLines = 1,
  });

  final List<String> missingIngredientNames;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (missingIngredientNames.isEmpty) {
      return Text(
        context.tr('Можно приготовить сейчас', 'Can make right now'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF8FFFD4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final preview = missingIngredientNames.take(3).join(', ');
    final hiddenCount = missingIngredientNames.length - 3;
    final text = context.isEnglish
        ? hiddenCount > 0
              ? 'Missing: $preview and $hiddenCount more'
              : 'Missing: $preview'
        : hiddenCount > 0
        ? 'Не хватает: $preview и ещё $hiddenCount'
        : 'Не хватает: $preview';

    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFFFC0D9),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PressableFavoriteButton extends StatefulWidget {
  const _PressableFavoriteButton({
    required this.tooltip,
    required this.isFavorite,
    required this.onPressed,
    required this.size,
    required this.inactiveBackgroundColor,
    required this.activeBackgroundColor,
    required this.inactiveIconColor,
    required this.activeIconColor,
  });

  final String tooltip;
  final bool isFavorite;
  final VoidCallback onPressed;
  final double size;
  final Color inactiveBackgroundColor;
  final Color activeBackgroundColor;
  final Color inactiveIconColor;
  final Color activeIconColor;

  @override
  State<_PressableFavoriteButton> createState() =>
      _PressableFavoriteButtonState();
}

class _PressableFavoriteButtonState extends State<_PressableFavoriteButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            scale: _pressed ? 0.9 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isFavorite
                    ? widget.activeBackgroundColor
                    : widget.inactiveBackgroundColor,
                boxShadow: widget.isFavorite
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x55FFCC7C),
                          blurRadius: 12,
                          spreadRadius: 0.8,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  widget.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  key: ValueKey<bool>(widget.isFavorite),
                  color: widget.isFavorite
                      ? widget.activeIconColor
                      : widget.inactiveIconColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuDashboardCard extends StatelessWidget {
  const _MenuDashboardCard({
    required this.shoppingCount,
    required this.servings,
    required this.powerSavingMode,
    required this.onSurprise,
    required this.onParty,
    required this.onShopping,
    required this.onServings,
  });

  final int shoppingCount;
  final int servings;
  final bool powerSavingMode;
  final VoidCallback onSurprise;
  final VoidCallback onParty;
  final VoidCallback onShopping;
  final VoidCallback onServings;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _MenuQuickAction(
        powerSavingMode: powerSavingMode,
        icon: Icons.casino_rounded,
        label: context.tr('Удиви меня', 'Surprise me'),
        onTap: onSurprise,
      ),
      _MenuQuickAction(
        powerSavingMode: powerSavingMode,
        icon: Icons.celebration_rounded,
        label: context.tr('Вечеринка', 'Party'),
        onTap: onParty,
      ),
      _MenuQuickAction(
        powerSavingMode: powerSavingMode,
        icon: Icons.shopping_basket_rounded,
        label: context.tr('Покупки', 'Shopping'),
        tooltip: context.tr('Список покупок', 'Shopping list'),
        badge: shoppingCount == 0 ? null : '$shoppingCount',
        onTap: onShopping,
      ),
      _MenuQuickAction(
        powerSavingMode: powerSavingMode,
        icon: Icons.people_alt_rounded,
        label: context.tr('$servings порц.', '$servings serv.'),
        onTap: onServings,
      ),
    ];

    return Row(
      children: actions
          .map((action) => Expanded(child: action))
          .toList(growable: false),
    );
  }
}

class _MenuQuickAction extends StatelessWidget {
  const _MenuQuickAction({
    required this.powerSavingMode,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.tooltip,
  });

  final bool powerSavingMode;
  final IconData icon;
  final String label;
  final String? badge;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? label,
      child: Semantics(
        button: true,
        label: tooltip ?? label,
        child: BarPressable(
          powerSavingMode: powerSavingMode,
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Icon(icon, color: const Color(0xFFFFA5D4), size: 20),
                      if (badge != null)
                        Positioned(
                          right: -11,
                          top: -8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5BAA),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD4DCF2),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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
}

class ViewModeSwitch extends StatelessWidget {
  const ViewModeSwitch({
    required this.mode,
    required this.onModeChanged,
    this.powerSavingMode = false,
    super.key,
  });

  final MenuViewMode mode;
  final ValueChanged<MenuViewMode> onModeChanged;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBorder(
      enabled: !powerSavingMode,
      borderRadius: BorderRadius.circular(14),
      borderWidth: 1.2,
      innerColor: const Color(0xFF1B1E32),
      colors: const <Color>[
        Color(0xFFFF77BC),
        Color(0xFF7C98FF),
        Color(0xFFFF77BC),
      ],
      glowEffect: !powerSavingMode,
      glow: const AnimatedGradientBorderGlow(opacity: 0.38),
      child: Row(
        children: <Widget>[
          _SwitchButton(
            powerSavingMode: powerSavingMode,
            active: mode == MenuViewMode.list,
            icon: Icons.view_agenda_rounded,
            onTap: () => onModeChanged(MenuViewMode.list),
          ),
          _SwitchButton(
            powerSavingMode: powerSavingMode,
            active: mode == MenuViewMode.grid,
            icon: Icons.grid_view_rounded,
            onTap: () => onModeChanged(MenuViewMode.grid),
          ),
        ],
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.powerSavingMode,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final bool powerSavingMode;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BarPressable(
      powerSavingMode: powerSavingMode,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration(
          context,
          AppMotion.standard,
          powerSavingMode: powerSavingMode,
        ),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: active ? const Color(0x33FF7EC8) : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 22,
          color: active ? const Color(0xFFFF8FCF) : const Color(0xFFB3BDD9),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x332B395E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x507E8DCA)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          context.cocktailTagLabel(tag),
          style: const TextStyle(
            color: Color(0xFFC9D5F6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NoCocktailMatchesMessage extends StatelessWidget {
  const _NoCocktailMatchesMessage({
    required this.hasSearchQuery,
    required this.hasActiveFilters,
    required this.onResetFilters,
  });

  final bool hasSearchQuery;
  final bool hasActiveFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final message = hasSearchQuery
        ? context.tr(
            'По запросу ничего не найдено',
            'No cocktails match your search',
          )
        : hasActiveFilters
        ? context.tr(
            'По выбранным фильтрам коктейли не найдены',
            'No cocktails found for selected filters',
          )
        : context.tr('Коктейли не найдены', 'No cocktails found');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x221A2142),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x445A689C)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF9AA8D0),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFC3CCE8), fontSize: 15),
            ),
            if (hasSearchQuery || hasActiveFilters) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(context.tr('Сбросить фильтры', 'Reset filters')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CocktailSearchField extends StatelessWidget {
  const _CocktailSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasValue,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Color(0xFFE8ECFF), fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: context.tr('Поиск коктейлей', 'Search cocktails'),
        hintStyle: const TextStyle(color: Color(0x99C2CCE9), fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFFB9C4E8),
          size: 20,
        ),
        suffixIcon: hasValue
            ? IconButton(
                tooltip: context.tr('Очистить', 'Clear'),
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFB9C4E8),
                  size: 19,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: const Color(0x33131A35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x557389C3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x557389C3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xAA8AA3FF), width: 1.2),
        ),
      ),
    );
  }
}

class NoCocktailsView extends StatelessWidget {
  const NoCocktailsView({
    required this.bottomInsetCompensation,
    required this.horizontalPadding,
    this.powerSavingMode = false,
    super.key,
  });

  final double bottomInsetCompensation;
  final double horizontalPadding;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsetCompensation),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding + 8),
          child: AnimatedGradientBorder(
            enabled: !powerSavingMode,
            borderRadius: BorderRadius.circular(24),
            borderWidth: 1.4,
            innerColor: const Color(0xFF191C2F),
            colors: const <Color>[
              Color(0xFFFD7DB8),
              Color(0xFF748BFF),
              Color(0xFFFD7DB8),
            ],
            glowEffect: !powerSavingMode,
            glow: const AnimatedGradientBorderGlow(opacity: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFFFA8D8),
                    size: 38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Пока не хватает ингредиентов',
                      'Not enough ingredients yet',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Добавь позиции в «Ингредиентах», и здесь появятся доступные коктейли.',
                      'Add items in "Ingredients", and available cocktails will appear here.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFCAD2EB),
                      fontSize: 14,
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
}
