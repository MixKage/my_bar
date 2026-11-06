#!/usr/bin/env python3
"""Regenerate bundled catalog text overlays (development only, never at runtime).

No account, paid API, or application server is needed. Existing translations are
cached locally so an editorial correction only retranslates changed source text.
Run after editing the English catalog, then review the generated translations.
Reviewed corrections live in catalog_translation_overrides.json and are always
applied last. Use --apply-reviewed or --check-reviewed to work offline.
"""

import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCALES = "es pt de fr it tr zh ja ko hi ar".split()
ENDPOINT = "https://clients5.google.com/translate_a/t"
DATA = ROOT / "assets/data"
OVERLAYS = DATA / "catalog_localizations"
REVIEWED = pathlib.Path(__file__).with_name("catalog_translation_overrides.json")
SECTIONS = ("ingredients", "cocktails")


def source_texts(catalog):
    values = []
    for item in catalog["ingredients"]:
        values.append(item["name"])
    for item in catalog["cocktails"]:
        values.extend([item["name"], item["description"], *item["preparationSteps"]])
        values.extend(
            value for value in item.get("ingredientAmounts", {}).values()
            if re.search(r"[A-Za-z]", value)
        )
    return list(dict.fromkeys(value for value in values if value.strip()))


def source_checksum(texts):
    value = 2166136261
    for byte in json.dumps(texts, ensure_ascii=False, separators=(",", ":")).encode():
        value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
    return format(value, "08x")


def source_hashes(catalog):
    texts = source_texts(catalog)
    return {
        "sourceTextSha256": hashlib.sha256(
            json.dumps(texts, ensure_ascii=False, separators=(",", ":")).encode()
        ).hexdigest(),
        "sourceTextChecksum": source_checksum(texts),
    }


def validate_reviewed(reviewed, catalog):
    """Reject incorrect IDs, locales and fields before any overlay is written."""
    if set(reviewed) != {"locales", "names", "amounts", "recipes"}:
        raise ValueError("Unexpected reviewed translation sections")
    if reviewed["locales"] != LOCALES or set(reviewed["names"]) != set(SECTIONS):
        raise ValueError("Reviewed translation locales or name sections do not match")

    def valid_text(text):
        return isinstance(text, str) and bool(text.strip())

    def validate_row(row):
        if (not isinstance(row, list) or len(row) != len(LOCALES)
                or not all(valid_text(value) for value in row)):
            raise ValueError(f"Expected one reviewed text per locale: {row!r}")

    by_id = {section: {item["id"]: item for item in catalog[section]}
             for section in SECTIONS}
    for section, items in reviewed["names"].items():
        for item_id, row in items.items():
            if item_id not in by_id[section]:
                raise ValueError(f"Unknown reviewed {section} ID: {item_id}")
            if row != "@source":
                validate_row(row)
    text_amounts = {
        value
        for item in catalog["cocktails"]
        for value in item.get("ingredientAmounts", {}).values()
        if re.search(r"[A-Za-z]", value)
    }
    missing_amounts = text_amounts - reviewed["amounts"].keys()
    if missing_amounts:
        raise ValueError(f"Missing reviewed amount phrases: {sorted(missing_amounts)!r}")
    for row in reviewed["amounts"].values():
        validate_row(row)
    for item_id, patches in reviewed["recipes"].items():
        if item_id not in by_id["cocktails"]:
            raise ValueError(f"Unknown reviewed recipe ID: {item_id}")
        source = by_id["cocktails"][item_id]
        for locale, fields in patches.items():
            if locale not in LOCALES:
                raise ValueError(f"Unknown reviewed recipe locale: {locale}")
            for key, value in fields.items():
                if key == "description" and valid_text(value):
                    continue
                if key == "preparationSteps" and isinstance(value, dict) and all(
                        index.isascii() and index.isdigit() and int(index) < len(source[key])
                        and valid_text(text) for index, text in value.items()):
                    continue
                raise ValueError(f"Invalid reviewed recipe field: {locale}/{item_id}/{key}")


def apply_reviewed(locale, catalog, overlay, reviewed):
    """Apply approved copy without changing recipe structure or numeric doses."""
    index = LOCALES.index(locale)
    for section in SECTIONS:
        names = reviewed["names"][section]
        for item in catalog[section]:
            item_id = item["id"]
            patch = overlay[section][item_id]
            if item_id in names:
                row = names[item_id]
                patch["name"] = item["name"] if row == "@source" else row[index]
            if section != "cocktails":
                continue
            for ingredient, amount in item.get("ingredientAmounts", {}).items():
                if amount in reviewed["amounts"]:
                    patch.setdefault("ingredientAmounts", {})[ingredient] = (
                        reviewed["amounts"][amount][index])
            for key, value in reviewed["recipes"].get(item_id, {}).get(locale, {}).items():
                if key == "preparationSteps":
                    for step, text in value.items():
                        patch[key][int(step)] = text
                else:
                    patch[key] = value


def validate_offline_rename(previous, current, reviewed):
    """Refresh hashes offline only for name changes covered in every locale."""
    for section in SECTIONS:
        before, after = previous[section], current[section]
        if [item["id"] for item in before] != [item["id"] for item in after]:
            raise ValueError(f"IDs changed in {section}; regenerate full translations")
        # Categories are shared tokens translated by the UI, not these overlays.
        editable = {"name", "displayName"}
        if section == "ingredients":
            editable.add("category")
        for old, new in zip(before, after):
            if old == new:
                continue
            item_id = new["id"]
            if item_id not in reviewed["names"][section] or any(
                    old.get(key) != new.get(key)
                    for key in (old.keys() | new.keys()) - editable):
                raise ValueError(f"Not a fully reviewed source rename: {section}/{item_id}")


def reviewed_overlays(locales, catalog, reviewed, *, check, previous=None):
    expected_hashes = source_hashes(catalog)
    previous_hashes = source_hashes(previous) if previous is not None else expected_hashes
    if previous is not None:
        validate_offline_rename(previous, catalog, reviewed)
    updates = []
    for locale in locales:
        path = OVERLAYS / (locale + ".json")
        original = path.read_text(encoding="utf-8")
        overlay = json.loads(original)
        actual_hashes = {key: overlay.get(key) for key in expected_hashes}
        if actual_hashes not in [previous_hashes, expected_hashes]:
            raise ValueError(f"{locale}: stale source hashes; provide the prior source or regenerate")
        if overlay["locale"] != locale or any(
                list(overlay[section]) != [item["id"] for item in catalog[section]]
                for section in SECTIONS):
            raise ValueError(f"{locale}: catalog IDs do not match the overlay")
        if any(len(overlay["cocktails"][item["id"]]["preparationSteps"]) !=
               len(item["preparationSteps"]) for item in catalog["cocktails"]):
            raise ValueError(f"{locale}: recipe step counts do not match")
        apply_reviewed(locale, catalog, overlay, reviewed)
        overlay.update(expected_hashes)
        generated = json.dumps(overlay, ensure_ascii=False, indent=2) + "\n"
        if check and generated != original:
            raise ValueError(f"{locale}: reviewed translations are not current")
        if generated != original:
            updates.append((path, overlay))
    for path, overlay in updates:
        write_json(path, overlay)
    print(f"{len(locales)} reviewed overlays {'verified' if check else 'applied'}")


def batches(texts):
    current, size = [], 0
    for text in texts:
        encoded_size = len(urllib.parse.urlencode({"q": text}))
        if current and (size + encoded_size > 5500 or len(current) == 32):
            yield current
            current, size = [], 0
        current.append(text)
        size += encoded_size
    if current:
        yield current


def translate(locale, texts):
    params = [("client", "dict-chrome-ex"), ("sl", "en"),
              ("tl", "zh-CN" if locale == "zh" else locale)]
    params.extend(("q", text) for text in texts)
    url = ENDPOINT + "?" + urllib.parse.urlencode(params)
    for attempt in range(6):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=40) as response:
                result = json.load(response)
            if len(result) != len(texts) or not all(isinstance(t, str) and t.strip() for t in result):
                raise ValueError("Unexpected translation response")
            return dict(zip(texts, result))
        except Exception:
            if attempt == 5:
                raise
            time.sleep(min(2 ** attempt, 15))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def localize(locale, catalog, texts, cache_folder, reviewed):
    cache_path = cache_folder / (locale + ".json")
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    missing = [text for text in texts if text not in cache]
    groups = list(batches(missing))
    for index, group in enumerate(groups):
        cache.update(translate(locale, group))
        write_json(cache_path, cache)
        if index % 10 == 0 or index == len(groups) - 1:
            print(f"{locale}: {index + 1}/{len(groups)} batches", flush=True)

    overlay = {
        "locale": locale,
        **source_hashes(catalog),
        "ingredients": {item["id"]: {"name": cache[item["name"]]}
                        for item in catalog["ingredients"]},
        "cocktails": {},
    }
    for item in catalog["cocktails"]:
        translated = {
            "name": cache[item["name"]],
            "description": cache[item["description"]],
            "preparationSteps": [cache[text] for text in item["preparationSteps"]],
        }
        amounts = {key: cache[value] for key, value in item.get("ingredientAmounts", {}).items()
                   if re.search(r"[A-Za-z]", value)}
        if amounts:
            translated["ingredientAmounts"] = amounts
        overlay["cocktails"][item["id"]] = translated
    apply_reviewed(locale, catalog, overlay, reviewed)
    write_json(OVERLAYS / (locale + ".json"), overlay)
    print(f"{locale}: {len(overlay['cocktails'])} recipes, {len(overlay['ingredients'])} ingredients", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", nargs="+", default=LOCALES, choices=LOCALES)
    parser.add_argument("--workers", type=int, default=3)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply-reviewed", action="store_true", help="update committed overlays offline")
    mode.add_argument("--check-reviewed", action="store_true", help="verify committed overlays offline")
    parser.add_argument("--previous-source", help="prior English JSON file (or - for stdin) for reviewed renames")
    args = parser.parse_args()
    if args.previous_source and not args.apply_reviewed:
        parser.error("--previous-source requires --apply-reviewed")
    catalog = json.loads((DATA / "bar_template.json").read_text(encoding="utf-8"))
    reviewed = json.loads(REVIEWED.read_text(encoding="utf-8"))
    try:
        validate_reviewed(reviewed, catalog)
        if args.apply_reviewed or args.check_reviewed:
            previous = None
            if args.previous_source:
                previous = (json.load(sys.stdin) if args.previous_source == "-"
                            else json.loads(pathlib.Path(args.previous_source).read_text(encoding="utf-8")))
            reviewed_overlays(args.locales, catalog, reviewed,
                              check=args.check_reviewed, previous=previous)
            return
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    texts = source_texts(catalog)
    cache_folder = ROOT / ".dart_tool/catalog_translation_cache"
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(localize, locale, catalog, texts, cache_folder, reviewed)
                   for locale in args.locales]
        for future in concurrent.futures.as_completed(futures):
            future.result()


if __name__ == "__main__":
    main()
