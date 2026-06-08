-- scripts/core/alt_writ_visual_stability_0474.lua
-- Tech Priests 0.1.474
-- Single late visual authority for stable Cogitator station overlays:
--   * Alt-mode station writ icon over the Cogitator Station, not the priest.
--   * Stable radius/interstation/pair-link rendering with draw-before-destroy refresh.
--   * Restored held-station radius preview without filled disks or green flashes.

local M = {}
M.version = "0.1.489" -- retained storage key, hardened context gating
M.storage_key = "alt_writ_visual_stability_0474"
M.refresh_period = 20
M.redraw_period = 240
M.ttl = 720
M.max_pairs = 160
M.max_known_icons = 384

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, s = pcall(function() return tostring(v) end); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    station_alt_writ_enabled = true,
    stable_overlay_enabled = true,
    placement_preview_enabled = true,
    known_resource_alt_icons_enabled = true,
    objects_by_player = {},
    signature_by_player = {},
    last_draw_tick_by_player = {},
    stats = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  if root.station_alt_writ_enabled == nil then root.station_alt_writ_enabled = true end
  if root.stable_overlay_enabled == nil then root.stable_overlay_enabled = true end
  if root.placement_preview_enabled == nil then root.placement_preview_enabled = true end
  if root.known_resource_alt_icons_enabled == nil then root.known_resource_alt_icons_enabled = true end
  root.objects_by_player = root.objects_by_player or {}
  root.signature_by_player = root.signature_by_player or {}
  root.last_draw_tick_by_player = root.last_draw_tick_by_player or {}
  root.stats = root.stats or {}
  return root
end

local function pairs_table()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
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
  if pair and pair.station and pair.station.valid and _G.tech_priests_radar_operating_radius_0280 then
    local ok, r = pcall(_G.tech_priests_radar_operating_radius_0280, pair)
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

local function entity_is_station_or_priest(entity)
  if not valid(entity) then return false end
  local n = tostring(entity.name or "")
  return n:find("cogitator%-station") ~= nil or n:find("tech%-priest") ~= nil or n:find("magos%-tech%-priest") ~= nil
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

local function player_alt_enabled(player)
  if not (player and player.valid) then return false end
  local ok, value = pcall(function() return player.game_view_settings and player.game_view_settings.show_entity_info end)
  return ok and value == true
end

local function selected_pair_for_player(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  -- 0.1.489: visual overlays are strict selection/placement context only.
  -- Do not fall back to old "last opened / last inspected" pair helpers here;
  -- those stale helpers were enough to redraw station rings and junior link
  -- lines after the player had stopped hovering or holding a station.
  if not (selected and selected.valid) then return nil end
  if storage and storage.tech_priests then
    local unit = selected.unit_number
    local by_station = storage.tech_priests.pairs_by_station or {}
    local by_priest = storage.tech_priests.pairs_by_priest or {}
    if unit and by_station[unit] then return by_station[unit] end
    if unit and by_priest[unit] then return by_priest[unit] end
  end
  if _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, selected)
    if ok and pair then return pair end
  end
  return nil
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

local function destroy(obj)
  if obj then pcall(function() if obj.valid then obj.destroy() end end) end
end

local function destroy_list(list)
  if not list then return end
  for _, obj in pairs(list) do destroy(obj) end
end

local function list_valid(list)
  if not list or #list == 0 then return false end
  for _, obj in pairs(list) do
    local ok, is_valid = pcall(function() return obj and obj.valid end)
    if not (ok and is_valid) then return false end
  end
  return true
end

local function append(out, obj)
  if obj then out[#out + 1] = obj end
  return obj
end

local function draw_line(out, surface, from, to, color, width, players)
  if not (rendering and surface and players and #players > 0) then return nil end
  local ok, obj = pcall(function()
    return rendering.draw_line({
      surface = surface,
      from = from,
      to = to,
      color = color,
      width = width or 1,
      time_to_live = M.ttl,
      players = players,
    })
  end)
  if ok then return append(out, obj) end
  return nil
end

local function draw_dashed_line(out, surface, from, to, color, width, players)
  local dx = to.x - from.x
  local dy = to.y - from.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local segments = math.max(6, math.min(40, math.floor(dist / 3)))
  for i = 0, segments - 1 do
    if (i % 2) == 0 then
      local a = i / segments
      local b = math.min(1, (i + 0.58) / segments)
      draw_line(out, surface,
        { x = from.x + dx * a, y = from.y + dy * a },
        { x = from.x + dx * b, y = from.y + dy * b },
        color,
        math.max(width or 1, 2),
        players)
    end
  end
end

local function draw_circle(out, player, pair, faint)
  if not (rendering and player and player.valid and pair and pair.station and pair.station.valid) then return false end
  local rank = pair_rank(pair)
  local color
  if faint then
    color = { r = 0.72, g = 0.72, b = 0.72, a = 0.14 }
  elseif rank >= 4 then
    color = { r = 0.95, g = 0.88, b = 0.20, a = 0.26 }
  else
    color = { r = 0.25, g = 0.95, b = 0.25, a = 0.22 }
  end
  local ok, obj = pcall(function()
    return rendering.draw_circle({
      surface = player.surface,
      target = pair.station,
      radius = radius_for(pair),
      color = color,
      width = faint and 1 or 2,
      filled = false,
      draw_on_ground = true,
      time_to_live = M.ttl,
      players = { player },
    })
  end)
  if ok and obj then out[#out + 1] = obj; return true end
  return false
end

local function draw_connections(out, player, list)
  local gray = { r = 0.72, g = 0.72, b = 0.72, a = 0.42 }
  local equal = { r = 1.00, g = 0.72, b = 0.16, a = 0.62 }
  local used = {}
  local superior_for = {}
  local drawn = 0
  local players = { player }
  for _, subject in pairs(list) do
    local target, mode = best_connection_for(subject, list)
    if target and mode == "hierarchy" then
      superior_for[station_unit(subject) or 0] = station_unit(target) or 0
      local key = connection_key(subject, target)
      if not used[key] then
        used[key] = true
        draw_line(out, subject.station.surface, subject.station.position, target.station.position, gray, 1, players)
        drawn = drawn + 1
        if drawn >= M.max_pairs then return drawn end
      end
    end
  end
  for i = 1, #list do
    local a = list[i]
    for j = i + 1, #list do
      local b = list[j]
      if a and b and connected(a, b) and pair_rank(a) == pair_rank(b) then
        local au, bu = station_unit(a) or 0, station_unit(b) or 0
        local asup, bsup = superior_for[au], superior_for[bu]
        if (asup and bsup and asup == bsup) or ((not asup) and (not bsup)) then
          local key = connection_key(a, b)
          if not used[key] then
            used[key] = true
            draw_dashed_line(out, a.station.surface, a.station.position, b.station.position, equal, 2, players)
            drawn = drawn + 1
            if drawn >= M.max_pairs then return drawn end
          end
        end
      end
    end
  end
  return drawn
end

local function draw_pair_link(out, player, pair, selected_pair)
  if not (player and player.valid and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if pair.station.surface ~= pair.priest.surface or pair.station.surface ~= player.surface or pair.station.force ~= player.force then return false end
  local rank = pair_rank(pair)
  local color
  if rank >= 4 then color = { r = 0.25, g = 1.00, b = 0.30, a = 0.78 }
  elseif rank >= 3 then color = { r = 1.00, g = 0.20, b = 0.16, a = 0.72 }
  elseif rank >= 2 then color = { r = 0.72, g = 0.72, b = 0.72, a = 0.66 }
  else color = { r = 1.00, g = 0.62, b = 0.16, a = 0.72 } end
  local selected = (selected_pair == pair)
  return draw_line(out, pair.station.surface,
    { entity = pair.station, offset = { 0, -0.20 } },
    { entity = pair.priest, offset = { 0, -0.85 } },
    color,
    selected and 3 or 2,
    { player }) ~= nil
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  return v.item or v.item_name or v.name or v.output_item or v.wanted_item or v.requested_item or v.kind
end

local function station_writ_item(pair)
  if not pair then return nil, "none" end
  local q = pair.order_queue_0469
  local cur = (q and q.current) or pair.active_order_0469
  local item = item_from(cur)
  if item and item ~= "none" and item ~= "nil" then return item, "active-order" end
  item = item_from(pair.magos_current_plan_0471)
  if item and item ~= "none" and item ~= "nil" then return item, "magos-plan" end
  if pair.emergency_craft then
    local t = pair.emergency_craft
    item = item_from(t.current or t) or item_from(t)
    if item and item ~= "none" and item ~= "nil" then return item, "emergency-rite" end
  end
  if pair.scavenge then
    item = item_from(pair.scavenge)
    if item and item ~= "none" and item ~= "nil" then return item, "scavenge-rite" end
  end
  item = pair.logistic_requested_item or pair.requested_item or pair.last_item
  if item and item ~= "none" and item ~= "nil" then return item, "station-writ" end
  return nil, "none"
end

local function draw_sprite_fallback(out, surface, sprite_names, target, scale, tint, players, render_layer)
  if not (rendering and surface and target and players and #players > 0) then return nil, nil end
  for _, sprite in ipairs(sprite_names or {}) do
    if sprite and sprite ~= "" then
      local specs = {
        { render_layer = render_layer },
        { render_layer = "entity-info-icon" },
        { render_layer = "entity-info-icon-above" },
        { render_layer = "higher-object-above" },
        { render_layer = nil },
      }
      for _, spec0 in ipairs(specs) do
        local spec = {
          sprite = sprite,
          surface = surface,
          target = target,
          x_scale = scale or 0.5,
          y_scale = scale or 0.5,
          tint = tint,
          players = players,
          time_to_live = M.ttl,
        }
        if spec0.render_layer then spec.render_layer = spec0.render_layer end
        local ok, obj = pcall(function() return rendering.draw_sprite(spec) end)
        if ok and obj then out[#out + 1] = obj; return obj, sprite end
      end
    end
  end
  return nil, nil
end

local function draw_station_writ_icon(out, player, pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  local item, source = station_writ_item(pair)
  if not item then return false end
  local sprites = { "item/" .. item, "entity/" .. item, "recipe/" .. item, "virtual-signal/signal-info" }
  local obj, sprite = draw_sprite_fallback(out, pair.station.surface, sprites, { entity = pair.station, offset = { 0, -1.25 } }, 0.50, nil, { player }, "entity-info-icon")
  if obj then
    ensure_root().stats.last_writ_item = item
    ensure_root().stats.last_writ_source = source
    ensure_root().stats.last_writ_sprite = sprite
    return true
  end
  return false
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface) .. ":" .. tostring(entity.name or entity.type) .. ":" .. tostring(math.floor((p.x or 0) * 10)) .. ":" .. tostring(math.floor((p.y or 0) * 10))
end

local function draw_known_icon(out, player, entity, item_name)
  if not (player and player.valid and valid(entity) and item_name) then return false end
  if entity.type ~= "resource" and entity.type ~= "tree" and entity.type ~= "simple-entity" and entity.type ~= "simple-entity-with-owner" then return false end
  local color = { r = 0.65, g = 0.95, b = 1.00, a = 0.86 }
  pcall(function()
    local mark = rendering.draw_text({ surface = entity.surface, target = { entity = entity, offset = { 0, -0.12 } }, text = "⊕", color = color, scale = 1.85, alignment = "center", time_to_live = M.ttl, players = { player } })
    if mark then out[#out + 1] = mark end
  end)
  draw_sprite_fallback(out, entity.surface, { "item/" .. tostring(item_name), "entity/" .. tostring(item_name), "virtual-signal/signal-info" }, { entity = entity, offset = { 0, -0.98 } }, 0.46, nil, { player }, "entity-info-icon")
  return true
end

local function draw_instances_from_group(out, player, group, seen, count)
  if not group then return count end
  for item, rec in pairs(group) do
    local instances = rec and rec.instances or nil
    if instances then
      for _, inst in pairs(instances) do
        local entity = inst and inst.entity
        local key = entity_key(entity)
        if key and not seen[key] and valid(entity) and entity.surface == player.surface then
          seen[key] = true
          draw_known_icon(out, player, entity, item)
          count = count + 1
          if count >= M.max_known_icons then return count end
        end
      end
    elseif rec and rec.entity and rec.entity.valid then
      local entity = rec.entity
      local key = entity_key(entity)
      if key and not seen[key] and entity.surface == player.surface then
        seen[key] = true
        draw_known_icon(out, player, entity, item)
        count = count + 1
        if count >= M.max_known_icons then return count end
      end
    end
  end
  return count
end

local function draw_known_resource_alt_icons(out, player)
  local count = 0
  local seen = {}
  local catalog_root = storage and storage.tech_priests and (storage.tech_priests.station_catalog_0327 or storage.tech_priests.station_catalog_0326) or nil
  local stations = catalog_root and catalog_root.stations or nil
  if not stations then return 0 end
  for unit, cat in pairs(stations) do
    local pair = unit and pairs_table()[unit] or nil
    if pair and pair.station and pair.station.valid and pair.station.force == player.force and pair.station.surface == player.surface and cat then
      count = draw_instances_from_group(out, player, cat.resources, seen, count)
      if count >= M.max_known_icons then break end
      count = draw_instances_from_group(out, player, cat.mineable_products, seen, count)
      if count >= M.max_known_icons then break end
    end
  end
  return count
end

local function signature_for_player(root, player, list, selected_pair, held_name, alt)
  local parts = { "v=" .. M.version, "p=" .. tostring(player.index), "s=" .. tostring(player.surface and player.surface.index or "?"), "alt=" .. tostring(alt), "held=" .. tostring(held_name or "") }
  if selected_pair and selected_pair.station and selected_pair.station.valid then parts[#parts + 1] = "sel=" .. tostring(station_unit(selected_pair) or selected_pair.station.unit_number or "?") end
  for _, pair in ipairs(list or {}) do
    if pair.station and pair.station.valid then
      parts[#parts + 1] = "u" .. tostring(pair.station.unit_number or station_unit(pair) or "?") .. "@" .. tostring(math.floor(pair.station.position.x or 0)) .. "," .. tostring(math.floor(pair.station.position.y or 0))
      local item = nil
      if alt and root.station_alt_writ_enabled then item = station_writ_item(pair) end
      if item then parts[#parts + 1] = "w" .. tostring(pair.station.unit_number or station_unit(pair)) .. "=" .. tostring(item) end
    end
  end
  return table.concat(parts, "|")
end

local function should_show_station_overlay(player, selected_pair, held_name)
  if held_name then return true end
  local selected = player and player.valid and player.selected or nil
  if selected and selected.valid and entity_is_station_or_priest(selected) then return true end
  -- 0.1.489: selected_pair alone is not display authority. It can be stale
  -- state from older GUI/selection helpers; visible radius/link overlays require
  -- an actual selected entity or a held placement item.
  return false
end

function M.refresh_player(player)
  local root = ensure_root()
  if not (root.enabled and player and player.valid and player.surface and player.force) then return false end
  local list = collect_pairs_for_player(player)
  local selected_pair = selected_pair_for_player(player)
  local held_name = held_station_name(player)
  local alt = player_alt_enabled(player)
  local show_overlay = root.stable_overlay_enabled and should_show_station_overlay(player, selected_pair, held_name)
  if held_name and not root.placement_preview_enabled then show_overlay = false end
  local show_alt = alt and (root.station_alt_writ_enabled or root.known_resource_alt_icons_enabled)
  if not show_overlay and not show_alt then
    destroy_list(root.objects_by_player[player.index])
    root.objects_by_player[player.index] = nil
    root.signature_by_player[player.index] = nil
    return false
  end

  local sig = signature_for_player(root, player, list, selected_pair, held_name, alt)
  local existing = root.objects_by_player[player.index]
  local last_draw = tonumber(root.last_draw_tick_by_player[player.index]) or -999999
  if root.signature_by_player[player.index] == sig and list_valid(existing) and (now() - last_draw) < M.redraw_period then
    root.stats.skipped_stable_redraws = (root.stats.skipped_stable_redraws or 0) + 1
    return true
  end

  local out = {}
  local circles, lines, pairlinks, station_icons, known_icons = 0, 0, 0, 0, 0
  if show_overlay then
    local faint = held_name ~= nil and not (selected_pair and entity_is_station_or_priest(player.selected))
    for _, pair in ipairs(list) do
      if draw_circle(out, player, pair, faint) then circles = circles + 1 end
      if circles >= M.max_pairs then break end
    end
    lines = draw_connections(out, player, list)
    if selected_pair then
      if draw_pair_link(out, player, selected_pair, selected_pair) then pairlinks = pairlinks + 1 end
    end
  end
  if show_alt then
    if root.station_alt_writ_enabled then
      for _, pair in ipairs(list) do
        if draw_station_writ_icon(out, player, pair) then station_icons = station_icons + 1 end
        if station_icons >= M.max_pairs then break end
      end
    end
    if root.known_resource_alt_icons_enabled then known_icons = draw_known_resource_alt_icons(out, player) end
  end

  -- Draw-before-destroy refresh: the newly drawn objects are live before old
  -- objects are retired, so visible rings/links/icons should not strobe.
  local old = root.objects_by_player[player.index]
  root.objects_by_player[player.index] = out
  root.signature_by_player[player.index] = sig
  root.last_draw_tick_by_player[player.index] = now()
  destroy_list(old)
  root.stats.last_player = player.name
  root.stats.last_tick = now()
  root.stats.last_objects = #out
  root.stats.last_circles = circles
  root.stats.last_lines = lines
  root.stats.last_pairlinks = pairlinks
  root.stats.last_station_icons = station_icons
  root.stats.last_known_icons = known_icons
  root.stats.last_held_station = held_name
  return true
end

function M.refresh_all()
  if not (game and game.connected_players) then return end
  for _, player in pairs(game.connected_players) do pcall(M.refresh_player, player) end
end

function M.clear_all()
  local root = ensure_root()
  for idx, list in pairs(root.objects_by_player or {}) do
    destroy_list(list)
    root.objects_by_player[idx] = nil
    root.signature_by_player[idx] = nil
  end
end

function M.describe()
  local root = ensure_root()
  return "enabled=" .. tostring(root.enabled)
    .. " stable=" .. tostring(root.stable_overlay_enabled)
    .. " placement=" .. tostring(root.placement_preview_enabled)
    .. " station-alt-writ=" .. tostring(root.station_alt_writ_enabled)
    .. " known-alt-icons=" .. tostring(root.known_resource_alt_icons_enabled)
    .. " objects=" .. tostring(root.stats.last_objects or 0)
    .. " circles=" .. tostring(root.stats.last_circles or 0)
    .. " lines=" .. tostring(root.stats.last_lines or 0)
    .. " pair-links=" .. tostring(root.stats.last_pairlinks or 0)
    .. " writ-icons=" .. tostring(root.stats.last_station_icons or 0)
    .. " known-icons=" .. tostring(root.stats.last_known_icons or 0)
    .. " last-writ=" .. tostring(root.stats.last_writ_item or "none")
end

local function patch_legacy_visual_modules()
  local ok_v, Visuals = pcall(require, "scripts.core.network_visuals")
  if ok_v and type(Visuals) == "table" then
    local original_camera = Visuals.refresh_all_command_cameras
    Visuals.refresh_all = function()
      if type(original_camera) == "function" then pcall(original_camera) end
      return M.refresh_all()
    end
    Visuals.refresh_placement_preview_for_player = M.refresh_player
    Visuals.refresh_placement_previews = M.refresh_all
    Visuals.refresh_network_lines = M.refresh_all
    Visuals.refresh_pair_links = M.refresh_all
    Visuals.refresh_alt_icons_for_player = M.refresh_player
    Visuals.refresh_alt_icons = M.refresh_all
  end
  local ok_o, Overlay = pcall(require, "scripts.core.station_network_overlay")
  if ok_o and type(Overlay) == "table" then
    Overlay.refresh_for_player = M.refresh_player
    Overlay.refresh_all = M.refresh_all
  end
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-visual-stability-0474") end end)
  pcall(function()
    commands.add_command("tp-visual-stability-0474", "Tech Priests: inspect/toggle stable Cogitator station overlays and Alt-mode writ icons.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local root = ensure_root()
      local p = lower(event and event.parameter or "status")
      if p == "on" or p == "enable" then root.enabled = true end
      if p == "off" or p == "disable" then root.enabled = false; M.clear_all() end
      if p == "alt-on" then root.station_alt_writ_enabled = true end
      if p == "alt-off" then root.station_alt_writ_enabled = false end
      if p == "known-on" then root.known_resource_alt_icons_enabled = true end
      if p == "known-off" then root.known_resource_alt_icons_enabled = false end
      if p == "placement-on" then root.placement_preview_enabled = true end
      if p == "placement-off" then root.placement_preview_enabled = false end
      if p == "refresh" or p == "once" then M.clear_all(); M.refresh_all() end
      if player and player.valid then player.print("[tp-visual-stability-0474] " .. M.describe()) end
    end)
  end)
end

function M.install()
  if M._installed then return true end
  M._installed = true
  ensure_root()
  patch_legacy_visual_modules()
  _G.TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474 = M
  _G.tech_priests_0474_refresh_stable_visuals = M.refresh_all
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.refresh_period, function() M.refresh_all() end, { owner = "alt_writ_visual_stability_0474", category = "visuals", note = "stable station radius/link/Alt-writ overlays", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.refresh_period, function() M.refresh_all() end) end)
  end
  if registry and registry.on_event and defines and defines.events then
    if defines.events.on_player_cursor_stack_changed then registry.on_event(defines.events.on_player_cursor_stack_changed, function(event) local p = game.get_player(event.player_index); if p then M.refresh_player(p) end end, nil, { owner = "alt_writ_visual_stability_0474", category = "visuals" }) end
    if defines.events.on_runtime_mod_setting_changed then registry.on_event(defines.events.on_runtime_mod_setting_changed, function() M.clear_all(); M.refresh_all() end, nil, { owner = "alt_writ_visual_stability_0474", category = "visuals" }) end
    if defines.events.on_selected_entity_changed then registry.on_event(defines.events.on_selected_entity_changed, function(event) local p = game.get_player(event.player_index); if p then M.refresh_player(p) end end, nil, { owner = "alt_writ_visual_stability_0474", category = "visuals" }) end
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.474] stable Cogitator overlay + Alt-mode station writ icon authority installed") end
  return true
end

return M
