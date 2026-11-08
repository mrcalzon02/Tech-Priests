"""Render the actual geometry's parallel-light shadow on the platform plane."""
import bpy,pathlib,sys,json,hashlib
from mathutils import Vector
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();bpy.ops.wm.open_mainfile(filepath=str(r/'hydrogen-thruster-v01.blend'));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();direction=Vector((4,6,-8));floor=-.001;vertices=[];faces=[]
def clip(poly):
 out=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  ain=a.z>=floor;bin=b.z>=floor
  if ain:out.append(a)
  if ain!=bin:out.append(a+(b-a)*((floor-a.z)/(b.z-a.z)))
 return out
casters=0
for o in list(s.objects):
 if o.type!='MESH':continue
 ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles()
 for t in m.loop_triangles:
  poly=clip([o.matrix_world@m.vertices[i].co for i in t.vertices])
  if len(poly)<3:continue
  pts=[v+direction*((floor-v.z)/direction.z) for v in poly]
  if (pts[1]-pts[0]).cross(pts[2]-pts[0]).length<1e-12:continue
  start=len(vertices);vertices.extend(pts);faces.append(tuple(range(start,start+len(pts))))
 casters+=1;ev.to_mesh_clear()
for o in list(s.objects):
 if o.type in ['MESH','LIGHT']:o.hide_render=True
mesh=bpy.data.meshes.new('Actual clipped directional shadow triangles');mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(mesh.name,mesh);s.collection.objects.link(o)
mat=bpy.data.materials.new('Exact black shadow matte');mat.use_nodes=True;nt=mat.node_tree;nt.nodes.clear();em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(0,0,0,1);output=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(em.outputs[0],output.inputs['Surface']);o.data.materials.append(mat)
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0;s.render.resolution_x=768;s.render.resolution_y=1024;s.camera.data.ortho_scale=12;s.cycles.samples=8;s.cycles.use_denoising=False;s.render.filepath=str(r/'projected-shadow.png');bpy.ops.render.render(write_still=True)
(r/'projected-shadow-receipt.json').write_text(json.dumps({'status':'RENDERED_REQUIRES_ALPHA_REVIEW','native_model_sha256':hashlib.sha256((r/'hydrogen-thruster-v01.blend').read_bytes()).hexdigest(),'file':'projected-shadow.png','sha256':hashlib.sha256((r/'projected-shadow.png').read_bytes()).hexdigest(),'method':'Actual source triangles clipped to z >= platform plane, projected along parallel sunlight onto that plane, then rendered as a black matte with the unchanged camera. Not a painted or guessed shadow.','caster_meshes':casters,'projected_faces':len(faces),'light_travel_direction':list(direction),'platform_plane_z':floor,'cell':[768,1024],'ortho_scale':12,'pixels_per_model_unit':1024/12,'native_scale':.375,'native_shift':'same as body; identical optical axis and pixels per model unit','rejected_method':'Cycles shadow-catcher passes retain nonzero low-alpha image-border noise and are not used.'},indent=2)+'\n',encoding='utf-8');print('PROJECTED_SHADOW_RENDERED',len(faces))
