import bpy,json,hashlib,struct
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'boiler_tubing_audit';D.mkdir(exist_ok=True)
def capture(path):
 bpy.ops.wm.open_mainfile(filepath=str(path))
 if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update();items={}
 for o in s.objects:
  if o.type!='MESH' or o.name.startswith('V08 nozzle steam'):continue
  mods=[]
  for m in o.modifiers:mods.append({'name':m.name,'type':m.type,'render':m.show_render})
  mats=[]
  for m in o.data.materials:
   if not m:continue
   mats.append({'name':m.name,'surface_render_method':getattr(m,'surface_render_method',None),'nodes':[{'name':n.name,'type':n.type,'alpha':float(n.inputs['Alpha'].default_value) if n.type=='BSDF_PRINCIPLED' else None,'transmission':float(n.inputs['Transmission Weight'].default_value) if n.type=='BSDF_PRINCIPLED' else None} for n in m.node_tree.nodes if n.type in ['BSDF_TRANSPARENT','MIX_SHADER','BSDF_PRINCIPLED']] if m.use_nodes else []})
  items[o.name]={'hash':hashlib.sha256(b''.join(struct.pack('3f',*v.co) for v in o.data.vertices)).hexdigest(),'world':[[float(v) for v in row] for row in o.matrix_world],'hidden':o.hide_render,'collection_hidden':any(c.hide_render for c in o.users_collection),'materials':mats,'modifiers':mods}
 lights={o.name:{'type':o.data.type,'energy':o.data.energy,'world':[[float(v) for v in row] for row in o.matrix_world]} for o in s.objects if o.type=='LIGHT'}
 return {'objects':items,'lights':lights,'world':[(n.type,n.name) for n in s.world.node_tree.nodes] if s.world and s.world.use_nodes else [],'color_management':{'view_transform':s.view_settings.view_transform,'look':s.view_settings.look,'exposure':s.view_settings.exposure,'gamma':s.view_settings.gamma}}
a=capture(R/'upload/tech_priests_emergency_boiler_v07b.blend');b=capture(R/'boiler_v08/tech_priests_emergency_boiler_v08_animated.blend')
diff=[]
for name,x in a['objects'].items():
 y=b['objects'].get(name)
 if not y:diff.append({'name':name,'missing':True});continue
 changes={k:[x[k],y[k]] for k in ['hash','hidden','collection_hidden','modifiers'] if x[k]!=y[k]}
 error=max(abs(p-q) for xr,yr in zip(x['world'],y['world']) for p,q in zip(xr,yr))
 if error>1e-5:changes['world_error']=error
 if changes:diff.append({'name':name,'changes':changes})
tubes={n:y for n,y in b['objects'].items() if any(t in n.lower() for t in ['tube','pipe','feed','connection','return','coupling','union'])}
out={'source':a,'animated':b,'changes':diff,'tube_objects':tubes,'lights_identical':a['lights']==b['lights'],'color_management_identical':a['color_management']==b['color_management']}
(D/'Tubing_Audit.json').write_text(json.dumps(out,indent=2));print('CHANGES',diff);print('TUBES',list(tubes));print('LIGHTS_IDENTICAL',out['lights_identical'],'COLOR_IDENTICAL',out['color_management_identical'])
