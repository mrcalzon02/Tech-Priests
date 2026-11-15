local rocket=require('scripts.rocket_salvo_controller')
local GRAPHICAL=GRAPHICAL or false
local NAME='tech-priests-bunker-rocket-salvo'
local function check(ok,message)assert(ok,'[ROCKET SALVO] '..message)end
local function key(surface,tick,p)return surface.index..':'..tick..':'..math.floor(p.x*256+.5)..':'..math.floor(p.y*256+.5)end
local function target(surface,p,offset)
  local enemy=surface.create_entity{name='tp-rocket-test-target',position={p.x+offset[1],p.y+offset[2]},force='enemy'}
  enemy.disabled_by_script=true;return enemy
end
local function add_site(s,p,offset,ammo,count,mode)
  s.request_to_generate_chunks(p,1);s.force_generate_chunk_requests()
  local gun=s.create_entity{name=mode=='stock' and 'tp-rocket-stock-control' or NAME,position=p,force='player'}
  check(gun~=nil,'turret created')
  local enemy=target(s,p,offset);check(gun.insert{name=ammo,count=count}==count,'real rocket inventory loaded')
  local site={gun=gun,target=enemy,ammo=ammo,initial=count,inserted=0,mode=mode or 'steady',launches={},hits=0,damage=0,offset=offset}
  local t=storage.probe;t.sites[#t.sites+1]=site;t.guns[gun.unit_number]=site;t.targets[enemy.unit_number]=site
  return site
end
script.on_init(function()
  if GRAPHICAL then game.speed=12 end
  local s=game.create_surface('rocket-native',{water=0,default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  storage.probe={sites={},guns={},targets={},origins={},headings={},stock_unchanged=0}
  local t=storage.probe
  game.forces.player.technologies[NAME].researched=true
  check(game.forces.player.recipes[NAME].enabled,'native technology unlocks turret recipe')
  local offsets={{0,-26},{18,-18},{26,0},{18,18},{0,26},{-18,18},{-26,0},{-18,-18}}
  for tier,ammo in ipairs({'rocket','explosive-rocket'}) do
    for heading,offset in ipairs(offsets) do
      local site=add_site(s,{x=(heading-1)*80+.5,y=(tier-1)*80+.5},offset,ammo,36)
      site.heading=heading
    end
    add_site(s,{x=640.5,y=(tier-1)*80+.5},{0,-26},ammo,36,'stock')
  end
  t.partial=add_site(s,{x=720.5,y=.5},{0,-26},'rocket',3,'partial')
  t.lost=add_site(s,{x=800.5,y=.5},{0,-26},'rocket',12,'lost-target')
  t.external=add_site(s,{x=880.5,y=.5},{0,-26},'rocket',12,'external-disable')
  t.external.gun.disabled_by_script=true
  t.destroyed=add_site(s,{x=960.5,y=.5},{0,-26},'rocket',12,'destroyed')
  rocket.init({graphics_enabled=false})
end)
script.on_event(defines.events.on_script_trigger_effect,function(e)
  local t=storage.probe
  if e.effect_id==rocket.fire_effect then
    local gun=e.source_entity;local site=gun and gun.valid and t.guns[gun.unit_number]
    if site then t.origins[key(gun.surface,e.tick,e.source_position)]=site end
  end
  local projectile=e.effect_id==rocket.born_effect and e.source_entity
  local before=projectile and projectile.valid and projectile.position
  local site=before and t.origins[key(projectile.surface,e.tick,before)]
  rocket.effect(e)
  if site then
    t.origins[key(projectile.surface,e.tick,before)]=nil
    if site.mode=='stock' then
      check(projectile.position.x==before.x and projectile.position.y==before.y,'stock native projectile origin unchanged')
      t.stock_unchanged=t.stock_unchanged+1
      site.launches[#site.launches+1]={tick=e.tick,projectile=projectile.name,phase=e.tick<600 and 'base' or 'boost'}
    else
      local entry=storage.rocket_salvo.guns[site.gun.unit_number];local launch=entry.last_launch
      check(launch and launch.tick==e.tick and launch.moved,'original rocket moved successfully')
      check(launch.projectile==site.ammo,'native rocket type retained')
      check(launch.cell==#site.launches%6,'strict alternating six-cell order')
      check(math.abs(launch.actual.x-launch.wanted.x)<.004 and math.abs(launch.actual.y-launch.wanted.y)<.004,'calibrated actual muzzle origin')
      launch.phase=e.tick<600 and 'base' or 'boost'
      site.launches[#site.launches+1]=launch
      t.headings[rocket.heading(site.gun.orientation)]=true
      if site.mode=='steady' then
        local previous=site.launches[#site.launches-1]
        if previous and previous.phase==launch.phase then
          local gap=launch.tick-previous.tick
          local expected=previous.cell==5 and (launch.phase=='base' and 190 or 95) or (launch.phase=='base' and 10 or 5)
          -- The initial tick-zero entity update can be one tick short.
          check(gap==expected or previous.tick==0 and gap==expected-1,'salvo/reload cadence '..gap..' expected '..expected)
        end
      end
    end
  end
end)
script.on_event(defines.events.on_trigger_created_entity,function(e)
  if rocket.muzzle_created(e) then
    local entry=storage.rocket_salvo.guns[e.source.unit_number];local fx=entry.last_muzzle_effect
    check(fx.moved and math.abs(fx.actual.x-fx.wanted.x)<.004 and math.abs(fx.actual.y-fx.wanted.y)<.004,'native launch effect at active cell')
    storage.probe.muzzle_effects=(storage.probe.muzzle_effects or 0)+1
  end
end)
local function camera(player)
  if not GRAPHICAL then return end
  player.set_controller{type=defines.controllers.god}
  player.teleport({520.5,40},game.surfaces['rocket-native']);player.zoom=.035
end
script.on_event(defines.events.on_player_created,function(e)camera(game.get_player(e.player_index))end)
script.on_event(defines.events.on_player_joined_game,function(e)camera(game.get_player(e.player_index))end)
script.on_event(defines.events.on_entity_damaged,function(e)
  local site=storage.probe.targets[e.entity.unit_number]
  if site then site.hits=site.hits+1;site.damage=site.damage+e.final_damage_amount end
end)
local first_tick=true
script.on_event(defines.events.on_tick,function(e)
  local t=storage.probe
  if first_tick then
    first_tick=false
    if e.tick>1 then
      local saved_shots=0;local reloads=0
      for _,entry in pairs(storage.rocket_salvo.guns) do saved_shots=saved_shots+entry.shots;if entry.reload_owned then reloads=reloads+1;check(entry.entity.disabled_by_script,'reload inhibit persists')end end
      t.resume={tick=e.tick,saved_tick=t.last_completed_tick,saved_shots=saved_shots,reload_owners=reloads}
      check(reloads>0,'save taken during real reload')
    end
  end
  rocket.tick(e)
  for _,site in ipairs(t.sites) do
    if site.gun.valid then
      local left=site.gun.get_inventory(defines.inventory.turret_ammo).get_item_count(site.ammo)
      check(left+#site.launches==site.initial+site.inserted,'exact one native ammunition item per rocket')
    end
  end
  if #t.lost.launches==2 and not t.lost.removed then
    t.lost.target.destroy();t.lost.removed=true;t.lost.lost_tick=e.tick
  end
  if e.tick==300 then
    local site=t.lost;check(#site.launches==2,'no phantom shots after target loss')
    site.target=target(site.gun.surface,site.gun.position,{0,26});t.targets[site.target.unit_number]=site
  end
  if e.tick==320 then game.auto_save('rocket-salvo-mid-reload') end
  if e.tick==350 then
    check(#t.partial.launches==3,'partial salvo stops with empty ammo')
    check(t.partial.gun.insert{name='rocket',count=3}==3,'partial real resupply');t.partial.inserted=3
  end
  if e.tick==400 then check(#t.external.launches==0,'external disable respected');t.external.gun.disabled_by_script=false end
  if t.destroyed.gun.valid and #t.destroyed.launches==6 then
    local entry=storage.rocket_salvo.guns[t.destroyed.gun.unit_number]
    check(entry.reload_owned,'destroy fixture reaches reload');t.destroyed_id=t.destroyed.gun.unit_number;t.destroyed.gun.destroy()
  end
  if e.tick==500 then
    check(storage.rocket_salvo.guns[t.destroyed_id]==nil,'destroyed reload owner removed')
    t.rebuilt=add_site(game.surfaces['rocket-native'],{x=1040.5,y=.5},{0,-26},'rocket',6,'rebuilt')
  end
  if e.tick==600 then
    game.forces.player.set_gun_speed_modifier('rocket',1)
    game.forces.player.set_ammo_damage_modifier('rocket',.5)
  end
  if e.tick==900 then
    check(#t.partial.launches==6,'six paid rounds complete interrupted salvo')
    check(t.partial.gun.insert{name='rocket',count=6}==6,'second real resupply');t.partial.inserted=9
  end
  if e.tick==1700 then
    local rows={};local heading_count=0;for _ in pairs(t.headings) do heading_count=heading_count+1 end
    for _,site in ipairs(t.sites) do
      local count=#site.launches
      local expected=site.mode=='destroyed' and 6 or site.initial+site.inserted
      check(count==expected,site.mode..' exhausted exact inventory '..count..'/'..expected)
      check(site.damage>0,'original projectiles cause real damage')
      local expected_damage=0
      for _,launch in ipairs(site.launches) do expected_damage=expected_damage+(site.ammo=='rocket' and 200 or 150)*(launch.phase=='boost' and 1.5 or 1)end
      -- The first two native rockets lose their target in flight in this
      -- deliberate destruction fixture; they cannot damage its replacement.
      if site.mode=='lost-target' then expected_damage=expected_damage-400 end
      check(math.abs(site.damage-expected_damage)<.001,'native damage and research multiplier preserved '..site.damage..'/'..expected_damage)
      if site.gun.valid and site.mode~='stock' then check(not site.gun.disabled_by_script,'empty turret releases reload inhibit')end
      rows[#rows+1]={ammo=site.ammo,mode=site.mode,heading=site.heading,shots=count,damage=site.damage,hits=site.hits,launches=site.launches}
    end
    check(heading_count>=8,'all eight aim directions observed')
    check(t.stock_unchanged==72,'stock rocket origins preserved')
    if GRAPHICAL then check((t.muzzle_effects or 0)>0,'visible native launch effects exercised')end
    check(next(storage.rocket_salvo.pending)==nil,'no orphaned projectile origin queues')
    if t.resume then check(t.resume.saved_tick and t.resume.tick==t.resume.saved_tick+1,'reload begins immediately after actual saved tick')end
    helpers.write_file('rocket-salvo-physics/'..(GRAPHICAL and 'result-graphical.json' or 'result.json'),helpers.table_to_json({status='PASS',
      scope='Native combat physics only; no final art acceptance',sites=rows,headings=heading_count,
      stock_unchanged=t.stock_unchanged,muzzle_effects=t.muzzle_effects or 0,resume=t.resume}),false)
    if GRAPHICAL then game.tick_paused=true end
  end
  t.last_completed_tick=e.tick
end)
