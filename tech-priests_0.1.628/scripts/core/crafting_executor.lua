-- scripts/core/crafting_executor.lua
-- Tech Priests 0.1.337 station-anchored emergency crafting executor.
--
-- Mining happens at the mine. Crafting happens at the Cogitator Station.
-- This layer prevents the old desperation crafting routine from silently
-- finishing while a priest is loitering in the field, adds an obvious progress
-- bar, and reports successful crafts to chat/log/debug so the player can see
-- the work actually completed.

local Craft = {}
Craft.version = "0.1.340"
Craft.storage_key = "crafting_executor_0337"
Craft.close_distance_sq = 5.76 -- about 2.4 tiles; stations are large sprites.
Craft.move_refresh_ticks = 45
Craft.progress_refresh_ticks = 10
Craft.default_craft_ticks = 180
Craft.default_scan_ticks = 90
Craft.default_inventory_scan_ticks = 45

local function now() return game and game.tick or 0 end

local function debug_chat_allowed_0626(root)
  if not (root and root.debug_chat) then return false end
  if _G and _G.tech_priests_runtime_debug_enabled_0626 then
    local ok, enabled = pcall(_G.tech_priests_runtime_debug_enabled_0626, "verbose")
    if ok then return enabled == true end
  end
  return root.debug_chat == true
end
local function valid(e) return e and e.valid end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function pairs_by_station() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Craft.storage_key] = storage.tech_priests[Craft.storage_key] or { version = Craft.version, enabled = true, debug_chat = true, objects = {}, stats = {} }
  local root = storage.tech_priests[Craft.storage_key]
  root.version = Craft.version
  if root.enabled == nil then root.enabled = true end
  if root.debug_chat == nil then root.debug_chat = true end
  root.objects = root.objects or {}
  root.stats = root.stats or {}
  return root
end

local function pair_key(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or (pair.priest and pair.priest.valid and pair.priest.unit_number)) or nil
end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  return false
end

local function station_inventory(pair)
  if not (pair and pair.station and pair.station.valid and pair.station.get_inventory) then return nil end
  local inv = nil
  pcall(function()
    inv = pair.station.get_inventory(defines.inventory.chest)
       or pair.station.get_inventory(defines.inventory.assembling_machine_input)
       or pair.station.get_inventory(defines.inventory.assembling_machine_output)
  end)
  if inv and inv.valid then return inv end
  return nil
end

local function item_text(name)
  if name and item_exists(name) then return "[item=" .. tostring(name) .. "]" end
  return "[virtual-signal=signal-info]"
end

local function bar(progress, width)
  width = width or 16
  progress = math.max(0, math.min(1, tonumber(progress) or 0))
  local filled = math.floor(progress * width + 0.5)
  local out = ""
  for i = 1, width do out = out .. (i <= filled and "█" or "░") end
  return out
end

local function safe_destroy(obj)
  if not obj then return end
  pcall(function() if obj.valid == nil or obj.valid then obj.destroy() end end)
end

local function draw_text(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    return _G.tech_priests_emit_overhead_status_0473(pair, text, { r = 1.0, g = 0.86, b = 0.25, a = 0.98 }, ttl or 24, 0.62, "crafting-executor")
  end
  if not (valid_pair(pair) and rendering and rendering.draw_text) then return end
  local root = ensure_root()
  local key = pair_key(pair)
  if not key then return end
  safe_destroy(root.objects[key]); root.objects[key] = nil
  local ok, obj = pcall(function()
    return rendering.draw_text({
      text = text,
      target = pair.priest,
      target_offset = { 0.35, -3.05 },
      surface = pair.priest.surface,
      color = { r = 1.0, g = 0.86, b = 0.25, a = 0.98 },
      scale = 0.68,
      alignment = "left",
      time_to_live = ttl or 24
    })
  end)
  if ok and obj then root.objects[key] = obj end
end

local function draw_station_line(pair)
  -- 0.1.489: The paired Cogitator Station is not a scan target.
  -- A priest and its station share doctrine/inventory authority, so crafting
  -- return-to-station behavior must not draw acquisition/scanning beams back
  -- into the home station. The movement/order state still handles returning.
  return false
end

local function move_to_station(pair, reason)
  if not valid_pair(pair) then return false end
  local stale = (not pair.last_station_craft_command_0337) or (now() - (pair.last_station_craft_command_0337.tick or 0) >= Craft.move_refresh_ticks)
  if stale then
    local ok = false
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pair.station.position, reason or "station-craft", { radius = 1.15, owner = "crafting-executor", priority = 65, distraction = defines.distraction.none })
    else
      local command = { type = defines.command.go_to_location, destination = pair.station.position, radius = 1.15, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "crafting-executor-fallback-0616", { pair = pair, priority = 65, ttl = 600 })
        ok = ok_route and res ~= false
      else
        ok = pcall(function() pair.priest.set_command(command) end)
      end
    end
    if ok then pair.last_station_craft_command_0337 = { tick = now(), reason = reason or "station-craft" } end
  end
  pair.mode = "returning-to-station-for-craft"
  local d = math.sqrt(dist_sq(pair.priest.position, pair.station.position))
  local item = pair.emergency_craft and (pair.emergency_craft.output_item or pair.emergency_craft.item_name) or nil
  draw_text(pair, string.format("%s returning to station to craft %.1fm", item_text(item), d), 28)
  return true
end

local function at_station(pair)
  return valid_pair(pair) and dist_sq(pair.priest.position, pair.station.position) <= Craft.close_distance_sq
end

local function needed_units(task)
  local recipe = task and task.recipe or {}
  return math.max(1, tonumber(recipe.units) or tonumber(task and task.required_count) or 1)
end

local function ready_to_craft(pair)
  local task = pair and pair.emergency_craft
  if not task then return false end
  return (tonumber(task.gathered_units) or 0) >= needed_units(task)
end

local function progress_text(pair, task)
  local item = task and (task.output_item or task.item_name or (task.request and (task.request.item_name or task.request.name))) or nil
  local due = task and (task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337)
  local started = task and (task.craft_started_tick_0337 or task.station_craft_started_tick_0337 or task.craft_started_tick or task.started_tick) or now()
  local total = math.max(1, (due and started) and (due - started) or (tonumber(_G.EMERGENCY_CRAFT_WORK_TICKS) or Craft.default_craft_ticks))
  local remaining = due and math.max(0, due - now()) or total
  local progress = 1 - math.min(1, remaining / total)
  return string.format("%s crafting %s %ds", item_text(item), bar(progress, 16), math.ceil(remaining / 60))
end

local function entity_label(entity, fallback)
  if not valid(entity) then return fallback or "?" end
  local ok_backer, backer = pcall(function() return entity.backer_name end)
  if ok_backer and backer and backer ~= "" then return backer end
  local ok_name, name = pcall(function() return entity.name end)
  if ok_name and name then return name end
  return fallback or "?"
end

local function print_success(pair, item, count)
  local root = ensure_root()
  root.stats.crafted = (root.stats.crafted or 0) + (count or 1)
  root.stats.last_crafted_item = item
  root.stats.last_crafted_tick = now()
  local msg = string.format("[Tech Priests 0.1.337] %s successfully crafted %s x%d at station %s", entity_label(pair and pair.priest, "Tech-Priest"), tostring(item), tonumber(count) or 1, entity_label(pair and pair.station, "Cogitator Station"))
  if log then log(msg) end
  if debug_chat_allowed_0626(root) and game and pair.station and pair.station.valid and pair.station.force then
    for _, player in pairs(game.connected_players or {}) do
      if player and player.valid and player.force == pair.station.force then player.print(msg) end
    end
  end
  if pair and pair.priest and pair.priest.valid then
    draw_text(pair, string.format("%s crafted successfully", item_text(item)), 90)
  end
end

function Craft.before_legacy_handle(pair)
  local root = ensure_root(); if root.enabled == false then return false end
  if not (valid_pair(pair) and pair.emergency_craft) then return false end
  local task = pair.emergency_craft

  if ready_to_craft(pair) then
    if _G.tech_priests_0507_action_claim then pcall(_G.tech_priests_0507_action_claim, pair, "timed-station-crafting", "crafting_executor", "ready_to_craft") end
    -- All materials are gathered. The visible ritual/craft must happen at the
    -- station, not out in the field beside the ore patch.
    if not at_station(pair) then
      task.station_craft_pending_0337 = true
      return move_to_station(pair, "materials-ready")
    end
    if not task.craft_due_tick and not task.build_due_tick then
      task.station_craft_started_tick_0337 = now()
      task.craft_started_tick_0337 = now()
      pair.mode = "emergency-crafting"
      draw_station_line(pair)
      draw_text(pair, progress_text(pair, task), 30)
      -- Let the legacy handler create craft_due_tick and perform its own state
      -- setup. We only guarded the location.
      return false
    end
  end

  if pair.mode == "emergency-crafting" and task.craft_due_tick then
    if not at_station(pair) then return move_to_station(pair, "craft-drift-correction") end
    draw_station_line(pair)
    if not task.next_progress_visual_0337 or now() >= task.next_progress_visual_0337 then
      task.next_progress_visual_0337 = now() + Craft.progress_refresh_ticks
      draw_text(pair, progress_text(pair, task), 26)
    end
  end
  return false
end

function Craft.after_legacy_finish(pair, result, pre_item)
  if result and pair and pre_item then print_success(pair, pre_item, 1) end
  return result
end

function Craft.wrap_legacy()
  local prev_handle = rawget(_G, "handle_emergency_desperation_craft")
  if type(prev_handle) == "function" and rawget(_G, "TECH_PRIESTS_0337_PRE_HANDLE_EMERGENCY_CRAFT") == nil then
    _G.TECH_PRIESTS_0337_PRE_HANDLE_EMERGENCY_CRAFT = prev_handle
    _G.handle_emergency_desperation_craft = function(pair)
      if Craft.before_legacy_handle(pair) then return true end
      return _G.TECH_PRIESTS_0337_PRE_HANDLE_EMERGENCY_CRAFT(pair)
    end
  end

  local prev_finish = rawget(_G, "finish_emergency_desperation_craft")
  if type(prev_finish) == "function" and rawget(_G, "TECH_PRIESTS_0337_PRE_FINISH_EMERGENCY_CRAFT") == nil then
    _G.TECH_PRIESTS_0337_PRE_FINISH_EMERGENCY_CRAFT = prev_finish
    _G.finish_emergency_desperation_craft = function(pair)
      local pre_item = pair and pair.emergency_craft and (pair.emergency_craft.output_item or pair.emergency_craft.item_name) or nil
      local result = _G.TECH_PRIESTS_0337_PRE_FINISH_EMERGENCY_CRAFT(pair)
      return Craft.after_legacy_finish(pair, result, pre_item)
    end
  end
end

function Craft.pulse()
  local root = ensure_root(); if root.enabled == false then return end
  for _, pair in pairs(pairs_by_station()) do
    if valid_pair(pair) and pair.emergency_craft then
      Craft.before_legacy_handle(pair)
    end
  end
end

function Craft.tune_timings()
  -- Make test feedback less glacial while preserving the staged feel.
  _G.EMERGENCY_CRAFT_WORK_TICKS = math.min(tonumber(_G.EMERGENCY_CRAFT_WORK_TICKS) or Craft.default_craft_ticks, Craft.default_craft_ticks)
  _G.EMERGENCY_CRAFT_SCAN_TICKS = math.min(tonumber(_G.EMERGENCY_CRAFT_SCAN_TICKS) or Craft.default_scan_ticks, Craft.default_scan_ticks)
  _G.EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS = math.min(tonumber(_G.EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS) or Craft.default_inventory_scan_ticks, Craft.default_inventory_scan_ticks)
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok then return pair end end
  return nil
end

function Craft.commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-craft-0337", "Tech Priests: station craft feedback status/kick/debug. Usage: /tp-craft-0337 status|kick|debug-on|debug-off|enable|disable", function(event)
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
      if p == "kick" and pair then acted = Craft.before_legacy_handle(pair) end
      local task = pair and pair.emergency_craft or nil
      player.print("[Tech Priests 0.1.337] station crafting enabled=" .. tostring(root.enabled) .. " debug_chat=" .. tostring(root.debug_chat) .. " selected-mode=" .. tostring(pair and pair.mode or "none") .. " ready=" .. tostring(pair and ready_to_craft(pair) or false) .. " item=" .. tostring(task and (task.output_item or task.item_name) or "none") .. " crafted=" .. tostring(root.stats.crafted or 0) .. " acted=" .. tostring(acted))
    end)
  end)
end

function Craft.install()
  ensure_root()
  if Craft.installed_0507 then return true end
  Craft.installed_0507 = true
  Craft.tune_timings()
  Craft.wrap_legacy()
  Craft.commands()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(17, Craft.pulse, { owner = "crafting_executor", category = "crafting", note = "single owned timed station crafting pulse", priority = "normal" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(17, Craft.pulse)
  end
  if log then log("[Tech-Priests 0.1.507] station-anchored crafting executor installed once via runtime registry") end
  return true
end

return Craft
