-- Tech Priests 0.1.674-dev critical supply completion.
-- One real emergency supply item satisfies its full parent/child work chain.

local M = {}
M.version = "0.1.674-dev"
M.interval = 3

local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function requested_supply(v, seen)
  if type(v) == "string" then
    local s = lower(v)
    return s == "firearm-magazine" or s == "ammo" or s == "ammunition" or s == "magazine"
  end
  if type(v) ~= "table" then return false end
  seen = seen or {}
  if seen[v] then return false end
  seen[v] = true
  for _, key in ipairs({"item", "item_name", "output_item", "requested_item", "wanted_item", "target_item", "parent_item", "kind"}) do
    if requested_supply(v[key], seen) then return true end
  end
  for _, key in ipairs({"current", "request", "task", "parent", "order"}) do
    if requested_supply(v[key], seen) then return true end
  end
  return false
end

local function supply_present(pair)
  local hardener = rawget(_G, "TechPriestsProxyAmmoHardener0649")
  if not hardener then return false end
  local station = false
  local proxy = false
  if type(hardener.station_has_ammo) == "function" then
    local ok, result = pcall(hardener.station_has_ammo, pair)
    station = ok and result == true
  end
  if type(hardener.proxy_has_ammo) == "function" then
    local ok, result = pcall(hardener.proxy_has_ammo, pair)
    proxy = ok and result == true
  end
  if station and type(hardener.load_proxy_from_station) == "function" then
    pcall(hardener.load_proxy_from_station, pair, "critical-supply-0741")
    proxy = true
  end
  return station or proxy
end

local function clear_field(pair, field)
  if requested_supply(pair[field]) then pair[field] = nil; return true end
  return false
end

function M.service_pair(pair)
  if not (pair and valid(pair.station) and valid(pair.priest) and supply_present(pair)) then return false end
  local changed = false
  for _, field in ipairs({
    "active_supply_request", "supply_request", "inventory_scan", "scavenge",
    "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333",
    "active_task", "active_task_0285"
  }) do
    changed = clear_field(pair, field) or changed
  end
  if requested_supply(pair.logistic_requested_item) then
    pair.logistic_requested_item = nil
    pair.logistic_requested_count = nil
    changed = true
  end
  if requested_supply(pair.requested_item) then pair.requested_item = nil; changed = true end
  if requested_supply(pair.last_item) then pair.last_item = nil; changed = true end

  pair.direct_acquisition_target_lock_0650 = nil
  pair.need_ammunition = nil
  pair.no_ammo_0295 = nil
  pair.pinned_no_ammo_0295 = nil
  pair.last_combat_fail_0293 = nil
  pair.last_combat_fail_0295 = nil
  pair.next_ammo_supply_retry_tick_0295 = 0

  for _, field in ipairs({"blocker", "last_blocker", "emergency_blocker", "priority_blocker"}) do
    local text = lower(pair[field])
    if text:find("ammo", 1, true) or text:find("firearm%-magazine") then
      pair[field] = nil
      changed = true
    end
  end

  local op = pair.independent_emergency_operation_0184 or pair.independent_emergency_operation or pair.emergency_operation
  if type(op) == "table" and (requested_supply(op) or lower(op.phase):find("ammo", 1, true)) then
    op.last_item = nil
    op.requested_item = nil
    op.last_blocker_0264 = nil
    op.last_blocker_0266 = nil
    op.last_blocker_0267 = nil
    op.phase = "survival-satisfied"
    op.satisfied_tick_0741 = game and game.tick or 0
    changed = true
  end

  if pair.movement_request_0418 then
    local owner = lower(pair.movement_request_0418.owner)
    local reason = lower(pair.movement_request_0418.reason)
    if owner:find("direct", 1, true) or owner:find("logistics", 1, true)
      or reason:find("direct", 1, true) or reason:find("known%-source%-fetch") then
      pair.movement_request_0418 = nil
      changed = true
    end
  end

  if changed then
    pair.last_critical_supply_reconciliation_0741 = game and game.tick or 0
    if lower(pair.mode):find("ammo", 1, true) or lower(pair.mode):find("emergency%-gathering") then
      pair.mode = valid(pair.combat_target) and "defending" or "idle"
    end
  end
  return changed
end

function M.service_all()
  for _, pair in pairs(pair_map()) do M.service_pair(pair) end
end

function M.install()
  _G.TechPriestsCriticalSupplyReconciliation0741 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "critical_supply_reconciliation_0741",
      category = "logistics",
      interval = M.interval,
      priority = 1,
      budget = 8,
      fn = function() M.service_all(); return true end,
      note = "complete emergency parent work when its single real supply item is present"
    })
  end
  return true
end

return M
