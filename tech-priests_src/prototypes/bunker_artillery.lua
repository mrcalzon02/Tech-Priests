-- Native artillery combat with a source-pose revolving-breech mechanism.
local M={}
local NAME='tech-priests-bunker-artillery'
local GEOMETRY=require('scripts.artillery_barrage_geometry')
M.name=NAME;M.gun=NAME..'-gun'
local function heading(orientation)
  local a=orientation*2*math.pi
  return math.floor((math.atan2(math.sin(a),math.cos(a)*math.sqrt(2))/(2*math.pi)%1)*64+.5)%64
end
local function muzzle_heading(d)
  local p=GEOMETRY.muzzle;local a=math.pi-d*2*math.pi/64
  return {p[1]*math.cos(a)-p[2]*math.sin(a),-(p[1]*math.sin(a)+p[2]*math.cos(a)+p[3])/math.sqrt(2)}
end
function M.muzzle(orientation)return muzzle_heading(heading(orientation))end
function M.register(mod_name,options)
  if data.raw['artillery-turret'][NAME] then return end
  options=options or {}
  local visuals=require('scripts.artillery_barrage_visuals')
  assert(options.animation_pilot or visuals.complete,'Complete every animation heading before production registration')
  local foundation=assert(data.raw['ammo-turret']['tech-priests-bunker-autocannon'],'Actual bunker foundation required')
  local path='__'..mod_name..'__/graphics/entity/bunker-artillery/'
  local t=table.deepcopy(data.raw['artillery-turret']['artillery-turret'])
  t.name=NAME;t.localised_name={'entity-name.'..NAME}
  t.localised_description={'entity-description.'..NAME}
  t.icon=path..'icon.png';t.icon_size=128;t.icons=nil
  t.minable={mining_time=2,result=NAME};t.max_health=3000
  t.collision_box={{-1.4,-1.4},{1.4,1.4}};t.selection_box={{-1.5,-1.5},{1.5,1.5}};t.tile_width=3;t.tile_height=3
  t.circuit_connector=nil;t.circuit_wire_max_distance=nil;t.water_reflection=nil
  local base=foundation.base_picture or foundation.graphics_set.base_visualisation.animation
  t.base_picture=table.deepcopy(base.north)
  t.cannon_base_shift={0,0,0}
  -- No static cap is composited over the moving cage. The complete source
  -- mechanism, including its bearing, is drawn by the paid-shot controller.
  t.cannon_base_pictures={filename='__core__/graphics/empty.png',width=1,height=1,direction_count=1}
  t.cannon_barrel_pictures={filename='__core__/graphics/empty.png',width=1,height=1,direction_count=1}
  t.cannon_barrel_recoil_shiftings=nil;t.cannon_barrel_light_direction=nil
  t.cannon_parking_frame_count=1;t.cannon_parking_speed=1
  local gun=table.deepcopy(data.raw.gun['artillery-wagon-cannon']);gun.name=M.gun
  gun.localised_name={'item-name.'..M.gun};gun.icon=t.icon;gun.icon_size=t.icon_size;gun.icons=nil
  gun.attack_parameters.cooldown=gun.attack_parameters.cooldown*.45
  gun.attack_parameters.damage_modifier=1
  gun.attack_parameters.projectile_center={0,0};gun.attack_parameters.projectile_creation_distance=0
  gun.attack_parameters.apply_projection_to_projectile_creation_position=false
  gun.attack_parameters.projectile_creation_parameters={}
  -- Artillery selects this LUT using its already projected sprite orientation.
  -- One entry per captured heading avoids a second projection and a duplicate
  -- 1.0 endpoint (which skews native circular indexing).
  for d=0,63 do gun.attack_parameters.projectile_creation_parameters[#gun.attack_parameters.projectile_creation_parameters+1]={d/64,muzzle_heading(d)}end
  t.gun=gun.name
  local records={t,gun,
    {type='item',name=NAME,icon=t.icon,icon_size=128,subgroup=data.raw['item-subgroup']['tech-priests-bunker-weapons'] and 'tech-priests-bunker-weapons' or 'gun',order='j[bunker-artillery]',place_result=NAME,stack_size=5},
    {type='recipe',name=NAME,enabled=false,energy_required=40,ingredients={{type='item',name='artillery-turret',amount=1},
      {type='item',name='concrete',amount=150},{type='item',name='steel-plate',amount=100},{type='item',name='engine-unit',amount=20},
      {type='item',name='advanced-circuit',amount=30}},results={{type='item',name=NAME,amount=1}}},
    {type='technology',name=NAME,icon=t.icon,icon_size=128,prerequisites={'artillery','concrete'},effects={{type='unlock-recipe',recipe=NAME}},
      unit={count=400,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'military-science-pack',1},{'chemical-science-pack',1},{'production-science-pack',1}}}}}
  for key,layers in pairs(visuals.headings)do
    for layer,record in pairs(layers)do
      records[#records+1]={type='animation',name=string.format('tp-artillery-%s-%02d',layer,tonumber(key)),
        filename=path..record.file,width=record.width,height=record.height,line_length=record.line_length,frame_count=record.frame_count,
        scale=record.scale,shift=record.shift,flags={'always-compressed'},draw_as_shadow=layer=='shadow'}
    end
  end
  data:extend(records)
end
function M.finalize()
  if not data.raw['artillery-turret'][NAME]then return end
  local function hook(node)
    if type(node)~='table' then return end
    if node.type=='artillery' then node.trigger_fired_artillery=true end
    for _,child in pairs(node) do if type(child)=='table' then hook(child)end end
  end
  for _,ammo in pairs(data.raw.ammo) do if ammo.ammo_category=='artillery-shell' then hook(ammo.ammo_type)end end
end
return M
