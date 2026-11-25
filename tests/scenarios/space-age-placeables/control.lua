local void_station = "void-cogitator-station"
local void_research = "void-cogitator-stations"
local void_placeables = {
  void_station,
  "tech-priests-basic-space-cargo-inventory",
  "tech-priests-advanced-space-cargo-inventory"
}
local space_age_machinery = {
  "sterling-steam-catalyzer",
  "void-steam-engine",
  "citadel-manufactoreo",
  "entropic-extractor",
  "hydrogen-thruster",
  "thetazine-thruster",
  "void-fusion-thruster",
  "large-void-fusion-thruster",
  "tech-priests-voidship-macro-cannon",
  "tech-priests-voidship-lance-battery",
  "tech-priests-voidship-prow-launcher",
  "tech-priests-voidship-void-shield"
}

local function check_placeable(name, available)
  local item = prototypes.item[name]
  local entity = prototypes.entity[name]
  local recipe = prototypes.recipe[name]
  if available then
    assert(item and entity and recipe, "missing placeable: " .. name)
    assert(item.place_result == entity, "item cannot place its entity: " .. name)
  else
    assert(not (item or entity or recipe), "Space Age placeable exposed in base: " .. name)
  end
end

local function lay_tiles(surface, tile, left, top, right, bottom)
  local tiles = {}
  for x = left, right do
    for y = top, bottom do
      tiles[#tiles + 1] = { name = tile, position = {x, y} }
    end
  end
  surface.set_tiles(tiles)
end

local function build_args(force, name, position)
  return { name = name, position = position, force = force,
           build_check_type = defines.build_check_type.manual, raise_built = true }
end

local function setup()
  local space_age = script.active_mods["space-age"] ~= nil
  local force = game.forces.player

  for _, name in ipairs(void_placeables) do check_placeable(name, space_age) end
  for _, name in ipairs(space_age_machinery) do check_placeable(name, space_age) end
  for _, name in ipairs({"void-tech-priest", "void-tech-priest-belt-immune", "void-tech-priest-corpse"}) do
    assert((prototypes.entity[name] ~= nil) == space_age, "unexpected availability: " .. name)
  end
  assert((prototypes.technology[void_research] ~= nil) == space_age, "unexpected Void research availability")
  assert((prototypes.item["tech-priests-voidship-plasma-torpedo"] ~= nil) == space_age)
  assert((prototypes.recipe["tech-priests-voidship-plasma-torpedo"] ~= nil) == space_age)
  assert((remote.interfaces.tech_priests_voidship ~= nil) == space_age)

  for _, name in ipairs({"junior-cogitator-station", "planetary-magos-cogitator-station", "orbital-trader",
                         "tech-priests-martian-stone-cache"}) do
    check_placeable(name, true)
  end
  assert(force.technologies["planetary-magos-cogitator-stations"])
  assert(prototypes.entity["junior-tech-priest"])

  local nauvis = game.surfaces.nauvis
  nauvis.request_to_generate_chunks({48, 16}, 1)
  nauvis.force_generate_chunk_requests()
  lay_tiles(nauvis, "grass-1", 42, 10, 54, 22)
  for _, entity in pairs(nauvis.find_entities_filtered{area = {{42, 10}, {55, 23}}}) do entity.destroy() end
  local ground_position = {48, 16}
  local junior = build_args(force, "junior-cogitator-station", ground_position)
  assert(nauvis.can_place_entity(junior))
  if not space_age then
    assert(nauvis.create_entity(junior))
    return
  end

  local technology = assert(force.technologies[void_research])
  assert(technology.prerequisites["space-platform"], "Void research does not require Space Platform")
  force.technologies["space-platform"].researched = true
  for _, name in ipairs({"power-armor-mk2", "mech-armor"}) do
    if force.technologies[name] then force.technologies[name].researched = true end
  end
  for _, name in ipairs(void_placeables) do
    assert(not force.recipes[name].enabled, "Void research bypassed for " .. name)
    assert(not nauvis.can_place_entity(build_args(force, name, ground_position)), "planet accepted " .. name)
  end
  technology.researched = true
  for _, name in ipairs(void_placeables) do assert(force.recipes[name].enabled, "Void research omitted " .. name) end

  local platform = assert(force.create_space_platform{
    name = "Space Age placement test", planet = "nauvis", starter_pack = "space-platform-starter-pack"
  })
  if not platform.hub then assert(platform.apply_starter_pack(true)) end
  local surface = platform.surface
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  lay_tiles(surface, "space-platform-foundation", -10, -17, 20, 17)
  for index, name in ipairs(void_placeables) do
    assert(not surface.can_place_entity(build_args(force, name, {30, 0})), "empty space accepted " .. name)
    local args = build_args(force, name, {12, (index - 2) * 10})
    assert(surface.can_place_entity(args), "platform rejected " .. name)
    assert(surface.create_entity(args), "platform could not build " .. name)
  end
  storage.platform = platform
end

script.on_event(defines.events.on_tick, function(event)
  if event.tick == 1 then setup() end
  if event.tick ~= 120 then return end
  if not storage.platform then
    local priests = game.surfaces.nauvis.count_entities_filtered{
      name = {"junior-tech-priest", "junior-tech-priest-belt-immune"}, force = game.forces.player
    }
    assert(priests == 1, "ground station did not deploy one junior priest")
    log("SPACE_AGE_PLACEABLES_PASS base-only: Space Age prototypes absent; ground station deployed its priest")
    script.finish_test(true)
    return
  end
  local priests = storage.platform.surface.find_entities_filtered{
    name = {"void-tech-priest", "void-tech-priest-belt-immune"}, force = game.forces.player
  }
  assert(#priests == 1, "Void station did not deploy one priest on the platform")
  log("SPACE_AGE_PLACEABLES_PASS Space Age: research, deck placement, planetary rejection and Void Priest deployment")
  script.finish_test(true)
end)
