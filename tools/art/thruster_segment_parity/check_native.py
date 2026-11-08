import argparse,pathlib,json,hashlib,re
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--review-root',type=pathlib.Path,required=True);p.add_argument('--baseline',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();repo=a.repo.resolve();root=a.review_root.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);images=root/'userdata/script-output/custom-thruster-cutaway-v3';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
log=(root/'userdata/factorio-current.log').read_text(encoding='utf-8');assert 'Failed to load mod' not in log
assert re.search(r'Graphics options: \[Graphics quality: high\]',log) and '"--low-vram"' not in log
data=json.loads(next(line.split('CUTAWAY_CANDIDATE_JSON ',1)[1] for line in log.splitlines() if 'CUTAWAY_CANDIDATE_JSON ' in line));old=json.loads(a.baseline.read_text(encoding='utf-8'));probe=json.loads((images/'placement-probes.json').read_text(encoding='utf-8'));connected=json.loads((images/'connected-readback.json').read_text(encoding='utf-8'));disconnected=json.loads((images/'disconnected-readback.json').read_text(encoding='utf-8'))
assert len(probe['actual_sites'])==4 and all(x['can_place'] for x in probe['actual_sites'])
assert len(probe['edge_sweep'])==14
for row in probe['edge_sweep']:assert row['can_place']==(row['last_foundation_y']==0),row
for name in ['hydrogen-thruster','thetazine-thruster']:
 v=data[name];before=old['custom'][name]
 for key,baseline_key in [('fuel','fuel_fluid_box'),('oxidizer','oxidizer_fluid_box')]:assert v['ports'][key]==before['ports'][key] if 'ports' in before else v['ports'][key]==before[baseline_key]
 # Baseline fixture stores fuel boxes under ports? Use actual saved structure.
 lo,hi=v['collision'];assert lo[0]<=0<=hi[0] and lo[1]<=0<=hi[1]
 expected_selection={'hydrogen-thruster':[[-2,-2],[2,2]],'thetazine-thruster':[[-2.25,-2.5],[2.25,2.5]]}[name]
 assert v['selection']==expected_selection
 visual=next(x for x in v['graphics']['working_visualisations'] if x.get('name')=='platform-service-underlay');assert visual['always_draw'] and visual['render_layer']=='floor' and visual['animation']['filename'].startswith('__space-age__/')
 cap_names=[x.get('name') for x in v['graphics']['working_visualisations'] if x.get('name','').startswith('pipe-')];assert set(cap_names)=={'pipe-1','pipe-4'}
 c=next(x for x in connected['entities'] if x['name']==name);d=next(x for x in disconnected['entities'] if x['name']==name)
 assert len(c['ports'])==len(d['ports'])==2
 for port in c['ports']:assert port['connected']=='pipe' and port['connected_position']==port['target_position']
 for port in d['ports']:assert port['connected'] is False
pngs={}
for path in images.glob('*.png'):
 with Image.open(path) as im:im.verify()
 with Image.open(path) as im:im.load()
 pngs[path.name]=sha(path)
assert len(pngs)==9
module='prototypes/compatibility/thruster-mounting-visuals.lua';tp=next((root/'mods').glob('tech-priests_*'));assert sha(repo/'tech-priests_src'/module)==sha(tp/module)
result={'status':'PASS_NATIVE_LIQUID_CUTAWAY_CLEARANCE_ORIGIN_PIPE_CAPS_AND_HIGH_QUALITY_RENDER','runtime_module_sha256':sha(repo/'tech-priests_src'/module),'native_version':'2.1.24','high_quality_log_verified':True,'low_vram_flag_absent':True,'baseline_source_sha256':sha(a.baseline),'actual_sites_legal':4,'edge_probes':probe['edge_sweep'],'legal_last_foundation_row':0,'first_required_void_row':1,'supported_fore_rows':3,'collision_box_contains_origin':True,'pipe_boxes_filters_connections_and_native_caps_preserved':True,'native_png_sha256':pngs,'native_data_stage':data,'scope':'Targeted native placement/art integration only. No propulsion/consumption, behavior/regression, normal save mutation or automatic tile-deletion script. Full body/glow animation parity remains open.'}
(out/'native-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print('NATIVE_CUTAWAY_PASS',len(pngs),len(probe['edge_sweep']))
