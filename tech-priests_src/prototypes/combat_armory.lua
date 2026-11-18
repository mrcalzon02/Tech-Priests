-- Existing local armory definitions separated from the unfinished actor slice.
-- Values and recipes remain those in the original combat_roster.register.
-- No combat actors, AAI bridge, movement owner or reinforcement are installed.
local C=require("shared.combat_roster_catalog")
local M={}
local prefix="tech-priests-"
local science={R="automation-science-pack",G="logistic-science-pack",M="military-science-pack",B="chemical-science-pack",P="production-science-pack",Y="utility-science-pack"}
local function enabled(faction)
 local s=settings.startup["tech-priests-combat-allow-"..faction]
 return not s or s.value
end
local function ingredients(bill)
 local out={};for _,row in ipairs(bill) do out[#out+1]={type="item",name=row[1],amount=row[2]} end;return out
end
local function recipe(name,bill,count,category,initial,time)
 return{type="recipe",name=name,enabled=initial==true,categories=category and {category} or {"crafting"},
  energy_required=time or 5,ingredients=ingredients(bill),results={{type="item",name=name,amount=count or 1}}}
end
function M.register()
 local definitions={}
 local function add(p) definitions[#definitions+1]=p;return p end
 local function unlock(tech,name)
  if tech then
   local t=assert(data.raw.technology[tech],"Missing combat technology "..tech)
   t.effects=t.effects or {};t.effects[#t.effects+1]={type="unlock-recipe",recipe=name}
  end
 end
 for name,t in pairs(C.technologies) do
  local packs={};for code in t.packs:gmatch(".") do packs[#packs+1]={science[code],1} end
  data:extend{{type="technology",name=name,icon="__base__/graphics/technology/military.png",icon_size=256,
   prerequisites=t.prerequisites,effects={},unit={count=t.count,time=30,ingredients=packs},order="z[combat]-"..name}}
 end
 local militant=data.raw.technology["tech-priests-militant-orders"]
 militant.prerequisites[#militant.prerequisites+1]="tech-priests-bolt-armaments"
 add{type="item-subgroup",name="tech-priests-combat-supplies",group="tech-priests",order="h[combat-supplies]"}
 add{type="fuel-category",name="tech-priests-field-supply"}
 add{type="item",name="tech-priests-field-supply-pack",icon="__base__/graphics/icons/solid-fuel.png",icon_size=64,
  subgroup="tech-priests-combat-supplies",stack_size=100,fuel_categories={"tech-priests-field-supply"},fuel_value="2MJ"}
 add(recipe("tech-priests-field-supply-pack",{{"iron-plate",1},{"copper-plate",1},{"wood",2}},5,nil,true,3))
 for family,a in pairs(C.ammo) do
  local category=prefix.."combat-"..family
  add{type="ammo-category",name=category}
  local delivery
  if family=="induction" then
   delivery={type="instant",target_effects={{type="damage",damage={amount=20,type=a.damage_type}}}}
  elseif family=="las" or family=="gamma" or family=="volkite" or family=="arc" then
   local beam=table.deepcopy(assert(data.raw.beam["laser-beam"]))
   beam.name=prefix.."combat-beam-"..family;beam.damage_interval=60
   beam.action=nil -- cosmetic; each paid trigger below owns exactly one hit
   add(beam)
   delivery={{type="instant",target_effects={{type="damage",damage={amount=20,type=a.damage_type}}}},
    {type="beam",beam=beam.name,duration=6,max_length=40,source_offset={0,-.5}}}
  else
   local projectile=table.deepcopy(assert(data.raw.projectile["piercing-shotgun-pellet"]))
   projectile.name=prefix.."combat-projectile-"..family
   projectile.action={type="direct",action_delivery={type="instant",target_effects={{type="damage",damage={amount=20,type=a.damage_type}}}}}
   add(projectile)
   delivery={type="projectile",projectile=projectile.name,starting_speed=1}
  end
  add{type="ammo",name=a.name,icon="__base__/graphics/icons/"..(a.damage_type=="physical" and "piercing-rounds-magazine" or "battery")..".png",icon_size=64,
   subgroup="tech-priests-combat-supplies",stack_size=100,magazine_size=a.shots,ammo_category=category,
   ammo_type={category=category,target_type="entity",action={type="direct",action_delivery=delivery}}}
  add(recipe(a.name,a.ingredients,a.count,nil,a.technology==nil,5))
  unlock(a.technology,a.name)
 end
 for _,u in ipairs(C.units) do
  local icon="__tech-priests__/graphics/icons/character-skins/"..u.id..".png"
  local gun=table.deepcopy(assert(data.raw.gun.pistol))
  gun.name=u.weapon;gun.icon=icon;gun.icon_size=128;gun.icons=nil;gun.subgroup="tech-priests-combat-supplies"
  gun.attack_parameters={type="projectile",ammo_category=prefix.."combat-"..u.ammo_family,cooldown=u.cooldown,
   range=u.range,damage_modifier=u.damage/20,movement_slow_down_factor=0,
   projectile_creation_distance=u.melee and 0 or .4,projectile_center={0,-.4},sound=u.melee and nil or gun.attack_parameters.sound}
  add(gun)
  add(recipe(u.weapon,u.weapon_ingredients,1,nil,u.technology==nil,5+u.stage*2))
  if enabled(u.faction) then unlock(u.technology,u.weapon) end
 end
 data:extend(definitions)
 -- Preserve the existing faction restriction on weapon production.
 for _,u in ipairs(C.units) do
  if not enabled(u.faction) then data.raw.recipe[u.weapon].enabled=false end
 end
end
return M
