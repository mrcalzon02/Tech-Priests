-- scripts/core/direct_acquisition_physical_guard_0649.lua
-- Tech Priests 0.1.653
-- Commandless physical-target guard for direct acquisition.

local M = {}
M.version = "0.1.653"
M.storage_key = "direct_acquisition_physical_guard_0649"
M.search_radius = 2.75
M.max_pairs_per_pulse = 32
M.tick_interval = 29

local DIRECT_KINDS = { ["direct-mine-0273"] = true, ["direct-mine-0336"] = true, ["direct-dirt-0273"] = true, dirt = true }
local RESOURCE_ITEMS = { ["iron-ore"] = true, ["copper-ore"] = true, coal = true, stone = true, ["uranium-ore"] = true, wood = true }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}
  return r
end

local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail)
  local r = root(); stat(action)
  r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  while #r.recent > 100 do table.remove(r.recent, 1) end
end

local function item_exists(name) return name and prototypes and prototypes.item and prototypes.item[name] ~= nil end
local function current_direct_task(pair)
  local Exec = rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
  if Exec and type(Exec.current_direct_task) == "function" then local ok, task, cur, key = pcall(Exec.current_direct_task, pair); if ok then return task, cur, key end end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair and pair[key]; local cur = type(task) == "table" and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur, key end
  end
  return nil, nil, nil
end

local function output_item(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.requested_item) or nil
  if item_exists(item) then return item end
  item = task and (task.output_item or task.item_name or task.wanted_item or task.requested_item) or nil
  if item_exists(item) then return item end
  return nil
end

local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  return nil
end

local function target_position(cur)
  local e = target_entity(cur)
  if e then return e.position end
  if cur and cur.position and cur.position.x and cur.position.y then return cur.position end
  return nil
end

local function entity_matches_item(entity, item)
  if not valid(entity) then return false end
  if entity.type == "resource" then return item == nil or entity.name == item end
  local n = lower(entity.name)
  if item == "wood" then return n:find("tree", 1, true) ~= nil end
  if item == "stone" then return n:find("rock", 1, true) ~= nil or n:find("stone", 1, true) ~= nil end
  if item == "coal" then return n:find("coal", 1, true) ~= nil end
  if item == "iron-ore" then return n:find("iron", 1, true) ~= nil end
  if item == "copper-ore" then return n:find("copper", 1, true) ~= nil end
  return false
end

local function find_physical_target(pair, pos, item)
  if not (valid_pair(pair) and pos) then return nil end
  local area = { { pos.x - M.search_radius, pos.y - M.search_radius }, { pos.x + M.search_radius, pos.y + M.search_radius } }
  local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ area = area }) end)
  if not (ok and ents) then return nil end
  local best, best_d2 = nil, nil
  for _, e in pairs(ents) do
    if valid(e) and e ~= pair.station and e ~= pair.priest and entity_matches_item(e, item) then local d2 = dist_sq(e.position, pos); if not best_d2 or d2 < best_d2 then best, best_d2 = e, d2 end end
  end
  return best
end

function M.guard_pair(pair, reason)
  if root().enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local task, cur, key = current_direct_task(pair)
  if not (task and cur and DIRECT_KINDS[tostring(cur.kind or "")]) then return false, "no-direct-task" end
  local item = output_item(task, cur)
  if item and not RESOURCE_ITEMS[item] then return false, "not-resource-acquisition" end
  local e = target_entity(cur)
  if valid(e) then
    if entity_matches_item(e, item) then return false, "has-physical-target" end
    cur.entity = nil; cur.target = nil; cur.source = nil
    record("physical-target-mismatch-cleared-0649", pair, "item=" .. safe(item) .. " entity=" .. safe(e.name))
  end
  local pos = target_position(cur)
  local found = find_physical_target(pair, pos, item)
  if found then
    cur.entity = found; cur.target = found; cur.source = found; cur.position = { x = found.position.x, y = found.position.y }; pair.target = found
    record("physical-target-adopted-0649", pair, "item=" .. safe(item) .. " entity=" .. safe(found.name) .. " key=" .. safe(key))
    return true, "adopted"
  end
  if task.current then task.current = nil else if key == "emergency_craft" then pair.emergency_craft = nil elseif key == "direct_acquisition_task_0336" then pair.direct_acquisition_task_0336 = nil elseif key == "active_acquisition_0333" then pair.active_acquisition_0333 = nil end end
  pair.target = nil; pair.mode = "direct-acquisition-needs-physical-target-0649"
  pair.dispatcher_direct_0513 = pair.dispatcher_direct_0513 or {}; pair.dispatcher_direct_0513.phase = "need-physical-target-0649"; pair.dispatcher_direct_0513.detail = "no physical resource target at planned position"; pair.dispatcher_direct_0513.item = item; pair.dispatcher_direct_0513.tick = now()
  record("physical-target-missing-0649", pair, "item=" .. safe(item) .. " key=" .. safe(key))
  return true, "cleared-stale-target"
end

local function wrap_direct_executor()
  local Exec = rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
  if not (Exec and type(Exec.service_pair) == "function") or Exec.physical_guard_0649_wrapped then return false end
  Exec.physical_guard_0649_wrapped = true
  Exec.TECH_PRIESTS_0649_PRE_SERVICE_PAIR = Exec.service_pair
  Exec.service_pair = function(pair, reason, ...)
    local _, cur = current_direct_task(pair)
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] and not target_entity(cur) then local acted, why = M.guard_pair(pair, reason or "pre-0513"); if acted and why ~= "adopted" then return false, why end end
    return Exec.TECH_PRIESTS_0649_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

function M.service_pair(pair, reason) return M.guard_pair(pair, reason or "service") end
function M.service_all(reason)
  local n = 0
  for _, pair in pairs(pair_map()) do if n >= M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end end
  return n
end

function M.install()
  root(); wrap_direct_executor(); _G.TechPriestsDirectAcquisitionPhysicalGuard0649 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "direct_acquisition_physical_guard_0649", category = "acquisition", interval = M.tick_interval, priority = 52, budget = 6, fn = function(event, budget) wrap_direct_executor(); M.service_all("broker"); return true end, note = "prevent synthetic direct-resource deposits without a physical target entity" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() wrap_direct_executor(); M.service_all("nth-tick") end, { owner = "direct_acquisition_physical_guard_0649", category = "acquisition", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() wrap_direct_executor(); M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.653] direct acquisition physical guard installed") end
  return true
end

return M
