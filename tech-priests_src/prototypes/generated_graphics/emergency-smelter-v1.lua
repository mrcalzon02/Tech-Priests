-- Actual fixed-north1x1 burner furnace; visual fields only.
local e=assert(data.raw.furnace['tech-priests-emergency-smelter'])
local p='__tech-priests__/graphics/entity/emergency-smelter-v1/'
local function animation(name)
 return{layers={{filename=p..'shadow.png',width=512,height=512,frame_count=1,repeat_count=24,draw_as_shadow=true,scale=.15,shift={0,-.5/math.sqrt(2)}},{filename=p..name,width=512,height=512,frame_count=24,line_length=6,animation_speed=.8,scale=.15,shift={0,-.5/math.sqrt(2)}}}}
end
e.graphics_set={animation=animation('working.png'),idle_animation=animation('idle.png'),always_draw_idle_animation=false,working_visualisations={{light={intensity=.35,size=2,color={1,.22,.04}},position={0,.18},effect='flicker',fadeout=true}}}
e.working_visualisations=nil;e.integration_patch=nil;e.water_reflection=nil
-- World-sprite projection of the real chimney outlet, with no extra smoke height.
for _,smoke in pairs(e.energy_source.smoke or{})do smoke.position={.20,-.285-1.175/math.sqrt(2)};smoke.height=0 end
local y=-.289-.59/math.sqrt(2)
local connection={points={wire={red={-.275,y},green={-.195,y}},shadow={red={-.275,-.289},green={-.195,-.289}}}}
e.circuit_connector={table.deepcopy(connection),table.deepcopy(connection),table.deepcopy(connection),table.deepcopy(connection)}
for _,v in ipairs({e,data.raw.item['tech-priests-emergency-smelter'],data.raw.recipe['tech-priests-emergency-smelter']})do v.icon=p..'icon.png';v.icon_size=128;v.icons=nil end

-- Existing recipes declare up to eight item results. A one-slot furnace cannot
-- auto-select even ordinary smelting after the mod's zero-chance detritus result
-- is appended. Match existing recipe capacity; keep all recipes/rates unchanged.
e.result_inventory_size=8
