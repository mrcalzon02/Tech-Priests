local barrage=require('scripts.artillery_barrage_controller')
local geometry=require('scripts.artillery_barrage_geometry')
local visual_data=require('scripts.artillery_barrage_visuals')
local NAME='tech-priests-bunker-artillery'
local GRAPHICAL=GRAPHICAL or false
local function check(ok,msg)assert(ok,'[ARTILLERY NATIVE] '..msg)end
local function target(s,p,offset)
  local point={p.x+offset[1],p.y+offset[2]};s.request_to_generate_chunks(point,1);s.force_generate_chunk_requests()
  local enemy=s.create_entity{name='tp-artillery-test-target',position=point,force='enemy'}
  enemy.disabled_by_script=true;return enemy
end
local function add(s,p,offset,force,ammo,mode)
  s.request_to_generate_chunks(p,1);s.force_generate_chunk_requests()
  local gun=s.create_entity{name=mode=='stock' and 'tp-artillery-stock-control' or NAME,position=p,force=force}
  local actual=gun.insert{name='artillery-shell',count=ammo};check(actual==ammo,'loaded native shells '..actual..'/'..ammo)
  local enemy=target(s,p,offset);force.chart(s,{{enemy.position.x-3,enemy.position.y-3},{enemy.position.x+3,enemy.position.y+3}})
  local site={gun=gun,target=enemy,offset=offset,initial=ammo,inserted=0,mode=mode or 'steady',launches={},damage=0,hits=0,force=force.name}
  local t=storage.artillery_test;t.sites[#t.sites+1]=site;t.guns[gun.unit_number]=site;t.targets[enemy.unit_number]=site
  barrage.add(gun);return site
end
script.on_init(function()
  if GRAPHICAL then game.speed=3 end
  local s=game.create_surface('barrage-native',{water=0,default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  s.always_day=true
  storage.artillery_test={sites={},guns={},targets={},last_tick=0}
  local t=storage.artillery_test
  local boosted=game.create_force('artillery-boosted');boosted.set_friend('player',true);game.forces.player.set_friend(boosted,true)
  boosted.custom_color={r=.12,g=.42,b=1}
  boosted.set_gun_speed_modifier('artillery-shell',1);boosted.set_ammo_damage_modifier('artillery-shell',.5)
  game.forces.player.technologies[NAME].researched=true;check(game.forces.player.recipes[NAME].enabled,'native tech recipe unlock')
  local offsets={{0,-160},{160,0},{0,160},{-160,0}}
  for row,force in ipairs({game.forces.player,boosted})do
    for i,offset in ipairs(offsets)do add(s,{x=(i-1)*600+.5,y=(row-1)*600+.5},offset,force,9)end
    add(s,{x=2400.5,y=(row-1)*600+.5},{0,-160},force,9,'stock')
  end
  t.partial=add(s,{x=3000.5,y=.5},{0,-160},game.forces.player,2,'partial')
  t.lost=add(s,{x=3600.5,y=.5},{0,-160},game.forces.player,6,'lost-target')
  t.external=add(s,{x=4200.5,y=.5},{0,-160},game.forces.player,3,'external-disable');t.external.gun.disabled_by_script=true
  t.destroyed=add(s,{x=4800.5,y=.5},{0,-160},game.forces.player,3,'destroyed')
  barrage.init{graphics_enabled=true}
  if GRAPHICAL then
    s.request_to_generate_chunks({6800,0},1);s.force_generate_chunk_requests()
    for i,force in ipairs({game.forces.player,boosted})do
      local display=s.create_entity{name=NAME,position={6797+(i-1)*7,.5},force=force}
      display.disabled_by_script=true;barrage.add(display)
    end
  end
  if visual_data.complete then
    s.request_to_generate_chunks({6600.5,.5},1);s.force_generate_chunk_requests()
    t.heading_probe=s.create_entity{name=NAME,position={6600.5,.5},force='player'}
    t.heading_probe.disabled_by_script=true;barrage.add(t.heading_probe);t.visual_headings=0
  end
  s.request_to_generate_chunks({5400.5,.5},1);s.force_generate_chunk_requests()
  t.manual=add(s,{x=6000.5,y=.5},{0,-400},game.forces.player,1,'manual-target')
  t.manual.flare=s.create_entity{name='artillery-flare',position=t.manual.target.position,force='player',frame_speed=1,vertical_speed=0,height=0,movement={0,0}}
  check(t.manual.flare and t.manual.flare.valid,'native manual targeting flare')
  for i,angle in ipairs({math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4})do
    add(s,{x=7200.5+(i-1)*600,y=.5},{math.sin(angle)*160,-math.cos(angle)*160},game.forces.player,9,'steady')
  end
  t.assembler=s.create_entity{name='assembling-machine-3',position={5400.5,.5},force='player'};t.assembler.set_recipe(NAME)
  for _,ingredient in ipairs(prototypes.recipe[NAME].ingredients)do check(t.assembler.insert{name=ingredient.name,count=ingredient.amount}==ingredient.amount,'exact recipe inputs')end
end)
script.on_event(defines.events.on_trigger_fired_artillery,function(e)
  local t=storage.artillery_test;local gun=e.source;local site=gun and gun.valid and t.guns[gun.unit_number]
  if not site then return end
  local before=e.entity.position;barrage.fired(e)
  local entry=storage.artillery_barrage.guns[gun.unit_number]
  local launch={tick=e.tick,position=before,projectile=e.entity.name,orientation=gun.relative_turret_orientation}
  if site.mode~='stock'then
    check(entry and entry.last_launch.tick==e.tick,'one original projectile notification per native launch')
    launch.chamber=entry.last_chamber;launch.gap=entry.native_gap;launch.reload_gap=entry.reload_gap
    local angle=launch.orientation*2*math.pi
    local h=math.floor((math.atan2(math.sin(angle),math.cos(angle)*math.sqrt(2))/(2*math.pi)%1)*64+.5)%64
    local a=math.pi-h*2*math.pi/64;local p=geometry.muzzle
    launch.wanted={x=gun.position.x+p[1]*math.cos(a)-p[2]*math.sin(a),y=gun.position.y-(p[1]*math.sin(a)+p[2]*math.cos(a)+p[3])/math.sqrt(2)}
    check(math.abs(before.x-launch.wanted.x)<.08 and math.abs(before.y-launch.wanted.y)<.08,'native model-derived launch origin '..helpers.table_to_json(launch))
  end
  site.launches[#site.launches+1]=launch
  if GRAPHICAL and site==t.sites[1] and #site.launches==1 then
    game.take_screenshot{surface=gun.surface,position={gun.position.x,gun.position.y-3.5},resolution={1100,1000},zoom=2,
      show_gui=false,path='artillery-native/first-native-launch.png'}
  end
  if site.mode=='lost-target' and #site.launches==2 then site.target.destroy();site.removed=true end
  if site.mode=='destroyed' and #site.launches==3 then
    check(entry.reload_owned,'destroy during owned reload');t.destroyed_id=gun.unit_number;gun.destroy()
  end
end)
local function camera(player)
  if not GRAPHICAL then return end
  local surface=game.surfaces['barrage-native']
  if not player.character then player.set_controller{type=defines.controllers.character,character=player.physical_surface.create_entity{name='character',position={4.5,2.5},force=player.force}}end
  player.teleport({4.5,2.5},surface);player.zoom=.9
end
script.on_event(defines.events.on_gui_opened,barrage.gui_opened)
script.on_event(defines.events.on_gui_closed,barrage.gui_closed)
script.on_event(defines.events.on_gui_click,barrage.gui_click)
script.on_event(defines.events.on_gui_checked_state_changed,barrage.gui_checked)
script.on_event(defines.events.on_player_created,function(e)camera(game.get_player(e.player_index))end)
script.on_event(defines.events.on_player_joined_game,function(e)camera(game.get_player(e.player_index))end)
script.on_event(defines.events.on_entity_damaged,function(e)
  local site=storage.artillery_test.targets[e.entity.unit_number]
  if site then site.damage=site.damage+e.final_damage_amount;site.hits=site.hits+1 end
end)
local first_tick=true
script.on_event(defines.events.on_tick,function(e)
  local t=storage.artillery_test
  if first_tick then
    first_tick=false
    if GRAPHICAL then game.speed=3 end
    if e.tick>1 then
      local owners=0;for _,v in pairs(storage.artillery_barrage.guns)do if v.reload_owned then owners=owners+1 end end
      t.resume={saved_tick=t.last_tick,tick=e.tick,owners=owners};check(owners>0,'save during actual reload')
    end
  end
  barrage.tick(e);t.assembler.energy=500000
  if t.heading_probe then
    if e.tick>=2501 and e.tick<=2564 then
      local entry=storage.artillery_barrage.guns[t.heading_probe.unit_number]
      check(entry.visual.heading==e.tick-2501,'all 64 native orientations select the matching captured heading')
      check(entry.visual.ammo==0,'empty heading probe has no decorative ammunition')
      t.visual_headings=t.visual_headings+1
    end
    if e.tick>=2500 and e.tick<=2563 then
      local angle=(e.tick-2500)*2*math.pi/64
      t.heading_probe.relative_turret_orientation=math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi)%1
    end
  end
  t.visual_checks=t.visual_checks or 0;t.visual_phases=t.visual_phases or {}
  for _,entry in pairs(storage.artillery_barrage.guns)do
    check(entry.visual and entry.objects.body.valid,'real mechanism rendering exists')
    check(entry.objects.body.animation_speed==0,'native launches select source poses')
    check(entry.objects.body.animation_offset==entry.visual.frame,'source frame is applied')
    local phase=entry.visual.phase
    t.visual_phases[phase<250 and 'recoil-index' or phase<315 and 'lower' or phase<500 and 'open-reload' or phase<550 and 'close' or 'elevate']=true
    t.visual_checks=t.visual_checks+1
  end
  for _,site in ipairs(t.sites)do if site.gun.valid then
    check(site.gun.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count('artillery-shell')+#site.launches==site.initial+site.inserted,'one paid shell per launch')
  end end
  if GRAPHICAL then
    for index=1,4 do
      local site=t.sites[index];local entry=storage.artillery_barrage.guns[site.gun.unit_number]
      if entry and entry.last_chamber==2 and entry.visual then
        site.captured=site.captured or {}
        for stage,phase in ipairs({330,460,485})do
          if entry.visual.phase>=phase and not site.captured[stage]then
            site.captured[stage]=true;t.directional_captures=(t.directional_captures or 0)+1
            game.take_screenshot{surface=site.gun.surface,position={site.gun.position.x,site.gun.position.y-3.5},resolution={1100,1000},zoom=2,
              force_render=true,show_gui=false,path='artillery-native/direction-'..index..'-reload-'..stage..'.png'}
          end
        end
      end
    end
  end
  if e.tick==360 then game.auto_save('artillery-native-mid-reload')end
  if e.tick==700 then
    check(#t.partial.launches==2,'partial ammo stops after two shells')
    t.partial.inserted=t.partial.gun.insert{name='artillery-shell',count=4};check(t.partial.inserted==4,'real partial resupply')
    check(#t.external.launches==0,'external disable respected');t.external.gun.disabled_by_script=false
    if t.lost.removed then
      t.lost.target=target(t.lost.gun.surface,t.lost.gun.position,t.lost.offset)
      t.targets[t.lost.target.unit_number]=t.lost;game.forces.player.chart(t.lost.gun.surface,{{3597,-164},{3604,-156}})
    end
  end
  if e.tick==1000 then
    check(t.destroyed_id and storage.artillery_barrage.guns[t.destroyed_id]==nil,'destroyed owner removed')
    add(game.surfaces['barrage-native'],{x=4800.5,y=.5},{0,-160},game.forces.player,3,'rebuilt')
  end
  if GRAPHICAL and (e.tick==10 or e.tick==100 or e.tick==200 or e.tick==280 or e.tick==350 or e.tick==450 or e.tick==459 or e.tick==466 or e.tick==474 or e.tick==481 or e.tick==489 or e.tick==504 or e.tick==580 or e.tick==1000)then
    local gun=t.sites[1].gun
    game.take_screenshot{surface=gun.surface,position={gun.position.x,gun.position.y-3.5},resolution={1100,1000},zoom=2,
      force_render=true,show_gui=false,path='artillery-native/actual-bunker-'..e.tick..'.png'}
  end
  if GRAPHICAL and e.tick==40 then
    game.take_screenshot{surface=game.surfaces['barrage-native'],position={6800.5,-2},resolution={1100,800},zoom=1.6,
      force_render=true,show_gui=false,path='artillery-native/team-corners.png'}
  end
  if GRAPHICAL and (e.tick==120 or e.tick==320) then local player=game.get_player(1);if player then player.opened=t.sites[1].gun end end
  if GRAPHICAL and (e.tick==135 or e.tick==480) then
    local player=game.get_player(1);check(player and player.opened==player.gui.screen.tp_artillery_live,'complete artillery window opened')
    check(player.gui.screen.tp_artillery_live,'complete live turret preview exists')
    local view=storage.artillery_barrage.viewers[player.index]
    check(view.right.ammunition.inventory==t.sites[1].gun.get_inventory(defines.inventory.artillery_turret_ammo),'real native ammo inventory bound to widget')
    check(player.get_main_inventory(),'actual player inventory available')
    t.real_gui=true
    game.take_screenshot{player=player,force_render=true,resolution={player.display_resolution.width,player.display_resolution.height},show_gui=true,path='artillery-native/'..(e.tick==135 and 'native-preview.png' or 'reload-preview.png')}end
  if GRAPHICAL and (e.tick==150 or e.tick==545) then local player=game.get_player(1);if player then player.opened=nil end end
  if e.tick==3600 then
    local rows={};local controls={}
    for _,site in ipairs(t.sites)do if site.mode=='stock'then controls[site.force]=site end end
    for _,site in ipairs(t.sites)do
      check(#site.launches==site.initial+site.inserted,site.mode..' exhausted exact paid inventory '..#site.launches..'/'..(site.initial+site.inserted))
      if site.mode~='lost-target'then check(site.damage>0,'original native shells cause damage')end
      if site.mode=='steady'then
        local control=controls[site.force]
        check(math.abs(site.damage/#site.launches-control.damage/#control.launches)<.001,'per-shell damage matches the native control')
      end
      for i=2,#site.launches do
        local prev,now=site.launches[i-1],site.launches[i];local gap=now.tick-prev.tick
        if site.mode=='stock'then check(gap==(site.force=='player' and 200 or 100),'native stock control cadence')
        elseif site.mode=='steady'then
          local wanted=prev.chamber==2 and (site.force=='player' and 420 or 210) or (site.force=='player' and 90 or 45)
          check(gap==wanted,'three-shot cadence '..gap..'/'..wanted)
          check(now.chamber==(prev.chamber+1)%3,'sequential revolving chambers')
        end
      end
      rows[#rows+1]={mode=site.mode,force=site.force,shots=#site.launches,damage=site.damage,launches=site.launches}
    end
    check(t.assembler.get_output_inventory().get_item_count(NAME)==1,'native assembler produced turret')
    check(t.assembler.get_inventory(defines.inventory.crafter_input).is_empty(),'native recipe exact consumption')
    if t.resume then check(t.resume.tick==t.resume.saved_tick+1,'serialized next tick resumed')end
    if GRAPHICAL then check(t.directional_captures==12,'all four directional cage and shell-insertion captures requested')end
    helpers.write_file('artillery-native/'..(GRAPHICAL and 'graphical.json' or 'result.json'),helpers.table_to_json({status='PASS',actual_art=true,animated_art=GRAPHICAL,real_gui=t.real_gui,sites=rows,resume=t.resume,recipe_outputs=1,visual_checks=t.visual_checks,visual_phases=t.visual_phases,visual_headings=t.visual_headings}),false)
  end
  t.last_tick=e.tick
end)
