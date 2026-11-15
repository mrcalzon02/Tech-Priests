-- Read-only configuration and admission checks, shared by world generation
-- and the existing canonical pair creator. No additional scheduler or state.
local M={}
local prefix="tech-priests-enemy-"
function M.get(key,default)
 local setting=settings and settings.global and settings.global[prefix..key]
 if setting then return setting.value end
 return default
end
function M.is_enemy_force(force)
 return force and force.name:find("^tech%-priests%-renegades%-")~=nil
end
function M.allowed_planet(planet)
 for name in M.get("allowed-planets","nauvis,fulgora,vulcanus,gleba"):gmatch("[^,%s]+")do
  if name:lower()==planet:lower()then return true end
 end
 return false
end
function M.admit_priests(force_name,additional)
 local total,local_count=0,0
 local root=storage and storage.tech_priests
 for _,pair in pairs(root and root.pairs_by_station or {})do
  local station=pair.station
  if station and station.valid and M.is_enemy_force(station.force)then
   -- Reserve missing priests' existing bindings as well as living workers;
   -- ordinary recovery may restore them without creating another slot.
   total=total+1
   if station.force.name==force_name then local_count=local_count+1 end
  end
 end
 local global_max=M.get("max-priests",96)
 local planet_max=M.get("max-priests-per-planet",24)
 return (global_max==0 or total+additional<=global_max)
   and (planet_max==0 or local_count+additional<=planet_max)
end
function M.admit_colony(surface,planet)
 if not M.admit_priests("tech-priests-renegades-"..planet,3)then return false end
 local total,local_count=0,0
 local root=storage and storage.tech_priests
 for _,records in pairs(root and root.enemy_planetary_seeding or {})do
  for _,colony in pairs(records)do
   if type(colony)=="table"then
    local alive=false
    for _,station in pairs(colony.stations or {})do
     if station.valid then alive=true;break end
    end
    if alive then
     total=total+1
     if colony.force=="tech-priests-renegades-"..planet then local_count=local_count+1 end
    end
   end
  end
 end
 local global_max=M.get("max-colonies",24)
 local planet_max=M.get("max-colonies-per-planet",6)
 return (global_max==0 or total<global_max)and(planet_max==0 or local_count<planet_max)
end
return M
