-- Real plate/water-to-shell production. No item clock tokens or decay resets.
require('native-data')
local spec=require('spec')
local machine=data.raw['assembling-machine'][spec.entity]
machine.tile_width=4;machine.tile_height=4;machine.use_mirroring=false
machine.show_recipe_icon=false;machine.show_recipe_icon_on_map=false
machine.localised_description='Welds a two-plate blank and expands it in exposed edge clamps. Water is the isolated review forming medium; production economy is provisional.'
data.raw.recipe[spec.recipe].allow_productivity=false
