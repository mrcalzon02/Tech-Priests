-- scripts/core/efficiency_economy_0595.lua
-- Tech Priests 0.1.595
--
-- Dormant runtime gate. If no Tech-Priest pair/station/system has actually
-- entered the world, passive nth-tick services should not wake the full legacy
-- runtime lattice. Build/research/player events still run and can wake the
-- runtime immediately. This is an economy gate only; it does not create work.

local M = {}
M.version = "0.1.595"
M.storage_key = "efficiency_economy_0595"

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    dormant_enabled = true,
    active = false,
    reason = "startup",
    last_probe = 0,
    next_probe = 0,
    stats = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.dormant_enabled == nil then r.dormant_enabled = true end
  r.stats = r.stats or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function looks_like_tp_name(name)
  name = tostring(name or "")
  return name:find("tech%-priests", 1, false)
    or name:find("cogitator", 1, false)
    or name:find("tech%-priest", 1, false)
    or name:find("conclave", 1, false)
    or name:find("martian%-micro", 1, false)
    or name:find("machine%-spirit", 1, false)
end

local function has_valid_pairs()
  local tp = storage and storage.tech_priests
  local pairs_by_station = tp and tp.pairs_by_station
  if type(pairs_by_station) ~= "table" then return false end
  for _, pair in pairs(pairs_by_station) do
    if pair and (valid(pair.station) or valid(pair.priest)) then return true end
  end
  return false
end

local function has_known_runtime_entities()
  local tp = storage and storage.tech_priests
  if type(tp) ~= "table" then return false end

  -- Cheap known root checks first. These are intentionally broad enough to
  -- catch existing saves without doing a surface scan every pulse.
  for _, key in ipairs({
    "pairs_by_station",
    "pairs_by_priest",
    "consecration_targets",
    "machine_spirit_ledger",
    "conclave_centers",
    "stone_caches",
    "stations_by_unit",
    "priests_by_unit",
  }) do
    local t = tp[key]
    if type(t) == "table" then
      for _, v in pairs(t) do
        if valid(v) then return true end
        if type(v) == "table" and (valid(v.entity) or valid(v.station) or valid(v.priest)) then return true end
      end
    end
  end

  return false
end

function M.awaken(reason)
  local r = root()
  r.active = true
  r.reason = tostring(reason or "runtime-entity")
  r.next_probe = now() + 60 * 30
  stat("awaken")
  return true
end

function M.sleep(reason)
  local r = root()
  r.active = false
  r.reason = tostring(reason or "no-runtime-entities")
  r.next_probe = now() + 60 * 10
  stat("sleep")
  return false
end

function M.runtime_active(reason)
  local r = root()
  if r.dormant_enabled == false then return true end
  if r.active and now() < (r.next_probe or 0) then return true end

  r.last_probe = now()
  if has_valid_pairs() or has_known_runtime_entities() then
    return M.awaken(reason or "storage-runtime-entities")
  end

  return M.sleep(reason or "dormant")
end

function M.should_run_nth_tick(tick, route, event)
  local r = root()
  if r.dormant_enabled == false then return true end
  if M.runtime_active("nth-tick-" .. tostring(tick or "?")) then return true end

  -- Let ultra-rare probes through so long-running dormant saves can self-heal
  -- if an older module failed to mark activity. This keeps the mod quiet while
  -- still avoiding a permanent sleep trap.
  local t = now()
  if (tonumber(tick) or 0) >= 3600 and (t % (tonumber(tick) or 3600) == 0) then
    stat("rare_probe_allowed")
    return true
  end

  stat("nth_tick_skipped")
  return false
end

local function entity_from_event(event)
  if not event then return nil end
  return event.created_entity or event.entity or event.destination or event.source
end

function M.mark_event(event, label)
  local ent = entity_from_event(event)
  if ent and valid(ent) and looks_like_tp_name(ent.name) then
    return M.awaken(label or "event-" .. tostring(ent.name))
  end
  return false
end

function M.register_events()
  if not (defines and defines.events) then return false end
  local ev = defines.events
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if not (registry and type(registry.on_event) == "function") then return false end

  local build_events = {
    ev.on_built_entity,
    ev.on_robot_built_entity,
    ev.script_raised_built,
    ev.script_raised_revive,
    ev.on_space_platform_built_entity,
  }
  local remove_events = {
    ev.on_player_mined_entity,
    ev.on_robot_mined_entity,
    ev.on_entity_died,
    ev.script_raised_destroy,
    ev.on_space_platform_mined_entity,
  }
  local accepted = {}

  local function unregister_all()
    for i = #accepted, 1, -1 do
      local rec = accepted[i]
      pcall(registry.on_event, rec.id, nil, nil, rec.options)
    end
  end

  local function register_event(id, handler, route, note)
    if not id then return true end
    local options = {
      owner = "efficiency_economy_0595",
      route = route,
      category = "dormant-wake",
      note = note or "",
    }
    local ok, entry = pcall(registry.on_event, id, handler, nil, options)
    if not ok or not entry then return false end
    accepted[#accepted + 1] = { id = id, options = options }
    return true
  end

  local function on_any_build(event) M.mark_event(event, "entity-built") end
  local function on_any_remove(event)
    M.mark_event(event, "entity-removed")
    root().next_probe = math.min(root().next_probe or 0, now() + 60)
  end

  for _, id in ipairs(build_events) do
    if not register_event(id, on_any_build, "wake-build", "wake on Tech-Priest entity build") then
      unregister_all()
      return false
    end
  end
  for _, id in ipairs(remove_events) do
    if not register_event(id, on_any_remove, "wake-remove", "probe after Tech-Priest entity removal") then
      unregister_all()
      return false
    end
  end

  if not register_event(ev.on_research_finished, function(event)
    local tech = event and event.research
    if tech and looks_like_tp_name(tech.name) then
      root().reason = "research-unlocked-" .. tostring(tech.name)
      root().next_probe = math.min(root().next_probe or 0, now() + 60)
      stat("research_seen")
    end
  end, "wake-research", "observe Tech-Priest research unlock") then
    unregister_all()
    return false
  end

  return true, unregister_all
end

function M.commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-runtime-dormant-0595") end)
  commands.add_command("tp-runtime-dormant-0595", "Report Tech Priests dormant runtime gate state.", function(cmd)
    local r = root()
    local player = cmd and cmd.player_index and game and game.get_player(cmd.player_index) or nil
    local line = "[Tech-Priests 0.1.595] dormant=" .. tostring(not r.active)
      .. " enabled=" .. tostring(r.dormant_enabled)
      .. " reason=" .. tostring(r.reason)
      .. " skipped=" .. tostring((r.stats and r.stats.nth_tick_skipped) or 0)
      .. " awaken=" .. tostring((r.stats and r.stats.awaken) or 0)
    if player then player.print(line) elseif log then log(line) end
  end)
end

function M.install()
  local routes_ok, rollback = M.register_events()
  if routes_ok ~= true then return false end
  local ok, err = pcall(function()
    _G.tech_priests_runtime_active_0595 = M.runtime_active
    _G.tech_priests_should_run_nth_tick_0595 = M.should_run_nth_tick
    M.commands()
  end)
  if not ok then
    if rollback then rollback() end
    if log then log("[Tech-Priests 0.1.595] dormant runtime gate install rolled back: "..tostring(err)) end
    return false
  end
  if log then log("[Tech-Priests 0.1.595] dormant runtime gate installed with registry-owned build/remove/research wake routes") end
  return true
end

return M
