-- Tech Priests 1076: Magos-directed physical roboport/power frontier.
-- Planner only: the existing 0338 priest executor owns ALL item movement and
-- entity creation. 0714 remains read-only. No free poles, power or robots.
local M={version="0.1.676.1076",step=36,max_segments=24,
  max_poles_per_segment=24,scan_radius=96,scan_limit=64,
  interval=397,planner_budget=2,settle_ticks=60*30}
local function tick() return game and game.tick or 0 end
local function valid(e) return e and e.valid==true end
local function point(p) return {x=p.x,y=p.y} end
local function d2(a,b)
  local x=a.x-b.x; local y=a.y-b.y; return x*x+y*y
end
local function distance(a,b) return math.sqrt(d2(a,b)) end
-- Factorio snaps one-tile pole centers by up to half a tile on BOTH
-- axes. Euclidean radius 0.6 rejects the legitimate diagonal (0.5,0.5)
-- native placement. Require same native tile, not an adjacent tile; the
-- 0338 receipt's exact request, built LuaEntity and grid are checked below.
local function same(a,b)
  return a and b and math.abs(a.x-b.x)<=0.5001
    and math.abs(a.y-b.y)<=0.5001
end
local function live(pair)
  return valid(pair and pair.station) and valid(pair.priest)
    and pair.station.name=="planetary-magos-cogitator-station"
end
local function power_id(pole)
  local ok,id=pcall(function() return pole.electric_network_id end)
  return ok and tonumber(id) and id>0 and id or nil
end
local function grid_port(port)
  if not(valid(port) and port.type=="roboport")then
    return nil,"invalid-roboport"
  end
  local connected=false
  pcall(function() connected=port.is_connected_to_electric_network() end)
  if not connected or (tonumber(port.energy)or 0)<=0 then
    return nil,"roboport-not-powered"
  end
  local electric_id=power_id(port)
  if not electric_id then
    return nil,"roboport-electric-network-unidentified"
  end
  local cell,network
  pcall(function() cell=port.logistic_cell end)
  if not(cell and cell.valid~=false and cell.transmitting~=false)then
    return nil,"roboport-logistic-cell-inactive"
  end
  -- Physical port placement/removal can invalidate a native network
  -- between observations. Read identity inside the protected call, never
  -- access a stale LuaLogisticNetwork field to authorize construction.
  local ok,network_id,network_force=pcall(function()
    network=cell.logistic_network
    if not network or network.valid~=true then return nil,nil end
    return network.network_id,network.force
  end)
  if not(ok and type(network_id)=="number" and network_id>0
    and network_force==port.force)then
    return nil,"no-native-logistic-network"
  end
  return {cell=cell,network=network,network_id=network_id,
    electric_network_id=electric_id}
end
local function find(pair,filter,category,require_fresh)
  local router=rawget(_G,"TechPriestsScanRouting0610")
  if not(router and type(router.find_entities)=="function")then
    return nil,"canonical-scan-unavailable"
  end
  local ok,result=pcall(router.find_entities,pair.station.surface,filter,
    {category=category or "construction",limit=filter.limit,
      -- A just-built pole/port can be absent from the 0579 industrial
      -- index even though 0338 holds its native LuaEntity receipt.
      -- Only exact physical site verification requires a fresh scan.
      require_fresh=require_fresh==true,record_negative=false})
  if not ok or type(result)~="table"then
    return nil,"canonical-scan-failed"
  end
  return result
end
local function prototype(entity_name,item_name,type_name)
  local p=prototypes and prototypes.entity and prototypes.entity[entity_name]
  local i=prototypes and prototypes.item and prototypes.item[item_name]
  local result
  if i then pcall(function() result=i.place_result end)end
  if not(p and p.type==type_name and result
     and result.name==entity_name)then return nil end
  return p
end
local function can_place(pair,name,pos)
  local ok,allowed=pcall(function()
    return pair.station.surface.can_place_entity{
      name=name,position=pos,force=pair.station.force}
  end)
  return ok and allowed==true
end
local function port_at(pair,pos)
  local entities=find(pair,{
    type="roboport",position=pos,radius=0.75,
    force=pair.station.force,limit=3},nil,true)
  for _,e in pairs(entities or {})do
    if valid(e) and e.surface==pair.station.surface
      and same(e.position,pos)then return e end
  end
end
local function pole_at(pair,pos,name)
  local entities=find(pair,{
    name=name,position=pos,radius=0.75,
    force=pair.station.force,limit=3},nil,true)
  for _,e in pairs(entities or {})do
    if valid(e) and same(e.position,pos)then return e end
  end
end
local function goal_for(pair)
  local specified=pair.roboport_expansion_goal_1076
  local rail=pair.remote_rail_outpost_0835
  local g=specified
  if not g and rail
    and (rail.status=="starvation-confirmed"
      or rail.status=="building-physical-rail")then
    g=rail.target
  end
  if type(g)~="table"then return nil end
  local target=g.target or g.position or g
  if type(target)~="table" or type(target.x)~="number"
    or type(target.y)~="number"then return nil end
  if g.root_station_unit and g.root_station_unit~=pair.station.unit_number then return nil end
  if g.force_index and g.force_index~=pair.station.force.index then return nil end
  if g.surface_index and g.surface_index~=pair.station.surface.index then return nil end
  if distance(pair.station.position,target)>M.step*M.max_segments then
    return nil
  end
  return point(target)
end
local function choose_origin(pair,goal,options)
  options=options or {}
  local entities,reason=find(pair,{
    type="roboport",force=pair.station.force,
    position=options.center or pair.station.position,radius=M.scan_radius,
    limit=M.scan_limit})
  if not entities then return nil,reason end
  local best,best_score
  for _,port in ipairs(entities)do
    if valid(port) and port.force==pair.station.force then
      local readiness=grid_port(port)
      if readiness
        and (not options.electric_network_id
          or readiness.electric_network_id==options.electric_network_id)
        and (not options.logistic_network_id
          or readiness.network_id==options.logistic_network_id)then
        local score=distance(port.position,goal)
        if not best or score<best_score then
          best,best_score={port=port,network_id=readiness.network_id},score
        end
      end
    end
  end
  return best,best and "native-powered-origin" or "no-powered-roboport"
end
local covered
-- Factorio 2.0 exposes electric-pole geometry as quality-aware prototype
-- methods, not LuaEntityPrototype fields. Fail closed if a prototype cannot
-- report its actual supply/wire reach; never guess or authorize a build.
local function pole_supply(proto)
  local ok,value=pcall(function() return proto.get_supply_area_distance() end)
  return ok and tonumber(value) or 0
end
local function pole_wire(proto)
  local ok,value=pcall(function() return proto.get_max_wire_distance() end)
  return ok and tonumber(value) or 0
end
local function choose_anchor(pair,port,goal)
  local cell=grid_port(port)
  if not cell then return nil,"power-anchor-roboport-inactive" end
  local poles,reason=find(pair,{
    type="electric-pole",force=pair.station.force,
    position=port.position,radius=M.scan_radius,limit=M.scan_limit})
  if not poles then return nil,reason end
  local best,score
  local claimed=power_id(port)
  if not claimed then return nil,"source-roboport-electric-network-unidentified" end
  for _,pole in ipairs(poles)do
    local id=valid(pole) and pole.force==pair.station.force
      and power_id(pole) or nil
    local supply=pole_supply(pole.prototype)
    local reach=pole_wire(pole.prototype)
    -- Existing connected poles farther toward the goal can be reused:
    -- the source port independently proves this SAME electric network ID.
    -- Never rebuild an identical run of poles after losing only the port.
    if id and reach>2 and supply>0
      and id==claimed
      and covered(cell.cell,pole.position,"construction") then
      local d=distance(pole.position,goal)
      if not best or d<score then
        best={pole=pole,grid_id=id};score=d
      end
    end
  end
  return best,best and "physical-grid-anchor" or "no-proven-powered-grid-anchor"
end
covered=function(cell,pos,kind)
  local method=kind=="logistic" and "is_in_logistic_range"
    or "is_in_construction_range"
  local ok,result=pcall(function() return cell[method](pos) end)
  return ok and result==true
end
local function complete_coverage(port,target)
  local live_port=grid_port(port)
  return live_port and covered(live_port.cell,target,"construction")
    and covered(live_port.cell,target,"logistic")
end
local worker_for,resolve_worker
local function derive_site(pair,source,target)
  local portp=prototype("roboport","roboport","roboport")
  if not portp then return nil,"roboport-item-or-prototype-unavailable" end
  local from=source.position
  local delta=distance(from,target)
  if delta<5 then return nil,"target-too-close-to-source-port" end
  local step=math.min(M.step,delta)
  local ux=(target.x-from.x)/delta
  local uy=(target.y-from.y)/delta
  local cx=math.floor(from.x+ux*step+0.5)
  local cy=math.floor(from.y+uy*step+0.5)
  local builder=rawget(_G,"TechPriestsConstructionPlanner0338")
  if not(builder and type(builder.frontier_site_contact_0338)=="function")then
    return nil,"canonical-priest-contact-preflight-unavailable"
  end
  local original=grid_port(source)
  if not original then return nil,"source-roboport-lost-power-or-network" end
  -- Native 1080 built three connected poles, then stalled before its first
  -- port because the fixed 36-tile site was outside the Magos's authorized
  -- 0418 standoff. A pole chain must not target a port the original physical
  -- builder cannot reach. Prefer the farthest VALID location; test shorter
  -- progression distances without relaxing native wire/grid/robot coverage.
  -- Native 41560203624: after the first real port at x=38, the
  -- shortest examined site was still 16 tiles away. A second port just
  -- beyond the existing 4x4 footprint can be reachable under the SAME
  -- 0338/0418 authority. Examine bounded shorter advances as well;
  -- keep >5 tiles of progress, real power/coverage and physical stock.
  for _,retreat in ipairs({0,4,8,12,16,20,24,28,30})do
    local bx=math.floor(cx-ux*retreat+0.5)
    local by=math.floor(cy-uy*retreat+0.5)
    for _,off in ipairs({{0,0},{0,4},{0,-4},{4,0},{-4,0},
          {0,8},{0,-8},{8,0},{-8,0}})do
      local pos={x=bx+off[1],y=by+off[2]}
      if covered(original.cell,pos,"construction")
        and distance(pos,target)<delta-5
        and distance(pos,from)>5
        and distance(pos,from)<=M.step+9
        and not port_at(pair,pos)
        and can_place(pair,"roboport",pos)then
        -- A live port must eventually join the SAME native logistics cell.
        local rad=tonumber(original.cell.logistic_radius)or 0
        local newrad=tonumber(source.logistic_cell.logistic_radius)or rad
        if rad>0 and newrad>0
          and math.abs(pos.x-from.x)<rad+newrad-4
          and math.abs(pos.y-from.y)<rad+newrad-4 then
          local worker=worker_for(pair,"roboport","roboport",pos)
          if worker then
            return pos,"site-with-connected-coverage-and-authorized-contact",
              worker.station.unit_number
          end
        end
      end
    end
  end
  return nil,"no-covered-roboport-site-with-authorized-priest-contact"
end
-- When a real pole chain reaches the Magos's legitimate movement boundary,
-- do not insist on another unreachable pole toward the original distant
-- port site. Reuse an ALREADY BUILT pole on the original electric grid and
-- choose a nearer, genuinely powered port footprint within the original
-- construction cell, native logistic overlap and 0338/0418 contact. This
-- changes only the proposed site; 0338 still debits and constructs the port.
local function reachable_port_from_existing_grid(pair,state)
  local origin=state.source_port
  local native=grid_port(origin)
  if not(native and native.electric_network_id==state.electric_network_id
    and native.network_id==state.logistic_network_id)then return nil end
  local radius=tonumber(native.cell.logistic_radius)or 0
  if radius<=0 then return nil end
  local builder=rawget(_G,"TechPriestsConstructionPlanner0338")
  if not(builder and type(builder.frontier_site_contact_0338)=="function")then
    return nil
  end
  -- Newly placed 0338 poles can be missing from the cached 0579 index.
  -- A fallback that reuses real built poles must inspect live Factorio
  -- entities. This is one bounded exception scan on an actual dead end,
  -- not a recurring broad per-tick search.
  local poles=find(pair,{type="electric-pole",force=pair.station.force,
    position=origin.position,radius=M.scan_radius,limit=M.scan_limit},
    "construction",true)
  if not poles then return nil end
  local from,target=origin.position,state.target
  local baseline=distance(from,target)
  local best,best_pole,best_score,best_worker
  for _,pole in ipairs(poles)do
    if valid(pole) and pole.force==pair.station.force
      and pole.surface==pair.station.surface
      and power_id(pole)==state.electric_network_id
      and covered(native.cell,pole.position,"construction")then
      local supply=pole_supply(pole.prototype)
      local remaining=distance(pole.position,target)
      if supply>0 and remaining>0.1 then
        local ux=(target.x-pole.position.x)/remaining
        local uy=(target.y-pole.position.y)/remaining
        for _,forward in ipairs({4,3,5,2,6})do
          for _,side in ipairs({0,2,-2,4,-4})do
            local pos={x=math.floor(pole.position.x+ux*forward-uy*side+0.5),
              y=math.floor(pole.position.y+uy*forward+ux*side+0.5)}
            local dx=math.abs(pos.x-pole.position.x)
            local dy=math.abs(pos.y-pole.position.y)
            local score=distance(pos,target)
            if dx<=supply+1.5 and dy<=supply+1.5
              and (dx>=2.75 or dy>=2.75)
              and score<baseline-5
              and distance(pos,from)>5
              and distance(pos,from)<=M.step+9
              and math.abs(pos.x-from.x)<radius*2-4
              and math.abs(pos.y-from.y)<radius*2-4
              and covered(native.cell,pos,"construction")
              and not port_at(pair,pos)
              and can_place(pair,"roboport",pos)then
              local worker=worker_for(pair,"roboport","roboport",pos)
              if worker and (not best or score<best_score)then
                best,best_pole,best_score,best_worker=
                  pos,pole,score,worker.station.unit_number
              end
            end
          end
        end
      end
    end
  end
  return best,best_pole,best_worker
end
local function builder_available(pair)
  return not(pair.construction_task_0338
    or pair.construction_custody_0338
    or pair.construction_candidate_0338
    or pair.construction_request
    or pair.robot_network_task_0338
    or pair.robot_network_request_0338
    or pair.remote_drill_request_1011)
end
-- The Magos retains strategic authority. A genuine ranked Senior may
-- execute a later 0338 build only with its OWN physically stocked source,
-- original 0418 contact, and live direct-subordinate identity. This does
-- not transfer items or expand either priest's movement authority.
resolve_worker=function(root,unit)
  if not(live(root) and type(unit)=="number")then return nil end
  if unit==root.station.unit_number then return root end
  local tp=storage and storage.tech_priests
  local child=tp and tp.pairs_by_station and tp.pairs_by_station[unit]
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not(child and valid(child.station) and valid(child.priest)
    and child.station.unit_number==unit
    and child.station.surface==root.station.surface
    and child.station.force==root.station.force
    and hierarchy and type(hierarchy.rank)=="function"
    and type(hierarchy.is_direct_subordinate)=="function")then return nil end
  local ok,eligible=pcall(function()
    return hierarchy.rank(root)==4 and hierarchy.rank(child)==3
      and hierarchy.is_direct_subordinate(root,child)==true
  end)
  return ok and eligible and child or nil
end
worker_for=function(root,name,item,pos)
  local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
  if not(planner and type(planner.frontier_site_contact_0338)=="function"
    and authority and type(authority.generic_item_count)=="function")then
    return nil
  end
  local function eligible(worker,require_stock)
    if not worker then return false end
    if worker==root then
      -- Root's existing 0338 yield authority must decide whether a
      -- bootstrap candidate is physically funded; a candidate alone is
      -- not active cargo and must not disappear during site preflight.
      if worker.construction_task_0338 or worker.construction_custody_0338
        or worker.construction_request or worker.robot_network_task_0338
        or worker.robot_network_request_0338
        or worker.remote_drill_request_1011 then return false end
    elseif not builder_available(worker)then return false end
    if require_stock then
      local stocked,count=pcall(authority.generic_item_count,worker,item)
      if not(stocked and tonumber(count) and count>=1)then return false end
    end
    local ok,stand=pcall(planner.frontier_site_contact_0338,
      worker,name,pos)
    return ok and stand~=nil and stand~=false
  end
  -- Prefer physically stocked owners. Preserve the existing unfunded Magos
  -- wait path so 0338 can report missing materials without inventing a
  -- different construction site or losing the mission's original request.
  if eligible(root,true)then return root end
  local tp=storage and storage.tech_priests
  local ids={}
  for id in pairs(tp and tp.pairs_by_station or {})do
    if type(id)=="number" and id~=root.station.unit_number then
      ids[#ids+1]=id
    end
  end
  table.sort(ids)
  for _,id in ipairs(ids)do
    local worker=resolve_worker(root,id)
    if worker and eligible(worker,true)then return worker end
  end
  if eligible(root,false)then return root end
  return nil
end
local function submit(pair,state,name,item,pos,kind,root_unit)
  -- Only 0338 can release its own *unfunded, unstarted* discovery
  -- candidate. Never clear a live task, reserved site or carried item.
  if pair.construction_candidate_0338 or pair.construction_bootstrap_ghost_0645 then
    local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
    if not(planner and type(planner.yield_unfunded_frontier_candidate_0338)=="function")then
      return false,"canonical-builder-occupied:0338-yield-unavailable"
    end
    local ok,allowed,reason=pcall(
      planner.yield_unfunded_frontier_candidate_0338,pair)
    if not(ok and allowed==true)then
      return false,"canonical-builder-occupied:"..tostring(ok and reason or allowed)
    end
  end
  if not builder_available(pair)then return false,"canonical-builder-occupied" end
  -- Avoid claiming a long-lived 0338 site reservation when no real part
  -- exists. The original 0338 executor still owns exact pickup and debit.
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
  if not(authority and type(authority.generic_item_count)=="function")then
    return false,"physical-stock-observer-unavailable"
  end
  local ok,available=pcall(authority.generic_item_count,pair,item)
  if not(ok and tonumber(available) and available>=1)then
    return false,"waiting-real-power-or-roboport-item"
  end
  if not can_place(pair,name,pos)then return false,"engine-site-obstructed" end
  local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
  if not(planner and type(planner.frontier_site_contact_0338)=="function")then
    return false,"canonical-priest-contact-preflight-unavailable"
  end
  local checked,stand,why=pcall(planner.frontier_site_contact_0338,pair,name,pos)
  if not(checked and stand)then
    return false,"canonical-priest-contact-refused:"..tostring(checked and why or stand)
  end
  local request={item_name=item,entity_name=name,
    category=kind=="pole" and "emergency-power-pole" or "utility-roboport",
    position=point(pos),site_reason="powered-roboport-frontier-1076",
    frontier_root_unit_1076=root_unit or pair.station.unit_number,
    frontier_builder_unit_1076=pair.station.unit_number}
  pair.construction_request=request
  state.pending={kind=kind,request=request,position=point(pos),
    entity_name=name,started_tick=tick(),
    builder_station_unit=pair.station.unit_number}
  state.status="awaiting-priest-physical-build"
  return true,"submitted-to-canonical-0338"
end
local function fail(state,reason)
  state.status="blocked";state.blocked_reason=reason
  state.last_update_tick=tick()
  -- A real 0338-built pole/port can join the original grid after settling.
  -- Retain the exact receipt and custody; never debit a second item.
  if reason=="built-pole-not-connected-to-original-grid"
    or reason=="built-roboport-power-or-logistic-merge-unverified"then
    state.grid_retry_attempts=(state.grid_retry_attempts or 0)+1
    state.grid_retry_after_tick=tick()+math.min(
      M.settle_ticks,300*state.grid_retry_attempts)
  end
  return {processed=1,blocked=1,detail=reason}
end
local function verify_pending(pair,state)
  local p=state.pending
  if not p then return nil end
  local worker=resolve_worker(pair,p.builder_station_unit
    or pair.station.unit_number)
  if not worker then
    return fail(state,"frontier-builder-original-rank-or-identity-lost")
  end
  local last=worker.construction_last_task_0338
  if last and last.request_value==p.request and last.phase=="aborted"then
    -- A timed-out approach is recoverable ONLY after 0338 has returned the
    -- exact physical item to storage. Do not reissue while custody remains,
    -- or if an engine entity already occupies the formerly reserved site.
    local result=tostring(last.result or "")
    local site_timeout=result:find("^construction%-timeout:move%-site:")~=nil
    local source_timeout=result:find("^construction%-timeout:move%-source:")~=nil
    local refunded=result:find(";custody%-returned%-source$",1,false)
      or result:find(";custody%-stored$",1,false)
    -- Native 41516621302: the second pole timed out before pickup.
    -- 0338 reports ";empty-custody" when no item was ever removed.
    -- Retry only if the SAME recorded physical source still owns at least
    -- one real item on the original surface/force; no source debit, no
    -- inventory credit, no site completion and no custody shortcut.
    local source_stocked=false
    if source_timeout and result:find(";empty%-custody$")~=nil
      and last.item_name==p.request.item_name
      and valid(last.source_entity)
      and last.source_entity.surface==pair.station.surface
      and last.source_entity.force==pair.station.force
      and last.source_inv and last.source_inv.valid==true then
      local ok,remaining=pcall(function()
        return last.source_inv.get_item_count(last.item_name)
      end)
      source_stocked=ok and type(remaining)=="number" and remaining>=1
    end
    local no_cargo=not worker.construction_task_0338
      and not worker.construction_custody_0338
      and (not last.carried or (tonumber(last.carried.count)or 0)==0)
    local empty=p.kind=="pole" and not pole_at(pair,p.position,p.entity_name)
      or p.kind=="port" and not port_at(pair,p.position)
    local retries=tonumber(state.refunded_replans_1076)or 0
    if ((site_timeout and refunded) or source_stocked)
      and no_cargo and empty and retries<2
      and worker.construction_request==p.request
      and last.built_entity==nil then
      -- 0338 has already released its site reservation and physically
      -- refunded its item. Discard ONLY our original request identity;
      -- the next broker pulse must recheck real stock and a reachable site.
      worker.construction_request=nil
      state.last_aborted_receipt_1076=last
      state.refunded_replans_1076=retries+1
      state.pending=nil
      state.site=nil
      state.status="planning"
      state.last_update_tick=tick()
      return {processed=1,waiting=1,
        detail=source_stocked and "physically-stocked-frontier-source-replan"
          or "physically-refunded-frontier-site-replan"}
    end
    return fail(state,"physical-builder-aborted:"..tostring(last.failure_reason_0338 or last.result))
  end
  if not(last and last.request_value==p.request and last.phase=="complete"
    and valid(last.built_entity)
    and last.built_entity.name==p.entity_name
    and same(last.built_entity.position,p.position)
    and worker.construction_request==nil)then
    return {processed=1,waiting=1,detail="awaiting-counted-0338-build"}
  end
  local actual=p.kind=="pole" and pole_at(pair,p.position,p.entity_name)
    or port_at(pair,p.position)
  if not(actual and actual==last.built_entity)then
    return fail(state,"physical-built-entity-custody-mismatch")
  end
  if p.kind=="pole"then
    if power_id(actual)~=state.electric_network_id then
      if tick()-p.started_tick<M.settle_ticks then
        return {processed=1,waiting=1,detail="awaiting-real-pole-grid-connection"}
      end
      return fail(state,"built-pole-not-connected-to-original-grid")
    end
    state.power_anchor=actual
    state.poles_built=(state.poles_built or 0)+1
    if state.poles_built>M.max_segments*M.max_poles_per_segment then
      return fail(state,"power-pole-segment-cap")
    end
  else
    local new=grid_port(actual)
    local previous=grid_port(state.source_port)
    if not(new and previous and new.network_id==previous.network_id
      and new.electric_network_id==state.electric_network_id
      and previous.electric_network_id==state.electric_network_id)then
      if tick()-p.started_tick<M.settle_ticks then
        return {processed=1,waiting=1,detail="awaiting-native-powered-logistic-merge"}
      end
      return fail(state,"built-roboport-power-or-logistic-merge-unverified")
    end
    local pole=state.power_anchor
    if not(valid(pole) and power_id(pole)==state.electric_network_id)then
      return fail(state,"expanded-roboport-lost-verified-electric-grid")
    end
    -- Factorio may assign a new logistics-network ID when two physical
    -- cells merge. The native grid_port() readings above already prove that
    -- this EXACT built port and our previous port share the SAME live
    -- network, on the original electric grid. Adopt that verified current
    -- identity rather than treating a stale number as a network split.
    -- This changes bookkeeping only: no new coverage, item or entity.
    state.logistic_network_id=new.network_id
    state.source_port=actual
    state.last_source_position=point(actual.position)
    state.segments=(state.segments or 0)+1
    if state.segments>M.max_segments then return fail(state,"roboport-segment-cap")end
    state.site=nil
    state.site_builder_unit=nil
    state.power_anchor=nil
  end
  state.last_receipt=last
  state.pending=nil
  state.grid_retry_attempts=nil
  state.grid_retry_after_tick=nil
  state.blocked_reason=nil
  state.status="planning"
  state.last_update_tick=tick()
  return {processed=1,acted=1,detail=p.kind=="pole" and
    "physical-connected-power-pole-verified" or
    "physical-powered-logistic-roboport-verified"}
end
function M.service_pair(pair)
  if not live(pair)then return {processed=0,detail="not-live-magos"}end
  local goal=goal_for(pair)
  local s=pair.roboport_frontier_1076
  if not s and not goal then return {processed=0,detail="no-expansion-goal"}end
  -- Existing 0338 physical cargo and in-flight tasks take precedence over
  -- strategic site planning. Refuse before selecting new pole coordinates:
  -- the planner must neither preempt custody nor mask the refusal behind
  -- an unrelated site-geometry diagnostic. A previously submitted frontier
  -- receipt is still examined below without starting competing work.
  if (pair.construction_task_0338 or pair.construction_custody_0338)
      and not(s and s.pending)then
    return {processed=1,waiting=1,detail="canonical-builder-occupied"}
  end
  if not s then
    local source,why=choose_origin(pair,goal)
    if not source then return {processed=1,blocked=1,detail=why}end
    local anchor,other=choose_anchor(pair,source.port,goal)
    if not anchor then return {processed=1,blocked=1,detail=other}end
    s={version=M.version,target=goal,source_port=source.port,
      last_source_position=point(source.port.position),
      logistic_network_id=source.network_id,
      electric_network_id=anchor.grid_id,power_anchor=anchor.pole,
      status="planning",segments=0,poles_built=0,started_tick=tick()}
    pair.roboport_frontier_1076=s
  end
  if s.status=="blocked" then
    local reason=s.blocked_reason
    if s.pending and (reason=="built-pole-not-connected-to-original-grid"
      or reason=="built-roboport-power-or-logistic-merge-unverified")then
      if tick()<(s.grid_retry_after_tick or tick())then
        return {processed=1,waiting=1,
          detail="awaiting-original-grid-recheck:"..tostring(reason)}
      end
      -- Recheck the same completed 0338 receipt against live native grid IDs.
      return verify_pending(pair,s)
    end
    return {processed=1,detail="blocked:"..tostring(reason or "")}
  end
  if s.status=="complete"then
    local confirmed=grid_port(s.source_port)
    if confirmed
      and confirmed.electric_network_id==s.electric_network_id
      and confirmed.network_id==s.logistic_network_id
      and complete_coverage(s.source_port,s.target)then
      return {processed=1,detail="verified-existing-covered-frontier"}
    end
    -- A lost port or separated grid invalidates completion immediately.
    -- Never return a stale success; rejoin from surviving real infrastructure.
    s.status="recovering"
    s.coverage_loss_tick=tick()
    s.site=nil
    s.power_anchor=nil
  end
  if s.status=="recovering" then
    local recovered,why=choose_origin(pair,s.target,{
      center=s.last_source_position or pair.station.position,
      electric_network_id=s.electric_network_id,
      logistic_network_id=s.logistic_network_id})
    if not recovered then return {processed=1,waiting=1,
      detail="awaiting-original-powered-network:"..tostring(why)}end
    local anchor,reason=choose_anchor(pair,recovered.port,s.target)
    if not anchor or anchor.grid_id~=s.electric_network_id then
      return {processed=1,waiting=1,
        detail="awaiting-original-grid-pole:"..tostring(reason)}
    end
    s.source_port=recovered.port
    s.power_anchor=anchor.pole
    s.last_source_position=point(recovered.port.position)
    s.site=nil
    s.recovery_attempts=(s.recovery_attempts or 0)+1
    s.status="planning"
  end
  if s.pending then return verify_pending(pair,s)end
  local source=grid_port(s.source_port)
  if not source then return fail(s,"source-roboport-lost-power-or-network")end
  if source.electric_network_id~=s.electric_network_id
    or (s.logistic_network_id and
      source.network_id~=s.logistic_network_id)then
    return fail(s,"source-roboport-original-network-diverged")
  end
  if complete_coverage(s.source_port,s.target)then
    s.status="complete";s.completed_tick=tick()
    return {processed=1,acted=0,detail="actual-logistic-and-construction-coverage-at-goal"}
  end
  if s.segments>=M.max_segments then
    return fail(s,"maximum-verified-expansion-segments")
  end
  if not s.site then
    local site,reason,worker_unit=derive_site(pair,s.source_port,s.target)
    if not site then return fail(s,reason)end
    s.site=site
    s.site_builder_unit=worker_unit
  end
  if not s.power_anchor and s.segments>0 then
    -- A validated new roboport is the next logistics frontier, but electrical
    -- continuity must be independently re-anchored for each new segment.
    local next_anchor,reason=choose_anchor(pair,s.source_port,s.target)
    if not next_anchor then return fail(s,reason)end
    if next_anchor.grid_id~=s.electric_network_id then
      return fail(s,"new-frontier-connected-to-different-electric-grid")
    end
    s.power_anchor=next_anchor.pole
  end
  local anchor=s.power_anchor
  if not(valid(anchor) and power_id(anchor)==s.electric_network_id)then
    -- Never create a new isolated power system or credit an unpowered pole.
    return fail(s,"electric-source-disconnected")
  end
  local pole_name="medium-electric-pole"
  local polep=prototype(pole_name,pole_name,"electric-pole")
  if not polep then return fail(s,"medium-electric-pole-item-unavailable")end
  -- Terminate the pole chain just outside the 4x4 roboport footprint.
  local delta=distance(s.source_port.position,s.site)
  local ux=(s.site.x-s.source_port.position.x)/delta
  local uy=(s.site.y-s.source_port.position.y)/delta
  local terminus={x=math.floor(s.site.x-ux*4+0.5),
    y=math.floor(s.site.y-uy*4+0.5)}
  local supply=pole_supply(anchor.prototype)
  local dx=math.abs(anchor.position.x-s.site.x)
  local dy=math.abs(anchor.position.y-s.site.y)
  if supply>0 and dx<=supply+1.5 and dy<=supply+1.5 then
    -- The last PHYSICALLY CONNECTED pole must supply the port footprint.
    local worker=resolve_worker(pair,s.site_builder_unit
      or pair.station.unit_number)
    if not worker then return fail(s,"frontier-port-builder-identity-lost")end
    local ok,why=submit(worker,s,"roboport","roboport",s.site,
      "port",pair.station.unit_number)
    if not ok and type(why)=="string"
      and why:find("canonical-priest-contact",1,true)then
      return fail(s,why)
    end
    return {processed=1,waiting=not ok and 1 or nil,
      detail=why}
  end
  local anchor_range=pole_wire(anchor.prototype)
  local next_range=pole_wire(polep)
  local step=math.min(anchor_range,next_range)-1.5
  if step<2 then return fail(s,"insufficient-pole-wire-reach")end
  local remaining=distance(anchor.position,terminus)
  if remaining<0.5 then return fail(s,"pole-at-terminal-without-port-supply")end
  local unitx=(terminus.x-anchor.position.x)/remaining
  local unity=(terminus.y-anchor.position.y)/remaining
  local length=math.min(step,remaining)
  local x=math.floor(anchor.position.x+unitx*length+0.5)
  local y=math.floor(anchor.position.y+unity*length+0.5)
  local selected,selected_worker
  -- Native 2.0.77: a stocked first pole timed out before physical arrival.
  -- Try bounded shorter wire-connected sites that 0338/0418 can actually
  -- approach. Do not enlarge the Magos leash or invent construction reach.
  local builder=rawget(_G,"TechPriestsConstructionPlanner0338")
  if not(builder and type(builder.frontier_site_contact_0338)=="function")then
    return fail(s,"canonical-priest-contact-preflight-unavailable")
  end
  -- After a genuine 0338 refund, do not repeat the identical longest
  -- approach that timed out. Back off two more tiles per bounded retry;
  -- all candidates still require native wire reach and priest authorization.
  local minimum_retreat=math.min(4,2*(tonumber(s.refunded_replans_1076)or 0))
  for _,retreat in ipairs({0,2,4,6,8})do
    if retreat>=minimum_retreat then
    local bx=math.floor(x-unitx*retreat+0.5)
    local by=math.floor(y-unity*retreat+0.5)
    for _,offset in ipairs({{0,0},{0,2},{0,-2},{2,0},{-2,0}})do
      local candidate={x=bx+offset[1],y=by+offset[2]}
      if distance(candidate,anchor.position)>2
        and distance(candidate,anchor.position)<math.min(anchor_range,next_range)-0.25
        and distance(candidate,terminus)<remaining-1
        and covered(source.cell,candidate,"construction")
        and can_place(pair,pole_name,candidate)then
        local worker=worker_for(pair,pole_name,pole_name,candidate)
        if worker then
          selected=candidate
          selected_worker=worker
          break
        end
      end
    end
    if selected then break end
    end
  end
  if not selected then
    local port_site,connected_pole,worker_unit=
      reachable_port_from_existing_grid(pair,s)
    if port_site and connected_pole and worker_unit then
      local worker=resolve_worker(pair,worker_unit)
      if not worker then return fail(s,"frontier-fallback-builder-identity-lost")end
      s.site=port_site
      s.site_builder_unit=worker_unit
      s.power_anchor=connected_pole
      local ok,why=submit(worker,s,"roboport","roboport",
        port_site,"port",pair.station.unit_number)
      return {processed=1,waiting=not ok and 1 or nil,detail=why}
    end
    return fail(s,"no-wire-connected-pole-site-with-authorized-priest-contact")
  end
  local ok,why=submit(selected_worker,s,pole_name,pole_name,
    selected,"pole",pair.station.unit_number)
  return {processed=1,waiting=not ok and 1 or nil,detail=why}
end
function M.service_budgeted(_,budget)
  local tp=storage and storage.tech_priests
  if not tp then return {processed=0,acted=0,detail="no-storage"}end
  local candidates={}
  for id,pair in pairs(tp.pairs_by_station or{})do
    if live(pair) and id==pair.station.unit_number
      and (pair.roboport_frontier_1076 or goal_for(pair))then
      candidates[#candidates+1]={id=id,pair=pair}
    end
  end
  table.sort(candidates,function(a,b)return a.id<b.id end)
  local state=tp.roboport_expansion_broker_1076 or {cursor=0}
  tp.roboport_expansion_broker_1076=state
  local count=math.min(#candidates,math.max(0,math.floor(tonumber(budget)or M.planner_budget)))
  if count==0 then
    local reason=#candidates==0 and "no-active-goals" or "zero-service-budget"
    state.last_attempt={tick=tick(),detail=reason,
      candidates=#candidates,failed=false}
    return {processed=0,acted=0,detail=reason}
  end
  local start=state.cursor%#candidates+1
  local done,failures=0,0
  for i=0,count-1 do
    local candidate=candidates[(start+i-1)%#candidates+1]
    local pair=candidate.pair
    local ok,result=pcall(M.service_pair,pair)
    -- Preserve the exact native refusal/error behind the budgeted 0600
    -- dispatch. Previously a failed pcall was reduced to an anonymous count
    -- and a pre-initialization refusal left no trace of why no pole moved.
    -- This record contains only save-safe primitives, never item credit.
    local detail=ok and type(result)=="table"
      and tostring(result.detail or "no-detail")
      or "service-error:"..tostring(result)
    local frontier=pair.roboport_frontier_1076
    state.last_attempt={tick=tick(),station_unit=candidate.id,
      detail=detail,failed=not ok,
      status=type(frontier)=="table"
        and tostring(frontier.status or "not-initialized")
        or "not-initialized"}
    if not ok then
      failures=failures+1
      state.last_failure=state.last_attempt
    elseif result and result.acted then done=done+result.acted end
  end
  state.cursor=(start+count-1)%#candidates
  return {processed=count,acted=done,failed=failures,
    exhausted=#candidates>count,
    detail="verified-physical-build-receipts="..done}
end
function M.install()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(broker and type(broker.register_service)=="function")then
    return false,"canonical-broker-unavailable"
  end
  local service=broker.register_service{
    name="roboport_expansion_frontier_1076",category="construction",
    interval=M.interval,priority=55,budget=M.planner_budget,
    note="physical 0338 pole and roboport chain; real grid and coverage proof",
    fn=M.service_budgeted}
  if not service then return false,"broker-service-rejected"end
  _G.TechPriestsRoboportExpansionFrontier1076=M
  return true
end
return M
