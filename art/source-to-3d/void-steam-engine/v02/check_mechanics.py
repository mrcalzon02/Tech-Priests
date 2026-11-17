"""Measured joint closure and guide engagement in source and independent runtime."""
import bpy,json,math,sys,struct,hashlib
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
rows=[]
for mode in ('source','runtime'):
 p=O/('void-steam-v02.blend' if mode=='source' else 'void-steam-v02.glb')
 if mode=='source':bpy.ops.wm.open_mainfile(filepath=str(p));first=0
 else:
  b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);first=min(g['accessors'][x['input']]['min'][0] for a in g['animations'] for x in a['samplers'])
  bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(p))
 s=bpy.context.scene;max_joint=0;max_rodlength=0;min_engagement=1;max_axial=0;max_pressurecap=0;fixed=[]
 for i in range(385):
  f=1+i/2;t=f if mode=='source' else (first+(f-1)/48)*48;s.frame_set(math.floor(t),subframe=t%1);bpy.context.view_layer.update()
  c=bpy.data.objects['VOID | common rotating crank']
  for sign,side in ((-1,'left'),(1,'right')):
   r=bpy.data.objects['VOID | '+side+' rigid connecting rod'];q=bpy.data.objects['VOID | '+side+' guided crosshead']
   lower=r.matrix_world@Vector((0,0,0));upper=r.matrix_world@Vector((0,0,.46));wrist=q.matrix_world@Vector((0,0,0));pin=c.matrix_world@Vector((sign*.665,0,sign*.15))
   max_joint=max(max_joint,(lower-pin).length,(upper-wrist).length)
   max_rodlength=max(max_rodlength,abs((upper-lower).length-.46))
   max_axial=max(max_axial,abs(wrist.x-sign*.665),abs(wrist.y-.16))
   stem_low=q.matrix_world@Vector((0,0,.070));stem_top=q.matrix_world@Vector((0,0,.560))
   min_engagement=min(min_engagement,stem_top.z-1.32,1.24-stem_low.z)
   max_pressurecap=max(max_pressurecap,stem_top.z)
  socket=bpy.data.objects['VOID | STEAM full-bore fixed mouth'];fixed.append([list(row) for row in socket.matrix_world])
 # Runtime is glTF Y-up converted by importer into the same native author coordinates.
 stationary=max(abs(fixed[i][a][b]-fixed[0][a][b]) for i in range(len(fixed)) for a in range(4) for b in range(4))
 r={'artifact':mode,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'poses':385,'includes_half_frames':True,'maximum_pin_joint_error_tiles':max_joint,'maximum_rigid_rod_length_error_tiles':max_rodlength,'maximum_piston_coaxial_error_tiles':max_axial,'minimum_stem_overlap_beyond_both_guide_ends_tiles':min_engagement,'maximum_stem_top_z':max_pressurecap,'fixed_socket_matrix_variation':stationary,'piston_radial_guide_clearance_tiles':.005,'pin_eye_radial_clearance_tiles':.003,'rod_to_inner_crank_web_axial_clearance_tiles':.013,'rod_to_outer_crank_web_axial_clearance_tiles':.018}
 r['passed']=max_joint<.001 and max_rodlength<1e-6 and max_axial<1e-6 and min_engagement>.04 and max_pressurecap<1.79 and stationary<1e-7
 rows.append(r);assert r['passed'],r
(O/'mechanical-inspection.json').write_text(json.dumps({'passed':all(r['passed'] for r in rows),'artifacts':rows,'clearance_triangle_contacts_separately_adjudicated':False},indent=2)+'\n')
print('VOID_MECHANICAL_PASS',json.dumps(rows),flush=True)
