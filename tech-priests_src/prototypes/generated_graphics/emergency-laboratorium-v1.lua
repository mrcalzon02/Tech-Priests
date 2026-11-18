-- One-tile fixed-north burner research lab: graphics and real terminal positions.
local e=assert(data.raw.lab['tech-priests-emergency-laboratorium'])
local p='__tech-priests__/graphics/entity/emergency-laboratorium-v1/'
local function animation(name)
 return{layers={{filename=p..'shadow.png',width=512,height=512,frame_count=1,repeat_count=24,draw_as_shadow=true,scale=.15,shift={0,-.5/math.sqrt(2)}},{filename=p..name,width=512,height=512,frame_count=24,line_length=6,animation_speed=.2,scale=.15,shift={0,-.5/math.sqrt(2)}}}}
end
e.on_animation=animation('working.png');e.off_animation=animation('idle.png');e.frozen_patch=nil;e.water_reflection=nil
-- Burner glow is at the actual firebox, not the sprite center.
e.light={intensity=.3,size=1.6,color={1,.22,.04},shift={-.31,.324-.169/math.sqrt(2)},flicker_interval=12,flicker_min_modifier=.85,flicker_max_modifier=1,offset_flicker=true}
local y=-.260-.736/math.sqrt(2)
e.circuit_connector={points={wire={red={-.27,y},green={-.18,y}},shadow={red={-.27,-.260},green={-.18,-.260}}}}
for _,v in ipairs({e,data.raw.item['tech-priests-emergency-laboratorium'],data.raw.recipe['tech-priests-emergency-laboratorium']})do v.icon=p..'icon.png';v.icon_size=128;v.icons=nil end
