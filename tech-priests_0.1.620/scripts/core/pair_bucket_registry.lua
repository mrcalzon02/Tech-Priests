-- scripts/core/pair_bucket_registry.lua
-- Tech Priests 0.1.600
-- Pair bucket registry: broad pair scans are rebuilt into small work buckets.

local M = {}
M.version = "0.1.608"
M.storage_key = "pair_bucket_registry_0600"
M.bucket_names = { "active", "idle", "invalid", "repair", "logistics", "combat", "movement", "visible", "dirty", "sleeping" }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_id(pair, fallback)
  local id = station_unit(pair)
  if id then return tostring(id) end
  return tostring(fallback or "nil")
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, buckets = {}, stats = {}, pair_refs = {}, dirty_reasons = {}, forced_buckets = {} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  r.buckets = r.buckets or {}
  r.stats = r.stats or {}
  r.pair_refs = r.pair_refs or {}
  r.dirty_reasons = r.dirty_reasons or {}
  r.forced_buckets = r.forced_buckets or {}
  for _, name in ipairs(M.bucket_names) do r.buckets[name] = r.buckets[name] or {} end
  return r
end

local function count_table(t) local n=0; if type(t)=="table" then for _ in pairs(t) do n=n+1 end end; return n end

local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

function M.valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function get_order(pair)
  local q = pair and pair.order_queue_0469
  return pair and ((q and q.current) or pair.active_order_0469 or pair.active_task or pair.active_task_0285) or nil
end

local function forced_bucket_active(pair, bucket)
  if not pair then return false end
  local until_tick = tonumber(pair["_tp_force_bucket_until_" .. tostring(bucket or "?") .. "_0608"] or 0) or 0
  return until_tick > now()
end

local function is_repair(pair)
  local s = pair and pair.repair_0516
  if s and s.phase and s.phase ~= "none" and s.phase ~= "complete" and s.phase ~= "no-target" then return true end
  if forced_bucket_active(pair, "repair") or (tonumber(pair and pair._tp_repair_wake_until_0608 or 0) or 0) > now() then return true end
  local mode = lower(pair and pair.mode)
  if mode:find("repair", 1, true) then return true end
  local o = get_order(pair)
  local k = lower(o and (o.kind or o.type or o.key or o.source))
  if k:find("repair", 1, true) ~= nil then return true end
  -- Legacy safety fallback: if a shared repair queue exists, broad bucket
  -- eligibility remains available until all repair discovery is directed.
  -- Event-driven 0.1.608 wake hints above are the preferred fast path.
  local okQ, Q = pcall(require, "scripts.core.work_queue_authority")
  if okQ and Q and Q.count and (Q.count("repair") or 0) > 0 then return true end
  return false
end

local function is_logistics(pair)
  local mode = lower(pair and pair.mode)
  if mode:find("logistic", 1, true) or mode:find("supply", 1, true) or mode:find("acqui", 1, true) or mode:find("scavenge", 1, true) then return true end
  local o = get_order(pair)
  local k = lower(o and (o.kind or o.type or o.key or o.source))
  return k:find("logistic", 1, true) or k:find("acqui", 1, true) or k:find("scavenge", 1, true)
end

local function is_combat(pair)
  local mode = lower(pair and pair.mode)
  return mode:find("combat", 1, true) or mode:find("attack", 1, true)
end

local function is_movement(pair)
  local mode = lower(pair and pair.mode)
  return mode:find("moving", 1, true) or mode:find("walk", 1, true)
end

local function bucket_add(r, bucket, id)
  if not (r.buckets and r.buckets[bucket]) then return end
  if r.buckets[bucket][id] then return end
  r.buckets[bucket][id] = true
end

function M.rebuild(reason)
  local r = M.root()
  for _, name in ipairs(M.bucket_names) do r.buckets[name] = {} end
  r.pair_refs = {}
  local total, valid_count, invalid_count = 0, 0, 0
  for key, pair in pairs(pair_map()) do
    total = total + 1
    local id = pair_id(pair, key)
    r.pair_refs[id] = pair
    if not M.valid_pair(pair) then
      invalid_count = invalid_count + 1
      bucket_add(r, "invalid", id)
    else
      valid_count = valid_count + 1
      if pair._tp_bucket_dirty_0600 then bucket_add(r, "dirty", id) end
      if is_repair(pair) then bucket_add(r, "repair", id); bucket_add(r, "active", id)
      elseif is_logistics(pair) then bucket_add(r, "logistics", id); bucket_add(r, "active", id)
      elseif is_combat(pair) then bucket_add(r, "combat", id); bucket_add(r, "active", id)
      elseif is_movement(pair) then bucket_add(r, "movement", id); bucket_add(r, "active", id)
      else bucket_add(r, "idle", id) end
      for fb_key, rec in pairs(r.forced_buckets or {}) do
        if fb_key == (id .. ":" .. tostring(rec.bucket or "")) then
          if (tonumber(rec.until_tick or 0) or 0) > now() and r.buckets[rec.bucket] then
            bucket_add(r, rec.bucket, id); bucket_add(r, "active", id)
          else
            r.forced_buckets[fb_key] = nil
          end
        end
      end
    end
  end
  r.last_rebuild_tick = now()
  r.last_rebuild_reason = tostring(reason or "manual")
  r.last_total = total
  r.last_valid = valid_count
  r.last_invalid = invalid_count
  stat("rebuilds")
  return r
end


function M.force_bucket(pair_or_id, bucket, ttl, reason)
  local r = M.root()
  local id = type(pair_or_id) == "table" and pair_id(pair_or_id) or tostring(pair_or_id or "nil")
  bucket = tostring(bucket or "")
  if not r.buckets[bucket] then return false, "unknown-bucket" end
  local until_tick = now() + (tonumber(ttl) or 600)
  r.forced_buckets[id .. ":" .. bucket] = { bucket = bucket, until_tick = until_tick, reason = tostring(reason or "forced") }
  if type(pair_or_id) == "table" then
    pair_or_id["_tp_force_bucket_until_" .. bucket .. "_0608"] = until_tick
  end
  r.buckets[bucket][id] = true
  stat("forced_" .. bucket)
  return true, "forced"
end

function M.mark_dirty(pair_or_id, reason)
  local r = M.root()
  local id = type(pair_or_id) == "table" and pair_id(pair_or_id) or tostring(pair_or_id or "nil")
  if type(pair_or_id) == "table" then pair_or_id._tp_bucket_dirty_0600 = true end
  r.dirty_reasons[id] = tostring(reason or "dirty")
  if r.buckets.dirty then r.buckets.dirty[id] = true end
  stat("dirty_marks")
end

function M.clear_dirty(pair_or_id)
  local r = M.root()
  local id = type(pair_or_id) == "table" and pair_id(pair_or_id) or tostring(pair_or_id or "nil")
  if type(pair_or_id) == "table" then pair_or_id._tp_bucket_dirty_0600 = nil end
  if r.buckets.dirty then r.buckets.dirty[id] = nil end
  r.dirty_reasons[id] = nil
end

function M.each(bucket, limit, fn)
  local r = M.root()
  if not r.last_rebuild_tick or now() - (tonumber(r.last_rebuild_tick) or 0) > 120 then M.rebuild("stale-auto") end
  local b = r.buckets[bucket] or {}
  local count, acted = 0, 0
  for id in pairs(b) do
    local pair = r.pair_refs[id] or pair_map()[tonumber(id)] or pair_map()[id]
    if pair and M.valid_pair(pair) then
      count = count + 1
      local ok, res = pcall(fn, pair, id)
      if ok and res ~= false then acted = acted + 1 end
      if limit and count >= limit then break end
    end
  end
  return acted, count
end

function M.count(bucket)
  local r = M.root()
  local n = 0
  for _ in pairs(r.buckets[bucket] or {}) do n = n + 1 end
  return n
end

function M.report_lines()
  local r = M.rebuild("report")
  local lines = {}
  lines[#lines + 1] = "[tp-runtime-report] pair-buckets total=" .. safe(r.last_total or 0) .. " valid=" .. safe(r.last_valid or 0) .. " invalid=" .. safe(r.last_invalid or 0) .. " rebuilds=" .. safe(r.stats.rebuilds or 0) .. " forced=" .. safe(count_table and count_table(r.forced_buckets) or 0)
  local parts = {}
  for _, name in ipairs(M.bucket_names) do parts[#parts + 1] = name .. "=" .. safe(M.count(name)) end
  lines[#lines + 1] = "  buckets " .. table.concat(parts, " ")
  return lines
end

function M.install()
  M.root()
  _G.TechPriestsPairBucketRegistry0600 = M
  return true
end

return M
