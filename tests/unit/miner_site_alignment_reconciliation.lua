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
-- Isolation of the scan router: site eligibility remains under test here.
_G.TechPriestsScanRouting0610={
  find_entities=function(surface,filter)
    return surface.find_entities_filtered(filter)
  end
}
local Planner=require("scripts.core.construction_site_planner")
local function check(ok,why)if not ok then error("miner-site regression: "..why,2)end end
local ore={valid=true,name="iron-ore",type="resource",amount=200,
  position={x=10.5,y=0.5}}
local block=false
local resources=true
local function setup()
  permitted=true;block=false;resources=true
  _G.TechPriestsScanRouting0610.find_entities=function(surface,filter)
    return surface.find_entities_filtered(filter)
  end
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

scenario("empty indexed resource catalog falls back to live ore scan",function()
  local pair=setup()
  _G.TechPriestsScanRouting0610.find_entities=function(surface,filter,opts)
    if opts and opts.category=="construction-resource" then return {} end
    return surface.find_entities_filtered(filter)
  end
  local pos,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(pos and why=="resource-patch-live-verified",
    "empty index prevented live ore verification: "..tostring(why))
end)

scenario("stale cached clearance obstruction cannot deny live legal site",function()
  local pair=setup()
  _G.TechPriestsScanRouting0610.find_entities=function(surface,filter,opts)
    if opts and opts.category=="construction-clearance" then
      return {{valid=true,type="assembling-machine",name="stale-obstacle"}}
    end
    return surface.find_entities_filtered(filter)
  end
  local pos,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(pos and why=="resource-patch-live-verified",
    "false-positive catalog obstruction displaced real placement")
end)

scenario("failed live resource query stays fail closed",function()
  local pair=setup()
  pair.station.surface.find_entities_filtered=function(filter)
    if filter.type=="resource" then error("simulated engine query failure") end
    return {}
  end
  _G.TechPriestsScanRouting0610.find_entities=function(_,filter,opts)
    if opts and opts.category=="construction-resource" then return {} end
    return {}
  end
  local pos,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(pos==nil and why=="miner-live-resource-scan-failed",
    "failed live query allowed unverified placement")
end)

scenario("standard mining drill chooses real iron before closer coal",function()
  local pair=setup()
  local iron={valid=true,name="iron-ore",type="resource",amount=100,
    position={x=12.5,y=0.5}}
  local coal={valid=true,name="coal",type="resource",amount=100,
    position={x=4.5,y=0.5}}
  pair.station.surface.find_entities_filtered=function(filter)
    if filter.type=="resource" then return {coal,iron} end
    if filter.type=="mining-drill" then return {} end
    if filter.area then return {} end
    return {}
  end
  local pos,why=Planner.plan_site(pair,{
    entity_name="burner-mining-drill",category="miner"})
  check(pos~=nil and pos.x>=11,
    "closer coal was selected instead of industrial iron: "..tostring(why))
end)

print("[miner-site-alignment] PASS scenarios="..total)
