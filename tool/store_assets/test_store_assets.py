"""Offline regression tests. Never invokes Flutter, downloads or uploads."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

from PIL import Image

MODULE_PATH = Path(__file__).with_name("store_assets.py")
SPEC = importlib.util.spec_from_file_location("store_assets", MODULE_PATH)
assets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)


class StoreAssetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.output = self.root / "output"
        self.config = assets.load_config(MODULE_PATH.with_name("config.json"))
        self.languages = self.config["languages"][:2]
        self.devices = self.config["devices"][:1]

    def small_config(self):
        result = copy.deepcopy(self.config)
        for creative in result["creatives"]:
            creative.update(width=120, height=80, safeRect={"x": 30, "y": 20, "width": 60, "height": 40})
        for device in result["devices"]:
            device.update(width=60, height=100)
        return result

    def create_source(self):
        path = self.root / "source.png"
        Image.new("RGBA", (200, 200), (11, 22, 33, 255)).save(path)
        return path

    def test_all_languages_and_device_dimensions(self):
        self.assertEqual(len(self.config["languages"]), 13)
        self.assertEqual(len({lang["appStoreLocale"] for lang in self.config["languages"]}), 13)
        devices = {device["id"]: (device["width"], device["height"]) for device in self.config["devices"]}
        self.assertEqual(devices["iphone-duo-outer"], (1398, 2034))
        self.assertEqual(devices["iphone-duo-inner"], (2007, 2853))
        self.assertEqual(len(assets.shot_entries(self.config, self.config["languages"], self.config["devices"])), 390)

    def test_locale_mapping_does_not_reuse_play_codes(self):
        mapping = {lang["code"]: lang for lang in self.config["languages"]}
        self.assertEqual(mapping["ru"]["appStoreLocale"], "ru")
        self.assertEqual(mapping["ru"]["googlePlayLocale"], "ru-RU")
        self.assertEqual(mapping["zh"]["appStoreLocale"], "zh-Hans")
        self.assertEqual(mapping["ar"]["direction"], "rtl")

    def test_selection_rejects_unknown_and_empty(self):
        self.assertEqual([lang["code"] for lang in assets.select(self.config["languages"], "ar,en,ar", "code", "languages")], ["ar", "en"])
        for value in ("xx", ", ,"):
            with self.assertRaises(assets.AssetError):
                assets.select(self.config["languages"], value, "code", "languages")

    def test_default_selection_rejects_all_disabled(self):
        for items, identity in ((self.config["languages"], "code"), (self.config["devices"], "id")):
            disabled = [{**item, "enabled": False} for item in items]
            with self.assertRaisesRegex(assets.AssetError, "No enabled"):
                assets.select(disabled, None, identity, "entries")

    def test_output_rejects_broad_roots_and_symlinks(self):
        for path in (Path("/"), Path.home(), assets.REPO_ROOT, assets.SCRIPT_DIR):
            with self.assertRaises(assets.AssetError):
                assets.safe_output(path)
        link = self.root / "link"
        link.symlink_to(self.output, target_is_directory=True)
        with self.assertRaises(assets.AssetError):
            assets.safe_output(link / "child")

    def test_target_rejects_traversal_and_symlinks(self):
        self.output.mkdir()
        (self.output / "creatives").symlink_to(self.root, target_is_directory=True)
        for path in ("../escape.png", "/escape.png", "creatives/escape.png"):
            with self.assertRaises(assets.AssetError):
                assets.target_file(self.output, path)

    def test_bad_config_dimensions_duplicate_and_path(self):
        for mutation in (lambda cfg: cfg["devices"][0].update(width=-1), lambda cfg: cfg["languages"][0].update(appStoreLocale="../en"), lambda cfg: cfg["languages"].append(cfg["languages"][0])):
            config = copy.deepcopy(self.config)
            mutation(config)
            path = self.root / "bad.json"
            path.write_text(json.dumps(config))
            with self.assertRaises(assets.AssetError):
                assets.load_config(path)

    def test_bad_config_locale_type_and_nonfinite_pixel_ratio(self):
        mutations = [lambda cfg: cfg["languages"][0].update(appStoreLocale=123)]
        mutations.extend(lambda cfg, ratio=ratio: cfg["devices"][0].update(pixelRatio=ratio) for ratio in (float("nan"), float("inf"), float("-inf"), True, "3"))
        for mutation in mutations:
            config = copy.deepcopy(self.config)
            mutation(config)
            path = self.root / "bad.json"
            path.write_text(json.dumps(config))
            with self.assertRaises(assets.AssetError):
                assets.load_config(path)

    def test_export_rgb_dimensions_and_shared_locale_references(self):
        config = self.small_config()
        result = assets.export_creatives(config, self.output, self.languages, self.create_source(), False)
        self.assertEqual(result["creatives"], 3)
        manifest = json.loads((self.output / "creative-manifest.json").read_text())
        self.assertEqual(manifest["localizations"]["en-US"], manifest["localizations"]["ru"])
        for item in manifest["assets"]:
            path = self.output / item["path"]
            assets.verify_image(path, 120, 80)
            self.assertEqual(item["sha256"], assets.digest(path))

    def test_export_refuses_overwrite_and_preserves_unrelated(self):
        config = self.small_config()
        source = self.create_source()
        assets.export_creatives(config, self.output, self.languages, source, False)
        unrelated = self.output / "keep.txt"
        unrelated.write_text("keep")
        with self.assertRaises(assets.AssetError):
            assets.export_creatives(config, self.output, self.languages, source, False)
        assets.export_creatives(config, self.output, self.languages, source, True)
        self.assertEqual(unrelated.read_text(), "keep")

    def test_export_refuses_review_guide_as_source_without_mutation(self):
        config = self.small_config()
        assets.export_creatives(config, self.output, self.languages, self.create_source(), False)
        guide = self.output / "review-guides" / "header-safe-area.png"
        previous_hashes = {path: assets.digest(path) for path in self.output.rglob("*") if path.is_file()}
        with self.assertRaisesRegex(assets.AssetError, "source must be separate"):
            assets.export_creatives(config, self.output, self.languages, guide, True)
        self.assertEqual(previous_hashes, {path: assets.digest(path) for path in self.output.rglob("*") if path.is_file()})

    def test_invalid_source_does_not_create_outputs(self):
        source = self.root / "source.jpg"
        Image.new("RGB", (200, 200)).save(source)
        with self.assertRaises(assets.AssetError):
            assets.export_creatives(self.small_config(), self.output, self.languages, source, False)
        self.assertFalse(self.output.exists())

    def test_validation_rejects_alpha_missing_and_wrong_size(self):
        path = self.root / "image.png"
        with self.assertRaises(assets.AssetError):
            assets.verify_image(path, 10, 10)
        Image.new("RGBA", (10, 10)).save(path)
        with self.assertRaises(assets.AssetError):
            assets.verify_image(path, 10, 10)
        assets.normalize_rgb(path)
        assets.verify_image(path, 10, 10)
        with self.assertRaises(assets.AssetError):
            assets.verify_image(path, 11, 10)

    def test_rgb_trns_is_rejected_and_normalized_to_opaque(self):
        path = self.root / "transparent-rgb.png"
        Image.new("RGB", (10, 10), (10, 20, 30)).save(path, transparency=(10, 20, 30))
        with Image.open(path) as image:
            self.assertEqual(image.mode, "RGB")
            self.assertIn("transparency", image.info)
        with self.assertRaisesRegex(assets.AssetError, "opaque RGB"):
            assets.verify_image(path, 10, 10)
        assets.normalize_rgb(path)
        assets.verify_image(path, 10, 10)
        with Image.open(path) as image:
            self.assertNotIn("transparency", image.info)
            self.assertEqual(image.getpixel((0, 0)), (7, 9, 17))

    def test_package_hash_manifest_and_reproducible_zip(self):
        config = self.small_config()
        assets.export_creatives(config, self.output, self.languages, self.create_source(), False)
        first = assets.package(config, self.output, self.languages, self.devices, "creatives", False)
        with zipfile.ZipFile(first["archive"]) as archive:
            self.assertEqual(len(archive.namelist()), 5)
            manifest = json.loads(archive.read("my-bar-creatives-manifest.json"))
            self.assertFalse(manifest["uploaded"])
            self.assertEqual(manifest["imageCount"], 3)
            self.assertEqual(manifest["metadataCount"], 1)
            self.assertEqual(manifest["metadata"][0]["path"], "creative-manifest.json")
            self.assertEqual(assets.hashlib.sha256(archive.read("creative-manifest.json")).hexdigest(), manifest["metadata"][0]["sha256"])
            for item in manifest["files"]:
                self.assertEqual(assets.hashlib.sha256(archive.read(item["path"])).hexdigest(), item["sha256"])
        with self.assertRaises(assets.AssetError):
            assets.package(config, self.output, self.languages, self.devices, "creatives", False)
        second = assets.package(config, self.output, self.languages, self.devices, "creatives", True)
        self.assertEqual(first["sha256"], second["sha256"])

    def test_screenshot_package_metadata_is_optional_and_preserves_provenance(self):
        config = self.small_config()
        languages, devices = config["languages"][:1], config["devices"][:1]
        for item in assets.shot_entries(config, languages, devices):
            path = self.output / item["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.new("RGB", (item["width"], item["height"])).save(path)
        first = assets.package(config, self.output, languages, devices, "screenshots", False)
        self.assertEqual((first["images"], first["metadata"], first["files"]), (6, 0, 7))
        with zipfile.ZipFile(first["archive"]) as archive:
            manifest = json.loads(archive.read("my-bar-screenshots-manifest.json"))
            self.assertFalse(manifest["provenance"]["nativeDeviceCapture"])
            self.assertIn("offline Noto", manifest["provenance"]["fontFallback"])
            self.assertTrue(all(not image["nativeDeviceCapture"] for image in manifest["files"]))
        assets.save_json(self.output / "capture-manifest.json", {"schemaVersion": 1, "renderer": "flutter-widget", "nativeDeviceCapture": False, "screenshots": []})
        metadata_bytes = (self.output / "capture-manifest.json").read_bytes()
        second = assets.package(config, self.output, languages, devices, "screenshots", True)
        self.assertEqual((second["images"], second["metadata"], second["files"]), (6, 1, 8))
        with zipfile.ZipFile(second["archive"]) as archive:
            self.assertEqual(archive.read("capture-manifest.json"), metadata_bytes)
            manifest = json.loads(archive.read("my-bar-screenshots-manifest.json"))
            self.assertEqual(manifest["metadata"][0]["sha256"], assets.hashlib.sha256(metadata_bytes).hexdigest())
        third = assets.package(config, self.output, languages, devices, "screenshots", True)
        self.assertEqual(second["sha256"], third["sha256"])

    def test_all_package_includes_both_manifests_not_review_guides(self):
        config = self.small_config()
        languages, devices = config["languages"][:1], config["devices"][:1]
        for item in assets.shot_entries(config, languages, devices):
            path = self.output / item["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.new("RGB", (item["width"], item["height"])).save(path)
        assets.save_json(self.output / "capture-manifest.json", {"schemaVersion": 1, "renderer": "flutter-widget", "screenshots": []})
        assets.export_creatives(config, self.output, languages, self.create_source(), False)
        result = assets.package(config, self.output, languages, devices, "all", False)
        self.assertEqual((result["images"], result["metadata"], result["files"]), (9, 2, 12))
        with zipfile.ZipFile(result["archive"]) as archive:
            self.assertEqual(len(archive.namelist()), result["files"])
            self.assertIn("capture-manifest.json", archive.namelist())
            self.assertIn("creative-manifest.json", archive.namelist())
            self.assertFalse(any("review-guides" in name for name in archive.namelist()))

    def test_package_refuses_invalid_present_metadata(self):
        config = self.small_config()
        assets.export_creatives(config, self.output, self.languages, self.create_source(), False)
        (self.output / "creative-manifest.json").write_text("not valid json")
        with self.assertRaisesRegex(assets.AssetError, "invalid metadata"):
            assets.package(config, self.output, self.languages, self.devices, "creatives", False)
        self.assertFalse((self.output / "my-bar-creatives.zip").exists())

    def test_plan_is_read_only(self):
        with contextlib.redirect_stdout(io.StringIO()) as stream:
            code = assets.main(["plan", "--languages", "ru,en", "--devices", "iphone-duo-inner", "--output", str(self.output), "--json"])
        self.assertEqual(code, 0)
        self.assertFalse(self.output.exists())
        result = json.loads(stream.getvalue())
        self.assertEqual(result["screenshots"], 12)

    def test_capture_refuses_existing_before_flutter(self):
        target = self.output / assets.shot_entries(self.config, self.languages, self.devices)[0]["path"]
        target.parent.mkdir(parents=True)
        target.write_bytes(b"existing")
        with mock.patch.object(assets.subprocess, "run") as run:
            with self.assertRaises(assets.AssetError):
                assets.capture(self.config, MODULE_PATH.with_name("config.json"), self.output, self.languages, self.devices, False)
            run.assert_not_called()

    def test_capture_env_selections_and_rgb_normalization(self):
        config = self.small_config()
        languages, devices = config["languages"][:1], config["devices"][:1]
        def fake_capture(command, cwd, env, check):
            self.assertIn("--no-pub", command)
            self.assertEqual(env["STORE_ASSET_LANGUAGES"], "en")
            self.assertEqual(env["STORE_ASSET_DEVICES"], "iphone-medium")
            entries = assets.shot_entries(config, languages, devices)
            for item in entries:
                target = self.output / item["path"]
                target.parent.mkdir(parents=True, exist_ok=True)
                Image.new("RGBA", (item["width"], item["height"]), (1, 2, 3, 255)).save(target)
            assets.save_json(self.output / "capture-manifest.json", {"schemaVersion": 1, "renderer": "flutter-widget", "screenshots": entries})
        with mock.patch.object(assets.subprocess, "run", side_effect=fake_capture):
            result = assets.capture(config, MODULE_PATH.with_name("config.json"), self.output, languages, devices, False)
        self.assertEqual(result["screenshots"], 6)
        assets.validate(config, self.output, languages, devices, "screenshots")

    def test_font_download_rejects_non_pinned_or_untrusted_sources(self):
        path = self.root / "font_sources.json"
        for url, sha in (("http://raw.githubusercontent.com/google/fonts/main/a.ttf", "a" * 64), ("https://evil.example/a.ttf", "a" * 64), ("https://raw.githubusercontent.com/unknown/repo/a.ttf", "a" * 64), ("https://raw.githubusercontent.com/google/fonts/main/a.ttf", "")):
            path.write_text(json.dumps({"schemaVersion": 1, "fonts": [{"family": "Test", "path": "../../.dart_tool/store_assets/fonts/a.ttf", "url": url, "sha256": sha}]}))
            with mock.patch.object(assets, "urlopen") as network:
                with self.assertRaises(assets.AssetError):
                    assets.prepare_fonts(MODULE_PATH.with_name("config.json"), path)
                network.assert_not_called()

    def test_font_download_refuses_paths_outside_exact_cache(self):
        path = self.root / "font_sources.json"
        path.write_text(json.dumps({"schemaVersion": 1, "fonts": [{"family": "Test", "path": "outside.ttf", "url": "https://raw.githubusercontent.com/google/fonts/main/a.ttf", "sha256": "a" * 64}]}))
        with mock.patch.object(assets, "urlopen") as network:
            with self.assertRaises(assets.AssetError):
                assets.prepare_fonts(MODULE_PATH.with_name("config.json"), path)
            network.assert_not_called()

    def test_font_prepare_download_hash_cache_and_atomic_failure(self):
        repo = self.root / "repo"
        tool = repo / "tool" / "store_assets"
        tool.mkdir(parents=True)
        manifest_path = tool / "font_sources.json"
        target = repo / ".dart_tool" / "store_assets" / "fonts" / "Test.ttf"
        content = b"a pinned test font (mock transport only)"
        url = "https://raw.githubusercontent.com/google/fonts/pinned/ofl/test/Test.ttf"
        manifest = {"schemaVersion": 1, "fonts": [{"family": "Test", "path": "../../.dart_tool/store_assets/fonts/Test.ttf", "url": url, "sha256": assets.hashlib.sha256(content).hexdigest()}]}
        manifest_path.write_text(json.dumps(manifest))
        class Response(io.BytesIO):
            def geturl(self):
                return url
        with mock.patch.object(assets, "REPO_ROOT", repo):
            with mock.patch.object(assets, "urlopen", return_value=Response(content)) as network:
                result = assets.prepare_fonts(tool / "config.json")
                self.assertEqual(result["downloaded"], 1)
                network.assert_called_once()
                self.assertEqual(target.read_bytes(), content)
            with mock.patch.object(assets, "urlopen") as network:
                result = assets.prepare_fonts(tool / "config.json")
                self.assertEqual(result["downloaded"], 0)
                network.assert_not_called()
            target.write_bytes(b"old cache is preserved when download is bad")
            with mock.patch.object(assets, "urlopen", return_value=Response(b"wrong bytes")):
                with self.assertRaises(assets.AssetError):
                    assets.prepare_fonts(tool / "config.json")
                self.assertEqual(target.read_bytes(), b"old cache is preserved when download is bad")
                self.assertEqual(list(target.parent.glob("*.download")), [])

    def test_focal_crop_and_review_guides_are_not_packaged(self):
        config = self.small_config()
        for item in config["creatives"]:
            item.update(width=100, height=50, safeRect={"x": 10, "y": 5, "width": 40, "height": 20})
        source = Image.new("RGB", (100, 100))
        cropped, actual = assets.crop_focal(source, config["creatives"][0], (0.5, 0.5))
        self.assertEqual(cropped.size, (100, 50))
        self.assertEqual(actual["x"], 50)
        self.assertEqual(actual["y"], 15)
        assets.export_creatives(config, self.output, self.languages, self.create_source(), False, (0.5, 0.5))
        self.assertEqual(len(list((self.output / "review-guides").glob("*.png"))), 3)
        result = assets.package(config, self.output, self.languages, self.devices, "creatives", False)
        with zipfile.ZipFile(result["archive"]) as archive:
            self.assertFalse(any("review-guides" in name for name in archive.namelist()))

    def test_focal_point_parser_rejects_invalid_numbers(self):
        self.assertEqual(assets.parse_focal_point("0.25, 0.75"), (0.25, 0.75))
        for value in ("nan,0", "2,0", "0.5", "foo,bar", "1,2,3"):
            with self.assertRaises(assets.argparse.ArgumentTypeError):
                assets.parse_focal_point(value)

    def test_config_font_hashes_match_download_manifest(self):
        sources = json.loads(MODULE_PATH.with_name("font_sources.json").read_text())
        self.assertEqual(self.config["fonts"], [{key: font[key] for key in ("family", "path", "sha256")} for font in sources["fonts"]])


if __name__ == "__main__":
    unittest.main()
