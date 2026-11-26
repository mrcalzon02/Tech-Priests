-- Actual 0644 caller with dense native-shaped membership and live inventory.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,lab_input=2}}
local calls={query=0,stock=0,products=0}
local stock={stone=5,["automation-science-pack"]=1}
local force={object_name="LuaForce",valid=true,index=1,name="player",recipes={},technologies={}}
local surface={object_name="LuaSurface",valid=true,index=1,name="nauvis"}
local neutral={object_name="LuaForce",valid=true,index=3,name="neutral"}
prototypes={item={},entity={}}
local all={}
local function add(kind,name,x,y,unit,owner)
  local e={object_name="LuaEntity",valid=true,type=kind,name=name,unit_number=unit,
    position={x=x,y=y},force=owner or force,surface=surface}
  all[#all+1]=e;return e
end
local inv={object_name="LuaInventory",valid=true,get_item_count=function(item)calls.stock=calls.stock+1;return stock[item]or 0 end}
local station=add("container","junior-cogitator-station",0,0,1)
station.get_inventory=function(id)return id==1 and inv end
local priest=add("unit","tech-priest",0,1,2)
local pair={station=station,priest=priest,station_unit=1,radius=36}
storage.tech_priests.pairs_by_station[1]=pair
for i=1,512 do
  local e=add("container","wooden-chest",(i-1)%16+.5,math.floor((i-1)/16)+.5,100+i)
  e.get_inventory=function()return{valid=true,get_item_count=function()calls.stock=calls.stock+1;return 0 end}end
end
add("resource","iron-ore",-3,-3,nil,neutral).amount=1000
local lab=add("lab","lab",3,-3,900)
lab.prototype={lab_inputs={"automation-science-pack"}}
lab.get_inventory=function()return{valid=true,get_item_count=function()calls.stock=calls.stock+1;return 0 end}end
surface.can_place_entity=function()return true end
surface.find_entities_filtered=function(filter)
  calls.query=calls.query+1
  assert(filter.area and filter.limit and filter.limit<=16,"broad query escaped work budget")
  local out={};local kinds={};for _,k in ipairs(filter.type)do kinds[k]=true end
  local a,b=filter.area[1],filter.area[2]
  for _,e in ipairs(all)do
    if e.valid and kinds[e.type]and(not filter.force or e.force==filter.force)
      and e.position.x>=a[1]and e.position.x<b[1]and e.position.y>=a[2]and e.position.y<b[2]then
      out[#out+1]=e;if #out==filter.limit then break end
    end
  end
  return out
end
local cells={}
for _,e in ipairs(all)do
  local k=math.floor(e.position.x/32)..":"..math.floor(e.position.y/32)
  cells[k]=cells[k]or{known_tick=1000,entities={}}
  cells[k].entities[e.unit_number or 9999]=e
end
storage.tech_priests.efficiency_economy_0579={enabled=true,surfaces={["1"]={cells=cells,dirty={}}}}
local function recipe(name,item,ingredients)
  force.recipes[name]=setmetatable({name=name,valid=true,enabled=true,ingredients=ingredients or{},object_name="LuaRecipe"},
    {__index=function(_,key)if key=="products"then calls.products=calls.products+1;return{{name=item}}end end})
end
for i=1,200 do recipe("unused"..i,"unused"..i)end
recipe("stone-furnace","stone-furnace",{{name="stone",amount=5}})
recipe("tech-priests-emergency-smelter","tech-priests-emergency-smelter",{{name="iron-plate",amount=1}})
for i=1,180 do
  local name=string.format("research-%03d",i)
  force.technologies[name]={valid=true,enabled=true,researched=false,name=name,prerequisites={},
    research_unit_ingredients={{name="automation-science-pack",amount=1}},research_unit_count=i}
end
local P=require("scripts.core.master_infrastructure_plan_0644")
local Q=require("scripts.core.force_planning_queue")
local plan,why=P.build_plan(pair,"large-single-factory")
assert(not plan and why=="planning-pending"and calls.query==0 and calls.stock==0 and calls.products==0,
  "caller advanced expensive planning")
for i=1,30 do P.build_plan(pair,"repeated caller")end
assert(calls.query==0 and calls.products==0,"duplicate requests executed work")
local idle=0
Q.register("busy-work",function()idle=idle+1;return{processed=0}end)
Q.submit(2,"busy-work","no-action")
local function pulse(offered)
  game.tick=game.tick+5
  local q,n=calls.query,calls.stock
  local r=Q.pulse({tick=game.tick},offered or 16)
  assert(r.processed<=16 and calls.query-q<=16 and calls.stock-n<=16,"unbounded inner work")
  return r
end
for i=1,30 do pulse()end
local function clone(v,seen)
  if type(v)~="table"then assert(type(v)~="thread"and type(v)~="function");return v end
  if v.object_name then return v end
  seen=seen or{};if seen[v]then return seen[v]end
  local out={};seen[v]=out;for k,x in pairs(v)do out[clone(k,seen)]=clone(x,seen)end;return out
end
storage=clone(storage);pair=storage.tech_priests.pairs_by_station[1]
for _,name in ipairs({"master_infrastructure_plan_0644","infrastructure_continuation_1507","force_planning_queue","planning_metadata_1507","bounded_planning_area_1507"})do package.loaded["scripts.core."..name]=nil end
P=require("scripts.core.master_infrastructure_plan_0644");Q=require("scripts.core.force_planning_queue")
Q.register("busy-work",function()idle=idle+1;return{processed=0}end)
for i=1,5000 do pulse();plan=P.build_plan(pair,"resume");if plan then break end end
assert(plan,"dense continuation failed to finish")
assert(plan.target.preferred_item=="stone-furnace"and plan.target.feasibility=="ingredients-stocked","doctrine/stock selection changed")
assert(plan.research_candidate=="research-001","cheapest physical science lost")
assert(plan.resources["iron-ore"]and idle>100,"neutral resource or no-action fairness lost")
assert(calls.products==202,"shared product membership repeatedly rebuilt")
assert(pair.priest==priest and priest.valid,"original priest replaced")
-- Change stock after the lengthy world/recipe/science assessment has already
-- selected a target. The final bounded recount must change that selection.
plan=nil;P.build_plan(pair,"stock-spent")
local reached_final=false
for i=1,20000 do
  pulse(1)
  local job=Q.peek(1,"infrastructure-survey","1")
  if job and job.state.phase=="refresh-stock"then reached_final=true;break end
end
assert(reached_final,"did not reach final stock check")
stock.stone=0;stock["iron-plate"]=1;stock["automation-science-pack"]=0
for i=1,5000 do pulse();plan=P.build_plan(pair,"stock-spent");if plan then break end end
assert(plan and plan.target.preferred_item=="tech-priests-emergency-smelter","stale ingredient counts survived final recount")
assert(not plan.research_candidate,"spent science packs survived final validation")
-- A completed but unconsumed proposal also loses authority after a world edit.
P.build_plan(pair,"late-world-edit")
local ready
for i=1,5000 do pulse();ready=Q.peek(1,"infrastructure-survey","1");if ready and ready.status=="ready"then break end end
assert(ready and ready.status=="ready"and ready.result.plan)
local Area=require("scripts.core.bounded_planning_area_1507")
Area.note_entity({entity=lab})
assert(not P.plan_current(pair,ready.result.plan),"edited world retained published authority")
local rejected,why=P.build_plan(pair,"late-world-edit")
assert(not rejected and why=="planning-pending","late world edit consumed a stale result")
-- Relocation while suspended cannot publish the old domain's plan.
P.build_plan(pair,"relocation");pulse();station.position={x=100,y=100}
local stale=P.build_plan(pair,"relocation");assert(not stale,"relocated station consumed stale plan")
assert(Q.root().stats.failures==0,"hidden handler fault")
print("infrastructure_continuation_1507 PASS: actual caller, dense factory, bounded queries/rows/stock/recipes/science, reload, fairness, live stock, relocation")
