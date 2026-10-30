-- Method I: a real 0338 builder, not this planner, spends drill stock.
-- Test the live 0820 return route, physical terminal, exact build receipt,
-- persistent request identity, unavailable stock and refusal of forged drills.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Chain=require("scripts.core.resource_station_chain_0820")
local Drill=require("scripts.core.remote_machine_drill_1011")
game={tick=1000}
defines={inventory={chest=1},direction={north=0}}
prototypes={item={["burner-mining-drill"]={},
  ["wooden-chest"]={}},entity={["burner-mining-drill"]={}}}
local force={index=1}
local surface={index=1}
local stock={["burner-mining-drill"]=1,["wooden-chest"]=1,coal=5}
local inv={valid=true,get_item_count=function(name)return stock[name] or 0 end}
local magos={station={valid=true,unit_number=100,
  position={x=0,y=0},force=force,surface=surface},
  priest={valid=true,unit_number=200},radius=30,rank_test=4}
local junior={station={valid=true,unit_number=101,
  position={x=20,y=0},force=force,surface=surface,
  get_inventory=function(id)assert(id==1);return inv end},
  priest={valid=true,unit_number=201},radius=20,rank_test=3,
  remote_resource_assignment_0820={
    root_station_unit=100,parent_station_unit=100,segment=1}}
storage={tech_priests={pairs_by_station={[100]=magos,[101]=junior}}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(pair)return pair.rank_test end,
  is_direct_subordinate=function(a,b)return a==magos and b==junior end}
local mission={status="reached-resource",root_station_unit=100,
  current_station_unit=101,segments=1,
  route_station_units={100,101},need="iron-ore",
  resource_name="iron-ore",target={x=24,y=0}}
magos.resource_expansion_0259={chain_0820=mission}
local ore={valid=true,type="resource",name="iron-ore",
  amount=100,position={x=24.2,y=0.2},surface=surface}
local built,receiver
local receiver_inv={valid=true,get_item_count=function()return 0 end}
local scan_count=0
_G.TechPriestsScanRouting0610={find_entities=function(s,filter,opts)
  assert(s==surface and opts and opts.require_fresh==true)
  scan_count=scan_count+1
  if filter.type=="resource" then
    assert(filter.name=="iron-ore" and opts.category=="resource")
    return {ore}
  end
  assert(opts.category=="construction" and filter.limit==4)
  if filter.name=="wooden-chest" then
    return receiver and {receiver} or {}
  end
  assert(filter.name=="burner-mining-drill")
  return built and {built} or {}
end}
surface.can_place_entity=function(spec)
  assert(spec.force==force)
  if spec.name=="wooden-chest" then
    assert(spec.position.x==25.5 and spec.position.y==0.5)
  else
    assert(spec.name=="burner-mining-drill"
      and spec.direction==0 and spec.position.x==24)
  end
  return true
end
local function service()return Drill.service_pair(magos)end
stock.coal=4
assert(select(2,service())=="physical-drill-receiver-or-fuel-stock-missing"
  and not junior.construction_request and not mission.remote_drill_1011,
  "missing physical fuel still authorized construction")
stock.coal=5
junior.construction_request={item_name="existing-task"}
assert(select(2,service())=="terminal-has-existing-construction"
  and not mission.remote_drill_1011,
  "a live native construction request was overwritten")
junior.construction_request=nil
local ok,reason=service()
local req=junior.construction_request
local state=mission.remote_drill_1011
assert(ok and reason=="physical-drill-requested-from-real-terminal-stock"
  and req and req.item_name=="burner-mining-drill"
  and req.entity_name=="burner-mining-drill"
  and req.remote_drill_root_1011==100
  and req.remote_drill_terminal_1011==101
  and state and state.request==req
  and state.phase=="drill-requested"
  and stock["burner-mining-drill"]==1 and not built,
  "planning minted an entity or debited inventory outside 0338")
assert(select(2,service())=="waiting-for-native-0338-drill-builder"
  and junior.construction_request==req and scan_count>=1,
  "pending native construction was replaced")
junior.construction_request=nil
assert(select(2,service())=="awaiting-exact-native-drill-build-proof"
  and state.phase=="drill-requested",
  "missing native build receipt was accepted")
built={valid=true,name="burner-mining-drill",type="mining-drill",
  unit_number=300,position={x=24,y=0},direction=0,
  drop_position={x=25.2,y=0.1},surface=surface,force=force}
junior.construction_last_task_0338={
  request_value={item_name="burner-mining-drill"},
  phase="complete",built_entity=built}
assert(select(2,service())=="awaiting-exact-native-drill-build-proof",
  "foreign builder request credited a real drill")
junior.construction_last_task_0338.request_value=req
stock["burner-mining-drill"]=0 -- Native 0338 alone made the actual debit.
package.loaded["scripts.core.remote_machine_drill_1011"]=nil
Drill=require("scripts.core.remote_machine_drill_1011")
assert(select(2,service())=="counted-0338-drill-built-receiver-and-fuel-pending"
  and state.phase=="drill-verified" and state.drill_unit==300
  and stock["burner-mining-drill"]==0,
  "physical drill completion not verified across module reload")
stock["wooden-chest"]=0
assert(select(2,service())=="physical-receiver-stock-missing"
  and state.phase=="drill-verified",
  "missing real chest stock authorized a receiver")
stock["wooden-chest"]=1
junior.construction_request={item_name="competing"}
assert(select(2,service())=="terminal-has-existing-construction",
  "receiver request displaced an existing native constructor")
junior.construction_request=nil
assert(select(2,service())=="physical-receiver-requested-from-real-terminal-stock",
  "real drill did not request a native output chest")
local receiver_req=junior.construction_request
assert(receiver_req and receiver_req.item_name=="wooden-chest"
  and receiver_req.entity_name=="wooden-chest"
  and receiver_req.position.x==25.5 and receiver_req.position.y==0.5
  and receiver_req.remote_drill_unit_1012==300
  and state.receiver_request==receiver_req
  and state.phase=="receiver-requested"
  and stock["wooden-chest"]==1,
  "receiver planning debited stock or invented a chest")
package.loaded["scripts.core.remote_machine_drill_1011"]=nil
Drill=require("scripts.core.remote_machine_drill_1011")
assert(select(2,service())=="waiting-for-native-0338-receiver-builder",
  "pending chest request was lost on module reload")
junior.construction_request=nil
assert(select(2,service())=="awaiting-exact-native-receiver-build-proof",
  "missing native chest receipt was accepted")
receiver={valid=true,name="wooden-chest",type="container",
  unit_number=400,position={x=25.5,y=0.5},surface=surface,force=force,
  get_inventory=function(id)assert(id==1);return receiver_inv end}
junior.construction_last_task_0338={
  request_value={item_name="wooden-chest"},
  phase="complete",built_entity=receiver}
assert(select(2,service())=="awaiting-exact-native-receiver-build-proof",
  "unrelated native chest receipt was accepted")
junior.construction_last_task_0338.request_value=receiver_req
stock["wooden-chest"]=0 -- Only the native 0338 constructor debits it.
assert(select(2,service())=="counted-0338-receiver-built-connection-pending"
  and state.phase=="receiver-built" and state.receiver_unit==400,
  "exact native chest completion was not checked against real entity")
game.tick=1800
local pending,pending_reason=service()
assert(pending==false
  and pending_reason=="waiting-for-physical-drill-receiver-connection"
  and state.phase=="receiver-built",
  "unfueled receiver was credited, quarantined or monopolized the ore courier")
built.drop_target=receiver
assert(select(2,service())=="physical-drill-receiver-connected-fuel-pending"
  and state.phase=="receiver-verified",
  "actual drill drop connection was not required")
assert(select(2,service())=="physical-drill-and-receiver-present-fuel-pending",
  "a built chest was incorrectly credited as delivered ore")
-- An aborted native chest task may leave the exact request on the pair.
-- That stale request must not conceal the abort behind a perpetual busy state.
local completed_receiver=receiver
local connected_receiver=built.drop_target
local completed_state=state
mission.remote_drill_1011={
  phase="receiver-requested",root_unit=100,terminal_unit=101,
  resource_name="iron-ore",target={x=24,y=0},
  position={x=24,y=0},direction=0,drill_unit=300,
  receiver_position={x=25.5,y=0.5},
  receiver_request=receiver_req}
junior.construction_request=receiver_req
junior.construction_last_task_0338={
  request_value=receiver_req,phase="aborted",result="receiver-site-blocked"}
assert(select(2,service())=="native-receiver-builder-aborted:receiver-site-blocked"
  and mission.remote_drill_1011.phase=="blocked",
  "native receiver abort was hidden by its retained request")
junior.construction_request=nil
junior.construction_last_task_0338=nil
mission.remote_drill_1011=completed_state
built.drop_target=connected_receiver
receiver=completed_receiver
receiver={valid=true,name="wooden-chest",type="container",
  unit_number=401,position={x=25.5,y=0.5},surface=surface,force=force,
  get_inventory=function()return receiver_inv end}
assert(select(2,service())=="verified-physical-receiver-lost"
  and state.phase=="blocked",
  "different physical chest replaced the verified receiver")
mission.remote_drill_1011=nil
stock["wooden-chest"]=1
stock["burner-mining-drill"]=1
receiver=nil
built=nil
junior.construction_last_task_0338=nil
assert(select(2,service())=="physical-drill-requested-from-real-terminal-stock")
local lost=mission.remote_drill_1011
junior.construction_request=nil
lost.phase="drill-verified"
lost.drill_unit=300
built={valid=true,name="burner-mining-drill",type="mining-drill",
  unit_number=301,position={x=24,y=0},direction=0,
  drop_position={x=25.2,y=0.1},surface=surface,force=force}
assert(select(2,service())=="verified-physical-drill-lost"
  and lost.phase=="blocked",
  "different physical drill silently replaced original custody")
mission.remote_drill_1011=nil
stock["burner-mining-drill"]=1
built=nil
assert(select(2,service())=="physical-drill-requested-from-real-terminal-stock")
local aborted=mission.remote_drill_1011
-- 0338 leaves a failed request on the pair until a new owner clears it.
junior.construction_last_task_0338={
  request_value=aborted.request,phase="aborted",result="blocked-site"}
assert(select(2,service())=="native-drill-builder-aborted:blocked-site"
  and aborted.phase=="blocked" and stock["burner-mining-drill"]==1,
  "aborted native builder was accepted or planner removed stock")
-- A new objective may only be issued after the rejected native request is
-- explicitly retired; the production planner never silently steals it.
junior.construction_request=nil
mission.remote_drill_1011=nil
assert(select(2,service())=="physical-drill-requested-from-real-terminal-stock")
local replaced=mission.remote_drill_1011
junior.construction_request={item_name="other-worker"}
assert(select(2,service())=="native-drill-request-replaced-by-other-work"
  and replaced.phase=="blocked" and stock["burner-mining-drill"]==1,
  "a competing native request was misreported as drill construction")
print("[remote-machine-drill-1011] PASS physical drill and receiver, counted 0338 requests, exact drop connection, reload, forged identity and abort")
