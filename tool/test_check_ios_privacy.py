"""Offline fixtures: never calls Xcode tools, signs a bundle or builds Flutter."""

import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    "check_ios_privacy", Path(__file__).with_name("check_ios_privacy.py"),
)
privacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(privacy)


class PrivacyPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.app = self.root / "Runner.app"
        self.app.mkdir()
        self.write_plist(self.app / "Info.plist", {"CFBundleExecutable": "Runner"})
        self.binary = self.make_binary(self.app / "Runner")
        self.outputs = {}
        self.calls = []

    def write_plist(self, path, values):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(values))

    def make_binary(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\xcf\xfa\xed\xfe" + b"fixture")
        return path

    def tool(self, arguments):
        self.calls.append(arguments)
        return self.outputs.get((arguments[0], arguments[-1]), "")

    def inspect(self):
        return privacy.inspect_app(self.app, run=self.tool)

    def test_clean_app_needs_no_camera_or_location_declarations(self):
        # Merely containing a photo selector does not imply camera access.
        self.outputs[("strings", str(self.binary))] = "PHPickerViewController UIImagePickerController"
        report = self.inspect()
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["references"], {"camera": [], "location": []})
        self.assertEqual(report["binaries"], ["Runner"])
        self.assertEqual([call[0] for call in self.calls], ["xcrun", "strings"])

    def test_missing_purposes_fail_for_statically_linked_sdk(self):
        self.outputs[("xcrun", str(self.binary))] = "_OBJC_CLASS_$_AVCaptureDevice"
        self.outputs[("strings", str(self.binary))] = "requestWhenInUseAuthorization"
        report = self.inspect()
        self.assertTrue(report["references"]["camera"])
        self.assertTrue(report["references"]["location"])
        self.assertTrue(any("NSCameraUsageDescription" in error for error in report["errors"]))
        self.assertTrue(any("NSLocationWhenInUseUsageDescription" in error for error in report["errors"]))

    def test_frameworks_are_inspected_and_real_purposes_pass(self):
        framework = self.make_binary(self.app / "Frameworks" / "Example.framework" / "Example")
        self.outputs[("strings", str(framework))] = "AVCaptureSession CLLocationManager"
        values = {key: "A clear user-facing purpose." for key in privacy.PURPOSES.values()}
        self.write_plist(self.app / "Info.plist", values)
        self.write_plist(self.app / "ru.lproj" / "InfoPlist.strings", {
            "NSCameraUsageDescription": "Добавить фотографию коктейля.",
        })
        report = self.inspect()
        self.assertEqual(report["errors"], [])
        self.assertIn("Frameworks/Example.framework/Example", report["references"]["camera"])
        self.assertIn("ru", report["purposes"]["camera"]["localized"])

    def test_empty_base_and_localized_purposes_fail(self):
        self.write_plist(self.app / "Info.plist", {"NSCameraUsageDescription": " "})
        self.write_plist(self.app / "fr.lproj" / "InfoPlist.strings", {
            "NSLocationWhenInUseUsageDescription": "",
        })
        errors = self.inspect()["errors"]
        self.assertEqual(len(errors), 2)
        self.assertTrue(any("fr.lproj" in error for error in errors))

    def test_legacy_framework_and_static_references_fail_even_with_purposes(self):
        (self.app / "Frameworks" / "DKCamera.framework").mkdir(parents=True)
        self.outputs[("strings", str(self.binary))] = "DKImagePickerController DKPhotoGallery"
        errors = self.inspect()["errors"]
        self.assertTrue(any("Legacy picker framework" in error for error in errors))
        self.assertTrue(any("Legacy picker API reference" in error for error in errors))

    def test_tool_failures_are_not_reported_as_clean(self):
        with mock.patch.object(privacy, "macho_files", return_value=[self.binary]):
            def fail_tool(arguments):
                raise ValueError("tool not available")
            report = privacy.inspect_app(self.app, run=fail_tool)
        self.assertTrue(any("Cannot inspect Runner" in error for error in report["errors"]))

    def test_external_tool_failure_is_not_silently_ignored(self):
        result = subprocess.CompletedProcess(["xcrun", "nm"], 1, "", "nm failed")
        with mock.patch.object(privacy.subprocess, "run", return_value=result) as run:
            with self.assertRaisesRegex(ValueError, "nm failed"):
                privacy.run_tool(["xcrun", "nm", "-m", str(self.binary)])
        self.assertFalse(run.call_args.kwargs["check"])
        self.assertNotIn("shell", run.call_args.kwargs)

    def test_macho_discovery_covers_universal_and_thin_binaries(self):
        self.binary.unlink()
        for index, magic in enumerate(sorted(privacy.MACHO_MAGICS)):
            (self.app / f"binary-{index}").write_bytes(magic + b"fixture")
        (self.app / "ignored.png").write_bytes(b"\x89PNGfixture")
        self.assertEqual(len(list(privacy.macho_files(self.app))), len(privacy.MACHO_MAGICS))

    def test_archive_resolves_the_actual_app(self):
        archive = self.root / "MyBar.xcarchive"
        destination = archive / "Products" / "Applications" / self.app.name
        destination.parent.mkdir(parents=True)
        self.app.rename(destination)
        self.assertEqual(privacy.resolve_app(archive), destination)
        self.assertEqual(privacy.inspect_app(archive, run=self.tool)["errors"], [])

    def test_ambiguous_archive_and_unbuilt_bundle_are_rejected(self):
        archive = self.root / "Empty.xcarchive"
        archive.mkdir()
        with self.assertRaises(ValueError):
            privacy.resolve_app(archive)
        self.binary.unlink()
        self.assertTrue(any("No Mach-O" in error for error in self.inspect()["errors"]))

    def test_openstep_strings_are_converted_read_only(self):
        path = self.app / "ru.lproj" / "InfoPlist.strings"
        path.parent.mkdir()
        original = b'"NSCameraUsageDescription" = "Localized purpose";'
        path.write_bytes(original)
        calls = []
        def convert(arguments):
            calls.append(arguments)
            return plistlib.dumps({"NSCameraUsageDescription": "Localized purpose"}).decode()
        result = privacy.load_plist(path, run=convert)
        self.assertEqual(result["NSCameraUsageDescription"], "Localized purpose")
        self.assertEqual(calls[0][:5], ["plutil", "-convert", "xml1", "-o", "-"])
        self.assertEqual(path.read_bytes(), original)

    def test_main_returns_nonzero_for_failed_preflight(self):
        report = {"app": str(self.app), "binaries": ["Runner"],
                  "references": {"camera": ["Runner"]}, "errors": ["Missing purpose"]}
        with mock.patch.object(privacy, "inspect_app", return_value=report), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(privacy.main([str(self.app)]), 1)


if __name__ == "__main__":
    unittest.main()
