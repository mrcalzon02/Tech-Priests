#!/usr/bin/env python3
"""FMPL Pipette procedural Blender library build + honest draft preview.

Creates new editable .blend, GLB and Cycles PNG, never overwrites source.
The catalog and junction geometry remain visual prototypes until independent
native re-open, material approval and actual game connection verification.
Run with Blender --background --python-exit-code 1 --python this_file -- ...
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import library_geometry as lib


def file_sha(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()


def mat_preview(group, *, conductor_index=None):
    palette={
        "metal_pipe":(.45,.46,.48,1.), "polymer_pipe":(.21,.42,.55,1.),
        "tubing":(.48,.73,.77,1.), "hose":(.18,.25,.31,1.),
        "conduit":(.62,.67,.69,1.), "wire":(.42,.32,.17,1.),
        "housing":(.28,.29,.33,1.), "tension":(.49,.50,.52,1.),
        "rebar":(.38,.32,.30,1.)
    }
    colors=[
        (.87,.20,.18,1.),(.90,.52,.11,1.),(.91,.83,.23,1.),
        (.18,.69,.29,1.),(.16,.46,.89,1.),(.68,.26,.82,1.),
        (.22,.72,.73,1.),(.88,.88,.84,1.)
    ]
    color=colors[conductor_index%8] if conductor_index is not None else palette[group]
    name="PIPETTE PREVIEW ONLY | "+group
    if conductor_index is not None:
        name+=" | core %02d"%conductor_index
    existing=bpy.data.materials.get(name)
    if existing:
        return existing
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=color
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        raise RuntimeError("Missing editable Principled BSDF")
    bsdf.inputs["Base Color"].default_value=color
    bsdf.inputs["Metallic"].default_value=.55 if group in {"metal_pipe","rebar","conduit","tension"} else .08
    bsdf.inputs["Roughness"].default_value=.38 if group not in {"wire","housing"} else .56
    mat["pipette_preview_unapproved"]=True
    return mat


def make_obj(collection, part, material, architecture):
    name="PIPETTE | "+architecture+" | "+part["name"]
    data=bpy.data.meshes.new(name+" | mesh")
    data.from_pydata(part["vertices"],[],part["faces"])
    data.update(calc_edges=True)
    obj=bpy.data.objects.new(name,data)
    collection.objects.link(obj)
    data.materials.append(material)
    for poly in data.polygons:
        poly.use_smooth=True
    obj["pipette_architecture_id"]=architecture
    obj["pipette_mesh_role"]=part["role"]
    obj["pipette_preview_only"]=True
    obj["pipette_source_recipe"]=part.get("profile_kind","solid-or-wire")
    obj["pipette_true_open_bore"]=part.get("true_open_bore",False)
    if "conductor_index" in part:
        obj["pipette_conductor_index"]=part["conductor_index"]
    if "public_port_centers_unchanged" in part:
        obj["pipette_port_centers_json"]=json.dumps(part["public_port_centers_unchanged"])
    return obj


def cylinder(collection, name, start, end, radius):
    start, end = Vector(start),Vector(end)
    d=end-start
    if d.length<.015:
        raise ValueError("Invalid short cylinder "+name)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=d.length,
                                        end_fill_type="NGON",location=(start+end)*.5)
    ob=bpy.context.object
    ob.name=name
    ob.rotation_euler=d.to_track_quat("Z","Y").to_euler()
    # Apply geometry transform before Boolean; Boolean should not read scale
    # transforms from production or prior collections.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for old in tuple(ob.users_collection):
        old.objects.unlink(ob)
    collection.objects.link(ob)
    return ob


def boolean(target, tool, operation):
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active=target
    mod=target.modifiers.new("Pipette exact "+operation,"BOOLEAN")
    mod.operation=operation
    mod.solver="EXACT"
    mod.object=tool
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if len(target.data.polygons)==0:
        raise RuntimeError("Boolean produced empty geometry "+operation)
    bpy.data.objects.remove(tool,do_unlink=True)
    return target


def build_fluid_branch(collection, model, approved_material):
    """Native CSG three-way pipe body: union OD, subtract all through-bores.

    Only smooth hollow families are supported for this first verified builder.
    The operation is deliberately not faked for corrugated metal/hose geometry.
    """
    kind=lib.RECIPES[model["architecture_id"]][0]
    if kind not in {"smooth_hollow","soft_cast_hollow"}:
        raise RuntimeError("No approved CSG branch for '"+kind+
                           "': use straight preview until shaped manifold kernel exists")
    ports=model["public_ports"]
    hubs=model["junctions"]
    if len(hubs)!=1 or len(ports)<3:
        raise RuntimeError("Manifold CSG accepts one hub with 3+ ports")
    h=Vector(hubs[0]["xyz_bu"])
    od=model["nominal_outer_diameter_bu"]
    wall=lib.RECIPES[model["architecture_id"]][1]
    if not .08<wall<.7:
        raise RuntimeError("CSG manifold requires positive genuine hollow wall")
    radius=od*.5
    inner=radius*(1-wall)
    root=None
    for i,p in enumerate(ports):
        q=Vector(p["xyz_bu"])
        obj=cylinder(collection,"pipe outer solid leg "+p["id"],h,q,radius)
        if root is None:
            root=obj
        else:
            root=boolean(root,obj,"UNION")
    # Cast branch enlargement encloses the intersection without closing bore.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,
                  radius=radius*(1.22 if kind=="soft_cast_hollow" else 1.08),location=h)
    boss=bpy.context.object
    boss.name="Pipe true-volume central junction boss"
    for old in tuple(boss.users_collection):
        old.objects.unlink(boss)
    collection.objects.link(boss)
    root=boolean(root,boss,"UNION")
    for p in ports:
        q=Vector(p["xyz_bu"])
        d=(q-h).normalized()
        # Bore cylinder starts just behind center and leaves the mouth face:
        # sequential subtraction creates ONE connected hollow interior.
        drill=cylinder(collection,"pipe actual open bore "+p["id"],
                       h-d*.038,q+d*.045,inner)
        root=boolean(root,drill,"DIFFERENCE")
    root.name="PIPETTE | "+model["architecture_id"]+" | hollow CSG "+
              model["topology"]+" manifold"
    root.data.materials.append(approved_material)
    for poly in root.data.polygons:
        poly.use_smooth=True
    root["pipette_architecture_id"]=model["architecture_id"]
    root["pipette_mesh_role"]="native-boolean-connected-hollow-manifold"
    root["pipette_true_open_bore"]=True
    root["pipette_native_boolean_bore_constructed"]=True
    root["pipette_port_centers_json"]=json.dumps(ports,sort_keys=True)
    root["pipette_visual_candidate_not_game_validated"]=True
    return [root]


def add_preview_camera_lights(scene, objects):
    points=[obj.matrix_world@Vector(v) for obj in objects for v in obj.bound_box]
    if not points:
        raise RuntimeError("No actual geometry for Pipette Cycles proof")
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    # Comparison rig camera and lights remain IDENTICAL for every material:
    # no implicit scaling based on how widely a particular hose happens to sag.
    fixture=lib.source_json("comparison_fixture.v1.json")
    center=Vector(fixture["workspace"]["center_xyz_bu"])
    span=max(fixture["workspace"]["nominal_display_footprint_bu"])
    world=bpy.data.worlds.new("Pipette proof-only ambient")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.40,.48,.58,1.)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.75
    scene.world=world
    data=bpy.data.cameras.new("Pipette proof 45 azimuth ortho")
    camera=bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(camera)
    camera.location=center+Vector((1.75,-1.75,1.85))*span
    camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO"
    data.ortho_scale=span*1.45
    scene.camera=camera
    for i,(x,y,z,energy) in enumerate(((1.,-1.3,2.2,450.),
                                       (-1.5,.5,1.4,300.))):
        lamp=bpy.data.lights.new("Pipette proof light %d"%i,"AREA")
        lamp.energy=energy*span*span
        lamp.shape="DISK"
        lamp.size=span*1.3
        ob=bpy.data.objects.new(lamp.name,lamp)
        scene.collection.objects.link(ob)
        ob.location=center+Vector((x,y,z))*span
        ob.rotation_euler=(center-ob.location).to_track_quat("-Z","Y").to_euler()


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--architecture",required=True,choices=sorted(lib.RECIPES))
    ap.add_argument("--topology",default="straight")
    ap.add_argument("--source-blend")
    ap.add_argument("--material-name")
    ap.add_argument("--preview-only",action="store_true")
    ap.add_argument("--out-blend",required=True)
    ap.add_argument("--out-glb",required=True)
    ap.add_argument("--out-png",required=True)
    ap.add_argument("--report",required=True)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    outputs=[Path(x).resolve() for x in (args.out_blend,args.out_glb,
                                          args.out_png,args.report)]
    if len(set(outputs))!=len(outputs) or any(x.exists() for x in outputs):
        raise FileExistsError("All Pipette outputs must be new unique paths")
    if args.preview_only and args.material_name:
        raise ValueError("Do not pretend preview material is production approved")
    if not args.preview_only and not(args.source_blend and args.material_name):
        raise ValueError("Production material requires approved source .blend and exact material ID")
    original_hash=None
    if args.source_blend:
        source=Path(args.source_blend).resolve()
        original_hash=file_sha(source)
        bpy.ops.wm.open_mainfile(filepath=str(source))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    model=lib.build_demo(args.architecture,args.topology)
    name="PIPETTE | architecture | "+args.architecture+" | "+args.topology
    if bpy.data.collections.get(name):
        raise RuntimeError("Source already has this Pipette collection; refusing overwrite")
    collection=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    if args.preview_only:
        surface=mat_preview(model["catalog_group"])
    else:
        surface=bpy.data.materials.get(args.material_name)
        if surface is None:
            raise RuntimeError("Approved FMPL material ID not present: "+args.material_name)
    if model["requires_native_csg_manifold"]:
        objects=build_fluid_branch(collection,model,surface)
    else:
        objects=[]
        for part in model["meshes"]:
            conductor=part.get("conductor_index")
            mat=mat_preview(model["catalog_group"],conductor_index=conductor) \
                    if args.preview_only else surface
            objects.append(make_obj(collection,part,mat,args.architecture))
    if len(model["public_ports"])>=2 and lib.RECIPES[args.architecture][0] \
            not in {"open_spiral","single_wire","eight_wire","eight_wire_tied",
                    "seven_strand"}:
        for p in model["public_ports"]:
            collar=lib.terminal_ring(p["xyz_bu"],p["outward_normal"],
                                     model["nominal_outer_diameter_bu"],
                                     args.architecture,role="socket-termination")
            objects.append(make_obj(collection,collar,surface,args.architecture))
    collection["pipette_public_ports_json"]=json.dumps(model["public_ports"])
    collection["pipette_fixed_fixture"]="comparison_fixture.v1.json"
    collection["pipette_preview_only"]=bool(args.preview_only)
    collection["pipette_native_game_connected"]=False
    bpy.context.view_layer.update()
    if not objects:
        raise RuntimeError("No Blender-native meshes were created")
    for path in outputs:
        path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(outputs[0]))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(outputs[1]),export_format="GLB",
                              use_selection=True,export_apply=True)
    add_preview_camera_lights(bpy.context.scene,objects)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=24
    scene.render.resolution_x=768
    scene.render.resolution_y=768
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(outputs[2])
    scene.render.film_transparent=True
    bpy.ops.render.render(write_still=True)
    if not outputs[2].is_file() or outputs[2].stat().st_size < 2048:
        raise RuntimeError("Cycles produced no meaningful output image")
    if args.source_blend and file_sha(Path(args.source_blend).resolve())!=original_hash:
        raise RuntimeError("Source file changed during Pipette build")
    receipt={k:v for k,v in model.items() if k!="meshes"}
    receipt.update({
        "native_blender_generated":True,
        "native_glb_generated":True,
        "real_cycles_render_generated":True,
        "independent_reopen_verified":False,
        "mesh_count":len(objects),
        "mesh_face_count":sum(len(o.data.polygons) for o in objects),
        "source_blend_sha256":original_hash,
        "source_preserved":True,
        "approved_materials":not args.preview_only,
        "game_native_ports_verified":False,
        "outputs":{p:{"filename":str(q),"sha256":file_sha(q)}
                   for p,q in zip(("blend","glb","preview_png"),outputs[:3])}
    })
    outputs[3].write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PIPETTE_NATIVE_LIBRARY_BUILD",args.architecture,args.topology,
          "meshes",len(objects),"faces",receipt["mesh_face_count"],
          "csg_manifold",model["requires_native_csg_manifold"])


if __name__=="__main__":
    main()
