#!/usr/bin/env python3
"""Regenerate bundled catalog text overlays (development only, never at runtime).

No account, paid API, or application server is needed. Existing translations are
cached locally so an editorial correction only retranslates changed source text.
Run after editing the English catalog, then review the generated translations.
"""

import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import re
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCALES = "es pt de fr it tr zh ja ko hi ar".split()
ENDPOINT = "https://clients5.google.com/translate_a/t"


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


def localize(locale, catalog, texts, cache_folder):
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
        "sourceTextSha256": hashlib.sha256(
            json.dumps(texts, ensure_ascii=False, separators=(",", ":")).encode()
        ).hexdigest(),
        "sourceTextChecksum": source_checksum(texts),
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
    write_json(ROOT / "assets/data/catalog_localizations" / (locale + ".json"), overlay)
    print(f"{locale}: {len(overlay['cocktails'])} recipes, {len(overlay['ingredients'])} ingredients", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", nargs="+", default=LOCALES, choices=LOCALES)
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()
    catalog = json.loads((ROOT / "assets/data/bar_template.json").read_text())
    texts = source_texts(catalog)
    cache_folder = ROOT / ".dart_tool/catalog_translation_cache"
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(localize, locale, catalog, texts, cache_folder) for locale in args.locales]
        for future in concurrent.futures.as_completed(futures):
            future.result()


if __name__ == "__main__":
    main()
