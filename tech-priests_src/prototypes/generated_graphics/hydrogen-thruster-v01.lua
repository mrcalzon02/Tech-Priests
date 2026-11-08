-- Authored hydrogen model V01: drawing-only registration, after legacy rescaling.
local p=data.raw.thruster and data.raw.thruster['hydrogen-thruster']
if not p or not p.graphics_set then return end
local base='__tech-priests__/graphics/entity/hydrogen-thruster-v01/'
local function animation(state,emission)
 return {filename=base..'hydrogen-thruster-v01-'..state..(emission and '-emission' or '')..'.png',width=512,height=768,line_length=7,frame_count=7,animation_speed=0.18,scale=0.375,shift={-2.98023223876953e-08,1.31840550899506},draw_as_glow=emission or false,blend_mode=emission and 'additive' or 'normal'}
end
local function body(state)
 return {north={layers={animation(state,false),{filename=base..'hydrogen-thruster-v01-shadow.png',width=768,height=1024,frame_count=1,repeat_count=7,animation_speed=0.18,scale=0.375,shift={-2.98023223876953e-08,1.31840550899506},draw_as_shadow=true}}}}
end
p.graphics_set.idle_animation=body('idle')
p.graphics_set.animation=body('run')
p.graphics_set.always_draw_idle_animation=false
p.graphics_set.animation_random_start_frame=false
p.drawing_box={{-2.65,-2.95},{2.65,5.25}}
p.graphics_set.working_visualisations=p.graphics_set.working_visualisations or {}
local thermal={name='hydrogen-v01-thermal-glow',always_draw=false,animation=animation('run',true)}
local existing=nil
for i,v in ipairs(p.graphics_set.working_visualisations) do if v.name==thermal.name then existing=i end end
if existing then p.graphics_set.working_visualisations[existing]=thermal else p.graphics_set.working_visualisations[#p.graphics_set.working_visualisations+1]=thermal end
