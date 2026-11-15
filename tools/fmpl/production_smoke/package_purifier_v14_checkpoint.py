"""Package actual local V14 evidence without promoting failed/incomplete gates."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def read(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))

def write(p,data):
    p=Path(p); temp=p.with_suffix(p.suffix+'.tmp')
    temp.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8'); temp.replace(p)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--staging',required=True)
    ap.add_argument('--out',required=True); args=ap.parse_args()
    root=Path(__file__).resolve().parents[3]; staging=Path(args.staging).resolve()
    out=Path(args.out).resolve()
    if out.exists(): raise FileExistsError('Keep previous checkpoint immutable')
    geometry=read(staging/'independent-readback.json')
    central=read(staging/'central-visual/central-console-visual-proof.json')
    witness=read(staging/'witness-visual/witness-visibility-qa.json')
    steam=read(staging/'steam-qa.json'); atlas=read(staging/'sprites/super-greeble-qa.json')
    census=read(staging/'scene-census.json')
    if geometry['errors'] or not central['passed'] or not witness['passed'] or not atlas['passed']:
        raise RuntimeError('Targeted source/geometry gates incomplete; inspect reports')
    out.mkdir(parents=True)
    for name in ('water-purifier-v14.blend','water-purifier-v14.glb','construction-receipt.json',
                 'independent-readback.json','line-endpoint-census.json','fitted-joints.json',
                 'surface-derivatives.json','idle.png','working.png','runtime-front.png','runtime-clay.png',
                 'sprite-profile.json','steam-qa.json'):
        shutil.copy2(staging/name,out/name)
    for folder in ('central-visual','witness-visual'):
        shutil.copytree(staging/folder,out/folder)
    sprites=out/'sprites'; sprites.mkdir()
    for name in ('capture.json','reopen-qa.json','super-greeble-qa.json','super-greeble-contact-sheet.png',
                 'idle-64.png','idle-128.png','idle-256.png','working-64.png','working-128.png','working-256.png'):
        shutil.copy2(staging/'sprites'/name,sprites/name)
    before=staging.parent/'v13-recovered/fmpl-super-greeble/super-greeble-working.png'
    shutil.copy2(before,out/'v13-before.png')
    # A contact sheet of genuine renders; no repainting of any machine image.
    panel=Image.new('RGB',(1536,550),(33,35,38)); draw=ImageDraw.Draw(panel)
    for i,(name,label) in enumerate((('v13-before.png','V13 source'),('working.png','V14 native candidate'),
                                    ('runtime-front.png','GLB: failed liquid / steam parity'))):
        with Image.open(out/name) as im: panel.paste(im.convert('RGBA'),(i*512,30),im.getchannel('A'))
        draw.text((i*512+16,12),label,fill='white')
    panel.save(out/'before-after-runtime.png')
    fps=census['timeline_fps']; cycle_seconds=96/fps
    frames=[]
    for i in range(8):
        with Image.open(staging/f'sprites/frames/working/d00/f{i:03d}.png') as im:
            rgba=im.convert('RGBA'); bg=Image.new('RGB',rgba.size,(33,35,38)); bg.paste(rgba,mask=rgba.getchannel('A'))
            frames.append(bg)
    frames[0].save(out/'working-native-loop.webp',save_all=True,append_images=frames[1:],
        duration=round(cycle_seconds*1000/8),loop=0,lossless=True)
    review=dict(schema='tech-priests.hash-bound-visual-review.v1',
        status='CANDIDATE_NOT_FINAL; GLB_VISUAL_REJECTED',scale='0 to 5; final threshold 4 in every category',
        reviewed_images={n:sha(out/n) for n in ('v13-before.png','working.png','runtime-front.png','runtime-clay.png')},
        source_sha256=sha(out/'water-purifier-v14.blend'),export_sha256=sha(out/'water-purifier-v14.glb'),
        references={
          'art/source-to-3d/boiler-v08/production/Boiler_V08_Game_Ready_Overview.png':
            sha(root/'art/source-to-3d/boiler-v08/production/Boiler_V08_Game_Ready_Overview.png'),
          'docs/art/metallic-hydrogen-chain/references/metallic_hydrogen_seven_precursor_style_board.jpg':
            sha(root/'docs/art/metallic-hydrogen-chain/references/metallic_hydrogen_seven_precursor_style_board.jpg')},
        scores={
          'silhouette':dict(score=4,reason='Process vessel, two filter stages, raw/clean witnesses and red load-bearing frame remain readable.'),
          'construction':dict(score=3,reason='Console and upper drive repaired; ten main unions contact receivers; remaining service endpoint census incomplete.'),
          'native_surface_finish':dict(score=3,reason='Packed PBR, physical UVs and material identities present; no final wear/finish comparison or owner approval.'),
          'animation_and_states':dict(score=3,reason='Quarter-turn motion, water/foam/bubbles and CRT isolation pass; idle steam fails inherited threshold; native state/clock integration unproven.'),
          'runtime_export_visual':dict(score=2,reason='Metal channels and geometry survive; witness liquids/glass become pale and steam becomes opaque on actual GLB reimport.'),
          'prototype_pipe_integration':dict(score=0,reason='No native purifier prototype installed; no actual connected/disconnected placement jig yet.')},
        owner_approval=False,ordinary_runtime_integrated=False)
    write(out/'VISUAL_REVIEW.json',review)
    registry=root/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json'
    packet=read(root/'docs/art/metallic-hydrogen-chain/JOB_SPEC.json')
    queue=[dict(id=x['id'],planned_footprint_tiles=x['planned_footprint_tiles'],
                status='candidate_native' if x['id']=='water-purifier' else 'not_built_this_checkpoint') for x in packet['tasks']]
    checkpoint=dict(schema='tech-priests.mh7.production-continuation.v1',status='active',
        workspace=str(root),base_commit='e6a5022',current_candidate=str(out),staging=str(staging),
        source_recovery=dict(run=42854827403,artifact=13781794050,
            path=str(staging.parent/'v13-recovered/fmpl-super-greeble/water-purifier-fmpl-super.blend'),
            sha256='971087c8a03e5b91ab6f70afa2a1abe13f5d0cd231b9983969bd509ed10330be'),
        geometry_gate=geometry['status'],central_effects=central['passed'],witness_effects=witness['passed'],
        steam=steam['passed'],atlas=atlas['passed'],GLB_visual='failed',queue=queue,
        source_timeline_fps=fps,cycle_timeline_interval=96,cycle_seconds=cycle_seconds,
        captured_working_frames=8,proposed_native_animation_speed=8/(60*cycle_seconds),
        clock_authority='source timeline duration; proposed Factorio clock requires actual engine readback',
        parts_registry_sha256=sha(registry),registered_parts=len(read(registry)['parts']),
        native_ports_verified=False,reactors=dict(status='source_recovery_pending',
            source_manifest='docs/art/external-model-sources.json',
            browser_attempt='app-access approval timed out before navigation; no source absence inferred'),
        next_steps=['Complete source steam idle visibility without lowering 75/20 pixel gates',
                    'Complete named endpoint/branch audit and raised-console electrical route',
                    'Bake or adapt procedural GLB materials; reimport and inspect again',
                    'Extract and clean-append a genuine library component',
                    'Build isolated native purifier prototype and real pipe fitting jig',
                    'Continue unique machines 02-07; recover reactor V14 bytes'],
        safety=dict(other_checkouts_untouched=True,release_changed=False,workflows_dispatched=False),
        remote_published=False,owner_approved=False)
    write(out/'CHECKPOINT.json',checkpoint)
    write(root/'docs/art/metallic-hydrogen-chain/V14_CONTINUATION.json',checkpoint)
    (out/'README.md').write_text('# Water Purifier V14 local candidate\n\n'
        'Real editable native source and inspected evidence. This is not final or integrated.\n\n'
        'See VISUAL_REVIEW.json and CHECKPOINT.json. Geometry, contacts, UV, central/witness effects and six atlas sheets pass their targeted checks. '
        'The GLB is retained as a **failed visual study**: liquid/glass and steam do not match the native source. '
        'Idle steam is below its existing pixel threshold. Remaining service couplings, library extraction, prototype/pipe jig and owner acceptance remain open.\n\n'
        'working-native-loop.webp uses the original source timeline cycle duration, not the sprite capture preview FPS. '
        'The proposed Factorio animation clock in CHECKPOINT.json is not engine-verified.\n',encoding='utf-8')
    write(out/'SHA256.json',{str(p.relative_to(out)).replace('\\','/'):sha(p)
        for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print(json.dumps(dict(candidate=str(out),clock_seconds=cycle_seconds,source_fps=fps,goal='active')))

if __name__=='__main__': main()
