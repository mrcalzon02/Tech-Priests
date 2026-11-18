"""Promote current captured art and retain actual native evidence with explicit gates."""
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
import json,hashlib,shutil,sys
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';B=R/'build/conclave-native-v08';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();mode=sys.argv[1]
if mode=='integrate':
 assert json.loads((O/'inspection.json').read_text())['passed'];assert json.loads((O/'independent-motion-audit.json').read_text())['passed']
 receipt=json.loads((O/'motion-frames-clean/capture-source.json').read_text());assert receipt['source_sha256']==h(O/'conclave-center-v08.blend')
 D=R/'tech-priests_src/graphics/entity/conclave-center-v08';D.mkdir(exist_ok=True)
 layer=json.loads((O/'native-layer-composition.json').read_text());assert layer['passed'];assert layer['source_sha256']==h(O/'conclave-center-v08.blend')
 for a,b in [('placement-base.png','placement-base.png'),('ambient-effects.png','ambient-effects.png'),('ambient-light.png','ambient-light.png'),('icon.png','icon.png'),('shadow-d0.png','shadow.png')]:shutil.copy2(O/'captures'/a,D/b)
 p=R/'tech-priests_src/prototypes/conclave_center_0558.lua'
 if (O/'production-prototype-v08.lua').exists():shutil.copy2(O/'production-prototype-v08.lua',p)
 else:p.write_text(p.read_text().replace('conclave-center-v07/','conclave-center-v08/'))
 retired=D/'ambient-north.png'
 if retired.exists():
  assert retired.resolve().parent==D.resolve();retired.unlink()
 credit='Low Poly Skull (Craneo) by DGordillo\nhttps://blendswap.com/blend/2499\nCC BY 3.0: https://creativecommons.org/licenses/by/3.0/\nConclave adaptation: uniformly resized, original mesh/UV/sculpt normal retained, aged ivory material, mounted shrine. Central skull has additional fitted augmetic half-mask, ocular fitting, jaw hardware and cog surround. No endorsement implied.\n'
 (O/'ATTRIBUTION.txt').write_text(credit);(R/'tech-priests_src/credits/Conclave-DGordillo-skull.txt').write_text(credit)
 (O/'integration.json').write_text(json.dumps(dict(source_sha256=h(O/'conclave-center-v08.blend'),export_sha256=h(O/'conclave-center-v08.glb'),runtime_art={p.name:h(p) for p in D.glob('*.png')},prototype_sha256=h(R/'tech-priests_src/prototypes/conclave_center_0558.lua'),state='Integrated candidate; native V08 validation and owner review still required'),indent=2))
 print('V08_PRODUCTION_ART_INTEGRATED');sys.exit()
assert mode=='evidence';N=O/'native-evidence';N.mkdir(exist_ok=True);S=B/'user-data/script-output/conclave-center'
for name in ('native-results.json','reload-results.json','native-close.png','native-gameplay.png','native-night.png','native-ghost.png'):
 shutil.copy2(S/name,N/name)
frames=sorted(S.glob('native-motion-*.png'));assert len(frames)==36
for p in frames:shutil.copy2(p,N/p.name)
images=[Image.open(p).convert('RGB') for p in frames];images[0].save(N/'native-motion.gif',save_all=True,append_images=images[1:],duration=[330,330,340]*12,loop=0)
native=json.loads((N/'native-results.json').read_text());reload=json.loads((N/'reload-results.json').read_text());old=json.loads((R/'build/conclave-native-v01/user-data/script-output/data-raw-dump.json').read_text());new=json.loads((B/'user-data/script-output/data-raw-dump.json').read_text());ID='tech-priests-conclave-center';delta={}
for kind in ('container','item','recipe'):
 a=old[kind][ID];b=new[kind][ID];delta[kind]=[k for k in set(a)|set(b) if a.get(k)!=b.get(k)]
allowed=all(set(v)<=set(('icon','picture','stateless_visualisation')) for v in delta.values());unique=len({h(p) for p in frames});motion={}
for name,box in [('candles',(220,135,425,225)),('central_crt',(280,262,358,315)),('keyboard',(282,311,358,345))]:
 crops=[im.crop(box) for im in images];differences=[sum(ImageStat.Stat(ImageChops.difference(crops[0],im)).sum) for im in crops[1:]];motion[name]=dict(changed=max(differences)>0,max_rgb_difference_sum=max(differences),crop=box)
result=dict(passed=native['passed'] and reload.get('reloaded',False) and reload.get('reload_inventory_preserved',False) and allowed and unique>1 and all(x['changed'] for x in motion.values()),prototype_changed_fields=delta,gameplay_fields_preserved=allowed,native_function=native,native_reload=reload,graphical_frames=36,unique_graphical_frames=unique,motion_regions=motion,night='Actual native screenshot retained; visual assessment separately in review.json',physical_governance_input='Pending; automated GUI presence never substituted for physical input',owner_approval=False,source_sha256=h(O/'conclave-center-v08.blend'),export_sha256=h(O/'conclave-center-v08.glb'),prototype_sha256=h(R/'tech-priests_src/prototypes/conclave_center_0558.lua'))
(N/'native-review.json').write_text(json.dumps(result,indent=2)+'\n')
for name in ('create','test','reload','dump','capture'):shutil.copy2(B/(name+'.log'),N/(name+'.log'))
print('V08_ACTUAL_NATIVE_EVIDENCE',result['passed'])
assert result['passed']
