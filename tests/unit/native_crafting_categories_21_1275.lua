local choose = dofile("tech-priests_src/prototypes/compatibility/native_crafting_categories_1275.lua")
local categories={"crafting","basic-crafting","advanced-crafting","electronics","pressing"}
local result21=choose({crafting={},["advanced-crafting"]={},electronics={}}, categories)
assert(#result21==3 and result21[1]=="crafting"
  and result21[2]=="advanced-crafting" and result21[3]=="electronics",
  "removed 2.1 basic-crafting should never be assigned")
local result20=choose({crafting={},["basic-crafting"]={},["advanced-crafting"]={},
  electronics={},pressing={}}, categories)
assert(#result20==5 and result20[2]=="basic-crafting"
  and result20[5]=="pressing", "valid 2.0 and modded native categories lost")
local duplicates=choose({crafting={}}, {"crafting","crafting"})
assert(#duplicates==1 and duplicates[1]=="crafting",
  "duplicate native category capabilities not deduplicated")
assert(not pcall(choose,{},categories), "missing real category registry accepted")
print("[native-categories-2.1-1275] PASS actual registry, 2.0 and 2.1 emergency assembler")
