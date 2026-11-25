-- Hydrogen V03: source-pinned Pipette assembly, full source cone and native trail.
local p=data.raw.thruster and data.raw.thruster['hydrogen-thruster']
local donor=data.raw.thruster and data.raw.thruster.thruster
if not(p and donor and p.graphics_set and donor.graphics_set)then return end
local base='__tech-priests__/graphics/entity/hydrogen-thruster-v03/'
local function translate(value,delta,seen)
 if type(value)~='table'then return end;seen=seen or{};if seen[value]then return end;seen[value]=true
 if type(value.shift)=='table'then local x,y=value.shift[1]or value.shift.x,value.shift[2]or value.shift.y;if type(x)=='number'and type(y)=='number'then value.shift={x+delta[1],y+delta[2]}end end
 for k,v in pairs(value)do if k~='shift'then translate(v,delta,seen)end end
end
local deltas={}
for _,entry in ipairs({{p.fuel_fluid_box,-1.5},{p.oxidizer_fluid_box,1.5}})do
 local box,x=entry[1],entry[2];assert(box and #box.pipe_connections==1)
 local c=box.pipe_connections[1];local old=c.position
 for _,name in pairs(c.enable_working_visualisations or{})do deltas[name]={x-(old[1]or old.x),.5-(old[2]or old.y)}end
 c.position={x,.5}
end
local g=p.graphics_set;local kept={}
for _,visual in ipairs(g.working_visualisations or{})do if deltas[visual.name]then translate(visual,deltas[visual.name]);kept[#kept+1]=visual end end
local function animation(kind)
 return{filenames={base..kind..'-1.png',base..kind..'-2.png'},width=512,height=1536,line_length=8,lines_per_file=4,frame_count=64,animation_speed=.5,scale=0.375,shift={-2.98023223876953e-08,2.31840550899506}}
end
local shadow=animation('shadow');shadow.width=398;shadow.height=186;shadow.shift={0.292968720197678,-0.0253444910049438};shadow.draw_as_shadow=true
local cold={filename=base..'idle-body.png',width=512,height=1536,frame_count=1,repeat_count=64,animation_speed=.5,scale=0.375,shift={-2.98023223876953e-08,2.31840550899506}}
local cold_shadow={filename=base..'idle-shadow.png',width=398,height=186,frame_count=1,repeat_count=64,animation_speed=.5,scale=0.375,shift={0.292968720197678,-0.0253444910049438},draw_as_shadow=true}
g.animation={north={layers={animation('body'),shadow}}}
g.idle_animation={north={layers={cold,cold_shadow}}}
g.always_draw_idle_animation=false;g.animation_random_start_frame=false
local heat=animation('heat-glow');heat.draw_as_glow=true;heat.blend_mode='additive'
kept[#kept+1]={name='hydrogen-v03-full-source-cone-heat',fadeout=true,animation={layers={heat}}}
g.working_visualisations=kept
for _,key in ipairs({'flame_effect','flame_half_height','flame_effect_width','flame_effect_height','flame_effect_offset'})do g[key]=table.deepcopy(donor.graphics_set[key])end
-- Owner width revision: narrow the separate native effect, preserving the baked blue cone.
local trail_width_factor=0.5
g.flame_effect_width=g.flame_effect_width*trail_width_factor
-- Native trail starts aft of all 64 actual physical near-lips plus .14 tile.
g.flame_position={-1.862645149230957e-08,6.406509890556335+(g.flame_effect_offset or 0)}
p.plumes=table.deepcopy(donor.plumes)
for _,plume in ipairs(p.plumes.stateless_visualisations)do
 for _,key in ipairs({'offset_x','speed_x'})do
  for i,value in ipairs(plume[key])do plume[key][i]=value*trail_width_factor end
 end
 plume.animation.scale=(plume.animation.scale or 1)*trail_width_factor
end
p.collision_box={{-1.85,-1.85},{1.85,.95}}
p.drawing_box={{-2.65,-2.95},{2.875,42.5}}
local icon='__tech-priests__/graphics/icons/hydrogen-thruster-v03-icon.png'
p.icon=icon;p.icons=nil;p.icon_size=64
local item=data.raw.item and data.raw.item['hydrogen-thruster']
if item then item.icon=icon;item.icons=nil;item.icon_size=64 end
