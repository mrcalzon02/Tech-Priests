# 1268 — Doctrinal factory organization matrix and research

**Status:** Fourteen named organization strategies mapped; source-level layout scoring and read-only recipe analysis implemented. No automatic city-block, main-bus, rail-megabase or sushi factory has been constructed by this work. These are competing objectives, not separate physics or permission to change existing machines.

**Ownership:** `scripts/core/doctrine_map.lua` supplies canonical faction keys. It is social/personality metadata. A priest's opinion, alignment, schism, or rank **must never silently select an active factory construction strategy**. Engineering doctrine must be explicitly requested or assigned by a later user-approved planning setting. Factorio-native entities, real recipe and inventory state, physical construction/custody and measured consumption stay authoritative.

## Online research — why there is no universal layout

1. [Factorio Wiki — Main bus](https://wiki.factorio.com/Main_bus). A bus provides predictable shared ingredients, taps and expansion, but demands more belts, land and tied-up material. Reserve growth margins and crossing corridors; multiple parallel lines are only useful when the native production rate can actually feed them. This is *not* automatically best for an early compact base.
2. [Factorio Wiki — Transport use cases](https://wiki.factorio.com/Tutorial:Transport_use_cases). Belts are predictable local continuous flow; trains are favored for distant bulk/large-scale transfer, robots for flexible short-range distribution with real network and energy. A doctrinal preference cannot override already-present transport infrastructure or missing physical robot/rail capability.
3. [Factorio Wiki — Belt transport](https://wiki.factorio.com/Transport_network). Every ordinary belt has two lanes; turns and side-loading affect lanes and effective consumption. Throughput is constrained by native belt speed, inserters, congestion and stacking. A theoretical lane-count number is not an item-transfer receipt.
4. [Factorio Wiki — Inserters](https://wiki.factorio.com/Inserters). True pickup/drop geometry, arm motion and stack bonuses affect item intake. Direct insertion can eliminate a complete belt section, but must be observed on actual source and sink entities.
5. [Factorio Wiki — Belt physics](https://wiki.factorio.com/Transport_belts/Physics) and [official LuaEntityPrototype reference](https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html). The read-only unstacked capacity estimate for a straight prototype belt is `belt_speed × 480 × 60` items/minute. This is a *planning lower-tier baseline*, not a claimed modded belt-stack or end-to-end throughput. The online Lua docs may default to 2.1; execution and compatibility must still be checked under pinned Factorio 2.0.77.
6. [Factorio Wiki — transport belt capacity](https://wiki.factorio.com/Transport_belt_capacity_(research)). Space Age stack inserters and stacking research change limits: do not treat unstacked baseline as hard maximum in enabled expansions, and do not assume stack upgrades or quality exist when they are absent.

## Competing preferences, using the repository's **actual** 14 camps

| Existing doctrine | Preferred future topology | Benefit / risk | Implementation stage |
| --- | --- | --- | --- |
| Main Bus Orthodoxy `main_bus` | Reusable parallel ingredient trunks with consistent branch taps | Predictability, capacity allocation and future growth; space and belt-buffer cost | P2 shared ingredient evidence + reserved corridors |
| Sushi Belt Mysticism `sushi` | Mixed-item circulation with filter/injection/withdrawal control | Dense multiple ingredients; starvation/deadlock and contamination risk | P4 only with measured circuits and conservation |
| Mixed Spaghetti Pragmatica `mixed_spaghetti` | Shortest legal, obstacle-aware localized routes | Rapid compact bootstrap; costly future modification | P1 native directed-route tie-breaking |
| City Block Administratum `city_block` | Repeatable bounded manufacturing blocks | Expansion and district ownership; rail/robot interface and zoning overhead | P3 after native connection proof |
| Rail Megabase Logis `rail_megabase` | Buffered rail station interfaces plus local belts | Excellent remote bulk logistics; trains, stops, signals, fuel and capacity must be real | P3 |
| Logistic Bot Reliquary `bot_mall` | Powered provider/requester cells, belts for bulk | Flexible high-part-count mall; power/robot cost and crowded networks | P3 |
| Direct Insertion Conservatory `direct_insertion` | Adjacent machine output → input by real inserter | Minimal belts, low buffering and compactness; constrained orientation/recipe ratios | P1, actual port geometry required |
| Beaconed Module Ascendancy `beaconed_modules` | Repeated high-output machine rows with full-speed insertion | Machine density and throughput; modules, beacons and electricity can dominate | P3 |
| Balancer Geometry Scholam `belt_balancer` | Ratio-correct splitters and lane-balanced trunks | Predictable parallel feed; unnecessary splitter complexity if flow doesn't need it | P3 |
| Bootstrap Survival Rite `rush_bootstrap` | First viable short local machine-and-belt chain | Low early cost; must eventually resolve throughput and expansion deficits | P1 |
| Distributed Shrine Network `distributed_mini_factories` | Small production pods with explicit shared buffers | Resilience and locality; duplicate facilities and transfer costs | P2 |
| Circuit Oracle Covenant `circuit_control` | Native circuit-limited insertion and throughput control | Strong flow shaping; wiring/filter failure creates starvation | P4 |
| Quality Reliquary Sorting Rite `quality_sorting` | Per-quality filtered routes, reclaim/recycle loops | Controlled quality handling; extra footprint, filtered stock, potential feedback loops | P4 with quality actually enabled |
| Void Platform Axiomata `space_platform` | Compact platform-only resource and item loops | Tight off-world survival; special surface and asteroid native mechanics | P4 on actual Space Age surface |

## Engineering integration now implemented

- `factory_doctrine_organization_1268.lua` holds all fourteen **advisory** profiles. Missing key uses a neutral engine-native style; unknown named key is rejected instead of silently defaulting to Main Bus. Each policy declares future requirements and its currently active scope **native-legal-local-tie-break-only**.
- `arterial_planner.organize_material_plan(pair, plan, explicit_doctrine)` calls the planning-only 1268 analyzer. It aggregates recipe *batch* ingredients, identifies repeated-item consumers and **possible** bus trunks. A repeated ingredient is not proof of a required full bus or of real throughput. Fluids remain delegated to native fluid planning.
- `belt_route_preflight_1267.plan` now uses a doctrine preference only to rank native-placeable local route choices. Every candidate must still pass actual Factorio direction/placement checks. A route neither reserves corridor tiles nor becomes real cargo.
- The same preflight reports native unstacked straight-belt capacity, `provisional_belts` for the requested `rate_per_min`, and an explicit unknown-capacity reason where prototype speed cannot be observed. Inserter throughput and stacking are not inferred.
- This iteration deliberately does **not** create ghost blueprints, preempt 0338, acquire 0601 reservations, or automatically rewrite a player's factory. In particular, a "sushi" or "city_block" profile does not authorize building those advanced shapes.

## Common objective function for future physical layouts

**Hard constraints — never relax them for doctrine:** correct force/surface/station authority; physically installed source and sink; correct recipe ingredient and quality; native exact placement/orientation; native inserter pickup/drop; unobstructed known belts; verified power/fuel/fluids; original 0338 item custody and worker work reservations; no existing factory demolition or buffer appropriation. Any unknown is a blocker.

**Soft objectives — vary by doctrine only after hard constraints:** fewer tiles and inserters; fewer turns; future expansion reserves; proximity of related recipes; lane isolation; reduced buffered material; observed consumer starvation; power and rail/robot handoff costs; repairability and existing infrastructure reuse; science throughput and total production.

Plan evaluation must compare **two or more candidate arrangements** using one set of real native preflight checks, then choose the best *feasible* candidate under the selected explicit policy. The current 1268 tie-break preference is a small verified first step, not yet this comprehensive optimizer.

## Next development / evidence gates

1. **P1a inserter placement:** detect real source drop and consumer pickup using installed entity fields or native prototype geometry; rotate/place *candidate* inserters with native checks. Do not assume vanilla one-tile arm reach for custom/modded inserters. Preserve source-to-sink correct direction.
2. **P1b physical construction:** immutable, owned belt/inserter requests through 0601 + 0510 + 0338; original item stock must be present or produced via existing recipe planners, carried and debited, never spawned. Save/reload keeps reservations/custody.
3. **P1c transport verification:** true installed route continuity, belt lines, native source transfer, countable consumer intake and sustained motion. A belt item observed at rest is NOT equivalent to delivered ore.
4. **P2 factory graph and doctrine comparison:** two or more consuming recipes share an actual iron/copper intermediate; compare Main Bus vs local pod vs direct insertion vs pragmatic routing, with native space and actual SPM supply, then select an explicitly approved style.
5. **P3–P4:** proper splitters, undergrounds, lane priorities, circuit/filter loops, quality and Space Age, rail/robot boundary dispatch once those systems have native proof.

**Acceptance:** identical physically stocked midgame native Factorio 2.0.77 scenarios across distinct policies; report materials consumed, total belt/inserter counts, native machine input/output, actual production, lab consumption and sustained 5 SPM; verify interrupted saves and recovery. Source/unit PASS means only preflight and organization logic passed, not physical factory success.

