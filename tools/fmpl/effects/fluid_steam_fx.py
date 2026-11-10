#!/usr/bin/env python3
"""FMPL animated fluid/steam machinery fixtures. Actual Blender meshes only.

Source-safe derivative assemblies; 1 Blender unit = 1 Factorio tile. No 2D
compositing, no fake engine fluidbox ports, no unclassified external donors.
"""
from __future__ import annotations
import math

import bpy
from mathutils import Vector

FRAMES = tuple(range(1, 92, 6)) + (97,)  # 16 authored 8fps samples + exact closing pose


def _own(p, collection, label, obj, material):
    obj.name = label
    return p.rehouse(obj, collection, material)


def _orb(p, collection, label, pos, radius, material):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=radius, location=pos)
    return _own(p, collection, label, bpy.context.object, material)


def _fluid_cylinder(p, collection, label, a, b, radius, material):
    start, end = Vector(a), Vector(b)
    axis = end - start
    if axis.length < .08:
        raise ValueError("Fluid pipe must span a physical segment")
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24, radius=radius, depth=axis.length,
        location=(start + end) / 2)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(axis)
    return _own(p, collection, label, obj, material)


def _clear_flow(p, col, label, a, b, glass, liquid, foam):
    """Actual see-through tube, liquid core and keyed moving witness particles."""
    p.open_hollow_tube(col, label+" / transparent tube", a, b, .055, glass)
    _fluid_cylinder(p, col, label+" / moving liquid channel", a, b, .030, liquid)
    start, end = Vector(a), Vector(b)
    for k in range(2):
        t0 = .22 + .36 * k
        ob = _orb(p, col, label+" / flow tracer %02d"%k,
                  start.lerp(end, t0), .017 + .003 * k, foam)
        for frame in FRAMES:
            phase = (t0 + .82*(frame-1)/96.) % .82 + .08
            ob.location = start.lerp(end, phase)
            ob.keyframe_insert(data_path="location", frame=frame)
        ob["fmpl_fluid_role"] = "keyed witness flow inside glass tube"


def _meniscus(p, col, index, center, radius, material):
    """Real triangulated fluid surface with two animated shape-key waveforms."""
    count = 32
    levels = (radius * .30, radius * .62, radius)
    vertices = [(0., 0., 0.)]
    for r in levels:
        for k in range(count):
            ang = math.tau * k / count
            vertices.append((r * math.cos(ang), r * math.sin(ang), 0.))
    faces = [(0, 1+k, 1+(k+1)%count) for k in range(count)]
    for ring in range(1, len(levels)):
        low, high = 1+(ring-1)*count, 1+ring*count
        for k in range(count):
            nxt = (k+1)%count
            faces.append((low+k, high+k, high+nxt, low+nxt))
    mesh = bpy.data.meshes.new("FMPL WITNESS WATER | %02d"%index)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(
        p.name_of("sample station %d moving liquid meniscus"%index), mesh)
    col.objects.link(obj)
    obj.location = center
    mesh.materials.append(material)
    obj["fmpl_fluid_role"] = "reconstructed vertex slosh surface"
    obj["fmpl_candidate_not_game_approved"] = True
    obj.shape_key_add(name="Datum")
    surge = obj.shape_key_add(name="Inlet surge")
    backwash = obj.shape_key_add(name="Return wash")
    for i, (x, y, _) in enumerate(vertices):
        r = math.hypot(x, y) / radius
        angle = math.atan2(y, x)
        surge.data[i].co.z = .052 * (x/radius) + .017*r*math.sin(3*angle)
        backwash.data[i].co.z = -.050*(x/radius) + .019*r*math.sin(3*angle + 1.4)
    for frame in FRAMES:
        phase = math.tau * (frame - 1) / 96.
        surge.value = .50 - .50 * math.cos(phase)
        surge.keyframe_insert(data_path="value", frame=frame)
        backwash.value = .50 - .50 * math.cos(phase + 1.35)
        backwash.keyframe_insert(data_path="value", frame=frame)
    return obj


def _bubbles(p, col, index, x, y, material):
    objects = []
    for k in range(12):
        angle = math.tau*k/12 + .17*index
        # Let the chamber's near-inner wall act as a physical observation face.
        # The bubble stays in the modeled fluid, not behind its opaque volume.
        r = .066 + .016*(k%3)
        dx = r*math.cos(angle)
        dy = -math.sqrt(max(.001, .148**2-dx**2)) + .012
        base = .800 + .036*(k%6)
        ob = _orb(p, col, "sample station %d liquid bubble %02d"%(index,k),
                  (x+dx, y+dy, base),
                  .027 + .004*(k%3), material)
        for frame in FRAMES:
            # Bounded, individually phase-shifted 16-sample rise with exact seam.
            phase = math.tau * (frame - 1)/96.
            dz = .050 + .050*math.sin(phase + .41*k)
            ob.location.z = base + dz*(.78+.055*(k%4))
            ob.keyframe_insert(data_path="location", index=2, frame=frame)
        ob["fmpl_fluid_role"] = "rising process bubble in transparent fluid"
        objects.append(ob)
    return objects


def _foam_crest(p, col, idx, x, y, z, material):
    """Front-side physical waterline foam. It follows keyed slosh, not a decal."""
    count=20
    verts=[]
    faces=[]
    radius=.151
    for k in range(count+1):
        angle=math.pi * k/count
        # Front semicircle sits just inside the glass, on the actual waterline.
        dx=radius*math.cos(angle)
        dy=-radius*math.sin(angle)
        verts.extend(((dx,dy,-.015),(dx,dy,.015)))
        if k:
            a=2*(k-1)
            b=2*k
            faces.append((a,b,b+1,a+1))
    mesh=bpy.data.meshes.new("FMPL fluid | witness crest %02d"%idx)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(
        p.name_of("sample station %d animated waterline foam crest"%idx),mesh)
    col.objects.link(obj)
    obj.location=(x,y,z)
    obj.data.materials.append(material)
    obj["fmpl_fluid_role"]="keyed foam crest following slosh at real transparent tank wall"
    obj["fmpl_candidate_not_game_approved"]=True
    for frame in FRAMES:
        phase=math.tau*(frame-1)/96.
        obj.location.z=z+.065*math.sin(phase)
        obj.rotation_euler.y=.17*math.sin(phase+.6)
        obj.keyframe_insert(data_path="location",frame=frame)
        obj.keyframe_insert(data_path="rotation_euler",frame=frame)
    return obj


def build_witness_canisters(col, p, mats):
    """Physically larger front RAW and CLEAN canisters with inlet/exit flow."""
    glass, iron, brass, steel = (
        mats.get("fx_glass", mats["glass"]), mats["iron"], mats["brass"], mats["steel"])
    dark, foam = mats["gunmetal"], mats["foam"]
    specs = ((1, -.36, mats["amber"], mats.get("fx_raw", mats["amber"])),
             (2, .24, mats["teal"], mats.get("fx_clear", mats["teal"])))
    out = {"vessels": 0, "moving_surfaces": 0, "visible_foam_crests": 0,
           "liquid_bubbles": 0, "flow_tracers": 0, "glass_flows": 0}
    for idx, x, liquid, surface_mat in specs:
        y = -1.272
        p.block(col, "sample station %d foundation shoe"%idx,
                (x,y+.04,.53), (.43,.27,.18), dark, .014)
        # Open-ended physical glass wall; preserve a pressure observation lid.
        # An opaque cylinder or iron cap would block the moving water entirely.
        p.open_hollow_tube(col,"sample station %d enlarged transparent vessel"%idx,
            (x,y,.659),(x,y,1.27),.176,glass)
        p.cyl(col,"sample station %d enlarged visible liquid column"%idx,
              (x,y,.895), .157, .518, surface_mat)
        for height in (.659, 1.270):
            p.torus(col,"sample station %d pressure retainer %.3f"%(idx,height),
                    (x,y,height),.182,.018,brass)
        for side in (-1,1):
            p.cyl(col,"sample station %d front sight support %d"%(idx,side),
                  (x+side*.158,y-.075,.96),.014,.63,steel,vertices=12)
        p.cyl(col,"sample station %d transparent pressure observation lid"%idx,
              (x,y,1.277),.165,.019,glass)
        _meniscus(p,col,idx,(x,y,1.158),.154,surface_mat)
        _foam_crest(p,col,idx,x,y,1.158,foam)
        out["liquid_bubbles"] += len(_bubbles(p,col,idx,x,y,foam))
        out["vessels"] += 1
        out["moving_surfaces"] += 1
        out["visible_foam_crests"] += 1
    # These are visible witness/sample branches connecting the EXISTING pump,
    # filter and discharge routes: they do not change the two engine fluidbox
    # openings at X+/-1.5 Y0 Z.36.
    channels = (
        ("raw-canister inlet",(-.72,-1.118,1.122),(-.536,-1.272,1.122),mats.get("fx_raw", mats["amber"])),
        ("raw-canister outlet",(-.536,-1.272,.762),(-.72,-1.09,.762),mats.get("fx_raw", mats["amber"])),
        ("clean-canister inlet",(.590,-1.105,1.122),(.416,-1.272,1.122),mats.get("fx_clear", mats["teal"])),
        ("clean-canister outlet",(.416,-1.272,.762),(.590,-1.105,.762),mats.get("fx_clear", mats["teal"]))
    )
    for label, start, end, liquid in channels:
        _clear_flow(p,col,label,start,end,glass,liquid,foam)
        out["glass_flows"] += 1
        out["flow_tracers"] += 2
    p.pipe_route(col,"raw witness feed from pump",
                 [(-1.12,-.79,.61),(-.94,-1.08,.94),(-.72,-1.118,1.122)],
                 .037,iron,brass)
    p.pipe_route(col,"raw witness return to first filter",
                 [(-.72,-1.09,.762),(-.82,-1.05,.72),(-.92,-1.00,.67)],
                 .037,steel,iron)
    p.pipe_route(col,"clean witness feed from treatment outlet",
                 [(.69,-.18,.79),(.74,-.86,.94),(.590,-1.105,1.122)],
                 .037,steel,iron)
    p.pipe_route(col,"clean witness return to discharge casting",
                 [(.590,-1.105,.762),(.82,-.87,.72),(.88,-.18,.66)],
                 .037,steel,brass)
    for label, _, near, _ in channels:
        p.torus(col,label+" / seated vessel connector gland",
                near,.060,.013,brass,axis="X")
    return out


def add_relief_steam(col,p,mats):
    """Stepped, keyframed, restrained vapor from the REAL top relief nozzle."""
    steam = mats.get("fx_steam") or bpy.data.materials.get("FMPL | vented condensed steam")
    if steam is None:
        raise RuntimeError("FMPL vented condensed steam material is missing")
    for k in range(4):
        x0=.94 + .045 * k
        y0=.60 + .012 * (k%2)
        z0=2.89 + .083 * k
        ob = _orb(p,col,"relief nozzle keyed condensed steam %02d"%k,
                  (x0,y0,z0),.088,steam)
        for frame in FRAMES:
            phase = math.tau * (frame - 1)/96.
            s = .22 + .90 * (math.sin(phase + .48*k)**2)
            ob.scale=(.72*s,.62*s,1.20*s)
            ob.location=(x0+.018*s,y0+.015*s,z0+.09*s)
            ob.keyframe_insert(data_path="scale",frame=frame)
            ob.keyframe_insert(data_path="location",frame=frame)
        ob["fmpl_fx_origin"] = "physical relief nozzle (.94,.60,2.80)"
    return {"relief_steam_puffs":4,"origin_xyz":(.94,.60,2.80)}
