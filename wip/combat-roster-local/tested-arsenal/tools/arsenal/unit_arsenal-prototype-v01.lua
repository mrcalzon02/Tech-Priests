-- Owner's 15 single-weapon loadouts. Shared native gun/ammo definitions are also
-- real recipe ingredients. Numerical tuning is provisional, not approved balance.
local M={}
local PREFIX='tech-priests-arsenal-'
M.supplies={
 ['galvanic-clips']={shots=10,damage={{8,'physical'}},icon='firearm-magazine',inputs={{'iron-plate',2},{'copper-plate',1}},batch=5},
 ['las-charge-cells']={shots=20,damage={{10,'laser'}},icon='battery',inputs={{'iron-plate',1},{'copper-plate',2},{'electronic-circuit',1}},batch=5},
 ['tool-charges']={shots=20,damage={{8,'physical'},{2,'electric'}},icon='battery',inputs={{'copper-plate',2},{'electronic-circuit',1}},batch=5},
 ['bolt-magazines']={shots=10,damage={{14,'physical'},{4,'explosion'}},icon='piercing-rounds-magazine',inputs={{'piercing-rounds-magazine',2},{'steel-plate',2},{'explosives',1}},batch=4},
 ['radium-magazines']={shots=20,damage={{5,'physical'},{4,'radiation'}},icon='uranium-rounds-magazine',inputs={{'iron-plate',2},{'copper-plate',1},{'uranium-238',1}},batch=10},
 ['gamma-cells']={shots=8,damage={{22,'radiation'},{8,'electric'}},icon='battery',inputs={{'battery',2},{'advanced-circuit',1}},batch=5},
 ['magnarail-slug-packs']={shots=5,damage={{60,'physical'}},icon='cannon-shell',inputs={{'steel-plate',2},{'battery',1},{'advanced-circuit',2}},batch=5},
 ['volkite-cells']={shots=8,damage={{40,'fire'},{20,'laser'}},icon='battery',inputs={{'battery',4},{'processing-unit',1},{'copper-plate',4}},batch=5},
 ['heavy-arc-cells']={shots=8,damage={{65,'electric'}},icon='battery',inputs={{'battery',2},{'processing-unit',1}},batch=5},
 ['graviton-charges']={shots=5,damage={{65,'physical'},{35,'electric'}},icon='battery',inputs={{'battery',4},{'processing-unit',2},{'low-density-structure',2}},batch=5},
}
-- id, unit recipe suffix, supply, cooldown, range, damage modifier, prerequisite
M.weapons={
 {'galvanic-rifle','ranger','galvanic-clips',30,18,1,nil},
 {'lasgun','guardsman','las-charge-cells',12,20,1,'steel-processing'},
 {'power-axe','enginseer','tool-charges',30,1.5,1.8,'automation'},
 {'laspistol','imperial-officer','las-charge-cells',18,16,.75,'logistics'},
 {'bolt-pistol','lord-commissar','bolt-magazines',24,18,.8,'military-2'},
 {'radium-carbine','skitarii-vanguard','radium-magazines',8,18,1,'uranium-processing'},
 {'radium-serpenta','skitarii-marshal','radium-magazines',18,16,1.2,'uranium-processing'},
 {'gamma-pistol','datasmith','gamma-cells',40,16,1,'chemical-science-pack'},
 {'boltgun','battle-sister','bolt-magazines',18,22,1,'chemical-science-pack'},
 {'dialogus-staff','dialogus','tool-charges',40,1.5,1.2,'chemical-science-pack'},
 {'condemnor-boltgun','canoness','bolt-magazines',20,24,1.2,'chemical-science-pack'},
 {'magnarail-lance','manipulus','magnarail-slug-packs',60,30,1,'production-science-pack'},
 {'volkite-blaster','dominus','volkite-cells',60,26,1,'utility-science-pack'},
 {'heavy-arc-rifle','kataphron-breacher','heavy-arc-cells',60,25,1,'utility-science-pack'},
 {'heavy-grav-cannon','kataphron-destroyer','graviton-charges',90,28,1,'utility-science-pack'},
}
local function ingredients(rows)
 local result={};for _,row in ipairs(rows) do result[#result+1]={type='item',name=row[1],amount=row[2]} end;return result
end
local function title(id)
 return id:gsub('%-',' '):gsub('^%l',string.upper)
end
function M.register(mod_name)
 local path='__'..mod_name..'__/graphics/weapons/'
 local records={{type='item-subgroup',name=PREFIX..'weapons',group='combat',order='z[unit-arsenal]'},
  {type='item-subgroup',name=PREFIX..'supplies',group='combat',order='z[unit-supplies]'}}
 if not data.raw['damage-type'].radiation then records[#records+1]={type='damage-type',name='radiation',localised_name='Radiation'} end
 for id,supply in pairs(M.supplies) do
  local name=PREFIX..id;local ammo=table.deepcopy(data.raw.ammo['firearm-magazine'])
  ammo.name=name;ammo.localised_name=title(id);ammo.localised_description='Shared supply for the agreed single-weapon unit roster. Initial prototype tuning.'
  ammo.icon='__base__/graphics/icons/'..supply.icon..'.png';ammo.icon_size=64;ammo.icons=nil
  ammo.subgroup=PREFIX..'supplies';ammo.order=id;ammo.magazine_size=supply.shots;ammo.reload_time=nil
  ammo.ammo_category=name
  local effects={}
  for _,damage in ipairs(supply.damage) do effects[#effects+1]={type='damage',damage={amount=damage[1],type=damage[2]}} end
  effects[#effects+1]={type='create-entity',entity_name='explosion-hit'}
  ammo.ammo_type={target_type='entity',action={type='direct',action_delivery={type='instant',target_effects=effects}}}
  records[#records+1]={type='ammo-category',name=name,localised_name=title(id)}
  records[#records+1]=ammo
  records[#records+1]={type='recipe',name=name,enabled=id=='galvanic-clips',energy_required=2,
   ingredients=ingredients(supply.inputs),results={{type='item',name=name,amount=supply.batch}}}
 end
 for index,row in ipairs(M.weapons) do
  local id,supply=row[1],row[3];local name=PREFIX..id
  local gun=table.deepcopy(data.raw.gun['submachine-gun'])
  gun.name=name;gun.localised_name=title(id);gun.localised_description='Player weapon and unit equipment component. Uses '..title(supply)..'.'
  gun.icon=path..id..'.png';gun.icon_size=64;gun.icons=nil;gun.subgroup=PREFIX..'weapons';gun.order=string.format('%02d',index)
  gun.attack_parameters.ammo_category=PREFIX..supply;gun.attack_parameters.ammo_categories=nil
  gun.attack_parameters.cooldown=row[4];gun.attack_parameters.range=row[5];gun.attack_parameters.min_range=0
  gun.attack_parameters.damage_modifier=row[6];gun.attack_parameters.ammo_consumption_modifier=1
  gun.attack_parameters.projectile_creation_distance=.6;gun.attack_parameters.shell_particle=nil
  gun.attack_parameters.movement_slow_down_factor=row[5]<2 and .9 or .65
  records[#records+1]=gun
  local costs={{'iron-plate',10},{'copper-plate',5},{'iron-gear-wheel',2},{'electronic-circuit',1}}
  if id=='lasgun' then costs={{'iron-plate',6},{'copper-plate',3},{'electronic-circuit',1}}
  elseif index>=6 then costs={{'steel-plate',10+index},{'advanced-circuit',2},{'battery',2}}
   if index>=12 then costs[#costs+1]={'processing-unit',2} end
   if index==15 then costs[#costs+1]={'low-density-structure',5} end
  end
  records[#records+1]={type='recipe',name=name,enabled=index==1,energy_required=4+index,
   ingredients=ingredients(costs),results={{type='item',name=name,amount=1}}}
  if index>1 then
   local science={{'automation-science-pack',1}}
   if index>=4 then science[#science+1]={'logistic-science-pack',1} end
   if index>=5 then science[#science+1]={'military-science-pack',1} end
   if index>=6 then science[#science+1]={'chemical-science-pack',1} end
   if index>=12 then science[#science+1]={'production-science-pack',1} end
   if index>=13 then science[#science+1]={'utility-science-pack',1} end
   local prerequisites={row[7]}
   if index==4 then prerequisites[#prerequisites+1]=PREFIX..'lasgun' end
   if index==11 then prerequisites[#prerequisites+1]=PREFIX..'boltgun' end
   if index==15 then prerequisites={PREFIX..'volkite-blaster',PREFIX..'heavy-arc-rifle','low-density-structure'} end
   records[#records+1]={type='technology',name=name,localised_name=title(id),icon=gun.icon,icon_size=64,
    prerequisites=prerequisites,effects={{type='unlock-recipe',recipe=name},{type='unlock-recipe',recipe=PREFIX..supply}},
    unit={count=index==15 and 1500 or math.max(50,(index-1)*50),time=30,ingredients=science}}
  end
 end
 data:extend(records)
end

-- Public recipe/gun contract for the separate AAI combat-roster implementation.
-- Only existing explicit recipes are updated; this module creates no unit actors.
function M.attach_unit_recipes()
 for _,row in ipairs(M.weapons) do
  local aliases={'tech-priests-combat-'..row[2]}
  if row[2]=='ranger' then aliases[#aliases+1]='tech-priests-combat-skitarii-ranger' end
  if row[2]=='enginseer' then aliases[#aliases+1]='tech-priests-combat-tech-priest-enginseer' end
  for _,name in ipairs(aliases) do
   local recipe=data.raw.recipe[name]
   if recipe then
    recipe.ingredients=recipe.ingredients or {};local found=false
    for _,item in pairs(recipe.ingredients) do if (item.name or item[1])==PREFIX..row[1] then found=true end end
    if not found then recipe.ingredients[#recipe.ingredients+1]={type='item',name=PREFIX..row[1],amount=1} end
   end
  end
 end
end
return M
