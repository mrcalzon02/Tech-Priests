"""One camera fixture for all Water Purifier production-smoke derivatives.

A preview is a diagnostic sample of the canonical fixed machine camera,
NOT an additional render angle or a claim that four sprite views were exported.
This module never edits a source .blend on disk.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FMPL = HERE.parent
if str(FMPL) not in sys.path:
    sys.path.insert(0, str(FMPL))

from capture_policy import POLICY_ID, validate_capture_profile
from blender_camera_guard import install_canonical_camera, assert_clean, camera_record


def purifier_profile(resolution=512):
    """Measured Water Purifier camera: (0,-6,7.65) to (0,0,1.65)."""
    if type(resolution) is not int or resolution <= 0:
        raise ValueError("Camera target resolution must be a positive integer")
    profile = {
        "camera_policy": POLICY_ID,
        "capture_kind": "entity",
        "directions": [0, 90, 180, 270],
        "states": {"idle": [1], "working": [25]},
        "source_size": resolution,
        "camera_override": {
            "type": "ORTHO",
            "elevation_deg": 45,
            "azimuth_deg": 0,
            "distance": 6 * math.sqrt(2),
            "target": [0.0, 0.0, 1.65],
            "ortho_scale": 5.8,
            "shift_x": 0,
            "shift_y": 0,
        },
    }
    validate_capture_profile(profile)
    return profile


def clean_scene(scene, bpy, resolution=512):
    """Replace ALL old cameras in an in-memory derived scene; fail on rigged geometry."""
    cfg = purifier_profile(resolution)
    receipt = install_canonical_camera(scene, cfg, bpy)
    assert_clean(scene, cfg, bpy)
    return receipt


def audit_scene(scene, bpy, resolution=512):
    """Fail if any unapproved camera persists or its actual pose differs."""
    cfg = purifier_profile(resolution)
    assert_clean(scene, cfg, bpy)
    return camera_record(scene)
