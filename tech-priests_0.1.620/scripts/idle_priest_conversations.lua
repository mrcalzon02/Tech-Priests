-- Tech Priests 0.1.249
-- Editable behavior call layer for idle Tech-Priest-to-Tech-Priest conversations.
-- This file is intentionally required at the end of control.lua so it can act as
-- the final conversation gate after the historical wrapper stack has loaded.

TECH_PRIESTS_IDLE_PRIEST_CONVERSATIONS_MODULE_0249 = true

function tech_priests_idle_priest_conversations_cancel_0249(pair, reason)
  if not pair then return false end
  local had = pair.idle_conversation or pair.idle_conversation_listener_until or pair.idle_conversation_speaker_station_unit or pair.idle_conversation_approach_0180 or pair.idle_conversation_approach_listener_until_0180 or pair.idle_conversation_approach_speaker_station_unit_0180
  if tech_priests_stop_idle_conversation_0167 then pcall(function() tech_priests_stop_idle_conversation_0167(pair) end) end
  if tech_priests_clear_conversation_approach_0180 then pcall(function() tech_priests_clear_conversation_approach_0180(pair) end) end
  if tech_priests_clear_conversation_lock_0179 then pcall(function() tech_priests_clear_conversation_lock_0179(pair) end) end
  pair.idle_conversation = nil
  pair.idle_conversation_listener_until = nil
  pair.idle_conversation_speaker_station_unit = nil
  pair.idle_conversation_approach_0180 = nil
  pair.idle_conversation_approach_listener_until_0180 = nil
  pair.idle_conversation_approach_speaker_station_unit_0180 = nil
  pair.idle_conversation_next_approach_command_tick_0180 = nil
  if had and reason and tech_priests_0246_log then
    tech_priests_0246_log(pair, "idle-priest-conversation-cancel", "reason=" .. tostring(reason))
  end
  return had and true or false
end

function tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair)
  if not pair then return false end
  if tech_priests_pair_has_higher_priority_work_0248 then
    local ok, result = pcall(function() return tech_priests_pair_has_higher_priority_work_0248(pair) end)
    if ok and result then return true end
  end
  if tech_priests_pair_has_higher_priority_work_0246 then
    local ok, result = pcall(function() return tech_priests_pair_has_higher_priority_work_0246(pair) end)
    if ok and result then return true end
  end
  if pair.mode == "attacking" or pair.mode == "repairing" or pair.mode == "sanctifying" or pair.mode == "missing-repair-supplies" or pair.mode == "missing-consecration-supplies" or pair.mode == "ammo-missing-supplies" then
    return true
  end
  return false
end

tech_priests_original_is_pair_available_for_idle_conversation_0249 = tech_priests_original_is_pair_available_for_idle_conversation_0249 or tech_priests_is_pair_available_for_idle_conversation_0167
function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)
  if tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_priest_conversations_cancel_0249(pair, "higher-priority-work")
    return false
  end
  if not tech_priests_original_is_pair_available_for_idle_conversation_0249 then return false end
  return tech_priests_original_is_pair_available_for_idle_conversation_0249(pair, as_listener)
end

tech_priests_original_start_idle_conversation_0249 = tech_priests_original_start_idle_conversation_0249 or tech_priests_start_idle_conversation_0167
function tech_priests_start_idle_conversation_0167(pair, listener_pair)
  if tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair) or tech_priests_idle_priest_conversations_higher_priority_visible_0249(listener_pair) then
    tech_priests_idle_priest_conversations_cancel_0249(pair, "start-denied-higher-priority-work")
    tech_priests_idle_priest_conversations_cancel_0249(listener_pair, "start-denied-higher-priority-work")
    return false
  end
  return tech_priests_original_start_idle_conversation_0249(pair, listener_pair)
end

tech_priests_original_update_idle_conversation_behavior_0249 = tech_priests_original_update_idle_conversation_behavior_0249 or update_idle_conversation_behavior
function update_idle_conversation_behavior(pair)
  if tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_priest_conversations_cancel_0249(pair, "update-cancel-higher-priority-work")
    return false
  end
  if not tech_priests_original_update_idle_conversation_behavior_0249 then return false end
  return tech_priests_original_update_idle_conversation_behavior_0249(pair)
end

function tech_priests_idle_priest_conversations_tick_0249(pair)
  if not pair then return false end
  if tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_priest_conversations_cancel_0249(pair, "tick-cancel-higher-priority-work")
    return false
  end
  if tech_priests_pair_is_conversation_locked_0179 and tech_priests_pair_is_conversation_locked_0179(pair) then
    return update_idle_conversation_behavior(pair) and true or false
  end
  if tech_priests_pair_is_conversation_approaching_0180 and tech_priests_pair_is_conversation_approaching_0180(pair) then
    return update_idle_conversation_behavior(pair) and true or false
  end
  return false
end

tech_priests_original_tick_pair_idle_priest_conversations_0249 = tech_priests_original_tick_pair_idle_priest_conversations_0249 or tick_pair
function tick_pair(pair)
  if tech_priests_idle_priest_conversations_tick_0249(pair) then return true end
  return tech_priests_original_tick_pair_idle_priest_conversations_0249(pair)
end
