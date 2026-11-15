"""Bounded native API experiment for decay health/quality across logistics."""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--factorio',required=True);ap.add_argument('--out',required=True);args=ap.parse_args()
    out=Path(args.out).resolve();exe=Path(args.factorio).resolve()
    if out.exists():raise FileExistsError('Preserve API experiment')
    out.mkdir(parents=True);mods=out/'mods';mod=mods/'tp-mh7-pellet-probe_0.0.1';mod.mkdir(parents=True);user=out/'user-data';user.mkdir()
    (mod/'info.json').write_text(json.dumps(dict(name='tp-mh7-pellet-probe',version='0.0.1',title='Isolated native pellet decay experiment',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','quality >= 2.1.24'],spoiling_required=True,quality_required=True,expansion_required=True)))
    (mod/'data.lua').write_text("""local rows={}
for i=0,3 do
 local item=table.deepcopy(data.raw.item['iron-ore']);item.name='tp-mh7-probe-pellet-'..i
 item.type='item-with-tags';item.localised_name='Decay probe phase '..i;item.stack_size=1
 if i<3 then item.spoil_ticks=120;item.spoil_result='tp-mh7-probe-pellet-'..(i+1);item.spoil_quality_change=-1;item.quality_affects_spoil_ticks=false
 item.spoil_to_trigger_result={items_per_trigger=1,trigger={type='direct',action_delivery={type='instant',target_effects={{type='script',effect_id='tp-pellet-phase-'..i}}}}}
 end
 rows[#rows+1]=item
end
data:extend(rows)
""")
    (mod/'control.lua').write_text("""local function dump(name,value) helpers.write_file('pellet-probe/'..name..'.json',helpers.table_to_json(value),false) end
local function snapshot(stack)
 if not stack or not stack.valid_for_read then return {empty=true} end
 return {name=stack.name,count=stack.count,health=stack.health,quality=stack.quality.name,spoil_tick=stack.spoil_tick,spoil_percent=stack.spoil_percent,tags=stack.tags}
end
script.on_init(function()
 local s=game.surfaces[1];s.request_to_generate_chunks({0,0},1);s.force_generate_chunk_requests()
 storage.probe={events={},samples={}}
 local p=storage.probe
 p.chest=s.create_entity{name='steel-chest',position={0,0},force='player'}
 p.chest.get_inventory(defines.inventory.chest).insert{name='tp-mh7-probe-pellet-0',count=1,quality='legendary',health=.10,tags={marker='persist-me'}}
 p.ground=s.create_entity{name='item-on-ground',position={2,0},stack={name='tp-mh7-probe-pellet-0',count=1,quality='legendary',health=.90}}
 p.belt=s.create_entity{name='transport-belt',position={4,0},force='player'}
 p.belt.get_transport_line(1).insert_at_back{name='tp-mh7-probe-pellet-0',count=1,quality='legendary',health=.90}
 p.inv=game.create_inventory(1);p.inv.insert{name='tp-mh7-probe-pellet-0',count=1,quality='legendary',health=.90}
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
 local p=storage.probe;p.events[#p.events+1]={tick=event.tick,effect=event.effect_id,source=event.source_entity and event.source_entity.name or nil,target=event.target_entity and event.target_entity.name or nil,source_position=event.source_position,target_position=event.target_position,quality=event.quality,chest_snapshot=snapshot(p.chest.get_inventory(defines.inventory.chest)[1])}
end)
script.on_event(defines.events.on_tick,function(event)
 if event.tick%30==0 then
  local p=storage.probe;local row={tick=event.tick,chest=snapshot(p.chest.get_inventory(defines.inventory.chest)[1]),ground=p.ground.valid and snapshot(p.ground.stack) or {missing=true},script_inventory=snapshot(p.inv[1])}
  local line=p.belt.get_transport_line(1);row.belt=#line>0 and snapshot(line[1]) or {empty=true};p.samples[#p.samples+1]=row
 end
 if event.tick==480 then dump('readback',{events=storage.probe.events,samples=storage.probe.samples}) end
end)
""")
    enabled={'base','quality','recycler','tp-mh7-pellet-probe'}
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in ('base','quality','recycler','space-age','elevated-rails','tp-mh7-pellet-probe')])))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];save=out/'pellet-probe.zip'
    for label,tail in (('create',['--create',str(save)]),('runtime',['--benchmark',str(save),'--benchmark-ticks','500','--benchmark-runs','1'])):
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        print('PELLET_PROBE',label,result.returncode,flush=True)
        if result.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))


if __name__=='__main__':main()
