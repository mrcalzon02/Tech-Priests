-- Tech Priests 0.1.259
-- Resource-directed station expansion doctrine.
--
-- When the Planetary Magos ratio planner needs dedicated resources such as
-- iron, copper, coal, stone, oil, or uranium, and the current station radius has
-- no map-resource access beyond emergency pseudo-miner recipes, the Magos
-- projects lower-tier Cogitator ghosts toward those resources.  If no matching
-- resource exists in generated map area, it expands in rotating outward bearings
-- until generation eventually reveals a useful patch.

TECH_PRIESTS_RESOURCE_EXPANSION_VERSION_0259 = "0.1.259"
TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259 = 60 * 20
TECH_PRIESTS_RESOURCE_EXPANSION_SEARCH_START_0259 = 64
TECH_PRIESTS_RESOURCE_EXPANSION_SEARCH_MAX_0259 = 2048
TECH_PRIESTS_RESOURCE_EXPANSION_SEARCH_STEP_0259 = 128
TECH_PRIESTS_RESOURCE_EXPANSION_MAX_RESOURCES_PER_PASS_0259 = 2

local function diag(message)
  if log then log("[Tech Priests 0.1.259 resource expansion] " .. tostring(message)) end
end

local function valid_pair(pair)
  if tech_priests_0248_valid_pair then return tech_priests_0248_valid_pair(pair) end
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

local function distance_sq(a, b)
  if tech_priests_distance_sq_0186 then return tech_priests_distance_sq_0186(a, b) end
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function radius(pair)
  local ok, r = pcall(function() if refresh_pair_radius then return refresh_pair_radius(pair) end return pair.radius or pair.base_radius or 30 end)
  if ok and r then return r end
  return 30
end

local function station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

local function is_magos(pair)
  if tech_priests_0255_pair_is_magos_planner then
    local ok, result = pcall(function() return tech_priests_0255_pair_is_magos_planner(pair) end)
    if ok and result then return true end
  end
  return false
end

local function product_name_matches(product, target)
  return product and product.name == target
end

local function resource_prototypes_for_product(product_name)
  local result = {}
  if not product_name then return result end
  for resource_name, proto in pairs((tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("entity")) or {}) do
    local ok_type, typ = pcall(function() return proto.type end)
    if ok_type and typ == "resource" then
      local ok_mine, mineable = pcall(function() return proto.mineable_properties end)
      if ok_mine and mineable and mineable.products then
        for _, product in pairs(mineable.products) do
          if product_name_matches(product, product_name) then
            result[#result + 1] = resource_name
            break
          end
        end
      end
    end
  end
  return result
end

local function resource_names_for_need(item_or_fluid)
  local names = resource_prototypes_for_product(item_or_fluid)
  -- Common aliases.  Crude oil is a fluid product, not an item, but it is a
  -- resource dependency for refinery planning.
  if #names == 0 and item_or_fluid == "crude-oil" and tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440("crude-oil") then
    names[#names + 1] = "crude-oil"
  end
  return names
end

local function current_radius_has_resource(pair, resource_names)
  if not (valid_pair(pair) and resource_names and #resource_names > 0) then return false end
  local station = pair.station
  local r = radius(pair)
  for _, resource_name in pairs(resource_names) do
    local found = station.surface.find_entities_filtered({
      name = resource_name,
      type = "resource",
      position = station.position,
      radius = r,
      limit = 1
    })
    if found and found[1] then return true end
  end
  return false
end

local function nearest_known_resource(pair, resource_names)
  if not (valid_pair(pair) and resource_names and #resource_names > 0) then return nil end
  local station = pair.station
  local center = station.position
  local best, best_score = nil, nil
  for search_r = TECH_PRIESTS_RESOURCE_EXPANSION_SEARCH_START_0259, TECH_PRIESTS_RESOURCE_EXPANSION_SEARCH_MAX_0259, TECH_PRIESTS_RESOURCE_EXPANSION_SEARCH_STEP_0259 do
    local area = {{center.x - search_r, center.y - search_r}, {center.x + search_r, center.y + search_r}}
    for _, resource_name in pairs(resource_names) do
      local found = station.surface.find_entities_filtered({ name = resource_name, type = "resource", area = area, limit = 256 })
      for _, entity in pairs(found or {}) do
        if entity and entity.valid then
          local score = distance_sq(center, entity.position)
          if score > (radius(pair) * radius(pair)) and (not best_score or score < best_score) then
            best, best_score = entity, score
          end
        end
      end
    end
    if best then return best end
  end
  return nil
end

local function exploration_angle(pair, key)
  local unit = station_unit(pair) or 1
  local tick = game and game.tick or 0
  local phase = math.floor(tick / TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259)
  local slot = (phase + unit + (key or 0)) % 8
  return (math.pi * 2) * (slot / 8)
end

local function op_for_pair(pair)
  if tech_priests_get_emergency_operation_0184 then
    local ok, op = pcall(function() return tech_priests_get_emergency_operation_0184(pair) end)
    if ok and op then return op end
  end
  pair.independent_emergency_operation_0184 = pair.independent_emergency_operation_0184 or { enabled = true, reason = "resource-expansion" }
  return pair.independent_emergency_operation_0184
end

local function build_need_list(pair, op)
  local result = {}
  if tech_priests_0257_build_ratio_plan then
    local ok, plan = pcall(function() return tech_priests_0257_build_ratio_plan(pair, op or {}) end)
    if ok and plan then
      for item_name, _ in pairs(plan.raw_items or {}) do result[#result + 1] = item_name end
      for fluid_name, _ in pairs(plan.fluids or {}) do
        if fluid_name == "crude-oil" or string.find(fluid_name, "oil", 1, true) then result[#result + 1] = "crude-oil" end
      end
      if (plan.groups and (plan.groups.oil or 0) > 0) then result[#result + 1] = "crude-oil" end
    end
  end
  if #result == 0 then
    -- Conservative default field-industry dependencies.
    result = { "iron-ore", "copper-ore", "coal", "stone" }
  end
  local seen, unique = {}, {}
  for _, name in pairs(result) do
    if name and not seen[name] then seen[name] = true; unique[#unique + 1] = name end
  end
  return unique
end

function tech_priests_0259_resource_expansion_service(pair)
  if not (valid_pair(pair) and is_magos(pair)) then return false end
  local op = op_for_pair(pair)
  local state = pair.resource_expansion_0259 or { next_tick = 0, last_need = nil, last_direction = nil, last_reason = nil }
  pair.resource_expansion_0259 = state
  if game and game.tick and game.tick < (state.next_tick or 0) then return false end
  state.next_tick = (game and game.tick or 0) + TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259

  local StationExpansion = _G.TECH_PRIESTS_STATION_EXPANSION_0256 or package.loaded["scripts.magos_station_expansion"]
  if not (StationExpansion and StationExpansion.request_station_expansion) then
    state.last_reason = "station expansion module unavailable"
    return false
  end

  local issued = 0
  local needs = build_need_list(pair, op)
  for idx, need in pairs(needs) do
    local resources = resource_names_for_need(need)
    if #resources > 0 and not current_radius_has_resource(pair, resources) then
      local nearest = nearest_known_resource(pair, resources)
      local angle = nil
      if nearest and nearest.valid then
        angle = math.atan2(nearest.position.y - pair.station.position.y, nearest.position.x - pair.station.position.x)
        state.last_reason = "toward known " .. tostring(need) .. " resource " .. tostring(nearest.name)
      else
        angle = exploration_angle(pair, idx)
        state.last_reason = "exploratory expansion for missing " .. tostring(need)
      end
      local ok = StationExpansion.request_station_expansion(pair, "resource:" .. tostring(need), op, state.last_reason, angle)
      if ok then
        issued = issued + 1
        state.last_need = need
        state.last_direction = angle
        op.resource_expansion_need_0259 = need
        op.resource_expansion_reason_0259 = state.last_reason
        if issued >= TECH_PRIESTS_RESOURCE_EXPANSION_MAX_RESOURCES_PER_PASS_0259 then break end
      end
    end
  end
  return false
end

if tech_priests_service_independent_emergency_operation_0184 and not TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0259_RESOURCE then
  TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0259_RESOURCE = tech_priests_service_independent_emergency_operation_0184
  function tech_priests_service_independent_emergency_operation_0184(pair)
    pcall(function() tech_priests_0259_resource_expansion_service(pair) end)
    return TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0259_RESOURCE(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    commands.add_command("tp-resource-expansion-debug", "Tech Priests: report Planetary Magos resource-directed expansion state.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then player.print("[Tech Priests] Select a Planetary Magos station or priest first."); return end
      local op = op_for_pair(pair)
      local needs = build_need_list(pair, op)
      local state = pair.resource_expansion_0259 or {}
      player.print("[Tech Priests] resource expansion debug: magos=" .. tostring(is_magos(pair)) .. " last_need=" .. tostring(state.last_need or "none") .. " reason=" .. tostring(state.last_reason or "none"))
      for _, need in pairs(needs) do
        local res = resource_names_for_need(need)
        player.print("  need=" .. tostring(need) .. " resources=" .. tostring(table.concat(res, ",")) .. " in_radius=" .. tostring(current_radius_has_resource(pair, res)))
      end
    end)
  end)
end

diag("resource-directed station expansion doctrine loaded")
