-- Stage with the actual scripts/shared trees and base. Create a save, then
-- benchmark it for 10000 ticks. The saved 0721 job resumes through its existing
-- service callback; native LuaObjects and supported table keys are retained.
TechPriestsRuntimeEventRegistry=require("scripts.core.runtime_event_registry")
local Broker=require("scripts.core.runtime_tick_broker")
local Governor=require("scripts.core.efficiency_economy_0598")
local Cleanup=require("scripts.core.runtime_command_cleanup_0720")
local Audit=require("scripts.core.development_integration_audit_0721")
assert(Broker.install());assert(Governor.install());Cleanup.install();assert(Audit.install())
local function check(value,message)assert(value,"[AUDIT CONTINUATION NATIVE] "..message)end
local function state()return storage.tech_priests[Audit.storage_key]end
local function service()
  for _,entry in ipairs(Broker.services)do
    if entry.name=="development_integration_audit_0721"then return entry end
  end
  error("actual audit service missing")
end
local function clone(value,seen)
  if type(value)~="table"then return value end
  seen=seen or {};if seen[value]then return seen[value]end
  local result={};seen[value]=result
  -- Native Factorio tables retain insertion order, including after save/load.
  for key,entry in pairs(value)do result[clone(key,seen)]=clone(entry,seen)end
  return result
end
local function progress(check_service)
  local audit=state()
  local job=audit.serialization_job_0721
  local frame=job.frames[#job.frames]
  local scan=job.scan
  local deadline=storage.tech_priests.efficiency_economy_0598.broker_deadlines.development_integration_audit_0721
  if check_service then
    check(deadline.next_due_tick==service().next_due_tick
        and deadline.next_due_tick==audit.next_service_tick_0721,
      "actual service and persistent broker deadlines differ")
  end
  return {nodes=scan.nodes,tables=scan.tables,work=scan.work,last_step_work=scan.last_step_work,
    lua_objects=scan.lua_objects,circular_references=scan.circular_references,
    frame_count=#job.frames,phase=frame.phase,cursor=frame.cursor,current_key=frame.current_key,
    next_key=next(frame.value,frame.cursor),path=frame.path,next_due_tick=deadline.next_due_tick,
    next_audit_tick=audit.next_audit_tick_0721,pending=scan.pending,complete=scan.complete}
end
local original_step=Audit.step_storage_audit
Audit.step_storage_audit=function(...)
  local profiler=helpers.create_profiler(false)
  local scan,work=original_step(...)
  profiler.stop()
  if work>0 then
    log{"","[TP-AUDIT-SLICE] tick=",game.tick," work=",work," duration=",profiler}
  end
  return scan,work
end
script.on_init(function()
  storage.tech_priests={pairs_by_station={},payload={}}
  local force=game.forces.player
  for i=1,60000 do storage.tech_priests.payload[i]=i end
  for i=1,1000 do storage.tech_priests.payload["engine-"..i]=force end
  local key={nested={value=7}}
  storage.tech_priests.keyed={[key]=true,[force]="native-force-key"}
  storage.tech_priests.key_alias=key
  storage.tech_priests.cycle=storage.tech_priests
  local _,_,status=Audit.audit_all()
  check(status.pending and not status.complete and status.serialization.nodes==0,
    "admission drained or passed an incomplete walk")
  local scan=Audit.step_storage_audit(48)
  check(scan.pending and scan.work>0,"mid-walk save was not prepared")
  local saved=progress(true)
  check(type(saved.cursor)=="number"and saved.path=="storage.tech_priests[payload]",
    "checkpoint did not stop inside the native ordered numeric payload")
  local checkpoint=clone(storage.tech_priests)
  Audit.audit_all() -- Same explicit caller and shared-tick slice as after load.
  Audit.step_storage_audit(256)
  local warm=progress(true)
  storage.tech_priests=checkpoint
  service().next_due_tick=state().next_service_tick_0721
  storage.audit_fixture={saved=saved,warm=warm,saved_work=saved.work,saved_nodes=saved.nodes,
    max_work=scan.last_step_work,started_tick=scan.tick,done=false,reloaded=false}
  log("[TP-AUDIT-CREATE] "..helpers.table_to_json{passed=true,saved_work=saved.work,
    saved_nodes=saved.nodes,saved_cursor=saved.cursor,saved_phase=saved.phase,
    saved_next_key=saved.next_key,pending=saved.pending,complete=saved.complete})
end)
script.on_event(defines.events.on_tick,function(event)
  local fixture=storage.audit_fixture
  if not fixture or fixture.done then return end
  if not fixture.reloaded then
    check(game.tick==fixture.started_tick,"first loaded event changed the checkpoint tick")
    local force_key_found=false
    for key,value in pairs(storage.tech_priests.keyed)do
      if type(key)=="userdata"and key==game.forces.player and value=="native-force-key"then
        force_key_found=true
      end
    end
    check(storage.tech_priests.keyed[storage.tech_priests.key_alias]==true
        and force_key_found
        and storage.tech_priests.cycle==storage.tech_priests,
      "native table/LuaObject key or cyclic alias changed after load")
    local restored=progress(false)
    for _,field in ipairs({"nodes","tables","work","last_step_work","frame_count","phase",
        "cursor","current_key","next_key","path","next_due_tick","next_audit_tick"})do
      check(restored[field]==fixture.saved[field],"saved cursor/progress mismatch: "..field)
    end
    Audit.audit_all() -- Explicit caller before its next scheduled callback.
    Audit.step_storage_audit(256)
    local fresh=progress(true)
    for _,field in ipairs({"nodes","tables","work","last_step_work","lua_objects",
        "circular_references","frame_count","phase","cursor","current_key","next_key",
        "path","next_due_tick","next_audit_tick","pending","complete"})do
      check(fresh[field]==fixture.warm[field],"first loaded step differs from warm step: "..field)
    end
    fixture.reloaded=true
  end
  local owner=service()
  if game.tick>=owner.next_due_tick then owner.fn(event,1,owner)end
  local scan=state().last_serialization
  fixture.max_work=math.max(fixture.max_work,scan.last_step_work)
  check(scan.last_step_work<=256,"native shared work budget exceeded")
  if not state().serialization_job_0721 then
    check(scan.complete and not scan.failed and not scan.pending and not scan.truncated,
      "native walk aborted or mislabeled an incomplete scan")
    check(scan.nodes>60000 and scan.lua_objects>=1000,"large native graph was not fully traversed")
    check(state().last_completed_serialization_0721==scan,"last completed summary was lost")
    check(not scan.frames and not scan.seen and not scan.root,"published traversal references")
    Audit.audit_all()
    check(not state().serialization_job_0721,"overdue long walk immediately restarted")
    fixture.done=true
    log("[TP-AUDIT-PASS] "..helpers.table_to_json{passed=true,tick=game.tick,
      completion_ticks=scan.finished_tick-scan.tick,nodes=scan.nodes,tables=scan.tables,
      lua_objects=scan.lua_objects,work=scan.work,max_step_work=fixture.max_work,
      saved_work=fixture.saved_work,native_reloaded_cursor=true,
      saved_cursor=fixture.saved.cursor,saved_phase=fixture.saved.phase,
      saved_next_key=fixture.saved.next_key,native_first_step_parity=true,
      native_table_and_luaobject_keys=true,published_summary_only=true,
      next_service_tick=state().next_service_tick_0721,
      next_walk_tick=state().last_serialization_tick+Audit.serialization_interval})
  end
end)
