import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/bar_network_image.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../widgets/neon_background.dart';

enum MenuViewMode { list, grid }

class BarMenuPage extends StatefulWidget {
  const BarMenuPage({
    required this.availableCocktails,
    required this.cocktailCount,
    required this.ingredientsById,
    required this.onManagePressed,
    super.key,
  });

  final List<Cocktail> availableCocktails;
  final int cocktailCount;
  final Map<String, Ingredient> ingredientsById;
  final VoidCallback onManagePressed;

  @override
  State<BarMenuPage> createState() => _BarMenuPageState();
}

class _BarMenuPageState extends State<BarMenuPage> {
  MenuViewMode _viewMode = MenuViewMode.list;
  String? _expandedCocktailId;

  @override
  Widget build(BuildContext context) {
    final expandedId = _resolveExpandedId(widget.availableCocktails);

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
            Expanded(
              child: widget.availableCocktails.isEmpty
                  ? const NoCocktailsView()
                  : _viewMode == MenuViewMode.grid
                  ? CocktailGrid(cocktails: widget.availableCocktails)
                  : CocktailList(
                      cocktails: widget.availableCocktails,
                      ingredientsById: widget.ingredientsById,
                      expandedId: expandedId,
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

  String? _resolveExpandedId(List<Cocktail> availableCocktails) {
    if (availableCocktails.isEmpty) {
      return null;
    }

    final hasActive = availableCocktails.any(
      (cocktail) => cocktail.id == _expandedCocktailId,
    );
    return hasActive ? _expandedCocktailId : availableCocktails.first.id;
  }
}

class CocktailGrid extends StatelessWidget {
  const CocktailGrid({required this.cocktails, super.key});

  final List<Cocktail> cocktails;

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Text(
                      cocktail.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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
    super.key,
  });

  final List<Cocktail> cocktails;
  final Map<String, Ingredient> ingredientsById;
  final String? expandedId;
  final ValueChanged<String> onToggleExpanded;

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
                              ],
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
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
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
                                  ],
                                ),
                              );
                            }),
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
                  'Добавь позиции в "Ингридиенты", и здесь появятся доступные коктейли.',
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
