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
-- The dispatcher-owned facility pathway also starts new miners before
-- the periodic continuity pulse, so it must use the identical physical fuel
-- decision rather than unconditionally selecting iron.
recipe_name=nil
pair.emergency_craft={output_item="iron-plate",facility_only_0647=true}
game.tick=2020
local manual=Facility.service_pair(pair,"manual-facility-initial-recipe")
check(manual==true and recipe_name=="tech-priests-emergency-mine-coal",
  "dispatcher facility route bypassed real fuel-starvation recipe selection")
pair.emergency_craft=nil

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

-- Existing iron is stored in an assigned stone cache rather than the
-- Cogitator chest or furnace. A second unconfigured miner must see the
-- physically held ore and choose coal, not launch two iron-only miners.
ore=stored({})
local stone_stock=stored({["iron-ore"]=5})
local cache={valid=true,name="tech-priests-martian-stone-cache",type="container",
  unit_number=88,position={x=67,y=2},surface=surface,force=force}
cache.get_inventory=function(id)
  if id==defines.inventory.chest then return stone_stock end
end
local storage_scans=0
_G.TechPriestsStorageRoleAuthority0686={
  generic_storage_sources=function(p)
    storage_scans=storage_scans+1
    return {{inv=stone_stock,entity=cache,source="stone-cache"}}
  end
}
-- The first station maintains its real iron rite. The second station's
-- initial recipe must reflect cached ore and its empty physical fuel stock.
recipe_name="tech-priests-emergency-mine-iron-ore"
other_recipe=nil
entities={miner,furnace,other_miner,other_furnace,cache}
game.tick=2400
Facility.service_all("broker-periodic")
check(other_recipe=="tech-priests-emergency-mine-coal" and storage_scans>0,
  "cache-backed iron stock did not trigger real missing-coal extraction")
check(stone_stock.get_item_count("iron-ore")==5,
  "choosing a miner recipe consumed or fabricated cache stock")
-- A cache containing a little coal is not an ongoing coal source.
-- A fresh peer miner must balance the existing iron rite rather than making
-- all automatically configured miners iron-only until the furnaces go cold.
stone_stock=stored({["iron-ore"]=5,coal=4})
other_recipe=nil
game.tick=2600
local coal_before=stone_stock.get_item_count("coal")
Facility.service_all("broker-periodic")
check(recipe_name==iron_rite and other_recipe==coal_rite,
  "seed coal prevented a peer miner from establishing continuous coal production")
check(stone_stock.get_item_count("coal")==coal_before
    and stone_stock.get_item_count("iron-ore")==5,
  "initial automatic coal recipe consumed or fabricated raw resources")
local new_mutations=other_mutations
game.tick=2750
Facility.service_all("broker-periodic")
check(other_recipe==coal_rite and other_mutations==new_mutations,
  "existing automatically selected coal rite was reset without authorization")


-- A third real shared-force miner fills the missing copper source in the
-- electronics chain. Existing iron and coal miners must keep their selected
-- engine recipes, and the fourth remains an iron/coal production peer.
do
  prototypes.recipe["tech-priests-emergency-mine-copper-ore"]={}
  local copper_recipe,copper_mutations=nil,0
  local copper_miner={valid=true,name="tech-priests-emergency-miner",
    type="assembling-machine",unit_number=101,
    position={x=132,y=1},force=force,surface=surface}
  copper_miner.get_recipe=function()
    return copper_recipe and {name=copper_recipe} or nil
  end
  copper_miner.set_recipe=function(name)
    copper_recipe=name;copper_mutations=copper_mutations+1;return true
  end
  local copper_station={valid=true,name="senior-cogitator-station",
    unit_number=102,position={x=128,y=0},force=force,surface=surface}
  copper_station.get_inventory=station.get_inventory
  storage.tech_priests.pairs_by_station[102]={
    station=copper_station,
    priest={valid=true,unit_number=103,position={x=129,y=0}},
    station_unit=102,radius=36
  }
  entities={miner,furnace,other_miner,other_furnace,copper_miner,cache}
  recipe_name=iron_rite
  other_recipe=coal_rite
  game.tick=3000
  Facility.service_all("four-rank-copper-specialist")
  local copper_rite="tech-priests-emergency-mine-copper-ore"
  check(copper_recipe==copper_rite and copper_mutations==1,
    "third physical miner failed to establish copper production")
  check(recipe_name==iron_rite and other_recipe==coal_rite,
    "copper assignment overwrote the existing iron/coal miners")
  game.tick=3150
  Facility.service_all("preserve-copper-specialist")
  check(copper_recipe==copper_rite and copper_mutations==1,
    "ongoing maintenance retargeted a selected copper miner")
  local fourth_recipe,fourth_mutations=nil,0
  local fourth_miner={valid=true,name="tech-priests-emergency-miner",
    type="assembling-machine",unit_number=111,
    position={x=196,y=1},force=force,surface=surface}
  fourth_miner.get_recipe=function()
    return fourth_recipe and {name=fourth_recipe} or nil
  end
  fourth_miner.set_recipe=function(name)
    fourth_recipe=name;fourth_mutations=fourth_mutations+1;return true
  end
  local fourth_station={valid=true,name="planetary-magos-cogitator-station",
    unit_number=112,position={x=192,y=0},force=force,surface=surface}
  fourth_station.get_inventory=station.get_inventory
  storage.tech_priests.pairs_by_station[112]={
    station=fourth_station,
    priest={valid=true,unit_number=113,position={x=193,y=0}},
    station_unit=112,radius=36
  }
  entities={miner,furnace,other_miner,other_furnace,copper_miner,fourth_miner,cache}
  game.tick=3300
  Facility.service_all("fourth-miner-balanced-production")
  check(fourth_recipe==iron_rite and fourth_mutations==1,
    "fourth miner displaced required iron income instead of balancing roles")
  check(copper_recipe==copper_rite and copper_mutations==1
      and other_recipe==coal_rite and recipe_name==iron_rite,
    "fourth station rewrote the other three autonomous miners")
end

print("[emergency-miner-continuity-regression] PASS scenarios=13")
