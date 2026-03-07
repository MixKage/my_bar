# Catalog Snapshot Builder

Standalone utility for generating an **app-compatible local catalog snapshot** (`ingredients + cocktails`) for My Bar.

The utility is designed for an offline-first runtime model:
- external API is used **only at build/import time**,
- runtime app works from a prebuilt local JSON,
- images are stored as **URL only** (no binary image download/bundling).

## What It Does

Pipeline:

`external source data -> parsing -> normalization -> canonical mapping -> validation -> dedupe -> export JSON`

Output JSON is compatible with the app seed format and can be used directly by the built-in JSON provider.

## Entrypoint

Run from repository root:

```bash
dart run tool/catalog_snapshot_builder/build_bar_catalog_snapshot.dart --print-summary --pretty
```

## CLI Options

- `--source=<thecocktaildb|seed|http-json>`: import source (default `thecocktaildb`)
- `--output=<path>`: output snapshot path (default `assets/data/bar_template.json`)
- `--template=<path>`: template JSON for canonical mapping baseline (default `assets/data/bar_template.json`)
- `--seed-input=<path>`: input for `--source=seed` (default `assets/data/bar_template.json`)
- `--base-url=<url>`: base URL for source (`thecocktaildb` override or `http-json`)
- `--api-key=<key>`: TheCocktailDB API key (default `1`)
- `--pretty`: pretty-print output JSON
- `--dry-run`: run without writing output file
- `--strict`: drop cocktails with unresolved ingredient references
- `--fail-on-unresolved-mapping`: fail build if unresolved ingredient mappings exist
- `--print-summary`: print import and validation summary
- `--help`: show help

## Examples

Build from TheCocktailDB into main app seed file:

```bash
dart run tool/catalog_snapshot_builder/build_bar_catalog_snapshot.dart \
  --source=thecocktaildb \
  --api-key=1 \
  --output=assets/data/bar_template.json \
  --pretty \
  --print-summary
```

Dry-run validation without writing:

```bash
dart run tool/catalog_snapshot_builder/build_bar_catalog_snapshot.dart \
  --dry-run \
  --print-summary
```

Build from existing seed file (re-normalization check):

```bash
dart run tool/catalog_snapshot_builder/build_bar_catalog_snapshot.dart \
  --source=seed \
  --seed-input=assets/data/bar_template.json \
  --dry-run \
  --strict \
  --print-summary
```

## Output Format

Top-level structure:

```json
{
  "metadata": { "...": "..." },
  "ingredients": [ ... ],
  "cocktails": [ ... ]
}
```

Compatibility notes:
- app runtime loader uses `ingredients` and `cocktails`,
- extra fields (`metadata`, `source`, `sourceId`, `canonicalSlug`, `aliases`, etc.) are preserved for tooling/debugging,
- unknown extra fields do not break runtime parsing.

## Validation and Dedupe

During build:
- source-level dedupe by `sourceId`,
- deterministic IDs/canonical keys via existing app utilities,
- reference validation (`cocktail.ingredients` must exist in ingredient set),
- invalid cocktail drop accounting,
- unresolved mapping accounting.

Summary includes:
- imported ingredients count,
- imported cocktails count,
- invalid cocktails dropped,
- unresolved ingredient mappings,
- duplicates removed.

## Canonical Mapping Strategy

The utility reuses current app mapping/normalization logic:
- `IngredientCanonicalMapper`
- TheCocktailDB normalizer + explicit mapping dictionary
- stable key utilities (`normalizeKey`, `slugify`, `canonicalFromValue`)

When exact internal key mapping is not found:
- a safe canonical slug is generated,
- source name and source IDs are retained in exported metadata fields.

## Integration With App Runtime

Recommended flow:
1. Run utility in CI/local build.
2. Commit generated snapshot JSON.
3. App uses this JSON as built-in catalog seed.

This keeps runtime independent from external API availability.

## Limitations

- Ingredient aliases are stored only in snapshot metadata fields; runtime models keep canonical fields.
- External source quality affects normalization quality (especially measure parsing).
- TheCocktailDB free API limitations still apply at snapshot build time.
