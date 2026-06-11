-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2133-2150
local function add_recent_notes_plaque_0494(parent, pair, profile)
  local plaque = add_plaque_0494(parent, "Recent Noospheric Notations")
  if profile then
    add_kv_0494(plaque, "Mental state", tostring(profile.mental_state or "unrecorded"))
    add_kv_0494(plaque, "Personal plan", tostring(profile.plan or "awaits command"))
    add_kv_0494(plaque, "Personal goal", tostring(profile.goal or "become slightly less disappointed"))
    if profile.last_conversation_tick_0412 then
      add_kv_0494(plaque, "Last discourse", tostring(profile.last_conversation_kind_0412 or "conversation") .. " with " .. tostring(profile.last_conversation_with_0412 or "unknown") .. " at tick " .. tostring(profile.last_conversation_tick_0412))
      add_kv_0494(plaque, "Last exchange", tostring(profile.last_conversation_summary_0412 or "no summary"))
    else
      add_subtle_note_0494(plaque, "No recent discourse recorded.")
    end
  else
    add_subtle_note_0494(plaque, "No recent notations available.")
  end
  return plaque
end

