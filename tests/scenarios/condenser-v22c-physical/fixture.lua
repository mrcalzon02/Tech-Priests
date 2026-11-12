-- Isolated native Factorio 2.1 physical alignment acceptance for source-locked
-- Blender V22C. This fixture is NEVER shipped inside the public mod.
-- Four real 2x2 entities, four real pipe entities, engine-provided fluid
-- connections only: no fabricated graphics/connection pixels or mock ports.
local M={}
local PREFIX="[TP-CONDENSER-V22C-PHYSICAL] "
local KEY="ci_condenser_v22c_physical"
local CONDENSER="tech-priests-atmospheric-water-condenser"
local RECIPE="tech-priests-atmospheric-water-condensing"
local DIRECTIONS={
  {name="north", direction=defines.direction.north,x=0,y=0},
  {name="east", direction=defines.direction.east,x=18,y=0},
  {name="south", direction=defines.direction.south,x=0,y=18},
  {name="west", direction=defines.direction.west,x=18,y=18},
}
local function emit(message) log(PREFIX..message) end
local function fail(message) error(PREFIX.."FAIL "..message,0) end
local function near(a,b) return math.abs(a-b)<0.001 end
local function clear_test_area(surface,center)
  local tiles={}
  local left,right=center.x-6,center.x+6
  local top,bottom=center.y-6,center.y+6
  for x=left,right do for y=top,bottom do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{
    area={{left-1,top-1},{right+1,bottom+1}}
  }) do
    if e.valid and (e.type=="tree" or e.type=="cliff" or
        e.type=="simple-entity" or e.type=="resource") then
      e.destroy()
    end
  end
end
local function run()
  local surface=game.surfaces[1]
  local force=game.forces.player
  if not (prototypes.entity[CONDENSER] and
      prototypes.recipe[RECIPE] and prototypes.entity.pipe) then
    fail("MISSING_ORIGINAL_PROTOTYPES")
  end
  local machines,pipes={},{}
  for _,spec in ipairs(DIRECTIONS) do
    local center={x=spec.x,y=spec.y}
    clear_test_area(surface,center)
    local machine=surface.create_entity{
      name=CONDENSER, position=center, direction=spec.direction,
      force=force,raise_built=false
    }
    if not(machine and machine.valid) then
      fail("CREATE_2X2_MACHINE_"..spec.name)
    end
    if machine.direction~=spec.direction then
      fail("MACHINE_DIRECTION_CHANGED_"..spec.name)
    end
    local selected=machine.set_recipe(RECIPE)
    local recipe=machine.get_recipe()
    if not(selected and recipe and recipe.name==RECIPE) then
      fail("CONVERTER_FLUID_RECIPE_NOT_SELECTED_"..spec.name)
    end
    local fluid_prototype=machine.get_fluid_box_prototype(1)
    local connections=machine.get_fluid_box_pipe_connections(1)
    if not(fluid_prototype and type(connections)=="table" and
        #connections==1) then
      fail("OUTPUT_FLUIDBOX_COUNT_"..spec.name)
    end
    local c=connections[1]
    local p=c.target_position
    if not(c.flow_direction=="output" and c.connection_type=="normal"
      and p and type(p.x)=="number" and type(p.y)=="number"
      and not c.target) then
      fail("PRECONNECT_OUTPUT_POINT_"..spec.name)
    end
    -- The intended output is on the rotated exterior, never inside the 2x2.
    if math.abs(p.x-center.x)<0.75 and
       math.abs(p.y-center.y)<0.75 then
      fail("OUTPUT_PIPE_INSIDE_MACHINE_"..spec.name)
    end
    if not surface.can_place_entity{
      name="pipe",position=p,force=force
    } then
      fail("OUTPUT_PIPE_SITE_OCCUPIED_"..spec.name.."_"..p.x.."_"..p.y)
    end
    local pipe=surface.create_entity{
      name="pipe",position=p,force=force,raise_built=false
    }
    if not(pipe and pipe.valid) then
      fail("NATIVE_PIPE_NOT_CREATED_"..spec.name)
    end
    local after=machine.get_fluid_box_pipe_connections(1)
    local neighbours=machine.get_fluid_box_neighbours(1)
    if not(after and #after==1 and after[1].target==pipe) then
      fail("NATIVE_PIPE_NOT_CONNECTED_"..spec.name)
    end
    local linked=false
    for _,entry in pairs(neighbours or {}) do
      if entry.entity==pipe then linked=true end
    end
    if not linked then
      fail("NATIVE_FLUIDBOX_NEIGHBOUR_MISSING_"..spec.name)
    end
    -- 2.1 fluid segments are NOT created synchronously with on_init entity
    -- placement. Actual LuaEntity pipe target + independent neighbour identity
    -- above establish a native physical link. Check segment identity only when
    -- the engine reports an existing segment; never invent water or a segment.
    local machine_has_segment=machine.has_fluid_segment(1)
    local pipe_has_segment=pipe.has_fluid_segment(1)
    -- A physical 2.1 output joins before the whole network finalizes.
    -- On the native creation tick one endpoint can have a segment while the
    -- other is still building its segment. That is NOT a broken pipe link.
    -- Native target and neighbour identity above remain the hard gate.
    local machine_segment=0
    local segment_state="unformed"
    if machine_has_segment~=pipe_has_segment then
      segment_state="forming"
    elseif machine_has_segment and pipe_has_segment then
      machine_segment=machine.get_fluid_segment_id(1)
      local pipe_segment=pipe.get_fluid_segment_id(1)
      if not(machine_segment and pipe_segment and machine_segment==pipe_segment) then
        fail("FORMED_FLUID_SEGMENT_NOT_SHARED_"..spec.name)
      end
      segment_state="formed"
    end
    local pp=after[1].target_position
    if not(near(p.x,pp.x) and near(p.y,pp.y)) then
      fail("PIPE_SOCKET_MOVED_ON_CONNECT_"..spec.name)
    end
    machines[#machines+1]=machine.unit_number
    pipes[#pipes+1]=pipe.unit_number
    emit(string.format(
      "NATIVE_CONNECTED facing=%s machine=%d pipe=%d source_x=%.3f source_y=%.3f target_x=%.3f target_y=%.3f segment=%d segment_state=%s",
      spec.name,machine.unit_number,pipe.unit_number,
      center.x,center.y,p.x,p.y,machine_segment,segment_state
    ))
  end
  local checked={}
  for _,id in ipairs(machines)do
    if checked[id] then fail("DUPLICATE_MACHINE_ID") end
    checked[id]=true
  end
  for _,id in ipairs(pipes)do
    if checked[id] then fail("DUPLICATE_PIPE_ID") end
    checked[id]=true
  end
  emit("PASS four original 2x2 V22C condensers with native direction-rotated output pipes")
end
function M.install()
  -- A native save creation always has a real on_init lifecycle, whereas
  -- headless benchmark ticks can skip the central work broker during startup.
  -- Register on the canonical owner-keyed lifecycle; never install an extra
  -- script.on_tick or a parallel event scheduler.
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not(registry and registry.on_init) then
    fail("CANONICAL_NATIVE_INIT_REGISTRY_UNAVAILABLE")
  end
  assert(registry.on_init(function()
    storage.tech_priests=storage.tech_priests or {}
    if storage.tech_priests[KEY] then
      emit("FAIL DUPLICATE_NATIVE_INIT_ATTEMPT")
      return
    end
    storage.tech_priests[KEY]={attempted=true,passed=false}
    local ok,err=pcall(run)
    if not ok then
      storage.tech_priests[KEY].failure=tostring(err)
      emit("FAIL "..tostring(err))
      return
    end
    storage.tech_priests[KEY].passed=true
  end,{owner=KEY,route="initialize",category="diagnostics",priority="last"}))
  emit("INSTALLED isolated 4-direction native pipe acceptance on engine on_init")
  return true
end
return M
