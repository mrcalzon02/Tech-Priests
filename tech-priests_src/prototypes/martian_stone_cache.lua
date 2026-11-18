-- Tech Priests 0.1.538 - Martian stone cache and cargo reliquary prototypes.
-- A family of primitive stone reliquaries, filtered stone caches, fluid/battery
-- vaults, and space-cargo inventories.  Runtime filtering is handled by
-- scripts/core/stone_cache_filter_0534.lua so ordinary containers remain simple
-- Factorio chests rather than new logistics controllers.

local util = require("util")

local STONE_CACHE_ENTITY_PATH = "__tech-priests__/graphics/entity/stone-cache/"
local STONE_CACHE_ICON_PATH = "__tech-priests__/graphics/icons/stone-cache/"

local TWO_BY_TWO_SELECTION_BOX = {{-1.0, -1.0}, {1.0, 1.0}}
local TWO_BY_TWO_COLLISION_BOX = {{-0.90, -0.90}, {0.90, 0.90}}
local BASIC_SPACE_CARGO_SELECTION_BOX = {{-3.0, -1.30}, {3.0, 1.30}}
local BASIC_SPACE_CARGO_COLLISION_BOX = {{-2.70, -1.10}, {2.70, 1.10}}
local ADV_SPACE_CARGO_SELECTION_BOX = {{-2.50, -2.50}, {2.50, 2.50}}
local ADV_SPACE_CARGO_COLLISION_BOX = {{-2.20, -2.20}, {2.20, 2.20}}

local SPACE_PLATFORM_ONLY_SURFACE_CONDITIONS = {
  { property = "gravity", min = -0.01, max = 0.10 },
  { property = "pressure", min = -0.01, max = 0.10 }
}

local function apply_space_platform_only_buildability(entity)
  if not entity then return entity end
  entity.surface_conditions = table.deepcopy(SPACE_PLATFORM_ONLY_SURFACE_CONDITIONS)
  local source = (data.raw["cargo-bay"] and data.raw["cargo-bay"]["cargo-bay"])
    or (data.raw["space-platform-hub"] and data.raw["space-platform-hub"]["space-platform-hub"])
    or (data.raw["assembling-machine"] and data.raw["assembling-machine"]["crusher"])
  if source and source.tile_buildability_rules then
    entity.tile_buildability_rules = table.deepcopy(source.tile_buildability_rules)
  end
  entity.heating_energy = "0W"
  return entity
end

local asset_dims = {
  ["tech-priests-martian-stone-cache"] = {1254, 1254},
  ["tech-priests-stone-cache-item-vault"] = {1024, 1024},
  ["tech-priests-stone-cache-primitive-acclimator-battery-bank"] = {1024, 1024},
  ["tech-priests-stone-cache-pressurized-fluid-vault"] = {1024, 1024},
  ["tech-priests-stone-cache-coal"] = {1254, 1254},
  ["tech-priests-stone-cache-copper-ore"] = {1254, 1254},
  ["tech-priests-stone-cache-copper-plate"] = {1254, 1254},
  ["tech-priests-stone-cache-copper-cable"] = {1254, 1254},
  ["tech-priests-stone-cache-iron-gear-wheel"] = {1024, 1024},
  ["tech-priests-stone-cache-iron-ore"] = {1254, 1254},
  ["tech-priests-stone-cache-iron-plate"] = {1254, 1254},
  ["tech-priests-stone-cache-iron-stick"] = {1254, 1254},
  ["tech-priests-stone-cache-stone"] = {1254, 1254},
  ["tech-priests-stone-cache-wood"] = {1254, 1254},
  ["tech-priests-basic-space-cargo-inventory"] = {1889, 833},
  ["tech-priests-advanced-space-cargo-inventory"] = {1315, 1196}
}

local AUTHORED_FILTERED_CACHE_KEYS = {
  ["tech-priests-stone-cache-coal"]="coal",
  ["tech-priests-stone-cache-copper-ore"]="copper-ore",
  ["tech-priests-stone-cache-copper-plate"]="copper-plate",
  ["tech-priests-stone-cache-copper-cable"]="copper-cable",
  ["tech-priests-stone-cache-iron-gear-wheel"]="iron-gear-wheel",
  ["tech-priests-stone-cache-iron-ore"]="iron-ore",
  ["tech-priests-stone-cache-iron-plate"]="iron-plate",
  ["tech-priests-stone-cache-iron-stick"]="iron-stick",
  ["tech-priests-stone-cache-stone"]="stone",
  ["tech-priests-stone-cache-wood"]="wood",
}

local function icon_path(name)
  if name == "tech-priests-advanced-space-cargo-inventory" then return "__tech-priests__/graphics/entity/advanced-space-cargo-v01/icon.png" end
  if name == "tech-priests-basic-space-cargo-inventory" then return "__tech-priests__/graphics/entity/basic-space-cargo-v01/icon.png" end
  if AUTHORED_FILTERED_CACHE_KEYS[name] then return "__tech-priests__/graphics/entity/filtered-stone-caches-v01/" .. AUTHORED_FILTERED_CACHE_KEYS[name] .. "-icon.png" end
  if name == "tech-priests-stone-cache-pressurized-fluid-vault" then return "__tech-priests__/graphics/entity/pressurized-fluid-vault-v01/icon.png" end
  if name == "tech-priests-stone-cache-primitive-acclimator-battery-bank" then return "__tech-priests__/graphics/entity/primitive-battery-bank-v01/icon.png" end
  if name == "tech-priests-stone-cache-item-vault" then return "__tech-priests__/graphics/entity/item-vault-v01/icon.png" end
  if name == "tech-priests-martian-stone-cache" then
    return "__tech-priests__/graphics/entity/martian-stone-cache-v01/icon.png"
  end
  return STONE_CACHE_ICON_PATH .. name .. ".png"
end

local function sprite_path(name)
  return STONE_CACHE_ENTITY_PATH .. name .. ".png"
end

local function shadow_path(name)
  return STONE_CACHE_ENTITY_PATH .. name .. "-shadow.png"
end

local function picture_for(name, scale, shift)
  if name == "tech-priests-advanced-space-cargo-inventory" then return {
    north={layers={
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/shadow-d0.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/body-d0.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423}},
    }},
    east={layers={
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/shadow-d1.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/body-d1.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423}},
    }},
    south={layers={
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/shadow-d2.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/body-d2.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423}},
    }},
    west={layers={
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/shadow-d3.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/body-d3.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423}},
    }},
  } end
  if name == "tech-priests-basic-space-cargo-inventory" then return {
    north={layers={
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/shadow-d0.png",width=1024,height=1024,scale=7*32/1024,shift={0,0},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/body-d0.png",width=1024,height=1024,scale=7*32/1024,shift={0,0}},
    }},
    east={layers={
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/shadow-d1.png",width=1024,height=1024,scale=7*32/1024,shift={0,0},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/body-d1.png",width=1024,height=1024,scale=7*32/1024,shift={0,0}},
    }},
    south={layers={
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/shadow-d2.png",width=1024,height=1024,scale=7*32/1024,shift={0,0},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/body-d2.png",width=1024,height=1024,scale=7*32/1024,shift={0,0}},
    }},
    west={layers={
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/shadow-d3.png",width=1024,height=1024,scale=7*32/1024,shift={0,0},draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/basic-space-cargo-v01/body-d3.png",width=1024,height=1024,scale=7*32/1024,shift={0,0}},
    }},
  } end
  if AUTHORED_FILTERED_CACHE_KEYS[name] then
    local root = "__tech-priests__/graphics/entity/filtered-stone-caches-v01/" .. AUTHORED_FILTERED_CACHE_KEYS[name]
    local registration = {0,-0.08713203435596423}
    return {layers={
      {filename=root .. "-shadow.png",width=512,height=512,scale=3*32/512,shift=registration,draw_as_shadow=true},
      {filename=root .. "-body.png",width=512,height=512,scale=3*32/512,shift=registration}
    }}
  end
  -- Authored primitive accumulator: native capacity, rates and ports unchanged.
  if name == "tech-priests-stone-cache-primitive-acclimator-battery-bank" then
    local registration = {0, -0.01213203435596423}
    return {layers = {
      {filename="__tech-priests__/graphics/entity/primitive-battery-bank-v01/shadow.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration, draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/primitive-battery-bank-v01/body.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration}
    }}
  end
  -- Authored Item Vault: fixed-facing native ten-slot container unchanged.
  if name == "tech-priests-stone-cache-item-vault" then
    local registration = {0, -0.08713203435596423}
    return {layers = {
      {filename="__tech-priests__/graphics/entity/item-vault-v01/shadow.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration, draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/item-vault-v01/body.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration}
    }}
  end
  -- Authored base cache only. All inventories, circuits and variants retain
  -- their original definitions; fixed-north orientation is unchanged.
  if name == "tech-priests-martian-stone-cache" then
    local root = "__tech-priests__/graphics/entity/martian-stone-cache-v01/"
    local registration = {0, -0.08713203435596423}
    return {layers = {
      {filename=root .. "shadow.png", priority="high", width=512, height=512,
        scale=3.0*32/512, shift=registration, draw_as_shadow=true},
      {filename=root .. "body.png", priority="high", width=512, height=512,
        scale=3.0*32/512, shift=registration}
    }}
  end
  local dims = asset_dims[name] or {1024, 1024}
  return {
    layers = {
      {
        filename = shadow_path(name),
        priority = "high",
        width = dims[1],
        height = dims[2],
        frame_count = 1,
        line_length = 1,
        draw_as_shadow = true,
        shift = shift and {(shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08} or {0.08, 0.08},
        scale = scale or 0.055
      },
      {
        filename = sprite_path(name),
        priority = "high",
        width = dims[1],
        height = dims[2],
        frame_count = 1,
        line_length = 1,
        shift = shift or {0, 0},
        scale = scale or 0.055
      }
    }
  }
end

local function animation_for(name, scale, shift)
  -- Factorio 2.0 accumulators render through chargable_graphics, not the
  -- legacy top-level picture/charge_animation fields.  Use the same single
  -- frame stone-cache asset for idle, charging, and discharging so no vanilla
  -- accumulator art can bleed through.
  local dims = asset_dims[name] or {1024, 1024}
  return {
    layers = {
      {
        filename = shadow_path(name),
        priority = "high",
        width = dims[1],
        height = dims[2],
        frame_count = 1,
        line_length = 1,
        draw_as_shadow = true,
        shift = shift and {(shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08} or {0.08, 0.08},
        scale = scale or 0.068
      },
      {
        filename = sprite_path(name),
        priority = "high",
        width = dims[1],
        height = dims[2],
        frame_count = 1,
        line_length = 1,
        shift = shift or {0, 0},
        scale = scale or 0.068
      }
    }
  }
end

local function ingredient(name, amount)
  return { type = "item", name = name, amount = amount }
end

local function make_item(spec)
  return {
    type = "item",
    name = spec.name,
    localised_name = { "item-name." .. spec.name },
    localised_description = { "item-description." .. spec.name },
    icon = icon_path(spec.name),
    icon_size = 64,
    subgroup = spec.subgroup or "tech-priest-emergency-industry",
    order = spec.order or ("z[stone-cache]-[" .. spec.name .. "]"),
    place_result = spec.name,
    stack_size = spec.stack_size or 50
  }
end

local function make_container(spec)
  local chest_source = data.raw.container and (data.raw.container["steel-chest"] or data.raw.container["wooden-chest"])
  if not chest_source then return nil end
  local chest = table.deepcopy(chest_source)
  chest.name = spec.name
  chest.localised_name = { "entity-name." .. spec.name }
  chest.localised_description = { "entity-description." .. spec.name }
  chest.icon = icon_path(spec.name)
  chest.icon_size = 64
  chest.icons = nil
  chest.minable = { mining_time = spec.mining_time or 0.35, result = spec.name }
  chest.inventory_size = spec.inventory_size or 6
  chest.max_health = spec.max_health or 180
  chest.order = spec.order or ("z[stone-cache]-[" .. spec.name .. "]")
  chest.corpse = "small-remnants"
  -- 0.1.538: Factorio 2.0 does not provide rock-big-explosion in the tested load.
  -- Keep these primitive cache containers boot-safe by falling back only to
  -- explosion prototypes that are actually present, otherwise omit the field.
  if data.raw.explosion then
    chest.dying_explosion = (data.raw.explosion["medium-explosion"] and "medium-explosion")
      or (data.raw.explosion["explosion"] and "explosion")
      or nil
  else
    chest.dying_explosion = nil
  end
  chest.collision_box = table.deepcopy(spec.collision_box or TWO_BY_TWO_COLLISION_BOX)
  chest.selection_box = table.deepcopy(spec.selection_box or TWO_BY_TWO_SELECTION_BOX)
  chest.picture = picture_for(spec.name, spec.scale or 0.055, spec.shift)
  -- Centered Martian relief keeps its own backing; native pins/LEDs and all
  -- connector points/reach remain unchanged. Avoid a steel-chest board over it.
  if spec.name == "tech-priests-martian-stone-cache" or spec.name == "tech-priests-stone-cache-item-vault" or AUTHORED_FILTERED_CACHE_KEYS[spec.name] then
    for _, connector in ipairs(chest.circuit_connector or {}) do
      if connector.sprites then
        connector.sprites.connector_main = util.empty_sprite()
        connector.sprites.connector_shadow = util.empty_sprite()
      end
    end
  end
  -- Authored Basic cargo contact registration. Owner requested native rotation.
  -- Four-way sprites/contacts rotate with the original rectangular footprint;
  -- inventory, research, recipe, platform restrictions and wire reach are unchanged.
  if spec.name == "tech-priests-basic-space-cargo-inventory" then
    chest.direction_count = 4
    local original = table.deepcopy(chest.circuit_connector[1])
    chest.circuit_connector = {}
    local draw = {
      {red={0.45,0.6310928022089936},green={0.59,0.6310928022089936},led={0.73,0.6646803743153545},shifts={led_blue={0.7190019392498955,0.38859272936132194},led_blue_off={0.7190530493951612,0.3885967049605158},led_green={0.7191124986799029,0.4959208036109507},led_red={0.7191124986799029,0.4959208036109507}}},
      {red={-1.075,0.1891510639674015},green={-1.075,0.28814601333351814},led={-1.075,0.4207285348059958},shifts={led_blue={-1.0859980607501045,0.14464088985196322},led_blue_off={-1.0859469506048387,0.14464486545115707},led_green={-1.085887501320097,0.251968964101592},led_red={-1.085887501320097,0.251968964101592}}},
      {red={-0.4500000000000001,-0.8891867773420833},green={-0.5900000000000001,-0.8891867773420833},led={-0.7300000000000001,-0.8555992052357224},shifts={led_blue={-0.7409980607501045,-1.131686850189755},led_blue_off={-0.7409469506048387,-1.1316828745905612},led_green={-0.7408875013200973,-1.0243587759401263},led_red={-0.7408875013200973,-1.0243587759401263}}},
      {red={1.075,-0.44724503910049146},green={1.075,-0.546239988466608},led={1.0749999999999997,-0.6116473657263637},shifts={led_blue={1.0640019392498954,-0.8877350106803963},led_blue_off={1.064053049395161,-0.8877310350812024},led_green={1.0641124986799027,-0.7804069364307675},led_red={1.0641124986799027,-0.7804069364307675}}},
    }
    for i = 1,4 do
      local c = table.deepcopy(original)
      c.points.wire.red = draw[i].red
      c.points.wire.green = draw[i].green
      c.points.shadow.red = {draw[i].red[1]+0.05,draw[i].red[2]+0.05}
      c.points.shadow.green = {draw[i].green[1]+0.05,draw[i].green[2]+0.05}
      for _, key in ipairs({"connector_main","connector_shadow","wire_pins","wire_pins_shadow"}) do c.sprites[key]=util.empty_sprite() end
      for key, shift in pairs(draw[i].shifts) do c.sprites[key].shift=shift end
      c.sprites.blue_led_light_offset=draw[i].led
      c.sprites.red_green_led_light_offset=draw[i].led
      chest.circuit_connector[i]=c
    end
  end
  -- Authored Advanced cargo contact registration. Owner requested native rotation.
  -- Four-way sprites/contacts rotate with the owner-corrected square footprint;
  -- inventory, research, recipe, platform restrictions and wire reach are unchanged.
  if spec.name == "tech-priests-advanced-space-cargo-inventory" then
    chest.direction_count = 4
    local original = table.deepcopy(chest.circuit_connector[1])
    chest.circuit_connector = {}
    local draw = {
      {red={0.36000000000000004,2.2247624099467638},green={0.472,2.2247624099467638},led={0.584,2.2516324676318527},shifts={led_blue={0.5730019392498955,1.97554482267782},led_blue_off={0.5730530493951613,1.975548798277014},led_green={0.5731124986799028,2.082872896927449},led_red={0.5731124986799028,2.082872896927449}}},
      {red={-2.328,0.2567624099467643},green={-2.328,0.36876240994676424},led={-2.328,0.5076324676318529},shifts={led_blue={-2.338998060750104,0.23154482267782028},led_blue_off={-2.3389469506048384,0.23154879827701413},led_green={-2.338887501320097,0.33887289692744904},led_red={-2.338887501320097,0.33887289692744904}}},
      {red={-0.3600000000000003,-2.431237590053236},green={-0.47200000000000025,-2.431237590053236},led={-0.5840000000000003,-2.404367532368147},shifts={led_blue={-0.5949980607501048,-2.6804551773221794},led_blue_off={-0.594946950604839,-2.6804512017229856},led_green={-0.5948875013200974,-2.573127103072551},led_red={-0.5948875013200974,-2.573127103072551}}},
      {red={2.328,-0.4632375900532364},green={2.328,-0.5752375900532364},led={2.328,-0.6603675323681475},shifts={led_blue={2.3170019392498955,-0.9364551773221801},led_blue_off={2.3170530493951613,-0.9364512017229862},led_green={2.3171124986799025,-0.8291271030725513},led_red={2.3171124986799025,-0.8291271030725513}}},
    }
    for i = 1,4 do
      local c = table.deepcopy(original)
      c.points.wire.red = draw[i].red
      c.points.wire.green = draw[i].green
      c.points.shadow.red = {draw[i].red[1]+0.05,draw[i].red[2]+0.05}
      c.points.shadow.green = {draw[i].green[1]+0.05,draw[i].green[2]+0.05}
      for _, key in ipairs({"connector_main","connector_shadow","wire_pins","wire_pins_shadow"}) do c.sprites[key]=util.empty_sprite() end
      for key, shift in pairs(draw[i].shifts) do c.sprites[key].shift=shift end
      c.sprites.blue_led_light_offset=draw[i].led
      c.sprites.red_green_led_light_offset=draw[i].led
      chest.circuit_connector[i]=c
    end
  end
  if spec.space_platform_only then
    apply_space_platform_only_buildability(chest)
  end
  chest.open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.35 }
  chest.close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.35 }
  return chest
end

local function make_recipe(spec)
  return {
    type = "recipe",
    name = spec.name,
    localised_name = { "recipe-name." .. spec.name },
    localised_description = { "recipe-description." .. spec.name },
    icon = icon_path(spec.name),
    icon_size = 64,
    subgroup = spec.subgroup or "tech-priest-emergency-industry",
    order = spec.order or ("z[stone-cache]-[" .. spec.name .. "]"),
    category = "crafting",
    enabled = spec.enabled ~= false,
    energy_required = spec.energy_required or 5,
    ingredients = spec.ingredients or { ingredient("stone", 40) },
    results = { { type = "item", name = spec.name, amount = 1 } },
    main_product = spec.name
  }
end

local cache_specs = {
  {
    name = "tech-priests-martian-stone-cache",
    inventory_size = 4,
    scale = 0.055,
    max_health = 180,
    energy_required = 6,
    ingredients = { ingredient("stone", 32) },
    order = "z[stone-cache]-a[basic]"
  },
  {
    name = "tech-priests-stone-cache-item-vault",
    inventory_size = 10,
    scale = 0.068,
    max_health = 240,
    energy_required = 8,
    ingredients = { ingredient("stone", 48), ingredient("iron-plate", 6), ingredient("iron-gear-wheel", 2) },
    order = "z[stone-cache]-b[item-vault]"
  },
  {
    name = "tech-priests-stone-cache-coal",
    filter_item = "coal",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("coal", 4) },
    order = "z[stone-cache]-c[coal]"
  },
  {
    name = "tech-priests-stone-cache-stone",
    filter_item = "stone",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 48) },
    order = "z[stone-cache]-d[stone]"
  },
  {
    name = "tech-priests-stone-cache-wood",
    filter_item = "wood",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("wood", 8) },
    order = "z[stone-cache]-e[wood]"
  },
  {
    name = "tech-priests-stone-cache-iron-ore",
    filter_item = "iron-ore",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("iron-ore", 8) },
    order = "z[stone-cache]-f[iron-ore]"
  },
  {
    name = "tech-priests-stone-cache-copper-ore",
    filter_item = "copper-ore",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("copper-ore", 8) },
    order = "z[stone-cache]-g[copper-ore]"
  },
  {
    name = "tech-priests-stone-cache-iron-plate",
    filter_item = "iron-plate",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("iron-plate", 6) },
    order = "z[stone-cache]-h[iron-plate]"
  },
  {
    name = "tech-priests-stone-cache-copper-plate",
    filter_item = "copper-plate",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("copper-plate", 6) },
    order = "z[stone-cache]-i[copper-plate]"
  },
  {
    name = "tech-priests-stone-cache-copper-cable",
    filter_item = "copper-cable",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("copper-cable", 16) },
    order = "z[stone-cache]-j[copper-cable]"
  },
  {
    name = "tech-priests-stone-cache-iron-gear-wheel",
    filter_item = "iron-gear-wheel",
    inventory_size = 6,
    scale = 0.068,
    ingredients = { ingredient("stone", 40), ingredient("iron-gear-wheel", 4) },
    order = "z[stone-cache]-k[iron-gear-wheel]"
  },
  {
    name = "tech-priests-stone-cache-iron-stick",
    filter_item = "iron-stick",
    inventory_size = 6,
    scale = 0.055,
    ingredients = { ingredient("stone", 40), ingredient("iron-stick", 10) },
    order = "z[stone-cache]-l[iron-stick]"
  },
  {
    name = "tech-priests-basic-space-cargo-inventory",
    inventory_size = 20,
    -- 0.1.541: doubled visual footprint to match the intended cargo-object presence.
    scale = 0.110,
    max_health = 260,
    subgroup = "tech-priest-void-cargo",
    selection_box = BASIC_SPACE_CARGO_SELECTION_BOX,
    collision_box = BASIC_SPACE_CARGO_COLLISION_BOX,
    space_platform_only = true,
    energy_required = 10,
    enabled = false,
    ingredients = { ingredient("steel-chest", 1), ingredient("void-sealed-cargo", 1), ingredient("offworld-cogitator-components", 1) },
    order = "z[stone-cache]-m[basic-space-cargo]"
  },
  {
    name = "tech-priests-advanced-space-cargo-inventory",
    inventory_size = 50,
    -- 0.1.541: doubled visual footprint to match the intended cargo-object presence.
    scale = 0.120,
    max_health = 420,
    subgroup = "tech-priest-void-cargo",
    selection_box = ADV_SPACE_CARGO_SELECTION_BOX,
    collision_box = ADV_SPACE_CARGO_COLLISION_BOX,
    space_platform_only = true,
    energy_required = 18,
    enabled = false,
    ingredients = { ingredient("steel-chest", 2), ingredient("void-sealed-cargo", 4), ingredient("offworld-cogitator-components", 4), ingredient("processing-unit", 4) },
    order = "z[stone-cache]-n[advanced-space-cargo]"
  }
}

local prototypes = {}
for _, spec in pairs(cache_specs) do
  if not spec.space_platform_only or feature_flags.space_travel then
    local item = make_item(spec)
    local chest = make_container(spec)
    local recipe = make_recipe(spec)
    if item then prototypes[#prototypes + 1] = item end
    if chest then prototypes[#prototypes + 1] = chest end
    if recipe then prototypes[#prototypes + 1] = recipe end
  end
end

local function bank_state_animation(state)
  local root = "__tech-priests__/graphics/entity/primitive-battery-bank-v01/"
  local registration = {0, -0.01213203435596423}
  return {layers = {
    {filename=root .. "shadow.png", priority="high", width=512, height=512,
      repeat_count=8, animation_speed=0.20, scale=3.0*32/512, shift=registration, draw_as_shadow=true},
    {filename=root .. "body.png", priority="high", width=512, height=512,
      repeat_count=8, animation_speed=0.20, scale=3.0*32/512, shift=registration},
    {filename=root .. state .. ".png", priority="high", width=512, height=512,
      frame_count=8, line_length=8, animation_speed=0.20, scale=3.0*32/512, shift=registration, draw_as_glow=true}
  }}
end

local function make_battery_bank()
  -- 0.1.549: this is an accumulator mechanically, but it must use the
  -- Primitive Acclimator Battery Bank stone-cache artwork, not the vanilla
  -- accumulator sprite or the generic container prototype.
  local name = "tech-priests-stone-cache-primitive-acclimator-battery-bank"
  local source = data.raw.accumulator and data.raw.accumulator["accumulator"]
  if not source then return nil end
  local bank = table.deepcopy(source)
  bank.name = name
  bank.localised_name = { "entity-name." .. name }
  bank.localised_description = { "entity-description." .. name }
  bank.icon = icon_path(name)
  bank.icon_size = 64
  bank.icons = nil
  bank.minable = { mining_time = 0.45, result = name }
  bank.max_health = math.max(bank.max_health or 150, 220)
  bank.collision_box = table.deepcopy(TWO_BY_TWO_COLLISION_BOX)
  bank.selection_box = table.deepcopy(TWO_BY_TWO_SELECTION_BOX)
  bank.picture = nil
  bank.charge_animation = nil
  bank.discharge_animation = nil
  bank.charge_cooldown = nil
  bank.discharge_cooldown = nil
  bank.chargable_graphics = {
    picture = picture_for(name, 0.068),
    charge_animation = bank_state_animation("charge"),
    charge_cooldown = 30,
    discharge_animation = bank_state_animation("discharge"),
    discharge_cooldown = 30
  }
  bank.charge_light = nil
  bank.discharge_light = nil
  -- Authored cabinet provides the connector backing; original wire pins,
  -- native LED states, points, signal and wire reach remain unchanged.
  if bank.circuit_connector and bank.circuit_connector.sprites then
    bank.circuit_connector.sprites.connector_main = util.empty_sprite()
    bank.circuit_connector.sprites.connector_shadow = util.empty_sprite()
    -- Seat inherited LED pixels on the authored cabinet, preserving native states.
    local sprites = bank.circuit_connector.sprites
    local dx, dy = 0.18087693924989555, -0.1448376449540326
    for _, key in ipairs({"led_blue", "led_blue_off", "led_green", "led_red"}) do
      if sprites[key] then
        local shift = sprites[key].shift or {0,0}
        sprites[key].shift = {(shift[1] or 0)+dx, (shift[2] or 0)+dy}
      end
    end
    for _, key in ipairs({"blue_led_light_offset", "red_green_led_light_offset"}) do
      if sprites[key] then sprites[key] = {sprites[key][1]+dx, sprites[key][2]+dy} end
    end
  end
  bank.water_reflection = nil
  bank.integration_patch = nil
  if bank.energy_source then
    bank.energy_source.buffer_capacity = "1MJ"
    bank.energy_source.input_flow_limit = "500kW"
    bank.energy_source.output_flow_limit = "500kW"
    bank.energy_source.render_no_network_icon = true
  end
  return bank
end

local function authored_fluid_vault_picture(facing)
  local root = "__tech-priests__/graphics/entity/pressurized-fluid-vault-v01/"
  local registration = {0, 0.05211994936611669}
  return {layers = {
    {filename=root .. facing .. "-shadow.png", width=512, height=512, scale=0.25, shift=registration, draw_as_shadow=true},
    {filename=root .. facing .. ".png", width=512, height=512, scale=0.25, shift=registration}
  }}
end

local function make_fluid_vault()
  local source = data.raw["storage-tank"] and data.raw["storage-tank"]["storage-tank"]
  if not source then return nil end
  local name = "tech-priests-stone-cache-pressurized-fluid-vault"
  local tank = table.deepcopy(source)
  tank.name = name
  tank.localised_name = { "entity-name." .. name }
  tank.localised_description = { "entity-description." .. name }
  tank.icon = icon_path(name)
  tank.icon_size = 64
  tank.icons = nil
  tank.minable = { mining_time = 0.45, result = name }
  tank.max_health = math.max(tank.max_health or 200, 260)
  tank.placeable_by = { item = name, count = 1 }
  tank.collision_box = {{-1.10, -1.10}, {1.10, 1.10}}
  tank.selection_box = {{-1.15, -1.15}, {1.15, 1.15}}
  if tank.fluid_box then
    tank.fluid_box.volume = 1000
    tank.fluid_box.pipe_connections = {
      -- Pipe access must remain on the integer north/south pipe grid so actual
      -- pipes can connect.  The vault collision box is deliberately widened
      -- after Transport Drones compatibility so these legal pipe positions stay
      -- inside the entity bounds during assignID.
      { flow_direction = "input-output", direction = defines.direction.north, position = {0, -1.0} },
      { flow_direction = "input-output", direction = defines.direction.south, position = {0, 1.0} }
    }
    -- 0.1.547: the fluid vault is a custom stone asset, not a visible clone of
    -- the vanilla storage tank.  Do not inherit base pipe-cover artwork because
    -- the south cover was rendering as a pale rectangular nub below the vault.
    tank.fluid_box.pipe_covers = nil
    tank.fluid_box.pipe_picture = nil
  end
  -- 0.1.547: replace the full storage-tank picture set, not only
  -- pictures.picture.  The inherited fluid/window/flow overlays from the vanilla
  -- tank were still being drawn on top of/below the custom vault sprite and
  -- created the stray gray-beige fluid-window nub visible under the base.
  tank.pictures = {picture = {
    north=authored_fluid_vault_picture("north"), east=authored_fluid_vault_picture("east"),
    south=authored_fluid_vault_picture("north"), west=authored_fluid_vault_picture("east")
  }}
  -- Authored fluid-vault contact draw registration: original large-tank pixel
  -- anchors do not fit this compact vessel. Only graphics/points change; native
  -- amount/temperature controls, wire reach, fluid ports and capacity stay fixed.
  local contact_draw = {
    {red={0.625,0.608916847198287}, green={0.715,0.7079117965644037}, blue_light={0.585,0.6831985931288072}, red_green_light={0.585,0.6195589828220178}, leds={led_blue={0.4524682233647529,0.4509685160079845},led_blue_off={0.4524163098783817,0.4509080899022001},led_green={0.45460472685241515,0.49606654152745644},led_red={0.45460472685241515,0.49606654152745644}}},
    {red={-0.776,0.45791684719828696}, green={-0.776,0.6469117965644036}, blue_light={-0.7725,0.49569859312880715}, red_green_light={-0.7725,0.4320589828220179}, leds={led_blue={-0.6504446386273037,0.24473540201435806},led_blue_off={-0.6504170590081606,0.24469027548913358},led_green={-0.6526843847710133,0.2898572094788752},led_red={-0.6526843847710133,0.2898572094788752}}},
    {red={0.625,0.608916847198287}, green={0.715,0.7079117965644037}, blue_light={0.585,0.6831985931288072}, red_green_light={0.585,0.6195589828220178}, leds={led_blue={0.4524682233647529,0.4509685160079845},led_blue_off={0.4524163098783817,0.4509080899022001},led_green={0.45460472685241515,0.49606654152745644},led_red={0.45460472685241515,0.49606654152745644}}},
    {red={-0.776,0.45791684719828696}, green={-0.776,0.6469117965644036}, blue_light={-0.7725,0.49569859312880715}, red_green_light={-0.7725,0.4320589828220179}, leds={led_blue={-0.6504446386273037,0.24473540201435806},led_blue_off={-0.6504170590081606,0.24469027548913358},led_green={-0.6526843847710133,0.2898572094788752},led_red={-0.6526843847710133,0.2898572094788752}}},
  }
  for i, connector in ipairs(tank.circuit_connector or {}) do
    local draw = contact_draw[i]
    if draw then
      connector.points.wire.red = draw.red
      connector.points.wire.green = draw.green
      connector.points.shadow.red = {draw.red[1]+0.08,draw.red[2]+0.08}
      connector.points.shadow.green = {draw.green[1]+0.08,draw.green[2]+0.08}
      local sprites = connector.sprites
      for _, key in ipairs({"connector_main","connector_shadow","wire_pins","wire_pins_shadow"}) do sprites[key]=util.empty_sprite() end
      for key, shift in pairs(draw.leds) do sprites[key].shift = shift end
      sprites.blue_led_light_offset=draw.blue_light
      sprites.red_green_led_light_offset=draw.red_green_light
    end
  end
  tank.water_reflection = nil
  return tank
end

local battery_name = "tech-priests-stone-cache-primitive-acclimator-battery-bank"
local fluid_name = "tech-priests-stone-cache-pressurized-fluid-vault"

prototypes[#prototypes + 1] = make_item({ name = battery_name, subgroup = "tech-priest-emergency-industry", order = "z[stone-cache]-o[battery-bank]", stack_size = 20 })
local battery = make_battery_bank()
if battery then prototypes[#prototypes + 1] = battery end
prototypes[#prototypes + 1] = make_recipe({
  name = battery_name,
  enabled = false,
  energy_required = 10,
  ingredients = { ingredient("stone", 40), ingredient("battery", 8), ingredient("copper-cable", 12), ingredient("iron-plate", 6) },
  order = "z[stone-cache]-o[battery-bank]"
})

prototypes[#prototypes + 1] = make_item({ name = fluid_name, subgroup = "tech-priest-emergency-industry", order = "z[stone-cache]-p[fluid-vault]", stack_size = 20 })
local tank = make_fluid_vault()
if tank then prototypes[#prototypes + 1] = tank end
prototypes[#prototypes + 1] = make_recipe({
  name = fluid_name,
  enabled = false,
  energy_required = 10,
  ingredients = { ingredient("stone", 40), ingredient("pipe", 8), ingredient("iron-plate", 8) },
  order = "z[stone-cache]-p[fluid-vault]"
})

data:extend(prototypes)

local function unlock_recipe(technology_name, recipe_name)
  local technology = data.raw.technology and data.raw.technology[technology_name]
  if not technology then return end
  technology.effects = technology.effects or {}
  for _, effect in pairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return end
  end
  table.insert(technology.effects, { type = "unlock-recipe", recipe = recipe_name })
end

unlock_recipe("electric-energy-accumulators", battery_name)
unlock_recipe("fluid-handling", fluid_name)
if feature_flags.space_travel then
  unlock_recipe("void-cogitator-stations", "tech-priests-basic-space-cargo-inventory")
  unlock_recipe("void-cogitator-stations", "tech-priests-advanced-space-cargo-inventory")
end
