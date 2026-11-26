-- Native path learning is advisory. The 0418 controller remains the only
-- movement actuator, and every accepted crossing is walked by Factorio.
-- Long native results and geometry edits are consumed by the shared force
-- planner one point/chunk at a time; no callback walks an entire result.
local Q = require("scripts.core.force_planning_queue")
local M = { storage_key = "traversable_crossings_1507", kind = "crossing-learning",
  edit_kind = "crossing-edits", crossing_length = 12, max_dependencies = 9,
  max_cached = 2048, max_native_pending = 8, request_timeout = 3600,
  retry_ticks = 600, validation_per_tick = 64, live_checks_per_tick = 8 }

local function tick() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function point(p) return p and { x = p.x or p[1], y = p.y or p[2] } end
local function distance_sq(a,b)
  return (a.x-b.x)^2 + (a.y-b.y)^2
end
local function chunk_key(x,y) return x .. ":" .. y end
local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if not r then
    r = { surfaces = {}, cache = {}, ring = {}, ring_cursor = 0, next_record = 0,
      pending = {}, pending_count = 0, serial = 0, edits = {}, edit_head = 1,
      edit_tail = 0, configuration = 0, stats = {} }
    storage.tech_priests[M.storage_key] = r
  end
  return r
end
M.root = root
local function stat(name,n)
  local r = root(); r.stats[name] = (r.stats[name] or 0) + (n or 1)
end
local function surface_state(index)
  local r = root()
  local s = r.surfaces[index]
  if not s then
    s = { chunks = {}, pending_edits = 0, generation = 0 }
    r.surfaces[index] = s
  end
  return s
end
local function identity(surface,force,name,start,goal)
  -- A bounded start cell permits nearby priests to share a crossing. The
  -- final goal retains quarter-tile precision; no general direction guess.
  return table.concat({surface,force,name,math.floor(start.x/2),
    math.floor(start.y/2),math.floor(goal.x*4),math.floor(goal.y*4)}, ":")
end
local function bounds(box)
  local a = box and point(box.left_top or box[1])
  local b = box and point(box.right_bottom or box[2])
  if not (a and b and a.x and a.y and b.x and b.y) then return nil end
  return a,b
end

local function wake_edits()
  local r = root()
  if r.edit_head > r.edit_tail then return end
  local job = Q.peek(0,M.edit_kind,"geometry")
  if job then
    if job.status == "ready" then job.state = {}; Q.retry(job) end
  else
    Q.submit(0,M.edit_kind,"geometry",{})
  end
end
local function enqueue_edit(surface,record)
  if not surface then return end
  local r,s = root(),surface_state(surface)
  r.serial = r.serial + 1
  record.surface,record.serial = surface,r.serial
  r.edit_tail = r.edit_tail + 1
  r.edits[r.edit_tail] = record
  s.pending_edits = s.pending_edits + 1
  wake_edits()
end
local function invalidate_chunk(edit,x,y)
  local s = surface_state(edit.surface)
  local key = chunk_key(x,y)
  s.chunks[key] = math.max(s.chunks[key] or 0,edit.serial)
  stat("edited_chunks")
end
local function finish_edit(r,edit)
  local s = surface_state(edit.surface)
  s.pending_edits = math.max(0,s.pending_edits-1)
  r.edits[r.edit_head] = nil
  r.edit_head = r.edit_head + 1
  if r.edit_head > r.edit_tail then
    r.edit_head,r.edit_tail = 1,0
  end
end
local function edit_step(job)
  local r = root()
  local edit = r.edits[r.edit_head]
  if not edit then return { processed=1,done=true,result={status="caught-up"} } end
  if edit.tiles then
    local entry = edit.tiles[edit.cursor or 1]
    if not entry then finish_edit(r,edit)
    else
      local p = point(entry.position or entry)
      if p and p.x and p.y then
        invalidate_chunk(edit,math.floor(p.x/32),math.floor(p.y/32))
      end
      edit.cursor = (edit.cursor or 1) + 1
    end
  elseif edit.chunks then
    local p = edit.chunks[edit.cursor or 1]
    if not p then finish_edit(r,edit)
    else
      invalidate_chunk(edit,p.x,p.y)
      edit.cursor = (edit.cursor or 1) + 1
    end
  else
    local x,y = edit.x or edit.min_x,edit.y or edit.min_y
    invalidate_chunk(edit,x,y)
    x = x+1
    if x > edit.max_x then x,y = edit.min_x,y+1 end
    edit.x,edit.y = x,y
    if y > edit.max_y then finish_edit(r,edit) end
  end
  return {processed=1,done=r.edit_tail==0,result={status="caught-up"}}
end

local non_obstacles = {unit=true,character=true,["entity-ghost"]=true,
  ["tile-ghost"]=true,corpse=true,["item-entity"]=true,resource=true,
  projectile=true,["flying-text"]=true,["highlight-box"]=true,
  ["smoke-with-trigger"]=true,["particle-source"]=true}
function M.on_entity_changed(event)
  local e = event and (event.destination or event.entity or event.created_entity)
  if not (valid(e) and e.surface) or non_obstacles[e.type] then return end
  local a,b = bounds(e.bounding_box)
  if not a then a,b = point(e.position),point(e.position) end
  if not (a and b) then return end
  -- Rotation can exchange width and height. Cover both old and new boxes.
  if event.previous_direction ~= nil and e.position then
    local p = e.position
    local extent = math.max(math.abs(a.x-p.x),math.abs(a.y-p.y),
      math.abs(b.x-p.x),math.abs(b.y-p.y))
    a,b = {x=p.x-extent,y=p.y-extent},{x=p.x+extent,y=p.y+extent}
  end
  enqueue_edit(e.surface.index,{min_x=math.floor(a.x/32),min_y=math.floor(a.y/32),
    max_x=math.floor(b.x/32),max_y=math.floor(b.y/32)})
end
function M.on_tiles_changed(event)
  if not (event and event.tiles) then return end
  -- Native tile payloads contain ordinary tables and serializable LuaObjects.
  -- Retaining that array is O(1); each tile is inspected only by edit_step.
  enqueue_edit(event.surface_index or (event.surface and event.surface.index),
    {tiles=event.tiles,cursor=1})
end
function M.on_chunks_deleted(event)
  if not event then return end
  enqueue_edit(event.surface_index,{chunks=event.positions or event.chunks or {},cursor=1})
end
function M.on_surface_reset(event)
  local index = event and event.surface_index
  if not index then return end
  local s = surface_state(index)
  -- A cleared/deleted surface really changes every crossing on THAT surface.
  -- Other surfaces and forces retain their cache entries.
  s.generation,s.chunks = s.generation+1,{}
end
function M.on_configuration_changed()
  local r=root()
  -- Prototype geometry or collision masks may have changed. This is a
  -- configuration boundary, not the normal chunk-edit invalidation route.
  r.configuration=(r.configuration or 0)+1
  r.cache,r.ring,r.ring_cursor={},{},0
end

local function done(job,status)
  local r,s = root(),job.state
  if s.request_id and r.pending[s.request_id] then
    r.pending[s.request_id] = nil
    r.pending_count = math.max(0,r.pending_count-1)
  end
  s.path,s.edge,s.dependencies = nil,nil,nil
  stat(status)
  return {processed=1,done=true,result={status=status}}
end
function M.on_path_finished(event)
  local r = root()
  local pending = event and r.pending[event.id]
  if not pending then return end
  r.pending[event.id] = nil
  r.pending_count = math.max(0,r.pending_count-1)
  local job = Q.peek(pending.force,M.kind,pending.key)
  if not (job and job.status=="pending" and job.state.request_id==event.id) then return end
  job.state.request_id = nil
  -- This callback never scans/copies the native path, even for a huge route.
  job.state.path = event.path
  job.state.failed = not event.path
  job.state.busy = event.try_again_later==true
  job.state.phase = "path"
end

local function begin_cross(s,p)
  s.cross = {start=point(p),finish=point(p),length=0,dependencies={},seen={}}
end
local function prepare_point(s,p)
  local b=s.box
  s.point=p
  s.dep = {min_x=math.floor((p.x+b[1].x)/32),max_x=math.floor((p.x+b[2].x)/32),
    min_y=math.floor((p.y+b[1].y)/32),max_y=math.floor((p.y+b[2].y)/32)}
  s.phase="dependency"
end
local function publish_cross(job)
  local r,s,p = root(),job.state,job.payload
  local cross=s.cross
  if distance_sq(cross.start,cross.finish)<1 then return end
  local key=identity(p.surface,p.force,p.name,cross.start,p.goal)
  r.next_record=r.next_record+1
  local rec={id=r.next_record,key=key,surface=p.surface,force=p.force,name=p.name,
    start=cross.start,finish=cross.finish,goal=p.goal,
    generation=s.generation,dependencies=cross.dependencies,created_tick=tick()}
  -- A bounded ring prevents unbounded save growth; replacing one slot is O(1).
  r.ring_cursor=r.ring_cursor%M.max_cached+1
  local old=r.ring[r.ring_cursor]
  if old and r.cache[old.key] and r.cache[old.key].id==old.id then r.cache[old.key]=nil end
  r.cache[key]=rec
  r.ring[r.ring_cursor]={key=key,id=rec.id}
  stat("crossings_learned")
end
local function learning_step(job)
  local r,s,p=root(),job.state,job.payload
  local ss=surface_state(p.surface)
  if tick()-job.created_tick>M.request_timeout then return done(job,"learning-expired") end
  if ss.pending_edits>0 then wake_edits();return {processed=1,waiting=true} end
  local surface=game and game.surfaces and game.surfaces[p.surface]
  if not surface or surface.valid==false then return done(job,"surface-gone") end
  if s.generation and s.generation~=ss.generation then return done(job,"surface-changed") end
  if s.configuration and s.configuration~=(r.configuration or 0) then return done(job,"collision-profile-changed") end
  if not s.phase then
    if r.pending_count>=M.max_native_pending
      or not Q.claim_tick("native-crossing-path",1) then return {processed=1,waiting=true} end
    local prototype=prototypes and prototypes.entity and prototypes.entity[p.name]
      or (valid(p.entity) and p.entity.prototype)
    local a,b
    if prototype then a,b=bounds(prototype.collision_box) end
    if not (a and b and prototype.collision_mask and surface.request_path)
      or math.max(b.x-a.x,b.y-a.y)>4 then return done(job,"native-profile-unavailable") end
    s.box,s.serial,s.generation,s.configuration={a,b},r.serial,ss.generation,r.configuration or 0
    local ok,id=pcall(surface.request_path,{bounding_box={a,b},
      collision_mask=prototype.collision_mask,start=p.start,goal=p.goal,
      force=p.force,radius=p.radius,can_open_gates=false,max_gap_size=0,
      max_attack_distance=0,entity_to_ignore=valid(p.entity) and p.entity or nil,
      pathfind_flags={cache=false,low_priority=true,no_break=false,
        allow_destroy_friendly_entities=false,allow_paths_through_own_entities=false}})
    if not (ok and id) then return done(job,"native-path-rejected") end
    s.request_id,s.phase=id,"waiting"
    r.pending[id]={force=p.force,key=job.key}
    r.pending_count=r.pending_count+1
    stat("native_requests")
  elseif s.phase=="waiting" then
    return {processed=1,waiting=true}
  elseif s.phase=="path" then
    if s.failed then return done(job,s.busy and "native-busy" or "native-no-path") end
    local node=s.path and s.path[s.path_index or 1]
    if not node then
      if s.cross and s.cross.length>0 then s.finish_after_publish=true;s.phase="validate";s.check=1
      else return done(job,"learned") end
    elseif node.needs_destroy_to_reach then return done(job,"destructive-path-rejected")
    else
      local target=point(node.position)
      if not (target and target.x and target.y) then return done(job,"invalid-path-point") end
      s.last=s.last or point(p.start)
      if not s.cross then begin_cross(s,s.last) end
      local dx,dy=target.x-s.last.x,target.y-s.last.y
      s.edge={start=point(s.last),target=target,steps=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy))),index=0}
      s.path_index=(s.path_index or 1)+1
      -- Include the entry footprint as well as the traversed microsegments.
      prepare_point(s,s.last)
    end
  elseif s.phase=="edge" then
    local edge=s.edge
    edge.index=edge.index+1
    if edge.index>edge.steps then s.edge=nil;s.phase="path"
    else
      local ratio=edge.index/edge.steps
      local next_point={x=edge.start.x+(edge.target.x-edge.start.x)*ratio,
        y=edge.start.y+(edge.target.y-edge.start.y)*ratio}
      s.cross.length=s.cross.length+math.sqrt(distance_sq(s.last,next_point))
      s.last=next_point;s.cross.finish=point(next_point)
      prepare_point(s,next_point)
    end
  elseif s.phase=="dependency" then
    local d=s.dep
    local x,y=d.x or d.min_x,d.y or d.min_y
    local key=chunk_key(x,y)
    local version=ss.chunks[key] or 0
    if version>s.serial then return done(job,"edited-pending-path") end
    if not s.cross.seen[key] then
      if #s.cross.dependencies>=M.max_dependencies then return done(job,"crossing-too-wide") end
      s.cross.seen[key]=true
      s.cross.dependencies[#s.cross.dependencies+1]={key=key,version=version}
    end
    x=x+1;if x>d.max_x then x,y=d.min_x,y+1 end
    d.x,d.y=x,y
    if y>d.max_y then
      s.dep=nil
      if s.cross.length>=M.crossing_length then s.phase="validate";s.check=1
      else s.phase="edge" end
    end
  elseif s.phase=="validate" then
    local dependency=s.cross.dependencies[s.check]
    if dependency then
      if (ss.chunks[dependency.key] or 0)~=dependency.version then return done(job,"edited-pending-crossing") end
      s.check=s.check+1
    else s.phase="publish" end
  elseif s.phase=="publish" then
    publish_cross(job)
    if s.finish_after_publish then return done(job,"learned") end
    begin_cross(s,s.last)
    -- Dependency for the shared boundary belongs to both crossings.
    prepare_point(s,s.last)
  end
  return {processed=1}
end

function M.validate(token,pair)
  if not token then return false,"no-crossing" end
  local r=root()
  local rec=r.cache[token.key]
  if not rec or rec.id~=token.id then return false,"crossing-replaced" end
  if pair then
    local e=pair.priest
    if not (valid(e) and e.surface and e.force and e.surface.index==rec.surface
      and e.force.index==rec.force and e.name==rec.name) then return false,"crossing-profile-changed" end
  end
  local ss=surface_state(rec.surface)
  if ss.pending_edits>0 then wake_edits();return false,"geometry-edit-pending" end
  if ss.generation~=rec.generation then return false,"surface-changed" end
  for i=1,#rec.dependencies do
    if not Q.claim_tick("crossing-validation",M.validation_per_tick) then return false,"validation-budget" end
    local d=rec.dependencies[i]
    if (ss.chunks[d.key] or 0)~=d.version then stat("stale_crossings_rejected");return false,"edited-crossing" end
  end
  return true,rec
end
function M.select(pair,goal,maximum,radius)
  if not M.installed then return nil,nil,"not-installed" end
  local e=pair and pair.priest
  if not (valid(e) and valid(pair.station) and e.surface and e.force and goal)
    or e.surface~=pair.station.surface or e.force~=pair.station.force then return nil,nil,"invalid-pair" end
  wake_edits()
  local r,s=root(),surface_state(e.surface.index)
  if s.pending_edits>0 then return nil,nil,"geometry-edit-pending" end
  local key=identity(e.surface.index,e.force.index,e.name,e.position,goal)
  local rec=r.cache[key]
  if rec and distance_sq(rec.start,e.position)<=9
    and distance_sq(rec.finish,e.position)>1
    and distance_sq(rec.finish,e.position)<=(maximum or 18)^2 then
    local token={key=key,id=rec.id}
    local ok=M.validate(token,pair)
    if ok and Q.claim_tick("crossing-live-check",M.live_checks_per_tick) then
      local checked,clear=pcall(e.surface.can_place_entity,{name=e.name,
        position=rec.finish,force=e.force})
      if checked and clear then stat("crossings_reused");return point(rec.finish),token,"learned-crossing" end
      stat("live_crossings_rejected")
    end
  end
  local job=Q.peek(e.force.index,M.kind,key)
  local existing=pair.crossing_learning_1507
  if not job and existing and existing.force==e.force.index
    and existing.surface==e.surface.index and existing.name==e.name
    and distance_sq(existing.goal,goal)<=0.04 then
    local inflight=Q.peek(existing.force,M.kind,existing.key)
    local active=pair.movement_request_0418
    if inflight and (inflight.status=="pending" or (active
      and active.crossing_managed_1507 and (active.expires_tick or -1)>=tick()
      and distance_sq(active.ground_route_final_destination or active,goal)<=0.04)) then
      return nil,nil,inflight.status=="pending" and "pending" or "active-native-route"
    end
  end
  if job and job.status=="ready" and tick()-(job.completed_tick or tick())>=M.retry_ticks then
    Q.forget(e.force.index,M.kind,key);job=nil
  end
  if not job then
    local submitted,status=Q.submit(e.force.index,M.kind,key,{surface=e.surface.index,
      force=e.force.index,name=e.name,start=point(e.position),goal=point(goal),
      radius=math.max(0.15,tonumber(radius) or 0.75),entity=e})
    if submitted then pair.crossing_learning_1507={force=e.force.index,
      surface=e.surface.index,name=e.name,key=key,goal=point(goal)} end
    return nil,nil,status
  end
  return nil,nil,job.status=="ready" and "native-fallback" or "pending"
end

Q.register(M.kind,learning_step)
Q.register(M.edit_kind,edit_step)
function M.install()
  if not Q.install() then return false end
  local registry=require("scripts.core.runtime_event_registry")
  local events=defines and defines.events or {}
  local function bind(name,fn)
    if not events[name] then return true end
    return registry.on_event(events[name],fn,nil,{owner="traversable-crossings-1507",
      route=name,category="movement",priority=-100,note="bounded local geometry invalidation"})~=nil
  end
  local installed=bind("on_script_path_request_finished",M.on_path_finished)
  for _,name in ipairs({"on_built_entity","on_robot_built_entity","script_raised_built",
    "script_raised_revive","on_entity_cloned","on_entity_died","on_player_mined_entity",
    "on_robot_mined_entity","script_raised_destroy","on_player_rotated_entity"}) do
    installed=bind(name,M.on_entity_changed) and installed
  end
  for _,name in ipairs({"on_player_built_tile","on_robot_built_tile","on_player_mined_tile",
    "on_robot_mined_tile","script_raised_set_tiles"}) do installed=bind(name,M.on_tiles_changed) and installed end
  installed=bind("on_chunk_deleted",M.on_chunks_deleted) and installed
  installed=bind("on_surface_deleted",M.on_surface_reset) and installed
  installed=bind("on_surface_cleared",M.on_surface_reset) and installed
  registry.on_configuration_changed(M.on_configuration_changed,{owner="traversable-crossings-1507",
    route="prototype-geometry-changed",category="movement",note="invalidate changed prototype collision profiles"})
  M.installed=installed
  return installed
end
return M
