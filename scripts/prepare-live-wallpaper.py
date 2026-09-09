#!/usr/bin/env python3
"""Prepare the Godot Android live-wallpaper integration for local/CI builds.

This pins TheOathMan/Godot-Android-Live-Wallpaper v1.5.1 and installs the
matching Godot Gradle Android source template into res://android/build.
"""
from __future__ import annotations

import hashlib
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot_project"
PLUGIN_DIR = PROJECT / "addons" / "Android" / "LiveWallpaper"
ANDROID_BUILD = PROJECT / "android" / "build"
PLUGIN_URL = (
    "https://github.com/TheOathMan/Godot-Android-Live-Wallpaper/"
    "releases/download/v1.5.1/GodotLiveWallpaperPlugin.zip"
)
PLUGIN_SHA256 = "0bfc928515cf1ba8f7127754a2d28e995f508145aadd35d7a5ebdf8f2153a6b2"


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "tankwall-live-wallpaper-setup"})
    with urllib.request.urlopen(req, timeout=120) as src, dest.open("wb") as out:
        shutil.copyfileobj(src, out)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def install_plugin() -> None:
    marker = PLUGIN_DIR / "plugin.cfg"
    if marker.exists():
        print(f"LiveWallpaper plugin already present: {PLUGIN_DIR}")
        return
    with tempfile.TemporaryDirectory() as td_name:
        archive = Path(td_name) / "GodotLiveWallpaperPlugin.zip"
        print("Downloading pinned LiveWallpaper plugin v1.5.1")
        download(PLUGIN_URL, archive)
        actual = sha256(archive)
        if actual != PLUGIN_SHA256:
            raise RuntimeError(f"LiveWallpaper plugin checksum mismatch: {actual}")
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(PROJECT)
    if not marker.exists():
        raise RuntimeError(f"Plugin archive did not create expected file: {marker}")


def find_android_source_zip() -> Path:
    candidates = sorted(
        (Path.home() / ".local" / "share" / "godot" / "export_templates").glob("*/android_source.zip"),
        reverse=True,
    )
    if not candidates:
        raise RuntimeError("android_source.zip not found; install matching Godot export templates first")
    return candidates[0]


def install_gradle_template() -> None:
    if (ANDROID_BUILD / "build.gradle").exists() or (ANDROID_BUILD / "build.gradle.kts").exists():
        print(f"Godot Android Gradle template already present: {ANDROID_BUILD}")
        return

    source_zip = find_android_source_zip()
    print(f"Installing Godot Android Gradle template from {source_zip}")
    with tempfile.TemporaryDirectory() as td_name:
        td = Path(td_name)
        with zipfile.ZipFile(source_zip) as zf:
            zf.extractall(td)
        roots = [p.parent for p in td.rglob("build.gradle") if p.parent.name in {"android_source", "build"}]
        roots += [p.parent for p in td.rglob("build.gradle.kts") if p.parent.name in {"android_source", "build"}]
        if not roots:
            # Stable Godot templates normally extract directly as an Android project.
            roots = [td]
        source_root = roots[0]
        ANDROID_BUILD.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source_root, ANDROID_BUILD, dirs_exist_ok=True)

    if not ((ANDROID_BUILD / "build.gradle").exists() or (ANDROID_BUILD / "build.gradle.kts").exists()):
        raise RuntimeError("Failed to install a usable Godot Android Gradle build template")


def main() -> None:
    install_plugin()
    install_gradle_template()
    print("Live wallpaper Android integration prepared.")


if __name__ == "__main__":
    main()
