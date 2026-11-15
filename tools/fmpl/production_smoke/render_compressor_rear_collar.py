"""Render the actual rear collar as a separate joint-depth layer."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from compressor_native_fittings import CompressorNativeFittings
from refine_purifier_v14 import sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--capture',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.capture).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Retain seam-layer studies')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(root/'master.blend'))
    s=bpy.data.scenes['RENDER'];bpy.context.window.scene=s;s.frame_set(1);fit=CompressorNativeFittings(s);pivot=s.objects['EXPORT | direction pivot'];records=[]
    for direction,angle,role in (('east',270,'hydrogen_suction'),('west',90,'hydrogen_discharge')):
        pivot.rotation_euler.z=math.radians(angle);fit.apply(angle);bpy.context.view_layer.update()
        selected=[o for o in fit.groups[role] if 'reusable machine collar' in o.name or 'actual flange bolt' in o.name]
        if len(selected)!=9:raise RuntimeError('Expected only the existing collar and eight retaining heads')
        for o in s.objects:
            if o.type=='MESH':o.visible_camera=o in selected
        s.render.filepath=str(out/('rear-collar-'+direction+'.png'));bpy.ops.render.render(write_still=True)
        records.append(dict(direction=direction,angle=angle,role=role,actual_meshes=[o.name for o in selected],sha256=sha(s.render.filepath)))
    (out/'seam-layer-receipt.json').write_text(json.dumps(dict(master_sha256=sha(root/'master.blend'),layers=records,
        method='Actual collar-only camera visibility, full scene retained for lighting/shadow rays. Static joint depth layer; no pixel-painted replacement, body stretch or new neck geometry.'),indent=2)+'\n')


if __name__=='__main__':main()
