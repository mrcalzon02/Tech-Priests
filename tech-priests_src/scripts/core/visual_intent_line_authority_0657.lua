-- scripts/core/visual_intent_line_authority_0657.lua
-- Tech Priests 0.1.657
--
-- Commandless visual intent line authority.
--
-- The selected/hovered orange pair line used to mean only "station owns this
-- priest."  During physical work that is misleading: the line must point from
-- the priest to the concrete active leaf target, because that is the line the
-- player reads as movement intent.  This module patches network_visuals so its
-- selected pair link is an intent line whenever active_leaf_task_0655 or a live
-- movement request exists.

local M = {}
M.version = "0.1.657"
M.storage_key = "visual_intent_line_authority_0657"
M.refresh_period = 5
M.ttl = 30
M.max_drawn = 64

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function priest_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_priest or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, patched = false, stats = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end

local function network_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.network_visuals_0333 = storage.tech_priests.network_visuals_0333 or { pair_link_objects_by_player = {}, stats = {} }
  local r = storage.tech_priests.network_visuals_0333
  r.pair_link_objects_by_player = r.pair_link_objects_by_player or {}
  r.stats = r.stats or {}
  return r
end

local function safe_destroy(obj)
  if not obj then return end
  pcall(function() if obj.valid then obj.destroy() end end)
end
local function clear_player(player_index)
  local nr = network_root()
  local list = nr.pair_link_objects_by_player[player_index]
  if list then for _, obj in pairs(list) do safe_destroy(obj) end end
  nr.pair_link_objects_by_player[player_index] = nil
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and selected.unit_number then
    return pair_map()[selected.unit_number] or priest_map()[selected.unit_number]
  end
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  return nil
end

local function active_target(pair)
  if not valid_pair(pair) then return nil end
  local leaf = pair.active_leaf_task_0655 or pair.actual_task_status_0655
  if type(leaf) == "table" and leaf.x and leaf.y and now() - (tonumber(leaf.tick) or 0) <= 240 then
    local e = pair.current_work_target_0655 or pair.current_work_target_0654 or pair.target
    if valid(e) then return { entity = e, label = leaf.label or leaf.phase or "active task", kind = leaf.family or "leaf" } end
    return { position = { x = leaf.x, y = leaf.y }, label = leaf.label or leaf.phase or "active task", kind = leaf.family or "leaf" }
  end
  local req = pair.movement_request_0418
  if type(req) == "table" and req.x and req.y and (not req.expires_tick or req.expires_tick >= now()) then
    return { position = { x = req.x, y = req.y }, label = req.reason or req.owner or "movement", kind = "movement" }
  end
  local lf = pair.logistics_fetch_0527 or pair.logistics_fetch_0526
  if type(lf) == "table" and valid(lf.source) and lf.phase == "moving-to-source" then
    return { entity = lf.source, label = "Fetching " .. safe(lf.item), kind = "logistics" }
  end
  return nil
end

local function color_for(kind)
  if kind == "construction" then return { r = 0.30, g = 1.00, b = 0.45, a = 0.95 } end
  if kind == "consecration" then return { r = 0.55, g = 1.00, b = 0.95, a = 0.95 } end
  if kind == "logistics" then return { r = 1.00, g = 0.78, b = 0.18, a = 0.95 } end
  if kind == "acquisition" then return { r = 1.00, g = 0.55, b = 0.10, a = 0.95 } end
  return { r = 1.00, g = 0.62, b = 0.16, a = 0.85 }
end

local function draw_pair_for_player(player, pair, out)
  if not (player and player.valid and valid_pair(pair) and rendering and rendering.draw_line) then return end
  if pair.station.force ~= player.force or pair.station.surface ~= player.surface or pair.priest.surface ~= player.surface then return end
  local target = active_target(pair)
  if target then
    local color = color_for(target.kind)
    local spec = { surface = player.surface, from = { entity = pair.priest, offset = { 0, -0.85 } }, color = color, width = 3, time_to_live = M.ttl, players = { player } }
    if valid(target.entity) then spec.to = { entity = target.entity, offset = { 0, -0.25 } } else spec.to = target.position end
    local ok, obj = pcall(function() return rendering.draw_line(spec) end)
    if ok and obj then out[#out + 1] = obj end
    if rendering.draw_text and target.label then
      local ok2, txt = pcall(function() return rendering.draw_text({ surface = player.surface, target = valid(target.entity) and { entity = target.entity, offset = { 0, -1.15 } } or target.position, text = tostring(target.label), color = color, scale = 0.62, alignment = "center", time_to_live = M.ttl, players = { player } }) end)
      if ok2 and txt then out[#out + 1] = txt end
    end
    return
  end
  -- No active work target: draw a subdued home link only so ownership is still visible.
  local ok, obj = pcall(function()
    return rendering.draw_line({ surface = pair.station.surface, from = { entity = pair.station, offset = { 0, -0.20 } }, to = { entity = pair.priest, offset = { 0, -0.85 } }, color = { r = 0.55, g = 0.55, b = 0.55, a = 0.28 }, width = 1, time_to_live = M.ttl, players = { player } })
  end)
  if ok and obj then out[#out + 1] = obj end
end

function M.refresh_pair_links()
  local r = root(); if r.enabled == false then return end
  if not (game and game.connected_players and rendering) then return end
  local nr = network_root()
  local total = 0
  for _, player in pairs(game.connected_players) do
    if player and player.valid then
      clear_player(player.index)
      local out = {}
      local pair = selected_pair(player)
      if pair then
        draw_pair_for_player(player, pair, out)
      elseif nr.pair_link_always_on then
        for _, p in pairs(pair_map()) do
          draw_pair_for_player(player, p, out)
          if #out >= M.max_drawn then break end
        end
      end
      nr.pair_link_objects_by_player[player.index] = out
      total = total + #out
    end
  end
  nr.stats.pair_links_drawn = total
  nr.stats.pair_link_mode = "active-intent-line-0657"
  r.stats.drawn = total
  r.stats.last_tick = now()
end

local function patch_network_visuals()
  local ok, Visuals = pcall(require, "scripts.core.network_visuals")
  if not (ok and Visuals and type(Visuals) == "table") then return false end
  if Visuals.TECH_PRIESTS_0657_PATCHED then return true end
  Visuals.TECH_PRIESTS_0657_PRE_REFRESH_PAIR_LINKS = Visuals.refresh_pair_links
  Visuals.refresh_pair_links = M.refresh_pair_links
  Visuals.TECH_PRIESTS_0657_PATCHED = true
  root().patched = true
  if log then log("[Tech-Priests 0.1.657] network pair link patched: selected pair line now points to active leaf/movement target") end
  return true
end

function M.install()
  root(); patch_network_visuals(); _G.TechPriestsVisualIntentLineAuthority0657 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "visual_intent_line_authority_0657", category = "visuals", interval = M.refresh_period, priority = 25, budget = 4, fn = function(event, budget) patch_network_visuals(); M.refresh_pair_links(); return true end, note = "draw selected pair line to active work target, not station home" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.refresh_period, function() patch_network_visuals(); M.refresh_pair_links() end, { owner = "visual_intent_line_authority_0657", category = "visuals", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.refresh_period, function() patch_network_visuals(); M.refresh_pair_links() end) end end
  if log then log("[Tech-Priests 0.1.657] visual intent line authority installed") end
  return true
end

return M
