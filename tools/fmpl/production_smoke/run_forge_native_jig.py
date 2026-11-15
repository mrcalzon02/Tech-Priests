"""Real native inserter/press/preservation cases, with actual mid-cycle reload."""
import argparse
import json
import math
from pathlib import Path
import shutil
import subprocess
from PIL import Image,ImageDraw
from run_compressor_native_jig import lua,sha


def main():
    ap=argparse.ArgumentParser()
    for name in ('factorio','asset','audio-mod','out'):ap.add_argument('--'+name,required=True)
    ap.add_argument('--reload',action='store_true');ap.add_argument('--debug-counters',action='store_true')
    args=ap.parse_args();out=Path(args.out).resolve();exe=Path(args.factorio).resolve();asset=Path(args.asset).resolve();cap=asset/'captures';here=Path(__file__).resolve().parent
    if out.exists():raise FileExistsError('Preserve native forge studies')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    if json.loads((cap/'capture.json').read_text())['source_sha256']!=sha(asset/'forge-v03.blend'):raise RuntimeError('Wrong engineering/capture source')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir()
    decay=mods/'tp-mh7-pellet-decay_0.0.3';decay.mkdir();src=here/'pellet_decay_review'
    for name in ('config.lua','data.lua','decay.lua','forge.lua'):shutil.copy2(src/name,decay/name)
    shutil.copy2(src/'runtime.lua',decay/'control.lua')
    (decay/'info.json').write_text(json.dumps(dict(name='tp-mh7-pellet-decay',version='0.0.3',title='Live pellet instability and state-preserving press',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','quality >= 2.1.24'],expansion_required=True,quality_required=True,spoiling_required=True)))
    spec=dict(mod_id='tp-mh7-forge-review',entity='tp-mh7-review-forge',title='Forge isolated native state-preserving production review',cycle_seconds=8,category='tp-mh7-review-forging',recipe='tp-mh7-review-forge-work',recipe_seconds=8,
        collision_box=[[-1.3,-1.3],[1.3,1.3]],selection_box=[[-1.5,-1.5],[1.5,1.5]],body_render_layer='object',sprite_scale=5.8/8,sprite_shift_y=-1.05*math.sqrt(.5)+4/32,
        ports=[],item_product='tp-mh7-forge-cycle-result',product_probability=0,primary_animation_clock=True,item_ingredients=[dict(type='item',name='tp-mh7-forge-cycle-token',amount=1)])
    mod=mods/'tp-mh7-forge-review_0.0.1';mod.mkdir();graphics=mod/'graphics';graphics.mkdir()
    for source,target in [('native_machine_review_data.lua','native-data.lua'),('forge_review_data.lua','data.lua'),('forge_review_control.lua','control.lua')]:shutil.copy2(here/source,mod/target)
    (mod/'spec.lua').write_text('return '+lua(spec)+'\n');(out/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
    (mod/'info.json').write_text(json.dumps(dict(name=spec['mod_id'],version='0.0.1',title=spec['title'],author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','tp-mh7-pellet-decay >= 0.0.3'])))
    for direction,row in [('north',0),('east',3),('south',2),('west',1)]:
        for state in ('idle','working'):
            sheet=Image.new('RGBA',(1024,512))
            for i in range(8):
                with Image.open(cap/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else i:03d}.png') as im:sheet.paste(im,((i%4)*256,(i//4)*256))
                if args.debug_counters:
                    x=(i%4)*256+12;y=(i//4)*256+12;color=(220,40,230,255) if state=='idle' else (20+28*i,230-20*i,40+20*i,255)
                    ImageDraw.Draw(sheet).rectangle((x,y,x+7,y+7),fill=color)
            sheet.save(graphics/(state+'-'+direction+'.png'))
    Image.new('RGBA',(1,8)).save(graphics/'animation-clock.png')
    audio=Path(args.audio_mod).resolve();shutil.copytree(audio,mods/audio.name)
    enabled={'base','quality','recycler','tp-mh7-pellet-decay',spec['mod_id'],json.loads((audio/'info.json').read_text())['name']}
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903503,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'forge-native-jig.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
    commands=[('create',['--create',str(save),'--map-gen-settings',str(settings)])]
    if args.reload:commands.append(('save-at-200',['--load-game',str(save),'--until-tick','200']))
    commands.extend([('processing-decay',['--benchmark',str(save),'--benchmark-ticks','8801' if args.reload else '9001','--benchmark-runs','1']),('data',['--dump-data'])]);results=[]
    for label,tail in commands:
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240)
        results.append(dict(stage=label,exit_code=result.returncode,log_sha256=sha(out/(label+'.log'))));print('FORGE_NATIVE_STAGE',label,result.returncode,flush=True)
        if result.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
    reports={name:json.loads((user/'script-output'/spec['mod_id']/(name+'.json')).read_text()) for name in ('processing','decay-integration','mixed-quality')}
    if any(not r['passed'] for r in reports.values()):raise RuntimeError('Native forge behavior failed')
    raw=json.loads((user/'script-output/data-raw-dump.json').read_text());native=raw['assembling-machine'][spec['entity']];work=raw['recipe'][spec['recipe']]
    if native.get('fluid_boxes') or work['preserve_products_in_machine_output'] or work['results'][0]['independent_probability']!=0:raise RuntimeError('Real stock could be consumed/replaced/preserved by native driver')
    sound=native['working_sound']['sound']
    if not sound['filename'].endswith('/forge-working.ogg') or abs(sound['volume']-.7)>1e-8:raise RuntimeError('Native forge sound binding differs')
    receipt=dict(passed=True,save_reload_exercised=args.reload,model_source_sha256=sha(asset/'forge-v03.blend'),capture_sha256=sha(cap/'capture.json'),commands=results,results=reports,
        source_hashes={p.name:sha(p) for p in src.glob('*.lua')},fixture_hashes={name:sha(mod/name) for name in ('data.lua','native-data.lua','control.lua','spec.lua')},graphic_hashes={p.name:sha(p) for p in graphics.glob('*.png')},diagnostic_frame_counters=args.debug_counters,
        native_prototype=dict(fluid_box_count=0,working_sound=native['working_sound'],driver_results=work['results'],driver_ingredients=work['ingredients'],preserve_products_in_machine_output=False),
        ordinary_chain_integrated=False,gameplay_balanced=False,graphical_seating_verified=False,native_animation_clock_verified=False)
    (out/'native-jig-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('FORGE_NATIVE_STATE_PRESERVATION_PASS',flush=True)


if __name__=='__main__':main()
