-- Actual 0643 admission + shared-broker callers. No native FPS claim.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local function check(v,msg) assert(v,"shortage-continuation: "..msg) end
local function fixture(count,options)
  options=options or {}
  for _,name in ipairs({"force_planning_queue","planning_metadata_1507","emergency_facility_placement_bridge_0643"}) do package.loaded["scripts.core."..name]=nil end
  game={tick=1000};storage={tech_priests={pairs_by_station={}}};defines={inventory={chest=1,fuel=2,alias=1}}
  local calls={inventory=0,queries=0,construction=0,services={},source_visits=0}
  _G.TechPriestsRuntimeTickBroker0600={base_interval=1,register_service=function(s) calls.services[s.name]=s;return s end}
  _G.TechPriestsRuntimeEventRegistry=nil
  local force={valid=true,index=1,name="player",object_name="LuaForce",recipes={}}
  local network={valid=true,object_name="LuaLogisticNetwork"}
  local surface={valid=true,index=1,object_name="LuaSurface"}
  local world={};local stocks={};local native={}
  local function entity(id,kind,x,stock)
    local e={valid=true,object_name="LuaEntity",unit_number=id,type=kind,name=kind,position={x=x,y=0},force=force,surface=surface}
    native[e]=true
    if stock then
      stocks[id]=stock
      e.get_inventory=function(slot)
        check(type(slot)=="number","unbound inventory API")
        if slot~=1 then return nil end
        return {valid=true,object_name="LuaInventory",get_item_count=function(item) calls.inventory=calls.inventory+1;return stock[item] or 0 end}
      end
    end
    return e
  end
  local initial=options.empty and {} or {["iron-plate"]=20,["copper-plate"]=12,["iron-gear-wheel"]=8}
  for n=1,count do
    local stock={};for k,v in pairs(initial) do stock[k]=v end
    if options.materials then stock["stone-furnace"]=1;stock["assembling-machine-1"]=1 end
    local station=entity(n,"container",n%10,stock);station.logistic_network=network
    storage.tech_priests.pairs_by_station[n]={station=station,priest=entity(n+10000,"unit",n%10),radius=36}
  end
  local provider=entity(9001,"logistic-container",16,options.provider_stock or {["iron-plate"]=3,["copper-plate"]=2,["iron-gear-wheel"]=1})
  provider.logistic_network=network;world[#world+1]=provider
  -- Rejected entries are still charged. None may count as this group's stock.
  local foreign=entity(9002,"logistic-container",18,{["iron-plate"]=999});foreign.force={valid=true,index=2,name="other"};foreign.logistic_network=network;world[#world+1]=foreign
  for i=1,options.noise or 32 do world[#world+1]=entity(100000+i,"tree",i%30) end
  if options.capacity then
    local furnace=entity(8001,"furnace",8);world[#world+1]=furnace
    local assembler=entity(8002,"assembling-machine",9);world[#world+1]=assembler
  end
  surface.find_entities_filtered=function(query)
    calls.queries=calls.queries+1
    check(query.limit==16 and query.area,"unbounded world query")
    local types={};for _,kind in ipairs(query.type) do types[kind]=true end
    local out={};local a,b=query.area[1],query.area[2]
    for _,e in ipairs(world) do
      if e.valid and types[e.type] and e.force==query.force and e.position.x>=a[1] and e.position.x<b[1] and e.position.y>=a[2] and e.position.y<b[2] then
        out[#out+1]=e;if #out>=query.limit then break end
      end
    end
    return out
  end
  if not options.cold then
    local cells={}
    for x=-2,2 do for y=-2,2 do cells[x..":"..y]={known_tick=game.tick,entities={}} end end
    for _,e in ipairs(world) do local k=math.floor(e.position.x/32)..":"..math.floor(e.position.y/32);cells[k].entities[e.unit_number]=e end
    storage.tech_priests.efficiency_economy_0579={surfaces={["1"]={cells=cells,dirty={}}}}
  end
  prototypes={item={},entity={}}
  for i=1,40 do prototypes.item["unrelated-"..i]={name="unrelated-"..i};force.recipes["unrelated-"..i]={enabled=true,products={{name="unrelated-"..i}}} end
  for _,name in ipairs({"stone-furnace","assembling-machine-1"}) do
    prototypes.item[name]={name=name,place_result={name=name}}
    prototypes.entity[name]={name=name}
    force.recipes[name]={enabled=true,name=name,products={{name=name}},object_name="LuaRecipe"}
  end
  _G.TechPriestsConstructionBootstrapGhostPlanner0645={service_pair=function(pair,reason,name)
    calls.construction=calls.construction+1;calls.last_pair=pair;calls.last_name=name
    check(reason:find("emergency-network:",1,true)==1,"lost canonical route")
    return false,"placement-pending"
  end}
  local Q=require("scripts.core.force_planning_queue")
  local B=require("scripts.core.emergency_facility_placement_bridge_0643");B.install()
  local function pulse(budget)
    local before=calls.inventory;game.tick=game.tick+1
    local r=Q.pulse({tick=game.tick},budget or 1)
    check(r.processed<=(budget or 1),"broker offered work exceeded")
    check(calls.inventory-before<=2*(budget or 1),"inventory scan was hidden inside one work unit")
    return r
  end
  local function group() return Q.peek(1,"shortage-assessment","surface:1") end
  local function drain(limit)
    for i=1,limit or 30000 do
      pulse()
      local j,status=group()
      if j and status=="ready" then return j.result,i end
    end
    local j=group();error("continuation did not finish; phase="..tostring(j and j.state.phase))
  end
  local fixture={Q=Q,B=B,calls=calls,force=force,network=network,world=world,provider=provider,stocks=stocks,
    surface=surface,pulse=pulse,drain=drain,group=group,native=native}
  function fixture.reload()
    for _,name in ipairs({"force_planning_queue","planning_metadata_1507","emergency_facility_placement_bridge_0643"}) do package.loaded["scripts.core."..name]=nil end
    Q=require("scripts.core.force_planning_queue");B=require("scripts.core.emergency_facility_placement_bridge_0643")
    fixture.Q,fixture.B=Q,B;B.install()
  end
  return fixture
end
local function check_saved(value,seen)
  if type(value)~="table" or value.object_name then check(type(value)~="function" and type(value)~="thread","unsaveable continuation value");return end
  seen=seen or {};if seen[value] then return end;seen[value]=true
  for k,v in pairs(value) do check_saved(k,seen);check_saved(v,seen) end
end
local function copy_saved(value,seen)
  if type(value)~="table" or value.object_name then return value end
  seen=seen or {};if seen[value] then return seen[value] end
  local out={};seen[value]=out;for k,v in pairs(value) do out[copy_saved(k,seen)]=copy_saved(v,seen) end
  return out
end
-- The legacy public caller is now admission/readback, including repeated calls.
do
  local f=fixture(2)
  for _=1,100 do local reports=f.B.assess();check(next(reports)==nil,"partial report published") end
  check(f.calls.inventory==0 and f.calls.queries==0,"caller advanced work without broker")
  local done,steps=f.drain();check(done.status=="complete","indexed group failed")
  local r=f.B.root().assessments["1:1"]
  check(r.complete and r.station_count==2 and r.available["iron-plate"]==43 and r.available["copper-plate"]==26 and r.available["iron-gear-wheel"]==17,"physical source accounting changed")
  check(next(r.deficits)==nil and f.calls.construction==0,"false shortage/action")
  check(f.calls.queries==0 and steps>100,"retained index ignored or entire group processed in a unit")
end
-- A large single group resumes across ticks and module reload. No functions,
-- iterators or coroutine stacks are needed in its saved continuation.
do
  local f=fixture(100,{noise=180,capacity=true})
  f.B.assess()
  for _=1,180 do f.pulse() end
  check_saved(storage)
  storage=copy_saved(storage)
  f.reload()
  local done,steps=f.drain(80000)
  check(done.status=="complete" and steps>1000,"single group was not sliced")
  check(f.B.root().assessments["1:1"].station_count==100,"reload lost group membership")
  check(f.calls.construction==0,"full factory built spurious machines")
end
-- Backpressure and no-action work cannot discard other forces or grow a
-- deferred list forever. A blocked first group does not stall the second.
do
  local f=fixture(2)
  f.Q.max_per_force=1
  f.Q.register("stalled",function()return {waiting=true}end)
  f.Q.submit(1,"stalled","hold",{})
  local second={valid=true,index=2,name="second",object_name="LuaForce",recipes=f.force.recipes}
  local pair=storage.tech_priests.pairs_by_station[2];pair.station.force=second
  f.B.assess()
  for _=1,50 do f.pulse() end
  local other=f.Q.peek(2,"shortage-assessment","surface:1")
  check(other~=nil,"full force starved other force")
  local roster=f.Q.peek(0,"shortage-roster","all")
  check(#roster.state.order==2,"queue-full retries grew deferred list")
  f.Q.forget(1,"stalled","hold");f.Q.max_per_force=64
  for _=1,100 do f.pulse() end
  check(f.group()~=nil,"full group was forgotten after capacity returned")
end
-- Current shortage/material witnesses are checked after the slow work. A
-- filled station or spent kit while pending never publishes a stale claim.
for _,change in ipairs({"shortage","material"}) do
  local f=fixture(1,{empty=true,materials=true,provider_stock={}});f.B.assess()
  local reached=false
  for _=1,30000 do
    f.pulse();local j=f.group()
    if j and j.state.phase=="dispatch" then
      local item=j.state.need.item
      if change=="shortage" then f.stocks[1][item]=1000 else f.stocks[1][j.state.meta.items[j.state.need.stage]]=0 end
      reached=true;break
    end
  end
  check(reached,"fixture never reached staged final decision")
  f.pulse()
  check(f.calls.construction==0 and next(f.B.root().reservations)==nil,"changed stock published or acted on stale reservation")
end
-- Stock arriving in a different connected provider during the slow world
-- survey is included by the per-need live pass and cancels new reservations.
do
  local f=fixture(1,{empty=true,materials=true,provider_stock={}});f.B.assess()
  local reached=false
  for _=1,30000 do
    f.pulse();local j=f.group()
    if j and j.state.phase=="capacity-validation" then reached=true;break end
  end
  check(reached,"provider-change fixture never finished initial stock observations")
  for _,item in ipairs({"iron-plate","copper-plate","iron-gear-wheel"}) do f.stocks[9001][item]=1000 end
  local done=f.drain()
  check(done.status=="complete" and f.calls.construction==0 and next(f.B.root().reservations)==nil,
    "new connected stock produced a stale shortage reservation")
end
-- Terrain or construction changes while pending reject a previously complete
-- cell snapshot; they cannot turn partial capacity into absent capacity.
do
  local f=fixture(2,{empty=true,materials=true,provider_stock={}});f.B.assess()
  for _=1,30000 do
    f.pulse();local j=f.group()
    if j and j.state.phase=="stock" then break end
  end
  local index=storage.tech_priests.efficiency_economy_0579.surfaces["1"]
  index.dirty["0:0"]={tick=game.tick,reason="new-furnace"}
  local done=f.drain()
  check(done.status=="stale" and f.calls.construction==0 and next(f.B.root().reservations)==nil,"world change bypassed complete validation")
end
-- A new machine after all cell validation but immediately before dispatch
-- invalidates only the one pending force/surface group in O(1) event work.
do
  local f=fixture(1,{empty=true,materials=true,provider_stock={}});f.B.assess()
  local reached=false
  for _=1,30000 do
    f.pulse();local j=f.group()
    if j and j.state.phase=="dispatch" then reached=true;break end
  end
  check(reached,"late terrain fixture did not reach dispatch")
  local e={valid=true,type="furnace",name="stone-furnace",unit_number=70001,
    force=f.force,surface=f.surface,position={x=3,y=0}}
  check(f.B.handle_entity_change({entity=e}),"late local edit did not reach pending group")
  f.pulse();local j,status=f.group()
  check(status=="ready" and j.result.status=="stale" and f.calls.construction==0,
    "late new capacity slipped between final validation and action")
end
-- Removing the discovery cursor is safe and still allows another station to
-- be assessed; a partial roster must not be claimed complete after deletion.
do
  local f=fixture(4);f.B.assess();f.pulse()
  local j=f.Q.peek(0,"shortage-roster","all")
  if j.state.cursor then storage.tech_priests.pairs_by_station[j.state.cursor]=nil end
  local done=f.drain()
  check(done.status=="complete" or done.status=="stale","deleted roster cursor crashed continuation")
end
-- Cold discovery is capped at 16 results, and returned rows are visited over
-- separate broker steps. It remains honest if no retained membership exists.
do
  local f=fixture(1,{cold=true,capacity=true});f.B.assess()
  local done=f.drain()
  check(done.status=="complete" and f.calls.queries>0,"bounded cold discovery failed")
end
print("[shortage-continuation-1507] PASS actual admission/broker callers; single 100-station group; reload; queue backpressure/fairness; current stock/world changes; bounded cold discovery")
