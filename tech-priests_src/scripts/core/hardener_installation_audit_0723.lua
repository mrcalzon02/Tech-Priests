-- Tech Priests 0.1.674-dev final hardener installation audit.
-- Arms one post-loader finalization hook, quarantines retired regressions, records
-- degraded families, and remains read-only after the loader has finalized.

local M={version="0.1.674-dev",storage_key="hardener_installation_audit_0723",interval=311,recent_limit=100}
local function now()return game and game.tick or 0 end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function root()
 storage.tech_priests=storage.tech_priests or{}
 local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,stats={},recent={},last={},quarantine={},finalizer={}}
 storage.tech_priests[M.storage_key]=r;r.version=M.version;if r.enabled==nil then r.enabled=true end
 r.stats=r.stats or{};r.recent=r.recent or{};r.last=r.last or{};r.quarantine=r.quarantine or{};r.finalizer=r.finalizer or{};return r
end
local function stat(k,n)local r=root();r.stats[k]=(r.stats[k]or 0)+(tonumber(n)or 1)end
local function broker_service(name)local b=rawget(_G,"TechPriestsRuntimeTickBroker0600");for _,s in ipairs((b and b.services)or{})do if s.name==name then return s end end end
local function restore_ammo_wrappers()
 local restored=0
 local ok_leaf,leaf=pcall(require,"scripts.core.active_leaf_task_truth_0655")
 if ok_leaf and leaf and type(leaf.TECH_PRIESTS_0740_PRE_TRUTH)=="function"then leaf.truth=leaf.TECH_PRIESTS_0740_PRE_TRUTH;leaf.TECH_PRIESTS_0740_PRE_TRUTH=nil;leaf.ammo_scavenge_0740_wrapped=nil;restored=restored+1 end
 local ok_direct,direct=pcall(require,"scripts.core.direct_acquisition_executor_0513")
 if ok_direct and direct and type(direct.TECH_PRIESTS_0740_PRE_SERVICE_PAIR)=="function"then direct.service_pair=direct.TECH_PRIESTS_0740_PRE_SERVICE_PAIR;direct.TECH_PRIESTS_0740_PRE_SERVICE_PAIR=nil;direct.ammo_scavenge_0740_wrapped=nil;restored=restored+1 end
 local old=rawget(_G,"TECH_PRIESTS_0740_PRE_FORCE_COMBAT_TICK")
 if type(old)=="function"then _G.tech_priests_0293_force_combat_tick=old;_G.tech_priests_0292_force_combat_tick=old;_G.TECH_PRIESTS_0740_PRE_FORCE_COMBAT_TICK=nil;restored=restored+1 end
 return restored
end
local function quarantine_regressions()
 local r=root();local ammo,audit=broker_service("ammo_scavenge_priority_0740"),broker_service("development_integration_audit_0721")
 if ammo then ammo.enabled=false end;if audit then audit.enabled=true end
 local tp=storage.tech_priests;if tp.ammo_scavenge_priority_0740 then tp.ammo_scavenge_priority_0740.enabled=false end;if tp.development_integration_audit_0721 then tp.development_integration_audit_0721.enabled=true end
 r.quarantine={tick=now(),ammo_services_disabled=ammo and 1 or 0,development_audit_services_reenabled=audit and 1 or 0,ammo_wrappers_restored=restore_ammo_wrappers()};stat("regression_quarantines");return true
end
local function copy_failures(source)local out={};for _,f in ipairs(source or{})do out[#out+1]={module=safe(f.module),label=safe(f.label),reason=safe(f.reason)}end;return out end
local function signature(failures)local parts={};for _,f in ipairs(failures)do parts[#parts+1]=f.label.."="..f.reason end;table.sort(parts);return table.concat(parts,"|")end
function M.inspect()
 local r=root();local constraints=rawget(_G,"TechPriestsPlanningConstraints0646")
 local summary=constraints and type(constraints.installation_summary)=="function"and constraints.installation_summary()or nil
 local failures=summary and copy_failures(summary.failures)or{{module="scripts.core.planning_constraints_0646",label="planning_constraints_0646",reason="summary-unavailable"}}
 local snapshot={tick=now(),available=constraints~=nil,phase=summary and summary.phase or"unavailable",complete=summary and summary.complete==true or false,attempted=summary and tonumber(summary.attempted)or 0,passed=summary and tonumber(summary.passed)or 0,failed=#failures,failures=failures,degraded_families=summary and summary.degraded_families or{},quarantine=r.quarantine,finalizer=r.finalizer}
 r.last=snapshot;local sig=signature(failures)
 if sig~=r.last_failure_signature then r.last_failure_signature=sig;for _,f in ipairs(failures)do r.recent[#r.recent+1]={tick=now(),label=f.label,module=f.module,reason=f.reason}end;while #r.recent>M.recent_limit do table.remove(r.recent,1)end end
 stat("audits");if snapshot.complete then stat("complete_observations")else stat("incomplete_observations")end;return snapshot
end
local function wrap_final_installer()
 local ok,final=pcall(require,"scripts.core.task_auspex_0622")
 if not(ok and final and type(final.install)=="function")then return false,"task-auspex-final-installer-unavailable"end
 if final.recovery_finalizer_0744_wrapped then return true end
 final.recovery_finalizer_0744_wrapped=true;local previous=final.install
 final.install=function(...)
  local ok_previous,previous_result=pcall(previous,...)
  local constraints=rawget(_G,"TechPriestsPlanningConstraints0646");local finalized,final_result=false,"constraints-unavailable"
  if constraints and type(constraints.finalize_installation)=="function"then finalized,final_result=pcall(constraints.finalize_installation,"task-auspex-post-loader");finalized=finalized and final_result==true end
  local r=root();r.finalizer={tick=now(),previous_ok=ok_previous,previous_result=safe(previous_result),previous_explicit=previous_result==true,finalized=finalized,final_result=safe(final_result),final_explicit=final_result==true}
  M.inspect();if not ok_previous then error(previous_result,0)end
  return previous_result==true and finalized
 end
 return true
end
local function patch_diagnostics()
 local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
 if not(d and type(d.pair_dump_lines)=="function")then return false end;if d.hardener_installation_audit_0723_wrapped then return true end
 d.hardener_installation_audit_0723_wrapped=true;local previous=d.pair_dump_lines
 d.pair_dump_lines=function(...)
  local lines=previous(...);lines=type(lines)=="table"and lines or{};local last=M.inspect()
  lines[#lines+1]="PAIR-DUMP-0468 HARDENER-INSTALLATION-0723 phase="..safe(last.phase).." complete="..safe(last.complete).." attempted="..safe(last.attempted).." passed="..safe(last.passed).." failed="..safe(last.failed).." degraded_families="..safe(type(last.degraded_families)=="table"and table_size and table_size(last.degraded_families)or"?")
  for i=math.max(1,#root().recent-12),#root().recent do local e=root().recent[i];if e then lines[#lines+1]="PAIR-DUMP-0468 hardener.failure["..i.."] "..e.label.." module="..e.module.." reason="..e.reason end end
  return lines
 end
 return true
end
local function register_service()
 local b=rawget(_G,"TechPriestsRuntimeTickBroker0600");if not(b and type(b.register_service)=="function")then return false end
 return b.register_service({name="hardener_installation_audit_0723",category="diagnostics",interval=M.interval,priority=997,budget=1,dynamic_budget=false,note="read-only finalized hardener ledger",fn=function()local s=M.inspect();return{processed=1,acted=0,failed=s.failed,detail="phase="..s.phase.." failed="..s.failed}end})~=nil
end
function M.install()
 root();local quarantine_ok=quarantine_regressions();local finalizer_ok,why=wrap_final_installer();local diagnostics_ok=patch_diagnostics();local broker_ok=register_service();_G.TechPriestsHardenerInstallationAudit0723=M
 if log then log("[Tech-Priests recovery] hardener audit armed quarantine="..safe(quarantine_ok).." finalizer="..safe(finalizer_ok).." diagnostics="..safe(diagnostics_ok).." broker="..safe(broker_ok).." reason="..safe(why))end
 return quarantine_ok==true and finalizer_ok==true and diagnostics_ok==true and broker_ok==true
end
return M
