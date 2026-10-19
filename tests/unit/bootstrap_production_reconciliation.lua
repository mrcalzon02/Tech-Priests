-- Plain Lua 5.2: normal-furnace feed and recursive bootstrap manufacturing.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
defines={inventory={chest=1,fuel=2,furnace_source=3,furnace_result=4,
  assembling_machine_input=5,assembling_machine_output=6,character_main=7,burnt_result=8}}
prototypes={item={
  ["iron-plate"]={},["iron-gear-wheel"]={},["iron-ore"]={},coal={},
  ["burner-mining-drill"]={place_result={}},["stone-furnace"]={place_result={}},stone={},
}}
_G.TechPriestsMasterInfrastructurePlan0644={
  build_plan=function()return {target={preferred_item="burner-mining-drill",stage="resource-extraction"}} end
}
_G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
  if item=="iron-gear-wheel" then return {{name="iron-plate",count=2}} end
  if item=="stone-furnace" then return {{name="stone",count=5}} end
  if item=="burner-mining-drill" then
    return {{name="iron-gear-wheel",count=2},{name="iron-plate",count=3}}
  end
  return {}
end

local F=require("scripts.core.emergency_facility_doctrine")
local Infra=require("scripts.core.infrastructure_first_governor_0640")
local Production=require("scripts.core.emergency_production_executor_0514")
local RawGovernor=require("scripts.core.bootstrap_resource_governor_0637")
_G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343=F
_G.TechPriestsEmergencyProductionExecutor0514=Production

local function check(ok,label)
  if not ok then error("bootstrap production regression: "..label,2) end
end
local function inventory(initial)
  local stock={}
  for name,n in pairs(initial or {}) do stock[name]=n end
  local x={valid=true,stock=stock}
  x.get_item_count=function(n)return stock[n] or 0 end
  x.can_insert=function()return true end
  x.insert=function(t)stock[t.name]=(stock[t.name] or 0)+t.count;return t.count end
  x.remove=function(t)
    local n=math.min(stock[t.name] or 0,t.count)
    stock[t.name]=(stock[t.name] or 0)-n
    return n
  end
  return x
end
local function fixture()
  storage={tech_priests={pairs_by_station={}}}
  game.tick=game.tick+50000
  local force={index=1,name="player",recipes={
    ["iron-gear-wheel"]={enabled=true,products={{name="iron-gear-wheel",type="item"}}},
    ["burner-mining-drill"]={enabled=true,products={{name="burner-mining-drill",type="item"}}},
    ["stone-furnace"]={enabled=true,products={{name="stone-furnace",type="item"}}},
  }}
  local source=inventory({["iron-ore"]=8,coal=6})
  local fuel=inventory()
  local input=inventory()
  local output=inventory()
  local surface={index=1,name="nauvis"}
  local ore={valid=true,name="iron-ore",type="resource",amount=1000,
    position={x=5,y=5},force=force,surface=surface}
  local furnace={valid=true,unit_number=30,name="stone-furnace",type="furnace",
    position={x=3,y=0},force=force,surface=surface}
  furnace.get_inventory=function(id)
    if id==defines.inventory.fuel then return fuel end
    if id==defines.inventory.furnace_source then return input end
    if id==defines.inventory.furnace_result then return output end
  end
  function surface.find_entities_filtered(args)
    if args.type=="resource" then return {ore} end
    if args.force and args.force~=force then return {} end
    return {furnace}
  end
  local station={valid=true,unit_number=11,name="test-station",position={x=0,y=0},
    surface=surface,force=force,get_inventory=function(id)
      if id==defines.inventory.chest then return source end
    end}
  local priest={valid=true,unit_number=12,name="test-priest",position={x=0,y=0},
    surface=surface,force=force}
  local pair={station=station,priest=priest,station_unit=11,priest_unit=12,
    radius=18,mode="idle"}
  storage.tech_priests.pairs_by_station[11]=pair
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local n=source.insert({name=item,count=count})
    return n==count,"deposited",n
  end
  return {pair=pair,force=force,furnace=furnace,ore=ore,source=source,
    fuel=fuel,input=input,output=output,surface=surface}
end
local total=0
local function scenario(name,run)
  run();total=total+1
  print("[bootstrap-production-regression] PASS "..name)
end

scenario("local standard furnace adopted and fed real ore and coal",function()
  local f=fixture()
  f.pair.emergency_craft={item_name="iron-plate",output_item="iron-plate",
    count=4,facility_only_0647=true}
  local ok,why=F.service_pair(f.pair,"test")
  check(ok and why=="used-owned-facilities","standard furnace not used: "..tostring(why))
  check(f.input.get_item_count("iron-ore")==4,"no physical ore transferred")
  check(f.fuel.get_item_count("coal")==2,"no physical fuel transferred")
  check(f.source.get_item_count("iron-ore")==4 and f.source.get_item_count("coal")==4,
    "machine was fed without exact station withdrawal")
  check(F.tag_built_entity~=nil,"facility registration unavailable")
  local record=storage.tech_priests.emergency_facility_doctrine_0343
  check(record~=nil,"normal furnace ownership not recorded")
end)

scenario("ordinary furnace counts as smelter before miner planning",function()
  local f=fixture()
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=iron-plate",1,true)~=nil,
    "built normal furnace did not expose smelting prerequisite: "..status)
end)

scenario("manufactured gear dependency gets strict recipe and consumes plates",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=4})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}
  }
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=iron-gear-wheel",1,true)~=nil,
    "manufactured prerequisite was ignored: "..status)
  local ok,why=Infra.service_pair(f.pair,"test-dependency")
  check(ok,"could not assign gear craft: "..tostring(why))
  local task=f.pair.emergency_craft
  check(task and task.strict_recipe_0647==true and task.output_item=="iron-gear-wheel",
    "missing dependency did not become strict manufacturing task")
  check(task.strict_recipe_ingredients_0647[1].name=="iron-plate",
    "iron gear recipe ingredients were not bound")
  game.tick=game.tick+Production.default_station_craft_ticks+2
  local done,detail=Production.service_pair(f.pair,"finish-gear")
  check(done,"strict manufactured gear failed: "..tostring(detail))
  check(f.source.get_item_count("iron-gear-wheel")==1,"gear was not produced")
  check(f.source.get_item_count("iron-plate")==2,"gear did not consume exact plates")
end)

scenario("locked force recipe cannot be manufactured by the bootstrap gate",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=4})
  f.force.recipes["iron-gear-wheel"].enabled=false
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}
  }
  local ok,reason=Infra.service_pair(f.pair,"locked-gear")
  check(not ok and tostring(reason):find("recipe-locked-or-unavailable",1,true),
    "locked recipe incorrectly admitted")
  check(f.pair.emergency_craft==nil,"locked recipe produced a craft task")
end)

scenario("partial gear stock manufactures one missing unit then resumes drill",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=6})
  f.source.insert({name="iron-gear-wheel",count=1})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}
  }
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=iron-gear-wheel",1,true)~=nil,
    "single gear incorrectly satisfied two-gear prerequisite")
  local ok,detail=Infra.service_pair(f.pair,"partial-gears")
  check(ok,"partial stock failed to request real second gear: "..tostring(detail))
  check(f.pair.emergency_craft and f.pair.emergency_craft.strict_recipe_0647==true,
    "partial stock bypassed strict manufacturing")
  game.tick=game.tick+Production.default_station_craft_ticks+2
  check(Production.service_pair(f.pair,"finish-second-gear"),"second gear not fabricated")
  check(f.source.get_item_count("iron-gear-wheel")==2,
    "second physical gear was not added to previous stock")
  check(f.source.get_item_count("iron-plate")==4,
    "second gear did not consume its exact plate ingredients")
  local next_status=Infra.status_for_pair(f.pair)
  check(next_status:find("needed=burner-mining-drill",1,true)~=nil,
    "satisfied ingredient count did not resume parent machine recipe: "..next_status)
end)

scenario("raw stone dependency resumes original furnace craft",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=5})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="stone-furnace",
    reason="central-plan:resource-extraction",
    ingredients={{name="stone-furnace",count=1}}
  }
  local ok,why=Infra.service_pair(f.pair,"missing-stone-furnace")
  check(ok,"no child furnace dependency: "..tostring(why))
  local request=f.pair.infrastructure_recipe_request_0647
  check(request and request.item=="stone-furnace" and request.missing=="stone",
    "stone furnace did not request physical stone")
  check(not f.pair.emergency_craft,"stone furnace was fabricated without stone")
  f.source.insert({name="stone",count=5})
  local retried,detail=Infra.service_pair(f.pair,"stone-arrived")
  check(retried,"child furnace did not resume after stone delivery: "..tostring(detail))
  local craft=f.pair.emergency_craft
  check(craft and craft.item_name=="stone-furnace" and craft.strict_recipe_0647==true,
    "raw-material request was overwritten before strict furnace manufacturing")
  check(craft.strict_recipe_ingredients_0647[1].name=="stone",
    "furnace recipe did not bind stone consumption")
end)

scenario("manufactured prerequisite suppresses unrelated bulk mining",function()
  local f=fixture()
  f.pair.mode="direct-acquisition-working"
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}
  }
  RawGovernor.root().enabled=true
  local worked,reason=RawGovernor.service_pair(f.pair,"manufacturer-priority")
  check(not worked and reason=="reserve-satisfied",
    "generic reserve mining stole manufactured prerequisite priority")
  check(f.pair.direct_acquisition_task_0336==nil,
    "a new bulk resource task was assigned during gear dependency")
end)

scenario("strict manufacturing blocks new bulk reserve assignment",function()
  local f=fixture()
  f.pair.emergency_craft={output_item="iron-gear-wheel",
    strict_recipe_0647=true,strict_recipe_ingredients_0647={{name="iron-plate",count=2}}}
  RawGovernor.root().enabled=true
  local acted,why=RawGovernor.service_pair(f.pair,"strict-craft-priority")
  check(not acted and why=="strict-recipe-in-progress",
    "strict craft did not take precedence over raw reserves")
  check(f.pair.direct_acquisition_task_0336==nil,
    "strict recipe was preempted by optional bulk gathering")
end)

scenario("unladen governor reserve yields to real recipe craft",function()
  local f=fixture()
  local raw={kind="direct-mine-0336",output_item="iron-ore",
    bootstrap_resource_0637=true,current={kind="direct-mine-0336",
      entity=f.ore,output_item="iron-ore"}}
  f.pair.direct_acquisition_task_0336=raw
  f.pair.active_acquisition_0333=raw
  f.pair.target=f.ore
  f.pair.mode="direct-acquisition-working"
  f.pair.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel"}
  RawGovernor.root().enabled=true
  local acted,why=RawGovernor.service_pair(f.pair,"yield-to-recipe")
  check(not acted and why=="strict-recipe-in-progress","reserve did not yield")
  check(f.pair.direct_acquisition_task_0336==nil
    and f.pair.active_acquisition_0333==nil,"old bulk mining aliases survived")
  check(f.pair.target==nil,"stale raw target survived craft priority")
  check(f.pair.emergency_craft.strict_recipe_0647==true,
    "yield modified the authorized manufacturing task")
end)

scenario("raw acquisition cargo is preserved until returned",function()
  local f=fixture()
  local raw={kind="direct-mine-0336",output_item="iron-ore",
    bootstrap_resource_0637=true,current={kind="direct-mine-0336",
      entity=f.ore,output_item="iron-ore"}}
  f.pair.direct_acquisition_task_0336=raw
  f.pair.direct_acquisition_custody_0513={item="iron-ore",count=1}
  f.pair.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel"}
  RawGovernor.root().enabled=true
  local acted,why=RawGovernor.service_pair(f.pair,"hold-cargo")
  check(not acted and why=="strict-recipe-waiting-direct-custody",
    "cargo was not protected")
  check(f.pair.direct_acquisition_task_0336==raw
    and f.pair.direct_acquisition_custody_0513.count==1,
    "loaded raw acquisition was discarded")
end)

scenario("strict production never retires unrelated active acquisition order",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=4})
  f.pair.emergency_craft={strict_recipe_0647=true,item_name="iron-gear-wheel",
    output_item="iron-gear-wheel",count=1,target_stock_0647=1,
    strict_recipe_ingredients_0647={{name="iron-plate",count=2}}}
  local acquisition={kind="acquisition",status="active",
    key="mining-order-unrelated",item="iron-ore",priority=570}
  f.pair.order_queue_0469={current=acquisition,pending={},pending_keys={}}
  local acknowledgements=0
  _G.TECH_PRIESTS_ORDER_QUEUE_0469={
    complete_current=function() acknowledgements=acknowledgements+1;return true end
  }
  Production.service_pair(f.pair,"manufacturing-start")
  game.tick=game.tick+Production.default_station_craft_ticks+2
  local ok=Production.service_pair(f.pair,"manufacturing-complete")
  check(ok,"strict manufacturing did not complete")
  check(f.source.get_item_count("iron-gear-wheel")==1,
    "real ingredients did not produce exactly one gear")
  check(f.source.get_item_count("iron-plate")==2,
    "manufacturing failed to consume physical plates")
  check(f.pair.order_queue_0469.current==acquisition and acknowledgements==0,
    "unrelated acquisition order was falsely acknowledged")
  _G.TECH_PRIESTS_ORDER_QUEUE_0469=nil
end)

scenario("parent mining drill recipe survives both gear transactions",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=10})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    reason="central-plan:resource-extraction",
    ingredients={{name="iron-gear-wheel",count=2},
      {name="iron-plate",count=3}}
  }
  for n=1,2 do
    local ok,why=Infra.service_pair(f.pair,"gear-chain-"..n)
    check(ok,"failed to assign gear unit "..n..": "..tostring(why))
    local craft=f.pair.emergency_craft
    check(craft and craft.output_item=="iron-gear-wheel",
      "child manufacturing request was not retained")
    check(craft.resume_parent_recipe_request_0647
      and craft.resume_parent_recipe_request_0647.item=="burner-mining-drill",
      "parent drill recipe was not bound into gear task")
    game.tick=game.tick+Production.default_station_craft_ticks+2
    check(Production.service_pair(f.pair,"physical-gear-"..n),
      "physical gear manufacturing failed")
    check(f.source.get_item_count("iron-gear-wheel")==n,
      "physical gear count after transaction "..n.." is wrong")
    check(f.pair.emergency_craft==nil,"completed child craft left active")
    check(f.pair.infrastructure_recipe_request_0647
      and f.pair.infrastructure_recipe_request_0647.item=="burner-mining-drill",
      "finished gear transaction did not restore parent request")
    check(f.pair.local_infrastructure_gate_0640==nil,
      "completed child gate trapped subsequent production")
  end
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=burner-mining-drill",1,true)~=nil,
    "full gear stock did not return planning to parent drill")
end)

scenario("stone-furnace raw-material child restores parent drill after craft",function()
  local f=fixture()
  -- This fixture isolates the stone-child chain after the first smelting gate.
  f.source.insert({name="iron-plate",count=5})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="stone-furnace",
    reason="central-plan:resource-extraction",
    ingredients={{name="stone-furnace",count=1}}
  }
  check(Infra.service_pair(f.pair,"stone-child"),"stone child request failed")
  local req=f.pair.infrastructure_recipe_request_0647
  check(req and req.item=="stone-furnace" and req.missing=="stone",
    "stone child lost raw ingredient request")
  check(req.parent_request_0647 and req.parent_request_0647.item=="burner-mining-drill",
    "raw stone request lost parent drill identity")
  f.source.insert({name="stone",count=5})
  check(Infra.service_pair(f.pair,"stone-delivered"),"stone craft not resumed")
  local craft=f.pair.emergency_craft
  check(craft and craft.resume_parent_recipe_request_0647
    and craft.resume_parent_recipe_request_0647.item=="burner-mining-drill",
    "raw child craft lost parent before execution")
  game.tick=game.tick+Production.default_station_craft_ticks+2
  check(Production.service_pair(f.pair,"stone-furnace-complete"),
    "physical furnace craft failed")
  check(f.source.get_item_count("stone-furnace")==1
    and f.source.get_item_count("stone")==0,"stone was not consumed exactly")
  check(f.pair.infrastructure_recipe_request_0647
    and f.pair.infrastructure_recipe_request_0647.item=="burner-mining-drill",
    "stone-furnace completion did not restore drill request")
end)

print("[bootstrap-production-regression] PASS scenarios="..total)
