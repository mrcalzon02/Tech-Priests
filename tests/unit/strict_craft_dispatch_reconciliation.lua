-- Lua 5.2: canonical 0488/0510 strict craft versus direct-acquisition ownership.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=16000}
storage={tech_priests={pairs_by_station={}}}
local counts={craft=0,direct=0,stops=0,repair=0}
local physical={valid=true,name="iron-ore",type="resource",
  unit_number=90,position={x=8,y=0},surface={index=1}}
local function make_pair()
  storage={tech_priests={pairs_by_station={}}}
  counts={craft=0,direct=0,stops=0,repair=0}
  local surface={index=1,name="nauvis"}
  local force={index=1,name="player"}
  local station={valid=true,name="junior-cogitator-station",unit_number=11,
    position={x=0,y=0},surface=surface,force=force}
  local priest={valid=true,name="priest",unit_number=12,
    position={x=8,y=0},surface=surface,force=force}
  local p={station=station,priest=priest,mode="direct-acquisition-working",
    station_unit=11,priest_unit=12}
  storage.tech_priests.pairs_by_station[11]=p
  return p
end
local Arbiter=require("scripts.core.action_state_arbiter_0488")
local Dispatcher=require("scripts.core.single_dispatcher_0510")
_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488=Arbiter
_G.TechPriestsEmergencyProductionExecutor0514={
  service_pair=function()counts.craft=counts.craft+1;return true,"station-craft" end}
_G.TechPriestsDirectAcquisitionExecutor0513={
  current_direct_task=function(p)
    local t=p.direct_acquisition_task_0336
    return t,t and t.current,"direct_acquisition_task_0336"
  end,
  service_pair=function()counts.direct=counts.direct+1;return true,"working"end,
}
_G.TechPriestsRepairExecutor0516={service_pair=function()
  counts.repair=counts.repair+1;return true,"repair"end}
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={
  request_status=function(p)
    return p.movement_request_0418 and {active=true,owner=p.movement_request_0418.owner}
      or {active=false}
  end,
  stop=function(p)
    counts.stops=counts.stops+1;p.movement_request_0418=nil;return true
  end
}
local total=0
local function check(ok,why)if not ok then error("strict-dispatch: "..why,2)end end
local function test(label,fn)
  fn();total=total+1;print("[strict-craft-dispatch] PASS "..label)
end
local function setup(p)
  local raw={kind="direct-mine-0336",bootstrap_resource_0637=true,
    output_item="iron-ore",current={kind="direct-mine-0336",
      output_item="iron-ore",entity=physical}}
  p.direct_acquisition_task_0336=raw
  p.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel",
    count=1,target_stock_0647=2,craft_due_tick_0514=15900,
    current={kind="direct-mine-0336",entity=physical}}
  p.movement_request_0418={owner="direct-acquisition-0513",
    priority=650,expires_tick=16500}
  return raw
end

test("timed strict craft wins over stray direct current and route",function()
  local p=make_pair();setup(p)
  local action=Arbiter.action(p)
  check(action.kind=="crafting","arbiter selected "..tostring(action.kind))
  local result=Dispatcher.service_pair(p,"regression")
  check(result.acted==1 and counts.craft==1 and counts.direct==0,
    "dispatcher did not execute strict production")
  check(counts.stops==1 and p.movement_request_0418==nil,
    "stale direct movement lease survived")
  check(p.emergency_craft.strict_recipe_0647==true,"strict craft was cleared")
end)

test("strict craft without due tick beats stale direct-mine current",function()
  local p=make_pair();setup(p)
  p.emergency_craft.craft_due_tick_0514=nil
  local action=Arbiter.action(p)
  check(action.kind=="crafting","stale direct-mine alias disguised strict recipe as "..tostring(action.kind))
  local result=Dispatcher.service_pair(p,"strict-no-due")
  check(result.acted==1 and counts.craft==1 and counts.direct==0,
    "strict recipe was not serviced before its fallback due tick")
  check(counts.stops==1 and p.movement_request_0418==nil,
    "stale direct movement lease blocked the manufacturing handoff")
end)

test("physical custody returns before strict station crafting",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_custody_0513={item="iron-ore",count=1}
  local result=Dispatcher.service_pair(p,"cargo-return")
  check(result.acted==1 and counts.direct==1 and counts.craft==0,
    "carried mined output lost its executor")
  check(counts.stops==0,"custody return movement was stopped")
  check(p.direct_acquisition_custody_0513.count==1,"physical custody changed")
end)

test("active repair order is not displaced by pending manufacturing",function()
  local p=make_pair();setup(p)
  p.order_queue_0469={current={kind="repair",status="active",key="repair-unique",
    priority=800,target=physical},pending={},pending_keys={}}
  local result=Dispatcher.service_pair(p,"repair-priority")
  check(result.acted==1 and counts.repair==1 and counts.craft==0,
    "repair order was preempted without authorization")
  check(counts.stops==0,"repair-owned movement was modified")
  check(p.order_queue_0469.current.key=="repair-unique","repair order changed")
end)

test("ordinary explicit acquisition retains its order priority",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="acquisition",status="active",
    key="deliberate-acquisition",priority=570},pending={},pending_keys={}}
  local result=Dispatcher.service_pair(p,"explicit-acquisition")
  check(result.acted==1 and counts.direct==1 and counts.craft==0,
    "nonbootstrap acquisition was displaced")
  check(counts.stops==0,"explicit acquisition movement was stopped")
end)

test("no movement owner means no unrelated stop",function()
  local p=make_pair();setup(p)
  p.movement_request_0418.owner="movement-controller-enforcement-0566"
  Dispatcher.service_pair(p,"enforced-return")
  check(counts.craft==1 and counts.stops==0,
    "safety enforcement movement was stopped")
end)

print("[strict-craft-dispatch] PASS scenarios="..total)
