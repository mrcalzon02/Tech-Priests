-- Per-registered-drive visuals only. The existing service owns electric draw,
-- native fuel proxies and operation.sample; this module never resamples power.
-- API authority: installed Factorio 2.1.24 LuaRendering/LuaRenderObject/Color.
local Operation = require('scripts.core.void_fusion_operation')
local M = {}

local function finite(value)
  return type(value) == 'number' and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function valid(object)
  local kind = type(object)
  return (kind == 'table' or kind == 'userdata') and object.valid == true
end

local function destroy(object)
  if valid(object) then object.destroy() end
end

function M.clear(record)
  if type(record) ~= 'table' then return end
  local state = record.visuals
  if type(state) == 'table' then
    destroy(state.energy)
    destroy(state.plume)
  end
  record.visuals = nil
end

local function hide(state, status)
  for _, key in ipairs({'energy', 'plume'}) do
    if valid(state[key]) then
      state[key].visible = false
      state[key].color = {r=0, g=0, b=0, a=0}
    end
  end
  state.status = status
  state.normalized_level = 0
  state.powered = false
  state.factor = nil
  state.power_watts = nil
  state.render_errors = nil
  state.energy_visible = false
  state.plume_visible = false
  return state
end

-- Color is premultiplied in Factorio. Setting only alpha while keeping RGB=1
-- would not establish the requested additive-brightness/power relationship.
function M.power_tint(factor)
  if not finite(factor) or factor < Operation.minimum_factor
      or factor > Operation.maximum_factor then return nil end
  local level = factor / Operation.maximum_factor
  return {r=level, g=level, b=level, a=level}, level
end

-- LuaEntity has no supported thruster.thrust attribute in 2.1.24. Native
-- working status plus the platform's real route/paused state gates propulsion.
local function thrusting(entity, definitions)
  local platform = entity.surface.platform
  return valid(platform) and platform.paused == false
    and platform.state == definitions.space_platform_state.on_the_path
    and entity.status == definitions.entity_status.working
end

-- context.powered MUST be the existing service's actual sink-buffer decision
-- made after setting this sample's power_usage. context.family (or persisted
-- record.visual_family) supplies data-stage AnimationPrototype names:
-- {energy_animation, plume_animation, animation_speed=32/60, frame_count=64,
--  energy_render_layer='higher-object-above', plume_render_layer=...}.
-- Those prototypes contain normalized-at-peak additive art with runtime tint
-- enabled. Local crackle/particle motion may loop; no global brightness sine
-- is introduced here. Call only from normal events, never from on_load.
function M.update(record, context)
  context = context or {}
  local entity = record and record.thruster
  if not valid(entity) then M.clear(record); return nil end
  local family = context.family or record.visual_family
  if type(family) ~= 'table' or type(family.energy_animation) ~= 'string'
      or family.energy_animation == '' then
    M.clear(record)
    return nil, 'missing_visual_family'
  end
  local tick = context.tick or game.tick
  local speed = family.animation_speed or 32/60
  local frames = family.frame_count or 64
  local lease = context.lease_ticks or 120
  assert(finite(speed) and speed >= 0, 'Invalid fusion visual animation speed')
  assert(finite(frames) and frames >= 1 and frames == math.floor(frames),
    'Invalid fusion visual frame count')
  assert(finite(lease) and lease >= 1 and lease <= 3600
    and lease == math.floor(lease), 'Invalid fusion visual lease')
  local energy_layer = family.energy_render_layer or 'higher-object-above'
  local plume_layer = family.plume_render_layer or 'higher-object-above'
  local signature = table.concat({family.energy_animation,
    family.plume_animation or '', tostring(speed), tostring(frames),
    energy_layer, plume_layer}, '|')
  local state = record.visuals
  if type(state) ~= 'table' or state.version ~= 1
      or state.unit_number ~= entity.unit_number
      or state.surface_index ~= entity.surface.index
      or state.family_signature ~= signature then
    M.clear(record)
    state = {version=1, unit_number=entity.unit_number,
      surface_index=entity.surface.index, family_signature=signature}
    record.visuals = state
  end
  local sample = record.operation
  local tint, level = M.power_tint(sample and sample.factor)
  if not tint or sample.last_tick ~= tick then
    return hide(state, 'missing_or_stale_operation_sample')
  end
  local expected_watts = Operation.nominal_power_watts * sample.factor
  if not finite(sample.power_watts)
      or math.abs(sample.power_watts - expected_watts) > 0.01 then
    return hide(state, 'inconsistent_power_sample')
  end
  local powered = context.powered == true and valid(record.sink)
  local plume_active = powered and thrusting(entity, context.defines or defines)
  local renderer = context.renderer or rendering
  local errors = {}
  local function draw(key, name, layer, visible)
    local object = state[key]
    if type(name) ~= 'string' or name == '' then
      destroy(object); state[key] = nil; return
    end
    if not valid(object) then
      -- Entity targets automatically die with the entity or surface transfer.
      -- An expiring lease is a final backstop if a caller loses its record.
      local ok, result = pcall(function()
        return renderer.draw_animation{animation=name, target=entity,
          surface=entity.surface, render_layer=layer, animation_speed=speed,
          animation_offset=(sample.seed or entity.unit_number or 0) % frames,
          tint=powered and tint or {r=0,g=0,b=0,a=0},
          visible=visible, time_to_live=lease, light_mode='glow'}
      end)
      if not ok then errors[key] = tostring(result); return end
      if not valid(result) then
        errors[key] = 'draw_animation returned no valid render object'; return
      end
      object = result; state[key] = object
    end
    object.time_to_live = lease
    object.color = powered and tint or {r=0,g=0,b=0,a=0}
    object.visible = visible
  end
  draw('energy', family.energy_animation, energy_layer, powered)
  draw('plume', family.plume_animation, plume_layer, plume_active)
  state.last_tick = tick
  state.factor = sample.factor
  state.power_watts = sample.power_watts
  state.normalized_level = powered and level or 0
  state.energy_visible = powered and valid(state.energy)
  state.plume_visible = plume_active and valid(state.plume)
  state.powered = powered
  state.render_errors = next(errors) and errors or nil
  state.status = state.render_errors and 'render_creation_failed'
    or powered and 'powered' or 'unpowered'
  return state
end

-- Plain readback for native evidence; no LuaObject references enter JSON.
function M.snapshot(record)
  local state = record and record.visuals
  if type(state) ~= 'table' then return nil end
  local result = {status=state.status, factor=state.factor,
    power_watts=state.power_watts, normalized_level=state.normalized_level,
    powered=state.powered, last_tick=state.last_tick,
    render_errors=state.render_errors}
  for _, key in ipairs({'energy', 'plume'}) do
    local object = state[key]
    result[key] = valid(object) and {id=object.id, visible=object.visible,
      color=object.color, animation=object.animation,
      animation_speed=object.animation_speed, time_to_live=object.time_to_live}
      or {valid=false}
  end
  return result
end

return M
