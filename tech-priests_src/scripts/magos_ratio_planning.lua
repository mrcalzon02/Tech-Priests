-- Tech Priests 0.1.257
-- Planetary Magos ratio-aware recipe planning.
--
-- This late-loaded layer makes the Magos standard-industry planner estimate a
-- small production chain from the current objective item and build additional
-- machines until the local field industry roughly matches that chain.  It is
-- intentionally conservative: it produces low target rates, caps demand, and
-- uses the existing acquisition/construction ladder instead of bypassing it.

TECH_PRIESTS_MAGOS_RATIO_PLANNER_VERSION_0257 = "0.1.257"
TECH_PRIESTS_MAGOS_RATIO_TARGET_ITEMS_PER_SECOND_0257 = 1 / (60 * 2) -- one objective item every two minutes
TECH_PRIESTS_MAGOS_RATIO_MAX_DEPTH_0257 = 5
TECH_PRIESTS_MAGOS_RATIO_MAX_PER_GROUP_0257 = 12
TECH_PRIESTS_MAGOS_RATIO_MIN_CONNECTOR_SET_0257 = 2

function tech_priests_0257_diag(message)
  if log then log("[Tech Priests 0.1.257 Magos ratio planner] " .. tostring(message)) end
end

local function tech_priests_0257_count_table_values(t)
  local n = 0
  for _, v in pairs(t or {}) do n = n + (tonumber(v) or 0) end
  return n
end

local function tech_priests_0257_entity_valid(name)
  return name and tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(name) ~= nil
end

local function tech_priests_0257_item_valid(name)
  return name and tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) ~= nil
end

local function tech_priests_0257_recipe_valid(name)
  return name and tech_priests_get_recipe_prototype_0440 and tech_priests_get_recipe_prototype_0440(name) ~= nil
end

local function tech_priests_0257_recipe_hidden(recipe)
  local ok, hidden = pcall(function() return recipe.hidden end)
  return ok and hidden or false
end

local function tech_priests_0257_recipe_category(recipe)
  local ok, category = pcall(function() return recipe.category end)
  if ok then return category end
  return nil
end

local function tech_priests_0257_recipe_energy(recipe)
  local ok, energy = pcall(function() return recipe.energy end)
  if ok and tonumber(energy) and energy > 0 then return energy end
  return 0.5
end

local function tech_priests_0257_recipe_products(recipe)
  local ok, products = pcall(function() return recipe.products end)
  if ok and products then return products end
  return {}
end

local function tech_priests_0257_recipe_ingredients(recipe)
  local ok, ingredients = pcall(function() return recipe.ingredients end)
  if ok and ingredients then return ingredients end
  return {}
end

local function tech_priests_0257_product_amount(recipe, item_name)
  local amount = 0
  for _, product in pairs(tech_priests_0257_recipe_products(recipe)) do
    if product and product.name == item_name and (not product.type or product.type == "item") then
      amount = amount + (tonumber(product.amount) or tonumber(product.amount_min) or 1)
    end
  end
  if amount <= 0 then amount = 1 end
  return amount
end

local function tech_priests_0257_machine_speed_for_group(group)
  local groups = TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255 or {}
  for _, entity_name in pairs(groups[group] or {}) do
    if tech_priests_0257_entity_valid(entity_name) then
      local proto = tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity_name) or nil
      if proto then
        local ok_speed, speed = pcall(function() return proto.crafting_speed end)
        if ok_speed and tonumber(speed) and speed > 0 then return speed end
        local ok_mining, mining = pcall(function() return proto.mining_speed end)
        if ok_mining and tonumber(mining) and mining > 0 then return mining end
      end
    end
  end
  return 1
end

local function tech_priests_0257_group_for_recipe(recipe)
  local category = tech_priests_0257_recipe_category(recipe) or ""
  if category == "smelting" or category == "metallurgy" then return "smelters" end
  if category == "chemistry" or category == "oil-processing" or category == "chemistry-or-cryogenics" then return "chemical" end
  if category == "crafting" or category == "basic-crafting" or category == "advanced-crafting" or category == "crafting-with-fluid" then return "assemblers" end
  if string.find(category, "chem", 1, true) or string.find(category, "oil", 1, true) then return "chemical" end
  if string.find(category, "smelt", 1, true) or string.find(category, "furnace", 1, true) then return "smelters" end
  return "assemblers"
end

local function tech_priests_0257_recipe_produces(recipe, item_name)
  for _, product in pairs(tech_priests_0257_recipe_products(recipe)) do
    if product and product.name == item_name and (not product.type or product.type == "item") then return true end
  end
  return false
end

local function tech_priests_0257_pick_recipe_for_item(item_name)
  if not item_name then return nil end
  local recipe_prototypes = (tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("recipe")) or {}

  -- Prefer direct recipe name matches when possible.
  local direct = recipe_prototypes[item_name]
  if direct and tech_priests_0257_recipe_produces(direct, item_name) and not tech_priests_0257_recipe_hidden(direct) then
    return direct
  end

  local best = nil
  local best_score = -9999
  for _, recipe in pairs(recipe_prototypes) do
    if tech_priests_0257_recipe_produces(recipe, item_name) and not tech_priests_0257_recipe_hidden(recipe) then
      local category = tech_priests_0257_recipe_category(recipe) or ""
      local score = 0
      if recipe.name == item_name then score = score + 50 end
      if category == "crafting" or category == "basic-crafting" then score = score + 20 end
      if category == "smelting" then score = score + 15 end
      if category == "advanced-crafting" then score = score + 10 end
      if category == "chemistry" or category == "oil-processing" then score = score + 5 end
      local ingredients = tech_priests_0257_recipe_ingredients(recipe)
      score = score - #ingredients
      if score > best_score then
        best = recipe
        best_score = score
      end
    end
  end
  return best
end

local function tech_priests_0257_is_raw_item(item_name)
  if not item_name then return false end
  if item_name == "wood" or item_name == "coal" or item_name == "stone" or item_name == "iron-ore" or item_name == "copper-ore" or item_name == "uranium-ore" then return true end
  -- Treat items emitted by map resources as raw for ratio purposes.
  do
    for _, proto in pairs((tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("entity")) or {}) do
      local ok_type, typ = pcall(function() return proto.type end)
      if ok_type and typ == "resource" then
        local ok_mine, mineable = pcall(function() return proto.mineable_properties end)
        if ok_mine and mineable and mineable.products then
          for _, product in pairs(mineable.products) do
            if product and product.name == item_name then return true end
          end
        end
      end
    end
  end
  return false
end

local function tech_priests_0257_add_need(plan, key, count)
  if not key then return end
  plan[key] = math.max(plan[key] or 0, math.min(TECH_PRIESTS_MAGOS_RATIO_MAX_PER_GROUP_0257, math.ceil(count or 1)))
end

local function tech_priests_0257_decompose_item(plan, item_name, required_rate, depth, seen)
  if not item_name or required_rate <= 0 then return end
  if depth > TECH_PRIESTS_MAGOS_RATIO_MAX_DEPTH_0257 then return end
  seen = seen or {}
  if seen[item_name] then return end
  seen[item_name] = true

  if tech_priests_0257_is_raw_item(item_name) then
    local miner_speed = tech_priests_0257_machine_speed_for_group("miners")
    local miner_count = math.max(1, math.ceil(required_rate / math.max(0.005, miner_speed * 0.20)))
    tech_priests_0257_add_need(plan.groups, "miners", miner_count)
    plan.raw_items[item_name] = (plan.raw_items[item_name] or 0) + required_rate
    seen[item_name] = nil
    return
  end

  local recipe = tech_priests_0257_pick_recipe_for_item(item_name)
  if not recipe then
    -- Unknown intermediates are acquisition targets but do not imply a machine.
    plan.unresolved[item_name] = (plan.unresolved[item_name] or 0) + required_rate
    seen[item_name] = nil
    return
  end

  local group = tech_priests_0257_group_for_recipe(recipe)
  local output_amount = tech_priests_0257_product_amount(recipe, item_name)
  local energy = tech_priests_0257_recipe_energy(recipe)
  local speed = tech_priests_0257_machine_speed_for_group(group)
  local machines = math.max(1, math.ceil((required_rate * energy) / math.max(0.001, output_amount * speed)))
  tech_priests_0257_add_need(plan.groups, group, machines)
  plan.recipes[recipe.name] = { item = item_name, group = group, rate = required_rate, machines = machines }

  if group == "chemical" then
    tech_priests_0257_add_need(plan.groups, "chemical", machines)
    if tech_priests_0257_recipe_category(recipe) == "oil-processing" then tech_priests_0257_add_need(plan.groups, "oil", 1) end
  end

  for _, ingredient in pairs(tech_priests_0257_recipe_ingredients(recipe)) do
    if ingredient and ingredient.name and (not ingredient.type or ingredient.type == "item") then
      local amount = tonumber(ingredient.amount) or 1
      local ingredient_rate = required_rate * amount / math.max(1, output_amount)
      tech_priests_0257_decompose_item(plan, ingredient.name, ingredient_rate, depth + 1, seen)
    elseif ingredient and ingredient.type == "fluid" then
      tech_priests_0257_add_need(plan.groups, "chemical", 1)
      tech_priests_0257_add_need(plan.groups, "oil", 1)
      plan.fluids[ingredient.name or "fluid"] = (plan.fluids[ingredient.name or "fluid"] or 0) + (tonumber(ingredient.amount) or 1)
    end
  end

  seen[item_name] = nil
end

function tech_priests_0257_build_ratio_plan(pair, op)
  local plan = {
    objective = nil,
    groups = {},
    recipes = {},
    raw_items = {},
    fluids = {},
    unresolved = {},
    target_rate = TECH_PRIESTS_MAGOS_RATIO_TARGET_ITEMS_PER_SECOND_0257,
    connector_need = {}
  }
  if not (pair and op) then return plan end

  local objective = nil
  if tech_priests_0255_current_planning_item then
    local ok, item = pcall(function() return tech_priests_0255_current_planning_item(pair, op) end)
    if ok then objective = item end
  end
  if not objective then objective = "automation-science-pack" end
  plan.objective = objective

  tech_priests_0257_decompose_item(plan, objective, plan.target_rate, 0, {})

  -- Science objectives imply at least one lab.  Slow doctrine, but not zero doctrine.
  if string.find(objective, "science", 1, true) or objective == "automation-science-pack" then
    tech_priests_0257_add_need(plan.groups, "labs", 1)
  end

  local production_machine_count = (plan.groups.miners or 0) + (plan.groups.smelters or 0) + (plan.groups.assemblers or 0) + (plan.groups.chemical or 0) + (plan.groups.oil or 0)
  local inserters = math.max(TECH_PRIESTS_MAGOS_RATIO_MIN_CONNECTOR_SET_0257, math.ceil(production_machine_count * 1.5))
  local belts = math.max(TECH_PRIESTS_MAGOS_RATIO_MIN_CONNECTOR_SET_0257, math.ceil(production_machine_count * 2))
  local pipes = math.max(0, ((plan.groups.chemical or 0) + (plan.groups.oil or 0)) * 3)
  plan.connector_need["inserter"] = inserters
  plan.connector_need["transport-belt"] = belts
  if pipes > 0 then plan.connector_need["pipe"] = pipes end

  -- Basic power should scale with consumers.  This is crude but prevents one
  -- lonely pole from satisfying a growing field industry.
  local electric_consumers = (plan.groups.assemblers or 0) + (plan.groups.chemical or 0) + (plan.groups.oil or 0) + (plan.groups.labs or 0)
  if electric_consumers > 0 then
    tech_priests_0257_add_need(plan.groups, "power", math.max(1, math.ceil(electric_consumers / 3)))
  end

  return plan
end

function tech_priests_0257_count_group_entities(pair, group_name)
  if not (pair and pair.station and pair.station.valid and group_name) then return 0 end
  local station = pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or 30
  local names = (TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255 and TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255[group_name]) or {}
  local count = 0
  for _, entity_name in pairs(names) do
    if tech_priests_0257_entity_valid(entity_name) then
      local found = station.surface.find_entities_filtered({
        name = entity_name,
        force = station.force,
        position = station.position,
        radius = radius
      })
      count = count + #(found or {})
    end
  end
  return count
end

function tech_priests_0257_count_specific_entity(pair, entity_name)
  if not (pair and pair.station and pair.station.valid and entity_name and tech_priests_0257_entity_valid(entity_name)) then return 0 end
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or 30
  local found = pair.station.surface.find_entities_filtered({ name = entity_name, force = pair.station.force, position = pair.station.position, radius = radius })
  return #(found or {})
end

function tech_priests_0257_first_available_item_for_group(group_name)
  if tech_priests_0255_first_available_item and TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255 then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255[group_name] or {})
  end
  return nil
end

function tech_priests_0257_pick_ratio_need(pair, op)
  if not (pair and op) then return nil, nil, nil end
  local plan = tech_priests_0257_build_ratio_plan(pair, op)
  op.magos_ratio_plan_0257 = plan

  local group_order = { "power", "miners", "smelters", "assemblers", "chemical", "oil", "labs" }
  for _, group in pairs(group_order) do
    local desired = tonumber(plan.groups[group] or 0) or 0
    if desired > 0 then
      local have = tech_priests_0257_count_group_entities(pair, group)
      if have < desired then
        local item_name = tech_priests_0257_first_available_item_for_group(group)
        if item_name then
          op.magos_ratio_phase_0257 = "ratio-" .. group
          op.magos_ratio_group_0257 = group
          op.magos_ratio_have_0257 = have
          op.magos_ratio_desired_0257 = desired
          op.magos_ratio_item_0257 = item_name
          return item_name, "ratio-" .. group .. " " .. tostring(have) .. "/" .. tostring(desired), plan
        end
      end
    end
  end

  -- Connector counts are entity-specific rather than group-wide, because the
  -- planner needs both belts and inserters, not merely one arbitrary connector.
  local connector_order = { "transport-belt", "inserter", "pipe" }
  for _, connector in pairs(connector_order) do
    local desired = tonumber(plan.connector_need[connector] or 0) or 0
    if desired > 0 and tech_priests_0257_item_valid(connector) and tech_priests_0257_entity_valid(connector) then
      local have = tech_priests_0257_count_specific_entity(pair, connector)
      if have < desired then
        op.magos_ratio_phase_0257 = "ratio-connector"
        op.magos_ratio_group_0257 = connector
        op.magos_ratio_have_0257 = have
        op.magos_ratio_desired_0257 = desired
        op.magos_ratio_item_0257 = connector
        return connector, "ratio-connector " .. connector .. " " .. tostring(have) .. "/" .. tostring(desired), plan
      end
    end
  end

  op.magos_ratio_phase_0257 = "ratio-satisfied"
  op.magos_ratio_group_0257 = nil
  op.magos_ratio_have_0257 = nil
  op.magos_ratio_desired_0257 = nil
  op.magos_ratio_item_0257 = nil
  return nil, nil, plan
end

if tech_priests_0255_pick_standard_need then
  TECH_PRIESTS_ORIGINAL_PICK_STANDARD_NEED_0257 = tech_priests_0255_pick_standard_need
  function tech_priests_0255_pick_standard_need(pair, op)
    local central = pair and pair.master_infrastructure_plan_0644 or nil
    if central and central.stage and central.stage ~= "ready" then
      return nil, "central-martian-bootstrap:" .. tostring(central.stage)
    end
    if tech_priests_0255_pair_is_magos_planner and tech_priests_0255_pair_is_magos_planner(pair) then
      local item, reason = tech_priests_0257_pick_ratio_need(pair, op)
      if item then return item, reason end
    end
    return TECH_PRIESTS_ORIGINAL_PICK_STANDARD_NEED_0257(pair, op)
  end
end

if commands and commands.add_command then
  pcall(function()
    commands.add_command("tp-magos-ratio-debug", "Tech Priests: report Planetary Magos ratio-aware recipe planning demand for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then
        player.print("[Tech Priests] Select a Planetary Magos Cogitator Station or its priest first.")
        return
      end
      local op = tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair) or pair.independent_emergency_operation_0184 or {}
      local plan = tech_priests_0257_build_ratio_plan(pair, op)
      local item, reason = tech_priests_0257_pick_ratio_need(pair, op)
      player.print("[Tech Priests] Planetary Magos ratio planner diagnostics:")
      player.print("  objective=" .. tostring(plan.objective) .. " target_rate=" .. tostring(plan.target_rate) .. " item/s")
      player.print("  next_ratio_need=" .. tostring(item or "none") .. " reason=" .. tostring(reason or "ratio satisfied"))
      local order = { "power", "miners", "smelters", "assemblers", "chemical", "oil", "labs" }
      for _, group in pairs(order) do
        local desired = tonumber(plan.groups[group] or 0) or 0
        if desired > 0 then
          player.print("  group " .. group .. ": have=" .. tostring(tech_priests_0257_count_group_entities(pair, group)) .. " desired=" .. tostring(desired))
        end
      end
      for connector, desired in pairs(plan.connector_need or {}) do
        if desired and desired > 0 then
          player.print("  connector " .. connector .. ": have=" .. tostring(tech_priests_0257_count_specific_entity(pair, connector)) .. " desired=" .. tostring(desired))
        end
      end
      local recipe_count = tech_priests_0257_count_table_values(plan.recipes)
      player.print("  planned_recipes=" .. tostring(recipe_count) .. " raw_items=" .. tostring(tech_priests_0257_count_table_values(plan.raw_items)) .. " unresolved=" .. tostring(tech_priests_0257_count_table_values(plan.unresolved)))
      local shown = 0
      for recipe_name, info in pairs(plan.recipes or {}) do
        shown = shown + 1
        if shown <= 8 then
          player.print("    recipe " .. tostring(recipe_name) .. " -> group=" .. tostring(info.group) .. " machines=" .. tostring(info.machines) .. " item=" .. tostring(info.item))
        end
      end
    end)
  end)
end

tech_priests_0257_diag("Planetary Magos ratio-aware recipe planner loaded")
