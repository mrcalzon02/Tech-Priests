#!/usr/bin/env python3
"""FMPL smoke: derivative Water Purifier + real PBR + calibrated reference.

Only the derivative is written. Reference fixtures are hidden from production
sprites and GLB exports. No native pipe cell or gameplay integration is claimed.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_geometry_hash(objects):
    h = hashlib.sha256()
    for obj in sorted(objects, key=lambda o: o.name):
        h.update(obj.name.encode("utf-8"))
        for row in obj.matrix_world:
            for value in row:
                h.update(struct.pack("<d", float(value)))
        for vert in obj.data.vertices:
            h.update(struct.pack("<ddd", *[float(v) for v in vert.co]))
        for face in obj.data.polygons:
            h.update(struct.pack("<I", len(face.vertices)))
            for index in face.vertices:
                h.update(struct.pack("<I", index))
    return h.hexdigest()


def uv_for_visible_surface(obj):
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="FMPL | planar tile UV")
    for polygon in mesh.polygons:
        normal = polygon.normal
        major = max(range(3), key=lambda i: abs(normal[i]))
        u, v = ((1, 2) if major == 0 else ((0, 2) if major == 1 else (0, 1)))
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            pos = obj.matrix_world @ vertex
            layer.data[loop_index].uv = (float(pos[u])*1.25, float(pos[v])*1.25)


def material_key(name):
    value = name.lower().replace("mh7 ", "")
    options = [
        ("gunmetal", "gunmetal_dark"),
        ("steel", "machine_steel"),
        ("iron", "iron"),
        ("brass", "brass"),
        ("red", "martian_red"),
        ("dark", "dark_recess"),
        ("glass", "glass"),
    ]
    return next((result for token, result in options if token in value), None)


def prepare_camera(scene):
    camera_data = bpy.data.cameras.new("FMPL | 45 degree orthographic lens")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 6.6
    camera = bpy.data.objects.new("FMPL | 45 degree camera", camera_data)
    scene.collection.objects.link(camera)
    target = Vector((0, 0, 1.35))
    camera.location = target + Vector((7.0, -7.0, 8.0))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.device = "CPU"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100
    if not any(o.type == "LIGHT" for o in scene.objects):
        sun_data = bpy.data.lights.new("FMPL | daylight", "SUN")
        sun_data.energy = 2.0
        sunlight = bpy.data.objects.new("FMPL | daylight", sun_data)
        scene.collection.objects.link(sunlight)
        sunlight.rotation_euler = (math.radians(33), math.radians(-25), math.radians(21))
    return camera


def load_module(filepath, name):
    spec = importlib.util.spec_from_file_location(name, filepath)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    p = argparse.ArgumentParser()
    for x in ("source", "expected-sha", "fmpl-root", "pipe-reference",
              "pipe-helper", "out", "glb", "report", "preview"):
        p.add_argument("--" + x, required=True)
    args = p.parse_args(sys.argv[sys.argv.index("--")+1:])
    src = Path(args.source).resolve()
    out = Path(args.out).resolve()
    glb = Path(args.glb).resolve()
    report_path = Path(args.report).resolve()
    preview = Path(args.preview).resolve()
    for path in (out, glb, report_path, preview):
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            raise FileExistsError("FMPL refuses to overwrite existing candidate " + str(path))
    if sha(src) != args.expected_sha:
        raise RuntimeError("Water Purifier candidate SHA-256 differs from FMPL checkpoint")
    fmpl = Path(args.fmpl_root).resolve()
    lib_script = fmpl/"art/source-to-3d/shared-parts/industrial-asset-library/import_materials.py"
    manifest_path = fmpl/"art/source-to-3d/shared-parts/industrial-asset-library/catalog.json"
    catalog = json.loads(manifest_path.read_text(encoding="utf-8"))
    if len(catalog["materials"]) != 23 or len(catalog["candidates"]) != 39:
        raise RuntimeError("The FMPL catalog is not the tested module set")
    bpy.ops.wm.open_mainfile(filepath=str(src))
    scene = bpy.context.scene
    source_objects = [o for o in scene.objects if o.type == "MESH" and o.name.startswith("MH7_")]
    if len(source_objects) < 45:
        raise RuntimeError("Expected the actual four-goal Water Purifier, not an empty stage")
    original_geometry = source_geometry_hash(source_objects)
    mats = load_module(lib_script, "fmpl_material_importer").import_materials(
        fmpl, ["machine_steel", "iron", "brass", "martian_red",
               "gunmetal_dark", "dark_recess", "glass"])
    assignments = {}
    for obj in source_objects:
        original = obj.data.materials[0].name if obj.data.materials else ""
        replacement = material_key(original)
        if replacement:
            uv_for_visible_surface(obj)
            obj.data.materials.clear()
            obj.data.materials.append(mats[replacement])
            assignments[replacement] = assignments.get(replacement, 0) + 1
    if len(assignments) < 3 or sum(assignments.values()) < 24:
        raise RuntimeError("FMPL PBR material assignment did not cover the machinery")
    if source_geometry_hash(source_objects) != original_geometry:
        raise RuntimeError("Unexpected modification to original Water Purifier geometry")
    jigfile = Path(args.pipe_reference)
    jig_hash = sha(jigfile)
    if jig_hash != "af6d1d74f0439b327b0b4e496386aa35fdac0859c177b55707dbfb5243e691ca":
        raise RuntimeError("Unexpected fluid reference source hash")
    helper = load_module(Path(args.pipe_helper).resolve(), "fmpl_pipe_append")
    interface_receipts = []
    for name, coordinates, direction in (
        ("raw-water-in", (-1.5, -.78, 0.0), "W"),
        ("purified-water-out", (1.5, -.62, 0.0), "E"),
    ):
        collection, root = helper.append_interface(
            jigfile, joint_ground=coordinates, facing=direction,
            name="FMPL QA reference | " + name, scene=scene)
        bpy.context.view_layer.update()
        sockets = [obj for obj in collection.all_objects
                   if obj.get("interface_role") == "socket_marker"]
        if len(sockets) != 1:
            raise RuntimeError("Missing native reference socket marker")
        position = tuple(float(v) for v in sockets[0].matrix_world.translation)
        expected = (coordinates[0], coordinates[1], .36)
        error = math.dist(position, expected)
        if error > 0.0002:
            raise RuntimeError("Physical reference fixture misaligned: " + str(error))
        fixture_objects=[ob for ob in list(collection.all_objects) if ob is not None]
        if len(fixture_objects) < 9:
            raise RuntimeError("Expected all nine actual fluid-interface reference objects")
        for ob in fixture_objects:
            ob.hide_render = True
        interface_receipts.append({"name": name,"socket_world_xyz": list(position),
          "facing":direction,"root_scale":list(root.scale),
          "ground_position":list(coordinates),"reference_mating_error_tiles":error,
          "native_factorio_port_verified":False})
    if source_geometry_hash(source_objects) != original_geometry:
        raise RuntimeError("The fluid reference appendix changed source geometry")
    prepare_camera(scene)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(out), compress=True, check_existing=False)
    # Export ONLY authored machine parts. Calibration aids never enter game art.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in source_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = source_objects[0]
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB",
                              use_selection=True, export_apply=True)
    scene.render.resolution_x = 420
    scene.render.resolution_y = 420
    scene.render.filepath = str(preview)
    bpy.ops.render.render(write_still=True)
    actual = {
      "schema":"fmpl.production-smoke.v1", "status":"built",
      "model_id":"water-purifier-mh7",
      "source_candidate_sha256":args.expected_sha,
      "source_mesh_count":len(source_objects),
      "source_geometry_digest":original_geometry,
      "derivative_blend_sha256":sha(out),
      "exported_glb_sha256":sha(glb),
      "preview_sha256":sha(preview),
      "materials_assigned":assignments,
      "pbr_presets_imported":list(mats),
      "packed_file_images":sum(bool(img.packed_file) for img in bpy.data.images if img.source=="FILE"),
      "calibration_reference_sha256":jig_hash,
      "pipe_references":interface_receipts,
      "source_preserved":True,
      "human_visual_approval":False,
      "factorio_native_port_verified":False,
      "game_integrated":False
    }
    report_path.write_text(json.dumps(actual, indent=2)+"\n", encoding="utf-8")
    print("FMPL_SCENE_BUILT " + json.dumps({
        "objects":len(source_objects),"materials":assignments,
        "pipe_jigs":len(interface_receipts)}),flush=True)


if __name__ == "__main__":
    main()
