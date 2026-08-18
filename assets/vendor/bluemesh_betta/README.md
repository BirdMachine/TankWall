# BlueMesh — Betta Splendens

TankWall uses the Sketchfab model **Betta Splendens** by **BlueMesh** as the first production rigged fish candidate.

- Source: https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b
- Author: BlueMesh / https://sketchfab.com/VapTor
- License: CC BY 4.0 / https://creativecommons.org/licenses/by/4.0/
- Archive filename expected by the build: `betta_splendens.zip`

The source archive is intentionally kept intact. `scripts/install-vendor-models.py` expands it into `godot_project/assets/models/bluemesh_betta/` before Godot import/export. The expanded directory is ignored by Git so there is one canonical vendor copy plus a clear attribution trail.

Required credit:

> This work is based on “Betta Splendens” by BlueMesh, licensed under CC BY 4.0.

The downloaded archive inspected for TankWall contains a glTF 2.0 scene, PBR textures, a 53-joint skin, and one skeletal animation named `Take 01`.
