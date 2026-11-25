-- Bounded dense scans must enumerate when possible and fail closed otherwise.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
local M = require("scripts.core.catalog_dense_scan_1478")
local function entity(id, x, y)
  return {unit_number=id, name="steel-chest",valid=true,position={x=x,y=y}}
end
local function surface(entities)
  local n=0
  return {find_entities_filtered=function(options)
    n=n+1
    local a,b=options.area[1],options.area[2]
    local out={}
    for _,e in ipairs(entities) do
      if e.position.x>=a[1] and e.position.x<b[1]
        and e.position.y>=a[2] and e.position.y<b[2] then
        out[#out+1]=e
        if #out>=options.limit then break end
      end
    end
    return out
  end, calls=function() return n end}
end
local area={{0,0},{64,64}}
local quiet={}
for i=1,500 do quiet[i]=entity(i,i%60+0.2,math.floor(i/60)+0.3) end
local q=surface(quiet)
local got,meta=M.scan(q,area,{limit=768})
assert(meta.complete and #got==500 and meta.queries==1 and q.calls()==1,
  "ordinary uncapped scan changed")
local crowd={}
for i=1,1100 do crowd[i]=entity(i,((i-1)%33)*1.7+0.1,math.floor((i-1)/33)*1.7+0.1) end
local c=surface(crowd)
local all,info=M.scan(c,area,{limit=768})
assert(info.complete and #all==1100 and info.queries==5 and info.splits==1,
  "dense 1,100-entity station area was not fully enumerated")
local unique={}
for _,e in ipairs(all) do assert(not unique[e.unit_number],"duplicate entity returned") unique[e.unit_number]=true end
local exact={}
for i=1,768 do exact[i]=entity(i,i%55+0.1,math.floor(i/55)+0.2) end
local e,em=M.scan(surface(exact),area,{limit=768})
assert(em.complete and #e==768 and em.queries==5,
  "exact-limit result was assumed complete or lost")
local tightly={}
for i=1,2400 do tightly[i]=entity(i,1+(i%13)*0.001,2+(i%19)*0.001) end
local many,m=M.scan(surface(tightly),area,{limit=768})
assert(not m.complete and m.truncated_leaves>=1 and m.queries<=13 and #many>=768,
  "unresolvable dense region falsely reported complete")
local low,lm=M.scan(surface(crowd),area,{limit=768,max_queries=1})
assert(not lm.complete and lm.budget_exhausted and lm.queries==1,
  "query budget exceeded or hidden truncation")
local capped,cm=M.scan(surface(quiet),area,{limit=768,max_entities=200})
assert(not cm.complete and cm.reason=="entity-budget" and #capped==200,
  "total results cap not enforced")
local neg={}
for i=1,800 do neg[i]=entity(i,-60+(i%45),-60+math.floor(i/45)) end
local ng,nm=M.scan(surface(neg),{{-64,-64},{0,0}},{limit=768})
assert(nm.complete and #ng==800,"negative coordinates lost entities")
local failures={find_entities_filtered=function() error("forced-failure") end}
local empty,err=M.scan(failures,area,{limit=768})
assert(not empty and not err.complete and err.reason=="surface-query-failed",
  "engine query failure was concealed")
-- Deterministic stress across both sides of the native query limit.
for _,population in ipairs({1,767,768,769,1500,2000,3000,5000}) do
  local samples={}
  for i=1,population do
    samples[i]=entity(i,((i*37)%6398)/100+0.01,
      ((i*71)%6398)/100+0.01)
  end
  local scanned,check=M.scan(surface(samples),area,{limit=768})
  assert(scanned and check.queries<=13 and #scanned<=3072,
    "population scan exceeded a resource budget")
  local got={}
  for _,item in ipairs(scanned) do
    assert(not got[item.unit_number],"population scan duplicated an entity")
    got[item.unit_number]=true
  end
  if check.complete then
    assert(#scanned==population,
      "complete population scan failed to enumerate the world")
  end
end
-- Two resources without unit_number share the catalog's quantized fallback key.
-- They are physically distinct and must not be merged by dense deduplication.
local a={valid=true,name="stone",type="simple-entity",position={x=10.011,y=11.02}}
local b={valid=true,name="stone",type="simple-entity",position={x=10.019,y=11.02}}
local collision,proof=M.scan(surface({a,b}),area,{
  limit=768,key_of=function(e)
    return e.name..":"..math.floor(e.position.x*10)..":"..math.floor(e.position.y*10)
  end})
assert(not proof.complete and proof.reason=="identity-collision"
  and #collision==2 and collision[1]~=collision[2]
  and proof.identity_collisions==1,
  "a fallback key collision must not silently drop or certify distinct entities")
-- The replacement identity helper distinguishes their actual positions.
local Identity=require("scripts.core.entity_identity_1481")
local precise,exact=M.scan(surface({a,b}),area,{limit=768,key_of=Identity.key})
assert(exact.complete and #precise==2 and exact.identity_collisions==0,
  "precise keys failed to preserve both real resources")

-- A reload retains ordinary continuation data and native entity identities,
-- while functions are recreated by requiring the module. These plain fixture
-- entities stand in for serialized LuaEntity handles; never use them as keys
-- in the continuation itself.
local handles={}
for _,item in ipairs(crowd) do handles[item]=true end
local function saved_copy(value,seen)
  local kind=type(value)
  assert(kind~="function" and kind~="thread","continuation retained a callback")
  if kind~="table" then return value end
  assert(getmetatable(value)==nil,"continuation retained a metatable")
  if handles[value] then return value end
  seen=seen or {}
  if seen[value] then return seen[value] end
  local copy={};seen[value]=copy
  for key,child in pairs(value) do
    assert(type(key)=="string" or type(key)=="number" or type(key)=="boolean",
      "continuation retained an object identity as a table key")
    copy[key]=saved_copy(child,seen)
  end
  return copy
end

local stepped_surface=surface(crowd)
local state=M.begin(area,{limit=768,key_of=Identity.key})
local finished,stepped,stepped_info,total_visits=false,nil,nil,0
local admissions=0
while not finished do
  admissions=admissions+1
  assert(admissions<100,"bounded dense continuation stopped making progress")
  local before_calls,before_size=stepped_surface.calls(),#state.out
  local usage
  finished,stepped,stepped_info,usage=M.step(state,stepped_surface,
    {queries=1,entities=128},Identity.key)
  assert(usage.queries<=1 and usage.entities<=128,
    "continuation exceeded a per-admission query/entity budget")
  assert(stepped_surface.calls()-before_calls==usage.queries,
    "usage concealed a real native query")
  assert(#state.out-before_size<=usage.entities,
    "newly appended records exceeded inspected-entry work")
  total_visits=total_visits+usage.entities
  if admissions==2 then
    state=saved_copy(state)
    package.loaded["scripts.core.catalog_dense_scan_1478"]=nil
    M=require("scripts.core.catalog_dense_scan_1478")
  end
end
assert(admissions>5 and total_visits>#stepped,
  "test did not exercise a buffered query and duplicate visits across pulses")
assert(#stepped==#all,"reload lost or duplicated dense scan results")
for index,item in ipairs(all) do
  assert(stepped[index]==item,"continuation changed deterministic scan order")
end
for key,value in pairs(info) do
  assert(stepped_info[key]==value,"continuation changed final metadata: "..key)
end
local final_calls=stepped_surface.calls()
local done_again,out_again,info_again,idle=M.step(state,stepped_surface,
  {queries=1,entities=128},Identity.key)
assert(done_again and out_again==stepped and info_again==stepped_info
  and idle.queries==0 and idle.entities==0 and stepped_surface.calls()==final_calls,
  "a completed continuation repeated work")

-- Invalid and duplicate buffered entries still consume the offered work.
local invalid={valid=false,position={x=1,y=1}}
local live=entity(9001,1,1)
local tail=entity(9002,2,2)
local mixed_calls=0
local mixed_surface={find_entities_filtered=function()
  mixed_calls=mixed_calls+1
  return {invalid,live,live,tail}
end}
local mixed=M.begin(area,{limit=768})
for index=1,4 do
  local done,items,details,usage=M.step(mixed,mixed_surface,
    {queries=index==1 and 1 or 0,entities=1})
  assert(usage.entities==1 and usage.queries==(index==1 and 1 or 0),
    "invalid/duplicate entry escaped the inspection budget")
  assert(#items==({0,1,1,2})[index],"buffered visit produced the wrong result tail")
  assert(done==(index==4),"buffered work was discarded or falsely completed")
  if done then assert(details.complete and details.unique==2) end
end
assert(mixed_calls==1,"buffer continuation repeated the spatial query")

-- Rejected filtering consumes this admission; retry the same partition in
-- the next one, without storing callbacks or resetting the global query cap.
local fallback_calls=0
local fallback_surface={find_entities_filtered=function(query)
  fallback_calls=fallback_calls+1
  if query.invert then error("unsupported inverted filter") end
  return {live}
end}
local fallback=M.begin(area,{exclude_types={"transport-belt"}})
local pending,items,details,used=M.step(fallback,fallback_surface,
  {queries=1,entities=128})
assert(not pending and #items==0 and used.queries==1 and used.entities==0
  and details.prefilter_fallbacks==1 and fallback_calls==1,
  "unfiltered fallback exceeded this admission's native query budget")
fallback=saved_copy(fallback)
local fallback_done,fallback_out,fallback_info,fallback_used=M.step(
  fallback,fallback_surface,{queries=1,entities=128})
assert(fallback_done and #fallback_out==1 and fallback_info.complete
  and fallback_info.queries==2 and fallback_used.queries==1
  and fallback_used.entities==1 and fallback_calls==2,
  "pending fallback did not survive data serialization")

-- Sliced collisions retain both physical entities and never certify the
-- ambiguous key; the duplicate of the second identity must still coalesce.
local collision_state=M.begin(area,{limit=768})
local collision_surface={find_entities_filtered=function() return {a,b,b} end}
local final_collision,collision_out,collision_info=false
for index=1,3 do
  final_collision,collision_out,collision_info,used=M.step(collision_state,
    collision_surface,{queries=1,entities=1},function() return "same-key" end)
  assert(used.entities==1)
end
assert(final_collision and #collision_out==2
  and collision_info.identity_collisions==1 and not collision_info.complete,
  "cross-pulse collision handling dropped or duplicated a real entity")

local capped_state=M.begin(area,{limit=768,max_entities=200})
local cap_done,cap_out,cap_info=false
local cap_surface=surface(quiet)
while not cap_done do
  cap_done,cap_out,cap_info,used=M.step(capped_state,cap_surface,
    {queries=1,entities=31})
  assert(used.queries<=1 and used.entities<=31)
end
assert(#cap_out==200 and cap_info.reason=="entity-budget"
  and cap_info.budget_exhausted and cap_surface.calls()==1,
  "continued query-buffer processing lost the aggregate entity cap")

local invalid_state=M.begin({{0,0},{0,0}})
local invalid_done,invalid_out,invalid_info,invalid_usage=M.step(
  invalid_state,stepped_surface,{queries=1,entities=128})
assert(invalid_done and invalid_out==nil and not invalid_info.complete
  and invalid_usage.queries==0 and invalid_usage.entities==0,
  "invalid geometry issued work or lost the legacy nil result")
print("[catalog-dense-scan-1478] PASS: synchronous parity, continued budgets, duplicates, fallback, collision, caps and reload")
