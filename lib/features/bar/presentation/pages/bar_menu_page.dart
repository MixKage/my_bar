import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/widgets/bar_network_image.dart';
import '../../../../core/widgets/neon_scrollbar.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';
import 'cocktail_details_page.dart';
import '../widgets/cocktail_glass_icon.dart';
import '../widgets/neon_background.dart';
import '../widgets/neon_bottom_navigation.dart';

enum MenuViewMode { list, grid }

class BarMenuPage extends StatefulWidget {
  const BarMenuPage({
    required this.cocktails,
    required this.selectedIngredientIds,
    required this.ingredientsById,
    required this.visitorMode,
    required this.onManagePressed,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Set<String> selectedIngredientIds;
  final Map<String, Ingredient> ingredientsById;
  final bool visitorMode;
  final VoidCallback onManagePressed;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  State<BarMenuPage> createState() => _BarMenuPageState();
}

class _BarMenuPageState extends State<BarMenuPage> {
  final ScrollController _scrollController = ScrollController();
  MenuViewMode _viewMode = MenuViewMode.list;
  String? _expandedCocktailId;
  final Set<String> _selectedTags = <String>{};
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomOverlayPadding =
        kNeonBottomNavigationHeight +
        kNeonBottomNavigationBottomMargin +
        bottomInset;
    final bottomContentPadding = bottomOverlayPadding + 24;

    final missingIngredientsByCocktailId = _buildMissingIngredientsMap(
      widget.cocktails,
    );
    final hasSelectedIngredients = widget.selectedIngredientIds.isNotEmpty;
    final sortedCocktails = _sortCocktailsByAvailability(
      widget.cocktails,
      missingIngredientsByCocktailId,
    );
    final filteredCocktails = _applyFilters(sortedCocktails);
    final availableCocktailCount = filteredCocktails.where((cocktail) {
      final missingIngredients = missingIngredientsByCocktailId[cocktail.id];
      return missingIngredients == null || missingIngredients.isEmpty;
    }).length;
    final totalCocktailCount = filteredCocktails.length;
    final expandedId = _resolveExpandedId(filteredCocktails);
    final activeFilters = <String>[
      if (_favoritesOnly) context.tr('Избранные', 'Favorites'),
      ..._selectedTags.map(context.cocktailTagLabel),
    ];

    return NeonBackground(
      topGlow: const Color(0xFFFF5BB0),
      bottomGlow: const Color(0xFF6A70FF),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 6),
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
                      Text(
                        context.tr(
                          'Доступно $availableCocktailCount из $totalCocktailCount',
                          'Available $availableCocktailCount of $totalCocktailCount',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFCCD3E8),
                          fontSize: 14,
                        ),
                      ),
                      if (activeFilters.isNotEmpty)
                        Text(
                          context.tr(
                            'Фильтр: ${activeFilters.join(', ')}',
                            'Filter: ${activeFilters.join(', ')}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE8B9D7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                ViewModeSwitch(
                  mode: _viewMode,
                  onModeChanged: (mode) => setState(() => _viewMode = mode),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.tr('Управление баром', 'Bar management'),
                  onPressed: widget.onManagePressed,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _favoritesOnly,
                    avatar: Icon(
                      _favoritesOnly
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: _favoritesOnly
                          ? const Color(0xFFFFD8EC)
                          : const Color(0xFFC2CDEB),
                    ),
                    label: Text(context.tr('Избранные', 'Favorites')),
                    selectedColor: const Color(0x44FF6FAF),
                    checkmarkColor: const Color(0xFFFFE5F3),
                    side: BorderSide(
                      color: _favoritesOnly
                          ? const Color(0xFFEF73BD)
                          : const Color(0x3AD8DDF6),
                    ),
                    backgroundColor: const Color(0x221A2142),
                    labelStyle: TextStyle(
                      color: _favoritesOnly
                          ? const Color(0xFFFFD8EC)
                          : const Color(0xFFC2CDEB),
                      fontSize: 12,
                    ),
                    onSelected: (value) {
                      setState(() {
                        _favoritesOnly = value;
                      });
                    },
                  ),
                ),
                ...kCocktailTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(context.cocktailTagLabel(tag)),
                      selectedColor: const Color(0x44FF6FAF),
                      checkmarkColor: const Color(0xFFFFE5F3),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFFEF73BD)
                            : const Color(0x3AD8DDF6),
                      ),
                      backgroundColor: const Color(0x221A2142),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFFFFD8EC)
                            : const Color(0xFFC2CDEB),
                        fontSize: 12,
                      ),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: widget.cocktails.isEmpty || !hasSelectedIngredients
                ? NoCocktailsView(bottomInsetCompensation: bottomOverlayPadding)
                : filteredCocktails.isEmpty
                ? _NoTagMatchesView()
                : _viewMode == MenuViewMode.grid
                ? CocktailGrid(
                    cocktails: filteredCocktails,
                    missingIngredientsByCocktailId:
                        missingIngredientsByCocktailId,
                    ingredientsById: widget.ingredientsById,
                    visitorMode: widget.visitorMode,
                    bottomPadding: bottomContentPadding,
                    scrollController: _scrollController,
                    onEditCocktailPressed: widget.onEditCocktailPressed,
                    onToggleFavoritePressed: widget.onToggleFavoritePressed,
                  )
                : CocktailList(
                    cocktails: filteredCocktails,
                    missingIngredientsByCocktailId:
                        missingIngredientsByCocktailId,
                    ingredientsById: widget.ingredientsById,
                    visitorMode: widget.visitorMode,
                    bottomPadding: bottomContentPadding,
                    scrollController: _scrollController,
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

  List<Cocktail> _applyFilters(List<Cocktail> source) {
    var filtered = source;

    if (_favoritesOnly) {
      filtered = filtered
          .where((cocktail) => cocktail.isFavorite)
          .toList(growable: false);
    }

    if (_selectedTags.isEmpty) {
      return filtered;
    }

    return filtered
        .where((cocktail) => cocktail.tags.any(_selectedTags.contains))
        .toList(growable: false);
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

  Map<String, List<String>> _buildMissingIngredientsMap(
    List<Cocktail> cocktails,
  ) {
    return <String, List<String>>{
      for (final cocktail in cocktails)
        cocktail.id: _missingIngredientNamesForCocktail(cocktail),
    };
  }

  List<String> _missingIngredientNamesForCocktail(Cocktail cocktail) {
    final missing = <String>[];

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
      missing.add(ingredient.name);
    }

    return missing;
  }
}

class CocktailGrid extends StatelessWidget {
  const CocktailGrid({
    required this.cocktails,
    required this.missingIngredientsByCocktailId,
    required this.ingredientsById,
    required this.visitorMode,
    required this.bottomPadding,
    required this.scrollController,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Map<String, List<String>> missingIngredientsByCocktailId;
  final Map<String, Ingredient> ingredientsById;
  final bool visitorMode;
  final double bottomPadding;
  final ScrollController scrollController;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720 ? 3 : 2;
        return NeonScrollbar(
          controller: scrollController,
          child: GridView.builder(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2 / 3,
            ),
            itemCount: cocktails.length,
            itemBuilder: (context, index) {
              final cocktail = cocktails[index];
              final missingIngredients =
                  missingIngredientsByCocktailId[cocktail.id] ??
                  const <String>[];
              return AnimatedGradientBorder(
                borderRadius: BorderRadius.circular(20),
                borderWidth: 1.5,
                innerColor: const Color(0xFF191B2E),
                colors: const <Color>[
                  Color(0xFFFF7EC8),
                  Color(0xFF7F8FFF),
                  Color(0xFFFF7EC8),
                ],
                glowEffect: true,
                glow: const AnimatedGradientBorderGlow(
                  opacity: 0.35,
                  outerBlurSigma: 14,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => CocktailDetailsPage(
                          cocktail: cocktail,
                          missingIngredientNames: missingIngredients,
                          ingredientsById: ingredientsById,
                          visitorMode: visitorMode,
                          onEditCocktailPressed: onEditCocktailPressed,
                          onToggleFavoritePressed: onToggleFavoritePressed,
                        ),
                      ),
                    );
                  },
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
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  child: BarNetworkImage(
                                    imageUrl: cocktail.image,
                                    loadingColor: const Color(0xFFF5A3D8),
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
                                activeBackgroundColor: const Color(0x664A3E2E),
                                inactiveIconColor: const Color(0xFFC8D3F8),
                                activeIconColor: const Color(0xFFFFD37B),
                                onPressed: () =>
                                    onToggleFavoritePressed(cocktail.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
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
                              missingIngredientNames: missingIngredients,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class CocktailList extends StatelessWidget {
  const CocktailList({
    required this.cocktails,
    required this.missingIngredientsByCocktailId,
    required this.ingredientsById,
    required this.visitorMode,
    required this.bottomPadding,
    required this.scrollController,
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
  final double bottomPadding;
  final ScrollController scrollController;
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
        padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding),
        itemCount: cocktails.length,
        itemBuilder: (context, index) {
          final cocktail = cocktails[index];
          final isExpanded = cocktail.id == expandedId;
          final missingIngredients =
              missingIngredientsByCocktailId[cocktail.id] ?? const <String>[];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedGradientBorder(
              enabled: isExpanded,
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
              glowEffect: isExpanded,
              glow: const AnimatedGradientBorderGlow(opacity: 0.58),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onToggleExpanded(cocktail.id),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
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
                                  loadingBackgroundColor: const Color(
                                    0xFF2C2F4F,
                                  ),
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
                                  : context.tr(
                                      'В избранное',
                                      'Add to favorites',
                                    ),
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
                      if (isExpanded)
                        Padding(
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
                                final ingredient =
                                    ingredientsById[ingredientId];
                                final amount = cocktail.ingredientAmountLabel(
                                  ingredientId,
                                );
                                final isOptional = cocktail
                                    .isIngredientOptional(ingredientId);
                                final isDecoration = cocktail
                                    .isIngredientDecoration(ingredientId);
                                final substitutions =
                                    cocktail
                                        .ingredientSubstitutions[ingredientId] ??
                                    const <String>[];
                                final substitutionsText = substitutions
                                    .map(
                                      (id) => ingredientsById[id]?.name ?? id,
                                    )
                                    .join(', ');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          const Icon(
                                            Icons.blur_circular_rounded,
                                            color: Color(0xFF7FA9FF),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            ingredient?.name ?? ingredientId,
                                            style: const TextStyle(
                                              color: Color(0xFFE2E7F9),
                                              fontSize: 14,
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
                                        foregroundColor: const Color(
                                          0xFFFFB9DD,
                                        ),
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
                    ],
                  ),
                ),
              ),
            ),
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

class ViewModeSwitch extends StatelessWidget {
  const ViewModeSwitch({
    required this.mode,
    required this.onModeChanged,
    super.key,
  });

  final MenuViewMode mode;
  final ValueChanged<MenuViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBorder(
      borderRadius: BorderRadius.circular(14),
      borderWidth: 1.2,
      innerColor: const Color(0xFF1B1E32),
      colors: const <Color>[
        Color(0xFFFF77BC),
        Color(0xFF7C98FF),
        Color(0xFFFF77BC),
      ],
      glowEffect: true,
      glow: const AnimatedGradientBorderGlow(opacity: 0.38),
      child: Row(
        children: <Widget>[
          _SwitchButton(
            active: mode == MenuViewMode.list,
            icon: Icons.view_agenda_rounded,
            onTap: () => onModeChanged(MenuViewMode.list),
          ),
          _SwitchButton(
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
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
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

class _NoTagMatchesView extends StatelessWidget {
  const _NoTagMatchesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          context.tr(
            'По выбранным фильтрам коктейли не найдены',
            'No cocktails found for selected filters',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFC3CCE8), fontSize: 16),
        ),
      ),
    );
  }
}

class NoCocktailsView extends StatelessWidget {
  const NoCocktailsView({required this.bottomInsetCompensation, super.key});

  final double bottomInsetCompensation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsetCompensation),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedGradientBorder(
            borderRadius: BorderRadius.circular(24),
            borderWidth: 1.4,
            innerColor: const Color(0xFF191C2F),
            colors: const <Color>[
              Color(0xFFFD7DB8),
              Color(0xFF748BFF),
              Color(0xFFFD7DB8),
            ],
            glowEffect: true,
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
                      'Добавь позиции в "Ингридиентах", и здесь появятся доступные коктейли.',
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
