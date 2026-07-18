-- scripts/core/runtime_event_registry.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Owner-keyed Factorio event surface with deterministic priority, route-local
-- filtering, owner-specific removal, failure isolation, and auditable metadata.

local Registry={version="0.1.674-dev",events={},nth_ticks={},event_routes={},nth_tick_routes={},init_routes={},configuration_routes={},installed_events={},installed_nth_ticks={},sequence=0,profiler_enabled=false,stats={},recent={}}
Registry.init_handlers=Registry.init_routes;Registry.configuration_changed_handlers=Registry.configuration_routes
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function now()return game and game.tick or 0 end
local function caller()
 if not(debug and debug.getinfo)then return"unknown",0 end;local i=debug.getinfo(3,"Sl")or debug.getinfo(2,"Sl");return i and(i.short_src or i.source)or"unknown",i and tonumber(i.currentline)or 0
end
local function meta(opts)
 opts=type(opts)=="table"and opts or{};local src,line=caller();local owner=safe(opts.owner or opts.module or src or"legacy-control");local route=safe(opts.route or opts.name or owner)
 local p=opts.priority;if p=="first"or p=="front"then p=-100000 elseif p=="last"or p=="final"then p=100000 else p=tonumber(p)or 0 end
 return{owner=owner,route=route,id=owner..":"..route,category=safe(opts.category or"uncategorized"),note=safe(opts.note or""),source=safe(opts.source or src),line=tonumber(opts.line or line)or 0,priority=p,stop_on_truthy=opts.stop_on_truthy==true,all=opts.all==true}
end
local function stat(k,n)Registry.stats[k]=(Registry.stats[k]or 0)+(n or 1)end
local function remember(kind,entry,detail)
 Registry.recent[#Registry.recent+1]={tick=now(),kind=kind,owner=entry and entry.owner,route=entry and entry.route,source=entry and entry.source,line=entry and entry.line,detail=safe(detail)};while #Registry.recent>100 do table.remove(Registry.recent,1)end
end
local function event_key(id)return safe(id)end
local function sort_routes(routes)table.sort(routes,function(a,b)if a.priority==b.priority then if a.sequence==b.sequence then return a.id<b.id end;return a.sequence<b.sequence end;return a.priority<b.priority end)end
local function upsert(routes,entry)
 for i,v in ipairs(routes)do if v.id==entry.id then entry.sequence=v.sequence;routes[i]=entry;sort_routes(routes);return"replaced"end end
 Registry.sequence=Registry.sequence+1;entry.sequence=Registry.sequence;routes[#routes+1]=entry;sort_routes(routes);return"added"
end
local function remove(routes,id,all)
 local n=0;for i=#routes,1,-1 do if all or routes[i].id==id then table.remove(routes,i);n=n+1 end end;return n
end

local function candidate(event)return event and(event.entity or event.created_entity or event.destination or event.source or event.ghost or event.robot)end
local function expected_match(actual,expected)
 if type(expected)=="table"then for _,v in pairs(expected)do if expected_match(actual,v)then return true end end;return false end
 if actual==expected then return true end
 if actual~=nil then local ok_name,name=pcall(function()return actual.name end);if ok_name and name~=nil and expected_match(name,expected)then return true end;local ok_index,index=pcall(function()return actual.index end);if ok_index and index~=nil and expected_match(index,expected)then return true end end
 return safe(actual)==safe(expected)
end
local function one_filter(event,f)
 if type(f)~="table"then return true end;local kind=f.filter;local e=candidate(event);local result=true
 if kind=="name"then result=e and expected_match(e.name,f.name)or false
 elseif kind=="type"then result=e and expected_match(e.type,f.type)or false
 elseif kind=="ghost_name"then result=e and expected_match(e.ghost_name or e.name,f.name or f.ghost_name)or false
 elseif kind=="ghost_type"then result=e and expected_match(e.ghost_type or e.type,f.type or f.ghost_type)or false
 elseif kind=="force"then result=expected_match((e and e.force)or(event and event.force),f.force)
 elseif kind=="surface"then result=expected_match((e and e.surface)or(event and(event.surface or event.surface_index)),f.surface)
 elseif kind=="damage-type"then result=expected_match(event and event.damage_type,f.type or f.name)
 elseif kind=="item"then local s=event and(event.item_stack or event.stack);result=s and expected_match(s.name,f.name)or false
 elseif kind=="recipe"then result=expected_match(event and event.recipe,f.name)or false
 elseif kind=="robot-has-cargo"then local r=event and event.robot;local c=0;if r and r.valid and r.get_inventory and defines and defines.inventory then local ok,inv=pcall(r.get_inventory,defines.inventory.robot_cargo);if ok and inv and inv.valid then c=inv.get_item_count()end end;result=c>0
 else result=true;stat("unknown_filter_broadened")end
 if f.invert then result=not result end;return result
end
local function matches(event,filters)
 if filters==nil then return true end;if type(filters)~="table"then return true end
 local list=filters.filter and{filters}or filters;local acc=nil
 for _,f in ipairs(list)do local ok,r=pcall(one_filter,event,f);if not ok then r=true;stat("filter_errors");remember("filter-error",nil,r)end;local mode=f.mode or"or";if acc==nil then acc=r elseif mode=="and"then acc=acc and r else acc=acc or r end end
 return acc~=false
end

local function profile(entry,ok,elapsed)
 local key=(entry.event and("event:"..entry.event)or entry.tick and("nth:"..entry.tick)or entry.lifecycle or"route")..":"..entry.id;local r=Registry.stats[key]or{calls=0,errors=0,total_ms=0,worst_ms=0};r.calls=r.calls+1;if not ok then r.errors=r.errors+1 end;if elapsed then r.total_ms=r.total_ms+elapsed;r.worst_ms=math.max(r.worst_ms,elapsed);r.avg_ms=r.total_ms/r.calls end;Registry.stats[key]=r
end
local function call(entry,event)
 if not(entry and type(entry.handler)=="function")then return nil end
 local profiler;if Registry.profiler_enabled and game and game.create_profiler then local ok,p=pcall(game.create_profiler,false);if ok then profiler=p end end
 local ok,result=pcall(entry.handler,event)
 local ms;if profiler then pcall(function()profiler.stop()end);local text=safe(profiler);ms=tonumber(text:match("([%d%.]+)"))end;profile(entry,ok,ms)
 if not ok then stat("handler_errors");remember("handler-error",entry,result);if log then log("[Tech Priests event registry] isolated handler failure owner="..entry.owner.." route="..entry.route.." source="..entry.source..":"..entry.line.." error="..safe(result))end;return nil end
 return result
end

local function dispatch_event(key,event)
 local routes=Registry.event_routes[key]or{};for _,entry in ipairs(routes)do if matches(event,entry.filters)then local handled=call(entry,event);if handled and entry.stop_on_truthy then return end end end
end
local function dispatch_tick(key,event)
 if _G and type(_G.tech_priests_should_run_nth_tick_0595)=="function"then local ok,a=pcall(_G.tech_priests_should_run_nth_tick_0595,tonumber(key)or key,Registry.nth_tick_routes[key],event);if ok and a==false then return end end
 for _,entry in ipairs(Registry.nth_tick_routes[key]or{})do local run=true;if _G and type(_G.tech_priests_route_budget_0598)=="function"then local ok,a=pcall(_G.tech_priests_route_budget_0598,entry,event,tonumber(key)or key);if ok and a==false then run=false end end;if run then local handled=call(entry,event);if handled and entry.stop_on_truthy then return end end end
end
local function install_event(id)
 local key=event_key(id);if Registry.installed_events[key]or not(script and script.on_event)then return end;Registry.installed_events[key]=id;script.on_event(id,function(event)dispatch_event(key,event)end)
end
local function install_tick(tick)
 local key=event_key(tick);if Registry.installed_nth_ticks[key]or not(script and script.on_nth_tick)then return end;Registry.installed_nth_ticks[key]=tick;script.on_nth_tick(tick,function(event)dispatch_tick(key,event)end)
end
local function uninstall_event(key)if Registry.installed_events[key]and script and script.on_event then script.on_event(Registry.installed_events[key],nil)end;Registry.installed_events[key]=nil end
local function uninstall_tick(key)if Registry.installed_nth_ticks[key]and script and script.on_nth_tick then script.on_nth_tick(Registry.installed_nth_ticks[key],nil)end;Registry.installed_nth_ticks[key]=nil end

function Registry.on_event(id,handler,filters,opts)
 if type(id)=="table"and handler~=nil then local out;for _,v in ipairs(id)do out=Registry.on_event(v,handler,filters,opts)end;return out end
 local key=event_key(id);Registry.event_routes[key]=Registry.event_routes[key]or{};local m=meta(opts)
 if handler==nil then local n=remove(Registry.event_routes[key],m.id,m.all);Registry.events[#Registry.events+1]={event=key,action="remove",owner=m.owner,route=m.route,count=n};if #Registry.event_routes[key]==0 then uninstall_event(key)end;return n end
 local entry={event=key,raw_event=id,handler=handler,filters=filters,owner=m.owner,route=m.route,id=m.id,category=m.category,note=m.note,source=m.source,line=m.line,priority=m.priority,stop_on_truthy=m.stop_on_truthy};local action=upsert(Registry.event_routes[key],entry);Registry.events[#Registry.events+1]={event=key,action=action,owner=m.owner,route=m.route,priority=m.priority};install_event(id);return entry
end
function Registry.on_nth_tick(tick,handler,opts)
 local key=event_key(tick);Registry.nth_tick_routes[key]=Registry.nth_tick_routes[key]or{};local m=meta(opts)
 if handler==nil then local n=remove(Registry.nth_tick_routes[key],m.id,m.all);Registry.nth_ticks[#Registry.nth_ticks+1]={tick=tick,action="remove",owner=m.owner,route=m.route,count=n};if #Registry.nth_tick_routes[key]==0 then uninstall_tick(key)end;return n end
 local entry={tick=tick,handler=handler,owner=m.owner,route=m.route,id=m.id,category=m.category,note=m.note,source=m.source,line=m.line,priority=m.priority,stop_on_truthy=m.stop_on_truthy};local action=upsert(Registry.nth_tick_routes[key],entry);Registry.nth_ticks[#Registry.nth_ticks+1]={tick=tick,action=action,owner=m.owner,route=m.route,priority=m.priority};install_tick(tick);return entry
end
local function lifecycle(list,handler,opts,name)
 local m=meta(opts);if handler==nil then return remove(list,m.id,m.all)end;local entry={lifecycle=name,handler=handler,owner=m.owner,route=m.route,id=m.id,category=m.category,note=m.note,source=m.source,line=m.line,priority=m.priority};return upsert(list,entry),entry
end
function Registry.on_init(handler,opts)
 local action,entry=lifecycle(Registry.init_routes,handler,opts,"init");if not Registry.installed_init and script and script.on_init then Registry.installed_init=true;script.on_init(function(event)for _,v in ipairs(Registry.init_routes)do call(v,event)end end)end;return entry or action
end
function Registry.on_configuration_changed(handler,opts)
 local action,entry=lifecycle(Registry.configuration_routes,handler,opts,"configuration");if not Registry.installed_configuration_changed and script and script.on_configuration_changed then Registry.installed_configuration_changed=true;script.on_configuration_changed(function(event)for _,v in ipairs(Registry.configuration_routes)do call(v,event)end end)end;return entry or action
end
function Registry.get_events()return Registry.events end
function Registry.get_nth_ticks()return Registry.nth_ticks end
function Registry.get_event_routes()return Registry.event_routes end
function Registry.get_nth_tick_routes()return Registry.nth_tick_routes end
function Registry.count_event_handlers()local n=0;for _,r in pairs(Registry.event_routes)do n=n+#r end;return n end
function Registry.count_nth_tick_handlers()local n=0;for _,r in pairs(Registry.nth_tick_routes)do n=n+#r end;return n end
function Registry.set_profiler_enabled(v)Registry.profiler_enabled=v==true;return Registry.profiler_enabled end
function Registry.profiler_report_lines(limit)
 local lines={"[tp-runtime-report] registry-0744 version="..Registry.version.." events="..Registry.count_event_handlers().." nth="..Registry.count_nth_tick_handlers().." errors="..safe(Registry.stats.handler_errors or 0).." unknown_filters="..safe(Registry.stats.unknown_filter_broadened or 0).." profiler="..safe(Registry.profiler_enabled)};local n=math.max(1,#Registry.recent-(tonumber(limit)or 8)+1);for i=n,#Registry.recent do local e=Registry.recent[i];if e then lines[#lines+1]="  registry.recent["..i.."] "..safe(e.kind).." owner="..safe(e.owner).." route="..safe(e.route).." src="..safe(e.source)..":"..safe(e.line).." "..safe(e.detail)end end;return lines
end
function RegistryProfiler0625_report_lines(limit)return Registry.profiler_report_lines(limit)end
function Registry.print_summary(player)if not(player and player.valid)then return end;for _,line in ipairs(Registry.profiler_report_lines(8))do player.print(line)end end
_G.TechPriestsRuntimeEventRegistry=Registry
return Registry
