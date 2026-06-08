-- Tech Priests - item prototypes.


local MARTIAN_MICRO_ICON_SIZE = 128
local MARTIAN_MICRO_ICON_PATH = "__tech-priests__/graphics/icons/martian-micro/"

local function tech_priests_micro_icon_path(name)
  return MARTIAN_MICRO_ICON_PATH .. name .. ".png"
end

local function soften_station_tint_0311(tint)
  tint = tint or { r = 1, g = 1, b = 1, a = 1 }
  local blend = 0.48
  return {
    r = 1.0 - ((1.0 - (tint.r or 1.0)) * blend),
    g = 1.0 - ((1.0 - (tint.g or 1.0)) * blend),
    b = 1.0 - ((1.0 - (tint.b or 1.0)) * blend),
    a = 1.0
  }
end

local stations = {
  { name = "junior-cogitator-station", order = "a", icon = "__tech-priests__/graphics/icons/junior-cogitator-station.png", tint = { r = 1.0, g = 0.58, b = 0.18, a = 1.0 } },
  { name = "intermediate-cogitator-station", order = "b", icon = "__tech-priests__/graphics/icons/cogitator-station.png", tint = { r = 0.70, g = 0.70, b = 0.70, a = 1.0 } },
  { name = "senior-cogitator-station", order = "c", icon = "__tech-priests__/graphics/icons/senior-cogitator-station.png", tint = { r = 0.92, g = 0.10, b = 0.08, a = 1.0 } },
  { name = "planetary-magos-cogitator-station", order = "d", icon = "__tech-priests__/graphics/icons/planetary-magos-cogitator-station.png", tint = { r = 0.08, g = 0.07, b = 0.06, a = 1.0 } },
  { name = "void-cogitator-station", order = "e", icon = "__tech-priests__/graphics/icons/void-cogitator-station.png", tint = { r = 1.00, g = 0.96, b = 0.86, a = 1.0 } }
}

local items = {}
for _, station in pairs(stations) do
  table.insert(items, {
    -- 0.1.301: permanent named Cogitator cells carry identity/inventory
    -- preservation tags, so they must be unstackable and tag-capable.
    type = "item-with-tags",
    name = station.name,
    icon = nil,
    icon_size = nil,
    icons = {
      {
        icon = station.icon or "__tech-priests__/graphics/icons/cogitator-station.png",
        icon_size = 64,
        tint = soften_station_tint_0311(station.tint)
      }
    },
    subgroup = "tech-priest-cogitators",
    order = "d[tech-priests]-" .. station.order .. "[" .. station.name .. "]",
    place_result = station.name,
    stack_size = 1
  })
end


table.insert(items, {
  type = "item",
  name = "mechanical-detritus",
  icon = "__tech-priests__/graphics/icons/mechanical-detritus.png",
  icon_size = 64,
  subgroup = "tech-priest-cogitators",
  order = "a[consecration]-b[mechanical-detritus]",
  stack_size = 10
})

local consecration_materials = {
  { name = "ritual-salt", order = "c[salt]", stack_size = 100 },
  { name = "pure-carbon", order = "d[pure-carbon]", stack_size = 100 },
  { name = "sodium-carbonate", order = "e[sodium-carbonate]", stack_size = 100 },
  { name = "wood-pulp", order = "f[wood-pulp]", stack_size = 200 }
}

for _, material in pairs(consecration_materials) do
  table.insert(items, {
    type = "item",
    name = material.name,
    icon = "__tech-priests__/graphics/icons/" .. material.name .. ".png",
    icon_size = 64,
    subgroup = "tech-priest-sanctification",
    order = "b[materials]-" .. material.order,
    stack_size = material.stack_size
  })
end


table.insert(items, {
  type = "capsule",
  name = "sacred-machine-oil",
  icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
  icon_size = 64,
  subgroup = "tech-priest-sanctification",
  order = "a[consecration]-a[sacred-machine-oil]",
  stack_size = 100,
  flags = { "spawnable" },
  capsule_action = {
    type = "throw",
    attack_parameters = {
      type = "projectile",
      activation_type = "throw",
      ammo_category = "capsule",
      cooldown = 15,
      range = 8,
      projectile_creation_distance = 0.6,
      ammo_type = {
        target_type = "position",
        action = {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = "sacred-machine-oil-projectile",
            starting_speed = 0.35
          }
        }
      }
    }
  }
})


-- 0.1.590 Data Spike: counter-schism reclaim capsule.  It uses a script-trigger
-- projectile so runtime can decide whether the struck hostile entity is a
-- Tech-Priest pair, station, machine, wall, turret, or ordinary reclaimable
-- structure.
table.insert(items, {
  type = "capsule",
  name = "tech-priests-data-spike",
  icon = "__tech-priests__/graphics/icons/data-spike.png",
  icon_size = 64,
  subgroup = "tech-priest-cogitators",
  order = "z[conclave]-a[data-spike]",
  stack_size = 50,
  flags = { "spawnable" },
  capsule_action = {
    type = "throw",
    attack_parameters = {
      type = "projectile",
      activation_type = "throw",
      ammo_category = "capsule",
      cooldown = 45,
      range = 32,
      projectile_creation_distance = 0.6,
      ammo_type = {
        target_type = "entity",
        action = {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = "tech-priests-data-spike-projectile",
            starting_speed = 0.65
          }
        }
      }
    }
  }
})


local orbital_trader_icon = "__tech-priests__/graphics/icons/orbital-trader.png"

table.insert(items, {
  type = "item",
  name = "orbital-trader",
  icon = orbital_trader_icon,
  icon_size = 128,
  subgroup = "tech-priest-orbital-trade",
  order = "a[orbital-trader]",
  place_result = "orbital-trader",
  stack_size = 5
})

local mid_tier_materials = {
  { name = "paraffin", order = "g[paraffin]", stack_size = 100 },
  { name = "sacred-candle", order = "h[sacred-candle]", stack_size = 100 }
}

for _, material in pairs(mid_tier_materials) do
  table.insert(items, {
    type = "item",
    name = material.name,
    icon = "__tech-priests__/graphics/icons/" .. material.name .. ".png",
    icon_size = 64,
    subgroup = "tech-priest-sanctification",
    order = "b[materials]-" .. material.order,
    stack_size = material.stack_size
  })
end

table.insert(items, {
  type = "capsule",
  name = "machine-maintenance-litany",
  icon = "__tech-priests__/graphics/icons/machine-maintenance-litany.png",
  icon_size = 64,
  subgroup = "tech-priest-sanctification",
  order = "a[consecration]-b[machine-maintenance-litany]",
  stack_size = 50,
  flags = { "spawnable" },
  capsule_action = {
    type = "throw",
    attack_parameters = {
      type = "projectile",
      activation_type = "throw",
      ammo_category = "capsule",
      cooldown = 15,
      range = 8,
      projectile_creation_distance = 0.6,
      ammo_type = {
        target_type = "position",
        action = {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = "sacred-machine-oil-projectile",
            starting_speed = 0.35
          }
        }
      }
    }
  }
})

table.insert(items, {
  type = "capsule",
  name = "sacred-incense-grenade",
  icon = "__tech-priests__/graphics/icons/sacred-incense-grenade.png",
  icon_size = 64,
  subgroup = "tech-priest-sanctification",
  order = "a[consecration]-c[sacred-incense-grenade]",
  stack_size = 50,
  capsule_action = {
    type = "throw",
    attack_parameters = {
      type = "projectile",
      activation_type = "throw",
      ammo_category = "capsule",
      cooldown = 30,
      range = 25,
      projectile_creation_distance = 0.6,
      ammo_type = {
        target_type = "position",
        action = {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = "sacred-incense-projectile",
            starting_speed = 0.30
          }
        }
      }
    }
  }
})

table.insert(items, {
  type = "capsule",
  name = "ritual-of-machine-appeasement",
  icon = "__tech-priests__/graphics/icons/ritual-of-machine-appeasement.png",
  icon_size = 64,
  subgroup = "tech-priest-sanctification",
  order = "a[consecration]-c[ritual-of-machine-appeasement]",
  stack_size = 25,
  flags = { "spawnable" },
  capsule_action = {
    type = "throw",
    attack_parameters = {
      type = "projectile",
      activation_type = "throw",
      ammo_category = "capsule",
      cooldown = 15,
      range = 8,
      projectile_creation_distance = 0.6,
      ammo_type = {
        target_type = "position",
        action = {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = "sacred-machine-oil-projectile",
            starting_speed = 0.35
          }
        }
      }
    }
  }
})


local orbital_imports = {
  { name = "offworld-cogitator-components", order = "b[imports]-a[cogitator]" },
  { name = "servitor-parts", order = "b[imports]-b[servitor]" },
  { name = "relic-fragment", order = "b[imports]-c[relic]" },
  { name = "void-sealed-cargo", order = "b[imports]-d[cargo]" }
}

for _, item in pairs(orbital_imports) do
  table.insert(items, {
    type = "item",
    name = item.name,
    icon = "__tech-priests__/graphics/icons/" .. item.name .. ".png",
    icon_size = 64,
    subgroup = "tech-priest-orbital-trade",
    order = item.order,
    stack_size = 50
  })
end

-- 0.1.415: Void-Sealed Cargo is no longer only a station ingredient.  It now
-- supports a gacha/crate doctrine of low-probability salvage: strange Mechanicus
-- intermediates, odd parallel vanilla equipment, and weapon/ammunition curios.
-- Icons deliberately reuse in-mod or base-game icons until the Alpha Art pass
-- creates bespoke sealed-cargo outputs.
local function tech_priests_void_cargo_icon(base_icon, tint)
  return {
    {
      icon = base_icon or "__tech-priests__/graphics/icons/void-sealed-cargo.png",
      icon_size = 64,
      tint = tint or { r = 0.82, g = 0.92, b = 1.0, a = 1.0 }
    },
    {
      icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
      icon_size = 64,
      scale = 0.24,
      shift = { 8, 8 },
      tint = { r = 0.45, g = 1.0, b = 0.55, a = 0.85 }
    }
  }
end

local void_cargo_intermediates_0415 = {
  {
    name = "auspex-scrap",
    icon = "__base__/graphics/icons/radar.png",
    tint = { r = 0.70, g = 0.95, b = 1.0, a = 1.0 },
    order = "a[auspex-scrap]"
  },
  {
    name = "hexagrammic-circuit-shard",
    icon = "__base__/graphics/icons/advanced-circuit.png",
    tint = { r = 0.85, g = 0.40, b = 1.0, a = 1.0 },
    order = "b[hexagrammic-circuit-shard]"
  },
  {
    name = "archeotech-capacitor",
    icon = "__base__/graphics/icons/battery.png",
    tint = { r = 0.92, g = 0.90, b = 0.55, a = 1.0 },
    order = "c[archeotech-capacitor]"
  },
  {
    name = "micro-servitor-actuator",
    icon = "__base__/graphics/icons/engine-unit.png",
    tint = { r = 0.78, g = 0.62, b = 0.52, a = 1.0 },
    order = "d[micro-servitor-actuator]"
  },
  {
    name = "machine-spirit-bound-relay",
    icon = "__base__/graphics/icons/electronic-circuit.png",
    tint = { r = 0.40, g = 1.0, b = 0.55, a = 1.0 },
    order = "e[machine-spirit-bound-relay]"
  },
  {
    name = "sanctified-lens-array",
    icon = "__base__/graphics/icons/solar-panel.png",
    tint = { r = 0.70, g = 0.92, b = 1.0, a = 1.0 },
    order = "f[sanctified-lens-array]"
  },
  {
    name = "plasma-coil-reliquary",
    icon = "__base__/graphics/icons/processing-unit.png",
    tint = { r = 0.45, g = 0.80, b = 1.0, a = 1.0 },
    order = "g[plasma-coil-reliquary]"
  },
  {
    name = "void-burned-cogitator-core",
    icon = "__tech-priests__/graphics/icons/offworld-cogitator-components.png",
    tint = { r = 0.60, g = 0.55, b = 0.80, a = 1.0 },
    order = "h[void-burned-cogitator-core]"
  },
  {
    name = "red-robe-fiber-bundle",
    icon = "__base__/graphics/icons/low-density-structure.png",
    tint = { r = 1.0, g = 0.18, b = 0.12, a = 1.0 },
    order = "i[red-robe-fiber-bundle]"
  },
  {
    name = "noospheric-targeter",
    icon = "__base__/graphics/icons/radar.png",
    tint = { r = 0.35, g = 1.0, b = 0.65, a = 1.0 },
    order = "j[noospheric-targeter]"
  },
  {
    name = "combat-servitor-targeting-eye",
    icon = "__base__/graphics/icons/radar.png",
    tint = { r = 1.0, g = 0.25, b = 0.20, a = 1.0 },
    order = "k[combat-servitor-targeting-eye]"
  },
  {
    name = "sealed-ration-cache",
    icon = "__base__/graphics/icons/wooden-chest.png",
    tint = { r = 0.92, g = 0.72, b = 0.45, a = 1.0 },
    order = "l[sealed-ration-cache]"
  },
  {
    name = "omen-bearing-data-slate",
    icon = "__base__/graphics/icons/constant-combinator.png",
    tint = { r = 0.60, g = 1.0, b = 0.72, a = 1.0 },
    order = "m[omen-bearing-data-slate]"
  },
  {
    name = "spent-phosphor-lumen",
    icon = "__base__/graphics/icons/small-lamp.png",
    tint = { r = 0.95, g = 0.95, b = 0.65, a = 1.0 },
    order = "n[spent-phosphor-lumen]"
  },
  {
    name = "ritually-suspect-machine-plate",
    icon = "__base__/graphics/icons/steel-plate.png",
    tint = { r = 0.75, g = 0.78, b = 0.85, a = 1.0 },
    order = "o[ritually-suspect-machine-plate]"
  },
  {
    name = "void-chilled-lubricant-ampoule",
    icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
    tint = { r = 0.50, g = 0.85, b = 1.0, a = 1.0 },
    order = "p[void-chilled-lubricant-ampoule]"
  }
}

for _, spec in pairs(void_cargo_intermediates_0415) do
  table.insert(items, {
    type = "item",
    name = spec.name,
    icons = tech_priests_void_cargo_icon(spec.icon, spec.tint),
    subgroup = "tech-priest-void-cargo",
    order = spec.order,
    stack_size = 50
  })
end

local function tech_priests_copy_named_prototype_0415(proto_type, source_name, new_name, fallback_icon, mutate)
  local source = data.raw[proto_type] and data.raw[proto_type][source_name]
  local prototype
  if source then
    prototype = table.deepcopy(source)
    prototype.name = new_name
    prototype.localised_name = { "item-name." .. new_name }
    prototype.localised_description = { "item-description." .. new_name }
    prototype.subgroup = "tech-priest-void-cargo"
    prototype.order = "z[void-gear]-" .. new_name
    prototype.icons = tech_priests_void_cargo_icon((source.icon or fallback_icon), { r = 0.82, g = 0.96, b = 1.0, a = 1.0 })
    prototype.icon = nil
    prototype.icon_size = nil
  else
    prototype = {
      type = "item",
      name = new_name,
      localised_name = { "item-name." .. new_name },
      localised_description = { "item-description." .. new_name },
      icons = tech_priests_void_cargo_icon(fallback_icon, { r = 0.82, g = 0.96, b = 1.0, a = 1.0 }),
      subgroup = "tech-priest-void-cargo",
      order = "z[void-gear]-" .. new_name,
      stack_size = 10
    }
  end
  if mutate then mutate(prototype) end
  table.insert(items, prototype)
end

tech_priests_copy_named_prototype_0415("gun", "submachine-gun", "las-carbine", "__tech-priests__/graphics/icons/las-carbine.png", function(gun)
  gun.order = "q[las-carbine]"
  if gun.attack_parameters then
    gun.attack_parameters.range = (gun.attack_parameters.range or 18) + 1
    if gun.attack_parameters.cooldown then
      gun.attack_parameters.cooldown = math.max(1, gun.attack_parameters.cooldown * 0.94)
    end
  end
end)

tech_priests_copy_named_prototype_0415("ammo", "piercing-rounds-magazine", "hot-shot-power-cell", "__tech-priests__/graphics/icons/hot-shot-power-cell.png", function(ammo)
  ammo.order = "r[hot-shot-power-cell]"
  ammo.magazine_size = ammo.magazine_size or 10
  ammo.stack_size = 100
end)

tech_priests_copy_named_prototype_0415("armor", "light-armor", "rite-sealed-flak-vest", "__base__/graphics/icons/light-armor.png", function(armor)
  armor.order = "s[rite-sealed-flak-vest]"
  armor.durability = math.floor((armor.durability or 800) * 1.10)
  armor.inventory_size_bonus = (armor.inventory_size_bonus or 0) + 2
end)

tech_priests_copy_named_prototype_0415("repair-tool", "repair-pack", "mars-pattern-repair-kit", "__base__/graphics/icons/repair-pack.png", function(tool)
  tool.order = "t[mars-pattern-repair-kit]"
  tool.speed = (tool.speed or 2) * 1.10
  tool.durability = math.floor((tool.durability or 300) * 1.10)
  tool.stack_size = 100
end)


-- Horrid emergency micro-industry: one-tile stopgap machines for Tech-Priest survival doctrine.
local emergency_industry_items = {
  {
    name = "tech-priests-emergency-miner",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-miner"),
    order = "a[emergency-miner]"
  },
  {
    name = "tech-priests-emergency-boiler",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-boiler"),
    order = "b[emergency-boiler]"
  },
  {
    name = "tech-priests-atmospheric-water-condenser",
    icon = tech_priests_micro_icon_path("tech-priests-atmospheric-water-condenser"),
    order = "c[atmospheric-water-condenser]"
  },
  {
    name = "tech-priests-emergency-steam-engine",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-steam-engine"),
    order = "d[emergency-steam-engine]"
  },
  {
    name = "tech-priests-emergency-smelter",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-smelter"),
    order = "e[emergency-smelter]"
  },
  {
    name = "tech-priests-emergency-assembler",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-assembler"),
    order = "f[emergency-assembler]"
  },
  {
    name = "tech-priests-emergency-laboratorium",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-laboratorium"),
    order = "g[emergency-laboratorium]"
  },
  {
    name = "tech-priests-emergency-power-grid",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-power-grid"),
    order = "h[emergency-power-grid]"
  }
}

for _, item in pairs(emergency_industry_items) do
  table.insert(items, {
    type = "item",
    name = item.name,
    icon = item.icon,
    icon_size = MARTIAN_MICRO_ICON_SIZE,
    subgroup = "tech-priest-emergency-industry",
    order = item.order,
    place_result = item.name,
    stack_size = 20
  })
end


data:extend(items)
