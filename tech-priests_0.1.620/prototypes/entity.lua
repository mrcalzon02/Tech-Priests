-- Tech Priests - entity prototypes.
-- 0.1.30: use vanilla substation death explosion for Cogitator Stations.

local util = require("util")
local smoke_animations = require("__base__.prototypes.entity.smoke-animations")

local substation_source = data.raw["electric-pole"] and data.raw["electric-pole"]["substation"]

local MR_BASE_PATH = "__mechanicus-reborn__/images/"
local MODEL_SCALE = 0.65


-- 0.1.385: Martian emergency micro-machinery now uses mod-owned provisional
-- art paths instead of borrowing base-game icons/world sprites. These are not
-- final Alpha Art replacements; they are custom in-mod scaffolds so the coming
-- art pass can replace scale-aware 1x1/2x2 micro-machine graphics without
-- inheriting oversized vanilla machine art.
local MARTIAN_MICRO_ICON_SIZE = 128
local MARTIAN_MICRO_ICON_PATH = "__tech-priests__/graphics/icons/martian-micro/"
local MARTIAN_MICRO_ENTITY_PATH = "__tech-priests__/graphics/entity/martian-micro/"

local MARTIAN_MICRO_SPRITE_DIMS = {
  ["tech-priests-atmospheric-water-condenser"] = {1254, 1254},
  ["tech-priests-emergency-miner"] = {1254, 1254},
  ["tech-priests-emergency-assembler"] = {1254, 1254},
  ["tech-priests-emergency-laboratorium"] = {1254, 1254},
  ["tech-priests-emergency-smelter"] = {1254, 1254},
  ["tech-priests-emergency-power-grid"] = {1254, 1254},
  ["tech-priests-emergency-steam-engine"] = {1024, 1024},
  ["tech-priests-emergency-boiler"] = {1024, 1024}
}

local COGITATOR_STATION_ART_0534 = {
  ["junior-cogitator-station"] = {
    filename = "__tech-priests__/graphics/entity/cogitator-station/junior-cogitator-station.png",
    icon = "__tech-priests__/graphics/icons/junior-cogitator-station.png",
    width = 1027,
    height = 1532,
    scale = 0.090,
    shift = util.by_pixel(0, -22)
  },
  ["senior-cogitator-station"] = {
    filename = "__tech-priests__/graphics/entity/cogitator-station/senior-cogitator-station.png",
    icon = "__tech-priests__/graphics/icons/senior-cogitator-station.png",
    width = 1024,
    height = 1536,
    scale = 0.090,
    shift = util.by_pixel(0, -30)
  },
  ["planetary-magos-cogitator-station"] = {
    filename = "__tech-priests__/graphics/entity/cogitator-station/planetary-magos-cogitator-station.png",
    icon = "__tech-priests__/graphics/icons/planetary-magos-cogitator-station.png",
    width = 1024,
    height = 1536,
    scale = 0.092,
    -- 0.1.546: live testing showed the 0.1.544/0.1.545 downward correction overshot and made
    -- the platform sit below its selection frame.  Raise it back toward the frame midpoint while
    -- keeping it lower than the old hovering placement.
    shift = util.by_pixel(0, -18)
  },
  ["void-cogitator-station"] = {
    filename = "__tech-priests__/graphics/entity/cogitator-station/void-cogitator-station.png",
    icon = "__tech-priests__/graphics/icons/void-cogitator-station.png",
    width = 1024,
    height = 1536,
    scale = 0.092,
    shift = util.by_pixel(0, -20)
  }
}

local function tech_priests_micro_sprite_dims(name)
  return MARTIAN_MICRO_SPRITE_DIMS[name] or { MARTIAN_MICRO_ICON_SIZE, MARTIAN_MICRO_ICON_SIZE }
end

local function tech_priests_micro_icon_path(name)
  return MARTIAN_MICRO_ICON_PATH .. name .. ".png"
end

local function tech_priests_micro_sprite_path(name)
  return MARTIAN_MICRO_ENTITY_PATH .. name .. ".png"
end

local function tech_priests_micro_shadow_path(name)
  return MARTIAN_MICRO_ENTITY_PATH .. name .. "-shadow.png"
end

local function tech_priests_micro_sprite_layer(name, scale, shift)
  local dims = tech_priests_micro_sprite_dims(name)
  return {
    filename = tech_priests_micro_sprite_path(name),
    priority = "high",
    width = dims[1],
    height = dims[2],
    frame_count = 1,
    line_length = 1,
    shift = shift or { 0, 0 },
    scale = scale or 0.04
  }
end

local function tech_priests_micro_shadow_layer(name, scale, shift)
  local dims = tech_priests_micro_sprite_dims(name)
  return {
    filename = tech_priests_micro_shadow_path(name),
    priority = "high",
    width = dims[1],
    height = dims[2],
    frame_count = 1,
    line_length = 1,
    shift = shift or { 0.08, 0.08 },
    scale = scale or 0.04,
    draw_as_shadow = true
  }
end

local function tech_priests_micro_animation(name, scale, shift)
  return {
    layers = {
      tech_priests_micro_shadow_layer(name, scale, shift and { (shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08 } or { 0.08, 0.08 }),
      tech_priests_micro_sprite_layer(name, scale, shift)
    }
  }
end

local function tech_priests_micro_sprite(name, scale, shift)
  return {
    layers = {
      tech_priests_micro_shadow_layer(name, scale, shift and { (shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08 } or { 0.08, 0.08 }),
      tech_priests_micro_sprite_layer(name, scale, shift)
    }
  }
end

-- Electric-pole pictures are validated as RotatedSprite definitions, not as
-- ordinary animation sprites. Every layer needs a direction_count matching the
-- connection-point cardinality. Keep this helper separate from generic micro
-- animations so assemblers/labs/etc. do not accidentally inherit pole-only
-- sprite fields.
local function tech_priests_micro_pole_picture(name, scale, shift, direction_count)
  local count = direction_count or 1
  local shadow_shift = shift and { (shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08 } or { 0.08, 0.08 }
  return {
    layers = {
      {
        filename = tech_priests_micro_shadow_path(name),
        priority = "high",
        width = tech_priests_micro_sprite_dims(name)[1],
        height = tech_priests_micro_sprite_dims(name)[2],
        direction_count = count,
        line_length = count,
        shift = shadow_shift,
        scale = scale or 0.25,
        draw_as_shadow = true
      },
      {
        filename = tech_priests_micro_sprite_path(name),
        priority = "high",
        width = tech_priests_micro_sprite_dims(name)[1],
        height = tech_priests_micro_sprite_dims(name)[2],
        direction_count = count,
        line_length = count,
        shift = shift or { 0, 0 },
        scale = scale or 0.25
      }
    }
  }
end

local function tech_priests_apply_micro_icon(entity, name)
  entity.icon = tech_priests_micro_icon_path(name)
  entity.icon_size = MARTIAN_MICRO_ICON_SIZE
  entity.icons = nil
end

local function tech_priests_apply_micro_crafting_art(entity, name, scale)
  tech_priests_apply_micro_icon(entity, name)
  entity.graphics_set = {
    animation = tech_priests_micro_animation(name, scale or 0.25)
  }
  entity.graphics_set_flipped = nil
  entity.animation = nil
  entity.animations = nil
  entity.integration_patch = nil
  entity.water_reflection = nil
end

local function tech_priests_micro_boiler_pictures(name, scale)
  local function picture()
    return {
      structure = tech_priests_micro_animation(name, scale or 0.32),
      fire = tech_priests_micro_animation(name, scale or 0.32),
      fire_glow = tech_priests_micro_animation(name, scale or 0.32)
    }
  end
  return {
    north = picture(),
    east = picture(),
    south = picture(),
    west = picture()
  }
end

local TIER_DEFS = {
  {
    key = "junior",
    order = "a",
    station_name = "junior-cogitator-station",
    priest_name = "junior-tech-priest",
    immune_priest_name = "junior-tech-priest-belt-immune",
    corpse_name = "junior-tech-priest-corpse",
    station_health = 500,
    priest_health = 150,
    inventory_size = 4, -- 0.1.529: base +2 working slots
    tint = { r = 1.0, g = 0.58, b = 0.18, a = 1.0 }
  },
  {
    key = "intermediate",
    order = "b",
    station_name = "intermediate-cogitator-station",
    priest_name = "intermediate-tech-priest",
    immune_priest_name = "intermediate-tech-priest-belt-immune",
    corpse_name = "intermediate-tech-priest-corpse",
    station_health = 1000,
    priest_health = 300,
    inventory_size = 5, -- 0.1.529: base +2 working slots
    tint = { r = 0.70, g = 0.70, b = 0.70, a = 1.0 }
  },
  {
    key = "senior",
    order = "c",
    station_name = "senior-cogitator-station",
    priest_name = "senior-tech-priest",
    immune_priest_name = "senior-tech-priest-belt-immune",
    corpse_name = "senior-tech-priest-corpse",
    station_health = 2000,
    priest_health = 600,
    inventory_size = 6, -- 0.1.529: base +2 working slots
    tint = { r = 0.92, g = 0.10, b = 0.08, a = 1.0 }
  },
  {
    key = "planetary-magos",
    order = "d",
    station_name = "planetary-magos-cogitator-station",
    priest_name = "planetary-magos-tech-priest",
    immune_priest_name = "planetary-magos-tech-priest-belt-immune",
    corpse_name = "planetary-magos-tech-priest-corpse",
    station_health = 2600,
    priest_health = 850,
    inventory_size = 7, -- 0.1.529: base +2 working slots
    tint = { r = 0.08, g = 0.07, b = 0.06, a = 1.0 }
  },
  {
    key = "void",
    order = "e",
    station_name = "void-cogitator-station",
    priest_name = "void-tech-priest",
    immune_priest_name = "void-tech-priest-belt-immune",
    corpse_name = "void-tech-priest-corpse",
    station_health = 2600,
    priest_health = 850,
    inventory_size = 7, -- 0.1.529: base +2 working slots
    -- A pale void-duty tint: mostly white, but still recognizably robed.
    tint = { r = 1.00, g = 0.96, b = 0.86, a = 1.0 }
  }
}

local function soften_station_tint_0311(tint)
  tint = tint or { r = 1, g = 1, b = 1, a = 1 }
  -- Station tints should echo the priest rank color without becoming a flat,
  -- solid recolor.  Blend toward white so the Cogitator art still reads.
  local blend = 0.42
  return {
    r = 1.0 - ((1.0 - (tint.r or 1.0)) * blend),
    g = 1.0 - ((1.0 - (tint.g or 1.0)) * blend),
    b = 1.0 - ((1.0 - (tint.b or 1.0)) * blend),
    a = 1.0
  }
end

local function make_station(def)
  local station = table.deepcopy(data.raw["container"]["steel-chest"])
  station.name = def.station_name
  station.localised_name = { "entity-name." .. def.station_name }
  station.localised_description = { "entity-description." .. def.station_name }
  station.icon = nil
  station.icon_size = nil
  local station_art_0534 = COGITATOR_STATION_ART_0534[def.station_name]
  station.icons = {
    {
      icon = (station_art_0534 and station_art_0534.icon) or "__tech-priests__/graphics/icons/cogitator-station.png",
      icon_size = 64,
      tint = soften_station_tint_0311(def.tint)
    }
  }
  station.minable = { mining_time = 0.4, result = def.station_name }
  station.max_health = def.station_health
  station.inventory_size = def.inventory_size
  station.corpse = (substation_source and substation_source.corpse) or "medium-remnants"
  station.dying_explosion = (substation_source and substation_source.dying_explosion) or "substation-explosion"
  station.open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.43 }
  station.close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.43 }

  -- Borrow the vanilla substation footprint so the temporary Cogitator sprite occupies
  -- and occludes world space like the structure it visually resembles. The station
  -- remains a container: no hidden power node and no electric-pole behavior.
  if substation_source then
    station.collision_box = table.deepcopy(substation_source.collision_box)
    station.selection_box = table.deepcopy(substation_source.selection_box)
    station.drawing_box_vertical_extension = substation_source.drawing_box_vertical_extension
    station.collision_mask = table.deepcopy(substation_source.collision_mask)

    -- Keep container circuit-network behavior, but move the red/green wire attachment
    -- to the substation-style wire point when available. This lets the station read
    -- as an inventory on the circuit network without pretending to distribute power.
    station.circuit_wire_max_distance = substation_source.maximum_wire_distance or station.circuit_wire_max_distance
    station.draw_circuit_wires = true
    station.draw_copper_wires = false
    if station.circuit_connector and substation_source.connection_points and substation_source.connection_points[1] then
      station.circuit_connector = table.deepcopy(station.circuit_connector)
      station.circuit_connector.points = table.deepcopy(substation_source.connection_points[1])
    end
  end

  local cogitator_layers = {}

  -- Restore the vanilla substation shadow as a separate shadow layer. The station
  -- remains a container; this only gives the custom Cogitator artwork its ground
  -- contact back instead of making it behave as an electric pole.
  if substation_source and substation_source.pictures and substation_source.pictures.layers then
    for _, layer in pairs(substation_source.pictures.layers) do
      if layer.draw_as_shadow then
        table.insert(cogitator_layers, table.deepcopy(layer))
        break
      end
    end
  end

  table.insert(cogitator_layers, {
    filename = (station_art_0534 and station_art_0534.filename) or "__tech-priests__/graphics/entity/cogitator-station/cogitator-station.png",
    priority = "high",
    width = (station_art_0534 and station_art_0534.width) or 184,
    height = (station_art_0534 and station_art_0534.height) or 270,
    x = 0,
    y = 0,
    -- 0.1.534: station-specific alpha art where supplied; Intermediate keeps the old default Cogitator sprite.
    shift = (station_art_0534 and station_art_0534.shift) or util.by_pixel(0, -28),
    scale = (station_art_0534 and station_art_0534.scale) or 0.50,
    tint = soften_station_tint_0311(def.tint)
  })

  station.picture = {
    layers = cogitator_layers
  }

  -- Prototype-side radius hint. The runtime script draws the real current radius,
  -- including force research bonuses, when the station is selected.
  station.radius_visualisation_specification = {
    distance = 20,
    sprite = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1
    }
  }

  return station
end

local function sprite(filename, animation_speed, shadow, tint)
  local layer = {
    filename = MR_BASE_PATH .. filename,
    width = 150,
    height = 160,
    shift = util.by_pixel(shadow and 20 or 0, shadow and -8 or -21),
    frame_count = 22,
    direction_count = 8,
    animation_speed = animation_speed,
    scale = MODEL_SCALE
  }
  if shadow then
    layer.draw_as_shadow = true
  end
  if tint then
    layer.tint = tint
  end
  return layer
end

local function make_animation(main_file, shadow_file, speed, tint)
  return {
    layers = {
      sprite(main_file, speed, false, tint),
      sprite(shadow_file, speed, true, nil)
    }
  }
end

local function make_priest_corpse(def)
  local priest_corpse = table.deepcopy((data.raw["corpse"] and (data.raw["corpse"]["character-corpse"] or data.raw["corpse"]["small-biter-corpse"])) or data.raw["simple-entity"]["simple-entity-with-force"])
  priest_corpse.type = "corpse"
  priest_corpse.name = def.corpse_name
  priest_corpse.localised_name = { "entity-name." .. def.corpse_name }
  priest_corpse.icon = "__base__/graphics/icons/repair-pack.png"
  priest_corpse.icon_size = 64
  priest_corpse.flags = { "placeable-neutral", "not-on-map" }
  priest_corpse.selectable_in_game = false
  priest_corpse.collision_box = {{0, 0}, {0, 0}}
  priest_corpse.selection_box = {{0, 0}, {0, 0}}
  priest_corpse.collision_mask = { layers = {} }
  priest_corpse.time_before_removed = 60 * 30
  priest_corpse.time_before_shading_off = 60 * 10

  local priest_dead_animation = {
    filename = MR_BASE_PATH .. "level1_dead.png",
    width = 150,
    height = 160,
    frame_count = 2,
    direction_count = 1,
    animation_speed = 0.05,
    shift = util.by_pixel(0, -21),
    scale = MODEL_SCALE,
    tint = def.tint
  }

  priest_corpse.animation = priest_dead_animation
  priest_corpse.decay_animation = table.deepcopy(priest_dead_animation)
  priest_corpse.direction_shuffle = nil
  priest_corpse.shuffle_directions_at_frame = nil
  priest_corpse.ground_patch = nil
  priest_corpse.ground_patch_higher = nil
  priest_corpse.dying_speed = 0.04
  return priest_corpse
end

local function make_priest(def, belt_immune)
  -- Baseline adepts were too slow to reliably escape even basic transport-belt
  -- nonsense. Give every visible Tech-Priest a small default mobility increase,
  -- then let the post-Senior rite swap them to true belt-immune prototypes.
  local run_animation_speed = belt_immune and 0.92 or 0.82
  local idle_gun_animation_speed = belt_immune and 0.36 or 0.32
  local priest_run_animation = make_animation("level1_running.png", "level1_running_shadow.png", run_animation_speed, def.tint)
  local priest_gun_idle_animation = make_animation("level1_idle_gun.png", "level1_idle_gun_shadow.png", idle_gun_animation_speed, def.tint)

  local base_unit = data.raw["unit"]["compilatron"] or data.raw["unit"]["small-biter"]
  local player_character = data.raw["character"] and data.raw["character"]["character"]
  local priest = table.deepcopy(base_unit)
  priest.name = belt_immune and def.immune_priest_name or def.priest_name
  priest.icon = "__base__/graphics/icons/repair-pack.png"
  priest.icon_size = 64
  priest.localised_name = { "entity-name." .. priest.name }
  priest.localised_description = { "entity-description." .. priest.name }
  priest.max_health = def.priest_health
  priest.resistances = {
    { type = "physical", decrease = 1, percent = 10 },
    { type = "fire", percent = 20 }
  }
  priest.distraction_cooldown = 300
  priest.vision_distance = 18
  -- 0.1.466: the temporary movement-audit crawl proved too slow for behavior-tree validation.
  -- Keep priests visibly deliberate, but fast enough that target acquisition, combat
  -- preemption, and return-to-station behavior can be observed in one live test pass.
  -- 0.1.518: movement cadence testing showed priests could appear painfully slow
  -- once every action became a real walk/ritual/repair phase.  Raise the
  -- baseline unit speed modestly while keeping the deliberate Tech-Priest gait.
  priest.movement_speed = belt_immune and 0.095 or 0.080
  priest.distance_per_frame = belt_immune and 0.145 or 0.125
  priest.has_belt_immunity = belt_immune and true or false
  priest.affected_by_tiles = false

  -- Void Tech-Priests are not walkers. Their runtime doctrine treats them as
  -- maneuvering-pack attendants, so their prototype is made as non-obstructive
  -- as Factorio safely allows. Planetary priests keep their normal unit body.
  if def.key == "void" then
    priest.has_belt_immunity = true
    priest.collision_box = {{0, 0}, {0, 0}}
    priest.selection_box = {{-0.35, -0.75}, {0.35, 0.20}}
    priest.collision_mask = { layers = {} }
    priest.movement_speed = 0.001
    priest.distance_per_frame = 0.001
    priest.ai_settings = priest.ai_settings or {}
    priest.ai_settings.do_separation = false
  end
  priest.absorptions_to_join_attack = { pollution = 0 }
  priest.corpse = def.corpse_name
  priest.dying_explosion = nil
  priest.minable = nil
  priest.flags = { "placeable-player", "placeable-off-grid", "not-repairable" }
  priest.run_animation = priest_run_animation

  -- The visible Tech-Priest is cloned from a commandable unit so it can be
  -- ordered around by script, but it must not keep inherited biter/creature
  -- vocalizations. Pull safe humanoid damage/death audio from the vanilla
  -- character where the prototype field exists, and silence the rest.
  priest.working_sound = nil
  priest.created_sound = nil
  priest.mined_sound = nil
  priest.sound = nil
  priest.alert_when_damaged = true
  priest.dying_sound = player_character and player_character.dying_sound and table.deepcopy(player_character.dying_sound) or nil
  priest.damaged_trigger_effect = player_character and player_character.damaged_trigger_effect and table.deepcopy(player_character.damaged_trigger_effect) or nil

  -- The Tech-Priest's real ranged damage is handled by the hidden ammo-turret proxy.
  -- This native unit attack exists so the visible priest can enter its weapon animation.
  priest.attack_parameters = {
    type = "projectile",
    range = 15,
    cooldown = 30,
    ammo_category = "melee",
    ammo_type = {
      target_type = "entity",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          target_effects = {
            { type = "damage", damage = { amount = 0.01, type = "physical" } }
          }
        }
      }
    },
    animation = priest_gun_idle_animation,
    sound = nil
  }

  priest.water_reflection = nil
  -- 0.1.509: Tech-Priests are scripted workers, not expendable biter attack units.
  -- The base prototype may inherit UnitAISettings from compilatron/small-biter.
  -- If destroy_when_commands_fail remains true, Factorio may invalidate the
  -- visible priest after repeated failed go-to-location commands.  Lock all
  -- priest variants to non-disposable, non-spawner, non-attack-group AI.
  priest.ai_settings = priest.ai_settings or {}
  priest.ai_settings.destroy_when_commands_fail = false
  priest.ai_settings.allow_try_return_to_spawner = false
  priest.ai_settings.do_separation = false
  priest.ai_settings.join_attacks = false
  priest.ai_settings.path_resolution_modifier = priest.ai_settings.path_resolution_modifier or 0
  return priest
end

-- Hidden small-arms proxy. The visible Tech-Priest remains the moving unit;
-- this ammo turret exists only so Factorio can resolve real bullet-category
-- ammunition, including weird modded bullet effects, through the normal turret path.
local proxy = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
proxy.name = "tech-priest-small-arms-proxy"
proxy.localised_name = { "entity-name.tech-priest-small-arms-proxy" }
proxy.localised_description = { "entity-description.tech-priest-small-arms-proxy" }
proxy.icon = "__base__/graphics/icons/gun-turret.png"
proxy.icon_size = 64
proxy.flags = {
  "placeable-off-grid",
  "not-on-map",
  "not-deconstructable",
  "not-blueprintable",
  "not-repairable",
  "not-flammable",
  "hide-alt-info"
}
proxy.minable = nil
proxy.max_health = 250
proxy.corpse = nil
proxy.dying_explosion = nil
proxy.collision_box = {{0, 0}, {0, 0}}
proxy.selection_box = {{0, 0}, {0, 0}}
proxy.collision_mask = { layers = {} }
proxy.alert_when_attacking = false
proxy.call_for_help_radius = 0
proxy.energy_source = nil
proxy.energy_consumption = nil
proxy.automated_ammo_count = 10
proxy.inventory_size = 1
proxy.attack_parameters = table.deepcopy(data.raw["ammo-turret"]["gun-turret"].attack_parameters)
proxy.attack_parameters.range = 15
proxy.attack_parameters.min_range = 0
proxy.attack_parameters.cooldown = 6
proxy.attack_parameters.ammo_category = "bullet"
proxy.selectable_in_game = false
proxy.hidden = true
proxy.hidden_in_factoriopedia = true
proxy.drawing_box_vertical_extension = 0

local empty_sprite = {
  filename = "__core__/graphics/empty.png",
  priority = "extra-high",
  width = 1,
  height = 1,
  frame_count = 1,
  direction_count = 1
}
local empty_animation = { layers = { empty_sprite } }
proxy.folded_animation = empty_animation
proxy.preparing_animation = empty_animation
proxy.prepared_animation = empty_animation
proxy.attacking_animation = empty_animation
proxy.folding_animation = empty_animation
proxy.base_picture = empty_animation
proxy.integration = empty_animation
proxy.graphics_set = {
  base_visualisation = { animation = empty_animation },
  animation = empty_animation
}


local function make_orbital_trader()
  local trader = table.deepcopy(data.raw["assembling-machine"] and (data.raw["assembling-machine"]["assembling-machine-3"] or data.raw["assembling-machine"]["assembling-machine-2"] or data.raw["assembling-machine"]["assembling-machine-1"]))
  if not trader then return nil end

  trader.name = "orbital-trader"
  trader.localised_name = { "entity-name.orbital-trader" }
  trader.localised_description = { "entity-description.orbital-trader" }
  -- Alpha/Master Art 0.1.395: Orbital Trader animation track intentionally abandoned. Use the accepted production sprite key as a static-only entity. No working_visualisations are defined until a proper separately authored animation set exists.
  trader.icon = "__tech-priests__/graphics/icons/orbital-trader.png"
  trader.icon_size = 128
  trader.icons = nil
  trader.minable = { mining_time = 1.0, result = "orbital-trader" }
  trader.max_health = 1200
  trader.crafting_categories = { "orbital-trader" }
  trader.crafting_speed = 1
  trader.energy_usage = "750kW"
  trader.module_slots = 0
  trader.allowed_effects = {}
  trader.result_inventory_size = 8
  trader.selection_box = { { -3.0, -3.0 }, { 3.0, 3.0 } }
  trader.collision_box = { { -2.7, -2.7 }, { 2.7, 2.7 } }
  trader.next_upgrade = nil
  trader.fast_replaceable_group = nil

  -- Do NOT blindly copy cargo-landing-pad graphics_set.animation here.
  -- In Space Age that table may expose a small working visualisation/fan/radiator
  -- layer rather than the full pad body when transplanted onto an assembling-machine,
  -- which made the Orbital Trader render as only a spinning radiator.
  -- Use a stable internal static body sprite until the full cargo-pad sprite schema is
  -- mapped explicitly.
  trader.graphics_set = {
    animation = {
      layers = {
        {
          filename = "__tech-priests__/graphics/entity/orbital-trader/orbital-trader.png",
          priority = "high",
          width = 384,
          height = 384,
          frame_count = 1,
          shift = util.by_pixel(0, -8),
          scale = 0.5
        },
        {
          filename = "__tech-priests__/graphics/entity/orbital-trader/orbital-trader-shadow.png",
          priority = "high",
          width = 384,
          height = 384,
          frame_count = 1,
          draw_as_shadow = true,
          shift = util.by_pixel(18, 4),
          scale = 0.5
        }
      }
    }
  }

  return trader
end



local SACRED_INCENSE_SMOKE_TINT = { r = 0.82, g = 0.82, b = 0.78, a = 0.030 }
local SACRED_INCENSE_SMOKE_TINT_SOFT = { r = 0.78, g = 0.78, b = 0.74, a = 0.020 }
local SACRED_INCENSE_SMOKE_TINT_FAINT = { r = 0.70, g = 0.70, b = 0.66, a = 0.012 }
local SACRED_INCENSE_SMOKE_ANIMATION_SPEED = 1 / 120
local SACRED_INCENSE_CLOUD_DURATION_TICKS = 60 * 20

local MACHINE_DAMAGE_SMOKE_TINT = { r = 0.18, g = 0.15, b = 0.12, a = 0.52 }
local MACHINE_DAMAGE_SMOKE_CLOUD_TINT = { r = 0.16, g = 0.14, b = 0.12, a = 0.34 }
local MACHINE_DAMAGE_SMOKE_ANIMATION_SPEED = 1 / 7
local PRIEST_TRANSLOCATION_SMOKE_TINT = { r = 0.58, g = 0.54, b = 0.48, a = 0.16 }
local PRIEST_TRANSLOCATION_SMOKE_ANIMATION_SPEED = 1 / 9

local function make_machine_damage_smoke()
  -- Visible, short-lived impact smoke for actual machine injury events. This is
  -- intentionally larger and longer than the nearly invisible 0.1.102 puff, but
  -- still a local event effect rather than a map-covering factory fire.
  return
  {
    type = "explosion",
    name = "tech-priests-machine-damage-smoke",
    localised_name = { "entity-name.tech-priests-machine-damage-smoke" },
    flags = { "not-on-map" },
    hidden = true,
    subgroup = "explosions",
    render_layer = "higher-object-above",
    fade_out_duration = 70,
    scale_out_duration = 55,
    scale_in_duration = 5,
    scale_initial = 0.06,
    scale = 0.42,
    scale_deviation = 0.04,
    scale_increment_per_tick = 0.0024,
    correct_rotation = true,
    scale_animation_speed = true,
    animations =
    {
      {
        width = 152,
        height = 120,
        line_length = 5,
        frame_count = 60,
        shift = {-0.53125, -0.4375},
        priority = "high",
        animation_speed = MACHINE_DAMAGE_SMOKE_ANIMATION_SPEED,
        tint = MACHINE_DAMAGE_SMOKE_TINT,
        filename = "__base__/graphics/entity/smoke/smoke.png",
        flags = { "smoke", "linear-magnification" }
      }
    }
  }
end

local function make_machine_damage_smoke_cloud()
  -- A second, trivial-smoke layer makes the event visible even when the
  -- explosion puff is partly hidden by entity sprites. It lingers briefly as a
  -- dirty local cough and then fades before repeated damage can blanket the map.
  return
  {
    type = "trivial-smoke",
    name = "tech-priests-machine-damage-smoke-cloud",
    localised_name = { "entity-name.tech-priests-machine-damage-smoke-cloud" },
    flags = { "not-on-map" },
    hidden = true,
    show_when_smoke_off = true,
    duration = 110,
    fade_in_duration = 6,
    fade_away_duration = 50,
    spread_duration = 65,
    start_scale = 0.08,
    end_scale = 0.54,
    render_layer = "higher-object-above",
    color = MACHINE_DAMAGE_SMOKE_CLOUD_TINT,
    affected_by_wind = false,
    cyclic = true,
    animation = smoke_animations.trivial_smoke_fast
    {
      animation_speed = 1 / 20,
      scale = 0.70,
      tint = MACHINE_DAMAGE_SMOKE_CLOUD_TINT,
      flags = { "smoke", "linear-magnification" }
    }
  }
end

local function make_priest_translocation_smoke()
  -- Ritual arrival/departure puff for Tech-Priests. This is intentionally a
  -- very short event effect, not a cloud: it starts tiny, pops open quickly,
  -- and vanishes before mass station recalls can stack into a smoke bank.
  return
  {
    type = "explosion",
    name = "tech-priests-priest-translocation-smoke",
    localised_name = { "entity-name.tech-priests-priest-translocation-smoke" },
    flags = { "not-on-map" },
    hidden = true,
    subgroup = "explosions",
    render_layer = "higher-object-above",
    fade_out_duration = 10,
    scale_out_duration = 12,
    scale_in_duration = 2,
    scale_initial = 0.035,
    scale = 0.38,
    scale_deviation = 0.035,
    scale_increment_per_tick = 0.006,
    correct_rotation = true,
    scale_animation_speed = true,
    animations =
    {
      {
        width = 152,
        height = 120,
        line_length = 5,
        frame_count = 60,
        shift = {-0.53125, -0.4375},
        priority = "high",
        animation_speed = PRIEST_TRANSLOCATION_SMOKE_ANIMATION_SPEED,
        tint = PRIEST_TRANSLOCATION_SMOKE_TINT,
        filename = "__base__/graphics/entity/smoke/smoke.png",
        flags = { "smoke", "linear-magnification" }
      }
    }
  }
end


local function make_sacred_incense_trivial_smoke_animation(scale, tint)
  -- New base direction: use the same base smoke-animation helper family used by
  -- the vanilla atomic bomb smoke definition, but keep only the smoke body. The
  -- incense grenade deliberately does not create nuke glare, shockwaves, scorch,
  -- damage, fire, or mushroom-cloud entities.
  return smoke_animations.trivial_smoke_fast
  {
    animation_speed = SACRED_INCENSE_SMOKE_ANIMATION_SPEED,
    scale = scale,
    tint = tint,
    flags = { "smoke", "linear-magnification" }
  }
end

local function make_sacred_incense_cloud_variant(name, smoke_tint, animation_scale, start_scale, end_scale, duration_ticks)
  return
  {
    type = "trivial-smoke",
    name = name,
    localised_name = { "entity-name.sacred-incense-cloud" },
    flags = { "not-on-map" },
    hidden = true,
    show_when_smoke_off = true,
    duration = duration_ticks or SACRED_INCENSE_CLOUD_DURATION_TICKS,
    fade_in_duration = 120,
    fade_away_duration = 60 * 8,
    spread_duration = 60 * 17,
    start_scale = start_scale,
    end_scale = end_scale,
    render_layer = "higher-object-under",
    color = smoke_tint,
    affected_by_wind = false,
    cyclic = true,
    movement_slow_down_factor = 0,
    animation = make_sacred_incense_trivial_smoke_animation(animation_scale, smoke_tint)
  }
end

local function make_sacred_incense_cloud()
  return make_sacred_incense_cloud_variant(
    "sacred-incense-cloud",
    SACRED_INCENSE_SMOKE_TINT,
    3.25,
    0.70,
    5.80,
    60 * 20
  )
end

local function make_sacred_incense_cloud_soft()
  return make_sacred_incense_cloud_variant(
    "sacred-incense-cloud-soft",
    SACRED_INCENSE_SMOKE_TINT_SOFT,
    2.75,
    0.55,
    4.80,
    60 * 20
  )
end

local function make_sacred_incense_cloud_faint()
  return make_sacred_incense_cloud_variant(
    "sacred-incense-cloud-faint",
    SACRED_INCENSE_SMOKE_TINT_FAINT,
    2.15,
    0.40,
    3.70,
    60 * 18
  )
end

local function make_sacred_machine_oil_projectile()
  return {
    type = "projectile",
    name = "sacred-machine-oil-projectile",
    localised_name = { "entity-name.sacred-machine-oil-projectile" },
    flags = { "not-on-map" },
    acceleration = 0.01,
    animation = {
      filename = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
      width = 64,
      height = 64,
      frame_count = 1,
      scale = 0.18
    },
    action = {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = {
          { type = "script", effect_id = "tech-priests-sacred-oil-impact" }
        }
      }
    },
    final_action = nil
  }
end


local function make_tech_priests_data_spike_projectile_0590()
  return {
    type = "projectile",
    name = "tech-priests-data-spike-projectile",
    localised_name = { "entity-name.tech-priests-data-spike-projectile" },
    flags = { "not-on-map" },
    acceleration = 0.02,
    animation = {
      filename = "__tech-priests__/graphics/icons/data-spike.png",
      width = 64,
      height = 64,
      frame_count = 1,
      scale = 0.24
    },
    action = {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = {
          { type = "script", effect_id = "tech-priests-data-spike-impact" }
        }
      }
    },
    final_action = nil
  }
end

local function make_sacred_incense_projectile()
  local source = data.raw["projectile"] and (data.raw["projectile"]["poison-capsule"] or data.raw["projectile"]["grenade"])
  local projectile

  if source then
    projectile = table.deepcopy(source)
  else
    projectile = {
      type = "projectile",
      flags = { "not-on-map" },
      acceleration = 0.005,
      animation = {
        filename = "__tech-priests__/graphics/icons/sacred-incense-grenade.png",
        width = 64,
        height = 64,
        frame_count = 1,
        scale = 0.25
      }
    }
  end

  projectile.name = "sacred-incense-projectile"
  projectile.localised_name = { "entity-name.sacred-incense-projectile" }
  projectile.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "script", effect_id = "tech-priests-sacred-incense-impact" }
      }
    }
  }
  projectile.final_action = nil

  return projectile
end



-- Hidden logistics bridge entities. The visible Cogitator Station intentionally
-- remains a normal circuit-readable container. These invisible helper chests let
-- construction/logistic robots do the hauling through the real logistics system:
-- requester cache receives wanted goods, active-provider return cache takes
-- unwanted goods back out when the tiny station inventory is clogged.
local function make_hidden_logistic_cache(base_name, name, mode)
  local base = data.raw["logistic-container"] and data.raw["logistic-container"][base_name]
  if not base then return nil end
  local cache = table.deepcopy(base)
  cache.name = name
  cache.localised_name = { "entity-name." .. name }
  cache.localised_description = { "entity-description." .. name }
  -- Factorio 2.0 no longer guarantees the old logistic chest icon file
  -- names such as __base__/graphics/icons/logistic-chest-active-provider.png.
  -- Since this cache is a deepcopy of the real base prototype, preserve whatever
  -- icon/icons definition that prototype uses instead of hardcoding a path.
  if base.icons then
    cache.icons = table.deepcopy(base.icons)
    cache.icon = nil
    cache.icon_size = nil
  else
    cache.icon = base.icon or "__core__/graphics/empty.png"
    cache.icon_size = base.icon_size or 64
  end
  cache.flags = {
    "placeable-off-grid",
    "not-on-map",
    "not-deconstructable",
    "not-blueprintable",
    "not-repairable",
    "not-flammable",
    "hide-alt-info"
  }
  cache.hidden = true
  cache.hidden_in_factoriopedia = true
  cache.minable = nil
  cache.max_health = 100000
  cache.inventory_size = 12
  cache.request_slot_count = 6
  cache.max_logistic_slots = 6
  cache.logistic_mode = mode
  cache.render_not_in_network_icon = false
  cache.use_exact_mode = true
  cache.landing_location_offset = {0, 0}
  cache.corpse = nil
  cache.dying_explosion = nil
  cache.collision_box = {{0, 0}, {0, 0}}
  cache.selection_box = {{0, 0}, {0, 0}}
  cache.collision_mask = { layers = {} }
  cache.selectable_in_game = false
  local empty_picture = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    frame_count = 1,
    direction_count = 1
  }
  -- Keep the helper chest physically/logistically real, but visually absent.
  -- Factorio 2.0 logistic containers may use different visual fields, so clear
  -- the common copied chest graphics instead of relying on only `picture`.
  cache.picture = table.deepcopy(empty_picture)
  cache.pictures = nil
  cache.animation = nil
  cache.animations = nil
  cache.integration_patch = nil
  cache.graphics_set = nil
  cache.opened_duration = 0
  cache.animation_sound = nil
  cache.icon_draw_specification = { scale = 0 }
  cache.icons_positioning = {}
  cache.draw_circuit_wires = false
  cache.draw_copper_wires = false
  return cache
end

local hidden_requester_cache = make_hidden_logistic_cache(
  "requester-chest",
  "tech-priests-cogitator-requester-cache",
  "requester"
)
local hidden_return_cache = make_hidden_logistic_cache(
  "active-provider-chest",
  "tech-priests-cogitator-return-cache",
  "active-provider"
)
local prototypes_to_extend = { proxy }

local machine_damage_smoke = make_machine_damage_smoke()
if machine_damage_smoke then
  table.insert(prototypes_to_extend, machine_damage_smoke)
end

local machine_damage_smoke_cloud = make_machine_damage_smoke_cloud()
if machine_damage_smoke_cloud then
  table.insert(prototypes_to_extend, machine_damage_smoke_cloud)
end

local priest_translocation_smoke = make_priest_translocation_smoke()
if priest_translocation_smoke then
  table.insert(prototypes_to_extend, priest_translocation_smoke)
end

local sacred_incense_cloud = make_sacred_incense_cloud()
if sacred_incense_cloud then
  table.insert(prototypes_to_extend, sacred_incense_cloud)
end

local sacred_incense_cloud_soft = make_sacred_incense_cloud_soft()
if sacred_incense_cloud_soft then
  table.insert(prototypes_to_extend, sacred_incense_cloud_soft)
end

local sacred_incense_cloud_faint = make_sacred_incense_cloud_faint()
if sacred_incense_cloud_faint then
  table.insert(prototypes_to_extend, sacred_incense_cloud_faint)
end

local sacred_incense_projectile = make_sacred_incense_projectile()
if sacred_incense_projectile then
  table.insert(prototypes_to_extend, sacred_incense_projectile)
end
local orbital_trader = make_orbital_trader()
if orbital_trader then
  table.insert(prototypes_to_extend, orbital_trader)
end

if hidden_requester_cache then
  table.insert(prototypes_to_extend, hidden_requester_cache)
end
if hidden_return_cache then
  table.insert(prototypes_to_extend, hidden_return_cache)
end

for _, def in pairs(TIER_DEFS) do
  table.insert(prototypes_to_extend, make_station(def))
  table.insert(prototypes_to_extend, make_priest(def, false))
  table.insert(prototypes_to_extend, make_priest(def, true))
  table.insert(prototypes_to_extend, make_priest_corpse(def))
end


-- 0.1.178: Horrid one-by-one emergency industry prototypes.
-- These are deliberately weak, ugly stopgap machines. They use vanilla visuals and
-- sounds where possible so the pass is mechanically safe before bespoke sprites exist.
local TECH_PRIESTS_PLANETSIDE_SURFACE_CONDITIONS = {
  { property = "pressure", min = 1 },
  { property = "gravity", min = 1 }
}

local function tech_priests_apply_planetside_conditions(entity)
  if entity then
    entity.surface_conditions = table.deepcopy(TECH_PRIESTS_PLANETSIDE_SURFACE_CONDITIONS)
  end
  return entity
end

local MICRO_SELECTION_BOX = { { -0.5, -0.5 }, { 0.5, 0.5 } }
local MICRO_COLLISION_BOX = { { -0.35, -0.35 }, { 0.35, 0.35 } }
-- 0.1.340: larger clickable boxes for micro fluid/power train pieces.
-- They remain compact machines, but the selection/collision now matches the
-- visual expectation better when debugging and placing them in a tight bootstrap cluster.
local MICRO_EXPANDED_SELECTION_BOX = { { -0.62, -0.62 }, { 0.62, 0.62 } }
local TWO_BY_TWO_EXPANDED_SELECTION_BOX = { { -1.12, -1.12 }, { 1.12, 1.12 } }
local TWO_BY_TWO_EXPANDED_COLLISION_BOX = { { -0.96, -0.96 }, { 0.96, 0.96 } }
-- Fluid connection prototypes are validated against the entity collision box after
-- Factorio normalizes side-facing pipe connections to the tile edge (for example
-- west becomes x=-0.5).  The emergency boiler/condenser/engine are still a 1x1
-- footprint, but fluid-capable variants need collision extents that include that
-- normalized edge or the loader rejects the prototype.
local MICRO_FLUID_COLLISION_BOX = { { -0.51, -0.51 }, { 0.51, 0.51 } }
local TWO_BY_TWO_SELECTION_BOX = { { -1.0, -1.0 }, { 1.0, 1.0 } }
local TWO_BY_TWO_COLLISION_BOX = { { -0.90, -0.90 }, { 0.90, 0.90 } }
local MICRO_PIPE_EDGE = 0.0 -- Direction supplies the edge; keep the declared position central and valid.

-- 0.1.541 visual scale doctrine: custom 1024/1254 px Martian sprites must be
-- sized by their intended tile footprint, not by inherited vanilla-machine art.
-- 1254 * 0.026 ~= one Factorio tile; 1024 * 0.063 ~= two tiles.
local MICRO_ONE_TILE_SPRITE_SCALE_0541 = 0.026
local MICRO_ONE_TILE_SLIGHTLY_LARGE_SCALE_0541 = 0.034
local MICRO_TWO_TILE_SPRITE_SCALE_0541 = 0.063
local MICRO_TWO_TILE_COMPACT_SCALE_0541 = 0.052

-- 0.1.546 emergency art containment: live screenshots showed several supplied
-- Martian micro-machine sprites rendering at roughly ten times their intended
-- footprint despite their small collision/selection boxes.  Keep prototype
-- footprint doctrine intact, but clamp the visual layer tree only.
local MICRO_GIGANTIC_ART_CORRECTION_0546 = 1.00 -- retired in 0.1.549; do not multiply bespoke single-image micro art after assigning its intended scale

local function tech_priests_rescale_visual_tree(layer, factor)
  if type(layer) ~= "table" then return end
  for _, value in pairs(layer) do
    if type(value) == "table" then
      tech_priests_rescale_visual_tree(value, factor)
    end
  end
  if (layer.filename or layer.filenames or layer.stripes) and (layer.width or layer.height or layer.size) then
    layer.scale = (layer.scale or 1) * factor
    layer.shift = { 0, 0 }
  end
end

local function tech_priests_apply_micro_visuals(entity, factor)
  if not entity then return end
  for _, field in pairs({
    "animation",
    "animations",
    "horizontal_animation",
    "vertical_animation",
    "idle_animation",
    "always_draw_idle_animation",
    "base_picture",
    "picture",
    "pictures",
    "structure",
    "fire",
    "fire_glow",
    "burning_cooldown",
    "graphics_set",
    "working_visualisations",
    "integration_patch",
    "water_reflection",
    "smoke",
    "vehicle_impact_sound"
  }) do
    if entity[field] then
      tech_priests_rescale_visual_tree(entity[field], factor or 0.50)
    end
  end
end


-- 0.1.289: Generator prototypes, including the vanilla steam-engine base used
-- by the Martian Emergency Micro-Steam Engine, keep their main sprites in
-- horizontal_animation/vertical_animation.  Earlier micro scaling only touched
-- the generic animation fields, so the selection/collision box was tiny while
-- the steam-engine art stayed full size.  This explicit pass makes the
-- emergency engine visually match the 2x2-ish footprint.
local function tech_priests_scale_sound_volume_0541(sound, factor)
  if type(sound) ~= "table" then return end
  if type(sound.volume) == "number" then sound.volume = sound.volume * (factor or 1) end
  for _, value in pairs(sound) do
    if type(value) == "table" then tech_priests_scale_sound_volume_0541(value, factor) end
  end
end

local function tech_priests_reduce_entity_sound_volume_0541(entity, factor)
  if not entity then return end
  for _, field in pairs({ "working_sound", "open_sound", "close_sound", "mined_sound", "created_effect", "damaged_trigger_effect" }) do
    if entity[field] then tech_priests_scale_sound_volume_0541(entity[field], factor or 1) end
  end
end

local function tech_priests_apply_two_by_two_visual_boxes_0541(entity)
  entity.selection_box = table.deepcopy(TWO_BY_TWO_SELECTION_BOX)
  entity.collision_box = table.deepcopy(TWO_BY_TWO_COLLISION_BOX)
  entity.drawing_box_vertical_extension = 0.35
  return entity
end

local function tech_priests_apply_micro_generator_visuals(entity, factor)
  if not entity then return end
  tech_priests_apply_micro_visuals(entity, factor or 0.28)
  for _, field in pairs({
    "horizontal_animation",
    "vertical_animation",
    "horizontal_frozen_patch",
    "vertical_frozen_patch",
    "smoke",
    "impact_category",
  }) do
    if entity[field] then
      tech_priests_rescale_visual_tree(entity[field], factor or 0.28)
    end
  end
  entity.drawing_box_vertical_extension = 0.2
end

local function tech_priests_micro_boxes(entity)
  entity.selection_box = table.deepcopy(MICRO_SELECTION_BOX)
  entity.collision_box = table.deepcopy(MICRO_COLLISION_BOX)
  entity.drawing_box_vertical_extension = 0.2
  return entity
end

local function tech_priests_micro_fluid_boxes(entity)
  entity.selection_box = table.deepcopy(MICRO_EXPANDED_SELECTION_BOX)
  entity.collision_box = table.deepcopy(MICRO_FLUID_COLLISION_BOX)
  entity.drawing_box_vertical_extension = 0.25
  return entity
end

local function tech_priests_two_by_two_fluid_boxes(entity)
  entity.selection_box = table.deepcopy(TWO_BY_TWO_EXPANDED_SELECTION_BOX)
  entity.collision_box = table.deepcopy(TWO_BY_TWO_EXPANDED_COLLISION_BOX)
  entity.drawing_box_vertical_extension = 0.35
  return entity
end

local function make_emergency_miner()
  -- 0.1.250: reworked from a true mining-drill clone into a pseudo-miner.
  -- The machine is effectively a tiny zero-power assembling machine that runs
  -- hidden, zero-input, long-wait emergency-mining recipes.  It does not need
  -- to sit on ore.  Its recipe category is unique, so normal assemblers cannot
  -- perform these shameful survival rites.
  local source = data.raw["assembling-machine"] and data.raw["assembling-machine"]["assembling-machine-1"]
  if not source and data.raw["assembling-machine"] then
    for _, candidate in pairs(data.raw["assembling-machine"]) do source = candidate; break end
  end
  if not source then return nil end
  local miner = table.deepcopy(source)
  miner.name = "tech-priests-emergency-miner"
  miner.localised_name = { "entity-name.tech-priests-emergency-miner" }
  miner.localised_description = { "entity-description.tech-priests-emergency-miner" }
  tech_priests_apply_micro_icon(miner, "tech-priests-emergency-miner")
  miner.minable = { mining_time = 0.2, result = "tech-priests-emergency-miner" }
  miner.next_upgrade = nil
  miner.max_health = 80
  -- 0.1.554: the micro-miner is no longer a free void-output box.
  -- It burns raw chemical fuel while running its private pseudo-mining recipes,
  -- so the player/priest chooses the output from the recipe menu and pays time + fuel.
  miner.energy_source = {
    type = "burner",
    fuel_categories = { "chemical" },
    effectivity = 0.45,
    fuel_inventory_size = 1,
    emissions_per_minute = { pollution = 16 },
    smoke = {
      {
        name = "smoke",
        deviation = { 0.06, 0.06 },
        frequency = 2,
        position = { 0, -0.35 },
        starting_vertical_speed = 0.035
      }
    }
  }
  miner.energy_usage = "90kW"
  miner.crafting_categories = { "tech-priests-emergency-mining" }
  miner.crafting_speed = 1
  miner.module_slots = 0
  miner.allowed_effects = {}
  miner.fluid_boxes = nil
  miner.input_fluid_box = nil
  miner.output_fluid_box = nil
  miner.fixed_recipe = nil
  miner.show_recipe_icon = true
  miner.show_recipe_icon_on_map = false
  miner.return_ingredients_on_change = false
  miner.match_animation_speed_to_activity = false
  tech_priests_reduce_entity_sound_volume_0541(miner, 0.5)
  tech_priests_apply_micro_crafting_art(miner, "tech-priests-emergency-miner", MICRO_ONE_TILE_SLIGHTLY_LARGE_SCALE_0541)
  tech_priests_micro_boxes(miner)
  tech_priests_apply_micro_visuals(miner, 1.0)
  tech_priests_apply_planetside_conditions(miner)
  return miner
end

local function make_emergency_boiler()
  local source = data.raw["boiler"] and data.raw["boiler"]["boiler"]
  if not source then return nil end
  local boiler = table.deepcopy(source)
  boiler.name = "tech-priests-emergency-boiler"
  boiler.localised_name = { "entity-name.tech-priests-emergency-boiler" }
  boiler.localised_description = { "entity-description.tech-priests-emergency-boiler" }
  tech_priests_apply_micro_icon(boiler, "tech-priests-emergency-boiler")
  boiler.minable = { mining_time = 0.2, result = "tech-priests-emergency-boiler" }
  boiler.next_upgrade = nil
  boiler.max_health = 80
  boiler.energy_consumption = "600kW"
  if boiler.energy_source then
    boiler.energy_source.emissions_per_minute = { pollution = 60 }
    boiler.energy_source.fuel_inventory_size = 1
  end
  boiler.fluid_box = {
    production_type = "input-output",
    filter = "water",
    volume = 100,
    pipe_connections = {
      { flow_direction = "input-output", direction = defines.direction.west, position = { -MICRO_PIPE_EDGE, 0 } },
      { flow_direction = "input-output", direction = defines.direction.south, position = { 0, MICRO_PIPE_EDGE } }
    }
  }
  boiler.output_fluid_box = {
    production_type = "output",
    filter = "steam",
    volume = 100,
    pipe_connections = {
      { flow_direction = "output", direction = defines.direction.east, position = { MICRO_PIPE_EDGE, 0 } }
    }
  }
  boiler.pictures = tech_priests_micro_boiler_pictures("tech-priests-emergency-boiler", MICRO_TWO_TILE_SPRITE_SCALE_0541)
  boiler.water_reflection = nil
  tech_priests_apply_two_by_two_visual_boxes_0541(boiler)
  -- 0.1.549: bespoke boiler art is a single 1024px asset; the assigned 2x2 scale is final.
  -- Do not apply an inherited visual-tree shrink afterward or it will drift between invisible and gigantic.
  tech_priests_apply_planetside_conditions(boiler)
  return boiler
end

local function make_atmospheric_water_condenser()
  local source = data.raw["assembling-machine"] and (data.raw["assembling-machine"]["chemical-plant"] or data.raw["assembling-machine"]["assembling-machine-1"])
  if not source then return nil end
  local condenser = table.deepcopy(source)
  condenser.name = "tech-priests-atmospheric-water-condenser"
  condenser.localised_name = { "entity-name.tech-priests-atmospheric-water-condenser" }
  condenser.localised_description = { "entity-description.tech-priests-atmospheric-water-condenser" }
  tech_priests_apply_micro_icon(condenser, "tech-priests-atmospheric-water-condenser")
  condenser.minable = { mining_time = 0.2, result = "tech-priests-atmospheric-water-condenser" }
  condenser.next_upgrade = nil
  condenser.max_health = 90
  condenser.crafting_categories = { "tech-priests-atmospheric-condensing" }
  condenser.crafting_speed = 0.33
  -- 0.1.254: the condenser must be able to bootstrap the emergency
  -- Martian power chain before electricity exists.  It is therefore a
  -- fuel-fed atmospheric condenser: emergency pseudo-miners can provide
  -- coal/wood, that fuel runs the condenser to make water, and the same
  -- raw fuel can feed the boiler to produce steam for the tiny lab grid.
  condenser.energy_usage = "70kW"
  condenser.energy_source = {
    type = "burner",
    fuel_categories = { "chemical" },
    effectivity = 0.60,
    fuel_inventory_size = 1,
    emissions_per_minute = { pollution = 18 },
    smoke = {
      {
        name = "smoke",
        deviation = { 0.08, 0.08 },
        frequency = 3,
        position = { 0, -0.45 },
        starting_vertical_speed = 0.04
      }
    }
  }
  condenser.module_slots = 0
  condenser.allowed_effects = {}
  condenser.fluid_boxes = {
    {
      production_type = "output",
      volume = 100,
      pipe_connections = {
        { flow_direction = "output", direction = defines.direction.east, position = { MICRO_PIPE_EDGE, 0 } }
      }
    }
  }
  -- 0.1.290: condenser doctrine is now honestly 2x2: visual size, selection box, and collision box agree.
  tech_priests_apply_micro_crafting_art(condenser, "tech-priests-atmospheric-water-condenser", 0.051)
  tech_priests_two_by_two_fluid_boxes(condenser)
  -- 0.1.549: condenser is a single 1254px asset scaled directly to a readable 2x2 footprint.
  tech_priests_apply_planetside_conditions(condenser)
  return condenser
end

local function make_emergency_steam_engine()
  local source = data.raw["generator"] and data.raw["generator"]["steam-engine"]
  if not source then return nil end
  local engine = table.deepcopy(source)
  engine.name = "tech-priests-emergency-steam-engine"
  engine.localised_name = { "entity-name.tech-priests-emergency-steam-engine" }
  engine.localised_description = { "entity-description.tech-priests-emergency-steam-engine" }
  tech_priests_apply_micro_icon(engine, "tech-priests-emergency-steam-engine")
  engine.minable = { mining_time = 0.2, result = "tech-priests-emergency-steam-engine" }
  engine.next_upgrade = nil
  engine.max_health = 90
  engine.max_power_output = "300kW"
  if type(engine.fluid_usage_per_tick) == "number" then
    engine.fluid_usage_per_tick = engine.fluid_usage_per_tick / 3
  end
  engine.fluid_box = {
    production_type = "input-output",
    filter = "steam",
    volume = 100,
    pipe_connections = {
      { flow_direction = "input-output", direction = defines.direction.west, position = { -MICRO_PIPE_EDGE, 0 } },
      { flow_direction = "input-output", direction = defines.direction.east, position = { MICRO_PIPE_EDGE, 0 } }
    }
  }
  -- 0.1.290: engine doctrine is now honestly 2x2: visual size, selection box, and collision box agree.
  -- 0.1.534: EMM sprites are normalized toward roughly two-tile visual width so the suite reads as one machine family.
  engine.horizontal_animation = tech_priests_micro_animation("tech-priests-emergency-steam-engine", MICRO_TWO_TILE_SPRITE_SCALE_0541)
  engine.vertical_animation = tech_priests_micro_animation("tech-priests-emergency-steam-engine", MICRO_TWO_TILE_SPRITE_SCALE_0541)
  engine.horizontal_frozen_patch = nil
  engine.vertical_frozen_patch = nil
  engine.water_reflection = nil
  tech_priests_two_by_two_fluid_boxes(engine)
  -- 0.1.549: generator art is already assigned at final 2x2 scale above. Avoid recursive post-scaling.
  tech_priests_apply_planetside_conditions(engine)
  return engine
end

local function make_emergency_assembler()
  local source = data.raw["assembling-machine"] and data.raw["assembling-machine"]["assembling-machine-1"]
  if not source then return nil end
  local assembler = table.deepcopy(source)
  assembler.name = "tech-priests-emergency-assembler"
  assembler.localised_name = { "entity-name.tech-priests-emergency-assembler" }
  assembler.localised_description = { "entity-description.tech-priests-emergency-assembler" }
  tech_priests_apply_micro_icon(assembler, "tech-priests-emergency-assembler")
  assembler.minable = { mining_time = 0.2, result = "tech-priests-emergency-assembler" }
  assembler.next_upgrade = nil
  assembler.max_health = 90
  -- 0.1.343: smelting removed from the micro-assembler.  Ore-to-plate
  -- survival now belongs to the dedicated Martian Emergency Micro-Smelter,
  -- so priests stop trying to hand/assembler-smelt plates before they have a
  -- usable furnace-like machine.
  assembler.crafting_categories = {
    "crafting",
    "basic-crafting",
    "advanced-crafting"
  }
  assembler.crafting_speed = 0.17
  assembler.energy_usage = "80kW"
  assembler.energy_source = {
    type = "burner",
    fuel_categories = { "chemical" },
    effectivity = 0.75,
    fuel_inventory_size = 1,
    emissions_per_minute = { pollution = 20 },
    smoke = {
      {
        name = "smoke",
        deviation = { 0.1, 0.1 },
        frequency = 4,
        position = { 0, -0.4 },
        starting_vertical_speed = 0.05
      }
    }
  }
  assembler.module_slots = 0
  assembler.allowed_effects = {}
  assembler.fluid_boxes = nil
  tech_priests_apply_micro_crafting_art(assembler, "tech-priests-emergency-assembler", MICRO_ONE_TILE_SLIGHTLY_LARGE_SCALE_0541)
  tech_priests_micro_boxes(assembler)
  tech_priests_apply_micro_visuals(assembler, 1.0)
  tech_priests_apply_planetside_conditions(assembler)
  return assembler
end


local function make_emergency_smelter()
  local source = data.raw["furnace"] and data.raw["furnace"]["stone-furnace"]
  if not source then return nil end
  local smelter = table.deepcopy(source)
  smelter.name = "tech-priests-emergency-smelter"
  smelter.localised_name = { "entity-name.tech-priests-emergency-smelter" }
  smelter.localised_description = { "entity-description.tech-priests-emergency-smelter" }
  tech_priests_apply_micro_icon(smelter, "tech-priests-emergency-smelter")
  smelter.minable = { mining_time = 0.2, result = "tech-priests-emergency-smelter" }
  smelter.next_upgrade = nil
  smelter.max_health = 80
  smelter.crafting_categories = { "smelting", "tech-priests-emergency-smelting" }
  smelter.crafting_speed = 0.25
  smelter.energy_usage = "70kW"
  smelter.energy_source = {
    type = "burner",
    fuel_categories = { "chemical" },
    effectivity = 0.75,
    fuel_inventory_size = 1,
    emissions_per_minute = { pollution = 18 },
    smoke = {
      {
        name = "smoke",
        deviation = { 0.08, 0.08 },
        frequency = 4,
        position = { 0, -0.4 },
        starting_vertical_speed = 0.05
      }
    }
  }
  smelter.module_slots = 0
  smelter.allowed_effects = {}
  tech_priests_apply_micro_crafting_art(smelter, "tech-priests-emergency-smelter", MICRO_ONE_TILE_SPRITE_SCALE_0541)
  tech_priests_micro_boxes(smelter)
  -- 0.1.549: smelter is a single 1254px asset scaled directly to 1x1. No recursive post-shrink.
  tech_priests_apply_planetside_conditions(smelter)
  return smelter
end

local function make_emergency_laboratorium()
  local source = data.raw["lab"] and data.raw["lab"]["lab"]
  if not source then return nil end
  local lab = table.deepcopy(source)
  lab.name = "tech-priests-emergency-laboratorium"
  lab.localised_name = { "entity-name.tech-priests-emergency-laboratorium" }
  lab.localised_description = { "entity-description.tech-priests-emergency-laboratorium" }
  tech_priests_apply_micro_icon(lab, "tech-priests-emergency-laboratorium")
  lab.minable = { mining_time = 0.2, result = "tech-priests-emergency-laboratorium" }
  lab.next_upgrade = nil
  lab.max_health = 80
  -- The Martian emergency boiler/steam-engine/pole chain is sized around this
  -- tiny laboratory first; the burner assembler handles its own fuel.
  lab.researching_speed = 0.33
  lab.energy_usage = "20kW"
  lab.module_slots = 0
  lab.allowed_effects = {}
  lab.on_animation = tech_priests_micro_animation("tech-priests-emergency-laboratorium", MICRO_ONE_TILE_SPRITE_SCALE_0541)
  lab.off_animation = tech_priests_micro_animation("tech-priests-emergency-laboratorium", MICRO_ONE_TILE_SPRITE_SCALE_0541)
  lab.frozen_patch = nil
  lab.water_reflection = nil
  tech_priests_micro_boxes(lab)
  tech_priests_apply_micro_visuals(lab, 1.0)
  tech_priests_apply_planetside_conditions(lab)
  return lab
end


local function make_emergency_power_grid()
  local source = data.raw["electric-pole"] and (data.raw["electric-pole"]["small-electric-pole"] or data.raw["electric-pole"]["medium-electric-pole"])
  if not source then return nil end
  local pole = table.deepcopy(source)
  pole.name = "tech-priests-emergency-power-grid"
  pole.localised_name = { "entity-name.tech-priests-emergency-power-grid" }
  pole.localised_description = { "entity-description.tech-priests-emergency-power-grid" }
  tech_priests_apply_micro_icon(pole, "tech-priests-emergency-power-grid")
  pole.minable = { mining_time = 0.2, result = "tech-priests-emergency-power-grid" }
  pole.next_upgrade = nil
  pole.max_health = 55
  -- 0.1.409: this emergency grid is supposed to be a tiny usable pole, not a
  -- purely decorative wire anchor.  Keep the range modest, but set it explicitly
  -- instead of inheriting/limiting through an optional dependency's pole values.
  pole.supply_area_distance = 3.5
  pole.maximum_wire_distance = 9.0
  pole.draw_copper_wires = true
  pole.draw_circuit_wires = true
  -- 0.1.385: the custom provisional pole art is a single-direction compact
  -- RotatedSprite, so use one matching connection point rather than inheriting
  -- the source pole's directional cardinality. This preserves the earlier
  -- cardinality-synchronization doctrine without keeping oversized base art.
  local connection_point_count = 1
  pole.connection_points = {}
  for _ = 1, connection_point_count do
    table.insert(pole.connection_points, {
      wire = {
        copper = { 0.00, -0.48 },
        red = { -0.16, -0.42 },
        green = { 0.16, -0.42 }
      },
      shadow = {
        copper = { 0.22, -0.22 },
        red = { 0.06, -0.18 },
        green = { 0.38, -0.18 }
      }
    })
  end
  pole.module_slots = nil
  -- Electric poles require RotatedSprite picture layers with explicit
  -- direction_count. Do not use the generic micro Sprite helper here.
  pole.pictures = tech_priests_micro_pole_picture("tech-priests-emergency-power-grid", MICRO_ONE_TILE_SLIGHTLY_LARGE_SCALE_0541, nil, connection_point_count)
  pole.active_picture = nil
  -- Preserve/copy the base electric pole radius visualisation so selected poles
  -- visibly advertise the supply area.  Removing this made the micro-grid look
  -- like it had no power radius even when supply_area_distance was non-zero.
  if source.radius_visualisation_picture then
    pole.radius_visualisation_picture = table.deepcopy(source.radius_visualisation_picture)
  end
  pole.water_reflection = nil
  tech_priests_micro_boxes(pole)
  tech_priests_apply_micro_visuals(pole, 1.0)
  -- Micro-visual scaling should never be allowed to disturb the functional pole
  -- radius values.  Reassert them after the visual pass for prototype clarity.
  pole.supply_area_distance = 3.5
  pole.maximum_wire_distance = 9.0
  tech_priests_apply_planetside_conditions(pole)
  return pole
end

for _, emergency_entity in pairs({
  make_emergency_miner(),
  make_emergency_boiler(),
  make_atmospheric_water_condenser(),
  make_emergency_steam_engine(),
  make_emergency_smelter(),
  make_emergency_assembler(),
  make_emergency_laboratorium(),
  make_emergency_power_grid(),
  make_sacred_machine_oil_projectile(),
  make_tech_priests_data_spike_projectile_0590()
}) do
  if emergency_entity then
    table.insert(prototypes_to_extend, emergency_entity)
  end
end


data:extend(prototypes_to_extend)


-- Consecrated assembler footprint pass.
-- Factorio requires entities linked by next_upgrade to use matching bounding
-- boxes. Resizing only assembling-machine-1 breaks the vanilla assembler upgrade
-- chain, so all three assembler tiers receive the same clean 4x4 Mechanicus
-- footprint while preserving their existing next_upgrade pointers.
local MECHANICUS_ASSEMBLER_SELECTION_BOX = { { -2.0, -2.0 }, { 2.0, 2.0 } }
local MECHANICUS_ASSEMBLER_COLLISION_BOX = { { -1.8, -1.8 }, { 1.8, 1.8 } }

local MECHANICUS_ASSEMBLER_SPRITE_SCALE_FACTOR = 4 / 3

local function rescale_sprite_layer(layer, factor)
  if type(layer) ~= "table" then return end

  -- Walk nested animation structures first: layers, north/east/south/west variants,
  -- graphics_set working_visualisations, hr_version, etc.
  for _, value in pairs(layer) do
    if type(value) == "table" then
      rescale_sprite_layer(value, factor)
    end
  end

  -- A real sprite/animation layer has a filename/stripes source and dimensions.
  -- Icon definitions are not inside the assembler prototype visuals, but the
  -- dimension check keeps this from touching non-visual control tables anyway.
  if (layer.filename or layer.filenames or layer.stripes) and (layer.width or layer.height or layer.size) then
    layer.scale = (layer.scale or 1) * factor
  end
end

local function rescale_assembler_visuals(assembler, factor)
  if not assembler then return end
  if assembler.graphics_set then
    rescale_sprite_layer(assembler.graphics_set, factor)
  end
  if assembler.animation then
    rescale_sprite_layer(assembler.animation, factor)
  end
  if assembler.working_visualisations then
    rescale_sprite_layer(assembler.working_visualisations, factor)
  end
end


for _, assembler_name in pairs({
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3"
}) do
  local assembler = data.raw["assembling-machine"] and data.raw["assembling-machine"][assembler_name]
  if assembler then
    assembler.selection_box = table.deepcopy(MECHANICUS_ASSEMBLER_SELECTION_BOX)
    assembler.collision_box = table.deepcopy(MECHANICUS_ASSEMBLER_COLLISION_BOX)

    -- Add one extra result slot for machine-level waste. Mechanical Detritus is
    -- inserted into the normal assembler output inventory so inserters can remove
    -- it, and so an ignored waste stack can physically jam the machine.
    assembler.result_inventory_size = math.max((assembler.result_inventory_size or 1) + 1, 2)

    rescale_assembler_visuals(assembler, MECHANICUS_ASSEMBLER_SPRITE_SCALE_FACTOR)
    assembler.localised_description = { "entity-description." .. assembler_name }
  end
end
