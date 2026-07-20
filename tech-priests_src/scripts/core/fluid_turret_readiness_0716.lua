-- Tech Priests 0.1.674-dev fluid-turret readiness doctrine.
-- Canonical read-only inspection of accepted attack fluids, connected pipeline supply,
-- and the separate internal ammunition buffer. Pipeline fluid is subtracted from the
-- entity aggregate before activation-threshold evaluation; no wrapper is required.

local M={version="0.1.674-dev",storage_key="fluid_turret_readiness_0716",scan_interval=60*5,entity_cache_ticks=60*3,service_radius_floor=28,service_radius_cap=96,max_scan_entities=96,minimum_segment_supply=.001,read_only=true,internal_buffer_correction_integrated=true,structured_scan_truth=true}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function entity_key(e)return valid(e)and(e.unit_number and("unit:"..e.unit_number)or safe(e.surface and e.surface.index)..":fluid-turret:"..math.floor(e.position.x*10)..":"..math.floor(e.position.y*10))or nil end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,read_only=true,internal_buffer_correction_integrated=true,structured_scan_truth=true,stats={},scan_due={},entity_due={},reports={}}
 storage.tech_priests[M.storage_key]=r;r.version=M.version;if r.enabled==nil then r.enabled=true end;r.read_only=true;r.internal_buffer_correction_integrated=true;r.structured_scan_truth=true;r.stats=r.stats or{};r.scan_due=r.scan_due or{};r.entity_due=r.entity_due or{};r.reports=r.reports or{};return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function fluidbox(e)local ok,b=pcall(function()return e.fluidbox end);return ok and b and b.valid and b or nil end
local function segment_contents(box,index)local out={};if box and box.valid then pcall(function()out=box.get_fluid_segment_contents(index)or{}end)end;return type(out)=="table"and out or{}end
local function accepted_fluids(e)
 local out,lookup={},{};local attack;pcall(function()attack=e.prototype.attack_parameters end);for _,rec in pairs(attack and attack.fluids or{})do local name,damage;pcall(function()name=rec.type or rec.name or rec.fluid;damage=tonumber(rec.damage_modifier)or 1 end);if type(name)=="string"and name~=""and not lookup[name]then lookup[name]=true;out[#out+1]={name=name,damage_modifier=damage or 1}end end;table.sort(out,function(a,b)return a.name<b.name end);return out,lookup
end
local function connection_records(box,index)
 local out={};local connections={};if box and box.valid then pcall(function()connections=box.get_pipe_connections(index)or{}end)end;for _,c in pairs(connections)do if type(c)=="table"then local owner;if c.target then pcall(function()owner=c.target.owner end)end;local p=c.target_position or c.position;out[#out+1]={connected=c.target~=nil or valid(owner),position=p and{x=p.x,y=p.y}or nil,target_owner=owner}end end;return out
end
local function pipeline_report(e,accepted)
 local box=fluidbox(e);local result={present=box~=nil,connected=false,accepted_amount=0,wrong_fluids={},records={},free_targets={}};if not box then return result end
 for index=1,#box do local segment=segment_contents(box,index);local connections=connection_records(box,index);local connected=false;for _,c in ipairs(connections)do if c.connected then connected=true elseif c.position then result.free_targets[#result.free_targets+1]=c.position end end;if connected then result.connected=true end
  local accepted_amount,wrong=0,{};for name,amount in pairs(segment)do amount=tonumber(amount)or 0;if accepted[name]then accepted_amount=accepted_amount+amount;result.accepted_amount=result.accepted_amount+amount elseif amount>.001 then local rec={name=name,amount=amount,index=index};wrong[#wrong+1]=rec;result.wrong_fluids[#result.wrong_fluids+1]=rec end end
  result.records[#result.records+1]={index=index,connected=connected,connections=connections,segment_contents=segment,accepted_amount=accepted_amount,wrong_fluids=wrong}
 end;return result
end
local function total_contents(e)local out={};if valid(e)and e.get_fluid_contents then pcall(function()out=e.get_fluid_contents()or{}end)end;return type(out)=="table"and out or{}end
local function local_fluidbox_contents(e)
 local out={};local box=fluidbox(e);if not box then return out end;for index=1,#box do local fluid;pcall(function()fluid=box[index]end);if type(fluid)=="table"and fluid.name then out[fluid.name]=(out[fluid.name]or 0)+(tonumber(fluid.amount)or 0)end end;return out
end
local function storage_records(e)local out={};local count=0;pcall(function()count=tonumber(e.fluids_count)or 0 end);for index=1,count do local fluid;pcall(function()fluid=e.get_fluid(index)end);out[#out+1]=type(fluid)=="table"and fluid.name and{index=index,name=fluid.name,amount=tonumber(fluid.amount)or 0,temperature=tonumber(fluid.temperature)}or{index=index,amount=0}end;return out end
local function buffer_report(e,accepted)
 local total=total_contents(e);local local_pipe=local_fluidbox_contents(e);local internal={};for name,amount in pairs(total)do local remaining=math.max(0,(tonumber(amount)or 0)-(tonumber(local_pipe[name])or 0));if remaining>.000001 then internal[name]=remaining end end
 local accepted_amount,wrong=0,{};for name,amount in pairs(internal)do if accepted[name]then accepted_amount=accepted_amount+amount elseif amount>.001 then wrong[#wrong+1]={name=name,amount=amount}end end
 local size,ratio=0,0;pcall(function()size=tonumber(e.prototype.fluid_buffer_size)or 0 end);pcall(function()ratio=tonumber(e.prototype.activation_buffer_ratio)or 0 end);local threshold=math.max(0,size*ratio)
 return{contents=internal,storages=storage_records(e),entity_total_contents=total,local_fluidbox_contents=local_pipe,accepted_amount=accepted_amount,wrong_fluids=wrong,capacity=size,activation_ratio=ratio,activation_threshold=threshold,above_activation_threshold=accepted_amount+.001>=threshold,separation_method="entity-total-minus-local-fluidboxes"}
end
local function runtime_report(e)local status,target,orientation,damage,kills;pcall(function()status=e.status end);pcall(function()target=e.shooting_target end);pcall(function()orientation=e.turret_orientation end);pcall(function()damage=tonumber(e.damage_dealt)or 0 end);pcall(function()kills=tonumber(e.kills)or 0 end);return{status=status,shooting_target=target,shooting=valid(target),turret_orientation=orientation,damage_dealt=damage or 0,kills=kills or 0}end
function M.inspect_entity(pair,e,force)
 if not(valid_pair(pair)and valid(e)and e.type=="fluid-turret")then return nil,"invalid"end;local key=entity_key(e);local r=M.root();if not force and key and(tonumber(r.entity_due[key])or 0)>now()then return r.reports[key],"cached"end;if key then r.entity_due[key]=now()+M.entity_cache_ticks end
 local accepted_list,accepted=accepted_fluids(e);local pipeline=pipeline_report(e,accepted);local buffer=buffer_report(e,accepted);local state,severity
 if #accepted_list==0 then state,severity="accepted-fluid-unknown","blocked" elseif #pipeline.wrong_fluids>0 or #buffer.wrong_fluids>0 then state,severity="wrong-fluid-contamination","blocked" elseif not pipeline.present then state,severity="input-fluidbox-unavailable","blocked" elseif not pipeline.connected then state,severity="input-pipeline-unconnected","blocked" elseif pipeline.accepted_amount<M.minimum_segment_supply and buffer.accepted_amount<=.001 then state,severity="connected-pipeline-empty","waiting" elseif not buffer.above_activation_threshold then state,severity="internal-buffer-filling","waiting" else state,severity="fluid-ammunition-ready","ready"end
 local report={version=M.version,tick=now(),read_only=true,internal_buffer_corrected=true,entity=e,entity_name=e.name,entity_unit=e.unit_number,station_unit=station_unit(pair),state=state,severity=severity,accepted_fluids=accepted_list,accepted_lookup=accepted,pipeline=pipeline,buffer=buffer,runtime=runtime_report(e),connection_required=state=="input-pipeline-unconnected"};if key then r.reports[key]=report end;stat("entities-inspected");stat("state-"..state);return report,"inspected"
end
local function service_radius(pair)local radius=tonumber(pair and pair.radius)or M.service_radius_floor;if valid_pair(pair)and type(_G.get_station_operating_radius)=="function"then local ok,v=pcall(_G.get_station_operating_radius,pair.station);if ok and tonumber(v)then radius=tonumber(v)end end;return math.max(8,math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))end
local function routed_find(surface,filters,category,key,ttl)local scanner=rawget(_G,"TechPriestsScanRouting0610")or package.loaded["scripts.core.scan_routing_0610"];if scanner and type(scanner.find_entities)=="function"then local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=key,negative_ttl=ttl or 60*4}));return entities or{}end;local ok,entities=pcall(function()return surface.find_entities_filtered(filters)end);return ok and entities or{}end
function M.scan_pair(pair,force)
 if M.root().enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;local key=tostring(station_unit(pair)or"?");local r=M.root();if not force and(tonumber(r.scan_due[key])or 0)>now()then return{processed=0,acted=0,detail="cached"}end;r.scan_due[key]=now()+M.scan_interval
 local radius=service_radius(pair);local p=pair.station.position;local entities=routed_find(pair.station.surface,{area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=pair.station.force,type="fluid-turret",limit=M.max_scan_entities},"fluid-turret-readiness","fluid-turret-readiness:"..safe(pair.station.surface.index)..":"..safe(pair.station.force.index)..":"..key,60*4)
 local reports,ready,connection_required,blocked={},0,0,0;for _,e in pairs(entities)do local report=M.inspect_entity(pair,e,false);if report then reports[#reports+1]=report;if report.state=="fluid-ammunition-ready"then ready=ready+1 end;if report.connection_required then connection_required=connection_required+1 end;if report.severity=="blocked"then blocked=blocked+1 end end end
 pair.fluid_turret_reports_0716=reports;pair.fluid_turret_summary_0716={version=M.version,tick=now(),inspected=#reports,ready=ready,connection_required=connection_required,blocked=blocked,read_only=true};stat("pair-scans");return{processed=1,acted=0,blocked=blocked,waiting=connection_required,detail="inspected="..#reports.." ready="..ready}
end
local function patch_diagnostics()
 local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(d and type(d.pair_dump_lines)=="function")or d.fluid_turret_readiness_0716_wrapped then return false end;d.fluid_turret_readiness_0716_wrapped=true;local previous=d.pair_dump_lines;d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=M.root();lines[#lines+1]="PAIR-DUMP-0468 FLUID-TURRET-READINESS-0716 enabled="..safe(r.enabled).." read_only=true buffer_method=entity-total-minus-local-fluidboxes inspected="..safe(r.stats["entities-inspected"]or 0);return lines end;return true
end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
local function register_service()
 local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="fluid_turret_readiness_0716",category="readiness",interval=227,priority=79,budget=6,note="read-only corrected fluid turret pipeline and internal buffer readiness",fn=function(_,budget)local processed,blocked,waiting,failed=0,0,0,0;for _,pair in pairs(pair_map())do if processed>=math.max(1,tonumber(budget)or 6)then break end;local ok,out=pcall(M.scan_pair,pair,false);processed=processed+1;if ok and type(out)=="table"then blocked=blocked+(tonumber(out.blocked)or 0);waiting=waiting+(tonumber(out.waiting)or 0)else failed=failed+1 end end;return{processed=processed,acted=0,blocked=blocked,waiting=waiting,failed=failed,detail="pairs="..processed}end});return service~=nil
end
function M.install()M.root();_G.TechPriestsFluidTurretReadiness0716=M;_G.tech_priests_fluid_turret_inspect_0716=M.inspect_entity;if not register_service()then return false end;patch_diagnostics();if log then log("[Tech-Priests recovery] corrected read-only fluid turret readiness armed")end;return true end
return M
