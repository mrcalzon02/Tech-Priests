-- Tech Priests - crafting menu organization.

data:extend({
  {
    type = "item-group",
    name = "tech-priests",
    order = "z[tech-priests]",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64
  },
  {
    type = "item-subgroup",
    name = "tech-priest-cogitators",
    group = "tech-priests",
    order = "a[cogitators]"
  },
  {
    type = "item-subgroup",
    name = "tech-priest-sanctification",
    group = "tech-priests",
    order = "b[sanctification]"
  },
  {
    type = "item-subgroup",
    name = "tech-priest-orbital-trade",
    group = "tech-priests",
    order = "c[orbital-trade]"
  },
  {
    type = "item-subgroup",
    name = "tech-priest-emergency-industry",
    group = "tech-priests",
    order = "d[emergency-industry]"
  },
  {
    -- 0.1.415: Void-Sealed Cargo gacha/crate outputs live here so the
    -- inventory tab does not scatter strange parallel equipment across vanilla
    -- logistics, combat, and intermediate subgroups during testing.
    type = "item-subgroup",
    name = "tech-priest-void-cargo",
    group = "tech-priests",
    order = "e[void-cargo]"
  }
})
