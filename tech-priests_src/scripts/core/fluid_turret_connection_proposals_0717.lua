-- Tech Priests 0.1.674-dev read-only fluid-turret connection proposals.
-- Canonical source selection and exact endpoint validation. It chooses one accepted
-- attack fluid, one supplied same-force source segment, and exact free interfaces.
-- It never reserves tiles, moves priests, places pipes, or mutates fluids.

local M={version="0.1.674-dev",storage_key="fluid_turret_connection_proposals_0717",proposal_ttl=60*20,service_radius_floor=28,service_radius_cap=96,max_scan_sources=192,read_only=true,proposal_integrity_integrated=true,structured_scan_truth=true}
local FLUID_ENTITY_TYPES={"pipe","pipe-to-ground","pump","storage-tank","offshore-pump","assembling-machine","furnace","mining-drill","boiler","generator","reactor","fluid-turret","rocket-silo"}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return math.huge end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function same_pos(a,b)return a and b and math.abs((a.x or 0)-(b.x or 0))<.15 and math.abs((a.y or 0)-(b.y or 0))<.15 end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,read_only=true,proposal_integrity_integrated=true,structured_scan_truth=true,stats={},recent={},proposals={}}
 storage.tech_priests[M.storage_key]=r;r.version=M.version;if r.enabled==nil then r.enabled=true end;r.read_only=true;r.proposal_integrity_integrated=true;r.structured_scan_truth=true;r.stats=r.stats or{};r.recent=r.recent or{};r.proposals=r.proposals or{};return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(pair,action,detail)local r=M.root();r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or"")};while #r.recent>140 do table.remove(r.recent,1)end;stat(action)end
local function readiness()return rawget(_G,"TechPriestsFluidTurretReadiness0716")or package.loaded["scripts.core.fluid_turret_readiness_0716"]end
local function fluidbox(e)local ok,b=pcall(function()return e.fluidbox end);return ok and b and b.valid and b or nil end
local function segment_contents(box,index)local out={};if box and box.valid then pcall(function()out=box.get_fluid_segment_contents(index)or{}end)end;return type(out)=="table"and out or{}end
local function segment_capacity(box,index)local v=0;if box and box.valid then pcall(function()v=tonumber(box.get_capacity(index))or 0 end)end;return v end
local function segment_id(box,index)local v;if box and box.valid then pcall(function()v=box.get_fluid_segment_id(index)end)end;return v end
local function exclusive_segment(box,index,fluid,allow_empty)
 local contents=segment_contents(box,index);local amount=tonumber(contents[fluid])or 0;for name,other in pairs(contents)do if name~=fluid and(tonumber(other)or 0)>.001 then return false,"wrong-fluid:"..name,amount end end;if not allow_empty and amount<=.001 then return false,"selected-fluid-empty",amount end;return true,"exclusive",amount
end
local function free_interfaces(box,index)
 local out={};local connections={};if box and box.valid then pcall(function()connections=box.get_pipe_connections(index)or{}end)end;for _,c in pairs(connections)do if type(c)=="table"then local owner;if c.target then pcall(function()owner=c.target.owner end)end;local p=c.target_position or c.position;if c.target==nil and not valid(owner)and p then out[#out+1]={x=p.x,y=p.y}end end end;return out
end
local function segment_candidates(e,fluid)
 local out={};local box=fluidbox(e);if not box then return out end;for index=1,#box do local compatible,_,amount=exclusive_segment(box,index,fluid,false);if compatible then local interfaces=free_interfaces(box,index);if #interfaces>0 then out[#out+1]={entity=e,entity_name=e.name,entity_unit=e.unit_number,position={x=e.position.x,y=e.position.y},fluidbox_index=index,segment_id=segment_id(box,index),amount=amount,capacity=segment_capacity(box,index),interfaces=interfaces}end end end;return out
end
local function service_radius(pair)local radius=tonumber(pair and pair.radius)or M.service_radius_floor;if valid_pair(pair)and type(_G.get_station_operating_radius)=="function"then local ok,v=pcall(_G.get_station_operating_radius,pair.station);if ok and tonumber(v)then radius=tonumber(v)end end;return math.max(8,math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))end
local function routed_find(surface,filters,category,key,ttl)local scanner=rawget(_G,"TechPriestsScanRouting0610")or package.loaded["scripts.core.scan_routing_0610"];if scanner and type(scanner.find_entities)=="function"then local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=key,negative_ttl=ttl or 60*5}));return entities or{}end;local ok,entities=pcall(surface.find_entities_filtered,surface,filters);return ok and entities or{}end
local function find_source(pair,turret,fluid,targets)
 local radius=service_radius(pair);local p=pair.station.position;local entities=routed_find(turret.surface,{area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=turret.force,type=FLUID_ENTITY_TYPES,limit=M.max_scan_sources},"fluid-turret-source","fluid-turret-source:"..safe(turret.surface.index)..":"..safe(turret.force.index)..":"..fluid,60*5)
 local best;for _,e in pairs(entities)do if valid(e)and e~=turret then for _,segment in ipairs(segment_candidates(e,fluid))do local nearest=dist_sq(e.position,turret.position);for _,target in ipairs(targets or{})do nearest=math.min(nearest,dist_sq(e.position,target))end;local score=nearest-math.min(segment.amount,100000)*.001;if not best or score<best.selection_score then segment.distance_sq=nearest;segment.selection_score=score;best=segment end end end end;return best
end
local function preferred_fluids(report)
 local out,seen,damage={}, {}, {};for _,a in ipairs(report.accepted_fluids or{})do damage[a.name]=tonumber(a.damage_modifier)or 1 end
 local function add(name,reason)if type(name)=="string"and not seen[name]and report.accepted_lookup and report.accepted_lookup[name]then seen[name]=true;out[#out+1]={name=name,reason=reason,damage_modifier=damage[name]or 1}end end
 local present={};for name,amount in pairs(report.buffer and report.buffer.contents or{})do if report.accepted_lookup and report.accepted_lookup[name]and(tonumber(amount)or 0)>.001 then present[#present+1]=name end end;for _,rec in ipairs(report.pipeline and report.pipeline.records or{})do for name,amount in pairs(rec.segment_contents or{})do if report.accepted_lookup and report.accepted_lookup[name]and(tonumber(amount)or 0)>.001 then present[#present+1]=name end end end;table.sort(present);for _,name in ipairs(present)do add(name,"existing-turret-fluid")end
 local remaining={};for _,a in ipairs(report.accepted_fluids or{})do if a.name and not seen[a.name]then remaining[#remaining+1]={name=a.name,damage_modifier=tonumber(a.damage_modifier)or 1}end end;table.sort(remaining,function(a,b)return a.damage_modifier==b.damage_modifier and a.name<b.name or a.damage_modifier>b.damage_modifier end);for _,a in ipairs(remaining)do add(a.name,"highest-damage-compatible")end;return out
end
local function resolve_box(e,proposal_targets,fluid,allow_empty)
 local box=fluidbox(e);if not box then return nil,{},"no-fluidbox"end;local best_index,best_targets,best_matches
 for index=1,#box do local compatible=exclusive_segment(box,index,fluid,allow_empty);if compatible then local targets=free_interfaces(box,index);local matches,filtered=0,{};for _,target in ipairs(targets)do for _,wanted in ipairs(proposal_targets or{})do if same_pos(target,wanted)then matches=matches+1;filtered[#filtered+1]=target;break end end end;if matches>0 and(not best_matches or matches>best_matches)then best_index,best_targets,best_matches=index,filtered,matches end end end
 if not best_index then return nil,{},"no-exclusive-matching-port"end;return best_index,best_targets,"resolved"
end
local function endpoint_identity_safe(pair,p)
 if not(valid_pair(pair)and p and valid(p.turret)and p.source and valid(p.source.entity))then return false,"endpoint-invalid"end;if p.turret.surface~=pair.station.surface or p.source.entity.surface~=pair.station.surface then return false,"surface-mismatch"end;if p.turret.force~=pair.station.force or p.source.entity.force~=pair.station.force then return false,"force-mismatch"end;if p.turret_unit and p.turret.unit_number~=p.turret_unit then return false,"turret-unit-mismatch"end;if p.source.entity_unit and p.source.entity.unit_number~=p.source.entity_unit then return false,"source-unit-mismatch"end;if(tonumber(p.expires_tick)or 0)<now()then return false,"proposal-expired"end;return true,"identity-safe"
end
local function validate_proposal(pair,p,report)
 local ok,why=endpoint_identity_safe(pair,p);if not ok then return nil,why end;if not(report and report.accepted_lookup and report.accepted_lookup[p.fluid])then return nil,"fluid-no-longer-accepted"end
 local turret_index,turret_targets=resolve_box(p.turret,p.connection_targets,p.fluid,true);local source_index,source_targets=resolve_box(p.source.entity,p.source.interfaces,p.fluid,false);if not(turret_index and source_index and#turret_targets>0 and#source_targets>0)then return nil,"geometry-or-fluid-rejected"end
 local copy={};for k,v in pairs(p)do copy[k]=v end;copy.fluidbox_index=turret_index;copy.connection_targets=turret_targets;copy.source={};for k,v in pairs(p.source)do copy.source[k]=v end;copy.source.fluidbox_index=source_index;copy.source.interfaces=source_targets;copy.integrity_0718="safe";copy.integrity_tick_0718=now();copy.proposal_integrity="safe";return copy,"safe"
end
local function build_for_report(pair,report)
 if not(valid_pair(pair)and report and valid(report.entity)and report.state=="input-pipeline-unconnected")then return nil,nil end;local targets=report.pipeline and report.pipeline.free_targets or{};if #targets==0 then return nil,nil end
 for rank,pref in ipairs(preferred_fluids(report))do local source=find_source(pair,report.entity,pref.name,targets);if source then local raw={version=M.version,tick=now(),expires_tick=now()+M.proposal_ttl,read_only=true,action="connect-fluid-turret-input",turret=report.entity,turret_name=report.entity_name,turret_unit=report.entity_unit,fluid=pref.name,fluid_damage_modifier=pref.damage_modifier,fluid_preference_reason=pref.reason,fluid_preference_rank=rank,connection_targets=targets,source=source,state="source-network-found"};local safe_proposal=validate_proposal(pair,raw,report);if safe_proposal then stat("preference-"..pref.reason);return raw,safe_proposal end end end
 return{version=M.version,tick=now(),expires_tick=now()+M.proposal_ttl,read_only=true,action="connect-fluid-turret-input",turret=report.entity,turret_name=report.entity_name,turret_unit=report.entity_unit,connection_targets=targets,state="no-source-network-found"},nil
end
function M.refresh_pair(pair,force)
 if M.root().enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;local doctrine=readiness();if doctrine and type(doctrine.scan_pair)=="function"then pcall(doctrine.scan_pair,pair,force==true)end
 local raw,safe_proposals={},{};for _,report in ipairs(pair.fluid_turret_reports_0716 or{})do local proposal,safe_proposal=build_for_report(pair,report);if proposal then raw[#raw+1]=proposal end;if safe_proposal then safe_proposals[#safe_proposals+1]=safe_proposal end end
 pair.fluid_turret_connection_proposals_0717=raw;pair.fluid_turret_safe_proposals_0718=safe_proposals;M.root().proposals[tostring(station_unit(pair)or"?")]=safe_proposals;stat("pair-refreshes");stat("proposals-created",#raw);stat("safe-proposals",#safe_proposals);record(pair,"proposal-refresh","raw="..#raw.." safe="..#safe_proposals);return{processed=1,acted=0,waiting=#raw-#safe_proposals,blocked=0,detail="safe="..#safe_proposals}
end
local function patch_diagnostics()
 local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(d and type(d.pair_dump_lines)=="function")or d.fluid_turret_connection_proposals_0717_wrapped then return false end;d.fluid_turret_connection_proposals_0717_wrapped=true;local previous=d.pair_dump_lines;d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=M.root();lines[#lines+1]="PAIR-DUMP-0468 FLUID-TURRET-PROPOSALS-0717 enabled="..safe(r.enabled).." read_only=true integrity_integrated=true proposals="..safe(r.stats["proposals-created"]or 0).." safe="..safe(r.stats["safe-proposals"]or 0);return lines end;return true
end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
local function register_service()
 local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="fluid_turret_connection_proposals_0717",category="planning",interval=229,priority=80,budget=6,note="read-only accepted-fluid source and exact port proposal discovery",fn=function(_,budget)local processed,waiting,failed=0,0,0;for _,pair in pairs(pair_map())do if processed>=math.max(1,tonumber(budget)or 6)then break end;local ok,out=pcall(M.refresh_pair,pair,false);processed=processed+1;if ok and type(out)=="table"then waiting=waiting+(tonumber(out.waiting)or 0)else failed=failed+1 end end;return{processed=processed,acted=0,waiting=waiting,failed=failed,detail="pairs="..processed}end});return service~=nil
end
function M.install()M.root();_G.TechPriestsFluidTurretConnectionProposals0717=M;if not register_service()then return false end;patch_diagnostics();if log then log("[Tech-Priests recovery] safe read-only fluid turret proposals armed; 0718 integrity integrated")end;return true end
return M
