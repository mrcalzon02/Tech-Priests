"""Reopen preserved mechanics, inspect runtime PBR and render actual GLB joints."""
import argparse
import json
from pathlib import Path
import sys
import shutil
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
    if out.exists():raise FileExistsError('Preserve finish review evidence')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0)
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());errors=[]
    for name,digest in receipt['preserved_geometry_and_morph_digests'].items():
        if mesh_digest(s.objects[name])!=digest:errors.append('Changed source geometry '+name)
    for row in receipt['textures']:
        if sha(row['file'])!=row['sha256']:errors.append('Changed authored map '+row['file'])
    packed=[dict(name=i.name,size=list(i.size),packed=bool(i.packed_file)) for i in bpy.data.images if i.source=='FILE']
    if any(not r['packed'] or min(r['size'])==0 for r in packed):errors.append('Unloaded or unpacked source image')
    for o in list(s.objects):
        if o.type not in ('CAMERA','LIGHT'):bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));s.render.fps=24;activate_imported_clip(s,'working');s.frame_set(42)
    actual={sl.material for o in s.objects if o.type=='MESH' for sl in o.material_slots if sl.material};materials=[]
    for m in sorted(actual,key=lambda m:m.name):
        if not m.name.startswith('TP Assembler V03 | '):continue
        bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        linked={k:bool(bs and bs.inputs[k].is_linked) for k in ('Base Color','Roughness','Metallic','Normal')}
        images=[dict(name=n.image.name,size=list(n.image.size)) for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
        if not all(linked.values()) or any(min(r['size'])==0 for r in images):errors.append('Runtime PBR incomplete '+m.name)
        materials.append(dict(name=m.name,channels=linked,images=images))
    if len(materials)!=10:errors.append('Expected ten distinct authored runtime materials')
    s.cycles.samples=32;s.render.resolution_x=s.render.resolution_y=640;s.render.film_transparent=True
    clay=bpy.data.materials.new('Diagnostic neutral clay');clay.use_nodes=True
    bs=clay.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.20,.20,.20,1);bs.inputs['Roughness'].default_value=.85
    views=[('front-fill',43,(0,.2,1.3),(0,-6,6),6.9,False),
           ('rear-seal',205,(0,.3,1.3),(0,6,6),6.9,False),
           ('canister-shoulder-and-window',43,(0,.1,.95),(2,-3,2),2.3,False),
           ('hopper-valve-linkage',43,(-.9,.4,2.37),(2,-3,2),1.55,False),
           ('cap-rails-and-open-neck',43,(-1,.5,1.48),(1,-3,2.4),1.8,False),
           ('landed-sealing-tool',205,(0,.22,1.64),(2,-3,1.8),1.8,False),
           ('rear-gantry-and-conductors',283,(.2,.9,2.38),(2,3,2),3.9,False),
           ('clay-three-stations',283,(0,.2,1.3),(3,-5,4.2),5.8,True)]
    rows=[];reused=Path(args.reuse_views).resolve() if args.reuse_views else None
    if reused:
        prior=json.loads((reused/'finish-readback.json').read_text())
        if prior['source_sha256']!=sha(source) or prior['glb_sha256']!=sha(glb):raise RuntimeError('Stale reused render artifacts')
    for label,frame,target,offset,scale,neutral in views:
        if reused and not neutral:
            row=next(r for r in prior['views'] if r['view']==label);path=reused/(label+'.png')
            if sha(path)!=row['sha256'] or row['source_frame']!=frame:raise RuntimeError('Changed reused render')
            shutil.copy2(path,out/path.name);rows.append(row);continue
        s.frame_set(frame-1);bpy.context.view_layer.update();target=Vector(target);s.camera.location=target+Vector(offset)
        s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale;s.view_layers[0].material_override=clay if neutral else None
        path=out/(label+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True);rows.append(dict(view=label,source_frame=frame,sha256=sha(path),diagnostic_camera=True))
    report=dict(passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(glb),preserved_meshes=len(receipt['preserved_geometry_and_morph_digests']),authored_maps=len(receipt['textures']),source_images=packed,runtime_materials=materials,views=rows,
                scope='Reopened source geometry and packed maps, actual imported GLB PBR and actual front/rear/joint/clay renders. Visual review, final captures and native assembly remain separate.')
    (out/'finish-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('ASSEMBLER_FINISH_READBACK',not errors,errors,flush=True)


if __name__=='__main__':main()
