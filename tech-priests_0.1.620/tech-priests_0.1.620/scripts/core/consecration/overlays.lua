-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

clear_sanctification_overlay = function(entity_or_unit)
  ensure_storage()
  local unit = nil
  if type(entity_or_unit) == "number" then
    unit = entity_or_unit
  elseif entity_or_unit and entity_or_unit.unit_number then
    unit = entity_or_unit.unit_number
  end
  if not unit then return end

  local overlay = storage.tech_priests.consecration.overlays[unit]
  if overlay then
    destroy_render_objects(overlay)
    storage.tech_priests.consecration.overlays[unit] = nil
  end
end

function overlay_strength_bucket(severity)
  severity = math.max(0, math.min(1, severity or 0))
  return math.floor(severity * SANCTIFICATION_OVERLAY_BUCKETS + 0.5)
end

function get_sanctification_overlay_sprite(record, overlay_kind)
  local entity = record and record.entity
  local name = entity and entity.valid and entity.name or nil

  if name and SANCTIFICATION_VEHICLE_OVERLAY_NAMES[name] then
    if overlay_kind == "grime" then return SANCTIFICATION_VEHICLE_SLIME_OVERLAY_SPRITE end
    if overlay_kind == "sheen" then return SANCTIFICATION_VEHICLE_GLOW_OVERLAY_SPRITE end
  end

  local machine = name and SANCTIFICATION_MACHINE_OVERLAY_SPRITES[name] or nil
  if machine and machine[overlay_kind] then return machine[overlay_kind] end

  if overlay_kind == "grime" then return SANCTIFICATION_GRIME_OVERLAY_SPRITE end
  return SANCTIFICATION_SHEEN_OVERLAY_SPRITE
end

function get_machine_overlay_state(record)
  local percent = get_sanctification_percent(record)

  -- Master-plan neutral band: 45%-55% is visually calm. Below 45%, the
  -- machine darkens toward the 5% misery floor. Above 55%, it gains a gentle
  -- sanctified sheen/glow. Neither state is allowed to become a blinding decal.
  if percent < 0.45 then
    local severity = math.max(0, math.min(1, (0.45 - percent) / 0.40))
    local bucket = overlay_strength_bucket(severity)
    local bucket_severity = bucket / SANCTIFICATION_OVERLAY_BUCKETS
    return {
      sprite = get_sanctification_overlay_sprite(record, "grime"),
      overlay_kind = "grime",
      bucket = bucket,
      -- Quantized tint prevents tiny sanctification changes from repeatedly
      -- recreating the sprite and producing a visible pulse/flicker.
      -- The grime sprite now carries black/green/brown dirt coloration itself.
      -- Keep tint close to neutral so scratches, grease and oil staining remain visible.
      tint = { r = 0.92, g = 0.96, b = 0.82, a = 0.36 + 0.54 * bucket_severity }
    }
  elseif percent > 0.55 then
    local severity = math.max(0, math.min(1, (percent - 0.55) / 0.45))
    local bucket = overlay_strength_bucket(severity)
    local bucket_severity = bucket / SANCTIFICATION_OVERLAY_BUCKETS
    local gold = { r = 1.00, g = 0.74, b = 0.18, a = 0.12 + 0.20 * bucket_severity }
    local white = { r = 1.00, g = 1.00, b = 0.90, a = 0.16 + 0.16 * bucket_severity }
    return {
      sprite = get_sanctification_overlay_sprite(record, "sheen"),
      overlay_kind = "sheen",
      bucket = bucket,
      tint = interpolate_color(gold, white, math.max(0, percent - 1.0) / 0.20)
    }
  end

  return nil
end

function tech_priests_overlay_scale_factor_0567(record)
  local entity = record and record.entity
  local etype = entity and entity.valid and entity.type or nil
  if etype == "furnace" or etype == "mining-drill" then return 0.50 end
  return 1.00
end

function get_overlay_orientation(unit_number)
  -- Deterministic per-machine rotation so grime patches are not all identical,
  -- but they also do not jitter frame-to-frame.
  local seed = tonumber(unit_number or 0) or 0
  local mixed = (seed * 1103515245 + 12345) % 2001
  return ((mixed - 1000) / 1000) * 0.03
end

function deterministic_unit_noise(unit_number, index, salt)
  local seed = (tonumber(unit_number or 0) or 0) + (index or 0) * 7919 + (salt or 0) * 104729
  local mixed = (seed * 1103515245 + 12345) % 2147483647
  return mixed / 2147483647
end

function grime_patch_layout(unit_number, count)
  -- Runtime rendering cannot inherit Space Age's internal freeze shader/mask.
  -- Instead of one large square decal, draw several deterministic grime patches
  -- within a soft assembler-shaped scatter region. This reads like a tiled
  -- dirty texture without painting a black square over belts and floor tiles.
  local patches = {}
  local fallback = {
    { -0.60, -0.80 }, { 0.00, -0.88 }, { 0.55, -0.72 },
    { -0.78, -0.25 }, { -0.15, -0.18 }, { 0.48, -0.20 },
    { -0.50, 0.36 }, { 0.05, 0.42 }, { 0.62, 0.28 }
  }

  for i = 1, count do
    local base = fallback[((i - 1) % #fallback) + 1]
    local jx = (deterministic_unit_noise(unit_number, i, 1) - 0.5) * 0.28
    local jy = (deterministic_unit_noise(unit_number, i, 2) - 0.5) * 0.24
    patches[#patches + 1] = {
      offset = { base[1] + jx, base[2] + jy },
      orientation = deterministic_unit_noise(unit_number, i, 3),
      scale = SANCTIFICATION_GRIME_PATCH_BASE_SCALE * (0.78 + deterministic_unit_noise(unit_number, i, 4) * 0.44)
    }
  end

  return patches
end

update_sanctification_overlay = function(record, force)
  if not (record and record.entity and record.entity.valid) then return end
  ensure_storage()

  local unit = record.entity.unit_number
  if not unit then return end
  if not force and game.tick < (record.next_overlay_refresh_tick or 0) then return end
  record.next_overlay_refresh_tick = game.tick + SANCTIFICATION_OVERLAY_REFRESH_TICKS

  local state = get_machine_overlay_state(record)
  local existing = storage.tech_priests.consecration.overlays[unit]

  if not state then
    if existing then clear_sanctification_overlay(unit) end
    return
  end

  local orientation = get_overlay_orientation(unit)
  local overlay_scale_factor_0567 = tech_priests_overlay_scale_factor_0567(record)
  local pattern_key = state.sprite .. ":" .. tostring(state.bucket) .. ":scale=" .. tostring(overlay_scale_factor_0567)

  if state.overlay_kind == "grime" then
    local patch_count = math.max(2, math.min(SANCTIFICATION_GRIME_PATCH_COUNT_MAX, 3 + math.floor((state.bucket or 0) * 0.85)))
    pattern_key = pattern_key .. ":patches=" .. tostring(patch_count)

    if existing and existing.objects and existing.pattern_key == pattern_key then
      return
    end

    if existing then clear_sanctification_overlay(unit) end

    local objects = {}
    for _, patch in pairs(grime_patch_layout(unit, patch_count)) do
      local ok, sprite = pcall(function()
        return rendering.draw_sprite({
          sprite = state.sprite,
          target = { entity = record.entity, offset = patch.offset },
          surface = record.entity.surface,
          tint = state.tint,
          x_scale = patch.scale * overlay_scale_factor_0567,
          y_scale = patch.scale * overlay_scale_factor_0567,
          orientation = patch.orientation,
          -- Keep persistent grime decals below smoke/explosion effects so damage and incense puffs render on top.
          render_layer = "higher-object-under"
        })
      end)
      if ok and sprite then objects[#objects + 1] = sprite end
    end

    if #objects > 0 then
      storage.tech_priests.consecration.overlays[unit] = {
        objects = objects,
        sprite = state.sprite,
        bucket = state.bucket,
        pattern_key = pattern_key
      }
    end
    return
  end

  -- High sanctity sheen is still a single mild glow layer, but it must also be
  -- destroyed/replaced correctly when the machine returns to neutral or dirty.
  if existing and existing.object then
    local ok_valid, valid = pcall(function() return existing.object.valid end)
    if ok_valid and valid and existing.sprite == state.sprite and existing.bucket == state.bucket and existing.orientation == orientation then
      return
    end
  end

  if existing then clear_sanctification_overlay(unit) end

  local ok, sprite = pcall(function()
    return rendering.draw_sprite({
      sprite = state.sprite,
      target = { entity = record.entity, offset = { 0, -0.12 } },
      surface = record.entity.surface,
      tint = state.tint,
      x_scale = SANCTIFICATION_OVERLAY_SCALE * overlay_scale_factor_0567,
      y_scale = SANCTIFICATION_OVERLAY_SCALE * overlay_scale_factor_0567,
      orientation = orientation,
      -- Keep persistent sanctification sheen below smoke/explosion effects for consistent visual layering.
      render_layer = "higher-object-under"
    })
  end)

  if ok and sprite then
    storage.tech_priests.consecration.overlays[unit] = {
      object = sprite,
      sprite = state.sprite,
      bucket = state.bucket,
      orientation = orientation,
      pattern_key = pattern_key
    }
  end
end

function get_sanctification_bar_color(record)
  local value = record.sanctification or 0
  local base_max = math.max(1, get_base_sanctification_max(record and record.entity and record.entity.valid and record.entity.force or nil))
  local percent_of_original_max = value / base_max

  local gray = { r = 0.45, g = 0.45, b = 0.45, a = 0.92 }
  local green = { r = 0.20, g = 0.95, b = 0.30, a = 0.94 }
  local gold = { r = 1.00, g = 0.78, b = 0.12, a = 0.96 }
  local white = { r = 1.00, g = 1.00, b = 0.92, a = 0.98 }

  -- 0.1.417: color by original/base capacity, not the damaged surviving cap.
  -- A machine at 50/50 due to permanent maximum-sanctity damage should not look
  -- like a pristine gold 100% machine.  The red scar shows lost max; the fill
  -- color now honestly follows remaining absolute sanctity.
  if percent_of_original_max <= 0.5 then
    return interpolate_color(gray, green, percent_of_original_max / 0.5)
  elseif percent_of_original_max <= 1.0 then
    return interpolate_color(green, gold, (percent_of_original_max - 0.5) / 0.5)
  else
    return interpolate_color(gold, white, math.min(1, percent_of_original_max - 1.0))
  end
end

draw_sanctification_label = function(record)
  if not (record and record.entity and record.entity.valid) then return end
  ensure_storage()
  local unit = record.entity.unit_number
  local previous = storage.tech_priests.consecration.renders[unit]
  if previous then destroy_render_objects(previous) end

  local entity = record.entity
  local base_max = math.max(1, get_base_sanctification_max(entity.force))
  local max_value = record.max_sanctification or base_max
  max_value = math.max(0, math.min(base_max, max_value))

  -- The bar now represents the original/base maximum sanctification, not the
  -- currently surviving maximum. This makes permanent machine-spirit capacity
  -- damage visible: current sanctification fills from the left, while destroyed
  -- maximum capacity is painted as a red scar expanding inward from the right.
  local current_max_ratio = math.max(0, math.min(1, max_value / base_max))
  local value_ratio = math.max(0, math.min(current_max_ratio, (record.sanctification or 0) / base_max))

  -- Preserve the old tiny floor indicator for machines that still have some
  -- sanctification, but do not allow it to draw into the red degraded-capacity
  -- scar.
  if (record.sanctification or 0) > 0 then
    value_ratio = math.max(math.min(get_minimum_sanctification_value_fraction(), current_max_ratio), value_ratio)
  end

  local lost_max_ratio = math.max(0, 1 - current_max_ratio)
  local half_width = SANCTIFICATION_BAR_WIDTH / 2
  local fill_right = -half_width + (SANCTIFICATION_BAR_WIDTH * value_ratio)
  local max_right = -half_width + (SANCTIFICATION_BAR_WIDTH * current_max_ratio)
  local y = SANCTIFICATION_BAR_Y_OFFSET
  local h = SANCTIFICATION_BAR_HEIGHT

  local ok, result = pcall(function()
    local background = rendering.draw_rectangle({
      color = { r = 0.02, g = 0.02, b = 0.02, a = 0.72 },
      filled = true,
      left_top = { entity = entity, offset = { -half_width - 0.04, y - 0.04 } },
      right_bottom = { entity = entity, offset = { half_width + 0.04, y + h + 0.04 } },
      surface = entity.surface,
      time_to_live = SANCTIFICATION_RENDER_TTL
    })

    local degraded_max = nil
    local degraded_outline = nil
    local degraded_ticks = nil
    if lost_max_ratio > 0.001 then
      -- Draw the lost maximum capacity as an aggressive, high-alpha red block.
      -- It deliberately overlaps the bar frame slightly so even small losses are
      -- visible during normal mouseover inspection.
      degraded_max = rendering.draw_rectangle({
        color = { r = 1.00, g = 0.00, b = 0.00, a = 0.96 },
        filled = true,
        left_top = { entity = entity, offset = { max_right, y - 0.015 } },
        right_bottom = { entity = entity, offset = { half_width, y + h + 0.015 } },
        surface = entity.surface,
        time_to_live = SANCTIFICATION_RENDER_TTL
      })

      degraded_outline = rendering.draw_rectangle({
        color = { r = 1.00, g = 0.18, b = 0.12, a = 1.00 },
        filled = false,
        width = 2,
        left_top = { entity = entity, offset = { max_right, y - 0.025 } },
        right_bottom = { entity = entity, offset = { half_width, y + h + 0.025 } },
        surface = entity.surface,
        time_to_live = SANCTIFICATION_RENDER_TTL
      })

      degraded_ticks = {}
      local lost_width = half_width - max_right
      local tick_count = math.max(1, math.min(4, math.floor(lost_width / 0.16)))
      for i = 1, tick_count do
        local tick_x = max_right + (lost_width * i / (tick_count + 1))
        degraded_ticks[#degraded_ticks + 1] = rendering.draw_line({
          color = { r = 0.35, g = 0.00, b = 0.00, a = 0.95 },
          width = 2,
          from = { entity = entity, offset = { tick_x - 0.035, y - 0.015 } },
          to = { entity = entity, offset = { tick_x + 0.035, y + h + 0.015 } },
          surface = entity.surface,
          time_to_live = SANCTIFICATION_RENDER_TTL
        })
      end
    end

    local fill = nil
    if value_ratio > 0 then
      fill = rendering.draw_rectangle({
        color = get_sanctification_bar_color(record),
        filled = true,
        left_top = { entity = entity, offset = { -half_width, y } },
        right_bottom = { entity = entity, offset = { fill_right, y + h } },
        surface = entity.surface,
        time_to_live = SANCTIFICATION_RENDER_TTL
      })
    end

    -- Draw the outer frame last so the red scar and normal fill both remain
    -- boxed inside one readable sanctification meter.
    local frame = rendering.draw_rectangle({
      color = { r = 1.0, g = 0.86, b = 0.24, a = 0.98 },
      filled = false,
      width = 2,
      left_top = { entity = entity, offset = { -half_width - 0.04, y - 0.04 } },
      right_bottom = { entity = entity, offset = { half_width + 0.04, y + h + 0.04 } },
      surface = entity.surface,
      time_to_live = SANCTIFICATION_RENDER_TTL
    })

    local label_id = nil
    local label_current = nil
    local label_lost = nil
    local label_x = half_width + 0.18
    local machine_id_text = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or nil
    if machine_id_text then
      label_id = rendering.draw_text({
        text = machine_id_text,
        target = { entity = entity, offset = { -half_width - 0.02, y - 0.34 } },
        surface = entity.surface,
        color = { r = 1.0, g = 0.84, b = 0.24, a = 0.98 },
        scale = 0.50,
        alignment = "left",
        time_to_live = SANCTIFICATION_RENDER_TTL
      })
    end
    local current_text = string.format("%.1f / %.1f", tonumber(record.sanctification or 0) or 0, max_value)
    label_current = rendering.draw_text({
      text = current_text,
      target = { entity = entity, offset = { label_x, y - 0.03 } },
      surface = entity.surface,
      color = { r = 0.38, g = 1.0, b = 0.42, a = 0.98 },
      scale = 0.58,
      alignment = "left",
      time_to_live = SANCTIFICATION_RENDER_TTL
    })

    if lost_max_ratio > 0.001 then
      label_lost = rendering.draw_text({
        text = string.format("-%.1f max", math.max(0, base_max - max_value)),
        target = { entity = entity, offset = { label_x, y + 0.17 } },
        surface = entity.surface,
        color = { r = 1.0, g = 0.12, b = 0.08, a = 0.98 },
        scale = 0.55,
        alignment = "left",
        time_to_live = SANCTIFICATION_RENDER_TTL
      })
    end

    return { background = background, degraded_max = degraded_max, degraded_outline = degraded_outline, degraded_ticks = degraded_ticks, frame = frame, fill = fill, label_id = label_id, label_current = label_current, label_lost = label_lost }
  end)

  if ok and result then
    storage.tech_priests.consecration.renders[unit] = result
  end
end


return { name = 'scripts.core.consecration.overlays', version = '0.1.452' }
