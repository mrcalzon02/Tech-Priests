-- Tech Priests - Space Age compatibility.
-- Loaded only when mods["space-age"] exists.
--
-- Goals:
--   * Make Tech-Priests placeable/usable on space platform foundation where a
--     comparable vanilla entity is already allowed.
--   * Give custom items sensible Space Age rocket-logistics weights so platform
--     construction requests can carry them predictably.
--   * Avoid hardcoding Space Age graphics/paths. This file only copies stable
--     prototype fields from entities that already exist in data.raw.

local kilogram = _G.kg or 1000
local ton = _G.ton or (1000 * kilogram)

local function platform_safe_surface_conditions()
  -- Wide-open surface condition override.  Space platforms have zero/near-zero
  -- surface properties, while copied vanilla chests can carry a positive
  -- gravity minimum.  Earlier min=0 attempts were not enough in live tests, so
  -- use an explicit broad min/max range to beat inherited container doctrine.
  return {
    { property = "gravity", min = -1000000, max = 1000000 },
    { property = "pressure", min = -1000000, max = 1000000 }
  }
end

local function first_existing_entity(candidates)
  for _, candidate in ipairs(candidates or {}) do
    local raw_type = candidate[1]
    local name = candidate[2]
    local proto = data.raw[raw_type] and data.raw[raw_type][name]
    if proto then return proto end
  end
  return nil
end

local function copy_buildability_from(target, source)
  if not target or not source then return end

  -- Space Age uses prototype-side placement restrictions such as
  -- tile_buildability_rules and surface_conditions. Copy tile rules from a
  -- comparable vanilla prototype so foundation/platform tile placement remains
  -- sane, but do not inherit the source surface_conditions directly.
  if source.tile_buildability_rules then
    target.tile_buildability_rules = table.deepcopy(source.tile_buildability_rules)
  else
    target.tile_buildability_rules = nil
  end

  target.surface_conditions = platform_safe_surface_conditions()
end


local PLATFORM_ENTITY_NAMES = {
  ["planetary-magos-cogitator-station"] = true,
  ["void-cogitator-station"] = true,
  ["orbital-trader"] = true,
  ["tech-priests-hidden-requester-cache"] = true,
  ["tech-priests-hidden-return-cache"] = true,
  ["junior-tech-priest"] = true,
  ["intermediate-tech-priest"] = true,
  ["senior-tech-priest"] = true,
  ["planetary-magos-tech-priest"] = true,
  ["void-tech-priest"] = true,
  ["junior-tech-priest-belt-immune"] = true,
  ["intermediate-tech-priest-belt-immune"] = true,
  ["senior-tech-priest-belt-immune"] = true,
  ["planetary-magos-tech-priest-belt-immune"] = true,
  ["void-tech-priest-belt-immune"] = true,
  ["junior-tech-priest-corpse"] = true,
  ["intermediate-tech-priest-corpse"] = true,
  ["senior-tech-priest-corpse"] = true,
  ["planetary-magos-tech-priest-corpse"] = true,
  ["void-tech-priest-corpse"] = true,
}

local function clear_space_surface_restrictions_by_name(name)
  if not name then return end
  for _, prototypes_of_type in pairs(data.raw or {}) do
    local proto = prototypes_of_type and prototypes_of_type[name]
    if proto then
      proto.surface_conditions = platform_safe_surface_conditions()
      -- Do not clear tile_buildability_rules here; those are useful for making
      -- structures require actual platform/foundation tiles. The problematic
      -- placement blocker is the default chest/container gravity minimum.
      if proto.heating_energy == nil and proto.type ~= "corpse" and proto.type ~= "unit" then
        proto.heating_energy = "0W"
      end
    end
  end
end

local function clear_all_space_surface_restrictions()
  for name in pairs(PLATFORM_ENTITY_NAMES) do
    clear_space_surface_restrictions_by_name(name)
  end
end

local function set_weight(item_name, weight)
  local item = data.raw.item and data.raw.item[item_name]
  if item then item.weight = weight end
  local tool = data.raw["selection-tool"] and data.raw["selection-tool"][item_name]
  if tool then tool.weight = weight end
  local capsule = data.raw.capsule and data.raw.capsule[item_name]
  if capsule then capsule.weight = weight end
end


local function scale_sprite_like_tree(node, factor)
  -- Recursively scale common sprite/animation tables without assuming a
  -- specific thruster graphics shape. This helper is intentionally defensive:
  -- Space Age graphics_set tables can contain nested layers, animations,
  -- working_visualisations, filenames, tints, and scalar metadata.
  if not node or type(node) ~= "table" or type(factor) ~= "number" then return end

  local seen = {}
  local function visit(t)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true

    if type(t.scale) == "number" then
      t.scale = t.scale * factor
    end
    if type(t.hr_version) == "table" then
      visit(t.hr_version)
    end

    -- Shifts are tile-space offsets; scaling them along with the sprite keeps
    -- copied thruster layers centered on the reduced footprint.
    if type(t.shift) == "table" and type(t.shift[1]) == "number" and type(t.shift[2]) == "number" then
      t.shift = { t.shift[1] * factor, t.shift[2] * factor }
    end

    -- Some graphics tables use explicit width/height/line_length/frame_count
    -- fields; do not scale pixel dimensions. Only scale runtime transform
    -- fields and nested tables.
    for k, v in pairs(t) do
      if type(v) == "table" and k ~= "shift" then
        visit(v)
      end
    end
  end

  visit(node)
end

local function mark_platform_buildable_entity(raw_type, name, source_type, source_name)
  local target = data.raw[raw_type] and data.raw[raw_type][name]
  local source = data.raw[source_type] and data.raw[source_type][source_name]
  if not target or not source then return end

  copy_buildability_from(target, source)

  -- Space platforms are zero-gravity. The modded structures are ritual support
  -- nodes rather than freezing/cryogenic systems, so do not opt them into the
  -- freezing/heating mechanic.
  target.heating_energy = "0W"
end

-- Visible player-built structures.
-- Do not copy from steel-chest here: Space Age deliberately blocks normal
-- chests on platforms.  Copy tile/foundation rules from something that is
-- actually platform-buildable, then apply our own permissive surface conditions.
local platform_tile_source = first_existing_entity({
  {"assembling-machine", "crusher"},
  {"asteroid-collector", "asteroid-collector"},
  {"cargo-bay", "cargo-bay"},
  {"space-platform-hub", "space-platform-hub"}
})

for _, station_name in pairs({
  "planetary-magos-cogitator-station",
  "void-cogitator-station"
}) do
  local target = data.raw.container and data.raw.container[station_name]
  if target then
    copy_buildability_from(target, platform_tile_source)
    target.placeable_by = { item = station_name, count = 1 }
  end
end

mark_platform_buildable_entity("assembling-machine", "orbital-trader", "assembling-machine", "crusher")
if data.raw["assembling-machine"] and data.raw["assembling-machine"]["orbital-trader"] and not (data.raw["assembling-machine"] and data.raw["assembling-machine"]["crusher"]) then
  mark_platform_buildable_entity("assembling-machine", "orbital-trader", "assembling-machine", "assembling-machine-3")
end

-- Script-spawned helper logistics caches. Copy from their own vanilla parents so
-- if request/provider chests are allowed on a platform, these helpers inherit the
-- same permission. They are still hidden and non-player-placeable.
mark_platform_buildable_entity("logistic-container", "tech-priests-hidden-requester-cache", "logistic-container", "requester-chest")
mark_platform_buildable_entity("logistic-container", "tech-priests-hidden-return-cache", "logistic-container", "active-provider-chest")

-- Script-spawned units/corpses/effects should not get stricter surface limits
-- from their copied base prototypes. They are not directly player-built.
for _, unit_name in pairs({
  "junior-tech-priest", "intermediate-tech-priest", "senior-tech-priest", "planetary-magos-tech-priest", "void-tech-priest",
  "junior-tech-priest-belt-immune", "intermediate-tech-priest-belt-immune", "senior-tech-priest-belt-immune", "planetary-magos-tech-priest-belt-immune", "void-tech-priest-belt-immune"
}) do
  local unit = data.raw.unit and data.raw.unit[unit_name]
  if unit then
    unit.surface_conditions = platform_safe_surface_conditions()
    unit.tile_buildability_rules = nil
    unit.heating_energy = "0W"
  end
end

for _, corpse_name in pairs({
  "junior-tech-priest-corpse",
  "intermediate-tech-priest-corpse",
  "senior-tech-priest-corpse",
  "planetary-magos-tech-priest-corpse",
  "void-tech-priest-corpse"
}) do
  local corpse = data.raw.corpse and data.raw.corpse[corpse_name]
  if corpse then
    corpse.surface_conditions = platform_safe_surface_conditions()
    corpse.tile_buildability_rules = nil
  end
end

-- Sensible Space Age rocket-logistics weights. These are not meant as final
-- balance; they prevent custom items from falling into odd default cargo
-- behavior and let platform hub construction requests reason about them.
set_weight("junior-cogitator-station", 100 * kilogram)
set_weight("intermediate-cogitator-station", 180 * kilogram)
set_weight("senior-cogitator-station", 300 * kilogram)
set_weight("planetary-magos-cogitator-station", 360 * kilogram)
set_weight("void-cogitator-station", 420 * kilogram)
set_weight("orbital-trader", 500 * kilogram)

set_weight("mechanical-detritus", 2 * kilogram)
set_weight("ritual-salt", 1 * kilogram)
set_weight("pure-carbon", 1 * kilogram)
set_weight("sodium-carbonate", 1 * kilogram)
set_weight("wood-pulp", 500) -- 0.5 kg if kg is 1000
set_weight("paraffin", 1 * kilogram)
set_weight("sacred-candle", 1 * kilogram)

set_weight("sacred-machine-oil", 2 * kilogram)
set_weight("machine-maintenance-litany", 5 * kilogram)
set_weight("ritual-of-machine-appeasement", 8 * kilogram)
set_weight("sacred-incense-grenade", 10 * kilogram)

set_weight("offworld-cogitator-components", 20 * kilogram)
set_weight("servitor-parts", 15 * kilogram)
set_weight("relic-fragment", 25 * kilogram)
set_weight("void-sealed-cargo", 40 * kilogram)

-- 0.1.415: Void-Sealed Cargo output weights. Small salvage components stay
-- light enough for platform logistics; gear rewards carry closer to their
-- vanilla equivalents.
local void_cargo_small_salvage_weights_0415 = {
  "auspex-scrap",
  "hexagrammic-circuit-shard",
  "archeotech-capacitor",
  "micro-servitor-actuator",
  "machine-spirit-bound-relay",
  "sanctified-lens-array",
  "plasma-coil-reliquary",
  "void-burned-cogitator-core",
  "red-robe-fiber-bundle",
  "noospheric-targeter",
  "combat-servitor-targeting-eye",
  "sealed-ration-cache",
  "omen-bearing-data-slate",
  "spent-phosphor-lumen",
  "ritually-suspect-machine-plate",
  "void-chilled-lubricant-ampoule"
}
for _, item_name in pairs(void_cargo_small_salvage_weights_0415) do
  set_weight(item_name, 2 * kilogram)
end
set_weight("las-carbine", 20 * kilogram)
set_weight("hot-shot-power-cell", 1 * kilogram)
set_weight("rite-sealed-flak-vest", 25 * kilogram)
set_weight("mars-pattern-repair-kit", 4 * kilogram)

-- Last line of defense: clear low-gravity surface restrictions from every
-- Tech Priests entity name, regardless of which prototype table currently owns
-- it. This is intentionally repeated when this file is required from
-- data-final-fixes.lua.
clear_all_space_surface_restrictions()


--------------------------------------------------------------------------
-- Blackstone asteroid and Citadel Manufactureo platform chain.
--------------------------------------------------------------------------

local BLACKSTONE_ICON = "__tech-priests__/graphics/icons/blackstone.png"
local BLACKSTONE_ICON_BY_ITEM_0433 = {
  ["blackstone-asteroid-chunk"] = "__tech-priests__/graphics/icons/blackstone-asteroid-chunk.png",
  ["blackstone-fragment"] = "__tech-priests__/graphics/icons/blackstone-fragment.png",
  ["blackstone-slab"] = "__tech-priests__/graphics/icons/blackstone-slab.png"
}
local BLACKSTONE_CHUNK = "blackstone-asteroid-chunk"
local BLACKSTONE_FRAGMENT = "blackstone-fragment"
local BLACKSTONE_SLAB = "blackstone-slab"
local ENTROPIC_BLACKSTONE_FUEL_CATEGORY = "entropic-extractor-blackstone"
local CITADEL_MANUFACTOREO = "citadel-manufactoreo"
local ENTROPIC_EXTRACTOR = "entropic-extractor"
local LIQUID_HYDROGEN = "liquid-hydrogen"
local LIQUID_OXYGEN = "liquid-oxygen"
local HYDROGEN_THRUSTER = "hydrogen-thruster"
local STERLING_STEAM_CATALYZER = "sterling-steam-catalyzer"
local VOID_STEAM_ENGINE = "void-steam-engine"
local CARBONIC_ACID = "carbonic-acid"
local IRON_SALTS = "iron-salts"
local MAGNETO_RESONANT_SLURRY = "magneto-resonant-slurry"
local THETAZINE_FUEL = "thetazine-fuel"
local THETAZINE_THRUSTER = "thetazine-thruster"
local VOID_FUSION_THRUSTER = "void-fusion-thruster"
local LARGE_VOID_FUSION_THRUSTER = "large-void-fusion-thruster"
local VOID_FUSION_THRUSTER_POWER_SINK = "void-fusion-thruster-power-sink"
local VOID_FUSION_THRUSTER_CHARGE = "void-fusion-thruster-charge"
local VOID_FUSION_THRUSTER_REACTION_MASS = "void-fusion-thruster-reaction-mass"

local function blackstone_platform_only_surface_conditions()
  -- Platform-only: space platforms are effectively zero gravity/pressure.
  return {
    { property = "gravity", min = -0.01, max = 0.10 },
    { property = "pressure", min = -0.01, max = 0.10 }
  }
end


-- 0.1.433 Alpha graphics integration helpers.
-- These helpers deliberately use ordinary prototype-stage animation tables and
-- fixed frame dimensions. Runtime behavior, movement, scheduler state, fluid
-- boxes, and platform authority are not modified by this graphics pass.
local function tech_priests_animation_layer_0433(filename, width, height, frame_count, line_length, animation_speed, scale, shift)
  return {
    filename = filename,
    priority = "high",
    width = width,
    height = height,
    frame_count = frame_count or 1,
    line_length = line_length or frame_count or 1,
    animation_speed = animation_speed or 0.20,
    scale = scale or 1,
    shift = shift or {0, 0}
  }
end

local function tech_priests_animation_4way_0433(filename, width, height, frame_count, line_length, animation_speed, scale, shift)
  local animation = tech_priests_animation_layer_0433(filename, width, height, frame_count, line_length, animation_speed, scale, shift)
  return {
    north = table.deepcopy(animation),
    east = table.deepcopy(animation),
    south = table.deepcopy(animation),
    west = table.deepcopy(animation)
  }
end

local function tech_priests_static_machine_graphics_0433(idle_filename, active_filename, width, height, scale, shift)
  local idle = tech_priests_animation_4way_0433(idle_filename, width, height, 1, 1, 1, scale, shift)
  local active = tech_priests_animation_4way_0433(active_filename or idle_filename, width, height, 1, 1, 1, scale, shift)
  return {
    idle_animation = idle,
    animation = active,
    always_draw_idle_animation = false
  }
end

local function tech_priests_thruster_graphics_0433(idle_filename, run_filename, width, height, frame_count, line_length, animation_speed, scale, shift)
  return {
    idle_animation = tech_priests_animation_4way_0433(idle_filename, width, height, frame_count, line_length, animation_speed, scale, shift),
    animation = tech_priests_animation_4way_0433(run_filename, width, height, frame_count, line_length, animation_speed, scale, shift),
    always_draw_idle_animation = false
  }
end

-- 0.1.439: When a custom thruster replaces the vanilla graphics_set, the
-- inherited fluid boxes may still contain enable_working_visualisations entries
-- such as pipe-1/pipe-2/pipe-3/pipe-4. Those names only exist in the vanilla
-- thruster graphics_set. Strip the inherited pipe visual gates so the custom
-- thruster sheets can load without requiring matching named pipe overlays.
local function tech_priests_strip_thruster_pipe_visual_gates_0439(thruster)
  if type(thruster) ~= "table" then return 0 end
  local removed = 0
  local seen = {}

  local function visit(node)
    if type(node) ~= "table" or seen[node] then return end
    seen[node] = true

    if node.enable_working_visualisations ~= nil then
      node.enable_working_visualisations = nil
      removed = removed + 1
    end

    for _, child in pairs(node) do
      if type(child) == "table" then
        visit(child)
      end
    end
  end

  visit(thruster.fuel_fluid_box)
  visit(thruster.oxidizer_fluid_box)
  visit(thruster.fluid_box)
  visit(thruster.fluid_boxes)
  return removed
end

local function blackstone_item_like_icon(name)
  local item = {
    type = "item",
    name = name,
    icon = BLACKSTONE_ICON_BY_ITEM_0433[name] or BLACKSTONE_ICON,
    icon_size = 64,
    subgroup = "tech-priest-orbital-trade",
    order = "c[blackstone]-" .. name,
    stack_size = 50,
    weight = 20 * kilogram
  }

  -- 0.1.453: the Entropic Extractor burns processed Blackstone fragments, not raw asteroid chunks.
  -- Raw chunks remain orbital collection material; fragments are the refined reliquary fuel.
  if name == BLACKSTONE_FRAGMENT then
    item.fuel_category = ENTROPIC_BLACKSTONE_FUEL_CATEGORY
    item.fuel_value = "1PJ"
    item.fuel_glow_color = { r = 0.12, g = 0.95, b = 0.22, a = 1.0 }
  end

  return item
end

if not (data.raw["fuel-category"] and data.raw["fuel-category"][ENTROPIC_BLACKSTONE_FUEL_CATEGORY]) then
  data:extend({
    {
      type = "fuel-category",
      name = ENTROPIC_BLACKSTONE_FUEL_CATEGORY
    }
  })
end

data:extend({
  blackstone_item_like_icon(BLACKSTONE_CHUNK),
  blackstone_item_like_icon(BLACKSTONE_FRAGMENT),
  blackstone_item_like_icon(BLACKSTONE_SLAB),
  {
    type = "item",
    name = CITADEL_MANUFACTOREO,
    icon = "__tech-priests__/graphics/icons/citadel-manufactoreo.png",
    icon_size = 64,
    subgroup = "tech-priest-orbital-trade",
    order = "c[blackstone]-a[citadel-manufactoreo]",
    place_result = CITADEL_MANUFACTOREO,
    stack_size = 5,
    weight = 750 * kilogram
  },
  {
    type = "item",
    name = ENTROPIC_EXTRACTOR,
    icon = "__tech-priests__/graphics/icons/entropic-extractor.png",
    icon_size = 64,
    subgroup = "tech-priest-orbital-trade",
    order = "c[blackstone]-b[entropic-extractor]",
    place_result = ENTROPIC_EXTRACTOR,
    stack_size = 20,
    weight = 100 * kilogram
  }
})

local function blackstone_copy_icon_fields(target)
  target.icon = BLACKSTONE_ICON
  target.icon_size = 64
  target.icons = nil
end

local function replace_blackstone_names(value)
  if type(value) == "string" then
    value = string.gsub(value, "metallic%-asteroid%-chunk", BLACKSTONE_CHUNK)
    value = string.gsub(value, "carbonic%-asteroid%-chunk", BLACKSTONE_CHUNK)
    value = string.gsub(value, "oxide%-asteroid%-chunk", BLACKSTONE_CHUNK)
    value = string.gsub(value, "small%-metallic%-asteroid", "small-blackstone-asteroid")
    value = string.gsub(value, "medium%-metallic%-asteroid", "medium-blackstone-asteroid")
    value = string.gsub(value, "big%-metallic%-asteroid", "big-blackstone-asteroid")
    value = string.gsub(value, "huge%-metallic%-asteroid", "huge-blackstone-asteroid")
    return value
  elseif type(value) == "table" then
    for k, v in pairs(value) do
      value[k] = replace_blackstone_names(v)
    end
  end
  return value
end




local function restore_existing_asteroid_particle_references(value)
  -- Some Space Age asteroid/chunk prototypes contain references to particle
  -- prototype names such as metallic-asteroid-chunk-particle-medium. Our
  -- Blackstone clones should keep those existing particle prototype references
  -- unless/until we deliberately provide a complete Blackstone particle family.
  -- Otherwise assignID fails on the first renamed particle reference.
  if type(value) == "string" then
    value = string.gsub(value, "blackstone%-asteroid%-chunk%-particle", "metallic-asteroid-chunk-particle")
    value = string.gsub(value, "blackstone%-asteroid%-particle", "metallic-asteroid-particle")
    return value
  elseif type(value) == "table" then
    for k, v in pairs(value) do
      value[k] = restore_existing_asteroid_particle_references(v)
    end
  end
  return value
end


local function tech_priests_tint_blackstone_runtime_sprites_0453(value)
  -- 0.1.453: raw Blackstone chunks were still visually inheriting the base
  -- metallic asteroid object.  Until a complete bespoke asteroid sprite family is
  -- painted, tint copied sprite fields toward dark green-black so the in-world
  -- object no longer reads as ordinary metallic ore.
  if type(value) ~= "table" then return end
  if value.filename or value.filenames or value.stripes or value.layers or value.hr_version then
    value.tint = value.tint or { r = 0.08, g = 0.11, b = 0.08, a = 1.0 }
  end
  if type(value.hr_version) == "table" then
    value.hr_version.tint = value.hr_version.tint or { r = 0.08, g = 0.11, b = 0.08, a = 1.0 }
  end
  for _, child in pairs(value) do
    if type(child) == "table" then tech_priests_tint_blackstone_runtime_sprites_0453(child) end
  end
end

-- 0.1.543: Retarget Blackstone asteroid bodies, chunks, and particle debris to
-- the actual Blackstone image assets shipped with this mod instead of the
-- inherited Space Age metallic/iron asteroid sheets.  This deliberately keeps
-- the cloned prototype behavior, damage, collection, and spawn definitions
-- intact; only nested sprite sources are redirected and normalized to the
-- 64x64 Blackstone artwork currently available in graphics/icons/.
local BLACKSTONE_ASTEROID_BODY_SPRITE_0543 = "__tech-priests__/graphics/icons/blackstone.png"
local BLACKSTONE_ASTEROID_CHUNK_SPRITE_0543 = "__tech-priests__/graphics/icons/blackstone-asteroid-chunk.png"
local BLACKSTONE_PARTICLE_SPRITE_0543 = "__tech-priests__/graphics/icons/blackstone-fragment.png"
local BLACKSTONE_PARTICLE_SPRITES_0544 = {
  tiny = "__tech-priests__/graphics/effect/blackstone-particles/blackstone-particle-tiny.png",
  small = "__tech-priests__/graphics/effect/blackstone-particles/blackstone-particle-small.png",
  medium = "__tech-priests__/graphics/effect/blackstone-particles/blackstone-particle-medium.png",
  big = "__tech-priests__/graphics/effect/blackstone-particles/blackstone-particle-big.png",
  large = "__tech-priests__/graphics/effect/blackstone-particles/blackstone-particle-large.png"
}

local function tech_priests_retarget_blackstone_sprite_nodes_0543(value, filename, scale)
  if type(value) ~= "table" then return end

  if type(value.layers) == "table" and #value.layers > 1 then
    -- The inherited asteroid art can contain several metallic color/shadow
    -- layers.  If every one is redirected to the same Blackstone plate, the
    -- result overdraws into a bright stack.  Keep one visible layer and let
    -- the supplied icon art carry the object silhouette.
    value.layers = { value.layers[1] }
  end

  if value.filename or value.filenames or value.stripes then
    value.filename = filename
    value.filenames = nil
    value.stripes = nil
    value.width = 64
    value.height = 64
    value.size = nil
    value.x = 0
    value.y = 0
    value.frame_count = 1
    value.line_length = 1
    value.direction_count = nil
    value.width_in_frames = nil
    value.height_in_frames = nil
    value.repeat_count = nil
    value.variation_count = nil
    value.scale = scale or value.scale or 1
    value.tint = nil
    value.hr_version = nil
    value.draw_as_shadow = nil
  end

  for _, child in pairs(value) do
    if type(child) == "table" then
      tech_priests_retarget_blackstone_sprite_nodes_0543(child, filename, scale)
    end
  end
end


local function tech_priests_particle_suffix_0544(name)
  local suffix = tostring(name or ""):match("%-([^%-]+)$")
  if suffix == "tiny" or suffix == "small" or suffix == "medium" or suffix == "big" or suffix == "large" then return suffix end
  return "medium"
end

local function tech_priests_particle_sprite_for_name_0544(name)
  local suffix = tech_priests_particle_suffix_0544(name)
  return BLACKSTONE_PARTICLE_SPRITES_0544[suffix] or BLACKSTONE_PARTICLE_SPRITE_0543
end

local function tech_priests_find_particle_template_0544(name)
  if not data.raw.particle then return nil end
  local suffix = tech_priests_particle_suffix_0544(name)
  local candidates = {
    "metallic-asteroid-chunk-particle-" .. suffix,
    "metallic-asteroid-particle-" .. suffix,
    "carbonic-asteroid-chunk-particle-" .. suffix,
    "carbonic-asteroid-particle-" .. suffix,
    "oxide-asteroid-chunk-particle-" .. suffix,
    "oxide-asteroid-particle-" .. suffix,
    "stone-particle-" .. suffix,
    "stone-particle-medium"
  }
  for _, candidate in pairs(candidates) do
    if data.raw.particle[candidate] then return data.raw.particle[candidate] end
  end
  for _, particle in pairs(data.raw.particle) do
    return particle
  end
  return nil
end

local function tech_priests_ensure_blackstone_particle_0544(name)
  if not data.raw.particle or not name or data.raw.particle[name] then return end
  local template = tech_priests_find_particle_template_0544(name)
  if not template then return end
  local clone = table.deepcopy(template)
  clone.name = name
  clone.localised_name = { "entity-name." .. name }
  local sprite = tech_priests_particle_sprite_for_name_0544(name)
  tech_priests_retarget_blackstone_sprite_nodes_0543(clone.pictures, sprite, 0.24)
  tech_priests_retarget_blackstone_sprite_nodes_0543(clone.picture, sprite, 0.24)
  data:extend({ clone })
end

local function tech_priests_ensure_blackstone_particle_family_0544()
  local suffixes = { "tiny", "small", "medium", "big", "large", "huge" }
  for _, suffix in pairs(suffixes) do
    tech_priests_ensure_blackstone_particle_0544("blackstone-asteroid-chunk-particle-" .. suffix)
    tech_priests_ensure_blackstone_particle_0544("blackstone-asteroid-particle-" .. suffix)
  end
  tech_priests_ensure_blackstone_particle_0544("blackstone-asteroid-chunk-particle")
  tech_priests_ensure_blackstone_particle_0544("blackstone-asteroid-particle")
end

local function make_blackstone_particle_family()
  -- The asteroid and asteroid-chunk prototypes contain particle prototype
  -- references such as metallic-asteroid-chunk-particle-medium. When we
  -- rename the chunk lineage to blackstone-asteroid-chunk, Factorio expects
  -- matching particle prototypes to exist. Clone every metallic chunk particle
  -- variant we can find so small/medium/big/etc. particle references do not
  -- fail one size at a time.
  if not data.raw.particle then return end

  local clones = {}
  for particle_name, particle in pairs(data.raw.particle) do
    local blackstone_name = nil
    if string.find(particle_name, "metallic%-asteroid%-chunk") then
      blackstone_name = string.gsub(particle_name, "metallic%-asteroid%-chunk", BLACKSTONE_CHUNK)
    elseif string.find(particle_name, "metallic%-asteroid") then
      blackstone_name = string.gsub(particle_name, "metallic%-asteroid", "blackstone-asteroid")
    end

    if blackstone_name and blackstone_name ~= particle_name and not data.raw.particle[blackstone_name] then
      local clone = table.deepcopy(particle)
      clone.name = blackstone_name
      clone.localised_name = { "entity-name." .. blackstone_name }
      -- 0.1.543: Use the included Blackstone particulate image instead of
      -- merely tinting the vanilla metallic/iron asteroid particle family.
      tech_priests_retarget_blackstone_sprite_nodes_0543(clone.pictures, BLACKSTONE_PARTICLE_SPRITE_0543, 0.22)
      tech_priests_retarget_blackstone_sprite_nodes_0543(clone.picture, BLACKSTONE_PARTICLE_SPRITE_0543, 0.22)
      table.insert(clones, clone)
    end
  end

  if #clones > 0 then
    data:extend(clones)
  end
end

local function make_blackstone_asteroid_chunk()
  local base = data.raw["asteroid-chunk"] and (
    data.raw["asteroid-chunk"]["metallic-asteroid-chunk"] or
    data.raw["asteroid-chunk"]["carbonic-asteroid-chunk"] or
    data.raw["asteroid-chunk"]["oxide-asteroid-chunk"])
  if not base or (data.raw["asteroid-chunk"] and data.raw["asteroid-chunk"][BLACKSTONE_CHUNK]) then return end

  local chunk = table.deepcopy(base)
  chunk.name = BLACKSTONE_CHUNK
  chunk.localised_name = { "asteroid-chunk-name.blackstone-asteroid-chunk" }
  chunk.localised_description = { "asteroid-chunk-description.blackstone-asteroid-chunk" }
  blackstone_copy_icon_fields(chunk)
  chunk.order = "z[blackstone-asteroid-chunk]"
  chunk.hide_from_signal_gui = false
  replace_blackstone_names(chunk)
  -- 0.1.545: Do not rename particle prototype references inside the cloned
  -- asteroid-chunk. Factorio validates those references at assignID time, and
  -- the engine expects real particle prototypes. The Blackstone chunk body still
  -- uses the shipped Blackstone sprite, but impact/debris references are restored
  -- to existing Space Age particles until a fully verified custom particle
  -- prototype family is introduced.
  restore_existing_asteroid_particle_references(chunk)
  tech_priests_retarget_blackstone_sprite_nodes_0543(chunk, BLACKSTONE_ASTEROID_CHUNK_SPRITE_0543, 0.42)
  data:extend({ chunk })
end

local BLACKSTONE_ASTEROID_SIZES = {
  { size = "small", source = "small-metallic-asteroid", health = 120, visual_scale = 0.45 },
  { size = "medium", source = "medium-metallic-asteroid", health = 360, visual_scale = 0.75 },
  { size = "big", source = "big-metallic-asteroid", health = 1200, visual_scale = 1.10 },
  { size = "huge", source = "huge-metallic-asteroid", health = 3200, visual_scale = 1.55 }
}

local function make_blackstone_asteroids()
  if not data.raw.asteroid then return end
  for _, spec in pairs(BLACKSTONE_ASTEROID_SIZES) do
    local source = data.raw.asteroid[spec.source]
    local name = spec.size .. "-blackstone-asteroid"
    if source and not data.raw.asteroid[name] then
      local asteroid = table.deepcopy(source)
      asteroid.name = name
      asteroid.localised_name = { "entity-name." .. name }
      asteroid.localised_description = { "entity-description.blackstone-asteroid" }
      asteroid.max_health = spec.health or asteroid.max_health
      asteroid.mass = (asteroid.mass or 1) * 2.5
      asteroid.resistances = asteroid.resistances or {}
      table.insert(asteroid.resistances, { type = "physical", decrease = 10, percent = 80 })
      table.insert(asteroid.resistances, { type = "explosion", decrease = 10, percent = 60 })
      blackstone_copy_icon_fields(asteroid)
      replace_blackstone_names(asteroid)
      -- 0.1.545: keep inherited particle references valid while retargeting
      -- visible asteroid body sprites to Blackstone art.
      restore_existing_asteroid_particle_references(asteroid)
      tech_priests_retarget_blackstone_sprite_nodes_0543(asteroid, BLACKSTONE_ASTEROID_BODY_SPRITE_0543, spec.visual_scale or 1.0)
      data:extend({ asteroid })
    end
  end
end

local function make_citadel_manufactoreo()
  if data.raw["assembling-machine"] and data.raw["assembling-machine"][CITADEL_MANUFACTOREO] then return end
  local source = (data.raw["assembling-machine"] and (data.raw["assembling-machine"]["crusher"] or data.raw["assembling-machine"]["assembling-machine-3"] or data.raw["assembling-machine"]["orbital-trader"]))
  if not source then return end

  local citadel = table.deepcopy(source)
  citadel.name = CITADEL_MANUFACTOREO
  citadel.localised_name = { "entity-name.citadel-manufactoreo" }
  citadel.localised_description = { "entity-description.citadel-manufactoreo" }
  citadel.icon = "__tech-priests__/graphics/icons/citadel-manufactoreo.png"
  citadel.icon_size = 64
  citadel.icons = nil
  citadel.minable = { mining_time = 2.0, result = CITADEL_MANUFACTOREO }
  citadel.crafting_categories = { "citadel-manufactoreo" }
  citadel.crafting_speed = 1
  citadel.energy_usage = "2MW"
  citadel.module_slots = 2
  citadel.fixed_recipe = nil
  citadel.fixed_quality = nil
  citadel.next_upgrade = nil
  citadel.fast_replaceable_group = nil
  citadel.placeable_by = { item = CITADEL_MANUFACTOREO, count = 1 }
  -- 0.1.453: visual footprint was crowding its selection envelope; grow by one tile in every direction.
  citadel.collision_box = {{-2.45, -2.45}, {2.45, 2.45}}
  citadel.selection_box = {{-2.50, -2.50}, {2.50, 2.50}}
  citadel.drawing_box = {{-3.30, -3.40}, {3.30, 3.15}}
  citadel.surface_conditions = blackstone_platform_only_surface_conditions()
  local build_source = data.raw["assembling-machine"] and (data.raw["assembling-machine"]["crusher"] or data.raw["assembling-machine"]["orbital-trader"])
  if build_source and build_source.tile_buildability_rules then
    citadel.tile_buildability_rules = table.deepcopy(build_source.tile_buildability_rules)
  end
  citadel.heating_energy = "0W"
  citadel.graphics_set = tech_priests_static_machine_graphics_0433(
    "__tech-priests__/graphics/entity/citadel-manufactoreo/citadel-manufactoreo-idle.png",
    "__tech-priests__/graphics/entity/citadel-manufactoreo/citadel-manufactoreo-active.png",
    384,
    384,
    0.50,
    {0, -0.20}
  )
  citadel.working_visualisations = nil
  citadel.integration_patch = nil
  citadel.water_reflection = nil
  data:extend({ citadel })
end



local function copy_platform_buildability(target, preferred_source)
  local build_source = preferred_source
    or (data.raw["assembling-machine"] and data.raw["assembling-machine"]["crusher"])
    or (data.raw["asteroid-collector"] and data.raw["asteroid-collector"]["asteroid-collector"])
    or (data.raw["cargo-bay"] and data.raw["cargo-bay"]["cargo-bay"])
    or (data.raw["space-platform-hub"] and data.raw["space-platform-hub"]["space-platform-hub"])
  if build_source and build_source.tile_buildability_rules then
    target.tile_buildability_rules = table.deepcopy(build_source.tile_buildability_rules)
  end
  target.surface_conditions = blackstone_platform_only_surface_conditions()
  target.heating_energy = "0W"
end

local function make_entropic_extractor()
  if data.raw["burner-generator"] and data.raw["burner-generator"][ENTROPIC_EXTRACTOR] then return end

  local extractor = {
    type = "burner-generator",
    name = ENTROPIC_EXTRACTOR,
    localised_name = { "entity-name.entropic-extractor" },
    localised_description = { "entity-description.entropic-extractor" },
    icon = "__tech-priests__/graphics/icons/entropic-extractor.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 1.0, result = ENTROPIC_EXTRACTOR },
    max_health = 500,
    corpse = "solar-panel-remnants",
    dying_explosion = "solar-panel-explosion",
    collision_box = {{-1.49, -1.49}, {1.49, 1.49}},
    selection_box = {{-1.50, -1.50}, {1.50, 1.50}},
    drawing_box = {{-1.75, -1.85}, {1.75, 1.75}},
    placeable_by = { item = ENTROPIC_EXTRACTOR, count = 1 },
    next_upgrade = nil,
    fast_replaceable_group = nil,

    -- 0.1.434: The Entropic Extractor is no longer a disguised solar panel.
    -- It is a space-platform burner-generator fed only by Entropic Extractor
    -- Blackstone fuel. The private fuel category prevents Blackstone chunks
    -- from being accepted by ordinary burner machines or future generic
    -- Blackstone-powered devices. The chunk stores absurd total energy; this entity meters
    -- that power out slowly so the machine behaves like a reliquary generator,
    -- not a portable reactor detonation politely shaped like a cube.
    burner = {
      type = "burner",
      fuel_categories = { ENTROPIC_BLACKSTONE_FUEL_CATEGORY },
      effectivity = 1.0,
      fuel_inventory_size = 1,
      burnt_inventory_size = 0,
      emissions_per_minute = { pollution = 0 },
      light_flicker = {
        color = { r = 0.20, g = 1.00, b = 0.30 },
        minimum_intensity = 0.15,
        maximum_intensity = 0.65
      }
    },
    energy_source = {
      type = "electric",
      usage_priority = "primary-output",
      buffer_capacity = "20MJ",
      output_flow_limit = "2MW",
      render_no_network_icon = false
    },
    max_power_output = "2MW",
    idle_animation = tech_priests_animation_4way_0433(
      "__tech-priests__/graphics/entity/entropic-extractor/entropic-extractor-idle-sheet.png",
      256,
      256,
      8,
      8,
      0.055,
      0.375,
      {0, 0}
    ),
    animation = tech_priests_animation_4way_0433(
      "__tech-priests__/graphics/entity/entropic-extractor/entropic-extractor-active-sheet.png",
      256,
      256,
      8,
      8,
      0.145,
      0.375,
      {0, 0}
    ),
    always_draw_idle_animation = false,
    working_sound = data.raw.lab and data.raw.lab.lab and table.deepcopy(data.raw.lab.lab.working_sound) or nil
  }

  copy_platform_buildability(extractor)
  data:extend({ extractor })
end


local function make_primitive_steam_items()
  local items = {}
  if not (data.raw.item and data.raw.item[STERLING_STEAM_CATALYZER]) then
    table.insert(items, {
      type = "item",
      name = STERLING_STEAM_CATALYZER,
      localised_name = { "item-name.sterling-steam-catalyzer" },
      localised_description = { "item-description.sterling-steam-catalyzer" },
      icon = "__tech-priests__/graphics/icons/sterling-steam-catalyzer.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "d[hydrogen-thruster]-a[sterling-steam-catalyzer]",
      stack_size = 20,
      place_result = STERLING_STEAM_CATALYZER,
      weight = 100 * kilogram
    })
  end
  if not (data.raw.item and data.raw.item[VOID_STEAM_ENGINE]) then
    table.insert(items, {
      type = "item",
      name = VOID_STEAM_ENGINE,
      localised_name = { "item-name.void-steam-engine" },
      localised_description = { "item-description.void-steam-engine" },
      icon = "__tech-priests__/graphics/icons/void-steam-engine.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "d[hydrogen-thruster]-b[void-steam-engine]",
      stack_size = 20,
      place_result = VOID_STEAM_ENGINE,
      weight = 100 * kilogram
    })
  end
  if #items > 0 then data:extend(items) end
end

local function tech_priests_primitive_steam_animation_0534(name, width, height, scale, shift)
  return {
    layers = {
      {
        filename = "__tech-priests__/graphics/entity/" .. name .. "/" .. name .. "-shadow.png",
        priority = "high",
        width = width,
        height = height,
        frame_count = 1,
        line_length = 1,
        draw_as_shadow = true,
        shift = shift and { (shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08 } or {0.08, 0.08},
        scale = scale
      },
      {
        filename = "__tech-priests__/graphics/entity/" .. name .. "/" .. name .. ".png",
        priority = "high",
        width = width,
        height = height,
        frame_count = 1,
        line_length = 1,
        shift = shift or {0, 0},
        scale = scale
      }
    }
  }
end

local function tech_priests_primitive_boiler_pictures_0534(name, width, height, scale, shift)
  local function picture()
    local art = tech_priests_primitive_steam_animation_0534(name, width, height, scale, shift)
    return { structure = table.deepcopy(art), fire = table.deepcopy(art), fire_glow = table.deepcopy(art) }
  end
  return { north = picture(), east = picture(), south = picture(), west = picture() }
end

local function make_sterling_steam_catalyzer()
  if data.raw.boiler and data.raw.boiler[STERLING_STEAM_CATALYZER] then return end
  local source = data.raw.boiler and data.raw.boiler["boiler"]
  if not source then return end

  local catalyzer = table.deepcopy(source)
  catalyzer.name = STERLING_STEAM_CATALYZER
  catalyzer.localised_name = { "entity-name.sterling-steam-catalyzer" }
  catalyzer.localised_description = { "entity-description.sterling-steam-catalyzer" }
  catalyzer.icon = "__tech-priests__/graphics/icons/sterling-steam-catalyzer.png"
  catalyzer.icon_size = 64
  catalyzer.icons = nil
  catalyzer.minable = { mining_time = 1.0, result = STERLING_STEAM_CATALYZER }
  catalyzer.placeable_by = { item = STERLING_STEAM_CATALYZER, count = 1 }
  catalyzer.next_upgrade = nil
  catalyzer.fast_replaceable_group = nil
  catalyzer.max_health = math.max(catalyzer.max_health or 200, 300)
  -- 0.1.534: new Void Steam Catalyzer art uses a broad two-by-four platform footprint.
  catalyzer.collision_box = {{-1.85, -0.90}, {1.85, 0.90}}
  catalyzer.selection_box = {{-2.0, -1.0}, {2.0, 1.0}}
  catalyzer.energy_consumption = "600kW"
  catalyzer.target_temperature = source.target_temperature or 165
  catalyzer.fluid_box = table.deepcopy(source.fluid_box)
  catalyzer.output_fluid_box = table.deepcopy(source.output_fluid_box)
  if catalyzer.fluid_box then
    catalyzer.fluid_box.production_type = "input"
    catalyzer.fluid_box.pipe_connections = {
      { flow_direction = "input", direction = defines.direction.west, position = {-1.5, 0} }
    }
  end
  if catalyzer.output_fluid_box then
    catalyzer.output_fluid_box.production_type = "output"
    catalyzer.output_fluid_box.pipe_connections = {
      { flow_direction = "output", direction = defines.direction.east, position = {1.5, 0} }
    }
  end
  catalyzer.pictures = tech_priests_primitive_boiler_pictures_0534(STERLING_STEAM_CATALYZER, 1402, 1122, 0.080, {0, -0.05})
  catalyzer.water_reflection = nil
  -- Copy the vanilla burner source so any normal burnable fuel category still works.
  catalyzer.energy_source = table.deepcopy(source.energy_source)
  copy_platform_buildability(catalyzer)
  data:extend({ catalyzer })
end

local function make_void_steam_engine()
  if data.raw.generator and data.raw.generator[VOID_STEAM_ENGINE] then return end
  local source = data.raw.generator and data.raw.generator["steam-engine"]
  if not source then return end

  local engine = table.deepcopy(source)
  engine.name = VOID_STEAM_ENGINE
  engine.localised_name = { "entity-name.void-steam-engine" }
  engine.localised_description = { "entity-description.void-steam-engine" }
  engine.icon = "__tech-priests__/graphics/icons/void-steam-engine.png"
  engine.icon_size = 64
  engine.icons = nil
  local void_steam_engine_animation = tech_priests_primitive_steam_animation_0534(VOID_STEAM_ENGINE, 1024, 1024, 0.074, {0, 0})
  engine.horizontal_animation = table.deepcopy(void_steam_engine_animation)
  engine.vertical_animation = table.deepcopy(void_steam_engine_animation)
  engine.horizontal_frozen_patch = nil
  engine.vertical_frozen_patch = nil
  engine.minable = { mining_time = 1.0, result = VOID_STEAM_ENGINE }
  engine.placeable_by = { item = VOID_STEAM_ENGINE, count = 1 }
  engine.next_upgrade = nil
  engine.fast_replaceable_group = nil
  engine.max_power_output = "300kW"
  engine.maximum_temperature = source.maximum_temperature or 165
  engine.max_health = math.max(engine.max_health or 200, 300)
  -- 0.1.534: new Void Steam Electric Generator art uses a compact two-by-two platform footprint.
  engine.collision_box = {{-0.90, -0.90}, {0.90, 0.90}}
  engine.selection_box = {{-1.0, -1.0}, {1.0, 1.0}}
  engine.fluid_box = table.deepcopy(source.fluid_box)
  if engine.fluid_box then
    engine.fluid_box.production_type = "input"
    engine.fluid_box.pipe_connections = {
      { flow_direction = "input", direction = defines.direction.west, position = {-0.5, 0} }
    }
  end
  engine.water_reflection = nil
  copy_platform_buildability(engine)
  data:extend({ engine })
end

local function make_hydrogen_propellant_fluids()
  local fluids = {}
  if not (data.raw.fluid and data.raw.fluid[LIQUID_HYDROGEN]) then
    table.insert(fluids, {
      type = "fluid",
      name = LIQUID_HYDROGEN,
      localised_name = { "fluid-name.liquid-hydrogen" },
      localised_description = { "fluid-description.liquid-hydrogen" },
      icon = "__tech-priests__/graphics/icons/liquid-hydrogen.png",
      icon_size = 64,
      default_temperature = -253,
      max_temperature = 20,
      heat_capacity = "0.1kJ",
      base_color = { r = 0.35, g = 0.75, b = 1.0 },
      flow_color = { r = 0.65, g = 0.95, b = 1.0 },
      order = "c[hydrogen-propellant]-a[liquid-hydrogen]"
    })
  end
  if not (data.raw.fluid and data.raw.fluid[LIQUID_OXYGEN]) then
    table.insert(fluids, {
      type = "fluid",
      name = LIQUID_OXYGEN,
      localised_name = { "fluid-name.liquid-oxygen" },
      localised_description = { "fluid-description.liquid-oxygen" },
      icon = "__tech-priests__/graphics/icons/liquid-oxygen.png",
      icon_size = 64,
      default_temperature = -183,
      max_temperature = 20,
      heat_capacity = "0.1kJ",
      base_color = { r = 0.65, g = 0.85, b = 1.0 },
      flow_color = { r = 0.82, g = 0.96, b = 1.0 },
      order = "c[hydrogen-propellant]-b[liquid-oxygen]"
    })
  end
  if #fluids > 0 then data:extend(fluids) end
end


local function make_thetazine_items_and_fluids()
  local prototypes = {}

  if not (data.raw.fluid and data.raw.fluid[CARBONIC_ACID]) then
    table.insert(prototypes, {
      type = "fluid",
      name = CARBONIC_ACID,
      localised_name = { "fluid-name.carbonic-acid" },
      localised_description = { "fluid-description.carbonic-acid" },
      icon = "__tech-priests__/graphics/icons/carbonic-acid.png",
      icon_size = 64,
      default_temperature = 15,
      max_temperature = 100,
      heat_capacity = "0.1kJ",
      base_color = { r = 0.25, g = 0.38, b = 0.32 },
      flow_color = { r = 0.48, g = 0.70, b = 0.62 },
      order = "c[thetazine]-a[carbonic-acid]"
    })
  end

  if not (data.raw.item and data.raw.item[IRON_SALTS]) then
    table.insert(prototypes, {
      type = "item",
      name = IRON_SALTS,
      localised_name = { "item-name.iron-salts" },
      localised_description = { "item-description.iron-salts" },
      icon = "__tech-priests__/graphics/icons/iron-salts.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-b[iron-salts]",
      stack_size = 100,
      weight = 2 * kilogram
    })
  end

  if not (data.raw.fluid and data.raw.fluid[MAGNETO_RESONANT_SLURRY]) then
    table.insert(prototypes, {
      type = "fluid",
      name = MAGNETO_RESONANT_SLURRY,
      localised_name = { "fluid-name.magneto-resonant-slurry" },
      localised_description = { "fluid-description.magneto-resonant-slurry" },
      icon = "__tech-priests__/graphics/icons/magneto-resonant-slurry.png",
      icon_size = 64,
      default_temperature = 15,
      max_temperature = 100,
      heat_capacity = "0.2kJ",
      base_color = { r = 0.22, g = 0.06, b = 0.24 },
      flow_color = { r = 0.72, g = 0.22, b = 0.90 },
      order = "c[thetazine]-c[magneto-resonant-slurry]"
    })
  end

  if not (data.raw.fluid and data.raw.fluid[THETAZINE_FUEL]) then
    table.insert(prototypes, {
      type = "fluid",
      name = THETAZINE_FUEL,
      localised_name = { "fluid-name.thetazine-fuel" },
      localised_description = { "fluid-description.thetazine-fuel" },
      icon = "__tech-priests__/graphics/icons/thetazine-fuel.png",
      icon_size = 64,
      default_temperature = 15,
      max_temperature = 500,
      heat_capacity = "0.5kJ",
      fuel_value = "8MJ",
      base_color = { r = 0.65, g = 0.04, b = 0.70 },
      flow_color = { r = 1.0, g = 0.25, b = 0.95 },
      order = "c[thetazine]-d[thetazine-fuel]"
    })
  end

  if not (data.raw.item and data.raw.item[THETAZINE_THRUSTER]) then
    table.insert(prototypes, {
      type = "item",
      name = THETAZINE_THRUSTER,
      localised_name = { "item-name.thetazine-thruster" },
      localised_description = { "item-description.thetazine-thruster" },
      icon = "__tech-priests__/graphics/icons/thetazine-thruster.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-e[thetazine-thruster]",
      stack_size = 10,
      place_result = THETAZINE_THRUSTER,
      weight = 220 * kilogram
    })
  end

  if #prototypes > 0 then data:extend(prototypes) end
end


local function make_void_fusion_thruster_items_and_fluids()
  local prototypes = {}

  if not (data.raw.fluid and data.raw.fluid[VOID_FUSION_THRUSTER_CHARGE]) then
    table.insert(prototypes, {
      type = "fluid",
      name = VOID_FUSION_THRUSTER_CHARGE,
      localised_name = { "fluid-name.void-fusion-thruster-charge" },
      localised_description = { "fluid-description.void-fusion-thruster-charge" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      default_temperature = 15,
      max_temperature = 100,
      heat_capacity = "0.1kJ",
      hidden = true,
      base_color = { r = 0.40, g = 0.05, b = 0.75 },
      flow_color = { r = 0.85, g = 0.45, b = 1.00 },
      order = "c[void-fusion]-a[charge]"
    })
  end

  if not (data.raw.fluid and data.raw.fluid[VOID_FUSION_THRUSTER_REACTION_MASS]) then
    table.insert(prototypes, {
      type = "fluid",
      name = VOID_FUSION_THRUSTER_REACTION_MASS,
      localised_name = { "fluid-name.void-fusion-thruster-reaction-mass" },
      localised_description = { "fluid-description.void-fusion-thruster-reaction-mass" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      default_temperature = 15,
      max_temperature = 100,
      heat_capacity = "0.1kJ",
      hidden = true,
      base_color = { r = 0.05, g = 0.04, b = 0.08 },
      flow_color = { r = 0.35, g = 0.30, b = 0.50 },
      order = "c[void-fusion]-b[reaction-mass]"
    })
  end

  if not (data.raw.item and data.raw.item[VOID_FUSION_THRUSTER]) then
    table.insert(prototypes, {
      type = "item",
      name = VOID_FUSION_THRUSTER,
      localised_name = { "item-name.void-fusion-thruster" },
      localised_description = { "item-description.void-fusion-thruster" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-f[void-fusion-thruster]",
      stack_size = 5,
      place_result = VOID_FUSION_THRUSTER,
      weight = 1000 * kilogram
    })
  end

  if not (data.raw.item and data.raw.item[LARGE_VOID_FUSION_THRUSTER]) then
    table.insert(prototypes, {
      type = "item",
      name = LARGE_VOID_FUSION_THRUSTER,
      localised_name = { "item-name.large-void-fusion-thruster" },
      localised_description = { "item-description.large-void-fusion-thruster" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-g[large-void-fusion-thruster]",
      stack_size = 5,
      place_result = LARGE_VOID_FUSION_THRUSTER,
      weight = 650 * kilogram
    })
  end

  if #prototypes > 0 then data:extend(prototypes) end
end


local function make_hydrogen_thruster_item()
  if data.raw.item and data.raw.item[HYDROGEN_THRUSTER] then return end
  data:extend({
    {
      type = "item",
      name = HYDROGEN_THRUSTER,
      localised_name = { "item-name.hydrogen-thruster" },
      localised_description = { "item-description.hydrogen-thruster" },
      icon = "__tech-priests__/graphics/icons/hydrogen-thruster.png",
      icon_size = 64,
      subgroup = "tech-priest-orbital-trade",
      order = "d[hydrogen-thruster]",
      stack_size = 10,
      place_result = HYDROGEN_THRUSTER,
      weight = 200 * kilogram
    }
  })
end

local function replace_thruster_fluid_filters(value)
  if type(value) ~= "table" then return end
  for k, v in pairs(value) do
    if type(v) == "table" then
      replace_thruster_fluid_filters(v)
    elseif k == "filter" and v == "thruster-fuel" then
      value[k] = LIQUID_HYDROGEN
    elseif k == "filter" and v == "thruster-oxidizer" then
      value[k] = LIQUID_OXYGEN
    end
  end
end


-- 0.1.451: Custom Tech-Priest thruster art no longer matches the vanilla
-- Space Age thruster's inherited footprint/pipe assumptions. Keep placement
-- platform-safe, but stop blindly inheriting vanilla thruster pipe locations.
local function tech_priests_thruster_platform_build_rules_0451()
  -- 0.1.453: true thrusters must use the vanilla thruster edge-placement
  -- doctrine, not generic platform-machine build rules. This preserves the
  -- requirement that the exhaust/bell end hangs over the void.
  local vanilla = data.raw.thruster and data.raw.thruster["thruster"]
  if vanilla and vanilla.tile_buildability_rules then
    return table.deepcopy(vanilla.tile_buildability_rules)
  end
  local build_source = data.raw["assembling-machine"] and data.raw["assembling-machine"]["crusher"]
    or data.raw["asteroid-collector"] and data.raw["asteroid-collector"]["asteroid-collector"]
    or data.raw["cargo-bay"] and data.raw["cargo-bay"]["cargo-bay"]
    or data.raw["space-platform-hub"] and data.raw["space-platform-hub"]["space-platform-hub"]
  if build_source and build_source.tile_buildability_rules then
    return table.deepcopy(build_source.tile_buildability_rules)
  end
  return nil
end

local function tech_priests_apply_hydrogen_thruster_geometry_0451(thruster)
  if type(thruster) ~= "table" then return end

  -- 0.1.454: Hydrogen Thruster is a strict 4x4 platform-edge body.  The
  -- vanilla thruster tile-buildability rules are retained so the lower row of
  -- four tiles is treated as the void/exhaust row while the remaining footprint
  -- must be supported by platform foundation.
  thruster.tile_width = 4
  thruster.tile_height = 4
  thruster.collision_box = {{-1.85, -1.85}, {1.85, 1.85}}
  thruster.selection_box = {{-2.00, -2.00}, {2.00, 2.00}}
  thruster.drawing_box = {{-2.65, -2.95}, {2.65, 4.35}}
  thruster.sticker_box = {{-1.85, -1.85}, {1.85, 1.85}}
  thruster.hit_visualization_box = {{-2.00, -2.00}, {2.00, 2.00}}
  thruster.tile_buildability_rules = tech_priests_thruster_platform_build_rules_0451()
end

local function tech_priests_clamp_pipe_position_inside_collision_box_0452(thruster, position)
  -- 0.1.452: Factorio validates thruster pipe connection positions against
  -- the entity collision box, not the visual/selection box. The requested
  -- hydrogen ports live on the left/right upper shoulders; clamp them inside
  -- the box and let their west/east directions make the pipe connection face
  -- outward instead of placing the point itself outside the legal bounds.
  if not (thruster and type(thruster.collision_box) == "table" and position) then return position end
  local lt = thruster.collision_box[1] or thruster.collision_box.left_top
  local rb = thruster.collision_box[2] or thruster.collision_box.right_bottom
  if not (lt and rb) then return position end
  local min_x = tonumber(lt[1] or lt.x) or -1
  local min_y = tonumber(lt[2] or lt.y) or -1
  local max_x = tonumber(rb[1] or rb.x) or 1
  local max_y = tonumber(rb[2] or rb.y) or 1
  local margin = 0.04
  local x = tonumber(position[1] or position.x) or 0
  local y = tonumber(position[2] or position.y) or 0
  if x < min_x + margin then x = min_x + margin end
  if x > max_x - margin then x = max_x - margin end
  if y < min_y + margin then y = min_y + margin end
  if y > max_y - margin then y = max_y - margin end
  return { x, y }
end

local function tech_priests_make_single_pipe_connection_0451(position, direction)
  local connection = {
    flow_direction = "input",
    position = position
  }
  if defines and defines.direction and direction then
    connection.direction = direction
  end
  return connection
end

local function tech_priests_apply_hydrogen_thruster_fluid_ports_0451(thruster)
  if type(thruster) ~= "table" then return end

  -- User-specified layout: one input on the left and one input on the right,
  -- both near the top of the thruster body and offset one tile downward from
  -- the top edge. For the 4x4 footprint (-2..2), that gives y=-1.0.
  local west = (defines and defines.direction and defines.direction.west) or nil
  local east = (defines and defines.direction and defines.direction.east) or nil

  if type(thruster.fuel_fluid_box) == "table" then
    thruster.fuel_fluid_box.filter = LIQUID_HYDROGEN
    thruster.fuel_fluid_box.production_type = "input"
    thruster.fuel_fluid_box.pipe_connections = {
      tech_priests_make_single_pipe_connection_0451(tech_priests_clamp_pipe_position_inside_collision_box_0452(thruster, {-1.80, -1.00}), west)
    }
  end

  if type(thruster.oxidizer_fluid_box) == "table" then
    thruster.oxidizer_fluid_box.filter = LIQUID_OXYGEN
    thruster.oxidizer_fluid_box.production_type = "input"
    thruster.oxidizer_fluid_box.pipe_connections = {
      tech_priests_make_single_pipe_connection_0451(tech_priests_clamp_pipe_position_inside_collision_box_0452(thruster, {1.80, -1.00}), east)
    }
  end
end

local function tech_priests_hide_thruster_fluid_ports_0451(thruster, fuel_filter, oxidizer_filter)
  if type(thruster) ~= "table" then return end
  if type(thruster.fuel_fluid_box) == "table" then
    thruster.fuel_fluid_box.filter = fuel_filter or thruster.fuel_fluid_box.filter
    thruster.fuel_fluid_box.production_type = "input"
    thruster.fuel_fluid_box.pipe_connections = {}
  end
  if type(thruster.oxidizer_fluid_box) == "table" then
    thruster.oxidizer_fluid_box.filter = oxidizer_filter or thruster.oxidizer_fluid_box.filter
    thruster.oxidizer_fluid_box.production_type = "input"
    thruster.oxidizer_fluid_box.pipe_connections = {}
  end
end


local TECH_PRIESTS_THRUSTER_PERFORMANCE_SCALE_0455 = {
  [HYDROGEN_THRUSTER] = 0.25,
  [THETAZINE_THRUSTER] = 0.45,
  [VOID_FUSION_THRUSTER] = 0.10,
  [LARGE_VOID_FUSION_THRUSTER] = 0.35
}

local function tech_priests_scale_thruster_performance_point_0455(point, scale)
  if type(point) ~= "table" then return end
  scale = tonumber(scale) or 1.0

  -- In Space Age, the thrust-producing performance point exposes effectivity,
  -- fluid_usage, and fluid_volume.  Earlier passes scaled every numeric value
  -- except fluid_volume, which could accidentally compound fuel use and thrust
  -- when a custom thruster was cloned from another custom thruster.  This pass
  -- applies an absolute thrust/efficiency scale by changing effectivity only;
  -- fluid_volume and fluid_usage stay vanilla-shaped so the engine curve remains
  -- predictable and the final speed no longer explodes from inherited multipliers.
  if type(point.effectivity) == "number" then
    point.effectivity = point.effectivity * scale
  else
    for k, v in pairs(point) do
      if type(v) == "number" and k ~= "fluid_volume" and k ~= "fluid_usage" then
        point[k] = v * scale
      end
    end
  end
end

local function tech_priests_apply_absolute_thruster_performance_0455(thruster, scale)
  if type(thruster) ~= "table" then return end
  tech_priests_scale_thruster_performance_point_0455(thruster.min_performance, scale)
  tech_priests_scale_thruster_performance_point_0455(thruster.max_performance, scale)
end

local function tech_priests_vanilla_thruster_source_0455()
  return data.raw.thruster and data.raw.thruster["thruster"] or nil
end

local function make_hydrogen_thruster()
  if data.raw.thruster and data.raw.thruster[HYDROGEN_THRUSTER] then return end
  local source = data.raw.thruster and data.raw.thruster["thruster"]
  if not source then return end

  local thruster = table.deepcopy(source)
  thruster.name = HYDROGEN_THRUSTER
  thruster.localised_name = { "entity-name.hydrogen-thruster" }
  thruster.localised_description = { "entity-description.hydrogen-thruster" }
  thruster.icon = "__tech-priests__/graphics/icons/hydrogen-thruster.png"
  thruster.icon_size = 64
  thruster.icons = nil
  thruster.minable = { mining_time = 1.0, result = HYDROGEN_THRUSTER }
  thruster.placeable_by = { item = HYDROGEN_THRUSTER, count = 1 }
  thruster.next_upgrade = nil
  thruster.fast_replaceable_group = nil
  thruster.surface_conditions = blackstone_platform_only_surface_conditions()
  thruster.heating_energy = "0W"

  tech_priests_apply_hydrogen_thruster_geometry_0451(thruster)
  replace_thruster_fluid_filters(thruster)
  tech_priests_strip_thruster_pipe_visual_gates_0439(thruster)
  tech_priests_apply_hydrogen_thruster_fluid_ports_0451(thruster)

  -- 0.1.455: absolute performance scale from vanilla.  Primitive hydrogen
  -- should be visibly functional but not a platform catapult.
  tech_priests_apply_absolute_thruster_performance_0455(thruster, TECH_PRIESTS_THRUSTER_PERFORMANCE_SCALE_0455[HYDROGEN_THRUSTER])


  thruster.graphics_set = tech_priests_thruster_graphics_0433(
    "__tech-priests__/graphics/entity/hydrogen-thruster/hydrogen-thruster-idle.png",
    "__tech-priests__/graphics/entity/hydrogen-thruster/hydrogen-thruster-run.png",
    256,
    512,
    7,
    7,
    0.18,
    0.54,
    {0, 1.25}
  )
  thruster.animation = nil
  thruster.animations = nil
  thruster.working_visualisations = nil

  data:extend({ thruster })
end


local function make_thetazine_thruster()
  if data.raw.thruster and data.raw.thruster[THETAZINE_THRUSTER] then return end
  local source = tech_priests_vanilla_thruster_source_0455()
  if not source then return end

  local thruster = table.deepcopy(source)
  thruster.name = THETAZINE_THRUSTER
  thruster.localised_name = { "entity-name.thetazine-thruster" }
  thruster.localised_description = { "entity-description.thetazine-thruster" }
  thruster.icon = "__tech-priests__/graphics/icons/thetazine-thruster.png"
  thruster.icon_size = 64
  thruster.icons = nil
  thruster.minable = { mining_time = 1.0, result = THETAZINE_THRUSTER }
  thruster.placeable_by = { item = THETAZINE_THRUSTER, count = 1 }
  thruster.next_upgrade = nil
  thruster.fast_replaceable_group = nil
  thruster.surface_conditions = blackstone_platform_only_surface_conditions()
  thruster.heating_energy = "0W"
  thruster.tile_buildability_rules = tech_priests_thruster_platform_build_rules_0451()

  if thruster.fuel_fluid_box then
    thruster.fuel_fluid_box.filter = THETAZINE_FUEL
  end
  if thruster.oxidizer_fluid_box then
    thruster.oxidizer_fluid_box.filter = "water"
  end

  -- If this was cloned from a vanilla thruster, recursively replace the normal
  -- propellant filters. If it was cloned from the hydrogen thruster, replace the
  -- hydrogen/oxygen pair as well.
  local function replace_filters(value)
    if type(value) ~= "table" then return end
    for k, v in pairs(value) do
      if type(v) == "table" then
        replace_filters(v)
      elseif k == "filter" and (v == "thruster-fuel" or v == LIQUID_HYDROGEN) then
        value[k] = THETAZINE_FUEL
      elseif k == "filter" and (v == "thruster-oxidizer" or v == LIQUID_OXYGEN) then
        value[k] = "water"
      end
    end
  end
  replace_filters(thruster)
  tech_priests_strip_thruster_pipe_visual_gates_0439(thruster)

  -- 0.1.455: clone from vanilla and apply an absolute Thetazine scale so the
  -- chain cannot inherit Hydrogen's edited numbers and then multiply again.
  tech_priests_apply_absolute_thruster_performance_0455(thruster, TECH_PRIESTS_THRUSTER_PERFORMANCE_SCALE_0455[THETAZINE_THRUSTER])

  -- 0.1.453: cleaned Thetazine art is not the tiny half-scale placeholder; it
  -- needs a wider live footprint and a lower visual origin. Keep its fuel rules,
  -- but abandon the old blanket 50% shrink pass.
  thruster.tile_width = 5
  thruster.tile_height = 5
  thruster.collision_box = {{-2.35, -2.35}, {2.35, 2.35}}
  thruster.selection_box = {{-2.50, -2.50}, {2.50, 2.50}}
  thruster.drawing_box = {{-3.35, -3.30}, {3.35, 4.95}}
  thruster.sticker_box = {{-2.35, -2.35}, {2.35, 2.35}}
  thruster.hit_visualization_box = {{-2.50, -2.50}, {2.50, 2.50}}
  thruster.tile_buildability_rules = tech_priests_thruster_platform_build_rules_0451()

  thruster.graphics_set = tech_priests_thruster_graphics_0433(
    "__tech-priests__/graphics/entity/thetazine-thruster/thetazine-thruster-idle.png",
    "__tech-priests__/graphics/entity/thetazine-thruster/thetazine-thruster-run.png",
    256,
    512,
    2,
    2,
    0.12,
    0.55,
    {0, 1.65}
  )
  thruster.animation = nil
  thruster.animations = nil
  thruster.working_visualisations = nil
  thruster.picture = nil
  thruster.pictures = nil

  data:extend({ thruster })
end


local function make_void_fusion_thruster_power_sink()
  if data.raw["electric-energy-interface"] and data.raw["electric-energy-interface"][VOID_FUSION_THRUSTER_POWER_SINK] then return end
  data:extend({
    {
      type = "electric-energy-interface",
      name = VOID_FUSION_THRUSTER_POWER_SINK,
      localised_name = { "entity-name.void-fusion-thruster-power-sink" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      flags = { "not-blueprintable", "not-deconstructable", "not-on-map", "not-selectable-in-game", "placeable-off-grid" },
      hidden = true,
      hidden_in_factoriopedia = true,
      selectable_in_game = false,
      collision_box = {{0, 0}, {0, 0}},
      collision_mask = { layers = {} },
      selection_box = {{0, 0}, {0, 0}},
      minable = nil,
      max_health = 1,
      energy_source = {
        type = "electric",
        buffer_capacity = "30MJ",
        input_flow_limit = "30MW",
        output_flow_limit = "0W",
        usage_priority = "secondary-input",
        render_no_network_icon = false,
        render_no_power_icon = false,
        drain = "0W"
      },
      energy_production = "0W",
      energy_usage = "12MW",
      gui_mode = "none",
      picture = {
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        priority = "extra-high"
      },
      surface_conditions = blackstone_platform_only_surface_conditions()
    }
  })
end

local function tech_priests_prepare_void_fusion_thruster_electric_drive_0454(thruster, result_item_name, performance_scale)
  if type(thruster) ~= "table" then return end

  -- The Void-Fusion family is intentionally treated as electric/ritual drive
  -- hardware in play. Its internal working fluids are script-serviced; do not
  -- expose pipe ports on the visible entity.
  tech_priests_hide_thruster_fluid_ports_0451(thruster, VOID_FUSION_THRUSTER_CHARGE, VOID_FUSION_THRUSTER_REACTION_MASS)

  local function replace_filters(value)
    if type(value) ~= "table" then return end
    for k, v in pairs(value) do
      if type(v) == "table" then
        replace_filters(v)
      elseif k == "filter" and (v == "thruster-fuel" or v == LIQUID_HYDROGEN or v == THETAZINE_FUEL) then
        value[k] = VOID_FUSION_THRUSTER_CHARGE
      elseif k == "filter" and (v == "thruster-oxidizer" or v == LIQUID_OXYGEN or v == "water") then
        value[k] = VOID_FUSION_THRUSTER_REACTION_MASS
      end
    end
  end
  replace_filters(thruster)
  tech_priests_strip_thruster_pipe_visual_gates_0439(thruster)
  tech_priests_hide_thruster_fluid_ports_0451(thruster, VOID_FUSION_THRUSTER_CHARGE, VOID_FUSION_THRUSTER_REACTION_MASS)

  tech_priests_apply_absolute_thruster_performance_0455(thruster, performance_scale or 1.0)

  thruster.minable = { mining_time = 2.0, result = result_item_name or thruster.name }
  thruster.placeable_by = { item = result_item_name or thruster.name, count = 1 }
  thruster.next_upgrade = nil
  thruster.fast_replaceable_group = nil
  thruster.surface_conditions = blackstone_platform_only_surface_conditions()
  thruster.heating_energy = "0W"
  thruster.tile_buildability_rules = tech_priests_thruster_platform_build_rules_0451()
  thruster.animation = nil
  thruster.animations = nil
  thruster.shadow = nil
  thruster.working_visualisations = nil
end

local function make_void_fusion_thruster()
  if data.raw.thruster and data.raw.thruster[VOID_FUSION_THRUSTER] then return end
  local source = tech_priests_vanilla_thruster_source_0455()
  if not source then return end

  local thruster = table.deepcopy(source)
  thruster.name = VOID_FUSION_THRUSTER
  thruster.localised_name = { "entity-name.void-fusion-thruster" }
  thruster.localised_description = { "entity-description.void-fusion-thruster" }
  thruster.icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png"
  thruster.icon_size = 64
  thruster.icons = nil

  -- 0.1.454: restore the original thin one-by-nine void-drive spine.  This is
  -- the long sealed electric relic, not the new wide large thruster.
  thruster.tile_width = 1
  thruster.tile_height = 9
  thruster.collision_box = {{-0.45, -4.45}, {0.45, 4.45}}
  thruster.selection_box = {{-0.50, -4.50}, {0.50, 4.50}}
  thruster.drawing_box = {{-1.35, -5.25}, {1.35, 5.25}}
  thruster.sticker_box = {{-0.45, -4.45}, {0.45, 4.45}}
  thruster.hit_visualization_box = {{-0.50, -4.50}, {0.50, 4.50}}

  -- 0.1.455: thin one-by-nine void spine has very high thrust density per
  -- platform-width tile, so it must be a precision drive, not a main engine.
  tech_priests_prepare_void_fusion_thruster_electric_drive_0454(thruster, VOID_FUSION_THRUSTER, TECH_PRIESTS_THRUSTER_PERFORMANCE_SCALE_0455[VOID_FUSION_THRUSTER])

  thruster.graphics_set = tech_priests_thruster_graphics_0433(
    "__tech-priests__/graphics/entity/void-fusion-thruster/void-fusion-thruster-idle.png",
    "__tech-priests__/graphics/entity/void-fusion-thruster/void-fusion-thruster-run.png",
    192,
    576,
    2,
    2,
    0.08,
    0.50,
    {0, -0.10}
  )

  data:extend({ thruster })
end

local function make_large_void_fusion_thruster()
  if data.raw.thruster and data.raw.thruster[LARGE_VOID_FUSION_THRUSTER] then return end
  local source = tech_priests_vanilla_thruster_source_0455()
  if not source then return end

  local thruster = table.deepcopy(source)
  thruster.name = LARGE_VOID_FUSION_THRUSTER
  thruster.localised_name = { "entity-name.large-void-fusion-thruster" }
  thruster.localised_description = { "entity-description.large-void-fusion-thruster" }
  thruster.icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png"
  thruster.icon_size = 64
  thruster.icons = nil

  -- 0.1.454: preserve the useful 0.1.453 wide rework as a separate large
  -- electric Void-Fusion Thruster. It shares the Hydrogen Thruster's 4x4 edge
  -- footprint and remains no-pipe/electric-proxy serviced.
  thruster.tile_width = 4
  thruster.tile_height = 4
  thruster.collision_box = {{-1.85, -1.85}, {1.85, 1.85}}
  thruster.selection_box = {{-2.00, -2.00}, {2.00, 2.00}}
  thruster.drawing_box = {{-2.85, -2.95}, {2.85, 4.35}}
  thruster.sticker_box = {{-1.85, -1.85}, {1.85, 1.85}}
  thruster.hit_visualization_box = {{-2.00, -2.00}, {2.00, 2.00}}

  -- 0.1.455: large wide electric variant is the stronger Void-Fusion drive,
  -- but still far below vanilla thruster output to avoid runaway platform speed.
  tech_priests_prepare_void_fusion_thruster_electric_drive_0454(thruster, LARGE_VOID_FUSION_THRUSTER, TECH_PRIESTS_THRUSTER_PERFORMANCE_SCALE_0455[LARGE_VOID_FUSION_THRUSTER])

  thruster.graphics_set = tech_priests_thruster_graphics_0433(
    "__tech-priests__/graphics/entity/void-fusion-thruster/void-fusion-thruster-wide-idle.png",
    "__tech-priests__/graphics/entity/void-fusion-thruster/void-fusion-thruster-wide-run.png",
    384,
    512,
    1,
    1,
    0.08,
    0.40,
    {0, 1.25}
  )

  data:extend({ thruster })
end

local function pick_existing_technology(candidates, fallback)
  for _, name in ipairs(candidates or {}) do
    if data.raw.technology and data.raw.technology[name] then return name end
  end
  return fallback
end

local function add_hydrogen_thruster_recipes_and_technology()
  if data.raw.recipe and data.raw.recipe["water-electrolysis"] then return end

  data:extend({
    {
      type = "recipe",
      name = "water-electrolysis",
      localised_name = { "recipe-name.water-electrolysis" },
      category = "chemistry",
      enabled = false,
      energy_required = 20,
      ingredients = { { type = "fluid", name = "water", amount = 100 } },
      results = {
        { type = "fluid", name = LIQUID_HYDROGEN, amount = 20 },
        { type = "fluid", name = LIQUID_OXYGEN, amount = 10 }
      },
      main_product = LIQUID_HYDROGEN,
      subgroup = "tech-priest-orbital-trade",
      order = "d[hydrogen-propellant]-a[water-electrolysis]"
    },
    {
      type = "recipe",
      name = STERLING_STEAM_CATALYZER,
      localised_name = { "recipe-name.sterling-steam-catalyzer" },
      icon = "__tech-priests__/graphics/icons/sterling-steam-catalyzer.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 12,
      ingredients = {
        { type = "item", name = "boiler", amount = 1 },
        { type = "item", name = "offworld-cogitator-components", amount = 2 },
        { type = "item", name = "servitor-parts", amount = 1 },
        { type = "item", name = "pipe", amount = 10 }
      },
      results = { { type = "item", name = STERLING_STEAM_CATALYZER, amount = 1 } }
    },
    {
      type = "recipe",
      name = VOID_STEAM_ENGINE,
      localised_name = { "recipe-name.void-steam-engine" },
      icon = "__tech-priests__/graphics/icons/void-steam-engine.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 12,
      ingredients = {
        { type = "item", name = "steam-engine", amount = 1 },
        { type = "item", name = "offworld-cogitator-components", amount = 2 },
        { type = "item", name = "servitor-parts", amount = 1 },
        { type = "item", name = "pipe", amount = 10 }
      },
      results = { { type = "item", name = VOID_STEAM_ENGINE, amount = 1 } }
    },
    {
      type = "recipe",
      name = HYDROGEN_THRUSTER,
      localised_name = { "recipe-name.hydrogen-thruster" },
      icon = "__tech-priests__/graphics/icons/hydrogen-thruster.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 20,
      ingredients = {
        { type = "item", name = "steam-engine", amount = 4 },
        { type = "item", name = "offworld-cogitator-components", amount = 5 },
        { type = "item", name = "servitor-parts", amount = 2 },
        { type = "item", name = "pipe", amount = 20 }
      },
      results = { { type = "item", name = HYDROGEN_THRUSTER, amount = 1 } }
    },
    {
      type = "technology",
      name = "hydrogen-thruster-propulsion",
      icon = "__tech-priests__/graphics/icons/hydrogen-thruster.png",
      icon_size = 64,
      prerequisites = {
        pick_existing_technology({ "space-platform-thruster", "space-platform" }, "space-platform"),
        "blackstone-citadel-manufacture"
      },
      effects = {
        { type = "unlock-recipe", recipe = "water-electrolysis" },
        { type = "unlock-recipe", recipe = STERLING_STEAM_CATALYZER },
        { type = "unlock-recipe", recipe = VOID_STEAM_ENGINE },
        { type = "unlock-recipe", recipe = HYDROGEN_THRUSTER }
      },
      unit = {
        count = 350,
        ingredients = {
          { "automation-science-pack", 1 },
          { "logistic-science-pack", 1 },
          { "chemical-science-pack", 1 },
          { "space-science-pack", 1 }
        },
        time = 45
      },
      order = "c-m-d[hydrogen-thruster]"
    }
  })
end


local function add_thetazine_recipes_and_technology()
  if data.raw.recipe and data.raw.recipe["thetazine-fuel-from-blackstone-slurry"] then return end

  local recipes = {
    {
      type = "recipe",
      name = "carbonic-acid-from-pure-carbon",
      localised_name = { "recipe-name.carbonic-acid-from-pure-carbon" },
      category = "chemistry",
      enabled = false,
      energy_required = 8,
      ingredients = {
        { type = "item", name = "pure-carbon", amount = 2 },
        { type = "fluid", name = LIQUID_HYDROGEN, amount = 50 }
      },
      results = { { type = "fluid", name = CARBONIC_ACID, amount = 50 } },
      main_product = CARBONIC_ACID,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-a[carbonic-acid-pure-carbon]"
    },
    {
      type = "recipe",
      name = "iron-salts-from-carbonic-acid",
      localised_name = { "recipe-name.iron-salts-from-carbonic-acid" },
      icon = "__tech-priests__/graphics/icons/iron-salts.png",
      icon_size = 64,
      category = "chemistry",
      enabled = false,
      energy_required = 6,
      ingredients = {
        { type = "fluid", name = CARBONIC_ACID, amount = 50 },
        { type = "item", name = "iron-ore", amount = 5 }
      },
      results = { { type = "item", name = IRON_SALTS, amount = 5 } },
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-b[iron-salts]"
    },
    {
      type = "recipe",
      name = "magneto-resonant-slurry",
      localised_name = { "recipe-name.magneto-resonant-slurry" },
      category = "chemistry",
      enabled = false,
      energy_required = 8,
      ingredients = {
        { type = "item", name = IRON_SALTS, amount = 5 },
        { type = "item", name = "sacred-machine-oil", amount = 1 }
      },
      results = { { type = "fluid", name = MAGNETO_RESONANT_SLURRY, amount = 50 } },
      main_product = MAGNETO_RESONANT_SLURRY,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-c[magneto-resonant-slurry]"
    },
    {
      type = "recipe",
      name = "thetazine-fuel-from-blackstone-slurry",
      localised_name = { "recipe-name.thetazine-fuel-from-blackstone-slurry" },
      category = "chemistry",
      enabled = false,
      energy_required = 10,
      ingredients = {
        { type = "fluid", name = MAGNETO_RESONANT_SLURRY, amount = 50 },
        { type = "item", name = BLACKSTONE_SLAB, amount = 1 }
      },
      results = { { type = "fluid", name = THETAZINE_FUEL, amount = 1000 } },
      main_product = THETAZINE_FUEL,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-d[thetazine-fuel]"
    },
    {
      type = "recipe",
      name = THETAZINE_THRUSTER,
      localised_name = { "recipe-name.thetazine-thruster" },
      icon = "__tech-priests__/graphics/icons/thetazine-thruster.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 24,
      ingredients = {
        { type = "item", name = HYDROGEN_THRUSTER, amount = 1 },
        { type = "item", name = "offworld-cogitator-components", amount = 8 },
        { type = "item", name = "servitor-parts", amount = 4 },
        { type = "item", name = IRON_SALTS, amount = 10 },
        { type = "item", name = "pipe", amount = 30 }
      },
      results = { { type = "item", name = THETAZINE_THRUSTER, amount = 1 } },
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-e[thetazine-thruster]"
    }
  }

  if data.raw.item and data.raw.item["carbon"] then
    table.insert(recipes, 1, {
      type = "recipe",
      name = "carbonic-acid-from-carbon",
      localised_name = { "recipe-name.carbonic-acid-from-carbon" },
      category = "chemistry",
      enabled = false,
      energy_required = 8,
      ingredients = {
        { type = "item", name = "carbon", amount = 2 },
        { type = "fluid", name = LIQUID_HYDROGEN, amount = 50 }
      },
      results = { { type = "fluid", name = CARBONIC_ACID, amount = 60 } },
      main_product = CARBONIC_ACID,
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-a[carbonic-acid-carbon]"
    })
  end

  local effects = {
    { type = "unlock-recipe", recipe = "carbonic-acid-from-pure-carbon" },
    { type = "unlock-recipe", recipe = "iron-salts-from-carbonic-acid" },
    { type = "unlock-recipe", recipe = "magneto-resonant-slurry" },
    { type = "unlock-recipe", recipe = "thetazine-fuel-from-blackstone-slurry" },
    { type = "unlock-recipe", recipe = THETAZINE_THRUSTER }
  }
  if data.raw.item and data.raw.item["carbon"] then
    table.insert(effects, 1, { type = "unlock-recipe", recipe = "carbonic-acid-from-carbon" })
  end

  table.insert(recipes, {
    type = "technology",
    name = "thetazine-propulsion",
    icon = "__tech-priests__/graphics/icons/thetazine-fuel.png",
    icon_size = 64,
    prerequisites = {
      "hydrogen-thruster-propulsion",
      "blackstone-citadel-manufacture",
      "efficient-sacred-oil-rendering"
    },
    effects = effects,
    unit = {
      count = 500,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "space-science-pack", 1 }
      },
      time = 60
    },
    order = "c-m-e[thetazine-propulsion]"
  })

  data:extend(recipes)
end


local function add_void_fusion_thruster_recipe_and_technology()
  local prerequisites = { "thetazine-propulsion", "blackstone-citadel-manufacture" }
  local fusion_tech = pick_existing_technology({ "fusion-reactor-equipment", "fusion-reactor", "fusion-power" }, nil)
  if fusion_tech then table.insert(prerequisites, fusion_tech) end
  local lightning_tech = pick_existing_technology({ "lightning-collector", "planet-discovery-fulgora" }, nil)
  if lightning_tech then table.insert(prerequisites, lightning_tech) end

  local additions = {}

  if not (data.raw.recipe and data.raw.recipe[VOID_FUSION_THRUSTER]) then
    table.insert(additions, {
      type = "recipe",
      name = VOID_FUSION_THRUSTER,
      localised_name = { "recipe-name.void-fusion-thruster" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 60,
      ingredients = {
        { type = "item", name = "void-sealed-cargo", amount = 80 },
        { type = "item", name = BLACKSTONE_SLAB, amount = 24 },
        { type = "item", name = "lightning-rod", amount = 16 },
        { type = "item", name = "fusion-reactor-equipment", amount = 8 }
      },
      results = { { type = "item", name = VOID_FUSION_THRUSTER, amount = 1 } },
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-f[void-fusion-thruster]"
    })
  end

  if not (data.raw.recipe and data.raw.recipe[LARGE_VOID_FUSION_THRUSTER]) then
    table.insert(additions, {
      type = "recipe",
      name = LARGE_VOID_FUSION_THRUSTER,
      localised_name = { "recipe-name.large-void-fusion-thruster" },
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 45,
      ingredients = {
        { type = "item", name = "void-sealed-cargo", amount = 48 },
        { type = "item", name = BLACKSTONE_SLAB, amount = 14 },
        { type = "item", name = "lightning-rod", amount = 8 },
        { type = "item", name = "fusion-reactor-equipment", amount = 4 }
      },
      results = { { type = "item", name = LARGE_VOID_FUSION_THRUSTER, amount = 1 } },
      subgroup = "tech-priest-orbital-trade",
      order = "e[thetazine]-g[large-void-fusion-thruster]"
    })
  end

  if not (data.raw.technology and data.raw.technology["void-fusion-thruster-propulsion"]) then
    table.insert(additions, {
      type = "technology",
      name = "void-fusion-thruster-propulsion",
      icon = "__tech-priests__/graphics/icons/void-fusion-thruster.png",
      icon_size = 64,
      prerequisites = prerequisites,
      effects = {
        { type = "unlock-recipe", recipe = VOID_FUSION_THRUSTER },
        { type = "unlock-recipe", recipe = LARGE_VOID_FUSION_THRUSTER }
      },
      unit = {
        count = 800,
        ingredients = {
          { "automation-science-pack", 1 },
          { "logistic-science-pack", 1 },
          { "chemical-science-pack", 1 },
          { "space-science-pack", 1 }
        },
        time = 75
      },
      order = "c-m-f[void-fusion-thruster]"
    })
  elseif data.raw.technology["void-fusion-thruster-propulsion"] then
    local tech = data.raw.technology["void-fusion-thruster-propulsion"]
    tech.effects = tech.effects or {}
    local function ensure_unlock(recipe_name)
      for _, effect in pairs(tech.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return end
      end
      table.insert(tech.effects, { type = "unlock-recipe", recipe = recipe_name })
    end
    ensure_unlock(VOID_FUSION_THRUSTER)
    ensure_unlock(LARGE_VOID_FUSION_THRUSTER)
  end

  if #additions > 0 then data:extend(additions) end
end

local function add_blackstone_recipes_and_technology()
  if data.raw.recipe and data.raw.recipe["blackstone-fragment-from-asteroid-chunk"] then return end

  data:extend({
    {
      type = "recipe",
      name = CITADEL_MANUFACTOREO,
      icon = "__tech-priests__/graphics/icons/citadel-manufactoreo.png",
      icon_size = 64,
      category = "crafting",
      enabled = false,
      energy_required = 20,
      ingredients = {
        { type = "item", name = "steel-plate", amount = 100 },
        { type = "item", name = "processing-unit", amount = 20 },
        { type = "item", name = "low-density-structure", amount = 20 },
        { type = "item", name = "offworld-cogitator-components", amount = 10 },
        { type = "item", name = "relic-fragment", amount = 2 },
        { type = "item", name = "sacred-machine-oil", amount = 50 }
      },
      results = { { type = "item", name = CITADEL_MANUFACTOREO, amount = 1 } }
    },
    {
      type = "recipe",
      name = "blackstone-fragment-from-asteroid-chunk",
      localised_name = { "recipe-name.blackstone-fragment-from-asteroid-chunk" },
      icon = BLACKSTONE_ICON,
      icon_size = 64,
      category = "citadel-manufactoreo",
      enabled = false,
      energy_required = 8,
      ingredients = { { type = "item", name = BLACKSTONE_CHUNK, amount = 1 } },
      results = {
        { type = "item", name = BLACKSTONE_FRAGMENT, amount = 1 },
        { type = "item", name = "stone", amount = 1, probability = 0.25 }
      },
      main_product = BLACKSTONE_FRAGMENT
    },
    {
      type = "recipe",
      name = "blackstone-slab-compression",
      localised_name = { "recipe-name.blackstone-slab-compression" },
      icon = BLACKSTONE_ICON,
      icon_size = 64,
      category = "citadel-manufactoreo",
      enabled = false,
      energy_required = 20,
      ingredients = {
        { type = "item", name = BLACKSTONE_FRAGMENT, amount = 10 },
        { type = "item", name = "sacred-machine-oil", amount = 5 }
      },
      results = { { type = "item", name = BLACKSTONE_SLAB, amount = 1 } }
    },
    {
      type = "recipe",
      name = ENTROPIC_EXTRACTOR,
      localised_name = { "recipe-name.entropic-extractor" },
      icon = "__tech-priests__/graphics/icons/entropic-extractor.png",
      icon_size = 64,
      category = "citadel-manufactoreo",
      enabled = false,
      energy_required = 30,
      ingredients = {
        { type = "item", name = "offworld-cogitator-components", amount = 5 },
        { type = "item", name = "servitor-parts", amount = 4 },
        { type = "item", name = BLACKSTONE_SLAB, amount = 1 }
      },
      results = { { type = "item", name = ENTROPIC_EXTRACTOR, amount = 1 } }
    },
    {
      type = "technology",
      name = "blackstone-citadel-manufacture",
      icon = BLACKSTONE_ICON,
      icon_size = 64,
      prerequisites = { "orbital-relic-procurement", "space-platform" },
      effects = {
        { type = "unlock-recipe", recipe = CITADEL_MANUFACTOREO },
        { type = "unlock-recipe", recipe = "blackstone-fragment-from-asteroid-chunk" },
        { type = "unlock-recipe", recipe = "blackstone-slab-compression" },
        { type = "unlock-recipe", recipe = ENTROPIC_EXTRACTOR }
      },
      unit = {
        count = 500,
        ingredients = {
          { "automation-science-pack", 1 },
          { "logistic-science-pack", 1 },
          { "chemical-science-pack", 1 },
          { "space-science-pack", 1 }
        },
        time = 45
      },
      order = "c-m-c[blackstone]"
    }
  })
end

local function copy_spawn_points_scaled(spawn_points, scale)
  local points = table.deepcopy(spawn_points or {})
  for _, point in pairs(points) do
    if point.probability then
      point.probability = math.max(0, point.probability * scale)
    end
  end
  return points
end

local function has_spawn_definition(definitions, asteroid_name)
  for _, def in pairs(definitions or {}) do
    if def.asteroid == asteroid_name then return true end
  end
  return false
end

local function find_spawn_definition(definitions, candidates)
  for _, candidate in ipairs(candidates or {}) do
    for _, def in pairs(definitions or {}) do
      if def.asteroid == candidate then return def end
    end
  end
  return nil
end

local function add_blackstone_space_spawns()
  local asteroid_candidates_by_size = {
    small = { "small-metallic-asteroid", "small-carbonic-asteroid", "small-oxide-asteroid" },
    medium = { "medium-metallic-asteroid", "medium-carbonic-asteroid", "medium-oxide-asteroid" },
    big = { "big-metallic-asteroid", "big-carbonic-asteroid", "big-oxide-asteroid" },
    huge = { "huge-metallic-asteroid", "huge-carbonic-asteroid", "huge-oxide-asteroid" }
  }
  local size_scale = { small = 0.0025, medium = 0.0075, big = 0.020, huge = 0.045 }

  for _, connection in pairs(data.raw["space-connection"] or {}) do
    connection.asteroid_spawn_definitions = connection.asteroid_spawn_definitions or {}
    for size, candidates in pairs(asteroid_candidates_by_size) do
      local blackstone_name = size .. "-blackstone-asteroid"
      if data.raw.asteroid and data.raw.asteroid[blackstone_name] and not has_spawn_definition(connection.asteroid_spawn_definitions, blackstone_name) then
        local base_def = find_spawn_definition(connection.asteroid_spawn_definitions, candidates)
        if base_def and base_def.spawn_points then
          table.insert(connection.asteroid_spawn_definitions, {
            type = "entity",
            asteroid = blackstone_name,
            spawn_points = copy_spawn_points_scaled(base_def.spawn_points, size_scale[size] or 0.005)
          })
        end
      end
    end
  end

  for _, location in pairs(data.raw["space-location"] or {}) do
    location.asteroid_spawn_definitions = location.asteroid_spawn_definitions or location.asteroid_spawn_definitions
    if type(location.asteroid_spawn_definitions) == "table" and not has_spawn_definition(location.asteroid_spawn_definitions, BLACKSTONE_CHUNK) then
      local base_def = find_spawn_definition(location.asteroid_spawn_definitions, { "metallic-asteroid-chunk", "carbonic-asteroid-chunk", "oxide-asteroid-chunk" })
      if base_def then
        table.insert(location.asteroid_spawn_definitions, {
          type = "asteroid-chunk",
          asteroid = BLACKSTONE_CHUNK,
          probability = math.max(0, (base_def.probability or 0.01) * 0.01),
          speed = base_def.speed or 0.016
        })
      end
    end
  end
end

make_blackstone_particle_family()
tech_priests_ensure_blackstone_particle_family_0544()
make_blackstone_asteroid_chunk()
make_blackstone_asteroids()
make_citadel_manufactoreo()
make_entropic_extractor()
make_hydrogen_propellant_fluids()
make_thetazine_items_and_fluids()
make_void_fusion_thruster_items_and_fluids()
make_primitive_steam_items()
make_sterling_steam_catalyzer()
make_void_steam_engine()
make_hydrogen_thruster_item()
make_hydrogen_thruster()
make_thetazine_thruster()
make_void_fusion_thruster_power_sink()
make_void_fusion_thruster()
make_large_void_fusion_thruster()
add_blackstone_recipes_and_technology()
add_hydrogen_thruster_recipes_and_technology()
add_thetazine_recipes_and_technology()
add_void_fusion_thruster_recipe_and_technology()
add_blackstone_space_spawns()

set_weight(BLACKSTONE_CHUNK, 40 * kilogram)
set_weight(BLACKSTONE_FRAGMENT, 25 * kilogram)
set_weight(BLACKSTONE_SLAB, 250 * kilogram)
set_weight(CITADEL_MANUFACTOREO, 750 * kilogram)
set_weight(ENTROPIC_EXTRACTOR, 100 * kilogram)
set_weight(HYDROGEN_THRUSTER, 200 * kilogram)
set_weight(STERLING_STEAM_CATALYZER, 100 * kilogram)
set_weight(VOID_STEAM_ENGINE, 100 * kilogram)
set_weight(IRON_SALTS, 2 * kilogram)
set_weight(THETAZINE_THRUSTER, 220 * kilogram)
set_weight(VOID_FUSION_THRUSTER, 1000 * kilogram)
set_weight(LARGE_VOID_FUSION_THRUSTER, 650 * kilogram)
