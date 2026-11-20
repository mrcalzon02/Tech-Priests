package.path='./tech-priests_src/?.lua;'..package.path
local Sort=require('scripts.core.indexed_entity_sort_1494')
local N,REPS=1800,80
local samples={}
for i=1,N do samples[i]={unit_number=(i*983)%N} end
local function key(e) return 'u:'..string.format('%06d',e.unit_number) end
local function old(arr)
 table.sort(arr,function(a,b)
  return tostring(key(a) or '')<tostring(key(b) or '')
 end)
end
local function new(arr) Sort.sort(arr,key) end
local function run(fn)
 local began=os.clock()
 for i=1,REPS do
  local x={}
  for j=1,N do x[j]=samples[j] end
  fn(x)
  for j=2,N do assert(x[j-1].unit_number<=x[j].unit_number) end
 end
 return (os.clock()-began)*1000/REPS
end
local oldms,newms=run(old),run(new)
print(string.format('old %.4f ms/1800; new %.4f ms/1800; ratio %.2fx (local Lua, synthetic)',oldms,newms,oldms/newms))
