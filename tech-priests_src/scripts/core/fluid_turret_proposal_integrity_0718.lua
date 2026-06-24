-- Tech Priests 0.1.674-dev fluid-turret proposal integrity.
-- Resolves the exact turret fluidbox by runtime connection-target geometry,
-- filters endpoints to that box, and proves that turret/source segments contain
-- only the selected accepted attack fluid. Read-only; no reservations or work.

local M = { version = "0.1.674-dev", storage_key = "fluid_turret_proposal_integrity_0718" }

local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function same_pos(a,b) return a and b and math.abs((a.x or 0)-(b.x or 0))<0.15 and math.abs((a.y or 0)-(b.y or 0))<0.15 end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,read_only=true,stats={}}
  storage.tech_priests[M.storage_key]=r; r.version=M.version
  if r.enabled==nil then r.enabled=true end; r.stats=r.stats or {}; return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok,box=pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function segment_contents(box,index)
  local contents={}; if box and box.valid then pcall(function() contents=box.get_fluid_segment_contents(index) or {} end) end
  return type(contents)=="table" and contents or {}
end

local function exclusive_segment(box,index,fluid,allow_empty)
  local contents=segment_contents(box,index); local amount=tonumber(contents[fluid]) or 0
  for name,other in pairs(contents) do if name~=fluid and (tonumber(other) or 0)>0.001 then return false,"wrong-fluid:"..name,amount end end
  if not allow_empty and amount<=0.001 then return false,"selected-fluid-empty",amount end
  return true,"exclusive",amount
end

local function unconnected_targets(box,index)
  local out={}; if not (box and box.valid) then return out end
  local connections={}; pcall(function() connections=box.get_pipe_connections(index) or {} end)
  for _,connection in pairs(connections or {}) do
    if type(connection)=="table" then
      local owner; if connection.target then pcall(function() owner=connection.target.owner end) end
      local position=connection.target_position or connection.position
      if not connection.target and not valid(owner) and position then out[#out+1]={x=position.x,y=position.y} end
    end
  end
  return out
end

local function resolve_box(entity,proposal_targets,fluid,allow_empty)
  local box=fluidbox(entity); if not box then return nil,{},"no-fluidbox" end
  local best_index,best_targets,best_matches
  for index=1,#box do
    local compatible,why=exclusive_segment(box,index,fluid,allow_empty)
    if compatible then
      local targets=unconnected_targets(box,index); local matches=0; local filtered={}
      for _,target in ipairs(targets) do
        for _,wanted in ipairs(proposal_targets or {}) do if same_pos(target,wanted) then matches=matches+1; filtered[#filtered+1]=target; break end end
      end
      if matches>0 and (not best_matches or matches>best_matches) then best_index,best_targets,best_matches=index,filtered,matches end
    elseif not allow_empty then stat("source_segment_rejected") end
  end
  if not best_index then return nil,{},"no-exclusive-matching-port" end
  return best_index,best_targets,"resolved"
end

local function accepted(report,fluid)
  return report and report.accepted_lookup and report.accepted_lookup[fluid]==true
end

local function report_for(pair,turret)
  local doctrine=rawget(_G,"TechPriestsFluidTurretReadiness0716") or package.loaded["scripts.core.fluid_turret_readiness_0716"]
  if doctrine and type(doctrine.inspect_entity)=="function" then return doctrine.inspect_entity(pair,turret,true) end
  return nil
end

function M.refresh_pair(pair)
  if root().enabled==false or not valid_pair(pair) then return 0 end
  local safe_proposals={}
  for _,proposal in ipairs(pair.fluid_turret_connection_proposals_0717 or {}) do
    if proposal.state=="source-network-found" and valid(proposal.turret) and proposal.source and valid(proposal.source.entity) and proposal.fluid then
      local report=report_for(pair,proposal.turret)
      if accepted(report,proposal.fluid) then
        local turret_index,turret_targets=resolve_box(proposal.turret,proposal.connection_targets,proposal.fluid,true)
        local source_index,source_targets=resolve_box(proposal.source.entity,proposal.source.interfaces,proposal.fluid,false)
        if turret_index and source_index and #turret_targets>0 and #source_targets>0 then
          local copy={}; for key,value in pairs(proposal) do copy[key]=value end
          copy.fluidbox_index=turret_index; copy.connection_targets=turret_targets
          copy.source={}; for key,value in pairs(proposal.source) do copy.source[key]=value end
          copy.source.fluidbox_index=source_index; copy.source.interfaces=source_targets
          copy.integrity_0718="safe"; safe_proposals[#safe_proposals+1]=copy; stat("safe_proposals")
        else stat("geometry_rejected") end
      else stat("unaccepted_fluid_rejected") end
    end
  end
  pair.fluid_turret_safe_proposals_0718=safe_proposals
  return #safe_proposals
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.fluid_turret_proposal_integrity_0718_wrapped then return false end
  diag.fluid_turret_proposal_integrity_0718_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 FLUID-TURRET-PROPOSAL-INTEGRITY-0718 enabled="..safe(r.enabled).." read_only=true safe="..safe(r.stats.safe_proposals or 0).." geometry_rejected="..safe(r.stats.geometry_rejected or 0).." fluid_rejected="..safe(r.stats.unaccepted_fluid_rejected or 0)
    return lines
  end
  return true
end

local function register_service()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="fluid_turret_proposal_integrity_0718",category="machine-logistics",interval=233,priority=81,budget=6,note="read-only exact fluid turret and source port identity validation",fn=function(_,budget) local count=0; for _,pair in pairs(pair_map()) do if valid_pair(pair) then M.refresh_pair(pair); count=count+1; if count>=(tonumber(budget) or 6) then break end end end; return count>0,"pairs="..safe(count) end}) end
end

function M.install()
  root(); register_service(); patch_diagnostics(); _G.TechPriestsFluidTurretProposalIntegrity0718=M
  if log then log("[Tech-Priests 0.1.674-dev] exact fluid-turret proposal port integrity armed") end
  return true
end

return M
