-- Fixed-north 6x6 Orbital Trader: art and native-pod visuals only.
local e=assert(data.raw['assembling-machine']['orbital-trader'])
local prefix='__tech-priests__/graphics/entity/orbital-trader-v1/'
local shift=-1.15/math.sqrt(2)
local function image(file,frames)
 return{filename=prefix..file,width=512,height=512,frame_count=frames,line_length=frames==1 and 1 or 8,repeat_count=frames==1 and 32 or 1,animation_speed=9.6/60,scale=.75,shift={0,shift}}
end
e.graphics_set={idle_animation=image('body-idle.png',1),animation=image('body-working.png',32),always_draw_idle_animation=false}
e.working_visualisations=nil;e.integration_patch=nil;e.water_reflection=nil
local y=2.321-1.08/math.sqrt(2)
local connection={points={wire={red={1.52,y},green={2.28,y}},shadow={red={1.52,2.321},green={2.28,2.321}}}}
e.circuit_connector={table.deepcopy(connection),table.deepcopy(connection),table.deepcopy(connection),table.deepcopy(connection)}
for _,p in ipairs({e,data.raw.item['orbital-trader'],data.raw.recipe['orbital-trader']})do p.icon=prefix..'icon.png';p.icon_size=128;p.icons=nil end
local function hatch(name,file,offset)
 return{type='animation',name=name,filename=prefix..file,width=512,height=512,frame_count=21,line_length=7,animation_speed=1,scale=.75,shift={0,shift+(offset or 0)}}
end
data:extend({hatch('tp-orbital-hatch-back-v1','hatch-back.png'),hatch('tp-orbital-hatch-front-v1','hatch-front.png',-3),{type='sprite',name='tp-orbital-front-wall-mask-v1',filename=prefix..'front-wall-mask.png',width=512,height=512,scale=.75,shift={0,shift-3}}})
-- Reuse the complete existing native pod and landing procession. Only this
-- owned empty visual instance omits impact damage; the vanilla pod is unchanged.
local pod=table.deepcopy(assert(data.raw['cargo-pod']['cargo-pod']))
pod.name='tp-orbital-native-cargo-pod';pod.impact_trigger=nil;pod.hidden_in_factoriopedia=true
data:extend({pod})
