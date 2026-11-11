-- scripts/core/construction_planner.lua
-- Tech Priests 0.1.674-dev recovery.
-- Sole physical construction owner. Broker work is discovery only; the pure action
-- classifier recommends cached work and single_dispatcher_0510 alone executes it.

-- 0822 owns the persisted physical-recycling reservation. A reserved
-- leaf may not receive a NEW 0338 construction duty during evacuation.
-- Already-active physical cargo/tasks continue under their original owner.
local Recycling0822=require("scripts.core.station_recycling_0822")
local M={version="0.1.674-dev",storage_key="construction_planner",discovery_interval=233,max_pairs_per_discovery=6,move_priority=968,move_ttl=60*12,reservation_ttl=60*20,request_timeout=60*20,travel_ticks_per_tile=20,max_travel_extra_ticks=60*120,max_ground_detour_extra_ticks=60*60,pickup_reach_sq=2.56,build_reach_sq=4,return_reach_sq=2.56,dispatcher_owned=true,discovery_only_broker=true,positional_reservation=true,exact_item_custody=true}
-- Original 0836 rail requests must not hold 0338 indefinitely without
-- a real source item. The 0338 physical builder, not the observer, owns
-- task admission and this finite no-custody refusal.
M.rail_source_wait_ticks_0836=60*120
-- An original 0836 rail may lie 650 tiles east while all REAL rail stock
-- remains at its Magos station. The same priest must walk back to stock and
-- then out to the segment. Keep a bounded rail-only travel budget; never
-- extend the standard construction deadline or bypass movement/item custody.
M.rail_max_travel_extra_ticks_0836=60*600
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return math.huge end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function within_entity_reach(position,entity,limit_sq)
 if not(position and valid(entity))then return false end
 -- Factorio reports the entity box in world coordinates. A priest beside a
 -- large station can legitimately reach its inventory while remaining more
 -- than one tile from the station's center.
 local ok,box=pcall(function()return entity.selection_box or entity.bounding_box end)
 if ok and box then
  local lt=box.left_top or box[1];local rb=box.right_bottom or box[2]
  if lt and rb and type(lt.x)=="number"and type(lt.y)=="number"
   and type(rb.x)=="number"and type(rb.y)=="number"then
   local x=math.max(math.min(lt.x,rb.x),math.min(math.max(lt.x,rb.x),position.x))
   local y=math.max(math.min(lt.y,rb.y),math.min(math.max(lt.y,rb.y),position.y))
   return dist_sq(position,{x=x,y=y})<=limit_sq
  end
 end
 return dist_sq(position,entity.position)<=limit_sq
end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,dispatcher_owned=true,discovery_only_broker=true,positional_reservation=true,exact_item_custody=true,stats={},recent={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version
 if r.enabled==nil then r.enabled=true end;r.dispatcher_owned=true;r.discovery_only_broker=true;r.positional_reservation=true;r.exact_item_custody=true;r.stats=r.stats or{};r.recent=r.recent or{};r.cursor=tonumber(r.cursor)or 0;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(pair,action,detail)local r=M.root();local ev={tick=now(),station=safe(station_unit(pair)),action=tostring(action or"event"),detail=tostring(detail or"")};r.recent[#r.recent+1]=ev;while #r.recent>160 do table.remove(r.recent,1)end;if pair then pair.construction_last_event_0338=ev end end
local function site_planner()return rawget(_G,"TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359")or package.loaded["scripts.core.construction_site_planner"]end
local function storage_authority()return rawget(_G,"TechPriestsStorageRoleAuthority0686")or package.loaded["scripts.core.storage_role_authority_0686"]end
local function reservations_module()
 local r=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"];if not r then local ok,m=pcall(require,"scripts.core.work_reservations");if ok then r=m end end;return r
end
local function ensure_reservation_category()
 local r=reservations_module();if not r then return nil end;local category="construction-placement";local found=false;for _,v in ipairs(r.categories or{})do if v==category then found=true break end end;if not found then r.categories=r.categories or{};r.categories[#r.categories+1]=category end
 local state=type(r.root)=="function"and r.root()or nil;if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end;return r
end
local function position_target(pair,pos)return{position={x=pos.x,y=pos.y},surface_index=pair.station.surface.index,force_index=pair.station.force.index}end
local function claim_site(pair,task)
 local r=ensure_reservation_category();if not(r and type(r.claim)=="function"and task.position)then return false,"reservation-unavailable"end;task.reservation_target=position_target(pair,task.position)
 local ok,why=r.claim("construction-placement",task.reservation_target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family="construction",entity_name=task.entity_name,item=task.item_name,source="construction-planner-0338"});task.reserved_0338=ok==true;return ok==true,why
end
local function release_site(pair,task)
 if not(task and task.reservation_target)then return false end;local r=reservations_module();if r and type(r.release)=="function"then local ok,v=pcall(r.release,"construction-placement",task.reservation_target,pair);return ok and v==true end;return false
end
local function request_move_position(pair,pos,reason,radius)
 if not(valid_pair(pair)and pos)then return false end;local f=rawget(_G,"tech_priests_request_movement_0418");if type(f)~="function"then return false end
 local ok,accepted=pcall(f,pair,pos,reason,{owner="construction-planner-0338",priority=M.move_priority,ttl=M.move_ttl,radius=radius or 1.5,distraction=defines and defines.distraction and defines.distraction.none or nil});return ok and accepted==true
end
local function source_approach_position(pair,entity,margin,avoid_station)
 if not(valid_pair(pair)and valid(entity))then return nil end
 local ok,box=pcall(function()return entity.selection_box end)
 if not(ok and box)then
  ok,box=pcall(function()return entity.bounding_box end)
 end
 if not(ok and box)then return entity.position end
 local lt=box.left_top or box[1];local rb=box.right_bottom or box[2]
 if not(lt and rb and lt.x and lt.y and rb.x and rb.y)then return entity.position end
 local x0,x1=math.min(lt.x,rb.x),math.max(lt.x,rb.x)
 local y0,y1=math.min(lt.y,rb.y),math.max(lt.y,rb.y)
 local p=pair.priest.position
 local clamp=function(v,a,b)return math.max(a,math.min(b,v))end
 -- The center of a multi-tile station cannot be entered. Request a reachable
 -- external service point at the closest side, inside inventory reach.
 local gap=math.max(0.3,tonumber(margin)or 0.6)
 local points={
  {x=x0-gap,y=clamp(p.y,y0,y1)},
  {x=x1+gap,y=clamp(p.y,y0,y1)},
  {x=clamp(p.x,x0,x1),y=y0-gap},
  {x=clamp(p.x,x0,x1),y=y1+gap},
 }
 local best,score=nil,math.huge
 for _,point in ipairs(points)do
  -- Ghost retry standoffs must be on the exterior side of the building,
  -- away from the Cogitator footprint. Choosing the closest point to the
  -- priest can lead straight into the station's impassable collision box.
  local d=avoid_station and -dist_sq(pair.station.position,point)
    or dist_sq(p,point)
  if d<score then best=point;score=d end
 end
 return best
end
local function request_move(pair,target,reason)
 if not valid(target)then return false end
 local dest=source_approach_position(pair,target)
 return request_move_position(pair,dest or target.position,reason,dest and 0.5 or 1.5)
end
local function item_count(inv,item)if not(inv and inv.valid and item)then return 0 end;local ok,n=pcall(function()return inv.get_item_count(item)end);return ok and(tonumber(n)or 0)or 0 end
local function remove_item(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,n=pcall(function()return inv.remove({name=item,count=count})end);return ok and(tonumber(n)or 0)or 0 end
local function insert_item(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,n=pcall(function()return inv.insert({name=item,count=count})end);return ok and(tonumber(n)or 0)or 0 end
local function generic_source_allowed(pair,src)
 local e=src and src.entity;local inv=src and src.inv;if not(inv and inv.valid and valid(e))then return false end;if e.surface~=pair.station.surface or e.force~=pair.station.force then return false end;if e==pair.station then return true end;return e.type=="container"or e.type=="logistic-container"or e.type=="car"or e.type=="spider-vehicle"
end
local function home_sources(pair)
 local out,seen={},{}
 local function add(src)
  if not generic_source_allowed(pair,src) then return end
  -- 1200: LuaInventory's printable description is not an inventory ID:
  -- distinct physical chests can have the same tostring() representation.
  -- Deduplicate by the actual container unit or, without a unit, its
  -- LuaEntity identity. The old string key discarded stocked supply chests
  -- immediately after reading an empty Cogitator inventory.
  local entity=src.entity
  local key=entity.unit_number and ("unit:"..tostring(entity.unit_number))
    or entity
  if seen[key] then return end
  seen[key]=true
  out[#out+1]={inv=src.inv,entity=entity,
    label=src.source or src.inventory_id or "generic-home-source"}
 end
 -- 1243: Use exactly the same canonical 0686 container sources as
 -- infrastructure-first stock counting. A source survey is read-only:
 -- calling the steward's inventory-flush entry point during a recommendation
 -- could move another owner's real items before 0338 begins its transaction.
 local authority=storage_authority()
 if authority and type(authority.generic_storage_sources)=="function" then
  local ok,sources=pcall(authority.generic_storage_sources,pair)
  if ok and type(sources)=="table" then
   for _,src in ipairs(sources) do add(src) end
  end
 else
  -- Legacy unit fixtures that only mock the old station/steward APIs.
  if authority and type(authority.generic_station_inventories)=="function" then
   local ok,sources=pcall(authority.generic_station_inventories,pair)
   if ok and type(sources)=="table" then
    for _,src in ipairs(sources) do add(src) end
   end
  end
  local steward=rawget(_G,"tech_priests_inventory_steward_sources_for_pair")
  if type(steward)=="function" then
   local ok,sources=pcall(steward,pair)
   if ok and type(sources)=="table" then
    for _,src in ipairs(sources) do add(src) end
   end
  end
 end
 return out
end
-- A rail-loading journey may leave REAL item stacks in a persistent,
-- engine-owned inventory carried by the ORIGINAL Magos. This is physical
-- 0338 supply custody, not a virtual rail counter or an alternate builder.
-- Only the original live 0836 request may ever draw from this protected hold.
local function original_rail_cargo_0836(pair,item)
 if item~="rail" or not valid_pair(pair) then return nil,false end
 local mission=pair.remote_rail_outpost_0835
 local pending=mission and mission.pending_rail_0836
 local request=pair.construction_request
 if not(pending and pending.request==request and type(request)=="table"
   and request.site_reason=="remote-rail-physical-frontier-0836"
   and request.item_name=="rail" and request.entity_name=="straight-rail"
   and mission.root_station_unit==pair.station.unit_number
   and mission.surface_index==pair.station.surface.index
   and mission.force_index==pair.station.force.index)then
  return nil,false
 end
 local held=pair.rail_material_cargo_0836
 if not held then return nil,false end
 if type(held)~="table" or held.quarantine
   or not(held.inventory and held.inventory.valid)
   or held.station_unit~=pair.station.unit_number
   or held.priest_unit~=pair.priest.unit_number
   or held.surface_index~=pair.station.surface.index
   or held.force_index~=pair.station.force.index then
  return nil,true
 end
 return held,false
end
local function source_for_item(pair,item)
 local held,invalid=original_rail_cargo_0836(pair,item)
 if invalid then return nil end -- preserve lost/ambiguous physical custody
 if held and item_count(held.inventory,"rail")>0 then
  return {item_name="rail",count=item_count(held.inventory,"rail"),
    inv=held.inventory,entity=pair.priest,
    label="engine-carried-original-rail-0836",score=-math.huge}
 end
 local best;for _,src in ipairs(home_sources(pair))do local count=item_count(src.inv,item);if count>0 then local score=dist_sq(pair.priest.position,src.entity.position)-math.min(count,100);if not best or score<best.score then best={item_name=item,count=count,inv=src.inv,entity=src.entity,label=src.label,score=score}end end end;return best
end
local function entity_exists(name)return type(name)=="string"and name~=""and prototypes and prototypes.entity and prototypes.entity[name]~=nil end
local function item_exists(name)return type(name)=="string"and name~=""and prototypes and prototypes.item and prototypes.item[name]~=nil end
local function place_result(item_name)local item=item_exists(item_name)and prototypes.item[item_name]or nil;local result;if item then pcall(function()result=item.place_result end)end;return result and result.name or nil end
local function item_for_entity(entity_name)
 if not entity_exists(entity_name)then return nil end;local policy=rawget(_G,"TechPriestsPlanningConstraints0646")or package.loaded["scripts.core.planning_constraints_0646"];if policy and type(policy.item_for_entity)=="function"then local ok,item=pcall(policy.item_for_entity,entity_name);if ok and item then return item end end
 for name,item in pairs(prototypes and prototypes.item or{})do local result;pcall(function()result=item.place_result end);if result and result.name==entity_name then return name end end;return nil
end
local function entity_type(name)local p=entity_exists(name)and prototypes.entity[name]or nil;local typ;if p then pcall(function()typ=p.type end)end;return typ end
local function category_for(entity_name,requested)
 local typ=entity_type(entity_name);if requested and requested~=""and requested~="generic"then return requested end;if typ=="mining-drill"then return"miner"end;if typ=="furnace"then return"furnace"end;if typ=="assembling-machine"then return"assembler"end;if typ=="container"or typ=="logistic-container"then return"storage"end;if typ=="lab"then return"lab"end;if typ=="electric-pole"then return"emergency-power-pole"end;if typ=="roboport"then return"defense-roboport"end;if typ=="wall"or typ=="gate"then return"defense-wall"end;if typ=="artillery-turret"then return"defense-artillery"end;if typ=="ammo-turret"or typ=="electric-turret"or typ=="fluid-turret"then return"defense-turret"end;if typ=="radar"then return"defense-radar"end;if typ=="land-mine"then return"defense-mine"end;return"generic"
end
local function normalize_placeable(v)
 if type(v)=="string"then if item_exists(v)then local e=place_result(v);return e and{item_name=v,entity_name=e,category=category_for(e)}or nil end;if entity_exists(v)then local item=item_for_entity(v);return item and{item_name=item,entity_name=v,category=category_for(v)}or nil end;return nil end
 if type(v)~="table"then return nil end;local item=v.item_name or v.item or v.name;local entity=v.entity_name or v.entity or v.place_result;if entity and type(entity)=="table"then entity=entity.name end;if not entity and item then entity=place_result(item)end;if not item and entity then item=item_for_entity(entity)end;if not(item_exists(item)and entity_exists(entity))then return nil end;return{item_name=item,entity_name=entity,category=category_for(entity,v.category or v.class),source=v.source,direction=v.direction}
end
local request_fields={"structure_construction_requested_item","construction_requested_item","construction_request","pending_construction","build_request"}
local function bootstrap_request(pair)
 local rec=pair and pair.construction_bootstrap_ghost_0645;if type(rec)~="table"then return nil end;local ghost=valid(rec.ghost)and rec.ghost or nil;if not ghost and rec.position and valid_pair(pair)then local ok,e=pcall(pair.station.surface.find_entity,pair.station.surface,"entity-ghost",rec.position);if ok and valid(e)then ghost=e end end
 local placeable=normalize_placeable({item_name=rec.item,entity_name=rec.entity_name,category=rec.category or rec.class,source="construction-bootstrap-ghost-0645",direction=rec.direction});if not placeable or not rec.position then return nil end;return{field="construction_bootstrap_ghost_0645",value=rec,placeable=placeable,position={x=rec.position.x,y=rec.position.y},ghost=ghost,site_reason="bootstrap-ghost",effectiveness=rec.effectiveness}
end
-- An unfunded, unstarted bootstrap candidate must not monopolize the sole
-- priest builder indefinitely when a physically stocked frontier needs it.
-- Keep the original bootstrap request intact for later; never preempt any
-- active task, real cargo, funded request, robot custody or remote drill.
function M.yield_unfunded_frontier_candidate_0338(pair)
 if not valid_pair(pair) then return false,"invalid-pair" end
 if pair.construction_task_0338 or pair.construction_custody_0338
   or pair.robot_network_task_0338 or pair.robot_network_request_0338
   or pair.remote_drill_request_1011 or pair.construction_request
   or pair.construction_task then
  return false,"active-construction-or-priority-custody"
 end
 local bootstrap=bootstrap_request(pair)
 if bootstrap and source_for_item(pair,bootstrap.placeable.item_name) then
  return false,"funded-bootstrap-request"
 end
 for _,field in ipairs({"structure_construction_requested_item",
     "construction_requested_item"}) do
  local v=pair[field]
  local placeable=v and normalize_placeable(v)
  if placeable and source_for_item(pair,placeable.item_name) then
   return false,"funded-earlier-request:"..field
  end
 end
 local candidate=pair.construction_candidate_0338
 if not candidate then return true,"no-active-candidate" end
 if type(candidate)~="table" or type(candidate.item_name)~="string" then
  return false,"unidentified-construction-candidate"
 end
 if source_for_item(pair,candidate.item_name) then
  return false,"funded-construction-candidate"
 end
 -- Discovery candidates reserve no physical item or site. A subsequent
 -- 0338 discovery reconstructs this unchanged request after the frontier.
 pair.construction_candidate_0338=nil
 stat("unfunded_frontier_candidate_yields")
 record(pair,"unfunded-candidate-yielded-to-frontier",candidate.item_name)
 return true,"unfunded-candidate-yielded"
end
-- The original 1076 Magos may delegate a physical build only to its
-- still-live, directly paired rank-3 Senior on the same force/surface.
-- Revalidate that exact edge inside 0338 too: 0488's recommendation is
-- read-only and is not sufficient authority to prioritize construction.
-- Only the exact original Magos 0836 pending rail may use the 0338
-- item-carrying builder. A claimed rail marker is not item authority.
local function owned_pending_rail_0836(pair,request)
 local mission=pair and pair.remote_rail_outpost_0835
 local pending=mission and mission.pending_rail_0836
 local route=mission and mission.rail_frontier_0836
 local station=pair and pair.station
 local priest=pair and pair.priest
 local point=request and request.position
 return type(request)=="table" and valid_pair(pair)
   and station.name=="planetary-magos-cogitator-station"
   and station.force and station.surface
   and priest.force==station.force and priest.surface==station.surface
   and type(mission)=="table"
   and mission.status=="building-physical-rail"
   and mission.root_station_unit==station.unit_number
   and mission.force_index==station.force.index
   and mission.surface_index==station.surface.index
   and type(route)=="table" and type(route.segment)=="number"
   and type(pending)=="table" and type(pending.position)=="table"
   and pending.request==request and pair.construction_request==request
   and request.rail_mission_station_unit_0836==station.unit_number
   and request.rail_segment_0836==route.segment+1
   and pending.segment==request.rail_segment_0836
   and request.item_name=="rail" and request.entity_name=="straight-rail"
   and request.site_reason=="remote-rail-physical-frontier-0836"
   and point and point.x==pending.position.x
   and point.y==pending.position.y
   and request.direction==pending.direction
end
-- 0836 rail discovery is not material authority. Recheck the original live
-- pending Magos request before admitting a cached 0338 candidate and at
-- each subsequent physical-custody step. No replacement rail mission may
-- inherit a stale original rail's construction item or movement lease.
local function marked_rail_request_0836(candidate)
 local request=type(candidate)=="table" and candidate.request_value
 return type(candidate)=="table" and (
   candidate.site_reason=="remote-rail-physical-frontier-0836"
   or (type(request)=="table" and (
     request.rail_segment_0836~=nil
     or request.site_reason=="remote-rail-physical-frontier-0836"
     -- A paid locomotive uses the same original Magos marker, but is
     -- NOT a track segment. Every other forged 0836 marker still fails
     -- the original pending-rail ownership check.
     or (request.rail_mission_station_unit_0836~=nil
       and not((request.site_reason=="original-first-locomotive-0836"
          and request.item_name=="locomotive"
          and request.entity_name=="locomotive")
          or (request.site_reason=="original-first-wagon-0836"
          and request.item_name=="cargo-wagon"
          and request.entity_name=="cargo-wagon"))))))
end
local function authorized_rail_candidate_0836(pair,candidate)
 local request=candidate and candidate.request_value
 return type(candidate)=="table"
   and candidate.request_field=="construction_request"
   and candidate.site_reason=="remote-rail-physical-frontier-0836"
   and candidate.item_name=="rail"
   and candidate.entity_name=="straight-rail"
   and type(request)=="table"
   and type(request.position)=="table"
   and type(candidate.position)=="table"
   and candidate.position.x==request.position.x
   and candidate.position.y==request.position.y
   and candidate.direction==request.direction
   and owned_pending_rail_0836(pair,request)
end
-- Load a modest REAL rail stack only at the original 0338 source pickup.
-- Each later construction still removes exactly ONE rail from an actual
-- LuaInventory, retains the ordinary cargo lease, builds with 0338 and
-- requires the unweakened 0836 native unit/graph receipt. The one-slot
-- LuaInventory survives save/reload; other tasks/storage cannot spend it.
-- Any ambiguous debit/refund remains physically quarantined, never minted.
local function stage_original_rail_supply_0836(pair,task)
 if not authorized_rail_candidate_0836(pair,task) then return true end
 local existing=pair.rail_material_cargo_0836
 if existing then
  -- Keep persistent REAL rail cargo. A depleted hold may be refilled only
  -- after a genuine return to stocked source inventory; a stale/mismatched
  -- or quarantined hold must never be silently replaced.
  if type(existing)~="table" or existing.quarantine
    or not(existing.inventory and existing.inventory.valid)
    or existing.station_unit~=pair.station.unit_number
    or existing.priest_unit~=pair.priest.unit_number
    or existing.surface_index~=pair.station.surface.index
    or existing.force_index~=pair.station.force.index then
   record(pair,"rail-restage-refused-0836","custody-invalid-or-mismatched")
   return false
  end
  -- Last item just debited from this hold is already in 0338 task custody.
  -- Do not transfer or restage it remotely; next stock must come from a
  -- physical source the Magos actually reaches.
  if item_count(existing.inventory,"rail")>0
    or task.source_inv==existing.inventory then return true end
 end
 if not(game and type(game.create_inventory)=="function"
   and task.source_inv and task.source_inv.valid
   and valid(task.source_entity) and task.source_entity.unit_number)then
  return true -- normal one-item construction path remains authoritative
 end
 local source=task.source_inv
 local before=item_count(source,"rail")
 -- The verified native corridor needed another distant supply run after
 -- the original seven-rail hold. Bound the next physical pickup by ONE
 -- complete native rail stack (maximum 100) and its REAL prototype capacity,
 -- reserving one item in original source inventory. Every item remains
 -- physically sourced and individually debited when built.
 -- Every built segment still consumes ONE counted rail from this LuaInventory.
 local prototype=prototypes and prototypes.item and prototypes.item["rail"]
 local stack_capacity=prototype and tonumber(prototype.stack_size) or 0
 local amount=math.min(100,math.max(0,before-1),math.max(0,stack_capacity))
 if amount<1 then return true end
 local inventory=existing and existing.inventory or nil
 if not inventory then
  local ok,created=pcall(function()return game.create_inventory(1)end)
  if not ok then return true end
  inventory=created
 end
 if not(inventory and inventory.valid
   and item_count(inventory,"rail")==0)then
  record(pair,"rail-restage-refused-0836","native-hold-not-empty")
  return false
 end
 local held=existing or {inventory=inventory,
   station_unit=pair.station.unit_number,
   priest_unit=pair.priest.unit_number,
   surface_index=pair.station.surface.index,
   force_index=pair.station.force.index,
   origin_unit=task.source_entity.unit_number,
   loaded_tick=now(),loaded_count=0}
 if not existing then
  pair.rail_material_cargo_0836=held -- persist authority BEFORE real transfer
 end
 local removed=remove_item(source,"rail",amount)
 local inserted=insert_item(inventory,"rail",removed)
 local uninserted=removed-inserted
 local refunded=uninserted>0 and insert_item(source,"rail",uninserted) or 0
 local source_after=item_count(source,"rail")
 local held_after=item_count(inventory,"rail")
 held.loaded_count=held_after
 held.loaded_tick=now()
 held.origin_unit=task.source_entity.unit_number
 if source_after~=before-removed+refunded
   or held_after~=inserted or refunded~=uninserted
   or removed~=inserted+refunded
   or held_after>amount then
  held.quarantine="rail-stage-physical-custody-ambiguous"
  record(pair,"rail-stage-quarantined-0836",held.quarantine)
  return false
 end
 held.restock_cycles_0836=(tonumber(held.restock_cycles_0836)or 0)
   +(existing and 1 or 0)
 record(pair,"rail-stage-native-cargo-0836",
   "source="..safe(held.origin_unit).." native_held="..safe(held_after)..
   " original_source_before="..safe(before)..
   " original_source_after="..safe(source_after))
 return true
end
-- Exact post-audit locomotive ownership. This request cannot borrow a rail
-- segment's receipt or run under a different Magos, surface or item.
local function owned_pending_locomotive_0836(pair,request)
 local mission=pair and pair.remote_rail_outpost_0835
 local state=mission and mission.first_locomotive_0836
 local route=mission and mission.rail_frontier_0836
 local station=pair and pair.station
 local priest=pair and pair.priest
 local point=request and request.position
 return type(request)=="table" and valid_pair(pair)
   and station.name=="planetary-magos-cogitator-station"
   and priest.force==station.force and priest.surface==station.surface
   and mission.status=="rail-track-established"
   and mission.root_station_unit==station.unit_number
   and mission.force_index==station.force.index
   and mission.surface_index==station.surface.index
   and route and route.chain_audit_completed_tick_0836
   and type(route.built_units)=="table"
   and route.segment==#route.built_units and route.segment>=16
   and state and state.phase=="awaiting-original-0338"
   and state.request==request and pair.construction_request==request
   and request.rail_mission_station_unit_0836==station.unit_number
   and request.site_reason=="original-first-locomotive-0836"
   and request.item_name=="locomotive" and request.entity_name=="locomotive"
   and point and state.position and point.x==state.position.x
   and point.y==state.position.y and request.direction==route.direction
end
local function owned_pending_wagon_0836(pair,request)
 local mission=pair and pair.remote_rail_outpost_0835
 local state=mission and mission.first_wagon_0836
 local route=mission and mission.rail_frontier_0836
 local station=pair and pair.station
 local priest=pair and pair.priest
 local point=request and request.position
 return type(request)=="table" and valid_pair(pair)
   and station.name=="planetary-magos-cogitator-station"
   and priest.force==station.force and priest.surface==station.surface
   and mission.status=="rail-track-established"
   and mission.root_station_unit==station.unit_number
   and mission.force_index==station.force.index
   and mission.surface_index==station.surface.index
   and route and route.chain_audit_completed_tick_0836
   and type(route.built_units)=="table"
   and route.segment==#route.built_units and route.segment>=16
   and mission.first_locomotive_0836
   and mission.first_locomotive_0836.phase=="native-paid-locomotive-verified"
   and valid(mission.first_locomotive_0836.built_entity)
   and mission.first_locomotive_0836.built_entity.train
   and mission.first_locomotive_0836.built_entity.train.valid
   and state and state.phase=="awaiting-original-0338"
   and state.request==request and pair.construction_request==request
   and request.rail_mission_station_unit_0836==station.unit_number
   and request.site_reason=="original-first-wagon-0836"
   and request.item_name=="cargo-wagon" and request.entity_name=="cargo-wagon"
   and point and state.position and point.x==state.position.x
   and point.y==state.position.y and request.direction==route.direction
end
local function frontier_owned_by_pair_0338(pair,request)
 if not(type(request)=="table" and valid_pair(pair))then return false end
 local unit=station_unit(pair)
 if request.site_reason=="original-first-locomotive-0836" then
  return owned_pending_locomotive_0836(pair,request)
 end
 if request.site_reason=="original-first-wagon-0836" then
  return owned_pending_wagon_0836(pair,request)
 end
 if request.rail_mission_station_unit_0836~=nil
   or request.site_reason=="remote-rail-physical-frontier-0836" then
  return owned_pending_rail_0836(pair,request)
 end
 if request.frontier_root_unit_1076==unit then
  return request.frontier_builder_unit_1076==nil
    or request.frontier_builder_unit_1076==unit
 end
 if request.frontier_builder_unit_1076~=unit then return false end
 local root=pair_map()[request.frontier_root_unit_1076]
 local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
 if not(valid_pair(root)
   and root.station.name=="planetary-magos-cogitator-station"
   and root.station.force==pair.station.force
   and root.station.surface==pair.station.surface
   and hierarchy and type(hierarchy.rank)=="function"
   and type(hierarchy.is_direct_subordinate)=="function")then
  return false
 end
 local ok,allowed=pcall(function()
  return hierarchy.rank(root)==4 and hierarchy.rank(pair)==3
    and hierarchy.is_direct_subordinate(root,pair)==true
 end)
 return ok and allowed==true
end
-- 1203: Check actual same-force local emergency machinery before letting
-- a stale bootstrap ghost consume another item. Other SPM machine requests
-- retain their intentional ability to add industrial capacity.
local function existing_bootstrap_smelter_1203(pair)
 if not valid_pair(pair)then return nil end
 local station=pair.station
 local ok,found=pcall(function()
  return station.surface.find_entities_filtered{
   name="tech-priests-emergency-smelter",
   position=station.position,radius=22,force=station.force,limit=16}
 end)
 if not(ok and type(found)=="table")then return nil end
 for _,entity in ipairs(found)do
  if valid(entity)and entity.name=="tech-priests-emergency-smelter"
    and entity.force==station.force and entity.surface==station.surface
    and entity.position and dist_sq(entity.position,station.position)<=22*22
  then return entity end
 end
 return nil
end
-- The completed one-time starter can also satisfy older direct build requests.
local function retire_unclaimed_starter_request_1205(pair,request)
 if not(request and request.placeable
   and request.placeable.entity_name=="tech-priests-emergency-smelter"
   and existing_bootstrap_smelter_1203(pair)) then return false end
 if request.field~="construction_bootstrap_ghost_0645"
   and pair[request.field]==request.value then pair[request.field]=nil end
 pair.construction_candidate_0338=nil
 record(pair,"bootstrap-smelter-request-already-physical-1205",request.field)
 return true
end
-- 1258: an existing 0691 pipe route may use 0338 only after checking
-- its live exact tile, station domain and real pipe source. This grants no
-- items, no free movement and no ownership of an incumbent 0338 task.
local function funded_fluid_pipe_1258(pair)
 local req=pair and pair.construction_request
 local plan=pair and pair.standard_fluid_route_plan_0691
 if not(type(req)=="table"and req.source=="standard-fluid-route-0691"
   and req.item_name=="pipe"and req.entity_name=="pipe"
   and type(plan)=="table"and plan.state=="construction-requested"
   and req.route_plan_id==plan.id and req.route_direction==plan.direction
   and type(req.position)=="table")then return nil end
 local index=tonumber(plan.current_index)
 local tile=index and plan.tiles and plan.tiles[index]
 if not(tile and tonumber(req.route_index)==index
   and req.position.x==tile.x and req.position.y==tile.y)then return nil end
 if not(valid(plan.machine)and plan.machine.force==pair.station.force
   and plan.machine.surface==pair.station.surface)then return nil end
 local remote=plan.remote and plan.remote.entity
 if not(valid(remote)and remote.force==pair.station.force
   and remote.surface==pair.station.surface)then return nil end
 local item=normalize_placeable(req)
 if not(item and item.item_name=="pipe"and item.entity_name=="pipe"
   and source_for_item(pair,"pipe"))then return nil end
 return req,item
end
-- An EXACT unfunded/unplaceable local miner cannot indefinitely block an
-- already-issued original 0836 paid rail. Consult ONLY the original 0338
-- failed physical site receipt for the SAME original construction request.
-- Its real inventory, order and future retry remain untouched. No active
-- builder, returned item, robot task or foreign mission may be displaced.
local function blocked_local_miner_yields_to_rail_0836(pair,field,value)
 local refusal=pair and pair.construction_site_refusal_0338
 local rail=pair and pair.construction_request
 local authorized=(owned_pending_rail_0836(pair,rail)
     and source_for_item(pair,"rail")~=nil)
   or (owned_pending_locomotive_0836(pair,rail)
     and source_for_item(pair,"locomotive")~=nil)
   or (owned_pending_wagon_0836(pair,rail)
     and source_for_item(pair,"cargo-wagon")~=nil)
 local at=refusal and tonumber(refusal.tick)
 local item=value and normalize_placeable(value)
 local explicit_site=type(value)=="table"
   and (value.position or value.site_position)
 return field=="construction_requested_item" and value~=nil
   and type(refusal)=="table"
   and refusal.field==field and refusal.request==value
   and refusal.reason=="no-miner-site"
   and at and at<=now() and now()-at<=600
   and not explicit_site and item
   and entity_type(item.entity_name)=="mining-drill"
   and authorized
   and not(pair.construction_task_0338
     or pair.construction_custody_0338 or pair.construction_task_0340
     or pair.robot_network_task_0338 or pair.robot_network_request_0338
     or pair.construction_task or pair.direct_acquisition_custody_0513
     or pair.machine_logistics_custody_0528)
end
local function construction_request(pair)
 -- Remote ore demand takes priority over UNSTARTED routine construction.
 -- If its exact local mining site was refused by this same 0338 planner,
 -- allow one already-issued, physically stocked original 0836 rail first.
 -- The remote drill request remains pending for bounded re-evaluation.
 local remote=pair.remote_drill_request_1011
 if remote~=nil then
  local p=normalize_placeable(remote)
  if not(type(remote)=="table" and p
    and remote.remote_drill_terminal_1011==station_unit(pair)
    and (remote.item_name=="burner-mining-drill"
      or remote.item_name=="wooden-chest")) then return nil end
  return{field="remote_drill_request_1011",value=remote,
    placeable=p,position=remote.position,
    site_reason=remote.site_reason}
 end
 -- The 1076 frontier may use the builder ahead of an unfunded
 -- bootstrap ghost, but only after the same physical-source checks used
 -- by 0338 have ruled out a funded earlier construction request.
 -- 1252: a physically stocked power setup is a real prerequisite for
 -- electricity-dependent factory work. Admit this exact requested machine
 -- ahead of any UNSTARTED bootstrap ghost, funded or unfunded. Keep that
 -- ghost intact; active physical construction and custody are never displaced.
 local power=pair.structure_construction_requested_item
 if type(power)=="table"and power.owner=="power-setup-1252"
   and type(power.item_name)=="string"then
  local physical=normalize_placeable(power)
  if physical and source_for_item(pair,power.item_name)then
   return{field="structure_construction_requested_item",
     value=power,placeable=physical,position=power.position,
     site_reason=power.site_reason}
  end
 end
 local fluid,pipe_item=funded_fluid_pipe_1258(pair)
 if fluid then
  return{field="construction_request",value=fluid,placeable=pipe_item,
    position=fluid.position,site_reason=fluid.site_reason}
 end
 local b=bootstrap_request(pair)
 local frontier=pair.construction_request
 local blocked_miner=blocked_local_miner_yields_to_rail_0836(
   pair,"construction_requested_item",pair.construction_requested_item)
 if type(frontier)=="table"
   and frontier_owned_by_pair_0338(pair,frontier)
   -- Only the exact pending 0836 request can pass a still UNSTARTED
   -- funded bootstrap ghost; power and already begun custody retain priority.
   and (owned_pending_rail_0836(pair,frontier)
    or owned_pending_locomotive_0836(pair,frontier)
     or owned_pending_wagon_0836(pair,frontier)
    or not b or not source_for_item(pair,b.placeable.item_name)) then
  local earlier_funded=false
  for _,field in ipairs({"structure_construction_requested_item",
      "construction_requested_item"}) do
   local value=pair[field]
   local p=value and normalize_placeable(value)
   if p and source_for_item(pair,p.item_name)
     and not (blocked_miner and field=="construction_requested_item") then
     earlier_funded=true
   end
  end
  if not earlier_funded then
   local p=normalize_placeable(frontier)
   if p then return{field="construction_request",value=frontier,
     placeable=p,position=frontier.position,
     site_reason=frontier.site_reason} end
  end
 end
 -- An unfunded ghost reserves no real inventory. A separate paid,
 -- physically stocked build can proceed without retiring that ghost.
 -- Existing active construction custody and remote duties remain untouched.
 if b and not source_for_item(pair,b.placeable.item_name) then
  for _,field in ipairs({"structure_construction_requested_item",
      "construction_requested_item"})do
   local value=pair[field]
   local p=value and normalize_placeable(value)
   if p and source_for_item(pair,p.item_name)
      and not (blocked_miner and field=="construction_requested_item") then
    return{field=field,value=value,placeable=p,
      position=type(value)=="table"and(value.position or value.site_position)or nil,
      site_reason=type(value)=="table"and value.site_reason or nil}
   end
  end
 end
 if b then return b end
 for _,field in ipairs(request_fields)do
  local value=pair[field]
  if value~=nil then
   -- An invalid delegated 1076 marker may not enter the ordinary 0338
   -- construction fallback after failing its ranked priority preflight.
   -- This is only a fail-closed refusal, never request/cargo deletion.
   if field=="construction_request" and type(value)=="table"
     and (value.frontier_root_unit_1076~=nil
     or value.rail_mission_station_unit_0836~=nil
     or value.site_reason=="remote-rail-physical-frontier-0836")
    and not frontier_owned_by_pair_0338(pair,value)then return nil end
   local p=normalize_placeable(value)
   if p then return{field=field,value=value,placeable=p,
     position=type(value)=="table"and(value.position or value.site_position)or nil,
     site_reason=type(value)=="table"and value.site_reason or nil}end
  end
 end
 local legacy=pair.construction_task;if type(legacy)=="table"and legacy.item_name and legacy.entity_name then local p=normalize_placeable(legacy);if p then return{field="construction_task",value=legacy,placeable=p,position=legacy.site_position,site_reason=legacy.site_reason or"legacy-task-recovery"}end end;return nil
end
local function clear_request(pair,task)
 local field=task and task.request_field;if not field then return end;if field=="construction_bootstrap_ghost_0645"then if type(pair[field])=="table"then pair[field].status="built";pair[field].completed_tick=now()end;pair[field]=nil elseif pair[field]==task.request_value then pair[field]=nil end;if field=="construction_task"then pair.construction_task=nil end
end
local function plan_request(pair,request)
 if request.position then local planner=site_planner();local report;if planner and type(planner.placement_effectiveness_report)=="function"and tostring(request.placeable.category or""):find("defense",1,true)then local ok,r,why=pcall(planner.placement_effectiveness_report,pair,request.placeable.entity_name,request.position,request.placeable.category);if not(ok and r)then return nil,ok and(why or"ineffective-fixed-defense-site")or("site-effectiveness-error:"..safe(r))end;report=r end;return request.position,request.site_reason or"fixed-request-site",report end
 local planner=site_planner();if not(planner and type(planner.plan_site)=="function")then return nil,"site-planner-unavailable"end;local ok,pos,why,report=pcall(planner.plan_site,pair,request.placeable);if not ok then return nil,"site-planner-error:"..safe(pos)end;return pos,why,report
end
-- An unstarted bootstrap discovery is not a reservation. If a separate
-- earlier construction writ actually has a real item source, 0338 must
-- reconsider that funded work instead of indefinitely reusing the cached
-- unfunded ghost. Only the canonical builder may discard its own *candidate*;
-- never clear the writ, its source, a live build, robot job, cargo or movement.
-- A persisted/expired 0418 movement REQUEST is not a 0338 construction
-- reservation. Do not let that read-only movement record pin an unfunded
-- cached candidate forever; 0418 and 0510 still own movement and dispatch.
-- This function NEVER writes the movement request or admits a physical task.
local function refresh_funded_prior_over_unfunded_bootstrap_0338(pair)
 local candidate=pair and pair.construction_candidate_0338
 if not(candidate and candidate.request_field=="construction_bootstrap_ghost_0645"
   and type(candidate.item_name)=="string"
   and not source_for_item(pair,candidate.item_name)
   and not(pair.construction_task_0338 or pair.construction_custody_0338
     or pair.robot_network_task_0338 or pair.robot_network_request_0338
     or pair.construction_task)) then
  return false
 end
 for _,field in ipairs({"structure_construction_requested_item",
     "construction_requested_item"}) do
  local value=pair[field]
  local placeable=value and normalize_placeable(value)
  if placeable and source_for_item(pair,placeable.item_name) then
   -- Refresh discovery through the ORIGINAL 0338 priority/site and physical
   -- admission pipeline. A funded but unplaceable request can fail there;
   -- it is never silently bypassed in favor of the remote rail.
   pair.construction_candidate_0338=nil
   record(pair,"funded-prior-replaces-unfunded-bootstrap",field)
   return true
  end
 end
 return false
end
-- Discovery can run between the frontier's request and the dispatcher.
-- A cached unstarted bootstrap candidate may not steal an exact pending
-- 0836 rail request, even when its stock is funded. Physical tasks/cargo win.
local function refresh_unfunded_frontier_candidate(pair)
 local frontier=pair and pair.construction_request
 local c=pair and pair.construction_candidate_0338
 if not(type(frontier)=="table"
   and frontier_owned_by_pair_0338(pair,frontier)
   and c and c.request_value~=frontier
   and not pair.construction_task_0338
   and not pair.construction_custody_0338
   and type(c.item_name)=="string"
   and (owned_pending_rail_0836(pair,frontier)
     or owned_pending_locomotive_0836(pair,frontier)
     or owned_pending_wagon_0836(pair,frontier)
     or not source_for_item(pair,c.item_name))) then return false end
 pair.construction_candidate_0338=nil
 return true
end
-- Only an unfunded waiting-source task may yield to the resource mission.
-- Release its site reservation; retain the original request and never
-- preempt an item already carried or held under 0338 custody.
local function defer_unfunded_for_remote(pair)
 local task=pair.construction_task_0338
 local priority=pair.remote_drill_request_1011
 if not(priority and task and task.request_value~=priority
   and task.phase=="waiting-source" and not task.carried
   and not pair.construction_custody_0338
   and not source_for_item(pair,task.item_name)) then return false end
 if task.reserved_0338 and not release_site(pair,task) then return false end
 pair.construction_task_0338=nil
 pair.construction_candidate_0338=nil
 stat("unfunded_construction_deferred_for_remote")
 record(pair,"unfunded-deferred-for-remote",task.item_name)
 return true
end
function M.discover_pair(pair,force)
 local state=M.root();if state.enabled==false or not valid_pair(pair)then return nil end
 if refresh_unfunded_frontier_candidate(pair) then force=true end
 if refresh_funded_prior_over_unfunded_bootstrap_0338(pair) then force=true end
 defer_unfunded_for_remote(pair)
 if pair.construction_task_0338 or pair.construction_custody_0338 then return pair.construction_candidate_0338 end
 local priority=pair.remote_drill_request_1011
 if priority and (not pair.construction_candidate_0338
   or pair.construction_candidate_0338.request_value~=priority) then
  pair.construction_candidate_0338=nil
  force=true
 end
 if not force and now()<(tonumber(pair.construction_cooldown_0338)or 0)then return pair.construction_candidate_0338 end
 local request=construction_request(pair);if not request then pair.construction_candidate_0338=nil;return nil end
 if retire_unclaimed_starter_request_1205(pair,request) then return nil end
 local pos,why,effect=plan_request(pair,request)
 if not pos then
  pair.construction_candidate_0338=nil
  pair.construction_blocked_reason_0338=why
  pair.construction_site_refusal_0338={
    tick=now(),field=request.field,request=request.value,reason=why}
  pair.construction_cooldown_0338=now()+180
  record(pair,"site-blocked",why)
  return nil
 end
 pair.construction_site_refusal_0338=nil
 local c={version=M.version,tick=now(),item_name=request.placeable.item_name,entity_name=request.placeable.entity_name,category=request.placeable.category,position={x=pos.x,y=pos.y},direction=request.placeable.direction,site_reason=why,effectiveness=effect,request_field=request.field,request_value=request.value,ghost=request.ghost,source="construction-planner-0338"};pair.construction_candidate_0338=c;pair.construction_blocked_reason_0338=nil;stat("candidates-discovered");return c
end
-- Method II: 0338 submits one real ghost to Factorio's construction
-- robots. The physically paired parent, not the distant Magos, must own the
-- next rank's construction request. 0714 remains read-only.
local function robot_child_rank_0338(pair,entity_name)
 if pair.station.name=="planetary-magos-cogitator-station"
   and entity_name=="senior-cogitator-station" then return 4,3 end
 if pair.station.name=="senior-cogitator-station"
   and entity_name=="intermediate-cogitator-station" then return 3,2 end
 return nil,nil
end
local function robot_network_preflight_0338(pair,request,receipt_only)
 if not(valid_pair(pair) and type(request)=="table"
   and type(request.position)=="table"
   and type(request.position.x)=="number"
   and type(request.position.y)=="number"
   and request.root_station_unit==pair.station.unit_number
   and robot_child_rank_0338(pair,request.entity_name)~=nil
   and request.surface_index==pair.station.surface.index
   and request.force_index==pair.station.force.index)then
  return nil,"robot-request-rank-or-identity-invalid"
 end
 local placeable=normalize_placeable(request)
 if not(placeable and placeable.entity_name==request.entity_name
   and placeable.item_name==request.item_name)then
  return nil,"robot-request-item-prototype-invalid"
 end
 local readiness=rawget(_G,"TechPriestsRoboportReadiness0714")
 if not(readiness and type(readiness.scan_pair)=="function")then
  return nil,"roboport-observer-unavailable"
 end
 local ok=pcall(readiness.scan_pair,pair,true)
 if not ok then return nil,"roboport-observation-failed" end
 local saw_port,saw_coverage,saw_power,saw_robots,saw_stock=false,false,false,false,false
 for _,report in ipairs(pair.roboport_reports_0714 or{})do
  local port=report.entity
  if valid(port) and port.type=="roboport"
    and port.force==pair.station.force
    and port.surface==pair.station.surface then
   saw_port=true
   local cell,network
   pcall(function()cell=port.logistic_cell end)
   if cell and cell.valid~=false
     and type(cell.is_in_construction_range)=="function"then
    local covered,inside=pcall(function()
      return cell.is_in_construction_range(request.position)
    end)
    if covered and inside==true then
     saw_coverage=true
     pcall(function()network=cell.logistic_network end)
     local connected=false
     if port.is_connected_to_electric_network then
      pcall(function()connected=port.is_connected_to_electric_network()end)
     end
     local energy=tonumber(port.energy)or 0
     if connected and energy>0 and cell.transmitting~=false then
      saw_power=true
      if network and network.valid~=false
        and network.force==pair.station.force
        and (receipt_only or (tonumber(network.available_construction_robots)or 0)>0)
        and (tonumber(network.all_construction_robots)or 0)>0 then
       saw_robots=true
       local stocked,count=pcall(function()
         return network.get_item_count(request.item_name)
       end)
       if stocked and (receipt_only or (tonumber(count)or 0)>0) then
        saw_stock=true
        return {port=port,network=network,cell=cell,
          stock=tonumber(count),network_id=network.network_id},
          "powered-supplied-construction-network"
       end
      end
     end
    end
   end
  end
 end
 if not saw_port then return nil,"no-real-roboport" end
 if not saw_coverage then return nil,"outside-real-construction-coverage" end
 if not saw_power then return nil,"roboport-unpowered" end
 if not saw_robots then return nil,"no-available-construction-robots" end
 if not saw_stock then return nil,"no-physical-logistic-supply" end
 return nil,"robot-network-unavailable"
end
M.robot_network_preflight_0338=robot_network_preflight_0338
-- A real built entity plus an unrelated network stock change is not proof
-- that a construction robot built THIS station. Record the canonical native
-- on_robot_built_entity event against the already-owned 0338 ghost task.
-- Keep only primitive unit identities/tick so the receipt survives save/load.
function M.observe_native_robot_build_0338(event)
 local entity=event and event.entity
 local robot=event and event.robot
 if not(valid(entity) and valid(robot)
   and entity.unit_number and robot.unit_number
   and robot.type=="construction-robot"
   and robot.force==entity.force and robot.surface==entity.surface)then
  return false
 end
 for _,pair in pairs(pair_map())do
  local task=pair and pair.robot_network_task_0338
  if valid_pair(pair) and task
    and task.phase=="awaiting-real-construction-robot"
    and not task.robot_build_receipt_0338
    and task.entity_name==entity.name
    and task.position and dist_sq(entity.position,task.position)<=0.36
    and pair.station.force==entity.force
    and pair.station.surface==entity.surface
    and type(task.started_tick)=="number"
    and now()>=task.started_tick then
   task.robot_build_receipt_0338={
    station_unit=entity.unit_number,robot_unit=robot.unit_number,
    force_index=entity.force.index,surface_index=entity.surface.index,
    tick=now()}
   stat("native-robot-station-build-events")
   return true
  end
 end
 return false
end
local function robot_station_at_0338(pair,task)
 local surface=pair.station.surface
 local found
 local ok=pcall(function()
  found=surface.find_entities_filtered{
   name=task.entity_name,position=task.position,radius=0.6,
   force=pair.station.force,limit=4}
 end)
 if not(ok and type(found)=="table")then return nil end
 for _,entity in ipairs(found)do
  if valid(entity) and entity.name==task.entity_name
    and entity.surface==surface and entity.force==pair.station.force
    and dist_sq(entity.position,task.position)<=0.36 then
   return entity
  end
 end
 return nil
end
function M.service_robot_network_pair_0338(pair)
 if not valid_pair(pair) then
  return {processed=0,failed=1,detail="invalid-robot-pair"}
 end
 local request=pair.robot_network_request_0338
 local task=pair.robot_network_task_0338
 if not task and not request then
  return {processed=0,detail="no-robot-request"}
 end
 if pair.construction_task_0338 or pair.construction_custody_0338 then
  return {processed=1,blocked=1,detail="other-construction-custody"}
 end
 if not task then
  local live,why=robot_network_preflight_0338(pair,request)
  if not live then return {processed=1,blocked=1,detail=why} end
  if robot_station_at_0338(pair,request)then
   return {processed=1,blocked=1,detail="station-site-already-occupied"}
  end
  local placeable=normalize_placeable(request)
  local can,clear=pcall(function()
   return pair.station.surface.can_place_entity{
    name=placeable.entity_name,position=request.position,
    force=pair.station.force,direction=request.direction}
  end)
  if not(can and clear==true)then
   return {processed=1,blocked=1,detail="robot-site-not-engine-placeable"}
  end
  local claim={position={x=request.position.x,y=request.position.y},
   entity_name=request.entity_name,item_name=request.item_name,
   request_value=request,request_field="robot_network_request_0338"}
  local reserved,reason=claim_site(pair,claim)
  if not reserved then
   return {processed=1,blocked=1,detail="robot-site-reservation:"..safe(reason)}
  end
  -- The ghost is the ONLY construction mutation here. The native robot
  -- network, not the priest or this script, must fetch and spend the item.
  local created,ghost=pcall(function()
   return pair.station.surface.create_entity{
    name="entity-ghost",inner_name=request.entity_name,
    position=request.position,force=pair.station.force,
    direction=request.direction,expires=false,raise_built=true}
  end)
  if not(created and valid(ghost)
    and ghost.name=="entity-ghost"
    and ghost.ghost_name==request.entity_name
    and ghost.force==pair.station.force
    and ghost.surface==pair.station.surface)then
   release_site(pair,claim)
   return {processed=1,blocked=1,detail="robot-ghost-create-refused"}
  end
  task=claim
  task.ghost=ghost
  task.phase="awaiting-real-construction-robot"
  task.network_id=live.network_id
  task.port_unit=live.port.unit_number
  task.network_stock_before=live.stock
  task.started_tick=now()
  pair.robot_network_task_0338=task
  stat("robot-ghosts-placed")
  record(pair,"robot-ghost-submitted",request.entity_name)
  return {processed=1,waiting=1,detail="robot-ghost-awaiting-physical-build"}
 end
 if task.request_value~=request or not task.ghost then
  return {processed=1,blocked=1,detail="robot-task-custody-identity-invalid"}
 end
 if valid(task.ghost)then
  return {processed=1,waiting=1,detail="robot-ghost-still-present"}
 end
 local entity=robot_station_at_0338(pair,task)
 if not entity then
  return {processed=1,blocked=1,detail="robot-ghost-lost-without-real-station"}
 end
 local native=task.robot_build_receipt_0338
 if not(native and native.station_unit==entity.unit_number
   and type(native.robot_unit)=="number"
   and native.force_index==entity.force.index
   and native.surface_index==entity.surface.index
   and type(native.tick)=="number"
   and type(task.started_tick)=="number"
   and native.tick>=task.started_tick
   and native.tick<=now())then
  return {processed=1,blocked=1,detail="robot-native-build-event-unverified"}
 end
 if not task.stock_delta_verified then
  local live,why=robot_network_preflight_0338(pair,request,true)
  if not live then
   return {processed=1,blocked=1,detail="robot-receipt-network:"..why}
  end
  if live.network_id~=task.network_id
    or task.network_stock_before-live.stock~=1 then
   return {processed=1,blocked=1,detail="robot-material-debit-unverified"}
  end
  task.stock_delta_verified=true
  task.built_entity=entity
  task.physical_build_tick=now()
 end
 local tp=storage and storage.tech_priests
 local child=tp and tp.pairs_by_station
   and tp.pairs_by_station[entity.unit_number]
 local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
 if not(child and child.station==entity and valid(child.priest)
   and hierarchy and type(hierarchy.rank)=="function"
   and type(hierarchy.is_direct_subordinate)=="function"
   and hierarchy.rank(pair)==robot_child_rank_0338(pair,request.entity_name)
   and hierarchy.rank(child)==select(2,robot_child_rank_0338(pair,request.entity_name))
   and hierarchy.is_direct_subordinate(pair,child)==true)then
  return {processed=1,waiting=1,detail="robot-station-awaiting-ranked-pair"}
 end
 release_site(pair,task)
 task.phase="complete"
 task.completed_tick=now()
 task.child_station_unit=entity.unit_number
 task.child_priest_unit=child.priest.unit_number
 pair.robot_network_last_task_0338=task
 pair.robot_network_task_0338=nil
 pair.robot_network_request_0338=nil
 stat("robot-stations-physically-verified")
 record(pair,"robot-station-built-and-paired",safe(entity.unit_number))
 return {processed=1,acted=1,detail="robot-station-physically-built-and-paired"}
end
function M.recommend_action(pair)
 if not pair then return nil end
 if not pair.construction_task_0338 and not pair.construction_custody_0338 then
  -- A cached construction candidate must not monopolize the dispatcher
  -- while 0256 is physically evacuating this station. Preserve any
  -- preexisting construction task/cargo under its original duty instead.
  local ok,reserved=pcall(Recycling0822.reservation_for,pair)
  if not ok or reserved then return nil end
 end
 if not pair.construction_task_0338 and not pair.construction_custody_0338
   and (pair.robot_network_task_0338 or pair.robot_network_request_0338) then
  if now()<(tonumber(pair.robot_network_retry_tick_0338)or 0) then return nil end
  local rt=pair.robot_network_task_0338
  if not(rt and valid(rt.ghost)) then
   return {kind="construction",family="construction",
    position=(rt and rt.position) or pair.robot_network_request_0338.position,
    phase=rt and "robot-receipt" or "robot-ghost",
    source="construction-planner-0338",reason="real-robot-network-station"}
  end
  return nil
 end
 local task=pair.construction_task_0338;local custody=pair.construction_custody_0338;local candidate=pair.construction_candidate_0338;local v=task or custody or candidate;if not v then return nil end;-- Do not monopolize the sole action dispatcher while a requested item has not yet been produced.
 if task and task.phase=="waiting-source" and not source_for_item(pair,task.item_name) then return nil end
 if not task and not custody and candidate and not source_for_item(pair,candidate.item_name) then return nil end
 return{kind="construction",family="construction",target=valid(v.ghost)and v.ghost or nil,position=v.position,item=v.item_name or v.item,phase=v.phase or(task and task.phase)or"candidate",source="construction-planner-0338",reason=v.site_reason or v.reason or"construction-request",active=task~=nil or custody~=nil}
end
local function sync_custody(pair,task,reason)
 local carried=task and task.carried;if carried and carried.item_name and(tonumber(carried.count)or 0)>0 then pair.construction_custody_0338={version=M.version,tick=now(),phase="removed-not-built",item_name=carried.item_name,count=carried.count,entity_name=task.entity_name,category=task.category,position=task.position,direction=task.direction,source_entity=task.source_entity,source_inv=task.source_inv,source_label=task.source_label,request_field=task.request_field,request_value=task.request_value,reason=reason or task.phase};return true end;pair.construction_custody_0338=nil;return false
end
local function release_terminal_movement(pair)
 -- A high-priority construction route is valid only while this pair still
 -- owns a physical construction task. Terminal cleanup must free it so the
 -- next material acquisition is not denied for the remainder of a 720-tick
 -- movement lease. Never stop combat, rescue or another family's route.
 local controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
 if not(controller and type(controller.request_status)=="function"
   and type(controller.stop)=="function")then return false end
 local ok,status=pcall(controller.request_status,pair)
 if not(ok and type(status)=="table" and status.active==true
   and status.owner=="construction-planner-0338")then return false end
 local stopped,accepted=pcall(controller.stop,pair,"construction-terminal-handoff-0338")
 if stopped and accepted==true then
  stat("terminal_movement_released")
  return true
 end
 stat("terminal_movement_release_failed")
 return false
end
-- 1150: Only the 0338 executor may configure a recipe on the brand-new
-- physical assembler it has just placed with an actually debited item.
-- Never repurpose a player's/another priest's existing machine, change a
-- loaded recipe, or discard stock ejected by set_recipe (Factorio 2.0).
function M.configure_built_factory_recipe_1150(pair,task,built)
 local request=task and task.request_value
 local recipe=type(request)=="table" and request.factory_component_recipe_1150
 if recipe==nil then return false,"not-factory-component-construction" end
 if not(valid_pair(pair) and valid(built)
   and type(recipe)=="string" and recipe~=""
   and task.request_field=="construction_requested_item"
   and pair.construction_requested_item==request
   and request.factory_component_owner_1150==station_unit(pair)
   and request.item_name==task.item_name
   and request.entity_name==task.entity_name
   and built.name==task.entity_name
   and built.type=="assembling-machine"
   and built.force==pair.station.force
   and built.surface==pair.station.surface
   and built.unit_number
   and type(built.get_recipe)=="function"
   and type(built.set_recipe)=="function")then
  return false,"recipe-build-identity-or-type-invalid"
 end
 local force_recipes=pair.station.force.recipes
 local available=force_recipes and force_recipes[recipe]
 if not(available and available.enabled==true)then
  return false,"factory-recipe-not-researched"
 end
 local read,current=pcall(function()return built.get_recipe()end)
 if not read then return false,"built-machine-recipe-unreadable" end
 if current then
  return current.name==recipe, current.name==recipe
    and "physical-built-machine-already-configured"
    or "built-machine-has-foreign-recipe"
 end
 -- A newly placed empty assembler can safely accept one recipe. If an
 -- on_built callback inserted items or fluids, refuse: set_recipe would
 -- otherwise remove them and return stacks the planner cannot custody.
 if type(built.get_item_count)~="function"then
  return false,"new-assembler-stock-unverifiable"
 end
 local items_ok,n=pcall(function()return built.get_item_count()end)
 if not(items_ok and n==0)then
  return false,"new-assembler-not-empty"
 end
 local checked,empty=pcall(function()
  local box=built.fluidbox
  if not box then return true end
  for i=1,#box do
   local fluid=box[i]
   if fluid and (tonumber(fluid.amount)or 0)>0 then return false end
  end
  return true
 end)
 if not checked or empty~=true then
  return false,"new-assembler-has-fluid-or-unreadable-fluidbox"
 end
 local ok,removed=pcall(function()return built.set_recipe(recipe)end)
 if not ok then return false,"new-assembler-set-recipe-refused:"..safe(removed) end
 if type(removed)~="table" or next(removed)~=nil then
  return false,"new-assembler-set-recipe-displaced-items"
 end
 local readback,selected=pcall(function()return built.get_recipe()end)
 if not(readback and selected and selected.name==recipe)then
  return false,"new-assembler-recipe-readback-failed"
 end
 return true,"real-built-assembler-recipe-configured"
end
local function finish(pair,task,built,reason)
 release_terminal_movement(pair)
 release_site(pair,task)
 local request=task and task.request_value
 if built and type(request)=="table"
   and type(request.factory_component_recipe_1150)=="string"then
  local configured,why=M.configure_built_factory_recipe_1150(pair,task,built)
  pair.factory_component_last_receipt_1150={
    station_unit=station_unit(pair),entity_unit=built.unit_number,
    recipe=request.factory_component_recipe_1150,
    configured=configured==true,reason=why,tick=now(),
    built_entity=built,
  }
  if not configured then
   -- The entity WAS built with a real item. Do not claim recipe production,
   -- issue a duplicate machine or roll back item custody on configuration
   -- failure. Preserve a visible blocker until the same entity is resolved.
   pair.factory_component_blocked_1150={
    recipe=request.factory_component_recipe_1150,
    entity_unit=built.unit_number,built_entity=built,reason=why,tick=now()}
   record(pair,"factory-recipe-configuration-blocked-1150",why)
  else
   pair.factory_component_blocked_1150=nil
   record(pair,"factory-recipe-configured-1150",
     request.factory_component_recipe_1150)
  end
 end
 -- Preserve the original 0836 writ's terminal fate BEFORE 0338 clears its
 -- request and another build overwrites the generic last-task receipt.
 -- Only native readbacks and primitive values; this trace never grants rail
 -- credit or restores items.
 if marked_rail_request_0836(task) then
  local mission=pair.remote_rail_outpost_0835
  local pending=mission and mission.pending_rail_0836
  if pending and pending.request==task.request_value then
   local debit=task.original_rail_source_debit_0836
   local source_now=nil
   if task.source_inv and task.source_inv.valid then
    source_now=item_count(task.source_inv,task.item_name)
   end
   pending.original_terminal_trace_0836={
    tick=now(),result=reason,phase=built and "complete" or "aborted",
    request_owned_before_clear=pair.construction_request==task.request_value,
    item_name=task.item_name,source_label=task.source_label,
    source_unit=debit and debit.source_unit or nil,
    source_before=debit and debit.before or nil,
    source_after=debit and debit.after or nil,
    source_readback=source_now,
    carried_remaining=task.carried and task.carried.count or nil,
    built_name=valid(built) and built.name or nil,
    built_unit=valid(built) and built.unit_number or nil,
    built_position=valid(built) and {
     x=built.position.x,y=built.position.y} or nil,
   }
  end
 end
 if built then clear_request(pair,task)end
 -- A physically debited second starter must reach its source inventory
 -- before the obsolete non-ghost commissioning request is retired.
 if not built and task.retire_after_refund_1205
   and task.entity_name=="tech-priests-emergency-smelter"
   and (not task.carried or (tonumber(task.carried.count)or 0)<=0)
   and task.request_field~="construction_bootstrap_ghost_0645"
   and pair[task.request_field]==task.request_value then
  pair[task.request_field]=nil
 end
 pair.construction_candidate_0338=nil
 pair.construction_custody_0338=nil
 pair.construction_task_0338=nil
 pair.construction_task=nil
 -- 1153: all original 0338 build, movement and item custody has been
 -- released before 0528 may OFFER (not start) the real ingredient feed.
 -- The existing logistics executor performs each future actual debit,
 -- priest movement and insertion using native inventory readbacks.
 local receipt=pair.factory_component_last_receipt_1150
 if built and receipt and receipt.configured==true
     and receipt.built_entity==built then
  local logistics=rawget(_G,"TechPriestsMachineLogisticsFulfillment0528")
    or package.loaded["scripts.core.logistics_machine_fulfillment_0528"]
  local offered,why=false,"physical-0528-authority-unavailable"
  if logistics
      and type(logistics.offer_factory_component_feed_1153)=="function"then
    local ok,accepted,reason=pcall(
      logistics.offer_factory_component_feed_1153,pair,built,receipt.recipe)
    offered=ok and accepted==true
    why=ok and reason or "physical-0528-offer-error:"..safe(accepted)
  end
  pair.factory_component_feed_status_1153={
    tick=now(),machine_unit=built.unit_number,recipe=receipt.recipe,
    candidate_offered=offered,reason=why,
  }
 end
 pair.construction_cooldown_0338=now()+(built and 90 or 180)
 task.phase=built and "complete" or "aborted"
 task.completed_tick=now()
 task.result=reason
 task.built_entity=built
 pair.construction_last_task_0338=task
 -- The generic terminal slot is overwritten by unrelated subsequent work.
 -- Preserve THIS exact original paid 0836 completion inside its pending writ
 -- so a later native scan can verify it after indexed scans catch up. This
 -- records only a real 0338 source debit and actual built LuaEntity, never
 -- creates either. Missing/ambiguous source evidence cannot be accepted.
 if built and marked_rail_request_0836(task) then
  local mission=pair.remote_rail_outpost_0835
  local pending=mission and mission.pending_rail_0836
  local debit=task.original_rail_source_debit_0836
  if pending and pending.request==task.request_value
    and task.request_field=="construction_request"
    and task.item_name=="rail" and task.entity_name=="straight-rail"
    and task.creative_build~=true
    and debit and debit.item=="rail" and debit.source_unit
    and type(debit.before)=="number" and type(debit.after)=="number"
    and debit.before>=1 and debit.before-debit.after==1
    and valid(built) and built.name=="straight-rail"
    and built.unit_number
    and built.force==pair.station.force
    and built.surface==pair.station.surface then
   pending.original_paid_completion_0836={
    request_value=task.request_value,phase="complete",
    built_entity=built,built_unit=built.unit_number,
    item_name="rail",creative_build=false,
    source_unit=debit.source_unit,source_before=debit.before,
    source_after=debit.after,source_debit_tick=debit.tick,
    completed_tick=now(),native_0338_paid=true}
   record(pair,"original-paid-rail-receipt-preserved-0836",
     "source="..safe(debit.source_unit)..
     " before="..safe(debit.before).." after="..safe(debit.after)..
     " built="..safe(built.unit_number))
  else
   record(pair,"original-rail-receipt-unproven-0836",
     "missing-original-native-debit-or-entity")
  end
 end
 -- Preserve ONE paid 0338 train receipt through later generic builds.
 -- An actual native locomotive and original source debit are mandatory.
 if built and task.item_name=="locomotive"
   and task.entity_name=="locomotive"
   and task.site_reason=="original-first-locomotive-0836"
   and task.request_field=="construction_request"
   and task.creative_build~=true then
  local mission=pair.remote_rail_outpost_0835
  local state=mission and mission.first_locomotive_0836
  local debit=task.original_locomotive_debit_0836
  if state and state.request==task.request_value
    and debit and debit.source_unit and type(debit.before)=="number"
    and type(debit.after)=="number" and debit.before-debit.after==1
    and valid(built) and built.name=="locomotive" and built.unit_number
    and built.train and built.train.valid
    and built.force==pair.station.force
    and built.surface==pair.station.surface then
   state.built_entity=built
   state.paid_completion_0836={
     request_value=task.request_value,native_0338_paid=true,
     source_unit=debit.source_unit,before=debit.before,after=debit.after,
     built_entity=built,built_unit=built.unit_number,completed_tick=now()}
  end
 end
 -- Preserve ONE paid 0338 train receipt through later generic builds.
 -- An actual native wagon and original source debit are mandatory.
 if built and task.item_name=="cargo-wagon"
   and task.entity_name=="cargo-wagon"
   and task.site_reason=="original-first-wagon-0836"
   and task.request_field=="construction_request"
   and task.creative_build~=true then
  local mission=pair.remote_rail_outpost_0835
  local state=mission and mission.first_wagon_0836
  local debit=task.original_wagon_debit_0836
  if state and state.request==task.request_value
    and debit and debit.source_unit and type(debit.before)=="number"
    and type(debit.after)=="number" and debit.before-debit.after==1
    and valid(built) and built.name=="cargo-wagon" and built.unit_number
    and built.train and built.train.valid
    and built.force==pair.station.force
    and built.surface==pair.station.surface then
   state.built_entity=built
   state.paid_completion_0836={
     request_value=task.request_value,native_0338_paid=true,
     source_unit=debit.source_unit,before=debit.before,after=debit.after,
     built_entity=built,built_unit=built.unit_number,completed_tick=now()}
  end
 end
 record(pair,built and "built" or "aborted",reason)
 -- The last-task slot is shared with routine 0338 work. Reconcile an
 -- ORIGINAL paid, physically placed 0836 rail while this exact terminal
 -- receipt still owns the slot, before another build can replace it.
 -- 0836 itself verifies the native rail entity, exact request identity,
 -- segment order and graph continuity; this does not mint a receipt.
 if built and marked_rail_request_0836(task) then
  local rail=rawget(_G,"TechPriestsRailTrackFrontier0836")
  local mission=pair.remote_rail_outpost_0835
  local pending=mission and mission.pending_rail_0836
  if pending and pending.request==task.request_value
    and rail and type(rail.verify_pending)=="function" then
   local ok,verified,why=pcall(rail.verify_pending,pair)
   record(pair,ok and verified and "physical-rail-reconciled-0836"
     or "physical-rail-reconciliation-refused-0836",
     ok and safe(why) or ("verifier-error:"..safe(verified)))
  end
 end
 if not built and task.request_field=="construction_bootstrap_ghost_0645"
   and type(reason)=="string"
   and reason:find("^site%-invalid:occupied%-by%-physical%-entity:")
   and (not task.carried or (tonumber(task.carried.count)or 0)<=0) then
  -- The carried machine was physically refunded before finish() ran.
  -- Replan immediately now that no task/custody owns the obsolete ghost.
  -- Never discard a live machine or wait for a later planning pulse just
  -- to retire a site already obstructed by real infrastructure.
  local planner=rawget(_G,"TechPriestsConstructionBootstrapGhostPlanner0645")
    or package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]
  if planner and type(planner.service_pair)=="function"then
   local ok,changed=pcall(planner.service_pair,pair,"construction-obstruction-refunded-0338")
   if ok and changed==true then
    pair.construction_cooldown_0338=now()+60
    stat("occupied-sites-replanned-after-refund")
   end
  end
 end
 return{processed=1,acted=built and 1 or 0,blocked=built and 0 or 1,detail=reason}
end
local function deposit_exact(pair,item,count,reason)local a=storage_authority();if a and type(a.deposit_exact)=="function"then return a.deposit_exact(pair,item,count,reason,{})end;return false,"storage-authority-unavailable",0 end
local function return_custody(pair,task)
 local failure=task.failure_reason_0338
 local carried=task.carried;if not(carried and carried.item_name and(tonumber(carried.count)or 0)>0)then return finish(pair,task,false,failure and (failure..";empty-custody") or "empty-custody")end
 if valid(task.source_entity)and task.source_inv and task.source_inv.valid then
  if not within_entity_reach(pair.priest.position,task.source_entity,M.return_reach_sq) then task.phase="return-custody";sync_custody(pair,task,"returning-source");if not request_move(pair,task.source_entity,"construction-custody-source-return-0338")then return{processed=1,blocked=1,detail="source-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-source-custody"}end
  local inserted=insert_item(task.source_inv,carried.item_name,carried.count);carried.count=carried.count-inserted;if carried.count<=0 then return finish(pair,task,false,failure and (failure..";custody-returned-source") or "custody-returned-source")end;task.source_entity=nil;task.source_inv=nil;sync_custody(pair,task,"source-return-partial")
 end
 if not within_entity_reach(pair.priest.position,pair.station,M.return_reach_sq) then task.phase="return-custody";sync_custody(pair,task,"returning-station");if not request_move(pair,pair.station,"construction-custody-station-return-0338")then return{processed=1,blocked=1,detail="station-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-station-custody"}end
 local accepted,why,inserted=deposit_exact(pair,carried.item_name,carried.count,"construction-custody-return-0338");inserted=tonumber(inserted)or 0;carried.count=carried.count-inserted;if accepted==true and carried.count<=0 then return finish(pair,task,false,failure and (failure..";custody-stored") or "custody-stored")end;sync_custody(pair,task,"storage-blocked");return{processed=1,blocked=1,detail="storage-blocked:"..safe(why)}
end
-- Explicit admin-only test setting; never inferred from frustration.
local function creative_enabled()
 local root=M.root()
 return root.creative_instant_build==true
end
local function register_creative_command()
 if not(commands and commands.add_command)then return false end
 if commands.commands and commands.commands["tp-creative-build"] then return true end
 commands.add_command("tp-creative-build","Admin test toggle: /tp-creative-build on|off|status",function(event)
  local player=event.player_index and game.get_player(event.player_index) or nil
  if player and (not player.valid or not player.admin) then
   player.print("[Tech-Priests] Administrator access required.")
   return
  end
  local mode=tostring(event.parameter or "status"):lower():match("^%s*(.-)%s*$")
  local root=M.root()
  if mode=="on"then root.creative_instant_build=true
  elseif mode=="off"then root.creative_instant_build=false
  elseif mode~="status"then
   if player then player.print("Usage: /tp-creative-build on|off|status")end
   return
  end
  local message="[Tech-Priests] Creative construction: "..(root.creative_instant_build and "ON" or "OFF")
  if player then player.print(message)elseif log then log(message)end
 end)
 return true
end
local frontier_site_contact_0338
local function begin_task(pair,c)
 -- A cached discovery candidate is NOT construction authority. A delegated
 -- 1076 Senior can lose its live rank edge, or the Magos can replace the
 -- exact request, between 0338 discovery and physical task admission.
 -- Recheck before reserving a site or debiting any native item. Retain the
 -- original request/cargo untouched on refusal.
 local request=c.request_value
 local marked=type(request)=="table"
   and request.frontier_root_unit_1076~=nil
 if c.site_reason=="powered-roboport-frontier-1076" or marked then
  if not(marked and c.request_field=="construction_request"
    and c.site_reason=="powered-roboport-frontier-1076"
    and request.site_reason=="powered-roboport-frontier-1076"
    and pair.construction_request==request
    and frontier_owned_by_pair_0338(pair,request)
    and request.item_name==c.item_name
    and request.entity_name==c.entity_name
    and type(request.position)=="table"
    and type(c.position)=="table"
    and request.position.x==c.position.x
    and request.position.y==c.position.y)then
   return nil,"frontier-request-ownership-stale"
  end
  local stand,why=frontier_site_contact_0338(pair,c.entity_name,c.position)
  if not stand then return nil,why end
 end
 if marked_rail_request_0836(c)
   and not authorized_rail_candidate_0836(pair,c) then
  return nil,"rail-original-physical-request-stale"
 end
 -- The first locomotive has its OWN post-audit, counted site and source
 -- ownership. A station marker alone cannot authorize train construction.
 local locomotive_writ=type(c.request_value)=="table"
   and c.request_value.site_reason=="original-first-locomotive-0836"
 if locomotive_writ or c.site_reason=="original-first-locomotive-0836" then
  if not(c.request_field=="construction_request"
    and c.item_name=="locomotive" and c.entity_name=="locomotive"
    and c.site_reason=="original-first-locomotive-0836"
    and type(c.position)=="table"
    and type(c.request_value)=="table"
    and type(c.request_value.position)=="table"
    and c.position.x==c.request_value.position.x
    and c.position.y==c.request_value.position.y
    and c.direction==c.request_value.direction
    and owned_pending_locomotive_0836(pair,c.request_value))then
   return nil,"locomotive-original-physical-request-stale"
  end
 end
 local wagon_writ=type(c.request_value)=="table"
   and c.request_value.site_reason=="original-first-wagon-0836"
 if wagon_writ or c.site_reason=="original-first-wagon-0836" then
  if not(c.request_field=="construction_request"
    and c.item_name=="cargo-wagon" and c.entity_name=="cargo-wagon"
    and c.site_reason=="original-first-wagon-0836"
    and type(c.position)=="table"
    and type(c.request_value)=="table"
    and type(c.request_value.position)=="table"
    and c.position.x==c.request_value.position.x
    and c.position.y==c.request_value.position.y
    and c.direction==c.request_value.direction
    and owned_pending_wagon_0836(pair,c.request_value))then
   return nil,"wagon-original-physical-request-stale"
  end
 end
 local task={version=M.version,phase="waiting-source",item_name=c.item_name,entity_name=c.entity_name,category=c.category,position={x=c.position.x,y=c.position.y},direction=c.direction,site_reason=c.site_reason,effectiveness=c.effectiveness,request_field=c.request_field,request_value=c.request_value,ghost=c.ghost,started_tick=now()};local ok,why=claim_site(pair,task);if not ok then return nil,why end;pair.construction_task_0338=task;return task
end
local function restore_orphan_custody(pair)
 if pair.construction_task_0338 or type(pair.construction_custody_0338)~="table"then return false end;local c=pair.construction_custody_0338;if not(c.item_name and(tonumber(c.count)or 0)>0)then return false end;pair.construction_task_0338={version=M.version,phase="return-custody",item_name=c.item_name,entity_name=c.entity_name,category=c.category,position=c.position,direction=c.direction,carried={item_name=c.item_name,count=c.count},source_entity=c.source_entity,source_inv=c.source_inv,source_label=c.source_label,request_field=c.request_field,request_value=c.request_value,started_tick=now(),custody_recovery=true};record(pair,"orphan-custody-restored",c.item_name);return true
end
local function site_still_valid(pair,task)
 if task.request_field=="construction_bootstrap_ghost_0645"
   and not valid(task.ghost) then
  local record=pair.construction_bootstrap_ghost_0645
  if type(record)=="table" and valid(record.ghost)
    and record.entity_name==task.entity_name
    and dist_sq(record.ghost.position,task.position)<=0.36 then
   -- A rebuilt reference is legitimate only at the same reserved site.
   task.ghost=record.ghost
  else
   -- The ghost may have been replaced at a different site. Return the
   -- already-carried physical item rather than reviving or constructing at
   -- a superseded position.
   return false,"obsolete-or-missing-bootstrap-ghost"
  end
 end
 if valid(task.ghost)then
  local ghost_planner=rawget(_G,"TechPriestsConstructionBootstrapGhostPlanner0645")
    or package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]
  if ghost_planner and type(ghost_planner.physical_site_obstruction)=="function"then
   local ok,occupied,other=pcall(ghost_planner.physical_site_obstruction,pair,task.ghost)
   if ok and occupied then
    return false,"occupied-by-physical-entity:"..safe(other and other.name)
   end
  end
  return true,"matching-ghost"
 end
 local planner=site_planner();if planner and type(planner.placement_effectiveness_report)=="function"and tostring(task.category or""):find("defense",1,true)then local ok,report,why=pcall(planner.placement_effectiveness_report,pair,task.entity_name,task.position,task.category);if ok and report then task.effectiveness=report;return true,"effectiveness-revalidated"end;return false,ok and(why or"ineffective-defense-site")or("effectiveness-error:"..safe(report))end
 local ok,can=pcall(function()return pair.station.surface.can_place_entity({name=task.entity_name,position=task.position,force=pair.station.force,direction=task.direction})end);return ok and can==true,ok and"engine-revalidated"or"engine-check-failed"
end
-- Factorio can refuse an otherwise valid receiver tile when the builder
-- itself occupies that tile. This is only a physical standoff proposal:
-- the engine must still approve the empty site after the priest walks away.
-- A collision-clear *center* is not enough for a wide priest: its
-- projected collision box can still overlap a 1x1 chest at the drill output.
-- Factorio remains the final placement authority.
local function chest_contact_clears_priest(pair,task,pos)
 if task.entity_name~="wooden-chest" then return true,false end
 local ok,priest_box=pcall(function()return pair.priest.bounding_box end)
 local proto=prototypes and prototypes.entity and prototypes.entity[task.entity_name]
 local site_ok,site_box=pcall(function()return proto and proto.collision_box end)
 if not(ok and priest_box and site_ok and site_box)then return true,false end
 local function edges(box)
  local a=box.left_top or box[1];local b=box.right_bottom or box[2]
  if not(a and b and type(a.x)=="number"and type(a.y)=="number"
    and type(b.x)=="number"and type(b.y)=="number")then return nil end
  return math.min(a.x,b.x),math.min(a.y,b.y),
    math.max(a.x,b.x),math.max(a.y,b.y)
 end
 local px0,py0,px1,py1=edges(priest_box)
 local sx0,sy0,sx1,sy1=edges(site_box)
 if not(px0 and sx0)then return true,false end
 local dx=pos.x-pair.priest.position.x
 local dy=pos.y-pair.priest.position.y
 local x0=task.position.x+sx0;local x1=task.position.x+sx1
 local y0=task.position.y+sy0;local y1=task.position.y+sy1
 local gap=0.05
 return px1+dx+gap<=x0 or px0+dx-gap>=x1
   or py1+dy+gap<=y0 or py0+dy-gap>=y1,true
end
local function standoff_key(pos)
 return string.format("%.3f:%.3f",pos.x,pos.y)
end
-- A 4x4 roboport cannot be built by walking within two tiles of its
-- CENTER: that point is inside the future collision footprint. Use the
-- native prototype's collision box for this one wide frontier structure,
-- while retaining the original two-tile reach measured from its EDGE.
-- Unavailable native geometry fails closed, never grants remote placement.
local function roboport_collision_bounds(task)
 if not(task and task.entity_name=="roboport" and task.position)then return nil end
 local ok,box=pcall(function()
  local proto=prototypes and prototypes.entity and prototypes.entity.roboport
  return proto and proto.collision_box
 end)
 if not(ok and box)then return nil end
 local lt=box.left_top or box[1];local rb=box.right_bottom or box[2]
 if not(lt and rb and type(lt.x)=="number" and type(lt.y)=="number"
   and type(rb.x)=="number" and type(rb.y)=="number")then return nil end
 local x0,x1=math.min(lt.x,rb.x),math.max(lt.x,rb.x)
 local y0,y1=math.min(lt.y,rb.y),math.max(lt.y,rb.y)
 if x0>=x1 or y0>=y1 then return nil end
 return x0,y0,x1,y1
end
-- 1204: A 3x3 assembler's center is not a build contact. The original
-- center-only two-tile test forces a priest into its future collision box,
-- where it cannot clear the ghost and repeatedly times out. Honor the
-- genuine prototype footprint for wide machines, retaining the same two-
-- tile physical reach measured from its edge and Factorio's final placement
-- checks. Small machines still use the existing conservative center test.
local function wide_entity_collision_bounds_1204(task)
 if not(task and task.position and type(task.entity_name)=="string")
   or task.entity_name=="roboport"then return nil end
 local proto=prototypes and prototypes.entity
   and prototypes.entity[task.entity_name]
 local box=proto and proto.collision_box
 if not box then return nil end
 local a,b=box.left_top or box[1],box.right_bottom or box[2]
 if not(a and b)then return nil end
 -- Accept runtime BoundingBox {left_top={x,y}} and prototype data-stage
 -- {{x,y},{x,y}} coordinates without guessing the sprite's size.
 local ax,ay=a.x or a[1],a.y or a[2]
 local bx,by=b.x or b[1],b.y or b[2]
 if not(type(ax)=="number"and type(ay)=="number"
   and type(bx)=="number"and type(by)=="number")then return nil end
 local x0,x1=math.min(ax,bx),math.max(ax,bx)
 local y0,y1=math.min(ay,by),math.max(ay,by)
 if x1-x0<1.5 and y1-y0<1.5 then return nil end
 -- A locomotive's runtime prototype box is in its north-facing frame.
 -- The original 0836 railway runs EAST: collision is rotated by 90 degrees.
 -- The ordinary wide-machine standoff otherwise walks the priest INSIDE
 -- the locomotive's future long axis, turning an initially placeable site
 -- into a genuine engine-revalidated refusal after the physical approach.
 -- Correct geometry only; Factorio still checks the final placeability.
 if task.entity_name=="locomotive" or task.entity_name=="cargo-wagon" then
  local d=defines and defines.direction
  if not d then return nil end
  if task.direction==d.east or task.direction==d.west then
   x0,y0,x1,y1=-y1,x0,-y0,x1
  elseif task.direction~=d.north and task.direction~=d.south then
   return nil -- Do not guess at a non-cardinal train footprint.
  end
 end
 return x0,y0,x1,y1
end
local function site_build_distance_sq(position,task)
 local x0,y0,x1,y1
 if task.entity_name=="roboport"then
  x0,y0,x1,y1=roboport_collision_bounds(task)
  if not x0 then return math.huge end
 else
  x0,y0,x1,y1=wide_entity_collision_bounds_1204(task)
  if not x0 then return dist_sq(position,task.position)end
 end
 local px=position.x-task.position.x
 local py=position.y-task.position.y
 local dx=math.max(x0-px,0,px-x1)
 local dy=math.max(y0-py,0,py-y1)
 return dx*dx+dy*dy
end
-- A planned locomotive contact must keep the original moving priest's
-- entire projected physical collision box off the rotated rolling-stock
-- footprint. A site-clear point is insufficient for a non-point-size priest.
-- Missing geometry fails closed; no item, task or pre-existing writ is altered.
local function locomotive_contact_clears_priest_0836(pair,task,contact)
 if task.entity_name~="locomotive" and task.entity_name~="cargo-wagon"then return true end
 local x0,y0,x1,y1=wide_entity_collision_bounds_1204(task)
 if not x0 then return false end
 local ok,box=pcall(function()return pair.priest.bounding_box end)
 if not(ok and box)then return false end
 local a,b=box.left_top or box[1],box.right_bottom or box[2]
 if not(a and b)then return false end
 local ax,ay=a.x or a[1],a.y or a[2]
 local bx,by=b.x or b[1],b.y or b[2]
 if not(type(ax)=="number"and type(ay)=="number"
   and type(bx)=="number"and type(by)=="number")then return false end
 local dx=contact.x-pair.priest.position.x
 local dy=contact.y-pair.priest.position.y
 local px0,px1=math.min(ax,bx)+dx,math.max(ax,bx)+dx
 local py0,py1=math.min(ay,by)+dy,math.max(ay,by)+dy
 local gap=0.08
 local sx0,sx1=task.position.x+x0,task.position.x+x1
 local sy0,sy1=task.position.y+y0,task.position.y+y1
 return px1+gap<=sx0 or px0-gap>=sx1
   or py1+gap<=sy0 or py0-gap>=sy1
end
local function non_ghost_standoff(pair,task,avoid,reach_recovery)
 if not (valid_pair(pair) and task and task.position) then return nil end
 local surface=pair.station.surface
 -- Normal contacts favor a generously clear collision footprint. Factorio
 -- 2.0.77 can stop a moving priest about 0.32 tiles short of such a contact:
 -- a 1.9-tile receiver waypoint then leaves the builder outside its actual
 -- two-tile construction reach, even though movement was accepted.
 -- After *observed physical stall only*, try shorter contacts first. Every
 -- candidate must still clear the projected priest box and pass Factorio's
 -- real can_place_entity check; never increase build reach or force placement.
 local offsets
 local wx0,wy0,wx1,wy1=wide_entity_collision_bounds_1204(task)
 if task.entity_name=="roboport" then
  local x0,y0,x1,y1=roboport_collision_bounds(task)
  if not x0 then return nil end
  -- Exterior contacts must clear the future building and wide priest,
  -- but remain within the SAME two-tile physical build reach from its box.
  -- Slightly shorter/longer contacts are available after a genuine stall.
  local mx,my=(x0+x1)*0.5,(y0+y1)*0.5
  local gaps=reach_recovery and {1.25,1.6,1.45} or {1.45,1.25}
  offsets={}
  for _,gap in ipairs(gaps)do
   offsets[#offsets+1]={x0-gap,my}
   offsets[#offsets+1]={x1+gap,my}
   offsets[#offsets+1]={mx,y0-gap}
   offsets[#offsets+1]={mx,y1+gap}
  end
 elseif task.entity_name=="wooden-chest" then
  offsets=reach_recovery
    and {{1.72,0},{-1.72,0},{0,1.72},{0,-1.72},
         {1.22,1.22},{1.22,-1.22},{-1.22,1.22},{-1.22,-1.22},
         {1.8,0},{-1.8,0},{0,1.8},{0,-1.8},
         {1.9,0},{-1.9,0},{0,1.9},{0,-1.9},
         {1.34,1.34},{1.34,-1.34},{-1.34,1.34},{-1.34,-1.34}}
    or {{1.9,0},{-1.9,0},{0,1.9},{0,-1.9},
        {1.34,1.34},{1.34,-1.34},{-1.34,1.34},{-1.34,-1.34}}
 elseif wx0 then
  -- Exterior contacts must be outside a 2x2/3x3 collision footprint,
  -- not the nominal center-distance contact intended for small chests.
  local mx,my=(wx0+wx1)*0.5,(wy0+wy1)*0.5
  local gaps=reach_recovery and {0.75,1.15,1.55} or {0.9,1.25}
  offsets={}
  for _,gap in ipairs(gaps)do
   offsets[#offsets+1]={wx0-gap,my}
   offsets[#offsets+1]={wx1+gap,my}
   offsets[#offsets+1]={mx,wy0-gap}
   offsets[#offsets+1]={mx,wy1+gap}
  end
 else
  offsets={{1.4,0},{-1.4,0},{0,1.4},{0,-1.4},
           {0.99,0.99},{0.99,-0.99},{-0.99,0.99},{-0.99,-0.99}}
 end
 local tried=task.standoff_tried_0338 or {}
 local best,score=nil,math.huge
 for _,offset in ipairs(offsets) do
  local pos={x=task.position.x+offset[1],y=task.position.y+offset[2]}
  local authorized=true
  if task.site_reason=="powered-roboport-frontier-1076" then
   -- A Magos cannot build beyond its existing 0418 movement authority.
   -- Check the actual exterior contact, not the structure center.
   local controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
   authorized=false
   if controller and type(controller.position_allowed)=="function" then
    local ok,allowed=pcall(controller.position_allowed,pair,pos,
      "construction-site-standoff-0338",{owner="construction-planner-0338"})
    authorized=ok and allowed==true
   end
  end
  if authorized and not tried[standoff_key(pos)]
    and (not avoid or dist_sq(pos,avoid)>0.01)
    and site_build_distance_sq(pos,task)<=M.build_reach_sq
    and chest_contact_clears_priest(pair,task,pos)
    and locomotive_contact_clears_priest_0836(pair,task,pos) then
   local ok,clear=pcall(function()
    return surface.can_place_entity{
      name=pair.priest.name,position=pos,force=pair.station.force}
   end)
   if ok and clear==true then
    local d=dist_sq(pair.priest.position,pos)
    if d<score then best=pos;score=d end
   end
  end
 end
 return best
end
frontier_site_contact_0338=function(pair,entity_name,position)
 if not(valid_pair(pair) and type(position)=="table"
   and type(position.x)=="number" and type(position.y)=="number") then
  return nil,"frontier-invalid-priest-or-site"
 end
 local controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
 if not(controller and type(controller.position_allowed)=="function") then
  return nil,"frontier-canonical-movement-authority-unavailable"
 end
 local stand=non_ghost_standoff(pair,{
  entity_name=entity_name,position=position,
  site_reason="powered-roboport-frontier-1076"})
 return stand,stand and "authorized-physical-priest-contact"
   or "frontier-no-physically-reachable-authorized-contact"
end
M.frontier_site_contact_0338=function(pair,entity_name,position)
 return frontier_site_contact_0338(pair,entity_name,position)
end
local function diagnose_receiver_site(pair,task)
 if task.entity_name~="wooden-chest" or type(log)~="function" then return end
 if task.last_site_diag_0338 and now()-task.last_site_diag_0338<300 then return end
 task.last_site_diag_0338=now()
 local stand=task.build_standoff_0338 or {}
 local priest_clear,clearance_known=chest_contact_clears_priest(pair,task,pair.priest.position)
 local observed="not-queried"
 -- A site still blocked after the builder's actual collision box has cleared
 -- cannot be repaired by marching that same builder around the chest. Ask
 -- the existing scan router for bounded, fresh evidence of physical occupants;
 -- this diagnostic never authorizes mining, movement or construction.
 if clearance_known and priest_clear then
  local router=rawget(_G,"TechPriestsScanRouting0610")
    or package.loaded["scripts.core.scan_routing_0610"]
  if router and type(router.find_entities)=="function"then
   local p=task.position
   local ok,entities=pcall(router.find_entities,pair.station.surface,
     {area={{p.x-0.6,p.y-0.6},{p.x+0.6,p.y+0.6}},limit=12},
     {category="construction",limit=12,require_fresh=true})
   if ok and type(entities)=="table"then
    local names={}
    for _,entity in ipairs(entities)do
     if valid(entity)then
      names[#names+1]=safe(entity.name).."#"..safe(entity.unit_number)
        .."@"..safe(entity.position and entity.position.x)
        ..","..safe(entity.position and entity.position.y)
     end
    end
    observed=table.concat(names,";")
   else observed="scan-unavailable" end
  else observed="router-unavailable" end
 end
 log("[Tech-Priests 0338] RECEIVER_SITE_BLOCKED tick="..safe(now())..
   " site="..safe(task.position.x)..","..safe(task.position.y)..
   " priest="..safe(pair.priest.position.x)..","..safe(pair.priest.position.y)..
   " contact="..safe(stand.x)..","..safe(stand.y)..
   " phase="..safe(task.phase).." attempts="..safe(task.standoff_replans_0338)..
   " priest_clear="..safe(clearance_known and priest_clear)..
   " occupants="..observed)
end
-- A real drill can eject ore onto the exact receiver tile before its chest
-- exists (Factorio runtime 41185592104). Never delete that stack or move it
-- remotely. The 0338 builder must collect it at the site into an engine-owned
-- persistent inventory, carry it home and transfer it into its original source
-- inventory before retrying the same reserved construction.
local function receiver_ground_item(pair,task)
 if task.entity_name~="wooden-chest" or valid(task.ghost) then return nil end
 local router=rawget(_G,"TechPriestsScanRouting0610")
   or package.loaded["scripts.core.scan_routing_0610"]
 if not(router and type(router.find_entities)=="function")then return nil end
 local p=task.position
 local ok,entities=pcall(router.find_entities,pair.station.surface,
   {area={{p.x-0.55,p.y-0.55},{p.x+0.55,p.y+0.55}},
     type="item-entity",limit=8},
   {category="construction",limit=8,require_fresh=true})
 if not(ok and type(entities)=="table")then return nil end
 for _,e in ipairs(entities)do
  if valid(e) and e.name=="item-on-ground" then
   local good,stack=pcall(function()return e.stack end)
   if good and stack and stack.valid_for_read
     and (tonumber(stack.count)or 0)>0 then return e end
  end
 end
 return nil
end
local function ground_cargo_count(task)
 local cargo=task.ground_cargo_0338
 if not(cargo and cargo.valid and task.ground_item_0338)then return 0 end
 return item_count(cargo,task.ground_item_0338)
end
local function clear_ground_site(pair,task)
 if task.phase=="clear-ground-pickup" then
  -- Save physical detour start across reload.
  task.ground_detour_started_tick_0338=task.ground_detour_started_tick_0338 or now()
  local e=task.ground_source_0338
  if not valid(e) then e=receiver_ground_item(pair,task);task.ground_source_0338=e end
  if not valid(e) then task.phase="move-site";return{processed=1,waiting=1,detail="ground-site-source-gone-recheck"}end
  if e.surface~=pair.station.surface
    or dist_sq(e.position,task.position)>0.61 then
   return{processed=1,blocked=1,detail="ground-site-identity-changed"}
  end
  if not within_entity_reach(pair.priest.position,e,M.pickup_reach_sq)then
   if not request_move_position(pair,e.position,"construction-ground-pickup-0338",1.0)then
    return{processed=1,blocked=1,waiting=1,detail="ground-pickup-route-denied"}
   end
   return{processed=1,waiting=1,detail="moving-to-real-ground-item"}
  end
  local cargo=task.ground_cargo_0338
  if not cargo then
   local ok,created=pcall(function()return game.create_inventory(1)end)
   if not(ok and created and created.valid)then
    return{processed=1,blocked=1,detail="ground-cargo-unavailable"}
   end
   cargo=created;task.ground_cargo_0338=cargo
  end
  local src=e.stack
  if not(src and src.valid_for_read and (tonumber(src.count)or 0)>0)then
   return{processed=1,blocked=1,detail="ground-stack-unreadable"}
  end
  local name=src.name
  if task.ground_item_0338 and task.ground_item_0338~=name then
   return{processed=1,blocked=1,detail="ground-stack-identity-changed"}
  end
  local before=tonumber(src.count)or 0
  local slot=cargo[1]
  if not(slot and type(slot.transfer_stack)=="function")then
   return{processed=1,blocked=1,detail="ground-cargo-slot-unavailable"}
  end
  local held_before=item_count(cargo,name)
  local ok=pcall(function()slot.transfer_stack(src)end)
  local held_after=item_count(cargo,name)
  local ground_after=(valid(e) and e.stack and e.stack.valid_for_read)
    and (tonumber(e.stack.count)or 0)or 0
  if held_after-held_before~=before-ground_after
    or held_after<held_before or ground_after>before then
   task.ground_custody_error_0338="ground-transfer-ambiguous"
   return{processed=1,blocked=1,detail="ground-transfer-ambiguous"}
  end
  if not ok and held_after==held_before then
   return{processed=1,blocked=1,waiting=1,detail="ground-transfer-refused"}
  end
  if held_after<=0 then
   return{processed=1,blocked=1,waiting=1,detail="ground-transfer-no-items"}
  end
  task.ground_item_0338=name
  -- An exact native drill can refill its empty output tile while the builder
  -- walks home. Keep this real stack in persistent engine cargo until the
  -- receiver is built; only then return and deposit it at the source.
  local native=task.request_field=="remote_drill_request_1011"
    and type(task.request_value)=="table"
    and tonumber(task.request_value.remote_drill_unit_1012)
  if native then
   task.ground_source_0338=nil
   task.phase="move-site"
   record(pair,"native-receiver-ground-held-for-build",name.." x"..safe(held_after))
   if dist_sq(pair.priest.position,task.position)<=M.build_reach_sq then
    local clear=site_still_valid(pair,task)
    if clear then
     task.phase="build"
     -- Build in the same engine tick as the actual stack pickup, when
     -- collision/reach checks permit. No time for the drill to refill.
     return M.service_pair(pair,"native-receiver-after-real-ground-pickup")
    end
   end
   return{processed=1,waiting=1,detail="ground-item-held-for-receiver-build"}
  end
  task.phase="clear-ground-return"
  record(pair,"ground-site-physically-picked-up",name.." x"..safe(held_after))
  return{processed=1,waiting=1,detail="ground-item-in-engine-cargo"}
 end
 if task.phase=="clear-ground-return" then
  local cargo=task.ground_cargo_0338
  local item=task.ground_item_0338
  if task.ground_custody_error_0338
    or not(cargo and cargo.valid and item)then
   return{processed=1,blocked=1,detail="ground-cargo-quarantined"}
  end
  local held=ground_cargo_count(task)
  if held<=0 then
   return{processed=1,blocked=1,detail="ground-cargo-empty-unreconciled"}
  end
  if not(valid(task.source_entity) and task.source_inv
    and task.source_inv.valid)then
   return{processed=1,blocked=1,waiting=1,detail="ground-return-source-unavailable"}
  end
  if not within_entity_reach(pair.priest.position,task.source_entity,M.return_reach_sq)then
   if not request_move(pair,task.source_entity,"construction-ground-return-0338")then
    return{processed=1,blocked=1,waiting=1,detail="ground-return-route-denied"}
   end
   return{processed=1,waiting=1,detail="carrying-real-ground-item-home"}
  end
  local inv=task.source_inv
  local before=item_count(inv,item)
  local slot=cargo[1]
  if not(slot and slot.valid_for_read and slot.name==item)then
   task.ground_custody_error_0338="ground-return-slot-changed"
   return{processed=1,blocked=1,detail="ground-return-slot-changed"}
  end
  for i=1,#inv do
   local dest=inv[i]
   if dest and type(dest.transfer_stack)=="function"then
    pcall(function()dest.transfer_stack(slot)end)
    local remaining=ground_cargo_count(task)
    local credited=item_count(inv,item)-before
    if credited~=held-remaining or credited<0 or remaining>held then
     task.ground_custody_error_0338="ground-return-ambiguous"
     return{processed=1,blocked=1,detail="ground-return-ambiguous"}
    end
    if remaining==0 then break end
    held=remaining;before=item_count(inv,item)
   end
  end
  if ground_cargo_count(task)>0 then
   return{processed=1,blocked=1,waiting=1,detail="ground-return-storage-full"}
  end
  cargo.destroy()
  task.ground_cargo_0338=nil
  task.ground_item_0338=nil
  task.ground_source_0338=nil
  task.ground_cleared_0338=(tonumber(task.ground_cleared_0338)or 0)+1
  -- The original static-blocker deadline was not extended by contact
  -- rotation. A physically removed blocker is a genuinely changed site.
  task.site_blocked_since_0338=nil
  record(pair,"ground-site-deposited-real-item","counted")
  if task.ground_abort_reason_0338 then
   local why=task.ground_abort_reason_0338
   task.ground_abort_reason_0338=nil
   return M.abort_pair(pair,why)
  end
  -- The original one-way travel allowance excludes real ground cleanup.
  -- Credit elapsed pickup/return and outbound travel only after the physical
  -- item is deposited with counted inventory receipts. Bound cumulative
  -- cleanup allowances so blocked construction still expires.
  local started=tonumber(task.ground_detour_started_tick_0338)
  if started and now()>=started then
   local elapsed=now()-started
   local outbound=math.ceil(math.sqrt(dist_sq(pair.priest.position,task.position))
     *M.travel_ticks_per_tile)
   local previous=math.max(0,tonumber(task.ground_detour_allowance_ticks_0338)or 0)
   task.ground_detour_allowance_ticks_0338=math.min(
     M.max_ground_detour_extra_ticks,previous+elapsed+outbound)
  end
  task.ground_detour_started_tick_0338=nil
  if task.ground_built_entity_0338 then
   local built=task.ground_built_entity_0338
   if not valid(built)then
    return finish(pair,task,false,"native-receiver-lost-after-physical-build")
   end
   return finish(pair,task,built,task.ground_build_reason_0338 or "entity-created")
  end
  task.phase="move-site"
  return{processed=1,waiting=1,detail="ground-item-counted-at-source"}
 end
 return nil
end
local function matching_ghost(pair,task)
 local ghost=task.ghost
 if not valid(ghost) then return false,"ghost-invalid" end
 local ok,why=pcall(function()
  if ghost.name~="entity-ghost" then return "wrong-entity-type:"..safe(ghost.name) end
  if ghost.ghost_name~=task.entity_name then return "wrong-ghost-prototype:"..safe(ghost.ghost_name).."/"..safe(task.entity_name) end
  if ghost.surface~=pair.station.surface then return "wrong-surface" end
  if ghost.force~=pair.station.force then return "wrong-force:"..safe(ghost.force and ghost.force.name).."/"..safe(pair.station.force and pair.station.force.name) end
  -- The ghost's engine-normalized position is authoritative. Bootstrap records
  -- may contain the requested placement coordinate before entity snapping.
  -- Preserve the original site claim; reject only a ghost that has moved
  -- materially away from the requested site.
  if dist_sq(ghost.position,task.position)>4 then return "wrong-position" end
  return nil
 end)
 if not ok then return false,"ghost-validation-error:"..safe(why) end
 return why==nil,why
end
local function create_entity(pair,task)
 if valid(task.ghost)then
  local matches,mismatch=matching_ghost(pair,task);if not matches then return nil,"ghost-mismatch:"..safe(mismatch)end
  -- Factorio 2.0 revive returns collided items, revived entity, and optionally a proxy.
  local ok,collided,entity=pcall(function()return task.ghost.revive({raise_revive=true})end)
  if ok and valid(entity) and entity.name==task.entity_name
   and entity.force==pair.station.force and entity.surface==pair.station.surface then return entity,"ghost-revived"end
  -- A failed revival is not authorization to create through the ghost.
  return nil,ok and"ghost-revive-refused"or"ghost-revive-error:"..safe(collided)
 end
 local ok,e=pcall(function()return pair.station.surface.create_entity({name=task.entity_name,position=task.position,force=pair.station.force,direction=task.direction,raise_built=true})end)
 if ok and valid(e) and e.name==task.entity_name and e.force==pair.station.force then return e,"entity-created"end
 return nil,ok and"create-refused"or"create-error:"..safe(e)
end

function M.abort_pair(pair,reason)local task=pair and pair.construction_task_0338;if not task then return{processed=0,detail="no-task"}end;if ground_cargo_count(task)>0 then task.ground_abort_reason_0338=reason or"aborted";task.phase="clear-ground-return";sync_custody(pair,task,"ground-cargo-must-return-first");return{processed=1,blocked=1,waiting=1,detail="ground-cargo-return-required"}end;if sync_custody(pair,task,reason)then task.phase="return-custody";return return_custody(pair,task)end;return finish(pair,task,false,reason or"aborted")end
local function construction_active_timeout(pair,task)
 if not task or task.phase=="waiting-source" then return false end
 if not task.active_started_tick_0338 then
  -- A station may take minutes to manufacture the requested placeable.
  -- Start a finite travel deadline only once the physical source exists.
  local source=valid(task.source_entity)and task.source_entity.position or pair.station.position
  local site=task.position or source
  local distance=math.sqrt(dist_sq(pair.priest.position,source))
    +math.sqrt(dist_sq(source,site))
  task.active_started_tick_0338=now()
  -- Only the exact authorized original railway writ gets enough time
  -- for the physical source-to-priest-to-remote-site round trip. A foreign,
  -- revoked or ordinary build keeps the original strict timeout.
  local travel_cap=M.max_travel_extra_ticks
  if marked_rail_request_0836(task)
      and authorized_rail_candidate_0836(pair,task) then
    travel_cap=M.rail_max_travel_extra_ticks_0836
  end
  task.travel_allowance_ticks_0338=math.min(travel_cap,
    math.ceil(distance*M.travel_ticks_per_tile))
 end
 return now()-task.active_started_tick_0338>
   M.request_timeout+(tonumber(task.travel_allowance_ticks_0338)or 0)
    +math.min(M.max_ground_detour_extra_ticks,
      math.max(0,tonumber(task.ground_detour_allowance_ticks_0338)or 0))
end
function M.service_pair(pair,reason)
 local state=M.root();if state.enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end
 if not pair.construction_task_0338 and not pair.construction_custody_0338 then
  local ok,rec=pcall(Recycling0822.reservation_for,pair)
  if not ok then
   return{processed=1,blocked=1,detail="station-recovery-reservation-unobservable-0822"}
  end
  if rec then
   -- This is a real persisted 0256 writ, not a CI-specific flag.
   -- Never create a fresh construction task while the station is being
   -- emptied and physically recovered by its parent/eligible peer.
   return{processed=1,blocked=1,detail="station-recovery-reserved-0822"}
  end
 end
 if not pair.construction_task_0338 and not pair.construction_custody_0338
   and (pair.robot_network_task_0338 or pair.robot_network_request_0338) then
  local result=M.service_robot_network_pair_0338(pair)
  if result.blocked==1 and not pair.robot_network_task_0338 then
   -- A disconnected or empty network must not force a new bounded 0714
   -- observation on every canonical dispatcher pulse.
   pair.robot_network_retry_tick_0338=now()+180
  end
  return result
 end
 restore_orphan_custody(pair)
 defer_unfunded_for_remote(pair)
 local task=pair.construction_task_0338
 if valid(pair.combat_target)then
  if task and ground_cargo_count(task)>0 then
   return M.abort_pair(pair,"combat-interrupted-ground-cargo")
  elseif task and task.carried then
   task.phase="return-custody";sync_custody(pair,task,"combat-interrupted")
   return return_custody(pair,task)
  elseif task then return M.abort_pair(pair,"combat-priority")
  else return{processed=1,blocked=1,detail="combat-priority"}end
 end
 if not task then
  local priority=pair.remote_drill_request_1011
  refresh_unfunded_frontier_candidate(pair)
  local power=pair.structure_construction_requested_item
  local old=pair.construction_candidate_0338
  -- Only a cached UNSTARTED candidate yields to energy planning.
  -- The physical 0338 task and its item custody were checked above.
  if type(power)=="table"and power.owner=="power-setup-1252"
     and old and old.request_value~=power
     and source_for_item(pair,power.item_name)then
   pair.construction_candidate_0338=nil
  end
  local fluid=funded_fluid_pipe_1258(pair)
  if fluid and old and old.request_value~=fluid then
   -- Only the cached, UNSTARTED discovery yields; no physical custody.
   pair.construction_candidate_0338=nil
  end
  -- A cached unfunded bootstrap may not hide a genuinely stocked earlier writ.
  refresh_funded_prior_over_unfunded_bootstrap_0338(pair)
  local c=pair.construction_candidate_0338
  if priority and (not c or c.request_value~=priority) then c=nil end
  c=c or M.discover_pair(pair,true)
  if not c then return{processed=1,waiting=1,detail="no-candidate"}end
  if retire_unclaimed_starter_request_1205(pair,{
    field=c.request_field,value=c.request_value,
    placeable={entity_name=c.entity_name}}) then
   return{processed=1,waiting=1,detail="bootstrap-smelter-already-physical-1205"}
  end
  local why;task,why=begin_task(pair,c)
  if not task then return{processed=1,blocked=1,detail="reservation-blocked:"..safe(why)}end
 end
 if task.phase=="return-custody"then return return_custody(pair,task)end
 -- A physically credited railway may NEVER inherit the admin creative
 -- shortcut, including a preexisting creative task loaded from a save.
 -- Refuse via the same 0338 abort authority before any engine placement.
 if marked_rail_request_0836(task) and task.creative_build==true then
  return M.abort_pair(pair,"rail-creative-item-bypass-forbidden")
 end
 -- An admitted 0836 task can still lose its original Magos ownership while
 -- moving or across reload. Keep any already-debited item in the existing
 -- 0338 return-custody path, never place it against a different rail writ.
 if marked_rail_request_0836(task)
   and not authorized_rail_candidate_0836(pair,task) then
  return M.abort_pair(pair,"rail-original-physical-request-stale")
 end
 if task.site_reason=="original-first-locomotive-0836"
   and not (task.request_field=="construction_request"
     and task.request_value==pair.construction_request
     and owned_pending_locomotive_0836(pair,task.request_value)) then
  return M.abort_pair(pair,"locomotive-original-physical-request-stale")
 end
 if task.site_reason=="original-first-wagon-0836"
   and not (task.request_field=="construction_request"
     and task.request_value==pair.construction_request
     and owned_pending_wagon_0836(pair,task.request_value)) then
  return M.abort_pair(pair,"wagon-original-physical-request-stale")
 end
 -- Preexisting real local infrastructure supersedes only this one-time
 -- bootstrap smelter; original item custody returns through 0338.
 if task.entity_name=="tech-priests-emergency-smelter"
   and task.phase~="clear-ground-return"
   and existing_bootstrap_smelter_1203(pair) then
  -- Direct and ghost requests share the real physical uniqueness check.
  -- Refund counted cargo first; do not cancel a valid physical return.
  task.failure_reason_0338=task.request_field=="construction_bootstrap_ghost_0645"
    and "bootstrap-smelter-already-physical-1203"
    or "bootstrap-smelter-already-physical-1205"
  if task.request_field~="construction_bootstrap_ghost_0645" then
   task.retire_after_refund_1205=true
  end
  return M.abort_pair(pair,task.failure_reason_0338)
 end
 if task.ground_custody_error_0338 then return{processed=1,blocked=1,detail="ground-cargo-quarantined"}end
 if task.phase=="clear-ground-return"then return clear_ground_site(pair,task)end
 if construction_active_timeout(pair,task)then
  -- A timed-out route still refunds the physical item, but the completed
  -- 0338 receipt must retain the actual timeout cause, not merely the
  -- generic custody-returned-source outcome.
  local why="construction-timeout:"..safe(task.phase)..":"..safe(task.item_name)
  task.failure_reason_0338=why
  return M.abort_pair(pair,why)
 end
 if task.phase=="clear-ground-pickup"then return clear_ground_site(pair,task)end
 -- Rail acceptance requires a real 0338 source item even when an admin
 -- enabled creative building for unrelated manual/test construction.
 if task.phase=="waiting-source" and creative_enabled()
   and not marked_rail_request_0836(task) then
  task.creative_build=true
  task.phase="move-site"
 end
 if task.phase=="waiting-source"then
  local source=source_for_item(pair,task.item_name)
  if not source then
   -- The earlier 0836 admission watchdog cannot run while 0338 owns
   -- an active task. If all previously stocked rails disappear after
   -- admission, this physical builder used to wait forever with no item
   -- custody. Bound only this original rail writ; other manufacturing
   -- jobs retain their existing legitimate waiting-source policy.
   if marked_rail_request_0836(task) then
    local started=tonumber(task.started_tick)
    if not started or started<0 or started>now()
      or now()-started>M.rail_source_wait_ticks_0836 then
     -- No source item was debited; canonical 0338 abort releases its
     -- reservation and records the exact original task refusal.
     -- 0836 observes that terminal receipt and blocks the mission.
     return M.abort_pair(pair,"rail-physical-source-unavailable")
    end
   end
   return{processed=1,waiting=1,detail="waiting-source"}
  end
  task.source_entity=source.entity
  task.source_inv=source.inv
  task.source_label=source.label
  task.phase="move-source"
 end
 if task.phase=="move-source"then if not valid(task.source_entity)then return M.abort_pair(pair,"source-invalid")end;if not within_entity_reach(pair.priest.position,task.source_entity,M.pickup_reach_sq) then if not request_move(pair,task.source_entity,"construction-source-0338")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="moving-source"}end;task.phase="pickup"end
 if task.phase=="pickup"then
  -- A durable original 0836 rail receipt must originate with a measured
  -- native 0338 source debit, not a counter, source-unit guess or ghost.
  local original_rail=marked_rail_request_0836(task)
    and authorized_rail_candidate_0836(pair,task)
  local mission=pair.remote_rail_outpost_0835
  local first_loco=mission and mission.first_locomotive_0836
  local original_loco=task.item_name=="locomotive"
    and task.entity_name=="locomotive"
    and task.site_reason=="original-first-locomotive-0836"
    and task.request_field=="construction_request"
    and first_loco and first_loco.request==task.request_value
    and owned_pending_locomotive_0836(pair,task.request_value)
    and mission.status=="rail-track-established"
  local before=original_rail and item_count(task.source_inv,task.item_name) or nil
  local locomotive_before=original_loco
    and item_count(task.source_inv,"locomotive") or nil
  local first_wagon=mission and mission.first_wagon_0836
  local original_wagon=task.item_name=="cargo-wagon"
    and task.entity_name=="cargo-wagon"
    and task.site_reason=="original-first-wagon-0836"
    and task.request_field=="construction_request"
    and first_wagon and first_wagon.request==task.request_value
    and owned_pending_wagon_0836(pair,task.request_value)
    and mission.status=="rail-track-established"
  local wagon_before=original_wagon
    and item_count(task.source_inv,"cargo-wagon") or nil
  local removed=remove_item(task.source_inv,task.item_name,1)
  if removed~=1 then return M.abort_pair(pair,"source-remove-failed")end
  task.carried={item_name=task.item_name,count=1}
  if original_rail then
   local after=item_count(task.source_inv,task.item_name)
   if not(before and before>=1 and before-after==1
       and valid(task.source_entity) and task.source_entity.unit_number) then
    -- The single removed rail remains under the original 0338 cargo lease.
    -- Return it physically; never manufacture or credit ambiguous stock.
    return M.abort_pair(pair,"rail-native-source-debit-unreconciled")
   end
   task.original_rail_source_debit_0836={
    source_unit=task.source_entity.unit_number,
    before=before,after=after,tick=now(),item="rail"}
   -- After ONE verified 0338 item debit, optionally stage additional
   -- actual rails into the original Magos' persistent engine inventory.
   -- The paid rail itself remains in this original 0338 task.carry.
   if not stage_original_rail_supply_0836(pair,task) then
    return M.abort_pair(pair,"rail-native-stage-custody-ambiguous")
   end
  end
  if original_loco then
    local after=item_count(task.source_inv,"locomotive")
    if not(locomotive_before and locomotive_before>=1
      and locomotive_before-after==1
      and valid(task.source_entity) and task.source_entity.unit_number)then
      return M.abort_pair(pair,"native-locomotive-source-debit-unreconciled")
    end
    task.original_locomotive_debit_0836={
      source_unit=task.source_entity.unit_number,
      before=locomotive_before,after=after,tick=now()}
  end
  if original_wagon then
    local after=item_count(task.source_inv,"cargo-wagon")
    if not(wagon_before and wagon_before>=1
      and wagon_before-after==1
      and valid(task.source_entity) and task.source_entity.unit_number)then
      return M.abort_pair(pair,"native-wagon-source-debit-unreconciled")
    end
    task.original_wagon_debit_0836={
      source_unit=task.source_entity.unit_number,
      before=wagon_before,after=after,tick=now()}
  end
  sync_custody(pair,task,"removed-source")
  task.phase="move-site"
 end
 if task.phase=="move-site"then
  -- Native 2.0.77 run 41189829595: dropped drill output blocked the
  -- receiver tile while the builder was still outside build reach.
  -- Waiting for the build/move-clear phase cannot work if movement stops
  -- short of that range. Observe the real site before approaching it;
  -- only a real scanned stack can start physical pickup and counted return.
  -- Throttle this preflight so routine construction adds no scan loop.
  if task.entity_name=="wooden-chest" and not valid(task.ghost)
    and task.carried and (tonumber(task.carried.count)or 0)>0
    and now()>=(tonumber(task.ground_preflight_next_tick_0338)or 0)then
   task.ground_preflight_next_tick_0338=now()+180
   -- A real drill may eject an item-on-ground onto the receiver tile
   -- while Factorio still reports that the chest prototype is placeable.
   -- Do not use can_place_entity as a proxy for whether ground cargo exists:
   -- physically recover every observed stack before the carried chest is
   -- constructed, even when the engine reports an otherwise clear site.
   -- The bounded 0610 scan observes actual entities; it never creates ore.
   if (tonumber(task.ground_cleared_0338)or 0)<4 then
    local loose=receiver_ground_item(pair,task)
    if loose then
     if ground_cargo_count(task)>0 then
      task.phase="clear-ground-return"
      return{processed=1,waiting=1,detail="ground-cargo-return-before-next-pickup"}
     end
     task.ground_source_0338=loose
     task.phase="clear-ground-pickup"
     task.ground_detour_started_tick_0338=task.ground_detour_started_tick_0338 or now()
     sync_custody(pair,task,"ground-site-obstruction-preflight")
     return{processed=1,waiting=1,detail="ground-item-requires-physical-clearance"}
    end
   end
  end
  if site_build_distance_sq(pair.priest.position,task)>M.build_reach_sq then
   -- Non-ghost construction must approach a real collision-clear standoff,
   -- never deliberately route into the footprint the item will occupy.
   -- Factorio still validates the actual build site before construction.
   local destination,move_reason,move_radius=task.position,"construction-site-0338",1.75
   if not valid(task.ghost) then
    -- Keep one physical destination for the whole approach. Re-selecting the
    -- closest contact on every service can reverse a moving priest's route
    -- before it ever enters build reach (observed native receiver timeout).
    local stand=task.build_standoff_0338
    if not stand then
     stand=non_ghost_standoff(pair,task)
     if stand then
      task.build_standoff_0338=stand
      task.move_site_last_position_0338={x=pair.priest.position.x,y=pair.priest.position.y}
      task.move_site_progress_tick_0338=now()
      task.move_site_best_remaining_0338=math.sqrt(dist_sq(pair.priest.position,stand))
     end
    else
     -- Sideways motion and route oscillation are not progress toward the
     -- actual contact. The old displacement-only timer could be refreshed
     -- forever by a priest circling an unreachable receiver waypoint.
     local previous=task.move_site_last_position_0338
     local remaining=math.sqrt(dist_sq(pair.priest.position,stand))
     local best=tonumber(task.move_site_best_remaining_0338)
     if not best then
      best=previous and math.sqrt(dist_sq(previous,stand)) or remaining
      task.move_site_best_remaining_0338=best
     end
     if remaining<=best-0.2 then
      task.move_site_best_remaining_0338=remaining
      task.move_site_last_position_0338={x=pair.priest.position.x,y=pair.priest.position.y}
      task.move_site_progress_tick_0338=now()
     elseif now()-(tonumber(task.move_site_progress_tick_0338)or now())>=180 then
      -- Rotate only after 180 ticks without a meaningful decrease in
      -- distance to the waypoint, never because of lateral displacement.
      -- All alternatives still require engine collision and reach checks.
      local failed=stand
      task.standoff_tried_0338=task.standoff_tried_0338 or {}
      task.standoff_tried_0338[standoff_key(failed)]=true
      local alternate=non_ghost_standoff(pair,task,failed,true)
      if not alternate then
       sync_custody(pair,task,"construction-site-all-contacts-stalled")
       return{processed=1,blocked=1,waiting=1,detail="construction-site-all-contacts-stalled"}
      end
      stand=alternate
      task.build_standoff_0338=stand
      task.move_site_replans_0338=(tonumber(task.move_site_replans_0338)or 0)+1
      task.move_site_progress_tick_0338=now()
      task.move_site_last_position_0338={x=pair.priest.position.x,y=pair.priest.position.y}
      task.move_site_best_remaining_0338=math.sqrt(dist_sq(pair.priest.position,stand))
      record(pair,"approach-contact-stalled-replanned",
        safe(task.move_site_replans_0338).." priest="..
        safe(pair.priest.position.x)..","..safe(pair.priest.position.y)..
        " site="..safe(task.position.x)..","..safe(task.position.y)..
        " previous="..safe(failed.x)..","..safe(failed.y)..
        " next="..safe(stand.x)..","..safe(stand.y)..
        " remaining="..safe(remaining).." best="..safe(best))
     end
    end
    if not stand then
     sync_custody(pair,task,"construction-site-no-safe-standoff")
     return{processed=1,blocked=1,waiting=1,detail="construction-site-no-safe-standoff"}
    end
    destination,move_reason,move_radius=stand,"construction-site-standoff-0338",
      task.entity_name=="wooden-chest" and 0.08 or 0.3
   end
   if not request_move_position(pair,destination,move_reason,move_radius)then
    -- Movement arbitration can temporarily refuse a new route even while
    -- the builder holds a real item. Keep the engine-owned source debit and
    -- its 0338 custody intact; retry until the existing finite travel
    -- deadline, when abort_pair physically returns the same item.
    task.movement_denials_0338=(tonumber(task.movement_denials_0338)or 0)+1
    sync_custody(pair,task,"construction-site-route-denied")
    return{processed=1,blocked=1,waiting=1,detail="construction-site-route-denied"}
   end
   task.movement_denials_0338=nil
   return{processed=1,waiting=1,detail="moving-site"}
  end
  task.phase="build"
 end
local function safely_clear_of_ghost(pair,task)
 local ghost=task and task.ghost
 if not (valid_pair(pair) and valid(ghost)) then return false end
 local ok,box=pcall(function()return ghost.selection_box end)
 if not(ok and box)then return false end
 local lt=box.left_top or box[1]
 local rb=box.right_bottom or box[2]
 if not(lt and rb and lt.x and lt.y and rb.x and rb.y)then return false end
 local p=pair.priest.position
 local dx=math.max(lt.x-p.x,0,p.x-rb.x)
 local dy=math.max(lt.y-p.y,0,p.y-rb.y)
 -- Clearance from the *world-space* footprint, plus actual build reach.
 -- A movement controller need not hit an arbitrarily precise waypoint if
 -- the priest is already far enough outside the ghost collision area.
 return dx*dx+dy*dy>=0.25
   and site_build_distance_sq(p,task)<=M.build_reach_sq
end
 if task.phase=="move-clear-site" then
  -- The site-clear phase must share the original finite obstruction budget.
  -- Replanning physical contacts cannot extend an immovable blockage forever.
  if not valid(task.ghost) and task.site_blocked_since_0338
    and now()-task.site_blocked_since_0338>60*10 then
   task.failure_reason_0338="site-invalid:engine-revalidated"
   task.phase="return-custody"
   sync_custody(pair,task,task.failure_reason_0338)
   return return_custody(pair,task)
  end
  local stand=task.build_standoff_0338
  if not stand then task.failure_reason_0338="no-safe-build-standoff";task.phase="return-custody";return return_custody(pair,task)end
  if not valid(task.ghost) then
   -- Center distance is NOT collision clearance. A priest can stand 1.2
   -- tiles from a receiver center and still overlap its footprint. Only
   -- Factorio's actual placement check authorizes leaving this phase.
   local clear,why=site_still_valid(pair,task)
   if not clear then
    if why~="engine-revalidated" then
     task.failure_reason_0338="site-check-failed:"..safe(why)
     task.phase="return-custody"
     return return_custody(pair,task)
    end
    diagnose_receiver_site(pair,task)
    local priest_clear,clearance_known=chest_contact_clears_priest(
      pair,task,pair.priest.position)
    if clearance_known and priest_clear then
     -- Native drill output can leave a REAL item-on-ground on this tile.
     -- A physical pickup into persistent engine cargo and counted return
     -- must precede any chest construction. Static obstructions still wait.
     if (tonumber(task.ground_cleared_0338)or 0)<4 then
      local loose=receiver_ground_item(pair,task)
      if loose then
       if ground_cargo_count(task)>0 then
        task.phase="clear-ground-return"
        return{processed=1,waiting=1,detail="ground-cargo-return-before-next-pickup"}
       end
       task.ground_source_0338=loose
       task.phase="clear-ground-pickup"
       task.ground_detour_started_tick_0338=task.ground_detour_started_tick_0338 or now()
       sync_custody(pair,task,"real-ground-obstruction")
       return{processed=1,waiting=1,detail="ground-item-requires-physical-clearance"}
      end
     end
     sync_custody(pair,task,"external-site-obstruction")
     return{processed=1,blocked=1,waiting=1,
       detail="external-site-obstruction-awaiting-clearance"}
    end
    -- Native engine: accepted movement can stop short of a collision-clear
    -- contact. After 180 ticks without 0.2 tiles of actual progress, rotate
    -- the physical destination, retaining the original item and deadline.
    if dist_sq(pair.priest.position,stand)>0.04 then
     local previous=task.move_clear_last_position_0338
     if not previous or dist_sq(pair.priest.position,previous)>=0.04 then
      task.move_clear_last_position_0338={x=pair.priest.position.x,y=pair.priest.position.y}
      task.move_clear_progress_tick_0338=now()
     elseif now()-(tonumber(task.move_clear_progress_tick_0338)or now())>=180 then
      task.standoff_tried_0338=task.standoff_tried_0338 or {}
      task.standoff_tried_0338[standoff_key(stand)]=true
      local alternate=non_ghost_standoff(pair,task,stand,true)
      if not alternate then
       sync_custody(pair,task,"construction-clear-site-all-contacts-stalled")
       return{processed=1,blocked=1,waiting=1,
         detail="construction-clear-site-all-contacts-stalled"}
      end
      stand=alternate
      task.build_standoff_0338=stand
      task.move_clear_replans_0338=(tonumber(task.move_clear_replans_0338)or 0)+1
      task.move_clear_last_position_0338={x=pair.priest.position.x,y=pair.priest.position.y}
      task.move_clear_progress_tick_0338=now()
      record(pair,"blocked-site-contact-stalled-replanned",safe(task.move_clear_replans_0338))
     end
    end
    if dist_sq(pair.priest.position,stand)<=0.04 then
     -- Never oscillate between the same reached-but-blocked contacts.
     -- Primitive keys survive save/reload with the original custody.
     task.standoff_tried_0338=task.standoff_tried_0338 or {}
     task.standoff_tried_0338[standoff_key(stand)]=true
     local alternative=non_ghost_standoff(pair,task,stand)
     if not alternative then
      sync_custody(pair,task,"all-physical-site-contacts-blocked")
      return{processed=1,waiting=1,blocked=1,detail="all-physical-site-contacts-blocked"}
     end
     task.build_standoff_0338=alternative
     stand=alternative
     task.move_clear_last_position_0338=nil
     task.move_clear_progress_tick_0338=nil
     task.standoff_replans_0338=(tonumber(task.standoff_replans_0338)or 0)+1
     record(pair,"site-contact-replanned",safe(task.standoff_replans_0338))
    end
    if not request_move_position(pair,stand,"construction-clear-occupied-site-0338",
      task.entity_name=="wooden-chest" and 0.08 or 0.3) then
     -- Keep the real carried item and retry only within the bounded site
     -- obstruction deadline. A refused movement is not permission to build.
     sync_custody(pair,task,"site-clear-route-denied")
     return{processed=1,waiting=1,blocked=1,detail="site-clear-route-denied"}
    end
    return{processed=1,waiting=1,detail="clearing-occupied-site"}
   end
  elseif not safely_clear_of_ghost(pair,task) and dist_sq(pair.priest.position,stand)>0.16 then
   if not request_move_position(pair,stand,"construction-clear-ghost-footprint-0338",0.3) then
    -- 1201: a single temporary movement-arbitration refusal is not a
    -- permanent site failure. Keep the already-debited machine and exact
    -- construction custody; retry this same route under the existing
    -- finite construction_active_timeout rather than refunding at once.
    -- Neither a remote ghost revival nor a second inventory debit is allowed.
    task.ghost_clear_denials_0338=(tonumber(task.ghost_clear_denials_0338)or 0)+1
    sync_custody(pair,task,"ghost-clear-route-denied")
    return{processed=1,waiting=1,blocked=1,detail="ghost-clear-route-denied"}
   end
   task.ghost_clear_denials_0338=nil
   return{processed=1,waiting=1,detail="clearing-build-footprint"}
  end
  task.phase="build"
 end
 if task.phase=="build"then
  local ok,why=site_still_valid(pair,task)
  if not ok then
   if not valid(task.ghost) and why=="engine-revalidated" and task.carried then
    -- A moving priest can briefly occupy the exact 1x1 receiver tile.
    -- Wait for the real engine obstruction to clear; never skip the check.
    -- Static obstructions expire and refund the original item.
    task.site_blocked_since_0338=task.site_blocked_since_0338 or now()
    diagnose_receiver_site(pair,task)
    if now()-task.site_blocked_since_0338<=60*10 then
     local stand=non_ghost_standoff(pair,task)
     if stand then
      task.build_standoff_0338=stand
      task.move_clear_last_position_0338=nil
      task.move_clear_progress_tick_0338=nil
      task.phase="move-clear-site"
     end
     sync_custody(pair,task,"engine-site-obstructed")
     return{processed=1,waiting=1,blocked=1,detail="engine-site-obstructed-retry"}
    end
   end
   task.failure_reason_0338="site-invalid:"..safe(why)
   task.phase="return-custody"
   sync_custody(pair,task,task.failure_reason_0338)
   return return_custody(pair,task)
  end
  task.site_blocked_since_0338=nil
  local built,build_why=create_entity(pair,task)
  if not built then
   -- A ghost revival may be refused because the builder or another moving
   -- actor occupies its footprint. Preserve exact item custody, walk aside
   -- outside the real ghost selection box and retry at most twice. Static
   -- blockers still fail closed and return the unchanged item to storage.
   if build_why=="ghost-revive-refused" and valid(task.ghost)
      and (tonumber(task.revive_reposition_attempts_0338)or 0)<2 then
    task.revive_reposition_attempts_0338=(tonumber(task.revive_reposition_attempts_0338)or 0)+1
    local margin=task.revive_reposition_attempts_0338==1 and 1.5 or 1.8
    task.build_standoff_0338=source_approach_position(pair,task.ghost,margin,true)
    if task.build_standoff_0338 then
     task.phase="move-clear-site"
     return{processed=1,waiting=1,detail="revival-refused-reposition"}
    end
   end
   task.failure_reason_0338=build_why;task.phase="return-custody";sync_custody(pair,task,build_why)
   return return_custody(pair,task)
  end
  if task.carried then task.carried.count=0 end
  pair.construction_custody_0338=nil
  stat("entities-built");if task.creative_build then stat("creative-entities-built")end
  if ground_cargo_count(task)>0 then
   -- Chest is real and spent; ground ore is still held by the builder.
   -- Do not complete the native mission or authorize fuel until this
   -- same LuaInventory has been physically returned and counted home.
   task.ground_built_entity_0338=built
   task.ground_build_reason_0338=build_why
   task.phase="clear-ground-return"
   return{processed=1,waiting=1,detail="receiver-built-ground-cargo-return-pending"}
  end
  return finish(pair,task,built,build_why)
 end
 return{processed=1,failed=1,detail="unknown-phase:"..safe(task.phase)}
end
function M.service_all(reason,budget)
 local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);local state=M.root();local limit=math.min(#list,math.max(0,math.floor(tonumber(budget)or M.max_pairs_per_discovery)));if limit==0 then return{processed=0,acted=0,detail="no-pairs"}end;local start=state.cursor%#list+1;local failed=0;for offset=0,limit-1 do local pair=list[((start+offset-1)%#list)+1].pair;local ok=pcall(M.discover_pair,pair,false);if not ok then failed=failed+1 end end;state.cursor=(start+limit-2)%#list+1;return{processed=limit,acted=0,failed=failed,exhausted=#list>limit,detail="pairs="..limit.." failed="..failed}
end
function M.describe_pair(pair)if not pair then return"No pair."end;local task=pair.construction_task_0338;if task then return"Construction "..safe(task.entity_name).." phase="..safe(task.phase).." site="..safe(task.position and(task.position.x..","..task.position.y))end;local c=pair.construction_candidate_0338;if c then return"Construction candidate "..safe(c.entity_name).." reason="..safe(c.site_reason)end;return"No construction work."end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
local function register_service()
 local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="construction_discovery_0338",category="construction",interval=M.discovery_interval,priority=58,budget=M.max_pairs_per_discovery,note="discovery only; dispatcher owns physical construction",fn=function(_,budget)return M.service_all("broker-discovery",budget)end});return service~=nil
end
local function register_native_robot_receipt_0338()
 if not(script and type(script.on_event)=="function"
   and defines and defines.events and defines.events.on_robot_built_entity)then
  -- Pure source fixtures without Factorio's event API retain their normal
  -- direct-executor tests; native production must register the real event.
  return not(script and type(script.on_event)=="function")
 end
 local ok,registry=pcall(require,"scripts.core.runtime_event_registry")
 if not(ok and registry and type(registry.on_event)=="function")then
  return false
 end
 local registered,route=pcall(registry.on_event,
  defines.events.on_robot_built_entity,function(event)
   M.observe_native_robot_build_0338(event)
  end,nil,{owner="construction-planner-0338",
    route="native-robot-station-receipt",priority=20})
 return registered and route~=nil and route~=false
end
function M.install()M.root();register_creative_command();_G.TechPriestsConstructionPlanner0338=M;_G.TECH_PRIESTS_CONSTRUCTION_PLANNER=M;if not register_service()then return false end;if not register_native_robot_receipt_0338()then return false end;if log then log("[Tech-Priests recovery] dispatcher-owned construction planner armed; defense effectiveness and exact custody enabled")end;return true end
return M
