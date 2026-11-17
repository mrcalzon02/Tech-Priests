-- Authored closed Citadel cathedral. Actual fixed-north 5x5 platform assembler.
local target=assert(data.raw["assembling-machine"]["citadel-manufactoreo"],"actual Citadel prototype")
local prefix="__tech-priests__/graphics/entity/citadel-manufactoreo-v1/"
local function picture(file,frames)
 return {filename=prefix..file,width=512,height=512,frame_count=frames,repeat_count=frames==1 and 32 or 1,line_length=frames==1 and 1 or 8,animation_speed=8/60,scale=.625,shift={0,-1.1313708499}}
end
target.graphics_set={idle_animation=picture("north-idle.png",1),animation=picture("north-working.png",32),always_draw_idle_animation=false}
target.working_visualisations=nil;target.integration_patch=nil;target.water_reflection=nil
-- Native red/green terminals sit on the console's right-hand interface.
-- This preserves the existing circuit behavior/reach and adds no copper socket.
-- Source console's upper two seated control heads provide the terminals.
-- Projection: native X = model X; native Y = -model Y - model Z/sqrt(2).
-- No inherited crusher connector sprite floats over the cathedral roof.
local connector={points={wire={red={-1.58060241774,1.5392782916},green={-1.47785547352,1.53927831027}},shadow={red={-1.58060241774,2.22363851202},green={-1.47785547352,2.22363851202}}}}
target.circuit_connector={table.deepcopy(connector),table.deepcopy(connector),table.deepcopy(connector),table.deepcopy(connector)}
for _,prototype in ipairs({target,data.raw.item["citadel-manufactoreo"],data.raw.recipe["citadel-manufactoreo"]})do
 if prototype then prototype.icon=prefix.."icon.png";prototype.icon_size=64;prototype.icons=nil end
end
