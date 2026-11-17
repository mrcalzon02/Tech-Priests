-- Closed fragment-burning 3x3 reliquary. Art-only integration.
local target=assert(data.raw["burner-generator"]["entropic-extractor"])
local prefix="__tech-priests__/graphics/entity/entropic-extractor-v1/"
local function sprite(direction,state,frames)
 return {filename=prefix..direction.."-"..state..".png",width=512,height=512,frame_count=frames,repeat_count=frames==1 and 32 or 1,line_length=frames==1 and 1 or 8,animation_speed=8/60,scale=.375,shift={0,-.707106781187}}
end
local function four(state,frames)
 return {north=sprite("north",state,frames),east=sprite("east",state,frames),south=sprite("south",state,frames),west=sprite("west",state,frames)}
end
target.idle_animation=four("idle",1)
target.animation=four("working",32)
target.always_draw_idle_animation=false
for _,p in ipairs({target,data.raw.item["entropic-extractor"],data.raw.recipe["entropic-extractor"]})do
 p.icon=prefix.."icon.png";p.icon_size=64;p.icons=nil
end
