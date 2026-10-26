-- Real source-module regression: no staffed station may be mined until
-- its rank, hierarchy, production, inventories and priest lifecycle are safe.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
local Recovery = require("scripts.core.station_recycling_0822")

local function inventory(contents)
  return {
    valid = true,
    get_contents = function() return contents or {} end,
  }
end
local force, surface = {}, {}
surface.find_logistic_network_by_position=function() return nil end
defines={inventory={chest=1}}
local function pair(id, r, station_name)
  local st = {
    valid = true, unit_number = id, name = station_name,
    force = force, surface = surface, position = { x = id * 10, y = 0 },
    minable = true,
    prototype = { mineable_properties = {
      products = { { name = station_name, type = "item", amount = 1 } }
    } },
  }
  local priest = {
    valid = true, unit_number = id + 100, position = st.position,
    get_main_inventory = function() return inventory() end,
  }
  return {
    station = st, priest = priest, rank = r, mode = "idle",
    inventory = inventory(),
    command_hierarchy_0480 = {
      superior_unit = nil, direct_subordinate_units = {}, peer_units = {},
    },
  }
end
local parent = pair(1, 2, "intermediate-cogitator-station")
local junior = pair(2, 1, "junior-cogitator-station")
junior.command_hierarchy_0480.superior_unit = 1
storage = { tech_priests = {
  pairs_by_station = { [1] = parent, [2] = junior },
  station_expansion_0256 = {},
} }
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480 = {
  rank = function(p) return p.rank end,
  is_direct_subordinate = function(p, c)
    return c.command_hierarchy_0480.superior_unit == p.station.unit_number
  end,
  peers = function(p) return p.peer_list or {} end,
}
_G.tech_priests_0358_station_sources_for_pair = function(p)
  return { { inv = p.inventory, owner = p.station } }
end
local item = "junior-cogitator-station"
local function eligible(p, c)
  return Recovery.check_candidate(p or parent, c or junior, item)
end
local function rejects(expected, fn)
  local ok, why = eligible()
  assert(not ok and why == expected,
    "expected " .. expected .. " got " .. tostring(ok) .. " / " .. tostring(why))
  fn()
end

local ok, why = eligible()
assert(ok and why == "eligible-for-lifecycle-lease", "idle empty direct Junior should pass preflight")
local candidate, status = Recovery.find_candidate(parent, item, { x = 100, y = 0 })
assert(candidate == junior and status == "eligible-but-awaiting-priest-lifecycle-lease")
assert(junior.station.valid and junior.priest.valid, "preflight must not mine or destroy")

junior.inventory = inventory({ ["iron-plate"] = 1 })
rejects("station-inventory-not-empty", function() junior.inventory = inventory() end)
junior.inventory = inventory({ { name = "iron-plate", count = 2, quality = "normal" } })
rejects("station-inventory-not-empty", function() junior.inventory = inventory() end)
junior.inventory = { valid = true, get_contents = function() error("unreadable inventory") end }
rejects("station-inventory-not-empty", function() junior.inventory = inventory() end)

junior.priest.get_main_inventory = function() return inventory({ ["iron-ore"] = 1 }) end
rejects("priest-cargo-not-empty", function()
  junior.priest.get_main_inventory = function() return inventory() end
end)
junior.command_hierarchy_0480.direct_subordinate_units = { 99 }
rejects("station-has-descendants", function()
  junior.command_hierarchy_0480.direct_subordinate_units = {}
end)
junior.command_hierarchy_0480.peer_units = { 98 }
rejects("station-has-other-peers", function()
  junior.command_hierarchy_0480.peer_units = {}
end)
junior.mode = "mining"
rejects("priest-not-idle", function() junior.mode = "idle" end)
junior.combat_target = { valid = true }
rejects("active-pair-duty:combat_target", function() junior.combat_target = nil end)
junior.inventory_transfer_custody_0687 = { count = 1 }
rejects("active-pair-duty:inventory_transfer_custody_0687", function()
  junior.inventory_transfer_custody_0687 = nil
end)
storage.tech_priests.station_expansion_0256[4] = {
  status = "active", worker_station_unit = 2,
}
rejects("active-station-expansion-or-resource-mission", function()
  storage.tech_priests.station_expansion_0256[4] = nil
end)
parent.resource_expansion_0259 = {
  chain_0820 = { status = "building-station", current_station_unit = 2 },
}
rejects("active-station-expansion-or-resource-mission", function()
  parent.resource_expansion_0259 = nil
end)
junior.station.minable = false
rejects("station-mining-product-not-exact", function() junior.station.minable = true end)
junior.station.prototype.mineable_properties.products = {
  { name = item, amount = 1 }, { name = "iron-plate", amount = 1 },
}
rejects("station-mining-product-not-exact", function()
  junior.station.prototype.mineable_properties.products = { { name = item, amount = 1 } }
end)
junior.proxy = { valid = true }
rejects("linked-helper-needs-lifecycle:proxy", function() junior.proxy = nil end)
-- A live priest-owned small-arms proxy is NOT a station facility: its actual
-- entity and ammunition remain with the same priest throughout relocation.
local proxy = { valid = true, unit_number = 900, name = "tech-priest-small-arms-proxy",
  force = force, surface = surface, position = junior.priest.position }
junior.priest.force, junior.priest.surface = force, surface
junior.proxy = proxy
assert(eligible(), "attached exclusively-owned priest proxy must survive station relocation")
proxy.shooting_target = { valid = true }
rejects("linked-helper-needs-lifecycle:proxy", function() proxy.shooting_target = nil end)
proxy.position = { x = 1000, y = 0 }
rejects("linked-helper-needs-lifecycle:proxy", function()
  proxy.position = junior.priest.position
end)
proxy.force = {}
rejects("linked-helper-needs-lifecycle:proxy", function() proxy.force = force end)
parent.proxy = proxy
rejects("linked-helper-needs-lifecycle:proxy-shared", function() parent.proxy = nil end)
junior.proxy = nil
assert(proxy.valid, "preflight must never destroy the priest's actual proxy or ammunition")
local function cache(name,id)
  return {valid=true,name=name,unit_number=id,force=force,surface=surface,
    position=junior.station.position,
    get_inventory=function() return inventory() end}
end
local requester=cache("tech-priests-cogitator-requester-cache",901)
local returning=cache("tech-priests-cogitator-return-cache",902)
junior.logistic_requester=requester
junior.logistic_return_cache=returning
assert(eligible(), "empty exclusively owned station caches may be recycled")
requester.get_inventory=function() return inventory({["iron-plate"]=1}) end
rejects("linked-helper-cargo:logistic_requester",function()
  requester.get_inventory=function() return inventory() end
end)
returning.get_inventory=function() return inventory({["copper-plate"]=1}) end
rejects("linked-helper-cargo:logistic_return_cache",function()
  returning.get_inventory=function() return inventory() end
end)
requester.position={x=999,y=0}
rejects("linked-helper-identity-or-position:logistic_requester",function()
  requester.position=junior.station.position
end)
parent.logistic_return_cache=requester
rejects("linked-helper-shared:logistic_requester",function()
  parent.logistic_return_cache=nil
end)
junior.logistic_requested_item="iron-plate"
rejects("linked-helper-active-request",function()
  junior.logistic_requested_item=nil
end)
surface.find_logistic_network_by_position=function() return {} end
rejects("linked-helper-network-active:logistic_requester",function()
  surface.find_logistic_network_by_position=function() return nil end
end)
junior.logistic_requester=nil
junior.logistic_return_cache=nil
assert(requester.valid and returning.valid,
  "preflight cannot destroy hidden caches")
storage.tech_priests.inventory_steward_0357 = {
  stashes_by_station = { [2] = { [5] = {} } },
}
rejects("station-stash-custody", function()
  storage.tech_priests.inventory_steward_0357 = nil
end)
storage.tech_priests.emergency_facility_doctrine_0343 = {
  by_station = { [2] = { [5] = true } },
}
rejects("station-facility-custody", function()
  storage.tech_priests.emergency_facility_doctrine_0343 = nil
end)
local source = _G.tech_priests_0358_station_sources_for_pair
_G.tech_priests_0358_station_sources_for_pair = nil
rejects("inventory-authority-unavailable", function()
  _G.tech_priests_0358_station_sources_for_pair = source
end)
junior.command_hierarchy_0480.superior_unit = 90
rejects("not-direct-lower-rank-subordinate", function()
  junior.command_hierarchy_0480.superior_unit = 1
end)
junior.station.force = {}
rejects("foreign-domain", function() junior.station.force = force end)

local junior_parent = pair(3, 1, item)
junior_parent.peer_list = { junior }
junior.command_hierarchy_0480.peer_units = { 3 }
storage.tech_priests.pairs_by_station[3] = junior_parent
assert(eligible(junior_parent, junior), "Junior peer must be reclaimable by eligible Junior")
junior_parent.peer_list = {}
local peer_ok, peer_why = eligible(junior_parent, junior)
assert(not peer_ok and peer_why == "not-junior-peer", "no arbitrary same-rank salvage")
junior.command_hierarchy_0480.peer_units = {}
storage.tech_priests.pairs_by_station[3] = nil

local further = pair(4, 1, item)
further.command_hierarchy_0480.superior_unit = 1
further.station.position.x = -100
storage.tech_priests.pairs_by_station[4] = further
local farthest = Recovery.find_candidate(parent, item, { x = 100, y = 0 })
assert(farthest == further, "prefer least useful physical station to remote target")
assert(junior.station.valid and junior.priest.valid and further.station.valid,
  "selection is non-destructive, no station item may be invented")
print("station recycling 0822: rank, custody, active mission, peer and physical-item preflight PASS")

-- Method I no-spare-item reversal: plan an actual five-station hierarchy
-- leaf-first, but never treat planning as a physical mine or inventory credit.
local Reversal = require("scripts.core.station_starvation_reversal_0850")
local magos = pair(100, 4, "planetary-magos-cogitator-station")
local senior = pair(101, 3, "senior-cogitator-station")
local middle = pair(102, 2, "intermediate-cogitator-station")
local lead = pair(103, 1, item)
local leaf = pair(104, 1, item)
magos.command_hierarchy_0480.direct_subordinate_units = {101}
senior.command_hierarchy_0480.superior_unit = 100
senior.command_hierarchy_0480.direct_subordinate_units = {102}
middle.command_hierarchy_0480.superior_unit = 101
middle.command_hierarchy_0480.direct_subordinate_units = {103}
lead.command_hierarchy_0480.superior_unit = 102
lead.command_hierarchy_0480.peer_units = {104}
lead.peer_list = {leaf}
leaf.command_hierarchy_0480.peer_units = {103}
leaf.peer_list = {lead}
storage.tech_priests.pairs_by_priest=storage.tech_priests.pairs_by_priest or {}
for _, p in ipairs({magos, senior, middle, lead, leaf}) do
  storage.tech_priests.pairs_by_station[p.station.unit_number] = p
  storage.tech_priests.pairs_by_priest[p.priest.unit_number] = p
end
game = {tick=12345}
local destination = {x=900,y=0}
local plan, result = Reversal.preflight(magos, destination, "senior-cogitator-station")
assert(plan and result == "leaf-first-order-verified-no-items-moved"
  and plan.status == "leaf-first-preflight-only"
  and plan.root_station_unit == 100 and #plan.stages == 4
  and plan.stages[1].station_unit == 104
  and plan.stages[1].parent_station_unit == 103
  and plan.stages[2].station_unit == 103
  and plan.stages[3].station_unit == 102
  and plan.stages[4].station_unit == 101
  and plan.stages[4].item == "senior-cogitator-station"
  and plan.first_leaf_preflight_tick == 12345,
  "no-spare-item reversal must expose the exact leaf-first physical order")
assert(leaf.station.valid and leaf.priest.valid
  and senior.station.valid and senior.priest.valid
  and not storage.tech_priests.station_relocation_0823,
  "preflight cannot mine, teleport, reassign or create inventory")

local function plan_valid()
  local ok,why=Reversal.validate_plan(magos,plan,destination,
    "senior-cogitator-station")
  assert(ok and why=="reversal-plan-live-preflight-verified",
    "stored reversal plan did not revalidate: "..tostring(why))
end
local function plan_refused(reason,observed_target)
  local ok,why=Reversal.validate_plan(magos,plan,observed_target or destination,
    "senior-cogitator-station")
  assert(not ok and why==reason,
    "expected stored plan refusal "..reason.." got "..tostring(why))
end
plan_valid()
plan.stages[2].parent_station_unit=999
plan_refused("reversal-plan-stage-changed:2")
plan.stages[2].parent_station_unit=102
plan.target.x=destination.x+1
plan_refused("reversal-plan-target-changed")
plan.target.x=destination.x
plan_refused("reversal-plan-target-changed",{x=destination.x-1,y=0})
plan.status="actively-mining"
plan_refused("missing-or-malformed-stored-reversal-plan")
plan.status="leaf-first-preflight-only"
plan_valid()
lead.command_hierarchy_0480.peer_units={104,999}
plan_refused("reversal-plan-live-ambiguous-junior-peers")
lead.command_hierarchy_0480.peer_units={104}
leaf.inventory=inventory({["iron-ore"]=1})
plan_refused("reversal-plan-live-leaf-preflight:station-inventory-not-empty")
leaf.inventory=inventory()
plan_valid()
local perpendicular=Reversal.preflight(magos,{x=1000,y=900},
  "senior-cogitator-station")
assert(not perpendicular,"sideways chain is not a safe physical reversal")
assert(leaf.station.valid and leaf.priest.valid
  and not storage.tech_priests.station_relocation_0823,
  "stored-plan revalidation cannot mine or create inventory")
local function reversal_refused(reason)
  local p, why = Reversal.preflight(magos, destination, "senior-cogitator-station")
  assert(not p and why == reason, "expected " .. reason .. " got " .. tostring(why))
end
magos.command_hierarchy_0480.direct_subordinate_units = {101, 999}
reversal_refused("ambiguous-root-subordinates")
magos.command_hierarchy_0480.direct_subordinate_units = {101}
middle.command_hierarchy_0480.direct_subordinate_units = {103, 104}
reversal_refused("ambiguous-intermediate-subordinates")
middle.command_hierarchy_0480.direct_subordinate_units = {103}
lead.command_hierarchy_0480.peer_units = {104, 999}
reversal_refused("ambiguous-junior-peers")
lead.command_hierarchy_0480.peer_units = {104}
leaf.command_hierarchy_0480.peer_units = {103, 999}
reversal_refused("leaf-has-other-command-custody")
leaf.command_hierarchy_0480.peer_units = {103}
leaf.inventory = inventory({["iron-ore"]=1})
reversal_refused("leaf-preflight:station-inventory-not-empty")
leaf.inventory = inventory()
leaf.active_task = {kind="mining"}
reversal_refused("leaf-preflight:active-pair-duty:active_task")
leaf.active_task = nil
local prior_surface = leaf.station.surface
leaf.station.surface = {}
reversal_refused("invalid-junior-peer")
leaf.station.surface = prior_surface
local wrong_parent = senior.command_hierarchy_0480.superior_unit
senior.command_hierarchy_0480.superior_unit = 999
reversal_refused("invalid-root-link")
senior.command_hierarchy_0480.superior_unit = wrong_parent
local hierarchy = _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480
local saved_direct = hierarchy.is_direct_subordinate
hierarchy.is_direct_subordinate = function() error("hierarchy read unavailable") end
reversal_refused("invalid-root-link")
hierarchy.is_direct_subordinate = saved_direct
local saved_peers = hierarchy.peers
hierarchy.peers = function(p)
  if p == lead then error("peer read unavailable") end
  return saved_peers(p)
end
reversal_refused("junior-peer-authority-unobservable")
hierarchy.peers = function(p)
  if p == leaf then error("leaf peer read unavailable") end
  return saved_peers(p)
end
reversal_refused("leaf-peer-authority-unobservable")
hierarchy.peers = saved_peers
assert(not Reversal.preflight(magos, {x=0/0,y=0}, "senior-cogitator-station"),
  "nonfinite resource target must not authorize dismantling")
local useful, useful_reason = Reversal.preflight(magos,
  {x=1100,y=0}, "senior-cogitator-station")
assert(not useful and useful_reason == "existing-chain-not-opposed-to-target",
  "must not recycle an existing chain approaching the ore")
assert(not Reversal.preflight(magos, nil, "senior-cogitator-station"),
  "unknown ore target must not authorize dismantling")
package.loaded["scripts.core.station_starvation_reversal_0850"] = nil
local ReloadedReversal = require("scripts.core.station_starvation_reversal_0850")
local persisted = ReloadedReversal.preflight(magos, plan.target, plan.required_item)
assert(persisted and persisted.stages[1].station_unit == 104
  and persisted.stages[4].station_unit == 101,
  "reload must reconstruct the same physical station order from IDs")
print("[station-starvation-reversal-0850] PASS five real pairs, leaf-first ordering, blocked custody, rank, target, and reload preflight")

-- 0851 production staging: the Junior parent must WALK to its terminal peer,
-- mine one real station item into a persistent engine-owned hold, and carry it
-- physically to the Magos. This does NOT clear the next ancestor for mining.
local Cargo0851=require("scripts.core.station_cargo_0824")
local Relocation0851=require("scripts.core.station_relocation_0823")
local bags0851={}
game.create_inventory=function(size)
  assert(size==1)
  local bag={valid=true,stock=0,item=nil}
  bag.get_item_count=function(name)
    return (bag.item==nil or bag.item==name) and bag.stock or 0
  end
  bag.insert=function(stack)
    if bag.stock>0 and bag.item~=stack.name then return 0 end
    local n=math.min(stack.count,1-bag.stock)
    if n>0 then bag.item=stack.name end
    bag.stock=bag.stock+n
    return n
  end
  bag.remove=function(stack)
    if bag.item~=nil and bag.item~=stack.name then return 0 end
    local n=math.min(stack.count,bag.stock)
    bag.stock=bag.stock-n
    if bag.stock==0 then bag.item=nil end
    return n
  end
  bag.is_empty=function() return bag.stock==0 end
  bag.destroy=function()
    assert(bag.stock==0)
    bag.valid=false
  end
  bags0851[#bags0851+1]=bag
  return bag
end
defines.command={go_to_location=5}
defines.distraction={none=0}
magos.resource_expansion_0259={chain_0820={
  status="building-station",root_station_unit=100,target=destination
}}
local expansion_rec={id=510,status="active",station_item="senior-cogitator-station",
  reversal_plan_0850=plan,worker_station_unit=100}
storage.tech_priests.station_expansion_0256[510]=expansion_rec
-- Regression: reserve future NEW mundane assignments for the actual five
-- original station/priest pairs, never for unrelated units. Do not confuse
-- this with mining authorization or cancellation of an existing duty.
for _,p in ipairs({magos,senior,middle,lead,leaf}) do
  local reserved,writ=Reversal.future_worker_reserved(p)
  assert(reserved and writ==expansion_rec,
    "active five-station writ must reserve each real participant")
end
-- Exercise the actual 0640 production entry point, not just its helper:
-- five rank-specific priests must be protected against NEW assignments.
local Infrastructure0640=require("scripts.core.infrastructure_first_governor_0640")
for _,p in ipairs({magos,senior,middle,lead,leaf}) do
  local worked,why=Infrastructure0640.service_pair(p,"reversal-reservation-unit")
  assert(worked==false and why=="physical-station-reversal-reserved"
    and not p.infrastructure_recipe_request_0647,
    "0640 must honor production five-station future-work reservation")
end
local unrelated=pair(999,1,item)
assert(not Reversal.future_worker_reserved(unrelated),
  "unrelated priest cannot be reserved by another mission")
local old_status=expansion_rec.status
expansion_rec.status="complete"
assert(not Reversal.future_worker_reserved(magos),
  "finished reversal must release future-work reservation")
expansion_rec.status=old_status
local saved_last=plan.stages[4]
plan.stages[4]="corrupt-stage"
assert(not Reversal.future_worker_reserved(magos),
  "malformed saved plan cannot reserve new future work")
plan.stages[4]=saved_last
assert(Reversal.future_worker_reserved(magos),
  "restored physical writ must retain future-work reservation")
-- Canonical 0418 refuses ordinary Junior work beyond 40 tiles, while a
-- specifically authorized station-recovery route remains legal.
local Movement0418=require("scripts.core.movement_controller")
local distant_peer={x=lead.station.position.x+60,y=lead.station.position.y}
local legacy_allowed=Movement0418.position_allowed(lead,distant_peer,
  "legacy-issue-priest-command",{owner="legacy-command"})
local recovery_allowed=Movement0418.position_allowed(lead,distant_peer,
  "station-recovery-leaf-0851",{owner="station-recovery-0851"})
assert(not legacy_allowed and recovery_allowed,
  "canonical movement must distinguish station recovery from ordinary work")
-- 0871: exercise the ACTUAL 0418 request/debounce code, not a stubbed
-- route. The Factorio engine mined the terminal Junior but repeatedly held
-- the same-priority return after leaf-walk refreshes reset the 90-tick age.
local leaf_ok,leaf_req=Movement0418.request(lead,distant_peer,
  "station-recovery-leaf-0851",
  {owner="station-recovery-0851",priority=45,ttl=600,radius=2})
assert(leaf_ok and type(leaf_req)=="table" and leaf_req.priority==45,
  "physical leaf approach must retain the normal owned route priority")
local early_return,held=Movement0418.request(lead,magos.station.position,
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=45,ttl=600,radius=2})
assert(not early_return and held=="retarget-held"
  and lead.movement_request_0418==leaf_req,
  "the real controller must reproduce the original return retarget failure")
local returned,return_req=Movement0418.request(lead,magos.station.position,
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=56,ttl=600,radius=2})
assert(returned and type(return_req)=="table"
  and return_req.owner=="station-recovery-0851"
  and return_req.priority==56
  and return_req.reason=="station-recovery-return-0851"
  and lead.movement_request_0418==return_req,
  "verified carried-item return must transition immediately from the leaf route")
-- 0872: reproduce the SECOND real engine failure: after the 45->56
-- handoff, the 0418 controller owns a short ground waypoint to the Magos.
-- A moving priest causes the next 60-tick service to recompute that waypoint;
-- same-priority debounce refuses it even though the FINAL destination did
-- not change. The production helper must reuse the live canonical route,
-- not reissue a different waypoint or silently override safety.
assert(return_req.ground_route_chunked
  and return_req.ground_route_final_destination
  and return_req.ground_route_final_destination.x==magos.station.position.x,
  "test must exercise a genuinely segmented physical return route")
local previous_request_fn=_G.tech_priests_request_movement_0418
local previous_status_fn=_G.tech_priests_movement_status_0418
_G.tech_priests_request_movement_0418=function(...)
  return Movement0418.request(...)
end
_G.tech_priests_movement_status_0418=function(...)
  return Movement0418.request_status(...)
end
local previous_priest_position=lead.priest.position
lead.priest.position={x=previous_priest_position.x-3,y=previous_priest_position.y}
local repeated,repeat_why=Movement0418.request(lead,magos.station.position,
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=56,ttl=600,radius=2})
assert(not repeated and repeat_why=="retarget-held"
  and lead.movement_request_0418==return_req,
  "real 0418 must reproduce repeated-return moving-waypoint debounce")
local reused,reuse_why=Reversal.request_recovery_walk(
  lead,magos.station.position,"return",nil)
assert(reused and reuse_why=="canonical-recovery-route-in-progress"
  and lead.movement_request_0418==return_req
  and return_req.ground_route_final_destination.x==magos.station.position.x,
  "production 0851 must preserve an active 0418 final-goal route without churn")
local changed,changed_why=Reversal.request_recovery_walk(
  lead,{x=magos.station.position.x+7,y=magos.station.position.y},"return",nil)
assert(not changed and changed_why=="retarget-held"
  and lead.movement_request_0418==return_req,
  "changed final destination must never masquerade as an accepted old route")
lead.priest.position=previous_priest_position
print("[station-starvation-waypoint-0872] PASS real moving-waypoint debounce, same-goal route reuse, changed-goal refusal")
-- 0874: the next physical carrier is an Intermediate, not the Junior
-- used in 0851. Its long Junior-recovery approach and return must be owned
-- by canonical 0418; the same final-goal route must not be churned by
-- repeated service calls, and high-priority safety must still win.
local Ancestor0853=require("scripts.core.station_starvation_ancestor_0853")
local middle_origin={x=middle.priest.position.x,y=middle.priest.position.y}
local ancestor_target={x=middle.station.position.x+64,
  y=middle.station.position.y}
local ancestor_ok,ancestor_why=Ancestor0853.request_recovery_walk(
  middle,ancestor_target,"leaf",nil)
local ancestor_req=middle.movement_request_0418
assert(ancestor_ok and ancestor_req
  and ancestor_req.owner=="station-recovery-0853"
  and ancestor_req.reason=="station-recovery-leaf-0853"
  and ancestor_req.priority==45
  and ancestor_req.ground_route_final_destination
  and ancestor_req.ground_route_final_destination.x==ancestor_target.x,
  "second-Junior recovery must submit a real long-range 0418 route")
middle.priest.position={x=middle_origin.x+3,y=middle_origin.y}
local ancestor_reused,reuse_ancestor_why=Ancestor0853.request_recovery_walk(
  middle,ancestor_target,"leaf",nil)
assert(ancestor_reused
  and reuse_ancestor_why=="canonical-ancestor-route-in-progress"
  and middle.movement_request_0418==ancestor_req,
  "moving Intermediate must reuse the original final-goal route")
local ancestor_changed,ancestor_change_why=Ancestor0853.request_recovery_walk(
  middle,{x=ancestor_target.x+9,y=ancestor_target.y},"leaf",nil)
assert(not ancestor_changed and ancestor_change_why=="retarget-held"
  and middle.movement_request_0418==ancestor_req,
  "changed Intermediate objective cannot inherit the old route")
local ancestor_return,ancestor_return_why=Ancestor0853.request_recovery_walk(
  middle,magos.station.position,"return",nil)
assert(ancestor_return and middle.movement_request_0418.priority==56
  and middle.movement_request_0418.reason=="station-recovery-return-0853",
  "counted second-Junior return must outrank its own leaf approach")
local ancestor_safety=Movement0418.request(middle,middle.station.position,
  "movement-enforcement-overleash-return-0566",
  {owner="movement-controller-enforcement-0566",priority=840,ttl=600,
   bounds_exempt=true})
assert(ancestor_safety,"real 0418 must accept priority-840 safety movement")
local ancestor_blocked,ancestor_block_why=Ancestor0853.request_recovery_walk(
  middle,magos.station.position,"return",nil)
assert(not ancestor_blocked and ancestor_block_why=="higher-priority-movement-owned"
  and middle.movement_request_0418.owner=="movement-controller-enforcement-0566",
  "second-Junior return may not override emergency safety ownership")
Movement0418.stop(middle,"0874-regression-reset")
middle.priest.position=middle_origin
assert(not Ancestor0853.request_recovery_walk(
  middle,{x=0/0,y=0},"return",nil),
  "malformed persisted return goal cannot obtain a movement lease")

-- 0875: third/fourth recovery must respect canonical ownership and waypoints.
local Third0875=require("scripts.core.station_starvation_intermediate_0854")
local Fourth0875=require("scripts.core.station_starvation_senior_0855")
for _,spec in ipairs({
  {suffix="0854",p=senior,walk=Third0875.request_recovery_walk},
  {suffix="0855",p=magos,walk=Fourth0875.request_recovery_walk}
}) do
  local p=spec.p
  local origin={x=p.priest.position.x,y=p.priest.position.y}
  local target={x=origin.x+64,y=origin.y}
  assert(spec.walk(p,target,"leaf",nil),"0875 physical approach refused")
  local req=p.movement_request_0418
  assert(req and req.owner=="station-recovery-"..spec.suffix
    and req.reason=="station-recovery-leaf-"..spec.suffix
    and req.priority==45 and req.ground_route_final_destination
    and req.ground_route_final_destination.x==target.x,"0875 wrong route owner")
  p.priest.position={x=origin.x+3,y=origin.y}
  local reused,reason=spec.walk(p,target,"leaf",nil)
  assert(reused and reason=="canonical-recovery-route-in-progress"
    and p.movement_request_0418==req,"0875 moving waypoint churn")
  local changed,why=spec.walk(p,{x=target.x+9,y=target.y},"leaf",nil)
  assert(not changed and why=="retarget-held" and p.movement_request_0418==req,
    "0875 changed target reused previous route")
  assert(spec.walk(p,magos.station.position,"return",nil)
    and p.movement_request_0418.priority==56,"0875 cargo return held")
  local safety_goal={x=origin.x,y=origin.y+12}
  assert(Movement0418.request(p,safety_goal,
    "movement-enforcement-overleash-return-0566",
    {owner="movement-controller-enforcement-0566",
      priority=840,ttl=600,bounds_exempt=true})
    and p.movement_request_0418.owner=="movement-controller-enforcement-0566",
    "0875 safety failed to take ownership")
  local denied,denial=spec.walk(p,magos.station.position,"return",nil)
  assert(not denied and denial=="higher-priority-movement-owned"
    and p.movement_request_0418.owner=="movement-controller-enforcement-0566",
    "0875 recovery bypassed safety")
  Movement0418.stop(p,"0875-regression-reset")
  p.priest.position=origin
  assert(not spec.walk(p,{x=0/0,y=0},"leaf",nil),"0875 malformed goal")
  local saved_defines=defines
  defines=nil
  local missing,missing_reason=spec.walk(p,target,"leaf",nil)
  defines=saved_defines
  assert(not missing and missing_reason=="recovery-command-api-unavailable",
    "0875 missing Factorio command API must fail closed")
end
print("[station-starvation-route-0875] PASS canonical 0418 third/fourth approach, waypoint reuse, cargo priority and safety")
print("[station-starvation-route-0874] PASS real Intermediate 0418 route, moving-waypoint reuse, leg handoff, safety refusal")
local safety_ok,safety_req=Movement0418.request(lead,lead.station.position,
  "movement-enforcement-overleash-return-0566",
  {owner="movement-controller-enforcement-0566",priority=840,ttl=600,
   radius=1,bounds_exempt=true})
assert(safety_ok and type(safety_req)=="table" and safety_req.priority==840,
  "overleash safety must still preempt station-item recovery")
local unsafe,why_unsafe=Movement0418.request(lead,magos.station.position,
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=56,ttl=600,radius=2})
assert(not unsafe and why_unsafe=="higher-priority-movement-owned"
  and lead.movement_request_0418==safety_req,
  "return phase must never override active higher-priority safety movement")
local helper_unsafe,helper_reason=Reversal.request_recovery_walk(
  lead,magos.station.position,"return",nil)
assert(not helper_unsafe and helper_reason=="higher-priority-movement-owned"
  and lead.movement_request_0418==safety_req,
  "production route reuse must never misidentify a safety-owned route")
_G.tech_priests_request_movement_0418=previous_request_fn
_G.tech_priests_movement_status_0418=previous_status_fn
storage.tech_priests[Movement0418.storage_key]=nil
lead.movement_request_0418=nil
print("[station-starvation-route-0871] PASS real 0418 retarget refusal, immediate custody-return handoff, safety priority retained")
local commands={}
local reject_ancestor_move=false
local reject_leaf_move=false
local function walk(priest,command)
  assert((priest==lead.priest or priest==middle.priest or priest==senior.priest)
    and command.type==defines.command.go_to_location)
  commands[#commands+1]=command.destination
  if priest==middle.priest and reject_ancestor_move then return false end
  if priest==lead.priest and reject_leaf_move then return false end
  return true
end
local routed_0870={}
_G.tech_priests_request_movement_0418=function(pair,destination,reason,opts)
  if pair==middle and opts.owner=="station-recovery-0853" then
    assert((reason=="station-recovery-leaf-0853"
        or reason=="station-recovery-return-0853")
      and opts.priority==(reason=="station-recovery-return-0853" and 56 or 45)
      and opts.ttl==600 and opts.radius==2,
      "Intermediate's recovery route must retain exact 0418 ownership")
    return walk(pair.priest,{
      type=defines.command.go_to_location,destination=destination})
  end
  -- 0875: the same canonical hook now owns the third and fourth real
  -- recovery walks. Delegate to the existing refusal-aware movement fixture.
  if (pair==senior and opts.owner=="station-recovery-0854")
      or (pair==magos and opts.owner=="station-recovery-0855") then
    local suffix=pair==senior and "0854" or "0855"
    assert((reason=="station-recovery-leaf-"..suffix
        or reason=="station-recovery-return-"..suffix)
      and opts.priority==(reason=="station-recovery-return-"..suffix and 56 or 45)
      and opts.ttl==600 and opts.radius==2
      and opts.distraction==defines.distraction.none,
      "later physical recovery stages must retain exact 0418 ownership")
    return walk(pair.priest,{
      type=defines.command.go_to_location,destination=destination})
  end
  assert(pair==lead and (reason=="station-recovery-leaf-0851"
      or reason=="station-recovery-return-0851")
    and opts.owner=="station-recovery-0851"
    and opts.priority==(reason=="station-recovery-return-0851" and 56 or 45)
    and opts.ttl==600 and opts.radius==2
    and opts.distraction==defines.distraction.none,
    "first-stage recovery must use the canonical owned route")
  routed_0870[#routed_0870+1]={reason=reason,destination=destination}
  return walk(pair.priest,{
    type=defines.command.go_to_location,destination=destination})
end
local mine_count=0
leaf.station.mine=function(args)
  mine_count=mine_count+1
  assert(args.force==true and args.raise_destroy==true)
  assert(Relocation0851.intercept_removed(leaf.station,{
    name=defines.events.script_raised_destroy
  }),"leaf mining must preserve original priest through lifecycle")
  leaf.station.valid=false
  args.inventory.stock=args.inventory.stock+1
  error("post-mutation Factorio callback failure")
end
defines.events={script_raised_destroy=11,on_entity_died=12}
local original_leaf_priest=leaf.priest
reject_leaf_move=true
local first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-leaf-movement-refused"
  and expansion_rec.reversal_route_denial_0870=="route-refused"
  and #routed_0870==1 and #commands==1 and mine_count==0 and #bags0851==0
  and expansion_rec.reversal_stage_0851.phase=="to-leaf",
  "refused first-Junior walk must not mine or create a phantom cargo hold")
reject_leaf_move=false
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-walking-to-real-junior-leaf"
  and expansion_rec.reversal_route_denial_0870==nil
  and #routed_0870==2 and #commands==2 and mine_count==0
  and expansion_rec.reversal_stage_0851.phase=="to-leaf"
  and #bags0851==0,"planning must not remotely mine or credit items")
lead.priest.position={x=leaf.station.position.x,y=leaf.station.position.y}
reject_leaf_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-return-movement-refused"
  and expansion_rec.reversal_route_denial_0870=="route-refused"
  and #routed_0870==3 and mine_count==1 and #bags0851==1 and bags0851[1].stock==1
  and expansion_rec.reversal_stage_0851.phase=="to-magos",
  "refused return command must keep the exact physically mined Junior item")
reject_leaf_move=false
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-carrying-real-leaf-item-to-magos"
  and expansion_rec.reversal_route_denial_0870==nil
  and #routed_0870==4
  and routed_0870[1].reason=="station-recovery-leaf-0851"
  and routed_0870[4].reason=="station-recovery-return-0851"
  and mine_count==1 and #bags0851==1 and bags0851[1].stock==1
  and not leaf.station.valid and original_leaf_priest.valid
  and storage.tech_priests.pairs_by_station[104]==nil
  and storage.tech_priests.pairs_by_priest[204]==leaf
  and Relocation0851.protect_priest(leaf,original_leaf_priest),
  "physical leaf mine must preserve one item, living priest and exact custody")
local staged=expansion_rec.reversal_stage_0851
assert(staged.phase=="to-magos" and
  Relocation0851.pending_for_record(staged).status=="staged"
  and Cargo0851.get(lead,staged),
  "staging lease and engine cargo must be recoverable from persistent storage")
-- The next ancestor cannot be mined while its priest still holds the leaf item.
lead.command_hierarchy_0480.peer_units={}
local eligible_parent,blocked_parent=Recovery.check_candidate(
  middle,lead,"junior-cogitator-station")
assert(not eligible_parent and blocked_parent=="station-has-engine-carried-custody",
  "never dismantle a carrier's home station before physical handoff")
-- A failed destination allocation must leave the real carried item intact.
lead.priest.position={x=magos.station.position.x,y=magos.station.position.y}
local allocate=game.create_inventory
game.create_inventory=function() error("depot allocation unavailable") end
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-magos-depot-handoff-blocked:depot-engine-inventory-allocation-refused"
  and bags0851[1].stock==1 and bags0851[1].valid
  and #bags0851==1 and mine_count==1,
  "allocation refusal must not debit or invent station stock")
game.create_inventory=allocate
-- A real destination can reject insertion. Debit must be refunded into the
-- SAME engine-owned carrier, with no phantom depot credit.
local old_create=game.create_inventory
game.create_inventory=function(size)
  local bag=old_create(size)
  local insert=bag.insert
  bag.insert=function() return 0 end
  bag.enable_insert=function() bag.insert=insert end
  return bag
end
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-magos-depot-handoff-blocked:depot-insert-refused-item-refunded"
  and bags0851[1].stock==1 and bags0851[2].stock==0
  and mine_count==1 and #bags0851==2,
  "failed Magos depot insertion must return the original physical item")
game.create_inventory=old_create
-- The original priest and lease remain protected; depot is a separate real
-- LuaInventory. Callback errors after actual insertion are reconciled by
-- inventory readback rather than by trusting the callback return value.
bags0851[2].enable_insert()
local insert= bags0851[2].insert
bags0851[2].insert=function(stack)
  insert(stack)
  error("post-insert callback error")
end
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-leaf-item-stored-in-magos-depot"
  and staged.phase=="in-magos-depot"
  and bags0851[1].stock==0 and not bags0851[1].valid
  and bags0851[2].stock==1 and bags0851[2].valid
  and not Cargo0851.has_record(staged)
  and mine_count==1 and original_leaf_priest.valid
  and Relocation0851.pending_for_record(staged).status=="staged",
  "counted handoff must debit carrier, credit protected depot and preserve priest")
local Depot0852=require("scripts.core.station_starvation_depot_0852")
local depot=Depot0852.get(magos,lead,staged)
assert(depot and depot.status=="stored" and depot.inventory==bags0851[2])
-- The original worker can now be considered for ancestor recovery, but
-- no ancestor is automatically mined or redeployed by this iteration.
local next_ok,next_reason=Recovery.check_candidate(middle,lead,item)
assert(next_ok and next_reason=="eligible-for-lifecycle-lease",
  "successful handoff must release the original carrier's inventory custody")
-- 0881: actual second-stage service repairs a three-tile idle hidden
-- proxy drift, then still refuses to preempt an Intermediate's existing duty.
lead.priest.force=lead.station.force
lead.priest.surface=lead.station.surface
local recovery_proxy_0881={valid=true,unit_number=9881,
  name="tech-priest-small-arms-proxy",force=lead.priest.force,
  surface=lead.priest.surface,
  position={x=lead.priest.position.x+3,y=lead.priest.position.y},
  ammo={["firearm-magazine"]=19}}
local align_count_0881=0
recovery_proxy_0881.teleport=function(pos)
  align_count_0881=align_count_0881+1
  recovery_proxy_0881.position={x=pos.x,y=pos.y}
  return true
end
lead.proxy=recovery_proxy_0881
local proxy_ok_0881,proxy_why_0881=Recovery.check_candidate(middle,lead,item)
assert(not proxy_ok_0881 and proxy_why_0881=="linked-helper-needs-lifecycle:proxy",
  "0822 must reject a real drifting proxy before the stage repair")
local original_middle_mode_0881=middle.mode
middle.mode="direct-acquisition-working"
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
local after_proxy_ok_0881,after_proxy_why_0881=Recovery.check_candidate(middle,lead,item)
if not (first and phase=="reversal-ancestor-worker-busy"
    and align_count_0881==1 and after_proxy_ok_0881) then
  print("[0881-diagnostic] phase="..tostring(phase).." first="..tostring(first)
    .." aligned="..tostring(align_count_0881)
    .." preflight="..tostring(after_proxy_ok_0881)
    .." reason="..tostring(after_proxy_why_0881)
    .." middle_mode="..tostring(middle.mode))
end
assert(first and phase=="reversal-ancestor-worker-busy"
  and align_count_0881==1 and after_proxy_ok_0881
  and lead.proxy==recovery_proxy_0881
  and recovery_proxy_0881.ammo["firearm-magazine"]==19
  and not expansion_rec.reversal_stage_0853 and mine_count==1
  and #bags0851==2 and bags0851[2].stock==1,
  "real 0853 must realign original proxy without mining or preempting worker")
middle.mode=original_middle_mode_0881
lead.proxy=nil
print("[station-starvation-live-proxy-0881] PASS actual 0853 idle proxy alignment, strict 0822 recheck and worker refusal")
-- Second Junior: its Intermediate parent must walk and mine only after
-- the first real item is safely deposited and the Junior's custody clears.
lead.inventory=inventory({["iron-ore"]=1})
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-ancestor-live-preflight:station-inventory-not-empty"
  and mine_count==1 and #bags0851==2
  and not expansion_rec.reversal_stage_0853,
  "occupied ancestor must not be mined or assigned a carrier")
lead.inventory=inventory()
reject_ancestor_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-ancestor-junior-movement-refused"
  and expansion_rec.reversal_stage_0853.phase=="to-leaf"
  and mine_count==1 and #bags0851==2,
  "refused Intermediate movement must not physically mine or fabricate cargo")
reject_ancestor_move=false
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-ancestor-walking-to-junior"
  and expansion_rec.reversal_stage_0853.phase=="to-leaf"
  and #bags0851==2 and mine_count==1,
  "second stage must walk a distinct Intermediate worker; observed "..tostring(phase))
local ancestor_stage=expansion_rec.reversal_stage_0853
local original_junior_priest=lead.priest
local second_mines=0
lead.station.mine=function(args)
  second_mines=second_mines+1
  assert(args.force==true and args.raise_destroy==true)
  assert(Relocation0851.intercept_removed(lead.station,{
    name=defines.events.script_raised_destroy
  }),"second Junior mine must preserve the original priest")
  lead.station.valid=false
  args.inventory.stock=args.inventory.stock+1
  return true
end
middle.priest.position={x=lead.station.position.x,y=lead.station.position.y}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-ancestor-carrying-junior-item-to-magos"
  and second_mines==1 and #bags0851==3 and bags0851[3].stock==1
  and original_junior_priest.valid and not lead.station.valid
  and storage.tech_priests.pairs_by_station[103]==nil
  and Relocation0851.protect_priest(lead,original_junior_priest)
  and bags0851[2].stock==1,
  "second Junior mine must preserve both original priests and physical items")
-- A rejected return command is not a completed transfer: the *same* mined
-- item must remain in the carrier's real engine inventory, and no Magos depot
-- may be credited while the Intermediate has not walked back.
reject_ancestor_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-ancestor-return-movement-refused"
  and expansion_rec.reversal_stage_0853.phase=="to-magos"
  and #bags0851==3 and bags0851[3].valid and bags0851[3].stock==1
  and second_mines==1 and not Depot0852.get_staged(magos,ancestor_stage)
  and original_junior_priest.valid
  and Relocation0851.pending_for_record(ancestor_stage).status=="staged",
  "refused Intermediate return must conserve physical Junior item and priest")
reject_ancestor_move=false
middle.priest.position={x=magos.station.position.x,y=magos.station.position.y}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-ancestor-junior-item-stored-in-magos-depot"
  and #bags0851==4 and bags0851[3].stock==0 and not bags0851[3].valid
  and bags0851[4].stock==1 and bags0851[2].stock==1
  and not Cargo0851.has_record(ancestor_stage)
  and Relocation0851.pending_for_record(ancestor_stage).status=="staged",
  "second handoff must count exact carrier debit and independent Magos credit")
local staged_first=Depot0852.get_staged(magos,staged)
local staged_second=Depot0852.get_staged(magos,ancestor_stage)
assert(staged_first and staged_second and staged_first.inventory~=staged_second.inventory
  and staged_first.inventory.stock==1 and staged_second.inventory.stock==1,
  "two recovered Junior items must survive in separate protected inventories")

-- Third physical recovery: the Senior may mine Intermediate only after
-- BOTH original Junior items remain in separate real Magos depot inventories.
-- A hierarchy rebuild removes the physically mined Junior subordinate edge.
middle.command_hierarchy_0480.direct_subordinate_units={}
middle.inventory=inventory({["iron-ore"]=1})
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-intermediate-live-preflight:station-inventory-not-empty"
  and not expansion_rec.reversal_stage_0854 and #bags0851==4,
  "occupied Intermediate cannot be mined even after two Junior depots")
middle.inventory=inventory()
local original_intermediate_priest=middle.priest
local third_mines=0
local reject_senior_move=false
local original_walk=walk
walk=function(priest,command)
  if priest==senior.priest and reject_senior_move then return false end
  return original_walk(priest,command)
end
reject_senior_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-intermediate-movement-refused"
  and expansion_rec.reversal_stage_0854.phase=="to-leaf"
  and third_mines==0 and #bags0851==4,
  "Senior's refused walk must not mine Intermediate or debit depot")
reject_senior_move=false
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-intermediate-walking-to-station"
  and third_mines==0 and #bags0851==4,
  "0875 legacy third-stage compatibility: handled="..tostring(first)
    .." phase="..tostring(phase).." mines="..tostring(third_mines)
    .." depots="..tostring(#bags0851)
    .." denial="..tostring(expansion_rec.reversal_intermediate_route_denial_0875))
middle.station.mine=function(args)
  third_mines=third_mines+1
  assert(args.force==true and args.raise_destroy==true)
  assert(Relocation0851.intercept_removed(middle.station,{
    name=defines.events.script_raised_destroy
  }),"Intermediate mine must preserve its original priest")
  middle.station.valid=false
  assert(args.inventory.insert{name="intermediate-cogitator-station",count=1}==1)
  return true
end
senior.priest.position={x=middle.station.position.x,y=middle.station.position.y}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-intermediate-carrying-item-to-magos"
  and third_mines==1 and #bags0851==5
  and bags0851[5].stock==1
  and bags0851[5].item=="intermediate-cogitator-station"
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and original_intermediate_priest.valid
  and storage.tech_priests.pairs_by_station[102]==nil
  and Relocation0851.protect_priest(middle,original_intermediate_priest),
  "Intermediate must be mined physically into a third distinct carrier")
local intermediate_stage=expansion_rec.reversal_stage_0854
-- The Senior's return movement may be refused after the real Intermediate
-- has already been mined. The engine-owned carrier and original priest stay
-- under their existing lease, and neither protected Junior depot is debited.
reject_senior_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-intermediate-return-movement-refused"
  and intermediate_stage.phase=="to-magos"
  and #bags0851==5 and bags0851[5].valid and bags0851[5].stock==1
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and not Depot0852.get_staged(magos,intermediate_stage)
  and third_mines==1 and original_intermediate_priest.valid
  and Relocation0851.pending_for_record(intermediate_stage).status=="staged",
  "refused Senior return must conserve physical Intermediate item and priest")
reject_senior_move=false
senior.priest.position={x=magos.station.position.x,y=magos.station.position.y}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-intermediate-item-stored-in-magos-depot"
  and #bags0851==6 and not bags0851[5].valid
  and bags0851[6].stock==1
  and bags0851[6].item=="intermediate-cogitator-station"
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and not Cargo0851.has_record(intermediate_stage)
  and Relocation0851.pending_for_record(intermediate_stage).status=="staged",
  "Intermediate item must be counted at Magos with both Junior items intact")
local third_depot=Depot0852.get_staged(magos,intermediate_stage)
assert(third_depot and third_depot.inventory==bags0851[6]
  and Depot0852.get_staged(magos,staged)
  and Depot0852.get_staged(magos,ancestor_stage),
  "all three distinct protected depot items and original priests must survive")

-- 0855: the original Magos physically recovers its childless direct Senior,
-- after exact readback of all three earlier station-item depots.
senior.command_hierarchy_0480.direct_subordinate_units={}
magos.station_expansion_0256=expansion_rec
senior.inventory=inventory({["iron-ore"]=1})
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-live-preflight:station-inventory-not-empty"
  and not expansion_rec.reversal_stage_0855 and #bags0851==6,
  "occupied Senior must remain intact")
senior.inventory=inventory()
local original_senior_priest=senior.priest
local fourth_mines=0
local reject_magos_move=false
local old_walk=walk
walk=function(priest,command)
  if priest==magos.priest then
    assert(command.type==defines.command.go_to_location)
    commands[#commands+1]=command.destination
    return not reject_magos_move
  end
  return old_walk(priest,command)
end
magos.active_task={kind="existing-work"}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-magos-busy"
  and not expansion_rec.reversal_stage_0855 and fourth_mines==0,
  "Magos may not preempt an existing task to mine Senior")
magos.active_task=nil
reject_magos_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-magos-movement-refused"
  and expansion_rec.reversal_stage_0855.phase=="to-leaf"
  and fourth_mines==0 and #bags0851==6,
  "refused Magos outward walk must not mine Senior")
reject_magos_move=false
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-magos-walking-to-station"
  and fourth_mines==0 and #bags0851==6)
senior.station.mine=function(args)
  fourth_mines=fourth_mines+1
  assert(args.force==true and args.raise_destroy==true)
  assert(Relocation0851.intercept_removed(senior.station,{
    name=defines.events.script_raised_destroy
  }),"Senior mine must preserve its original priest")
  senior.station.valid=false
  assert(args.inventory.insert{name="senior-cogitator-station",count=1}==1)
  return true
end
magos.priest.position={x=senior.station.position.x,y=senior.station.position.y}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-magos-carrying-item-home"
  and fourth_mines==1 and #bags0851==7
  and bags0851[7].stock==1 and bags0851[7].item=="senior-cogitator-station"
  and original_senior_priest.valid and not senior.station.valid
  and storage.tech_priests.pairs_by_station[101]==nil
  and Relocation0851.protect_priest(senior,original_senior_priest)
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and bags0851[6].stock==1,
  "Magos must physically mine Senior into fourth engine hold")
local senior_stage=expansion_rec.reversal_stage_0855
reject_magos_move=true
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-magos-return-refused"
  and fourth_mines==1 and #bags0851==7
  and bags0851[7].stock==1 and bags0851[7].valid
  and not Depot0852.get_staged(magos,senior_stage),
  "refused return must not credit fourth depot or duplicate item")
reject_magos_move=false
magos.priest.position={x=magos.station.position.x,y=magos.station.position.y}
first,phase=Reversal.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-item-stored-in-magos-depot"
  and #bags0851==8 and not bags0851[7].valid
  and bags0851[8].stock==1 and bags0851[8].item=="senior-cogitator-station"
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and bags0851[6].stock==1 and fourth_mines==1
  and not Cargo0851.has_record(senior_stage)
  and Relocation0851.pending_for_record(senior_stage).status=="staged",
  "fourth handoff must conserve Senior item and original priest")
local fourth_depot=Depot0852.get_staged(magos,senior_stage)
assert(fourth_depot and fourth_depot.inventory==bags0851[8]
  and fourth_depot.inventory~=third_depot.inventory
  and fourth_depot.inventory~=staged_first.inventory
  and fourth_depot.inventory~=staged_second.inventory
  and original_leaf_priest.valid and original_junior_priest.valid
  and original_intermediate_priest.valid and original_senior_priest.valid,
  "four independent engine depots must preserve four original priests")
local Auditor0867=require("scripts.core.station_starvation_rebuild_0867")
local seal,audit_reason=Auditor0867.audit(magos,expansion_rec)
assert(seal and seal.stage_count==4 and #seal.items==4
  and audit_reason=="four-real-depots-and-original-priests-verified"
  and seal.items[1].station_unit==104
  and seal.items[2].station_unit==103
  and seal.items[3].station_unit==102
  and seal.items[4].station_unit==101
  and seal.items[4].item=="senior-cogitator-station",
  "outward reconstruction cannot start without four exact physical receipts")
-- 0868: four individually valid depots must still belong to the SAME
-- original hierarchy and to the SAME live natural-ore objective. The
-- readiness audit cannot authorize a different target or cross-wired chain.
local mission_target=magos.resource_expansion_0259.chain_0820.target
magos.resource_expansion_0259.chain_0820.target={
  x=mission_target.x+1,y=mission_target.y}
local denied,why=Auditor0867.audit(magos,expansion_rec)
assert(not denied and why=="four-depot-original-resource-target-changed",
  "four conserved items must not authorize rebuilding toward changed ore")
magos.resource_expansion_0259.chain_0820.target=mission_target
local original_parent=plan.stages[2].parent_station_unit
plan.stages[2].parent_station_unit=plan.stages[4].station_unit
local denied_chain,chain_why=Auditor0867.audit(magos,expansion_rec)
assert(not denied_chain
  and chain_why=="four-depot-stage-identity-or-removal-invalid:2",
  "cross-wired original station hierarchy must not authorize redeployment")
plan.stages[2].parent_station_unit=original_parent
local original_carrier=ancestor_stage.worker_priest_unit
ancestor_stage.worker_priest_unit=magos.priest.unit_number
local denied_carrier,carrier_why=Auditor0867.audit(magos,expansion_rec)
assert(not denied_carrier
  and carrier_why=="four-depot-original-chain-or-carrier-invalid:2",
  "saved receipt cannot substitute the Magos for the original carrier priest")
ancestor_stage.worker_priest_unit=original_carrier
assert(Auditor0867.audit(magos,expansion_rec)
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and bags0851[6].stock==1 and bags0851[8].stock==1
  and original_leaf_priest.valid and original_junior_priest.valid
  and original_intermediate_priest.valid and original_senior_priest.valid,
  "failed target/chain/worker audits must not mutate physical custody")
print("[station-starvation-four-depot-0868] PASS original ore target, linked original carriers, fail-closed custody")
local prior_stock=bags0851[4].stock
bags0851[4].stock=0
assert(not Auditor0867.audit(magos,expansion_rec),
  "debit of a protected second depot must invalidate rebuild readiness")
bags0851[4].stock=prior_stock
local first_record=storage.tech_priests.station_reversal_depot_0852[staged.id]
local second_record=storage.tech_priests.station_reversal_depot_0852[ancestor_stage.id]
local original_second_inventory=second_record.inventory
second_record.inventory=first_record.inventory
assert(not Auditor0867.audit(magos,expansion_rec),
  "reusing one counted inventory for two stations is not four distinct items")
second_record.inventory=original_second_inventory
assert(Auditor0867.audit(magos,expansion_rec),
  "restoring independent inventory identities must restore read-only readiness")

package.loaded["scripts.core.station_starvation_depot_0852"]=nil
package.loaded["scripts.core.station_starvation_ancestor_0853"]=nil
package.loaded["scripts.core.station_starvation_intermediate_0854"]=nil
package.loaded["scripts.core.station_starvation_senior_0855"]=nil
package.loaded["scripts.core.station_starvation_rebuild_0867"]=nil
package.loaded["scripts.core.station_starvation_reversal_0850"]=nil
local Reloaded0851=require("scripts.core.station_starvation_reversal_0850")
first,phase=Reloaded0851.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-item-stored-in-magos-depot"
  and mine_count==1 and second_mines==1 and third_mines==1
  and fourth_mines==1 and #bags0851==8
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and bags0851[6].stock==1 and bags0851[8].stock==1
  and original_intermediate_priest.valid and original_senior_priest.valid
  and original_leaf_priest.valid and original_junior_priest.valid,
  "reload must preserve four counted depot items without re-mining or duplication")
-- Missing plans must still quarantine the living priest and real depot item.
local original_plan=expansion_rec.reversal_plan_0850
-- Corrupt saved predecessors AFTER the fourth real mine and deposit. These
-- invalid plans must leave all four engine-owned holds and priests untouched.
local Senior0855=require("scripts.core.station_starvation_senior_0855")
for i=1,3 do
  local saved=original_plan.stages[i]
  original_plan.stages[i]=nil
  local commands_before=#commands
  local safe,handled,reason=pcall(Senior0855.service,
    magos,expansion_rec,original_plan,walk)
  assert(safe and handled
    and reason=="reversal-senior-prior-stage-plan-invalid:"..i
    and #commands==commands_before and mine_count==1
    and second_mines==1 and third_mines==1 and fourth_mines==1
    and bags0851[2].stock==1 and bags0851[2].valid
    and bags0851[4].stock==1 and bags0851[4].valid
    and bags0851[6].stock==1 and bags0851[6].valid
    and bags0851[8].stock==1 and bags0851[8].valid
    and original_leaf_priest.valid and original_junior_priest.valid
    and original_intermediate_priest.valid and original_senior_priest.valid,
    "missing saved predecessor must quarantine four physical depots")
  original_plan.stages[i]=saved
end
local descriptor=original_plan.stages[2]
original_plan.stages[2]="corrupt-plan-descriptor"
local safe,handled,reason=pcall(Senior0855.service,
  magos,expansion_rec,original_plan,walk)
assert(safe and handled
  and reason=="reversal-senior-prior-stage-plan-invalid:2"
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and bags0851[6].stock==1 and bags0851[8].stock==1
  and original_senior_priest.valid,
  "non-table descriptor cannot crash the runtime or debit custody")
original_plan.stages[2]=descriptor
expansion_rec.reversal_plan_0850=nil
local walks_before=#commands
first,phase=Reloaded0851.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-staged-plan-or-root-unavailable"
  and #commands==walks_before and mine_count==1 and second_mines==1
  and fourth_mines==1 and bags0851[2].stock==1 and bags0851[2].valid
  and bags0851[4].stock==1 and bags0851[4].valid
  and bags0851[6].stock==1 and bags0851[6].valid
  and bags0851[8].stock==1 and bags0851[8].valid
  and Relocation0851.pending_for_record(staged).status=="staged"
  and original_leaf_priest.valid,
  "missing plan must quarantine protected depot and original priest")
expansion_rec.reversal_plan_0850=original_plan
first,phase=Reloaded0851.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-senior-item-stored-in-magos-depot"
  and mine_count==1 and second_mines==1 and third_mines==1
  and fourth_mines==1 and bags0851[2].stock==1
  and bags0851[4].stock==1 and bags0851[6].stock==1
  and bags0851[8].stock==1,
  "restored plan must resume four protected depots without re-mining")
local original_stage_id=staged.id
staged.id="tampered-stage"
first,phase=Reloaded0851.service_first_leaf(magos,expansion_rec,walk)
assert(first and phase=="reversal-stage-identity-changed"
  and bags0851[2].stock==1 and bags0851[4].stock==1
  and bags0851[6].stock==1 and bags0851[8].stock==1
  and mine_count==1 and second_mines==1 and third_mines==1
  and fourth_mines==1
  and Relocation0851.protect_priest(leaf,original_leaf_priest),
  "changed stage identity must fail closed and preserve real custody")
staged.id=original_stage_id
-- Saved-plan and stage corruption must never turn a completed physical
-- recovery into a Lua tick exception or release a real item from custody.
local protected_stock={bags0851[2],bags0851[4],bags0851[6],bags0851[8]}
local function assert_four_depots_untouched(label,commands_before)
  assert(#commands==commands_before and mine_count==1
    and second_mines==1 and third_mines==1 and fourth_mines==1
    and original_leaf_priest.valid and original_junior_priest.valid
    and original_intermediate_priest.valid and original_senior_priest.valid,
    label..": original priests or mining counts changed")
  for _,bag in ipairs(protected_stock) do
    assert(bag.valid and bag.stock==1,
      label..": original engine-owned depot was debited")
  end
end
local saved_first=original_plan.stages[1]
for _,bad in ipairs({"corrupt-descriptor",false}) do
  original_plan.stages[1]=bad
  local before=#commands
  local ok,handled,why=pcall(Reloaded0851.service_first_leaf,
    magos,expansion_rec,walk)
  assert(ok and handled and why=="reversal-stage-order-unavailable",
    "corrupt first-stage descriptor must be refused, not dereferenced")
  assert_four_depots_untouched("first-stage plan corruption",before)
end
original_plan.stages[1]=saved_first
local saved_plan=expansion_rec.reversal_plan_0850
expansion_rec.reversal_plan_0850="corrupt-plan"
local before=#commands
local ok,handled,why=pcall(Reloaded0851.service_first_leaf,
  magos,expansion_rec,walk)
assert(ok and handled and why=="reversal-staged-plan-or-root-unavailable",
  "non-table saved reversal plan must quarantine existing custody")
assert_four_depots_untouched("non-table plan",before)
expansion_rec.reversal_plan_0850=saved_plan
local cases={
  {field="reversal_stage_0851",fn=Reloaded0851.service_first_leaf,
   reason="reversal-stage-identity-changed",args={magos,expansion_rec,walk}},
  {field="reversal_stage_0853",
   fn=require("scripts.core.station_starvation_ancestor_0853").service,
   reason="reversal-ancestor-stage-identity-changed",
   args={magos,expansion_rec,original_plan,walk}},
  {field="reversal_stage_0854",
   fn=require("scripts.core.station_starvation_intermediate_0854").service,
   reason="reversal-intermediate-stage-identity-changed",
   args={magos,expansion_rec,original_plan,walk}},
  {field="reversal_stage_0855",fn=Senior0855.service,
   reason="reversal-senior-stage-identity-changed",
   args={magos,expansion_rec,original_plan,walk}}
}
for _,case in ipairs(cases) do
  local previous=expansion_rec[case.field]
  expansion_rec[case.field]="corrupt-stage"
  local before=#commands
  local safe,refused,reason=pcall(case.fn,table.unpack(case.args))
  assert(safe and refused and reason==case.reason,
    case.field.." must reject malformed persisted stage")
  assert_four_depots_untouched(case.field,before)
  expansion_rec[case.field]=previous
end
print("[station-starvation-saved-custody-0858] PASS malformed plan and four stage records fail closed with four exact depots and original priests")
print("[station-starvation-staging-0851] PASS real mine, counted Magos depot handoff, refusal refund, original priest, ancestor custody and reload")

print("[station-starvation-ancestor-0853] PASS fresh second-Junior preflight, physical mine, two counted Magos depots, original priests, and reload")
print("[station-starvation-intermediate-0854] PASS fresh Intermediate preflight, refused Senior walk, real mine, three protected Magos depots, three original priests, and reload")

print("[station-starvation-senior-0855] PASS Magos-owned fourth physical mine, refused travel, four exact depots, four original priests, and reload")
