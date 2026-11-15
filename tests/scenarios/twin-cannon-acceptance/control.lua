local integration=require('scripts.bunker_cannon_integration')
local cannon=require('scripts.twin_cannon_controller')
local bullet=require('scripts.bullet_turret_controller')
integration.install()
local session_checked=false
local function check(ok,message)assert(ok,'[CANNON-ACCEPTANCE] '..message)end
local function screenshot(name,position,zoom)
  if GRAPHICAL then game.take_screenshot{surface=storage.cannon_acceptance.surface,position=position,resolution={1000,800},zoom=zoom or 2,
    path='twin-cannon-acceptance/'..name..'.png',show_gui=false} end
end
script.on_init(function()
  local s=game.create_surface('twin-cannon-acceptance',{default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  s.always_day=true
  storage.cannon_acceptance={surface=s,sites={},legacy={},damage={},headings={},poses={},aerial_peak=0}
  local r=storage.cannon_acceptance
  local function tile(p)
    s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
    local tiles={};for x=math.floor(p.x)-7,math.floor(p.x)+7 do for y=math.floor(p.y)-7,math.floor(p.y)+7 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end;s.set_tiles(tiles)
  end
  local ammo={'cannon-shell','explosive-cannon-shell','uranium-cannon-shell','explosive-uranium-cannon-shell'}
  local offsets={{0,-24},{17,-17},{24,0},{17,17},{0,24},{-17,17},{-24,0},{-17,-17}}
  for tier,round in ipairs(ammo) do for heading,offset in ipairs(offsets) do
    local p={x=(heading-1)*80+.5,y=(tier-1)*80+.5};tile(p)
    local gun=s.create_entity{name='tech-priests-bunker-twin-cannon',position=p,force='player'}
    local target=s.create_entity{name='tp-cannon-acceptance-target',position={p.x+offset[1],p.y+offset[2]},force='enemy'};target.disabled_by_script=true
    check(gun.insert{name=round,count=100}==100,'native shell supply')
    local site={gun=gun,target=target,ammo=round,tier=tier,heading=heading,launches={},damage={}}
    r.sites[#r.sites+1]=site;r.damage[target.unit_number]=site
  end end
  local legacy={{'autocannon','tech-priests-autocannon-magazine',50},{'lobber','tech-priests-lobber-grenade-magazine',10},
    {'energy-dish',nil,0},{'chicago-piano','firearm-magazine',100},{'twin-minigun','firearm-magazine',100}}
  for i,config in ipairs(legacy) do
    local p={x=720.5,y=(i-1)*80+.5};tile(p)
    local gun=s.create_entity{name='tech-priests-bunker-'..config[1],position=p,force='player'}
    local target=s.create_entity{name='tp-cannon-acceptance-target',position={p.x,p.y-14},force='enemy'};target.disabled_by_script=true
    if config[2] then check(gun.insert{name=config[2],count=config[3]}==config[3],'legacy ammo '..config[1]) end
    r.legacy[#r.legacy+1]={name=config[1],gun=gun,target=target,ammo=config[2],initial=config[3]}
  end
  tile({x=800.5,y=.5});r.spinner=s.create_entity{name='tech-priests-bunker-twin-cannon',position={800.5,.5},force='player'}
  integration.init()
  if GRAPHICAL then game.speed=3 end
end)
-- Preserve the shipping damage owner, then observe the engine's damage.
script.on_event(defines.events.on_entity_damaged,function(e)
  bullet.hit(e)
  local site=storage.cannon_acceptance.damage[e.entity.unit_number]
  if site then site.damage[#site.damage+1]={tick=game.tick,amount=e.final_damage_amount,type=e.damage_type.name} end
end)
script.on_event(defines.events.on_tick,function(e)
  integration.tick(e);local r=storage.cannon_acceptance
  if not session_checked then
    session_checked=true
    if r.last_tick then
      local shots=0;for _,site in ipairs(r.sites) do shots=shots+#site.launches end
      r.resume={saved_tick=r.last_tick,resume_tick=e.tick,saved_shots=shots}
    end
  end
  r.last_tick=e.tick
  for _,site in ipairs(r.sites) do
    local entry=storage.twin_cannon.guns[site.gun.unit_number]
    check(entry and entry.visual,'live controller')
    for _,pass in ipairs({'body','shadow','aerial1','aerial2'}) do check(entry.objects[pass] and entry.objects[pass].valid,'real '..pass..' art') end
    r.poses[entry.visual.mode]=true
    if entry.shots>#site.launches then
      local launch=entry.last_launch;check(launch and launch.tick==entry.last_shot and launch.moved,'original native projectile')
      local previous=site.launches[#site.launches]
      if previous then
        check(previous.bank~=launch.bank,'strict alternating banks')
        -- A map-creation tick-zero shot has a one-tick startup phase. Require
        -- the exact 45-tick steady cadence after that initial launch.
        if launch.tick<600 and previous.tick>0 then check(launch.tick-previous.tick==45,'default 45-tick cadence '..helpers.table_to_json({gap=launch.tick-previous.tick,ammo=site.ammo,heading=site.heading,tick=launch.tick,previous=previous.tick,cooldown=site.gun.prototype.attack_parameters.cooldown,speed=site.gun.force.get_gun_speed_modifier('cannon-shell')})) end
      end
      site.launches[#site.launches+1]={tick=launch.tick,bank=launch.bank,projectile=launch.projectile}
    end
  end
  for _,site in ipairs(r.legacy) do if site.name=='energy-dish' then site.gun.energy=100000000 end end
  local spin=storage.twin_cannon.guns[r.spinner.unit_number]
  if e.tick>=1200 and e.tick<1584 then r.spinner.orientation=((e.tick-1200)/384)%1
  elseif e.tick==1584 then r.spinner.orientation=0 end
  if e.tick>=1200 then
    r.headings[spin.visual.heading]=true
    for _,aerial in ipairs(spin.aerials) do r.aerial_peak=math.max(r.aerial_peak,math.sqrt(aerial.x*aerial.x+aerial.y*aerial.y)) end
  end
  if e.tick==500 then game.auto_save('twin-cannon-acceptance-mid-fire') end
  if e.tick==600 then
    game.forces.player.set_ammo_damage_modifier('cannon-shell',.5)
    game.forces.player.set_gun_speed_modifier('cannon-shell',.5)
  end
  if e.tick==300 then
    for i=1,8 do screenshot('facing-'..i,r.sites[i].gun.position,3) end
  elseif e.tick==1100 then
    for _,site in ipairs(r.sites) do
      local entry=storage.twin_cannon.guns[site.gun.unit_number]
      check(entry.native_gap>=29 and entry.native_gap<=31,'native shooting research cadence')
      check(site.gun.get_item_count(site.ammo)==100-#site.launches,'one native shell per shot')
      site.gun.get_inventory(defines.inventory.turret_ammo).clear()
    end
  elseif e.tick==1200 then
    for _,site in ipairs(r.sites) do check(storage.twin_cannon.guns[site.gun.unit_number].visual.mode=='idle','empty gun settles fully') end
  elseif e.tick==1300 or e.tick==1450 then screenshot('unarmed-turn-'..e.tick,r.spinner.position,4)
  elseif e.tick==1800 then
    local report={status='PASS',graphical=GRAPHICAL,scope='Shipping integration, full actual art, 32 cannon sites and five older weapons',sites={},legacy={},headings={},aerial_peak=r.aerial_peak,resume=r.resume}
    local count=0;for d in pairs(r.headings) do count=count+1;report.headings[#report.headings+1]=d end
    table.sort(report.headings);check(count==64,'all 64 real sprite headings loaded during turn')
    check(r.aerial_peak>.01,'unarmed turning bends aerials')
    for _,a in ipairs(spin.aerials) do check(math.abs(a.x)<.003 and math.abs(a.y)<.003,'aerials settle after rotation') end
    for _,mode in ipairs({'idle','single0','single1','overlap0','overlap1'}) do check(r.poses[mode],'all mechanism states exercised') end
    for _,site in ipairs(r.sites) do
      check(#site.launches>20 and #site.damage>20,'native firing and damage '..site.ammo)
      if site.ammo=='cannon-shell' then
        local before,after=false,false
        for _,hit in ipairs(site.damage) do
          if hit.type=='physical' and hit.tick<590 and math.abs(hit.amount-1000)<.01 then before=true end
          if hit.type=='physical' and hit.tick>650 and math.abs(hit.amount-1500)<.01 then after=true end
        end
        check(before and after,'native damage research reaches original projectile')
      end
      report.sites[#report.sites+1]={ammo=site.ammo,heading=site.heading,shots=#site.launches,health=site.target.health,launches=site.launches}
    end
    for _,site in ipairs(r.legacy) do
      check(site.target.health<10000000,'older weapon still fires '..site.name)
      if site.ammo then check(site.gun.get_item_count(site.ammo)<site.initial,'older ammo consumption '..site.name) end
      if site.name=='chicago-piano' or site.name=='twin-minigun' then check(storage.bullet_turrets[site.gun.unit_number].pulses>10,'shared bullet callback '..site.name) end
      if site.name=='lobber' then check(storage.bunker_cap_visuals[site.gun.unit_number].shots>10,'shared lobber callback') end
      report.legacy[#report.legacy+1]={name=site.name,health=site.target.health}
    end
    check(next(storage.twin_cannon.pending)==nil,'all launch callbacks paired')
    helpers.write_file('twin-cannon-acceptance/'..(GRAPHICAL and 'result-graphical.json' or 'result.json'),helpers.table_to_json(report),false)
    screenshot('settled-cannon',r.sites[1].gun.position,4)
    if GRAPHICAL then game.tick_paused=true end
  end
end)
