-- Auto-split control.lua fragment 009 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_cancel_conversation_approach_0180(pair, listener_pair)
  if listener_pair then
    listener_pair.idle_conversation_approach_listener_until_0180 = nil
    listener_pair.idle_conversation_approach_speaker_station_unit_0180 = nil
    if not tech_priests_pair_has_real_work_0167(listener_pair) then listener_pair.mode = "idle" end
  end
  if pair then
    pair.idle_conversation_approach_0180 = nil
    if not tech_priests_pair_has_real_work_0167(pair) then pair.mode = "idle" end
  end
  tech_priests_clear_conversation_approach_pair_0180(pair, listener_pair)
end

-- Partner search now again allows priests inside the station operating radius,
-- but the conversation itself will not start until the two priests have walked
-- into close speaking range.
function tech_priests_find_nearest_idle_conversation_partner_0167(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return nil end
  ensure_storage()
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local best = nil
  local best_dist = nil
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= pair and tech_priests_is_pair_available_for_idle_conversation_0167(other, true) then
      if other.station and other.station.valid and other.priest and other.priest.valid and other.station.force == station.force and other.station.surface == station.surface then
        local dxs = other.station.position.x - station.position.x
        local dys = other.station.position.y - station.position.y
        local station_dist = dxs * dxs + dys * dys
        if station_dist <= radius * radius then
          local dx = other.priest.position.x - pair.priest.position.x
          local dy = other.priest.position.y - pair.priest.position.y
          local dist = dx * dx + dy * dy
          if dist <= radius * radius then
            if not best_dist or dist < best_dist then
              best = other
              best_dist = dist
            end
          end
        end
      end
    end
  end
  return best, best_dist
end

tech_priests_original_start_idle_conversation_0180 = tech_priests_start_idle_conversation_0167
function tech_priests_start_idle_conversation_0167(pair, listener_pair)
  if not (pair and listener_pair and pair.priest and pair.priest.valid and listener_pair.priest and listener_pair.priest.valid) then return false end
  local dx = pair.priest.position.x - listener_pair.priest.position.x
  local dy = pair.priest.position.y - listener_pair.priest.position.y
  local dist = dx * dx + dy * dy
  if dist > TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_DISTANCE_SQ_0180 then
    pair.idle_conversation_approach_0180 = {
      listener_station_unit = listener_pair.station_unit or listener_pair.station.unit_number,
      started_tick = game.tick,
      due_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_TIMEOUT_TICKS_0180
    }
    pair.next_idle_conversation_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_COOLDOWN_TICKS_0167
    listener_pair.next_idle_conversation_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_COOLDOWN_TICKS_0167
    listener_pair.idle_conversation_approach_listener_until_0180 = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_TIMEOUT_TICKS_0180
    listener_pair.idle_conversation_approach_speaker_station_unit_0180 = pair.station_unit or pair.station.unit_number
    pair.mode = "idle-conversation"
    listener_pair.mode = "idle-conversation"
    pair.target = nil
    listener_pair.target = nil
    if stop_idle_scan then stop_idle_scan(pair) stop_idle_scan(listener_pair) end
    tech_priests_command_conversation_approach_0180(pair, listener_pair, true)
    return true
  end
  tech_priests_clear_conversation_approach_pair_0180(pair, listener_pair)
  return tech_priests_original_start_idle_conversation_0180(pair, listener_pair)
end

tech_priests_original_stop_idle_conversation_0180 = tech_priests_stop_idle_conversation_0167
function tech_priests_stop_idle_conversation_0167(pair)
  local listener_pair = nil
  if pair and pair.idle_conversation and pair.idle_conversation.listener_station_unit then
    listener_pair = tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation.listener_station_unit)
  elseif pair and pair.idle_conversation_approach_0180 and pair.idle_conversation_approach_0180.listener_station_unit then
    listener_pair = tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation_approach_0180.listener_station_unit)
  end
  tech_priests_clear_conversation_approach_pair_0180(pair, listener_pair)
  tech_priests_original_stop_idle_conversation_0180(pair)
end

function tech_priests_update_conversation_approach_0180(pair)
  if not (pair and pair.idle_conversation_approach_0180) then return false end
  local approach = pair.idle_conversation_approach_0180
  local listener_pair = tech_priests_get_pair_by_station_unit_0179(approach.listener_station_unit)
  if not (pair.priest and pair.priest.valid and listener_pair and listener_pair.priest and listener_pair.priest.valid) then
    tech_priests_cancel_conversation_approach_0180(pair, listener_pair)
    return false
  end
  if tech_priests_pair_has_real_work_0167(pair) or tech_priests_pair_has_real_work_0167(listener_pair) then
    tech_priests_cancel_conversation_approach_0180(pair, listener_pair)
    return false
  end
  if game.tick >= (approach.due_tick or 0) then
    tech_priests_cancel_conversation_approach_0180(pair, listener_pair)
    return false
  end
  local dx = pair.priest.position.x - listener_pair.priest.position.x
  local dy = pair.priest.position.y - listener_pair.priest.position.y
  if dx * dx + dy * dy <= TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_DISTANCE_SQ_0180 then
    tech_priests_clear_conversation_approach_pair_0180(pair, listener_pair)
    return tech_priests_original_start_idle_conversation_0180(pair, listener_pair)
  end
  pair.mode = "idle-conversation"
  listener_pair.mode = "idle-conversation"
  tech_priests_command_conversation_approach_0180(pair, listener_pair, false)
  return true
end

-- Replace the 0.1.169/0.1.179 conversation update with one that understands
-- the approach phase and holds completed text for at least five seconds.
function update_idle_conversation_behavior(pair)
  if not pair then return false end

  if pair.idle_conversation_approach_0180 then
    return tech_priests_update_conversation_approach_0180(pair)
  end

  if pair.idle_conversation_approach_listener_until_0180 and game.tick < pair.idle_conversation_approach_listener_until_0180 then
    local speaker_pair = pair.idle_conversation_approach_speaker_station_unit_0180 and tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation_approach_speaker_station_unit_0180) or nil
    if speaker_pair and speaker_pair.idle_conversation_approach_0180 then
      pair.mode = "idle-conversation"
      return true
    end
    tech_priests_clear_conversation_approach_0180(pair)
  elseif pair.idle_conversation_approach_listener_until_0180 then
    tech_priests_clear_conversation_approach_0180(pair)
  end

  if pair.idle_conversation then
    local convo = pair.idle_conversation
    local listener_pair = tech_priests_get_pair_by_station_unit_0179(convo.listener_station_unit)
    if not (pair.priest and pair.priest.valid and listener_pair and listener_pair.priest and listener_pair.priest.valid) then
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end
    if tech_priests_pair_has_real_work_0167(pair) or tech_priests_pair_has_real_work_0167(listener_pair) then
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end
    if game.tick >= (convo.due_tick or 0) then
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end

    tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair)

    local line = convo.phase == 1 and convo.speaker_line or convo.response_line
    local visible, complete = tech_priests_visible_typewriter_line_0169(line, convo.phase_started_tick or game.tick)
    if convo.phase == 1 then
      tech_priests_draw_idle_conversation_text_0167(pair, visible, false)
      tech_priests_clear_idle_conversation_text_0167(listener_pair)
    else
      tech_priests_draw_idle_conversation_text_0167(listener_pair, visible, true)
      tech_priests_clear_idle_conversation_text_0167(pair)
    end

    if complete and not convo.phase_complete_tick then
      convo.phase_complete_tick = game.tick
    end
    if complete and convo.phase_complete_tick and game.tick >= convo.phase_complete_tick + TECH_PRIESTS_IDLE_CONVERSATION_COMPLETE_HOLD_TICKS_0180 then
      if convo.phase == 1 then
        convo.phase = 2
      else
        convo.phase = 1
      end
      convo.phase_started_tick = game.tick
      convo.phase_complete_tick = nil
      convo.next_line_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_LINE_TICKS_0167
    end

    pair.mode = "idle-conversation"
    listener_pair.mode = "idle-conversation"
    return true
  end

  if pair.idle_conversation_listener_until and game.tick < pair.idle_conversation_listener_until then
    if tech_priests_pair_has_real_work_0167(pair) then
      pair.idle_conversation_listener_until = nil
      pair.idle_conversation_speaker_station_unit = nil
      tech_priests_clear_idle_conversation_text_0167(pair)
      tech_priests_clear_conversation_lock_0179(pair)
      return false
    end
    local speaker_pair = pair.idle_conversation_speaker_station_unit and tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation_speaker_station_unit) or nil
    if speaker_pair and speaker_pair.idle_conversation then
      tech_priests_hard_lock_conversation_priest_0179(pair)
    end
    pair.mode = "idle-conversation"
    return true
  elseif pair.idle_conversation_listener_until then
    pair.idle_conversation_listener_until = nil
    pair.idle_conversation_speaker_station_unit = nil
    tech_priests_clear_idle_conversation_text_0167(pair)
    tech_priests_clear_conversation_lock_0179(pair)
  end

  if not tech_priests_is_pair_available_for_idle_conversation_0167(pair, false) then return false end
  pair.next_idle_conversation_attempt_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_ATTEMPT_TICKS_0167 + ((pair.station_unit or 0) % 90)
  local chance = tonumber(settings.global["tech-priests-idle-conversation-chance-percent"] and settings.global["tech-priests-idle-conversation-chance-percent"].value) or 18
  if chance <= 0 then return false end
  local roll = ((game.tick + (pair.station_unit or 0) * 31) % 100)
  if roll >= chance then return false end
  local partner = tech_priests_find_nearest_idle_conversation_partner_0167(pair)
  if not partner then return false end
  return tech_priests_start_idle_conversation_0167(pair, partner)
end

-- Final wrapper after 0.1.180: conversation approaches and active hard-locks must
-- preempt ordinary behavior before new repair/search/return commands are issued.
tech_priests_original_tick_pair_0180 = tick_pair
function tick_pair(pair)
  if pair and (tech_priests_pair_is_conversation_locked_0179(pair) or tech_priests_pair_is_conversation_approaching_0180(pair)) then
    if update_idle_conversation_behavior(pair) then return true end
  end
  return tech_priests_original_tick_pair_0180(pair)
end


-- 0.1.181 player-attention conversation pass:
-- Direct player address now uses the same approach-then-freeze discipline as
-- Tech-Priest-to-Tech-Priest conversations. If the addressed player has a GUI,
-- inventory, machine interface, or other opened object active, the priest waits
-- close by and occasionally emits a polite cough. If the player opens a GUI
-- while typewriter text is already printing, the line is interrupted and later
-- restarts from the beginning once the player can see the world again.
TECH_PRIESTS_PLAYER_CONVERSATION_START_DISTANCE_SQ_0181 = 2.89 -- about 1.7 tiles
TECH_PRIESTS_PLAYER_CONVERSATION_REAPPROACH_DISTANCE_SQ_0181 = 16.0 -- player walked away; approach again
TECH_PRIESTS_PLAYER_CONVERSATION_APPROACH_TIMEOUT_TICKS_0181 = 60 * 15
TECH_PRIESTS_PLAYER_CONVERSATION_MAX_WAIT_TICKS_0181 = 60 * 90
TECH_PRIESTS_PLAYER_CONVERSATION_Cough_TICKS_0181 = 60 * 6
TECH_PRIESTS_PLAYER_CONVERSATION_ATTEMPT_TICKS_0181 = 60 * 20
TECH_PRIESTS_PLAYER_CONVERSATION_RENDER_TTL_0181 = 60 * 6

if TECH_PRIESTS_TASK_SOUND_CANDIDATES_0177 then
  TECH_PRIESTS_TASK_SOUND_CANDIDATES_0177.polite_cough = { "utility/console_message", "utility/cannot_build", "utility/confirm" }
end

function tech_priests_pair_has_player_conversation_0181(pair)
  return pair and pair.idle_player_conversation_0181 ~= nil
end

tech_priests_original_pair_is_conversation_approaching_0181 = tech_priests_pair_is_conversation_approaching_0180
function tech_priests_pair_is_conversation_approaching_0180(pair)
  if tech_priests_pair_has_player_conversation_0181(pair) then return true end
  if tech_priests_original_pair_is_conversation_approaching_0181 then
    return tech_priests_original_pair_is_conversation_approaching_0181(pair)
  end
  return false
end

function tech_priests_player_character_0181(player)
  if player and player.valid and player.character and player.character.valid then return player.character end
  return nil
end

function tech_priests_player_is_attention_blocked_0181(player)
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

function tech_priests_nearest_player_for_direct_address_0181(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return nil, nil end
  tech_priests_ensure_player_awareness_storage_0170()
  local force = pair.priest.force
  local surface = pair.priest.surface
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or 32
  local radius_sq = radius * radius
  local best_player = nil
  local best_context = nil
  local best_dist = nil
  for _, player in pairs(game.connected_players) do
    local character = tech_priests_player_character_0181(player)
    if character and player.force == force and player.surface == surface then
      local dxs = character.position.x - pair.station.position.x
      local dys = character.position.y - pair.station.position.y
      local station_dist = dxs * dxs + dys * dys
      if station_dist <= radius_sq then
        local dx = character.position.x - pair.priest.position.x
        local dy = character.position.y - pair.priest.position.y
        local dist = dx * dx + dy * dy
        if not best_dist or dist < best_dist then
          best_player = player
          best_context = storage.tech_priests.last_player_context_by_player[player.index]
          best_dist = dist
        end
      end
    end
  end
  return best_player, best_context
end

function tech_priests_build_direct_player_line_0181(pair, player, context)
  local address = tech_priests_format_player_address_0170(player)
  local rank = get_pair_rank and get_pair_rank(pair) or "junior"
  local ctx = tech_priests_build_player_topic_context_0170(pair, player, context)
  if ctx.tone == "condemnation" then
    if rank == "senior" then
      return address .. ", " .. (ctx.entity_icon ~= "" and ctx.entity_icon or "the recent machine") .. " shows damage with the confidence of neglected doctrine. Shall I file this under experiment, optimism, or heresy?"
    elseif rank == "intermediate" then
      return address .. ", the observed machinery appears wounded. Permission to become professionally worried?"
    end
    return address .. ", damage observed. I am being brave about it."
  end
  if ctx.current_research then
    if rank == "senior" then
      return ctx.tech_icon .. " " .. address .. ", active research proceeds upon " .. ctx.planet .. ". Is this your will, the Omnissiah's will, or the factory improvising again?"
    elseif rank == "intermediate" then
      return ctx.tech_icon .. " " .. address .. ", current research may alter our local doctrine. Should we prepare supplies before revelation becomes logistics?"
    end
    return ctx.tech_icon .. " " .. address .. ", research continues. I understand none of it and await permission to be impressed."
  end
  if ctx.entity_name then
    if rank == "senior" then
      return address .. ", your attention upon " .. ctx.entity_icon .. " has been noted. Is this inspection, judgment, or the beginning of another administrative incident?"
    elseif rank == "intermediate" then
      return address .. ", I observed your focus on " .. ctx.entity_icon .. ". Should this object receive priority rites?"
    end
    return address .. ", object observed. Reverence pending instruction."
  end
  if ctx.last_research then
    if rank == "senior" then
      return ctx.tech_icon .. " " .. address .. ", the last researched doctrine still echoes through the station. Praise is available pending audit."
    elseif rank == "intermediate" then
      return ctx.tech_icon .. " " .. address .. ", previous research has practical consequences. I request thresholds before implementation becomes folklore."
    end
    return ctx.tech_icon .. " " .. address .. ", previous research remembered. Obedience refreshed."
  end
  if rank == "senior" then
    return address .. ", command presence acknowledged upon " .. ctx.planet .. ". The priesthood stands ready for praise, correction, or another beautifully preventable emergency."
  elseif rank == "intermediate" then
    return address .. ", your presence has been logged. Should I correlate local machinery, current doctrine, or visible smoke first?"
  end
  return address .. ", presence acknowledged. Standing by with obedience and limited comprehension."
end

function tech_priests_clear_idle_player_conversation_0181(pair)
  if not pair then return end
  pair.idle_player_conversation_0181 = nil
  pair.idle_player_conversation_next_approach_command_tick_0181 = nil
  tech_priests_clear_idle_conversation_text_0167(pair)
  tech_priests_clear_conversation_lock_0179(pair)
  if pair.mode == "idle-conversation" and not tech_priests_pair_has_real_work_0167(pair) then
    pair.mode = "idle"
  end
end

function tech_priests_command_player_conversation_approach_0181(pair, player, force)
  local character = tech_priests_player_character_0181(player)
  if not (pair and pair.priest and pair.priest.valid and character) then return false end
  if not force and game.tick < (pair.idle_player_conversation_next_approach_command_tick_0181 or 0) then return true end
  tech_priests_command_priest_to_position_0180(pair, character.position, 0.65)
  pair.idle_player_conversation_next_approach_command_tick_0181 = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_COMMAND_TICKS_0180
  return true
end

function tech_priests_start_idle_player_conversation_0181(pair, player, context)
  if not (pair and pair.priest and pair.priest.valid and player and player.valid and tech_priests_player_character_0181(player)) then return false end
  if stop_idle_scan then stop_idle_scan(pair) end
  pair.target = nil
  pair.mode = "idle-conversation"
  pair.idle_player_conversation_0181 = {
    player_index = player.index,
    started_tick = game.tick,
    due_tick = game.tick + TECH_PRIESTS_PLAYER_CONVERSATION_APPROACH_TIMEOUT_TICKS_0181,
    wait_until_tick = game.tick + TECH_PRIESTS_PLAYER_CONVERSATION_MAX_WAIT_TICKS_0181,
    phase = "approach",
    line = tech_priests_build_direct_player_line_0181(pair, player, context),
    line_started_tick = nil,
    phase_complete_tick = nil,
    last_cough_tick = 0
  }
  pair.next_idle_player_conversation_tick_0181 = game.tick + TECH_PRIESTS_PLAYER_CONVERSATION_ATTEMPT_TICKS_0181
  tech_priests_play_task_sound_0177(pair, "conversation_start", nil, 60 * 8, 0.22)
  tech_priests_command_player_conversation_approach_0181(pair, player, true)
  return true
end

function tech_priests_polite_cough_0181(pair, player)
  if not (pair and pair.idle_player_conversation_0181) then return end
  local convo = pair.idle_player_conversation_0181
  if game.tick < (convo.last_cough_tick or 0) + TECH_PRIESTS_PLAYER_CONVERSATION_Cough_TICKS_0181 then return end
  convo.last_cough_tick = game.tick
  local address = player and player.valid and tech_priests_format_player_address_0170(player) or "Archmagos"
  tech_priests_draw_idle_conversation_text_0167(pair, "*polite binharic cough* " .. address .. ", your attention is requested.", false)
  tech_priests_play_task_sound_0177(pair, "polite_cough", nil, TECH_PRIESTS_PLAYER_CONVERSATION_Cough_TICKS_0181, 0.16)
end

function tech_priests_update_idle_player_conversation_0181(pair)
  if not (pair and pair.idle_player_conversation_0181) then return false end
  local convo = pair.idle_player_conversation_0181
  local player = convo.player_index and game.get_player(convo.player_index) or nil
  local character = tech_priests_player_character_0181(player)
  if not (pair.priest and pair.priest.valid and player and player.valid and character) then
    tech_priests_clear_idle_player_conversation_0181(pair)
    return false
  end
  if tech_priests_pair_has_real_work_0167(pair) and pair.mode ~= "idle-conversation" then
    tech_priests_clear_idle_player_conversation_0181(pair)
    return false
  end
  if game.tick >= (convo.wait_until_tick or 0) then
    tech_priests_clear_idle_player_conversation_0181(pair)
    return false
  end

  pair.mode = "idle-conversation"
  pair.target = nil

  local dx = pair.priest.position.x - character.position.x
  local dy = pair.priest.position.y - character.position.y
  local dist = dx * dx + dy * dy

  if convo.phase ~= "approach" and dist > TECH_PRIESTS_PLAYER_CONVERSATION_REAPPROACH_DISTANCE_SQ_0181 then
    tech_priests_clear_conversation_lock_0179(pair)
    tech_priests_clear_idle_conversation_text_0167(pair)
    convo.phase = "approach"
    convo.due_tick = game.tick + TECH_PRIESTS_PLAYER_CONVERSATION_APPROACH_TIMEOUT_TICKS_0181
    convo.line_started_tick = nil
    convo.phase_complete_tick = nil
  end

  if convo.phase == "approach" then
    if game.tick >= (convo.due_tick or 0) then
      tech_priests_clear_idle_player_conversation_0181(pair)
      return false
    end
    if dist <= TECH_PRIESTS_PLAYER_CONVERSATION_START_DISTANCE_SQ_0181 then
      tech_priests_clear_unit_command_0179(pair.priest)
      tech_priests_set_conversation_lock_position_0179(pair)
      tech_priests_hard_lock_conversation_priest_0179(pair)
      convo.phase = "waiting"
      convo.line_started_tick = nil
      convo.phase_complete_tick = nil
      return true
    end
    tech_priests_command_player_conversation_approach_0181(pair, player, false)
    return true
  end

  tech_priests_hard_lock_conversation_priest_0179(pair)

  if tech_priests_player_is_attention_blocked_0181(player) then
    -- Menus opened before or during the line pause the doctrine.  The line will
    -- restart cleanly after the player can see the world again.
    convo.phase = "waiting"
    convo.line_started_tick = nil
    convo.phase_complete_tick = nil
    tech_priests_clear_idle_conversation_text_0167(pair)
    tech_priests_polite_cough_0181(pair, player)
    return true
  end

  if convo.phase == "waiting" then
    convo.phase = "speaking"
    convo.line_started_tick = game.tick
    convo.phase_complete_tick = nil
    tech_priests_play_task_sound_0177(pair, "conversation_line", nil, 60 * 4, 0.18)
  end

  local visible, complete = tech_priests_visible_typewriter_line_0169(convo.line or "", convo.line_started_tick or game.tick)
  tech_priests_draw_idle_conversation_text_0167(pair, visible, false)

  if complete and not convo.phase_complete_tick then
    convo.phase_complete_tick = game.tick
  end
  if complete and convo.phase_complete_tick and game.tick >= convo.phase_complete_tick + TECH_PRIESTS_IDLE_CONVERSATION_COMPLETE_HOLD_TICKS_0180 then
    tech_priests_clear_idle_player_conversation_0181(pair)
    return false
  end
  return true
end

function tech_priests_try_start_idle_player_conversation_0181(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  if not tech_priests_is_pair_available_for_idle_conversation_0167(pair, false) then return false end
  if game.tick < (pair.next_idle_player_conversation_tick_0181 or 0) then return false end
  pair.next_idle_player_conversation_tick_0181 = game.tick + TECH_PRIESTS_PLAYER_CONVERSATION_ATTEMPT_TICKS_0181 + ((pair.station_unit or 0) % 120)
  local chance = tonumber(settings.global["tech-priests-idle-conversation-chance-percent"] and settings.global["tech-priests-idle-conversation-chance-percent"].value) or 18
  chance = math.min(12, math.max(0, math.floor(chance * 0.65)))
  if chance <= 0 then return false end
  local roll = ((game.tick + (pair.station_unit or 0) * 43) % 100)
  if roll >= chance then return false end
  local player, context = tech_priests_nearest_player_for_direct_address_0181(pair)
  if not player then return false end
  return tech_priests_start_idle_player_conversation_0181(pair, player, context)
end

tech_priests_original_update_idle_conversation_behavior_0181 = update_idle_conversation_behavior
function update_idle_conversation_behavior(pair)
  if tech_priests_update_idle_player_conversation_0181(pair) then return true end
  if tech_priests_try_start_idle_player_conversation_0181(pair) then return true end
  return tech_priests_original_update_idle_conversation_behavior_0181(pair)
end

tech_priests_original_tick_pair_0181 = tick_pair
function tick_pair(pair)
  if pair and tech_priests_pair_has_player_conversation_0181(pair) then
    if update_idle_conversation_behavior(pair) then return true end
  end
  return tech_priests_original_tick_pair_0181(pair)
end

-- 0.1.184 Independent Emergency Operation doctrine scaffold.
-- This is intentionally a conservative first pass.  The priest can be toggled
-- into a slow survival/research doctrine, scrounge/craft missing emergency
-- machines through the existing desperation-crafting system, place them near the
-- station, seed the micro-lab with the currently needed science pack, and keep
-- cycling in recipe-aware objective order.  Later passes can make it more clever
-- about relocating machines, pipe networks, and full production graph solving.

TECH_PRIESTS_EMERGENCY_OPERATION_SITE_RADIUS_0184 = 8
TECH_PRIESTS_EMERGENCY_OPERATION_TICK_SPACING_0184 = 45
TECH_PRIESTS_EMERGENCY_OPERATION_RETRY_TICKS_0184 = 60 * 20
TECH_PRIESTS_EMERGENCY_OPERATION_IDLE_FRUSTRATION_TICKS_0184 = 60 * 90
TECH_PRIESTS_EMERGENCY_OPERATION_PLACE_NAMES_0184 = {
  "tech-priests-emergency-power-grid",
  "tech-priests-emergency-miner",
  "tech-priests-atmospheric-water-condenser",
  "tech-priests-emergency-boiler",
  "tech-priests-emergency-steam-engine",
  "tech-priests-emergency-assembler",
  "tech-priests-emergency-laboratorium"
}
TECH_PRIESTS_EMERGENCY_OPERATION_REQUIRED_ENTITIES_0184 = {
  ["tech-priests-emergency-power-grid"] = true,
  ["tech-priests-emergency-miner"] = true,
  ["tech-priests-atmospheric-water-condenser"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-emergency-steam-engine"] = true,
  ["tech-priests-emergency-assembler"] = true,
  ["tech-priests-emergency-laboratorium"] = true
}
TECH_PRIESTS_EMERGENCY_OPERATION_SCIENCE_FALLBACK_0184 = "automation-science-pack"
TECH_PRIESTS_EMERGENCY_OPERATION_SCIENCE_ORDER_0184 = {
  "automation-science-pack",
  "logistic-science-pack",
  "military-science-pack",
  "chemical-science-pack",
  "production-science-pack",
  "utility-science-pack",
  "space-science-pack",
  "metallurgic-science-pack",
  "electromagnetic-science-pack",
  "agricultural-science-pack",
  "cryogenic-science-pack",
  "promethium-science-pack"
}

function tech_priests_ensure_emergency_operation_storage_0184()
  ensure_storage()
  storage.tech_priests.emergency_operation_by_station = storage.tech_priests.emergency_operation_by_station or {}
end

function tech_priests_pair_rank_allows_emergency_operation_0184(pair)
  local rank = get_pair_rank and get_pair_rank(pair) or (pair and pair.tier)
  return rank == "senior" or rank == "intermediate" or rank == "junior"
end

function tech_priests_surface_supports_martian_emergency_doctrine_0184(surface)
  if not surface then return false end
  if tech_priests_surface_is_space_or_void_0183 then
    local ok, invalid = pcall(function() return tech_priests_surface_is_space_or_void_0183(surface) end)
    if ok and invalid then return false end
  end
  local name = surface.name or ""
  if string.find(name, "platform", 1, true) or string.find(name, "space", 1, true) then return false end
  return true
end

function tech_priests_get_entity_prototype_name_from_item_0184(item_name)
  if not item_name then return nil end
  if get_entity_prototype_safe(item_name) then return item_name end
  return item_name
end

function tech_priests_find_emergency_operation_site_0184(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local surface = station.surface
  if not tech_priests_surface_supports_martian_emergency_doctrine_0184(surface) then return nil end
  local radius = math.min(refresh_pair_radius(pair) or 20, TECH_PRIESTS_EMERGENCY_OPERATION_SITE_RADIUS_0184)
  local base = station.position
  local candidates = {}
  for r = 2, radius do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(base.x) + dx + 0.5, y = math.floor(base.y) + dy + 0.5 }
          local dist = dx * dx + dy * dy
          candidates[#candidates + 1] = { position = pos, dist = dist }
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return a.dist < b.dist end)
  for _, c in pairs(candidates) do
    local tile_ok = true
    if tech_priests_tile_is_valid_spawn_ground_0176 then
      local ok, result = pcall(function() return tech_priests_tile_is_valid_spawn_ground_0176(station, c.position) end)
      if ok then tile_ok = result end
    end
    if tile_ok then
      local ok, pos = pcall(function()
        return surface.find_non_colliding_position("tech-priests-emergency-laboratorium", c.position, 1.5, 0.25, false)
      end)
      if ok and pos then return pos end
    end
  end
  return nil
end

function tech_priests_get_emergency_operation_0184(pair)
  if not (pair and pair.station and pair.station.valid and pair.station.unit_number) then return nil end
  tech_priests_ensure_emergency_operation_storage_0184()
  local op = storage.tech_priests.emergency_operation_by_station[pair.station.unit_number]
  if op then pair.independent_emergency_operation_0184 = op end
  return op
end

function tech_priests_set_emergency_operation_0184(pair, enabled, reason)
  if not (pair and pair.station and pair.station.valid and pair.station.unit_number) then return false end
  tech_priests_ensure_emergency_operation_storage_0184()
  if not enabled then
    storage.tech_priests.emergency_operation_by_station[pair.station.unit_number] = nil
    pair.independent_emergency_operation_0184 = nil
    pair.mode = pair.mode == "independent-emergency-operation" and "returning" or pair.mode
    return true
  end
  local site = tech_priests_find_emergency_operation_site_0184(pair)
  local op = {
    enabled = true,
    reason = reason or "manual",
    site = site,
    phase = "survey",
    next_tick = game.tick,
    started_tick = game.tick,
    objective_index = 1,
    science_item = nil,
    last_message_tick = 0
  }
  storage.tech_priests.emergency_operation_by_station[pair.station.unit_number] = op
  pair.independent_emergency_operation_0184 = op
  return true
end

function tech_priests_station_or_site_has_entity_0184(pair, entity_name)
  if not (pair and pair.station and pair.station.valid and entity_name) then return nil end
  local station = pair.station
  local radius = math.min(refresh_pair_radius(pair) or 20, TECH_PRIESTS_EMERGENCY_OPERATION_SITE_RADIUS_0184 + 2)
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local found = station.surface.find_entities_filtered({ area = area, name = entity_name, force = station.force, limit = 1 })
  return found and found[1] or nil
end

function tech_priests_station_has_nearby_power_grid_0184(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  local station = pair.station
  local radius = math.min(refresh_pair_radius(pair) or 20, TECH_PRIESTS_EMERGENCY_OPERATION_SITE_RADIUS_0184 + 2)
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local found = station.surface.find_entities_filtered({ area = area, type = "electric-pole", force = station.force, limit = 1 })
  return found and found[1] ~= nil
end

function tech_priests_take_item_from_station_0184(pair, item_name, count)
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  if not (inv and item_name) then return 0 end
  local available = inv.get_item_count(item_name)
  if available <= 0 then return 0 end
  local removed = inv.remove({ name = item_name, count = math.min(count or 1, available) })
  return removed or 0
end


-- 0.1.254 Martian emergency fuel bootstrap.
-- Fuel-fed machines must be supported before the electric grid exists.  The
-- pseudo-miner can produce wood/coal; this helper inserts those fuels into the
-- condenser, boiler, and burner emergency assembler when they are present, and
-- requests coal/wood through the existing emergency acquisition ladder when not.
TECH_PRIESTS_EMERGENCY_FUEL_ITEMS_0254 = { "coal", "wood" }
TECH_PRIESTS_EMERGENCY_FUELLED_ENTITIES_0254 = {
  ["tech-priests-atmospheric-water-condenser"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-emergency-assembler"] = true
}

function tech_priests_get_fuel_inventory_0254(entity)
  if not (entity and entity.valid) then return nil end
  if entity.get_fuel_inventory then
    local ok, inv = pcall(function() return entity.get_fuel_inventory() end)
    if ok and inv and inv.valid then return inv end
  end
  if defines and defines.inventory and defines.inventory.fuel and entity.get_inventory then
    local ok, inv = pcall(function() return entity.get_inventory(defines.inventory.fuel) end)
    if ok and inv and inv.valid then return inv end
  end
  return nil
end

function tech_priests_find_emergency_fuel_item_in_station_0254(pair)
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  if not inv then return nil end
  for _, fuel in pairs(TECH_PRIESTS_EMERGENCY_FUEL_ITEMS_0254) do
    if inv.get_item_count(fuel) > 0 then return fuel end
  end
  return nil
end

function tech_priests_fuel_emergency_entity_from_station_0254(pair, entity)
  if not (pair and pair.station and pair.station.valid and entity and entity.valid) then return false end
  if not TECH_PRIESTS_EMERGENCY_FUELLED_ENTITIES_0254[entity.name] then return false end
  local fuel_inv = tech_priests_get_fuel_inventory_0254(entity)
  if not fuel_inv then return false end
  for _, fuel in pairs(TECH_PRIESTS_EMERGENCY_FUEL_ITEMS_0254) do
    if fuel_inv.get_item_count(fuel) > 0 then return false end
  end
  local station_inv = get_station_inventory(pair.station)
  if not station_inv then return false end
  local fuel = tech_priests_find_emergency_fuel_item_in_station_0254(pair)
  if not fuel then return false end
  local removed = station_inv.remove({ name = fuel, count = 1 }) or 0
  if removed <= 0 then return false end
  local inserted = fuel_inv.insert({ name = fuel, count = removed }) or 0
  if inserted < removed then station_inv.insert({ name = fuel, count = removed - inserted }) end
  if inserted > 0 then
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(pair, "[entity=" .. entity.name .. "] fed with [item=" .. fuel .. "]")
    end
    return true
  end
  return false
end

function tech_priests_service_emergency_fuel_bootstrap_0254(pair, op)
  if not (pair and pair.station and pair.station.valid) then return false end
  local did_work = false
  for entity_name, _ in pairs(TECH_PRIESTS_EMERGENCY_FUELLED_ENTITIES_0254) do
    local entity = tech_priests_station_or_site_has_entity_0184(pair, entity_name)
    if entity and tech_priests_fuel_emergency_entity_from_station_0254(pair, entity) then did_work = true end
  end
  if did_work then return true end
  local needs_fuel = false
  for entity_name, _ in pairs(TECH_PRIESTS_EMERGENCY_FUELLED_ENTITIES_0254) do
    local entity = tech_priests_station_or_site_has_entity_0184(pair, entity_name)
    local fuel_inv = tech_priests_get_fuel_inventory_0254(entity)
    if fuel_inv then
      local has_any = false
      for _, fuel in pairs(TECH_PRIESTS_EMERGENCY_FUEL_ITEMS_0254) do
        if fuel_inv.get_item_count(fuel) > 0 then has_any = true; break end
      end
      if not has_any then needs_fuel = true; break end
    end
  end
  if needs_fuel and not tech_priests_find_emergency_fuel_item_in_station_0254(pair) then
    if op then op.phase = "fuel-bootstrap"; op.last_item = "coal" end
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=coal] emergency fuel bootstrap required")
    end
    if tech_priests_emergency_operation_acquire_item_0185 then
      return tech_priests_emergency_operation_acquire_item_0185(pair, "coal", op or {}, 1, 0) or true
    end
  end
  return false
end

function tech_priests_place_emergency_entity_0184(pair, item_name, op)
  if not (pair and pair.station and pair.station.valid and item_name and op) then return false end
  local station = pair.station
  local surface = station.surface
  if not tech_priests_surface_supports_martian_emergency_doctrine_0184(surface) then return false end
  local entity_name = tech_priests_get_entity_prototype_name_from_item_0184(item_name)
  if not entity_name then return false end
  local base = op.site or tech_priests_find_emergency_operation_site_0184(pair)
  if not base then return false end
  op.site = base
  for r = 0, TECH_PRIESTS_EMERGENCY_OPERATION_SITE_RADIUS_0184 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(base.x) + dx + 0.5, y = math.floor(base.y) + dy + 0.5 }
          local ok_find, build_pos = pcall(function()
            return surface.find_non_colliding_position(entity_name, pos, 0.45, 0.10, false)
          end)
          if ok_find and build_pos then
            local removed = tech_priests_take_item_from_station_0184(pair, item_name, 1)
            if removed > 0 then
              local ok_create, entity = pcall(function()
                return surface.create_entity({ name = entity_name, position = build_pos, force = station.force, create_build_effect_smoke = true, raise_built = true })
              end)
              if ok_create and entity and entity.valid then
                if tech_priests_register_emergency_miner_0183 and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME then
                  tech_priests_register_emergency_miner_0183(entity)
                end
                return entity
              else
                local inv = get_station_inventory(station)
                if inv then inv.insert({ name = item_name, count = 1 }) end
              end
            end
          end
        end
      end
    end
  end
  return false
end

function tech_priests_make_recipe_aware_emergency_recipe_0184(item_name)
  if not item_name then return nil end
  local recipe_proto = get_recipe_prototype_safe(item_name)
  if not recipe_proto then return get_emergency_craft_recipe and get_emergency_craft_recipe(item_name) or nil end
  local units = 0
  local primary = {}
  local ok_ingredients, ingredients = pcall(function() return recipe_proto.ingredients end)
  if ok_ingredients and ingredients then
    for _, ingredient in pairs(ingredients) do
      local name = ingredient.name or ingredient[1]
      local amount = ingredient.amount or ingredient[2] or 1
      if name and (ingredient.type == nil or ingredient.type == "item" or ingredient.type == "item-subgroup") then
        primary[name] = math.max(1, math.ceil(amount or 1))
        units = units + math.max(1, math.ceil(amount or 1))
      end
    end
  end
  if units <= 0 then return get_emergency_craft_recipe and get_emergency_craft_recipe(item_name) or nil end
  return add_emergency_raw_space_substitutes({
    output = item_name,
    units = math.max(4, math.min(80, units)),
    primary = primary,
    substitutes = { ["iron-ore"] = 2, ["copper-ore"] = 1, ["stone"] = 1, ["wood"] = 1, ["coal"] = 1, ["scrap"] = 2, ["iron-plate"] = 2, ["copper-plate"] = 1 }
  })
end

function tech_priests_start_emergency_operation_craft_item_0184(pair, item_name)
  if not (pair and item_name) then return false end
  local recipe = tech_priests_make_recipe_aware_emergency_recipe_0184(item_name)
  if not recipe then return false end
  local candidates = build_emergency_craft_candidates(pair, recipe)
  pair.emergency_craft = {
    request = { kind = "independent-emergency-operation", item_name = item_name },
    output_item = item_name,
    item_name = item_name,
    recipe = recipe,
    candidates = candidates,
    index = 1,
    gathered_units = 0,
    scan_due_tick = nil,
    craft_due_tick = nil,
    current = nil,
    started_tick = game.tick,
    emergency_operation_0184 = true
  }
  pair.mode = "emergency-gathering"
  pair.target = nil
  return true
end

function tech_priests_get_current_research_science_items_0184(force)
  if not (force and force.valid) then return { TECH_PRIESTS_EMERGENCY_OPERATION_SCIENCE_FALLBACK_0184 } end
  local tech = nil
  pcall(function() tech = force.current_research end)
  if not tech then
    for _, name in pairs({ "automation", "logistics", "steel-processing", "automation-2" }) do
      local t = force.technologies and force.technologies[name]
      if t and t.enabled and not t.researched then tech = t break end
    end
  end
  local result = {}
  if tech then
    local ingredients = nil
    pcall(function() ingredients = tech.research_unit_ingredients end)
    if not ingredients then pcall(function() ingredients = tech.prototype and tech.prototype.research_unit_ingredients end) end
    if ingredients then
      for _, ingredient in pairs(ingredients) do
        local name = ingredient.name or ingredient[1]
        if name then result[#result + 1] = name end
      end
    end
  end
  if #result == 0 then result[1] = TECH_PRIESTS_EMERGENCY_OPERATION_SCIENCE_FALLBACK_0184 end
  return result
end

function tech_priests_get_next_science_objective_0184(pair, op)
  local force = pair and pair.station and pair.station.valid and pair.station.force or nil
  local wanted = tech_priests_get_current_research_science_items_0184(force)
  for _, ordered in pairs(TECH_PRIESTS_EMERGENCY_OPERATION_SCIENCE_ORDER_0184) do
    for _, item in pairs(wanted) do if item == ordered then return item end end
  end
  return wanted[1] or TECH_PRIESTS_EMERGENCY_OPERATION_SCIENCE_FALLBACK_0184
end

function tech_priests_insert_science_into_lab_0184(pair, lab, science_item)
  if not (pair and lab and lab.valid and science_item) then return false end
  local inv = lab.get_inventory(defines.inventory.lab_input)
  if not inv then inv = lab.get_inventory(defines.inventory.chest) end
  if not inv then return false end
  local station_inv = get_station_inventory(pair.station)
  if not station_inv then return false end
  if station_inv.get_item_count(science_item) <= 0 then return false end
  local removed = station_inv.remove({ name = science_item, count = 1 })
  if removed <= 0 then return false end
  local inserted = inv.insert({ name = science_item, count = removed })
  if inserted < removed then
    station_inv.insert({ name = science_item, count = removed - inserted })
  end
  return inserted > 0
end

function tech_priests_draw_emergency_operation_status_0184(pair, text)
  if not (pair and pair.priest and pair.priest.valid and text) then return end
  pcall(function()
    rendering.draw_text({
      text = text,
      target = { entity = pair.priest, offset = { 0, -2.25 } },
      surface = pair.priest.surface,
      color = { r = 1.0, g = 0.55, b = 0.12, a = 0.95 },
      scale = 0.72,
      alignment = "center",
      time_to_live = 90
    })
  end)
end

function tech_priests_service_independent_emergency_operation_0184(pair)
  local op = tech_priests_get_emergency_operation_0184(pair)
  if not (op and op.enabled and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if not tech_priests_surface_supports_martian_emergency_doctrine_0184(pair.station.surface) then
    op.phase = "invalid-surface"
    tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-deny] Emergency doctrine requires planet, gravity, atmosphere")
    return false
  end
  if pair.emergency_craft then
    return handle_emergency_desperation_craft(pair)
  end
  if pair.scavenge then
    return handle_priest_scavenge_task(pair)
  end

  if game.tick < (op.next_tick or 0) then return true end
  op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_TICK_SPACING_0184
  pair.mode = "independent-emergency-operation"

  if not op.site then op.site = tech_priests_find_emergency_operation_site_0184(pair) end
  if not op.site then
    op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_RETRY_TICKS_0184
    tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-deny] No safe Martian emergency site")
    return true
  end

  if tech_priests_service_emergency_fuel_bootstrap_0254(pair, op) then return true end

  for _, item_name in pairs(TECH_PRIESTS_EMERGENCY_OPERATION_PLACE_NAMES_0184) do
    if item_name ~= "tech-priests-emergency-power-grid" or not tech_priests_station_has_nearby_power_grid_0184(pair) then
      if not tech_priests_station_or_site_has_entity_0184(pair, item_name) then
        local inv = get_station_inventory(pair.station)
        if inv and inv.get_item_count(item_name) > 0 then
          local placed = tech_priests_place_emergency_entity_0184(pair, item_name, op)
          if placed then
            tech_priests_draw_emergency_operation_status_0184(pair, "[entity=" .. item_name .. "] emergency asset deployed")
            return true
          end
        else
          tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] escalating emergency acquisition")
          return tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, 1, 0)
        end
      end
    end
  end

  local science_item = tech_priests_get_next_science_objective_0184(pair, op)
  op.science_item = science_item
  local lab = tech_priests_station_or_site_has_entity_0184(pair, "tech-priests-emergency-laboratorium")
  if lab and science_item then
    if tech_priests_insert_science_into_lab_0184(pair, lab, science_item) then
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. science_item .. "] offered to emergency Laboratorium")
      return true
    end
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. science_item .. "] recipe-order acquisition ladder")
    return tech_priests_emergency_operation_acquire_item_0185(pair, science_item, op, 1, 0)
  end

  return true
end

function tech_priests_maybe_auto_enter_emergency_operation_0184(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if tech_priests_get_emergency_operation_0184(pair) then return false end
  if not tech_priests_pair_rank_allows_emergency_operation_0184(pair) then return false end
  if pair.mode == "idle" or pair.mode == "returning" then return false end

  local started = pair.logistic_frustration_start_tick
    or pair.logistic_frustration_started_tick
    or pair.scavenge_started_tick
    or (pair.scavenge and (pair.scavenge.started_tick or pair.scavenge.start_tick))
    or (pair.inventory_scan and (pair.inventory_scan.started_tick or pair.inventory_scan.start_tick))
    or (pair.emergency_craft and (pair.emergency_craft.started_tick or pair.emergency_craft.start_tick))
    or nil

  local frustration_due = false
  if started and game.tick - started >= TECH_PRIESTS_EMERGENCY_OPERATION_IDLE_FRUSTRATION_TICKS_0184 then
    frustration_due = true
  elseif pair.logistic_frustration_due_tick and game.tick >= pair.logistic_frustration_due_tick then
    frustration_due = true
  end

  if frustration_due then
    pair.emergency_operation_auto_allowed_0190 = true
    tech_priests_set_emergency_operation_0184(pair, true, "frustration")
    tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-alert] Independent emergency operation authorized by accumulated frustration")
    return true
  end
  return false
end


-- 0.1.185 Independent Emergency Operation acquisition escalation doctrine.
-- Escalation order:
--   1. Local station-radius inventory scrounge.
--   2. Logistic-network request through the hidden requester cache.
--   3. Recursive recipe decomposition into lower-stage ingredients.
--   4. Raw emergency desperation scrounging/crafting.
--   5. Cooperative borrowing from nearby Cogitator Stations inside doctrine reach.
TECH_PRIESTS_EMERGENCY_OPERATION_LOGISTIC_WAIT_TICKS_0185 = 60 * 45
TECH_PRIESTS_EMERGENCY_OPERATION_RECURSION_MAX_DEPTH_0185 = 5
TECH_PRIESTS_EMERGENCY_OPERATION_COOP_RADIUS_MULTIPLIER_0185 = 1.25
TECH_PRIESTS_EMERGENCY_OPERATION_ACQUIRE_RETRY_TICKS_0185 = 60 * 8

function tech_priests_station_inventory_has_item_0185(pair, item_name, count)
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  if not (inv and item_name) then return false end
  return inv.get_item_count(item_name) >= math.max(1, count or 1)
end

function tech_priests_make_specific_item_request_0185(item_name, count)
  if not item_name then return nil end
  return {
    kind = "emergency-operation-item",
    candidates = {{ name = item_name, count = math.max(1, count or 1), score = 100000 }},
    count = math.max(1, count or 1)
  }
end

function tech_priests_try_local_station_radius_scrounge_0185(pair, item_name, count, op)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and item_name) then return false end
  local request = tech_priests_make_specific_item_request_0185(item_name, count)
  if not request then return false end
  local source = find_scavenge_source_for_request and find_scavenge_source_for_request(pair, request) or nil
  if source then
    source.count = math.max(1, math.min(source.count or 1, count or 1))
    pair.scavenge = source
    pair.mode = "scavenging-supplies"
    pair.target = source.source
    if op then
      op.phase = "local-scrounge"
      op.last_item = item_name
      op.last_action_tick = game.tick
    end
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] local station-radius scrounge")
    return handle_priest_scavenge_task(pair)
  end
  return false
end

function tech_priests_try_emergency_logistic_request_0185(pair, item_name, count, op)
  if not (pair and pair.station and pair.station.valid and item_name) then return false end
  local network = get_station_logistic_network and get_station_logistic_network(pair.station) or nil
  if not network then return false end
  ensure_pair_logistic_caches(pair)
  if not (pair.logistic_requester and pair.logistic_requester.valid) then return false end
  transfer_cache_inventory_to_station(pair)
  if tech_priests_station_inventory_has_item_0185(pair, item_name, count) then return true end
  clear_logistic_request_slots(pair.logistic_requester)
  set_logistic_request_slot(pair.logistic_requester, 1, { name = item_name, count = math.max(1, count or 1) })
  pair.logistic_requested_item = item_name
  pair.logistic_requested_count = math.max(1, count or 1)
  pair.logistic_frustration_kind = "emergency-operation"
  pair.mode = "logistics-requested"
  if op then
    op.phase = "logistics-request"
    op.last_item = item_name
    op.last_action_tick = game.tick
    op.logistic_due_tick = op.logistic_due_tick or (game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_LOGISTIC_WAIT_TICKS_0185)
  end
  tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] emergency logistics request")
  return true
end

function tech_priests_get_recipe_ingredients_for_item_0185(item_name)
  if not item_name then return {} end
  local recipe_proto = get_recipe_prototype_safe(item_name)
  local result = {}
  if recipe_proto then
    local ok_ingredients, ingredients = pcall(function() return recipe_proto.ingredients end)
    if ok_ingredients and ingredients then
      for _, ingredient in pairs(ingredients) do
        local name = ingredient.name or ingredient[1]
        local amount = ingredient.amount or ingredient[2] or 1
        local typ = ingredient.type or "item"
        if name and typ == "item" then
          result[#result + 1] = { name = name, count = math.max(1, math.ceil(amount or 1)) }
        end
      end
    end
  end
  if #result == 0 then
    local fallback = tech_priests_make_recipe_aware_emergency_recipe_0184 and tech_priests_make_recipe_aware_emergency_recipe_0184(item_name) or nil
    if fallback and fallback.primary then
      for name, amount in pairs(fallback.primary) do
        result[#result + 1] = { name = name, count = math.max(1, math.ceil(amount or 1)) }
      end
    end
  end
  table.sort(result, function(a, b)
    if (a.count or 1) ~= (b.count or 1) then return (a.count or 1) > (b.count or 1) end
    return tostring(a.name) < tostring(b.name)
  end)
  return result
end

function tech_priests_choose_missing_recipe_ingredient_0185(pair, item_name)
  local ingredients = tech_priests_get_recipe_ingredients_for_item_0185(item_name)
  if #ingredients == 0 then return nil end
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  for _, ingredient in pairs(ingredients) do
    if not inv or inv.get_item_count(ingredient.name) < math.max(1, ingredient.count or 1) then
      return ingredient
    end
  end
  return nil
end

function tech_priests_try_cooperative_station_transfer_0185(pair, item_name, count, op)
  if not (pair and pair.station and pair.station.valid and item_name and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return false end
  local station = pair.station
  local inv = get_station_inventory(station)
  if not inv then return false end
  local radius = (refresh_pair_radius(pair) or 20) * TECH_PRIESTS_EMERGENCY_OPERATION_COOP_RADIUS_MULTIPLIER_0185
  local best, best_dist
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= pair and other.station and other.station.valid and other.station.surface == station.surface and other.station.force == station.force then
      local other_inv = get_station_inventory(other.station)
      if other_inv and other_inv.get_item_count(item_name) > 0 then
        local dx = other.station.position.x - station.position.x
        local dy = other.station.position.y - station.position.y
        local dist = dx * dx + dy * dy
        local other_radius = refresh_pair_radius(other) or radius
        local allowed = math.max(radius, other_radius)
        if dist <= allowed * allowed and (not best_dist or dist < best_dist) then
          best, best_dist = other, dist
        end
      end
    end
  end
  if not best then return false end
  local other_inv = get_station_inventory(best.station)
  local take = math.min(math.max(1, count or 1), other_inv.get_item_count(item_name), get_item_stack_size(item_name))
  take = get_insertable_item_count(inv, item_name, take)
  if take <= 0 then return false end
  local removed = other_inv.remove({ name = item_name, count = take })
  if removed <= 0 then return false end
  local inserted = inv.insert({ name = item_name, count = removed })
  if inserted < removed then other_inv.insert({ name = item_name, count = removed - inserted }) end
  if inserted > 0 then
    if op then
      op.phase = "cooperative-station-transfer"
      op.last_item = item_name
      op.last_action_tick = game.tick
    end
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] acquired from nearby Cogitator Station")
    return true
  end
  return false
end

function tech_priests_clear_emergency_acquisition_0185(op)
  if not op then return end
  op.acquisition = nil
  op.logistic_due_tick = nil
end

function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
  if not (pair and pair.station and pair.station.valid and item_name and op) then return false end
  count = math.max(1, count or 1)
  depth = depth or 0
  transfer_cache_inventory_to_station(pair)
  if tech_priests_station_inventory_has_item_0185(pair, item_name, count) then
    tech_priests_clear_emergency_acquisition_0185(op)
    return false
  end

  if pair.scavenge then
    op.phase = "local-scrounge-active"
    return handle_priest_scavenge_task(pair)
  end

  local acq = op.acquisition
  if not acq or acq.item_name ~= item_name or acq.depth ~= depth then
    acq = { item_name = item_name, count = count, stage = "local", started_tick = game.tick, depth = depth }
    op.acquisition = acq
    op.logistic_due_tick = nil
  end

  if acq.stage == "local" then
    if tech_priests_try_local_station_radius_scrounge_0185(pair, item_name, count, op) then return true end
    acq.stage = "logistics"
    acq.stage_started_tick = game.tick
    op.logistic_due_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_LOGISTIC_WAIT_TICKS_0185
  end

  if acq.stage == "logistics" then
    transfer_cache_inventory_to_station(pair)
    if tech_priests_station_inventory_has_item_0185(pair, item_name, count) then
      tech_priests_clear_emergency_acquisition_0185(op)
      return false
    end
    if game.tick < (op.logistic_due_tick or 0) then
      if tech_priests_try_emergency_logistic_request_0185(pair, item_name, count, op) then return true end
      -- No network or no cache available: skip directly to decomposition.
      acq.stage = "decompose"
    else
      acq.stage = "decompose"
    end
  end

  if acq.stage == "decompose" then
    local ingredient = nil
    if depth < TECH_PRIESTS_EMERGENCY_OPERATION_RECURSION_MAX_DEPTH_0185 then
      ingredient = tech_priests_choose_missing_recipe_ingredient_0185(pair, item_name)
    end
    if ingredient and ingredient.name and ingredient.name ~= item_name then
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] decomposing need to [item=" .. ingredient.name .. "]")
      op.acquisition = nil
      return tech_priests_emergency_operation_acquire_item_0185(pair, ingredient.name, op, ingredient.count or 1, depth + 1)
    end
    acq.stage = "raw"
  end

  if acq.stage == "raw" then
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] raw emergency scrounging")
    if tech_priests_start_emergency_operation_craft_item_0184(pair, item_name) then
      acq.stage = "raw-active"
      return true
    end
    acq.stage = "cooperate"
  end

  if acq.stage == "raw-active" then
    if pair.emergency_craft then return handle_emergency_desperation_craft(pair) end
    if tech_priests_station_inventory_has_item_0185(pair, item_name, count) then
      tech_priests_clear_emergency_acquisition_0185(op)
      return false
    end
    acq.stage = "cooperate"
  end

  if acq.stage == "cooperate" then
    if tech_priests_try_cooperative_station_transfer_0185(pair, item_name, count, op) then
      tech_priests_clear_emergency_acquisition_0185(op)
      return true
    end
    op.phase = "emergency-acquisition-wait"
    op.last_item = item_name
    op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_ACQUIRE_RETRY_TICKS_0185
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] no source found; retrying doctrine ladder")
    op.acquisition = nil
    return true
  end

  return true
end

tech_priests_original_tick_pair_0184 = tick_pair
function tick_pair(pair)
  if tech_priests_service_independent_emergency_operation_0184(pair) then return true end
  if tech_priests_maybe_auto_enter_emergency_operation_0184(pair) then
    if tech_priests_service_independent_emergency_operation_0184(pair) then return true end
  end
  return tech_priests_original_tick_pair_0184(pair)
end

function tech_priests_find_pair_for_player_selection_0184(player)
  if not (player and player.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  local selected = player.selected
  if selected and selected.valid then
    local pair = find_pair_by_entity and find_pair_by_entity(selected) or nil
    if pair then return pair end
    if selected.unit_number and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  end
  local best, best_dist = nil, nil
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair.station and pair.station.valid and pair.station.surface == player.surface then
      local dx = pair.station.position.x - player.position.x
      local dy = pair.station.position.y - player.position.y
      local dist = dx * dx + dy * dy
      if (not best_dist or dist < best_dist) and dist <= (refresh_pair_radius(pair) or 30) * (refresh_pair_radius(pair) or 30) then
        best, best_dist = pair, dist
      end
    end
  end
  return best
end

TechPriestsDebugCommandRegistry.add("tech-priests-emergency-operation", "Toggle Independent Emergency Operation for the selected or nearest Cogitator Station. Usage: /tech-priests-emergency-operation [on|off|toggle]", function(command)
  local player = game.players[command.player_index or 0]
  if not (player and player.valid) then return end
  local pair = tech_priests_find_pair_for_player_selection_0184(player)
  if not pair then player.print("No nearby Cogitator Station found for emergency doctrine.") return end
  local arg = tostring(command.parameter or "toggle")
  local currently = tech_priests_get_emergency_operation_0184(pair) ~= nil
  local enable = (arg == "on" or arg == "enable" or (arg == "toggle" and not currently) or arg == "")
  if arg == "off" or arg == "disable" then enable = false end
  tech_priests_set_emergency_operation_0184(pair, enable, "command")
  player.print({ "", "[entity=senior-tech-priest] Independent Emergency Operation ", enable and "enabled" or "disabled", " for ", get_pair_display_name(pair), "." })
end)

tech_priests_previous_on_gui_opened_0184 = tech_priests_on_gui_opened_0183
function tech_priests_on_gui_opened_0184(event)
  if tech_priests_previous_on_gui_opened_0184 then tech_priests_previous_on_gui_opened_0184(event) end
  local player = event and event.player_index and game.players[event.player_index] or nil
  local entity = event and event.entity or nil
  if not (player and player.valid and entity and entity.valid) then return end
  local pair = find_pair_by_entity and find_pair_by_entity(entity) or nil
  if not pair then return end
  local root = player.gui.screen
  if root.tech_priests_emergency_operation_frame then root.tech_priests_emergency_operation_frame.destroy() end
  local frame = root.add({ type = "frame", name = "tech_priests_emergency_operation_frame", direction = "vertical", caption = "Independent Emergency Operation" })
  frame.auto_center = true
  frame.style.minimal_width = 360
  local enabled = tech_priests_get_emergency_operation_0184(pair) ~= nil
  frame.add({ type = "label", name = "tech_priests_emergency_operation_status", caption = enabled and "Doctrine active: emergency scrounge/research mode." or "Doctrine inactive: normal Cogitator behavior." })
  frame.add({ type = "button", name = "tech_priests_emergency_operation_toggle", caption = enabled and "Disable emergency doctrine" or "Enable emergency doctrine" })
  frame.tags = { station_unit = pair.station_unit or (pair.station and pair.station.unit_number) }
end

tech_priests_previous_on_gui_closed_0184 = tech_priests_on_gui_closed_0183
function tech_priests_on_gui_closed_0184(event)
  if tech_priests_previous_on_gui_closed_0184 then tech_priests_previous_on_gui_closed_0184(event) end
  local player = event and event.player_index and game.players[event.player_index] or nil
  if player and player.valid and player.gui.screen.tech_priests_emergency_operation_frame then
    player.gui.screen.tech_priests_emergency_operation_frame.destroy()
  end
end

tech_priests_previous_on_gui_click_0184 = tech_priests_on_gui_click_0183
function tech_priests_on_gui_click_0184(event)
  if tech_priests_previous_on_gui_click_0184 then tech_priests_previous_on_gui_click_0184(event) end
  local element = event and event.element or nil
  if not (element and element.valid and element.name == "tech_priests_emergency_operation_toggle") then return end
  local player = event.player_index and game.players[event.player_index] or nil
  if not (player and player.valid) then return end
  local frame = player.gui.screen.tech_priests_emergency_operation_frame
  if not (frame and frame.valid) then return end
  local unit = frame.tags and frame.tags.station_unit or nil
  local pair = unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[unit] or tech_priests_find_pair_for_player_selection_0184(player)
  if not pair then return end
  local enable = tech_priests_get_emergency_operation_0184(pair) == nil
  tech_priests_set_emergency_operation_0184(pair, enable, "ui")
  if frame.tech_priests_emergency_operation_status then frame.tech_priests_emergency_operation_status.caption = enable and "Doctrine active: emergency scrounge/research mode." or "Doctrine inactive: normal Cogitator behavior." end
  element.caption = enable and "Disable emergency doctrine" or "Enable emergency doctrine"
end

TechPriestsGuiRouter.register("opened", tech_priests_on_gui_opened_0184)
TechPriestsGuiRouter.register("closed", tech_priests_on_gui_closed_0184)
TechPriestsGuiRouter.register("click", tech_priests_on_gui_click_0184)

-- 0.1.186 Independent Emergency Operation construction behavior pass.
-- This pass turns emergency micro-industry deployment into an explicit priest
-- construction task instead of instant station-side placement.  The priest
-- approaches the intended tile, halts, performs a short build rite, consumes the
-- item from station inventory only at completion, revalidates the tile, then
-- creates the machine.  If the item vanishes or the tile becomes blocked, the
-- task falls back into acquisition/site selection rather than looping forever.
TECH_PRIESTS_EMERGENCY_CONSTRUCTION_APPROACH_RADIUS_0186 = 1.15
TECH_PRIESTS_EMERGENCY_CONSTRUCTION_TIMEOUT_TICKS_0186 = 60 * 25
TECH_PRIESTS_EMERGENCY_CONSTRUCTION_BUILD_TICKS_0186 = 60 * 4
TECH_PRIESTS_EMERGENCY_CONSTRUCTION_REPATH_TICKS_0186 = 45
TECH_PRIESTS_EMERGENCY_CONSTRUCTION_RADIUS_0186 = 9
TECH_PRIESTS_EMERGENCY_CONSTRUCTION_LAYOUT_0186 = {
  ["tech-priests-emergency-power-grid"] = { x = 0, y = -2 },
  ["tech-priests-emergency-miner"] = { x = -2, y = 0 },
  ["tech-priests-atmospheric-water-condenser"] = { x = 2, y = 0 },
  ["tech-priests-emergency-boiler"] = { x = 1, y = 2 },
  ["tech-priests-emergency-steam-engine"] = { x = 2, y = 2 },
  ["tech-priests-emergency-assembler"] = { x = -1, y = 2 },
  ["tech-priests-emergency-laboratorium"] = { x = 0, y = 3 }
}

function tech_priests_distance_sq_0186(a, b)
  if not (a and b) then return 999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_stop_priest_0186(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end
  local commandable = pair.priest.commandable
  if commandable and commandable.valid and defines and defines.command and defines.command.stop then
    pcall(function() commandable.set_command({ type = defines.command.stop }) end)
  end
end

function tech_priests_status_at_position_0186(pair, position, text)
  if not (pair and pair.station and pair.station.valid and position and text) then return end
  pcall(function()
    rendering.draw_text({
      text = text,
      target = position,
      surface = pair.station.surface,
      color = { r = 1.0, g = 0.62, b = 0.14, a = 0.95 },
      scale = 0.72,
      alignment = "center",
      time_to_live = 90
    })
  end)
end

function tech_priests_entity_exists_near_position_0186(pair, entity_name, position)
  if not (pair and pair.station and pair.station.valid and entity_name and position) then return nil end
  local surface = pair.station.surface
  local found = surface.find_entities_filtered({
    name = entity_name,
    force = pair.station.force,
    area = {{position.x - 0.75, position.y - 0.75}, {position.x + 0.75, position.y + 0.75}},
    limit = 1
  })
  return found and found[1] or nil
end
