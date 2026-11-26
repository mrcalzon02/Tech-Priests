-- scripts/core/construction_site_planner.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical read-only placement authority. It chooses coordinates only; it never
-- owns inventory, movement, construction execution, or ghosts. The shared
-- force planner alone advances saved search continuations.

local Queue = require("scripts.core.force_planning_queue")
local Metadata = require("scripts.core.planning_metadata_1507")

local Planner = {
  version = "0.1.674-dev",
  default_radius = 36,
  max_radius = 96,
  min_radius = 3,
  max_candidates_per_ring = 4096,
  threat_scan_limit = 128,
  placement_authority = true,
  read_only = true,
  effectiveness_scoring = true,
}

local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function dist_sq(a, b)
  if not (a and b) then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function constraints()
  local module = rawget(_G, "TechPriestsPlanningConstraints0646")
  if not module then
    local ok, loaded = pcall(require, "scripts.core.planning_constraints_0646")
    if ok then module = loaded end
  end
  return module
end
local function metadata_ready(pair)
  local policy=constraints()
  return not (policy and type(policy.request_metadata)=="function")
    or policy.request_metadata(pair.station.force)==true
end
local function routed_find(surface, filters, category, negative_key, ttl)
  local scan = rawget(_G, "TechPriestsScanRouting0610")
  if not scan then
    local ok, loaded = pcall(require, "scripts.core.scan_routing_0610")
    if ok then scan = loaded end
  end
  if scan and type(scan.find_entities) == "function" then
    local entities = select(1, scan.find_entities(surface, filters, {
      category = category or "construction",
      negative_key = negative_key,
      negative_ttl = ttl or 60 * 4,
    }))
    return entities or {}
  end
  -- Factorio LuaSurface methods take their filter table as the first argument;
  -- passing the surface explicitly silently fails this protected fallback.
  local ok, entities = pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and entities or {}
end
local function prototype(entity_name)
  if not (entity_name and prototypes and prototypes.entity) then return nil end
  local ok, value = pcall(function() return prototypes.entity[entity_name] end)
  return ok and value or nil
end
local function entity_type(entity_name)
  local value = prototype(entity_name)
  local result
  if value then pcall(function() result = value.type end) end
  return result
end
local function radius_for(pair)
  if not (pair and valid(pair.station)) then return Planner.default_radius end
  if type(_G.refresh_pair_radius) == "function" then
    local ok, radius = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(radius) then return math.max(8, math.min(96, tonumber(radius))) end
  end
  if type(_G.get_station_operating_radius) == "function" then
    local ok, radius = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(radius) then return math.max(8, math.min(96, tonumber(radius))) end
  end
  return math.max(8, math.min(96, tonumber(pair.radius or pair.base_radius) or Planner.default_radius))
end
local function as_xy(position)
  if not position then return { x = 0, y = 0 } end
  return { x = position.x or position[1] or 0, y = position.y or position[2] or 0 }
end
local function collision_box(entity_name)
  local value = prototype(entity_name)
  if not value then return nil end
  local box
  pcall(function() box = value.collision_box end)
  if not box then return nil end
  local left_top = as_xy(box.left_top or box[1] or box.lt)
  local right_bottom = as_xy(box.right_bottom or box[2] or box.rb)
  return {
    left_top = left_top,
    right_bottom = right_bottom,
    width = math.abs(right_bottom.x - left_top.x),
    height = math.abs(right_bottom.y - left_top.y),
  }
end
local function buffer_for(entity_name, category)
  if category == "assembler" then return 2 end
  if category == "defense-roboport" then return 2 end
  if category == "defense-artillery" then return 2 end
  if category == "defense-turret" or category == "defense-wall" then return 1.25 end
  if category == "emergency-powertrain" then return 1.25 end
  local box = collision_box(entity_name)
  if box and math.max(box.width, box.height) >= 3 then return 1.5 end
  return 1
end
local function footprint_area(entity_name, position, buffer)
  local box = collision_box(entity_name)
  buffer = tonumber(buffer) or 1
  if box then
    return {
      { position.x + box.left_top.x - buffer, position.y + box.left_top.y - buffer },
      { position.x + box.right_bottom.x + buffer, position.y + box.right_bottom.y + buffer },
    }
  end
  return {
    { position.x - buffer, position.y - buffer },
    { position.x + buffer, position.y + buffer },
  }
end
local ignored_clearance_types = {
  corpse = true,
  ["particle-source"] = true,
  ["highlight-box"] = true,
  ["simple-entity-with-owner"] = true,
}
local function area_clear(surface, entity_name, position, buffer, ignore_resources, live)
  local filters={area=footprint_area(entity_name,position,buffer),limit=128}
  local entities
  if live then
    local ok,found=pcall(function() return surface.find_entities_filtered(filters) end)
    if not (ok and found) or #found>=128 then return false end -- fail closed
    entities=found
  else
    entities=routed_find(surface,filters,"construction-clearance",nil,60*2)
  end
  for _, entity in pairs(entities or {}) do
    if valid(entity) and not ignored_clearance_types[entity.type]
      and not (ignore_resources and entity.type == "resource")
    then
      return false
    end
  end
  return true
end
local function can_place(surface, force, entity_name, position)
  local ok, result = pcall(function()
    return surface.can_place_entity({
      name = entity_name,
      position = position,
      force = force,
      build_check_type = defines and defines.build_check_type and defines.build_check_type.manual or nil,
    })
  end)
  if ok then return result == true end
  ok, result = pcall(function()
    return surface.can_place_entity({
      name = entity_name,
      position = position,
      force = force,
    })
  end)
  return ok and result == true
end
local function open_side_clear(surface, entity_name, position, buffer, live)
  local box = collision_box(entity_name)
  local side = box and math.max(2.5, math.max(box.width, box.height) * 0.75 + 1.5) or 3
  for _, candidate in ipairs({
    { x = position.x - side, y = position.y },
    { x = position.x, y = position.y - side },
    { x = position.x + side, y = position.y },
    { x = position.x, y = position.y + side },
  }) do
    if area_clear(surface, entity_name, candidate, buffer or 1, true, live) then return true end
  end
  return false
end
local function x_order_for_ring(radius)
  local values = { 0 }
  for offset = 1, radius do
    values[#values + 1] = -offset
    values[#values + 1] = offset
  end
  return values
end
local function spiral_offsets(radius)
  local result, seen = {}, {}
  local function add(dx, dy)
    local key = dx .. ":" .. dy
    if not seen[key] then
      seen[key] = true
      result[#result + 1] = { dx = dx, dy = dy }
    end
  end
  for _, dx in ipairs(x_order_for_ring(radius)) do add(dx, -radius) end
  for dy = -radius + 1, radius do add(-radius, dy) end
  for dx = -radius + 1, radius do add(dx, radius) end
  for dy = radius - 1, -radius + 1, -1 do add(radius, dy) end
  return result
end
local function grid_position(origin, dx, dy)
  return { x = origin.x + dx, y = origin.y + dy }
end
local function force_is_enemy(force, other)
  if not (force and other and force ~= other) then return false end
  local ok, result = pcall(function() return force.is_enemy(other) end)
  return ok and result == true
end
local function defense_profile(entity_name, category)
  local typ = entity_type(entity_name)
  local requested = tostring(category or "")
  if requested == "defense-roboport" or requested == "roboport" or typ == "roboport" then
    local value = prototype(entity_name)
    local construction_radius, logistics_radius = 0, 0
    if value then
      pcall(function() construction_radius = tonumber(value.construction_radius) or 0 end)
      pcall(function() logistics_radius = tonumber(value.logistics_radius) or 0 end)
    end
    return {
      family = "roboport",
      category = "defense-roboport",
      perimeter = false,
      requires_power = true,
      construction_radius = construction_radius,
      logistics_radius = logistics_radius,
    }
  end
  if requested == "defense-wall" or typ == "wall" or typ == "gate" then
    return { family = "wall", category = "defense-wall", perimeter = true }
  end
  if requested == "defense-artillery" or typ == "artillery-turret" then
    return { family = "artillery", category = "defense-artillery", perimeter = true, needs_ammo = true }
  end
  if requested == "defense-turret" or requested == "turret"
    or typ == "ammo-turret" or typ == "electric-turret" or typ == "fluid-turret"
  then
    return {
      family = "turret",
      category = "defense-turret",
      perimeter = true,
      requires_power = typ == "electric-turret",
      needs_ammo = typ == "ammo-turret",
      needs_fluid = typ == "fluid-turret",
    }
  end
  if requested == "defense-radar" or typ == "radar" then
    return { family = "radar", category = "defense-radar", perimeter = false, requires_power = true }
  end
  if requested == "defense-mine" or typ == "land-mine" then
    return { family = "mine", category = "defense-mine", perimeter = true }
  end
  return nil
end
local function threat_alignment_score(station, position, threat)
  if not threat then return 0 end
  local cx = position.x - station.position.x
  local cy = position.y - station.position.y
  local c_len = math.sqrt(cx * cx + cy * cy)
  local t_len = math.sqrt(threat.x * threat.x + threat.y * threat.y)
  if c_len <= 0 or t_len <= 0 then return 0 end
  local dot = (cx * threat.x + cy * threat.y) / (c_len * t_len)
  return -55 * dot
end
local function target_radius(pair, profile)
  local radius = radius_for(pair)
  if profile.family == "roboport" then
    local inset = math.max(6, math.min(18, (profile.construction_radius or 0) * 0.55))
    return math.max(Planner.min_radius + 2, radius - inset)
  end
  if profile.family == "radar" then return math.max(Planner.min_radius + 2, radius * 0.65) end
  return radius
end
local function has_existing_miner_near(surface, position, live)
  local filters={position=position,radius=4.25,type="mining-drill",limit=1}
  if live then
    local ok,found=pcall(function()return surface.find_entities_filtered(filters)end)
    if not (ok and found) then return true end -- fail closed
    return #found>0
  end
  local entities=routed_find(surface,filters,"construction-miner",nil,60*3)
  return entities and #entities>0
end
local function miner_grid_positions(entity_name, resource_position)
  -- Ore entities sit on tile centers. Factorio even-width machines such as
  -- the 2x2 burner drill have integer-centered footprints, while odd-width
  -- machines use tile half-centers. Check the four nearest legal anchors.
  local box=collision_box(entity_name)
  local width=box and box.width or 1
  local height=box and box.height or 1
  local xoffset=math.floor(width+0.5)%2==0 and 0 or 0.5
  local yoffset=math.floor(height+0.5)%2==0 and 0 or 0.5
  local x0=math.floor(resource_position.x-xoffset)+xoffset
  local y0=math.floor(resource_position.y-yoffset)+yoffset
  return {
    {x=x0,y=y0},{x=x0+1,y=y0},
    {x=x0,y=y0+1},{x=x0+1,y=y0+1},
  }
end
-- A search result is only a proposal. Both callers share the same force job
-- and must consume one live authorization immediately before creating a ghost
-- or admitting physical construction. Polling never advances the search.
local ORDINARY_KIND = "ordinary-placement-0359"
local MINER_KIND = "resource-placement-0359"
local DEFENSE_KIND = "defense-placement-0359"
local FIXED_KIND = "fixed-output-placement-0359"
local ADMISSION_KIND = "fixed-admission-placement-0359"
local live_job
local function station_id(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number))
end
local function job_pair(job)
  local pairs_by_station = storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  return pairs_by_station[job.payload.station]
end
local function same_domain(pair, payload)
  local station = pair and pair.station
  return valid(station) and station_id(pair) == payload.station
    and station.unit_number == payload.station
    and station.force.index == payload.force and station.surface.index == payload.surface
    and station.position.x == payload.x and station.position.y == payload.y
    and math.min(radius_for(pair), Planner.max_radius) == payload.radius
end
local function search_key(pair, entity_name, category)
  return tostring(station_id(pair)) .. ":" .. entity_name .. ":" .. tostring(category)
end
local function search_payload(pair, entity_name, category)
  local station = pair.station
  return {station=station_id(pair),force=station.force.index,surface=station.surface.index,
    x=station.position.x,y=station.position.y,radius=math.min(radius_for(pair),Planner.max_radius),
    entity_name=entity_name,category=category}
end
-- Constant-space version of the original top/left/bottom/right ring order.
-- It avoids rebuilding all offsets on every resumed tick.
local function ring_position(payload, ring, index)
  local top = ring * 2 + 1
  local dx,dy
  if index <= top then
    dx = index == 1 and 0 or (index % 2 == 0 and -index/2 or (index-1)/2)
    dy = -ring
  elseif index <= top + ring * 2 then
    dx,dy = -ring, -ring + index - top
  elseif index <= top + ring * 4 then
    dx,dy = -ring + index - top - ring * 2, ring
  else
    dx,dy = ring, ring - (index - top - ring * 4)
  end
  return {x=payload.x+dx,y=payload.y+dy}
end
-- Eligibility is also work: inspect one candidate recipe per broker visit,
-- then keep a live recipe witness instead of rescanning the membership list
-- for every search position or final physical admission.
local function unlock_step(job,pair)
  local policy=constraints()
  if not(policy and type(policy.request_metadata)=="function") then return nil end
  if not metadata_ready(pair) then return {processed=0,waiting=true} end
  local s=job.state
  local epoch=Metadata.epoch()
  if s.metadata_epoch~=epoch then
    s.metadata_epoch,s.unlock_cursor,s.unlock_recipe,s.unlock_item=epoch,1,nil,nil
  end
  local item=Metadata.item_for_entity(job.payload.entity_name)
  if not item then return {processed=1,done=true,result={reason="no-placeable-item"}} end
  if s.unlock_item~=item then s.unlock_cursor,s.unlock_recipe,s.unlock_item=1,nil,item end
  if s.unlock_recipe then
    local recipe=pair.station.force.recipes[s.unlock_recipe]
    if recipe and recipe.enabled==true then return nil end
    s.unlock_cursor,s.unlock_recipe=1,nil
    return {processed=1}
  end
  local names=Metadata.recipe_names(pair.station.force,item)
  if not names then return {processed=0,waiting=true} end
  local name=names[s.unlock_cursor or 1]
  if not name then
    return {processed=1,done=true,result={reason="technology-locked-or-no-enabled-recipe"}}
  end
  s.unlock_cursor=(s.unlock_cursor or 1)+1
  local recipe=pair.station.force.recipes[name]
  if recipe and recipe.enabled==true then s.unlock_recipe=name end
  return {processed=1}
end
local function live_unlock(job,pair)
  local policy=constraints()
  if not(policy and type(policy.request_metadata)=="function") then
    return not(policy and type(policy.entity_unlocked)=="function")
      or policy.entity_unlocked(pair,job.payload.entity_name)==true
  end
  local s=job.state
  local epoch=Metadata.epoch()
  if s.metadata_epoch~=epoch or Metadata.item_for_entity(job.payload.entity_name)~=s.unlock_item then return false end
  local recipe=s.unlock_recipe and pair.station.force.recipes[s.unlock_recipe]
  return recipe and recipe.enabled==true
end
local function ordinary_candidate(pair, payload, position, live)
  local policy = constraints()
  if policy and type(policy.request_metadata)~="function" and type(policy.entity_unlocked)=="function"
    and not policy.entity_unlocked(pair,payload.entity_name) then return false end
  if policy and type(policy.interior_position_allowed)=="function"
    and not policy.interior_position_allowed(pair,position) then return false end
  local station = pair.station
  local ignore_resources = payload.category == "miner" or payload.category == "emergency-miner"
  return can_place(station.surface,station.force,payload.entity_name,position)
    and area_clear(station.surface,payload.entity_name,position,
      buffer_for(payload.entity_name,payload.category),ignore_resources,live)
    and (payload.category ~= "assembler"
      or open_side_clear(station.surface,payload.entity_name,position,1,live))
end
local function ordinary_step(job)
  local pair,payload,state = job_pair(job),job.payload,job.state
  if not same_domain(pair,payload) then
    return {processed=1,done=true,result={reason="placement-domain-changed"}}
  end
  local eligibility=unlock_step(job,pair)
  if eligibility then return eligibility end
  if not metadata_ready(pair) then return {processed=0,waiting=true} end
  if not Queue.claim_tick("placement-search",15) then return {processed=0,waiting=true} end
  state.ring,state.index = state.ring or Planner.min_radius,state.index or 1
  if state.ring > payload.radius then
    return {processed=1,done=true,result={reason="no-spiral-site"}}
  end
  local position = ring_position(payload,state.ring,state.index)
  state.index = state.index + 1
  if state.index > math.min(state.ring*8,Planner.max_candidates_per_ring) then
    state.ring,state.index = state.ring + 1,1
  end
  -- Every attempted position consumes a token, including territory, engine,
  -- clearance and service-side rejection. No whole-ring accounting.
  if ordinary_candidate(pair,payload,position,false) then
    return {processed=1,done=true,result={position=position,
      reason="station-spiral-top-left-buffered"}}
  end
  return {processed=1}
end
Queue.register(ORDINARY_KIND,ordinary_step)

function Planner.is_pending(reason)
  return type(reason)=="string" and reason:sub(1,17)=="placement-pending"
end
local function request_site(pair,entity_name,category,kind,fixed_position,admission)
  if not (pair and valid(pair.station) and station_id(pair)) then return nil,"invalid-station" end
  local key=search_key(pair,entity_name,category)
  if fixed_position then key=key..":"..tostring(fixed_position.x)..":"..tostring(fixed_position.y) end
  if admission then
    key=key..":direction:"..tostring(admission.direction or 0)
      ..":ghost:"..tostring(admission.owned_ghost and admission.owned_ghost.unit_number or 0)
  end
  local force=pair.station.force.index
  local job=Queue.peek(force,kind,key)
  if job and not same_domain(pair,job.payload) then Queue.forget(force,kind,key);job=nil end
  local status
  if job then status=job.status else
    local payload=search_payload(pair,entity_name,category)
    if fixed_position then payload.fixed_position={x=fixed_position.x,y=fixed_position.y} end
    if admission then
      payload.direction=admission.direction
      payload.owned_ghost=admission.owned_ghost
    end
    job,status=Queue.submit(force,kind,key,payload)
  end
  if not job then return nil,"placement-pending-queue-full" end
  if status~="ready" then return nil,"placement-pending" end
  local result=job.result or {}
  if not result.position then
    Queue.forget(force,kind,key)
    return nil,result.reason or "site-planner-worker-error"
  end
  return {x=result.position.x,y=result.position.y},result.reason,result.effectiveness,
    {id=job.id,force_index=force,kind=kind,key=key}
end
function Planner.plan_spiral(pair, entity_name, category)
  return request_site(pair,entity_name,category or "generic",ORDINARY_KIND)
end
function Planner.authorize(pair,ticket,position)
  if type(ticket)~="table" then return false,"placement-pending-ticket-missing" end
  local job=Queue.peek(ticket.force_index,ticket.kind,ticket.key)
  if not(job and job.id==ticket.id and job.status=="ready" and job.result
    and job.result.position and position and job.result.position.x==position.x
    and job.result.position.y==position.y) then
    return false,"placement-pending-ticket-stale"
  end
  if not same_domain(pair,job.payload) then
    Queue.forget(ticket.force_index,ticket.kind,ticket.key)
    return false,"placement-pending-domain-changed"
  end
  if not metadata_ready(pair) then return false,"placement-pending-metadata" end
  if not Queue.claim_tick("placement-live",1) then return false,"placement-pending-live-budget" end
  if not live_job(job,pair,position) then
    if job.kind~=ORDINARY_KIND then job.state={} end
    Queue.retry(job)
    return false,"placement-pending-live-obstruction"
  end
  Queue.forget(ticket.force_index,ticket.kind,ticket.key)
  return true,"placement-live-authorized"
end
function Planner.install()
  if not Queue.install() then return false end
  local registry=require("scripts.core.runtime_event_registry")
  local events=defines and defines.events or {}
  local function bind(name,handler)
    if not events[name] then return true end
    return registry.on_event(events[name],handler,nil,{owner="construction-site-planner-0359",
      route="territory-"..name,priority=-100,category="construction"})~=nil
  end
  local ok=true
  for _,name in ipairs({"on_built_entity","on_robot_built_entity","script_raised_built",
    "script_raised_revive","on_entity_cloned","on_entity_died","on_pre_player_mined_item",
    "on_robot_pre_mined","script_raised_destroy","on_entity_force_changed"})do
    ok=bind(name,Planner.on_station_changed) and ok
  end
  for _,name in ipairs({"on_research_finished","on_research_reversed","on_force_reset",
    "on_forces_merged","on_surface_deleted","on_surface_cleared","on_runtime_mod_setting_changed"})do
    ok=bind(name,Planner.on_territory_changed) and ok
  end
  return registry.on_configuration_changed(Planner.on_territory_changed,
    {owner="construction-site-planner-0359",route="territory-configuration",priority=-100})~=nil and ok
end
-- Bounded live spatial discovery. One step queries one <=8x8 cell OR
-- visits one returned entity. Dense cells subdivide; a broad force/surface
-- query never counts as one planning operation. Native entity handles in
-- these short result pages are supported Factorio storage values.
local function circle_scan(position,radius,types,force,limit)
  local left=math.floor((position.x-radius)/8)*8
  local top=math.floor((position.y-radius)/8)*8
  return {position={x=position.x,y=position.y},radius=radius,types=types,
    force=force,limit=limit,left=left,top=top,x=left,y=top,
    right=math.floor((position.x+radius)/8)*8,
    bottom=math.floor((position.y+radius)/8)*8,count=0,pending={}}
end
local function scan_step(surface,scan)
  if scan.error then return nil,true,scan.error end
  if scan.limit and scan.count>=scan.limit then return nil,true end
  if scan.saturated then
    -- Even a page rejected in favor of finer spatial coverage is actual
    -- returned candidate work. Charge every row before subdividing it.
    local page=scan.saturated
    if page.index<=#page.entities then
      page.index=page.index+1
      return nil,false
    end
    local cell=page.cell;scan.saturated=nil
    if cell.size<=0.25 then
      scan.error="bounded-live-query-overflow";return nil,true,scan.error
    end
    local half=cell.size/2
    scan.pending[#scan.pending+1]={x=cell.x+half,y=cell.y+half,size=half}
    scan.pending[#scan.pending+1]={x=cell.x,y=cell.y+half,size=half}
    scan.pending[#scan.pending+1]={x=cell.x+half,y=cell.y,size=half}
    scan.pending[#scan.pending+1]={x=cell.x,y=cell.y,size=half}
    return nil,false
  end
  if scan.entities then
    local entity=scan.entities[scan.entity_index]
    if not entity then scan.entities=nil;scan.cell=nil;return nil,false end
    scan.entity_index=scan.entity_index+1
    local c=scan.cell
    if valid(entity) and entity.position and entity.position.x>=c.x
      and entity.position.x<c.x+c.size and entity.position.y>=c.y
      and entity.position.y<c.y+c.size
      and dist_sq(entity.position,scan.position)<=scan.radius*scan.radius then
      scan.count=scan.count+1
      return entity,false
    end
    return nil,false
  end
  local cell=table.remove(scan.pending)
  if not cell then
    if scan.y>scan.bottom then return nil,true end
    cell={x=scan.x,y=scan.y,size=8}
    scan.x=scan.x+8
    if scan.x>scan.right then scan.x,scan.y=scan.left,scan.y+8 end
  end
  local ok,entities=pcall(function()return surface.find_entities_filtered({
    area={{cell.x,cell.y},{cell.x+cell.size,cell.y+cell.size}},
    type=scan.types,force=scan.force,limit=64})end)
  if not(ok and type(entities)=="table")then
    scan.error="bounded-live-query-failed";return nil,true,scan.error
  end
  if #entities>=64 then
    -- Stack order preserves deterministic top-left, top-right, bottom-left,
    -- bottom-right traversal even across reload.
    scan.saturated={entities=entities,index=1,cell=cell}
  else
    scan.entities,scan.entity_index,scan.cell=entities,1,cell
  end
  return nil,false
end
local function search_allowed(job,pair)
  if not same_domain(pair,job.payload) then
    return false,{processed=1,done=true,result={reason="placement-domain-changed"}}
  end
  local eligibility=unlock_step(job,pair)
  if eligibility then return false,eligibility end
  if not metadata_ready(pair) or not Queue.claim_tick("placement-search",15) then
    return false,{processed=0,waiting=true}
  end
  return true
end
local function fixed_position_allowed(pair,payload,position)
  local policy=constraints()
  return (not policy or type(policy.interior_position_allowed)~="function"
      or policy.interior_position_allowed(pair,position))
    and can_place(pair.station.surface,pair.station.force,payload.entity_name,position)
end
Queue.register(FIXED_KIND,function(job)
  local pair=job_pair(job)
  local allowed,denied=search_allowed(job,pair)
  if not allowed then return denied end
  local position=job.payload.fixed_position
  local legal=position and fixed_position_allowed(pair,job.payload,position)
  return {processed=1,done=true,result={position=legal and position or nil,
    reason=legal and "drill-output-verified" or "fixed-drill-output-position-blocked"}}
end)
function Planner.plan_fixed_output(pair,entity_name,category,position)
  return request_site(pair,entity_name,category,FIXED_KIND,position)
end
-- A fixed request already has a position authority, but it is not an admitted
-- physical task. Even an owned planning ghost must receive its own live token
-- before 0338 reserves a site or takes material. This continuation performs no
-- whole-site search and never moves an explicitly requested position.
local function matching_owned_ghost(pair,payload,position)
  local ghost=payload.owned_ghost
  if not ghost then return true end
  local rec=pair.construction_bootstrap_ghost_0645
  return valid(ghost) and ghost.name=="entity-ghost"
    and ghost.ghost_name==payload.entity_name
    and ghost.force==pair.station.force and ghost.surface==pair.station.surface
    and ghost.position.x==position.x and ghost.position.y==position.y
    and (ghost.direction or 0)==(payload.direction or 0)
    and type(rec)=="table" and rec.ghost==ghost
    and rec.entity_name==payload.entity_name and rec.position
    and rec.position.x==position.x and rec.position.y==position.y
end
local function fixed_admission_area(payload,position)
  local box=collision_box(payload.entity_name)
  if not box then return {{position.x,position.y},{position.x,position.y}} end
  local east=defines and defines.direction and defines.direction.east or 4
  local angle=(payload.direction or 0)/east*math.pi/2
  local cosine,sine=math.cos(angle),math.sin(angle)
  local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
  for i=1,4 do
    local x=i<=2 and box.left_top.x or box.right_bottom.x
    local y=i%2==1 and box.left_top.y or box.right_bottom.y
    local rx,ry=x*cosine-y*sine,x*sine+y*cosine
    left,top,right,bottom=math.min(left,rx),math.min(top,ry),math.max(right,rx),math.max(bottom,ry)
  end
  return {{position.x+left,position.y+top},{position.x+right,position.y+bottom}}
end
local function fixed_admission_allowed(job,pair,position)
  local payload=job.payload
  if not matching_owned_ghost(pair,payload,position) then return false end
  if payload.owned_ghost and not live_unlock(job,pair) then return false end
  -- Native ghost_revive checks physical entities and current terrain. Never
  -- destroy/hide the ghost to probe placement, and never use forced building.
  local ok,allowed=pcall(pair.station.surface.can_place_entity,{
    name=payload.entity_name,position=position,direction=payload.direction,
    force=pair.station.force,
    build_check_type=defines and defines.build_check_type and defines.build_check_type.ghost_revive})
  if not(ok and allowed==true) then return false end
  -- The engine's revival check may ignore ghosts. Only the exact owned ghost
  -- is exempt here; another ghost at this footprint still owns its site.
  local read,ghosts=pcall(pair.station.surface.find_entities_filtered,{
    area=fixed_admission_area(payload,position),type="entity-ghost",limit=2})
  if not(read and type(ghosts)=="table") or #ghosts>=2 then return false end
  for _,ghost in pairs(ghosts) do
    if valid(ghost) and ghost~=payload.owned_ghost then return false end
  end
  return true
end
Queue.register(ADMISSION_KIND,function(job)
  local pair=job_pair(job)
  if not same_domain(pair,job.payload) then
    return {processed=1,done=true,result={reason="placement-pending-domain-changed"}}
  end
  if job.payload.owned_ghost then
    local eligibility=unlock_step(job,pair)
    if eligibility then return eligibility end
  end
  if not matching_owned_ghost(pair,job.payload,job.payload.fixed_position) then
    return {processed=1,done=true,result={reason="placement-pending-owned-ghost-changed"}}
  end
  return {processed=1,done=true,result={position=job.payload.fixed_position,
    reason="fixed-position-awaiting-live-admission"}}
end)
function Planner.plan_fixed_admission(pair,placeable,position,ghost)
  return request_site(pair,placeable.entity_name,placeable.category,ADMISSION_KIND,position,
    {direction=placeable.direction,owned_ghost=ghost})
end
local function resource_weight(name)
  return name=="iron-ore" and 0 or name=="copper-ore" and 10000
    or name=="coal" and 20000 or 30000
end
local function resource_step(job)
  local pair,payload,s=job_pair(job),job.payload,job.state
  local allowed,denied=search_allowed(job,pair)
  if not allowed then return denied end
  if not s.scan then
    s.scan=circle_scan(pair.station.position,payload.radius,"resource",nil)
    s.seen,s.phase={},"resource"
    return {processed=1}
  end
  if s.phase=="resource" then
    local entity,done,err=scan_step(pair.station.surface,s.scan)
    if err then return {processed=1,done=true,result={reason="miner-live-resource-scan-failed"}} end
    if entity and (not entity.amount or entity.amount>0) then
      s.resource={name=entity.name,position={x=entity.position.x,y=entity.position.y}}
      s.anchors=miner_grid_positions(payload.entity_name,entity.position)
      s.anchor_index,s.phase=1,"anchor"
    elseif done then
      return {processed=1,done=true,result={position=s.best,
        resource=s.best_resource,reason=s.best and "resource-patch-live-verified" or "no-miner-site"}}
    end
  elseif s.phase=="anchor" then
    local position=s.anchors[s.anchor_index]
    s.anchor_index=s.anchor_index+1
    if not position then s.phase="resource";return {processed=1} end
    local key=string.format("%.2f:%.2f",position.x,position.y)
    if not s.seen[key] then
      s.seen[key]=true
      local policy=constraints()
      local territory_ok=not policy or type(policy.interior_position_allowed)~="function"
        or policy.interior_position_allowed(pair,position)
      if territory_ok and dist_sq(position,pair.station.position)<=payload.radius*payload.radius then
        s.candidate,s.phase=position,"miner-neighbor"
      end
    end
  elseif s.phase=="miner-neighbor" then
    s.phase=has_existing_miner_near(pair.station.surface,s.candidate,true) and "anchor" or "engine"
  elseif s.phase=="engine" then
    s.phase=can_place(pair.station.surface,pair.station.force,payload.entity_name,s.candidate)
      and "clearance-query" or "anchor"
  elseif s.phase=="clearance-query" then
    local ok,entities=pcall(function()return pair.station.surface.find_entities_filtered({
      area=footprint_area(payload.entity_name,s.candidate,buffer_for(payload.entity_name,"miner")),limit=128})end)
    if not(ok and entities) or #entities>=128 then s.phase="anchor"
    else s.clearance,s.clearance_index,s.phase=entities,1,"clearance-entity" end
  elseif s.phase=="clearance-entity" then
    local entity=s.clearance[s.clearance_index];s.clearance_index=s.clearance_index+1
    if entity then
      if valid(entity) and entity.type~="resource" and not ignored_clearance_types[entity.type] then
        s.clearance,s.phase=nil,"anchor"
      end
    else
      local score=dist_sq(s.candidate,pair.station.position)+resource_weight(s.resource.name)
      if not s.best_score or score<s.best_score then
        s.best,s.best_score,s.best_resource=s.candidate,score,s.resource
      end
      s.clearance,s.phase=nil,"anchor"
    end
  end
  return {processed=1}
end
Queue.register(MINER_KIND,resource_step)

local function territory_root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests.placement_territory_1507
  if not r then r={epoch=0,forces={}};storage.tech_priests.placement_territory_1507=r end
  return r
end
local function territory_epoch(pair)
  local r=territory_root()
  local f=r.forces[pair.station.force.index] or {}
  return tostring(r.epoch)..":"..tostring(f.epoch or 0)..":"..tostring(f[pair.station.surface.index] or 0)
end
local function bump_territory(force,surface)
  local r=territory_root()
  if not force then r.epoch=r.epoch+1;return end
  local f=r.forces[force] or {epoch=0};r.forces[force]=f
  if surface then f[surface]=(f[surface] or 0)+1 else f.epoch=f.epoch+1 end
end
function Planner.on_station_changed(event)
  local entity=event and (event.created_entity or event.entity or event.destination)
  if not valid(entity) then return end
  if type(entity.name)=="string" and entity.name:find("cogitator-station",1,true) then
    bump_territory(entity.force.index,entity.surface.index)
  end
end
function Planner.on_territory_changed(event)
  local force=event and (event.force or (event.research and event.research.force))
  bump_territory(force and force.index or nil)
end
local function next_station(s)
  local map=storage.tech_priests.pairs_by_station or {}
  if s.station_cursor and map[s.station_cursor]==nil then s.station_cursor=nil end
  local key,pair=next(map,s.station_cursor)
  s.station_cursor=key
  return key,pair
end
local function territory_radius(pair)
  if type(_G.refresh_pair_radius)=="function" then
    local ok,value=pcall(_G.refresh_pair_radius,pair)
    if ok and tonumber(value) then return math.max(8,tonumber(value)) end
  end
  if type(_G.get_station_operating_radius)=="function" then
    local ok,value=pcall(_G.get_station_operating_radius,pair.station)
    if ok and tonumber(value) then return math.max(8,tonumber(value)) end
  end
  return math.max(8,tonumber(pair.radius or pair.base_radius) or 20)
end
Planner.territory_epoch=territory_epoch
Planner.territory_radius=territory_radius
local function defense_restart_candidate(s)
  s.position,s.clearance,s.scan,s.station_cursor=nil,nil,nil,nil
  s.phase="position"
end
local function support_descriptor(profile,index)
  if index==1 and profile.requires_power then return 12,"electric-pole",-18,45 end
  if index==2 and profile.needs_fluid then return 6,{"pipe","pipe-to-ground","storage-tank","pump"},-18,38 end
  if index==3 and profile.needs_ammo then return 14,{"container","logistic-container","cargo-wagon"},-12,24 end
end
local function spacing_types(family)
  if family=="roboport" then return {"roboport"}
  elseif family=="wall" then return {"wall","gate"}
  elseif family=="artillery" then return {"artillery-turret"}
  elseif family=="turret" then return {"ammo-turret","electric-turret","fluid-turret"}
  elseif family=="radar" then return {"radar"}
  elseif family=="mine" then return {"land-mine"} end
end
local function defense_report(pair,payload,s)
  return {version=Planner.version,read_only=true,placement_authority=true,
    family=s.profile.family,category=s.profile.category,entity_name=payload.entity_name,
    position={x=s.position.x,y=s.position.y},score=s.score,target_radius=s.desired,
    actual_radius=math.sqrt(dist_sq(pair.station.position,s.position)),
    threat_source=s.threat and s.threat.source or "none",territory_reason="defense-territory-owned",
    territory_epoch=s.epoch,station=payload.station,surface_index=payload.surface,
    force_index=payload.force,station_position={x=payload.x,y=payload.y},radius=payload.radius}
end
local function defense_step(job)
  local pair,payload,s=job_pair(job),job.payload,job.state
  local allowed,denied=search_allowed(job,pair)
  if not allowed then return denied end
  if s.epoch and s.epoch~=territory_epoch(pair) then job.state={};return {processed=1} end
  if not s.phase then
    s.profile=defense_profile(payload.entity_name,payload.category)
    if not s.profile then return {processed=1,done=true,result={reason="not-defense"}} end
    s.desired=target_radius(pair,s.profile)
    s.ring=math.max(Planner.min_radius,math.floor(s.desired+0.5)-4)
    s.max_ring=math.min(Planner.max_radius,math.floor(s.desired+0.5)+4)
    s.index,s.epoch=1,territory_epoch(pair)
    if valid(pair.combat_target) and force_is_enemy(pair.station.force,pair.combat_target.force) then
      s.threat={x=pair.combat_target.position.x-payload.x,
        y=pair.combat_target.position.y-payload.y,source="active-combat-target"}
      s.phase="position"
    else
      s.scan=circle_scan(pair.station.position,math.min(160,radius_for(pair)*2.5),
        {"unit","unit-spawner","turret"},nil,Planner.threat_scan_limit)
      s.vx,s.vy,s.weight,s.phase=0,0,0,"threat"
    end
  elseif s.phase=="threat" then
    local entity,done,err=scan_step(pair.station.surface,s.scan)
    if err then return {processed=1,done=true,result={reason="defense-live-threat-scan-failed"}} end
    if entity and force_is_enemy(pair.station.force,entity.force) then
      local dx,dy=entity.position.x-payload.x,entity.position.y-payload.y
      local weight=(entity.type=="unit-spawner" and 4 or entity.type=="turret" and 3 or 1)
        / math.max(1,math.sqrt(dx*dx+dy*dy))
      s.vx,s.vy,s.weight=s.vx+dx*weight,s.vy+dy*weight,s.weight+weight
    elseif done then
      if s.weight>0 and (s.vx~=0 or s.vy~=0) then
        s.threat={x=s.vx/s.weight,y=s.vy/s.weight,source="nearby-hostiles"}
      end
      s.scan,s.phase=nil,"position"
    end
  elseif s.phase=="position" then
    if payload.fixed_position and not s.fixed_tested then
      s.position={x=payload.fixed_position.x,y=payload.fixed_position.y};s.fixed_tested=true
    elseif payload.fixed_position or s.ring>s.max_ring then
      return {processed=1,done=true,result={position=s.best and s.best.position,
        effectiveness=s.best,reason=s.best and ("defense-effective:"..s.profile.family..":score="
          ..string.format("%.2f",s.best.score)) or "no-effective-defense-site",territory_epoch=s.epoch}}
    else
      s.position=ring_position(payload,s.ring,s.index)
      s.index=s.index+1
      if s.index>math.min(s.ring*8,Planner.max_candidates_per_ring) then s.ring,s.index=s.ring+1,1 end
    end
    local radius=territory_radius(pair)
    local distance=math.sqrt(dist_sq(pair.station.position,s.position))
    if s.profile.perimeter then
      if math.abs(distance-radius)>3.5 then defense_restart_candidate(s)
      else s.phase="territory-neighbor";s.station_cursor=nil end
    else
      if distance>math.max(3,radius-2) then defense_restart_candidate(s)
      else s.phase="engine" end
    end
  elseif s.phase=="territory-neighbor" then
    local key,other=next_station(s)
    if not key then s.phase="engine"
    elseif other~=pair and other and valid(other.station)
      and other.station.surface.index==payload.surface and other.station.force.index==payload.force
      and dist_sq(other.station.position,s.position)<=territory_radius(other)^2 then
      defense_restart_candidate(s)
    end
  elseif s.phase=="engine" then
    if can_place(pair.station.surface,pair.station.force,payload.entity_name,s.position) then
      s.clearance_position,s.clearance_buffer=s.position,buffer_for(payload.entity_name,s.profile.category)
      s.side,s.phase=0,"clearance-query"
    else defense_restart_candidate(s) end
  elseif s.phase=="clearance-query" then
    local ok,entities=pcall(function()return pair.station.surface.find_entities_filtered({
      area=footprint_area(payload.entity_name,s.clearance_position,s.clearance_buffer),limit=128})end)
    if not(ok and entities) or #entities>=128 then
      if s.side>0 and s.side<4 then s.phase="next-side" else defense_restart_candidate(s) end
    else s.clearance,s.clearance_index,s.phase=entities,1,"clearance-entity" end
  elseif s.phase=="clearance-entity" then
    local entity=s.clearance[s.clearance_index];s.clearance_index=s.clearance_index+1
    if entity then
      if valid(entity) and not ignored_clearance_types[entity.type]
        and not(s.side>0 and entity.type=="resource") then
        if s.side>0 and s.side<4 then s.phase="next-side" else defense_restart_candidate(s) end
      end
    elseif s.side==0 and s.profile.family~="wall" and s.profile.family~="mine" then
      s.clearance,s.phase=nil,"next-side"
    else
      s.score=math.abs(math.sqrt(dist_sq(pair.station.position,s.position))-s.desired)*9
        +threat_alignment_score(pair.station,s.position,s.threat)
      s.support_index,s.scan,s.phase=1,nil,"support"
    end
  elseif s.phase=="next-side" then
    s.side=s.side+1
    local box=collision_box(payload.entity_name)
    local distance=box and math.max(2.5,math.max(box.width,box.height)*.75+1.5) or 3
    local dx=s.side==1 and -distance or s.side==3 and distance or 0
    local dy=s.side==2 and -distance or s.side==4 and distance or 0
    s.clearance_position={x=s.position.x+dx,y=s.position.y+dy}
    s.clearance_buffer,s.phase=1,"clearance-query"
  elseif s.phase=="support" then
    if s.support_index>3 then
      s.scan=circle_scan(s.position,s.profile.family=="roboport" and 64 or 16,
        spacing_types(s.profile.family),pair.station.force,96)
      s.phase="spacing"
    else
      local radius,types,yes,no=support_descriptor(s.profile,s.support_index)
      if not radius then s.support_index=s.support_index+1
      elseif not s.scan then s.scan=circle_scan(s.position,radius,types,pair.station.force,1)
      else
        local entity,done,err=scan_step(pair.station.surface,s.scan)
        if err then return {processed=1,done=true,result={reason="defense-live-support-scan-failed"}} end
        if entity or done then
          s.score=s.score+(entity and yes or no)
          s.scan,s.support_index=nil,s.support_index+1
        end
      end
    end
  elseif s.phase=="spacing" then
    local entity,done,err=scan_step(pair.station.surface,s.scan)
    if err then return {processed=1,done=true,result={reason="defense-live-spacing-scan-failed"}} end
    if entity then
      local distance=math.sqrt(dist_sq(s.position,entity.position))
      if s.profile.family=="roboport" then
        local existing=0
        pcall(function()existing=tonumber(entity.prototype.construction_radius) or 0 end)
        local desired=math.max(10,math.min(48,(s.profile.construction_radius+existing)*.7))
        if distance<desired*.35 then s.score=s.score+70
        elseif distance<=desired then s.score=s.score-18
        else s.score=s.score+math.min(24,(distance-desired)*.4) end
      elseif distance<3 then s.score=s.score+80
      elseif distance<7 then s.score=s.score+22
      else s.score=s.score-math.min(8,distance*.25) end
    elseif done then
      local report=defense_report(pair,payload,s)
      if not s.best or report.score<s.best.score or (report.score==s.best.score
        and (report.position.y<s.best.position.y
          or (report.position.y==s.best.position.y and report.position.x<s.best.position.x))) then
        s.best=report
      end
      defense_restart_candidate(s)
    end
  end
  return {processed=1}
end
Queue.register(DEFENSE_KIND,defense_step)
function Planner.plan_defense_site(pair,entity_name,category)
  return request_site(pair,entity_name,category,DEFENSE_KIND)
end
function Planner.evaluate_defense_candidate(pair,entity_name,position,category)
  local pos,why,report,ticket=request_site(pair,entity_name,category,DEFENSE_KIND,position)
  return pos and report or nil,why,ticket
end
live_job=function(job,pair,position)
  if job.kind==ADMISSION_KIND then return fixed_admission_allowed(job,pair,position) end
  if not live_unlock(job,pair) then return false end
  if job.kind==FIXED_KIND then return fixed_position_allowed(pair,job.payload,position) end
  if job.kind==DEFENSE_KIND then
    local profile=defense_profile(job.payload.entity_name,job.payload.category)
    if not profile or job.result.territory_epoch~=territory_epoch(pair) then return false end
    return can_place(pair.station.surface,pair.station.force,job.payload.entity_name,position)
      and area_clear(pair.station.surface,job.payload.entity_name,position,
        buffer_for(job.payload.entity_name,profile.category),false,true)
      and ((profile.family=="wall" or profile.family=="mine")
        or open_side_clear(pair.station.surface,job.payload.entity_name,position,1,true))
  end
  if not ordinary_candidate(pair,job.payload,position,true) then return false end
  if job.kind==MINER_KIND then
    if has_existing_miner_near(pair.station.surface,position,true) then return false end
    local witness=job.result.resource
    if not witness then return false end
    local ok,entities=pcall(function()return pair.station.surface.find_entities_filtered({
      position=witness.position,radius=.1,type="resource",name=witness.name,limit=1})end)
    return ok and entities and valid(entities[1])
      and (not entities[1].amount or entities[1].amount>0)
  end
  return true
end
-- Already-admitted physical construction keeps its original authority; it
-- does not wait for another whole perimeter ranking while carrying material.
-- World collision and the original station domain are still checked live.
function Planner.live_admitted_defense_site(pair,entity_name,position,category,report)
  local profile=defense_profile(entity_name,category)
  if not profile then return false,"invalid-defense-admission" end
  -- Old saves already hold an admitted task; preserve that ownership while
  -- enforcing present collision. New admissions always include full domain.
  if report and report.station_position and (station_id(pair)~=report.station or pair.station.surface.index~=report.surface_index
    or pair.station.force.index~=report.force_index
    or pair.station.position.x~=report.station_position.x
    or pair.station.position.y~=report.station_position.y
    or math.min(radius_for(pair),Planner.max_radius)~=report.radius) then
    return false,"defense-admission-domain-changed"
  end
  local allowed=can_place(pair.station.surface,pair.station.force,entity_name,position)
    and area_clear(pair.station.surface,entity_name,position,buffer_for(entity_name,category),false,true)
  return allowed,allowed and "defense-admission-live-checked" or "engine-blocked"
end

function Planner.plan_site(pair, placeable)
  if not (pair and valid(pair.station) and placeable and placeable.entity_name) then
    return nil, "invalid"
  end
  if not metadata_ready(pair) then return nil,"placement-pending-metadata" end
  local policy = constraints()
  if policy and type(policy.request_metadata) ~= "function" and type(policy.entity_unlocked) == "function" then
    local unlocked, why = policy.entity_unlocked(pair, placeable.entity_name)
    if not unlocked then return nil, why or "technology-locked" end
  end
  local category = placeable.category or "generic"
  if category == "deferred-network" then return nil, "deferred-network-submodule" end
  local profile = defense_profile(placeable.entity_name, category)
  if profile then return Planner.plan_defense_site(pair, placeable.entity_name, profile.category) end
  if category == "miner" then return request_site(pair,placeable.entity_name,category,MINER_KIND) end
  if category == "emergency-miner" then return Planner.plan_spiral(pair, placeable.entity_name, category) end
  if category == "emergency-power-pole" or category == "emergency-powertrain"
    or category == "emergency-smelter"
  then
    return Planner.plan_spiral(pair, placeable.entity_name, category)
  end
  if entity_type(placeable.entity_name) == "mining-drill" and category ~= "emergency-miner" then
    return request_site(pair,placeable.entity_name,category,MINER_KIND)
  end
  return Planner.plan_spiral(pair, placeable.entity_name, category)
end
function Planner.placement_effectiveness_report(pair, entity_name, position, category)
  return Planner.evaluate_defense_candidate(pair, entity_name, position, category)
end
function Planner.debug_sequence(pair, entity_name, limit)
  local station = pair and pair.station
  if not valid(station) then return {} end
  local result = {}
  limit = tonumber(limit) or 24
  for ring = Planner.min_radius, math.min(Planner.min_radius + 4, Planner.max_radius) do
    for _, offset in ipairs(spiral_offsets(ring)) do
      result[#result + 1] = {
        x = station.position.x + offset.dx,
        y = station.position.y + offset.dy,
        ring = ring,
      }
      if #result >= limit then return result end
    end
  end
  return result
end

_G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359 = Planner
_G.TechPriestsConstructionSitePlanner = Planner

return Planner
