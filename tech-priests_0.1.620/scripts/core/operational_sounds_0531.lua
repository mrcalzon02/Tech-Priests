-- scripts/core/operational_sounds_0531.lua
-- Tech Priests 0.1.531
--
-- Operational/mechanical sound reporter. This module imports the uploaded
-- machine/UI/respirator sounds into a single audio-only layer. It does not
-- create work, alter orders, move priests, complete tasks, or claim action
-- families. It routes through sound_manager_0475 when possible and falls back
-- to surface.play_sound for prototype sounds.

local M = {}
M.version = "0.1.531"
M.storage_key = "operational_sounds_0531"
M.breath_interval = 60 * 13
M.breath_min_cooldown = 60 * 40
M.gui_click_cooldown = 7
M.gui_specific_cooldown = 5

local CUSTOM_MACHINE_NAMES = {
  ["tech-priests-emergency-miner"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-atmospheric-water-condenser"] = true,
  ["tech-priests-emergency-steam-engine"] = true,
  ["tech-priests-emergency-smelter"] = true,
  ["tech-priests-emergency-assembler"] = true,
  ["tech-priests-emergency-laboratorium"] = true,
  ["tech-priests-emergency-power-grid"] = true,
  ["tech-priests-orbital-trader"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    breath_enabled = true,
    gui_click_enabled = true,
    machine_event_enabled = true,
    stats = {},
    recent = {},
    next_by_key = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.breath_enabled == nil then r.breath_enabled = true end
  if r.gui_click_enabled == nil then r.gui_click_enabled = true end
  if r.machine_event_enabled == nil then r.machine_event_enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.next_by_key = r.next_by_key or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(event, detail)
  local r = root()
  r.recent[#r.recent + 1] = { tick = now(), event = tostring(event or "event"), detail = tostring(detail or "") }
  while #r.recent > 32 do table.remove(r.recent, 1) end
end

local function cooldown_allows(key, ticks)
  local r = root()
  local t = now()
  local next_tick = tonumber(r.next_by_key[key] or 0) or 0
  if t < next_tick then return false, next_tick - t end
  r.next_by_key[key] = t + (tonumber(ticks) or 1)
  return true, 0
end

local function hash_number(a, b)
  local text = tostring(a or "") .. ":" .. tostring(b or "")
  local h = 5381
  for i = 1, #text do h = (h * 33 + string.byte(text, i)) % 2147483647 end
  return h
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function pair_for_entity(entity)
  if not valid(entity) then return nil end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.station == entity or pair.priest == entity) then return pair end
  end
  return nil
end

local function emit(pair, event, opts)
  opts = opts or {}
  if _G.tech_priests_sound_event_0475 then
    local ok, a, b = pcall(_G.tech_priests_sound_event_0475, pair, event, opts)
    if ok then return a, b end
  end
  local surface = opts.surface or (opts.source_entity and valid(opts.source_entity) and opts.source_entity.surface) or (pair and valid(pair.station) and pair.station.surface) or nil
  local position = opts.position or (opts.source_entity and valid(opts.source_entity) and opts.source_entity.position) or (pair and valid(pair.priest) and pair.priest.position) or nil
  local path = opts.path or (opts.candidates and opts.candidates[1]) or nil
  if surface and position and path and surface.play_sound then
    local ok = pcall(function() surface.play_sound({ path = path, position = position, volume_modifier = math.max(0, math.min(1, tonumber(opts.volume_multiplier or 0.35) or 0.35)) }) end)
    if ok then return true, path end
  end
  return false, "no-sound-target"
end

local function play_at_entity(entity, event, sound, volume, cooldown)
  if not valid(entity) then return false, "invalid-entity" end
  local key = tostring(event) .. ":" .. tostring(entity.unit_number or entity.name or "entity")
  local allowed = cooldown_allows(key, cooldown or 60)
  if not allowed then return false, "cooldown" end
  local pair = pair_for_entity(entity)
  local ok, used = emit(pair, event, {
    source = "station",
    source_entity = entity,
    position = entity.position,
    surface = entity.surface,
    candidates = { sound },
    path = sound,
    cooldown_key = key,
    cooldown_ticks = cooldown or 60,
    volume_multiplier = volume or 0.35,
  })
  if ok then stat(event); record(event, tostring(entity.name) .. " -> " .. tostring(used or sound)) end
  return ok, used
end

local function is_custom_machine(entity)
  return valid(entity) and CUSTOM_MACHINE_NAMES[entity.name] == true
end

function M.on_machine_built(event)
  local r = root()
  if not (r.enabled and r.machine_event_enabled) then return end
  local entity = event and (event.created_entity or event.entity or event.destination) or nil
  if is_custom_machine(entity) then
    play_at_entity(entity, "machine_start_0531", "tech-priests-machine-start-0531", 0.48, 60)
  end
end

function M.on_machine_removed(event)
  local r = root()
  if not (r.enabled and r.machine_event_enabled) then return end
  local entity = event and event.entity or nil
  if is_custom_machine(entity) then
    play_at_entity(entity, "machine_wind_down_0531", "tech-priests-machine-wind-down-0531", 0.42, 60)
  end
end

function M.on_gui_click(event)
  local r = root()
  if not (r.enabled and r.gui_click_enabled) then return end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local element = event.element
  local name = element and element.valid and tostring(element.name or "") or ""
  local lname = lower(name)
  if not (name:find("tech_priests", 1, true) or name:find("tp_", 1, true) or lname:find("tech%-priest") or lname:find("cogitator", 1, true)) then return end
  local event_name = "gui_click_0531"
  local sound = { "tech-priests-tp-gui-button-press-01", "tech-priests-tp-gui-button-press-02", "tech-priests-clicker-button-0531", "tech-priests-clak-0531" }
  local cd = M.gui_click_cooldown
  if lname:find("portrait", 1, true) then
    event_name = "gui_portrait_selected_0533"
    sound = { "tech-priests-tp-gui-portrait-select-01" }
    cd = M.gui_specific_cooldown
  elseif lname:find("tab", 1, true) or lname:find("pane", 1, true) or lname:find("page", 1, true) then
    event_name = "gui_tab_changed_0533"
    sound = { "tech-priests-tp-gui-tab-change-01" }
    cd = M.gui_specific_cooldown
  elseif lname:find("close", 1, true) then
    event_name = "gui_panel_close_0533"
    sound = { "tech-priests-tp-gui-panel-close-01" }
    cd = 10
  end
  local key = tostring(event_name) .. ":" .. tostring(player.index)
  local allowed = cooldown_allows(key, cd)
  if not allowed then return end
  local pair = nil
  local selected = player.selected
  if selected and selected.valid then pair = pair_for_entity(selected) end
  local ok = emit(pair, event_name, {
    source = "station",
    position = player.position,
    surface = player.surface,
    candidates = sound,
    cooldown_key = key,
    cooldown_ticks = cd,
    volume_multiplier = 0.20,
  })
  if ok then stat(event_name) end
end

function M.service_breaths()
  local r = root()
  if not (r.enabled and r.breath_enabled) then return end
  local t = now()
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      local id = pair.priest_unit or pair.priest.unit_number or pair.station_unit or pair.station.unit_number or 0
      local h = hash_number(id, math.floor(t / M.breath_interval))
      -- Roughly one third of eligible intervals per priest, but deterministic.
      if (h % 3) == 0 then
        local key = "breath:" .. tostring(id)
        local allowed = cooldown_allows(key, M.breath_min_cooldown + (h % (60 * 30)))
        if allowed then
          local ok = emit(pair, "priest_breath_0531", {
            source = "priest",
            candidates = { "tech-priests-gas-mask-breathing-0531" },
            cooldown_key = key,
            cooldown_ticks = M.breath_min_cooldown,
            volume_multiplier = 0.16 + ((h % 5) * 0.01),
          })
          if ok then
            stat("priest_breath_0531")
            record("priest_breath_0531", "priest=" .. safe(id))
            pair.last_operational_sound_0531 = { tick = t, event = "priest_breath_0531" }
          end
        end
      end
    end
  end
end

local function selected_pair(player)
  local selected = player and player.valid and player.selected or nil
  if selected and selected.valid then return pair_for_entity(selected) end
  for _, pair in pairs(pair_map()) do
    if pair and valid_pair(pair) and pair.station.force == player.force then return pair end
  end
  return nil
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-operational-sounds-0531") end)
  commands.add_command("tp-operational-sounds-0531", "Tech Priests 0.1.531: operational/mechanical sound status/test. Usage: status|on|off|breath-on|breath-off|test-gas|test-machine|test-ui|test-boot", function(event)
    local player = event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local r = root()
    local p = lower(event.parameter or "status")
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "breath-on" then r.breath_enabled = true end
    if p == "breath-off" then r.breath_enabled = false end
    local pair = selected_pair(player)
    if p == "test-gas" and pair then
      emit(pair, "priest_breath_0531", { source="priest", candidates={"tech-priests-gas-mask-breathing-0531"}, volume_multiplier=0.25, cooldown_key="test-gas:"..player.index, cooldown_ticks=1 })
    elseif p == "test-machine" then
      emit(pair, "machine_start_0531", { source="station", position=player.position, surface=player.surface, candidates={"tech-priests-machine-start-0531"}, volume_multiplier=0.45, cooldown_key="test-machine:"..player.index, cooldown_ticks=1 })
    elseif p == "test-ui" then
      emit(pair, "gui_click_0531", { source="station", position=player.position, surface=player.surface, candidates={"tech-priests-tp-gui-button-press-01", "tech-priests-tp-gui-button-press-02"}, volume_multiplier=0.25, cooldown_key="test-ui:"..player.index, cooldown_ticks=1 })
    elseif p == "test-boot" then
      emit(pair, "boot_keys_0531", { source="station", position=player.position, surface=player.surface, candidates={"tech-priests-clanking-keys-0531","tech-priests-typing-sounds-0531"}, volume_multiplier=0.35, cooldown_key="test-boot:"..player.index, cooldown_ticks=1 })
    end
    player.print("[tp-operational-sounds-0531] enabled=" .. safe(r.enabled) .. " breath=" .. safe(r.breath_enabled) .. " gui_click=" .. safe(r.gui_click_enabled) .. " machine_events=" .. safe(r.machine_event_enabled) .. " stats=" .. safe(serpent and serpent.line and serpent.line(r.stats) or "see-storage"))
    local last = r.recent[#r.recent]
    if last then player.print("[tp-operational-sounds-0531] last=" .. safe(last.event) .. " detail=" .. safe(last.detail) .. " tick=" .. safe(last.tick)) end
  end)
end

function M.install()
  root()
  if M._installed then return true end
  M._installed = true
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and R.on_nth_tick then
    R.on_nth_tick(M.breath_interval, function() M.service_breaths() end, { owner = "operational_sounds_0531", category = "audio" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.breath_interval, function() M.service_breaths() end)
  end
  local function reg(ev, fn, owner)
    if R and R.on_event then
      R.on_event(ev, fn, { owner = owner or "operational_sounds_0531", category = "audio" })
    elseif script and script.on_event then
      script.on_event(ev, fn)
    end
  end
  if defines and defines.events then
    local e = defines.events
    if e.on_built_entity then reg(e.on_built_entity, function(event) M.on_machine_built(event) end) end
    if e.on_robot_built_entity then reg(e.on_robot_built_entity, function(event) M.on_machine_built(event) end) end
    if e.script_raised_built then reg(e.script_raised_built, function(event) M.on_machine_built(event) end) end
    if e.script_raised_revive then reg(e.script_raised_revive, function(event) M.on_machine_built(event) end) end
    if e.on_pre_player_mined_item then reg(e.on_pre_player_mined_item, function(event) M.on_machine_removed(event) end) end
    if e.on_robot_pre_mined then reg(e.on_robot_pre_mined, function(event) M.on_machine_removed(event) end) end
    if e.on_entity_died then reg(e.on_entity_died, function(event) M.on_machine_removed(event) end) end
    if e.script_raised_destroy then reg(e.script_raised_destroy, function(event) M.on_machine_removed(event) end) end
    if e.on_gui_click then reg(e.on_gui_click, function(event) M.on_gui_click(event) end) end
  end
  M.register_commands()
  _G.tech_priests_operational_sound_0531 = function(pair, event, opts) return emit(pair, event, opts or {}) end
  if log then log("[Tech-Priests 0.1.531] operational/mechanical sound reporter installed") end
  return true
end

return M
