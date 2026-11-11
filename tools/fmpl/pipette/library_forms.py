#!/usr/bin/env python3
"""FMPL Pipette -- five distinct editable carrier constructions.

Pure-Python geometry. All positions use the existing frozen reference ports.
No invisible engineering performance claims and no unanchored support rings.
These constructions are not generic retextures of a circular pipe:
  * layflat: actual flattened hollow cross section,
  * twin: two separate hollow lumens with a bonded external web,
  * retractile: 14-turn continuous axial hollow coil,
  * ladder: two rails with real cross rungs and open spaces,
  * slotted duct: U-shaped base and slotted upright combs.

Native .blend/.glb and real Cycles proof are separate approval gates.
"""
from __future__ import annotations

import math
if __package__:
    from . import library_geometry as g
else:
    import library_geometry as g

TAU = math.tau
SUPPORTED = {
    "tube_retractile_coil":"retractile",
    "hose_layflat":"layflat",
    "hose_twin_bonded":"twin",
    "housing_ladder_tray":"ladder",
    "housing_slotted_duct":"slotted",
}


def _frame(axis):
    d = g.unit(axis)
    u,v = g.frame(d)
    return d,u,v


def _tag(part, role, profile, a, b, **metadata):
    part["role"] = role
    part["profile_kind"] = profile
    part["public_port_centers_unchanged"]=[list(a), list(b)]
    part.update(metadata)
    return part


def _rail(a,b,arch,width,thickness,name,role):
    """Closed rectangular structural extrusion (width and height independent).

    This is NOT a flat electrical ribbon. A tray rail may be narrow and tall;
    the former ribbon-only helper incorrectly rejected a rail when its wall
    height exceeded its width. The actual prism is just six real faces with
    a stable local cross-section oriented along its authored segment.
    """
    if width<=0 or thickness<=0:
        raise ValueError("Invalid rail width or wall height")
    _,u,v=_frame(g.sub(b,a))
    corners=((-1,-1),(-1,1),(1,1),(1,-1))
    verts=[]
    for center in (a,b):
        for x,y in corners:
            verts.append(g.plus(center,g.plus(
                g.mult(u,x*width*.5),g.mult(v,y*thickness*.5))))
    faces=[
        (3,2,1,0),(4,5,6,7),
        (0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)
    ]
    m=g.mesh(name,role,verts,faces,architecture_id=arch)
    return _tag(m,role,"solid-rectangular-rail",a,b,
                solid_rail=True,
                actual_section_width_bu=width,
                actual_section_height_bu=thickness)


def flattened_hollow(a,b,architecture_id,nominal_od=.12):
    """One watertight wall with a genuinely open flattened/elliptical bore."""
    if not .03<=nominal_od<=.5:
        raise ValueError("Invalid scene-relative envelope")
    span = g.norm(g.sub(b,a))
    route=g.sample_centerline(a,b,sag=span*.12,samples=57)
    centers=g.resample(route,104)
    sides=40
    width=nominal_od*.96
    thickness=nominal_od*.33
    # No null inner bore: this is an actual thin flattened transport hose.
    inner_w=width*.87
    inner_h=thickness*.49
    vertices=[]
    faces=[]
    for i,center in enumerate(centers):
        tan=g.sub(centers[min(i+1,len(centers)-1)],
                  centers[max(0,i-1)])
        _,u,v=_frame(tan)
        for outer in (True,False):
            halfw=(width if outer else inner_w)*.5
            halfh=(thickness if outer else inner_h)*.5
            for k in range(sides):
                t=TAU*k/sides
                offset=g.plus(g.mult(u,halfw*math.cos(t)),
                              g.mult(v,halfh*math.sin(t)))
                vertices.append(g.plus(center,offset))
    stride=sides*2
    for i in range(len(centers)-1):
        x,y=i*stride,(i+1)*stride
        for k in range(sides):
            nxt=(k+1)%sides
            faces.append((x+k,x+nxt,y+nxt,y+k))
            faces.append((x+sides+k,y+sides+k,y+sides+nxt,x+sides+nxt))
    for base,first in ((0,True),((len(centers)-1)*stride,False)):
        for k in range(sides):
            nxt=(k+1)%sides
            faces.append((base+k,base+sides+k,base+sides+nxt,base+nxt)
                         if first else
                         (base+k,base+nxt,base+sides+nxt,base+sides+k))
    result=g.mesh("Flattened continuous hollow layflat discharge web",
                  "flattened-hollow-hose-wall",vertices,faces,
                  architecture_id=architecture_id,bore=True,
                  other={
                    "profile_kind":"flattened-elliptical-open-bore",
                    "outer_width_bu":width,
                    "outer_height_bu":thickness,
                    "inner_width_bu":inner_w,
                    "inner_height_bu":inner_h,
                    "public_port_centers_unchanged":[list(a),list(b)],
                    "centerline_start":list(a),"centerline_end":list(b)})
    return [result]


def retractile_coil(a,b,architecture_id,nominal_od=.12):
    """One genuinely hollow wound tube with 14 axial turns and straight leads.

    Unlike a corrugated cover, the transport lumen itself follows the helix.
    Each public endpoint is exact and no extra hose is invented inside the coil.
    """
    if not .03<=nominal_od<=.5:
        raise ValueError("Invalid coil envelope")
    axis=g.sub(b,a)
    length=g.norm(axis)
    if length<.5:
        raise ValueError("Retractile coil requires a visible service span")
    _,u,v=_frame(axis)
    turns=14
    coil_r=nominal_od*.285
    tube_od=nominal_od*.245
    p=[]
    for i in range(281):
        t=i/280
        # Smooth entry and exit, no additional connector or floating cap.
        envelope=math.sin(math.pi*t)**2
        theta=TAU*turns*t
        base=g.interpolate(a,b,t)
        radial=g.plus(g.mult(u,math.cos(theta)*coil_r*envelope),
                      g.mult(v,math.sin(theta)*coil_r*envelope))
        p.append(g.plus(base,radial))
    p[0],p[-1]=tuple(a),tuple(b)
    m=g.tube(p,tube_od,.24,"smooth","Real helical retractile pneumatic lumen",
             architecture_id,sides=16)
    _tag(m,"hollow-helical-retractile-line","continuous-axial-coil",
         a,b,helix_turns=turns,centerline_radius_bu=coil_r,
         tube_outer_diameter_bu=tube_od,
         coil_outer_envelope_bu=2*coil_r+tube_od)
    if m["coil_outer_envelope_bu"]>nominal_od:
        raise ValueError("Coil exceeds shared nominal connection envelope")
    return [m]


def twin_bonded(a,b,architecture_id,nominal_od=.12):
    """Two distinct open-bore tubes; deliberately NOT a single branched bore."""
    if not .03<=nominal_od<=.5:
        raise ValueError("Invalid twin hose size")
    axis=g.sub(b,a)
    length=g.norm(axis)
    _,u,v=_frame(axis)
    route=g.sample_centerline(a,b,sag=length*.08,samples=61)
    channel_od=nominal_od*.45
    separation=nominal_od*.49
    pieces=[]
    for k,sign in enumerate((-1,1)):
        path=[g.plus(p,g.mult(u,sign*separation*.5)) for p in route]
        m=g.tube(path,channel_od,.27,"smooth",
                 "Individually open bonded lumen %d"%(k+1),
                 architecture_id,sides=20)
        pieces.append(_tag(m,"separate-hollow-channel","parallel-twin-lumen",
                           a,b,channel_index=k,channel_count=2,
                           no_fluid_interconnection=True,
                           internal_bore_diameter_bu=m["bore_diameter_bu"]))
    # External web lies on the TOP of both tubes. No web through either bore.
    top=[g.plus(p,g.mult(v,-channel_od*.5)) for p in route]
    web=g.flat_extrusion(top,nominal_od*.56,nominal_od*.08,
                        "Visible molded bonding ridge",architecture_id,
                        role="external-molded-bridge")
    pieces.append(_tag(web,"external-molded-bridge",
                       "twin-hose-outer-bond-web",a,b))
    if separation<=channel_od*.73:
        raise ValueError("Twin hose open lumens may overlap")
    return pieces


def ladder_tray(a,b,architecture_id,nominal_od=.12):
    """True open cable ladder: two rails and countable transverse crossbars."""
    axis=g.sub(b,a)
    length=g.norm(axis)
    if length<.4:
        raise ValueError("Tray must have room for physical rung spacing")
    _,u,v=_frame(axis)
    rail_offset=nominal_od*.43
    pieces=[]
    for side in (-1,1):
        d=g.mult(u,side*rail_offset)
        p=g.plus(a,d);q=g.plus(b,d)
        pieces.append(_rail(p,q,architecture_id,nominal_od*.12,
                      nominal_od*.30,"Ladder rail %s"%side,
                      "open-ladder-longitudinal-rail"))
    count=max(4,min(28,int(length/(nominal_od*1.75))))
    for i in range(count):
        t=(i+1)/(count+1)
        center=g.plus(g.interpolate(a,b,t),g.mult(v,nominal_od*.06))
        e=g.mult(u,rail_offset)
        p,q=g.sub(center,e),g.plus(center,e)
        pieces.append(_rail(p,q,architecture_id,nominal_od*.13,
                      nominal_od*.095,"Open ladder rung %02d"%(i+1),
                      "open-ladder-transverse-rung"))
    for p in pieces:
        p["public_port_centers_unchanged"]=[list(a),list(b)]
        p["rung_count"]=count
        p["carrier_has_open_air_gaps"]=True
    return pieces


def slotted_duct(a,b,architecture_id,nominal_od=.12):
    """Open U-shaped panel wiring duct, with genuine gaps between wall fingers."""
    axis=g.sub(b,a)
    length=g.norm(axis)
    if length<.4:
        raise ValueError("Slotted duct requires enough space for separate fingers")
    _,u,v=_frame(axis)
    pieces=[]
    floor_center=g.mult(v,nominal_od*.26)
    pieces.append(_rail(g.plus(a,floor_center),g.plus(b,floor_center),
                  architecture_id,nominal_od*.94,nominal_od*.14,
                  "Full length channel bottom","continuous-duct-floor"))
    slots=max(8,min(30,int(length/(nominal_od*1.30))))
    for side in (-1,1):
        wall=g.mult(u,side*nominal_od*.43)
        foot=g.plus(wall,g.mult(v,nominal_od*.16))
        pieces.append(_rail(g.plus(a,foot),g.plus(b,foot),
            architecture_id,nominal_od*.11,nominal_od*.20,
            "Continuous duct foot %s"%side,"continuous-duct-wall-foot"))
        for index in range(slots):
            beg=(index+.13)/slots
            end=(index+.78)/slots
            p=g.plus(g.interpolate(a,b,beg),
                     g.plus(wall,g.mult(v,-nominal_od*.07)))
            q=g.plus(g.interpolate(a,b,end),
                     g.plus(wall,g.mult(v,-nominal_od*.07)))
            finger=_rail(p,q,architecture_id,nominal_od*.11,
                         nominal_od*.36,
                         "Slotted wall finger %s-%02d"%(side,index),
                         "individual-slotted-wall-finger")
            finger["slot_index"]=index
            pieces.append(finger)
    for p in pieces:
        p["public_port_centers_unchanged"]=[list(a),list(b)]
        p["slot_count_per_side"]=slots
        p["carrier_has_open_air_gaps"]=True
        p["removable_lid_not_mounted"]=True
    return pieces


def generate(a,b,architecture_id,nominal_od=.12):
    """Return distinct editable meshes; refuse names without a real builder."""
    if architecture_id not in SUPPORTED:
        raise ValueError("Not a supported physical carrier form: "+architecture_id)
    if g.norm(g.sub(b,a))<.4:
        raise ValueError("Carrier span too short for meaningful fixed fixture")
    method=SUPPORTED[architecture_id]
    return {
        "retractile":retractile_coil,
        "layflat":flattened_hollow,
        "twin":twin_bonded,
        "ladder":ladder_tray,
        "slotted":slotted_duct
    }[method](a,b,architecture_id,nominal_od)
