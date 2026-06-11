-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1686-1706
local function add_conversations_display(parent, pair)
  local profile = profile_for_pair(pair)
  add_label(parent, "Noospheric discourse reliquary")
  if profile then
    add_label(parent, "Current temperament: " .. tostring(profile.mental_state or "unvoiced"))
    add_label(parent, "Declared intent after discourse: " .. tostring(profile.plan or "resume useful rites"))
    add_label(parent, "Last exchange: " .. tostring(profile.last_conversation_kind_0412 or "none-recorded") .. " with " .. tostring(profile.last_conversation_with_0412 or "no interlocutor"))
    add_label(parent, "Last note: " .. tostring(profile.last_conversation_summary_0412 or "no archived utterance"))
  else
    add_label(parent, "  No priest persona slate is bound to this station yet.")
  end
  add_label(parent, "Recent vox keys")
  local rows = recent_conversation_rows(pair, 12)
  if #rows == 0 then add_label(parent, "  No recent speech keys have been burned into the slate.") end
  for i, row in ipairs(rows) do
    add_label(parent, "  " .. tostring(i) .. ". " .. tostring(row.key or row.text or row.summary or row))
  end
  local locked = pair and (pair.idle_conversation or pair.idle_conversation_listener_until or pair.idle_conversation_speaker_station_unit or pair.idle_conversation_lock_position_0179)
  add_label(parent, "Conversation clamp: " .. (locked and "active; priest attention reserved for speech" or "inactive; priest may return to labor"))
end

