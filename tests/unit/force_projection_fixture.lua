-- Executable API-contract mock: verifies bounded setup and all presets.
-- This is NOT native Factorio acceptance.
local fixture="tests/scenarios/force-projection/fixture.lua"
local presets={"2p2b","4p-ffa","1v4-bugs","2v2","3v1","4v4-priests"}
for _,preset in ipairs(presets) do
  local handlers,initializers,records={},{},{}
  local Registry={on_init=function(fn)initializers[#initializers+1]=fn end,
    on_event=function(id,fn)handlers[id]=fn;return true end}
  package.loaded["scripts.core.runtime_event_registry"]=Registry
  storage={tech_priests={pairs_by_station={}}}
  tech_priests_set_emergency_operation_0184=function(pair,enabled,reason)
    assert(enabled and reason=="arena-independent")
    assert(pair.emergency_operation_auto_allowed_0190==true)
    assert(pair.logistic_frustration_due_tick==game.tick)
    pair.independent_emergency_operation_0184={enabled=true,reason=reason}
    return true
  end
  tech_priests_get_emergency_operation_0184=function(pair)
    return pair.independent_emergency_operation_0184
  end
  helpers={table_to_json=function(data)records[#records+1]=data;return "{}" end}
  log=function()end
  _G.TP_FORCE_PROJECTION_CONFIG={preset=preset,seed=42,active_ticks=3600}
  defines={events={},inventory={chest=1}}
  for _,name in ipairs({"on_tick","on_entity_damaged","on_built_entity",
      "on_robot_built_entity","script_raised_built","script_raised_revive",
      "on_entity_died","on_research_finished"})do defines.events[name]=name end
  local created,chunks,api_calls=0,0,0
  local surface={request_to_generate_chunks=function()api_calls=api_calls+1 end,
    force_generate_chunk_requests=function()chunks=chunks+1 end,
    set_tiles=function()api_calls=api_calls+1 end,
    find_entities_filtered=function(opts)
      assert(type(opts.force)=="table" and #opts.force==#storage.ci_force_projection_v1.participants,
        "census must filter participating forces before its entity limit")
      assert(opts.limit==512)
      return {}
    end}
  local inventories={}
  surface.create_entity=function(args)
    api_calls=api_calls+1;created=created+1
    local entity={valid=true,unit_number=created,name=args.name,
      position=args.position,force=args.force,type="container"}
    local inv={valid=true}
    local contents={}
    inv.get_item_count=function(name)return contents[name]or 0 end
    inv.insert=function(stack)
      contents[stack.name]=(contents[stack.name]or 0)+stack.count;return stack.count
    end
    for i=1,48 do inv[i]={set_stack=function(stack)
      assert(stack.count>=1 and stack.count<=100);return true end}end
    entity.get_inventory=function()return inv end
    entity.get_item_count=function()return 48 end
    if args.name=="planetary-magos-cogitator-station"then
      local priest={valid=true,unit_number=created+100000}
      storage.tech_priests.pairs_by_station[created]={station=entity,priest=priest}
    end
    return entity
  end
  prototypes={item={a={hidden=false,stack_size=100,type="item"},
    ["senior-cogitator-station"]={hidden=false,stack_size=1,type="item"},
    b={hidden=false,stack_size=100,type="ammo"},
    hidden={hidden=true,stack_size=100,type="item"}},
    entity={["steel-chest"]={hidden=false,type="container",
      get_inventory_size=function()return 48 end}}}
  game={tick=0,surfaces={surface},forces={},map_settings={enemy_expansion={},enemy_evolution={}},
    create_random_generator=function(seed)
      local x=seed
      return function(a,b)x=(x*48271)%2147483647;return a+x%(b-a+1)end
    end,
    server_save=function()end}
  game.create_force=function(name)
    local force={name=name,set_evolution_factor=function()end,
      set_friend=function()end,set_cease_fire=function()end,chart=function()end,
      get_item_production_statistics=function()return {
        get_input_count=function()return 0 end,get_output_count=function()return 0 end}end}
    game.forces[name]=force;return force
  end
  local M=dofile(fixture);M.install();initializers[1]()
  local expected=preset=="4v4-priests" and 8 or preset=="1v4-bugs" and 5 or 4
  local s=storage.ci_force_projection_v1
  assert(#s.participants==expected)
  for _,p in ipairs(s.participants)do
    assert(game.forces[p.force].ai_controllable==(p.kind=="b"))
    if preset=="4p-ffa" then assert(p.kind=="p") end
  end
  for t=1,100000 do
    game.tick=t;api_calls=0
    handlers.on_tick{tick=t}
    assert(api_calls<=16,"unbounded fixture API batch: "..api_calls)
    assert(not s.failed,"fixture failed: "..preset)
    if s.finished then break end
  end
  assert(s.finished,"fixture did not terminate")
  for _,p in ipairs(s.participants)do
    if p.kind=="p"then
      local pair=storage.tech_priests.pairs_by_station[p.station.unit_number]
      assert(pair.independent_emergency_operation_0184.enabled)
      assert(p.expansion_stock.count>=1 and p.expansion_stock.count<=5)
      assert(p.station.get_inventory(1).get_item_count("senior-cogitator-station")==p.expansion_stock.count)
      assert(p.expansion_stock.deployed==0)
    end
  end
  assert(chunks==(s.side/32)^2)
  local counts={}
  for _,r in ipairs(records)do
    if r.cell then
      assert(r.entities_or_tiles>0,"empty deposit "..r.cell.." "..r.name.." "..r.x..","..r.y)
      counts[r.cell]=(counts[r.cell]or 0)+1
    end
  end
  for cell=0,(s.side/256)^2-1 do assert(counts[cell]==6)end
  print("PASS bounded fixture setup and observation "..preset)
end
