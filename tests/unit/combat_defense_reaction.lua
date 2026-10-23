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
local registered
_G.TechPriestsRuntimeEventRegistry={on_event=function(id,callback,_,opts)
  assert(id==92 and opts.owner=="combat_defense_reaction_0816")
  registered=callback
  return true
end}
assert(M.install() and registered==M.record_damage,
  "canonical damage-event registration was altered")
print("[combat-defense-reaction] PASS durable hostile memory, coalescing, coverage, expiry and migration")
