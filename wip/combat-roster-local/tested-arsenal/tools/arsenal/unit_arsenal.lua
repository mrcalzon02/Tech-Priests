-- Owner's single-weapon roster. Playable first balance pass, not final AAI balance.
local M={}
local PREFIX='tech-priests-arsenal-'
local settings=require('prototypes.weapon_profiles')
M.profiles=settings.profiles;M.research=settings.research
local function tech(id) return PREFIX..M.research[id][1] end
M.supplies={
 ['galvanic-clips']={shots=5,damage={{12,'physical'}},effect='galvanic',delivery='projectile',speed=1.5,seconds=2,inputs={{'iron-plate',2},{'copper-plate',1}},batch=5},
 ['las-charge-cells']={shots=40,damage={{8,'laser'}},effect='las',seconds=3,inputs={{'iron-plate',1},{'copper-plate',2},{'electronic-circuit',1}},batch=5},
 ['tool-charges']={shots=20,damage={{12,'physical'},{8,'electric'}},effect='melee',seconds=3,inputs={{'copper-plate',2},{'electronic-circuit',1}},batch=5},
 ['bolt-magazines']={shots=10,damage={{20,'physical'},{8,'explosion'}},effect='bolt',delivery='projectile',speed=.65,seconds=5,inputs={{'piercing-rounds-magazine',2},{'steel-plate',2},{'explosives',1}},batch=4},
 ['radium-magazines']={shots=30,damage={{6,'physical'},{4,'radiation'}},effect='radium',delivery='projectile',speed=1,seconds=5,inputs={{'iron-plate',2},{'copper-plate',1},{'uranium-238',1}},batch=10},
 ['gamma-cells']={shots=8,damage={{40,'radiation'},{20,'electric'}},effect='gamma',seconds=6,inputs={{'battery',2},{'advanced-circuit',1}},batch=5},
 ['magnarail-slug-packs']={shots=3,damage={{200,'physical'}},effect='magnarail',delivery='projectile',speed=3,seconds=8,inputs={{'steel-plate',2},{'battery',1},{'advanced-circuit',2}},batch=5},
 ['volkite-cells']={shots=8,damage={{100,'fire'},{60,'laser'}},effect='volkite',duration=10,splash={radius=2,damage={{25,'fire'}}},seconds=10,inputs={{'battery',4},{'processing-unit',1},{'copper-plate',4}},batch=5},
 ['heavy-arc-cells']={shots=8,damage={{120,'electric'}},effect='arc',duration=8,splash={radius=3,damage={{60,'electric'}}},seconds=10,inputs={{'battery',2},{'processing-unit',1}},batch=5},
 ['graviton-charges']={shots=5,damage={{160,'physical'},{80,'electric'}},effect='graviton',duration=12,splash={radius=3.5,damage={{120,'physical'}}},slow=true,seconds=15,inputs={{'battery',4},{'processing-unit',2},{'low-density-structure',2}},batch=5},
}
-- id, unit recipe suffix, supply, cooldown ticks, range tiles, damage multiplier, science stage
M.weapons={
 {'galvanic-rifle','ranger','galvanic-clips',30,24,1,0},
 {'lasgun','guardsman','las-charge-cells',12,20,1,1},
 {'power-axe','enginseer','tool-charges',30,1.5,1.4,1},
 {'laspistol','imperial-officer','las-charge-cells',18,16,.8,2},
 {'bolt-pistol','lord-commissar','bolt-magazines',24,18,.8,2},
 {'radium-carbine','skitarii-vanguard','radium-magazines',8,18,1,3},
 {'radium-serpenta','skitarii-marshal','radium-magazines',18,20,1.6,3},
 {'gamma-pistol','datasmith','gamma-cells',40,16,1,3},
 {'boltgun','battle-sister','bolt-magazines',18,22,1,3},
 {'dialogus-staff','dialogus','tool-charges',40,1.5,2.2,3},
 {'condemnor-boltgun','canoness','bolt-magazines',24,28,1.2,3},
 {'magnarail-lance','manipulus','magnarail-slug-packs',90,34,1,4},
 {'volkite-blaster','dominus','volkite-cells',60,26,1,5},
 {'heavy-arc-rifle','kataphron-breacher','heavy-arc-cells',45,24,1,5},
 {'heavy-grav-cannon','kataphron-destroyer','graviton-charges',90,28,1,5},
}
local function ingredients(rows)
 local result={};for _,row in ipairs(rows) do result[#result+1]={type='item',name=row[1],amount=row[2]} end;return result
end
local function title(id)
 return id:gsub('%-',' '):gsub('^%l',string.upper)
end
function M.register(mod_name)
 local fx=require('prototypes.firing_effects');fx.register(M.supplies)
 local sounds=require('__base__.prototypes.entity.sounds')
 local path='__'..mod_name..'__/graphics/weapons/'
 local records={{type='item-subgroup',name=PREFIX..'weapons',group='combat',order='z[unit-arsenal]'},
  {type='item-subgroup',name=PREFIX..'supplies',group='combat',order='z[unit-supplies]'}}
 if not data.raw['damage-type'].radiation then records[#records+1]={type='damage-type',name='radiation',localised_name='Radiation'} end
 for id,supply in pairs(M.supplies) do
  local name=PREFIX..id;local ammo=table.deepcopy(data.raw.ammo['firearm-magazine'])
  ammo.name=name;ammo.localised_name=title(id);ammo.localised_description='Finite shared supply: '..supply.shots..' attacks per item. Used by players and matching unit weapons.'
  ammo.icon='__'..mod_name..'__/graphics/supplies/'..id..'.png';ammo.icon_size=64;ammo.icons=nil
  ammo.subgroup=PREFIX..'supplies';ammo.order=id;ammo.magazine_size=supply.shots;ammo.reload_time=nil
  ammo.ammo_category=name
  ammo.ammo_type=fx.ammo_type(id,supply)
  records[#records+1]={type='ammo-category',name=name,localised_name=title(id)}
  records[#records+1]=ammo
  records[#records+1]={type='recipe',name=name,enabled=id=='galvanic-clips',energy_required=supply.seconds,
   ingredients=ingredients(supply.inputs),results={{type='item',name=name,amount=supply.batch}}}
 end
 for index,row in ipairs(M.weapons) do
  local id,supply=row[1],row[3];local name=PREFIX..id;local profile=M.profiles[id]
  local gun=table.deepcopy(data.raw.gun['submachine-gun'])
  gun.name=name;gun.localised_name=title(id);gun.localised_description=profile.role..' Player weapon and unit component. Uses '..title(supply)..'.'
  gun.icon=path..id..'.png';gun.icon_size=64;gun.icons=nil;gun.subgroup=PREFIX..'weapons';gun.order=string.format('%02d',index)
  gun.attack_parameters.ammo_category=PREFIX..supply;gun.attack_parameters.ammo_categories=nil
  gun.attack_parameters.cooldown=row[4];gun.attack_parameters.range=row[5];gun.attack_parameters.min_range=0
  gun.attack_parameters.damage_modifier=row[6];gun.attack_parameters.ammo_consumption_modifier=1
  gun.attack_parameters.projectile_creation_distance=row[5]<2 and 0 or .6;gun.attack_parameters.shell_particle=nil
  gun.attack_parameters.movement_slow_down_factor=profile.move
  local effect=M.supplies[supply].effect
  if effect~='melee' and M.supplies[supply].delivery~='projectile' then gun.attack_parameters.type='beam' end
  gun.attack_parameters.sound=(effect=='las' or effect=='gamma' or effect=='volkite') and
   {filename='__base__/sound/fight/laser-1.ogg',volume=.5} or
   ((effect=='arc' or effect=='graviton' or effect=='melee') and
    {filename='__base__/sound/fight/electric-beam.ogg',volume=.5} or
    (effect=='bolt' and sounds.heavy_gunshot or sounds.light_gunshot))
  records[#records+1]=gun
  records[#records+1]={type='recipe',name=name,enabled=index==1,energy_required=profile.time,
   ingredients=ingredients(profile.cost),results={{type='item',name=name,amount=1}}}
  if index>1 then
   local science={{'automation-science-pack',1}};local stage=row[7]
   if stage>=2 then science[#science+1]={'logistic-science-pack',1} end
   if stage>=3 or id=='bolt-pistol' then science[#science+1]={'military-science-pack',1} end
   if stage>=3 then science[#science+1]={'chemical-science-pack',1} end
   if stage>=4 then science[#science+1]={'production-science-pack',1} end
   if stage>=5 then science[#science+1]={'utility-science-pack',1} end
   local research=M.research[id];local prerequisites={}
   for _,p in ipairs(research[3]) do prerequisites[#prerequisites+1]=p:sub(1,1)=='@' and tech(p:sub(2)) or p end
   if stage>=2 then prerequisites[#prerequisites+1]='logistic-science-pack' end
   records[#records+1]={type='technology',name=tech(id),localised_name=title(research[1]),icon=gun.icon,icon_size=64,
    prerequisites=prerequisites,effects={{type='unlock-recipe',recipe=name},{type='unlock-recipe',recipe=PREFIX..supply}},
    unit={count=research[2],time=30,ingredients=science}}
  end
 end
 data:extend(records)
end

-- Public recipe/gun contract for the separate AAI combat-roster implementation.
-- Only existing explicit recipes are updated; this module creates no unit actors.
function M.attach_unit_recipes()
 require('prototypes.unit_unlocks').attach(M)
end
-- Mounted attack backends use this exact gun definition; native AAI cars use guns={gun id}.
function M.attack_parameters(id)
 assert(M.profiles[id],'Unknown roster weapon '..tostring(id))
 return table.deepcopy(data.raw.gun[PREFIX..id].attack_parameters)
end
return M
