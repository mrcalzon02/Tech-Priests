-- Engineer pixels on the original character. This module only reads gameplay
-- state and owns presentation records/render objects; it never moves a body.
local PoseMap=require("shared.engineer_pose_map")
local M={data_name="tech-priests-engineer-visuals",host_name="tech-priests-custom-character"}
local catalog
local function data()
  if not catalog then
    local prototype=prototypes.mod_data[M.data_name]
    catalog=prototype and prototype.data
  end
  return catalog
end
M.catalog=data
function M.needed(entity)
  -- Retained historical renderer; no current player body is hidden or needs
  -- scripted Engineer art. Also refuse old catalog data after an upgrade.
  return false
end
local function object(id) return id and rendering.get_object_by_id(id) end
local function clear(rec)
  for _,id in pairs(rec.renders or {}) do
    local render=object(id)
    if render and render.valid then render.destroy() end
  end
  rec.renders={}
end
local function orientation(position,target,fallback)
  if not target then return fallback end
  local dx,dy=target.x-position.x,target.y-position.y
  if dx*dx+dy*dy<0.000001 then return fallback end
  return (math.atan2(dy,dx)/(2*math.pi)+.25)%1
end
local function direction8(value) return math.floor((value%1)*8+.5)%8 end

-- Observe every character model, including custom skins. Restoring Engineer
-- then retains the body's gun/aim history without changing native input.
function M.observe(rec)
  local entity=rec.entity
  if not (entity and entity.valid and entity.type=="character") then return end
  local source=data()
  if not source then return end
  local position=entity.position
  local height=entity.flight_height or 0
  local walking=entity.walking_state
  local shooting=entity.shooting_state
  local facing=entity.orientation or (entity.direction or 0)/16
  if shooting and shooting.state~=defines.shooting.not_shooting then
    rec.gun_until=game.tick+(source.ticks_to_keep_gun or 0)
    rec.aim_until=game.tick+(source.ticks_to_keep_aiming_direction or 0)
    rec.aim=orientation(position,shooting.position,facing)
  end
  if rec.engineer_observed_tick~=game.tick then
    local elapsed=rec.engineer_observed_tick and game.tick-rec.engineer_observed_tick
    local previous=rec.engineer_position
    rec.engineer_motion=nil
    -- Native character.position already includes flight elevation. Use the
    -- ground projection for movement, excluding vertical take-off and bobbing.
    local ground={x=position.x,y=position.y+height}
    if elapsed and elapsed>0 and elapsed<=60 and previous
      and rec.engineer_surface==entity.surface.index and rec.engineer_walking
      and walking and walking.walking and not entity.driving then
      local distance=((ground.x-previous.x)^2+(ground.y-previous.y)^2)^.5
      local reported=entity.character_running_speed or source.running_speed or .15
      -- A teleport must not become an enormous visual stride. Ordinary belt
      -- motion and fixed-point rounding fit inside this conservative bound.
      if distance<=math.max(reported,.001)*elapsed*2+.25 then
        rec.engineer_motion=distance/elapsed
      end
    end
    rec.engineer_previous_height=rec.engineer_height
    rec.engineer_height=height
    rec.engineer_position=ground
    rec.engineer_surface=entity.surface.index
    rec.engineer_observed_tick=game.tick
    rec.engineer_walking=walking and walking.walking or false
  end
end

local function first_state(states,...)
  for i=1,select("#",...) do local name=select(i,...);if states[name] then return name end end
end
local function pose(rec,source,variant)
  local entity=rec.entity
  if entity.driving then return "hidden" end
  local states=variant.states
  local walking=entity.walking_state
  local shooting=entity.shooting_state
  local mining=entity.mining_state
  local facing=entity.orientation or (entity.direction or 0)/16
  local moving=walking and walking.walking
  local walk=moving and (walking.direction or entity.direction or 0)/16 or facing
  local is_shooting=shooting and shooting.state~=defines.shooting.not_shooting
  local armed=is_shooting or rec.gun_until and game.tick<rec.gun_until
  local aiming=armed and rec.aim_until and game.tick<rec.aim_until
  local aim=aiming and rec.aim or (moving and walk or facing)
  local height=entity.flight_height or 0
  local state
  if entity.is_flying then
    -- Native 2.1.25 Mech measurements put steady hover/bobbing at 1..1.30
    -- tiles. Below that band, rising/falling height identifies transitions.
    -- There is no exposed native flight-phase property; this is the measured
    -- vanilla threshold, not a sign-of-height-change test during bobbing.
    if height<1-.0001 then
      local previous=rec.engineer_previous_height
      if previous and height<previous-.0001 then state=first_state(states,"landing")
      else state=first_state(states,"take_off") end
    end
    if not state and moving then
      state=armed and first_state(states,"flying_with_gun","flying") or first_state(states,"flying","flying_with_gun")
    end
    state=state or (armed and first_state(states,"idle_with_gun_in_air","idle_in_air")
      or first_state(states,"idle_in_air","idle_with_gun_in_air"))
    state=state or first_state(states,"idle_with_gun","idle")
  elseif mining and mining.mining then
    state=first_state(states,"mining_with_tool")
    aim=orientation(entity.position,mining.position,facing)
  elseif moving then
    state=armed and first_state(states,"running_with_gun","running")
      or first_state(states,"running","running_with_gun")
  else
    state=armed and first_state(states,"idle_with_gun","idle") or first_state(states,"idle","idle_with_gun")
  end
  state=state or first_state(states,"idle_with_gun","idle")
  local multiplier=1
  if state=="running" or state=="running_with_gun" then
    local speed=rec.engineer_motion
    if speed==nil then speed=entity.character_running_speed or source.running_speed end
    multiplier=math.max(0,speed or 0)/(source.distance_per_frame or .13)
  elseif state=="mining_with_tool" then
    multiplier=math.max(0,1+(entity.character_mining_speed_modifier or 0)+(entity.force.manual_mining_speed_modifier or 0))
  end
  return state,aim,walk,multiplier,height
end

local function selection(clip,aim,walk)
  local bank=PoseMap[clip.directions]
  if bank then
    local a,w=direction8(aim)+1,direction8(walk)+1
    return bank.row[a][w],bank.mirrored[a][w],bank.reversed[a][w]
  end
  local row=math.floor((aim%1)*clip.directions+.5)%clip.directions
  if clip.counterclockwise then row=(-row)%clip.directions end
  return row,false,false
end

local function render_layers(variant,clip,state,mirrored)
  local alternate=mirrored and state=="running_with_gun" and variant.states.flipped_shadow_running_with_gun
  local result={}
  for _,layer in ipairs(clip.layers) do
    if not (alternate and layer.shadow) then result[#result+1]={layer=layer,mirrored=mirrored} end
  end
  if alternate then
    -- These shadows were rendered for the mirrored body with the light still
    -- coming from the same direction; reflecting their pixels would be wrong.
    for _,layer in ipairs(alternate.layers) do result[#result+1]={layer=layer,mirrored=false} end
  end
  return result
end

local function cycle(rec,state,clip,multiplier,reversed)
  local gait=state=="running" or state=="running_with_gun"
  local kind=gait and "gait" or state
  local frames=clip.frames
  local rate=(clip.speed or 1)*multiplier
  local phase=0
  if rec.state and rec.engineer_cycle==kind and rec.engineer_phase_tick then
    local elapsed=math.max(0,game.tick-rec.engineer_phase_tick)
    phase=rec.engineer_phase or 0
    if rec.engineer_frames and rec.engineer_frames~=frames then phase=phase*frames/rec.engineer_frames end
    -- The latest movement sample describes the elapsed interval, so blocked
    -- movement and real running bonuses advance the gait by traveled distance.
    phase=phase+elapsed*(gait and rate or rec.engineer_phase_rate or rate)
  end
  local transition=state=="take_off" or state=="landing"
  if transition then
    phase=math.min(phase,frames-1)
    if phase>=frames-1 then rate=0 end
  else phase=phase%frames end
  rec.engineer_cycle,rec.engineer_phase,rec.engineer_phase_rate=kind,phase,rate
  rec.engineer_phase_tick,rec.engineer_frames=game.tick,frames
  if reversed then
    -- The oracle's forward/reverse integer frames sum to 21 of 22. Reflect
    -- the continuous phase just below the next boundary to preserve that
    -- relationship for fractional phases, including a freshly started cycle.
    local boundary=(PoseMap.reverse_frame_sum+1)*frames/PoseMap.sample_frame_count
    return (boundary-phase-.000001)%frames,-rate
  end
  return phase,rate
end

local function target(entity,entry,height)
  local layer=entry.layer
  local shift=layer.shift or {0,0}
  return {entity=entity,offset={entry.mirrored and -shift[1] or shift[1],
    shift[2]+(layer.shadow and height or 0)}}
end

function M.update(rec)
  local entity=rec.entity
  local source=data()
  if not (source and entity and entity.valid and M.needed(entity)) then clear(rec);return false end
  M.observe(rec)
  local armor=entity.get_inventory(defines.inventory.character_armor)
  local item=armor and armor.valid and armor[1]
  local variant_index=item and item.valid_for_read and source.armor_to_variant[item.name] or source.default_variant
  local variant=source.variants[variant_index]
  local state,aim,walk,multiplier,height=pose(rec,source,variant)
  if state=="hidden" then clear(rec);rec.state=nil;rec.engineer_cycle=nil;return true end
  local clip=state and variant.states[state]
  if not clip then clear(rec);return false end
  local row,mirrored,reversed=selection(clip,aim,walk)
  local layers=render_layers(variant,clip,state,mirrored)
  local frame,rate=cycle(rec,state,clip,multiplier,reversed)
  local key=variant_index..":"..state..":"..row..":"..tostring(mirrored)..":"..tostring(reversed)
  local player=rec.player_index and game.get_player(rec.player_index)
  local tint=player and player.valid and player.color or entity.color or entity.force.color
  local changed=rec.engineer_key~=key or #rec.renders~=#layers
  for i in ipairs(layers) do local render=object(rec.renders[i]);if not(render and render.valid) then changed=true end end
  if changed then
    local created={}
    local ok,err=pcall(function()
      for i,entry in ipairs(layers) do
        local layer=entry.layer
        local render=rendering.draw_animation{
          animation=layer.animations[row%layer.directions+1],
          target=target(entity,entry,height),surface=entity.surface,
          render_layer=layer.shadow and "object-under" or "object",
          x_scale=entry.mirrored and -1 or 1,
          animation_speed=rate/(layer.speed or 1),animation_frame=frame,
          light_mode=layer.light and "light" or layer.glow and "glow" or "occluder",
          tint=layer.tint and tint or {r=1,g=1,b=1,a=1}}
        created[i]=render.id
      end
    end)
    if not ok then
      for _,id in ipairs(created) do local render=object(id);if render and render.valid then render.destroy() end end
      error(err)
    end
    clear(rec);rec.renders=created;rec.engineer_key=key
  else
    for i,entry in ipairs(layers) do
      local layer=entry.layer
      local render=object(rec.renders[i])
      render.animation_speed=rate/(layer.speed or 1)
      render.animation_frame=frame
      if layer.tint then render.color=tint end
      render.target=target(entity,entry,height)
    end
  end
  rec.state,rec.row,rec.mirrored,rec.reversed=state,row,mirrored,reversed
  rec.engineer_variant=variant_index
  rec.position={x=entity.position.x,y=entity.position.y}
  rec.color=tint
  return true
end
return M
