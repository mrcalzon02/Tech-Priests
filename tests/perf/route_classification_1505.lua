-- Synthetic routing microbenchmark; not a Factorio UPS measurement.
package.path='./tech-priests_src/?.lua;'..package.path
local C=require('scripts.core.route_classification_1505')
local category,owner='visuals','overhead-renderer'
local n,diagnostics=90,false
local function old()
 local c=string.lower(tostring(category or ''))
 local o=string.lower(tostring(owner or ''))
 local diag=diagnostics -- real legacy asks two settings on every callback
 if c=='diagnostics' or o:find('diagnostics',1,true) or o:find('pair_dump',1,true)then
  if not diag then return 999999 end
  return n>=80 and 8 or 3
 end
 if c=='visuals' or c=='audio' or c=='gui' or o:find('visual',1,true)
  or o:find('overhead',1,true) or o:find('sound',1,true)
  or o:find('voice',1,true) or o:find('chatter',1,true) then
  return n>=160 and 8 or n>=80 and 5 or n>=35 and 3 or 1
 end
 if c=='inventory' or c=='scheduler' or c=='crafting'
  or o:find('order_queue',1,true) or o:find('planning',1,true)
  or o:find('reserve',1,true) or o:find('inventory',1,true)then
  return n>=160 and 3 or n>=80 and 2 or 1
 end
 return 1
end
local class=C.classify(category,owner)
local function new() return C.multiplier(class,n,false) end
local N=200000
local function benchmark(fn)
 local start,check=os.clock(),0
 for i=1,N do check=check+fn() end
 return (os.clock()-start)*1000,check
end
local baseline,bcheck=benchmark(old)
local optimized,ocheck=benchmark(new)
assert(bcheck==ocheck)
print(('[route-classification-1505-perf] %d callbacks baseline=%.3fms optimized=%.3fms ratio=%.2fx (synthetic Lua)'):format(N,baseline,optimized,baseline/optimized))
