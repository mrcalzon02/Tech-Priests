-- Observe native paid launches and insert the three-shot barrage reload pause.
local M={}
local NAME='tech-priests-bunker-artillery'
local VISUALS=require('scripts.artillery_barrage_visuals')
local function state()storage.artillery_barrage=storage.artillery_barrage or {guns={}};return storage.artillery_barrage end
function M.add(gun)
  if not(gun and gun.valid and gun.name==NAME)then return false end
  local s=state();s.guns[gun.unit_number]=s.guns[gun.unit_number] or {entity=gun,shots=0,next_chamber=0,objects={}}
  return true
end
function M.init(options)
  local s=state();s.graphics_enabled=not options or options.graphics_enabled~=false
  if not prototypes.entity[NAME]then return end
  for _,surface in pairs(game.surfaces)do for _,gun in pairs(surface.find_entities_filtered{name=NAME})do M.add(gun)end end
  for _,force in pairs(game.forces)do
    if force.technologies[NAME]and force.technologies[NAME].researched and force.recipes[NAME]then force.recipes[NAME].enabled=true end
  end
end
function M.fired(e)
  if not M.add(e.source)then return false end
  local gun=e.source;local entry=state().guns[gun.unit_number]
  if entry.last_shot==e.tick then return true end
  local multiplier=1+gun.force.get_gun_speed_modifier('artillery-shell')
  local donor=prototypes.item['artillery-wagon-cannon'].attack_parameters.cooldown
  local own=prototypes.item[NAME..'-gun'].attack_parameters.cooldown
  local gap=math.max(1,math.ceil(own/multiplier-1e-7))
  local cycle=3*math.max(1,math.ceil(donor/multiplier-1e-7))
  entry.last_chamber=entry.next_chamber;entry.next_chamber=(entry.next_chamber+1)%3
  entry.shots=entry.shots+1;entry.last_shot=e.tick;entry.native_gap=gap
  local shell=entry.objects and entry.objects['shell'..entry.last_chamber]
  if shell and shell.valid then shell.visible=false end
  entry.last_launch={tick=e.tick,chamber=entry.last_chamber,position=e.entity.position,projectile=e.entity.name,
    orientation=gun.relative_turret_orientation,gap=gap,target_cycle=cycle}
  if entry.next_chamber==0 and not gun.disabled_by_script then
    entry.reload_gap=cycle-2*gap;entry.release_tick=e.tick+entry.reload_gap+1-gap
    entry.reload_owned=true;gun.disabled_by_script=true
    entry.previous_status=gun.custom_status
    gun.custom_status={diode=defines.entity_status_diode.yellow,label={'','Reloading revolving-breech artillery'}}
  end
  return true
end
function M.heading(orientation)
  local a=orientation*2*math.pi
  return math.floor((math.atan2(math.sin(a),math.cos(a)*math.sqrt(2))/(2*math.pi)%1)*64+.5)%64
end
local function visuals(entry,tick)
  local gun=entry.entity;entry.objects=entry.objects or {}
  local d=M.heading(gun.relative_turret_orientation)
  if not VISUALS.headings[tostring(d)] then
    local distance=65
    for key in pairs(VISUALS.headings)do local h=tonumber(key);local delta=math.abs(d-h);delta=math.min(delta,64-delta)
      if delta<distance then entry.pilot_heading=h;distance=delta end
    end
    d=entry.pilot_heading
  end
  local phase=0
  if entry.last_shot then
    local age=tick-entry.last_shot
    if entry.last_chamber<2 then phase=entry.last_chamber*90+math.min(age*90/entry.native_gap,89)
    elseif age<(entry.reload_gap or 420)then phase=180+age*420/(entry.reload_gap or 420)end
  end
  phase=math.max(0,math.min(600,math.floor(phase)))
  local frame=VISUALS.lookup[phase+1]
  local function draw(pass,layer)
    local animation=string.format('tp-artillery-%s-%02d',pass,d);local obj=entry.objects[pass]
    if not(obj and obj.valid)then obj=rendering.draw_animation{animation=animation,target=gun,surface=gun.surface,
      animation_speed=0,animation_offset=frame,render_layer=layer or 'higher-object-above'};entry.objects[pass]=obj
    else
      if obj.animation~=animation then obj.animation=animation end
      if obj.animation_offset~=frame then obj.animation_offset=frame end
    end
    return obj
  end
  if VISUALS.headings[tostring(d)].shadow then draw('shadow','object-under')end
  draw('body')
  local inventory=gun.get_inventory(defines.inventory.artillery_turret_ammo)
  local count=inventory and inventory.get_item_count()or 0
  local start=entry.next_chamber
  local reloading=entry.last_chamber==2 and phase>=180
  if reloading then start=0 end
  for cell=0,2 do
    local obj=draw('shell'..cell)
    local visible=(not reloading or phase>=450+15*cell)and cell>=start and cell<math.min(3,start+count)
    if obj.visible~=visible then obj.visible=visible end
  end
  entry.visual={heading=d,phase=phase,frame=frame,ammo=count}
end
function M.gui_opened(e)
  local player=game.get_player(e.player_index);local gun=e.entity
  if not(player and gun and gun.valid and gun.name==NAME)then return end
  local s=state();s.viewers=s.viewers or {}
  if player.gui.screen.tp_artillery_live then player.gui.screen.tp_artillery_live.destroy()end
  local panel=player.gui.screen.add{type='frame',name='tp_artillery_live',direction='vertical',caption=gun.localised_name}
  local content=panel.add{type='flow',direction='horizontal'}
  local inventory=player.get_main_inventory()
  if inventory then
    local left=content.add{type='frame',direction='vertical',caption={'','Inventory'},style='inside_shallow_frame'}
    local slots=left.add{type='inventory',slots_per_row=10,handle_cursor_transfer=true,handle_cursor_split=true,handle_open_item=true}
    slots.inventory=inventory
  end
  local right=content.add{type='frame',direction='vertical',style='inside_shallow_frame'}
  local camera=right.add{type='camera',name='view',position={gun.position.x,gun.position.y-2.5},surface_index=gun.surface.index,zoom=1.1}
  camera.style.width=400;camera.style.height=300
  right.add{type='checkbox',name='tp_artillery_auto',caption={'','Auto targeting'},state=gun.artillery_auto_targeting}
  local ammo=right.add{type='inventory',name='ammunition',slots_per_row=1,handle_cursor_transfer=true,handle_cursor_split=true,handle_open_item=true}
  ammo.inventory=gun.get_inventory(defines.inventory.artillery_turret_ammo)
  ammo.enabled=player.can_reach_entity(gun)
  local status=right.add{type='label',name='status',caption={''}}
  right.add{type='progressbar',name='reload',value=0}.style.width=400
  panel.add{type='button',name='tp_artillery_close',caption={'gui.close'}}
  s.viewers[player.index]={gun=gun,panel=panel,right=right,switching=true}
  player.opened=panel;s.viewers[player.index].switching=nil;panel.force_auto_center()
end
function M.gui_closed(e)
  local player=game.get_player(e.player_index)
  if not player then return end
  local s=state();local view=s.viewers and s.viewers[player.index]
  -- Opening our window closes the engine's incomplete static preview first.
  if view and (view.switching or player.opened==view.panel)then return end
  if player.gui.screen.tp_artillery_live then player.gui.screen.tp_artillery_live.destroy()end
  if s.viewers then s.viewers[player.index]=nil end
end
function M.gui_click(e)
  if e.element and e.element.valid and e.element.name=='tp_artillery_close'then
    local player=game.get_player(e.player_index);player.opened=nil;M.gui_closed(e)
  end
end
function M.gui_checked(e)
  local view=state().viewers and state().viewers[e.player_index]
  if view and view.gun.valid and e.element==view.right.tp_artillery_auto then view.gun.artillery_auto_targeting=e.element.state end
end
function M.tick(e)
  for id,entry in pairs(state().guns)do
    local gun=entry.entity
    if not gun.valid then
      for _,obj in pairs(entry.objects or {})do if obj.valid then obj.destroy()end end
      state().guns[id]=nil
    elseif entry.reload_owned and e.tick>=entry.release_tick then
      gun.disabled_by_script=false;entry.reload_owned=nil
      local status=gun.custom_status
      if status and status.label and status.label[2]=='Reloading revolving-breech artillery'then gun.custom_status=entry.previous_status end
      entry.previous_status=nil
    end
    if gun.valid and state().graphics_enabled then visuals(entry,e.tick)end
  end
  for id,view in pairs(state().viewers or {})do
    local player=game.get_player(id)
    if not(view.gun.valid and view.panel.valid and player and player.opened==view.panel)then
      if view.panel.valid then view.panel.destroy()end
      state().viewers[id]=nil
    else
      local entry=state().guns[view.gun.unit_number]
      local count=view.gun.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count()
      local reloading=entry and entry.last_chamber==2 and entry.visual and entry.visual.phase>=180
      view.right.status.caption={'',reloading and 'Reloading' or count==0 and 'No ammunition' or 'Ready'}
      view.right.reload.value=reloading and (entry.visual.phase-180)/420 or 0
      view.right.tp_artillery_auto.state=view.gun.artillery_auto_targeting
      view.right.ammunition.enabled=player and player.can_reach_entity(view.gun)or false
    end
  end
end
return M
