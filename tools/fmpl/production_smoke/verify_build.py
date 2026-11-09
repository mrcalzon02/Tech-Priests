#!/usr/bin/env python3
"""Independent Blender reopen, actual PBR, jig and GLB roundtrip validation."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy


def sha(file):
    return hashlib.sha256(Path(file).read_bytes()).hexdigest()


def geometry_hash(objects):
    h=hashlib.sha256()
    for obj in sorted(objects,key=lambda o:o.name):
        h.update(obj.name.encode("utf-8"))
        for row in obj.matrix_world:
            for val in row:
                h.update(struct.pack("<d",float(val)))
        for vert in obj.data.vertices:
            h.update(struct.pack("<ddd",*[float(q) for q in vert.co]))
        for face in obj.data.polygons:
            h.update(struct.pack("<I",len(face.vertices)))
            for idx in face.vertices:
                h.update(struct.pack("<I",idx))
    return h.hexdigest()


def main():
    parser=argparse.ArgumentParser()
    for key in ("blend","glb","build-report","out"):
        parser.add_argument("--"+key,required=True)
    a=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    build=json.loads(Path(a.build_report).read_text(encoding="utf-8"))
    if sha(a.blend)!=build["derivative_blend_sha256"] or sha(a.glb)!=build["exported_glb_sha256"]:
        raise RuntimeError("FMPL native/GLB hash changed before independent reopening")
    bpy.ops.wm.open_mainfile(filepath=str(Path(a.blend).resolve()))
    scene=bpy.context.scene
    source=[x for x in scene.objects if x.type=="MESH" and x.name.startswith("MH7_")]
    if len(source)!=build["source_mesh_count"] or geometry_hash(source)!=build["source_geometry_digest"]:
        raise RuntimeError("The derivative altered the source machine geometry")
    if not scene.camera or scene.camera.data.type!="ORTHO" or scene.render.engine!="CYCLES":
        raise RuntimeError("The source camera or Cycles render configuration was lost")
    cameras=[o for o in scene.objects if o.type=="CAMERA"]
    expected=(0.0,-6.0,7.65)
    if (len(cameras)!=1 or scene.camera != cameras[0] or
        max(abs(float(scene.camera.location[i])-expected[i]) for i in range(3))>0.001 or
        abs(scene.camera.data.ortho_scale-5.8)>0.001):
        raise RuntimeError("One canonical zero-azimuth 45-degree camera required")
    for name,xyz in (("raw-water-in",(-1.5,0.0,0.36)),("purified-water-out",(1.5,0.0,0.36))):
        records=[e for e in build["pipe_references"] if e["name"]==name]
        if len(records)!=1 or max(abs(records[0]["socket_world_xyz"][i]-xyz[i]) for i in range(3))>0.0002:
            raise RuntimeError("Provisional centred edge-port plane is off grid: "+name)
    mats=set()
    for obj in source:
        mats.update(m.name for m in obj.data.materials if m.name.startswith("TP Library |"))
    if len(mats)<3:
        raise RuntimeError("FMPL material slots missing on saved source geometry")
    images=[i for i in bpy.data.images if i.source=="FILE"]
    packed_count=len([i for i in images if i.packed_file])
    if packed_count<10:
        raise RuntimeError("FMPL PBR textures were not packed into Blender derivative")
    refs=[c for c in bpy.data.collections if c.name.startswith("FMPL QA reference |")]
    if len(refs)!=2:
        raise RuntimeError("Missing isolated fluid interface test references")
    for c in refs:
        if any(x is not None and x.type=="MESH" and not x.hide_render for x in c.all_objects):
            raise RuntimeError("A pipe calibration guide would leak into production sprite")
    main_count=len(source)
    # Fresh scene, not a cached append: glTF importer must reproduce the model.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(a.glb).resolve()))
    imported=[x for x in bpy.context.scene.objects if x.type=="MESH"]
    if len(imported)<main_count:
        raise RuntimeError("GLB roundtrip lost model objects")
    if any(x.name.startswith("FMPL QA reference |") for x in imported):
        raise RuntimeError("A calibration object leaked into the exported GLB")
    result={
      "schema":"fmpl.production-smoke.verify.v1","passed":True,
      "saved_blend_sha256":sha(a.blend),"glb_sha256":sha(a.glb),
      "source_meshes_reopened":main_count,"glb_meshes_reimported":len(imported),
      "pbr_materials_in_source":sorted(mats),"packed_images":packed_count,
      "calibration_fixtures_hidden":2,
      "source_geometry_preserved":True,
      "native_factorio_port_verified":False,
      "game_integrated":False
    }
    Path(a.out).write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_GLTF_ROUNDTRIP_PASS "+json.dumps({
        "source":main_count,"reimported":len(imported),"materials":len(mats)}),flush=True)


if __name__=="__main__":
    main()
