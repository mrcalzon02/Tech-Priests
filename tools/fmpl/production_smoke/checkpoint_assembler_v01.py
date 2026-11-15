"""Save the three-station pilot and an honest seven-machine render gallery."""
import argparse
import json
from pathlib import Path
import shutil
from PIL import Image,ImageDraw,ImageFont
from run_compressor_native_jig import sha


def write(path,value):
    path=Path(path);temporary=path.with_suffix(path.suffix+'.tmp');temporary.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');temporary.replace(path)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/canister-assembler/v01-indexed-construction'
    if out.exists():raise FileExistsError('Preserve construction checkpoints')
    source=src/'assembler-v01.blend';glb=src/'assembler-v01.glb';export=json.loads((src/'export-readback.json').read_text());inspection=json.loads((src/'inspection/assembler-readback.json').read_text())
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb):raise RuntimeError('Export gate')
    if not inspection['recorded_contacts_passed'] or not inspection['work_loop_passed'] or inspection['centerline_obstructions'] or inspection['source_sha256']!=sha(source) or inspection['glb_sha256']!=sha(glb):raise RuntimeError('Construction readback gate')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('assembler-v01.blend','assembler-v01.glb','working-front.png','construction-receipt.json','export-readback.json','port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    shutil.copytree(src/'inspection',out/'inspection')
    panel=Image.new('RGB',(1920,640),(30,32,35))
    for index,name in enumerate(('first-station-fill','second-station-cap','third-station')):
        with Image.open(out/'inspection'/(name+'.png')) as image:
            image=image.convert('RGBA');panel.paste(image,(index*640,0),image.getchannel('A'))
    panel.save(out/'indexed-stations.png')
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen shared master changed')
        consumer=dict(machine='canister-assembler',machine_revision='V01 three-indexed-nest construction pilot',instance=instance['instance'],transform=instance['transform'],model_source_sha256=sha(source),runtime_export_sha256=sha(glb),status='Actual unchanged appended assembly retained in source and independently imported GLB; full motion, finish and native pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    if sha(registry_path)!=previous:raise RuntimeError('Concurrent registry change; preserve both candidates for reconciliation')
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['canister-assembler']=entries;write(registry_path,registry)
    next_steps=['Audit complete cap/press/guide/meter/nozzle motion and granular path; slow the short head-index transitions','Finish assembler-specific surfaces and relevant metering/sealing sound','Capture four idle/working directions after pilot refinement','Implement live pellet/shell assembly through the existing seal operation; preserve HP, quality, phase and remaining deadline','Refine three reactors, remaining sprite-only buildings and ordinary chain/UI/economy integration']
    checkpoint=dict(status='saved_source_export_and_indexed_construction_pilot; full_motion_finish_native_pending',source_sha256=sha(source),glb_sha256=sha(glb),library_registry_sha256=sha(registry_path),footprint=[4,4],primary_canisters=3,
        recorded_contacts=len(inspection['contacts']),recorded_contacts_passed=True,work_cycle_seconds=14,station_seconds=4,return_seconds=2,source_loop_matrix_error=inspection['work_loop_matrix_error'],triangles=export['runtime_stats']['triangles'],
        actual_glb_phase_views=3,bounded_vertical_core_probes_passed=True,complete_granular_path_verified=False,full_swept_clearance_verified=False,dedicated_surfaces_complete=False,audio_implemented=False,native_verified=False,owner_approved=False,
        native_contract='Use existing live-stack seal operation. Never heal integrity, improve quality, reset decay stage or refresh remaining instability. Return original shell condition on unseal.',next=next_steps)
    write(out/'CHECKPOINT.json',checkpoint)
    write(out/'VISUAL_REVIEW.json',dict(status='construction pilot; below final gate',source_sha256=sha(source),glb_sha256=sha(glb),owner_approved=False,final_threshold_unchanged=4,
        reference_sha256=sha(repo/'docs/art/metallic-hydrogen-chain/references/metallic_hydrogen_seven_precursor_style_board.jpg'),scores=dict(silhouette=3,construction=3,surfaces=2,states=3,native=0),
        findings=['Three distinct supported canister nests retain the requested three-canister layout. Hollow formed bodies, front witness apertures and supported cap slides establish loading/closing mechanics.',
                  'Rear gantry and open cantilever keep the tool bore clear; offset crank drives an actual sliding pellet gate, rather than rotating a shaft through the feed core.',
                  'Recorded contacts, fourteen-second object-matrix loop and source/export validity pass. Three actual GLB indexed phases were viewed. Packed donor PBR is provisional.',
                  'Full motion and granular-path review, dedicated finish/sound, final four-angle capture and live-state native containment remain required.'],render_hashes={r['view']:r['sha256'] for r in inspection['views']}))
    # Only own model renders, never the concept board or native game pixels.
    family=repo/'art/source-to-3d/metallic-hydrogen-chain';rows=[]
    for number,label,folder,status in [
        (1,'Water purifier','water-purifier/v16-owner-accepted','Owner-accepted art'),
        (2,'Electrolyzer','electrolyzer/v06-owner-accepted-native','Owner-accepted native placement'),
        (3,'Hydrogen compressor','hydrogen-compressor/v05-slow-and-audio','V05 art / V06 native accepted'),
        (4,'Metallization crucible','metallization-crucible/v04-native-production','Restrained animation accepted'),
        (5,'Pelletization forge','pelletization-forge/v03-finish-and-states','V03 art / V04 native checkpoint'),
        (6,'Pressure-vessel fabricator','pressure-vessel-fabricator/v04-native-review','V03 art / V04 native checkpoint')]:
        root=family/folder;image=root/'captures/frames/working/d00/f003.png';capture=json.loads((root/'captures/capture.json').read_text())
        rows.append(dict(stage=number,label=label,image=str(image.relative_to(repo)),image_sha256=sha(image),model_source_sha256=capture['source_sha256'],status=status))
    rows.append(dict(stage=7,label='Canister assembler',image=str((out/'working-front.png').relative_to(repo)),image_sha256=sha(out/'working-front.png'),model_source_sha256=sha(source),status='Construction pilot; finish/native open'))
    if len({r['model_source_sha256'] for r in rows})!=7:raise RuntimeError('Seven-source gallery must contain seven distinct actual sources')
    gallery=Image.new('RGB',(1280,840),(30,32,35));draw=ImageDraw.Draw(gallery);font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
    draw.text((18,12),'Seven distinct saved machine assets — actual model renders',font=font,fill='white')
    draw.text((18,38),'Completion status differs by stage. The assembler is a construction pilot; chain/reactor work remains open.',font=small,fill=(195,200,205))
    for index,row in enumerate(rows):
        x=index%4*320;y=70+index//4*385
        with Image.open(repo/row['image']) as image:
            image=image.convert('RGBA').resize((320,320),Image.Resampling.LANCZOS);gallery.paste(image,(x,y),image.getchannel('A'))
        draw.text((x+12,y+325),f"{row['stage']}. {row['label']}",font=font,fill='white');draw.text((x+12,y+352),row['status'],font=small,fill=(240,183,87) if row['stage']==7 else (180,195,185))
    gallery.save(out/'seven-stage-gallery.png');write(out/'seven-stage-gallery-sources.json',dict(status='Seven different saved model sources; mixed delivery stages, not full goal completion',rows=rows))
    (out/'README.md').write_text('# Three-station canister assembler V01 pilot\n\nThree supported canister nests use newly built hollow shells, shallow front witness openings, retaining bands and independent cap slides. A rear gantry carries one indexed hollow filling/sealing head, a supported moving hopper, an offset-crank sliding pellet gate and a genuine telescoping nozzle/annular punch. The three four-second station phases plus two-second head return form a closed fourteen-second source cycle. The registered cogitator is an unchanged appended library assembly; the machine vessels are new hollow construction, not stretched icon props.\n\nEditable source and actual GLB export pass finite/UV/packed-image checks, all recorded static contacts, source/export sampled poses and exact first/last object matrices. Three actual exported index/closure views were inspected. Two bounded vertical core probes pass. They do not prove complete granular-path clearance or full moving cap/press/guide mechanics. Dedicated model-specific surfaces, sound, full four-angle capture and actual native assembly remain open. Donor maps are provisional. No owner approval is inferred.\n\nNative implementation must use live pellet stacks and the existing seal operation, preserving health, quality, decay stage and remaining deadline. Ordinary recipe conversion must not refresh the pellet. The original pressure-shell condition must survive containment and unsealing. Standard Factorio inserter access is sufficient.\n\nThe seven-stage gallery contains actual own-model renders from seven different saved sources. It explicitly retains each stage status: the assembler pilot is not finished art, and seven saved models do not complete the chain/reactor/remaining-building goal. The concept board and native screenshot pixels are excluded. Earlier failed front-gantry, floating support and blocked-feed studies remain private staging.\n',encoding='utf-8')
    (out/'RESULTS.md').write_text('# Construction checkpoint results\n\nSource, actual GLB, three indexed views, recorded contacts and closed source loop are saved. The seventh distinct machine source completes the initial seven-source construction census only. Full assembler mechanics/finish/audio/capture/native, ordinary chain integration, three reactors and the remaining sprite-only inventory remain open. See CHECKPOINT.json for exact counts and scope, and seven-stage-gallery-sources.json for image/source hashes.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='canister-assembler';d['current_candidate']=str(out);d['assembler']=checkpoint;d['library_registry_sha256']=sha(registry_path);d['next_steps']=next_steps
    for row in d['queue']:
        if row['id']=='canister-assembler':row['status']='V01 three-indexed-station source/export pilot saved; full mechanics/finish/audio/capture/native next'
    write(path,d);print('ASSEMBLER_PILOT_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
