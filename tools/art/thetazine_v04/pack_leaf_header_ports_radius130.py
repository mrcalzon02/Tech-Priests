"""Separate two packed supply ports from existing fittings and return trunks."""
import bpy,pathlib,sys,json,hashlib,math,tempfile,ast
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();R=pathlib.Path(sys.argv[sys.argv.index('--')+2]).resolve();R.mkdir(exist_ok=False);tempfile.tempdir=str(R/'export-temp');pathlib.Path(tempfile.tempdir).mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();src=P/'thetazine-v04-regenerative-study.blend';m=json.loads((P/'source-manifest.json').read_text());assert sha(src)==m['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update();L=m['leaf_regenerative_cooling'];A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));B=Vector((0,A.z,-A.y));X=Vector((1,0,0));O=Vector((0,.35,.2));F=1.25;core=bpy.data.objects['V04 independently suspended engine core'];core_inv=core.matrix_world.inverted();q=lambda z:(O+A*z)*F;radial=lambda t:X*math.cos(t)+B*math.sin(t);point=lambda z,r,t:q(z)+radial(t)*r*F
builder=pathlib.Path(__file__).with_name('add_leaf_regenerative_cooling.py');tree=ast.parse(builder.read_text());node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='path_data');ns={'Vector':Vector,'X':X,'B':B,'math':math};exec(compile(ast.Module(body=[node],type_ignores=[]),str(builder),'exec'),ns);path_data=ns['path_data']
def ring_replace(obj,center,axis,rin,rout,length):
 n=len(obj.data.vertices)//4;assert n==20;axis=axis.normalized();seed=X if abs(axis.dot(X))<.9 else B;u=(seed-axis*seed.dot(axis)).normalized();v=axis.cross(u)
 for j,(z,r) in enumerate([(-length/2,rin),(-length/2,rout),(length/2,rout),(length/2,rin)]):
  for i in range(n):obj.data.vertices[j*n+i].co=center+axis*z+(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))*r
 obj.data.update()
for idx,degrees in [(1,23.5),(4,113.5)]:
 job=next(v for v in L['flex_links'] if v['leaf_index']==idx and v['kind']=='inlet');host=bpy.data.objects['V04 stationary regenerative supply half '+job['fluid']];tree=BVHTree.FromPolygons([host.matrix_world@v.co for v in host.data.vertices],[list(p.vertices) for p in host.data.polygons]);contact,normal,_,distance=tree.find_nearest(point(2.94,.685,math.radians(degrees)));assert distance<.005;normal.normalize();prefix=f'V04 leaf supply root union {idx:02}'
 ring_replace(bpy.data.objects[prefix+' seated stem'],contact-normal*.001,normal,.017,.021,.030);ring_replace(bpy.data.objects[prefix+' captive union'],contact+normal*.004,normal,.0165,.023,.016);ring_replace(bpy.data.objects[prefix+' host flange'],contact-normal*.002,normal,.017,.024,.012)
 job['root_rest']=list(contact+normal*.009);job['root_axis_rest']=list(normal);job['root_lead']=.06;port=next(p for p in L['ports'] if p['name']==prefix);port.update(contact_world_rest=list(contact),cap_world_rest=job['root_rest'],axis_world_rest=list(normal),port_style='Compact flush socket, positioned away from existing turbo supply coupling')
 obj=bpy.data.objects[job['mesh']];keys=obj.data.shape_keys.key_blocks
 for frame in range(65):
  s.frame_set(frame);bpy.context.view_layer.update();leaf=bpy.data.objects[job['leaf']];p0=core.matrix_world@core_inv@Vector(job['root_rest']);p3=leaf.matrix_world@Vector(job['end_local']);ax0=(core.matrix_world.to_3x3()@normal).normalized();ax1=(leaf.matrix_world.to_3x3()@A).normalized();p1=p0+ax0*.06;p2=p3-ax1*.15;pts=[p0*(1-t)**3+p1*(3*(1-t)**2*t)+p2*(3*(1-t)*t*t)+p3*t**3 for t in [i/32 for i in range(33)]];coords,_,_=path_data(pts,.016,12,True);key=keys['Basis'] if frame==0 else keys[f'Leaf cooling flex pose {frame:02}']
  for v,co in zip(key.data,coords):v.co=co
s.frame_set(0);bpy.context.view_layer.update()
for fluid,theta in [('water',math.pi/12),('fuel',math.pi+math.pi/12)]:
 p0=point(3.04,.635,theta)+radial(theta)*.045;p1=point(3.04,1.30,theta);p2=point(2.20,1.30,theta);p3=point(2.20,.685,theta)+radial(theta)*.045;pts=[p0*(1-t)**3+p1*(3*(1-t)**2*t)+p2*(3*(1-t)*t*t)+p3*t**3 for t in [i/48 for i in range(49)]];verts,faces,uv=path_data(pts,.020);obj=bpy.data.objects['V04 leaf cooling common return trunk '+fluid];assert len(verts)==len(obj.data.vertices)
 for v,co in zip(obj.data.vertices,verts):v.co=co
 layer=obj.data.uv_layers.active
 for poly,values in zip(obj.data.polygons,uv):
  for li,val in zip(poly.loop_indices,values):layer.data[li].uv=val
 obj.data.update()
s.frame_set(1);bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(R/src.name),compress=True)
for o in s.objects:o.select_set(o.type in ['MESH','EMPTY'] and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(R/'thetazine-v04-regenerative-study.glb'),use_selection=True,export_format='GLB',export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
m['native_sha256']=sha(R/src.name);m['glb_sha256']=sha(R/'thetazine-v04-regenerative-study.glb');m['leaf_header_packing_repair']={'script_sha256':sha(pathlib.Path(__file__)),'input_native_sha256':sha(src),'compact_supply_ports':[1,4],'return_trunk_control_radius':1.30,'scope':'Separate new supply takeoffs from existing turbo-feed unions and warm-return trunk paths, retaining independent coolant lanes and unchanged external interfaces.'};(R/'source-manifest.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8',newline='\n');print('LEAF_HEADER_PACKING_REPAIRED',m['native_sha256'])
