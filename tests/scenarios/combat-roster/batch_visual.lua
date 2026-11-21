-- Test-only native GUI evidence: 30 genuine AAI actors, 14 native bunkers,
-- 48 naturally hostile biters, three-way player/renegade/enemy engagement.
-- NO synthetic damage, fired shots, research, wins, frames, or AAI steering.
-- The fixture injects initial vehicles/ammo/fuel; never credit recruitment.
local Registry=require("scripts.core.runtime_event_registry")
local C=require("shared.combat_roster_catalog")
local Bridge=require("scripts.core.combat_roster_bridge")
local MARK="[TP-COMBAT-BATCH] "
local AMMO={
 {"tech-priests-bunker-autocannon","tech-priests-autocannon-magazine"},
 {"tech-priests-bunker-chicago-piano","firearm-magazine"},
 {"tech-priests-bunker-twin-minigun","firearm-magazine"},
 {"tech-priests-bunker-twin-cannon","cannon-shell"},
 {"tech-priests-bunker-lobber","tech-priests-lobber-grenade-magazine"},
 {"tech-priests-bunker-rocket-salvo","rocket"},
 {"tech-priests-bunker-energy-dish",nil},
}
local CLIPS={
 {id="01-massed-units",start=80,stop=1000,step=20,x=0,y=0,zoom=.51},
 {id="02-bunker-lines",start=80,stop=1000,step=20,x=0,y=-17,zoom=.78},
 {id="03-enemy-flank",start=400,stop=1400,step=20,x=0,y=16,zoom=.78},
}
local function check(v,why) assert(v,MARK.."FAIL "..tostring(why)) end
local function enemies(a,b)
 a.set_friend(b,false);b.set_friend(a,false)
 a.set_cease_fire(b,false);b.set_cease_fire(a,false)
end
local function allied(a,b,friend)
 a.set_friend(b,friend);b.set_friend(a,friend)
 a.set_cease_fire(b,true);b.set_cease_fire(a,true)
end
local function init()
 local t={start=game.tick,actors={},turrets={},biters={},clips={},damage={
   player=0,renegade=0,enemy=0,protected=0},hits={player=0,renegade=0,enemy=0},
   sample_count=0,scenario="genuine-aai-native-batch",saved=false,ready=false}
 -- Do not publish half-built battle state. The event registry catches setup
 -- failures, but later ticks must never read an incomplete surface or roster.
 log(MARK.."SETUP_BEGIN")
 local s=game.create_surface("combat-batch-2_1-proof",{
   water=0,starting_area=0,default_enable_all_autoplace_controls=false,
   autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
 t.surface=s.index
 log(MARK.."SETUP_SURFACE_READY index="..tostring(t.surface))
 s.always_day=true;s.peaceful_mode=false
 s.request_to_generate_chunks({x=0,y=0},4);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-85,-60},{85,65}}}) do
   if e.valid and e.type~="character" then e.destroy() end
 end
 local tiles={}
 for x=-75,75 do for y=-48,50 do
   tiles[#tiles+1]={name="refined-concrete",position={x=x,y=y}}
 end end
 s.set_tiles(tiles)
 log(MARK.."SETUP_TERRAIN_READY")
 local player=game.forces.player
 local renegade=game.forces["tech-priests-renegades-nauvis"]
   or game.create_force("tech-priests-renegades-nauvis")
 local enemy=game.forces.enemy
 local friend=game.forces["tp-batch-allied"] or game.create_force("tp-batch-allied")
 local truce=game.forces["tp-batch-ceasefire"] or game.create_force("tp-batch-ceasefire")
 enemies(player,renegade);enemies(player,enemy);enemies(renegade,enemy)
 for _,force in ipairs({player,renegade,enemy}) do
   allied(force,friend,true);allied(force,truce,false)
 end
 local targets={
  {force=player,x=-46,y=-9,role="same-force"},
  {force=friend,x=-40,y=-9,role="allied"},
  {force=truce,x=-34,y=-9,role="ceasefire"},
 }
 for _,rec in ipairs(targets) do
   local e=s.create_entity{name="tech-priests-combat-test-target",
     position={x=rec.x,y=rec.y},force=rec.force}
   check(e and e.valid,"protected target cannot be created "..rec.role)
   e.disabled_by_script=true
   rec.entity=e;rec.health=e.health
 end
 t.protected=targets
 log(MARK.."SETUP_PROTECTED_TARGETS_READY count="..#targets)
 for side,force in ipairs({player,renegade}) do
   local y=side==1 and -23 or 23
   for i,def in ipairs(AMMO) do
     local x=(i-4)*11
     local gun=s.create_entity{name=def[1],position={x=x,y=y},force=force,
       direction=defines.direction.north,raise_built=true}
     check(gun and gun.valid,"native bunker absent "..def[1].." side="..side)
     local record={entity=gun,name=def[1],force=force.name,
       unit=gun.unit_number,ammo=def[2],initial=0}
     if def[2] then
       local count=gun.insert{name=def[2],count=80}
       check(count>0,"native bunker refused actual ammo "..def[1])
       record.initial=count
     else
       local power=s.create_entity{name="electric-energy-interface",
         position={x=x+3,y=y+(side==1 and -5 or 5)},force=force}
       local pole=s.create_entity{name="substation",
         position={x=x+3,y=y+(side==1 and -2 or 2)},force=force}
       check(power and pole,"energy dish physical electrical feed unavailable")
       power.power_production=1000000000
       power.electric_buffer_size=1000000000
       power.energy=1000000000
     end
     t.turrets[#t.turrets+1]=record
   end
   for i,u in ipairs(C.units) do
     local x=(i-8)*4.8
     local start={x=x,y=side==1 and -9 or 9}
     local car=s.create_entity{name=u.name,position=start,force=force,raise_built=true}
     check(car and car.valid,"native combatant missing "..u.id.." side="..side)
     local registered=Bridge.unit(car)
     check(registered and registered.unit_id,"native AAI unit not managed "..u.id)
     local ammo=C.ammo[u.ammo_family]
     check(ammo,"combatant has no canonical ammo family "..u.id)
     local count=car.get_inventory(defines.inventory.car_ammo).insert{
       name=ammo.name,count=8}
     local fuel=car.get_fuel_inventory().insert{
       name="tech-priests-field-supply-pack",count=12}
     check(count==8 and fuel==12,"native arm/fuel refused "..u.id)
     local goal={x=x*.68,y=side==1 and 12 or -12}
     local ok,why=Bridge.command(car,force,{position=goal})
     check(ok==true,"AAI native move command refused "..u.id.."/"..tostring(why))
     t.actors[#t.actors+1]={entity=car,id=u.id,unit=registered.unit_id,
       force=force.name,ammo=ammo.name,initial=count,spawn=start}
   end
 end
 log(MARK.."SETUP_ACTORS_AND_BUNKERS_READY actors="..#t.actors.." bunkers="..#t.turrets)
 for i=1,48 do
   local name=i%3==0 and "medium-biter" or "small-biter"
   local x=((i-1)%16-7.5)*4.2
   local y=34+math.floor((i-1)/16)*4
   local b=s.create_entity{name=name,position={x=x,y=y},force=enemy}
   check(b and b.valid,"native biter placement failed "..i)
   local ok=pcall(function() b.set_command{
     type=defines.command.attack_area,destination={x=x*.35,y=-14},
     radius=8,distraction=defines.distraction.by_enemy} end)
   check(ok,"native biter attack order unavailable "..i)
   t.biters[#t.biters+1]=b
 end
 t.expected={aai_actors=30,types=15,native_bunkers=14,
   native_biters=48,forces=3}
 check(#t.actors==30 and #t.turrets==14 and #t.biters==48,
   "native setup did not stage the expected physical actors/turrets/biters")
 check(t.surface and s.valid and game.surfaces[t.surface]==s,
   "native setup surface not retained")
 -- Publish atomically after all native placements and identities exist.
 t.ready=true
 storage.combat_batch_visual=t
 log(MARK.."INIT "..helpers.table_to_json(t.expected))
end

local function capture(t,elapsed)
 if TP_COMBAT_BATCH_VISUALS~=true then return end
 local s=game.surfaces[t.surface]
 for _,clip in ipairs(CLIPS)do
  if elapsed>=clip.start and elapsed<=clip.stop
     and (elapsed-clip.start)%clip.step==0 then
   local n=math.floor((elapsed-clip.start)/clip.step)
   local file=string.format("combat-roster/batch-native/%s/frame-%04d.png",
     clip.id,n)
   game.take_screenshot{surface=s,position={x=clip.x,y=clip.y},
     resolution={960,540},zoom=clip.zoom,path=file,
     show_gui=false,force_render=true,daytime=0}
   t.clips[clip.id]=t.clips[clip.id] or {}
   t.clips[clip.id][#t.clips[clip.id]+1]={frame=n,tick=game.tick}
  end
 end
end
local function snapshot(t)
 local alive_actor,alive_bunker,alive_biter=0,0,0
 local spent=0
 local force_counts={player=0,renegade=0}
 -- AAI may replace a car when entering/exiting a command mode. The old
 -- LuaEntity in the creation receipt then becomes invalid even though the
 -- SAME real AAI actor, physical ammo, force and driver still exist.
 -- Resolve current native managed bodies by the original immutable AAI ID.
 -- This is read-only: never spawn, teleport or move a combatant here.
 local registry_ok,managed=pcall(remote.call,
   "aai-programmable-vehicles","get_units")
 local aai_registry_available=registry_ok and type(managed)=="table"
 for _,rec in ipairs(t.actors)do
  local unit=aai_registry_available and managed[rec.unit] or nil
  local entity=unit and unit.vehicle or nil
  if entity and entity.valid and entity.type=="car"
    and entity.force and entity.force.name==rec.force then
   alive_actor=alive_actor+1
   if rec.force=="player"then force_counts.player=force_counts.player+1
   else force_counts.renegade=force_counts.renegade+1 end
  end
 end
 for _,rec in ipairs(t.turrets)do
  local e=rec.entity
  if e and e.valid then
   alive_bunker=alive_bunker+1
   if rec.ammo then
     local remaining=e.get_item_count(rec.ammo)
     spent=spent+math.max(0,rec.initial-remaining)
   end
  end
 end
 for _,b in ipairs(t.biters)do if b.valid then alive_biter=alive_biter+1 end end
 return {actors_alive=alive_actor,turrets_alive=alive_bunker,
   biters_alive=alive_biter,rounds_missing_from_surviving_turrets=spent,
   aai_registry_available=aai_registry_available,
   force_actors_alive=force_counts}
end
local function tick(event)
 local t=storage.combat_batch_visual
 if not (t and t.ready==true and type(t.surface)=="number") or t.done then return end
 local elapsed=game.tick-t.start
 capture(t,elapsed)
 if elapsed>0 and elapsed%300==0 then
  local status=snapshot(t)
  log(MARK.."SAMPLE elapsed="..elapsed.." "..helpers.table_to_json(status))
  t.sample_count=t.sample_count+1
 end
 if elapsed>=1530 then
  local state=snapshot(t)
  local blockers={}
  local function require_native(condition,reason)
    if not condition then blockers[#blockers+1]=reason end
  end
  require_native(t.sample_count>=4,"native combat checkpoints absent")
  require_native(t.damage.player>0 and t.hits.player>0,
    "native enemy/biter force did not damage a player entity")
  require_native(t.damage.renegade>0 and t.hits.renegade>0,
    "player did not inflict any native damage on hostile renegades")
  require_native(state.rounds_missing_from_surviving_turrets>0,
    "no physical bunker ammunition consumption observed")
  require_native(state.aai_registry_available,
    "AAI managed unit registry unavailable in native battle")
  require_native(state.actors_alive>0 and state.turrets_alive>0,
    "no surviving AAI-managed combatant and native bunker at end of battle")
  for _,rec in ipairs(t.protected)do
    require_native(rec.entity.valid and rec.entity.health==rec.health,
      "ceasefire/friendly target damaged "..rec.role)
  end
  local verdict=#blockers==0 and "PASS" or "FAIL"
  local proof={status=verdict,native=true,
    source="Factorio GUI 2.1",engine_version=script.active_mods.base,
    scenario="fixture-staged-physical-units-and-ammo-not-factory-recruitment",
    expected=t.expected,counts=state,damage=t.damage,hits=t.hits,
    frames=t.clips,samples=t.sample_count,blockers=blockers,
    no_scripted_damage=true,allied_safety=t.damage.protected==0}
  helpers.write_file("combat-roster/batch-native/manifest.json",
    helpers.table_to_json(proof),false)
  t.done=true
  log(MARK.."NATIVE_COMBAT_COMPLETE "..helpers.table_to_json{
    status=verdict,blockers=blockers,damage=t.damage,hits=t.hits,
    remaining=state,
    clip_counts={#(t.clips["01-massed-units"] or {}),
      #(t.clips["02-bunker-lines"] or {}),
      #(t.clips["03-enemy-flank"] or {})}})
  -- Even a genuine combat FAIL deserves saved, original frame evidence.
  game.auto_save("combat-batch-native")
 end
end
local function damaged(e)
 local t=storage.combat_batch_visual
 if not (t and e.entity and e.final_damage_amount
      and e.final_damage_amount>0)then return end
 local target=e.entity
 local f=target.force and target.force.name or ""
 if f=="player" then t.damage.player=t.damage.player+e.final_damage_amount
   t.hits.player=t.hits.player+1
 elseif f=="tech-priests-renegades-nauvis"then
   t.damage.renegade=t.damage.renegade+e.final_damage_amount
   t.hits.renegade=t.hits.renegade+1
 elseif f=="enemy"then
   t.damage.enemy=t.damage.enemy+e.final_damage_amount
   t.hits.enemy=t.hits.enemy+1
 end
 for _,rec in ipairs(t.protected or {})do
  if rec.entity==target then t.damage.protected=t.damage.protected+e.final_damage_amount end
 end
end
Registry.on_init(init,{owner="combat-batch-native",route="setup",priority=2200})
Registry.on_event(defines.events.on_tick,tick,nil,
  {owner="combat-batch-native",route="record-proof",priority=2200})
Registry.on_event(defines.events.on_entity_damaged,damaged,nil,
  {owner="combat-batch-native",route="native-damage",priority=2200})
