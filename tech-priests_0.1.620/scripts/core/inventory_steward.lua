-- scripts/core/inventory_steward.lua
-- Tech Priests 0.1.357 station-bound inventory steward.
--
-- Doctrine correction:
--   Tech-Priests do not own active working inventories. Their bound Cogitator
--   Station inventory is their inventory. Priest inventories are treated only as
--   accidental/transient cargo that must be evacuated back to the station or to a
--   station-owned stash. Crafting and acquisition outputs must never deliberately
--   deposit into the priest inventory.

local Steward = {}
Steward.version = "0.1.490"
Steward.storage_key = "inventory_steward_0357"
Steward.legacy_storage_key = "inventory_steward_0356"
Steward.scan_radius = 28
Steward.station_close_distance_sq = 9
Steward.pulse_max_pairs = 12
Steward.stash_names = { "tech-priests-martian-stone-cache", "wooden-chest", "iron-chest", "steel-chest" }
Steward.chest_build_costs = { ["tech-priests-martian-stone-cache"] = { stone = 12 }, ["wooden-chest"] = { wood = 2 } }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function item_exists(name) return name and prototypes and prototypes.item and prototypes.item[name] ~= nil end
local function entity_exists(name) return name and prototypes and prototypes.entity and prototypes.entity[name] ~= nil end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  local old = storage.tech_priests[Steward.legacy_storage_key]
  storage.tech_priests[Steward.storage_key] = storage.tech_priests[Steward.storage_key] or {
    version = Steward.version,
    enabled = true,
    debug_chat = true,
    stashes_by_station = old and old.stashes_by_station or {},
    stats = {},
  }
  local root = storage.tech_priests[Steward.storage_key]
  root.version = Steward.version
  if root.enabled == nil then root.enabled = true end
  if root.debug_chat == nil then root.debug_chat = true end
  root.stashes_by_station = root.stashes_by_station or {}
  root.stats = root.stats or {}
  return root
end

local function station_key(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil
end

local function say(pair, msg)
  local root = ensure_root()
  if log then log("[Tech Priests 0.1.490] " .. tostring(msg)) end
  if root.debug_chat and game and pair and pair.station and pair.station.valid then
    for _, p in pairs(game.connected_players or {}) do
      if p and p.valid and p.force == pair.station.force then p.print("[Tech Priests 0.1.490] " .. tostring(msg)) end
    end
  end
end

local function draw_status(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    return _G.tech_priests_emit_overhead_status_0473(pair, text, { r = 1, g = 0.82, b = 0.22, a = 0.95 }, ttl or 90, 0.62, "inventory-steward")
  end
  if _G.tech_priests_draw_emergency_operation_status_0184 then
    pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text)
  elseif rendering and rendering.draw_text and valid_pair(pair) then
    pcall(function()
      rendering.draw_text({
        text = text,
        target = pair.priest,
        target_offset = { 0.35, -2.85 },
        surface = pair.priest.surface,
        color = { r = 1, g = 0.82, b = 0.22, a = 0.95 },
        scale = 0.65,
        alignment = "left",
        time_to_live = ttl or 90,
      })
    end)
  end
end

local function safe_get_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function station_inventories(pair)
  local out = {}
  if not valid(pair and pair.station) then return out end
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
  }
  local seen = {}
  for _, id in ipairs(ids) do
    local inv = safe_get_inventory(pair.station, id)
    if inv and not seen[tostring(inv)] then out[#out+1] = inv; seen[tostring(inv)] = true end
  end
  return out
end

local function station_inventory(pair)
  local invs = station_inventories(pair)
  return invs[1]
end

local function priest_inventories(pair)
  local out = {}
  if not valid(pair and pair.priest) then return out end
  local seen = {}
  local function add(inv)
    if inv and inv.valid and not seen[tostring(inv)] then out[#out+1] = inv; seen[tostring(inv)] = true end
  end
  if pair.priest.get_main_inventory then
    local ok, inv = pcall(function() return pair.priest.get_main_inventory() end)
    if ok then add(inv) end
  end
  add(safe_get_inventory(pair.priest, defines.inventory.character_main))
  add(safe_get_inventory(pair.priest, defines.inventory.chest))
  add(safe_get_inventory(pair.priest, defines.inventory.spider_trunk))
  add(safe_get_inventory(pair.priest, defines.inventory.car_trunk))
  return out
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, c = pcall(function() return inv.get_item_count(item) end)
  if ok then return tonumber(c) or 0 end
  return 0
end

local function inv_remove(inv, stack)
  if not (inv and inv.valid and stack and stack.name and stack.count and stack.count > 0) then return 0 end
  local ok, c = pcall(function() return inv.remove(stack) end)
  return ok and (tonumber(c) or 0) or 0
end

local function inv_insert(inv, stack)
  if not (inv and inv.valid and stack and stack.name and stack.count and stack.count > 0) then return 0 end
  local ok, c = pcall(function() return inv.insert(stack) end)
  return ok and (tonumber(c) or 0) or 0
end

local function inv_can_insert(inv, stack)
  if not (inv and inv.valid and stack and stack.name and stack.count and stack.count > 0) then return false end
  local ok, yes = pcall(function() return inv.can_insert(stack) end)
  return ok and yes == true
end

local function empty_slots(inv)
  if not (inv and inv.valid) then return 0 end
  local ok, c = pcall(function() return inv.count_empty_stacks() end)
  return ok and (tonumber(c) or 0) or 0
end

local function entity_inventory(entity)
  return safe_get_inventory(entity, defines.inventory.chest)
      or safe_get_inventory(entity, defines.inventory.assembling_machine_input)
      or safe_get_inventory(entity, defines.inventory.assembling_machine_output)
      or safe_get_inventory(entity, defines.inventory.furnace_source)
      or safe_get_inventory(entity, defines.inventory.furnace_result)
end

local function remember_stash(pair, entity)
  if not (valid_pair(pair) and valid(entity)) then return end
  local root = ensure_root()
  local key = station_key(pair)
  if not key then return end
  root.stashes_by_station[key] = root.stashes_by_station[key] or {}
  root.stashes_by_station[key][entity.unit_number or ("pos:" .. entity.position.x .. ":" .. entity.position.y)] = {
    entity = entity,
    unit = entity.unit_number,
    name = entity.name,
    tick = now(),
    x = entity.position.x,
    y = entity.position.y,
  }
end

local function iter_known_stashes(pair)
  local root = ensure_root()
  local key = station_key(pair)
  local out = {}
  local bucket = key and root.stashes_by_station[key] or nil
  if bucket then
    for id, rec in pairs(bucket) do
      local e = rec and rec.entity
      if valid(e) then out[#out+1] = e else bucket[id] = nil end
    end
  end
  return out
end

local function find_nearby_container(pair, stack)
  if not valid_pair(pair) then return nil, nil end
  for _, e in ipairs(iter_known_stashes(pair)) do
    local inv = entity_inventory(e)
    if inv_can_insert(inv, stack) then return e, inv end
  end
  local surface = pair.station.surface
  local ents = {}
  pcall(function()
    ents = surface.find_entities_filtered({
      position = pair.station.position,
      radius = Steward.scan_radius,
      force = pair.station.force,
      type = { "container", "logistic-container", "assembling-machine", "furnace" }
    }) or {}
  end)
  for _, e in pairs(ents) do
    if valid(e) and e ~= pair.station then
      local inv = entity_inventory(e)
      if inv_can_insert(inv, stack) then
        if e.type == "container" or e.type == "logistic-container" then remember_stash(pair, e) end
        return e, inv
      end
    end
  end
  return nil, nil
end

local function count_in_station(pair, item)
  local total = 0
  for _, inv in ipairs(station_inventories(pair)) do total = total + inv_count(inv, item) end
  return total
end

local function remove_from_station(pair, item, count)
  local remaining = count or 1
  local removed_total = 0
  for _, inv in ipairs(station_inventories(pair)) do
    if remaining <= 0 then break end
    local removed = inv_remove(inv, { name = item, count = remaining })
    remaining = remaining - removed
    removed_total = removed_total + removed
  end
  return removed_total
end

local function count_accidental_priest_cargo(pair)
  local n = 0
  for _, inv in ipairs(priest_inventories(pair)) do
    local ok, contents = pcall(function() return inv.get_contents() end)
    if ok and contents then
      for _, v in pairs(contents) do
        if type(v) == "number" then n = n + v elseif type(v) == "table" then n = n + (tonumber(v.count) or 0) end
      end
    end
  end
  return n
end

local function find_build_position(pair, entity_name)
  if not valid_pair(pair) then return nil end
  local surface = pair.station.surface
  local base = pair.station.position
  local offsets = {
    {2.5, 0}, {-2.5, 0}, {0, 2.5}, {0, -2.5},
    {3.5, 2.5}, {-3.5, 2.5}, {3.5, -2.5}, {-3.5, -2.5},
    {5, 0}, {-5, 0}, {0, 5}, {0, -5},
  }
  for _, o in ipairs(offsets) do
    local p = { x = base.x + o[1], y = base.y + o[2] }
    local ok, pos = pcall(function() return surface.find_non_colliding_position(entity_name, p, 3, 0.25, false) end)
    if ok and pos then return pos end
  end
  return nil
end

function Steward.create_stash(pair)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local surface = pair.station.surface
  local chosen = nil
  for _, name in ipairs(Steward.stash_names) do
    if entity_exists(name) and count_in_station(pair, name) > 0 then
      chosen = name
      remove_from_station(pair, name, 1)
      break
    end
  end
  if not chosen then
    for _, candidate in ipairs(Steward.stash_names) do
      local cost = Steward.chest_build_costs[candidate]
      if cost and entity_exists(candidate) then
        local enough = true
        for item, need in pairs(cost) do if count_in_station(pair, item) < need then enough = false end end
        if enough then
          for item, need in pairs(cost) do remove_from_station(pair, item, need) end
          chosen = candidate
          break
        end
      end
    end
  end
  if not chosen then return nil, "no-station-chest-or-wood" end
  local pos = find_build_position(pair, chosen)
  if not pos then return nil, "no-build-position" end
  local ok, entity = pcall(function()
    return surface.create_entity({ name = chosen, position = pos, force = pair.station.force, raise_built = true })
  end)
  if not (ok and valid(entity)) then return nil, "create-failed" end
  remember_stash(pair, entity)
  ensure_root().stats.stashes_created = (ensure_root().stats.stashes_created or 0) + 1
  draw_status(pair, "[item=" .. chosen .. "] station stash created", 120)
  say(pair, string.format("%s created station-bound stash %s near %s", tostring(pair.priest.backer_name or pair.priest.name), chosen, tostring(pair.station.backer_name or pair.station.name)))
  return entity, "created"
end

function Steward.safe_deposit_item(pair, item, count, reason)
  local root = ensure_root(); if root.enabled == false then return false, "disabled" end
  if not (valid_pair(pair) and item_exists(item)) then return false, "invalid" end
  count = math.max(1, tonumber(count) or 1)
  local stack = { name = item, count = count }

  for _, sinv in ipairs(station_inventories(pair)) do
    if inv_can_insert(sinv, stack) then
      local inserted = inv_insert(sinv, stack)
      if inserted >= count then
        root.stats.deposited_station = (root.stats.deposited_station or 0) + inserted
        return true, "station"
      end
    end
  end

  local stash, inv = find_nearby_container(pair, stack)
  if stash and inv then
    local inserted = inv_insert(inv, stack)
    if inserted >= count then
      remember_stash(pair, stash)
      root.stats.deposited_stash = (root.stats.deposited_stash or 0) + inserted
      draw_status(pair, string.format("[item=%s] stashed x%d in station stash", item, inserted), 90)
      return true, "stash"
    end
  end

  local made, why = Steward.create_stash(pair)
  if made then
    local minv = entity_inventory(made)
    if inv_can_insert(minv, stack) then
      local inserted = inv_insert(minv, stack)
      if inserted >= count then
        root.stats.deposited_new_stash = (root.stats.deposited_new_stash or 0) + inserted
        draw_status(pair, string.format("[item=%s] stashed x%d in new station chest", item, inserted), 120)
        return true, "new-stash"
      end
    end
  end

  root.stats.blocked = (root.stats.blocked or 0) + 1
  draw_status(pair, string.format("[item=%s] station inventory full; need station stash", item), 120)
  return false, why or "no-station-space"
end

function Steward.flush_priest_inventory_to_station(pair, reason)
  if not valid_pair(pair) then return 0, "invalid-pair" end
  local moved = 0
  for _, inv in ipairs(priest_inventories(pair)) do
    for i = 1, #inv do
      local stack = inv[i]
      if stack and stack.valid_for_read then
        local name, count = stack.name, stack.count
        local ok, why = Steward.safe_deposit_item(pair, name, count, reason or "priest-inventory-evacuation")
        if ok then
          local removed = inv_remove(inv, { name = name, count = count })
          moved = moved + removed
        else
          draw_status(pair, string.format("station-bound inventory blocked: %s", tostring(why)), 120)
          return moved, why
        end
      end
    end
  end
  if moved > 0 then
    ensure_root().stats.evacuated_priest_items = (ensure_root().stats.evacuated_priest_items or 0) + moved
    draw_status(pair, string.format("station-bound inventory: moved %d items to station", moved), 90)
  end
  return moved, "ok"
end

-- Compatibility name. This no longer means “free room in the priest.” It means
-- evacuate accidental priest cargo and verify the bound station has some space.
function Steward.unload_nonessential_priest_inventory(pair, reason)
  return Steward.flush_priest_inventory_to_station(pair, reason or "compat-unload")
end

function Steward.ensure_priest_room(pair, slots, reason)
  Steward.flush_priest_inventory_to_station(pair, reason or "station-bound-room")
  local free = 0
  for _, inv in ipairs(station_inventories(pair)) do free = free + empty_slots(inv) end
  if free >= (tonumber(slots) or 1) then return true, "station-space" end
  return false, "station-full"
end


function Steward.sources_for_pair(pair)
  -- Public source list for construction/acquisition helpers. This deliberately
  -- excludes priest inventories. The bound station and its remembered stash
  -- containers are the only active working inventories.
  local out = {}
  if not valid_pair(pair) then return out end
  Steward.flush_priest_inventory_to_station(pair, "sources-for-pair")
  for _, inv in ipairs(station_inventories(pair)) do
    out[#out+1] = { inv = inv, inventory_id = "station", source = "station", entity = pair.station }
  end
  for _, e in ipairs(iter_known_stashes(pair)) do
    local inv = entity_inventory(e)
    if inv and inv.valid then out[#out+1] = { inv = inv, inventory_id = "stash", source = "station-stash", entity = e } end
  end
  return out
end

function Steward.wrap_legacy_finish()
  local prev = rawget(_G, "finish_emergency_desperation_craft")
  if type(prev) ~= "function" or rawget(_G, "TECH_PRIESTS_0357_PRE_STEWARD_FINISH_CRAFT") ~= nil then return end
  _G.TECH_PRIESTS_0357_PRE_STEWARD_FINISH_CRAFT = prev
  _G.finish_emergency_desperation_craft = function(pair)
    local task = pair and pair.emergency_craft or nil
    local item = task and task.output_item or nil
    if item and valid_pair(pair) then
      local ok, why = Steward.safe_deposit_item(pair, item, 1, "craft-output")
      if ok then
        pair.emergency_craft = nil
        if _G.clear_logistic_frustration then pcall(_G.clear_logistic_frustration, pair) end
        pair.mode = "returning"
        pair.target = nil
        if _G.return_to_station and pair.priest and pair.station then pcall(_G.return_to_station, pair.priest, pair.station) end
        draw_status(pair, string.format("[item=%s] crafted into station inventory", item), 120)
        return true
      else
        task.craft_due_tick = now() + 90
        task.station_craft_due_tick_0337 = task.craft_due_tick
        pair.mode = "emergency-crafting-waiting-for-station-space"
        draw_status(pair, string.format("[item=%s] craft paused: no station inventory space (%s)", item, tostring(why)), 150)
        return true
      end
    end
    return _G.TECH_PRIESTS_0357_PRE_STEWARD_FINISH_CRAFT(pair)
  end
end

function Steward.pulse_pair(pair)
  if not valid_pair(pair) then return false end
  Steward.flush_priest_inventory_to_station(pair, "periodic-station-bound-flush")
  return true
end

function Steward.pulse()
  local root = ensure_root(); if root.enabled == false then return end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= Steward.pulse_max_pairs then break end
    if valid_pair(pair) then Steward.pulse_pair(pair); n = n + 1 end
  end
end

local function selected_pair(player)
  if not (player and player.valid and player.selected) then return nil end
  local sel = player.selected
  for _, pair in pairs(pair_map()) do
    if pair and ((valid(pair.station) and pair.station == sel) or (valid(pair.priest) and pair.priest == sel)) then return pair end
  end
  return nil
end

function Steward.status(pair)
  local root = ensure_root()
  local key = station_key(pair)
  local stashes = 0
  if key and root.stashes_by_station[key] then for _, rec in pairs(root.stashes_by_station[key]) do if valid(rec.entity) then stashes = stashes + 1 end end end
  local sinv = station_inventory(pair or {})
  local priest_items = pair and count_accidental_priest_cargo(pair) or 0
  return string.format("enabled=%s doctrine=station-bound stashes=%d station_empty_slots=%s accidental_priest_items=%s station=%s stats_station=%s stats_stash=%s evacuated=%s blocked=%s", tostring(root.enabled), stashes, tostring(empty_slots(sinv)), tostring(priest_items), tostring(key or "none"), tostring(root.stats.deposited_station or 0), tostring((root.stats.deposited_stash or 0) + (root.stats.deposited_new_stash or 0)), tostring(root.stats.evacuated_priest_items or 0), tostring(root.stats.blocked or 0))
end

function Steward.commands()
  if not (commands and commands.add_command) then return end
  local function handler(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not player then return end
    local root = ensure_root()
    local p = tostring(event.parameter or "status")
    if p == "enable" then root.enabled = true end
    if p == "disable" then root.enabled = false end
    if p == "debug-on" then root.debug_chat = true end
    if p == "debug-off" then root.debug_chat = false end
    local pair = selected_pair(player)
    local acted = false
    if p == "kick" and pair then Steward.flush_priest_inventory_to_station(pair, "manual-kick"); acted = true end
    if p == "all" then for _, q in pairs(pair_map()) do if valid_pair(q) then Steward.pulse_pair(q); acted = true end end end
    player.print("[Tech Priests 0.1.490] inventory steward " .. Steward.status(pair) .. " acted=" .. tostring(acted))
  end
  pcall(function() commands.remove_command("tp-inventory-steward-0356") end)
  pcall(function() commands.remove_command("tp-inventory-steward-0357") end)
  commands.add_command("tp-inventory-steward-0356", "Tech Priests: station-bound inventory steward. Usage: status|kick|all|enable|disable|debug-on|debug-off", handler)
  commands.add_command("tp-inventory-steward-0357", "Tech Priests 0.1.357: station-bound inventory steward. Usage: status|kick|all|enable|disable|debug-on|debug-off", handler)
end

function Steward.install()
  ensure_root()
  _G.tech_priests_safe_deposit_item = Steward.safe_deposit_item
  _G.tech_priests_inventory_steward_unload = Steward.flush_priest_inventory_to_station
  _G.tech_priests_inventory_steward_create_stash = Steward.create_stash
  _G.tech_priests_inventory_steward_sources_for_pair = Steward.sources_for_pair
  _G.TECH_PRIESTS_STATION_BOUND_INVENTORY_0357 = Steward
  Steward.wrap_legacy_finish()
  Steward.commands()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "inventory_steward_0357", category = "inventory", interval = 43, priority = 65, budget = 8, fn = function(event, budget) Steward.pulse(event) return true end, note = "station-bound inventory steward migrated from direct nth-tick" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(43, Steward.pulse, { owner = "inventory_steward_0357", category = "inventory", note = "fallback until runtime broker is available", priority = "normal" })
    elseif script and script.on_nth_tick then script.on_nth_tick(43, Steward.pulse) end
  end
  if log then log("[Tech-Priests 0.1.490] station-bound inventory steward installed; priest inventories are treated as accidental cargo only") end
  return true
end

return Steward
