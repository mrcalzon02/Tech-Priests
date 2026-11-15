-- Six native rockets, staggered by the engine; the owner inserts reload pauses.
local M={}
local NAME='tech-priests-bunker-rocket-salvo'
M.fire_effect='tp-rocket-salvo-fire';M.born_effect='tp-rocket-salvo-born'
local function contains(node,id)
  if type(node)~='table' then return false end
  if node.effect_id==id then return true end
  for _,v in pairs(node) do if type(v)=='table' and contains(v,id) then return true end end
  return false
end
local function append(old,new)
  if not old then return {new} end
  if old.type then return {old,new} end
  local result=table.deepcopy(old);result[#result+1]=new;return result
end
function M.register(mod_name,options)
  if data.raw['ammo-turret'][NAME] then return end
  options=options or {}
  assert(not options.headless,'Rocket combat prototypes require the actual bunker art')
  local foundation=assert(data.raw['ammo-turret']['tech-priests-bunker-autocannon'],'Rocket turret requires the family foundation')
  local t=table.deepcopy(foundation)
  local path='__'..mod_name..'__/graphics/entity/bunker-rocket-salvo/'
  t.name=NAME;t.localised_name={'','Fortified six-cell rocket salvo'}
  t.localised_description={'','Six native rockets, ten ticks apart, followed by a cassette reload. Base cycle: four seconds. Uses existing rocket ammunition.'}
  t.icon=path..'icon.png';t.icon_size=128;t.icons=nil
  t.minable={mining_time=1.5,result=NAME};t.max_health=2500
  t.collision_box={{-1.4,-1.4},{1.4,1.4}};t.selection_box={{-1.5,-1.5},{1.5,1.5}}
  t.tile_width=3;t.tile_height=3;t.rotation_speed=.007
  t.attack_parameters=table.deepcopy(data.raw.gun['rocket-launcher'].attack_parameters)
  t.attack_parameters.cooldown=10;t.attack_parameters.range=36;t.attack_parameters.min_range=8
  t.attack_parameters.damage_modifier=1;t.attack_parameters.ammo_consumption_modifier=1
  t.attack_parameters.shell_particle=nil
  t.attack_from_start_frame=false;t.attacking_speed=1
  t.start_attacking_only_when_can_shoot=true;t.leave_attacking_if_shoot_fails=false
  t.starting_attack_animation=nil;t.ending_attack_animation=nil
  t.circuit_connector=nil;t.circuit_wire_max_distance=nil;t.water_reflection=nil
  local headings=options.capture_headings
  if not headings then headings={};for d=0,63 do headings[#headings+1]=d end end
  local function nearest(d)
    local best,dist=headings[1],65
    for _,h in ipairs(headings) do local delta=math.abs(d-h);delta=math.min(delta,64-delta);if delta<dist then best,dist=h,delta end end
    return best
  end
  local function native()
    local stripes={};for d=0,63 do stripes[#stripes+1]={filename=path..string.format('native-%02d.png',nearest(d)),width_in_frames=1,height_in_frames=1}end
    return {width=256,height=256,frame_count=1,direction_count=64,stripes=stripes,
      scale=.774999976158,shift={0,-1.110906519093},apply_projection=true}
  end
  for _,state in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'}) do
    t[state]=native()
  end
  local records={t,
    {type='item',name=NAME,icon=t.icon,icon_size=t.icon_size,subgroup=data.raw['item-subgroup']['tech-priests-bunker-weapons'] and 'tech-priests-bunker-weapons' or 'gun',order='i[rocket-salvo]',place_result=NAME,stack_size=10},
    {type='recipe',name=NAME,enabled=false,energy_required=30,ingredients={
      {type='item',name='rocket-launcher',amount=2},{type='item',name='concrete',amount=150},
      {type='item',name='steel-plate',amount=120},{type='item',name='engine-unit',amount=12},
      {type='item',name='iron-gear-wheel',amount=30},{type='item',name='advanced-circuit',amount=20}},
      results={{type='item',name=NAME,amount=1}}},
    {type='technology',name=NAME,icon=t.icon,icon_size=t.icon_size,prerequisites={'rocketry','concrete'},
      effects={{type='unlock-recipe',recipe=NAME}},unit={count=250,time=30,
        ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'military-science-pack',1},{'chemical-science-pack',1}}}}}
  do
    for _,d in ipairs(headings) do
      for mode,frames in pairs({idle=1,reload=95}) do records[#records+1]={type='animation',name=string.format('tp-rocket-%s-body-%02d',mode,d),
        filename=path..string.format('%s-body-%02d.png',mode,d),width=256,height=256,frame_count=frames,line_length=frames==1 and 1 or 8,
        scale=.774999976158,shift={0,-1.110906519093}}end
      records[#records+1]={type='animation',name=string.format('tp-rocket-noses-%02d',d),filename=path..string.format('noses-%02d.png',d),
        width=256,height=256,frame_count=6,line_length=6,scale=.774999976158,shift={0,-1.110906519093}}
      for mode,frames in pairs({idle=1,reload=95}) do
        local cell=options.shadow_cell or (options.static_shadow_pilot and 512 or 256)
        records[#records+1]={type='animation',name=string.format('tp-rocket-%s-shadow-%02d',mode,d),
          filename=path..(options.static_shadow_pilot and string.format('shadow-%02d.png',d) or string.format('%s-shadow-%02d.png',mode,d)),
          width=cell,height=cell,frame_count=options.static_shadow_pilot and 1 or frames,
          line_length=options.static_shadow_pilot and 1 or (frames==1 and 1 or 8),
          scale=.774999976158*512/cell,shift={0,-1.110906519093},draw_as_shadow=true}
      end
    end
  end
  data:extend(records)
end
function M.finalize()
  local touched={}
  local function hook(node)
    if type(node)~='table' then return end
    if node.type=='projectile' and node.projectile then
      local function tag_fx(fx)
        if type(fx)~='table' then return end
        if fx.type=='create-entity' and fx.entity_name=='explosion-hit' then fx.trigger_created_entity=true end
        for _,v in pairs(fx) do if type(v)=='table' then tag_fx(v) end end
      end
      tag_fx(node.source_effects)
      if not contains(node.source_effects,M.fire_effect) then
        node.source_effects=append(node.source_effects,{type='script',effect_id=M.fire_effect})
      end
      touched[node.projectile]=true
    end
    for k,v in pairs(node) do if type(v)=='table' and k~='source_effects' then hook(v) end end
  end
  for _,ammo in pairs(data.raw.ammo) do if ammo.ammo_category=='rocket' then hook(ammo.ammo_type) end end
  for name in pairs(touched) do
    local projectile=assert(data.raw.projectile[name],name)
    if not contains(projectile.created_effect,M.born_effect) then
      projectile.created_effect=append(projectile.created_effect,{type='direct',action_delivery={type='instant',
        target_effects={type='script',effect_id=M.born_effect}}})
    end
  end
end
return M
