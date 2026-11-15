-- Heavy lane defence: native cannon ammunition, two alternating breeches.
local M={}
local NAME='tech-priests-bunker-twin-cannon'
local FIRE='tp-twin-cannon-fire'
local BORN='tp-twin-cannon-projectile-born'
local function contains(node,id)
  if type(node)~='table' then return false end
  if node.effect_id==id then return true end
  for _,child in pairs(node) do if type(child)=='table' and contains(child,id) then return true end end
  return false
end
local function append_effect(old,new)
  if not old then return {new} end
  if old.type then return {old,new} end
  local result=table.deepcopy(old);result[#result+1]=new;return result
end
function M.register(mod_name,options)
  if data.raw['ammo-turret'][NAME] then return end
  options=options or {};local placeholder=options.headless==true
  local stock=assert(data.raw['ammo-turret']['gun-turret'])
  local foundation=data.raw['ammo-turret']['tech-priests-bunker-autocannon']
  assert(foundation or placeholder,'The cannon requires the family bunker foundation')
  local t=table.deepcopy(foundation or stock)
  local path='__'..mod_name..'__/graphics/entity/bunker-twin-cannon/'
  t.name=NAME;t.localised_name={'entity-name.'..NAME};t.localised_description={'entity-description.'..NAME}
  t.icon=placeholder and '__base__/graphics/icons/tank-cannon.png' or path..'icon.png';t.icon_size=placeholder and 64 or 128;t.icons=nil
  t.minable={mining_time=1.5,result=NAME};t.max_health=3000
  t.collision_box={{-1.4,-1.4},{1.4,1.4}};t.selection_box={{-1.5,-1.5},{1.5,1.5}};t.tile_width=3;t.tile_height=3
  t.rotation_speed=.004;t.turret_base_has_direction=true;t.random_animation_offset=false
  t.circuit_connector=nil;t.circuit_wire_max_distance=nil;t.water_reflection=nil;t.integration=nil
  t.attack_parameters=table.deepcopy(data.raw.gun['tank-cannon'].attack_parameters)
  t.attack_parameters.cooldown=t.attack_parameters.cooldown/2
  t.attack_parameters.range=36;t.attack_parameters.min_range=8;t.attack_parameters.damage_modifier=1
  t.attack_parameters.shell_particle=nil
  t.starting_attack_animation=nil;t.ending_attack_animation=nil;t.attacking_speed=1
  t.attack_from_start_frame=false
  t.start_attacking_only_when_can_shoot=true;t.leave_attacking_if_shoot_fails=false
  local function native()
    if placeholder then return {filename='__core__/graphics/empty.png',width=1,height=1,frame_count=1,direction_count=1} end
    local stripes={};for d=0,63 do stripes[#stripes+1]={filename=path..string.format('native-%02d.png',d),width_in_frames=1,height_in_frames=1} end
    return {width=256,height=256,frame_count=1,direction_count=64,stripes=stripes,scale=.774999976158,shift={0,-1.110906519093},apply_projection=true}
  end
  for _,state in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'}) do t[state]=native() end
  local subgroup=data.raw['item-subgroup']['tech-priests-bunker-weapons'] and 'tech-priests-bunker-weapons' or 'gun'
  local records={t,
    {type='item',name=NAME,icon=t.icon,icon_size=t.icon_size,subgroup=subgroup,order='h[twin-cannon]',place_result=NAME,stack_size=10},
    {type='recipe',name=NAME,enabled=false,energy_required=30,ingredients={
      {type='item',name='gun-turret',amount=2},{type='item',name='concrete',amount=150},{type='item',name='steel-plate',amount=150},
      {type='item',name='engine-unit',amount=20},{type='item',name='iron-gear-wheel',amount=30},{type='item',name='advanced-circuit',amount=20}},
      results={{type='item',name=NAME,amount=1}}},
    {type='technology',name=NAME,icon=t.icon,icon_size=t.icon_size,prerequisites={'tank','concrete'},effects={{type='unlock-recipe',recipe=NAME}},
      unit={count=300,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'military-science-pack',1},{'chemical-science-pack',1}}}}
  }
  for i,variation in ipairs(data.raw.explosion['explosion-gunshot'].animations) do
    local animation=table.deepcopy(variation)
    animation.type='animation';animation.name='tp-twin-cannon-native-muzzle-'..i
    records[#records+1]=animation
  end
  if not placeholder and not options.native_preview_only then
    local headings=options.capture_headings or {};if not options.capture_headings then for d=0,63 do headings[#headings+1]=d end end
    for _,d in ipairs(headings) do
      for mode,frames in pairs({idle=1,single0=40,single1=40,overlap0=18,overlap1=18}) do
        records[#records+1]={type='animation',name=string.format('tp-twin-cannon-%s-body-%02d',mode,d),
          filename=path..string.format('%s-body-%02d.png',mode,d),
          width=256,height=256,frame_count=frames,line_length=mode=='idle' and 1 or (frames==40 and 8 or 6),
          scale=.774999976158,shift={0,-1.110906519093}}
      end
      for bank=0,1 do
        records[#records+1]={type='animation',name=string.format('tp-twin-cannon-aerial%d-%02d',bank,d),
          filename=path..string.format('aerial%d-%02d.png',bank,d),width=256,height=256,frame_count=25,line_length=5,
          scale=.774999976158,shift={0,-1.110906519093}}
      end
      records[#records+1]={type='animation',name=string.format('tp-twin-cannon-shadow-%02d',d),filename=path..string.format('shadow-%02d.png',d),
        width=512,height=512,frame_count=1,scale=.774999976158,shift={0,-1.110906519093},draw_as_shadow=true}
      -- Native flame artwork is registered once above for controlled rotation.
    end
  end
  data:extend(records)
end
function M.finalize()
  if not data.raw['ammo-turret'][NAME] then return end
  local touched={}
  local function mark_flash(node)
    if type(node)~='table' then return end
    if node.entity_name=='explosion-gunshot' and (node.type=='create-explosion' or node.type=='create-entity') then
      node.type='create-entity';node.trigger_created_entity=true
    end
    for _,child in pairs(node) do if type(child)=='table' then mark_flash(child) end end
  end
  local function hook(node)
    if type(node)~='table' then return end
    if node.type=='projectile' and node.projectile then
      mark_flash(node.source_effects)
      if not contains(node.source_effects,FIRE) then node.source_effects=append_effect(node.source_effects,{type='script',effect_id=FIRE}) end
      touched[node.projectile]=true
    end
    for key,child in pairs(node) do if type(child)=='table' and key~='source_effects' then hook(child) end end
  end
  for _,ammo in pairs(data.raw.ammo) do if ammo.ammo_category=='cannon-shell' then hook(ammo.ammo_type) end end
  for name in pairs(touched) do
    local projectile=assert(data.raw.projectile[name],name)
    if not contains(projectile.created_effect,BORN) then
      projectile.created_effect=append_effect(projectile.created_effect,{type='direct',action_delivery={type='instant',target_effects={type='script',effect_id=BORN}}})
    end
  end
end
return M
