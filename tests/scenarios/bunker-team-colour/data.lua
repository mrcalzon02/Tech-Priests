local mod='tech-priests-bunker-family-prototype'
require('prototypes.bunker_family').register(mod)
require('prototypes.bunker_bullet_weapons').register(mod)
require('prototypes.bunker_twin_cannon').register(mod,{native_preview_only=true})
-- This fixture verifies static native ownership colour, not combat. Avoid
-- loading the unused full lobber firing/shadow atlases into its GPU process.
for name in pairs(data.raw.animation) do
  if name:find('^tp%-lobber%-') and not name:find('^tp%-lobber%-idle%-') then data.raw.animation[name]=nil end
end
for _,suffix in ipairs({'autocannon','lobber','energy-dish','chicago-piano','twin-minigun','twin-cannon'}) do
  local name='tech-priests-bunker-'..suffix
  local entity=data.raw['ammo-turret'][name] or data.raw['electric-turret'][name]
  local base=entity.base_picture or entity.graphics_set.base_visualisation.animation
  for _,direction in ipairs({'north','east','south','west'}) do
    local mask=base[direction].layers[3]
    assert(mask.apply_runtime_tint and mask.filename:find('base%-'..direction..'%-team%-mask.png$'),name..':'..direction..' missing mask')
  end
end
log('[BUNKER-TEAM-COLOUR] All six prototypes have four native force-tinted stanchion masks')
