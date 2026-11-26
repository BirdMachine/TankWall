# Gallery, depth and fin modes · 0.13

The companion now uses a compact navigation bar and quiet ivory/sea-glass styling, with separate Care, Fish, World and Journal sheets. The fish remains visible while editing. Shape, Colour, Finish and Motion are directly accessible from the fish tabs. Light and depth have their own pages. Portrait and landscape use a separate preview camera, leaving the camera used for swim bounds untouched.

## Fish preparation

The purchased [Dynamic Betafish pack](https://www.fab.com/listings/8744393d-3db2-44c9-869f-93a74c164b78) lists **two animated models with twelve texture varieties**. The supplied `source(1).zip` contains both GLBs, and `source.zip` contains their two C4D counterparts. No additional texture archive is present in those uploads. Both installed shapes are prepared and selectable, with portraits rendered from the actual models. The twelve complete authored skin varieties cannot be reconstructed from those four files alone.

| Shape | Rig | Rendered triangles | Cloth proxy points |
| --- | --- | --- | --- |
| Split tail | 77 bones | 48,475 | 43 |
| Fan tail | 72 bones | 42,281 | 38 |

Geometry reduction preserves the source hierarchy, inverse binds, animation keys and UVs. The original companion remains available. Shape changes retain colours and care history. Portraits are build-time renders, generated with `PrepareFishPortraits.gd`; the APK does not simulate extra fish for thumbnails.

Raw and optimized purchased assets, their portraits and the local signing key stay outside Git/CI. The original uploads remain authoritative; further skin preparation needs the pack's missing texture maps.

## Working occlusion and shadows

Godot 4.7.2 is pinned with matching Android templates and bridge dependencies. Its Compatibility renderer supports real screen-space ambient occlusion; these controls are connected to the actual Environment, not a vignette or painted shadow. Radius and strength are adjustable. Cast shadows control the main directional light, including its opacity. Tank panels receive shadows without casting their own, avoiding self-shadow patterns across flat walls. Ambient colour/strength, key/fill controls and three lighting studies are also available.

Defaults keep occlusion and shadows off, preserving older saved lighting and its rendering cost. Effects are optional and persist to wallpaper. Rest dims the configured lights; Wake restores them. Occlusion/shadows consume extra rendering time, so the UI makes that tradeoff visible.

The import cache is invalidated when engine versions change. Reusing old skinned-model caches during an engine upgrade produced visibly distorted fins; reimporting the original GLBs restores correct geometry. Editor preferences are preserved.

The wallpaper bridge now implements the 4.7 bounded renderer shutdown and pointer-capture contracts. Android validation exercises native fin simulation, occlusion/shadow activation and the wallpaper lifecycle.

## Experimental native fin option

The familiar Water backend remains the default. The optional Cloth backend uses a pinned MIT [Bone Cloth](https://github.com/pulppixel/godot-bone-cloth) source revision, compiled for Godot 4.7, Linux and Android. Three independent two-ray membranes keep unrelated fins separate. Gravity is zero; drag, stiffness, angle limits, cross-links and body capsule collisions provide water-style tuning. Freedom adjusts this profile. This remains a cloth approximation, not a fluid-dynamics solver.

The upstream release advertises desktop binaries. `scripts/build-bone-cloth.py` adds Android ABI builds from its pinned source, with an explicit API build profile. The generated native libraries remain outside Git. The extension and KawaiiPhysics/Godot notices are bundled under `licenses/` and accessible from Journal.

Tests verify finite motion, untouched body/head channels, scale preservation and fin translations within a 0.001 source-unit float round-trip tolerance. The emulator export additionally runs a synthetic native simulation to check the Android ABI and actual inertial response. The paid rigs are validated privately; public CI uses the redistributable original companion.

## Build

Use Godot 4.7.2 and Android SDK/build-tools 35, with NDK 28.1.13356709 for the optional cloth backend. Install SCons 4.11.1 into an isolated environment, then run `python3 scripts/build-bone-cloth.py --android`. The normal Android build script builds the matching wallpaper AAR and exports the app. CI performs these steps from pinned public sources and never fetches the purchased fish.

Validation results and device-specific limits are reported in the PR and downloadable nightflight notes. A native cloth mode is offered as experimental; the original water proxy remains available.

For private resource-only rebuilds, `prepare-native-shell.py` accepts repeatable `--strip-library` and `--strip-asset` options. Strip the previous project extension, its re-exported C++ dependency, and `licenses/BoneCloth.txt` before exporting them again; otherwise APK signing rejects duplicate ZIP entries. Keep the same-engine shell and private signing key in the private checkpoint.
