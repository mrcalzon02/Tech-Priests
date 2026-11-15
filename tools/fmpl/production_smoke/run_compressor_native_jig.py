"""Create a self-contained review prototype and run real native fluid tests."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
from PIL import Image,ImageDraw


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def lua(value):
    if isinstance(value,bool):return 'true' if value else 'false'
    if value is None:return 'nil'
    if isinstance(value,(int,float)):return repr(value)
    if isinstance(value,str):return json.dumps(value)
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--factorio',required=True);ap.add_argument('--asset',required=True)
    ap.add_argument('--capture',required=True);ap.add_argument('--out',required=True)
    ap.add_argument('--debug-counters',action='store_true',help='Temporary state/frame counter in otherwise transparent sprite corners; never final artwork')
    ap.add_argument('--source-name',default='compressor-v04.blend')
    ap.add_argument('--rear-collar',help='Directory of real rendered rear collars for joint-depth review')
    ap.add_argument('--audio-addon',help='Original machinery audio extension directory')
    args=ap.parse_args()
    exe=Path(args.factorio).resolve();asset=Path(args.asset).resolve();capture=Path(args.capture).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Keep previous native profiles')
    base=exe.parents[2]/'data';version=json.loads((base/'base/info.json').read_text())['version']
    if version!='2.1.24':raise RuntimeError('Requires inspected native 2.1.24')
    cycle_seconds=json.loads((capture/'capture.json').read_text())['config']['cycle_seconds']
    spec=dict(mod_id='tp-mh7-compressor-review',entity='tp-mh7-review-compressor',title='Compressor isolated art and pipe review',cycle_seconds=cycle_seconds,rear_collar_layer=bool(args.rear_collar),
        category='tp-mh7-review-compression',recipe='tp-mh7-review-compress',collision_box=[[-1.3,-1.8],[1.3,1.8]],selection_box=[[-1.5,-2],[1.5,2]],
        sprite_scale=6.1/8,sprite_shift_y=-.82*math.sqrt(.5)+4/32,
        ports=[dict(id='hydrogen_suction',production_type='input',fluid='tp-mh7-review-hydrogen-gas',color=[.4,.7,.8],position=[-1,-.5],direction='west',target=[-2,-.5],plane=[-1.5,-.5]),
               dict(id='hydrogen_discharge',production_type='output',fluid='tp-mh7-review-compressed-hydrogen',color=[.3,.6,.75],position=[1,-.5],direction='east',target=[2,-.5],plane=[1.5,-.5])])
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir();mod=mods/(spec['mod_id']+'_0.0.1');mod.mkdir();graphics=mod/'graphics';graphics.mkdir()
    here=Path(__file__).resolve().parent
    for src,dst in (('native_machine_review_data.lua','data.lua'),('native_machine_review_control.lua','control.lua')):shutil.copy2(here/src,mod/dst)
    (mod/'spec.lua').write_text('return '+lua(spec)+'\n');(out/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
    if args.rear_collar:
        for direction in ('east','west'):shutil.copy2(Path(args.rear_collar)/('rear-collar-'+direction+'.png'),graphics/('rear-collar-'+direction+'.png'))
    (mod/'info.json').write_text(json.dumps(dict(name=spec['mod_id'],version='0.0.1',title=spec['title'],author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24'])))
    for direction,row in (('north',0),('east',3),('south',2),('west',1)):
        for state in ('idle','working'):
            sheet=Image.new('RGBA',(1024,512))
            for i in range(8):
                with Image.open(capture/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else i:03d}.png') as image:
                    if image.mode!='RGBA' or image.size!=(256,256):raise RuntimeError('Wrong source frame')
                    sheet.paste(image,((i%4)*256,(i//4)*256))
                    if args.debug_counters:
                        x=(i%4)*256+24;y=(i//4)*256+24
                        color=(220,40,230,255) if state=='idle' else (20+28*i,230-20*i,40+20*i,255)
                        ImageDraw.Draw(sheet).rectangle((x,y,x+7,y+7),fill=color)
            sheet.save(graphics/(state+'-'+direction+'.png'))
    enabled={'base',spec['mod_id']}
    if args.audio_addon:
        audio=Path(args.audio_addon).resolve();shutil.copytree(audio,mods/audio.name);enabled.add('tp-mh7-machinery-audio')
    (mods/'mod-list.json').write_text(json.dumps({'mods':[dict(name=n,enabled=n in enabled) for n in ('base','elevated-rails','quality','recycler','space-age',spec['mod_id'],'tp-mh7-machinery-audio')]}))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(base)+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903443,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'compressor-native-jig.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];commands=[]
    for name,tail in (('create',['--create',str(save),'--map-gen-settings',str(settings)]),('flow',['--benchmark',str(save),'--benchmark-ticks',str(max(660,180+cycle_seconds*60)),'--benchmark-runs','1'])):
        print('COMPRESSOR_NATIVE_START',name,flush=True)
        with (out/(name+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        commands.append(dict(stage=name,returncode=result.returncode))
        if result.returncode:raise RuntimeError('Actual native '+name+' failed')
    reports={n:json.loads((user/'script-output'/spec['mod_id']/(n+'.json')).read_text()) for n in ('physical-ports','flow')}
    if any(not r['passed'] for r in reports.values()):raise RuntimeError('Actual native validation failed')
    receipt=dict(passed=True,base_version=version,results=reports,commands=commands,model_source_sha256=sha(asset/args.source_name),
        source_capture_sha256=sha(capture/'capture.json'),native_profile=str(out),fixture_hashes={n:sha(mod/n) for n in ('data.lua','control.lua','spec.lua')},
        source_graphic_hashes={p.name:sha(p) for p in graphics.glob('*.png')},audio_addon_enabled=bool(args.audio_addon),
        diagnostic_frame_counters=args.debug_counters,graphical_seating_verified=False,native_animation_clock_verified=False,ordinary_mod_installed=False,production_economy_assigned=False)
    (out/'native-jig-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('COMPRESSOR_NATIVE_FLUID_PASS',flush=True)


if __name__=='__main__':main()
