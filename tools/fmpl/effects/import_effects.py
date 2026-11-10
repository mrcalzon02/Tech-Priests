#!/usr/bin/env python3
"""Append checked FMPL Effects material/FX rig assets to real Blender scenes.

No automatic textures, generators, source mutations, renders or game prototype changes.
Import bpy only inside public callables so standard Python can validate the adapter.
"""
from __future__ import annotations
import hashlib
from pathlib import Path

LIBRARY_VERSION="1.0.2"
PREFIX="FMPL FX | "
RIG_PREFIX="FMPL FX RIG | "
ROOT_PREFIX="FMPL FX ROOT | "

def _check_source(file, expected_sha256=None):
    path=Path(file).resolve()
    if not path.is_file() or path.suffix.lower()!=".blend":
        raise FileNotFoundError("FMPL native effects .blend missing: "+str(path))
    if expected_sha256 is not None:
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        if digest!=expected_sha256:
            raise RuntimeError("FMPL Effects source hash mismatch")
    return path

def import_materials(blend_file, material_ids, *, expected_sha256=None):
    """Return {id: material}; no replacement of existing sources and no silent rename."""
    import bpy
    source=_check_source(blend_file,expected_sha256)
    names=list(material_ids)
    if not names or len(names)!=len(set(names)):
        raise ValueError("Require unique nonempty FMPL material identifiers")
    for identifier in names:
        if not identifier or "/" in identifier or identifier.startswith("."):
            raise ValueError("Invalid material id: "+identifier)
    existing={}
    needed=[]
    for identifier in names:
        material=bpy.data.materials.get(PREFIX+identifier)
        if material is not None:
            if material.get("fmpl_effect_id")!=identifier or material.get("fmpl_effect_version")!=LIBRARY_VERSION:
                raise RuntimeError("Existing material name conflicts with canonical FX asset: "+identifier)
            existing[identifier]=material
        else:
            needed.append(identifier)
    if needed:
        with bpy.data.libraries.load(str(source),link=False) as (available,requested):
            candidates={PREFIX+identifier for identifier in needed}
            missing=candidates-set(available.materials)
            if missing:raise KeyError("FMPL native library lacks: "+", ".join(sorted(missing)))
            requested.materials=[PREFIX+identifier for identifier in needed]
    result={}
    for identifier in names:
        material=bpy.data.materials.get(PREFIX+identifier)
        if material is None or material.get("fmpl_effect_id")!=identifier or material.get("fmpl_effect_version")!=LIBRARY_VERSION:
            raise RuntimeError("FMPL native material append/readback failed: "+identifier)
        result[identifier]=material
    return result

def append_rig(blend_file, rig_id, *, anchor=(0,0,0), scene=None, expected_sha256=None):
    """Append a real 3D animated rig collection and place its root at a machine anchor.

    Caller verifies suitable nozzle/contact geometry, tile dimensions and render direction.
    """
    import bpy
    source=_check_source(blend_file,expected_sha256)
    if not isinstance(rig_id,str) or not rig_id or "/" in rig_id:
        raise ValueError("Invalid FMPL rig identifier")
    if len(anchor)!=3 or any(not isinstance(a,(int,float)) for a in anchor):
        raise ValueError("Anchor must be (x,y,z) real world coordinates")
    name=RIG_PREFIX+rig_id
    if bpy.data.collections.get(name) is not None or bpy.data.objects.get(ROOT_PREFIX+rig_id) is not None:
        raise FileExistsError("FMPL rig already exists; refuse duplicate append: "+rig_id)
    target=scene or bpy.context.scene
    with bpy.data.libraries.load(str(source),link=False) as (available,requested):
        if name not in available.collections:
            raise KeyError("FMPL library lacks animated rig: "+name)
        requested.collections=[name]
    collection=bpy.data.collections.get(name)
    root=bpy.data.objects.get(ROOT_PREFIX+rig_id)
    if collection is None or root is None or root.get("fmpl_effect_rig_id")!=rig_id:
        raise RuntimeError("FX rig collection missing named parent/root after native append")
    target.collection.children.link(collection)
    root.location=tuple(float(v) for v in anchor)
    return collection,root
