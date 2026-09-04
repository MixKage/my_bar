import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bar_pressable.dart';
import '../../domain/models/cocktail.dart';
import '../../domain/models/ingredient.dart';
import '../../domain/models/measurement_system.dart';
import 'cocktail_details_page.dart';

class SurpriseCocktailPage extends StatefulWidget {
  const SurpriseCocktailPage({
    required this.cocktails,
    required this.initialCocktailId,
    required this.missingIngredientsByCocktailId,
    required this.ingredientsById,
    required this.visitorMode,
    required this.measurementSystem,
    required this.powerSavingMode,
    required this.onEditCocktailPressed,
    required this.onToggleFavoritePressed,
    super.key,
  });

  final List<Cocktail> cocktails;
  final String initialCocktailId;
  final Map<String, List<String>> missingIngredientsByCocktailId;
  final Map<String, Ingredient> ingredientsById;
  final bool visitorMode;
  final MeasurementSystem measurementSystem;
  final bool powerSavingMode;
  final Future<void> Function(Cocktail cocktail) onEditCocktailPressed;
  final ValueChanged<String> onToggleFavoritePressed;

  @override
  State<SurpriseCocktailPage> createState() => _SurpriseCocktailPageState();
}

class _SurpriseCocktailPageState extends State<SurpriseCocktailPage> {
  final Random _random = Random();
  late int _index;
  late Set<String> _favoriteIds;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _index = widget.cocktails.indexWhere(
      (c) => c.id == widget.initialCocktailId,
    );
    if (_index < 0) _index = 0;
    _favoriteIds = widget.cocktails
        .where((c) => c.isFavorite)
        .map((c) => c.id)
        .toSet();
  }

  Future<void> _next() async {
    if (_switching || widget.cocktails.length < 2) return;
    final duration = AppMotion.duration(
      context,
      AppMotion.emphasized,
      powerSavingMode: widget.powerSavingMode,
    );
    HapticFeedback.selectionClick();
    setState(() {
      // Non-zero offset guarantees no immediate repeat.
      _index =
          (_index + 1 + _random.nextInt(widget.cocktails.length - 1)) %
          widget.cocktails.length;
      _switching = true;
    });
    await Future<void>.delayed(duration);
    if (mounted) setState(() => _switching = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cocktails.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            context.tr('Нет подходящих коктейлей', 'No matching cocktails'),
          ),
        ),
      );
    }
    final cocktail = widget.cocktails[_index];
    return Scaffold(
      body: HeroMode(
        enabled: false,
        child: AnimatedSwitcher(
          duration: AppMotion.duration(
            context,
            AppMotion.emphasized,
            powerSavingMode: widget.powerSavingMode,
          ),
          switchInCurve: AppMotion.enterCurve,
          switchOutCurve: AppMotion.exitCurve,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              for (final child in previous)
                ExcludeSemantics(child: IgnorePointer(child: child)),
              ?current,
            ],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: CocktailDetailsPage(
            key: ValueKey<String>(cocktail.id),
            cocktail: cocktail,
            initialIsFavorite: _favoriteIds.contains(cocktail.id),
            missingIngredientNames:
                widget.missingIngredientsByCocktailId[cocktail.id] ??
                const <String>[],
            ingredientsById: widget.ingredientsById,
            visitorMode: widget.visitorMode,
            measurementSystem: widget.measurementSystem,
            powerSavingMode: widget.powerSavingMode,
            onEditCocktailPressed: widget.onEditCocktailPressed,
            onToggleFavoritePressed: (id) {
              if (!_favoriteIds.add(id)) _favoriteIds.remove(id);
              widget.onToggleFavoritePressed(id);
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.cocktails.length == 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.tr(
                    'В этой подборке только один коктейль',
                    'There is only one cocktail in this selection',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFAEB9DB),
                    fontSize: 12,
                  ),
                ),
              ),
            BarActionButton(
              label: context.tr('Следующий коктейль', 'Next cocktail'),
              icon: Icons.shuffle_rounded,
              powerSavingMode: widget.powerSavingMode,
              onPressed: _switching || widget.cocktails.length < 2
                  ? null
                  : _next,
            ),
          ],
        ),
      ),
    );
  }
}
