"""Compare source and actual GLB state poses and the working-loop closure."""
import argparse
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha
from electrolyzer_state_clips import activate_imported_clip


def sample(scene,clip=None):
    objects=[o for o in scene.objects if 'visible electrode gas bubble' in o.name or 'console live green bar' in o.name]
    result={}
    for frame in (0,1,13,25,37,49,61,73,85,97):
        if clip:activate_imported_clip(scene,'idle' if frame==0 else 'working')
        scene.frame_set(0 if frame==0 else frame-1 if clip else frame);bpy.context.view_layer.update()
        result[str(frame)]={o.name:dict(location=list(o.location),scale=list(o.scale)) for o in objects}
    return result


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--dir',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.dir).resolve()
    source=root/'electrolyzer-v01.blend';glb=root/'electrolyzer-v01.glb'
    bpy.ops.wm.open_mainfile(filepath=str(source));native=sample(bpy.context.scene)
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb))
    runtime=sample(bpy.context.scene,clip=True);errors=[];max_error=0;loop_error=0
    raw=glb.read_bytes();doc=json.loads(raw[20:20+int.from_bytes(raw[12:16],'little')])
    clips=[]
    for anim in doc.get('animations',[]):
        accessors=[doc['accessors'][row['input']] for row in anim['samplers']]
        start=min(a['min'][0] for a in accessors);end=max(a['max'][0] for a in accessors)
        clips.append(dict(name=anim.get('name'),start_seconds=start,end_seconds=end,channels=len(anim['channels'])))
    if {c['name'] for c in clips}!={'idle','working'}:errors.append('missing coherent idle/working clips')
    if any(abs(c['end_seconds']-c['start_seconds']-4)>1e-5 for c in clips if c['name']=='working'):errors.append('working clip duration differs from four seconds')
    for frame,poses in native.items():
        for name,pose in poses.items():
            if name not in runtime[frame]:errors.append('missing animated export object '+name);continue
            for channel in ('location','scale'):
                max_error=max(max_error,max(abs(a-b) for a,b in zip(pose[channel],runtime[frame][name][channel])))
    for name,pose in native['1'].items():
        for channel in ('location','scale'):
            loop_error=max(loop_error,max(abs(a-b) for a,b in zip(pose[channel],native['97'][name][channel])))
    if max_error>1e-4:errors.append('actual GLB state poses differ')
    if loop_error>1e-4:errors.append('working loop does not close')
    idle_bubbles=[p for n,p in native['0'].items() if 'visible electrode gas bubble' in n]
    if len(idle_bubbles)!=16 or any(max(p['scale'])>1e-6 for p in idle_bubbles):errors.append('standby bubbles visible')
    if native['1']==native['25']:errors.append('no source working motion')
    report=dict(passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(glb),
        maximum_export_pose_error=max_error,maximum_loop_closure_error=loop_error,exported_clips=clips,
        native=native,runtime=runtime,scope='10 sampled actual source/imported local poses, standby hidden tracers and loop boundary; rendered timing requires capture review')
    (root/'motion-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ELECTROLYZER_MOTION',not errors,errors,'export_error',max_error,'loop_error',loop_error,flush=True)


if __name__=='__main__':main()
