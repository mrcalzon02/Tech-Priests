#!/usr/bin/env python3
"""Blender-only API to append a design-language candidate; no donor modifications."""
import argparse
import math
import os
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from probe_source import probe

def append_greeble(source, name, *, target_box=(1,1,1), anchor=(0,0,0),
                   fit="uniform", yaw_degrees=0.0):
    """Anchor at bottom-center of a target box; all units are consuming Blender units.

    uniform retains donor aspect; stretch independently scales axes and needs review.
    This never asserts native Factorio port compatibility.
    """
    source=Path(source).expanduser().resolve()
    probe(source,verify_hash=True)
    if fit not in ("uniform","stretch"):
        raise ValueError("Only uniform or stretch fits are supported")
    if len(target_box)!=3 or any(not math.isfinite(float(v)) or v<=0 for v in target_box):
        raise ValueError("Invalid positive target box")
    if len(anchor)!=3 or any(not math.isfinite(float(v)) for v in anchor):
        raise ValueError("Invalid anchor")
    if not math.isfinite(float(yaw_degrees)):
        raise ValueError("Nonfinite yaw")
    with bpy.data.libraries.load(str(source),link=False) as (available,imported):
        if name not in available.objects:
            raise KeyError(f"Source object not found: {name}")
        imported.objects=[name]
    obj=imported.objects[0]
    if obj is None or obj.type!="MESH":
        raise ValueError("Only MESH donor candidates can be appended")
    col=bpy.data.collections.get("FMPL_Greebles")
    if col is None:
        col=bpy.data.collections.new("FMPL_Greebles")
        bpy.context.scene.collection.children.link(col)
    col.objects.link(obj)
    # Editable private mesh copy. Bake original modeling transforms only on the copy.
    transform=obj.matrix_world.copy()
    obj.parent=None
    obj.data=obj.data.copy()
    obj.data.transform(transform)
    obj.data.transform(Matrix.Rotation(math.radians(yaw_degrees),4,"Z"))
    obj.matrix_world=Matrix.Identity(4)
    corners=[Vector(p) for p in obj.bound_box]
    lo=[min(p[i] for p in corners) for i in range(3)]
    hi=[max(p[i] for p in corners) for i in range(3)]
    size=[hi[i]-lo[i] for i in range(3)]
    if any(x<=1e-8 for x in size):
        raise ValueError("Degenerate mesh: inspect manually")
    ratio=[float(target_box[i])/size[i] for i in range(3)]
    scale=[min(ratio)]*3 if fit=="uniform" else ratio
    obj.scale=scale
    obj.location=(float(anchor[0])-(lo[0]+hi[0])*scale[0]/2,
                  float(anchor[1])-(lo[1]+hi[1])*scale[1]/2,
                  float(anchor[2])-lo[2]*scale[2])
    obj["fmpl_source_id"]="greebles-drive-2026-10"
    obj["fmpl_source_object"]=name
    obj["fmpl_status"]="unreviewed-decorative-candidate"
    obj["fmpl_native_port_verified"]=False
    obj["fmpl_fit"]=fit
    return obj

def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    p=argparse.ArgumentParser()
    p.add_argument("--source",default=os.environ.get("FMPL_GREEBLES_BLEND"))
    p.add_argument("--object",required=True)
    p.add_argument("--target-box",nargs=3,type=float,required=True)
    p.add_argument("--anchor",nargs=3,type=float,default=(0,0,0))
    p.add_argument("--fit",choices=["uniform","stretch"],default="uniform")
    p.add_argument("--yaw",type=float,default=0.0)
    p.add_argument("--output",required=True)
    a=p.parse_args(args)
    if not a.source:p.error("Source path or FMPL_GREEBLES_BLEND required")
    target=Path(a.output).resolve()
    if target in {Path(a.source).resolve(),Path(bpy.data.filepath).resolve()}:
        p.error("Cannot overwrite donor or opened machine source")
    append_greeble(a.source,a.object,target_box=a.target_box,anchor=a.anchor,
                   fit=a.fit,yaw_degrees=a.yaw)
    target.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(target))
    print("FMPL_GREEBLES_APPENDED_CANDIDATE",a.object,str(target))

if __name__=="__main__":
    main()
