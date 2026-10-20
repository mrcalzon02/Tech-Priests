-- Plain Lua 5.2 regression for the 0649 guard and 0637 recovery contract.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path

game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1}}
prototypes={item={["iron-ore"]={}}}
local Guard=require("scripts.core.direct_acquisition_physical_guard_0649")
local Bootstrap=require("scripts.core.bootstrap_resource_governor_0637")
_G.TechPriestsDirectAcquisitionExecutor0513=nil

local function check(ok,why)
  if not ok then error("physical-guard regression: "..why,2) end
end
local resource={valid=true,name="iron-ore",type="resource",amount=100,position={x=4,y=0}}
local function pair()
  storage={tech_priests={pairs_by_station={}}}
  local inv={valid=true,get_item_count=function()return 0 end}
  local surface={index=1,name="nauvis"}
  function surface.find_entities_filtered(filter)
    if filter.type=="resource" and filter.name=="iron-ore" then return {resource} end
    return {}
  end
  local station={valid=true,unit_number=1,name="test-station",
    position={x=0,y=0},surface=surface,force={index=1}}
  station.get_inventory=function() return inv end
  local priest={valid=true,unit_number=2,name="test-priest",position={x=0,y=0}}
  local p={station=station,priest=priest,station_unit=1,priest_unit=2,
    radius=12,mode="direct-acquisition-working"}
  storage.tech_priests.pairs_by_station[1]=p
  return p
end
local function stale()
  return {kind="direct-mine-0336",output_item="iron-ore",bootstrap_resource_0637=true,
    current={kind="direct-mine-0336",output_item="iron-ore",position={x=120,y=120}}}
end
local count=0
local function scenario(label,test)
  test();count=count+1
  print("[physical-guard-regression] PASS "..label)
end

scenario("stale direct root retires every matching alias",function()
  local p=pair();local task=stale()
  p.emergency_craft=task;p.direct_acquisition_task_0336=task
  local ok,why=Guard.guard_pair(p,"regression")
  check(ok and why=="cleared-stale-target","stale root not rejected")
  check(p.emergency_craft==nil and p.direct_acquisition_task_0336==nil,
    "abandoned direct root remained active after removing current")
  check(task.current==nil,"stale child not removed")
end)

scenario("retired task allows fresh raw acquisition assignment",function()
  local p=pair();local task=stale()
  p.emergency_craft=task;p.direct_acquisition_task_0336=task
  Guard.guard_pair(p,"stale")
  Bootstrap.root().enabled=true
  -- This tests admission and target selection; the direct executor owns execution.
  package.loaded["scripts.core.direct_acquisition_executor_0513"]={
    service_pair=function()return true,"mock-dispatch" end}
  local ok,why=Bootstrap.service_pair(p,"recover")
  check(ok and why=="assigned","resource governor failed to recover: "..tostring(why))
  check(p.direct_acquisition_task_0336~=task,"reused stale root")
  check(p.direct_acquisition_task_0336.current.entity==resource,"new task lacks physical target")
end)

scenario("parent manufacturing order survives a stale direct child",function()
  local p=pair();local parent={kind="crafting",item_name="iron-gear-wheel",current=stale().current}
  p.emergency_craft=parent
  check(Guard.guard_pair(p,"child"),"stale child not detected")
  check(p.emergency_craft==parent and parent.current==nil,
    "unrelated manufacturing parent was discarded")
end)

scenario("higher priority order and target are not clobbered",function()
  local p=pair();local task=stale()
  local other={valid=true,name="repair-target",type="assembling-machine",position={x=1,y=1}}
  p.direct_acquisition_task_0336=task
  p.target=other;p.mode="repairing"
  p.order_queue_0469={current={kind="repair",status="active"}}
  check(Guard.guard_pair(p,"preempted-direct"),"stale preempted mining task not cleared")
  check(p.target==other and p.mode=="repairing","physical guard overwrote active repair")
  check(p.direct_acquisition_task_0336==nil,"preempted stale direct task remained")
end)


scenario("parent-only physical item resolves and deposits exact ore",function()
  package.loaded["scripts.core.direct_acquisition_executor_0513"]=nil
  local Direct=require("scripts.core.direct_acquisition_executor_0513")
  local p=pair()
  p.priest.position={x=1,y=0}
  local e={valid=true,name="iron-ore",type="resource",amount=3,
    position={x=1,y=0},surface=p.station.surface}
  p.emergency_craft={output_item="iron-ore",
    current={kind="direct-mine-0336",entity=e}}
  local deposits,stops=0,0
  _G.tech_priests_stop_movement_0418=function()stops=stops+1;return true end
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    check(item=="iron-ore" and count==1,"unexpected physical deposit")
    deposits=deposits+count
    return true,"deposited",count
  end
  local ok,why=Direct.service_pair(p,"parent-only-item")
  check(ok==true and why=="working","parent-only item rejected: "..tostring(why))
  check(e.amount==3 and p.dispatcher_phase=="work-target",
    "physical ore changed before extraction completed")
  game.tick=game.tick+100
  ok,why=Direct.service_pair(p,"finish-parent-only-item")
  check(ok==true and why=="complete","physical completion failed: "..tostring(why))
  check(e.amount==2 and deposits==1 and p.direct_acquisition_custody_0513==nil,
    "physical extraction, station deposit or custody clearing was untruthful")
  check(stops>=2,"work clamp was not acquired")
end)

scenario("child item mismatch fails before physical mutation",function()
  local Direct=require("scripts.core.direct_acquisition_executor_0513")
  local p=pair()
  p.priest.position={x=1,y=0}
  prototypes.item["copper-ore"]={}
  local e={valid=true,name="iron-ore",type="resource",amount=3,
    position={x=1,y=0},surface=p.station.surface}
  p.emergency_craft={output_item="iron-ore",
    current={kind="direct-mine-0336",entity=e,output_item="copper-ore"}}
  local ok,why=Direct.service_pair(p,"mismatched-child-item")
  check(ok==false and tostring(why):find("physical-output-mismatch",1,true),
    "mismatched child output did not fail closed: "..tostring(why))
  check(e.amount==3 and p.direct_acquisition_custody_0513==nil,
    "mismatched output removed ore or created custody")
end)

print("[physical-guard-regression] PASS scenarios="..count)
