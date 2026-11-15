local c=require('scripts.twin_cannon_controller')
local NAME='tech-priests-bunker-twin-cannon'
local function check(ok,msg)assert(ok,'[CANNON-ROLE] '..msg)end
script.on_init(function()
  local s=game.create_surface('twin-cannon-role',{default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  for _,p in ipairs({{0,0},{80,0},{160,0},{240,0}}) do s.request_to_generate_chunks(p,2) end;s.force_generate_chunk_requests()
  local function gun(name,x,ammo,count)
    local e=s.create_entity{name=name,position={x+.5,.5},force='player'};check(e.insert{name=ammo,count=count}==count,'load actual ammunition');return e
  end
  local function target(name,p)
    local e=s.create_entity{name=name,position=p,force='enemy'};e.disabled_by_script=true;return e
  end
  local ap=gun(NAME,0,'cannon-shell',1);local rifle=gun('gun-turret',80,'firearm-magazine',1);local lane=gun(NAME,160,'cannon-shell',1)
  local heavy1=target('tp-cannon-armour-target',{ap.position.x,ap.position.y-16})
  local heavy2=target('tp-cannon-armour-target',{rifle.position.x,rifle.position.y-16})
  local line={};for i=1,3 do line[i]=target('tp-cannon-line-target',{lane.position.x,lane.position.y-9-i*3}) end
  storage.role={ap=ap,rifle=rifle,lane=lane,heavy={heavy1,heavy2},line=line,shots={},damage={ap=0,rifle=0},deaths=0}
  game.forces.player.technologies[NAME].researched=true
  check(game.forces.player.recipes[NAME].enabled,'research unlocks recipe')
  local assembler=s.create_entity{name='assembling-machine-3',position={240,0},force='player'}
  check(assembler.set_recipe(NAME)==nil or assembler.get_recipe().name==NAME,'set native recipe')
  for _,ingredient in pairs(prototypes.recipe[NAME].ingredients) do check(assembler.insert{name=ingredient.name,count=ingredient.amount}==ingredient.amount,'load recipe ingredient '..ingredient.name) end
  storage.role.assembler=assembler
  c.init({graphics_enabled=false})
end)
script.on_event(defines.events.on_script_trigger_effect,function(e)
  c.effect(e)
  if e.effect_id==c.fire_effect then
    local id=e.source_entity.unit_number;storage.role.shots[id]=(storage.role.shots[id] or 0)+1
  end
end)
script.on_event(defines.events.on_trigger_created_entity,c.muzzle_created)
script.on_event(defines.events.on_entity_damaged,function(e)
  if e.entity==storage.role.heavy[1] then storage.role.damage.ap=storage.role.damage.ap+e.final_damage_amount
  elseif e.entity==storage.role.heavy[2] then storage.role.damage.rifle=storage.role.damage.rifle+e.final_damage_amount end
end)
script.on_event(defines.events.on_entity_died,function(e)
  if e.entity.name=='tp-cannon-line-target' then storage.role.deaths=storage.role.deaths+1 end
end)
script.on_event(defines.events.on_tick,function(e)
  c.tick(e);local r=storage.role;r.assembler.energy=1000000
  if e.tick==1900 then
    check(r.ap.get_item_count('cannon-shell')==0 and r.shots[r.ap.unit_number]==1,'one AP shell consumed')
    check(r.rifle.get_item_count('firearm-magazine')==0,'ten ordinary rounds consumed')
    check(r.damage.ap>20*r.damage.rifle,'AP shell materially outperforms a rifle magazine against heavy armour')
    check(r.lane.get_item_count('cannon-shell')==0 and r.shots[r.lane.unit_number]==1,'one shell fired into lane')
    local lane_state={};for _,target in ipairs(r.line) do lane_state[#lane_state+1]={valid=target.valid,health=target.valid and target.health or 0,position=target.valid and target.position or nil} end
    check(r.deaths>=2,'one original AP projectile penetrates multiple enemies '..helpers.table_to_json({deaths=r.deaths,targets=lane_state,launch=storage.twin_cannon.guns[r.lane.unit_number].last_launch}))
    check(r.assembler.get_item_count(NAME)==1,'native recipe produced one turret')
    local report={status='PASS',heavy_armour_damage=r.damage,comparison='One native cannon shell versus ten basic gun-turret rounds; identical physical armour',
      single_shell_lane_kills=r.deaths,recipe_output=r.assembler.get_item_count(NAME),power='Fixture supplies electrical energy; ingredients and recipe are real'}
    helpers.write_file('twin-cannon-role/result.json',helpers.table_to_json(report),false)
  end
end)
