-- scripts/core/network_visuals.lua
-- Tech Priests 0.1.333 placement/network visual quality-of-life layer.
--
-- This module keeps visual/debug display code out of control.lua.  It owns:
--   * command-overview camera repinning to the active priest/station,
--   * placement-time Cogitator Station radius previews,
--   * gray station-to-station network lines,
--   * alt-mode-only known-resource icons/circles.

local Visuals = {}
Visuals.version = "0.1.464"
Visuals.storage_key = "network_visuals_0333"
Visuals.refresh_period = 20
Visuals.camera_refresh_period = 5
Visuals.network_refresh_period = 120
Visuals.preview_ttl = 120
Visuals.network_ttl = 180
Visuals.alt_ttl = 45
Visuals.pair_link_ttl = 120
Visuals.pair_link_refresh_period = 10
Visuals.pair_link_always_on_default = false
Visuals.max_station_pairs_drawn = 128
Visuals.max_catalog_icons_per_player = 384

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Visuals.storage_key] = storage.tech_priests[Visuals.storage_key] or {
    version = Visuals.version,
    enabled = true,
    placement_preview_enabled = false,
    network_lines_enabled = true,
    alt_resource_icons_enabled = true,
    preview_objects_by_player = {},
    network_objects = {},
    alt_objects_by_player = {},
    pair_link_objects_by_player = {},
    pair_link_always_on = Visuals.pair_link_always_on_default,
    stats = {},
    next_network_tick = 0
  }
  local root = storage.tech_priests[Visuals.storage_key]
  root.version = Visuals.version
  root.stats = root.stats or {}
  root.next_network_tick = root.next_network_tick or 0
  root.preview_objects_by_player = root.preview_objects_by_player or {}
  root.network_objects = root.network_objects or {}
  root.alt_objects_by_player = root.alt_objects_by_player or {}
  root.pair_link_objects_by_player = root.pair_link_objects_by_player or {}
  if root.pair_link_always_on == nil then root.pair_link_always_on = Visuals.pair_link_always_on_default end
  -- 0.1.444: 0.1.443 briefly made pair links always-on by default. Restore
  -- the intended radar-hover behavior: the home link remains visible while a
  -- station/priest is selected/hovered and is refreshed on a short cadence, but
  -- the map is not permanently webbed with pair links unless the debug command
  -- explicitly asks for it.
  if root.pair_link_always_on == true and not root.user_overrode_pair_links_0444 then root.pair_link_always_on = false end
  if root.enabled == nil then root.enabled = true end
  -- 0.1.463: do not draw whole-radius previews around existing stations while
  -- holding a station item.  Factorio placement ghosts are enough for now.
  root.placement_preview_enabled = false
  root.placement_radius_force_disabled_0463 = true
  if root.network_lines_enabled == nil then root.network_lines_enabled = true end
  if root.alt_resource_icons_enabled == nil then root.alt_resource_icons_enabled = true end
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
    local name = stack.name
    if tostring(name):find("cogitator%-station") then return name end
  end
  return nil
end

local function safe_destroy(obj)
  if not obj then return end
  pcall(function()
    if obj.valid then obj.destroy() end
  end)
end

local function clear_list(list)
  if not list then return end
  for _, obj in pairs(list) do safe_destroy(obj) end
end

local function clear_player_previews(root, player_index)
  if not (root and player_index) then return end
  clear_list(root.preview_objects_by_player[player_index])
  root.preview_objects_by_player[player_index] = nil
end

local function clear_player_alt(root, player_index)
  if not (root and player_index) then return end
  clear_list(root.alt_objects_by_player[player_index])
  root.alt_objects_by_player[player_index] = nil
end

local function clear_player_pair_link(root, player_index)
  if not (root and player_index) then return end
  clear_list(root.pair_link_objects_by_player[player_index])
  root.pair_link_objects_by_player[player_index] = nil
end

local function selected_pair_for_player_visual(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid then
    if storage and storage.tech_priests then
      if selected.unit_number and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then
        return storage.tech_priests.pairs_by_station[selected.unit_number]
      end
      if selected.unit_number and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then
        return storage.tech_priests.pairs_by_priest[selected.unit_number]
      end
    end
    if _G.find_pair_for_entity then
      local ok, pair = pcall(_G.find_pair_for_entity, selected)
      if ok and pair then return pair end
    end
  end
  return nil
end

local function pair_link_color(pair)
  local rank = pair_rank(pair)
  if rank >= 4 then return { r = 0.25, g = 1.00, b = 0.30, a = 0.70 } end
  if rank >= 3 then return { r = 1.00, g = 0.20, b = 0.16, a = 0.68 } end
  if rank >= 2 then return { r = 0.72, g = 0.72, b = 0.72, a = 0.62 } end
  return { r = 1.00, g = 0.62, b = 0.16, a = 0.68 }
end


local function clear_network(root)
  clear_list(root.network_objects)
  root.network_objects = {}
end

local function connected(a, b)
  if not (a and b and a.station and a.station.valid and b.station and b.station.valid) then return false end
  if a.station.force ~= b.station.force or a.station.surface ~= b.station.surface then return false end
  local ar = radius_for(a)
  local br = radius_for(b)
  local d = distance_sq(a.station.position, b.station.position)
  return d <= (math.max(ar, br) * 3) * (math.max(ar, br) * 3)
end

local function draw_debug_line(surface, from, to, color, width, ttl, players, force)
  if not rendering then return nil end
  if players and #players == 0 then return nil end
  local spec = {
    surface = surface, from = from, to = to, color = color,
    width = width or 1, time_to_live = ttl or Visuals.network_ttl
  }
  if players then spec.players = players end
  if force then spec.forces = { force } end
  local ok, obj = pcall(function() return rendering.draw_line(spec) end)
  if ok then return obj end
  return nil
end

local function draw_dashed_line(surface, from, to, color, width, ttl, players, out, force)
  -- Factorio runtime rendering has no native dashed line primitive. This is a
  -- deliberately explicit segmented render-line stream.  Keep the gaps large
  -- enough to read even at zoomed-out testing distances.
  local dx = to.x - from.x
  local dy = to.y - from.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local segments = math.max(6, math.min(40, math.floor(dist / 3)))
  for i = 0, segments - 1 do
    if (i % 2) == 0 then
      local a = i / segments
      local b = math.min(1, (i + 0.58) / segments)
      local p1 = { x = from.x + dx * a, y = from.y + dy * a }
      local p2 = { x = from.x + dx * b, y = from.y + dy * b }
      local obj = draw_debug_line(surface, p1, p2, color, math.max(width or 1, 2), ttl, players, force)
      if obj then out[#out + 1] = obj end
    end
  end
end

function Visuals.refresh_command_preview_camera(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return false end
  local frame = player.gui.screen["tech_priests_command_overview_0189"] or player.gui.screen["tech_priests_command_overview_frame_0189"]
  if not (frame and frame.valid) then return false end
  local function walk(el)
    if not (el and el.valid and el.children) then return nil end
    for _, child in pairs(el.children) do
      if child.name == "tech_priests_command_camera_0189" then return child end
      local found = walk(child)
      if found then return found end
    end
    return nil
  end
  local cam = frame["tech_priests_command_camera_0189"]
  if not (cam and cam.valid) then cam = walk(frame) end
  if not (cam and cam.valid) then return false end

  local pair = nil
  local selected_unit = nil
  if _G.tech_priests_command_overview_storage_0189 then
    local ok, selected = pcall(_G.tech_priests_command_overview_storage_0189)
    if ok and selected then selected_unit = selected[player.index] end
  end
  if selected_unit then pair = pairs_table()[selected_unit] end

  if not pair and _G.tech_priests_valid_pairs_for_player_0189 and _G.tech_priests_get_selected_pair_0189 then
    local ok, rows = pcall(_G.tech_priests_valid_pairs_for_player_0189, player)
    if ok then
      local ok2, found = pcall(_G.tech_priests_get_selected_pair_0189, player, rows)
      if ok2 then pair = found end
    end
  elseif not pair and _G.selected_pair_for_player then
    local ok, found = pcall(_G.selected_pair_for_player, player)
    if ok then pair = found end
  end
  if not (pair and pair.station and pair.station.valid) then return false end
  local target = (pair.priest and pair.priest.valid and pair.priest) or pair.station
  pcall(function() cam.position = target.position end)
  pcall(function() cam.surface_index = target.surface.index end)
  return true
end

function Visuals.refresh_all_command_cameras()
  if not game or not game.connected_players then return end
  for _, player in pairs(game.connected_players) do Visuals.refresh_command_preview_camera(player) end
end

function Visuals.refresh_placement_preview_for_player(player)
  local root = ensure_root()
  if player and player.valid then clear_player_previews(root, player.index) end
  -- 0.1.463: deliberate no-op.  No large Cogitator Station radius circles while
  -- holding a station item; this path was another source of full-radius flashes.
  return
end

function Visuals.refresh_placement_previews()
  if not game or not game.connected_players then return end
  for _, player in pairs(game.connected_players) do Visuals.refresh_placement_preview_for_player(player) end
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
        -- Prefer the closest direct superior; higher-rank ties still win when distance is nearly equal.
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


local function entity_is_station_or_priest(entity)
  if not valid(entity) then return false end
  local n = tostring(entity.name or "")
  return n:find("cogitator%-station") ~= nil or n:find("tech%-priest") ~= nil or n:find("magos%-tech%-priest") ~= nil
end

local function player_wants_network_lines(player)
  if not (player and player.valid) then return false end
  -- 0.1.453: holding a station should not trigger global persistent network lines/radius light.
  if player.selected and player.selected.valid and entity_is_station_or_priest(player.selected) then return true end
  return false
end

local function interested_players_for_force_surface(force, surface)
  local out = {}
  if not (game and game.connected_players) then return out end
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.force == force and player.surface == surface and player_wants_network_lines(player) then
      out[#out + 1] = player
    end
  end
  return out
end

function Visuals.refresh_network_lines()
  local root = ensure_root()
  clear_network(root)
  if not (root.enabled and root.network_lines_enabled and rendering) then return end
  local objects = {}
  local list = {}
  local any_interested = false
  for _, player in pairs(game and game.connected_players or {}) do
    if player_wants_network_lines(player) then any_interested = true; break end
  end
  if not any_interested then
    root.network_objects = objects
    root.stats.network_lines_drawn = 0
    root.stats.network_mode = "hover-or-placement-only-0333"
    return
  end
  for _, pair in pairs(pairs_table()) do
    if pair and pair.station and pair.station.valid then list[#list + 1] = pair end
  end
  table.sort(list, function(a, b)
    local ar, br = pair_rank(a), pair_rank(b)
    if ar ~= br then return ar > br end
    return (station_unit(a) or 0) < (station_unit(b) or 0)
  end)

  local drawn = 0
  local used = {}
  local gray = { r = 0.62, g = 0.62, b = 0.62, a = 0.46 }
  local equal = { r = 1.00, g = 0.72, b = 0.16, a = 0.76 }

  local superior_for = {}
  for _, subject in pairs(list) do
    local target, mode = best_connection_for(subject, list)
    if target and mode == "hierarchy" then
      superior_for[station_unit(subject) or 0] = station_unit(target) or 0
      local key = connection_key(subject, target)
      if not used[key] then
        used[key] = true
        local obj = draw_debug_line(subject.station.surface, subject.station.position, target.station.position, gray, 1, Visuals.network_ttl, interested_players_for_force_surface(subject.station.force, subject.station.surface), nil)
        if obj then objects[#objects + 1] = obj end
        drawn = drawn + 1
      end
    end
    if drawn >= Visuals.max_station_pairs_drawn then break end
  end

  -- Equal-rank sharing links are not native Factorio dashed logistics wires.
  -- They are segmented render lines. Draw them only when the stations are near,
  -- same force/surface/rank, and either share the same superior or have no
  -- superior at all. This preserves the hierarchy tree while still showing peer
  -- resource sharing where it matters.
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
            draw_dashed_line(a.station.surface, a.station.position, b.station.position, equal, 2, Visuals.network_ttl, interested_players_for_force_surface(a.station.force, a.station.surface), objects, nil)
            drawn = drawn + 1
            if drawn >= Visuals.max_station_pairs_drawn then break end
          end
        end
      end
    end
    if drawn >= Visuals.max_station_pairs_drawn then break end
  end

  -- Fallback: isolated stations with no superior/equal peer still get one plain
  -- nearest link so the player can see that the network is not orphaned.
  for _, subject in pairs(list) do
    if drawn >= Visuals.max_station_pairs_drawn then break end
    local has_line = false
    local su = station_unit(subject) or 0
    for key in pairs(used) do
      if key:find(tostring(su), 1, true) then has_line = true; break end
    end
    if not has_line then
      local target, mode = best_connection_for(subject, list)
      if target then
        local key = connection_key(subject, target)
        if not used[key] then
          used[key] = true
          if mode == "equal" then
            draw_dashed_line(subject.station.surface, subject.station.position, target.station.position, equal, 2, Visuals.network_ttl, interested_players_for_force_surface(subject.station.force, subject.station.surface), objects, nil)
          else
            local obj = draw_debug_line(subject.station.surface, subject.station.position, target.station.position, gray, 1, Visuals.network_ttl, interested_players_for_force_surface(subject.station.force, subject.station.surface), nil)
            if obj then objects[#objects + 1] = obj end
          end
          drawn = drawn + 1
        end
      end
    end
  end

  root.network_objects = objects
  root.stats.network_lines_drawn = drawn
  root.stats.network_mode = "hover-or-placement-hierarchy-plus-peer-dash-0333"
end

local function player_alt_enabled(player)
  if not (player and player.valid) then return false end
  local ok, value = pcall(function() return player.game_view_settings and player.game_view_settings.show_entity_info end)
  return ok and value == true
end

local function main_product_for_entity(entity)
  if not valid(entity) then return nil end
  if entity.type == "resource" then return entity.name end
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if ok and props and props.products then
    for _, product in pairs(props.products) do
      local name = product.name or product[1]
      if name then return name end
    end
  end
  if entity.type == "tree" then return "wood" end
  return nil
end

local function draw_known_icon_for_player(player, entity, item_name, station_unit_text, out)
  if not (player and player.valid and valid(entity) and item_name and rendering) then return end
  -- Do not overlay known-item icons on recipe-bearing machines; those already
  -- have useful alt-mode recipe displays. This visual is for resources,
  -- trees, rocks, and primitive mineables.
  if entity.type ~= "resource" and entity.type ~= "tree" and entity.type ~= "simple-entity" and entity.type ~= "simple-entity-with-owner" then return end
  local color = { r = 0.65, g = 0.95, b = 1.00, a = 0.86 }
  -- 0.1.333: the glyph itself is the marker.  The previous small cyan debug
  -- circle made this look like two overlapping target systems; scale the plus
  -- circle glyph up to roughly match the old bracket circle and remove the
  -- separate draw_circle entirely.
  pcall(function()
    local mark = rendering.draw_text({ surface = entity.surface, target = { entity = entity, offset = { 0, -0.12 } }, text = "⊕", color = color, scale = 1.85, alignment = "center", time_to_live = Visuals.alt_ttl, players = { player } })
    if mark then out[#out + 1] = mark end
  end)
  pcall(function()
    local s = rendering.draw_sprite({ surface = entity.surface, sprite = "item/" .. tostring(item_name), target = { entity = entity, offset = { 0, -0.98 } }, x_scale = 0.46, y_scale = 0.46, time_to_live = Visuals.alt_ttl, players = { player } })
    if s then out[#out + 1] = s end
  end)
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface) .. ":" .. tostring(entity.name or entity.type) .. ":" .. tostring(math.floor((p.x or 0) * 10)) .. ":" .. tostring(math.floor((p.y or 0) * 10))
end

local function draw_instances_from_group(player, group, seen, out, count)
  if not group then return count end
  for item, rec in pairs(group) do
    local instances = rec and rec.instances or nil
    if instances then
      for _, inst in pairs(instances) do
        local entity = inst and inst.entity
        local key = entity_key(entity)
        if key and not seen[key] and valid(entity) and entity.surface == player.surface then
          seen[key] = true
          draw_known_icon_for_player(player, entity, item, inst.owner_unit and ("#" .. tostring(inst.owner_unit)) or nil, out)
          count = count + 1
          if count >= Visuals.max_catalog_icons_per_player then return count end
        end
      end
    elseif rec and rec.entity and rec.entity.valid then
      local entity = rec.entity
      local key = entity_key(entity)
      if key and not seen[key] and entity.surface == player.surface then
        seen[key] = true
        draw_known_icon_for_player(player, entity, item, rec.owner_unit and ("#" .. tostring(rec.owner_unit)) or nil, out)
        count = count + 1
        if count >= Visuals.max_catalog_icons_per_player then return count end
      end
    end
  end
  return count
end

function Visuals.refresh_alt_icons_for_player(player)
  local root = ensure_root()
  clear_player_alt(root, player.index)
  if not (root.enabled and root.alt_resource_icons_enabled and player_alt_enabled(player)) then return end
  local out = {}
  local count = 0
  local seen = {}
  local catalog_root = storage and storage.tech_priests and (storage.tech_priests.station_catalog_0327 or storage.tech_priests.station_catalog_0326) or nil
  local stations = catalog_root and catalog_root.stations or nil
  if stations then
    for unit, cat in pairs(stations) do
      local pair = unit and pairs_table()[unit] or nil
      if pair and pair.station and pair.station.valid and pair.station.force == player.force and pair.station.surface == player.surface and cat then
        count = draw_instances_from_group(player, cat.resources, seen, out, count)
        if count >= Visuals.max_catalog_icons_per_player then break end
        count = draw_instances_from_group(player, cat.mineable_products, seen, out, count)
        if count >= Visuals.max_catalog_icons_per_player then break end
      end
    end
  end
  root.alt_objects_by_player[player.index] = out
  root.stats.alt_icons_drawn = count
end

function Visuals.refresh_alt_icons()
  if not game or not game.connected_players then return end
  for _, player in pairs(game.connected_players) do Visuals.refresh_alt_icons_for_player(player) end
end

local function should_draw_pair_for_player(player, pair)
  if not (player and player.valid and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if pair.station.surface ~= pair.priest.surface then return false end
  if pair.station.surface ~= player.surface then return false end
  if pair.station.force ~= player.force then return false end
  return true
end

local function draw_pair_home_link_for_player(player, pair, selected_pair, out)
  if not should_draw_pair_for_player(player, pair) then return end
  local selected = selected_pair and pair == selected_pair
  local color = pair_link_color(pair)
  if not selected then color = { r = color.r, g = color.g, b = color.b, a = math.min(color.a or 0.55, 0.52) } end
  local ok, obj = pcall(function()
    return rendering.draw_line({
      surface = pair.station.surface,
      from = { entity = pair.station, offset = { 0, -0.20 } },
      to = { entity = pair.priest, offset = { 0, -0.85 } },
      color = color,
      width = selected and 3 or 2,
      time_to_live = Visuals.pair_link_ttl,
      players = { player }
    })
  end)
  if ok and obj then out[#out + 1] = obj end
end

function Visuals.refresh_pair_links()
  local root = ensure_root()
  if not (root.enabled and game and game.connected_players and rendering and rendering.draw_line) then return end
  root.stats.pair_links_drawn = 0
  for _, player in pairs(game.connected_players) do
    if player and player.valid then
      clear_player_pair_link(root, player.index)
      local out = {}
      local selected_pair = selected_pair_for_player_visual(player)
      if root.pair_link_always_on then
        for _, pair in pairs(pairs_table()) do
          draw_pair_home_link_for_player(player, pair, selected_pair, out)
          if #out >= Visuals.max_station_pairs_drawn then break end
        end
      elseif selected_pair then
        draw_pair_home_link_for_player(player, selected_pair, selected_pair, out)
      end
      root.pair_link_objects_by_player[player.index] = out
      root.stats.pair_links_drawn = (root.stats.pair_links_drawn or 0) + #out
    end
  end
end

function Visuals.refresh_all()
  local root = ensure_root()
  if not root.enabled then return end
  Visuals.refresh_all_command_cameras()
  Visuals.refresh_placement_previews()
  Visuals.refresh_pair_links()
  if (game and game.tick or 0) >= (root.next_network_tick or 0) then
    Visuals.refresh_network_lines()
    root.next_network_tick = (game and game.tick or 0) + Visuals.network_refresh_period
  end
  Visuals.refresh_alt_icons()
end

function Visuals.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-network-visuals-0333", "Tech Priests: report/toggle 0.1.332 placement, hierarchy station network, and alt-mode known-resource visuals.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      if p == "placement-on" then root.placement_preview_enabled = false; root.placement_radius_force_disabled_0463 = true; player.print("[Tech Priests 0.1.463] placement radius previews are hard-disabled for this test pass.") end
      if p == "placement-off" then root.placement_preview_enabled = false; root.placement_radius_force_disabled_0463 = true end
      if p == "lines-on" then root.network_lines_enabled = true end
      if p == "lines-off" then root.network_lines_enabled = false end
      if p == "pair-links-on" then root.pair_link_always_on = true; root.user_overrode_pair_links_0444 = true end
      if p == "pair-links-off" or p == "pair-links-hover" then root.pair_link_always_on = false; root.user_overrode_pair_links_0444 = true end
      if p == "alt-on" then root.alt_resource_icons_enabled = true end
      if p == "alt-off" then root.alt_resource_icons_enabled = false end
      if p == "refresh" then root.next_network_tick = 0; Visuals.refresh_all() end
      player.print("[Tech Priests 0.1.444] network visuals enabled=" .. tostring(root.enabled) .. " placement=" .. tostring(root.placement_preview_enabled) .. " lines=" .. tostring(root.network_lines_enabled) .. " pair-links-always=" .. tostring(root.pair_link_always_on) .. " hover-mode=" .. tostring(not root.pair_link_always_on) .. " alt-icons=" .. tostring(root.alt_resource_icons_enabled) .. " lines-drawn=" .. tostring(root.stats.network_lines_drawn or 0) .. " alt-icons=" .. tostring(root.stats.alt_icons_drawn or 0))
    end)
  end)
end

function Visuals.install()
  if Visuals._installed then return true end
  Visuals._installed = true
  ensure_root()
  _G.tech_priests_0328_refresh_network_visuals = Visuals.refresh_all
  _G.tech_priests_0328_refresh_command_preview_camera = Visuals.refresh_command_preview_camera
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(Visuals.refresh_period, function() Visuals.refresh_all() end, { owner = "network_visuals", category = "visuals", note = "refresh hover-gated station/priest and network visuals" })
    registry.on_nth_tick(Visuals.pair_link_refresh_period, function() Visuals.refresh_pair_links() end, { owner = "network_visuals", category = "visuals", note = "refresh selected/hovered station-priest home link" })
    registry.on_nth_tick(Visuals.camera_refresh_period, function() Visuals.refresh_all_command_cameras() end, { owner = "network_visuals", category = "visuals", note = "refresh command camera" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(Visuals.refresh_period, function() Visuals.refresh_all() end)
    script.on_nth_tick(Visuals.pair_link_refresh_period, function() Visuals.refresh_pair_links() end)
    script.on_nth_tick(Visuals.camera_refresh_period, function() Visuals.refresh_all_command_cameras() end)
  end
  if script and defines and defines.events and script.on_event then
    if defines.events.on_player_cursor_stack_changed then
      script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if player then Visuals.refresh_placement_preview_for_player(player) end
      end)
    end
    if defines.events.on_runtime_mod_setting_changed then
      script.on_event(defines.events.on_runtime_mod_setting_changed, function() Visuals.refresh_all() end)
    end
  end
  Visuals.register_commands()
  if log then log("[Tech-Priests 0.1.464] placement/hierarchy-network visuals installed; station/pair lines preserved; placement radius previews remain off") end
  return true
end

return Visuals
