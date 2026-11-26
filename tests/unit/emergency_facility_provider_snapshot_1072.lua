-- 1072: the 0643 shortage snapshot consumes the retained identity owner,
-- while rereading native-shaped physical inventories on every assessment.
-- No logistic item credit or network force/surface shortcut is permitted.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=107200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,assembling_machine_input=2,car_trunk=3,fuel=4,
  chest_alias=1}}
local chest_slot=defines.inventory.chest
local inventory_accesses,unsupported_accesses=0,0
local network={valid=true}
local force={valid=true,index=1,name="player"}
local scans,provider_requests=0,0
local surface={index=1}
local provider_stock={["iron-plate"]=3,["copper-plate"]=2,
  ["iron-gear-wheel"]=1}
local function inventory(stock)
  return {valid=true,get_item_count=function(name)return stock[name] or 0 end}
end
local provider={valid=true,unit_number=91,type="logistic-container",
  logistic_network=network,force=force,surface=surface,position={x=16,y=0}}
provider.get_inventory=function(id)
  assert(type(id)=="number","LuaEntity.get_inventory is already bound")
  inventory_accesses=inventory_accesses+1
  if id==chest_slot then return inventory(provider_stock) end
  unsupported_accesses=unsupported_accesses+1
end
surface.find_entities_filtered=function(args)
  scans=scans+1
  assert(args.name=="entity-ghost","facility assessment repeated spatial inventory discovery")
  return {}
end
local far={valid=true,unit_number=92,type="logistic-container",
  logistic_network=network,force=force,surface=surface,position={x=1000,y=0},
  get_inventory=provider.get_inventory}
local foreign={valid=true,unit_number=93,type="logistic-container",
  logistic_network=network,force={index=2},surface=surface,position={x=16,y=0},
  get_inventory=provider.get_inventory}
_G.TechPriestsStationCatalog={inventory_candidates=function(pair,radius,types)
  assert(radius==36 and pair.station.surface==surface)
  if #types==1 and types[1]=="logistic-container" then
    provider_requests=provider_requests+1
    return {provider,far,foreign}
  end
  return {} -- no physical production machines in this fixture
end}
local base={["iron-plate"]=20,["copper-plate"]=12,
  ["iron-gear-wheel"]=8}
for _,id in ipairs({11,21}) do
  local station={valid=true,type="container",unit_number=id,force=force,surface=surface,
    position={x=id,y=0},logistic_network=network}
  station.get_inventory=function(slot)
    assert(type(slot)=="number","LuaEntity.get_inventory is already bound")
    inventory_accesses=inventory_accesses+1
    if slot==chest_slot then return inventory(base) end
    unsupported_accesses=unsupported_accesses+1
  end
  storage.tech_priests.pairs_by_station[id]={
    station=station,priest={valid=true,unit_number=id+1000}}
end
-- Borrow the event-maintained raw index instead of the synchronous catalog
-- view, which filters/copies an entire provider array in one call.
local cells={}
for x=-2,2 do for y=-2,2 do cells[x..":"..y]={known_tick=game.tick,entities={}} end end
cells["0:0"].entities={provider,far,foreign}
storage.tech_priests.efficiency_economy_0579={surfaces={["1"]={cells=cells,dirty={}}}}
local Queue=require("scripts.core.force_planning_queue")
local Bridge=require("scripts.core.emergency_facility_placement_bridge_0643")
local function assess(expect_iron,expect_copper,expect_gears,expect_requests,
    expect_accesses,expect_unsupported)
  local before,before_unsupported=inventory_accesses,unsupported_accesses
  for _,cell in pairs(cells) do cell.known_tick=game.tick end
  local target=(Bridge.root().stats.assessments or 0)+1
  Bridge.root().next_assessment_tick=0;Bridge.root().next_groups["1:1"]=0
  local reports=Bridge.assess()
  for _=1,5000 do
    game.tick=game.tick+1
    Queue.pulse({tick=game.tick},16)
    local job,status=Queue.peek(1,"shortage-assessment","surface:1")
    if (Bridge.root().stats.assessments or 0)>=target and status=="ready" then break end
  end
  local report=reports["1:1"]
  assert(report and report.station_count==2
    and report.available["iron-plate"]==expect_iron
    and report.available["copper-plate"]==expect_copper
    and report.available["iron-gear-wheel"]==expect_gears
    and next(report.deficits)==nil
    and scans==0 and provider_requests==0,
    "0643 duplicated physical stock, repeated per-item provider discovery, "
    .."or changed shortage accounting")
  assert(inventory_accesses-before==expect_accesses
    and unsupported_accesses-before_unsupported==(expect_unsupported or 0),
    "0643 probed unrelated inventory kinds for a known container or changed compatibility access")
end
assess(43,26,17,2,9)
-- Change physical stock before another broker-owned assessment:
-- identities may be retained, but quantities must be recounted for that cycle.
provider_stock["iron-plate"]=0
provider_stock["copper-plate"]=0
provider_stock["iron-gear-wheel"]=0
assess(40,24,16,4,9)
-- A second station may report a different logistic network; the same
-- provider returned by the retained identity owner must be credited at most once
-- and only to its real network owner.
local other={valid=true}
storage.tech_priests.pairs_by_station[21].station.logistic_network=other
provider_stock["iron-plate"]=7
provider_stock["copper-plate"]=4
provider_stock["iron-gear-wheel"]=2
game.tick=game.tick+Bridge.interval
assess(47,28,18,6,9)
-- A second, different network could see the same world-space container
-- from the identity list, but must never count it as that network's property.
-- Disconnect BOTH stations while the physical provider stays full:
-- obsolete network snapshots must not credit its material.
storage.tech_priests.pairs_by_station[11].station.logistic_network=nil
storage.tech_priests.pairs_by_station[21].station.logistic_network=nil
game.tick=game.tick+Bridge.interval
assess(40,24,16,6,6)
-- Other native chest-family types also own exactly one supported slot.
for _,kind in ipairs({"infinity-container","linked-container"}) do
  for _,pair in pairs(storage.tech_priests.pairs_by_station) do
    pair.station.type=kind
  end
  assess(40,24,16,6,6)
end
-- Unknown/other types retain the old inventory-ID search, including alias
-- deduplication. Missing native chest metadata must retain that path too.
storage.tech_priests.pairs_by_station[11].station.type="assembling-machine"
storage.tech_priests.pairs_by_station[21].station.type=nil
assess(40,24,16,6,24,18)
for _,pair in pairs(storage.tech_priests.pairs_by_station) do
  pair.station.type="container"
end
defines.inventory.chest=nil
assess(40,24,16,6,24,18)
print("[facility-provider-snapshot-1072] PASS broker-owned physical recount; zero spatial inventory discovery; typed accesses, range, force, network, disconnection and compatibility fallback")
