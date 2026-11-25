-- Scheduled catalog work must be bounded without publishing unsafe partial state.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Catalog,Invalidator
local function reload()
  package.loaded['scripts.core.station_catalog']=nil
  package.loaded['scripts.core.catalog_owner_index_1496']=nil
  package.loaded['scripts.core.catalog_dense_scan_1478']=nil
  Catalog=require('scripts.core.station_catalog')
  Invalidator=require('scripts.core.station_area_change_invalidator_0634')
end
local function world(count,overlap)
  game={tick=0};settings={global={}};defines={inventory={chest=1}}
  storage={tech_priests={pairs_by_station={}}}
  _G.get_station_inventory=nil
  _G.get_station_operating_radius=nil
  _G.tech_priests_radar_sweep_ticks_for_pair_0279=function()return 600 end
  _G.tech_priests_efficiency_0579_entities_for_area=nil
  _G.tech_priests_efficiency_0579_note_area_scan=nil
  local w={entities={},queries=0,roster={},contents_reads=0}
  w.force={valid=true,index=1,name='player',object_name='LuaForce'}
  w.surface={valid=true,index=1,name='nauvis',object_name='LuaSurface'}
  w.surface.find_entities_filtered=function(options)
    w.queries=w.queries+1
    if w.query_failure then error('native query failure')end
    local a,b=options.area[1],options.area[2]
    local out={}
    for _,entity in ipairs(w.entities)do
      local p=entity.position
      if entity.valid and p.x>=a[1] and p.x<b[1] and p.y>=a[2] and p.y<b[2] then
        local excluded=false
        for _,name in ipairs(options.type or {})do
          if name==entity.fixture_type then excluded=true end
        end
        if not options.invert or not excluded then
          out[#out+1]=entity
          if options.limit and #out>=options.limit then break end
        end
      end
    end
    return out
  end
  function w.resource(id,x,y)
    local entity={object_name='LuaEntity',valid=true,unit_number=id,
      name='iron-ore',type='resource',fixture_type='resource',amount=1,
      position={x=x,y=y},surface=w.surface,force=w.force,
      prototype={mineable_properties={products={{name='iron-ore',amount=1}}}},
      get_inventory=function()return nil end}
    w.entities[#w.entities+1]=entity
    return entity
  end
  function w.chest(id,item)
    local inventory={valid=true,
      get_contents=function()w.contents_reads=w.contents_reads+1;return {[item]=7}end,
      get_item_count=function(requested)return requested==item and 7 or 0 end}
    local entity={object_name='LuaEntity',valid=true,unit_number=id,
      name='wooden-chest',type='container',fixture_type='container',
      position={x=1,y=1},surface=w.surface,force=w.force,
      get_inventory=function(index)if index==1 then return inventory end end}
    w.entities[#w.entities+1]=entity
    return entity
  end
  for index=1,count do
    local inventory={valid=true,get_contents=function()w.contents_reads=w.contents_reads+1;return {}end,
      get_item_count=function()return 0 end}
    local station={object_name='LuaEntity',valid=true,unit_number=1000+index,
      name='junior-cogitator-station',type='container',position={x=overlap and 0 or (index-1)*100,y=0},
      surface=w.surface,force=w.force,get_inventory=function(id)if id==1 then return inventory end end}
    local pair={station=station,station_unit=station.unit_number,radius=32,
      priest={object_name='LuaEntity',valid=true,unit_number=2000+index}}
    w.roster[index]=pair;storage.tech_priests.pairs_by_station[station.unit_number]=pair
  end
  reload()
  function w.root()return storage.tech_priests.station_catalog_0327 end
  function w.pulse()
    game.tick=game.tick+5
    local before=w.queries
    local inspected=w.root() and w.root().stats.incremental_inspected or 0
    Catalog.scan_due(2)
    assert(w.queries-before<=1,'scheduled admission exceeded one native query')
    assert((w.root().stats.incremental_inspected or 0)-inspected<=128,
      'scheduled admission exceeded128 buffered/validation/release visits')
  end
  function w.until_done(predicate,limit)
    for _=1,limit or 1000 do
      if predicate()then return end
      w.pulse()
    end
    error('catalog continuation did not converge')
  end
  function w.queue(pair)
    Catalog.get_for_pair(pair)
    w.root().next_scan[pair.station_unit]=0
    if w.root().stations[pair.station_unit]then w.root().stations[pair.station_unit].dirty_0634=true end
  end
  return w
end
local function save_copy(value,seen)
  assert(type(value)~='function','saved continuation contains a callback')
  if type(value)~='table' then return value end
  if value.object_name then return value end -- native LuaObjects retain identity on load
  assert(getmetatable(value)==nil,'saved continuation depends on a metatable')
  seen=seen or {};if seen[value]then return seen[value]end
  local out={};seen[value]=out
  for key,item in pairs(value)do out[save_copy(key,seen)]=save_copy(item,seen)end
  return out
end
local function population(w,pair,n,base)
  for index=1,n do w.resource(base+index,pair.station.position.x-18+((index-1)%20)*1.8,
    -12+math.floor((index-1)/20)*1.8)end
end

-- Four real queues share one budget; save/load midway must not lose progress,
-- expose staged claims or fall back to the synchronous index helpers.
local w=world(4,false)
for index,pair in ipairs(w.roster)do population(w,pair,300,index*10000);w.queue(pair)end
local indexed_calls=0
_G.tech_priests_efficiency_0579_entities_for_area=function()indexed_calls=indexed_calls+1;error('synchronous index read')end
_G.tech_priests_efficiency_0579_note_area_scan=function()indexed_calls=indexed_calls+1;error('synchronous index write')end
for _=1,5 do w.pulse()end
assert(next(w.root().owned_resources)==nil,'staged discovery leaked ownership before publication')
local roster_due=w.root().roster_due
for _=1,100 do assert(Catalog.get_for_pair(w.roster[1])==nil)end
assert(w.root().roster_due==roster_due,'cold reads repeatedly invalidated the roster cache')
storage=save_copy(storage);reload()
for index=1,4 do w.roster[index]=storage.tech_priests.pairs_by_station[1000+index]end
w.until_done(function()return (w.root().stats.incremental_completed or 0)==4 end)
assert(indexed_calls==0,'incremental scan called an unbounded index helper')
assert(w.contents_reads==0,'scheduled scan read inventory quantities')
local maximum_delay=0
for _,pair in ipairs(w.roster)do
  local catalog=Catalog.get_for_pair(pair)
  assert(catalog.resources['iron-ore'].sources==300 and catalog.owned_resource_count==300,
    'completed incremental catalog lost entities or ownership')
  assert(pair.known_resources_0326==catalog and pair.known_resources_0327==catalog)
  assert(w.root().next_scan[pair.station_unit]==catalog.scan_started_tick+600,
    'refresh deadline drifted to completion plus the full old interval')
  maximum_delay=math.max(maximum_delay,catalog.scan_completed_tick-catalog.scan_started_tick)
end
assert(maximum_delay<600,'four-station refresh throughput fell below the original cycle')

-- Alternating overlapping stations must all finish without a global revision
-- reset, stealing the winning station's claims or exposing rejected raw sources.
local overlap=world(4,true)
population(overlap,overlap.roster[1],300,30000)
for _,pair in ipairs(overlap.roster)do overlap.queue(pair)end
overlap.until_done(function()return (overlap.root().stats.scans or 0)==4 end)
local owner=overlap.root().owned_resources['u:30001']
assert(owner,'overlapping stations never committed a claim')
for _,pair in ipairs(overlap.roster)do
  local catalog=Catalog.get_for_pair(pair)
  assert(catalog,'a competing station never published its bounded observation')
  if pair.station_unit~=owner then
    assert(not catalog.resources['iron-ore'] and not catalog.mineable_products['iron-ore'],
      'partial raw catalog exposes a different live owner resource')
    assert(Catalog.find_known_source(pair,'iron-ore')==nil,'partial source lookup stole ownership')
  end
end

-- A result-cap failure keeps the old completed snapshot and claims while
-- still making new safely observed physical inventory available to callers.
local partial=world(1,false);local p=partial.roster[1]
local old=partial.resource(40001,0,0)
local retained=Catalog.scan_pair(p)
old.position.x=100
partial.entities={};local chest=partial.chest(40002,'copper-plate')
population(partial,p,300,41000)
Catalog.max_dense_scan_entities_1478=16
partial.queue(p)
partial.until_done(function()return (partial.root().stats.incremental_partial or 0)==1 end)
assert(Catalog.get_for_pair(p)==retained,'incomplete scan replaced the last completed snapshot')
assert(partial.root().owned_resources['u:40001']==p.station_unit,'incomplete scan dropped an old claim')
assert(partial.root().partial_stations[p.station_unit].scan_incomplete_1478)
assert(Catalog.find_known_source(p,'copper-plate').source==chest,'incomplete additions became unusable')

-- Stock-only invalidation clears shortages without replacing the physical
-- token mid-scan. A topology event at the same tick must still replace it.
local stock=world(1,false);p=stock.roster[1]
population(stock,p,300,45000);stock.queue(p)
game.get_player=function()return {valid=true,character={valid=true,
  surface=stock.surface,position={x=0,y=0}}}end
game.tick=10;Catalog.step_pair(p,{queries=1,entities=128})
local physical_marker=p.station_area_dirty_0634
p.emergency_missing_item='iron-plate'
for _=1,200 do Invalidator.handle_player_inventory_event({player_index=1},'stock-only')end
assert(p.station_area_dirty_0634==physical_marker and not p.emergency_missing_item,
  'stock-only event invalidated a physical continuation or retained shortage')
stock.until_done(function()return (stock.root().stats.incremental_completed or 0)==1 end)
assert(not Catalog.get_for_pair(p).scan_incomplete_1478,'stock-only events forced a partial survey')
stock.queue(p);Catalog.step_pair(p,{queries=1,entities=128})
physical_marker=p.station_area_dirty_0634
Invalidator.handle_player_inventory_event({player_index=1},'same-tick-stock')
assert(p.station_area_dirty_0634==physical_marker)
Invalidator.handle_entity_event({entity=stock.entities[1]},'same-tick-topology')
assert(p.station_area_dirty_0634~=physical_marker,'same-tick topology change lost its distinct token')
stock.until_done(function()return (stock.root().stats.incremental_partial or 0)==1 end)

-- Same-tick invalidation and concurrent built/radar observations cannot be
-- cleared by the older traversal or erased by its ownership cleanup.
local changed=world(1,false);p=changed.roster[1]
population(changed,p,200,50000)
retained=Catalog.scan_pair(p);changed.queue(p)
game.tick=10;Catalog.step_pair(p,{queries=1,entities=128})
local built=changed.resource(59000,2,2)
assert(Catalog.claim_built_entity(p,built,'built'))
assert(Catalog.note_radar_detection(p,built,{kind='resource'}))
assert(Invalidator.handle_entity_event({created_entity=built},'same-tick-first'))
assert(Invalidator.handle_entity_event({created_entity=built},'same-tick-second'))
changed.until_done(function()return (changed.root().stats.incremental_partial or 0)==1 end)
assert(Catalog.get_for_pair(p)==retained and retained.dirty_0634,
  'an older pending result erased a newer same-tick invalidation')
assert(changed.root().owned_resources['u:59000']==p.station_unit,
  'older pending cleanup erased a later built/radar claim')
assert(retained.resources['iron-ore'].sources==201,'radar observation was overwritten')
changed.queue(p)
changed.until_done(function()return (changed.root().stats.incremental_completed or 0)==1 end)
assert(Catalog.get_for_pair(p)~=retained and not Catalog.get_for_pair(p).dirty_0634,
  'quiet follow-up failed to complete a fresh snapshot')

-- A destruction after its first validation must not be resurrected at commit.
local dead=world(1,false);p=dead.roster[1]
population(dead,p,400,60000);dead.queue(p)
dead.until_done(function()
  local pending=dead.root().pending_scans[p.station_unit]
  return pending and pending.phase=='validate' and pending.validation_cursor>1
end)
local target=dead.entities[1]
Catalog.handle_destroyed_entity(target,'fixture-death');target.valid=false
dead.until_done(function()return (dead.root().stats.incremental_partial or 0)==1 end)
assert(dead.root().owned_resources['u:60001']==nil,'publication resurrected a destroyed staged claim')
assert(Catalog.get_for_pair(p).resources['iron-ore'].sources==399,
  'validation restart retained destroyed resource counts')

-- Mining-drill depletion is a distinct engine event. Route it through the
-- existing claim owner after an earlier slice has accepted this unitless ore.
local depleted=world(1,false);p=depleted.roster[1]
population(depleted,p,400,65000)
local ore=depleted.entities[1];ore.unit_number=nil
local ore_key=Catalog.entity_key(ore)
assert(Catalog.claim_built_entity(p,ore,'resource'))
depleted.queue(p)
depleted.until_done(function()
  local pending=depleted.root().pending_scans[p.station_unit]
  return pending and pending.phase=='validate' and pending.validation_cursor>1
end)
assert(depleted.root().pending_scans[p.station_unit].context.deferred_claims.by_key[ore_key].accepted)
defines.events={on_built_entity=1,on_entity_died=2,
  on_player_main_inventory_changed=3,on_resource_depleted=4}
local previous_registry=_G.TechPriestsRuntimeEventRegistry
local event_handlers={}
_G.TechPriestsRuntimeEventRegistry={on_event=function(events,handler)
  for _,event_id in ipairs(events)do event_handlers[event_id]=handler end
  return true
end}
assert(Invalidator.install())
local depletion_handler=assert(event_handlers[defines.events.on_resource_depleted],
  'resource-depleted route was not installed')
local before_queries=depleted.queries
local before_revision=depleted.root().station_revisions[p.station_unit]
ore.amount=0
assert(depletion_handler({entity=ore}))
ore.valid=false -- engine removes finite ore after reporting depletion
assert(depleted.queries==before_queries,'depletion performed a world query')
assert(depleted.root().station_revisions[p.station_unit]>before_revision,
  'depletion failed to revise already-validated pending claims')
assert(depleted.root().owned_resources[ore_key]==nil,'depletion retained its existing finite claim')
depleted.until_done(function()return (depleted.root().stats.incremental_partial or 0)==1 end)
assert(depleted.root().owned_resources[ore_key]==nil,'publication resurrected depleted ore')
assert(Catalog.get_for_pair(p).resources['iron-ore'].sources==399,
  'bounded depletion revalidation retained invalid source counts')

-- The same engine event also reports minimum yield on infinite resources.
-- The live source and its existing claim must survive without restarting work.
local infinite=world(1,false);p=infinite.roster[1]
population(infinite,p,400,66000)
ore=infinite.entities[1];ore.prototype.infinite_resource=true
ore_key=Catalog.entity_key(ore)
assert(Catalog.claim_built_entity(p,ore,'resource'))
infinite.queue(p)
infinite.until_done(function()
  local pending=infinite.root().pending_scans[p.station_unit]
  return pending and pending.phase=='validate' and pending.validation_cursor>1
end)
local before_marker=p.station_area_dirty_0634
before_revision=infinite.root().station_revisions[p.station_unit]
before_queries=infinite.queries
assert(depletion_handler({entity=ore})==false)
assert(infinite.root().owned_resources[ore_key]==p.station_unit and ore.valid,
  'minimum infinite yield discarded a usable claim')
assert(infinite.root().station_revisions[p.station_unit]==before_revision
  and p.station_area_dirty_0634==before_marker and infinite.queries==before_queries,
  'minimum infinite yield invalidated physical membership or scanned the world')
infinite.until_done(function()return (infinite.root().stats.incremental_completed or 0)==1 end)
assert(Catalog.get_for_pair(p).resources['iron-ore'].sources==400
  and infinite.root().owned_resources[ore_key]==p.station_unit,
  'minimum-yield source was lost during publication')
_G.TechPriestsRuntimeEventRegistry=previous_registry

-- Relocation, removal and explicit synchronous refresh all supersede saved work.
local moved=world(1,false);p=moved.roster[1]
population(moved,p,300,70000);moved.queue(p)
Catalog.step_pair(p,{queries=1,entities=128})
p.station.position.x=100
local result=Catalog.step_pair(p,{queries=1,entities=128})
assert(result.reason=='domain-or-settings-changed' and not moved.root().pending_scans[p.station_unit])
assert(next(moved.root().owned_resources)==nil,'relocated pending scan leaked claims')
p.station.position.x=0;Catalog.step_pair(p,{queries=1,entities=128})
p.station.valid=false;Catalog.prune_invalid()
assert(not moved.root().pending_scans[p.station_unit],'cold removed station kept pending work')
p.station.valid=true;moved.queue(p);Catalog.step_pair(p,{queries=1,entities=128})
local stale=moved.root().pending_scans[p.station_unit]
local explicit=Catalog.scan_pair(p)
assert(not moved.root().pending_scans[p.station_unit] and not Catalog.publish_pending(p,stale))
assert(Catalog.get_for_pair(p)==explicit,'superseded continuation overwrote explicit refresh')

-- A real unexpected classification error remains visible and cannot publish
-- half-built ownership. Ordinary native-query failure stays explicitly partial.
local failed=world(1,false);p=failed.roster[1]
local bad=failed.resource(80001,0,0);bad.type=nil
setmetatable(bad,{__index=function(_,key)if key=='type' then error('classification exploded')end end})
failed.queue(p)
local ok=pcall(Catalog.step_pair,p,{queries=1,entities=128})
assert(not ok and failed.root().stats.incremental_errors==1,'classification failure was concealed')
assert(not failed.root().pending_scans[p.station_unit] and next(failed.root().owned_resources)==nil,
  'failed continuation published partial ownership')
failed.query_failure=true;failed.queue(p)
failed.until_done(function()return (failed.root().stats.incremental_partial or 0)==1 end)
assert(Catalog.get_for_pair(p).scan_reason_1478=='surface-query-failed',
  'native query failure was mislabeled as complete')

-- Measure the deliberately conservative capacity limit rather than pretending
-- every four-station population can meet a600-tick deadline with this budget.
local dense=world(4,false)
for station_index,pair in ipairs(dense.roster)do
  for index=1,3000 do
    dense.resource(100000+station_index*10000+index,
      pair.station.position.x-25+((index-1)%50),-30+math.floor((index-1)/50))
  end
  dense.queue(pair)
end
dense.until_done(function()return (dense.root().stats.incremental_completed or 0)>=4 end,2000)
local first_finished={}
for _,pair in ipairs(dense.roster)do
  local cat=Catalog.get_for_pair(pair)
  assert(cat.resources['iron-ore'].sources==3000,'dense scheduled scan lost certified coverage')
  first_finished[pair.station_unit]=cat.scan_completed_tick
end
dense.until_done(function()
  for _,pair in ipairs(dense.roster)do
    if Catalog.get_for_pair(pair).scan_completed_tick<=first_finished[pair.station_unit]then return false end
  end
  return true
end,2500)
local dense_delay=dense.root().stats.max_incremental_duration_ticks
assert(dense.root().stats.max_incremental_step_entities<=128
  and dense.root().stats.max_incremental_step_queries<=1)

print('[station-catalog-incremental] PASS: one query/128 visits; four stations; reload; fair overlap; safe partial additions; lifecycle/errors; max four-station300-entity delay='..maximum_delay..' ticks; four-station3000-entity refresh delay='..dense_delay..' ticks')
