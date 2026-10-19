-- Lua 5.2 regression: genuine burner drill fuel supply through 0528.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
defines={inventory={fuel=1,chest=2,assembling_machine_input=3,
  assembling_machine_output=4,furnace_source=5,furnace_result=6}}
prototypes={item={coal={}}}
storage={tech_priests={pairs_by_station={}}}
local bound
_G.TechPriestsRuntimeTickBroker0600={
  register_service=function(s)
    if s.name=="machine_logistics_discovery_0528" then bound=s.fn end
    return true
  end
}
local inventory={valid=true,items={}}
inventory.get_item_count=function(n)return inventory.items[n] or 0 end
inventory.get_contents=function()return inventory.items end
inventory.insert=function(stack)
  inventory.items[stack.name]=(inventory.items[stack.name] or 0)+stack.count
  return stack.count
end
local force={index=1,name="player"}
local surface={index=1,name="nauvis",valid=true}
local drill={valid=true,type="mining-drill",name="burner-mining-drill",unit_number=100,
  position={x=6,y=0},surface=surface,force=force}
drill.get_inventory=function(id)if id==defines.inventory.fuel then return inventory end end
surface.find_entities_filtered=function(opts)
  if type(opts.type)=="table" then
    for _,kind in ipairs(opts.type)do if kind=="mining-drill" then return {drill} end end
  end
  return {}
end
local station={valid=true,unit_number=1,name="test-station",surface=surface,
  force=force,position={x=0,y=0}}
local priest={valid=true,unit_number=2,name="priest",surface=surface,force=force,
  position={x=0,y=0}}
local pair={station=station,priest=priest,station_unit=1,radius=18}
storage.tech_priests.pairs_by_station[1]=pair
_G.TechPriestsStorageRoleAuthority0686={
  generic_item_count=function(_,item)return item=="coal" and 7 or 0 end
}
local M=require("scripts.core.logistics_machine_fulfillment_0528")
local function check(ok,why)
  if not ok then error("drill-fuel-regression: "..why,2)end
end
check(M.install(),"discovery service was not installed")
check(type(bound)=="function","broker was not registered")
local ok=bound(nil,2)
check(ok~=nil,"machine fuel discovery did not run")
local candidate=pair.machine_logistics_candidate_0528
check(candidate and candidate.machine==drill,"burner drill omitted from machine candidate")
check(candidate.action=="supply-fuel" and candidate.item=="coal",
  "candidate was not physical coal fuel")
check(candidate.count>0 and candidate.count<=M.max_transfer,
  "fuel planning ignored station stock or bounded transfer")
inventory.insert({name="coal",count=3})
game.tick=game.tick+M.no_task_cooldown+100
pair.machine_logistics_candidate_0528=nil
bound(nil,2)
check(pair.machine_logistics_candidate_0528==nil,
  "already-fueled drill continued requesting fuel")
print("[drill-fuel-regression] PASS scenarios=2")
