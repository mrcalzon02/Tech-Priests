-- Real 0721 traversal and broker registration. Large/deep/keyed graphs must
-- remain bounded and serialize progress; published summaries contain no cursor.
package.path="tech-priests_src/?.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=0}
defines={events={on_tick=1}}
local native={}
script={on_event=function(id,fn)native[id]=fn end,
  get_event_handler=function(id)return native[id]end,on_nth_tick=function()end}
commands={commands={},remove_command=function()return false end}
TechPriestsRuntimeEventRegistry=require("scripts.core.runtime_event_registry")
local Broker=require("scripts.core.runtime_tick_broker")
assert(Broker.install())
local Governor=require("scripts.core.efficiency_economy_0598")
assert(Governor.install())
local Cleanup=require("scripts.core.runtime_command_cleanup_0720");Cleanup.install()
local M=require("scripts.core.development_integration_audit_0721")
assert(M.install())
local function state()return storage.tech_priests[M.storage_key]end
local function start()
  state().last_serialization_tick=-M.serialization_interval
  local _,_,status=M.audit_all()
  assert(status.pending and not status.complete)
  return state().serialization_job_0721
end
local max_work=0
local function step(amount)
  game.tick=game.tick+5
  local scan,used=M.step_storage_audit(amount)
  local again,extra=M.step_storage_audit(amount)
  assert(scan==again and used+extra<=M.serialization_work_budget,
    "multiple same-tick callers exceeded the shared slice")
  max_work=math.max(max_work,scan.last_step_work)
  assert(scan.last_step_work<=M.serialization_work_budget)
  return scan
end
local function finish(limit)
  local turns=0
  while state().serialization_job_0721 do
    turns=turns+1;assert(turns<(limit or 15000),"storage walk failed to converge")
    step()
  end
  return state().last_serialization
end
local function assert_summary(summary)
  assert(not summary.frames and not summary.seen and not summary.root
    and not summary.processed and not summary.value,"published cursor/graph references")
  for _,entry in ipairs(summary.issues)do assert(#entry.path<=280)end
end

-- The previous 50001-node truncation is not a completed clean observation.
storage.tech_priests.payload={}
for i=1,60000 do storage.tech_priests.payload[i]=i end
state().last_serialization={tick=0,nodes=50001,truncated=true,unsupported=0,issues={}}
state().last_serialization_tick=game.tick
local _,_,initial=M.audit_all()
assert(initial.pending and initial.serialization.nodes==0,
  "legacy truncated result was accepted or admission performed the full walk")
local first_job=state().serialization_job_0721
step()
game.tick=game.tick+M.serialization_interval+1
M.audit_all()
assert(state().serialization_job_0721==first_job,"periodic deadline restarted pending progress")
local scan=finish()
assert(scan.complete and not scan.failed and not scan.pending and not scan.truncated
  and scan.nodes>60000,"large graph never completed beyond the old cutoff")
assert_summary(scan)
assert(state().last_completed_serialization_0721==scan)
local completed=scan
M.audit_all()
assert(not state().serialization_job_0721 and state().last.serialization==completed,
  "completion immediately restarted an overdue walk")

-- Supported table keys are part of the graph, not opaque labels. Plain
-- object_name strings do not turn a table with bad children into a LuaObject.
storage.tech_priests.payload=nil
local key={nested={callback=function()end}}
storage.tech_priests.keyed={[key]="value"}
storage.tech_priests.spoof={object_name="LuaEntity",callback=function()end}
start();scan=finish()
assert(scan.complete and scan.failed and scan.unsupported==2,
  "table-key contents or a spoofed LuaObject escaped inspection")
assert_summary(scan)
storage.tech_priests.keyed=nil;storage.tech_priests.spoof=nil

-- Unsupported keys are reported but never retained as saved bookmarks.
local unsupported=function()end
storage.tech_priests.bad_key={[unsupported]="bad"}
start();scan=finish()
assert(not scan.complete and scan.failed and scan.abort_reason=="unsupported-key")
assert_summary(scan)
storage.tech_priests.bad_key=nil

-- A deleted current key resets only that map. Seen-key skips and unwinding
-- still count against the same work allowance and remaining rows are visited.
local changing={}
for i=1,1000 do changing["row-"..i]=i end
storage.tech_priests.changing=changing
local job=start()
local deleted=false
for _=1,300 do
  step(24)
  job=state().serialization_job_0721
  for _,frame in ipairs(job and job.frames or {})do
    if frame.value==changing and frame.cursor then
      changing[frame.cursor]=nil;changing["new-tail"]=true;deleted=true;break
    end
  end
  if deleted then break end
end
assert(deleted,"fixture did not reach a real saved cursor")
scan=finish()
assert(scan.complete and not scan.failed and scan.cursor_resets>0,
  "deleted cursor lost progress or failed traversal")
storage.tech_priests.changing=nil

-- No recursive call stack or unbounded error path: excessive nesting fails
-- visibly instead of certifying a partial walk.
local old_limit=M.serialization_frame_limit
M.serialization_frame_limit=24
local deep={};storage.tech_priests.deep=deep
for _=1,100 do deep.child={};deep=deep.child end
start();scan=finish()
assert(not scan.complete and scan.failed and scan.truncated and scan.abort_reason=="frame-limit")
assert_summary(scan)
storage.tech_priests.deep=nil;M.serialization_frame_limit=old_limit

-- A restored Lua module uses only saved progress; it does not rewind a map or
-- write cache-warmness-dependent diagnostics into the saved graph.
storage.tech_priests.reload_rows={}
for i=1,6000 do storage.tech_priests.reload_rows[i]=i end
start()
-- Stock Lua may rehash a copied string-key map; Factorio preserves insertion
-- order in real saves (covered by the native scenario). Keep this portable
-- comparison inside a dense array for its entire thirty-slice window.
local reached_array=false
for _=1,300 do
  step(48)
  local pending=state().serialization_job_0721
  local frame=pending and pending.frames[#pending.frames]
  if frame and frame.value==storage.tech_priests.reload_rows and frame.cursor then
    reached_array=true;break
  end
end
assert(reached_array,"reload fixture did not reach its saved array cursor")
local function clone(value,seen)
  if type(value)~="table"then return value end
  seen=seen or {};if seen[value]then return seen[value]end
  local out={};seen[value]=out
  for k,v in pairs(value)do out[clone(k,seen)]=clone(v,seen)end
  return out
end
local checkpoint,checkpoint_tick=clone(storage),game.tick
local function deadlines()
  local saved=storage.tech_priests.efficiency_economy_0598.broker_deadlines.development_integration_audit_0721
  local service
  for _,candidate in ipairs(Broker.services)do
    if candidate.name=="development_integration_audit_0721"then service=candidate end
  end
  assert(saved.next_due_tick==service.next_due_tick
    and saved.next_due_tick==state().next_service_tick_0721,"saved broker deadline differs")
  return saved.next_due_tick
end
local warm={}
M.audit_all() -- An explicit caller arrives before the next broker callback.
for i=1,30 do
  local s=step()
  warm[i]={s.nodes,s.tables,s.work,s.last_step_work,s.pending,s.complete,s.unsupported,deadlines()}
end
-- Factorio evaluates control/installers before restoring persistent storage.
-- Do not model a joining client as reinstalling owners into the restored graph.
storage={tech_priests={pairs_by_station={}}};game.tick=checkpoint_tick
package.loaded["scripts.core.development_integration_audit_0721"]=nil
M=require("scripts.core.development_integration_audit_0721")
assert(M.install())
storage=clone(checkpoint)
M.audit_all()
for i=1,30 do
  local s=step()
  local values={s.nodes,s.tables,s.work,s.last_step_work,s.pending,s.complete,s.unsupported,deadlines()}
  for j=1,8 do assert(values[j]==warm[i][j],"fresh module changed saved traversal progress/deadline")end
end
scan=finish();assert(scan.complete and not scan.failed)
assert_summary(scan)

-- Replacing the storage root cannot certify the detached graph retained by
-- an otherwise copied audit state.
start();step(24)
local retained_state=state()
storage.tech_priests={pairs_by_station={},[M.storage_key]=retained_state,fresh=true}
scan=step()
assert(not scan.complete and scan.failed and scan.abort_reason=="root-changed")
M.audit_all();assert(state().serialization_job_0721.root==storage.tech_priests)
scan=finish();assert(scan.complete and not scan.failed)
print("[development-storage-audit-continuation] PASS >60000-nodes shared-budget="..max_work
  .." pending-not-pass no-expiry-restart table-keys spoof-guard deleted-cursor depth-limit reload-parity root-change")
