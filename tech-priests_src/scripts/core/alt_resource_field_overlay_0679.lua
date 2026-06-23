-- Tech Priests 0.1.663 force-wide ALT claimed-resource field overlay.
-- Replaces the old per-entity marker budget with an aggregated edge map built
-- across every same-force, same-surface Cogitator catalog. Large ore patches are
-- represented by one field outline and one label instead of hundreds of icons.

local M = {
  version = "0.1.663",
  storage_key = "alt_resource_field_overlay_0679",
  cell_size = 6,
  max_fields = 96,
  max_edge_segments = 520,
  max_scan_resources_per_station = 2048,
  redraw_period = 120,
  ttl = 180,
}

local previous_refresh_player
local previous_clear_all
local previous_describe

local PALETTE = {
  { r = 0.28, g = 0.86, b = 1.00 },
  { r = 1.00, g = 0.72, b = 0.20 },
  { r = 0.45, g = 1.00, b = 0.42 },
  { r = 1.00, g = 0.40, b = 0.24 },
  { r = 0.76, g = 0.48, b = 1.00 },
  { r = 0.92, g = 0.92, b = 0.92 },
  { r = 0.32, g = 0.68, b = 1.00 },
  { r = 1.00, g = 0.36, b = 0.70 },
}

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    field_edges_enabled = true,
    labels_enabled = true,
    objects_by_player = {},
    signature_by_player = {},
    last_draw_tick_by_player = {},
    field_cache = {},
    stats = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.field_edges_enabled == nil then r.field_edges_enabled = true end
  if r.labels_enabled == nil then r.labels_enabled = true end
  r.objects_by_player = r.objects_by_player or {}
  r.signature_by_player = r.signature_by_player or {}
  r.last_draw_tick_by_player = r.last_draw_tick_by_player or {}
  r.field_cache = r.field_cache or {}
  r.stats = r.stats or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function player_alt_enabled(player)
  if not (player and player.valid) then return false end
  local ok, enabled = pcall(function()
    return player.game_view_settings and player.game_view_settings.show_entity_info
  end)
  return ok and enabled == true
end

local function destroy(object)
  if not object then return end
  pcall(function()
    if object.valid then object.destroy() end
  end)
end

local function destroy_list(list)
  for _, object in pairs(list or {}) do destroy(object) end
end

local function objects_valid(list)
  if not list or #list == 0 then return false end
  for _, object in ipairs(list) do
    local ok, is_valid = pcall(function() return object and object.valid end)
    if not (ok and is_valid) then return false end
  end
  return true
end

local function append(list, object)
  if object then list[#list + 1] = object end
  return object
end

local function pair_lookup()
  local lookup = {}
  for key, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      lookup[tostring(key)] = pair
      local unit = station_unit(pair)
      if unit then lookup[tostring(unit)] = pair end
    end
  end
  return lookup
end

local function catalog_module()
  local ok, catalog = pcall(require, "scripts.core.station_catalog")
  return ok and catalog or nil
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  local catalog = catalog_module()
  if catalog and type(catalog.entity_key) == "function" then
    local ok, key = pcall(catalog.entity_key, entity)
    if ok and key then return key end
  end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local position = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface)
    .. ":" .. tostring(entity.name or entity.type)
    .. ":" .. tostring(math.floor((position.x or 0) * 10))
    .. ":" .. tostring(math.floor((position.y or 0) * 10))
end

local function same_owner(a, b)
  return tostring(a or "") == tostring(b or "")
end

local function station_pair_for_catalog(lookup, unit, catalog)
  local pair = lookup[tostring(unit or "")]
    or lookup[tostring(catalog and catalog.station_unit or "")]
  if pair then return pair end

  local wanted = tostring((catalog and catalog.station_unit) or unit or "")
  for _, candidate in pairs(pair_map()) do
    if candidate and valid(candidate.station) and tostring(station_unit(candidate) or "") == wanted then
      return candidate
    end
  end
  return nil
end

local function matching_pair_for_player(pair, player)
  return pair
    and valid(pair.station)
    and pair.station.surface == player.surface
    and pair.station.force == player.force
end

local function catalog_root()
  local tp = storage and storage.tech_priests
  return tp and (tp.station_catalog_0327 or tp.station_catalog_0326) or nil
end

local function context_key(player)
  return tostring(player.surface.index) .. ":" .. tostring(player.force.index)
end

local function count_keys(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end

local function catalog_signature(player)
  local croot = catalog_root()
  local lookup = pair_lookup()
  local parts = {
    "v=" .. M.version,
    "surface=" .. tostring(player.surface.index),
    "force=" .. tostring(player.force.index),
    "owned=" .. tostring(count_keys(croot and croot.owned_resources)),
  }

  for unit, catalog in pairs(croot and croot.stations or {}) do
    local pair = station_pair_for_catalog(lookup, unit, catalog)
    if matching_pair_for_player(pair, player) then
      parts[#parts + 1] = tostring(station_unit(pair) or unit)
        .. "@" .. tostring(catalog.tick or 0)
        .. ":" .. tostring(catalog.owned_resource_count or 0)
        .. ":" .. tostring(catalog.radius or 0)
    end
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function parse_position_key(key)
  if type(key) ~= "string" or key:sub(1, 2) == "u:" then return nil end
  local surface_name, entity_name, x10, y10 = key:match("^(.*):([^:]+):(-?%d+):(-?%d+)$")
  if not (surface_name and entity_name and x10 and y10) then return nil end
  return surface_name, entity_name, tonumber(x10) / 10, tonumber(y10) / 10
end

local function scan_owned_resources_for_pair(pair, croot, add_claim)
  if not (pair and valid(pair.station) and pair.station.surface and croot and croot.owned_resources) then return end
  local radius = tonumber(pair.radius)
  if type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(value) then radius = tonumber(value) end
  end
  radius = math.max(8, tonumber(radius) or 24)
  local position = pair.station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius },
  }
  local ok, resources = pcall(function()
    return pair.station.surface.find_entities_filtered({
      area = area,
      type = "resource",
      limit = M.max_scan_resources_per_station,
    })
  end)
  if not (ok and resources) then return end

  local unit = station_unit(pair)
  for _, entity in ipairs(resources) do
    local key = entity_key(entity)
    if key and same_owner(croot.owned_resources[key], unit) then
      add_claim(entity.name, entity.position, unit, entity.amount or 1, key, entity.type)
    end
  end
end

local function collect_claims(player)
  local claims = {}
  local seen = {}
  local croot = catalog_root()
  local lookup = pair_lookup()
  local missing_position_claims = 0

  local function add_claim(item_name, position, owner_unit, amount, key, kind)
    if not (item_name and position and position.x and position.y and owner_unit) then return end
    key = key or (tostring(item_name) .. "@" .. tostring(position.x) .. ":" .. tostring(position.y))
    if seen[key] then return end
    local owner_pair = lookup[tostring(owner_unit)]
    if not matching_pair_for_player(owner_pair, player) then return end
    seen[key] = true
    claims[#claims + 1] = {
      item = tostring(item_name),
      position = { x = position.x, y = position.y },
      owner = tostring(owner_unit),
      amount = tonumber(amount) or 1,
      key = key,
      kind = kind,
    }
  end

  local function add_record(item_name, record, catalog_unit)
    if not record then return end
    local instances = record.instances
    if type(instances) == "table" then
      for _, instance in pairs(instances) do
        local entity = instance and instance.entity
        if valid(entity) and entity.surface == player.surface then
          local key = entity_key(entity)
          local owner = (croot and croot.owned_resources and key and croot.owned_resources[key])
            or instance.owner_unit
            or catalog_unit
          add_claim(item_name, entity.position, owner, instance.count or entity.amount or 1, key, entity.type)
        end
      end
    elseif valid(record.entity) and record.entity.surface == player.surface then
      local key = entity_key(record.entity)
      local owner = (croot and croot.owned_resources and key and croot.owned_resources[key])
        or record.owner_unit
        or catalog_unit
      add_claim(item_name, record.entity.position, owner, record.count or record.entity.amount or 1, key, record.entity.type)
    end
  end

  for unit, catalog in pairs(croot and croot.stations or {}) do
    local pair = station_pair_for_catalog(lookup, unit, catalog)
    if matching_pair_for_player(pair, player) then
      local catalog_unit = station_unit(pair) or catalog.station_unit or unit
      -- Resource records are primary so a physical ore patch has one stable type.
      for item_name, record in pairs(catalog.resources or {}) do
        add_record(item_name, record, catalog_unit)
      end
      for item_name, record in pairs(catalog.mineable_products or {}) do
        add_record(item_name, record, catalog_unit)
      end
      scan_owned_resources_for_pair(pair, croot, add_claim)
    end
  end

  -- Recover position-key claims omitted by per-item instance caps. This makes the
  -- overlay reflect the complete ownership ledger, not only the retained nearest
  -- instance lists.
  for key, owner_unit in pairs(croot and croot.owned_resources or {}) do
    if not seen[key] then
      local surface_name, entity_name, x, y = parse_position_key(key)
      if surface_name == player.surface.name then
        add_claim(entity_name, { x = x, y = y }, owner_unit, 1, key, "ledger-position")
      else
        missing_position_claims = missing_position_claims + 1
      end
    end
  end

  return claims, missing_position_claims
end

local function cell_key(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function merge_owner_set(target, source)
  for owner in pairs(source or {}) do target[owner] = true end
end

local function build_fields_from_claims(claims)
  local by_item = {}
  local size = M.cell_size

  for _, claim in ipairs(claims or {}) do
    local item_cells = by_item[claim.item]
    if not item_cells then
      item_cells = {}
      by_item[claim.item] = item_cells
    end
    local cx = math.floor(claim.position.x / size)
    local cy = math.floor(claim.position.y / size)
    local key = cell_key(cx, cy)
    local cell = item_cells[key]
    if not cell then
      cell = {
        key = key,
        cx = cx,
        cy = cy,
        claims = 0,
        amount = 0,
        sum_x = 0,
        sum_y = 0,
        owners = {},
      }
      item_cells[key] = cell
    end
    cell.claims = cell.claims + 1
    cell.amount = cell.amount + (claim.amount or 1)
    cell.sum_x = cell.sum_x + claim.position.x
    cell.sum_y = cell.sum_y + claim.position.y
    cell.owners[claim.owner] = true
  end

  local fields = {}
  local neighbors = {
    { -1, -1 }, { 0, -1 }, { 1, -1 },
    { -1,  0 },             { 1,  0 },
    { -1,  1 }, { 0,  1 }, { 1,  1 },
  }

  for item_name, cells in pairs(by_item) do
    local visited = {}
    for key, seed in pairs(cells) do
      if not visited[key] then
        local stack = { seed }
        visited[key] = true
        local field = {
          item = item_name,
          cells = {},
          claims = 0,
          amount = 0,
          sum_x = 0,
          sum_y = 0,
          owners = {},
          min_cx = seed.cx,
          max_cx = seed.cx,
          min_cy = seed.cy,
          max_cy = seed.cy,
        }

        while #stack > 0 do
          local cell = table.remove(stack)
          field.cells[#field.cells + 1] = cell
          field.claims = field.claims + cell.claims
          field.amount = field.amount + cell.amount
          field.sum_x = field.sum_x + cell.sum_x
          field.sum_y = field.sum_y + cell.sum_y
          field.min_cx = math.min(field.min_cx, cell.cx)
          field.max_cx = math.max(field.max_cx, cell.cx)
          field.min_cy = math.min(field.min_cy, cell.cy)
          field.max_cy = math.max(field.max_cy, cell.cy)
          merge_owner_set(field.owners, cell.owners)

          for _, delta in ipairs(neighbors) do
            local neighbor_key = cell_key(cell.cx + delta[1], cell.cy + delta[2])
            if cells[neighbor_key] and not visited[neighbor_key] then
              visited[neighbor_key] = true
              stack[#stack + 1] = cells[neighbor_key]
            end
          end
        end

        field.center = {
          x = field.sum_x / math.max(1, field.claims),
          y = field.sum_y / math.max(1, field.claims),
        }
        field.owner_count = count_keys(field.owners)
        fields[#fields + 1] = field
      end
    end
  end

  table.sort(fields, function(a, b)
    if a.claims ~= b.claims then return a.claims > b.claims end
    return tostring(a.item) < tostring(b.item)
  end)
  return fields
end

local function build_fields(player, signature)
  local r = root()
  local key = context_key(player)
  local cached = r.field_cache[key]
  if cached and cached.signature == signature and type(cached.fields) == "table" then
    stat("field_cache_hits")
    return cached.fields, cached.claim_count or 0, cached.unresolved or 0
  end

  local claims, unresolved = collect_claims(player)
  local fields = build_fields_from_claims(claims)
  r.field_cache[key] = {
    signature = signature,
    fields = fields,
    claim_count = #claims,
    unresolved = unresolved,
    built_tick = now(),
  }
  stat("field_cache_rebuilds")
  return fields, #claims, unresolved
end

local function color_for_item(item_name, alpha)
  local hash = 0
  for index = 1, #tostring(item_name or "") do
    hash = (hash * 33 + string.byte(item_name, index)) % 2147483647
  end
  local base = PALETTE[(hash % #PALETTE) + 1]
  return { r = base.r, g = base.g, b = base.b, a = alpha or 1 }
end

local function draw_line(out, player, from, to, color, width)
  local ok, object = pcall(function()
    return rendering.draw_line({
      surface = player.surface,
      from = from,
      to = to,
      color = color,
      width = width,
      draw_on_ground = true,
      time_to_live = M.ttl,
      players = { player },
    })
  end)
  return ok and append(out, object) or nil
end

local function draw_circle(out, player, position, radius, color, width)
  local ok, object = pcall(function()
    return rendering.draw_circle({
      surface = player.surface,
      target = position,
      radius = radius,
      color = color,
      width = width,
      filled = false,
      draw_on_ground = true,
      time_to_live = M.ttl,
      players = { player },
    })
  end)
  return ok and append(out, object) or nil
end

local function sprite_candidates(item_name)
  return {
    "item/" .. item_name,
    "fluid/" .. item_name,
    "entity/" .. item_name,
    "virtual-signal/signal-info",
  }
end

local function draw_sprite(out, player, field)
  for _, sprite in ipairs(sprite_candidates(field.item)) do
    local ok, object = pcall(function()
      return rendering.draw_sprite({
        sprite = sprite,
        surface = player.surface,
        target = { x = field.center.x, y = field.center.y - 0.55 },
        x_scale = 0.62,
        y_scale = 0.62,
        render_layer = "entity-info-icon",
        time_to_live = M.ttl,
        players = { player },
      })
    end)
    if ok and object then append(out, object); return true end
  end
  return false
end

local function localized_resource_name(item_name)
  local prototype = nil
  pcall(function()
    prototype = (prototypes and prototypes.item and prototypes.item[item_name])
      or (prototypes and prototypes.fluid and prototypes.fluid[item_name])
      or (prototypes and prototypes.entity and prototypes.entity[item_name])
  end)
  return prototype and prototype.localised_name or item_name
end

local function draw_label(out, player, field, color)
  local station_word = field.owner_count == 1 and " station" or " stations"
  local text = {
    "",
    localized_resource_name(field.item),
    "  •  ", tostring(field.claims), " claimed  •  ",
    tostring(field.owner_count), station_word,
  }
  local ok, object = pcall(function()
    return rendering.draw_text({
      surface = player.surface,
      target = { x = field.center.x, y = field.center.y + 0.35 },
      text = text,
      color = color,
      scale = 0.82,
      alignment = "center",
      vertical_alignment = "top",
      use_rich_text = true,
      time_to_live = M.ttl,
      players = { player },
    })
  end)
  return ok and append(out, object) or nil
end

local function draw_field_edges(out, player, field, segment_budget)
  if field.claims <= 2 or #field.cells <= 1 then
    draw_circle(out, player, field.center, 1.8, color_for_item(field.item, 0.18), 5)
    draw_circle(out, player, field.center, 1.8, color_for_item(field.item, 0.75), 1.5)
    return segment_budget + 1
  end

  local lookup = {}
  for _, cell in ipairs(field.cells) do lookup[cell.key] = true end
  local size = M.cell_size
  local directions = {
    { dx = 0, dy = -1, side = "top" },
    { dx = 1, dy = 0, side = "right" },
    { dx = 0, dy = 1, side = "bottom" },
    { dx = -1, dy = 0, side = "left" },
  }

  for _, cell in ipairs(field.cells) do
    local x1 = cell.cx * size
    local y1 = cell.cy * size
    local x2 = x1 + size
    local y2 = y1 + size
    for _, direction in ipairs(directions) do
      if segment_budget >= M.max_edge_segments then return segment_budget end
      if not lookup[cell_key(cell.cx + direction.dx, cell.cy + direction.dy)] then
        local from, to
        if direction.side == "top" then
          from, to = { x = x1, y = y1 }, { x = x2, y = y1 }
        elseif direction.side == "right" then
          from, to = { x = x2, y = y1 }, { x = x2, y = y2 }
        elseif direction.side == "bottom" then
          from, to = { x = x2, y = y2 }, { x = x1, y = y2 }
        else
          from, to = { x = x1, y = y2 }, { x = x1, y = y1 }
        end
        draw_line(out, player, from, to, color_for_item(field.item, 0.16), 5)
        draw_line(out, player, from, to, color_for_item(field.item, 0.74), 1.5)
        segment_budget = segment_budget + 1
      end
    end
  end
  return segment_budget
end

function M.clear_player(player)
  if not player then return false end
  local r = root()
  destroy_list(r.objects_by_player[player.index])
  r.objects_by_player[player.index] = nil
  r.signature_by_player[player.index] = nil
  r.last_draw_tick_by_player[player.index] = nil
  return true
end

function M.clear_all()
  local r = root()
  for player_index, objects in pairs(r.objects_by_player) do
    destroy_list(objects)
    r.objects_by_player[player_index] = nil
    r.signature_by_player[player_index] = nil
    r.last_draw_tick_by_player[player_index] = nil
  end
end

function M.refresh_player(player)
  local r = root()
  if not (r.enabled and player and player.valid and player.surface and player.force and player_alt_enabled(player)) then
    return M.clear_player(player)
  end

  local signature = catalog_signature(player)
  local existing = r.objects_by_player[player.index]
  local last_draw = tonumber(r.last_draw_tick_by_player[player.index]) or -999999
  if r.signature_by_player[player.index] == signature
    and objects_valid(existing)
    and now() - last_draw < M.redraw_period
  then
    stat("stable_redraw_skips")
    return true
  end

  local fields, claim_count, unresolved = build_fields(player, signature)
  local out = {}
  local drawn_fields = 0
  local edge_segments = 0
  for _, field in ipairs(fields) do
    if drawn_fields >= M.max_fields or edge_segments >= M.max_edge_segments then break end
    if r.field_edges_enabled then
      edge_segments = draw_field_edges(out, player, field, edge_segments)
    end
    draw_sprite(out, player, field)
    if r.labels_enabled then
      draw_label(out, player, field, color_for_item(field.item, 0.96))
    end
    drawn_fields = drawn_fields + 1
  end

  local old = r.objects_by_player[player.index]
  r.objects_by_player[player.index] = out
  r.signature_by_player[player.index] = signature
  r.last_draw_tick_by_player[player.index] = now()
  destroy_list(old)

  r.stats.last_player = player.name
  r.stats.last_tick = now()
  r.stats.last_claim_count = claim_count
  r.stats.last_field_count = #fields
  r.stats.last_drawn_fields = drawn_fields
  r.stats.last_edge_segments = edge_segments
  r.stats.last_objects = #out
  r.stats.last_unresolved_claims = unresolved
  return true
end

function M.refresh_all()
  if not (game and game.connected_players) then return end
  for _, player in pairs(game.connected_players) do pcall(M.refresh_player, player) end
end

local function disable_legacy_per_entity_icons()
  local tp = storage and storage.tech_priests
  local legacy_root = tp and tp.alt_writ_visual_stability_0474
  if legacy_root then
    legacy_root.known_resource_alt_icons_enabled = false
    legacy_root.signature_by_player = {}
  end
end

local function remove_legacy_commands()
  if not (commands and commands.remove_command) then return end
  pcall(commands.remove_command, "tp-visual-stability-0474")
  pcall(commands.remove_command, "tp-visual-lease-0487")
end

local function patch_visual_authority()
  local visual = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  if not visual then
    local ok, loaded = pcall(require, "scripts.core.alt_writ_visual_stability_0474")
    if ok then visual = loaded end
  end
  if not visual then return false end

  disable_legacy_per_entity_icons()
  if visual.alt_resource_field_overlay_0679_wrapped then return true end
  visual.alt_resource_field_overlay_0679_wrapped = true

  previous_refresh_player = visual.refresh_player
  previous_clear_all = visual.clear_all
  previous_describe = visual.describe

  visual.refresh_player = function(player)
    disable_legacy_per_entity_icons()
    local result = true
    if type(previous_refresh_player) == "function" then
      local ok, value = pcall(previous_refresh_player, player)
      result = ok and value ~= false
    end
    M.refresh_player(player)
    return result
  end

  visual.clear_all = function(...)
    local result = true
    if type(previous_clear_all) == "function" then
      local ok, value = pcall(previous_clear_all, ...)
      result = ok and value ~= false
    end
    M.clear_all()
    return result
  end

  visual.describe = function(...)
    local base = type(previous_describe) == "function" and previous_describe(...) or ""
    local r = root()
    return base
      .. " resource-fields=" .. tostring(r.stats.last_drawn_fields or 0)
      .. " claimed=" .. tostring(r.stats.last_claim_count or 0)
      .. " edges=" .. tostring(r.stats.last_edge_segments or 0)
  end

  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
    or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.alt_resource_field_overlay_0679_wrapped
  then
    return
  end

  local previous = diagnostics.pair_dump_lines
  diagnostics.alt_resource_field_overlay_0679_wrapped = true
  diagnostics.pair_dump_lines = function()
    local lines = previous()
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ALT-RESOURCE-FIELDS-0679 enabled="
      .. safe(r.enabled)
      .. " claims=" .. safe(r.stats.last_claim_count or 0)
      .. " fields=" .. safe(r.stats.last_field_count or 0)
      .. " drawn=" .. safe(r.stats.last_drawn_fields or 0)
      .. " edges=" .. safe(r.stats.last_edge_segments or 0)
      .. " objects=" .. safe(r.stats.last_objects or 0)
      .. " unresolved=" .. safe(r.stats.last_unresolved_claims or 0)
      .. " cache_hits=" .. safe(r.stats.field_cache_hits or 0)
      .. " cache_rebuilds=" .. safe(r.stats.field_cache_rebuilds or 0)
    return lines
  end
end

function M.install()
  root()
  local catalog = catalog_module()
  if catalog then
    catalog.max_instances_per_item = math.max(tonumber(catalog.max_instances_per_item) or 256, 1024)
  end
  patch_visual_authority()
  patch_diagnostics()
  remove_legacy_commands()
  _G.TechPriestsAltResourceFieldOverlay0679 = M
  _G.tech_priests_refresh_claimed_resource_fields_0679 = M.refresh_all
  pcall(function()
    M.clear_all()
    M.refresh_all()
  end)
  if log then
    log("[Tech-Priests 0.1.663] ALT claimed-resource field overlay installed; all station claims aggregate into glowing field edges")
  end
  return true
end

return M
