"""Build safe live-state assembler addon plus a separate destructive review fixture."""
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
    for key in ('factorio','asset','audio','out'):ap.add_argument('--'+key,required=True)
    ap.add_argument('--reload',action='store_true');ap.add_argument('--debug-counters',action='store_true')
    args=ap.parse_args();exe=Path(args.factorio).resolve();asset=Path(args.asset).resolve();audio=Path(args.audio).resolve();out=Path(args.out).resolve();here=Path(__file__).resolve().parent;cap=asset/'captures'
    if out.exists():raise FileExistsError('Preserve native assembler studies')
    capture=json.loads((cap/'capture.json').read_text())
    if capture['source_sha256']!=sha(asset/'assembler-v03.blend') or len(capture['frames'])!=68:raise RuntimeError('Capture source mismatch')
    for n in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/n).read_text())['passed']:raise RuntimeError('Capture gate '+n)
    spec=dict(mod_id='tp-mh7-assembler',entity='tp-mh7-canister-assembler',title='Canister assembler',cycle_seconds=16,frame_count=16,category='tp-mh7-review-assembly',recipe='tp-mh7-assembler-work',recipe_seconds=16,
        collision_box=[[-1.8,-1.8],[1.8,1.8]],selection_box=[[-2,-2],[2,2]],body_render_layer='object',sprite_scale=6.9/8,sprite_shift_y=-1.25*math.sqrt(.5)+4/32,
        ports=[],item_product='tp-mh7-assembler-cycle-result',product_probability=0,item_ingredients=[dict(type='item',name='tp-mh7-assembler-cycle-token',amount=1)],primary_animation_clock=True,exact_tick_clock=True)
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir();mod=mods/'tp-mh7-assembler_0.0.1';mod.mkdir();graphics=mod/'graphics';graphics.mkdir();sound=mod/'sound';sound.mkdir()
    src=here/'assembler_native'
    for original,target in [('data.lua','data.lua'),('assembler.lua','assembler.lua'),('runtime.lua','control.lua')]:shutil.copy2(src/original,mod/target)
    shutil.copy2(here/'native_machine_review_data.lua',mod/'native-data.lua');(mod/'spec.lua').write_text('return '+lua(spec)+'\n');(out/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
    info=dict(name=spec['mod_id'],version='0.0.1',title='State-preserving canister assembler',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','tp-mh7-pellet-decay >= 0.0.3'])
    (mod/'info.json').write_text(json.dumps(info,indent=2)+'\n')
    for path in (audio/'masters').glob('*.ogg'):shutil.copy2(path,sound/path.name)
    for direction,row in [('north',0),('east',3),('south',2),('west',1)]:
        for state in ('idle','working'):
            sheet=Image.new('RGBA',(1024,1024))
            for index in range(16):
                with Image.open(cap/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else index:03d}.png') as frame:sheet.paste(frame,((index%4)*256,(index//4)*256))
                if args.debug_counters:
                    x=index%4*256+12;y=index//4*256+12;color=(240,40,240,255) if state=='idle' else (20+13*index,235-11*index,40+9*index,255)
                    ImageDraw.Draw(sheet).rectangle((x,y,x+7,y+7),fill=color)
            sheet.save(graphics/(state+'-'+direction+'.png'))
    Image.new('RGBA',(1,16)).save(graphics/'animation-clock.png')
    decay=mods/'tp-mh7-pellet-decay_0.0.3';decay.mkdir();dsrc=here/'pellet_decay_review'
    for n in ('config.lua','data.lua','decay.lua','forge.lua'):shutil.copy2(dsrc/n,decay/n)
    shutil.copy2(dsrc/'runtime.lua',decay/'control.lua');(decay/'info.json').write_text(json.dumps(dict(name='tp-mh7-pellet-decay',version='0.0.3',title='Live pellet instability and preservation',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','quality >= 2.1.24'],expansion_required=True,quality_required=True,spoiling_required=True)))
    fixture=mods/'tp-mh7-assembler-review_0.0.1';fixture.mkdir();shutil.copy2(src/'fixture.lua',fixture/'control.lua');shutil.copy2(src/'fixture-data.lua',fixture/'data.lua')
    (fixture/'info.json').write_text(json.dumps(dict(name='tp-mh7-assembler-review',version='0.0.1',title='Isolated assembler review world',author='Tech Priests',factorio_version='2.1',dependencies=['tp-mh7-assembler >= 0.0.1'])))
    enabled={'base','quality','recycler','tp-mh7-pellet-decay','tp-mh7-assembler','tp-mh7-assembler-review'}
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903701,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'assembler-native-jig.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];commands=[]
    stages=[('create',['--create',str(save),'--map-gen-settings',str(settings)])]
    if args.reload:stages.append(('save-at-400',['--load-game',str(save),'--until-tick','400']))
    stages.extend([('production',['--benchmark',str(save),'--benchmark-ticks','5601' if args.reload else '6001','--benchmark-runs','1']),('data',['--dump-data'])])
    for label,tail in stages:
        print('ASSEMBLER_NATIVE_START',label,flush=True)
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240)
        commands.append(dict(stage=label,exit_code=result.returncode,log_sha256=sha(out/(label+'.log'))))
        if result.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
    production=json.loads((user/'script-output/tp-mh7-assembler-review/production.json').read_text());raw=json.loads((user/'script-output/data-raw-dump.json').read_text());native=raw['assembling-machine'][spec['entity']];recipe=raw['recipe'][spec['recipe']]
    if not production['passed'] or native['tile_width']!=4 or native['tile_height']!=4 or native.get('fluid_boxes') or recipe['preserve_products_in_machine_output'] or recipe['results'][0]['independent_probability']!=0:raise RuntimeError('Native production/prototype contract')
    sound=native['working_sound']['sound']
    if not sound['filename'].endswith('/assembler-working.ogg') or abs(sound['volume']-.65)>1e-8:raise RuntimeError('Sound binding')
    receipt=dict(passed=True,save_reload_exercised=args.reload,model_source_sha256=sha(asset/'assembler-v03.blend'),capture_sha256=sha(cap/'capture.json'),commands=commands,results=production,diagnostic_frame_counters=args.debug_counters,
        production_mod_hashes={p.relative_to(mod).as_posix():sha(p) for p in mod.rglob('*') if p.is_file()},fixture_hashes={p.name:sha(p) for p in fixture.glob('*.lua')},graphic_hashes={p.name:sha(p) for p in graphics.glob('*.png')},
        native_prototype=dict(tile_width=4,tile_height=4,fluid_boxes=0,working_sound=native['working_sound'],driver_recipe=recipe),ordinary_chain_integrated=False,graphical_seating_verified=False,native_animation_clock_verified=False)
    (out/'native-jig-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('ASSEMBLER_NATIVE_PRODUCTION_PASS',flush=True)


if __name__=='__main__':main()
