-- scripts/core/hover_movement_stability.lua
-- Tech Priests 0.1.444 hover-selection and movement-churn stability layer.
--
-- This module does not own movement. Its job is to keep old debug mouse-over
-- refresh hooks from hammering the scheduler every tick while the player is
-- merely observing the radar/radius overlay. Actual ground movement remains in
-- movement_controller.lua; respawn/recreate remains in lifecycle modules.

local H = {}
H.version = "0.1.444"
H.mouseover_refresh_cooldown_ticks = 90
H.radar_refresh_cooldown_ticks = 45

local function now()
  return (game and game.tick) or 0
end

local function station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.hover_movement_stability_0444 = storage.tech_priests.hover_movement_stability_0444 or {
    version = H.version,
    stats = {}
  }
  local root = storage.tech_priests.hover_movement_stability_0444
  root.version = H.version
  root.stats = root.stats or {}
  return root
end

local function should_throttle(pair, source)
  if not (pair and pair.station and pair.station.valid) then return false end
  source = tostring(source or "")
  local tick = now()
  local cooldown = nil
  local field = nil
  if source == "mouse-over" then
    cooldown = H.mouseover_refresh_cooldown_ticks
    field = "last_mouseover_order_refresh_0444"
  elseif source == "radar-sweep" then
    cooldown = H.radar_refresh_cooldown_ticks
    field = "last_radar_order_refresh_0444"
  end
  if not field then return false end
  local last = tonumber(pair[field]) or -1000000
  if tick < last + cooldown then
    local root = ensure_root()
    root.stats.throttled = (root.stats.throttled or 0) + 1
    root.stats["throttled_" .. source] = (root.stats["throttled_" .. source] or 0) + 1
    pair.last_hover_refresh_throttled_0444 = { tick = tick, source = source, cooldown = cooldown }
    if source == "mouse-over" then pair.mouseover_emergency_handler_suppressed_tick_0444 = tick end
    return true
  end
  pair[field] = tick
  return false
end

function H.patch_order_refresh()
  if _G.tech_priests_0270_refresh_orders_for_pair and not _G.TECH_PRIESTS_0444_PRE_REFRESH_ORDERS then
    _G.TECH_PRIESTS_0444_PRE_REFRESH_ORDERS = _G.tech_priests_0270_refresh_orders_for_pair
    _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source)
      if should_throttle(pair, source) then return true end
      return _G.TECH_PRIESTS_0444_PRE_REFRESH_ORDERS(pair, source)
    end
  end

  if _G.handle_emergency_desperation_craft and not _G.TECH_PRIESTS_0444_PRE_HANDLE_EMERGENCY_CRAFT then
    _G.TECH_PRIESTS_0444_PRE_HANDLE_EMERGENCY_CRAFT = _G.handle_emergency_desperation_craft
    _G.handle_emergency_desperation_craft = function(pair, ...)
      if pair and pair.mouseover_emergency_handler_suppressed_tick_0444 == now() then
        local root = ensure_root()
        root.stats.mouseover_emergency_calls_suppressed = (root.stats.mouseover_emergency_calls_suppressed or 0) + 1
        return false
      end
      return _G.TECH_PRIESTS_0444_PRE_HANDLE_EMERGENCY_CRAFT(pair, ...)
    end
  end
end

function H.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-hover-stability-0444") end)
  commands.add_command("tp-hover-stability-0444", "Tech Priests: report hover refresh throttling and movement-churn stabilizer state.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not player then return end
    local root = ensure_root()
    local selected = player.selected
    local pair = nil
    if selected and selected.valid and _G.find_pair_for_entity then
      local ok, got = pcall(_G.find_pair_for_entity, selected)
      if ok then pair = got end
    end
    player.print("[tp-hover-stability-0444] throttled=" .. tostring(root.stats.throttled or 0)
      .. " mouse=" .. tostring(root.stats["throttled_mouse-over"] or 0)
      .. " radar=" .. tostring(root.stats["throttled_radar-sweep"] or 0)
      .. " emergency-suppressed=" .. tostring(root.stats.mouseover_emergency_calls_suppressed or 0))
    if pair then
      player.print("  selected station=#" .. tostring(station_unit(pair) or "?")
        .. " last-hover-throttle=" .. tostring(pair.last_hover_refresh_throttled_0444 and pair.last_hover_refresh_throttled_0444.tick or "none"))
    end
  end)
end

function H.install()
  ensure_root()
  H.patch_order_refresh()
  H.register_commands()
  if log then log("[Tech-Priests 0.1.444] hover movement stability installed; mouse-over/radar refresh no longer hammers movement each tick") end
  return true
end

return H
