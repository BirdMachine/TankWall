# Wallpaper bridge provenance

Source: https://github.com/TheOathMan/Godot-Android-Live-Wallpaper
Pinned upstream commit: `67ab3eb4847393883906c098b8bd58960ecba27d`.

The bridge is MIT licensed (see LICENSE). Its copied Godot and AOSP surface
classes retain their original MIT and Apache 2.0 notices in the source files.
TamoTank builds these sources against Godot 4.5.1, enables touch delivery, clears
stale service references, and prevents an obsolete preview engine from pausing
the active wallpaper engine.
The service uses a private `:wallpaper` process and TamoTank metadata. Generated
libraries and the Godot engine's generated Android template are not committed.

The upstream bridge currently uses a modified OpenGL surface lifecycle. It
requires the Compatibility renderer. Its behaviour needs device/launcher
validation, including previews, visibility, surface replacement and rotation.
