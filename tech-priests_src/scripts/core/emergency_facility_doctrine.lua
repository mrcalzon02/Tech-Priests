-- scripts/core/emergency_facility_doctrine.lua
-- Tech Priests 0.1.343 Martian emergency facility doctrine with micro-smelter.
--
-- This module lets scavenge/acquisition mode reuse emergency equipment placed
-- and tagged by its own Cogitator Station. If no suitable owned equipment is
-- available, it asks the construction planner to place the necessary Martian
-- emergency hardware. It deliberately starts with conservative equipment use:
-- miners, atmospheric condenser, boiler, steam engine, emergency assembler,
-- emergency power grid, and laboratorium are tagged and tracked; recipes and
-- inventories are nudged only when the target entity exposes safe Factorio API
-- calls.

local M = {}
M.version = "0.1.348"
M.storage_key = "emergency_facility_doctrine_0343"
M.service_period = 11
M.max_per_pulse = 12
M.station_close_distance_sq = 9.0
M.default_radius = 36

local EMERGENCY_ENTITIES = {
  ["tech-priests-emergency-miner"] = { role = "miner", item = "tech-priests-emergency-miner" },
  ["tech-priests-atmospheric-water-condenser"] = { role = "condenser", item = "tech-priests-atmospheric-water-condenser" },
  ["tech-priests-emergency-boiler"] = { role = "boiler", item = "tech-priests-emergency-boiler" },
  ["tech-priests-emergency-steam-engine"] = { role = "steam-engine", item = "tech-priests-emergency-steam-engine" },
  ["tech-priests-emergency-smelter"] = { role = "smelter", item = "tech-priests-emergency-smelter" },
  ["tech-priests-emergency-assembler"] = { role = "assembler", item = "tech-priests-emergency-assembler" },
  ["tech-priests-emergency-laboratorium"] = { role = "lab", item = "tech-priests-emergency-laboratorium" },
  ["tech-priests-emergency-power-grid"] = { role = "power-grid", item = "tech-priests-emergency-power-grid" },
}

local REQUIRED_CORE = {
  "tech-priests-emergency-miner",
  -- 0.1.343: the smelter is the first true industry unlock after crude
  -- mining, because plates should come from ore + fuel in a machine instead
  -- of hand/substitute crafting.
  "tech-priests-emergency-smelter",
  "tech-priests-atmospheric-water-condenser",
  "tech-priests-emergency-boiler",
  "tech-priests-emergency-steam-engine",
  "tech-priests-emergency-power-grid",
  "tech-priests-emergency-assembler",
}

local BASIC_FUELS = { "coal", "wood", "solid-fuel" }
local REQUEST_ITEMS = { "iron-ore", "copper-ore", "coal", "stone", "wood", "iron-plate", "copper-plate", "firearm-magazine" }


local function debug_chat_allowed_0626(root)
  if not (root and root.debug_chat) then return false end
  if _G and _G.tech_priests_runtime_debug_enabled_0626 then
    local ok, enabled = pcall(_G.tech_priests_runtime_debug_enabled_0626, "verbose")
    if ok then return enabled == true end
  end
  return root.debug_chat == true
end
local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function pairs_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function unit(pair) return pair and pair.station and pair.station.valid and pair.station.unit_number end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function role_of(e) return valid(e) and EMERGENCY_ENTITIES[e.name] and EMERGENCY_ENTITIES[e.name].role or nil end
local function is_emergency_name(name) return EMERGENCY_ENTITIES[name] ~= nil end
local function item_for_entity(name) return EMERGENCY_ENTITIES[name] and EMERGENCY_ENTITIES[name].item or name end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    debug_chat = true,
    facilities = {},
    by_station = {},
    stats = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.facilities = root.facilities or {}
  root.by_station = root.by_station or {}
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function entity_key(entity)
  if _G.TECH_PRIESTS_STATION_CATALOG_0327 and _G.TECH_PRIESTS_STATION_CATALOG_0327.entity_key then
    local ok, key = pcall(_G.TECH_PRIESTS_STATION_CATALOG_0327.entity_key, entity)
    if ok and key then return key end
  end
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface) .. ":" .. tostring(entity.name or entity.type) .. ":" .. tostring(math.floor((p.x or 0) * 10)) .. ":" .. tostring(math.floor((p.y or 0) * 10))
end

local function radius_for(pair)
  if not valid_pair(pair) then return M.default_radius end
  if _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, tonumber(r)) end
  end
  return tonumber(pair.radius) or M.default_radius
end

local function draw(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    return _G.tech_priests_emit_overhead_status_0473(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, ttl or 90, 0.62, "emergency-facility-doctrine")
  end
  if _G.TECH_PRIESTS_WORK_VISUALS and _G.TECH_PRIESTS_WORK_VISUALS.show then pcall(_G.TECH_PRIESTS_WORK_VISUALS.show, pair, text, ttl or 90) end
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
end

local function print_msg(pair, text)
  local root = ensure_root(); if not debug_chat_allowed_0626(root) then return end
  if game and game.print then game.print(text) end
  if log then log(text) end
end

local function safe_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function inventory_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function insert_item(inv, item, count)
  if not (inv and inv.valid and item) then return 0 end
  local ok, inserted = pcall(function() return inv.insert({ name = item, count = count or 1 }) end)
  return ok and (tonumber(inserted) or 0) or 0
end

local function remove_item(inv, item, count)
  if not (inv and inv.valid and item) then return 0 end
  local ok, removed = pcall(function() return inv.remove({ name = item, count = count or 1 }) end)
  return ok and (tonumber(removed) or 0) or 0
end

local function inventories(entity)
  local out = {}
  local ids = {
    defines.inventory.chest,
    defines.inventory.character_main,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
    defines.inventory.fuel,
    defines.inventory.burnt_result,
  }
  for _, id in pairs(ids) do
    local inv = safe_inventory(entity, id)
    if inv then out[#out+1] = { id = id, inv = inv } end
  end
  return out
end

local function source_inventory_for(pair, item)
  -- 0.1.357 station-bound doctrine: emergency facilities are fed from the
  -- owning Cogitator Station inventory. Accidental priest cargo is flushed
  -- before lookup and is not considered active material stock.
  if _G.tech_priests_inventory_steward_unload then pcall(_G.tech_priests_inventory_steward_unload, pair, "emergency-facility-source") end
  for _, slot in ipairs(inventories(pair.station)) do
    if inventory_count(slot.inv, item) > 0 then return slot.inv end
  end
  return nil
end

function M.tag_built_entity(pair, entity, reason)
  if not (valid_pair(pair) and valid(entity)) then return false end
  local r = radius_for(pair)
  if dist_sq(entity.position, pair.station.position) > r * r then return false end
  local root = ensure_root()
  local key = entity_key(entity); if not key then return false end
  local u = unit(pair); if not u then return false end
  local role = role_of(entity) or "built"
  root.facilities[key] = {
    key = key,
    station_unit = u,
    entity = entity,
    name = entity.name,
    role = role,
    reason = reason or "built",
    tick = now(),
  }
  root.by_station[u] = root.by_station[u] or {}
  root.by_station[u][key] = true
  pair.emergency_facility_keys_0339 = pair.emergency_facility_keys_0339 or {}
  pair.emergency_facility_keys_0339[key] = true
  if _G.TECH_PRIESTS_STATION_CATALOG_0327 and _G.TECH_PRIESTS_STATION_CATALOG_0327.claim_built_entity then
    pcall(_G.TECH_PRIESTS_STATION_CATALOG_0327.claim_built_entity, pair, entity, "built-facility")
  end
  root.stats.tagged = (root.stats.tagged or 0) + 1
  draw(pair, "tagged facility: " .. tostring(entity.name), 90)
  return true
end

local function forget_invalid(root)
  for key, rec in pairs(root.facilities or {}) do
    if not (rec.entity and rec.entity.valid) then
      local by = root.by_station[rec.station_unit]
      if by then by[key] = nil end
      root.facilities[key] = nil
    end
  end
end

local function scan_owned_emergency(pair)
  local root = ensure_root(); if not valid_pair(pair) then return {} end
  local u = unit(pair); local found = {}
  local r = radius_for(pair)
  local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r }) end)
  if not ok or not ents then return found end
  for _, e in pairs(ents) do
    if valid(e) and is_emergency_name(e.name) then
      local key = entity_key(e)
      local rec = root.facilities[key]
      if rec and rec.station_unit == u then
        rec.entity = e; found[#found+1] = rec
      elseif (not rec) and dist_sq(e.position, pair.station.position) <= r*r then
        -- If it was placed before this module existed and is inside the station
        -- radius, conservatively let the nearest owning station claim it on scan.
        M.tag_built_entity(pair, e, "local-scan")
        found[#found+1] = root.facilities[key]
      end
    end
  end
  return found
end

local function recipe_exists(name)
  if not name then return false end
  if prototypes and prototypes.recipe then
    local ok, p = pcall(function() return prototypes.recipe[name] end)
    return ok and p ~= nil
  end
  return false
end

local function safe_suffix(item)
  return tostring(item or ""):gsub("[^%w%-_]", "-")
end

local function recipe_for(role, item)
  item = item or "iron-ore"
  if role == "miner" then
    local r = "tech-priests-emergency-mine-" .. safe_suffix(item)
    if recipe_exists(r) then return r end
    for _, alt in ipairs({ "iron-ore", "coal", "stone", "wood", "copper-ore" }) do
      r = "tech-priests-emergency-mine-" .. safe_suffix(alt)
      if recipe_exists(r) then return r end
    end
  elseif role == "smelter" then
    if item == "iron-plate" then return "tech-priests-emergency-smelt-iron-ore-to-iron-plate" end
    if item == "copper-plate" then return "tech-priests-emergency-smelt-copper-ore-to-copper-plate" end
    if item == "stone-brick" then return "tech-priests-emergency-smelt-stone-to-stone-brick" end
  elseif role == "assembler" then
    if item == "repair-pack" and recipe_exists("tech-priests-emergency-repair-pack") then return "tech-priests-emergency-repair-pack" end
    if recipe_exists(item) then return item end
  elseif role == "condenser" then
    if recipe_exists("tech-priests-atmospheric-water-condensation") then return "tech-priests-atmospheric-water-condensation" end
    if recipe_exists("tech-priests-condense-water") then return "tech-priests-condense-water" end
  end
  return nil
end

local function set_recipe(entity, recipe, pair, reason)
  if not (valid(entity) and recipe and entity.set_recipe) then return false end
  -- 0.1.576: recipe mutation must claim the machine first. This prevents
  -- several priests from repeatedly changing the same emergency facility while
  -- also drawing a small visible Tech-Priest reservation icon over the target.
  if _G.tech_priests_0576_claim_machine_for_recipe then
    local ok_claim, allowed, why = pcall(_G.tech_priests_0576_claim_machine_for_recipe, pair, entity, recipe, reason or "emergency-facility-doctrine")
    if ok_claim and allowed == false then return false, why end
  end
  local current = nil
  pcall(function() local r = entity.get_recipe and entity.get_recipe(); current = type(r) == "string" and r or (r and r.name) end)
  if current == recipe then return true end
  local ok, result = pcall(function() return entity.set_recipe(recipe) end)
  return ok and result ~= false
end

local function feed_fuel_from_pair(pair, entity)
  local fuel = safe_inventory(entity, defines.inventory.fuel)
  if not fuel then return 0 end
  local inserted = 0
  for _, f in ipairs(BASIC_FUELS) do
    if inventory_count(fuel, f) < 2 then
      local src = source_inventory_for(pair, f)
      if src then
        local removed = remove_item(src, f, 2 - inventory_count(fuel, f))
        if removed > 0 then inserted = inserted + insert_item(fuel, f, removed) end
      end
    end
  end
  return inserted
end

local function feed_inputs_from_pair(pair, entity, want_item)
  local input = safe_inventory(entity, defines.inventory.assembling_machine_input) or safe_inventory(entity, defines.inventory.furnace_source)
  if not input then return 0 end
  local inserted = 0
  local candidates = { want_item, "iron-ore", "copper-ore", "stone", "coal", "wood", "iron-plate", "copper-plate" }
  for _, it in ipairs(candidates) do
    if it and inventory_count(input, it) < 4 then
      local src = source_inventory_for(pair, it)
      if src then
        local removed = remove_item(src, it, 4 - inventory_count(input, it))
        if removed > 0 then inserted = inserted + insert_item(input, it, removed) end
      end
    end
  end
  return inserted
end

local function choose_request_item(pair)
  local task = pair and (pair.station_crafting_task_0337 or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333 or pair.emergency_operation or pair.independent_emergency_operation)
  if type(task) == "table" then
    return task.item or task.item_name or task.craft or task.requested_item or task.output or task.target_item
  end
  if type(task) == "string" then return task end
  for _, it in ipairs(REQUEST_ITEMS) do return it end
  return "iron-ore"
end

local function find_role(facilities, role)
  for _, rec in pairs(facilities or {}) do
    if rec and rec.role == role and rec.entity and rec.entity.valid then return rec.entity end
  end
  return nil
end

local function has_role(facilities, role)
  return find_role(facilities, role) ~= nil
end

local function missing_core_items(facilities)
  local have = {}
  for _, rec in pairs(facilities or {}) do if rec and rec.name then have[rec.name] = true end end
  local missing = {}
  for _, name in ipairs(REQUIRED_CORE) do if not have[name] then missing[#missing+1] = item_for_entity(name) end end
  return missing
end

local function give_build_order(pair, item)
  -- If the construction planner sees the item in the bound station inventory, it
  -- will place it. This module does not fabricate items; crafting/acquisition
  -- modules remain responsible for producing them.
  local planner = _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0357 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0343 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0342 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0340 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0338
  if planner and planner.service_pair then
    pcall(planner.service_pair, pair, "emergency-facility-doctrine")
  end
  draw(pair, "placing emergency facility: [item=" .. tostring(item) .. "]", 90)
end

local function use_owned_facilities(pair, facilities, request_item)
  local used = false
  local miner = find_role(facilities, "miner")
  if miner then
    local recipe = recipe_for("miner", request_item or "iron-ore")
    if recipe then
      -- 0.1.576: the Micro-Miner is now player/priest selectable through its
      -- ordinary assembler recipe menu. Do not keep changing it just because a
      -- different emergency item is requested. Set one safe default only if no
      -- emergency recipe is currently selected.
      local current = nil
      pcall(function() local r = miner.get_recipe and miner.get_recipe(); current = type(r) == "string" and r or (r and r.name) end)
      local has_emergency_recipe = current and string.sub(current, 1, #"tech-priests-emergency-mine-") == "tech-priests-emergency-mine-"
      if has_emergency_recipe or set_recipe(miner, recipe, pair, "micro-miner-default") then
        feed_fuel_from_pair(pair, miner)
        draw(pair, "emergency miner: " .. tostring(current or recipe), 90)
        used = true
      end
    end
  end

  local smelter = find_role(facilities, "smelter")
  if smelter then
    local recipe = recipe_for("smelter", request_item)
    if recipe and set_recipe(smelter, recipe, pair, "emergency-smelter") then
      feed_fuel_from_pair(pair, smelter)
      feed_inputs_from_pair(pair, smelter, request_item)
      draw(pair, "emergency smelter: " .. tostring(recipe), 90)
      used = true
    end
  end

  local assembler = find_role(facilities, "assembler")
  if assembler then
    local recipe = recipe_for("assembler", request_item)
    if recipe and set_recipe(assembler, recipe, pair, "emergency-assembler") then
      feed_fuel_from_pair(pair, assembler)
      feed_inputs_from_pair(pair, assembler, request_item)
      draw(pair, "emergency assembler: " .. tostring(recipe), 90)
      used = true
    end
  end

  local condenser = find_role(facilities, "condenser")
  if condenser then
    local recipe = recipe_for("condenser", "water")
    if recipe then set_recipe(condenser, recipe, pair, "emergency-condenser") end
    feed_fuel_from_pair(pair, condenser)
    used = true
  end

  local boiler = find_role(facilities, "boiler")
  if boiler then feed_fuel_from_pair(pair, boiler); used = true end
  return used
end

local function service_pair(pair, reason)
  local root = ensure_root(); if root.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  forget_invalid(root)

  local facilities = scan_owned_emergency(pair)
  local request_item = choose_request_item(pair)
  if #facilities > 0 and use_owned_facilities(pair, facilities, request_item) then
    root.stats.used = (root.stats.used or 0) + 1
    return true, "used-owned-facilities"
  end

  local missing = missing_core_items(facilities)
  if #missing > 0 then
    for _, item in ipairs(missing) do
      -- Only ask for the next missing item. Repeated pulses will advance the
      -- chain after construction/crafting catches up.
      give_build_order(pair, item)
      root.stats.requested_build = (root.stats.requested_build or 0) + 1
      return true, "requested-" .. tostring(item)
    end
  end

  return false, "no-emergency-facility-action"
end

function M.service_pair(pair, reason) return service_pair(pair, reason or "external") end

function M.service_all(reason)
  local root = ensure_root(); if root.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pairs_map()) do
    if n >= M.max_per_pulse then break end
    local ok = service_pair(pair, reason or "pulse")
    if ok then n = n + 1 end
  end
  return n
end

local function selected_pair(player)
  if not (player and player.valid and player.selected) then return nil end
  local sel = player.selected
  for _, pair in pairs(pairs_map()) do
    if pair and ((valid(pair.station) and pair.station == sel) or (valid(pair.priest) and pair.priest == sel)) then return pair end
  end
  return nil
end

local function describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local facilities = scan_owned_emergency(pair)
  local roles = {}
  for _, rec in ipairs(facilities) do roles[#roles+1] = tostring(rec.role) .. ":" .. tostring(rec.name) end
  return "station=" .. tostring(pair.station.unit_number) .. " facilities=" .. tostring(#facilities) .. " request=" .. tostring(choose_request_item(pair)) .. " :: " .. table.concat(roles, ", ")
end

function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-emergency-facilities-0339") end)
  commands.add_command("tp-emergency-facilities-0339", "Tech-Priests Martian emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[tp-emergency-facilities-0339] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[tp-emergency-facilities-0339] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[tp-emergency-facilities-0339] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[tp-emergency-facilities-0339] debug chat off") return end
    if arg == "all" then player.print("[tp-emergency-facilities-0339] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-emergency-facilities-0339] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[tp-emergency-facilities-0339] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[tp-emergency-facilities-0339] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end)

  pcall(function() commands.remove_command("tp-emergency-facilities-0340") end)
  commands.add_command("tp-emergency-facilities-0340", "Tech-Priests 0.1.340 Martian emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[tp-emergency-facilities-0340] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[tp-emergency-facilities-0340] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[tp-emergency-facilities-0340] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[tp-emergency-facilities-0340] debug chat off") return end
    if arg == "all" then player.print("[tp-emergency-facilities-0340] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-emergency-facilities-0340] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[tp-emergency-facilities-0340] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[tp-emergency-facilities-0340] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end)

  local function handle_0357(event, label)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[" .. label .. "] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[" .. label .. "] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[" .. label .. "] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[" .. label .. "] debug chat off") return end
    if arg == "all" then player.print("[" .. label .. "] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[" .. label .. "] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[" .. label .. "] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[" .. label .. "] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end
  pcall(function() commands.remove_command("tp-emergency-facilities-0343") end)
  pcall(function() commands.remove_command("tp-emergency-facilities-0357") end)
  commands.add_command("tp-emergency-facilities-0357", "Tech-Priests 0.1.357 emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_0357(event, "tp-emergency-facilities-0357") end)
  commands.add_command("tp-emergency-facilities-0343", "Tech-Priests 0.1.342 Martian emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[tp-emergency-facilities-0343] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[tp-emergency-facilities-0343] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[tp-emergency-facilities-0343] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[tp-emergency-facilities-0343] debug chat off") return end
    if arg == "all" then player.print("[tp-emergency-facilities-0343] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-emergency-facilities-0343] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[tp-emergency-facilities-0343] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[tp-emergency-facilities-0343] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end)
end

function M.install()
  ensure_root()
  M.install_commands()
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0339 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0357 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0340 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0342 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0348 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "emergency_facility_doctrine_0357", category = "emergency", interval = M.service_period or 60, priority = 60, budget = 8, fn = function(event, budget) return M.service_all("broker-periodic") end, note = "Martian emergency facility doctrine migrated from direct nth-tick" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(M.service_period, function() M.service_all("registry-periodic") end, { owner = "emergency_facility_doctrine_0357", category = "emergency", note = "fallback until runtime broker is available", priority = "normal" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.service_period, function() M.service_all("periodic") end)
    end
  end
  if log then log("[Tech-Priests 0.1.357] Martian emergency facility doctrine station-bound inventory source lookup loaded") end
end

return M
