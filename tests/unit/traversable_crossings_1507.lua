-- Actual 0418 caller + shared broker continuation. These are Lua contracts,
-- not a claim of native FPS, native path solving, or native save acceptance.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000,surfaces={},connected_players={}}
storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},distraction={none=0},events={}}
local event_names={"on_script_path_request_finished","on_built_entity",
  "on_robot_built_entity","script_raised_built","script_raised_revive",
  "on_entity_cloned","on_entity_died","on_player_mined_entity",
  "on_robot_mined_entity","script_raised_destroy","on_player_rotated_entity",
  "on_player_built_tile","on_robot_built_tile","on_player_mined_tile",
  "on_robot_mined_tile","script_raised_set_tiles","on_chunk_deleted",
  "on_surface_deleted","on_surface_cleared"}
for index,name in ipairs(event_names)do defines.events[name]=index end
local native_events={}
script={on_event=function(id,fn)native_events[id]=fn end,
  get_event_handler=function(id)return native_events[id]end}
local services={}
_G.TechPriestsRuntimeTickBroker0600={base_interval=5,
  register_service=function(spec)services[spec.name]=spec;return spec end}
_G.tech_priests_any_player_near_0568=function()return true end
_G.TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local force={object_name="LuaForce",index=1,name="player"}
local calls,issued,teleports={}, {},0
local next_native=0
local blocked={}
local surface={object_name="LuaSurface",valid=true,index=1}
surface.request_path=function(spec)
  next_native=next_native+1
  calls[next_native]=spec
  assert(spec.pathfind_flags.no_break==false,"native path was made unsliceable")
  assert(spec.pathfind_flags.cache==false,"native learning ignored geometry changes")
  return next_native
end
surface.can_place_entity=function(spec)
  return not blocked[math.floor(spec.position.x)..":"..math.floor(spec.position.y)]
end
game.surfaces[1]=surface
prototypes={entity={priest={collision_box={{-0.4,-0.4},{0.4,0.4}},
  collision_mask={layers={player=true,water_tile=true}}}}}
local function pair_at(id,x,y)
  local station={object_name="LuaEntity",valid=true,name="junior-cogitator-station",
    unit_number=id,position={x=x,y=y},force=force,surface=surface}
  local priest={object_name="LuaEntity",valid=true,type="unit",name="priest",
    unit_number=id+10000,position={x=x,y=y},force=force,surface=surface,
    prototype=prototypes.entity.priest,
    commandable={valid=true,set_command=function(command)issued[#issued+1]=command end}}
  priest.teleport=function()teleports=teleports+1;return true end
  local pair={station=station,priest=priest,radius=36}
  storage.tech_priests.pairs_by_station[id]=pair
  return pair
end
local Q=require("scripts.core.force_planning_queue")
local Cross=require("scripts.core.traversable_crossings_1507")
local Movement=require("scripts.core.movement_controller")
assert(Movement.install())
local function advance(budget)
  game.tick=game.tick+5
  local result=services.force_planning_queue_1507.fn({tick=game.tick},budget or 16)
  assert(result.processed<=(budget or 16),"force planner exceeded offered work")
  assert((Q.root().stats.budget_contract_errors or 0)==0,"path worker exceeded one charged operation")
  return result
end
local function emit(name,event)
  event.tick=game.tick;event.name=defines.events[name]
  assert(native_events[event.name],"missing event route: "..name)(event)
end
local function request(pair,goal)
  local ok,why=Movement.request(pair,goal,"repair-travel",{
    owner="repair-executor-0516",priority=70,radius=0.5,ttl=7200})
  assert(ok,"real movement request refused: "..tostring(why))
  Movement.service(nil,24)
  return pair.movement_request_0418
end
local function learning_job(pair)
  for _,job in pairs(Q.root().jobs)do
    if job.kind==Cross.kind and job.payload.entity==pair.priest and job.status=="pending" then return job end
  end
end
local function wait_native(pair)
  local job=assert(learning_job(pair),"real caller did not queue learning")
  for _=1,300 do
    if job.state.request_id then return job,job.state.request_id end
    advance()
  end
  error("native request never started")
end
local function finish_learning(job,path,id)
  emit("on_script_path_request_finished",{id=id or job.state.request_id,path=path,try_again_later=false})
  for _=1,2000 do
    if job.status=="ready" then return job.result.status end
    advance()
  end
  error("learning failed to complete")
end
local function learn(pair,goal)
  request(pair,goal)
  local job,id=wait_native(pair)
  assert(finish_learning(job,{{position=pair.priest.position},
    {position=goal}},id)=="learned","valid native crossing was not learned")
end
local function drain_edits()
  for _=1,2000 do
    if Cross.root().edit_tail==0 then return end
    advance()
  end
  error("geometry continuation did not finish")
end

-- Cold, incomplete and full queues keep the original priest moving under
-- the original owner. Neither callback nor caller performs the planning loop.
local a=pair_at(1,0,4)
local goal={x=30,y=4}
local req=request(a,goal)
assert(req.x==30 and not req.ground_route_chunked and req.crossing_managed_1507,
  "pending learning replaced native fallback with an idle/guessed route")
assert(#calls==0 and issued[#issued].destination.x==30,"caller advanced native learning")
local first_job,id=wait_native(a)
local old_steps=first_job.steps
advance()
assert(first_job.status=="pending" and first_job.steps>old_steps,"waiting job was lost")
assert(a.movement_request_0418==req and a.priest.unit_number==10001,
  "learning replaced the original priest or active owner")

-- Save-like serialization preserves plain continuations and engine references.
-- Modules and event handlers are rebuilt from scratch, including Q's registry.
local function save_copy(value,seen)
  if type(value)~="table"then assert(type(value)~="function","function entered saved state");return value end
  if value.object_name then return value end
  seen=seen or {};if seen[value]then return seen[value]end
  local out={};seen[value]=out
  for key,item in pairs(value)do out[save_copy(key,seen)]=save_copy(item,seen)end
  return out
end
local function reload()
  storage=save_copy(storage)
  for _,name in ipairs({"scripts.core.force_planning_queue",
    "scripts.core.traversable_crossings_1507","scripts.core.movement_controller",
    "scripts.core.runtime_event_registry"})do package.loaded[name]=nil end
  Q=require("scripts.core.force_planning_queue")
  Cross=require("scripts.core.traversable_crossings_1507")
  Movement=require("scripts.core.movement_controller")
  assert(Movement.install())
  a=storage.tech_priests.pairs_by_station[1]
end
reload()
first_job=assert(learning_job(a))
assert(first_job.state.request_id==id,"save/reload lost native pending handle")
emit("on_script_path_request_finished",{id=id,path={{position={x=0,y=4}},
  {position={x=30,y=4}}},try_again_later=false})
advance(1)
assert(first_job.status=="pending","one step consumed the entire path")
reload()
first_job=assert(learning_job(a))
for _=1,300 do if first_job.status=="ready"then break end;advance()end
assert(first_job.status=="ready" and first_job.result.status=="learned",
  "save/reload failed to resume point/chunk processing")
Movement.stop(a,"restart-learned-route")
game.tick=game.tick+5
local reused=request(a,goal)
assert(reused.crossing_token_1507 and reused.x>0 and reused.x<30,
  "actual caller did not reuse learned crossing")
assert(issued[#issued].pathfind_flags.cache==false,"cached advice bypassed native path validation")
local token=reused.crossing_token_1507
local calls_before=#calls
local total_before=Q.root().total
a.priest.position={x=3,y=4}
game.tick=game.tick+5
assert(request(a,goal)==reused and reused.crossing_token_1507==token,
  "same owner/goal submission replaced an active learned waypoint")
assert(Q.root().total==total_before,"same route created another planner while moving between start cells")
a.priest.position={x=0,y=4}

-- The unrelated edit is processed gradually, then the exact learned record
-- remains reusable. No surface/force-wide route-cache eviction occurs.
emit("on_built_entity",{entity={valid=true,type="wall",surface=surface,
  position={x=205,y=205},bounding_box={{204.5,204.5},{205.5,205.5}}}})
assert(not Cross.validate(token),"unprocessed geometry edit was trusted")
drain_edits();game.tick=game.tick+5
assert(Cross.validate(token),"unrelated chunk edit invalidated a reusable crossing")
Movement.stop(a,"unrelated-edit")
local reused_again=request(a,goal)
assert(reused_again.crossing_token_1507.id==token.id and #calls==calls_before,
  "unrelated edit discarded/relearned the existing route")

-- Another route on the same surface uses different chunks and stays warm.
local b=pair_at(2,0,132)
learn(b,{x=30,y=132})
Movement.stop(b,"restart-other-route");game.tick=game.tick+5
local other=request(b,{x=30,y=132}).crossing_token_1507
assert(other,"second route did not warm")

-- Rotating a long collider can obstruct a learned crossing in chunks that its
-- previous narrow footprint never occupied. The actual consumer must fall
-- back immediately; after bounded invalidation an unrelated route stays warm.
local rotated=pair_at(9,33,260)
local rotated_goal={x=63,y=260}
learn(rotated,rotated_goal)
Movement.stop(rotated,"restart-before-rotation");game.tick=game.tick+5
local rotated_token=request(rotated,rotated_goal).crossing_token_1507
assert(rotated_token,"rotation fixture did not learn a crossing")
local rotation_edits_before=Cross.root().stats.edited_chunks
emit("on_player_rotated_entity",{previous_direction=0,entity={valid=true,
  type="storage-tank",surface=surface,position={x=96,y=260},
  bounding_box={{32,259.5},{160,260.5}}}})
assert(Cross.root().stats.edited_chunks==rotation_edits_before,
  "rotation callback scanned its full old/new footprint")
Movement.service(nil,24)
assert(not rotated.movement_request_0418.crossing_token_1507
  and rotated.movement_request_0418.x==rotated_goal.x,
  "actual caller used a stale crossing through a newly rotated collider")
drain_edits();game.tick=game.tick+5
assert(not Cross.validate(rotated_token),"rotated collision footprint kept its crossing reusable")
assert(Cross.validate(other),"rotation evicted an unrelated crossing on the same surface")

emit("on_built_entity",{entity={valid=true,type="wall",surface=surface,
  position={x=5,y=4},bounding_box={{4.5,3.5},{5.5,4.5}}}})
Movement.service(nil,24)
assert(not a.movement_request_0418.crossing_token_1507 and a.movement_request_0418.x==goal.x,
  "active cached route survived a new obstruction without native fallback")
drain_edits();game.tick=game.tick+5
assert(not Cross.validate(token),"edited crossing stayed reusable")
assert(Cross.validate(other),"edit invalidated an unrelated route on the same surface")
b.priest.force={object_name="LuaForce",index=99}
assert(not Cross.validate(other,b),"crossing survived force/profile change")
b.priest.force=force
for _=1,60 do game.tick=game.tick+10;Movement.service(nil,24)end
assert(teleports==0,"stale route used legacy teleport recovery through an obstruction")
assert(a.movement_request_0418.owner=="repair-executor-0516",
  "path invalidation stole work ownership")

-- A wall added after the async request began makes its eventual answer stale.
local c=pair_at(3,500,12)
request(c,{x=530,y=12})
local cj,cid=wait_native(c)
emit("on_built_entity",{entity={valid=true,type="wall",surface=surface,
  position={x=506,y=12},bounding_box={{505.5,11.5},{506.5,12.5}}}})
drain_edits()
local learned_before=Cross.root().stats.crossings_learned
local status=finish_learning(cj,{{position={x=500,y=12}},{position={x=530,y=12}}},cid)
assert(status=="edited-pending-path" and Cross.root().stats.crossings_learned==learned_before,
  "stale native result published a crossing through an edited chunk")

-- Native answers requiring destruction are not proof of traversability.
local d=pair_at(4,600,12)
request(d,{x=630,y=12});local dj,did=wait_native(d)
assert(finish_learning(dj,{{position={x=600,y=12}},
  {position={x=630,y=12},needs_destroy_to_reach=true}},did)=="destructive-path-rejected")

-- Full queue and no-action waiters leave actual movement live. Waiting on a
-- native event does not starve another force or a route that can make progress.
local cap=Q.max_jobs;Q.max_jobs=Q.root().total
local e=pair_at(5,700,12)
local e_req=request(e,{x=730,y=12})
assert(e_req.x==730 and not learning_job(e),"full queue idled/claimed a route")
Q.max_jobs=cap
game.tick=game.tick+5
request(e,{x=730,y=12})
local ej,eid=wait_native(e)
local fair_steps=0
Q.register("crossing-fairness-probe",function()fair_steps=fair_steps+1;return {processed=1,waiting=true}end)
local fair=Q.submit(2,"crossing-fairness-probe","waiting",{})
local before=fair_steps
assert(finish_learning(ej,{{position={x=700,y=12}},{position={x=730,y=12}}},eid)=="learned")
assert(fair_steps>before,"another force's no-action waiter starved")
Q.forget(2,"crossing-fairness-probe","waiting")

-- A bulk tile event is O(1) at delivery; each charged visit consumes one tile.
local tiles={}
for i=1,1024 do tiles[i]={position={x=2000+i,y=2000}}end
local edits_before=Cross.root().stats.edited_chunks
emit("on_player_built_tile",{surface_index=1,tiles=tiles})
assert(Cross.root().stats.edited_chunks==edits_before,"tile callback scanned its whole payload")
advance(1)
assert(Cross.root().stats.edited_chunks==edits_before+1,"one edit unit was a whole tile batch")
reload()
drain_edits()
assert(Cross.root().stats.edited_chunks==edits_before+1024,
  "save/reload lost part of the deferred tile edit")

-- Final collision failure is counted and leaves the original native fallback.
local f=pair_at(6,800,12)
learn(f,{x=830,y=12});Movement.stop(f,"blocked-exit")
blocked["812:12"]=true;game.tick=game.tick+5
local f_req=request(f,{x=830,y=12})
assert(not f_req.crossing_token_1507 and f_req.x==830,
  "live obstruction was ignored when consuming a learned crossing")
assert((Cross.root().stats.live_crossings_rejected or 0)>0,"rejected live check was not charged")

-- Footprints straddling a chunk boundary depend on the neighboring chunk.
local g=pair_at(7,20,20)
learn(g,{x=50,y=20});Movement.stop(g,"boundary-reuse");game.tick=game.tick+5
local boundary=request(g,{x=50,y=20}).crossing_token_1507
assert(boundary,"boundary crossing not learned")
emit("script_raised_set_tiles",{surface_index=1,tiles={{position={x=32,y=20}}}})
drain_edits();game.tick=game.tick+5
assert(not Cross.validate(boundary),"changed neighboring footprint chunk stayed reusable")
Cross.on_configuration_changed()
assert(not Cross.validate(other),"configuration changed collision profiles without retiring old crossings")
assert(teleports==0,"path learning fabricated physical movement")
print("[traversable-crossings-1507] PASS actual movement callers, native fallback, queue backpressure, force fairness, reload, local invalidation, stale native result, bulk tiles, live obstruction, zero teleport")
