"""Actual data-stage drawing import and exact preservation of all other fields."""
import pathlib,json,hashlib,copy
W=pathlib.Path(__file__).parent;R=W/'pilot-35';repo=pathlib.Path('C:/GITS/Tech-Priests');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();before=json.loads((R/'normal-prototype-before.json').read_text());after=json.loads((R/'normal-prototype-after.json').read_text());allowed={'graphics_set','drawing_box','plumes'};changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k));assert set(changed)<=allowed and 'graphics_set'in changed;assert {k:v for k,v in before.items() if k not in allowed}=={k:v for k,v in after.items() if k not in allowed}
def caps(p):return {v['name']:v for v in p['graphics_set']['working_visualisations'] if v.get('enabled_by_name')}
assert caps(before)==caps(after);assert len(caps(after))==2;assert 'not-rotatable'in after['flags'];g=after['graphics_set'];body,shadow=g['animation']['north']['layers'];assert body['frame_count']==shadow['frame_count']==64 and body['animation_speed']==shadow['animation_speed']==.5;assert shadow['draw_as_shadow'];assert all(v['frame_count']*v['repeat_count']==64 for v in g['idle_animation']['north']['layers']);assert g['always_draw_idle_animation'] is False
heat=next(v for v in g['working_visualisations'] if v['name']=='v04-separate-heat-glow')['animation']['layers'][0];assert heat['draw_as_glow'] and heat['blend_mode']=='additive' and heat['frame_count']==64;assert not any('frame-counter' in str(v) for v in [g])
paths=set()
def walk(v):
 if isinstance(v,str) and v.startswith('__tech-priests__/graphics/entity/thetazine-thruster-v04/'):paths.add(v)
 elif isinstance(v,dict):
  for c in v.values():walk(c)
 elif isinstance(v,list):
  for c in v:walk(c)
walk(g);assert len(paths)==9;files=[]
for v in sorted(paths):
 p=repo/'tech-priests_src'/v.removeprefix('__tech-priests__/');source=R/'source-package'/p.name;assert sha(p)==sha(source);files.append({'path':p.relative_to(repo).as_posix(),'sha256':sha(p)})
# Compare the actual normal graph to the previously captured reviewed graph,
# removing only review counters and its texture namespace.
log=(R/'native-stop-zero-amount-rejected.log').read_text(encoding='utf-8');line=next(l.split('THETAZINE_V04_NATIVE_JSON ',1)[1] for l in log.splitlines() if 'THETAZINE_V04_NATIVE_JSON 'in l);reviewed=json.loads(line);prefix='__model-visual-review__/graphics/thetazine-v04/'
def normalize(v):
 if isinstance(v,dict):
  if 'frame-counter.png'in v.get('filename',''):return None
  return {k:normalize(c) for k,c in v.items()}
 if isinstance(v,list):return [n for c in v if (n:=normalize(c))is not None]
 if isinstance(v,str):return v.replace(prefix,'__tech-priests__/graphics/entity/thetazine-thruster-v04/')
 return v
maximum=0
def equal(a,b,path):
 global maximum
 if isinstance(a,(int,float)) and not isinstance(a,bool) and isinstance(b,(int,float)) and not isinstance(b,bool):maximum=max(maximum,abs(a-b));assert abs(a-b)<1e-9,(path,a,b)
 elif isinstance(a,dict):assert isinstance(b,dict) and a.keys()==b.keys(),(path,'keys',a.keys(),b.keys());[equal(v,b[k],path+'.'+k) for k,v in a.items()]
 elif isinstance(a,list):assert isinstance(b,list) and len(a)==len(b),(path,'length');[equal(v,w,path+f'[{i}]') for i,(v,w) in enumerate(zip(a,b))]
 else:assert a==b,(path,a,b)
equal(normalize(reviewed['graphics']),g,'graphics');equal(reviewed['plumes'],after['plumes'],'plumes');m=json.loads((R/'source-manifest.json').read_text());out={'status':'PASS_ACTUAL_NORMAL_IMPORT_GRAPH_AND_ALL_NONVISUAL_FIELDS_PRESERVED','native_sha256':m['native_sha256'],'before_sha256':sha(R/'normal-prototype-before.json'),'after_sha256':sha(R/'normal-prototype-after.json'),'changed_root_fields':changed,'all_other_root_fields_exact':True,'preserved_nonvisual_field_count':len([k for k in before if k not in allowed]),'conditional_cap_names':list(caps(after)),'old_working_frames':before['graphics_set']['animation']['north']['frame_count'],'new_working_frames':64,'native_review_graph_equal_after_counter_namespace_removal':True,'max_json_numeric_difference':maximum,'runtime_images':files,'scope':'Actual data.raw snapshots from exact tracked source before/after. Only drawing graph, drawing bounds and plumes may differ; all other entity fields equal. No behavior/regression/performance test. Actual normal-prototype graphical view remains separately required.'};(R/'normal-import-validation.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps(out))
