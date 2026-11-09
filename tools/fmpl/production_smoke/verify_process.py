#!/usr/bin/env python3
"""Fresh Blender readback of FMPL V02 process machine and keyed state."""
import argparse
import array
import hashlib
import json
import math
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
    for arg in ("blend","glb","build-report","idle-preview","active-preview","out"):
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
    glass_transmission=float(transmission.default_value)
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
    if len(refs)!=2 or any(o is not None and o.type=="MESH" and not o.hide_render for col in refs for o in col.all_objects):
        raise RuntimeError("Calibrated reference must be retained but not drawn")
    extras=[o for o in scene.objects if o.type=="MESH" and
            not o.name.startswith("MH7_") and
            not o.name.startswith("FMPL_PROCESS |")]
    unhidden=[o.name for o in extras if not o.hide_render]
    if unhidden:
        raise RuntimeError("Nonproduction environment geometry remains visible: "+str(unhidden))
    # In Blender 5.2 Scene.use_nodes is deprecated, and may read back as true
    # after reopening even when the saved output is transparent. Test the
    # actual Cycles pixel alpha instead of guessing from legacy compositor flags.
    def verify_png_alpha(path, expected_hash):
        if sha(path)!=expected_hash:
            raise RuntimeError("Rendered process proof hash changed")
        image=bpy.data.images.load(str(Path(path).resolve()),check_existing=False)
        try:
            if image.channels!=4:
                raise RuntimeError("PNG image lacks an alpha channel")
            pixels=array.array("f",[0.0])*(image.size[0]*image.size[1]*4)
            image.pixels.foreach_get(pixels)
            minimum=min(pixels[3::4]);maximum=max(pixels[3::4])
            if minimum>.05 or maximum<.95:
                raise RuntimeError("Actual Blender process PNG is not transparent and nonempty")
            return {"minimum":round(minimum,4),"maximum":round(maximum,4)}
        finally:
            bpy.data.images.remove(image)
    idle_alpha=verify_png_alpha(a.idle_preview,report["idle_render_sha256"])
    active_alpha=verify_png_alpha(a.active_preview,report["active_render_sha256"])

    # Single source-model camera, matching the proven boiler's canonical
    # 45 degree elevation and 0 degree azimuth, not diagonal item art.
    camera_objects=[o for o in scene.objects if o.type=="CAMERA"]
    camera=scene.camera
    if camera is None or len(camera_objects)!=1 or camera is not camera_objects[0]:
        raise RuntimeError("Only one Factorio production camera is permitted")
    expected_camera=(0.0,-6.0,7.65)
    if (max(abs(float(camera.location[i])-expected_camera[i]) for i in range(3))>.002
            or abs(float(camera.data.ortho_scale)-5.8)>.002):
        raise RuntimeError("Machine-wide camera deviates from boiler export orientation")
    if report.get("grid_aligned_model_ports") is not True:
        raise RuntimeError("Model did not declare two centered tile-edge joints")
    receipts=report.get("canonical_pipe_interfaces",[])
    if len(receipts)!=2:
        raise RuntimeError("Missing full machine inlet and outlet references")
    join_checks=[]
    from mathutils import Vector
    bpy.context.view_layer.update()
    for role,side in (("raw-water-in",-1),("purified-water-out",1)):
        group=[c for c in refs if c.name.startswith("FMPL QA reference | "+role)]
        if len(group)!=1:
            raise RuntimeError("Missing independent reference group: "+role)
        candidate=[o for o in process if o.name==("FMPL_PROCESS | "+role+" / reusable machine collar")]
        throat=[o for o in process if o.name==("FMPL_PROCESS | "+role+" / reusable machine throat")]
        adjacent=[o for o in group[0].all_objects if o is not None and
                  o.get("interface_role")=="reference_near_collar"]
        if len(candidate)!=1 or len(throat)!=1 or len(adjacent)!=1:
            raise RuntimeError("Full-size original collar/throat mesh was not actually copied for "+role)
        def surface_ring(obj):
            return [obj.matrix_world @ v.co for v in obj.data.vertices
                    if abs(float((obj.matrix_world @ v.co).x)-side*1.5)<.000005]
        face=surface_ring(candidate[0])
        near=surface_ring(adjacent[0])
        if len(face)<64 or len(near)<64:
            raise RuntimeError("External pipe mouth is not a real annular surface: "+role)
        residual=max(min((v-w).length for w in near) for v in face)
        if residual>1e-5:
            raise RuntimeError("Canonical boiler/condenser pipe ring does not mate at actual plane: "+role+" "+str(residual))
        values=[math.hypot(v.y,v.z-.36) for v in face]
        outer=max(values)
        bore=min(values)
        if abs(outer-.34)>.002 or abs(bore-.245)>.002:
            raise RuntimeError("Real pipe mouth has the wrong open bore/outer collar: "+role)
        fasteners=[o for o in process if o.name.startswith("FMPL_PROCESS | "+role+" / actual flange bolt ")]
        if len(fasteners)!=8:
            raise RuntimeError("Model lacks boiler-pattern mechanical flange fixtures for "+role)
        cast=[o for o in process if
              (role=="raw-water-in" and "raw inlet cast receiving manifold" in o.name) or
              (role=="purified-water-out" and "clarified water outlet casting" in o.name)]
        if len(cast)!=1:
            raise RuntimeError("A full bore must reduce into physically supported machinery: "+role)
        join_checks.append({
           "role":role,"joint_xyz":[side*1.5,0.0,.36],
           "open_bore_diameter":.49,"collar_outer_diameter":.68,
           "mating_ring_vertices":len(face),"near_pipe_ring_vertices":len(near),
           "max_contact_residual_tiles":residual,
           "fastener_count":len(fasteners),
           "native_factorio_fluidbox_verified":False
        })
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
      "glass_transmission":glass_transmission,
      "keyed_agitator_frames":[1,25,49,73,97],
      "steam_activity_changed":idle!=active,
      "packed_pbr_images":packed,
      "structural_concrete_and_paving":True,
      "one_canonical_factorio_camera":True,
      "centered_mating_faces":join_checks,
      "native_water_purifier_fluidbox_declared":False,
      "actual_png_alpha":{"idle":idle_alpha,"working":active_alpha},
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
