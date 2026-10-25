-- Method I: fail-closed five-station, no-spare-item reversal preflight.
-- This is an ordering witness, NOT permission to mine, move or fabricate stock.
-- Each eventual physical stage must independently revalidate 0822 custody and
-- hierarchy before taking a real station item into an engine-owned carrier.
local Recovery = require("scripts.core.station_recycling_0822")
local M = { version = "0.1.674-dev.0850" }

local expected = {
  [3] = "senior-cogitator-station",
  [2] = "intermediate-cogitator-station",
  [1] = "junior-cogitator-station",
}
local function valid(pair)
  return pair and pair.station and pair.station.valid
    and pair.priest and pair.priest.valid
    and pair.station.unit_number ~= nil
end
local function dist2(a, b)
  local x, y = a.x-b.x, a.y-b.y
  return x*x+y*y
end
local function rank(h, pair)
  local ok, result = pcall(h.rank, pair)
  return ok and tonumber(result) or nil
end
local function same_domain(a, b)
  return a.station.surface == b.station.surface
    and a.station.force == b.station.force
end
local function only_child(tp, h, parent, required_rank, label)
  local slate = parent.command_hierarchy_0480
  local ids = slate and slate.direct_subordinate_units
  if type(ids) ~= "table" or #ids ~= 1 then
    return nil, "ambiguous-" .. label .. "-subordinates"
  end
  local id = ids[1]
  local child = tp.pairs_by_station[id]
  if not valid(child) then return nil, "missing-" .. label .. "-pair" end
  if not same_domain(parent, child) or rank(h, child) ~= required_rank
      or child.station.name ~= expected[required_rank] then
    return nil, "wrong-" .. label .. "-rank-or-domain"
  end
  local ch = child.command_hierarchy_0480
  if not (ch and ch.superior_unit == parent.station.unit_number
      and h.is_direct_subordinate(parent, child) == true) then
    return nil, "invalid-" .. label .. "-link"
  end
  return child
end

function M.preflight(magos, target, station_item)
  if station_item ~= expected[3] then return nil, "not-senior-item" end
  if not (valid(magos) and target and type(target.x) == "number"
      and type(target.y) == "number") then
    return nil, "root-or-known-resource-target-unavailable"
  end
  local tp = storage and storage.tech_priests
  local h = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not (tp and type(tp.pairs_by_station) == "table" and h
      and type(h.rank) == "function"
      and type(h.is_direct_subordinate) == "function"
      and type(h.peers) == "function") then
    return nil, "hierarchy-or-pair-registry-unavailable"
  end
  if rank(h, magos) ~= 4 then return nil, "not-planetary-magos" end
  local senior, reason = only_child(tp, h, magos, 3, "root")
  if not senior then return nil, reason end
  local intermediate
  intermediate, reason = only_child(tp, h, senior, 2, "senior")
  if not intermediate then return nil, reason end
  local junior
  junior, reason = only_child(tp, h, intermediate, 1, "intermediate")
  if not junior then return nil, reason end
  local peers = h.peers(junior)
  local slate = junior.command_hierarchy_0480
  if type(peers) ~= "table" or #peers ~= 1
      or not slate or type(slate.peer_units) ~= "table"
      or #slate.peer_units ~= 1 then
    return nil, "ambiguous-junior-peers"
  end
  local leaf = peers[1]
  if not valid(leaf) or leaf == junior
      or leaf.station.unit_number ~= slate.peer_units[1]
      or not same_domain(junior, leaf)
      or rank(h, leaf) ~= 1 or leaf.station.name ~= expected[1] then
    return nil, "invalid-junior-peer"
  end
  local leaf_slate = leaf.command_hierarchy_0480
  local back = h.peers(leaf)
  if not (leaf_slate and type(leaf_slate.peer_units) == "table"
      and #leaf_slate.peer_units == 1
      and leaf_slate.peer_units[1] == junior.station.unit_number
      and type(back) == "table" and #back == 1 and back[1] == junior
      and type(leaf_slate.direct_subordinate_units) == "table"
      and #leaf_slate.direct_subordinate_units == 0
      and leaf_slate.superior_unit == nil) then
    return nil, "leaf-has-other-command-custody"
  end
  local seen = {}
  for _, pair in ipairs({magos, senior, intermediate, junior, leaf}) do
    local id = pair.station.unit_number
    if seen[id] or tp.pairs_by_station[id] ~= pair
        or not same_domain(magos, pair) then
      return nil, "duplicate-foreign-or-unregistered-station"
    end
    seen[id] = true
  end
  -- Reversal is justified only if the existing terminal is farther from
  -- the real needed patch than the Magos itself. Never dismantle a useful
  -- forward chain just because a station item happens to be unavailable.
  if dist2(leaf.station.position, target)
      <= dist2(magos.station.position, target) then
    return nil, "existing-chain-not-opposed-to-target"
  end
  local safe, why = Recovery.check_candidate(junior, leaf, expected[1])
  if not safe then return nil, "leaf-preflight:" .. tostring(why) end
  -- Primitive IDs only: safe across save/reload. Ancestors are NOT cleared
  -- or certified yet; each will require a fresh 0822 check after its children
  -- have been physically recovered and all real custody has been reconciled.
  return {
    status = "leaf-first-preflight-only",
    root_station_unit = magos.station.unit_number,
    target = {x=target.x, y=target.y},
    required_item = station_item,
    stages = {
      {parent_station_unit=junior.station.unit_number,
       station_unit=leaf.station.unit_number, item=expected[1]},
      {parent_station_unit=intermediate.station.unit_number,
       station_unit=junior.station.unit_number, item=expected[1]},
      {parent_station_unit=senior.station.unit_number,
       station_unit=intermediate.station.unit_number, item=expected[2]},
      {parent_station_unit=magos.station.unit_number,
       station_unit=senior.station.unit_number, item=expected[3]},
    },
    first_leaf_preflight_tick = game and game.tick or 0,
  }, "leaf-first-order-verified-no-items-moved"
end
_G.TechPriestsStationStarvationReversal0850 = M
return M
