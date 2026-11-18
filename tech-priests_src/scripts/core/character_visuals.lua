-- Presentation only. Never owns a priest's movement, target, inventory or damage.
local Catalog=require("shared.character_skin_catalog")
local Combat=require("shared.combat_roster_catalog")
local Registry=require("scripts.core.runtime_event_registry")
local M={host_name="tech-priests-custom-character",corpse_name="tech-priests-custom-character-corpse",budget=128}
local installed=false
local pending_processor=nil
function M.set_pending_processor(callback) pending_processor=callback end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local tp=storage.tech_priests
  tp.character_visuals=tp.character_visuals or {actors={},pair_cursor=nil,actor_cursor=nil,stats={}}
  return tp.character_visuals
end
local function valid(entity) return entity and entity.valid end
local function color(c)
  c=c or {}
  return {r=c.r or c[1] or 1,g=c.g or c[2] or 1,b=c.b or c[3] or 1,a=1}
end
local function color_key(c) return string.format("%.5f:%.5f:%.5f",c.r,c.g,c.b) end
local function get_render(id) return id and rendering.get_object_by_id(id) or nil end
local function clear(rec)
  for _,id in pairs(rec.renders or {}) do local obj=get_render(id);if obj and obj.valid then obj.destroy() end end
  rec.renders={}
end
function M.model_for_entity(entity)
  if not valid(entity) then return nil end
  local combat=Combat.for_entity_name(entity.name)
  if combat and entity.type=="car" then return combat.id end
  local rank=entity.name:match("^(.+)%-tech%-priest")
  return rank and Catalog.ranks[rank] or nil
end
local function direction(entity,state)
  local ok,value=pcall(function() return entity.orientation end)
  value=ok and value or (entity.direction or 0)/16
  if entity.type=="car" and state=="attack" then value=value+entity.relative_turret_orientation end
  return math.floor((value%1)*8+0.5)%8
end
function M.track(entity,id,player_index)
  if not (valid(entity) and Catalog.by_id[id]) then return nil end
  local r=root()
  local key=entity.unit_number
  if not key then r.next_corpse=(r.next_corpse or 0)-1;key=r.next_corpse end
  local rec=r.actors[key]
  if not rec then rec={entity=entity,model=id,renders={},player_index=player_index};r.actors[key]=rec end
  if rec.model~=id then clear(rec);rec.model=id;rec.state=nil end
  rec.player_index=player_index
  return rec
end
local function player_character(player)
  if valid(player.character) then return player.character end
  local tp=storage.tech_priests
  local picker=tp and tp.character_skin_picker
  local cached=picker and picker.characters and picker.characters[player.index]
  return valid(cached) and cached or nil
end
M.player_character=player_character
function M.refresh_player(player,id)
  local entity=player_character(player)
  if valid(entity) and entity.name==M.host_name and Catalog.by_id[id] then
    local rec=M.track(entity,id,player.index)
    if rec then M.update(rec) end
    return true
  end
  return false
end
local function state_for(rec)
  local entity=rec.entity
  if rec.dead then return "death" end
  if rec.player_index then
    local player=game.get_player(rec.player_index)
    if not (player and player.valid) then return "idle" end
    if player.driving then return "hidden" end
    if player.controller_type~=defines.controllers.character then return "idle" end
    local shooting=player.shooting_state
    if shooting and shooting.state~=defines.shooting.not_shooting then return "attack" end
    local mining=player.mining_state
    if mining and mining.mining then return Catalog.by_id[rec.model].states.work and "work" or "attack" end
    local walking=player.walking_state
    if walking and walking.walking then return "walk" end
    return "idle"
  end
  if entity.type=="car" then
    local driver=entity.get_driver()
    if driver and driver.valid then
      local shooting=driver.shooting_state
      if shooting and shooting.state~=defines.shooting.not_shooting
        and not entity.get_inventory(defines.inventory.car_ammo).is_empty() then return "attack" end
    end
  end
  local pos=entity.position
  if rec.position and (pos.x-rec.position.x)^2+(pos.y-rec.position.y)^2>0.000001 then return "walk" end
  local pair=storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[entity.unit_number]
  if pair then
    if valid(pair.combat_target) then return "attack" end
    local mode=string.lower(tostring(pair.mode or ""))
    if Catalog.by_id[rec.model].states.work and
      (mode:find("repair",1,true) or mode:find("consecrat",1,true) or mode:find("craft",1,true)) then return "work" end
  end
  return "idle"
end
local function animation_name(id,state,row,part)
  return "tech-priests-avatar-"..id.."-"..state.."-"..row.."-"..part
end
function M.update(rec)
  local entity=rec.entity
  if not valid(entity) then clear(rec);return false end
  local skin=Catalog.by_id[rec.model]
  if not skin then clear(rec);return false end
  local state=state_for(rec)
  if state=="hidden" then clear(rec);rec.state=nil;return true end
  local row=rec.dead and rec.row or direction(entity,state)
  local player=rec.player_index and game.get_player(rec.player_index)
  local tint=color(rec.dead and rec.death_color or player and player.color or entity.force.color)
  local tint_key=color_key(tint)
  local finished=rec.dead and game.tick>=rec.death_end
  local changed=rec.state~=state or rec.row~=row or rec.finished~=finished
  for _,part in ipairs({"shadow","base","mask"}) do
    local obj=get_render(rec.renders[part])
    if not (obj and obj.valid) then changed=true end
  end
  if changed then
    local ids={}
    local ok,err=pcall(function()
      local speed=finished and 0 or skin.states[state].speed
      local offset=finished and skin.frames-1 or (-(rec.state_tick or game.tick)*speed)%skin.frames
      if rec.state~=state then rec.state_tick=game.tick;offset=(-game.tick*speed)%skin.frames end
      for _,part in ipairs({"shadow","base","mask"}) do
        local obj=rendering.draw_animation{
          animation=animation_name(rec.model,state,row,part),
          target={entity=entity},surface=entity.surface,
          render_layer=part=="shadow" and "object-under" or "object",
          animation_speed=speed,animation_offset=offset,light_mode="occluder",
          tint=part=="mask" and tint or {r=1,g=1,b=1,a=1}}
        ids[part]=obj.id
      end
    end)
    if not ok then
      for _,id in pairs(ids) do local obj=get_render(id);if obj and obj.valid then obj.destroy() end end
      error(err)
    end
    clear(rec)
    rec.renders=ids
    rec.state,rec.row,rec.finished=state,row,finished
  elseif rec.tint_key~=tint_key then
    local mask=get_render(rec.renders.mask)
    if mask and mask.valid then mask.color=tint end
  end
  rec.tint_key=tint_key
  rec.color=tint
  rec.position={x=entity.position.x,y=entity.position.y}
  return true
end
function M.tick(event)
  if event.tick%5~=0 then return end
  if pending_processor and event.tick%30==0 then pending_processor() end
  local tp=storage.tech_priests
  if not tp then return end
  local pairs_map=tp.pairs_by_station or {}
  local existing=tp.character_visuals
  if not existing and next(pairs_map)==nil then return end
  local r=root()
  local key=r.pair_cursor
  if key and not pairs_map[key] then key=nil end
  for _=1,32 do
    local pair
    key,pair=next(pairs_map,key)
    if not key then break end
    if pair and valid(pair.priest) then
      local id=M.model_for_entity(pair.priest)
      if id then M.track(pair.priest,id) end
    end
  end
  r.pair_cursor=key
  -- Player avatars are responsive independently of priest population.
  for _,player in pairs(game.connected_players) do
    local choice=tp.character_skin_picker and tp.character_skin_picker.selected[player.index]
    if choice then M.refresh_player(player,choice) end
  end
  local actors=r.actors
  local cursor=r.actor_cursor
  if cursor and not actors[cursor] then cursor=nil end
  local processed=0
  for _=1,M.budget do
    local rec
    local previous_cursor=cursor
    cursor,rec=next(actors,cursor)
    if not cursor then break end
    local current=cursor
    if not M.update(rec) then
      actors[current]=nil
      -- Resume after the retained predecessor. Stopping after one stale AAI
      -- body lets replacements accumulate faster than they can be collected
      -- and starves valid actors of their presentation update.
      cursor=previous_cursor
    else
      processed=processed+1
    end
  end
  r.actor_cursor=cursor
  r.stats.last_processed=processed
end
function M.on_death(event)
  local entity=event.entity
  if not valid(entity) then return end
  local r=root()
  local previous=r.actors[entity.unit_number]
  local id=previous and previous.model or M.model_for_entity(entity)
  if not id then return end
  r.deaths=r.deaths or {}
  local p=entity.position
  r.deaths[entity.unit_number]={tick=game.tick,model=id,row=direction(entity),surface=entity.surface.index,
    position={x=p.x,y=p.y},color=color(previous and previous.color or entity.force.color)}
end
function M.post_death(event)
  local r=root()
  local pending=r.deaths or {}
  for unit,death in pairs(pending) do
    if game.tick-death.tick>2 then pending[unit]=nil
    elseif unit==event.unit_number then
      for _,corpse in pairs(event.corpses or {}) do
        if valid(corpse) and corpse.surface.index==death.surface
          and (corpse.position.x-death.position.x)^2+(corpse.position.y-death.position.y)^2<0.1 then
          local rec=M.track(corpse,death.model)
          if rec then
            rec.dead=true;rec.row=death.row;rec.death_color=death.color
            rec.death_end=game.tick+math.ceil(Catalog.by_id[death.model].states.death.duration*60)
            M.update(rec)
          end
          pending[unit]=nil
          break
        end
      end
    end
  end
end
function M.install()
  if installed then return true end
  installed=true
  assert(Registry.on_event(defines.events.on_tick,M.tick,nil,{owner="character_visuals",route="presentation",category="visual",note="bounded presentation only; player appearance runs before first station"}))
  assert(Registry.on_event(defines.events.on_entity_died,M.on_death,nil,{owner="character_visuals",route="capture-death",category="visual"}))
  if defines.events.on_post_entity_died then
    assert(Registry.on_event(defines.events.on_post_entity_died,M.post_death,nil,{owner="character_visuals",route="corpse-presentation",category="visual"}))
  end
  return true
end
return M
