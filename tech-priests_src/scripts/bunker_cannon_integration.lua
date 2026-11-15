-- Shared event ownership for the six-weapon prototype. Combat remains native.
local M={}
local family=require('scripts.bunker_family_visuals')
local bullet=require('scripts.bullet_turret_controller')
local cannon=require('scripts.twin_cannon_controller')
local rocket=require('scripts.rocket_salvo_controller')
function M.init()family.init();cannon.init();rocket.init()end
function M.tick(e)family.tick(e);cannon.tick(e);rocket.tick(e)end
local function add(entity)family.add(entity);cannon.add(entity);rocket.add(entity)end
function M.install_main(registry)
  assert(registry and registry.on_event and registry.on_init,'Canonical runtime event registry required')
  local owner='bunker_weapons'
  local preserved={};local previous_count=0
  for event,routes in pairs(registry.get_event_routes()) do
    preserved[event]={}
    for _,route in ipairs(routes) do preserved[event][route.id]=true;previous_count=previous_count+1 end
  end
  local function event(id,fn,route)
    assert(registry.on_event(id,fn,nil,{owner=owner,route=route,category='combat',priority=200}),route)
  end
  registry.on_init(M.init,{owner=owner,route='initialize',category='combat',priority=200})
  registry.on_configuration_changed(M.init,{owner=owner,route='configuration',category='combat',priority=200})
  event(defines.events.on_tick,M.tick,'weapon-motion')
  event(defines.events.on_entity_damaged,bullet.hit,'bullet-shot-observer')
  event(defines.events.on_script_trigger_effect,function(e)family.shot(e);cannon.effect(e);rocket.effect(e)end,'native-shot-effects')
  event(defines.events.on_trigger_created_entity,function(e)
    if not cannon.muzzle_created(e) and not rocket.muzzle_created(e) then bullet.muzzle_created(e) end
  end,'muzzle-effects')
  event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
    defines.events.script_raised_built,defines.events.script_raised_revive},function(e)add(e.entity)end,'weapon-built')
  event(defines.events.on_entity_cloned,function(e)add(e.destination)end,'weapon-cloned')
  for id,routes in pairs(preserved) do
    local current={};for _,route in ipairs(registry.get_event_routes()[id] or {}) do current[route.id]=true end
    for name in pairs(routes) do assert(current[name],'Existing runtime route lost: '..name) end
  end
  M.main_ownership={preexisting_routes=previous_count,preserved=true,owner=owner}
  return true
end
function M.install()
  family.install()
  script.on_init(M.init)
  script.on_configuration_changed(M.init)
  script.on_event(defines.events.on_tick,M.tick)
  script.on_event(defines.events.on_script_trigger_effect,function(e)family.shot(e);cannon.effect(e);rocket.effect(e)end)
  script.on_event(defines.events.on_trigger_created_entity,function(e)
    if not cannon.muzzle_created(e) and not rocket.muzzle_created(e) then bullet.muzzle_created(e) end
  end)
  script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
    defines.events.script_raised_built,defines.events.script_raised_revive},function(e)add(e.entity)end)
  script.on_event(defines.events.on_entity_cloned,function(e)add(e.destination)end)
end
return M
