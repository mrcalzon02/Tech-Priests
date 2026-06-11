-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1315-1332
local function add_conversation_key_display(parent, pair)
  add_label(parent, "Recent conversation keys")
  add_label(parent, "  Shows recently used chatter keys so the pair can avoid immediately repeating what it has said and to whom.")
  local rows = recent_conversation_rows(pair, 5)
  if #rows == 0 then
    for i = 1, 5 do add_label(parent, "    #" .. tostring(i) .. " EMPTY CONVERSATION KEY SLOT") end
    return
  end
  for i = 1, 5 do
    local rec = rows[i]
    if rec then
      add_label(parent, "    #" .. tostring(i) .. " " .. tostring(rec.channel or "?") .. " | " .. tostring(rec.speaker or "?") .. " -> " .. tostring(rec.target or "?") .. " | key=" .. tostring(rec.key or "?") .. " [" .. task_age_text(rec.tick) .. "]")
    else
      add_label(parent, "    #" .. tostring(i) .. " EMPTY CONVERSATION KEY SLOT")
    end
  end
end

