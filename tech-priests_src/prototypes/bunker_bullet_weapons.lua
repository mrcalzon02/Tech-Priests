-- Original quad burst and paired rotary prototypes. Ordinary bullet magazines.
local M={}
function M.register(mod_name)
  if data.raw['ammo-turret']['tech-priests-bunker-chicago-piano'] then return end
  local stock=assert(data.raw['ammo-turret']['gun-turret'])
  local bunker=assert(data.raw['ammo-turret']['tech-priests-bunker-autocannon'])
  local g=require('prototypes.bunker_autocannon_graphics')
  local base='__'..mod_name..'__/graphics/entity/'
  local records={}
  for _,variant in ipairs({'chicago-piano','twin-minigun'}) do
    local name='tech-priests-bunker-'..variant
    local path=base..'bunker-'..variant..'/'
    local frames=variant=='chicago-piano' and 24 or 18
    local function native()
      local stripes={}
      for d=0,63 do stripes[#stripes+1]={filename=path..string.format('native-%02d.png',d),width_in_frames=1,height_in_frames=1} end
      return {width=256,height=256,frame_count=1,direction_count=64,stripes=stripes,
        -- Match the controller's map-to-45-degree-camera heading projection.
        scale=g.turret_scale,shift=g.turret_shift,apply_projection=true}
    end
    local t=table.deepcopy(bunker)
    t.name=name;t.icon=path..'icon.png';t.icon_size=128;t.icons=nil
    t.localised_name={'entity-name.'..name};t.localised_description={'entity-description.'..name}
    t.minable={mining_time=1,result=name};t.rotation_speed=stock.rotation_speed
    t.attack_parameters=table.deepcopy(stock.attack_parameters)
    t.attack_parameters.shell_particle=nil
    t.attack_parameters.cooldown=variant=='chicago-piano' and data.raw.gun['submachine-gun'].attack_parameters.cooldown or stock.attack_parameters.cooldown
    if variant=='twin-minigun' then
      t.attack_parameters.ammo_consumption_modifier=2*(stock.attack_parameters.ammo_consumption_modifier or 1)
      t.attack_parameters.damage_modifier=2*(stock.attack_parameters.damage_modifier or 1)
    end
    t.attacking_speed=1;t.attack_from_start_frame=false
    t.start_attacking_only_when_can_shoot=true;t.leave_attacking_if_shoot_fails=false
    t.starting_attack_animation=nil;t.ending_attack_animation=nil
    for _,state in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'}) do t[state]=native() end
    records[#records+1]=t
    for d=0,63 do
      for _,mode in ipairs({'idle','cycle'}) do
        for _,pass in ipairs({'body','fx','shadow'}) do
          local count=mode=='idle' or pass=='shadow' and 1 or frames
          if mode=='idle' then count=1 end
          local size=pass=='shadow' and 512 or 256
          records[#records+1]={type='animation',name=string.format('tp-%s-%s-%s-%02d',variant,mode,pass,d),
            filename=path..string.format(mode=='idle' and 'idle-%s-%02d.png' or '%s-%02d.png',pass,d),
            width=size,height=size,frame_count=count,line_length=count==1 and 1 or 6,
            scale=g.turret_scale,shift=g.turret_shift,
            draw_as_shadow=pass=='shadow' or nil,draw_as_glow=pass=='fx' or nil}
        end
      end
    end
    records[#records+1]={type='item',name=name,icon=t.icon,icon_size=128,
      subgroup='tech-priests-bunker-weapons',order='g['..variant..']',place_result=name,stack_size=10}
    records[#records+1]={type='recipe',name=name,enabled=false,energy_required=20,
      ingredients={{type='item',name='gun-turret',amount=variant=='chicago-piano' and 4 or 2},
        {type='item',name='concrete',amount=100},{type='item',name='steel-plate',amount=100},
        {type='item',name='iron-gear-wheel',amount=20},{type='item',name='advanced-circuit',amount=10}},
      results={{type='item',name=name,amount=1}}}
    records[#records+1]={type='technology',name=name,icon=t.icon,icon_size=128,
      prerequisites={'military-3','concrete'},
      effects={{type='unlock-recipe',recipe=name}},
      unit={count=200,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'military-science-pack',1}}}}
  end
  data:extend(records)
end
function M.finalize()
  -- Ordinary bullet magazines carry their own stock muzzle explosion.
  -- Request its creation callback so the controller can suppress it only
  -- for our two mounts, while stock guns keep their normal effect.
  local function mark_muzzle(node,source)
    if type(node)~='table' then return end
    if source and (node.type=='create-explosion' or node.type=='create-entity') and node.entity_name=='explosion-gunshot' then
      -- create-explosion uses the render-only path and does not deliver
      -- the creation callback. The entity path preserves the same visual
      -- for stock weapons and supplies the originating gun to our filter.
      node.type='create-entity'
      node.trigger_created_entity=true
    end
    for key,child in pairs(node) do
      if type(child)=='table' then mark_muzzle(child,source or key=='source_effects') end
    end
  end
  for _,ammo in pairs(data.raw.ammo) do mark_muzzle(ammo.ammo_type,false) end
  -- Stock bullet research has a separate gun-turret bonus in addition to
  -- the general ammunition bonus. Preserve that relationship for both caps.
  for _,technology in pairs(data.raw.technology) do
    local additions={}
    for _,effect in ipairs(technology.effects or {}) do
      if effect.type=='turret-attack' and effect.turret_id=='gun-turret' then
        for _,name in ipairs({'tech-priests-bunker-chicago-piano','tech-priests-bunker-twin-minigun'}) do
          local found=false
          for _,existing in ipairs(technology.effects) do
            if existing.type=='turret-attack' and existing.turret_id==name and existing.modifier==effect.modifier then found=true end
          end
          if not found then local copy=table.deepcopy(effect);copy.turret_id=name;additions[#additions+1]=copy end
        end
      end
    end
    for _,effect in ipairs(additions) do technology.effects[#technology.effects+1]=effect end
  end
end
return M
