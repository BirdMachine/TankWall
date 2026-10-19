# Fishy swimming beta — 2026-10-19

This beta targets the fish in TankWall. TamoTank integration, companion zones and
the live-wallpaper branches are separate work. No assets or services were bought.

## What was wrong

The runtime used BlueMesh's `Take 01` animation as its entire swim system. The
glTF clip also translates and rotates the source `Cube` parent. On top of that,
the old adapter mapped source axes without compensating for the Sketchfab axis
conversion already embedded in the imported scene. Locomotion could therefore
steer one frame while the rendered animal moved in a different frame. There
was no additional torso bend or fin response to actual steering.

## Implemented

- Retain the actual volumetric BlueMesh body, textured skin and 53-joint rig.
- Disable the baked clip and its root motion. Normalize placement from the
  actual skeleton transform, level the rest-pose body and hide source helpers.
- Drive five torso joints with a caudally traveling wave. Amplitude increases
  toward the tail; each joint gets a different rest-relative orientation.
- Add sustained body curvature from measured turning velocity and a small
  pitch response. Rotations use the joint's actual rest axes, rather than
  assuming all bones share local axes.
- Give caudal, dorsal, anal, pelvic, pectoral and gill chains separate motion.
  Fin rays use phase offsets, softer distal response, damped spring angles,
  stroke-velocity drag and subtle out-of-plane cupping. Pectoral activity
  increases at low forward speed.
- Use predictive boundary steering and slightly varying cruising effort.
  The controller still integrates forward speed; this is procedural animation
  with drag-inspired secondary motion, not fluid dynamics or force-derived
  propulsion.
- Reduce default fish size/depth travel for portrait framing, center the initial
  spawn, add ambient fill, and reduce overexposed directional lighting.
- Add an Android Swim Beta export preset with a separate package ID:
  `com.birdmachine.tankwall.swimbeta`. It installs beside regular TankWall.
- Preserve the CC BY source credit in the repository and add an in-app credit.

## Free approaches researched

| Source | What it offers | Decision for this beta |
| --- | --- | --- |
| [Godot fish vertex-animation tutorial](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html) | Vertex waves, twisting and posterior masking; efficient schooling with MultiMesh | Good low-cost route for many fish. Our existing fin skeleton makes native skeletal deformation more controllable for this single close-up betta. |
| [FishSim](https://github.com/nerk987/FishSim) | Blender target-following, effort, mass/drag, tail steering, fin stiffness/phase and pectoral hovering | Useful offline rig/bake workflow; existing TankWall experiments already target it. An offline baked trajectory does not directly solve interactive turns, so no FishSim code was copied into the runtime. |
| [frankiezafe/Fish-shader](https://github.com/frankiezafe/Fish-shader) | MIT shader-based fish animation without an armature | Useful reference for a future lightweight alternative. A full shader replacement is unnecessary while the licensed rig supports deformation. No code imported. |
| [Qhunliv13/Procedural-fish-in-godot](https://github.com/Qhunliv13/Procedural-fish-in-godot) | MIT GPU compute bone calculation and chain IK | Interesting for more complex procedural fish. Compute introduces a rendering/backend change relative to TankWall's OpenGL Compatibility target; not adopted. |
| [SimFish / walstad loom](https://github.com/mhsenkow/SimFish) | Large ecosystem simulation, schooling, behavior and voxel/pixel rendering | Useful behavioral reference; too broad a dependency and a different visual target for this repair. Not imported. |
| [BlueMesh Betta Splendens](https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b) | Already-vendored CC BY 4.0 animated/skinned betta | Chosen free asset; keep its textures and topology, replace the motion driver. |

Research pages describe capabilities; they are not evidence that a library
would produce the requested appearance without adaptation. This beta's motion
code is original; no donor engine/add-on was added as a dependency.

## Paid option parked

[junnichis — Betta fish](https://www.cgtrader.com/3d-models/animal/fish/betta):
the retrieved page displayed **$11 sale / $22 regular**, a rigged and animated
Blender 2.79 asset with 3,616 polygons and PNG textures. The page also marks
“Plugins Used”; compatibility and the supplied motion would need inspection
before purchase. Metadata still lists $22, so the sale/checkout price is not
guaranteed. No purchase, download or integration was made. This is an option,
not a verified improvement over the free fish.

## Verification and reproducing the preview

Validated with Godot **4.5.1**, OpenGL Compatibility and software rendering:

Android CI pins the same engine version and explicitly requests `platform-tools`
instead of the setup action's obsolete default `tools` package. It uses the
prebuilt Android template, so it does not download the NDK/CMake toolchains.

```bash
python3 scripts/install-vendor-models.py
godot --headless --editor --path godot_project --quit
godot --headless --path godot_project --script res://tests/test_swim.gd
godot --headless --path godot_project --export-debug "Android Swim Beta"
```

The integration test requires the real imported skin, checks that root animation
is disabled, measures torso and tail displacement, verifies distinct segment
orientations and unchanged bone translations/scales, compares fin integration
at 30/60/120 Hz, checks pause stability, and runs 30 seconds of real locomotion
in a portrait-sized tank. It is included in Android CI.

Observed results: torso lateral sweep **0.269** source units; tail-ray sweep
**1.895** source units; distal spring angles after 3 seconds at 30/60/120 FPS
**0.0885 / 0.0851 / 0.0833** radians; **0/1800** wall-pinned frames, and
minimum displacement/heading alignment **0.9999998**. These are regression
measurements, not biological accuracy or Android performance benchmarks.

Actual runtime-rig inspection (4 s side profile, 6 s orbit under turn load,
4 s low-effort fin motion) can be recorded with:

```bash
godot --path godot_project --fixed-fps 30 --resolution 900x900 \
  --write-movie /absolute/existing/directory/swim.avi \
  --script res://scripts/SwimShowcase.gd
```

Add `-- --tank` for the real Main scene, camera and autonomous controller in
portrait framing. The default inspection rotates the root deliberately to
expose the geometry; it is not a recording of autonomous locomotion. The saved
preview labels those two segments separately.

Android export was signed and verified with APK Signature Scheme v2/v3.
Rendered frames were visually inspected from side, oblique and near-end-on
angles. No physical S21 Ultra or Android emulator runtime/performance check was
performed in this session. The beta remains a normal app; this branch does not
merge the separate wallpaper-service work. Existing fins still use their
original topology and ray count; more elaborate membrane folds would require
additional mesh/rig work. Device testing and the user's visual judgment remain
the acceptance gate for realistic swimming.
