-- Dedicated graphics fixture. Does not create logistics actors or assert flow/combat behavior.
local function add(surface,name,position,direction)
  local e=assert(surface.create_entity{name=name,position=position,direction=direction,
    force='player',snap_to_grid=true,create_build_effect_smoke=false},name)
  e.destructible=false
  return e
end
local function connections(e)
  local result={}
  for index in ipairs(e.prototype.fluidbox_prototypes) do
    for _,c in ipairs(e.get_fluid_box_pipe_connections(index) or {}) do
      result[#result+1]={index=index,position=c.position,target_position=c.target_position,
        connected_name=c.target and c.target.name or nil,
        connected_position=c.target and c.target.position or nil,flow_direction=c.flow_direction}
    end
  end
  return result
end
local function pipe_stubs(e)
  for _,c in ipairs(connections(e)) do
    local target=c.target_position
    -- Ordinary entity grid, not off-grid pipes forced to fit fractional ports.
    add(e.surface,'pipe',target)
    local dx=target.x-c.position.x;local dy=target.y-c.position.y
    if math.abs(dx)>math.abs(dy) then dx=dx>0 and 1 or -1;dy=0
    else dy=dy>0 and 1 or -1;dx=0 end
    add(e.surface,'pipe',{target.x+dx,target.y+dy})
  end
end
local function record(e,label)
  storage.entities[#storage.entities+1]={entity=e,label=label}
end
local function clear_visual_obstructions()
  for _,e in pairs(storage.platform_surface.find_entities_filtered{type='asteroid'}) do e.destroy() end
  storage.platform_surface.platform.destroy_asteroid_chunks{}
end
local function placement_probe(e)
  local s=e.surface;local position={36+(e.prototype.tile_width%2==1 and .5 or 0),e.position.y};local results={}
  for edge=-1,6 do
    local tiles={}
    for x=32,43 do for y=-8,8 do tiles[#tiles+1]={name=y<=edge and 'space-platform-foundation' or 'empty-space',position={x,y}} end end
    s.set_tiles(tiles)
    results[#results+1]={last_foundation_tile_y=edge,position=position,can_place=s.can_place_entity{name=e.name,position=position,direction=e.direction,force='player'}}
  end
  return results
end
script.on_init(function()
  storage.entities={};storage.captured=false
  local ground=game.surfaces.nauvis
  ground.request_to_generate_chunks({0,0},2);ground.force_generate_chunk_requests()
  for _,e in pairs(ground.find_entities_filtered{area={{-40,-24},{40,24}}}) do e.destroy() end
  local tiles={};for x=-40,40 do for y=-24,24 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
  ground.set_tiles(tiles);ground.daytime=0;ground.freeze_daytime=true
  ground.destroy_decoratives{area={{-40,-24},{40,24}}}
  local dirs={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
  for j,direction in ipairs(dirs) do
    local x=(j-2.5)*8
    record(add(ground,'tech-priests-emergency-boiler',{x,-6},direction),'boiler-disconnected-'..j)
    local boiler=add(ground,'tech-priests-emergency-boiler',{x,2},direction);pipe_stubs(boiler);record(boiler,'boiler-connected-'..j)
  end
  local platform=assert(game.forces.player.create_space_platform{name='Local visual mount jig',planet='nauvis',starter_pack='space-platform-starter-pack'})
  platform.apply_starter_pack(true);local space=platform.surface
  space.request_to_generate_chunks({0,0},2);space.force_generate_chunk_requests()
  local foundation={};for x=-44,44 do for y=-24,2 do foundation[#foundation+1]={name='space-platform-foundation',position={x,y}} end end
  space.set_tiles(foundation);space.daytime=0;space.freeze_daytime=true
  storage.platform_surface=space
  local names={'thruster','hydrogen-thruster','thetazine-thruster','void-fusion-thruster','large-void-fusion-thruster'}
  for j,name in ipairs(names) do
    local proto=prototypes.entity[name];local cy=proto.tile_height%2==1 and .5 or 0
    local last=math.ceil(cy+proto.tile_height/2)-1;local lane={}
    for x=(j-3)*12-5,(j-3)*12+5 do for y=-12,6 do
      lane[#lane+1]={name=y<=last and 'space-platform-foundation' or 'empty-space',position={x,y}}
    end end
    space.set_tiles(lane)
    local e=add(space,name,{(j-3)*12,0},defines.direction.north)
    pipe_stubs(e);record(e,name..'-connected')
  end
end)
script.on_event(defines.events.on_player_created,function(event)
  local p=game.get_player(event.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,-12},game.surfaces.nauvis);p.zoom=1.25
end)
script.on_event(defines.events.on_tick,function()
  if storage.captured and not storage.disconnected_done and game.tick>=150 then
    storage.disconnected_done=true
    for _,pipe in pairs(storage.platform_surface.find_entities_filtered{type='pipe'}) do pipe.destroy() end
    local disconnected={status='DISCONNECTED_GEOMETRY_CAPTURED',entities={}}
    for _,entry in ipairs(storage.entities) do
      local e=entry.entity
      if e.type=='thruster' then disconnected.entities[#disconnected.entities+1]={name=e.name,position=e.position,connections=connections(e)} end
    end
    helpers.write_file('model-visual-review/disconnected-readback.json',helpers.table_to_json(disconnected))
    clear_visual_obstructions()
    for j,name in ipairs({'thruster','hydrogen-thruster','thetazine-thruster','void-fusion-thruster','large-void-fusion-thruster'}) do
      game.take_screenshot{surface=storage.platform_surface,position={(j-3)*12,1},resolution={800,900},zoom=2,
        path='model-visual-review/'..name..'-disconnected.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,daytime=0,force_render=true}
    end
    game.auto_save('model-visual-review');game.tick_paused=true
    return
  end
  if storage.captured or game.tick<120 or #game.players==0 then return end
  storage.captured=true
  for _,p in pairs(game.players) do p.teleport({-100,-100},game.surfaces.nauvis) end
  local report={status='GRAPHICAL_FIXTURE_CAPTURE_REQUESTED',tick=game.tick,
    scope='Visual/prototype attachment geometry only. No fuel use, thrust, AI, logistics, combat or regression checks.',entities={}}
  for _,entry in ipairs(storage.entities) do
    local e=entry.entity
    report.entities[#report.entities+1]={label=entry.label,name=e.name,position=e.position,
      direction=e.direction,surface=e.surface.name,connections=connections(e),
      platform_edge_geometry=e.type=='thruster' and placement_probe(e) or nil}
  end
  helpers.write_file('model-visual-review/attachment-readback.json',helpers.table_to_json(report))
  game.take_screenshot{surface=game.surfaces.nauvis,position={0,-2},resolution={1600,1000},zoom=1.7,
    path='model-visual-review/boiler-four-directions.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,daytime=0,force_render=true}
  clear_visual_obstructions()
  for j,name in ipairs({'thruster','hydrogen-thruster','thetazine-thruster','void-fusion-thruster','large-void-fusion-thruster'}) do
    game.take_screenshot{surface=storage.platform_surface,position={(j-3)*12,1},resolution={800,900},zoom=2,
      path='model-visual-review/'..name..'-connected.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,daytime=0,force_render=true}
  end
end)
