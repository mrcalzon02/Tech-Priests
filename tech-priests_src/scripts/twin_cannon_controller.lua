-- Native ammo creates the original projectile. This owner only relocates
-- its launch point and drives the independent cannon mechanisms.
local M={}
local NAME='tech-priests-bunker-twin-cannon'
M.fire_effect='tp-twin-cannon-fire'
M.projectile_effect='tp-twin-cannon-projectile-born'
local ROOT2=math.sqrt(2)
local FLASH_LEAD=.16
local function yaw(orientation)
  local a=orientation*2*math.pi
  return math.pi-math.atan2(math.sin(a),math.cos(a)*ROOT2)
end
local function state()
  storage.twin_cannon=storage.twin_cannon or {guns={},pending={}}
  return storage.twin_cannon
end
local function key(surface,tick,position)
  return surface.index..':'..tick..':'..math.floor(position.x*256+.5)..':'..math.floor(position.y*256+.5)
end
function M.heading(orientation)
  local angle=orientation*2*math.pi
  local projected=math.atan2(math.sin(angle),math.cos(angle)*ROOT2)/(2*math.pi)%1
  return math.floor(projected*64+.5)%64
end
function M.muzzle(gun,bank)
  -- Same 45-degree studio, calibrated scale and socket as the cap sprites.
  local a=math.pi-M.heading(gun.orientation)*2*math.pi/64
  local x,y,z=bank==0 and -.58 or .58,-2.55,2.61
  local rx=x*math.cos(a)-y*math.sin(a)
  local ry=x*math.sin(a)+y*math.cos(a)
  return {x=gun.position.x+rx,y=gun.position.y-(ry+z)/ROOT2}
end
function M.flash_pose(gun,bank)
  local point=M.muzzle(gun,bank)
  local a=math.pi-M.heading(gun.orientation)*2*math.pi/64
  local dx,dy=math.sin(a),math.cos(a)/ROOT2
  local length=math.sqrt(dx*dx+dy*dy);dx=dx/length;dy=dy/length
  -- Quantize the bore like the native projectile, then lead only the flash.
  local function fixed(v) return (v<0 and -1 or 1)*math.floor(math.abs(v)*256)/256 end
  return {x=fixed(point.x)+dx*FLASH_LEAD,y=fixed(point.y)+dy*FLASH_LEAD},math.atan2(dx,-dy)/(2*math.pi)%1,point
end
function M.flash_layer(gun)
  -- Camera is south of the model. A north/away-facing muzzle is behind its
  -- collar; a south/toward-facing blast is in front of the barrel.
  local a=math.pi-M.heading(gun.orientation)*2*math.pi/64
  return math.cos(a)>1e-6 and 'light-effect' or 'object-under'
end
function M.add(gun)
  if not(gun and gun.valid and gun.name==NAME) then return false end
  local s=state()
  s.guns[gun.unit_number]=s.guns[gun.unit_number] or {entity=gun,last_bank=1,shots=0,objects={},bank_shots={},
    aerials={{x=0,y=0,vx=0,vy=0},{x=0,y=0,vx=0,vy=0}},last_yaw=yaw(gun.orientation),last_speed=0}
  return true
end
function M.init(options)
  state().graphics_enabled=not(options and options.graphics_enabled==false)
  if not prototypes.entity[NAME] then return end
  for _,surface in pairs(game.surfaces) do
    for _,gun in pairs(surface.find_entities_filtered{name=NAME}) do M.add(gun) end
  end
  for _,force in pairs(game.forces) do
    local tech=force.technologies[NAME]
    if tech and tech.researched and force.recipes[NAME] then force.recipes[NAME].enabled=true end
  end
end
function M.effect(event)
  if event.effect_id==M.fire_effect then
    local gun=event.source_entity
    if not M.add(gun) then return false end
    local s=state();local entry=s.guns[gun.unit_number]
    if entry.last_shot==event.tick then return true end
    if entry.last_shot then entry.native_gap=event.tick-entry.last_shot end
    entry.last_bank=1-entry.last_bank;entry.last_shot=event.tick;entry.shots=entry.shots+1
    entry.bank_shots=entry.bank_shots or {};entry.bank_shots[entry.last_bank]=event.tick
    for bank,aerial in ipairs(entry.aerials or {}) do
      aerial.vy=aerial.vy+(bank-1==entry.last_bank and 1.30 or .85)
      aerial.vx=aerial.vx+(entry.last_bank==0 and -.30 or .30)
    end
    local k=key(gun.surface,event.tick,event.source_position)
    s.pending[k]=s.pending[k] or {}
    s.pending[k][#s.pending[k]+1]={gun=gun,bank=entry.last_bank,tick=event.tick,muzzle=M.muzzle(gun,entry.last_bank)}
    return true
  elseif event.effect_id==M.projectile_effect then
    local projectile=event.source_entity
    if not(projectile and projectile.valid and projectile.type=='projectile') then return true end
    local s=state();local k=key(projectile.surface,event.tick,projectile.position)
    local queue=s.pending[k]
    if not(queue and #queue>0) then return true end -- stock cannons keep their native origin
    local shot=table.remove(queue,1);if #queue==0 then s.pending[k]=nil end
    if not shot.gun.valid then return true end
    local entry=s.guns[shot.gun.unit_number];local before=projectile.position
    local moved=projectile.teleport(shot.muzzle,nil,false,false)
    entry.last_launch={tick=event.tick,bank=shot.bank,projectile=projectile.name,
      before=before,wanted=shot.muzzle,actual=projectile.position,moved=moved}
    if not moved then entry.launch_error='Native projectile could not be moved to muzzle' end
    return true
  end
  return false
end
function M.muzzle_created(event)
  local gun,flash=event.source,event.entity
  if gun and gun.valid and gun.name==NAME and flash and flash.valid and flash.name=='explosion-gunshot' then
    M.add(gun)
    local entry=state().guns[gun.unit_number]
    -- Native source effects may precede or follow the launch callback.
    local bank=entry.last_shot==event.tick and entry.last_bank or 1-entry.last_bank
    local point,orientation,muzzle=M.flash_pose(gun,bank)
    -- Explosion entities ignore writable orientation. Draw the unchanged native
    -- artwork with explicit rotation, suppressing the original random flash.
    local variant=entry.shots%5+1
    local effect=rendering.draw_animation{animation='tp-twin-cannon-native-muzzle-'..variant,
      surface=gun.surface,target=point,orientation=orientation,time_to_live=2,
      render_layer=M.flash_layer(gun),animation_offset=-event.tick}
    flash.destroy()
    local actual=effect.target.position
    entry.last_native_effect={tick=event.tick,bank=bank,wanted=point,actual=actual,moved=effect.valid,
      muzzle=muzzle,flame_lead=FLASH_LEAD,orientation=effect.orientation,wanted_orientation=orientation,
      render_layer=effect.render_layer}
    return true
  end
  return false
end
function M.visual_pose(entry,tick)
  if not entry.last_shot then return 'idle',0 end
  -- Native shooting research can shorten the cadence; finish runout before
  -- the same gun's next shot rather than snapping a half-retracted barrel.
  local scale=math.max(1,45/math.max(1,entry.native_gap or 45))
  local age=(tick-entry.last_shot)*scale
  if age>=80 then return 'idle',0 end
  local other=(entry.bank_shots or {})[1-entry.last_bank]
  local overlap=other and (tick-other)*scale<80
  local mode=(overlap and 'overlap' or 'single')..entry.last_bank
  return mode,math.min(overlap and 17 or 39,math.floor(age/2))
end
local function flex(entry)
  local gun=entry.entity;local angle=yaw(gun.orientation)
  local delta=(angle-(entry.last_yaw or angle)+math.pi)%(2*math.pi)-math.pi
  local speed=delta*60;local accel=(speed-(entry.last_speed or speed))*60
  entry.last_yaw=angle;entry.last_speed=speed
  for index,aerial in ipairs(entry.aerials) do
    local x=index==1 and -1.20 or 1.20
    local omega=2*math.pi*(index==1 and 2.5 or 3.25)
    local fx=(accel*.48+speed*speed*x)*.65
    local fy=(-accel*x+speed*speed*.48)*.65
    for sub=1,4 do
      aerial.vx=aerial.vx+(fx-aerial.x*omega*omega-aerial.vx*2*.13*omega)/240
      aerial.vy=aerial.vy+(fy-aerial.y*omega*omega-aerial.vy*2*.13*omega)/240
      aerial.x=aerial.x+aerial.vx/240;aerial.y=aerial.y+aerial.vy/240
      for _,axis in ipairs({'x','y'}) do
        if math.abs(aerial[axis])>.09 then aerial[axis]=aerial[axis]>0 and .09 or -.09;aerial['v'..axis]=0 end
      end
    end
  end
end
local function aim_through_line(entry)
  local gun=entry.entity;local target=gun.shooting_target
  if not(target and target.valid and target.health and target.health>0) then return end
  local ammo=gun.get_inventory(defines.inventory.turret_ammo)
  local round=ammo and ammo[1]
  if not(round and round.valid_for_read and (round.name=='cannon-shell' or round.name=='uranium-cannon-shell')) then return end
  local p=gun.position;local dx,dy=target.position.x-p.x,target.position.y-p.y
  local length=math.sqrt(dx*dx+dy*dy);if length<.01 then return end
  dx=dx/length;dy=dy/length
  -- Position-targeted native shells stop at their aim point. Aim at a real
  -- farther enemy of the same priority type so their original piercing budget
  -- can carry through the nearer enemies. Ammo and projectiles stay unchanged.
  local chosen,furthest=target,length
  for _,candidate in pairs(gun.surface.find_entities_filtered{name=target.name,force=target.force,position=p,radius=36}) do
    if candidate.valid and candidate.health and candidate.health>0 then
      local x,y=candidate.position.x-p.x,candidate.position.y-p.y
      local along=x*dx+y*dy;local across=math.abs(x*dy-y*dx)
      if along>furthest and across<=.45 then chosen=candidate;furthest=along end
    end
  end
  if chosen~=target then gun.shooting_target=chosen;entry.line_target=chosen end
end
local function visual(entry,tick)
  local gun=entry.entity
  local mode,frame=M.visual_pose(entry,tick);local heading=M.heading(gun.orientation)
  entry.visual={mode=mode,frame=frame,heading=heading,tick=tick}
  if state().graphics_enabled==false then return end -- explicit physics fixture
  local function layer(pass,animation,offset,render_layer)
    local obj=entry.objects[pass]
    if not(obj and obj.valid) then
      obj=rendering.draw_animation{animation=animation,target=gun,surface=gun.surface,animation_speed=0,
        animation_offset=offset,render_layer=render_layer or 'object'};entry.objects[pass]=obj
    else
      if obj.animation~=animation then obj.animation=animation end
      if obj.animation_offset~=offset then obj.animation_offset=offset end
    end
  end
  layer('shadow',string.format('tp-twin-cannon-shadow-%02d',heading),0,'object-under')
  layer('body',string.format('tp-twin-cannon-%s-body-%02d',mode,heading),frame)
  for bank,aerial in ipairs(entry.aerials) do
    local ix=math.max(0,math.min(4,math.floor(aerial.x/.045+2.5)))
    local iy=math.max(0,math.min(4,math.floor(aerial.y/.045+2.5)))
    layer('aerial'..bank,string.format('tp-twin-cannon-aerial%d-%02d',bank-1,heading),ix*5+iy)
  end
end
function M.tick(event)
  local s=state()
  for k,queue in pairs(s.pending) do
    if queue[1].tick<event.tick then
      -- Every supported native cannon delivery creates its projectile in
      -- the same update. Retain a bounded diagnostic rather than a leak.
      for _,shot in ipairs(queue) do
        if shot.gun.valid then s.guns[shot.gun.unit_number].launch_error='Missing native projectile creation callback' end
      end
      s.pending[k]=nil
    end
  end
  for id,entry in pairs(s.guns) do
    if not entry.entity.valid then
      for _,object in pairs(entry.objects) do if object.valid then object.destroy() end end
      s.guns[id]=nil
    else
      entry.aerials=entry.aerials or {{x=0,y=0,vx=0,vy=0},{x=0,y=0,vx=0,vy=0}}
      aim_through_line(entry)
      flex(entry)
      if event.tick%2==0 then visual(entry,event.tick) end
    end
  end
end
return M
