-- scripts/core/radar_afterglow.lua
-- Tech Priests 0.1.334 radar sweeper afterglow visual repair.
-- Uses the uploaded wedge as a single rotating sweep afterglow, anchored at the
-- station/radar origin as if the sprite's lower-right corner were the pivot.
-- 0.1.334 locks the tested 0.25-turn orientation and removes public
-- calibration so future saves do not drift away from the verified alignment.

local Afterglow = {}
Afterglow.version = "0.1.465"
Afterglow.storage_key = "radar_afterglow_0334"
Afterglow.sprite = "tech-priests-radar-sweeper-afterglow"
Afterglow.default_ttl = 90
Afterglow.enabled = true
Afterglow.fixed_angle_offset_turns = 0.25

local function valid(e) return e and e.valid end

local function setting(name, default)
  if settings and settings.global and settings.global[name] then
    local v = settings.global[name].value
    if v ~= nil then return v end
  end
  return default
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Afterglow.storage_key] = storage.tech_priests[Afterglow.storage_key] or {
    version = Afterglow.version,
    enabled = true,
    objects_by_player = {},
    stats = {},
    angle_offset_turns = Afterglow.fixed_angle_offset_turns
  }
  local root = storage.tech_priests[Afterglow.storage_key]
  root.version = Afterglow.version
  -- 0.1.465: restore the uploaded RADARSweeper wedge by default.  The thing
  -- that must stay dead is the full-radius station-light/dinner-plate effect,
  -- not the actual sweep artwork.
  if root.enabled == nil then root.enabled = true end
  if root.force_disabled_0463 then root.force_disabled_0463 = nil; root.enabled = true end
  root.objects_by_player = root.objects_by_player or {}
  root.stats = root.stats or {}
  root.manual_angle_offset_turns = nil
  root.angle_offset_turns = Afterglow.fixed_angle_offset_turns
  return root
end

local function destroy(obj)
  if not obj then return end
  pcall(function() if obj.valid then obj.destroy() end end)
end

local function radius_for(pair)
  if pair and pair.station and pair.station.valid and _G.tech_priests_radar_operating_radius_0280 then
    local ok, r = pcall(_G.tech_priests_radar_operating_radius_0280, pair)
    if ok and tonumber(r) then return math.max(8, tonumber(r)) end
  end
  if pair and pair.station and pair.station.valid and _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, tonumber(r)) end
  end
  return tonumber(pair and pair.radius) or 30
end

local function rotated_lower_right_anchor_offset(scale, angle)
  -- Source image is 256x512 px, approximately 8x16 tiles at 32 px/tile.
  -- rendering.draw_sprite rotates around image center. Shift the target so that
  -- the lower-right corner remains at the station. The vector from the desired
  -- lower-right pivot to the image center is (-half_w, -half_h), rotated by the
  -- same final orientation used for the sprite.
  local half_w = 4.0 * scale
  local half_h = 8.0 * scale
  local lx = -half_w
  local ly = -half_h
  local c = math.cos(angle or 0)
  local s = math.sin(angle or 0)
  return { x = lx * c - ly * s, y = lx * s + ly * c }
end

local function pulse_alpha()
  local t = game and game.tick or 0
  return 0.30 + 0.10 * ((math.sin(t / 16) + 1) * 0.5)
end

local function draw_with_layer(spec)
  -- Prefer above-object readability without sitting above smoke/fog. If a layer
  -- name is not accepted by this Factorio build, pcall catches it and tries the
  -- next layer rather than dropping the radar entirely.
  local layers = { "higher-object", "object", "radius-visualization", nil }
  for _, layer in ipairs(layers) do
    spec.render_layer = layer
    local ok, obj = pcall(function() return rendering.draw_sprite(spec) end)
    if ok and obj then return obj, layer end
  end
  return nil, nil
end

function Afterglow.draw(player_state, player, station, center, radius, angle)
  local root = ensure_root()
  if not (root.enabled and player and player.valid and valid(station) and center and angle and rendering) then
    -- Disabled means the wrapper should fall through to the original phosphor
    -- line trail.  Only remove old radius-scaled afterglow sprites from prior
    -- saves; do not touch trail_0283, line, or endcap.
    if player_state then
      destroy(player_state.afterglow_0330)
      destroy(player_state.afterglow_0332)
      destroy(player_state.afterglow_0334)
      player_state.afterglow_0330 = nil
      player_state.afterglow_0332 = nil
      player_state.afterglow_0334 = nil
    end
    return false
  end
  player_state = player_state or {}

  local r = radius or radius_for({ station = station }) or 30
  local scale = math.max(0.35, r / 16)
  local offset_turns = Afterglow.fixed_angle_offset_turns
  local final_angle = (angle or 0) + (offset_turns * math.pi * 2)
  local orientation = (final_angle / (math.pi * 2)) % 1
  local offset = rotated_lower_right_anchor_offset(scale, final_angle)
  local tint = { r = 0.45, g = 1.0, b = 0.45, a = pulse_alpha() }

  local obj, layer = draw_with_layer({
    sprite = Afterglow.sprite,
    surface = station.surface,
    target = { entity = station, offset = offset },
    orientation = orientation,
    x_scale = scale,
    y_scale = scale,
    tint = tint,
    players = { player },
    time_to_live = Afterglow.default_ttl
  })
  if obj then
    destroy(player_state.afterglow_0330)
    destroy(player_state.afterglow_0332)
    destroy(player_state.afterglow_0334)
    player_state.afterglow_0334 = obj
    root.stats.draws = (root.stats.draws or 0) + 1
    root.stats.last_layer = layer or "default"
    root.stats.angle_offset_turns = offset_turns
    return true
  end
  root.stats.failures = (root.stats.failures or 0) + 1
  return false
end

function Afterglow.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-radar-afterglow-0334", "Tech Priests: report/toggle fixed radar sweeper afterglow visual.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      root.angle_offset_turns = Afterglow.fixed_angle_offset_turns
      player.print("[Tech Priests 0.1.334] radar afterglow enabled=" .. tostring(root.enabled) .. " draws=" .. tostring(root.stats.draws or 0) .. " failures=" .. tostring(root.stats.failures or 0) .. " layer=" .. tostring(root.stats.last_layer or "?") .. " fixed-offset-turns=" .. tostring(Afterglow.fixed_angle_offset_turns))
    end)
  end)
end

function Afterglow.install()
  ensure_root()
  if Afterglow._installed then return true end
  Afterglow._installed = true

  if _G.tech_priests_radar_draw_phosphor_trail_0283 and not _G.TECH_PRIESTS_0332_PRE_RADAR_PHOSPHOR_TRAIL then
    _G.TECH_PRIESTS_0332_PRE_RADAR_PHOSPHOR_TRAIL = _G.tech_priests_radar_draw_phosphor_trail_0283
    _G.tech_priests_radar_draw_phosphor_trail_0283 = function(player_state, player, station, center, radius, angle)
      local ok = Afterglow.draw(player_state, player, station, center, radius, angle)
      if not ok and _G.TECH_PRIESTS_0332_PRE_RADAR_PHOSPHOR_TRAIL then
        return _G.TECH_PRIESTS_0332_PRE_RADAR_PHOSPHOR_TRAIL(player_state, player, station, center, radius, angle)
      end
      return ok
    end
  elseif _G.tech_priests_radar_draw_phosphor_trail_0283 and not _G.TECH_PRIESTS_0330_PRE_RADAR_PHOSPHOR_TRAIL then
    -- Safety for saves that reached the 0.1.330 wrapper but not the 0.1.332 name.
    _G.TECH_PRIESTS_0330_PRE_RADAR_PHOSPHOR_TRAIL = _G.tech_priests_radar_draw_phosphor_trail_0283
  end

  Afterglow.register_commands()
  if log then log("[Tech-Priests 0.1.465] radar RADARSweeper afterglow restored; full-radius station-light remains suppressed") end
  return true
end

return Afterglow
