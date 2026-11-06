-- 1277: Factorio 2.1 crafter inventories replacing 2.0 assembly/furnace.
-- No magic numeric indices, safe refusal on unknown enum.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local native=require("scripts.core.native_crafter_inventory_1277")
local old={
 assembling_machine_input=2,assembling_machine_output=3,
 furnace_source=2,furnace_result=3,
 assembling_machine_modules=4, furnace_modules=4,
}
local modern={
 crafter_input=7,crafter_output=8,crafter_modules=9,crafter_trash=10,
}
for _,case in ipairs({{"input",2,7},{"output",3,8},{"modules",4,9}}) do
 local role,previous,new=case[1],case[2],case[3]
 assert(native.index(old,role)==previous and native.index(modern,role)==new,
  "native inventory enum changed for "..role)
 local mixed={}
 for k,v in pairs(old) do mixed[k]=v end
 for k,v in pairs(modern) do mixed[k]=v end
 assert(native.index(mixed,role)==new,
  "modern native enum was not preferred when both exist")
end
local divergent={furnace_source=3,furnace_result=4,assembling_machine_input=5,assembling_machine_output=6}
assert(native.index(divergent,"input","furnace")==3 and native.index(divergent,"output","furnace")==4)
assert(native.index(divergent,"input","assembler")==5 and native.index(divergent,"output","assembler")==6)
assert(native.index(modern,"trash")==10)
assert(native.index({},"input")==nil and native.index(nil,"input")==nil)
assert(native.index(modern,"unsupported")==nil)
for _,path in ipairs({
 "tech-priests_src/scripts/core/emergency_facility_doctrine.lua",
 "tests/scenarios/all-ground-ranks/ground_rank_harness.lua",
}) do
 local file=assert(io.open(path,"rb"))
 local text=file:read("*a");file:close()
 assert(text:find('crafter_index_1277("input"',1,true)
  and text:find('crafter_index_1277("output"',1,true),
  "missing tested native crafter index usage: "..path)
 for _,name in ipairs({"assembling_machine_input","assembling_machine_output",
    "furnace_source","furnace_result"}) do
  assert(not text:find("defines.inventory."..name,1,true),
   "unconverted removed inventory enum "..name.." in "..path)
 end
end
print("[native-crafter-inventory-1277] PASS authoritative 2.0/2.1 input/output/modules and no nil enum calls")
