-- scripts/core/placeholder_audio_0533.lua
-- Tech Priests 0.1.533
-- Functional placeholder audio integration layer.
--
-- This is an audio reporter only. It observes meaningful transitions and asks
-- sound_manager_0475 to play cooldown-governed one-shots. It must not create
-- work, alter orders, move priests, complete tasks, change inventories, or draw
-- visuals.

local M = {}
M.version = "0.1.533"
M.storage_key = "placeholder_audio_0533"
M.machine_scan_interval = 311
M.broken_link_scan_interval = 601

local original_create_pair = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
    next_by_key = {},
    machine_state = {},
    link_state = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.next_by_key = r.next_by_key or {}
  r.machine_state = r.machine_state or {}
  r.link_state = r.link_state or {}
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

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function pair_for_entity(entity)
  if not valid(entity) then return nil end
  local tp = storage and storage.tech_priests or nil
  if tp then
    if tp.pairs_by_station and entity.unit_number and tp.pairs_by_station[entity.unit_number] then return tp.pairs_by_station[entity.unit_number] end
    if tp.station_by_priest and tp.pairs_by_station and entity.unit_number then
      local station_unit = tp.station_by_priest[entity.unit_number]
      if station_unit and tp.pairs_by_station[station_unit] then return tp.pairs_by_station[station_unit] end
    end
  end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.station == entity or pair.priest == entity) then return pair end
  end
  return nil
end

local function emit(pair, event, opts)
  opts = opts or {}
  local r = root()
  if not r.enabled then return false, "disabled" end
  if _G.tech_priests_sound_event_0475 then
    local ok, a, b = pcall(_G.tech_priests_sound_event_0475, pair, event, opts)
    if ok then
      if a then stat(event); record(event, safe(b or opts.path or "played")) end
      return a, b
    end
  end
  local entity = opts.source_entity or opts.target
  local surface = opts.surface or (valid(entity) and entity.surface) or (pair and valid(pair.station) and pair.station.surface) or nil
  local position = opts.position or (valid(entity) and entity.position) or (pair and valid(pair.priest) and pair.priest.position) or (pair and valid(pair.station) and pair.station.position) or nil
  local path = opts.path or (opts.candidates and opts.candidates[1]) or nil
  if surface and position and path and surface.play_sound then
    local ok = pcall(function() surface.play_sound({ path = path, position = position, volume_modifier = math.max(0, math.min(1, tonumber(opts.volume_multiplier or 0.35) or 0.35)) }) end)
    if ok then stat(event); record(event, safe(path)); return true, path end
  end
  return false, "no-sound-target"
end

function M.emit_machine(entity, event, opts)
  if not valid(entity) then return false, "invalid-entity" end
  opts = opts or {}
  if opts.force_theater ~= true then
    local allow_theater = rawget(_G, "tech_priests_allow_theater_for_entity_0609")
    if allow_theater then
      local ok, allowed, tier = pcall(allow_theater, entity, "audio")
      if ok and allowed == false then
        stat("spatial_audio_suppressed_0609")
        return false, "spatial-interest-" .. tostring(tier or "suppressed")
      end
    end
  end
  opts.source_entity = opts.source_entity or entity
  opts.target = opts.target or entity
  opts.surface = opts.surface or entity.surface
  opts.position = opts.position or entity.position
  opts.cooldown_key = opts.cooldown_key or (tostring(event) .. ":" .. tostring(entity.unit_number or entity.name or "entity"))
  return emit(pair_for_entity(entity), event, opts)
end

function M.wrap_create_pair()
  if original_create_pair or type(rawget(_G, "create_pair")) ~= "function" then return false end
  original_create_pair = rawget(_G, "create_pair")
  _G.TECH_PRIESTS_0533_PRE_CREATE_PAIR = original_create_pair
  _G.create_pair = function(station, ...)
    local pair = original_create_pair(station, ...)
    if pair and valid(pair.station) then
      local unit = pair.station.unit_number or 0
      local key = "station-link-established:" .. tostring(unit)
      local allowed = cooldown_allows(key, 1)
      if allowed then
        emit(pair, "station_link_established_0533", {
          source = "station",
          cooldown_key = key,
          cooldown_ticks = 1,
          volume_multiplier = 0.42,
        })
      end
    end
    return pair
  end
  return true
end

function M.scan_broken_links()
  local r = root()
  if not r.enabled then return end
  for station_unit, pair in pairs(pair_map()) do
    local station_ok = pair and valid(pair.station)
    local priest_ok = pair and valid(pair.priest)
    local key = tostring(station_unit or (pair and pair.station_unit) or "?")
    local prior = r.link_state[key]
    local broken = station_ok and not priest_ok
    r.link_state[key] = broken and "broken" or "ok"
    if broken and prior ~= "broken" then
      local cd_key = "station-link-broken:" .. key
      if cooldown_allows(cd_key, 60 * 10) then
        emit(pair, "station_link_broken_0533", {
          source = "station",
          position = pair.station.position,
          surface = pair.station.surface,
          cooldown_key = cd_key,
          cooldown_ticks = 60 * 10,
          volume_multiplier = 0.45,
        })
      end
    end
  end
end

local function record_ratio(record)
  local max_value = tonumber(record and record.max_sanctification) or nil
  if not max_value and get_base_sanctification_max and record and record.entity and record.entity.valid then
    local ok, value = pcall(get_base_sanctification_max, record.entity.force)
    if ok then max_value = tonumber(value) end
  end
  max_value = max_value or 100
  if max_value <= 0 then max_value = 100 end
  return math.max(0, math.min(2, (tonumber(record and record.sanctification) or 0) / max_value))
end

function M.scan_machine_audio()
  local r = root()
  if not r.enabled then return end
  local machines = storage and storage.tech_priests and storage.tech_priests.consecration and storage.tech_priests.consecration.machines or nil
  if type(machines) ~= "table" then return end
  for unit, record in pairs(machines) do
    local entity = record and record.entity or nil
    if valid(entity) then
      local key = tostring(unit or entity.unit_number or entity.name)
      local state = r.machine_state[key] or {}
      local ratio = record_ratio(record)
      local total_detritus = tonumber(record.total_detritus_inserted_0422 or record.total_waste_inserted_0417 or 0) or 0
      local jammed = record.waste_jammed == true or record.detritus_jammed == true or ((tonumber(record.last_detritus_remaining_0417 or 0) or 0) > 0 and (tonumber(record.last_detritus_requested_0417 or 0) or 0) > 0)

      local crossed_low = (ratio <= 0.35 and (state.ratio == nil or state.ratio > 0.35)) or (ratio <= 0.45 and (state.ratio == nil or state.ratio > 0.45))
      if crossed_low then
        M.emit_machine(entity, "machine_low_sanctity_warning_0533", {
          source = "target",
          cooldown_key = "machine-low-sanctity:" .. key,
          cooldown_ticks = 60 * 30,
          volume_multiplier = 0.34,
          key = key,
        })
      end

      if jammed and state.jammed ~= true then
        M.emit_machine(entity, "machine_detritus_clog_0533", {
          source = "target",
          cooldown_key = "machine-detritus-clog:" .. key,
          cooldown_ticks = 60 * 15,
          volume_multiplier = 0.38,
          key = key,
        })
      elseif total_detritus > (tonumber(state.total_detritus or 0) or 0) and ratio <= 0.45 then
        -- A softer occasional cue for new detritus appearing under dirty operation,
        -- but still cooldown-limited per machine so output contamination does not chatter.
        M.emit_machine(entity, "machine_detritus_clog_0533", {
          source = "target",
          cooldown_key = "machine-detritus-growth:" .. key,
          cooldown_ticks = 60 * 15,
          volume_multiplier = 0.25,
          key = key,
        })
      end

      state.ratio = ratio
      state.jammed = jammed
      state.total_detritus = total_detritus
      r.machine_state[key] = state
    else
      r.machine_state[tostring(unit)] = nil
    end
  end
end

local function is_tech_priest_gui_event(event)
  local element = event and event.element
  local name = element and element.valid and tostring(element.name or "") or ""
  if name ~= "" and (name:find("tech_priests", 1, true) or name:find("tp_", 1, true) or lower(name):find("tech%-priest")) then return true end
  local entity = event and event.entity or nil
  if valid(entity) then
    local ename = lower(entity.name or "")
    if ename:find("tech%-priest") or ename:find("cogitator", 1, true) then return true end
  end
  return false
end

function M.on_gui_opened(event)
  if not is_tech_priest_gui_event(event) then return end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local pair = nil
  if valid(event.entity) then pair = pair_for_entity(event.entity) end
  emit(pair, "gui_panel_open_0533", {
    source = "station",
    position = player.position,
    surface = player.surface,
    cooldown_key = "gui-panel-open:" .. tostring(player.index),
    cooldown_ticks = 10,
    volume_multiplier = 0.22,
  })
end

function M.on_gui_closed(event)
  if not is_tech_priest_gui_event(event) then return end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local pair = nil
  if valid(event.entity) then pair = pair_for_entity(event.entity) end
  emit(pair, "gui_panel_close_0533", {
    source = "station",
    position = player.position,
    surface = player.surface,
    cooldown_key = "gui-panel-close:" .. tostring(player.index),
    cooldown_ticks = 10,
    volume_multiplier = 0.22,
  })
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
  pcall(function() commands.remove_command("tp-placeholder-audio-0533") end)
  commands.add_command("tp-placeholder-audio-0533", "Tech Priests 0.1.533: placeholder audio status/test. Usage: status|on|off|test-repair|test-oil|test-scan|test-emergency|test-link|test-broken|test-low|test-clog", function(event)
    local player = event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local r = root()
    local p = lower(event.parameter or "status")
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    local pair = selected_pair(player)
    local selected = player.selected
    local entity = valid(selected) and selected or nil
    local common = { position = player.position, surface = player.surface, cooldown_key = "manual-placeholder-audio:" .. p .. ":" .. tostring(player.index), cooldown_ticks = 1, volume_multiplier = 0.7 }
    if p == "test-repair" then emit(pair, "repair_action", common) end
    if p == "test-oil" or p == "test-sanctify" then emit(pair, "consecrate_action", common) end
    if p == "test-scan" then emit(pair, "scan_action_0533", common) end
    if p == "test-emergency" then emit(pair, "priest_emergency_0533", common) end
    if p == "test-link" then emit(pair, "station_link_established_0533", common) end
    if p == "test-broken" then emit(pair, "station_link_broken_0533", common) end
    if p == "test-low" then M.emit_machine(entity or (pair and pair.station), "machine_low_sanctity_warning_0533", common) end
    if p == "test-clog" then M.emit_machine(entity or (pair and pair.station), "machine_detritus_clog_0533", common) end
    player.print("[tp-placeholder-audio-0533] enabled=" .. safe(r.enabled) .. " stats=" .. safe(serpent and serpent.line and serpent.line(r.stats) or "see-storage"))
    local last = r.recent[#r.recent]
    if last then player.print("[tp-placeholder-audio-0533] last=" .. safe(last.event) .. " detail=" .. safe(last.detail) .. " tick=" .. safe(last.tick)) end
  end)
end

function M.install()
  root()
  if M._installed then return true end
  M._installed = true
  M.wrap_create_pair()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and R.on_nth_tick then
    R.on_nth_tick(M.machine_scan_interval, function() M.scan_machine_audio() end, { owner = "placeholder_audio_0533", category = "audio" })
    R.on_nth_tick(M.broken_link_scan_interval, function() M.scan_broken_links() end, { owner = "placeholder_audio_0533", category = "audio" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.machine_scan_interval, function() M.scan_machine_audio() end)
    script.on_nth_tick(M.broken_link_scan_interval, function() M.scan_broken_links() end)
  end
  local function reg(ev, fn)
    if R and R.on_event then
      R.on_event(ev, fn, { owner = "placeholder_audio_0533", category = "audio" })
    elseif script and script.on_event then
      script.on_event(ev, fn)
    end
  end
  if defines and defines.events then
    local e = defines.events
    if e.on_gui_opened then reg(e.on_gui_opened, function(event) M.on_gui_opened(event) end) end
    if e.on_gui_closed then reg(e.on_gui_closed, function(event) M.on_gui_closed(event) end) end
  end
  M.register_commands()
  _G.tech_priests_placeholder_audio_0533 = M
  _G.tech_priests_placeholder_audio_0533_emit_machine = function(entity, event, opts) return M.emit_machine(entity, event, opts or {}) end
  if log then log("[Tech-Priests 0.1.533] placeholder functional audio reporter installed") end
  return true
end

return M
