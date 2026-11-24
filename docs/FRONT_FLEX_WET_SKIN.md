# Front flex and wet skin — 2026-11-24

Continues the v0.6 body-volume rework on the same licensed BlueMesh asset.
Birdie's feedback was that the new motion was much closer; this pass adds
some freedom at the front and smoother, shinier skin.

## Changes

- Add a restrained anterior yaw/pitch response and start the pivot curvature
  earlier along the spine. The cruising stroke remains restrained.
- Move the skull branch through the same angular delta as the anterior torso.
  In this model the skull is a sibling of the torso branch, not its child;
  leaving it stationary would separate the head/eyes from the new front bend.
- Reduce body normal-map strength to 28% of the source setting, soften the
  roughness variation and add a 0.55 clearcoat layer. Preserve color textures,
  metallic response, eye settings and translucent fin materials.
- Keep the dual quaternion skinning and original model dimensions/weights.

These coefficients are visual tuning, not measured biological parameters.
This does not add cloth simulation or replace the model.

## Validation

Local Godot 4.7.2 regressions pass: swim, pivot, 42 corner cases, volume and
live modifier execution. Across the volume regression's left/right/compound
bends, the 27 sampled opposing torso pairs retain 99.72–100.40% of their rest
width. Maximum measured front rotation is 0.195 radians (about 11 degrees);
the skull and anterior torso angular deltas agree within 0.002 radians.

Actual Compatibility/OpenGL frames were rendered and inspected, including
shader compilation, flesh/eye separation and the surface highlights.
`TankWall-Front-Flex-Wet-Skin-v0.7.mp4` compares v0.6 (left) with v0.7 (right).
It uses the same 20-second fixed-root inspection as the preceding body pass:
two torso-only views, then compound bending and quiet swimming with fins.
It is controlled rig footage, not autonomous locomotion footage.

The Android comparison beta is **TankWall Wet Skin Beta**, package
`com.birdmachine.tankwall.wetbeta`, version **0.7-front-flex-wet-skin**, code
**7**. It installs beside v0.6. Android CI uses Godot 4.5.1. Phone appearance
and performance remain device acceptance checks.

See [the model-source investigation](BETTA_MODEL_PROVENANCE.md) for the
archived reference app and replacement candidates. No new asset was purchased
or integrated.
