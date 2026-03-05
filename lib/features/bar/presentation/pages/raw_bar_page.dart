import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/bar_network_image.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../widgets/neon_background.dart';
import '../widgets/neon_bottom_navigation.dart';

class RawBarPage extends StatefulWidget {
  const RawBarPage({
    required this.ingredients,
    required this.cocktails,
    required this.selectedIngredientIds,
    required this.onToggleIngredient,
    required this.onManagePressed,
    super.key,
  });

  final List<Ingredient> ingredients;
  final List<Cocktail> cocktails;
  final Set<String> selectedIngredientIds;
  final ValueChanged<String> onToggleIngredient;
  final VoidCallback onManagePressed;

  @override
  State<RawBarPage> createState() => _RawBarPageState();
}

class _RawBarPageState extends State<RawBarPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomContentPadding =
        kNeonBottomNavigationHeight +
        kNeonBottomNavigationBottomMargin +
        bottomInset +
        24;

    final filteredIngredients = widget.ingredients
        .where(
          (ingredient) =>
              ingredient.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    final cocktailsByIngredient = _buildCocktailUsageMap(widget.cocktails);

    return NeonBackground(
      topGlow: const Color(0xFF7D4BFF),
      bottomGlow: const Color(0xFF2AA6FF),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topInset + 20,
          16,
          bottomContentPadding,
        ),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Мой Бар',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: <Color>[Color(0xFFCC9CFF), Color(0xFF67D5FF)],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 80)),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Управление баром',
                onPressed: widget.onManagePressed,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Выбери бутылки и ингредиенты, которые уже есть дома',
            style: TextStyle(color: Color(0xFFB8C1D9), fontSize: 15),
          ),
          const SizedBox(height: 18),
          AnimatedGradientBorder(
            colors: const <Color>[
              Color(0xFF6D5CFF),
              Color(0xFF52C7FF),
              Color(0xFF6D5CFF),
            ],
            borderRadius: BorderRadius.circular(18),
            borderWidth: 1.5,
            innerColor: const Color(0xFF111321),
            glowEffect: true,
            glow: const AnimatedGradientBorderGlow(opacity: 0.42),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                hintText: 'Поиск ингредиентов...',
                hintStyle: TextStyle(color: Color(0xFF7180A7)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFFA4B2DD),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...filteredIngredients.map((ingredient) {
            final selected = widget.selectedIngredientIds.contains(
              ingredient.id,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IngredientCard(
                ingredient: ingredient,
                cocktails:
                    cocktailsByIngredient[ingredient.id] ?? const <Cocktail>[],
                selected: selected,
                onTap: () => widget.onToggleIngredient(ingredient.id),
              ),
            );
          }),
          if (filteredIngredients.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 46),
              child: Center(
                child: Text(
                  'Ничего не найдено',
                  style: TextStyle(color: Color(0xFFA8B0C8), fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
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

class IngredientCard extends StatelessWidget {
  const IngredientCard({
    required this.ingredient,
    required this.cocktails,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Ingredient ingredient;
  final List<Cocktail> cocktails;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: selected ? 1.0 : 0.985,
      child: AnimatedGradientBorder(
        enabled: selected,
        showBorderWhenDisabled: true,
        disabledBorderColor: const Color(0xFF354067),
        glowEffect: selected,
        glow: const AnimatedGradientBorderGlow(opacity: 0.5),
        borderRadius: BorderRadius.circular(22),
        borderWidth: 1.7,
        innerColor: const Color(0xFF15182B),
        colors: const <Color>[
          Color(0xFFBB7DFF),
          Color(0xFF49D1FF),
          Color(0xFFBB7DFF),
        ],
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            height: 116,
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 90,
                      height: double.infinity,
                      child: BarNetworkImage(
                        imageUrl: ingredient.image,
                        loadingColor: const Color(0xFF8CA8FF),
                        loadingBackgroundColor: const Color(0xFF22263D),
                        errorWidget: const ColoredBox(
                          color: Color(0xFF22263D),
                          child: Icon(
                            Icons.local_bar_rounded,
                            color: Color(0xFF8FA3D8),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                          ingredient.category,
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
                                  const _IngredientAttributePill(
                                    label: 'Украшение',
                                    color: Color(0xFF7CCBFF),
                                  ),
                                if (ingredient.isOptional)
                                  const _IngredientAttributePill(
                                    label: 'Опционально',
                                    color: Color(0xFFB58BFF),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _cocktailHintText(cocktails),
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
                  padding: const EdgeInsets.only(right: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? const Color(0xFFB24EFF)
                          : const Color(0xFF242B46),
                      boxShadow: selected
                          ? const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x88B24EFF),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cocktailHintText(List<Cocktail> cocktails) {
    if (cocktails.isEmpty) {
      return 'Пока нет коктейлей с этим ингредиентом';
    }
    if (cocktails.length == 1) {
      return 'Приготовьте "${cocktails.first.name}"';
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
