local arsenal=require('__tech-priests-unit-arsenal__.prototypes.unit_arsenal')
local PREFIX='tech-priests-arsenal-'
local function remaining(stack)
 if not stack.valid_for_read then return 0 end
 return (stack.count-1)*stack.prototype.magazine_size+stack.ammo
end
script.on_init(function()
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
 storage.arsenal={sites={},hits={},report={engine=script.active_mods.base,players={},mounted={},unlocks={},effects_seen={}}}
 helpers.write_file('unit-arsenal/balance-contract.json',helpers.table_to_json{weapons=arsenal.weapons,
  supplies=arsenal.supplies,profiles=arsenal.profiles,research=arsenal.research},false)
 local force=game.forces.player
 for _,row in ipairs(arsenal.weapons) do
  local weapon=force.recipes[PREFIX..row[1]];local unit=force.recipes['tech-priests-combat-'..row[2]]
  local before=weapon.enabled==unit.enabled
  if row[7]>0 then force.technologies['tp-unit-unlock-'..row[2]].researched=true end
  local ok=before and weapon.enabled and unit.enabled and force.recipes[PREFIX..row[3]].enabled
  storage.arsenal.report.unlocks[#storage.arsenal.report.unlocks+1]={weapon=row[1],passed=ok}
  assert(ok,'Unit/weapon unlock mismatch '..row[1])
 end
 for index,row in ipairs(arsenal.weapons) do
  local y=index*80;local range=row[5];local distance=range<2 and 1.1 or 8
  surface.request_to_generate_chunks({10,y},1);surface.force_generate_chunk_requests()
  for _,obstacle in pairs(surface.find_entities_filtered{area={{-5,y-8},{150,y+8}},type={'tree','cliff','simple-entity','resource'}}) do obstacle.destroy() end
  local player=surface.create_entity{name='character',position={0,y},force='player'}
  assert(player);player.destructible=false
  local target=surface.create_entity{name='tp-arsenal-target',position={distance,y},force='enemy'}
  player.get_inventory(defines.inventory.character_guns)[1].set_stack{name=PREFIX..row[1],count=1}
  player.get_inventory(defines.inventory.character_ammo)[1].set_stack{name=PREFIX..row[3],count=20}
  player.selected=target
  player.shooting_state={state=defines.shooting.shooting_selected,position=target.position}
  local turret=surface.create_entity{name='tp-arsenal-test-'..row[1],position={100,y},force='player'}
  local enemy=surface.create_entity{name='tp-arsenal-target',position={100+distance,y},force='enemy'}
  turret.insert{name=PREFIX..row[3],count=20}
  storage.arsenal.sites[index]={player=player,target=target,turret=turret,enemy=enemy,row=row,
   intervals={player={},mounted={}},last_shot={},last_remaining={},
   player_initial=remaining(player.get_inventory(defines.inventory.character_ammo)[1]),
   mounted_initial=remaining(turret.get_inventory(defines.inventory.turret_ammo)[1]),initial_health=target.health,mounted_health=enemy.health}
  if arsenal.supplies[row[3]].splash then
   local site=storage.arsenal.sites[index]
   site.neighbor=surface.create_entity{name='tp-arsenal-target',position={101+distance,y},force='enemy'}
   site.friendly=surface.create_entity{name='tp-arsenal-target',position={100+distance,y+1},force='player'}
  end
  local site=storage.arsenal.sites[index]
  local maker=surface.create_entity{name='character',position={-20,y},force='player'};maker.destructible=false
  local supply=arsenal.supplies[row[3]]
  for _,cost in ipairs(arsenal.profiles[row[1]].cost) do assert(maker.insert{name=cost[1],count=cost[2]}==cost[2]) end
  for _,cost in ipairs(supply.inputs) do assert(maker.insert{name=cost[1],count=cost[2]}==cost[2]) end
  assert(maker.begin_crafting{count=1,recipe=PREFIX..row[1],silent=true}==1)
  assert(maker.begin_crafting{count=1,recipe=PREFIX..row[3],silent=true}==1)
  site.maker=maker
 end
end)
script.on_event(defines.events.on_tick,function(event)
 local s=storage.arsenal;if not s then return end
 if event.tick<360 then
  for _,entity in pairs(game.surfaces[1].find_entities_filtered{type={'beam','projectile','sticker'}}) do
   if entity.name:find('tech%-priests%-arsenal%-') then s.report.effects_seen[entity.name]=true end
  end
  for _,site in ipairs(s.sites) do
   if not site.screenshot then
    local pos=site.player.position
    local visible=#game.surfaces[1].find_entities_filtered{area={{pos.x-1,pos.y-2},{pos.x+8,pos.y+2}},type={'beam','projectile'}}>0
    if visible or (site.row[5]<2 and site.target.health<site.initial_health) then
     game.take_screenshot{surface=game.surfaces[1],position={4,pos.y},resolution={768,320},zoom=2,
      path='unit-arsenal/effects/'..site.row[1]..'.png',show_gui=false,daytime=0,force_render=true,hide_health_bars=true}
     site.screenshot=true
    end
   end
  end
 end
 if event.tick<361 then
  for _,site in ipairs(s.sites) do
   local current={player=remaining(site.player.get_inventory(defines.inventory.character_ammo)[1]),
    mounted=remaining(site.turret.get_inventory(defines.inventory.turret_ammo)[1])}
   for kind,value in pairs(current) do
    if site.last_remaining[kind] and value<site.last_remaining[kind] then
     if site.last_shot[kind] then table.insert(site.intervals[kind],event.tick-site.last_shot[kind]) end
     site.last_shot[kind]=event.tick
    end
    site.last_remaining[kind]=value
   end
   site.player.selected=site.target
   site.player.shooting_state={state=defines.shooting.shooting_selected,position=site.target.position}
  end
 end
 if event.tick==360 then
  for _,site in ipairs(s.sites) do
   site.player.shooting_state={state=defines.shooting.not_shooting,position=site.target.position}
   site.mounted_remaining=remaining(site.turret.get_inventory(defines.inventory.turret_ammo)[1])
   site.turret.get_inventory(defines.inventory.turret_ammo).clear()
  end
 end
 if event.tick==420 then
  for _,site in ipairs(s.sites) do
   site.player.shooting_state={state=defines.shooting.not_shooting,position=site.target.position}
   local id=site.row[1]
   local player_used=site.player_initial-remaining(site.player.get_inventory(defines.inventory.character_ammo)[1])
   local mounted_used=site.mounted_initial-site.mounted_remaining
   local player_damage=site.initial_health-site.target.health
   local mounted_damage=site.mounted_health-site.enemy.health
   local supply=arsenal.supplies[site.row[3]];local per_shot=0
   for _,d in ipairs(supply.damage) do per_shot=per_shot+d[1] end
   if supply.splash then for _,d in ipairs(supply.splash.damage) do per_shot=per_shot+d[1] end end
   per_shot=per_shot*site.row[6]
   local function result(used,actual,kind)
    local cadence=#site.intervals[kind]>0
    for _,interval in ipairs(site.intervals[kind]) do if math.abs(interval-site.row[4])>1 then cadence=false end end
    return {weapon=id,ammo_used=used,damage=actual,expected_damage=used*per_shot,cadence_passed=cadence,
     shot_intervals=site.intervals[kind],passed=used>0 and cadence and math.abs(actual-used*per_shot)<.1}
   end
   s.report.players[#s.report.players+1]=result(player_used,player_damage,'player')
   s.report.mounted[#s.report.mounted+1]=result(mounted_used,mounted_damage,'mounted')
   if site.neighbor then
    local splash=0;for _,d in ipairs(supply.splash.damage) do splash=splash+d[1] end
    local actual=site.initial_health-site.neighbor.health
    local ok=math.abs(actual-mounted_used*splash*site.row[6])<.1 and site.friendly.health==site.initial_health
    s.report.area=s.report.area or {};s.report.area[#s.report.area+1]={weapon=id,secondary_damage=actual,
     expected=mounted_used*splash*site.row[6],friendly_damage=site.initial_health-site.friendly.health,passed=ok}
   end
   -- The same gun item is a native crafting ingredient, including axe and staff.
   site.player.get_inventory(defines.inventory.character_guns).clear()
   local main=site.player.get_inventory(defines.inventory.character_main)
   assert(main.insert{name=PREFIX..id,count=1}==1);assert(main.insert{name='iron-plate',count=1}==1)
   helpers.write_file('unit-arsenal/firing-checkpoint.json',helpers.table_to_json(s.report),false)
   local crafted=site.player.begin_crafting{count=1,recipe='tech-priests-combat-'..site.row[2],silent=true}
   assert(crafted==1,'Component crafting failed '..id)
  end
 end
 if event.tick==600 then
  s.report.component_crafts={};s.report.passed=true
  for _,site in ipairs(s.sites) do
   local item='tp-arsenal-test-unit-'..site.row[2]
   local count=site.player.get_item_count(item)
   s.report.component_crafts[#s.report.component_crafts+1]={weapon=site.row[1],result=item,count=count,passed=count==1}
   if count~=1 then s.report.passed=false end
  end
  for _,row in ipairs(s.report.players) do if not row.passed then s.report.passed=false end end
  for _,row in ipairs(s.report.mounted) do if not row.passed then s.report.passed=false end end
  for _,row in ipairs(s.report.area or {}) do if not row.passed then s.report.passed=false end end
  s.report.melee_range={}
  for _,site in ipairs(s.sites) do
   do
    site.enemy.teleport({100+site.row[5]+3,site.turret.position.y})
    if site.neighbor then site.neighbor.teleport({102+site.row[5]+3,site.turret.position.y}) end
    site.turret.insert{name=PREFIX..site.row[3],count=2}
    site.range_ammo=remaining(site.turret.get_inventory(defines.inventory.turret_ammo)[1])
   end
  end
 end
 if event.tick==720 then
  game.set_wait_for_screenshots_to_finish()
  for _,site in ipairs(s.sites) do
   do
    local used=site.range_ammo-remaining(site.turret.get_inventory(defines.inventory.turret_ammo)[1])
    s.report.melee_range[#s.report.melee_range+1]={weapon=site.row[1],range=site.row[5],out_of_range_ammo_used=used,passed=used==0}
    if used~=0 then s.report.passed=false end
   end
  end
  helpers.write_file('unit-arsenal/native-behavior.json',helpers.table_to_json(s.report),false)
  log('UNIT_ARSENAL_NATIVE '..tostring(s.report.passed))
 end
 -- Separate long-duration native effect preview; firing/consumption tests above stay unaltered.
 if event.tick==800 then
  for _,site in ipairs(s.sites) do
   local effect=arsenal.supplies[site.row[3]].effect
   if effect~='melee' then
    game.surfaces[1].create_entity{name=PREFIX..effect..'-beam',position=site.player.position,
     source=site.player,target=site.target,source_offset={0,-.5},duration=90}
   else
    game.surfaces[1].create_entity{name='small-explosion-hit',position=site.target.position}
   end
  end
 end
 if event.tick==801 then
  for _,site in ipairs(s.sites) do
   game.take_screenshot{surface=game.surfaces[1],position={3,site.player.position.y},resolution={768,320},zoom=2,
    path='unit-arsenal/effect-previews/'..site.row[1]..'.png',show_gui=false,daytime=0,force_render=true,hide_health_bars=true}
  end
  game.set_wait_for_screenshots_to_finish()
 end
 if event.tick==5000 then
  s.report.manufacturing={}
  for _,site in ipairs(s.sites) do
   local row=site.row;local supply=arsenal.supplies[row[3]]
   local weapons=site.maker.get_item_count(PREFIX..row[1]);local ammo=site.maker.get_item_count(PREFIX..row[3])
   local ok=weapons==1 and ammo==supply.batch
   s.report.manufacturing[#s.report.manufacturing+1]={weapon=row[1],weapon_output=weapons,supply=row[3],
    supply_output=ammo,expected_supply_output=supply.batch,passed=ok}
   if not ok then s.report.passed=false end
  end
  helpers.write_file('unit-arsenal/native-behavior.json',helpers.table_to_json(s.report),false)
 end
end)
