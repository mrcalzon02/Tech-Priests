local Registry=require("scripts.core.runtime_event_registry")
local C=require("shared.combat_roster_catalog")
local Bridge=require("scripts.core.combat_roster_bridge")
local function check(v,why) if not v then error("[TP-COMBAT-TEST] "..why) end end
local function getunit(r)
 local units=remote.call("aai-programmable-vehicles","get_units")
 return units[r.aai_id]
end
local function shots(entity)
 local inv=entity.get_inventory(defines.inventory.car_ammo);local n=0
 for i=1,#inv do local s=inv[i];if s.valid_for_read then n=n+(s.count-1)*s.prototype.magazine_size+s.ammo end end
 return n
end
local function init()
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then
  remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true)
 end
 local surface=game.create_surface("combat-roster-native",{width=1600,height=3000,water=0,autoplace_controls={}})
 surface.request_to_generate_chunks({120,550},20);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities()) do if e.valid then e.destroy() end end
 local tiles={};for x=-30,350 do for y=-30,1250 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end;surface.set_tiles(tiles)
 local hostile=game.create_force("combat-roster-hostile")
 hostile.set_friend("player",false);hostile.set_cease_fire("player",false)
 game.forces.player.set_friend(hostile,false);game.forces.player.set_cease_fire(hostile,false)
 local t={start=game.tick,rows={},phase=0};storage.combat_roster_test=t
 local cease=game.create_force("combat-roster-ceasefire")
 for side,force in ipairs({game.forces.player,hostile,game.forces.enemy}) do
  force.set_cease_fire(cease,true);cease.set_cease_fire(force,true)
  for i,u in ipairs(C.units) do
   local y=(i-1)*80;local x=(side-1)*120
   local car=surface.create_entity{name=u.name,position={x,y},force=force,raise_built=true}
   local aai=Bridge.unit(car);check(aai,"AAI manages "..u.id)
   local ammo=C.ammo[u.ammo_family]
   local inv=car.get_inventory(defines.inventory.car_ammo)
   for family,other in pairs(C.ammo) do
    check(inv.can_insert{name=other.name,count=1}==(family==u.ammo_family),"native gun admits only its own ammunition "..u.id.." / "..family)
   end
   local gun_count=0;for _ in pairs(car.prototype.guns) do gun_count=gun_count+1 end
   check(gun_count==1,"exactly one native gun")
   local target=surface.create_entity{name="tech-priests-combat-test-target",position={x+(u.melee and 12 or u.range-4),y},force=side==1 and hostile or game.forces.player}
   local friend=surface.create_entity{name="tech-priests-combat-test-target",position={x-2,y},force=force}
   local truce=surface.create_entity{name="tech-priests-combat-test-target",position={x-3,y+2},force=cease}
   check(Bridge.command(car,force,{position={x=target.position.x-.8,y=y}}),"unfuelled native move order accepted")
   t.rows[#t.rows+1]={id=u.id,aai_id=aai.unit_id,target=target,ammo=ammo.name,
    health=target.health,force=force.index,start={x=x,y=y},melee=u.melee,damage=0,damage_events=0,friend=friend,truce=truce}
  end
 end
 log("[TP-COMBAT-TEST] INIT 45 real actors; all 15 types on player, custom hostile and native enemy forces")
end
local function tick(event)
 local t=storage.combat_roster_test;if not t then return end
 if TP_COMBAT_VISUALS and game.speed~=8 then game.speed=8 end
 local function capture(state)
  for _,r in ipairs(t.rows) do if r.force==game.forces.player.index then
   local actor=getunit(r).vehicle
   game.take_screenshot{surface=actor.surface,position={x=actor.position.x,y=actor.position.y-.65},resolution={256,256},zoom=2,
    path="combat-roster/visual/"..r.id.."-"..state..".png",show_gui=false,force_render=true,daytime=0}
  end end
 end
 if t.done then
  if TP_COMBAT_VISUALS and not t.visual_done then
   if not t.visual_death_tick then
    t.visual_death_tick=game.tick
    for _,r in ipairs(t.rows) do if r.force==game.forces.player.index then
     local actor=getunit(r).vehicle;r.death_position=actor.position;r.death_surface=actor.surface
     check(actor.die(game.forces.enemy),"native combatant death "..r.id)
    end end
   elseif game.tick-t.visual_death_tick>=10 then
    for _,r in ipairs(t.rows) do if r.death_position then
     local found=false
     for _,rec in pairs(storage.tech_priests.character_visuals.actors) do
      if rec.dead and rec.model==r.id and rec.entity.valid and rec.entity.surface==r.death_surface then
       local mask=rendering.get_object_by_id(rec.renders.mask)
       check(mask and mask.valid and rec.state=="death","native masked corpse animation "..r.id);found=true
      end
     end
     check(found,"combatant corpse presentation exists "..r.id)
     game.take_screenshot{surface=r.death_surface,position={x=r.death_position.x,y=r.death_position.y-.65},resolution={256,256},zoom=2,
      path="combat-roster/visual/"..r.id.."-death.png",show_gui=false,force_render=true,daytime=0}
    end end
    t.visual_done=true;log("[TP-COMBAT-TEST] VISUAL_PASS 15 idle/walk/attack/death captures and 45 native force masks")
    game.auto_save("combat-roster-visual")
   end
  end
  return
 end
 local elapsed=game.tick-t.start
 if TP_COMBAT_VISUALS and not t.idle_capture and elapsed>=60 then t.idle_capture=true;capture("idle") end
 if TP_COMBAT_VISUALS and not t.attack_capture and elapsed>=600 then
  t.attack_capture=true;capture("attack")
  for _,r in ipairs(t.rows) do
   local actor=getunit(r).vehicle
   local rec=storage.tech_priests.character_visuals.actors[actor.unit_number]
   check(rec and rec.model==r.id,"combat presentation uses correct model")
   check(rec.renders.mask,"new AAI body receives its presentation immediately "..r.id)
   local mask=rendering.get_object_by_id(rec.renders.mask)
   check(mask and mask.valid,"native force mask exists "..r.id)
   local tint=mask.color;local force=actor.force.color
   check(math.abs(tint.r-force.r)<.001 and math.abs(tint.g-force.g)<.001 and math.abs(tint.b-force.b)<.001,"native unit mask uses its actual force colour")
  end
 end
 if TP_COMBAT_VISUALS and not t.walk_capture and elapsed>=3200 then t.walk_capture=true;capture("walk") end
 if t.phase==0 and elapsed>=120 then
  t.phase=-1 -- fail once if a native interface refuses the handoff
  for _,r in ipairs(t.rows) do
   check(r.target.health==r.health,"unarmed actor cannot damage "..r.id)
   local unit=getunit(r);check(unit and unit.vehicle.valid,"managed body")
   local pos=unit.vehicle.position
   check((pos.x-r.start.x)^2+(pos.y-r.start.y)^2<.1,"no movement without physical field supplies "..r.id)
   check(unit.vehicle.get_fuel_inventory().insert{name="tech-priests-field-supply-pack",count=10}==10,"physical movement supplies inserted")
   check(unit.vehicle.get_inventory(defines.inventory.car_ammo).insert{name=r.ammo,count=2}==2,"real ammo supplied")
   r.initial_shots=shots(unit.vehicle)
   local p=r.target.position
   check(Bridge.command(unit.vehicle,game.forces[r.force],{position={x=p.x-.8,y=p.y}}),"player/commander AAI order accepted")
  end
  t.phase=1
 elseif t.phase==1 and elapsed>=3000 then
  t.phase=2 -- fail once; isolated registry errors must not flood every tick
  local results={}
  for _,r in ipairs(t.rows) do
   local unit=getunit(r);check(unit and unit.vehicle.valid,"combatant survives "..r.id)
   local remaining=shots(unit.vehicle)
   local nearest=unit.vehicle.surface.find_nearest_enemy{position=unit.vehicle.position,max_distance=40,force=unit.vehicle.force}
   log("[TP-COMBAT-TEST] STATE "..r.id.." "..helpers.table_to_json{driver=unit.driver and unit.driver.valid,
    shooting=unit.driver and unit.driver.shooting_state.state,active=unit.active_state,seated=unit.vehicle.get_driver()~=nil,
    target=unit.attack_target and unit.attack_target.valid and unit.attack_target.name,
    nearest=nearest and nearest.name,target_military=r.target.is_military_target,
    fuel=unit.vehicle.burner.remaining_burning_fuel,shots=remaining,health=r.target.health})
   check(r.target.health<r.health,"actual native damage "..r.id.." force="..r.force.." pos="..serpent.line(unit.vehicle.position).." mode="..tostring(unit.mode).." shots="..remaining)
   check(remaining<r.initial_shots,"actual ammo consumed "..r.id)
   check(remaining==0,"finite physical magazines exhaust "..r.id)
   check(r.damage_events==r.initial_shots-remaining,"exactly one native hit per spent shot "..r.id
    .." hits="..r.damage_events.." spent="..(r.initial_shots-remaining))
   if r.melee then check(r.closest_hit and r.closest_hit<=2.6,"axe/staff native contact") end
   results[#results+1]={id=r.id,force=r.force,shots_consumed=r.initial_shots-remaining,damage=r.health-r.target.health,
    native_damage_events=r.damage_events,closest_melee_hit=r.closest_hit,aai_id=r.aai_id}
   Bridge.command(unit.vehicle,game.forces[r.force],{stop=true})
   local stopped=getunit(r).vehicle -- a native mode command may replace the body synchronously
   r.stop_position={x=stopped.position.x,y=stopped.position.y};r.after_fire_health=r.target.health
  end
  t.results=results
 elseif t.phase==2 and elapsed>=3120 then
  t.phase=3
  for _,r in ipairs(t.rows) do
   local unit=getunit(r);local p=unit.vehicle.position;local q=r.stop_position
   check((p.x-q.x)^2+(p.y-q.y)^2<.5,"native stop holds position "..r.id)
   check(Bridge.command(unit.vehicle,game.forces[r.force],{position={x=r.start.x+8,y=r.start.y+8}}),"native resume accepted")
  end
 elseif t.phase==3 and elapsed>=3450 then
  t.phase=4
  for _,r in ipairs(t.rows) do
   local unit=getunit(r);local p=unit.vehicle.position;local q=r.stop_position
   check((p.x-q.x)^2+(p.y-q.y)^2>1,"native movement resumes "..r.id)
   check(r.target.health==r.after_fire_health and shots(unit.vehicle)==0,"out of ammo means no further damage "..r.id)
   check(r.friend.health==r.health and r.truce.health==r.health,"friendly and ceasefire forces are not attacked")
   local energy=unit.vehicle.get_fuel_inventory().get_item_count("tech-priests-field-supply-pack")*2000000+unit.vehicle.burner.remaining_burning_fuel
   check(energy>0 and energy<20000000,"native movement spends finite fuel energy "..r.id)
  end
  helpers.write_file("combat-roster/battle.json",helpers.table_to_json{passed=true,units=45,types=15,forces=3,mods=script.active_mods,
   checks={"single weapon","ammo compatibility","unarmed refusal","one hit per spent shot","native melee contact",
    "finite ammunition exhaustion","no empty-ammo damage","no movement without supplies","finite native movement fuel",
    "same-destination reissue after refuelling","stop","resume","same-force safety","ceasefire safety"},results=t.results},false)
  log("[TP-COMBAT-TEST] PASS 45 actors; exact ammo/damage, melee contact, exhaustion, stop/resume and force safety")
  t.done=true
 end
end
local function damaged(event)
 local t=storage.combat_roster_test;if not t then return end
 for _,r in ipairs(t.rows) do
  if r.target==event.entity then
   r.damage_events=r.damage_events+1
   if r.melee and event.cause and event.cause.valid then
    local a,b=event.cause.position,r.target.position
    r.closest_hit=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
   end
  end
 end
end
Registry.on_init(init,{owner="combat-roster-test",route="setup",priority=2000})
Registry.on_event(defines.events.on_tick,function(event)
 local ok,err=xpcall(function() tick(event) end,function(why) return debug.traceback(tostring(why),2) end)
 if not ok then error(err) end
end,nil,{owner="combat-roster-test",route="assertions",priority=2000})
Registry.on_event(defines.events.on_entity_damaged,damaged,nil,{owner="combat-roster-test",route="receipts",priority=2000})
