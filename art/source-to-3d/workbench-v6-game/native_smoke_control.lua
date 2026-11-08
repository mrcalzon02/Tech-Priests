script.on_init(function()
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({0,0},1)
  surface.force_generate_chunk_requests()
  surface.set_tiles({{name="stone-path",position={0,0}}})
  for _,e in pairs(surface.find_entities_filtered{area={{-1,-1},{2,2}}}) do
    if e.type~="character" then e.destroy() end
  end
  local e=surface.create_entity{name="tech-priests-emergency-assembler",position={0.5,0.5},force="player"}
  assert(e and e.valid,"Workbench creation failed")
  game.forces.player.recipes["iron-gear-wheel"].enabled=true
  assert(e.set_recipe("iron-gear-wheel"),"Workbench recipe rejected")
  e.insert{name="iron-plate",count=20}
  e.get_fuel_inventory().insert{name="coal",count=5}
  storage.bench=e
end)
script.on_event(defines.events.on_tick,function(event)
  if event.tick==600 then
    local e=storage.bench
    assert(e and e.valid,"Workbench disappeared")
    assert(e.products_finished>0,"Workbench failed to craft gears")
    log("WORKBENCH_SMOKE_PASS products="..e.products_finished.." direction="..e.direction)
    script.finish_test(true)
  end
end)
