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
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import library_geometry as lib
import library_fittings as fittings


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
    if "conductor_port_pair" in part:
        obj["pipette_conductor_port_pair_json"]=json.dumps(part["conductor_port_pair"])
    if "branch_continuity" in part:
        obj["pipette_full_conductor_branch_continuity"]=part["branch_continuity"]
    if "branch_hardware_type" in part:
        obj["pipette_branch_hardware_type"]=part["branch_hardware_type"]
    if "axial_length_bu" in part:
        obj["pipette_axial_length_bu"]=float(part["axial_length_bu"])
    if "bore_diameter_bu" in part:
        obj["pipette_bore_diameter_bu"]=float(part["bore_diameter_bu"])
    if "branch_port_id" in part:
        obj["pipette_branch_port_id"]=part["branch_port_id"]
    if "ferrule_terminal_port" in part:
        obj["pipette_branch_ferrule_port"]=part["ferrule_terminal_port"]
    if "joint_type" in part:
        obj["pipette_joint_type"]=part["joint_type"]
        obj["pipette_socket_id"]=part["public_socket_id"]
        obj["pipette_socket_xyz_json"]=json.dumps(part["public_socket_xyz_bu"])
        obj["pipette_socket_seating_verified"]=False
    return obj


def cylinder(collection, name, start, end, radius):
    start, end = Vector(start),Vector(end)
    d=end-start
    if d.length<.015:
        raise ValueError("Invalid short cylinder "+name)
    # Blender operators act on ALL selected objects. Boolean keeps the
    # destination selected, so failing to deselect here rotates the *existing*
    # manifold when a new drill cylinder is created. That produced a severely
    # disconnected Y despite the earlier weak proof reporting success.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=d.length,
                                        end_fill_type="NGON",location=(start+end)*.5)
    ob=bpy.context.object
    ob.name=name
    ob.rotation_euler=d.to_track_quat("Z","Y").to_euler()
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active=ob
    # Apply geometry transform ONLY to this fresh tool cylinder.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    ob.select_set(False)
    for old in tuple(ob.users_collection):
        old.objects.unlink(ob)
    collection.objects.link(ob)
    return ob


def _world_bounds(obj):
    bpy.context.view_layer.update()
    verts=[obj.matrix_world @ v.co for v in obj.data.vertices]
    if not verts:
        raise RuntimeError("Object has no vertices for CSG bounds")
    return {"min":[round(min(v[i] for v in verts),5) for i in range(3)],
            "max":[round(max(v[i] for v in verts),5) for i in range(3)],
            "faces":len(obj.data.polygons),
            "location":[round(float(v),5) for v in obj.location]}


def _nearest_surface_gap(ob, xyz):
    """Shortest distance to an ACTUAL triangle, not sparse mesh vertices."""
    bpy.context.view_layer.update()
    tree=BVHTree.FromObject(ob,bpy.context.evaluated_depsgraph_get())
    probe=Vector(xyz)
    local=ob.matrix_world.inverted_safe() @ probe
    hit,normal,face,distance=tree.find_nearest(local)
    if hit is None:
        raise RuntimeError("CSG mesh has no queryable surface triangles")
    return (ob.matrix_world @ hit-probe).length


def boolean(target, tool, operation):
    # Printed receipts are intended to diagnose CSG lost-arm failures.
    print("PIPETTE_CSG_BEFORE",operation,json.dumps({
        "target":_world_bounds(target),"tool":_world_bounds(tool)}))
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
    print("PIPETTE_CSG_AFTER",operation,json.dumps({
        "target":_world_bounds(target)}))
    bpy.data.objects.remove(tool,do_unlink=True)
    return target


def repair_connected_pipe_surface(obj, diameter):
    """Close Boolean seams before a Y is accepted as real manifold geometry.

    Exact Booleans can leave coincident or disconnected submeshes even when a
    Cycles preview looks joined. First weld coincident vertices; if the mesh
    still is not a single closed surface, use a bounded Blender-native voxel
    remesh at sufficiently fine pitch to retain a real central open bore.
    Never silently accept disconnected islands or degenerate wall faces.
    """
    import bmesh
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),
                             dist=diameter*.0004)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),
                                 dist=diameter*.0002)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    def audit():
        return lib.surface_topology(
            [tuple(int(i) for i in poly.vertices)
             for poly in obj.data.polygons])
    first=audit()
    def valid(report):
        return report["surface_islands"]==1 and \
            report["naked_boundary_edges"]==0 and \
            report["overlapping_nonmanifold_edges"]==0 and \
            report["degenerate_polygons"]==0
    if not valid(first):
        print("PIPETTE_CSG_SURFACE_REPAIR",json.dumps(first))
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        if not hasattr(obj.data,"remesh_voxel_size"):
            raise RuntimeError(
                "Cannot repair disconnected pipe geometry: Blender voxel remesh unavailable")
        obj.data.remesh_voxel_size=max(.0025,diameter/28)
        bpy.ops.object.voxel_remesh()
        obj.select_set(False)
        obj.data.update()
    final=audit()
    print("PIPETTE_CSG_FINAL_TOPOLOGY",json.dumps(final))
    if not valid(final):
        raise RuntimeError("Cannot certify a connected, watertight hollow Y: "+
                           json.dumps(final))
    obj["pipette_native_connected_surface_proven"]=True
    return final


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
    # FIRST make one solid central hub. Unioning three cylinders that touch
    # only at their center caps is numerically degenerate in Exact Boolean:
    # Blender previously DROPPED two complete legs. Each arm MUST overlap
    # an already-existing, watertight volume by a deliberate positive depth.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,
                  radius=radius*(1.45 if kind=="soft_cast_hollow" else 1.30),
                  location=h)
    root=bpy.context.object
    root.name="Pipe overlapping central solid hub"
    for old in tuple(root.users_collection):
        old.objects.unlink(root)
    collection.objects.link(root)
    for p in ports:
        q=Vector(p["xyz_bu"])
        d=(q-h).normalized()
        # Start INSIDE the central sphere, not at a coplanar cap.
        inward=h-d*radius*.72
        outer_arm=cylinder(collection,"Pipe true outer leg "+p["id"],
                           inward,q,radius)
        root=boolean(root,outer_arm,"UNION")
        # Validate *after each union* that all already placed full-length
        # arms remain present, not merely that a mesh is nonempty.
        probe=h.lerp(q,.78)
        gap=_nearest_surface_gap(root,probe)
        if gap>radius*1.8:
            raise RuntimeError("CSG union lost a newly added pipe leg "+
                               p["id"]+"; surface gap %.4f BU"%gap)
    for p in ports:
        q=Vector(p["xyz_bu"])
        d=(q-h).normalized()
        # Bore cylinder starts just behind center and leaves the mouth face:
        # sequential subtraction creates ONE connected hollow interior.
        drill=cylinder(collection,"pipe actual open bore "+p["id"],
                       h-d*radius*1.65,q+d*radius*.78,inner)
        root=boolean(root,drill,"DIFFERENCE")
    # Must be one physically continuous watertight surface. An object that
    # simply contains isolated tubes is NOT an acceptable hollow junction.
    repair_connected_pipe_surface(root,od)
    root.name=("PIPETTE | "+model["architecture_id"]+
               " | hollow CSG "+model["topology"]+" manifold")
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
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.55
    scene.world=world
    data=bpy.data.cameras.new("Pipette proof 45 azimuth ortho")
    camera=bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(camera)
    camera.location=center+Vector((1.75,-1.75,1.85))*span
    camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO"
    data.ortho_scale=span*1.08
    scene.camera=camera
    for i,(x,y,z,energy) in enumerate(((1.,-1.3,2.2,160.),
                                       (-1.5,.5,1.4,100.))):
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
    ap.add_argument("--no-asset-mark",action="store_true",
                    help="do not mark generated collection for Blender Asset Browser")
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
            if args.preview_only and part.get("role")=="individual-conductor-ferrule":
                mat=mat_preview("metal_pipe")
            elif args.preview_only and part.get("role")=="branch-strain-relief-wrap":
                mat=mat_preview("housing")
            elif args.preview_only:
                mat=mat_preview(model["catalog_group"],conductor_index=conductor)
            else:
                mat=surface
            objects.append(make_obj(collection,part,mat,args.architecture))
    # Real, explicitly compatible fitting geometry is selected from the
    # architecture catalog. Unknown fittings are not relabeled brass rings.
    catalog=lib.source_json("architecture_catalog.v1.json")
    meta=next(row for row in catalog["architecture_types"]
              if row["id"]==args.architecture)
    favorites={
        "wire_eight_loose_bundle":"terminal_block",
        "wire_eight_laced_loom":"terminal_block",
        "wire_single_insulated_solid":"ring_lug",
        "hose_rubber_coolant":"hose_barb_clamp",
        "conduit_fmc_interlocked":"flex_conduit_connector",
        "conduit_ent_corrugated":"snap_conduit",
        "conduit_split_corrugated_loom":"split_loom_clip",
        "conduit_emt_thinwall":"compression_conduit",
        "pipe_galvanized_threaded":"threaded"}
    choices=meta["compatible_joint_ids"]
    embedded_wire_breakout=(
        model.get("branch_junction_status")==
        "continuous-conductor-breakout-built")
    preferred=favorites.get(args.architecture)
    if preferred is not None and preferred not in choices:
        raise RuntimeError("Misconfigured favorite fitting for "+args.architecture)
    candidates=([preferred] if preferred else [])+[
        x for x in choices if x!=preferred and x in fittings.FITTING_RECIPES]
    # The five new physical carriers have profiles that cannot mate to
    # arbitrary round glands without an actual measured transition.
    # A flattened layflat hose needs a round-to-flat cuff; twin-bonded
    # hoses need TWO distinct outlet fittings; slotted U ducts need a
    # rectangular, not circular, snap. Refuse to fabricate false hardware.
    special_profiles_without_verified_terminals={
        "tube_retractile_coil","hose_layflat","hose_twin_bonded",
        "housing_ladder_tray","housing_slotted_duct"
    }
    chosen=(None if embedded_wire_breakout or
                 args.architecture in special_profiles_without_verified_terminals
            else next((x for x in candidates if x in fittings.FITTING_RECIPES),None))
    if args.architecture in special_profiles_without_verified_terminals:
        print("PIPETTE_FITTING_TRANSITION_PENDING",
              args.architecture,"source_ports_remain_fixed")
    installed_fittings=[]
    for p in model["public_ports"]:
        if embedded_wire_breakout:
            # The individual 8->4+4 wire ferrules and 3 lightweight relief
            # wraps are ALREADY present inside the typed branch mesh. A
            # terminal_block here produces giant unrelated terminal bricks.
            continue
        if chosen:
            parts=fittings.build(args.architecture,chosen,p,
                                 model["nominal_outer_diameter_bu"])
            for part in parts:
                fitting_material=mat_preview("metal_pipe") \
                  if args.preview_only and chosen not in {
                    "snap_conduit","split_loom_clip","terminal_block"} else surface
                objects.append(make_obj(collection,part,fitting_material,
                                        args.architecture))
            installed_fittings.append({"port":p["id"],"type":chosen,
                                       "mesh_count":len(parts)})
        else:
            # An untyped ring is not a usable termination. Keep the actual
            # section's open end and report the missing hardware instead of
            # confusing users with a manufactured-looking fake connector.
            print("PIPETTE_TYPED_FITTING_PENDING",args.architecture,
                  p["id"],"candidates",",".join(choices))
    model["physically_modelled_fitting_type"]=chosen
    model["installed_terminal_fittings"]=installed_fittings
    model["missing_terminal_hardware"]=(
        [] if (chosen or embedded_wire_breakout) else
        [p["id"] for p in model["public_ports"]])
    if embedded_wire_breakout:
        model["embedded_branch_connector"]=(
            model["branch_geometry"]["branch_hardware_type"])
        model["embedded_branch_terminations"]={
            "A":8,"B":4,"C":4,"style":"individual-mini-crimp-ferrules"}

    collection["pipette_public_ports_json"]=json.dumps(model["public_ports"])
    collection["pipette_branch_junction_status"]=model["branch_junction_status"]
    if embedded_wire_breakout:
        collection["pipette_branch_port_counts_json"]=json.dumps(
            model["branch_geometry"]["branch_port_conductor_counts"])
        collection["pipette_branch_route_count"]=8
        collection["pipette_branch_has_midspan_wrappers"]=(
            bool(model["branch_geometry"]["branch_strain_relief_wraps"]))
        collection["pipette_embedded_hardware_style"]=(
            "natural-loose-wire-split-with-port-ferrules"
            if model["branch_geometry"]["branch_strain_relief_wraps"]==0
            else "laced-wraps-and-mini-ferrules")
    collection["pipette_fixed_fixture"]="comparison_fixture.v1.json"
    collection["pipette_preview_only"]=bool(args.preview_only)
    collection["pipette_native_game_connected"]=False
    if not args.no_asset_mark:
        # Blender 5.2 supports native collection asset data-blocks (ID.asset_mark).
        # These remain EXPLICITLY LABELED PREVIEW assets, not certified hardware
        # or approved Factorio production models.
        collection.asset_mark()
        if collection.asset_data is None:
            raise RuntimeError("Failed to mark native Pipette collection as Blender asset")
        collection.asset_data.description=(
            "FMPL Pipette EDITABLE PROTOTYPE — %s / %s; %s material, no native "
            "game pressure/electrical/force certification"%
            (args.architecture,args.topology,
             "PREVIEW ONLY" if args.preview_only else "source-approved"))
        collection["pipette_blender_asset_browser"]=True
    else:
        collection["pipette_blender_asset_browser"]=False
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
                              use_selection=True)
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
        "blender_collection_asset_marked":not args.no_asset_mark,
        "blender_asset_category":"FMPL/Pipette/PROTOTYPES",
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
