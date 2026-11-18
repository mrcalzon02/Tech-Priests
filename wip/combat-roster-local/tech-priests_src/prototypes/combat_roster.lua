-- Separate combat actors; never change ranked worker identities, AI or custody.
local C=require("shared.combat_roster_catalog")
local M={}
local prefix="tech-priests-"
local categories={mechanicus="tech-priests-recruit-mechanicus",["astra-militarum"]="tech-priests-recruit-guard",sororitas="tech-priests-recruit-sororitas"}
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
local function empty()
 return {filename="__core__/graphics/empty.png",size=1,direction_count=1,frame_count=1}
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
 add{type="item-subgroup",name="tech-priests-combat-units",group="tech-priests",order="g[combat]"}
 add{type="item-subgroup",name="tech-priests-combat-supplies",group="tech-priests",order="h[combat-supplies]"}
 add{type="fuel-category",name="tech-priests-field-supply"}
 add{type="selection-tool",name="tech-priests-muster-order-tool",
  icon="__tech-priests__/graphics/icons/character-skins/enginseer.png",icon_size=128,
  flags={"not-stackable","only-in-cursor","spawnable"},subgroup="spawnables",stack_size=1,
  select={border_color={r=.9,g=.3,b=.15},mode={"any-tile"},cursor_box_type="copy"},
  alt_select={border_color={r=.5,g=.5,b=.5},mode={"any-tile"},cursor_box_type="not-allowed"}}
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
  local actor=table.deepcopy(assert(data.raw.car.car))
  actor.name=u.name;actor.localised_name={"entity-name."..u.name};actor.icon=icon;actor.icon_size=128;actor.icons=nil
  actor.minable={mining_time=.5,result=u.name};actor.max_health=u.health
  actor.collision_box={{-.25,-.25},{.25,.25}};actor.selection_box={{-.55,-.55},{.55,.55}}
  actor.drawing_box_vertical_extension=2;actor.weight=150
  actor.energy_source={type="burner",fuel_categories={"tech-priests-field-supply"},effectivity=1,fuel_inventory_size=1,burnt_inventory_size=0}
  actor.consumption="20kW";actor.friction_force=data.raw.car.car.friction_force*(.12/u.speed);actor.rotation_speed=.015
  actor.tank_driving=true
  actor.inventory_size=12;actor.guns={u.weapon};actor.turret_rotation_speed=.02
  actor.animation=empty();actor.turret_animation=empty();actor.light=nil;actor.light_animation=nil;actor.water_reflection=nil
  actor.working_sound=nil;actor.sound_no_fuel=nil;actor.stop_trigger=nil;actor.stop_trigger_speed=nil
  actor.dying_explosion=nil;actor.dying_trigger_effect=nil;actor.dying_sound=nil
  actor.open_sound=nil;actor.close_sound=nil
  actor.track_particle_triggers=nil;actor.effectivity=1;actor.energy_per_hit_point=1000000000
  actor.equipment_grid=nil;actor.fast_replaceable_group=nil;actor.next_upgrade=nil
  actor.resistances={{type="physical",decrease=u.stage,percent=math.min(35,u.stage*5)}}
  actor.is_military_target=true;actor.allow_passengers=true
  local corpse=table.deepcopy(assert(data.raw.corpse["small-remnants"]))
  corpse.name=u.name.."-corpse";corpse.animation=empty();corpse.animation.direction_count=1
  actor.corpse=corpse.name;add(corpse)
  add(actor)
  add{type="item-with-entity-data",name=u.name,icon=icon,icon_size=128,subgroup="tech-priests-combat-units",
   order=string.format("%02d-",u.stage)..u.id,place_result=u.name,stack_size=1}
  add(recipe(u.name,u.ingredients,1,categories[u.faction],u.technology==nil and enabled(u.faction),15+u.stage*10))
  if enabled(u.faction) then unlock(u.technology,u.name) end
  if data.raw.quality.uncommon then
   -- Paid advanced training produces a fresh uncommon actor. Native quality
   -- raises maximum health; existing mined actors never enter a recipe that
   -- would erase their health, names, fuel, ammunition or stored state.
   local name=u.name.."-reinforced"
   local bill=table.deepcopy(u.ingredients)
   local function extra(item,count)
    for _,row in ipairs(bill) do if row[1]==item then row[2]=row[2]+count;return end end
    bill[#bill+1]={item,count}
   end
   extra("steel-plate",25);extra("advanced-circuit",10)
   local advanced=recipe(name,bill,1,categories[u.faction],false,30+u.stage*15)
   advanced.results={{type="item",name=u.name,amount=1,quality_min="uncommon",quality_max="uncommon",affected_by_quality=false}}
   advanced.localised_name={"tech-priests-combat.reinforced-unit",u.label}
   advanced.allow_productivity=false;advanced.auto_recycle=false
   add(advanced)
   local prerequisites={"production-science-pack"}
   if u.technology then prerequisites[#prerequisites+1]=u.technology end
   if data.raw.technology["quality-module"] then prerequisites[#prerequisites+1]="quality-module" end
   local packs={{"automation-science-pack",1},{"logistic-science-pack",1},{"military-science-pack",1},
    {"chemical-science-pack",1},{"production-science-pack",1}}
   if u.stage==5 then packs[#packs+1]={"utility-science-pack",1};prerequisites[#prerequisites+1]="utility-science-pack" end
   add{type="technology",name=u.name.."-reinforcement",icon=icon,icon_size=128,
    localised_name={"tech-priests-combat.reinforced-unit",u.label},
    localised_description={"tech-priests-combat.reinforced-description"},
    prerequisites=prerequisites,effects=enabled(u.faction) and {{type="unlock-recipe",recipe=name}} or {},
    unit={count=250+u.stage*50,time=30,ingredients=packs},order="z[combat-reinforcement]-"..u.id}
  end
 end
 data:extend(definitions)
 -- Faction restrictions affect production, separately from cosmetic skin access.
 for _,u in ipairs(C.units) do
  if not enabled(u.faction) then data.raw.recipe[u.name].enabled=false;data.raw.recipe[u.weapon].enabled=false end
 end
end
function M.finalize()
 -- AAI normally adds a paid AI-conversion variant. Our faction recipe already
 -- makes the commandable actor: normalize AAI's generated composite under the
 -- canonical identity, keeping exactly one public production recipe per model.
 for _,u in ipairs(C.units) do
  local generated=u.name.."-"..u.weapon
  local variants={{"car",""},{"car","-_-solid"},{"car","-_-ghost"},{"character","-_-driver"},
   {"unit","-_-navigator"},{"simple-entity","-_-buffer"},{"virtual-signal","-_-signal"}}
  for _,v in ipairs(variants) do
   local kind,suffix=v[1],v[2]
   local p=table.deepcopy(assert(data.raw[kind][generated..suffix],"AAI composite missing: "..generated..suffix))
   p.name=u.name..suffix
   if p.factoriopedia_alternative then p.factoriopedia_alternative=u.name end
   if p.placeable_by then p.placeable_by={item=u.name,count=1} end
   if p.minable then p.minable={mining_time=.5,result=u.name} end
   if kind=="unit" then
    -- The invisible navigator must never supply a free secondary attack.
    p.attack_parameters.ammo_type.action.action_delivery.target_effects.damage.amount=0
   end
   data.raw[kind][generated..suffix]=nil
   data:extend{p}
  end
  local item=data.raw["item-with-entity-data"][generated]
  if item then item.hidden=true;item.hidden_in_factoriopedia=true;item.place_result=u.name end
  for _,suffix in ipairs({"","-reverse"}) do
   local name=generated..suffix
   if data.raw.recipe[name] then data.raw.recipe[name].enabled=false;data.raw.recipe[name].hidden=true end
   for _,tech in pairs(data.raw.technology) do
    for i=#(tech.effects or {}),1,-1 do if tech.effects[i].recipe==name then table.remove(tech.effects,i) end end
   end
  end
 end
end
return M
