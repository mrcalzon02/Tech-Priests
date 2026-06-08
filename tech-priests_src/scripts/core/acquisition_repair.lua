-- scripts/core/acquisition_repair.lua
-- Tech Priests 0.1.333 emergency acquisition repair.
-- The 0.1.332 logs showed assigned survival-ammo/emergency cascade tasks idling
-- because a legacy survival acquire path still touched game.item_prototypes in
-- Factorio 2.0. This module provides safe prototype helpers and a late fallback
-- that forces assigned ammo/resource requests back into direct gather/mining.

local Repair = {}
Repair.version = "0.1.337"
Repair.storage_key = "acquisition_repair_0337"
Repair.scan_limit = 192
Repair.max_radius = 96
Repair.primitive_items = { "iron-ore", "coal", "stone", "wood", "copper-ore", "iron-plate", "copper-plate" }

local function valid(e) return e and e.valid end
local function pairs_by_station() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function area(pos,r) return {{pos.x-r,pos.y-r},{pos.x+r,pos.y+r}} end
local function now() return game and game.tick or 0 end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Repair.storage_key] = storage.tech_priests[Repair.storage_key] or { version = Repair.version, enabled = true, stats = {} }
  local root = storage.tech_priests[Repair.storage_key]
  root.version = Repair.version
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function item_proto(name)
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

local function item_exists(name) return item_proto(name) ~= nil end

local function recipe_proto(name)
  if not name then return nil end
  if prototypes then
    local ok, proto = pcall(function() return prototypes.recipe and prototypes.recipe[name] end)
    if ok and proto then return proto end
  end
  if tech_priests_get_recipe_prototype_0440 then
    local proto = tech_priests_get_recipe_prototype_0440(name)
    if proto then return proto end
  end
  return nil
end

local function wanted_from_pair(pair)
  local op = pair and pair.independent_emergency_operation_0184
  if op and op.acquisition and op.acquisition.item_name then return op.acquisition.item_name end
  local task = pair and pair.emergency_craft
  if task then return task.item_name or task.output_item or (task.request and (task.request.item_name or task.request.name or task.request.item)) end
  local req = pair and (pair.active_supply_request or pair.supply_request)
  if req then return req.item_name or req.name or req.item or req.kind end
  return pair and (pair.logistic_requested_item or pair.last_requested_supply_item_0173 or pair.last_resource_doctrine_item) or nil
end

local function normalize_item(name, context)
  if not name then return nil end
  name = tostring(name)
  if name == "ammo" or name == "ammunition" or name == "magazine" then return "firearm-magazine" end
  if name == "repair" or name == "repairs" then return "repair-pack" end
  if name:find("^virtual%-signal") then
    if context == "ammo" then return "firearm-magazine" end
    return nil
  end
  if item_exists(name) then return name end
  return nil
end

local function radius_for(pair)
  local r = tonumber(pair and pair.radius) or nil
  if _G.refresh_pair_radius then local ok, rr = pcall(_G.refresh_pair_radius, pair); if ok and tonumber(rr) then r = tonumber(rr) end end
  if not r and _G.get_station_operating_radius and pair and pair.station and pair.station.valid then local ok, rr = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(rr) then r = tonumber(rr) end end
  return math.max(12, math.min(Repair.max_radius, tonumber(r) or 32))
end

local function mineable_products(entity)
  if not valid(entity) then return {} end
  if entity.type == "resource" and item_exists(entity.name) then return { { name = entity.name, amount = 1 } } end
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if not (ok and props and props.products) then
    if entity.type == "tree" and item_exists("wood") then return { { name = "wood", amount = 1 } } end
    return {}
  end
  local out = {}
  for _, product in pairs(props.products or {}) do
    local name = product.name or product[1]
    if name and item_exists(name) then out[#out + 1] = { name = name, amount = product.amount or product.amount_min or product[2] or 1 } end
  end
  if #out == 0 and entity.type == "tree" and item_exists("wood") then out[#out + 1] = { name = "wood", amount = 1 } end
  return out
end

local function recipe_ingredients(item)
  local recipe = recipe_proto(item)
  if not recipe then return {} end
  local ok, ingredients = pcall(function() return recipe.ingredients end)
  if not (ok and ingredients) then return {} end
  local out = {}
  for _, ing in pairs(ingredients) do
    local name = ing.name or ing[1]
    if name and item_exists(name) then out[#out + 1] = name end
  end
  return out
end

local function useful_items_for(wanted)
  local out, seen = {}, {}
  local function add(name)
    name = normalize_item(name)
    if name and not seen[name] then seen[name] = true; out[#out + 1] = name end
  end
  add(wanted)
  for _, ing in ipairs(recipe_ingredients(wanted)) do
    add(ing)
    for _, ing2 in ipairs(recipe_ingredients(ing)) do add(ing2) end
  end
  for _, p in ipairs(Repair.primitive_items) do add(p) end
  return out
end

local function find_mineable(pair, wanted)
  if not valid_pair(pair) then return nil end
  local wants = useful_items_for(wanted)
  local wanted_rank = {}; for i, item in ipairs(wants) do wanted_rank[item] = #wants - i + 1 end
  local r = radius_for(pair)
  local ok, ents = pcall(function()
    return pair.station.surface.find_entities_filtered({ area = area(pair.station.position, r), type = { "resource", "tree", "simple-entity", "simple-entity-with-owner" }, limit = Repair.scan_limit })
  end)
  if not (ok and ents) then return nil end
  local best, best_score = nil, -1
  for _, ent in pairs(ents) do
    if valid(ent) then
      for _, prod in pairs(mineable_products(ent)) do
        local rank = wanted_rank[prod.name]
        if rank then
          local d = dist_sq(pair.station.position, ent.position)
          local score = rank * 100000 - d
          if score > best_score then
            best_score = score
            best = { entity = ent, item = prod.name, wanted = wanted, distance_sq = d }
          end
        end
      end
    end
  end
  return best
end

local function show(pair, text, target)
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  if _G.draw_emergency_craft_scan_line and target and target.valid then pcall(_G.draw_emergency_craft_scan_line, pair, target) end
end

function Repair.force_direct_gather(pair, wanted, reason)
  local root = ensure_root()
  if root.enabled == false or not valid_pair(pair) then return false end
  wanted = normalize_item(wanted, "ammo") or "firearm-magazine"

  -- 0.1.414 movement hammer: do not let overlapping acquisition repair/unstick
  -- pulses overwrite a live ground gather target every few seconds.  That old
  -- retarget churn looked like the Tech-Priest was jumping tree-to-tree even
  -- when the actual command system was only being spammed with new targets.
  local task = pair.emergency_craft
  local cur = task and task.current or nil
  if cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273" or cur.kind == "direct-mine-0336") and cur.entity and cur.entity.valid then
    local is_space = false
    if _G.tech_priests_pair_on_space_platform_0204 then
      local ok_space, result_space = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
      is_space = ok_space and result_space or false
    end
    if not is_space then
      pair.direct_target_lease_0414 = pair.direct_target_lease_0414 or { tick = now(), wanted = wanted }
      if (now() - (pair.direct_target_lease_0414.tick or now())) < 360 then
        root.stats.preserved_current_target_0414 = (root.stats.preserved_current_target_0414 or 0) + 1
        show(pair, "[item=" .. tostring(cur.output_item or cur.item_name or wanted) .. "] holding current gather target; retarget suppressed", cur.entity)
        return true
      end
    end
  end

  local source = find_mineable(pair, wanted)
  if not source then
    show(pair, "[item=" .. tostring(wanted) .. "] no mineable source found; doctrine still searching", pair.station)
    root.stats.no_source = (root.stats.no_source or 0) + 1
    return false
  end
  pair.emergency_craft = pair.emergency_craft or {}
  local task = pair.emergency_craft
  task.request = task.request or { kind = "acquisition-repair-0333", item_name = wanted }
  task.item_name = wanted
  task.output_item = wanted
  if (not task.recipe) and _G.get_emergency_craft_recipe then
    local ok_recipe, recipe = pcall(_G.get_emergency_craft_recipe, wanted)
    if ok_recipe and recipe then task.recipe = recipe end
  end
  task.current = {
    kind = "direct-mine-0273",
    entity = source.entity,
    position = source.entity.position,
    item_name = source.item,
    output_item = source.item,
    wanted_item = wanted,
    doctrine_reason = reason or "acquisition-repair-0333"
  }
  task.candidates = task.candidates or { task.current }
  task.index = task.index or 1
  task.gathered_units = task.gathered_units or 0
  task.direct_due_tick_0273 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0315 = nil
  pair.mode = "emergency-gathering"
  pair.target = source.entity
  pair.last_acquisition_repair_0333 = { tick = now(), wanted = wanted, source = source.item, reason = reason or "repair" }
  show(pair, "[item=" .. tostring(source.item) .. "] acquisition repair: direct gather", source.entity)
  root.stats.direct_gather_started = (root.stats.direct_gather_started or 0) + 1
  -- 0.1.336: assigning a direct target is not enough. Immediately hand the
  -- pair to the executor so it issues movement and begins work instead of
  -- loitering around the station with a “busy mining” label.
  pcall(function()
    local Exec = require("scripts.core.acquisition_executor")
    if Exec and Exec.service_pair then Exec.service_pair(pair, "force-direct-gather") end
  end)
  return true
end

function Repair.watch_assigned_idle()
  local root = ensure_root(); if root.enabled == false then return end
  for _, pair in pairs(pairs_by_station()) do
    if valid_pair(pair) then
      local mode = tostring(pair.mode or "")
      local wanted = wanted_from_pair(pair)
      local stuck = (pair.emergency_craft or pair.active_supply_request or pair.supply_request or pair.independent_emergency_operation_0184) and (mode == "" or mode == "idle" or mode == "logistics" or mode == "missing-ammo-supplies" or mode == "pinned-no-ammo" or mode == "independent-emergency-operation")
      if stuck and wanted and ((pair.next_acquisition_repair_tick_0333 or 0) <= now()) then
        pair.next_acquisition_repair_tick_0333 = now() + 180
        Repair.force_direct_gather(pair, wanted, "watchdog-stuck-" .. mode)
      end
    end
  end
end

function Repair.wrap_emergency_acquire()
  local prev = rawget(_G, "tech_priests_emergency_operation_acquire_item_0185")
  if type(prev) ~= "function" or rawget(_G, "TECH_PRIESTS_0333_PRE_EMERGENCY_ACQUIRE") then return end
  _G.TECH_PRIESTS_0333_PRE_EMERGENCY_ACQUIRE = prev
  _G.tech_priests_emergency_operation_acquire_item_0185 = function(pair, item_name, op, count, depth)
    local ok, result = pcall(_G.TECH_PRIESTS_0333_PRE_EMERGENCY_ACQUIRE, pair, item_name, op, count, depth)
    if ok and result then return result end
    if not ok then
      pair.last_acquisition_error_0333 = tostring(result)
    end
    return Repair.force_direct_gather(pair, item_name, ok and "false-return" or ("error:" .. tostring(result))) or (ok and result or false)
  end
end

function Repair.commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-acquire-0333", "Tech Priests: acquisition repair status/kick for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      local pair = nil
      if _G.selected_pair_for_player then local ok, found = pcall(_G.selected_pair_for_player, player); if ok then pair = found end end
      if p == "kick" and pair then Repair.force_direct_gather(pair, wanted_from_pair(pair), "manual-kick") end
      player.print("[Tech Priests 0.1.337] acquisition repair enabled=" .. tostring(root.enabled) .. " direct=" .. tostring(root.stats.direct_gather_started or 0) .. " no-source=" .. tostring(root.stats.no_source or 0) .. " pair-wanted=" .. tostring(pair and wanted_from_pair(pair) or "none") .. " pair-mode=" .. tostring(pair and pair.mode or "none"))
    end)
  end)
end

function Repair.install()
  ensure_root()
  if Repair.installed_0507 then return true end
  Repair.installed_0507 = true
  Repair.wrap_emergency_acquire()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(90, Repair.watch_assigned_idle, { owner = "acquisition_repair", category = "acquisition", note = "single owned assigned-idle repair watchdog", priority = "normal" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(90, Repair.watch_assigned_idle)
  end
  Repair.commands()
  if log then log("[Tech-Priests 0.1.507] acquisition repair installed once via runtime registry") end
  return true
end

return Repair
