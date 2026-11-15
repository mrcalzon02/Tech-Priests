-- Native inventory, targeting and projectiles own combat. This owner only
-- selects the occupied launch cell, moves the original launch and pauses reload.
local M={}
local NAME='tech-priests-bunker-rocket-salvo'
local SOCKETS=require('scripts.rocket_salvo_geometry')
M.fire_effect='tp-rocket-salvo-fire';M.born_effect='tp-rocket-salvo-born'
local function state()
  storage.rocket_salvo=storage.rocket_salvo or {guns={},pending={}}
  return storage.rocket_salvo
end
local function key(surface,tick,p)
  return surface.index..':'..tick..':'..math.floor(p.x*256+.5)..':'..math.floor(p.y*256+.5)
end
function M.heading(orientation)
  local a=orientation*2*math.pi
  return math.floor((math.atan2(math.sin(a),math.cos(a)*math.sqrt(2))/(2*math.pi)%1)*64+.5)%64
end
function M.muzzle(gun,cell)
  local socket=SOCKETS[cell+1];local a=math.pi-M.heading(gun.orientation)*2*math.pi/64
  local x,y,z=socket[1],socket[2],socket[3]
  return {x=gun.position.x+x*math.cos(a)-y*math.sin(a),
          y=gun.position.y-(x*math.sin(a)+y*math.cos(a)+z)/math.sqrt(2)}
end
function M.add(gun)
  if not(gun and gun.valid and gun.name==NAME) then return false end
  local s=state();s.guns[gun.unit_number]=s.guns[gun.unit_number] or {entity=gun,next_cell=0,shots=0,objects={}}
  return true
end
function M.init(options)
  options=options or {};local s=state()
  s.graphics_enabled=options.graphics_enabled~=false;s.capture_headings=options.capture_headings
  if not prototypes.entity[NAME] then return end
  for _,surface in pairs(game.surfaces) do
    for _,gun in pairs(surface.find_entities_filtered{name=NAME}) do M.add(gun) end
  end
  for _,force in pairs(game.forces) do
    if force.technologies[NAME] and force.technologies[NAME].researched and force.recipes[NAME] then
      force.recipes[NAME].enabled=true
    end
  end
end
local function native_gap(gun)
  return math.max(1,math.ceil(prototypes.entity[NAME].attack_parameters.cooldown/(1+gun.force.get_gun_speed_modifier('rocket'))-1e-7))
end
function M.effect(e)
  if e.effect_id==M.fire_effect then
    local gun=e.source_entity
    if not M.add(gun) then return false end
    local s=state();local entry=s.guns[gun.unit_number]
    if entry.last_shot==e.tick then return true end
    local gap=native_gap(gun)
    entry.last_cell=entry.next_cell;entry.next_cell=(entry.next_cell+1)%6
    entry.shots=entry.shots+1;entry.last_shot=e.tick;entry.native_gap=gap
    local nose=entry.objects['nose'..entry.last_cell]
    if nose and nose.valid then nose.visible=false end
    if entry.next_cell==0 and not gun.disabled_by_script then
      entry.reload_start=e.tick;entry.reload_gap=19*gap
      -- The native cooldown freezes while disabled. Release early enough for
      -- its remaining updates to complete the agreed last-shot/next-shot gap.
      entry.release_tick=e.tick+entry.reload_gap+1-gap
      entry.reload_owned=true;gun.disabled_by_script=true
      entry.previous_status=gun.custom_status
      gun.custom_status={diode=defines.entity_status_diode.yellow,label={'','Reloading six-cell rocket launcher'}}
    end
    local k=key(gun.surface,e.tick,e.source_position)
    s.pending[k]=s.pending[k] or {}
    s.pending[k][#s.pending[k]+1]={gun=gun,cell=entry.last_cell,tick=e.tick,muzzle=M.muzzle(gun,entry.last_cell)}
    return true
  elseif e.effect_id==M.born_effect then
    local projectile=e.source_entity
    if not(projectile and projectile.valid and projectile.type=='projectile') then return true end
    local s=state();local k=key(projectile.surface,e.tick,projectile.position);local queue=s.pending[k]
    if not(queue and #queue>0) then return true end -- native stock weapons stay untouched
    local shot=table.remove(queue,1);if #queue==0 then s.pending[k]=nil end
    if shot.gun.valid then
      local entry=s.guns[shot.gun.unit_number];local before=projectile.position
      local moved=projectile.teleport(shot.muzzle,nil,false,false)
      entry.last_launch={tick=e.tick,cell=shot.cell,projectile=projectile.name,moved=moved,
        before=before,wanted=shot.muzzle,actual=projectile.position,orientation=projectile.orientation}
    end
    return true
  end
  return false
end
function M.muzzle_created(e)
  local gun,fx=e.source,e.entity
  if not(M.add(gun) and fx and fx.valid and fx.name=='explosion-hit') then return false end
  local entry=state().guns[gun.unit_number]
  local cell=entry.last_shot==e.tick and entry.last_cell or entry.next_cell
  local p=M.muzzle(gun,cell);local moved=fx.teleport(p,nil,false,false)
  entry.last_muzzle_effect={tick=e.tick,cell=cell,moved=moved,actual=fx.position,wanted=p}
  return true
end
function M.tick(e)
  local s=state()
  for id,entry in pairs(s.guns) do
    local gun=entry.entity
    if not gun.valid then
      for _,object in pairs(entry.objects) do if object.valid then object.destroy() end end
      s.guns[id]=nil
    elseif entry.reload_owned and e.tick>=entry.release_tick then
      gun.disabled_by_script=false;entry.reload_owned=nil
      local status=gun.custom_status
      if status and status.label and status.label[2]=='Reloading six-cell rocket launcher' then gun.custom_status=entry.previous_status end
      entry.previous_status=nil
    end
    if gun.valid and s.graphics_enabled then
      local d=M.heading(gun.orientation)
      if s.capture_headings then
        local best,dist=s.capture_headings[1],65
        for _,h in ipairs(s.capture_headings) do local delta=math.abs(d-h);delta=math.min(delta,64-delta);if delta<dist then best,dist=h,delta end end
        d=best
      end
      local reload=entry.reload_start and e.tick-entry.reload_start<entry.reload_gap
      local source_frame=reload and 52+(e.tick-entry.reload_start)*190/entry.reload_gap or 1
      local mode=reload and 'reload' or 'idle';local frame=reload and math.min(94,math.floor((source_frame-52)/2)) or 0
      local function draw(pass,animation,offset,layer)
        local obj=entry.objects[pass]
        if not(obj and obj.valid) then
          obj=rendering.draw_animation{animation=animation,target=gun,surface=gun.surface,animation_speed=0,
            animation_offset=offset,render_layer=layer or 'object'};entry.objects[pass]=obj
        else
          if obj.animation~=animation then obj.animation=animation end
          if obj.animation_offset~=offset then obj.animation_offset=offset end
        end
        return obj
      end
      draw('shadow',string.format('tp-rocket-%s-shadow-%02d',mode,d),frame,'object-under')
      draw('body',string.format('tp-rocket-%s-body-%02d',mode,d),frame)
      local count=gun.get_inventory(defines.inventory.turret_ammo).get_item_count()
      local start=entry.next_cell
      for cell=0,5 do
        local nose=draw('nose'..cell,string.format('tp-rocket-noses-%02d',d),cell)
        local visible=(not reload or source_frame>=180) and cell>=start and cell<start+count
        if nose.visible~=visible then nose.visible=visible end
      end
      entry.visual={heading=d,mode=mode,frame=frame,source_frame=source_frame,ammo=count}
    end
  end
  -- Unmatched callbacks are transient; old stock origins do not accumulate.
  for k,queue in pairs(s.pending) do if queue[1].tick<e.tick-1 then s.pending[k]=nil end end
end
return M
