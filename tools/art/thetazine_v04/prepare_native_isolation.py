"""Extend the local-only native review with separately visible exhaust layers."""
import pathlib,argparse,subprocess,sys,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--study',type=pathlib.Path,required=True);p.add_argument('--review-root',type=pathlib.Path,required=True);p.add_argument('--flame-y-adjust',type=float,default=0.0);a=p.parse_args();W=pathlib.Path(__file__).parent;profile=a.review_root.resolve();subprocess.run([sys.executable,str(W/'prepare_native.py'),'--study',str(a.study.resolve()),'--review-root',str(profile),'--flame-y-adjust',str(a.flame_y_adjust)],check=True);M=profile/'mods/model-visual-review_0.1.0';data=M/'data-final-fixes.lua';control=M/'scenarios/model-placement/control.lua'
extra='''
-- Exhaust-layer isolation is confined to this disposable graphics-review mod.
for _,spec in ipairs({{'source-light',false,false,true},{'native-jet',true,false,false},{'smoke',false,true,false}}) do
 local v=table.deepcopy(p);v.name='thetazine-v04-isolate-'..spec[1];v.localised_name={'','V04 layer: '..spec[1]}
 if not spec[2] then v.graphics_set.flame_effect=nil end
 if not spec[3] then v.plumes=nil end
 if not spec[4] then
  local keep={};for _,w in ipairs(v.graphics_set.working_visualisations) do if w.name~='v04-separate-heat-glow' then keep[#keep+1]=w end end;v.graphics_set.working_visualisations=keep
 end
 data:extend({v})
end
''';data.write_text(data.read_text()+extra,encoding='utf-8',newline='\n')
c=control.read_text();c=c.replace('for x=-8,24 do','for x=-8,96 do')
c=c.replace('s.set_tiles(void)',"for _,cx in ipairs({33,50,67,84}) do for x=cx-2,cx+2 do for y=1,100 do void[#void+1]={name='empty-space',position={x,y}} end end end;s.set_tiles(void)")
spawn='''storage.isolation={}
 for i,name in ipairs({'source-light','native-jet','smoke','vanilla'}) do
  local x=name=='vanilla' and 84 or 16.5+17*i;local y=name=='vanilla' and -1.5 or .5;local proto=name=='vanilla' and 'thruster' or 'thetazine-v04-isolate-'..name
  assert(s.can_place_entity{name=proto,position={x,y},direction=defines.direction.north,force='player'},'Isolation site illegal: '..name)
  local v=assert(s.create_entity{name=proto,position={x,y},direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.isolation[#storage.isolation+1]={name=name,entity=v,x=x}
 end
'''
c=c.replace('storage.entity=e','storage.entity=e;'+spawn)
c=c.replace(' supplied_levels(.85,.85);'," for _,fixture in pairs(s.find_entities_filtered{area={{-8,-12},{96,12}}}) do if fixture.type=='thruster' or fixture.type=='pipe' then fixture.destructible=false end end\n supplied_levels(.85,.85);")
c=c.replace('if tick==55 then','if tick==55 or tick%30==0 then')
# Replace only the tick-body invocation; the function definition stays intact.
c=c.replace(' supplied_levels(fuel,water)\n'," supplied_levels(fuel,water)\n for _,r in ipairs(storage.isolation or {}) do local v=r.entity;if fuel<=0 or water<=0 then v.clear_fluid_inside() else v.set_fluid(1,{name=r.name=='vanilla' and 'thruster-fuel' or 'thetazine-fuel',amount=v.get_fluid_capacity(1)*fuel});v.set_fluid(2,{name=r.name=='vanilla' and 'thruster-oxidizer' or 'water',amount=v.get_fluid_capacity(2)*water}) end end\n")
c=c.replace('helpers.table_to_json({ports=ports',"helpers.table_to_json({source_native_sha256='"+json.loads((a.study/'source-manifest.json').read_text())['native_sha256']+"',ports=ports")
capture='''
 if tick==338 or tick==342 then
  local views={{name='integrated',x=16.5}};for _,r in ipairs(storage.isolation) do views[#views+1]=r end
  for _,r in ipairs(views) do game.take_screenshot{player=game.players[1],surface=storage.surface,position={r.x,12.5},resolution={1100,1800},zoom=1.1,daytime=0,show_gui=false,force_render=true,path='thetazine-v04-native/isolation/'..r.name..'-'..tick..'.png'} end
 end
''';c=c.replace(' if tick==670 then',capture+' if tick==670 then');control.write_text(c,encoding='utf-8',newline='\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();receipt=json.loads((profile/'v04-preparation-receipt.json').read_text());receipt.update(data_sha256=sha(data),control_sha256=sha(control),isolation_layers=['integrated','source-light','native-jet','smoke','vanilla'],isolation_scope='Review-only scene and prototype copies; no normal-mod or gameplay edits. Actual installed vanilla is the control; source light/native jet/smoke shown separately.');(profile/'v04-preparation-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n');print('NATIVE_LAYER_ISOLATION_PREPARED')
