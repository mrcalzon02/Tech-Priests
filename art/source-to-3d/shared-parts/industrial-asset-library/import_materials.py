"""Import existing Bunker v10 PBR maps as packed materials in a Blender scene.

No downloaded assets, generation or source mutation. Requires actual mesh UVs.
Call from Blender Python only (bpy is imported inside the function).
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parent / "catalog.json"


def import_materials(repo_root, material_ids=None, *, pack=True):
    import bpy
    repo = Path(repo_root).resolve()
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    records = {item["material_id"]: item for item in catalog["materials"]}
    names = list(records) if material_ids is None else list(material_ids)
    unknown = sorted(set(names) - set(records))
    if unknown:
        raise ValueError("Unknown source materials: " + ", ".join(unknown))
    result = {}
    for name in names:
        spec = records[name]
        paths = {kind: repo / data["source_path"] for kind, data in spec["maps"].items()}
        for kind, path in paths.items():
            if not path.is_file():
                raise FileNotFoundError(f"{name}:{kind}: missing committed map {path}")
        mat_name = "TP Library | " + name
        existing = bpy.data.materials.get(mat_name)
        if existing is not None:
            if existing.get("tp_library_material_id") != name:
                raise ValueError("Name collision with non-library material: " + mat_name)
            result[name] = existing
            continue
        mat = bpy.data.materials.new(mat_name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        if not bsdf:
            raise RuntimeError("Blender Principled BSDF node is missing")
        tex = {}
        for kind, path in paths.items():
            image = bpy.data.images.load(str(path), check_existing=True)
            if kind != "albedo":
                image.colorspace_settings.name = "Non-Color"
            if pack:
                image.pack()
            node = nodes.new("ShaderNodeTexImage")
            node.name = "TP_LIBRARY_" + kind.upper()
            node.image = image
            node.extension = "REPEAT"
            tex[kind] = node
        links.new(tex["albedo"].outputs["Color"], bsdf.inputs["Base Color"])
        split = nodes.new("ShaderNodeSeparateColor")
        split.mode = "RGB"
        links.new(tex["orm"].outputs["Color"], split.inputs["Color"])
        links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
        normal = nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = .45 if name.startswith("ferrocrete") else .28
        links.new(tex["normal"].outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        mat["tp_library_material_id"] = name
        mat["tp_library_source_commit"] = catalog["source_commit"]
        mat["tp_library_source_manifest"] = spec["source_manifest"]
        mat["tp_library_maps_sha256"] = json.dumps({k: hashlib.sha256(p.read_bytes()).hexdigest() for k, p in paths.items()}, sort_keys=True)
        result[name] = mat
    return result
