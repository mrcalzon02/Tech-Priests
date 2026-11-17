"""Exercise artillery through the full Tech Priests canonical event owner."""
import argparse,json,shutil,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--graphics',action='store_true');p.add_argument('--gui-test',action='store_true');p.add_argument('--reload',action='store_true');p.add_argument('--server-save',action='store_true');p.add_argument('--pilot',action='store_true');p.add_argument('--production-control',type=Path);args=p.parse_args()
stage=ROOT/'build/twin-cannon/main-integration';mod=stage/'mods/tech-priests';out=ROOT/'build/artillery-native/main';out.mkdir(parents=True,exist_ok=True)
assert (stage/'production-overlay.json').exists(),'Stage the complete production mod first'
art=ROOT/('build/artillery-native/animated-art-v19'if args.pilot else 'tech-priests_src/graphics/entity/bunker-artillery')
visuals=json.loads((art/'visuals.json').read_text());assert args.pilot or visuals['complete']
if args.pilot:
 (mod/'locale/en').mkdir(parents=True,exist_ok=True)
 shutil.copy2(ROOT/'tech-priests_src/locale/en/bunker-artillery.cfg',mod/'locale/en/bunker-artillery.cfg')
 target=mod/'graphics/entity/bunker-artillery';target.mkdir(parents=True,exist_ok=True)
 manifest=json.loads((art/'assets.json').read_text())
 for filename in manifest['files']:shutil.copy2(art/filename,target/filename)
 for filename in ('artillery_barrage_visuals.lua','artillery_barrage_geometry.lua'):shutil.copy2(art/filename,mod/'scripts'/filename)
 for relative in ('scripts/bunker_cannon_integration.lua','scripts/artillery_barrage_controller.lua','prototypes/bunker_artillery.lua'):
  shutil.copy2(ROOT/'tech-priests_src'/relative,mod/relative)
 (mod/'data.lua').write_bytes((ROOT/'tech-priests_src/data.lua').read_bytes()+b"\n-- Isolated incomplete-direction pilot, never production registration.\nrequire('prototypes.bunker_artillery').register('tech-priests',{animation_pilot=true})\n")
fixture=ROOT/'tests/scenarios/artillery-native'
data=(fixture/'data.lua').read_text();data="local artillery=require('prototypes.bunker_artillery')\n"+data[data.index('local t=data.raw'):]
with tarfile.open(stage/'main-source.tar')as archive:original=archive.extractfile('tech-priests_src/data-updates.lua').read()
(mod/'data-updates.lua').write_bytes(original+b'\n-- Isolated artillery acceptance targets.\n'+data.encode())
control=(fixture/'control.lua').read_text().replace('script.on_init(','on_init(').replace('script.on_event(','event(')
control=control.replace("event(defines.events.on_gui_opened,barrage.gui_opened)\n",'').replace("event(defines.events.on_gui_closed,barrage.gui_closed)\n",'')
control=control.replace("event(defines.events.on_gui_click,barrage.gui_click)\n",'').replace("event(defines.events.on_gui_checked_state_changed,barrage.gui_checked)\n",'')
control=control.replace('local before=e.entity.position;barrage.fired(e)','local before=e.entity.position').replace('  barrage.tick(e);t.assembler.energy=500000','  t.assembler.energy=500000')
control=control.replace("  if GRAPHICAL then game.speed=3 end", "  check(script.mod_name=='tech-priests','actual main mod')\n  check(integration.main_ownership and integration.main_ownership.preserved,'existing event routes preserved')\n  if GRAPHICAL then game.speed=3 end")
control=control.replace("{status='PASS',actual_art=true", "{status='PASS',main_mod=script.mod_name,event_ownership=integration.main_ownership,actual_art=true")
control=control.replace('artillery-native/','artillery-main/')
prefix="""local registry=require('scripts.core.runtime_event_registry')
local integration=require('scripts.bunker_cannon_integration')
local function on_init(fn)registry.on_init(fn,{owner='artillery_acceptance',route='setup',priority=1000000})end
local function event(id,fn)registry.on_event(id,fn,nil,{owner='artillery_acceptance',route=tostring(id),priority=1000000})end
"""
(mod/'scripts/artillery_main_fixture.lua').write_text('local GRAPHICAL='+('true'if args.graphics or args.gui_test else 'false')+'\n'+prefix+control)
(mod/'control.lua').write_bytes((args.production_control or ROOT/'tech-priests_src/control.lua').read_bytes()+b"\n-- Isolated acceptance only.\nrequire('scripts.artillery_main_fixture')\n")
user=out/'user-data';user.mkdir(exist_ok=True);exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe')
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(stage/'mods'),'--disable-migration-window']
proof=user/'script-output/artillery-main'/('graphical.json'if args.graphics or args.gui_test else 'result.json');proof.unlink(missing_ok=True)
checkpoint=user/'saves/_autosave-artillery-native-mid-reload.zip';save=checkpoint if args.reload else out/'artillery-main.zip'
if not args.reload:
 with (out/'create.log').open('w')as log:subprocess.run(base+['--create',str(save)],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
if args.server_save:
 checkpoint.unlink(missing_ok=True)
 settings=out/'server-settings.json';settings.write_text(json.dumps({'name':'Local artillery acceptance','description':'Isolated test','visibility':{'public':False,'lan':False},'auto_pause':False,'require_user_verification':False}))
 command=['--start-server',str(save),'--server-settings',str(settings),'--bind','127.0.0.1','--port','34298'];tag='save-server'
else:
 command=['--load-game',str(save),'--window-size','1600x1000']if args.graphics else ['--test-save',str(save),'--test-ticks','3610']if args.gui_test else ['--benchmark',str(save),'--benchmark-ticks','3610','--benchmark-runs','1'];tag='graphics'if args.graphics else 'gui-test'if args.gui_test else 'reload'if args.reload else 'physics'
with (out/(tag+'.log')).open('w')as log:
 proc=subprocess.Popen(base+command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
 try:
  deadline=time.monotonic()+(160 if args.graphics else 60)
  while proc.poll()is None and time.monotonic()<deadline:
   if args.server_save and checkpoint.exists()and 'Saving finished'in (out/(tag+'.log')).read_text(errors='replace'):break
   if args.graphics and proof.exists():break
   time.sleep(.2)
 finally:
  if proc.poll()is None:proc.terminate()
  proc.wait(timeout=10)
log=(out/(tag+'.log')).read_text(errors='replace');assert 'isolated handler failure'not in log,log[-7000:]
if args.server_save:assert checkpoint.exists();print('ARTILLERY_MAIN_MID_RELOAD_SAVED');raise SystemExit(0)
r=json.loads(proof.read_text());assert r['status']=='PASS'and r['main_mod']=='tech-priests'and r['event_ownership']['preserved']and r['visual_checks']>1000
if not args.pilot:assert r['visual_headings']==64
if args.reload:assert r['resume']['tick']==r['resume']['saved_tick']+1 and r['resume']['owners']>0
if args.graphics or args.gui_test:assert r['real_gui']and r['animated_art']
shutil.copy2(proof,proof.parent/('save-reload.json'if args.reload else 'graphics-verified.json'if args.graphics else 'fresh.json'))
print('ARTILLERY_MAIN_PASS',len(r['sites']),r['event_ownership'])
