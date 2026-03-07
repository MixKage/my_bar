import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/models/cocktail_glass_types.dart';

const Map<String, String> _glassTypeAssetPath = <String, String>{
  'Бокал шале': 'assets/icons/cocktails/coupe_glass.svg',
  'Винный бокал': 'assets/icons/cocktails/wine_glass.svg',
  'Ирландский стакан': 'assets/icons/cocktails/irish_coffee_glass.svg',
  'Коллинз': 'assets/icons/cocktails/collins_glass.svg',
  'Кружка': 'assets/icons/cocktails/beer_mug.svg',
  'Кубок': 'assets/icons/cocktails/goblet.svg',
  'Маргарита': 'assets/icons/cocktails/margarita_glass.svg',
  'Мартини': 'assets/icons/cocktails/martini_glass.svg',
  'Пинта': 'assets/icons/cocktails/pint_glass.svg',
  'Питчер': 'assets/icons/cocktails/pitcher.svg',
  'Рокс': 'assets/icons/cocktails/old_fashioned_glass.svg',
  'Рюмка': 'assets/icons/cocktails/shot_glass.svg',
  'Фужер': 'assets/icons/cocktails/champagne_flute.svg',
  'Хайболл': 'assets/icons/cocktails/highball_glass.svg',
  'Харрикейн': 'assets/icons/cocktails/hurricane_glass.svg',
  'Шот': 'assets/icons/cocktails/shot.svg',
};

String cocktailGlassAssetPath(String glassType) {
  return _glassTypeAssetPath[glassType] ??
      _glassTypeAssetPath[kDefaultCocktailGlassType]!;
}

class CocktailGlassIcon extends StatelessWidget {
  const CocktailGlassIcon({
    required this.glassType,
    this.size = 16,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final String glassType;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorFilter = color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn);
    return SvgPicture.asset(
      cocktailGlassAssetPath(glassType),
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: colorFilter,
      semanticsLabel: semanticLabel ?? glassType,
      placeholderBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.wine_bar_rounded,
          size: size,
          color: color ?? const Color(0xFFAEB9E8),
        ),
      ),
    );
  }
}
