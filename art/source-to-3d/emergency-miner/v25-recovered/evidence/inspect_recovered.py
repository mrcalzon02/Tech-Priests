import bpy,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parent
p=R/'recovered-original/emergency-miner-motion-v21/review/miner_motion_A.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
s=bpy.context.scene
report={'source':str(p.relative_to(R)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'blender':bpy.app.version_string,'scene':s.name,'frames':[s.frame_start,s.frame_end],'fps':s.render.fps,'objects':len(s.objects),'meshes':len([o for o in s.objects if o.type=='MESH']),'images':[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file),'path':i.filepath} for i in bpy.data.images],'materials':[],'animation_actions':[a.name for a in bpy.data.actions]}
for m in bpy.data.materials:
 report['materials'].append({'name':m.name,'nodes':[n.bl_idname for n in m.node_tree.nodes]if m.use_nodes else [],'animated':bool(m.node_tree and m.node_tree.animation_data)})
(R/'recovered-editable-inspection.json').write_text(json.dumps(report,indent=2))
print('RECOVERED_SOURCE_REOPENED',report['scene'],report['meshes'],'meshes',len(report['materials']),'materials')
