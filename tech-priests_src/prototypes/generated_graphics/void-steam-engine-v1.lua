-- Void Steam Engine authored generator art. Native 2x2, two orientations.
local target=assert(data.raw.generator["void-steam-engine"],"actual Void generator")
local prefix="__tech-priests__/graphics/entity/void-steam-engine-v1/"
local function animation(facing)
 return {filename=prefix..facing.."-working.png",width=256,height=256,frame_count=32,line_length=8,animation_speed=8/60,scale=.5,shift={0,-0.428712661841}}
end
-- Factorio2.1 uses GeneratorPrototype.pictures; inherited base art must be replaced.
target.pictures={north={animation=animation("north")},east={animation=animation("east")}}
-- Native animation-only control: stopped output must stop the mechanism.
-- https://lua-api.factorio.com/2.1.24/types/PerceivedPerformance.html
target.perceived_performance=table.deepcopy(target.perceived_performance or {})
target.perceived_performance.minimum=0
target.horizontal_animation=nil;target.vertical_animation=nil
target.horizontal_frozen_patch=nil;target.vertical_frozen_patch=nil
target.water_reflection=nil
-- Retain native steam smoke behavior, with the emitter seated on the open exhaust.
for _,smoke in ipairs(target.smoke or {}) do
 smoke.north_position={0.82,-1.84975342585};smoke.east_position={0.82,-0.209753425849};smoke.deviation={.015,.015}
end
for _,prototype in ipairs({target,data.raw.item["void-steam-engine"],data.raw.recipe["void-steam-engine"]}) do
 if prototype then prototype.icon=prefix.."icon.png";prototype.icon_size=64;prototype.icons=nil end
end
