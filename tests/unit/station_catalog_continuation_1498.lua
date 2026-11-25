-- Bounded catalog continuation: real owners with adversarial engine fixtures.
-- Engine fixtures only. Production catalog/cache/registry owners are loaded.
package.path='tech-priests_src/?.lua;tech-priests_src/?/init.lua;'..package.path

local function fixture()
  for _,name in ipairs({'station_catalog','efficiency_economy_0587',
      'runtime_event_registry','station_area_change_invalidator_0634',
      'catalog_owner_index_1496'}) do package.loaded['scripts.core.'..name]=nil end
  _G.TechPriestsStationCatalog=nil
  _G.TechPriestsEfficiencyEconomy0587=nil
  _G.TechPriestsRuntimeEventRegistry=nil
  storage={tech_priests={pairs_by_station={}}};game={tick=1,forces={}}
  settings={global={}}
  defines={inventory={chest=1},events={on_built_entity=1,on_entity_died=2,
    on_player_main_inventory_changed=3,on_resource_depleted=4}}
  local handlers={}
  script={on_event=function(id,fn)handlers[id]=fn end,
    get_event_handler=function(id)return handlers[id]end,on_nth_tick=function()end}
  TechPriestsRuntimeEventRegistry=require('scripts.core.runtime_event_registry')
  local world={entries={},queries=0,inventory_queries=0}
  local surface={object_name='LuaSurface',valid=true,index=1,name='nauvis'}
  local force={object_name='LuaForce',valid=true,index=1,name='player',logistic_networks={}}
  game.forces={player=force}
  local resource_proto={name='iron-ore',type='resource',
    mineable_properties={products={{name='iron-ore',amount=1}}},
    get_inventory_size=function()return nil end}
  local chest_proto={name='wooden-chest',type='container',
    get_inventory_size=function(id)if id==1 then return 16 end end}
  prototypes={entity={['iron-ore']=resource_proto,['wooden-chest']=chest_proto}}
  local function resource(id,x,y)
    local e={object_name='LuaEntity',valid=true,unit_number=id,type='resource',
      name='iron-ore',amount=250,position={x=x,y=y},surface=surface,
      force=force,prototype=resource_proto}
    world.entries[#world.entries+1]=e
    return e
  end
  surface.find_entities_filtered=function(opts)
    if opts.invert then world.queries=world.queries+1
    else world.inventory_queries=world.inventory_queries+1 end
    if world.query_failure then error('native query failure')end
    local types={}
    if type(opts.type)=='string' then types[opts.type]=true
    else for _,kind in ipairs(opts.type or {})do types[kind]=true end end
    local a,b=opts.area[1],opts.area[2]
    local ax,ay,bx,by=a.x or a[1],a.y or a[2],b.x or b[1],b.y or b[2]
    local out={}
    for _,e in ipairs(world.entries)do
      local matches=not opts.type or types[e.fixture_type or e.type]==true
      if opts.invert then matches=not matches end
      local box=e.bounding_box
      local in_area=box and box.left_top.x<bx and box.right_bottom.x>ax
        and box.left_top.y<by and box.right_bottom.y>ay
        or not box and e.position.x>=ax and e.position.x<bx
          and e.position.y>=ay and e.position.y<by
      if matches and e.valid and in_area then
        out[#out+1]=e
        if opts.limit and #out>=opts.limit then break end
      end
    end
    return out
  end
  local function pair(unit,name,x)
    local station={object_name='LuaEntity',valid=true,unit_number=unit,
      type='container',name=name,position={x=x,y=32},surface=surface,force=force,
      prototype=chest_proto,get_inventory=function()return nil end}
    local p={station=station,station_unit=unit,radius=32,
      priest={object_name='LuaEntity',valid=true,unit_number=unit+1}}
    storage.tech_priests.pairs_by_station[unit]=p
    return p
  end
  local p=pair(60000,'planetary-magos-cogitator-station',32)
  local lower=pair(70000,'junior-cogitator-station',40)
  local foreign=pair(80000,'senior-cogitator-station',300)
  for i=1,196 do resource(i,2+((i-1)%14)*4.3,2+math.floor((i-1)/14)*4.3)end
  assert(require('scripts.core.efficiency_economy_0587').install())
  local Invalidation=require('scripts.core.station_area_change_invalidator_0634')
  assert(Invalidation.install())
  local C=require('scripts.core.station_catalog')
  C.scan_limit=64
  C.query_budget_per_pulse_1498=1
  C.work_budget_per_pulse_1498=16
  local initial=assert(C.scan_pair(p))
  assert(not initial.scan_incomplete_1478 and initial.scan_entities_1478==196)
  local root=storage.tech_priests[C.storage_key]
  root.next_scan[70000]=1000000;root.next_scan[80000]=1000000
  local ctx={C=C,pair=p,lower=lower,foreign=foreign,world=world,
    resource=resource,root=root,initial=initial,Invalidation=Invalidation}
  function ctx.emit(name,event)
    event.name,event.tick=defines.events[name],game.tick
    assert(handlers[event.name],'missing installed event route: '..name)(event)
  end
  function ctx.job()return root.scan_jobs_1498 and root.scan_jobs_1498[60000]end
  function ctx.pulse()
    game.tick=game.tick+5
    local before=world.queries+world.inventory_queries
    C.scan_due(2)
    assert(world.queries+world.inventory_queries-before<=C.query_budget_per_pulse_1498,
      'one scheduled pulse exceeded its global native query budget')
    assert((root.stats.continuation_last_work_1498 or 0)<=C.work_budget_per_pulse_1498,
      'one scheduled pulse exceeded its global work budget')
  end
  function ctx.dirty()
    -- West edge affects only this station, while the lower rank remains in
    -- the full roster without becoming due. Use the real freshness owner.
    assert(Invalidation.invalidate_near(surface,
      {x=p.station.position.x-32,y=p.station.position.y},'independent-review'))
  end
  function ctx.start()
    ctx.dirty();game.tick=game.tick+(60-game.tick%60)
    for _=1,30 do ctx.pulse();if ctx.job()then return ctx.job()end end
    error('scheduled scan did not retain a pending continuation')
  end
  function ctx.until_(predicate,label)
    for _=1,5000 do if predicate()then return end;ctx.pulse()end
    error('no bounded progress: '..label)
  end
  function ctx.reload()
    -- Change hash-table layouts while preserving aliases and engine identities.
    local copied={}
    local function clone(v)
      if type(v)~='table' or v.object_name then return v end
      if copied[v]then return copied[v]end
      local out={};copied[v]=out
      local keys={};for k in pairs(v)do keys[#keys+1]=k end
      table.sort(keys,function(a,b)return tostring(a)>tostring(b)end)
      for _,k in ipairs(keys)do out[clone(k)]=clone(v[k])end
      return out
    end
    storage=clone(storage)
    for _,name in ipairs({'station_catalog','catalog_dense_scan_1478',
        'catalog_owner_index_1496'})do package.loaded['scripts.core.'..name]=nil end
    _G.TechPriestsStationCatalog=nil
    C=require('scripts.core.station_catalog')
    C.scan_limit=64;C.query_budget_per_pulse_1498=1;C.work_budget_per_pulse_1498=16
    p=storage.tech_priests.pairs_by_station[60000]
    root=storage.tech_priests[C.storage_key]
    ctx.C,ctx.pair,ctx.root=C,p,root
  end
  return ctx
end

-- External radar/build claims must survive cancellation, while speculative
-- claims introduced only by the abandoned scan must be rolled back.
do
  local x=fixture()
  local staged=x.resource(20000,1,1)
  local job=x.start()
  x.until_(function()return x.root.owned_resources['u:20000']==60000 end,
    'new staged claim')
  assert(x.job()==job,'fixture failed to interrupt the pending job')
  local built=x.resource(30000,3,3)
  local radar=x.resource(30001,4,4)
  assert(x.C.claim_built_entity(x.pair,built,'built'))
  assert(x.C.note_radar_detection(x.pair,radar,{kind='resource'}))
  x.pair.station.position={x=1000,y=1000}
  x.dirty()
  x.until_(function()return x.job()~=job end,'domain cancellation')
  assert(x.root.owned_resources['u:20000']==nil,
    'domain cancellation leaked a newly staged claim')
  assert(x.root.owned_resources['u:30000']==60000,
    'domain cancellation discarded an external construction claim')
  assert(x.root.owned_resources['u:30001']==60000,
    'domain cancellation discarded an external radar claim')
  assert(x.root.owned_resources['u:1']==60000,
    'domain cancellation discarded a retained published claim')
  print('[continuation-independent] PASS external radar/build claims and rollback')
end

-- An explicit fresh scan must supersede pending work; subsequent scanner
-- pulses may not publish the old continuation over that newer snapshot.
do
  local x=fixture();local job=x.start()
  local latest=x.resource(30002,5,5)
  game.tick=game.tick+1
  local explicit=assert(x.C.scan_pair(x.pair))
  assert(x.job()==nil,'explicit refresh left an old pending publication')
  assert(explicit~=x.initial and explicit.resources['iron-ore'].sources==197,
    'explicit refresh did not include the latest physical world')
  for _=1,20 do x.pulse()end
  assert(x.C.get_for_pair(x.pair)==explicit,
    'old pending scan overwrote an explicit refreshed snapshot')
  assert(x.root.owned_resources['u:30002']==60000)
  print('[continuation-independent] PASS explicit refresh supersedes pending work')
end

-- A same-tick event after admission is a new change even though its tick is
-- equal to the scan's start tick. It cannot be hidden by timestamp ordering.
do
  local x=fixture();local job=x.start()
  local published=x.C.get_for_pair(x.pair)
  x.dirty()
  x.until_(function()return x.C.get_for_pair(x.pair)~=published end,
    'same-tick post-admission invalidation')
  assert(x.C.get_for_pair(x.pair).dirty_0634,
    'same-tick post-admission topology change was published clean')
  print('[continuation-independent] PASS same-tick topology change remains dirty')
end

-- Ongoing topology invalidation must not repeatedly reset progress. Lower
-- ranks which are not due still belong to the subordinate presentation.
do
  local x=fixture();local job=x.start()
  local published=x.C.get_for_pair(x.pair)
  local pulses=0
  while x.C.get_for_pair(x.pair)==published and pulses<5000 do
    x.dirty();x.pulse();pulses=pulses+1
  end
  local fresh=x.C.get_for_pair(x.pair)
  assert(fresh~=published,'continuous invalidation starved a catalog publication')
  assert(fresh.dirty_0634,'changes during a scan were falsely published clean')
  local subordinate=false
  for _,rec in ipairs(fresh.subordinate_stations or {})do
    if rec.unit==70000 then subordinate=true end
  end
  assert(subordinate,'not-due lower-rank station was omitted from full roster')
  assert(x.world.inventory_queries==1,
    'ordinary continuations rediscovered retained inventory membership')
  print('[continuation-independent] PASS continuous events, complete roster, no inventory rescan; pulses='..pulses)
end

-- Reload during work must resume to the same resource/ownership result.
-- Actual native save serialization is a separate engine fixture.
do
  local x=fixture();x.start()
  for _=1,11 do x.pulse()end
  assert(x.job(),'fixture did not reach a pending midscan reload')
  local previous_tick=x.root.stations[60000].tick
  x.reload()
  x.until_(function()return x.root.stations[60000].tick~=previous_tick end,
    'rehash/reload continuation')
  local final=x.root.stations[60000]
  assert(not final.scan_incomplete_1478 and final.resources['iron-ore'].sources==196,
    'reload skipped, duplicated or falsely truncated physical resources')
  for i=1,196 do assert(x.root.owned_resources['u:'..i]==60000,
    'reload lost physical ownership for '..i)end
  print('[continuation-independent] PASS rehash/reload ownership and totals')
end

-- One shared slice budget must rotate actual progress, not merely advance
-- past unserved second slots and permanently favor alternate station IDs.
do
  local x=fixture();local roster={x.pair};local originals={}
  for i=1,3 do
    local unit=60000+i*10
    local station={}
    for k,v in pairs(x.pair.station)do station[k]=v end
    station.unit_number=unit
    local p={station=station,station_unit=unit,radius=32,
      priest={object_name='LuaEntity',valid=true,unit_number=unit+1}}
    storage.tech_priests.pairs_by_station[unit]=p
    roster[#roster+1]=p
  end
  for _,p in ipairs(roster)do
    originals[p.station_unit]=x.C.scan_pair(p)
    originals[p.station_unit].dirty_0634=true
    x.root.next_scan[p.station_unit]=0
  end
  game.tick=120
  local completed={};local pulses=0
  while pulses<5000 do
    local remaining=false
    for _,p in ipairs(roster)do
      if x.C.get_for_pair(p)~=originals[p.station_unit]then completed[p.station_unit]=true end
      if not completed[p.station_unit]then remaining=true end
    end
    if not remaining then break end
    x.pulse();pulses=pulses+1
  end
  for _,p in ipairs(roster)do assert(completed[p.station_unit],
    'shared slice budget starved station '..p.station_unit)end
  local owner=x.root.owned_resources['u:1']
  for _,p in ipairs(roster)do
    if p.station_unit~=owner then
      assert(not x.C.get_for_pair(p).resources['iron-ore']
        and x.C.find_known_source(p,'iron-ore')==nil,
        'overlapping completed survey exposed a different station\'s claimed resource')
    end
  end
  print('[continuation-independent] PASS four dense stations progress under shared budget; pulses='..pulses)
end

-- If the pair table is replaced while its physical station survives, the
-- cancellation path must restore tracking to the current pair, so a later
-- complete survey can retire old claims instead of leaking them forever.
do
  local x=fixture();local job=x.start()
  local replacement={}
  for k,v in pairs(x.pair)do replacement[k]=v end
  replacement.catalog_owned_resource_keys_0327={}
  storage.tech_priests.pairs_by_station[60000]=replacement
  x.until_(function()return x.job()~=job end,'pair record replacement')
  x.world.entries={}
  x.root.stations[60000].dirty_0634=true
  local empty=assert(x.C.scan_pair(replacement))
  assert(not empty.scan_incomplete_1478 and not empty.resources['iron-ore'])
  assert(x.root.owned_resources['u:1']==nil,
    'replacement pair lost retirement tracking and leaked an absent old claim')
  print('[continuation-independent] PASS pair replacement transfers retirement tracking')
end



-- The normal item/UI view can compact a borrowed source array while a visual
-- continuation is yielded. The replacement must be dirty, then converge in a
-- following bounded survey without another inventory discovery query.
do
  local x=fixture()
  local E=require('scripts.core.efficiency_economy_0587')
  local sources={}
  local function chest(id)
    local e={object_name='LuaEntity',valid=true,unit_number=id,
      type='container',name='wooden-chest',position={x=30,y=30},
      surface=x.pair.station.surface,force=x.pair.station.force,
      prototype=prototypes.entity['wooden-chest'],get_inventory=function()return nil end}
    x.world.entries[#x.world.entries+1]=e
    return e
  end
  for i=1,64 do sources[i]=chest(90000+i)end
  E.invalidate_all('borrowed-array-mutation-fixture')
  local job=x.start()
  x.until_(function()return x.job()==job and job.phase=='inventory'
    and job.inventory_cursor>1 end,'yielded retained identity phase')
  local before_queries=x.world.inventory_queries
  sources[1].valid=false
  assert(x.C.inventory_candidates(x.pair,32)) -- Existing view compacts the array.
  local added=chest(90100)
  E.invalidate_entity_sources({entity=added},'built')
  assert(x.root.next_scan[x.pair.station_unit]==job.next_due,
    'fixture accidentally used the separate0634 dirty marker')
  local previous=x.C.get_for_pair(x.pair)
  x.until_(function()return x.C.get_for_pair(x.pair)~=previous end,
    'publication after retained array mutation')
  local changed=x.C.get_for_pair(x.pair)
  assert(changed.dirty_0634,'borrowed identity mutation was falsely published clean')
  x.until_(function()local c=x.C.get_for_pair(x.pair)
    return c~=changed and not c.dirty_0634 end,'clean follow-up after retained mutation')
  assert(x.C.get_for_pair(x.pair).entities['wooden-chest'].count==64,
    'borrowed compaction/addition silently lost a surviving source')
  assert(x.world.inventory_queries==before_queries,
    'borrowed identity mutation caused inventory rediscovery')
  print('[continuation-independent] PASS borrowed identity compaction/addition and clean follow-up')
end

-- World area queries include overlapping collision boxes. They must retain
-- the old synchronous selection even if the entity center lies outside the
-- station square; inventory candidates have a separate center-based policy.
do
  local x=fixture()
  local edge=x.resource(95000,64.5,32)
  edge.type,edge.name='simple-entity','edge-rock'
  edge.prototype={mineable_properties={products={{name='stone',amount=6}}}}
  edge.bounding_box={left_top={x=63.5,y=31.5},right_bottom={x=65.5,y=32.5}}
  x.initial.dirty_0634=true
  local reference=x.C.scan_pair(x.pair)
  assert(reference.entities['edge-rock'].count==1,'reference fixture did not overlap the native area')
  x.start()
  x.until_(function()return x.C.get_for_pair(x.pair)~=reference end,'collision-box edge publication')
  local final=x.C.get_for_pair(x.pair)
  assert(final.entities['edge-rock'].count==1 and final.mineable_products.stone.count==6,
    'continued world survey incorrectly clipped native collision-box results to entity centers')
  assert(x.root.owned_resources['u:95000']==x.pair.station_unit,
    'continued edge source lost resource ownership')
  assert(x.C.find_known_source(x.pair,'stone').entity==edge,
    'live source guard clipped the native collision-box overlap to its center')
  print('[continuation-independent] PASS native area collision-box selection')
end

-- Stock-only events clear short-lived supply conclusions, without changing
-- the physical dirty token or the deadline of an in-flight world survey.
do
  local x=fixture();local job=x.start()
  local marker,due=x.pair.station_area_dirty_0634,x.root.next_scan[60000]
  local queries=x.world.queries+x.world.inventory_queries
  game.get_player=function()return {valid=true,character={valid=true,
    surface=x.pair.station.surface,position={x=1,y=32}}}end
  x.pair.emergency_missing_item='iron-plate'
  for _=1,200 do x.emit('on_player_main_inventory_changed',{player_index=1})end
  assert(x.pair.station_area_dirty_0634==marker and x.root.next_scan[60000]==due
    and x.pair.emergency_missing_item==nil and x.job()==job,
    'stock-only events changed physical membership or retained a stale shortage')
  assert(x.world.queries+x.world.inventory_queries==queries,
    'stock-only events performed a world query')
  local previous=x.C.get_for_pair(x.pair)
  x.until_(function()return x.C.get_for_pair(x.pair)~=previous end,'stock-only publication')
  assert(not x.C.get_for_pair(x.pair).dirty_0634,
    'stock-only events forced another physical survey')
  print('[continuation-independent] PASS stock-only dirty token and deadline')
end

-- Finite mining-drill depletion is a distinct native event. Its unitless
-- claim must disappear immediately and cannot be restored by an older job.
-- The job keeps progress and the next bounded survey repairs stale tallies.
do
  local x=fixture();local ore=x.resource(nil,1,32)
  x.initial.dirty_0634=true
  local previous=x.C.scan_pair(x.pair)
  local key=x.C.entity_key(ore)
  local job=x.start()
  x.until_(function()return job.catalog.owned_keys[key]end,'accepted unitless finite ore')
  local marker=x.pair.station_area_dirty_0634
  local queries=x.world.queries+x.world.inventory_queries
  ore.amount=0
  x.emit('on_resource_depleted',{entity=ore})
  ore.valid=false -- The engine removes finite ore after reporting depletion.
  assert(x.root.owned_resources[key]==nil and x.job()==job
    and x.pair.station_area_dirty_0634~=marker and x.root.next_scan[60000]==0,
    'finite depletion kept its claim, restarted work, or lost invalidation')
  assert(x.world.queries+x.world.inventory_queries==queries,
    'resource depletion performed a synchronous world query')
  x.until_(function()return x.C.get_for_pair(x.pair)~=previous end,'finite depletion publication')
  local changed=x.C.get_for_pair(x.pair)
  assert(changed.dirty_0634 and x.root.owned_resources[key]==nil,
    'older publication resurrected finite ore or falsely certified freshness')
  assert(x.C.find_known_source(x.pair,'iron-ore').entity~=ore,
    'a live work lookup returned depleted ore from a retained snapshot')
  x.until_(function()local cat=x.C.get_for_pair(x.pair)
    return cat~=changed and not cat.dirty_0634 end,'finite depletion clean follow-up')
  assert(x.C.get_for_pair(x.pair).resources['iron-ore'].sources==196
    and x.root.owned_resources[key]==nil,
    'bounded follow-up retained a depleted tally or restored its ownership')
  print('[continuation-independent] PASS finite depletion and bounded convergence')
end

-- Reaching minimum infinite yield uses the same event, but the live source
-- must stay owned without dirtying, restarting, or querying the world.
do
  local x=fixture();local ore=x.resource(nil,1,32)
  ore.prototype={name='iron-ore',type='resource',infinite_resource=true,
    mineable_properties={products={{name='iron-ore',amount=1}}}}
  x.initial.dirty_0634=true
  local previous=x.C.scan_pair(x.pair)
  local key=x.C.entity_key(ore)
  local job=x.start()
  x.until_(function()return job.catalog.owned_keys[key]end,'accepted infinite source')
  local marker,due=x.pair.station_area_dirty_0634,x.root.next_scan[60000]
  local queries=x.world.queries+x.world.inventory_queries
  x.emit('on_resource_depleted',{entity=ore})
  assert(x.root.owned_resources[key]==60000 and ore.valid and x.job()==job
    and x.pair.station_area_dirty_0634==marker and x.root.next_scan[60000]==due,
    'minimum infinite yield removed a usable source or invalidated its survey')
  assert(x.world.queries+x.world.inventory_queries==queries,
    'minimum infinite yield performed a world query')
  x.until_(function()return x.C.get_for_pair(x.pair)~=previous end,'infinite-yield publication')
  local final=x.C.get_for_pair(x.pair)
  assert(not final.dirty_0634 and final.resources['iron-ore'].sources==197
    and x.root.owned_resources[key]==60000,
    'minimum-yield resource was lost during publication')
  print('[continuation-independent] PASS infinite minimum-yield retention')
end

-- Work readers recheck the canonical owner, live surface/range and distance,
-- then fall through to another retained instance without spatial rediscovery.
do
  local x=fixture()
  local a,b=x.resource(97001,31,32),x.resource(97002,30,32)
  for _,entity in ipairs({a,b})do
    entity.name='copper-ore'
    entity.prototype={name='copper-ore',type='resource',
      mineable_properties={products={{name='copper-ore',amount=1}}}}
  end
  x.initial.dirty_0634=true;x.C.scan_pair(x.pair)
  assert(x.C.find_known_source(x.pair,'copper-ore').entity==a)
  local queries=x.world.queries+x.world.inventory_queries
  x.root.owned_resources[x.C.entity_key(a)]=x.foreign.station_unit
  assert(x.C.find_known_source(x.pair,'copper-ore').entity==b,
    'primary source with a different live owner hid a valid alternate')
  b.position={x=70,y=32}
  assert(x.C.find_known_source(x.pair,'copper-ore')==nil,
    'retained source moved outside its world area remained eligible')
  b.position={x=20,y=32}
  b.surface={valid=true,index=2,name='other-surface'}
  assert(x.C.find_known_source(x.pair,'copper-ore')==nil,
    'retained source moved to another surface remained eligible')
  b.surface=x.pair.station.surface
  local found=x.C.find_known_source(x.pair,'copper-ore')
  assert(found.entity==b and found.station_distance_sq==144,
    'source lookup reused a stale saved distance')
  b.valid=false
  assert(x.C.find_known_source(x.pair,'copper-ore')==nil,
    'invalid alternate or foreign-owned primary remained eligible')
  assert(x.world.queries+x.world.inventory_queries==queries,
    'live resource validation rediscovered the physical world')
  print('[continuation-independent] PASS live owner/domain/alternate/distance checks')
end

-- Obsolete domain snapshots become current-domain incomplete placeholders.
-- Repeated readers neither scan synchronously nor dirty a valid replacement.
do
  for _,change in ipairs({
    function(p)p.station.position={x=1000,y=1000}end,
    function(p)p.station.surface={valid=true,index=2,name='other'}end,
    function(p)p.station.force={valid=true,index=2,name='other'}end,
    function(p)p.radius=12 end,
  })do
    local x=fixture();local before=x.C.get_for_pair(x.pair)
    local queries=x.world.queries+x.world.inventory_queries
    change(x.pair)
    local placeholder=x.C.get_for_pair(x.pair)
    assert(placeholder and placeholder~=before and placeholder.pending_snapshot_1498
      and placeholder.scan_incomplete_1478 and not placeholder.resources['iron-ore'],
      'changed station domain exposed an obsolete snapshot')
    for _=1,50 do assert(x.C.get_for_pair(x.pair)==placeholder)end
    assert(x.root.owned_resources['u:1']==60000 and x.root.next_scan[60000]==0,
      'changed-domain reader lost old retirement claims or did not request bounded work')
    assert(x.world.queries+x.world.inventory_queries==queries,
      'cold/domain-changed readers performed synchronous discovery')
  end
  local x=fixture();x.pair.station.position={x=33,y=32}
  local placeholder=x.C.get_for_pair(x.pair);local job=x.start()
  local due=x.root.next_scan[60000]
  for _=1,50 do assert(x.C.get_for_pair(x.pair)==placeholder)end
  assert(x.root.next_scan[60000]==due and x.job()==job,
    'repeated pending readers dirtied or restarted the current-domain replacement')
  x.until_(function()return x.C.get_for_pair(x.pair)~=placeholder end,'changed-domain replacement')
  assert(not x.C.get_for_pair(x.pair).dirty_0634,
    'ordinary pending readers prevented clean publication')
  print('[continuation-independent] PASS changed-domain placeholders and passive readers')
end

-- Unexpected classification errors stay visible and use the existing sliced
-- cancellation path; a consumed-but-unapplied native batch cannot publish.
-- Expected engine-query failure remains an explicitly incomplete survey.
do
  local x=fixture()
  local staged=x.resource(98001,1,1)
  local bad=x.resource(98002,2,2)
  bad.type=nil;bad.fixture_type='resource'
  setmetatable(bad,{__index=function(_,key)
    if key=='type' then error('classification exploded')end
  end})
  x.world.entries={staged,bad}
  local ok,reason=pcall(x.start)
  assert(not ok and tostring(reason):find('classification exploded',1,true)
    and x.root.stats.continuation_errors_1498==1,
    'classification failure was concealed')
  local failed=x.job()
  assert(failed and failed.cancelled and x.C.get_for_pair(x.pair)==x.initial,
    'classification error left a partial batch eligible for publication')
  x.until_(function()return x.job()~=failed end,'bounded failed-job cancellation')
  assert(x.root.owned_resources['u:98001']==nil and x.root.owned_resources['u:1']==60000
    and x.C.get_for_pair(x.pair)==x.initial,
    'failed survey leaked its new claim or discarded the published snapshot')
  x.world.query_failure=true
  x.start()
  x.until_(function()return x.C.get_for_pair(x.pair)~=x.initial end,'failed native query')
  local incomplete=x.C.get_for_pair(x.pair)
  assert(incomplete.scan_incomplete_1478 and incomplete.scan_reason_1478=='surface-query-failed'
    and x.root.owned_resources['u:1']==60000,
    'native query failure was certified complete or retired an unproven old claim')
  print('[continuation-independent] PASS visible classification error and native query failure')
end

-- Coverage caps must remain explicit and keep old ownership until a complete
-- traversal can prove absence. Removal must discard a pending publication.
do
  local x=fixture();local absent=x.world.entries[196]
  absent.position={x=1000,y=1000}
  x.C.max_dense_scan_entities_1478=16
  x.start()
  x.until_(function()return x.C.get_for_pair(x.pair)~=x.initial end,'capped survey')
  local partial=x.C.get_for_pair(x.pair)
  assert(partial.scan_incomplete_1478 and partial.scan_reason_1478=='entity-budget'
    and x.root.owned_resources['u:196']==60000,
    'capped traversal concealed incomplete coverage or retired an unproven claim')
  x.C.max_dense_scan_entities_1478=3072
  x.start()
  x.until_(function()return x.C.get_for_pair(x.pair)~=partial end,'complete cap follow-up')
  assert(not x.C.get_for_pair(x.pair).scan_incomplete_1478
    and x.root.owned_resources['u:196']==nil,
    'complete follow-up failed to retire an absent capped-survey source')
  local job=x.start()
  x.pair.station.valid=false
  x.C.prune_invalid()
  assert(not x.root.scan_jobs_1498[60000] and not x.root.stations[60000]
    and x.root.owned_resources['u:1']==nil and x.C.get_for_pair(x.pair)==nil,
    'removed station retained pending work, ownership or a public catalog')
  print('[continuation-independent] PASS coverage caps and removed pending station')
end
print('[continuation-independent] ALL PASS')
