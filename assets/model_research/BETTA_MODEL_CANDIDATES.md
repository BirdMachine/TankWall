# Betta model candidates

We want a betta that is visually close to the flowing-finned look of classic aquarium live wallpapers while remaining practical for Android/Godot.

## Candidate sources to evaluate

- Superhive / Blender Market: rigged betta models with fin animation workflows.
- Sketchfab: downloadable betta models; license and rigging vary by asset.
- CGTrader / TurboSquid: paid rigged or animated fish models in Blender/FBX/GLTF-compatible workflows.
- Meshy/community model libraries: useful for inexpensive static baselines, but rigging and licensing must be checked individually.

## Acceptance checklist

A model is ready for TankWall when it has:

- an explicit license allowing the intended app distribution,
- a clean skinned armature,
- body + flowing fin deformation that survives GLB/GLTF export,
- at least one loopable idle/swim animation or an armature suitable for procedural animation,
- transparent/translucent fin materials that render correctly in Godot Compatibility mode,
- sensible mobile geometry and texture sizes,
- no dependency on proprietary modifiers that cannot be baked/exported.

The placeholder procedural fish in `godot_project/scenes/Fish.tscn` exists only to unblock rendering and build work while we select the final asset.
