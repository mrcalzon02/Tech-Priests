-- Tech Priests 0.1.249
-- Editable behavior call layer for idle Tech-Priest-to-player conversations.
-- This is separate from priest-priest conversation behavior so player-facing
-- chatter can be edited without digging through the main runtime file.

TECH_PRIESTS_IDLE_PLAYER_CONVERSATIONS_MODULE_0249 = true

function tech_priests_idle_player_conversations_cancel_0249(pair, reason)
  if not pair then return false end
  local had = pair.idle_player_conversation_0181 ~= nil
  if tech_priests_clear_idle_player_conversation_0181 then pcall(function() tech_priests_clear_idle_player_conversation_0181(pair) end) end
  pair.idle_player_conversation_0181 = nil
  pair.idle_player_conversation_next_approach_command_tick_0181 = nil
  if had and reason and tech_priests_0246_log then
    tech_priests_0246_log(pair, "idle-player-conversation-cancel", "reason=" .. tostring(reason))
  end
  return had and true or false
end

function tech_priests_idle_player_conversations_higher_priority_visible_0249(pair)
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

tech_priests_original_try_start_idle_player_conversation_0249 = tech_priests_original_try_start_idle_player_conversation_0249 or tech_priests_try_start_idle_player_conversation_0181
function tech_priests_try_start_idle_player_conversation_0181(pair)
  if tech_priests_idle_player_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_player_conversations_cancel_0249(pair, "start-denied-higher-priority-work")
    return false
  end
  if not tech_priests_original_try_start_idle_player_conversation_0249 then return false end
  return tech_priests_original_try_start_idle_player_conversation_0249(pair)
end

tech_priests_original_start_idle_player_conversation_0249 = tech_priests_original_start_idle_player_conversation_0249 or tech_priests_start_idle_player_conversation_0181
function tech_priests_start_idle_player_conversation_0181(pair, player, context)
  if tech_priests_idle_player_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_player_conversations_cancel_0249(pair, "start-denied-higher-priority-work")
    return false
  end
  if not tech_priests_original_start_idle_player_conversation_0249 then return false end
  return tech_priests_original_start_idle_player_conversation_0249(pair, player, context)
end

tech_priests_original_update_idle_player_conversation_0249 = tech_priests_original_update_idle_player_conversation_0249 or tech_priests_update_idle_player_conversation_0181
function tech_priests_update_idle_player_conversation_0181(pair)
  if tech_priests_idle_player_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_player_conversations_cancel_0249(pair, "update-cancel-higher-priority-work")
    return false
  end
  if not tech_priests_original_update_idle_player_conversation_0249 then return false end
  return tech_priests_original_update_idle_player_conversation_0249(pair)
end

function tech_priests_idle_player_conversations_tick_0249(pair)
  if not pair then return false end
  if tech_priests_idle_player_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_player_conversations_cancel_0249(pair, "tick-cancel-higher-priority-work")
    return false
  end
  if tech_priests_pair_has_player_conversation_0181 and tech_priests_pair_has_player_conversation_0181(pair) then
    return tech_priests_update_idle_player_conversation_0181(pair) and true or false
  end
  return false
end

tech_priests_original_tick_pair_idle_player_conversations_0249 = tech_priests_original_tick_pair_idle_player_conversations_0249 or tick_pair
function tick_pair(pair)
  if tech_priests_idle_player_conversations_tick_0249(pair) then return true end
  return tech_priests_original_tick_pair_idle_player_conversations_0249(pair)
end
