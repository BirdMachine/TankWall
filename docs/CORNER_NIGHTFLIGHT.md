# Corner-motion nightflight — 2026-11-22

This pass continues the 3D rig in `BirdMachine/TankWall` from `070425f` on
`codex/fishy-swimming-beta`. `BirdMachine/TamoTank/main` is still the separate
Kotlin/Compose 2D companion aquarium (`f2ff603`). This work does not port the
3D renderer into that app or add Android wallpaper-service wiring.

## Reference review

Recovered and visually inspected Birdie's five BETTA 120Hz screen recordings,
re-uploaded on 2026-10-28:

| Recording | Duration | Useful motion |
| --- | --- | --- |
| `az_recorder_20260818_093600_1.mp4` | 5.04 s | Broadside to narrow silhouette, followed by descent and another turn |
| `az_recorder_20260818_093600_2.mp4` | 6.32 s | Compact turns and changing fin overlap |
| `az_recorder_20260818_093600_3.mp4` | 4.30 s | Close profile travel, banking and fan overlap |
| `az_recorder_20260818_093600_4.mp4` | 10.19 s | Repeated turns and movement through the portrait frame |
| `az_recorder_20260818_093650_edited_1.mp4` | 2.75 s | Especially useful compact turn: broad fan, folded silhouette, then descent |

Durations are container timestamps, not measured biological timing. The older
`TankWall-Tight-Turns.mp4` was also inspected; it is an implementation preview,
not live-fish evidence. The BETTA archive is an app/source dump, not the missing
reference video. No app code or assets from that archive were used.

[Real betta aquarium footage by FalkinsOG](https://commons.wikimedia.org/wiki/File:Betta_fish_in_aquarium.webm)
was downloaded and visually inspected, including a denser sequence around
27–38 s. It shows a broadside hover, forward movement and a downward turn;
the long fins change apparent area and overlap through the manoeuvre. This is
useful shape/transition evidence, not a calibrated tight-corner experiment.
The clip is credited CC BY-SA 4.0; it is not bundled in the app or our preview.

The technical background is [Flammang et al., *Functional Morphology of the
Fin Rays of Teleost Fishes*, DOI 10.1002/jmor.20161](https://websites.umich.edu/~alben/jmor20161.pdf).
That study concerns **bluegill**, not bettas. It supports flexible, deforming
fin rays and different motion across behaviours. It does not supply betta
turn durations or validate our procedural coefficients. New stock results
explicitly labelled AI-generated were excluded as motion evidence.

## Changes

- Use the full 3D heading error for a pivot, allowing steep floor/ceiling and
  diagonal reversals. Project stored bend onto the rendered dorsal/side axes
  so vertical turns flex vertically.
- Scale preparatory curvature with turn angle; a 90-degree correction no
  longer loads the same deep C as a 180-degree reversal.
- Drive pectoral asymmetry and long-fin folding from the preparatory body bend,
  before root rotation starts. Membrane deployment closes promptly and reopens
  more slowly after release, in addition to the existing fin-ray springs.
- Limit forward speed by remaining head clearance and stopping distance. This
  prevents the bounds clamp from supplying an uncommanded sideways correction.
- Hold an inward departure course after a turn begun close to glass. A held
  corner target otherwise pulled the fish into a second reversal immediately,
  before it had left the first corner.
- Parallel transport the dorsal frame through steep turns; remove the old
  fixed-pitch reference-axis switch that could snap the body roll.
- Bank from actual yaw motion during a committed pivot.

These are procedural animation and steering changes, not a fluid solver or
self-colliding cloth simulation. The existing 53-joint BlueMesh fish and
CC BY 4.0 attribution are preserved.

## Review clip

`TamoTank-Corner-Nightflight-Comparison.mp4` compares the previous commit on the
left with this pass on the right. Four six-second segments show a horizontal
reversal, corner departure, ceiling turn, and overhead reversal. Both use the
same deterministic production controller, skin and lighting at **half-speed**.
The wire box marks controller head bounds, not a complete fin collision hull.
No hand-keyed root rotation substitutes for locomotion.

Capture with a graphical display and Godot installed:

```sh
python3 scripts/install-vendor-models.py
python3 scripts/render-corner-review.py --output /absolute/path/corners.avi
```

The wrapper copies the project to a temporary directory and sets a square
capture viewport there, leaving the app's portrait settings intact.

## Validation

Local Godot 4.7.2, OpenGL Compatibility with Mesa software rendering:

- `test_swim.gd`: passed; 0/1800 wall-pinned frames; minimum forward travel
  alignment 0.99999988; fin integration at 30/60/120 Hz stayed within tolerance.
- `test_pivot.gd`: passed at 30/60/120 Hz and both horizontal signs; reversal
  about 0.88–0.90 s, head excursion about 0.054–0.060 world units.
- `test_corners.gd`: 42 cases passed (eight corners and six face normals,
  each at 30/60/120 Hz); maximum clamp correction ~1.2e-7 world units;
  maximum sampled body rotation rate ~8.75 rad/s after initial alignment.
- Actual engine footage rendered for visual inspection. These measurements
  verify stability and regression behaviour, not biological accuracy or
  S21 Ultra battery/performance.

Android CI remains pinned to Godot 4.5.1, now runs the corner regression and
exports a separate `TankWall-nightflight-beta` artifact (package
`com.birdmachine.tankwall.swimbeta`, version `0.5-corner-flight`, code 5).
Local Android export/device testing was not performed; see the PR's CI result.
The first remaining art gate is whether the BlueMesh fin topology can approach
the target's deeply folded, cloth-like silhouette. This pass is reviewable
progress, not a claim that the BETTA 120Hz look has been matched.
