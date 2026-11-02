-- Autonomous Magos roboport frontier: no unpowered leaps, no free parts,
-- only exact 0338 physical receipts and engine-observed connected grid.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.roboport_expansion_frontier_1076")
game={tick=1000}
local force={index=1}
local net={valid=true,force=force,network_id=19}
local pole_proto={type="electric-pole",maximum_wire_distance=9,
  supply_area_distance=3.5}
prototypes={
 entity={roboport={type="roboport"},
   ["medium-electric-pole"]=pole_proto},
 item={roboport={place_result={name="roboport"}},
   ["medium-electric-pole"]={place_result={name="medium-electric-pole"}}}}
local objects={}
local function add(e)
  objects[#objects+1]=e
  return e
end
local surface={index=1}
local function range(p,goal,r)
  return math.abs(goal.x-p.x)<=r and math.abs(goal.y-p.y)<=r
end
local function port(pos,connected,network_id)
  local e={valid=true,type="roboport",name="roboport",position=pos,
    surface=surface,force=force,energy=connected and 10000 or 0,
    electric_network_id=7,
    is_connected_to_electric_network=function()return connected end}
  local n=network_id==19 and net or
    {valid=true,force=force,network_id=network_id}
  e.logistic_cell={
    valid=true,transmitting=connected,logistic_radius=25,
    construction_radius=55,logistic_network=n,
    is_in_logistic_range=function(pos2)return range(pos,pos2,25)end,
    is_in_construction_range=function(pos2)return range(pos,pos2,55)end}
  return add(e)
end
local function pole(pos,id)
  return add({valid=true,type="electric-pole",name="medium-electric-pole",
    position=pos,surface=surface,force=force,prototype=pole_proto,
    electric_network_id=id})
end
function surface.find_entities_filtered(spec)
  local result={}
  for _,e in ipairs(objects)do
    if e.valid and (not spec.force or spec.force==e.force)
      and (not spec.name or spec.name==e.name)
      and (not spec.type or spec.type==e.type)
      and (not spec.position or
        (e.position.x-spec.position.x)^2+
        (e.position.y-spec.position.y)^2<=spec.radius*spec.radius)
      and (not spec.radius or not spec.position or
        (e.position.x-spec.position.x)^2+
        (e.position.y-spec.position.y)^2<=spec.radius*spec.radius)then
      result[#result+1]=e
      if spec.limit and #result>=spec.limit then break end
    end
  end
  return result
end
function surface.can_place_entity(spec)
  assert(spec.force==force and
    (spec.name=="roboport" or spec.name=="medium-electric-pole"),
    "unexpected place_entity call")
  return true
end
local stock={["medium-electric-pole"]=300,roboport=24}
_G.TechPriestsStorageRoleAuthority0686={
  generic_item_count=function(_,item)return stock[item]or 0 end}
local queries=0
_G.TechPriestsScanRouting0610={find_entities=function(s,filter,opts)
  assert(s==surface and opts.limit==filter.limit and filter.limit<=64,
    "expansion used uncapped or foreign-world scan")
  queries=queries+1
  return surface.find_entities_filtered(filter)
end}
local function make_pair(goal)
  return {station={valid=true,name="planetary-magos-cogitator-station",
    unit_number=99,force=force,surface=surface,position={x=0,y=0}},
    priest={valid=true},roboport_expansion_goal_1076={
      target=goal,root_station_unit=99,surface_index=1,force_index=1}}
end
local root_port=port({x=0,y=0},true,19)
pole({x=0,y=4},7)
local pair=make_pair({x=100,y=0})
local stages,ports,poles=0,0,0
local result=M.service_pair(pair)
assert(result.detail=="submitted-to-canonical-0338","first physical step not submitted")
assert(pair.construction_request.entity_name=="medium-electric-pole",
  "first extension must build physically connected power before a roboport")
assert(#objects==2,"planning created an actual building without priest executor")
local first_request=pair.construction_request
local duplicate=M.service_pair(pair)
assert(duplicate.waiting==1 and pair.construction_request==first_request
  and #objects==2,
  "planner issued duplicate construction while a physical receipt was pending")
while stages<100 do
  local request=pair.construction_request
  if request then
    assert(pair.roboport_frontier_1076.pending.request==request,
      "construction request lost persistent stage identity")
    local ent=request.entity_name=="roboport" and
      port(request.position,true,19) or pole(request.position,7)
    if request.entity_name=="roboport" then
      ports=ports+1
    else
      poles=poles+1
    end
    -- Simulate the legitimate 0338 receipt only: no inventory mutations
    -- are performed by the frontier planner itself.
    assert(stock[request.item_name]>=1,"fixture ran out of physical stock")
    stock[request.item_name]=stock[request.item_name]-1
    pair.construction_last_task_0338={
      phase="complete",request_value=request,built_entity=ent}
    pair.construction_request=nil
    local proved=M.service_pair(pair)
    assert(proved.acted==1 and pair.roboport_frontier_1076.pending==nil,
      "physical builder receipt was not independently verified")
  end
  local next=M.service_pair(pair)
  stages=stages+1
  if pair.roboport_frontier_1076.status=="complete"then break end
  assert(next and not next.blocked,
    "physical frontier blocked: "..tostring(next and next.detail))
end
assert(pair.roboport_frontier_1076.status=="complete",
  "multiple powered coverage segments did not reach objective")
assert(ports>=2 and poles>=3,"test did not exercise multiple power/port stages")
assert(pair.roboport_frontier_1076.segments==ports)
assert(pair.roboport_frontier_1076.poles_built==poles)
assert(stock.roboport==24-ports
  and stock["medium-electric-pole"]==300-poles,
  "planner forged or double-debited the simulated physical construction stock")
assert(queries>0 and stages<100,"nonbounded or no canonical source scans")
-- A completed frontier is not a permanent credit: losing the last actual
-- port must trigger inspection of surviving original-network infrastructure.
local frontier=pair.roboport_frontier_1076
local destroyed=frontier.source_port
destroyed.valid=false
local recovery=M.service_pair(pair)
assert(frontier.coverage_loss_tick==game.tick
  and frontier.recovery_attempts==1
  and frontier.source_port~=destroyed,
  "destroyed final port left stale completed coverage")
assert(recovery.detail=="submitted-to-canonical-0338"
  and pair.construction_request
  and pair.construction_request.entity_name=="roboport",
  "surviving connected pole chain was not reused for physical port recovery")
local restored_request=pair.construction_request
local replacement=port(restored_request.position,true,19)
stock.roboport=stock.roboport-1
pair.construction_last_task_0338={
  phase="complete",request_value=restored_request,built_entity=replacement}
pair.construction_request=nil
local receipt=M.service_pair(pair)
assert(receipt.acted==1 and frontier.source_port==replacement,
  "replacement port was not verified by original physical 0338 receipt")
assert(M.service_pair(pair).detail==
    "actual-logistic-and-construction-coverage-at-goal"
    and frontier.status=="complete",
  "real recovery did not restore monitored logistic and construction coverage")
local original_objects=objects
objects={}
local no_power=port({x=0,y=0},false,19)
local p2=make_pair({x=100,y=0})
local refused=M.service_pair(p2)
assert(not p2.roboport_frontier_1076 and refused.blocked==1,
  "dead roboport initiated an unpowered frontier")
no_power.valid=false
objects=original_objects
local foreign=make_pair({x=40,y=30})
foreign.roboport_expansion_goal_1076.force_index=2
assert(M.service_pair(foreign).detail=="no-expansion-goal",
  "foreign-force mission was accepted")
-- New mission, one receipt with a disconnected pole: do not bless it
-- or advance. A bounded settling window must end in a hard block.
local isolated=make_pair({x=0,y=100})
local saved=stock["medium-electric-pole"]
stock["medium-electric-pole"]=0
local missing=M.service_pair(isolated)
assert(missing.detail=="waiting-real-power-or-roboport-item"
  and not isolated.construction_request,
  "planner monopolized construction without any physical pole supply")
stock["medium-electric-pole"]=saved
local first=M.service_pair(isolated)
assert(isolated.construction_request
  and isolated.construction_request.entity_name=="medium-electric-pole",
  "isolation scenario never submitted a real pole request")
local r=isolated.construction_request
local bad=pole(r.position,999)
isolated.construction_last_task_0338={
  phase="complete",request_value=r,built_entity=bad}
isolated.construction_request=nil
local awaiting=M.service_pair(isolated)
assert(awaiting.waiting==1 and isolated.roboport_frontier_1076.pending,
  "wrong-grid pole was counted as an expansion")
game.tick=game.tick+M.settle_ticks+1
local blocked=M.service_pair(isolated)
assert(blocked.blocked==1
  and isolated.roboport_frontier_1076.status=="blocked"
  and isolated.roboport_frontier_1076.segments==0,
  "disconnected electricity was incorrectly credited")
local pole_stock_after_block=stock["medium-electric-pole"]
local early=M.service_pair(isolated)
assert(early.waiting==1 and isolated.construction_request==nil,
  "blocked grid recheck duplicated the original physical pole request")
bad.electric_network_id=7 -- actual late grid reconnection, no item credit
game.tick=game.tick+M.settle_ticks+1
local reconnected=M.service_pair(isolated)
assert(reconnected.acted==1
  and isolated.roboport_frontier_1076.pending==nil
  and isolated.roboport_frontier_1076.status=="planning"
  and stock["medium-electric-pole"]==pole_stock_after_block,
  "late physical pole connection did not resume exact 0338 receipt")
-- A physically built and energized port belonging to a different electric
-- grid MUST NOT be accepted merely because its logistic cells merged.
local wrong_port=make_pair({x=0,y=-100})
local port_request
for k=1,50 do
  local step_result=M.service_pair(wrong_port)
  local req=wrong_port.construction_request
  assert(not step_result.blocked,
    "wrong-grid port setup unexpectedly blocked: "..tostring(step_result.detail))
  if req then
    local actual
    if req.entity_name=="medium-electric-pole" then
      actual=pole(req.position,7)
    else
      port_request=req
      actual=port(req.position,true,19)
      actual.electric_network_id=999
    end
    wrong_port.construction_last_task_0338={
      phase="complete",request_value=req,built_entity=actual}
    wrong_port.construction_request=nil
    local result=M.service_pair(wrong_port)
    if port_request then
      assert(result.waiting==1 and wrong_port.roboport_frontier_1076.pending,
        "foreign-electric-grid roboport was falsely accepted")
      game.tick=game.tick+M.settle_ticks+1
      local expired=M.service_pair(wrong_port)
      assert(expired.blocked==1
        and wrong_port.roboport_frontier_1076.status=="blocked",
        "wrong-grid energized roboport bypassed native electric network proof")
      local port_stock_after_block=stock.roboport
      assert(M.service_pair(wrong_port).waiting==1
        and wrong_port.construction_request==nil,
        "blocked port recheck duplicated a physical build request")
      actual.electric_network_id=7 -- real grid merge, no extra item
      game.tick=game.tick+M.settle_ticks+1
      local restored=M.service_pair(wrong_port)
      assert(restored.acted==1
        and wrong_port.roboport_frontier_1076.pending==nil
        and wrong_port.roboport_frontier_1076.status=="planning"
        and stock.roboport==port_stock_after_block,
        "late powered port merge did not conserve original physical receipt")
      break
    end
    assert(result.acted==1,
      "wrong-grid setup could not physically receipt a connecting pole")
  end
end
assert(port_request,"wrong-grid roboport negative never reached a port build")
-- Exercise the actual 0600 broker entry point, not only direct service_pair.
-- A candidate array must never shadow Lua's built-in pairs() iterator:
-- doing so silently makes every scheduled frontier dispatch fail in pcall.
local budget_pair=make_pair({x=160,y=0})
budget_pair.station.unit_number=100
budget_pair.roboport_expansion_goal_1076.root_station_unit=100
storage={tech_priests={pairs_by_station={
  [99]=pair,[100]=budget_pair,
  [101]={station={valid=false},priest={valid=false}}
}}}
local broker_first=M.service_budgeted(nil,1)
assert(broker_first.processed==1 and broker_first.failed==0
  and storage.tech_priests.roboport_expansion_broker_1076.cursor==1,
  "canonical broker failed first real Magos frontier dispatch")
local broker_second=M.service_budgeted(nil,1)
assert(broker_second.processed==1 and broker_second.failed==0
  and storage.tech_priests.roboport_expansion_broker_1076.cursor==0,
  "canonical broker did not rotate fairly to the second live Magos")
local broker_zero=M.service_budgeted(nil,0)
assert(broker_zero.processed==0 and broker_zero.acted==0,
  "zero broker budget unexpectedly dispatched construction")
print("[roboport-expansion-1076] PASS sequential pole/port receipts, real coverage, grid continuity, no scripted items, blocked wrong-grid pole and roboport, late physical reconnection without double debit")
