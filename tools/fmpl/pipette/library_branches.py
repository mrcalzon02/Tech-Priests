#!/usr/bin/env python3
"""FMPL Pipette: actual continuous loose-wire Y/tee breakout geometry.

This module deliberately does NOT use a solid block, panel box, universal
junction primitive, electrical splice, or replicated eight-wire branch.

Eight individually insulated conductors enter shared public port A:
  four continuous conductors exit B, four exit C.
Every conductor is ONE editable mesh spanning its source and destination.
Local strand offsets fit inside the fixed public mouth envelope; the public
XYZ/normal from the comparison fixture are NEVER rewritten.
Real compact lacing/heatshrink wraps and individual ferrules are separate
editable parts. Appearance rules do not imply electrical ratings.
"""
from __future__ import annotations

import math

if __package__:
    from . import library_geometry as geom
else:
    import library_geometry as geom

TAU=math.tau
SUPPORTED={"wire_eight_loose_bundle","wire_eight_laced_loom"}
TOPOLOGIES={"wye","tee"}


def _offset(axis, index, count, radius, phase=0.0):
    u,v=geom.frame(axis)
    angle=TAU*(index/count+phase)
    return geom.plus(geom.mult(u,radius*math.cos(angle)),
                     geom.mult(v,radius*math.sin(angle)))


def _mean(points):
    if not points:
        raise ValueError("Empty wire group")
    return tuple(sum(p[axis] for p in points)/len(points)
                 for axis in range(3))


def _hollow_wrap(center,axis,diameter,length,architecture_id,label,
                 group_port,conductor_count,wrap_style):
    """Real tapered hollow polymer strain-relief boot following grouped wires.

    Axially substantial yet compact: round, softly tapered, with a positive
    hollow bore throughout. A rectangular box or paper-thin toroidal ring is
    never substituted for a physical wire-harness transition.
    """
    if not 0<diameter<.5 or not 0<length<.5:
        raise ValueError("Invalid taper-boot size")
    tangent=geom.unit(axis)
    u,v=geom.frame(tangent)
    sections=[(-.50,.96),(-.43,.98),(-.25,1.0),
              (0.,1.06),(.25,1.0),(.43,.98),(.50,.96)]
    sides=24
    verts=[]
    for along,scale in sections:
        origin=geom.plus(center,geom.mult(tangent,along*length))
        for ring in (0,1):
            radius=diameter*.5*scale*(1. if ring==0 else .87)
            for k in range(sides):
                phase=TAU*k/sides
                offset=geom.plus(geom.mult(u,radius*math.cos(phase)),
                                 geom.mult(v,radius*math.sin(phase)))
                verts.append(geom.plus(origin,offset))
    stride=sides*2
    faces=[]
    for section in range(len(sections)-1):
        a,b=section*stride,(section+1)*stride
        for k in range(sides):
            nxt=(k+1)%sides
            faces.append((a+k,a+nxt,b+nxt,b+k))
            faces.append((a+sides+k,b+sides+k,b+sides+nxt,a+sides+nxt))
    for base,is_start in ((0,True),((len(sections)-1)*stride,False)):
        for k in range(sides):
            nxt=(k+1)%sides
            faces.append((base+k,base+sides+k,base+sides+nxt,base+nxt)
                         if is_start else
                         (base+k,base+nxt,base+sides+nxt,base+sides+k))
    part=geom.mesh(label,"branch-strain-relief-wrap",
                   verts,faces,architecture_id=architecture_id,bore=True,
                   other={"profile_kind":"tapered-hollow-wire-breakout-boot",
                          "outer_diameter_bu":diameter,
                          "bore_diameter_bu":diameter*.96*.87,
                          "axial_length_bu":length})
    part["branch_hardware_type"]=wrap_style
    part["branch_port_id"]=group_port
    part["gripped_conductor_count"]=conductor_count
    part["structural_joint_verified"]=False
    return part


def _ferrule(endpoint, tangent, nominal_od, architecture_id,
             source_port, target_port, conductor_index, at_port):
    """A real compact annular crimp sleeve centered on an individual wire end."""
    axis=geom.unit(tangent)
    # Eight-wire insulated strand OD is 0.115 of the comparison OD.
    conductor_od=nominal_od*.115
    # Ferrule bore must clear the insulated strand: 1.37 * .80 = 1.096.
    ferrule_od=conductor_od*1.37
    # Confine small sleeve to the first 0.025 BU at each visible wire end;
    # its center does NOT alter the canonical public port XYZ.
    depth=nominal_od*.20
    inner=geom.plus(endpoint,geom.mult(axis,depth if at_port=="input" else -depth))
    part=geom.tube([endpoint,inner],ferrule_od,.20,"smooth",
                   "Crimp ferrule %s conductor %02d"%(at_port,conductor_index+1),
                   architecture_id,sides=12)
    part["role"]="individual-conductor-ferrule"
    part["ferrule_terminal_port"]=source_port if at_port=="input" else target_port
    part["conductor_index"]=conductor_index
    part["conductor_port_pair"]=[source_port,target_port]
    part["branch_hardware_type"]="wire-end-mini-ferrule"
    part["electrical_rating_verified"]=False
    return part


def build_eight_wire_y(architecture_id, topology_record, nominal_od=.12):
    """Construct physically continuous eight-to-four-plus-four Y/tee wiring.

    Fixture ports MUST have exactly A,B,C and a single HUB. Routing is
    normalized to those exact declared coordinates. No invented trunk branch
    socket, no solid box, and no electrical split/duplication of conductors.
    """
    if architecture_id not in SUPPORTED:
        raise ValueError("Wire breakout unsupported for "+str(architecture_id))
    if not 0.03 <= nominal_od <= .5:
        raise ValueError("Nonpositive/out-of-range demonstration diameter")
    if len(topology_record.get("ports",[]))!=3:
        raise ValueError("Eight-wire Y must have precisely three public ports")
    ports={p["id"]:p for p in topology_record["ports"]}
    if set(ports)!={"A","B","C"}:
        raise ValueError("Wire Y needs canonical ports A, B, C")
    hubs=topology_record.get("junctions",[])
    if len(hubs)!=1 or hubs[0]["id"]!="HUB":
        raise ValueError("Wire Y must have one named reference HUB")
    a=tuple(ports["A"]["xyz_bu"])
    h=tuple(hubs[0]["xyz_bu"])
    b=tuple(ports["B"]["xyz_bu"])
    c=tuple(ports["C"]["xyz_bu"])
    if min(geom.norm(geom.sub(h,a)),
           geom.norm(geom.sub(b,h)),
           geom.norm(geom.sub(c,h)))<.30:
        raise ValueError("Branch legs too short for visible conductor breakout")
    for port,axis in ((ports["A"],geom.sub(a,h)),
                      (ports["B"],geom.sub(b,h)),
                      (ports["C"],geom.sub(c,h))):
        if geom.dot(geom.unit(axis),
                    geom.unit(port["outward_normal"]))<.995:
            raise ValueError("Wrong public socket facing: "+port["id"])
    fixture=geom.source_json("comparison_fixture.v1.json")
    behavior=fixture["wire_bundle_display_policy"]
    if behavior["count"]!=8:
        raise ValueError("Authoritative eight-wire fixture count changed")
    multipliers=behavior["per_core_sag_multipliers"]
    phases=behavior["per_core_lateral_phase"]
    if len(multipliers)!=8 or len(phases)!=8:
        raise ValueError("Eight-conductor variation has invalid lengths")
    laced=(architecture_id=="wire_eight_laced_loom")
    arch=architecture_id
    strand_od=nominal_od*.115
    trunk_radius=nominal_od*.30
    exit_radius=nominal_od*.27
    trunk_direction=geom.unit(geom.sub(h,a))
    meshes=[]
    paths={}
    trunk_sites=[]
    exit_sites={"B":[],"C":[]}
    for k in range(8):
        # Partition by the physical upper/lower half of the incoming bundle.
        # Alternating arbitrary IDs between exits creates crossing spaghetti.
        upper="B" if b[1]>=c[1] else "C"
        lower="C" if upper=="B" else "B"
        target=upper if k in (2,3,4,5) else lower
        q=b if target=="B" else c
        branch_direction=geom.unit(geom.sub(q,h))
        start_offset=_offset(trunk_direction,k,8,trunk_radius,phase=.02)
        finish_offset=_offset(branch_direction,k,8,exit_radius,phase=.02)
        start=geom.plus(a,start_offset)
        end=geom.plus(q,finish_offset)
        # Each physical conductor passes through the junction exactly ONCE,
        # with a small lane-specific offset; no eight-to-sixteen cloning.
        divider=(1 if target==upper else -1)*nominal_od*.10
        h_offset=geom.plus(start_offset,(0.,divider,0.))
        passage=geom.plus(h,h_offset)
        length1=geom.norm(geom.sub(passage,start))
        length2=geom.norm(geom.sub(end,passage))
        sag1=length1*behavior["base_sag_fraction_of_span"]*.60*(1+.15*(multipliers[k]-1))
        sag2=length2*behavior["base_sag_fraction_of_span"]*.70*(1+.30*(multipliers[k]-1))
        p1=geom.sample_centerline(start,passage,sag=sag1,
              lateral=nominal_od*.034*phases[k]*.20,samples=51)
        p2=geom.sample_centerline(passage,end,sag=sag2,
              lateral=nominal_od*.025*phases[k]*.20,samples=51)
        # One continuous 101-sample route. A single tube mesh bridges the
        # central passage and has no internal disconnected cap at HUB.
        path=p1+p2[1:]
        result=geom.tube(path,strand_od,0.,"single_wire",
                         "Continuous breakout conductor %02d A to %s"%(k+1,target),
                         arch,sides=12)
        result["role"]="continuous-branched-conductor"
        result["conductor_index"]=k
        result["conductor_port_pair"]=["A",target]
        result["public_port_centers_unchanged"]=[
            list(a),list(q)]
        result["source_endpoint_bu"]=list(start)
        result["target_endpoint_bu"]=list(end)
        result["junction_passage_bu"]=list(passage)
        result["sag_blender_units"]=[sag1,sag2]
        result["branch_continuity"]=True
        result["electrical_connection_verified"]=False
        meshes.append(result)
        paths[k]=(p1,p2)
        trunk_sites.append(p1[40])
        exit_sites[target].append(p2[13])
        meshes.append(_ferrule(start,trunk_direction,nominal_od,arch,
                               "A",target,k,"input"))
        meshes.append(_ferrule(end,branch_direction,nominal_od,arch,
                               "A",target,k,"output"))
    # Prevent the physically impossible interpenetration that previously
    # happened when eight wires were linearly compressed into a tiny knot.
    # Compare real centerline samples across all eight trunk lanes and each
    # four-wire exit group. This is a deterministic cross-section acceptance
    # gate (not a full arbitrary 3D BVH cable-collision simulator).
    from itertools import combinations
    trunks=range(8)
    b_ids=[k for k in range(8) if (
        ("B" if b[1]>=c[1] else "C")=="B")==(k in (2,3,4,5))]
    c_ids=[k for k in range(8) if k not in b_ids]
    min_spacing=float("inf")
    for leg,groups in ((0,(tuple(trunks),)),
                       (1,(tuple(b_ids),tuple(c_ids)))):
        for indices in groups:
            for sample_index in range(51):
                for i,j in combinations(indices,2):
                    gap=geom.norm(geom.sub(
                        paths[i][leg][sample_index],
                        paths[j][leg][sample_index]))
                    min_spacing=min(min_spacing,gap)
    if min_spacing<=strand_od*1.08:
        raise RuntimeError(
            "Eight-wire breakout centerlines interpenetrate: "
            "min %.5f BU for %.5f BU strands"%(min_spacing,strand_od))
    if laced:
        # A loose wire assembly contains NO supports in empty space.
        # Only the explicitly laced harness requests protective wraps.
        # These modeled wraps are visually provisional until actually
        # conformed to the wire envelope and seated to real anchors.
        trunk_center=_mean(trunk_sites)
        meshes.append(_hollow_wrap(trunk_center,trunk_direction,
            nominal_od*.94,nominal_od*1.15,arch,
            "Laced incoming eight-wire containment sleeve","A",8,
            "eight-wire-laced-strain-relief"))
        for target in ("B","C"):
            q=b if target=="B" else c
            direction=geom.unit(geom.sub(q,h))
            center=_mean(exit_sites[target])
            meshes.append(_hollow_wrap(center,direction,
                nominal_od*.85,nominal_od*.88,arch,
                "Laced four-wire %s branch sleeve"%target,target,4,
                "four-wire-branch-heatshrink"))
        for index,at in enumerate((.52,.71)):
            locations=[paths[k][0][round(at*50)] for k in range(8)]
            meshes.append(_hollow_wrap(_mean(locations),trunk_direction,
                nominal_od*.92,nominal_od*.095,arch,
                "Laced loom trunk retaining tie %d"%(index+1),"A",8,
                "additional-harness-lacing"))
    # In loose-wire mode there is deliberately no suspended mid-span
    # steel/polymer ring, fictitious clamp, or strain-relief sleeve.
    if len([x for x in meshes if x["role"]=="continuous-branched-conductor"])!=8:
        raise RuntimeError("Conductor continuity count lost")
    if any(x["role"]=="junction-housing-preview" for x in meshes):
        raise RuntimeError("Wire breakout attempted generic box fallback")
    return {
        "meshes":meshes,
        "branch_hardware_type":("eight-wire-Y-laced-breakout" if laced else
                                "eight-wire-Y-unbound-loose-split"),
        "branch_has_mounted_support":False,
        "branch_strain_relief_wraps":5 if laced else 0,
        "branch_port_conductor_counts":{"A":8,"B":4,"C":4},
        "branch_route_count":8,
        "minimum_wire_center_spacing_bu":min_spacing,
        "minimum_wire_surface_gap_bu":min_spacing-strand_od,
        "cross_section_spacing_checked":True,
        "branch_continuity_constructed":True,
        "branch_splice_certified":False,
        "branch_strain_relief_verified":False,
        "connection_quality":"geometry-only; no electrical certification",
        "public_ports_unchanged":True,
    }
