-- scripts/core/overhead_text_authority_0473.lua
-- Tech Priests 0.1.473
-- Late-binding audit pass for priest overhead text.
--
-- 0.1.471 introduced the canonical one-slot overhead status governor, but old
-- status-bubble paths could still render their own rich-text labels such as
-- "☼ [item=firearm-magazine] survival ammo".  This authority is deliberately
-- late-loaded after the legacy fragments, order queue, Magos planning, and
-- combat authority.  It turns remaining overhead text emitters into state hints
-- for the canonical display and destroys legacy objects that would otherwise
-- stack above the same priest.

local M = {}
M.version = "0.1.473"
M.storage_key = "overhead_text_authority_0473"
M.default_ttl = 75

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function pair_key(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and valid(pair.station) then return pair.station.unit_number end
  if pair and valid(pair.priest) then return pair.priest.unit_number end
  return nil
end

local function destroy_object(obj)
  if not obj then return end
  pcall(function() if obj.valid == nil or obj.valid then obj.destroy() end end)
end

local function pair_from_entity(entity)
  if not (entity and entity.valid and storage and storage.tech_priests) then return nil end
  local unit = entity.unit_number
  if not unit then return nil end
  return (storage.tech_priests.pairs_by_priest or {})[unit]
      or (storage.tech_priests.pairs_by_station or {})[unit]
end

local function target_entity_from_args(args)
  if type(args) ~= "table" then return nil end
  local target = args.target
  if target and target.valid then return target end
  if type(target) == "table" and target.entity and target.entity.valid then return target.entity end
  if args.entity and args.entity.valid then return args.entity end
  return nil
end

function M.clear_legacy(pair)
  if not pair then return end
  local key = pair_key(pair)
  if pair.tech_priests_status_render_0215 then
    for channel, obj in pairs(pair.tech_priests_status_render_0215) do
      destroy_object(obj)
      pair.tech_priests_status_render_0215[channel] = nil
    end
  end
  if storage and storage.tech_priests and key then
    if storage.tech_priests.priest_bubbles then
      destroy_object(storage.tech_priests.priest_bubbles[key])
      storage.tech_priests.priest_bubbles[key] = nil
    end
    local roots = {
      "tech_priests_work_visuals_0323",
      "crafting_executor_0337",
      "inventory_steward_0357",
      "inventory_steward_0356",
      "construction_planner_0359",
      "construction_planner_0343",
      "emergency_facility_doctrine_0343",
    }
    for _, name in ipairs(roots) do
      local root = storage.tech_priests[name]
      if root and root.objects and key then
        destroy_object(root.objects[key])
        root.objects[key] = nil
      end
    end
  end
end

function M.emit(pair, text, color, ttl, scale, source)
  local root = ensure_root()
  if root.enabled == false then return true end
  if not (pair and valid(pair.priest)) then return false end
  M.clear_legacy(pair)
  local governor = rawget(_G, "TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471")
  if governor and governor.set then
    local ok, result = pcall(governor.set, pair, text, color, ttl or M.default_ttl, scale or 0.62, source or "overhead-authority-0473")
    if ok then
      root.stats.routed = (root.stats.routed or 0) + 1
      return result ~= false
    end
  end
  local f = rawget(_G, "tech_priests_overhead_status_0471_set")
  if type(f) == "function" then
    local ok, result = pcall(f, pair, text, color, ttl or M.default_ttl, scale or 0.62, source or "overhead-authority-0473")
    if ok then
      root.stats.routed = (root.stats.routed or 0) + 1
      return result ~= false
    end
  end
  -- Fallback for very early load windows: store intent only. The 0471 periodic
  -- governor will draw on its next service if available.
  pair.overhead_status_0473_pending = { text = text, color = color, ttl = ttl, scale = scale, source = source, tick = now() }
  root.stats.pending = (root.stats.pending or 0) + 1
  return true
end

function M.update_all()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and valid(pair.priest) then
      M.clear_legacy(pair)
      local pending = pair.overhead_status_0473_pending
      if pending and (now() - (pending.tick or 0) < 600) then
        M.emit(pair, pending.text, pending.color, pending.ttl, pending.scale, pending.source)
        pair.overhead_status_0473_pending = nil
      end
    end
  end
end

function M.install()
  ensure_root()
  _G.TECH_PRIESTS_OVERHEAD_TEXT_AUTHORITY_0473 = M
  _G.tech_priests_emit_overhead_status_0473 = function(pair, text, color, ttl, scale, source)
    return M.emit(pair, text, color, ttl, scale, source)
  end

  local previous_clear = rawget(_G, "clear_priest_status_bubble")
  _G.TECH_PRIESTS_0473_PRE_CLEAR_PRIEST_STATUS_BUBBLE = previous_clear
  _G.clear_priest_status_bubble = function(station_unit)
    if storage and storage.tech_priests and storage.tech_priests.priest_bubbles then
      destroy_object(storage.tech_priests.priest_bubbles[station_unit])
      storage.tech_priests.priest_bubbles[station_unit] = nil
    end
    return true
  end

  _G.TECH_PRIESTS_0473_PRE_DRAW_PRIEST_STATUS_BUBBLE = rawget(_G, "draw_priest_status_bubble")
  _G.draw_priest_status_bubble = function(pair)
    return M.emit(pair, nil, nil, M.default_ttl, 0.62, "legacy-status-bubble")
  end

  _G.TECH_PRIESTS_0473_PRE_DRAW_PRIEST_STATUS_TEXT = rawget(_G, "draw_priest_status_text")
  _G.draw_priest_status_text = function(args)
    local pair = pair_from_entity(target_entity_from_args(args))
    if pair then return M.emit(pair, args and args.text or nil, args and args.color or nil, args and args.time_to_live or M.default_ttl, args and args.scale or 0.62, "legacy-draw-priest-status-text") end
    local prev = rawget(_G, "TECH_PRIESTS_0473_PRE_DRAW_PRIEST_STATUS_TEXT")
    if type(prev) == "function" then return prev(args) end
    return nil
  end

  _G.TECH_PRIESTS_0473_PRE_RENDER_PAIR_STATUS_0266 = rawget(_G, "tech_priests_0266_render_pair_status")
  _G.tech_priests_0266_render_pair_status = function(pair, text, color)
    return M.emit(pair, text, color, M.default_ttl, 0.62, "survival-status-0266")
  end

  -- Reassert the 0471 wrappers in case a legacy fragment or late recovery file
  -- replaced them after that module first installed.
  _G.tech_priests_draw_stacked_status_text_0211 = function(pair, text, color, ttl, scale, channel)
    return M.emit(pair, text, color, ttl or M.default_ttl, scale or 0.62, channel or "stacked-status-0211")
  end
  _G.tech_priests_draw_emergency_operation_status_0184 = function(pair, text)
    return M.emit(pair, text, { r = 1.0, g = 0.55, b = 0.12, a = 0.95 }, M.default_ttl, 0.62, "emergency-status-0184")
  end
  _G.tech_priests_task_force_snippet_0187 = function(pair, text)
    return M.emit(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, M.default_ttl, 0.62, "task-force-0187")
  end
  _G.tech_priests_task_force_snippet_0188 = _G.tech_priests_task_force_snippet_0187

  if script and script.on_nth_tick then
    if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
      TechPriestsRuntimeEventRegistry.on_nth_tick(17, M.update_all, { owner = "overhead-text-authority-0473", category = "visuals" })
    else
      pcall(function() script.on_nth_tick(17, M.update_all) end)
    end
  end

  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-overhead-authority-0473") end end)
    pcall(function()
      commands.add_command("tp-overhead-authority-0473", "Tech Priests: report the canonical overhead text authority state.", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        local root = ensure_root()
        if player and player.valid then
          player.print("[tp-overhead-authority-0473] enabled=" .. safe(root.enabled) .. " routed=" .. safe(root.stats.routed or 0) .. " pending=" .. safe(root.stats.pending or 0))
        end
      end)
    end)
  end
  if log then log("[Tech-Priests 0.1.473] single-slot overhead text authority installed") end
  return true
end

return M
