"""Offline regression tests. Never invokes Flutter, downloads or uploads."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import re
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

    def create_captures(self, config, languages, devices, kind="screenshots", scenes=None):
        entries = (assets.marketing_entries if kind == "marketing" else assets.shot_entries)(config, languages, devices, scenes)
        for item in entries:
            path = self.output / item["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.new("RGB", (item["width"], item["height"])).save(path)
        if kind == "marketing":
            assets.save_json(self.output / "marketing-manifest.json", {
                "schemaVersion": 1, "renderer": "flutter-marketing-compositor",
                "screenshots": [{**item, "sourceUiEdited": False, "sourceUiCropped": False, "nativeDeviceCapture": False} for item in entries],
            })
        return entries

    def test_all_languages_and_device_dimensions(self):
        self.assertEqual(len(self.config["languages"]), 13)
        self.assertEqual(len({lang["appStoreLocale"] for lang in self.config["languages"]}), 13)
        devices = {device["id"]: (device["width"], device["height"]) for device in self.config["devices"]}
        self.assertEqual(devices["iphone-duo-outer"], (1398, 2034))
        self.assertEqual(devices["iphone-duo-inner"], (2007, 2853))
        self.assertEqual(len(self.config["screenshots"]), 7)
        self.assertEqual(self.config["screenshots"][-1]["id"], "07-almost-ready")
        self.assertEqual(len(assets.shot_entries(self.config, self.config["languages"], self.config["devices"])), 455)

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
        self.assertEqual((first["images"], first["metadata"], first["files"]), (7, 0, 8))
        with zipfile.ZipFile(first["archive"]) as archive:
            manifest = json.loads(archive.read("my-bar-screenshots-manifest.json"))
            self.assertFalse(manifest["provenance"]["nativeDeviceCapture"])
            self.assertIn("offline Noto", manifest["provenance"]["fontFallback"])
            self.assertTrue(all(not image["nativeDeviceCapture"] for image in manifest["files"]))
        assets.save_json(self.output / "capture-manifest.json", {"schemaVersion": 1, "renderer": "flutter-widget", "nativeDeviceCapture": False, "screenshots": []})
        metadata_bytes = (self.output / "capture-manifest.json").read_bytes()
        second = assets.package(config, self.output, languages, devices, "screenshots", True)
        self.assertEqual((second["images"], second["metadata"], second["files"]), (7, 1, 9))
        with zipfile.ZipFile(second["archive"]) as archive:
            self.assertEqual(archive.read("capture-manifest.json"), metadata_bytes)
            manifest = json.loads(archive.read("my-bar-screenshots-manifest.json"))
            self.assertEqual(manifest["metadata"][0]["sha256"], assets.hashlib.sha256(metadata_bytes).hexdigest())
        third = assets.package(config, self.output, languages, devices, "screenshots", True)
        self.assertEqual(second["sha256"], third["sha256"])

    def test_all_package_includes_three_sets_and_manifests_not_review_guides(self):
        config = self.small_config()
        languages, devices = config["languages"][:1], config["devices"][:1]
        for item in assets.shot_entries(config, languages, devices):
            path = self.output / item["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.new("RGB", (item["width"], item["height"])).save(path)
        assets.save_json(self.output / "capture-manifest.json", {"schemaVersion": 1, "renderer": "flutter-widget", "screenshots": []})
        self.create_captures(config, languages, devices, "marketing")
        assets.export_creatives(config, self.output, languages, self.create_source(), False)
        result = assets.package(config, self.output, languages, devices, "all", False)
        self.assertEqual((result["images"], result["metadata"], result["files"]), (17, 3, 21))
        with zipfile.ZipFile(result["archive"]) as archive:
            self.assertEqual(len(archive.namelist()), result["files"])
            self.assertIn("capture-manifest.json", archive.namelist())
            self.assertIn("creative-manifest.json", archive.namelist())
            self.assertIn("marketing-manifest.json", archive.namelist())
            self.assertFalse(any("review-guides" in name for name in archive.namelist()))
            manifest = json.loads(archive.read("my-bar-all-manifest.json"))
            marketing_files = [item for item in manifest["files"] if item["path"].startswith("marketing/")]
            self.assertEqual(len(marketing_files), 7)
            self.assertTrue(all("archivePath" not in item for item in marketing_files))
            self.assertIn("marketing/en-US/iphone-medium/07-almost-ready.png", archive.namelist())

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
        self.assertEqual(result["screenshots"], 14)

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
            self.assertEqual(env["STORE_ASSET_SCENES"], ",".join(scene["id"] for scene in config["screenshots"]))
            entries = assets.shot_entries(config, languages, devices)
            for item in entries:
                target = self.output / item["path"]
                target.parent.mkdir(parents=True, exist_ok=True)
                Image.new("RGBA", (item["width"], item["height"]), (1, 2, 3, 255)).save(target)
            assets.save_json(self.output / "capture-manifest.json", {"schemaVersion": 1, "renderer": "flutter-widget", "screenshots": entries})
        with mock.patch.object(assets.subprocess, "run", side_effect=fake_capture):
            result = assets.capture(config, MODULE_PATH.with_name("config.json"), self.output, languages, devices, False)
        self.assertEqual(result["screenshots"], 7)
        assets.validate(config, self.output, languages, devices, "screenshots")

    def test_scene_selectors_plan_paths_and_reject_unknown_before_writes(self):
        with contextlib.redirect_stdout(io.StringIO()) as stream:
            code = assets.main(["plan", "--languages", "ru", "--devices", "iphone-duo-inner", "--scenes", "07-almost-ready,03-recipe,07-almost-ready", "--output", str(self.output), "--json"])
        self.assertEqual(code, 0)
        result = json.loads(stream.getvalue())
        self.assertEqual((result["scenes"], result["screenshots"]), (2, 2))
        self.assertEqual([item["screen"] for item in result["files"]], ["07-almost-ready", "03-recipe"])
        self.assertEqual(result["marketingFiles"][0]["path"], "marketing/ru/iphone-duo-inner/07-almost-ready.png")
        self.assertFalse(self.output.exists())
        for command in ("capture", "compose", "validate", "package"):
            with contextlib.redirect_stderr(io.StringIO()), mock.patch.object(assets.subprocess, "run") as run:
                self.assertEqual(assets.main([command, "--scenes", "unknown", "--output", str(self.output)]), 1)
                run.assert_not_called()

    def test_marketing_validate_requires_matching_manifest_and_png(self):
        config = self.small_config()
        languages, devices, scenes = config["languages"][:1], config["devices"][:1], config["screenshots"][-1:]
        entries = self.create_captures(config, languages, devices, "marketing", scenes)
        assets.validate(config, self.output, languages, devices, "marketing", scenes)
        manifest = self.output / "marketing-manifest.json"
        correct = manifest.read_text()
        manifest.unlink()
        with self.assertRaisesRegex(assets.AssetError, "marketing-manifest"):
            assets.validate(config, self.output, languages, devices, "marketing", scenes)
        manifest.write_text(correct)
        (self.output / entries[0]["path"]).unlink()
        with self.assertRaisesRegex(assets.AssetError, "Missing image"):
            assets.package(config, self.output, languages, devices, "marketing", False, scenes)
        self.assertFalse((self.output / "my-bar-marketing.zip").exists())

    def test_marketing_manifest_rejects_mismatches_edited_ui_and_missing_entries(self):
        config = self.small_config()
        languages, devices, scenes = config["languages"][:1], config["devices"][:1], config["screenshots"][:1]
        self.create_captures(config, languages, devices, "marketing", scenes)
        path = self.output / "marketing-manifest.json"
        original = json.loads(path.read_text())
        mutations = [lambda data: data.update(renderer="other"), lambda data: data["screenshots"].clear(),
                     lambda data: data["screenshots"][0].update(sourceUiEdited=True),
                     lambda data: data["screenshots"][0].update(sourcePath="screenshots/wrong.png"),
                     lambda data: data["screenshots"].append(data["screenshots"][0]),
                     lambda data: data["screenshots"].append({"path": "../escape.png"})]
        for mutation in mutations:
            data = copy.deepcopy(original)
            mutation(data)
            assets.save_json(path, data)
            with self.assertRaises(assets.AssetError):
                assets.validate(config, self.output, languages, devices, "marketing", scenes)

    def test_marketing_package_is_selected_upload_set_with_raw_source_provenance(self):
        config = self.small_config()
        languages, devices, scenes = config["languages"][:1], config["devices"][:1], config["screenshots"][-1:]
        self.create_captures(config, languages, devices, "marketing", scenes)
        result = assets.package(config, self.output, languages, devices, "marketing", False, scenes)
        with zipfile.ZipFile(result["archive"]) as archive:
            self.assertEqual(len(archive.namelist()), 3)
            self.assertIn("en-US/iphone-medium/03-almost-ready.png", archive.namelist())
            self.assertFalse(any(name.startswith("screenshots/") for name in archive.namelist()))
            manifest = json.loads(archive.read("my-bar-marketing-manifest.json"))
            self.assertEqual(manifest["renderer"], "flutter-marketing-compositor")
            self.assertEqual(manifest["files"][0]["sourcePath"], "screenshots/en-US/iphone-medium/07-almost-ready.png")
            self.assertEqual(manifest["files"][0]["path"], "marketing/en-US/iphone-medium/07-almost-ready.png")
            self.assertEqual(manifest["files"][0]["archivePath"], "en-US/iphone-medium/03-almost-ready.png")
            self.assertEqual(manifest["files"][0]["sequence"], 3)
            self.assertEqual(manifest["files"][0]["sha256"], assets.hashlib.sha256(archive.read(manifest["files"][0]["archivePath"])).hexdigest())
            self.assertFalse(manifest["files"][0]["sourceUiEdited"])
        second = assets.package(config, self.output, languages, devices, "marketing", True, scenes)
        self.assertEqual(result["sha256"], second["sha256"])

    def test_compose_env_selections_normalization_and_preserves_unselected(self):
        config = self.small_config()
        config["fonts"] = []
        languages, devices, scenes = config["languages"][:1], config["devices"][:1], config["screenshots"][-1:]
        self.create_captures(config, languages, devices, scenes=scenes)
        config_path = self.root / "config.json"
        assets.save_json(config_path, config)
        assets.save_json(self.root / "marketing_copy.json", {"schemaVersion": 1, "sequence": [scene["id"] for scene in config["screenshots"]], "languages": {"en": {"07-almost-ready": {"headline": "Almost ready", "subtitle": "Just one ingredient"}}}})
        (self.root / "artwork").mkdir()
        Image.new("RGB", (10, 10)).save(self.root / "artwork" / "screenshot-background.png")
        unrelated = self.output / "keep.txt"
        unrelated.write_text("keep")
        def fake_compose(command, cwd, env, check):
            self.assertEqual(command[2], "tool/store_assets/compose_marketing.dart")
            self.assertEqual(env["STORE_ASSET_SCENES"], "07-almost-ready")
            self.assertEqual(env["STORE_ASSET_LANGUAGES"], "en")
            self.create_captures(config, languages, devices, "marketing", scenes)
            for item in assets.marketing_entries(config, languages, devices, scenes):
                Image.new("RGBA", (item["width"], item["height"]), (1, 2, 3, 255)).save(self.output / item["path"])
        with mock.patch.object(assets.subprocess, "run", side_effect=fake_compose) as run:
            result = assets.compose(config, config_path, self.output, languages, devices, False, scenes)
            self.assertEqual(result["marketingScreenshots"], 1)
            run.assert_called_once()
        self.assertEqual(unrelated.read_text(), "keep")
        assets.validate(config, self.output, languages, devices, "marketing", scenes)
        with mock.patch.object(assets.subprocess, "run") as run:
            with self.assertRaisesRegex(assets.AssetError, "already exists"):
                assets.compose(config, config_path, self.output, languages, devices, False, scenes)
            run.assert_not_called()

    def test_compose_missing_raw_capture_fails_before_flutter(self):
        config = self.small_config()
        with mock.patch.object(assets.subprocess, "run") as run:
            with self.assertRaisesRegex(assets.AssetError, "Missing image"):
                assets.compose(config, MODULE_PATH.with_name("config.json"), self.output, config["languages"][:1], config["devices"][:1], False, config["screenshots"][:1])
            run.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_compose_refuses_hardlink_to_raw_source_before_flutter(self):
        config = self.small_config()
        languages, devices, scenes = config["languages"][:1], config["devices"][:1], config["screenshots"][:1]
        entries = self.create_captures(config, languages, devices, scenes=scenes)
        source = self.output / entries[0]["path"]
        target = self.output / assets.marketing_entries(config, languages, devices, scenes)[0]["path"]
        target.parent.mkdir(parents=True)
        assets.os.link(source, target)
        original = source.read_bytes()
        with mock.patch.object(assets.subprocess, "run") as run:
            with self.assertRaisesRegex(assets.AssetError, "sources must be separate"):
                assets.compose(config, MODULE_PATH.with_name("config.json"), self.output, languages, devices, True, scenes)
            run.assert_not_called()
        self.assertEqual(source.read_bytes(), original)

    def test_marketing_upload_archive_uses_story_order_without_renaming_sources(self):
        config = self.small_config()
        languages, devices = config["languages"][:1], config["devices"][:1]
        entries = self.create_captures(config, languages, devices, "marketing")
        before = {item["path"]: assets.digest(self.output / item["path"]) for item in entries}
        result = assets.package(config, self.output, languages, devices, "marketing", False)
        expected_names = ["01-ingredients.png", "02-cocktails.png", "03-almost-ready.png", "04-shopping.png", "05-recipe.png", "06-party.png", "07-surprise.png"]
        with zipfile.ZipFile(result["archive"]) as archive:
            images = [name for name in archive.namelist() if name.endswith(".png")]
            self.assertEqual(images, [f"en-US/iphone-medium/{name}" for name in expected_names])
            manifest = json.loads(archive.read("my-bar-marketing-manifest.json"))
            self.assertEqual(manifest["uploadSequence"][2], "07-almost-ready")
            self.assertEqual([item["sequence"] for item in manifest["files"]], list(range(1, 8)))
            for item in manifest["files"]:
                self.assertEqual(item["sha256"], before[item["path"]])
                self.assertEqual(item["sha256"], assets.hashlib.sha256(archive.read(item["archivePath"])).hexdigest())
        self.assertEqual(before, {item["path"]: assets.digest(self.output / item["path"]) for item in entries})

    def test_marketing_copy_has_exact_locale_scene_coverage_and_reasonable_caption_lengths(self):
        data = assets.load_marketing_copy(self.config, MODULE_PATH.with_name("config.json"))
        language_codes = {language["code"] for language in self.config["languages"]}
        scene_ids = {scene["id"] for scene in self.config["screenshots"]}
        self.assertEqual(set(data["languages"]), language_codes)
        self.assertEqual(len(data["sequence"]), len(scene_ids))
        self.assertEqual(set(data["sequence"]), scene_ids)
        self.assertEqual(data["sequence"][2], "07-almost-ready")
        for language, localized in data["languages"].items():
            self.assertEqual(set(localized), scene_ids, language)
            for scene, copy in localized.items():
                for key, maximum in (("headline", 64), ("subtitle", 110)):
                    value = copy[key]
                    self.assertIsInstance(value, str)
                    self.assertEqual(value, value.strip(), f"{language}/{scene}/{key}")
                    self.assertTrue(value, f"{language}/{scene}/{key}")
                    self.assertLessEqual(len(value), maximum, f"{language}/{scene}/{key}")
                    self.assertNotIn("\n", value)
        # Compare any concrete recipe-count claim to the shipping catalog, not
        # to a hard-coded constant that could silently go stale after additions.
        catalog = json.loads((assets.REPO_ROOT / "assets/data/bar_template.json").read_text())
        count = len(catalog["cocktails"])
        for language, localized in data["languages"].items():
            claims = re.findall(r"\d+", localized["02-cocktails"]["subtitle"])
            self.assertEqual(claims, [str(count)], language)

    def test_marketing_copy_rejects_duplicate_missing_unknown_or_nonstring_sequence(self):
        original = assets.load_marketing_copy(self.config, MODULE_PATH.with_name("config.json"))
        for sequence in (original["sequence"][:-1], [*original["sequence"][:-1], original["sequence"][0]], [*original["sequence"][:-1], "unknown"], [*original["sequence"][:-1], {}]):
            data = copy.deepcopy(original)
            data["sequence"] = sequence
            assets.save_json(self.root / "marketing_copy.json", data)
            with self.assertRaisesRegex(assets.AssetError, "sequence"):
                assets.load_marketing_copy(self.config, self.root / "config.json")

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
