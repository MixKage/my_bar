import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/widgets/bar_network_image.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../widgets/cocktail_glass_icon.dart';
import '../widgets/neon_background.dart';

String cocktailHeroTag(String cocktailId) => 'cocktail_hero_$cocktailId';

class CocktailDetailsPage extends StatefulWidget {
  const CocktailDetailsPage({
    required this.cocktail,
    required this.missingIngredientNames,
    required this.ingredientsById,
    required this.visitorMode,
    this.powerSavingMode = false,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final Cocktail cocktail;
  final List<String> missingIngredientNames;
  final Map<String, Ingredient> ingredientsById;
  final bool visitorMode;
  final bool powerSavingMode;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  State<CocktailDetailsPage> createState() => _CocktailDetailsPageState();
}

class _CocktailDetailsPageState extends State<CocktailDetailsPage> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.cocktail.isFavorite;
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    widget.onToggleFavoritePressed(widget.cocktail.id);
  }

  Future<void> _editCocktail() async {
    await widget.onEditCocktailPressed(widget.cocktail);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cocktail = widget.cocktail;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NeonBackground(
        topGlow: const Color(0xFFFF5BB0),
        bottomGlow: const Color(0xFF6A70FF),
        reduceEffects: widget.powerSavingMode,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, bottomInset + 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AnimatedGradientBorder(
                enabled: !widget.powerSavingMode,
                borderRadius: BorderRadius.circular(24),
                borderWidth: 1.8,
                innerColor: const Color(0xFF1A1D32),
                colors: const <Color>[
                  Color(0xFFFF6FAF),
                  Color(0xFF7E8BFF),
                  Color(0xFFFF6FAF),
                ],
                glowEffect: !widget.powerSavingMode,
                glow: const AnimatedGradientBorderGlow(opacity: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 260,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Hero(
                            tag: cocktailHeroTag(cocktail.id),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                              child: BarNetworkImage(
                                imageUrl: cocktail.image,
                                loadingColor: const Color(0xFFE6A8E3),
                                loadingBackgroundColor: const Color(0xFF2C2F4F),
                                errorWidget: const ColoredBox(
                                  color: Color(0xFF2C2F4F),
                                  child: Icon(
                                    Icons.local_drink_rounded,
                                    color: Color(0xFFB4BEEF),
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: _DetailsTopActionButton(
                              tooltip: context.tr('Назад', 'Back'),
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: _DetailsFavoriteButton(
                              tooltip: _isFavorite
                                  ? context.tr(
                                      'Убрать из избранного',
                                      'Remove from favorites',
                                    )
                                  : context.tr(
                                      'В избранное',
                                      'Add to favorites',
                                    ),
                              isFavorite: _isFavorite,
                              onPressed: _toggleFavorite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            cocktail.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (cocktail.description.isNotEmpty)
                            Text(
                              cocktail.description,
                              style: const TextStyle(
                                color: Color(0xFFC5CCE5),
                                fontSize: 14,
                              ),
                            ),
                          if (cocktail.description.isNotEmpty)
                            const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              CocktailGlassIcon(
                                glassType: cocktail.glassType,
                                size: 17,
                                color: const Color(0xFFFFB9DD),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr(
                                    'Бокал: ${context.cocktailGlassTypeLabel(cocktail.glassType)}',
                                    'Glass: ${context.cocktailGlassTypeLabel(cocktail.glassType)}',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFFFB9DD),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: cocktail.tags
                                .map(
                                  (tag) => _DetailsTagPill(
                                    label: context.cocktailTagLabel(tag),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 8),
                          _DetailsAvailabilityHint(
                            missingIngredientNames:
                                widget.missingIngredientNames,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Color(0x33FF7EC8)),
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
                                widget.ingredientsById[ingredientId];
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
                                .map(
                                  (id) =>
                                      widget.ingredientsById[id]?.name ?? id,
                                )
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
                              if (!widget.visitorMode)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFFB9DD),
                                  ),
                                  onPressed: _editCocktail,
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
                          const SizedBox(height: 6),
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
        ),
      ),
    );
  }
}

class _DetailsTagPill extends StatelessWidget {
  const _DetailsTagPill({required this.label});

  final String label;

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
          label,
          style: const TextStyle(
            color: Color(0xFFC9D5F6),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DetailsAvailabilityHint extends StatelessWidget {
  const _DetailsAvailabilityHint({
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

class _DetailsFavoriteButton extends StatefulWidget {
  const _DetailsFavoriteButton({
    required this.tooltip,
    required this.isFavorite,
    required this.onPressed,
  });

  final String tooltip;
  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  State<_DetailsFavoriteButton> createState() => _DetailsFavoriteButtonState();
}

class _DetailsFavoriteButtonState extends State<_DetailsFavoriteButton> {
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
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isFavorite
                    ? const Color(0x664A3E2E)
                    : const Color(0x44353C62),
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
                      ? const Color(0xFFFFD37B)
                      : const Color(0xFFC8D3F8),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsTopActionButton extends StatefulWidget {
  const _DetailsTopActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_DetailsTopActionButton> createState() =>
      _DetailsTopActionButtonState();
}

class _DetailsTopActionButtonState extends State<_DetailsTopActionButton> {
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
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x4A1B2545),
              ),
              child: Icon(
                widget.icon,
                color: const Color(0xFFE8ECFF),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
