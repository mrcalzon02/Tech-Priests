-- Save-safe planning membership walk. One call performs at most one bounded
-- query, one returned/retained candidate, or one setup/final validation step.
-- This does not claim items, choose work, or advance outside the force broker.
local M={query_limit=16,max_depth=7,cell_size=32}
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function epoch_root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests.planning_area_epochs_1507
  if not r then r={surfaces={}};storage.tech_priests.planning_area_epochs_1507=r end
  return r
end
local function epochs(surface)
  local r=epoch_root();local e=r.surfaces[surface]
  if not e then e={regions={},tiles=0};r.surfaces[surface]=e end
  return e
end
local function region_key(level,x,y) return level..":"..x..":"..y end
local function coverage(s)
  local span=math.max(s.x2-s.x1+1,s.y2-s.y1+1)
  local size,level=1,0
  while size<span and level<20 do size=size*2;level=level+1 end
  if size<span then return nil end
  local out={};local e=epochs(s.surface_index)
  for x=math.floor(s.x1/size),math.floor(s.x2/size) do
    for y=math.floor(s.y1/size),math.floor(s.y2/size) do
      local key=region_key(level,x,y);out[#out+1]={key=key,epoch=e.regions[key] or 0}
    end
  end
  s.tile_epoch=e.tiles
  return out
end
-- One event touches a fixed 21 ancestor counters, independent of station/job
-- count. An area's rectangle is covered by at most four nodes at one level.
function M.note_entity(event)
  local e=event and (event.entity or event.created_entity or event.destination)
  if not valid(e) then return false end
  local counters=epochs(e.surface.index);local x,y=math.floor(e.position.x/32),math.floor(e.position.y/32)
  local size=1
  for level=0,20 do
    local key=region_key(level,math.floor(x/size),math.floor(y/size))
    counters.regions[key]=(counters.regions[key] or 0)+1;size=size*2
  end
  return true
end
function M.note_tiles(event)
  local index=event and (event.surface_index or event.surface and event.surface.index)
  if not index then return false end
  -- A tile event can contain an arbitrarily large array. Planning snapshots
  -- conservatively retry on one surface epoch; route caches have their own
  -- bounded, chunk-local tile invalidation and are not touched here.
  local e=epochs(index);e.tiles=e.tiles+1;return true
end
local function signature(surface,key)
  local root=storage and storage.tech_priests and storage.tech_priests.efficiency_economy_0579
  local index=root and root.enabled~=false and root.use_indexed_catalog_cells~=false
    and root.surfaces and root.surfaces[tostring(surface)]
  local rec=index and index.cells and index.cells[key]
  return rec,rec and rec.entities,rec and rec.known_tick,index and index.dirty and index.dirty[key]
end
local function pair_live(s)
  local p=s.pair;local e=p and p.station
  return valid(e) and e==s.station and valid(p.priest)
    and e.force==s.force and e.surface==s.surface
    and e.position.x==s.x and e.position.y==s.y
end
local function same_cell(s,c)
  local rec,list,stamp,dirty=signature(s.surface_index,c.key)
  return rec==c.record and list==c.list and stamp==c.stamp and dirty==c.dirty
end
local function stopped(s,reason)
  s.done=true;s.stale=true;s.reason=reason
  return {processed=1,done=true,stale=true,reason=reason}
end
local function next_cell(s)
  s.current=nil;s.cy=s.cy+1
  if s.cy>s.y2 then s.cy=s.y1;s.cx=s.cx+1 end
  s.phase="cell"
end
local function candidate(s,e)
  if not(valid(e) and s.type_set[e.type] and e.surface==s.surface and (s.force_policy=="any" or e.force==s.force
      or (s.force_policy=="same-or-neutral" and e.force and e.force.name=="neutral"))) then return nil end
  local p=e.position;local dx,dy=p.x-s.x,p.y-s.y
  if dx*dx+dy*dy>s.radius*s.radius then return nil end
  local key=e.unit_number or (tostring(e.type)..":"..tostring(e.name)..":"..p.x..":"..p.y)
  if s.seen[key] then return nil end
  s.seen[key]=true
  return e
end
function M.begin(pair,radius,types,options)
  options=options or {}
  if not(pair and valid(pair.station) and valid(pair.priest)) then return nil,"invalid-pair" end
  local station=pair.station;local p=station.position;radius=math.max(0,tonumber(radius) or 0)
  local x1,y1=math.floor((p.x-radius)/M.cell_size),math.floor((p.y-radius)/M.cell_size)
  local s={pair=pair,station=station,force=station.force,surface=station.surface,
    surface_index=station.surface.index,x=p.x,y=p.y,radius=radius,force_policy=options.force_policy or "same",
    x1=x1,y1=y1,x2=math.floor((p.x+radius)/M.cell_size),y2=math.floor((p.y+radius)/M.cell_size),
    cx=x1,cy=y1,phase="types",types=type(types)=="string" and {types} or types or {},
    type_cursor=1,type_set={},cells={},seen={},started_tick=now(),work=0,queries=0}
  s.coverage=coverage(s)
  if not s.coverage then return nil,"area-too-large" end
  return s
end
function M.current(s)
  if not (s and pair_live(s) and s.coverage) then return false end
  local e=epochs(s.surface_index)
  if e.tiles~=s.tile_epoch then return false end
  for i=1,#s.coverage do
    local node=s.coverage[i]
    if (e.regions[node.key] or 0)~=node.epoch then return false end
  end
  return true
end
function M.validate(s)
  if not s then return {processed=1,done=true,stale=true,reason="invalid-scan"} end
  if not s.revalidating then
    s.revalidating=true;s.phase="validate";s.done=nil;s.validate_cursor=1
  end
  local result=M.step(s)
  if result.done then s.revalidating=nil end
  return result
end
function M.step(s)
  if not s then return {processed=1,done=true,stale=true,reason="invalid-scan"} end
  if s.done then return {processed=1,done=true,stale=s.stale,reason=s.reason} end
  s.work=s.work+1
  if not M.current(s) then return stopped(s,"world-or-station-changed") end
  if s.phase=="types" then
    local kind=s.types[s.type_cursor];s.type_cursor=s.type_cursor+1
    if kind then s.type_set[kind]=true else s.phase="cell" end
    return {processed=1}
  elseif s.phase=="cell" then
    if s.cx>s.x2 then s.phase="validate";s.validate_cursor=1;return {processed=1} end
    local key=s.cx..":"..s.cy
    local rec,list,stamp,dirty=signature(s.surface_index,key)
    local cell={key=key,record=rec,list=list,stamp=stamp,dirty=dirty}
    s.cells[#s.cells+1]=cell
    if rec and list and not dirty and tonumber(stamp) and stamp>=0 and stamp<=now() and now()-stamp<=600 then
      s.current={kind="index",cell=cell,map=list,key=nil};s.phase="read"
    else
      local size=M.cell_size
      local area={math.max(s.cx*size,s.x-s.radius),math.max(s.cy*size,s.y-s.radius),
        math.min(s.cx*size+size,s.x+s.radius),math.min(s.cy*size+size,s.y+s.radius),0}
      s.current={kind="query",cell=cell,pending={area},at=1};s.phase="read"
    end
    return {processed=1}
  elseif s.phase=="validate" then
    local cell=s.cells[s.validate_cursor];s.validate_cursor=s.validate_cursor+1
    if not cell then s.done=true;s.finished_tick=now();return {processed=1,done=true} end
    if not same_cell(s,cell) then return stopped(s,"world-changed") end
    return {processed=1}
  end
  local c=s.current
  if not same_cell(s,c.cell) then return stopped(s,"world-changed") end
  if c.kind=="index" then
    if c.key~=nil and c.map[c.key]==nil then return stopped(s,"membership-changed") end
    local key,e=next(c.map,c.key);c.key=key
    if key==nil then next_cell(s);return {processed=1} end
    return {processed=1,entity=candidate(s,e)}
  elseif c.batch then
    local e=c.batch[c.cursor]
    if e then c.cursor=c.cursor+1;return {processed=1,entity=candidate(s,e)} end
    if #c.batch>=M.query_limit then
      local a=c.area
      if a[5]>=M.max_depth then return stopped(s,"saturated-world-cell") end
      local mx,my=(a[1]+a[3])/2,(a[2]+a[4])/2;local depth=a[5]+1;local q=c.pending
      q[#q+1]={a[1],a[2],mx,my,depth};q[#q+1]={mx,a[2],a[3],my,depth}
      q[#q+1]={a[1],my,mx,a[4],depth};q[#q+1]={mx,my,a[3],a[4],depth}
    end
    c.batch=nil
    return {processed=1}
  end
  local area=c.pending[c.at];c.at=c.at+1
  if not area then next_cell(s);return {processed=1} end
  if area[3]<=area[1] or area[4]<=area[2] then return {processed=1} end
  local ok,entities=pcall(s.surface.find_entities_filtered,{area={{area[1],area[2]},{area[3],area[4]}},
    force=s.force_policy=="same" and s.force or nil,type=s.types,limit=M.query_limit})
  s.queries=s.queries+1
  if not(ok and type(entities)=="table") then return stopped(s,"world-query-failed") end
  if #entities>M.query_limit then return stopped(s,"uncapped-world-query") end
  c.area,c.batch,c.cursor=area,entities,1
  return {processed=1,queried=true}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
    or require("scripts.core.runtime_event_registry")
  if M.registry==registry then return true end
  if not(registry and registry.on_event and defines and defines.events) then return false end
  local changes,tiles={},{}
  for _,name in ipairs({"on_built_entity","on_robot_built_entity","script_raised_built","script_raised_revive",
      "on_player_mined_entity","on_robot_mined_entity","on_entity_died","script_raised_destroy","on_entity_cloned",
      "on_player_rotated_entity"}) do
    if defines.events[name] then changes[#changes+1]=defines.events[name] end
  end
  for _,name in ipairs({"on_player_built_tile","on_robot_built_tile","on_player_mined_tile","on_robot_mined_tile","script_raised_set_tiles"}) do
    if defines.events[name] then tiles[#tiles+1]=defines.events[name] end
  end
  if #changes>0 then registry.on_event(changes,M.note_entity,nil,{owner="bounded_planning_area_1507",route="entity-epochs",category="planning"}) end
  if #tiles>0 then registry.on_event(tiles,M.note_tiles,nil,{owner="bounded_planning_area_1507",route="tile-epochs",category="planning"}) end
  M.registry=registry;return true
end
return M
