// Reproducible editorial migration for the October 2026 bundled-catalog audit.
// Run explicitly with `node tool/catalog_audit/repair_catalog.mjs`.
// Source references and the policy for unspecified measures are in the audit report.
import fs from 'node:fs';

const paths = ['assets/data/bar_template.json', 'assets/data/bar_template_ru.json'];
const catalogs = paths.map(path => JSON.parse(fs.readFileSync(path, 'utf8')));
const original = catalogs.map(catalog => structuredClone(catalog));
const date = '2026-10-19';
const changeIds = new Set();
const descriptions = new Map();
const source = slug => `https://iba-world.com/iba-cocktail/${slug}/`;
const measures = entries => Object.fromEntries(entries.map(([id, amount, unit = 'мл']) => [id, [String(amount), unit]]));

function recipe(id, entries, en, ru, url, options = {}) {
  if (options.description) descriptions.set(id, options.description);
  for (let language = 0; language < catalogs.length; language++) {
    const cocktail = catalogs[language].cocktails.find(c => c.id === id);
    if (!cocktail) throw new Error(`Unknown cocktail: ${id}`);
    if (entries) {
      const values = measures(entries);
      cocktail.ingredients = Object.keys(values);
      cocktail.ingredientAmounts = Object.fromEntries(Object.entries(values).map(([id, value]) => [id, value[0]]));
      cocktail.ingredientUnits = Object.fromEntries(Object.entries(values).map(([id, value]) => [id, value[1]]).filter(([, value]) => value));
      cocktail.optionalIngredients = cocktail.optionalIngredients.filter(id => id in values);
      cocktail.decorationIngredients = cocktail.decorationIngredients.filter(id => id in values);
      cocktail.ingredientSubstitutions = {};
    }
    if (en) cocktail.preparationSteps = language ? ru : en;
    if (options.description) cocktail.description = options.description[language];
    if (options.decoration) cocktail.decorationIngredients = options.decoration;
    if (options.optional) cocktail.optionalIngredients = options.optional;
    if (options.glass) cocktail.glassType = options.glass;
    if (options.removeIba) cocktail.tags = cocktail.tags.filter(tag => !tag.toLowerCase().includes('iba'));
    cocktail.sourceMetadata = {
      ...cocktail.sourceMetadata,
      recipeReviewedAt: date,
      ...(url ? { recipeSourceUrl: url } : {}),
    };
    if (options.yield) cocktail.sourceMetadata.recipeYield = options.yield;
  }
  changeIds.add(id);
}

function ingredient(id, names, templateId) {
  catalogs.forEach((catalog, language) => {
    if (catalog.ingredients.some(i => i.id === id)) return;
    const template = catalog.ingredients.find(i => i.id === templateId);
    catalog.ingredients.push({
      ...template,
      id,
      name: names[language],
      displayName: names[language],
      sourceId: id,
      canonicalSlug: id,
      // Reuse an existing related illustration; no new network dependency.
      remoteImageUrl: undefined,
      isDecoration: false,
      isOptional: false,
    });
  });
}

ingredient('peach_puree', ['White peach purée', 'Пюре белого персика'], 'peach_nectar');
ingredient('grapefruit_soda', ['Grapefruit soda', 'Грейпфрутовая газировка'], 'juice_grapefruit');
ingredient('creme_de_violette', ['Crème de violette', 'Фиалковый ликёр'], 'creme_de_mure');
ingredient('orange_flower_water', ['Orange flower water', 'Вода цветков апельсина'], 'orange');
ingredient('cinnamon_syrup', ['Cinnamon syrup', 'Коричный сироп'], 'syrup_sugar');
ingredient('fat_washed_mezcal', ['Prepared fat-washed mezcal', 'Готовый мескаль, настоянный на жире'], 'mezcal');
ingredient('habanero_tincture', ['Prepared habanero tincture', 'Готовая настойка хабанеро'], 'hot_sauce');
ingredient('red_chilli', ['Fresh red chilli', 'Свежий красный перец чили'], 'red_chili_flakes');

recipe('americano', [['campari',30],['rosso_vermouth',30],['soda_water','Top up',''],['orange','1/2','долька'],['lemon',1,'twist']],
  ['Fill a rocks glass with ice and add Campari and sweet red vermouth.', 'Add a splash of soda water and stir gently.', 'Garnish with the orange slice and lemon peel.'],
  ['Наполните рокс льдом, добавьте кампари и красный сладкий вермут.', 'Долейте немного содовой и осторожно перемешайте.', 'Украсьте ломтиком апельсина и лимонной цедрой.'], source('americano'), {decoration:['orange','lemon']});
recipe('aviation', [['gin',45],['lemon',15],['maraschino_liqueur',15],['creme_de_violette',1,'tsp'],['maraschino_cherry',1,'шт']],
  ['Shake the gin, lemon juice and both liqueurs with ice until chilled.', 'Strain into a chilled cocktail glass.', 'Add the optional maraschino cherry.'],
  ['Встряхните джин, лимонный сок и оба ликёра со льдом до охлаждения.', 'Процедите в охлаждённый коктейльный бокал.', 'По желанию украсьте коктейльной вишней.'], source('aviation'), {optional:['maraschino_cherry'],decoration:['maraschino_cherry']});
recipe('bellini', [['prosecco',100],['peach_puree',50]],
  ['Chill a flute glass, the peach purée and the Prosecco.', 'Gently combine the purée and Prosecco in a mixing glass with ice.', 'Pour into the chilled flute, leaving the ice behind.'],
  ['Охладите бокал-флейту, персиковое пюре и просекко.', 'Осторожно соедините пюре и просекко в смесительном стакане со льдом.', 'Перелейте в охлаждённую флейту, оставив лёд в смесительном стакане.'], source('bellini'), {description:['Peach purée and Prosecco form this gently sparkling classic.','Нежный игристый коктейль из персикового пюре и просекко.']});
recipe('b-52', [['kahlua',15],['baileys_irish_cream',15],['grand_marnier',15]],
  ['Pour the coffee liqueur into a chilled shot glass.', 'Slowly pour Irish cream over the back of a spoon to form the middle layer.', 'Layer the orange liqueur on top in the same way. Serve without lighting.'],
  ['Налейте кофейный ликёр в охлаждённую стопку.', 'Медленно налейте сливочный ликёр по обратной стороне ложки, формируя средний слой.', 'Так же добавьте сверху апельсиновый ликёр. Подавайте без поджигания.'], 'https://www.kahlua.com/en-ca/drinks/b-52-recipe/');
recipe('casino', [['gin',40],['maraschino_liqueur',10],['lemon',10],['orange_bitter',2,'dash'],['cherry',1,'шт']],
  ['Shake Old Tom gin, maraschino liqueur, fresh lemon juice and orange bitters with ice.', 'Strain into a chilled rocks glass over fresh ice.', 'Garnish with the cherry; a small lemon-peel twist is optional.'],
  ['Встряхните джин Old Tom, ликёр мараскино, свежий лимонный сок и апельсиновый биттер со льдом.', 'Процедите в охлаждённый рокс со свежим льдом.', 'Украсьте вишней; по желанию добавьте немного лимонной цедры.'], source('casino'), {decoration:['cherry'],glass:'Рокс'});
recipe('clover-club', [['gin',45],['syrup_raspberry',15],['lemon',15],['egg_white','A few drops','']],
  ['Combine gin, raspberry syrup, fresh lemon juice and a few drops of pasteurized egg white in a shaker.', 'Shake without ice to develop foam, then add ice and shake again until cold.', 'Strain into a chilled cocktail glass.'],
  ['Соедините в шейкере джин, малиновый сироп, свежий лимонный сок и несколько капель пастеризованного яичного белка.', 'Встряхните без льда для пены, затем добавьте лёд и встряхните ещё раз до охлаждения.', 'Процедите в охлаждённый коктейльный бокал.'], source('clover-club'));
recipe('dark-and-stormy', [['rum_dark',60],['ginger_beer',100]],
  ['Fill a highball glass with ice and add ginger beer.', 'Slowly pour the dark rum on top. Garnish with a lime wedge if desired.'],
  ['Наполните хайбол льдом и налейте имбирное пиво.', 'Медленно налейте сверху тёмный ром. По желанию украсьте долькой лайма.'], source('dark-n-stormy'));
recipe('espresso-martini', [['vodka',50],['kahlua',30],['syrup_sugar',10],['espresso',1,'shot']],
  ['Brew one strong espresso and let it cool briefly.', 'Add the vodka, coffee liqueur, sugar syrup and espresso to a shaker with ice.', 'Shake vigorously until foamy and strain into a chilled cocktail glass.'],
  ['Приготовьте одну порцию крепкого эспрессо и немного остудите.', 'Добавьте в шейкер со льдом водку, кофейный ликёр, сахарный сироп и эспрессо.', 'Энергично встряхните до появления пены и процедите в охлаждённый коктейльный бокал.'], source('espresso-martini'));
recipe('long-island-tea', [['vodka',15],['rum_light',15],['gin',15],['tequila',15],['cointreau',15],['lemon',25],['syrup_sugar',30],['coca_cola','Top up','']],
  ['Fill a highball glass with ice.', 'Add the five spirits, fresh lemon juice and sugar syrup.', 'Top with cola and stir gently.'],
  ['Наполните хайбол льдом.', 'Добавьте пять алкогольных ингредиентов, свежий лимонный сок и сахарный сироп.', 'Долейте колой и осторожно перемешайте.'], source('long-island-iced-tea'));
recipe('mai-tai', [['rum_gold',30],['rum_dark',30],['orange_curacao',15],['orgeat_syrup',15],['lime',30],['syrup_sugar',7.5]],
  ['Use an amber Jamaican rum and a molasses-based Martinique rum for the two rum measures.', 'Shake both rums, orange curaçao, orgeat, fresh lime juice and sugar syrup with ice.', 'Pour into a double rocks glass with the ice. Garnish with mint and lime peel if desired.'],
  ['Для двух порций рома используйте янтарный ямайский и выдержанный ром Мартиники на основе мелассы.', 'Встряхните оба рома, апельсиновый кюрасао, оршад, свежий сок лайма и сахарный сироп со льдом.', 'Перелейте вместе со льдом в большой рокс. По желанию украсьте мятой и цедрой лайма.'], source('mai-tai'));
recipe('mimosa', [['prosecco',75],['juice_orange',75]],
  ['Chill the orange juice, Prosecco and a flute glass.', 'Pour the juice into the glass, slowly add the Prosecco and stir once gently.'],
  ['Охладите апельсиновый сок, просекко и бокал-флейту.', 'Налейте в бокал сок, медленно добавьте просекко и осторожно перемешайте.'], source('mimosa'));
recipe('monkey-gland', [['gin',45],['juice_orange',45],['absinthe',1,'tbsp'],['grenadine',1,'tbsp']],
  ['Shake the gin, orange juice, absinthe and grenadine with ice.', 'Strain into a chilled cocktail glass.'],
  ['Встряхните джин, апельсиновый сок, абсент и гренадин со льдом.', 'Процедите в охлаждённый коктейльный бокал.'], source('monkey-gland'));
recipe('moscow-mule', [['vodka',45],['ginger_beer',120],['lime',10]],
  ['Fill a mule mug or rocks glass with ice.', 'Add vodka, ginger beer and fresh lime juice; stir gently.'],
  ['Наполните кружку для мула или рокс льдом.', 'Добавьте водку, имбирное пиво и свежий сок лайма; осторожно перемешайте.'], source('moscow-mule'));
recipe('old-cuban', [['rum_dark',45],['lime',22.5],['syrup_sugar',30],['angostura_bitter',2,'dash'],['mint','6-8','leaf'],['prosecco',60]],
  ['Combine the aged rum, fresh lime juice, syrup, bitters and mint in a shaker with ice.', 'Shake and double-strain into a chilled cocktail glass.', 'Slowly add the Prosecco and garnish with mint if desired.'],
  ['Соедините выдержанный ром, свежий сок лайма, сироп, биттер и мяту в шейкере со льдом.', 'Встряхните и дважды процедите в охлаждённый коктейльный бокал.', 'Медленно долейте просекко и по желанию украсьте мятой.'], source('old-cuban'));
recipe('paloma', [['tequila',50],['lime',5],['salt',1,'pinch'],['grapefruit_soda',100]],
  ['Pour the tequila and fresh lime juice into a highball glass.', 'Add ice and the pinch of salt, then pour in grapefruit soda.', 'Stir gently.'],
  ['Налейте текилу и свежий сок лайма в хайбол.', 'Добавьте лёд и щепотку соли, затем грейпфрутовую газировку.', 'Осторожно перемешайте.'], source('paloma'));
recipe('penicillin', [['blended_scotch',60],['lemon',22.5],['syrup_honey',22.5],['ginger','2-3','долька'],['islay_single_malt_scotch',7.5]],
  ['Muddle the fresh ginger slices in a shaker.', 'Add blended Scotch, fresh lemon juice, honey syrup and ice; shake until cold.', 'Fine-strain into a rocks glass over fresh ice.', 'Slowly float the smoky Islay whisky on top.'],
  ['Разомните ломтики свежего имбиря в шейкере.', 'Добавьте купажированный скотч, свежий лимонный сок, медовый сироп и лёд; встряхните до охлаждения.', 'Процедите через мелкое сито в рокс со свежим льдом.', 'Медленно налейте сверху дымный виски с острова Айла.'], source('penicillin'));
recipe('pina-colada', [['rum_light',50],['cream_of_coconut',30],['juice_pineapple',50]],
  ['Put the white rum, coconut cream and pineapple juice in a blender with crushed ice.', 'Blend until smooth, then pour into a large chilled glass.'],
  ['Поместите белый ром, кокосовые сливки и ананасовый сок в блендер с колотым льдом.', 'Взбейте до однородности и перелейте в большой охлаждённый бокал.'], source('pina-colada'));
recipe('pisco-sour', [['pisco',60],['lemon',30],['syrup_sugar',20],['egg_white',1,'шт'],['bitters','A few dashes','']],
  ['Shake pisco, fresh lemon juice, sugar syrup and one pasteurized egg white without ice to develop foam.', 'Add ice, shake until cold and strain into a chilled glass.', 'Place a few drops of aromatic bitters on the foam.'],
  ['Встряхните писко, свежий лимонный сок, сахарный сироп и один пастеризованный яичный белок без льда для пены.', 'Добавьте лёд, встряхните до охлаждения и процедите в охлаждённый бокал.', 'Добавьте на пену несколько капель ароматического биттера.'], source('pisco-sour'), {decoration:['bitters']});
recipe('ramos-gin-fizz', [['gin',45],['lime',15],['lemon',15],['syrup_sugar',30],['cream',60],['egg_white',30],['orange_flower_water',3,'dash'],['vanilla_extract',2,'капля'],['soda_water','Top up','']],
  ['Put all ingredients except soda water in a shaker with ice; use pasteurized egg white.', 'Shake thoroughly for about two minutes. Strain, return the liquid to the shaker and shake again without ice for about one minute.', 'Strain into a highball glass and gently top with soda water. Never shake the soda.'],
  ['Добавьте в шейкер со льдом всё, кроме содовой; используйте пастеризованный белок.', 'Тщательно встряхивайте около двух минут. Процедите, верните жидкость в шейкер и встряхивайте без льда ещё около минуты.', 'Процедите в хайбол и осторожно долейте содовой. Содовую не взбалтывайте.'], source('ramos-fizz'));
recipe('russian-spring-punch', [['vodka',25],['lemon',25],['creme_de_cassis',15],['syrup_sugar',10],['prosecco','Top up','']],
  ['Shake vodka, fresh lemon juice, cassis and sugar syrup with ice.', 'Strain into a tall glass filled with fresh ice, then top with sparkling wine.'],
  ['Встряхните водку, свежий лимонный сок, крем де кассис и сахарный сироп со льдом.', 'Процедите в высокий бокал со свежим льдом, затем долейте игристым вином.'], source('russian-spring-punch'));
recipe('sazerac', [['cognac',50],['absinthe',10],['sugar',1,'cube'],['peychauds_bitter',2,'dash'],['lemon',1,'twist']],
  ['Rinse a chilled rocks glass with absinthe, add ice temporarily and set aside.', 'Dissolve the sugar with Peychaud’s bitters in a mixing glass, then add cognac and ice and stir until cold.', 'Discard the ice and excess absinthe from the serving glass; strain the cocktail into it.', 'Express the lemon-peel oils over the drink and garnish with the peel.'],
  ['Ополосните охлаждённый рокс абсентом, временно наполните льдом и отставьте.', 'Растворите сахар с биттером Peychaud’s в смесительном стакане, затем добавьте коньяк и лёд и перемешайте до охлаждения.', 'Уберите лёд и лишний абсент из бокала подачи; процедите в него коктейль.', 'Выдавите над напитком масла из лимонной цедры и украсьте цедрой.'], source('sazerac'), {decoration:['lemon']});
recipe('tequila-sunrise', [['tequila',45],['juice_orange',90],['grenadine',15]],
  ['Pour tequila and orange juice into a highball glass filled with ice.', 'Slowly add grenadine so it sinks and creates the sunrise gradient. Do not stir.'],
  ['Налейте текилу и апельсиновый сок в хайбол со льдом.', 'Медленно добавьте гренадин: он опустится на дно и создаст градиент восхода. Не перемешивайте.'], source('tequila-sunrise'));
recipe('zombie', [['rum_dark',45],['rum_gold',45],['151_proof_rum',30],['lime',20],['falernum',15],['juice_grapefruit',10],['cinnamon_syrup',5],['grenadine',1,'tsp'],['angostura_bitter',1,'dash'],['pernod',6,'капля']],
  ['The grapefruit juice and cinnamon syrup together make one measure of Donn’s Mix (2:1).', 'Put all measured ingredients in a blender with about 170 g of cracked ice.', 'Pulse for only a few seconds and pour into a tall tumbler. Add more ice if needed.'],
  ['Грейпфрутовый сок и коричный сироп вместе образуют порцию смеси Донна в соотношении 2:1.', 'Поместите все отмеренные ингредиенты в блендер примерно со 170 г дроблёного льда.', 'Включите импульсный режим на несколько секунд и перелейте в высокий стакан. При необходимости добавьте лёд.'], source('zombie'));

recipe('the-laverstoke', [['gin',50],['elderflower_cordial',15],['rosso_vermouth',15],['ginger_ale',100],['lime',2,'долька'],['ginger',1,'долька'],['mint',1,'sprig']],
  ['Squeeze the lime wedges into a balloon glass; add the ginger, elderflower cordial, vermouth and gin.', 'Fill with ice and stir to chill.', 'Add ginger ale, stir gently and garnish with the mint. This version uses the producer’s winter Rosso variation and cordial alternative.'],
  ['Выжмите дольки лайма в большой бокал-баллон; добавьте имбирь, сироп бузины, вермут и джин.', 'Наполните льдом и перемешайте до охлаждения.', 'Добавьте имбирный эль, осторожно перемешайте и украсьте мятой. Здесь используется зимняя версия производителя с Rosso и безалкогольным сиропом бузины.'], 'https://www.bombaysapphire.com/distillery/gin-cocktails/the-laverstoke/', {decoration:['mint']});

// Straightforward preparation repairs retain the source's existing proportions.
const repairs = [
  ['kabonyelka', ['Pour coffee liqueur into a chilled shot glass.', 'Carefully add sambuca over the back of a spoon.', 'Add Galliano in the same way to form the top layer.'], ['Налейте кофейный ликёр в охлаждённую стопку.', 'Осторожно добавьте самбуку по обратной стороне ложки.', 'Так же добавьте сверху Гальяно.']],
  ['abc', ['Pour amaretto into a chilled shot glass.', 'Slowly add Irish cream over the back of a spoon, then layer cognac on top.'], ['Налейте амаретто в охлаждённую стопку.', 'Медленно добавьте сливочный ликёр по обратной стороне ложки, затем сверху коньяк.']],
  ['afterglow', ['Combine the two juices and grenadine.', 'Pour over ice in a highball glass and stir.'], ['Смешайте оба сока и гренадин.', 'Перелейте в хайбол со льдом и перемешайте.']],
  ['apello', ['Pour the three juices into a glass with ice and stir.', 'Garnish with the maraschino cherry.'], ['Налейте три сока в бокал со льдом и перемешайте.', 'Украсьте коктейльной вишней.']],
  ['avalanche', ['Shake the whisky, coffee liqueur and cream in a shaker with ice.', 'Strain into a highball glass over fresh ice.'], ['Встряхните виски, кофейный ликёр и сливки в шейкере со льдом.', 'Процедите в хайбол со свежим льдом.']],
  ['b-53', ['Pour Kahlúa into a chilled shot glass.', 'Slowly layer sambuca and then Grand Marnier over the back of a spoon.'], ['Налейте Калуа в охлаждённую стопку.', 'Медленно налейте по обратной стороне ложки сначала самбуку, затем Гран Марнье.']],
  ['baby-eskimo', ['Let the ice cream soften briefly.', 'Stir the coffee liqueur, milk and ice cream together in a large glass until smooth. Serve immediately.'], ['Дайте мороженому немного размягчиться.', 'Размешайте кофейный ликёр, молоко и мороженое в большом бокале до однородности. Подавайте сразу.']],
  ['bahama-mama', ['Combine the rums, liqueur, grenadine, juices and sweet-and-sour mix in a glass with ice.', 'Add soda water last and stir gently.'], ['Соедините ром, ликёр, гренадин, соки и кисло-сладкую смесь в бокале со льдом.', 'В конце добавьте содовую и осторожно перемешайте.']],
  ['barracuda', ['Shake everything except Prosecco with ice.', 'Strain into a chilled glass, then top with Prosecco.'], ['Встряхните со льдом всё, кроме просекко.', 'Процедите в охлаждённый бокал, затем долейте просекко.']],
  ['bijou', ['Combine all ingredients in a mixing glass with ice.', 'Stir until chilled and strain into a chilled cocktail glass.'], ['Соедините все ингредиенты в смесительном стакане со льдом.', 'Перемешайте до охлаждения и процедите в охлаждённый коктейльный бокал.']],
  ['broadside', ['Half-fill a rocks glass with ice.', 'Add the fresh culinary wormwood, rum, Scotch and bitters, then stir.'], ['Наполните рокс льдом наполовину.', 'Добавьте свежую полынь, предназначенную для пищевого использования, ром, скотч и биттер, затем перемешайте.']],
  ['bubble-gum', ['Combine the four equal measures in a mixing glass with ice.', 'Stir briefly and strain into a chilled shot glass.'], ['Соедините четыре равные меры в смесительном стакане со льдом.', 'Недолго перемешайте и процедите в охлаждённую стопку.']],
  ['bumble-bee', ['Pour Irish cream into a shot glass.', 'Slowly add coffee liqueur over the back of a spoon, followed by sambuca.'], ['Налейте сливочный ликёр в стопку.', 'Медленно добавьте по обратной стороне ложки кофейный ликёр, затем самбуку.']],
  ['caipirissima', ['Cut the limes into wedges and gently muddle them with sugar in a sturdy glass.', 'Add white rum and crushed ice. Stir thoroughly.'], ['Нарежьте лаймы дольками и осторожно разомните с сахаром в прочном стакане.', 'Добавьте белый ром и колотый лёд. Хорошо перемешайте.']],
  ['chocolate-milk', ['Pour milk into a chilled shot glass.', 'Slowly add chocolate liqueur and a dash of amaretto. Serve without stirring.'], ['Налейте молоко в охлаждённую стопку.', 'Медленно добавьте шоколадный ликёр и немного амаретто. Подавайте, не перемешивая.']],
  ['corn-n-oil', ['Cut the half lime into two wedges and muddle with falernum and bitters in a rocks glass.', 'Add the aged rum and ice, then stir.', 'Slowly float blackstrap rum on top.'], ['Разрежьте половину лайма на две дольки и разомните с фалернумом и биттером в роксе.', 'Добавьте выдержанный ром и лёд, затем перемешайте.', 'Медленно налейте сверху ром Blackstrap.']],
  ['corpse-reviver', ['Coat a chilled cocktail glass with the absinthe and discard the excess.', 'Shake all remaining ingredients with ice and strain into the prepared glass.'], ['Ополосните охлаждённый коктейльный бокал абсентом и слейте лишнее.', 'Встряхните остальные ингредиенты со льдом и процедите в подготовленный бокал.']],
  ['death-in-the-afternoon', ['Chill the glass and both ingredients.', 'Pour in the absinthe, slowly top with Champagne and serve.'], ['Охладите бокал и оба ингредиента.', 'Налейте абсент, медленно долейте шампанское и подавайте.']],
  ['elderflower-caipirinha', ['Cut the lime into wedges and muddle gently in a sturdy glass.', 'Add elderflower cordial, cachaça and crushed ice.', 'Stir and add more crushed ice if needed.'], ['Нарежьте лайм дольками и осторожно разомните в прочном стакане.', 'Добавьте сироп бузины, кашасу и колотый лёд.', 'Перемешайте и при необходимости добавьте ещё колотого льда.']],
  ['espresso-rumtini', ['Combine the rum, vanilla syrup, espresso and coffee in a shaker with ice.', 'Shake until chilled and strain into a cocktail glass.'], ['Соедините ром, ванильный сироп, эспрессо и кофе в шейкере со льдом.', 'Встряхните до охлаждения и процедите в коктейльный бокал.']],
  ['flaming-dr-pepper', ['Combine the amaretto, vodka and rum in a chilled glass.', 'Add Dr Pepper and beer, then stir gently. Serve unlit.'], ['Соедините амаретто, водку и ром в охлаждённом бокале.', 'Добавьте Dr Pepper и пиво, затем осторожно перемешайте. Подавайте без поджигания.']],
  ['flaming-lamborghini', ['Combine all four chilled liqueurs in a cocktail glass.', 'Stir gently and serve unlit. This is the no-flame version.'], ['Соедините четыре охлаждённых ликёра в коктейльном бокале.', 'Осторожно перемешайте и подавайте без поджигания. Это версия без огня.']],
  ['freddy-kruger', ['Combine the three chilled spirits in a shot glass and stir briefly.'], ['Соедините три охлаждённых алкогольных ингредиента в стопке и слегка перемешайте.']],
  ['grand-blue', ['Shake all ingredients with ice until cold.', 'Strain into a rocks glass over fresh ice.'], ['Встряхните все ингредиенты со льдом до охлаждения.', 'Процедите в рокс со свежим льдом.']],
  ['hemingway-special', ['Shake all ingredients with ice until cold.', 'Strain into a chilled cocktail glass.'], ['Встряхните все ингредиенты со льдом до охлаждения.', 'Процедите в охлаждённый коктейльный бокал.']],
  ['honey-bee', ['Stir honey with fresh lemon juice until it loosens.', 'Add rum and ice, shake well and strain into a chilled cocktail glass.'], ['Размешайте мёд со свежим лимонным соком, чтобы он стал менее густым.', 'Добавьте ром и лёд, хорошо встряхните и процедите в охлаждённый коктейльный бокал.']],
  ['hot-chocolate-to-die-for', ['Melt the chocolate with butter and vanilla over a water bath.', 'Stir in half-and-half until smooth and hot, without boiling.', 'Pour into mugs and add mini marshmallows.'], ['Растопите шоколад с маслом и ванилью на водяной бане.', 'Добавьте смесь молока и сливок, размешайте до однородности и прогрейте, не кипятите.', 'Разлейте по кружкам и добавьте мини-маршмеллоу.']],
  ['irish-cream', ['Combine the Scotch and condensed milk.', 'Stir in half-and-half, coconut syrup and chocolate syrup until smooth.', 'Refrigerate in a clean closed container and serve chilled.'], ['Соедините скотч и сгущённое молоко.', 'Добавьте смесь молока и сливок, кокосовый и шоколадный сиропы; размешайте до однородности.', 'Храните в чистой закрытой ёмкости в холодильнике и подавайте охлаждённым.']],
  ['jackhammer', ['Pour both spirits into a rocks glass with ice and stir.'], ['Налейте оба алкогольных ингредиента в рокс со льдом и перемешайте.']],
  ['karsk', ['Pour hot coffee into a heatproof cup.', 'Add the measured food-grade grain spirit and stir. No coin is needed.'], ['Налейте горячий кофе в термостойкую чашку.', 'Добавьте отмеренный пищевой зерновой спирт и перемешайте. Монета не нужна.']],
  ['kioki-coffee', ['Pour Kahlúa and brandy into a heatproof mug.', 'Top with hot coffee and stir. Add whipped cream if desired.'], ['Налейте Калуа и бренди в термостойкую кружку.', 'Долейте горячий кофе и перемешайте. По желанию добавьте взбитые сливки.']],
  ['kiwi-martini', ['Peel the kiwi and muddle it with sugar syrup in a shaker.', 'Add vodka and ice, then shake well.', 'Fine-strain into a chilled cocktail glass.'], ['Очистите киви и разомните с сахарным сиропом в шейкере.', 'Добавьте водку и лёд, хорошо встряхните.', 'Процедите через мелкое сито в охлаждённый коктейльный бокал.']],
  ['lassi-khara', ['Blend the yoghurt, cold water, salt and asafoetida until frothy.', 'Serve chilled. Curry leaves are an optional garnish.'], ['Взбейте йогурт, холодную воду, соль и асафетиду до пены.', 'Подавайте охлаждённым. По желанию украсьте листьями карри.']],
  ['lazy-coconut-paloma', ['Fill a highball glass with ice.', 'Add coconut liqueur and grapefruit juice, top with soda water and stir gently.'], ['Наполните хайбол льдом.', 'Добавьте кокосовый ликёр и грейпфрутовый сок, долейте содовой и осторожно перемешайте.']],
  ['lemon-shot', ['Combine Galliano, lemon vodka and a small float of rum in a shot glass.', 'Serve with a lemon wedge sprinkled with sugar. Serve unlit.'], ['Соедините Гальяно, лимонную водку и немного рома в стопке.', 'Подайте с долькой лимона, посыпанной сахаром. Подавайте без поджигания.']],
  ['lunch-box', ['Pour chilled beer and orange juice into a pint glass, leaving room.', 'Pour in the amaretto directly and stir gently; do not drop a glass into the drink.'], ['Налейте охлаждённое пиво и апельсиновый сок в большой бокал, оставив место.', 'Добавьте амаретто прямо в напиток и осторожно перемешайте; не бросайте рюмку в бокал.']],
  ['melya', ['Mix one teaspoon of cocoa powder and one teaspoon of honey in a coffee cup.', 'Pour in freshly brewed espresso while stirring until dissolved.'], ['Смешайте по одной чайной ложке какао-порошка и мёда в кофейной чашке.', 'Влейте свежеприготовленный эспрессо и размешайте до растворения.']],
  ['michelada', ['Pour the tomato juice, lime juice and sauces into a chilled glass and stir.', 'Slowly add beer and stir gently. Do not shake.'], ['Налейте томатный сок, сок лайма и соусы в охлаждённый бокал и перемешайте.', 'Медленно добавьте пиво и осторожно перемешайте. Не взбалтывайте.']],
  ['national-aquarium', ['Shake all ingredients except lemon-lime soda with ice.', 'Strain over fresh ice in a tall glass, then add the soda and stir gently.'], ['Встряхните со льдом всё, кроме лимонно-лаймовой газировки.', 'Процедите в высокий бокал со свежим льдом, добавьте газировку и осторожно перемешайте.']],
  ['new-york-lemonade', ['Moisten the glass rim with lemon juice and dip in sugar if desired.', 'Shake vodka, orange liqueur and lemon juice with ice.', 'Strain into a glass, add soda water and stir gently.'], ['По желанию смочите край бокала лимонным соком и обмакните в сахар.', 'Встряхните водку, апельсиновый ликёр и лимонный сок со льдом.', 'Процедите в бокал, добавьте содовую и осторожно перемешайте.']],
  ['nuked-hot-chocolate', ['Mix cocoa, sugar, vanilla and a little milk in a microwave-safe mug.', 'Heat briefly and stir until smooth.', 'Add the remaining milk and heat in short intervals, stirring, until hot.'], ['Смешайте какао, сахар, ваниль и немного молока в кружке для микроволновой печи.', 'Недолго прогрейте и размешайте до однородности.', 'Добавьте оставшееся молоко и нагревайте короткими интервалами, помешивая, до горячего состояния.']],
  ['orange-crush', ['Shake all ingredients with ice.', 'Strain into a chilled glass.'], ['Встряхните все ингредиенты со льдом.', 'Процедите в охлаждённый бокал.']],
  ['orange-push-up', ['Blend all ingredients with crushed ice until smooth.', 'Pour into a large glass.'], ['Взбейте все ингредиенты с колотым льдом в блендере до однородности.', 'Перелейте в большой бокал.']],
  ['owen-s-grandmother-s-revenge', ['Chill the whisky, beer and lemonade.', 'Combine gently in a large pitcher with ice. Do not blend or shake carbonated beer.'], ['Охладите виски, пиво и лимонад.', 'Осторожно соедините в большом кувшине со льдом. Газированное пиво не взбивайте в блендере или шейкере.']],
  ['pink-panty-pulldowns', ['Chill all ingredients.', 'Mix the vodka and pink lemonade in a pitcher, add Sprite last and stir gently. Do not shake.'], ['Охладите все ингредиенты.', 'Смешайте водку и розовый лимонад в кувшине, в конце добавьте Sprite и осторожно перемешайте. Не взбалтывайте.']],
  ['popped-cherry', ['Pour vodka, cherry liqueur and both juices into a tall glass with ice.', 'Stir and serve; add a cherry if desired.'], ['Налейте водку, вишнёвый ликёр и оба сока в высокий бокал со льдом.', 'Перемешайте и подавайте; по желанию украсьте вишней.']],
  ['pornstar-martini', ['Shake vodka, Passoã, passion-fruit juice and lime juice with ice; keep the Prosecco separate.', 'Strain into a chilled cocktail glass.', 'Serve the chilled Prosecco alongside in a small glass.'], ['Встряхните водку, Passoã, сок маракуйи и сок лайма со льдом; просекко оставьте отдельно.', 'Процедите в охлаждённый коктейльный бокал.', 'Подайте охлаждённое просекко отдельно в небольшой рюмке.']],
  ['pure-passion', ['Combine the rum, Passoã, lime juice, passion-fruit syrup and peach bitters in a glass with crushed ice.', 'Stir well and garnish with mint.'], ['Соедините ром, Passoã, сок лайма, сироп маракуйи и персиковый биттер в бокале с колотым льдом.', 'Хорошо перемешайте и украсьте мятой.']],
  ['pysch-vitamin-light', ['Shake all three juices with ice.', 'Strain into a tall glass over fresh ice.'], ['Встряхните три сока со льдом.', 'Процедите в высокий бокал со свежим льдом.']],
  ['red-snapper', ['Shake the whisky, amaretto and cranberry juice with ice.', 'Strain into a chilled glass.'], ['Встряхните виски, амаретто и клюквенный сок со льдом.', 'Процедите в охлаждённый бокал.']],
  ['salty-dog', ['Moisten the rim of a highball glass with grapefruit juice and dip it in salt.', 'Add ice, gin and grapefruit juice, then stir gently.'], ['Смочите край хайбола грейпфрутовым соком и обмакните в соль.', 'Добавьте лёд, джин и грейпфрутовый сок, затем осторожно перемешайте.']],
  ['screwdriver', ['Fill a highball glass with ice.', 'Add vodka, top with orange juice and stir gently.'], ['Наполните хайбол льдом.', 'Добавьте водку, долейте апельсиновым соком и осторожно перемешайте.']],
  ['shot-gun', ['Combine the three whiskies in a chilled glass and stir briefly.'], ['Соедините три вида виски в охлаждённом бокале и слегка перемешайте.']],
  ['stinger', ['Add brandy and white crème de menthe to a mixing glass with ice.', 'Stir until cold and strain into a chilled cocktail glass.'], ['Добавьте бренди и белый мятный ликёр в смесительный стакан со льдом.', 'Перемешайте до охлаждения и процедите в охлаждённый коктейльный бокал.']],
  ['the-philosopher', ['Shake gin, melon liqueur, orange bitters and lemon juice with ice.', 'Strain into a chilled glass, then top with Prosecco.'], ['Встряхните джин, дынный ликёр, апельсиновый биттер и лимонный сок со льдом.', 'Процедите в охлаждённый бокал, затем долейте просекко.']],
  ['tipperary', ['Stir all ingredients with ice until chilled.', 'Strain into a chilled glass. Express orange-peel oils over the surface if desired, then discard the peel.'], ['Перемешайте все ингредиенты со льдом до охлаждения.', 'Процедите в охлаждённый бокал. По желанию выдавите над напитком масла из апельсиновой цедры, затем уберите цедру.']],
  ['winter-paloma', ['Fill a rocks glass with ice.', 'Add tequila, fresh lime juice and agave syrup.', 'Top with grapefruit juice, add a dash of food-grade pepper and stir. This is the simplified version; the original uses prepared pepper-infused tequila.'], ['Наполните рокс льдом.', 'Добавьте текилу, свежий сок лайма и сироп агавы.', 'Долейте грейпфрутовым соком, добавьте немного пищевого перца и перемешайте. Это упрощённая версия; в оригинале используется заранее настоянная на перце текила.']],
  ['yoghurt-cooler', ['Put the yoghurt, fruit and ice in a blender with the lid secured.', 'Blend until smooth and pour into glasses. Stop the blender before adding more ice.'], ['Поместите йогурт, фрукты и лёд в блендер и закройте крышку.', 'Взбейте до однородности и разлейте по бокалам. Перед добавлением льда остановите блендер.']],
  ['zipperhead', ['Fill a tall glass with ice.', 'Pour in Chambord, then vodka, and finally soda water. Pour slowly to retain the layers.'], ['Наполните высокий бокал льдом.', 'Налейте шамбор, затем водку и в конце содовую. Наливайте медленно, чтобы сохранить слои.']],
  ['zizi-coin-coin', ['Pour Cointreau and fresh lemon juice over ice in a glass.', 'Stir gently and garnish with a lemon slice if desired.'], ['Налейте Куантро и свежий лимонный сок в бокал со льдом.', 'Осторожно перемешайте и по желанию украсьте ломтиком лимона.']],
  ['zorbatini', ['Stir vodka and ouzo with ice in a mixing glass.', 'Strain into a chilled cocktail glass. An olive is an optional garnish.'], ['Перемешайте водку и узо со льдом в смесительном стакане.', 'Процедите в охлаждённый коктейльный бокал. По желанию украсьте оливкой.']],
];
for (const [id, en, ru] of repairs) recipe(id, null, en, ru);

// Repairs supported by the bundled source text, where an ingredient/measure was
// omitted from the ingredient list or the translation changed its meaning.
function setMeasure(id, ingredientId, amount, unit = '', options = {}) {
  catalogs.forEach(catalog => {
    const c = catalog.cocktails.find(c => c.id === id);
    if (!c.ingredients.includes(ingredientId)) c.ingredients.push(ingredientId);
    c.ingredientAmounts[ingredientId] = String(amount);
    if (unit) c.ingredientUnits[ingredientId] = unit;
    else delete c.ingredientUnits[ingredientId];
    for (const [key, selected] of Object.entries(options)) {
      if (selected && !c[key].includes(ingredientId)) c[key].push(ingredientId);
    }
  });
  changeIds.add(id);
}
function replaceIngredient(id, from, to) {
  catalogs.forEach(catalog => {
    const c = catalog.cocktails.find(c => c.id === id);
    c.ingredients = [...new Set(c.ingredients.map(i => i === from ? to : i))];
    for (const field of ['ingredientAmounts','ingredientUnits']) {
      if (from in c[field]) { c[field][to] = c[field][from]; delete c[field][from]; }
    }
    c.optionalIngredients = c.optionalIngredients.map(i => i === from ? to : i);
    c.decorationIngredients = c.decorationIngredients.map(i => i === from ? to : i);
  });
  changeIds.add(id);
}
setMeasure('bahama-mama','soda_water',2,'part');
setMeasure('elderflower-caipirinha','elderflower_cordial',30,'мл');
setMeasure('egg-nog-4','sugar','1/2','cup'); // Two separate 1/4 cups in the method.
setMeasure('melya','honey',1,'tsp');
setMeasure('melya','cocoa_powder',1,'tsp');
setMeasure('melya','espresso',1,'shot');
setMeasure('quarter-deck-cocktail','rum_light','1 1/2','oz');
setMeasure('lemon-shot','sugar',1,'pinch');
setMeasure('rosemary-blue','lemon',1,'долька');
setMeasure('the-laverstoke','ginger_ale',100,'мл');
setMeasure('thai-coffee','sugar','1-2','tsp');
setMeasure('thai-coffee','ice','5-6','cube');
setMeasure('thai-iced-coffee','cardamom','2-3','шт');
setMeasure('thai-iced-coffee','cream','To taste');
setMeasure('zoksel','coca_cola','To taste'); // A "slice of cola" is a source-column error.
setMeasure('zoksel','lemon',1,'долька',{decorationIngredients:true});
setMeasure('english-rose-cocktail','powdered_sugar','For the rim','',{decorationIngredients:true,optionalIngredients:true});
setMeasure('lemon-drop','sugar','For the rim','',{decorationIngredients:true,optionalIngredients:true});
setMeasure('john-collins','angostura_bitter',1,'dash',{optionalIngredients:true});
setMeasure('planter-s-punch-178368-178368-178368','angostura_bitter',1,'dash');
setMeasure('zorro','coffee','Top up');
setMeasure('zorro','whipped_cream','For garnish','',{decorationIngredients:true});
replaceIngredient('munich-mule','lemon','lime');
replaceIngredient('empell-n-cocina-s-fat-washed-mezcal','mezcal','fat_washed_mezcal');
setMeasure('empell-n-cocina-s-fat-washed-mezcal','habanero_tincture',5,'капля',{optionalIngredients:true});
recipe('empell-n-cocina-s-fat-washed-mezcal',null,
  ['Use already prepared adobo fat-washed mezcal for this recipe.', 'Stir the prepared mezcal and chocolate liqueur with ice for about 45 seconds.', 'Strain into a chilled coupe, then slowly pour the coffee liqueur down the inside over a spoon.', 'Optionally finish with five drops of prepared habanero tincture.'],
  ['Для этого рецепта используйте уже подготовленный мескаль, настоянный на жире с адобо.', 'Перемешивайте подготовленный мескаль и шоколадный ликёр со льдом около 45 секунд.', 'Процедите в охлаждённый бокал-купе, затем медленно налейте кофейный ликёр по стенке через ложку.', 'По желанию добавьте пять капель готовой настойки хабанеро.'],
  undefined, {description:['A chocolate-and-coffee cocktail requiring prepared fat-washed mezcal; the optional habanero tincture adds heat.','Шоколадно-кофейный коктейль на заранее подготовленном мескале, настоянном на жире; настойка хабанеро добавляется по желанию.']});

// The original Spice 75 method is explicitly a six-glass batch (the publisher's
// header says five, but its actual method specifies six). Preserve that basis.
setMeasure('spice-75','sugar',60,'g');
setMeasure('spice-75','water',30,'мл');
setMeasure('spice-75','champagne',600,'мл');
recipe('spice-75',null,
  ['Batch recipe: the quantities make six flute glasses.', 'Warm the sugar with 30 ml water and allspice until dissolved; cool and filter.', 'Measure 60 ml of the prepared spiced syrup. Shake it with the rum, lime juice and ice, working in batches if necessary.', 'Divide among six flutes, add 100 ml Champagne to each and garnish with orange peel.'],
  ['Рецепт на кувшин: указанные количества рассчитаны на шесть бокалов-флейт.', 'Нагрейте сахар с 30 мл воды и душистым перцем до растворения; остудите и отфильтруйте.', 'Отмерьте 60 мл готового пряного сиропа. Встряхните его с ромом, соком лайма и льдом, при необходимости в несколько приёмов.', 'Разделите между шестью флейтами, добавьте в каждую по 100 мл шампанского и украсьте апельсиновой цедрой.'],
  'https://www.bbcgoodfood.com/recipes/spice-75', {yield:6});

recipe('drinking-chocolate',null,
  ['Warm the cream, milk, cinnamon stick and split vanilla pod gently for 15–20 minutes.', 'Remove the vanilla pod and cinnamon stick.', 'Stir in the chocolate until melted. Divide between one or two mugs and top with whipped cream.'],
  ['Осторожно нагревайте сливки, молоко, палочку корицы и разрезанный стручок ванили 15–20 минут.', 'Удалите стручок ванили и палочку корицы.', 'Добавьте шоколад и размешайте до растворения. Разлейте по одной-двум кружкам и украсьте взбитыми сливками.']);
recipe('gluehwein',null,
  ['Heat the water, sugar and spices until the sugar dissolves, then let infuse for 30 minutes.', 'Strain, add wine and lemon juice and heat gently without boiling.', 'Serve hot. Brief heating does not make wine alcohol-free.'],
  ['Нагрейте воду, сахар и специи до растворения сахара и оставьте на 30 минут.', 'Процедите, добавьте вино и лимонный сок и осторожно нагрейте без кипения.', 'Подавайте горячим. Краткий нагрев не делает вино безалкогольным.']);
recipe('h-d',null,
  ['Combine whisky and Irish cream in a heatproof glass with capacity of at least 500 ml.', 'Top with hot coffee and stir.'],
  ['Соедините виски и сливочный ликёр в термостойком бокале объёмом не менее 500 мл.', 'Долейте горячий кофе и перемешайте.']);
recipe('ipamena',null,
  ['Cut half a lime into pieces and muddle with brown sugar in a shaker.', 'Add passion-fruit juice and ice, then shake well.', 'Strain into a glass, top with ginger ale and stir gently.'],
  ['Нарежьте половину лайма кусочками и разомните с коричневым сахаром в шейкере.', 'Добавьте сок маракуйи и лёд, хорошо встряхните.', 'Процедите в бокал, долейте имбирным элем и осторожно перемешайте.']);

recipe('hunter-s-moon', [['gin',1,'part'],['vermouth_dry','1/2','part'],['sherry','1/2','part'],['olive',1,'шт'],['lemon',1,'twist']],
  ['This is the spirit-forward Absolut Drinks version of Hunter’s Moon.', 'Stir gin, dry vermouth and sherry with ice until cold.', 'Strain into a chilled cocktail glass and garnish with the olive and lemon peel.'],
  ['Это крепкая версия Hunter’s Moon от Absolut Drinks.', 'Перемешайте джин, сухой вермут и херес со льдом до охлаждения.', 'Процедите в охлаждённый коктейльный бокал и украсьте оливкой и лимонной цедрой.'],
  'https://www.absolutdrinks.com/en/drinks/hunters-moon/', {decoration:['olive','lemon'],glass:'Мартини', description:['A gin, dry-vermouth and sherry cocktail, following the Absolut Drinks version.','Коктейль из джина, сухого вермута и хереса по версии Absolut Drinks.']});
recipe('lone-tree-cooler', [['gin',2,'oz'],['vermouth_dry',1,'tbsp'],['powdered_sugar','1/2','tsp'],['soda_water','Top up',''],['orange_spiral',1,'twist'],['lemon',1,'twist']],
  ['Dissolve the sugar in about 60 ml of the soda water in a Collins glass.', 'Add ice, gin and dry vermouth and stir.', 'Top with more soda water and garnish with the citrus peels.'],
  ['Растворите сахар примерно в 60 мл содовой в стакане коллинз.', 'Добавьте лёд, джин и сухой вермут и перемешайте.', 'Долейте содовой и украсьте цитрусовой цедрой.'],
  'https://nscpolteksby.ac.id/ebook/files/Ebook/Hospitality/Mister%20Boston%20Official%20Bartenders%20guide%20%282009%29/5.%20Chapter%204%20-%20GIN.pdf', {decoration:['orange_spiral','lemon']});
setMeasure('gin-cooler','powdered_sugar','1/2','tsp');
setMeasure('gin-cooler','orange_spiral',1,'twist',{decorationIngredients:true});
setMeasure('gin-cooler','lemon',1,'twist',{decorationIngredients:true});
recipe('gin-cooler',null,
  ['Dissolve the sugar in about 60 ml soda water in a Collins glass.', 'Add ice and gin, top with more soda and stir.', 'Garnish with the orange and lemon peels.'],
  ['Растворите сахар примерно в 60 мл содовой в стакане коллинз.', 'Добавьте лёд и джин, долейте содовой и перемешайте.', 'Украсьте апельсиновой и лимонной цедрой.'],
  'https://www.crystalmixer.com/gin-cooler-recipe/');
setMeasure('figgy-thyme','lemon','Fresh juice to taste');
setMeasure('figgy-thyme','thyme',1,'sprig');
recipe('figgy-thyme',null,
  ['Muddle the figs and thyme in a shaker.', 'Add vodka, honey and fresh lemon juice to taste; the original source does not specify a fixed lemon measure.', 'Add ice, shake and strain into a Collins glass over crushed ice.', 'Top with tonic and add the bitters.'],
  ['Разомните инжир и тимьян в шейкере.', 'Добавьте водку, мёд и свежий лимонный сок по вкусу; исходный рецепт не задаёт точный объём сока.', 'Добавьте лёд, встряхните и процедите в коллинз с колотым льдом.', 'Долейте тоником и добавьте биттер.'],
  'https://www.thecocktaildb.com/drink/178344');
recipe('halloween-punch', [['cherry_juice',2,'л'],['orange',3,'шт'],['red_chilli',1,'шт'],['cinnamon',3,'stick'],['cloves',10,'шт'],['ginger',6,'долька'],['vodka',200]],
  ['Batch recipe: makes about 12 small glasses; vodka is optional.', 'Peel the oranges; use only the peel. Pierce the whole chilli.', 'Simmer cherry juice, orange peel, chilli, cinnamon, cloves and ginger for five minutes.', 'Cool and refrigerate for at least four hours. Strain out the spices and peel.', 'Stir in vodka if using and pour into glasses.'],
  ['Рецепт на кувшин: примерно 12 небольших бокалов; водка добавляется по желанию.', 'Снимите цедру с апельсинов; нужна только цедра. Проколите целый перец чили.', 'Томите вишнёвый сок, цедру, чили, корицу, гвоздику и имбирь пять минут.', 'Остудите и уберите в холодильник минимум на четыре часа. Процедите от специй и цедры.', 'При желании добавьте водку, перемешайте и разлейте по бокалам.'],
  'https://www.bbcgoodfood.com/recipes/halloween-punch', {yield:12,optional:['vodka']});
// The imported Mango Mojito mixed a 200 ml pitcher list with 30 ml individual
// instructions. Keep the batch list, distribute it evenly, and leave its yield
// open instead of claiming an unsupported number of servings.
setMeasure('mango-mojito','sugar','To taste');
setMeasure('mango-mojito','mint','To taste');
recipe('mango-mojito',null,
  ['Pitcher recipe: the quantities below are for the whole batch.', 'Peel and dice the mango. Blend it with the juice of half the limes.', 'Cut the remaining limes into wedges and gently muddle with sugar and mint to taste in a pitcher.', 'Add mango purée, all the measured rum and crushed ice; stir well.', 'Top with soda water and divide evenly between glasses.'],
  ['Рецепт на кувшин: указанные количества относятся ко всей смеси.', 'Очистите и нарежьте манго. Измельчите его с соком половины лаймов.', 'Оставшиеся лаймы нарежьте дольками и осторожно разомните в кувшине с сахаром и мятой по вкусу.', 'Добавьте пюре манго, весь отмеренный ром и колотый лёд; хорошо перемешайте.', 'Долейте содовой и равномерно разлейте по бокалам.'],
  'https://www.thecocktaildb.com/drink/178358');
setMeasure('hot-toddy','water',400,'мл');
recipe('hot-toddy',null,
  ['The quantities make two heatproof glasses.', 'Divide the whisky and honey between the glasses. Add half a cinnamon stick to each.', 'Add 200 ml hot water to each glass and stir.', 'Add lemon juice to taste and garnish each glass with a lemon slice and one clove.'],
  ['Указанные количества рассчитаны на два термостойких бокала.', 'Разделите виски и мёд между бокалами. Добавьте в каждый по половине палочки корицы.', 'Долейте в каждый по 200 мл горячей воды и перемешайте.', 'Добавьте лимонный сок по вкусу и украсьте каждый бокал ломтиком лимона с одной гвоздикой.'],
  'https://www.bbcgoodfood.com/recipes/hot-toddy', {yield:2});
setMeasure('fros','water','1/2','cup');
setMeasure('fros','ice',1,'cup');
setMeasure('campari-beer','lager',1,'bottle');
setMeasure('fruit-cooler','juice_apple',1,'can');
setMeasure('sangria','wine_red',1,'bottle');
setMeasure('wine-punch','wine_red',1,'bottle');
setMeasure('shark-attack','lemonade',1,'can');
setMeasure('gin-smash','sugar',1,'cube');
setMeasure('jamaican-coffee','rum','1/6','part');
setMeasure('jamaican-coffee','coffee','1/6','part');
setMeasure('jamaican-coffee','water','1/2','part');
setMeasure('jitterbug','gin',2,'part');
setMeasure('jitterbug','vodka',1,'part');
// The source does not define the capacity of a "fifth" or generic bottle here.
setMeasure('brain-fart','everclear','1 fifth bottle');
setMeasure('brain-fart','vodka','1 fifth bottle');
setMeasure('homemade-kahlua','vodka','1 fifth bottle');
for (const id of ['gin-daisy','gin-sour','gin-smash','john-collins','rum-cobbler','rum-sour','tom-collins']) setMeasure(id,'orange',1,'долька',{decorationIngredients:true});
setMeasure('grass-skirt','pineapple',1,'долька',{decorationIngredients:true});
setMeasure('dragonfly','lime',1,'долька',{decorationIngredients:true});
setMeasure('rum-cobbler','lemon',1,'долька',{decorationIngredients:true});
setMeasure('rum-punch','rum',1,'bottle');
setMeasure('rum-punch','ginger_ale',1,'bottle');
recipe('rum-punch',null,
  ['Batch recipe. The source calls for a small bottle of rum and a large bottle of ginger ale but does not define their capacities.', 'Combine the rum and juices in a punch bowl with crushed ice.', 'Add ginger ale last and stir gently.'],
  ['Рецепт на чашу для пунша. В источнике указаны маленькая бутылка рома и большая бутылка имбирного эля без точного объёма.', 'Соедините ром и соки в чаше для пунша с колотым льдом.', 'В конце добавьте имбирный эль и осторожно перемешайте.']);
recipe('munich-mule', [['gin',50],['lime',20],['ginger_beer',100],['cucumber','For garnish','']],
  ['Fill a highball glass with ice.', 'Add gin and fresh lime juice.', 'Pour in ginger beer, stir gently and garnish with cucumber.'],
  ['Наполните хайбол льдом.', 'Добавьте джин и свежий сок лайма.', 'Долейте имбирным пивом, осторожно перемешайте и украсьте огурцом.'],
  undefined, {decoration:['cucumber']});
recipe('duchamp-s-punch',null,
  ['Add pisco, lime juice, pineapple syrup, elderflower liqueur, bitters and a pinch of pepper to a shaker with ice.', 'Shake until cold and double-strain into a chilled double rocks glass over one large ice cube.', 'Garnish with the lavender sprigs.'],
  ['Добавьте писко, сок лайма, ананасовый сироп, ликёр бузины, биттер и щепотку перца в шейкер со льдом.', 'Встряхните до охлаждения и дважды процедите в охлаждённый большой рокс с одним крупным кубиком льда.', 'Украсьте веточками лаванды.']);
setMeasure('duchamp-s-punch','lavender',2,'sprig',{decorationIngredients:true});
recipe('fros',null,
  ['Batch recipe: pour the rosé into a shallow freezer-safe container and freeze for at least six hours, until almost solid.', 'Heat the sugar and half a cup of water until dissolved. Remove from the heat, add strawberries and infuse for 30 minutes.', 'Filter the strawberry syrup and chill. Measure 3 1/2 oz of this syrup for the drink; reserve any remainder.', 'Blend the frozen rosé with lemon juice, the measured syrup and one cup of crushed ice.', 'Freeze the mixture for 25–35 minutes, blend again briefly and divide between glasses.'],
  ['Рецепт на несколько бокалов: налейте розовое вино в неглубокую ёмкость для морозильной камеры и замораживайте минимум шесть часов, почти до твёрдого состояния.', 'Нагрейте сахар с половиной стакана воды до растворения. Снимите с огня, добавьте клубнику и оставьте на 30 минут.', 'Отфильтруйте клубничный сироп и охладите. Отмерьте 3 1/2 унции сиропа для напитка; остаток сохраните отдельно.', 'Измельчите в блендере замороженное вино, лимонный сок, отмеренный сироп и один стакан колотого льда.', 'Уберите смесь в морозильную камеру на 25–35 минут, ещё раз недолго взбейте и разделите между бокалами.']);
recipe('miami-vice',null,
  ['Blend the piña-colada mix with half the measured rum and crushed ice; set aside.', 'Separately blend the daiquiri mix with the remaining rum and crushed ice.', 'Layer the two frozen mixtures in a large glass. The source leaves the quantities of both prepared mixes variable.'],
  ['Взбейте смесь для пина-колады с половиной отмеренного рома и колотым льдом; отставьте.', 'Отдельно взбейте смесь для дайкири с оставшимся ромом и колотым льдом.', 'Выложите обе замороженные смеси слоями в большой бокал. Источник не задаёт точные количества готовых смесей.'],
  undefined, {removeIba:true});
recipe('mocha-berry',null,
  ['Stir the cocoa powder and raspberry liqueur into hot coffee until smooth.', 'Pour into a heatproof mug and top with whipped cream.'],
  ['Размешайте какао-порошок и малиновый ликёр в горячем кофе до однородности.', 'Перелейте в термостойкую кружку и украсьте взбитыми сливками.']);
recipe('new-york-sour',null,
  ['Shake whisky, fresh lemon juice and sugar with ice.', 'Strain into a rocks glass over fresh ice.', 'Slowly pour the red wine over the back of a spoon to float it on top. Garnish with the cherry.'],
  ['Встряхните виски, свежий лимонный сок и сахар со льдом.', 'Процедите в рокс со свежим льдом.', 'Медленно налейте красное вино по обратной стороне ложки, чтобы оно осталось сверху. Украсьте вишней.']);
recipe('space-odyssey',null,
  ['Fill a tall glass with ice.', 'Add both rums and the measured pineapple juice.', 'Top with orange juice, add grenadine to taste and garnish with cherries.'],
  ['Наполните высокий бокал льдом.', 'Добавьте оба рома и отмеренный ананасовый сок.', 'Долейте апельсиновым соком, добавьте гренадин по вкусу и украсьте вишней.']);
recipe('thai-iced-coffee',null,
  ['Brew a pot of strong coffee with two or three crushed cardamom pods in the grounds.', 'Sweeten the hot coffee to taste, then let it cool.', 'Pour over ice in a tall glass.', 'Slowly add cream over the back of a spoon to create a separate top layer.'],
  ['Заварите крепкий кофе, добавив к молотому кофе два-три раздавленных стручка кардамона.', 'Подсластите горячий кофе по вкусу и остудите.', 'Налейте в высокий бокал со льдом.', 'Медленно добавьте сливки по обратной стороне ложки, чтобы получился отдельный верхний слой.']);
recipe('zoksel',null,
  ['Chill all ingredients. The original recipe gives no fixed proportions.', 'Combine the beer and soft drinks in a large glass, adding cassis to taste.', 'Stir gently and garnish with the lemon slice. Do not shake the carbonated ingredients.'],
  ['Охладите все ингредиенты. В исходном рецепте нет фиксированных пропорций.', 'Соедините пиво и безалкогольные напитки в большом бокале, добавляя крем де кассис по вкусу.', 'Осторожно перемешайте и украсьте ломтиком лимона. Не взбалтывайте газированные ингредиенты.'],
  'https://www.thecocktaildb.com/drink/15691-zoksel-cocktail');
recipe('ziemes-martini-apfelsaft',null,
  ['Combine the vermouth and apple juice in a glass and stir gently.', 'Serve without ice; the original recipe calls for room-temperature juice.'],
  ['Соедините вермут и яблочный сок в бокале и осторожно перемешайте.', 'Подавайте без льда; в исходном рецепте используется сок комнатной температуры.']);
recipe('egg-nog-classic-cooked',null,
  ['Batch recipe: whisk the eggs, sugar and salt together in a large saucepan.', 'Stir in half the milk.', 'Cook over low heat, stirring continuously, until the mixture coats a spoon and reaches 160°F (about 71°C).', 'Remove from the heat and stir in the remaining milk and vanilla.', 'Cover and refrigerate until thoroughly chilled, for several hours or overnight.', 'Stir before pouring into cups and serve chilled.'],
  ['Рецепт на несколько порций: взбейте яйца, сахар и соль в большой кастрюле.', 'Добавьте половину молока и перемешайте.', 'Готовьте на слабом огне, непрерывно помешивая, пока смесь не начнёт обволакивать ложку и не достигнет 71°C (160°F).', 'Снимите с огня и добавьте оставшееся молоко и ваниль.', 'Накройте и уберите в холодильник на несколько часов или на ночь до полного охлаждения.', 'Перед подачей перемешайте и разлейте по чашкам. Подавайте охлаждённым.']);
recipe('frapp',null,
  ['Use chilled coffee and milk. If the coffee is freshly brewed, cool it first.', 'Blend the coffee, milk and sugar on high speed for about one minute, until frothy.', 'Pour into a glass and serve immediately.'],
  ['Используйте охлаждённые кофе и молоко. Свежесваренный кофе сначала остудите.', 'Взбейте кофе, молоко и сахар в блендере на высокой скорости около минуты до пены.', 'Перелейте в бокал и сразу подавайте.']);

// Complete quantities that the original method explicitly leaves variable.
// Never invent fixed millilitres for a source that supplies none.
const topUps = new Set(['soda_water','ginger_ale','coca_cola','lemon_lime_soda','fresca','lemonade','tonic_water']);
const garnishes = new Set(['nutmeg','whipped_cream','orange_spiral','lime_peel','cherry']);
const countIngredients = new Set(['egg','egg_white','egg_yolk','lime','lemon','orange','apple','banana','mango','kiwi','papaya','figs','strawberries','blackberries','pineapple','maraschino_cherry','cherry','olive','cloves','cardamom','black_pepper','oreo_cookie']);
const ratios = new Set(['abc','bubble-gum','moranguito']);
const changedMeasures = new Set();

for (let language = 0; language < catalogs.length; language++) {
  const catalog = catalogs[language];
  for (const c of catalog.cocktails) {
    c.ingredientAmounts ||= {};
    c.ingredientUnits ||= {};
    const juicedCitrus = new Set();
    for (const id of c.ingredients) {
      const before = JSON.stringify([c.ingredientAmounts[id],c.ingredientUnits[id]]);
      let amount = (c.ingredientAmounts[id] || '').trim();
      let unit = (c.ingredientUnits[id] || '').trim();
      if (unit === 'по вкусу') { amount ||= 'To taste'; unit = ''; }
      // English source measure, copied to RU before localization below.
      if (!unit) {
        const inline = amount.match(/^(\d+(?:[ .\/\-]\d+)*)\s+(gr|grams?|scoops?|qt|pints?|gal|lb|inches?|inch|packages?|bottles?|cans?)$/i);
        if (inline) {
          amount = inline[1];
          const token = inline[2].toLowerCase();
          unit = ({gr:'g',gram:'g',grams:'g',scoops:'scoop',scoop:'scoop',pints:'pint',pint:'pint',inches:'inch',inch:'inch',packages:'package',package:'package',bottles:'bottle',bottle:'bottle',cans:'can',can:'can'})[token] || token;
        } else if (/^\d+(?:-\d+)? cups? (?:white|boiling|cold|hot)$/i.test(amount)) {
          amount = amount.split(' ')[0]; unit = 'cup';
        } else if (/^\d+(?:-\d+)? (?:fresh leaves|fresh|Fresh|Large Sprig|whole|whole green|crushed)$/i.test(amount)) {
          amount = amount.split(' ')[0];
          unit = id === 'mint' ? (/sprig/i.test(c.ingredientAmounts[id]) ? 'sprig' : 'leaf') : 'шт';
        } else if (amount === '1 dl Schweppes') {
          amount = '100'; unit = 'мл';
        } else if (amount === '1/2 handful') {
          amount = '1/2'; unit = 'handful';
        } else if (amount === '2 or 3') {
          amount = '2-3'; unit = 'cube';
        } else if (/^(?:1 )?twist of$/i.test(amount) || amount === 'Twist of' || amount === '1 long strip') {
          amount = '1'; unit = 'twist';
        } else if (/^(?:1 )?splash(?:es)?$/i.test(amount)) {
          amount = 'A splash';
        } else if (amount === '2 splashes') {
          amount = 'Two splashes';
        } else if (/^dash$/i.test(amount)) {
          amount = '1'; unit = 'dash';
        } else if (/^pinch$/i.test(amount)) {
          amount = '1'; unit = 'pinch';
        } else if (amount === 'Around rim put 1 pinch') {
          amount = '1'; unit = 'pinch';
        } else if (amount === 'About 8 drops') {
          amount = '8'; unit = 'капля';
        } else if (/^(?:garnish(?: with)?|Fresh|Ground|ground|mini|Chopped|wedges|Rimmed|black|Turkish apple|very sweet|\(Claret\)|\(if needed\)|frozen)$/i.test(amount)) {
          amount = /garnish|rimmed|wedges|mini|Fresh|Ground|ground|Chopped/.test(amount) ? 'For garnish' : 'To taste';
        } else if (/^(?:top(?: up(?: with)?)?|fill(?: with| to top with)?|full glass|over|\(seltzer water\)|chilled)$/i.test(amount)) {
          amount = id === 'ice' ? 'As needed' : 'Top up';
        } else if (amount === 'Squeeze') {
          amount = 'Fresh juice to taste';
        } else if (amount === 'Float Bacardi') {
          amount = 'A small float';
        } else if (amount === 'wedge') {
          amount = '1'; unit = 'долька';
        } else if (amount === 'cubes' || amount === 'crushed') {
          amount = 'As needed';
        } else if (amount === 'Add 10 oz') {
          amount = '10'; unit = 'oz';
        } else if (amount === '1 small bottle') {
          amount = '1'; unit = 'bottle';
        } else if (amount === 'large bottle') {
          amount = '1 large bottle';
        } else if (amount === 'mikey bottle') {
          amount = '1 small bottle';
        } else if (amount === '1/2 Fresh') {
          amount = '1/2'; unit = 'шт';
        } else if (amount === '½') {
          amount = '1/2'; unit = 'шт';
        }
      }
      if (!amount) {
        amount = id === 'ice' || id === 'water' ? 'As needed' : topUps.has(id) ? 'Top up' : garnishes.has(id) ? 'For garnish' : 'To taste';
      }
      if (!unit && /^\d+(?:[ .\/\-]\d+)*$/.test(amount)) {
        if (ratios.has(c.id)) unit = 'part';
        else if (id === 'ice') unit = 'cube';
        else if (id === 'mint') unit = c.id === 'acapulco' ? 'sprig' : 'leaf';
        else if (id === 'vanilla') unit = 'stick';
        else if (id === 'cinnamon') unit = 'stick';
        else if (id === 'ginger') unit = 'долька';
        else if (countIngredients.has(id)) unit = 'шт';
      }
      if (unit === 'twist' || ['maraschino_cherry','cherry','nutmeg','orange_spiral','lime_peel'].includes(id)) {
        if (!c.decorationIngredients.includes(id)) c.decorationIngredients.push(id);
      }
      // Keep whole-fruit quantities scalable without inventing a juice yield.
      if (id === 'lemon' || id === 'lime') {
        const match = amount.match(/^(?:Juice of|Сок из) (\d+(?:\/\d+)?)(?: (wedge|дольки))?$/i);
        if (match) {
          amount = match[1]; unit = match[2] ? 'долька' : 'шт';
          juicedCitrus.add(id);
        }
      }
      const phrases = {
        'Top up':'Долить', 'To taste':'По вкусу', 'For garnish':'Для украшения', 'As needed':'По необходимости',
        'A splash':'Немного', 'Two splashes':'Два небольших всплеска', 'A small float':'Небольшой верхний слой',
        'Fresh juice to taste':'Свежий сок по вкусу', 'For the rim':'Для края бокала', 'A few drops':'Несколько капель',
        'A few dashes':'Несколько дэшей', '1 large bottle':'1 большая бутылка', '1 small bottle':'1 маленькая бутылка', '1 fifth bottle':'1 бутылка fifth (объём не указан)',
      };
      if (language) amount = phrases[amount] || amount;
      c.ingredientAmounts[id] = amount;
      if (unit) c.ingredientUnits[id] = unit;
      else delete c.ingredientUnits[id];
      if (before !== JSON.stringify([amount,c.ingredientUnits[id]])) changedMeasures.add(`${c.id}:${id}`);
    }
    if (juicedCitrus.size) {
      const note = language
        ? 'Выжмите указанное количество лимона или лайма: в напиток нужен только сок.'
        : 'Squeeze the indicated quantity of lemon or lime; use only its juice in the drink.';
      if (!c.preparationSteps.includes(note)) c.preparationSteps.unshift(note);
    }
    // Correct repeated literal mistranslations without changing the technique.
    if (language) c.preparationSteps = c.preparationSteps.map(step => step
      .replaceAll('старомодный стакан','стакан рокс').replaceAll('старинный стакан','стакан рокс')
      .replaceAll('старомодном стакане','стакане рокс').replaceAll('старинном стакане','стакане рокс')
      .replaceAll('кислый стакан','бокал для сауэра').replaceAll('на камнях','со льдом')
      .replaceAll('воздушный шар','большой бокал-баллон').replaceAll('легким кремом','нежирными сливками')
      .replaceAll('курбон','бурбон').replaceAll('Служить.','Подавайте.')
      .replaceAll('оранжевую спираль','спираль апельсиновой цедры').replaceAll('оранжевая спираль','спираль апельсиновой цедры')
      .replaceAll('апельсиновой завитком','полоской апельсиновой цедры').replaceAll('Гарнир.','Украсьте по желанию.')
      .replaceAll('бегового или виски','рома или виски'));
    // Every source's recipe has at least one clear action; remove empty labels.
    c.preparationSteps = c.preparationSteps.filter(step => !/^(?:step|шаг)\s*\d+$/i.test(step.trim()));
  }
  catalog.metadata.stats.importedCocktails = catalog.cocktails.length;
  catalog.metadata.stats.importedIngredients = catalog.ingredients.length;
  catalog.metadata.recipeAudit = {
    reviewedAt: date,
    reviewedCocktails: catalog.cocktails.length,
    policy: 'Preserve source variants; explicit variable measures; never infer shot or package capacity.',
    report: 'docs/catalog-audit-2026-10.md',
  };
}

// These source descriptions duplicate instructions. Keep the card's description
// synchronized when its method has been corrected, instead of leaving a second
// contradictory recipe (notably burning, wrong spirit, and wrong quantities).
for (let language = 0; language < catalogs.length; language++) {
  for (const c of catalogs[language].cocktails) {
    if (!changeIds.has(c.id)) continue;
    // Most seed descriptions are an independently translated copy of the
    // method, with subtle differences. Equality checks miss stale errors.
    // Preserve the one authored narrative and any explicit editorial summary;
    // otherwise synchronize both fields for all explicitly corrected cards.
    if (descriptions.has(c.id)) c.description = descriptions.get(c.id)[language];
    else if (c.id !== 'kabonyelka') c.description = c.preparationSteps.join(' ');
  }
  fs.writeFileSync(paths[language], `${JSON.stringify(catalogs[language], null, 2)}\n`);
}
const changedCocktails = original[0].cocktails.filter((c,index) => JSON.stringify(c) !== JSON.stringify(catalogs[0].cocktails[index]));
console.log(JSON.stringify({ reviewed: catalogs[0].cocktails.length, changedCocktails: changedCocktails.length, explicitlyRepaired: changeIds.size, normalizedMeasures: changedMeasures.size, ingredients: catalogs[0].ingredients.length }, null, 2));
