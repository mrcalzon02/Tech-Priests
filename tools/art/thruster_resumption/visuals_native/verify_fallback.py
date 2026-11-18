"""Actual native ordinary-drive fallback with optional animation paths absent."""
import argparse,pathlib,json,hashlib
p=argparse.ArgumentParser();p.add_argument('profile',type=pathlib.Path);a=p.parse_args();r=a.profile.resolve();sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest();prep=json.loads((r/'preparation.json').read_text());assert prep['optional_animation_assets_present']==False
src=r/'user-data/script-output/visual-power-native/continuous-results.json';j=json.loads(src.read_text());assert not j['objects']and len(j['rows'])==2;rows=[]
for s in j['rows']:
 assert s['registered']and s.get('visuals')is None
 assert s['sink']['valid']and s['sink']['energy']>0 and abs(s['sink']['power_watts']-s['operation']['power_watts'])<.01
 assert s['fluid1']['amount']>0 and s['fluid2']['amount']>0 and s['platform_speed']>0
 rows.append({'unit':s['unit'],'actual_power_watts':s['sink']['power_watts'],'factor':s['operation']['factor'],'native_platform_speed':s['platform_speed'],'no_visual_state_or_objects':True,'real_internal_fluid_stores_positive':True})
result={'status':'PASS_NATIVE_OPTIONAL_ASSET_ABSENCE_SKIPS_VISUALS_PRESERVES_REAL_SERVICE','preparation_sha256':sha(r/'preparation.json'),'native_evidence_sha256':sha(src),'updated_runtime_source_hashes':prep['updated_runtime_source_hashes'],'rows':rows,'scope':'Actual2.1.24 headless ordinary registered drive operation with no optional AnimationPrototype names; no pixel art claim.'};(r/'optional-visual-fallback-validation.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
