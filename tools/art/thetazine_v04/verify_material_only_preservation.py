"""Prove both native scenes have identical evaluated geometry at every pose."""
import bpy,pathlib,sys,json,hashlib,struct
from mathutils import Vector
before=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();after=pathlib.Path(sys.argv[sys.argv.index('--')+2]).resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(root):
 bpy.ops.wm.open_mainfile(filepath=str(root/'thetazine-v04-regenerative-study.blend'));s=bpy.context.scene;rows=[]
 for f in range(66):
  s.frame_set(f);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();h=hashlib.sha256();count=0
  for o in sorted(s.objects,key=lambda o:o.name):
   if o.type not in ['MESH','EMPTY']:continue
   h.update(o.name.encode());h.update(struct.pack('<16f',*(v for row in o.matrix_world for v in row)))
   if o.type=='MESH':
    ev=o.evaluated_get(dg);me=ev.to_mesh();h.update(struct.pack('<I',len(me.vertices)))
    for v in me.vertices:h.update(struct.pack('<3f',*v.co))
    ev.to_mesh_clear();count+=1
  rows.append({'frame':f,'evaluated_geometry_and_transform_sha256':h.hexdigest(),'meshes_including_render_volume':count})
 return rows
a=snapshot(before);b=snapshot(after);assert a==b,'Material-only change altered evaluated geometry or transforms'
result={'status':'PASS_EXACT_NATIVE_GEOMETRY_AND_TRANSFORMS_66_POSES','before_native_sha256':sha(before/'thetazine-v04-regenerative-study.blend'),'native_sha256':sha(after/'thetazine-v04-regenerative-study.blend'),'poses':a,'scope':'Exact object transforms and evaluated mesh vertices, including all hose morphs/core/physical meshes and render-only volume. Baseline20 seated-route/clearance evidence remains attributable to baseline20; unchanged geometry proves preservation without pretending to rerun collision audits.'};(after/'material-only-preservation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print(result['status'])
