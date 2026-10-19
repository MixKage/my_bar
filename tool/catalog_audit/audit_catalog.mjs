// Offline, read-only validation of every bundled recipe, including locale parity.
// Usage: node tool/catalog_audit/audit_catalog.mjs
import fs from 'node:fs';
import assert from 'node:assert/strict';

const filenames = ['bar_template.json', 'bar_template_ru.json'];
const catalogs = filenames.map(filename => JSON.parse(fs.readFileSync(`assets/data/${filename}`, 'utf8')));
const units = new Set(['мл','л','oz','cl','tsp','tbsp','shot','part','cup','dash','pinch','ч.ложка','ч.ложки','ст.ложка','ст.ложки','долька','шт','капля','по вкусу','g','sprig','leaf','scoop','twist','stick','cube','bottle','can','package','inch','lb','pint','qt','gal','handful']);
const numeric = /^\d+(?:[ .\/\-]\d+)*$/;
const stats = [];

for (const [index, catalog] of catalogs.entries()) {
  const context = filenames[index];
  const ingredientIds = new Set(catalog.ingredients.map(i => i.id));
  const recipeIds = new Set(catalog.cocktails.map(c => c.id));
  assert.equal(ingredientIds.size, catalog.ingredients.length, `${context}: duplicate ingredient IDs`);
  assert.equal(recipeIds.size, catalog.cocktails.length, `${context}: duplicate cocktail IDs`);
  assert.equal(catalog.metadata.stats.importedIngredients, ingredientIds.size, `${context}: ingredient metadata count`);
  assert.equal(catalog.metadata.stats.importedCocktails, recipeIds.size, `${context}: cocktail metadata count`);
  let entries = 0;
  let variableMeasures = 0;
  let sourceReferenced = 0;
  for (const c of catalog.cocktails) {
    const label = `${context}/${c.id}`;
    assert(c.name.trim(), `${label}: missing name`);
    assert(c.ingredients.length, `${label}: no ingredients`);
    assert.equal(new Set(c.ingredients).size, c.ingredients.length, `${label}: duplicate ingredients`);
    assert(c.preparationSteps.length && c.preparationSteps.every(s => typeof s === 'string' && s.trim().length > 3), `${label}: missing preparation`);
    assert(!/ядерную бомбу|Двойной штамм|мелкую китайскую|Наполните стакан камнями|пищевой мукой|масло и подавайте|воздушный шар/.test(`${c.description} ${c.preparationSteps.join(' ')}`), `${label}: known mistranslation`);
    assert(!c.preparationSteps.some(s => /^(?:step|шаг)\s*\d+$/i.test(s.trim())), `${label}: empty step label`);
    for (const id of c.ingredients) {
      entries++;
      assert(ingredientIds.has(id), `${label}: unknown ingredient ${id}`);
      const amount = (c.ingredientAmounts[id] || '').trim();
      const unit = (c.ingredientUnits[id] || '').trim();
      assert(amount, `${label}/${id}: missing measure`);
      assert(!numeric.test(amount) || unit, `${label}/${id}: numeric measure without unit`);
      assert(!unit || units.has(unit), `${label}/${id}: unsupported unit ${unit}`);
      if (!numeric.test(amount)) variableMeasures++;
    }
    for (const field of ['ingredientAmounts','ingredientUnits','ingredientSubstitutions']) {
      for (const id of Object.keys(c[field] || {})) assert(c.ingredients.includes(id), `${label}: orphan ${field}/${id}`);
    }
    for (const field of ['optionalIngredients','decorationIngredients']) {
      for (const id of c[field]) assert(c.ingredients.includes(id), `${label}: orphan ${field}/${id}`);
    }
    if (c.sourceMetadata.recipeSourceUrl) {
      assert.equal(new URL(c.sourceMetadata.recipeSourceUrl).protocol, 'https:', `${label}: source URL`);
      sourceReferenced++;
    }
    assert(fs.existsSync(c.image), `${label}: missing offline image ${c.image}`);
  }
  for (const ingredient of catalog.ingredients) assert(fs.existsSync(ingredient.image), `${context}: missing image ${ingredient.id}`);
  stats.push({catalog:context, recipes:recipeIds.size, ingredients:ingredientIds.size, entries, variableMeasures, sourceReferenced});
}

assert.deepEqual(catalogs[0].ingredients.map(i => i.id), catalogs[1].ingredients.map(i => i.id), 'EN/RU ingredient ID parity');
assert.deepEqual(catalogs[0].cocktails.map(c => c.id), catalogs[1].cocktails.map(c => c.id), 'EN/RU recipe ID parity');
for (const [index, en] of catalogs[0].cocktails.entries()) {
  const ru = catalogs[1].cocktails[index];
  for (const field of ['ingredients','ingredientUnits','optionalIngredients','decorationIngredients']) assert.deepEqual(en[field], ru[field], `${en.id}: EN/RU ${field}`);
  for (const id of en.ingredients) if (numeric.test(en.ingredientAmounts[id])) assert.equal(en.ingredientAmounts[id], ru.ingredientAmounts[id], `${en.id}/${id}: EN/RU numeric quantity`);
}
console.log(JSON.stringify({status:'passed',stats}, null, 2));
