-- 1072: the 0643 shortage snapshot may reuse provider identity discovery
-- during ONE pulse, but must reread real inventory counts on later pulses.
-- No logistic item credit or network force/surface shortcut is permitted.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=107200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,assembling_machine_input=2}}
local network={valid=true}
local force={index=1,name="player"}
local scans=0
local provider_stock={["iron-plate"]=3,["copper-plate"]=2,
  ["iron-gear-wheel"]=1}
local function inventory(stock)
  return {valid=true,get_item_count=function(name)return stock[name] or 0 end}
end
local provider={valid=true,unit_number=91,type="logistic-container",
  logistic_network=network}
provider.get_inventory=function(_,id)
  if id==defines.inventory.chest then return inventory(provider_stock) end
end
local surface={index=1}
surface.find_entities_filtered=function(args)
  if args.type=="logistic-container" then
    scans=scans+1
    return {provider}
  end
  assert(type(args.type)=="table","unexpected facility scan type")
  return {} -- fixture has no physical production machines
end
local base={["iron-plate"]=20,["copper-plate"]=12,
  ["iron-gear-wheel"]=8}
for _,id in ipairs({11,21}) do
  local station={valid=true,unit_number=id,force=force,surface=surface,
    position={x=id,y=0},logistic_network=network}
  station.get_inventory=function(_,slot)
    if slot==defines.inventory.chest then return inventory(base) end
  end
  storage.tech_priests.pairs_by_station[id]={
    station=station,priest={valid=true,unit_number=id+1000}}
end
local Bridge=require("scripts.core.emergency_facility_placement_bridge_0643")
local function assess(expect_iron,expect_copper,expect_gears,expect_scans)
  local reports=Bridge.assess()
  local report=reports["1:1"]
  assert(report and report.station_count==2
    and report.available["iron-plate"]==expect_iron
    and report.available["copper-plate"]==expect_copper
    and report.available["iron-gear-wheel"]==expect_gears
    and next(report.deficits)==nil
    and scans==expect_scans,
    "0643 duplicated physical stock, repeated per-item provider discovery, "
    .."or changed shortage accounting")
end
assess(43,26,17,1)
-- Change physical stock between broker pulses: container identities may
-- be reused within a pulse, but item quantities must never be cached.
provider_stock["iron-plate"]=0
provider_stock["copper-plate"]=0
provider_stock["iron-gear-wheel"]=0
game.tick=game.tick+Bridge.interval
assess(40,24,16,2)
-- A second station may report a different logistic network; the same
-- provider returned by a mock surface scan must be credited at most once
-- and only to its real network owner.
local other={valid=true}
storage.tech_priests.pairs_by_station[21].station.logistic_network=other
provider_stock["iron-plate"]=7
provider_stock["copper-plate"]=4
provider_stock["iron-gear-wheel"]=2
game.tick=game.tick+Bridge.interval
assess(47,28,18,4)
-- A second, different network could see the same world-space container
-- from the area scan, but must never count it as that network's property.
-- Disconnect BOTH stations while the physical provider stays full:
-- obsolete network snapshots must not credit its material.
storage.tech_priests.pairs_by_station[11].station.logistic_network=nil
storage.tech_priests.pairs_by_station[21].station.logistic_network=nil
game.tick=game.tick+Bridge.interval
assess(40,24,16,4)
print("[facility-provider-snapshot-1072] PASS single per-network discovery, live counts, owner and disconnection")
