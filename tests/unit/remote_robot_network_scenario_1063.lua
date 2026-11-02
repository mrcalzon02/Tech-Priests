-- Scenario S2 / 1063: distinguish a real powered, robot-equipped network
-- from disconnected, depleted or robotless ports. The existing 0714 authority
-- is READ-ONLY; this is NOT proof that robots built a remote station.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Readiness=require("scripts.core.roboport_readiness_0714")
game={tick=10630}
storage={tech_priests={}}
defines={inventory={roboport_robot=1,roboport_material=2}}
prototypes={item={
  ["construction-robot"]={place_result={type="construction-robot"}},
  ["logistic-robot"]={place_result={type="logistic-robot"}},
  ["repair-pack"]={type="repair-tool"},
}}
local force={index=1}
local find_calls=0
local surface={index=1,find_entities_filtered=function(spec)
  find_calls=find_calls+1
  assert(spec and spec.force==force and spec.limit==64,
    "S2 inspected robotic infrastructure with an unbounded scan")
  return {}
end}
local robot_stock={["construction-robot"]=3,["logistic-robot"]=1}
local robot_inventory={valid=true,
  get_contents=function() return robot_stock end}
local repair_stock={["repair-pack"]=0}
local can_supply_packs=true
local material_inventory={valid=true,
  get_contents=function() return repair_stock end,
  can_insert=function(_,stack)
    return can_supply_packs and stack.name=="repair-pack" and stack.count==1
  end}
local network={all_construction_robots=3,available_construction_robots=2,
  all_logistic_robots=1,available_logistic_robots=1,cells={{valid=true}}}
local cell={logistic_network=network,construction_radius=55,
  logistic_radius=25,stationed_construction_robot_count=3,
  stationed_logistic_robot_count=1,charging_robots={}}
local powered=true
local port={valid=true,type="roboport",name="roboport",
  unit_number=5101,position={x=25,y=0},force=force,surface=surface,
  prototype={recharge_minimum=100},electric_buffer_size=100000,
  energy=10000,logistic_cell=cell,
  is_connected_to_electric_network=function()return powered end,
  get_inventory=function(_,kind)
    if kind==defines.inventory.roboport_robot then return robot_inventory end
    if kind==defines.inventory.roboport_material then return material_inventory end
  end}
local pair={station={valid=true,unit_number=5001,
  position={x=0,y=0},force=force,surface=surface},
  priest={valid=true,unit_number=5002}}
local function inspect()return Readiness.inspect_entity(pair,port,true)end
local active,why=inspect()
assert(why=="inspected" and active and active.read_only==true
  and active.placement_authority==false
  and active.state=="manual-repair-pack-service-eligible"
  and active.network.present==true
  and active.network.available_construction==2
  and active.coverage.construction_radius==55
  and active.energy.connected==true
  and active.energy.energy==10000
  and active.robots.construction==3 and active.robots.logistic==1
  and active.robot_population_monitor_only==true
  and robot_stock["construction-robot"]==3 and find_calls==1,
  "S2 did not recognize physically powered robot-covered network readiness")
-- No network means there is no valid construction-coverage authority.
cell.logistic_network=nil
local missing=inspect()
assert(missing and missing.state=="logistic-network-missing"
  and missing.severity=="blocked" and robot_stock["construction-robot"]==3,
  "S2 falsely considered an isolated roboport a working robot network")
cell.logistic_network=network
powered=false
local powerless=inspect()
assert(powerless and powerless.state=="electric-network-missing"
  and powerless.severity=="blocked",
  "S2 credited construction capability without an electrical connection")
powered=true
port.energy=0
local drained=inspect()
assert(drained and drained.state=="energy-buffer-low"
  and drained.severity=="blocked",
  "S2 credited a drained roboport as ready")
port.energy=10000
network.all_construction_robots=0
network.available_construction_robots=0
local no_robots=inspect()
assert(no_robots and no_robots.state=="no-construction-robots-monitor"
  and no_robots.severity=="monitor"
  and no_robots.placement_authority==false,
  "S2 mistook a powered but robotless port for construction acceptance")
network.all_construction_robots=3
network.available_construction_robots=2
can_supply_packs=false
local no_repairs=inspect()
assert(no_repairs and no_repairs.state=="no-compatible-repair-pack"
  and no_repairs.severity=="blocked",
  "S2 ignored read-only maintenance supply constraints")
-- 0714 can inspect the ROBOT network but cannot create a ghost, place a
-- station, debit a station item or command a construction robot. The next
-- production gate must live under existing construction/robot authorities.
assert(robot_stock["construction-robot"]==3
  and repair_stock["repair-pack"]==0
  and port.valid==true and pair.station.valid==true,
  "S2 readiness monitoring mutated physical items or station identity")
print("[remote-expansion-scenario-S2-1063] PASS powered network observations, disconnected/unpowered/drained/robotless refusals; robot-built outpost still unimplemented")

-- 1070: the actual canonical 0338 construction executor, not the read-only
-- 0714 observer, submits a real station ghost. A Factorio construction robot
-- must consume the logistic network item before the new station can be
-- accepted. These mocks prove the SOURCE contract only; the native engine
-- still has to prove robot dispatch, building and save/reload.
local Planner=require("scripts.core.construction_planner")
_G.TechPriestsRoboportReadiness0714=Readiness
pair.station.name="planetary-magos-cogitator-station"
cell.transmitting=true
cell.is_in_construction_range=function(pos)
  return pos.x>=35 and pos.x<=75 and math.abs(pos.y)<=40
end
network.force=force
network.network_id=777
local logistic_items={["senior-cogitator-station"]=1}
network.get_item_count=function(item)
  return logistic_items[item] or 0
end
prototypes.item["senior-cogitator-station"]={
  place_result={name="senior-cogitator-station",type="container"}}
prototypes.entity={["senior-cogitator-station"]={
  name="senior-cogitator-station",type="container"}}
local real_station,ghost
local ghost_creations=0
surface.find_entities_filtered=function(spec)
  if spec.type=="roboport" then
    assert(spec.force==force and spec.limit==Readiness.max_entities,
      "robot construction bypassed the bounded 0714 observer")
    return {port}
  end
  if spec.name=="senior-cogitator-station" then
    return real_station and {real_station} or {}
  end
  assert(spec.force==force and spec.limit==64,
    "robot network readiness issued an unbounded or foreign scan")
  return {}
end
surface.can_place_entity=function(spec)
  assert(spec.name=="senior-cogitator-station"
    and spec.force==force and spec.position.x==55,
    "robot ghost construction did not validate the real site")
  return true
end
surface.create_entity=function(spec)
  assert(spec.name=="entity-ghost"
    and spec.inner_name=="senior-cogitator-station"
    and spec.position.x==55 and spec.force==force,
    "robot builder bypassed the native Factorio ghost API")
  ghost_creations=ghost_creations+1
  ghost={valid=true,name="entity-ghost",
    ghost_name="senior-cogitator-station",
    position={x=55,y=0},force=force,surface=surface}
  return ghost
end
local claims,releases=0,0
_G.TechPriestsWorkReservations0601={
  categories={"construction-placement"},
  root=function()return {reservations={["construction-placement"]={}}}end,
  claim=function()claims=claims+1;return true,"claimed"end,
  release=function()releases=releases+1;return true end,
}
local request={root_station_unit=5001,
  surface_index=1,force_index=1,
  item_name="senior-cogitator-station",
  entity_name="senior-cogitator-station",
  position={x=55,y=0},site_reason="S2-physical-robot-outpost"}
pair.robot_network_request_0338=request
local function refuse(expected)
  local result=Planner.service_robot_network_pair_0338(pair)
  assert(result.blocked==1 and result.detail==expected
    and ghost_creations==0 and claims==0
    and logistic_items["senior-cogitator-station"]==1
    and pair.robot_network_task_0338==nil,
    "robot ghost bypassed refusal "..expected..": "..tostring(result.detail))
end
-- Restore the observer's earlier maintenance-test changes.
can_supply_packs=true
powered=false
refuse("roboport-unpowered")
powered=true
network.available_construction_robots=0
refuse("no-available-construction-robots")
network.available_construction_robots=2
logistic_items["senior-cogitator-station"]=0
local no_item=Planner.service_robot_network_pair_0338(pair)
assert(no_item.blocked==1 and no_item.detail=="no-physical-logistic-supply"
  and ghost_creations==0 and claims==0,
  "robot ghost appeared without real logistic supply")
logistic_items["senior-cogitator-station"]=1
request.position={x=120,y=0}
local outside=Planner.service_robot_network_pair_0338(pair)
assert(outside.blocked==1
  and outside.detail=="outside-real-construction-coverage"
  and ghost_creations==0,"remote robot ghost escaped real coverage")
request.position={x=55,y=0}
request.root_station_unit=9999
refuse("robot-request-rank-or-identity-invalid")
request.root_station_unit=5001
assert(Planner.recommend_action(pair).source=="construction-planner-0338",
  "robot ghost was not offered through the existing dispatcher family")
local first=Planner.service_pair(pair,"S2-canonical-dispatch")
assert(first.waiting==1 and first.detail=="robot-ghost-awaiting-physical-build"
  and ghost_creations==1 and claims==1
  and logistic_items["senior-cogitator-station"]==1
  and pair.robot_network_task_0338.ghost==ghost
  and Planner.recommend_action(pair)==nil,
  "canonical 0338 failed to place one unspent native robot ghost")
local pending=Planner.service_robot_network_pair_0338(pair)
assert(pending.waiting==1 and ghost_creations==1 and claims==1,
  "robot ghost was duplicated before actual Factorio construction")
ghost.valid=false
local missing=Planner.service_robot_network_pair_0338(pair)
assert(missing.blocked==1
  and missing.detail=="robot-ghost-lost-without-real-station"
  and ghost_creations==1 and logistic_items["senior-cogitator-station"]==1,
  "lost ghost was treated as a real built station")
real_station={valid=true,name="senior-cogitator-station",
  unit_number=7001,position={x=55,y=0},force=force,surface=surface}
local phantom=Planner.service_robot_network_pair_0338(pair)
assert(phantom.blocked==1 and phantom.detail=="robot-material-debit-unverified"
  and ghost_creations==1,
  "station entity without real robot item debit was credited")
logistic_items["senior-cogitator-station"]=0
local waiting=Planner.service_robot_network_pair_0338(pair)
assert(waiting.waiting==1
  and waiting.detail=="robot-station-awaiting-ranked-pair"
  and pair.robot_network_task_0338.stock_delta_verified==true,
  "real robot construction incorrectly invented a paired priest")
local child={station=real_station,
  priest={valid=true,unit_number=7002}}
storage.tech_priests.pairs_by_station={[7001]=child}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p==pair and 4 or 3 end,
  is_direct_subordinate=function(parent,c)
    return parent==pair and c==child
  end,
}
local done=Planner.service_pair(pair,"S2-physical-robot-receipt")
assert(done.acted==1
  and done.detail=="robot-station-physically-built-and-paired"
  and pair.robot_network_request_0338==nil
  and pair.robot_network_task_0338==nil
  and pair.robot_network_last_task_0338.child_station_unit==7001
  and pair.robot_network_last_task_0338.child_priest_unit==7002
  and releases==1 and claims==1 and ghost_creations==1
  and logistic_items["senior-cogitator-station"]==0,
  "robot station completion lacked exact debit, rank, priest or custody")
print("[remote-expansion-robot-0338-1070] PASS canonical ghost, live power/coverage/robots/supply, exact native-item debit, real station and ranked pair; Factorio engine still pending")
