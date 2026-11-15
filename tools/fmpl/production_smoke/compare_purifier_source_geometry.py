"""Read two real scenes and locate exact inherited source digest differences."""
import json
from pathlib import Path
import sys
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_process import hash_original_meshes
args=sys.argv[sys.argv.index('--')+1:]
records=[]
for path in args[:2]:
    bpy.ops.wm.open_mainfile(filepath=str(Path(path).resolve())); bpy.context.scene.frame_set(25)
    bpy.context.view_layer.update()
    rows={o.name:dict(hash=hash_original_meshes([o]),matrix=[list(r) for r in o.matrix_world],parent=o.parent.name if o.parent else None)
          for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(('MH7_','FMPL_PROCESS |'))}
    records.append(rows)
differences={n:dict(before=records[0].get(n),after=records[1].get(n)) for n in set(records[0])|set(records[1]) if records[0].get(n)!=records[1].get(n)}
Path(args[2]).write_text(json.dumps(differences,indent=2)+'\n')
print('INHERITED_GEOMETRY_DIFFERENCES',len(differences))
