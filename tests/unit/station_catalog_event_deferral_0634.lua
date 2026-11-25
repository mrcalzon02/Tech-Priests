-- Construction/removal bursts must use the existing bounded catalog scanner.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
game={tick=1};settings={global={}};defines={inventory={chest=1}}
storage={tech_priests={pairs_by_station={}}}
local surface={valid=true,index=1,name='nauvis'}
local force={valid=true,index=1,name='player'}
local queries,entities=0,{}
surface.find_entities_filtered=function()
  queries=queries+1
  local out={}
  for _,entity in ipairs(entities)do
    if entity.valid then out[#out+1]=entity end
  end
  return out
end
local function chest(unit)
  local inv={valid=true,get_contents=function()return {['iron-plate']=unit}end}
  return {valid=true,unit_number=unit,name='wooden-chest',type='container',
    position={x=1,y=1},surface=surface,force=force,
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
_G.tech_priests_0327_scan_station_catalog=Catalog.scan_pair
for _,pair in ipairs(roster)do assert(Catalog.scan_pair(pair))end
assert(queries==4)
local originals={}
for i,pair in ipairs(roster)do originals[i]=Catalog.get_for_pair(pair)end

game.tick=2
entities[2]=chest(11)
for i=1,200 do
  assert(Invalidation.handle_entity_event({created_entity=entities[2]},'built/created'))
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

game.tick=121
Invalidation.handle_entity_event({entity=entities[1]},'removed/destroyed')
Invalidation.handle_entity_event({entity=entities[2]},'removed/destroyed')
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
  assert(Invalidation.handle_entity_event({created_entity=added},'built/created'))
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
print('[station-catalog-event-deferral-0634] PASS: 200 events, four stations, zero eager scans; bounded fair refresh under continuous events and live validity')
