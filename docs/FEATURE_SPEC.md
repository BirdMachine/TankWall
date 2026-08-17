# Feature Spec

## MVP

- Android live wallpaper aquarium scene.
- Background modes: solid color, custom image, GIF, and looped video.
- One fish initially, with architecture supporting up to three fish.
- Fish/model selector prepared for multiple rigged models and material variants.
- Mobile-friendly rendering and battery-conscious defaults.

## Settings

Settings should persist to `user://settings.json` and cover background mode/file, solid color, fish count, selected fish models, animation speed, quality, and interaction toggles.

## Fish model requirements

Preferred format: GLB/GLTF with skinning and swim/idle animation. FBX is acceptable if conversion is clean. Target a modest mobile triangle count, ideally below ~20k triangles per fish for a three-fish scene, with transparent fins/materials tested on Android.

## Milestones

1. Reproducible normal Android APK build.
2. Android WallpaperService integration.
3. Native file picker/settings UI.
4. Image/GIF/video background pipeline.
5. Rigged betta model integration.
6. Multi-fish independent movement and appearance.
7. Performance/battery controls and polish.
