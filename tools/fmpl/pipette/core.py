#!/usr/bin/env python3
"""FMPL Pipette v0.1: deterministic, Blender-unit linework planning, no bpy.

No real-world sizing conversions, geometry exports, hidden internals or
simulation. The Blender adapter (separate stage) consumes these plans.
"""
from __future__ import annotations
import argparse
import itertools
import json
import math
import re
from pathlib import Path

SCHEMA = "fmpl.pipette.route.v0.1"
PLAN_SCHEMA = "fmpl.pipette.plan.v0.1"
SIZE_PRESETS = {
    "hairline": 0.012, "thin": 0.025, "regular": 0.060,
    "heavy": 0.120, "massive": 0.250,
}
FLUID = {"fluid", "coolant", "air", "gas", "steam"}
ELECTRICAL = {"wires", "signal", "power"}
FAMILY_PAYLOADS = {
    "rigid_pipe": FLUID | {"empty"},
    "segmented_conduit": FLUID | ELECTRICAL | {"empty"},
    "flex_hose": FLUID | {"empty"},
    "single_wire": ELECTRICAL,
    "wire_bundle": ELECTRICAL,
    "conduit": ELECTRICAL | FLUID | {"empty"},
    "tension_cable": {"mechanical_tension"},
    "rebar": {"reinforcement"},
}
FITTINGS = {
    "flange": FLUID, "compression": FLUID | {"empty"},
    "hose_tail": FLUID, "cable_gland": ELECTRICAL | {"empty"},
    "lug": ELECTRICAL, "eye": {"mechanical_tension"},
    "clevis": {"mechanical_tension"},
    "rebar_coupler": {"reinforcement"}, "lap": {"reinforcement"},
    "none": set().union(*FAMILY_PAYLOADS.values()),
}
MAX_SECTION_COUNT = 256
MAX_POINTS = 256
MAX_CONDUCTORS = 64


class PipetteError(ValueError):
    """Explicitly rejected route or unverified physical attachment."""


def _number(value, label, *, positive=False):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise PipetteError(label + " must be a Blender-unit number")
    x = float(value)
    if not math.isfinite(x) or (positive and x <= 0):
        raise PipetteError(label + " must be finite and positive" if positive
                           else label + " must be finite")
    return x


def xyz(value, label):
    if not isinstance(value, (list, tuple)) or len(value) != 3:
        raise PipetteError(label + " must contain 3 Blender-unit coordinates")
    return tuple(_number(x, label) for x in value)


def _vec(a, b):
    return tuple(b[i] - a[i] for i in range(3))


def _dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def _length(a):
    return math.sqrt(_dot(a, a))


def _dist(a, b):
    return _length(_vec(a, b))


def _normal(vector, label):
    v = xyz(vector, label)
    n = _length(v)
    if n < 1e-7:
        raise PipetteError(label + " must be a nonzero direction")
    if abs(n - 1.0) > .03:
        raise PipetteError(label + " must be approximately unit-length")
    return tuple(k / n for k in v)


def _socket(data, label, payload):
    if not isinstance(data, dict):
        raise PipetteError(label + " must be a declared socket")
    for field in ("id", "xyz", "normal", "role", "payloads", "parent_mesh"):
        if field not in data:
            raise PipetteError(label + " requires " + field)
    role = data["role"]
    if role not in ("source", "sink", "bidirectional", "anchor"):
        raise PipetteError(label + " has unrecognized socket role")
    if not isinstance(data["payloads"], list) or payload not in data["payloads"]:
        raise PipetteError(label + " is not compatible with " + payload)
    if any(not isinstance(data.get(k), str) or not data[k].strip()
           for k in ("id", "parent_mesh")):
        raise PipetteError(label + " requires nonblank socket id and parent mesh")
    return {"id":data["id"], "xyz":xyz(data["xyz"], label+".xyz"),
            "normal":_normal(data["normal"], label+".normal"),
            "role":role, "payloads":list(data["payloads"]),
            "parent_mesh":data["parent_mesh"]}


def _segment_aabb(a, b, lo, hi):
    """Finite segment / axis-aligned protected volume intersection."""
    t0, t1 = 0.0, 1.0
    for i in range(3):
        d = b[i] - a[i]
        if abs(d) < 1e-12:
            if a[i] >= lo[i] and a[i] <= hi[i]:
                continue
            return False
        u, v = (lo[i]-a[i])/d, (hi[i]-a[i])/d
        enter, leave = min(u, v), max(u, v)
        t0, t1 = max(t0, enter), min(t1, leave)
        if t0 > t1:
            return False
    return True


def _protected(data):
    result = []
    for i, region in enumerate(data or []):
        if not isinstance(region, dict):
            raise PipetteError("keep_outs entries must have minimum/maximum corners")
        lo = xyz(region.get("min"), "keep_outs.min")
        hi = xyz(region.get("max"), "keep_outs.max")
        if any(lo[j] >= hi[j] for j in range(3)):
            raise PipetteError("keep_outs must have increasing min/max corners")
        result.append({"id":region.get("id", "keep-out-"+str(i)),
                       "min":lo, "max":hi})
    return result


def _collisions(points, keepouts, radius):
    collisions = []
    for region in keepouts:
        lo = tuple(x-radius for x in region["min"])
        hi = tuple(x+radius for x in region["max"])
        for i in range(len(points)-1):
            if _segment_aabb(points[i], points[i+1], lo, hi):
                collisions.append({"keep_out_id":region["id"],
                                   "segment_index":i})
    return collisions


def _unique(points):
    result = [points[0]]
    for v in points[1:]:
        if _dist(result[-1], v) > 1e-8:
            result.append(v)
    return result


def _route(path, a, b, keepouts, radius):
    if not isinstance(path, dict):
        raise PipetteError("path must be a routing declaration")
    kind = path.get("kind")
    if kind == "straight":
        points = [a, b]
    elif kind == "waypoints":
        raw = path.get("points")
        if not isinstance(raw, list) or not 2 <= len(raw) <= MAX_POINTS:
            raise PipetteError("waypoints requires 2..256 points")
        points = [xyz(x, "path.points") for x in raw]
        if _dist(points[0], a) > 1e-5 or _dist(points[-1], b) > 1e-5:
            raise PipetteError("path endpoints must seat on the declared sockets")
    elif kind == "orthogonal":
        candidates = []
        for axes in itertools.permutations((0, 1, 2)):
            loc = list(a)
            trial = [a]
            for axis in axes:
                loc[axis] = b[axis]
                trial.append(tuple(loc))
            trial = _unique(trial)
            if len(trial) >= 2 and not _collisions(trial, keepouts, radius):
                candidates.append((len(trial), axes, trial))
        if not candidates:
            raise PipetteError("No clear orthogonal route: explicit waypoints required")
        _, _, points = min(candidates, key=lambda x:(x[0], x[1]))
    elif kind == "hanging":
        n = path.get("samples", 16)
        if not isinstance(n, int) or isinstance(n, bool) or not 4 <= n <= MAX_POINTS:
            raise PipetteError("hanging samples must be an integer 4..256")
        sag = _number(path.get("sag", 0.10), "hanging.sag")
        if sag < 0:
            raise PipetteError("hanging.sag is a nonnegative Blender unit")
        points = []
        for i in range(n+1):
            t = i/n
            p = [a[j]*(1-t)+b[j]*t for j in range(3)]
            p[2] -= 4.0*sag*t*(1-t)
            points.append(tuple(p))
    else:
        raise PipetteError("path.kind must be straight, waypoints, orthogonal or hanging")
    points = _unique(points)
    if len(points) < 2:
        raise PipetteError("route has zero geometric length")
    if len(points)>MAX_POINTS+1:
        raise PipetteError("route has too many path samples")
    hits = _collisions(points,keepouts,radius)
    if hits:
        raise PipetteError("route crosses protected volume: " +
                           ", ".join(sorted({h["keep_out_id"] for h in hits})))
    return points


def _fit_auto(family, payload):
    if family == "rebar":
        return "rebar_coupler"
    if family == "tension_cable":
        return "eye"
    if payload in ELECTRICAL:
        return "lug" if family in {"single_wire", "wire_bundle"} else "cable_gland"
    if family == "flex_hose":
        return "hose_tail"
    if family in {"rigid_pipe", "segmented_conduit"}:
        return "flange" if payload in FLUID else "compression"
    return "compression" if payload in FLUID else "cable_gland"


def _fitting(request, family, payload, terminal):
    fitting = (request.get("fittings") or {}).get(terminal, "auto")
    if fitting == "auto":
        fitting = _fit_auto(family,payload)
    if not isinstance(fitting, str) or fitting not in FITTINGS:
        raise PipetteError("invalid "+terminal+" fitting")
    if payload not in FITTINGS[fitting]:
        raise PipetteError(terminal+" fitting "+fitting+" incompatible with "+payload)
    if fitting == "none" and not request.get("allow_unterminated", False):
        raise PipetteError("open unattached line needs explicit allow_unterminated=true")
    return fitting


def _profile(spec, family):
    if not isinstance(spec, dict):
        raise PipetteError("size must be a Blender-unit size object")
    label=spec.get("visual_gauge", "regular")
    if label not in SIZE_PRESETS:
        raise PipetteError("unknown relative visual gauge "+str(label))
    diameter=_number(spec.get("outer_diameter",SIZE_PRESETS[label]),
                     "size.outer_diameter",positive=True)
    if diameter > 1.5:
        raise PipetteError("outer diameter exceeds bounded prototype scene-unit size")
    hollow=family in {"rigid_pipe","segmented_conduit","flex_hose","conduit"}
    wall=_number(spec.get("wall_fraction", .2 if hollow else 0.0),
                 "size.wall_fraction")
    if hollow and not .04<=wall<=.48:
        raise PipetteError("hollow conduit requires a wall fraction 0.04..0.48")
    if not hollow and wall != 0:
        raise PipetteError("solid wire/cable/rebar must not declare a hollow wall")
    count=spec.get("conductor_count", 1)
    if not isinstance(count,int) or isinstance(count,bool) or not 1<=count<=MAX_CONDUCTORS:
        raise PipetteError("conductor_count must be an integer 1..64")
    if family=="single_wire" and count!=1:
        raise PipetteError("single_wire always contains exactly one wire")
    if family=="wire_bundle" and count<2:
        raise PipetteError("wire_bundle requires 2 or more conductor strands")
    if count!=1 and family not in {"wire_bundle","conduit","segmented_conduit"}:
        raise PipetteError("multiple conductors only allowed inside wire bundles/conduits")
    strand_diameter=_number(spec.get("strand_diameter",diameter/max(2.,math.sqrt(count)*2.2)),
                            "size.strand_diameter",positive=True)
    if strand_diameter>diameter:
        raise PipetteError("wire core cannot exceed its outer route diameter")
    return {"outer_diameter":diameter, "outer_radius":diameter/2,
            "bore_diameter":diameter*(1-wall) if hollow else None,
            "wall_fraction":wall, "hollow":hollow,
            "visual_gauge":label, "conductor_count":count,
            "strand_diameter":strand_diameter}


def _split(points,pitch):
    sections=[]
    for start,end in zip(points,points[1:]):
        length=_dist(start,end)
        n=max(1,math.ceil(length/pitch))
        if len(sections)+n>MAX_SECTION_COUNT:
            raise PipetteError("too many sections: increase pitch or simplify route")
        for j in range(n):
            a=tuple(start[k]+(end[k]-start[k])*j/n for k in range(3))
            b=tuple(start[k]+(end[k]-start[k])*(j+1)/n for k in range(3))
            sections.append({"a":a,"b":b,"length":_dist(a,b)})
    return sections


def infer_family_candidates(source_name,properties=None):
    """Conservative classification hints: never assert a real connection."""
    text=(str(source_name)+" "+str(properties or {})).lower()
    terms={
        "rigid_pipe":r"\b(pipe|tubing|manifold|elbow|hardline)\b",
        "segmented_conduit":r"\b(segment|articulated|corrugated conduit)\b",
        "flex_hose":r"\b(hose|flex tube|rubber line)\b",
        "single_wire":r"\b(wire|lead|strand)\b",
        "wire_bundle":r"\b(bundle|loom|harness)\b",
        "conduit":r"\b(conduit|raceway|sleeve)\b",
        "tension_cable":r"\b(cable|tether|guy wire|winch line)\b",
        "rebar":r"\b(rebar|reinforcing rod)\b",
    }
    candidates=[k for k,pattern in terms.items() if re.search(pattern,text)]
    return {"source_name":source_name, "family_candidates":candidates,
            "confidence":"name-hint-only", "requires_review":True}


def plan(request):
    """Return geometry, terminals and behavior metadata without Blender side effects."""
    if not isinstance(request,dict):
        raise PipetteError("route request must be a mapping")
    family=request.get("family")
    payload=request.get("payload")
    if family not in FAMILY_PAYLOADS:
        raise PipetteError("unknown Pipette family")
    if payload not in FAMILY_PAYLOADS[family]:
        raise PipetteError("incompatible family and payload")
    name=request.get("id")
    if not isinstance(name,str) or not name.strip():
        raise PipetteError("route requires nonblank id")
    mat=request.get("material_id")
    if not isinstance(mat,str) or not mat.strip():
        raise PipetteError("material_id must refer to a specific approved Blender material")
    size=_profile(request.get("size",{}),family)
    a=_socket(request.get("start_socket"),"start_socket",payload)
    b=_socket(request.get("end_socket"),"end_socket",payload)
    if a["id"]==b["id"] or _dist(a["xyz"],b["xyz"])<1e-6:
        raise PipetteError("start and end sockets must be distinct")
    if a["role"] not in ("source","bidirectional","anchor"):
        raise PipetteError("start socket must be source, bidirectional or anchor")
    if b["role"] not in ("sink","bidirectional","anchor"):
        raise PipetteError("end socket must be sink, bidirectional or anchor")
    protected=_protected(request.get("keep_outs",[]))
    points=_route(request.get("path",{}),a["xyz"],b["xyz"],protected,size["outer_radius"])
    pitch=request.get("joint_pitch")
    if family=="segmented_conduit":
        pitch=_number(pitch,"joint_pitch",positive=True)
    elif pitch is not None:
        raise PipetteError("joint_pitch currently only supported for segmented_conduit")
    segments=_split(points,pitch if pitch else float("inf"))
    fits={end:_fitting(request,family,payload,end) for end in ("start","end")}
    notes=[]
    for end,sock,direction in (("start",a,_vec(points[0],points[1])),
                               ("end",b,_vec(points[-1],points[-2]))):
        if _dot(sock["normal"],direction)/_length(direction)<.1:
            notes.append(end+" socket facing not aligned to visible route")
    if len(segments)>128:
        notes.append("large section count may be invisible at standard Factorio camera")
    inner_geometry=bool(request.get("expose_cores",False))
    if inner_geometry and family not in {"wire_bundle","conduit","segmented_conduit"}:
        raise PipetteError("expose_cores only applies to wire bundles or populated conduits")
    if family in {"conduit","segmented_conduit"} and inner_geometry and payload not in ELECTRICAL:
        raise PipetteError("wire cores only apply when payload is electrical")
    if family=="wire_bundle" and not request.get("expose_cores",False):
        notes.append("wire conductors classified but not built where hidden by sheath")
    if family=="rebar" and request.get("size",{}).get("conductor_count",1)!=1:
        raise PipetteError("rebar is a solid reinforcement member")
    behavior=request.get("behavior",{})
    if not isinstance(behavior,dict):
        raise PipetteError("behavior must be a map of future integration IDs")
    support=request.get("supports",{})
    if not isinstance(support,dict):
        raise PipetteError("supports must be a map")
    return {
        "schema":PLAN_SCHEMA, "id":name, "family":family,"payload":payload,
        "units":"Blender scene units only; no real-world conversion",
        "size":size,"material_id":mat,"material_resolved_in_blender":False,
        "sockets":{"start":a,"end":b},
        "centerline":points, "segments":segments,
        "fittings":fits,
        "joint_locations":[sec["b"] for sec in segments[:-1]]
                          if family=="segmented_conduit" else [],
        "keep_outs":protected,
        "supports":support,
        "behavior_hooks":behavior,
        "expose_cores":inner_geometry,
        "warnings":notes,
        "provenance":"pure parametric plan; no Blender mesh or game integration",
        "approval":{"native_blender_verified":False,
                    "material_verified":False,"factorio_connected":False,
                    "owner_approved":False}
    }


def main():
    parser=argparse.ArgumentParser(description="FMPL Pipette Blender-unit route plan")
    parser.add_argument("--request",required=True)
    parser.add_argument("--output",required=True)
    args=parser.parse_args()
    target=Path(args.output).resolve()
    if target.exists():
        raise FileExistsError("refusing to overwrite an existing plan receipt")
    plan_data=plan(json.loads(Path(args.request).read_text(encoding="utf-8")))
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(plan_data,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PIPETTE_PLAN_READY",plan_data["id"],len(plan_data["segments"]))


if __name__=="__main__":
    main()
