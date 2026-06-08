-- scripts/core/station_network_overlay.lua
-- Tech Priests 0.1.354 protected station radius + connection overlay.
--
-- This module deliberately owns only the fragile player-facing station network
-- visuals that were getting lost during unrelated behavior/consecration passes:
--   * Cogitator Station operating-radius circles,
--   * hierarchy / peer station connection lines,
--   * placement-time station radius preview while holding a station item.
--
-- Keep this file small, boring, and independent.  Do not add priest behavior,
-- catalog logic, consecration logic, chatter, or acquisition logic here.

local Overlay = {}
Overlay.version = "0.1.464"
Overlay.storage_key = "station_network_overlay_0354"
Overlay.refresh_period = 30
Overlay.time_to_live = 210
Overlay.redraw_period = 150
Overlay.draw_large_filled_radius = false
Overlay.max_lines = 160
Overlay.max_circles = 160

local function valid(e) return e and e.valid end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Overlay.storage_key] = storage.tech_priests[Overlay.storage_key] or {
    version = Overlay.version,
    enabled = true,
    radius_enabled = true,
    connections_enabled = true,
    objects_by_player = {},
    signature_by_player = {},
    last_draw_tick_by_player = {},
    stats = {}
  }
  local root = storage.tech_priests[Overlay.storage_key]
  root.version = Overlay.version
  root.objects_by_player = root.objects_by_player or {}
  root.signature_by_player = root.signature_by_player or {}
  root.last_draw_tick_by_player = root.last_draw_tick_by_player or {}
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  -- 0.1.464: restore the radius *ring* the player wanted to keep, but keep
  -- filled/full-disk illumination banned.  The failure was the green filled
  -- station-light / radar-plate effect, not the perimeter circle or links.
  if root.radius_enabled == nil or root.radius_force_disabled_0463 then root.radius_enabled = true end
  root.radius_force_disabled_0463 = nil
  if root.connections_enabled == nil then root.connections_enabled = true end
  return root
end

local function pairs_table()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil
end

local function pair_rank(pair)
  if _G.tech_priests_get_pair_tier_rank then
    local ok, rank = pcall(_G.tech_priests_get_pair_tier_rank, pair)
    if ok and tonumber(rank) then return tonumber(rank) end
  end
  local name = pair and pair.station and pair.station.valid and pair.station.name or tostring(pair and pair.tier or "")
  if name:find("void", 1, true) then return 5 end
  if name:find("planetary", 1, true) or name:find("magos", 1, true) then return 4 end
  if name:find("senior", 1, true) then return 3 end
  if name:find("intermediate", 1, true) then return 2 end
  return 1
end

local function radius_for(pair)
  if pair and pair.station and pair.station.valid and _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, tonumber(r)) end
  end
  return tonumber(pair and pair.radius) or 24
end

local function distance_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
  local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
  return dx * dx + dy * dy
end

local function held_station_name(player)
  if not (player and player.valid) then return nil end
  local stack = player.cursor_stack
  if stack and stack.valid_for_read then
    local name = tostring(stack.name or "")
    if name:find("cogitator%-station") then return name end
  end
  return nil
end

local function entity_is_station_or_priest(entity)
  if not valid(entity) then return false end
  local n = tostring(entity.name or "")
  return n:find("cogitator%-station") ~= nil or n:find("tech%-priest") ~= nil or n:find("magos%-tech%-priest") ~= nil
end

local function overlay_signature(player)
  if not (player and player.valid) then return nil end
  -- 0.1.453/0.1.461: do not light every existing station while the player is merely holding
  -- a station ghost/item for placement.  Placement preview belongs to Factorio; full
  -- radius illumination is hover/selection only.
  local selected = player.selected
  if selected and selected.valid and entity_is_station_or_priest(selected) then
    local surface = selected.surface and (selected.surface.index or selected.surface.name) or "surface"
    return tostring(surface) .. ":" .. tostring(selected.unit_number or selected.name or "selected")
  end
  return nil
end

local function player_wants_overlay(player)
  return overlay_signature(player) ~= nil
end

local function safe_destroy(obj)
  if obj then pcall(function() if obj.valid then obj.destroy() end end) end
end

local function clear_player(root, player_index)
  local list = root.objects_by_player[player_index]
  if list then for _, obj in pairs(list) do safe_destroy(obj) end end
  root.objects_by_player[player_index] = nil
  if root.signature_by_player then root.signature_by_player[player_index] = nil end
  if root.last_draw_tick_by_player then root.last_draw_tick_by_player[player_index] = nil end
end

local function list_still_valid(list)
  if not list or #list == 0 then return false end
  for _, obj in pairs(list) do
    local ok, is_valid = pcall(function() return obj and obj.valid end)
    if not (ok and is_valid) then return false end
  end
  return true
end

local function collect_pairs_for_player(player)
  local out = {}
  if not (player and player.valid and player.surface and player.force) then return out end
  for _, pair in pairs(pairs_table()) do
    if pair and pair.station and pair.station.valid and pair.station.force == player.force and pair.station.surface == player.surface then
      out[#out + 1] = pair
    end
  end
  table.sort(out, function(a, b)
    local ar, br = pair_rank(a), pair_rank(b)
    if ar ~= br then return ar > br end
    return (station_unit(a) or 0) < (station_unit(b) or 0)
  end)
  return out
end

local function connected(a, b)
  if not (a and b and a.station and a.station.valid and b.station and b.station.valid) then return false end
  if a.station.force ~= b.station.force or a.station.surface ~= b.station.surface then return false end
  local ar = radius_for(a)
  local br = radius_for(b)
  local d = distance_sq(a.station.position, b.station.position)
  local maxr = math.max(ar, br)
  return d <= (maxr * 3) * (maxr * 3)
end

local function connection_key(a, b)
  local au = station_unit(a) or (a.station and a.station.valid and a.station.unit_number) or 0
  local bu = station_unit(b) or (b.station and b.station.valid and b.station.unit_number) or 0
  if au > bu then au, bu = bu, au end
  return tostring(au) .. ":" .. tostring(bu)
end

local function draw_line(player, from, to, color, width, out)
  if not rendering then return nil end
  local ok, obj = pcall(function()
    return rendering.draw_line({
      surface = player.surface,
      from = from,
      to = to,
      color = color,
      width = width or 1,
      time_to_live = Overlay.time_to_live,
      players = { player }
    })
  end)
  if ok and obj then out[#out + 1] = obj; return obj end
  return nil
end

local function draw_dashed_line(player, from, to, color, width, out)
  local dx = to.x - from.x
  local dy = to.y - from.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local segments = math.max(6, math.min(48, math.floor(dist / 3)))
  for i = 0, segments - 1 do
    if (i % 2) == 0 then
      local a = i / segments
      local b = math.min(1, (i + 0.58) / segments)
      draw_line(player,
        { x = from.x + dx * a, y = from.y + dy * a },
        { x = from.x + dx * b, y = from.y + dy * b },
        color,
        math.max(width or 1, 2),
        out)
    end
  end
end

local function best_connection_for(subject, list)
  if not (subject and subject.station and subject.station.valid) then return nil, nil end
  local sr = pair_rank(subject)
  local best_superior, best_superior_score = nil, nil
  local best_equal, best_equal_score = nil, nil
  local best_fallback, best_fallback_score = nil, nil
  for _, other in pairs(list) do
    if other ~= subject and connected(subject, other) then
      local orank = pair_rank(other)
      local d = distance_sq(subject.station.position, other.station.position)
      if orank > sr then
        local score = d - (orank * 0.01)
        if not best_superior_score or score < best_superior_score then best_superior, best_superior_score = other, score end
      elseif orank == sr then
        if not best_equal_score or d < best_equal_score then best_equal, best_equal_score = other, d end
      else
        if not best_fallback_score or d < best_fallback_score then best_fallback, best_fallback_score = other, d end
      end
    end
  end
  if best_superior then return best_superior, "hierarchy" end
  if best_equal then return best_equal, "equal" end
  if best_fallback then return best_fallback, "fallback" end
  return nil, nil
end

local function draw_radius(player, pair, out)
  if not (rendering and pair and pair.station and pair.station.valid) then return false end
  local radius = radius_for(pair)
  local color = { r = 0.25, g = 0.95, b = 0.25, a = 0.14 }
  if pair_rank(pair) >= 4 then
    color = { r = 0.95, g = 0.90, b = 0.20, a = 0.16 }
  end

  -- 0.1.464: perimeter ring only.  No filled circle, no draw_light, no sprite
  -- scaled to station radius.  This preserves the readable radar/operating range
  -- circle without recreating the flashing green dinner plate.
  local ok, circle = pcall(function()
    return rendering.draw_circle({
      surface = player.surface,
      target = pair.station,
      radius = radius,
      color = color,
      width = 1,
      filled = false,
      draw_on_ground = true,
      time_to_live = Overlay.time_to_live,
      players = { player }
    })
  end)
  if ok and circle then out[#out + 1] = circle; return true end
  return false
end

local function draw_connections(player, list, out)
  local gray = { r = 0.72, g = 0.72, b = 0.72, a = 0.30 }
  local equal = { r = 1.00, g = 0.72, b = 0.16, a = 0.42 }
  local used = {}
  local superior_for = {}
  local drawn = 0

  for _, subject in pairs(list) do
    local target, mode = best_connection_for(subject, list)
    if target and mode == "hierarchy" then
      superior_for[station_unit(subject) or 0] = station_unit(target) or 0
      local key = connection_key(subject, target)
      if not used[key] then
        used[key] = true
        draw_line(player, subject.station.position, target.station.position, gray, 1, out)
        drawn = drawn + 1
      end
    end
    if drawn >= Overlay.max_lines then return drawn end
  end

  for i = 1, #list do
    local a = list[i]
    for j = i + 1, #list do
      local b = list[j]
      if connected(a, b) and pair_rank(a) == pair_rank(b) then
        local au, bu = station_unit(a) or 0, station_unit(b) or 0
        local asup, bsup = superior_for[au], superior_for[bu]
        if (asup and bsup and asup == bsup) or ((not asup) and (not bsup)) then
          local key = connection_key(a, b)
          if not used[key] then
            used[key] = true
            draw_dashed_line(player, a.station.position, b.station.position, equal, 2, out)
            drawn = drawn + 1
            if drawn >= Overlay.max_lines then return drawn end
          end
        end
      end
    end
  end

  for _, subject in pairs(list) do
    local su = tostring(station_unit(subject) or 0)
    local has_line = false
    for key in pairs(used) do
      if key:find(su, 1, true) then has_line = true; break end
    end
    if not has_line then
      local target, mode = best_connection_for(subject, list)
      if target then
        local key = connection_key(subject, target)
        if not used[key] then
          used[key] = true
          if mode == "equal" then
            draw_dashed_line(player, subject.station.position, target.station.position, equal, 2, out)
          else
            draw_line(player, subject.station.position, target.station.position, gray, 1, out)
          end
          drawn = drawn + 1
          if drawn >= Overlay.max_lines then return drawn end
        end
      end
    end
  end
  return drawn
end

function Overlay.refresh_for_player(player)
  local root = ensure_root()
  if not (player and player.valid) then return end
  local sig = overlay_signature(player)
  if not (root.enabled and sig) then
    clear_player(root, player.index)
    return
  end

  local now_tick = game and game.tick or 0
  local last_sig = root.signature_by_player[player.index]
  local last_draw = tonumber(root.last_draw_tick_by_player[player.index]) or -999999
  local existing = root.objects_by_player[player.index]
  if last_sig == sig and list_still_valid(existing) and (now_tick - last_draw) < Overlay.redraw_period then
    root.stats.last_refresh_tick = now_tick
    root.stats.last_player = player.name
    root.stats.skipped_stable_redraws = (root.stats.skipped_stable_redraws or 0) + 1
    return
  end

  clear_player(root, player.index)
  local list = collect_pairs_for_player(player)
  local out = {}
  local circle_count = 0
  if root.radius_enabled then
    for _, pair in pairs(list) do
      if circle_count >= Overlay.max_circles then break end
      if draw_radius(player, pair, out) then circle_count = circle_count + 1 end
    end
  end
  local line_count = 0
  if root.connections_enabled then line_count = draw_connections(player, list, out) end
  root.objects_by_player[player.index] = out
  root.signature_by_player[player.index] = sig
  root.last_draw_tick_by_player[player.index] = now_tick
  root.stats.last_refresh_tick = now_tick
  root.stats.last_player = player.name
  root.stats.last_circles = circle_count
  root.stats.last_lines = line_count
  root.stats.last_objects = #out
end

function Overlay.refresh_all()
  if not game or not game.connected_players then return end
  for _, player in pairs(game.connected_players) do Overlay.refresh_for_player(player) end
end

function Overlay.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-station-overlay-0355", "Tech Priests: protected station radius/connection overlay status/toggle/refresh.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      if p == "radius-on" then root.radius_enabled = true; root.radius_force_disabled_0463 = nil end
      if p == "radius-off" then root.radius_enabled = false end
      if p == "lines-on" then root.connections_enabled = true end
      if p == "lines-off" then root.connections_enabled = false end
      if p == "refresh" then Overlay.refresh_all() end
      player.print("[Tech Priests 0.1.354] station overlay enabled=" .. tostring(root.enabled)
        .. " radius=" .. tostring(root.radius_enabled)
        .. " lines=" .. tostring(root.connections_enabled)
        .. " circles=" .. tostring(root.stats.last_circles or 0)
        .. " lines-drawn=" .. tostring(root.stats.last_lines or 0)
        .. " objects=" .. tostring(root.stats.last_objects or 0))
    end)
  end)
end

function Overlay.install()
  if Overlay._installed then return true end
  Overlay._installed = true
  local root = ensure_root()
  -- Purge any old persistent radius objects stored by earlier versions on load.
  for player_index, list in pairs(root.objects_by_player or {}) do
    if list then for _, obj in pairs(list) do safe_destroy(obj) end end
    root.objects_by_player[player_index] = nil
  end
  root.signature_by_player = {}
  root.last_draw_tick_by_player = {}
  _G.tech_priests_0355_refresh_station_network_overlay = Overlay.refresh_all
  _G.tech_priests_0355_refresh_station_network_overlay_for_player = Overlay.refresh_for_player
  if script and script.on_nth_tick then
    script.on_nth_tick(Overlay.refresh_period, function() Overlay.refresh_all() end)
  end
  if script and defines and defines.events and script.on_event then
    if defines.events.on_player_cursor_stack_changed then
      script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if player then Overlay.refresh_for_player(player) end
      end)
    end
    if defines.events.on_selected_entity_changed then
      script.on_event(defines.events.on_selected_entity_changed, function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if player then Overlay.refresh_for_player(player) end
      end)
    end
  end
  Overlay.register_commands()
  if log then log("[Tech-Priests 0.1.464] protected station network overlay installed; radius ring and station links enabled; filled disks disabled") end
  return true
end

return Overlay
