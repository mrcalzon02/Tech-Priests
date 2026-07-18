-- scripts/core/proxy_ammo_hardener_0649.lua
-- Tech Priests 0.1.674-dev recovery.
-- Broker-owned hidden-proxy ammunition service with exact removal, checked
-- insertion, persistent refund custody, and structured service accounting.

local M={version="0.1.674-dev",storage_key="proxy_ammo_hardener_0649",tick_interval=41,max_pairs_per_pulse=24,load_batch=10,log_interval=600}
local AMMO_ORDER={"uranium-rounds-magazine","piercing-rounds-magazine","firearm-magazine"}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,out=pcall(tostring,v);return ok and out or"?"end
local function lower(v)return string.lower(tostring(v or""))end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function station_unit(pair)return pair and(pair.station_unit or(valid(pair.station)and pair.station.unit_number))or nil end
local function priest_unit(pair)return pair and(pair.priest_unit or(valid(pair.priest)and pair.priest.unit_number))or nil end
local function valid_pair(pair)return type(pair)=="table"and valid(pair.station)end
local function root()
 storage.tech_priests=storage.tech_priests or{};storage.tech_priests[M.storage_key]=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,stats={},recent={},last_log={}}
 local r=storage.tech_priests[M.storage_key];r.version=M.version;if r.enabled==nil then r.enabled=true end;r.stats=r.stats or{};r.recent=r.recent or{};r.last_log=r.last_log or{};return r
end
local function stat(name,n)local r=root();r.stats[name]=(tonumber(r.stats[name])or 0)+(n or 1)end
local function record(action,pair,detail,force)
 local r=root();stat(action);local ev={tick=now(),action=tostring(action or"event"),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=safe(detail)};r.recent[#r.recent+1]=ev;while #r.recent>120 do table.remove(r.recent,1)end
 local key=ev.action..":"..ev.station;local last=tonumber(r.last_log[key]or-1000000)or-1000000;if force or now()-last>=M.log_interval then r.last_log[key]=now();if log then log("[Tech-Priests recovery] "..ev.action.." station="..ev.station.." priest="..ev.priest.." "..safe(detail))end end
end
local function item_exists(name)return name and prototypes and prototypes.item and prototypes.item[name]~=nil end
local function safe_inventory(entity,id)if not(valid(entity)and entity.get_inventory and id)then return nil end;local ok,inv=pcall(function()return entity.get_inventory(id)end);return ok and inv and inv.valid and inv or nil end
local function count(inv,item)if not(inv and inv.valid and item)then return 0 end;local ok,n=pcall(function()return inv.get_item_count(item)end);return ok and(tonumber(n)or 0)or 0 end
local function remove(inv,item,n)if not(inv and inv.valid and item and n and n>0)then return 0 end;local ok,got=pcall(function()return inv.remove{name=item,count=n}end);return ok and(tonumber(got)or 0)or 0 end
local function insert(inv,item,n)if not(inv and inv.valid and item and n and n>0)then return 0 end;local ok,got=pcall(function()return inv.insert{name=item,count=n}end);return ok and(tonumber(got)or 0)or 0 end
local function station_sources(pair)
 local out,seen={},{};local function add(inv,label)if inv and inv.valid and not seen[tostring(inv)]then out[#out+1]={inv=inv,label=label};seen[tostring(inv)]=true end end
 if not valid_pair(pair)then return out end
 local f=rawget(_G,"tech_priests_inventory_steward_sources_for_pair");if type(f)=="function"then local ok,sources=pcall(f,pair);if ok and type(sources)=="table"then for _,src in ipairs(sources)do if src and src.inv and src.inv.valid then add(src.inv,src.source or"steward")end end end end
 if defines and defines.inventory then add(safe_inventory(pair.station,defines.inventory.chest),"station-chest")end;return out
end
local function atomic_return(pair,item,n,reason)
 if n<=0 then return true end;local f=rawget(_G,"tech_priests_safe_deposit_item");if type(f)~="function"then return false,"atomic-storage-unavailable"end
 local ok,done,why,inserted=pcall(f,pair,item,n,reason or"proxy-ammo-refund-0649");inserted=tonumber(inserted)or(done==true and n or 0);return ok and done==true and inserted==n,why
end
local function retain_refund(pair,item,n,reason)
 pair.proxy_ammo_refund_custody_0649={version=M.version,item=item,count=n,reason=safe(reason),created_tick=now()};record("proxy-ammo-refund-custody-0649",pair,item.." x"..n,true)
end
local function service_refund(pair)
 local c=pair.proxy_ammo_refund_custody_0649;if not c then return false,"no-refund"end
 if not(item_exists(c.item)and tonumber(c.count)and c.count>0)then pair.proxy_ammo_refund_custody_0649=nil;record("proxy-ammo-invalid-custody-0649",pair,safe(c.item),true);return false,"invalid-refund-custody"end
 local ok,why=atomic_return(pair,c.item,c.count,"proxy-ammo-refund-retry-0649");if not ok then return false,"refund-blocked:"..safe(why)end
 pair.proxy_ammo_refund_custody_0649=nil;record("proxy-ammo-refund-complete-0649",pair,c.item.." x"..c.count,true);return true,"refund-complete"
end
function M.station_ammo(pair)
 for _,item in ipairs(AMMO_ORDER)do if item_exists(item)then for _,src in ipairs(station_sources(pair))do local n=count(src.inv,item);if n>0 then return item,n,src end end end end
 if prototypes and prototypes.item then for item_name,proto in pairs(prototypes.item)do local typ;pcall(function()typ=proto.type end);if typ=="ammo"then for _,src in ipairs(station_sources(pair))do local n=count(src.inv,item_name);if n>0 then return item_name,n,src end end end end end
 return nil,0,nil
end
function M.station_has_ammo(pair)local item,n=M.station_ammo(pair);return item~=nil and n>0 end
function M.ensure_proxy(pair)
 if pair then for _,key in ipairs{"proxy","proxy_turret","combat_proxy","hidden_proxy_0293","proxy_0293"}do local e=pair[key];if valid(e)then pair.proxy=e;return e end end end
 local f=rawget(_G,"ensure_proxy");if type(f)=="function"then local ok,proxy=pcall(f,pair);if ok and valid(proxy)then pair.proxy=proxy;return proxy end end;return nil
end
function M.proxy_ammo_inventory(pair)
 local proxy=M.ensure_proxy(pair);if not valid(proxy)or not defines or not defines.inventory then return nil,proxy end;return safe_inventory(proxy,defines.inventory.turret_ammo),proxy
end
function M.proxy_has_ammo(pair)
 local inv=M.proxy_ammo_inventory(pair);if inv and inv.valid then for _,item in ipairs(AMMO_ORDER)do if item_exists(item)and count(inv,item)>0 then return true end end;if prototypes and prototypes.item then for item_name,proto in pairs(prototypes.item)do local typ;pcall(function()typ=proto.type end);if typ=="ammo"and count(inv,item_name)>0 then return true end end end end;return false
end
function M.load_proxy_from_station(pair,reason)
 if root().enabled==false or not valid_pair(pair)then return false,"disabled-or-invalid"end
 if pair.proxy_ammo_refund_custody_0649 then return false,"refund-pending"end
 if M.proxy_has_ammo(pair)then pair.proxy_ammo_0649={tick=now(),status="already-loaded",reason=reason or"load"};return false,"already-loaded"end
 local inv,proxy=M.proxy_ammo_inventory(pair);if not(valid(proxy)and inv and inv.valid)then pair.proxy_ammo_0649={tick=now(),status="no-proxy-ammo-inventory",reason=reason or"load"};record("proxy-ammo-no-inventory-0649",pair,"reason="..safe(reason),true);return false,"no-proxy-ammo-inventory"end
 local item,available,src=M.station_ammo(pair);if not item then pair.proxy_ammo_0649={tick=now(),status="station-ammo-missing",reason=reason or"load"};return false,"station-ammo-missing"end
 local want=math.max(1,math.min(M.load_batch,available));local removed=remove(src.inv,item,want);if removed<=0 then pair.proxy_ammo_0649={tick=now(),status="station-remove-failed",item=item};return false,"station-remove-failed"end
 local loaded=insert(inv,item,removed);local leftover=removed-loaded;local refund_ok,refund_why=true,nil
 if leftover>0 then refund_ok,refund_why=atomic_return(pair,item,leftover,"proxy-ammo-insert-remainder-0649");if not refund_ok then retain_refund(pair,item,leftover,refund_why)end end
 pair.proxy_ammo_0649={tick=now(),status=loaded>0 and(leftover>0 and"partially-loaded"or"loaded")or"insert-failed",item=item,loaded=loaded,removed=removed,leftover=leftover,refund_complete=refund_ok,reason=reason or"load",source=src and src.label}
 record(loaded>0 and"proxy-ammo-loaded-0649"or"proxy-ammo-insert-failed-0649",pair,"item="..safe(item).." loaded="..loaded.." leftover="..leftover,true)
 return loaded>0,loaded>0 and"loaded"or(refund_ok and"insert-rejected-refunded"or"insert-rejected-refund-custody")
end
local function wrap_ammo_functions()
 if not rawget(_G,"TECH_PRIESTS_0649_PRE_LOAD_PROXY_FROM_STATION")then _G.TECH_PRIESTS_0649_PRE_LOAD_PROXY_FROM_STATION=rawget(_G,"load_proxy_from_station")or false;_G.load_proxy_from_station=function(pair,...)local did=M.load_proxy_from_station(pair,"load_proxy_from_station-0649");if did then return true end;local pre=rawget(_G,"TECH_PRIESTS_0649_PRE_LOAD_PROXY_FROM_STATION");if type(pre)=="function"then local ok,result=pcall(pre,pair,...);return ok and result==true end;return false end end
 _G.tech_priests_0293_proxy_has_ammo=function(pair)return M.proxy_has_ammo(pair)end
 _G.tech_priests_0293_station_has_ammo=function(pair)return M.station_has_ammo(pair)end
 _G.tech_priests_0295_station_or_proxy_has_ammo=function(pair)if M.proxy_has_ammo(pair)then return true end;if M.station_has_ammo(pair)then local did=M.load_proxy_from_station(pair,"station-or-proxy-check-0649");return did==true and M.proxy_has_ammo(pair)end;return false end
 return true
end
function M.service_pair(pair,reason)
 if root().enabled==false or not valid_pair(pair)then return false,"disabled-or-invalid"end
 if pair.proxy_ammo_refund_custody_0649 then return service_refund(pair)end
 if M.proxy_has_ammo(pair)then return false,"already-loaded"end
 local item=M.station_ammo(pair);if not item then return false,"station-ammo-missing"end
 local combatish=valid(pair.combat_target)or valid(pair.target)or lower(pair.mode):find("ammo",1,true)or pair.need_ammunition or pair.no_ammo_0295 or pair.pinned_no_ammo_0295
 if combatish or pair.proxy then return M.load_proxy_from_station(pair,reason or"service")end;return false,"not-needed"
end
function M.service_all(reason,budget)
 local acted,processed,blocked=0,0,0;local limit=math.max(1,math.min(M.max_pairs_per_pulse,math.floor(tonumber(budget)or M.max_pairs_per_pulse)))
 for _,pair in pairs(pair_map())do if processed>=limit then break end;if valid_pair(pair)then processed=processed+1;local ok,did,why=pcall(M.service_pair,pair,reason or"pulse");if ok and did==true then acted=acted+1 elseif not ok or tostring(why):find("blocked",1,true)or tostring(why):find("custody",1,true)then blocked=blocked+1;if not ok then record("proxy-ammo-service-error-0649",pair,did,true)end end end end
 return{processed=processed,acted=acted,blocked=blocked,exhausted=processed>=limit and processed<#pair_map(),detail="acted="..acted.." blocked="..blocked}
end
function M.install()
 root();local wrapped=wrap_ammo_functions();local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600");if not(broker and type(broker.register_service)=="function")then return false end
 local service=broker.register_service{name="proxy_ammo_hardener_0649",category="combat",interval=M.tick_interval,priority=54,budget=6,fn=function(_,budget)wrap_ammo_functions();return M.service_all("broker",budget)end,note="lossless station ammunition loading for hidden proxy gun"}
 if not service then return false end;_G.TechPriestsProxyAmmoHardener0649=M;if log then log("[Tech-Priests 0.1.674-dev] broker-owned proxy ammo hardener installed")end;return wrapped==true
end
return M
