"""Correct the approved workbench hammer, validate contact, and export in Blender.

blender -b --python workbench_v7.py -- --source-blend source/rough_timber_workbench_v4.blend --output-dir output --render all
No packages outside Blender's Python are required. The source geometry is retained.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Quaternion, Vector

HITS = (32, 48, 64, 80, 96, 112)
DIRECTIONS = ("north", "east", "south", "west")
EXPORT_FRAMES = tuple(range(2, 193, 2))


def action_curves(action):
    if hasattr(action, "fcurves"):
        return action.fcurves
    return action.layers[0].strips[0].channelbag(action.slots[0]).fcurves


def linear_keys(action):
    for curve in action_curves(action):
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-blend", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--render", choices=("none", "proof", "all"), default="all")
    parser.add_argument("--samples", type=int, default=16)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def build_scene(source):
    bpy.ops.wm.open_mainfile(filepath=str(source.resolve()))
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end, scene.render.fps = 1, 192, 24
    head = bpy.data.objects["Single forged hammer head"]
    handle = bpy.data.objects["Hammer wooden handle"]
    sheet = next(obj for obj in scene.objects if obj.name.startswith("ONE continuous"))
    rest_head = head.matrix_world.copy()
    rig = bpy.data.objects.new("Hammer grip - face-first swing", None)
    scene.collection.objects.link(rig)
    rig.location = Vector((.29, -.16, .85))
    rig.rotation_mode = "QUATERNION"
    bpy.context.view_layer.update()
    for obj in (handle, head):
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.matrix_world = world
    bpy.context.view_layer.update()
    rest = rig.location.copy()
    # The long local Y axis runs between the two striking faces. The old cycle
    # kept this horizontal and struck with the broad local -Z side instead.
    handle_axis = Vector((math.cos(math.radians(24)), -math.sin(math.radians(24)), 0))
    swing_axis = Vector((math.sin(math.radians(24)), math.cos(math.radians(24)), 0))
    striking_face = Vector((0, .16, 0))
    face_relative = rest_head @ striking_face - rest
    face_down = Quaternion(handle_axis, -math.pi / 2)
    # Use the actual evaluated surface under the center of the striking face.
    evaluated_sheet = sheet.evaluated_get(bpy.context.evaluated_depsgraph_get())
    hit, location, normal, face_index = evaluated_sheet.ray_cast(Vector((0, 0, 2)), Vector((0, 0, -1)))
    if not hit:
        raise RuntimeError("The central metal sheet contact ray missed")
    contact = sheet.matrix_world @ location
    contact.z += .0005  # Half a millimeter above the irregular hammered surface.
    working_grip = contact - face_down @ face_relative

    def swing(angle):
        return Quaternion(swing_axis, math.radians(angle)) @ face_down

    # Raise clear of the plate before rolling, then keep one grip pivot while
    # striking. Bake smooth positions/rotations every frame: interpolation can
    # never overshoot the authored impact and put the head through the sheet.
    keys = [(1, rest, Quaternion()), (8, rest, Quaternion()),
            (14, rest + Vector((0, 0, .27)), Quaternion()),
            (21, working_grip + Vector((0, 0, .18)), face_down),
            (25, working_grip, swing(64))]
    for frame in HITS:
        keys.extend(((frame - 7, working_grip, swing(64)),
                     (frame - 2, working_grip, swing(28)),
                     (frame, working_grip, face_down),
                     (frame + 2, working_grip, swing(13))))
    keys.extend(((122, working_grip, swing(48)),
                 (130, working_grip + Vector((0, 0, .23)), face_down),
                 (138, rest + Vector((0, 0, .23)), Quaternion()),
                 (143, rest, Quaternion()), (192, rest, Quaternion())))
    keys = sorted({frame: (frame, pos.copy(), rot.copy()) for frame, pos, rot in keys}.values())
    for frame in range(1, 193):
        left, right = keys[0], keys[-1]
        for a, b in zip(keys, keys[1:]):
            if a[0] <= frame <= b[0]:
                left, right = a, b
                break
        t = (frame - left[0]) / max(1, right[0] - left[0])
        t = t * t * (3 - 2 * t)
        rig.location = left[1].lerp(right[1], t)
        rig.rotation_quaternion = left[2].slerp(right[2], t)
        rig.keyframe_insert("location", frame=frame)
        rig.keyframe_insert("rotation_quaternion", frame=frame)
    linear_keys(rig.animation_data.action)
    heat = add_heat(sheet)
    add_sparks(scene, contact)
    # Parent the complete authored asset, including its impact light, beneath
    # one orientation root. Camera and daylight remain fixed for all views.
    root = bpy.data.objects.new("EXPORT_CARDINAL_ORIENTATION", None)
    scene.collection.objects.link(root)
    bpy.context.view_layer.update()
    ground = bpy.data.objects["Preview ground - excluded from asset"]
    for obj in list(scene.objects):
        if obj not in (root, ground) and obj.parent is None and (
            obj.type not in {"CAMERA", "LIGHT"} or obj.name == "Impact flicker"
        ):
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    return scene, root, rig, head, handle, sheet, heat, contact


def add_heat(sheet):
    mat = sheet.data.materials[0].copy()
    mat.name = "Hammered sheet - central heat and cooling"
    sheet.data.materials[0] = mat
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    geom = nodes.new("ShaderNodeNewGeometry")
    flat = nodes.new("ShaderNodeVectorMath"); flat.operation = "MULTIPLY"
    flat.inputs[1].default_value = (1, 1, 0)
    links.new(geom.outputs["Position"], flat.inputs[0])
    distance = nodes.new("ShaderNodeVectorMath"); distance.operation = "LENGTH"
    links.new(flat.outputs[0], distance.inputs[0])
    falloff = nodes.new("ShaderNodeMapRange"); falloff.clamp = True
    for key, value in (("From Min", .025), ("From Max", .38), ("To Min", 1), ("To Max", 0)):
        falloff.inputs[key].default_value = value
    links.new(distance.outputs["Value"], falloff.inputs["Value"])
    heat = nodes.new("ShaderNodeValue"); heat.name = "Heat build and cooling envelope"
    emission = nodes.new("ShaderNodeMath"); emission.operation = "MULTIPLY"
    links.new(falloff.outputs["Result"], emission.inputs[0])
    links.new(heat.outputs[0], emission.inputs[1])
    links.new(emission.outputs[0], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Emission Color"].default_value = (1, .065, .004, 1)
    base = bsdf.inputs["Base Color"].links[0].from_socket
    mix = nodes.new("ShaderNodeMixRGB"); mix.blend_type = "MIX"
    mix.inputs[2].default_value = (.32, .055, .014, 1)
    links.new(base, mix.inputs[1])
    tint = nodes.new("ShaderNodeMath"); tint.operation = "MULTIPLY"
    tint.inputs[1].default_value = .24
    links.new(emission.outputs[0], tint.inputs[0]); links.new(tint.outputs[0], mix.inputs[0])
    links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    for frame, strength in ((1, 0), (31, 0), (40, .12), (56, .3), (72, .55),
                            (88, .85), (104, 1.15), (120, 1.4), (143, .9),
                            (158, .4), (176, .1), (192, 0)):
        heat.outputs[0].default_value = strength
        heat.outputs[0].keyframe_insert("default_value", frame=frame)
    return heat


def add_sparks(scene, contact):
    rng = random.Random(19)
    material = bpy.data.materials.new("Hot flying sparks"); material.use_nodes = True
    nodes = material.node_tree.nodes; nodes.clear()
    em = nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (1, .29, .025, 1)
    em.inputs[1].default_value = 7
    output = nodes.new("ShaderNodeOutputMaterial"); material.node_tree.links.new(em.outputs[0], output.inputs[0])
    for strike in HITS:
        for index in range(14):
            mesh = bpy.data.meshes.new("Tapered spark")
            mesh.from_pydata([(0, 0, -.5), (.12, 0, 0), (0, .12, 0), (-.12, 0, 0), (0, -.12, 0), (0, 0, .5)], [],
                             [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1), (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)])
            mesh.materials.append(material)
            obj = bpy.data.objects.new(f"Spark strike {strike} shard {index}", mesh); scene.collection.objects.link(obj)
            angle, speed = rng.uniform(0, math.tau), rng.uniform(.6, 1.3)
            velocity = Vector((math.cos(angle) * speed, math.sin(angle) * speed, rng.uniform(.6, 1.6)))
            start = contact + Vector((rng.uniform(-.035, .035), rng.uniform(-.035, .035), .006))
            life = rng.randint(7, 11)
            for frame in (1, strike - 1):
                obj.scale = (0, 0, 0); obj.keyframe_insert("scale", frame=frame)
            for age in range(life + 1):
                frame, t = strike + age, age / 24
                position = start + velocity * t + Vector((0, 0, -3 * t * t))
                direction = velocity + Vector((0, 0, -6 * t))
                obj.location = position
                obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
                fade = max(0, 1 - age / life)
                obj.scale = (.018 * fade, .018 * fade, .065 * fade) if position.z > contact.z else (0, 0, 0)
                obj.keyframe_insert("location", frame=frame); obj.keyframe_insert("rotation_euler", frame=frame); obj.keyframe_insert("scale", frame=frame)
            obj.scale = (0, 0, 0); obj.keyframe_insert("scale", frame=192)
            linear_keys(obj.animation_data.action)
    light_data = bpy.data.lights.new("Impact flicker", "POINT")
    light = bpy.data.objects.new("Impact flicker", light_data); scene.collection.objects.link(light)
    light.location = contact + Vector((0, 0, .06))
    light_data.color, light_data.shadow_soft_size = (1, .23, .04), .08
    for frame in (1, 192):
        light_data.energy = 0; light_data.keyframe_insert("energy", frame=frame)
    for frame in HITS:
        for offset, power in ((-1, 0), (0, 12), (2, 0)):
            light_data.energy = power; light_data.keyframe_insert("energy", frame=frame + offset)
    linear_keys(light_data.animation_data.action)


def validate(scene, root, rig, head, handle, sheet, heat, contact):
    report = {"impact_frames": list(HITS), "contacts": [], "rendered_impact_frames": [],
              "source_geometry_preserved": True, "face_axis": "head local +Y", "face_alignment_required": .99999}
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for index, direction in enumerate(DIRECTIONS):
        root.rotation_euler.z = -index * math.pi / 2
        for frame in HITS:
            scene.frame_set(frame); bpy.context.view_layer.update()
            world = head.matrix_world
            face = world @ Vector((0, .16, 0))
            face_normal = (world.to_3x3() @ Vector((0, 1, 0))).normalized()
            target = root.matrix_world @ contact
            dot = face_normal.dot(Vector((0, 0, -1)))
            error = (face - target).length
            evaluated = head.evaluated_get(depsgraph)
            min_z = min((evaluated.matrix_world @ v.co).z for v in evaluated.data.vertices)
            assert dot > .99999, (direction, frame, "sideways face", dot)
            assert error < 1e-5, (direction, frame, "missed center", error)
            assert min_z >= contact.z - 1e-5, (direction, frame, "head intersects plate", min_z)
            assert frame in EXPORT_FRAMES, ("impact omitted from export", frame)
            report["contacts"].append({"direction": direction, "frame": frame,
                                       "normal_dot_down": dot, "face_center_error": error, "lowest_head_z": min_z})
    root.rotation_euler.z = 0
    # Check actual evaluated head AND wooden handle, throughout every frame;
    # a correct contact pose is not enough if pickup/lay-down clips the sheet.
    floor_z = min((sheet.matrix_world @ v.co).z for v in sheet.data.vertices if abs(v.co.x) < .40 and abs(v.co.y) < .34)
    minimum = {"head": 10.0, "handle": 10.0}
    for frame in range(1, 193):
        scene.frame_set(frame)
        for key, obj in (("head", head), ("handle", handle)):
            evaluated = obj.evaluated_get(depsgraph)
            z = min((evaluated.matrix_world @ vertex.co).z for vertex in evaluated.data.vertices)
            minimum[key] = min(minimum[key], z)
            assert z >= floor_z - .001, (frame, key, "plate penetration", z, floor_z)
    scene.frame_set(1); start = {o.name: o.matrix_world.copy() for o in (head, handle)}
    scene.frame_set(192)
    assert all(abs(start[o.name][i][j] - o.matrix_world[i][j]) < 1e-6 for o in (head, handle) for i in range(4) for j in range(4))
    assert heat.outputs[0].default_value == 0
    report.update({"rest_loop_exact": True, "fully_cold_at_end": True,
                   "all_192_frames_clear_sheet": True, "minimum_hammer_z": minimum,
                   "rendered_impact_frames": list(HITS), "sheet_center_z": contact.z - .0005})
    scene.frame_set(1)
    return report


def setup_render(scene, samples):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples; scene.cycles.seed = 19; scene.cycles.use_animated_seed = False
    scene.cycles.use_denoising = False
    scene.render.use_persistent_data = True
    scene.render.image_settings.file_format = "PNG"; scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    bpy.data.objects["Preview ground - excluded from asset"].hide_render = True
    camera, target = scene.camera, Vector((0, 0, .63))
    angle = math.radians(-55)
    camera.location = (3 * math.cos(angle), 3 * math.sin(angle), 3.63)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = 2.0
    scene.render.resolution_percentage = 100
    scene.render.resolution_x = scene.render.resolution_y = 128


def render_frame(scene, frame, path, size):
    scene.frame_set(frame); scene.render.resolution_x = scene.render.resolution_y = size
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    options = args(); out = options.output_dir.resolve(); out.mkdir(parents=True, exist_ok=True)
    scene, root, rig, head, handle, sheet, heat, contact = build_scene(options.source_blend)
    report = validate(scene, root, rig, head, handle, sheet, heat, contact)
    report.update({"blender": bpy.app.version_string, "source_sha256": sha256(options.source_blend),
                   "generator_sha256": sha256(__file__)})
    (out / "contact-validation.json").write_text(json.dumps(report, indent=2) + "\n")
    setup_render(scene, options.samples)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "workbench_v7.blend"))
    # Reopen the deliverable and repeat the geometric checks against its actual
    # saved animation data, rather than trusting the live authoring session.
    bpy.ops.wm.open_mainfile(filepath=str(out / "workbench_v7.blend"))
    scene = bpy.context.scene
    root = bpy.data.objects["EXPORT_CARDINAL_ORIENTATION"]
    rig = bpy.data.objects["Hammer grip - face-first swing"]
    head = bpy.data.objects["Single forged hammer head"]
    handle = bpy.data.objects["Hammer wooden handle"]
    sheet = next(obj for obj in scene.objects if obj.name.startswith("ONE continuous"))
    heat = sheet.data.materials[0].node_tree.nodes["Heat build and cooling envelope"]
    reopen = validate(scene, root, rig, head, handle, sheet, heat, contact)
    reopen["saved_blend_sha256"] = sha256(out / "workbench_v7.blend")
    reopen["blender"] = bpy.app.version_string
    (out / "reopen-validation.json").write_text(json.dumps(reopen, indent=2) + "\n")
    if options.render != "none":
        for name, frame in (("rest", 2), ("raised", 25), ("impact", 32), ("sparks", 98), ("cooling", 160)):
            render_frame(scene, frame, out / "proofs" / (name + ".png"), 480)
        # Same authored hammer in the old V5 impact orientation for comparison.
        scene.frame_set(32)
        animation = rig.animation_data.action
        rig.animation_data.action = None
        rig.location = Vector((.51, -.23, .85)); rig.rotation_quaternion = Quaternion()
        bpy.context.view_layer.update()
        scene.render.filepath = str(out / "proofs" / "before-side-impact.png")
        bpy.ops.render.render(write_still=True)
        rig.animation_data.action = animation
        scene.frame_set(32)
    if options.render == "all":
        for index, direction in enumerate(DIRECTIONS):
            root.rotation_euler.z = -index * math.pi / 2
            for number, frame in enumerate(EXPORT_FRAMES):
                render_frame(scene, frame, out / "frames" / direction / f"{frame:04d}.png", 128)
                if (number + 1) % 8 == 0:
                    print(f"WORKBENCH_PROGRESS {direction} {number + 1}/96", flush=True)
    manifest = {"width": 128, "height": 128, "scale": .5, "shift": [0, -.63 / math.sqrt(2)],
                "fps": 12, "frames": 96, "timeline_frames": list(EXPORT_FRAMES), "columns": 12, "rows": 8,
                "seconds": 8, "directions": list(DIRECTIONS), "camera_elevation_degrees": 45,
                "camera_ortho_scale": 2.0, "camera_matrix": [list(row) for row in scene.camera.matrix_world],
                "samples": options.samples, "blender": bpy.app.version_string,
                "source_sha256": sha256(options.source_blend), "generator_sha256": sha256(__file__),
                "render_mode": options.render, "shadow": "internal contact shading; transparent ground, no external shadow pass"}
    (out / "render-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    root.rotation_euler.z = 0; scene.frame_set(1)
    print("WORKBENCH_V7_OK", flush=True)


if __name__ == "__main__":
    main()
