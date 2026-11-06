import 'package:flutter/widgets.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/search/app_search_query.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/ingredient.dart';

AppSearchDocument ingredientSearchDocument(
  BuildContext context,
  Ingredient ingredient,
) => AppSearchDocument(
  name: ingredient.name,
  aliases: _ingredientSearchNames(ingredient),
  details: [
    ingredient.category,
    context.ingredientCategoryLabel(ingredient.category),
  ],
);

AppSearchDocument cocktailSearchDocument(
  BuildContext context,
  Cocktail cocktail,
  Map<String, Ingredient> ingredients,
) => AppSearchDocument(
  name: cocktail.name,
  aliases: {
    cocktail.id,
    ...cocktail.aliases,
    ...?_cocktailAliases[cocktail.id],
  },
  related: {
    for (final id in cocktail.ingredients)
      if (ingredients[id] case final Ingredient ingredient) ...{
        ingredient.name,
        ..._ingredientSearchNames(ingredient),
      } else
        id,
  },
  details: [
    cocktail.description,
    context.cocktailGlassTypeLabel(cocktail.glassType),
    ...cocktail.tags,
    ...cocktail.tags.map(context.cocktailTagLabel),
  ],
);

Iterable<String> _ingredientSearchNames(Ingredient ingredient) => {
  ingredient.id,
  ...ingredient.aliases,
  ...?_ingredientAliases[ingredient.id],
};

// These are alternative names for one record, not recipe substitutions.
const _ingredientAliases = <String, List<String>>{
  'orange': ['апельсин', 'apelsin', 'portakal', 'برتقال', '오렌지'],
  'juice_orange': ['orange juice', 'апельсиновый сок', 'jus d’orange'],
  'blood_orange': ['красный апельсин', 'blood orange'],
  'mint': ['мята', 'mint leaves'],
  'olive': ['оливка', 'оливки'],
  'gin': ['джин', 'dzhin'],
  'triple_sec': ['triple sec', 'трипл сек', 'tripl sek'],
  'wild_turkey': ['уайлд тёрки', 'wild turkey'],
  'syrup_sugar': ['simple syrup', 'sugar syrup', 'сахарный сироп'],
  'soda_water': [
    'club soda',
    'sparkling water',
    'содовая',
    'газированная вода',
  ],
  'coca_cola': ['coke', 'cola', 'кола', 'кока кола'],
  'fresh_lime_juice': ['fresh lime juice', 'сок лайма'],
  'whisky': ['whiskey', 'виски'],
  'baileys_irish_cream': ['baileys', 'бейлис', 'бэйлис'],
};

const _cocktailAliases = <String, List<String>>{
  'old-fashioned': ['олд фэшн', 'олд фешен', 'старомодный', 'old fashioned'],
  'whiskey-sour': ['whisky sour', 'виски сауэр', 'виски сауер'],
  'pina-colada': ['piña colada', 'пина колада'],
  'bloody-mary': ['bloody mary', 'кровавая мэри'],
  'mojito': ['мохито', 'mokhito', 'मोजिटो'],
  'negroni': ['негрони'],
  'cuba-libre': ['куба либре'],
  'sidecar': ['сайдкар', 'side car'],
  'gluehwein': ['glühwein', 'gluehwein', 'mulled wine', 'глинтвейн'],
  'orange-whip': ['orange whip', 'оранж уип'],
};
