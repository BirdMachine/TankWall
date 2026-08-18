#!/usr/bin/env python3
"""Install redistributable vendor model archives into the Godot project.

This keeps third-party source archives intact in assets/vendor/ while exposing a
normal Godot-importable directory under godot_project/assets/models/.
"""
from __future__ import annotations

import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MODELS = [
    {
        "name": "BlueMesh Betta Splendens",
        "archive": ROOT / "assets/vendor/bluemesh_betta/betta_splendens.zip",
        "dest": ROOT / "godot_project/assets/models/bluemesh_betta",
        "required": ["scene.gltf", "scene.bin", "textures/BETTA_baseColor.png"],
    },
]


def install_model(model: dict) -> bool:
    archive: Path = model["archive"]
    dest: Path = model["dest"]
    required = [dest / p for p in model["required"]]

    if all(p.exists() for p in required):
        print(f"Vendor model ready: {model['name']} -> {dest}")
        return True

    if not archive.exists():
        print(f"Vendor model archive not present: {archive}")
        return False

    print(f"Installing {model['name']} from {archive}")
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(archive) as zf:
        zf.extractall(dest)

    missing = [str(p) for p in required if not p.exists()]
    if missing:
        raise RuntimeError(f"{model['name']} archive is missing expected files: {missing}")

    print(f"Installed {model['name']} -> {dest}")
    return True


def main() -> None:
    installed = 0
    for model in MODELS:
        installed += int(install_model(model))
    print(f"Vendor models available: {installed}/{len(MODELS)}")


if __name__ == "__main__":
    main()
