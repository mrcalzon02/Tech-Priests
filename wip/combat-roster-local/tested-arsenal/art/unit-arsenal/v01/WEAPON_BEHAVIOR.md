# Weapon behavior and manufacturing — first playable pass

Exact single-weapon roster. Player guns and mounted backends share the same native gun/ammo definitions. Units and their weapon recipes share one research unlock; shared supplies may be available earlier. No separate weapon research is required. The standalone package exposes the planned unit unlock bundles until actual combat-unit recipes are loaded.

Values below are unresearched, normal quality, before resistances. Primary damage includes impact splash on the directly targeted enemy; raw DPS excludes travel time, target acquisition, downtime and misses. Capacity is attacks per physical supply item, not an extra reload delay. Recipes permit handcrafting; powered assemblers use their ordinary electricity. No separate cell charger or automatic recharge is implemented. Craft seconds are recipe work at crafting speed 1.

| Unit / weapon | Stage | Range | Shots/s | Capacity | Primary damage | Raw primary DPS | Role |
|---|---|---:|---:|---:|---:|---:|---|
| Skitarii Ranger / Galvanic rifle | Start | 24 | 2.00 | 5 | 12 | 24.0 | Starter precision rifle; long reach, five-round clips. |
| Guardsman / Lasgun | Early / red | 20 | 5.00 | 40 | 8 | 40.0 | Affordable sustained line fire; forty shots per cell. |
| Enginseer / Power axe | Early / red | 1.5 | 2.00 | 20 | 28 | 56.0 | Contact melee; induction impact, no projectile. |
| Imperial Officer / Laspistol | Green | 16 | 3.33 | 40 | 6.4 | 21.3 | Mobile sidearm; shorter range and lower output than a lasgun. |
| Lord Commissar / Bolt pistol | Green + military | 18 | 2.50 | 10 | 22.4 | 56.0 | Compact bolt sidearm; expensive ammunition. |
| Skitarii Vanguard / Radium carbine | Mid / blue | 18 | 7.50 | 30 | 10 | 75.0 | Rapid close-range fire; physical and radiation damage. |
| Skitarii Marshal / Radium serpenta | Mid / blue | 20 | 3.33 | 30 | 16 | 53.3 | Slower, stronger radium shots; greater reach and mobility. |
| Datasmith / Gamma pistol | Mid / blue | 16 | 1.50 | 8 | 60 | 90.0 | Short-range radiation burst; low cell capacity. |
| Battle Sister / Boltgun | Mid / blue | 22 | 3.33 | 10 | 28 | 93.3 | Medium-range bolt fire; higher sustained output than the pistol. |
| Dialogus / Dialogus staff | Mid / blue | 1.5 | 1.50 | 20 | 44 | 66.0 | Powered melee impact; stronger but slower than the axe. |
| Canoness / Condemnor boltgun | Later mid / blue | 28 | 2.50 | 10 | 33.6 | 84.0 | Long-range precision bolt fire; no secondary stake attack. |
| Manipulus / Magnarail lance | Advanced / purple | 34 | 0.67 | 3 | 200 | 133.3 | Longest-range single-target shot; three slugs per pack. |
| Dominus / Volkite blaster | Late / yellow | 26 | 1.00 | 8 | 185 | 185.0 | Thermal beam with a small enemy-only impact area. |
| Kataphron Breacher / Heavy arc rifle | Late / yellow | 24 | 1.33 | 8 | 180 | 240.0 | Electrical crowd damage; broad enemy-only impact area. |
| Kataphron Destroyer / Heavy grav-cannon | Final late-game unlock | 28 | 0.67 | 5 | 360 | 240.0 | Final heavy impact: broad enemy-only damage; 1.5 s target slow. |

## Manufacturing and unlocks

| Weapon | Recipe inputs | Craft seconds | Unit unlock bundle | Science |
|---|---|---:|---|---|
| Galvanic rifle | 10 iron-plate, 5 copper-plate, 2 iron-gear-wheel | 5 | Start | none |
| Lasgun | 6 iron-plate, 3 copper-plate, 1 electronic-circuit | 5 | tech-priests-arsenal-guard-muster | automation |
| Power axe | 4 steel-plate, 4 copper-plate, 3 iron-gear-wheel, 2 electronic-circuit | 8 | tech-priests-arsenal-enginseer-initiation | automation |
| Laspistol | 4 iron-plate, 2 copper-plate, 2 electronic-circuit | 4 | tech-priests-arsenal-officer-corps | automation, logistic |
| Bolt pistol | 6 steel-plate, 3 iron-gear-wheel, 2 electronic-circuit | 8 | tech-priests-arsenal-commissariat | automation, logistic, military |
| Radium carbine | 12 steel-plate, 2 advanced-circuit, 2 battery | 12 | tech-priests-arsenal-vanguard-cohorts | automation, logistic, military, chemical |
| Radium serpenta | 10 steel-plate, 4 advanced-circuit, 3 battery | 14 | tech-priests-arsenal-skitarii-command | automation, logistic, military, chemical |
| Gamma pistol | 12 steel-plate, 6 advanced-circuit, 6 battery | 16 | tech-priests-arsenal-cybernetica-protocols | automation, logistic, military, chemical |
| Boltgun | 16 steel-plate, 2 advanced-circuit, 6 iron-gear-wheel | 14 | tech-priests-arsenal-militant-orders | automation, logistic, military, chemical |
| Dialogus staff | 12 steel-plate, 4 advanced-circuit, 4 battery | 16 | tech-priests-arsenal-sacred-liturgies | automation, logistic, military, chemical |
| Condemnor boltgun | 22 steel-plate, 6 advanced-circuit, 2 battery | 20 | tech-priests-arsenal-canoness-command | automation, logistic, military, chemical |
| Magnarail lance | 30 steel-plate, 12 advanced-circuit, 10 battery, 2 electric-engine-unit | 30 | tech-priests-arsenal-galvanic-mastery | automation, logistic, military, chemical, production |
| Volkite blaster | 35 steel-plate, 8 processing-unit, 20 battery, 5 low-density-structure | 40 | tech-priests-arsenal-dominus-ascension | automation, logistic, military, chemical, production, utility |
| Heavy arc rifle | 40 steel-plate, 8 processing-unit, 16 battery, 4 electric-engine-unit | 40 | tech-priests-arsenal-heavy-servitor-chassis | automation, logistic, military, chemical, production, utility |
| Heavy grav-cannon | 60 steel-plate, 16 processing-unit, 30 battery, 15 low-density-structure, 6 electric-engine-unit | 60 | tech-priests-arsenal-grav-annihilation | automation, logistic, military, chemical, production, utility |

## Shared supply economy

| Supply | Batch inputs | Output | Seconds | Attacks per item / batch |
|---|---|---:|---:|---:|
| galvanic-clips | 2 iron-plate, 1 copper-plate | 5 | 2 | 5 / 25 |
| las-charge-cells | 1 iron-plate, 2 copper-plate, 1 electronic-circuit | 5 | 3 | 40 / 200 |
| tool-charges | 2 copper-plate, 1 electronic-circuit | 5 | 3 | 20 / 100 |
| bolt-magazines | 2 piercing-rounds-magazine, 2 steel-plate, 1 explosives | 4 | 5 | 10 / 40 |
| radium-magazines | 2 iron-plate, 1 copper-plate, 1 uranium-238 | 10 | 5 | 30 / 300 |
| gamma-cells | 2 battery, 1 advanced-circuit | 5 | 6 | 8 / 40 |
| magnarail-slug-packs | 2 steel-plate, 1 battery, 2 advanced-circuit | 5 | 8 | 3 / 15 |
| volkite-cells | 4 battery, 1 processing-unit, 4 copper-plate | 5 | 10 | 8 / 40 |
| heavy-arc-cells | 2 battery, 1 processing-unit | 5 | 10 | 8 / 40 |
| graviton-charges | 4 battery, 2 processing-unit, 2 low-density-structure | 5 | 15 | 5 / 25 |

## Effects and practical limits

Ballistics use travelling native projectiles. Las, gamma, volkite, arc and graviton use native beam deliveries, with damage applied once per attack by the beam action. Melee uses only a contact impact and electrical strike sound, with no flying projectile. Sounds and effect graphics reuse Factorio assets, with separate tinted beam prototypes. Projectile impact and beam damage are not duplicated by an additional instant hit.

Volkite: 160 direct + 25 fire in a 2-tile enemy-only radius. Heavy arc: 120 direct + 60 electric in a 3-tile enemy-only radius; this is an impact discharge, not a chain-jumping attack. Graviton: 240 direct + 120 physical in a 3.5-tile enemy-only radius, with 50% movement speed for 90 ticks on the primary target. Radiation is a native damage type, with no persistent fallout or damage-over-time system. Magnarail is a high-damage single-target shot, with no unimplemented piercing claim. No secondary weapons are added.

Player movement factors while firing range from 0.9 for melee/light sidearms to 0.25 for the grav-cannon. Those are player handling penalties, not automatic changes to AAI vehicle movement. Real actor placement, eight-facing muzzle animation and AAI melee approach remain a separate integration gate. The package does not create combat units or faction buildings.

Native validation measures ammo consumption, per-shot damage, cadence, range, enemy splash/friendly exclusion, shared unit/weapon research and component crafting. The standalone data audit checks science ceilings, manufacturing ingredient reachability and unchanged vanilla/bunker definitions. Full modpack balance and owner visual acceptance remain pending.
