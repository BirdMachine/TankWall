#!/usr/bin/env python3
"""Headless FishSim experiment harness for TankWall.

Runs the bundled FishSim Goldfish against the same Betta120Hz-inspired target
trajectory using one named parameter preset. Outputs a .blend and CSV telemetry.

This script intentionally keeps FishSim as an external GPL tool; TankWall does
not copy FishSim source into the application.
"""
from __future__ import annotations

import csv
import importlib
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

PRESET = os.environ.get("TANKWALL_FISHSIM_PRESET", "silk_glide")
FISHSIM_DIR = Path(os.environ["FISHSIM_DIR"]).resolve()
OUT_DIR = Path(os.environ.get("TANKWALL_FISHSIM_OUT", "fishsim-results")).resolve()
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Same course for every preset. At 60 fps this is ten seconds:
# hover -> lazy launch -> sweeping arc -> strong turn -> burst -> coast -> settle.
KEYS = [
    (1,   Vector((0.0, 0.0, 0.0))),
    (65,  Vector((0.0, -0.15, 0.0))),
    (150, Vector((0.7, -2.0, 0.15))),
    (245, Vector((2.2, -3.7, 0.35))),
    (335, Vector((3.0, -2.0, 0.50))),
    (405, Vector((1.35, -0.45, 0.20))),
    (455, Vector((-0.9, -2.4, -0.20))),
    (515, Vector((-1.45, -3.65, -0.05))),
    (580, Vector((-0.45, -3.95, 0.0))),
    (600, Vector((-0.42, -3.95, 0.0))),
]

# These are deliberately broad probes rather than claims of final values.
PRESETS = {
    "silk_glide": {
        "pMass": 55.0,
        "pDrag": 4.2,
        "pPower": 1.15,
        "pMaxFreq": 23.0,
        "pMaxTailAngle": 24.0,
        "pAngularDrag": 3.4,
        "pMaxSteeringAngle": 22.0,
        "pTurnAssist": 2.3,
        "pLeanIntoTurn": 1.6,
        "pEffortGain": 0.20,
        "pEffortIntegral": 0.035,
        "pEffortRamp": 0.09,
        "pMaxTailFinAngle": 24.0,
        "pTailFinPhase": 110.0,
        "pTailFinStiffness": 0.22,
        "pChestRatio": 0.32,
        "pChestRaise": 0.75,
        "pRandom": 0.0,
        "pHoverDist": 0.85,
        "pHoverTailFrc": 0.12,
        "pHoverMaxForce": 0.14,
        "pHTransTime": 0.65,
        "pSTransTime": 0.28,
        "pMaxPecFreq": 26.0,
        "pMaxPecAngle": 22.0,
        "pPecPhase": 112.0,
        "pPecStiffness": 0.18,
        "pPecSynch": False,
        "pHoverTwitch": 0.0,
    },
    "balanced": {
        "pMass": 38.0,
        "pDrag": 6.0,
        "pPower": 1.15,
        "pMaxFreq": 18.0,
        "pMaxTailAngle": 22.0,
        "pAngularDrag": 2.1,
        "pMaxSteeringAngle": 24.0,
        "pTurnAssist": 3.2,
        "pLeanIntoTurn": 1.4,
        "pEffortGain": 0.24,
        "pEffortIntegral": 0.05,
        "pEffortRamp": 0.16,
        "pMaxTailFinAngle": 22.0,
        "pTailFinPhase": 100.0,
        "pTailFinStiffness": 0.38,
        "pChestRatio": 0.38,
        "pChestRaise": 0.9,
        "pRandom": 0.0,
        "pHoverDist": 0.75,
        "pHoverTailFrc": 0.16,
        "pHoverMaxForce": 0.18,
        "pHTransTime": 0.45,
        "pSTransTime": 0.22,
        "pMaxPecFreq": 21.0,
        "pMaxPecAngle": 24.0,
        "pPecPhase": 100.0,
        "pPecStiffness": 0.28,
        "pPecSynch": False,
        "pHoverTwitch": 0.0,
    },
    "responsive": {
        "pMass": 27.0,
        "pDrag": 7.5,
        "pPower": 1.25,
        "pMaxFreq": 14.0,
        "pMaxTailAngle": 26.0,
        "pAngularDrag": 1.6,
        "pMaxSteeringAngle": 29.0,
        "pTurnAssist": 4.4,
        "pLeanIntoTurn": 1.9,
        "pEffortGain": 0.29,
        "pEffortIntegral": 0.06,
        "pEffortRamp": 0.24,
        "pMaxTailFinAngle": 27.0,
        "pTailFinPhase": 92.0,
        "pTailFinStiffness": 0.48,
        "pChestRatio": 0.42,
        "pChestRaise": 1.15,
        "pRandom": 0.0,
        "pHoverDist": 0.65,
        "pHoverTailFrc": 0.20,
        "pHoverMaxForce": 0.22,
        "pHTransTime": 0.34,
        "pSTransTime": 0.16,
        "pMaxPecFreq": 17.0,
        "pMaxPecAngle": 27.0,
        "pPecPhase": 90.0,
        "pPecStiffness": 0.38,
        "pPecSynch": False,
        "pHoverTwitch": 0.0,
    },
}


def load_fishsim():
    parent = FISHSIM_DIR.parent
    if str(parent) not in sys.path:
        sys.path.insert(0, str(parent))
    module_name = FISHSIM_DIR.name
    fs = importlib.import_module(module_name)
    fs.register()
    return fs


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def add_goldfish():
    # Use FishSim's own operator so its bundled collection and rig glue are
    # initialized exactly the way the add-on expects.
    result = bpy.ops.armature.addfish("EXEC_DEFAULT", FishSelector="Goldfish")
    if "FINISHED" not in result:
        raise RuntimeError(f"FishSim Goldfish add failed: {result}")

    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE" and o.pose.bones.get("root")]
    if not rigs:
        raise RuntimeError("No FishSim armature found after adding Goldfish")
    rig = rigs[0]
    root = rig.pose.bones["root"]
    proxy_name = root.get("TargetProxy", "")
    proxy = bpy.context.scene.objects.get(proxy_name)
    if proxy is None:
        # Older/bundled variants may not have a proxy yet.
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
        bpy.ops.armature.fsim_add("EXEC_DEFAULT")
        proxy_name = root.get("TargetProxy", "")
        proxy = bpy.context.scene.objects.get(proxy_name)
    if proxy is None:
        raise RuntimeError("FishSim target proxy could not be resolved")
    return rig, proxy


def animate_proxy(proxy):
    proxy.animation_data_clear()
    for frame, position in KEYS:
        proxy.location = position
        proxy.keyframe_insert(data_path="location", frame=frame)
    if proxy.animation_data and proxy.animation_data.action:
        # Smooth target motion except the opening/closing hover; FishSim should
        # create the organic lag, not jerky interpolation artifacts.
        for fc in proxy.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"


def apply_parameters(scene):
    values = PRESETS[PRESET]
    props = scene.FSimProps
    for name, value in values.items():
        if not hasattr(props, name):
            print(f"WARN FishSim property missing: {name}")
            continue
        setattr(props, name, value)
    scene.FSimMainProps.fsim_start_frame = 1
    scene.FSimMainProps.fsim_end_frame = 600
    return values


def simulate(rig):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.scene.FSimMainProps.fsim_targetrig = rig.name
    result = bpy.ops.armature.fsimulate("EXEC_DEFAULT")
    if "FINISHED" not in result:
        raise RuntimeError(f"FishSim simulation failed: {result}")


def bone_rotation_xyz(rig, name):
    bone = rig.pose.bones.get(name)
    if bone is None:
        return (math.nan, math.nan, math.nan)
    e = bone.rotation_quaternion.to_euler("XYZ")
    return tuple(math.degrees(v) for v in e)


def write_telemetry(scene, rig, proxy):
    csv_path = OUT_DIR / f"{PRESET}.csv"
    candidate_bones = ["spine_master", "chest", "torso", "back_fin", "tail_master", "root"]
    existing = [n for n in candidate_bones if rig.pose.bones.get(n)]
    with csv_path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        header = ["frame", "time_s", "x", "y", "z", "speed", "target_error"]
        for name in existing:
            header += [f"{name}_rx", f"{name}_ry", f"{name}_rz"]
        writer.writerow(header)
        prev = None
        for frame in range(1, 601):
            scene.frame_set(frame)
            p = rig.matrix_world.translation.copy()
            speed = 0.0 if prev is None else (p - prev).length * 60.0
            prev = p
            error = (proxy.matrix_world.translation - p).length
            row = [frame, (frame - 1) / 60.0, p.x, p.y, p.z, speed, error]
            for name in existing:
                row += bone_rotation_xyz(rig, name)
            writer.writerow(row)
    return csv_path


def write_summary(scene, rig, proxy, values):
    speeds = []
    errors = []
    prev = None
    for frame in range(1, 601):
        scene.frame_set(frame)
        p = rig.matrix_world.translation.copy()
        if prev is not None:
            speeds.append((p - prev).length * 60.0)
        prev = p
        errors.append((proxy.matrix_world.translation - p).length)
    summary = OUT_DIR / f"{PRESET}-summary.txt"
    summary.write_text(
        f"preset={PRESET}\n"
        f"mean_speed={sum(speeds)/len(speeds):.5f}\n"
        f"max_speed={max(speeds):.5f}\n"
        f"mean_target_error={sum(errors)/len(errors):.5f}\n"
        f"max_target_error={max(errors):.5f}\n"
        + "\n".join(f"{k}={v}" for k, v in values.items())
        + "\n"
    )
    return summary


def main():
    if PRESET not in PRESETS:
        raise SystemExit(f"Unknown preset {PRESET!r}; choose {sorted(PRESETS)}")
    print(f"=== TankWall FishSim experiment: {PRESET} ===")
    load_fishsim()
    clear_scene()
    scene = bpy.context.scene
    scene.render.fps = 60
    scene.frame_start = 1
    scene.frame_end = 600
    rig, proxy = add_goldfish()
    animate_proxy(proxy)
    values = apply_parameters(scene)
    simulate(rig)
    write_telemetry(scene, rig, proxy)
    write_summary(scene, rig, proxy, values)
    blend_path = OUT_DIR / f"{PRESET}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print(f"Saved {blend_path}")


if __name__ == "__main__":
    main()
