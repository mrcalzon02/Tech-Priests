-- Three original authored facilities. Unit/weapon recipes belong to the later
-- combat-roster slice. Inventory artwork is explicitly deferred by the owner.
local M={}
local PREFIX="__tech-priests__/graphics/entity/faction-factories/"
M.definitions={
 {id="martian",name="tech-priests-martian-manufactorum",category="tech-priests-recruit-mechanicus",
  tiles=4,target=1.35,power="150kW",health=1500,speed=1,enabled=true,
  ingredients={{"iron-plate",40},{"copper-plate",10},{"iron-gear-wheel",10},{"electronic-circuit",5},{"stone-brick",20}}},
 {id="guard",name="tech-priests-guard-muster-hall",category="tech-priests-recruit-guard",
  tiles=5,target=1.45,power="250kW",health=2000,speed=1.5,technology="tech-priests-guard-muster",
  ingredients={{"iron-plate",40},{"steel-plate",25},{"iron-gear-wheel",10},{"electronic-circuit",10},{"stone-brick",30}}},
 {id="sororitas",name="tech-priests-sororitas-convent",category="tech-priests-recruit-sororitas",
  tiles=6,target=2,power="800kW",health=3500,speed=2,technology="tech-priests-militant-orders",
  ingredients={{"steel-plate",100},{"advanced-circuit",20},{"battery",20},{"stone-brick",100}}},
}
local function sprite(def,direction,shadow)
 return {filename=PREFIX..def.id.."/"..direction..(shadow and "-shadow" or "")..".png",
  width=768,height=768,frame_count=1,repeat_count=24,animation_speed=.2,line_length=1,scale=.5,
  shift={0,-def.target/math.sqrt(2)},draw_as_shadow=shadow or nil}
end
local function working_fx(def,kind)
 local effect={constant_speed=true,fadeout=true,synced_fadeout=true,
  effect=kind=="glow" and "flicker" or "none",render_layer=kind=="smoke" and "smoke" or "object",
  secondary_draw_order=kind=="glow" and 10 or 0}
 for _,direction in ipairs({"north","east","south","west"}) do
  local size=kind=="smoke" and 512 or 768
  effect[direction.."_animation"]={filename=PREFIX..def.id.."/"..kind.."-"..direction..".png",
   width=size,height=size,frame_count=24,line_length=6,animation_speed=.2,
   scale=kind=="smoke" and .75 or .5,shift={0,-def.target/math.sqrt(2)},
   draw_as_glow=kind=="glow" or nil,blend_mode=kind=="glow" and "additive" or "normal"}
 end
 return effect
end
function M.register()
 local output={{type="item-subgroup",name="tech-priests-faction-production",group="tech-priests",order="f[faction-production]"}}
 local base=assert(data.raw["assembling-machine"]["assembling-machine-2"])
 for index,def in ipairs(M.definitions) do
  output[#output+1]={type="recipe-category",name=def.category}
  local entity=table.deepcopy(base)
  entity.name=def.name
  entity.localised_name={"entity-name."..def.name}
  entity.localised_description={"entity-description."..def.name}
  entity.icon="__base__/graphics/icons/assembling-machine-2.png";entity.icon_size=64;entity.icons=nil
  entity.minable={mining_time=.6,result=def.name}
  entity.max_health=def.health
  entity.fast_replaceable_group=nil;entity.next_upgrade=nil
  entity.collision_box={{-def.tiles/2+.2,-def.tiles/2+.2},{def.tiles/2-.2,def.tiles/2-.2}}
  entity.selection_box={{-def.tiles/2,-def.tiles/2},{def.tiles/2,def.tiles/2}}
  entity.tile_width=def.tiles;entity.tile_height=def.tiles
  entity.drawing_box_vertical_extension=4
  entity.crafting_categories={def.category};entity.crafting_speed=def.speed
  entity.energy_usage=def.power
  entity.energy_source={type="electric",usage_priority="secondary-input",drain="5kW",emissions_per_minute={pollution=2}}
  entity.module_slots=0;entity.allowed_effects={}
  -- A real reagent/coolant inlet supports future weapon/supply recipes and
  -- native four-way rotation, including the square 4/5/6-tile footprints.
  entity.fluid_boxes={{production_type="input",volume=100,
   pipe_picture=table.deepcopy(require("__base__.prototypes.entity.assembler-pictures").assembler2pipepictures),
   pipe_covers=pipecoverspictures(),
   pipe_connections={{flow_direction="input",direction=defines.direction.north,
    position={def.tiles%2==0 and .5 or 0,-def.tiles/2+.5}}}}}
  entity.fluid_boxes_off_when_no_fluid_recipe=false
  entity.water_reflection=nil;entity.graphics_set_flipped=nil
  -- A genuine 24-frame main cycle advances the working layers in Factorio.
  -- Static body/shadow repeat without duplicating atlas pixels. Idle omits smoke.
  entity.graphics_set={animation={},idle_animation={}}
  for _,direction in ipairs({"north","east","south","west"}) do
   entity.graphics_set.idle_animation[direction]={layers={sprite(def,direction,false),sprite(def,direction,true)}}
   entity.graphics_set.animation[direction]={layers={sprite(def,direction,false),sprite(def,direction,true),working_fx(def,"smoke")[direction.."_animation"]}}
  end
  local light={effect="flicker",constant_speed=true,fadeout=true,
   light={intensity=.55,size=6,color=def.id=="guard" and {r=.75,g=.8,b=1} or {r=1,g=.58,b=.22},minimum_darkness=.05}}
  local light_pos=def.id=="sororitas" and {0,-2.2,1.8} or {0,-1.3,1.8}
  for i,direction in ipairs({"north","east","south","west"}) do
   local theta=-(i-1)*math.pi/2
   local x=light_pos[1]*math.cos(theta)-light_pos[2]*math.sin(theta)
   local y=light_pos[1]*math.sin(theta)+light_pos[2]*math.cos(theta)
   light[direction.."_position"]={x,-(y+light_pos[3])/math.sqrt(2)}
  end
  entity.graphics_set.working_visualisations={working_fx(def,"glow"),light}
  entity.match_animation_speed_to_activity=false
  output[#output+1]=entity
  output[#output+1]={type="item",name=def.name,localised_name={"entity-name."..def.name},
   icon=entity.icon,icon_size=64,subgroup="tech-priests-faction-production",order=tostring(index),
   place_result=def.name,stack_size=10}
  local ingredients={}
  for _,item in ipairs(def.ingredients) do ingredients[#ingredients+1]={type="item",name=item[1],amount=item[2]} end
  output[#output+1]={type="recipe",name=def.name,localised_name={"entity-name."..def.name},
   enabled=def.enabled==true,energy_required=10,ingredients=ingredients,
   results={{type="item",name=def.name,amount=1}}}
 end
 local icon="__tech-priests__/graphics/icons/tech-priests-category.png"
 output[#output+1]={type="technology",name="tech-priests-guard-muster",icon=icon,icon_size=64,
  prerequisites={"steel-processing"},effects={{type="unlock-recipe",recipe="tech-priests-guard-muster-hall"}},
  unit={count=50,time=15,ingredients={{"automation-science-pack",1}}},order="c-m-f-a"}
 output[#output+1]={type="technology",name="tech-priests-militant-orders",icon=icon,icon_size=64,
  prerequisites={"chemical-science-pack","military-2","battery","advanced-circuit"},
  effects={{type="unlock-recipe",recipe="tech-priests-sororitas-convent"}},
  unit={count=200,time=30,ingredients={{"automation-science-pack",1},{"logistic-science-pack",1},
   {"military-science-pack",1},{"chemical-science-pack",1}}},order="c-m-f-b"}
 data:extend(output)
end
return M
