-- scripts/core/arterial_planner.lua
-- Tech Priests 0.1.360 arterial factory planning scaffold.
--
-- Purpose:
--   Give Planetary Magos / senior station chains a conservative ghost-planning
--   surface for science-pack production without hijacking existing construction,
--   acquisition, or emergency-facility behavior yet.
--
-- First-pass scope:
--   * Build a recipe dependency outline for a requested product.
--   * Estimate a minimum viable number of machines by recipe node.
--   * Use station + subordinate-station operating space as the planning area.
--   * Place a tiny starter arterial ghost marker set: one final assembler-like
--     machine, one belt, and one pole, using a top-center / left-biased spiral.
--   * Prefer Martian micro machinery for dry primitive steps when available.
--   * Prefer definitive base fluid machinery for fluid recipes.
--   * Do not route full belts, pipes, rails, roboports, or drones yet.
--
-- This module is intentionally planning-only.  It is the beginning of the
-- arterial planner, not the final factory generator.

local A = {}
A.version = "0.1.360"
A.storage_key = "arterial_planner_0360"
A.default_product = "automation-science-pack"
A.max_recipe_depth = 5
A.max_nodes = 80
A.default_search_radius = 48
A.ghost_ttl = 60 * 60 * 10

local function valid(e) return e and e.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function pos_key(pos) return string.format("%.1f,%.1f", pos.x or 0, pos.y or 0) end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function round2(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) / 100 end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[A.storage_key] = storage.tech_priests[A.storage_key] or {
    version = A.version,
    enabled = true,
    debug = true,
    plans = {},
    stats = { planned = 0, ghosts = 0, failed = 0 }
  }
  local root = storage.tech_priests[A.storage_key]
  root.version = A.version
  root.plans = root.plans or {}
  root.stats = root.stats or { planned = 0, ghosts = 0, failed = 0 }
  if root.enabled == nil then root.enabled = true end
  return root
end

local function proto_recipe(name)
  if not (name and prototypes and prototypes.recipe) then return nil end
  local ok, p = pcall(function() return prototypes.recipe[name] end)
  if ok then return p end
  return nil
end

local function proto_item(name)
  if not (name and prototypes and prototypes.item) then return nil end
  local ok, p = pcall(function() return prototypes.item[name] end)
  if ok then return p end
  return nil
end

local function proto_entity(name)
  if not (name and prototypes and prototypes.entity) then return nil end
  local ok, p = pcall(function() return prototypes.entity[name] end)
  if ok then return p end
  return nil
end

local function recipe_category(recipe)
  if not recipe then return "crafting" end
  local ok, cat = pcall(function() return recipe.category end)
  if ok and cat then return cat end
  return "crafting"
end

local function recipe_energy(recipe)
  if not recipe then return 1 end
  local ok, e = pcall(function() return recipe.energy end)
  if ok and tonumber(e) then return tonumber(e) end
  local ok2, e2 = pcall(function() return recipe.energy_required end)
  if ok2 and tonumber(e2) then return tonumber(e2) end
  return 1
end

local function recipe_products(recipe)
  if not recipe then return {} end
  local ok, products = pcall(function() return recipe.products end)
  if ok and products then return products end
  local ok2, main = pcall(function() return recipe.main_product end)
  if ok2 and main then return {{type="item", name=main, amount=1}} end
  return {}
end

local function recipe_ingredients(recipe)
  if not recipe then return {} end
  local ok, ingredients = pcall(function() return recipe.ingredients end)
  if ok and ingredients then return ingredients end
  return {}
end

local function product_name(prod)
  if type(prod) ~= "table" then return nil end
  return prod.name or prod[1]
end

local function product_amount(prod)
  if type(prod) ~= "table" then return 1 end
  return tonumber(prod.amount or prod.amount_min or prod[2]) or 1
end

local function ingredient_name(ing)
  if type(ing) ~= "table" then return nil end
  return ing.name or ing[1]
end

local function ingredient_amount(ing)
  if type(ing) ~= "table" then return 1 end
  return tonumber(ing.amount or ing[2]) or 1
end

local function ingredient_type(ing)
  if type(ing) ~= "table" then return "item" end
  return ing.type or "item"
end

local function recipe_yields_item(recipe, item_name)
  for _, prod in pairs(recipe_products(recipe)) do
    if product_name(prod) == item_name then return product_amount(prod) end
  end
  return nil
end

local function recipe_enabled(recipe)
  if not recipe then return false end
  local ok, enabled = pcall(function() return recipe.enabled end)
  if ok and enabled ~= nil then return enabled end
  return true
end

local function find_recipe_for_item(item_name, force)
  if not item_name then return nil end
  -- Prefer an explicitly unlocked force recipe if available.
  if force and force.valid and force.recipes then
    local ok, recipes = pcall(function() return force.recipes end)
    if ok and recipes then
      for _, recipe in pairs(recipes) do
        local ok_enabled, enabled = pcall(function() return recipe.enabled end)
        if ok_enabled and enabled and recipe_yields_item(recipe, item_name) then return recipe end
      end
    end
  end
  if prototypes and prototypes.recipe then
    for _, recipe in pairs(prototypes.recipe) do
      if recipe_yields_item(recipe, item_name) and recipe_enabled(recipe) then return recipe end
    end
    for _, recipe in pairs(prototypes.recipe) do
      if recipe_yields_item(recipe, item_name) then return recipe end
    end
  end
  return nil
end

local function item_place_result(item_name)
  local ip = proto_item(item_name)
  if not ip then return nil end
  local ok, result = pcall(function() return ip.place_result end)
  if ok then
    if type(result) == "string" then return result end
    if type(result) == "table" and result.name then return result.name end
  end
  return nil
end

local function entity_exists(name) return proto_entity(name) ~= nil end

local function choose_machine_for_category(category, contains_fluid)
  category = category or "crafting"
  if category == "smelting" or category == "tech-priests-emergency-smelting" then
    if entity_exists("tech-priests-emergency-smelter") then return "tech-priests-emergency-smelter", "martian-micro-smelter" end
    return "stone-furnace", "furnace" end
  if contains_fluid or category == "chemistry" or category == "oil-processing" or category == "fluid-filtration" then
    if category == "oil-processing" and entity_exists("oil-refinery") then return "oil-refinery", "definitive-fluid-refinery" end
    if entity_exists("chemical-plant") then return "chemical-plant", "definitive-fluid-chemical-plant" end
  end
  if category == "crafting" or category == "basic-crafting" or category == "advanced-crafting" then
    if entity_exists("tech-priests-emergency-micro-assembler") then return "tech-priests-emergency-micro-assembler", "martian-micro-assembler" end
    if entity_exists("assembling-machine-1") then return "assembling-machine-1", "base-assembler" end
  end
  if entity_exists("assembling-machine-1") then return "assembling-machine-1", "generic-assembler" end
  return nil, "no-machine"
end

local function recipe_contains_fluid(recipe)
  for _, ing in pairs(recipe_ingredients(recipe)) do if ingredient_type(ing) == "fluid" then return true end end
  for _, prod in pairs(recipe_products(recipe)) do if prod.type == "fluid" then return true end end
  return false
end

local function station_rank(pair)
  if pair and pair.rank then return tonumber(pair.rank) or 1 end
  local name = valid(pair and pair.station) and pair.station.name or ""
  if name:find("planetary%-magos") then return 4 end
  if name:find("senior") then return 3 end
  if name:find("intermediate") then return 2 end
  return 1
end

local function operating_radius(pair)
  local r = A.default_search_radius
  if _G.get_station_operating_radius and valid(pair and pair.station) then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  return r
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok and pair then return pair end end
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) and (pair.station == selected or (valid(pair.priest) and pair.priest == selected)) then return pair end
  end
  return nil
end

local function subordinate_pairs(pair)
  local out = {}
  if not valid(pair and pair.station) then return out end
  local radius = operating_radius(pair)
  local rank = station_rank(pair)
  for _, other in pairs(pair_map()) do
    if other ~= pair and valid(other and other.station) and other.station.surface == pair.station.surface and other.station.force == pair.station.force then
      if station_rank(other) < rank and dist_sq(other.station.position, pair.station.position) <= radius * radius then
        out[#out+1] = other
      end
    end
  end
  table.sort(out, function(a,b) return dist_sq(a.station.position, pair.station.position) < dist_sq(b.station.position, pair.station.position) end)
  return out
end

local function planning_anchor_points(pair)
  local anchors = {}
  if valid(pair and pair.station) then anchors[#anchors+1] = { pair = pair, entity = pair.station, radius = operating_radius(pair), role = "primary" } end
  for _, sub in ipairs(subordinate_pairs(pair)) do anchors[#anchors+1] = { pair = sub, entity = sub.station, radius = operating_radius(sub), role = "subordinate" } end
  return anchors
end

local function is_position_in_planning_area(pair, pos)
  for _, anchor in ipairs(planning_anchor_points(pair)) do
    if valid(anchor.entity) and dist_sq(anchor.entity.position, pos) <= (anchor.radius * anchor.radius) then return true, anchor end
  end
  return false, nil
end

local function build_recipe_tree(pair, item_name, amount, depth, seen, plan)
  if not item_name or #plan.nodes >= A.max_nodes then return nil end
  depth = depth or 0
  amount = tonumber(amount) or 1
  seen = seen or {}
  if seen[item_name] and depth > 0 then return nil end
  if depth > A.max_recipe_depth then return nil end
  seen[item_name] = true

  local recipe = find_recipe_for_item(item_name, valid(pair and pair.station) and pair.station.force or nil)
  if not recipe then
    local leaf = { kind = "raw", item = item_name, amount = amount, depth = depth, machine = nil, category = "raw", reason = "no-known-recipe" }
    plan.nodes[#plan.nodes+1] = leaf
    return leaf
  end

  local out_amt = recipe_yields_item(recipe, item_name) or 1
  local cycles = math.max(1, math.ceil(amount / math.max(0.001, out_amt)))
  local cat = recipe_category(recipe)
  local has_fluid = recipe_contains_fluid(recipe)
  local machine, machine_reason = choose_machine_for_category(cat, has_fluid)
  local energy = recipe_energy(recipe)
  local machines = math.max(1, math.ceil((cycles * energy) / 30)) -- minimum viable, roughly one half-minute target.
  local node = {
    kind = "recipe",
    item = item_name,
    amount = amount,
    recipe = recipe.name,
    cycles = cycles,
    depth = depth,
    category = cat,
    contains_fluid = has_fluid,
    machine = machine,
    machine_reason = machine_reason,
    machines = machines,
    ingredients = {}
  }
  plan.nodes[#plan.nodes+1] = node
  for _, ing in pairs(recipe_ingredients(recipe)) do
    local iname = ingredient_name(ing)
    local iamt = ingredient_amount(ing) * cycles
    node.ingredients[#node.ingredients+1] = { name = iname, type = ingredient_type(ing), amount = iamt }
    if ingredient_type(ing) ~= "fluid" then build_recipe_tree(pair, iname, iamt, depth + 1, table.deepcopy(seen), plan) end
  end
  return node
end

function A.make_plan(pair, product, amount)
  if not (pair and valid(pair.station)) then return nil, "invalid-pair" end
  product = product or A.default_product
  amount = tonumber(amount) or 1
  local root = ensure_root()
  local plan = {
    version = A.version,
    tick = game.tick,
    owner_station_unit = pair.station.unit_number,
    owner_station_name = pair.station.backer_name or pair.station.name,
    product = product,
    amount = amount,
    station_rank = station_rank(pair),
    anchors = {},
    nodes = {},
    transit_preference = { "rail", "transport-drones", "roboport", "belt" },
    junior_roles = { "storage", "acquisition", "drone-control", "transportation", "construction" },
    warnings = {}
  }
  for _, anchor in ipairs(planning_anchor_points(pair)) do
    plan.anchors[#plan.anchors+1] = {
      unit = anchor.entity.unit_number,
      name = anchor.entity.backer_name or anchor.entity.name,
      role = anchor.role,
      radius = anchor.radius,
      x = round2(anchor.entity.position.x),
      y = round2(anchor.entity.position.y)
    }
  end
  build_recipe_tree(pair, product, amount, 0, {}, plan)
  if #plan.nodes == 0 then plan.warnings[#plan.warnings+1] = "no recipe tree was found" end
  root.plans[pair.station.unit_number] = plan
  root.stats.planned = (root.stats.planned or 0) + 1
  return plan, nil
end

local function spiral_candidates(center, max_radius)
  local list = {}
  for r = 2, max_radius or 32 do
    -- top/north band first, left-biased, then the rest of the ring.
    for dx = 0, -r, -1 do list[#list+1] = {x = center.x + dx, y = center.y - r} end
    for dx = 1, r do list[#list+1] = {x = center.x + dx, y = center.y - r} end
    for dy = -r + 1, r do list[#list+1] = {x = center.x - r, y = center.y + dy} end
    for dy = -r + 1, r do list[#list+1] = {x = center.x + r, y = center.y + dy} end
    for dx = -r + 1, r - 1 do list[#list+1] = {x = center.x + dx, y = center.y + r} end
  end
  return list
end

local function can_place(surface, force, entity_name, position)
  if not (surface and entity_name and position) then return false end
  local ok, result = pcall(function()
    return surface.can_place_entity{ name = entity_name, position = position, force = force, build_check_type = defines.build_check_type.ghost_revive }
  end)
  if ok then return result end
  local ok2, result2 = pcall(function() return surface.can_place_entity{ name = entity_name, position = position, force = force } end)
  return ok2 and result2 or false
end

local function find_site(pair, entity_name, occupied)
  if not (valid(pair and pair.station) and entity_name) then return nil end
  local surface = pair.station.surface
  local force = pair.station.force
  occupied = occupied or {}
  for _, anchor in ipairs(planning_anchor_points(pair)) do
    local candidates = spiral_candidates(anchor.entity.position, math.min(anchor.radius or 32, 48))
    for _, pos in ipairs(candidates) do
      local key = pos_key(pos)
      if not occupied[key] then
        local in_area = is_position_in_planning_area(pair, pos)
        if in_area and can_place(surface, force, entity_name, pos) then
          occupied[key] = true
          return pos, anchor
        end
      end
    end
  end
  return nil
end

local function create_ghost(surface, force, entity_name, position, direction)
  if not (surface and entity_name and position) then return nil, "bad-ghost-args" end
  local ok, ghost = pcall(function()
    return surface.create_entity{
      name = "entity-ghost",
      inner_name = entity_name,
      position = position,
      force = force,
      direction = direction or defines.direction.north,
      expires = true
    }
  end)
  if ok and ghost then
    pcall(function() ghost.time_to_live = A.ghost_ttl end)
    return ghost, nil
  end
  return nil, "create-ghost-failed"
end

function A.place_plan_ghosts(pair, plan)
  if not (pair and valid(pair.station)) then return false, "invalid-pair" end
  plan = plan or (ensure_root().plans[pair.station.unit_number]) or A.make_plan(pair, A.default_product, 1)
  if not plan then return false, "no-plan" end
  local root = ensure_root()
  local surface = pair.station.surface
  local force = pair.station.force
  local occupied = {}
  local placed = {}
  local final_node = nil
  for _, node in ipairs(plan.nodes or {}) do
    if node.kind == "recipe" and node.depth == 0 then final_node = node break end
  end
  final_node = final_node or plan.nodes[1]
  local machine_name = final_node and final_node.machine or "assembling-machine-1"
  if machine_name and entity_exists(machine_name) then
    local site, anchor = find_site(pair, machine_name, occupied)
    if site then
      local ghost = create_ghost(surface, force, machine_name, site, defines.direction.south)
      if ghost then placed[#placed+1] = { kind = "machine", name = machine_name, x = site.x, y = site.y, anchor = anchor and anchor.role or "primary" } end
    end
  end
  -- Starter arterial belt segment.  Full routing is deliberately deferred.
  if entity_exists("transport-belt") then
    local belt_site, anchor = find_site(pair, "transport-belt", occupied)
    if belt_site then
      local ghost = create_ghost(surface, force, "transport-belt", belt_site, defines.direction.east)
      if ghost then placed[#placed+1] = { kind = "belt", name = "transport-belt", x = belt_site.x, y = belt_site.y, anchor = anchor and anchor.role or "primary" } end
    end
  end
  -- Starter pole.  Prefer emergency grid if available, otherwise base small pole.
  local pole = entity_exists("tech-priests-emergency-power-grid") and "tech-priests-emergency-power-grid" or (entity_exists("small-electric-pole") and "small-electric-pole" or nil)
  if pole then
    local pole_site, anchor = find_site(pair, pole, occupied)
    if pole_site then
      local ghost = create_ghost(surface, force, pole, pole_site, defines.direction.north)
      if ghost then placed[#placed+1] = { kind = "pole", name = pole, x = pole_site.x, y = pole_site.y, anchor = anchor and anchor.role or "primary" } end
    end
  end
  plan.ghosts = placed
  plan.last_ghost_tick = game.tick
  root.stats.ghosts = (root.stats.ghosts or 0) + #placed
  if #placed == 0 then root.stats.failed = (root.stats.failed or 0) + 1; return false, "no-ghost-sites" end
  return true, placed
end

local function describe_plan(plan)
  local lines = {}
  if not plan then return {"no plan"} end
  lines[#lines+1] = string.format("product=%s x%s station=%s rank=%s anchors=%d nodes=%d", tostring(plan.product), tostring(plan.amount), tostring(plan.owner_station_name), tostring(plan.station_rank), #(plan.anchors or {}), #(plan.nodes or {}))
  lines[#lines+1] = "transit preference: rail > transport drones > roboports > belts"
  if plan.anchors then
    local bits = {}
    for _, a in ipairs(plan.anchors) do bits[#bits+1] = string.format("%s:%s r%s", a.role, a.name, tostring(a.radius)) end
    lines[#lines+1] = "planning anchors: " .. table.concat(bits, "; ")
  end
  for i, node in ipairs(plan.nodes or {}) do
    if i > 18 then lines[#lines+1] = "... additional recipe nodes omitted from chat output" break end
    local indent = string.rep("  ", math.min(4, node.depth or 0))
    if node.kind == "recipe" then
      lines[#lines+1] = string.format("%s%s via %s: %s machine=%s count=%s", indent, tostring(node.item), tostring(node.recipe), tostring(node.category), tostring(node.machine or "none"), tostring(node.machines or 1))
    else
      lines[#lines+1] = string.format("%s%s raw/source amount=%s reason=%s", indent, tostring(node.item), tostring(node.amount), tostring(node.reason))
    end
  end
  if plan.ghosts and #plan.ghosts > 0 then
    local bits = {}
    for _, g in ipairs(plan.ghosts) do bits[#bits+1] = string.format("%s:%s@%.1f,%.1f", g.kind, g.name, g.x, g.y) end
    lines[#lines+1] = "ghosts: " .. table.concat(bits, "; ")
  end
  return lines
end

function A.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-arterial-0360") end)
  commands.add_command("tp-arterial-0360", "Tech Priests 0.1.360 arterial science/factory planner: status|plan <item>|ghost <item>|clear", function(event)
    local player = game.players[event.player_index]
    if not player then return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-arterial-0360] select a Cogitator Station or Tech-Priest."); return end
    local arg = tostring(event.parameter or "status")
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd or "status"
    rest = (rest and rest ~= "") and rest or A.default_product
    local root = ensure_root()
    if cmd == "enable" then root.enabled = true; player.print("[tp-arterial-0360] enabled") return end
    if cmd == "disable" then root.enabled = false; player.print("[tp-arterial-0360] disabled") return end
    if cmd == "clear" then root.plans[pair.station.unit_number] = nil; player.print("[tp-arterial-0360] cleared station plan") return end
    local plan = root.plans[pair.station.unit_number]
    if cmd == "plan" then
      plan = A.make_plan(pair, rest, 1)
      player.print("[tp-arterial-0360] planned " .. tostring(rest))
    elseif cmd == "ghost" then
      plan = A.make_plan(pair, rest, 1)
      local ok, result = A.place_plan_ghosts(pair, plan)
      player.print("[tp-arterial-0360] ghost=" .. tostring(ok) .. " result=" .. tostring(type(result) == "table" and #result or result))
    elseif not plan then
      plan = A.make_plan(pair, A.default_product, 1)
    end
    for _, line in ipairs(describe_plan(plan)) do player.print("[tp-arterial-0360] " .. line) end
  end)
end

function A.install()
  ensure_root()
  A.install_commands()
  _G.TECH_PRIESTS_ARTERIAL_PLANNER_0360 = A
  _G.tech_priests_0360_make_arterial_plan = A.make_plan
  _G.tech_priests_0360_place_arterial_ghosts = A.place_plan_ghosts
  if log then log("[Tech-Priests 0.1.360] arterial science/factory ghost-planning scaffold loaded") end
  return true
end

return A
