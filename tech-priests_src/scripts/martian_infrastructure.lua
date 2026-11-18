-- Native pole/radar composition. Work happens on lifecycle events, never per tick.
local M = {}
local prefix = 'tech-priests-martian-comms-'
local function tier(e)
  if not (e and e.valid) then return nil end
  return tonumber(e.name:match('^tech%-priests%-martian%-comms%-(%d)$'))
end
local function tables()
  storage.tech_priests_martian_arrays = storage.tech_priests_martian_arrays or {}
  storage.tech_priests_martian_destroy = storage.tech_priests_martian_destroy or {}
end
function M.ensure(e)
  local n = tier(e)
  if not n then return end
  tables()
  local record = storage.tech_priests_martian_arrays[e.unit_number]
  if record and record.radar and record.radar.valid then return record.radar end
  record = record or {pole=e}
  local helper_name = prefix..n..'-vision'
  local found = e.surface.find_entities_filtered{name=helper_name, position=e.position, radius=0.05, force=e.force}
  local radar = found[1]
  for i=2,#found do found[i].destroy() end
  radar = radar or e.surface.create_entity{name=helper_name,position=e.position,force=e.force,quality=e.quality,create_build_effect_smoke=false}
  assert(radar, 'Failed to create Martian array vision component')
  radar.destructible=false; radar.operable=false
  record.radar=radar
  if not record.parent_registration then
    record.parent_registration=script.register_on_object_destroyed(e)
    storage.tech_priests_martian_destroy[record.parent_registration]={parent=e.unit_number,part='pole'}
  end
  local registration=script.register_on_object_destroyed(radar)
  storage.tech_priests_martian_destroy[registration]={parent=e.unit_number,part='radar'}
  record.radar_registration=registration
  storage.tech_priests_martian_arrays[e.unit_number]=record
  return radar
end
function M.remove(e)
  if not (e and e.valid and tier(e)) then return end
  tables()
  local record=storage.tech_priests_martian_arrays[e.unit_number]
  if not record then return end
  storage.tech_priests_martian_arrays[e.unit_number]=nil
  if record.parent_registration then storage.tech_priests_martian_destroy[record.parent_registration]=nil end
  if record.radar_registration then storage.tech_priests_martian_destroy[record.radar_registration]=nil end
  if record.radar and record.radar.valid then record.radar.destroy() end
end
function M.initialize()
  tables()
  local unlocks={["tech-priests-martian-power-1"]="electronics",["tech-priests-martian-power-2"]="electric-energy-distribution-1",["tech-priests-martian-power-3"]="electric-energy-distribution-2",["tech-priests-martian-comms-1"]="radar",["tech-priests-martian-comms-2"]="advanced-circuit",["tech-priests-martian-comms-3"]="processing-unit"}
  for _,force in pairs(game.forces) do
    for recipe,technology in pairs(unlocks) do
      if force.technologies[technology] and force.technologies[technology].researched and force.recipes[recipe] then force.recipes[recipe].enabled=true end
    end
  end
  local names={prefix..'1',prefix..'2',prefix..'3'}
  for _,surface in pairs(game.surfaces) do
    for _,e in pairs(surface.find_entities_filtered{name=names}) do M.ensure(e) end
    -- Configuration changes also discard genuinely orphaned components.
    for n=1,3 do
      for _,r in pairs(surface.find_entities_filtered{name=prefix..n..'-vision'}) do
        local parent=surface.find_entities_filtered{name=prefix..n,position=r.position,radius=.05,force=r.force}[1]
        if not parent then r.destroy() end
      end
    end
  end
end
function M.install_main(registry)
  assert(registry and registry.on_event and registry.on_init,'Canonical Tech Priests event registry required')
  local owner='martian_infrastructure'
  local preserved={}
  for event,routes in pairs(registry.get_event_routes()) do
    preserved[event]={};for _,route in ipairs(routes) do preserved[event][route.id]=true end
  end
  local function register_event(event,handler,filters)
    assert(registry.on_event(event,handler,filters,{owner=owner,route='event-'..tostring(event),category='infrastructure',priority=220}))
  end
local filters={}
for n=1,3 do filters[#filters+1]={filter='name',name=prefix..n} end
for _,event in ipairs({defines.events.on_built_entity,defines.events.on_robot_built_entity,defines.events.script_raised_built,defines.events.script_raised_revive}) do
  register_event(event,function(ev) M.ensure(ev.entity or ev.created_entity) end,filters)
end
for _,event in ipairs({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,defines.events.on_entity_died,defines.events.script_raised_destroy}) do
  register_event(event,function(ev) M.remove(ev.entity) end,filters)
end
register_event(defines.events.on_entity_cloned,function(ev)
  if tier(ev.destination) then M.ensure(ev.destination)
  elseif ev.destination.valid and ev.destination.name:match('^tech%-priests%-martian%-comms%-%d%-vision$') then
    ev.destination.destroy() -- The cloned visible pole owns its own new component.
  end
end)
register_event(defines.events.on_object_destroyed,function(ev)
  tables()
  local binding=storage.tech_priests_martian_destroy[ev.registration_number]
  if not binding then return end
  storage.tech_priests_martian_destroy[ev.registration_number]=nil
  local record=storage.tech_priests_martian_arrays[binding.parent]
  if not record then return end
  if binding.part=='pole' then
    storage.tech_priests_martian_arrays[binding.parent]=nil
    if record.radar_registration then storage.tech_priests_martian_destroy[record.radar_registration]=nil end
    if record.radar and record.radar.valid then record.radar.destroy() end
  elseif record.pole and record.pole.valid then
    record.radar=nil;M.ensure(record.pole)
  end
end)
registry.on_configuration_changed(M.initialize,{owner=owner,route='configuration',category='infrastructure',priority=220})
registry.on_init(M.initialize,{owner=owner,route='initialize',category='infrastructure',priority=220})

  for event,old in pairs(preserved) do
    local present={};for _,route in ipairs(registry.get_event_routes()[event] or {}) do present[route.id]=true end
    for id in pairs(old) do assert(present[id],'Existing Tech Priests event route lost: '..id) end
  end
  M.main_ownership={owner=owner,preserved=true}
  return true
end
return M
