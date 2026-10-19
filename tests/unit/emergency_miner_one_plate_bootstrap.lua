-- Lua 5.2: first emergency miner requires its actual recipe's one iron
-- plate, not the unrelated four-plate general reserve target.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,assembling_machine_input=2,
  assembling_machine_output=3,furnace_result=4,furnace_source=5}}
prototypes={item={
  ["iron-plate"]={},["tech-priests-emergency-miner"]={},["stone"]={}
}}
local stock={["iron-plate"]=0}
local inv={valid=true,get_item_count=function(item)return stock[item] or 0 end}
local force={index=1}
local surface={index=1}
local station={valid=true,unit_number=10,position={x=0,y=0},force=force,
  surface=surface,get_inventory=function(id)if id==1 then return inv end end}
local priest={valid=true,unit_number=11,position={x=0,y=0}}
local furnace={valid=true,type="furnace",name="stone-furnace",
  unit_number=20,position={x=2,y=1},force=force,surface=surface}
local ore={valid=true,type="resource",name="iron-ore",
  position={x=4,y=0},amount=100}
surface.find_entities_filtered=function(opts)
  if opts.type=="resource" then return {ore} end
  if type(opts.type)=="table" then return {furnace} end
  return {furnace,ore}
end
local pair={station=station,priest=priest,station_unit=10,
  mode="idle",radius=24}
storage.tech_priests.pairs_by_station[10]=pair
_G.TechPriestsEmergencyProductionExecutor0514={service_pair=function()return true end}
local Governor=require("scripts.core.infrastructure_first_governor_0640")
local function check(ok,why)
  if not ok then error("one-plate-bootstrap regression: "..why,2)end
end
check(Governor.status_for_pair(pair):find("needed=iron%-plate"),
  "empty station failed to request the first smelted iron plate")
local assigned=Governor.service_pair(pair,"first-plate")
check(assigned==true and pair.emergency_craft
  and pair.emergency_craft.output_item=="iron-plate"
  and pair.emergency_craft.count==1
  and pair.emergency_craft.facility_only_0647==true,
  "primitive smelting requested more plates than the miner recipe needs")
stock["iron-plate"]=1
pair.emergency_craft=nil
pair.local_infrastructure_gate_0640=nil
check(Governor.status_for_pair(pair):find("needed=tech%-priests%-emergency%-miner"),
  "one real iron plate did not unlock emergency-miner construction objective")
check(stock["iron-plate"]==1,
  "planning modified physical station resources")
print("[one-plate-bootstrap-regression] PASS scenarios=3")
