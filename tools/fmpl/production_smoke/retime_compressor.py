"""Retime actual actions, preserving geometry and equivalent poses exactly."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_process import hash_original_meshes
from refine_purifier_v14 import sha


def snapshot(scene,frames):
    poses={}
    for frame in frames:
        scene.frame_set(frame);bpy.context.view_layer.update()
        poses[frame]={o.name:[float(c) for row in o.matrix_world for c in row] for o in scene.objects if o.type in ('MESH','EMPTY')}
    return poses


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--seconds',type=int,required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve previous timing study')
    out.mkdir(parents=True);source=src/'compressor-v04.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    old_end=s.frame_end;old_seconds=(old_end-1)/s.render.fps;factor=args.seconds/old_seconds
    frames=(0,)+tuple(1+i*(old_end-1)//8 for i in range(9));before=snapshot(s,frames)
    s.frame_set(25);bpy.context.view_layer.update();meshes=[o for o in s.objects if o.type=='MESH'];geometry_before=hash_original_meshes(meshes)
    actions={o.animation_data.action for o in s.objects if o.animation_data and o.animation_data.action}
    for action in actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            if key.co.x<1:continue
                            key.co.x=1+(key.co.x-1)*factor
                            key.handle_left.x=1+(key.handle_left.x-1)*factor
                            key.handle_right.x=1+(key.handle_right.x-1)*factor
                        curve.update()
    s.frame_end=1+args.seconds*s.render.fps;s['working_cycle_seconds']=args.seconds
    mapped={f:(0 if f==0 else int(1+(f-1)*factor)) for f in frames};after=snapshot(s,mapped.values())
    error=max(abs(a-b) for frame,objects in before.items() for name,values in objects.items() for a,b in zip(values,after[mapped[frame]][name]))
    s.frame_set(int(1+24*factor));bpy.context.view_layer.update();geometry_after=hash_original_meshes(meshes)
    if error>1e-5 or geometry_after!=geometry_before:raise RuntimeError('Retime altered equivalent poses or source geometry')
    states=dict(idle=[0],working=[int(1+(f-1)*factor) for f in range(4,97,12)])
    s['animation_states']=json.dumps(states)
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    shutil.copytree(src/'textures',out/'textures')
    for image in bpy.data.images:
        if image.source=='FILE' and 'textures' in image.filepath:
            tail=Path(image.filepath).parts
            if 'textures' in tail:image.filepath=str(out.joinpath(*tail[tail.index('textures'):]))
    bpy.ops.file.pack_all();target=out/'compressor-v05.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt=json.loads((src/'construction-receipt.json').read_text());receipt.update(revision='V05 owner-requested slower timing',native_sha256=sha(target),source_sha256=sha(source),cycle_seconds=args.seconds,states=states)
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    (out/'retime-readback.json').write_text(json.dumps(dict(passed=True,old_seconds=old_seconds,new_seconds=args.seconds,factor=factor,
        source_sha256=sha(source),native_sha256=sha(target),equivalent_pose_error=error,geometry_before=geometry_before,geometry_after=geometry_after,
        actual_actions_retimed=len(actions),equivalent_frames=mapped,owner_request='Slow the animation down'),indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('COMPRESSOR_RETIMED',old_seconds,args.seconds,'pose_error',error,flush=True)


if __name__=='__main__':main()
