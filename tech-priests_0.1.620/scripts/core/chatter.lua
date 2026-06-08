-- scripts/core/chatter.lua
-- Tech Priests 0.1.334 background chatter doctrine.
-- Conversation is now a background visual/social layer, not an idle activity
-- owner. It must never change mining/crafting/movement/task state. Passive
-- chatter avoids working priests by default; direct player taps on a priest can
-- request a short line or a task-aware busy rejection.

local Chatter = {}
Chatter.version = "0.1.461"
local DoctrineChatter = require("scripts.core.doctrine_chatter")
local DoctrineArgument = require("scripts.core.doctrine_argument")
local DoctrineVisualStyles = require("scripts.core.doctrine_visual_styles")
Chatter.storage_key = "background_chatter_0334"
Chatter.default_interval = 240
Chatter.text_ttl = 135
Chatter.visibility_check_interval = 15
Chatter.pending_line_ttl = 60 * 20
Chatter.max_pairs_per_pulse = 24
Chatter.partner_radius_sq = 36 * 36
-- 0.1.412: background doctrine speech is paced like the older direct
-- conversation typewriter.  Argument lines may be queued in a burst by the
-- social logic, but this module now serializes their visible/chat output so the
-- player sees a back-and-forth exchange rather than a diagnostic wall.
Chatter.typewriter_ticks_per_char = 2
Chatter.typewriter_min_visible_chars = 1
Chatter.typewriter_hold_ticks = 75
Chatter.typewriter_gap_ticks = 45
Chatter.max_scheduled_line_ticks = 60 * 10

local function valid(e) return e and e.valid end
local line_key
local task_name

local function global_setting(name, default)
  if settings and settings.global and settings.global[name] then
    local v = settings.global[name].value
    if v ~= nil then return v end
  end
  return default
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Chatter.storage_key] = storage.tech_priests[Chatter.storage_key] or {
    version = Chatter.version,
    enabled = true,
    objects = {},
    next_tick = 0,
    stats = {},
    tap_cooldown_by_player = {},
    recent_lines = {},
    recent_pair_lines = {},
    recent_line_ledger = {},
    pending_lines = {},
    pending_next_id = 1
  }
  local root = storage.tech_priests[Chatter.storage_key]
  root.version = Chatter.version
  if root.enabled == nil then root.enabled = true end
  root.objects = root.objects or {}
  root.stats = root.stats or {}
  root.tap_cooldown_by_player = root.tap_cooldown_by_player or {}
  root.recent_lines = root.recent_lines or {}
  root.recent_pair_lines = root.recent_pair_lines or {}
  root.recent_line_ledger = root.recent_line_ledger or {}
  root.pending_lines = root.pending_lines or {}
  root.pending_next_id = root.pending_next_id or 1
  return root
end

local function destroy(obj)
  if not obj then return end
  pcall(function() if obj.valid then obj.destroy() end end)
end

local function clear_unit(root, unit)
  if not (root and unit) then return end
  destroy(root.objects[unit])
  root.objects[unit] = nil
end

local function pairs_by_station()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function unit(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil
end

local function pair_display_name(pair)
  if not pair then return "Unknown Tech-Priest" end
  return tostring(pair.priest_display_name or pair.cell_name or pair.station_display_name or (pair.priest and pair.priest.valid and pair.priest.localised_name) or (pair.priest and pair.priest.valid and pair.priest.name) or (pair.station and pair.station.valid and pair.station.localised_name) or "Tech-Priest")
end

local enqueue_visible_line

local function remember_conversation_key(root, pair, text, target_pair, direct_player, channel)
  if not (root and text) then return end
  root.recent_line_ledger = root.recent_line_ledger or {}
  local speaker_unit = unit(pair)
  local target_unit = target_pair and unit(target_pair) or nil
  local key = line_key and line_key(text) or tostring(text or "")
  local entry = {
    tick = game and game.tick or 0,
    key = key,
    speaker = pair_display_name(pair),
    speaker_unit = speaker_unit,
    target = target_pair and pair_display_name(target_pair) or (direct_player and direct_player.valid and direct_player.name) or "ambient",
    target_unit = target_unit,
    channel = channel or (target_pair and "priest-priest" or (direct_player and "priest-player" or "ambient"))
  }
  table.insert(root.recent_line_ledger, 1, entry)
  while #root.recent_line_ledger > 40 do table.remove(root.recent_line_ledger) end
end


local function safe_surface_name(entity)
  if entity and entity.valid and entity.surface then return tostring(entity.surface.name or entity.surface.index or "?") end
  return "?"
end

local function position_string(entity)
  if not (entity and entity.valid and entity.position) then return "x=?, y=?" end
  return "x=" .. tostring(math.floor((entity.position.x or 0) + 0.5)) .. ", y=" .. tostring(math.floor((entity.position.y or 0) + 0.5))
end

local function station_name(pair)
  if not pair then return "unknown station" end
  return tostring(pair.station_display_name or pair.cell_name or (pair.station and pair.station.valid and pair.station.localised_name) or (pair.station and pair.station.valid and pair.station.name) or "unknown station")
end

local function format_chat_log_line(pair, text, target_pair, direct_player, channel)
  -- 0.1.408: keep the player-facing chat line readable.  The prior diagnostic
  -- form included location, station, task, channel, font, color, camp, cadence,
  -- symbol-mix, and other style internals.  That was useful for development but
  -- turned doctrine arguments into a screen-wide wall of metadata.  Detailed
  -- style state remains available through doctrine/style commands and docs; the
  -- ambient conversation log now shows only the surface and who spoke to whom.
  local speaker = pair_display_name(pair)
  local recipient = target_pair and pair_display_name(target_pair) or (direct_player and direct_player.valid and direct_player.name) or "ambient"
  local surface = safe_surface_name(pair and pair.priest)
  return "[Tech-Priests chatter] surface=" .. surface
    .. " | " .. speaker .. " -> " .. recipient
    .. " :: " .. tostring(text)
end

local function print_chat_line(pair, text, target_pair, direct_player, channel, color, font)
  if not (pair and pair.priest and pair.priest.valid and text) then return false end
  local ok_root, root = pcall(ensure_root)
  if ok_root and root then return enqueue_visible_line(root, pair, text, target_pair, direct_player, channel, color, font) end
  return false
end

local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
  local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
  return dx * dx + dy * dy
end


local function station_radius(pair)
  if not pair then return 32 end
  if _G.refresh_pair_radius then
    local ok, radius = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(radius) then return tonumber(radius) end
  end
  return tonumber(pair.radius or pair.scan_radius or pair.station_radius) or 32
end

local function player_character(player)
  if _G.tech_priests_player_character_0181 then
    local ok, character = pcall(_G.tech_priests_player_character_0181, player)
    if ok then return character end
  end
  if player and player.valid and player.character and player.character.valid then return player.character end
  return nil
end

local function player_attention_blocked(player)
  if _G.tech_priests_player_is_attention_blocked_0181 then
    local ok, blocked = pcall(_G.tech_priests_player_is_attention_blocked_0181, player)
    if ok then return blocked end
  end
  if not (player and player.valid) then return true end
  local ok_opened, opened = pcall(function() return player.opened end)
  if ok_opened and opened ~= nil then return true end
  local ok_self, opened_self = pcall(function() return player.opened_self end)
  if ok_self and opened_self then return true end
  local ok_type, gui_type = pcall(function() return player.opened_gui_type end)
  if ok_type and gui_type then
    local none_type = nil
    pcall(function() none_type = defines.gui_type.none end)
    if none_type == nil or gui_type ~= none_type then return true end
  end
  return false
end

local function closest_witness_player(pair, target_pair)
  if not (game and pair and valid(pair.priest) and valid(pair.station)) then return nil end
  local radius = station_radius(pair)
  local radius_sq = radius * radius
  local best, best_d = nil, nil
  for _, player in pairs(game.connected_players or {}) do
    local character = player_character(player)
    if character and player.force == pair.priest.force and character.surface == pair.priest.surface then
      local ds = dist_sq(character.position, pair.station.position)
      local target_ok = true
      if target_pair and valid(target_pair.station) then
        local tr = station_radius(target_pair)
        target_ok = dist_sq(character.position, target_pair.station.position) <= (tr * tr)
      end
      if ds <= radius_sq and target_ok then
        local d = dist_sq(character.position, pair.priest.position)
        if not best_d or d < best_d then best, best_d = player, d end
      end
    end
  end
  return best, best_d
end

local function destroy_pending_render(line)
  if line and line.render_id then
    pcall(function()
      if line.render_id.valid then line.render_id.destroy() end
    end)
    line.render_id = nil
  end
end

local function typewriter_visible_text(text, started_tick)
  text = tostring(text or "...")
  local prefix, body = string.match(text, "^(%[[^%]]+%]%s*)(.*)$")
  if not prefix then
    prefix = ""
    body = text
  end
  local elapsed = math.max(0, ((game and game.tick) or 0) - (started_tick or ((game and game.tick) or 0)))
  local ticks_per_char = tonumber(Chatter.typewriter_ticks_per_char) or 2
  if ticks_per_char < 1 then ticks_per_char = 1 end
  local count = math.floor(elapsed / ticks_per_char)
  if count < (tonumber(Chatter.typewriter_min_visible_chars) or 1) then count = tonumber(Chatter.typewriter_min_visible_chars) or 1 end
  if count > #body then count = #body end
  return prefix .. string.sub(body, 1, count), count >= #body
end

local function scheduled_duration_for_text(text)
  text = tostring(text or "")
  local ticks_per_char = tonumber(Chatter.typewriter_ticks_per_char) or 2
  local hold = tonumber(Chatter.typewriter_hold_ticks) or 75
  local gap = tonumber(Chatter.typewriter_gap_ticks) or 45
  local raw = (#text * ticks_per_char) + hold + gap
  local minimum = 60 * 2
  local maximum = tonumber(Chatter.max_scheduled_line_ticks) or (60 * 10)
  if raw < minimum then raw = minimum end
  if maximum > 0 and raw > maximum then raw = maximum end
  return raw
end

local function reserve_speech_slot(root, text)
  local now_tick = (game and game.tick) or 0
  root.next_speech_tick_0408 = math.max(tonumber(root.next_speech_tick_0408) or now_tick, now_tick)
  local due = root.next_speech_tick_0408
  root.next_speech_tick_0408 = due + scheduled_duration_for_text(text)
  return due
end

local function draw_bubble_for_player(root, line)
  if not (root and line and rendering and rendering.draw_text) then return false end
  local pair = line.pair
  local player = line.player
  if not (pair and valid(pair.priest) and player and player.valid) then return false end
  local visible = line.visible_text or tostring(line.text or "")
  if line.last_drawn_visible_text == visible and line.render_id and line.render_id.valid then return true end
  destroy_pending_render(line)
  local ok, obj = pcall(function()
    return rendering.draw_text({
      surface = pair.priest.surface,
      target = { entity = pair.priest, offset = { 1.05, -0.82 } },
      text = tostring(visible),
      color = line.color or (DoctrineVisualStyles and DoctrineVisualStyles.color_for_pair and DoctrineVisualStyles.color_for_pair(pair)) or { r = 0.95, g = 0.82, b = 0.45, a = 0.94 },
      font = line.font or (DoctrineVisualStyles and DoctrineVisualStyles.font_for_pair and DoctrineVisualStyles.font_for_pair(pair)) or "default",
      scale = tonumber(line.scale) or 0.68,
      alignment = "left",
      time_to_live = math.max(tonumber(Chatter.visibility_check_interval) or 15, 15) + 45,
      players = { player }
    })
  end)
  if ok and obj then
    line.render_id = obj
    line.last_drawn_visible_text = visible
    return true
  end
  return false
end

enqueue_visible_line = function(root, pair, text, target_pair, direct_player, channel, color, font)
  if not (root and pair and valid(pair.priest) and text) then return false end
  local player = direct_player and direct_player.valid and direct_player or closest_witness_player(pair, target_pair)
  if not player then
    root.stats.no_witness_lines = (root.stats.no_witness_lines or 0) + 1
    return false
  end
  local id = root.pending_next_id or 1
  root.pending_next_id = id + 1
  root.pending_lines = root.pending_lines or {}
  local style = DoctrineVisualStyles and DoctrineVisualStyles.style_for_pair and DoctrineVisualStyles.style_for_pair(pair) or nil
  local safe_text = tostring(text)
  root.pending_lines[#root.pending_lines + 1] = {
    id = id,
    pair = pair,
    target_pair = target_pair,
    player = player,
    player_index = player.index,
    direct = direct_player ~= nil,
    text = safe_text,
    visible_text = "",
    channel = channel,
    color = color or (style and style.color),
    font = font or (style and style.font),
    doctrine_camp = style and style.camp or nil,
    doctrine_glyph_prefix = style and style.glyph_prefix or nil,
    created_tick = game and game.tick or 0,
    not_before_tick = reserve_speech_slot(root, safe_text),
    started_tick = nil,
    complete_tick = nil,
    printed = false,
    blocked_last_tick = nil,
    ttl = Chatter.text_ttl,
  }
  return true
end

function Chatter.process_pending_lines()
  local root = ensure_root()
  local now_tick = game and game.tick or 0
  local live = {}
  for _, line in ipairs(root.pending_lines or {}) do
    local pair = line.pair
    local target_pair = line.target_pair
    local player = line.player_index and game.get_player(line.player_index) or line.player
    line.player = player
    local expired = now_tick > (tonumber(line.created_tick) or now_tick) + Chatter.pending_line_ttl
    if expired or not (pair and valid(pair.priest) and player and player.valid) then
      destroy_pending_render(line)
    elseif now_tick < (tonumber(line.not_before_tick) or tonumber(line.created_tick) or now_tick) then
      -- Keep queued speech invisible until its scheduled turn.  This is the
      -- back-pressure that prevents a whole five-round argument from appearing
      -- in one frame.
      live[#live + 1] = line
    else
      local current_witness = (line.direct and player) or closest_witness_player(pair, target_pair)
      if not current_witness then
        destroy_pending_render(line)
        line.started_tick = nil
        live[#live + 1] = line
      elseif current_witness.index ~= player.index then
        destroy_pending_render(line)
        line.player = current_witness
        line.player_index = current_witness.index
        line.started_tick = nil
        live[#live + 1] = line
      elseif player_attention_blocked(player) then
        -- Same doctrine as the older direct-address typewriter: an opened GUI,
        -- inventory, machine interface, or other attention-blocking panel resets
        -- the display timer instead of letting the player miss the line.
        destroy_pending_render(line)
        line.started_tick = nil
        line.blocked_last_tick = now_tick
        live[#live + 1] = line
      else
        if not line.started_tick then
          line.started_tick = now_tick
          line.complete_tick = nil
          line.visible_text = ""
          line.last_drawn_visible_text = nil
          if _G.tech_priests_conversation_voice_0530_on_line_started then
            pcall(_G.tech_priests_conversation_voice_0530_on_line_started, line)
          end
        end
        local visible, complete = typewriter_visible_text(line.text, line.started_tick or now_tick)
        line.visible_text = visible
        draw_bubble_for_player(root, line)
        if complete and not line.complete_tick then
          line.complete_tick = now_tick
          -- 0.1.461: print to chat only after the visible typewriter line has
          -- finished.  The floating speech is now the primary utterance; the
          -- chat log becomes its archive, not a spoiler that fires first.
          if not line.printed then
            local out = format_chat_log_line(pair, line.text, target_pair, player, line.channel)
            pcall(function() player.print(out) end)
            remember_conversation_key(root, pair, line.text, target_pair, player, line.channel)
            line.printed = true
          end
        end
        local hold_until = (line.complete_tick or (now_tick + 1)) + (tonumber(Chatter.typewriter_hold_ticks) or 75)
        if not complete or now_tick < hold_until then
          live[#live + 1] = line
        else
          destroy_pending_render(line)
        end
      end
    end
  end
  root.pending_lines = live
end
task_name = function(pair)
  local mode = tostring(pair and pair.mode or "")
  local cur = pair and pair.emergency_craft and pair.emergency_craft.current or nil
  if cur then
    if cur.item_name then return "[item=" .. tostring(cur.item_name) .. "] acquiring " .. tostring(cur.item_name) end
    if cur.output_item then return "[item=" .. tostring(cur.output_item) .. "] acquiring " .. tostring(cur.output_item) end
    if cur.entity and cur.entity.valid then return "[entity=" .. tostring(cur.entity.name) .. "] harvesting " .. tostring(cur.entity.name) end
  end
  local craft = pair and pair.emergency_craft or nil
  if craft then
    local item = craft.output_item or craft.item_name or craft.item or nil
    if item then return "[item=" .. tostring(item) .. "] emergency doctrine for " .. tostring(item) end
  end
  local req = pair and pair.supply_request or pair and pair.active_supply_request or nil
  if req and req.item then return "[item=" .. tostring(req.item) .. "] supply request: " .. tostring(req.item) end
  if req and req.name then return "[item=" .. tostring(req.name) .. "] supply request: " .. tostring(req.name) end
  local writ = pair and (pair.priest_task_0323 or pair.active_writ_0323 or pair.current_writ)
  if writ then
    local item = writ.item or writ.name or writ.requested_item or writ.resource
    if item then return "[item=" .. tostring(item) .. "] assigned writ: " .. tostring(item) end
  end
  if mode:find("laser%-fallback", 1, false) then return "[item=stone] mining laser fallback / resource acquisition" end
  if mode:find("primitive%-resource%-doctrine", 1, false) or mode:find("acquisition%-doctrine", 1, false) then return "[item=iron-ore] primitive resource doctrine" end
  if mode:find("craft", 1, true) then return "[virtual-signal=signal-C] station crafting rite" end
  if mode:find("mine", 1, true) or mode:find("scavenge", 1, true) then return "[item=iron-ore] mining/scavenging" end
  if mode:find("repair", 1, true) then return "[item=repair-pack] repair service" end
  if mode:find("combat", 1, true) or mode:find("attack", 1, true) or mode:find("defend", 1, true) then return "[item=firearm-magazine] combat watch" end
  if mode:find("consecr", 1, true) or mode:find("sanct", 1, true) then return "[item=sacred-machine-oil] sanctification rite" end
  if mode ~= "" and mode ~= "idle" and mode ~= "nil" then return "state: " .. mode end
  return "idle / awaiting doctrine"
end

local function is_busy(pair)
  if not pair then return false end
  if _G.tech_priests_pair_has_real_work_0167 then
    local ok, busy = pcall(_G.tech_priests_pair_has_real_work_0167, pair)
    if ok and busy then return true end
  end
  local mode = tostring(pair.mode or "")
  if mode == "" or mode == "idle" or mode == "idle-scan" or mode == "idle-conversation" then
    if pair.emergency_craft and pair.emergency_craft.current then return true end
    if pair.supply_request or pair.active_supply_request or pair.priest_task_0323 or pair.active_writ_0323 then return true end
    return false
  end
  return true
end

local function chance_percent(seed, chance)
  chance = tonumber(chance) or 0
  if chance <= 0 then return false end
  if chance >= 100 then return true end
  local roll = math.abs((seed * 1103515245 + 12345) % 100)
  return roll < chance
end

local function line_cooldown_ticks()
  return tonumber(global_setting("tech-priests-background-chatter-line-cooldown-ticks", 7200)) or 7200
end

line_key = function(text)
  text = tostring(text or "")
  text = text:gsub("%[technology=[^%]]+%]", "[technology]")
  text = text:gsub("%[item=[^%]]+%]", "[item]")
  text = text:gsub("%s+", " ")
  return text
end

local function prune_recent_lines(root, now_tick)
  if not root then return end
  local cutoff = (now_tick or (game and game.tick) or 0)
  for k, until_tick in pairs(root.recent_lines or {}) do
    if tonumber(until_tick or 0) <= cutoff then root.recent_lines[k] = nil end
  end
end

local function is_recent_line(root, text)
  if not (root and text) then return false end
  local key = line_key(text)
  local until_tick = root.recent_lines and root.recent_lines[key] or nil
  return until_tick and until_tick > ((game and game.tick) or 0)
end

local function mark_line_used(root, text)
  if not (root and text) then return end
  local cd = line_cooldown_ticks()
  if cd <= 0 then return end
  root.recent_lines = root.recent_lines or {}
  root.recent_lines[line_key(text)] = ((game and game.tick) or 0) + cd
end

local function mark_dialogue_used(root, first, second)
  mark_line_used(root, first)
  mark_line_used(root, second)
end

local function normalize_rank_for_legacy(pair)
  if _G.tech_priests_get_pair_tier_name_0167 then
    local ok, rank = pcall(_G.tech_priests_get_pair_tier_name_0167, pair)
    if ok and rank then return tostring(rank) end
  end
  local raw = pair and (pair.tier or pair.rank_key) or "junior"
  raw = tostring(raw or "junior")
  if raw == "planetary-magos" or raw == "void" then return "senior" end
  if raw == "intermediate" or raw == "senior" or raw == "junior" then return raw end
  return "junior"
end

local function format_legacy_line(line, tech_name)
  if _G.tech_priests_format_conversation_line_0167 then
    local ok, out = pcall(_G.tech_priests_format_conversation_line_0167, line, tech_name)
    if ok and out then return tostring(out) end
  end
  local icon = tech_name and tech_name ~= "" and ("[technology=" .. tostring(tech_name) .. "]") or ""
  line = tostring(line or "...")
  line = line:gsub("__TECH_ICON__", icon)
  line = line:gsub("__TECH__", tostring(tech_name or "an unidentified doctrine"))
  return line
end

local function current_legacy_topic(pair)
  local force = pair and pair.station and pair.station.valid and pair.station.force or nil
  if _G.tech_priests_get_conversation_topic_for_force_0167 then
    local ok, topic, tech_name = pcall(_G.tech_priests_get_conversation_topic_for_force_0167, force)
    if ok then return topic, tech_name end
  end
  return rawget(_G, "TECH_PRIESTS_DEFAULT_CONVERSATION_TOPIC_0167") or "cogitator-station-deployment", nil
end

local function legacy_pool_for(pair, partner)
  local topics = rawget(_G, "TECH_PRIESTS_CONVERSATION_LINES_0167") or {}
  local responses = rawget(_G, "TECH_PRIESTS_CONVERSATION_RESPONSES_0167") or {}
  local topic, tech_name = current_legacy_topic(pair)
  local topic_table = topics[topic] or topics[rawget(_G, "TECH_PRIESTS_FALLBACK_UNKNOWN_TECH_TOPIC_0167") or "__fallback_unknown_technology__"] or nil
  local speaker_rank = normalize_rank_for_legacy(pair)
  local listener_rank = normalize_rank_for_legacy(partner)
  local branch = topic_table and topic_table[speaker_rank] and topic_table[speaker_rank][listener_rank] or nil
  local response_branch = responses[listener_rank] or responses.junior or nil
  return branch or {}, response_branch or {}, tech_name
end

local function choose_nonrecent(root, lines, seed, tech_name)
  if type(lines) ~= "table" or #lines == 0 then return nil end
  local count = #lines
  local fallback = nil
  for i = 1, count do
    local idx = (((seed or 0) + i - 1) % count) + 1
    local line = format_legacy_line(lines[idx], tech_name)
    if not fallback then fallback = line end
    if not is_recent_line(root, line) then return line end
  end
  return fallback
end

local function choose_legacy_dialogue(root, pair, partner, seed)
  -- Prefer the historical researched-doctrine chooser because it already knows
  -- the last researched topic, rank pairing, and technology icon formatting.
  if _G.tech_priests_choose_conversation_lines_0167 then
    for i = 0, 5 do
      local ok, chosen = pcall(_G.tech_priests_choose_conversation_lines_0167, pair, partner)
      if ok and type(chosen) == "table" and chosen.speaker_line and chosen.response_line then
        local a, b = tostring(chosen.speaker_line), tostring(chosen.response_line)
        if not is_recent_line(root, a) and not is_recent_line(root, b) then
          return a, b, chosen.topic or "legacy"
        end
      end
    end
  end
  local speaker_lines, response_lines, tech_name = legacy_pool_for(pair, partner)
  local a = choose_nonrecent(root, speaker_lines, seed or 0, tech_name)
  local b = choose_nonrecent(root, response_lines, (seed or 0) + 11, tech_name)
  return a, b, "legacy-pool"
end

local function choose_fallback_line(root, lines, seed)
  if type(lines) ~= "table" or #lines == 0 then return "..." end
  local count = #lines
  local fallback = nil
  for i = 1, count do
    local idx = (((seed or 0) + i - 1) % count) + 1
    local line = tostring(lines[idx] or "...")
    if not fallback then fallback = line end
    if not is_recent_line(root, line) then return line end
  end
  return fallback or "..."
end

local function draw_bubble(root, pair, text, color)
  -- 0.1.372: speech bubbles are emitted through the visibility-aware line
  -- queue in print_chat_line so that chat and world text share the same
  -- closest-player / GUI-blocked / restart-timer discipline.  This helper is
  -- retained for older call sites and only reports whether a witness exists.
  return closest_witness_player(pair) ~= nil
end

local openers = {
  "Binary canticle acknowledged?",
  "Report machine-spirit temperament.",
  "Your station hums off-key.",
  "Have you appeased the local gear-train?",
  "Doctrine check: work before reverie.",
  "Resource omens remain impure.",
  "I request a brief exchange of blessed noise."
}

local replies = {
  "Acknowledged.",
  "The rite proceeds.",
  "I have seen worse. Recently.",
  "Machine spirits remain judgemental.",
  "Your datum is accepted under protest.",
  "Praise the Omnissiah, continue labor."
}

local busy_replies = {
  "Busy: %s",
  "Not now: %s",
  "Writ active: %s",
  "Denied. Hands occupied: %s",
  "Later. Current rite: %s"
}

local function find_partner(pair, list)
  if not (pair and valid(pair.priest)) then return nil end
  local best, best_d = nil, nil
  for _, other in pairs(list) do
    if other ~= pair and valid(other.priest) and valid(other.station)
      and other.priest.force == pair.priest.force
      and other.priest.surface == pair.priest.surface then
      local d = dist_sq(pair.priest.position, other.priest.position)
      if d <= Chatter.partner_radius_sq and (not best_d or d < best_d) then
        best, best_d = other, d
      end
    end
  end
  return best
end

local function find_pair_by_priest(entity)
  if not valid(entity) then return nil end
  for _, pair in pairs(pairs_by_station()) do
    if pair and pair.priest and pair.priest.valid and pair.priest == entity then return pair end
    if pair and pair.priest and pair.priest.valid and entity.unit_number and pair.priest.unit_number == entity.unit_number then return pair end
  end
  return nil
end

local function looks_like_priest_entity(entity)
  if not valid(entity) then return false end
  local n = tostring(entity.name or "")
  return n:find("tech%-priest", 1, false) ~= nil or n:find("magos%-tech%-priest", 1, false) ~= nil
end

function Chatter.direct_tap(player, entity)
  local root = ensure_root()
  if not root.enabled then return false end
  if not (player and player.valid and valid(entity) and looks_like_priest_entity(entity)) then return false end
  local cooldown = tonumber(global_setting("tech-priests-direct-priest-tap-chatter-cooldown-ticks", 120)) or 120
  local now_tick = game and game.tick or 0
  local last = root.tap_cooldown_by_player[player.index] or 0
  if now_tick - last < cooldown then return false end
  root.tap_cooldown_by_player[player.index] = now_tick

  local pair = find_pair_by_priest(entity)
  if not pair then return false end
  local seed = now_tick + (unit(pair) or 0) * 41 + player.index
  if is_busy(pair) then
    local icon = task_name(pair)
    local msg = string.format(busy_replies[(seed % #busy_replies) + 1], icon)
    draw_bubble(root, pair, msg, { r = 1.0, g = 0.66, b = 0.28, a = 0.96 })
    print_chat_line(pair, msg, nil, player)
    mark_line_used(root, msg)
    root.stats.direct_busy_rejections = (root.stats.direct_busy_rejections or 0) + 1
    return true
  end
  local msg = nil
  local legacy_line = nil
  legacy_line = select(1, choose_legacy_dialogue(root, pair, nil, seed))
  msg = legacy_line or choose_fallback_line(root, replies, seed)
  draw_bubble(root, pair, msg, { r = 0.78, g = 0.92, b = 1.0, a = 0.94 })
  print_chat_line(pair, msg, nil, player)
  mark_line_used(root, msg)
  root.stats.direct_taps = (root.stats.direct_taps or 0) + 1
  return true
end

function Chatter.pulse()
  local root = ensure_root()
  root.enabled = global_setting("tech-priests-enable-background-chatter", true)
  Chatter.process_pending_lines()
  if not root.enabled then return end

  prune_recent_lines(root, game and game.tick or 0)
  local chance = tonumber(global_setting("tech-priests-background-chatter-chance-percent", 5)) or 5
  local busy_reject = tonumber(global_setting("tech-priests-background-chatter-busy-reject-percent", 85)) or 85
  local passive_busy = global_setting("tech-priests-background-chatter-allow-passive-busy-rejection", false)
  if chance <= 0 then return end

  local list = {}
  for _, pair in pairs(pairs_by_station()) do
    if pair and valid(pair.station) and valid(pair.priest) then list[#list + 1] = pair end
  end
  table.sort(list, function(a, b) return (unit(a) or 0) < (unit(b) or 0) end)

  local processed = 0
  for _, pair in ipairs(list) do
    processed = processed + 1
    if processed > Chatter.max_pairs_per_pulse then break end
    -- Background chatter is non-invasive. If the initiating priest is busy, do
    -- not make it talk. That prevents chatter from visually masking stalled work
    -- and keeps mining/crafting doctrine clean.
    if not is_busy(pair) and closest_witness_player(pair) then
      local u = unit(pair) or 0
      local seed = (game and game.tick or 0) + u * 37
      if chance_percent(seed, chance) then
        local partner = find_partner(pair, list)
        if partner and closest_witness_player(pair, partner) and closest_witness_player(partner, pair) then
          local partner_busy = is_busy(partner)
          if partner_busy and passive_busy and chance_percent(seed + 17, busy_reject) then
            local icon = task_name(partner)
            local msg = string.format(busy_replies[(seed % #busy_replies) + 1], icon)
            draw_bubble(root, partner, msg, { r = 1.0, g = 0.66, b = 0.28, a = 0.95 })
            print_chat_line(partner, msg, pair, nil)
            if _G.tech_priests_0412_note_priest_conversation then
              pcall(_G.tech_priests_0412_note_priest_conversation, partner, pair, "busy_rejection", msg, msg)
            end
            mark_line_used(root, msg)
            root.stats.busy_rejections = (root.stats.busy_rejections or 0) + 1
          elseif not partner_busy then
            local argument_started = false
            local argument_chance = tonumber(global_setting("tech-priests-doctrine-argument-chance-percent", 12)) or 12
            if DoctrineArgument and DoctrineArgument.start_argument and chance_percent(seed + 47, argument_chance) then
              local ok_arg, started = pcall(DoctrineArgument.start_argument, pair, partner, seed + 47, "background doctrine argument")
              argument_started = ok_arg and started or false
              if argument_started then
                root.stats.doctrine_arguments = (root.stats.doctrine_arguments or 0) + 1
                root.stats.last_topic = "doctrine-argument"
              end
            end
            if not argument_started then
              local opener, reply, topic = nil, nil, nil
              local doctrine_chance = tonumber(global_setting("tech-priests-doctrine-chatter-chance-percent", 45)) or 45
              if DoctrineChatter and DoctrineChatter.choose_dialogue and chance_percent(seed + 31, doctrine_chance) then
                local ok_doc, doc_a, doc_b, meta = pcall(DoctrineChatter.choose_dialogue, pair, partner, seed)
                if ok_doc and doc_a and doc_b then
                  opener, reply = tostring(doc_a), tostring(doc_b)
                  topic = meta and meta.topic or "doctrine"
                  root.stats.doctrine_chatter_lines = (root.stats.doctrine_chatter_lines or 0) + 2
                  root.stats.last_doctrine_relation = meta and meta.relation or root.stats.last_doctrine_relation
                end
              end
              if not (opener and reply) then
                opener, reply, topic = choose_legacy_dialogue(root, pair, partner, seed)
              end
              opener = opener or choose_fallback_line(root, openers, seed)
              reply = reply or choose_fallback_line(root, replies, seed + 3)
              draw_bubble(root, pair, opener, { r = 0.95, g = 0.82, b = 0.45, a = 0.94 })
              draw_bubble(root, partner, reply, { r = 0.78, g = 0.92, b = 1.0, a = 0.94 })
              print_chat_line(pair, opener, partner, nil, topic and ("priest-priest/" .. tostring(topic)) or "priest-priest")
              print_chat_line(partner, reply, pair, nil, topic and ("priest-priest/" .. tostring(topic)) or "priest-priest")
              if _G.tech_priests_0412_note_priest_conversation then
                local kind = tostring(topic or "passive_conversation")
                if kind == "doctrine" then kind = "passive_conversation" end
                pcall(_G.tech_priests_0412_note_priest_conversation, pair, partner, kind, opener, opener)
                pcall(_G.tech_priests_0412_note_priest_conversation, partner, pair, kind, reply, reply)
              end
              mark_dialogue_used(root, opener, reply)
              root.stats.last_topic = topic or root.stats.last_topic
              root.stats.chatter_lines = (root.stats.chatter_lines or 0) + 2
            end
          end
        end
      end
    end
  end
end

function Chatter.recent_conversation_keys_for_pair(pair, limit)
  local root = ensure_root()
  local out = {}
  local u = unit(pair)
  limit = tonumber(limit) or 5
  for _, entry in ipairs(root.recent_line_ledger or {}) do
    if (not u) or entry.speaker_unit == u or entry.target_unit == u then
      out[#out + 1] = entry
      if #out >= limit then break end
    end
  end
  return out
end

function Chatter.remember_external_conversation_key(pair, text, target_pair, channel)
  local root = ensure_root()
  remember_conversation_key(root, pair, text, target_pair, nil, channel or "external")
end

function Chatter.work_audit(player)
  if not (player and player.valid) then return end
  local total, busy, work_flags = 0, 0, {}
  for _, pair in pairs(pairs_by_station()) do
    if pair and valid(pair.station) and valid(pair.priest) and pair.station.force == player.force then
      total = total + 1
      local b = is_busy(pair)
      if b then busy = busy + 1 end
      local name = pair.priest.localised_name or pair.priest.name
      local mode = tostring(pair.mode or "?")
      local icon = task_name(pair)
      work_flags[#work_flags + 1] = tostring(name) .. " mode=" .. mode .. " busy=" .. tostring(b) .. " task=" .. icon
      if #work_flags >= 6 then break end
    end
  end
  player.print("[Tech Priests 0.1.334] work audit: pairs=" .. total .. " busy=" .. busy .. " chatter-mutates-work=false")
  for _, line in ipairs(work_flags) do player.print("  " .. line) end
end

function Chatter.catalog(player)
  if not (player and player.valid) then return end
  local topics = rawget(_G, "TECH_PRIESTS_CONVERSATION_LINES_0167") or {}
  local responses = rawget(_G, "TECH_PRIESTS_CONVERSATION_RESPONSES_0167") or {}
  local topic_count, line_count = 0, 0
  for _, lines in pairs(topics) do
    topic_count = topic_count + 1
    if type(lines) == "table" then
      line_count = line_count + #(lines.speaker or lines.speaker_lines or lines.lines or lines)
    end
  end
  local response_groups, response_count = 0, 0
  for _, lines in pairs(responses) do
    response_groups = response_groups + 1
    if type(lines) == "table" then response_count = response_count + #lines end
  end
  player.print("[Tech Priests 0.1.334] conversation catalog: legacy topics=" .. tostring(topic_count) .. " approx-lines=" .. tostring(line_count) .. " response-groups=" .. tostring(response_groups) .. " responses=" .. tostring(response_count) .. " chatter-openers=" .. tostring(#openers) .. " chatter-replies=" .. tostring(#replies) .. " busy-replies=" .. tostring(#busy_replies) .. " doctrine-module=" .. tostring(DoctrineChatter and DoctrineChatter.version or "missing"))
  local shown = 0
  for topic, _ in pairs(topics) do
    shown = shown + 1
    if shown <= 10 then player.print("  legacy topic: " .. tostring(topic)) end
  end
  if shown > 10 then player.print("  …" .. tostring(shown - 10) .. " more legacy topics available") end
end

function Chatter.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-chatter-0334", "Tech Priests: report/toggle/pulse/tap/audit/catalog 0.1.334 background chatter.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      if p == "pulse" then Chatter.pulse() end
      if p == "tap" then Chatter.direct_tap(player, player.selected) end
      if p == "audit" then Chatter.work_audit(player) end
      if p == "catalog" then Chatter.catalog(player) end
      player.print("[Tech Priests 0.1.334] background chatter enabled=" .. tostring(root.enabled) .. " lines=" .. tostring(root.stats.chatter_lines or 0) .. " passive-busy-rejections=" .. tostring(root.stats.busy_rejections or 0) .. " direct-taps=" .. tostring(root.stats.direct_taps or 0) .. " direct-busy=" .. tostring(root.stats.direct_busy_rejections or 0) .. " chance=" .. tostring(global_setting("tech-priests-background-chatter-chance-percent", 5)) .. "% line-cooldown=" .. tostring(line_cooldown_ticks()) .. " recent-lines=" .. tostring((function() local n=0 for _ in pairs(root.recent_lines or {}) do n=n+1 end return n end)()) .. " last-topic=" .. tostring(root.stats.last_topic or "?") .. " doctrine-lines=" .. tostring(root.stats.doctrine_chatter_lines or 0) .. " last-doctrine-relation=" .. tostring(root.stats.last_doctrine_relation or "?") .. " doctrine-arguments=" .. tostring(root.stats.doctrine_arguments or 0) .. " passive-busy=" .. tostring(global_setting("tech-priests-background-chatter-allow-passive-busy-rejection", false)))
    end)
  end)
end

function Chatter.install_selection_tap_hook()
  if not (script and defines and defines.events and script.on_event and defines.events.on_selected_entity_changed) then return end
  if _G.TECH_PRIESTS_0332_PRE_ON_SELECTED_ENTITY_CHANGED then return end
  _G.TECH_PRIESTS_0332_PRE_ON_SELECTED_ENTITY_CHANGED = _G.on_selected_entity_changed
  _G.on_selected_entity_changed = function(event)
    if _G.TECH_PRIESTS_0332_PRE_ON_SELECTED_ENTITY_CHANGED then
      pcall(_G.TECH_PRIESTS_0332_PRE_ON_SELECTED_ENTITY_CHANGED, event)
    end
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if player and player.selected then Chatter.direct_tap(player, player.selected) end
  end
  script.on_event(defines.events.on_selected_entity_changed, _G.on_selected_entity_changed)
end

function Chatter.install()
  ensure_root()
  if Chatter._installed then return true end
  Chatter._installed = true
  if script and script.on_nth_tick then
    script.on_nth_tick(tonumber(global_setting("tech-priests-background-chatter-interval-ticks", Chatter.default_interval)) or Chatter.default_interval, function() Chatter.pulse() end)
    script.on_nth_tick(Chatter.visibility_check_interval, function() Chatter.process_pending_lines() end)
  end
  Chatter.install_selection_tap_hook()
  Chatter.register_commands()
  _G.tech_priests_0334_recent_conversation_keys_for_pair = Chatter.recent_conversation_keys_for_pair
  _G.tech_priests_0369_doctrine_chatter = DoctrineChatter
  _G.tech_priests_0334_remember_external_conversation_key = Chatter.remember_external_conversation_key
  _G.tech_priests_0334_visible_player_for_pair = closest_witness_player
  _G.tech_priests_0334_format_conversation_chat_line = format_chat_log_line
  _G.tech_priests_0334_queue_visible_line = function(pair, text, target_pair, channel, color, font) local root = ensure_root(); return enqueue_visible_line(root, pair, text, target_pair, nil, channel, color, font) end
  if log then log("[Tech-Priests 0.1.461] background chatter module installed; chat archive prints after typewriter speech completes") end
  return true
end

return Chatter
