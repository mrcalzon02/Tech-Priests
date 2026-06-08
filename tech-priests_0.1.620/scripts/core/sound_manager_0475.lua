-- scripts/core/sound_manager_0475.lua
-- Tech Priests 0.1.475
-- Unified sound manager for Cogitator/Tech-Priest task, writ, combat,
-- acquisition, crafting, and maintenance events.
--
-- Intent:
--   Older modules played sounds directly or routed through the 0.1.177 task
--   sound shim.  This authority keeps those legacy entry points alive while
--   moving decisions into one cooldown-governed event map.  New systems should
--   call TECH_PRIESTS_SOUND_MANAGER_0475.emit(pair, event, opts) instead of
--   playing sounds manually.

local M = {}
M.version = "0.1.475"
M.tick_interval = 23
M.default_cooldown_ticks = 60 * 3
M.station_task_switch_cooldown = 60
M.writ_cooldown = 60 * 5
M.action_ambience_cooldown = 60 * 4

local original_task_sound_0177 = nil
local original_mode_sound_0177 = nil
local original_order_submit_0469 = nil

local function now() return game and game.tick or 0 end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, out = pcall(function() return tostring(value) end)
  return ok and out or "?"
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function clamp(value, lo, hi)
  value = tonumber(value) or lo
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function setting_bool(name, default)
  if settings and settings.global and settings.global[name] ~= nil then
    local v = settings.global[name].value
    if v == nil then return default end
    return v == true
  end
  if type(read_global_bool_setting) == "function" then
    local ok, value = pcall(read_global_bool_setting, name, default)
    if ok and value ~= nil then return value == true end
  end
  return default
end

local function setting_number(name, default)
  if settings and settings.global and settings.global[name] ~= nil then
    local v = tonumber(settings.global[name].value)
    if v ~= nil then return v end
  end
  return default
end

local function enabled()
  local r = nil
  if storage and storage.tech_priests and storage.tech_priests.sound_manager_0475 then r = storage.tech_priests.sound_manager_0475 end
  if r and r.force_enabled == false then return false end
  if r and r.force_enabled == true then return true end
  if setting_bool("tech-priests-enable-sound-manager", true) == false then return false end
  return setting_bool("tech-priests-enable-task-sounds", true) ~= false
end

local function base_volume(multiplier)
  local percent = setting_number("tech-priests-task-sound-volume-percent", 70)
  return clamp((percent / 100) * (tonumber(multiplier) or 1), 0, 1.5)
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function position_from(pair, opts)
  opts = opts or {}
  if opts.position then return opts.position end
  if opts.target and valid(opts.target) then return opts.target.position end
  if opts.source == "station" and pair and valid(pair.station) then return pair.station.position end
  if opts.source == "priest" and pair and valid(pair.priest) then return pair.priest.position end
  if opts.source == "target" and opts.target_position then return opts.target_position end
  if opts.source_entity and valid(opts.source_entity) then return opts.source_entity.position end
  if pair and valid(pair.priest) then return pair.priest.position end
  if pair and valid(pair.station) then return pair.station.position end
  return nil
end

local function surface_from(pair, opts)
  opts = opts or {}
  if opts.surface then return opts.surface end
  if opts.target and valid(opts.target) then return opts.target.surface end
  if opts.source_entity and valid(opts.source_entity) then return opts.source_entity.surface end
  if opts.source == "station" and pair and valid(pair.station) then return pair.station.surface end
  if opts.source == "priest" and pair and valid(pair.priest) then return pair.priest.surface end
  if pair and valid(pair.priest) then return pair.priest.surface end
  if pair and valid(pair.station) then return pair.station.surface end
  return nil
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.sound_manager_0475 = storage.tech_priests.sound_manager_0475 or {
    version = M.version,
    stats = {},
    global_next = {},
    last = {},
  }
  local r = storage.tech_priests.sound_manager_0475
  r.version = M.version
  r.stats = r.stats or {}
  r.global_next = r.global_next or {}
  r.last = r.last or {}
  return r
end

local function stat(name, delta)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (delta or 1)
end

local function cooldown_store(pair)
  if pair then
    pair.sound_manager_next_0475 = pair.sound_manager_next_0475 or {}
    return pair.sound_manager_next_0475
  end
  return root().global_next
end

local function cooldown_allows(pair, key, ticks)
  key = key or "generic"
  ticks = tonumber(ticks) or M.default_cooldown_ticks
  local store = cooldown_store(pair)
  local t = now()
  local next_tick = tonumber(store[key] or 0) or 0
  if t < next_tick then return false, next_tick - t end
  store[key] = t + ticks
  return true, 0
end

local event_profiles = {
  station_task_switch = {
    source = "station",
    volume = 0.36,
    cooldown = 60,
    candidates = {
      "utility/wire_connect_pole",
      "utility/armor_insert",
      "utility/console_message",
      "utility/confirm",
    },
  },
  writ_issued = {
    source = "priest",
    volume = 0.54,
    cooldown = 60 * 5,
    candidates = {
      -- Several installations expose the programmable speaker alarm paths
      -- differently; try the most likely siren/alarm names first and fall
      -- back to known utility sounds if the current game rejects them.
      "programmable-speaker/siren",
      "programmable-speaker/alarm-2",
      "programmable-speaker/alarm-1",
      "utility/console_message",
      "utility/cannot_build",
      "utility/confirm",
    },
  },
  task_switch = {
    source = "station",
    volume = 0.34,
    cooldown = 60,
    candidates = { "utility/wire_connect_pole", "utility/console_message", "utility/confirm" },
  },
  logistics_request = {
    source = "station",
    volume = 0.34,
    cooldown = 60 * 4,
    candidates = { "tech-priests-clak-0531", "tech-priests-typing-sounds-0531", "utility/wire_connect_pole", "utility/confirm" },
  },
  logistics_wait = {
    source = "station",
    volume = 0.32,
    cooldown = 60 * 4,
    candidates = { "utility/cannot_build", "utility/console_message", "utility/confirm" },
  },
  crafting_action = {
    source = "priest",
    volume = 0.45,
    cooldown = 60 * 4,
    candidates = {
      "entity/assembling-machine-1/working",
      "entity/assembling-machine-2/working",
      "entity/assembling-machine-3/working",
      "utility/build_small",
      "utility/confirm",
    },
  },
  mining_laser_action = {
    source = "priest",
    volume = 0.24,
    cooldown = 60 * 2,
    candidates = {
      "tech-priests-tp-priest-scan-01",
      "tech-priests-tp-priest-scan-02",
      "tech-priests-tp-priest-scan-03",
      "utility/wire_connect_pole",
      "utility/confirm",
    },
  },
  scan_action_0533 = {
    source = "priest",
    volume = 0.22,
    cooldown = 60 * 2,
    candidates = { "tech-priests-tp-priest-scan-01", "tech-priests-tp-priest-scan-02", "tech-priests-tp-priest-scan-03", "utility/wire_connect_pole" },
  },
  emergency_laser_action = {
    source = "priest",
    volume = 0.46,
    cooldown = 45,
    candidates = {
      "entity/laser-turret/shoot",
      "entity/laser-turret/shot",
      "utility/cannot_build",
      "utility/confirm",
    },
  },
  repair_action = {
    source = "priest",
    volume = 0.42,
    cooldown = 60 * 3,
    candidates = { "tech-priests-tp-priest-repair-01", "tech-priests-tp-priest-repair-02", "tech-priests-tp-priest-repair-03", "tech-priests-clak-0531", "utility/repair_pack", "utility/manual_repair" },
  },
  consecrate_action = {
    source = "priest",
    volume = 0.42,
    cooldown = 60 * 4,
    candidates = { "tech-priests-tp-priest-sanctify-oil-01", "tech-priests-tp-priest-sanctify-oil-02", "tech-priests-tp-priest-sanctify-oil-03", "tech-priests-snap-0531", "tech-priests-clak-0531" },
  },
  deploy = {
    source = "station",
    volume = 0.52,
    cooldown = 60 * 4,
    candidates = { "tech-priests-machine-start-0531", "tech-priests-cathonk-0531", "utility/build_small", "utility/confirm" },
  },
  recall = {
    source = "station",
    volume = 0.50,
    cooldown = 60 * 4,
    candidates = { "tech-priests-typing-sounds-0531", "utility/console_message", "utility/confirm" },
  },
  return_to_station = {
    source = "station",
    volume = 0.28,
    cooldown = 60 * 6,
    candidates = { "utility/armor_insert", "utility/confirm" },
  },

  conversation_voice = {
    source = "priest",
    volume = 0.31,
    cooldown = 1,
    candidates = { "tech-priests-voice-blahblah-01" },
  },
  technology_voice = {
    source = "station",
    volume = 0.40,
    cooldown = 30,
    candidates = { "tech-priests-voice-blahblah-tech" },
  },


  machine_start_0531 = {
    source = "station",
    volume = 0.52,
    cooldown = 60 * 3,
    candidates = { "tech-priests-machine-start-0531", "tech-priests-cathonk-0531" },
  },
  machine_wind_down_0531 = {
    source = "station",
    volume = 0.44,
    cooldown = 60 * 3,
    candidates = { "tech-priests-machine-wind-down-0531", "tech-priests-clak-0531" },
  },
  priest_breath_0531 = {
    source = "priest",
    volume = 0.20,
    cooldown = 60 * 45,
    candidates = { "tech-priests-gas-mask-breathing-0531" },
  },
  gui_click_0531 = {
    source = "station",
    volume = 0.16,
    cooldown = 6,
    candidates = { "tech-priests-tp-gui-button-press-01", "tech-priests-tp-gui-button-press-02", "tech-priests-clicker-button-0531", "tech-priests-clak-0531" },
  },
  gui_panel_open_0533 = { source = "station", volume = 0.20, cooldown = 10, candidates = { "tech-priests-tp-gui-panel-open-01" } },
  gui_panel_close_0533 = { source = "station", volume = 0.20, cooldown = 10, candidates = { "tech-priests-tp-gui-panel-close-01" } },
  gui_tab_changed_0533 = { source = "station", volume = 0.18, cooldown = 5, candidates = { "tech-priests-tp-gui-tab-change-01" } },
  gui_portrait_selected_0533 = { source = "station", volume = 0.18, cooldown = 5, candidates = { "tech-priests-tp-gui-portrait-select-01" } },

  priest_emergency_0533 = {
    source = "priest",
    volume = 0.42,
    cooldown = 60 * 30,
    candidates = { "tech-priests-tp-priest-emergency-01", "tech-priests-tp-priest-emergency-02", "utility/cannot_build", "utility/console_message" },
  },
  station_link_established_0533 = {
    source = "station",
    volume = 0.38,
    cooldown = 1,
    candidates = { "tech-priests-tp-station-link-established-01", "tech-priests-tp-station-link-established-02", "tech-priests-cathonk-0531" },
  },
  station_link_broken_0533 = {
    source = "station",
    volume = 0.40,
    cooldown = 60 * 10,
    candidates = { "tech-priests-tp-station-link-broken-01", "tech-priests-tp-station-link-broken-02", "utility/cannot_build" },
  },
  machine_low_sanctity_warning_0533 = {
    source = "target",
    volume = 0.34,
    cooldown = 60 * 30,
    candidates = { "tech-priests-tp-machine-low-sanctity-warning-01", "tech-priests-tp-machine-low-sanctity-warning-02", "tech-priests-tp-machine-low-sanctity-warning-03" },
  },
  machine_detritus_clog_0533 = {
    source = "target",
    volume = 0.38,
    cooldown = 60 * 15,
    candidates = { "tech-priests-tp-machine-detritus-clog-01", "tech-priests-tp-machine-detritus-clog-02" },
  },

  conversation_start = {
    source = "priest",
    volume = 0.22,
    cooldown = 60 * 8,
    candidates = { "tech-priests-typing-sounds-0531", "utility/console_message", "utility/confirm" },
  },
  conversation_line = {
    source = "priest",
    volume = 0.16,
    cooldown = 60 * 4,
    candidates = { "tech-priests-typing-sounds-0531", "utility/console_message", "utility/confirm" },
  },
  polite_cough = {
    source = "priest",
    volume = 0.16,
    cooldown = 60 * 8,
    candidates = { "tech-priests-gas-mask-breathing-0531", "utility/console_message", "utility/cannot_build", "utility/confirm" },
  },
  inventory_transfer = {
    source = "station",
    volume = 0.42,
    cooldown = 60 * 2,
    candidates = { "tech-priests-cathonk-0531", "tech-priests-clak-0531", "utility/inventory_move", "utility/armor_insert", "utility/confirm" },
  },
  watchdog = {
    source = "station",
    volume = 0.46,
    cooldown = 60 * 6,
    candidates = { "utility/cannot_build", "utility/console_message", "utility/confirm" },
  },
  idle_scan = {
    source = "station",
    volume = 0.18,
    cooldown = 60 * 7,
    candidates = { "tech-priests-tp-priest-scan-01", "tech-priests-tp-priest-scan-02", "tech-priests-tp-priest-scan-03", "tech-priests-clak-0531", "tech-priests-typing-sounds-0531" },
  },
}

local legacy_event_map = {
  deploy = "deploy",
  recall = "recall",
  return_to_station = "return_to_station",
  repair = "repair_action",
  consecrate = "consecrate_action",
  logistics_request = "logistics_request",
  logistics_wait = "logistics_wait",
  scan_scavenge = "scan_action_0533",
  scan_cram = "logistics_wait",
  scavenge_take = "inventory_transfer",
  scavenge_pickup = "inventory_transfer",
  cram_deposit = "inventory_transfer",
  cram_dump = "logistics_wait",
  emergency_scan_inventory = "scan_action_0533",
  emergency_scan_field = "scan_action_0533",
  emergency_take = "inventory_transfer",
  emergency_craft = "crafting_action",
  combat = "emergency_laser_action",
  idle_scan = "idle_scan",
  conversation_start = "conversation_start",
  conversation_line = "conversation_line",
  polite_cough = "polite_cough",
  watchdog = "watchdog",
}

local mode_event_map = {
  ["moving-to-repair"] = "repair_action",
  repairing = "repair_action",
  ["moving-to-consecrate"] = "consecrate_action",
  consecrating = "consecrate_action",
  ["missing-repair-supplies"] = "logistics_wait",
  ["missing-consecration-supplies"] = "logistics_wait",
  ["missing-ammo-supplies"] = "logistics_wait",
  ["awaiting-logistics"] = "logistics_request",
  ["logistics-requested"] = "logistics_request",
  ["logistics-scavenge-countdown"] = "logistics_request",
  ["logistics-no-network"] = "logistics_wait",
  ["logistics-cram-countdown"] = "logistics_wait",
  ["moving-to-scavenge"] = "scan_action_0533",
  ["scavenging-supplies"] = "scan_action_0533",
  ["moving-to-cram"] = "logistics_wait",
  ["cramming-supplies"] = "inventory_transfer",
  ["moving-to-combat"] = "emergency_laser_action",
  defending = "emergency_laser_action",
  ["defending-laser-fallback"] = "emergency_laser_action",
  ["moving-to-laser-fallback"] = "emergency_laser_action",
  ["emergency-gathering"] = "priest_emergency_0533",
  ["independent-emergency-operation"] = "priest_emergency_0533",
  ["emergency-crafting"] = "crafting_action",
  ["idle-conversation"] = "conversation_start",
  returning = "return_to_station",
  ["returning-to-station"] = "return_to_station",
  deploying = "deploy",
}

local function profile_for(event)
  return event_profiles[event] or event_profiles[legacy_event_map[event or ""] or ""] or event_profiles.task_switch
end

local function play_candidates(surface, position, candidates, volume)
  if not (surface and position and surface.play_sound) then return false, "no-surface-or-position" end
  if volume <= 0 then return false, "volume-zero" end
  for _, path in ipairs(candidates or {}) do
    local ok = pcall(function()
      surface.play_sound({ path = path, position = position, volume_modifier = math.max(0, math.min(1, volume)) })
    end)
    if ok then return true, path end
  end
  return false, "no-candidate-accepted"
end

local function candidate_order_0533(candidates, seed)
  if type(candidates) ~= "table" or #candidates <= 1 then return candidates end
  local n = #candidates
  local h = tonumber(seed) or now() or 0
  if type(seed) == "string" then
    h = 5381
    for i = 1, #seed do h = (h * 33 + string.byte(seed, i)) % 2147483647 end
  end
  local start = (math.abs(h) % n) + 1
  local out = {}
  for i = 0, n - 1 do out[#out + 1] = candidates[((start + i - 1) % n) + 1] end
  return out
end

function M.emit(pair, event, opts)
  opts = opts or {}
  if not enabled() then return false, "disabled" end
  event = legacy_event_map[event or ""] or event or "task_switch"
  local profile = profile_for(event)
  local sound_surface = surface_from(pair, opts)
  local source = opts.source or profile.source
  local sound_position = position_from(pair, { position = opts.position, target = opts.target, source = source, source_entity = opts.source_entity, target_position = opts.target_position, surface = opts.surface })
  if not (sound_surface and sound_position) then return false, "no-position" end

  local cooldown = tonumber(opts.cooldown_ticks or profile.cooldown or M.default_cooldown_ticks) or M.default_cooldown_ticks
  local cooldown_key = opts.cooldown_key or ("sound:" .. safe(event) .. ":" .. safe(opts.item or opts.key or "generic"))
  local allowed, remaining = cooldown_allows(pair, cooldown_key, cooldown)
  if not allowed then return false, "cooldown:" .. safe(remaining) end

  local volume = base_volume(tonumber(opts.volume_multiplier or profile.volume or 0.4) or 0.4)
  local candidates = candidate_order_0533(opts.candidates or profile.candidates, safe(event) .. ":" .. safe(cooldown_key) .. ":" .. safe(now()))
  local ok, used = play_candidates(sound_surface, sound_position, candidates, volume)
  if ok then
    stat("played")
    local r = root()
    r.last[#r.last + 1] = { tick = now(), event = event, path = used, item = opts.item, source = source }
    while #r.last > 16 do table.remove(r.last, 1) end
    if pair then pair.last_sound_event_0475 = { tick = now(), event = event, path = used, item = opts.item, source = source } end
    return true, used
  end
  stat("failed")
  return false, used
end

local function classify_action_event(pair)
  if not valid_pair(pair) then return nil end
  local order = pair.active_order_0469 or (pair.order_queue_0469 and pair.order_queue_0469.current) or nil
  local kind = lower(order and order.kind or pair.mode)
  local mode = lower(pair.mode)
  if kind:find("combat", 1, true) or mode:find("combat", 1, true) or mode:find("defend", 1, true) or mode:find("laser%-fallback") then return "emergency_laser_action" end
  if kind:find("emergency", 1, true) or mode:find("emergency", 1, true) then return "priest_emergency_0533" end
  if kind:find("repair", 1, true) or mode:find("repair", 1, true) then return "repair_action" end
  if kind:find("consecr", 1, true) or kind:find("sanct", 1, true) or mode:find("consecr", 1, true) or mode:find("sanct", 1, true) then return "consecrate_action" end
  if kind:find("craft", 1, true) or mode:find("craft", 1, true) then return "crafting_action" end
  if kind:find("mine", 1, true) or kind:find("acqui", 1, true) or kind:find("gather", 1, true) or kind:find("scavenge", 1, true) or mode:find("gather", 1, true) or mode:find("mine", 1, true) or mode:find("scavenge", 1, true) then return "mining_laser_action" end
  if kind:find("logistic", 1, true) or mode:find("logistic", 1, true) then return "logistics_request" end
  return nil
end

local function current_signature(pair)
  if not valid_pair(pair) then return "invalid" end
  local q = pair.order_queue_0469
  local current = pair.active_order_0469 or (q and q.current) or nil
  local current_key = current and current.key or "none"
  local item = current and current.item or pair.logistic_requested_item or "none"
  local mode = pair.mode or "nil"
  return safe(current_key) .. "|" .. safe(item) .. "|" .. safe(mode)
end

function M.tick_pair(pair)
  if not valid_pair(pair) then return end
  local signature = current_signature(pair)
  if pair.sound_manager_last_signature_0475 ~= signature then
    local had_previous = pair.sound_manager_last_signature_0475 ~= nil
    pair.sound_manager_last_signature_0475 = signature
    if had_previous then
      local order = pair.active_order_0469 or (pair.order_queue_0469 and pair.order_queue_0469.current) or nil
      M.emit(pair, "station_task_switch", {
        source = "station",
        item = order and order.item,
        key = signature,
        cooldown_key = "station-switch:" .. safe(valid(pair.station) and pair.station.unit_number or "?"),
        cooldown_ticks = M.station_task_switch_cooldown,
        volume_multiplier = 0.34,
      })
    end
  end

  local action_event = classify_action_event(pair)
  if action_event then
    local order = pair.active_order_0469 or (pair.order_queue_0469 and pair.order_queue_0469.current) or nil
    local action_cooldown = M.action_ambience_cooldown
    local action_volume = (action_event == "emergency_laser_action") and 0.40 or 0.28
    local action_source = action_event == "logistics_request" and "station" or "priest"
    if action_event == "priest_emergency_0533" then
      action_cooldown = 60 * 30
      action_volume = 0.42
    elseif action_event == "scan_action_0533" or action_event == "mining_laser_action" then
      action_cooldown = 60 * 2
      action_volume = 0.22
    end
    M.emit(pair, action_event, {
      source = action_source,
      item = order and order.item,
      key = action_event,
      cooldown_key = "action-ambience:" .. safe(action_event),
      cooldown_ticks = action_cooldown,
      volume_multiplier = action_volume,
    })
  end
end

function M.tick_all()
  if not enabled() then return end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then pcall(function() M.tick_pair(pair) end) end
  end
end

function M.wrap_legacy_task_sound()
  if type(rawget(_G, "tech_priests_play_task_sound_0177")) == "function" and not original_task_sound_0177 then
    original_task_sound_0177 = rawget(_G, "tech_priests_play_task_sound_0177")
    _G.TECH_PRIESTS_0475_PRE_TASK_SOUND_0177 = original_task_sound_0177
    _G.tech_priests_play_task_sound_0177 = function(pair, sound_key, position, cooldown_ticks, volume_multiplier)
      local event = legacy_event_map[sound_key or ""] or sound_key or "task_switch"
      local ok = M.emit(pair, event, {
        position = position,
        cooldown_ticks = cooldown_ticks,
        volume_multiplier = volume_multiplier,
        key = sound_key,
      })
      return ok == true
    end
  end

  if type(rawget(_G, "tech_priests_play_mode_transition_sound_0177")) == "function" and not original_mode_sound_0177 then
    original_mode_sound_0177 = rawget(_G, "tech_priests_play_mode_transition_sound_0177")
    _G.TECH_PRIESTS_0475_PRE_MODE_SOUND_0177 = original_mode_sound_0177
    _G.tech_priests_play_mode_transition_sound_0177 = function(pair, mode)
      local event = mode_event_map[mode or ""] or "task_switch"
      M.emit(pair, "station_task_switch", { source = "station", key = mode, cooldown_ticks = M.station_task_switch_cooldown, volume_multiplier = 0.30 })
      return M.emit(pair, event, { key = mode, cooldown_ticks = 60 * 5, volume_multiplier = 0.28 })
    end
  end
end

function M.wrap_order_queue()
  local oq = rawget(_G, "TECH_PRIESTS_ORDER_QUEUE_0469")
  if not (oq and type(oq.submit) == "function") then return false end
  if oq.sound_manager_wrapped_0475 then return true end
  original_order_submit_0469 = oq.submit
  oq.sound_manager_wrapped_0475 = true
  oq.submit = function(pair, order, opts)
    local ok, state, existing = original_order_submit_0469(pair, order, opts)
    if ok and (state == "active" or state == "queued" or state == "preempt") and order then
      M.emit(pair, "writ_issued", {
        source = "priest",
        item = order.item,
        key = order.key,
        cooldown_key = "writ:" .. safe(order.key),
        cooldown_ticks = M.writ_cooldown,
        volume_multiplier = 0.54,
      })
      if state == "preempt" then
        M.emit(pair, "station_task_switch", { source = "station", item = order.item, key = order.key, cooldown_ticks = M.station_task_switch_cooldown, volume_multiplier = 0.38 })
      end
    end
    return ok, state, existing
  end
  _G.tech_priests_0469_submit_order = oq.submit
  return true
end

function M.install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-sound-manager-0475") end end)
  pcall(function()
    commands.add_command("tp-sound-manager-0475", "Tech Priests 0.1.475: unified sound manager. Usage: status|test-writ|test-switch|test-mining|test-combat|test-repair|test-sanctify|test-emergency|test-link|off|on|auto", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local param = lower(event and event.parameter or "status")
      local r = root()
      if param == "off" or param == "disable" then
        r.force_enabled = false
      elseif param == "on" or param == "enable" then
        r.force_enabled = true
      elseif param == "auto" then
        r.force_enabled = nil
      end

      local pair = nil
      if player and player.valid then
        local sel = player.selected
        if valid(sel) and storage and storage.tech_priests then
          if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[sel.unit_number] then pair = storage.tech_priests.pairs_by_station[sel.unit_number] end
          if not pair and storage.tech_priests.station_by_priest and storage.tech_priests.pairs_by_station then
            local station_unit = storage.tech_priests.station_by_priest[sel.unit_number]
            pair = station_unit and storage.tech_priests.pairs_by_station[station_unit] or nil
          end
        end
      end

      if param == "test-writ" then M.emit(pair, "writ_issued", { cooldown_key = "manual-test-writ", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-switch" then M.emit(pair, "station_task_switch", { source = "station", cooldown_key = "manual-test-switch", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-mining" then M.emit(pair, "mining_laser_action", { cooldown_key = "manual-test-mining", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-combat" then M.emit(pair, "emergency_laser_action", { cooldown_key = "manual-test-combat", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-repair" then M.emit(pair, "repair_action", { cooldown_key = "manual-test-repair", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-sanctify" then M.emit(pair, "consecrate_action", { cooldown_key = "manual-test-sanctify", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-emergency" then M.emit(pair, "priest_emergency_0533", { cooldown_key = "manual-test-emergency", cooldown_ticks = 1, volume_multiplier = 0.7 }) end
      if param == "test-link" then M.emit(pair, "station_link_established_0533", { source = "station", cooldown_key = "manual-test-link", cooldown_ticks = 1, volume_multiplier = 0.7 }) end

      if player and player.valid then
        local r = root()
        player.print("[tp-sound-manager-0475] enabled=" .. safe(enabled()) .. " override=" .. safe(r.force_enabled) .. " played=" .. safe(r.stats.played or 0) .. " failed=" .. safe(r.stats.failed or 0) .. " volume=" .. safe(setting_number("tech-priests-task-sound-volume-percent", 70)) .. "%")
        if pair and pair.last_sound_event_0475 then
          local s = pair.last_sound_event_0475
          player.print("[tp-sound-manager-0475] selected last event=" .. safe(s.event) .. " path=" .. safe(s.path) .. " item=" .. safe(s.item) .. " tick=" .. safe(s.tick))
        else
          player.print("[tp-sound-manager-0475] select a Cogitator Station or Tech-Priest for pair-local sound status/tests.")
        end
      end
    end)
  end)
end

function M.install()
  root()
  M.wrap_legacy_task_sound()
  M.wrap_order_queue()
  M.install_commands()
  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(M.tick_interval, function() M.tick_all() end, { owner = "sound_manager_0475", category = "audio" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, function() M.tick_all() end)
  end
  _G.TECH_PRIESTS_SOUND_MANAGER_0475 = M
  _G.tech_priests_sound_event_0475 = M.emit
  if log then log("[Tech-Priests 0.1.475] unified task/writ sound manager installed") end
  return true
end

return M
