-- Finished authored 3D inventory artwork. No recipe, research or behavior changes.
local root="__tech-priests__/graphics/icons/material-icons-v01/"
local rows={
 {"item","tech-priests-field-supply-pack","field-supply-pack"},
 {"item","tech-priests-martian-manufactorum","martian-manufactorum"},
 {"item","tech-priests-guard-muster-hall","guard-muster-hall"},
 {"item","tech-priests-sororitas-convent","sororitas-convent"},
}
local function apply(p,path)
 p.icon=path;p.icon_size=64;p.icons=nil;p.icon_mipmaps=nil
end
local replacements={}
for _,row in ipairs(rows) do
 local p=assert(data.raw[row[1]] and data.raw[row[1]][row[2]],"Missing modeled inventory prototype "..row[2])
 local path=root..row[3]..".png"
 replacements[row[2]]={path=path,previous=p.icon}
 apply(p,path)
 if p.place_result then
  for kind,prototypes in pairs(data.raw) do
   local e=prototypes[p.place_result]
   if e and kind~="recipe" and kind~="technology" and (e.collision_box or e.minable) then apply(e,path) end
  end
 end
end
-- Single-output recipes normally inherit item icons. Replace explicit legacy
-- multi-output icons only when their real primary result matches the item.
for _,recipe in pairs(data.raw.recipe) do
 local main=recipe.main_product
 if not main then
  if replacements[recipe.name] then
   for _,result in ipairs(recipe.results or {}) do if result.name==recipe.name then main=recipe.name;break end end
  end
  if not main and recipe.results and #recipe.results==1 then main=recipe.results[1].name end
  if (not main or main=="") and recipe.results and #recipe.results>1 then
   local first=recipe.results[1].name;local r=replacements[first]
   if r and recipe.icon==r.previous then main=first end
  end
 end
 local replacement=main and replacements[main]
 if replacement and (recipe.icon or recipe.icons) then apply(recipe,replacement.path) end
end
