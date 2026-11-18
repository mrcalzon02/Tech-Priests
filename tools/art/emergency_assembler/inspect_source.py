"""Read the supplied V07 scene without evaluating embedded scripts."""
import bpy, hashlib, json, sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/source-to-3d/emergency-assembler/v07'
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
def bounds(obj):
    if obj.type not in {'MESH','CURVE','FONT','SURFACE','META'}:return None
    corners=[obj.matrix_world@Vector(p) for p in obj.bound_box]
    return [[min(p[i] for p in corners) for i in range(3)],
            [max(p[i] for p in corners) for i in range(3)]]
report={'blend':bpy.data.filepath,'sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),
 'scene':scene.name,'frame_start':scene.frame_start,'frame_end':scene.frame_end,
 'fps':scene.render.fps,'fps_base':scene.render.fps_base,'frame_current':scene.frame_current,
 'engine':scene.render.engine,'camera':scene.camera.name if scene.camera else None,
 'render':[scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage],
 'world':scene.world.name if scene.world else None,
 'objects':[{'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,
             'hide_render':o.hide_render,'location':list(o.location),'rotation':list(o.rotation_euler),
             'scale':list(o.scale),'bounds':bounds(o),'data':o.data.name if o.data else None,
             'materials':[m.name if m else None for m in o.data.materials] if o.type=='MESH' else [],
             'animated':bool(o.animation_data)} for o in scene.objects],
 'images':[{'name':i.name,'path':i.filepath,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images],
 'actions':[{'name':a.name,'frame_range':list(a.frame_range)} for a in bpy.data.actions],
 'texts':[t.name for t in bpy.data.texts], 'markers':[{ 'name':m.name,'frame':m.frame } for m in scene.timeline_markers],
 'camera_data':{'type':scene.camera.data.type,'ortho_scale':scene.camera.data.ortho_scale} if scene.camera else None}
(OUT/'source-inspection.json').write_text(json.dumps(report,indent=2)+'\n')
for i,t in enumerate(bpy.data.texts): (OUT/f'embedded-text-{i:02d}.txt').write_text(t.as_string())
print('ASSEMBLER_INSPECTION',json.dumps({k:report[k] for k in ['sha256','frame_start','frame_end','fps','frame_current','engine','camera','texts','markers']}))
print('OBJECTS',len(report['objects']),'IMAGES',len(report['images']),'ACTIONS',len(report['actions']))
