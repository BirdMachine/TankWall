#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/install-godot-headless.py
mkdir -p godot_project/build/android

cat <<'MSG'

TankWall Codespace is ready 🐟
- Godot: /usr/local/bin/godot
- Android SDK: /opt/android-sdk
- Build: bash scripts/build-android-debug.sh

The current milestone builds a normal Android Godot APK first. Native live-wallpaper service wiring comes next.
MSG
