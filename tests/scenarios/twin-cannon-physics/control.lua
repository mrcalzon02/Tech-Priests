local cannon=require('scripts.twin_cannon_controller')
local NAME='tech-priests-bunker-twin-cannon'
local function check(ok,message)assert(ok,'[TWIN-CANNON] '..message)end
local function key(surface,tick,p)return surface.index..':'..tick..':'..math.floor(p.x*256+.5)..':'..math.floor(p.y*256+.5)end
script.on_init(function()
  local s=game.create_surface('cannon-physics',{default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  storage.probe={sites={},guns={},targets={},pending={},suppressed=0,stock_flashes=0,poses={},flex_peak=0}
  local ammo={'cannon-shell','explosive-cannon-shell','uranium-cannon-shell','explosive-uranium-cannon-shell'}
  local offsets={{0,-24},{17,-17},{24,0},{17,17},{0,24},{-17,17},{-24,0},{-17,-17}}
  game.forces.player.technologies[NAME].researched=true
  check(game.forces.player.recipes[NAME].enabled,'research unlocks recipe')
  for tier,round in ipairs(ammo) do
    for heading,offset in ipairs(offsets) do
      local p={x=(heading-1)*80+.5,y=(tier-1)*80+.5}
      s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
      local tiles={};for x=p.x-30.5,p.x+30.5 do for y=p.y-30.5,p.y+30.5 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
      local gun=s.create_entity{name=NAME,position=p,force='player'}
      local target=s.create_entity{name='tp-cannon-launch-target',position={p.x+offset[1],p.y+offset[2]},force='enemy'};target.disabled_by_script=true
      check(gun.insert{name=round,count=50}==50,'load native shell '..round)
      local site={gun=gun,target=target,ammo=round,heading=heading,launches={},damage={},hits=0}
      local t=storage.probe;t.sites[#t.sites+1]=site;t.guns[gun.unit_number]=site;t.targets[target.unit_number]=site
    end
    local p={x=640.5,y=(tier-1)*80+.5};s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
    local tiles={};for x=p.x-30.5,p.x+30.5 do for y=p.y-30.5,p.y+30.5 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
    local gun=s.create_entity{name='tp-cannon-stock-control',position=p,force='player'}
    local target=s.create_entity{name='tp-cannon-launch-target',position={p.x,p.y-24},force='enemy'};target.disabled_by_script=true
    gun.insert{name=round,count=50}
    local site={gun=gun,target=target,ammo=round,heading=1,stock=true,launches={},damage={},hits=0}
    local t=storage.probe;t.sites[#t.sites+1]=site;t.guns[gun.unit_number]=site;t.targets[target.unit_number]=site
  end
  s.request_to_generate_chunks({720,.5},1);s.force_generate_chunk_requests()
  storage.probe.flex_gun=s.create_entity{name=NAME,position={720,.5},force='player'}
  cannon.init({graphics_enabled=false})
end)
script.on_event(defines.events.on_script_trigger_effect,function(e)
  local t=storage.probe
  if e.effect_id==cannon.fire_effect then
    local gun=e.source_entity;local site=gun and gun.valid and t.guns[gun.unit_number]
    if site then t.pending[key(gun.surface,e.tick,e.source_position)]=site end
  end
  local projectile=e.effect_id==cannon.projectile_effect and e.source_entity
  local before=projectile and projectile.valid and projectile.position
  local site=before and t.pending[key(projectile.surface,e.tick,before)]
  cannon.effect(e)
  if site then
    t.pending[key(projectile.surface,e.tick,before)]=nil
    if site.stock then
      check(projectile.position.x==before.x and projectile.position.y==before.y,'stock launch unchanged')
      site.launches[#site.launches+1]={tick=e.tick,actual=projectile.position}
    else
      local entry=storage.twin_cannon.guns[site.gun.unit_number];local launch=entry.last_launch
      check(launch and launch.tick==e.tick and launch.moved,'original projectile relocated')
      local effect=entry.last_native_effect
      check(effect and effect.tick==e.tick and effect.bank==launch.bank,'native cannon effect paired with firing barrel')
      check(math.abs(effect.muzzle.x-launch.actual.x)<.004 and math.abs(effect.muzzle.y-launch.actual.y)<.004,'native effect foot and projectile share muzzle')
      local angle=effect.orientation*2*math.pi
      check(math.abs(effect.actual.x-launch.actual.x-math.sin(angle)*.16)<.004 and math.abs(effect.actual.y-launch.actual.y+math.cos(angle)*.16)<.004,'native flash centre 0.16 tile ahead of muzzle '..helpers.table_to_json({launch=launch.actual,effect=effect}))
      check(math.abs(effect.orientation-effect.wanted_orientation)<.00001,'native flame follows barrel direction')
      local facing=math.pi-cannon.heading(site.gun.orientation)*2*math.pi/64
      check(effect.render_layer==(math.cos(facing)>1e-6 and 'light-effect' or 'object-under'),'native flame depth follows facing')
      launch.native_effect_bank=effect.bank;launch.native_effect_actual=effect.actual
      launch.native_effect_orientation=effect.orientation;launch.native_effect_muzzle=effect.muzzle
      launch.native_effect_render_layer=effect.render_layer
      check(math.abs(launch.actual.x-launch.wanted.x)<.004 and math.abs(launch.actual.y-launch.wanted.y)<.004,'exact projected muzzle')
      local previous=site.launches[#site.launches]
      if previous then check(launch.bank~=previous.bank,'strict alternating bank') end
      site.launches[#site.launches+1]=launch
    end
  end
end)
script.on_event(defines.events.on_trigger_created_entity,function(e)
  local flash=e.entity;local gun=e.source;local site=gun and gun.valid and storage.probe.guns[gun.unit_number]
  local is_flash=flash and flash.valid and flash.name=='explosion-gunshot'
  local removed=cannon.muzzle_created(e)
  if site and is_flash then
    if site.stock then check(not removed and flash.valid,'stock native flash preserved');storage.probe.stock_flashes=storage.probe.stock_flashes+1
    else
      local effect=storage.twin_cannon.guns[gun.unit_number].last_native_effect
        check(removed and not flash.valid and effect and effect.moved,'original flash replaced with oriented native artwork')
      check(math.abs(effect.actual.x-effect.wanted.x)<.004 and math.abs(effect.actual.y-effect.wanted.y)<.004,'native flash at active barrel')
      storage.probe.suppressed=storage.probe.suppressed+1
    end
  end
end)
script.on_event(defines.events.on_entity_damaged,function(e)
  local site=storage.probe.targets[e.entity.unit_number]
  if site then site.hits=site.hits+1;site.damage[#site.damage+1]={amount=e.final_damage_amount,type=e.damage_type.name} end
end)
script.on_event(defines.events.on_tick,function(e)
  cannon.tick(e);local t=storage.probe
  for _,site in ipairs(t.sites) do
    if not site.stock then
      local entry=storage.twin_cannon.guns[site.gun.unit_number]
      if entry.visual then t.poses[entry.visual.mode]=(t.poses[entry.visual.mode] or 0)+1 end
    end
  end
  if e.tick>=1110 and e.tick<1130 then t.flex_gun.orientation=(t.flex_gun.orientation+.004)%1
  elseif e.tick>=1130 and e.tick<1150 then t.flex_gun.orientation=(t.flex_gun.orientation-.004)%1 end
  local flex_entry=storage.twin_cannon.guns[t.flex_gun.unit_number]
  if e.tick>=1110 then
    for _,aerial in ipairs(flex_entry.aerials) do t.flex_peak=math.max(t.flex_peak,math.sqrt(aerial.x*aerial.x+aerial.y*aerial.y)) end
  end
  if e.tick==1100 then
    for _,site in ipairs(t.sites) do
      local spent=50-site.gun.get_item_count(site.ammo)
      check(spent==#site.launches,'one native shell per launch '..site.ammo)
      site.gun.get_inventory(defines.inventory.turret_ammo).clear()
    end
  elseif e.tick==1200 then
    local report={status='PASS',engine=script.active_mods.base,sites={},native_flashes_positioned=t.suppressed,stock_flashes=t.stock_flashes,visual_modes=t.poses,unarmed_traverse_aerial_peak=t.flex_peak}
    for _,mode in ipairs({'idle','single0','single1','overlap0','overlap1'}) do check((t.poses[mode] or 0)>0,'shot-driven visual state exercised '..mode) end
    check(t.flex_peak>.01,'unarmed traverse bends aerials without firing')
    for _,aerial in ipairs(flex_entry.aerials) do check(math.abs(aerial.x)<.02 and math.abs(aerial.y)<.02,'unarmed aerials settle after turning stops') end
    for _,site in ipairs(t.sites) do
      check(#site.launches>10,'launched repeatedly')
      check(site.hits>10,'hits narrow target '..site.ammo..':'..site.heading)
      for i=2,#site.launches do check(site.launches[i].tick-site.launches[i-1].tick==(site.stock and 90 or 45),'steady native cadence') end
      if not site.stock then check(not storage.twin_cannon.guns[site.gun.unit_number].launch_error,'no callback failure') end
      report.sites[#report.sites+1]={ammo=site.ammo,heading=site.heading,stock=site.stock or false,launches=site.launches,hits=site.hits,damage=site.damage,health=site.target.health}
    end
    check(next(storage.twin_cannon.pending)==nil,'launch queue drained')
    check(t.suppressed>100 and t.stock_flashes>20,'source-scoped native muzzle positioning exercised')
    helpers.write_file('twin-cannon-physics/result.json',helpers.table_to_json(report),false)
  end
end)
