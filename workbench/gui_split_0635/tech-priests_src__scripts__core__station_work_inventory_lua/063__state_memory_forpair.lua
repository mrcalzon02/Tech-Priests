-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 796-808
local function state_memory_for(pair)
  local r = state_memory_root()
  local key = station_key(pair)
  if not (r and key and key ~= "?") then return nil end
  r.by_station[key] = r.by_station[key] or { history = {}, projections = {}, recent_conversation_keys = {} }
  local mem = r.by_station[key]
  mem.history = mem.history or {}
  mem.projections = mem.projections or {}
  mem.recent_conversation_keys = mem.recent_conversation_keys or {}
  return mem
end


