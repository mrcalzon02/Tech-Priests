-- Authored V04 source35. Native source SHA256: 539d6cef7d8e00d5e13967d26817578c1d654ad1cdb7df373dabbe352f659583
-- Local Blender body, independent heat map and projected geometry shadow.
local p=data.raw.thruster and data.raw.thruster['thetazine-thruster']
local donor=data.raw.thruster and data.raw.thruster.thruster
if not (p and donor and p.graphics_set and donor.graphics_set) then return end
local base='__tech-priests__/graphics/entity/thetazine-thruster-v04/'
local function animation(kind)
 return {filenames={base..kind..'-1.png',base..kind..'-2.png'},width=512,height=1280,line_length=8,lines_per_file=4,frame_count=64,animation_speed=.5,scale=.46875,shift={-3.725290298461914e-08,2.8901551961898804}}
end
local workingShadow={filenames={base..'shadow-1.png',base..'shadow-2.png'},width=398,height=394,line_length=8,lines_per_file=4,frame_count=64,animation_speed=.5,scale=.46875,shift={0.366210900247097,-0.31785261631011963},draw_as_shadow=true}
local coldBody={filename=base..'idle-body.png',width=512,height=1280,frame_count=1,repeat_count=64,scale=.46875,shift={-3.725290298461914e-08,2.8901551961898804}}
local coldShadow={filename=base..'idle-shadow.png',width=398,height=394,frame_count=1,repeat_count=64,scale=.46875,shift={0.366210900247097,-0.31785261631011963},draw_as_shadow=true}
local g=p.graphics_set
g.animation={north={layers={animation('body'),workingShadow}}}
g.idle_animation={north={layers={coldBody,coldShadow}}}
g.always_draw_idle_animation=false;g.animation_random_start_frame=false
local kept={}
for _,v in ipairs(g.working_visualisations or {}) do
 if v.name=='platform-service-underlay' then
  v.animation={filename=base..'underlay.png',width=512,height=1280,scale=.46875,shift={-3.725290298461914e-08,2.8901551961898804}};kept[#kept+1]=v
 elseif v.enabled_by_name then kept[#kept+1]=v end
end
local heat=animation('heat-glow');heat.draw_as_glow=true;heat.blend_mode='additive'
kept[#kept+1]={name='v04-separate-heat-glow',fadeout=true,animation={layers={heat}}}
g.working_visualisations=kept
for _,key in ipairs({'flame_effect','flame_half_height','flame_effect_width','flame_effect_height','flame_effect_offset'}) do g[key]=table.deepcopy(donor.graphics_set[key]) end
-- Measured from the installed donor alpha, not a redistributed game sprite.
local a=donor.graphics_set.animation;local shift=a.shift or {0,0}
local donorLip=(531-a.height/2)*a.scale/32+(shift[2] or shift.y or 0)
local join={9.336508810520172e-07,8.420409533835482}
g.flame_position={join[1],join[2]-(donorLip-donor.graphics_set.flame_position[2])}
p.plumes=table.deepcopy(donor.plumes)
p.drawing_box={{-4,-5},{4,42}}
