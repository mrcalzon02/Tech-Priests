local rocket=require('scripts.rocket_salvo_controller')
local function check(ok,message)assert(ok,'[ROCKET ANIMATION] '..message)end
local function capture(name,site,gui)
  if not GRAPHICAL then return end
  game.take_screenshot{surface=storage.pilot.surface,position={site.gun.position.x,site.gun.position.y-1.2},
    resolution={960,720},zoom=3,show_gui=gui or false,show_entity_info=false,path='rocket-salvo-animated/'..name..'.png'}
end
script.on_init(function()
  if GRAPHICAL then game.speed=3 end
  local surface=game.create_surface('rocket-animation',{water=0,default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  surface.always_day=true
  local forces={game.forces.player}
  for _,name in ipairs({'blue-test','green-test','red-test'}) do forces[#forces+1]=game.create_force(name)end
  for _,force in ipairs(forces) do for _,other in ipairs(forces) do force.set_friend(other,true);force.set_cease_fire(other,true)end end
  for i,c in ipairs({{1,.7,.05},{.05,.3,1},{.1,1,.2},{1,.08,.05}}) do forces[i].custom_color={r=c[1],g=c[2],b=c[3]}end
  storage.pilot={surface=surface,sites={},poses={},captures={},hits=0,effects=0}
  local offsets={{0,-26},{26,0},{0,26},{-26,0}}
  for tier,ammo in ipairs({'rocket','explosive-rocket'}) do
    for heading,offset in ipairs(offsets) do
      local p={x=(heading-1)*80+.5,y=(tier-1)*80+.5};surface.request_to_generate_chunks(p,1);surface.force_generate_chunk_requests()
      local tiles={};for x=p.x-10.5,p.x+10.5 do for y=p.y-10.5,p.y+10.5 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;surface.set_tiles(tiles)
      local gun=surface.create_entity{name='tech-priests-bunker-rocket-salvo',position=p,force=forces[heading]}
      local target=surface.create_entity{name='tp-rocket-animation-target',position={p.x+offset[1],p.y+offset[2]},force='enemy'};target.disabled_by_script=true
      gun.orientation=(heading-1)/4
      check(gun.insert{name=ammo,count=12}==12,'load twelve native rockets')
      storage.pilot.sites[#storage.pilot.sites+1]={gun=gun,target=target,ammo=ammo,heading=(heading-1)*16,shots=0}
    end
  end
  rocket.init({capture_headings={0,16,32,48}})
end)
script.on_event(defines.events.on_script_trigger_effect,function(e)
  rocket.effect(e)
  if e.effect_id==rocket.fire_effect then
    for _,site in ipairs(storage.pilot.sites) do if site.gun==e.source_entity then site.shots=site.shots+1 end end
  end
end)
script.on_event(defines.events.on_trigger_created_entity,function(e)
  if rocket.muzzle_created(e) then
    local entry=storage.rocket_salvo.guns[e.source.unit_number]
    check(entry.last_muzzle_effect.moved,'native launch effect relocated');storage.pilot.effects=storage.pilot.effects+1
  end
end)
script.on_event(defines.events.on_entity_damaged,function(e)
  if e.entity.name=='tp-rocket-animation-target' then storage.pilot.hits=storage.pilot.hits+1 end
end)
script.on_event(defines.events.on_tick,function(e)
  rocket.tick(e);local p=storage.pilot
  for _,site in ipairs(p.sites) do
    local entry=storage.rocket_salvo.guns[site.gun.unit_number];check(entry and entry.visual,'actual graphics state')
    check(entry.objects.body.valid and entry.objects.shadow.valid,'real native body and shadow objects')
    for i=0,5 do check(entry.objects['nose'..i] and entry.objects['nose'..i].valid,'actual rocket nose layer')end
    p.poses[entry.visual.mode]=true
  end
  local site=p.sites[1];local entry=storage.rocket_salvo.guns[site.gun.unit_number];local v=entry.visual
  if e.tick==2 then for i,s in ipairs(p.sites) do capture('initial-facing-'..i,s)end end
  if v.mode=='reload' then
    for name,range in pairs({opening={88,96},feeding={138,146},closing={190,198}}) do
      if v.source_frame>=range[1] and v.source_frame<=range[2] and not p.captures[name] then
        p.captures[name]=true;capture(name,site)
      end
    end
  end
  if e.tick==100 then game.auto_save('rocket-animation-mid-reload')end
  if e.tick==600 and GRAPHICAL then
    local player=game.get_player(1)
    if player then player.set_controller{type=defines.controllers.god};player.teleport({-3,1},p.surface);player.opened=site.gun end
  end
  if e.tick==602 then capture('native-inventory-preview',site,true)end
  if e.tick==620 and GRAPHICAL then local player=game.get_player(1);if player then player.opened=nil end end
  if e.tick==800 then
    local rows={}
    for i,s in ipairs(p.sites) do
      local ent=storage.rocket_salvo.guns[s.gun.unit_number]
      check(s.shots==12 and s.gun.get_item_count(s.ammo)==0,'exact native ammo for two salvos')
      check(ent.visual.mode=='idle' and not s.gun.disabled_by_script,'empty launcher settled and enabled')
      for cell=0,5 do check(not ent.objects['nose'..cell].visible,'no displayed rockets without ammo')end
      check(s.target.health<1000000,'native rocket damage')
      capture('empty-facing-'..i,s)
      rows[#rows+1]={ammo=s.ammo,heading=s.heading,shots=s.shots,health=s.target.health,visual=ent.visual}
    end
    check(p.poses.idle and p.poses.reload and p.captures.opening and p.captures.feeding and p.captures.closing,'all checked reload phases visited')
    helpers.write_file('rocket-salvo-animated/'..(GRAPHICAL and 'result-graphical.json' or 'result.json'),helpers.table_to_json({status='PASS',
      scope='Actual four-heading sprite pilot; static shadows only, full headings and moving shadows remain open',sites=rows,poses=p.poses,effects=p.effects,hits=p.hits}),false)
    if GRAPHICAL then game.tick_paused=true end
  end
end)
