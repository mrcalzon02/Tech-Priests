-- scripts/core/acquisition_unstick.lua
-- Tech Priests 0.1.335 unstick layer for pairs that visibly have ammo/resource
-- needs but fall into idle/no-managed-priority-claimed without an active gather.

local Unstick = {}
Unstick.version = "0.1.336"
Unstick.storage_key = "acquisition_unstick_0336"
Unstick.retry_ticks = 90
Unstick.max_per_pulse = 16

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function pairs_by_station() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Unstick.storage_key] = storage.tech_priests[Unstick.storage_key] or { version = Unstick.version, enabled = true, stats = {} }
  local root = storage.tech_priests[Unstick.storage_key]
  root.version = Unstick.version
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end

local function read_task_item(task)
  if type(task) ~= "table" then return nil end
  return task.item or task.name or task.item_name or task.requested_item or task.resource or task.output_item or task.target_item
end

local function wanted_from_pair(pair)
  if not pair then return nil end
  local op = pair.independent_emergency_operation_0184
  if op then
    if op.last_item then return op.last_item end
    if op.acquisition and op.acquisition.item_name then return op.acquisition.item_name end
    if op.request and read_task_item(op.request) then return read_task_item(op.request) end
  end
  if pair.emergency_craft then
    if pair.emergency_craft.item_name then return pair.emergency_craft.item_name end
    if pair.emergency_craft.output_item then return pair.emergency_craft.output_item end
    if pair.emergency_craft.current and pair.emergency_craft.current.wanted_item then return pair.emergency_craft.current.wanted_item end
    if pair.emergency_craft.current and pair.emergency_craft.current.item_name then return pair.emergency_craft.current.item_name end
  end
  if pair.active_supply_request and read_task_item(pair.active_supply_request) then return read_task_item(pair.active_supply_request) end
  if pair.supply_request and read_task_item(pair.supply_request) then return read_task_item(pair.supply_request) end
  if pair.priest_task_0323 and read_task_item(pair.priest_task_0323) then return read_task_item(pair.priest_task_0323) end
  if pair.active_writ_0323 and read_task_item(pair.active_writ_0323) then return read_task_item(pair.active_writ_0323) end
  if pair.current_writ and read_task_item(pair.current_writ) then return read_task_item(pair.current_writ) end
  if pair.active_task and read_task_item(pair.active_task) then return read_task_item(pair.active_task) end
  if pair.active_task_0285 and read_task_item(pair.active_task_0285) then return read_task_item(pair.active_task_0285) end
  if pair.last_item then return pair.last_item end
  if pair.last_requested_supply_item_0173 then return pair.last_requested_supply_item_0173 end
  local mode = tostring(pair.mode or "") .. " " .. tostring(pair.phase or "") .. " " .. tostring(pair.blocker or "")
  if mode:find("ammo", 1, true) or mode:find("no%-ammo") or mode:find("firearm%-magazine") then return "firearm-magazine" end
  if mode:find("no%-managed%-priority%-claimed") then return "firearm-magazine" end
  return nil
end

local function station_count(pair, item)
  if not (valid_pair(pair) and item and pair.station.get_inventory) then return 0 end
  local inv = nil
  pcall(function() inv = pair.station.get_inventory(defines.inventory.chest) or pair.station.get_inventory(defines.inventory.assembling_machine_input) end)
  if inv and inv.valid then local ok, n = pcall(function() return inv.get_item_count(item) end); if ok then return n or 0 end end
  return 0
end

local function priest_count(pair, item)
  -- 0.1.357 station-bound inventory doctrine: priest inventory is transient
  -- cargo only. Flush it if possible, but do not count it as satisfying work.
  if _G.tech_priests_inventory_steward_unload then pcall(_G.tech_priests_inventory_steward_unload, pair, "acquisition-unstick-count") end
  return 0
end

local function needs_work(pair)
  if not valid_pair(pair) then return false end
  local mode = tostring(pair.mode or "")
  if pair.emergency_craft and pair.emergency_craft.current and pair.emergency_craft.current.entity and valid(pair.emergency_craft.current.entity) then return false end
  if mode == "moving-to-scavenge" or mode == "emergency-gathering" or mode == "mining" or mode == "crafting" or mode == "combat" or mode == "defending" then return false end
  if mode == "idle" or mode == "" or mode == "logistics" or mode == "missing-ammo-supplies" or mode == "pinned-no-ammo" or mode == "independent-emergency-operation" or mode == "no-managed-priority-claimed" then return true end
  if mode:find("no%-managed%-priority%-claimed") or mode:find("ammo") or mode:find("logistics") then return true end
  return false
end

local function call_repair(pair, wanted, reason)
  local ok, Repair = pcall(require, "scripts.core.acquisition_repair")
  if ok and Repair and Repair.force_direct_gather then return Repair.force_direct_gather(pair, wanted, reason) end
  return false
end

function Unstick.pulse(reason)
  local root = ensure_root(); if root.enabled == false then return end
  local processed = 0
  for _, pair in pairs(pairs_by_station()) do
    if valid_pair(pair) and needs_work(pair) and ((pair.next_acquisition_unstick_tick_0335 or 0) <= now()) then
      local wanted = wanted_from_pair(pair) or "firearm-magazine"
      -- If the requested final item is already present, leave legacy delivery code alone.
      if station_count(pair, wanted) + priest_count(pair, wanted) <= 0 then
        pair.next_acquisition_unstick_tick_0335 = now() + Unstick.retry_ticks
        local did = call_repair(pair, wanted, reason or "unstick-pulse")
        root.stats.pulses = (root.stats.pulses or 0) + 1
        if did then root.stats.started = (root.stats.started or 0) + 1 else root.stats.failed = (root.stats.failed or 0) + 1 end
        processed = processed + 1
        if processed >= Unstick.max_per_pulse then return end
      end
    end
  end
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok then return pair end end
  local selected = player and player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  return nil
end

function Unstick.commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-unstick-0335", "Tech Priests: acquisition unstick status/kick/all.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      if p == "all" then Unstick.pulse("manual-all") end
      local pair = selected_pair(player)
      if p == "kick" and pair then call_repair(pair, wanted_from_pair(pair) or "firearm-magazine", "manual-kick-0335") end
      player.print("[Tech Priests 0.1.336] acquisition unstick enabled=" .. tostring(root.enabled) .. " pulses=" .. tostring(root.stats.pulses or 0) .. " started=" .. tostring(root.stats.started or 0) .. " failed=" .. tostring(root.stats.failed or 0) .. " selected-mode=" .. tostring(pair and pair.mode or "none") .. " selected-wanted=" .. tostring(pair and wanted_from_pair(pair) or "none"))
    end)
  end)
end

function Unstick.install()
  ensure_root()
  if Unstick.installed_0507 then return true end
  Unstick.installed_0507 = true
  Unstick.commands()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(120, function() Unstick.pulse("nth-tick-120-acquisition-unstick-owned-0507") end, { owner = "acquisition_unstick", category = "acquisition", note = "single owned acquisition unstick watchdog", priority = "normal" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(120, function() Unstick.pulse("nth-tick-120") end)
  end
  if log then log("[Tech-Priests 0.1.507] acquisition unstick watchdog installed once via runtime registry") end
  return true
end

return Unstick
