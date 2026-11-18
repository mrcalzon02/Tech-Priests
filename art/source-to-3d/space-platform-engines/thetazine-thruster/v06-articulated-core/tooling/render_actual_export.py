"""Inspect the actual detailed GLB with the established Thetazine lighting."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, required=True)
parser.add_argument("--glb", type=Path, required=True)
parser.add_argument("--out", type=Path, required=True)
parser.add_argument("--views", default="all")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()))
scene = bpy.context.scene
for obj in list(scene.objects):
    if obj.type not in {"LIGHT", "CAMERA"}:bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(args.glb.resolve()))
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 8
scene.render.resolution_x = scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
views = [
    ("actual-v06-whole", (0,-13,13), (0,-1.7,-.5), 11.8, 17, False),
    ("actual-v06-side-actuator", (4,-3.8,2.8), (1.1,-1.7,-.65), 3.3, 17, False),
    ("actual-v06-upper", (5,-5,6), (0,.15,.9), 5.8, 17, False),
    ("actual-v06-frame-joint", (4,1.0,3.8), (1.90,2.25,1.25), 2.35, 17, False),
    ("actual-v06-ram-root", (3,-6,3), (.65,-2.4,-1.2), 2.9, 17, False),
    ("actual-v06-auger-service", (-4,2.5,4.5), (-1.6,-.12,1.30), 1.8, 17, False),
    ("actual-v06-rear", (6,7,5), (0,-1.7,-.5), 10.8, 33, False),
    ("actual-v06-rear-clay", (6,7,5), (0,-1.7,-.5), 10.8, 33, True),
]
if args.views != "all":
    selected=set(args.views.split(","))
    assert selected <= {row[0] for row in views}
    views=[row for row in views if row[0] in selected]
records = []
for name, location, target, scale, frame, clay in views:
    scene.frame_set(frame)
    scene.camera.location = location
    scene.camera.rotation_euler = (Vector(target)-scene.camera.location).to_track_quat("-Z","Y").to_euler()
    scene.camera.data.type = "ORTHO"
    scene.camera.data.ortho_scale = scale
    scene.view_layers[0].material_override = None
    if clay:
        mat = bpy.data.materials.new("V06 neutral inspection clay")
        mat.use_nodes = True
        bs = mat.node_tree.nodes.get("Principled BSDF")
        bs.inputs["Base Color"].default_value = (.3,.3,.3,1)
        bs.inputs["Metallic"].default_value = 0
        bs.inputs["Roughness"].default_value = .7
        scene.view_layers[0].material_override = mat
    path = out / (name+".png")
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    records.append({"file":path.name,"sha256":sha(path),"frame":frame,"location":location,"target":target,
                    "ortho_scale":scale,"clay":clay,"scope":"Actual reimported physical GLB; no source-only exhaust volume."})
    (out/"render-receipt.json").write_text(json.dumps({"source_sha256":sha(args.source),"glb_sha256":sha(args.glb),
            "script_sha256":sha(Path(__file__)),"rendered":records,"status":"ACTUAL_GLB_VIEWS_REQUIRE_REVIEW"},indent=2)+"\n")
print("V06_ACTUAL_EXPORT_VIEWS_COMPLETE",len(records),flush=True)
