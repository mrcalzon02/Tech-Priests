-- Real graphical Factorio 2.1 client screenshot fixture for APPROVED V22C.
-- This file lives only in a per-run isolated test mod, never the release.
-- The ONLY capture mechanism is Factorio's native game.take_screenshot.
local DIRECTIONS={
  {"north",defines.direction.north},
  {"east",defines.direction.east},
  {"south",defines.direction.south},
  {"west",defines.direction.west}
}
local STATES={"idle","working"}
local ZOOMS={{"normal",1.0},{"close",2.7}}
local NAME="tech-priests-atmospheric-water-condenser"
local RECIPE="tech-priests-atmospheric-water-condensing"
local PREFIX="TP_CONDENSER_V22C_GUI "
local EXPECTED_OUTPUT={
  -- Independent front-row pipe offsets from the actual four Blender views.
  -- Not calculated from the fluidbox: this must reject the old rear-row bug.
  north={x=1.5,y=0.5},
  east={x=-0.5,y=1.5},
  south={x=-1.5,y=-0.5},
  west={x=0.5,y=-1.5}
}
local function near(a,b) return math.abs(a-b)<0.001 end
local function ensure(condition,reason)
  if not condition then error(PREFIX.."FAIL "..reason,0) end
end
local function clear_area(surface,center)
  -- Controlled identical pads (not eight unrelated random-world scenes).
  -- 49x49 concrete tiles cover the entire 1.0x screenshot viewport.
  local tiles={}
  for y=-24,24 do
    for x=-24,24 do
      tiles[#tiles+1]={name="concrete",position={center.x+x,center.y+y}}
    end
  end
  surface.set_tiles(tiles,true)
  local area={{center.x-25,center.y-25},{center.x+25,center.y+25}}
  for _,item in pairs(surface.find_entities_filtered{area=area}) do
    if item.valid and (item.type=="tree" or item.type=="cliff" or
      item.type=="simple-entity" or item.type=="resource") then
      item.destroy()
    end
  end
  if surface.destroy_decoratives then
    surface.destroy_decoratives{area=area}
  end
end
script.on_init(function()
  local surface=assert(game.surfaces[1],"Missing native test surface")
  ensure(prototypes.entity[NAME]~=nil,"Missing production V22C condenser")
  ensure(prototypes.recipe[RECIPE]~=nil,"Missing production water recipe")
  local locations={}
  -- Separate empty native terrain cells; no production saves or user entities.
  for st,state in ipairs(STATES) do
    for d,orientation in ipairs(DIRECTIONS) do
      local center={x=192+72*(d-1),y=192+72*(st-1)}
      surface.request_to_generate_chunks(center,2)
      locations[#locations+1]={center=center,state=state,facing=orientation[1],
        direction=orientation[2]}
    end
  end
  surface.force_generate_chunk_requests()
  local shots={}
  local machines,pipes,working=0,0,0
  for _,site in ipairs(locations) do
    clear_area(surface,site.center)
    local machine=surface.create_entity{
      name=NAME,position=site.center,direction=site.direction,
      force=game.forces.player,raise_built=false
    }
    ensure(machine and machine.valid,"Machine placement "..site.facing..site.state)
    ensure(machine.direction==site.direction,"Engine changed rotation "..site.facing)
    ensure(machine.set_recipe(RECIPE),"Cannot select genuine condenser water recipe")
    ensure(machine.get_recipe() and machine.get_recipe().name==RECIPE,
      "Selected wrong production recipe")
    local connections=machine.get_fluid_box_pipe_connections(1)
    ensure(type(connections)=="table" and #connections==1,
      "Expected one genuine native output socket")
    local port=connections[1]
    ensure(port.target_position and port.flow_direction=="output",
      "No native output pipe target")
    local expected=assert(EXPECTED_OUTPUT[site.facing],
      "Missing authored flange orientation")
    local physical={x=site.center.x+expected.x,y=site.center.y+expected.y}
    ensure(near(port.target_position.x,physical.x) and
           near(port.target_position.y,physical.y),
      "VISUAL_FLANGE_PORT_MISMATCH "..site.facing..
      " expected="..physical.x..","..physical.y..
      " engine="..port.target_position.x..","..port.target_position.y)
    -- Place the pipe at the independently specified sprite flange coordinate,
    -- NOT wherever the defective prototype happens to report its socket.
    local pipe=surface.create_entity{
      name="pipe",position=physical,force=game.forces.player,
      raise_built=false
    }
    ensure(pipe and pipe.valid,"Pipe placement failed "..site.facing..site.state)
    local linked=machine.get_fluid_box_pipe_connections(1)
    ensure(linked and #linked==1 and linked[1].target==pipe,
      "Engine did not connect real output pipe")
    local neighbor=false
    for _,record in pairs(machine.get_fluid_box_neighbours(1) or {}) do
      if record.entity==pipe then neighbor=true end
    end
    ensure(neighbor,"Engine reported no real pipe neighbor")
    machines=machines+1;pipes=pipes+1
    if site.state=="working" then
      local burner=machine.burner
      ensure(burner and burner.inventory,"Genuine fuel burner unavailable")
      local accepted=burner.inventory.insert{name="coal",count=30}
      ensure(accepted>0,"Condenser could not accept actual coal fuel")
      working=working+1
    end
    for _,zoom in ipairs(ZOOMS) do
      shots[#shots+1]={
        center=site.center,facing=site.facing,state=site.state,
        zoom_name=zoom[1],zoom=zoom[2],
        path="condenser-v22c/"..site.facing.."-"..site.state.."-"..zoom[1]..".png"
      }
    end
  end
  ensure(machines==8 and pipes==8 and working==4 and #shots==16,
    "Native setup counts wrong")
  storage.condenser_v22c_gui={next_shot=0,shots=shots}
  log(PREFIX.."NATIVE_WORLD_PASS condensers=8 connected_pipes=8 fueled=4 screenshots=16 independent_front_flange_positions=4 controlled_concrete_pads=8")
end)
script.on_nth_tick(60,function(event)
  local state=storage.condenser_v22c_gui
  if not state then return end
  local index=state.next_shot+1
  if index>#state.shots then return end
  local shot=state.shots[index]
  game.take_screenshot{
    surface=game.surfaces[1],
    position=shot.center,
    resolution={x=1152,y=864},
    zoom=shot.zoom,
    path=shot.path,
    show_gui=false,
    show_entity_info=false,
    anti_alias=true,
    force_render=true,
    daytime=0.0, -- noon; 0.5 is midnight and hides the approved piston/mist detail
    hide_clouds=true,
    hide_fog=true
  }
  state.next_shot=index
  log(PREFIX.."SCREENSHOT_REQUEST "..index.."/16 "..shot.path..
    " tick="..event.tick)
  if index==#state.shots then
    game.set_wait_for_screenshots_to_finish()
    log(PREFIX.."SCREENSHOT_QUEUE_COMPLETE count=16")
  end
end)
