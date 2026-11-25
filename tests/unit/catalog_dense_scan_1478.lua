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
-- The incoming incremental fixture's distinct serialization/parity contracts
-- use the selected begin/step API. No callback, metatable or object table key
-- belongs in a saved continuation; only engine handles retain their identity.
local handles={}
for _,item in ipairs(crowd)do handles[item]=true end
local function saved_copy(value,seen)
  local kind=type(value)
  assert(kind~='function' and kind~='thread','continuation retained a callback')
  if kind~='table' then return value end
  if handles[value]then return value end
  assert(getmetatable(value)==nil,'continuation retained a metatable')
  seen=seen or {};if seen[value]then return seen[value]end
  local copy={};seen[value]=copy
  for key,child in pairs(value)do
    assert(type(key)=='string' or type(key)=='number' or type(key)=='boolean',
      'continuation retained an object identity as a table key')
    copy[key]=saved_copy(child,seen)
  end
  return copy
end
do
  local stepped_surface=surface(crowd)
  local state=M.begin(area,{limit=768})
  local admissions,visits=0,0
  while not state.done do
    admissions=admissions+1
    assert(admissions<100,'dense continuation stopped making progress')
    local before_calls,before_size=stepped_surface.calls(),#state.results
    local batch,_,_,usage=M.step(stepped_surface,state,
      {query_budget=1,entity_budget=128,key_of=Identity.key})
    assert(usage.queries<=1 and usage.entities<=128
      and stepped_surface.calls()-before_calls==usage.queries,
      'continued usage concealed a native query or exceeded its budget')
    assert(#state.results-before_size==#batch and #batch<=usage.entities,
      'newly appended records escaped inspected-entry accounting')
    visits=visits+usage.entities
    if admissions==2 then
      state=saved_copy(state)
      package.loaded['scripts.core.catalog_dense_scan_1478']=nil
      M=require('scripts.core.catalog_dense_scan_1478')
    end
  end
  assert(admissions>5 and visits>#state.results and #state.results==#all,
    'reload did not exercise buffered duplicates or changed result coverage')
  for index,item in ipairs(all)do
    assert(state.results[index]==item,'reload changed deterministic scan order')
  end
  for key,value in pairs(info)do
    assert(state.info[key]==value,'continued metadata differs: '..key)
  end
  local final_calls=stepped_surface.calls()
  local batch,meta,done,idle=M.step(stepped_surface,state,
    {query_budget=1,entity_budget=128,key_of=Identity.key})
  assert(done and #batch==0 and meta==state.info and idle.queries==0
    and idle.entities==0 and stepped_surface.calls()==final_calls,
    'completed continuation repeated work')
end

-- Invalid and duplicate entries still consume result traversal budget, even
-- when no native calls are allowed while the saved buffer is being drained.
do
  local invalid={valid=false,position={x=1,y=1}}
  local live,tail=entity(9001,1,1),entity(9002,2,2)
  local calls=0
  local mixed_surface={find_entities_filtered=function()
    calls=calls+1;return {invalid,live,live,tail}
  end}
  local state=M.begin(area,{limit=768})
  for index=1,4 do
    local _,details,done,usage=M.step(mixed_surface,state,
      {query_budget=index==1 and 1 or 0,entity_budget=1})
    assert(usage.entities==1 and usage.queries==(index==1 and 1 or 0)
      and #state.results==({0,1,1,2})[index] and done==(index==4),
      'invalid/duplicate entry escaped its slice or discarded buffered work')
    if done then assert(details.complete and details.unique==2)end
  end
  assert(calls==1,'buffer traversal repeated a spatial query')
end

-- Persisting a rejected-filter retry must not repeat its already-counted
-- probe. The aggregate unique-entity cap also spans all resumed buffers.
do
  local calls=0
  local fallback_surface={find_entities_filtered=function(query)
    calls=calls+1
    if query.invert then error('unsupported inverted filter')end
    return {crowd[1]}
  end}
  local state=M.begin(area,{exclude_types={'transport-belt'}})
  local batch,details,done,usage=M.step(fallback_surface,state,
    {query_budget=1,entity_budget=128})
  assert(not done and #batch==0 and usage.queries==1 and usage.entities==0
    and details.prefilter_fallbacks==1 and calls==1)
  state=saved_copy(state)
  batch,details,done,usage=M.step(fallback_surface,state,
    {query_budget=1,entity_budget=128})
  assert(done and #batch==1 and details.complete and details.queries==2
    and usage.queries==1 and usage.entities==1 and calls==2,
    'pending filter fallback lost its partition or reset the total query cap')

  local capped_surface=surface(quiet)
  state=M.begin(area,{limit=768,max_entities=200})
  while not state.done do
    local _,_,_,used=M.step(capped_surface,state,{query_budget=1,entity_budget=31})
    assert(used.queries<=1 and used.entities<=31)
  end
  assert(#state.results==200 and state.info.reason=='entity-budget'
    and state.info.budget_exhausted and capped_surface.calls()==1,
    'continued buffer lost its aggregate unique-entity cap')
  local invalid_state,invalid_info=M.begin({{0,0},{0,0}})
  local before=capped_surface.calls()
  local invalid_out,invalid_scan=M.scan(capped_surface,{{0,0},{0,0}})
  assert(invalid_state==nil and not invalid_info.complete and invalid_out==nil
    and invalid_scan.reason=='invalid-scan-request' and capped_surface.calls()==before,
    'invalid geometry issued a query or lost the synchronous nil contract')
end

-- A duplicate of the second distinct identity in a collision group must
-- coalesce even when its equality comparisons are split across pulses.
do
  local state=M.begin(area,{limit=768})
  local collision_surface={find_entities_filtered=function()return {a,b,b}end}
  local slices=0
  while not state.done do
    slices=slices+1
    local _,_,_,used=M.step(collision_surface,state,
      {query_budget=1,entity_budget=1,key_of=function()return 'same-key'end})
    assert(used.entities<=1 and used.queries<=1 and slices<20)
  end
  assert(#state.results==2 and state.info.identity_collisions==1
    and not state.info.complete and slices>=6,
    'continued collision comparisons dropped or duplicated a physical identity')
end
print('[catalog-dense-scan-1478] PASS: synchronous parity; continued budgets, duplicates, caps and serializable reload')
