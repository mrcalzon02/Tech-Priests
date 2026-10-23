-- Hostile incidents remain persistent, bounded, enemy-only and station-owned.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.combat_defense_reaction_0816")
game={tick=108100}
defines={inventory={turret_ammo=7},events={on_entity_damaged=92}}
local player={name="player"}
local enemy={name="enemy"}
player.is_enemy=function(other) return other==enemy end
enemy.is_enemy=function(other) return other==player end
local visible_turrets={}
local surface={index=1}
surface.find_entities_filtered=function(_) return visible_turrets end
local function turret_lookup(_,_,_) return visible_turrets end
local function entity(name,x,force)
  return {valid=true,name=name,position={x=x,y=0},force=force,surface=surface}
end
local left=entity("intermediate-cogitator-station",0,player)
local right=entity("planetary-magos-cogitator-station",64,player)
left.unit_number=100
right.unit_number=101
local first={station=left,priest=entity("tech-priest",1,player),radius=28}
local second={station=right,priest=entity("tech-priest",65,player),radius=28}
local pairs={a=first,b=second}
local biter=entity("small-biter",58,enemy)
local victim=entity("stone-furnace",60,player)
local ok,reason=M.record_damage({entity=victim,cause=biter,final_damage_amount=4},pairs)
assert(ok and reason=="queued","real hostile damage was not recorded")
assert(first.defense_perimeter_0259==nil,"wrong Cogitator took attack")
local state=second.defense_perimeter_0259
local incident=state.hostile_incidents_0817[1]
assert(#state.threats==1 and state.hostile_hits_0816==1
  and incident.first_tick==108100 and incident.expires_at>game.tick
  and incident.station_unit==101 and incident.surface_index==1
  and incident.force_name=="player" and incident.hit_count==1
  and state.threats[1].incident_id_0817==incident.id
  and math.abs(state.threats[1].position.x-37)<0.01
  and state.turrets_built_at_first_hostile_hit_0816==0,
  "hostile waypoint did not retain physical site, ownership or lifetime")
for _=1,20 do
  game.tick=game.tick+1
  local yes,why=M.record_damage({entity=victim,cause=biter,damage_amount=2},pairs)
  assert(yes and why=="refreshed","burst damage did not refresh memory")
end
assert(#state.threats==1 and #state.hostile_incidents_0817==1
  and incident.hit_count==21 and incident.total_damage==44,
  "repeated hits generated redundant incidents or dropped severity")
local friendly=entity("allied-priest",58,player)
assert(not M.record_damage({entity=victim,cause=friendly,damage_amount=10},pairs))
assert(not M.record_damage({entity=victim,cause=biter,damage_amount=0},pairs))
local far=entity("rock",180,player)
assert(not M.record_damage({entity=far,cause=biter,damage_amount=3},pairs))
assert(#state.threats==1 and incident.hit_count==21,
  "friendly, zero or out-of-station damage altered memory")
game.tick=game.tick+M.repeat_window+1
local yes,why=M.record_damage({entity=victim,cause=biter,damage_amount=4},pairs)
assert(yes and why=="refreshed" and #state.threats==1
  and #state.hostile_incidents_0817==1
  and incident.expires_at==game.tick+M.incident_lifetime_ticks,
  "older hostile incident lost stable locality or retention")
local victim_near=entity("assembling-machine",43,player)
yes,why=M.record_damage({entity=victim_near,cause=biter,damage_amount=9},pairs)
assert(yes and why=="queued" and #state.hostile_incidents_0817==2
  and #state.threats==2,"distinct neighboring facility lost its incident")
local no_state={station=right,priest=second.priest,radius=28}
assert(M.reconcile_pair(no_state,turret_lookup)==0 and no_state.defense_perimeter_0259==nil,
  "old saves without incident memory did not migrate safely")
assert(M.reconcile_pair(second,turret_lookup)==2 and #state.threats==2,
  "uncovered locations did not remain actionable")
local armed=true
visible_turrets={
  {valid=true,type="ammo-turret",
   get_inventory=function(slot)
     assert(slot==7)
     return {valid=true,is_empty=function() return not armed end}
   end},
}
game.tick=game.tick+M.reconcile_interval_ticks
assert(M.reconcile_pair(second,turret_lookup)==0 and #state.threats==0,
  "existing physical coverage did not suppress duplicate turret requests")
assert(incident.status=="defended" and incident.covered,
  "genuinely armed existing turret was not recognized")
-- A struck but already-defended location must NOT create a new turret
-- demand between physical-coverage scans.
game.tick=game.tick+1
local defended_hit,defended_reason=M.record_damage({
  entity=victim,cause=biter,damage_amount=1},pairs)
assert(defended_hit and defended_reason=="refreshed"
  and #state.threats==0 and incident.covered,
  "repeated damage at an armed turret generated duplicate defense notice")
armed=false
game.tick=game.tick+M.reconcile_interval_ticks
M.reconcile_pair(second,turret_lookup)
assert(incident.status=="resupply-required" and incident.needs_ammo
  and #state.threats==0,
  "empty turret should require ammunition, not a duplicate turret")
second.defense_task_0259={type="build-turret",incident_id_0817=incident.id}
game.tick=game.tick+M.incident_lifetime_ticks+1
M.reconcile_pair(second,turret_lookup)
assert(second.defense_task_0259~=nil,
  "incident expiry illegally deleted active construction")
second.defense_task_0259=nil
game.tick=game.tick+M.reconcile_interval_ticks
M.reconcile_pair(second,turret_lookup)
assert(#state.hostile_incidents_0817==0 and #state.threats==0
  and state.expired_incidents_0817==2,
  "expired locations lingered or left stale construction requests")
-- One wall section can be hit hundreds of times without creating a new
-- incident, resetting the planner every tick, or producing duplicate tasks.
local station3=entity("intermediate-cogitator-station",250,player)
station3.unit_number=102
local pair3={station=station3,priest=entity("tech-priest",250,player),radius=28}
local wall_a=entity("stone-wall",267,player)
local attacker_a=entity("small-biter",271,enemy)
attacker_a.position.y=1
game.tick=game.tick+100
local first_hit_tick=game.tick
local yes3,why3=M.record_damage({
  entity=wall_a,cause=attacker_a,damage_amount=3},{third=pair3})
assert(yes3 and why3=="queued","first wall attack did not create memory")
local st3=pair3.defense_perimeter_0259
local site=st3.hostile_incidents_0817[1]
local first_id=site.id
assert(site.expires_at-first_hit_tick==M.incident_lifetime_ticks
  and M.incident_lifetime_ticks>=5000000
  and site.active_until-first_hit_tick==M.incident_decay_ticks
  and M.incident_decay_ticks<M.incident_lifetime_ticks,
  "long-term memory and renewable decay timers were not separate")
st3.next_scan_tick=game.tick+180
st3.next_incident_review_0817=game.tick+180
for i=1,150 do
  local got,why=M.record_damage({
    entity=wall_a,cause=attacker_a,damage_amount=1},{third=pair3})
  assert(got and why=="refreshed")
end
assert(#st3.hostile_incidents_0817==1 and #st3.threats==1
  and site.hit_count==151 and site.waves==1
  and site.position.x==267 and site.position.y==0
  and st3.next_scan_tick>game.tick
  and st3.next_incident_review_0817>game.tick,
  "same-tick damage spam duplicated work or thrashed scan cadence")
local wall_b=entity("stone-wall",265,player)
wall_b.position.y=8
local attacker_b=entity("small-biter",268,enemy)
attacker_b.position.y=10
game.tick=game.tick+M.center_sample_interval_ticks
local before_hot=site.active_until
local before_center=site.defense_position.y
local moved,merged=M.record_damage({
  entity=wall_b,cause=attacker_b,damage_amount=2},{third=pair3})
assert(moved and merged=="refreshed" and site.id==first_id
  and #st3.threats==1 and #st3.hostile_incidents_0817==1
  and site.position.y>0 and site.position.y<wall_b.position.y
  and site.defense_position.y>before_center
  and st3.threats[1].position.y==site.defense_position.y
  and site.active_until>before_hot
  and st3.next_scan_tick>game.tick,
  "attack drift should slide queued center without new task or scan spam")
-- An opposite (but nearby) hit moves the center back after the sampling
-- interval; sufficient movement may wake the existing planner, not new jobs.
wall_b.position.y=-6
attacker_b.position.y=-8
game.tick=game.tick+M.wake_interval_ticks
local prior_center=site.defense_position.y
M.record_damage({entity=wall_b,cause=attacker_b,damage_amount=1},
  {third=pair3})
assert(site.defense_position.y<prior_center
  and #st3.threats==1 and site.id==first_id,
  "moving hostile front failed to steer an existing alert")
game.tick=site.active_until+1
local no_turrets=function() return {} end
assert(M.reconcile_pair(pair3,no_turrets)==1
  and #st3.hostile_incidents_0817==1
  and #st3.threats==1 and site.urgency_phase=="cooling"
  and site.effective_priority<=site.priority,
  "short decay incorrectly erased persistent tactical memory")
local wave_start=game.tick
local reactivated,refresh=M.record_damage({
  entity=wall_a,cause=attacker_a,damage_amount=2},{third=pair3})
assert(reactivated and refresh=="refreshed"
  and site.id==first_id and site.waves==2
  and site.active_until==wave_start+M.incident_decay_ticks
  and site.expires_at==wave_start+M.incident_lifetime_ticks
  and #st3.hostile_incidents_0817==1 and #st3.threats==1,
  "attack after decay should reactivate retained incident, not make new one")
pair3.defense_task_0259={
  type="build-turret",incident_id_0817=site.id,
  position={x=site.defense_position.x,y=site.defense_position.y}}
local owned_position=pair3.defense_task_0259.position
game.tick=game.tick+M.center_sample_interval_ticks
M.record_damage({entity=wall_b,cause=attacker_b,damage_amount=1},
  {third=pair3})
assert(pair3.defense_task_0259.position==owned_position
  and #st3.threats==1,
  "an active priest's construction commitment was retargeted")
pair3.defense_task_0259=nil
game.tick=site.last_tick+M.incident_lifetime_ticks-1
M.reconcile_pair(pair3,no_turrets)
assert(#st3.hostile_incidents_0817==1,
  "incident was purged before the full quiet retention interval")
game.tick=game.tick+1
M.reconcile_pair(pair3,no_turrets)
assert(#st3.hostile_incidents_0817==0 and #st3.threats==0,
  "incident did not expire after the full quiet interval")

-- The memory cap may suppress NEW sites but must never evict hot, uncovered,
-- already-owned incidents simply because a ninth location took damage.
local station4=entity("planetary-magos-cogitator-station",4000,player)
station4.unit_number=103
local pair4={station=station4,priest=entity("tech-priest",4000,player),radius=28}
local grid={
  {-18,-18},{0,-18},{18,-18},{-18,0},
  {0,0},{18,0},{-18,18},{0,18},{18,18}}
for i=1,M.max_incidents do
  local victim4=entity("stone-wall",4000+grid[i][1],player)
  victim4.position.y=grid[i][2]
  local attacker4=entity("small-biter",victim4.position.x+1,enemy)
  attacker4.position.y=victim4.position.y
  game.tick=game.tick+1
  local good=M.record_damage({entity=victim4,cause=attacker4,
    damage_amount=1},{fourth=pair4})
  assert(good,"could not fill incident limit with independent sites")
end
local st4=pair4.defense_perimeter_0259
assert(#st4.hostile_incidents_0817==M.max_incidents
  and #st4.threats==M.max_incidents,"eight-site ledger cap broken")
local ninth=entity("stone-wall",4018,player)
ninth.position.y=18
local ninth_enemy=entity("small-biter",4019,enemy)
ninth_enemy.position.y=18
local accepted,suppressed=M.record_damage({
  entity=ninth,cause=ninth_enemy,damage_amount=1},{fourth=pair4})
assert(accepted and suppressed=="capacity-suppressed"
  and #st4.hostile_incidents_0817==M.max_incidents
  and #st4.threats==M.max_incidents
  and st4.suppressed_new_incidents_0817==1,
  "incident spam exceeded memory cap or discarded active hot locations")
-- Legacy on-disk incidents gain the long retention and separate active
-- decay in place, without destroying their stable identifier.
local old_pair={station=station3,priest=pair3.priest,radius=28,
  defense_perimeter_0259={hostile_incidents_0817={{
    id=77,station_unit=102,surface_index=1,force_name="player",
    position={x=267,y=0},defense_position={x=277,y=0},
    first_tick=100,last_tick=200,expires_at=216200,
    hit_count=2,total_damage=4,priority=7,
  }},threats={}}}
game.tick=220000
M.reconcile_pair(old_pair,no_turrets)
local migrated=old_pair.defense_perimeter_0259.hostile_incidents_0817[1]
assert(migrated.id==77 and migrated.active_until==200+M.incident_decay_ticks
  and migrated.expires_at==200+M.incident_lifetime_ticks
  and migrated.urgency_phase=="cooling",
  "saved 0817 memory failed non-destructive long-retention migration")
-- Real engine damage events can have no surviving LuaEntity cause but DO
-- contain their authoritative attacking force. They still represent actual
-- hostile damage, unlike a fabricated notification or friendly repair event.
local anonymous_station=entity("junior-cogitator-station",6000,player)
anonymous_station.unit_number=104
local anonymous_pair={
  station=anonymous_station,priest=entity("tech-priest",6000,player),radius=28}
local anonymous_wall=entity("stone-wall",6012,player)
local anonymous_ok,anonymous_reason=M.record_damage({
  entity=anonymous_wall,force=enemy,final_damage_amount=7
},{anonymous=anonymous_pair})
assert(anonymous_ok and anonymous_reason=="queued",
  "hostile event.force with optional cause absent must create incident")
local anonymous_state=anonymous_pair.defense_perimeter_0259
assert(anonymous_state.hostile_hits_0816==1
  and anonymous_state.hostile_incidents_0817[1].attacker=="force:enemy"
  and anonymous_state.hostile_incidents_0817[1].total_damage==7,
  "force-only hostile event lost exact physical damage or attacker origin")
assert(not M.record_damage({
  entity=anonymous_wall,force=player,final_damage_amount=7
},{anonymous=anonymous_pair}),
  "friendly force-only damage wrongly created an incident")
assert(not M.record_damage({
  entity=anonymous_wall,final_damage_amount=7
},{anonymous=anonymous_pair}),
  "damage with no known hostile force must fail closed")
assert(not M.record_damage({
  entity=anonymous_wall,cause=biter,force=player,final_damage_amount=7
},{anonymous=anonymous_pair}),
  "authoritative friendly attacking force must override stale enemy cause")
local hostile_projectile=entity("acid-projectile",6013,enemy)
local projectile_ok=M.record_damage({
  entity=anonymous_wall,source=hostile_projectile,final_damage_amount=2
},{anonymous=anonymous_pair})
assert(projectile_ok and anonymous_state.hostile_hits_0816==2
  and #anonymous_state.hostile_incidents_0817==1,
  "physical hostile projectile without cause should refresh existing incident")
local registered
_G.TechPriestsRuntimeEventRegistry={on_event=function(id,callback,_,opts)
  assert(id==92 and opts.owner=="combat_defense_reaction_0816")
  registered=callback
  return true
end}
assert(M.install() and registered==M.record_damage,
  "canonical damage-event registration was altered")
-- Canonical event routes can remain in memory after an unrelated legacy
-- script.on_event overwrites Factorio's actual handler. Reattaching an owner
-- must restore the original registry dispatcher without duplicating routes.
local current_handlers={}
local current_filter=nil
script={
  on_event=function(id,handler) current_handlers[id]=handler end,
  get_event_handler=function(id) return current_handlers[id] end,
  get_event_filter=function(_) return current_filter end,
  set_event_filter=function(_,filters) current_filter=filters end,
}
local Registry=require("scripts.core.runtime_event_registry")
local received=0
local function observe() received=received+1 end
Registry.on_event(92,observe,nil,{owner="test",route="damage"})
local initial_handler=current_handlers[92]
assert(type(initial_handler)=="function"
  and Registry.event_delivery_status(92).verified,
  "initial registry engine handler not installed")
current_handlers[92]=function() error("legacy handler stole engine channel") end
current_filter={{filter="name",name="rail"}}
local missing=Registry.event_delivery_status(92)
assert(not missing.verified and missing.routes==1,
  "raw legacy overwrite was not identified")
local recovered,reason=Registry.reconcile_event(92)
assert(recovered and reason=="canonical","registry could not rebind engine")
local restored=Registry.event_delivery_status(92)
assert(restored.verified and restored.rebindings==1
  and not restored.filter_present and current_filter==nil
  and restored.routes==1 and current_handlers[92]==initial_handler,
  "re-registration did not recover canonical event delivery")
current_handlers[92]({name=92})
assert(received==1,"engine dispatch did not reach its canonical listener once")
Registry.on_event(92,observe,nil,{owner="test",route="damage"})
assert(Registry.event_delivery_status(92).rebindings==1,
  "healthy registry incurred redundant event rebindings")
print("[combat-defense-reaction] PASS durable hostile memory, coalescing, coverage, expiry and migration")
