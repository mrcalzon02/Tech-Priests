"""Freeze the surfaced forge, actual artifact readbacks, captures and own SFX."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image,ImageDraw


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,data):Path(p).write_text(json.dumps(data,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--audio',required=True);ap.add_argument('--repo',default='.')
    args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve();audio=Path(args.audio).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pelletization-forge/v03-finish-and-states';aout=repo/'art/source-to-3d/shared-audio/hydrogen-machinery/forge-v01'
    if out.exists() or aout.exists():raise FileExistsError('Preserve forge/audio checkpoints')
    source=src/'forge-v03.blend';glb=src/'forge-v03.glb';cap=src/'captures';reports={}
    for folder,file in [('mechanics','mechanical-readback.json'),('mechanics-export','mechanical-readback.json'),('material-path','material-path-readback.json'),('material-path-export','material-path-readback.json'),('services','service-readback.json'),('services-export','service-readback.json')]:
        row=json.loads((src/folder/file).read_text());reports[folder]=row
        if not row['passed'] or row['source_sha256']!=sha(source):raise RuntimeError('Failed/source-stale readback '+folder)
        if folder.endswith('-export') and row['glb_sha256']!=sha(glb):raise RuntimeError('Stale actual export '+folder)
    export=json.loads((src/'export-readback.json').read_text());inspection=json.loads((src/'export-inspection/export-inspection.json').read_text())
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb) or not inspection['geometry_passed'] or inspection['glb_sha256']!=sha(glb):raise RuntimeError('Export/inspection gate')
    capture=json.loads((cap/'capture.json').read_text())
    if capture['source_sha256']!=sha(source) or len(capture['frames'])!=36:raise RuntimeError('Capture source/count')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    areceipt=json.loads((audio/'audio-receipt.json').read_text())
    if not areceipt['passed'] or areceipt['compressor_comparison']['effective_rms_difference_db']>-3:raise RuntimeError('Audio decode/mix gate')
    receipt=json.loads((src/'construction-receipt.json').read_text())
    if len(receipt['textures'])!=24 or any(sha(row['file'])!=row['sha256'] for row in receipt['textures']):raise RuntimeError('Authored map gate')
    out.mkdir(parents=True);aout.mkdir(parents=True)
    for root in (out,aout):(root/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('forge-v03.blend','forge-v03.glb','working-front.png','port_manifest.json','part_provenance.json','construction-receipt.json','export-readback.json','inspection-panel.png'):shutil.copy2(src/name,out/name)
    for name in ('textures','mechanics','mechanics-export','material-path','material-path-export','services','services-export','export-inspection','details','captures'):
        shutil.copytree(src/name,out/name,ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    (aout/'masters').mkdir()
    for row in areceipt['assets']:
        for ext in ('wav','ogg'):
            path=audio/(row['name']+'.'+ext)
            if sha(path)!=row[ext+'_sha256']:raise RuntimeError('Audio bytes changed')
            shutil.copy2(path,aout/'masters'/path.name)
    shutil.copy2(audio/'audio-receipt.json',aout/'audio-receipt.json')
    mod=aout/'review-mod/tp-mh7-forge-audio_0.0.1';(mod/'sound').mkdir(parents=True)
    for p in audio.glob('*.ogg'):shutil.copy2(p,mod/'sound'/p.name)
    write(mod/'info.json',dict(name='tp-mh7-forge-audio',version='0.0.1',title='Forge authored hydraulic and tooling audio',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','? tp-mh7-forge-review >= 0.0.1']))
    (mod/'data-updates.lua').write_text("""local m=data.raw['assembling-machine']['tp-mh7-review-forge']
if m then
 local root='__tp-mh7-forge-audio__/sound/'
 m.working_sound={sound={filename=root..'forge-working.ogg',volume=.70,audible_distance_modifier=2,priority=40,preload=true},
  idle_sound={filename=root..'forge-idle.ogg',volume=.09,audible_distance_modifier=.75},
  activate_sound={filename=root..'forge-start.ogg',volume=.65,audible_distance_modifier=1.75},
  deactivate_sound={filename=root..'forge-stop.ogg',volume=.55,audible_distance_modifier=1.5},
  match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
 log('TP_MH7_FORGE_AUDIO_BOUND')
end
""")
    (aout/'README.md').write_text('# Forge authored sound\n\nOriginal eight-second hydraulic pump/motor bed, auger feed grit, pressure-load rise, restrained tooling/frame knocks, return-valve wash and small die/tray ticks. Separate powered idle, start and shutdown cues. No sampled or third-party recordings. Decode, headroom and loop-seam checks pass. At .70 gain the working bed is about 7.16 dB below the compressor at 1.15; the compressor retains foreground priority.\n\nThe add-on targets the forthcoming isolated native forge prototype. Actual native binding and event synchronization remain pending; technical audio checks and the phase-aligned render preview do not imply owner audition or ordinary integration.\n')
    def panel(state,i):
        im=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(im)
        for slot,(label,direction) in enumerate((('North',0),('East',3),('South',2),('West',1))):
            x=slot%2*256;y=slot//2*276
            with Image.open(cap/f'frames/{state}/d{direction:02d}/f{i:03d}.png') as frame:
                frame=frame.convert('RGBA');im.paste(frame,(x,y),frame.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return im
    panel('idle',0).save(out/'forge-four-angle-idle.png');frames=[panel('working',i) for i in range(8)]
    frames[0].save(out/'forge-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=1000,loop=0,disposal=2)
    tmp=out/'preview-frames';tmp.mkdir()
    for i,im in enumerate(frames):im.save(tmp/f'{i:03d}.png')
    # First source sample is frame 7 = .25 seconds. Offset the periodic sound
    # by that same phase; retain the honest one-frame-per-second presentation.
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','1','-i',str(tmp/'%03d.png'),'-stream_loop','-1','-ss','0.25','-i',str(aout/'masters/forge-working.wav'),'-t','8','-c:v','libx264','-r','24','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out/'forge-working-with-sound.mp4')],check=True)
    shutil.rmtree(tmp)
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((out/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen library master changed')
        consumer=dict(machine='pelletization-forge',machine_revision='V03 finish/state candidate',instance=instance['instance'],transform=instance['transform'],model_source_sha256=sha(source),runtime_export_sha256=sha(glb),status='Retained actual V01 appended console; unchanged frozen library master. Source/export/geometry/captures pass; native item handling pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['pelletization-forge']=entries;write(registry_path,registry)
    checkpoint=dict(status='surfaced_material_path_and_state_candidate; native_item_processing_pending',source_sha256=sha(source),glb_sha256=sha(glb),registry_sha256=sha(registry_path),footprint=[3,3],surface_map_count=24,
        contacts=len(reports['mechanics']['contacts']),guided_ram_static_pair_checks_each=reports['mechanics']['moving_fixed_pair_checks'],
        visible_stock_poses_each=reports['material-path']['visible_poses'],stock_surface_pair_checks_each=reports['material-path']['nearby_surface_pair_checks'],rotor_static_pair_checks_each=reports['material-path']['rotor_static_pair_checks'],
        hydraulic_core_rays_each=reports['services']['core_rays'],triangles=export['runtime_stats']['triangles'],maximum_sampled_world_pose_error=export['maximum_sampled_world_pose_error'],
        capture_frames=36,atlas_count=6,cycle_seconds=8,audio_implemented=True,native_audio_binding_verified=False,native_item_interfaces_verified=False,ordinary_chain_integrated=False,owner_approved=False,
        material_path_scope='Quarter-frame sampled stock/auger checks in source and actual GLB, not a physical force/volume simulation or continuous mathematical clearance proof.',
        no_new_verified_parts='Machine-local press/auger/hydraulic assemblies are not automatically library-approved.',
        next=['Native 3x3 forge with actual inserter feed/pickup and zero gameplay fluid boxes','Preserve incoming raw pellet HP, quality, stage and remaining instability throughout processing, blockage and save/reload','Verify native animation/audio binding and four orientations','Build vessel fabricator and canister assembler; integrate full chain; recover/refine three reactor sources'])
    write(out/'CHECKPOINT.json',checkpoint)
    reference=repo/'art/source-to-3d/metallic-hydrogen-chain/water-purifier/v16-owner-accepted/working.png'
    write(out/'VISUAL_REVIEW.json',dict(status='reviewed engineering/finish candidate; owner and native pending',source_sha256=sha(source),glb_sha256=sha(glb),reference_sha256=sha(reference),
        render_hashes={p.relative_to(out).as_posix():sha(p) for folder in ('details','export-inspection') for p in (out/folder).glob('*.png')},scores={
            'silhouette':dict(score=4,reason='Distinct open-hopper/guided press with accessible tray and compact side hydraulic pack; coherent red frame, dark iron and brass family at gameplay scale.'),
            'construction':dict(score=4,reason='Raw stock fits the enlarged supported auger and continuous die/discharge route. Die studs now clamp an actual retained flange; hose mouths are straight/coaxial at drilled interfaces, with mounted standoffs and a closed local hydraulic circuit. Source and actual GLB checks pass.'),
            'surfaces':dict(score=4,reason='24 maps distinguish frame enamel, tapered hopper flow wear, ground guides/ram, die annuli, bored crosshead, guide/die seat dirt, chutes and reservoir. Actual export closeups, rear and clay were inspected against accepted family reference.'),
            'states':dict(score=4,reason='Eight-second actual source/GLB press/feed/material cycle, idle plus eight working poses per direction, six atlases and reopened capture master. No ornamental extra motion.'),
            'native_integration':dict(score=0,reason='Actual item handling, state-preserving processing, native animation/sound binding and final ordinary chain still required.')}))
    (out/'README.md').write_text('# Forge V03 finish and state candidate\n\nThe real 3x3 press now has a pellet-sized supported auger, offset open hopper throat, retained die flange and continuous visible loading/compression/ejection path. The original pilot feeder was too small for its stock and its discharge struck the bed; both were repaired. A grounded hydraulic reservoir/motor, two supported hoses and drilled coaxial actuator couplings complete the local service circuit. There are no gameplay fluid ports.\n\nSource and actual GLB independently pass quarter-frame stock/all-machine and flight/fixed-machine checks over the eight-second cycle, recorded contacts, guided press clearance, loop closure and 36 local hydraulic core rays each. These are bounded mesh/pose checks, not force, mass-conservation or pressure certification. Actual front/rear/clay, hopper, die loading, compressed press, discharge and hydraulic closeups were inspected.\n\n24 authored maps follow the actual frame edges, hopper descent/corners, press tooling, die annuli, guide/die mounting seats, chute contact lanes and reservoir seams. The editable source, runtime GLB, four idle views, 32 working views, six 64/128/256 atlases and reopened capture master are included. The eight-second four-view MP4 pairs the sampled renders with original forge audio at matching .25-second source phase. The compressor remains louder.\n\nThis is a finished-art candidate, not owner acceptance or native/economy completion. Native item processing must preserve the incoming pellet HP, native quality, decay stage and remaining deadline. Ordinary recipe conversion must not refresh it. Actual inserter handling, blocked output, save/reload, sound binding and native playback are next; no additional crucible animation is requested.\n',encoding='utf-8')
    for root in (out,aout):write(root/'SHA256.json',{p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pelletization-forge';d['current_candidate']=str(out);d['forge']=checkpoint;d['library_registry_sha256']=sha(registry_path)
    d['forge']['audio_delivery']=aout.relative_to(repo).as_posix()
    for row in d['queue']:
        if row['id']=='pelletization-forge':row['status']='24-map/source-export material-path and four-angle state candidate with own sound; native state-preserving processing next'
    d['next_steps']=checkpoint['next'];write(path,d);print('FORGE_V03_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
