-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

function spawn_sacred_incense_smoke_particle(surface, position, force, entity_name)
  if not (surface and position) then return end
  local smoke_name = entity_name or SACRED_INCENSE_CLOUD_ENTITY_NAME
  pcall(function()
    -- These are trivial-smoke prototypes now, copied from the vanilla atomic
    -- smoke approach. Prefer the dedicated smoke API when available, and fall
    -- back to create_entity for compatibility with older runtime behavior.
    if surface.create_trivial_smoke then
      surface.create_trivial_smoke({
        name = smoke_name,
        position = position
      })
    else
      surface.create_entity({
        name = smoke_name,
        position = position,
        force = force
      })
    end
  end)
end

function spawn_sacred_incense_smoke_ring(surface, position, force, radius, count, phase, entity_name)
  if not (surface and position) then return end
  radius = radius or 0
  count = math.max(1, count or 1)
  phase = phase or 0

  if radius <= 0.15 then
    spawn_sacred_incense_smoke_particle(surface, position, force, entity_name)
    return
  end

  for i = 1, count do
    local angle = ((i - 1) / count + phase) * math.pi * 2
    local cloud_position = {
      x = position.x + math.cos(angle) * radius,
      y = position.y + math.sin(angle) * radius
    }
    spawn_sacred_incense_smoke_particle(surface, cloud_position, force, entity_name)
  end
end

function spawn_sacred_incense_initial_smoke(surface, position, force)
  -- Atomic-smoke direction: only a few large, transparent, long-lived trivial-smoke
  -- bodies at impact. They bloom outward using the smoke prototype itself rather
  -- than being continuously emitted as roiling tendrils.
  spawn_sacred_incense_smoke_particle(surface, position, force, SACRED_INCENSE_CLOUD_ENTITY_NAME)

  local offsets = {
    { x = 1.75, y = -1.05, entity = SACRED_INCENSE_CLOUD_SOFT_ENTITY_NAME },
    { x = -1.55, y = 1.25, entity = SACRED_INCENSE_CLOUD_FAINT_ENTITY_NAME }
  }

  for _, offset in pairs(offsets) do
    spawn_sacred_incense_smoke_particle(surface, {
      x = position.x + offset.x,
      y = position.y + offset.y
    }, force, offset.entity)
  end
end

function spawn_sacred_incense_expanding_smoke(cloud)
  local surface = cloud.surface_index and game.surfaces[cloud.surface_index] or nil
  if not surface then return false end
  local position = cloud.position
  if not position then return false end

  local force = cloud.force_name and game.forces[cloud.force_name] or nil
  local started = cloud.created_tick or game.tick
  local elapsed = math.max(0, game.tick - started)
  local lifetime = math.max(1, (cloud.expires or game.tick) - started)
  local progress = math.min(1, elapsed / lifetime)

  -- Extremely sparse visual top-up: after the three initial long-lived nuclear
  -- haze bodies, add only one or two faint outer wisps over the whole lifetime.
  -- These should read as the edge of the blessing expanding, not as another
  -- smoke generator.
  local step = cloud.visual_step or 0
  if step >= SACRED_INCENSE_CLOUD_MAX_VISUAL_PULSES then
    return true
  end

  local max_radius = cloud.radius or SACRED_INCENSE_GRENADE_RADIUS
  local pulse_progress = (step + 1) / (SACRED_INCENSE_CLOUD_MAX_VISUAL_PULSES + 1)
  local ring_radius = math.max(1.0, max_radius * pulse_progress)
  local phase = (step * 0.311) % 1

  spawn_sacred_incense_smoke_ring(surface, position, force, ring_radius, 1, phase, SACRED_INCENSE_CLOUD_FAINT_ENTITY_NAME)

  cloud.visual_step = step + 1
  return true
end

function add_active_sacred_incense_cloud(surface, position, force, player_index)
  ensure_storage()
  if not (surface and position) then return end

  local cloud = {
    surface_index = surface.index,
    position = { x = position.x, y = position.y },
    force_name = force and force.valid and force.name or nil,
    player_index = player_index,
    radius = SACRED_INCENSE_GRENADE_RADIUS,
    restore_amount = SACRED_INCENSE_CLOUD_TICK_RESTORE_AMOUNT,
    created_tick = game.tick,
    visual_step = 0,
    next_visual_tick = game.tick + SACRED_INCENSE_CLOUD_VISUAL_PULSE_INTERVAL,
    next_tick = game.tick + SACRED_INCENSE_CLOUD_TICK_INTERVAL,
    expires = game.tick + SACRED_INCENSE_CLOUD_DURATION_TICKS
  }

  table.insert(storage.tech_priests.active_incense_clouds, cloud)
end

function tick_sacred_incense_cloud(cloud)
  local surface = cloud.surface_index and game.surfaces[cloud.surface_index] or nil
  if not surface then return false end

  local position = cloud.position
  local radius = cloud.radius or SACRED_INCENSE_GRENADE_RADIUS
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }

  local filters = { area = area, name = CONSECRATION_TARGET_NAME_LIST }
  if cloud.force_name and game.forces[cloud.force_name] then
    filters.force = game.forces[cloud.force_name]
  end

  local entities = surface.find_entities_filtered(filters)
  local circular_targets = {}
  local radius_sq = radius * radius
  for _, entity in pairs(entities) do
    local dx = entity.position.x - position.x
    local dy = entity.position.y - position.y
    if dx * dx + dy * dy <= radius_sq then
      circular_targets[#circular_targets + 1] = entity
    end
  end

  local valid_targets = collect_consecration_targets_from_entities(circular_targets)
  if #valid_targets == 0 then return true end

  local player = cloud.player_index and game.get_player(cloud.player_index) or nil
  local restored_count = restore_consecration_targets(valid_targets, cloud.restore_amount or SACRED_INCENSE_CLOUD_TICK_RESTORE_AMOUNT, player)

  -- The smoke field itself is now intentionally sparse and long-lived. Do not
  -- spawn per-machine smoke on every sanctification tick; that becomes too dense
  -- when several grenades overlap.

  return true
end

function process_active_sacred_incense_clouds()
  ensure_storage()
  local clouds = storage.tech_priests.active_incense_clouds
  if not clouds then return end

  local tick = game.tick
  for i = #clouds, 1, -1 do
    local cloud = clouds[i]
    if not cloud or tick >= (cloud.expires or 0) then
      table.remove(clouds, i)
    else
      if tick >= (cloud.next_visual_tick or 0) then
        spawn_sacred_incense_expanding_smoke(cloud)
        cloud.next_visual_tick = tick + SACRED_INCENSE_CLOUD_VISUAL_PULSE_INTERVAL
      end
      if tick >= (cloud.next_tick or 0) then
        tick_sacred_incense_cloud(cloud)
        cloud.next_tick = tick + SACRED_INCENSE_CLOUD_TICK_INTERVAL
      end
    end
  end
end

function apply_sacred_incense_impact(event)
  if not (event and event.effect_id == SACRED_INCENSE_IMPACT_EFFECT_ID and event.target_position) then return end
  local surface = game.surfaces[event.surface_index]
  if not surface then return end

  local position = event.target_position
  local source = event.source_entity
  local force = source and source.valid and source.force or nil
  local player = event.source_player_index and game.get_player(event.source_player_index) or nil

  spawn_sacred_incense_initial_smoke(surface, position, force)
  add_active_sacred_incense_cloud(surface, position, force, event.source_player_index)

  if source and source.valid then
    source.surface.play_sound({ path = "utility/confirm", position = position })
  else
    surface.play_sound({ path = "utility/confirm", position = position })
  end

  if player and player.valid then
    player.create_local_flying_text({
      text = { "tech-priests-consecration.incense-cloud-restored", tostring(SACRED_INCENSE_CLOUD_DURATION_SECONDS) },
      position = position
    })
  end
end


return { name = 'scripts.core.consecration.incense', version = '0.1.347' }
