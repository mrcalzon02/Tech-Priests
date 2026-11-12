-- Tech-Priests: user-approved condenser V22C, real Blender Cycles, Factorio 2.1.
-- Load from data-final-fixes.lua only AFTER every atlas PNG has been committed
-- and validated. Never change fluid production recipe, burner inventory or
-- 2x2 collision footprint; only graphics, machine icon and output port slot.
local name = 'tech-priests-atmospheric-water-condenser'
local target = assert(data.raw['assembling-machine'] and data.raw['assembling-machine'][name],
  'Condenser V22C source prototype missing')
local dir = '__tech-priests__/graphics/entity/atmospheric-water-condenser-v22c/'

-- Fixed Wube 45-degree camera; Blender positive yaw E/W is opposite Factorio.
-- Native pipe outlet is on the 2x2 east rear-row (x=1,y=-0.5 in scene).
local captured = {north='north', east='west_native', south='south', west='east_native'}
local order = {'north','east','south','west'}
local FRAMES = 32
local SLICES = 4
local SLICE_SIZE = 8
local TICKS_PER_CYCLE = 12 * 60
local function frame_path(which, original, resolution, chunk)
  if which == 'idle' then
    return dir .. 'idle-' .. original .. '-' .. resolution .. '.png'
  end
  return dir .. string.format('active-%s-%s-%02d.png', original, resolution, chunk)
end
-- The 256px standard sheets are genuine downscaled Cycles exports, not
-- reconstructed or procedurally substituted pixels. Their 0.4 scale keeps
-- precisely the same placement as 512px at 0.2.
local quality_setting = settings and settings.startup and
    settings.startup["tech-priests-condenser-sprite-quality"]
local quality = quality_setting and quality_setting.value or 'auto'
assert(quality == 'auto' or quality == 'high' or quality == 'standard',
       'Unsupported condenser graphics quality: ' .. tostring(quality))
local resolution = quality == 'standard' and 'sd' or 'hr'
local frame_size = resolution == 'sd' and 256 or 512
local world_scale = resolution == 'sd' and 0.4 or 0.2
assert(math.abs(frame_size * world_scale - 102.4) < 0.001,
       'Condenser HR and SD sprite footprint registration diverged')
local function animation(which, facing)
  local original = assert(captured[facing], 'Unknown condenser facing')
  local paths={}
  for i = 0,SLICES-1 do
    paths[#paths+1]=frame_path(which,original,resolution,i)
  end
  return {
    filenames=paths,
    priority='high',
    width=frame_size,height=frame_size,
    frame_count=FRAMES,
    line_length=4,
    slice=SLICE_SIZE,
    lines_per_file=2,
    animation_speed=FRAMES / TICKS_PER_CYCLE,
    run_mode='forward',
    scale=world_scale,
    shift={0,0},
    allow_reducing_frames=false,
    -- Auto gives Factorio permission to reduce high-res on limited hardware.
    -- High explicitly preserves the full resolution; Standard loads SD PNGs.
    allow_forced_downscale=(quality == 'auto'),
  }
end
local active, idle={},{}
for _,facing in ipairs(order) do
  active[facing]=animation('active',facing)
  idle[facing]=animation('idle',facing)
end
-- Both sets have 32 frames, required by Factorio 2.1 WorkingVisualisations.
-- Idle files repeat frame 1 in eight-frame slices; duplicate filenames share
-- the same source. Actual SD files are selectable by the startup quality option.
target.graphics_set={
  animation=active,
  idle_animation=idle,
  always_draw_idle_animation=false,
}
target.graphics_set_flipped=nil
target.animation=nil
target.animations=nil
target.match_animation_speed_to_activity=false
target.animation_random_start_frame=false

-- Keep exactly the existing fuel-fed atmospheric condensation output fluidbox.
-- The source prototype has one output and no liquid input. At 2x2, the right
-- edge and rear row are placed at {0.5,-0.5} (the direction supplies the edge).
local boxes = assert(target.fluid_boxes, 'Condenser output fluidbox absent')
assert(#boxes==1 and boxes[1].production_type=='output', 'Condenser output fluidbox contract drift')
assert(type(boxes[1].pipe_connections)=='table' and #boxes[1].pipe_connections==1,
       'Condenser must have one physical output socket')
local port=boxes[1].pipe_connections[1]
assert(port.flow_direction=='output' and port.direction==defines.direction.east,
       'Condenser native east-only output changed')
port.position={0.5,-0.5}
-- Only authored mist is used as the active visual; no independent random smoke
-- that could look like an exhaust burst coming out during an intake stroke.
if target.energy_source and target.energy_source.type=='burner' then
  target.energy_source.smoke=nil
end

local icon = dir .. 'icon-64.png'
target.icon,target.icons,target.icon_size=icon,nil,64
for _,kind in ipairs({'item','recipe'}) do
  local prototype=(data.raw[kind] or {})[name]
  if prototype then
    prototype.icon,prototype.icons,prototype.icon_size=icon,nil,64
  end
end
