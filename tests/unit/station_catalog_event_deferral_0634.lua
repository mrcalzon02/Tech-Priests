-- Construction/removal bursts must use the existing bounded catalog scanner.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
game={tick=1};settings={global={}};defines={inventory={chest=1},events={
  on_built_entity=1,on_entity_died=2,on_player_main_inventory_changed=3}}
storage={tech_priests={pairs_by_station={}}}
local handlers={}
script={on_event=function(id,handler)handlers[id]=handler end,
  get_event_handler=function(id)return handlers[id]end,
  on_nth_tick=function()end}
TechPriestsRuntimeEventRegistry=require('scripts.core.runtime_event_registry')
local function emit(name,event)
  event.name=defines.events[name];event.tick=game.tick
  assert(handlers[event.name],'missing installed event route')(event)
end
local surface={valid=true,index=1,name='nauvis'}
local force={valid=true,index=1,name='player'}
local chest_prototype={name='wooden-chest',type='container',
  get_inventory_size=function(id)if id==1 then return 16 end end}
prototypes={entity={['wooden-chest']=chest_prototype}}
local queries,inventory_queries,entities=0,0,{}
surface.find_entities_filtered=function(query)
  if query.invert then queries=queries+1 else inventory_queries=inventory_queries+1 end
  local types={}
  if type(query.type)=='string' then types[query.type]=true
  else for _,kind in ipairs(query.type or {})do types[kind]=true end end
  local out={}
  for _,entity in ipairs(entities)do
    local matches=not query.type or types[entity.type]==true
    if query.invert then matches=not matches end
    if entity.valid and matches then out[#out+1]=entity end
  end
  return out
end
local function chest(unit)
  local inv={valid=true,get_contents=function()return {['iron-plate']=unit}end,
    get_item_count=function(item)return item=='iron-plate' and unit or 0 end}
  return {valid=true,unit_number=unit,name='wooden-chest',type='container',
    position={x=1,y=1},surface=surface,force=force,prototype=chest_prototype,
    get_inventory=function(id)if id==1 then return inv end end}
end
entities[1]=chest(10)
local roster={}
for i=1,4 do
  local station={valid=true,unit_number=100+i,name='junior-cogitator-station',
    type='container',position={x=i,y=0},surface=surface,force=force}
  local pair={station=station,station_unit=station.unit_number,
    priest={valid=true,unit_number=200+i},radius=32}
  roster[#roster+1]=pair
  storage.tech_priests.pairs_by_station[station.unit_number]=pair
end
local Catalog=require('scripts.core.station_catalog')
local Invalidation=require('scripts.core.station_area_change_invalidator_0634')
assert(require('scripts.core.efficiency_economy_0587').install())
assert(Invalidation.install())
_G.tech_priests_0327_scan_station_catalog=Catalog.scan_pair
for _,pair in ipairs(roster)do assert(Catalog.scan_pair(pair))end
assert(queries==4 and inventory_queries==4,
  'each station should seed inventories once and survey the remaining world once')
local originals={}
for i,pair in ipairs(roster)do originals[i]=Catalog.get_for_pair(pair)end

game.tick=2
entities[2]=chest(11)
for i=1,200 do
  emit('on_built_entity',{created_entity=entities[2]})
end
assert(queries==4,'event burst performed synchronous area scans')
for i,pair in ipairs(roster)do
  assert(Catalog.get_for_pair(pair)==originals[i],
    'dirty snapshot deletion forced a reader to rescan')
  assert(originals[i].dirty_0634,'event failed to invalidate clean reuse')
end
assert(queries==4,'a catalog reader bypassed the existing scan budget')

game.tick=60
Catalog.scan_due(2)
assert(queries==6,'existing scanner did not respect its two-station budget')
game.tick=120
Catalog.scan_due(2)
assert(queries==8,'remaining dirty stations were not serviced next pulse')
for _,pair in ipairs(roster)do
  local fresh=Catalog.get_for_pair(pair)
  assert(not fresh.dirty_0634 and fresh.entities['wooden-chest'].count==2,
    'dirty snapshot was clean-reused or new construction was missed')
end

-- Inventory/cursor events change stock, not the surrounding entity list.
-- Clear shortage conclusions while retaining each physical catalog's due
-- time and clean status; a player transfer must not request world discovery.
local catalog_root=storage.tech_priests.station_catalog_0327
local prior_due={}
for _,pair in ipairs(roster)do
  local unit=pair.station.unit_number
  prior_due[unit]=catalog_root.next_scan[unit]
  pair.emergency_missing_item='iron-plate'
end
game.get_player=function()
  return {valid=true,character={valid=true,surface=surface,position={x=1,y=0}}}
end
for i=1,200 do
  emit('on_player_main_inventory_changed',{player_index=1})
end
for _,pair in ipairs(roster)do
  local unit=pair.station.unit_number
  assert(not Catalog.get_for_pair(pair).dirty_0634
    and catalog_root.next_scan[unit]==prior_due[unit]
    and pair.emergency_missing_item==nil,
    'stock changes dirtied spatial membership or retained a stale shortage')
end
assert(queries==8,'player stock changes rediscovered nearby inventories')

game.tick=121
emit('on_entity_died',{entity=entities[1]})
emit('on_entity_died',{entity=entities[2]})
entities[1].valid=false;entities[2].valid=false
for _,pair in ipairs(roster)do
  assert(Catalog.find_known_source(pair,'iron-plate')==nil,
    'retained snapshot exposed a destroyed physical source')
end
assert(queries==8,'removal event or source lookup performed an eager area scan')
game.tick=180;Catalog.scan_due(2)
game.tick=240;Catalog.scan_due(2)
for _,pair in ipairs(roster)do
  assert(Catalog.get_for_pair(pair).entities['wooden-chest']==nil,
    'bounded refresh did not remove destroyed entities')
end

-- Continuous nearby construction dirties all four stations before every
-- pulse. Restarting the pair iteration would permanently favor the first
-- two stations; retained snapshots must still receive fair refreshes.
local refreshes={}
for pulse=1,4 do
  game.tick=240+pulse*60
  local added=chest(20+pulse)
  entities[#entities+1]=added
  local before=queries
  emit('on_built_entity',{created_entity=added})
  assert(queries==before,'continuous construction performed eager scanning')
  Catalog.scan_due(2)
  assert(queries==before+2,'continuous construction exceeded scan budget')
  local updated=0
  for _,pair in ipairs(roster)do
    if Catalog.get_for_pair(pair).tick==game.tick then
      local unit=pair.station.unit_number
      refreshes[unit]=(refreshes[unit]or 0)+1
      updated=updated+1
    end
  end
  assert(updated==2,'scanner did not refresh exactly two dirty stations')
end
for _,pair in ipairs(roster)do
  assert(refreshes[pair.station.unit_number]==2,
    'continuous event stream starved a dirty station catalog')
end
assert(inventory_queries==4,'events, item questions or resource surveys rediscovered inventory membership')
print('[station-catalog-event-deferral-0634] PASS: world events deferred fairly; 200 stock events clear shortages without dirtying physical membership; live validity')
