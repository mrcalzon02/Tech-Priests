"""Read actual native evidence, retain hard failures, and hash the tested inputs."""
from pathlib import Path
import argparse, datetime, hashlib, json, zipfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('output_root',type=Path)
args=parser.parse_args();root=args.output_root.resolve()
def read(path):return json.loads(path.read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
outputs=root/'user-data/script-output/thruster-resume'
native=read(outputs/'native-results.json')
continuous=read(outputs/'continuous-results.json')
reloaded=read(outputs/'reload-results.json')
assert native['passed'] is True and native['independent_phase'] is True
assert continuous['passed'] is True and reloaded['passed'] is True
assert continuous==reloaded,'Actual uninterrupted/reloaded states differ'
assert len(native['rows'])==4
rows=[]
for row in native['rows']:
    assert row['passed'] is True
    result={k:row[k]for k in ('name','placement_legal','movement','passed')}
    result['platform_weight_kg']=row['initial']['platform_weight']
    if 'cycle_samples'in row:
        for key in ('unpowered_refusal','powered_service','no_visible_ports','power_cut_refusal','power_recovery','sink_replaced','native_cycle','power_bounds','significant_variation'):
            assert row[key] is True,(row['name'],key)
            result[key]=True
        for key in ('minimum_power_watts','maximum_power_watts','minimum_fluid','maximum_fluid'):
            result[key]=row[key]
        departed=[v for v in row['cycle_samples']if v['connection']is not False and v.get('platform_distance',0)>0 and v['platform_speed']>0]
        assert departed
        first=departed[0]
        result['first_recorded_departure']={k:first[k]for k in ('tick','platform_speed','platform_distance','connection')}
        result['cycle_samples']=len(row['cycle_samples'])
        result['initial_native_sink_power_watts']=row['initial']['power_usage_watts']
        assert result['initial_native_sink_power_watts']==12000000
    else:
        assert row['native_consumption'] is True and row['connected_ports'] is True
        result['native_consumption']=True;result['connected_ports']=True
        result['working_sample']={k:row['working'][k]for k in ('tick','platform_speed','platform_distance','connection','fluid1','fluid2')}
    rows.append(result)
source=read(root/'source-binding.json')
updates=read(root/'dynamic-source-binding.json')if(root/'dynamic-source-binding.json').exists()else{'updated_files':{}}
expected_inputs=dict(source['files']);expected_inputs.update(updates['updated_files'])
for rel,expected in expected_inputs.items():
    assert sha(root/'mods/tech-priests'/rel)==expected,'Frozen final source changed: '+rel
saves=list((root/'user-data/saves').glob('*thruster-resume-complete*.zip'))
assert len(saves)==1
with zipfile.ZipFile(saves[0])as z:assert z.testzip()is None
assert 'Saving finished' in(root/'server.log').read_text(errors='replace')
evidence={}
for p in [*outputs.glob('*results.json'),saves[0],root/'create.log',root/'test.log',root/'server.log',root/'reload.log',root/'source-binding.json',root/'dynamic-source-binding.json']:
    if p.exists():evidence[p.relative_to(root).as_posix()]={'sha256':sha(p),'bytes':p.stat().st_size}
for name in ('run.py','control.lua','data.lua','verify.py'):
    evidence[name]={'sha256':sha(Path(__file__).with_name(name)),'bytes':Path(__file__).with_name(name).stat().st_size}
summary={
    'status':'PASS_FOUR_NATIVE_DRIVES_DYNAMIC_FUSION_AND_EXACT_SAVE_RELOAD',
    'verified_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'engine':'Factorio 2.1.24 build 87808, Steam win64, base/Space Age/Quality/Elevated Rails',
    'seed':17112026,'native_rows':rows,'independent_fusion_phase':True,
    'saved_tick':1500,'compared_tick':1560,'exact_uninterrupted_reload_match':True,
    'source_snapshot':{'original_file_count':len(source['files']),'final_updated_files':updates['updated_files'],'source_binding':'source-binding.json','dynamic_binding':'dynamic-source-binding.json'},
    'native_interpretation':[
        'Read actual LuaEntity power_usage times60, actual native fluid stores and real platform connection/distance; nonzero speed alone does not prove departure.',
        'Narrow precision-drive flight uses a20.8-ton hub/corridor/spine platform; other bodies use84.8–86.6-ton disposable platforms. These are functional checks, not comparative balance measurements.',
        'The eight-second operating cycle runs throughout the powered and unpowered periods;150 ten-tick native samples span more than three complete periods.',
        'A newly rebuilt electrical sink needs one service interval to recharge. Its power phase is checked immediately; fluid-target tolerance resumes after that interval.',
        'Power-cut no-refill proof waits for the real30MJ sink to drain, clears residual hidden working fluid, and observes60ticks with no native refill before recovery.',
        'The test electrical source is a private native100MW electric-energy-interface on each fusion platform; ordinary thruster prototypes and runtime services are exercised.',
    ],
    'limits':['No ordinary personal save/profile or installed mod was changed.','No owner visual acceptance or final authored fusion-model completion is inferred.','Optional third-party compatibility and final balance/energy economy remain separate.'],
    'evidence':evidence,
}
(root/'validation-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(summary['status']);print('EXACT_RELOAD_MATCH',summary['exact_uninterrupted_reload_match']);print('SOURCE_FILES',len(source['files']),'FINAL_UPDATES',len(updates['updated_files']))
