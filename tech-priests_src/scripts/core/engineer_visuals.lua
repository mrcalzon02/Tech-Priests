-- Engineer pixels on the original character. This module only reads gameplay
-- state and owns render objects; it never assigns a controller or character.
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
  local source=data()
  return source and (entity.name==M.host_name or entity.name==source.character_name and source.native_hidden)
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
local function pose(rec,source,variant)
  local entity=rec.entity
  local player=rec.player_index and game.get_player(rec.player_index)
  if entity.driving or player and player.valid and player.driving then return "hidden" end
  local walking=entity.walking_state
  local shooting=entity.shooting_state
  local mining=entity.mining_state
  local facing=entity.orientation or (entity.direction or 0)/16
  local is_shooting=shooting and shooting.state~=defines.shooting.not_shooting
  if is_shooting then
    rec.gun_until=game.tick+(source.ticks_to_keep_gun or 0)
    rec.aim_until=game.tick+(source.ticks_to_keep_aiming_direction or 0)
    rec.aim=orientation(entity.position,shooting.position,facing)
  end
  local armed=is_shooting or rec.gun_until and game.tick<rec.gun_until
  local aiming=armed and rec.aim_until and game.tick<rec.aim_until
  local aim=aiming and rec.aim or facing
  local moving=walking and walking.walking
  local height=entity.flight_height or 0
  local flying=entity.is_flying
  local state
  if flying then
    if rec.flight_height and height>rec.flight_height+.0001 and variant.states.take_off then state="take_off"
    elseif rec.flight_height and height<rec.flight_height-.0001 and variant.states.landing then state="landing"
    elseif moving then state=armed and "flying_with_gun" or "flying"
    else state=armed and "idle_with_gun_in_air" or "idle_in_air" end
  elseif mining and mining.mining then
    state="mining_with_tool";aim=orientation(entity.position,mining.position,facing)
  elseif moving then state=armed and "running_with_gun" or "running"
  else state=armed and "idle_with_gun" or "idle" end
  rec.flight_height=height
  -- 18/40-direction banks are aim/walk combinations. The ordinary running
  -- pose is the safe fallback until an exact bank selector is available.
  if state=="running_with_gun" then state="running";aim=facing end
  if state=="flying_with_gun" then state="flying";aim=facing end
  if not variant.states[state] then state=armed and "idle_with_gun" or "idle" end
  if not variant.states[state] then state="idle_with_gun" end
  local multiplier=1
  if state=="running" then
    multiplier=(entity.character_running_speed or source.running_speed)/(source.distance_per_frame or .13)
  elseif state=="mining_with_tool" then
    multiplier=1+(entity.character_mining_speed_modifier or 0)+(entity.force.manual_mining_speed_modifier or 0)
  end
  return state,aim,multiplier,height
end
function M.update(rec)
  local entity=rec.entity
  local source=data()
  if not (source and entity and entity.valid and M.needed(entity)) then clear(rec);return false end
  local armor=entity.get_inventory(defines.inventory.character_armor)
  local item=armor and armor.valid and armor[1]
  local variant_index=item and item.valid_for_read and source.armor_to_variant[item.name] or source.default_variant
  local variant=source.variants[variant_index]
  local state,facing,multiplier,height=pose(rec,source,variant)
  if state=="hidden" then clear(rec);rec.state=nil;return true end
  local clip=variant.states[state]
  if not clip then clear(rec);return false end
  local row=math.floor((facing%1)*clip.directions+.5)%clip.directions
  local key=variant_index..":"..state..":"..row
  local player=rec.player_index and game.get_player(rec.player_index)
  local tint=player and player.valid and player.color or entity.color or entity.force.color
  local changed=rec.engineer_key~=key
  for i in ipairs(clip.layers) do local render=object(rec.renders[i]);if not(render and render.valid) then changed=true end end
  if changed then
    local frame=0
    local previous=object(rec.renders[1])
    if previous and previous.valid and rec.state==state then frame=previous.animation_frame end
    local created={}
    local ok,err=pcall(function()
      for i,layer in ipairs(clip.layers) do
        local render=rendering.draw_animation{
          animation=layer.animations[row%layer.directions+1],
          target={entity=entity,offset={0,layer.shadow and 0 or -height}},surface=entity.surface,
          render_layer=layer.shadow and "object-under" or "object",
          animation_speed=multiplier,animation_frame=frame,
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
    for i,layer in ipairs(clip.layers) do
      local render=object(rec.renders[i])
      render.animation_speed=multiplier
      if layer.tint then render.color=tint end
      render.target={entity=entity,offset={0,layer.shadow and 0 or -height}}
    end
  end
  rec.state,rec.row=state,row
  rec.position={x=entity.position.x,y=entity.position.y}
  rec.color=tint
  return true
end
return M
