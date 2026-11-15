local visuals=require('scripts.bunker_family_visuals');visuals.install()
local families={
  {name='tech-priests-bunker-autocannon',ammo='tech-priests-autocannon-magazine'},
  {name='tech-priests-bunker-lobber',ammo='tech-priests-lobber-grenade-magazine'},
  {name='tech-priests-bunker-energy-dish'},
  {name='tech-priests-bunker-lobber',ammo='tech-priests-lobber-cluster-grenade-magazine'},
  {name='tech-priests-bunker-lobber',ammo='tech-priests-lobber-tp-fixture-cryogenic-grenade-magazine'}
}
local function check(ok,message) assert(ok,'[BUNKER-FAMILY] '..message) end
script.on_init(function()
  visuals.init()
  game.speed=3
  storage.family={sites={},hits={},done=false}
  local s=game.create_surface('bunker-family-proof',{water=0,starting_area=0,
    default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}}})
  s.always_day=true;s.peaceful_mode=true
  local offsets={{0,-18},{12.73,-12.73},{18,0},{12.73,12.73},{0,18},{-12.73,12.73},{-18,0},{-12.73,-12.73}}
  for family,def in ipairs(families) do
    game.forces.player.technologies[def.name].researched=true
    check(game.forces.player.recipes[def.name].enabled,'research unlock '..def.name)
    for heading,offset in ipairs(offsets) do
      local x=(heading-1)*80+.5;local y=(family-1)*80+.5
      s.request_to_generate_chunks({x,y},2);s.force_generate_chunk_requests()
      for _,e in pairs(s.find_entities_filtered{area={{x-28,y-28},{x+28,y+28}}}) do e.destroy() end
      local tiles={}
      for tx=x-25.5,x+25.5 do for ty=y-25.5,y+25.5 do tiles[#tiles+1]={name='refined-concrete',position={tx,ty}} end end
      s.set_tiles(tiles)
      local gun=check(s.can_place_entity{name=def.name,position={x,y},force='player'},'placement')
      gun=s.create_entity{name=def.name,position={x,y},force='player',direction=defines.direction.north}
      check(gun and gun.valid,'create '..def.name)
      visuals.add(gun)
      local target=s.create_entity{name='tp-family-target',position={x+offset[1],y+offset[2]},force='enemy'}
      target.disabled_by_script=true
      local site={gun=gun,target=target,family=family,heading=heading,ammo=def.ammo,hits=0,ticks={}}
      storage.family.sites[#storage.family.sites+1]=site;storage.family.hits[target.unit_number]=site
      if def.ammo then
        check(not gun.get_inventory(defines.inventory.turret_ammo).can_insert{name='firearm-magazine',count=1},'reject rifle ammo')
        if heading==1 then
          site.chest=s.create_entity{name='steel-chest',position={x,y+3},force='player'}
          site.inserter=s.create_entity{name='burner-inserter',position={x,y+2},force='player',direction=defines.direction.south}
          site.inserter.get_fuel_inventory().insert{name='coal',count=50}
        end
      else
        site.power=s.create_entity{name='electric-energy-interface',position={x+4,y+4},force='player'}
        site.power.power_production=100000000;site.power.energy=0;site.power.disabled_by_script=true
        site.pole=s.create_entity{name='substation',position={x+4,y},force='player'}
      end
    end
  end
  local pack_position={720.5,80.5}
  s.request_to_generate_chunks(pack_position,2);s.force_generate_chunk_requests()
  local gun=s.create_entity{name='tech-priests-bunker-lobber',position=pack_position,force='player'}
  visuals.add(gun)
  local target=s.create_entity{name='tp-family-target',position={720.5,62.5},force='enemy'}
  target.disabled_by_script=true
  local pack={gun=gun,target=target,hits=0,ticks={},family=6,heading=1}
  storage.family.pack_fixture=pack;storage.family.hits[target.unit_number]=pack
  log('[BUNKER-FAMILY] INIT '..#storage.family.sites..' sites, eight aim directions per weapon/ammunition variant')
end)
script.on_event(defines.events.on_entity_damaged,function(e)
  local t=storage.family;if not t then return end
  local site=t.hits[e.entity.unit_number]
  if site then
    site.hits=site.hits+1;site.ticks[#site.ticks+1]=e.tick
    site.damage_types=site.damage_types or {};site.damage_types[e.damage_type.name]=true
  end
end)
script.on_event(defines.events.on_entity_died,function(e)
  local t=storage.family;if not t then return end
  for _,site in ipairs(t.sites) do
    if site.gun==e.entity then
      log('[BUNKER-FAMILY] TURRET_DIED family='..site.family..' heading='..site.heading..' cause='..
        (e.cause and e.cause.valid and e.cause.name or 'none')..' force='..(e.force and e.force.name or 'none'))
    end
  end
end)
local function screenshot(site,name)
  if game.is_multiplayer() then return end
  game.take_screenshot{surface=site.gun.surface,position={site.gun.position.x,site.gun.position.y-1},
    resolution={960,720},zoom=2,path='bunker-family/'..name..'.png',show_gui=false,force_render=true}
end
script.on_event(defines.events.on_player_created,function(e)
  local p=game.get_player(e.player_index);p.teleport({.5,-2},storage.family.sites[1].gun.surface);p.zoom=1.5
end)
script.on_event(defines.events.on_tick,function(e)
  visuals.tick(e)
  local t=storage.family;if not t then return end
  if e.tick==180 then
    local player=game.get_player(1)
    if player then
      local site=t.sites[9];player.teleport({site.gun.position.x-3,site.gun.position.y},site.gun.surface)
      player.opened=site.gun
    end
  elseif e.tick==182 then
    local player=game.get_player(1)
    if player then game.take_screenshot{player=player,resolution={1440,900},show_gui=true,
      path='bunker-family/lobber-native-gui-preview.png',force_render=true} end
  end
  if e.tick>500 and e.tick<1500 then
    for _,site in ipairs(t.sites) do
      if site.family==3 and site.heading==5 then
        local fx=(storage.bunker_dish_charge or {})[site.gun.unit_number]
        if fx then
          local age=e.tick-fx.last_discharge
          if age==1 or age==4 or age==20 or age==40 or age==60 or age==80 or age==100 or age==116 then
            screenshot(site,'dish-charge-'..fx.last_discharge..'-'..age)
          end
        end
      end
    end
  end
  if t.done then
    if e.tick>=2900 and e.tick<3540 and (e.tick-2900)%10==0 then
      local heading=(e.tick-2900)/10
      for _,site in ipairs(t.sites) do
        if site.heading==5 then
          site.gun.disabled_by_script=true;site.gun.orientation=heading/64
          check(site.gun.direction==defines.direction.north,'base moved during independent 64-heading traverse')
        end
      end
      visuals.tick(e)
      for _,site in ipairs(t.sites) do if site.heading==5 then screenshot(site,'traverse-'..site.family..'-'..heading) end end
    elseif e.tick==3540 then
      helpers.write_file('bunker-family/traverse.json',helpers.table_to_json({status='PASS',
        weapons=3,headings=64,base_placement='north throughout',cap_orientation='independent LuaEntity.orientation'}),false)
      log('[BUNKER-FAMILY] INDEPENDENT_64_HEADING_TRAVERSE_PASS')
    end
    return
  end
  if e.tick==120 then
    check(t.pack_fixture.gun.insert{name='tech-priests-lobber-grenade-magazine',count=1}==1,'load one six-round pack')
    for _,site in ipairs(t.sites) do
      check(site.hits==0,'empty/unpowered turret fired')
      if site.ammo then
        if site.chest then site.chest.insert{name=site.ammo,count=50}
        else check(site.gun.insert{name=site.ammo,count=50}==50,'load actual ammo') end
      else site.power.disabled_by_script=false end
    end
    log('[BUNKER-FAMILY] EMPTY_AMMO_AND_NO_POWER_PASS')
  elseif e.tick>=600 and e.tick<=680 and e.tick%10==0 then
    for _,site in ipairs(t.sites) do
      if site.heading==5 then screenshot(site,'weapon-'..site.family..'-tick-'..e.tick) end
    end
  elseif e.tick==1000 then
    for _,site in ipairs(t.sites) do
      check(site.gun.direction==defines.direction.north,'base placement direction changed with aim')
      screenshot(site,'weapon-'..site.family..'-aim-'..site.heading)
    end
  elseif e.tick==1800 then
    check(t.pack_fixture.hits==6,'one pack must fire exactly six grenades')
    check(t.pack_fixture.gun.get_inventory(defines.inventory.turret_ammo).is_empty(),'six shots empty one pack')
    local diagnostic={}
    for _,site in ipairs(t.sites) do diagnostic[#diagnostic+1]={family=site.family,heading=site.heading,hits=site.hits,ticks=site.ticks,status=site.gun.status,ammo=site.ammo and site.gun.get_item_count(site.ammo),energy=site.gun.energy} end
    log('[BUNKER-FAMILY] DIAGNOSTIC '..helpers.table_to_json(diagnostic))
    for _,site in ipairs(t.sites) do
      check(site.hits>5,'weapon failed to damage in direction '..site.family..':'..site.heading)
      if site.chest then check(site.chest.get_item_count(site.ammo)<50,'inserter supply') end
      if site.ammo then
        site.gun.get_inventory(defines.inventory.turret_ammo).clear()
        if site.inserter then site.inserter.disabled_by_script=true;site.inserter.held_stack.clear() end
      else site.power.disabled_by_script=true;site.power.energy=0 end
    end
    log('[BUNKER-FAMILY] COMBAT_AND_INSERTER_PASS')
  elseif e.tick==2200 then
    for _,site in ipairs(t.sites) do site.stopped_hits=site.hits end
  elseif e.tick==2400 then
    for _,site in ipairs(t.sites) do
      check(site.hits==site.stopped_hits,'weapon fires without ammo/power after depletion')
      if site.ammo then site.gun.insert{name=site.ammo,count=5}
      else site.power.disabled_by_script=false end
    end
    log('[BUNKER-FAMILY] DEPLETION_PASS')
  elseif e.tick==2800 then
    check(t.pack_fixture.hits==6,'no seventh shot from a six-round pack')
    local result={status='PASS',engine=script.active_mods.base,sites={},native_weapons=true,one_pack_shots=t.pack_fixture.hits}
    for _,site in ipairs(t.sites) do
      check(site.hits>site.stopped_hits,'resume after resupply '..site.family..':'..site.heading)
      check(site.gun.valid,'turret destroyed family '..site.family..' heading '..site.heading)
      check(site.gun.direction==defines.direction.north,'fixed base after firing')
      if site.family==3 then check(site.damage_types.electric,'dish electrical damage') end
      if site.family==5 then check(site.damage_types['tp-fixture-cryo'],'modded grenade damage preserved') end
      if site.family==2 then
        local v=storage.bunker_cap_visuals[site.gun.unit_number]
        check(v and v.shots and v.shots>=site.hits,'shot-driven cap animation')
        local steady={}
        for _,tick in ipairs(site.ticks) do if tick>400 and tick<1700 then steady[#steady+1]=tick end end
        for n=2,#steady do check(steady[n]-steady[n-1]==80,'exact 80-tick lobber cadence') end
      end
      result.sites[#result.sites+1]={weapon=site.gun.name,heading=site.heading,hits=site.hits,
        before_resupply=site.stopped_hits,shots=site.ticks,energy=site.gun.energy,damage_types=site.damage_types,ammo=site.ammo}
    end
    t.done=true;helpers.write_file('bunker-family/result.json',helpers.table_to_json(result),false)
    log('[BUNKER-FAMILY] PASS '..helpers.table_to_json(result))
    game.auto_save('bunker-family-verified')
  end
end)
