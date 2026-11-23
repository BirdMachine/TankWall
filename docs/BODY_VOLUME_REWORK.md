# Body-volume rework — 2026-11-23

Birdie's v0.5 device feedback was that the body still looked laterally flat and
flapped like a sheet. The earlier corner regressions verified trajectory and
bone motion, but did not establish a convincing torso silhouette.

## Diagnosis and implementation

The source BlueMesh torso is already three-dimensional. Inspection of its actual
non-fin vertices found opposing sides roughly ±0.25 source units in the belly;
there is no zero-thickness body card to inflate. The source proportions, UVs,
geometry and weights are retained in this pass.

The previous torso driver mainly imposed yaw on five joints; pitch was largely
reserved for steep manoeuvres, with no local longitudinal torsion. That makes
much of the motion read as a plane swinging side to side even on a solid mesh.
This pass adds distributed pitch and twist through a committed bend, while
keeping the head quiet. Low-effort cruising uses a smaller, stroke-weighted
wave instead of the previous continuous broad wag. These coefficients are art
tuning, not calibrated biological measurements.

The runtime also changes from linear matrix skinning to **dual quaternion
skinning**. Linear blends of rotating transforms can shrink a cross-section;
rigid-transform blending avoids that particular collapse. This is a robustness
improvement, not evidence that collapse alone caused the device complaint.
The algorithm is described by [Kavan et al., 2008](https://dcgi.fel.cvut.cz/wp-content/wpallimport-dist/publications/pdf/publications-2008-kavan-tog-adqb-paper.pdf).
The implementation here is original, based on the published algorithm.

- Encode original weights and joint indices into two float custom attributes.
- Upload each current skin transform as a real/dual quaternion pair after the
  skeleton modifier updates. Correct quaternion hemispheres before blending.
- Apply the same skinning to body, eyes and fins, and remove the engine skin
  channels to prevent a second deformation pass.
- Preserve opaque flesh/eye depth testing, textured metallic/roughness response,
  normal maps, fin transparency and the existing compliant membrane motion.
- Retain the existing rest proportions: no body inflation or animated scale.

This is a specialized path for the inspected 53-bind BlueMesh asset. Replacing
the asset requires a deliberate adapter update; it is not a generic glTF loader.

## Visual inspection

`TankWall-Body-Rework-Comparison.mp4` compares v0.5 with this pass in four
five-second views. The first two hide the fins and show the torso obliquely and
from above. The final two restore the fins for compound bending and quiet
swimming. The root stays fixed; the camera and controlled rig loads are
explicit inspection tools, not autonomous locomotion footage.

```sh
python3 scripts/install-vendor-models.py
python3 scripts/render-corner-review.py --script BodyShowcase.gd \
  --label 'BODY REWORK v0.6' --output /absolute/path/body.avi
```

The existing `CornerShowcase.gd` was rendered with the new skin as a separate
check of the actual controller. Phone appearance/performance and whether the
motion now satisfies the desired realism remain device acceptance checks.

## Validation

Local Godot 4.7.2, Compatibility/OpenGL with Mesa software rendering:

- Swim, pivot, 42-case corner and live runtime regressions pass.
- The new volume regression samples **27 opposing vertex pairs actually used
  by the opaque torso surface**, with >95% spine membership. Fin-root vertices
  and unused vertex-array entries are excluded.
- At rest, maximum CPU skin error is about 5.4e-5 source units.
- Across the tested left/right and compound bends, sampled torso width stays
  about **99.78–100.32%** of its rest value. This is a cross-section regression,
  not a full volumetric integral or proof of biological realism.
- Local body torsion reaches about 0.735 in the measured lateral-axis vertical
  component, proving the fixed-root torso is not restricted to one bend plane.
- Actual GPU frames and source textures were inspected after shader compilation.
  Headless tests alone do not validate GPU shader behavior.

Android CI remains on Godot 4.5.1 and adds `test_volume.gd`. This comparison beta
uses `com.birdmachine.tankwall.bodybeta`, named **TankWall Body Beta**, version
**0.6-body-volume**, code **6**. It installs beside v0.5, so the device comparison
does not depend on CI debug-key update compatibility.

## Different-model assessment

A replacement can help with anatomy and especially the target's large, folded
fin topology, but it does not automatically fix a planar motion driver.
[The current free model's redistributed listing](https://aizity.com/assets/free-3d-model-download/betta-splendens-3d-model)
is the same BlueMesh asset, not an independent replacement.
[Junnichi Suko's Fab betta](https://www.fab.com/listings/71de915f-54b9-49a4-ac88-cf2fb4f9923f)
advertises 16 in-place animations and cloth simulation, but its supplied format
is Unreal Engine; portable cloth motion has not been verified.
[3D Subject's Blender betta documentation](https://superhivemarket.com/products/beautiful-betta-fish/docs/new)
requires a cloth bake and optionally a Wiggle bake. Neither is a verified,
drop-in Godot replacement. No new asset was purchased or integrated.

The current free asset is retained for this body-focused revision. Exact
BETTA 120Hz parity and self-colliding cloth fins are not claimed.
