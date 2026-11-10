#!/usr/bin/env python3
"""FMPL scene-to-Factorio-tile scope, pure Python and dimensionless.

Ordinary linework remains directly sized in Blender units. Canonical Factorio
pipe-flange fixture dimensions are stored separately as proportions of the
explicit machine tile footprint. Never infer a native Factorio fluidbox cell
from a Blender mouth or convert millimeters/AWG/real-world units.
"""
from __future__ import annotations
import math

SCHEMA="fmpl.scene-scope.v1"
PIPE_STANDARD_ID="factorio-fluid-interface-v1"
PIPE_STANDARD_TILES={
    "barrel_outer_diameter":.57,
    "open_bore_diameter":.49,
    "mounting_collar_outer_diameter":.68,
    "mounting_collar_axial_thickness":.075,
}
FACE_NORMALS={
    "west":(-1.,0.,0.),
    "east":(1.,0.,0.),
    "south":(0.,-1.,0.),
    "north":(0.,1.,0.),
}
POSITION_TOLERANCE_TILES=.015
NORMAL_TOLERANCE_DEG=5.0


class SceneScaleError(ValueError):
    """Invalid or ambiguous machine scene scope and standard port reference."""


def _number(value,label,positive=False):
    if isinstance(value,bool) or not isinstance(value,(int,float)):
        raise SceneScaleError(label+" must be a numeric scene unit/tile fraction")
    v=float(value)
    if not math.isfinite(v) or (positive and v<=0):
        raise SceneScaleError(label+" must be finite and positive")
    return v


def _xyz(value,label):
    if not isinstance(value,(tuple,list)) or len(value)!=3:
        raise SceneScaleError(label+" must have three Blender scene coordinates")
    return tuple(_number(v,label) for v in value)


def resolve_scope(data):
    """Normalize the explicit tile-footprint reference for one model scene.

    A 2x2 body has boundaries X/Y +/-1 tile from its model origin, a 3x3 body
    has boundaries +/-1.5 tile. scene_units_per_tile may differ per scene.
    Elevation and transverse offsets of ports are ALWAYS explicit.
    """
    if not isinstance(data,dict):
        raise SceneScaleError("scene_scope must be a versioned mapping")
    if data.get("schema")!=SCHEMA:
        raise SceneScaleError("scene_scope.schema must be "+SCHEMA)
    ref=data.get("id")
    if not isinstance(ref,str) or not ref.strip():
        raise SceneScaleError("scene_scope.id must be nonempty")
    u=_number(data.get("scene_units_per_tile"),"scene_units_per_tile",positive=True)
    if u<.001 or u>100:
        raise SceneScaleError("scene_units_per_tile outside bounded authored range .001..100")
    footprint=data.get("footprint_tiles")
    if (not isinstance(footprint,list) or len(footprint)!=2 or
        any(isinstance(n,bool) or not isinstance(n,int) or not 1<=n<=64 for n in footprint)):
        raise SceneScaleError("footprint_tiles must be a two-element [width,height] integer list")
    origin=_xyz(data.get("origin_bu"),"origin_bu")
    up=data.get("up_axis","+Z")
    if up!="+Z":
        raise SceneScaleError("FMPL canonical tile-scoped profiles use +Z")
    w,h=footprint
    return {
        "schema":SCHEMA,"id":ref,
        "scene_units_per_tile":u,
        "footprint_tiles":[w,h],
        "origin_bu":origin,
        "up_axis":"+Z",
        "XY_min_bu":(origin[0]-w*u/2,origin[1]-h*u/2),
        "XY_max_bu":(origin[0]+w*u/2,origin[1]+h*u/2),
        "canonical_pipe_standard_id":PIPE_STANDARD_ID,
        "native_factorio_fluidbox_verified":False,
        "reference_status":"scene geometry only; not game-port proof"
    }


def to_blender_units(tile_fraction,scope):
    """Only explicit game-tile proportions are converted, never real-world."""
    return _number(tile_fraction,"tile_fraction")*scope["scene_units_per_tile"]


def to_tile_fraction(scene_units,scope):
    return _number(scene_units,"scene_units")/scope["scene_units_per_tile"]


def standard_pipe(scope):
    if scope.get("schema")!=SCHEMA:
        raise SceneScaleError("standard pipe needs an explicit scene scope")
    dims={k+"_bu":to_blender_units(v,scope)
          for k,v in PIPE_STANDARD_TILES.items()}
    dims["id"]=PIPE_STANDARD_ID
    dims["tile_dimensions"]=dict(PIPE_STANDARD_TILES)
    dims["native_geometry_source_required"]=True
    dims["installed_factorio_fluidbox_proven"]=False
    return dims


def _vector_normal(value,label):
    p=_xyz(value,label)
    magnitude=math.sqrt(sum(x*x for x in p))
    if magnitude<1e-7 or abs(magnitude-1.)>.03:
        raise SceneScaleError(label+" must be unit length")
    return tuple(x/magnitude for x in p)


def port_center(scope,face,transverse_offset_tiles,elevation_tiles):
    if face not in FACE_NORMALS:
        raise SceneScaleError("port face must be north/south/east/west")
    t=to_blender_units(transverse_offset_tiles,scope)
    z=to_blender_units(elevation_tiles,scope)
    origin=scope["origin_bu"]
    w,h=scope["footprint_tiles"]
    u=scope["scene_units_per_tile"]
    if face=="west":
        if abs(transverse_offset_tiles)>h/2:
            raise SceneScaleError("port transverse offset outside footprint")
        return (origin[0]-w*u/2,origin[1]+t,origin[2]+z)
    if face=="east":
        if abs(transverse_offset_tiles)>h/2:
            raise SceneScaleError("port transverse offset outside footprint")
        return (origin[0]+w*u/2,origin[1]+t,origin[2]+z)
    if abs(transverse_offset_tiles)>w/2:
        raise SceneScaleError("port transverse offset outside footprint")
    if face=="south":
        return (origin[0]+t,origin[1]-h*u/2,origin[2]+z)
    return (origin[0]+t,origin[1]+h*u/2,origin[2]+z)


def verify_port(socket,interface,scope):
    """Check an explicitly declared model-space port against a tile boundary.

    The standard fitting proportions are independent of 2x2/3x3 footprint;
    footprint defines *where* the machine boundary is. Never infer actual
    Factorio fluidbox or assume a unique port offset.
    """
    if not isinstance(interface,dict):
        raise SceneScaleError("tile_interface must be an explicit mapping")
    if interface.get("standard_id")!=PIPE_STANDARD_ID:
        raise SceneScaleError("unrecognized standard pipe fitting profile")
    face=interface.get("face")
    t=_number(interface.get("transverse_offset_tiles"),
              "tile_interface.transverse_offset_tiles")
    z=_number(interface.get("elevation_tiles"),"tile_interface.elevation_tiles")
    center=port_center(scope,face,t,z)
    actual=_xyz(socket["xyz"],"socket.xyz")
    normal=_vector_normal(socket["normal"],"socket.normal")
    dist=math.sqrt(sum((center[k]-actual[k])**2 for k in range(3)))
    maximum=POSITION_TOLERANCE_TILES*scope["scene_units_per_tile"]
    if dist>maximum:
        raise SceneScaleError("socket is not seated on the declared tile-boundary port")
    expected=FACE_NORMALS[face]
    dot=sum(normal[k]*expected[k] for k in range(3))
    if dot<math.cos(math.radians(NORMAL_TOLERANCE_DEG)):
        raise SceneScaleError("socket outward normal does not face its tile boundary")
    return {
        "standard_id":PIPE_STANDARD_ID,
        "face":face,
        "transverse_offset_tiles":t,
        "elevation_tiles":z,
        "expected_xyz_bu":center,
        "position_error_bu":dist,
        "outer_normal":expected,
        "dimensions":standard_pipe(scope),
        "requires_reducing_adapter":True,
        "native_factorio_fluidbox_verified":False,
        "model_port_verified":True
    }
