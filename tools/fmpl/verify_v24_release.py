"""Verify approved V24 source, all 105 PNGs, frame rate and prototype hookup."""
import argparse,json,math,zipfile
from pathlib import Path
from verify_v22c_release import file_record,fail_if,sha256

SPRITES='graphics/entity/atmospheric-water-condenser-v24'
APPROVED_SOURCE='1bf12339ad62855b032665e76aeda540a4ede3d301fa57e45bd766ca1444e037'

def validate(mod_dir):
    mod_dir=Path(mod_dir);images=mod_dir/SPRITES
    m=json.loads((images/'atlas_manifest.json').read_text())
    fail_if(m['schema']!='tech-priests.condenser-v24-factorio-atlases.v1','Wrong schema')
    fail_if(m['source_sha256']!=APPROVED_SOURCE or m['native_scene_sha256']!=APPROVED_SOURCE,'Wrong approved V24 source')
    fail_if(m.get('owner_visual_approved') is not True,'Owner approval missing')
    fail_if(m.get('original_source_meshes_changed') is not True or m.get('authorized_geometry_delta')!='eight seat bores and rack perforations, sixteen recessed liners/floors','Authorized inlet geometry delta missing')
    fail_if(m.get('generated_image_art_or_fabricated_pixels') is not False,'Native source proof absent')
    fail_if(m['source_frame_sequence']!=list(range(1,97)) or m['actual_factorio_animation_frames']!=96,'Missing or shuffled frames')
    fail_if(m['cycle_seconds']!=12 or not math.isclose(m['factorio_animation_speed_frames_per_tick'],96/720),'Wrong cycle speed')
    fail_if(m['blender_yaw_to_factorio']!={'0':'north','90':'west','180':'south','270':'east'},'Wrong cardinal registration')
    fail_if(m['orientation_angles']!=[0,90,180,270],'Missing direction')
    fail_if(m['factorio_output_connection_local']!=[.5,.5] or m['nominal_collision_footprint_tiles']!=[2,2],'Port or footprint moved')
    fail_if((m['hr_frame_px'],m['sd_frame_px'],m['hr_factorio_scale'],m['sd_factorio_scale'])!=(512,256,.24,.48),'HR/SD size or world scale drift')
    seen=set()
    for face in ('north','east','south','west'):
        for quality,size in (('hr',512),('sd',256)):
            record=m['files'][face][quality]
            fail_if(len(record['activity_slices'])!=12,'Missing animation slice')
            for i,r in enumerate(record['activity_slices']):
                fail_if(r['name']!=f'active-{face}-{quality}-{i:02d}.png','Unordered slice')
                seen.add(file_record(images,r,(size*4,size*2)))
            idle=record['idle_repeated_slice']
            fail_if(idle['name']!=f'idle-{face}-{quality}.png','Wrong idle')
            seen.add(file_record(images,idle,(size*4,size*2)))
    seen.add(file_record(images,m['icon'],(64,64)))
    fail_if(len(seen)!=105 or {p.name for p in images.glob('*.png')}!=seen,'Expected exactly 105 PNGs')
    lua=(mod_dir/'prototypes/generated_graphics/atmospheric-water-condenser-v24.lua').read_text()
    for token in ('local FRAMES = 96','local SLICES = 12','slice=SLICE_SIZE','lines_per_file=2','animation_speed=FRAMES / TICKS_PER_CYCLE','port.position={0.5,0.5}',"local captured = {north='north', east='east', south='south', west='west'}","resolution = quality == 'standard' and 'sd' or 'hr'","frame_size = resolution == 'sd' and 256 or 512","world_scale = resolution == 'sd' and 0.48 or 0.24"):
        fail_if(token not in lua,'Lua contract missing '+token)
    fixes=(mod_dir/'data-final-fixes.lua').read_text()
    hook='require("prototypes.generated_graphics.atmospheric-water-condenser-v24")'
    prior='require("prototypes.generated_graphics.atmospheric-water-condenser-v22c")'
    fail_if(fixes.count(hook)!=1 or fixes.index(hook)<fixes.index(prior),'V24 final override missing or incorrectly ordered')
    return {'status':'PASS','png_assets':105,'native_captured_frames':384,'frames_per_direction':96,'fps':8,'cycle_seconds':12,'source_sha256':APPROVED_SOURCE,'quality_modes':['auto','high','standard'],'pipe_local':[.5,.5]}

def verify_archive(path,mod_name,mod_version):
    with zipfile.ZipFile(path) as z:
        base=f'{mod_name}_{mod_version}/{SPRITES}/'
        m=json.loads(z.read(base+'atlas_manifest.json'))
        for record in [r for quality in m['files'].values() for pack in quality.values() for r in [*pack['activity_slices'],pack['idle_repeated_slice']]]+[m['icon']]:
            fail_if(sha256(z.read(base+record['name']))!=record['sha256'],'Packaged PNG mismatch '+record['name'])
    return True

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--mod-dir',type=Path,required=True);p.add_argument('--release',type=Path)
    a=p.parse_args();result=validate(a.mod_dir)
    if a.release:
        info=json.loads((a.mod_dir/'info.json').read_text());verify_archive(a.release,info['name'],info['version']);result['archive_verified']=True
    print('CONDENSER_V24_RELEASE_INTEGRATION_PASS',json.dumps(result,sort_keys=True))
