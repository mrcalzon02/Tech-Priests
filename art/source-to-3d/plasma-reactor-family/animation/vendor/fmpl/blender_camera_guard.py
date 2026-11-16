"""Blender camera lifecycle authority; uses no persistent inspection cameras."""
from contextlib import contextmanager

from capture_policy import (POLICY_ID, CAMERA_NAME, expected_location,
                            validate_capture_profile, verify_camera_receipt)


def camera_record(scene):
    c = scene.camera
    return {"name": c.name, "matrix_world": [list(r) for r in c.matrix_world],
            "type": c.data.type, "ortho_scale": c.data.ortho_scale,
            "shift_x": c.data.shift_x, "shift_y": c.data.shift_y,
            "resolution": [scene.render.resolution_x, scene.render.resolution_y]}


def assert_clean(scene, cfg, bpy):
    cameras = [o for o in bpy.data.objects if o.type == "CAMERA"]
    if len(cameras) != 1 or cameras[0] is not scene.camera:
        raise ValueError("Saved FMPL environment must contain exactly one canonical camera")
    if scene.camera.get("fmpl_camera_role") != "production":
        raise ValueError("Unapproved camera object in production scene")
    bpy.context.view_layer.update()
    verify_camera_receipt(camera_record(scene), cfg)
    return True


def install_canonical_camera(scene, cfg, bpy):
    """Clear old cameras in memory for derived export. Never save over source."""
    validate_capture_profile(cfg)
    cameras = [o for o in bpy.data.objects if o.type == "CAMERA"]
    for camera in cameras:
        children = [o.name for o in bpy.data.objects
                    if o.parent is camera and o.type != "CAMERA"]
        if children:
            raise ValueError(f"Camera {camera.name} parents model geometry: {children}")
    removed = [o.name for o in cameras]
    for camera in cameras:
        bpy.data.objects.remove(camera, do_unlink=True)
    data = bpy.data.cameras.new("FMPL 45deg Orthographic")
    data.type = "ORTHO"
    data.ortho_scale = float(cfg["camera_override"]["ortho_scale"])
    data.shift_x = data.shift_y = 0.0
    camera = bpy.data.objects.new(CAMERA_NAME, data)
    camera["fmpl_camera_role"] = "production"
    camera["fmpl_camera_policy"] = POLICY_ID
    scene.collection.objects.link(camera)
    camera.location = expected_location(cfg)
    from mathutils import Vector
    camera.rotation_euler = (Vector(cfg["camera_override"]["target"]) -
                             camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.resolution_x = scene.render.resolution_y = cfg["source_size"]
    scene.render.resolution_percentage = 100
    assert_clean(scene, cfg, bpy)
    return {"policy": POLICY_ID, "removed_camera_objects": removed,
            "persistent_camera_count": 1, "name": CAMERA_NAME}


@contextmanager
def temporary_inspection_camera(scene, bpy, label="viewport"):
    """Viewport only. Always dispose even if an inspection fails."""
    previous = scene.camera
    data = bpy.data.cameras.new("FMPL TEMP " + str(label))
    obj = bpy.data.objects.new("FMPL_TEMP_INSPECTION_CAMERA", data)
    obj["fmpl_camera_role"] = "temporary-inspection"
    scene.collection.objects.link(obj)
    try:
        yield obj
    finally:
        scene.camera = previous
        bpy.data.objects.remove(obj, do_unlink=True)
        if data.users == 0:
            bpy.data.cameras.remove(data)
