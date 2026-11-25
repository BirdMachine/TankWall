# Reactive fins prototype 0.10

The purchased fins now respond to actual motion in addition to their authored
animation. Six fin-ray chains feed a small world-space cloth proxy. The
split-tail model uses 43 particles and the broad-tail model uses 38. Fin roots
are fixed to the animated pose; outer points retain inertia as the fish turns,
brakes and glides. A 120 Hz solver applies water drag, graduated pose-restoring
forces, ray-length constraints, angular limits and membrane tension links.
There is no added periodic flap or random fin displacement.

The proxy runs after animation through the existing SkeletonModifier3D hook.
Its directions are mapped back into the original fin bone rotations. Bone
positions, scales, hierarchy, inverse bind matrices and animation assets stay
unchanged. Body, mouth and eye bones receive no new offsets. World-space
simulation avoids relying on the source rig having normalized bind scales.

The broad tail has only one bone for its lower fan. That bone gets a virtual
tip and a limited swing; this cannot create detailed internal folds in that
part of the mesh. The other rays contain articulated chains. Neighbouring
rays have tension links, and a simple body capsule gives point-level collision
avoidance. This is not a full mesh-cloth or triangle self-collision solver:
fin surfaces can still intersect each other or the tank, and the existing
head bounds are not a complete fin collision hull.

**World → Reactive fins** switches between this layer and the original recorded
animation. The preference is saved, defaults on for older saves, and is read
by the wallpaper without introducing another care-data writer. Toggling the
layer off preserves the authored pose; enabling it, teleporting, or resuming
after a long frame resets accumulated momentum.

## Review and validation

`FinClothShowcase.gd` compares identical production controllers and animation
timelines with the layer off/on, for both models through reversals and vertical
turns. The recording uses 30 fps with 60 Hz simulation, so motion is shown at
half speed. `diagnose_fin_runtime.gd` separately checks that the normal rendered
SkeletonModifier callback drives both models, without the manual review hook.

`test_fin_cloth.gd` checks attached roots, exact ray lengths, a measurable
inertial response, settling, 30/60/120 Hz convergence, and safe resets on toggle,
teleport and resume. `test_fin_rig.gd` checks the actual private rigs for finite
transforms, preservation of body poses/translations/scales, and an unchanged
pose with physics disabled. It skips when purchased inputs are absent in CI.
Existing companion, tank, swimming, pivot, corner and volume checks remain in
the workflow. Private rig-source verification still checks authored assets.

Local actual-rig measurements were approximately 0.4–0.5 ms of solver/mapping
CPU time per 60 Hz step on this executor. These are desktop observations;
Android phone battery, thermal and sustained-frame-rate measurements remain
necessary before treating the prototype as a performance result.

The private APK reuses the unchanged Godot 4.5.1 Android host and wallpaper
plugin from the previously validated 0.9 private build. `prepare-native-shell.py`
removes old project resources before Godot exports the current scripts/assets
into that native shell. Normal CI still builds the Android host/plugin from
source. The package/signing identity is retained and versionCode increases to
10, allowing an update without replacing the companion's saved progress.
