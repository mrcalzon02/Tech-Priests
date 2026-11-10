#!/usr/bin/env python3
"""FMPL Pipette architectural linework mesh kernel (first native-geometry slice).

Pure Python; no bpy, NumPy, external dependencies, real-world gauge conversions,
simulation, or modification of existing FMPL assets. Returned objects contain
editable vertices/faces and exact reference fixture ports. Blender material
resolution and CSG fluid branch bores are delegated to library_blender.py.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
TAU = math.tau
MAX_RINGS = 2048
MAX_FACES = 90000

# Explicit geometry implementation targets. The other indexed architectures
# remain indexed, not claimed constructed or approved.
RECIPES = {
    "conduit_emt_thinwall": ("smooth_hollow", .16, "formed_metal"),
    "conduit_pvc_rigid": ("smooth_hollow", .20, "fixed"),
    "conduit_ent_corrugated": ("annular_polymer", .24, "corrugated_polymer"),
    "conduit_fmc_interlocked": ("interlocked_metal", .21, "spring_metal_flex"),
    "conduit_split_corrugated_loom": ("split_annular", .18, "corrugated_polymer"),
    "conduit_helical_plastic_wrap": ("open_spiral", 0., "flex_polymer"),
    "conduit_squarelock_metal": ("interlocked_metal", .24, "spring_metal_flex"),
    "conduit_articulated_segmented": ("articulated_rings", .24, "segmented_joint"),
    "housing_spring_guard": ("open_spiral", 0., "spring_guarded"),
    "hose_metal_annular": ("annular_metal", .18, "spring_metal_flex"),
    "hose_metal_helical": ("helical_metal", .18, "spring_metal_flex"),
    "hose_rubber_coolant": ("smooth_hollow", .27, "soft_hose"),
    "pipe_galvanized_threaded": ("smooth_hollow", .20, "fixed"),
    "pipe_lead_historical": ("soft_cast_hollow", .24, "semi_rigid"),
    "wire_single_insulated_solid": ("single_wire", 0., "loose_wire"),
    "wire_eight_loose_bundle": ("eight_wire", 0., "loose_bundle"),
    "wire_eight_laced_loom": ("eight_wire_tied", 0., "flex_bundle"),
    "rebar_deformed_ribbed": ("ribbed_rebar", 0., "formed_rebar"),
    "cable_steel_1x7": ("seven_strand", 0., "tensioned"),
}
WIRE_RECIPES = {"single_wire", "eight_wire", "eight_wire_tied", "seven_strand"}
OPEN_RECIPES = {"open_spiral", "split_annular"}


def source_json(filename):
    return json.loads((HERE / filename).read_text(encoding="utf-8"))


def plus(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mult(a, s):
    return tuple(x * s for x in a)


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1],
            a[2]*b[0]-a[0]*b[2],
            a[0]*b[1]-a[1]*b[0])


def norm(a):
    return math.sqrt(dot(a, a))


def unit(a):
    length = norm(a)
    if length < 1e-9:
        raise ValueError("Zero-length geometry vector")
    return mult(a, 1.0 / length)


def frame(tangent):
    """Deterministic stable near-horizontal frame, independent of camera."""
    tangent = unit(tangent)
    ref = (0., 0., 1.) if abs(tangent[2]) < .94 else (0., 1., 0.)
    u = unit(cross(tangent, ref))
    return u, unit(cross(tangent, u))


def interpolate(a, b, t):
    return plus(mult(a, 1-t), mult(b, t))


def polyline_length(points):
    return sum(norm(sub(b, a)) for a, b in zip(points, points[1:]))


def sample_centerline(a, b, sag=0.0, lateral=0.0, samples=49):
    """Zero endpoint drift. Smooth gravity-like sag plus bounded lateral bow."""
    if not 2 <= samples <= 256:
        raise ValueError("centerline sample count must be between 2 and 256")
    a, b = tuple(float(x) for x in a), tuple(float(x) for x in b)
    axis = sub(b, a)
    distance = norm(axis)
    if distance < 1e-6:
        raise ValueError("Pipette route endpoints coincide")
    u, v = frame(axis)
    # On horizontal lines the secondary frame points broadly toward +Z.
    lateral_axis = u
    points = []
    for k in range(samples):
        t = k / (samples-1)
        envelope = 4*t*(1-t)
        offset = plus((0., 0., -sag*envelope),
                      mult(lateral_axis, lateral*math.sin(math.pi*t)**2))
        points.append(plus(interpolate(a, b, t), offset))
    points[0], points[-1] = a, b
    return points


def resample(points, steps):
    if not 2 <= steps <= MAX_RINGS:
        raise ValueError("Unbounded mesh ring count")
    seglens = [norm(sub(b, a)) for a, b in zip(points, points[1:])]
    length = sum(seglens)
    if length < 1e-8:
        raise ValueError("Degenerate route")
    result = []
    for k in range(steps):
        target = length * k / (steps-1)
        done = 0.
        for i, seg in enumerate(seglens):
            if i == len(seglens)-1 or done+seg >= target:
                result.append(interpolate(points[i], points[i+1],
                                          max(0., min(1., (target-done)/max(seg, 1e-12)))))
                break
            done += seg
    result[0], result[-1] = tuple(points[0]), tuple(points[-1])
    return result


def mesh(name, role, verts, faces, *, architecture_id, port_ids=(), bore=False,
         other=None):
    if not verts or not faces or len(faces) > MAX_FACES:
        raise ValueError("empty or over-large Pipette mesh: "+name)
    data = {"name": name, "role": role, "architecture_id": architecture_id,
            "vertices": [list(map(float, v)) for v in verts],
            "faces": [list(map(int, f)) for f in faces],
            "port_ids": list(port_ids), "true_open_bore": bool(bore),
            "preview_only": True}
    if other:
        data.update(other)
    return data


def tube(points, diameter, wall, kind, name, architecture_id,
         sides=20, pitch=None):
    """Build visibly distinct hollow annuli/solid bars, with open axial bores.

    Profiles are evaluated per ring and per vertex. The helical phase explicitly
    includes the circumferential angle; annular rib phase does not. Split shells
    omit a real longitudinal wedge and close their slit-side wall surfaces.
    """
    if not 0 < diameter <= 2.0 or not 0 <= wall < .75:
        raise ValueError("Invalid relative Blender-unit wall or diameter")
    if sides < 12 or sides > 64:
        raise ValueError("Unsupported radial ring resolution")
    length = polyline_length(points)
    frequency = pitch or max(diameter*1.30, .065)
    count = min(MAX_RINGS, max(18, int(math.ceil(length /
                  min(diameter*.48, frequency/8)))+1))
    # Too long or too finely detailed is a deliberate hard error.
    if count >= MAX_RINGS:
        raise ValueError("Line exceeds bounded sample count")
    path = resample(points, count)
    slit = kind == "split_annular"
    rad = diameter/2
    bore = wall > 0
    core_rad = rad*(1-wall)
    n = sides+1 if slit else sides
    verts, faces = [], []
    progress = 0.
    for i, center in enumerate(path):
        if i:
            progress += norm(sub(center, path[i-1]))
        tangent = sub(path[min(i+1, count-1)],
                      path[max(0, i-1)])
        u, v = frame(tangent)
        for ring in range(2 if bore else 1):
            for j in range(n):
                if slit:
                    # Genuine longitudinal access slit: 0.15 radians removed.
                    theta = .075+(TAU-.15)*j/sides
                else:
                    theta = TAU*j/sides
                outer = (ring == 0)
                rr = rad if outer else core_rad
                if outer:
                    phase = TAU*progress/frequency
                    if kind in ("annular_polymer", "annular_metal", "split_annular"):
                        rr *= 1+.115*math.cos(phase)
                    elif kind in ("interlocked_metal", "helical_metal"):
                        rr *= 1+.11*math.cos(phase-theta)
                        rr *= 1+.028*math.cos(2*(phase-theta))
                    elif kind == "ribbed_rebar":
                        rr *= 1+.065*max(0, math.cos(phase-theta*.5))**8
                    elif kind == "soft_cast_hollow":
                        rr *= 1+.017*math.sin(progress*7+theta*2)
                direction = plus(mult(u, math.cos(theta)),
                                 mult(v, math.sin(theta)))
                verts.append(plus(center, mult(direction, rr)))
    stride = n*(2 if bore else 1)
    circum = n-1 if slit else n
    for i in range(count-1):
        a, b = i*stride, (i+1)*stride
        for j in range(circum):
            k = (j+1)%n
            faces.append((a+j, a+k, b+k, b+j))
            if bore:
                faces.append((a+n+j, b+n+j, b+n+k, a+n+k))
    if bore:
        for i in (0, count-1):
            base = i*stride
            for j in range(circum):
                k = (j+1)%n
                face = ((base+j, base+n+j, base+n+k, base+k)
                        if i == 0 else
                        (base+j, base+k, base+n+k, base+n+j))
                faces.append(face)
        if slit:
            for i in range(count-1):
                a, b = i*stride, (i+1)*stride
                faces.extend((
                    (a, b, b+n, a+n),
                    (a+n-1, a+2*n-1, b+2*n-1, b+n-1)))
    elif not slit:
        faces.append(tuple(reversed(tuple(range(n)))))
        faces.append(tuple((count-1)*stride+j for j in range(n)))
    return mesh(name, "hollow-section" if bore else "solid-section",
                verts, faces, architecture_id=architecture_id, bore=bore,
                other={"profile_kind": kind, "outer_diameter_bu": diameter,
                       "bore_diameter_bu": diameter*(1-wall) if bore else 0,
                       "centerline_start": list(points[0]),
                       "centerline_end": list(points[-1]),
                       "sample_rings": count,
                       "longitudinal_slit": slit})


def helical_ribbon(points, diameter, pitch, width, thickness,
                   name, architecture_id, *, role="spiral-wrap"):
    """Solid rectangular helical strip with genuine open gaps, not a decal."""
    if not 0 < width < pitch or not 0 < thickness < diameter*.4:
        raise ValueError("Helix pitch, band width and thickness inconsistent")
    length = polyline_length(points)
    revolutions = length / pitch
    count = max(40, int(revolutions*24)+1)
    if count >= MAX_RINGS:
        raise ValueError("Helical strip exceeds ring limit")
    path = resample(points, count)
    vertices, faces = [], []
    for i, p in enumerate(path):
        s = i/(count-1)*length
        tangent = sub(path[min(i+1, count-1)],
                      path[max(0, i-1)])
        u, v = frame(tangent)
        phase = TAU*s/pitch
        outward = plus(mult(u, math.cos(phase)), mult(v, math.sin(phase)))
        center = plus(p, mult(outward, diameter*.5))
        normal = unit(tangent)
        # Rectangular ribbon cross-section, swept along the true helix.
        for along, radial in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vertices.append(plus(center,
                            plus(mult(normal, width*.5*along),
                                 mult(outward, thickness*.5*radial))))
    faces.append((3, 2, 1, 0))
    for i in range(count-1):
        for j in range(4):
            k = (j+1)%4
            faces.append((i*4+j, i*4+k, (i+1)*4+k, (i+1)*4+j))
    faces.append(tuple((count-1)*4+j for j in range(4)))
    return mesh(name, role, vertices, faces, architecture_id=architecture_id,
                other={"profile_kind": "true-helical-ribbon", "pitch_bu": pitch,
                       "band_width_bu": width, "centerline_start": list(points[0]),
                       "centerline_end": list(points[-1])})


def wire_cores(a, b, architecture_id, *, eight=True, tied=False, diameter=.12,
               base_sag_fraction=.11):
    """Group-coherent eight-wire layout, never eight coincident core centerlines."""
    rig = source_json("comparison_fixture.v1.json")["wire_bundle_display_policy"]
    stiff = source_json("stiffness_profiles.v1.json")["wire_bundle_variation"]
    if rig["seed"] != stiff["deterministic_seed"]:
        raise ValueError("Unstable wire layout provenance")
    count = 8 if eight else 1
    span = norm(sub(b, a))
    tangent = unit(sub(b, a))
    u, v = frame(tangent)
    r = diameter*.30
    strands = []
    for k in range(count):
        theta = TAU*k/max(count, 1)
        offset = plus(mult(u, math.cos(theta)*r),
                      mult(v, math.sin(theta)*r)) if eight else (0.,0.,0.)
        # Local pin offsets exist INSIDE the one common public socket envelope.
        start, end = plus(a, offset), plus(b, offset)
        multiplier = rig["per_core_sag_multipliers"][k] if eight else 1
        phase = rig["per_core_lateral_phase"][k] if eight else 0
        sag = base_sag_fraction*span*multiplier
        lateral = diameter*.04*phase
        points = sample_centerline(start, end, sag=sag, lateral=lateral)
        item = tube(points, diameter*.115 if eight else diameter*.26, 0.,
                    "single_wire", "Conductor %02d"%(k+1),
                    architecture_id, sides=12)
        item["role"] = "individually-slack-insulated-wire"
        item["conductor_index"] = k
        item["sag_blender_units"] = sag
        item["public_port_centers_unchanged"] = [list(a), list(b)]
        strands.append(item)
    if tied:
        # Harness ties are individually modeled only on long two-point spans.
        for t in (.25, .5, .75):
            center = interpolate(a, b, t)
            center = plus(center, (0,0,-4*base_sag_fraction*span*t*(1-t)))
            tangent = sub(b, a)
            u, v = frame(tangent)
            verts, faces = [], []
            ringradius = diameter*.42
            for i in range(24):
                phase = TAU*i/24
                for z in (-.008, .008):
                    verts.append(plus(center,
                                plus(mult(u, ringradius*math.cos(phase)),
                                     plus(mult(v, ringradius*math.sin(phase)),
                                          mult(unit(tangent), z)))))
            for i in range(24):
                j=(i+1)%24
                faces.append((i*2, j*2, j*2+1, i*2+1))
            strands.append(mesh("Harness tie %.2f"%t, "periodic-loom-tie",
                                verts, faces, architecture_id=architecture_id))
    return strands


def steel_seven_strand(a, b, architecture_id, diameter=.12):
    """True 1x7 cable: one central steel strand and six wound outer strands."""
    axis = sub(b, a)
    length = norm(axis)
    tangent = unit(axis)
    u, v = frame(tangent)
    # One thick center strand + six physically distinct helical wires.
    r = diameter*.24
    small = diameter*.31
    base = sample_centerline(a, b, sag=length*.012, samples=129)
    meshes = [tube(base, small, 0., "single_wire", "Seven rope center",
                   architecture_id, sides=12)]
    meshes[0]["role"] = "solid-rope-core"
    for k in range(6):
        points = []
        for i, p in enumerate(base):
            phase = TAU*(k/6+2.8*i/(len(base)-1))
            points.append(plus(p, plus(mult(u, r*math.cos(phase)),
                                       mult(v, r*math.sin(phase)))))
        part = tube(points, diameter*.25, 0., "single_wire",
                    "Outer helical steel strand %d"%(k+1), architecture_id,
                    sides=12)
        part["role"] = "helically-wound-rope-strand"
        part["conductor_index"] = k+1
        meshes.append(part)
    return meshes


def terminal_ring(center, direction, diameter, architecture_id, *,
                  role="connector-sleeve", length_factor=.6, scale=1.12):
    a=plus(center, mult(unit(direction), -diameter*length_factor*.5))
    b=plus(center, mult(unit(direction), diameter*length_factor*.5))
    item=tube([a, b], diameter*scale, .20, "smooth_hollow",
              role, architecture_id, sides=24)
    item["role"]=role
    return item


def line_segment(a, b, architecture_id, *, nominal_od=.12, topology="straight"):
    """Geometries for one outward reference-fixture leg (no implicit joins)."""
    if architecture_id not in RECIPES:
        raise ValueError("Architecture not implemented: "+architecture_id)
    kind, wall, stiffness = RECIPES[architecture_id]
    stiffness_meta = source_json("stiffness_profiles.v1.json")["presets"][stiffness]
    sag_fraction = stiffness_meta["normalized_sag_fraction_of_span"]
    distance=norm(sub(b,a))
    if kind in {"eight_wire","eight_wire_tied"}:
        return wire_cores(a,b,architecture_id,tied=kind=="eight_wire_tied",
                          base_sag_fraction=sag_fraction)
    if kind=="single_wire":
        return wire_cores(a,b,architecture_id,eight=False,
                          base_sag_fraction=sag_fraction)
    if kind=="seven_strand":
        return steel_seven_strand(a,b,architecture_id,nominal_od)
    points=sample_centerline(a,b,sag=distance*sag_fraction)
    if kind=="open_spiral":
        return [helical_ribbon(points,nominal_od,pitch=nominal_od*.95,
                               width=nominal_od*.45,
                               thickness=nominal_od*.09,
                               name="Open helical protective strip",
                               architecture_id=architecture_id)]
    shape = {
        "smooth_hollow":"smooth", "soft_cast_hollow":"soft_cast_hollow",
        "annular_polymer":"annular_polymer", "annular_metal":"annular_metal",
        "interlocked_metal":"interlocked_metal",
        "helical_metal":"helical_metal",
        "split_annular":"split_annular", "ribbed_rebar":"ribbed_rebar",
        "articulated_rings":"annular_metal"}.get(kind)
    if shape is None:
        raise ValueError("No actual geometry recipe for "+kind)
    pitch=nominal_od*(.82 if shape=="interlocked_metal" else 1.08)
    body=tube(points,nominal_od,wall,shape,"Manufactured "+kind,
              architecture_id,pitch=pitch)
    result=[body]
    if kind in {"interlocked_metal"}:
        # Interlocking raised spiral seam: a separate solid strip, NOT annular
        # plastic corrugation and NOT a smooth pipe merely renamed as metal.
        result.append(helical_ribbon(points,nominal_od*1.16,
                pitch=pitch,width=pitch*.28,thickness=nominal_od*.045,
                name="Helically interlocked metal locking seam",
                architecture_id=architecture_id,role="metal-interlock-seam"))
    if kind=="articulated_rings":
        # Exposed manufactured sleeves, not simply a modified surface shader.
        for i in range(1,6):
            p=interpolate(a,b,i/6)
            tangent=unit(sub(b,a))
            result.append(terminal_ring(p,tangent,nominal_od,architecture_id,
                                        role="articulated-ring-%02d"%i,
                                        length_factor=.23,scale=1.06))
    return result


def build_demo(architecture_id, topology="wye", *, nominal_od=None):
    """Return an editable-mesh assembly with locked public port coordinates.

    Public port XYZ/normals are copied from the authoritative fixture. The
    render adapter must union/subtract hollow fluid manifolds at the HUB;
    ordinary preview tubes alone are not misrepresented as a sealed branch.
    """
    fixture = source_json("comparison_fixture.v1.json")
    catalog = source_json("architecture_catalog.v1.json")
    listed = {item["id"]:item for item in catalog["architecture_types"]}
    if architecture_id not in RECIPES or architecture_id not in listed:
        raise ValueError("Unimplemented or unknown architectural recipe")
    if topology not in fixture["topologies"]:
        raise ValueError("Unknown comparison topology")
    meta=listed[architecture_id]
    if topology not in meta["comparison_topologies"]:
        raise ValueError("Topology incompatible with architecture")
    topo=fixture["topologies"][topology]
    diameter=float(nominal_od or fixture["workspace"]["nominal_outer_diameter_bu"])
    if not .03 <= diameter <= .5:
        raise ValueError("Invalid comparison OD")
    points={p["id"]:tuple(p["xyz_bu"]) for p in topo["ports"]}
    points.update({p["id"]:tuple(p["xyz_bu"]) for p in topo["junctions"]})
    result=[]
    for a,b in topo["connection_graph"]:
        result.extend(line_segment(points[a],points[b],architecture_id,
                                   nominal_od=diameter,topology=topology))
    # Distinct geometry with explicit provenance; no invented functional join.
    # For branching pipes, native Blender MUST boolean-union outer shells and
    # subtract their continuous bores before marking them as a valid manifold.
    needs_manifold = len(topo["ports"]) >= 3 and meta["group"] in {
        "metal_pipe","polymer_pipe","hose","tubing"}
    if len(topo["ports"])>=3 and not needs_manifold:
        # Central insulated junction enclosure is *not* an implicit electrical
        # or fluid network. It is a real visible housing for the branch fanout.
        center=tuple(topo["junctions"][0]["xyz_bu"])
        w=diameter*1.75
        # Concise cube with properly modeled solid faces, tagged unapproved.
        v=[(center[0]+x*w,center[1]+y*w,center[2]+z*w*.68)
           for x,y,z in ((-1,-1,-1),(-1,-1,1),(-1,1,-1),
                         (-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1))]
        f=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),
           (0,2,3,1),(4,5,7,6)]
        result.append(mesh("Typed branch housing - open for connector review",
                           "junction-housing-preview",v,f,
                           architecture_id=architecture_id))
    return {
        "schema":"fmpl.pipette.geometry-preview.v1",
        "architecture_id":architecture_id,
        "topology":topology,
        "catalog_group":meta["group"],
        "construction_profile":RECIPES[architecture_id][0],
        "public_ports":[dict(p) for p in topo["ports"]],
        "junctions":[dict(p) for p in topo["junctions"]],
        "nominal_outer_diameter_bu":diameter,
        "meshes":result,
        "requires_native_csg_manifold":needs_manifold,
        "electrical_or_fluid_simulation_verified":False,
        "approved_materials":False,
        "native_blender_verified":False,
        "provenance":"distinct procedural editable geometry; not production approved"
    }


def export_obj(model, target):
    """External inspection format; Blender .blend and GLB remain native gates."""
    target=Path(target)
    if target.exists():
        raise FileExistsError("Refuse to overwrite existing mesh preview")
    target.parent.mkdir(parents=True,exist_ok=True)
    lines=["# FMPL Pipette generated geometry: not yet native verified"]
    offset=0
    for part in model["meshes"]:
        lines.append("o "+part["name"].replace(" ","_"))
        for x,y,z in part["vertices"]:
            lines.append("v %.8f %.8f %.8f"%(x,y,z))
        for face in part["faces"]:
            lines.append("f "+" ".join(str(offset+i+1) for i in face))
        offset+=len(part["vertices"])
    target.write_text("\n".join(lines)+"\n",encoding="utf-8")
    return target


def main():
    import argparse
    parser=argparse.ArgumentParser(description="FMPL Pipette indexed construction mesh pilot")
    parser.add_argument("--architecture",required=True,choices=sorted(RECIPES))
    parser.add_argument("--topology",default="wye")
    parser.add_argument("--out-obj",required=True)
    parser.add_argument("--out-json",required=True)
    args=parser.parse_args()
    m=build_demo(args.architecture,args.topology)
    report=Path(args.out_json)
    if report.exists():
        raise FileExistsError("Refuse to overwrite existing receipt")
    export_obj(m,args.out_obj)
    receipt={k:v for k,v in m.items() if k!="meshes"}
    receipt["mesh_count"]=len(m["meshes"])
    receipt["face_count"]=sum(len(x["faces"]) for x in m["meshes"])
    receipt["vertex_count"]=sum(len(x["vertices"]) for x in m["meshes"])
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PIPETTE_GEOMETRY_PILOT",m["architecture_id"],m["topology"],
          receipt["mesh_count"],receipt["face_count"])


if __name__=="__main__":
    main()
