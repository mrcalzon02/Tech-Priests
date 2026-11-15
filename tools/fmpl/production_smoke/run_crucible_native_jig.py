"""Actual 5x5 one-fluid/item-output crucible, pickups, decay and sound load."""
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
    for name in ('factorio','asset','capture','decay-mod','audio-mod','out'):ap.add_argument('--'+name,required=True)
    ap.add_argument('--body-render-layer',choices=('object','lower-object'),default='object')
    ap.add_argument('--shift-pixels',type=int,default=4)
    ap.add_argument('--debug-counters',action='store_true',help='Private frame-clock diagnostic; excluded from final artwork')
    ap.add_argument('--primary-animation-clock',action='store_true',help='Explicit primary clock for state-filtered visual layers')
    args=ap.parse_args();out=Path(args.out).resolve();exe=Path(args.factorio).resolve();asset=Path(args.asset).resolve();cap=Path(args.capture).resolve()
    if out.exists():raise FileExistsError('Preserve native crucible studies')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture '+name)
    capture=json.loads((cap/'capture.json').read_text())
    if capture['source_sha256']!=sha(asset/'crucible-v03.blend'):raise RuntimeError('Wrong engineering source/capture')
    spec=dict(mod_id='tp-mh7-crucible-review',entity='tp-mh7-review-crucible',title='Crucible isolated native production review',cycle_seconds=8,
        category='tp-mh7-review-metallization',recipe='tp-mh7-review-metallize',recipe_seconds=1,
        collision_box=[[-2.3,-2.3],[2.3,2.3]],selection_box=[[-2.5,-2.5],[2.5,2.5]],body_render_layer=args.body_render_layer,
        sprite_scale=7.7/8,sprite_shift_y=-1.2*math.sqrt(.5)+args.shift_pixels/32,
        ports=[dict(id='conditioned_hydrogen_input',production_type='input',fluid='tp-mh7-review-compressed-hydrogen',color=[.3,.6,.75],position=[-2,0],direction='west',target=[-3,0],plane=[-2.5,0])],
        item_product='tp-mh7-raw-metallicized-pellet',item_pickup_edge=[2.5,0],rear_collar_layer=False,
        fixture_product_quality='legendary',primary_animation_clock=args.primary_animation_clock)
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir();mod=mods/'tp-mh7-crucible-review_0.0.1';mod.mkdir();graphics=mod/'graphics';graphics.mkdir()
    here=Path(__file__).resolve().parent
    for source,target in (('native_machine_review_data.lua','data.lua'),('crucible_review_control.lua','control.lua')):shutil.copy2(here/source,mod/target)
    (mod/'spec.lua').write_text('return '+lua(spec)+'\n');(out/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
    (mod/'info.json').write_text(json.dumps(dict(name=spec['mod_id'],version='0.0.1',title=spec['title'],author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','tp-mh7-pellet-decay >= 0.0.2'])))
    for direction,row in (('north',0),('east',3),('south',2),('west',1)):
        for state in ('idle','working'):
            sheet=Image.new('RGBA',(1024,512))
            for i in range(8):
                with Image.open(cap/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else i:03d}.png') as image:
                    if image.size!=(256,256) or image.mode!='RGBA':raise RuntimeError('Wrong native source frame')
                    sheet.paste(image,((i%4)*256,(i//4)*256))
                    if args.debug_counters:
                        x=(i%4)*256+12;y=(i//4)*256+12
                        color=(220,40,230,255) if state=='idle' else (20+28*i,230-20*i,40+20*i,255)
                        ImageDraw.Draw(sheet).rectangle((x,y,x+7,y+7),fill=color)
            sheet.save(graphics/(state+'-'+direction+'.png'))
    if args.primary_animation_clock:Image.new('RGBA',(1,8)).save(graphics/'animation-clock.png')
    enabled={'base',spec['mod_id'],'quality','recycler'}
    for source in (Path(args.decay_mod).resolve(),Path(args.audio_mod).resolve()):
        shutil.copytree(source,mods/source.name);enabled.add(json.loads((source/'info.json').read_text())['name'])
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903443,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'crucible-native-jig.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];commands=[]
    for label,tail in (('create',['--create',str(save),'--map-gen-settings',str(settings)]),('production-decay',['--benchmark',str(save),'--benchmark-ticks','8401','--benchmark-runs','1']),('data',['--dump-data'])):
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        commands.append(dict(stage=label,exit_code=result.returncode));print('CRUCIBLE_NATIVE_STAGE',label,result.returncode,flush=True)
        if result.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
    reports={name:json.loads((user/'script-output'/spec['mod_id']/(name+'.json')).read_text()) for name in ('physical-ports','production','decay-integration')}
    if any(not row['passed'] for row in reports.values()):raise RuntimeError('Native behavior failed')
    data=json.loads((user/'script-output/data-raw-dump.json').read_text());native=data['assembling-machine'][spec['entity']];recipe=data['recipe'][spec['recipe']]
    sound=native['working_sound']['sound']
    if len(native['fluid_boxes'])!=1 or recipe['preserve_products_in_machine_output']:raise RuntimeError('Native inlet/output preservation differs')
    if not sound['filename'].endswith('/crucible-working.ogg') or abs(sound['volume']-.65)>1e-8:raise RuntimeError('Crucible audio binding differs')
    receipt=dict(passed=True,model_source_sha256=sha(asset/'crucible-v03.blend'),capture_sha256=sha(cap/'capture.json'),commands=commands,results=reports,
        native_prototype=dict(fluid_box_count=len(native['fluid_boxes']),working_sound=native['working_sound'],recipe_results=recipe['results'],preserve_products_in_machine_output=recipe['preserve_products_in_machine_output']),
        fixture_hashes={name:sha(mod/name) for name in ('data.lua','control.lua','spec.lua')},graphic_hashes={p.name:sha(p) for p in graphics.glob('*.png')},
        diagnostic_frame_counters=args.debug_counters,primary_animation_clock=args.primary_animation_clock,
        gameplay_balance=False,ordinary_chain_integrated=False,graphical_seating_verified=False,native_animation_clock_verified=False)
    (out/'native-jig-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('CRUCIBLE_NATIVE_PRODUCTION_DECAY_AUDIO_PASS',flush=True)


if __name__=='__main__':main()
