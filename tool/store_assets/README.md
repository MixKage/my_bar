# Store assets: offline generation and manual publishing

This tool prepares assets; it never signs in to a store, changes store metadata,
or uploads anything. Publishing remains a separate, manual review step.
The only network command is an explicit `prepare-fonts`, which downloads free,
SHA-256-pinned fonts from their official GitHub repositories to an ignored cache.
All captures and exports then work locally without paid services or a server.

## First run

Requirements: the project's Flutter SDK/dependencies, Python 3.10+, and Pillow.
Run Flutter dependency setup once before going offline. Install Pillow into your
preferred Python environment; no additional Python packages are required.

```sh
python3 -m venv .dart_tool/store_assets/venv
. .dart_tool/store_assets/venv/bin/activate
python3 -m pip install -r tool/store_assets/requirements.txt
python3 tool/store_assets/store_assets.py prepare-fonts
python3 tool/store_assets/store_assets.py check-fonts
python3 tool/store_assets/store_assets.py list
python3 tool/store_assets/store_assets.py plan --languages en,ru,ar --devices iphone-large,iphone-duo-inner
```

Font sources, hashes, licenses, and cache locations are recorded next to this
tool. `prepare-fonts` reuses matching cached files and atomically repairs only
known font-cache files; it cannot write elsewhere. If you already have the
matching cache, skip this download step. Font binaries are not bundled into
the shipping app by this workflow.

## Capture screenshots

```sh
python3 tool/store_assets/store_assets.py capture --languages en,ru --devices iphone-large
python3 tool/store_assets/store_assets.py validate --kind screenshots --languages en,ru --devices iphone-large
python3 tool/store_assets/store_assets.py package --kind screenshots --languages en,ru --devices iphone-large
```

Omit `--languages` and `--devices` to generate the complete configured matrix:
13 languages × 5 viewports × 6 screens = 390 PNGs. Use `plan --json` to inspect
every output path first. `--output` defaults to `build/store-assets`; use a
dedicated output directory for other destinations. Do not run another Flutter
test or build while capture is running, because Flutter shares generated assets.

Existing selected image files are refused unless `--overwrite` is supplied.
Overwriting replaces only those files; no directory tree is deleted, and
unselected captures are retained in the merged capture manifest. A failed run
retains completed PNGs; repeat the same selection with `--overwrite`.

The capture test uses actual app widgets and deterministic local fixture data.
Each viewport is rendered independently at its physical pixel dimensions and
pixel ratio. It does not stretch screenshots from another device. Source
screens: ingredients at home, cocktail menu, recipe/portions, party planner,
smart shopping, and surprise me.

Output:

```text
build/store-assets/
  screenshots/<App Store locale>/<device ID>/01-ingredients.png ... 06-surprise.png
  capture-manifest.json
  my-bar-screenshots.zip
  my-bar-screenshots-manifest.json
```

PNG outputs are opaque RGB. The renderer is `flutter-widget`, **not** a native
simulator or physical-device capture: OS status bars, exact hardware safe-area
geometry, keyboard, native dialogs, and fold transitions are not certified by
this test. Safe areas in the config are explicit test fixtures in logical
Flutter units. The iPhone Duo profiles reproduce Apple's accepted screenshot
pixel sizes; they are not a claim that an iPhone Duo simulator is installed.
Review screenshots against the real app on relevant devices before upload.
Do not substitute invented/mock UI or unsupported app features in store images.

## Languages and devices

`config.json` maps app codes `en,ru,es,pt,de,fr,it,tr,zh,ja,ko,hi,ar` to their
App Store and Google Play locale IDs separately. Arabic captures use RTL. The
Google Play mappings are available for reuse, but the current viewport profiles
capture iOS layouts; do not label them Android-device screenshots.

| Device ID | Portrait PNG size | Pixel ratio |
| --- | --- | --- |
| `iphone-medium` | 1206 × 2622 | 3 |
| `iphone-large` | 1320 × 2868 | 3 |
| `ipad-13` | 2064 × 2752 | 2 |
| `iphone-duo-outer` | 1398 × 2034 | 3 |
| `iphone-duo-inner` | 2007 × 2853 | 3 |

For a new viewport, add a new device ID with physical `width`/`height`,
`pixelRatio`, and logical `safeArea` insets rather than resizing old images.
`--config /absolute/path/config.json` permits a separate reviewed profile.

## App Store Header and Search Results

Use one approved, text-free PNG artwork source with the key subject close to
the center. This is marketing artwork, not an app screenshot. Export performs
only mechanical focal-point cropping, Lanczos resizing and RGB conversion:

```sh
python3 tool/store_assets/store_assets.py export-creatives --source tool/store_assets/artwork/cocktails-master.png --focal-point 0.5,0.417
python3 tool/store_assets/store_assets.py validate --kind creatives
python3 tool/store_assets/store_assets.py package --kind creatives
```

| Asset | PNG size | Important-content safe rectangle (x, y, width, height) |
| --- | --- | --- |
| Header | 3840 × 1646 | 1097, 493, 1646, 661 |
| Search Results | 3840 × 2560 | 836, 765, 2168, 1030 |
| Universal | 5244 × 2950 | 1921, 660, 1402, 962 |

The normalized source focal point defaults to the image center (`0.5,0.5`).
The committed My Bar artwork uses `0.5,0.417`; its built-in image-generation
prompt set and export settings are saved in `artwork/provenance.json`.
The crop tries to place that point at each safe rectangle's center, constrained
by the source image edges; it never adds blank borders. The actual resulting
focal coordinates are recorded in the manifest. This does not guarantee that
the entire subject fits the safe rectangle. Inspect `review-guides/*-safe-area.png`
(green rectangle, pink focal cross) and Apple's overlays manually. Review guides
are **not upload assets** and are deliberately excluded from ZIP packages.
Avoid small text, UI screenshots, device frames, or logos
near crop edges. The tool does not paint captions, badges, or fabricated UI.
The same three text-free files serve all 13 locales; `creative-manifest.json`
maps every selected App Store locale to the shared PNGs without duplicates.

Output: `creatives/header.png`, `creatives/search-results.png`,
`creatives/universal.png`, `creative-manifest.json`, and optional
`my-bar-creatives.zip` plus its SHA-256 manifest.

The **Product Page Information** section in App Store Connect also contains
metadata fields; artwork does not replace translations of those fields.
Do not upload an SVG copied from the web form: these image outputs are PNGs.

## Validation and reproducibility

```sh
python3 -m unittest discover -s tool/store_assets -p 'test_*.py'
python3 tool/store_assets/store_assets.py validate --kind all
python3 tool/store_assets/store_assets.py package --kind all
```

Validation checks presence, PNG decoding, exact physical dimensions, and opaque
RGB mode. It does not certify translations, native-device rendering, artistic
quality, or store acceptance. Packages include a file list with byte sizes and
SHA-256 hashes, plus separate App Store/Google Play locale mappings. Existing
`capture-manifest.json` and/or `creative-manifest.json` are included for the
selected asset kind, with their own paths and hashes under `metadata`. Image
counts are separate from metadata counts. Screenshot entries explicitly retain
the offscreen renderer, non-native-device status, and offline font-fixture
provenance. A capture index may describe additional captures outside the selected
ZIP subset; the package's `files` list is the definitive set of included images.
ZIP entry
timestamps are fixed so unchanged inputs produce the same package hash.
`package` also refuses overwriting unless explicitly requested.

Official references (verify again before upload if requirements change):

- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Apple asset best practices](https://developer.apple.com/app-store/asset-best-practices/)
- [Apple creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)
- [Apple design templates (Sketch)](https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-templates.sketch)

iPhone Duo screenshots are optional as of the specification review on
2026-10-19. Apple requires them starting in April 2027 for apps built with
iOS 27.1 SDK or later; check the screenshot specification again at submission.

No credentials, signing keys, store API tokens, or upload endpoints are used.
