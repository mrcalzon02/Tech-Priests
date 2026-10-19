-- Lua 5.2: ongoing emergency miners must run even when the single
-- dispatcher suppresses obsolete independent facility planning pulses.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,furnace_source=2,fuel=3}}
prototypes={recipe={
  ["tech-priests-emergency-mine-iron-ore"]={},
  ["tech-priests-emergency-mine-coal"]={}
}}
local force={index=1,name="player"}
local surface={index=1,name="nauvis"}
local recipe_name
local recipe_mutations=0
local miner={valid=true,name="tech-priests-emergency-miner",
  type="assembling-machine",unit_number=55,
  position={x=4,y=1},force=force,surface=surface}
miner.get_recipe=function()
  return recipe_name and {name=recipe_name} or nil
end
miner.set_recipe=function(recipe)
  recipe_name=recipe;recipe_mutations=recipe_mutations+1;return true
end
local entities={miner}
surface.find_entities_filtered=function()return entities end
local station={valid=true,name="junior-cogitator-station",
  unit_number=22,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=23,position={x=2,y=0}}
local pair={station=station,priest=priest,station_unit=22,radius=36}
storage.tech_priests.pairs_by_station[22]=pair
local Facility=require("scripts.core.emergency_facility_doctrine")
local Production=require("scripts.core.emergency_production_executor_0514")
local function check(ok,detail)
  if not ok then error("emergency-miner-continuity regression: "..detail,2) end
end
check(Production.install(),"single production owner did not install")
local worked=Facility.service_all("broker-periodic")
check(worked==1 and recipe_name=="tech-priests-emergency-mine-iron-ore",
  "broker was prevented from configuring a placed idle miner")
check(recipe_mutations==1,"first maintenance did not set exactly one physical recipe")
check(not pair.emergency_craft and not pair.construction_request,
  "ongoing miner maintenance created competing manufacturing/construction orders")

game.tick=1350
local again=Facility.service_all("broker-periodic")
check(again==0 and recipe_mutations==1,
  "already-running emergency miner recipe was reset")
recipe_name="tech-priests-emergency-mine-coal"
game.tick=1500
Facility.service_all("broker-periodic")
check(recipe_name=="tech-priests-emergency-mine-coal" and recipe_mutations==1,
  "maintenance overwrote a selected resource recipe")

entities={}
game.tick=1650
local absent=Facility.service_all("broker-periodic")
check(absent==0 and not pair.emergency_craft and not pair.construction_request,
  "maintenance attempted independent construction without an existing miner")
local independent,why=Facility.service_pair(pair,"broker-periodic")
check(not independent and why=="suppressed-by-0514",
  "suppression of independent strategic facility planning was lost")

-- With real iron already inside an unfueled furnace, the first recipe for an
-- unconfigured emergency miner must earn coal instead of more stranded ore.
local function stored(items)
  return {valid=true,get_item_count=function(name)return items[name] or 0 end}
end
local chest=stored({})
local ore=stored({["iron-ore"]=4})
local fuel=stored({})
station.get_inventory=function(id)
  if id==defines.inventory.chest then return chest end
end
local furnace={valid=true,name="stone-furnace",type="furnace",
  unit_number=57,position={x=2,y=0},force=force,surface=surface}
furnace.get_inventory=function(id)
  if id==defines.inventory.furnace_source then return ore end
  if id==defines.inventory.fuel then return fuel end
end
entities={miner,furnace}
recipe_name=nil
game.tick=1800
local coal_started=Facility.service_all("broker-periodic")
check(coal_started==1 and recipe_name=="tech-priests-emergency-mine-coal",
  "real buffered iron and missing furnace fuel failed to select slow coal production")
local coal_count=recipe_mutations
game.tick=1950
Facility.service_all("broker-periodic")
check(recipe_name=="tech-priests-emergency-mine-coal" and recipe_mutations==coal_count,
  "autonomous maintenance changed an active selected coal rite")
-- Four-rank operations must not choose coal on every miner and starve
-- actual mined iron. Two shared-force priests with ore and no coal should
-- configure one new miner for each useful resource without fake inventory.
local other_recipe,other_mutations=nil,0
local other_miner={valid=true,name="tech-priests-emergency-miner",
  type="assembling-machine",unit_number=75,
  position={x=68,y=1},force=force,surface=surface}
other_miner.get_recipe=function()
  return other_recipe and {name=other_recipe} or nil
end
other_miner.set_recipe=function(name)
  other_recipe=name;other_mutations=other_mutations+1;return true
end
local other_furnace={valid=true,name="stone-furnace",type="furnace",
  unit_number=76,position={x=66,y=0},force=force,surface=surface}
other_furnace.get_inventory=furnace.get_inventory
local other_station={valid=true,name="intermediate-cogitator-station",
  unit_number=74,position={x=64,y=0},force=force,surface=surface}
other_station.get_inventory=station.get_inventory
local other_pair={station=other_station,
  priest={valid=true,unit_number=77,position={x=65,y=0}},
  station_unit=74,radius=36}
storage.tech_priests.pairs_by_station[74]=other_pair
entities={miner,furnace,other_miner,other_furnace}
recipe_name=nil
game.tick=2100
Facility.service_all("broker-periodic")
local iron_rite="tech-priests-emergency-mine-iron-ore"
local coal_rite="tech-priests-emergency-mine-coal"
check((recipe_name==iron_rite and other_recipe==coal_rite)
    or (recipe_name==coal_rite and other_recipe==iron_rite),
  "shared workshops selected only one mineral and abandoned ore or fuel income")
local last_other=other_mutations
local last_first=recipe_mutations
game.tick=2250
Facility.service_all("broker-periodic")
check(last_other==other_mutations and last_first==recipe_mutations,
  "cooperative bootstrap overwrote an existing mining rite")
print("[emergency-miner-continuity-regression] PASS scenarios=8")
