-- Native material/power/direction/rotation/research checks, no combat simulation.
local Registry=require("scripts.core.runtime_event_registry")
local defs=require("prototypes.faction_factories").definitions
local NativeInventory=require("scripts.core.native_crafter_inventory_1277")
local INPUT=assert(NativeInventory.index(defines.inventory,"input","assembler"))
local OUTPUT=assert(NativeInventory.index(defines.inventory,"output","assembler"))
local function check(ok,message)
 if not ok then storage.factory_test.failed=message;error("[TP-FACTORIES-TEST] FAIL "..message) end
end
local function initialize()
 local surface=game.create_surface("faction-factory-proof",{width=128,height=128})
 surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities()) do if e.valid and e.type~="character" then e.destroy() end end
 local tiles={}
 for x=-30,30 do for y=-20,32 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
 surface.set_tiles(tiles);surface.daytime=0;surface.freeze_daytime=true
 surface.destroy_decoratives{area={{-40,-30},{40,40}}}
 local force=game.forces.player
 storage.factory_test={entities={},surface=surface.index,stage=0,init_tick=game.tick}
 local t=storage.factory_test
 check(force.recipes[defs[1].name].enabled,"Martian building starts unlocked")
 for index=2,3 do check(not force.recipes[defs[index].name].enabled,"researched buildings start locked") end
 force.technologies["tech-priests-guard-muster"].researched=true
 force.technologies["tech-priests-militant-orders"].researched=true
 for index,def in ipairs(defs) do
  check(force.recipes[def.name].enabled,"factory research unlocks recipe")
  for row,dir in ipairs({defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}) do
   local position={x=-12+(index-1)*12,y=-9+(row-1)*10}
   local entity=surface.create_entity{name=def.name,position=position,direction=dir,force=force}
   check(entity and entity.valid and entity.direction==dir,"native directional placement "..def.id.." requested="..dir.." actual="..tostring(entity and entity.direction))
   check(entity.prototype.crafting_categories[def.category],"exclusive faction crafting category")
   check(entity.prototype.tile_width==def.tiles and entity.prototype.tile_height==def.tiles,"native footprint")
   entity.set_recipe("tech-priests-factory-proof-"..def.id)
   entity.get_inventory(INPUT).insert{name="iron-plate",count=2}
   local electric=surface.create_entity{name="electric-energy-interface",position={position.x+6,position.y+4},force=force}
   electric.power_production=1000000000;electric.electric_buffer_size=1000000000
   surface.create_entity{name="substation",position={position.x+4,position.y+4},force=force}
   t.entities[#t.entities+1]={entity=entity,id=def.id,direction=dir,position=position,tiles=def.tiles}
  end
 end
 -- Native art reference placed at true size, not resized in a comparison panel.
 surface.create_entity{name="assembling-machine-2",position={20,-8},force=force}
 log("[TP-FACTORIES-TEST] INITIALIZED 12 actual factories; three categories; native power")
end
local session_done=false
local function tick(event)
 local t=storage.factory_test
 if not t or t.failed then return end
 if t.done then
  if not session_done then
   check(#t.entities==12,"all factory records survive reload")
   for _,r in ipairs(t.entities) do check(r.entity.valid and r.entity.direction==r.direction,"factory identity and orientation survive reload") end
   log("[TP-FACTORIES-TEST] RELOAD_PASS all factory identities and directions")
   session_done=true
  end
  if not t.animation_complete and event.tick>=t.animation_start+(t.animation_frames+1)*8 then
   for _,r in ipairs(t.entities) do check(r.entity.is_crafting(),"working FX proof uses actual active crafting") end
   local player=game.get_player(1)
   game.take_screenshot{player=player,surface=game.surfaces[t.surface],position={0,-8},resolution={1440,900},zoom=1.35,
    path=string.format("faction-factories/fx-night-%02d.png",t.animation_frames),show_gui=false,daytime=.45,force_render=true}
   game.take_screenshot{player=player,surface=game.surfaces[t.surface],position={0,-8},resolution={1440,900},zoom=1.35,
    path=string.format("faction-factories/fx-day-%02d.png",t.animation_frames),show_gui=false,daytime=0,force_render=true}
   t.animation_frames=t.animation_frames+1
   if t.animation_frames==15 then
    t.animation_complete=true
    helpers.write_file("faction-factories/animation-proof.json",helpers.table_to_json{passed=true,frames=15,tick_step=8,
     active_factories=12,working_state="engine is_crafting",light="native flicker and emissive atlas",smoke="24-frame native working animation"},false)
    log("[TP-FACTORIES-TEST] ANIMATION_PASS 12 active native factories; night flicker/smoke capture sequence")
    game.auto_save("faction-factories")
   end
  end
  return
 end
 if event.tick<t.init_tick+120 then return end
 if t.stage==0 then
 for _,r in ipairs(t.entities) do
  local entity=r.entity
  local input=entity.get_inventory(INPUT)
  local output=entity.get_inventory(OUTPUT)
  local status="unknown";for name,value in pairs(defines.entity_status) do if value==entity.status then status=name end end
  check(input.get_item_count("iron-plate")==0,"real input consumed: "..r.id.." direction="..r.direction.." status="..status.." recipe="..entity.get_recipe().name.." energy="..entity.energy)
  check(output.get_item_count("iron-stick")==4,"exact physical output: "..r.id)
  check(entity.energy>0,"native electric network powers factory")
  check(entity.direction==r.direction,"crafting retains direction")
  entity.set_recipe("tech-priests-factory-fluid-proof-"..r.id)
  input.insert{name="iron-plate",count=2}
  local dx=r.tiles%2==0 and .5 or 0
  local dy=-r.tiles/2-.5
  local theta=r.direction*math.pi/8
  local p=entity.position
  r.pipe=entity.surface.create_entity{name="pipe",position={p.x+dx*math.cos(theta)-dy*math.sin(theta),p.y+dx*math.sin(theta)+dy*math.cos(theta)},force=entity.force}
  check(r.pipe and r.pipe.valid,"real pipe at rotated reagent inlet")
  r.pipe.set_fluid(1,{name="water",amount=5})
 end
 t.stage=1;t.fluid_start=event.tick
 return
 end
 if event.tick<t.fluid_start+120 then return end
 for _,r in ipairs(t.entities) do
  local input=r.entity.get_inventory(INPUT);local output=r.entity.get_inventory(OUTPUT)
  check(input.get_item_count("iron-plate")==0 and output.get_item_count("iron-stick")==8,"second physical batch produced through real fluid inlet")
  local supplied=r.pipe.get_fluid(1);local received=r.entity.get_fluid(1)
  local remaining=(supplied and supplied.amount or 0)+(received and received.amount or 0)
  check(math.abs(remaining-4)<.001,"one water consumed from connected native pipe network")
  check(r.entity.direction==r.direction,"fluid crafting retains direction")
 end
 local player=game.get_player(1)
 if not player then return end
 player.teleport({0,3},game.surfaces[t.surface])
 for column,def in ipairs(defs) do
  game.take_screenshot{player=player,surface=game.surfaces[t.surface],position={x=-12+(column-1)*12,y=5},
   resolution={640,1600},zoom=1.15,path="faction-factories/"..def.id.."-native.png",show_gui=false,daytime=0,force_render=true}
 end
 game.take_screenshot{player=player,surface=game.surfaces[t.surface],position={0,-8},resolution={1920,1080},zoom=1.5,
  path="faction-factories/native-overview.png",show_gui=false,daytime=0,force_render=true}
 t.done=true;session_done=true
 helpers.write_file("faction-factories/result.json",helpers.table_to_json{passed=true,count=12,models=3,directions=4,
  research=true,physical_input=48,physical_output=96,physical_water_consumed=12,
  accounting_scope="completed dry/fluid proof before separate animation supplies",
  animation_iron_supplied=120,icons="deferred",combat_recipes="not implemented in this slice"},false)
 log("[TP-FACTORIES-TEST] PASS research, 12 placements, power, input debit, pipe fluid consumption and exact output")
 for _,r in ipairs(t.entities) do
  r.entity.set_recipe("tech-priests-factory-animation-proof-"..r.id)
  check(r.entity.get_inventory(INPUT).insert{name="iron-plate",count=10}==10,"separate animation stock physically supplied")
 end
 game.surfaces[t.surface].daytime=.45
 t.animation_start=game.tick;t.animation_frames=0
end
Registry.on_init(initialize,{owner="faction-factories-native-proof",route="setup",priority=1200})
Registry.on_event(defines.events.on_tick,tick,nil,{owner="faction-factories-native-proof",route="assertions",priority=2000})
