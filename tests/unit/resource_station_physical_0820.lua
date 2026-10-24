-- Exercise the ACTUAL 0256 expansion executor with an existing inventory
-- and a new real-style on_built pair registration. No free station item.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local surface={index=1}
local force={name="player"}
local ghost,physical
local foreign_ghost, block_all_ghost_sites
local next_ghost_unit=8000
local built_count=0
local fail_next_build=false
local throw_after_build=false
surface.can_place_entity=function(_)return true end
surface.find_entities_filtered=function(filters)
  if filters.name=="entity-ghost" then
    if block_all_ghost_sites then return {foreign_ghost} end
    local matches={}
    for _,candidate in pairs({foreign=foreign_ghost,planned=ghost}) do
      if candidate and candidate.valid
          and (not filters.ghost_name or candidate.ghost_name==filters.ghost_name)
          and (not filters.force or candidate.force==filters.force)
          and (not filters.area or (
            candidate.position.x>=filters.area[1][1]
            and candidate.position.x<=filters.area[2][1]
            and candidate.position.y>=filters.area[1][2]
            and candidate.position.y<=filters.area[2][2])) then
        matches[#matches+1]=candidate
      end
    end
    return matches
  end
  if filters.name=="senior-cogitator-station" then
    return physical and physical.valid and {physical} or {}
  end
  return {}
end
surface.create_entity=function(args)
  if args.name=="entity-ghost" then
    next_ghost_unit=next_ghost_unit+1
    ghost={valid=true,name="entity-ghost",
      position=args.position,ghost_name=args.inner_name,unit_number=next_ghost_unit,
      force=force,surface=surface,
      destroy=function()ghost.valid=false end}
    return ghost
  end
  if args.name=="senior-cogitator-station" then
    assert(ghost and ghost.valid,
      "station ghost was destroyed before physical construction succeeded")
    if fail_next_build then
      fail_next_build=false
      error("simulated engine rejection of physical station placement")
    end
    physical={valid=true,name=args.name,position=args.position,
      unit_number=802,force=force,surface=surface}
    built_count=built_count+1
    if throw_after_build then
      throw_after_build=false
      error("simulated raised-built callback exception after entity creation")
    end
    return physical
  end
  error("unexpected create_entity "..tostring(args.name))
end
local created_cargo = {}
game={tick=100,create_inventory=function(size)
  assert(size==1, "station cargo must have exactly one engine-owned slot")
  local bag={valid=true,stock=0}
  bag.get_item_count=function(item)
    assert(item=="senior-cogitator-station")
    return bag.stock
  end
  bag.insert=function(stack)
    assert(stack.name=="senior-cogitator-station")
    if bag.stock+stack.count>1 then return 0 end
    bag.stock=bag.stock+stack.count
    return stack.count
  end
  bag.remove=function(stack)
    assert(stack.name=="senior-cogitator-station")
    local taken=math.min(bag.stock,stack.count)
    bag.stock=bag.stock-taken
    return taken
  end
  bag.destroy=function()
    assert(bag.stock==0,"never destroy a hold containing physical stock")
    bag.valid=false
  end
  created_cargo[#created_cargo+1]=bag
  return bag
end}
-- The live executor only issues movement through Factorio's command API.
-- A fixture without these definitions falsely stalls before ghost arrival.
defines={command={go_to_location=1},distraction={none=0}}
local station={valid=true,unit_number=200,
  name="planetary-magos-cogitator-station",position={x=0,y=0},
  force=force,surface=surface}
local priest={valid=true,unit_number=201,position={x=0,y=0}}
local pair={station=station,priest=priest,rank_test=4,radius=30}
storage={tech_priests={pairs_by_station={[200]=pair}}}
tech_priests_0252_rank_number=function(p)return p.rank_test end
tech_priests_get_item_prototype_0440=function(name)
  if name=="senior-cogitator-station" then return {name=name} end
end
tech_priests_get_entity_prototype_0440=function(name)
  if name=="senior-cogitator-station" then return {name=name} end
end
tech_priests_surface_supports_martian_emergency_doctrine_0184=function()return true end
local stock=0
local inventory={valid=true,
  get_insertable_count=function()return 10 end,
  get_item_count=function(name)
    return name=="senior-cogitator-station" and stock or 0
  end,
  remove=function(args)
    local taken=math.min(stock,args.count)
    stock=stock-taken
    return taken
  end,
  insert=function(args)stock=stock+args.count;return args.count end,
}
get_station_inventory=function()return inventory end
local acquisition_requests=0
tech_priests_emergency_operation_acquire_item_0185=function(_,name)
  assert(name=="senior-cogitator-station")
  acquisition_requests=acquisition_requests+1
  return true
end
local movement_orders=0
issue_priest_command=function(_,order)
  movement_orders=movement_orders+1
  priest.position={x=order.destination.x,y=order.destination.y}
end
local paired=0
on_built=function(event)
  assert(event.entity==physical,"built callback received an unrelated entity")
  paired=paired+1
  storage.tech_priests.pairs_by_station[802]={
    station=physical,priest={valid=true,position=physical.position},
    rank_test=3,radius=28,
  }
end
local Expansion=dofile("tech-priests_src/scripts/magos_station_expansion.lua")
-- A new worker can exist before the first 0256 planner tick. The registry
-- must be initialized by its authoritative module before reserving that
-- worker, and later planner calls must neither steal nor erase its writ.
assert(storage.tech_priests.station_expansion_0256==nil
  and storage.tech_priests.station_expansion_by_worker_0256==nil
  and storage.tech_priests.station_expansion_next_id_0256==nil,
  "fixture must exercise genuinely uninitialized 0256 registries")
assert(Expansion.ensure_state(), "early 0256 registry initialization failed")
local expansion_state=storage.tech_priests
local writs=expansion_state.station_expansion_0256
local by_worker=expansion_state.station_expansion_by_worker_0256
local reserved_id=expansion_state.station_expansion_next_id_0256
assert(type(writs)=="table" and type(by_worker)=="table"
  and type(reserved_id)=="number", "0256 registry remains unavailable")
writs[reserved_id]={id=reserved_id,status="awaiting-pairing",
  requester_station_unit=station.unit_number,
  worker_station_unit=station.unit_number}
by_worker[station.unit_number]=reserved_id
expansion_state.station_expansion_next_id_0256=reserved_id+1
assert(Expansion.ensure_state() and expansion_state.station_expansion_0256==writs
  and expansion_state.station_expansion_by_worker_0256==by_worker
  and expansion_state.station_expansion_next_id_0256==reserved_id+1
  and writs[reserved_id].status=="awaiting-pairing",
  "repeated initialization erased an existing worker reservation")
assert(not Expansion.request_station_expansion(
    pair,"resource:iron-ore",nil,"reserved-worker-must-not-be-stolen",0)
  and ghost==nil and by_worker[station.unit_number]==reserved_id
  and expansion_state.station_expansion_next_id_0256==reserved_id+1,
  "ordinary planner stole an early reserved worker or projected a ghost")
writs[reserved_id]=nil
by_worker[station.unit_number]=nil
expansion_state.station_expansion_next_id_0256=reserved_id
assert(Expansion.allowed_station_item_for_pair(pair)=="senior-cogitator-station")
-- A pre-existing ghost cannot be borrowed by a newly created writ.
foreign_ghost={valid=true,name="entity-ghost",ghost_name="senior-cogitator-station",
  position={x=30.5,y=0.5},unit_number=799,force=force,surface=surface}
block_all_ghost_sites=true
assert(not Expansion.request_station_expansion(
    pair,"resource:iron-ore",nil,"all-ghost-sites-occupied",0)
  and ghost==nil and next(storage.tech_priests.station_expansion_0256)==nil
  and storage.tech_priests.station_expansion_next_id_0256==reserved_id
  and foreign_ghost.valid and stock==0,
  "an occupied ghost site was reused or generated an orphan writ")
block_all_ghost_sites=false
local requested=Expansion.request_station_expansion(
  pair,"resource:iron-ore",nil,"known-patch-east",0)
local rec=storage.tech_priests.station_expansion_0256[1]
assert(requested and rec and rec.status=="active"
  and rec.requester_station_unit==200 and rec.worker_station_unit==200
  and rec.required_worker_rank==3 and rec.commander_bootstrap
  and ghost and ghost.valid and ghost~=foreign_ghost
  and rec.ghost_unit~=foreign_ghost.unit_number
  and (math.abs(ghost.position.x-foreign_ghost.position.x)>=0.75
    or math.abs(ghost.position.y-foreign_ghost.position.y)>=0.75)
  and foreign_ghost.valid
  and not physical and stock==0,
  "Magos adopted an occupied ghost rather than creating its own station ghost")
local initial_ghost=ghost
local next_id=storage.tech_priests.station_expansion_next_id_0256
assert(not Expansion.request_station_expansion(
    pair,"resource:copper-ore",nil,"competing-mission",1)
  and ghost==initial_ghost
  and storage.tech_priests.station_expansion_next_id_0256==next_id,
  "busy commander created an orphan competing station ghost")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and acquisition_requests==1 and built_count==0
  and stock==0 and ghost.valid
  and rec.recycling_candidate_unit_0822==nil
  and rec.recycling_preflight_0822=="no-safe-subordinate-station",
  "missing station item was fabricated or unsafe recovery was attempted")
stock=1 -- Physically stocked fixture after a real acquisition path.
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and movement_orders==1 and rec.phase=="moving-to-ghost"
  and stock==0 and not physical
  and #created_cargo==1 and created_cargo[1].stock==1
  and rec.recycling_candidate_unit_0822==nil
  and rec.recycling_preflight_0822==nil,
  "station built before reaching ghost or stale recovery proposal remained")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and rec.phase=="building-ghost"
  and stock==0 and created_cargo[1].stock==1
  and rec.build_due_tick>game.tick,
  "ghost placement bypassed the physical construction delay")
game.tick=rec.build_due_tick
ghost.quality={name="rare"}
assert(Expansion.service_station_expansion_assignment(pair)
  and rec.phase=="ghost-quality-does-not-match-carried-item"
  and created_cargo[1].stock==1 and built_count==0,
  "a normal carried station item cannot become a rare station for free")
ghost.quality={name="normal"}
assert(Expansion.service_station_expansion_assignment(pair)
  and stock==0 and built_count==1
  and rec.status=="complete" and paired==1
  and physical and physical.valid and not ghost.valid
  and not created_cargo[1].valid
  and storage.tech_priests.pairs_by_station[802].station==physical
  and storage.tech_priests.station_expansion_by_worker_0256[200]==nil,
  "lower rank child not physically built, paired, or accounted for")
-- A collision/engine error cannot consume the station item or erase the
-- ghost. It must remain possible to retry after the bounded delay.
physical=nil
ghost=nil
stock=1
fail_next_build=true
priest.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:copper-ore",nil,"retry-after-collision",0))
local retry=storage.tech_priests.station_expansion_0256[2]
assert(retry and retry.status=="active" and ghost and ghost.valid)
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and retry.phase=="moving-to-ghost" and stock==0
  and created_cargo[2].stock==1)
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and retry.phase=="building-ghost" and stock==0
  and created_cargo[2].stock==1)
game.tick=retry.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and retry.status=="active" and retry.phase=="build-failed"
  and ghost.valid and not physical and stock==0
  and created_cargo[2].stock==1
  and built_count==1 and paired==1,
  "failed physical build erased ghost, duplicated station or lost item")
local retry_tick=retry.next_retry_tick
game.tick=retry_tick-1
assert(not Expansion.service_station_expansion_assignment(pair)
  and retry.build_due_tick==nil and created_cargo[2].stock==1,
  "failed station placement ignored its bounded retry delay")
game.tick=retry_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and retry.phase=="building-ghost" and stock==0
  and created_cargo[2].stock==1)
game.tick=retry.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and retry.status=="complete" and stock==0
  and not created_cargo[2].valid
  and physical and physical.valid and not ghost.valid
  and built_count==2 and paired==2,
  "recovered station item failed to construct exactly once on retry")

-- An exception in a raised-built callback can happen after the engine
-- created the station. Observe the entity before refunding to prevent a
-- free station and a returned item existing at the same time.
physical=nil
ghost=nil
stock=1
throw_after_build=true
priest.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:stone",nil,"callback-exception",0))
local callback=storage.tech_priests.station_expansion_0256[3]
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and callback.phase=="moving-to-ghost" and created_cargo[3].stock==1)
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and callback.phase=="building-ghost")
game.tick=callback.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and callback.status=="complete" and physical and physical.valid
  and stock==0 and not created_cargo[3].valid and not ghost.valid
  and built_count==3 and paired==3,
  "post-creation callback exception refunded a physically built station")
print("[resource-station-physical-0820] PASS physical item custody, rejected build retry, post-build exception, paired Senior")

-- A competing builder may finish the ghost after pickup. The priest must walk
-- home with its engine-owned inventory and return the unused physical item.
physical=nil
ghost=nil
stock=1
priest.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:uranium-ore",nil,"competing-build",0))
local outside=storage.tech_priests.station_expansion_0256[4]
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and stock==0 and created_cargo[4].stock==1)
physical={valid=true,name="senior-cogitator-station",
  position=outside.ghost_position,unit_number=903,force=force,surface=surface}
priest.position={x=outside.ghost_position.x,y=outside.ghost_position.y}
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and outside.status=="active"
  and outside.phase=="returning-unused-station-item")
game.tick=game.tick+60
assert(not Expansion.service_station_expansion_assignment(pair)
  and outside.status=="complete" and stock==1
  and not created_cargo[4].valid,
  "outside construction must return physically carried stock, not delete it")
print("[resource-station-cargo-0824] PASS local pickup, real cargo, retry and return")
-- Full live 0256 recovery path: Magos walks 80 tiles to an existing
-- lower-ranked staffed station, physically mines it into priest cargo,
-- walks back out to the ghost, and rebinds the SAME priest to the new site.
physical=nil
ghost=nil
stock=0
priest.position={x=0,y=0}
storage.tech_priests.pairs_by_station[802]=nil
local candidate_station={valid=true,unit_number=950,
  name="senior-cogitator-station",force=force,surface=surface,
  position={x=80,y=0},minable=true,
  prototype={mineable_properties={products={{
    name="senior-cogitator-station",amount=1,type="item"
  }}}}}
local candidate_priest={valid=true,unit_number=951,position={x=80,y=0},
  get_main_inventory=function()
    return {valid=true,get_contents=function()return {} end}
  end}
local candidate={station=candidate_station,priest=candidate_priest,
  rank_test=3,mode="idle",
  command_hierarchy_0480={superior_unit=200,
    direct_subordinate_units={},peer_units={}}}
storage.tech_priests.pairs_by_station[950]=candidate
storage.tech_priests.pairs_by_priest={[951]=candidate}
storage.tech_priests.station_by_priest={[951]=950}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank_test end,
  is_direct_subordinate=function(p,c)
    return c.command_hierarchy_0480
      and c.command_hierarchy_0480.superior_unit==p.station.unit_number
  end,
  peers=function()return {} end,
  rebuild=function()return true end
}
tech_priests_0358_station_sources_for_pair=function(p)
  return {{owner=p.station,inv={
    valid=true,get_contents=function()return {} end
  }}}
end
local recovery_mines=0
candidate_station.mine=function(args)
  recovery_mines=recovery_mines+1
  assert(args.inventory==created_cargo[5]
    and args.force==true and args.raise_destroy==true,
    "recovery must mine into the real priest cargo, not the parent station")
  assert(_G.tech_priests_relocation_intercept_removed_0823(
    candidate_station,{name=defines.events.script_raised_destroy}))
  candidate_station.valid=false
  args.inventory.stock=args.inventory.stock+1
  return true
end
defines.events={script_raised_destroy=11,on_entity_died=12}
on_built=function(event)
  paired=paired+1
  assert(_G.tech_priests_relocation_claim_0823(event.entity),
    "built event must rebind the original staffed station's priest")
end
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:iron-ore",nil,"recover-distant-senior",0))
local distant=storage.tech_priests.station_expansion_0256[5]
assert(distant and distant.status=="active" and ghost and ghost.valid)
-- A resource-starved writ must reserve the eligible leaf immediately, before
-- the next infrastructure-governor pulse can start an unrelated 0647 request.
local Recycling0822=require("scripts.core.station_recycling_0822")
assert(distant.recycling_candidate_unit_0822==950
  and Recycling0822.reservation_for(candidate)==distant
  and Recycling0822.reservation_for(pair)==nil
  and candidate.mode=="idle",
  "station starvation must reserve the real recoverable subordinate at writ creation")
local Governor0640=require("scripts.core.infrastructure_first_governor_0640")
local governor_ran,governor_reason=Governor0640.service_pair(candidate,"physical-recovery-regression")
assert(governor_ran==false
  and governor_reason=="physical-station-recovery-reserved"
  and candidate.mode=="idle" and candidate.emergency_craft==nil
  and candidate.infrastructure_recipe_request_0647==nil,
  "0640 must not assign a new material-acquisition task to a reserved leaf")
local rival={station={valid=true,unit_number=960,name=station.name,
    force=force,surface=surface},priest={valid=true,unit_number=961}}
local rival_ok,rival_reason=Recycling0822.check_candidate(
  rival,candidate,"senior-cogitator-station")
assert(not rival_ok and rival_reason=="station-reserved-for-other-recovery-worker",
  "another worker must not claim a station held by an active physical writ")
-- A reservation must neither override existing work nor outlive its writ.
candidate.mode="working"
local busy_ok,busy_reason=Recycling0822.check_candidate(
  pair,candidate,"senior-cogitator-station")
assert(not busy_ok and busy_reason=="priest-not-idle",
  "planning reservation must never authorize mining an occupied priest")
candidate.mode="idle"
distant.status="failed"
assert(Recycling0822.reservation_for(candidate)==nil,
  "completed or failed recovery writ must release planning reservation")
distant.status="active"
assert(Recycling0822.reservation_for(candidate)==distant,
  "persisted active writ must reconstruct reservation without transient state")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.phase=="moving-to-physical-station-recovery"
  and priest.position.x==80 and recovery_mines==0
  and stock==0 and #created_cargo==4,
  "worker must physically walk to the distant subordinate before mining")
-- A temporary competing duty must not redirect a resource-starved recovery
-- writ to ordinary station-item acquisition or mine an occupied station.
local acquisitions_before_block=acquisition_requests
candidate.mode="working"
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.phase=="station-recovery-blocked"
  and distant.recycling_preflight_0822=="priest-not-idle"
  and distant.recycling_candidate_unit_0822==950
  and acquisition_requests==acquisitions_before_block
  and recovery_mines==0 and candidate_station.valid
  and #created_cargo==4 and stock==0,
  "busy recovery candidate must block safely without fallback acquisition")
-- Reproduce the real 2.0.77 failure: after the 15-second eligibility
-- re-probe, a busy priest disappeared from find_candidate(), which erased
-- the reserved source station and incorrectly started fresh item acquisition.
-- A reserved candidate remains bound, but the actual mine must stay denied.
game.tick=distant.next_recycle_probe_tick_0822
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.phase=="station-recovery-blocked"
  and distant.recycling_preflight_0822=="priest-not-idle"
  and distant.recycling_candidate_unit_0822==950
  and acquisition_requests==acquisitions_before_block
  and recovery_mines==0 and candidate_station.valid
  and #created_cargo==4 and stock==0,
  "eligibility re-probe must retain the reserved busy station without mining or acquisition")
candidate.mode="idle"
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.phase=="station-item-physically-recovered-to-priest-cargo"
  and recovery_mines==1 and not candidate_station.valid
  and candidate_priest.valid and created_cargo[5].stock==1
  and storage.tech_priests.pairs_by_station[950]==nil
  and stock==0,"distant mine must preserve priest and counted carried item")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.phase=="moving-to-ghost" and stock==0
  and created_cargo[5].stock==1)
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.phase=="building-ghost" and stock==0)
game.tick=distant.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and distant.status=="complete" and recovery_mines==1
  and candidate.priest==candidate_priest and candidate_priest.valid
  and candidate.station==physical and candidate.station.unit_number==802
  and storage.tech_priests.pairs_by_station[802]==candidate
  and storage.tech_priests.station_by_priest[951]==802
  and not created_cargo[5].valid and stock==0,
  "real recovered item must build the distant ghost and preserve original priest")
print("[resource-station-recovery-0825] PASS 0256 distant walk, physical mine, cargo, rebuilt ghost and original priest")

-- The actual 0256 executor must NOT inherit a killed priest's cargo from a
-- distance. It must walk the replacement to the death site and reclaim the
-- same physical engine inventory before building the pending ghost.
physical=nil
ghost=nil
stock=1
priest.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:copper-ore",nil,"recover-fallen-carrier",0))
local fallen=storage.tech_priests.station_expansion_0256[6]
assert(fallen and fallen.status=="active" and ghost and ghost.valid)
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and fallen.phase=="moving-to-ghost" and stock==0
  and created_cargo[6].stock==1)
local Cargo=require("scripts.core.station_cargo_0824")
local death_site={x=priest.position.x,y=priest.position.y}
assert(Cargo.note_priest_lost(pair,priest)==1)
priest.valid=false
local replacement={valid=true,unit_number=202,position={x=0,y=0}}
pair.priest=replacement
pair.priest_unit=replacement.unit_number
issue_priest_command=function(actor,order)
  movement_orders=movement_orders+1
  actor.position={x=order.destination.x,y=order.destination.y}
end
on_built=function(event)
  paired=paired+1
  storage.tech_priests.pairs_by_station[802]={
    station=event.entity,priest={valid=true,position=event.entity.position},
    rank_test=3,radius=28,
  }
end
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and fallen.phase=="moving-to-fallen-carrier-cargo"
  and replacement.position.x==death_site.x
  and created_cargo[6].stock==1 and stock==0,
  "replacement priest cannot take a dead priest's item remotely")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and fallen.phase=="building-ghost"
  and created_cargo[6].stock==1 and stock==0,
  "death-site salvage did not resume the real ghost build")
game.tick=fallen.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and fallen.status=="complete" and physical and physical.valid
  and not created_cargo[6].valid and stock==0,
  "death-site salvage lost or duplicated the physical station item")
print("[resource-station-cargo-death-0826] PASS actual 0256 death-site travel, salvage, build")
-- A process/save interruption between the real cargo debit and entity
-- creation must not strand the item in an empty "building" inventory.
-- The live executor reconciles that debit, retries, and constructs once.
physical=nil
ghost=nil
stock=1
replacement.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:stone",nil,"interrupted-build-recovery",0))
local interrupted=storage.tech_priests.station_expansion_0256[7]
assert(interrupted and interrupted.status=="active")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and interrupted.phase=="moving-to-ghost" and stock==0
  and created_cargo[7].stock==1)
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and interrupted.phase=="building-ghost" and ghost.valid)
local Cargo0827=require("scripts.core.station_cargo_0824")
assert(Cargo0827.begin_build(pair,interrupted)
  and created_cargo[7].stock==0
  and Cargo0827.get(pair,interrupted).status=="building",
  "test must simulate a real already-debited station item")
game.tick=interrupted.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and interrupted.status=="active"
  and interrupted.phase=="interrupted-build-item-physically-refunded"
  and interrupted.build_due_tick==nil
  and created_cargo[7].stock==1 and ghost.valid
  and not physical and stock==0,
  "interrupted debit was lost, duplicated or prematurely built")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and interrupted.phase=="building-ghost")
game.tick=interrupted.build_due_tick
local resumed=Expansion.service_station_expansion_assignment(pair)
print("[resource-station-cargo-recovery-0827] observed result="..tostring(resumed)
  .." status="..tostring(interrupted.status)
  .." phase="..tostring(interrupted.phase)
  .." built="..tostring(built_count)
  .." physical="..tostring(physical and physical.valid)
  .." hold="..tostring(created_cargo[7].stock)
  .." hold_valid="..tostring(created_cargo[7].valid)
  .." ghost_valid="..tostring(ghost.valid))
assert(resumed
  and interrupted.status=="complete" and physical and physical.valid
  and stock==0 and not created_cargo[7].valid
  and not ghost.valid and built_count==6,
  "interrupted physical cargo did not build exactly one station")
print("[resource-station-cargo-recovery-0827] PASS interrupted build debit, physical refund and single successful retry")
-- A same-prototype ghost at the same coordinates is NOT the one owned by
-- this writ if its physical entity identity differs. The executor must
-- refuse to debit stock or build at the impostor's site.
physical=nil
ghost=nil
stock=1
priest.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:iron-ore",nil,"reject-impostor-ghost",0))
local impostor_writ=storage.tech_priests.station_expansion_0256[8]
assert(impostor_writ and impostor_writ.status=="active"
  and ghost and ghost.valid and impostor_writ.ghost_unit==ghost.unit_number)
local original_ghost_unit=ghost.unit_number
local builds_before_impostor=built_count
local holds_before_impostor=#created_cargo
ghost.unit_number=original_ghost_unit+1000
assert(not Expansion.service_station_expansion_assignment(pair)
  and impostor_writ.status=="failed"
  and stock==1 and built_count==builds_before_impostor
  and #created_cargo==holds_before_impostor,
  "same-position impostor ghost consumed an item or caused a station build")
ghost.valid=false
print("[resource-station-ghost-identity-0823] PASS no cargo debit or construction for unreserved physical ghost")

-- A missing owned ghost cannot be reconstructed by claiming a different
-- ghost at the same site while a real station item is carried.
physical=nil
ghost=nil
foreign_ghost.valid=false
stock=1
priest.position={x=0,y=0}
game.tick=game.tick+60
assert(Expansion.request_station_expansion(
  pair,"resource:iron-ore",nil,"carried-item-foreign-ghost",0))
local carried_writ=storage.tech_priests.station_expansion_0256[9]
local owned_ghost=ghost
local holds_before=#created_cargo
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and carried_writ.status=="active"
  and stock==0 and #created_cargo==holds_before+1
  and created_cargo[holds_before+1].stock==1,
  "test must begin with one physically carried station item")
owned_ghost.valid=false
foreign_ghost={valid=true,name="entity-ghost",ghost_name="senior-cogitator-station",
  position={x=owned_ghost.position.x,y=owned_ghost.position.y},
  unit_number=owned_ghost.unit_number+1000,force=force,surface=surface}
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and carried_writ.phase=="ghost-missing-with-physical-custody"
  and carried_writ.ghost_unit==owned_ghost.unit_number
  and foreign_ghost.valid and stock==0
  and created_cargo[holds_before+1].stock==1,
  "foreign ghost must not consume or acquire carried station cargo")
foreign_ghost.valid=false
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and ghost and ghost.valid and ghost~=owned_ghost
  and carried_writ.ghost_unit==ghost.unit_number
  and stock==0 and created_cargo[holds_before+1].stock==1,
  "vacated site must allow a new owned ghost without new station items")
print("[resource-station-ghost-site-0256] PASS occupied sites denied and carried item conserved")





