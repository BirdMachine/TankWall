# Living aquarium nightflight

The companion retains its additive care loop: no declining needs, absence
penalties, lost friendship, sickness, death or punitive notifications.

## Views and behaviour

**World** opens Showcase / Tank selection, a solid backwall colour, two purchased
body variants when installed, the original redistributable companion, soft
colour tints and Curious / Calm / Dreamy behaviour. The tank view adds a physical
floor, backwall, glass edges, stones and moving leaves. Showcase leaves the fish
against a quiet solid colour. Each preference is saved with the companion.

FishBrain is a local behaviour selector, with deterministic preferences tied to
the companion's identity. Residents explore, visit favourite corners, approach
the viewer, drift, and sometimes investigate a touch. These choices use the
existing swimming controller; food and explicit play take priority. There is no
network AI, account, API key or recurring inference cost.

## Purchased models

The user's Gusai pack supplied two GLBs and C4D sources. The split-tail GLB
contains a usable body/eye/mouth texture set. The broad-tail export contains
blank body materials; this build shares the split-tail maps with that model.
Additional colour-map variants from the separate texture pack are not present.

Raw files belong under ignored `assets/private/gusai/source/`. Install the
user-owned ZIP with `scripts/install-purchased-pack.py`, then run the Blender
command it prints. Generated mobile models and shared textures live in ignored
`godot_project/assets/models/gusai_betta/`. Neither licensed sources nor generated
mesh/texture files belong in public Git history, releases or CI artifacts.

Geometry is reduced with Blender while the original GLB node hierarchy, skin
palettes, inverse bind matrices and animation samples are retained byte for
byte. This avoids changing the C4D export's unusual bind transforms. The rig
verification script checks those properties and the mobile triangle budget.
Both models share content-addressed texture files. CI skips private-asset
verification when the licensed input is absent and uses BlueMesh as a fallback.

The adapter keeps native skinning and the artist's fin dynamics. A coherent
three-dimensional centreline bend adds steering curvature while rotating each
cross-section and its shading frame. It does not flatten or inflate the body.
Clip-root travel is held still; the existing controller owns locomotion. Body,
mouth, fins and eyes receive different surface roughness and coating settings.

## Android wallpaper

The wallpaper bridge is built from pinned, licensed source; see
`android/livewallpaper/NOTICE.md`. It uses a separate `:wallpaper` process to
respect Godot's single-engine-per-process requirement. **Set live wallpaper**
opens Android's preview/chooser so the owner makes the final selection.

Wallpaper mode uses the selected view without care panels and allows the fish
to roam the full screen. It pauses simulation when hidden and limits normal
wallpaper rendering to 60 fps. It reads companion data and never writes it;
foreground care remains the single writer. Settings are refreshed while visible
and on resume, preventing a stale wallpaper process from overwriting progress.

The native bridge uses a modified OpenGL surface implementation. Device and
launcher lifecycle checks remain necessary even when compilation and desktop
tests pass. The clean section of LivingShowcase is a desktop layout preview,
not evidence that the Android service ran. Record native validation separately.

## Checks

- Existing swim, pivot, 42 corner/wall cases, volume and runtime regressions.
- Companion persistence, a year of absence without penalties, backup recovery,
  food contact, play/steering cleanup, refresh cooldown and rest.
- 450 bounded behaviour choices across three personalities, temporary touch
  interest, the physical room, a panel-free wallpaper view, read-only saved
  progress and foreground preference updates.
- Private source/optimized rig comparison: exact hierarchy, bind transforms and
  animation samples, with fewer than 60,000 triangles per mobile model.

The side-by-side beta uses `com.birdmachine.tamotank.livingbeta` so it does not
replace the earlier companion prototype. The emulator preset uses x86_64; the
phone preset uses arm64. A private paid-model build is performed locally; public
CI builds contain the redistributable fallback.
