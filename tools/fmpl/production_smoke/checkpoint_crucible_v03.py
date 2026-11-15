"""Package surfaced six-blade crucible, real state captures and original SFX."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image,ImageDraw


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n')


def record_consumers(repo,out):
    path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(path.read_text());previous=sha(path)
    provenance=json.loads((out/'part_provenance.json').read_text());entries=[]
    for instance in provenance['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision'])
        master=path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen shared master changed')
        consumer=dict(machine='metallization-crucible',machine_revision='V03 finish/state candidate',instance=instance['instance'],transform=instance['transform'],
            model_source_sha256=sha(out/'crucible-v03.blend'),runtime_export_sha256=sha(out/'crucible-v03.glb'),
            status='Derived from actual V01 appended instances and retained in V03 source/export; local CRT state retimed, masters unchanged')
        if not any(c.get('model_source_sha256')==consumer['model_source_sha256'] and c.get('instance')==consumer['instance'] for c in part['consumers']):part['consumers'].append(consumer)
        entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['metallization-crucible']=entries;write(path,registry)
    return sha(path)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--audio',required=True);ap.add_argument('--repo',default='.');args=ap.parse_args()
    repo=Path(args.repo).resolve();src=Path(args.source).resolve();audio=Path(args.audio).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/metallization-crucible/v03-finish-and-states'
    aout=repo/'art/source-to-3d/shared-audio/hydrogen-machinery/crucible-v01'
    if out.exists() or aout.exists():raise FileExistsError('Preserve candidate/audio snapshots')
    source=src/'crucible-v03.blend';glb=src/'crucible-v03.glb';cap=src/'captures'
    reports={}
    for folder in ('mechanics','export-mechanics'):
        row=json.loads((src/folder/'mechanical-readback.json').read_text());reports[folder]=row
        if not row['passed'] or row['source_sha256']!=sha(source) or len(row['fan_blade_contacts'])!=102:raise RuntimeError('Fan/geometry gate '+folder)
    if reports['export-mechanics']['artifact_sha256']!=sha(glb):raise RuntimeError('Wrong runtime artifact')
    export=json.loads((src/'export-readback.json').read_text())
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb):raise RuntimeError('Export gate')
    capture=json.loads((cap/'capture.json').read_text())
    if capture['source_sha256']!=sha(source) or len(capture['frames'])!=36:raise RuntimeError('Capture source/count')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture '+name)
    out.mkdir(parents=True);aout.mkdir(parents=True)
    for root in (out,aout):(root/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('crucible-v03.blend','crucible-v03.glb','working-front.png','port_manifest.json','part_provenance.json','construction-receipt.json','export-readback.json'):shutil.copy2(src/name,out/name)
    for name in ('textures','mechanics','export-mechanics','export-details','captures'):shutil.copytree(src/name,out/name,ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    areceipt=json.loads((audio/'audio-receipt.json').read_text())
    if not areceipt['passed'] or areceipt['compressor_comparison']['effective_rms_difference_db']>-3:raise RuntimeError('Audio/mix gate')
    (aout/'masters').mkdir()
    for row in areceipt['assets']:
        for ext in ('wav','ogg'):
            p=audio/(row['name']+'.'+ext)
            if sha(p)!=row[ext+'_sha256']:raise RuntimeError('Audio bytes changed')
            shutil.copy2(p,aout/'masters'/p.name)
    shutil.copy2(audio/'audio-receipt.json',aout/'audio-receipt.json')
    mod=aout/'review-mod/tp-mh7-crucible-audio_0.0.1';(mod/'sound').mkdir(parents=True)
    for p in audio.glob('*.ogg'):shutil.copy2(p,mod/'sound'/p.name)
    write(mod/'info.json',dict(name='tp-mh7-crucible-audio',version='0.0.1',title='Crucible authored pressure and cooling audio',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','? tp-mh7-crucible-review >= 0.0.1']))
    (mod/'data-updates.lua').write_text("""local m=data.raw['assembling-machine']['tp-mh7-review-crucible']
if m then
 local root='__tp-mh7-crucible-audio__/sound/'
 m.working_sound={sound={filename=root..'crucible-working.ogg',volume=.65,audible_distance_modifier=2,priority=40,preload=true},
  idle_sound={filename=root..'crucible-idle.ogg',volume=.10,audible_distance_modifier=.75},
  activate_sound={filename=root..'crucible-start.ogg',volume=.70,audible_distance_modifier=1.75},
  deactivate_sound={filename=root..'crucible-stop.ogg',volume=.60,audible_distance_modifier=1.5},
  match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
 log('TP_MH7_CRUCIBLE_AUDIO_BOUND')
end
""")
    (aout/'README.md').write_text('# Crucible audio supplement\n\nOriginal authored induction/contactor hum, damped pressure-cabinet resonance and closed cooling wash, plus idle, start and shutdown cues. Eight-second working loop. Decode, headroom and loop-seam checks pass. At configured .65 gain the working bed measures about 7 dB below the compressor at 1.15; the compressor remains the foreground racket. No recordings or third-party music.\n\nThe add-on is prepared for the native crucible review prototype. Its actual binding/load and ordinary chain integration remain pending. Previous machinery audio V01 remains immutable. Owner audition is not inferred.\n')
    def panel(state,i):
        image=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(image)
        for slot,(label,direction) in enumerate((('North',0),('East',3),('South',2),('West',1))):
            x=slot%2*256;y=slot//2*276
            with Image.open(cap/f'frames/{state}/d{direction:02d}/f{i:03d}.png') as frame:
                frame=frame.convert('RGBA');image.paste(frame,(x,y),frame.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return image
    panel('idle',0).save(out/'crucible-four-angle-idle.png');frames=[panel('working',i) for i in range(8)]
    frames[0].save(out/'crucible-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=1000,loop=0,disposal=2)
    tmp=out/'preview-frames';tmp.mkdir()
    for i,frame in enumerate(frames):frame.save(tmp/f'{i:03d}.png')
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','1','-i',str(tmp/'%03d.png'),'-i',str(aout/'masters/crucible-working.wav'),'-t','8','-c:v','libx264','-r','24','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out/'crucible-working-with-sound.mp4')],check=True)
    shutil.rmtree(tmp)
    registry_sha=record_consumers(repo,out)
    checkpoint=dict(status='surfaced_six_blade_state_candidate; native_placement_pending',source_sha256=sha(source),glb_sha256=sha(glb),
        registry_sha256=registry_sha,
        surface_map_count=12,assembly_contacts=len(reports['mechanics']['contacts']),core_rays_each=reports['mechanics']['core_rays'],
        fan_blades=6,fan_root_contacts_per_artifact=102,fan_surface_pair_checks_each=reports['mechanics']['fan_surface_pair_checks'],
        source_and_export_passed=True,capture_frames=36,atlas_count=6,cycle_seconds=8,
        source_of_owner_correction='One original blade floated .1076 tile from the bearing. Rebuilt in a common rotor-local frame with six pitched roots seated into a real rotating hub and supported fixed spindle.',
        owner_approved=False,native_pipe_verified=False,native_audio_binding_verified=False,
        output='Raw solid metallicized pellets, with tested random HP/quality decay to inert; no second gameplay fluid box',
        decay_delivery='../../pellet-instability/v01-native-behavior',
        next=['Native 5x5 crucible with one hydrogen fluid input and raw pellet item output','Native inlet fitting, item pickup access and actual animation clocks','Owner finish/audio review and ordinary chain integration'])
    write(out/'CHECKPOINT.json',checkpoint)
    reference=repo/'art/source-to-3d/metallic-hydrogen-chain/water-purifier/v16-owner-accepted/purifier-four-angle-idle.png'
    write(out/'VISUAL_REVIEW.json',dict(status='reviewed_candidate; owner_and_native_pending',source_sha256=sha(source),glb_sha256=sha(glb),reference_sha256=sha(reference),
        render_hashes={p.name:sha(p) for p in (out/'export-details').glob('*.png')},scores={
            'silhouette':dict(score=4,reason='Dominant closed graded pressure chamber, four heavy grounded haunches, reachable hatch/corridor, independent injector and protected pellet transfer.'),
            'construction':dict(score=4,reason='Actual source/export contacts and traced cores pass. Six pitched blades visibly seat into the rotor hub; fixed spindle, bearing, retaining cap and guard support the cooling assembly. Earlier floating blade is excluded.'),
            'surfaces':dict(score=4,reason='Twelve packed image maps follow real shell/crown, cast-haunch and rolled-cover regions; band/hatch/nozzle contact dirt, crown turning and casting edge wear replace generic donor clouds. Actual exported closeups inspected.'),
            'states':dict(score=4,reason='True idle/stopped fan and lowered CRT versus closed working vessel with coherent eight-second fan/readout; 36 actual renders, six atlases and reopened master pass.'),
            'native_integration':dict(score=0,reason='Actual crucible native placement and one-fluid/item-output fixture still required; raw-pellet decay behavior is independently native-tested in its own fixture.')}))
    (out/'README.md').write_text('# Crucible V03 finish and state candidate\n\nTwelve model-specific PBR maps finish the real pressure shell/crown, red cast haunches and supported removable flank shields. Original pipe corrections are preserved. The owner caught a sparse/floating fan blade; actual inspection measured a .1076-tile gap. The replacement has six broad pitched blades seated in a rotating hub, a separate cabinet bearing/spindle and retained cap. Source and real GLB each pass 102 blade-root contacts across 17 poses plus fan/guard and blade/blade clearance, recorded assembly contacts and full process-core rays. Actual exported fan and pipe closeups were viewed.\n\nFour idle angles and eight working poses per angle are captured over eight seconds, with six 64/128/256 atlases, reopened editable capture master and an MP4 paired with the original pressure/cooling audio. Native sound binding and native crucible placement are still pending.\n\nThe owner specified raw solid pellets with random HP/quality decay to inert. The separate pellet-instability behavior delivery implements that in actual Factorio tests, including containment without healing or timer refresh. The output transfer housing is therefore an item interface, not a second native fluid connection. Final pickup access, recipes and chain integration remain open. This is a reviewed candidate, not owner finish acceptance.\n',encoding='utf-8')
    for root in (out,aout):write(root/'SHA256.json',{p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    cont=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(cont.read_text());d['current_candidate']=str(out);d['crucible']=checkpoint;d['library_registry_sha256']=registry_sha
    d['pellet_instability']=dict(path='art/source-to-3d/metallic-hydrogen-chain/pellet-instability/v01-native-behavior',native_continuous_and_reload_verified=True,ordinary_chain_integrated=False)
    for row in d['queue']:
        if row['id']=='metallization-crucible':row['status']='surfaced six-blade/four-angle/audio candidate; native one-fluid/item-output fixture next'
    write(cont,d);print('CRUCIBLE_V03_PACKAGED',out,flush=True)


if __name__=='__main__':main()
