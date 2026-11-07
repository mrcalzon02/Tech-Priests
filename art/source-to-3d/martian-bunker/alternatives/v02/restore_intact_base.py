"""Refit unchanged turret entities to the intact, pre-split M2 bunker.
Run from materialized martian_bunker_M2_paving_v6.blend.
"""
import bpy,json,sys,hashlib,math
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update()
comparison=json.loads((O/'source_comparison.json').read_text());signatures=comparison['correct_base_signature'];base_objs=[bpy.data.objects[name] for name in signatures]
# Preserve intact base objects and their live material graphs; discard the old cannon.
for o in list(S.objects):
 if o not in base_objs and o.type not in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
base=bpy.data.collections.new('EXISTING_BUNKER_BASE_UNCHANGED');S.collection.children.link(base)
for o in base_objs:
 for c in list(o.users_collection):c.objects.unlink(o)
 base.objects.link(o)
for col in list(bpy.data.collections):
 if col!=base and not col.objects and not col.children:bpy.data.collections.remove(col)
S.use_nodes=False;S.render.use_compositing=False;S.render.use_sequencer=False;S.render.engine='CYCLES';S.cycles.samples=24;S.cycles.device='CPU';S.cycles.use_denoising=True
S.render.resolution_x=S.render.resolution_y=1000;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
S.camera.animation_data_clear();S.camera.data.animation_data_clear()
S.world.use_nodes=True;bg=S.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.16,.18,.22,1);bg.inputs['Strength'].default_value=.4
for vl in S.view_layers:vl.use=True
for o in S.objects:
 if o.type=='LIGHT':o.hide_render=False

def camera(pos,target,scale):
 S.camera.location=pos;S.camera.rotation_euler=(Vector(target)-S.camera.location).to_track_quat('-Z','Y').to_euler();S.camera.data.type='ORTHO';S.camera.data.ortho_scale=scale

def verify_base():
 bpy.context.view_layer.update()
 for o in base_objs:
  spec=signatures[o.name]
  assert hashlib.sha256(repr([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest()==spec['mesh'],o.name
  assert max(abs(o.matrix_world[i][j]-spec['matrix'][i][j]) for i in range(4) for j in range(4))<1e-6,o.name
verify_base();camera((5,-7,5.5),(0,0,1.85),5.5);S.render.filepath=str(O/'Intact_Source_Base_Control.png');bpy.ops.render.render(write_still=True)
report={'stage':'V02 base restoration','source':'martian_bunker_M2_paving_v6.blend','base_mesh_count':len(base_objs),'source_base_signature':signatures,'previous_source_had_misplaced_parts':comparison['misplaced_base_parts'],'variants':{}}
for variant in ['energy_dish','grenade_lobber_12']:
 with bpy.data.libraries.load(str(O/(variant+'_entity.blend')),link=False) as (src,dst):dst.collections=[variant.upper()]
 col=dst.collections[0];S.collection.children.link(col);base.hide_render=False
 verify_base();camera((5,-7,5.5),(0,0,1.85),5.5);S['variant']=variant;S['stage']='V02 restored intact M2 bunker base'
 for _ in range(3):bpy.ops.outliner.orphans_purge(do_recursive=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(O/(variant+'_v02.blend')),compress=True)
 for view,pos,target,scale,base_visible in [('mounted',(5,-7,5.5),(0,0,1.85),5.5,True),('turret',(5,-7,5.5),(0,0,2.65),3.5,False),('front',(0,-8,3.5),(0,0,2.65),3.3,False),('rear',(-5,7,5.5),(0,0,2.65),3.5,False)]:
  base.hide_render=not base_visible;camera(pos,target,scale);S.render.filepath=str(O/(variant+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
 base.hide_render=False;camera((5,-7,5.5),(0,0,1.85),5.5);col.hide_render=True;S.render.filepath=str(O/(variant+'_Base_Preservation_Check.png'));bpy.ops.render.render(write_still=True);col.hide_render=False
 verify_base();meshes=[o for o in col.objects if o.type=='MESH'];report['variants'][variant]={'base_geometry_world_matrices_match_independent_intact_source':True,'mesh_count':len(meshes),'grenade_tubes':len([o for o in meshes if o.name.startswith('GRENADE_TUBE')]),'standalone_entity_sha256_unchanged':hashlib.sha256((O/(variant+'_entity.blend')).read_bytes()).hexdigest()}
 for o in list(col.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(col)
(O/'build_validation.json').write_text(json.dumps(report,indent=2));print('RESTORED_INTACT_BASE_PASS',flush=True)
