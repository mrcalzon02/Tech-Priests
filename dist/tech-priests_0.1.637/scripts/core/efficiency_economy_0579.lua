-- scripts/core/efficiency_economy_0579.lua
-- Tech Priests 0.1.579
--
-- Event-indexed station catalog economy. This module does not choose work,
-- reserve tasks, move priests, mine, repair, consecrate, or craft. It is a
-- cache/index service for station catalog scans: once a cell has been scanned,
-- later station catalog sweeps can reuse the indexed entity set instead of
-- calling surface.find_entities_filtered again. Build/mine/death events mark
-- cells dirty and update the index so normal world changes invalidate the cache.

local M = {}
M.version = "0.1.606"
M.storage_key = "efficiency_economy_0579"
M.cell_size = 32
M.known_keep_ticks = 60 * 60 * 20
M.cleanup_interval = 60 * 17
M.max_indexed_entities_per_area = 2048

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function lower(v) return string.lower(tostring(v or "")) end

local function surface_key(surface)
  if not surface then return "nil" end
  return tostring(surface.index or surface.name or "surface")
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or {x=0,y=0}
  return surface_key(entity.surface) .. ":" .. tostring(entity.name or entity.type or "?") .. ":" .. tostring(math.floor((p.x or 0)*10)) .. ":" .. tostring(math.floor((p.y or 0)*10))
end

local function cell_xy(pos)
  return math.floor((pos.x or pos[1] or 0) / M.cell_size), math.floor((pos.y or pos[2] or 0) / M.cell_size)
end

local function cell_key(cx, cy) return tostring(cx) .. ":" .. tostring(cy) end

local function area_cells(area)
  local lt = area and area[1] or {0,0}
  local rb = area and area[2] or {0,0}
  local x1, y1 = cell_xy({x = lt.x or lt[1] or 0, y = lt.y or lt[2] or 0})
  local x2, y2 = cell_xy({x = rb.x or rb[1] or 0, y = rb.y or rb[2] or 0})
  if x2 < x1 then x1,x2 = x2,x1 end
  if y2 < y1 then y1,y2 = y2,y1 end
  return x1,y1,x2,y2
end

local function in_area(entity, area)
  if not valid(entity) then return false end
  local p = entity.position or {x=0,y=0}
  local lt, rb = area and area[1] or nil, area and area[2] or nil
  if not (lt and rb) then return true end
  local x, y = p.x or 0, p.y or 0
  local ltx, lty = lt.x or lt[1] or 0, lt.y or lt[2] or 0
  local rbx, rby = rb.x or rb[1] or 0, rb.y or rb[2] or 0
  if rbx < ltx then ltx, rbx = rbx, ltx end
  if rby < lty then lty, rby = rby, lty end
  return x >= ltx and x <= rbx and y >= lty and y <= rby
end

local function is_noise_entity(entity)
  if not valid(entity) then return true end
  local t = entity.type
  if t == "character" or t == "player" then return true end
  if t == "transport-belt" or t == "underground-belt" or t == "splitter" or t == "loader" or t == "loader-1x1" or t == "linked-belt" then return true end
  return false
end

local function should_index(entity)
  if is_noise_entity(entity) then return false end
  -- Keep this broad because the station catalog counts ordinary machines,
  -- storage, resources, mineable rocks, and subordinate infrastructure.
  return true
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      use_indexed_catalog_cells = true,
      surfaces = {},
      entity_cells = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.use_indexed_catalog_cells == nil then r.use_indexed_catalog_cells = true end
  r.surfaces = r.surfaces or {}
  r.entity_cells = r.entity_cells or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 48 do table.remove(r.recent, 1) end
end

local function surface_index(root, surface)
  local s = surface_key(surface)
  root.surfaces[s] = root.surfaces[s] or { cells = {}, dirty = {} }
  root.surfaces[s].cells = root.surfaces[s].cells or {}
  root.surfaces[s].dirty = root.surfaces[s].dirty or {}
  return root.surfaces[s]
end

local function cell_record(sidx, ck)
  local rec = sidx.cells[ck]
  if type(rec) ~= "table" then
    rec = { known_tick = -1, entities = {} }
    sidx.cells[ck] = rec
  end
  rec.entities = rec.entities or {}
  return rec
end

local function remove_entity_key(root, key)
  local old = key and root.entity_cells[key]
  if type(old) == "table" then
    local sidx = root.surfaces[old.surface]
    local rec = sidx and sidx.cells and sidx.cells[old.cell]
    if rec and rec.entities then rec.entities[key] = nil end
    root.entity_cells[key] = nil
    stat("entity_removed")
  end
end

function M.index_entity(entity, reason)
  local r = M.root()
  if r.enabled == false or not should_index(entity) then return false end
  local key = entity_key(entity)
  if not key then return false end
  remove_entity_key(r, key)
  local cx, cy = cell_xy(entity.position or {x=0,y=0})
  local ck = cell_key(cx, cy)
  local sidx = surface_index(r, entity.surface)
  local rec = cell_record(sidx, ck)
  rec.known_tick = math.max(tonumber(rec.known_tick or -1) or -1, now())
  rec.entities[key] = entity
  r.entity_cells[key] = { surface = surface_key(entity.surface), cell = ck, tick = now(), name = entity.name, type = entity.type }
  stat("entity_indexed")
  if reason then r.stats["entity_indexed_" .. tostring(reason)] = (r.stats["entity_indexed_" .. tostring(reason)] or 0) + 1 end
  return true
end

local function mark_cell_dirty(surface, cx, cy, reason)
  local r = M.root()
  if r.enabled == false then return end
  local sidx = surface_index(r, surface)
  local ck = cell_key(cx, cy)
  sidx.dirty[ck] = { tick = now(), reason = tostring(reason or "dirty") }
  stat("cell_dirty_marks")
end

function M.mark_entity_dirty(entity, reason)
  if not valid(entity) then return end
  local cx, cy = cell_xy(entity.position or {x=0,y=0})
  mark_cell_dirty(entity.surface, cx, cy, reason)
end

function M.note_area_scan(surface, area, entities)
  local r = M.root()
  if r.enabled == false then return false end
  local sidx = surface_index(r, surface)
  local x1,y1,x2,y2 = area_cells(area)
  for cx=x1,x2 do
    for cy=y1,y2 do
      local ck = cell_key(cx, cy)
      local rec = cell_record(sidx, ck)
      rec.known_tick = now()
      sidx.dirty[ck] = nil
    end
  end
  local indexed = 0
  if type(entities) == "table" then
    for _, entity in pairs(entities) do
      if valid(entity) and in_area(entity, area) and M.index_entity(entity, "area-scan") then
        indexed = indexed + 1
        if indexed >= M.max_indexed_entities_per_area then break end
      end
    end
  end
  stat("area_scans_noted"); metric("direct_surface_scans",1); metric("scans_attempted",1)
  stat("area_scan_entities_indexed", indexed)
  return true
end

function M.entities_for_area(surface, area)
  local r = M.root()
  if r.enabled == false or r.use_indexed_catalog_cells == false then return nil end
  local sidx = r.surfaces[surface_key(surface)]
  if not (sidx and sidx.cells) then stat("area_index_miss_no_surface"); metric("indexed_cache_misses",1); return nil end
  local x1,y1,x2,y2 = area_cells(area)
  local out = {}
  local seen = {}
  for cx=x1,x2 do
    for cy=y1,y2 do
      local ck = cell_key(cx, cy)
      local rec = sidx.cells[ck]
      local dirty = sidx.dirty and sidx.dirty[ck]
      if not rec or (tonumber(rec.known_tick or -1) or -1) < 0 or dirty then
        stat("area_index_miss_dirty_or_unknown"); metric("indexed_cache_misses",1)
        return nil
      end
      for key, entity in pairs(rec.entities or {}) do
        if not valid(entity) then
          rec.entities[key] = nil
          r.entity_cells[key] = nil
          stat("invalid_entity_pruned_inline")
        elseif not seen[key] and in_area(entity, area) and should_index(entity) then
          seen[key] = true
          out[#out + 1] = entity
          if #out >= M.max_indexed_entities_per_area then break end
        end
      end
    end
  end
  stat("area_index_hits"); metric("indexed_cache_hits",1); metric("scans_redirected_to_cache",1)
  stat("area_index_entities_returned", #out)
  return out
end

function M.cleanup()
  local r = M.root()
  if r.enabled == false then return end
  local removed_cells, removed_entities = 0, 0
  for sname, sidx in pairs(r.surfaces or {}) do
    for ck, rec in pairs(sidx.cells or {}) do
      local live = 0
      for key, entity in pairs(rec.entities or {}) do
        if not valid(entity) then
          rec.entities[key] = nil
          r.entity_cells[key] = nil
          removed_entities = removed_entities + 1
        else
          live = live + 1
        end
      end
      if live == 0 and now() - (tonumber(rec.known_tick or 0) or 0) > M.known_keep_ticks then
        sidx.cells[ck] = nil
        removed_cells = removed_cells + 1
      end
    end
    for ck, dirty in pairs(sidx.dirty or {}) do
      if type(dirty) ~= "table" or now() - (tonumber(dirty.tick or 0) or 0) > M.known_keep_ticks then sidx.dirty[ck] = nil end
    end
  end
  if removed_cells > 0 then stat("cells_pruned", removed_cells) end
  if removed_entities > 0 then stat("invalid_entities_pruned", removed_entities) end
  stat("cleanup_runs")
end

local function install_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local events = defines and defines.events or nil
  if not (R and R.on_event and events) then return false end
  R.on_event({ events.on_built_entity, events.on_robot_built_entity, events.script_raised_built, events.script_raised_revive }, function(event)
    local e = event and (event.entity or event.created_entity)
    if valid(e) then M.mark_entity_dirty(e, "built"); M.index_entity(e, "built") end
  end, nil, { owner="efficiency_economy_0579", category="index", note="index built entities for catalog reuse" })
  R.on_event({ events.on_player_mined_entity, events.on_robot_mined_entity, events.on_entity_died, events.script_raised_destroy }, function(event)
    local e = event and event.entity
    if valid(e) then
      M.mark_entity_dirty(e, "removed")
      local r = M.root(); remove_entity_key(r, entity_key(e))
    end
  end, nil, { owner="efficiency_economy_0579", category="index", note="invalidate removed entities for catalog reuse" })
  remember("events", "build/remove dirty index hooks installed")
  return true
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0579") end end)
  commands.add_command("tp-efficiency-economy-0579", "Tech Priests 0.1.579 event-indexed catalog economy. Params: on/off/index-on/index-off/clear/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false
    elseif p == "index-on" then r.use_indexed_catalog_cells = true elseif p == "index-off" then r.use_indexed_catalog_cells = false
    elseif p == "clear" then r.surfaces = {}; r.entity_cells = {}; r.stats.clears = (r.stats.clears or 0) + 1 end
    local cells, entities, dirty = 0, 0, 0
    for _, sidx in pairs(r.surfaces or {}) do
      for _, rec in pairs(sidx.cells or {}) do cells = cells + 1; for _ in pairs(rec.entities or {}) do entities = entities + 1 end end
      for _ in pairs(sidx.dirty or {}) do dirty = dirty + 1 end
    end
    local msg = "[tp-efficiency-economy-0579] enabled="..safe(r.enabled).." index="..safe(r.use_indexed_catalog_cells).." cells="..safe(cells).." entities="..safe(entities).." dirty="..safe(dirty).." hits="..safe(r.stats.area_index_hits or 0).." misses="..safe(r.stats.area_index_miss_dirty_or_unknown or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  install_events()
  install_command()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.cleanup_interval, function() M.cleanup() end, { owner="efficiency_economy_0579", category="economy", priority="last", note="prune stale catalog cell index entries" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.cleanup_interval, function() M.cleanup() end)
  end
  _G.tech_priests_efficiency_0579_entities_for_area = function(surface, area) return M.entities_for_area(surface, area) end
  _G.tech_priests_efficiency_0579_note_area_scan = function(surface, area, entities) return M.note_area_scan(surface, area, entities) end
  _G.TechPriestsEfficiencyEconomy0579 = M
  if log then log("[Tech-Priests 0.1.579] event-indexed catalog economy installed") end
  return true
end

return M
