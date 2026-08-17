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

cd "$PROJECT"
godot --headless --editor --quit --path . || true
godot --headless --path . --export-debug "Android" "$OUT"

echo "APK written to $OUT"
