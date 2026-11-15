"""Preserve dedicated surfaces, verified four-view states and original audio."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image,ImageDraw
from run_compressor_native_jig import sha
from checkpoint_assembler_v01 import write


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--audio',required=True);ap.add_argument('--repo',default='.')
    args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve();audio=Path(args.audio).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/canister-assembler/v03-finish-and-states';aout=repo/'art/source-to-3d/shared-audio/hydrogen-machinery/assembler-v01'
    if out.exists() or aout.exists():raise FileExistsError('Preserve prior deliveries')
    source=src/'assembler-v03.blend';glb=src/'assembler-v03.glb';source_hash=sha(source);glb_hash=sha(glb)
    names=['export-readback.json','source-motion.json','runtime-motion.json','feed-readback.json','inspection/assembler-readback.json','details-verified/finish-readback.json']
    reports={n:json.loads((src/n).read_text()) for n in names}
    for name,r in reports.items():
        if r.get('source_sha256',r.get('native_sha256'))!=source_hash:raise RuntimeError('Stale source '+name)
        if name!='source-motion.json' and r['glb_sha256']!=glb_hash:raise RuntimeError('Stale export '+name)
    if any(not reports[n]['passed'] for n in ['export-readback.json','feed-readback.json','details-verified/finish-readback.json']):raise RuntimeError('Export/feed/finish gate')
    inspection=reports['inspection/assembler-readback.json'];finish=reports['details-verified/finish-readback.json']
    if not inspection['recorded_contacts_passed'] or not inspection['work_loop_passed'] or inspection['centerline_obstructions']:raise RuntimeError('Contacts/loop')
    for n in ['source-motion.json','runtime-motion.json']:
        if not reports[n]['reviewed_contacts_passed'] or reports[n]['unexpected_pairs'] or reports[n]['samples']!=1538:raise RuntimeError('Motion '+n)
    capture=json.loads((src/'captures/capture.json').read_text());qa=json.loads((src/'captures/qa.json').read_text());reopen=json.loads((src/'captures/reopen-qa.json').read_text())
    if capture['source_sha256']!=source_hash or len(capture['frames'])!=68 or not qa['passed'] or not reopen['passed'] or sha(src/'captures/master.blend')!=capture['master_sha256']:raise RuntimeError('Capture/reopened master')
    for row in capture['frames']:
        if sha(src/'captures'/row['path'])!=row['sha256']:raise RuntimeError('Changed frame')
    areport=json.loads((audio/'audio-receipt.json').read_text())
    if not areport['passed'] or areport['compressor_comparison']['effective_rms_difference_db']>-6:raise RuntimeError('Audio gate')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ['assembler-v03.blend','assembler-v03.glb','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json']+names[:4]:shutil.copy2(src/name,out/name)
    for folder in ['inspection','textures','captures']:shutil.copytree(src/folder,out/folder,ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    shutil.copytree(src/'details-verified',out/'details')
    (aout/'masters').mkdir(parents=True);(aout/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for row in areport['assets']:
        for ext in ('wav','ogg'):
            path=audio/(row['name']+'.'+ext)
            if sha(path)!=row[ext+'_sha256']:raise RuntimeError('Changed audio bytes')
            shutil.copy2(path,aout/'masters'/path.name)
    shutil.copy2(audio/'audio-receipt.json',aout/'audio-receipt.json')
    (aout/'README.md').write_text('# Canister assembler original sound\n\nSixteen-second electric gantry, cap slide/lift, brief pellet gate and filling patter, and restrained sealing drive with seated-cap contact. Separate powered idle, contactor startup and drive rundown. Original oscillators, seeded noise and resonances; no borrowed samples. Decoded headroom and seam checks pass. Planned .65 working gain places it about 13.6 dB below the compressor. The video uses matching .25-second source phase. Native binding, native sound-phase synchronization and owner audition remain pending.\n',encoding='utf-8')
    def four(state,index):
        image=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(image)
        for slot,(label,direction) in enumerate([('North',0),('East',3),('South',2),('West',1)]):
            x=slot%2*256;y=slot//2*276
            with Image.open(out/f'captures/frames/{state}/d{direction:02d}/f{index:03d}.png') as im:
                im=im.convert('RGBA');image.paste(im,(x,y),im.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return image
    four('idle',0).save(out/'assembler-four-angle-idle.png');frames=[four('working',i) for i in range(16)]
    frames[0].save(out/'assembler-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=1000,loop=0,disposal=2)
    sheet=Image.new('RGB',(2048,576),(33,35,38));draw=ImageDraw.Draw(sheet)
    for direction,label in enumerate(['North','West','South','East']):
        for index in range(16):
            with Image.open(out/f'captures/frames/working/d{direction:02d}/f{index:03d}.png') as im:
                im=im.convert('RGBA').resize((128,128),Image.Resampling.LANCZOS);sheet.paste(im,(index*128,direction*144),im.getchannel('A'))
            draw.text((index*128+4,direction*144+128),f'{label} {index+.25:g}s',fill='white')
    sheet.save(out/'assembler-working-contact-sheet.png')
    tmp=out/'preview-frames';tmp.mkdir()
    for index,frame in enumerate(frames):frame.save(tmp/f'{index:03d}.png')
    subprocess.run(['ffmpeg','-v','error','-framerate','1','-i',str(tmp/'%03d.png'),'-stream_loop','-1','-ss','0.25','-i',str(aout/'masters/assembler-working.wav'),'-t','16','-af','volume=0.65','-c:v','libx264','-r','24','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out/'assembler-working-with-sound.mp4')],check=True)
    if tmp.resolve().parent!=out or not out.is_relative_to(repo):raise RuntimeError('Unsafe preview cleanup')
    shutil.rmtree(tmp)
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Shared master changed')
        consumer=dict(machine='canister-assembler',machine_revision='V03 dedicated surfaces, four-view states and original sound',instance=instance['instance'],transform=instance['transform'],model_source_sha256=source_hash,runtime_export_sha256=glb_hash,status='Unchanged appended console; actual source/export mechanics, surfaces and captures pass agent review; native pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer));component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    if sha(registry_path)!=previous:raise RuntimeError('Concurrent registry change')
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['canister-assembler']=entries;write(registry_path,registry)
    checkpoint=json.loads((repo/'art/source-to-3d/metallic-hydrogen-chain/canister-assembler/v02-clearance-and-cadence/CHECKPOINT.json').read_text())
    next_steps=['Implement native live formed-pellet and shell sealing without HP/quality/decay reset; verify actual inserters, output blocks and mid-cycle reload','Bind appropriate original sound and prove exact sixteen-second native clock in all four directions','Refine three reactors, then remaining sprite-only buildings and ordinary chain/UI/economy integration']
    checkpoint.update(status='dedicated_finish_four_direction_states_and_original_sound_saved; native_pending',source_sha256=source_hash,glb_sha256=glb_hash,library_registry_sha256=sha(registry_path),triangles=reports['export-readback.json']['runtime_stats']['triangles'],dedicated_surfaces_complete=True,authored_maps=30,preserved_geometry_meshes=finish['preserved_meshes'],actual_glb_diagnostic_views=8,capture_frames=68,atlas_count=6,audio_implemented=True,native_audio_binding_verified=False,native_phase_synchronization_verified=False,native_verified=False,audio_delivery=str(aout),next=next_steps)
    write(out/'CHECKPOINT.json',checkpoint)
    write(out/'VISUAL_REVIEW.json',dict(status='agent-reviewed art/state candidate; owner/native pending',source_sha256=source_hash,glb_sha256=glb_hash,owner_approved=False,final_threshold_unchanged=4,reference_sha256=sha(repo/'art/source-to-3d/metallic-hydrogen-chain/pelletization-forge/v03-finish-and-states/export-inspection/front.png'),
        scores=dict(silhouette=dict(score=4,reason='Three distinct supported vessels, rear gantry, exposed cap slides and open hollow travelling head remain legible in four canonical views.'),construction=dict(score=4,reason='All 201 recorded contacts, source/export quarter-frame motion and complete authored core probes pass. No attachment threshold was relaxed.'),surfaces=dict(score=4,reason='Thirty actual maps follow canister circumference and band seats, bare formed shoulders, gantry members, slide lands, tool housing, electrical contacts and metering hardware. Corrected round normals remove shoulder/hopper faceting. Actual exported front/rear/joint/clay views inspected against surfaced forge family.'),states=dict(score=4,reason='Actual sixteen-second source/export, four idle and 64 working captures, six atlases and source-bound reopened master. Original sound preview matches sampled phase.'),native=dict(score=0,reason='Live-stack assembly, inserter cases, sound binding and exact native clock remain open.')),
        render_hashes={r['view']:r['sha256'] for r in finish['views']}))
    (out/'README.md').write_text('# Canister assembler V03 finish and states\n\nThe proven three-vessel indexed mechanism retains its sixteen-second cycle and all V02 geometry. Thirty dedicated PBR maps distinguish cylindrical vessel enamel and band seats, bare formed shoulders, red frame members, ground guide/ram lands, cast tooling, hopper/feed, bronze retainers, current contacts and mineral footing. Actual round normals are corrected while preserving hard profile edges. The appended shared cogitator is unchanged.\n\nSource and independently imported GLB pass all 201 attachments, 1,538 quarter-frame motion samples each, 1,512 combined core-path rays, closed gate/lids/bottoms and landed-punch checks. Actual GLB PBR, eight front/rear/closeup/clay views and unchanged source mesh digests pass. These are bounded geometric checks, not continuous collision proof, granular simulation or pressure certification.\n\nFour actual model rotations produce four idle plus 64 working frames, six 64/128/256 atlases and a source-bound reopened master. Sixteen one-second cells retain the source clock. The phase-aligned MP4 uses original cap, pellet gate, sealer and gantry sound at planned gain, about 13.6 dB below the compressor. Native sound synchronization and owner audition are not inferred.\n\nThis is agent-reviewed art. Live-state native sealing, actual inserter input/output, quality/integrity/remaining-decay preservation, blocked output, save/reload, sound binding and exact native clock remain required. No external gameplay fluid ports are assigned to this solid-input assembler. Ordinary chain integration, three reactors and the remaining sprite-only building work also remain open.\n',encoding='utf-8')
    for folder in (aout,out):write(folder/'SHA256.json',{p.relative_to(folder).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d.update(current_machine='canister-assembler',current_candidate=str(out),assembler=checkpoint,library_registry_sha256=sha(registry_path),next_steps=next_steps)
    for row in d['queue']:
        if row['id']=='canister-assembler':row['status']='V03 dedicated finish, four-direction states and original sound saved; live-state native assembly next'
    write(path,d);print('ASSEMBLER_V03_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
