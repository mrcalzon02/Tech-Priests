-- Native effects only. Energy beam actions and projectile impacts own their damage once.
local M={}
local P='tech-priests-arsenal-'
local colors={galvanic={.9,.75,.35},las={1,.12,.06},bolt={1,.65,.25},radium={.2,1,.35},
 gamma={.65,.25,1},magnarail={.5,.85,1},volkite={1,.35,.06},arc={.25,.65,1},graviton={.6,.4,1}}
local function tint(node,color)
 if type(node)~='table' then return end
 if node.filename then
  node.filename=node.filename:gsub('/laser%-body%.png','/laser-body-light.png'):gsub('/laser%-end%.png','/laser-end-light.png')
 end
 if node.filename or node.filenames or node.stripes then node.tint=color end
 for _,child in pairs(node) do if type(child)=='table' then tint(child,color) end end
end
local function direct(effects) return {type='direct',action_delivery={type='instant',target_effects=effects}} end
local function damage(rows)
 local result={}
 for _,row in ipairs(rows) do result[#result+1]={type='damage',damage={amount=row[1],type=row[2]}} end
 return result
end
function M.register(supplies)
 local records={}
 for key,color in pairs(colors) do
  local beam=table.deepcopy(data.raw.beam[key=='arc' and 'electric-beam-no-sound' or 'laser-beam'])
  beam.working_sound=nil
  beam.name=P..key..'-beam';beam.action=nil;beam.action_triggered_automatically=false
  for _,supply in pairs(supplies) do
   if supply.effect==key and supply.delivery~='projectile' then beam.action=direct(M.payload(supply)) end
  end
  beam.width=key=='graviton' and .8 or (key=='volkite' and .6 or .18)
  tint(beam.graphics_set,color)
  records[#records+1]=beam
 end
 local slow={type='sticker',name=P..'gravity-slow',flags={'not-on-map'},duration_in_ticks=90,
  target_movement_modifier=.5,vehicle_speed_modifier=.5}
 records[#records+1]=slow
 for id,supply in pairs(supplies) do
  if supply.delivery=='projectile' then
   local shot=table.deepcopy(data.raw.projectile.laser)
   shot.name=P..id..'-shot';shot.acceleration=0;shot.animation.tint=colors[supply.effect]
   if supply.effect~='radium' then
    shot.animation={filename='__base__/graphics/entity/bullet/bullet.png',width=3,height=50,
     draw_as_glow=true,tint=colors[supply.effect],scale=supply.effect=='bolt' and 1.1 or .35}
   end
   shot.action=direct(M.payload(supply));records[#records+1]=shot
  end
 end
 data:extend(records)
end
function M.payload(supply)
 local effects=damage(supply.damage)
 effects[#effects+1]={type='create-entity',entity_name=supply.impact or 'small-explosion-hit'}
 if supply.splash then
  effects[#effects+1]={type='nested-result',action={type='area',radius=supply.splash.radius,
   force='enemy',action_delivery={type='instant',target_effects=damage(supply.splash.damage)}}}
 end
 if supply.slow then effects[#effects+1]={type='create-sticker',sticker=P..'gravity-slow'} end
 return effects
end
function M.ammo_type(id,supply)
 local delivery
 if supply.delivery=='projectile' then
  delivery={type='projectile',projectile=P..id..'-shot',starting_speed=supply.speed,
   max_range=100}
 elseif supply.effect=='melee' then
  delivery={type='instant',target_effects=M.payload(supply)}
 else
  delivery={type='beam',beam=P..supply.effect..'-beam',duration=supply.duration or 8,source_offset={0,-.5}}
 end
 return {target_type='entity',action={type='direct',action_delivery=delivery}}
end
return M
