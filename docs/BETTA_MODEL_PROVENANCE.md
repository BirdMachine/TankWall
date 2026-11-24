# BETTA model investigation — 2026-11-24

## Supplied archived app

Inspected the previously supplied decompiled archive
`BETTA 120HZ 2026-05-14 02-08-22 327(1).zip`, including its Unity
`assets/bin/Data/data.unity3d` bundle. This is an inventory of this archived
build, not a claim about every released version of the app. UnityPy was used
only in the scratch inspection environment; it is not a project dependency.

The bundle contains four Mesh objects:

| Mesh name | Role / observation |
| --- | --- |
| `betta4.008` | One fish body; 120 bind poses |
| `okoR` | Right eye |
| `okoL` | Left eye |
| `Triangle` | UI mesh |

There is one SkinnedMeshRenderer with 120 bones and no blend-shape channels.
Thirteen fish materials use `v2-*` names, alongside multiple `bettaV2-*`
color/specular texture variants. Script metadata includes MagicaCloth2; a
serialized `MagicaCloth` component is enabled on `mc (2)`. This establishes
the component's presence/enabled flag, not its hierarchy activation, exact
runtime settings or contribution to every movement. The two stored animation
clip names found are `ison` and `openPlus`; that alone does not identify how
all fish movement is generated.

**Interpretation:** multiple fish appearances are consistent with one base
skinned fish and material variants. A selection of colors therefore does not
establish that the original model came from a multi-model marketplace pack.
The cloth component is also a reason to investigate fin simulation rather
than expecting a new static mesh alone to reproduce the target footage.

No creator attribution or original marketplace listing was identified from
the inspected metadata or searches for the exact model/texture names. The
asset may be original, commissioned or modified stock; these findings cannot
distinguish those possibilities. The [official app page](https://maxelus.net/android/betta-120hz/)
describes customizable colors/details/lights and physics but supplies no
model-pack attribution. [MagicaCloth2](https://magicasoft.jp/en/mc2_about/) is
Unity middleware, not a drop-in Godot feature.

No reference-app mesh, texture, rig, shader or code was copied into TankWall.
Only the factual inventory is recorded here.

## Independently available candidates

Checked public product descriptions and previews on 2026-11-24. Prices are
listing observations, not purchase quotes. None is a verified source of the
reference app's model, and none has been imported or tested in Godot.

| Asset | Verified contents | Fit and conversion work |
| --- | --- | --- |
| [Beautiful Betta Fish — 3D Subject](https://superhivemarket.com/products/beautiful-betta-fish) | Five color variations; FK rig; cloth fins/tail; two Blender files; Blender 4.2+; optional Wiggle 2 workflow. $29 listed. | Promising visual/material and cloth reference. Render-focused Blender setup; bake/convert and assess mobile cost. Not five distinct betta anatomies. |
| [Sakanasan aquarium + betta](https://booth.pm/en/items/7471709) | ¥1,000; one betta with three texture variations; animated/rigged; Blender and FBX plus Unity packages. Aquarium + fish together are 19,025 triangles, or 5,965 for the light version. | Practical low-cost portable-source candidate. Public preview has broad fins, but animation quality and Godot material conversion remain untested. Triangle totals are for the entire set, not the fish alone. |
| [Betta — Junnichi Suko, Fab](https://www.fab.com/listings/71de915f-54b9-49a4-ac88-cf2fb4f9923f) | Two texture patterns, 16 in-place animations, cloth simulation; 1,682-vertex low and 8,974-vertex middle versions; supplied format Unreal Engine. Price not exposed in the inspected public page. | Strong animation checklist; Unreal cloth and clips need a deliberate export/porting assessment. |
| [Older Blender Betta — Junnichi Suko](https://www.cgtrader.com/3d-models/animal/fish/betta) | $22; rigged/animated; Blender 2.79; plugins used. | Potential source-friendly option, but this older listing must not be assumed to include the new Fab version's 16 animations/cloth workflow. |
| [Blender fishes pack — Junnichi Suko](https://cubebrush.co/junnichisuko/products/pqo7eg/blender-fishes-pack) | Thirteen species including one betta; .blend; rigged/animated; $55 basic / $60 commercial listed. | A multi-species pack, not a collection of thirteen betta varieties. |
| [Betta Animated Set — 3dror](https://www.turbosquid.com/3d-models/betta-set-animation-max/1550312) | $79; male and female; 72-frame swim loop; 2,366 polygons combined; native 3ds Max 2013. | Actual two-body set, but less convenient source format for this Godot workflow. |

The BOOTH listing allows commercial/game use and prohibits redistribution of
the raw asset, including modified copies. Review the actual purchased license
before integration and keep restricted source assets out of the public repo.
Other candidates likewise require their selected license and technical files
to be reviewed before integration. No purchase was made.

## Recommendation

Keep the improved current rig available for device comparison. If buying a
candidate to evaluate, the ¥1,000 BOOTH set is the least expensive verified
portable-source option in this shortlist; 3D Subject is the more interesting
Blender cloth/material study. Confirm the export/bake workflow before choosing it.
For the target's broad folded fins, topology and compliant/self-contact motion
both deserve attention. Source-pack provenance remains unresolved.
