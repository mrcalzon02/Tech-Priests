-- T1-10: expanded-cache sorting calculates keys once per entity.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Sort=require('scripts.core.indexed_entity_sort_1494')
local entities={}
for i=1800,1,-1 do entities[#entities+1]={unit_number=i,valid=true} end
local probes=0
local function key(e)
 probes=probes+1
 return 'u:'..string.format('%06d',e.unit_number)
end
local original=entities
assert(Sort.sort(entities,key)==original)
assert(probes==1800,'key_for executed more than once per entity')
for i,e in ipairs(entities) do assert(e.unit_number==i,'lexical order changed') end
-- A no-op sized catalog and repeated sorts should remain safe.
local empty={}
assert(Sort.sort(empty,key)==empty and #empty==0 and probes==1800)
local single={{valid=true,unit_number=5}}
assert(Sort.sort(single,key)==single and single[1].unit_number==5)
assert(probes==1801)
assert(Sort.sort(nil,key)==nil)
-- All equal keys have no required secondary order, as in old comparator.
local equal={{valid=true,unit_number=2},{valid=true,unit_number=1}}
assert(Sort.sort(equal,function()return 'same' end)==equal)
assert(#equal==2 and equal[1]~=equal[2])
print('[indexed-entity-sort-1494] PASS: 1800 entities, one key each')
