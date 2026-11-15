"""Inspect actual exported PBR and render exposed plate, joints, rear and clay."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from finish_fabricator_v03 import mesh_digest
from electrolyzer_state_clips import activate_imported_clip


def main():
    ap=argparse.ArgumentParser()
    for key in ('source','glb','out'):ap.add_argument('--'+key,required=True)
    ap.add_argument('--reuse-views')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();glb=Path(args.glb).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve surface inspection')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0)
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());errors=[]
    for name,digest in receipt['preserved_geometry_and_morph_digests'].items():
        if mesh_digest(s.objects[name])!=digest:errors.append('Changed preserved mesh/morph '+name)
    for row in receipt['textures']:
        if sha(row['file'])!=row['sha256']:errors.append('Changed texture '+row['file'])
    packed=[dict(name=i.name,size=list(i.size),packed=bool(i.packed_file)) for i in bpy.data.images if i.source=='FILE']
    if any(not r['packed'] or min(r['size'])==0 for r in packed):errors.append('Unloaded/unpacked source image')
    for o in list(s.objects):
        if o.type not in ('CAMERA','LIGHT'):bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));s.render.fps=24;activate_imported_clip(s,'working');s.frame_set(174)
    materials=[]
    actual_materials={slot.material for o in s.objects if o.type=='MESH' for slot in o.material_slots if slot.material}
    for material in sorted(actual_materials,key=lambda m:m.name):
        if not material.use_nodes or not material.name.startswith('TP Fabricator V03 | '):continue
        if material.users==0:continue
        nodes=material.node_tree.nodes;bs=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
        images=[dict(name=n.image.name,size=list(n.image.size)) for n in nodes if n.type=='TEX_IMAGE' and n.image]
        linked={key:bool(bs and bs.inputs[key].is_linked) for key in ('Base Color','Roughness','Metallic','Normal')}
        if not all(linked.values()) or any(min(r['size'])==0 for r in images):errors.append('Incomplete runtime PBR '+material.name)
        materials.append(dict(name=material.name,channels=linked,images=images))
    if len(materials)!=8:errors.append('Expected eight actual authored runtime materials')
    s.cycles.samples=32;s.render.resolution_x=s.render.resolution_y=640;s.render.film_transparent=True
    clay=bpy.data.materials.new('Diagnostic neutral clay');clay.diffuse_color=(.38,.38,.38,1)
    views=[('front-formed',199,(0,0,1.05),(0,-6,6),6.7,False),
           ('rear-formed',199,(0,0,1.05),(0,6,6),6.7,False),
           ('weld-edge',49,(0,-.40,1.06),(1,-2,2.3),2.6,False),
           ('plate-and-clamps',199,(0,0,1.02),(2,-3,2.5),3.8,False),
           ('pump-and-suction',199,(-.98,1.30,.75),(-2,3,2.5),2.0,False),
           ('rear-lift-and-corridor',199,(1.55,.9,.73),(3,2,2),2.7,False),
           ('conductor-and-tool',49,(0,-.57,1.80),(1,-3,2),3.2,False),
           ('clay-open-frame',255,(0,0,1.05),(3,-5,4.2),5.6,True)]
    rows=[]
    reused=None
    if args.reuse_views:
        reused=Path(args.reuse_views).resolve();prior=json.loads((reused/'finish-readback.json').read_text())
        if prior['source_sha256']!=sha(source) or prior['glb_sha256']!=sha(glb):raise RuntimeError('Stale reused render source/export')
    for label,frame,target,offset,scale,neutral in views:
        if reused:
            import shutil
            old=next(r for r in prior['views'] if r['view']==label)
            path=reused/(label+'.png')
            if sha(path)!=old['sha256'] or old['source_frame']!=frame:raise RuntimeError('Stale reused view')
            shutil.copy2(path,out/path.name);rows.append(old);continue
        s.frame_set(frame-1);bpy.context.view_layer.update();target=Vector(target);s.camera.location=target+Vector(offset)
        s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale
        s.view_layers[0].material_override=clay if neutral else None
        path=out/(label+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        rows.append(dict(view=label,source_frame=frame,sha256=sha(path),diagnostic_camera=True))
    (out/'finish-readback.json').write_text(json.dumps(dict(passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(glb),
        preserved_meshes=len(receipt['preserved_geometry_and_morph_digests']),authored_maps=len(receipt['textures']),source_images=packed,runtime_materials=materials,views=rows,
        scope='Reopened source geometry/morph and packed-map check; actual GLB PBR links and diagnostic front/rear/closeup/clay renders. Visual judgement and final canonical captures are separate.'),indent=2)+'\n')
    print('FABRICATOR_FINISH_REIMPORT',not errors,errors,flush=True)


if __name__=='__main__':main()
