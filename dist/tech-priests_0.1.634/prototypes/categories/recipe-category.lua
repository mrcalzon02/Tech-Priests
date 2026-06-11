-- Tech Priests - recipe categories.

data:extend({
  {
    type = "recipe-category",
    name = "orbital-trader"
  },
  {
    type = "recipe-category",
    name = "citadel-manufactoreo"
  },
  {
    type = "recipe-category",
    name = "tech-priests-atmospheric-condensing"
  },
  {
    -- Hidden zero-input pseudo-mining recipes. Only the Martian Emergency
    -- Micro-Miner is assigned this category, so the recipes remain isolated
    -- from normal assemblers and player crafting.
    type = "recipe-category",
    name = "tech-priests-emergency-mining"
  },
  {
    -- Emergency ore-to-metal rites for the Martian Emergency Assembler. The
    -- assembler also accepts ordinary smelting recipes, but this private
    -- category lets the mod expose compatibility-wrapped ore recipes without
    -- granting them to normal furnaces or assemblers.
    type = "recipe-category",
    name = "tech-priests-emergency-smelting"
  }
})
