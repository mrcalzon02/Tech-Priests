"""Independent native Blender reopen checks for approved-source Condenser V22 study."""
import argparse,hashlib,json,sys
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'/'fmpl'))
from blender_camera_guard import assert_clean,camera_record
from capture_policy import POLICY_ID
APPROVED_SHA='1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
FRAMES=[1+6*i for i in range(16)]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main(out):
    original=out/'condenser_v22_motion_review.blend'
    if not original.is_file() or Path(bpy.data.filepath).resolve()!=original.resolve():
        raise RuntimeError('Must independently reopen the actual saved V22 Blender derivative')
    scene=bpy.context.scene
    if (scene.get('model_source_sha256')!=APPROVED_SHA or
        scene.get('native_game_art_modified') is not False or
        scene.get('animation_review_revision')!='V22 review-only candidate'):
        raise RuntimeError('Source hash, review-only, or game-art gate changed')
    profile={'camera_policy':POLICY_ID,'capture_kind':'entity',
       'directions':[0,90,180,270],'states':{'condenser_v22_preview':FRAMES},
       'source_size':256,'camera_override':{
       'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':5.5,
       'target':[0,0,.55],'ortho_scale':3.20,'shift_x':0,'shift_y':0}}
    assert_clean(scene,profile,bpy)
    root=bpy.data.objects.get('FX ONLY | mild condenser rack rumble')
    floor=bpy.data.objects.get('Condenser shallow tapered foundation')
    if root is None or floor is None:
        raise RuntimeError('Existing condenser or independent vibration rig missing')
    caps=[o for o in bpy.data.objects if o.name.startswith('Condenser capped canister ')]
    seats=[o for o in bpy.data.objects if o.name.startswith('Condenser dark canister seat ')]
    if len(caps)!=8 or len(seats)!=8 or any(o.parent!=root for o in caps+seats):
        raise RuntimeError('Exactly eight original capped canisters and seats must remain together')
    pngs=[out/f'frame_{i:03d}.png' for i in FRAMES]
    if any(not f.is_file() or f.stat().st_size<1000 for f in pngs):
        raise RuntimeError('Missing native condenser Cycles frames')
    scene.frame_set(1)
    begin=tuple(root.location)
    begin_rot=tuple(root.rotation_euler)
    base=tuple(tuple(row) for row in floor.matrix_world)
    scene.frame_set(49)
    moved=max(abs(a-b) for a,b in zip(begin,root.location))>.00001
    scene.frame_set(97)
    if not moved or max(abs(a-b) for a,b in zip(begin,root.location))>.000001:
        raise RuntimeError('Small original rack vibration absent or 16-frame cycle not closed')
    if max(abs(a-b) for a,b in zip(begin_rot,root.rotation_euler))>.000001:
        raise RuntimeError('Condenser rig rotation loop not closed')
    if base!=tuple(tuple(row) for row in floor.matrix_world):
        raise RuntimeError('Condenser foundation moved')
    result={'verification':'PASS','source_sha256':APPROVED_SHA,
      'frames':{p.name:sha(p) for p in pngs},'cap_parts':8,'seat_parts':8,
      'foundation_stationary':True,'fixed_camera':camera_record(scene),
      'game_art_changed':False,'owner_visual_approved':False}
    (out/'condenser_v22_native_readback.json').write_text(json.dumps(result,indent=2)+'\n')
    print('CONDENSER_V22_INDEPENDENT_NATIVE_REOPEN_PASS',json.dumps(result),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--out',type=Path,required=True)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    main(args.out.resolve())
