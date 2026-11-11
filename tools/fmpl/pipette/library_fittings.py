#!/usr/bin/env python3
"""FMPL Pipette first procedural connector/fitting meshes (no bpy required).

Each fitting is modeled as separate visible solids, not an adjective or shader.
These are editable dimension-relative *visual* fittings, pending real mating
socket/pressure/ampacity/force and source-material approval. No global mm/AWG.
"""
from __future__ import annotations

import math

if __package__:
    from . import library_geometry as g
else:
    import library_geometry as g

TAU=math.tau
# The 77-entry registry is broader; these physically constructed entries
# are the INITIAL reusable fitting geometry kernel.
FITTING_RECIPES={
    "flange":"bolted_hollow_flange",
    "compression":"hex_nut_and_ferule",
    "bite_ferrule":"double_ferrule_nut",
    "threaded":"helical_external_thread",
    "hose_barb_clamp":"barbed_spigot_and_band",
    "hose_crimp":"crimp_ferrule_and_insert",
    "sanitary_clamp":"paired_ferrules_and_clamp",
    "cable_gland":"hex_entry_nut_grommet",
    "compression_conduit":"metal_raceway_compression",
    "rigid_threaded_hub":"electrical_threaded_hub",
    "flex_conduit_connector":"flex_sheath_capture",
    "liquidtight_connector":"sealed_conduit_gland",
    "locknut_bushing":"threaded_locknut_and_insulated_lip",
    "snap_conduit":"molded_snap_lips",
    "split_loom_clip":"slitted_conduit_entry_clip",
    "crimp_butt":"electrical_double_ended_crimp",
    "ring_lug":"crimp_barrel_and_bolted_eye",
    "terminal_block":"eight_way_insulated_terminal_strip",
    "rebar_threaded_coupler":"heavy_solid_bar_coupling_sleeve",
    "turnbuckle":"screw_adjustable_tension_link",
    "clevis":"forked_mechanical_pin",
}
def annul(center, axis, outer, inner, length, *,
          arch, label, role, hex_outer=False, sides=24):
    """Open-bore round/hex annular fitting with real physical wall faces."""
    if not 0<inner<outer or length<=0 or sides<12:
        raise ValueError("Impossible annular fitting profile")
    t=g.unit(axis)
    u,v=g.frame(t)
    verts=[]
    for sign in (-1,1):
        base=g.plus(center,g.mult(t,sign*length*.5))
        for shape in ("outer","inner"):
            for k in range(sides):
                theta=TAU*k/sides
                r=outer if shape=="outer" else inner
                if hex_outer and shape=="outer":
                    # Six actual flats, not a circular cylinder mislabeled nut.
                    a=(theta+math.pi/6)%(math.pi/3)-math.pi/6
                    r=outer*math.cos(math.pi/6)/math.cos(a)
                direction=g.plus(g.mult(u,math.cos(theta)),
                                 g.mult(v,math.sin(theta)))
                verts.append(g.plus(base,g.mult(direction,r)))
    faces=[]
    for k in range(sides):
        j=(k+1)%sides
        faces.extend((
            (k,j,2*sides+j,2*sides+k),
            (sides+k,3*sides+k,3*sides+j,sides+j),
            (k,sides+k,sides+j,j),
            (2*sides+k,2*sides+j,3*sides+j,3*sides+k)))
    return g.mesh(label,role,verts,faces,architecture_id=arch,bore=True,
                  other={"fitting_body":True,"outer_radius_bu":outer,
                         "bore_radius_bu":inner,"hex_six_flats":hex_outer})


def rod(a,b,r, *,arch,label,role="solid-fastener",sides=12):
    """True solid cylindrical rod with closed end caps."""
    t=g.unit(g.sub(b,a))
    u,v=g.frame(t)
    verts=[]
    for p in (a,b):
        for k in range(sides):
            theta=TAU*k/sides
            verts.append(g.plus(p,g.plus(g.mult(u,r*math.cos(theta)),
                                         g.mult(v,r*math.sin(theta)))))
    faces=[tuple(range(sides-1,-1,-1)),
           tuple(range(sides,2*sides))]
    for k in range(sides):
        j=(k+1)%sides
        faces.append((k,j,sides+j,sides+k))
    return g.mesh(label,role,verts,faces,architecture_id=arch)


def block(center, axis, length, width, height, *,arch,label,role):
    """A real six-faced cuboid in a local port frame."""
    t=g.unit(axis)
    u,v=g.frame(t)
    verts=[]
    for x in (-.5,.5):
        for y in (-.5,.5):
            for z in (-.5,.5):
                verts.append(g.plus(center,
                  g.plus(g.mult(t,x*length),
                    g.plus(g.mult(u,y*width),g.mult(v,z*height)))))
    faces=[(0,2,6,4),(1,5,7,3),(0,4,5,1),
           (2,3,7,6),(0,1,3,2),(4,6,7,5)]
    return g.mesh(label,role,verts,faces,architecture_id=arch)


def build(architecture_id, joint_id, port, diameter=.12):
    """Build a named compatible terminal fitting at a FIXED public socket.

    This consumes the architecture's allowed joint list, not free-form
    arbitrary coupling. Fittings are explicitly staged, not certified by an
    existing socket or proof of Factorio-native fluidbox interoperability.
    """
    catalog=g.source_json("architecture_catalog.v1.json")
    known={t["id"]:t for t in catalog["architecture_types"]}
    if architecture_id not in known:
        raise ValueError("Unknown source architecture")
    profile=known[architecture_id]
    if joint_id not in profile["compatible_joint_ids"]:
        raise ValueError("Joint %s incompatible with architecture %s"%
                         (joint_id,architecture_id))
    if joint_id not in FITTING_RECIPES:
        raise ValueError("Fitting is indexed but not yet implemented: "+joint_id)
    ports=g.source_json("comparison_fixture.v1.json")
    if not isinstance(port,dict) or not all(
         field in port for field in ("id","xyz_bu","outward_normal")):
        raise ValueError("Fitting needs an explicit typed comparison port")
    p=tuple(port["xyz_bu"])
    axis=tuple(port["outward_normal"])
    if abs(g.norm(axis)-1.)>1e-6:
        raise ValueError("Nonunit fixture direction")
    r=diameter*.5
    result=[]
    def tube(label,outer,inner,depth,hexed=False,role="fitting-annulus",displacement=0):
        center=g.plus(p,g.mult(axis,displacement))
        return annul(center,axis,outer,inner,depth,arch=architecture_id,
                     label=label,role=role,hex_outer=hexed)
    def pin(label,rad,up,normal_depth,role="fastener"):
        # Radial pin origin on actual collar, not floating in local coords.
        u,v=g.frame(axis)
        center=g.plus(p,g.plus(g.mult(u,rad*math.cos(up)),
                              g.mult(v,rad*math.sin(up))))
        return rod(g.plus(center,g.mult(axis,-normal_depth*.5)),
                   g.plus(center,g.mult(axis,normal_depth*.5)),
                   diameter*.045,arch=architecture_id,label=label,role=role)
    if joint_id=="flange":
        result.append(tube("True hollow flange disk",r*1.90,r*.78,r*.36,
                           role="flange-with-open-bore"))
        for i in range(6):
            result.append(pin("Flange captive bolt %d"%i,r*1.55,TAU*i/6,
                              r*.65))
        result.append(tube("Mating pipe throat",r*1.02,r*.78,r*.86,
                           role="concentric-mating-throat"))
    elif joint_id in {"compression","bite_ferrule","compression_conduit",
                      "rigid_threaded_hub","liquidtight_connector",
                      "locknut_bushing","flex_conduit_connector","cable_gland"}:
        result.append(tube("Real hex retaining nut",r*1.42,r*.79,r*.85,
                           hexed=True,role="six-flat-retaining-nut"))
        result.append(tube("Seated receiving sleeve",r*1.02,r*.77,r*1.02,
                           role="concentric-insertion-sleeve",
                           displacement=-r*.20))
        if joint_id in {"bite_ferrule","liquidtight_connector","cable_gland"}:
            for i in range(2 if joint_id=="bite_ferrule" else 1):
                result.append(tube("Compressed gasket or ferrule %d"%i,
                                   r*.99,r*.82,r*.17,
                                   role="actual-ferrule-or-grommet",
                                   displacement=(i-.5)*r*.34))
        if joint_id=="flex_conduit_connector":
            points=[g.plus(p,g.mult(axis,-r*.75)),
                    g.plus(p,g.mult(axis,r*.12))]
            result.append(g.helical_ribbon(points,diameter,
                          pitch=diameter*.25,width=diameter*.11,
                          thickness=diameter*.036,
                          name="Captured helical sheath grip",
                          architecture_id=architecture_id,
                          role="conduit-helical-retention"))
    elif joint_id=="threaded":
        result.append(tube("Hollow threaded nipple body",r*1.01,r*.77,
                           r*1.6,role="open-bore-thread-body"))
        points=[g.plus(p,g.mult(axis,-r*.8)),
                g.plus(p,g.mult(axis,r*.8))]
        result.append(g.helical_ribbon(points,diameter,pitch=diameter*.18,
                      width=diameter*.08,thickness=diameter*.045,
                      name="Actual raised external helical thread",
                      architecture_id=architecture_id,role="male-thread-ridge"))
    elif joint_id in {"hose_barb_clamp","hose_crimp"}:
        result.append(tube("Real hollow hose barb nipple",r*.83,r*.58,
                           r*1.65,role="inserted-fluid-spigot"))
        for i in range(3 if joint_id=="hose_barb_clamp" else 5):
            result.append(tube("Hose circumferential retention ridge %02d"%i,
                               r*(1.07 if joint_id=="hose_barb_clamp" else 1.12),
                               r*.77,r*.11,role="retaining-barb-or-crimp",
                               displacement=r*(-.5+i*.24)))
        result.append(tube("Hose retaining clamp band",r*1.28,r*.84,
                           r*.3,role="full-width-clamp-band"))
    elif joint_id=="sanitary_clamp":
        for i in (-1,1):
            result.append(tube("Sanitary ferrule face %d"%i,r*1.4,r*.77,
                               r*.21,role="sanitary-ferrule",
                               displacement=i*r*.28))
        result.append(tube("Sanitary external ring clamp",r*1.52,r*1.14,
                           r*.48,role="external-clamp-ring"))
    elif joint_id in {"snap_conduit","split_loom_clip"}:
        result.append(tube("Polymer receiving collar",r*1.22,r*.75,
                           r*.58,role="polymer-receiving-hub"))
        for i in (-1,1):
            u,v=g.frame(axis)
            center=g.plus(p,g.mult(u,i*r*1.19))
            result.append(block(center,axis,r*.80,r*.20,r*.19,
                                arch=architecture_id,label="Spring snap-tab %d"%i,
                                role="polymer-snap-tab"))
    elif joint_id=="crimp_butt":
        result.append(tube("Electrical opposed end crimp sleeve",r*.72,
                           r*.32,r*2.1,role="two-sided-electrical-crimp"))
        for i in (-1,1):
            result.append(tube("Compressed conductor-end retaining bead %d"%i,
                               r*.77,r*.31,r*.18,
                               role="end-crimp-indent",
                               displacement=i*r*.58))
    elif joint_id=="ring_lug":
        result.append(tube("Conductor crimp barrel",r*.74,r*.31,r*1.3,
                           role="wire-crimp-barrel",displacement=-r*.50))
        result.append(block(g.plus(p,g.mult(axis,r*.47)),axis,
                            r*.76,r*.48,r*.17,
                            arch=architecture_id,label="Conductive lug tang bridge",
                            role="solid-lug-bridge"))
        result.append(tube("Flat conductive bolt eye",r*1.23,r*.39,r*.22,
                           role="flat-ring-lug",displacement=r*.90))
    elif joint_id=="terminal_block":
        # Never put eight blind contacts on a real two-conductor cable.
        # The construction recipe determines the number of independently
        # insulated terminal positions in a common, type-compatible housing.
        count=(2 if architecture_id=="wire_twisted_pair" else
               8 if architecture_id in {"wire_eight_loose_bundle",
                                         "wire_eight_laced_loom",
                                         "wire_eight_sheathed"} else 1)
        result.append(block(p,axis,diameter*.75,
                            diameter*(1.50 if count>=8 else .85),diameter*.86,
                            arch=architecture_id,
                            label="%d separately insulated terminal positions"%count,
                            role=("eight-way-connector-housing" if count==8
                                  else "sized-multicore-connector-housing")))
        u,v=g.frame(axis)
        for i in range(count):
            alpha=TAU*i/count
            # Contacts sit on the outside face of the connector housing, not
            # hidden inside an opaque box with an arbitrary conductor count.
            spot=g.plus(g.plus(p,g.mult(axis,diameter*.39)),
                        g.plus(g.mult(u,r*.44*math.cos(alpha)),
                               g.mult(v,r*.44*math.sin(alpha))))
            part=annul(spot,axis,r*.14,r*.065,r*.11,
                        arch=architecture_id,label="Conductive socket %d"%i,
                        role="individual-recessed-contact")
            part["conductor_index"]=i
            result.append(part)
    elif joint_id=="rebar_threaded_coupler":
        result.append(tube("Solid-bar mechanical coupling sleeve",r*1.38,
                           r*.89,r*1.6,hexed=True,
                           role="solid-bar-grip-coupler"))
        result.append(tube("Coupling steel retaining rim",r*1.44,r*.91,
                           r*.24,role="mechanical-sleeve-rim"))
    elif joint_id=="clevis":
        u,_=g.frame(axis)
        for sign in (-1,1):
            center=g.plus(p,g.mult(u,sign*r*.70))
            result.append(block(center,axis,r*1.6,r*.20,r*.46,
                                arch=architecture_id,label="Clevis fork ear %d"%sign,
                                role="clevis-paired-ears"))
        result.append(rod(g.plus(p,g.mult(u,-r*.95)),
                          g.plus(p,g.mult(u,r*.95)),
                          r*.17,arch=architecture_id,label="Clevis captive cross-pin",
                          role="transverse-load-pin"))
    elif joint_id=="turnbuckle":
        result.append(tube("Turnbuckle central threaded body",r*.95,r*.33,
                           r*2.,hexed=True,role="tensioning-body"))
        for sign in (-1,1):
            a=g.plus(p,g.mult(axis,sign*r*.95))
            b=g.plus(p,g.mult(axis,sign*r*1.75))
            result.append(rod(a,b,r*.28,arch=architecture_id,
                              label="Turnbuckle threaded shank %d"%sign,
                              role="opposed-thread-shank"))
    else:
        raise ValueError("Unimplemented fitting recipe "+joint_id)
    for m in result:
        m["joint_type"]=joint_id
        m["public_socket_id"]=port["id"]
        m["public_socket_xyz_bu"]=list(p)
        m["port_has_been_moved"]=False
        m["native_socket_seating_verified"]=False
    return result


def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument("--architecture",required=True)
    ap.add_argument("--joint",required=True)
    ap.add_argument("--topology",default="straight")
    ap.add_argument("--port",default="A")
    ap.add_argument("--out-obj",required=True)
    args=ap.parse_args()
    fixture=g.source_json("comparison_fixture.v1.json")["topologies"][args.topology]
    port=next((x for x in fixture["ports"] if x["id"]==args.port),None)
    if port is None:
        raise ValueError("Unknown public port")
    parts=build(args.architecture,args.joint,port)
    g.export_obj({"meshes":parts},args.out_obj)
    print("FMPL_PIPETTE_FITTING_BUILT",args.architecture,args.joint,
          len(parts),"parts")


if __name__=="__main__":
    main()
