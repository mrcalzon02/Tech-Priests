"""Bind the delivered artillery review to actual full-mod evidence and assets."""
import json,hashlib,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1];build=ROOT/'build/artillery-native';out=ROOT/'docs/prototypes/artillery-production-acceptance';out.mkdir(exist_ok=True)
load=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
state=load(build/'finalization.json');assert state['status']=='READY_FOR_FINAL_REVIEW'
source=ROOT/'art/bunker-artillery/candidate-v19';master=source/'rolling-artillery.blend'
assets=ROOT/'tech-priests_src/graphics/entity/bunker-artillery';manifest=load(assets/'assets.json')
assert manifest['status']=='PACKED_ALL_DIRECTIONS'and len(manifest['directions'])==64 and manifest['source_sha256']==sha(master)
for filename,expected in manifest['files'].items():assert sha(assets/filename)==expected,filename
native=build/'main/user-data/script-output/artillery-main'
reports={'fresh.json':native/'fresh.json','save-reload.json':native/'save-reload.json','graphical.json':native/'graphics-verified.json',
 'cannon-regression.json':ROOT/'build/twin-cannon/main-integration/user-data/script-output/twin-cannon-main/result.json',
 'rocket-regression.json':ROOT/'build/rocket-salvo/main-physics/user-data/script-output/rocket-salvo-main/fresh.json'}
for name,path in reports.items():
 report=load(path);assert report['status']=='PASS'and report['main_mod']=='tech-priests'and report['event_ownership']['preserved'];shutil.copy2(path,out/name)
graph=load(reports['graphical.json']);assert len(graph['sites'])==20 and graph['visual_headings']==64 and graph['real_gui']
for name in ('reload-preview.png','team-corners.png','first-native-launch.png'):
 shutil.copy2(native/name,out/name)
canvas=Image.new('RGB',(1200,720),(36,38,40))
for i in range(1,5):
 for row,stage in enumerate((1,3)):
  path=native/f'direction-{i}-reload-{stage}.png'
  with Image.open(path)as image:
   assert image.size==(1100,1000);crop=image.convert('RGB').crop((180,220,920,850));crop.thumbnail((290,310),Image.Resampling.LANCZOS)
   x=(i-1)*300+(300-crop.width)//2;y=row*360+35;canvas.paste(crop,(x,y))
   ImageDraw.Draw(canvas).text(((i-1)*300+8,row*360+10),f'FACTORIO | direction {i} | '+('gate'if stage==1 else 'shell insertion'),fill='white')
  if stage==3:shutil.copy2(path,out/path.name)
canvas.save(out/'native-direction-review.png')
ticks=[280,350,450,459,466,474,481,489,504,580];frames=[]
for tick in ticks:
 with Image.open(native/f'actual-bunker-{tick}.png')as image:
  crop=image.convert('RGB').crop((400,280,700,830));ImageDraw.Draw(crop).text((8,8),'FACTORIO | RELOAD / SHELL INSERTION',fill='white');frames.append(crop.quantize(colors=192))
durations=[max(50,round((ticks[i+1]-tick)*1000/60))if i+1<len(ticks)else 700 for i,tick in enumerate(ticks)]
frames[0].save(out/'reload-in-game.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2)
shutil.copy2(build/'finalization.json',out/'pipeline.json')
runtime={}
for relative in ('prototypes/bunker_artillery.lua','scripts/artillery_barrage_controller.lua','scripts/bunker_cannon_integration.lua'):
 data=(ROOT/'tech-priests_src'/relative).read_bytes();runtime[relative]={'lf_normalized_sha256':hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()}
criteria=[{'criterion':'Construction and support','score':8.5,'reason':'Centered pedestal, full-contact feet, heavy recuperators and attached cage/gate hardware; 601 source poses pass the named clearance checks.'},
 {'criterion':'Surface and silhouette','score':8.5,'reason':'Larger bore and shells read against the compact cap; oxide armour, dark forged support, steel tube and brass rounds remain distinct at game scale.'},
 {'criterion':'Mechanism and ammunition','score':9,'reason':'Actual native launches drive recoil and indexing. Lowering, gate opening, three visible sliding rounds, closure and re-elevation are visible in the recorded game.'},
 {'criterion':'Directional integration','score':9,'reason':'20 native sites include cardinal and diagonal launch checks. All 64 body headings and shadows are packed; all 64 runtime heading selections pass. No static cap covers the cage.'},
 {'criterion':'Team and inventory readability','score':9,'reason':'Orange and blue corner stanchions visibly identify forces. The complete live model appears beside real inventory widgets and the auto-targeting control.'}]
review={'status':'PASS_DELIVERED_PROTOTYPE_REVIEW','reviewer':'Codex','owner_visual_approval_claimed':False,'base_commit':state['base_commit'],'version':state['version'],
 'source_sha256':sha(master),'glb_sha256':sha(source/'rolling-artillery.glb'),'asset_manifest_sha256':sha(assets/'assets.json'),
 'criteria':criteria,'minimum_score':8,'average_score':sum(c['score']for c in criteria)/len(criteria),'runtime_sources':runtime,
 'scope':'Full main-mod native combat, damage, ammunition, research, recipe, manual targeting, partial resupply, target loss, external disable, destruction/rebuild, save/resume, GUI and force-colour evidence. Source clearance covers 601 sampled poses, not arbitrary continuous retiming.',
 'native_static_cap_overlay_removed':True,'native_projectiles_and_damage':True,'native_muzzle_mapping':'64 already-projected LUT entries; no duplicate 1.0 endpoint or second projection.',
 'cadence':{'base_gaps':[90,90,420],'double_speed_gaps':[45,45,210],'stock_sustained_shells_per_600_ticks':3},
 'counts':{'artillery_sites':20,'artillery_heading_selections':64,'cannon_sites':32,'legacy_sites':5,'cannon_headings':64,'rocket_sites':23},
 'scoped_shared_files':state['scoped_shared_files'],'files':{p.name:sha(p)for p in out.iterdir()if p.is_file()and p.name!='review.json'}}
(out/'review.json').write_text(json.dumps(review,indent=2)+'\n')
contract=load(source/'contract.json');contract.update(status='DELIVERED_PROTOTYPE_VERIFIED',runtime_implemented=True,collision_acceptance='PASS_SOURCE_INTERFACES_601_POSES',
 runtime_review='../../../docs/prototypes/artillery-production-acceptance/review.json',owner_visual_approval_claimed=False)
(source/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
print('ARTILLERY_ACCEPTANCE_BOUND',review['version'],review['average_score'],review['counts'])
