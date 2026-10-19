#!/usr/bin/env python3
"""Read-only preflight for the two privacy issues reported on build 68.

Usage: python3 tool/check_ios_privacy.py /path/to/Runner.app [--json]
       python3 tool/check_ios_privacy.py /path/to/MyBar.xcarchive

Examines real Mach-O files, including statically linked plugin code. This is a
focused API-reference check, not a replacement for Apple's upload validation.
Requires the macOS Xcode command-line tools. It never modifies or signs a bundle.
"""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys


MACHO_MAGICS = {
    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",  # Mach-O 32-bit
    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",  # Mach-O 64-bit
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",  # Universal
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",  # Universal 64-bit
}
PURPOSES = {
    "camera": "NSCameraUsageDescription",
    "location": "NSLocationWhenInUseUsageDescription",
}
REFERENCES = {
    "camera": re.compile(
        r"AVCaptureDevice|AVCaptureSession|AVCaptureDeviceInput|"
        r"UIImagePickerControllerSourceTypeCamera"
    ),
    "location": re.compile(r"CLLocationManager|requestWhenInUseAuthorization"),
}
LEGACY_PICKERS = re.compile(r"DKCamera|DKPhotoGallery|DKImagePickerController")


def run_tool(arguments):
    result = subprocess.run(
        arguments, check=False, capture_output=True, text=True,
        errors="replace", timeout=120,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ValueError(f"{' '.join(arguments[:2])} failed: {detail}")
    return result.stdout


def load_plist(path, run=run_tool):
    data = path.read_bytes()
    try:
        result = plistlib.loads(data)
    except (plistlib.InvalidFileException, ValueError, TypeError):
        # Source and some packaged InfoPlist.strings files use OpenStep syntax.
        # stdout conversion leaves the original file and its signature intact.
        converted = run(["plutil", "-convert", "xml1", "-o", "-", str(path)])
        result = plistlib.loads(converted.encode("utf-8"))
    if not isinstance(result, dict):
        raise ValueError(f"Expected a property-list dictionary: {path}")
    return result


def resolve_app(path):
    path = Path(path).expanduser().resolve()
    if path.suffix == ".xcarchive" and path.is_dir():
        apps = sorted((path / "Products" / "Applications").glob("*.app"))
        if len(apps) != 1:
            raise ValueError(f"Expected exactly one app in archive; found {len(apps)}")
        path = apps[0]
    if path.suffix != ".app" or not (path / "Info.plist").is_file():
        raise ValueError("Supply an existing .app or .xcarchive containing an app")
    return path


def macho_files(app):
    # Reading the magic avoids relying on file extensions or executable bits.
    for path in sorted(app.rglob("*")):
        if path.is_file():
            with path.open("rb") as source:
                if source.read(4) in MACHO_MAGICS:
                    yield path


def valid_purpose(value):
    return isinstance(value, str) and bool(value.strip())


def inspect_app(path, run=run_tool):
    app = resolve_app(path)
    info = load_plist(app / "Info.plist", run)
    report = {
        "app": str(app), "binaries": [], "references": {},
        "purposes": {}, "errors": [],
    }
    for category, key in PURPOSES.items():
        report["references"][category] = []
        report["purposes"][category] = {
            "key": key, "base": info.get(key), "localized": {},
        }
        if key in info and not valid_purpose(info[key]):
            report["errors"].append(f"Info.plist: {key} must be a non-empty string")

    # A legacy framework must not survive a dependency migration even if stripped.
    for framework in sorted(app.rglob("*.framework")):
        if LEGACY_PICKERS.search(framework.name):
            report["errors"].append(f"Legacy picker framework remains: {framework.relative_to(app)}")

    for binary in macho_files(app):
        relative = str(binary.relative_to(app))
        report["binaries"].append(relative)
        try:
            symbols = run(["xcrun", "nm", "-m", str(binary)])
            literals = run(["strings", "-a", str(binary)])
        except (OSError, subprocess.SubprocessError, ValueError) as error:
            report["errors"].append(f"Cannot inspect {relative}: {error}")
            continue
        contents = symbols + "\n" + literals
        if LEGACY_PICKERS.search(contents):
            report["errors"].append(f"Legacy picker API reference remains: {relative}")
        for category, pattern in REFERENCES.items():
            if pattern.search(contents):
                report["references"][category].append(relative)

    if not report["binaries"]:
        report["errors"].append("No Mach-O files found; this is not a verifiable built app")
    for category, key in PURPOSES.items():
        if report["references"][category] and not valid_purpose(info.get(key)):
            report["errors"].append(f"Sensitive {category} API references require {key} in Runner Info.plist")

    # Missing overrides correctly fall back to Info.plist. Overrides that exist
    # must be valid; adding an empty translation would hide the fallback text.
    for localized_path in sorted(app.glob("*.lproj/InfoPlist.strings")):
        try:
            localized = load_plist(localized_path, run)
        except (OSError, subprocess.SubprocessError, ValueError, plistlib.InvalidFileException) as error:
            report["errors"].append(f"Cannot read {localized_path.relative_to(app)}: {error}")
            continue
        locale = localized_path.parent.stem
        for category, key in PURPOSES.items():
            if key in localized:
                report["purposes"][category]["localized"][locale] = localized[key]
                if not valid_purpose(localized[key]):
                    report["errors"].append(f"{locale}.lproj/InfoPlist.strings: {key} must be a non-empty string")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--json", action="store_true", help="Print a machine-readable report")
    arguments = parser.parse_args(argv)
    try:
        report = inspect_app(arguments.bundle)
    except (OSError, subprocess.SubprocessError, ValueError, plistlib.InvalidFileException) as error:
        parser.exit(2, f"Cannot inspect app: {error}\n")
    if arguments.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"App: {report['app']}")
        print(f"Mach-O files inspected: {len(report['binaries'])}")
        for category, paths in report["references"].items():
            print(f"{category.capitalize()}: " + (", ".join(paths) if paths else "no API references detected"))
        for error in report["errors"]:
            print(f"ERROR: {error}")
        print("FAIL" if report["errors"] else "PASS (focused camera/location preflight)")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
