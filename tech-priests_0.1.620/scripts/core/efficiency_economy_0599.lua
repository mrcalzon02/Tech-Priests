-- Tech Priests 0.1.599: adaptive priest sleep states.
--
-- This is a governor around the legacy tick_pair chain, not a new behavior
-- controller. Calm, fully idle priests progressively sleep for longer windows;
-- visible/active priests, combat, logistics, construction, damage wakeups, and
-- explicit movement/work state still run immediately.

local M = { version = "0.1.608", storage_key = "efficiency_economy_0599" }

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if not r then
    r = { version = M.version, enabled = true, stats = {}, dirty_cells = {}, pair_state = {} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  r.stats = r.stats or {}
  r.dirty_cells = r.dirty_cells or {}
  r.pair_state = r.pair_state or {}
  if r.enabled == nil then r.enabled = true end
  return r
end

local function inc(k, n)
  local r = root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

local function valid(e) return e and e.valid end

local function pair_key(pair)
  if not pair then return nil end
  if valid(pair.station) and pair.station.unit_number then return pair.station.unit_number end
  if valid(pair.priest) and pair.priest.unit_number then return pair.priest.unit_number end
  return nil
end

local function safe_mode(pair)
  return tostring((pair and (pair.mode or pair.state or pair.activity_mode)) or "")
end

local active_modes = {
  ["independent-emergency-operation"] = true,
  ["emergency-gathering"] = true,
  ["returning"] = true,
  ["combat"] = true,
  ["attacking"] = true,
  ["retreating"] = true,
  ["repairing"] = true,
  ["consecrating"] = true,
  ["crafting"] = true,
  ["constructing"] = true,
  ["mining"] = true,
  ["scavenging"] = true,
}

local function pair_has_work(pair)
  if not pair then return false end
  if active_modes[safe_mode(pair)] then return true end
  if pair.task or pair.current_task or pair.active_task then return true end
  if pair.movement_mode or pair.move_target or pair.destination then return true end
  if pair.combat_target or pair.hostile or pair.paused_by_combat then return true end
  if pair.emergency or pair.emergency_state or pair.emergency_operation then return true end
  if pair.construction or pair.craft or pair.scavenge or pair.repair_target or pair.consecration_target then return true end
  if pair.order or pair.current_order or pair.active_order or pair.writ then return true end
  return false
end

local function cell_for(ent)
  if not valid(ent) then return nil end
  local p = ent.position
  local surface = ent.surface and ent.surface.index or 0
  local force = ent.force and ent.force.index or 0
  local cx = math.floor((p.x or 0) / 32)
  local cy = math.floor((p.y or 0) / 32)
  return surface .. ":" .. force .. ":" .. cx .. ":" .. cy
end

local function mark_dirty_near(ent)
  local r = root()
  local key = cell_for(ent)
  if key then r.dirty_cells[key] = (game and game.tick or 0) + 900 end
end

local function pair_dirty(pair)
  local r = root()
  local tick = game and game.tick or 0
  local key = cell_for(pair and (pair.station or pair.priest))
  if not key then return false end
  local until_tick = r.dirty_cells[key]
  if until_tick and until_tick >= tick then return true end
  if until_tick and until_tick < tick then r.dirty_cells[key] = nil end
  return false
end

local function observed(pair)
  local priest = pair and pair.priest
  local station = pair and pair.station
  local ent = valid(priest) and priest or station
  if not valid(ent) or not game then return false end
  local surf = ent.surface
  local pos = ent.position
  for _, player in pairs(game.connected_players or {}) do
    if player and player.valid and player.character and player.character.valid and player.character.surface == surf then
      local pp = player.character.position
      local dx, dy = (pp.x or 0) - (pos.x or 0), (pp.y or 0) - (pos.y or 0)
      if (dx * dx + dy * dy) <= (80 * 80) then return true end
    end
    if player and player.valid and player.opened == station then return true end
    if player and player.valid and player.selected and (player.selected == station or player.selected == priest) then return true end
  end
  return false
end

local function sleep_window(state)
  local level = state.sleep_level or 0
  if level <= 0 then return 0 end
  if level == 1 then return 60 end
  if level == 2 then return 180 end
  if level == 3 then return 360 end
  if level == 4 then return 720 end
  return 1200
end

local function should_skip(pair)
  local r = root()
  if not r.enabled then return false end
  if not pair or pair_has_work(pair) or observed(pair) or pair_dirty(pair) then
    local k = pair_key(pair)
    if k then r.pair_state[k] = { sleep_level = 0, next_tick = 0 } end
    return false
  end
  local k = pair_key(pair)
  if not k then return false end
  local tick = game and game.tick or 0
  local state = r.pair_state[k] or { sleep_level = 0, next_tick = 0 }
  r.pair_state[k] = state
  if state.next_tick and state.next_tick > tick then
    inc("skipped_idle_tick_pair")
    return true
  end
  state.sleep_level = math.min((state.sleep_level or 0) + 1, 5)
  state.next_tick = tick + sleep_window(state)
  inc("allowed_idle_probe")
  return false
end

local function wrap_tick_pair()
  if type(_G.tick_pair) ~= "function" then return end
  if _G.TECH_PRIESTS_TICK_PAIR_BEFORE_0599 then return end
  _G.TECH_PRIESTS_TICK_PAIR_BEFORE_0599 = _G.tick_pair
  _G.tick_pair = function(pair, ...)
    if should_skip(pair) then return nil end
    return _G.TECH_PRIESTS_TICK_PAIR_BEFORE_0599(pair, ...)
  end
end


function M.wake_pair(pair, reason)
  local r = root()
  local k = pair_key(pair)
  if not k then return false, "no-key" end
  r.pair_state[k] = { sleep_level = 0, next_tick = 0, wake_reason = tostring(reason or "directed-wake"), wake_tick = game and game.tick or 0 }
  if valid(pair and pair.station) then mark_dirty_near(pair.station) end
  inc("directed_wake_pair")
  return true, "woken"
end

local function wake_all()
  local r = root()
  r.pair_state = {}
  inc("global_wake")
end

local function on_entity_event(event)
  local ent = event and (event.entity or event.created_entity or event.destination)
  if valid(ent) then mark_dirty_near(ent) end
end

function M.install()
  root()
  _G.TechPriestsEfficiencyEconomy0599 = M
  _G.tech_priests_efficiency_0599_wake_pair = function(pair, reason) return M.wake_pair(pair, reason) end
  wrap_tick_pair()
  if script and script.on_event and defines and defines.events then
    local ev = defines.events
    local events = {
      ev.on_built_entity,
      ev.on_robot_built_entity,
      ev.script_raised_built,
      ev.script_raised_revive,
      ev.on_player_mined_entity,
      ev.on_robot_mined_entity,
      ev.on_entity_died,
      ev.script_raised_destroy,
      ev.on_entity_damaged,
      ev.on_research_finished,
    }
    for _, e in pairs(events) do
      if e then pcall(script.on_event, e, function(event)
        if event and event.research then wake_all() else on_entity_event(event) end
      end) end
    end
  end
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0599") end end)
    commands.add_command("tp-efficiency-economy-0599", "Report/toggle Tech Priests adaptive priest sleep states. Params: on/off/status", function(cmd)
      local r = root()
      local p = cmd and cmd.parameter or ""
      if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false end
      local lines = { "[tp-efficiency-economy-0599] enabled=" .. tostring(r.enabled) }
      local keys = {}
      for k in pairs(r.stats or {}) do keys[#keys+1] = k end
      table.sort(keys)
      for i=1, math.min(#keys, 20) do lines[#lines+1] = "  " .. keys[i] .. "=" .. tostring(r.stats[keys[i]]) end
      local player = cmd and cmd.player_index and game and game.get_player(cmd.player_index) or nil
      local msg = table.concat(lines, "\n")
      if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
    end)
  end
end

return M
