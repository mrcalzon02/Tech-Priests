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
