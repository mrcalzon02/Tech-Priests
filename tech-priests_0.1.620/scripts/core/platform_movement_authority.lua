-- Tech Priests — platform movement authority.
-- 0.1.430: documents and owns the legitimate space-platform exception to the
-- ground-priest movement-controller rule.  Ground priests must move through
-- movement_controller.lua; void/platform priests may use tiny validated hover
-- translations because Factorio unit pathing is unreliable across platform
-- machinery, belts, seams, and void edge cases.

local PlatformMovementAuthority = {}

local function now()
  return (game and game.tick) or 0
end

local function valid_entity(entity)
  return entity and entity.valid
end

local function pos_copy(pos)
  if not pos then return nil end
  return { x = pos.x or 0, y = pos.y or 0 }
end

function PlatformMovementAuthority.is_platform_pair(pair)
  if not (pair and pair.priest and pair.station) then return false end
  if tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(function() return tech_priests_pair_on_space_platform_0204(pair) end)
    if ok and result then return true end
  end
  if tech_priests_platform_pair_0206 then
    local ok, result = pcall(function() return tech_priests_platform_pair_0206(pair) end)
    if ok and result then return true end
  end
  if pair.station and pair.station.valid and pair.station.name == "void-cogitator-station" then return true end
  return false
end

function PlatformMovementAuthority.describe(pair)
  local path = pair and pair.space_platform_pathing_0209 or nil
  if not path then return "no-platform-path" end
  local target = path.target
  local tx = target and string.format("%.2f", target.x or 0) or "nil"
  local ty = target and string.format("%.2f", target.y or 0) or "nil"
  return "active=" .. tostring(path.active)
    .. " hover=" .. tostring(path.hover_glide_0220)
    .. " reason=" .. tostring(path.reason or path.owner or "unknown")
    .. " target=(" .. tx .. "," .. ty .. ")"
    .. " last_step=" .. tostring(path.last_hover_step_tick_0220 or path.last_step_tick_0216 or "never")
end

function PlatformMovementAuthority.begin_hover(pair, destination, reason)
  if not (PlatformMovementAuthority.is_platform_pair(pair) and valid_entity(pair.priest) and valid_entity(pair.station) and destination) then return false end
  local pos = pos_copy(destination.position or destination)
  if not pos then return false end
  if tech_priests_0220_begin_hover_glide then
    local ok, result = pcall(function() return tech_priests_0220_begin_hover_glide(pair, pos, reason or "platform movement authority") end)
    if ok and result then
      pair.last_platform_movement_authority_0430 = {
        tick = now(),
        reason = reason or "platform movement authority",
        action = "begin-hover",
        x = pos.x,
        y = pos.y
      }
      return true
    end
  end
  pair.space_platform_pathing_0209 = pair.space_platform_pathing_0209 or {}
  pair.space_platform_pathing_0209.active = true
  pair.space_platform_pathing_0209.hover_glide_0220 = true
  pair.space_platform_pathing_0209.target = pos
  pair.space_platform_pathing_0209.reason = reason or "platform movement authority fallback"
  pair.space_platform_pathing_0209.started_tick = pair.space_platform_pathing_0209.started_tick or now()
  pair.space_platform_pathing_0209.last_seen_tick = now()
  pair.last_platform_movement_authority_0430 = {
    tick = now(),
    reason = reason or "platform movement authority fallback",
    action = "begin-hover-fallback",
    x = pos.x,
    y = pos.y
  }
  return true
end

function PlatformMovementAuthority.hover_translate(pair, destination, reason)
  if not (PlatformMovementAuthority.is_platform_pair(pair) and valid_entity(pair.priest) and valid_entity(pair.station) and destination) then return false end
  local priest = pair.priest
  local pos = pos_copy(destination.position or destination)
  if not pos then return false end
  -- This is the explicit platform exception: a small hover/translation step, not
  -- ground walking, not return-to-station snapping, and not ordinary AI pathing.
  local ok, moved = pcall(function() return priest.teleport(pos, priest.surface) end)
  if ok and moved ~= false then
    local path = pair.space_platform_pathing_0209
    if path then path.last_seen_tick = now() end
    pair.last_platform_movement_authority_0430 = {
      tick = now(),
      reason = reason or "platform hover translation",
      action = "hover-translate",
      x = pos.x,
      y = pos.y
    }
    return true
  end
  pair.last_platform_movement_authority_0430 = {
    tick = now(),
    reason = reason or "platform hover translation refused",
    action = "hover-translate-failed",
    x = pos.x,
    y = pos.y
  }
  return false
end

function PlatformMovementAuthority.stop(pair, reason)
  if not pair then return false end
  if pair.space_platform_pathing_0209 then
    pair.space_platform_pathing_0209.active = false
    pair.space_platform_pathing_0209.stopped_reason_0430 = reason or "platform authority stop"
    pair.space_platform_pathing_0209.stopped_tick_0430 = now()
  end
  pair.last_platform_movement_authority_0430 = {
    tick = now(),
    reason = reason or "platform authority stop",
    action = "stop"
  }
  return true
end

function PlatformMovementAuthority.install()
  _G.tech_priests_platform_begin_hover_0430 = function(pair, destination, reason)
    return PlatformMovementAuthority.begin_hover(pair, destination, reason)
  end
  _G.tech_priests_platform_hover_translate_0430 = function(pair, destination, reason)
    return PlatformMovementAuthority.hover_translate(pair, destination, reason)
  end
  _G.tech_priests_platform_stop_0430 = function(pair, reason)
    return PlatformMovementAuthority.stop(pair, reason)
  end
  _G.tech_priests_platform_movement_summary_0430 = function(pair)
    return PlatformMovementAuthority.describe(pair)
  end
end

return PlatformMovementAuthority
