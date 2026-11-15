"""Restrained electrolysis state clock: standby plus a four-second gas loop."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha


def action_curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Keep previous finishing state')
    out.mkdir(parents=True);source=src/'electrolyzer-v01.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    bubbles=sorted((o for o in s.objects if 'visible electrode gas bubble' in o.name),key=lambda o:o.name)
    if len(bubbles)!=16:raise RuntimeError('Expected eight real tracers per cell')
    for index,ob in enumerate(bubbles):
        k=index%8;ob.animation_data_clear()
        for frame in range(0,98):
            phase=((frame-1+k*12)%96)/96
            # Hide during wrap/reset; a gas bubble rises and fades at the top,
            # rather than visibly moving downward through the glass.
            fade=min(1.,phase/.09,(1-phase)/.09) if frame else 0.
            fade=max(0.,fade)
            ob.location.z=.91+phase*.55;ob.scale=(fade,fade,fade*.92)
            ob.keyframe_insert(data_path='location',index=2,frame=frame)
            ob.keyframe_insert(data_path='scale',frame=frame)
        for curve in action_curves(ob.animation_data.action):
            for key in curve.keyframe_points:key.interpolation='LINEAR'
        ob.animation_data.action.name='TP Electrolyzer V05 | gas rise '+str(index)
        ob['animation_role']='contained rising gas; hidden wrap; frame0 standby; frames1..97 four-second working loop'
    bars=[o for o in s.objects if 'console live green bar' in o.name]
    s.frame_set(1);working={o:o.scale.z for o in bars}
    for ob in bars:
        ob.scale.z=.18;ob.keyframe_insert(data_path='scale',index=2,frame=0)
        ob.scale.z=working[ob];ob.keyframe_insert(data_path='scale',index=2,frame=1)
    states=dict(idle=[0],working=list(range(1,97,12)))
    s['animation_states']=json.dumps(states);s['working_cycle_seconds']=4
    s.render.fps=24;s.frame_start=0;s.frame_end=97;s.frame_set(25)
    for name in ('port_manifest.json','part_provenance.json'):
        shutil.copy2(src/name,out/name)
    shutil.copytree(src/'textures',out/'textures')
    # Packed maps are canonical; copy paths are set to this self-contained
    # derivative folder before saving, without touching previous evidence.
    for im in bpy.data.images:
        if im.name.startswith('TP Electrolyzer V04 |') and im.source=='FILE':
            im.filepath=str(out/'textures'/Path(im.filepath).name)
    bpy.ops.file.pack_all();target=out/'electrolyzer-v01.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    prior=json.loads((src/'construction-receipt.json').read_text())
    prior.update(status='candidate_native; state and exported-image review pending',revision='V05 working/standby states',
        source_sha256=sha(source),native_sha256=sha(target),states=states,
        clock=dict(source_fps=24,working_frames=[1,97],cycle_seconds=4),
        motion='16 restrained gas tracers rise with concealed wrap; standby has no bubbles and steady low green bars')
    (out/'construction-receipt.json').write_text(json.dumps(prior,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    s.frame_set(0);s.render.filepath=str(out/'idle-front.png');bpy.ops.render.render(write_still=True)
    print('ELECTROLYZER_V05_STATES_SAVED',sha(target),flush=True)


if __name__=='__main__':main()
