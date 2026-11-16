"""Fixed Factorio camera and ground registration for the approved Mars reactor family.

The FMPL policy and Blender guard are imported unmodified from the project.
A single world transform is shared by both image resolutions and all machine
headings. The authored geometry remains at its original native size.
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
from typing import Sequence

HERE = Path(__file__).resolve().parent
# Prefer the project's canonical modules in a repository checkout. A standalone
# source bundle carries byte-identical modules for reproducible camera audits.
IN_REPO = HERE.parents[3] / "tools" / "fmpl" if len(HERE.parents) > 3 else HERE
FMPL = IN_REPO if (IN_REPO / "blender_camera_guard.py").is_file() else HERE / "vendor" / "fmpl"
if str(FMPL) not in sys.path:
    sys.path.insert(0, str(FMPL))

from capture_policy import POLICY_ID, validate_capture_profile
from blender_camera_guard import install_canonical_camera, assert_clean, camera_record

NAMES = ("Minoris", "Majoris", "Maximus")
RADII = (1.65, 2.30, 3.05)
FOOTPRINTS = (4, 6, 8)
HR_SIZES = (384, 512, 704)
SD_SIZES = tuple(x // 2 for x in HR_SIZES)
UNITS_PER_TILE = 1.32
S = math.sqrt(0.5)
ANGLE_FOR_HEADING = {"north": 180, "east": 90, "south": 0, "west": 270}
CAPTURE_ANGLES = (0, 90, 180, 270)
ACTIVE_FRAMES = tuple(range(1, 97, 6))
# Authored key position is (-7,-12,18), expressed relative to the ground point.
# Orthographic ground shadows use the same fixed direction in all machine poses.
SHADOW_OFFSET_PER_Z = (7.0 / 18.0, 12.0 / 18.0)

def tier_index(tier):
    if tier in NAMES:
        return NAMES.index(tier)
    if type(tier) is int and 1 <= tier <= len(NAMES):
        return tier - 1
    raise ValueError(f"Unknown reactor tier {tier!r}")

def profile(tier, size=None):
    """Make the FMPL profile with ground origin at source (0,0,0)."""
    idx = tier_index(tier)
    radius = RADII[idx]
    hr_size = HR_SIZES[idx]
    if size is None:
        size = hr_size
    if type(size) is not int or size < 1:
        raise ValueError("A positive integer square resolution is required")
    span = hr_size * UNITS_PER_TILE / 64.0
    footprint = [FOOTPRINTS[idx]] * 2
    cfg = {
        "asset": "mars-reactor-" + NAMES[idx].lower(),
        "camera_policy": POLICY_ID,
        "capture_kind": "entity",
        "orientation_policy": "rotatable",
        "directions": list(CAPTURE_ANGLES),
        "source_size": size,
        "sizes": [SD_SIZES[idx], hr_size],
        "fps": 8,
        "states": {"idle": [1], "working": list(ACTIVE_FRAMES)},
        "pivot": [0.0, 0.0, 0.0],
        "scene_scope": {
            "schema": "fmpl.scene-scope.v1",
            "id": f"mars-{NAMES[idx].lower()}-{footprint[0]}x{footprint[1]}",
            "scene_units_per_tile": UNITS_PER_TILE,
            "footprint_tiles": footprint,
            "origin_bu": [0.0, 0.0, 0.0],
            "up_axis": "+Z",
        },
        "camera_override": {
            "type": "ORTHO", "elevation_deg": 45, "azimuth_deg": 0,
            "distance": 6 * span, "target": [0.40 * radius, 0.0, 1.35 * radius],
            "ortho_scale": span, "shift_x": 0.0, "shift_y": 0.0,
        },
    }
    validate_capture_profile(cfg)
    return cfg

def install(scene, tier, size=None):
    """Install and inspect the real FMPL camera in a derived Blender scene.

    Returns the installed, serializable profile. The canonical lifecycle receipt
    is recorded on the scene. Existing authored daylight and world stay fixed.
    """
    import bpy
    import json
    cfg = profile(tier, size)
    change = install_canonical_camera(scene, cfg, bpy)
    assert_clean(scene, cfg, bpy)
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene["fmpl_camera_lifecycle"] = json.dumps(change, sort_keys=True)
    scene["fmpl_capture_profile"] = json.dumps(cfg, sort_keys=True)
    return cfg

def select_direction(root, angle):
    """Reset a family-display root to the asset anchor and rotate the machine."""
    import bpy
    if angle not in CAPTURE_ANGLES:
        raise ValueError(f"Unapproved FMPL entity angle {angle!r}")
    root.location = (0.0, 0.0, 0.0)
    root.rotation_mode = "XYZ"
    root.rotation_euler = (0.0, 0.0, math.radians(angle))
    bpy.context.view_layer.update()

def project(cfg, point: Sequence[float], angle=0):
    """Project source-local XYZ into a pixel position, image origin top left.

    Continuous coordinates follow image edges (0..size) and work at any target
    resolution. Orthographic depth is obtained separately with camera_depth().
    """
    if angle not in CAPTURE_ANGLES:
        raise ValueError(f"Unapproved FMPL entity angle {angle!r}")
    x, y, z = point
    # Exact cardinals avoid floating projection jitter between repeated passes.
    rx, ry = ((x, y), (-y, x), (-x, -y), (y, -x))[int(angle) // 90]
    cx, cy, cz = cfg["camera_override"]["target"]
    size = cfg["source_size"]
    factor = size / cfg["camera_override"]["ortho_scale"]
    return (size / 2 + (rx - cx) * factor,
            size / 2 - ((ry - cy) + (z - cz)) * S * factor)

def camera_depth(cfg, point, angle=0):
    """Linear distance down the camera axis, with nearer surfaces smaller."""
    if angle not in CAPTURE_ANGLES:
        raise ValueError(f"Unapproved FMPL entity angle {angle!r}")
    x, y, z = point
    ry = (y, x, -y, -x)[int(angle) // 90]
    _, cy, cz = cfg["camera_override"]["target"]
    return cfg["camera_override"]["distance"] + (ry - cy - z + cz) * S

def registration(cfg, size=None):
    """Return Factorio Lua scale, tile shift and measured ground-anchor pixel."""
    size = cfg["source_size"] if size is None else size
    if type(size) is not int or size < 1:
        raise ValueError("A positive integer sprite resolution is required")
    cx, cy, cz = cfg["camera_override"]["target"]
    span = cfg["camera_override"]["ortho_scale"]
    units = cfg["scene_scope"]["scene_units_per_tile"]
    return {"scale": 32.0 * span / (units * size),
            "shift": [cx / units, -(cy + cz) * S / units],
            "origin_px": [size * (0.5 - cx / span),
                          size * (0.5 + (cy + cz) * S / span)]}

def audit(scene, cfg):
    import bpy
    assert_clean(scene, cfg, bpy)
    return {"camera": camera_record(scene),
            "registration": registration(cfg),
            "heading_angles": ANGLE_FOR_HEADING.copy(),
            "lights": [{"name": obj.name, "type": obj.data.type,
                        "energy": obj.data.energy, "color": list(obj.data.color),
                        "matrix_world": [list(row) for row in obj.matrix_world]}
                       for obj in sorted(scene.objects, key=lambda o: o.name)
                       if obj.type == "LIGHT"]}
