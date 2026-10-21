-- Lua 5.2: infrastructure stock must follow canonical managed storage.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=9000}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,assembling_machine_input=2,assembling_machine_output=3,
  furnace_result=4,furnace_source=5,fuel=6}}
prototypes={item={["electronic-circuit"]={},["copper-cable"]={},
  ["copper-plate"]={},["iron-plate"]={}}}
local function check(ok,msg)
  if not ok then error("infrastructure cache stock: "..msg,2) end
end
local function inv(items)
  return {valid=true,get_item_count=function(item)return items[item] or 0 end}
end
local stock={["iron-plate"]=1,["copper-plate"]=2}
local phantom={["iron-plate"]=97,["copper-plate"]=97,coal=97}
local force={index=1,recipes={
  ["electronic-circuit"]={enabled=true,products={{name="electronic-circuit",type="item"}}}
}}
local surface={index=1}
local cache={valid=true,name="tech-priests-martian-stone-cache",type="container",
  unit_number=50,position={x=4,y=0},force=force,surface=surface}
local cacheInv=inv(stock)
cache.get_inventory=function(id)
  if id==defines.inventory.chest then return cacheInv end
end
local assembler={valid=true,name="tech-priests-emergency-assembler",
  type="assembling-machine",unit_number=51,position={x=3,y=0},
  force=force,surface=surface}
function surface.find_entities_filtered(opts)
  if opts.type=="resource" then return {} end
  if type(opts.type)=="table" then
    -- Both the storage scanner and the infrastructure facility survey can
    -- request containers and machines together. Keep the mock faithful.
    return {cache,assembler}
  end
  return {}
end
local station={valid=true,name="junior-cogitator-station",
  unit_number=10,position={x=0,y=0},force=force,surface=surface}
local chest=inv({})
local machine=inv(phantom)
station.get_inventory=function(id)
  if id==defines.inventory.chest then return chest end
  return machine
end
local priest={valid=true,unit_number=11,position={x=0,y=0},surface=surface,force=force}
local pair={station=station,priest=priest,station_unit=10,mode="idle",radius=24}
storage.tech_priests.pairs_by_station[10]=pair
local Authority=require("scripts.core.storage_role_authority_0686")
_G.TechPriestsStorageRoleAuthority0686=Authority
local Infra=require("scripts.core.infrastructure_first_governor_0640")
local status=Infra.status_for_pair(pair)
check(status:find("iron_plate=1",1,true)~=nil,"machine work buffer credited as iron stock")
check(status:find("copper_plate=2",1,true)~=nil,"stone-cache copper plate was invisible")
check(status:find("needed=electronic-circuit",1,true)~=nil,"workshop did not select electronics")
check(Authority.generic_item_count(pair,"coal")==0,"machine fuel credited as storage")
force.recipes["electronic-circuit"].enabled=false
pair.infrastructure_recipe_request_0647={item="copper-cable",missing="copper-plate",
  ingredients={{name="copper-plate",count=2}}}
status=Infra.status_for_pair(pair)
check(status:find("needed=copper-cable",1,true)~=nil,"cache stock did not satisfy cable prerequisite")
stock["copper-plate"]=0
status=Infra.status_for_pair(pair)
check(status:find("copper_plate=0",1,true)~=nil
  and status:find("needed=copper-plate",1,true)~=nil,
  "missing copper was masked by false Cogitator stock")
print("[infrastructure-cache-stock] PASS scenarios=6")
