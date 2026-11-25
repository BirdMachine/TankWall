# TamoTank / TankWall

A gentle betta companion for Android, growing toward a live wallpaper. Care is optional and additive: the resident stays safe and content while you are away.

## Deep fin folds 0.11

[Deeper live folds](docs/DEEP_FIN_FOLDS.md) increase outer-fin freedom and add a
saved **Fin freedom** slider. A comparison keeps the previous 0.10 live profile
available alongside the stronger deformation through identical turns.

## Reactive fins 0.10
The [reactive fins prototype 0.10](docs/LIVE_FIN_PHYSICS.md) adds an optional
live cloth-proxy layer to the purchased fins, with a recorded-motion comparison
and tests for the actual rigs. It retains the companion and wallpaper views.

## Living aquarium 0.9

The current nightflight adds Showcase / 3D Tank views, a solid backwall picker, local fish personalities, two privately installed purchased models, and Android live-wallpaper integration. See [the implementation and validation notes](docs/LIVING_AQUARIUM.md). Paid model sources are excluded from this public repository; CI uses the redistributable fallback.

## Companion preview 0.8

Name your fish, offer a snack it swims over to eat, play follow-the-finger, make the water sparkle, or settle in for a quiet rest. Shared moments grow a persistent friendship and memory book. Four soft colour tints are available. There are no declining needs, absence penalties, streaks, sickness or death.

The companion APK installs separately as `com.birdmachine.tamotank.companion`. Tap the fish's name to rename it; use **Play**, then hold or drag in the water to invite it over. **Rest / Wake** changes the lighting and motion without changing progress. See [the care design and validation](docs/GENTLE_COMPANION.md).

This preview uses the modified BlueMesh fish. The purchased Gusai pack is awaiting private download and rig integration; it is not included in this build.

## Fishy swimming beta

The `codex/fishy-swimming-beta` branch replaces the bundled model motion with
traveling torso flexion, steering curvature and spring-driven fin chains on the
existing 53-joint BlueMesh betta. The Android Swim Beta export preset installs
beside regular TankWall. See [research, implementation and validation notes](docs/FISHY_SWIMMING_BETA.md).

The [corner-motion nightflight](docs/CORNER_NIGHTFLIGHT.md) continues this rig
with turns in three dimensions, preparatory fin folding, and a committed exit
from the glass. It includes repeatable before/after footage and corner tests.

The [body-volume rework](docs/BODY_VOLUME_REWORK.md) replaces planar torso
motion and linear transform blending with compound flex/torsion and dual
quaternion skinning, including an inspection with the fins hidden.

The [front-flex and wet-skin pass](docs/FRONT_FLEX_WET_SKIN.md) adds a small
anterior bend with coherent head motion and a smoother, coated body material.
Its [model-source investigation](docs/BETTA_MODEL_PROVENANCE.md) records the
archived BETTA 120Hz asset inventory and independently available alternatives.

## Current foundation

- Godot 4 aquarium scene using the mobile-friendly Compatibility renderer.
- Rigged BlueMesh fish, volumetric deformation, coated skin and procedural swimming.
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

The normal companion app and the Android live wallpaper share the Godot aquarium scene. Foreground care owns saved progress; a separate wallpaper process reads the resident and preferences without writing care data. Wallpaper lifecycle and launcher behaviour need native validation alongside the rendering tests.

## Near-term roadmap

1. Expand texture choices and review the purchased rigs on the phone.
2. Validate wallpaper previews, visibility, rotation and launcher behaviour.
3. Add Android background media selection.
4. Expand optional play, memories and tank dressing.
5. Add battery/performance controls and real-device checks.

See `docs/FEATURE_SPEC.md` and `assets/model_research/BETTA_MODEL_CANDIDATES.md` as those land.
