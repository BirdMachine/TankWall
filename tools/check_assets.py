#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fish_dir = root / "godot_project" / "assets" / "fish"
background_dir = root / "godot_project" / "assets" / "backgrounds"
print("Fish assets:")
for p in sorted(fish_dir.glob("*")):
    print(" -", p.name)
print("Background assets:")
for p in sorted(background_dir.glob("*")):
    print(" -", p.name)
