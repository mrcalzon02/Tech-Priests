-- Actual 0835 starvation decision with inventory, map-intelligence and
-- remote-ore mocks. The production planner creates no entities or resources.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Rail=require("scripts.core.remote_rail_outpost_0835")
game={tick=1000}
defines={inventory={chest=1}}
local qty={
  rail=700,locomotive=2,["cargo-wagon"]=3,coal=300,
  ["burner-mining-drill"]=12,["train-stop"]=4,["iron-ore"]=0
}
local inventory={valid=true,get_item_count=function(name)return qty[name] or 0 end}
local surface={index=1}
local intel=true
local nearby=false
local remote=true
local force={index=1,technologies={
    railway={researched=true},
    ["automated-rail-transportation"]={researched=true}}}
force.is_chunk_charted=function(_,sector)
  return intel and sector.x==16 and sector.y==0
end
local ore={valid=true,name="iron-ore",unit_number=991,
  type="resource",surface=surface,position={x=512,y=0},amount=10000}
surface.find_entities_filtered=function(args)
  assert(args.type=="resource" and args.name=="iron-ore",
    "rail observer searched unrelated entities")
  if args.position then
    return nearby and {{valid=true,amount=10}} or {}
  end
  return remote and {ore} or {}
end
_G.TechPriestsScanRouting0610={
  find_entities=function(scanned_surface,filters,context)
    assert(scanned_surface==surface
        and context and context.category=="resource"
        and filters.limit and filters.limit<=512,
      "rail planner bypassed canonical budgeted world scan")
    return surface.find_entities_filtered(filters)
  end,
}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=104,position={x=0,y=0},surface=surface,force=force,
  get_inventory=function(id)
    assert(id==defines.inventory.chest)
    return inventory
  end}
local pair={station=station,priest={valid=true,unit_number=105}}
local function blocked(want)
  local mission,reason=Rail.assess(pair)
  assert(mission==nil and reason==want,
    "incorrect starvation gate: "..tostring(reason).." expected "..want)
end

intel=false
blocked("no-charted-remote-ore")
intel=true
nearby=true
blocked("local-patch-available")
nearby=false
qty["iron-ore"]=Rail.stock_floor
blocked("stock-available")
qty["iron-ore"]=0
qty.locomotive=0
blocked("missing-physical-rail-supplies:locomotive")
qty.locomotive=2
force.technologies.railway.researched=false
blocked("railway-technology-locked")
force.technologies.railway.researched=true
remote=false
blocked("no-charted-remote-ore")
remote=true
local decision,why=Rail.assess(pair)
assert(why=="starved-charted-patch" and decision and
    decision.item=="iron-ore" and decision.position.x==512
    and decision.distance==512 and decision.observed_stock==0,
  "charted distant genuine ore not detected for rail-ready starving Magos")
local created,status=Rail.observe_pair(pair)
local original=pair.remote_rail_outpost_0835
assert(created and status=="starvation-objective-created"
    and original and original.status=="starvation-confirmed"
    and original.stage=="surveyed-remote-patch"
    and original.next_step=="plan-physical-track-route"
    and original.root_station_unit==104
    and original.target.x==512 and qty.rail==700
    and qty.locomotive==2 and qty["iron-ore"]==0,
  "rail starvation observer created phantom track, stock or wrong objective")
local again,reason=Rail.observe_pair(pair)
assert(not again and reason=="interval"
    and pair.remote_rail_outpost_0835==original,
  "rail observer duplicated the live strategic objective")
game.tick=2000
again,reason=Rail.observe_pair(pair)
assert(not again and reason=="mission-already-owned"
    and pair.remote_rail_outpost_0835==original
    and original.last_observed_tick==2000,
  "rail observation reassigned or reset an active mission")
station.name="junior-cogitator-station"
local forbidden,why_not=Rail.assess(pair)
assert(not forbidden and why_not=="not-live-planetary-magos",
  "subordinate station illegally claimed planetary rail expansion authority")
print("[remote-rail-outpost-0835] PASS charted remote-starvation discovery, genuine stock gates, durable ranked mission")
