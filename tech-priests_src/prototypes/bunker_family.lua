-- Playable native prototypes for the existing six-station lobber and energy dish.
-- Balance values are prototype defaults, distinct from the established cannon.
local M = {}
function M.register(mod_name)
  require('prototypes.bunker_autocannon').register(mod_name)
  if data.raw['ammo-turret']['tech-priests-bunker-lobber'] then return end
  local root = '__'..mod_name..'__/graphics/entity/'
  local g = require('prototypes.bunker_autocannon_graphics')
  local cannon = data.raw['ammo-turret']['tech-priests-bunker-autocannon']
  local function sprite(folder, mode, pass, frames)
    local stripes = {}
    for d=0,63 do
      stripes[#stripes+1]={filename=root..folder..'/'..(pass and pass..'-' or '')..mode..'-'..string.format('%02d',d)..'.png',
        width_in_frames=mode=='cycle' and 16 or frames,
        height_in_frames=mode=='cycle' and 12 or 1}
    end
    local is_shadow=pass=='shadow' or (folder=='bunker-energy-dish' and mode=='shadow')
    return {width=is_shadow and 512 or 256,height=is_shadow and 512 or 256,
      frame_count=frames,direction_count=64,stripes=stripes,
      scale=g.turret_scale,shift=g.turret_shift,apply_projection=true,
      draw_as_shadow=is_shadow or nil,draw_as_glow=pass=='emission' or nil}
  end
  local function lobber_anim(mode, frames)
    return {layers={sprite('bunker-lobber',mode,'shadow',frames),
      sprite('bunker-lobber',mode,'beauty',frames),sprite('bunker-lobber',mode,'emission',frames)}}
  end
  local function identity(t, name)
    t.name=name;t.minable={mining_time=1,result=name}
    t.localised_name={'entity-name.'..name};t.localised_description={'entity-description.'..name}
    t.icon=root..'bunker-autocannon/icon.png';t.icons=nil;t.icon_size=128
    t.corpse='big-remnants';t.dying_explosion='big-explosion'
  end
  local lobber=table.deepcopy(cannon)
  identity(lobber,'tech-priests-bunker-lobber')
  lobber.icon=root..'bunker-lobber/icon.png'
  -- Native turret states serialize an attack behind the entire animation.
  -- A shot-driven visual player below retains the 480-tick authored cycle
  -- while the native weapon consumes one real round every 80 ticks.
  -- Native previews render the current native state, including attacking.
  -- This conservative solid cap is covered by every full world-animation
  -- frame (see coverage-proof.json), preventing a second resting gun from
  -- showing through recoil/hatch motion. The concrete base stays separate.
  for _,key in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'}) do
    lobber[key]=sprite('bunker-lobber','native',nil,1)
  end
  lobber.starting_attack_animation=nil;lobber.ending_attack_animation=nil
  -- Bias the normalized float progress below 80 ticks to avoid an 81st tick
  -- from accumulated float rounding; the native cooldown still gates at 80.
  lobber.attacking_speed=1/79.9
  lobber.attack_from_start_frame=false;lobber.start_attacking_only_when_can_shoot=true
  lobber.leave_attacking_if_shoot_fails=false
  lobber.attack_parameters.cooldown=80
  lobber.attack_parameters.ammo_category='tech-priests-lobber-grenade'
  lobber.attack_parameters.range=28;lobber.attack_parameters.min_range=6
  lobber.attack_parameters.projectile_creation_distance=0.65
  lobber.attack_parameters.projectile_center={0,-1.6}
  local projectile=table.deepcopy(data.raw.projectile.grenade)
  projectile.name='tech-priests-lobber-grenade-projectile'
  -- Preserve the native arcing grenade, blast, smoke and impact behavior.
  local ammo={type='ammo',name='tech-priests-lobber-grenade-magazine',
    icon='__base__/graphics/icons/grenade.png',icon_size=64,
    subgroup='tech-priests-bunker-weapons',order='d[lobber-grenades]',stack_size=100,magazine_size=6,
    ammo_category='tech-priests-lobber-grenade',
    ammo_type={target_type='position',action={type='direct',action_delivery={type='projectile',
      source_effects={{type='script',effect_id='tech-priests-lobber-shot'}},
      projectile=projectile.name,starting_speed=0.3,direction_deviation=0,range_deviation=0,max_range=32}}}}
  if not data.raw.ammo['firearm-magazine'].ammo_category then
    ammo.ammo_category=nil;ammo.ammo_type.category='tech-priests-lobber-grenade'
  end
  local dish=table.deepcopy(data.raw['electric-turret']['laser-turret'])
  identity(dish,'tech-priests-bunker-energy-dish')
  dish.icon=root..'bunker-energy-dish/icon.png'
  for _,key in ipairs({'collision_box','selection_box','tile_width','tile_height','max_health',
      'graphics_set','base_picture','drawing_box_vertical_extension'}) do dish[key]=table.deepcopy(cannon[key]) end
  dish.turret_base_has_direction=true;dish.rotation_speed=0.005
  dish.random_animation_offset=false;dish.preparing_speed=1;dish.folding_speed=1
  dish.preparing_sound=nil;dish.folding_sound=nil
  dish.integration=nil;dish.water_reflection=nil;dish.circuit_connector=nil;dish.circuit_wire_max_distance=nil
  for _,key in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation'}) do
    dish[key]={layers={sprite('bunker-energy-dish','shadow',nil,1),sprite('bunker-energy-dish','idle',nil,1)}}
  end
  dish.energy_glow_animation=sprite('bunker-energy-dish','emission',nil,1)
  dish.energy_glow_animation.draw_as_glow=true
  dish.glow_light_intensity=0.5
  dish.attacking_animation=nil
  dish.attack_parameters=table.deepcopy(data.raw['electric-turret']['laser-turret'].attack_parameters)
  dish.attack_parameters.range=28;dish.attack_parameters.damage_modifier=4
  dish.attack_parameters.cooldown=120
  -- Local emitter centre is (0,-1.095,2.86). Native source_offset rotates
  -- the horizontal reach; delivery offset supplies fixed projected height.
  dish.attack_parameters.source_offset={0,-1.095}
  dish.attack_parameters.ammo_type.action.action_delivery.source_offset={0,-2.022325394193526}
  dish.attack_parameters.ammo_type.action.action_delivery.max_length=28
  dish.attack_parameters.ammo_type.action.action_delivery.beam='tech-priests-dish-zap'
  dish.attack_parameters.ammo_type.action.action_delivery.duration=6
  dish.attack_parameters.ammo_type.action.action_delivery.source_effects={{type='script',effect_id='tech-priests-dish-discharge'}}
  dish.attack_parameters.ammo_type.energy_consumption='800kJ'
  local zap=table.deepcopy(data.raw.beam['electric-beam'])
  zap.name='tech-priests-dish-zap';zap.width=0.8;zap.damage_interval=120
  zap.random_target_offset=true
  zap.action.action_delivery.target_effects[1].damage.amount=60
  dish.energy_source={type='electric',buffer_capacity='1600kJ',input_flow_limit='2400kW',drain='48kW',usage_priority='primary-input'}
  local records={lobber,dish,zap,projectile,ammo,{type='ammo-category',name='tech-priests-lobber-grenade'},
    {type='recipe',name=ammo.name,enabled=false,energy_required=3,
      ingredients={{type='item',name='grenade',amount=6},{type='item',name='steel-plate',amount=2}},
      results={{type='item',name=ammo.name,amount=1}}}}
  for d=0,63 do
    records[#records+1]={type='animation',name=string.format('tp-dish-electrical-%02d',d),
      filename=root..'bunker-energy-dish/'..string.format('electrical-%02d.png',d),
      width=256,height=256,frame_count=16,line_length=4,scale=g.turret_scale,shift=g.turret_shift,draw_as_glow=true}
  end
  for d=0,63 do
    for mode,frames in pairs({idle=1,entry=15,cycle=192,settle=15}) do
      for _,pass in ipairs({'beauty','emission','shadow'}) do
        local size=pass=='shadow' and 512 or 256
        records[#records+1]={type='animation',name=string.format('tp-lobber-%s-%s-%02d',mode,pass,d),
          filename=root..'bunker-lobber/'..string.format('%s-%s-%02d.png',pass,mode,d),
            width=size,height=size,frame_count=frames,line_length=mode=='cycle' and 16 or frames,
            scale=g.turret_scale,shift=g.turret_shift,
            draw_as_shadow=pass=='shadow' or nil,draw_as_glow=pass=='emission' or nil}
      end
    end
  end
  for _,t in ipairs({lobber,dish}) do
    records[#records+1]={type='item',name=t.name,icon=t.icon,icon_size=128,
      subgroup='tech-priests-bunker-weapons',order=t==lobber and 'c[lobber]' or 'e[dish]',place_result=t.name,stack_size=10}
    records[#records+1]={type='recipe',name=t.name,enabled=false,energy_required=20,
      ingredients={{type='item',name=t==lobber and 'gun-turret' or 'laser-turret',amount=1},
        {type='item',name='concrete',amount=100},{type='item',name='steel-plate',amount=100},
        {type='item',name='advanced-circuit',amount=10}},results={{type='item',name=t.name,amount=1}}}
    local effects={{type='unlock-recipe',recipe=t.name}}
    if t==lobber then effects[#effects+1]={type='unlock-recipe',recipe=ammo.name} end
    records[#records+1]={type='technology',name=t.name,icon=t.icon,icon_size=128,
      prerequisites={cannon.name,t==lobber and 'explosives' or 'laser-turret'},effects=effects,
      unit={count=200,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'military-science-pack',1}}}}
  end
  data:extend(records)
end
-- Final-fixes sees grenade capsules contributed by every loaded mod. Keep their
-- original projectile/effects (including cluster children), with real six-item
-- magazines. Capsule items remain throwable and are never changed into ammo.
function M.finalize_grenades()
  local technology=data.raw.technology['tech-priests-bunker-lobber']
  if not technology then return end
  local function is_grenade(node)
    if type(node)~='table' then return false end
    if node.type=='projectile' and node.projectile and node.projectile:lower():find('grenade',1,true) then return true end
    for _,child in pairs(node) do if type(child)=='table' and is_grenade(child) then return true end end
    return false
  end
  local function mark_shot(node)
    if type(node)~='table' then return end
    if node.type=='projectile' then
      node.max_range=math.max(node.max_range or 0,32)
      node.source_effects=node.source_effects or {}
      if node.source_effects.type then node.source_effects={node.source_effects} end
      node.source_effects[#node.source_effects+1]={type='script',effect_id='tech-priests-lobber-shot'}
      return
    end
    for _,child in pairs(node) do if type(child)=='table' then mark_shot(child) end end
  end
  local names={}
  for name,capsule in pairs(data.raw.capsule) do
    local action=capsule.capsule_action
    local attack=action and action.attack_parameters
    if action and action.type=='throw' and attack and attack.ammo_type and
        (name:lower():find('grenade',1,true) or is_grenade(attack.ammo_type)) then names[#names+1]=name end
  end
  table.sort(names)
  for _,name in ipairs(names) do
    local capsule=data.raw.capsule[name]
    local ammo_name=name=='grenade' and 'tech-priests-lobber-grenade-magazine' or 'tech-priests-lobber-'..name..'-magazine'
    local ammo=table.deepcopy(data.raw.ammo['tech-priests-lobber-grenade-magazine'])
    ammo.name=ammo_name;ammo.localised_name={'',{'item-name.'..name},' — lobber pack (6 rounds)'}
    ammo.localised_description={'item-description.tech-priests-lobber-grenade-pack'}
    ammo.icon=capsule.icon;ammo.icon_size=capsule.icon_size;ammo.icons=table.deepcopy(capsule.icons)
    ammo.ammo_type=table.deepcopy(capsule.capsule_action.attack_parameters.ammo_type)
    ammo.ammo_type.target_type='position'
    if data.raw.ammo['firearm-magazine'].ammo_category then ammo.ammo_category='tech-priests-lobber-grenade';ammo.ammo_type.category=nil
    else ammo.ammo_type.category='tech-priests-lobber-grenade' end
    mark_shot(ammo.ammo_type)
    data:extend({ammo,{type='recipe',name=ammo_name,enabled=false,energy_required=3,
      ingredients={{type='item',name=name,amount=6},{type='item',name='steel-plate',amount=2}},
      results={{type='item',name=ammo_name,amount=1}}}})
    local exists=false
    for _,effect in pairs(technology.effects) do if effect.recipe==ammo_name then exists=true end end
    if not exists then technology.effects[#technology.effects+1]={type='unlock-recipe',recipe=ammo_name} end
  end
  log('[BUNKER-FAMILY] GRENADE_TYPES '..table.concat(names,','))
end
return M
