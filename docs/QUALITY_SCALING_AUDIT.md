# Quality scaling audit — Tech-Priests custom entities

Date: 2026-11-21. Authority: `main`. Status: **source audited; real Factorio 2.1 native matrix not yet run.**

## Governing engine behavior
In Factorio 2.1, native `LuaQualityPrototype` applies quality effects to compatible entities: +30% health per quality level, +10% turret/weapon range per level (through `quality.range_multiplier`, maximum 3), crafting-machine speed, pole reach/wire connection, and eligible energy outputs. Vanilla levels are Normal=0, Uncommon=1, Rare=2, Epic=3, Legendary=5. Do **not** manually multiply engine-owned stats a second time. Official reference: https://lua-api.factorio.com/latest/prototypes/QualityPrototype.html ; https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html .

## Inspected family matrix
| Family | Source and prototype type | Expected native quality behavior | Tech-Priests-specific status / action |
| --- | --- | --- | --- |
| Bunker Autocannon | `prototypes/bunker_autocannon.lua`, ammo-turret clone | HP, turret range | Inherited natively; test actual legendary hits/ammo |
| Bunker Chicago Piano and Twin Minigun | `prototypes/bunker_bullet_weapons.lua`, ammo-turret clones | HP, range; ammo quality governs ammo effects | Inherited; quality-specific native firing still unmeasured |
| Bunker Twin Cannon | `prototypes/bunker_twin_cannon.lua`, ammo-turret clone; `scripts/twin_cannon_controller.lua` | HP, range | **Fixed:** custom line-through target scan no longer hard-coded to 36 tiles; derives radius from prototype range × placed Quality multiplier |
| Bunker Rocket Salvo | `prototypes/bunker_rocket_salvo.lua`, ammo-turret clone | HP, range | No quality-specific script multiplier found; require genuine distant rocket-hit proof |
| Bunker Lobber | `prototypes/bunker_family.lua`, ammo-turret clone | HP, range | **Fixed:** native projectile delivery ceiling no longer truncates legendary/custom quality range; attack range unchanged |
| Bunker Energy Dish | `prototypes/bunker_family.lua`, electric-turret clone | HP, beam range | **Fixed:** beam delivery maximum no longer truncates quality-scaled native attack range; native beam-hit proof still required |
| Bunker Artillery | `prototypes/bunker_artillery.lua`, artillery-turret clone | HP and artillery gun range by engine | Native turret/gun retained; test manual+automatic range in engine rather than duplicate scripting |
| Martian power pylons T1–T3 | `prototypes/martian_infrastructure.lua`, electric-pole clones | Quality-adjusted square electric supply and wire reach | **Fixed:** `scripts/defense_perimeter.lua` queries actual placed pole quality, not Normal; bounded search rectangle now covers high-quality substations |
| Martian comms arrays T1–T3 | visible electric-pole + hidden radar | Native pole reach; native radar radius | Existing `scripts/martian_infrastructure.lua` creates hidden radar with `quality=e.quality`; verify same quality after placement, cloning and reload |
| Cogitator Stations (five ranks) | `prototypes/entity.lua`, container clones | HP, quality-aware inventory size if supported | Runtime already adds quality station operating-radius bonus and pairs priest/proxy quality; test both without health double counting |
| Tech-Priest units and hidden proxy | `prototypes/entity.lua`, unit/electric-turret clones | Native HP/attack-range where applicable | Quality follows parent station in existing spawn path; test headful/native pairing |
| Combat-roster units | `prototypes/combat_roster.lua`, car-based actors | Native HP, applicable weapon range | **Open functionality gap:** `scripts/core/combat_roster_orders.lua` deliberately rejects non-Normal deployment until exact ItemWithQuality custody is provided. Do not bypass or mint free Legendary units |
| Faction factories ×3 | `prototypes/faction_factories.lua`, assembling-machine clones | Native HP/crafting speed | `module_slots=0` expressly configured; Law/Chaos doctrine modules currently cannot be installed. Decide eligibility separately |
| Hydrogen factories ×7 | `hydrogen/machine.lua`, `hydrogen/balance.lua`, assembling machines | Native HP/crafting speed; native module effects | Purifier no slots, six downstream exactly four slots; `quality_affects_module_slots=false` intentionally preserves four. Test all five entity qualities |
| Plasma reactors Minoris/Majoris/Maximus | `prototypes/plasma_reactor_family.lua`, burner-generator clones | Native HP; query `get_max_power_output(quality)` for real power behavior | **Open engine measurement:** do not assume quality multiplies its scripted MW contract until native evidence |
| Emergency miner/assembler/smelter/boiler/engine/lab, condenser | `prototypes/entity.lua`, multiple native machine types | Type-specific native HP/speed/output/fuel behavior | Most intentionally expose zero modules; cannot inherit doctrine effects without an authorized slot/eligibility change |
| Machine Spirit modules and sanctity | `scripts/core/consecration/quality_baseline.lua`, `doctrine_effects.lua` | Entity starting sanctity and module item quality | Implemented source-level; native quality, persistence and mixed-module validation outstanding |
| Walls and combat diagnostics | vanilla wall + `scripts/core/defense_layer_audit_1091.lua` | Native HP by placed quality | **Fixed:** compare `entity.health` to `entity.max_health`, not Normal `prototype.max_health` |

## Quality acceptance gate
1. Confirm native Factorio 2.1 Quality-enabled mod startup and availability of exact expected custom prototypes.
2. Place at least one specimen of each custom family at Normal and Legendary; exercise all five tiers for all eight bunker turrets. Compare native placed entity `max_health` against `prototype.get_max_health(quality)`; verify Quality identity and report observations.
3. Check native quality-adjusted turret range **through actual fired projectiles/beam hits**, including custom lobber/energy dish/twin cannon; do not accept a printed multiplier as physical hit evidence.
4. Verify connected high-quality pylons supply lasers beyond Normal reach; inspect actual helper radar quality in Martian comms arrays.
5. Compare `get_crafting_speed(quality)` and real factory outputs for ordinary, faction, emergency and hydrogen machines; check module slot invariants.
6. Measure plasma generator output using native `get_max_power_output(quality)` and a loaded electrical network; do not invent scaling.
7. Audit high-quality combat-unit physical item custody before allowing reinforced units into automated mustering.
8. Run genuine save/reload, multiplayer-relevant placement, and player-view screenshot/video proof when available.

### Source fixes in this pass
- `a12eeaf2a9eef3ce5eeeaee66d86cd19e83333f2`: quality-aware twin-cannon target radius; bunker energy-beam and grenade-delivery quality ceilings.
- `27b1ce3f0c9da5cb8d3c8afd4afcf4de3e5f3041`: power geometry uses placed pole quality; wall damage diagnostics use actual quality-adjusted max HP.
- Added source regressions for quality turret range, high-quality power coverage/wires, and damaged Legendary walls.
- **No real-engine runs or published release claimed.** Preserve `main`, existing models/animations, no new runtime loops or scheduler changes.

## Native matrix fixture added
The existing isolated runner accepts `--scenario quality-entity-matrix` using
`tests/scenarios/quality-entity-matrix/fixture.lua`. It requires the Quality
feature and every vanilla grade, then physically creates all eight bunker
weapons in five grades and 27 other custom entity prototypes at Normal and
Legendary. It checks actual placed entity health/quality, Quality multiplier,
where applicable native crafting speed and pole geometry, hidden Martian radar
quality, and logs reactor engine power outputs. A broker-owned service emits
the pass marker only in the later loaded benchmark process, not solely during
`--create`. Existing local cached mods/Factorio are reused; no CI workflow,
scheduler or dependency downloader was modified.

**Evidence level:** fixture source authored, not yet executed in Factorio. It
does not claim turret hit ranges, power production under load, reload/migration
or active defended-combat acceptance. Those require additional native probes.
