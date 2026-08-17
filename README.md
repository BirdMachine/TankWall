# TankWall Live Wallpaper

A Godot-for-Android successor to the classic betta live wallpaper idea, built around user-selected media backgrounds, multiple fish choices, and eventually up to three fish swimming at once.

## Current scaffold

- Godot 4 aquarium scene using the mobile-friendly Compatibility renderer.
- Placeholder fish mesh + procedural swim controller.
- Fish count architecture already supports 1–3 fish.
- Settings fields prepared for solid color, image, GIF-frame, and video backgrounds.
- Android export preset using package `com.birdmachine.tankwall`.
- GitHub Codespaces devcontainer with Java + Android SDK.
- Codespace bootstrap script that installs stable Godot 4 and matching export templates.
- GitHub Actions smoke check for the expected project shape.

## Open it in Codespaces

From this repository choose:

`Code → Codespaces → Create codespace on main`

The devcontainer runs `scripts/setup-codespaces.sh` automatically. After setup finishes, build with:

```bash
bash scripts/build-android-debug.sh
```

Expected output:

```text
godot_project/build/android/TankWall-debug.apk
```

## Important milestone split

The first milestone is a normal Android Godot APK so we can validate rendering, fish animation, settings, media backgrounds, and performance. The next milestone is native Android `WallpaperService` / Godot plugin wiring so Android exposes TankWall in the live-wallpaper picker.

## Near-term roadmap

1. Make the placeholder aquarium APK build reproducibly in Codespaces.
2. Add the Android live-wallpaper service/plugin.
3. Add the settings UI and Android file picker for solid/image/GIF/video backgrounds.
4. Replace the placeholder fish with a licensed, properly rigged betta model.
5. Add fish/model selection and independent behavior for up to three fish.
6. Add battery/performance controls, touch interaction, lighting, bubbles, and optional tank dressing.

See `docs/FEATURE_SPEC.md` and `assets/model_research/BETTA_MODEL_CANDIDATES.md` as those land.
