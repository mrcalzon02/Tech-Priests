-- Exercise the ACTUAL 0256 expansion executor with an existing inventory
-- and a new real-style on_built pair registration. No free station item.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local surface={index=1}
local force={name="player"}
local ghost,physical
local built_count=0
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
    physical={valid=true,name=args.name,position=args.position,
      unit_number=802,force=force,surface=surface}
    built_count=built_count+1
    return physical
  end
  error("unexpected create_entity "..tostring(args.name))
end
game={tick=100}
local station={valid=true,unit_number=200,
  name="planetary-magos-cogitator-station",position={x=0,y=0},
  force=force,surface=surface}
local priest={valid=true,position={x=0,y=0}}
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
local inventory={
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
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and acquisition_requests==1 and built_count==0
  and stock==0 and ghost.valid,
  "missing station item was fabricated rather than physically requested")
stock=1 -- Physically stocked fixture after a real acquisition path.
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and movement_orders==1 and rec.phase=="moving-to-ghost"
  and stock==1 and not physical,"station built before reaching ghost")
game.tick=game.tick+60
assert(Expansion.service_station_expansion_assignment(pair)
  and rec.phase=="building-ghost"
  and stock==1 and rec.build_due_tick>game.tick,
  "ghost placement bypassed the physical construction delay")
game.tick=rec.build_due_tick
assert(Expansion.service_station_expansion_assignment(pair)
  and stock==0 and built_count==1
  and rec.status=="complete" and paired==1
  and physical and physical.valid and not ghost.valid
  and storage.tech_priests.pairs_by_station[802].station==physical
  and storage.tech_priests.station_expansion_by_worker_0256[200]==nil,
  "lower rank child not physically built, paired, or accounted for")
print("[resource-station-physical-0820] PASS commander-built ghost, exact inventory, new paired Senior")
