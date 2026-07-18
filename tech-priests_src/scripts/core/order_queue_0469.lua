-- scripts/core/order_queue_0469.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Truthful per-pair intent queue: target-aware keys, complete duplicate refresh,
-- lossless preemption, explicit terminal states, immediate promotion, fair budget.

local M={version="0.1.674-dev",storage_key="order_queue_0469",queue_limit=8,
  default_timeout_ticks=7200,lease_ticks=360,tick_interval=17,max_history=200}
local original_assign,original_cancel,original_acquire,original_supply,original_scan
local Doctrine,original_direct,original_no_source

local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)local ok,s=pcall(tostring,v);return ok and s or"?"end
local function lower(v)return string.lower(tostring(v or""))end
local function map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))end
local function surface(p)return valid_pair(p)and safe(p.station.surface.name)or"unknown"end
local function target_key(t)if valid(t)then return safe(t.name).."#"..safe(t.unit_number or 0)end;if type(t)=="table"and t.x and t.y then return string.format("pos:%.2f,%.2f",t.x,t.y)end;return nil end
local priorities={validate=1000,combat=900,defense=900,repair=800,consecration=700,sanctify=700,assignment=610,logistics=600,supply=590,scavenge=580,acquisition=570,gather=570,direct_mine=570,emergency_craft=540,emergency=530,return_to_station=400,idle=0}
local function kind(v)local k=lower(v);if k==""then return"idle"elseif k:find("combat",1,true)or k:find("defend",1,true)then return"combat"elseif k:find("repair",1,true)then return"repair"elseif k:find("consecr",1,true)or k:find("sanct",1,true)then return"consecration"elseif k:find("assign",1,true)then return"assignment"elseif k:find("logistic",1,true)or k:find("supply",1,true)then return"logistics"elseif k:find("scavenge",1,true)then return"scavenge"elseif k:find("mine",1,true)or k:find("acqui",1,true)or k:find("gather",1,true)or k:find("resource",1,true)then return"acquisition"elseif k:find("emergency",1,true)or k:find("craft",1,true)then return"emergency_craft"end;return k end

local function root()storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{enabled=true,stats={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version;r.stats=r.stats or{};if r.enabled==nil then r.enabled=true end;return r end
local function stat(k,n)local r=root();r.stats[k]=(r.stats[k]or 0)+(n or 1)end
local function queue(p)
  p.order_queue_0469=p.order_queue_0469 or{version=M.version,pending={},pending_keys={},history={},stats={}}
  local q=p.order_queue_0469;q.version=M.version;q.pending=q.pending or{};q.history=q.history or{};q.stats=q.stats or{};q.pending_keys={}
  local clean={};for _,o in ipairs(q.pending)do if o and o.key and o.status~="complete"and o.status~="failed"and o.status~="cancelled"and not q.pending_keys[o.key]then q.pending_keys[o.key]=true;clean[#clean+1]=o end end;q.pending=clean;return q
end
local function history(q,o,status,why)q.history[#q.history+1]={key=o and o.key or"nil",kind=o and o.kind or"nil",item=o and o.item,status=status,reason=why,tick=now()};while #q.history>M.max_history do table.remove(q.history,1)end end
local function key_for(p,k,item,target,role,purpose)local tk=target_key(target)or"none";return table.concat({k,safe(unit(p)or"?"),surface(p),safe(item or"none"),safe(role or purpose or"none"),tk},":")end
local function from_task(p,t,source,reason)
  t=t or{};local k=kind(t.type or t.kind or t.phase or source or p.mode);local item=t.item or t.item_name or t.output_item or t.wanted_item or t.requested_item;local target=t.target or t.entity or t.source;local role=t.role or(t.assignment and(t.assignment.id or t.assignment.role));local purpose=t.purpose or t.owner_system or reason or source
  return{key=t.order_key_0469 or key_for(p,k,item,target,role,purpose),kind=k,item=item,count=tonumber(t.count or t.amount or 1)or 1,target=target,target_key=target_key(target),role=role,purpose=purpose,source=source or"assign_task",reason=reason or"scheduler",priority=tonumber(t.priority)or priorities[k]or 100,task=t,created_tick=now(),updated_tick=now(),expires_tick=now()+(tonumber(t.timeout_ticks)or M.default_timeout_ticks),status="queued"}
end
local function has(q,k)if q.current and q.current.key==k then return q.current end;for _,o in ipairs(q.pending)do if o.key==k then return o end end end
local function merge(existing,new)for _,k in ipairs{"kind","item","count","target","target_key","role","purpose","source","reason","priority","task","expires_tick","wanted_item","request","recipe","op","depth","supply_kind","supply_target","doctrine_source"}do if new[k]~=nil then existing[k]=new[k]end end;existing.updated_tick=now();return existing end
local function pending(q,o,front,ignore_limit)if q.pending_keys[o.key]then return false,"duplicate"end;if not ignore_limit and #q.pending>=M.queue_limit then q.stats.queue_full=(q.stats.queue_full or 0)+1;stat("queue_full");return false,"queue-full"end;o.status=front and"paused"or"queued";o.paused_tick=front and now()or o.paused_tick;q.pending_keys[o.key]=true;if front then table.insert(q.pending,1,o)else q.pending[#q.pending+1]=o end;return true,front and"paused"or"queued"end

local function call_original(p,o)
  if o.source=="assign_task"and original_assign then local ok,x=pcall(original_assign,p,o.task,"order-queue-0469");return ok and x==true
  elseif o.source=="emergency_acquire"and original_acquire then local ok,x=pcall(original_acquire,p,o.item,o.op,o.count,o.depth);return ok and x==true
  elseif o.source=="maybe_supply_scavenge"and original_supply then local ok,x=pcall(original_supply,p,o.supply_kind or o.item,o.supply_target);return ok and x==true
  elseif o.source=="start_scavenge_scan"and original_scan then local ok,x=pcall(original_scan,p,o.request or{item_name=o.item});return ok and x~=false
  elseif o.source=="doctrine_start_direct"and original_direct then local ok,x=pcall(original_direct,p,o.doctrine_source,o.wanted_item or o.item,o.reason);return ok and x==true
  elseif o.source=="doctrine_handle_no_source"and original_no_source then local ok,x=pcall(original_no_source,p,o.wanted_item or o.item,o.recipe,o.reason);return ok and x==true end
  return o.task==nil
end
local function activate(p,q,o,why,run_callback)o.status="active";o.activated_tick=now();q.current=o;p.active_order_0469=o;history(q,o,"activated",why);if run_callback==false then o.last_activate_result="caller-owned";return true end;local ok=call_original(p,o);o.last_activate_result=ok and"ok"or"failed";return ok end
local function pop(q)while #q.pending>0 do local o=table.remove(q.pending,1);if o and o.key then q.pending_keys[o.key]=nil end;if o and o.status~="complete"and o.status~="failed"and o.status~="cancelled"and(not o.expires_tick or now()<=o.expires_tick)then return o end end end
local function promote(p,q,why)
  while true do local o=pop(q);if not o then q.current=nil;p.active_order_0469=nil;return false,"empty"end;if activate(p,q,o,why,true)then q.stats.promotions=(q.stats.promotions or 0)+1;stat("promotions");return true,"promoted"end;o.status="failed";o.finished_tick=now();o.finish_reason="activation-failed";history(q,o,"failed",o.finish_reason);q.current=nil;p.active_order_0469=nil;stat("activation_failed")end
end

function M.submit(p,o,opts)
  opts=opts or{};if root().enabled==false then return false,"disabled"end;if not valid_pair(p)then return false,"invalid-pair"end;if type(o)~="table"then return false,"nil-order"end
  local q=queue(p);o.kind=kind(o.kind);o.priority=tonumber(o.priority)or priorities[o.kind]or 100;o.key=o.key or key_for(p,o.kind,o.item,o.target,o.role,o.purpose or o.reason);o.updated_tick=now();o.expires_tick=o.expires_tick or now()+M.default_timeout_ticks
  local existing=has(q,o.key);if existing then merge(existing,o);q.stats.duplicates_merged=(q.stats.duplicates_merged or 0)+1;stat("duplicates_merged");return false,"duplicate-merged",existing end
  if not q.current then activate(p,q,o,"submit",false);q.stats.started=(q.stats.started or 0)+1;stat("started");return true,"active",o end
  if o.priority>(tonumber(q.current.priority)or 0)then local old=q.current;local ok,why=pending(q,old,true,false);if not ok then return false,"preempt-"..why,q.current end;old.preempted_by=o.key;activate(p,q,o,"preempt",false);q.stats.preemptions=(q.stats.preemptions or 0)+1;stat("preemptions");return true,"preempt",o end
  local ok,why=pending(q,o,false,false);if not ok then return false,why,q.current end;q.stats.enqueued=(q.stats.enqueued or 0)+1;stat("enqueued");return true,"queued",o
end

local function target_invalid(o)return o and o.target and type(o.target)=="table"and o.target.valid==false end
local function surface_active(p,o)
  local m=lower(p.mode);if o.kind=="combat"then return valid(p.combat_target)and(m:find("combat",1,true)or m:find("defend",1,true))elseif o.kind=="repair"then return m:find("repair",1,true)~=nil elseif o.kind=="consecration"then return m:find("consecr",1,true)~=nil or m:find("sanct",1,true)~=nil elseif o.kind=="logistics"or o.kind=="scavenge"then return p.logistic_requested_item~=nil or p.scavenge~=nil elseif o.kind=="acquisition"or o.kind=="emergency_craft"then return p.emergency_craft~=nil or p.direct_acquisition_task_0336~=nil or m:find("mine",1,true)~=nil or m:find("craft",1,true)~=nil end;return false
end
local function should_finish(p,o)if o.expires_tick and now()>o.expires_tick then return true,"expired","failed"end;if target_invalid(o)then return true,"target-invalid","failed"end;if not valid_pair(p)then return true,"invalid-pair","failed"end;if surface_active(p,o)then return false end;if o.status=="paused"and now()<(o.paused_tick or 0)+M.lease_ticks then return false end;local m=lower(p.mode);if m==""or m=="idle"or m=="returning"or m=="returning-to-station"or m=="scheduler-0277"then return true,"surface-cleared","complete"end;return false end
local function finalize(p,status,why,item)
  if not valid_pair(p)then return false,"invalid-pair"end;local q=queue(p);local o=q.current;if not o then return false,"no-current"end;if item and o.item and item~=o.item then return false,"item-mismatch"end;o.status=status;o.finished_tick=now();o.finish_reason=why;history(q,o,status,why);q.current=nil;p.active_order_0469=nil;promote(p,q,why);return true,status
end
function M.complete_current(p,why,item)return finalize(p,"complete",why or"completed-by-authority",item)end
function M.fail_current(p,why)return finalize(p,"failed",why or"failed-by-authority")end
function M.cancel_current(p,why)return finalize(p,"cancelled",why or"cancelled-by-authority")end
function M.transition_current(p,patch,why)
  if root().enabled==false then return false,"disabled"end;if not valid_pair(p)then return false,"invalid-pair"end;if type(patch)~="table"then return false,"invalid-patch"end
  local q=queue(p);local o=q.current;if not o then return false,"no-current"end
  local nk=kind(patch.kind or o.kind);local ni=patch.item~=nil and patch.item or o.item;local nt=patch.clear_target and nil or (patch.target~=nil and patch.target or o.target);local nr=patch.role~=nil and patch.role or o.role;local np=patch.purpose~=nil and patch.purpose or o.purpose
  local newkey=patch.key or key_for(p,nk,ni,nt,nr,np or patch.reason or why)
  if newkey~=o.key and q.pending_keys[newkey]then return false,"transition-duplicate"end
  merge(o,patch);if patch.clear_task==true then o.task=nil end;o.kind=nk;o.item=ni;o.target=nt;o.target_key=target_key(nt);o.role=nr;o.purpose=np;o.key=newkey;o.status="active";o.transition_tick=now();o.transition_reason=why or"transition";q.current=o;p.active_order_0469=o;history(q,o,"transitioned",o.transition_reason);stat("transitions");return true,"transitioned",o
end
function M.tick_pair(p,why)
  if root().enabled==false or not valid_pair(p)then return false end;local q=queue(p);if not q.current then local t=p.active_task or p.active_task_0285;if t then local o=from_task(p,t,"adopt-active",why);activate(p,q,o,"adopt",false);stat("adopted");return true end;return promote(p,q,"empty-current")end
  local done,reason,status=should_finish(p,q.current);if done then finalize(p,status,reason);return true end;q.current.last_seen_tick=now();return false
end

local function wrapper_result(p,o,call)
  local accepted,state=M.submit(p,o);if state=="duplicate-merged"or state=="queued"then return true end;if not accepted then return false end
  local ok=call();if not ok then M.fail_current(p,"activation-rejected")end;return ok
end
function M.wrap_assign_task()local f=rawget(_G,"tech_priests_0285_assign_task");if type(f)~="function"or original_assign then return end;original_assign=f;_G.TECH_PRIESTS_0469_PRE_ASSIGN_TASK=f;_G.tech_priests_0285_assign_task=function(p,t,r)if root().enabled==false or not valid_pair(p)then return f(p,t,r)end;local o=from_task(p,t,"assign_task",r);return wrapper_result(p,o,function()return f(p,t,r)==true end)end end
function M.wrap_cancel_task()local f=rawget(_G,"tech_priests_0285_cancel_task");if type(f)~="function"or original_cancel then return end;original_cancel=f;_G.TECH_PRIESTS_0469_PRE_CANCEL_TASK=f;_G.tech_priests_0285_cancel_task=function(p,r)local x=f(p,r);if p and p.order_queue_0469 and p.order_queue_0469.current then M.cancel_current(p,r)end;return x end end
function M.wrap_emergency_acquire()local f=rawget(_G,"tech_priests_emergency_operation_acquire_item_0185");if type(f)~="function"or original_acquire then return end;original_acquire=f;_G.TECH_PRIESTS_0469_PRE_EMERGENCY_ACQUIRE=f;_G.tech_priests_emergency_operation_acquire_item_0185=function(p,n,op,c,d)if root().enabled==false or not valid_pair(p)or not n then return f(p,n,op,c,d)end;local o=from_task(p,{type="logistics",item=n,count=c or 1,priority=priorities.logistics},"emergency_acquire","emergency-acquire");o.op=op;o.depth=d;return wrapper_result(p,o,function()return f(p,n,op,c,d)==true end)end end
function M.wrap_scavenge()
  local f=rawget(_G,"maybe_start_supply_scavenge");if type(f)=="function"and not original_supply then original_supply=f;_G.maybe_start_supply_scavenge=function(p,k,t)local n=p and p.active_supply_request and(p.active_supply_request.item or p.active_supply_request.item_name)or k;if n=="repair"then n="repair-pack"end;if root().enabled==false or not valid_pair(p)or not n then return f(p,k,t)end;local o=from_task(p,{type="scavenge",item=n,target=t,priority=priorities.scavenge},"maybe_supply_scavenge","supply-scavenge");o.supply_kind=k;o.supply_target=t;return wrapper_result(p,o,function()return f(p,k,t)==true end)end end
  f=rawget(_G,"start_logistic_scavenge_inventory_scan");if type(f)=="function"and not original_scan then original_scan=f;_G.start_logistic_scavenge_inventory_scan=function(p,r)local n=r and(r.item or r.item_name or r.name);if root().enabled==false or not valid_pair(p)or not n then return f(p,r)end;local o=from_task(p,{type="scavenge",item=n,count=r.count or 1},"start_scavenge_scan","scan");o.request=r;return wrapper_result(p,o,function()return f(p,r)~=false end)end end
end
function M.wrap_doctrine()local ok,D=pcall(require,"scripts.core.resource_doctrine");if not ok or not D then return end;Doctrine=D;if type(D.start_direct_task)=="function"and not original_direct then original_direct=D.start_direct_task;D.start_direct_task=function(p,s,w,r)local n=s and(s.output_item or s.item_name)or w;local o=from_task(p,{type="acquisition",item=n,target=s and s.entity,priority=priorities.acquisition},"doctrine_start_direct",r);o.doctrine_source=s;o.wanted_item=w;return wrapper_result(p,o,function()return original_direct(p,s,w,r)==true end)end end;if type(D.handle_no_source)=="function"and not original_no_source then original_no_source=D.handle_no_source;D.handle_no_source=function(p,w,recipe,r)local o=from_task(p,{type="logistics",item=w,priority=priorities.logistics},"doctrine_handle_no_source",r);o.wanted_item=w;o.recipe=recipe;return wrapper_result(p,o,function()return original_no_source(p,w,recipe,r)==true end)end end end

function M.tick_all(reason,budget)
  local r=root();local list={};for k,p in pairs(map())do if valid_pair(p)then list[#list+1]={key=tostring(k),pair=p}end end;table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return 0 end
  local lim=math.max(1,math.min(#list,math.floor(tonumber(budget)or 16)));local acted=0;local start=(tonumber(r.cursor)or 0)%#list+1;for i=0,lim-1 do local rec=list[((start+i-1)%#list)+1];local ok,d=pcall(M.tick_pair,rec.pair,reason or"broker");if ok and d==true then acted=acted+1 end end;r.cursor=(start+lim-2)%#list+1;return acted
end
function M.install()
  root();M.wrap_assign_task();M.wrap_cancel_task();M.wrap_emergency_acquire();M.wrap_scavenge();M.wrap_doctrine();if commands and commands.remove_command then pcall(commands.remove_command,"tp-order-queue-0469")end
  local b=rawget(_G,"TechPriestsRuntimeTickBroker0600");if b and type(b.register_service)=="function"then b.register_service{name="order_queue_0469",category="scheduler",interval=M.tick_interval,priority=30,budget=16,note="truthful per-pair order lifecycle",fn=function(e,budget)local n=M.tick_all("broker-tick",budget);return n>0,"acted="..n end}end
  _G.TECH_PRIESTS_ORDER_QUEUE_0469=M;_G.tech_priests_0469_submit_order=M.submit;_G.tech_priests_0469_complete_current=M.complete_current;_G.tech_priests_0469_fail_current=M.fail_current;_G.tech_priests_0469_transition_current=M.transition_current
  if log then log("[Tech-Priests 0.1.674-dev] truthful order queue recovery armed")end;return true
end
return M
