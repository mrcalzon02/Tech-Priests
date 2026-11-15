"""Package reviewed fabricator finish, states and original audio; native remains open."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image,ImageDraw


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.');ap.add_argument('--audio',required=True)
    args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve()
    audio=Path(args.audio).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pressure-vessel-fabricator/v03-finish-and-states'
    if out.exists():raise FileExistsError('Preserve published revisions')
    source=src/'fabricator-v03.blend';glb=src/'fabricator-v03.glb';source_sha=sha(source);glb_sha=sha(glb)
    reports={name:json.loads((src/name).read_text()) for name in ('export-readback.json','source-motion.json','runtime-motion.json','flow-readback.json','inspection/hydroforming-readback.json','details-verified/finish-readback.json')}
    for name,d in reports.items():
        if d.get('source_sha256',d.get('native_sha256'))!=source_sha:raise RuntimeError(name+' source hash')
        if name!='source-motion.json' and d['glb_sha256']!=glb_sha:raise RuntimeError(name+' export hash')
    if not reports['export-readback.json']['passed'] or not reports['flow-readback.json']['passed']:raise RuntimeError('Export/flow gate')
    for name in ('source-motion.json','runtime-motion.json'):
        if not reports[name]['reviewed_contacts_passed'] or reports[name]['samples']!=1154:raise RuntimeError('Sampled motion gate')
    inspection=reports['inspection/hydroforming-readback.json']
    finish=reports['details-verified/finish-readback.json']
    if not finish['passed'] or finish['authored_maps']!=24:raise RuntimeError('Dedicated finish gate')
    capture=json.loads((src/'captures/capture.json').read_text())
    if capture['source_sha256']!=source_sha or len(capture['frames'])!=52:raise RuntimeError('Capture source/count')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((src/'captures'/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    areport=json.loads((audio/'audio-receipt.json').read_text())
    if not areport['passed'] or areport['compressor_comparison']['effective_rms_difference_db']>-3:raise RuntimeError('Audio gate')
    if not inspection['morph_passed'] or not inspection['recorded_contacts_passed']:raise RuntimeError('Morph/contact gate')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('fabricator-v03.blend','fabricator-v03.glb','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json','export-readback.json','source-motion.json','runtime-motion.json','flow-readback.json'):
        shutil.copy2(src/name,out/name)
    shutil.copytree(src/'inspection',out/'inspection')
    for folder in ('textures','captures'):shutil.copytree(src/folder,out/folder,ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    shutil.copytree(src/'details-verified',out/'details')
    panel=Image.new('RGB',(1920,640),(30,32,35))
    for i,name in enumerate(('plate-welding-open','clamped-expanding','formed-vessel-exposed')):
        with Image.open(out/'inspection'/(name+'.png')) as im:
            im=im.convert('RGBA');panel.paste(im,(i*640,0),im.getchannel('A'))
    panel.save(out/'hydroforming-phases.png')
    aout=repo/'art/source-to-3d/shared-audio/hydrogen-machinery/fabricator-v01'
    if aout.exists():raise FileExistsError('Preserve audio checkpoints')
    (aout/'masters').mkdir(parents=True);(aout/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for row in areport['assets']:
        for ext in ('wav','ogg'):
            path=audio/(row['name']+'.'+ext)
            if sha(path)!=row[ext+'_sha256']:raise RuntimeError('Audio bytes changed')
            shutil.copy2(path,aout/'masters'/path.name)
    shutil.copy2(audio/'audio-receipt.json',aout/'audio-receipt.json')
    mod=aout/'review-mod/tp-mh7-fabricator-audio_0.0.1';(mod/'sound').mkdir(parents=True)
    for path in audio.glob('*.ogg'):shutil.copy2(path,mod/'sound'/path.name)
    write(mod/'info.json',dict(name='tp-mh7-fabricator-audio',version='0.0.1',title='Fabricator authored welding and pressure audio',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','? tp-mh7-fabricator-review >= 0.0.1']))
    (mod/'data-updates.lua').write_text("""local m=data.raw['assembling-machine']['tp-mh7-review-fabricator']
if m then
 local root='__tp-mh7-fabricator-audio__/sound/'
 m.working_sound={sound={filename=root..'fabricator-working.ogg',volume=.70,audible_distance_modifier=1.8,priority=30,preload=true},
  idle_sound={filename=root..'fabricator-idle.ogg',volume=.08,audible_distance_modifier=.75},
  activate_sound={filename=root..'fabricator-start.ogg',volume=.55,audible_distance_modifier=1.5},
  deactivate_sound={filename=root..'fabricator-stop.ogg',volume=.45,audible_distance_modifier=1.25},
  match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
 log('TP_MH7_FABRICATOR_AUDIO_BOUND')
end
""",encoding='utf-8')
    (aout/'README.md').write_text('# Fabricator authored sound\n\nOriginal twelve-second seam-welding crackle, clamp drive and loaded forming-pump loop with restrained pressure return. Separate powered idle, start and shutdown. Oscillators, seeded filtered noise and resonances only; no sampled or third-party recordings. Decoded headroom and loop-seam checks pass. At planned .70 gain it is about 10 dB below the compressor, preserving the owner-requested compressor priority.\n\nThe add-on targets the forthcoming isolated fabricator prototype. Native binding, native phase synchronization and owner audition remain pending. The video uses the actual capture phase (.25 seconds) and planned .70 gain; it is a render/audio preview, not engine evidence.\n',encoding='utf-8')
    def four_views(state,index):
        image=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(image)
        for slot,(label,direction) in enumerate((('North',0),('East',3),('South',2),('West',1))):
            x=slot%2*256;y=slot//2*276
            with Image.open(out/f'captures/frames/{state}/d{direction:02d}/f{index:03d}.png') as frame:
                frame=frame.convert('RGBA');image.paste(frame,(x,y),frame.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return image
    four_views('idle',0).save(out/'fabricator-four-angle-idle.png');frames=[four_views('working',i) for i in range(12)]
    frames[0].save(out/'fabricator-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=1000,loop=0,disposal=2)
    sheet=Image.new('RGB',(1536,576),(33,35,38));draw=ImageDraw.Draw(sheet)
    for direction,label in enumerate(('North','West','South','East')):
        for index in range(12):
            with Image.open(out/f'captures/frames/working/d{direction:02d}/f{index:03d}.png') as image:
                image=image.convert('RGBA').resize((128,128),Image.Resampling.LANCZOS);sheet.paste(image,(index*128,direction*144),image.getchannel('A'))
            draw.text((index*128+4,direction*144+128),f'{label} {index+.25:g}s',fill='white')
    sheet.save(out/'fabricator-working-contact-sheet.png')
    tmp=out/'preview-frames';tmp.mkdir()
    for index,frame in enumerate(frames):frame.save(tmp/f'{index:03d}.png')
    subprocess.run(['ffmpeg','-v','error','-framerate','1','-i',str(tmp/'%03d.png'),'-stream_loop','-1','-ss','0.25','-i',str(aout/'masters/fabricator-working.wav'),'-t','12','-af','volume=0.70','-c:v','libx264','-r','24','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out/'fabricator-working-with-sound.mp4')],check=True)
    if tmp.resolve().parent!=out or not out.is_relative_to(repo):raise RuntimeError('Unsafe temporary cleanup')
    shutil.rmtree(tmp)
    write(aout/'SHA256.json',{p.relative_to(aout).as_posix():sha(p) for p in sorted(aout.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen shared part changed')
        consumer=dict(machine='pressure-vessel-fabricator',machine_revision='V03 dedicated finish, states and original audio',instance=instance['instance'],transform=instance['transform'],model_source_sha256=source_sha,runtime_export_sha256=glb_sha,status='Unchanged appended shared master; source/export bores, sampled motion, dedicated finish and four-direction captures pass; native pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['pressure-vessel-fabricator']=entries;write(registry_path,registry)
    checkpoint=dict(status='reviewed_dedicated_finish_four_direction_states_and_original_audio; native_pending',source_sha256=source_sha,glb_sha256=glb_sha,registry_sha256=sha(registry_path),footprint=[4,4],cycle_seconds=12,
        owner_process='Weld steel plates together, clamp the exposed blank in an open frame, and pump high-pressure forming material through a sealed mandrel to expand it.',
        contacts=len(inspection['contacts']),motion_samples_per_artifact=1154,motion_step_frames=.25,unexpected_sampled_intersections=0,source_and_runtime_core_rays=sum(r['rays'] for stage in ('source','runtime') for r in reports['flow-readback.json'][stage]['paths']),
        deformed_vertex_pose_samples=len(inspection['morph_samples']),maximum_deformed_world_vertex_error=inspection['maximum_deformed_world_vertex_error'],triangles=reports['export-readback.json']['runtime_stats']['triangles'],
        sampled_motion_clearance_verified=True,full_continuous_swept_clearance_verified=False,pressure_core_bore_probes_passed=True,hydraulic_simulation_or_seal_certification=False,
        item_visual_transition='Full-size workpiece retained; native crafting owns item removal. No scaling the neck through the mandrel.',owner_approved=False,dedicated_surfaces_complete=True,authored_maps=24,mounted_details=34,capture_frames=52,atlas_count=6,audio_implemented=True,native_audio_binding_verified=False,native_prototype_verified=False,
        next=['Build native 4x4 fluid/item prototype, real pipe joins and actual animation clock','Build canister assembler, refine three reactors, then remaining sprite-only buildings'])
    write(out/'CHECKPOINT.json',checkpoint)
    write(out/'VISUAL_REVIEW.json',dict(status='agent-reviewed finish/state candidate; owner and native pending',source_sha256=source_sha,glb_sha256=glb_sha,owner_approved=False,final_threshold_unchanged=4,
        reference_sha256=sha(repo/'art/source-to-3d/metallic-hydrogen-chain/pelletization-forge/v03-finish-and-states/export-inspection/front.png'),
        scores=dict(silhouette=dict(score=4,reason='Exposed welded blank, narrow clamping frame, distinct seam-tool gantry and supported pump circuit read clearly at the same family camera.'),
                    construction=dict(score=4,reason='Preserved moving geometry/morph, actual supported 34-detail additions, all contacts and both sampled motion/bore readbacks pass; closeups expose mounting and joint transitions.'),
                    surfaces=dict(score=4,reason='24 real maps follow plate perimeter and rolling direction, actual seam beads, frame edges, clamp wear, pump cabinet/motor, tooling and bronze retainers. Export PBR links and loaded images pass; front/rear/clay/closeups were viewed against the surfaced forge family.'),
                    states=dict(score=4,reason='Actual twelve-second idle/working export, four idle and 48 working captures, six atlases, source-bound master reopen and phase-aligned original sound preview.'),
                    native=dict(score=0,reason='Native 4x4 fluid/item implementation, graphical pipe seating, audio binding and actual clock remain pending.')),
        render_hashes={r['view']:r['sha256'] for r in finish['views']}))
    (out/'README.md').write_text('# Open-frame fabricator V03 finish and state candidate\n\nThe welded two-sheet blank remains exposed in narrow supported clamps. The seam tool traverses its real edge, parks clear, the upper frame clamps and the blank expands while its necks stay fixed. The rear lift uses a grounded clevis/trunnion; a bored reservoir/pump and constant-radius inlet elbow feed the sealed mandrel through a low service corridor. Native crafting owns output: the displayed blank never shrinks through its mandrel.\n\n24 dedicated PBR maps follow actual rolling direction, seam heat and bead travel, frame edges, clamp/guide mating strips, pump cabinet and motor, turned shafts and bronze retainers. Added motor saddles, seated cooling rings, closed service cap, screws and grounded anchors supply 34 mounted details. Preserved source geometry and morph digests are unchanged. Source and actual GLB pass all recorded contacts, 1,154 quarter-frame motion samples each, actual core bore probes and twelve deformed-vertex comparisons. These are geometric checks, not continuous collision proof or hydraulic certification. Actual exported front/rear/clay and weld/clamp/pump/lift/conductor closeups were viewed.\n\nFour actual model rotations produce four idle and 48 working frames, six 64/128/256 atlases and a reopened source-bound master. Twelve working cells each display for one second, preserving the real twelve-second clock. The four-view preview pairs actual captures with original welding, clamp-drive and forming-pump audio at the matching .25-second source phase. Compressor mix priority remains preserved.\n\nThis is agent-reviewed art, not owner approval or native completion. Native 4x4 fluid/item interfaces, actual graphical pipe seating, sound binding, playback clock and ordinary-chain integration remain required. The rejected cube and failed studies remain private. Accepted prior machines are unchanged.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pressure-vessel-fabricator';d['current_candidate']=str(out);d['fabricator']=checkpoint;d['library_registry_sha256']=sha(registry_path);d['next_steps']=checkpoint['next']
    for row in d['queue']:
        if row['id']=='pressure-vessel-fabricator':row['status']='V03 dedicated finish, four-direction states and original audio saved/reviewed; native fluid/item/pipe integration next'
    write(path,d);print('FABRICATOR_V03_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
