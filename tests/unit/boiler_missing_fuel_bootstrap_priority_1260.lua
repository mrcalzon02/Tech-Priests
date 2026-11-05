-- 1260: A real cold boiler with no local fuel must request ordinary coal,
-- not advanced nuclear/rocket fuel. Stocked fuel selection stays physical.
-- Discovery is read-only; dispatcher ownership starts the only fuel request.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
defines={inventory={chest=1}}
local surface={valid=true,index=1}
local force={valid=true,index=1}
local stock={coal=0,wood=0,["nuclear-fuel"]=0}
local chest={
 valid=true,
 get_item_count=function(item)return stock[item]or 0 end,
 remove=function(spec)
  local n=math.min(tonumber(spec.count)or 0,stock[spec.name]or 0)
  stock[spec.name]=(stock[spec.name]or 0)-n
  return n
 end,
}
local station={
 valid=true,unit_number=10,name="planetary-magos-cogitator-station",
 position={x=0,y=0},surface=surface,force=force,
 get_inventory=function(slot)
  assert(slot==defines.inventory.chest)
  return chest
 end,
}
local priest={valid=true,unit_number=11,position={x=1,y=0},
 surface=surface,force=force}
local boiler={valid=true,unit_number=20,name="boiler",type="boiler",
 position={x=5,y=0},surface=surface,force=force}
local pair={station=station,priest=priest,radius=30}
storage={tech_priests={pairs_by_station={[10]=pair}}}
prototypes={item={
 coal={fuel_value=4000000},
 wood={fuel_value=2000000},
 ["nuclear-fuel"]={fuel_value=1210000000},
}}
local installed={}
local burner_fuel_inventory={
 valid=true,
 can_insert=function(item)
  return type(item)=="table" and prototypes.item[item.name]~=nil
 end,
 insert=function(spec)
  assert(spec.name=="nuclear-fuel" and spec.count==2,
   "physical fuel insertion did not preserve the exact removed stack")
  installed[spec.name]=(installed[spec.name]or 0)+spec.count
  return spec.count
 end,
}
local report={
 entity=boiler,entity_name=boiler.name,entity_unit=boiler.unit_number,
 state="fuel-service-eligible",fuel_inventory=burner_fuel_inventory,
 fuel_count=0,connected_item_automation=false,
}
_G.TechPriestsEnergyFamilyReadiness0705={
 scan_pair=function(p)
  assert(p==pair)
  p.energy_family_reports_0705={report}
  return {processed=1,acted=0}
 end,
 inspect_entity=function(p,entity)
  assert(p==pair and entity==boiler)
  return report
 end,
}
local services={}
_G.TechPriestsRuntimeTickBroker0600={
 register_service=function(spec)
  assert(type(spec.name)=="string"and type(spec.fn)=="function")
  services[spec.name]=spec
  return spec
 end,
}
local reservations={categories={},reservations={}}
_G.TechPriestsWorkReservations0601={
 categories=reservations.categories,
 root=function()return reservations end,
 claim=function(category,target,owner)
  assert(category=="energy-family-logistics"and target==boiler and owner==pair)
  return true,"claimed"
 end,
 release=function()return true end,
}
local Logistics=require("scripts.core.energy_family_logistics_0707")
assert(Logistics.install()==true,"canonical energy discovery broker not installed")
local discovery=assert(services.energy_family_discovery_0707)
local cold=discovery.fn(nil,1)
assert(cold.acted==1
 and pair.energy_family_candidate_0707.item=="coal",
 "cold boiler requested unavailable advanced nuclear fuel instead of coal")
local started=Logistics.service_pair(pair,"bootstrap-missing-fuel")
assert(started.waiting==1 and started.detail=="waiting-source"
 and pair.energy_family_logistics_0707.phase=="waiting-source"
 and pair.active_supply_request.item=="coal"
 and pair.active_supply_request.purpose=="energy-fuel"
 and pair.logistic_requested_item.item=="coal"
 and stock.coal==0 and stock["nuclear-fuel"]==0,
 "missing-fuel request did not preserve a counted, unfilled coal duty")
local aborted=Logistics.abort_pair(pair,"test-reselection")
assert(aborted==false and pair.active_supply_request==nil
 and pair.logistic_requested_item==nil
 and pair.energy_family_logistics_0707==nil,
 "unstarted request could not release its owned demand safely")
-- Real, currently stocked compatible nuclear fuel is a separate decision:
-- do not invent coal or discard physical inventory already available.
stock["nuclear-fuel"]=2
game.tick=game.tick+Logistics.discovery_interval+5
local stocked=discovery.fn(nil,1)
assert(stocked.acted==1
 and pair.energy_family_candidate_0707.item=="nuclear-fuel"
 and pair.energy_family_candidate_0707.source
 and stock["nuclear-fuel"]==2,
 "missing-fuel fallback incorrectly displaced an existing stocked fuel source")
-- 1261: selection alone is NOT delivery. The sole dispatcher executor must
-- issue a real move, wait for physical source proximity, remove counted stock,
-- persist custody while traveling, and insert the same count into the boiler.
local moves={}
_G.tech_priests_request_movement_0418=function(p,position,reason,options)
 assert(p==pair and position and type(reason)=="string"
  and options.owner=="energy-family-logistics-0707")
 moves[#moves+1]=reason
 return true
end
priest.position={x=20,y=0}
local dispatch=Logistics.service_pair(pair,"physical-stocked-fuel")
assert(dispatch.waiting==1
 and pair.energy_family_logistics_0707.phase=="move-to-source",
 "stocked boiler fuel was never handed to the canonical executor")
local distant=Logistics.service_pair(pair,"before-source-arrival")
assert(distant.waiting==1 and stock["nuclear-fuel"]==2
 and installed["nuclear-fuel"]==nil
 and pair.energy_family_custody_0707==nil,
 "fuel removed or delivered remotely before source arrival")
-- The test fixture now represents an arrival; the module never teleports.
priest.position={x=0,y=0}
local pickup=Logistics.service_pair(pair,"at-real-storage")
assert(pickup.acted==1 and stock["nuclear-fuel"]==0
 and pair.energy_family_custody_0707.item=="nuclear-fuel"
 and pair.energy_family_custody_0707.count==2
 and installed["nuclear-fuel"]==nil,
 "physical pickup did not debit source stock and retain exact custody")
local transit=Logistics.service_pair(pair,"before-boiler-arrival")
assert(transit.waiting==1 and installed["nuclear-fuel"]==nil
 and pair.energy_family_custody_0707.count==2,
 "fuel delivered remotely while still in transit")
priest.position={x=5,y=0}
local delivered=Logistics.service_pair(pair,"at-physical-boiler")
assert(delivered.acted==1
 and installed["nuclear-fuel"]==2 and stock["nuclear-fuel"]==0
 and pair.energy_family_logistics_0707==nil
 and pair.energy_family_custody_0707==nil
 and #moves>=3,
 "real boiler fuel receipt did not close exact physical custody")
-- If coal is unavailable as a prototype, ordinary wood is the next
-- compatible physical-acquisition request, never an invented coal item.
stock["nuclear-fuel"]=0
prototypes.item.coal=nil
pair.energy_family_candidate_0707=nil
game.tick=game.tick+Logistics.discovery_interval+5
local wood=discovery.fn(nil,1)
assert(wood.acted==1 and pair.energy_family_candidate_0707.item=="wood"
 and stock.wood==0,
 "unsupported coal prototype or advanced-fuel request bypassed wood fallback")
print("[boiler-missing-fuel-bootstrap-1260] PASS coal-first missing fuel request, real stocked selection, safe demand cleanup, wood fallback; no item creation")
