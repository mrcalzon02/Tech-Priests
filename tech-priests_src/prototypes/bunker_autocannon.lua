-- Original 3x3 bunker cannon. Native ammo, targeting, turning and inserter supply.
local M = {}
local NAME = 'tech-priests-bunker-autocannon'
local AMMO = 'tech-priests-autocannon-magazine'
local CATEGORY = 'tech-priests-autocannon'
local PROJECTILE = 'tech-priests-autocannon-projectile'

local function damage(node, seen)
  if type(node) ~= 'table' then return 0 end
  if node.type == 'damage' then return node.damage.amount end
  local total = 0
  if node.type == 'projectile' and node.projectile and not seen[node.projectile] then
    seen[node.projectile] = true
    local projectile = assert(data.raw.projectile[node.projectile], node.projectile)
    total = damage(projectile.action, seen)
  end
  for key, child in pairs(node) do
    if type(child) == 'table' and key ~= 'source_effects' then total = total + damage(child, seen) end
  end
  return total
end

function M.finalize()
  local turret = data.raw['ammo-turret'][NAME]
  if not turret then return end
  local gun = assert(data.raw['ammo-turret']['gun-turret']).attack_parameters
  local cannon = assert(data.raw.gun['tank-cannon']).attack_parameters
  -- Harmonic mean of cooldowns = arithmetic mean of SHOTS PER SECOND.
  local cooldown = 2 / (1 / gun.cooldown + 1 / cannon.cooldown)
  -- Native cooldowns are rounded up to whole simulation ticks. Use the
  -- integral firing interval plus native per-magazine reload time so the
  -- measured average, not merely the tooltip, is the requested midpoint.
  local shot_ticks = math.floor(cooldown)
  turret.attack_parameters.cooldown = shot_ticks
  turret.attacking_speed = 1 / shot_ticks -- complete the recoil cycle between shots
  local rifle_ammo = assert(data.raw.ammo['firearm-magazine'])
  local shell = assert(data.raw.ammo['cannon-shell'])
  local hit = (damage(rifle_ammo.ammo_type, {}) + damage(shell.ammo_type, {})) / 2
  assert(hit > 0)
  data.raw.projectile[PROJECTILE].action.action_delivery.target_effects[1].damage.amount = hit

  local magazine_size = rifle_ammo.magazine_size * 2
  local reload_ticks = (cooldown - shot_ticks) * magazine_size
  assert(math.abs(reload_ticks-math.floor(reload_ticks+0.5))<1e-6,
    'Midpoint cadence must resolve to integral native reload ticks')
  data.raw.ammo[AMMO].magazine_size = magazine_size
  data.raw.ammo[AMMO].reload_time = math.floor(reload_ticks+0.5)
  -- Compare equal numbers of rounds, not differently sized magazines.
  local donor = assert(data.raw.recipe['firearm-magazine'])
  local recipe = data.raw.recipe[AMMO]
  recipe.ingredients = table.deepcopy(assert(donor.ingredients))
  for _, ingredient in pairs(recipe.ingredients) do
    local resource_factor = 2 * magazine_size / rifle_ammo.magazine_size
    if ingredient.amount then ingredient.amount = ingredient.amount * resource_factor
    else ingredient[2] = ingredient[2] * resource_factor end
  end
  local output = 0
  for _, result in pairs(donor.results or {}) do
    if result.name == 'firearm-magazine' then
      assert(not result.probability or result.probability == 1, 'Rifle batch must be deterministic')
      output = output + assert(result.amount)
    end
  end
  if output == 0 and donor.result == 'firearm-magazine' then output = donor.result_count or 1 end
  assert(output > 0, 'Missing rifle ammunition output')
  recipe.results = {{type='item', name=AMMO, amount=output}}
  for _, result in pairs(donor.results or {}) do
    if result.name ~= 'firearm-magazine' then
      recipe.results[#recipe.results+1] = table.deepcopy(result)
    end
  end
end

function M.register(mod_name)
  if data.raw['ammo-turret'][NAME] then return end
  local g = require('prototypes.bunker_autocannon_graphics')
  local path = '__' .. mod_name .. '__/graphics/entity/bunker-autocannon/'
  local icon = path .. 'icon.png'
  local function top(firing)
    local stripes = {}
    for d=0,(firing and 63 or 7) do
      stripes[#stripes+1] = {filename=path .. string.format(firing and 'firing-%02d.png' or 'idle-%02d.png',d),
        width_in_frames=firing and 32 or 1, height_in_frames=firing and 1 or 8}
    end
    return {width=g.cell,height=g.cell,frame_count=firing and 32 or 1,direction_count=64,
      stripes=stripes,scale=g.turret_scale,shift=g.turret_shift,apply_projection=true,
      animation_speed=1}
  end
  local base = {}
  for _,direction in ipairs({'north','east','south','west'}) do
    local function layer(suffix, shadow, glow)
      return {filename=path .. 'base-' .. direction .. suffix .. '.png',width=g.base_size,height=g.base_size,
        scale=g.base_scale,shift=g.base_shift,draw_as_shadow=shadow or nil,draw_as_glow=glow or nil}
    end
    base[direction] = {layers={layer('-shadow',true),layer(''),layer('-glow',false,true)}}
  end
  local turret=table.deepcopy(assert(data.raw['ammo-turret']['gun-turret']))
  turret.name=NAME;turret.icon=icon;turret.icon_size=128;turret.icons=nil
  turret.localised_name={'entity-name.' .. NAME};turret.localised_description={'entity-description.' .. NAME}
  turret.minable={mining_time=1,result=NAME};turret.max_health=2000
  turret.corpse='big-remnants';turret.dying_explosion='big-explosion'
  turret.collision_box={{-1.4,-1.4},{1.4,1.4}};turret.selection_box={{-1.5,-1.5},{1.5,1.5}}
  turret.tile_width=3;turret.tile_height=3;turret.fast_replaceable_group='tech-priests-bunker'
  turret.drawing_box_vertical_extension=2;turret.rotation_speed=0.005
  turret.turret_base_has_direction=true;turret.random_animation_offset=false
  turret.attack_from_start_frame=false;turret.start_attacking_only_when_can_shoot=true
  turret.preparing_speed=1;turret.folding_speed=1;turret.preparing_sound=nil;turret.folding_sound=nil
  turret.folded_animation=top(false);turret.preparing_animation=top(false)
  turret.prepared_animation=top(false);turret.folding_animation=top(false);turret.attacking_animation=top(true)
  turret.starting_attack_animation=nil;turret.ending_attack_animation=nil
  turret.integration=nil;turret.water_reflection=nil;turret.circuit_connector=nil;turret.circuit_wire_max_distance=nil
  if data.raw['ammo-turret']['gun-turret'].graphics_set then
    turret.graphics_set={base_visualisation={animation=base,render_layer='lower-object'}}
    turret.base_picture=nil
  else turret.graphics_set=nil;turret.base_picture=base end
  turret.attack_parameters=table.deepcopy(data.raw.gun['tank-cannon'].attack_parameters)
  turret.attack_parameters.ammo_category=CATEGORY
  turret.attack_parameters.range=24;turret.attack_parameters.min_range=0
  turret.attack_parameters.projectile_center={0,-1.45};turret.attack_parameters.projectile_creation_distance=2.05
  turret.attack_parameters.damage_modifier=1;turret.attack_parameters.shell_particle=nil
  turret.inventory_size=1;turret.automated_ammo_count=10

  local ammo=table.deepcopy(data.raw.ammo['firearm-magazine'])
  ammo.name=AMMO;ammo.localised_name={'item-name.' .. AMMO};ammo.localised_description={'item-description.' .. AMMO}
  ammo.icon='__base__/graphics/icons/cannon-shell.png';ammo.icon_size=64;ammo.icons=nil
  ammo.subgroup='tech-priests-bunker-weapons';ammo.order='b[autocannon-rounds]'
  ammo.ammo_type={target_type='entity',action={type='direct',action_delivery={type='projectile',
    projectile=PROJECTILE,starting_speed=1,direction_deviation=0,range_deviation=0,max_range=32}}}
  if data.raw.ammo['firearm-magazine'].ammo_category then ammo.ammo_category=CATEGORY
  else ammo.ammo_type.category=CATEGORY end
  local projectile=table.deepcopy(data.raw.projectile['cannon-projectile'])
  projectile.name=PROJECTILE;projectile.piercing_damage=nil;projectile.final_action=nil
  projectile.collision_box={{-0.05,-0.15},{0.05,0.15}}
  projectile.action={type='direct',action_delivery={type='instant',target_effects={
    {type='damage',damage={amount=552.5,type='physical'}},
    {type='create-entity',entity_name='explosion-hit'}}}}
  if projectile.animation then projectile.animation.scale=0.25 end
  local ammo_recipe=table.deepcopy(data.raw.recipe['firearm-magazine'])
  ammo_recipe.name=AMMO;ammo_recipe.enabled=false;ammo_recipe.results={{type='item',name=AMMO,amount=1}}
  ammo_recipe.result=nil;ammo_recipe.result_count=nil;ammo_recipe.main_product=AMMO
  ammo_recipe.icons=nil;ammo_recipe.icon=nil;ammo_recipe.icon_size=nil
  ammo_recipe.localised_name={'item-name.' .. AMMO}
  data:extend({
    {type='ammo-category',name=CATEGORY,localised_name={'ammo-category-name.' .. CATEGORY}},
    {type='item-subgroup',name='tech-priests-bunker-weapons',group=data.raw['item-group']['tech-priests'] and 'tech-priests' or 'combat',order='f[bunker-weapons]'},
    turret,ammo,projectile,ammo_recipe,
    {type='item',name=NAME,icon=icon,icon_size=128,subgroup='tech-priests-bunker-weapons',order='a[bunker-autocannon]',place_result=NAME,stack_size=10},
    {type='recipe',name=NAME,enabled=false,energy_required=20,ingredients={
      {type='item',name='gun-turret',amount=1},{type='item',name='concrete',amount=100},
      {type='item',name='steel-plate',amount=100},{type='item',name='iron-gear-wheel',amount=20},
      {type='item',name='advanced-circuit',amount=10}},results={{type='item',name=NAME,amount=1}}},
    {type='technology',name=NAME,icon=icon,icon_size=128,prerequisites={'military-3','concrete'},
      unit={count=200,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'military-science-pack',1}}},
      effects={{type='unlock-recipe',recipe=NAME},{type='unlock-recipe',recipe=AMMO}},order='e-b-a'}
  })
  M.finalize()
end

return M
