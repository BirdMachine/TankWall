# Deeper fin folds 0.11

The user supplied `1000060573.mp4` as a motion target. Its broad fins sweep out
of their resting plane, curl back toward the fish during directional changes,
and open again. This pass increases the existing live deformation toward that
range. The reference recording is not included in Git, and no reference-app
assets or code are used.

The default **Fin freedom** is now 2.2. A value of 1.0 retains the restrained
0.10 settings, while 0.5 gives a firmer response. At the new default:

- Outer-ray angular freedom increases from 0.72 to 1.95 radians.
- The first segment's cap increases from 0.22 to 0.60 radians.
- Pose-restoring frequencies decrease from 12/5 to 9/2.8 (root/tip), while
  velocity drag increases from 4.8 to 7.2. The fins lag further behind movement.
- Adjacent-segment bend limits transport the authored local bend along the
  ray, allowing long curls while limiting abrupt kinks.
- Length constraints keep fin roots attached and rays at their authored length.
  Membrane tension links and the existing body capsule remain active.

The slider under **World → Fin freedom** adjusts a running solver immediately
and persists to the wallpaper. Older saves adopt the new default while keeping
their existing Reactive fins on/off preference and all care progress. Controls
are disabled for the original companion, which uses its previous fin system.

`DeepFinShowcase.gd` compares 0.10's live profile with the new profile, using
identical production controllers through consecutive horizontal/vertical turns.
Both rows use live physics; the recording is shown at half speed. Body motion,
surface materials, authored animations, topology and bind data are unchanged.

## Validation

The synthetic repeatable turn produces peak offsets of approximately 0.249
(old) and 0.619 (new), a 2.49-fold increase. Actual private-rig tests produce
approximately 0.965 / 0.975 for the two shapes, versus about 0.410 previously.
These are scene-space deformation measurements, not physical fish dimensions.

`test_deep_fins.gd` checks the measurable increase, 30/60/120 Hz behaviour,
attached roots, exact lengths, finite states, geometric reach, settling, and
live tuning. The private-rig test also verifies that rendered bone positions
follow the simulated proxy within 0.001 scene units, with body bones and all
bone translations/scales preserved. Source-rig verification, existing care,
wallpaper state and swimming regressions remain applicable.

This remains a bone-driven cloth proxy. The broad fan's single lower bone
limits its internal folding detail. Fin-to-fin/triangle self-collision is not
implemented, so deeper folds can overlap. Real-device performance and the
visual match to the reference still require phone review.
