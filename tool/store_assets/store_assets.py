#!/usr/bin/env python3
"""Local store-asset generation, validation and packaging. Never uploads."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import zipfile

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "build" / "store-assets"
SAFE_ID = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_-]*$")


class AssetError(Exception):
    """A user-facing, recoverable configuration or asset error."""


def pillow():
    try:
        from PIL import Image, ImageOps
    except ImportError as error:
        raise AssetError("Pillow is required. Install it in your Python environment before exporting or validating images.") from error
    return Image, ImageOps


def load_config(path: Path) -> dict:
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise AssetError(f"Cannot read config {path}: {error}") from error
    if not isinstance(config, dict):
        raise AssetError("Config must be a JSON object.")
    if config.get("schemaVersion") != 1:
        raise AssetError("Unsupported config schemaVersion; expected 1.")
    for group, identity in (("languages", "code"), ("devices", "id"), ("screenshots", "id"), ("creatives", "id")):
        values = config.get(group)
        if not isinstance(values, list) or not values:
            raise AssetError(f"Config {group} must be a nonempty list.")
        seen = set()
        for item in values:
            if not isinstance(item, dict):
                raise AssetError(f"Config {group} entries must be JSON objects.")
            key = item.get(identity, "")
            if not isinstance(key, str) or not SAFE_ID.fullmatch(key) or key in seen:
                raise AssetError(f"Invalid or duplicate {group} identifier: {key!r}.")
            seen.add(key)
            if group == "languages":
                for field in ("appStoreLocale", "googlePlayLocale"):
                    locale = item.get(field, "")
                    if not isinstance(locale, str) or not SAFE_ID.fullmatch(locale):
                        raise AssetError(f"Invalid {field} locale for {key}.")
            if group in ("devices", "creatives"):
                if any(not isinstance(item.get(axis), int) or isinstance(item.get(axis), bool) or item[axis] <= 0 for axis in ("width", "height")):
                    raise AssetError(f"Invalid dimensions for {key}.")
                if group == "devices":
                    if item.get("platform") not in ("ios", "android"):
                        raise AssetError(f"Invalid platform for {key}.")
                    ratio = item.get("pixelRatio")
                    if isinstance(ratio, bool) or not isinstance(ratio, (int, float)) or not math.isfinite(ratio) or ratio <= 0:
                        raise AssetError(f"Invalid pixelRatio for {key}.")
                if group == "creatives" and item.get("safeRect"):
                    rect = item["safeRect"]
                    if not isinstance(rect, dict) or any(not isinstance(rect.get(axis), int) for axis in ("x", "y", "width", "height")):
                        raise AssetError(f"Invalid safe rectangle for {key}.")
                    if rect["x"] < 0 or rect["y"] < 0 or rect["width"] <= 0 or rect["height"] <= 0 or rect["x"] + rect["width"] > item["width"] or rect["y"] + rect["height"] > item["height"]:
                        raise AssetError(f"Safe rectangle falls outside {key}.")
    for field in ("appStoreLocale", "googlePlayLocale"):
        locales = [entry[field] for entry in config["languages"]]
        if len(set(locales)) != len(locales):
            raise AssetError(f"{field} locale paths must be unique.")
    return config


def select(items: list[dict], csv: str | None, key: str, label: str) -> list[dict]:
    if csv is None:
        enabled = [item for item in items if item.get("enabled", True)]
        if not enabled:
            raise AssetError(f"No enabled {label}. Enable at least one entry or select explicit IDs.")
        return enabled
    requested = list(dict.fromkeys(part.strip() for part in csv.split(",") if part.strip()))
    if not requested:
        raise AssetError(f"Select at least one {label}.")
    by_id = {item[key]: item for item in items}
    missing = [item for item in requested if item not in by_id]
    if missing:
        raise AssetError(f"Unknown {label}: {', '.join(missing)}. Use list to see supported values.")
    return [by_id[item] for item in requested]


def safe_output(path: Path) -> Path:
    path = path.expanduser().absolute()
    # Reject symlink ancestors as well as symlink output roots. A precise target
    # beneath a user-owned folder is allowed; a broad root is never an output.
    if any(part.is_symlink() for part in (path, *path.parents)):
        raise AssetError(f"Output must not traverse symbolic links: {path}")
    path = path.resolve()
    forbidden = {Path(path.anchor), Path.home().resolve(), REPO_ROOT, SCRIPT_DIR}
    if path in forbidden or path in REPO_ROOT.parents:
        raise AssetError(f"Choose a dedicated output folder, not {path}.")
    if path.exists() and not path.is_dir():
        raise AssetError(f"Output is not a directory: {path}")
    return path


def target_file(output: Path, relative: str | Path) -> Path:
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise AssetError(f"Unsafe artifact path: {relative}")
    target = output / relative
    if any(part.is_symlink() for part in (target, *target.parents)):
        raise AssetError(f"Artifact must not traverse symbolic links: {target}")
    if not target.resolve().is_relative_to(output.resolve()):
        raise AssetError(f"Artifact is outside output: {target}")
    return target


def ensure_writable(paths: list[Path], overwrite: bool) -> None:
    existing = [path for path in paths if path.exists()]
    if any(path.is_dir() for path in existing):
        raise AssetError("An artifact target is a directory; refusing to replace it.")
    if existing and not overwrite:
        sample = ", ".join(str(path) for path in existing[:3])
        raise AssetError(f"Output already exists: {sample}. Pass --overwrite to replace only the selected artifact files.")


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def shot_entries(config: dict, languages: list[dict], devices: list[dict], scenes: list[dict] | None = None) -> list[dict]:
    return [
        {"language": lang["code"], "locale": lang["appStoreLocale"], "device": device["id"],
         "screen": screen["id"], "width": device["width"], "height": device["height"],
         "path": f"screenshots/{lang['appStoreLocale']}/{device['id']}/{screen['id']}.png"}
        for lang in languages for device in devices for screen in (config["screenshots"] if scenes is None else scenes)
    ]


def marketing_entries(config: dict, languages: list[dict], devices: list[dict], scenes: list[dict] | None = None) -> list[dict]:
    return [{**item, "sourcePath": item["path"], "path": item["path"].replace("screenshots/", "marketing/", 1)}
            for item in shot_entries(config, languages, devices, scenes)]


def google_play_entries(config: dict, config_path: Path, languages: list[dict], devices: list[dict], scenes: list[dict] | None = None) -> list[dict]:
    """Android-only upload set: frame-free phone marketing, app-only tablets."""
    copy = load_marketing_copy(config, config_path)
    sequence = copy["sequence"]
    positions = {scene: index + 1 for index, scene in enumerate(sequence)}
    entries = []
    device_types = set()
    for device in devices:
        device_type = device.get("googlePlayDeviceType")
        if device.get("platform") != "android" or device_type not in ("phone", "tablet-7", "tablet-10"):
            raise AssetError(f"Google Play export requires Android phone/tablet profiles, not {device['id']}.")
        if device_type in device_types:
            raise AssetError(f"Select only one profile per Google Play device type: {device_type}.")
        device_types.add(device_type)
        width, height = device["width"], device["height"]
        if min(width, height) < 1080 or max(width, height) > 3840 or width * 16 != height * 9:
            raise AssetError(f"Google Play profile must be portrait 9:16, 1080–3840 pixels: {device['id']}.")
        for language in languages:
            source_kind = "marketing" if device_type == "phone" else "screenshots"
            sources = (marketing_entries if source_kind == "marketing" else shot_entries)(config, [language], [device], scenes)
            for source in sources:
                language_copy = copy["languages"].get(language["code"])
                localized = language_copy.get(source["screen"]) if isinstance(language_copy, dict) else None
                if not isinstance(localized, dict) or any(not isinstance(localized.get(key), str) or not localized[key].strip() for key in ("headline", "subtitle")):
                    raise AssetError(f"Missing localized Google Play screenshot context: {language['code']}/{source['screen']}")
                alt_text = f"{localized['headline']} — {localized['subtitle']}"
                if len(alt_text) > 140:
                    alt_text = localized["headline"]
                if len(alt_text) > 140:
                    raise AssetError(f"Google Play screenshot alt text exceeds 140 characters: {language['code']}/{source['screen']}")
                number = positions[source["screen"]]
                label = re.sub(r"^\d+-", "", source["screen"])
                entries.append({**source, "sourcePath": source["path"],
                                "capturePath": source.get("sourcePath", source["path"]),
                                "path": f"google-play/{language['googlePlayLocale']}/{device_type}/{number:02d}-{label}.png",
                                "locale": language["googlePlayLocale"], "appStoreLocale": language["appStoreLocale"],
                                "platform": "android", "deviceType": device_type,
                                "sourceKind": source_kind, "sequence": number,
                                "addedCaptions": device_type == "phone", "deviceFrame": "none",
                                "renderer": "flutter-marketing-compositor" if device_type == "phone" else "flutter-widget",
                                "altText": alt_text,
                                "sourceUiRoundedCornerMask": False,
                                "nativeDeviceCapture": False, "sourceUiEdited": False, "sourceUiCropped": False})
    return sorted(entries, key=lambda item: (item["locale"], item["deviceType"], item["sequence"]))


def verify_google_play_image(path: Path, width: int, height: int) -> None:
    verify_image(path, width, height)
    if path.stat().st_size > 8 * 1024 * 1024:
        raise AssetError(f"Google Play screenshot exceeds 8 MiB: {path}")


def validate_android_sources(output: Path, entries: list[dict]) -> None:
    data = read_capture_index(target_file(output, "capture-manifest.json"), "flutter-widget")
    captures = {item.get("path"): item for item in data["screenshots"]}
    phone_entries = [item for item in entries if item["sourceKind"] == "marketing"]
    phone_manifest = read_capture_index(target_file(output, "marketing-manifest.json"), "flutter-marketing-compositor") if phone_entries else None
    phones = {item.get("path"): item for item in phone_manifest["screenshots"]} if phone_manifest else {}
    for expected in entries:
        actual = captures.get(expected["capturePath"], {})
        if actual.get("platform") != "android" or actual.get("nativeDeviceCapture") is not False:
            raise AssetError(f"Missing verified Android widget capture provenance: {expected['capturePath']}")
        for field in ("language", "device", "screen", "width", "height"):
            if actual.get(field) != expected[field]:
                raise AssetError(f"Android capture {field} mismatch: {expected['capturePath']}")
        if actual.get("locale") != expected["appStoreLocale"]:
            raise AssetError(f"Android capture source locale mismatch: {expected['capturePath']}")
        if expected["sourceKind"] == "marketing":
            composed = phones.get(expected["sourcePath"], {})
            if (composed.get("platform") != "android" or composed.get("deviceFrame") != "none" or
                    composed.get("sourceUiRoundedCornerMask") is not False or
                    composed.get("sourceUiEdited") is not False or composed.get("sourceUiCropped") is not False or
                    composed.get("sourcePath") != expected["capturePath"] or
                    composed.get("sourceSha256") != digest(target_file(output, expected["capturePath"]))):
                raise AssetError(f"Phone marketing must contain unchanged Android UI and no decorative device frame: {expected['sourcePath']}")


def export_google_play(config: dict, config_path: Path, output: Path, languages: list[dict], devices: list[dict], overwrite: bool, scenes: list[dict] | None = None) -> dict:
    entries = google_play_entries(config, config_path, languages, devices, scenes)
    targets = [target_file(output, item["path"]) for item in entries]
    ensure_writable(targets, overwrite)
    validate_android_sources(output, entries)
    for item, target in zip(entries, targets):
        source = target_file(output, item["sourcePath"])
        verify_google_play_image(source, item["width"], item["height"])
        if target.exists() and source.samefile(target):
            raise AssetError("Google Play upload copies must be separate from source captures.")
    manifest_path = target_file(output, "google-play-manifest.json")
    previous = read_capture_index(manifest_path, "android-google-play-export") if manifest_path.exists() else {"screenshots": []}
    retained = {item["path"]: item for item in previous["screenshots"]}
    for path in retained:
        target_file(output, path)
    for item, target in zip(entries, targets):
        source = target_file(output, item["sourcePath"])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        retained[item["path"]] = {**item, "sha256": digest(target), "bytes": target.stat().st_size,
                                  "sourceSha256": digest(source)}
    save_json(manifest_path, {"schemaVersion": 1, "renderer": "android-google-play-export", "uploaded": False,
                             "source": config.get("sources", {}).get("googlePlayScreenshots"),
                             "notes": ["Actual Android Flutter-widget layouts, not resized iOS screenshots or native-device captures.",
                                       "Phone captions are localized. Tablets contain only app UI, with no added captions, backgrounds or device imagery.",
                                       "All images are opaque 24-bit RGB PNG, portrait 9:16 and no more than 8 MiB."],
                             "screenshots": sorted(retained.values(), key=lambda item: item["path"])})
    return {"googlePlayScreenshots": len(entries), "output": str(output / "google-play"), "uploaded": False}


def validate_google_play(config: dict, config_path: Path, output: Path, languages: list[dict], devices: list[dict], scenes: list[dict] | None = None) -> dict:
    entries = google_play_entries(config, config_path, languages, devices, scenes)
    validate_android_sources(output, entries)
    manifest = read_capture_index(target_file(output, "google-play-manifest.json"), "android-google-play-export")
    by_path = {}
    for item in manifest["screenshots"]:
        path = item.get("path")
        if not isinstance(path, str) or path in by_path:
            raise AssetError("Invalid or duplicate Google Play manifest path.")
        target_file(output, path)
        by_path[path] = item
    for expected in entries:
        actual = by_path.get(expected["path"], {})
        for field, value in expected.items():
            if actual.get(field) != value:
                raise AssetError(f"Google Play manifest {field} mismatch: {expected['path']}")
        path = target_file(output, expected["path"])
        verify_google_play_image(path, expected["width"], expected["height"])
        if actual.get("bytes") != path.stat().st_size:
            raise AssetError(f"Google Play screenshot byte size mismatch: {expected['path']}")
        if (actual.get("sha256") != digest(path) or actual.get("sha256") != actual.get("sourceSha256") or
                actual.get("sourceSha256") != digest(target_file(output, expected["sourcePath"]))):
            raise AssetError(f"Google Play screenshot/source hash mismatch: {expected['path']}")
    return {"validatedImages": len(entries), "kind": "google-play", "output": str(output / "google-play"), "uploaded": False}


def read_capture_index(path: Path, renderer: str) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise AssetError(f"Cannot read capture metadata {path}: {error}") from error
    if not isinstance(data, dict) or data.get("schemaVersion") != 1 or data.get("renderer") != renderer or not isinstance(data.get("screenshots"), list):
        raise AssetError(f"Invalid capture manifest schema/renderer/screenshots: {path}")
    if any(not isinstance(item, dict) for item in data["screenshots"]):
        raise AssetError(f"Invalid capture manifest entries: {path}")
    return data


def validate_marketing_index(output: Path, entries: list[dict]) -> None:
    data = read_capture_index(target_file(output, "marketing-manifest.json"), "flutter-marketing-compositor")
    by_path = {}
    for item in data["screenshots"]:
        path = item.get("path")
        if not isinstance(path, str) or path in by_path:
            raise AssetError("Invalid or duplicate marketing manifest path.")
        target_file(output, path)
        by_path[path] = item
    for expected in entries:
        actual = by_path.get(expected["path"])
        if actual is None:
            raise AssetError(f"Marketing manifest is missing selected image: {expected['path']}")
        for key in ("language", "locale", "device", "screen", "width", "height", "sourcePath"):
            if actual.get(key) != expected[key]:
                raise AssetError(f"Marketing manifest {key} mismatch: {expected['path']}")
        if actual.get("sourceUiEdited") is not False or actual.get("sourceUiCropped") is not False or actual.get("nativeDeviceCapture") is not False:
            raise AssetError(f"Marketing manifest must identify unedited, uncropped offscreen UI: {expected['path']}")


def creative_entries(config: dict) -> list[dict]:
    return [{"id": item["id"], "path": f"creatives/{item['id']}.png", "width": item["width"], "height": item["height"], "safeRect": item.get("safeRect")} for item in config["creatives"]]


def load_marketing_copy(config: dict, config_path: Path) -> dict:
    copy_path = config_path.parent / "marketing_copy.json"
    try:
        data = json.loads(copy_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise AssetError(f"Cannot read marketing copy {copy_path}: {error}") from error
    if not isinstance(data, dict) or data.get("schemaVersion") != 1 or not isinstance(data.get("languages"), dict):
        raise AssetError("Marketing copy must have schemaVersion 1 and a languages object.")
    sequence = data.get("sequence")
    expected = {scene["id"] for scene in config["screenshots"]}
    if not isinstance(sequence, list) or any(not isinstance(item, str) for item in sequence) or len(sequence) != len(expected) or set(sequence) != expected:
        raise AssetError("Marketing copy sequence must contain each configured scene exactly once.")
    return data


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def verify_image(path: Path, width: int, height: int) -> None:
    Image, _ = pillow()
    if not path.is_file():
        raise AssetError(f"Missing image: {path}")
    try:
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG":
                raise AssetError(f"Expected PNG: {path}")
            if image.size != (width, height):
                raise AssetError(f"Wrong dimensions for {path}: {image.size}, expected {(width, height)}.")
            if image.mode != "RGB" or "transparency" in image.info:
                raise AssetError(f"Expected opaque RGB image, got {image.mode}: {path}")
    except (OSError, ValueError) as error:
        raise AssetError(f"Cannot decode {path}: {error}") from error


def normalize_rgb(path: Path) -> None:
    Image, _ = pillow()
    with Image.open(path) as source:
        if source.mode == "RGB" and "transparency" not in source.info:
            return
        if source.mode == "RGBA" or "transparency" in source.info:
            rgba = source.convert("RGBA")
            result = Image.new("RGB", source.size, (7, 9, 17))
            result.paste(rgba, mask=rgba.getchannel("A"))
        else:
            result = source.convert("RGB")
        result.save(path, "PNG")


def font_errors(config: dict, config_path: Path) -> list[str]:
    errors = []
    for font in config.get("fonts", []):
        path = (config_path.parent / font["path"]).resolve()
        if not path.is_file():
            errors.append(f"Missing font {font['family']}: {path}")
        elif font.get("sha256") and digest(path) != font["sha256"]:
            errors.append(f"Font hash mismatch: {path}")
    return errors


def prepare_fonts(config_path: Path, manifest_path: Path | None = None) -> dict:
    """The one opt-in network operation: fetch pinned, freely licensed fonts."""
    manifest_path = manifest_path or config_path.parent / "font_sources.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise AssetError(f"Cannot read font sources {manifest_path}: {error}") from error
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1 or not isinstance(manifest.get("fonts"), list) or not manifest["fonts"]:
        raise AssetError("Font source manifest must have schemaVersion 1 and a nonempty fonts array.")
    cache = safe_output(REPO_ROOT / ".dart_tool" / "store_assets" / "fonts")
    prepared = []
    # Validate all entries before writing or connecting to the network.
    targets = []
    for font in manifest["fonts"]:
        if not isinstance(font, dict):
            raise AssetError("Invalid font source entry.")
        url = font.get("url", "")
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.netloc != "raw.githubusercontent.com":
            raise AssetError("Font URLs must use HTTPS on raw.githubusercontent.com, with no credentials or custom port.")
        if not parsed.path.startswith(("/google/fonts/", "/notofonts/noto-cjk/", "/notofonts/cjk/")):
            raise AssetError("Font sources must be official google/fonts or notofonts CJK repositories.")
        expected = font.get("sha256", "")
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", expected):
            raise AssetError("Every font source needs a pinned SHA-256 hash.")
        relative_path = font.get("path", "")
        if not isinstance(relative_path, str) or not relative_path:
            raise AssetError("Every font source needs a cache path relative to its manifest.")
        candidate = manifest_path.parent / relative_path
        if any(part.is_symlink() for part in (candidate, *candidate.parents)):
            raise AssetError(f"Font cache path traverses a symbolic link: {candidate}")
        candidate = candidate.resolve()
        if not candidate.is_relative_to(cache) or candidate == cache or candidate.suffix.lower() not in (".ttf", ".otf"):
            raise AssetError(f"Font target must be a TTF/OTF file inside {cache}: {candidate}")
        if candidate.exists() and not candidate.is_file():
            raise AssetError(f"Font cache target is not a file: {candidate}")
        if candidate in [entry[1] for entry in targets]:
            raise AssetError(f"Duplicate font cache target: {candidate}")
        targets.append((font, candidate, expected.lower()))
    for font, target, expected in targets:
        if target.is_file() and digest(target) == expected:
            prepared.append({"family": font.get("family"), "path": str(target), "cached": True})
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            request = Request(font["url"], headers={"User-Agent": "MyBar-StoreAssets/1.0"})
            with urlopen(request, timeout=60) as response:
                final_url = urlparse(response.geturl())
                if final_url.scheme != "https" or final_url.hostname != "raw.githubusercontent.com":
                    raise AssetError("Refusing a font download redirected away from the pinned HTTPS host.")
                with tempfile.NamedTemporaryFile(dir=target.parent, prefix=f".{target.name}.", suffix=".download", delete=False) as stream:
                    temporary = Path(stream.name)
                    size = 0
                    for block in iter(lambda: response.read(1024 * 1024), b""):
                        size += len(block)
                        if size > 100 * 1024 * 1024:
                            raise AssetError("Font download exceeded the 100 MiB safety limit.")
                        stream.write(block)
            if digest(temporary) != expected:
                raise AssetError(f"Downloaded font hash mismatch: {font.get('family', target.name)}. Cache was not replaced.")
            temporary.replace(target)
            temporary = None
            prepared.append({"family": font.get("family"), "path": str(target), "cached": False})
        except OSError as error:
            raise AssetError(f"Cannot download {font.get('family', target.name)}: {error}") from error
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    return {"fonts": prepared, "downloaded": sum(not entry["cached"] for entry in prepared), "uploaded": False}


def capture(config: dict, config_path: Path, output: Path, languages: list[dict], devices: list[dict], overwrite: bool, scenes: list[dict] | None = None) -> dict:
    pillow()  # Fail before starting Flutter if image verification is unavailable.
    errors = font_errors(config, config_path)
    if errors:
        raise AssetError("\n".join(errors))
    scenes = config["screenshots"] if scenes is None else scenes
    entries = shot_entries(config, languages, devices, scenes)
    targets = [target_file(output, item["path"]) for item in entries]
    manifest = target_file(output, "capture-manifest.json")
    # The manifest is a merge index, so existing unrelated captures are retained.
    ensure_writable(targets, overwrite)
    if manifest.exists():
        read_capture_index(manifest, "flutter-widget")
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(STORE_ASSET_CONFIG=str(config_path), STORE_ASSET_OUTPUT=str(output),
               STORE_ASSET_LANGUAGES=",".join(lang["code"] for lang in languages),
               STORE_ASSET_DEVICES=",".join(device["id"] for device in devices),
               STORE_ASSET_SCENES=",".join(scene["id"] for scene in scenes),
               FLUTTER_SUPPRESS_ANALYTICS="true", DART_SUPPRESS_ANALYTICS="true")
    command = ["flutter", "test", "tool/store_assets/capture_ui.dart", "--run-skipped", "--no-pub"]
    try:
        subprocess.run(command, cwd=REPO_ROOT, env=env, check=True)
    except FileNotFoundError as error:
        raise AssetError("Flutter is not available on PATH.") from error
    except subprocess.CalledProcessError as error:
        raise AssetError(f"Flutter capture failed (exit {error.returncode}). Existing completed PNGs were retained; retry the same selection with --overwrite.") from error
    for target, item in zip(targets, entries):
        if not target.is_file():
            raise AssetError(f"Capture did not produce {target}")
        normalize_rgb(target)
        verify_image(target, item["width"], item["height"])
    if not manifest.is_file():
        raise AssetError("Capture did not produce capture-manifest.json.")
    return {"screenshots": len(entries), "output": str(output), "renderer": "flutter-widget", "uploaded": False}


def compose(config: dict, config_path: Path, output: Path, languages: list[dict], devices: list[dict], overwrite: bool, scenes: list[dict] | None = None) -> dict:
    """Frame unchanged real UI captures with localized, offline marketing copy."""
    pillow()
    errors = font_errors(config, config_path)
    if errors:
        raise AssetError("\n".join(errors))
    scenes = config["screenshots"] if scenes is None else scenes
    entries = marketing_entries(config, languages, devices, scenes)
    targets = [target_file(output, item["path"]) for item in entries]
    ensure_writable(targets, overwrite)
    manifest = target_file(output, "marketing-manifest.json")
    if manifest.exists():
        validate_marketing_index(output, [])
    for item in entries:
        source = target_file(output, item["sourcePath"])
        verify_image(source, item["width"], item["height"])
        if any(target.exists() and source.samefile(target) for target in targets):
            raise AssetError("Raw screenshot sources must be separate from marketing output files.")
    copy = load_marketing_copy(config, config_path)
    for language in languages:
        localized = copy["languages"].get(language["code"])
        for scene in scenes:
            text = localized.get(scene["id"]) if isinstance(localized, dict) else None
            if not isinstance(text, dict) or any(not isinstance(text.get(key), str) or not text[key].strip() for key in ("headline", "subtitle")):
                raise AssetError(f"Missing marketing captions: {language['code']}/{scene['id']}")
    background = config_path.parent / "artwork" / "screenshot-background.png"
    if not background.is_file():
        raise AssetError(f"Missing marketing background: {background}")
    env = os.environ.copy()
    env.update(STORE_ASSET_CONFIG=str(config_path), STORE_ASSET_OUTPUT=str(output),
               STORE_ASSET_LANGUAGES=",".join(lang["code"] for lang in languages),
               STORE_ASSET_DEVICES=",".join(device["id"] for device in devices),
               STORE_ASSET_SCENES=",".join(scene["id"] for scene in scenes),
               FLUTTER_SUPPRESS_ANALYTICS="true", DART_SUPPRESS_ANALYTICS="true")
    try:
        subprocess.run(["flutter", "test", "tool/store_assets/compose_marketing.dart", "--run-skipped", "--no-pub"], cwd=REPO_ROOT, env=env, check=True)
    except FileNotFoundError as error:
        raise AssetError("Flutter is not available on PATH.") from error
    except subprocess.CalledProcessError as error:
        raise AssetError(f"Flutter composition failed (exit {error.returncode}). Completed PNGs were retained; retry the same selection with --overwrite.") from error
    for item, target in zip(entries, targets):
        if not target.is_file():
            raise AssetError(f"Composition did not produce {target}")
        normalize_rgb(target)
        verify_image(target, item["width"], item["height"])
    validate_marketing_index(output, entries)
    return {"marketingScreenshots": len(entries), "output": str(output), "renderer": "flutter-marketing-compositor", "uploaded": False}


def crop_focal(source, item: dict, focal_point: tuple[float, float]):
    """Cover the canvas, putting a source focal point near the safe-area center."""
    Image, _ = pillow()
    width, height = item["width"], item["height"]
    scale = max(width / source.width, height / source.height)
    crop_width, crop_height = width / scale, height / scale
    rect = item.get("safeRect")
    center_x = rect["x"] + rect["width"] / 2 if rect else width / 2
    center_y = rect["y"] + rect["height"] / 2 if rect else height / 2
    focal_x, focal_y = source.width * focal_point[0], source.height * focal_point[1]
    left = min(max(focal_x - center_x / scale, 0), source.width - crop_width)
    top = min(max(focal_y - center_y / scale, 0), source.height - crop_height)
    box = (left, top, left + crop_width, top + crop_height)
    image = source.resize((width, height), resample=Image.Resampling.LANCZOS, box=box)
    actual = {"x": round((focal_x - left) * scale, 2), "y": round((focal_y - top) * scale, 2)}
    return image, actual


def save_review_guide(image, item: dict, path: Path) -> None:
    from PIL import ImageDraw
    guide = image.copy()
    draw = ImageDraw.Draw(guide)
    rect = item.get("safeRect")
    if rect:
        line_width = max(3, image.width // 500)
        draw.rectangle((rect["x"], rect["y"], rect["x"] + rect["width"] - 1, rect["y"] + rect["height"] - 1), outline=(80, 255, 180), width=line_width)
    actual = item["focalPointPixels"]
    radius = max(12, image.width // 180)
    x, y = actual["x"], actual["y"]
    draw.line((x - radius, y, x + radius, y), fill=(255, 90, 170), width=3)
    draw.line((x, y - radius, x, y + radius), fill=(255, 90, 170), width=3)
    path.parent.mkdir(parents=True, exist_ok=True)
    guide.save(path, "PNG")


def export_creatives(config: dict, output: Path, languages: list[dict], source_path: Path, overwrite: bool, focal_point: tuple[float, float] = (0.5, 0.5)) -> dict:
    Image, ImageOps = pillow()
    entries = creative_entries(config)
    index_path = target_file(output, "creative-manifest.json")
    targets = [target_file(output, item["path"]) for item in entries]
    guides = [target_file(output, f"review-guides/{item['id']}-safe-area.png") for item in entries]
    ensure_writable([*targets, *guides, index_path], overwrite)
    output_paths = [*targets, *guides, index_path]
    if any(source_path.resolve() == path.resolve() or (source_path.is_file() and path.is_file() and source_path.samefile(path)) for path in output_paths):
        raise AssetError("Creative source must be separate from output files.")
    try:
        with Image.open(source_path) as original:
            if original.format != "PNG":
                raise AssetError("Use a PNG source for creative export.")
            original.load()
            source = ImageOps.exif_transpose(original).convert("RGB")
    except (OSError, ValueError) as error:
        raise AssetError(f"Cannot read creative source: {error}") from error
    source_hash = digest(source_path)
    for target, item, guide in zip(targets, entries, guides):
        target.parent.mkdir(parents=True, exist_ok=True)
        image, actual = crop_focal(source, item, focal_point)
        image.save(target, "PNG")
        item.update(sha256=digest(target), bytes=target.stat().st_size, focalPointPixels=actual)
        save_review_guide(image, item, guide)
    manifest = {"schemaVersion": 1, "kind": "app-store-creatives", "sourceSha256": source_hash,
                "transform": "safe-area-focal-cover-crop-lanczos-rgb", "sourceFocalPoint": list(focal_point), "assets": entries,
                "localizations": {lang["appStoreLocale"]: {item["id"]: item["path"] for item in entries} for lang in languages},
                "notes": ["Shared text-free artwork; each selected locale references the same files.",
                          "Safe rectangles are guidance for important subjects, not automatic content validation.",
                          "review-guides/ images contain overlays for review only; never upload them.",
                          "Manually inspect Apple overlays/crops before uploading. No assets were uploaded."]}
    save_json(index_path, manifest)
    return {"creatives": len(entries), "locales": len(languages), "output": str(output), "uploaded": False}


def selected_entries(config: dict, languages: list[dict], devices: list[dict], kind: str, scenes: list[dict] | None = None, config_path: Path | None = None) -> list[dict]:
    if kind == "google-play":
        return google_play_entries(config, config_path or SCRIPT_DIR / "config.json", languages, devices, scenes)
    entries = []
    if kind in ("all", "screenshots"):
        entries.extend(shot_entries(config, languages, devices, scenes))
    if kind in ("all", "marketing"):
        entries.extend(marketing_entries(config, languages, devices, scenes))
    if kind in ("all", "creatives"):
        entries.extend(creative_entries(config))
    return entries


def validate(config: dict, output: Path, languages: list[dict], devices: list[dict], kind: str, scenes: list[dict] | None = None, config_path: Path | None = None) -> dict:
    if kind == "google-play":
        return validate_google_play(config, config_path or SCRIPT_DIR / "config.json", output, languages, devices, scenes)
    entries = selected_entries(config, languages, devices, kind, scenes)
    errors = []
    for item in entries:
        try:
            verify_image(target_file(output, item["path"]), item["width"], item["height"])
        except AssetError as error:
            errors.append(str(error))
    if kind in ("all", "marketing"):
        try:
            validate_marketing_index(output, marketing_entries(config, languages, devices, scenes))
        except AssetError as error:
            errors.append(str(error))
    if errors:
        raise AssetError("Validation failed:\n" + "\n".join(errors[:20]) + (f"\n... and {len(errors) - 20} more errors" if len(errors) > 20 else ""))
    return {"validatedImages": len(entries), "kind": kind, "output": str(output), "uploaded": False}


def package(config: dict, output: Path, languages: list[dict], devices: list[dict], kind: str, overwrite: bool, scenes: list[dict] | None = None, config_path: Path | None = None) -> dict:
    validate(config, output, languages, devices, kind, scenes, config_path)
    entries = selected_entries(config, languages, devices, kind, scenes, config_path)
    name = f"my-bar-{kind}"
    archive_path = target_file(output, f"{name}.zip")
    manifest_path = target_file(output, f"{name}-manifest.json")
    ensure_writable([archive_path, manifest_path], overwrite)
    files = [{**item, "sha256": digest(target_file(output, item["path"])), "bytes": target_file(output, item["path"]).stat().st_size} for item in entries]
    upload_sequence = None
    if kind == "marketing":
        upload_sequence = load_marketing_copy(config, config_path or SCRIPT_DIR / "config.json")["sequence"]
        positions = {scene: index + 1 for index, scene in enumerate(upload_sequence)}
        for item in files:
            sequence = positions[item["screen"]]
            label = re.sub(r"^\d+-", "", item["screen"])
            item.update(sequence=sequence, archivePath=f"{item['locale']}/{item['device']}/{sequence:02d}-{label}.png")
        files.sort(key=lambda item: (item["locale"], item["device"], item["sequence"]))
    elif kind == "google-play":
        upload_sequence = load_marketing_copy(config, config_path or SCRIPT_DIR / "config.json")["sequence"]
        for item in files:
            item["archivePath"] = item["path"].removeprefix("google-play/")
    capture_provenance = {
        "renderer": "flutter-widget", "nativeDeviceCapture": False,
        "fontFallback": "offline Noto fixture replaces OS text fallback",
        "note": "Offscreen responsive layout previews, not physical-device or iPhone Duo simulator captures. Safe-area fixtures require device QA.",
    }
    if kind == "google-play":
        capture_provenance["note"] = "Offscreen real Android Flutter-widget layouts, not native emulator/physical-device captures. Android safe-area fixtures require device QA."
    for item in files:
        if item["path"].startswith("screenshots/"):
            item.update(capture_provenance)
        elif item["path"].startswith("marketing/"):
            item.update(capture_provenance, renderer="flutter-marketing-compositor", sourceUiEdited=False,
                        sourceUiCropped=False, deviceFrame="generic rounded frame; no hardware claims")
    metadata = []
    metadata_names = []
    if kind in ("all", "screenshots"):
        metadata_names.append("capture-manifest.json")
    if kind in ("all", "marketing"):
        metadata_names.append("marketing-manifest.json")
    if kind in ("all", "creatives"):
        metadata_names.append("creative-manifest.json")
    if kind == "google-play":
        metadata_names.append("google-play-manifest.json")
    for relative in metadata_names:
        path = target_file(output, relative)
        if path.exists():
            try:
                content = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError) as error:
                raise AssetError(f"Cannot package invalid metadata {path}: {error}") from error
            if not isinstance(content, dict):
                raise AssetError(f"Package metadata must be a JSON object: {path}")
            metadata.append({"path": relative, "sha256": digest(path), "bytes": path.stat().st_size})
    manifest = {"schemaVersion": 1, "app": config.get("app", "My Bar"), "kind": kind,
                "renderer": "android-google-play-export" if kind == "google-play" else "flutter-marketing-compositor" if kind == "marketing" else "flutter-widget" if kind != "creatives" else None,
                "provenance": capture_provenance if kind != "creatives" else {"kind": "marketing-artwork", "deviceCapture": False},
                "locales": [{"language": lang["code"], "appStore": lang["appStoreLocale"], "googlePlay": lang.get("googlePlayLocale")} for lang in languages],
                "files": files, "imageCount": len(files), "metadata": metadata,
                "metadataCount": len(metadata), "uploaded": False,
                **({"uploadSequence": upload_sequence,
                    "archivePathPolicy": "google-play-locale/device-type/story-sequence-scene.png; source files retain canonical path" if kind == "google-play" else "locale/device/marketing-sequence-scene.png; source files retain canonical path"} if upload_sequence is not None else {})}
    # A stable manifest and fixed ZIP timestamps make repeat exports reproducible.
    save_json(manifest_path, manifest)
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path, relative in [(manifest_path, manifest_path.name), *[(target_file(output, item["path"]), item.get("archivePath", item["path"])) for item in [*files, *metadata]]]:
            info = zipfile.ZipInfo(str(relative), date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    return {"archive": str(archive_path), "manifest": str(manifest_path), "files": len(files) + len(metadata) + 1, "images": len(files), "metadata": len(metadata), "sha256": digest(archive_path), "uploaded": False}


def parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--config", type=Path, default=SCRIPT_DIR / "config.json")
    common.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    common.add_argument("--languages", help="Comma-separated app codes, e.g. en,ru,ar. Default: all configured languages.")
    common.add_argument("--devices", help="Comma-separated device IDs. Default: enabled iOS profiles; Google Play export/validation/packaging use Android profiles.")
    common.add_argument("--scenes", help="Comma-separated scene IDs, e.g. 03-recipe,07-almost-ready. Default: all enabled scenes.")
    common.add_argument("--json", action="store_true", help="Print the result as JSON.")
    root = argparse.ArgumentParser(description=__doc__, epilog="Only explicit prepare-fonts downloads pinned free fonts. All other commands are offline. No authentication or upload command exists.")
    commands = root.add_subparsers(dest="command", required=True)
    commands.add_parser("list", parents=[common], help="List supported languages, devices and output sizes.")
    commands.add_parser("plan", parents=[common], help="Preview selected screenshot paths without writing files.")
    capture_parser = commands.add_parser("capture", parents=[common], help="Render real app widgets at each target viewport; no simulator required.")
    capture_parser.add_argument("--overwrite", action="store_true")
    compose_parser = commands.add_parser("compose", parents=[common], help="Compose localized upload-ready marketing screenshots from unchanged captured UI.")
    compose_parser.add_argument("--overwrite", action="store_true")
    google_play = commands.add_parser("export-google-play", parents=[common], help="Copy Android phone marketing and app-only tablets to ordered Google Play locale folders.")
    google_play.add_argument("--overwrite", action="store_true")
    creatives = commands.add_parser("export-creatives", parents=[common], help="Create opaque PNG header/search/universal crops from one PNG source.")
    creatives.add_argument("--source", required=True, type=Path)
    creatives.add_argument("--focal-point", type=parse_focal_point, default=(0.5, 0.5), metavar="X,Y", help="Normalized source focal point (0..1), default 0.5,0.5. Crop keeps it near each safe-area center when possible.")
    creatives.add_argument("--overwrite", action="store_true")
    for command in ("validate", "package"):
        child = commands.add_parser(command, parents=[common], help="Validate image dimensions/color." if command == "validate" else "Create a local ZIP with SHA-256 manifest.")
        child.add_argument("--kind", choices=("all", "screenshots", "marketing", "creatives", "google-play"), default="all", help="all includes raw screenshots, marketing screenshots and Apple creatives; use google-play for the Android upload set.")
        if command == "package":
            child.add_argument("--overwrite", action="store_true")
    commands.add_parser("check-fonts", parents=[common], help="Check configured local font files and optional SHA-256 hashes; never downloads.")
    font_parser = commands.add_parser("prepare-fonts", parents=[common], help="Explicit opt-in HTTPS download of pinned free fonts to the local cache.")
    font_parser.add_argument("--font-sources", type=Path, help="Default: font_sources.json next to the config.")
    return root


def parse_focal_point(value: str) -> tuple[float, float]:
    try:
        parts = tuple(float(part.strip()) for part in value.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("Use X,Y coordinates between 0 and 1.") from error
    if len(parts) != 2 or any(not 0 <= part <= 1 for part in parts):
        raise argparse.ArgumentTypeError("Use X,Y coordinates between 0 and 1.")
    return parts


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        config_path = args.config.expanduser().resolve()
        config = load_config(config_path)
        languages = select(config["languages"], args.languages, "code", "languages")
        device_selection = args.devices
        if device_selection is None and (args.command == "export-google-play" or getattr(args, "kind", None) == "google-play"):
            device_selection = ",".join(device["id"] for device in config["devices"] if device.get("platform") == "android")
        devices = select(config["devices"], device_selection, "id", "devices")
        scenes = select(config["screenshots"], args.scenes, "id", "scenes")
        output = safe_output(args.output)
        if args.command == "list":
            result = {"languages": config["languages"], "devices": config["devices"], "scenes": config["screenshots"], "creatives": config["creatives"], "notes": config.get("notes", [])}
        elif args.command == "plan":
            entries = shot_entries(config, languages, devices, scenes)
            result = {"output": str(output), "languages": len(languages), "devices": len(devices), "scenes": len(scenes), "screenshots": len(entries), "files": entries,
                      "marketingFiles": marketing_entries(config, languages, devices, scenes), "uploaded": False}
        elif args.command == "capture":
            result = capture(config, config_path, output, languages, devices, args.overwrite, scenes)
        elif args.command == "compose":
            result = compose(config, config_path, output, languages, devices, args.overwrite, scenes)
        elif args.command == "export-google-play":
            result = export_google_play(config, config_path, output, languages, devices, args.overwrite, scenes)
        elif args.command == "export-creatives":
            result = export_creatives(config, output, languages, args.source.expanduser().resolve(), args.overwrite, args.focal_point)
        elif args.command == "validate":
            result = validate(config, output, languages, devices, args.kind, scenes, config_path)
        elif args.command == "package":
            result = package(config, output, languages, devices, args.kind, args.overwrite, scenes, config_path)
        elif args.command == "prepare-fonts":
            result = prepare_fonts(config_path, args.font_sources.expanduser().resolve() if args.font_sources else None)
        else:
            errors = font_errors(config, config_path)
            if errors:
                raise AssetError("\n".join(errors))
            result = {"fonts": len(config.get("fonts", [])), "validated": True, "downloaded": False}
        if args.json or args.command == "list":
            print(json.dumps(result, ensure_ascii=False, indent=2))
        elif args.command == "plan":
            print(f"{result['languages']} languages × {result['devices']} devices × {result['scenes']} screens = {result['screenshots']} PNGs per raw/marketing set")
            print(f"Output: {output}\nRenderer: real Flutter widgets (not physical-device captures). No uploads.")
            for device in devices:
                print(f"  {device['id']}: {device['width']} × {device['height']} px @ {device['pixelRatio']}x")
        else:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (AssetError, OSError) as error:
        print(f"store-assets: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
