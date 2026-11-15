-- One controller for the two new weapons. The engine owns ammo and damage.
-- The piano controller owns only its explicit four-shot recycle interruption.
local M={}
local PIANO='tech-priests-bunker-chicago-piano'
local MINI='tech-priests-bunker-twin-minigun'
function M.muzzle_created(event)
  local source,flash=event.source,event.entity
  if source and source.valid and (source.name==PIANO or source.name==MINI)
      and flash and flash.valid and flash.name=='explosion-gunshot' then
    flash.destroy()
    return true
  end
  return false
end
function M.heading(orientation)
  -- Captures rotate in 3D beneath a 45-degree camera. Map-space aim must
  -- compensate for the camera's vertical foreshortening, like the native
  -- RotatedAnimation apply_projection option used by the preview core.
  local angle=orientation*2*math.pi
  local projected=math.atan2(math.sin(angle),math.cos(angle)*math.sqrt(2))/(2*math.pi)%1
  return math.floor(projected*64+.5)%64
end
function M.add(entity)
  if not(entity and entity.valid and (entity.name==PIANO or entity.name==MINI)) then return false end
  storage.bullet_turrets=storage.bullet_turrets or {}
  storage.bullet_turrets[entity.unit_number]=storage.bullet_turrets[entity.unit_number] or {entity=entity,objects={},burst=0,spin=0}
  return true
end
function M.init()
  storage.bullet_turrets=storage.bullet_turrets or {}
  for _,surface in pairs(game.surfaces) do
    for _,entity in pairs(surface.find_entities_filtered{name={PIANO,MINI}}) do M.add(entity) end
  end
end
function M.hit(event)
  local gun=event.cause
  if not M.add(gun) then return end
  local entry=storage.bullet_turrets[gun.unit_number]
  if entry.last_shot==event.tick then return end
  if entry.last_shot then
    local gap=event.tick-entry.last_shot
    if gap>0 and gap<=12 then entry.native_gap=gap end
  end
  local native_gap=entry.native_gap or prototypes.entity[gun.name].attack_parameters.cooldown
  if gun.name==PIANO then
    if not entry.last_shot or event.tick-entry.last_shot>30 then entry.burst=0 end
    entry.slot=entry.burst;entry.burst=entry.burst+1
    if entry.burst==4 then
      entry.burst=0
      -- The damage callback runs inside the shot update. Five cooldown
      -- updates remain after it; 25 held ticks + 5 native ticks = 30.
      if not gun.disabled_by_script then
        gun.disabled_by_script=true;entry.recycle_owned=true;entry.release_tick=event.tick+31-native_gap
        entry.previous_status=gun.custom_status
        gun.custom_status={diode=defines.entity_status_diode.yellow,label={'entity-status.tech-priests-quad-recycling'}}
      end
    end
  else
    entry.pair=((entry.pair or -1)+1)%6
    entry.shot_phase=entry.pair*6
  end
  entry.last_shot=event.tick;entry.pulses=(entry.pulses or 0)+1
end
function M.tick(event)
  for id,entry in pairs(storage.bullet_turrets or {}) do
    local gun=entry.entity
    if not gun.valid then
      for _,object in pairs(entry.objects) do if object.valid then object.destroy() end end
      storage.bullet_turrets[id]=nil
    else
      if entry.recycle_owned and event.tick>=entry.release_tick then
        gun.disabled_by_script=false;entry.recycle_owned=nil;entry.release_tick=nil
        local status=gun.custom_status
        if status and status.label and status.label[1]=='entity-status.tech-priests-quad-recycling' then gun.custom_status=entry.previous_status end
        entry.previous_status=nil
      end
      local variant=gun.name==PIANO and 'chicago-piano' or 'twin-minigun'
      local mode,frame,flash='idle',0,false
      if entry.last_shot then
        local age=event.tick-entry.last_shot
        local gap=entry.native_gap or prototypes.entity[gun.name].attack_parameters.cooldown
        flash=age<2
        if gun.name==PIANO then
          mode='cycle'
          if entry.slot==3 and age>=gap then frame=math.min(23,12+(age-gap)*12/math.max(1,30-gap))
          else frame=((entry.slot or 0)*6+math.min(age*6/gap,5))*.5 end
          if age>=30 then mode='idle' end
        elseif age<gap+24 then
          mode='cycle'
          if age<=gap then entry.spin=((entry.shot_phase or 0)+age*6/gap)%36
          else entry.spin=((entry.spin or 0)+(6/gap)*math.max(0,1-(age-gap)/24))%36 end
          frame=entry.spin*.5
        else mode='cycle';frame=(entry.spin or 0)*.5 end
      end
      local heading=M.heading(gun.orientation)
      for _,pass in ipairs({'shadow','body','fx'}) do
        local animation=string.format('tp-%s-%s-%s-%02d',variant,mode,pass,heading)
        local object=entry.objects[pass]
        local offset=pass=='shadow' and 0 or frame
        if pass=='fx' then
          -- A flash is a discrete shot frame, independent of body recoil.
          offset=variant=='twin-minigun' and (entry.shot_phase or 0)*.5 or (entry.slot or 0)*3
        end
        local visible=pass~='fx' or flash
        if not(object and object.valid) then
          object=rendering.draw_animation{animation=animation,target=gun,surface=gun.surface,
            render_layer=pass=='shadow' and 'object-under' or 'object',
            animation_speed=0,animation_offset=offset,visible=visible}
          entry.objects[pass]=object
        else
          if object.animation~=animation then object.animation=animation end
          object.animation_offset=offset;object.visible=visible
        end
      end
    end
  end
end
return M
