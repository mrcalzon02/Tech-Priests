-- scripts/core/overhead_status_governor_0471.lua
-- Tech Priests 0.1.471
-- Canonical single-slot overhead state display.
--
-- Earlier passes left several legacy render paths alive: emergency status,
-- task-force snippets, work visuals, inventory steward notes, acquisition
-- messages, and conversation/idle text could all draw independent labels above
-- the same priest.  This module makes the priest's overhead task label a single
-- governed slot.  It prefers the active order / active conversation / active
-- Magos plan, and treats old status draw calls as state hints instead of new
-- stacked text objects.

local M = {}
M.version = "0.1.473"
M.storage_key = "overhead_status_governor_0471"
M.update_interval = 23
M.default_ttl = 70
M.last_channel = "canonical"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end

local function lower(v) return string.lower(tostring(v or "")) end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    objects = {},
    last_text = {},
    stats = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.objects = root.objects or {}
  root.last_text = root.last_text or {}
  root.stats = root.stats or {}
  return root
end

local function pair_key(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and valid(pair.station) then return pair.station.unit_number end
  if pair and valid(pair.priest) then return pair.priest.unit_number end
  return nil
end

local function is_magos_pair(pair)
  local tier = lower(pair and (pair.tier or pair.rank or pair.station_rank))
  local sname = lower(pair and valid(pair.station) and pair.station.name or "")
  local pname = lower(pair and valid(pair.priest) and pair.priest.name or "")
  return tier:find("planetary%-magos", 1, false) ~= nil or sname:find("planetary%-magos", 1, false) ~= nil or pname:find("planetary%-magos", 1, false) ~= nil
end

local function destroy_object(obj)
  if not obj then return end
  pcall(function()
    if obj.valid == nil or obj.valid then obj.destroy() end
  end)
end

local function destroy_known_legacy_objects(pair)
  if not pair then return end
  -- Legacy stacked status renderer stored per-channel objects here.  The new
  -- doctrine is one visible task line, so every old channel is cleared before
  -- the canonical line is drawn.
  if pair.tech_priests_status_render_0215 then
    for k, obj in pairs(pair.tech_priests_status_render_0215 or {}) do
      destroy_object(obj)
      pair.tech_priests_status_render_0215[k] = nil
    end
  end
  local key = pair_key(pair)
  if storage and storage.tech_priests and key then
    if storage.tech_priests.priest_bubbles then
      destroy_object(storage.tech_priests.priest_bubbles[key]); storage.tech_priests.priest_bubbles[key] = nil
    end
    -- Work/crafting/inventory modules keep their own text object roots; clear
    -- them before the canonical line is drawn so there is exactly one overhead
    -- status slot.
    for _, name in ipairs({
      "tech_priests_work_visuals_0323",
      "crafting_executor_0337",
      "inventory_steward_0357",
      "inventory_steward_0356",
      "construction_planner_0359",
      "construction_planner_0343",
      "emergency_facility_doctrine_0343",
    }) do
      local root = storage.tech_priests[name]
      if root and root.objects then destroy_object(root.objects[key]); root.objects[key] = nil end
    end
  end
end

local function clean_item_name(name)
  name = tostring(name or "")
  if name == "" or name == "nil" or name == "none" then return nil end
  return (name:gsub("%-", " "))
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  return v.item or v.item_name or v.name or v.output_item or v.wanted_item or v.requested_item or v.resource
end

local function order_item(order)
  if not order then return nil end
  return order.item or item_from(order.task) or order.wanted_item or order.requested_item
end

local function conversation_active(pair)
  if not pair then return false end
  local t = now()
  if pair.idle_player_conversation_0181 then return true end
  if pair.idle_conversation then return true end
  if pair.idle_conversation_approach_0180 then return true end
  if pair.idle_conversation_listener_until and tonumber(pair.idle_conversation_listener_until) and t < tonumber(pair.idle_conversation_listener_until) then return true end
  if pair.idle_conversation_approach_listener_until_0180 and tonumber(pair.idle_conversation_approach_listener_until_0180) and t < tonumber(pair.idle_conversation_approach_listener_until_0180) then return true end
  if _G.tech_priests_pair_is_conversation_locked_0179 then
    local ok, yes = pcall(_G.tech_priests_pair_is_conversation_locked_0179, pair)
    if ok and yes then return true end
  end
  if _G.tech_priests_pair_has_player_conversation_0181 then
    local ok, yes = pcall(_G.tech_priests_pair_has_player_conversation_0181, pair)
    if ok and yes then return true end
  end
  return false
end

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return q and q.current or pair and pair.active_order_0469 or nil
end

local function current_plan(pair)
  local q = pair and pair.magos_planning_queue_0471
  return q and q.current or pair and pair.magos_current_plan_0471 or nil
end


local function progress_bar_0479(progress, width)
  width = width or 10
  progress = math.max(0, math.min(1, tonumber(progress) or 0))
  local filled = math.floor(progress * width + 0.5)
  local out = ""
  for i = 1, width do out = out .. (i <= filled and "█" or "░") end
  return out
end

local function craft_progress_status_0479(pair)
  if not pair then return nil, nil end
  local task = pair.emergency_craft or pair.station_craft_0337 or pair.active_craft_0479
  local mode = lower(pair.mode)
  if not task and not mode:find("craft", 1, true) then return nil, nil end
  task = task or {}
  local item = clean_item_name(item_from(task.current or task) or item_from(task.request or {}) or item_from(current_order(pair) or {}) or pair.last_item)
  local due = tonumber(task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337 or task.due_tick)
  local started = tonumber(task.craft_started_tick_0337 or task.station_craft_started_tick_0337 or task.craft_started_tick or task.started_tick or (due and (due - 180)) or now())
  local remaining_ticks = due and math.max(0, due - now()) or nil
  local total = due and math.max(1, due - started) or 180
  local progress = remaining_ticks and (1 - math.min(1, remaining_ticks / total)) or 0
  local seconds = remaining_ticks and math.ceil(remaining_ticks / 60) or nil
  local label = "Crafting" .. (item and (" " .. item) or "")
  if seconds then label = label .. " " .. tostring(seconds) .. "s" end
  label = label .. " " .. progress_bar_0479(progress, 10)
  return label, { r = 1.0, g = 0.74, b = 0.24, a = 0.95 }
end

local function order_text(pair, order)
  if not order then return nil, nil end
  local kind = lower(order.kind)
  local item = clean_item_name(order_item(order))
  if kind == "combat" or kind == "defense" then return "Battle rite engaged", { r = 1.0, g = 0.25, b = 0.15, a = 0.95 } end
  if kind == "repair" then return "Repair litany in progress", { r = 0.55, g = 0.95, b = 0.55, a = 0.95 } end
  if kind == "consecration" or kind == "sanctify" then return "Consecration rite in progress", { r = 0.60, g = 1.0, b = 0.95, a = 0.95 } end
  if kind == "construction" then return "Construction writ executing" .. (item and (": " .. item) or ""), { r = 1.0, g = 0.72, b = 0.25, a = 0.95 } end
  if kind == "logistics" or kind == "supply" then return "Station writ: " .. (item or "supplies"), { r = 1.0, g = 0.78, b = 0.22, a = 0.95 } end
  if kind == "assignment" then return "Subordinate writ executing" .. (item and (": " .. item) or ""), { r = 1.0, g = 0.78, b = 0.22, a = 0.95 } end
  if kind == "scavenge" or kind == "acquisition" or kind == "gather" or kind == "direct_mine" then return "Acquiring " .. (item or "field materials"), { r = 0.98, g = 0.72, b = 0.22, a = 0.95 } end
  if kind == "emergency_craft" or kind == "emergency" then return "Emergency fabrication rite" .. (item and (": " .. item) or ""), { r = 1.0, g = 0.62, b = 0.18, a = 0.95 } end
  if kind ~= "" and kind ~= "idle" then return "Executing writ: " .. kind, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 } end
  return nil, nil
end

local function legacy_text_hint(pair, incoming)
  local text = tostring(incoming or "")
  local low = lower(text)
  if text == "" then return nil end
  -- Suppress noisy bookkeeping acknowledgements.  They remain log-worthy, not
  -- overhead-state worthy.
  if low:find("inventory reliquary indexed", 1, true) then return nil end
  if low:find("indexed", 1, true) and low:find("reliquary", 1, true) then return nil end
  if low:find("no explicit item", 1, true) then return nil end
  if low:find("signal%-info", 1, false) and low:find("calculating", 1, true) then return nil end
  if low:find("survival", 1, true) or low:find("ammo", 1, true) or low:find("firearm%-magazine", 1, false) then
    return "Ammunition writ in progress", { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }
  end
  if low:find("assigned", 1, true) then
    local item = text:match("%[item=([^%]]+)%]") or text:match("item=([%w%-%_]+)")
    return "Assigned writ" .. (item and (": " .. clean_item_name(item)) or ""), { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }
  end
  if low:find("subordinate", 1, true) then return "Coordinating subordinate writ", { r = 1.0, g = 0.78, b = 0.22, a = 0.95 } end
  if low:find("combat", 1, true) or low:find("defend", 1, true) then return "Battle rite engaged", { r = 1.0, g = 0.25, b = 0.15, a = 0.95 } end
  if low:find("acquir", 1, true) or low:find("gather", 1, true) or low:find("mine", 1, true) then
    local item = text:match("%[item=([^%]]+)%]")
    return "Acquiring " .. (clean_item_name(item) or "field materials"), { r = 0.98, g = 0.72, b = 0.22, a = 0.95 }
  end
  -- For any remaining legacy text, show a short diegetic state rather than raw
  -- debug prose or rich-text tags.
  return "Rite in progress", { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }
end

function M.canonical_status(pair, incoming_text)
  if not (pair and valid(pair.priest)) then return nil, nil end
  if conversation_active(pair) then return "Conversing", { r = 1.0, g = 0.86, b = 0.28, a = 0.95 } end
  local craft_text, craft_color = craft_progress_status_0479(pair)
  if craft_text then return craft_text, craft_color end
  local order = current_order(pair)
  local text, color = order_text(pair, order)
  if text then return text, color end
  if pair.active_task or pair.active_task_0285 then
    local task = pair.active_task or pair.active_task_0285
    return order_text(pair, { kind = task.kind or task.type or pair.mode, item = item_from(task), task = task })
  end
  if pair.emergency_craft then
    local item = item_from(pair.emergency_craft.current or pair.emergency_craft)
    return "Emergency fabrication rite" .. (clean_item_name(item) and (": " .. clean_item_name(item)) or ""), { r = 1.0, g = 0.62, b = 0.18, a = 0.95 }
  end
  if pair.scavenge or pair.direct_acquisition_task_0336 then
    local t = pair.scavenge or pair.direct_acquisition_task_0336
    local item = item_from(t.current or t)
    return "Acquiring " .. (clean_item_name(item) or "field materials"), { r = 0.98, g = 0.72, b = 0.22, a = 0.95 }
  end
  local plan = current_plan(pair)
  if is_magos_pair(pair) and plan and plan.status ~= "complete" and plan.status ~= "cancelled" then
    local item = clean_item_name(plan.item)
    return "Composing construction writ" .. (item and (": " .. item) or ""), { r = 0.64, g = 1.0, b = 0.76, a = 0.95 }
  end
  if incoming_text then return legacy_text_hint(pair, incoming_text) end
  local mode = lower(pair.mode)
  if mode ~= "" and mode ~= "idle" and mode ~= "scheduler-0277" and mode ~= "no-managed-priority-claimed" then
    if mode:find("conversation", 1, true) then return "Conversing", { r = 1.0, g = 0.86, b = 0.28, a = 0.95 } end
    if mode:find("combat", 1, true) or mode:find("defend", 1, true) then return "Battle rite engaged", { r = 1.0, g = 0.25, b = 0.15, a = 0.95 } end
    if mode:find("gather", 1, true) or mode:find("mine", 1, true) or mode:find("laser%-fallback", 1, false) then return "Acquiring field materials", { r = 0.98, g = 0.72, b = 0.22, a = 0.95 } end
    return "Rite in progress", { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }
  end
  return nil, nil
end

function M.clear(pair)
  local root = ensure_root()
  local key = pair_key(pair)
  if key and root.objects[key] then destroy_object(root.objects[key]); root.objects[key] = nil end
  if key then root.last_text[key] = nil end
  destroy_known_legacy_objects(pair)
end

function M.set(pair, incoming_text, color, ttl, scale, source)
  local root = ensure_root()
  if root.enabled == false then return true end
  if not (pair and valid(pair.priest) and rendering and rendering.draw_text) then return false end
  local text, canonical_color = M.canonical_status(pair, incoming_text)
  if not text then M.clear(pair); return true end
  local key = pair_key(pair)
  if not key then return false end
  destroy_known_legacy_objects(pair)
  local previous = root.objects[key]
  local previous_text = root.last_text[key]
  if previous and previous.valid and previous_text == text then return true end
  destroy_object(previous)
  local ok, obj = pcall(function()
    return rendering.draw_text({
      text = tostring(text),
      target = { entity = pair.priest, offset = { 0, -2.75 } },
      surface = pair.priest.surface,
      color = canonical_color or color or { r = 1.0, g = 0.78, b = 0.22, a = 0.95 },
      scale = scale or 0.62,
      alignment = "center",
      time_to_live = ttl or M.default_ttl,
      use_rich_text = false,
    })
  end)
  if ok and obj then
    root.objects[key] = obj
    root.last_text[key] = text
    root.stats.draws = (root.stats.draws or 0) + 1
    pair.overhead_status_0471 = { text = text, source = source or M.last_channel, tick = now() }
    return true
  end
  return false
end

function M.update_pair(pair)
  if not (pair and valid(pair.priest)) then return end
  local allow_theater = rawget(_G, "tech_priests_allow_theater_for_pair_0609")
  if allow_theater then
    local ok, allowed = pcall(allow_theater, pair, "overhead")
    if ok and allowed == false then return end
  end
  local state = pair.overhead_status_state_0471 or {}
  pair.overhead_status_state_0471 = state
  if state.next_tick and now() < state.next_tick then return end
  state.next_tick = now() + M.update_interval
  M.set(pair, nil, nil, M.default_ttl, nil, "periodic")
end

function M.update_all()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do M.update_pair(pair) end
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  if _G.tech_priests_find_pair_for_player_selection_0184 then local ok, pair = pcall(_G.tech_priests_find_pair_for_player_selection_0184, player); if ok and pair then return pair end end
  local selected = player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local unit = selected.unit_number
    return (storage.tech_priests.pairs_by_station or {})[unit] or (storage.tech_priests.pairs_by_priest or {})[unit]
  end
  return nil
end

function M.install()
  _G.TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471 = M
  _G.tech_priests_overhead_status_0471_set = M.set
  _G.tech_priests_overhead_status_0471_clear = M.clear

  -- Replace legacy multi-channel status drawing with a single canonical slot.
  _G.tech_priests_draw_stacked_status_text_0211 = function(pair, text, color, ttl, scale, channel)
    return M.set(pair, text, color, ttl, scale, channel or "legacy-stacked")
  end
  _G.tech_priests_draw_emergency_operation_status_0184 = function(pair, text)
    return M.set(pair, text, { r = 1.0, g = 0.55, b = 0.12, a = 0.95 }, M.default_ttl, 0.62, "emergency")
  end
  _G.tech_priests_task_force_snippet_0187 = function(pair, text)
    return M.set(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, M.default_ttl, 0.62, "task-force")
  end
  _G.tech_priests_task_force_snippet_0188 = _G.tech_priests_task_force_snippet_0187

  -- Route the modular Work Visuals label into the same slot.  Its scan line may
  -- still draw separately; the text itself may not stack.
  local ok_w, WorkVisuals = pcall(require, "scripts.core.work_visuals")
  if ok_w and type(WorkVisuals) == "table" then
    WorkVisuals.draw_label = function(pair, text) return M.set(pair, text, nil, M.default_ttl, 0.62, "work-visuals") end
    local old_destroy = WorkVisuals.destroy_for_pair
    WorkVisuals.destroy_for_pair = function(pair)
      M.clear(pair)
      if old_destroy then pcall(old_destroy, pair) end
    end
  end

  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(M.update_interval, function() M.update_all() end, { owner = "overhead_status_governor_0471", category = "visuals" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.update_interval, M.update_all) end)
  end
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-overhead-status-0471") end end)
    pcall(function()
      commands.add_command("tp-overhead-status-0471", "Tech Priests: inspect or refresh the governed one-line priest overhead status.", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if not (player and player.valid) then return end
        local pair = selected_pair(player)
        if not pair then player.print("[tp-overhead-status-0471] select a tracked Cogitator station or priest."); return end
        M.set(pair, nil, nil, M.default_ttl, nil, "command")
        local status = pair.overhead_status_0471 or {}
        player.print("[tp-overhead-status-0471] " .. safe(status.text or "no visible overhead rite") .. " source=" .. safe(status.source) .. " tick=" .. safe(status.tick))
      end)
    end)
  end
  if log then log("[Tech-Priests 0.1.473] canonical one-slot overhead status governor installed") end
  return true
end

return M
