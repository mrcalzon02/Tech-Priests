-- scripts/core/resource_doctrine.lua
-- Tech Priests 0.1.325 Resource Doctrine Chain.
-- Fall-forward acquisition: if exact supply/emergency search fails, search loose
-- items, safe inventories, mineable results, dependency ingredients, rocks,
-- trees, and primitive fallback materials before idling.

local Doctrine = {}
Doctrine.version = "0.1.610"
Doctrine.storage_key = "tech_priests_resource_doctrine_0333"
Doctrine.scan_limit = 160
Doctrine.max_radius = 96
Doctrine.primitive_items = { "iron-ore", "copper-ore", "stone", "coal", "wood", "scrap", "iron-plate", "copper-plate", "iron-gear-wheel" }

local function g(name) return rawget(_G, name) end
local function callable(name) local fn = g(name); if type(fn) == "function" then return fn end; return nil end
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a, b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function area_around(pos, r) return {{pos.x-r,pos.y-r},{pos.x+r,pos.y+r}} end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function routed_scan(station, filters, category, wanted, ttl)
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  if Scan and type(Scan.find_entities) == "function" then
    local key = tostring(category or "resource") .. ":" .. safe(station.surface.index) .. ":" .. safe(station.force.index) .. ":" .. safe(station.unit_number) .. ":" .. safe(wanted or "any")
    local ents = select(1, Scan.find_entities(station.surface, filters, { category = category or "resource", negative_key = key, negative_ttl = ttl or 60 * 5 }))
    if ents then return ents end
  end
  local ok, ents = pcall(function() return station.surface.find_entities_filtered(filters) end)
  return ok and ents or nil
end

local function item_prototype(name)
  if not name then return nil end
  if prototypes then
    local ok, proto = pcall(function() return prototypes.item and prototypes.item[name] end)
    if ok and proto then return proto end
  end
  if tech_priests_get_item_prototype_0440 then
    local proto = tech_priests_get_item_prototype_0440(name)
    if proto then return proto end
  end
  return nil
end

local function item_exists(name)
  if not name then return false end
  local fn = callable("tech_priests_0312_item_exists")
  if fn then local ok, result = pcall(fn, name); if ok then return result == true end end
  return item_prototype(name) ~= nil
end

local function radius_for(pair)
  local fn = callable("refresh_pair_radius")
  if fn then local ok, r = pcall(fn, pair); if ok and tonumber(r) then return math.min(Doctrine.max_radius, math.max(12, tonumber(r))) end end
  return math.min(Doctrine.max_radius, math.max(24, tonumber(pair and pair.radius or 32)))
end

local function inventory_target_allowed(entity)
  if not valid(entity) then return false end
  -- Do not probe unsupported LuaEntity keys here. Type/prototype checks are safe.
  if entity.type == "character" or entity.type == "player" then return false end
  return true
end

local function mineable_products(entity)
  if not valid(entity) then return {} end
  local ok, mineable = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if not (ok and mineable and mineable.products) then return {} end
  local out = {}
  for _, product in pairs(mineable.products or {}) do
    local name = product.name or product[1]
    local amount = product.amount or product.amount_min or product[2] or 1
    if name and item_exists(name) and amount and amount > 0 then out[#out+1] = { name=name, amount=math.max(1, math.floor(amount)) } end
  end
  return out
end

local function entity_mines_item(entity, item)
  if not valid(entity) or not item then return nil end
  if entity.type == "resource" and entity.name == item then return { name=item, amount=1 } end
  for _, product in ipairs(mineable_products(entity)) do if product.name == item then return product end end
  return nil
end

local function is_mineable_primitive(entity)
  if not valid(entity) then return false end
  if entity.type == "tree" or entity.type == "resource" then return true end
  if entity.type == "simple-entity" or entity.type == "simple-entity-with-owner" then
    if #mineable_products(entity) > 0 then return true end
    local n = string.lower(entity.name or "")
    return string.find(n,"rock",1,true) or string.find(n,"stone",1,true) or string.find(n,"ruin",1,true)
  end
  return false
end

local function product_value(product, wanted, recipe)
  if not product then return 0 end
  if product == wanted then return 1000 end
  if recipe then
    local fn = callable("get_emergency_material_value")
    if fn then local ok, v = pcall(fn, recipe, product); if ok and tonumber(v) and tonumber(v)>0 then return tonumber(v)*10 end end
    if recipe.primary and recipe.primary[product] then return 600 end
    if recipe.substitutes and recipe.substitutes[product] then return 350 end
  end
  for i, name in ipairs(Doctrine.primitive_items) do if product == name then return 120-i end end
  return 0
end

local function best_product(entity, wanted, recipe)
  local exact = entity_mines_item(entity, wanted)
  if exact then return exact.name, exact.amount or 1, 1000 end
  local best, amount, value = nil, 1, 0
  for _, product in ipairs(mineable_products(entity)) do
    local v = product_value(product.name, wanted, recipe)
    if v > value then best, amount, value = product.name, product.amount or 1, v end
  end
  if not best and entity.type == "tree" and item_exists("wood") then best, amount, value = "wood", 1, product_value("wood", wanted, recipe) end
  return best, amount, value
end

local function get_recipe(item)
  local fn = callable("get_recipe_prototype_safe")
  if fn then local ok, recipe = pcall(fn, item); if ok and recipe then return recipe end end
  if prototypes then
    local ok, recipe = pcall(function() return prototypes.recipe and prototypes.recipe[item] end)
    if ok and recipe then return recipe end
  end
  if tech_priests_get_recipe_prototype_0440 then
    local recipe = tech_priests_get_recipe_prototype_0440(item)
    if recipe then return recipe end
  end
  return nil
end

local function ingredients_for(item)
  local recipe = get_recipe(item)
  if not recipe then return {} end
  local ok, ingredients = pcall(function() return recipe.ingredients end)
  if not (ok and ingredients) then return {} end
  local out = {}
  for _, ing in pairs(ingredients or {}) do
    local name = ing.name or ing[1]
    local amount = ing.amount or ing[2] or 1
    if name and item_exists(name) then out[#out+1] = { name=name, amount=math.max(1, math.ceil(amount or 1)) } end
  end
  return out
end

local function dependency_chain(item, depth, seen)
  local out = {}; seen = seen or {}; depth = depth or 0
  if not item or seen[item] or depth > 2 then return out end
  seen[item] = true; out[#out+1] = item
  for _, ing in ipairs(ingredients_for(item)) do for _, n in ipairs(dependency_chain(ing.name, depth+1, seen)) do out[#out+1] = n end end
  return out
end

local function status(pair, text, target)
  if not pair then return end
  pair.resource_doctrine_0325 = pair.resource_doctrine_0325 or {}
  pair.resource_doctrine_0325.last_status = text; pair.resource_doctrine_0325.last_status_tick = now(); pair.resource_doctrine_0325.last_target = target and target.valid and target.name or nil
  local draw = callable("tech_priests_draw_emergency_operation_status_0184"); if draw then pcall(draw, pair, text) end
  local scan = callable("draw_emergency_craft_scan_line"); if scan and valid(target) then pcall(scan, pair, target) end
end

function Doctrine.ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Doctrine.storage_key] = storage.tech_priests[Doctrine.storage_key] or { version=Doctrine.version, enabled=true, stats={} }
  local root = storage.tech_priests[Doctrine.storage_key]; root.version=Doctrine.version; root.stats=root.stats or {}; return root
end
function Doctrine.is_enabled() return Doctrine.ensure_root().enabled ~= false end

function Doctrine.find_loose_item(pair, item)
  if not valid_pair(pair) or not item then return nil end
  local station = pair.station; local r = radius_for(pair)
  local items = routed_scan(station, { area=area_around(station.position,r), type="item-entity", limit=Doctrine.scan_limit }, "resource", item, 60 * 4)
  if not items then return nil end
  local best, bd = nil, nil
  for _, e in pairs(items) do
    if valid(e) and e.stack and e.stack.valid_for_read and e.stack.name == item then local d=dist_sq(e.position, station.position); if not bd or d<bd then best,bd=e,d end end
  end
  if best then return { kind="ground", entity=best, output_item=item, item_name=item, value=1, station_distance_sq=bd or 0 } end
  return nil
end

function Doctrine.find_inventory_source(pair, item)
  if not valid_pair(pair) or not item then return nil end
  local station = pair.station; local r = radius_for(pair)
  local ents = routed_scan(station, { area=area_around(station.position,r), limit=Doctrine.scan_limit }, "resource", item, 60 * 4)
  if not ents then return nil end
  local inv_ids = {}; local function add(id) if id ~= nil then inv_ids[#inv_ids+1] = id end end
  add(defines.inventory.chest); add(defines.inventory.furnace_result); add(defines.inventory.assembling_machine_output); add(defines.inventory.car_trunk); add(defines.inventory.spider_trunk); add(defines.inventory.cargo_wagon); add(defines.inventory.character_corpse)
  local best = nil
  for _, ent in pairs(ents) do
    if ent ~= station and inventory_target_allowed(ent) then
      for _, inv_id in ipairs(inv_ids) do
        local ok_inv, inv = pcall(function() return ent.get_inventory(inv_id) end)
        if ok_inv and inv and inv.valid and inv.get_item_count and inv.get_item_count(item) > 0 then
          local d = dist_sq(ent.position, station.position)
          if not best or d < (best.station_distance_sq or 999999) then best = { source=ent, inventory_id=inv_id, item_name=item, count=1, kind="inventory", station_distance_sq=d } end
        end
      end
    end
  end
  return best
end

function Doctrine.find_mineable_source(pair, wanted, recipe, allow_primitive)
  if not valid_pair(pair) or not wanted then return nil end
  local station = pair.station; local r = radius_for(pair)
  local ents = routed_scan(station, { area=area_around(station.position,r), type={"resource","tree","simple-entity","simple-entity-with-owner"}, limit=Doctrine.scan_limit }, "resource", wanted, 60 * 5)
  if not ents then return nil end
  local best = nil
  for _, ent in pairs(ents) do
    if valid(ent) and is_mineable_primitive(ent) then
      local prod, amount, value = best_product(ent, wanted, recipe)
      if prod and value and value > 0 and (value >= 1000 or allow_primitive) then
        local d = dist_sq(ent.position, station.position)
        local c = { kind="direct-mine-0273", entity=ent, item_name=prod, output_item=prod, wanted_item=wanted, count=amount or 1, value=value, station_distance_sq=d, unit_number=ent.unit_number or 0 }
        if not best or c.value > best.value or (c.value == best.value and d < (best.station_distance_sq or 999999)) then best = c end
      end
    end
  end
  return best
end

function Doctrine.find_source(pair, wanted, recipe)
  local catalog_source = nil
  if _G.tech_priests_0326_find_known_source and wanted then
    local ok, found = pcall(_G.tech_priests_0326_find_known_source, pair, wanted)
    if ok then catalog_source = found end
  end
  return catalog_source or Doctrine.find_loose_item(pair, wanted) or Doctrine.find_inventory_source(pair, wanted) or Doctrine.find_mineable_source(pair, wanted, recipe, false)
end

function Doctrine.find_fallback_source(pair, wanted, recipe)
  for _, item in ipairs(dependency_chain(wanted)) do local s = Doctrine.find_source(pair, item, recipe); if s then s.wanted_item=wanted; s.dependency_item=item; return s end end
  for _, item in ipairs(Doctrine.primitive_items) do local s = Doctrine.find_source(pair, item, recipe); if s then s.wanted_item=wanted; s.dependency_item=item; s.primitive_fallback=true; return s end end
  local s = Doctrine.find_mineable_source(pair, wanted, recipe, true); if s then s.primitive_fallback=true; return s end
  return nil
end

function Doctrine.start_direct_task(pair, source, wanted, reason)
  if not (valid_pair(pair) and source) then return false end
  local item = source.output_item or source.item_name or wanted or "stone"; if not item_exists(item) then item = "stone" end
  pair.emergency_craft = pair.emergency_craft or {}
  local task = pair.emergency_craft
  task.request = task.request or { kind="resource-doctrine", item_name=wanted or item }
  task.item_name = wanted or item; task.output_item = wanted or item; task.gathered_units = task.gathered_units or 0; task.candidates = task.candidates or {}; task.index = task.index or 1
  task.current = { kind=source.kind or "direct-mine-0273", entity=source.entity, position=source.position or (source.entity and source.entity.valid and source.entity.position), item_name=item, output_item=item, wanted_item=wanted, doctrine_reason=reason or "resource-doctrine-0325" }
  task.resource_doctrine_0325 = true; task.started_tick = task.started_tick or now(); task.direct_due_tick_0315=nil; task.direct_due_tick_0312=nil; task.direct_due_tick_0273=nil
  pair.mode = source.primitive_fallback and "primitive-resource-doctrine" or "resource-doctrine-acquisition"; pair.target = source.entity or nil
  status(pair, "[item="..tostring(item).."] "..(source.primitive_fallback and "primitive fallback harvest" or "source doctrine harvest"), source.entity)
  local root=Doctrine.ensure_root(); root.stats.direct_tasks=(root.stats.direct_tasks or 0)+1
  return true
end

function Doctrine.handle_no_source(pair, wanted, recipe, reason)
  if not Doctrine.is_enabled() or not valid_pair(pair) or not wanted then return false end
  local s = Doctrine.find_fallback_source(pair, wanted, recipe)
  if not s then status(pair, "[item="..tostring(wanted).."] no source; scanning primitive doctrine", pair.station); return false end
  if s.source then pair.scavenge=s; pair.mode="scavenging"; pair.target=s.source; status(pair, "[item="..tostring(s.item_name or wanted).."] inventory source found", s.source); local root=Doctrine.ensure_root(); root.stats.inventory_sources=(root.stats.inventory_sources or 0)+1; return true end
  return Doctrine.start_direct_task(pair, s, wanted, reason)
end

function Doctrine.wrap_find_scavenge_source()
  local prev = rawget(_G,"find_scavenge_source_for_request"); if type(prev)~="function" or rawget(_G,"TECH_PRIESTS_0325_PRE_FIND_SCAVENGE_SOURCE") then return end
  _G.TECH_PRIESTS_0325_PRE_FIND_SCAVENGE_SOURCE = prev
  _G.find_scavenge_source_for_request = function(pair, request)
    local result = _G.TECH_PRIESTS_0325_PRE_FIND_SCAVENGE_SOURCE(pair, request); if result then return result end
    if not Doctrine.is_enabled() then return nil end
    local wanted = request and (request.item_name or request.name or request.item or request.kind); if wanted == "repair" then wanted="repair-pack" end
    if not item_exists(wanted) then return nil end
    return Doctrine.find_inventory_source(pair, wanted)
  end
end

function Doctrine.wrap_maybe_start_supply_scavenge()
  local prev = rawget(_G,"maybe_start_supply_scavenge"); if type(prev)~="function" or rawget(_G,"TECH_PRIESTS_0325_PRE_MAYBE_START_SUPPLY_SCAVENGE") then return end
  _G.TECH_PRIESTS_0325_PRE_MAYBE_START_SUPPLY_SCAVENGE = prev
  _G.maybe_start_supply_scavenge = function(pair, kind, target)
    local ok, result = pcall(_G.TECH_PRIESTS_0325_PRE_MAYBE_START_SUPPLY_SCAVENGE, pair, kind, target); if ok and result then return result end
    if not Doctrine.is_enabled() then return ok and result or false end
    local wanted = pair and pair.active_supply_request and (pair.active_supply_request.item_name or pair.active_supply_request.name or pair.active_supply_request.kind) or kind
    if wanted == "repair" then wanted="repair-pack" end
    if not item_exists(wanted) then return ok and result or false end
    return Doctrine.handle_no_source(pair, wanted, nil, "supply-scavenge-no-source") or (ok and result or false)
  end
end

function Doctrine.wrap_emergency_acquire()
  local prev = rawget(_G,"tech_priests_emergency_operation_acquire_item_0185"); if type(prev)~="function" or rawget(_G,"TECH_PRIESTS_0325_PRE_EMERGENCY_ACQUIRE") then return end
  _G.TECH_PRIESTS_0325_PRE_EMERGENCY_ACQUIRE = prev
  _G.tech_priests_emergency_operation_acquire_item_0185 = function(pair, item_name, op, count, depth)
    local ok, result = pcall(_G.TECH_PRIESTS_0325_PRE_EMERGENCY_ACQUIRE, pair, item_name, op, count, depth); if ok and result then return result end
    if not Doctrine.is_enabled() or not item_exists(item_name) then return ok and result or false end
    local recipe = nil; local maker = callable("tech_priests_make_recipe_aware_emergency_recipe_0184"); if maker then local okr, made = pcall(maker, item_name); if okr then recipe = made end end
    return Doctrine.handle_no_source(pair, item_name, recipe, "emergency-acquire-no-source") or (ok and result or false)
  end
end

function Doctrine.wrap_build_candidates()
  local prev = rawget(_G,"build_emergency_craft_candidates"); if type(prev)~="function" or rawget(_G,"TECH_PRIESTS_0325_PRE_BUILD_EMERGENCY_CANDIDATES") then return end
  _G.TECH_PRIESTS_0325_PRE_BUILD_EMERGENCY_CANDIDATES = prev
  _G.build_emergency_craft_candidates = function(pair, recipe)
    local candidates = _G.TECH_PRIESTS_0325_PRE_BUILD_EMERGENCY_CANDIDATES(pair, recipe) or {}
    if not Doctrine.is_enabled() or not valid_pair(pair) then return candidates end
    for _, item in ipairs(dependency_chain(recipe and recipe.output or recipe and recipe.item_name or nil)) do local src=Doctrine.find_mineable_source(pair,item,recipe,true); if src then src.resource_doctrine_0325=true; candidates[#candidates+1]=src end end
    table.sort(candidates, function(a,b) local av=tonumber(a.value or 0) or 0; local bv=tonumber(b.value or 0) or 0; if av~=bv then return av>bv end; return (a.station_distance_sq or 999999)<(b.station_distance_sq or 999999) end)
    return candidates
  end
end

function Doctrine.wrap_handle_emergency_craft()
  local prev = rawget(_G,"handle_emergency_desperation_craft"); if type(prev)~="function" or rawget(_G,"TECH_PRIESTS_0325_PRE_HANDLE_EMERGENCY_CRAFT") then return end
  _G.TECH_PRIESTS_0325_PRE_HANDLE_EMERGENCY_CRAFT = prev
  _G.handle_emergency_desperation_craft = function(pair)
    local task = pair and pair.emergency_craft or nil
    if Doctrine.is_enabled() and valid_pair(pair) and task and not task.current then
      local wanted = task.item_name or task.output_item or (task.request and (task.request.item_name or task.request.name))
      local src = Doctrine.find_fallback_source(pair, wanted, task.recipe); if src and not src.source then Doctrine.start_direct_task(pair, src, wanted, "empty-emergency-current") end
    end
    return _G.TECH_PRIESTS_0325_PRE_HANDLE_EMERGENCY_CRAFT(pair)
  end
end

function Doctrine.install()
  Doctrine.ensure_root(); Doctrine.wrap_find_scavenge_source(); Doctrine.wrap_maybe_start_supply_scavenge(); Doctrine.wrap_emergency_acquire(); Doctrine.wrap_build_candidates(); Doctrine.wrap_handle_emergency_craft()
  if commands and commands.add_command then pcall(function() commands.add_command("tp-resource-doctrine-0325", "Tech Priests: inspect/toggle source doctrine chain. Usage: /tp-resource-doctrine-0325 status|enable|disable", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil; local param=tostring(event and event.parameter or "status"); local root=Doctrine.ensure_root(); if param=="enable" then root.enabled=true elseif param=="disable" then root.enabled=false end
    if player and player.valid then local pair=nil; if selected_pair_for_player then local ok,found=pcall(selected_pair_for_player,player); if ok then pair=found end end; local st=pair and pair.resource_doctrine_0325 or nil; player.print("[Tech Priests 0.1.333] resource doctrine="..tostring(root.enabled).." direct="..tostring(root.stats.direct_tasks or 0).." inventory="..tostring(root.stats.inventory_sources or 0).." last="..tostring(st and st.last_status or "none")) end
  end) end) end
  if log then log("[Tech-Priests 0.1.333] resource doctrine fall-forward acquisition chain loaded with Factorio 2.0 prototype guards") end
  return true
end

return Doctrine
