"""Offline regression checks for reviewed catalog copy."""

import copy
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

import localize_catalog as catalog_tool


def reviewed_fixture():
    locales = catalog_tool.LOCALES
    catalog = {
        "ingredients": [
            {"id": "orange", "name": "Orange"},
            {"id": "other", "name": "Orange"},
        ],
        "cocktails": [{
            "id": "demo",
            "name": "Sample",
            "description": "Build in glass.",
            "preparationSteps": ["Fill the glass."],
            "ingredientAmounts": {"orange": "1", "water": "Top up"},
        }],
    }
    reviewed = {
        "locales": locales,
        "names": {
            "ingredients": {"orange": [f"fruit-{code}" for code in locales]},
            "cocktails": {"demo": "@source"},
        },
        "amounts": {"Top up": [f"fill-{code}" for code in locales]},
        "recipes": {"demo": {"es": {"preparationSteps": {"0": "Llena el vaso."}}}},
    }
    return catalog, reviewed


class ReviewedCatalogTest(unittest.TestCase):
    def test_committed_overlays_match_reviews_without_writes_or_network(self):
        catalog = json.loads((catalog_tool.DATA / "bar_template.json").read_text(encoding="utf-8"))
        reviewed = json.loads(catalog_tool.REVIEWED.read_text(encoding="utf-8"))
        catalog_tool.validate_reviewed(reviewed, catalog)
        with (
            patch.object(catalog_tool, "translate", side_effect=AssertionError("network")),
            patch.object(catalog_tool, "write_json", side_effect=AssertionError("write")),
        ):
            catalog_tool.reviewed_overlays(
                catalog_tool.LOCALES, catalog, reviewed, check=True)
        for locale in catalog_tool.LOCALES:
            with self.subTest(locale=locale):
                data = json.loads((catalog_tool.OVERLAYS / f"{locale}.json").read_text(
                    encoding="utf-8"))
                names = data["ingredients"]
                self.assertNotEqual(names["ginger_ale"]["name"], names["ginger_beer"]["name"])
                self.assertNotEqual(names["grape_juice"]["name"], names["juice_grapefruit"]["name"])
                self.assertNotEqual(names["fresh_lemon_juice"]["name"], names["fresh_lime_juice"]["name"])
                self.assertNotEqual(data["cocktails"]["scotch-sour"]["name"],
                                    data["cocktails"]["whiskey-sour"]["name"])

    def test_catalog_terms_use_food_or_drink_meaning(self):
        examples = {
            "tr": ("orange", "Portakal"),
            "ar": ("orange", "برتقال"),
            "ko": ("orange", "오렌지"),
            "fr": ("mountain_dew", "Mountain Dew"),
            "zh": ("southern_comfort", "Southern Comfort"),
        }
        for locale, (item, name) in examples.items():
            with self.subTest(locale=locale, item=item):
                data = json.loads((catalog_tool.OVERLAYS / f"{locale}.json").read_text(
                    encoding="utf-8"))
                self.assertEqual(data["ingredients"][item]["name"], name)
        ar = json.loads((catalog_tool.OVERLAYS / "ar.json").read_text(encoding="utf-8"))
        self.assertEqual(ar["cocktails"]["cuba-libre"]["ingredientAmounts"]["coca_cola"],
                         "أكمل ملء الكأس")

    def test_regular_regeneration_preserves_editorial_reviews(self):
        catalog, reviewed = reviewed_fixture()
        texts = catalog_tool.source_texts(catalog)
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp)
            cache = {text: f"machine-{text}" for text in texts}
            catalog_tool.write_json(path / "es.json", cache)
            output = path / "output"
            with (
                patch.object(catalog_tool, "OVERLAYS", output),
                patch.object(catalog_tool, "translate", side_effect=AssertionError("network")),
            ):
                catalog_tool.localize("es", catalog, texts, path, reviewed)
            overlay = json.loads((output / "es.json").read_text(encoding="utf-8"))
        self.assertEqual(overlay["ingredients"]["orange"]["name"], "fruit-es")
        self.assertEqual(overlay["ingredients"]["other"]["name"], "machine-Orange")
        drink = overlay["cocktails"]["demo"]
        self.assertEqual(drink["name"], "Sample")
        self.assertEqual(drink["ingredientAmounts"], {"water": "fill-es"})
        self.assertEqual(drink["preparationSteps"], ["Llena el vaso."])

    def test_offline_source_update_only_accepts_reviewed_renames(self):
        previous, reviewed = reviewed_fixture()
        renamed = copy.deepcopy(previous)
        renamed["ingredients"][0]["name"] = "Orange fruit"
        catalog_tool.validate_offline_rename(previous, renamed, reviewed)
        renamed["ingredients"][1]["name"] = "Different product"
        with self.assertRaisesRegex(ValueError, "Not a fully reviewed source rename"):
            catalog_tool.validate_offline_rename(previous, renamed, reviewed)
        renamed = copy.deepcopy(previous)
        renamed["cocktails"][0]["description"] = "Untranslated new instruction."
        with self.assertRaisesRegex(ValueError, "Not a fully reviewed source rename"):
            catalog_tool.validate_offline_rename(previous, renamed, reviewed)

    def test_bad_review_data_cannot_change_structure_or_omit_a_locale(self):
        catalog, reviewed = reviewed_fixture()
        bad = copy.deepcopy(reviewed)
        bad["recipes"]["demo"]["es"]["preparationSteps"] = {"7": "Invalid step"}
        with self.assertRaisesRegex(ValueError, "Invalid reviewed recipe field"):
            catalog_tool.validate_reviewed(bad, catalog)
        bad = copy.deepcopy(reviewed)
        bad["amounts"]["Top up"].pop()
        with self.assertRaisesRegex(ValueError, "one reviewed text per locale"):
            catalog_tool.validate_reviewed(bad, catalog)
        bad = copy.deepcopy(reviewed)
        del bad["amounts"]["Top up"]
        with self.assertRaisesRegex(ValueError, "Missing reviewed amount phrases"):
            catalog_tool.validate_reviewed(bad, catalog)


if __name__ == "__main__":
    unittest.main()
