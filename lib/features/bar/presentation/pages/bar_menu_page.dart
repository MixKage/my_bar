import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/bar_network_image.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/cocktail_tags.dart';
import '../../domain/models/ingredient.dart';
import '../widgets/neon_background.dart';

enum MenuViewMode { list, grid }

class BarMenuPage extends StatefulWidget {
  const BarMenuPage({
    required this.availableCocktails,
    required this.cocktailCount,
    required this.ingredientsById,
    required this.onManagePressed,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> availableCocktails;
  final int cocktailCount;
  final Map<String, Ingredient> ingredientsById;
  final VoidCallback onManagePressed;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  State<BarMenuPage> createState() => _BarMenuPageState();
}

class _BarMenuPageState extends State<BarMenuPage> {
  MenuViewMode _viewMode = MenuViewMode.list;
  String? _expandedCocktailId;
  final Set<String> _selectedTags = <String>{};

  @override
  Widget build(BuildContext context) {
    final filteredCocktails = _filterByTags(widget.availableCocktails);
    final expandedId = _resolveExpandedId(filteredCocktails);

    return NeonBackground(
      topGlow: const Color(0xFFFF5BB0),
      bottomGlow: const Color(0xFF6A70FF),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Барная карта',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Color(0x88FF55B0),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Доступно ${widget.availableCocktails.length} из ${widget.cocktailCount}',
                          style: const TextStyle(
                            color: Color(0xFFCCD3E8),
                            fontSize: 14,
                          ),
                        ),
                        if (_selectedTags.isNotEmpty)
                          Text(
                            'Фильтр: ${_selectedTags.join(', ')}',
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
                    tooltip: 'Управление баром',
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
                children: kCocktailTags
                    .map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: selected,
                          label: Text(tag),
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
                    })
                    .toList(growable: false),
              ),
            ),
            Expanded(
              child: widget.availableCocktails.isEmpty
                  ? const NoCocktailsView()
                  : filteredCocktails.isEmpty
                  ? const _NoTagMatchesView()
                  : _viewMode == MenuViewMode.grid
                  ? CocktailGrid(
                      cocktails: filteredCocktails,
                      onToggleFavoritePressed: widget.onToggleFavoritePressed,
                    )
                  : CocktailList(
                      cocktails: filteredCocktails,
                      ingredientsById: widget.ingredientsById,
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
      ),
    );
  }

  List<Cocktail> _filterByTags(List<Cocktail> source) {
    if (_selectedTags.isEmpty) {
      return source;
    }

    return source
        .where((cocktail) => cocktail.tags.any(_selectedTags.contains))
        .toList(growable: false);
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
}

class CocktailGrid extends StatelessWidget {
  const CocktailGrid({
    required this.cocktails,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> cocktails;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2 / 3,
          ),
          itemCount: cocktails.length,
          itemBuilder: (context, index) {
            final cocktail = cocktails[index];
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: BarNetworkImage(
                              imageUrl: cocktail.image,
                              loadingColor: const Color(0xFFF5A3D8),
                              loadingBackgroundColor: const Color(0xFF242A45),
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
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton.filledTonal(
                            tooltip: cocktail.isFavorite
                                ? 'Убрать из избранного'
                                : 'В избранное',
                            onPressed: () =>
                                onToggleFavoritePressed(cocktail.id),
                            icon: Icon(
                              cocktail.isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                            ),
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
                            const Icon(
                              Icons.wine_bar_rounded,
                              size: 13,
                              color: Color(0xFFACB8E6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cocktail.glassType,
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
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CocktailList extends StatelessWidget {
  const CocktailList({
    required this.cocktails,
    required this.ingredientsById,
    required this.expandedId,
    required this.onToggleExpanded,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> cocktails;
  final Map<String, Ingredient> ingredientsById;
  final String? expandedId;
  final ValueChanged<String> onToggleExpanded;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      itemCount: cocktails.length,
      itemBuilder: (context, index) {
        final cocktail = cocktails[index];
        final isExpanded = cocktail.id == expandedId;

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
                                    const Icon(
                                      Icons.wine_bar_rounded,
                                      size: 14,
                                      color: Color(0xFFAEB9E8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        cocktail.glassType,
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
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: cocktail.isFavorite
                                ? 'Убрать из избранного'
                                : 'В избранное',
                            onPressed: () =>
                                onToggleFavoritePressed(cocktail.id),
                            icon: Icon(
                              cocktail.isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFFC88A),
                            ),
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
                                const Icon(
                                  Icons.wine_bar_rounded,
                                  color: Color(0xFFFFB9DD),
                                  size: 17,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Бокал: ${cocktail.glassType}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFB9DD),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Состав',
                              style: TextStyle(
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
                                            if (isOptional) 'Опционально',
                                            if (isDecoration) 'Украшение',
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
                                          'Замена: $substitutionsText',
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
                                const Text(
                                  'Приготовление',
                                  style: TextStyle(
                                    color: Color(0xFFFF93CC),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
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
                                  label: const Text('Редактировать'),
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
          tag,
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'По выбранным тегам коктейли не найдены',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFC3CCE8), fontSize: 16),
        ),
      ),
    );
  }
}

class NoCocktailsView extends StatelessWidget {
  const NoCocktailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
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
          child: const Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFA8D8),
                  size: 38,
                ),
                SizedBox(height: 12),
                Text(
                  'Пока не хватает ингредиентов',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Добавь позиции в "Сыром баре", и здесь появятся доступные коктейли.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFCAD2EB), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
