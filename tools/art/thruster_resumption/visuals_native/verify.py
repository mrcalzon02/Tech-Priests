"""Verify actual native visual API/power records; never assert FX appearance."""
import argparse,pathlib,json,hashlib,math
p=argparse.ArgumentParser();p.add_argument('profile',type=pathlib.Path);a=p.parse_args();root=a.profile.resolve();sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest();prep=json.loads((root/'preparation.json').read_text());repo=pathlib.Path(__file__).resolve().parents[4];source=repo/'tech-priests_src'
assert sha(source/'control.lua')==prep['ordinary_control_sha256'];private=root/'mods/tech-priests';assert sha(private/'control.lua')==prep['private_control_observer_sha256']
for name,digest in prep['updated_runtime_source_hashes'].items():assert sha(private/name)==digest
reports=[]
for filename in ('continuous-results.json','reload-results.json'):
 path=root/'user-data/script-output/visual-power-native'/filename;j=json.loads(path.read_text());assert j['initialized_after_main']and j['reloaded']==filename.startswith('reload');max_color_error=0;max_watt_error=0;rows=[]
 for row in j['rows']:
  assert row['initial']['registered'];colors=[];factors=[];powered_count=0;plume_on=0;previous=None;stable_gate_checks=0;native_gate_transitions=[]
  for s in row['samples']:
   assert s['registered']and s['visuals'],(row['name'],s)
   op,v,sink=s['operation'],s['visuals'],s['sink'];assert not v.get('render_errors'),v
   error=abs(op['power_watts']-sink['power_watts']);max_watt_error=max(max_watt_error,error);assert error<.01,(s,error)
   assert op['last_tick']==v['last_tick']and 0<=s['engine_tick']-op['last_tick']<=10,('Different or stale service operation sample',s)
   assert .5<=op['factor']<=1.5;factors.append(op['factor'])
   for key in ('energy','plume'):
    obj=v[key];assert obj.get('id')and obj.get('valid',True)and obj['time_to_live']>0,(key,s)
    level=op['factor']/1.5 if v['powered']else 0
    for ch in ('r','g','b','a'):
     delta=abs(obj['color'][ch]-level);max_color_error=max(max_color_error,delta);assert delta<1e-6,(row['name'],key,ch,s,delta)
    if key=='energy':assert obj['visible']==v['powered'],('Energy visibility disagrees actual power',s)
    else:
     gate=lambda q:q['platform_paused']==False and q['status']==j['definitions']['working_status']and q['platform_state']==j['definitions']['on_the_path']
     # Native entity status can change between the prior nth_tick service and
     # this observer. Check exact visibility on stable native gate windows;
     # retain every transition witness rather than pretending observer-time
     # status was the status seen by the preceding real service call.
     if previous and gate(previous)==gate(s):
      stable_gate_checks+=1;assert obj['visible']==(v['powered']and gate(s)),('Stable native propulsion gate disagrees plume',s)
     else:native_gate_transitions.append({'tick':s['tick'],'actual_status':s['status'],'actual_platform_state':s['platform_state'],'actual_platform_paused':s['platform_paused'],'actual_plume_visible':obj['visible'],'last_service_tick':op['last_tick']})
   if v['powered']:
    powered_count+=1;assert s.get('fluid1')and s.get('fluid2');assert s['fluid1']['amount']>0 and s['fluid2']['amount']>0
   plume_on+=int(v['plume']['visible']);previous=s
  assert powered_count>50 and plume_on>10 and max(factors)-min(factors)>.4,(row['name'],powered_count,plume_on)
  assert not row['unpowered']['visuals']['energy']['visible']
  assert not row['powercut']['visuals']['powered']and not row['powercut']['visuals']['energy']['visible']and not row['powercut']['visuals']['plume']['visible']
  assert row['restored']['visuals']['powered']and row['restored']['visuals']['energy']['visible']
  assert row['paused']['visuals']['powered']and row['paused']['visuals']['energy']['visible']and not row['paused']['visuals']['plume']['visible']
  assert row['repaired']['sink']['unit']!=row['removed_sink']and row['repaired']['sink']['valid']
  for key in ('energy','plume'):
   assert row['pre_repair']['visuals'][key]['id']==row['repaired']['visuals'][key]['id'],('Sink repair replaced valid visual IDs',key,row)
   assert row['pre_save']['visuals'][key]['id']==row['post_save_or_reload']['visuals'][key]['id'],('Save/reload lost valid visual IDs',key,row)
  assert not row['removed']['registered']and row['remaining_sinks']==0
  assert stable_gate_checks>100
  rows.append({'prototype':row['name'],'unit':row['unit'],'powered_samples':powered_count,'visible_plume_samples':plume_on,'factor_range':[min(factors),max(factors)],'stable_native_plume_gate_checks':stable_gate_checks,'native_gate_transition_witnesses':native_gate_transitions,'sink_repair_ids_preserved':True,'save_reload_ids_preserved':True,'power_cut_hidden_zero_rgba':True,'pause_energy_on_plume_off':True,'entity_removal_clean':True})
 assert not j['render_objects_after_removal'];a_samples,b_samples=[r['samples']for r in j['rows']];deltas=[abs(x['operation']['factor']-y['operation']['factor'])for x,y in zip(a_samples,b_samples)];assert max(deltas)>.1
 reports.append({'file':filename,'sha256':sha(path),'actual_reloaded':j['reloaded'],'maximum_actual_RGBA_error_to_operation_factor_over1_5':max_color_error,'maximum_same_operation_sink_watt_error':max_watt_error,'independent_phase_max_factor_difference':max(deltas),'rows':rows})
result={'status':'PASS_NATIVE_REAL_VISUAL_POWER_RGBA_LIFECYCLE_AND_SAVE_RELOAD','profile':str(root),'preparation_sha256':sha(root/'preparation.json'),'updated_runtime_source_hashes':prep['updated_runtime_source_hashes'],'actual_native_reports':reports,'scope':'Actual Factorio2.1.24 headless LuaRenderObjects and ordinary registered thrusters/sinks/fluids. Private1px animation stubs exercise API and lifecycle only; no FX pixel appearance, shader, plume shape or final art installation acceptance.'};(root/'visual-power-native-validation.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
