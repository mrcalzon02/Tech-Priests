local cannon=require('scripts.twin_cannon_controller')
local session_checked=false
local function check(ok,msg) assert(ok,'[CANNON-ART-PILOT] '..msg) end
local function capture(path,zoom,position,gui)
  if not GRAPHICAL then return end
  game.take_screenshot{surface=storage.pilot.surface,position=position or {13.5,-8.5},resolution=gui and {1280,800} or (zoom and {800,800} or {1600,1000}),
    zoom=zoom or 1.25,path='twin-cannon-animated-pilot/'..path..'.png',show_gui=gui or false,player=gui and 1 or nil}
end
script.on_init(function()
  local surface=game.create_surface('twin-cannon-animated-pilot',{default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  surface.always_day=true;surface.request_to_generate_chunks({12,-7},2);surface.force_generate_chunk_requests()
  local tiles={};for x=-8,38 do for y=-25,8 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;surface.set_tiles(tiles)
  storage.pilot={surface=surface,sites={},snapshots={},modes={},hits=0}
  local ammo={'cannon-shell','explosive-cannon-shell','uranium-cannon-shell','explosive-uranium-cannon-shell'}
  for index,round in ipairs(ammo) do
    local x=(index-1)*9
    local gun=surface.create_entity{name='tech-priests-bunker-twin-cannon',position={x,0},force='player'};gun.orientation=0
    local target=surface.create_entity{name='tp-cannon-pilot-target',position={x,-18},force='enemy'};target.disabled_by_script=true
    target.teleport({gun.position.x,gun.position.y-18},nil,false,false)
    check(gun.insert{name=round,count=4}==4,'load four native shells')
    storage.pilot.sites[#storage.pilot.sites+1]={gun=gun,target=target,ammo=round,launches=0}
    rendering.draw_text{surface=surface,target={x,3},text=round,color={1,1,1},alignment='center'}
  end
  cannon.init()
end)
script.on_event(defines.events.on_script_trigger_effect,function(e)
  cannon.effect(e)
  if e.effect_id==cannon.fire_effect then
    local gun=e.source_entity
    for index,site in ipairs(storage.pilot.sites) do if site.gun==gun then
      site.launches=site.launches+1
      if index==1 and site.launches==1 then storage.pilot.first_shot=e.tick end
      if index==1 and site.launches==4 then storage.pilot.last_shot=e.tick end
    end end
  end
end)
script.on_event(defines.events.on_trigger_created_entity,cannon.muzzle_created)
script.on_event(defines.events.on_entity_damaged,function(e)
  if e.entity.name=='tp-cannon-pilot-target' then storage.pilot.hits=storage.pilot.hits+1 end
end)
script.on_event(defines.events.on_tick,function(e)
  cannon.tick(e);local p=storage.pilot
  if not session_checked then
    session_checked=true
    if p.last_seen_tick then
      local shots=0;for _,site in ipairs(p.sites) do shots=shots+site.launches end
      p.resume={saved_tick=p.last_seen_tick,resumed_tick=e.tick,saved_shots=shots}
    end
  end
  p.last_seen_tick=e.tick
  for _,site in ipairs(p.sites) do
    if site.gun.get_item_count(site.ammo)>0 then site.gun.shooting_target=site.target end
    local entry=storage.twin_cannon.guns[site.gun.unit_number]
    check(entry and entry.visual,'live visual controller')
    check(entry.objects.body and entry.objects.body.valid,'real body animation object')
    for _,name in ipairs({'shadow','aerial1','aerial2'}) do check(entry.objects[name] and entry.objects[name].valid,'real '..name..' animation object') end
    p.modes[entry.visual.mode]=(p.modes[entry.visual.mode] or 0)+1
  end
  if p.first_shot then
    local age=e.tick-p.first_shot
    if age==1 or age==4 or age==20 or age==40 or age==49 or age==65 then capture('recoil-age-'..age,4,{0,-1.5}) end
  end
  if e.tick==100 then game.auto_save('twin-cannon-pilot-mid-recoil') end
  if e.tick==260 then capture('four-ammo-world') end
  if e.tick==300 and GRAPHICAL then
    local player=game.get_player(1)
    if player then player.set_controller{type=defines.controllers.god};player.teleport({-3,1},p.surface);player.opened=p.sites[1].gun end
  end
  if e.tick==302 then capture('native-inventory-preview',nil,{0,0},true) end
  if e.tick==400 then
    local report={status='PASS',scope='Real two-heading animation pilot, four native ammunition types; full direction capture remains in progress',
      sites={},modes=p.modes,hits=p.hits,resume=p.resume}
    for _,site in ipairs(p.sites) do
      local entry=storage.twin_cannon.guns[site.gun.unit_number]
      check(site.launches==4 and site.gun.get_item_count(site.ammo)==0,'one native shell per shot '..helpers.table_to_json({ammo=site.ammo,shots=site.launches,count=site.gun.get_item_count(site.ammo),orientation=site.gun.orientation,status=site.gun.status}))
      check(entry.visual.mode=='idle','empty turret returned to battery')
      check(site.target.health<1000000,'native projectile damaged target')
      report.sites[#report.sites+1]={ammo=site.ammo,shots=site.launches,health=site.target.health,visual=entry.visual}
    end
    for _,mode in ipairs({'idle','single0','single1','overlap0','overlap1'}) do check(p.modes[mode],'real body state '..mode) end
    helpers.write_file('twin-cannon-animated-pilot/result.json',helpers.table_to_json(report),false)
    capture('empty-return-to-battery',4,{0,-1.5})
    if GRAPHICAL then game.tick_paused=true end
  end
end)
