"""Actual 4x4 plate/water-to-shell prototype, pipe/inserter/quality/audio review."""
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
    for key in ('factorio','asset','decay-mod','audio-mod','out'):ap.add_argument('--'+key,required=True)
    ap.add_argument('--debug-counters',action='store_true');ap.add_argument('--shift-pixels',type=int,default=4)
    ap.add_argument('--body-render-layer',choices=('object','lower-object'),default='object');ap.add_argument('--reload',action='store_true')
    ap.add_argument('--capture')
    args=ap.parse_args();exe=Path(args.factorio).resolve();asset=Path(args.asset).resolve();out=Path(args.out).resolve();cap=Path(args.capture).resolve() if args.capture else asset/'captures';here=Path(__file__).resolve().parent
    if out.exists():raise FileExistsError('Preserve native fabricator studies')
    if json.loads((exe.parents[2]/'data/base/info.json').read_text())['version']!='2.1.24':raise RuntimeError('Inspected Factorio 2.1.24 required')
    capture=json.loads((cap/'capture.json').read_text())
    if capture['source_sha256']!=sha(asset/'fabricator-v03.blend') or len(capture['frames'])!=52:raise RuntimeError('Source/capture mismatch')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    spec=dict(mod_id='tp-mh7-fabricator-review',entity='tp-mh7-review-fabricator',title='Fabricator isolated hydroforming production review',cycle_seconds=12,frame_count=12,
              category='tp-mh7-review-hydroforming',recipe='tp-mh7-review-hydroform',recipe_seconds=12,collision_box=[[-1.8,-1.8],[1.8,1.8]],selection_box=[[-2,-2],[2,2]],
              body_render_layer=args.body_render_layer,sprite_scale=6.7/8,sprite_shift_y=-1.05*math.sqrt(.5)+args.shift_pixels/32,
              ports=[dict(id='forming_fluid_intake',production_type='input',fluid='water',color=[.2,.4,.8],position=[-1.5,-.5],direction='west',target=[-2.5,-.5],plane=[-2,-.5])],
              item_product='tp-mh7-empty-pressure-shell',item_ingredients=[dict(type='item',name='steel-plate',amount=2)],primary_animation_clock=True,exact_tick_clock=True)
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir();mod=mods/'tp-mh7-fabricator-review_0.0.1';mod.mkdir();graphics=mod/'graphics';graphics.mkdir()
    for source,target in (('native_machine_review_data.lua','native-data.lua'),('fabricator_review_data.lua','data.lua'),('fabricator_review_control.lua','control.lua')):shutil.copy2(here/source,mod/target)
    (mod/'spec.lua').write_text('return '+lua(spec)+'\n');(out/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
    (mod/'info.json').write_text(json.dumps(dict(name=spec['mod_id'],version='0.0.1',title=spec['title'],author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','tp-mh7-pellet-decay >= 0.0.3'])))
    for direction,row in (('north',0),('east',3),('south',2),('west',1)):
        for state in ('idle','working'):
            sheet=Image.new('RGBA',(1024,768))
            for index in range(12):
                with Image.open(cap/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else index:03d}.png') as frame:sheet.paste(frame,((index%4)*256,(index//4)*256))
                if args.debug_counters:
                    x=(index%4)*256+12;y=(index//4)*256+12;color=(240,40,240,255) if state=='idle' else (20+18*index,235-15*index,40+13*index,255)
                    ImageDraw.Draw(sheet).rectangle((x,y,x+7,y+7),fill=color)
            sheet.save(graphics/(state+'-'+direction+'.png'))
    Image.new('RGBA',(1,12)).save(graphics/'animation-clock.png')
    enabled={'base','quality','recycler',spec['mod_id']}
    for src in (Path(args.decay_mod).resolve(),Path(args.audio_mod).resolve()):
        shutil.copytree(src,mods/src.name);enabled.add(json.loads((src/'info.json').read_text())['name'])
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=name,enabled=name in enabled) for name in sorted(enabled|{'space-age','elevated-rails'})])))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903601,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'fabricator-native-jig.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];commands=[]
    stages=[('create',['--create',str(save),'--map-gen-settings',str(settings)])]
    if args.reload:stages.append(('save-at-1200',['--load-game',str(save),'--until-tick','1200']))
    stages.extend([('production',['--benchmark',str(save),'--benchmark-ticks','1801' if args.reload else '3001','--benchmark-runs','1']),('data',['--dump-data'])])
    for label,tail in stages:
        print('FABRICATOR_NATIVE_START',label,flush=True)
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240)
        commands.append(dict(stage=label,exit_code=result.returncode))
        if result.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
    reports={name:json.loads((user/'script-output'/spec['mod_id']/(name+'.json')).read_text()) for name in ('physical-ports','production')}
    if any(not r['passed'] for r in reports.values()):raise RuntimeError('Actual native production failed')
    raw=json.loads((user/'script-output/data-raw-dump.json').read_text());native=raw['assembling-machine'][spec['entity']];recipe=raw['recipe'][spec['recipe']];sound=native['working_sound']['sound']
    if native['tile_width']!=4 or native['tile_height']!=4 or len(native['fluid_boxes'])!=1 or recipe['preserve_products_in_machine_output']:raise RuntimeError('Wrong native footprint/fluid/output contract')
    if not sound['filename'].endswith('/fabricator-working.ogg') or abs(sound['volume']-.70)>1e-8:raise RuntimeError('Audio binding differs')
    receipt=dict(passed=True,save_reload_exercised=args.reload,model_source_sha256=sha(asset/'fabricator-v03.blend'),capture_sha256=sha(cap/'capture.json'),commands=commands,results=reports,
                 fixture_hashes={name:sha(mod/name) for name in ('data.lua','native-data.lua','control.lua','spec.lua')},graphic_hashes={p.name:sha(p) for p in graphics.glob('*.png')},
                 diagnostic_frame_counters=args.debug_counters,native_prototype=dict(tile_width=4,tile_height=4,fluid_boxes=1,working_sound=native['working_sound'],recipe=recipe),
                 ordinary_chain_integrated=False,recipe_economy_final=False,graphical_seating_verified=False,native_animation_clock_verified=False)
    (out/'native-jig-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('FABRICATOR_NATIVE_PRODUCTION_QUALITY_AUDIO_PASS',flush=True)


if __name__=='__main__':main()
