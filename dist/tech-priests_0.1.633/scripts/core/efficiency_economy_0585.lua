-- scripts/core/efficiency_economy_0585.lua
-- Tech Priests 0.1.585
--
-- Event/dirty-mark coalescing economy pass. This is not a behavior controller.
-- It wraps the existing 0.1.579 catalog dirty markers and 0.1.580
-- consecration dirty markers so bursts of build/damage/remove events do not
-- repeatedly invalidate the same entity/cell/machine in the same few ticks.
-- Dirty work is buffered, de-duplicated, and flushed under a small budget.

local M = {}
M.version = "0.1.585"
M.storage_key = "efficiency_economy_0585"
M.flush_interval = 5
M.default_flush_budget = 96
M.max_pending = 4096
M.recent_keep = 40

local originals = { installed = false }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or {x=0,y=0}
  local s = entity.surface and (entity.surface.index or entity.surface.name) or "surface"
  return tostring(s)..":"..tostring(entity.name or entity.type or "?")..":"..tostring(math.floor((p.x or 0)*10))..":"..tostring(math.floor((p.y or 0)*10))
end

local function record_key(record)
  if type(record) ~= "table" then return nil end
  local e = record.entity
  if valid(e) then return entity_key(e) end
  local unit = record.unit_number or record.entity_unit_number or record.unit or record.id
  if unit then return "r:"..tostring(unit) end
  return nil
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      flush_budget = M.default_flush_budget,
      pending = {},
      order = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.flush_budget = tonumber(r.flush_budget) or M.default_flush_budget
  r.pending = r.pending or {}
  r.order = r.order or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > M.recent_keep do table.remove(r.recent,1) end
end

local function enqueue(kind, key, payload)
  local r=M.root()
  if r.enabled == false then return false end
  if not key then return false end
  local k = tostring(kind)..":"..tostring(key)
  local old = r.pending[k]
  if old then
    old.tick = now()
    old.reason = tostring(payload and payload.reason or old.reason or "coalesced")
    old.count = (tonumber(old.count or 1) or 1) + 1
    stat("coalesced_"..tostring(kind))
    return true
  end
  if #r.order >= M.max_pending then
    stat("pending_overflow_"..tostring(kind))
    return false
  end
  r.pending[k] = payload or {}
  r.pending[k].kind = kind
  r.pending[k].key = key
  r.pending[k].tick = now()
  r.pending[k].count = 1
  r.order[#r.order+1] = k
  stat("queued_"..tostring(kind))
  return true
end

local function unwrap_entity(payload)
  local e = payload and payload.entity
  if valid(e) then return e end
  return nil
end

local function flush_one(k)
  local r=M.root()
  local payload = r.pending[k]
  r.pending[k] = nil
  if type(payload) ~= "table" then return false end
  local kind = payload.kind
  local reason = payload.reason or "coalesced-0585"
  local ok, err = true, nil
  if kind == "dirty0579" and originals.mark0579 then
    local e = unwrap_entity(payload)
    if valid(e) then ok, err = pcall(originals.mark0579, e, reason) else stat("skip_invalid_dirty0579") end
  elseif kind == "dirty0580" and originals.mark0580 then
    local e = unwrap_entity(payload)
    if valid(e) then ok, err = pcall(originals.mark0580, e, reason) else stat("skip_invalid_dirty0580") end
  elseif kind == "record0580" and originals.record0580 then
    local rec = payload.record
    if type(rec) == "table" then ok, err = pcall(originals.record0580, rec, reason) else stat("skip_invalid_record0580") end
  else
    stat("skip_unknown_kind")
    return false
  end
  if ok then
    stat("flushed_"..tostring(kind))
    return true
  end
  stat("flush_error_"..tostring(kind))
  remember("flush-error", tostring(kind).." "..safe(err))
  return false
end

function M.flush(max_budget)
  local r=M.root()
  if r.enabled == false then return 0 end
  local budget = math.max(1, math.min(1000, tonumber(max_budget or r.flush_budget) or M.default_flush_budget))
  local spent = 0
  local kept = {}
  for _, k in ipairs(r.order or {}) do
    if spent >= budget then
      kept[#kept+1] = k
    else
      if r.pending[k] ~= nil then
        flush_one(k)
        spent = spent + 1
      end
    end
  end
  r.order = kept
  r.last_flush_tick = now()
  r.last_flush_spent = spent
  if spent > 0 then stat("flush_runs") end
  return spent
end

local function install_wrappers()
  if originals.installed then return true end
  local E0579 = rawget(_G, "TechPriestsEfficiencyEconomy0579")
  local E0580 = rawget(_G, "TechPriestsEfficiencyEconomy0580")
  if type(E0579) == "table" and type(E0579.mark_entity_dirty) == "function" then
    originals.mark0579 = E0579.mark_entity_dirty
    E0579.mark_entity_dirty = function(entity, reason)
      local r=M.root()
      if r.enabled == false then return originals.mark0579(entity, reason) end
      local key = entity_key(entity)
      if not key then return false end
      return enqueue("dirty0579", key, { entity=entity, reason=reason or "dirty0579-0585" })
    end
    stat("wrapped_dirty0579")
  end
  if type(E0580) == "table" and type(E0580.mark_entity_dirty) == "function" then
    originals.mark0580 = E0580.mark_entity_dirty
    E0580.mark_entity_dirty = function(entity, reason)
      local r=M.root()
      if r.enabled == false then return originals.mark0580(entity, reason) end
      local key = entity_key(entity)
      if not key then return false end
      return enqueue("dirty0580", key, { entity=entity, reason=reason or "dirty0580-0585" })
    end
    stat("wrapped_dirty0580")
  end
  if type(E0580) == "table" and type(E0580.mark_record_dirty) == "function" then
    originals.record0580 = E0580.mark_record_dirty
    E0580.mark_record_dirty = function(record, reason)
      local r=M.root()
      if r.enabled == false then return originals.record0580(record, reason) end
      local key = record_key(record)
      if not key then return false end
      return enqueue("record0580", key, { record=record, reason=reason or "record0580-0585" })
    end
    stat("wrapped_record0580")
  end
  originals.installed = true
  remember("install", "dirty/event coalescing wrappers installed")
  return true
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0585") end end)
  commands.add_command("tp-efficiency-economy-0585", "Tech Priests 0.1.585 dirty/event coalescing economy. Params: on/off/status/flush/budget N", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = tostring(event and event.parameter or "status")
    local p = lower(param)
    local r=M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "flush" then M.flush(1000) end
    local n = tonumber(param:match("budget%s+(%d+)"))
    if n then r.flush_budget = math.max(1, math.min(1000, n)) end
    local pending = 0; for _ in pairs(r.pending or {}) do pending = pending + 1 end
    local msg = "[tp-efficiency-economy-0585] enabled="..safe(r.enabled).." budget="..safe(r.flush_budget).." pending="..safe(pending).." order="..safe(#(r.order or {})).." last_spent="..safe(r.last_flush_spent or 0).." coalesced="..safe((r.stats.coalesced_dirty0579 or 0)+(r.stats.coalesced_dirty0580 or 0)+(r.stats.coalesced_record0580 or 0)).." flushed="..safe((r.stats.flushed_dirty0579 or 0)+(r.stats.flushed_dirty0580 or 0)+(r.stats.flushed_record0580 or 0))
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  install_wrappers()
  install_command()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.flush_interval, function() M.flush() end, { owner="efficiency_economy_0585", category="economy", priority="last", note="coalesce repeated dirty/event marks" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.flush_interval, function() M.flush() end)
  end
  _G.TechPriestsEfficiencyEconomy0585 = M
  if log then log("[Tech-Priests 0.1.585] dirty/event coalescing economy installed") end
  return true
end

return M
