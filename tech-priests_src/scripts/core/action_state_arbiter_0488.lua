-- scripts/core/action_state_arbiter_0488.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Pure action classifier and read-only presentation gate. It never creates work,
-- fails orders, clears executor state, requests movement, or owns a timer.

local M = {
  version = "0.1.674-dev",
  storage_key = "action_state_arbiter_0488",
  close_distance_sq = 4,
}

local previous_scan_line
local previous_fire_laser

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function lower(value) return string.lower(tostring(value or "")) end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    snapshots = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.snapshots = state.snapshots or {}
  return state
end
local function enabled() return root().enabled ~= false end
local function stat(key, amount)
  local state = root()
  state.stats[key] = (state.stats[key] or 0) + (tonumber(amount) or 1)
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function pair_key(pair)
  return pair and (pair.station_unit
    or (valid(pair.station) and pair.station.unit_number)
    or (valid(pair.priest) and pair.priest.unit_number)) or nil
end
local function current_order(pair)
  local queue = pair and pair.order_queue_0469
  return pair and ((queue and queue.current) or pair.active_order_0469) or nil
end
local function item_from(value)
  if type(value) == "string" then return value end
  if type(value) ~= "table" then return nil end
  return value.item or value.item_name or value.output_item or value.wanted_item
    or value.requested_item or value.resource
end

local function normalize_kind(value)
  local kind = lower(value)
  if kind == "" then return "idle" end
  if kind:find("item%-family%-logistics") or kind:find("item_family_logistics") then
    return "item-family-logistics"
  end
  if kind:find("machine%-logistics") or kind:find("machine_logistics") then
    return "machine-logistics"
  end
  if kind:find("combat%-repair") then return "combat-repair" end
  if kind:find("combat", 1, true) or kind:find("defend", 1, true) then return "combat" end
  if kind:find("repair", 1, true) then return "repair" end
  if kind:find("consecr", 1, true) or kind:find("sanct", 1, true) then
    return "consecration"
  end
  if kind:find("construct", 1, true) or kind:find("build", 1, true) then
    return "construction"
  end
  if kind:find("craft", 1, true) or kind:find("fabric", 1, true) then
    return "crafting"
  end
  if kind:find("machine", 1, true) or kind:find("logistic", 1, true)
    or kind:find("supply", 1, true) or kind:find("scav", 1, true)
    or kind:find("mine", 1, true) or kind:find("acqui", 1, true)
    or kind:find("gather", 1, true) or kind:find("resource", 1, true)
    or kind:find("emergency", 1, true)
  then
    return "acquisition"
  end
  if kind:find("return", 1, true) or kind:find("travell", 1, true)
    or kind:find("moving", 1, true)
  then
    return "movement"
  end
  return kind
end

local function entity_or_position(value, seen)
  if valid(value) then return value, value.position end
  if type(value) ~= "table" then return nil, nil end
  seen = seen or {}
  if seen[value] then return nil, nil end
  seen[value] = true
  if value.x and value.y then return nil, value end
  if type(value.position) == "table" and value.position.x and value.position.y then
    return nil, value.position
  end
  for _, key in ipairs({
    "target", "source", "entity", "resource_entity", "mining_target",
    "candidate", "current", "selected", "node", "destination", "task",
  }) do
    local entity, position = entity_or_position(value[key], seen)
    if entity or position then return entity, position end
  end
  return nil, nil
end

local function current_target(pair, order)
  for _, value in ipairs({
    order and order.target,
    order and order.task,
    pair and pair.direct_acquisition_custody_0513,
    pair and pair.direct_acquisition_task_0336,
    pair and pair.emergency_craft,
    pair and pair.consecration_0515,
    pair and pair.repair_0516,
    pair and pair.combat_repair_0517,
    pair and pair.machine_logistics_0528,
    pair and pair.item_family_logistics_0702,
    pair and pair.item_family_custody_0702,
    pair and pair.item_family_candidate_0702,
    pair and pair.active_task,
    pair and pair.active_task_0285,
    pair and pair.target,
  }) do
    local entity, position = entity_or_position(value)
    if entity or position then return entity, position end
  end
  return nil, nil
end

local function actual_crafting(pair, order)
  if normalize_kind(order and order.kind) == "crafting" then return true end
  local task = pair and (pair.emergency_craft or pair.station_crafting_task_0337
    or pair.station_craft_0337 or pair.active_craft_0479)
  if not task then return false end
  local current = type(task) == "table" and (task.current or task.entity or task.target)
  if valid(current) or type(current) == "table" then return false end
  local due = tonumber(task.craft_due_tick or task.build_due_tick
    or task.station_craft_due_tick_0337 or task.due_tick)
  return due ~= nil or task.station_craft_pending_0337 == true
end

local function hostile(priest, target)
  if not (valid(priest) and valid(target) and priest.force and target.force)
    or priest.force == target.force
  then
    return false
  end
  local ok, enemy = pcall(function()
    return priest.force.is_enemy and priest.force.is_enemy(target.force)
  end)
  return ok and enemy == true
end

local function combat_repair_recommendation(pair, order_kind, mode_kind)
  if order_kind ~= "idle"
    or not (mode_kind == "combat" or valid(pair.combat_target))
  then
    return nil
  end
  local doctrine = rawget(_G, "TechPriestsCombatRepairDoctrine0517")
    or package.loaded["scripts.core.combat_repair_doctrine_0517"]
  if not (doctrine and type(doctrine.recommend_action) == "function") then return nil end
  local ok, action = pcall(doctrine.recommend_action, pair)
  return ok and type(action) == "table" and action.kind == "combat-repair"
    and action or nil
end

local function machine_logistics_recommendation(pair, order_kind, mode_kind)
  if order_kind ~= "idle" or mode_kind == "combat" or valid(pair.combat_target) then
    return nil
  end
  local machine = rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
    or rawget(_G, "TechPriestsMachineLogisticsFulfillment0528")
    or package.loaded["scripts.core.logistics_machine_fulfillment_0528"]
  if not (machine and type(machine.recommend_action) == "function") then return nil end
  local ok, action = pcall(machine.recommend_action, pair)
  return ok and type(action) == "table" and action.kind == "machine-logistics"
    and action or nil
end

local function item_family_recommendation(pair, order_kind)
  if order_kind ~= "idle" and order_kind ~= "item-family-logistics" then return nil end
  local family = rawget(_G, "TechPriestsItemFamilyLogistics0702")
    or package.loaded["scripts.core.item_family_logistics_0702"]
  if not (family and type(family.recommend_action) == "function") then return nil end
  local ok, action = pcall(family.recommend_action, pair)
  return ok and type(action) == "table"
    and action.kind == "item-family-logistics" and action or nil
end

function M.action(pair)
  if not valid_pair(pair) then return { kind = "invalid", family = "invalid" } end
  local order = current_order(pair)
  local target, position = current_target(pair, order)
  local order_kind = normalize_kind(order and (order.kind or order.type or order.source))
  local mode_kind = normalize_kind(pair.mode)
  local combat_recommendation = combat_repair_recommendation(pair, order_kind, mode_kind)
  local machine_recommendation = machine_logistics_recommendation(pair, order_kind, mode_kind)
  local item_recommendation = item_family_recommendation(pair, order_kind)
  local active_item_recommendation = item_recommendation and item_recommendation.active == true
    and item_recommendation or nil
  local recommendation = combat_recommendation or active_item_recommendation
    or machine_recommendation or item_recommendation
  local kind, reason

  if pair.idle_player_conversation_0181 or pair.idle_conversation then
    kind, reason = "conversation", "conversation-surface"
  elseif actual_crafting(pair, order) then
    kind, reason = "crafting", "crafting-surface"
  elseif order_kind == "combat-repair" then
    kind, reason = "combat-repair", "order"
  elseif combat_recommendation then
    kind, reason = "combat-repair", "tactical-recommendation"
    target = combat_recommendation.target
    position = valid(target) and target.position or combat_recommendation.position
  elseif active_item_recommendation then
    kind, reason = "item-family-logistics", "active-item-family-custody"
    target = active_item_recommendation.target
    position = valid(target) and target.position or active_item_recommendation.position
  elseif order_kind == "combat"
    or (hostile(pair.priest, target) and mode_kind == "combat")
  then
    kind, reason = "combat", "order-or-hostile-target"
  elseif order_kind == "repair" then
    kind, reason = "repair", "order"
  elseif order_kind == "consecration" then
    kind, reason = "consecration", "order"
  elseif order_kind == "construction" then
    kind, reason = "construction", "order"
  elseif order_kind == "machine-logistics" then
    kind, reason = "machine-logistics", "order"
  elseif order_kind == "item-family-logistics" then
    kind, reason = "item-family-logistics", "order"
  elseif order_kind == "acquisition" then
    kind, reason = "acquisition", "order"
  elseif order_kind == "movement" then
    kind, reason = "movement", "order"
  elseif machine_recommendation then
    kind, reason = "machine-logistics", "machine-recommendation"
    target = machine_recommendation.target
    position = valid(target) and target.position or machine_recommendation.position
  elseif item_recommendation then
    kind, reason = "item-family-logistics", "item-family-recommendation"
    target = item_recommendation.target
    position = valid(target) and target.position or item_recommendation.position
  elseif mode_kind ~= "idle" then
    kind, reason = mode_kind, "compatibility-mode"
  else
    kind, reason = "idle", "no-current-order"
  end

  return {
    kind = kind,
    family = kind,
    target = target,
    position = position,
    item = recommendation and recommendation.item
      or (order and (order.item or item_from(order.task)))
      or item_from(pair.active_supply_request)
      or item_from(pair.logistic_requested_item)
      or item_from(pair.emergency_craft)
      or item_from(pair.direct_acquisition_task_0336),
    order_key = order and order.key,
    order_status = order and order.status,
    source = recommendation and recommendation.source or reason,
    reason = recommendation and recommendation.reason or reason,
    phase = recommendation and recommendation.phase,
  }
end

M.classify = M.action

local function destroy_visual(object)
  if object then
    pcall(function()
      if object.valid == nil or object.valid then object.destroy() end
    end)
  end
end

function M.clear_beams(pair)
  if not pair then return end
  destroy_visual(pair.scan_line_render)
  pair.scan_line_render = nil
  destroy_visual(pair.mining_beam_render)
  pair.mining_beam_render = nil
  local key = pair_key(pair)
  local work = storage and storage.tech_priests
    and storage.tech_priests.tech_priests_work_visuals_0323
  if work and work.scan_lines and key then
    destroy_visual(work.scan_lines[key])
    work.scan_lines[key] = nil
  end
end

function M.allow_scan(pair, target)
  if not enabled() then return true end
  if not valid_pair(pair) then return false end
  local action = M.action(pair)
  if action.kind ~= "acquisition" then
    M.clear_beams(pair)
    stat("scan_suppressed")
    return false
  end
  if valid(target) and valid(action.target) and target ~= action.target then
    stat("scan_target_mismatch")
    return false
  end
  if valid(target)
    and (dist_sq(pair.priest.position, target.position) or 0) > M.close_distance_sq
  then
    stat("remote_scan_suppressed")
    return false
  end
  return true
end

function M.allow_laser(priest, target)
  if not enabled() then return true end
  if not valid(priest) then return false end
  local pair = storage and storage.tech_priests
    and (storage.tech_priests.pairs_by_priest or {})[priest.unit_number]
  if not valid_pair(pair) then return true end
  local action = M.action(pair)
  if hostile(priest, target) then
    local allowed = action.kind == "combat"
    if not allowed then stat("combat_laser_suppressed") end
    return allowed
  end
  if action.kind ~= "acquisition" then
    M.clear_beams(pair)
    stat("laser_suppressed_wrong_action")
    return false
  end
  if valid(target) and valid(action.target) and target ~= action.target then
    stat("laser_target_mismatch")
    return false
  end
  if valid(target)
    and (dist_sq(priest.position, target.position) or 0) > M.close_distance_sq
  then
    stat("remote_laser_suppressed")
    return false
  end
  return true
end

local function progress_bar(progress, width)
  progress = math.max(0, math.min(1, tonumber(progress) or 0))
  width = width or 10
  local filled = math.floor(progress * width + 0.5)
  local out = ""
  for index = 1, width do out = out .. (index <= filled and "█" or "░") end
  return out
end

function M.status(pair)
  if not valid_pair(pair) then return nil, nil end
  local action = M.action(pair)
  if action.kind == "conversation" then
    return "Conversing", { r = 1, g = 0.86, b = 0.28, a = 0.95 }
  elseif action.kind == "combat" then
    return "Battle rite engaged", { r = 1, g = 0.25, b = 0.15, a = 0.95 }
  elseif action.kind == "combat-repair" then
    return "Combat repair litany", { r = 1, g = 0.45, b = 0.2, a = 0.95 }
  elseif action.kind == "repair" then
    return "Repair litany in progress", { r = 0.55, g = 0.95, b = 0.55, a = 0.95 }
  elseif action.kind == "consecration" then
    return "Consecration rite in progress", { r = 0.6, g = 1, b = 0.95, a = 0.95 }
  elseif action.kind == "construction" then
    return "Construction rite in progress", { r = 0.65, g = 0.85, b = 1, a = 0.95 }
  elseif action.kind == "machine-logistics" then
    return "Machine logistics: " .. tostring(action.item or "supplies"):gsub("-", " "),
      { r = 1, g = 0.68, b = 0.18, a = 0.95 }
  elseif action.kind == "item-family-logistics" then
    return "Item logistics: " .. tostring(action.item or "supplies"):gsub("-", " "),
      { r = 1, g = 0.76, b = 0.22, a = 0.95 }
  elseif action.kind == "crafting" then
    local task = pair.emergency_craft or pair.station_crafting_task_0337
      or pair.station_craft_0337 or pair.active_craft_0479 or {}
    local due = tonumber(task.craft_due_tick or task.build_due_tick
      or task.station_craft_due_tick_0337 or task.due_tick)
    local started = tonumber(task.craft_started_tick_0337
      or task.station_craft_started_tick_0337 or task.started_tick
      or (due and due - 180) or now())
    local label = "Crafting"
      .. (action.item and (" " .. tostring(action.item):gsub("-", " ")) or "")
    if due then
      local remaining = math.max(0, due - now())
      local total = math.max(1, due - started)
      label = label .. " " .. math.ceil(remaining / 60) .. "s "
        .. progress_bar(1 - math.min(1, remaining / total), 10)
    end
    return label, { r = 1, g = 0.74, b = 0.24, a = 0.95 }
  elseif action.kind == "acquisition" then
    return "Acquiring " .. tostring(action.item or "field materials"):gsub("-", " "),
      { r = 0.98, g = 0.72, b = 0.22, a = 0.95 }
  end
  return nil, nil
end

function M.status_for_pair(pair) return M.status(pair) end
function M.service_pair(pair)
  if not (enabled() and valid_pair(pair)) then return nil end
  return M.action(pair)
end
function M.tick_all() return 0 end

local function wrap_visuals()
  if type(_G.draw_emergency_craft_scan_line) == "function" and not previous_scan_line then
    previous_scan_line = _G.draw_emergency_craft_scan_line
    _G.draw_emergency_craft_scan_line = function(pair, target)
      if M.allow_scan(pair, target) then return previous_scan_line(pair, target) end
      return false
    end
  end
  if type(_G.tech_priests_0312_fire_laser) == "function" and not previous_fire_laser then
    previous_fire_laser = _G.tech_priests_0312_fire_laser
    _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
      if M.allow_laser(priest, target) then
        return previous_fire_laser(priest, target, damage, reason, color)
      end
      return false
    end
  end
  local ok, work = pcall(require, "scripts.core.work_visuals")
  if ok and type(work) == "table" then
    work.status_for_pair = function(pair)
      local action = M.action(pair)
      local text, color = M.status(pair)
      return text, action.kind == "acquisition" and action.target or nil, color
    end
    local previous = work.draw_scan_line
    if type(previous) == "function" and not work.action_arbiter_0488_wrapped then
      work.action_arbiter_0488_wrapped = true
      work.draw_scan_line = function(pair, target)
        if M.allow_scan(pair, target) then return previous(pair, target) end
      end
    end
  end
end

local function wrap_overhead()
  local governor = rawget(_G, "TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471")
  if governor and type(governor) == "table"
    and not governor.canonical_status_0488_previous
  then
    governor.canonical_status_0488_previous = governor.canonical_status
    governor.canonical_status = function(pair, incoming)
      local text, color = M.status(pair)
      if text then return text, color end
      return governor.canonical_status_0488_previous(pair, incoming)
    end
  end
end

local function wrap_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.action_state_wrapped_0488
  then
    return false
  end
  diagnostics.action_state_wrapped_0488 = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "ACTION-CLASSIFIER-0488 BEGIN pure=true scan_suppressed="
      .. safe(state.stats.scan_suppressed or 0)
      .. " laser_suppressed=" .. safe(state.stats.laser_suppressed_wrong_action or 0)
    for key, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local action = M.action(pair)
        lines[#lines + 1] = "classifier[" .. safe(key) .. "] kind="
          .. safe(action.kind) .. " item=" .. safe(action.item)
          .. " order=" .. safe(action.order_key) .. " source=" .. safe(action.source)
          .. " target=" .. safe(valid(action.target)
            and action.target.name .. "#" .. safe(action.target.unit_number) or "none")
      end
    end
    lines[#lines + 1] = "ACTION-CLASSIFIER-0488 END"
    return lines
  end
  return true
end

function M.install()
  root()
  _G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488 = M
  wrap_visuals()
  wrap_overhead()
  wrap_diagnostics()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-action-state-0488")
  end
  if log then
    log("[Tech-Priests recovery] pure action classifier installed; no scheduler or movement ownership")
  end
  return true
end

return M
