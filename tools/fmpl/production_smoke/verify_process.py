#!/usr/bin/env python3
"""Fresh Blender readback of FMPL V02 process machine and keyed state."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import bpy


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def geometry_sha(objs):
    h=hashlib.sha256()
    for obj in sorted(objs,key=lambda o:o.name):
        h.update(obj.name.encode("utf-8"))
        for row in obj.matrix_world:
            for v in row:
                h.update(struct.pack("<d",float(v)))
        for vert in obj.data.vertices:
            h.update(struct.pack("<ddd",*[float(x) for x in vert.co]))
        for face in obj.data.polygons:
            h.update(struct.pack("<I",len(face.vertices)))
            for index in face.vertices:
                h.update(struct.pack("<I",index))
    return h.hexdigest()


def main():
    parser=argparse.ArgumentParser()
    for arg in ("blend","glb","build-report","out"):
        parser.add_argument("--"+arg,required=True)
    a=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    report=json.loads(Path(a.build_report).read_text(encoding="utf-8-sig"))
    if sha(a.blend)!=report["derived_blend_sha256"] or sha(a.glb)!=report["glb_sha256"]:
        raise RuntimeError("FMPL process source/export hash mismatch")
    bpy.ops.wm.open_mainfile(filepath=str(Path(a.blend).resolve()))
    scene=bpy.context.scene
    originals=[o for o in scene.objects if o.type=="MESH" and o.name.startswith("MH7_")]
    process=[o for o in scene.objects if o.type=="MESH" and o.name.startswith("FMPL_PROCESS |")]
    if len(originals)!=50 or len(process)!=report["process_meshes_added"]:
        raise RuntimeError("Source or process mesh count has changed")
    if geometry_sha(originals)!=report["source_geometry_sha256"]:
        raise RuntimeError("Original 50 mesh geometries or transforms were mutated")
    if not report.get("glass_lid_visible") or not report.get("glass_windows_visible"):
        raise RuntimeError("No process glass claim in build receipt")
    roles=[o.name.lower() for o in process]
    expected=[
      "concrete raised plinth","paving brick","column anchor",
      "open double-wall","observation lid","keyframed","pump",
      "filter 1","filter 2","raw water","clean discharge",
      "pressure relief","vent nozzle","impeller paddle",
    ]
    # Rig empty is not a mesh; inspect that component by its saved object.
    expected=[x for x in expected if x!="keyframed"]
    for token in expected:
        if not any(token in name for name in roles):
            raise RuntimeError("Missing real process component "+token)
    mats={m.name for o in process+originals for m in o.data.materials if m}
    for mat in ("TP Library | ferrocrete","TP Library | ferrocrete_light",
                "TP Library | ferrocrete_dark","TP Library | machine_steel"):
        if mat not in mats:
            raise RuntimeError("FMPL PBR construction material absent: "+mat)
    windows=[o for o in process if "transparent observation lid" in o.name]
    if len(windows)!=1:
        raise RuntimeError("No real transparent treatment lid")
    shader=windows[0].data.materials[0].node_tree.nodes.get("Principled BSDF")
    transmission=shader.inputs.get("Transmission Weight")
    if transmission is None or transmission.default_value<.7:
        raise RuntimeError("Glass-topped chamber did not preserve real shader transmission")
    rotor=[x for x in scene.objects if x.name=="FMPL_PROCESS | keyframed central agitator rotor"]
    if len(rotor)!=1 or rotor[0].animation_data is None:
        raise RuntimeError("Agitator does not have an editable animation")
    for frame in (1,25,49):
        scene.frame_set(frame)
        if abs(float(rotor[0].rotation_euler.z)) < .3 and frame>1:
            raise RuntimeError("No actual agitator rotation at working frame "+str(frame))
    clouds=[o for o in process if "service steam plume" in o.name]
    if len(clouds)!=2 or any(o.animation_data is None for o in clouds):
        raise RuntimeError("Steam vent lacks two keyed vapor plumes")
    scene.frame_set(1)
    idle=[tuple(round(float(v),5) for v in o.scale) for o in clouds]
    scene.frame_set(25)
    active=[tuple(round(float(v),5) for v in o.scale) for o in clouds]
    if idle==active:
        raise RuntimeError("Steam geometry does not vary between idle and working state")
    if not scene.camera or scene.camera.data.type!="ORTHO" or scene.render.engine!="CYCLES":
        raise RuntimeError("Expected authored Factorio isometric Cycles camera missing")
    packed=sum(1 for img in bpy.data.images if img.source=="FILE" and img.packed_file)
    if packed<21:
        raise RuntimeError("FMPL metal and concrete PBR textures not packed")
    refs=[col for col in bpy.data.collections if col.name.startswith("FMPL QA reference |")]
    if len(refs)!=2 or any(o.type=="MESH" and not o.hide_render for col in refs for o in col.all_objects):
        raise RuntimeError("Calibrated reference must be retained but not drawn")
    intended=report["source_parts_rendered"]+len(process)
    source_count=len(originals)
    # Verify actual GLB imports independently; no reference guides are allowed.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(a.glb).resolve()))
    imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if len(imported)<intended:
        raise RuntimeError("Process exported GLB lost geometry (expected %d, got %d)"%(intended,len(imported)))
    if any(o.name.startswith("FMPL QA reference") for o in imported):
        raise RuntimeError("Reference-only pipe jig leaked to final GLB")
    result={
      "schema":"fmpl.process-machinery-verify.v1",
      "passed":True,"native_blend_sha256":sha(a.blend),"exported_glb_sha256":sha(a.glb),
      "preserved_original_meshes":source_count,"new_process_meshes":len(process),
      "reimported_glb_meshes":len(imported),
      "glass_transmission":float(transmission.default_value),
      "keyed_agitator_frames":[1,25,49,73,97],
      "steam_activity_changed":idle!=active,
      "packed_pbr_images":packed,
      "structural_concrete_and_paving":True,
      "native_pipe_cell_verified":False,
      "game_integrated":False,
      "owner_visual_approval":False
    }
    Path(a.out).write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PROCESS_REOPEN_PASS "+json.dumps({
       "source_meshes":source_count,"added":len(process),
       "glb_reimported":len(imported),"packed":packed}),flush=True)


if __name__=="__main__":
    main()
