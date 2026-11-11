"""Condenser V22 native Blender motion study from previously owner-approved V21 geometry.

SOURCE ONLY: require the exact approved editable .blend; do not synthesize a model
or alter its shape, ports, fasteners, canister count, clamps or textures.
Motion experiment: tiny whole-rack vibration, status electronics, no leaked fluid.
One canonical FMPL fixed 45-degree orthographic camera; no game integration.
"""
from __future__ import annotations
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2] if (HERE.parents[2]/'tools'/'fmpl').is_dir() else None
if ROOT:
    sys.path.insert(0,str(ROOT/'tools'/'fmpl'))
    from blender_camera_guard import install_canonical_camera, assert_clean, camera_record
    from capture_policy import POLICY_ID
else:
    raise RuntimeError('Run from a Tech-Priests repository checkout, not a detached script')

APPROVED_SHA='1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
CANISTER_PREFIX='Condenser capped canister '
SEAT_PREFIX='Condenser dark canister seat '
FRAME_IDS=[1+6*i for i in range(16)]
FREQUENCY=8


def source_sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def centroid(ob):
    return sum((ob.matrix_world@v.co for v in ob.data.vertices),Vector((0,0,0)))/len(ob.data.vertices)


def parent_preserve(obj,parent):
    matrix=obj.matrix_world.copy()
    obj.parent=parent
    obj.matrix_world=matrix


def make_point(name,center,color,collection):
    light_data=bpy.data.lights.new(name,'POINT')
    light_data.color=color
    light_data.energy=0
    light_data.shadow_soft_size=.05
    light=bpy.data.objects.new(name,light_data)
    collection.objects.link(light)
    light.location=center+Vector((0,0,.015))
    light['FX_ONLY_NO_ADDED_MACHINE_PART']=True
    return light


def install_camera(scene):
    profile={
       'camera_policy':POLICY_ID,'capture_kind':'entity',
       'directions':[0,90,180,270],
       'states':{'condenser_v22_preview':FRAME_IDS},
       'source_size':256,
       'camera_override':{'type':'ORTHO','elevation_deg':45,
           'azimuth_deg':0,'distance':5.5,'target':[0,0,.55],
           'ortho_scale':3.20,'shift_x':0,'shift_y':0},
    }
    install_canonical_camera(scene,profile,bpy)
    assert_clean(scene,profile,bpy)
    return profile


def run(source,out):
    source=source.resolve()
    out.mkdir(parents=True,exist_ok=True)
    if source_sha(source)!=APPROVED_SHA:
        raise RuntimeError('Refuse unapproved/changed condenser V21 source BLEND')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene=bpy.context.scene
    # Native V21 source contains visible source, reference adjacent pipe geometry,
    # all 8 real canisters and 8 seats. Keep real external pipe references hidden.
    canisters=[o for o in bpy.data.objects if o.name.startswith(CANISTER_PREFIX)]
    seats=[o for o in bpy.data.objects if o.name.startswith(SEAT_PREFIX)]
    if len(canisters)!=8 or len(seats)!=8:
        raise RuntimeError(f'Source canister parts changed: {len(canisters)} / {len(seats)}')
    for name in ('Condenser continuous central chassis',
                 'Condenser eight-seat rack body',
                 'Condenser inset display glass',
                 'Condenser right continuous side cheek',
                 'Water outlet end flange'):
        if bpy.data.objects.get(name) is None:
            raise RuntimeError('Required approved source object missing: '+name)
    if 'REFERENCE_ADJACENT_PIPES' in bpy.data.collections:
        reference=bpy.data.collections['REFERENCE_ADJACENT_PIPES']
        reference.hide_render=True
        for obj in reference.objects:
            obj.hide_render=True
    config=install_camera(scene)
    fx=bpy.data.collections.new('CON DENSER V22 REVIEW FX ONLY')
    scene.collection.children.link(fx)
    # V22: rack is driven as a single connected cassette; no canister pops
    # out of its pocket. Hoses and output flange remain physically stationary.
    rack=bpy.data.objects['Condenser eight-seat rack body']
    root=bpy.data.objects.new('FX ONLY | mild condenser rack rumble',None)
    fx.objects.link(root)
    root.location=centroid(rack)
    children=[rack]+canisters+seats+[o for o in bpy.data.objects if
        o.name.startswith('Condenser formed conductor retainer ')]
    for item in children:
        if item.parent is not None:
            raise RuntimeError('Original rack had parent hierarchy; do not sever it: '+item.name)
        parent_preserve(item,root)
    lcd=bpy.data.objects['Condenser inset display glass']
    display=make_point('FX ONLY | existing LCD green flux',centroid(lcd),(.02,1,.10),fx)
    diodes=[]
    for label,color in (('red',(.95,.04,.01)),('amber',(1,.42,.03)),
                        ('green',(.08,1,.04))):
        matches=[o for o in bpy.data.objects if o.name.startswith('Condenser '+label+' indicator') and 'domed diode cover' in o.name]
        if len(matches)!=1:
            raise RuntimeError('Original condenser indicator missing: '+label)
        diodes.append(make_point('FX ONLY | '+label+' existing diode',centroid(matches[0]),color,fx))
    scene.render.engine='CYCLES'
    scene.cycles.samples=20
    scene.render.threads_mode='FIXED'
    scene.render.threads=4
    scene.render.film_transparent=True
    scene.render.resolution_x=scene.render.resolution_y=256
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.frame_start=1
    scene.frame_end=96
    scene.render.fps=FREQUENCY
    base=root.location.copy()
    for frame in FRAME_IDS+[97]:
        phase=((frame-1)%96)/96
        wave=2*math.pi*phase
        # Entire approved rack/mount vibrates < 2mm per unit tile.
        root.location=base+Vector((.0012*math.sin(4*wave),
                                   .0007*math.sin(7*wave+.4),
                                   .0009*math.sin(6*wave+.2)))
        root.rotation_euler.z=math.radians(.12)*math.sin(3*wave)
        root.keyframe_insert(data_path='location',frame=frame)
        root.keyframe_insert(data_path='rotation_euler',frame=frame)
        display.data.energy=0.11+0.12*(1+math.sin(5*wave))*.5
        display.data.keyframe_insert(data_path='energy',frame=frame)
        for idx,light in enumerate(diodes):
            light.data.energy=.012+.11*(1 if ((frame-1)//12+idx)%4==0 else 0)
            light.data.keyframe_insert(data_path='energy',frame=frame)
    scene.frame_set(1)
    scene['model']='Atmospheric Water Condenser'
    scene['model_source_revision']='approved V21 unchanged'
    scene['animation_review_revision']='V22 review-only candidate'
    scene['model_source_sha256']=APPROVED_SHA
    scene['native_game_art_modified']=False
    scene['no_fluid_or_synthetic_machine_additions']=True
    scene['new_visible_geometry_count']=0
    blend=out/'condenser_v22_motion_review.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    frames=[]
    for f in FRAME_IDS:
        scene.frame_set(f)
        dest=out/f'frame_{f:03d}.png'
        scene.render.filepath=str(dest)
        bpy.ops.render.render(write_still=True)
        if not dest.is_file() or dest.stat().st_size<1000:
            raise RuntimeError('Native condenser render missing: '+str(dest))
        frames.append(dest)
    receipt={'model':'condenser','source_sha256':APPROVED_SHA,
             'candidate_revision':'V22','camera':camera_record(scene),
             'single_fixed_FMPL_45_camera':True,'frame_count':len(frames),
             'frame_sha256':{p.name:source_sha(p) for p in frames},
             'original_geometry_added':False,'output_game_assets_changed':False,
             'owner_visual_approval':'PENDING'}
    (out/'condenser_v22_motion_manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('CONDENSER_V22_REAL_BLENDER_REVIEW_READY '+json.dumps({'frames':len(frames),'source_sha256':APPROVED_SHA}),flush=True)


if __name__=='__main__':
    a=argparse.ArgumentParser()
    a.add_argument('--source-blend',required=True,type=Path)
    a.add_argument('--out',required=True,type=Path)
    argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    args=a.parse_args(argv)
    run(args.source_blend,args.out)