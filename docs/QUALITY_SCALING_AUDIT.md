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


## 2026-11-21 continued — implementation and expanded native gates
- **Martian comms hidden radar quality:** repaired `scripts/martian_infrastructure.lua`. Previously an existing hidden radar was returned without comparing its quality with the visible pylon. `M.ensure` now preserves matching helpers, replaces mismatched quality, culls duplicates, and invalidates the stale helper destruction registration before replacing it. Initial source commit `feee4b213ac75c06487f88290226d4f4ae74a7d7` was superseded by **corrective commit** `aff7c21a5acf93ac6930f6ea6fe2cbb2723aa663`, which rebuilt the file from its last known-good source after readback detected an accidental Lua replacement corruption. The corrected 146-line module retains the full event installer and was read back from `main`.
- Added `tests/unit/martian_array_quality_reconciliation.lua`: normal-to-Legendary reconciliation, idempotence, wrong-quality duplicate cleanup, cloned parent and removal without cross-parent deletion. A local Lua test of the focused source path passed; native clone/load acceptance is still required.
- Expanded `quality-entity-matrix` to iterate all 15 current `shared.combat_roster_catalog.units` (Normal and Legendary), plus all previous turrets and structures. Current fixture plans 40 turret + 54 machinery/structure + 30 AAI combat actor placements = **124**. The unit count remains roster-driven rather than hard-coded so future units join coverage.
- Strengthened native matrix to **reject** missing Legendary crafting-speed improvement, electric-pole supply/wire range bonuses, plasma burner-generator prototype output increase and altered four-module-slot contract on the six downstream hydrogen machines. It still does not claim real electrical power delivered under load.
- Added separate `quality-turret-fire` native fixture (1,200 ticks), wired into the **existing** isolated test runner without changing workflow triggers or scheduling. At 35 tiles, the Normal bunker Energy Dish (28 base range) must not damage its real enemy target while a Legendary Energy Dish (42 native range) **must** physically hit; only actual enemy health loss is accepted. Local Lua syntax pass; genuine Factorio engine result pending.
- **Remaining:** native engine load/run with cached dependencies, actual turret shots for other families, quality-preserving AAI mode replacement/mustering custody, plasma electrical load test, reactor fuel lifecycle, save/reload/multiplayer and visual proof.

No production/mod release has been published from this quality audit. Source readback and local source-only checks are not native acceptance.

## 2026-11-21 — AAI combat-unit Quality replacement observation
- `scripts/core/combat_quality_contract.lua` inspects exact source/destination `LuaEntity.quality.name` at the **existing** AAI replacement callback. Equal quality is a no-op; Normal-mode without Quality is supported. A quality loss or unpaid gain records only saveable primitive identity, Quality and tick in `storage.tech_priests.combat_quality_audit` and emits bounded logs (first 5, then each 100th).
- `combat_roster_bridge.preserve_replaced_inventory` retains its original exact item-stack swap/custody behavior. The new audit does **not** change entity quality, create replacements, interrupt AAI, alter 0338 custody, or grant items.
- Native 2.1 test must still exercise AAI's mode switch on a physically paid Legendary/Uncommon actor, then verify body and inventory Quality; **muster >Normal remains blocked** until exact ItemWithQuality debit/placement is implemented. No false 'Quality fixed' claim.
- `tests/unit/combat_roster_quality_transfer.lua` passes locally with the actual helper: matching Normal/Legendary, mismatch both directions, bounded log frequency, storage IDs, invalid entities. Added to existing manual Lua smoke list. No workflow triggers/scheduler changes.


## 2026-11-21 — native range/coverage acceptance expanded
- The existing `quality-entity-matrix` now checks **the actual canonical Cogitator operating-radius owner** for Normal and Legendary placements of every station rank; Legendary must add exactly five tiles to Normal at equal rank/force research, without modifying station or global runtime state.
- For each visible Martian communications pylon, the fixture confirms its hidden radar is the same Quality and inspects native `get_max_distance_of_nearby_sector_revealed(grade)`; Legendary coverage must exceed Normal. Radar quality and range are measured, not inferred from the pylon's icon or graphics.
- These are new **native assertions**, not successful native observations yet. They use the already registered isolated test scenario and need no additional runner, dependency download, scheduler or event authority.


## Quality matrix coverage expansion — 2026-11-21
- The current matrix now exercises **136 native placements** (40 bunker-turret quality specimens; 66 structures/production entities covering 33 types at Normal and Legendary; and 30 AAI combat-unit specimens covering the current 15-unit roster). Earlier sections reporting 124 placements describe the preceding iteration and are superseded by this count.
- Added the remaining physical emergency family: emergency miner, steam engine, laboratory, power grid, atmospheric condenser, plus the Orbital Trader. Their actual prototype identities were directly checked in `prototypes/entity.lua`, not invented.
- Because the added utility row would overlap the original combat-unit zone, actor rows were shifted to y=200/212 and 224/236, and the isolated terrain bounds extended to y=255. Pure placement-grid preflight (conservative 3×3 turrets, 8×8 utilities, 1×1 car actors) passes: 136 cases, zero model-rectangle overlap, all within test bounds.
- The existing quality-stat gates still run on actual placed entities only. **Native Factorio execution remains outstanding**; this geometric preflight is not a substitute for native `surface.create_entity` acceptance.


## Native Factorio quality receipts — Core30 (2026-11-21)

**Hardware/engine:** `OLD-CORE30-homebrew`, GTX 1660 SUPER; genuine Factorio 2.1.24 with Quality enabled. **Scope:** the retained locally cached `tech-priests-menu-pilot_0.0.1` bunker combat build, **not** the complete latest `tech-priests_src` package. No game or mod archive was downloaded.

- [Run 44973398234 — native health/range quality PASS](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/44973398234). Both actual Factorio `--create` and 120-tick `--benchmark` returned exit 0. All eight custom bunker prototypes accepted real Normal and Legendary placement, with **2.5x Legendary entity max health** and native **1.5x Legendary range multiplier**. Engine-reported HP Normal/Legendary: Autocannon 2000/5000; Chicago Piano 2000/5000; Twin Minigun 2000/5000; Twin Cannon 3000/7500; Rocket Salvo 2500/6250; Lobber 2000/5000; Energy Dish 2000/5000; Artillery 3000/7500.
- [Run 44973571998 — actual Legendary Energy Dish range hit PASS](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/44973571998). A separate real 900-tick native benchmark fired two powered bunker Energy Dishes at independent genuine hostile targets **35 tiles** away. Observed enemy HP loss: **Normal 0.00, Legendary 1665.18**. Both turrets had stored electrical energy. No scripted damage, invented kills or synthetic projectiles. Both native processes exited 0, with `PASS native legendary Energy Dish hits beyond normal range` in the original Factorio log.
- Original receipts persist on Core30 in `D:\Runner\actions-runner\_homebrew\reports\44973398234-quality-native-cache-1` and `44973571998-quality-native-cache-1`. GitHub Actions contains the native logs and exact process exit codes.
- [Full-mod preflight 44973249363](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/44973249363) confirmed native Factorio binary and locally cached AAI, but **no pinned full Tech-Priests source checkout** in its bounded search. No full-mod quality scenario ran from that attempt.

**Evidence boundary:** this is valid native engine proof for the retained bunker prototype family and live Energy Dish firing. It is **not** a full production-mod load, 136-placement acceptance, AAI inventory/replacement test, Cogitator/radar/hydrogen/reactor quality test, save/reload test, or new release. Those gates remain open pending a persistent full-source cache on the runner.

## Quality-graded plasma reactor *loaded output* acceptance

Added `tests/scenarios/quality-plasma-load/fixture.lua` to the original
isolated Factorio runner. Unlike the previous prototype-only `get_max_power_output`
check, this fixture measures electricity **generated by fuelled native
burner-generator entities under a real energy-network consumer load**. It tests
all three reactor sizes (Minoris 1 MW Normal, Majoris 2 MW Normal, Maximus
4 MW Normal) at Normal and Legendary, six isolated networks, six physical
pellet fuel deposits, and the native generated-energy counts. The source-level
scenario performs no simulated power injections and the mod's ordinary
reactor code is unchanged. Native output ratios remain unverified until the
Core30 run completes.

## Native extended-range ammunition turret firing acceptance

Added a separate `quality-bunker-ammo-range` isolated native case for the
six custom ammo-turret families not covered by the already-successful
Legendary Energy Dish shot test. Each of six pairs uses a physical
correct-category magazine/shell, independent enemy target and quality-aware
range bracket. The case requires Normal no-damage, Legendary genuine enemy
HP loss, and consumption of original ammunition. No combat results or
projectiles are scripted. Artillery is a subsequent, separate native gate.


## Core30 genuine plasma-generation output under load — accepted

**Evidence:** [Dens-Mortis native run 44980837295](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/44980837295), Factorio 2.1.24, source pin `99310f552ce3e8ed3b6cc2e1decdebf865c75dcb`, six physical isolated burner-generator entities and consumer-only electrical interfaces; native `--create` and 900-tick benchmark both exit 0. No game or graphics download.

**Actual network production over 600 simulation ticks:** Minoris Normal 10,000,000 J versus Legendary 25,000,001 J; Majoris Normal 19,999,999 J versus Legendary 50,000,002 J; Maximus Normal 39,999,998 J versus Legendary 100,000,003 J. All three ratios **2.500x**. All six reactors accepted one original contained-pellet item in the native burner inventory. The engine checked the plasma-only fuel category and measured real electrical production under demand. This confirms 1/2/4 MW Normal sustained output and 2.5/5/10 MW Legendary output for those measured periods.

**Units clarification:** `LuaEntityPrototype.get_max_power_output(quality)` yields joules **per tick**, not watts, so display MW as `output_joules_per_tick * 60 / 1,000,000`. The first fixture logged the correct *generated joule totals* but incorrectly labeled raw per-tick ratings as MW (0.017/0.033/0.067). The correction was separately committed in `9f04c47d1fa5d2a3438060520611b6d7550329de`. The original energy totals, which determine the pass, were unaffected.

**Outstanding:** multi-fuel decay/storage independence, save/reload, space-platform real placement/power, graphical animation proof, and sustained network monitoring across varying demand. The test does not assert these.

## Native automatic Artillery Quality range acceptance

A separate `quality-artillery-range` isolated engine test completes the
eight-type bunker weapon coverage. It places one Normal and one Legendary
artillery turret with real `artillery-shell` inventories and separate
charted enemy-spawner targets at 280 tiles, between the expected 224/336-tile
automatic ranges. The native engine must produce a real Legendary target
health loss and shell debit, with neither on the Normal side. The mod's
actual turret/gun prototypes are unchanged; this is test-only source.
