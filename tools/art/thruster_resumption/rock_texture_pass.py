"""Bounded, sprite-referenced wide Noctilith material revision.

Retains geometry and existing UVs. Samples geological masks in source space,
then raster-bakes independent per-rock maps. Base color is explicitly encoded
to sRGB; normal/ORM maps remain linear Non-Color data.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/fmpl"))
from blender_camera_guard import install_canonical_camera, camera_record

parser = argparse.ArgumentParser()
parser.add_argument("--source", type=pathlib.Path, required=True)
parser.add_argument("--out", type=pathlib.Path, required=True)
parser.add_argument("--transplant", type=pathlib.Path)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
src, out = args.source.resolve(), args.out.resolve()
out.mkdir(parents=True, exist_ok=False)
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
for path in src.iterdir():
    if path.is_file() and (path.suffix.lower() in {".json", ".txt"} or path.name == "installation-service-underlay.glb"):
        shutil.copy2(path, out / path.name)
shutil.copytree(src / "textures", out / "textures")
bpy.ops.wm.open_mainfile(filepath=str(src / "large-void-fusion-v01.blend"))
scene = bpy.context.scene


def geometry_digest(obj):
    mesh = obj.data
    return hashlib.sha256(json.dumps({
        "matrix": [list(row) for row in obj.matrix_world],
        "verts": [list(v.co) for v in mesh.vertices],
        "polys": [list(p.vertices) for p in mesh.polygons],
        "uv": [[list(p.uv) for p in layer.data] for layer in mesh.uv_layers],
    }, separators=(",", ":")).encode()).hexdigest()


before = {o.name: geometry_digest(o) for o in scene.objects if o.type == "MESH"}
seats = json.loads((src / "seating-contract.json").read_text())


def noise(points, frequency, seed=0):
    q = points * frequency + np.asarray((seed * .137, seed * .317, seed * .071))
    cell = np.floor(q)
    f = q - cell
    w = f * f * (3 - 2 * f)
    value = np.zeros(len(points))
    for x in (0, 1):
        for y in (0, 1):
            for z in (0, 1):
                raw = np.sin((cell + (x, y, z)) @ np.asarray((127.1, 311.7, 74.7))) * 43758.5453
                value += (raw - np.floor(raw)) * (w[:, 0] if x else 1 - w[:, 0]) * (w[:, 1] if y else 1 - w[:, 1]) * (w[:, 2] if z else 1 - w[:, 2])
    return value


def fracture(points, seed):
    """Irregular 3-D cell-boundary mineral web; no UV-square/checker pattern."""
    q = points * 6.5 + np.asarray((seed * .43, .19, seed * .27))
    cell = np.floor(q)
    distances = []
    for x in (-1, 0, 1):
        for y in (-1, 0, 1):
            for z in (-1, 0, 1):
                corner = cell + (x, y, z)
                jitter = []
                for offset in (.0, 17.3, 91.7):
                    raw = np.sin(corner @ np.asarray((127.1, 311.7, 74.7)) + offset) * 43758.5453
                    jitter.append(raw - np.floor(raw))
                point = corner + .15 + .7 * np.stack(jitter, axis=1)
                distances.append(np.linalg.norm(q - point, axis=1))
    nearest = np.partition(np.stack(distances), 1, axis=0)[:2]
    margin = np.abs(nearest[1] - nearest[0])
    broken = np.clip((noise(points, 4.3, seed) - .22) / .50, 0, 1)
    broken *= np.clip((noise(points, 21, seed + 29) - .30) / .32, 0, 1)
    return np.exp(-(margin / .065) ** 2) * broken


def mineral(points, seed):
    broad = noise(points, 2.5, seed)
    medium = noise(points, 9, seed + 4)
    grain = np.clip((noise(points, 34, seed + 9) - .30) / .40, 0, 1)
    grit = np.clip((noise(points, 105, seed + 12) - .32) / .36, 0, 1)
    seam = fracture(points, seed)
    plane = np.clip(.55 * broad + .30 * medium + .15 * grain, 0, 1)
    # Values here are LINEAR albedo; PNG storage is explicitly sRGB below.
    color = np.asarray((.026, .032, .018))[None, :] * (.30 + 1.60 * plane[:, None])
    color *= (.58 + .84 * grain[:, None]) * (.80 + .40 * grit[:, None])
    ochre = np.asarray((.077, .065, .031))[None, :]
    color = color * (1 - seam[:, None] * .82) + ochre * seam[:, None] * (.62 + .38 * grit[:, None])
    fleck = np.clip((grit - .71) / .29, 0, 1) * np.clip((medium - .50) * 3, 0, 1)
    color += fleck[:, None] * np.asarray((.030, .032, .022))
    roughness = np.clip(.90 - .14 * medium + .13 * grit - .045 * seam, .71, .98)
    height = (medium - .5) * .0035 + (grain - .5) * .0030 + (grit - .5) * .0016 - seam * .0024
    return color, roughness, height, seam


def srgb(linear):
    return np.where(linear <= .0031308, 12.92 * linear, 1.055 * np.maximum(linear, 0) ** (1 / 2.4) - .055)


def image_map(name, data, noncolor):
    image = bpy.data.images.new(name, width=len(data), height=len(data), alpha=True)
    if noncolor:
        image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(data.astype(np.float32).ravel())
    image.update()
    image.filepath_raw = str(out / "textures" / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


records = []
transplant = json.loads((args.transplant / "mineral-materials.json").read_text()) if args.transplant else None
for index in range(3):
    obj = bpy.data.objects["Fractured Noctilith block " + str(index)]
    size = 1024
    if transplant:
        row = next(r for r in transplant["rocks"] if r["object"] == obj.name)
        if row["geometry_uv_digest"] != geometry_digest(obj):
            raise ValueError("Material transfer geometry/UV mismatch " + obj.name)
        images = {}
        for key, meta in row["maps"].items():
            path = args.transplant / meta["file"]
            assert sha(path) == meta["sha256"]
            target = out / "textures" / path.name
            shutil.copy2(path, target)
            image = bpy.data.images.load(str(target), check_existing=False)
            image.colorspace_settings.name = "sRGB" if key == "basecolor" else "Non-Color"
            image.pack()
            images[key] = image
        record = dict(row)
    else:
        arrays = {key: np.ones((size, size, 4), dtype=np.float32) for key in ("basecolor", "normal", "orm")}
        arrays["basecolor"][:, :, :3] = 0
        arrays["normal"][:, :, :3] = (.5, .5, 1)
        arrays["orm"][:, :, :3] = (1, .85, 0)
        occupied = np.zeros((size, size), dtype=bool)
        seam_pixels, samples = 0, 0
        obj.data.calc_loop_triangles()
        uv = obj.data.uv_layers.active
        assert uv is not None
        for tri in obj.data.loop_triangles:
            tex = np.asarray([list(uv.data[i].uv) for i in tri.loops])
            world = np.asarray([list(obj.matrix_world @ obj.data.vertices[i].co) for i in tri.vertices])
            ab, ac = tex[1] - tex[0], tex[2] - tex[0]
            det = ab[0] * ac[1] - ab[1] * ac[0]
            if abs(det) < 1e-14:
                continue
            lo = np.maximum(np.floor(tex.min(0) * size).astype(int), 0)
            hi = np.minimum(np.ceil(tex.max(0) * size).astype(int), size - 1)
            if np.any(hi < lo):
                continue
            yy, xx = np.mgrid[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
            q = np.stack(((xx + .5) / size, (yy + .5) / size), axis=-1) - tex[0]
            b = (q[:, :, 0] * ac[1] - q[:, :, 1] * ac[0]) / det
            c = (ab[0] * q[:, :, 1] - ab[1] * q[:, :, 0]) / det
            inside = (b >= -1e-7) & (c >= -1e-7) & (b + c <= 1.0000001)
            if not inside.any():
                continue
            points = world[0] + b[inside, None] * (world[1] - world[0]) + c[inside, None] * (world[2] - world[0])
            color, rough, height, web = mineral(points, index + 19)
            tangent = ((world[1] - world[0]) * ac[1] - (world[2] - world[0]) * ab[1]) / det
            bitangent = (-(world[1] - world[0]) * ac[0] + (world[2] - world[0]) * ab[0]) / det
            tangent /= np.linalg.norm(tangent)
            bitangent -= tangent * np.dot(tangent, bitangent)
            bitangent /= np.linalg.norm(bitangent)
            # Correct UV-tangent finite differences, not atlas-neighbor gradients across seams.
            epsilon = .0007
            du = (mineral(points + tangent * epsilon, index + 19)[2] - height) / epsilon
            dv = (mineral(points + bitangent * epsilon, index + 19)[2] - height) / epsilon
            normal = np.stack((-du, -dv, np.ones(len(points))), axis=1)
            normal /= np.linalg.norm(normal, axis=1)[:, None]
            px, py = xx[inside], yy[inside]
            arrays["basecolor"][py, px, :3] = srgb(np.clip(color, 0, 1))
            arrays["normal"][py, px, :3] = normal * .5 + .5
            arrays["orm"][py, px, :3] = np.stack((np.ones(len(points)), rough, np.zeros(len(points))), axis=1)
            occupied[py, px] = True
            seam_pixels += int((web > .3).sum())
            samples += len(points)
        sample_colors = arrays["basecolor"][occupied, :3]
        for _ in range(4):
            was = occupied.copy()
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                take = np.roll(was, (dy, dx), (0, 1)) & ~occupied
                if dy == 1: take[0, :] = False
                if dy == -1: take[-1, :] = False
                if dx == 1: take[:, 0] = False
                if dx == -1: take[:, -1] = False
                for array in arrays.values():
                    array[take] = np.roll(array, (dy, dx), (0, 1))[take]
                occupied |= take
        images = {key: image_map("Noctilith-sprite-mineral-%02d-%s" % (index, key), arr, key != "basecolor")
                  for key, arr in arrays.items()}
        record = {"object": obj.name, "geometry_uv_digest": geometry_digest(obj), "resolution": [size, size],
                  "surface_samples": samples, "visible_fracture_mask_fraction": seam_pixels / max(samples, 1),
                  "basecolor_srgb_byte_quantiles_10_50_90": (np.quantile(sample_colors, [.1, .5, .9], axis=0) * 255).round(2).tolist(),
                  "metalness": 0, "maps": {key: {"file": "textures/" + pathlib.Path(image.filepath_raw).name,
                  "sha256": sha(pathlib.Path(image.filepath_raw)), "color_space": image.colorspace_settings.name}
                  for key, image in images.items()}}
    material = bpy.data.materials.new("Noctilith sprite mineral / rock " + str(index))
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 0
    for key, image in images.items():
        tex_node = nodes.new("ShaderNodeTexImage")
        tex_node.image = image
        if key == "basecolor":
            links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        elif key == "orm":
            sep = nodes.new("ShaderNodeSeparateColor")
            links.new(tex_node.outputs["Color"], sep.inputs["Color"])
            links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
            links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        else:
            normal_node = nodes.new("ShaderNodeNormalMap")
            links.new(tex_node.outputs["Color"], normal_node.inputs["Color"])
            links.new(normal_node.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(material)
    records.append(record)
    print("MINERAL_ROCK_BAKED", obj.name, flush=True)

after = {o.name: geometry_digest(o) for o in scene.objects if o.type == "MESH"}
assert before == after, "Material-only revision changed geometry/UV/matrix"
points = [o.matrix_world @ v.co for o in scene.objects if o.type == "MESH" for v in o.data.vertices]
projected = [(p.y + p.z) * 2 ** -.5 for p in points]
target_y = (min(p.y for p in points) + max(p.y for p in points)) / 2
target_z = (min(projected) + max(projected)) / 2 * 2 ** .5 - target_y
scale = max(max(projected) - min(projected), max(p.x for p in points) - min(p.x for p in points)) + .45
profile = {"camera_policy": "fmpl.factorio45.v1", "capture_kind": "entity", "orientation_policy": "fixed",
           "directions": [0], "source_size": 1024, "states": {"cold": [0], "working": [1]},
           "camera_override": {"type": "ORTHO", "elevation_deg": 45, "azimuth_deg": 0,
                               "distance": 18, "ortho_scale": scale, "target": [0, target_y, target_z]}}
removal = install_canonical_camera(scene, profile, bpy)
bpy.ops.file.pack_all()
blend, glb = out / "large-void-fusion-v01.blend", out / "large-void-fusion-v01.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if obj.type in {"MESH", "EMPTY"}:
        obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                         export_yup=True, export_apply=True, export_animations=False,
                         export_cameras=False, export_lights=False)
report = {"status": "MATERIAL_ONLY_BAKED_EXPORTED_REQUIRES_INDEPENDENT_RENDER_REVIEW",
          "input_blend": {"path": str(src / blend.name), "sha256": sha(src / blend.name)},
          "output_blend_sha256": sha(blend), "output_glb_sha256": sha(glb),
          "geometry_uv_matrix_preserved": before == after, "geometry_uv_digests": before,
          "rocks": records, "reference": "docs/art/thruster-resumption-20261117/animation-capture/noctilith-reference.json",
          "scope": "Rock materials only. No stone/cage/wire geometry or sockets changed; green recessed emission retained.",
          "profile": profile, "camera": camera_record(scene), "camera_removal": removal,
          "color_encoding": "Linear dielectric albedo explicitly sRGB-encoded for basecolorPNG; normal/ORM stay linear Non-Color."}
(out / "mineral-materials.json").write_text(json.dumps(report, indent=2) + "\n")
print("MINERAL_EXPORT_READY", str(out), flush=True)
