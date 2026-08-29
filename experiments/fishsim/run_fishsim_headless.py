#!/usr/bin/env python3
"""Headless driver for the TankWall FishSim tuning harness.

FishSim's normal Simulate operator is modal because it is designed for Blender's
interactive UI. In --background mode there is no event loop to feed TIMER events,
so the operator correctly returns RUNNING_MODAL and then never advances.

This wrapper reuses FishSim's own BoneMovement/ModalMove implementation directly,
stepping it once per frame until the requested simulation range is complete.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

import bpy

THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

import run_fishsim as harness


def simulate_headless(rig):
    """Run FishSim synchronously without Blender UI timer events."""
    scene = bpy.context.scene
    context = bpy.context

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    scene.FSimMainProps.fsim_targetrig = rig.name

    impl = importlib.import_module(f"{harness.FISHSIM_DIR.name}.FishSim")
    operator = impl.ARMATURE_OT_FSimulate()
    operator.sTargetRig = rig
    operator.armature_list(scene, scene.FSimMainProps)
    if not operator.sArmatures:
        raise RuntimeError("FishSim found no armatures to simulate")

    start = scene.FSimMainProps.fsim_start_frame
    end = scene.FSimMainProps.fsim_end_frame
    scene.frame_set(start)

    wm = context.window_manager
    wm.progress_begin(0.0, 100.0)
    try:
        operator.BoneMovement(context)
        # ModalMove advances scene.frame_current itself. Allow a small guard
        # margin so an upstream FishSim behavior change fails loudly instead of
        # hanging the Actions runner forever.
        for _ in range((end - start + 1) + 8):
            result = operator.ModalMove(context)
            if result == 0:
                break
        else:
            raise RuntimeError(
                f"FishSim headless stepping did not finish by frame {scene.frame_current}"
            )
    finally:
        wm.progress_end()

    if scene.frame_current != end:
        raise RuntimeError(
            f"FishSim stopped on frame {scene.frame_current}, expected {end}"
        )
    print(f"FishSim headless simulation completed through frame {end}")


# Replace only the UI/modal launch point. All FishSim physics and all telemetry,
# presets, trajectory construction, and saving stay in the original harness.
harness.simulate = simulate_headless
harness.main()
