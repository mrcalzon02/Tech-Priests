"""Remove only evaluated zero-area triangles; preserve visible surfaces and rig."""
import bpy, argparse,sys,json,hashlib,math,collections
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);O=a.out.resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()));S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update();C=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS']
def evaluate(o):return bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
records=[];total_removed=0;before_total=0;after_total=0
for o in list(C.objects):
    if o.type!='MESH':continue
    me=evaluate(o);me.calc_loop_triangles();points=[o.matrix_world@v.co for v in me.vertices]
    assert all(math.isfinite(x) for v in points for x in v)
    keep=[];removed=[]
    for t in me.loop_triangles:
        area=(points[t.vertices[1]]-points[t.vertices[0]]).cross(points[t.vertices[2]]-points[t.vertices[0]]).length
        (removed if area<1e-12 else keep).append(t)
    before_total+=len(keep)+len(removed);after_total+=len(keep)
    if not removed:bpy.data.meshes.remove(me);continue
    assert keep,'Do not silently remove a whole source object'
    ids=sorted({v for t in keep for v in t.vertices});remap={v:i for i,v in enumerate(ids)}
    nm=bpy.data.meshes.new(o.name+' | zero-area faces removed');nm.from_pydata([me.vertices[v].co[:] for v in ids],[],[[remap[v] for v in t.vertices] for t in keep]);nm.update()
    for mat in me.materials:nm.materials.append(mat)
    for old,new in zip(keep,nm.polygons):
        source=me.polygons[old.polygon_index];new.material_index=source.material_index;new.use_smooth=source.use_smooth
    for layer in me.uv_layers:
        uv=nm.uv_layers.new(name=layer.name)
        for old,new in zip(keep,nm.polygons):
            for oldli,newli in zip(old.loops,new.loop_indices):uv.data[newli].uv=layer.data[oldli].uv
    nm.normals_split_custom_set([me.corner_normals[li].vector[:] for t in keep for li in t.loops])
    # Exact source-loop correspondence: every surviving vertex, UV and material.
    max_uv=0.;max_pos=0.
    for old,new in zip(keep,nm.polygons):
        assert new.material_index==me.polygons[old.polygon_index].material_index
        for oldv,newv in zip(old.vertices,new.vertices):max_pos=max(max_pos,(me.vertices[oldv].co-nm.vertices[newv].co).length)
        for l in me.uv_layers:
            for oldli,newli in zip(old.loops,new.loop_indices):max_uv=max(max_uv,(l.data[oldli].uv-nm.uv_layers[l.name].data[newli].uv).length)
    assert max_pos==0 and max_uv==0,(o.name,max_pos,max_uv)
    old_world=o.matrix_world.copy();old_parent=o.parent
    o.data=nm;o.modifiers.clear();bpy.context.view_layer.update()
    assert o.parent==old_parent and o.matrix_world==old_world
    total_removed+=len(removed);records.append({'object':o.name,'removed_zero_area_triangles':len(removed),'retained_triangles':len(keep),'surviving_position_uv_material_correspondence':'exact','source_modifiers_baked_only_for_affected_object':True})
    bpy.data.meshes.remove(me)
assert total_removed==1764,(total_removed,'Unexpected baseline; audit before cleanup')
assert before_total==457512 and after_total==455748
assert len([o for o in C.objects if o.name.startswith('RECOIL_')])==6
S['model_completion_stage']='V16 zero-area triangle cleanup; source/history in V15; rig and motion incomplete'
native=O/'six_lobber_clean_geometry_v16.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
# Same-camera source/candidate renders with fixed seed for visual preservation.
cam=S.camera;cam.location=(0,-7,9);cam.rotation_euler=(Vector((0,0,2.75))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.2
S.render.engine='CYCLES';S.cycles.samples=16;S.cycles.seed=5855;S.cycles.use_denoising=True;S.render.resolution_x=S.render.resolution_y=640;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.filepath=str(O/'candidate-game.png');bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in C.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
glb=O/'six_lobber_clean_geometry_v16.glb';bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
report={'stage':'geometry cleanup only; rig preparation remains incomplete','source_sha256':hashlib.sha256(a.source.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'before_triangles':before_total,'after_triangles':after_total,'removed_zero_area_triangles':total_removed,'changed_objects':records,'all_surviving_source_positions_uvs_material_indices_exact':True,'parent_world_frames_retained':True,'recoil_controls':6,'animation_authored':False,'runtime_integrated':False,'visual_acceptance':'pending actual render comparison and independent reopen'}
(O/'cleanup-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('V16_ZERO_AREA_CLEANUP_PASS',total_removed,len(records),flush=True)
