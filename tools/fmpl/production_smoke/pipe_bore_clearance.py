#!/usr/bin/env python3
"""FMPL Water Purifier side-port bore clearance, Blender-native geometry only.

Non-destructive: the source 50 MH7 and 136 FMPL process meshes remain present
and hash-identical. Offending structures are render-hidden and replaced by
supported geometry with open 0.49-tile pipe passages at X +/-1.5, Y0 Z0.36.
No change to canonical collars, throats, machine camera or native fluidbox.
"""
from __future__ import annotations
import math
import bpy
from mathutils import Vector

RADIUS = .245
CLEAR_RADIUS = .266
MOUTH_CENTER_Z = .36
SIDES=(-1,1)
ROLE_BY_SIDE={-1:"raw-water-in",1:"purified-water-out"}


def _hide_named(objs,name):
    chosen=[o for o in objs if o.name==name and o.type=="MESH"]
    if len(chosen)!=1:
        raise RuntimeError("Cannot safely replace unique existing port obstruction: "+name)
    ob=chosen[0]
    if ob.hide_render:
        raise RuntimeError("Unexpected previously hidden port obstruction: "+name)
    ob.hide_render=True
    ob["fmpl_derived_bore_clearance"]="immutable original render-hidden in port clearance V11"
    return ob


def _clone_carved_source(scene,collection,p,source,label,cutters):
    if not source.hide_render:
        raise RuntimeError("Source must be retained and hidden before derivative carving")
    clone=source.copy()
    clone.data=source.data.copy()
    clone.name=p.name_of(label)
    clone.data.name=clone.name+" / cut relief"
    clone.hide_render=False
    clone.hide_viewport=False
    collection.objects.link(clone)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    clone.select_set(True)
    bpy.context.view_layer.objects.active=clone
    for cutter in cutters:
        mod=clone.modifiers.new("Bore .49 tile + engineering clearance","BOOLEAN")
        mod.operation="DIFFERENCE"
        mod.solver="EXACT"
        mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
    clone["fmpl_bore_clearance"]="real mesh boolean cut, not painted or hidden hole"
    clone["fmpl_bore_clearance_diameter_tiles"]=2*CLEAR_RADIUS
    if not clone.data.polygons:
        raise RuntimeError("Bore carve removed entire intended foundation: "+clone.name)
    return clone


def build_port_clearance(scene, col, p, original, process, mats):
    if bpy.data.collections.get("FMPL | SUPER GREEBLE V01") is not col:
        raise RuntimeError("Port clearances must be authored in the removable derivative collection")
    hidden=[]
    retained_bore=[]
    for side in SIDES:
        role=ROLE_BY_SIDE[side]
        collars=[ob for ob in process
                 if ob.name==p.name_of(role+" / reusable machine collar")]
        throats=[ob for ob in process
                 if ob.name==p.name_of(role+" / reusable machine throat")]
        if len(collars)!=1 or len(throats)!=1 or \
           any(ob.hide_render for ob in collars+throats):
            raise RuntimeError("Protected original full-bore port fitting missing: "+role)
        if any(float(ob.get("nominal_open_bore_diameter_tiles",0))!=.49
               for ob in collars+throats):
            raise RuntimeError("Protected pipe geometry is not authentic .49-tile bore")
        retained_bore.extend([ob.name for ob in collars+throats])
        for label in ("cast footing","braced manifold shoe"):
            ob=_hide_named(process,p.name_of(role+" / "+label))
            hidden.append(ob.name)
        for y in (-.42,.42):
            s="negative" if y<0 else "positive"
            p.block(col,"%s / redirected outboard footing %s"%(role,s),
                    (side*1.19,y,.29),(.24,.19,.17),mats["concrete"],.014)
            p.block(col,"%s / exterior saddle support %s"%(role,s),
                    (side*1.23,y,.43),(.11,.15,.18),mats["iron"],.013)
    rail_names=("MH7_chassis length rail","MH7_chassis length rail.001")
    for side,rail_name in zip(SIDES,rail_names):
        hidden.append(_hide_named(original,rail_name).name)
        for y in (-.84,.84):
            s="rear" if y>0 else "front"
            p.block(col,"split chassis rail / %s / %s"%(ROLE_BY_SIDE[side],s),
                    (side*1.30,y,.38),(.14,.92,.32),mats["red"],.014)
    original_bed=_hide_named(original,"MH7_base bed")
    plinth=_hide_named(process,p.name_of("cast industrial concrete raised plinth"))
    hidden.extend([original_bed.name,plinth.name])
    cutters=[]
    try:
        for side in SIDES:
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=96,radius=CLEAR_RADIUS,depth=.70,
                location=(side*1.34,0,MOUTH_CENTER_Z),
                rotation=(0,math.pi/2,0))
            cutter=bpy.context.object
            cutter.name="FMPL BOOLEAN ONLY | %s 0.532-tile clear passage"%ROLE_BY_SIDE[side]
            cutters.append(cutter)
        _clone_carved_source(scene,col,p,original_bed,
                             "bore-cleared original concrete foundation",cutters)
        _clone_carved_source(scene,col,p,plinth,
                             "bore-cleared raised concrete plinth",cutters)
    finally:
        for cutter in cutters:
            if cutter.name in bpy.data.objects:
                bpy.data.objects.remove(cutter,do_unlink=True)
    report=verify_bores(scene, original, process, list(col.objects))
    if not report["passed"]:
        raise RuntimeError("Ports still obstructed after structural refit: "+str(report["hits"][:8]))
    return {
        "replaced_originals_hidden":len(hidden),
        "hidden_original_object_names":hidden,
        "repaired_foundation_layers":2,
        "split_rail_segments":4,
        "redirected_supports":8,
        "original_canonical_port_meshes_preserved":retained_bore,
        "nominal_bore_diameter_tiles":2*RADIUS,
        "engineering_clearance_diameter_tiles":2*CLEAR_RADIUS,
        "functional_port_status":"model-space bore cleared; Factorio fluidbox not yet verified",
        "probe":report,
    }


def _raycast(obj,origin,direction,distance):
    inv=obj.matrix_world.inverted_safe()
    local_origin=inv @ origin
    local_direction=(inv.to_3x3() @ direction).normalized()
    hit,point,normal,face=obj.ray_cast(local_origin,local_direction,distance=distance)
    return bool(hit)


def verify_bores(scene, original=None, process=None, derivative=None):
    """Probe all actual *rendered* meshes with inward rays across both pipe bores.

    Every ray starts outside the flange, runs to x +/-1.21 and checks a
    0.205-tile-radius inner core (leaves clearance from the designed .245 bore
    wall). Empty cavities therefore cannot be blocked by rail, foot or floor.
    """
    bpy.context.view_layer.update()
    objs=[o for o in scene.objects if o.type=="MESH" and not o.hide_render]
    offsets=[]
    for y in (-.18,-.12,-.06,0.,.06,.12,.18):
        for z in (-.18,-.12,-.06,0.,.06,.12,.18):
            if y*y+z*z <= .205**2:
                offsets.append((y,z))
    if (0.,0.) not in offsets:
        raise RuntimeError("Bore verifier omitted pipe centerline")
    hits=[]
    sample_count=0
    for side in SIDES:
        origin_x=side*1.515
        direction=Vector((-side,0,0))
        for y,z in offsets:
            ray_origin=Vector((origin_x,y,MOUTH_CENTER_Z+z))
            sample_count+=1
            for ob in objs:
                # World bbox quick rejection to limit actual bpy raycasts.
                bbox=[ob.matrix_world @ Vector(v) for v in ob.bound_box]
                xmin=min(v.x for v in bbox);xmax=max(v.x for v in bbox)
                if (xmax<-1.53 or xmin>-1.20) if side==-1 else (xmin>1.53 or xmax<1.20):
                    continue
                ymin=min(v.y for v in bbox);ymax=max(v.y for v in bbox)
                zmin=min(v.z for v in bbox);zmax=max(v.z for v in bbox)
                if not(ymin-.002<=y<=ymax+.002 and zmin-.002<=MOUTH_CENTER_Z+z<=zmax+.002):
                    continue
                if _raycast(ob,ray_origin,direction,.305):
                    hits.append({
                        "side":ROLE_BY_SIDE[side],
                        "mesh":ob.name,
                        "offset_y":round(y,3),
                        "offset_z":round(z,3)
                    })
    return {
        "passed":not hits,
        "schema":"fmpl.water-purifier.side-bores.v11",
        "side_count":2,
        "probed_rays":sample_count,
        "bore_nominal_diameter":2*RADIUS,
        "inner_test_radius":.205,
        "hits":hits,
        "tested_actual_rendered_meshes":len(objs),
        "native_factorio_fluidbox_verified":False,
    }
