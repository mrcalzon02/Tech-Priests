-- 1247: already manufactured vanilla laboratories must enter the same
-- physical 0338 construction path as other stocked standard equipment.
-- Only Factorio's *explicit* first-lab craft-item technology trigger requires
-- manufacturing an additional real lab; existing stock does not satisfy it.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=12300}
defines={inventory={chest=1}}
storage={tech_priests={pairs_by_station={}}}
local force={valid=true,index=1,name="player",recipes={},technologies={}}
local surface={valid=true,index=1,name="nauvis"}
local function entity(name,kind,id,x)
 return {valid=true,unit_number=id,name=name,type=kind,
   position={x=x,y=0},force=force,surface=surface}
end
local entities={
 entity("stone-furnace","furnace",20,4),
 entity("burner-mining-drill","mining-drill",21,6),
 entity("assembling-machine-1","assembling-machine",22,8),
 entity("wooden-chest","container",23,10),
}
surface.find_entities_filtered=function(options)
 if type(options.type)=="table" then return entities end
 return {}
end
local station=entity("planetary-magos-cogitator-station","container",5,0)
local priest=entity("tech-priest","unit",6,1)
station.get_inventory=function()
 return {valid=true,get_item_count=function()return 0 end}
end
local pair={station=station,priest=priest,station_unit=5,
 radius=24,mode="idle"}
storage.tech_priests.pairs_by_station[5]=pair
local stock={lab=12,["electronic-circuit"]=10,
 ["iron-plate"]=100,["copper-plate"]=100}
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(p,item)
  assert(p==pair)
  return stock[item] or 0
 end,
}
prototypes={item={
 lab={place_result={name="lab"}},
 ["electronic-circuit"]={},
 ["automation-science-pack"]={},
 ["iron-plate"]={},
 ["copper-plate"]={},
}}
_G.TechPriestsMasterInfrastructurePlan0644={
 build_plan=function()
  return {stage="research-readiness",
    target={preferred_item="lab",stage="research-readiness"}}
 end,
}
local Governor=require("scripts.core.infrastructure_first_governor_0640")
local did,why=Governor.service_pair(pair,"stocked-standard-vanilla-lab")
assert(not did and why=="prestocked-machine-construction-requested"
 and pair.construction_requested_item=="lab"
 and stock.lab==12
 and pair.emergency_craft==nil
 and pair.construction_task_0338==nil
 and pair.construction_custody_0338==nil,
 "a dozen stocked labs were ignored or converted to synthetic research")
-- The original source can still hand the one actual laboratory to 0338.
assert(pair.station.force==force and pair.priest.valid and stock.lab==12,
 "lab request bypassed physical building or damaged rank custody")
-- Now manufacture ONE genuine lab solely for the unresearched vanilla
-- craft-item trigger. The 12 stocked labs MUST NOT count as the triggering
-- craft, and this branch may not replace an existing lab in inventory.
pair.construction_requested_item=nil
pair.local_infrastructure_gate_0640=nil
pair.mode="idle"
force.technologies["automation-science-pack"]={
 valid=true,enabled=true,researched=false}
force.recipes["automation-science-pack"]={enabled=false,
 products={{name="automation-science-pack"}}}
force.recipes.lab={enabled=true,
 products={{name="lab",type="item"}},
 ingredients={{name="electronic-circuit",amount=1}}}
_G.tech_priests_get_recipe_ingredients_for_item_0185=function(name)
 if name=="lab" then return {{name="electronic-circuit",count=1}} end
 return nil
end
local did2,why2=Governor.service_pair(pair,"real-first-lab-craft-trigger")
assert(why2~="prestocked-machine-construction-requested"
 and pair.construction_requested_item==nil and stock.lab==12,
 "existing lab stock falsely satisfied the craft-item research trigger")
assert(pair.infrastructure_recipe_request_0647~=nil
 or pair.emergency_craft~=nil
 or pair.local_infrastructure_gate_0640~=nil,
 "native craft-item trigger did not schedule a real recipe obligation")
print("[stocked-vanilla-lab-priority-1247] PASS stocked lab physical installation, real first-lab recipe trigger, zero synthetic items")
