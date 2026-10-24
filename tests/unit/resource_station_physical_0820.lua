-- Exercise the ACTUAL 0256 expansion executor with an existing inventory
-- and a new real-style on_built pair registration. No free station item.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local surface={index=1}
local force={name="player"}
local ghost,physical
local built_count=0
local fail_next_build=false
local throw_after_build=false
surface.can_place_entity=function(_)return true end
surface.find_entities_filtered=function(filters)
  if filters.name=="entity-ghost" then
    return ghost and ghost.valid and {ghost} or {}
  end
  if filters.name=="senior-cogitator-station" then
    return physical and physical.valid and {physical} or {}
  end
  return {}
end
surface.create_entity=function(args)
  if args.name=="entity-ghost" then
    ghost={valid=true,name="entity-ghost",
      position=args.position,ghost_name=args.inner_name,unit_number=801,
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
assert(Expansion.allowed_station_item_for_pair(pair)=="senior-cogitator-station")
local requested=Expansion.request_station_expansion(
  pair,"resource:iron-ore",nil,"known-patch-east",0)
local rec=storage.tech_priests.station_expansion_0256[1]
assert(requested and rec and rec.status=="active"
  and rec.requester_station_unit==200 and rec.worker_station_unit==200
  and rec.required_worker_rank==3 and rec.commander_bootstrap
  and ghost and ghost.valid
  and not physical and stock==0,
  "Magos with no existing Senior failed to reserve a real lower-rank ghost")
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
