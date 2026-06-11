-- scripts/core/runtime_config_0626.lua
-- Tech Priests 0.1.626
-- Canonical runtime configuration snapshot for debug/profiler/log-spam settings.
-- This is not a scheduler, cache, sleep, queue, reservation, movement, or task
-- authority.  It is a small settings snapshot so high-frequency runtime paths do
-- not repeatedly consult scattered mod settings, and so debug/profiler behavior
-- has one governing switch.

local M = {}
M.version = "0.1.626"
M.storage_key = "runtime_config_0626"
M.debug_setting = "tech-priests-debug-mode"

local DEBUG_ALIASES = {
  ["tech-priests-enable-station-request-debug-icons"] = true,
  ["tech-priests-enable-logistics-debug-overlay"] = true,
  ["tech-priests-enable-full-priority-diagnostics"] = true,
  ["tech-priests-enable-emergency-diagnostics"] = true,
}

local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end

local function read_setting(name, fallback)
  local s = settings and settings.global and settings.global[name]
  if s and s.value ~= nil then return s.value end
  return fallback
end

local function read_bool(name, fallback)
  local v = read_setting(name, fallback)
  return v == true
end

local function read_string(name, fallback)
  local v = read_setting(name, fallback)
  v = tostring(v or "")
  if v == "" then return fallback end
  return v
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, snapshot = {}, stats = {}, compatibility_scans = {} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  r.snapshot = r.snapshot or {}
  r.stats = r.stats or {}
  r.compatibility_scans = r.compatibility_scans or {}
  return r
end

local function legacy_debug_alias_active()
  for name in pairs(DEBUG_ALIASES) do
    if read_bool(name, false) then return true, name end
  end
  return false, nil
end

function M.refresh(reason)
  local r = M.root()
  local mode = read_string(M.debug_setting, "off")
  if mode ~= "off" and mode ~= "summary" and mode ~= "verbose" and mode ~= "profiler" and mode ~= "legacy" then
    mode = "off"
  end
  local legacy_active, legacy_source = legacy_debug_alias_active()
  local effective_mode = mode
  if mode == "legacy" then
    effective_mode = legacy_active and "summary" or "off"
  end
  r.snapshot = {
    tick = game and game.tick or 0,
    reason = tostring(reason or "refresh"),
    debug_mode = mode,
    effective_debug_mode = effective_mode,
    legacy_debug_alias_active = legacy_active,
    legacy_debug_alias_source = legacy_source,
    debug_enabled = effective_mode ~= "off",
    debug_summary = effective_mode == "summary" or effective_mode == "verbose" or effective_mode == "profiler",
    debug_verbose = effective_mode == "verbose" or effective_mode == "profiler",
    profiler_enabled = effective_mode == "profiler",
    task_auspex_enabled = effective_mode ~= "off",
    log_spam_enabled = effective_mode == "verbose" or effective_mode == "profiler",
  }
  r.stats.refreshes = (r.stats.refreshes or 0) + 1
  r.stats.last_refresh_tick = game and game.tick or 0
  r.stats.last_refresh_reason = tostring(reason or "refresh")
  _G.tech_priests_runtime_config_snapshot_0626 = r.snapshot
  return r.snapshot
end

function M.snapshot()
  local r = M.root()
  if not r.snapshot or not r.snapshot.effective_debug_mode then return M.refresh("lazy") end
  return r.snapshot
end

function M.debug_mode()
  return M.snapshot().effective_debug_mode or "off"
end

function M.is_debug_enabled(level)
  local s = M.snapshot()
  level = tostring(level or "summary")
  if level == "profiler" then return s.profiler_enabled == true end
  if level == "verbose" then return s.debug_verbose == true end
  return s.debug_enabled == true
end

function M.setting_bool(name, fallback)
  if DEBUG_ALIASES[name] and not M.is_debug_enabled("summary") then return false end
  return read_bool(name, fallback)
end

function M.setting_string(name, fallback)
  if name == M.debug_setting then return read_string(name, fallback or "off") end
  return read_string(name, fallback)
end

function M.note_compatibility_scan(name, kind, count)
  local r = M.root()
  local key = tostring(kind or "runtime") .. ":" .. tostring(name or "unknown")
  local rec = r.compatibility_scans[key] or { name = tostring(name or "unknown"), kind = tostring(kind or "runtime"), count = 0, last_tick = 0 }
  rec.count = (rec.count or 0) + (tonumber(count or 1) or 1)
  rec.last_tick = game and game.tick or 0
  r.compatibility_scans[key] = rec
  r.stats.compatibility_scans = (r.stats.compatibility_scans or 0) + 1
  if _G and _G.tech_priests_runtime_metric_0606 then pcall(_G.tech_priests_runtime_metric_0606, "compat_scan_" .. tostring(kind or "runtime"), 1) end
  return rec
end

function M.report_lines(limit)
  local r = M.root()
  local s = M.snapshot()
  local lines = {}
  lines[#lines + 1] = "[tp-runtime-report] runtime-config-0626 debug_mode=" .. safe(s.debug_mode) .. " effective=" .. safe(s.effective_debug_mode) .. " profiler=" .. safe(s.profiler_enabled) .. " task_auspex=" .. safe(s.task_auspex_enabled) .. " legacy_alias=" .. safe(s.legacy_debug_alias_active and s.legacy_debug_alias_source or "none") .. " refreshes=" .. safe((r.stats or {}).refreshes or 0)
  local scans = {}
  for _, rec in pairs(r.compatibility_scans or {}) do scans[#scans + 1] = rec end
  table.sort(scans, function(a,b) return (tonumber(a.last_tick or 0) or 0) > (tonumber(b.last_tick or 0) or 0) end)
  if #scans == 0 then
    lines[#lines + 1] = "  compatibility-scan-audit: no scans recorded yet"
  else
    for i = 1, math.min(#scans, tonumber(limit or 6) or 6) do
      local rec = scans[i]
      lines[#lines + 1] = "  compat-scan[" .. safe(i) .. "] " .. safe(rec.kind) .. ":" .. safe(rec.name) .. " count=" .. safe(rec.count or 0) .. " last_tick=" .. safe(rec.last_tick or 0)
    end
  end
  return lines
end

local function on_setting_changed(event)
  local setting = event and event.setting or ""
  if setting == M.debug_setting or DEBUG_ALIASES[setting] then
    local s = M.refresh("setting:" .. tostring(setting))
    local okB, Broker = pcall(require, "scripts.core.runtime_tick_broker")
    if okB and Broker and Broker.set_profiler_enabled then pcall(Broker.set_profiler_enabled, s.profiler_enabled == true) end
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and R.set_profiler_enabled then pcall(R.set_profiler_enabled, s.profiler_enabled == true) end
  end
end

function M.install()
  M.refresh("install")
  _G.TechPriestsRuntimeConfig0626 = M
  _G.tech_priests_runtime_config_refresh_0626 = function(reason) return M.refresh(reason) end
  _G.tech_priests_runtime_debug_enabled_0626 = function(level) return M.is_debug_enabled(level) end
  _G.tech_priests_runtime_setting_bool_0626 = function(name, fallback) return M.setting_bool(name, fallback) end
  _G.tech_priests_compatibility_scan_0626 = function(name, kind, count) return M.note_compatibility_scan(name, kind, count) end
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and R.on_event and defines and defines.events and defines.events.on_runtime_mod_setting_changed then
    R.on_event(defines.events.on_runtime_mod_setting_changed, on_setting_changed, nil, { owner = "runtime_config_0626", category = "settings", note = "canonical runtime config snapshot refresh" })
  elseif script and script.on_event and defines and defines.events and defines.events.on_runtime_mod_setting_changed then
    script.on_event(defines.events.on_runtime_mod_setting_changed, on_setting_changed)
  end
  return true
end

return M
