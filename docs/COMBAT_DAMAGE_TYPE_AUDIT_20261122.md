# Tech-Priests combat damage taxonomy and wall doctrine — source-backed audit

**Baseline examined:** `main` at `7c1867938e045858c6c1504e929d2b32af9720ad`, Tech-Priests `0.1.687`, and native combat archives retained in Dens-Mortis. This audit concerns **damage application** (Factorio `DamageParameters.type`), **not** ammunition categories or ammo names.

**Implementation status:** Four namespaced damage-type prototypes and their English names are now *registered in the data stage*. **No ammunition, projectiles, biter attacks, existing wall prototypes, weapons, resistances, or damage values were retagged or changed.** Wall variants and retyping proposals below are designs for A/B/C trials, not implemented entities. The native Factorio 2.1 startup and combat checks for these new prototype identifiers are pending.

## Existing engine vocabulary

Vanilla uses eight damage types: `physical`, `impact`, `poison`, `explosion`, `fire`, `laser`, `acid`, `electric`. The engine supports additional `damage-type` prototypes, with independent target `resistances={type,decrease,percent}`. **A custom type is only a new resistance category.** Damage over time, armor shredding, slowing, ignition or chain propagation requires separate stickers, trigger actions or explicit runtime logic.

New *registered but currently unused in weapon damage*: `tech-priests-plasma`, `tech-priests-corrosive`, `tech-priests-radiation`, `tech-priests-gravitic`. Names are namespaced to prevent collision with vanilla/other mods. We intentionally do **not** add custom `thermal`, `electric`, `acid` or `explosive` types yet: built-in `fire`, `electric`, `acid` and `explosion` already cover those channels.

**Warning:** If a weapon is reassigned to a new damage type while biters/structures still have no matching resistance, it may bypass their current armor. Never interpret `damage_type` changes as cosmetic. A split attack processes each damage instance against its own resistance, so preserving the sum of raw damage does *not* necessarily preserve effective DPS.

## Actual live combat-roster damage versus proposed doctrine

The catalog `tech-priests_src/shared/combat_roster_catalog.lua` defines ten ammunition families for 15 AAI units; `tech-priests_src/prototypes/combat_roster.lua` consumes `a.damage_type` as the real native hit type.

| Ammo family; weapons using it | Current hit type | Proposed B/C target | Priority |
|---|---|---|---|
| Galvanic · Ranger rifle | `physical` | **Keep:** solid kinetic projectile | Keep |
| Las · Guardsman lasgun / Officer laspistol | `laser` | **Keep:** coherent energy beam | Keep |
| Induction · Enginseer axe / Dialogus staff | `physical` | 70% physical + 30% electric, then 30/70 alternative | P2 |
| Bolt · Commissar, Sister, Canoness | `physical` | 80% physical + 20% **direct** explosion; independent small-radius blast C | P1 |
| Radium · Vanguard carbine / Marshal serpenta | `poison` | 20% physical + 80% **radiation**; test an alternate 50/50 against armored enemies | P1 |
| Gamma · Datasmith pistol | `laser` | 100% **radiation**; compare gamma/laser hybrid | P1 |
| Magnarail · Manipulus lance | `physical` | **Keep physical:** kinetic slug regardless of electromagnetic launcher | Keep |
| Volkite · Dominus blaster | `laser` | 30% laser + 70% **fire** (thermal injury); separate follow-up ignition mechanic | P2 |
| Arc · Breacher heavy arc rifle | `electric` | **Keep electric**; future chain-jump mechanics are separate | Keep |
| Graviton · Destroyer heavy grav cannon | `physical` | 30% physical + 70% **gravitic**, with 100% gravitic as separate candidate | P1 |

These are **candidate raw component shares**, not engine-approved balance numbers. The catalog is marked *generated* from `docs/data/combat-weapons-and-ammunition.json` / `tools/generate_combat_roster.py`, yet those sources were absent at those paths on audited `main`. **Recover the generator/source authority before retyping roster ammo; do not hand-edit the generated catalog.**

## Bunker weapon inheritance: damage must be inspected in final prototypes

| Bunker | Source of actual damage | Proposed treatment |
|---|---|---|
| Autocannon | Own `tech-priests-autocannon-projectile`, explicitly **physical** | Keep physical; test penetration and armor matchups |
| Chicago Piano | Native gun-turret ammunition effects | Physical magazines, unchanged; low DPS at evolution 1.0 requires target/armor review |
| Twin Minigun | Native gun-turret ammunition effects, doubled consumption and damage modifier | Physical magazines, unchanged initially; test rapid-fire role |
| Twin Cannon | **Vanilla cannon-shell** category and actual vanilla projectile effects: physical and explosive components depend on selected shell | Do **not** rewrite shared vanilla shells; reduce/check splash radius and friendly fire via an opt-in dedicated projectile or targeting behavior |
| Rocket Salvo | Native rocket/ammo `rocket` category; selected ammo's blast effects | Keep shared rocket ammo unchanged; test actual splash, 6-shot burst, reload and resource cost |
| Lobber | Clones grenade projectile; each packed grenade/capsule supplies its own original effects | Different grenade packs can be explosive/poison/fire/etc.; preserve per-ammo composition and test radius/friendly splash separately |
| Energy Dish | Clones the vanilla **electric-beam**, changes amount/cooldown without explicitly changing damage type | Verify final loaded beam's actual `damage.type` in engine; don't infer `laser` from the visual or turret base |
| Artillery | Native artillery turret/gun and selected vanilla artillery shell effects | Preserve vanilla shell identities; test direct + explosive components, range/Quality, friendly splash and economics |

**Plasma**: metallic-hydrogen plasma **reactors are power generators, not existing plasma weapons** in this mod. The new plasma damage channel is future-proofing for an authored plasma lance/cannon, not a claim that one already fires. **Corrosive**: existing biter acid is `acid`; reserve `tech-priests-corrosive` for explicit persistent material-corrosion effects with separate state/tick logic, not merely a renamed spitter attack.

## Wall resistance doctrine (placeholder art, not yet built)

Future entities (names proposed): `tech-priests-wall-reinforced`, `tech-priests-wall-blast`, `tech-priests-wall-fire`, `tech-priests-wall-ballistic`, `tech-priests-wall-corrosion`.

Use visually **color-tinted vanilla walls** for early test prototypes. Same 1×1 footprint, collision, fast replacement, repairability and placement interactions initially. Distinct recipes/research costs can follow once physical resistance results are measured. No final 3D/HR art is authorized until roles are validated.

| Wall | Strong resistance | Weak or ordinary channel | Purpose |
|---|---|---|---|
| Reinforced | Moderate physical, explosion, fire | None extreme | General-purpose control |
| Blast | Explosion + moderate physical | Acid/corrosive | Mitigate Twin Cannon/Lobber friendly splash |
| Fire-sealed | Fire + plasma | Physical / explosion | Flamethrowers, thermal rays and new plasma |
| Ballistic | Physical + impact | Explosion, corrosive | Bullets, biters and kinetic slugs |
| Corrosion-sealed | **Both** vanilla acid and new corrosive | Physical / explosion | Spitter/chemical attacks and future acid-over-time |

All resistances must be **less than 100%** and tested for real net damage after flat and percentage protection. High flat armor against low-damage rapid fire can create unexpected near-immunity even without 100% percentage resistance. Full immunity is explicitly excluded from the first A/B/C.

## Priority A/B/C native testing matrix

1. **Friendly splash first** — with original 12 Twin Cannons and 48 evolution-1.0 attackers at the known two-wall/seven-tile layout: **A** current shell/prototype; **B** original shell damage with smaller *dedicated* blast radius; **C** radius B plus owner-selected blast-resistant wall. Hold total enemy damage, target counts, wall geometry and ammunition supply separately constant as far as mechanically possible. Instrument enemy hit totals, friendly-wall/tower/AAI damage, wall segment deaths by final hitter, first breach, kills, ammunition and survival. Preserve ammo compatibility: never globally nerf vanilla or another mod's artillery/shells.
2. **Radiation and gravitic type trials** — for the 15-unit roster: **A** current vanilla type; **B** 100% candidate new type where appropriate; **C** mixed kinetic/energy components at the amounts in the table. Compare equal raw damage *and separately actual post-resistance DPS*, against Normal and max-evolution biters and armored structures. Test indirect/cross-mod resistances.
3. **Bolt/induction/volkite role splits** — **A** current; **B** two-component direct hits without new splash; **C** a distinct small-area or status action *separately*, with explicit friendly-fire and UPS logging. Never add a status effect by silently retyping damage.
4. **Wall cross-product** — 5 wall candidates × evolution 0, .25, .5, .75, 1 × 1/2/3 wall layers × requested 3/7/13 tile clearance × mono/cost-matched vanilla/mixed Tech-Priests loadouts. Start with representative subsets, then expand promising candidates across ≥3 reproducible seeds. Treat wave elimination, perimeter breach, actual friendly fire, ammo costs and survival as **separate metrics**, not one `PASS` label.
5. **Quality/research and source audit** — verify native 2.1 damage types and types from all selected ammo, both standard and Legendary turrets and ammo, current research modifiers, actual resistances and source pin. Compare a second current-head A baseline before interpreting old v0.1.687 benchmark results.

## Why this is urgent

Native `Dens-Mortis` [35-case fortification matrix](https://github.com/mrcalzon02/Dens-Mortis/blob/main/evidence/tech-priests/fortification/full-44928381052.md): 35/35 valid, only 12/35 waves eliminated, 0/35 permanently unbreached. The [friendly-fire diagnostic](https://github.com/mrcalzon02/Dens-Mortis/blob/main/evidence/tech-priests/fortification/friendly-fire-44946785702.md) found mono Twin Cannon inflicted **128,414** friendly wall damage plus **12,900** friendly turret and **1,000** defender/support damage, with **161** walls killed by cannon fire out of **167** walls destroyed. Mono Rocket Salvo killed the same 48 attackers, with zero recorded direct friendly damage and 19 wall losses. This is why damage **type**, damage **radius** and wall **resistance** must be independently evaluated.

The audit is reproducible from exact repository source using `python tools/check_combat_damage_taxonomy.py` (source only, no mod boot). Follow with real cached Core30/Steam Factorio 2.1 startup, actual final-prototype damage-type readback, and headed combat captures before publishing a balance change. Existing runner schedules, model installations, resources, weapon definitions and save assets must remain untouched until reviewed.

## Verified source gate — 2026-11-22

The exact source revision `c80cf44ba424ad22318362d8a86c3060cc02a018` passed [GitHub Actions 45123322306](https://github.com/mrcalzon02/Tech-Priests/actions/runs/45123322306): the read-only roster/type/locale checker reported `status=passed` for **four namespaced types, ten original ammo families and fifteen AAI units**; all **ten negative and invariance tests passed**, with no Factorio install or model assets downloaded. A preexisting orphan Git submodule entry prevented standard checkout; the successful source job used an eight-file, commit-pinned sparse Git fetch instead. **This verifies source structure only**. The engine startup, live turret projectile, new wall entities, animations, and A/B/C combat balance remain unverified.
