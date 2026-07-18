-- scripts/core/emergency_production_executor_0514.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Dispatcher-owned production with strict recipes, transactional ingredients,
-- persistent output/rollback custody, atomic deposits, and truthful handoff.

local M = { version = "0.1.674-dev", storage_key = "emergency_production_executor_0514",
  station_close_distance_sq = 5.76, move_refresh_ticks = 45,
  default_station_craft_ticks = 240, facility_wait_ticks = 480,
  max_pairs_per_pulse = 24 }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok,s=pcall(tostring,v); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pairs_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(p) return p and valid(p.station) and valid(p.priest) end
local function station_unit(p) return p and (p.station_unit or (valid(p.station) and p.station.unit_number)) end
local function dist2(a,b) if not(a and b)then return 1e12 end local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function at_station(p) return valid_pair(p) and dist2(p.priest.position,p.station.position)<=M.station_close_distance_sq end
local function item_exists(n) return type(n)=="string" and n~="" and (not(prototypes and prototypes.item) or prototypes.item[n]~=nil) end

function M.root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {enabled=true,suppress_independent_facility_pulses=true,
    block_legacy_desperation_craft=true,prefer_emergency_facilities=true,
    allow_timed_station_fallback=true,require_strict_fallback_recipe=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=r; r.version=M.version; r.stats=r.stats or {}; r.recent=r.recent or {}
  for _,k in ipairs{"enabled","suppress_independent_facility_pulses","block_legacy_desperation_craft","prefer_emergency_facilities","allow_timed_station_fallback","require_strict_fallback_recipe"} do if r[k]==nil then r[k]=true end end
  return r
end
local function stat(k,n) local r=M.root();r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(k,p,d) local r=M.root();stat(k);r.recent[#r.recent+1]={tick=now(),action=k,station=safe(station_unit(p)),detail=safe(d)};while #r.recent>120 do table.remove(r.recent,1) end end
local function phase(p,k,d) p.dispatcher_action="emergency-production";p.dispatcher_phase=k;p.dispatcher_emergency_production_0514=p.dispatcher_emergency_production_0514 or {};local s=p.dispatcher_emergency_production_0514;s.version=M.version;s.phase=k;s.tick=now();s.detail=safe(d) end
local function draw(p,t) if _G.tech_priests_emit_overhead_status_0473 then pcall(_G.tech_priests_emit_overhead_status_0473,p,t,{r=1,g=.74,b=.2,a=.98},60,.64,"emergency-production-0514") end end

local function inv(entity,id) if not(valid(entity) and entity.get_inventory and id)then return nil end local ok,v=pcall(function()return entity.get_inventory(id)end);return ok and v and v.valid and v or nil end
local function count(i,n) if not(i and i.valid and n)then return 0 end local ok,v=pcall(function()return i.get_item_count(n)end);return ok and tonumber(v) or 0 end
local function remove(i,n,c) c=math.max(0,math.floor(tonumber(c)or 0));if not(i and i.valid and n and c>0)then return 0 end local ok,v=pcall(function()return i.remove{name=n,count=c}end);return ok and tonumber(v) or 0 end
local function insert(i,n,c) c=math.max(0,math.floor(tonumber(c)or 0));if not(i and i.valid and n and c>0)then return 0 end local ok,v=pcall(function()return i.insert{name=n,count=c}end);return ok and tonumber(v) or 0 end

local function sources(p)
  local out,seen={},{}
  local function add(i,e,l) if not(i and i.valid)then return end local k=safe(i);if seen[k]then return end;seen[k]=true;out[#out+1]={inv=i,entity=e,label=l} end
  if type(_G.tech_priests_inventory_steward_sources_for_pair)=="function" then local ok,a=pcall(_G.tech_priests_inventory_steward_sources_for_pair,p);if ok and type(a)=="table" then for _,s in ipairs(a)do if s and s.valid then add(s,p.station,"steward")elseif type(s)=="table"then add(s.inv or s.inventory,s.entity,s.source or s.inventory_id)end end end end
  local d=defines and defines.inventory;if d then add(inv(p.station,d.chest),p.station,"station") end
  return out
end
local function total(p,n) local x=0;for _,s in ipairs(sources(p))do x=x+count(s.inv,n)end;return x end
local function deposit(p,n,c,why) if type(_G.tech_priests_safe_deposit_item)~="function"then return false,"atomic-storage-unavailable" end local ok,a,b,x=pcall(_G.tech_priests_safe_deposit_item,p,n,c,why);x=tonumber(x)or(a==true and c or 0);return ok and a==true and x==c,b or "deposit-blocked" end

local function task_item(t) if type(t)=="string"then return t end;if type(t)~="table"then return nil end;return t.output_item or t.item_name or t.item or t.wanted_item or t.requested_item end
local function current_task(p)
  if p.emergency_craft then return p.emergency_craft,"emergency_craft" end
  if p.station_crafting_task_0337 then return p.station_crafting_task_0337,"station_crafting_task_0337" end
  if p.active_craft_0479 then return p.active_craft_0479,"active_craft_0479" end
  local q=p.order_queue_0469;local o=q and q.current
  if o and o.item and (o.kind=="emergency_craft" or lower(o.kind):find("craft",1,true)) then local ot=o.task or{};return {output_item=o.item,count=o.count or 1,order_proxy_0514=true,strict_recipe_0647=o.strict_recipe_0647 or ot.strict_recipe_0647,strict_recipe_ingredients_0647=o.strict_recipe_ingredients_0647 or ot.strict_recipe_ingredients_0647},"order_proxy" end
end
local function clear_task(p,s) if s=="emergency_craft"then p.emergency_craft=nil elseif s=="station_crafting_task_0337"then p.station_crafting_task_0337=nil elseif s=="active_craft_0479"then p.active_craft_0479=nil end end
local function finish_order(p,n,why)
  local api=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469");if api and type(api.complete_current)=="function"then local ok,done=pcall(api.complete_current,p,why,n);if ok and done==true then return end end
  local q=p.order_queue_0469;local o=q and q.current;if o and (not n or not o.item or o.item==n)then o.status="complete";o.finished_tick=now();o.finish_reason=why;q.current=nil;p.active_order_0469=nil end
end
local function finalize(p,t,s,n,why) clear_task(p,s);finish_order(p,n,why);p.emergency_production_custody_0514=nil;phase(p,"complete",why);record("transaction-complete-0514",p,n);return true,"complete" end

local function ingredients(t)
  local a=t and t.strict_recipe_ingredients_0647;if type(a)~="table" or #a==0 then return nil end
  local out={};for _,v in ipairs(a)do local n=v and v.name;local c=math.max(1,math.floor(tonumber(v and v.count)or 1));if not item_exists(n)then return nil end;out[#out+1]={name=n,count=c} end;return out
end
local function plan_remove(p,list)
  local plan={};for _,need in ipairs(list)do local left=need.count;for _,s in ipairs(sources(p))do local take=math.min(left,count(s.inv,need.name));if take>0 then plan[#plan+1]={inv=s.inv,name=need.name,count=take};left=left-take end;if left<=0 then break end end;if left>0 then return nil,"missing-"..need.name end end;return plan
end
local function rollback(entries)
  local short={};for i=#entries,1,-1 do local e=entries[i];local x=insert(e.inv,e.name,e.removed);if x<e.removed then short[e.name]=(short[e.name]or 0)+(e.removed-x) end end;return short
end
local function consume_transaction(p,t,n,c)
  local list=ingredients(t);if not list then return false,"strict-recipe-required" end
  local plan,why=plan_remove(p,list);if not plan then return false,why end
  local done={};for _,e in ipairs(plan)do local x=remove(e.inv,e.name,e.count);done[#done+1]={inv=e.inv,name=e.name,removed=x};if x~=e.count then local short=rollback(done);if next(short)then p.emergency_production_custody_0514={version=M.version,phase="return-ingredients",items=short,item=n,reason="partial-removal"};record("ingredient-rollback-custody-0514",p,n)end;return false,"ingredient-removal-failed" end end
  p.emergency_production_custody_0514={version=M.version,phase="output-held",item=n,output_count=c,ingredients=list,created_tick=now()};stat("strict_transactions_started");return true
end
local function service_custody(p,t,s)
  local c=p.emergency_production_custody_0514;if not c then return false,"no-custody" end
  if c.phase=="return-ingredients" then for n,x in pairs(c.items or {})do if x>0 then local ok=deposit(p,n,x,"emergency-ingredient-rollback");if ok then c.items[n]=nil else phase(p,"return-ingredients","blocked "..n);return true,"rollback-blocked" end end end;p.emergency_production_custody_0514=nil;phase(p,"check-scavenge","ingredients restored");return false,"ingredients-restored" end
  if c.phase=="output-held" then local ok,why=deposit(p,c.item,c.output_count,"emergency-production-output");if not ok then phase(p,"deposit-output",why);record("output-custody-blocked-0514",p,c.item);return true,"deposit-blocked" end;return finalize(p,t,s,c.item,"fallback-station-craft-0514") end
  p.emergency_production_custody_0514=nil;return false,"invalid-custody"
end

local function move_station(p)
  if at_station(p)then return true end
  if type(_G.tech_priests_request_movement_0418)~="function"then phase(p,"movement-request-failed","movement authority unavailable");return false end
  local ok,a=pcall(_G.tech_priests_request_movement_0418,p,p.station.position,"emergency-production-0514",{radius=1.15,owner="emergency-production-0514",priority=620,ttl=600,distraction=defines.distraction.none})
  if not(ok and a==true)then phase(p,"movement-request-failed",a);return false end;p.target=p.station;p.mode="returning-to-station-for-production";return true
end
local function fallback_ticks(t) return math.max(M.default_station_craft_ticks,(tonumber(_G.EMERGENCY_CRAFT_WORK_TICKS)or M.default_station_craft_ticks)*math.max(1,tonumber(t and t.required_count)or 1)) end
local function timed_fallback(p,t,s,n)
  local r=M.root();if r.allow_timed_station_fallback==false then return false,"fallback-disabled" end
  if r.require_strict_fallback_recipe and not ingredients(t)then phase(p,"check-scavenge","strict-recipe-required");return false,"strict-recipe-required" end
  if not at_station(p)then phase(p,"return-to-station",n);return move_station(p),"returning" end
  t.station_craft_pending_0514=true;t.craft_started_tick_0514=t.craft_started_tick_0514 or now();t.craft_due_tick_0514=t.craft_due_tick_0514 or(now()+fallback_ticks(t));p.mode="emergency-production-station-craft"
  if now()<t.craft_due_tick_0514 then phase(p,"fallback-station-craft",n);return true,"crafting" end
  local ok,why=consume_transaction(p,t,n,math.max(1,math.floor(tonumber(t.count or t.required_count)or 1)));if not ok then t.craft_due_tick_0514=nil;t.craft_started_tick_0514=nil;t.station_craft_pending_0514=nil;phase(p,"check-scavenge",why);return false,why end
  return service_custody(p,t,s)
end

local function facility_root() return storage and storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343 end
local function facilities(p) local r=facility_root();local b=r and r.by_station and r.by_station[station_unit(p)];local out={};for k in pairs(b or {})do local x=r.facilities and r.facilities[k];if x and valid(x.entity)then out[#out+1]=x end end;return out end
local function collect_facility_output(p,n,c)
  local d=defines and defines.inventory;if not d then return 0 end
  local ids={d.chest,d.assembling_machine_output,d.furnace_result};local moved=0
  for _,rec in ipairs(facilities(p))do for _,id in ipairs(ids)do local i=inv(rec.entity,id);local take=math.min(c-moved,count(i,n));if take>0 then local x=remove(i,n,take);if x>0 then local ok=deposit(p,n,x,"emergency-facility-output");if ok then moved=moved+x else local back=insert(i,n,x);if back<x then p.emergency_production_custody_0514={version=M.version,phase="output-held",item=n,output_count=x-back,reason="facility-return-shortfall"} end;return moved end end end;if moved>=c then return moved end end end
  return moved
end
local function role_for(n) if n=="iron-plate" or n=="copper-plate" or n=="stone-brick"then return "smelter" end;return "assembler" end
local function has_role(p,r) for _,x in ipairs(facilities(p))do if x.role==r then return true end end;return false end
local function call_facility(p,n)
  local r=M.root();if r.prefer_emergency_facilities==false then return false,"disabled" end
  local ok,F=pcall(require,"scripts.core.emergency_facility_doctrine");if not(ok and F and type(F.service_pair)=="function")then return false,"unavailable" end
  r.dispatching_facility_0514=true;local ok2,a,w=pcall(F.service_pair,p,"dispatcher-0514");r.dispatching_facility_0514=false;if not ok2 then record("facility-error-0514",p,a);return false,"error" end;return a==true,w
end

function M.service_pair(p,reason)
  local r=M.root();if r.enabled==false then return false,"disabled" end;if not valid_pair(p)then return false,"invalid-pair" end
  local t,s=current_task(p);if p.emergency_production_custody_0514 then return service_custody(p,t,s) end;if not t then phase(p,"none","no-production-task");return false,"no-production-task" end
  local n=task_item(t);if not item_exists(n)then phase(p,"need-item",n);return false,"invalid-item" end
  local need=math.max(1,math.floor(tonumber(t.count or t.required_count)or 1));if total(p,n)>=need then return finalize(p,t,s,n,"already-supplied-0514") end
  local got=collect_facility_output(p,n,need);if got>0 and total(p,n)>=need then return finalize(p,t,s,n,"facility-output-collected-0514") end
  local role=role_for(n);local acted,why=call_facility(p,n);if acted then t.facility_started_tick_0514=t.facility_started_tick_0514 or now();phase(p,has_role(p,role)and"feed-machine"or"need-machine",why);return true,why end
  if has_role(p,role) and t.facility_started_tick_0514 and now()-t.facility_started_tick_0514<M.facility_wait_ticks then phase(p,"wait-machine",role);return true,"waiting-machine" end
  if t.facility_only_0647 then phase(p,"need-machine",n);return false,"facility-required" end
  return timed_fallback(p,t,s,n)
end

function M.service_all(reason,budget) local a,x=0,0;local lim=math.max(1,math.floor(tonumber(budget)or M.max_pairs_per_pulse));for _,p in pairs(pairs_map())do if x>=lim then break end;if valid_pair(p)and(current_task(p)or p.emergency_production_custody_0514)then x=x+1;local ok,d=pcall(M.service_pair,p,reason or"service-all");if ok and d==true then a=a+1 elseif not ok then record("service-error-0514",p,d)end end end;return a end

local function block_legacy(p) local r=M.root();return r.enabled~=false and r.block_legacy_desperation_craft~=false and valid_pair(p)and(current_task(p)~=nil or p.emergency_production_custody_0514~=nil) end
local function wrap_legacy(name,marker) local old=rawget(_G,name);if type(old)~="function"or rawget(_G,marker)then return end;_G[marker]=old;_G[name]=function(p,...)if block_legacy(p)then local ok,a=pcall(M.service_pair,p,"legacy-wrapper-0514");return ok and a==true end;return old(p,...)end end
local function wrap_facility()
  local ok,F=pcall(require,"scripts.core.emergency_facility_doctrine");if not(ok and F)or F.emergency_production_0514_wrapped then return end;F.emergency_production_0514_wrapped=true
  for _,name in ipairs{"service_pair","service_all"}do local old=F[name];if type(old)=="function"then F[name]=function(first,...)local r=M.root();local text=tostring(name=="service_pair" and select(1,...)or first or"");if r.enabled~=false and r.suppress_independent_facility_pulses~=false and not r.dispatching_facility_0514 and not text:find("dispatcher%-0514")and not text:find("manual")then return name=="service_all"and 0 or false,"suppressed-by-0514" end;return old(first,...)end end end
end

function M.install()
  M.root();wrap_facility();wrap_legacy("handle_emergency_desperation_craft","TECH_PRIESTS_0514_PRE_HANDLE_EMERGENCY_CRAFT");wrap_legacy("finish_emergency_desperation_craft","TECH_PRIESTS_0514_PRE_FINISH_EMERGENCY_CRAFT")
  if commands and commands.remove_command then pcall(commands.remove_command,"tp-emergency-production-0514") end
  _G.TechPriestsEmergencyProductionExecutor0514=M
  if log then log("[Tech-Priests 0.1.674-dev] emergency production recovery armed") end
  return true
end
return M
