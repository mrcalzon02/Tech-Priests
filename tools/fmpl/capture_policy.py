"""Single authoritative FMPL production camera and capture-type validation."""
import math

POLICY_ID = "fmpl.factorio45.v1"
CAMERA_NAME = "FMPL_CAPTURE_CAMERA"
ENTITY_DIRECTIONS = (0, 90, 180, 270)
ITEM_DIRECTIONS = (0,)
TOL = 1e-4


def number(value, label):
    if type(value) not in (int, float) or not math.isfinite(value):
        raise ValueError(f"{label} must be a finite number")
    return float(value)


def validate_capture_profile(cfg):
    if not isinstance(cfg, dict) or cfg.get("camera_policy") != POLICY_ID:
        raise ValueError(f"FMPL capture requires camera_policy {POLICY_ID}")
    kind = cfg.get("capture_kind")
    if kind not in ("entity", "item"):
        raise ValueError("capture_kind must be entity or item")
    correct = ENTITY_DIRECTIONS if kind == "entity" else ITEM_DIRECTIONS
    directions = cfg.get("directions")
    if (not isinstance(directions, list) or
            len(directions) != len(correct) or
            any(type(x) not in (int, float) or not math.isfinite(x) for x in directions) or
            tuple(directions) != correct):
        raise ValueError(f"Invalid {kind} directions; only {correct} are permitted")
    states = cfg.get("states")
    if not isinstance(states, dict) or not states:
        raise ValueError("At least one capture state required")
    if kind == "item":
        if list(states) != ["icon"] or not isinstance(states["icon"], list) or len(states["icon"]) != 1:
            raise ValueError("An item capture is one icon image, not a multi-view or animation")
    elif "icon" in states:
        raise ValueError("Entity captures cannot include an item icon state")
    cam = cfg.get("camera_override")
    if not isinstance(cam, dict) or cam.get("type", "ORTHO") != "ORTHO":
        raise ValueError("FMPL requires explicit orthographic camera_override")
    if abs(number(cam.get("elevation_deg"), "elevation_deg")-45) > 1e-7:
        raise ValueError("Camera must be at exactly 45 degrees elevation")
    if abs(number(cam.get("azimuth_deg"), "azimuth_deg")) > 1e-7:
        raise ValueError("Camera must be aligned to model grid at zero azimuth")
    for key in ("distance", "ortho_scale"):
        if number(cam.get(key), key) <= 0:
            raise ValueError(f"{key} must be positive")
    for key in ("shift_x", "shift_y"):
        if key in cam and abs(number(cam[key], key)) > TOL:
            raise ValueError("Camera lens shifts are not permitted")
    target = cam.get("target")
    if not isinstance(target, (list, tuple)) or len(target) != 3:
        raise ValueError("Camera target must contain three coordinates")
    for i, x in enumerate(target):
        number(x, f"target[{i}]")
    return kind


def expected_location(cfg):
    validate_capture_profile(cfg)
    cam = cfg["camera_override"]
    d = float(cam["distance"])
    t = [float(v) for v in cam["target"]]
    s = math.sqrt(0.5)
    return (t[0], t[1]-d*s, t[2]+d*s)


def verify_camera_receipt(record, cfg):
    """Inspect rendered Blender matrix, not only the configured requested angle."""
    validate_capture_profile(cfg)
    if not isinstance(record, dict) or record.get("name") != CAMERA_NAME:
        raise ValueError("Production receipt must identify the canonical FMPL camera")
    if record.get("type") != "ORTHO":
        raise ValueError("Camera must be orthographic")
    if abs(number(record.get("ortho_scale"), "ortho_scale")-float(cfg["camera_override"]["ortho_scale"])) > TOL:
        raise ValueError("Capture ortho_scale drift")
    for key in ("shift_x", "shift_y"):
        if abs(number(record.get(key), key)) > TOL:
            raise ValueError("Capture contains nonzero lens shift")
    if cfg.get("source_size") is not None and record.get("resolution") != [cfg["source_size"]]*2:
        raise ValueError("Capture resolution is not the prescribed square")
    m = record.get("matrix_world")
    if not isinstance(m, (list, tuple)) or len(m) != 4 or any(
        not isinstance(row, (list,tuple)) or len(row) != 4 for row in m
    ):
        raise ValueError("Missing/invalid camera matrix")
    for row in m:
        for v in row: number(v, "camera matrix element")
    location = expected_location(cfg)
    if any(abs(m[i][3]-location[i]) > TOL for i in range(3)):
        raise ValueError("Camera location moved")
    # Camera local +Z points backwards; local +Y points image-up.
    s = math.sqrt(.5)
    back = (0, -s, s)
    up = (0, s, s)
    if any(abs(m[i][2]-back[i]) > TOL for i in range(3)):
        raise ValueError("Camera direction no longer 45-degree grid aligned")
    if any(abs(m[i][1]-up[i]) > TOL for i in range(3)):
        raise ValueError("Camera rolled or changed grid orientation")
    return True
