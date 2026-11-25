#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/godot_project"
OUT="$PROJECT/build/android/TankWall-debug.apk"
mkdir -p "$(dirname "$OUT")"

if ! command -v godot >/dev/null 2>&1; then
  echo "Godot not found. In Codespaces run: bash scripts/setup-codespaces.sh" >&2
  exit 1
fi

# Expand redistributable third-party model archives before Godot imports the
# project. If an optional vendor archive is absent, the procedural fallback fish
# remains available.
python3 "$ROOT/scripts/install-vendor-models.py"
python3 "$ROOT/scripts/install-android-template.py"

# Build the pinned wallpaper bridge from auditable source. Its generated AARs
# are ignored; the paid fish pack is never fetched or uploaded by CI.
"$PROJECT/android/build/gradlew" -p "$ROOT/android/livewallpaper" \
  :plugin:assembleDebug :plugin:assembleRelease --no-daemon --console=plain
mkdir -p "$PROJECT/addons/TamoTankWallpaper/bin"
cp "$ROOT/android/livewallpaper/plugin/build/outputs/aar/plugin-debug.aar" "$PROJECT/addons/TamoTankWallpaper/bin/wallpaper-debug.aar"
cp "$ROOT/android/livewallpaper/plugin/build/outputs/aar/plugin-release.aar" "$PROJECT/addons/TamoTankWallpaper/bin/wallpaper-release.aar"

cd "$PROJECT"
# Import and validate the project. Do not hide scene/script errors: a green
# workflow should mean the exported APK can actually load its main scene.
godot --headless --editor --quit --path .
godot --headless --path . --export-debug "Android" "$OUT"

echo "APK written to $OUT"
