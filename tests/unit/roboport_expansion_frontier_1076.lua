-- Autonomous Magos roboport frontier: no unpowered leaps, no free parts,
-- only exact 0338 physical receipts and engine-observed connected grid.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.roboport_expansion_frontier_1076")
-- Planner-only fixtures do not execute 0338 movement; the real
-- authority's bounded contact preflight is exercised separately below.
_G.TechPriestsConstructionPlanner0338={
  frontier_site_contact_0338=function()return {x=0,y=0} end}
game={tick=1000}
local force={index=1}
local net={valid=true,force=force,network_id=19}
-- Real Factorio 2.0 LuaEntityPrototype has quality-aware geometry
-- methods; reading the old 1.1 fields throws instead of returning nil.
local supply_reads,wire_reads=0,0
local pole_proto=setmetatable({type="electric-pole",
  get_supply_area_distance=function()
    supply_reads=supply_reads+1;return 3.5
  end,
  get_max_wire_distance=function()
    wire_reads=wire_reads+1;return 9
  end}, {__index=function(_,key)
    if key=="supply_area_distance" or key=="maximum_wire_distance" then
      error("Factorio 2.0 LuaEntityPrototype doesn't contain key "..key)
    end
  end})
prototypes={
 entity={roboport={type="roboport",collision_box={
   left_top={x=-2,y=-2},right_bottom={x=2,y=2}}},
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
    (spec.name=="roboport" or spec.name=="medium-electric-pole"
      or spec.name=="tech-priest"),
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
  -- Native engine 1080 placed the correct receipt entity at (25.5,6.5),
  -- but a clean 0579 industrial index returned no freshly built pole.
  -- Require a direct engine read for the exact 0338 custody probe; leave
  -- nonreceipt broad discovery on the indexed canonical scan path.
  if filter.radius==0.75 and filter.limit==3
    and (filter.name=="medium-electric-pole"
      or filter.type=="roboport") then
    assert(opts.require_fresh==true,
      "native built 0338 receipt was checked against stale industrial index")
  end
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
local original_grid_anchor=pole({x=0,y=4},7)
-- A proposed autonomous Method II goal must first prove that the SAME
-- 1076 authority can identify actual powered coverage and a same-grid pole.
-- A ready-looking 0714 summary alone is not a buildable route.
local admission_owner=make_pair({x=10,y=0})
local admitted,admission_reason=M.native_covered_ore_admission_1076(
  admission_owner,{x=12,y=0},{x=8,y=0})
assert(admitted and admission_reason==
  "existing-powered-covered-grid-and-anchor-verified"
  and not admission_owner.roboport_frontier_1076,
  "existing native covered grid admission failed or built without 0338")
-- Factorio construction bots can build outside the 25-tile orange logistic
-- area, as long as an original network with real supplies covers the ghost
-- in its 55-tile green construction area. Do not demand orange-at-ghost.
local green_target={x=40,y=0}
local green_site={x=43,y=0}
assert(not root_port.logistic_cell.is_in_logistic_range(green_site)
  and root_port.logistic_cell.is_in_construction_range(green_site)
  and M.native_covered_ore_admission_1076(
    admission_owner,green_target,green_site),
  "physically buildable green-only target denied by robot admission")
local green_mission=make_pair(green_target)
green_mission.roboport_expansion_goal_1076.remote_station_item_1076=
  "intermediate-cogitator-station"
green_mission.roboport_expansion_goal_1076.remote_station_position_1076=
  green_site
local green_result=M.service_pair(green_mission)
assert(green_result.detail=="remote-station-hierarchy-unavailable"
  and green_mission.roboport_frontier_1076
  and green_mission.roboport_frontier_1076.status=="complete"
  and not green_mission.construction_request,
  "covered green-only mission tried to extend or fabricate a roboport")
original_grid_anchor.electric_network_id=8
assert(not M.native_covered_ore_admission_1076(
  admission_owner,{x=12,y=0},{x=8,y=0}),
  "foreign electric-grid pole was admitted for autonomous robot construction")
original_grid_anchor.electric_network_id=7
root_port.energy=0
assert(not M.native_covered_ore_admission_1076(
  admission_owner,{x=12,y=0},{x=8,y=0}),
  "unpowered original roboport authorized autonomous Method II")
root_port.energy=10000
assert(not M.native_covered_ore_admission_1076(
  admission_owner,{x=80,y=0},{x=78,y=0}),
  "uncovered remote ore was confused with native reachable network")
-- A genuine outside-green ore deficit may reserve only a READ-ONLY,
-- stocked and powered extension route. It cannot claim new network coverage.
local former_hierarchy=_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p==admission_owner and 4 or 0 end}
local distant_target={x=100,y=0}
local distant_site={x=96,y=0}
local extension_ok,extension_reason=M.native_uncovered_ore_admission_1076(
  admission_owner,distant_target,distant_site)
assert(extension_ok
  and extension_reason=="native-powered-stocked-first-frontier-waypoint"
  and not admission_owner.roboport_frontier_1076
  and not admission_owner.construction_request and #objects==2,
  "outside-green admission fabricated a build or refused a real first hop")
stock.roboport=0
assert(not M.native_uncovered_ore_admission_1076(
  admission_owner,distant_target,distant_site),
  "outside-green goal reserved without a counted roboport")
stock.roboport=24
stock["medium-electric-pole"]=0
assert(not M.native_uncovered_ore_admission_1076(
  admission_owner,distant_target,distant_site),
  "outside-green goal reserved without a counted electric pole")
stock["medium-electric-pole"]=300
original_grid_anchor.electric_network_id=999
assert(not M.native_uncovered_ore_admission_1076(
  admission_owner,distant_target,distant_site),
  "outside-green goal accepted unrelated electric network")
original_grid_anchor.electric_network_id=7
root_port.energy=0
assert(not M.native_uncovered_ore_admission_1076(
  admission_owner,distant_target,distant_site),
  "outside-green goal accepted unpowered source")
root_port.energy=10000
assert(not M.native_uncovered_ore_admission_1076(
  admission_owner,{x=40,y=0},{x=36,y=0}),
  "already-covered target started a redundant frontier")
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480=former_hierarchy

local deferred=make_pair({x=100,y=0})
deferred.roboport_expansion_goal_1076.activation_pending_1076=true
local held=M.service_pair(deferred)
assert(held.waiting==1
  and held.detail=="awaiting-original-ranked-robot-builder"
  and not deferred.roboport_frontier_1076
  and not deferred.construction_request and #objects==2,
  "predeclared robot frontier spent stock or built before its Senior existed")
deferred.roboport_expansion_goal_1076.activation_pending_1076=nil
assert(M.service_pair(deferred).detail=="submitted-to-canonical-0338"
  and deferred.construction_request,
  "verified Senior activation did not release the original physical builder")
-- Unknown native pole geometry must refuse construction, not fall
-- back to invented reach or consume a physical item.
local native_supply=pole_proto.get_supply_area_distance
pole_proto.get_supply_area_distance=function() return nil end
local unsupported=make_pair({x=100,y=0})
local refused_geometry=M.service_pair(unsupported)
assert(refused_geometry.blocked==1
  and refused_geometry.detail=="no-proven-powered-grid-anchor"
  and not unsupported.roboport_frontier_1076
  and not unsupported.construction_request and #objects==2,
  "unreadable native pole geometry authorized construction")
pole_proto.get_supply_area_distance=native_supply
-- A live native 1080 builder cannot walk arbitrarily far from the Magos.
-- Its target site must be shortened BEFORE spending three counted poles.
-- This injected contact boundary stands for canonical 0418's actual
-- position_allowed result; it does not grant expanded movement authority.
local genuine_contact=_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338
_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=
  function(_,name,pos)
    if name=="roboport" and pos.x>29 then
      return nil,"outside-native-authorized-standoff"
    end
    return {x=pos.x-1,y=pos.y}
  end
local contact_limited=make_pair({x=100,y=0})
local first_limited=M.service_pair(contact_limited)
assert(first_limited.detail=="submitted-to-canonical-0338"
  and contact_limited.roboport_frontier_1076
  and contact_limited.roboport_frontier_1076.site.x<=29
  and contact_limited.roboport_frontier_1076.site.x>5
  and contact_limited.construction_request
  and contact_limited.construction_request.entity_name=="medium-electric-pole",
  "frontier committed poles toward a physically unreachable first port")
_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=genuine_contact
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
-- Factorio 2.0 may snap a 1x1 electric pole to the center of the tile,
-- moving both coordinates by 0.5. The real 0338 receipt must still match
-- its original request and original electrical grid. An adjacent tile must
-- NOT satisfy the request, even when the item/entity type is identical.
local snapped=make_pair({x=100,y=0})
assert(M.service_pair(snapped).detail=="submitted-to-canonical-0338",
  "snapped placement setup did not request a real pole")
local snapped_request=snapped.construction_request
local snapped_entity=pole({x=snapped_request.position.x+0.5,
  y=snapped_request.position.y+0.5},7)
stock["medium-electric-pole"]=stock["medium-electric-pole"]-1
snapped.construction_last_task_0338={phase="complete",
  request_value=snapped_request,built_entity=snapped_entity}
snapped.construction_request=nil
local snapped_receipt=M.service_pair(snapped)
assert(snapped_receipt.acted==1
  and snapped.roboport_frontier_1076.poles_built==1
  and snapped.roboport_frontier_1076.pending==nil,
  "native half-tile diagonal snap lost a genuine 0338 pole receipt")
snapped_entity.valid=false
stock["medium-electric-pole"]=stock["medium-electric-pole"]+1
local adjacent=make_pair({x=100,y=0})
assert(M.service_pair(adjacent).detail=="submitted-to-canonical-0338",
  "adjacent-tile negative did not request a pole")
local adjacent_request=adjacent.construction_request
local adjacent_entity=pole({x=adjacent_request.position.x+1,
  y=adjacent_request.position.y},7)
adjacent.construction_last_task_0338={phase="complete",
  request_value=adjacent_request,built_entity=adjacent_entity}
adjacent.construction_request=nil
local adjacent_refusal=M.service_pair(adjacent)
assert(adjacent_refusal.waiting==1
  and adjacent.roboport_frontier_1076.poles_built==0
  and adjacent.roboport_frontier_1076.pending,
  "neighboring tile was falsely accepted as the original 0338 build")
adjacent_entity.valid=false
while stages<100 do
  local request=pair.construction_request
  if request then
    assert(pair.roboport_frontier_1076.pending.request==request,
      "construction request lost persistent stage identity")
    local ent=request.entity_name=="roboport" and
      port(request.position,true,19) or pole(request.position,7)
    if request.entity_name=="roboport" then
      -- Factorio may renumber the same live native network on every merge.
      net.network_id=net.network_id+1
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
    if request.entity_name=="roboport" then
      assert(pair.roboport_frontier_1076.logistic_network_id==
        net.network_id,
        "native logistics ID was not refreshed on every new segment")
    end
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
assert(supply_reads>0 and wire_reads>0,
  "native Factorio 2.0 pole geometry methods were not used")
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

-- An explicitly requested remote outpost must be a NEW native robot build
-- owned by the already paired direct Senior, not another priest-placed pole,
-- a credited ghost, or a second station under the distant Magos.
local senior={station={valid=true,name="senior-cogitator-station",
    unit_number=105,force=force,surface=surface,position={x=70,y=0}},
  priest={valid=true,unit_number=205},radius=40}
storage={tech_priests={pairs_by_station={[105]=senior}}}
local intermediate={station={valid=true,
    name="intermediate-cogitator-station",unit_number=106,
    force=force,surface=surface,position={x=100,y=0}},
  priest={valid=true,unit_number=206}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)
    if p==pair then return 4 end
    if p==senior then return 3 end
    if p==intermediate then return 2 end
    return 0
  end,
  is_direct_subordinate=function(parent,child)
    return (parent==pair and child==senior)
      or (parent==senior and child==intermediate)
  end,
  direct_capacity_remaining=function()return 1 end}
pair.roboport_expansion_goal_1076.remote_station_item_1076=
  "intermediate-cogitator-station"
pair.roboport_expansion_goal_1076.remote_station_position_1076=
  {x=100,y=0}
local robot_ready=false
_G.TechPriestsConstructionPlanner0338.robot_network_preflight_0338=
  function(worker,request)
    assert(worker==senior and request.root_station_unit==105
      and request.entity_name=="intermediate-cogitator-station"
      and request.position.x==100,
      "1076 delegated a foreign or wrong-rank robot station request")
    if not robot_ready then return nil,"no-available-construction-robots" end
    return {network_id=19,stock=1},"powered-supplied-construction-network"
  end
local robotless=M.service_pair(pair)
assert(robotless.waiting==1
  and robotless.detail=="no-available-construction-robots"
  and not senior.robot_network_request_0338
  and not frontier.remote_station_request_1076,
  "unpowered/robotless network received an outpost ghost request")
robot_ready=true
local submitted=M.service_pair(pair)
local remote_request=senior.robot_network_request_0338
assert(submitted.acted==1
  and submitted.detail=="remote-station-submitted-to-canonical-robot-0338"
  and remote_request and frontier.remote_station_request_1076==remote_request
  and frontier.remote_station_builder_1076==105,
  "covered frontier did not delegate original next-rank robot request")
assert(M.service_pair(pair).detail=="awaiting-native-robot-station-receipt",
  "unbuilt remote ghost was credited as a completed station")
storage.tech_priests.pairs_by_station[106]=intermediate
senior.robot_network_last_task_0338={
  phase="complete",request_value=remote_request,
  built_entity=intermediate.station,child_station_unit=106,
  child_priest_unit=206}
senior.robot_network_request_0338=nil
local remote_receipt=M.service_pair(pair)
assert(remote_receipt.acted==1
  and remote_receipt.detail=="robot-built-remote-intermediate-paired"
  and frontier.remote_station_unit_1076==106
  and frontier.remote_station_priest_1076==206,
  "1076 accepted no exact 0338 robot receipt or lost original priest identity")
intermediate.priest.valid=false
local lost=M.service_pair(pair)
assert(lost.blocked==1 and lost.detail=="remote-station-pair-or-identity-lost",
  "completed remote station persisted as success after priest identity loss")
intermediate.priest.valid=true
assert(M.service_pair(pair).detail=="verified-robot-built-remote-station",
  "valid original robot-built pair could not be reverified")
-- Native 41666700488 proved both powered ports, a paired remote
-- Intermediate and genuine iron ore, but the 0820 mission was never
-- adopted. A busy Magos can still verify an ALREADY built robot frontier;
-- this read-only path may not move/refund/debit its unrelated 0338 cargo.
local retained_build={phase="move-site",item_name="medium-electric-pole",
  carried={item_name="medium-electric-pole",count=1}}
local retained_cargo={item_name="medium-electric-pole",count=1}
pair.construction_task_0338=retained_build
pair.construction_custody_0338=retained_cargo
assert(M.service_pair(pair).detail=="canonical-builder-occupied",
  "unrelated active physical 0338 work bypassed builder exclusivity")
pair.roboport_expansion_goal_1076.remote_resource_item_1076="iron-ore"
pair.roboport_expansion_goal_1076.remote_resource_position_1076={x=101,y=0}
local previous_chain=_G.TechPriestsResourceStationChain0820
local adoption_checks=0
_G.TechPriestsResourceStationChain0820={
  adopt_verified_robot_frontier=function(root,item,target)
    assert(root==pair and item=="iron-ore"
      and target.x==101 and target.y==0,
      "complete robot-built route submitted foreign ore mission")
    adoption_checks=adoption_checks+1
    return false,"physical-ore-adoption-awaiting-canonical-check"
  end}
local verified_handoff=M.service_pair(pair)
assert(verified_handoff.waiting==1
  and verified_handoff.detail=="physical-ore-adoption-awaiting-canonical-check"
  and adoption_checks==1
  and pair.construction_task_0338==retained_build
  and pair.construction_custody_0338==retained_cargo
  and retained_cargo.count==1 and retained_build.carried.count==1
  and frontier.remote_station_unit_1076==106,
  "completed network ore-adoption was starved or stole Magos construction cargo")
_G.TechPriestsResourceStationChain0820=previous_chain
pair.construction_task_0338=nil
pair.construction_custody_0338=nil
pair.roboport_expansion_goal_1076.remote_resource_item_1076=nil
pair.roboport_expansion_goal_1076.remote_resource_position_1076=nil
pair.roboport_expansion_goal_1076.remote_station_item_1076=nil
pair.roboport_expansion_goal_1076.remote_station_position_1076=nil

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
-- A live port may briefly expose an invalid native logistic-network handle
-- during physical roboport mining/merging. Refuse without throwing or
-- submitting a 0338 request, then recover when the engine supplies a
-- valid network. This simulates Factorio's invalid-userdata read exception.
local stable_objects=objects
objects={}
local changing_port=port({x=0,y=0},true,19)
pole({x=0,y=4},7)
changing_port.logistic_cell.logistic_network=setmetatable(
  {valid=true,force=force},{__index=function(_,key)
    if key=="network_id" then
      error("LuaLogisticNetwork API call when LuaLogisticNetwork was invalid.")
    end
  end})
local changing_pair=make_pair({x=100,y=0})
local stale=M.service_pair(changing_pair)
assert(stale and stale.blocked==1
  and stale.detail=="no-powered-roboport"
  and not changing_pair.roboport_frontier_1076
  and not changing_pair.construction_request,
  "invalid native logistic network was read or authorized a physical build")
changing_port.logistic_cell.logistic_network=net
local resumed=M.service_pair(changing_pair)
assert(resumed.detail=="submitted-to-canonical-0338"
  and changing_pair.construction_request
  and changing_pair.roboport_frontier_1076,
  "revalidated native network did not resume physical 0338 planning")
objects=stable_objects
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
-- The scheduled broker must retain exact last-attempt evidence even when
-- the physical executor has not initialized a frontier. An anonymous pcall
-- failure count cannot diagnose a native 0338 construction refusal.
local observed=storage.tech_priests.roboport_expansion_broker_1076.last_attempt
assert(observed and observed.tick==game.tick
  and observed.failed==false
  and observed.station_unit==100
  and type(observed.detail)=="string" and #observed.detail>0
  and type(observed.status)=="string",
  "scheduled frontier lost its last exact refusal/attempt provenance")
local broker_zero=M.service_budgeted(nil,0)
assert(broker_zero.processed==0 and broker_zero.acted==0
  and broker_zero.detail=="zero-service-budget"
  and storage.tech_priests.roboport_expansion_broker_1076
    .last_attempt.detail=="zero-service-budget",
  "zero broker budget unexpectedly dispatched or concealed its refusal")
storage.tech_priests.pairs_by_station={}
local idle=M.service_budgeted(nil,1)
local idle_attempt=storage.tech_priests.roboport_expansion_broker_1076.last_attempt
assert(idle.processed==0 and idle_attempt
  and idle_attempt.detail=="no-active-goals"
  and idle_attempt.candidates==0 and idle_attempt.failed==false,
  "zero-candidate broker failed to preserve honest no-goal evidence")
-- A real industrial bootstrap can leave an unfunded 0338 discovery
-- candidate on the Magos indefinitely. Its request must survive while a
-- physically stocked 1076 pole build gets the sole builder; funded or
-- carrying work must never be displaced.
local Planner=require("scripts.core.construction_planner")
_G.TechPriestsConstructionPlanner0338=Planner
_G.TechPriestsStorageRoleAuthority0686.generic_station_inventories=function(p)
  return {{entity=p.station,inv={valid=true,
    get_item_count=function(item)return stock[item] or 0 end}}}
end
objects={}
port({x=0,y=0},true,19)
pole({x=0,y=4},7)
local yielded=make_pair({x=100,y=0})
yielded.priest.position={x=0,y=0}
yielded.priest.name="tech-priest"
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={
  position_allowed=function(_,p)
    return math.abs(p.x)<=28 and math.abs(p.y)<=28
  end}
local distant,why=Planner.frontier_site_contact_0338(
  yielded,"medium-electric-pole",{x=60,y=0})
assert(distant==nil and why=="frontier-no-physically-reachable-authorized-contact"
  and not yielded.construction_request and not yielded.construction_task_0338,
  "0338 accepted an out-of-radius frontier site without real movement authority")
local near=Planner.frontier_site_contact_0338(
  yielded,"medium-electric-pole",{x=18,y=0})
assert(near and math.abs(near.x)<=28,
  "0338 rejected a genuinely reachable near-grid physical contact")
local bootstrap={item="roboport",entity_name="roboport",
  position={x=10,y=10}}
yielded.construction_bootstrap_ghost_0645=bootstrap
yielded.construction_candidate_0338={
  item_name="roboport",request_field="construction_bootstrap_ghost_0645",
  request_value=bootstrap}
local prior_port_stock=stock.roboport
stock.roboport=1
local funded=M.service_pair(yielded)
assert(funded.detail=="canonical-builder-occupied:funded-bootstrap-request"
  and yielded.construction_candidate_0338
  and yielded.construction_request==nil,
  "funded bootstrap candidate was preempted by the frontier")
stock.roboport=0
local deferred=M.service_pair(yielded)
assert(deferred.detail=="submitted-to-canonical-0338"
  and yielded.construction_candidate_0338==nil
  and yielded.construction_bootstrap_ghost_0645==bootstrap
  and yielded.construction_request
  and yielded.construction_request.frontier_root_unit_1076==99,
  "unfunded bootstrap did not yield without losing its request")
local discovered=Planner.discover_pair(yielded,true)
assert(discovered and discovered.request_value==yielded.construction_request
  and discovered.request_field=="construction_request",
  "0338 rediscovery selected unfunded bootstrap over stocked frontier")
-- A discovery callback racing the dispatcher must also replace an old
-- unfunded bootstrap candidate without waiting for the normal cooldown.
yielded.construction_candidate_0338={
  item_name="roboport",request_field="construction_bootstrap_ghost_0645",
  request_value=bootstrap}
local rediscovered=Planner.discover_pair(yielded,false)
assert(rediscovered and rediscovered.request_value==yielded.construction_request
  and yielded.construction_bootstrap_ghost_0645==bootstrap,
  "unfunded candidate rediscovery race stole the frontier request")
local guarded=make_pair({x=100,y=0})
-- This custody-negative must have a physically placeable priest contact;
-- otherwise it tests geometry refusal instead of active-cargo protection.
guarded.priest.position={x=0,y=0}
guarded.priest.name="tech-priest"
guarded.construction_custody_0338={item_name="medium-electric-pole",count=1}
local blocked_guard=M.service_pair(guarded)
assert(blocked_guard.detail=="canonical-builder-occupied"
  and guarded.construction_custody_0338.count==1
  and not guarded.construction_request,
  "active physical construction cargo was preempted")
-- Active construction must win even if there is NO accessible expansion
-- geometry. The refusal has to come from existing 0338 custody, not from
-- opportunistic movement/placement failure that changes on another map.
local nonreachable=make_pair({x=100,y=0})
nonreachable.priest.position={x=0,y=0}
nonreachable.priest.name="tech-priest"
local owned_task={phase="move-site",item_name="medium-electric-pole",
  carried={item_name="medium-electric-pole",count=1}}
nonreachable.construction_task_0338=owned_task
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418.position_allowed=function()
  return false
end
local task_guard=M.service_pair(nonreachable)
assert(task_guard.detail=="canonical-builder-occupied"
  and nonreachable.construction_task_0338==owned_task
  and owned_task.carried.count==1
  and nonreachable.construction_request==nil
  and nonreachable.roboport_frontier_1076==nil,
  "in-flight 0338 physical cargo was displaced by unreachable expansion")

-- Once a frontier request is submitted and 0338 starts that SAME request,
-- its pending identity must be retained until the real construction receipt.
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418.position_allowed=function(_,pos)
  return math.abs(pos.x)<=28 and math.abs(pos.y)<=28
end
local in_flight=make_pair({x=100,y=0})
in_flight.priest.position={x=0,y=0}
in_flight.priest.name="tech-priest"
local ordered=M.service_pair(in_flight)
assert(ordered.detail=="submitted-to-canonical-0338"
  and in_flight.construction_request,
  "could not stage pending frontier receipt integrity probe")
local pending_request=in_flight.construction_request
local executing={phase="move-source",request_value=pending_request}
in_flight.construction_task_0338=executing
local pending_guard=M.service_pair(in_flight)
assert(pending_guard.detail=="awaiting-counted-0338-build"
  and in_flight.construction_task_0338==executing
  and in_flight.construction_request==pending_request
  and in_flight.roboport_frontier_1076.pending.request==pending_request,
  "in-flight frontier construction was restarted or its receipt replaced")
-- The native engine can time out approaching a pole. Retry only after
-- the same 0338 task has actually returned its ONE item; repeated failures
-- must become a bounded visible blocker, never infinite duplicate builds.
local refunded_pair=make_pair({x=100,y=0})
refunded_pair.priest.position={x=0,y=0}
refunded_pair.priest.name="tech-priest"
assert(M.service_pair(refunded_pair).detail=="submitted-to-canonical-0338",
  "physical refund scenario did not submit a first pole")
local first_refund_request=refunded_pair.construction_request
for n=1,3 do
  local req=refunded_pair.construction_request
  assert(req and req.item_name=="medium-electric-pole",
    "refunded pole attempt lost original physical item identity")
  refunded_pair.construction_last_task_0338={
    phase="aborted",request_value=req,built_entity=nil,
    carried={item_name="medium-electric-pole",count=0},
    result="construction-timeout:move-site:medium-electric-pole;custody-returned-source"}
  local decision=M.service_pair(refunded_pair)
  if n<3 then
    assert(decision.detail=="physically-refunded-frontier-site-replan"
      and refunded_pair.construction_request==nil
      and refunded_pair.roboport_frontier_1076.pending==nil
      and refunded_pair.roboport_frontier_1076.refunded_replans_1076==n,
      "exact physical refund was not safely accepted for bounded retry")
    assert(M.service_pair(refunded_pair).detail=="submitted-to-canonical-0338"
      and refunded_pair.construction_request~=req,
      "refunded item was not replanned with a fresh request identity")
    local changed=refunded_pair.construction_request
    local anchor=refunded_pair.roboport_frontier_1076.power_anchor.position
    local function squared(point)
      return (point.x-anchor.x)^2+(point.y-anchor.y)^2
    end
    assert(squared(changed.position)<squared(req.position),
      "physically refunded pole retry repeated the same distant movement site")
  else
    assert(decision.blocked==1
      and refunded_pair.roboport_frontier_1076.status=="blocked"
      and refunded_pair.construction_request==req,
      "repeated physical construction timeouts failed to cap retries")
  end
end
assert(first_refund_request~=refunded_pair.construction_request,
  "retry reused a stale aborted request")

-- Native 41516621302: the second pole timed out on move-source,
-- BEFORE physical pickup. 0338 left the real item at the original source
-- and recorded an empty-custody terminal. Permit only bounded replanning
-- after reading the same live source inventory, never by crediting a pole.
local function stage_source_timeout(p,remaining,source_force,carried)
  local req=p.construction_request
  assert(req and req.item_name=="medium-electric-pole")
  p.construction_last_task_0338={
    phase="aborted",request_value=req,item_name=req.item_name,
    built_entity=nil,carried=carried,
    source_entity={valid=true,surface=surface,force=source_force or force},
    source_inv={valid=true,get_item_count=function(item)
      assert(item==req.item_name)
      return remaining
    end},
    result="construction-timeout:move-source:medium-electric-pole;empty-custody"}
end
local source_retry=make_pair({x=100,y=0})
source_retry.priest.position={x=0,y=0}
source_retry.priest.name="tech-priest"
assert(M.service_pair(source_retry).detail=="submitted-to-canonical-0338")
for attempt=1,3 do
  local old_request=source_retry.construction_request
  stage_source_timeout(source_retry,1,force,nil)
  local result=M.service_pair(source_retry)
  if attempt<3 then
    assert(result.detail=="physically-stocked-frontier-source-replan"
      and source_retry.construction_request==nil
      and source_retry.roboport_frontier_1076.pending==nil
      and source_retry.roboport_frontier_1076.refunded_replans_1076==attempt,
      "real source-stocked move-source timeout was not boundedly replanned")
    assert(M.service_pair(source_retry).detail=="submitted-to-canonical-0338"
      and source_retry.construction_request~=old_request,
      "move-source retry reused an aborted construction request")
  else
    assert(result.blocked==1
      and source_retry.roboport_frontier_1076.status=="blocked"
      and source_retry.construction_request==old_request,
      "move-source timeouts bypassed the existing two-retry bound")
  end
end
local function rejected_source_timeout(remaining,source_force,carried)
  local p=make_pair({x=100,y=0})
  p.priest.position={x=0,y=0}
  p.priest.name="tech-priest"
  assert(M.service_pair(p).detail=="submitted-to-canonical-0338")
  local req=p.construction_request
  stage_source_timeout(p,remaining,source_force,carried)
  local decision=M.service_pair(p)
  assert(decision.blocked==1
    and p.roboport_frontier_1076.status=="blocked"
    and p.construction_request==req
    and p.roboport_frontier_1076.refunded_replans_1076==nil,
    "missing, foreign or already-held source item was improperly retried")
end
rejected_source_timeout(0,force,nil)
rejected_source_timeout(1,{index=999},nil)
rejected_source_timeout(1,force,{item_name="medium-electric-pole",count=1})

local still_held=make_pair({x=100,y=0})
still_held.priest.position={x=0,y=0}
still_held.priest.name="tech-priest"
assert(M.service_pair(still_held).detail=="submitted-to-canonical-0338")
local held_req=still_held.construction_request
still_held.construction_last_task_0338={
  phase="aborted",request_value=held_req,built_entity=nil,
  carried={item_name="medium-electric-pole",count=1},
  result="construction-timeout:move-site:medium-electric-pole"}
local unrefunded=M.service_pair(still_held)
assert(unrefunded.blocked==1
  and still_held.roboport_frontier_1076.status=="blocked"
  and still_held.construction_request==held_req
  and still_held.roboport_frontier_1076.refunded_replans_1076==nil,
  "unreturned physical item was improperly reissued")
-- Native run 41529875973: three real grid-1 poles were built, then
-- the next pole had no 0418-authorized contact. A closer port powered by an
-- EXISTING connected pole must be tried before blocking the whole frontier.
-- The fallback must only request 0338; no item/entity may appear from 1076.
-- Earlier unfunded-bootstrap negative intentionally left roboport stock at 0;
-- restore the original real-stock fixture before testing a funded build.
stock.roboport=prior_port_stock
local previous_objects=objects
objects={}
local short_origin=port({x=0,y=0},true,19)
pole({x=25.5,y=6.5},7)
local middle_pole=pole({x=33.5,y=5.5},7)
local last_pole=pole({x=41.5,y=3.5},7)
local function pole_dead_end_pair()
  local p=make_pair({x=100,y=0})
  p.priest.name="tech-priest"
  p.priest.position={x=39,y=3}
  p.roboport_frontier_1076={version=M.version,
    target={x=100,y=0},source_port=short_origin,
    -- Earlier multi-segment receipts may legitimately renumber this
    -- shared native-network fixture; retain its CURRENT live identity.
    electric_network_id=7,logistic_network_id=net.network_id,
    power_anchor=last_pole,site={x=52,y=0},
    status="planning",segments=0,poles_built=3,started_tick=game.tick}
  return p
end
local prior_contact=_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338
_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=
  function(_,name,pos)
    if name=="roboport" and pos.x<=39 and pos.x>=30 then
      return {x=pos.x-1.4,y=pos.y}
    end
    return nil,"outside-existing-0418-authority"
  end
-- The indexed 0579 entity view can be stale even after a real
-- 0338 receipt. The fallback must explicitly request fresh native poles.
local prior_scan=_G.TechPriestsScanRouting0610.find_entities
local fresh_pole_scans=0
_G.TechPriestsScanRouting0610.find_entities=function(s,filter,opts)
  if filter.type=="electric-pole" and filter.limit==M.scan_limit then
    if opts.require_fresh~=true then return {} end
    fresh_pole_scans=fresh_pole_scans+1
  end
  return prior_scan(s,filter,opts)
end
local close_port=pole_dead_end_pair()
local port_stock_before=stock.roboport
local fallback=M.service_pair(close_port)
local port_req=close_port.construction_request
assert(fallback.detail=="submitted-to-canonical-0338"
  and port_req and port_req.entity_name=="roboport"
  and close_port.roboport_frontier_1076.pending.request==port_req
  and close_port.roboport_frontier_1076.power_anchor
  and close_port.roboport_frontier_1076.power_anchor.electric_network_id==7
  and port_req.position.x<=39
  and fresh_pole_scans>=1
  and stock.roboport==port_stock_before,
  "three counted poles did not resite a reachable powered port without free stock: "..tostring(fallback.detail).." request="..tostring(port_req and port_req.entity_name).." site="..tostring(close_port.roboport_frontier_1076.site and close_port.roboport_frontier_1076.site.x))
local new_port=port(port_req.position,true,19)
stock.roboport=stock.roboport-1 -- only the canonical 0338 fixture debits it
close_port.construction_last_task_0338={
  phase="complete",request_value=port_req,built_entity=new_port}
close_port.construction_request=nil
-- Native 41557419132: genuine 0338 receipt accepted an original-grid
-- roboport, but the prior cached logistic_network_id was never updated
-- after Factorio merged the physical logistics cells.
-- Simulate the NATIVE network renumbering, not synthetic connectivity.
local previous_network_id=net.network_id
net.network_id=29
local port_receipt=M.service_pair(close_port)
assert(port_receipt.acted==1
  and close_port.roboport_frontier_1076.logistic_network_id==29
  and close_port.roboport_frontier_1076.segments==1
  and close_port.roboport_frontier_1076.source_port==new_port
  and close_port.roboport_frontier_1076.pending==nil
  and stock.roboport==port_stock_before-1,
  "nearer roboport did not require an exact real 0338 receipt")
-- Further planning must NOT stop solely because the original cached ID
-- changed while both real ports agree on a valid current native network.
local continued=M.service_pair(close_port)
assert(continued.detail~="source-roboport-original-network-diverged"
  and not(continued.blocked==1
    and close_port.roboport_frontier_1076.blocked_reason==
      "source-roboport-original-network-diverged"),
  "renumbered but joined real logistic network was rejected after 0338 receipt")
-- Native 41560203624: a first physically receipted port at x=38
-- joined the original grid, but the planner's shortest next candidate
-- was still beyond the original Magos's 0418 construction contact.
-- A distinct second port must be requested at a truly reachable,
-- nonoverlapping site using a SECOND real stocked item; no 1076 debit.
_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=
  function(_,name,pos)
    if name=="roboport" and pos.x==44 and pos.y==0 then
      return {x=40,y=0}
    end
    return nil,"outside-existing-0418-authority"
  end
local second_pair=make_pair({x=100,y=0})
second_pair.priest.name="tech-priest"
second_pair.priest.position={x=39,y=0}
second_pair.roboport_frontier_1076={version=M.version,
  target={x=100,y=0},source_port=new_port,
  electric_network_id=7,logistic_network_id=net.network_id,
  power_anchor=last_pole,status="planning",
  segments=1,poles_built=3,started_tick=game.tick}
local second_stock=stock.roboport
local second_result=M.service_pair(second_pair)
local second_request=second_pair.construction_request
assert(second_result.detail=="submitted-to-canonical-0338"
  and second_request and second_request.entity_name=="roboport"
  and second_request.position.x==44 and second_request.position.y==0
  and second_pair.roboport_frontier_1076.pending.request==second_request
  and stock.roboport==second_stock
  and #surface.find_entities_filtered{type="roboport",
    position=second_request.position,radius=0.75,
    force=force,limit=3}==0,
  "second original-grid port was not requested through 0338 at a legal nonoverlapping site with unchanged physical stock")
net.network_id=previous_network_id
_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=
  function()return nil,"outside-existing-0418-authority"end
local denied_port=pole_dead_end_pair()
local stock_at_refusal=stock.roboport
local no_contact=M.service_pair(denied_port)
assert(no_contact.blocked==1
  and no_contact.detail=="no-wire-connected-pole-site-with-authorized-priest-contact"
  and not denied_port.construction_request
  and stock.roboport==stock_at_refusal,
  "unreachable port fallback bypassed canonical priest contact or spent an item")
_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=prior_contact
_G.TechPriestsScanRouting0610.find_entities=prior_scan
objects=previous_objects
stock.roboport=prior_port_stock
-- Native Factorio 41548085823: three original-grid poles completed, then
-- the carried, physically debited 4x4 roboport remained in 0338 move-site.
-- A 1.4-tile CENTER standoff lies inside that footprint; a two-tile
-- center-distance requirement makes every exterior contact impossible.
-- Preserve the original two-tile reach from the native collision BOX.
local wide=make_pair({x=100,y=0})
wide.priest.name="tech-priest"
wide.priest.position={x=31,y=0}
local movement_controller=_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418
local original_allowed=movement_controller.position_allowed
movement_controller.position_allowed=function(_,pos)
  return pos.x>=0 and pos.x<=39 and math.abs(pos.y)<=28
end
local wide_site={x=38,y=0}
local exterior=Planner.frontier_site_contact_0338(wide,"roboport",wide_site)
assert(exterior and exterior.x<36 and exterior.x>=34
  and math.abs(exterior.y)<0.01
  and 38-exterior.x>2 and 36-exterior.x<=2,
  "wide roboport was planned inside its collision footprint or beyond two-tile edge reach")
-- The x=44 second-site planner fixture above uses a STUB contact approval.
-- It is NOT a test that the original Magos may physically approach x=44.
-- Prove this distinction against the real 0338 collision/0418 preflight:
-- with x<=39 genuine contact is impossible, despite legal site geometry.
local second_site={x=44,y=0}
local stocked_before_contact=stock.roboport
local magos_second_contact=Planner.frontier_site_contact_0338(
  wide,"roboport",second_site)
assert(magos_second_contact==nil
  and stock.roboport==stocked_before_contact,
  "second-site mocked approval concealed an unauthorized Magos build")
-- A real subordinate near x=42 has a distinct, bounded home authority.
-- Only its OWN 0338 may ever pick up, debit and physically build a port;
-- this contact preflight is NOT a delegated construction acceptance.
local nearby_worker=make_pair({x=100,y=0})
nearby_worker.station.name="senior-cogitator-station"
nearby_worker.station.unit_number=933
nearby_worker.station.position={x=42,y=0}
nearby_worker.priest.name="tech-priest"
nearby_worker.priest.position={x=42,y=0}
movement_controller.position_allowed=function(pair,pos)
  return pair==nearby_worker and pos.x>=35 and pos.x<=53
    and math.abs(pos.y)<=28
end
local senior_second_contact=Planner.frontier_site_contact_0338(
  nearby_worker,"roboport",second_site)
assert(senior_second_contact and senior_second_contact.x>39
  and senior_second_contact.x<42
  and stock.roboport==stocked_before_contact,
  "authorized nearby worker could not reach the second-site exterior without item spending")
movement_controller.position_allowed=function(_,pos)
  return pos.x>=0 and pos.x<=39 and math.abs(pos.y)<=28
end
local prior_move=_G.tech_priests_request_movement_0418
local routed
_G.tech_priests_request_movement_0418=function(_,pos,reason,opts)
  routed={pos=pos,reason=reason,owner=opts.owner}
  return true
end
local wide_task={phase="move-site",item_name="roboport",entity_name="roboport",
  position=wide_site,site_reason="powered-roboport-frontier-1076",
  carried={item_name="roboport",count=1},
  active_started_tick_0338=game.tick,travel_allowance_ticks_0338=2000}
wide.construction_task_0338=wide_task
wide.construction_custody_0338={item_name="roboport",count=1}
local approaching=Planner.service_pair(wide,"native-wide-roboport-approach")
assert(approaching.detail=="moving-site" and routed
  and routed.reason=="construction-site-standoff-0338"
  and routed.owner=="construction-planner-0338"
  and routed.pos.x<36 and routed.pos.x>=34
  and wide_task.carried.count==1
  and wide.construction_custody_0338.count==1,
  "wide roboport approach lost original physical custody or targeted an interior tile")
movement_controller.position_allowed=function()return false end
local forbidden=Planner.frontier_site_contact_0338(wide,"roboport",wide_site)
assert(forbidden==nil and wide_task.carried.count==1,
  "wide footprint contact bypassed the original 0418 movement boundary")
movement_controller.position_allowed=original_allowed
local real_box=prototypes.entity.roboport.collision_box
prototypes.entity.roboport.collision_box=nil
local unknown=Planner.frontier_site_contact_0338(wide,"roboport",wide_site)
assert(unknown==nil and wide_task.carried.count==1,
  "unknown native roboport collision geometry authorized a free build")
prototypes.entity.roboport.collision_box=real_box
_G.tech_priests_request_movement_0418=prior_move

-- Method II: after the Magos's real 0418 contact ends, the original
-- direct Senior may execute 0338 from its OWN stocked inventory. The
-- frontier remains on the original Magos and accepts only that exact
-- delegated worker's physical receipt, never a planned/ghost entity.
do
  local original_storage=storage
  local original_hierarchy=_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480
  local original_contact=_G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338
  local original_count=_G.TechPriestsStorageRoleAuthority0686.generic_item_count
  local root=make_pair({x=100,y=0})
  local senior={station={valid=true,name="senior-cogitator-station",
    unit_number=101,force=force,surface=surface,position={x=42,y=0}},
    priest={valid=true},test_stock={roboport=2,
      ["medium-electric-pole"]=12}}
  storage={tech_priests={pairs_by_station={[99]=root,[101]=senior}}}
  local direct=true
  _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
    rank=function(p)return p==root and 4 or p==senior and 3 or 0 end,
    is_direct_subordinate=function(parent,child)
      return direct and parent==root and child==senior
    end}
  _G.TechPriestsStorageRoleAuthority0686.generic_item_count=
    function(p,item)
      return p.test_stock and (p.test_stock[item]or 0) or (stock[item]or 0)
    end
  _G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=
    function(p,name,pos)
      if name=="roboport" and pos.x>=43 and pos.x<=48 then
        if p==senior then return {x=pos.x-3,y=pos.y}end
        return nil,"magos-0418-authority-ended"
      end
      return nil,"no-authorized-contact"
    end
  local original_network=net.network_id
  net.network_id=19
  local origin=port({x=38,y=0},true,19)
  local anchor=pole({x=41.5,y=3.5},7)
  local function stage()
    local p=make_pair({x=100,y=0})
    storage.tech_priests.pairs_by_station[99]=p
    root=p
    p.roboport_frontier_1076={version=M.version,
      target={x=100,y=0},source_port=origin,
      electric_network_id=7,logistic_network_id=net.network_id,
      power_anchor=anchor,status="planning",segments=1,
      poles_built=3,started_tick=game.tick}
    return p
  end
  local delegated=stage()
  local before=senior.test_stock.roboport
  local proposed=M.service_pair(delegated)
  local request=senior.construction_request
  assert(proposed.detail=="submitted-to-canonical-0338"
    and request and request.entity_name=="roboport"
    and request.frontier_root_unit_1076==99
    and request.frontier_builder_unit_1076==101
    and not delegated.construction_request
    and senior.test_stock.roboport==before,
    "ranked Senior did not receive a physically funded 0338 frontier request")
  -- The root-only 0338 construction priority was insufficient for a
  -- delegated Senior: its unfunded bootstrap candidate could be rediscovered
  -- after the frontier request was submitted. Exercise REAL 0338 discovery,
  -- not only the outer 1076 site planner or mocked 0488 recommendation.
  local original_sources=_G.TechPriestsStorageRoleAuthority0686.generic_station_inventories
  _G.TechPriestsStorageRoleAuthority0686.generic_station_inventories=
    function(p)
      return {{entity=p.station,inv={valid=true,
        get_item_count=function(item)
          return p.test_stock and (p.test_stock[item]or 0)
            or (stock[item]or 0)
        end}}}
    end
  local prior_poles=senior.test_stock["medium-electric-pole"]
  senior.test_stock["medium-electric-pole"]=0
  local queued_bootstrap={item="medium-electric-pole",
    entity_name="medium-electric-pole",position={x=42,y=8}}
  senior.construction_bootstrap_ghost_0645=queued_bootstrap
  local real_discovered=Planner.discover_pair(senior,true)
  assert(real_discovered and real_discovered.request_value==request
    and real_discovered.request_field=="construction_request"
    and real_discovered.site_reason=="powered-roboport-frontier-1076",
    "0338 prioritized a Senior's unfunded bootstrap over its exact delegated frontier")
  -- Reproduce a discovery callback racing the dispatcher: a stale,
  -- unfunded bootstrap candidate must yield with no inventory mutation.
  senior.construction_candidate_0338={
    item_name="medium-electric-pole",
    request_field="construction_bootstrap_ghost_0645",
    request_value=queued_bootstrap}
  local restored=Planner.discover_pair(senior,false)
  assert(restored and restored.request_value==request
    and senior.construction_bootstrap_ghost_0645==queued_bootstrap
    and senior.test_stock.roboport==before,
    "Senior stale bootstrap discovery reclaimed an already submitted frontier request")
  -- Funded unrelated construction is still higher priority and cannot be
  -- silently discarded. No item is removed by this discovery test.
  senior.test_stock["medium-electric-pole"]=1
  local funded_discovery=Planner.discover_pair(senior,true)
  assert(funded_discovery
    and funded_discovery.request_field=="construction_bootstrap_ghost_0645"
    and funded_discovery.request_value==queued_bootstrap
    and senior.test_stock["medium-electric-pole"]==1
    and senior.construction_request==request,
    "delegated frontier bypassed physically funded Senior bootstrap")
  senior.test_stock["medium-electric-pole"]=0
  senior.construction_bootstrap_ghost_0645=nil
  senior.construction_candidate_0338=nil
  direct=false
  local foreign_discovery=Planner.discover_pair(senior,true)
  assert(foreign_discovery==nil and senior.construction_request==request,
    "0338 fallback accepted a delegated frontier after live rank edge was lost")
  -- A previously cached, physically funded candidate must not bypass
  -- the fresh 0338 discovery refusal when the Senior loses its rank edge.
  -- This is the actual dispatcher-to-executor boundary, before site
  -- reservation, movement, inventory debit or any world construction.
  senior.construction_candidate_0338=real_discovered
  local stale_rank=Planner.service_pair(senior,"revoked-delegation")
  assert(stale_rank.detail=="reservation-blocked:frontier-request-ownership-stale"
    and not senior.construction_task_0338
    and not senior.construction_custody_0338
    and senior.construction_request==request
    and senior.test_stock.roboport==before,
    "cached 0338 candidate spent a Senior's item after rank revocation")
  direct=true
  -- An exact but superseded request also cannot be executed from a
  -- previously discovered candidate, even while the rank edge is valid.
  local replacement={item_name=request.item_name,
    entity_name=request.entity_name,position=request.position,
    site_reason=request.site_reason,
    frontier_root_unit_1076=99,frontier_builder_unit_1076=101}
  senior.construction_request=replacement
  local stale_request=Planner.service_pair(senior,"superseded-delegation")
  assert(stale_request.detail=="reservation-blocked:frontier-request-ownership-stale"
    and not senior.construction_task_0338
    and not senior.construction_custody_0338
    and senior.construction_request==replacement
    and senior.test_stock.roboport==before,
    "cached 0338 candidate spent an item after exact request replacement")
  senior.construction_candidate_0338=nil
  senior.construction_request=request
  senior.test_stock["medium-electric-pole"]=prior_poles
  _G.TechPriestsStorageRoleAuthority0686.generic_station_inventories=original_sources
  local actual=port(request.position,true,19)
  senior.test_stock.roboport=senior.test_stock.roboport-1
  senior.construction_last_task_0338={phase="complete",
    request_value=request,built_entity=actual}
  senior.construction_request=nil
  net.network_id=30
  local verified=M.service_pair(delegated)
  assert(verified.acted==1
    and delegated.roboport_frontier_1076.segments==2
    and delegated.roboport_frontier_1076.source_port==actual
    and delegated.roboport_frontier_1076.last_receipt==
      senior.construction_last_task_0338
    and senior.test_stock.roboport==before-1,
    "Magos accepted no exact delegated Senior physical receipt")
  actual.valid=false
  senior.test_stock.roboport=0
  net.network_id=19
  local empty=stage()
  local no_item=M.service_pair(empty)
  assert(no_item.blocked==1 and not senior.construction_request
    and not empty.construction_request,
    "unfunded Senior created a remote construction request")
  senior.test_stock.roboport=2
  direct=false
  local foreign=stage()
  local no_rank=M.service_pair(foreign)
  assert(no_rank.blocked==1 and not senior.construction_request,
    "foreign Senior bypassed live ranked hierarchy")
  direct=true
  senior.construction_custody_0338={item_name="roboport",count=1}
  local busy=stage()
  local no_custody=M.service_pair(busy)
  assert(no_custody.blocked==1 and not senior.construction_request,
    "competing Senior cargo was stolen by frontier planning")
  senior.construction_custody_0338=nil
  -- Native 41567706764 observed a stocked, real 0418-reachable Senior
  -- while 1076 blocked at second-site planning. The Senior may have a
  -- *discovery-only* 0338 candidate; selecting it must not steal funded
  -- work or real cargo. The ORIGINAL 0338 yield remains the final arbiter.
  local planner=_G.TechPriestsConstructionPlanner0338
  local prior_yield=planner.yield_unfunded_frontier_candidate_0338
  local yield_calls=0
  planner.yield_unfunded_frontier_candidate_0338=function(worker)
    yield_calls=yield_calls+1
    assert(worker==senior,"frontier tried yielding a foreign builder")
    local candidate=worker.construction_candidate_0338
    if candidate and candidate.item_name=="roboport" then
      return false,"funded-construction-candidate"
    end
    worker.construction_candidate_0338=nil
    return true,"unfunded-candidate-yielded"
  end
  senior.construction_candidate_0338={item_name="wooden-chest",
    source="construction-planner-0338",tick=game.tick}
  local unfunded_candidate=stage()
  local safe_yield_stock=senior.test_stock.roboport
  local yielded=M.service_pair(unfunded_candidate)
  local yielded_request=senior.construction_request
  assert(yielded.detail=="submitted-to-canonical-0338"
    and yield_calls==1 and not senior.construction_candidate_0338
    and yielded_request and yielded_request.frontier_root_unit_1076==99
    and yielded_request.frontier_builder_unit_1076==101
    and unfunded_candidate.roboport_frontier_1076.pending.request==yielded_request
    and senior.test_stock.roboport==safe_yield_stock,
    "unfunded Senior discovery monopolized an authorized stocked frontier builder")
  senior.construction_request=nil -- source fixture cleanup, no item debited
  local funded_candidate={item_name="roboport",
    source="construction-planner-0338",tick=game.tick}
  senior.construction_candidate_0338=funded_candidate
  local funded_wait=stage()
  local failed_yield=M.service_pair(funded_wait)
  assert(failed_yield.waiting==1
    and failed_yield.detail=="canonical-builder-occupied:funded-construction-candidate"
    and senior.construction_candidate_0338==funded_candidate
    and not senior.construction_request
    and not funded_wait.roboport_frontier_1076.pending
    and senior.test_stock.roboport==safe_yield_stock
    and yield_calls==2,
    "funded Senior construction candidate was silently preempted or spent")
  senior.construction_candidate_0338=nil
  planner.yield_unfunded_frontier_candidate_0338=prior_yield
  net.network_id=original_network
  _G.TechPriestsConstructionPlanner0338.frontier_site_contact_0338=original_contact
  _G.TechPriestsStorageRoleAuthority0686.generic_item_count=original_count
  _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480=original_hierarchy
  storage=original_storage
end
print("[roboport-expansion-1076] PASS sequential pole/port receipts, real coverage, grid continuity, no scripted items, blocked wrong-grid pole and roboport, late physical reconnection without double debit")
