-- 1223: stored real placeable hardware outranks primitive bootstrap recipes.
-- This is a policy/selection regression, not a claim of native construction.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=9000}
defines={inventory={chest=1}}
storage={tech_priests={pairs_by_station={}}}
local force={valid=true,name="player",index=1,recipes={}}
local enemy={valid=true,name="enemy",index=2}
local surface={index=1,name="nauvis"}
local other_surface={index=2,name="other"}
local function inventory(contents)
  return {valid=true,get_item_count=function(name)return contents[name] or 0 end}
end
local local_stock,enemy_stock,far_stock={}, {}, {}
local empty=inventory({})
local local_inv=inventory(local_stock)
local remote_inv=inventory(far_stock)
local enemy_inv=inventory(enemy_stock)
local station={valid=true,name="senior-cogitator-station",unit_number=21,
  type="container",position={x=0,y=0},force=force,surface=surface}
station.get_inventory=function(id)return id==1 and empty or nil end
local function chest(id,x,y,f,s,inv)
  return {valid=true,unit_number=id,name="steel-chest",type="container",
    position={x=x,y=y},force=f,surface=s,
    get_inventory=function(q)return q==1 and inv or nil end}
end
local local_chest=chest(22,8,0,force,surface,local_inv)
local foreign_chest=chest(23,9,0,enemy,surface,enemy_inv)
local remote_chest=chest(24,200,0,force,surface,remote_inv)
local wrong_surface=chest(25,8,0,force,other_surface,remote_inv)
local ore={valid=true,name="iron-ore",type="resource",
 amount=5000,position={x=12,y=3},surface=surface}
local objects={}
surface.find_entities_filtered=function(query)
  if query.area then
    -- Deliberately return invalid remembered/remote results as well: the
    -- production storage authority must reject them on its own.
    return {local_chest,foreign_chest,remote_chest,wrong_surface}
  end
  if query.type=="resource" then return {ore} end
  if query.type=="lab" then return {} end
  if type(query.type)=="table" then
    local out={local_chest}
    for _,entity in ipairs(objects) do out[#out+1]=entity end
    return out
  end
  return {}
end
local pair={station=station,priest={valid=true,unit_number=31,
  position={x=0,y=0},force=force,surface=surface},radius=24,mode="idle"}
storage.tech_priests.pairs_by_station[21]=pair
prototypes={item={}}
local function placeable(item,entity)
  prototypes.item[item]={name=item,place_result={name=entity or item}}
end
for _,item in ipairs({"stone-furnace","burner-mining-drill",
    "electric-mining-drill","assembling-machine-1","lab",
    "small-electric-pole","inserter","wooden-chest",
    "tech-priests-emergency-smelter","tech-priests-emergency-miner"}) do
  placeable(item)
end
for _,item in ipairs({"iron-plate","iron-gear-wheel","stone"}) do
  prototypes.item[item]={name=item}
end
force.recipes={
  ["stone-furnace"]={enabled=true,products={{name="stone-furnace"}},
    ingredients={{name="stone",amount=5}}},
  ["burner-mining-drill"]={enabled=true,
    products={{name="burner-mining-drill"}},
    ingredients={{name="iron-plate",amount=3},
      {name="iron-gear-wheel",amount=2}}},
  ["tech-priests-emergency-miner"]={enabled=true,
    products={{name="tech-priests-emergency-miner"}},
    ingredients={{name="iron-plate",amount=1},{name="stone",amount=1}}},
  ["tech-priests-emergency-smelter"]={enabled=true,
    products={{name="tech-priests-emergency-smelter"}},
    ingredients={{name="iron-plate",amount=1}}},
}
_G.TechPriestsPlanningConstraints0646={
 item_unlocked=function()return true end
}
local Storage=require("scripts.core.storage_role_authority_0686")
_G.TechPriestsStorageRoleAuthority0686=Storage
local Plan=require("scripts.core.master_infrastructure_plan_0644")
_G.TechPriestsMasterInfrastructurePlan0644=Plan
local Governor=require("scripts.core.infrastructure_first_governor_0640")
local function expect(cond,msg)assert(cond,"stored-bootstrap-1223: "..msg)end
local function plan(expected,name)
 local result=Plan.build_plan(pair,name)
 expect(result.target.preferred_item==expected,
   name.." expected "..expected.." got "..tostring(result.target.preferred_item))
 return result
end
-- A same-force nearby furnace is a physical construction kit, even if its
-- recipe ingredients are absent and the emergency recipe is available.
local_stock["stone-furnace"]=1
foreign_chest.valid=true
enemy_stock["stone-furnace"]=6
far_stock["stone-furnace"]=5
expect(Storage.generic_item_count(pair,"stone-furnace")==1,
 "remote/foreign/world-mismatched stock entered the physical supply count")
local furnace=plan("stone-furnace","real-crate-furnace")
expect(furnace.stage=="bootstrap-smelting"
 and furnace.target.feasibility=="stocked","stored furnace was not prioritized")
local ok,why=Governor.service_pair(pair,"stocked-furnace")
expect(not ok and why=="prestocked-machine-construction-requested"
 and pair.construction_requested_item=="stone-furnace"
 and pair.emergency_craft==nil,
 "governor crafted an emergency smelter despite physically stocked furnace")
-- Existing physical furnace completes the role; the stocked drill should
-- bypass the no-iron-plate emergency-miner prerequisite entirely.
local_stock["stone-furnace"]=0
pair.construction_requested_item=nil
local furnace_entity={valid=true,unit_number=32,name="stone-furnace",
 type="furnace",position={x=3,y=0},force=force,surface=surface}
objects={furnace_entity}
local_stock["burner-mining-drill"]=1
enemy_stock["burner-mining-drill"]=9
far_stock["burner-mining-drill"]=8
expect(Storage.generic_item_count(pair,"burner-mining-drill")==1,
 "foreign/distant finished drills bypassed physical custody domain")
local mining=plan("burner-mining-drill","real-crate-drill")
expect(mining.stage=="bootstrap-mining" and mining.target.feasibility=="stocked",
 "stored standard drill did not replace emergency bootstrap")
ok,why=Governor.service_pair(pair,"stored-standard-drill")
expect(not ok and why=="prestocked-machine-construction-requested"
 and pair.construction_requested_item=="burner-mining-drill"
 and pair.emergency_craft==nil
 and pair.infrastructure_recipe_request_0647==nil,
 "governor started primitive mining while installable standard drill waited")
-- A non-placeable item named like equipment does not qualify as hardware.
pair.construction_requested_item=nil
local_stock["burner-mining-drill"]=0
prototypes.item["burner-mining-drill"].place_result=nil
expect(Storage.generic_item_count(pair,"burner-mining-drill")==0,
 "empty local crate counted remote drills")
local no_hardware=plan("tech-priests-emergency-miner","no-real-hardware")
expect(no_hardware.target.feasibility:find("emergency-bootstrap:",1,true),
 "emergency fallback did not return when real kits were absent")
-- Merely having complete standard recipe ingredients (but not a drill)
-- must also avoid primitive emergency construction.
prototypes.item["burner-mining-drill"].place_result={name="burner-mining-drill"}
local_stock["iron-plate"]=3
local_stock["iron-gear-wheel"]=2
plan("burner-mining-drill","stored-standard-ingredient-bundle")
-- An electric-only kit is installable but not proof of a POWERED miner;
-- native readiness separately checks actual power and mined ore output.
local_stock["iron-plate"]=0
local_stock["iron-gear-wheel"]=0
local_stock["electric-mining-drill"]=1
plan("tech-priests-emergency-miner","central-bootstrap-primitive-order")
ok,why=Governor.service_pair(pair,"electric-kit-priority")
expect(not ok and why=="prestocked-machine-construction-requested"
 and pair.construction_requested_item=="electric-mining-drill"
 and pair.emergency_craft==nil,
 "stored electric machine was ignored in favor of hand-mined emergency plate")
-- No authority source must mean no fabricated local stock.
local_stock["electric-mining-drill"]=0
expect(Storage.generic_item_count(pair,"electric-mining-drill")==0,
 "empty physical source qualified for an emergency exit")
print("[stocked-equipment-priority-1223] PASS physical source domain, finished kits, ingredient bundles, emergency fallback and no synthetic equipment")
