"""Fuse the outlet into the condenser side and grade its metal finish toward the pipe."""
import bpy,bmesh,json,math,hashlib,struct
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'condenser_v21';D.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'condenser_v20/tech_priests_water_condenser_v20.blend'))
s=bpy.context.scene
def geometry_hash(o):
 return hashlib.sha256(b''.join(struct.pack('3f',*(o.matrix_world@v.co)) for v in o.data.vertices)).hexdigest()
reference_hashes={o.name:geometry_hash(o) for o in bpy.data.collections['REFERENCE_ADJACENT_PIPES'].objects if o.type=='MESH'}
body=bpy.data.objects['Condenser right continuous side cheek'];receiver=bpy.data.objects['Water outlet chassis receiver'];neck=bpy.data.objects['Water outlet continuous hollow manifold']
# Give the root the exact existing condenser iron finish, including its texture maps.
receiver.data.materials.clear();receiver.data.materials.append(bpy.data.materials['iron'])
for v in receiver.data.vertices:v.co.x=.64+(v.co.x-.56)/.14*.13
receiver.data.update()
# Cylindrical UVs allow the root to use the same material family as the housing.
uv=receiver.data.uv_layers.new(name=body.data.uv_layers.active.name)
for p in receiver.data.polygons:
 for li in p.loop_indices:
  v=receiver.data.vertices[receiver.data.loops[li].vertex_index].co
  uv.data[li].uv=((math.atan2(v.z-.36,v.y+.5)/math.tau)%1,(v.x-.64)*2)
transition=bpy.data.materials.new('Condenser outlet body-to-pipe aged metal');transition.use_nodes=True
nodes=transition.node_tree.nodes;nodes.clear();links=transition.node_tree.links
out=nodes.new('ShaderNodeOutputMaterial');shader=nodes.new('ShaderNodeBsdfPrincipled');links.new(shader.outputs['BSDF'],out.inputs['Surface'])
geom=nodes.new('ShaderNodeNewGeometry');xyz=nodes.new('ShaderNodeSeparateXYZ');links.new(geom.outputs['Position'],xyz.inputs[0])
mapping=nodes.new('ShaderNodeMapRange');mapping.clamp=True;mapping.interpolation_type='SMOOTHERSTEP';mapping.inputs['From Min'].default_value=.70;mapping.inputs['From Max'].default_value=.95;links.new(xyz.outputs['X'],mapping.inputs['Value'])
color=nodes.new('ShaderNodeMixRGB');color.blend_type='MIX';color.inputs[1].default_value=(.067,.057,.048,1);color.inputs[2].default_value=(.31,.35,.32,1);links.new(mapping.outputs['Result'],color.inputs[0])
noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=65;noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.7;links.new(geom.outputs['Position'],noise.inputs['Vector'])
wear=nodes.new('ShaderNodeMapRange');wear.inputs['To Min'].default_value=.85;wear.inputs['To Max'].default_value=1.05;links.new(noise.outputs['Fac'],wear.inputs['Value'])
multiply=nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1;links.new(color.outputs[0],multiply.inputs[1]);links.new(wear.outputs['Result'],multiply.inputs[2]);links.new(multiply.outputs[0],shader.inputs['Base Color'])
rough=nodes.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.58;rough.inputs['To Max'].default_value=.30;links.new(mapping.outputs['Result'],rough.inputs['Value']);links.new(rough.outputs['Result'],shader.inputs['Roughness']);shader.inputs['Metallic'].default_value=.83
bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.005;links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],shader.inputs['Normal'])
transition.diffuse_color=(.22,.24,.21,1)
# Use baked UV textures for the colour/roughness ramp so GLB keeps the same finish.
import zlib
W,H=512,128
def png(path,rows):
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(b'\0'+row for row in rows),9))+chunk(b'IEND',b''))
colors=[];roughness=[]
for yy in range(H):
 row=bytearray();rrow=bytearray()
 for xx in range(W):
  x=.44+.56*xx/(W-1);t=max(0,min(1,(x-.70)/.25));t=t*t*t*(t*(t*6-15)+10)
  variation=.93+.07*math.sin(xx*.27+yy*.67)*math.sin(xx*.13-yy*.29)
  for a,b in zip((.067,.057,.048),(.31,.35,.32)):
   linear=(a*(1-t)+b*t)*variation;srgb=12.92*linear if linear<=.0031308 else 1.055*linear**(1/2.4)-.055;row.append(round(max(0,min(1,srgb))*255))
  rr=round((.58*(1-t)+.30*t)*255);rrow.extend((rr,rr,rr))
 colors.append(bytes(row));roughness.append(bytes(rrow))
png(D/'Outlet_Metal_Transition_BaseColor.png',colors);png(D/'Outlet_Metal_Transition_Roughness.png',roughness)
nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');shader=nodes.new('ShaderNodeBsdfPrincipled');links.new(shader.outputs['BSDF'],out.inputs['Surface']);shader.inputs['Metallic'].default_value=.83
uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map='OutletTransitionUV'
for filename,socket,space in [('Outlet_Metal_Transition_BaseColor.png','Base Color','sRGB'),('Outlet_Metal_Transition_Roughness.png','Roughness','Non-Color')]:
 image=bpy.data.images.load(str(D/filename));image.colorspace_settings.name=space;image.pack();tex=nodes.new('ShaderNodeTexImage');tex.image=image;links.new(uvnode.outputs['UV'],tex.inputs['Vector']);links.new(tex.outputs['Color'],shader.inputs[socket])
uv=neck.data.uv_layers.new(name='OutletTransitionUV')
for p in neck.data.polygons:
 angles=[]
 for li in p.loop_indices:
  v=neck.data.vertices[neck.data.loops[li].vertex_index].co;angles.append((math.atan2(v.z-.36,v.y+.5)/math.tau)%1)
 for li,a in zip(p.loop_indices,angles):
  v=neck.data.vertices[neck.data.loops[li].vertex_index].co
  if max(angles)-min(angles)>.5 and a<.5:a+=1
  uv.data[li].uv=((v.x-.44)/.56,a)
if transition.name not in body.data.materials:body.data.materials.append(transition)
neck.data.materials.clear()
for m in body.data.materials:neck.data.materials.append(m)
transition_index=list(body.data.materials).index(transition)
for p in neck.data.polygons:p.material_index=transition_index
# A single continuous closed wall/root/neck mesh replaces the partly buried receiver.
fused=[]
for obj in [receiver,neck]:
 obj.modifiers.clear()
 bpy.context.view_layer.objects.active=body
 mod=body.modifiers.new('Fuse cast outlet '+obj.name,'BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=obj
 while body.modifiers.find(mod.name)>0:bpy.ops.object.modifier_move_up(modifier=mod.name)
 bpy.ops.object.modifier_apply(modifier=mod.name);fused.append(obj.name);bpy.data.objects.remove(obj,do_unlink=True)
 bm=bmesh.new();bm.from_mesh(body.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 print('UNION_STAGE',fused[-1],len(bm.verts),len(bm.faces),'bad',sum(not e.is_manifold for e in bm.edges),'boundary',sum(e.is_boundary for e in bm.edges),'over',sum(len(e.link_faces)>2 for e in bm.edges),flush=True)
 bm.to_mesh(body.data);bm.free();body.data.update()
body['outlet_root_join']='Boolean union: side cheek, cast receiver, hollow pipe neck; one connected mesh'
assert any(p.material_index==transition_index for p in body.data.polygons),'Transition material must survive the geometry union'
# Keep the small gasket dark and seat it at the visible cast-root/neck shoulder.
gasket=bpy.data.objects['Water outlet receiver brass seating band']
for v in gasket.data.vertices:v.co.x+=.07
gasket.data.materials.clear();gasket.data.materials.append(bpy.data.materials['iron'])
gasket.name='Water outlet recessed dark seating gasket'
# The outer flange shares the exact adjacent collar material, rather than a similar approximation.
adjacent=bpy.data.objects['Reference pipe 0 start collar'].data.materials[0]
for name in ['Water outlet end flange','Water outlet rim inner bevel seat']:
 o=bpy.data.objects[name];o.data.materials.clear();o.data.materials.append(adjacent)
bpy.context.view_layer.update()
bm=bmesh.new();bm.from_mesh(body.data);bad=sum(not e.is_manifold for e in bm.edges)
visited=set();components=0
for v in bm.verts:
 if v in visited:continue
 components+=1;stack=[v];visited.add(v)
 while stack:
  w=stack.pop()
  for e in w.link_edges:
   x=e.other_vert(w)
   if x not in visited:visited.add(x);stack.append(x)
bm.free();assert bad==0 and components==1,(bad,components)
def interface(o):
 return sorted(tuple(round(c,6) for c in o.matrix_world@v.co) for v in o.data.vertices if abs((o.matrix_world@v.co).x-1)<1e-5)
left=interface(body);right=interface(bpy.data.objects['Reference pipe 0 barrel'])
join_error=max(min((Vector(a)-Vector(b)).length for b in right) for a in left)
joint=len(left)==len(right) and join_error<1e-5
print('JOIN_RING',len(left),len(right),join_error,flush=True);assert joint
assert all(geometry_hash(bpy.data.objects[n])==h for n,h in reference_hashes.items())
report={'revision':'V21','scope':'Properly fuse side outlet into housing and transition body finish to adjacent pipe metal','fused_parts':fused,'joined_mesh':body.name,'joined_mesh_connected_components':components,'joined_mesh_nonmanifold_edges':bad,'join_plane_matches_adjacent_barrel':joint,'join_ring_max_error_tiles':join_error,'pipe_mouth_blender':[1,-.5,.36],'tile_footprint':[2,2],'adjacent_reference_geometry_unchanged':True,'reference_hashes':reference_hashes,'root_material':'Existing iron material shared with condenser housing','neck_finish':'Warm dark housing iron at X=.70, graded to adjacent silver/green steel by X=.95; fine mottled wear and roughness transition','outer_flange_material_is_adjacent_collar_material':bpy.data.objects['Water outlet end flange'].data.materials[0]==adjacent,'native_and_glb_validation':'Pending reopen/readback','runtime_validation':'Not performed; model revision only'}
(D/'Condenser_V21_Validation.json').write_text(json.dumps(report,indent=2))
s['asset_revision']='V21 integrated cast side outlet and body-to-pipe metal transition';s.camera=bpy.data.objects['PIPE_FIT_OBLIQUE'];s.cycles.samples=32
for o in s.objects:o.select_set(False)
for o in s.objects:
 if o.type=='MESH' and (o.parent and o.parent.name=='CONDENSER_TILE_CALIBRATION' or o.name.startswith('Water outlet')):o.select_set(True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_water_condenser_v21.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(D/'tech_priests_water_condenser_v21.glb'),export_format='GLB',use_selection=True,export_apply=True)
for camera,label in [('PIPE_FIT_OBLIQUE','Oblique'),('PIPE_FIT_GAME_CAMERA_45_DEGREES','Game_View')]:
 s.camera=bpy.data.objects[camera];s.render.filepath=str(D/('Condenser_V21_'+label+'.png'));bpy.ops.render.render(write_still=True)
print('V21_COMPLETE',json.dumps(report),flush=True)
