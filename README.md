# BettaBloom Live Wallpaper

Successor concept for a betta live wallpaper: custom background image/GIF/video/solid color, multiple fish skins/models, and up to 3 fish in the scene.

This repository contains:

- `godot_project/` — Godot 4 project scaffold for the aquarium scene.
- `.devcontainer/` — GitHub Codespaces environment with Java, Android SDK, and automatic Godot install.
- `android_wrapper/` — Android live wallpaper wrapper notes/stub structure.
- `assets/model_research/` — sourced betta model candidates and licensing notes.
- `scripts/` — setup/build helpers.
- `tools/` — helper scripts for adding backgrounds and checking model files.

## Codespaces

See `docs/CODESPACES.md`.

Fast path once this is in GitHub:

```bash
bash scripts/build-android-debug.sh
```

The output target is:

```text
godot_project/build/android/BettaBloom-debug.apk
```

## Important build note

The original sandbox did not include Godot/Android SDK/Gradle, so no real APK was generated there. The Codespaces devcontainer is designed to install the required tooling on first boot.

## Live wallpaper status

The project currently exports as a normal Android Godot app first. The next milestone is adding the Godot Android live wallpaper plugin/service wiring so Android recognizes it as a wallpaper provider.

See `docs/BUILD_ANDROID.md` and `docs/FEATURE_SPEC.md`.
