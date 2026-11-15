import bpy,sys,json
from pathlib import Path
from mathutils import Vector
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);bpy.ops.wm.open_mainfile(filepath=str(source))
report={'collections':[c.name for c in bpy.data.collections],'objects':[]}
for obj in bpy.context.scene.objects:
    report['objects'].append({'name':obj.name,'type':obj.type,'hide_render':obj.hide_render,
       'materials':[m.name for m in obj.data.materials if m] if obj.type=='MESH' else [],
       'parent':obj.parent.name if obj.parent else None,'location':list(obj.matrix_world.translation)})
out.write_text(json.dumps(report,indent=2)+'\n')
