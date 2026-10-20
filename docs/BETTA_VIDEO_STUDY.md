# Betta video study and swimming betas

2026-10-19. The first beta was rejected for stiffness, and the user's screenshot
showed an apparent second eye over the nose. Its bone-motion tests proved that
joints moved, but did not establish convincing swimming. This pass uses real
video frames as visual reference and adds checks for actual runtime advancement
and opaque head/eye depth behavior.

## Footage actually inspected

These are source videos, not generated motion. They were downloaded for private
analysis and sampled into temporal contact sheets. Neither their video bytes nor
reference screenshots are packaged in the app or committed to this repository.

| Source | Inspected intervals | Direct visual observations |
| --- | --- | --- |
| [Jack and Dan — Beautiful Betta Swimming In Slow Motion](https://www.youtube.com/watch?v=AjFkSOUXYCc), uploaded 2023-08-27, 3:32 | 00:15–00:25, 00:55–01:05, 01:50–01:58, sampled at 3 frames/s of the supplied video | In the close-up turn around 00:55–01:05, the head pivots while the long trailing fins take different shapes, partly furl, sweep around, and open. At 01:50–01:58, the body changes heading while the fin margins lag and change outline. Pectoral movements remain visible with little forward travel. The silhouette is not a permanently spread fan. |
| [Pexels — Fish in Aquarium, video 12659950](https://www.pexels.com/video/fish-in-aquarium-12659950/), 19.42 s retrieved clip | 00:00–00:08 and 00:10–00:18, sampled at 2 frames/s | Early footage shows little translation, with small fins moving and long fins hanging below the body. Later frames show a curved departure; the head starts the turn and the body/tail follow. The animal alternates station keeping with forward motion rather than moving continuously at one speed. |

These are qualitative observations from two individuals and different fin forms,
not measured biomechanics. The first source is explicitly slow motion; its video
timestamps were **not** treated as physical tail-beat timing. Refraction through
the bowl in the second source also limits geometric measurements.

The [Clark-Shen et al. study](https://pmc.ncbi.nlm.nih.gov/articles/PMC11704571/)
was consulted for a behavioral cross-check: its ethogram distinguishes swimming,
resting and hovering, and notes pectoral movement during hovering. It is not a
motion-capture dataset or a justification for making this animation biologically
validated.

## Changes drawn from the observations

1. **Free membrane, not only ray rotation.** The existing fin bones still supply
   broad motion, but the mesh is now separated into opaque flesh and soft fin
   surfaces. Vertex colors encode attachment softness and rest coordinates.
   A GPU membrane deformation adds rounded, varying out-of-plane folds and
   smaller free-edge waves. A cylindrical radial bend supplies the broad fold;
   its sine/cosine arc avoids simply scaling the fin shorter. Approximate
   shading normals follow the membrane deformation.
2. **Furling and opening.** Deployment varies with movement effort, steering,
   and a slower independent phase. Free margins can cup and trail while the
   attachment remains anchored. The result changes silhouette within a stroke.
3. **Separate fin timescales.** Fin rays no longer share one body-locked carrier.
   Distal phase lag, multi-axis cupping and deployment differ from the muscle
   stroke. The old fin spring natural frequency/damping suppressed much of its
   prescribed motion. Revised response retains visible secondary movement.
4. **Stroke, coast, inspect.** Forward effort now varies more, with brief low-speed
   inspection intervals. A close reversal slows translation and increases
   turning rate; the body's curvature responds to measured turning. Root turns
   are reduced during stationary inspection. The controller remains a kinematic
   approximation; it does not derive propulsion from fluid forces.
5. **Eyes and depth.** The source put both body and eyes in alpha blending, so
   their visibility depended on transparent-object ordering. Flesh and eyes
   now use opaque depth-tested materials. Fin transparency remains on its own
   surface, with alpha depth prepass. The original eye geometry and atlas UVs
   are retained; the fix addresses occlusion rather than relocating the eyes.

## Verification

- Godot 4.5.1/OpenGL Compatibility rendering; actual model and skin retained.
- `test_swim.gd`: torso/tail motion, segment preservation, fin/cupping pause
  stability, 30/60/120 Hz convergence, material/depth checks, and 30 seconds of
  portrait-tank locomotion. Stationary inspection is distinguished from wall
  pinning. The real eye mesh and head surface must use opaque materials, and
  the actual membrane surface must exist.
- `diagnose_runtime.gd`: observes 180 ordinary scene frames and requires at
  least 170 modifier callbacks plus an advancing membrane clock. This catches
  an animation that works only when a test manually steps bone poses.
- Visual review includes temporal frame sheets, stationary side view, turning,
  low-effort motion, oblique/head-on eye views, and the Main scene's autonomous
  camera. Stronger folds were adjusted after inspection to avoid sharply
  creased or tangled fin shapes.
- The second beta used version code 3 / `0.3-reference-study`. See the dated
  follow-up below for the current build and installation limitation.

The existing topology and three main caudal ray sectors still limit detailed
folding. This remains a procedural approximation with possible fin self-overlap,
not cloth collision or CFD. Desktop software-rendered footage is not an Android
performance benchmark. Kestrel testing remains necessary, and the user's visual
assessment—not a green test suite—is the criterion for lifelike movement.


## Tight-turn follow-up — 2026-10-20

The user still found the swimming stiff and supplied specific turning examples.
This pass revisited Jack and Dan at **01:03–01:08** and **01:52–01:57**, sampled
at 2 fps, then inspected [AquaLush's 10-second short](https://www.youtube.com/shorts/eISGwE8dTXs)
at 2 fps throughout and 8 fps over **00:03–00:04.8**. The short shows a compact
reversal around 00:04: the head changes course, the posterior body curls, and
the fan sweeps around and opens after it. The slow-motion turn around 01:54
shows different head and tail headings within the same moment. Timing in the
slow-motion source was not used as a physiological measurement.

The supplied [four-hour aquarium video](https://www.youtube.com/watch?v=VQxOauQX9co&t=5257s)
could not be retrieved after two timeouts. Only the user's screenshots at
**01:27:42–01:27:43** were inspected for that source; they show the dark blue/red
fish changing orientation within a small area, but do not establish its
intermediate body poses. No claim is made to have watched that video interval.

### Implementation

- `BettaPivot.gd` supplies **brake → curl → pivot → release** for horizontal
  destination changes greater than about 72 degrees. It captures a destination
  through the manoeuvre to avoid alternating steering while avoidance updates.
  Cruise steering remains available for small corrections.
- Braking removes most forward travel before the pivot. Preparatory body
  curvature builds for 0.16 s before root yaw starts; the pivot then takes
  0.30–0.80 s depending on angle and the turn-rate setting, followed by a
  0.36 s release. These are chosen animation timings, not measured biology.
- The controller now places its origin at the head/pectoral pivot rather than
  rotating the head around a remote torso centre. Uniform model scale and
  original proportions are retained.
- The spine receives an explicit bend envelope, independent of angular speed.
  Curvature persists while the head turns, then unwinds. Ordinary tailbeat
  amplitude is reduced during the manoeuvre; existing spring-driven fin rays
  and soft membranes trail its changing curvature. Bank is limited to avoid
  the earlier aircraft-like roll.
- `SwimShowcase.gd -- --pivots` exercises the **actual controller** with two
  deterministic destination reversals. `--overhead` shows the same course from
  above. It does not keyframe the model's root rotation. The new preview is a
  single square view with square pixels, with the overhead view shown afterward;
  there is no side-by-side canvas or nonuniform video scaling.

### Validation and limits

`test_pivot.gd` loads the actual skin and checks both turn directions plus an
exact 180-degree reversal. At 30/60/120 Hz the first reversal took about
0.88–0.90 s with 0.054–0.060 world units of head travel before facing back.
Those are synthetic scenario metrics, not measurements of the supplied fish.
It also requires curvature before yaw, differing head/tail joint frames,
release of the bend, and the rendered head remaining at its controller pivot.
The existing skin/material, fin stability, autonomous tank and ordinary runtime
checks remain in use. Numerical checks are regressions, not visual acceptance.

Frame-by-frame desktop review included the same manoeuvre from oblique and
overhead views, both turn directions, fin trailing/reopening and eye occlusion.
Camera framing was enlarged after the first render clipped the tail fan.

Current Android beta: version code **4**, **0.4-tight-turns**, package
`com.birdmachine.tankwall.swimbeta`. The earlier workspace's debug signing key
was unavailable in this session, so this APK has a new debug certificate.
Android requires uninstalling the previous Swim Beta before installing this
one; doing so resets that beta's saved settings. Normal TankWall is a separate
package. APK signing/package validation and desktop rendering were checked;
physical Android appearance and performance still need the user's review.

This continues to use the existing free CC BY model and Godot. No purchased
asset or paid animation service was used. Fin self-collision remains unsolved;
this is a procedural swimming beta, not fluid simulation.
