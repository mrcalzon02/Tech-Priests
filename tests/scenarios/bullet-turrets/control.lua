local visual=require('scripts.bunker_family_visuals');visual.install()
local bullets=require('scripts.bullet_turret_controller')
local function check(ok,message) assert(ok,'[BULLET-TURRETS] '..message) end
script.on_init(function()
  visual.init();game.speed=3
  storage.bullet_proof={sites={},targets={},done=false,muzzle_effects={}}
  local s=game.create_surface('bullet-turret-proof',{water=0,starting_area=0,default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  s.always_day=true;s.peaceful_mode=true
  local offsets={{0,-16},{11.31,-11.31},{16,0},{11.31,11.31},{0,16},{-11.31,11.31},{-16,0},{-11.31,-11.31}}
  local names={'tech-priests-bunker-chicago-piano','tech-priests-bunker-twin-minigun','gun-turret'}
  for family,name in ipairs(names) do
    if family<3 then game.forces.player.technologies[name].researched=true;check(game.forces.player.recipes[name].enabled,'research '..name) end
    for heading,off in ipairs(offsets) do
      local p={x=(heading-1)*80+.5,y=(family-1)*80+.5}
      s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
      local tiles={};for x=p.x-25.5,p.x+25.5 do for y=p.y-25.5,p.y+25.5 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end;s.set_tiles(tiles)
      local gun=s.create_entity{name=name,position=p,force='player',direction=defines.direction.north};check(gun and gun.valid,'placement')
      visual.add(gun)
      local target=s.create_entity{name='tp-bullet-proof-target',position={p.x+off[1],p.y+off[2]},force='enemy'};target.disabled_by_script=true
      local site={gun=gun,target=target,heading=heading,family=family,ticks={},damage={},hits=0}
      storage.bullet_proof.sites[#storage.bullet_proof.sites+1]=site;storage.bullet_proof.targets[target.unit_number]=site
    end
  end
end)
script.on_event(defines.events.on_trigger_created_entity,function(e)
  local flash=e.entity;local source=e.source
  local gunshot=flash and flash.valid and flash.name=='explosion-gunshot'
  local name=source and source.valid and source.name
  local removed=bullets.muzzle_created(e)
  if gunshot and name then
    local custom=name=='tech-priests-bunker-chicago-piano' or name=='tech-priests-bunker-twin-minigun'
    check(custom and removed and not flash.valid or not custom and not removed and flash.valid,'source-scoped muzzle suppression '..name)
    local t=storage.bullet_proof;t.muzzle_effects[name]=(t.muzzle_effects[name] or 0)+1
  end
end)
script.on_event(defines.events.on_entity_damaged,function(e)
  bullets.hit(e)
  local t=storage.bullet_proof;if not t then return end
  local site=t.targets[e.entity.unit_number]
  if site then site.ticks[#site.ticks+1]=e.tick;site.damage[#site.damage+1]=e.final_damage_amount;site.hits=site.hits+1 end
end)
script.on_event(defines.events.on_player_created,function(e)
  local p=game.get_player(e.player_index);local site=storage.bullet_proof.sites[13];p.teleport({site.gun.position.x-4,site.gun.position.y+1},site.gun.surface);p.zoom=1.8
  local panel=p.gui.left.add{type='frame',name='bullet_native_preview_proof',direction='vertical',caption='Native turret previews'}
  for _,index in ipairs({5,13}) do
    local gun=storage.bullet_proof.sites[index].gun
    panel.add{type='label',caption=gun.localised_name}
    local preview=panel.add{type='entity-preview'};preview.entity=gun
    preview.style.width=240;preview.style.height=200
  end
end)
local function screenshot(site,label)
  game.take_screenshot{surface=site.gun.surface,position={site.gun.position.x,site.gun.position.y-.8},
    resolution={960,720},zoom=2,show_gui=false,force_render=true,path='bullet-turrets/'..label..'.png'}
end
script.on_event(defines.events.on_tick,function(e)
  visual.tick(e)
  local t=storage.bullet_proof;if not t then return end
  if e.tick==120 then
    for _,site in ipairs(t.sites) do
      check(site.hits==0,'no firing while empty')
      check(site.gun.insert{name='firearm-magazine',count=50}==50,'ordinary firearm magazines')
    end
  elseif e.tick>=600 and e.tick<=670 then
    for _,site in ipairs(t.sites) do
      if site.heading==5 then screenshot(site,'weapon-'..site.family..'-tick-'..e.tick)
      elseif e.tick==600 and site.family<3 then screenshot(site,'weapon-'..site.family..'-heading-'..site.heading) end
    end
  elseif e.tick==1600 then
    local report={status='PASS',engine=script.active_mods.base,sites={}}
    local stock=prototypes.entity['gun-turret'].attack_parameters
    for _,site in ipairs(t.sites) do
      check(site.hits>20,'damages target '..site.family..':'..site.heading)
      local steady={};for _,tick in ipairs(site.ticks) do if tick>400 and tick<1500 then steady[#steady+1]=tick end end
      local gaps={};for i=2,#steady do local gap=steady[i]-steady[i-1];gaps[gap]=(gaps[gap] or 0)+1 end
      if site.family==1 then
        for gap in pairs(gaps) do check(gap==6 or gap==30,'piano gap '..gap) end
        check(gaps[30] and gaps[6],'four shots then half-second recycle')
        for i=5,#steady do check(steady[i]-steady[i-4]==48,'piano four-shot cycle') end
      else for gap in pairs(gaps) do check(gap==stock.cooldown,'stock cadence '..site.family..':'..gap) end end
      local stack=site.gun.get_inventory(defines.inventory.turret_ammo)[1]
      local remaining=stack.valid_for_read and ((stack.count-1)*10+stack.ammo) or 0
      local spent=500-remaining
      check(spent==site.hits*(site.family==2 and 2 or 1),'physical round consumption '..site.family..': '..spent..' / '..site.hits)
      if site.family<3 then check(site.gun.direction==defines.direction.north,'base stayed fixed '..site.family..':'..site.heading) end
      report.sites[#report.sites+1]={name=site.gun.name,heading=site.heading,orientation=site.gun.orientation,hits=site.hits,rounds_spent=spent,gaps=gaps,damage=site.damage[1],ticks=site.ticks}
    end
    check(report.sites[9].damage==2*report.sites[17].damage,'twin paired damage exactly twice stock')
    for _,name in ipairs({'tech-priests-bunker-chicago-piano','tech-priests-bunker-twin-minigun','gun-turret'}) do
      check((t.muzzle_effects[name] or 0)>20,'native muzzle creation/suppression exercised '..name)
    end
    helpers.write_file('bullet-turrets/muzzle-effects.json',helpers.table_to_json{status='PASS',counts=t.muzzle_effects,custom_native_flashes_removed=true,stock_flashes_preserved=true},false)
    helpers.write_file('bullet-turrets/result.json',helpers.table_to_json(report),false);t.done=true
    for _,site in ipairs(t.sites) do site.gun.get_inventory(defines.inventory.turret_ammo).clear();site.stopped=site.hits end
    log('[BULLET-TURRETS] CADENCE_DAMAGE_AMMO_PASS')
  elseif e.tick==1800 then
    for _,site in ipairs(t.sites) do check(site.hits==site.stopped,'stops without ammo') end
    log('[BULLET-TURRETS] EMPTY_STOP_PASS')
    for _,name in ipairs({'physical-projectile-damage-1','physical-projectile-damage-2','weapon-shooting-speed-1','weapon-shooting-speed-2'}) do
      game.forces.player.technologies[name].researched=true
    end
    for _,site in ipairs(t.sites) do
      site.upgraded_start=#site.ticks+1
      check(site.gun.insert{name='firearm-magazine',count=50}==50,'resupply for upgrade proof')
    end
  elseif e.tick==3000 then
    local report={status='PASS',phase='damage and speed upgrades',sites={}}
    local stock_gap;local stock_gaps={}
    for _,site in ipairs(t.sites) do
      local ticks={}
      for i=site.upgraded_start,#site.ticks do if site.ticks[i]>2000 and site.ticks[i]<2900 then ticks[#ticks+1]=site.ticks[i] end end
      local gaps={};for i=2,#ticks do local gap=ticks[i]-ticks[i-1];gaps[gap]=(gaps[gap] or 0)+1 end
      if site.family==3 then
        for gap,count in pairs(gaps) do stock_gap=math.max(stock_gap or 0,gap);stock_gaps[gap]=(stock_gaps[gap] or 0)+count end
      end
      report.sites[#report.sites+1]={family=site.family,heading=site.heading,gaps=gaps,
        damage=site.damage[site.upgraded_start],ticks=ticks}
    end
    check(stock_gap and stock_gap<6,'shooting speed upgrades exercised')
    log('[BULLET-TURRETS] UPGRADE_DIAGNOSTIC '..helpers.table_to_json(report))
    for _,site in ipairs(report.sites) do
      if site.family==1 then
        local sum,count=0,0;local burst=0;local seen_recycle=false
        for i=2,#site.ticks do
          local gap=site.ticks[i]-site.ticks[i-1]
          if gap>12 then
            check(gap>=29 and gap<=31,'upgraded recycle bounded to one native quantization tick')
            if seen_recycle then check(burst==3,'four upgraded shots between recycles') end
            seen_recycle=true;burst=0;sum=sum+gap;count=count+1
          else check(stock_gaps[gap],'piano uses upgraded stock interval');burst=burst+1 end
        end
        site.mean_recycle=sum/count
        check(math.abs(site.mean_recycle-30)<.15,'half-second average recycle after fractional speed research')
      else for gap in pairs(site.gaps) do check(stock_gaps[gap],'twin tracks upgraded stock cadence') end end
    end
    check(math.abs(report.sites[9].damage-2*report.sites[17].damage)<.0001,'twin tracks stock damage research')
    helpers.write_file('bullet-turrets/upgrades.json',helpers.table_to_json(report),false)
    log('[BULLET-TURRETS] RESEARCH_PASS')
    t.reload_baseline={}
    for i,site in ipairs(t.sites) do
      t.reload_baseline[i]=site.hits
      site.gun.get_inventory(defines.inventory.turret_ammo).clear()
      check(site.gun.insert{name='firearm-magazine',count=50}==50,'resupply for save/reload proof')
    end
    game.auto_save('bullet-turrets-verified')
  elseif e.tick==3300 then
    -- Also exercised after loading the tick-3000 autosave in a new process.
    for i,site in ipairs(t.sites) do
      check(site.hits>t.reload_baseline[i]+10,'continued firing after save/load '..i)
      if site.family<3 then
        local entry=storage.bullet_turrets[site.gun.unit_number]
        check(entry and entry.objects.body.valid and entry.objects.shadow.valid,'restored visual controller '..i)
      end
    end
    helpers.write_file('bullet-turrets/continued.json',helpers.table_to_json{status='PASS',tick=e.tick,sites=#t.sites},false)
    log('[BULLET-TURRETS] CONTINUED_FIRING_PASS')
    for _,index in ipairs({1,9}) do
      local site=t.sites[index];local p=site.gun.position;local s=site.gun.surface
      site.gun.get_inventory(defines.inventory.turret_ammo).clear();site.feed_start=site.hits
      site.feed_chest=s.create_entity{name='steel-chest',position={p.x,p.y+3},force='player'}
      site.feed_inserter=s.create_entity{name='burner-inserter',position={p.x,p.y+2},force='player',direction=defines.direction.south}
      check(site.feed_chest and site.feed_inserter,'inserter fixture placement')
      site.feed_inserter.get_fuel_inventory().insert{name='coal',count=50}
      check(site.feed_chest.insert{name='firearm-magazine',count=25}==25,'physical ammunition chest')
    end
  elseif e.tick==3900 then
    local report={status='PASS',sites={}}
    for _,index in ipairs({1,9}) do
      local site=t.sites[index]
      check(site.hits>site.feed_start+20,'inserter-fed firing '..site.family)
      check(site.feed_chest.get_item_count('firearm-magazine')<25,'inserter moved magazines '..site.family)
      report.sites[#report.sites+1]={name=site.gun.name,hits=site.hits-site.feed_start,chest_magazines=site.feed_chest.get_item_count('firearm-magazine')}
    end
    helpers.write_file('bullet-turrets/inserters.json',helpers.table_to_json(report),false)
    log('[BULLET-TURRETS] INSERTER_FEED_PASS')
  elseif e.tick==3950 then game.tick_paused=true
  end
end)
