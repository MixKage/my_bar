"""Offline checks for the human-reviewed Google Play 1.2.0 listing copy."""

import json
from pathlib import Path
import unittest


METADATA_PATH = Path(__file__).with_name("google_play_metadata_1.2.0.json")
REPO_ROOT = Path(__file__).resolve().parents[2]
EXPECTED_LOCALES = {
    "en": "en-US",
    "ru": "ru-RU",
    "es": "es-ES",
    "pt": "pt-BR",
    "de": "de-DE",
    "fr": "fr-FR",
    "it": "it-IT",
    "tr": "tr-TR",
    "zh": "zh-CN",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "hi": "hi-IN",
    "ar": "ar",
}


class GooglePlayMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.metadata = json.loads(METADATA_PATH.read_text(encoding="utf-8"))
        cls.localizations = cls.metadata["localizations"]

    def test_schema_and_version(self):
        self.assertEqual(self.metadata["schemaVersion"], 1)
        self.assertEqual(self.metadata["version"], "1.2.0")
        self.assertIsInstance(self.localizations, list)

    def test_all_thirteen_languages_have_unique_correct_play_locales(self):
        self.assertEqual(len(self.localizations), 13)
        self.assertEqual(
            len({entry["language"] for entry in self.localizations}), 13
        )
        self.assertEqual(
            len({entry["googlePlayLocale"] for entry in self.localizations}), 13
        )
        self.assertEqual(
            {
                entry["language"]: entry["googlePlayLocale"]
                for entry in self.localizations
            },
            EXPECTED_LOCALES,
        )

    def test_language_coverage_matches_screenshot_configuration(self):
        config = json.loads(
            METADATA_PATH.with_name("config.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            {language["code"] for language in config["languages"]},
            set(EXPECTED_LOCALES),
        )
        self.assertEqual(
            {
                language["code"]: language["googlePlayLocale"]
                for language in config["languages"]
            },
            EXPECTED_LOCALES,
        )

    def test_text_is_nonempty_trimmed_and_within_both_character_limits(self):
        for entry in self.localizations:
            for field, maximum in (
                ("title", 30),
                ("shortDescription", 80),
                ("fullDescription", 4000),
            ):
                with self.subTest(locale=entry["googlePlayLocale"], field=field):
                    value = entry[field]
                    self.assertIsInstance(value, str)
                    self.assertTrue(value)
                    self.assertEqual(value, value.strip())
                    self.assertLessEqual(len(value), maximum)
                    self.assertLessEqual(
                        len(value.encode("utf-16-le")) // 2, maximum
                    )
                    self.assertNotRegex(value, r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
                    if field != "fullDescription":
                        self.assertNotIn("\n", value)
                        self.assertNotIn("\r", value)

    def test_catalog_size_claims_match_the_shipping_catalog(self):
        catalog = json.loads(
            (REPO_ROOT / "assets/data/bar_template.json").read_text(
                encoding="utf-8"
            )
        )
        for entry in self.localizations:
            with self.subTest(locale=entry["googlePlayLocale"]):
                # Digit boundaries also work for Chinese and Japanese, where
                # there need not be spaces around the numeric claims.
                for collection in ("cocktails", "ingredients"):
                    count = len(catalog[collection])
                    self.assertRegex(
                        entry["fullDescription"], rf"(?<!\d){count}(?!\d)"
                    )
                self.assertRegex(entry["fullDescription"], r"(?<!\d)13(?!\d)")

    def test_copy_has_no_obsolete_developer_domain(self):
        # Keep the superseded host out of tracked text as well as live URLs.
        obsolete_host = ".".join(("logion-mobile", "com"))
        self.assertNotIn(
            obsolete_host,
            json.dumps(self.metadata, ensure_ascii=False).lower(),
        )


if __name__ == "__main__":
    unittest.main()
