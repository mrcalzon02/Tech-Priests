#!/usr/bin/env python3
"""Pipette Blender geometry adapter v0.1 — editable visible geometry only.

Actual Blender execution/GLB reopen, engine behavior and visual approval are
separate validation gates. Never treats numeric Blender-unit dimensions as
real-world pipe/wire gauges or mechanical ratings.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("fmpl_pipette_core",HERE/"core.py")
core=importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


def _file_sha(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):
            h.update(b)
    return h.hexdigest()


def _owned(collection,name,verts,faces,material,role,route):
    mesh=bpy.data.meshes.new(name+" | mesh")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    if material is not None:
        mesh.materials.append(material)
    obj["pipette_route_id"]=route["id"]
    obj["pipette_family"]=route["family"]
    obj["pipette_payload"]=route["payload"]
    obj["pipette_geometry_role"]=role
    obj["pipette_blender_units_only"]=True
    obj["pipette_prototype_not_game_integrated"]=True
    for face in mesh.polygons:
        face.use_smooth=True
    return obj


def _unit(vec):
    a=Vector(vec)
    if a.length < 1e-8:
        raise ValueError("zero-length local tube tangent")
    return a.normalized()


def _orient(tangent):
    z=_unit(tangent)
    fallback=Vector((0,0,1)) if abs(z.z)<.85 else Vector((0,1,0))
    axis=z.cross(fallback).normalized()
    b=z.cross(axis).normalized()
    return axis,b


def _path_points(points,pitch):
    """Add ring samples without silently smoothing authored source anchors."""
    out=[Vector(points[0])]
    for start,end in zip(points,points[1:]):
        a,b=Vector(start),Vector(end)
        length=(b-a).length
        steps=max(1,math.ceil(length/pitch))
        if len(out)+steps>1500:
            raise ValueError("Pipette adapter exceeded bounded ring count")
        for k in range(1,steps+1):
            out.append(a.lerp(b,k/steps))
    return out


def _cross_sections(points,outer_radius,inner_radius,sides,profile,pitch):
    verts=[]
    rings=[]
    progress=0.0
    for i,loc in enumerate(points):
        if i:
            progress+=(loc-points[i-1]).length
        if i==0:
            tangent=points[1]-loc
        elif i==len(points)-1:
            tangent=loc-points[i-1]
        else:
            tangent=_unit(loc-points[i-1])+_unit(points[i+1]-loc)
            if tangent.length<1e-7:
                raise ValueError("180-degree reversal in centerline")
        u,v=_orient(tangent)
        mod=1.0
        if "corrugation_pitch" in profile:
            wave=math.sin(math.tau*progress/profile["corrugation_pitch"])
            mod+=profile.get("corrugation_depth_ratio",.075)*wave
        if "rib_pitch" in profile:
            wave=math.cos(math.tau*progress/profile["rib_pitch"])
            mod+=profile.get("rib_height_ratio",.06)*max(0.,wave)**6
        base=len(verts)
        for j in range(sides):
            theta=math.tau*j/sides
            disp=u*math.cos(theta)+v*math.sin(theta)
            verts.append(tuple(loc+disp*outer_radius*mod))
        if inner_radius is not None:
            for j in range(sides):
                theta=math.tau*j/sides
                disp=u*math.cos(theta)+v*math.sin(theta)
                # Inner bore remains invariant through exterior corrugation.
                verts.append(tuple(loc+disp*inner_radius))
        rings.append(base)
    return verts,rings


def _make_tube(collection,name,points,diameter,wall_fraction,material,route,
               profile=None,sides=16,role="sheath"):
    if diameter<=0:
        raise ValueError("diameter in Blender units must be positive")
    profile=profile or {}
    outer=diameter/2
    inner=outer*(1-wall_fraction) if wall_fraction>0 else None
    min_pitch=min([diameter*.52]+
                  [float(profile[x])/5 for x in ("corrugation_pitch","rib_pitch")
                   if x in profile])
    samples=_path_points(points,max(min_pitch,0.002))
    ringlen=sides*(2 if inner is not None else 1)
    verts,rings=_cross_sections(samples,outer,inner,sides,profile,min_pitch)
    faces=[]
    for ring in range(len(rings)-1):
        a,b=rings[ring],rings[ring+1]
        for i in range(sides):
            j=(i+1)%sides
            faces.append((a+i,a+j,b+j,b+i))
            if inner is not None:
                faces.append((a+sides+i,b+sides+i,b+sides+j,a+sides+j))
    start,last=rings[0],rings[-1]
    if inner is None:
        faces.extend((tuple(reversed(tuple(start+j for j in range(sides)))),
                      tuple(last+j for j in range(sides))))
    else:
        for i in range(sides):
            j=(i+1)%sides
            # Two annular end caps seal the pipe wall, never the bore.
            faces.append((start+i,start+sides+i,start+sides+j,start+j))
            faces.append((last+i,last+j,last+sides+j,last+sides+i))
    ob=_owned(collection,name,verts,faces,material,role,route)
    ob["pipette_outer_diameter_bu"]=float(diameter)
    ob["pipette_bore_diameter_bu"]=float(diameter*(1-wall_fraction)) if wall_fraction else 0.
    ob["pipette_ring_count"]=len(samples)
    ob["pipette_true_hollow_mesh"]=bool(inner is not None)
    return ob


def _ring(collection,name,center,direction,radius,wire,material,route,role):
    """Actual toroidal connector ring oriented perpendicular to route."""
    vertices=24
    small=8
    u,v=_orient(direction)
    n=_unit(direction)
    center=Vector(center)
    verts=[]
    faces=[]
    for i in range(vertices):
        a=math.tau*i/vertices
        radial=u*math.cos(a)+v*math.sin(a)
        for j in range(small):
            b=math.tau*j/small
            point=center+radial*(radius+wire*math.cos(b))+n*(wire*math.sin(b))
            verts.append(tuple(point))
    for i in range(vertices):
        nxt=(i+1)%vertices
        for j in range(small):
            k=(j+1)%small
            faces.append((i*small+j,nxt*small+j,nxt*small+k,i*small+k))
    return _owned(collection,name,verts,faces,material,role,route)


def _connector(collection,root,terminal,kind,socket,direction,diameter,
               wall_fraction,material,route):
    if kind=="none":
        return []
    point=Vector(socket["xyz"])
    tangent=_unit(direction)
    if terminal=="start":
        tangent=-tangent
    outer=diameter/2
    collar_lengths={
        "flange":.80,"compression":.66,"hose_tail":1.20,
        "cable_gland":.85,"lug":.80,
        "eye":1.2,"clevis":1.2,"rebar_coupler":1.25,"lap":1.0
    }
    depth=diameter*collar_lengths.get(kind,.80)
    a=point-tangent*(depth*.5)
    b=point+tangent*(depth*.5)
    members=[]
    # These are rendered, real fitting parts. A ring alone is not a union:
    # every applicable fitting also gets a physical sleeve/barrel.
    if kind in {"flange","compression","hose_tail","cable_gland",
                "rebar_coupler","lap"}:
        hollow=wall_fraction if kind not in {"rebar_coupler","lap"} else 0.
        members.append(_make_tube(
            collection,root+" | "+terminal+" "+kind+" sleeve",
            [a,b],diameter*1.3,hollow,material,route,
            sides=16,role="terminal-sleeve"))
        members.append(_ring(
            collection,root+" | "+terminal+" "+kind+" retaining band",
            point,tangent,outer*1.34,max(.005,diameter*.075),
            material,route,"terminal-band"))
        if kind in {"flange","hose_tail","cable_gland"}:
            members.append(_ring(
                collection,root+" | "+terminal+" "+kind+" outer stop",
                point+tangent*(depth*.38),tangent,outer*1.3,
                max(.004,diameter*.065),material,route,"terminal-stop"))
    else:
        members.append(_ring(
            collection,root+" | "+terminal+" "+kind+" eye",
            point+tangent*(depth*.1),tangent,outer*1.55,
            max(.006,diameter*.16),material,route,"terminal-eye"))
    for obj in members:
        obj["pipette_socket_id"]=socket["id"]
        obj["pipette_fitting_kind"]=kind
        obj["pipette_joint_candidate_only"]=True
    return members


def _tapered_reducer(collection,name,begin,end,outer_start,inner_start,
                     outer_end,inner_end,material,route):
    """Real variable-radius hollow section joining canonical port to line."""
    a,b=Vector(begin),Vector(end)
    axis=b-a
    if axis.length<.04:
        raise RuntimeError("Pipette standard reducer is too short")
    u,v=_orient(axis)
    sides=32
    verts=[]
    faces=[]
    for pos,outer,inner in ((a,outer_start,inner_start),
                            (b,outer_end,inner_end)):
        if not 0<inner<outer:
            raise RuntimeError("Invalid reducer bore wall")
        for radius in (outer,inner):
            for k in range(sides):
                theta=math.tau*k/sides
                verts.append(tuple(pos+(u*math.cos(theta)+v*math.sin(theta))*radius))
    for k in range(sides):
        j=(k+1)%sides
        faces.extend((
            (k,j,2*sides+j,2*sides+k),
            (sides+k,3*sides+k,3*sides+j,sides+j),
            (k,sides+k,sides+j,j),
            (2*sides+k,2*sides+j,3*sides+j,3*sides+k)
        ))
    obj=_owned(collection,name,verts,faces,material,"standard-port-hollow-reducer",route)
    obj["pipette_true_hollow_mesh"]=True
    obj["pipette_outer_diameter_bu"]=outer_start*2
    obj["pipette_bore_diameter_bu"]=inner_start*2
    return obj


def _canonical_port_fixture(collection,root,terminal,plan,body_start,
                             body_end,material):
    """Proportion-matched fitted pipe/annulus from explicit tile-scoped port.

    A dimension-matching candidate, not an approved imported source fixture
    and not native Factorio fluidbox mapping.
    """
    interface=plan["tile_interfaces"].get(terminal)
    if interface is None:
        return []
    scope=plan["scene_scope"]
    dims=interface["dimensions"]
    p=Vector(plan["sockets"][terminal]["xyz"])
    b=Vector(body_start if terminal=="start" else body_end)
    inward=b-p
    if inward.length<.20*scope["scene_units_per_tile"]:
        raise RuntimeError("No clearance for canonical pipe barrel and reducer")
    inward.normalize()
    bu=scope["scene_units_per_tile"]
    barrel_od=dims["barrel_outer_diameter_bu"]
    bore=dims["open_bore_diameter_bu"]
    collar_od=dims["mounting_collar_outer_diameter_bu"]
    collar_len=dims["mounting_collar_axial_thickness_bu"]
    if not 0<bore<barrel_od<collar_od:
        raise RuntimeError("FMPL canonical pipe diameters are inconsistent")
    tubing_diameter=plan["size"]["outer_diameter"]
    tubing_bore=plan["size"]["bore_diameter"]
    if tubing_bore is None or tubing_bore>=bore:
        raise RuntimeError("Inner fluid tube bore must be smaller than standard port")
    prefix=root+" | "+terminal+" factorio-fluid-interface-v1 "
    members=[]
    members.append(_make_tube(
        collection,prefix+"hollow machine throat",
        [p,p+inward*.155*bu],
        barrel_od,1-bore/barrel_od,material,plan,
        role="standard-open-throat"))
    members.append(_make_tube(
        collection,prefix+"full machine collar",
        [p-inward*collar_len*.5,p+inward*collar_len*.5],
        collar_od,1-bore/collar_od,material,plan,
        role="standard-collar"))
    members.append(_tapered_reducer(
        collection,prefix+"hollow internal reducer",
        p+inward*.155*bu,b,
        barrel_od/2,bore/2,tubing_diameter/2,tubing_bore/2,
        material,plan))
    for obj in members:
        obj["pipette_standard_interface_id"]="factorio-fluid-interface-v1"
        obj["pipette_native_fluidbox_verified"]=False
        obj["pipette_standard_fixture_source"]="dimension-matching candidate; not cloned FMPL donor"
        obj["pipette_socket_id"]=plan["sockets"][terminal]["id"]
        obj["pipette_expected_port_xyz_bu"]=list(interface["expected_xyz_bu"])
    return members


def _inner_body_path(plan):
    """Protect the actual face bore from a smaller inner service tube."""
    points=[Vector(p) for p in plan["centerline"]]
    canonical=plan.get("tile_interfaces",{})
    if not canonical:
        return [tuple(p) for p in points]
    u=plan["scene_scope"]["scene_units_per_tile"]
    for terminal in ("start","end"):
        if terminal not in canonical:
            continue
        i,j=(0,1) if terminal=="start" else (-1,-2)
        direction=points[j]-points[i]
        if direction.length<.35*u:
            raise RuntimeError("First/last route leg too short for standard fitting")
        points[i]=points[i]+direction.normalized()*.235*u
    if any((b-a).length<1e-5 for a,b in zip(points,points[1:])):
        raise RuntimeError("Port reducer leaves degenerate internal pipe")
    return [tuple(p) for p in points]


def _cores(collection,root,plan,material,points):
    if not plan["expose_cores"]:
        return []
    count=plan["size"]["conductor_count"]
    outer=plan["size"]["outer_radius"]
    strand=plan["size"]["strand_diameter"]
    if count*strand*strand>outer*outer*2.75:
        raise RuntimeError("requested visible wires cannot fit within relative sheath diameter")
    axis=_unit(Vector(points[-1])-Vector(points[0]))
    u,v=_orient(axis)
    result=[]
    for k in range(count):
        angle=math.tau*k/max(2,count)
        offset=(u*math.cos(angle)+v*math.sin(angle))*(outer*.35 if count>1 else 0)
        wire=[tuple(Vector(point)+offset) for point in points]
        result.append(_make_tube(
            collection,root+" | exposed conductor %02d"%k,wire,
            strand,0.,material,plan,sides=12,role="visible-conductor"))
    return result


def build(plan,material,fit_material=None):
    if plan.get("schema")!=core.PLAN_SCHEMA:
        raise ValueError("Unknown Pipette route plan schema")
    name=plan["id"]
    slug=re.sub(r"[^A-Za-z0-9_-]+","-",name)[:80]
    target_name="FMPL | PIPETTE | "+slug
    if bpy.data.collections.get(target_name):
        raise RuntimeError("Refusing to overwrite a prior Pipette route collection")
    col=bpy.data.collections.new(target_name)
    bpy.context.scene.collection.children.link(col)
    objects=[]
    body_points=_inner_body_path(plan)
    family=plan["family"]
    sections=(core._split(body_points,
              max(.001,float(plan["segments"][0]["length"])))
              if family=="segmented_conduit" and plan.get("tile_interfaces")
              else plan["segments"])
    width=plan["size"]["outer_diameter"]
    wall=plan["size"]["wall_fraction"]
    profile=plan.get("surface_profile") or {}
    if family=="rebar":
        profile=dict(profile)
        profile.setdefault("rib_pitch",width*.72)
        profile.setdefault("rib_height_ratio",.065)
    if family=="flex_hose" and profile.get("corrugation_pitch",0):
        profile=dict(profile)
        profile.setdefault("corrugation_depth_ratio",.08)
    if family=="segmented_conduit":
        for i,sec in enumerate(sections):
            objects.append(_make_tube(
                col,target_name+" | segmented tube %03d"%i,
                [sec["a"],sec["b"]],width,wall,material,plan,role="segmented-shell"))
        for i,p in enumerate(plan["joint_locations"]):
            v=Vector(sections[i]["b"])-Vector(sections[i]["a"])
            objects.append(_make_tube(
                col,target_name+" | articulated joint sleeve %03d"%i,
                [Vector(p)-_unit(v)*width*.23,
                 Vector(p)+_unit(v)*width*.23],
                width*1.1,wall,fit_material or material,plan,role="joint-sleeve"))
    else:
        objects.append(_make_tube(
            col,target_name+" | continuous visible route",
            body_points,width,wall,material,plan,
            profile=profile,role="continuous-route"))
    a,b=plan["sockets"]["start"],plan["sockets"]["end"]
    p0,pn=plan["centerline"][0],plan["centerline"][-1]
    for terminal,socket,direction in (
        ("start",a,_unit(_vec(p0,plan["centerline"][1]))),
        ("end",b,_unit(_vec(plan["centerline"][-2],pn)))):
        if terminal in plan.get("tile_interfaces",{}):
            objects+=_canonical_port_fixture(
                col,target_name,terminal,plan,
                body_points[0],body_points[-1],fit_material or material)
        else:
            objects+=_connector(
                col,target_name,terminal,plan["fittings"][terminal],
                socket,direction,width,wall,fit_material or material,plan)
    objects+=_cores(col,target_name,plan,material,body_points)
    return col,objects


def _vec(a,b):
    return tuple(b[i]-a[i] for i in range(3))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--request",required=True)
    parser.add_argument("--source-blend")
    parser.add_argument("--out-blend",required=True)
    parser.add_argument("--out-glb",required=True)
    parser.add_argument("--report",required=True)
    parser.add_argument("--preview-only",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    outputs=[Path(p).resolve() for p in
             (args.out_blend,args.out_glb,args.report)]
    if any(p.exists() for p in outputs):
        raise FileExistsError("Pipette outputs must be new; never overwrite a scene")
    original_hash=None
    if args.source_blend:
        source=Path(args.source_blend).resolve()
        original_hash=_file_sha(source)
        bpy.ops.wm.open_mainfile(filepath=str(source))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    request=json.loads(Path(args.request).read_text(encoding="utf-8"))
    planned=core.plan(request)
    mat=bpy.data.materials.get(planned["material_id"])
    if mat is None:
        if not args.preview_only:
            raise RuntimeError("Exact approved material not found in source .blend: "+
                               planned["material_id"])
        mat=bpy.data.materials.new("PIPETTE PREVIEW ONLY | "+planned["material_id"])
        mat.diffuse_color=(.48,.5,.53,1.)
        mat.use_nodes=True
        bsdf=mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            raise RuntimeError("Blender preview material has no editable Principled BSDF")
        bsdf.inputs["Base Color"].default_value=(.48,.56,.64,1.)
        bsdf.inputs["Roughness"].default_value=.55
        bsdf.inputs["Metallic"].default_value=.15
        mat["pipette_unapproved_preview_material"]=True
    fitting_mat_name=request.get("fitting_material_id",planned["material_id"])
    fit_mat=bpy.data.materials.get(fitting_mat_name)
    if fit_mat is None and not args.preview_only:
        raise RuntimeError("Exact approved fitting material not found: "+fitting_mat_name)
    col,objects=build(planned,mat,fit_mat or mat)
    for dest in outputs:
        dest.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(outputs[0]),compress=True,
                               check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(outputs[1]),export_format="GLB",
        use_selection=True,export_apply=True)
    receipt={
        "schema":"fmpl.pipette.blender.build.v0.1",
        "route_id":planned["id"],"family":planned["family"],
        "payload":planned["payload"],
        "source_blend_sha256":original_hash,
        "native_blend_sha256":_file_sha(outputs[0]),
        "exported_glb_sha256":_file_sha(outputs[1]),
        "geometric_meshes_constructed":len(objects),
        "connector_specs":planned["fittings"],
        "outer_diameter_blender_units":planned["size"]["outer_diameter"],
        "scene_scope":planned.get("scene_scope"),
        "standard_tile_interfaces":planned.get("tile_interfaces",{}),
        "material_id":mat.name,
        "preview_material_only":bool(args.preview_only),
        "source_camera_preserved":bool(args.source_blend),
        "independent_blend_reopen_verified":False,
        "independent_glb_reimport_verified":False,
        "visually_approved":False,"game_integrated":False
    }
    outputs[2].write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PIPETTE_EDITABLE_CANDIDATE "+json.dumps({
        "route_id":planned["id"],"meshes":len(objects),
        "preview_only":bool(args.preview_only)
    }),flush=True)


if __name__=="__main__":
    main()
