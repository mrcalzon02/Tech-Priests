-- scripts/core/work_reservations.lua
-- Tech Priests 0.1.674-dev shared reservation authority.
-- This module arbitrates short-lived claims. It does not select behavior, move
-- priests, perform physical work, or own any family-specific terminal state.

local M={version="0.1.674-dev",storage_key="work_reservations_0601",default_ttl=600,position_scope_integrated=true,categories={"repair","sanctify","resource","construction","pickup","combat"}}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function pos_key(p)return p and string.format("%.1f,%.1f",tonumber(p.x)or 0,tonumber(p.y)or 0)or"no-pos"end
local function position_of(target)
 if type(target)~="table"then return nil end;if target.position and target.position.x and target.position.y then return target.position end;if target.x and target.y then return target end;return nil
end
local function surface_index_of(target,meta)
 if valid(target)then return target.surface and target.surface.index or nil end
 if type(target)=="table"and tonumber(target.surface_index)then return tonumber(target.surface_index)end
 return meta and tonumber(meta.surface_index)or nil
end
function M.target_key(target,meta)
 if valid(target)then if target.unit_number then return"unit:"..safe(target.unit_number)end;local surface=surface_index_of(target,meta);return(surface and("surface:"..surface..":")or"").."entity:"..safe(target.name)..":"..pos_key(target.position)end
 if type(target)=="table"then
  if target.unit_number then return"unit:"..safe(target.unit_number)end
  local position=position_of(target);if position then local surface=surface_index_of(target,meta);return(surface and("surface:"..surface..":")or"").."pos:"..pos_key(position)end
  if target.id then return"id:"..safe(target.id)end;if target.key then return"key:"..safe(target.key)end
 end
 return safe(target)
end
function M.pair_id(pair_or_id)
 if type(pair_or_id)~="table"then return safe(pair_or_id)end;if valid(pair_or_id.station)and pair_or_id.station.unit_number then return safe(pair_or_id.station.unit_number)end;return safe(pair_or_id.station_unit or pair_or_id.id or"unknown-pair")
end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,position_scope_integrated=true,reservations={},stats={},cleanup_cursor_0620=1};storage.tech_priests[M.storage_key]=r;r.version=M.version
 if r.enabled==nil then r.enabled=true end;r.position_scope_integrated=true;r.reservations=r.reservations or{};r.stats=r.stats or{};for _,cat in ipairs(M.categories)do r.reservations[cat]=r.reservations[cat]or{}end;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(r.stats[k]or 0)+(tonumber(n)or 1)end
local function ensure_category(category)
 category=tostring(category or"misc");local r=M.root();if not r.reservations[category]then r.reservations[category]={};local found=false;for _,name in ipairs(M.categories)do if name==category then found=true break end end;if not found then M.categories[#M.categories+1]=category end end;return category,r.reservations[category]
end
function M.get(category,target,meta)
 local r=M.root();category=tostring(category or"misc");local bucket=r.reservations[category];if not bucket then return nil end;local key=M.target_key(target,meta);local res=bucket[key];if res and(tonumber(res.expires_tick)or 0)<=now()then bucket[key]=nil;stat("expired_seen");return nil end;return res,key
end
function M.is_claimed(category,target,pair_or_id,meta)
 local res=M.get(category,target,meta);if not res then return false end;if pair_or_id and safe(res.pair_id)==M.pair_id(pair_or_id)then return false end;return true,res
end
function M.claim(category,target,pair_or_id,ttl,meta)
 local r=M.root();if r.enabled==false then return true,"disabled"end;category=ensure_category(category);local key=M.target_key(target,meta);local pair_id=M.pair_id(pair_or_id);local existing=r.reservations[category][key];if existing and(tonumber(existing.expires_tick)or 0)<=now()then r.reservations[category][key]=nil;existing=nil;stat("expired_seen")end
 if existing and safe(existing.pair_id)~=pair_id then stat("claim_denied");return false,"claimed",existing end
 local surface=surface_index_of(target,meta);local force=valid(target)and target.force and target.force.index or(type(target)=="table"and target.force_index)or(meta and meta.force_index)
 r.reservations[category][key]={key=key,category=category,pair_id=pair_id,expires_tick=now()+(tonumber(ttl)or M.default_ttl),target_name=valid(target)and target.name or nil,target_unit=valid(target)and target.unit_number or nil,surface_index=surface,force_index=force,created_tick=existing and existing.created_tick or now(),renewed_tick=now(),meta=meta};stat(existing and"claim_renewed"or"claim_created");if surface and position_of(target)then stat("surface_scoped_position_claims")end;return true,"claimed",r.reservations[category][key]
end
function M.release(category,target,pair_or_id,meta)
 local r=M.root();category=tostring(category or"misc");local bucket=r.reservations[category];if not bucket then return false end;local key=M.target_key(target,meta);local res=bucket[key];if not res then return false end;if pair_or_id and safe(res.pair_id)~=M.pair_id(pair_or_id)then stat("release_denied");return false end;bucket[key]=nil;stat("released");return true
end
function M.cleanup_expired(category,budget)
 local r=M.root();local cleaned,t=0,now();local cats;if category then cats={tostring(category)}else if#M.categories==0 then return 0 end;local idx=tonumber(r.cleanup_cursor_0620)or 1;if idx<1 or idx>#M.categories then idx=1 end;cats={M.categories[idx]};r.cleanup_cursor_0620=idx%#M.categories+1;stat("cleanup_rotated_categories")end
 for _,cat in ipairs(cats)do local bucket=r.reservations[cat]or{};for key,res in pairs(bucket)do if not res or(tonumber(res.expires_tick)or 0)<=t then bucket[key]=nil;cleaned=cleaned+1;stat("expired_cleaned");if budget and cleaned>=budget then stat("cleanup_budget_exhausted");return cleaned end end end end;return cleaned
end
function M.count(category)local r=M.root();local n=0;for _ in pairs(r.reservations[tostring(category or"")]or{})do n=n+1 end;return n end
function M.report_lines()
 M.cleanup_expired(nil,200);local r=M.root();local parts={};for _,cat in ipairs(M.categories)do parts[#parts+1]=cat.."="..safe(M.count(cat))end;return{"[tp-runtime-report] reservations "..table.concat(parts," ").." created="..safe(r.stats.claim_created or 0).." renewed="..safe(r.stats.claim_renewed or 0).." denied="..safe(r.stats.claim_denied or 0).." released="..safe(r.stats.released or 0).." expired="..safe(r.stats.expired_cleaned or 0).." surface_scoped="..safe(r.stats.surface_scoped_position_claims or 0)}
end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
function M.install()
 M.root();_G.TechPriestsWorkReservations0601=M;local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="work_reservations_0601_cleanup",category="runtime-cleanup",interval=300,priority=80,budget=120,note="expires stale surface-scoped shared work reservations",fn=function(_,budget)local n=M.cleanup_expired(nil,budget or 120);return{processed=1,acted=0,waiting=0,blocked=0,failed=0,detail="expired="..safe(n)}end});return service~=nil
end
return M
