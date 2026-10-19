-- Lua 5.2 regression: align mining drill footprints without relaxing site gates.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100}
prototypes={entity={
  ["burner-mining-drill"]={type="mining-drill",collision_box={
    left_top={x=-0.9,y=-0.9},right_bottom={x=0.9,y=0.9}}},
  ["big-mining-drill"]={type="mining-drill",collision_box={
    left_top={x=-1.4,y=-1.4},right_bottom={x=1.4,y=1.4}}},
}}
local permitted=true
_G.TechPriestsPlanningConstraints0646={
  entity_unlocked=function()return true end,
  interior_position_allowed=function()return permitted end,
}
local Planner=require("scripts.core.construction_site_planner")
local function check(ok,why)if not ok then error("miner-site regression: "..why,2)end end
local ore={valid=true,name="iron-ore",type="resource",amount=200,
  position={x=10.5,y=0.5}}
local block=false
local resources=true
local function setup()
  permitted=true;block=false;resources=true
  local surface={index=1,name="nauvis"}
  surface.find_entities_filtered=function(filter)
    if filter.type=="resource" then return resources and {ore} or {} end
    if filter.type=="mining-drill" then return {} end
    if filter.area then
      if block then return {{valid=true,type="assembling-machine",name="obstacle"}} end
      return resources and {ore} or {}
    end
    return {}
  end
  surface.can_place_entity=function(o)
    local valid_center
    if o.name=="burner-mining-drill" then
      valid_center=o.position.x%1==0 and o.position.y%1==0
    else
      valid_center=o.position.x%1==0.5 and o.position.y%1==0.5
    end
    return valid_center and not block
  end
  local force={index=1,name="player"}
  local station={valid=true,unit_number=1,name="station",
    position={x=0,y=0},surface=surface,force=force}
  return {station=station,priest={valid=true},radius=24}
end
local total=0
local function scenario(label,run)
  run();total=total+1;print("[miner-site-alignment] PASS "..label)
end

scenario("2x2 burner drill aligns from tile-centered ore to integer build center",function()
  local pair=setup()
  local position,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(position and position.x%1==0 and position.y%1==0,
    "2x2 drill site was not grid-aligned: "..tostring(why))
  check(math.abs(position.x-ore.position.x)<=1
    and math.abs(position.y-ore.position.y)<=1,"drill detached from ore tile")
end)

scenario("3x3 mining drill stays on legal half-tile build center",function()
  local pair=setup()
  local position,why=Planner.plan_site(pair,{
    entity_name="big-mining-drill",category="miner"})
  check(position and position.x%1==0.5 and position.y%1==0.5,
    "odd-width mining site failed alignment: "..tostring(why))
end)

scenario("territory gate still forbids miner placement",function()
  local pair=setup();permitted=false
  local position,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(position==nil and why=="no-miner-site",
    "alignment bypassed station territory")
end)

scenario("real collision still forbids all tested anchors",function()
  local pair=setup();block=true
  local position,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(position==nil and why=="no-miner-site",
    "alignment built through a physical machine")
end)

scenario("no physical resource forbids drill site",function()
  local pair=setup();resources=false
  local position,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(position==nil and why=="no-miner-site",
    "drill proposed without a real ore patch")
end)

print("[miner-site-alignment] PASS scenarios="..total)
