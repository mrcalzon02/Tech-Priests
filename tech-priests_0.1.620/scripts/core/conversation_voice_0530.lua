-- scripts/core/conversation_voice_0530.lua
-- Tech Priests 0.1.530
-- Deterministic voice-bark overlay for visible conversation lines and
-- technology-selection doctrine notices.
--
-- This module is an audio reporter only. It must not create work, complete
-- orders, alter pair state, or drive conversation timing. Conversation text is
-- still owned by chatter/doctrine systems; this layer only plays a short
-- non-lexical voice bark at the moment a visible typewriter line begins.

local M = {}
M.version = "0.1.530"

local generic_clips = {
  "tech-priests-voice-blahblah-01",
  "tech-priests-voice-blahblah-02",
  "tech-priests-voice-blahblah-03",
  "tech-priests-voice-blahblah-04",
  "tech-priests-voice-blahblah-05",
  "tech-priests-voice-blahblah-06",
  "tech-priests-voice-blahblah-07",
  "tech-priests-voice-blahblah-08",
  "tech-priests-voice-blahblah-09",
  "tech-priests-voice-blahblah-10",
  "tech-priests-voice-blahblah-11",
  "tech-priests-voice-blahblah-12",
}

local tech_clip = "tech-priests-voice-blahblah-tech"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, s = pcall(function() return tostring(v) end); return ok and s or "?" end

local function lower(v) return string.lower(tostring(v or "")) end

local function setting_bool(name, default)
  if settings and settings.global and settings.global[name] ~= nil then
    local v = settings.global[name].value
    if v ~= nil then return v == true end
  end
  return default
end

local function setting_number(name, default)
  if settings and settings.global and settings.global[name] ~= nil then
    local n = tonumber(settings.global[name].value)
    if n ~= nil then return n end
  end
  return default
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.conversation_voice_0530 = storage.tech_priests.conversation_voice_0530 or {
    version = M.version,
    enabled = true,
    stats = {},
    next_by_key = {},
    last = {},
    force_current_research = {}
  }
  local r = storage.tech_priests.conversation_voice_0530
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.next_by_key = r.next_by_key or {}
  r.last = r.last or {}
  r.force_current_research = r.force_current_research or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function hash_string(text)
  text = tostring(text or "")
  -- Arithmetic-only hash for Factorio Lua compatibility; avoids bitwise ops.
  local h = 5381
  for i = 1, #text do
    h = (h * 33 + string.byte(text, i)) % 2147483647
  end
  return h
end

local function normalize_text(text)
  text = tostring(text or "")
  text = text:gsub("%[technology=[^%]]+%]", "[technology]")
  text = text:gsub("%[item=[^%]]+%]", "[item]")
  text = text:gsub("%[entity=[^%]]+%]", "[entity]")
  text = text:gsub("%s+", " ")
  return text
end

local function unit(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or (pair.priest and pair.priest.valid and pair.priest.unit_number)) or 0
end

local function rank_key(pair)
  return tostring(pair and (pair.tier or pair.rank_key or pair.rank or pair.station_tier) or "unknown")
end

local function line_school(pair, line)
  local channel = lower(line and line.channel)
  local text = lower(line and line.text)
  if channel:find("technology", 1, true) or text:find("technology", 1, true) or text:find("research", 1, true) then return "technology-line" end
  if channel:find("doctrine", 1, true) then return "doctrine" end
  if channel:find("argument", 1, true) then return "argument" end
  if channel:find("priest%-player") then return "direct" end
  if channel:find("priest%-priest") then return "priest-priest" end
  if channel ~= "" then return channel end
  return "ambient:" .. rank_key(pair)
end

local function choose_generic_clip(pair, line)
  local school = line_school(pair, line)
  local h = hash_string(school .. "|" .. rank_key(pair) .. "|" .. normalize_text(line and line.text) .. "|" .. tostring(unit(pair) % 97))
  local idx = (h % #generic_clips) + 1
  local vol_bucket = (math.floor(h / 256) % 9) -- 0..8
  local speed_bucket = (math.floor(h / 65536) % 3) -- 0 slow, 1 normal, 2 fast
  local suffix = speed_bucket == 0 and "-slow" or (speed_bucket == 2 and "-fast" or "")
  local volume = (0.22 + (vol_bucket * 0.025)) * 1.10
  return generic_clips[idx] .. suffix, volume, school, h
end

local function can_play(r, key, cooldown)
  local t = now()
  local next_tick = tonumber(r.next_by_key[key] or 0) or 0
  if t < next_tick then return false, next_tick - t end
  r.next_by_key[key] = t + (tonumber(cooldown) or 1)
  return true, 0
end

local function emit_via_sound_manager(pair, event, clip, volume, cooldown_key, cooldown_ticks, opts)
  opts = opts or {}
  if _G.tech_priests_sound_event_0475 then
    local ok, a, b = pcall(_G.tech_priests_sound_event_0475, pair, event, {
      candidates = { clip },
      source = opts.source or "priest",
      position = opts.position,
      surface = opts.surface,
      cooldown_key = cooldown_key,
      cooldown_ticks = cooldown_ticks or 1,
      volume_multiplier = volume or 0.25,
      key = opts.key,
      item = opts.item,
    })
    if ok then return a, b end
  end
  local entity = pair and (opts.source == "station" and pair.station or pair.priest) or nil
  local surface = opts.surface or (entity and entity.valid and entity.surface) or nil
  local position = opts.position or (entity and entity.valid and entity.position) or nil
  if surface and surface.play_sound and position then
    local ok = pcall(function() surface.play_sound({ path = clip, position = position, volume_modifier = math.max(0, math.min(1, volume or 0.25)) }) end)
    if ok then return true, clip end
  end
  return false, "no-sound-target"
end

function M.on_line_started(line)
  local r = root()
  if not r.enabled or setting_bool("tech-priests-enable-voice-barks-0530", true) == false then return false, "disabled" end
  if not (line and line.pair and valid(line.pair.priest)) then return false, "invalid-line" end
  local pair = line.pair
  local clip, volume, school, h = choose_generic_clip(pair, line)
  local key = "line:" .. tostring(line.id or h) .. ":" .. tostring(unit(pair))
  local allowed = can_play(r, key, 1)
  if not allowed then return false, "line-cooldown" end
  local ok, used = emit_via_sound_manager(pair, "conversation_voice", clip, volume, key, 1, { source = "priest", key = school })
  if ok then
    stat("line_played")
    r.last[#r.last + 1] = { tick = now(), event = "line", school = school, clip = used or clip, volume = volume, unit = unit(pair) }
    while #r.last > 20 do table.remove(r.last, 1) end
    pair.last_voice_bark_0530 = { tick = now(), school = school, clip = used or clip, volume = volume }
  else
    stat("line_failed")
  end
  return ok, used
end

local function force_pairs(force)
  local out = {}
  for _, pair in pairs(storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}) do
    if pair and valid(pair.station) and valid(pair.priest) and pair.station.force == force then out[#out + 1] = pair end
  end
  table.sort(out, function(a, b)
    local score = { ["void"] = 6, ["planetary-magos"] = 5, ["senior"] = 4, ["intermediate"] = 3, ["junior"] = 2 }
    local sa = score[tostring(a.tier or a.rank_key or "")] or 1
    local sb = score[tostring(b.tier or b.rank_key or "")] or 1
    if sa ~= sb then return sa > sb end
    return (unit(a) or 0) < (unit(b) or 0)
  end)
  return out
end

function M.on_research_started(event)
  local r = root()
  if not r.enabled or setting_bool("tech-priests-enable-voice-barks-0530", true) == false then return false, "disabled" end
  local force = event and event.research and event.research.force or event and event.force or nil
  if not (force and force.valid) then return false, "no-force" end
  local tech_name = event and event.research and event.research.name or (force.current_research and force.current_research.name) or "unknown"
  local key = "tech:" .. tostring(force.name) .. ":" .. tostring(tech_name)
  local allowed = can_play(r, key, 60)
  if not allowed then return false, "tech-cooldown" end
  local pair = force_pairs(force)[1]
  local position, surface = nil, nil
  if pair and valid(pair.station) then position, surface = pair.station.position, pair.station.surface end
  local h = hash_string("technology|" .. tostring(force.name) .. "|" .. tostring(tech_name))
  local suffix = (math.floor(h / 256) % 3) == 0 and "-slow" or ((math.floor(h / 256) % 3) == 2 and "-fast" or "")
  local volume = (0.32 + ((math.floor(h / 65536) % 7) * 0.025)) * 1.10
  local ok, used = emit_via_sound_manager(pair, "technology_voice", tech_clip .. suffix, volume, key, 30, { source = "station", position = position, surface = surface, key = tech_name })
  if ok then
    stat("tech_played")
    r.last[#r.last + 1] = { tick = now(), event = "technology", tech = tech_name, clip = used or (tech_clip .. suffix), unit = pair and unit(pair) or 0 }
    while #r.last > 20 do table.remove(r.last, 1) end
  else
    stat("tech_failed")
  end
  return ok, used
end

function M.poll_current_research()
  local r = root()
  r.force_current_research = r.force_current_research or {}
  if not (game and game.forces) then return end
  for _, force in pairs(game.forces) do
    if force and force.valid then
      local tech = nil
      pcall(function() tech = force.current_research end)
      local name = tech and tech.name or nil
      local prev = r.force_current_research[force.name]
      if prev == nil then
        r.force_current_research[force.name] = name or false
      elseif prev ~= (name or false) then
        r.force_current_research[force.name] = name or false
        if name then M.on_research_started({ force = force, research = tech }) end
      end
    end
  end
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-conversation-voice-0530") end)
  commands.add_command("tp-conversation-voice-0530", "Tech Priests 0.1.530: voice-bark audio status/test. Usage: status|on|off|test-line|test-tech", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not player then return end
    local r = root()
    local p = tostring(event.parameter or "status")
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    local selected_pair = nil
    if player.selected and player.selected.valid then
      for _, pair in pairs(storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}) do
        if pair and (pair.station == player.selected or pair.priest == player.selected) then selected_pair = pair break end
      end
    end
    if p == "test-line" and selected_pair then
      M.on_line_started({ id = now(), pair = selected_pair, text = "Diagnostic canticle acknowledged.", channel = "diagnostic" })
    elseif p == "test-tech" then
      M.on_research_started({ force = player.force, research = player.force.current_research })
    end
    player.print("[tp-conversation-voice-0530] enabled=" .. tostring(r.enabled) .. " line_played=" .. tostring(r.stats.line_played or 0) .. " tech_played=" .. tostring(r.stats.tech_played or 0) .. " line_failed=" .. tostring(r.stats.line_failed or 0) .. " tech_failed=" .. tostring(r.stats.tech_failed or 0))
    local last = r.last[#r.last]
    if last then player.print("[tp-conversation-voice-0530] last event=" .. safe(last.event) .. " clip=" .. safe(last.clip) .. " school=" .. safe(last.school) .. " tech=" .. safe(last.tech) .. " tick=" .. safe(last.tick)) end
  end)
end

function M.install()
  root()
  if M._installed then return true end
  M._installed = true
  _G.tech_priests_conversation_voice_0530_on_line_started = function(line) return M.on_line_started(line) end
  if script and defines and defines.events and defines.events.on_research_started then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_started, function(event) M.on_research_started(event) end, { owner = "conversation_voice_0530", category = "audio" })
  end
  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(73, function() M.poll_current_research() end, { owner = "conversation_voice_0530", category = "audio" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(73, function() M.poll_current_research() end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.530] conversation voice bark audio installed") end
  return true
end

return M
