-- Network shortage assessment is a continuation of the shared force planner.
-- Reports are observation windows, never a credit for cached items. Only the
-- canonical construction caller may claim materials or create a ghost.
local Q = require("scripts.core.force_planning_queue")
local Metadata = require("scripts.core.planning_metadata_1507")
local M = {version="0.1.678", interval=113, query_limit=16,
  minimum={["iron-plate"]=20,["copper-plate"]=12,["iron-gear-wheel"]=8}}
local ITEMS={"copper-plate","iron-gear-wheel","iron-plate"}
local STAGES={"smelting","crafting"}
local STAGE_ENTITY={smelting="stone-furnace",crafting="assembling-machine-1"}
local GHOST_STAGE={
  ["burner-mining-drill"]="mining",["electric-mining-drill"]="mining",
  ["tech-priests-emergency-miner"]="mining",["stone-furnace"]="smelting",
  ["steel-furnace"]="smelting",["electric-furnace"]="smelting",
  ["tech-priests-emergency-smelter"]="smelting",
  ["assembling-machine-1"]="crafting",["assembling-machine-2"]="crafting",
  ["assembling-machine-3"]="crafting",["tech-priests-emergency-assembler"]="crafting"}
local TYPES={"mining-drill","furnace","assembling-machine","logistic-container","entity-ghost"}
local CHEST={container=true,["logistic-container"]=true,
  ["infinity-container"]=true,["linked-container"]=true}
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function pairs_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests.emergency_facility_placement_bridge_0643
  if not r then r={assessments={},reservations={},stats={}};storage.tech_priests.emergency_facility_placement_bridge_0643=r end
  r.assessments=r.assessments or {};r.reservations=r.reservations or {};r.stats=r.stats or {}
  r.pending_groups=r.pending_groups or {};r.next_groups=r.next_groups or {};r.epoch=r.epoch or 0
  if r.continuation_schema~=1 then
    -- Old synchronous claims cannot certify a newly admitted continuation.
    r.reservations={};r.continuation_schema=1
  end
  return r
end
M.root=root
local function stat(name,n) local r=root();r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function result(done,value,acted) return {processed=1,done=done or false,result=value,acted=acted or 0} end
local function group_key(force,surface) return tostring(force)..":"..tostring(surface) end
local function pair_valid(pair,force,surface)
  return pair and valid(pair.station) and valid(pair.priest)
    and (not force or pair.station.force.index==force)
    and (not surface or pair.station.surface.index==surface)
end
local function member_valid(m)
  local p=pairs_map()[m.unit] or pairs_map()[tostring(m.unit)]
  return p==m.pair and pair_valid(p,m.force,m.surface)
    and p.station==m.station and p.station.position.x==m.x and p.station.position.y==m.y
end
local function reaches(e,m)
  if not (member_valid(m) and valid(e) and e.surface==m.station.surface and e.force==m.station.force) then return false end
  local p=e.position;local dx,dy=p.x-m.x,p.y-m.y
  return dx*dx+dy*dy<=36*36
end
local function network(e)
  local ok,n=pcall(function()return e.logistic_network end)
  return ok and n and n.valid and n or nil
end
-- Native LuaCustomTable iterators are recreated around a saved key. No
-- iterator closure or coroutine is persisted. The registries here are immutable
-- within a configuration; a configuration event invalidates their jobs.
local function next_entry(map,key)
  if not map then return nil end
  local iter,owner=pairs(map)
  return iter(owner,key)
end
local function next_live(map,s)
  -- Event handlers can remove the saved key between ticks. Restarting uses
  -- a seen set, so removal never calls next(map,deleted_key) or double-credits.
  if s.cursor~=nil and map[s.cursor]==nil then s.cursor=nil end
  local key,value=next(map,s.cursor);s.cursor=key
  if key~=nil and s.seen[key] then return key,nil end
  if key~=nil then s.seen[key]=true end
  return key,value
end
local function slot_count(entity,id,item)
  if not (valid(entity) and entity.get_inventory and type(id)=="number") then return 0 end
  local ok,inv=pcall(entity.get_inventory,id)
  if not (ok and inv and inv.valid) then return 0 end
  local got,n=pcall(inv.get_item_count,item)
  return got and math.max(0,tonumber(n) or 0) or 0
end
local function source_live(source)
  if not (valid(source.entity) and member_valid(source.member)) then return false end
  if source.kind=="station" then return source.entity==source.member.station end
  local n=network(source.member.station)
  return n~=nil and reaches(source.entity,source.member) and network(source.entity)==n
end
local function stage_for(e)
  if e.type=="mining-drill" then return "mining" end
  if e.type=="furnace" or e.name=="tech-priests-emergency-smelter" then return "smelting" end
  if e.type=="assembling-machine" then return "crafting" end
end
local function index_surface(surface)
  local r=storage.tech_priests.efficiency_economy_0579
  return r and r.enabled~=false and r.use_indexed_catalog_cells~=false
    and r.surfaces and r.surfaces[tostring(surface)] or nil
end
local function cell_signature(surface,key)
  local r=index_surface(surface)
  local cell=r and r.cells and r.cells[key]
  return cell,cell and cell.entities,cell and cell.known_tick,
    r and r.dirty and r.dirty[key]
end
local function cell_unchanged(s,cell)
  local rec,list,stamp,dirty=cell_signature(s.surface_index,cell.key)
  return rec==cell.index_record and list==cell.index_list
    and stamp==cell.index_stamp and dirty==cell.index_dirty
end

local function roster_step(job)
  local s=job.state;local r=root()
  if not s.phase then s.phase="members";s.cursor=nil;s.seen={};s.groups={};s.order={};s.epoch=r.epoch end
  if s.epoch~=r.epoch then return result(true,{stale=true}) end
  if s.phase=="members" then
    local key,pair=next_live(pairs_map(),s)
    if key==nil then s.phase="submit";s.index=1;s.pending=#s.order;s.submitted={};return result() end
    if pair_valid(pair) then
      local station=pair.station;local force,surface=station.force.index,station.surface.index
      local id=group_key(force,surface);local g=s.groups[id]
      if not g then g={force=force,surface=surface,members={}};s.groups[id]=g;s.order[#s.order+1]=id end
      g.members[#g.members+1]={unit=station.unit_number,pair=pair,station=station,
        force=force,surface=surface,x=station.position.x,y=station.position.y,
        dirty=pair.station_area_dirty_0634}
    end
    return result()
  end
  if s.phase=="retire" then
    local key=next_live(r.assessments,s.retire)
    if key==nil then r.next_assessment_tick=now()+M.interval;return result(true,{groups=#s.order}) end
    if not s.groups[key] then
      r.assessments[key]=nil;r.next_groups[key]=nil
      for _,stage in ipairs(STAGES) do r.reservations[key..":"..stage]=nil end
    end
    return result()
  end
  if s.pending==0 then s.phase="retire";s.retire={seen={}};return result() end
  local id=s.order[s.index];s.index=s.index % #s.order+1
  if s.submitted[id] then return result() end
  local g=s.groups[id];local key="surface:"..g.surface
  if now()<(r.next_groups[id] or 0) then s.submitted[id]=true;s.pending=s.pending-1;return result() end
  local existing,status=Q.peek(g.force,"shortage-assessment",key)
  if existing and status=="ready" then Q.forget(g.force,"shortage-assessment",key);existing=nil end
  local queued=existing or Q.submit(g.force,"shortage-assessment",key,
    {members=g.members,force_index=g.force,surface_index=g.surface,network=id,epoch=r.epoch})
  -- Retry a fixed ring: a full force cannot block another force or grow an
  -- unbounded deferred array while the shared queue is stalled.
  if queued then s.submitted[id]=true;s.pending=s.pending-1 end
  return result()
end
local function abort(s,reason)
  local r=root();r.stats["aborted_"..reason]=(r.stats["aborted_"..reason] or 0)+1
  r.next_assessment_tick=math.min(r.next_assessment_tick or now(),now());r.next_groups[s.network]=0
  if r.pending_groups[s.network]==s then r.pending_groups[s.network]=nil end
  for _,stage in ipairs(STAGES) do r.reservations[s.network..":"..stage]=nil end
  return result(true,{status="stale",reason=reason,network=s.network})
end
local function init_group(job)
  local s=job.state;local p=job.payload
  s.phase="members";s.members=p.members;s.member_map={};s.sources={};s.entities={};s.seen_entities={}
  s.cells={};s.cell_map={};s.member_index=1;s.network=p.network;s.force_index=p.force_index;s.surface_index=p.surface_index
  root().pending_groups[s.network]=s
  s.started_tick=now();s.epoch=p.epoch;s.valid_members=0;s.inventory_ids={};s.inventory_seen={}
  s.available={};s.capacity={mining=0,smelting=0,crafting=0};s.planned={mining=0,smelting=0,crafting=0}
end
local function add_source(s,e,m,kind)
  local source={entity=e,member=m,kind=kind,counts={},positive_slots={}}
  s.sources[#s.sources+1]=source
  if kind=="station" then m.source=source end
end
local function begin_cells(s,m)
  m.x1,m.x2=math.floor((m.x-36)/32),math.floor((m.x+36)/32)
  m.y1,m.y2=math.floor((m.y-36)/32),math.floor((m.y+36)/32)
  s.cx,s.cy=m.x1,m.y1;s.phase="cells"
end
local function accept_entity(s,e,m)
  local identity=e.unit_number or (e.name..":"..e.position.x..":"..e.position.y)
  if s.seen_entities[identity] then return end
  if e.type=="logistic-container" then
    local n=network(m.station)
    if not n or network(e)~=n then return false end
    s.seen_entities[identity]=true;add_source(s,e,m,"provider")
  elseif e.type=="entity-ghost" then
    s.seen_entities[identity]=true
    s.entities[#s.entities+1]={entity=e,member=m,ghost=true}
  elseif stage_for(e) then
    s.seen_entities[identity]=true;s.entities[#s.entities+1]={entity=e,member=m}
  end
  return true
end
local function world_step(s)
  local scan=s.scan
  if s.candidate then
    local c=s.candidate;local m=s.members[s.cells[s.cell_index].members[c.member]]
    if not m then s.candidate=nil;return result() end
    c.member=c.member+1
    if reaches(c.entity,m) and accept_entity(s,c.entity,m) then s.candidate=nil end
    return result()
  end
  if not scan then
    local cell=s.cells[s.cell_index]
    if not cell then s.phase="inventory-ids";s.id_key=nil;return result() end
    local rec,list,stamp,dirty=cell_signature(s.surface_index,cell.key)
    cell.index_record,cell.index_list,cell.index_stamp,cell.index_dirty=rec,list,stamp,dirty
    if rec and list and not dirty and tonumber(stamp) and stamp>=0 and now()-stamp<=600 then
      s.scan={kind="index",map=list,cursor=nil,seen={}}
    else
      s.scan={kind="native",pending={{cell.x*32,cell.y*32,cell.x*32+32,cell.y*32+32,0}},at=1}
    end
    return result()
  end
  if scan.kind=="index" then
    local cell=s.cells[s.cell_index]
    if not cell_unchanged(s,cell) then return abort(s,"world-changed") end
    local key,e=next_live(scan.map,scan)
    if key==nil then s.scan=nil;s.cell_index=s.cell_index+1
    elseif valid(e) then s.candidate={entity=e,member=1} end
    return result()
  end
  if scan.batch then
    local e=scan.batch[scan.cursor]
    if e then scan.cursor=scan.cursor+1;s.candidate={entity=e,member=1};return result() end
    local a=scan.area
    if #scan.batch>=M.query_limit then
      if a[5]>=7 then return abort(s,"saturated-world-cell") end
      local mx,my=(a[1]+a[3])/2,(a[2]+a[4])/2;local depth=a[5]+1
      -- Four constant-size child descriptors; result traversal remains charged.
      local q=scan.pending
      q[#q+1]={a[1],a[2],mx,my,depth};q[#q+1]={mx,a[2],a[3],my,depth}
      q[#q+1]={a[1],my,mx,a[4],depth};q[#q+1]={mx,my,a[3],a[4],depth}
    end
    scan.batch=nil;return result()
  end
  local a=scan.pending[scan.at]
  if not a then s.scan=nil;s.cell_index=s.cell_index+1;return result() end
  scan.at=scan.at+1
  local member=s.members[1]
  if not member_valid(member) then return abort(s,"station-changed") end
  local ok,entities=pcall(member.station.surface.find_entities_filtered,
    {area={{a[1],a[2]},{a[3],a[4]}},force=member.station.force,type=TYPES,limit=M.query_limit})
  stat("bounded_queries")
  if not(ok and type(entities)=="table") then return abort(s,"world-query-failed") end
  if #entities>M.query_limit then return abort(s,"uncapped-world-query") end
  scan.area,scan.batch,scan.cursor=a,entities,1
  return result()
end
local function metadata_ready(s)
  local force=s.members[1].station.force
  if not Metadata.ready(force) then return false end
  s.meta={items={},recipes={}}
  for _,stage in ipairs(STAGES) do
    local item=Metadata.item_for_entity(STAGE_ENTITY[stage]);s.meta.items[stage]=item
    s.meta.recipes[stage]=item and Metadata.recipe_names(force,item,false) or {}
  end
  return true
end

local function stock_step(s)
  local source=s.sources[s.source_index]
  if not source then s.phase="capacity-validation";s.entity_index=1;return result() end
  local item=s.items[s.item_index]
  if not item then s.source_index=s.source_index+1;s.item_index=1;s.slot_index=1;return result() end
  if not source_live(source) then return abort(s,"source-changed") end
  local chest=defines and defines.inventory and defines.inventory.chest
  local slot=CHEST[source.entity.type] and type(chest)=="number" and (s.slot_index==1 and chest)
    or (not (CHEST[source.entity.type] and type(chest)=="number") and s.inventory_ids[s.slot_index])
  if not slot then s.item_index=s.item_index+1;s.slot_index=1;return result() end
  s.slot_index=s.slot_index+1
  local n=source_live(source) and slot_count(source.entity,slot,item) or 0
  source.counts[item]=(source.counts[item] or 0)+n
  s.available[item]=(s.available[item] or 0)+n
  if n>0 then source.positive_slots[item]=source.positive_slots[item] or slot end
  stat("inventory_slots")
  return result()
end
local function build_report(s)
  local report={available={},required={},deficits={},needs={},capacity=s.capacity,station_count=s.valid_members,
    observed_since=s.started_tick,observed_until=now(),tick=now(),complete=true,
    quantity_authority="rolling-observation-only; canonical caller rechecks live stock"}
  for _,item in ipairs(ITEMS) do
    local available=s.available[item] or 0;local required=M.minimum[item]*s.valid_members
    report.available[item],report.required[item]=available,required
    if available<required then
      local stage=item=="iron-gear-wheel" and "crafting" or "smelting"
      report.deficits[item]=required-available
      report.needs[#report.needs+1]={item=item,missing=required-available,stage=stage,
        input=item=="iron-plate" and "iron-ore" or item=="copper-plate" and "copper-ore" or "iron-plate",
        existing_capacity=s.capacity[stage],decision=s.capacity[stage]>0 and "investigate-throughput-or-delivery" or "missing-production-capacity"}
    end
  end
  return report
end
local function final_request(s,need,candidate,material)
  local r=root();local id=s.network..":"..need.stage;local pair=candidate.pair
  -- This is a single bounded live decision, not another group/area scan.
  -- Earlier rolling totals never authorize this request or claim any material.
  if not(member_valid(candidate) and source_live(material)) then r.reservations[id]=nil;return 0,"witness-changed" end
  if candidate.pair.station_area_dirty_0634~=candidate.dirty then r.reservations[id]=nil;return 0,"world-changed" end
  local chest=defines and defines.inventory and defines.inventory.chest
  if not(CHEST[candidate.station.type] and type(chest)=="number") then r.reservations[id]=nil;return 0,"live-station-slot-unavailable" end
  if slot_count(candidate.station,chest,need.item)>=M.minimum[need.item] then r.reservations[id]=nil;return 0,"shortage-satisfied" end
  local item=s.meta.items[need.stage];local slot=material.positive_slots[item]
  local have=slot_count(material.entity,slot,item)
  local recipe=candidate.station.force.recipes[s.recipe_name]
  if have<1 or not(recipe and recipe.enabled) then r.reservations[id]=nil;return 0,"stock-or-technology-changed" end
  local Planner=rawget(_G,"TechPriestsConstructionBootstrapGhostPlanner0645")
    or package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]
  if not(Planner and type(Planner.service_pair)=="function") then r.reservations[id]=nil;return 0,"canonical-planner-unavailable" end
  local reservation={network=s.network,stage=need.stage,entity=STAGE_ENTITY[need.stage],station_unit=candidate.unit,
    status="awaiting-planner",created_tick=now(),last_assessed_tick=now(),item=need.item,missing=need.missing,
    material={item=item,available=have,required=1,observed_tick=now()},observation_started_tick=s.started_tick}
  local rec=pair.construction_bootstrap_ghost_0645;local acted=0
  if rec and valid(rec.ghost) then
    reservation.status=rec.entity_name==reservation.entity and "awaiting-construction" or "waiting-other-construction"
    reservation.ghost_name=rec.entity_name
  else
    local ok,created,why=pcall(Planner.service_pair,pair,"emergency-network:"..id,reservation.entity)
    if not ok then reservation.status="planner-error";reservation.blocker=tostring(created)
    elseif created then reservation.status="construction-requested";reservation.requested_tick=now();acted=1
    else reservation.blocker=why end
  end
  -- Each reservation appears atomically only after its complete group scan and
  -- current local witnesses. Nothing staged can be consumed by another caller.
  r.reservations[id]=reservation
  return acted,reservation.status
end
local function group_step(job)
  local s=job.state;local r=root()
  if not s.phase then init_group(job);return result() end
  if s.epoch~=r.epoch then return abort(s,"configuration-changed") end
  if s.world_changed then return abort(s,"world-event") end
  if s.phase=="members" then
    local m=s.members[s.member_index]
    if not m then
      if s.valid_members==0 then return abort(s,"no-members") end
      s.phase="metadata";return result()
    end
    if not member_valid(m) then return abort(s,"station-changed") end
    if not s.member_map[m.unit] then
      s.member_map[m.unit]=m;s.valid_members=s.valid_members+1;add_source(s,m.station,m,"station")
      begin_cells(s,m)
    else s.member_index=s.member_index+1 end
    return result()
  elseif s.phase=="cells" then
    local m=s.members[s.member_index];local key=s.cx..":"..s.cy;local cell=s.cell_map[key]
    if not cell then cell={key=key,x=s.cx,y=s.cy,members={}};s.cell_map[key]=cell;s.cells[#s.cells+1]=cell end
    cell.members[#cell.members+1]=s.member_index
    s.cy=s.cy+1
    if s.cy>m.y2 then s.cy=m.y1;s.cx=s.cx+1 end
    if s.cx>m.x2 then s.member_index=s.member_index+1;s.phase="members" end
    return result()
  elseif s.phase=="metadata" then
    if metadata_ready(s) then s.phase="world";s.cell_index=1 end
    return result()
  elseif s.phase=="world" then return world_step(s)
  elseif s.phase=="inventory-ids" then
    local k,id=next_entry(defines and defines.inventory,s.id_key);s.id_key=k
    if k~=nil then
      if type(id)=="number" and not s.inventory_seen[id] then s.inventory_seen[id]=true;s.inventory_ids[#s.inventory_ids+1]=id end
    else
      s.items={ITEMS[1],ITEMS[2],ITEMS[3]}
      for _,stage in ipairs(STAGES) do local item=s.meta.items[stage];if item and not M.minimum[item] then s.items[#s.items+1]=item end end
      s.phase="stock";s.source_index=1;s.item_index=1;s.slot_index=1;s.stock_started_tick=now()
    end
    return result()
  elseif s.phase=="stock" then return stock_step(s)
  elseif s.phase=="capacity-validation" then
    local e=s.entities[s.entity_index]
    if not e then s.phase="cell-validation";s.validate_index=1;return result() end
    s.entity_index=s.entity_index+1
    if reaches(e.entity,e.member) then
      if e.ghost then
        local ok,name=pcall(function()return e.entity.ghost_name end);local stage=ok and GHOST_STAGE[name]
        if stage then s.planned[stage]=s.planned[stage]+1 end
      else local stage=stage_for(e.entity);if stage then s.capacity[stage]=s.capacity[stage]+1 end end
    end
    return result()
  elseif s.phase=="cell-validation" then
    local cell=s.cells[s.validate_index]
    if not cell then s.phase="membership-validation";s.roster={seen={}};s.member_count=0;s.member_ids_seen={};return result() end
    s.validate_index=s.validate_index+1
    if not cell_unchanged(s,cell) then return abort(s,"world-changed") end
    return result()
  elseif s.phase=="membership-validation" then
    local key,pair=next_live(pairs_map(),s.roster)
    if key~=nil then
      if pair_valid(pair,s.force_index,s.surface_index) then
        local m=s.member_map[pair.station.unit_number]
        if not(m and member_valid(m) and pair.station_area_dirty_0634==m.dirty) then return abort(s,"membership-changed") end
        if not s.member_ids_seen[m.unit] then s.member_ids_seen[m.unit]=true;s.member_count=s.member_count+1 end
      end
      return result()
    end
    if s.member_count~=s.valid_members then return abort(s,"membership-changed") end
    s.report=build_report(s);s.phase="science";s.pack_key=nil
    local force=s.members[1].station.force;s.research=force.current_research
    if s.research then s.report.science={research=s.research.name,packs={}} end
    return result()
  elseif s.phase=="science" then
    local k,p=next_entry(s.research and s.research.research_unit_ingredients,s.pack_key);s.pack_key=k
    if k~=nil then
      local name=p.name or p[1];if name then local packs=s.report.science.packs;packs[#packs+1]={item=name,per_unit=tonumber(p.amount or p[2]) or 1} end
      return result()
    end
    -- Fixed-size publication/retirement, independent of factory size. Keep the
    -- previous complete report visible until this point; no partial totals.
    r.assessments[s.network]=s.report
    for _,stage in ipairs(STAGES) do r.reservations[s.network..":"..stage]=nil end
    r.last_assessment_tick=now();r.stats.assessments=(r.stats.assessments or 0)+1
    s.need_index=1;s.stage_done={};s.phase="need";return result()
  elseif s.phase=="need" then
    local need=s.report.needs[s.need_index];s.need_index=s.need_index+1
    if not need then
      if r.pending_groups[s.network]==s then r.pending_groups[s.network]=nil end
      -- A healthy complete factory needs no continuous deep resurvey. The
      -- ordinary admission roster and entity events can wake it again; passive
      -- stock reconsideration uses the existing 30-second inventory horizon.
      r.next_groups[s.network]=now()+(next(s.report.deficits)==nil and 1800 or M.interval)
      return result(true,{status="complete",network=s.network,report=s.report})
    end
    if s.stage_done[need.stage] or need.decision~="missing-production-capacity" or s.planned[need.stage]>0 then return result() end
    s.need=need;s.need_source=1;s.need_slot=1;s.need_stock=0;s.phase="need-stock";return result()
  elseif s.phase=="need-stock" then
    -- A per-reservation live pass sees stock that arrived during the expensive
    -- world/metadata survey. Each source/slot is charged and may yield; this
    -- remains an observation, never a reservation of the observed quantity.
    local source=s.sources[s.need_source]
    if not source then s.recipe_index=1;s.phase="recipe-candidate";return result() end
    if not source_live(source) then return abort(s,"source-changed") end
    local chest=defines and defines.inventory and defines.inventory.chest
    local typed=CHEST[source.entity.type] and type(chest)=="number"
    local slot=typed and (s.need_slot==1 and chest) or (not typed and s.inventory_ids[s.need_slot])
    if not slot then s.need_source=s.need_source+1;s.need_slot=1;return result() end
    s.need_slot=s.need_slot+1
    s.need_stock=s.need_stock+slot_count(source.entity,slot,s.need.item)
    if s.need_stock>=M.minimum[s.need.item]*s.valid_members then
      s.phase="need";stat("live_group_shortage_cancellations")
    end
    return result()
  elseif s.phase=="recipe-candidate" then
    local name=s.meta.recipes[s.need.stage][s.recipe_index];s.recipe_index=s.recipe_index+1
    if not name then s.phase="need";return result() end
    local recipe=s.members[1].station.force.recipes[name]
    if recipe and recipe.enabled then s.recipe_name=name;s.candidate=nil;s.candidate_index=1;s.phase="station-candidate" end
    return result()
  elseif s.phase=="station-candidate" then
    local m=s.members[s.candidate_index];s.candidate_index=s.candidate_index+1
    if not m then
      if s.candidate then s.material_index=1;s.phase="material-candidate" else s.phase="need" end
      return result()
    end
    -- Native cogitators have exactly one chest inventory. Unsupported
    -- compatibility entities remain diagnostic until their live slot is known.
    local chest=defines and defines.inventory and defines.inventory.chest
    if member_valid(m) and CHEST[m.station.type] and type(chest)=="number"
      and slot_count(m.station,chest,s.need.item)<M.minimum[s.need.item]
      and (not s.candidate or m.unit<s.candidate.unit) then s.candidate=m end
    return result()
  elseif s.phase=="material-candidate" then
    local source=s.sources[s.material_index];s.material_index=s.material_index+1
    if not source then s.phase="need";return result() end
    local item=s.meta.items[s.need.stage];local slot=source.positive_slots[item]
    if slot and source_live(source) and slot_count(source.entity,slot,item)>0 then s.material=source;s.phase="dispatch" end
    return result()
  elseif s.phase=="dispatch" then
    local acted,why=final_request(s,s.need,s.candidate,s.material)
    r.last_construction_requests=acted;r.stats.construction_requests=(r.stats.construction_requests or 0)+acted
    if why=="shortage-satisfied" then stat("live_shortage_cancellations") end
    if r.reservations[s.network..":"..s.need.stage] then s.stage_done[s.need.stage]=true end
    s.phase="need";return result(false,nil,acted)
  end
  return abort(s,"unknown-phase")
end

Q.register("shortage-roster",roster_step)
Q.register("shortage-assessment",group_step)
-- The legacy entry point is admission/readback only. Repeated callers and
-- a full/stalled broker never advance even one station or inventory scan.
function M.assess()
  local r=root();local j,status=Q.peek(0,"shortage-roster","all")
  if j and status=="ready" then
    Q.forget(0,"shortage-roster","all");j=nil
  end
  if not j and now()>=(r.next_assessment_tick or 0) then
    j,status=Q.submit(0,"shortage-roster","all",{})
  end
  return r.assessments,j and "pending" or status or "sleeping"
end
function M.on_configuration_changed()
  local r=root();r.epoch=r.epoch+1;r.pending_groups={};r.next_groups={};r.reservations={};r.next_assessment_tick=0
end
-- A build/removal after the last cell check must invalidate the pending
-- decision before dispatch. One force/surface job owns its chunk map: this
-- event hook does no scan over stations, entities, tasks or pending jobs.
function M.handle_entity_change(event)
  local e=event and (event.entity or event.created_entity or event.destination)
  if not(valid(e) and e.force and e.surface) then return false end
  local r=root();local key=group_key(e.force.index,e.surface.index);local s=r.pending_groups[key]
  r.next_groups[key]=0;r.next_assessment_tick=0
  if not s then return false end
  local p=e.position;local chunk=math.floor(p.x/32)..":"..math.floor(p.y/32)
  if s.cell_map[chunk] then
    s.world_changed=true
    for _,stage in ipairs(STAGES) do r.reservations[key..":"..stage]=nil end
    return true
  end
  return false
end
function M.install()
  if M.installed then return true end
  if not Q.install() then error("emergency facility assessment requires shared force planner") end
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600") or require("scripts.core.runtime_tick_broker")
  local service=broker.register_service({name="emergency_facility_placement_bridge_0643",
    category="planning",interval=M.interval,priority=950,budget=1,
    fn=function() local _,status=M.assess();return {processed=1,acted=0,detail="shortage admission:"..tostring(status)} end,
    note="admission only; shared force planner owns station/entity/candidate continuation"})
  if not service then error("emergency facility admission broker registration failed") end
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if registry and type(registry.on_configuration_changed)=="function" then
    registry.on_configuration_changed(M.on_configuration_changed,{owner="emergency_facility_placement_bridge_0643",route="metadata-configuration",category="planning"})
  end
  if registry and type(registry.on_event)=="function" and defines and defines.events then
    local events={}
    for _,name in ipairs({"on_built_entity","on_robot_built_entity","script_raised_built","script_raised_revive",
        "on_player_mined_entity","on_robot_mined_entity","on_entity_died","script_raised_destroy","on_entity_cloned"}) do
      if defines.events[name] then events[#events+1]=defines.events[name] end
    end
    if #events>0 then registry.on_event(events,M.handle_entity_change,nil,
      {owner="emergency_facility_placement_bridge_0643",route="pending-world-edits",category="planning"}) end
  end
  M.installed=true;return true
end
return M
