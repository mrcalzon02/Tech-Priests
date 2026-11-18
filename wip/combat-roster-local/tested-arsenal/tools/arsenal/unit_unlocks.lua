-- Bind the weapon to the real unit recipe's unlock, never a second research gate.
local M={};local P='tech-priests-arsenal-'
local function add(technology,recipe)
 technology.effects=technology.effects or {}
 for _,e in ipairs(technology.effects) do if e.type=='unlock-recipe' and e.recipe==recipe then return end end
 technology.effects[#technology.effects+1]={type='unlock-recipe',recipe=recipe}
end
function M.attach(arsenal)
 local remap={}
 for _,row in ipairs(arsenal.weapons) do
  local id=row[1];local research=arsenal.research[id]
  local fallback=research and data.raw.technology[P..research[1]]
  local aliases={'tech-priests-combat-'..row[2]}
  if row[2]=='ranger' then aliases[#aliases+1]='tech-priests-combat-skitarii-ranger' end
  if row[2]=='enginseer' then aliases[#aliases+1]='tech-priests-combat-tech-priest-enginseer' end
  if row[2]=='datasmith' or row[2]=='manipulus' or row[2]=='dominus' then
   aliases[#aliases+1]='tech-priests-combat-'..(row[2]=='datasmith' and 'cybernetica-' or 'tech-priest-')..row[2]
  end
  local gates={};local found=false;local default=false
  for _,name in ipairs(aliases) do
   local recipe=data.raw.recipe[name]
   if recipe then
    found=true;default=default or recipe.enabled~=false
    recipe.ingredients=recipe.ingredients or {};local has=false
    for _,item in pairs(recipe.ingredients) do if (item.name or item[1])==P..id then has=true end end
    if not has then recipe.ingredients[#recipe.ingredients+1]={type='item',name=P..id,amount=1} end
    local has_gate=false
    for gate,technology in pairs(data.raw.technology) do
     if not fallback or gate~=fallback.name then
      for _,e in ipairs(technology.effects or {}) do
       if e.type=='unlock-recipe' and e.recipe==name then gates[gate]=technology;has_gate=true end
      end
     end
    end
    if not has_gate and recipe.enabled==false then
     assert(fallback,'Starter Ranger recipe must be enabled or have a native research gate')
     add(fallback,name)
    end
   end
  end
  if found and (next(gates) or default) then
   local gate_names={};for gate in pairs(gates) do gate_names[#gate_names+1]=gate end;table.sort(gate_names)
   for _,gate in ipairs(gate_names) do add(gates[gate],P..id);add(gates[gate],P..row[3]) end
   if default then data.raw.recipe[P..id].enabled=true;data.raw.recipe[P..row[3]].enabled=true end
   if fallback then
    if default then remap[fallback.name]=false else remap[fallback.name]=gate_names[1] end
   end
  end
 end
 for name in pairs(remap) do data.raw.technology[name]=nil end
 for _,technology in pairs(data.raw.technology) do
  if technology.prerequisites then
   local result={};local seen={}
   for _,p in ipairs(technology.prerequisites) do
    if remap[p]~=nil then p=remap[p] end
    if p and p~=technology.name and not seen[p] then seen[p]=true;result[#result+1]=p end
   end
   technology.prerequisites=result
  end
 end
end
return M
