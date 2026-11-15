-- Graphics only. Native turret targeting, projectiles, damage and ammo own combat.
-- Only explicitly registered lobbers are visited. Render targets die with entities.
local M={}
local bullet=require('scripts.bullet_turret_controller')
local NAME='tech-priests-bunker-lobber'
function M.add(entity)
  if bullet.add(entity) then return end
  if not(entity and entity.valid and entity.name==NAME) then return end
  storage.bunker_cap_visuals=storage.bunker_cap_visuals or {}
  local id=entity.unit_number
  if not storage.bunker_cap_visuals[id] then
    storage.bunker_cap_visuals[id]={entity=entity,objects={},phase=0}
  end
end
function M.init()
  bullet.init()
  storage.bunker_cap_visuals=storage.bunker_cap_visuals or {}
  for _,surface in pairs(game.surfaces) do
    for _,entity in pairs(surface.find_entities_filtered{name=NAME}) do M.add(entity) end
  end
  for _,force in pairs(game.forces) do
    for _,name in ipairs({'tech-priests-bunker-autocannon','tech-priests-bunker-lobber','tech-priests-bunker-energy-dish','tech-priests-bunker-chicago-piano','tech-priests-bunker-twin-minigun'}) do
      local technology=force.technologies[name]
      if technology and technology.researched then
        for _,effect in pairs(technology.effects) do
          if effect.type=='unlock-recipe' and force.recipes[effect.recipe] then force.recipes[effect.recipe].enabled=true end
        end
      end
    end
  end
end
function M.shot(event)
  if event.effect_id=='tech-priests-dish-discharge' then
    local entity=event.source_entity
    if entity and entity.valid then
      storage.bunker_dish_charge=storage.bunker_dish_charge or {}
      local entry=storage.bunker_dish_charge[entity.unit_number] or {entity=entity}
      entry.last_discharge=event.tick
      storage.bunker_dish_charge[entity.unit_number]=entry
    end
    return
  end
  if event.effect_id~='tech-priests-lobber-shot' then return end
  local entity=event.source_entity
  M.add(entity)
  local entry=entity and storage.bunker_cap_visuals[entity.unit_number]
  if not entry then return end
  if entry.last_shot==event.tick then return end
  if not entry.last_shot or event.tick-entry.last_shot>82 then
    entry.phase=0;entry.started=event.tick
  else entry.phase=(entry.phase+1)%6 end
  entry.last_shot=event.tick
  entry.shots=(entry.shots or 0)+1
end
local function charge_fx(event)
  for id,entry in pairs(storage.bunker_dish_charge or {}) do
    local entity=entry.entity
    local age=event.tick-entry.last_discharge
    if not entity.valid or age>128 then
      if entry.object and entry.object.valid then entry.object.destroy() end
      storage.bunker_dish_charge[id]=nil
    else
      local target=entity.shooting_target
      local visible=age<6 or (target and target.valid and entity.energy>=800000 and age<120)
      local heading=math.floor(entity.orientation*64+.5)%64
      local animation=string.format('tp-dish-electrical-%02d',heading)
      local frame=age<6 and 0 or math.min(15,1+math.floor((age-6)*15/114))
      if not(entry.object and entry.object.valid) then
        entry.object=rendering.draw_animation{animation=animation,target=entity,surface=entity.surface,
          render_layer='object',animation_speed=0,animation_offset=frame,visible=visible}
      else
        entry.object.visible=visible
        if entry.object.animation~=animation then entry.object.animation=animation end
        entry.object.animation_offset=frame
      end
    end
  end
end
function M.tick(event)
  bullet.tick(event)
  charge_fx(event)
  for id,entry in pairs(storage.bunker_cap_visuals or {}) do
    local entity=entry.entity
    if not entity.valid then
      for _,object in pairs(entry.objects) do if object.valid then object.destroy() end end
      storage.bunker_cap_visuals[id]=nil
    else
      local heading=math.floor(entity.orientation*64+.5)%64
      local mode,frame='idle',0
      if entry.last_shot then
        local elapsed=event.tick-entry.last_shot
        if elapsed<80 then
          mode='cycle';frame=(entry.phase*32+elapsed*.4)%192
          if entry.phase==0 and event.tick-entry.started<37.5 then
            mode='entry';frame=math.min(14,math.floor((event.tick-entry.started)*.4))
          end
        elseif elapsed<117.5 then mode='settle';frame=math.min(14,math.floor((elapsed-80)*.4))
        else entry.last_shot=nil end
      end
      for _,pass in ipairs({'shadow','beauty','emission'}) do
        local animation=string.format('tp-lobber-%s-%s-%02d',mode,pass,heading)
        local object=entry.objects[pass]
        if not(object and object.valid) then
          object=rendering.draw_animation{animation=animation,target=entity,surface=entity.surface,
            render_layer=pass=='shadow' and 'object-under' or 'object',animation_speed=0,animation_offset=frame}
          entry.objects[pass]=object
        else
          if object.animation~=animation then object.animation=animation end
          object.animation_offset=frame
        end
      end
    end
  end
end
function M.install()
  script.on_event(defines.events.on_entity_damaged,bullet.hit)
  script.on_event(defines.events.on_trigger_created_entity,bullet.muzzle_created)
  script.on_event(defines.events.on_script_trigger_effect,M.shot)
  script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
    defines.events.script_raised_built,defines.events.script_raised_revive},function(e) M.add(e.entity) end)
  script.on_configuration_changed(M.init)
end
return M
