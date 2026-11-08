import bpy,json,hashlib,sys,argparse,math
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--candidate',type=Path,required=True);p.add_argument('--source',type=Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);O=a.candidate.resolve();report=json.loads((O/'cleanup-validation.json').read_text())
def metrics():
    rows=[];pts=[];tri=0;bad=0
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or not any(c.name=='SIX_LOBBER_LOOSE_GRENADE_LOADERS' for c in o.users_collection):continue
        me=bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get());me.calc_loop_triangles();pp=[o.matrix_world@v.co for v in me.vertices];assert all(math.isfinite(x) for v in pp for x in v)
        n=sum((pp[t.vertices[1]]-pp[t.vertices[0]]).cross(pp[t.vertices[2]]-pp[t.vertices[0]]).length<1e-12 for t in me.loop_triangles)
        rows.append({'object':o.name,'triangles':len(me.loop_triangles),'degenerate_triangles':n,'uv_layers':len(me.uv_layers)});pts+=pp;bad+=n;tri+=len(me.loop_triangles);bpy.data.meshes.remove(me)
    return {'mesh_count':len(rows),'triangles':tri,'degenerate_triangles':bad,'bounds':[[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]],'meshes':rows}
def render(name,pos=(0,-7,9),clay=False):
    S=bpy.context.scene;cam=S.camera;cam.location=pos;cam.rotation_euler=(Vector((0,0,2.75))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.2
    S.render.engine='CYCLES';S.cycles.samples=16;S.cycles.seed=5855;S.cycles.use_denoising=True;S.render.resolution_x=S.render.resolution_y=640;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
    if clay:
        m=bpy.data.materials.new('V16 neutral clay');m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.35,.35,.35,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;S.view_layers[0].material_override=m
    else:S.view_layers[0].material_override=None
    S.render.filepath=str(O/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()));before=metrics();assert before['degenerate_triangles']==1764;render('source-game')
native=O/'six_lobber_clean_geometry_v16.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native));after=metrics();assert after['degenerate_triangles']==0 and after['triangles']==455748;assert after['bounds']==before['bounds'];render('candidate-game');render('candidate-rear',(-4,5,4.8))
# Keep the authored camera/light scene but remove all model meshes before import.
for o in list(bpy.context.scene.objects):
    if o.type in ('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
glb=O/'six_lobber_clean_geometry_v16.glb';assert hashlib.sha256(glb.read_bytes()).hexdigest()==report['glb_sha256'];bpy.ops.import_scene.gltf(filepath=str(glb))
col=bpy.data.collections.get('SIX_LOBBER_LOOSE_GRENADE_LOADERS')
if col is None:col=bpy.data.collections.new('SIX_LOBBER_LOOSE_GRENADE_LOADERS');bpy.context.scene.collection.children.link(col)
for o in bpy.context.scene.objects:
    if o.type=='MESH' and col not in list(o.users_collection):col.objects.link(o)
export=metrics();assert export['degenerate_triangles']==0 and export['triangles']==after['triangles'];assert max(abs(x-y) for b,c in zip(after['bounds'],export['bounds']) for x,y in zip(b,c))<1e-5
assert export['mesh_count']==320 and all(r['uv_layers'] for r in export['meshes']);assert len([o for o in bpy.context.scene.objects if o.name.startswith('RECOIL_')])==6
render('glb-game');render('glb-rear',(-4,5,4.8));render('glb-clay',(4,-6,5.5),True)
report.update({'native_independently_reopened':True,'glb_independently_imported':True,'source_metrics':before,'native_metrics':after,'glb_metrics':export,'visual_acceptance':'pending same-camera pixel comparison and viewed renders','render_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in O.glob('*.png')}})
(O/'independent-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('V16_NATIVE_AND_GLB_ZERO_DEGENERATE_PASS',flush=True)
