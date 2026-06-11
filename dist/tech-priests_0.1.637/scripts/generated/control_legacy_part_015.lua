-- Auto-split control.lua fragment 015 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_0264_pair_label(pair)
  local s = pair and pair.station
  local p = pair and pair.priest
  return tostring(s and s.valid and (s.name .. "#" .. tostring(s.unit_number)) or "station=nil") .. "/" .. tostring(p and p.valid and p.name or "priest=nil")
end

function tech_priests_0264_get_op(pair)
  if not pair then return nil end
  local op = nil
  if tech_priests_get_emergency_operation_0184 then
    local ok, got = pcall(function() return tech_priests_get_emergency_operation_0184(pair) end)
    if ok then op = got end
  end
  if not op then op = pair.independent_emergency_operation_0184 end
  return op
end

function tech_priests_0264_probe_priority(pair)
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(pair) end)
    if ok and probe then return probe.priority or "unknown", probe end
  end
  return "unknown", nil
end

function tech_priests_0264_priority_blocks_emergency(priority)
  return priority == "attack" or priority == "hostile" or priority == "repair" or priority == "repair-wait" or priority == "repair-missing-supplies" or priority == "sanctify" or priority == "sanctify-wait" or priority == "sanctify-missing-supplies"
end

function tech_priests_0264_emergency_summary(pair)
  local op = tech_priests_0264_get_op(pair)
  local priority, probe = tech_priests_0264_probe_priority(pair)
  local bits = {
    tech_priests_0264_pair_label(pair),
    "mode=" .. tostring(pair and pair.mode or "nil"),
    "emergency=" .. tostring(op and op.enabled or false),
    "reason=" .. tostring(op and op.reason or "nil"),
    "phase=" .. tostring(op and op.phase or "nil"),
    "last_item=" .. tostring(op and (op.last_item or op.science_item or op.magos_planner_item_0255) or "nil"),
    "blocker=" .. tostring(op and op.last_blocker_0264 or "nil"),
    "priority=" .. tostring(priority),
    "probe_reason=" .. tostring(probe and probe.reason or "nil"),
    "construction=" .. tostring(op and op.construction and (op.construction.item_name or op.construction.item or "active") or "nil"),
    "craft=" .. tostring(pair and pair.emergency_craft and (pair.emergency_craft.item_name or pair.emergency_craft.item or "active") or "nil"),
    "scavenge=" .. tostring(pair and pair.scavenge and (pair.scavenge.item_name or pair.scavenge.item or "active") or "nil")
  }
  return table.concat(bits, " ")
end

if tick_pair and not TECH_PRIESTS_TICK_PAIR_BEFORE_EMERGENCY_ARBITER_0264 then
  TECH_PRIESTS_TICK_PAIR_BEFORE_EMERGENCY_ARBITER_0264 = tick_pair
  function tick_pair(pair)
    local op = tech_priests_0264_get_op(pair)
    if op and op.enabled and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid then
      local priority, probe = tech_priests_0264_probe_priority(pair)
      if tech_priests_0264_priority_blocks_emergency(priority) then
        op.last_blocker_0264 = "higher-priority=" .. tostring(priority)
        return TECH_PRIESTS_TICK_PAIR_BEFORE_EMERGENCY_ARBITER_0264(pair)
      end

      op.last_blocker_0264 = nil
      local ok, did = pcall(function()
        if tech_priests_service_independent_emergency_operation_0184 then
          return tech_priests_service_independent_emergency_operation_0184(pair)
        end
        return false
      end)
      if ok and did then
        pair.last_emergency_service_tick_0264 = game.tick
        pair.mode = pair.mode == "idle" and "independent-emergency-operation" or pair.mode
        return true
      end

      if not ok then
        op.last_blocker_0264 = "service-error=" .. tostring(did)
        tech_priests_0264_log("emergency service error: " .. tech_priests_0264_emergency_summary(pair), true)
      else
        op.last_blocker_0264 = "service-returned-false"
      end

      -- Emergency mode must not silently fall through into ordinary idle.  If no
      -- higher-priority work exists, hold the priest in emergency-operation mode
      -- and emit a clear blocker line rather than letting idle hide the failure.
      pair.mode = "independent-emergency-operation"
      pair.target = nil
      if game.tick >= (op.next_diag_tick_0264 or 0) then
        op.next_diag_tick_0264 = game.tick + 300
        tech_priests_0264_log("emergency hold: " .. tech_priests_0264_emergency_summary(pair), true)
        if tech_priests_draw_emergency_operation_status_0184 then
          pcall(function() tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-alert] emergency doctrine active; " .. tostring(op.last_blocker_0264)) end)
        end
      end
      return true
    end
    return TECH_PRIESTS_TICK_PAIR_BEFORE_EMERGENCY_ARBITER_0264(pair)
  end
end

function tech_priests_0264_find_pair_for_player(player)
  if not (player and player.valid) then return nil end
  if tech_priests_find_pair_for_player_selection_0184 then
    local ok, pair = pcall(function() return tech_priests_find_pair_for_player_selection_0184(player) end)
    if ok and pair then return pair end
  end
  if player.selected and player.selected.valid then
    if find_pair_by_entity then
      local ok, pair = pcall(function() return find_pair_by_entity(player.selected) end)
      if ok and pair then return pair end
    end
    if get_pair_by_station then
      local ok, pair = pcall(function() return get_pair_by_station(player.selected) end)
      if ok and pair then return pair end
    end
  end
  return nil
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-force-emergency", "Tech Priests: force-enable Independent / Emergency doctrine on the selected Cogitator Station or priest.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_0264_find_pair_for_player(player)
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local ok = false
      if tech_priests_set_emergency_operation_0184 then ok = tech_priests_set_emergency_operation_0184(pair, true, "force-command") end
      local op = tech_priests_0264_get_op(pair)
      player.print("[Tech Priests " .. tech_priests_0264_mod_version() .. "] force emergency=" .. tostring(ok) .. " :: " .. tech_priests_0264_emergency_summary(pair))
      tech_priests_0264_log("/tp-force-emergency :: " .. tech_priests_0264_emergency_summary(pair), true)
    end)
  end)
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-emergency-status", "Tech Priests: report current Independent / Emergency doctrine state for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_0264_find_pair_for_player(player)
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local line = tech_priests_0264_emergency_summary(pair)
      player.print("[Tech Priests " .. tech_priests_0264_mod_version() .. "] " .. line)
      tech_priests_0264_log("/tp-emergency-status :: " .. line, true)
    end)
  end)
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-write-emergency-log", "Tech Priests: write all current emergency pair states to script-output.", function(event)
      local player = game.get_player(event.player_index)
      local count = 0
      if storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
        for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
          tech_priests_0264_log("manual dump: " .. tech_priests_0264_emergency_summary(pair), true)
          count = count + 1
        end
      end
      if player then player.print("[Tech Priests " .. tech_priests_0264_mod_version() .. "] wrote emergency diagnostics for " .. tostring(count) .. " pairs to script-output/" .. TECH_PRIESTS_EMERGENCY_DIAG_FILE_0264) end
    end)
  end)
end

TechPriestsRuntimeEventRegistry.on_nth_tick(613, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local active = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    local op = tech_priests_0264_get_op(pair)
    if op and op.enabled then
      active = active + 1
      tech_priests_0264_log("heartbeat: " .. tech_priests_0264_emergency_summary(pair), true)
    end
  end
  if active == 0 then
    tech_priests_0264_log("heartbeat: no active emergency operations; pairs=" .. tostring(table_size and table_size(storage.tech_priests.pairs_by_station or {}) or "unknown"), true)
  end
end)

tech_priests_0264_log("0.1.264 emergency arbiter loaded; script-output diagnostics enabled", true)



-- 0.1.266 Survival bootstrap, visible task glyphs, starter supply repair, and station slot doctrine.
-- This is deliberately appended as a final doctrine layer.  It does not replace
-- older emergency logic; it ensures empty stations are treated as short on the
-- survival basics before the Magos starts pretending the absence of inventory is
-- a valid steady state.
TECH_PRIESTS_VERSION_0266 = "0.1.266"
TECH_PRIESTS_STATUS_RENDER_TTL_0266 = 150
TECH_PRIESTS_STATUS_RENDER_INTERVAL_0266 = 60
TECH_PRIESTS_SURVIVAL_BOOTSTRAP_RETRY_TICKS_0266 = 60 * 2
TECH_PRIESTS_SURVIVAL_AMMO_COUNT_0266 = 10
TECH_PRIESTS_SURVIVAL_REPAIR_COUNT_0266 = 2
TECH_PRIESTS_SURVIVAL_OIL_COUNT_0266 = 1

function tech_priests_0266_log(message)
  local line = "[Tech-Priests " .. TECH_PRIESTS_VERSION_0266 .. "][tick " .. tostring(game and game.tick or 0) .. "] " .. tostring(message)
  if log then pcall(function() log(line) end) end
  if tech_priests_0264_log then pcall(function() tech_priests_0264_log(line, true) end) end
end

function tech_priests_0266_get_op(pair)
  if tech_priests_0264_get_op then
    local ok, op = pcall(function() return tech_priests_0264_get_op(pair) end)
    if ok and op then return op end
  end
  if tech_priests_get_emergency_operation_0184 then
    local ok, op = pcall(function() return tech_priests_get_emergency_operation_0184(pair) end)
    if ok and op then return op end
  end
  return pair and pair.independent_emergency_operation_0184 or nil
end

function tech_priests_0266_get_station_inventory(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  if get_station_inventory then
    local ok, inv = pcall(function() return get_station_inventory(pair.station) end)
    if ok and inv and inv.valid then return inv end
  end
  if pair.station.get_inventory and defines and defines.inventory then
    local ids = { defines.inventory.chest, defines.inventory.container, defines.inventory.cargo_wagon }
    for _, id in pairs(ids) do
      if id then
        local ok, inv = pcall(function() return pair.station.get_inventory(id) end)
        if ok and inv and inv.valid then return inv end
      end
    end
  end
  return nil
end

function tech_priests_0266_item_exists(name)
  if not name then return false end
  if get_item_prototype then
    local ok, proto = pcall(function() return get_item_prototype(name) end)
    if ok and proto then return true end
  end
  if prototypes and prototypes.item then
    local ok, proto = pcall(function() return prototypes.item[name] end)
    if ok and proto then return true end
  end
  return false
end

function tech_priests_0266_get_ammo_name()
  if get_starting_bonus_ammo_name then
    local ok, ammo = pcall(get_starting_bonus_ammo_name)
    if ok and ammo and tech_priests_0266_item_exists(ammo) then return ammo end
  end
  for _, name in pairs({ "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine" }) do
    if tech_priests_0266_item_exists(name) then return name end
  end
  return nil
end

function tech_priests_0266_get_oil_name()
  if SACRED_OIL_NAME and tech_priests_0266_item_exists(SACRED_OIL_NAME) then return SACRED_OIL_NAME end
  if tech_priests_0266_item_exists("sacred-machine-oil") then return "sacred-machine-oil" end
  if tech_priests_0266_item_exists("tech-priests-sacred-machine-oil") then return "tech-priests-sacred-machine-oil" end
  return nil
end

function tech_priests_0266_required_survival_items()
  local result = {}
  local ammo = tech_priests_0266_get_ammo_name()
  if ammo then result[#result + 1] = { role = "ammo", item = ammo, count = TECH_PRIESTS_SURVIVAL_AMMO_COUNT_0266, icon = "[item=" .. ammo .. "]", label = "ammo" } end
  if tech_priests_0266_item_exists("repair-pack") then result[#result + 1] = { role = "repair", item = "repair-pack", count = TECH_PRIESTS_SURVIVAL_REPAIR_COUNT_0266, icon = "[item=repair-pack]", label = "repair packs" } end
  local oil = tech_priests_0266_get_oil_name()
  if oil then result[#result + 1] = { role = "consecration", item = oil, count = TECH_PRIESTS_SURVIVAL_OIL_COUNT_0266, icon = "[item=" .. oil .. "]", label = "sacred oil" } end
  return result
end

function tech_priests_0266_station_empty(pair)
  local inv = tech_priests_0266_get_station_inventory(pair)
  if not inv then return true end
  local ok, empty = pcall(function() return inv.is_empty() end)
  if ok then return empty end
  for _, req in pairs(tech_priests_0266_required_survival_items()) do
    if inv.get_item_count(req.item) > 0 then return false end
  end
  return true
end

function tech_priests_0266_next_survival_shortage(pair)
  local inv = tech_priests_0266_get_station_inventory(pair)
  for _, req in pairs(tech_priests_0266_required_survival_items()) do
    local have = inv and inv.get_item_count(req.item) or 0
    if have < math.max(1, req.count or 1) then
      req.have = have
      return req
    end
  end
  return nil
end

function tech_priests_0266_set_visible_objective(pair, item_name, role, assigner)
  if not pair then return end
  pair.visible_task_item_0266 = item_name
  pair.visible_task_role_0266 = role or pair.visible_task_role_0266
  pair.visible_task_assigner_0266 = assigner and true or false
  pair.visible_task_tick_0266 = game and game.tick or 0
end

function tech_priests_0266_render_pair_status(pair, text, color)
  if not (pair and pair.priest and pair.priest.valid and text) then return end
  if not (rendering and rendering.draw_text) then return end
  pcall(function()
    rendering.draw_text({
      text = text,
      target = { entity = pair.priest, offset = { 0, -2.55 } },
      surface = pair.priest.surface,
      color = color or { r = 1.0, g = 0.72, b = 0.18, a = 0.95 },
      scale = 0.72,
      alignment = "center",
      time_to_live = TECH_PRIESTS_STATUS_RENDER_TTL_0266
    })
  end)
end

function tech_priests_0266_assignment_status(pair)
  if not pair then return nil end
  local a = pair.worker_assignment_0252 or pair.emergency_assignment_0252 or pair.emergency_assist_job_0187
  if a and (a.item_name or a.item or a.target_item) then
    local item = a.item_name or a.item or a.target_item
    tech_priests_0266_set_visible_objective(pair, item, "assigned", false)
    return "⇣ [item=" .. item .. "] assigned"
  end
  local op = tech_priests_0266_get_op(pair)
  if op and op.requested_assignments_0252 then
    for _, req in pairs(op.requested_assignments_0252) do
      if req and req.item_name then
        tech_priests_0266_set_visible_objective(pair, req.item_name, "delegating", true)
        return "⇡ [item=" .. req.item_name .. "] delegating"
      end
    end
  end
  if pair.requested_assignments_0252 then
    for _, req in pairs(pair.requested_assignments_0252) do
      if req and req.item_name then
        tech_priests_0266_set_visible_objective(pair, req.item_name, "delegating", true)
        return "⇡ [item=" .. req.item_name .. "] delegating"
      end
    end
  end
  return nil
end

function tech_priests_0266_status_text(pair)
  if not pair then return "?" end
  local station = pair.station
  local priest = pair.priest
  local op = tech_priests_0266_get_op(pair)
  local astatus = tech_priests_0266_assignment_status(pair)
  if astatus then return astatus end

  if pair.combat_target or pair.mode == "attacking" or pair.mode == "combat" then return "⚔ combat" end
  if pair.mode == "ammo-scrounge" or pair.logistic_frustration_kind == "ammo" then return "[ammo] ammo" end
  if pair.repair_target or pair.mode == "repairing" or pair.mode == "moving-to-repair" then return "[item=repair-pack] repair" end
  if pair.consecration_target or pair.mode == "consecrating" or pair.mode == "moving-to-consecrate" then return "✚ sanctify" end
  if pair.scavenge then
    local item = pair.scavenge.item_name or pair.scavenge.name or (pair.scavenge.request and pair.scavenge.request.item_name)
    if item then return "⌕ [item=" .. item .. "] scavenge" end
    return "⌕ scavenge"
  end
  if pair.emergency_craft then
    local item = pair.emergency_craft.item_name or pair.emergency_craft.output_item or pair.emergency_craft.item
    if item then
      tech_priests_0266_set_visible_objective(pair, item, "crafting", false)
      return "⚙ [item=" .. item .. "] craft"
    end
    return "⚙ craft"
  end
  if op and op.enabled then
    if op.construction then
      local item = op.construction.item_name or op.construction.item or op.construction.entity_name
      if item then
        tech_priests_0266_set_visible_objective(pair, item, "constructing", false)
        return "▦ [item=" .. item .. "] build"
      end
      return "▦ build"
    end
    if op.last_item then
      tech_priests_0266_set_visible_objective(pair, op.last_item, tostring(op.phase or "emergency"), false)
      return "☼ [item=" .. op.last_item .. "] " .. tostring(op.phase or "emergency")
    end
    local shortage = tech_priests_0266_next_survival_shortage(pair)
    if shortage then return "☼ " .. shortage.icon .. " need " .. shortage.role end
    if op.science_item then return "⌬ [item=" .. op.science_item .. "] science" end
    return "☼ emergency survey"
  end
  if pair.visible_task_item_0266 and (game.tick - (pair.visible_task_tick_0266 or 0)) < 60 * 20 then
    return "· [item=" .. pair.visible_task_item_0266 .. "] " .. tostring(pair.visible_task_role_0266 or "task")
  end
  if pair.mode and pair.mode ~= "idle" then return tostring(pair.mode) end
  return "… idle"
end

function tech_priests_0266_service_survival_bootstrap(pair, op)
  if not (pair and pair.station and pair.station.valid and op and op.enabled) then return false end
  -- Empty does not mean stable.  An empty Cogitator Station is missing the three
  -- first-order survival categories: ammunition, repair capacity, and sacred oil.
  local shortage = tech_priests_0266_next_survival_shortage(pair)
  if not shortage then return false end
  if game.tick < (op.survival_next_tick_0266 or 0) then return true end
  op.survival_next_tick_0266 = game.tick + TECH_PRIESTS_SURVIVAL_BOOTSTRAP_RETRY_TICKS_0266
  op.phase = "survival-" .. tostring(shortage.role)
  op.last_item = shortage.item
  op.last_blocker_0266 = "station lacks " .. tostring(shortage.item) .. " (" .. tostring(shortage.have or 0) .. "/" .. tostring(shortage.count or 1) .. ")"
  pair.mode = "independent-emergency-operation"
  tech_priests_0266_set_visible_objective(pair, shortage.item, op.phase, false)
  if tech_priests_draw_emergency_operation_status_0184 then
    pcall(function() tech_priests_draw_emergency_operation_status_0184(pair, shortage.icon .. " survival bootstrap: " .. shortage.label) end)
  end
  if tech_priests_emergency_operation_acquire_item_0185 then
    local ok, result = pcall(function() return tech_priests_emergency_operation_acquire_item_0185(pair, shortage.item, op, shortage.count or 1, 0) end)
    if ok and result ~= nil then return result or true end
    if not ok then tech_priests_0266_log("survival acquire error for " .. tostring(shortage.item) .. ": " .. tostring(result)) end
  end
  return true
end

if tech_priests_service_independent_emergency_operation_0184 then
  TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0266 = tech_priests_service_independent_emergency_operation_0184
  function tech_priests_service_independent_emergency_operation_0184(pair)
    local op = tech_priests_0266_get_op(pair)
    if op and op.enabled then
      if tech_priests_0266_service_survival_bootstrap(pair, op) then return true end
    end
    return TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0266(pair)
  end
end

-- Starting inventory repair: the old helper only granted the practical repair/oil/ammo
-- bundle during multiplayer.  The mod testing loop needs those supplies in single-player
-- too, and future saves should re-check the grant queue without destroying anything.
if grant_tech_priest_first_spawn_bonus then
  TECH_PRIESTS_ORIGINAL_GRANT_FIRST_SPAWN_BONUS_0266 = grant_tech_priest_first_spawn_bonus
  function grant_tech_priest_first_spawn_bonus(player)
    if not (player and player.valid) then return false end
    ensure_storage()
    local player_index = player.index
    local already = storage.tech_priests.starting_bonus_granted_by_player_index and storage.tech_priests.starting_bonus_granted_by_player_index[player_index]
    local result = TECH_PRIESTS_ORIGINAL_GRANT_FIRST_SPAWN_BONUS_0266(player)
    -- If the old grant already happened before this patch, do not hand out another
    -- station automatically, but do repair the missing practical kit once.
    storage.tech_priests.starting_field_kit_granted_0266 = storage.tech_priests.starting_field_kit_granted_0266 or {}
    if not storage.tech_priests.starting_field_kit_granted_0266[player_index] then
      if safe_insert_into_player_inventory then
        pcall(function() safe_insert_into_player_inventory(player, { name = "repair-pack", count = STARTING_BONUS_MULTIPLAYER_REPAIR_PACKS or 10 }) end)
        local oil = tech_priests_0266_get_oil_name()
        if oil then pcall(function() safe_insert_into_player_inventory(player, { name = oil, count = STARTING_BONUS_MULTIPLAYER_SACRED_OIL or 10 }) end) end
        local ammo = tech_priests_0266_get_ammo_name()
        if ammo then
          local count = 100
          if get_item_prototype then
            local ok, proto = pcall(function() return get_item_prototype(ammo) end)
            if ok and proto and proto.stack_size then count = math.max(1, proto.stack_size) end
          end
          pcall(function() safe_insert_into_player_inventory(player, { name = ammo, count = count }) end)
        end
      end
      storage.tech_priests.starting_field_kit_granted_0266[player_index] = true
    end
    return result
  end
end

function tech_priests_0266_seed_existing_players()
  if not game or not game.players then return end
  ensure_storage()
  storage.tech_priests.starting_field_kit_granted_0266 = storage.tech_priests.starting_field_kit_granted_0266 or {}
  for _, player in pairs(game.players) do
    if player and player.valid and player.connected then
      if not storage.tech_priests.starting_field_kit_granted_0266[player.index] then
        pcall(function() grant_tech_priest_first_spawn_bonus(player) end)
      end
    end
  end
end

pcall(function()
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then pcall(function() grant_tech_priest_first_spawn_bonus(player) end) end
  end)
end)
pcall(function()
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if player then pcall(function() grant_tech_priest_first_spawn_bonus(player) end) end
  end)
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-survival-status", "Tech Priests: show survival bootstrap needs and visible status for the selected station/priest.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_0264_find_pair_for_player and tech_priests_0264_find_pair_for_player(player) or nil
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local op = tech_priests_0266_get_op(pair)
      local shortage = tech_priests_0266_next_survival_shortage(pair)
      local text = tech_priests_0266_status_text(pair)
      player.print("[Tech Priests " .. TECH_PRIESTS_VERSION_0266 .. "] status=" .. tostring(text) .. " emergency=" .. tostring(op and op.enabled or false) .. " shortage=" .. tostring(shortage and shortage.item or "none"))
    end)
  end)
end

TechPriestsRuntimeEventRegistry.on_nth_tick(613, function()
  tech_priests_0266_seed_existing_players()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local active = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    local op = tech_priests_0266_get_op(pair)
    if op and op.enabled then
      active = active + 1
      if tech_priests_0264_emergency_summary and tech_priests_0264_log then
        pcall(function() tech_priests_0264_log("heartbeat: " .. tech_priests_0264_emergency_summary(pair), true) end)
      end
    end
    local text = tech_priests_0266_status_text(pair)
    tech_priests_0266_render_pair_status(pair, text)
  end
  if active == 0 and tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("heartbeat: no active emergency operations; pairs=" .. tostring(table_size and table_size(storage.tech_priests.pairs_by_station or {}) or "unknown"), true) end)
  end
end)
TechPriestsRuntimeEventRegistry.on_nth_tick(61, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.priest and pair.priest.valid then
      tech_priests_0266_render_pair_status(pair, tech_priests_0266_status_text(pair))
    end
  end
end)

tech_priests_0266_log("survival bootstrap + expanded overhead task status loaded")


-- 0.1.267 Emergency survey escape + five-second bootstrap cadence.
-- 0.1.266 proved the UI flag could be true while every pair stayed in
-- phase=survey with last_item=nil. The cause was that survival item discovery
-- could return an empty requirement list under Factorio 2 prototype shapes, so
-- emergency doctrine saw no shortage and therefore had no first action. This
-- patch makes the survival seed deterministic and forces emergency survey to
-- become a concrete ammo/repair/oil acquisition objective within five seconds.
TECH_PRIESTS_VERSION_0267 = "0.1.267"
TECH_PRIESTS_SURVIVAL_BOOTSTRAP_RETRY_TICKS_0266 = 60 * 5
TECH_PRIESTS_EMERGENCY_SURVEY_MAX_TICKS_0267 = 60 * 5

function tech_priests_0267_safe_proto_lookup(category, name)
  if not (category and name and prototypes) then return nil end
  local ok, bucket = pcall(function() return prototypes[category] end)
  if ok and bucket then
    local ok2, proto = pcall(function() return bucket[name] end)
    if ok2 and proto then return proto end
  end
  return nil
end

function tech_priests_0267_item_exists(name)
  if not name then return false end
  if get_item_prototype then
    local ok, proto = pcall(function() return get_item_prototype(name) end)
    if ok and proto then return true end
  end
  for _, category in pairs({
    "item", "ammo", "tool", "repair-tool", "selection-tool", "capsule",
    "gun", "armor", "module", "item-with-entity-data", "item-with-tags",
    "rail-planner", "space-platform-starter-pack"
  }) do
    if tech_priests_0267_safe_proto_lookup(category, name) then return true end
  end
  -- Known survival items in this mod/vanilla set. These are allowed as a final
  -- fallback so a missing runtime prototype bucket does not make the emergency
  -- planner believe it needs nothing.
  if name == "firearm-magazine" or name == "piercing-rounds-magazine" or name == "uranium-rounds-magazine" then return true end
  if name == "repair-pack" then return true end
  if name == "sacred-machine-oil" or name == "tech-priests-sacred-machine-oil" then return true end
  return false
end

tech_priests_0266_item_exists = tech_priests_0267_item_exists

function tech_priests_0266_get_ammo_name()
  if get_starting_bonus_ammo_name then
    local ok, ammo = pcall(get_starting_bonus_ammo_name)
    if ok and ammo and tech_priests_0267_item_exists(ammo) then return ammo end
  end
  for _, name in pairs({ "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine" }) do
    if tech_priests_0267_item_exists(name) then return name end
  end
  return "firearm-magazine"
end

function tech_priests_0266_get_oil_name()
  if SACRED_OIL_NAME and tech_priests_0267_item_exists(SACRED_OIL_NAME) then return SACRED_OIL_NAME end
  if tech_priests_0267_item_exists("sacred-machine-oil") then return "sacred-machine-oil" end
  if tech_priests_0267_item_exists("tech-priests-sacred-machine-oil") then return "tech-priests-sacred-machine-oil" end
  return "sacred-machine-oil"
end

function tech_priests_0266_required_survival_items()
  local ammo = tech_priests_0266_get_ammo_name() or "firearm-magazine"
  local oil = tech_priests_0266_get_oil_name() or "sacred-machine-oil"
  return {
    { role = "ammo", item = ammo, count = TECH_PRIESTS_SURVIVAL_AMMO_COUNT_0266 or 10, icon = "[item=" .. ammo .. "]", label = "ammo" },
    { role = "repair", item = "repair-pack", count = TECH_PRIESTS_SURVIVAL_REPAIR_COUNT_0266 or 2, icon = "[item=repair-pack]", label = "repair packs" },
    { role = "consecration", item = oil, count = TECH_PRIESTS_SURVIVAL_OIL_COUNT_0266 or 1, icon = "[item=" .. oil .. "]", label = "sacred oil" }
  }
end

function tech_priests_0266_next_survival_shortage(pair)
  local inv = tech_priests_0266_get_station_inventory and tech_priests_0266_get_station_inventory(pair) or nil
  for _, req in pairs(tech_priests_0266_required_survival_items()) do
    local have = 0
    if inv and req.item then
      local ok, count = pcall(function() return inv.get_item_count(req.item) end)
      if ok and count then have = count end
    end
    if have < math.max(1, req.count or 1) then
      req.have = have
      return req
    end
  end
  return nil
end

function tech_priests_0267_mark_bootstrap_shortage(pair, op, shortage, why)
  if not (pair and op and shortage) then return end
  op.phase = "survival-" .. tostring(shortage.role or "unknown")
  op.last_item = shortage.item
  op.last_blocker_0264 = why or ("station lacks " .. tostring(shortage.item))
  op.last_blocker_0266 = op.last_blocker_0264
  op.last_blocker_0267 = op.last_blocker_0264
  pair.mode = "independent-emergency-operation"
  if tech_priests_0266_set_visible_objective then
    pcall(function() tech_priests_0266_set_visible_objective(pair, shortage.item, op.phase, false) end)
  end
  if tech_priests_draw_emergency_operation_status_0184 then
    pcall(function() tech_priests_draw_emergency_operation_status_0184(pair, tostring(shortage.icon or "[virtual-signal=signal-alert]") .. " need " .. tostring(shortage.role or shortage.item)) end)
  end
end

if tech_priests_0266_service_survival_bootstrap then
  TECH_PRIESTS_ORIGINAL_SERVICE_SURVIVAL_BOOTSTRAP_0267 = tech_priests_0266_service_survival_bootstrap
  function tech_priests_0266_service_survival_bootstrap(pair, op)
    if not (pair and pair.station and pair.station.valid and op and op.enabled) then return false end
    local shortage = tech_priests_0266_next_survival_shortage(pair)
    if not shortage then return false end
    tech_priests_0267_mark_bootstrap_shortage(pair, op, shortage, "station lacks " .. tostring(shortage.item) .. " (" .. tostring(shortage.have or 0) .. "/" .. tostring(shortage.count or 1) .. ")")
    if game.tick < (op.survival_next_tick_0267 or 0) then return true end
    op.survival_next_tick_0267 = game.tick + TECH_PRIESTS_SURVIVAL_BOOTSTRAP_RETRY_TICKS_0266
    -- Keep the older field updated too so older helpers do not run at a different cadence.
    op.survival_next_tick_0266 = op.survival_next_tick_0267
    if tech_priests_emergency_operation_acquire_item_0185 then
      local ok, result = pcall(function() return tech_priests_emergency_operation_acquire_item_0185(pair, shortage.item, op, shortage.count or 1, 0) end)
      if ok then return result or true end
      op.last_blocker_0264 = "survival acquire error: " .. tostring(result)
      if tech_priests_0264_log then pcall(function() tech_priests_0264_log("survival acquire error for " .. tostring(shortage.item) .. ": " .. tostring(result), true) end) end
      return true
    end
    op.last_blocker_0264 = "no emergency acquisition function available"
    return true
  end
end

-- Force the transition out of inert survey even if the older tick_pair wrapper is
-- not the path currently servicing this save. This is deliberately small and
-- only runs for enabled emergency operations without higher-priority work.
TechPriestsRuntimeEventRegistry.on_nth_tick(300, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    local op = tech_priests_0266_get_op and tech_priests_0266_get_op(pair) or (tech_priests_0264_get_op and tech_priests_0264_get_op(pair))
    if op and op.enabled then
      local priority = "idle"
      if tech_priests_0264_probe_priority then
        local ok, p = pcall(function() return tech_priests_0264_probe_priority(pair) end)
        if ok and p then priority = p end
      end
      if not (tech_priests_0264_priority_blocks_emergency and tech_priests_0264_priority_blocks_emergency(priority)) then
        local shortage = tech_priests_0266_next_survival_shortage(pair)
        if shortage then
          tech_priests_0267_mark_bootstrap_shortage(pair, op, shortage, "five-second survey escape: station lacks " .. tostring(shortage.item))
          pcall(function() tech_priests_0266_service_survival_bootstrap(pair, op) end)
        elseif (op.phase == nil or op.phase == "survey") then
          op.phase = "science-objective"
          op.science_item = (tech_priests_get_next_science_objective_0184 and tech_priests_get_next_science_objective_0184(pair, op)) or "automation-science-pack"
          op.last_item = op.science_item
          pair.mode = "independent-emergency-operation"
        end
      end
    end
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-bootstrap-now", "Tech Priests: force one emergency bootstrap evaluation on the selected station/priest.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_0264_find_pair_for_player and tech_priests_0264_find_pair_for_player(player) or nil
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local op = tech_priests_0266_get_op and tech_priests_0266_get_op(pair) or nil
      if not (op and op.enabled) and tech_priests_set_emergency_operation_0184 then
        tech_priests_set_emergency_operation_0184(pair, true, "bootstrap-now")
        op = tech_priests_0266_get_op and tech_priests_0266_get_op(pair) or nil
      end
      if op then op.survival_next_tick_0267 = 0; op.survival_next_tick_0266 = 0 end
      local shortage = tech_priests_0266_next_survival_shortage(pair)
      if shortage and op then tech_priests_0267_mark_bootstrap_shortage(pair, op, shortage, "manual bootstrap-now") end
      if op then pcall(function() tech_priests_0266_service_survival_bootstrap(pair, op) end) end
      player.print("[Tech Priests " .. TECH_PRIESTS_VERSION_0267 .. "] bootstrap evaluated; shortage=" .. tostring(shortage and shortage.item or "none") .. " phase=" .. tostring(op and op.phase or "nil") .. " last_item=" .. tostring(op and op.last_item or "nil"))
    end)
  end)
end

if tech_priests_0264_log then
  pcall(function() tech_priests_0264_log("0.1.267 five-second survey escape + robust survival item discovery loaded", true) end)
else
  log("[Tech-Priests 0.1.267] five-second survey escape + robust survival item discovery loaded")
end


-- 0.1.268 Fast debug timers + assignment movement service repair.
-- The 0.1.267 logs show ranked assignment succeeds, but the Junior worker can
-- sit in emergency-gathering with pair.emergency_craft present while the
-- assignment retry gate returns early.  This patch services active worker
-- movement/craft state before waiting on assignment retry ticks, and clamps
-- mining/waiting/logistics timers to one second for debug observation.
TECH_PRIESTS_VERSION_0268 = "0.1.268"
TECH_PRIESTS_DEBUG_FAST_TIMER_TICKS_0268 = 60

function tech_priests_0268_apply_fast_debug_timers()
  local t = TECH_PRIESTS_DEBUG_FAST_TIMER_TICKS_0268 or 60
  -- Logistics / waiting / scavenge timers.
  LOGISTIC_REQUISITION_INTERVAL_TICKS = t
  LOGISTIC_FRUSTRATION_THRESHOLD_TICKS = t
  LOGISTIC_SCAVENGE_RETRY_TICKS = t
  LOGISTIC_CRAM_SEARCH_BEFORE_DUMP_TICKS = t
  LOGISTIC_INVENTORY_SCAN_TICKS = t
  LOGISTIC_NO_NETWORK_SCAVENGE_TICKS = t
  LOGISTIC_INVENTORY_APPROACH_TIMEOUT_TICKS = t
  LOGISTIC_TIMED_STATUS_REFRESH_TICKS = t
  LOGISTIC_TRASH_EXPORT_INTERVAL_TICKS = t

  -- Emergency gathering/crafting/mining observation timers.
  EMERGENCY_CRAFT_SCAN_TICKS = t
  EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS = t
  EMERGENCY_CRAFT_WORK_TICKS = t
  EMERGENCY_CRAFT_RETRY_TICKS = t
  EMERGENCY_CRAFT_VISUAL_PULSE_TICKS = math.min(15, t)
  TECH_PRIESTS_EMERGENCY_QUARRY_INTERVAL_TICKS = t

  -- Independent emergency operation timers.
  TECH_PRIESTS_EMERGENCY_OPERATION_TICK_SPACING_0184 = t
  TECH_PRIESTS_EMERGENCY_OPERATION_RETRY_TICKS_0184 = t
  TECH_PRIESTS_EMERGENCY_OPERATION_IDLE_FRUSTRATION_TICKS_0184 = t
  TECH_PRIESTS_EMERGENCY_OPERATION_LOGISTIC_WAIT_TICKS_0185 = t
  TECH_PRIESTS_EMERGENCY_OPERATION_ACQUIRE_RETRY_TICKS_0185 = t
  TECH_PRIESTS_SURVIVAL_BOOTSTRAP_RETRY_TICKS_0266 = t
  TECH_PRIESTS_EMERGENCY_SURVEY_MAX_TICKS_0267 = t

  -- Construction / planner / assignment timers.
  TECH_PRIESTS_EMERGENCY_CONSTRUCTION_TIMEOUT_TICKS_0186 = t * 5
  TECH_PRIESTS_EMERGENCY_CONSTRUCTION_BUILD_TICKS_0186 = t
  TECH_PRIESTS_EMERGENCY_CONSTRUCTION_REPATH_TICKS_0186 = t
  TECH_PRIESTS_TASK_FORCE_ASSIGNMENT_COOLDOWN_0187 = t
  TECH_PRIESTS_TASK_FORCE_ASSIGNMENT_COOLDOWN_0188 = t
  TECH_PRIESTS_ASSIGNMENT_RETRY_TICKS_0252 = t
  TECH_PRIESTS_ASSIGNMENT_TIMEOUT_TICKS_0252 = t * 20
  TECH_PRIESTS_MAGOS_PLANNER_RETRY_TICKS_0255 = t
end

tech_priests_0268_apply_fast_debug_timers()

function tech_priests_0268_log(message)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log(tostring(message), true) end)
  elseif log then
    log("[Tech-Priests 0.1.268] " .. tostring(message))
  end
end

function tech_priests_0268_emergency_craft_summary(pair)
  local task = pair and pair.emergency_craft or nil
  if not task then return "craft=nil" end
  local current = task.current or {}
  local ent = current.entity
  local target = ent and ent.valid and (tostring(ent.name) .. "#" .. tostring(ent.unit_number or "?")) or "none"
  local candidates = task.candidates and #task.candidates or 0
  return "craft=" .. tostring(task.item_name or task.output_item) ..
    " gathered=" .. tostring(task.gathered_units or 0) .. "/" .. tostring(task.recipe and task.recipe.units or "?") ..
    " index=" .. tostring(task.index or 1) .. "/" .. tostring(candidates) ..
    " current=" .. tostring(current.kind or "nil") .. ":" .. target ..
    " scan_due=" .. tostring(task.scan_due_tick) ..
    " craft_due=" .. tostring(task.craft_due_tick)
end

-- Assignment workers must keep moving/gathering even while their assignment retry
-- gate is cooling down.  The old 0.1.252 service checked assignment.next_tick
-- before servicing pair.emergency_craft, which allowed a worker to display
-- emergency-gathering but not receive fresh movement/scan commands.
if tech_priests_0252_service_assignment then
  TECH_PRIESTS_ORIGINAL_SERVICE_ASSIGNMENT_0268 = tech_priests_0252_service_assignment
  function tech_priests_0252_service_assignment(pair)
    -- Active craft/scavenge/construction states are real work.  Service them
    -- immediately, before any assignment cooldown wait.
    if pair and pair.emergency_craft and handle_emergency_desperation_craft then
      local ok, result = pcall(function() return handle_emergency_desperation_craft(pair) end)
      if not ok then
        tech_priests_0268_log("assignment worker craft error: " .. tostring(result))
        return true
      end
      if result then
        tech_priests_0268_log("assignment worker active: " .. tech_priests_0268_emergency_craft_summary(pair))
        return true
      end
    end
    if pair and pair.scavenge and handle_priest_scavenge_task then
      local ok, result = pcall(function() return handle_priest_scavenge_task(pair) end)
      if ok and result then return true end
    end
    local op = pair and pair.assignment_op_0252 or nil
    if op and op.construction and tech_priests_service_emergency_construction_0186 then
      local ok, result = pcall(function() return tech_priests_service_emergency_construction_0186(pair, op) end)
      if ok and result then return true end
    end
    return TECH_PRIESTS_ORIGINAL_SERVICE_ASSIGNMENT_0268(pair)
  end
end

-- Emergency operation itself gets the same active-work priority, so a worker or
-- requester cannot idle/wait while a craft/scavenge/construction subtask exists.
if tech_priests_service_independent_emergency_operation_0184 then
  TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0268 = tech_priests_service_independent_emergency_operation_0184
  function tech_priests_service_independent_emergency_operation_0184(pair)
    if pair and pair.emergency_craft and handle_emergency_desperation_craft then
      local ok, result = pcall(function() return handle_emergency_desperation_craft(pair) end)
      if ok and result then return true end
      if not ok then tech_priests_0268_log("emergency craft service error: " .. tostring(result)); return true end
    end
    if pair and pair.scavenge and handle_priest_scavenge_task then
      local ok, result = pcall(function() return handle_priest_scavenge_task(pair) end)
      if ok and result then return true end
    end
    return TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0268(pair)
  end
end

-- Small periodic movement/craft heartbeat while fast debug is active.  This is
-- intentionally sparse enough to read, but frequent enough to show why a priest
-- is not moving: no candidates, current target, distance, or due timer.
TechPriestsRuntimeEventRegistry.on_nth_tick(60, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.emergency_craft then
      local pos = pair.priest and pair.priest.valid and pair.priest.position or nil
      local current = pair.emergency_craft.current or {}
      local ent = current.entity
      local dist = "nil"
      if pos and ent and ent.valid then
        local dx = pos.x - ent.position.x
        local dy = pos.y - ent.position.y
        dist = string.format("%.2f", math.sqrt(dx * dx + dy * dy))
      end
      tech_priests_0268_log("fast-debug " .. tostring(pair.station and pair.station.name or "station") .. "#" .. tostring(pair.station and pair.station.unit_number or "?") .. " mode=" .. tostring(pair.mode) .. " dist=" .. tostring(dist) .. " " .. tech_priests_0268_emergency_craft_summary(pair))
    end
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-fast-debug-status", "Tech Priests: report fast debug timers and selected assignment/craft state.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_0264_find_pair_for_player and tech_priests_0264_find_pair_for_player(player) or (tech_priests_find_pair_for_player_selection_0184 and tech_priests_find_pair_for_player_selection_0184(player))
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      player.print("[Tech Priests] 0.1.268 fast debug timers active: logistics/mining/waiting ~= 60 ticks.")
      player.print("  mode=" .. tostring(pair.mode) .. " " .. tech_priests_0268_emergency_craft_summary(pair))
      if pair.assignment_0252 then
        player.print("  assignment #" .. tostring(pair.assignment_0252.id) .. " item=" .. tostring(pair.assignment_0252.item_name) .. " phase=" .. tostring(pair.assignment_0252.phase) .. " next=" .. tostring(pair.assignment_0252.next_tick))
      end
    end)
  end)
end

tech_priests_0268_log("0.1.268 fast debug timers + assignment movement service repair loaded")


-- 0.1.269 Emergency raw-resource fallback and dirt-scraping escape.
-- The 0.1.268 logs proved assignment, survival priority, and emergency-craft
-- state all wake up, but the Junior worker can sit in emergency-gathering with
-- current=nil even though the candidate list has entries.  This layer makes the
-- craft worker aggressively skip invalid candidates, rebuild the candidate list,
-- prefer exact raw resources, fall back to doubled substitute resource mining,
-- report "no resources here" upward, and finally perform bare-dirt scraping if
-- the same worker receives the same impossible raw-resource request again.

TECH_PRIESTS_VERSION_0269 = "0.1.269"
TECH_PRIESTS_DIRT_SCRAPE_TICKS_0269 = 60
TECH_PRIESTS_RAW_RESOURCE_NAMES_0269 = {
  ["iron-ore"] = true,
  ["copper-ore"] = true,
  ["coal"] = true,
  ["stone"] = true,
  ["uranium-ore"] = true,
  ["wood"] = true
}

function tech_priests_0269_log(message)
  local line = "[Tech-Priests 0.1.269][tick " .. tostring(game and game.tick or 0) .. "] " .. tostring(message)
  if log then log(line) end
  if helpers and helpers.write_file then
    pcall(function() helpers.write_file("tech-priests-emergency-diagnostics.log", line .. "\n", true) end)
  end
end

function tech_priests_0269_pos_key(pos)
  if not pos then return "nil" end
  return tostring(math.floor((pos.x or 0) * 10) / 10) .. "," .. tostring(math.floor((pos.y or 0) * 10) / 10)
end

function tech_priests_0269_is_raw_resource_name(name)
  if not name then return false end
  if TECH_PRIESTS_RAW_RESOURCE_NAMES_0269[name] then return true end
  if prototypes and prototypes.entity and prototypes.entity[name] then
    local ok, typ = pcall(function() return prototypes.entity[name].type end)
    if ok and typ == "resource" then return true end
  end
  return false
end

function tech_priests_0269_candidate_valid(candidate)
  if not candidate then return false, "nil-candidate" end
  if candidate.kind == "dirt" then return true end
  if not candidate.entity then return false, "nil-entity" end
  if not candidate.entity.valid then return false, "invalid-entity" end
  return true
end

function tech_priests_0269_find_resource_candidate(pair, requested_name, exact_only)
  if not (pair and pair.station and pair.station.valid) then return nil, "no-station" end
  local station = pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or 20
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local surface = station.surface

  -- Exact resource harvest comes first.  If the task wants iron ore and iron ore
  -- exists, do not play games with substitutes. Go mine the red-beam target.
  local filters = nil
  if requested_name == "wood" then
    filters = { area = area, type = "tree", limit = EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT or 128 }
  else
    filters = { area = area, type = "resource", name = requested_name, limit = EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT or 128 }
  end
  local ok_exact, exacts = pcall(function() return surface.find_entities_filtered(filters) end)
  if ok_exact then
    local best, best_dist = nil, nil
    for _, entity in pairs(exacts or {}) do
      if entity and entity.valid then
        local dx = entity.position.x - pos.x
        local dy = entity.position.y - pos.y
        local dist = dx * dx + dy * dy
        if dist <= radius * radius and (not best_dist or dist < best_dist) then
          best = entity; best_dist = dist
        end
      end
    end
    if best then
      return { kind = "resource", entity = best, item_name = requested_name, value = 999, station_distance_sq = best_dist or 0, unit_number = best.unit_number or 0, exact_resource_0269 = true }, "exact"
    end
  end

  if exact_only then return nil, "no-exact-resource" end

  -- Substitute resource fallback: harvest double the amount from random local
  -- resources rather than doing nothing.  Prefer actual resource patches, then
  -- trees as fuel/biomass substitutes.
  local ok_any, any_resources = pcall(function()
    return surface.find_entities_filtered({ area = area, type = {"resource", "tree"}, limit = EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT or 128 })
  end)
  if ok_any then
    local pool = {}
    for _, entity in pairs(any_resources or {}) do
      if entity and entity.valid then
        local item = entity.type == "tree" and "wood" or entity.name
        local dx = entity.position.x - pos.x
        local dy = entity.position.y - pos.y
        local dist = dx * dx + dy * dy
        if dist <= radius * radius then
          pool[#pool+1] = { kind = "resource", entity = entity, item_name = item, value = 1, station_distance_sq = dist, unit_number = entity.unit_number or 0, substitute_resource_0269 = true }
        end
      end
    end
    if #pool > 0 then
      table.sort(pool, function(a,b) return (a.station_distance_sq or 0) < (b.station_distance_sq or 0) end)
      return pool[1], "substitute"
    end
  end

  return nil, "no-resources-here"
end

function tech_priests_0269_assignment_note_no_resources(pair, resource_name)
  if not pair then return end
  pair.no_resources_here_0269 = pair.no_resources_here_0269 or {}
  pair.no_resources_here_0269[resource_name or "unknown"] = (pair.no_resources_here_0269[resource_name or "unknown"] or 0) + 1
  local count = pair.no_resources_here_0269[resource_name or "unknown"]
  local a = pair.assignment_0252 or pair.assignment_op_0252 or nil
  if pair.assignment_0252 then
    pair.assignment_0252.phase = "no-resources-here"
    pair.assignment_0252.note = "no resources here for " .. tostring(resource_name)
    pair.assignment_0252.updated_tick = game.tick
  end
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(pair, "no resources here: [item=" .. tostring(resource_name or "stone") .. "]")
  end
  tech_priests_0269_log("no-resources-here worker=" .. tostring(pair.station and pair.station.unit_number) .. " item=" .. tostring(resource_name) .. " count=" .. tostring(count))
  return count
end

function tech_priests_0269_begin_dirt_scrape(pair, task, resource_name)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and task) then return false end
  local station = pair.station
  local radius = math.min(8, refresh_pair_radius and refresh_pair_radius(pair) or 8)
  local angle = ((game.tick or 0) * 0.173) % 6.28318
  local dist = 2 + (((game.tick or 0) % 31) / 31) * math.max(1, radius - 2)
  local pos = { x = station.position.x + math.cos(angle) * dist, y = station.position.y + math.sin(angle) * dist }
  task.current = { kind = "dirt", item_name = "stone", value = 1, position = pos, dirt_resource_request_0269 = resource_name }
  task.dirt_due_tick_0269 = game.tick + TECH_PRIESTS_DIRT_SCRAPE_TICKS_0269
  pair.mode = "emergency-dirt-scraping"
  pair.target = nil
  if move_priest_to and pair.priest and pair.priest.valid then
    pcall(function()
      if tech_priests_request_movement_0418 then
        tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather", { radius = 0.75, owner = "direct-gather", priority = 55, distraction = defines.distraction.by_enemy })
      else
        pair.priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy })
      end
    end)
  end
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(pair, "scraping bare dirt for stone")
  end
  tech_priests_0269_log("dirt-scrape begin station=" .. tostring(station.unit_number) .. " requested=" .. tostring(resource_name) .. " at=" .. tech_priests_0269_pos_key(pos))
  return true
end

function tech_priests_0269_finish_dirt_scrape(pair, task)
  if not (pair and pair.station and pair.station.valid and task and task.current and task.current.kind == "dirt") then return false end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and inv.can_insert({ name = "stone", count = 1 }) then
    inv.insert({ name = "stone", count = 1 })
  else
    pcall(function()
      pair.station.surface.spill_item_stack({ position = pair.priest and pair.priest.valid and pair.priest.position or pair.station.position, stack = { name = "stone", count = 1 }, force = pair.station.force, allow_belts = false })
    end)
  end
  task.current = nil
  task.dirt_due_tick_0269 = nil
  pair.mode = "returning"
  tech_priests_0269_log("dirt-scrape complete station=" .. tostring(pair.station.unit_number) .. " yielded=stone")
  return_to_station(pair.priest, pair.station)
  -- Dirt stone is a consolation output, not proof that the original impossible
  -- raw-resource request was fulfilled.  Clear the craft and let the planner make
  -- a new decision with the newly acquired stone in the station.
  pair.emergency_craft = nil
  return true
end

if handle_emergency_desperation_craft then
  TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0269 = handle_emergency_desperation_craft
  function handle_emergency_desperation_craft(pair)
    if not (pair and pair.emergency_craft) then return false end
    local task = pair.emergency_craft
    local requested = task.output_item or (task.request and (task.request.item_name or task.request.target or task.request.name))

    -- Complete bare-dirt scraping if it is in progress.
    if task.current and task.current.kind == "dirt" then
      if game.tick < (task.dirt_due_tick_0269 or 0) then
        pair.mode = "emergency-dirt-scraping"
        return true
      end
      return tech_priests_0269_finish_dirt_scrape(pair, task)
    end

    -- If the candidate cursor points at nothing/invalid, skip aggressively rather
    -- than leaving the priest with current=nil forever.
    local candidates = task.candidates or {}
    local cursor = math.max(1, task.index or 1)
    while candidates[cursor] do
      local ok, why = tech_priests_0269_candidate_valid(candidates[cursor])
      if ok then break end
      tech_priests_0269_log("skip invalid emergency candidate station=" .. tostring(pair.station and pair.station.unit_number) .. " index=" .. tostring(cursor) .. " why=" .. tostring(why) .. " kind=" .. tostring(candidates[cursor] and candidates[cursor].kind))
      cursor = cursor + 1
    end
    task.index = cursor

    -- If every original candidate has gone stale, rebuild once immediately.
    if not candidates[task.index or 1] and build_emergency_craft_candidates and task.recipe then
      local rebuilt = build_emergency_craft_candidates(pair, task.recipe) or {}
      task.candidates = rebuilt
      task.index = 1
      task.current = nil
      candidates = rebuilt
      tech_priests_0269_log("rebuilt emergency candidates station=" .. tostring(pair.station and pair.station.unit_number) .. " output=" .. tostring(requested) .. " count=" .. tostring(#rebuilt))
    end

    -- Raw resource doctrine: exact resource first, substitute resources second at
    -- double burden, then no-resources-upchain, then bare dirt if the same worker
    -- is asked again after all options are exhausted.
    if (not (task.candidates or {})[task.index or 1]) and tech_priests_0269_is_raw_resource_name(requested) then
      local cand, mode = tech_priests_0269_find_resource_candidate(pair, requested, false)
      if cand then
        task.candidates = { cand }
        task.index = 1
        task.current = nil
        if mode == "substitute" and not task.substitute_doubled_0269 then
          task.recipe = task.recipe or {}
          task.recipe.units = math.max(1, (task.recipe.units or 1) * 2)
          task.substitute_doubled_0269 = true
          task.blocker_0269 = "using substitute resource at double burden"
        end
        tech_priests_0269_log("raw fallback candidate station=" .. tostring(pair.station and pair.station.unit_number) .. " requested=" .. tostring(requested) .. " mode=" .. tostring(mode) .. " item=" .. tostring(cand.item_name) .. " pos=" .. tech_priests_0269_pos_key(cand.entity and cand.entity.position))
      else
        local count = tech_priests_0269_assignment_note_no_resources(pair, requested)
        if count and count >= 2 then
          return tech_priests_0269_begin_dirt_scrape(pair, task, requested)
        end
        if tech_priests_0252_clear_assignment and pair.assignment_0252 then
          tech_priests_0252_clear_assignment(pair.assignment_0252, "failed", "no resources here for " .. tostring(requested))
        end
        pair.emergency_craft = nil
        pair.mode = "returning"
        return_to_station(pair.priest, pair.station)
        return true
      end
    end

    local ok, result = pcall(TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0269, pair)
    if not ok then
      tech_priests_0269_log("emergency craft handler error: " .. tostring(result))
      pair.emergency_craft = nil
      pair.mode = "returning"
      return_to_station(pair.priest, pair.station)
      return true
    end
    return result
  end
end

if commands then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-raw-fallback-debug", "Tech Priests: report raw fallback / dirt scraping counters for selected pair.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_get_selected_pair_0247 and tech_priests_get_selected_pair_0247(player) or nil
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest."); return end
      local task = pair.emergency_craft
      player.print("[Tech Priests 0.1.269] raw fallback debug station=" .. tostring(pair.station and pair.station.unit_number) .. " mode=" .. tostring(pair.mode))
      if task then
        player.print("  output=" .. tostring(task.output_item) .. " gathered=" .. tostring(task.gathered_units) .. "/" .. tostring(task.recipe and task.recipe.units) .. " index=" .. tostring(task.index) .. "/" .. tostring(task.candidates and #task.candidates or 0) .. " current=" .. tostring(task.current and task.current.kind) .. ":" .. tostring(task.current and task.current.item_name))
      else
        player.print("  emergency craft: none")
      end
      if pair.no_resources_here_0269 then
        for k,v in pairs(pair.no_resources_here_0269) do player.print("  no-resources " .. tostring(k) .. " = " .. tostring(v)) end
      end
    end)
  end)
end

tech_priests_0269_log("0.1.269 raw-resource fallback + no-resources-here + dirt scraping loaded")


-- ============================================================================
-- 0.1.270: mouse-over order refresh + direct nil-candidate raw fallback hook
-- ============================================================================
TECH_PRIESTS_VERSION_0270 = "0.1.270"

function tech_priests_0270_log(message)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log(tostring(message), true) end)
  elseif log then
    log("[Tech-Priests 0.1.270] " .. tostring(message))
  end
end

function tech_priests_0270_raw_request_from_task(task)
  if not task then return nil end
  -- item_name is the immediate material currently being gathered/crafted.
  -- output_item may be the higher product such as firearm-magazine, so it is
  -- deliberately checked after the raw/material fields.
  local names = {
    task.item_name,
    task.raw_item,
    task.material_item,
    task.ingredient_item,
    task.need_item,
    task.current_item,
    task.output_item,
    task.item,
    task.result,
  }
  for _, name in ipairs(names) do
    if name and tech_priests_0269_is_raw_resource_name and tech_priests_0269_is_raw_resource_name(name) then
      return name
    end
  end
  return nil
end

function tech_priests_0270_direct_raw_fallback(pair, task, reason)
  if not (pair and task) then return false end
  local requested = tech_priests_0270_raw_request_from_task(task)
  if not requested then return false end

  local cand, mode = nil, nil
  if tech_priests_0269_find_resource_candidate then
    cand, mode = tech_priests_0269_find_resource_candidate(pair, requested, false)
  end

  if cand then
    task.candidates = { cand }
    task.index = 1
    task.current = nil
    task.scan_due_tick = nil
    task.scan_started_tick = nil
    task.craft_due_tick = nil
    task.force_raw_fallback_0270 = nil
    task.raw_fallback_reason_0270 = reason
    if mode == "substitute" and not task.substitute_doubled_0269 then
      task.recipe = task.recipe or {}
      task.recipe.units = math.max(1, (task.recipe.units or 1) * 2)
      task.substitute_doubled_0269 = true
      task.blocker_0269 = "using substitute resource at double burden"
    end
    pair.mode = "emergency-gathering"
    pair.target = nil
    if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
    tech_priests_0270_log("raw fallback injected station=" .. tostring(pair.station and pair.station.unit_number) .. " requested=" .. tostring(requested) .. " mode=" .. tostring(mode) .. " reason=" .. tostring(reason))
    return true
  end

  local count = 0
  if tech_priests_0269_assignment_note_no_resources then
    count = tech_priests_0269_assignment_note_no_resources(pair, requested) or 0
  end
  tech_priests_0270_log("raw fallback no-resource station=" .. tostring(pair.station and pair.station.unit_number) .. " requested=" .. tostring(requested) .. " count=" .. tostring(count) .. " reason=" .. tostring(reason))

  if count >= 2 and tech_priests_0269_begin_dirt_scrape then
    return tech_priests_0269_begin_dirt_scrape(pair, task, requested)
  end

  if tech_priests_0252_clear_assignment and pair.assignment_0252 then
    pcall(function() tech_priests_0252_clear_assignment(pair.assignment_0252, "failed", "no resources here for " .. tostring(requested)) end)
  end
  pair.emergency_craft = nil
  pair.mode = "returning"
  if pair.priest and pair.priest.valid and pair.station and pair.station.valid and return_to_station then
    pcall(function() return_to_station(pair.priest, pair.station) end)
  end
  return true
end

-- This is the important live hook.  0.1.269 loaded but did not trigger because
-- it looked at output_item first; for ammo, output_item=firearm-magazine while
-- the actual raw gather task is item_name=iron-ore.  This wrapper treats
-- emergency-gathering + current=nil as the fallback trigger itself.
if handle_emergency_desperation_craft then
  TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0270 = handle_emergency_desperation_craft
  function handle_emergency_desperation_craft(pair)
    if pair and pair.emergency_craft then
      local task = pair.emergency_craft
      local current = task.current
      local current_ok = false
      if current then
        if current.kind == "dirt" then current_ok = true
        elseif current.entity and current.entity.valid then current_ok = true
        elseif current.position and current.kind == "dirt" then current_ok = true end
      end
      local candidates = task.candidates or {}
      local idx = math.max(1, task.index or 1)
      local candidate = candidates[idx]
      local candidate_ok = false
      if candidate then
        local ok = false
        if tech_priests_0269_candidate_valid then
          local ok2 = nil
          ok2 = select(1, tech_priests_0269_candidate_valid(candidate))
          ok = ok2 and true or false
        else
          ok = (candidate.entity and candidate.entity.valid) or candidate.kind == "dirt"
        end
        candidate_ok = ok
      end

      if task.force_raw_fallback_0270 or ((not current_ok) and (not candidate_ok) and tech_priests_0270_raw_request_from_task(task)) then
        return tech_priests_0270_direct_raw_fallback(pair, task, task.force_raw_fallback_0270 and "manual-refresh" or "nil-current")
      end
    end
    return TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0270(pair)
  end
end

function tech_priests_0270_refresh_orders_for_pair(pair, source)
  if not (pair and pair.station and pair.station.valid) then return false end
  source = source or "unknown"
  pair.next_emergency_operation_tick = game.tick
  pair.next_scavenge_search_tick = game.tick
  pair.next_inventory_scan_tick = game.tick
  pair.next_assignment_retry_tick_0270 = game.tick

  local op = nil
  if tech_priests_get_emergency_operation_0184 then
    local ok, got = pcall(function() return tech_priests_get_emergency_operation_0184(pair) end)
    if ok then op = got end
  end
  if op then
    op.next_tick = game.tick
    op.next_plan_tick = game.tick
    op.retry_tick = game.tick
    op.wait_until = nil
    op.last_probe_reason = "order refresh: " .. tostring(source)
  end

  if pair.assignment_0252 then
    pair.assignment_0252.next_tick = game.tick
    pair.assignment_0252.retry_tick = game.tick
    pair.assignment_0252.wait_until = nil
  end

  if pair.emergency_craft then
    local task = pair.emergency_craft
    task.scan_due_tick = nil
    task.scan_started_tick = nil
    task.craft_due_tick = nil
    if not (task.current and ((task.current.entity and task.current.entity.valid) or task.current.kind == "dirt")) then
      task.force_raw_fallback_0270 = true
    end
  end

  tech_priests_0270_log("orders refreshed station=" .. tostring(pair.station.unit_number) .. " source=" .. tostring(source) .. " mode=" .. tostring(pair.mode) .. " craft=" .. tostring(pair.emergency_craft and (pair.emergency_craft.item_name or pair.emergency_craft.output_item) or "nil"))
  return true
end

-- Mouse-over/selection refresh.  Moving the cursor over a priest/station or
-- changing selection now kicks its order planner back awake.  This is intended
-- as a debug lever and as a safety nudge for stuck state machines.
TECH_PRIESTS_ORIGINAL_ON_SELECTED_ENTITY_CHANGED_0270 = on_selected_entity_changed
function on_selected_entity_changed(event)
  if TECH_PRIESTS_ORIGINAL_ON_SELECTED_ENTITY_CHANGED_0270 then
    pcall(function() TECH_PRIESTS_ORIGINAL_ON_SELECTED_ENTITY_CHANGED_0270(event) end)
  end
  local player = game.get_player(event.player_index)
  if not (player and player.selected and player.selected.valid) then return end
  local pair = nil
  if find_pair_for_entity then
    local ok, got = pcall(function() return find_pair_for_entity(player.selected) end)
    if ok then pair = got end
  end
  if not pair and tech_priests_0264_find_pair_for_player then
    local ok, got = pcall(function() return tech_priests_0264_find_pair_for_player(player) end)
    if ok then pair = got end
  end
  if pair then
    tech_priests_0270_refresh_orders_for_pair(pair, "mouse-over")
    -- Service once immediately when safe so the visible state can change without
    -- waiting for the next diagnostic heartbeat.
    if pair.emergency_craft and handle_emergency_desperation_craft then
      pcall(function() handle_emergency_desperation_craft(pair) end)
    end
  end
end
TechPriestsRuntimeEventRegistry.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)

if commands then
  TechPriestsDebugCommandRegistry.add("tp-refresh-orders", "Tech Priests: refresh selected priest/station orders immediately.", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local pair = tech_priests_0264_find_pair_for_player and tech_priests_0264_find_pair_for_player(player) or nil
    if not pair and player.selected and player.selected.valid and find_pair_for_entity then
      local ok, got = pcall(function() return find_pair_for_entity(player.selected) end)
      if ok then pair = got end
    end
    if not pair then player.print("No Tech Priest pair selected.") return end
    tech_priests_0270_refresh_orders_for_pair(pair, "command")
    if pair.emergency_craft and handle_emergency_desperation_craft then pcall(function() handle_emergency_desperation_craft(pair) end) end
    player.print("Tech Priest orders refreshed for station #" .. tostring(pair.station and pair.station.unit_number or "?"))
  end)
end

tech_priests_0270_log("0.1.270 mouse-over order refresh + direct nil-candidate raw fallback loaded")


-- ============================================================================
-- 0.1.271: no-resources-here escalation ledger + top-chain dirt scraping
-- ============================================================================
TECH_PRIESTS_VERSION_0271 = "0.1.271"

function tech_priests_0271_log(message)
  local line = "[Tech-Priests 0.1.271][tick " .. tostring(game and game.tick or 0) .. "] " .. tostring(message)
  if log then log(line) end
  if helpers and helpers.write_file then
    pcall(function() helpers.write_file("tech-priests-emergency-diagnostics.log", line .. "\n", true) end)
  elseif tech_priests_0264_log then
    pcall(function() tech_priests_0264_log(tostring(message), true) end)
  end
end

function tech_priests_0271_station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

function tech_priests_0271_raw_request_from_task(task)
  if not task then return nil end
  local names = {
    task.item_name,
    task.raw_item,
    task.material_item,
    task.ingredient_item,
    task.need_item,
    task.current_item,
    task.output_item,
    task.item,
    task.result,
  }
  for _, name in ipairs(names) do
    if name and tech_priests_0269_is_raw_resource_name and tech_priests_0269_is_raw_resource_name(name) then return name end
  end
  return nil
end

function tech_priests_0271_ensure_storage()
  ensure_storage()
  storage.tech_priests.raw_no_resources_0271 = storage.tech_priests.raw_no_resources_0271 or {}
  storage.tech_priests.raw_no_resources_notes_0271 = storage.tech_priests.raw_no_resources_notes_0271 or {}
end
