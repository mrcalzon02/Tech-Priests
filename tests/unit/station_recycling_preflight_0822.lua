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
