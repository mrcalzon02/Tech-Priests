"""Independent reopen, evaluated GLB export/readback and local render evidence."""
import argparse, hashlib, json, math, struct, sys
from pathlib import Path
import bpy
from mathutils import Vector
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--candidate',type=Path,required=True);a=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);O=a.candidate.resolve()
native=O/'six_lobber_independent_recoil_v15.blend';report=json.loads((O/'rig-validation.json').read_text())
assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native));C=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS']
def metrics(objects):
    pts=[];tris=0;deg=0;uv=0;materials=set()
    for o in objects:
        if o.type!='MESH':continue
        me=bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get());me.calc_loop_triangles()
        pp=[o.matrix_world@v.co for v in me.vertices];assert all(math.isfinite(x) for p in pp for x in p)
        pts+=pp;tris+=len(me.loop_triangles);deg+=sum((pp[t.vertices[1]]-pp[t.vertices[0]]).cross(pp[t.vertices[2]]-pp[t.vertices[0]]).length<1e-12 for t in me.loop_triangles)
        uv+=bool(me.uv_layers)
        materials.update(m.name for m in me.materials if m)
        bpy.data.meshes.remove(me)
    return {'mesh_count':sum(o.type=='MESH' for o in objects),'triangles':tris,'degenerate_triangles':deg,'meshes_with_uv':uv,'bounds':[[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]],'materials':sorted(materials)}
assert len([o for o in C.objects if o.name.startswith('RECOIL_')])==6
assert all(not any(m.type=='MIRROR' for m in bpy.data.objects[r['object']].modifiers) for r in report['recoil_parts'])
before=metrics(list(C.objects));assert before['mesh_count']==320
images=[i for i in bpy.data.images if i.type=='IMAGE'];assert all(i.packed_file for i in images),'Unpacked source images'
bpy.ops.object.select_all(action='DESELECT')
for o in C.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
glb=O/'six_lobber_independent_recoil_v15.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
data=glb.read_bytes();length,kind=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+length])
assert len(doc.get('meshes',[]))==320
assert len(doc.get('images',[]))>0
assert all(img.get('bufferView') is not None for img in doc['images'])
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb))
after=metrics(list(bpy.context.scene.objects));assert after['triangles']==before['triangles'];assert after['mesh_count']==before['mesh_count'];assert after['degenerate_triangles']==before['degenerate_triangles'];assert after['meshes_with_uv']==before['meshes_with_uv']
bound_delta=max(abs(x-y) for p,q in zip(before['bounds'],after['bounds']) for x,y in zip(p,q));assert bound_delta<1e-5,bound_delta
for station in ('TOP_R','TOP_L','MID_R','MID_L','BOT_R','BOT_L'):assert bpy.data.objects.get('RECOIL_'+station)
S=bpy.context.scene;S.render.engine='CYCLES';S.cycles.samples=16;S.cycles.use_denoising=True;S.cycles.device='CPU';S.render.threads_mode='FIXED';S.render.threads=6
S.render.resolution_x=S.render.resolution_y=640;S.render.resolution_percentage=100;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.film_transparent=True
S.world=bpy.data.worlds.new('Neutral roundtrip world');S.world.use_nodes=True;S.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.12,.12,1);S.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
for name,pos,power,size in [('key',(-4,-5,8),700,5),('fill',(4,-1,6),500,4),('rim',(0,5,7),800,4)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size;o=bpy.data.objects.new(name,light);S.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,2.7))-o.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('Independent export inspection');cam=bpy.data.objects.new(camdata.name,camdata);S.collection.objects.link(cam);S.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=4.2
clay=bpy.data.materials.new('Neutral clay inspection');clay.diffuse_color=(.38,.38,.38,1);clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75
for name,pos in [('glb-front',(0,-7,4)),('glb-rear',(-4,5,4.8)),('glb-clay',(4,-6,5.5))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,2.75))-cam.location).to_track_quat('-Z','Y').to_euler();S.view_layers[0].material_override=clay if name=='glb-clay' else None
    S.render.filepath=str(O/(name+'.png'));bpy.ops.render.render(write_still=True)
report.update({'native_independently_reopened':True,'source_packed_images':len(images),'glb_sha256':hashlib.sha256(data).hexdigest(),'glb_embedded_images':len(doc['images']),'before_export':before,'after_reimport':after,'max_bound_delta_tiles':bound_delta,'six_controls_reopened_and_reimported':True,'glb_reimported_and_rendered':True,'visual_acceptance':'rig preservation review pending; source fidelity and animation not approved'})
(O/'roundtrip-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('V15_INDEPENDENT_REOPEN_AND_GLB_READBACK_PASS',flush=True)
