-- scripts/core/work_visuals.lua
-- Tech Priests 0.1.323 visible work-state feedback.
--
-- Keeps the player-facing question answered: is the priest crafting, scanning,
-- acquiring ingredients, delegating, or actually idle?  The renderer is kept in
-- a module so control.lua does not gain more main-chunk locals.

local Visuals = {}
Visuals.version = "0.1.459"
Visuals.storage_key = "tech_priests_work_visuals_0323"
Visuals.update_spacing = 15
Visuals.default_ttl = 22

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function g(name) return rawget(_G, name) end
local function callable(name) local fn = g(name); if type(fn) == "function" then return fn end; return nil end

local function safe_destroy(obj)
  if not obj then return end
  pcall(function()
    if obj.valid == nil or obj.valid then obj.destroy() end
  end)
end

local function pair_key(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and pair.station and pair.station.valid then return pair.station.unit_number end
  if pair and pair.priest and pair.priest.valid then return pair.priest.unit_number end
  return nil
end

local function bar(progress, width)
  width = width or 12
  progress = math.max(0, math.min(1, tonumber(progress) or 0))
  local filled = math.floor(progress * width + 0.5)
  local out = ""
  for i = 1, width do out = out .. (i <= filled and "█" or "░") end
  return out
end

local function item_text(item_name)
  if item_name and item_name ~= "" then return "[item=" .. tostring(item_name) .. "]" end
  return "[virtual-signal=signal-info] no explicit item"
end

local function idle_like_mode(mode)
  mode = tostring(mode or "")
  return mode == "" or mode == "idle" or mode == "no-managed-priority-claimed" or mode == "scheduler-0277" or mode == "no-managed-priority"
end

local function canonical_mode(pair)
  if not pair then return "idle" end
  return tostring(pair.visual_state_0276 or pair.mode or "idle")
end

local function has_canonical_active_task(pair)
  if not pair then return false end
  local task = pair.active_task or pair.active_task_0285
  if type(task) == "table" then return tostring(task.type or task.kind or "") ~= "idle" end
  if task ~= nil and task ~= false and tostring(task) ~= "idle" then return true end
  local kind = tostring(pair.task_kind_0276 or "")
  if kind ~= "" and kind ~= "idle" then return true end
  return false
end

function Visuals.is_workstate_idle(pair)
  if not pair then return true end
  if not idle_like_mode(canonical_mode(pair)) then return false end
  if has_canonical_active_task(pair) then return false end
  return true
end

function Visuals.ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Visuals.storage_key] = storage.tech_priests[Visuals.storage_key] or {
    version = Visuals.version,
    enabled = true,
    objects = {},
    scan_lines = {},
    stats = {}
  }
  local root = storage.tech_priests[Visuals.storage_key]
  root.version = Visuals.version
  root.objects = root.objects or {}
  root.scan_lines = root.scan_lines or {}
  root.stats = root.stats or {}
  return root
end

function Visuals.destroy_for_pair(pair)
  local root = Visuals.ensure_root()
  local key = pair_key(pair)
  if not key then return end
  safe_destroy(root.objects[key]); root.objects[key] = nil
  safe_destroy(root.scan_lines[key]); root.scan_lines[key] = nil
end

function Visuals.draw_label(pair, text)
  if not (pair and valid(pair.priest) and rendering and rendering.draw_text) then return end
  local root = Visuals.ensure_root()
  local key = pair_key(pair)
  if not key then return end
  safe_destroy(root.objects[key])
  local ok, obj = pcall(function()
    return rendering.draw_text({
      text = text,
      target = pair.priest,
      target_offset = { 0, -2.65 },
      surface = pair.priest.surface,
      color = { r = 1.0, g = 0.82, b = 0.22, a = 0.95 },
      scale = 0.64,
      alignment = "center",
      time_to_live = Visuals.default_ttl
    })
  end)
  if ok and obj then root.objects[key] = obj end
end

function Visuals.draw_scan_line(pair, target)
  if not (pair and valid(pair.priest) and rendering and rendering.draw_line) then return end
  local root = Visuals.ensure_root()
  local key = pair_key(pair)
  if not key then return end
  safe_destroy(root.scan_lines[key])
  if not valid(target) then return end
  local ok, obj = pcall(function()
    return rendering.draw_line({
      color = { r = 1.0, g = 0.45, b = 0.05, a = 0.82 },
      width = 2,
      from = pair.priest,
      from_offset = { 0, -1.15 },
      to = target,
      to_offset = { 0, -0.35 },
      surface = pair.priest.surface,
      time_to_live = Visuals.default_ttl
    })
  end)
  if ok and obj then root.scan_lines[key] = obj end
end

function Visuals.craft_status(pair)
  local task = pair and pair.emergency_craft or nil
  if not task then return nil end
  local item = task.item_name or task.output_item or (task.current and (task.current.item_name or task.current.output_item))
  local due = task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337
  if due and game then
    local started = task.craft_started_tick_0337 or task.station_craft_started_tick_0337 or task.craft_started_tick or (due - (tonumber(rawget(_G, "EMERGENCY_CRAFT_WORK_TICKS")) or 180))
    local total = math.max(1, due - started)
    local remaining = math.max(0, due - game.tick)
    local progress = 1 - math.min(1, remaining / total)
    local seconds = math.ceil(remaining / 60)
    return item_text(item) .. " crafting " .. bar(progress, 14) .. " " .. tostring(seconds) .. "s", nil
  end
  if pair and pair.mode == "returning-to-station-for-craft" then
    return item_text(item) .. " returning to station to craft", pair.station
  end
  local cur = task.current
  if cur then
    local target = cur.entity and cur.entity.valid and cur.entity or nil
    local name = cur.item_name or cur.output or item
    return item_text(name) .. " seeking ingredients", target
  end
  return item_text(item) .. " preparing craft", nil
end

function Visuals.scan_status(pair)
  local scan = pair and pair.inventory_scan or nil
  if scan then
    local item = scan.item_name or (scan.request and (scan.request.item_name or scan.request.name or scan.request.kind)) or (callable("get_inventory_scan_item_name") and select(2, pcall(callable("get_inventory_scan_item_name"), scan)))
    local idx = tonumber(scan.index or scan.current_index or 0) or 0
    local total = scan.candidates and #scan.candidates or 0
    local progress = total > 0 and math.min(1, idx / math.max(1, total)) or ((now() % 60) / 60)
    local target = scan.current and scan.current.entity and scan.current.entity.valid and scan.current.entity or nil
    return item_text(item) .. " scanning " .. bar(progress, 10) .. " " .. tostring(idx) .. "/" .. tostring(total), target
  end
  if pair and pair.scavenge then
    local item = pair.scavenge.item_name or pair.scavenge.name or pair.logistic_requested_item
    local target = pair.scavenge.source and pair.scavenge.source.valid and pair.scavenge.source or nil
    return item_text(item) .. " scavenging/searching", target
  end
  if pair and pair.logistic_requested_item then
    return item_text(pair.logistic_requested_item) .. " missing; searching supply", pair.station
  end
  return nil
end

function Visuals.delegation_status(pair)
  local q = pair and pair.subordinate_queue_0323 or nil
  local job = pair and pair.emergency_assist_job_0187 or nil
  if q and q.active and q.count and q.count > 0 then
    return "[virtual-signal=signal-info] delegating " .. tostring(q.count) .. "/" .. tostring(q.limit or 0) .. " subordinate writs", nil
  end
  if job then
    return item_text(job.item_name) .. " writ active; no subordinate capacity", nil
  end
  return nil
end

function Visuals.status_for_pair(pair)
  if not (pair and valid(pair.priest)) then return nil end

  -- 0.1.459: the overhead work text must follow the same pair state that the
  -- Cogitator Work State panel reports.  Older emergency/scavenge fields can
  -- remain as stale tables after the scheduler has returned the pair to idle;
  -- do not let those stale fields invent "placing emergency facility" or
  -- "no-managed-priority-claimed" labels over an idle priest.
  if Visuals.is_workstate_idle(pair) then return nil end

  local mode = canonical_mode(pair)
  local kind = tostring(pair.task_kind_0276 or (type(pair.active_task) == "table" and (pair.active_task.kind or pair.active_task.type)) or "")
  if kind ~= "" and not idle_like_mode(mode) then
    if kind == "combat" then return "[virtual-signal=signal-alert] combat doctrine: " .. mode, pair.target end
    if kind == "repair" then return "[item=repair-pack] repair doctrine: " .. mode, pair.target end
    if kind == "consecration" then return "[item=sacred-machine-oil] consecration doctrine: " .. mode, pair.target end
    if kind == "construction" then return "[item=iron-gear-wheel] construction doctrine: " .. mode, pair.target end
  end

  local text, target = Visuals.craft_status(pair)
  if text then return text, target end
  text, target = Visuals.scan_status(pair)
  if text then return text, target end
  text, target = Visuals.delegation_status(pair)
  if text then return text, target end
  if pair.mode == "emergency-crafting" or pair.mode == "independent-emergency-operation" then
    return "[virtual-signal=signal-info] calculating emergency doctrine / acquisition fallback", nil
  end
  if not idle_like_mode(mode) then return "[virtual-signal=signal-info] " .. tostring(mode), pair.target end
  return nil
end

function Visuals.update_pair(pair)
  local root = Visuals.ensure_root()
  if not root.enabled then return end
  if not (pair and valid(pair.priest)) then return end
  local state = pair.work_visuals_0323 or {}
  pair.work_visuals_0323 = state
  if game and state.next_tick and game.tick < state.next_tick then return end
  state.next_tick = now() + Visuals.update_spacing
  local text, target = Visuals.status_for_pair(pair)
  if text then
    Visuals.draw_label(pair, text)
    if target and target ~= pair.station then Visuals.draw_scan_line(pair, target)
    elseif pair.inventory_scan or pair.scavenge or pair.logistic_requested_item then Visuals.draw_scan_line(pair, target or pair.station) end
    root.stats.draws = (root.stats.draws or 0) + 1
  else
    Visuals.destroy_for_pair(pair)
  end
end

function Visuals.update_all()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do Visuals.update_pair(pair) end
end

function Visuals.install()
  local previous_tick_pair = rawget(_G, "tick_pair")
  if type(previous_tick_pair) == "function" and rawget(_G, "TECH_PRIESTS_0323_PRE_WORK_VISUAL_TICK_PAIR") == nil then
    _G.TECH_PRIESTS_0323_PRE_WORK_VISUAL_TICK_PAIR = previous_tick_pair
    _G.tick_pair = function(pair)
      local result = _G.TECH_PRIESTS_0323_PRE_WORK_VISUAL_TICK_PAIR(pair)
      pcall(function() Visuals.update_pair(pair) end)
      return result
    end
  end
  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-work-visuals-0323", "Tech Priests: inspect/toggle priest work-state visuals. Usage: /tp-work-visuals-0323 status|enable|disable", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        local parameter = tostring(event and event.parameter or "status")
        local root = Visuals.ensure_root()
        if parameter == "enable" then root.enabled = true elseif parameter == "disable" then root.enabled = false end
        if player and player.valid then player.print("[Tech Priests 0.1.459] work visuals=" .. tostring(root.enabled) .. " draws=" .. tostring(root.stats.draws or 0)) end
      end)
    end)
  end
  return true
end

return Visuals
