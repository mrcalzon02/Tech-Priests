-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1271-1278
local function recent_conversation_rows(pair, limit)
  if _G.tech_priests_0334_recent_conversation_keys_for_pair then
    local ok, rows = pcall(_G.tech_priests_0334_recent_conversation_keys_for_pair, pair, limit or 5)
    if ok and rows then return rows end
  end
  return {}
end

