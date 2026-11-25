package.path='tech-priests_src/?.lua;tech-priests_src/?/init.lua;'..package.path
local Dense=require('scripts.core.catalog_dense_scan_1478')
local function entity(id)return {object_name='LuaEntity',valid=true,unit_number=id,
  name='ore',type='resource',position={x=id,y=1}}end
local function run(state,surface,opts,after)
  local rows,iterations={},0
  while not state.done and iterations<2000 do
    iterations=iterations+1
    local batch,info,done,work=Dense.step(surface,state,opts)
    assert(work.queries<=opts.query_budget and work.entities<=opts.entity_budget,
      'native query or result/comparison work exceeded the offered slice')
    for _,e in ipairs(batch)do rows[#rows+1]=e end
    if after then after(state,iterations)end
  end
  assert(state.done,'dense continuation did not finish under finite work')
  return rows,iterations
end
local area={{0,0},{64,64}}
local entries={};for i=1,20 do entries[i]=entity(i)end
local calls=0
local surface={find_entities_filtered=function()
  calls=calls+1;return entries
end}
local first=Dense.begin(area,{limit=64,max_queries=1})
local rows,n=run(first,surface,{query_budget=1,entity_budget=1})
assert(first.info.complete and #rows==20 and n==20 and calls==1,
  'global query ceiling discarded a partially consumed result')
local collision=Dense.begin(area,{limit=64,max_queries=1})
calls=0
local many,steps=run(collision,surface,{query_budget=1,entity_budget=1,
  key_of=function()return 'shared-key'end})
assert(#many==20 and collision.info.identity_collisions==19 and steps>=210
  and calls==1 and not collision.info.complete,
  'collision comparisons hid unbounded work or lost distinct entities')
local fail_count=0
local fallback_surface={find_entities_filtered=function(query)
  fail_count=fail_count+1
  if query.invert then error('unsupported-filter')end
  return entries
end}
local fallback=Dense.begin(area,{limit=64,max_queries=2,exclude_types={'container'}})
local _,_,done,work=Dense.step(fallback_surface,fallback,
  {query_budget=1,entity_budget=1})
assert(not done and work.queries==1 and fallback.retry and fail_count==1,
  'filter fallback escaped one-call slice')
local recovered=run(fallback,fallback_surface,{query_budget=1,entity_budget=1})
assert(fallback.info.complete and #recovered==20 and fail_count==2,
  'deferred fallback repeated the failed query or dropped result rows')
local capped=Dense.begin(area,{limit=64,max_queries=1,exclude_types={'container'}})
local _,info= Dense.step(fallback_surface,capped,{query_budget=1,entity_budget=1})
assert(capped.done and not info.complete and info.reason=='prefilter-fallback-budget',
  'global query cap did not count failed filter probe')
print('[dense-step-independent] PASS: final native result drained; collision comparisons sliced; deferred fallback bounded')
