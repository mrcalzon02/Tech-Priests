-- scripts/core/work_reservations.lua
-- Tech Priests 0.1.601
-- Shared short-lived reservation authority for repair/sanctify/resource/construction/pickup/combat work.
-- This is not a behavior controller.  It is a small arbitration layer so many
-- priests do not claim/path toward the same target simultaneously.

local M = {}
M.version = "0.1.620"
M.storage_key = "work_reservations_0601"
M.default_ttl = 600
M.categories = { "repair", "sanctify", "resource", "construction", "pickup", "combat" }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function pos_key(p) return p and string.format("%.1f,%.1f", tonumber(p.x) or 0, tonumber(p.y) or 0) or "no-pos" end

function M.target_key(target)
  if valid(target) then
    if target.unit_number then return "unit:" .. safe(target.unit_number) end
    return "entity:" .. safe(target.name) .. ":" .. pos_key(target.position)
  end
  if type(target) == "table" then
    if target.unit_number then return "unit:" .. safe(target.unit_number) end
    if target.position then return "pos:" .. pos_key(target.position) end
    if target.x and target.y then return "pos:" .. pos_key(target) end
    if target.id then return "id:" .. safe(target.id) end
    if target.key then return "key:" .. safe(target.key) end
  end
  return safe(target)
end

function M.pair_id(pair_or_id)
  if type(pair_or_id) ~= "table" then return safe(pair_or_id) end
  if valid(pair_or_id.station) and pair_or_id.station.unit_number then return safe(pair_or_id.station.unit_number) end
  return safe(pair_or_id.station_unit or pair_or_id.id or "unknown-pair")
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, reservations = {}, stats = {}, cleanup_cursor_0620 = 1 }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.reservations = r.reservations or {}
  r.stats = r.stats or {}
  for _, cat in ipairs(M.categories) do r.reservations[cat] = r.reservations[cat] or {} end
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end

function M.get(category, target)
  local r = M.root(); category = tostring(category or "misc")
  local bucket = r.reservations[category]; if not bucket then return nil end
  local key = M.target_key(target)
  local res = bucket[key]
  if res and (tonumber(res.expires_tick) or 0) <= now() then bucket[key] = nil; stat("expired_seen"); return nil end
  return res, key
end

function M.is_claimed(category, target, pair_or_id)
  local res = M.get(category, target)
  if not res then return false end
  if pair_or_id and safe(res.pair_id) == M.pair_id(pair_or_id) then return false end
  return true, res
end

function M.claim(category, target, pair_or_id, ttl, meta)
  local r = M.root(); if r.enabled == false then return true, "disabled" end
  category = tostring(category or "misc")
  r.reservations[category] = r.reservations[category] or {}
  local key = M.target_key(target)
  local pair_id = M.pair_id(pair_or_id)
  local existing = M.get(category, target)
  if existing and safe(existing.pair_id) ~= pair_id then stat("claim_denied"); return false, "claimed", existing end
  r.reservations[category][key] = {
    key = key,
    category = category,
    pair_id = pair_id,
    expires_tick = now() + (tonumber(ttl) or M.default_ttl),
    target_name = valid(target) and target.name or nil,
    target_unit = valid(target) and target.unit_number or nil,
    surface_index = valid(target) and target.surface and target.surface.index or (meta and meta.surface_index),
    force_index = valid(target) and target.force and target.force.index or (meta and meta.force_index),
    created_tick = existing and existing.created_tick or now(),
    renewed_tick = now(),
  }
  stat(existing and "claim_renewed" or "claim_created")
  return true, "claimed", r.reservations[category][key]
end

function M.release(category, target, pair_or_id)
  local r = M.root(); category = tostring(category or "misc")
  local bucket = r.reservations[category]; if not bucket then return false end
  local key = M.target_key(target)
  local res = bucket[key]
  if not res then return false end
  if pair_or_id and safe(res.pair_id) ~= M.pair_id(pair_or_id) then stat("release_denied"); return false end
  bucket[key] = nil; stat("released"); return true
end

function M.cleanup_expired(category, budget)
  local r = M.root(); local cleaned = 0; local t = now()
  local cats
  if category then
    cats = { tostring(category) }
  else
    -- 0.1.620: cleanup is rotated by reservation category so the maintenance
    -- service does not repeatedly sweep every reservation bucket in one pulse.
    -- This refines the existing reservation authority; it is not a new cleanup
    -- scheduler. The broker still owns cadence and budget.
    local idx = tonumber(r.cleanup_cursor_0620) or 1
    if idx < 1 or idx > #M.categories then idx = 1 end
    cats = { M.categories[idx] }
    r.cleanup_cursor_0620 = (idx % #M.categories) + 1
    stat("cleanup_rotated_categories")
  end
  for _, cat in ipairs(cats) do
    local bucket = r.reservations[cat] or {}
    for key, res in pairs(bucket) do
      if not res or (tonumber(res.expires_tick) or 0) <= t then
        bucket[key] = nil; cleaned = cleaned + 1; stat("expired_cleaned")
        if budget and cleaned >= budget then stat("cleanup_budget_exhausted"); return cleaned end
      end
    end
  end
  return cleaned
end

function M.count(category)
  local r = M.root(); local n = 0
  for _, _ in pairs(r.reservations[tostring(category or "")] or {}) do n = n + 1 end
  return n
end

function M.report_lines()
  M.cleanup_expired(nil, 200)
  local r = M.root(); local parts = {}
  for _, cat in ipairs(M.categories) do parts[#parts+1] = cat .. "=" .. safe(M.count(cat)) end
  return { "[tp-runtime-report] reservations " .. table.concat(parts, " ") .. " created=" .. safe(r.stats.claim_created or 0) .. " renewed=" .. safe(r.stats.claim_renewed or 0) .. " denied=" .. safe(r.stats.claim_denied or 0) .. " released=" .. safe(r.stats.released or 0) .. " expired=" .. safe(r.stats.expired_cleaned or 0) .. " cleanup_rotations=" .. safe(r.stats.cleanup_rotated_categories or 0) .. " cleanup_budget_exhausted=" .. safe(r.stats.cleanup_budget_exhausted or 0) }
end

function M.install()
  M.root()
  _G.TechPriestsWorkReservations0601 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "work_reservations_0601_cleanup",
      category = "runtime-cleanup",
      interval = 300,
      priority = 80,
      budget = 120,
      note = "expires stale shared work reservations",
      fn = function(event, budget)
        local n = M.cleanup_expired(nil, budget or 120)
        return n > 0, "expired=" .. safe(n)
      end
    })
  end
  return true
end

return M
