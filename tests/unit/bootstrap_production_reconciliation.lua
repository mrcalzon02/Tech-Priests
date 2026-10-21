-- Plain Lua 5.2: normal-furnace feed and recursive bootstrap manufacturing.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
defines={inventory={chest=1,fuel=2,furnace_source=3,furnace_result=4,
  assembling_machine_input=5,assembling_machine_output=6,character_main=7,burnt_result=8}}
prototypes={item={
  ["iron-plate"]={},["iron-gear-wheel"]={},["iron-ore"]={},coal={},
  ["burner-mining-drill"]={place_result={}},["stone-furnace"]={place_result={}},stone={},
  ["iron-chest"]={place_result={name="iron-chest"}},
}}
_G.TechPriestsMasterInfrastructurePlan0644={
  build_plan=function()return {target={preferred_item="burner-mining-drill",stage="resource-extraction"}} end
}
_G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
  if item=="iron-gear-wheel" then return {{name="iron-plate",count=2}} end
  if item=="stone-furnace" then return {{name="stone",count=5}} end
  if item=="iron-chest" then return {{name="iron-plate",count=2}} end
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
    ["iron-chest"]={enabled=true,products={{name="iron-chest",type="item"}}},
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

scenario("unfueled standard drill demands real coal before bulk reserve",function()
  local f=fixture()
  local stock=f.source.get_item_count("coal")
  f.source.remove({name="coal",count=stock})
  local resource={valid=true,name="coal",type="resource",amount=1000,
    position={x=8,y=3},surface=f.surface,force=f.force}
  local fuel=inventory()
  local drill={valid=true,type="mining-drill",name="burner-mining-drill",
    unit_number=51,position={x=7,y=3},surface=f.surface,force=f.force}
  drill.get_inventory=function(id)
    if id==defines.inventory.fuel then return fuel end
  end
  drill.burner={remaining_burning_fuel=0}
  f.surface.find_entities_filtered=function(args)
    if args.name=="burner-mining-drill" then return {drill} end
    if args.type=="resource" and args.name=="coal" then return {resource} end
    if args.type=="resource" then return {f.ore,resource} end
    return {f.furnace}
  end
  f.pair.mode="emergency"
  RawGovernor.root().enabled=true
  local ok,why=RawGovernor.service_pair(f.pair,"drill-fuel")
  check(ok and why=="assigned",
    "no real direct coal acquisition was assigned: "..tostring(why))
  local task=f.pair.direct_acquisition_task_0336
  check(task and task.output_item=="coal" and task.required_count==3,
    "unfueled drill did not prioritize exactly three physical coal")
  check(task.current and task.current.entity==resource,
    "fuel acquisition was not tied to the physical coal patch")
end)

scenario("physical drill receiver chest consumes real iron plates",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=4})
  local original=_G.TechPriestsMasterInfrastructurePlan0644.build_plan
  _G.TechPriestsMasterInfrastructurePlan0644.build_plan=function()
    return {target={preferred_item="iron-chest",stage="mining-output-buffer"}}
  end
  local ok,why=Infra.service_pair(f.pair,"drill-receiver")
  _G.TechPriestsMasterInfrastructurePlan0644.build_plan=original
  check(ok,"receiver manufacturing step was not scheduled: "..tostring(why))
  local task=f.pair.emergency_craft
  check(task and task.output_item=="iron-chest"
    and task.strict_recipe_0647==true,
    "drill output receiver was not routed through strict production")
  game.tick=game.tick+Production.default_station_craft_ticks+2
  local worked=Production.service_pair(f.pair,"chest-transaction")
  check(worked and f.source.get_item_count("iron-chest")==1,
    "real iron chest was not manufactured")
  check(f.source.get_item_count("iron-plate")==2,
    "receiver material cost not physically consumed")
end)

scenario("active infrastructure blocks generic bulk reserve starvation",function()
  local f=fixture()
  f.pair.mode="idle"
  f.pair.local_infrastructure_gate_0640={
    state="assigned-local-step",item="iron-gear-wheel"}
  RawGovernor.root().enabled=true
  local assigned,why=RawGovernor.service_pair(f.pair,"gear-priority")
  check(not assigned and why=="infrastructure-prerequisite-priority",
    "generic reserve acquisition stole pending infrastructure work")
  check(f.pair.direct_acquisition_task_0336==nil,
    "unrelated raw mining task was scheduled over a concrete gear requirement")
  check(f.pair.bootstrap_mode_0637
    and f.pair.bootstrap_mode_0637.state=="deferred-for-infrastructure",
    "reserve governor reported missing bulk stock as physically satisfied")
end)

scenario("first circuits descend through physical copper cable",function()
  local f=fixture()
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=34,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local original_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return original_find(args) end
    return {f.furnace,assembler}
  end
  prototypes.item["electronic-circuit"]={}
  prototypes.item["copper-cable"]={}
  prototypes.item["copper-plate"]={}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{name="electronic-circuit",type="item",amount=1}}}
  f.force.recipes["copper-cable"]={enabled=true,
    products={{name="copper-cable",type="item",amount=2}}}
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="copper-plate",count=2})
  local former=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(name)
    if name=="electronic-circuit" then
      return {{name="iron-plate",count=1},{name="copper-cable",count=3}}
    end
    if name=="copper-cable" then return {{name="copper-plate",count=1}} end
    return former(name)
  end
  local drill_parent={item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}},
    reason="central-plan:bootstrap-normal-mining"}
  f.pair.infrastructure_recipe_request_0647=drill_parent
  f.pair.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel"}
  local busy=Infra.status_for_pair(f.pair)
  check(not busy:find("needed=electronic-circuit",1,true)
    and f.pair.emergency_craft
    and f.pair.emergency_craft.output_item=="iron-gear-wheel",
    "active strict gear task was replaced by electronics: "..busy)
  f.pair.emergency_craft=nil
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=electronic-circuit",1,true),
    "idle workshop failed to begin electronics before costly drill: "..status)
  local started,why=Infra.service_pair(f.pair,"electronics-prerequisite")
  check(started,"unlocked circuit dependency was not registered: "..tostring(why))
  local parent=f.pair.infrastructure_recipe_request_0647
  check(parent and parent.item=="electronic-circuit"
    and parent.missing=="copper-cable"
    and parent.parent_request_0647
    and parent.parent_request_0647.item=="burner-mining-drill",
    "electronic circuit lost its real copper cable or suspended drill parent")
  local child,detail=Infra.service_pair(f.pair,"copper-cable-dependency")
  check(child,"copper-cable dependency not queued: "..tostring(detail))
  local craft=f.pair.emergency_craft
  check(craft and craft.strict_recipe_0647==true
    and craft.output_item=="copper-cable"
    and craft.target_stock_0647==3
    and craft.resume_parent_recipe_request_0647
    and craft.resume_parent_recipe_request_0647.item=="electronic-circuit",
    "wire recipe lost its exact inputs, amount, or parent circuit")
  check(f.source.get_item_count("iron-plate")==1
    and f.source.get_item_count("copper-plate")==2
    and f.source.get_item_count("copper-cable")==0,
    "planning invented copper cable or spent materials before an actual craft")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=former
end)

scenario("first physical workshop demands bounded copper ore despite drill wait",function()
  local f=fixture()
  prototypes.item["copper-ore"]={}
  prototypes.item["copper-plate"]={}
  prototypes.item["electronic-circuit"]={}
  local copper={valid=true,name="copper-ore",type="resource",amount=400,
    position={x=6,y=5},surface=f.surface,force=f.force}
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",position={x=6,y=0},
    surface=f.surface,force=f.force}
  local original_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" and args.name=="copper-ore" then return {copper} end
    if args.type=="assembling-machine" then return {assembler} end
    return original_find(args)
  end
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}
  }
  f.pair.master_infrastructure_plan_0644={
    tick=game.tick,roles={["emergency-assembler"]=1}}
  f.pair.local_infrastructure_gate_0640={
    state="waiting-recipe-material",item="burner-mining-drill"}
  RawGovernor.root().enabled=true
  local scheduled,why=RawGovernor.service_pair(f.pair,"real-copper-for-workshop")
  check(scheduled and why=="assigned",
    "first workshop was starved by unrelated drill gear wait: "..tostring(why))
  local task=f.pair.direct_acquisition_task_0336
  check(task and task.output_item=="copper-ore" and task.required_count==3
    and task.bootstrap_resource_0637==true,
    "copper-ore request was not a bounded real direct-mining objective")
  check(f.source.get_item_count("copper-ore")==0
    and f.pair.infrastructure_recipe_request_0647.item=="burner-mining-drill",
    "scheduling copper invented ore or erased the normal-drill parent")
end)

scenario("circuit dependency smelts real copper ore through the standard furnace",function()
  local f=fixture()
  prototypes.item["electronic-circuit"]={}
  prototypes.item["copper-cable"]={}
  prototypes.item["copper-plate"]={}
  prototypes.item["copper-ore"]={}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{type="item",name="electronic-circuit",amount=1}}}
  f.force.recipes["copper-cable"]={enabled=true,
    products={{type="item",name="copper-cable",amount=2}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=46,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler}
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="electronic-circuit" then
      return {{name="iron-plate",count=1},{name="copper-cable",count=3}}
    elseif item=="copper-cable" then
      return {{name="copper-plate",count=1}}
    end
    return previous(item)
  end
  f.source.insert({name="iron-plate",count=1})
  check(Infra.service_pair(f.pair,"circuits"),"first circuit parent not requested")
  check(Infra.status_for_pair(f.pair):find("needed=copper-plate",1,true),
    "missing copper plate did not descend through copper cable")
  local requested,why=Infra.service_pair(f.pair,"copper-plate-prerequisite")
  check(requested,"smelting prerequisite was not assigned: "..tostring(why))
  check(f.pair.emergency_craft and f.pair.emergency_craft.facility_only_0647==true
    and f.pair.emergency_craft.output_item=="copper-plate",
    "missing copper plate incorrectly fabricated outside a real furnace")
  local pending=f.pair.infrastructure_recipe_request_0647
  check(pending and pending.item=="electronic-circuit"
    and pending.missing=="copper-cable",
    "smelting copper discarded the circuit/cable parent")
  f.source.insert({name="copper-ore",count=4})
  local worked,detail=F.service_pair(f.pair,"furnace-copper-feed")
  check(worked and detail=="used-owned-facilities"
    and f.input.get_item_count("copper-ore")==4
    and f.source.get_item_count("copper-ore")==0
    and f.source.get_item_count("copper-plate")==0,
    "physical furnace was not fed exact copper ore before circuit crafting")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)

scenario("stalled real assembler yields to bounded strict station craft",function()
  local f=fixture()
  f.source.insert({name="iron-plate",count=4})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=99,
    position={x=6,y=0},force=f.force,surface=f.surface,
    get_inventory=function()return nil end}
  local function owned()
    storage.tech_priests.emergency_facility_doctrine_0343={
      by_station={[11]={gear=true}},
      facilities={gear={entity=assembler,role="assembler"}}}
  end
  owned()
  local previous=_G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343={
    service_pair=function()return true,"used-owned-facilities" end}
  local task={output_item="iron-gear-wheel",count=1,
    strict_recipe_0647=true,
    strict_recipe_ingredients_0647={{name="iron-plate",count=2}}}
  f.pair.emergency_craft=task
  local accepted,why=Production.service_pair(f.pair,"real-assembler-first")
  check(accepted and why=="used-owned-facilities",
    "physical assembler was not given its first recipe opportunity")
  check(f.source.get_item_count("iron-plate")==4
      and f.source.get_item_count("iron-gear-wheel")==0,
    "first facility service fabricated manufactured output")
  game.tick=game.tick+Production.facility_wait_ticks+1
  local delayed,stage=Production.service_pair(f.pair,"stall-expired")
  check(delayed and stage=="crafting" and task.station_craft_pending_0514==true,
    "indefinite facility feeding blocked the bounded strict fallback")
  check(f.source.get_item_count("iron-plate")==4,
    "fallback consumed materials before real work elapsed")
  game.tick=game.tick+Production.default_station_craft_ticks+1
  check(Production.service_pair(f.pair,"strict-fallback-due"),
    "strict fallback did not finish after material-backed work")
  check(f.source.get_item_count("iron-gear-wheel")==1
      and f.source.get_item_count("iron-plate")==2
      and not f.pair.emergency_production_custody_0514,
    "strict fallback did not conserve and account physical ingredients")
  local empty=fixture()
  owned()
  empty.pair.emergency_craft={output_item="iron-gear-wheel",count=1,
    strict_recipe_0647=true,
    strict_recipe_ingredients_0647={{name="iron-plate",count=2}}}
  check(Production.service_pair(empty.pair,"empty-assembler"),
    "empty assembler startup was not serviced")
  game.tick=game.tick+Production.facility_wait_ticks+1
  Production.service_pair(empty.pair,"empty-fallback-start")
  game.tick=game.tick+Production.default_station_craft_ticks+1
  Production.service_pair(empty.pair,"empty-fallback-due")
  check(empty.source.get_item_count("iron-gear-wheel")==0
      and empty.pair.emergency_production_custody_0514==nil,
    "strict fallback fabricated gear without actual physical plates")
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343=previous
end)

scenario("surveys cannot overwrite a live physical copper-smelting task",function()
  local f=fixture()
  -- The new survey wants the first iron plate, but the previous machine
  -- transaction already owns a real copper plate furnace request.
  local task={item_name="copper-plate",output_item="copper-plate",
    count=2,facility_only_0647=true,infrastructure_first_0640=true,
    started_tick=game.tick,facility_started_tick_0514=game.tick}
  f.pair.emergency_craft=task
  f.pair.local_infrastructure_gate_0640={item="copper-plate",
    state="assigned-local-step",why="circuit-copper"}
  local ok,why=Infra.service_pair(f.pair,"survey-while-copper-smelting")
  check(ok==false and why=="active-local-production-retained",
    "unrelated iron reserve sweep displaced active copper smelting")
  check(f.pair.emergency_craft==task
    and f.pair.local_infrastructure_gate_0640.item=="copper-plate",
    "live copper task or its completion gate was overwritten")
  f.pair.emergency_craft=nil
  f.pair.mode="idle"
  local next_ok=Infra.service_pair(f.pair,"after-copper-complete")
  check(next_ok==true and f.pair.emergency_craft
    and f.pair.emergency_craft.output_item=="iron-plate",
    "finished copper transaction prevented the next iron prerequisite")
end)

scenario("surveys preserve strict craft timers and their recipe custody",function()
  local f=fixture()
  local task={item_name="iron-gear-wheel",output_item="iron-gear-wheel",
    strict_recipe_0647=true,infrastructure_first_0640=true,
    strict_recipe_ingredients_0647={{name="iron-plate",count=2}},
    craft_due_tick_0514=game.tick+300}
  f.pair.emergency_craft=task
  f.pair.local_infrastructure_gate_0640={item="iron-gear-wheel",
    state="assigned-local-step",why="strict-drill-gears"}
  local ok,why=Infra.service_pair(f.pair,"survey-while-strict-work")
  check(ok==false and why=="active-local-production-retained",
    "live gear manufacturing was displaced by different missing material")
  check(f.pair.emergency_craft==task
    and f.pair.emergency_craft.craft_due_tick_0514==game.tick+300,
    "strict transaction due time was reset during a new survey")
end)

scenario("built workshop selects electronics before stale drill-gear demand",function()
  local f=fixture()
  prototypes.item["electronic-circuit"]={}
  prototypes.item["copper-cable"]={}
  prototypes.item["copper-plate"]={}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{type="item",name="electronic-circuit",amount=1}}}
  local saved_ingredients=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="electronic-circuit" then
      return {{name="iron-plate",count=1},{name="copper-cable",count=3}}
    end
    return saved_ingredients(item)
  end
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=81,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local previous_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return previous_find(args) end
    return {f.furnace,assembler}
  end
  f.source.insert({name="iron-plate",count=2})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}}
  check(Infra.status_for_pair(f.pair):find("needed=electronic-circuit",1,true),
    "unfinished drill gear demand suppressed first workshop electronics")
  local held={output_item="iron-gear-wheel",item_name="iron-gear-wheel",
    strict_recipe_0647=true,infrastructure_first_0640=true,
    craft_due_tick_0514=game.tick+1000}
  f.pair.emergency_craft=held
  local guarded,reason=Infra.service_pair(f.pair,"live-gear-before-electronics")
  check(f.pair.emergency_craft==held
      and held.craft_due_tick_0514==game.tick+1000
      and (reason=="bootstrap-local-step-already-assigned"
        or reason=="already-working-local-step"
        or reason=="active-local-production-retained"),
    "electronics priority interrupted strict gear manufacturing: "..tostring(reason))
  f.pair.emergency_craft=nil
  f.pair.mode="idle"
  local requested,why=Infra.service_pair(f.pair,"after-gear-handoff")
  check(requested and why=="requested-recipe-material",
    "completed gear did not yield a physical circuit recipe dependency")
  check(f.pair.infrastructure_recipe_request_0647
      and f.pair.infrastructure_recipe_request_0647.item=="electronic-circuit"
      and f.pair.infrastructure_recipe_request_0647.missing=="copper-cable",
    "electronics priority discarded or bypassed the copper-cable prerequisite")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=saved_ingredients
end)

scenario("real workshop plate unlocks circuit without fabricated reserves",function()
  local f=fixture()
  prototypes.item["electronic-circuit"]={}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{name="electronic-circuit",type="item",amount=1}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=101,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local previous_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return previous_find(args) end
    return {f.furnace,assembler}
  end
  f.pair.emergency_craft={item_name="iron-plate",output_item="iron-plate",
    infrastructure_first_0640=true,facility_only_0647=true,count=4,
    required_count=4,started_tick=game.tick}
  f.pair.local_infrastructure_gate_0640={item="iron-plate",
    why="recipe-prerequisite-for:burner-mining-drill",state="assigned-local-step"}
  f.pair.infrastructure_recipe_request_0647={item="burner-mining-drill",
    missing="iron-gear-wheel",ingredients={{name="iron-gear-wheel",count=2}}}
  local old_production=_G.TechPriestsEmergencyProductionExecutor0514
  _G.TechPriestsEmergencyProductionExecutor0514=Production
  f.source.insert({name="iron-plate",count=1})
  local scheduled,why=Infra.service_pair(f.pair,"electronic-workshop-handoff")
  check(f.source.get_item_count("iron-plate")==1
    and f.pair.emergency_craft==nil,
    "one physically stored plate did not close oversized iron reserve")
  check(f.pair.infrastructure_recipe_request_0647
      and f.pair.infrastructure_recipe_request_0647.item=="burner-mining-drill",
    "circuit handoff erased the suspended standard drill dependency")
  check(Infra.status_for_pair(f.pair):find("needed=electronic-circuit",1,true),
    "completed iron reserve did not expose the first circuit objective")
  _G.TechPriestsEmergencyProductionExecutor0514=old_production
end)

scenario("fuel-starved strict assembler requests physical coal without overwriting recipe",function()
  local f=fixture()
  local coal={valid=true,name="coal",type="resource",amount=1000,
    position={x=5,y=4},force=f.force,surface=f.surface}
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=110,
    position={x=4,y=0},force=f.force,surface=f.surface,
    status=53,get_recipe=function()return {name="iron-gear-wheel"}end,
    get_inventory=function()return inventory()end,
    burner={remaining_burning_fuel=0}}
  local base_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" and args.name=="coal" then return {coal} end
    if args.name=="tech-priests-emergency-assembler" then return {assembler} end
    return base_find(args)
  end
  defines.entity_status={no_fuel=53}
  storage.tech_priests.emergency_facility_doctrine_0343={
    facilities={fuel_assembler={entity=assembler}},
    by_station={[11]={fuel_assembler=true}}
  }
  f.source.remove({name="coal",count=6})
  f.pair.emergency_craft={output_item="iron-gear-wheel",
    strict_recipe_0647=true,infrastructure_first_0640=true,
    strict_recipe_ingredients_0647={{name="iron-plate",count=2}}}
  RawGovernor.root().enabled=true
  local scheduled,why=RawGovernor.service_pair(f.pair,"strict-assembler-needs-real-coal")
  check(scheduled==true and why=="assigned",
    "coal starvation did not schedule physical extraction: "..tostring(why))
  local fuel=f.pair.direct_acquisition_task_0336
  check(fuel and fuel.output_item=="coal"
      and fuel.fuel_for_strict_recipe_0637==true
      and f.pair.emergency_craft.strict_recipe_0647==true
      and f.pair.emergency_craft.output_item=="iron-gear-wheel",
    "fuel mining replaced strict gear manufacturing")
  local continued,stage=RawGovernor.service_pair(f.pair,"fuel-acquisition-live")
  check(continued==false and stage=="strict-recipe-fuel-acquisition-in-progress"
    and f.pair.direct_acquisition_task_0336==fuel,
    "active physical fuel task was incorrectly discarded")
  defines.entity_status=nil
end)

scenario("physical copper ore is smelted before the expensive drill gear loop",function()
  local f=fixture()
  prototypes.item["copper-ore"]={}
  prototypes.item["copper-plate"]={}
  prototypes.item["electronic-circuit"]={}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{name="electronic-circuit",type="item",amount=1}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=119,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local previous_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return previous_find(args) end
    return {f.furnace,assembler}
  end
  f.source.insert({name="copper-ore",count=3})
  f.source.insert({name="iron-plate",count=1})
  f.pair.infrastructure_recipe_request_0647={item="burner-mining-drill",
    missing="iron-gear-wheel",ingredients={{name="iron-gear-wheel",count=2}}}
  local summary=Infra.status_for_pair(f.pair)
  check(summary:find("needed=copper-plate",1,true),
    "physical copper ore was ignored in favor of pending drill gears: "..summary)
  local ok,why=Infra.service_pair(f.pair,"first-workshop-copper")
  check(ok and f.pair.emergency_craft
    and f.pair.emergency_craft.output_item=="copper-plate"
    and f.pair.emergency_craft.facility_only_0647==true,
    "first copper plates were not routed through physical furnace: "..tostring(why))
  check(f.source.get_item_count("copper-plate")==0,
    "copper plate was fabricated without any smelting")
  check(f.pair.infrastructure_recipe_request_0647
    and f.pair.infrastructure_recipe_request_0647.item=="burner-mining-drill",
    "copper smelting discarded parent drill dependency")
  -- A competing survey cannot interrupt the live furnace transaction.
  local task=f.pair.emergency_craft
  local again,reason=Infra.service_pair(f.pair,"still-smelting")
  check(f.pair.emergency_craft==task
    and task.facility_only_0647==true,
    "copper furnace task was replaced while still producing: "..tostring(reason))
end)

scenario("ten real copper plates are prerequisite for Factorio electronics trigger",function()
  local f=fixture()
  prototypes.item["copper-ore"]={}
  prototypes.item["copper-plate"]={}
  prototypes.item["electronic-circuit"]={}
  f.force.technologies={electronics={enabled=true,researched=false}}
  f.force.recipes["electronic-circuit"]={enabled=false,
    products={{name="electronic-circuit",type="item",amount=1}}}
  local miner={valid=true,type="assembling-machine",
    name="tech-priests-emergency-miner",unit_number=145,
    position={x=7,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,miner}
  end
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="copper-ore",count=3})
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=2}}}
  local survey=Infra.status_for_pair(f.pair)
  check(survey:find("needed=copper-plate",1,true),
    "unresearched electronics failed to prioritize real copper trigger: "..survey)
  local accepted,why=Infra.service_pair(f.pair,"electronics-copper-trigger")
  check(accepted and f.pair.emergency_craft
    and f.pair.emergency_craft.output_item=="copper-plate"
    and f.pair.emergency_craft.facility_only_0647==true
    and f.pair.emergency_craft.count==10,
    "ten plates were not requested through an actual furnace: "..tostring(why))
  check(f.source.get_item_count("copper-plate")==0
    and f.force.technologies.electronics.researched==false
    and f.force.recipes["electronic-circuit"].enabled==false,
    "bootstrap counterfeited copper plates or unlocked technology")
  f.source.insert({name="copper-plate",count=9})
  check(Infra.status_for_pair(f.pair):find("needed=copper-plate",1,true),
    "nine physically produced plates incorrectly satisfied ten-plate trigger")
  f.source.insert({name="copper-plate",count=1})
  -- In a game the engine marks electronics researched when the trigger
  -- completes; this test changes only its simulated force state.
  f.force.technologies.electronics.researched=true
  f.force.recipes["electronic-circuit"].enabled=true
  check(not Infra.status_for_pair(f.pair):find(
      "why=unlock-electronics-copper-trigger",1,true),
    "researched electronics still blocked progression on copper trigger")
end)

scenario("researched shared Electronics releases local ten-copper trigger",function()
  local f=fixture()
  prototypes.item["copper-plate"]={}
  prototypes.item["electronic-circuit"]={}
  f.force.technologies={electronics={enabled=true,researched=true}}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{type="item",name="electronic-circuit"}}}
  f.source.insert({name="copper-plate",count=1})
  local job={output_item="copper-plate",item_name="copper-plate",
    count=10,required_count=10,facility_only_0647=true,
    infrastructure_first_0640=true}
  f.pair.emergency_craft=job
  f.pair.local_infrastructure_gate_0640={item="copper-plate",
    why="unlock-electronics-copper-trigger",state="assigned-local-step"}
  local direct={kind="direct-mine-0336",output_item="coal",
    current={kind="direct-mine-0336",output_item="coal"}}
  f.pair.direct_acquisition_task_0336=direct
  f.pair.mode="travelling-to-direct-acquisition"
  Infra.service_pair(f.pair,"force-electronics-already-researched")
  check(f.pair.emergency_craft==nil
      and f.pair.local_infrastructure_gate_0640==nil,
    "finished force research left ten-plate copper task blocking circuits")
  check(f.source.get_item_count("copper-plate")==1
      and f.pair.direct_acquisition_task_0336==direct
      and f.pair.mode=="travelling-to-direct-acquisition",
    "research handoff consumed a real plate or stole movement/cargo")
  check(f.force.technologies.electronics.researched
      and f.source.get_item_count("electronic-circuit")==0,
    "research handoff spoofed technology or circuit production")
end)

scenario("researched Electronics retires later physical copper reserve",function()
  local f=fixture()
  prototypes.item["copper-plate"]={}
  prototypes.item["electronic-circuit"]={}
  f.force.technologies={electronics={enabled=true,researched=true}}
  f.force.recipes["electronic-circuit"]={enabled=true,
    products={{type="item",name="electronic-circuit"}}}
  f.source.insert({name="copper-plate",count=1})
  local job={output_item="copper-plate",item_name="copper-plate",
    count=4,required_count=4,facility_only_0647=true,
    infrastructure_first_0640=true}
  f.pair.emergency_craft=job
  f.pair.local_infrastructure_gate_0640={item="copper-plate",
    why="first-electronics-physical-copper-smelting",
    state="assigned-local-step"}
  local direct={kind="direct-mine-0336",output_item="coal",
    current={kind="direct-mine-0336",output_item="coal"}}
  f.pair.direct_acquisition_task_0336=direct
  f.pair.mode="travelling-to-direct-acquisition"
  Infra.service_pair(f.pair,"researched-circuit-hand-off")
  check(f.pair.emergency_craft==nil
      and f.pair.local_infrastructure_gate_0640==nil,
    "researched Electronics left later copper reserve blocking circuit")
  check(f.source.get_item_count("copper-plate")==1
      and f.pair.direct_acquisition_task_0336==direct
      and f.pair.mode=="travelling-to-direct-acquisition"
      and f.source.get_item_count("electronic-circuit")==0,
    "later reserve handoff consumed ingredients or overrode mining authority")
end)

scenario("unresearched later copper reserve cannot be retired",function()
  local f=fixture()
  prototypes.item["copper-plate"]={}
  f.force.technologies={electronics={enabled=true,researched=false}}
  f.pair.mode="travelling-to-direct-acquisition"
  local job={output_item="copper-plate",item_name="copper-plate",
    count=4,required_count=4,facility_only_0647=true,
    infrastructure_first_0640=true}
  f.pair.emergency_craft=job
  f.pair.local_infrastructure_gate_0640={item="copper-plate",
    why="first-electronics-physical-copper-smelting",
    state="assigned-local-step"}
  f.source.insert({name="copper-plate",count=1})
  Infra.service_pair(f.pair,"no-unearned-electronics")
  check(f.pair.emergency_craft==job and job.count==4
      and f.source.get_item_count("copper-plate")==1,
    "later reserve released before the game completed Electronics")
end)

scenario("copper trigger cannot close without research or physical plate",function()
  local f=fixture()
  prototypes.item["copper-plate"]={}
  f.force.technologies={electronics={enabled=true,researched=false}}
  f.pair.mode="travelling-to-direct-acquisition"
  local job={output_item="copper-plate",item_name="copper-plate",
    count=10,required_count=10,facility_only_0647=true,
    infrastructure_first_0640=true}
  f.pair.emergency_craft=job
  f.pair.local_infrastructure_gate_0640={item="copper-plate",
    why="unlock-electronics-copper-trigger",state="assigned-local-step"}
  f.source.insert({name="copper-plate",count=1})
  Infra.service_pair(f.pair,"no-premature-tech-credit")
  check(f.pair.emergency_craft==job and job.count==10,
    "unresearched copper trigger was prematurely retired")
  f.force.technologies.electronics.researched=true
  f.source.remove({name="copper-plate",count=1})
  Infra.service_pair(f.pair,"no-free-copper-completion")
  check(f.pair.emergency_craft==job and job.count==10
      and f.source.get_item_count("copper-plate")==0,
    "research completion without physical copper invented a stored plate")
end)

scenario("physical assembler retires obsolete recursive gear request after custody",function()
  local f=fixture()
  prototypes.item["electronic-circuit"]={}
  prototypes.item["copper-cable"]={}
  prototypes.item["copper-plate"]={}
  local original_ingredients=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="electronic-circuit" then
      return {{name="iron-plate",count=1},{name="copper-cable",count=3}}
    end
    return original_ingredients(item)
  end
  f.force.recipes["electronic-circuit"]={
    enabled=true,products={{name="electronic-circuit",type="item"}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=202,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler}
  end
  local obsolete={item="tech-priests-emergency-assembler",
    missing="iron-gear-wheel",
    ingredients={{name="iron-gear-wheel",count=1}}}
  -- A real post-Electronics workshop already has its first iron plate;
  -- absent that plate, the early physical miner bootstrap takes priority.
  f.source.insert({name="iron-plate",count=1})
  f.pair.infrastructure_recipe_request_0647=obsolete
  f.pair.requested_item="iron-gear-wheel"
  f.pair.logistic_requested_item="iron-gear-wheel"
  f.pair.logistic_requested_count=1
  f.pair.local_infrastructure_gate_0640={
    item="iron-gear-wheel",why="recipe-prerequisite",state="assigned-local-step"}
  local cargo={item="coal",count=1}
  f.pair.mode="direct-acquisition-returning-with-custody"
  f.pair.direct_acquisition_custody_0513=cargo
  Infra.service_pair(f.pair,"live-coal-custody")
  check(f.pair.infrastructure_recipe_request_0647==obsolete
    and f.pair.direct_acquisition_custody_0513==cargo,
    "obsolete request cleared while physical cargo still in custody")
  f.pair.direct_acquisition_custody_0513=nil
  f.pair.mode="idle"
  local accepted,reason=Infra.service_pair(f.pair,"assembled-machine-now-exists")
  check(accepted and reason=="requested-recipe-material",
    "constructed assembler did not resume legitimate Electronics prerequisites: "..
    tostring(reason).." "..Infra.status_for_pair(f.pair))
  local request=f.pair.infrastructure_recipe_request_0647
  check(request and request.item=="electronic-circuit"
      and request.missing=="copper-cable"
      and f.pair.requested_item=="copper-cable",
    "stale assembler gear request survived after verified construction")
  check(storage.tech_priests.infrastructure_first_governor_0640.stats["satisfied-built-facility-request-0640"]==1,
    "obsolete work was not reconciled against physical machine presence")
  check(f.source.get_item_count("iron-gear-wheel")==0
      and f.source.get_item_count("electronic-circuit")==0,
    "built-machine reconciliation fabricated a manufactured item")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=original_ingredients
end)

-- Manufacturing work inventories are not uncommitted general supply.
-- A stale three-cable station output must not satisfy the circuit recipe:
-- only chest/cache stock may release the physical copper-cable prerequisite.
scenario("electronics prerequisites exclude station manufacturing buffers",function()
  local f=fixture()
  prototypes.item["copper-cable"]={}
  prototypes.item["electronic-circuit"]={}
  f.force.recipes["copper-cable"]={
    enabled=true,products={{name="copper-cable",type="item"}}}
  f.force.recipes["electronic-circuit"]={
    enabled=true,products={{name="electronic-circuit",type="item"}}}
  f.source.insert({name="copper-plate",count=1})
  f.source.insert({name="iron-plate",count=1})
  local work_output=inventory({["copper-cable"]=3})
  local get_inventory=f.pair.station.get_inventory
  f.pair.station.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return work_output end
    return get_inventory(id)
  end
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=203,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local original_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return original_find(args) end
    return {f.furnace,assembler}
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="copper-cable" then
      return {{name="copper-plate",count=1}}
    elseif item=="electronic-circuit" then
      return {{name="iron-plate",count=1},{name="copper-cable",count=3}}
    end
    return previous(item)
  end
  f.pair.infrastructure_recipe_request_0647={
    item="electronic-circuit",missing="copper-cable",
    ingredients={{name="iron-plate",count=1},{name="copper-cable",count=3}}}
  f.pair.local_infrastructure_gate_0640={
    item="electronic-circuit",why="bootstrap-first-electronics",
    state="waiting-recipe-material",tick=game.tick,next_retry_tick=0}
  local ok,why=Infra.service_pair(f.pair,"work-buffer-is-not-stock")
  local task=f.pair.emergency_craft
  check(ok and why=="assigned-local-step" and task
      and task.output_item=="copper-cable"
      and task.strict_recipe_0647==true
      and task.target_stock_0647==3,
    "work output falsely satisfied copper-cable prerequisite: "..tostring(why))
  check(f.source.get_item_count("copper-cable")==0
      and work_output.get_item_count("copper-cable")==3
      and f.source.get_item_count("copper-plate")==1
      and f.source.get_item_count("electronic-circuit")==0,
    "planning consumed or manufactured physical electronics ingredients")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)

scenario("post-Electronics circuit iron prioritizes retrievable stock",function()
  local f=fixture()
  prototypes.item["electronic-circuit"]={}
  f.force.technologies={electronics={researched=true}}
  f.force.recipes["electronic-circuit"]={
    enabled=true,products={{name="electronic-circuit",type="item"}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=204,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler}
  end
  -- These engine-produced iron plates remain in the smelter output.
  -- They must not satisfy a separate circuit assembler's usable input.
  f.output.insert({name="iron-plate",count=3})
  local survey=Infra.status_for_pair(f.pair)
  check(survey:find("needed=iron-plate",1,true)
      and survey:find("why=first-electronics-physical-iron-smelting",1,true),
    "furnace-held iron incorrectly skipped circuit prerequisite: "..survey)
  local ok,why=Infra.service_pair(f.pair,"first-circuit-reserved-iron")
  local task=f.pair.emergency_craft
  check(ok and why=="assigned-local-step" and task
      and task.output_item=="iron-plate"
      and task.facility_only_0647==true
      and task.count==1,
    "post-research first circuit did not schedule one real iron smelt")
  check(f.source.get_item_count("iron-plate")==0
      and f.output.get_item_count("iron-plate")==3
      and f.source.get_item_count("iron-ore")
        + f.input.get_item_count("iron-ore")==8
      and f.source.get_item_count("electronic-circuit")==0
      and f.input.get_item_count("iron-plate")==0,
    "reservation lost iron ore across station and furnace, or forged an ingredient"..
      " station_iron="..f.source.get_item_count("iron-plate")..
      " furnace_result_iron="..f.output.get_item_count("iron-plate")..
      " station_ore="..f.source.get_item_count("iron-ore")..
      " furnace_ore="..f.input.get_item_count("iron-ore")..
      " station_circuit="..f.source.get_item_count("electronic-circuit"))
end)

scenario("built research lab schedules engine-only physical science",function()
  local f=fixture()
  prototypes.item["automation-science-pack"]={}
  prototypes.item["electronic-circuit"]={}
  f.force.technologies={electronics={researched=true}}
  f.force.recipes["automation-science-pack"]={
    enabled=true,products={{name="automation-science-pack",type="item"}}}
  f.source.insert({name="electronic-circuit",count=1})
  -- Earlier physical emergency-miner bootstrap must already be satisfied.
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="iron-gear-wheel",count=1})
  f.source.insert({name="copper-plate",count=1})
  -- Keep an old normal-drill stone-furnace request and an unladen direct
  -- acquisition route. Both are lower priority than real first science.
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="stone-furnace",
    ingredients={{name="stone-furnace",count=1}}}
  f.pair.mode="travelling-to-direct-acquisition"
  local old_direct={kind="direct-mine-0336",output_item="stone",
    current={kind="direct-mine-0336",output_item="stone"}}
  f.pair.direct_acquisition_task_0336=old_direct
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=204,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local lab={valid=true,type="lab",name="tech-priests-emergency-laboratorium",
    unit_number=205,position={x=7,y=0},force=f.force,surface=f.surface}
  local previous_find=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return previous_find(args) end
    return {f.furnace,assembler,lab}
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="automation-science-pack" then
      return {{name="copper-plate",count=1},{name="iron-gear-wheel",count=1}}
    end
    return previous(item)
  end
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=automation-science-pack",1,true)
    and status:find("why=first-physical-science-pack",1,true),
    "built laboratory did not prioritize physical science: "..status)
  local ok,why=Infra.service_pair(f.pair,"physical-science-prerequisite")
  local task=f.pair.emergency_craft
  check(ok and why=="assigned-local-step" and task
      and task.output_item=="automation-science-pack"
      and task.strict_recipe_0647==true
      and task.facility_only_0647==true
      and f.pair.direct_acquisition_task_0336==old_direct,
    "science was not assigned without deleting older physical acquisition: "..tostring(why))
  check(f.source.get_item_count("automation-science-pack")==0
      and f.source.get_item_count("iron-gear-wheel")==1
      and f.source.get_item_count("copper-plate")==1,
    "science assignment fabricated output or consumed unclaimed ingredients")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)

scenario("vanilla science trigger requires an actually crafted normal lab",function()
  local f=fixture()
  prototypes.item["lab"]={place_result={name="lab"}}
  prototypes.item["transport-belt"]={}
  prototypes.item["automation-science-pack"]={}
  f.force.technologies={electronics={researched=true},
    ["automation-science-pack"]={enabled=true,researched=false}}
  f.force.recipes["automation-science-pack"]={enabled=false,
    products={{name="automation-science-pack",type="item"}}}
  f.force.recipes["lab"]={enabled=true,
    products={{name="lab",type="item"}}}
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="iron-gear-wheel",count=10})
  f.source.insert({name="electronic-circuit",count=10})
  f.source.insert({name="transport-belt",count=4})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=266,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local lab={valid=true,type="lab",name="tech-priests-emergency-laboratorium",
    unit_number=267,position={x=7,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler,lab}
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="lab" then
      return {{name="iron-gear-wheel",count=10},
        {name="electronic-circuit",count=10},
        {name="transport-belt",count=4}}
    end
    return previous(item)
  end
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="stone-furnace",
    ingredients={{name="stone-furnace",count=1}}}
  f.pair.mode="travelling-to-direct-acquisition"
  local survey=Infra.status_for_pair(f.pair)
  check(survey:find("needed=lab",1,true)
      and survey:find("why=unlock-first-science-by-physical-vanilla-lab",1,true),
    "research trigger was silently bypassed by emergency lab: "..survey)
  local ok,why=Infra.service_pair(f.pair,"physically-craft-vanilla-lab")
  local task=f.pair.emergency_craft
  check(ok and why=="assigned-local-step" and task
      and task.output_item=="lab"
      and task.strict_recipe_0647==true
      and task.facility_only_0647==true,
    "normal lab trigger was not assigned actual engine manufacture: "..tostring(why))
  check(f.source.get_item_count("lab")==0
      and f.source.get_item_count("automation-science-pack")==0
      and f.force.technologies["automation-science-pack"].researched==false
      and f.force.recipes["automation-science-pack"].enabled==false,
    "normal laboratory stage counterfeited the trigger or unlocked science")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)

scenario("carried raw material blocks science priority preemption",function()
  local f=fixture()
  prototypes.item["automation-science-pack"]={}
  prototypes.item["lab"]={place_result={name="lab"}}
  f.force.technologies={electronics={researched=true},
    ["automation-science-pack"]={researched=false,enabled=true}}
  f.force.recipes["lab"]={enabled=true,
    products={{name="lab",type="item"}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=299,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local lab={valid=true,type="lab",name="tech-priests-emergency-laboratorium",
    unit_number=300,position={x=7,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler,lab}
  end
  f.source.insert({name="iron-plate",count=1})
  local held={item="stone",count=3}
  f.pair.direct_acquisition_custody_0513=held
  f.pair.mode="travelling-to-direct-acquisition"
  local oldtask={kind="direct-mine-0336",output_item="stone",
    current={kind="direct-mine-0336",output_item="stone"}}
  f.pair.direct_acquisition_task_0336=oldtask
  local before=f.source.get_item_count("iron-ore")
  local ok,why=Infra.service_pair(f.pair,"protect-carried-stone-before-science")
  check(not ok and f.pair.direct_acquisition_custody_0513==held
      and f.pair.direct_acquisition_task_0336==oldtask
      and f.pair.mode=="travelling-to-direct-acquisition"
      and f.source.get_item_count("lab")==0
      and f.source.get_item_count("automation-science-pack")==0
      and f.source.get_item_count("iron-ore")==before,
    "laboratory/science priority stole raw cargo or fabricated research materials: "..
      tostring(why))
end)

scenario("green science follows engine crafting and real red stock",function()
  local f=fixture()
  prototypes.item["automation-science-pack"]={}
  prototypes.item["logistic-science-pack"]={}
  prototypes.item["inserter"]={}
  prototypes.item["transport-belt"]={}
  f.force.technologies={electronics={researched=true},
    ["logistic-science-pack"]={enabled=true,researched=false}}
  f.force.recipes["automation-science-pack"]={
    enabled=true,products={{name="automation-science-pack",type="item"}}}
  f.force.recipes["logistic-science-pack"]={
    enabled=true,products={{name="logistic-science-pack",type="item"}}}
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="inserter",count=1})
  f.source.insert({name="transport-belt",count=1})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=540,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local lab_input=inventory({["automation-science-pack"]=2})
  defines.inventory.lab_input=9
  local lab={valid=true,type="lab",name="tech-priests-emergency-laboratorium",
    unit_number=541,position={x=7,y=0},force=f.force,surface=f.surface}
  lab.get_inventory=function(id)
    if id==defines.inventory.lab_input then return lab_input end
  end
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler,lab}
  end
  storage.tech_priests.emergency_facility_doctrine_0343={
    facilities={["lab-541"]={role="lab",entity=lab}},
    by_station={[11]={["lab-541"]=true}}}
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="logistic-science-pack" then
      return {{name="inserter",count=1},{name="transport-belt",count=1}}
    end
    return previous(item)
  end
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=logistic-science-pack",1,true)
      and status:find("why=first-physical-green-science",1,true),
    "engine-enabled green crafting was hidden: "..status)
  local ok,why=Infra.service_pair(f.pair,"craft-engine-enabled-green")
  local task=f.pair.emergency_craft
  check(ok and why=="assigned-local-step" and task
      and task.output_item=="logistic-science-pack"
      and task.facility_only_0647==true
      and task.strict_recipe_0647==true,
    "green science did not require an actual workshop craft: "..tostring(why))
  check(f.source.get_item_count("logistic-science-pack")==0
      and f.source.get_item_count("inserter")==1
      and f.source.get_item_count("transport-belt")==1
      and lab_input.get_item_count("automation-science-pack")==2
      and f.force.technologies["logistic-science-pack"].researched==false,
    "green manufacturing assignment invented science or consumed research")
  -- Disable the recipe in the force: no planner may bypass that engine gate.
  f.pair.emergency_craft=nil
  f.pair.local_infrastructure_gate_0640=nil
  f.pair.infrastructure_recipe_request_0647=nil
  f.force.recipes["logistic-science-pack"].enabled=false
  local blocked=Infra.status_for_pair(f.pair)
  check(not blocked:find("needed=logistic-science-pack",1,true),
    "engine-disabled green recipe was treated as craftable: "..blocked)
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)


-- An engine-owned assembler cannot retrieve intermediary items held in the
-- Cogitator's unrelated manufacturing output inventory. In particular the
-- ordinary lab recipe must not treat ten stranded gears as ready materials.
scenario("vanilla lab requires retrievable gear stock, not work-buffer gears",function()
  local f=fixture()
  prototypes.item["lab"]={place_result={name="lab"}}
  prototypes.item["electronic-circuit"]={}
  prototypes.item["transport-belt"]={}
  f.force.technologies={electronics={researched=true},
    ["automation-science-pack"]={enabled=true,researched=false}}
  f.force.recipes["lab"]={
    enabled=true,products={{name="lab",type="item"}}}
  local work=inventory({["iron-gear-wheel"]=10})
  local station_inventory=f.pair.station.get_inventory
  f.pair.station.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return work end
    return station_inventory(id)
  end
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="electronic-circuit",count=10})
  f.source.insert({name="transport-belt",count=4})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=660,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local laboratory={valid=true,type="lab",
    name="tech-priests-emergency-laboratorium",unit_number=661,
    position={x=7,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler,laboratory}
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="lab" then return {
      {name="iron-gear-wheel",count=10},
      {name="electronic-circuit",count=10},
      {name="transport-belt",count=4}}
    end
    return previous(item)
  end
  local acted,reason=Infra.service_pair(f.pair,"lab-gears-held-in-work-buffer")
  local pending=f.pair.infrastructure_recipe_request_0647
  check(acted and reason=="requested-recipe-material"
      and pending and pending.item=="lab"
      and pending.missing=="iron-gear-wheel"
      and f.pair.requested_item=="iron-gear-wheel"
      and f.source.get_item_count("lab")==0,
    "unusable work-buffer gears incorrectly satisfied the vanilla lab recipe: "..
      tostring(reason))
  -- When ten actual gears reach general stock, the real engine recipe can
  -- be scheduled; the governor must not manufacture a laboratory itself.
  f.source.insert({name="iron-gear-wheel",count=10})
  f.pair.local_infrastructure_gate_0640=nil
  f.pair.mode="idle"
  local resumed,detail=Infra.service_pair(f.pair,"lab-gears-recovered")
  check(resumed and detail=="assigned-local-step"
      and f.pair.emergency_craft
      and f.pair.emergency_craft.output_item=="lab"
      and f.pair.emergency_craft.strict_recipe_0647==true
      and f.source.get_item_count("lab")==0
      and work.get_item_count("iron-gear-wheel")==10,
    "real gear delivery did not resume the physical lab recipe: "..tostring(detail))
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)

scenario("red science requires transferable copper, not a furnace output",function()
  local f=fixture()
  prototypes.item["automation-science-pack"]={}
  f.force.technologies={electronics={researched=true}}
  f.force.recipes["automation-science-pack"]={
    enabled=true,products={{name="automation-science-pack",type="item"}}}
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="iron-gear-wheel",count=1})
  f.output.insert({name="copper-plate",count=3})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=662,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local lab={valid=true,type="lab",name="tech-priests-emergency-laboratorium",
    unit_number=663,position={x=7,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler,lab}
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="automation-science-pack" then return {
      {name="copper-plate",count=1},
      {name="iron-gear-wheel",count=1}}
    end
    return previous(item)
  end
  local acted,reason=Infra.service_pair(f.pair,"science-copper-in-furnace-only")
  local pending=f.pair.infrastructure_recipe_request_0647
  check(acted and reason=="requested-recipe-material"
      and pending and pending.item=="automation-science-pack"
      and pending.missing=="copper-plate"
      and f.source.get_item_count("automation-science-pack")==0
      and f.output.get_item_count("copper-plate")==3,
    "inaccessible furnace output falsely satisfied science copper: "..
      tostring(reason))
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)


scenario("vanilla science trigger can start before emergency lab construction",function()
  local f=fixture()
  prototypes.item["lab"]={place_result={name="lab"}}
  prototypes.item["automation-science-pack"]={}
  f.force.technologies={electronics={researched=true},
    ["automation-science-pack"]={enabled=true,researched=false}}
  f.force.recipes["lab"]={enabled=true,
    products={{name="lab",type="item"}}}
  f.force.recipes["automation-science-pack"]={enabled=false,
    products={{name="automation-science-pack",type="item"}}}
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="iron-gear-wheel",count=10})
  f.source.insert({name="electronic-circuit",count=10})
  f.source.insert({name="transport-belt",count=4})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=664,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler} -- Deliberately no laboratory yet.
  end
  local oldtask={kind="direct-mine-0336",output_item="stone"}
  f.pair.direct_acquisition_task_0336=oldtask
  f.pair.mode="travelling-to-direct-acquisition"
  f.pair.infrastructure_recipe_request_0647={
    item="burner-mining-drill",missing="stone-furnace",
    ingredients={{name="stone-furnace",count=1}}}
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="lab" then return {
      {name="iron-gear-wheel",count=10},
      {name="electronic-circuit",count=10},
      {name="transport-belt",count=4}}
    end
    return previous(item)
  end
  local status=Infra.status_for_pair(f.pair)
  check(status:find("needed=lab",1,true)
      and status:find("why=unlock-first-science-by-physical-vanilla-lab",1,true),
    "vanilla science unlock incorrectly required an emergency lab: "..status)
  local ok,reason=Infra.service_pair(f.pair,"vanilla-lab-first")
  check(ok and reason=="assigned-local-step"
      and f.pair.emergency_craft
      and f.pair.emergency_craft.output_item=="lab"
      and f.pair.emergency_craft.strict_recipe_0647==true
      and f.pair.emergency_craft.facility_only_0647==true
      and f.pair.direct_acquisition_task_0336==oldtask,
    "legitimate vanilla lab recipe was delayed or stole existing custody: "..
      tostring(reason))
  check(f.source.get_item_count("lab")==0
      and f.source.get_item_count("automation-science-pack")==0
      and f.force.technologies["automation-science-pack"].researched==false,
    "early vanilla lab planning granted an item or science unlock")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)


scenario("unfinished vanilla lab does not starve emergency laboratory bootstrap",function()
  local f=fixture()
  prototypes.item["lab"]={place_result={name="lab"}}
  prototypes.item["electronic-circuit"]={}
  prototypes.item["transport-belt"]={}
  prototypes.item["automation-science-pack"]={}
  f.force.technologies={electronics={researched=true},
    ["automation-science-pack"]={enabled=true,researched=false}}
  f.force.recipes["lab"]={
    enabled=true,products={{name="lab",type="item"}}}
  f.force.recipes["automation-science-pack"]={
    enabled=false,products={{name="automation-science-pack",type="item"}}}
  f.source.insert({name="iron-plate",count=1})
  f.source.insert({name="iron-gear-wheel",count=9})
  f.source.insert({name="electronic-circuit",count=1})
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=665,
    position={x=6,y=0},force=f.force,surface=f.surface}
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler} -- No completed laboratory.
  end
  local previous=_G.tech_priests_get_recipe_ingredients_for_item_0185
  _G.tech_priests_get_recipe_ingredients_for_item_0185=function(item)
    if item=="lab" then return {
      {name="iron-gear-wheel",count=10},
      {name="electronic-circuit",count=10},
      {name="transport-belt",count=4}}
    end
    return previous(item)
  end
  local status=Infra.status_for_pair(f.pair)
  check(not status:find("needed=lab",1,true)
      and f.force.technologies["automation-science-pack"].researched==false,
    "incomplete expensive vanilla lab preempted emergency lab: "..status)
  check(f.source.get_item_count("lab")==0,
    "incomplete recipe obtained a vanilla laboratory")
  _G.tech_priests_get_recipe_ingredients_for_item_0185=previous
end)


scenario("incompatible workshop blocks fallback until a real pressing craft completes",function()
  local f=fixture()
  prototypes.item["transport-belt"]={}
  prototypes.recipe=prototypes.recipe or {}
  prototypes.recipe["transport-belt"]={
    category="pressing",ingredients={
      {name="iron-plate",type="item",amount=1},
      {name="iron-gear-wheel",type="item",amount=1}}}
  f.force.recipes["transport-belt"]={enabled=true,
    products={{name="transport-belt",type="item"}}}
  f.source.insert({name="iron-gear-wheel",count=2})
  f.source.insert({name="iron-plate",count=2})
  local input,output=inventory(),inventory()
  local selected,attempts=nil,0
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=772,
    position={x=6,y=0},force=f.force,surface=f.surface,
    prototype={crafting_categories={crafting=true,electronics=true}}}
  assembler.get_recipe=function()
    return selected and {name=selected,
      ingredients=prototypes.recipe[selected].ingredients} or nil
  end
  assembler.set_recipe=function(recipe)
    selected=recipe;attempts=attempts+1;return true
  end
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local oldfind=f.surface.find_entities_filtered
  f.surface.find_entities_filtered=function(args)
    if args.type=="resource" then return oldfind(args) end
    return {f.furnace,assembler}
  end
  check(F.tag_built_entity(f.pair,assembler,"owned-recipe-compatibility"),
    "physical workshop not registered")
  f.pair.emergency_craft={item_name="transport-belt",
    output_item="transport-belt",count=1,strict_recipe_0647=true,
    strict_recipe_ingredients_0647={{name="iron-plate",count=1},
      {name="iron-gear-wheel",count=1}},
    facility_only_0647=true,infrastructure_first_0640=true}
  local bad,why=Production.service_pair(f.pair,"incompatible-pressing")
  check(not bad and why=="incompatible-machine:incompatible-crafting-category:pressing",
    "capability blocker lost to generic facility/fallback: "..tostring(why))
  check(f.pair.dispatcher_emergency_production_0514.phase=="need-compatible-machine"
      and attempts==0 and not f.pair.emergency_production_custody_0514
      and f.source.get_item_count("iron-gear-wheel")==2
      and f.source.get_item_count("transport-belt")==0,
    "incompatible engine recipe removed materials or manufactured a belt")
  assembler.prototype.crafting_categories.pressing=true
  game.tick=game.tick+10
  local resumed,detail=Production.service_pair(f.pair,"real-press-capable")
  check(resumed and detail=="used-owned-facilities" and selected=="transport-belt"
      and attempts==1 and input.get_item_count("iron-gear-wheel")==1
      and input.get_item_count("iron-plate")==1
      and f.source.get_item_count("transport-belt")==0,
    "physical workshop did not recover from explicit category blocker: "..
      tostring(detail))
  -- This explicitly represents a mock engine finishing the real recipe;
  -- the production executor must collect its machine output, not create it.
  output.insert({name="transport-belt",count=1})
  game.tick=game.tick+1
  local finished,finish_reason=Production.service_pair(f.pair,"collect-real-belt")
  check(finished and finish_reason=="complete"
      and f.source.get_item_count("transport-belt")==1
      and output.get_item_count("transport-belt")==0
      and f.pair.emergency_craft==nil
      and not f.pair.emergency_production_custody_0514,
    "finished real belt batch not conserved/acknowledged: "..tostring(finish_reason))
end)

print("[bootstrap-production-regression] PASS scenarios="..total)
