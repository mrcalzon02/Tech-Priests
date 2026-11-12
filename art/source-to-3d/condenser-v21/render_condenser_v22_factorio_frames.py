"""Render 4x32 actual V22C Blender Cycles frames from an approved editable scene.

Never generate look-alike pixels. The source was constructed from the SHA-locked
V21 .blend by animate_condenser_v22.py --build-only. Camera remains canonical.
Original mesh parents and geometry are not modified, and 0/90/180/270 source
roots are temporarily rotated for each source-frame capture.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'tools' / 'fmpl'))
sys.path.insert(0, str(HERE))
from blender_camera_guard import assert_clean
from animate_condenser_v22 import profile, APPROVED_SHA, mesh_signatures

ANGLES = (0, 90, 180, 270)
FRAME_INDICES = tuple(range(1, 97, 3))
DIM = 512


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as inp:
        for buf in iter(lambda: inp.read(1024*1024), b''):
            digest.update(buf)
    return digest.hexdigest()


def is_reference(obj):
    return obj.name.startswith(('Reference pipe', 'Grid ', 'PIPE_FIT_', 'FMPL_CAPTURE_')) or any(
        coll.name in {'REFERENCE_ADJACENT_PIPES','GRID','GROUND','GROUND_GRID'}
        or coll.name.startswith('REFERENCE_') for coll in obj.users_collection)


def check_scene(scene):
    if scene.get('model_source_sha256') != APPROVED_SHA:
        raise RuntimeError('No approved V21 source receipt in saved V22C scene')
    if scene.get('source_world_transform_guard') != 'PASS':
        raise RuntimeError('V22C source world-transform guard missing')
    if scene.get('new_render_fx_curve_count') != 0 or scene.get('new_render_fx_particle_count') != 40:
        raise RuntimeError('Wrong V22C FX or original bevel steam is back')
    if scene.get('owner_visual_approved') is not False:
        # Approval gate is carried by owner request, not inferred from file.
        raise RuntimeError('V22C scene approval flag unexpectedly changed')
    locked = json.loads(scene.get('source_mesh_local_sha256', '{}'))
    parents = json.loads(scene.get('source_original_parents', '{}'))
    world = json.loads(scene.get('source_world_matrices', '{}'))
    if not locked or set(locked) != set(parents) or set(locked) != set(world):
        raise RuntimeError('Original geometry/parent/world snapshot incomplete')
    if locked != mesh_signatures(scene):
        raise RuntimeError('Original approved source mesh geometry changed')
    for name in locked:
        obj = bpy.data.objects[name]
        observed = obj.parent.name if obj.parent else None
        if observed != parents[name]:
            raise RuntimeError('Original source parent drift: ' + name)
    scene.frame_set(1)
    bpy.context.view_layer.update()
    for name, original in world.items():
        current = bpy.data.objects[name].matrix_world
        diff = max(abs(current[i][j] - original[i][j]) for i in range(4) for j in range(4))
        if diff > 1e-4:
            raise RuntimeError('Source mesh world-space drift before export: %s %.6f' % (name, diff))
    assert_clean(scene, profile(), bpy)
    if scene.camera.data.type != 'ORTHO':
        raise RuntimeError('Noncanonical camera')
    return locked, parents, world


def render(out: Path, angles=ANGLES, indices=FRAME_INDICES, samples=48):
    out = out.resolve()
    if out.exists() and any(out.iterdir()):
        raise RuntimeError('Refusing to overwrite an existing export: '+str(out))
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    locked, parents, original_world = check_scene(scene)
    turntable = bpy.data.objects.get('FX ONLY | entity export turntable')
    if turntable is None:
        raise RuntimeError('Reviewed V22C scene missing cardinal turntable')
    # These are original root meshes whose parent must never change.
    loose_roots = [bpy.data.objects[n] for n,p in parents.items()
                   if p is None and not is_reference(bpy.data.objects[n])]
    scene.render.engine='CYCLES'
    scene.cycles.samples=samples
    if hasattr(scene.cycles, 'seed'):
        scene.cycles.seed=27
    if hasattr(scene.cycles, 'use_animated_seed'):
        scene.cycles.use_animated_seed=False
    scene.render.resolution_x=scene.render.resolution_y=DIM
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.render.threads_mode='FIXED'
    scene.render.threads=4
    records={}
    for angle in angles:
        directory = out / f'direction_{angle:03d}'
        directory.mkdir(parents=True, exist_ok=False)
        frame_records=[]
        matrix=Matrix.Rotation(math.radians(angle),4,'Z')
        for frame in indices:
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            root_snapshots=[(obj, obj.matrix_world.copy()) for obj in loose_roots]
            try:
                turntable.rotation_euler.z=math.radians(angle)
                for obj,base in root_snapshots:
                    obj.matrix_world=matrix@base
                bpy.context.view_layer.update()
                target=directory / f'frame_{frame:03d}.png'
                scene.render.filepath=str(target)
                bpy.ops.render.render(write_still=True)
                if not target.is_file() or target.stat().st_size<10000:
                    raise RuntimeError('Real Cycles render failed: '+str(target))
                frame_records.append({'frame':frame,'path':str(target.relative_to(out)).replace('\\','/'),
                                      'sha256':sha(target),'bytes':target.stat().st_size})
            finally:
                for obj,base in root_snapshots:
                    obj.matrix_world=base
                turntable.rotation_euler.z=0
                bpy.context.view_layer.update()
        records[str(angle)]=frame_records
        print('CONDENSER_NATIVE_DIRECTION_COMPLETE',angle,len(frame_records),flush=True)
    scene.frame_set(1)
    bpy.context.view_layer.update()
    # Reverify original hierarchy/geometry and immobile world transform at idle.
    check_scene(scene)
    result={
        'schema':'tech-priests.condenser-v22c-factorio-native-frames.v1',
        'source_sha256':APPROVED_SHA,
        'original_mesh_count':len(locked),
        'native_scene':Path(bpy.data.filepath).name,
        'native_scene_sha256':sha(bpy.data.filepath),
        'approved_v22c_keyed_frames':96,
        'sampled_frames_per_orientation':len(indices),
        'original_fps':8,
        'sampled_animation_fps':8/3,
        'cycle_duration_seconds':12,
        'resolution':[DIM,DIM],
        'cycles_samples':samples,
        'camera_scale_world_units':3.2,
        'directions':records,
        'source_hierarchy_and_stationary_ports':'PASS',
        'artificial_or_generated_image_frames':False,
    }
    (out/'native_frames_manifest.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print('CONDENSER_V22C_NATIVE_FACTORIO_CAPTURE_PASS',len(angles)*len(indices),flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--angles',type=str,default='0,90,180,270')
    parser.add_argument('--samples',type=int,default=48)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    angles=tuple(int(a) for a in args.angles.split(','))
    if not angles or len(set(angles))!=len(angles) or any(a not in ANGLES for a in angles):
        raise RuntimeError('Invalid four-way angle selection')
    if args.samples<24 or args.samples>96:
        raise RuntimeError('Quality policy: Cycles samples 24..96 only')
    render(args.out,angles=angles,samples=args.samples)

if __name__=='__main__':main()
