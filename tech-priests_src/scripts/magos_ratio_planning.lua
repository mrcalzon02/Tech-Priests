-- Tech Priests 0.1.257
-- Planetary Magos ratio-aware recipe planning.
--
-- This late-loaded layer makes the Magos standard-industry planner estimate a
-- small production chain from the current objective item and build additional
-- machines until the local field industry roughly matches that chain.  It is
-- intentionally conservative: it produces low target rates, caps demand, and
-- uses the existing acquisition/construction ladder instead of bypassing it.

TECH_PRIESTS_MAGOS_RATIO_PLANNER_VERSION_0257 = "0.1.257"
-- 1133: The old constant yielded 0.5 packs/minute and silently kept every
-- factory at a token-size pilot rate. This is the conservative *starting*
-- science throughput objective, not proof of production or research.
TECH_PRIESTS_MAGOS_RATIO_DEFAULT_SPM_1133 = 5
TECH_PRIESTS_MAGOS_RATIO_MAX_SPM_1133 = 60
TECH_PRIESTS_MAGOS_RATIO_TARGET_ITEMS_PER_SECOND_0257 =
  TECH_PRIESTS_MAGOS_RATIO_DEFAULT_SPM_1133 / 60
-- 1189: a shallow five-step cutoff silently dropped modded technology
-- dependencies. Bound the graph but return explicit unresolved evidence.
TECH_PRIESTS_MAGOS_RATIO_MAX_DEPTH_0257 = 12
TECH_PRIESTS_MAGOS_RATIO_MAX_VISITS_1189 = 192
TECH_PRIESTS_MAGOS_RATIO_MAX_PER_GROUP_0257 = 48
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

-- Factorio product yields may be fractional, probabilistic, or bounded.
-- Never silently replace a missing/zero yield with one fabricated product.
local function tech_priests_0257_product_amount(recipe, item_name, kind)
  local amount=0
  kind=kind or "item"
  for _,product in pairs(tech_priests_0257_recipe_products(recipe)) do
    if product and product.name==item_name
        and (product.type or "item")==kind then
      local quantity=tonumber(product.amount)
      if not quantity then
        local low=tonumber(product.amount_min)
        local high=tonumber(product.amount_max)
        if low and high then quantity=(low+high)/2
        else quantity=low or high or 1 end
      end
      local probability=tonumber(product.probability) or 1
      if quantity>=0 and probability>=0 and probability<=1 then
        amount=amount+quantity*probability
      end
    end
  end
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

local function tech_priests_0257_recipe_produces(recipe,item_name,kind)
  return tech_priests_0257_product_amount(recipe,item_name,kind)>0
end

-- A modded item may have several producers, including a locked recipe whose
-- name exactly matches the item. Never choose unavailable recipes or let Lua
-- hash iteration decide which factory gets built. Only known enabled recipes
-- can be selected when Factorio exposes its actual force recipe table.
local function tech_priests_0257_pick_recipe_for_item(item_name,force,kind)
  if not item_name then return nil,"missing-product-name" end
  kind=kind or "item"
  local all=(tech_priests_prototype_table_0440
    and tech_priests_prototype_table_0440("recipe")) or {}
  local candidates,locked={},false
  for name,recipe in pairs(all) do
    if recipe and tech_priests_0257_recipe_produces(recipe,item_name,kind)
        and not tech_priests_0257_recipe_hidden(recipe) then
      local recipe_name=recipe.name or name
      local live=force and force.recipes
      local enabled=not live or (live[recipe_name] and
        live[recipe_name].enabled==true)
      if not enabled then
        locked=true
      else
        local category=tech_priests_0257_recipe_category(recipe) or ""
        local score=0
        if recipe_name==item_name then score=score+50 end
        if category=="crafting" or category=="basic-crafting" then
          score=score+20
        elseif category=="smelting" then score=score+15
        elseif category=="advanced-crafting" then score=score+10
        elseif category=="chemistry" or category=="oil-processing" then
          score=score+5 end
        score=score-#tech_priests_0257_recipe_ingredients(recipe)
        candidates[#candidates+1]={recipe=recipe,name=recipe_name,
          score=score}
      end
    end
  end
  table.sort(candidates,function(a,b)
    if a.score~=b.score then return a.score>b.score end
    return tostring(a.name)<tostring(b.name)
  end)
  if candidates[1] then return candidates[1].recipe,nil end
  return nil,locked and "recipe-locked-for-force"
    or "no-known-positive-yield-recipe"
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

-- Independent recipe and mineral streams ADD machine demand. The previous
-- add_need() max merged distinct furnace/assembler recipes, underbuilding a
-- functioning science line even when all its parts were available.
local function tech_priests_1133_add_machine_demand(plan,group,delta)
  if not (group and delta and delta>0) then return end
  plan.uncapped_groups[group]=(plan.uncapped_groups[group] or 0)+delta
  local total=plan.uncapped_groups[group]
  plan.groups[group]=math.min(TECH_PRIESTS_MAGOS_RATIO_MAX_PER_GROUP_0257,
    math.max(plan.groups[group] or 0,total))
  if total>TECH_PRIESTS_MAGOS_RATIO_MAX_PER_GROUP_0257 then
    plan.capacity_limited[group]=total-
      TECH_PRIESTS_MAGOS_RATIO_MAX_PER_GROUP_0257
  end
end

-- 1138: An explicit recipe input graph, NOT a claim of built belts or
-- connectors. Each link tracks actual source ingredients and demanded rates.
-- The canonical site planner must later design and construct these links.
local function tech_priests_1138_record_factory_link(plan,consumer,item,kind,rate)
  if not (type(consumer)=="string" and type(item)=="string"
      and (kind=="item" or kind=="fluid")
      and type(rate)=="number" and rate>0 and rate<math.huge) then return end
  local key=consumer.."|"..kind.."|"..item
  local link=plan.factory_links[key]
  if not link then
    link={consumer_recipe=consumer,source_item=item,
      source_kind=kind,rate_per_second=0}
    plan.factory_links[key]=link
  end
  link.rate_per_second=link.rate_per_second+rate
end

-- Read-only Factorio 2.0 engine production counter, per FORCE and SURFACE,
-- not per individual Cogitator; an observed zero is NOT a completed factory.
-- The API normalizes item flows to per-minute. Never credit station stock
-- or planner forecasts as measured science production.
function tech_priests_1133_observe_science_spm(pair,item)
  if not(pair and pair.station and pair.station.valid
      and pair.station.force and pair.station.surface
      and type(item)=="string" and tech_priests_0257_item_valid(item))then
    return nil,"not-a-valid-science-observation"
  end
  local force=pair.station.force
  local precision=defines and defines.flow_precision_index
    and defines.flow_precision_index.one_minute
  if type(force.get_item_production_statistics)~="function"
      or precision==nil then
    return nil,"factorio-item-production-statistics-unavailable"
  end
  local ok,stats=pcall(force.get_item_production_statistics,
    pair.station.surface)
  if not(ok and stats and stats.valid~=false
      and type(stats.get_flow_count)=="function")then
    return nil,"force-surface-production-statistics-unreadable"
  end
  local read,value=pcall(stats.get_flow_count,{
    name=item,category="input",precision_index=precision})
  if not(read and type(value)=="number" and value>=0
      and value==value and value<math.huge)then
    return nil,"science-production-flow-unreadable"
  end
  return value,"observed-force-surface-one-minute-production"
end

local function tech_priests_1189_mark_unresolved(plan,name,kind,rate,cause)
  local key=(kind=="fluid" and "fluid|" or "")..tostring(name)
  plan.unresolved[key]=(plan.unresolved[key] or 0)+(tonumber(rate) or 0)
  plan.unresolved_reasons_1189[key]=cause
  plan.graph_complete_1189=false
end

local function tech_priests_0257_decompose_item(plan, item_name, required_rate, depth, seen, force)
  if not item_name or required_rate<=0 then return end
  local key="item|"..tostring(item_name)
  plan.nodes_visited_1189=(plan.nodes_visited_1189 or 0)+1
  if plan.nodes_visited_1189>TECH_PRIESTS_MAGOS_RATIO_MAX_VISITS_1189 then
    tech_priests_1189_mark_unresolved(plan,item_name,"item",
      required_rate,"dependency-visit-cap")
    return
  end
  if depth>TECH_PRIESTS_MAGOS_RATIO_MAX_DEPTH_0257 then
    tech_priests_1189_mark_unresolved(plan,item_name,"item",
      required_rate,"dependency-depth-limit")
    return
  end
  seen=seen or {}
  if seen[key] then
    tech_priests_1189_mark_unresolved(plan,item_name,"item",
      required_rate,"cyclic-recipe-dependency")
    return
  end
  seen[key]=true

  if tech_priests_0257_is_raw_item(item_name) then
    local miner_speed = tech_priests_0257_machine_speed_for_group("miners")
    local old_rate=plan.raw_items[item_name] or 0
    local new_rate=old_rate+required_rate
    local old_miners=old_rate>0
      and math.ceil(old_rate / math.max(0.005, miner_speed * 0.20)) or 0
    local new_miners=math.ceil(new_rate / math.max(0.005, miner_speed * 0.20))
    tech_priests_1133_add_machine_demand(
      plan,"miners",new_miners-old_miners)
    plan.raw_items[item_name]=new_rate
    seen[key]=nil
    return
  end

  local recipe,recipe_reason=tech_priests_0257_pick_recipe_for_item(
    item_name,force,"item")
  if not recipe then
    -- Missing or locked modded intermediates are explicit blockers,
    -- never invented machines or a false complete science recipe chain.
    tech_priests_1189_mark_unresolved(plan,item_name,"item",
      required_rate,recipe_reason)
    seen[key]=nil
    return
  end

  local group = tech_priests_0257_group_for_recipe(recipe)
  local output_amount = tech_priests_0257_product_amount(recipe, item_name)
  if output_amount<=0 then
    tech_priests_1189_mark_unresolved(plan,item_name,"item",
      required_rate,"nonproductive-recipe-output")
    seen[key]=nil
    return
  end
  local energy = tech_priests_0257_recipe_energy(recipe)
  local speed = tech_priests_0257_machine_speed_for_group(group)
  local previous=plan.recipes[recipe.name]
  local total_rate=required_rate+(previous and previous.rate or 0)
  local machines=math.max(1,math.ceil((total_rate*energy)/
    math.max(0.001,output_amount*speed)))
  tech_priests_1133_add_machine_demand(
    plan,group,machines-(previous and previous.machines or 0))
  plan.recipes[recipe.name]={item=item_name,group=group,
    rate=total_rate,machines=machines,
    expected_output_per_minute=total_rate*60}

  if group == "chemical" then
    tech_priests_0257_add_need(plan.groups, "chemical", machines)
    if tech_priests_0257_recipe_category(recipe) == "oil-processing" then tech_priests_0257_add_need(plan.groups, "oil", 1) end
  end

  for _, ingredient in pairs(tech_priests_0257_recipe_ingredients(recipe)) do
    if ingredient and ingredient.name and (not ingredient.type or ingredient.type == "item") then
      local amount = tonumber(ingredient.amount) or 1
      local ingredient_rate = required_rate * amount /
        math.max(0.000001,output_amount)
      tech_priests_1138_record_factory_link(
        plan,recipe.name,ingredient.name,"item",ingredient_rate)
      tech_priests_0257_decompose_item(plan, ingredient.name,
        ingredient_rate,depth+1,seen,force)
    elseif ingredient and ingredient.type == "fluid" then
      tech_priests_1138_record_factory_link(
        plan,recipe.name,ingredient.name or "fluid","fluid",
        required_rate*(tonumber(ingredient.amount) or 1)
          / math.max(0.000001,output_amount))
      tech_priests_0257_add_need(plan.groups, "chemical", 1)
      tech_priests_0257_add_need(plan.groups, "oil", 1)
      local fluid_name=ingredient.name or "unknown-fluid"
      local fluid_rate=required_rate*(tonumber(ingredient.amount) or 1)
        /math.max(0.000001,output_amount)
      plan.fluids[fluid_name]=(plan.fluids[fluid_name] or 0)
        +fluid_rate
      -- 1189 audit: do not silently treat unknown fluid supply as
      -- completed piping. Typed fluid producer recursion follows next.
      if fluid_name=="unknown-fluid" then
        tech_priests_1189_mark_unresolved(plan,fluid_name,"fluid",
          fluid_rate,"fluid-name-missing")
      end
    end
  end

  seen[key]=nil
end

-- 1136: Multiple science packs are needed for the SAME research progress.
-- Factorio's live LuaTechnology exposes research_unit_ingredients; honor
-- their exact per-unit quantities and preserve the active research identity.
-- A selected non-science production order remains an ordinary objective.
local function tech_priests_1136_required_science_basket(pair,objective)
  local basket={}
  if type(objective)~="string"
      or not objective:find("science",1,true) then return basket,nil end
  local research=nil
  local ok,current=pcall(function()
    return pair and pair.station and pair.station.force
      and pair.station.force.current_research
  end)
  if ok then research=current end
  local read,ingredients=pcall(function()
    return research and research.research_unit_ingredients
  end)
  if read and type(ingredients)=="table" then
    for _,entry in pairs(ingredients)do
      local name=entry and (entry.name or entry[1])
      local amount=entry and tonumber(entry.amount or entry[2])
      -- A modded technology can consume "knowledge-token", "mana-vial",
      -- or ANY other valid item. Item names do not define science.
      -- Factorio's native research_unit_ingredients IS the authority.
      if type(name)=="string"
          and (not entry.type or entry.type=="item")
          and amount and amount>0 and amount<1000 then
        basket[name]=(basket[name] or 0)+amount
      end
    end
  end
  if not next(basket) then basket[objective]=1 end
  return basket,research and research.name or nil
end

function tech_priests_0257_build_ratio_plan(pair, op)
  local plan = {
    objective = nil,
    groups = {},
    recipes = {},
    factory_links = {},
    factory_link_order = {},
    raw_items = {},
    fluids = {},
    unresolved = {},
    unresolved_reasons_1189 = {},
    graph_complete_1189 = true,
    nodes_visited_1189 = 0,
    uncapped_groups = {},
    capacity_limited = {},
    target_spm = nil,
    science_packs = {},
    observed_spm_by_pack = {},
    science_technology = nil,
    observed_spm = nil,
    observed_spm_scope = nil,
    observed_spm_reason = nil,
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
  if type(objective)=="string"
      and objective:find("science",1,true) then
    local requested=tonumber(pair.science_spm_target_1133
      or op.science_spm_target_1133
      or TECH_PRIESTS_MAGOS_RATIO_DEFAULT_SPM_1133)
    if not requested or requested~=requested then
      requested=TECH_PRIESTS_MAGOS_RATIO_DEFAULT_SPM_1133
    end
    plan.target_spm=math.max(1,math.min(
      TECH_PRIESTS_MAGOS_RATIO_MAX_SPM_1133,requested))
    plan.target_rate=plan.target_spm/60
    plan.science_packs,plan.science_technology=
      tech_priests_1136_required_science_basket(pair,objective)
    local names={}
    for name in pairs(plan.science_packs)do names[#names+1]=name end
    table.sort(names)
    local limiting=nil
    local complete=true
    for _,name in ipairs(names)do
      local per_research_unit=plan.science_packs[name]
      tech_priests_0257_decompose_item(
        plan,name,plan.target_rate*per_research_unit,0,{},
        pair.station and pair.station.force)
      local observed,reason=tech_priests_1133_observe_science_spm(pair,name)
      plan.observed_spm_by_pack[name]=observed
      if observed==nil then
        complete=false
        plan.observed_spm_reason=reason
      else
        local completed_units_per_minute=observed/per_research_unit
        limiting=limiting and math.min(limiting,completed_units_per_minute)
          or completed_units_per_minute
      end
    end
    if complete and limiting then
      plan.observed_spm=limiting
      plan.observed_spm_reason="observed-limiting-science-basket"
      plan.observed_spm_scope="force-surface-research-basket"
    end
  else
    tech_priests_0257_decompose_item(
      plan,objective,plan.target_rate,0,{},
      pair.station and pair.station.force)
  end

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

  -- Stable order for source tests and the eventual physical component plan.
  for key in pairs(plan.factory_links)do
    plan.factory_link_order[#plan.factory_link_order+1]=key
  end
  table.sort(plan.factory_link_order)
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

-- 1142: Audit actual recipe selection on real, local production machines.
-- A bare assembler or furnace contributes ZERO to a particular recipe until
-- its real entity reports that configured recipe. This is read-only; physical
-- construction, placement, ingredient delivery and set_recipe still belong
-- to their own engine-authoritative executors.
function tech_priests_1142_observe_factory_recipe_slots(pair,plan)
  local audit={status="unobserved",needed={},configured={},missing={},
    first_missing=nil,missing_total=0,unconfigured=0}
  if not(pair and pair.station and pair.station.valid and plan
      and type(plan.recipes)=="table") then
    return audit
  end
  local station=pair.station
  local groups=TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255 or {}
  -- Furnaces are input-selected, not recipe-programmed assembling
  -- machines. Audit their physical count/production separately; treating
  -- empty get_recipe() as a missing explicit furnace recipe can cause
  -- repeated useless construction after the correct smelter is present.
  local eligible={assemblers=true,chemical=true,oil=true}
  local needed_groups={}
  for recipe_name,detail in pairs(plan.recipes) do
    if eligible[detail.group] and tonumber(detail.machines) then
      audit.needed[recipe_name]=math.max(0,math.ceil(detail.machines))
      audit.configured[recipe_name]=0
      needed_groups[detail.group]=true
    end
  end
  local group_names={}
  for name in pairs(needed_groups) do group_names[#group_names+1]=name end
  table.sort(group_names)
  local radius=refresh_pair_radius and refresh_pair_radius(pair) or 30
  local observed_all=true
  local seen={}
  for _,group in ipairs(group_names) do
    local entity_names={}
    for _,name in pairs(groups[group] or {}) do
      if tech_priests_0257_entity_valid(name) then
        entity_names[#entity_names+1]=name
      end
    end
    table.sort(entity_names)
    if #entity_names==0 then observed_all=false end
    for _,entity_name in ipairs(entity_names) do
      local ok,entities=pcall(function()
        return station.surface.find_entities_filtered({
          name=entity_name,force=station.force,
          position=station.position,radius=radius})
      end)
      if not(ok and type(entities)=="table") then
        observed_all=false
      else
        for _,entity in ipairs(entities) do
          if entity and entity.valid
              and entity.force==station.force
              and entity.surface==station.surface
              and entity.name==entity_name
              and not seen[entity.unit_number or entity] then
            seen[entity.unit_number or entity]=true
            local configured=nil
            if type(entity.get_recipe)=="function" then
              local read_ok,recipe=pcall(function()return entity.get_recipe()end)
              if read_ok and recipe then
                configured=type(recipe)=="table" and recipe.name
                  or recipe.name
              end
            end
            if configured and audit.configured[configured]~=nil then
              audit.configured[configured]=audit.configured[configured]+1
            else
              audit.unconfigured=audit.unconfigured+1
            end
          end
        end
      end
    end
  end
  local names={}
  for name in pairs(audit.needed) do names[#names+1]=name end
  table.sort(names)
  for _,name in ipairs(names) do
    local shortage=math.max(0,audit.needed[name]-audit.configured[name])
    audit.missing[name]=shortage
    audit.missing_total=audit.missing_total+shortage
    if shortage>0 and audit.first_missing==nil then
      audit.first_missing=name
    end
  end
  audit.status=observed_all and "observed-local-configurations"
    or "recipe-entity-scan-incomplete"
  return audit
end

-- 1150: Dependency-first physical CONSTRUCTION requirements for deficient
-- science intermediates. These plans carry no synthetic items or throughput.
-- The original 0338 physical builder must spend the native machine item,
-- place the real entity, then configure the untouched new assembler.
local function tech_priests_1150_recipe_execution_order(plan)
  local producers,sorted,visiting,visited={},{},{},{}
  for name,info in pairs(plan.recipes or {}) do
    if type(info.item)=="string" then producers[info.item]=name end
  end
  local function visit(name)
    if visited[name] or visiting[name] then return end
    visiting[name]=true
    for _,key in ipairs(plan.factory_link_order or {}) do
      local link=plan.factory_links[key]
      if link.consumer_recipe==name then
        local upstream=producers[link.source_item]
        if upstream then visit(upstream) end
      end
    end
    visiting[name]=nil
    visited[name]=true
    sorted[#sorted+1]=name
  end
  local names={}
  for name in pairs(plan.recipes or {}) do names[#names+1]=name end
  table.sort(names)
  for _,name in ipairs(names) do visit(name) end
  return sorted
end

local function tech_priests_1150_observe_component_output(pair,item)
  local force=pair and pair.station and pair.station.force
  local surface=pair and pair.station and pair.station.surface
  local precision=defines and defines.flow_precision_index
    and defines.flow_precision_index.one_minute
  if not(force and surface and precision
      and type(force.get_item_production_statistics)=="function") then
    return nil,"force-surface-statistics-unavailable"
  end
  local ok,stats=pcall(force.get_item_production_statistics,surface)
  if not(ok and stats and stats.valid~=false
      and type(stats.get_flow_count)=="function") then
    return nil,"force-surface-statistics-unreadable"
  end
  local read,n=pcall(stats.get_flow_count,{
    name=item,category="input",precision_index=precision})
  if not(read and type(n)=="number" and n>=0
      and n==n and n<math.huge) then
    return nil,"component-production-unobserved"
  end
  return n,"force-surface-production-per-minute"
end

function tech_priests_1150_plan_component_construction(pair,plan,audit)
  plan.factory_component_jobs_1150={}
  plan.factory_component_order_1150={}
  local first=nil
  local first_blocker=nil
  local recipe_order=tech_priests_1150_recipe_execution_order(plan)
  for _,recipe_name in ipairs(recipe_order)do
    local info=plan.recipes[recipe_name]
    local group=info and info.group
    if group=="assemblers" or group=="chemical" then
      local configured=(audit and audit.configured
        and audit.configured[recipe_name]) or 0
      local wanted=math.max(0,tonumber(info.machines) or 0)
      local missing=math.max(0,wanted-configured)
      local observed,scope=tech_priests_1150_observe_component_output(
        pair,info.item)
      local required=tonumber(info.expected_output_per_minute)or 0
      local deficient=observed==nil or observed+0.001<required
      local entity_name,item_name=nil,nil
      if missing>0 and deficient then
        local groups=TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255 or {}
        local candidates={}
        for _,name in pairs(groups[group] or {}) do
          if tech_priests_0257_entity_valid(name) then
            candidates[#candidates+1]=name
          end
        end
        table.sort(candidates)
        local target=tech_priests_get_recipe_prototype_0440
          and tech_priests_get_recipe_prototype_0440(recipe_name)
        local category=target and tech_priests_0257_recipe_category(target)
        for _,candidate in ipairs(candidates) do
          local machine=tech_priests_get_entity_prototype_0440
            and tech_priests_get_entity_prototype_0440(candidate)
          local supports=false
          -- LuaEntityPrototype.crafting_categories is a dictionary. A
          -- machine that cannot craft this exact recipe is not a candidate,
          -- even if the machine group matches (e.g. fluid recipes).
          local ok=pcall(function()
            supports=category and machine and machine.crafting_categories
              and machine.crafting_categories[category]==true
          end)
          if ok and supports==true then
            local chosen=tech_priests_0255_first_available_item
              and tech_priests_0255_first_available_item({candidate})
              or candidate
            local proto=chosen and tech_priests_get_item_prototype_0440
              and tech_priests_get_item_prototype_0440(chosen)
            local placed=proto and proto.place_result
            local placed_name=nil
            if type(placed)=="string" then placed_name=placed
            elseif placed then
              local good,name=pcall(function()return placed.name end)
              if good and type(name)=="string" then placed_name=name end
            end
            if placed_name==candidate and tech_priests_0257_item_valid(chosen)then
              item_name,entity_name=chosen,candidate
              break
            end
          end
        end
      end
      local unlocked=false
      local force=pair and pair.station and pair.station.force
      if force and force.recipes then
        local recipe=force.recipes[recipe_name]
        unlocked=recipe and recipe.enabled==true or false
      end
      local job={
        recipe=recipe_name,output_item=info.item,
        machine_group=group,machine_item=item_name,
        machine_entity=entity_name,configured=configured,
        required_machines=wanted,missing_machines=missing,
        required_per_minute=required,observed_per_minute=observed,
        observed_scope=scope,output_deficient=deficient,
        researched=unlocked,
      }
      if not deficient then job.phase="measured-output-sufficient"
      elseif missing==0 then job.phase="feed-or-connection-shortfall"
      elseif not unlocked then job.phase="recipe-locked-or-unknown"
      elseif not entity_name then job.phase="no-supported-machine-item"
      else job.phase="construct-dedicated-recipe-machine" end
      plan.factory_component_jobs_1150[recipe_name]=job
      plan.factory_component_order_1150[#plan.factory_component_order_1150+1]=recipe_name
      if not first and not first_blocker
          and job.output_deficient and job.missing_machines>0 then
        if job.phase=="construct-dedicated-recipe-machine" then
          first=job
        else
          first_blocker=job
        end
      end
    end
  end
  plan.factory_component_blocker_1150=first_blocker
  plan.factory_component_next_1150=first
  return first
end

function tech_priests_1150_issue_component_construction(pair,op,plan)
  local job=plan and plan.factory_component_next_1150
  if not(job and pair and pair.station and pair.station.valid
      and pair.priest and pair.priest.valid
      and pair.station.unit_number and job.machine_item
      and job.machine_entity and job.researched) then
    return false,"no-actionable-component-build"
  end
  local blocked=pair.factory_component_blocked_1150
  if blocked and blocked.recipe==job.recipe then
    return false,"previous-physical-build-recipe-configuration-blocked"
  end
  -- An existing 0338 task/request or independent 1011/1076 mission keeps
  -- all of its original identity, placement and item custody. Do not replace
  -- it with a science objective; return the item need to ordinary supply.
  if pair.construction_task_0338 or pair.construction_custody_0338
      or pair.remote_drill_request_1011
      or pair.robot_network_request_0338 or pair.robot_network_task_0338
      or pair.construction_bootstrap_ghost_0645
      or pair.structure_construction_requested_item
      or pair.pending_construction or pair.build_request
      or pair.construction_request then
    return false,"existing-physical-construction-owner"
  end
  local previous=pair.construction_requested_item
  if previous then
    if type(previous)=="table"
        and previous.factory_component_recipe_1150==job.recipe
        and previous.factory_component_owner_1150==
          pair.station.unit_number then
      return true,"existing-exact-component-construction-request"
    end
    return false,"existing-construction-request-preserved"
  end
  pair.construction_requested_item={
    item_name=job.machine_item,entity_name=job.machine_entity,
    category=job.machine_group=="chemical" and "chemical" or "assembler",
    source="magos-science-components-1150",
    site_reason="dedicated-science-component-production-1150",
    factory_component_recipe_1150=job.recipe,
    factory_component_item_1150=job.output_item,
    factory_component_owner_1150=pair.station.unit_number,
    factory_component_target_per_minute_1150=job.required_per_minute,
    factory_component_observed_per_minute_1150=job.observed_per_minute,
  }
  op.magos_factory_component_request_1150=job.recipe
  return true,"queued-for-real-0338-construction"
end

function tech_priests_0257_pick_ratio_need(pair, op)
  if not (pair and op) then return nil, nil, nil end
  local plan = tech_priests_0257_build_ratio_plan(pair, op)
  op.magos_ratio_plan_0257 = plan
  local recipe_audit=tech_priests_1142_observe_factory_recipe_slots(pair,plan)
  plan.factory_recipe_audit_1142=recipe_audit
  op.magos_ratio_recipe_gap_1142=recipe_audit.first_missing
  op.magos_ratio_recipe_gap_count_1142=
    recipe_audit.first_missing and recipe_audit.missing[
      recipe_audit.first_missing] or 0
  local component=tech_priests_1150_plan_component_construction(
    pair,plan,recipe_audit)
  op.magos_ratio_component_job_1150=nil
  -- Mining, smelting and electrical prerequisites must exist before a
  -- configured assembler can actually make the requested intermediate.
  local group_order = { "power", "miners", "smelters" }
  for _, group in ipairs(group_order) do
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

  if component and plan.target_spm
      and not(plan.observed_spm and plan.observed_spm>=plan.target_spm) then
    op.magos_ratio_component_job_1150=component.recipe
    op.magos_ratio_component_machine_1150=component.machine_item
    op.magos_ratio_phase_0257="factory-component-construction-needed"
    op.magos_ratio_group_0257=component.machine_group
    op.magos_ratio_have_0257=component.configured
    op.magos_ratio_desired_0257=component.required_machines
    op.magos_ratio_item_0257=component.machine_item
    return component.machine_item,
      "factory-component "..component.recipe.." configured "..
      tostring(component.configured).."/"..
      tostring(component.required_machines),plan
  end
  -- Preserve generic refinery/lab support after the recipe-specific stages.
  for _,group in ipairs({"assemblers","chemical","oil","labs"})do
    local desired=tonumber(plan.groups[group] or 0) or 0
    if desired>0 then
      local have=tech_priests_0257_count_group_entities(pair,group)
      if have<desired then
        local item_name=tech_priests_0257_first_available_item_for_group(group)
        if item_name then
          op.magos_ratio_phase_0257="ratio-"..group
          op.magos_ratio_group_0257=group
          op.magos_ratio_have_0257=have
          op.magos_ratio_desired_0257=desired
          op.magos_ratio_item_0257=item_name
          return item_name,"ratio-"..group.." "..have.."/"..desired,plan
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

  -- A safety cap is not proof that the requested SPM can be met. Likewise,
  -- enough machines by category is not proof that a science recipe is loaded,
  -- wired, supplied, powered and actually producing.
  local limited=nil
  for group,excess in pairs(plan.capacity_limited or {})do
    if excess>0 then limited=group;break end
  end
  if not plan.graph_complete_1189 then
    op.magos_ratio_phase_0257="recipe-dependency-unresolved-1189"
  elseif limited then
    op.magos_ratio_phase_0257="capacity-limited-"..limited
  elseif plan.target_spm and plan.observed_spm~=nil
      and plan.observed_spm+0.001<plan.target_spm then
    if recipe_audit.status=="observed-local-configurations"
        and recipe_audit.first_missing then
      op.magos_ratio_phase_0257="factory-recipe-configuration-missing"
    else
      op.magos_ratio_phase_0257="real-science-throughput-below-target"
    end
  elseif plan.target_spm and plan.observed_spm==nil then
    op.magos_ratio_phase_0257="science-throughput-unobserved"
  else
    op.magos_ratio_phase_0257="ratio-satisfied"
  end
  op.magos_ratio_group_0257 = nil
  op.magos_ratio_have_0257 = nil
  op.magos_ratio_desired_0257 = nil
  op.magos_ratio_item_0257 = nil
  return nil, nil, plan
end

-- 1172: independent, bounded strategic science-component pulse. The
-- legacy 0266 survival bootstrap can return before the 0255 Magos planner
-- while a survival shortage persists, even after real science production
-- has begun. The ALREADY installed 0471 strategic queue calls this pulse
-- separately; we never seize a live 0184, 0513 or 0338 physical owner,
-- clear the normal-drill obligation, enable an explicitly disabled op,
-- fabricate stock or grant technology.
-- 1176: The actual native Martian emergency Laboratorium IS a real lab
-- (a burner-powered clone of Factorio's lab), but the 0255 vanilla factory
-- expansion list correctly names only "lab". The independent science pulse
-- must recognize the physically present emergency lab without pretending a
-- vanilla lab has been constructed or accepting a remote force/surface lab.
function tech_priests_1176_has_local_research_lab(pair)
  if not(pair and pair.station and pair.station.valid
      and pair.station.surface and pair.station.force
      and pair.station.position) then return false end
  local station=pair.station
  local radius=refresh_pair_radius and refresh_pair_radius(pair) or 30
  if type(radius)~="number" or radius<=0 then return false end
  local candidates={"lab",
    TECH_PRIESTS_EMERGENCY_LAB_ENTITY_0253
      or "tech-priests-emergency-laboratorium"}
  for _,name in ipairs(candidates) do
    if tech_priests_0257_entity_valid(name) then
      local ok,found=pcall(function()
        return station.surface.find_entities_filtered{
          name=name,force=station.force,position=station.position,
          radius=radius,limit=1}
      end)
      if ok and type(found)=="table" then
        for _,entity in ipairs(found) do
          if entity and entity.valid and entity.name==name
              and entity.force==station.force
              and entity.surface==station.surface then
            local reachable,within=pcall(function()
              local pos=entity.position
              local dx=pos.x-station.position.x
              local dy=pos.y-station.position.y
              return dx*dx+dy*dy<=radius*radius
            end)
            if reachable and within then
              return true,"physical-local-laboratory:"..name
            end
          end
        end
      end
    end
  end
  return false,"no-local-laboratory"
end

function tech_priests_1172_service_autonomous_science_component(pair)
  if not(pair and pair.station and pair.station.valid
      and pair.priest and pair.priest.valid
      and tech_priests_0255_pair_is_magos_planner
      and tech_priests_0255_pair_is_magos_planner(pair)) then
    return false,"not-a-live-magos-pair"
  end
  local op=pair.independent_emergency_operation_0184
  if not(op and op.enabled==true) then
    return false,"emergency-operation-not-enabled"
  end
  if op.construction or pair.emergency_craft or pair.scavenge
      or pair.direct_acquisition_custody_0513
      or pair.construction_task_0338 or pair.construction_custody_0338 then
    return false,"incumbent-physical-duty-owned"
  end
  local central=pair.master_infrastructure_plan_0644
  if central and central.stage and central.stage~="ready"
      and central.stage~="science-ready" then
    if central.stage~="bootstrap-normal-mining" then
      return false,"unfinished-infrastructure:"..tostring(central.stage)
    end
    -- Native force/surface statistics are not sufficient alone; the Magos
    -- must also have a physically present local laboratory.
    if not tech_priests_1176_has_local_research_lab(pair) then
      return false,"no-local-laboratory"
    end
    local measured=tech_priests_1133_observe_science_spm(
      pair,"automation-science-pack")
    if type(measured)~="number" or measured<=0 then
      return false,"no-native-red-science-production"
    end
  end
  -- 1174: 0266 survival doctrine sets op.last_item to an AMMUNITION,
  -- REPAIR or OIL shortage. 0257 normally prefers last_item over science,
  -- so reusing that same operation accidentally plans survival stock as
  -- if it were science. Build a separate ephemeral science-only planning
  -- view; preserve the original active survival item, phase and next tick.
  local pack=op.science_item
  if type(pack)~="string" or not pack:find("science",1,true) then
    pack="automation-science-pack"
  end
  local science={
    science_item=pack,science_spm_target_1133=op.science_spm_target_1133,
  }
  local item,reason,plan=tech_priests_0257_pick_ratio_need(pair,science)
  -- 1178: A measured factory can be under its full target ratio for
  -- power/miners/smelters and STILL have physically working starter
  -- infrastructure. The ordinary prerequisite-first planner must keep its
  -- shortage, while the independent science pulse may schedule its FIRST
  -- missing supported recipe machine through the SAME paid 0338 builder.
  -- Never claim target capacity, grant materials, or do this on empty
  -- infrastructure / unknown science output. Existing owner guards above
  -- still take precedence.
  op.magos_ratio_prerequisite_gap_1178=nil
  local pending_group=type(reason)=="string"
    and reason:match("^ratio%-(%w+)") or nil
  if plan and item and not science.magos_ratio_component_job_1150
      and (pending_group=="power" or pending_group=="miners"
        or pending_group=="smelters")
      and plan.target_spm and plan.factory_component_next_1150 then
    local physical_starter=true
    for _,group in ipairs({"power","miners","smelters"}) do
      if tech_priests_0257_count_group_entities(pair,group)<1 then
        physical_starter=false
        break
      end
    end
    local measured=tech_priests_1133_observe_science_spm(
      pair,"automation-science-pack")
    if physical_starter
        and tech_priests_1176_has_local_research_lab(pair)
        and type(measured)=="number" and measured>0 then
      local job=plan.factory_component_next_1150
      -- plan_component_construction already proved the exact recipe is
      -- researched and has a matching item-placeable crafting machine.
      if job.researched and job.machine_item and job.machine_entity
          and job.phase=="construct-dedicated-recipe-machine" then
        op.magos_ratio_prerequisite_gap_1178=reason
        science.magos_ratio_component_job_1150=job.recipe
        science.magos_ratio_component_machine_1150=job.machine_item
        science.magos_ratio_phase_0257=
          "factory-component-prerequisite-overlap-1178"
        item=job.machine_item
      end
    end
  end
  op.magos_ratio_plan_0257=plan
  op.magos_ratio_phase_0257=science.magos_ratio_phase_0257
  op.magos_ratio_component_job_1150=science.magos_ratio_component_job_1150
  op.magos_ratio_component_machine_1150=
    science.magos_ratio_component_machine_1150
  if not(item and plan and science.magos_ratio_component_job_1150) then
    return false,reason or "no-actionable-science-component"
  end
  local placed,why=tech_priests_1150_issue_component_construction(
    pair,science,plan)
  op.magos_ratio_component_dispatch_1150=why
  if science.magos_factory_component_request_1150 then
    op.magos_factory_component_request_1150=
      science.magos_factory_component_request_1150
  end
  return placed==true,why
end

if tech_priests_0255_pick_standard_need then
  TECH_PRIESTS_ORIGINAL_PICK_STANDARD_NEED_0257 = tech_priests_0255_pick_standard_need
  function tech_priests_0255_pick_standard_need(pair, op)
    local central = pair and pair.master_infrastructure_plan_0644 or nil
    -- 1168: A native 123k run kept the Magos in "bootstrap-normal-mining"
    -- after real red-science production began. A permanent ALL-OR-NOTHING
    -- science gate blocks the very component machines needed to improve SPM.
    -- Permit COOPERATIVE science planning in that ONE unfinished stage only
    -- if a real lab exists within this Magos's authority and Factorio's own
    -- force/surface production statistics prove science was manufactured.
    -- Do not mutate 0644's drill obligation, grant stock, clear a task or
    -- replace the original 0338 construction/material owner.
    local overlap=false
    if central and central.stage=="bootstrap-normal-mining"
        and tech_priests_0255_pair_is_magos_planner
        and tech_priests_0255_pair_is_magos_planner(pair)
        and tech_priests_1176_has_local_research_lab(pair) then
      local measured=tech_priests_1133_observe_science_spm(
        pair,"automation-science-pack")
      overlap=type(measured)=="number" and measured>0
    end
    if op then
      op.magos_ratio_bootstrap_overlap_1168=
        overlap and "real-local-lab-and-native-red-science" or nil
    end
    if central and central.stage and central.stage ~= "ready"
        and central.stage ~= "science-ready" and not overlap then
      return nil, "central-martian-bootstrap:" .. tostring(central.stage)
    end
    if tech_priests_0255_pair_is_magos_planner and tech_priests_0255_pair_is_magos_planner(pair) then
      local item, reason, plan = tech_priests_0257_pick_ratio_need(pair, op)
      if item and op.magos_ratio_component_job_1150 then
        local ok,why=tech_priests_1150_issue_component_construction(
          pair,op,plan)
        op.magos_ratio_component_dispatch_1150=why
        -- A real machine item is still needed even when original physical
        -- 0338 authority currently owns another construction. The existing
        -- supply/crafting ladder is allowed to fulfill that prerequisite.
      end
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
      player.print("  objective=" .. tostring(plan.objective) ..
        " target_spm=" .. tostring(plan.target_spm or "not-science") ..
        " observed_spm=" .. tostring(plan.observed_spm or "unavailable") ..
        " scope=" .. tostring(plan.observed_spm_scope or plan.observed_spm_reason) ..
        " target_rate=" .. tostring(plan.target_rate) .. " item/s")
      player.print("  planning_state="..tostring(op.magos_ratio_phase_0257)..
        " current_research="..tostring(plan.science_technology or "none")..
        " local_recipe_gap="..tostring(op.magos_ratio_recipe_gap_1142 or "none")..
        " local_recipe_gap_count="..
          tostring(op.magos_ratio_recipe_gap_count_1142 or 0))
      for science_pack,unit_amount in pairs(plan.science_packs or {})do
        player.print("  science_budget "..science_pack..
          " items_per_research_unit="..unit_amount..
          " target_per_minute="..tostring((plan.target_spm or 0)*unit_amount)..
          " measured_per_minute="..
            tostring(plan.observed_spm_by_pack[science_pack] or "unavailable"))
      end
      player.print("  next_ratio_need=" .. tostring(item or "none") .. " reason=" .. tostring(reason or "ratio satisfied")..
        " component_request="..tostring(op.magos_factory_component_request_1150 or "none")..
        " dispatch="..tostring(op.magos_ratio_component_dispatch_1150 or "none"))
      for _,recipe_name in ipairs(plan.factory_component_order_1150 or {}) do
        local job=plan.factory_component_jobs_1150[recipe_name]
        player.print("  component "..recipe_name..
          " output_target_per_min="..tostring(job.required_per_minute)..
          " observed_per_min="..tostring(job.observed_per_minute or "unknown")..
          " configured="..job.configured.."/"..job.required_machines..
          " phase="..job.phase)
      end
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
      local recipe_count=0
      for _ in pairs(plan.recipes or {})do recipe_count=recipe_count+1 end
      for group,excess in pairs(plan.capacity_limited or {})do
        player.print("  CAPACITY_LIMITED "..group..
          " additional_machines_needed="..tostring(excess))
      end
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
