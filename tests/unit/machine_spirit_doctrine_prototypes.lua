local prototypes={}
data={extend=function(_,entries)
 for _,p in ipairs(entries) do
   assert(p.type and p.name,"prototype missing name/type")
   local key=p.type..":"..p.name
   assert(not prototypes[key],"duplicate "..key)
   prototypes[key]=p
 end
end}
assert(loadfile("tech-priests_src/prototypes/machine_spirit_doctrines.lua"))()
local function has(list,x)
 for _,value in ipairs(list or {}) do if value==x then return true end end
 return false
end
for _,kind in ipairs({"order","chaos"}) do
 assert(prototypes["module-category:tech-priests-machine-spirit-"..kind].type=="module-category")
 for tier=1,2 do
   local name="tech-priests-"..kind.."-module-"..tier
   local tname="machine-spirit-"..(kind=="order" and "law-order" or "chaos-anarchy").."-"..tier
   local module=assert(prototypes["module:"..name],name)
   assert(module.type=="module" and module.tier==tier)
   assert(module.category=="tech-priests-machine-spirit-"..kind)
   local recipe=assert(prototypes["recipe:"..name],"missing "..name.." recipe")
   local tech=assert(prototypes["technology:"..tname],"missing "..tname.." tech")
   assert(recipe.enabled==false and recipe.results[1].name==name)
   assert(tech.effects[1].recipe==name and tech.effects[1].type=="unlock-recipe")
   if tier==2 then
     assert(has(tech.prerequisites, tname:sub(1,-2).."1"),"missing parent tech")
     assert(has(tech.prerequisites,"processing-unit"),"Tier II needs Factorio 2.1 processing-unit research")
     assert(not has(tech.prerequisites,"advanced-electronics-2"),"obsolete Factorio prerequisite returned")
   end
 end
end
print("[machine-spirit-doctrine-prototypes] PASS two branches and module categories")
