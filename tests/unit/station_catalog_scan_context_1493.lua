-- T1-08: per-entity scanning must preserve wired inventory exclusion and tags.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={pairs_by_station={}}};game={tick=1}
defines={inventory={chest=1,assembling_machine_input=2},wire_connector_id={circuit_red=3}}
local setting_reads,rock_wires,contents_reads=0,0,0
local legacy_reads,connection_array_reads,ore_key_reads=0,0,0
local Identity=require('scripts.core.entity_identity_1481')
local original_key=Identity.key
Identity.key=function(entity)
 if entity==nil then return nil end
 if entity.name=='iron-ore' then ore_key_reads=ore_key_reads+1 end
 return original_key(entity)
end
_G.tech_priests_runtime_setting_bool_0626=function(_,fallback)
 setting_reads=setting_reads+1; return fallback
end
local surface={valid=true,index=1,name='nauvis'}
local force={valid=true,index=1,name='player'}
local station={valid=true,unit_number=500,position={x=32,y=32},
 name='junior-cogitator-station',surface=surface,force=force,
 get_inventory=function()return nil end}
local pair={station=station,station_unit=500,priest={valid=true,unit_number=501},radius=32}
storage.tech_priests.pairs_by_station[500]=pair
local entities={};local wired={}
local function machine(i,has_wire)
 local e={valid=true,unit_number=i,position={x=8+i,y=12},surface=surface,
  force=force,name='assembling-machine-1',type='assembling-machine',wired=has_wire}
 e.get_inventory=function(id)
  if id==2 then return {valid=true,get_contents=function()
   contents_reads=contents_reads+1
   return {['iron-plate']=2,['copper-plate']=1}
  end} end
 end
 e.get_wire_connector=function()
  return setmetatable({connection_count=e.wired and 1 or 0},{__index=function(_,key)
   if key=='connections' then
    connection_array_reads=connection_array_reads+1
    error('connection array must not be materialized after a numeric count')
   end
  end})
 end
 return setmetatable(e,{__index=function(_,key)
  if key=='circuit_connected_entities' then
   legacy_reads=legacy_reads+1
   error('LuaEntity does not contain key circuit_connected_entities')
  end
 end})
end
for i=1,10 do entities[#entities+1]=machine(i,false) end
for i=11,13 do wired[#wired+1]=machine(i,true);entities[#entities+1]=wired[#wired] end
for i=1,10 do
 local e={valid=true,unit_number=100+i,position={x=12+i,y=16},
  surface=surface,force=force,name='stone',type='simple-entity',
  prototype={mineable_properties={products={{name='stone',amount=3}}}},
  get_inventory=function() return nil end}
 e.get_wire_connector=function() rock_wires=rock_wires+1 end
 entities[#entities+1]=e
end
local ore={valid=true,unit_number=800,position={x=20,y=20},surface=surface,
 force=force,name='iron-ore',type='resource',amount=50,
 get_inventory=function() return nil end}
entities[#entities+1]=ore
surface.find_entities_filtered=function(opts)
 local out={}
 for _,e in ipairs(entities)do
  out[#out+1]=e
  if opts.limit and #out>=opts.limit then break end
 end
 return out
end
local C=require('scripts.core.station_catalog')
local first=C.scan_pair(pair)
assert(first and not first.scan_incomplete_1478 and first.scan_entities_1478==24)
assert(contents_reads==0 and setting_reads==0,
 'scheduled visual scan read inventory contents/settings')
C.snapshot_inventory(pair,first)
assert(setting_reads==2,'runtime settings reread per entity')
assert(rock_wires==0,'non-inventory rocks received wire checks')
assert(first.storage_items['iron-plate'].count==20,'wired inventories were included')
assert(first.storage_items['copper-plate'].count==10)
assert(first.wired_sources_skipped_1495==3,'wired omissions are not reported')
assert(legacy_reads==0 and connection_array_reads==0,
 'successful native connector answers still triggered obsolete probes or array copies')
assert(ore_key_reads==2,
 'one deduplication key and one ownership key should suffice for a cataloged ore entity')
assert(first.mineable_products.stone.count==30 and first.resources['iron-ore'].count==50,
 'reusing prototype product facts changed physical resource/product accounting')
local root=storage.tech_priests[C.storage_key]
local key=C.entity_key(ore)
local destroyed=0
root.render_tags[key]={object={valid=true,destroy=function()destroyed=destroyed+1 end},
 text={valid=true,destroy=function()destroyed=destroyed+1 end}}
assert(C.claim_built_entity(pair,ore,'resource'))
assert(destroyed==2 and root.render_tags[key]==nil,'legacy visual tags leaked')
wired[1].wired=false;game.tick=1000
local second=C.scan_pair(pair)
local before_snapshot=contents_reads
C.snapshot_inventory(pair,second)
assert(contents_reads>before_snapshot,'explicit ledger snapshot did not refresh contents')
assert(second.storage_items['iron-plate'].count==22,'newly disconnected inventory unavailable')
assert(second.wired_sources_skipped_1495==2,'wire omission count did not refresh')
assert(setting_reads==4 and rock_wires==0,'settings or non-inventory wire checks regressed')
assert(legacy_reads==0 and connection_array_reads==0,
 'subsequent scans repeated obsolete native API probes')
assert(second.mineable_products.stone.count==30 and first.mineable_products.stone.count==30,
 'later catalog accumulation mutated retained prototype facts or earlier snapshots')
-- A successful missing connector is a native empty answer. A failed modern
-- query is not: compatible legacy providers must still protect wired stock.
entities[1].get_wire_connector=function() return nil end
game.tick=2000
local absent_connector=C.scan_pair(pair)
C.snapshot_inventory(pair,absent_connector)
assert(absent_connector.storage_items['iron-plate'].count==22 and legacy_reads==0,
 'a missing native connector lost stock or caused obsolete fallback probing')
entities[2].get_wire_connector=function() error('unsupported modern connector query') end
entities[2].circuit_connected_entities={red={{valid=true}}}
game.tick=3000
local legacy_fallback=C.scan_pair(pair)
C.snapshot_inventory(pair,legacy_fallback)
assert(legacy_fallback.storage_items['iron-plate'].count==20
 and legacy_fallback.wired_sources_skipped_1495==3,
 'a failed modern query incorrectly exposed legacy wired inventory')
print('[station-catalog-scan-context-1493] PASS')
