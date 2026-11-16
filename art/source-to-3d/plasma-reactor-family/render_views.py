"""Photograph the finished assets in Blender, using the family studio scene."""
import sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from build_family import NAMES,VIEW,frame

def render():
    args=sys.argv[sys.argv.index('--')+1:]
    out=Path(args[0]).resolve();out.mkdir(parents=True,exist_ok=True)
    mode=args[1]
    s=bpy.context.scene
    groups=[bpy.data.collections[n] for n in NAMES]
    models=[o for g in groups for o in g.objects if o.type=='MESH']
    def snap(filename,objs,view,w,h,samples,margin):
        frame(objs,view,w,h,margin)
        s.cycles.samples=samples
        s.render.filepath=str(out/(filename+'.png'))
        bpy.ops.render.render(write_still=True)
    if mode=='preview':
        snap('family-preview',models,VIEW,1310,550,8,1.055)
        return
    if mode=='family':
        snap('family-hero',models,VIEW,2600,1060,54,1.055)
        return
    for i,g in enumerate(groups):
        if mode not in ('all',NAMES[i]): continue
        for other in groups: other.hide_render=(g!=other)
        pivot=next(o for o in g.objects if o.type=='EMPTY');pivot.location=(0,0,0)
        bpy.context.view_layer.update()
        objs=[o for o in g.objects if o.type=='MESH']
        snap(NAMES[i]+'-front',objs,VIEW,1456,1152,42,1.11)
        snap(NAMES[i]+'-rear',objs,Vector((-.75,1.0,.59)),1184,985,32,1.10)
if __name__=='__main__': render()
