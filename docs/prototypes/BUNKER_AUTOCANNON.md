# Original bunker autocannon prototype

The owner's requested playable defensive emplacement uses the approved original bunker base and the original cannon topper on a standard **3×3** footprint. Its two layers retain the delivered cameras' shared world origin; headings are never independently recentered. The fixed base has four placement orientations, and the gun has 64 independent aiming directions with all 32 captured firing frames.

## Initial specification

| Property | Prototype |
|---|---|
| Entity / item / recipe | `tech-priests-bunker-autocannon` |
| Ammunition | `tech-priests-autocannon-magazine` |
| Magazine | 20 rounds |
| Ammunition recipe | 16 iron plates for 20 rounds |
| Equivalent rifle recipe | 8 iron plates for 20 rounds |
| Recipe resource ratio | Exactly **2× per round**, for every ingredient |
| Average firing rate | **16/3 shots/sec = 320 rounds/min** |
| Single-target impact | **552.5 physical damage**, no blast damage or piercing |
| Base sustained damage/sec | 2,946⅔ before resistance and bonuses |
| Footprint | 3×3 selection; 2.8×2.8 collision box |
| Range / health | 24 tiles / 2,000 HP |
| Unlock | Fortified autocannon emplacements; military-3 + concrete |
| Construction | 1 gun turret, 100 concrete, 100 steel, 20 iron gears, 10 advanced circuits |

These are normal-quality, unresearched reference values. The firing-rate reference is the vanilla gun turret (10 shots/sec) and tank cannon (2/3 shots/sec). Their arithmetic midpoint is 16/3. Damage uses the normal firearm round (5) and normal cannon shell's total direct impact (1,000 physical + 100 explosion = 1,100); their midpoint is 552.5. The new round delivers that amount as one physical hit.

## Exact cadence uses native magazine reload

An 11.25-tick nominal cooldown alone produced only 5 shots/sec in the real engine. The implementation therefore uses native 11-tick shots, a 20-round magazine, and a native five-tick reload: `20 × 11 + 5 = 225` ticks per 20 shots. The recoil animation completes in 11 ticks. No combat event controller, fake projectile loop, free ammunition, or extra runtime scheduler is installed.

The data-final-fixes calculation resolves donor cooldowns and ammo damage from loaded prototypes. Each ammunition recipe ingredient is copied from the rifle recipe and multiplied by `2 × autocannon_magazine_size / rifle_magazine_size`; output batch count is preserved. This is **per-round** equivalence, not a comparison between different magazine sizes. Rifle-recipe byproducts are preserved, including the existing Tech Priests waste-output contract. Other mods that change donor timings to a combination incompatible with integral reload ticks will be rejected rather than silently changing the requested cadence.

## Integration and playable add-on

`tech-priests_src/data.lua` loads the prototype; its final calculation runs before the existing final native recipe-schema conversion. It uses native ammo-turret targeting, rotation, ammo filters, physical projectiles, inserters, mining, construction, and research. Existing factory recovery/runtime authorities are unchanged. No workflow is added or restored.

The standalone **Factorio 2.1** add-on permits immediate playtesting without repacking the protected 0.1.672 baseline or declaring the whole mod a verified release. It also works alongside an older Tech Priests installation. When the integrated prototype already exists, the add-on does not create a second copy. The shipping add-on is data-only; the combat fixture and its target entities are excluded.

Build it from this checkout:

```sh
python3 tools/build_bunker_autocannon_prototype.py --out /absolute/path/prototype-build
```

Copy `tech-priests-bunker-cannon-prototype_0.1.0.zip` into Factorio's mods folder, enable it, and research the named technology. Both recipes appear in the bunker weapons subgroup. Ammo is loaded by hand or normal inserters. The ammunition uses Factorio's native cannon-shell icon; the bunker icon and all building sprites come from the actual delivered machine.

## Verification and scope

The native headless combat fixture is in `tests/scenarios/bunker-autocannon/`. It checks eight firing directions, 3×3 placement, empty-ammo behavior, rejection of rifle/tank ammo, real inserter loading, ammunition consumption, physical damage, recipe resources (including a changed multi-resource donor), research unlocks, and **every rolling 20-shot interval equaling exactly 225 ticks**. `bunker-autocannon-native-tests.json` records actual results. Graphical client rendering and the complete third-party modpack are not claimed as tested; the accompanying mounted-machine preview is a sprite assembly, not an in-game screenshot.

The approved capture package remains the high-resolution source. Production sprites use 256-pixel cells, with one 32-frame row per heading and separate idle pages. All exported PNG dimensions and hashes are recorded in `bunker-autocannon-assets.json`. The base's 2048-pixel camera record and the turret's 640-pixel camera record are converted to a common 32 pixels/world-unit scale; their resulting shifts agree to under 0.00001 tile.
