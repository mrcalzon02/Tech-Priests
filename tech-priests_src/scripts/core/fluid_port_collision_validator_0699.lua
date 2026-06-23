-- Tech Priests 0.1.670 shared fluid-port collision validator.
--
-- A pipe tile beside a multi-fluid machine can geometrically touch more than one
-- fluidbox port. Before input or output planners see a proposal, this guard checks
-- every fluidbox whose runtime connection target occupies the same tile. The tile
-- is permitted only when every touching box is proven compatible with the intended
-- fluid. A different known fluid is rejected; an empty unfiltered unknown box is
-- rejected as ambiguous. Active plans are aborted if later recipe/filter/segment
-- changes make either endpoint unsafe.
--
-- No fluid mutation, construction, recipe change, or movement occurs here.

local M = {
  version = "0.1.670",
  storage_key = "fluid_port_collision_validator_0699",
  position_epsilon = 0.15,
  abort_cooldown = 60 * 10,
}

local previous_build_install
local previous_build_service_pair

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function same_pos(a,b) return a and b and math.abs((a.x or 0)-(b.x or 0))<=M.position_epsilon and math.abs((a.y or 0)-(b.y or 0))<=M.position_epsilon end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair,action,detail) local r=root(); stat(action); r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or "")}; while #r.recent>180 do table.remove(r.recent,1) end end

local function fluidbox(entity) if not valid(entity) then return nil end local ok,box=pcall(function() return entity.fluidbox end); return ok and box and box.valid and box or nil end
local function prototype_records(box,index)
  local out={}; if not (box and box.valid and index) then return out end
  local ok,value=pcall(function() return box.get_prototype(index) end); if not ok or value==nil then return out end
  if type(value)=="table" and value.object_name==nil then for _,p in pairs(value) do if p then out[#out+1]=p end end else out[#out+1]=value end
  return out
end
local function filter_name(box,index)
  local filter; pcall(function() filter=box.get_filter(index) end); if type(filter)=="table" and filter.name then return filter.name,"runtime-filter" end
  local locked; pcall(function() locked=box.get_locked_fluid(index) end); if type(locked)=="string" and locked~="" then return locked,"locked-fluid" end
  for _,prototype in ipairs(prototype_records(box,index)) do local fp; pcall(function() fp=prototype.filter end); if fp then local name; pcall(function() name=fp.name end); if type(name)=="string" and name~="" then return name,"prototype-filter" end end end
  return nil,nil
end
local function segment_contents(box,index) local contents={}; if box and box.valid then pcall(function() contents=box.get_fluid_segment_contents(index) or {} end) end; return type(contents)=="table" and contents or {} end
local function local_fluid(box,index) local fluid; if box and box.valid then pcall(function() fluid=box[index] end) end; return type(fluid)=="table" and fluid.name and (tonumber(fluid.amount) or 0)>0 and fluid or nil end
local function pipe_connections(box,index)
  local out={}; if not (box and box.valid and index) then return out end
  local connections={}; pcall(function() connections=box.get_pipe_connections(index) or {} end)
  for _,connection in pairs(connections or {}) do if type(connection)=="table" then local position=connection.target_position or connection.position; local owner; if connection.target then pcall(function() owner=connection.target.owner end) end; out[#out+1]={position=position and {x=position.x,y=position.y} or nil,connected=connection.target~=nil or valid(owner)} end end
  return out
end

local function report_requirement(report,index)
  for _,record_data in ipairs(report and report.records or {}) do
    if tonumber(record_data.index)==tonumber(index) and record_data.requirement and record_data.requirement.name then return record_data.requirement.name,record_data.direction end
  end
  return nil,nil
end

local function known_fluids(entity,index,report)
  local names={}; local sources={}; local box=fluidbox(entity); if not box then return names,sources end
  local requirement,direction=report_requirement(report,index)
  if requirement then names[requirement]=true; sources[#sources+1]="recipe-"..safe(direction) end
  local filter,filter_source=filter_name(box,index)
  if filter then names[filter]=true; sources[#sources+1]=filter_source end
  local contents=segment_contents(box,index)
  for name,amount in pairs(contents) do if (tonumber(amount) or 0)>0.001 then names[name]=true; sources[#sources+1]="segment" end end
  local current=local_fluid(box,index); if current then names[current.name]=true; sources[#sources+1]="local" end
  return names,sources
end

local function identity_compatible(entity,index,intended,report)
  local names,sources=known_fluids(entity,index,report)
  local count=0; local only
  for name in pairs(names) do count=count+1; only=name; if name~=intended then return false,"different-fluid:"..name, sources end end
  if count==0 then return false,"ambiguous-empty-unfiltered",sources end
  return only==intended,"compatible",sources
end

local function connection_targets(entity,index,unconnected_only)
  local out={}; local box=fluidbox(entity); if not box then return out end
  for _,connection in ipairs(pipe_connections(box,index)) do if connection.position and (not unconnected_only or not connection.connected) then out[#out+1]=connection.position end end
  return out
end

local function target_belongs_to_index(entity,index,target)
  for _,position in ipairs(connection_targets(entity,index,false)) do if same_pos(position,target) then return true end end
  return false
end

function M.validate_endpoint(entity,intended_index,target,intended_fluid,report)
  if not (valid(entity) and intended_index and target and intended_fluid) then return false,"invalid-endpoint" end
  local box=fluidbox(entity); if not box then return false,"entity-has-no-fluidbox" end
  if not target_belongs_to_index(entity,intended_index,target) then return false,"target-not-on-intended-fluidbox" end

  local touching=0
  for index=1,#box do
    if target_belongs_to_index(entity,index,target) then
      touching=touching+1
      local compatible,why=identity_compatible(entity,index,intended_fluid,report)
      if not compatible then
        stat(index==intended_index and "intended_port_rejected" or "shared_port_rejected")
        return false,"fluidbox-"..tostring(index)..":"..why
      end
    end
  end
  if touching<=0 then return false,"no-touching-fluidbox" end
  if touching>1 then stat("compatible_shared_ports") end
  stat("validated_endpoints")
  return true,touching>1 and "compatible-shared-port" or "single-port"
end

local function safe_targets(entity,index,targets,fluid,report)
  local out={}; local rejected={}
  for _,target in ipairs(targets or {}) do
    local ok,why=M.validate_endpoint(entity,index,target,fluid,report)
    if ok then out[#out+1]={x=target.x,y=target.y} else rejected[#rejected+1]={x=target.x,y=target.y,reason=why}; stat("proposal_targets_rejected") end
  end
  return out,rejected
end

local function shallow_copy(source)
  local out={}; for key,value in pairs(source or {}) do out[key]=value end; return out
end

local function filter_input_proposals(pair,report)
  local out={}
  for _,proposal in ipairs(pair.fluid_connection_proposals_0689 or {}) do
    if type(proposal)=="table" and proposal.action=="connect-fluid-input" and valid(proposal.machine) and proposal.fluidbox_index then
      local copy=shallow_copy(proposal)
      local machine_targets,rejected=safe_targets(proposal.machine,proposal.fluidbox_index,proposal.connection_targets,proposal.fluid,report)
      copy.connection_targets=machine_targets; copy.port_rejections_0699=rejected
      local source=proposal.source
      local source_safe=true; local source_rejections={}
      if source and valid(source.entity) and source.fluidbox_index then
        local source_targets=connection_targets(source.entity,source.fluidbox_index,true)
        for _,target in ipairs(source_targets) do local ok,why=M.validate_endpoint(source.entity,source.fluidbox_index,target,proposal.fluid,nil); if not ok then source_safe=false; source_rejections[#source_rejections+1]={x=target.x,y=target.y,reason=why} end end
        if #source_targets==0 then source_safe=false; source_rejections[#source_rejections+1]={reason="source-no-free-interface"} end
      else
        source_safe=false; source_rejections[#source_rejections+1]={reason="source-invalid"}
      end
      copy.source_port_safe_0699=source_safe; copy.source_port_rejections_0699=source_rejections
      if #machine_targets>0 and source_safe then out[#out+1]=copy else stat("input_proposals_rejected") end
    else
      out[#out+1]=proposal
    end
  end
  return out
end

local function filter_output_proposals(pair,report)
  local out={}
  for _,proposal in ipairs(pair.fluid_output_sink_proposals_0694 or {}) do
    if type(proposal)=="table" and proposal.action=="connect-fluid-output" and valid(proposal.machine) and proposal.output_fluidbox_index and proposal.sink and valid(proposal.sink.entity) then
      local copy=shallow_copy(proposal)
      local machine_targets,machine_rejected=safe_targets(proposal.machine,proposal.output_fluidbox_index,proposal.connection_targets,proposal.fluid,report)
      copy.connection_targets=machine_targets; copy.machine_port_rejections_0699=machine_rejected
      local sink_copy=shallow_copy(proposal.sink)
      local sink_targets,sink_rejected=safe_targets(proposal.sink.entity,proposal.sink.fluidbox_index,proposal.sink.interfaces,proposal.fluid,nil)
      sink_copy.interfaces=sink_targets; sink_copy.port_rejections_0699=sink_rejected; copy.sink=sink_copy
      if #machine_targets>0 and #sink_targets>0 then out[#out+1]=copy else stat("output_proposals_rejected") end
    else
      out[#out+1]=proposal
    end
  end
  return out
end

local function release_plan(pair,plan,field,reason)
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")
  if not reservations then local ok,module=pcall(require,"scripts.core.work_reservations"); if ok then reservations=module end end
  if reservations and type(reservations.release)=="function" then for _,target in ipairs(plan and plan.reservation_targets or {}) do pcall(reservations.release,"construction",target,pair) end end
  if pair.construction_task_0338 then
    local task=pair.construction_task_0338
    if task.fluid_pipe_plan_id_0691==plan.id or task.fluid_output_pipe_plan_id_0696==plan.id then pair.construction_task_0338=nil end
  end
  for _,request_field in ipairs({"active_supply_request","logistic_requested_item"}) do local request=pair[request_field]; if type(request)=="table" and request.plan_id==plan.id then pair[request_field]=nil end end
  plan.state="aborted"; plan.aborted_tick=now(); plan.result="port-collision:"..safe(reason)
  if field=="fluid_pipe_plan_0691" then pair.fluid_pipe_plan_last_0691=plan; pair.fluid_pipe_reject_until_0692=now()+M.abort_cooldown else pair.fluid_output_pipe_plan_last_0696=plan; pair.fluid_output_pipe_reject_until_0696=now()+M.abort_cooldown end
  pair[field]=nil; stat("active_plans_aborted"); record(pair,"active-plan-port-aborted",safe(field).." "..safe(reason))
end

local function validate_active_input(pair,plan,report)
  if not (plan and valid(plan.machine) and plan.source and valid(plan.source.entity) and plan.route and #plan.route>0) then return false,"invalid-input-plan" end
  local machine_target=plan.route[1]; local intended_index
  for _,record_data in ipairs(report and report.records or {}) do if record_data.direction=="input" and record_data.requirement and record_data.requirement.name==plan.fluid and target_belongs_to_index(plan.machine,record_data.index,machine_target) then intended_index=record_data.index; break end end
  if not intended_index then return false,"input-index-unresolved" end
  local ok,why=M.validate_endpoint(plan.machine,intended_index,machine_target,plan.fluid,report); if not ok then return false,"machine:"..why end
  local source_target=plan.route[#plan.route]
  ok,why=M.validate_endpoint(plan.source.entity,plan.source.fluidbox_index,source_target,plan.fluid,nil); if not ok then return false,"source:"..why end
  return true,"safe"
end

local function validate_active_output(pair,plan,report)
  if not (plan and valid(plan.machine) and plan.sink and valid(plan.sink.entity) and plan.route and #plan.route>0) then return false,"invalid-output-plan" end
  local machine_target=plan.route[1]; local ok,why=M.validate_endpoint(plan.machine,plan.output_fluidbox_index,machine_target,plan.fluid,report); if not ok then return false,"machine:"..why end
  local sink_target=plan.route[#plan.route]
  ok,why=M.validate_endpoint(plan.sink.entity,plan.sink.fluidbox_index,sink_target,plan.fluid,nil); if not ok then return false,"sink:"..why end
  return true,"safe"
end

local function patched_service_pair(pair,reason,...)
  if root().enabled==false or not valid_pair(pair) then return previous_build_service_pair(pair,reason,...) end
  local report=pair.machine_fluid_network_0689
  local input_plan=pair.fluid_pipe_plan_0691
  if input_plan then local ok,why=validate_active_input(pair,input_plan,report); if not ok then release_plan(pair,input_plan,"fluid_pipe_plan_0691",why) end end
  local output_plan=pair.fluid_output_pipe_plan_0696
  if output_plan then local ok,why=validate_active_output(pair,output_plan,report); if not ok then release_plan(pair,output_plan,"fluid_output_pipe_plan_0696",why) end end

  local original_inputs=pair.fluid_connection_proposals_0689
  local original_outputs=pair.fluid_output_sink_proposals_0694
  pair.fluid_connection_proposals_0689=filter_input_proposals(pair,report)
  pair.fluid_output_sink_proposals_0694=filter_output_proposals(pair,report)
  local acted,why=previous_build_service_pair(pair,reason,...)
  pair.fluid_connection_proposals_0689=original_inputs
  pair.fluid_output_sink_proposals_0694=original_outputs
  return acted,why
end

local function patch_build(build)
  if not (build and type(build.service_pair)=="function") or build.fluid_port_collision_validator_0699_active then return false end
  build.fluid_port_collision_validator_0699_active=true; previous_build_service_pair=build.service_pair; build.service_pair=patched_service_pair; return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.fluid_port_collision_validator_0699_wrapped then return false end
  diag.fluid_port_collision_validator_0699_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 FLUID-PORT-COLLISION-0699 enabled="..safe(r.enabled).." validated="..safe(r.stats.validated_endpoints or 0).." compatible_shared="..safe(r.stats.compatible_shared_ports or 0).." target_rejected="..safe(r.stats.proposal_targets_rejected or 0).." input_proposals_rejected="..safe(r.stats.input_proposals_rejected or 0).." output_proposals_rejected="..safe(r.stats.output_proposals_rejected or 0).." active_plans_aborted="..safe(r.stats.active_plans_aborted or 0).." fluid_mutations=0 direct_construction=0"
    for i=math.max(1,#r.recent-10),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 fluid-port.recent["..safe(i).."] tick="..safe(ev.tick).." action="..safe(ev.action).." station="..safe(ev.station).." "..safe(ev.detail) end end
    return lines
  end
  return true
end

function M.activate(build) patch_build(build); patch_diagnostics(); _G.TechPriestsFluidPortCollisionValidator0699=M; return true end
function M.install()
  root(); local ok,build=pcall(require,"scripts.core.construction_planner"); if not (ok and build) then return false end
  if not build.fluid_port_collision_validator_0699_install_wrapped then build.fluid_port_collision_validator_0699_install_wrapped=true; previous_build_install=build.install; build.install=function(...) local result=type(previous_build_install)=="function" and previous_build_install(...) or true; M.activate(build); return result end end
  if rawget(_G,"TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  patch_diagnostics(); _G.TechPriestsFluidPortCollisionValidator0699=M
  if log then log("[Tech-Priests 0.1.670] shared fluid-port collision validator armed; ambiguous shared ports are rejected") end
  return true
end

return M
