# Tech Priests — Factorio-native engine authority

**Project engineering rule:** Factorio is the authority for what exists, can
be constructed, is connected, belongs to a force, is powered, can be reached,
and can be transferred. Tech Priests may **plan** using read-only native
prototypes and observed positions; they must never turn a planned candidate
into a claimed game state by geometric inference or custom simulation.

This rule applies to vanilla 2.0 and modded prototypes. Prefer existing engine
mechanics, native object methods, and safe read-only queries. New planners
coordinate and prioritize work **around** the engine; they do not replace it.

## A two-stage, testable contract

1. **Candidate stage:** Use genuine observed entities; actual entity bounds,
   prototype ranges/ports, registered recipes and items; available inventories;
   and the native surface placement or reach query. Candidate positions are
   proposals only. No electricity, fluid, inventory, research or network coverage
   is awarded for a theoretically valid site.
2. **Execution and proof stage:** The original authoritative worker or engine
   performs construction, travel, inventory removal/insertion, wiring, energy
   distribution, fluid transport, research or mining. A planner advances **only**
   after native state confirms completion. If the native state cannot be read,
   preserve the uncertainty and report a blocker rather than assume success.

## Per-subsystem authoritative checks

| Question | Engine authority | Forbidden shortcut |
| --- | --- | --- |
| Can this machine physically go here? | `LuaSurface.can_place_entity` with the original name, direction, force and position | A homegrown collision-only check or creating the entity to try it |
| Does a proposed pole's service area intersect the machine? | The actual `LuaEntity.bounding_box` and `LuaEntityPrototype.supply_area_distance`; placement still needs engine approval | Center-only distance, arbitrary fixed radius, or claiming this proves connection |
| Is an *installed* machine on the pole's electrical network? | `LuaEntity.electric_network_id` on both the real machine and the real pole, with equal nonzero IDs; `is_connected_to_electric_network()` distinguishes a native unconnected entity from a test double | Inferring connectivity from a visible pole, distance, or a construction request |
| Can poles conduct to each other? | Native `electric_network_id`, real wire connector/connection state, prototype `maximum_wire_distance` for *planning* | Treating a wire-reach guess as actual copper wiring |
| Is power delivered? | The game's entity electric energy/generator output and laboratory state | Crediting power for mere poles, boiler or steam engine placement |
| Are water and steam routed? | Genuine native fluidbox connection/segment IDs, filter and measured fluid contents | Declaring a pipe route connected solely because planned adjacent tiles touch |
| Is an item available and transferred? | Original storage-role inventory counts and actual engine item removal/insertion receipts | Synthetic fuel, material teleports or decrementing only a simulated ledger |
| Can a robot build there? | Existing powered Factorio logistic/construction network and real robots; native construction results | Bounding-circle proxy as confirmed robot coverage |
| Is a train journey possible/completed? | Actual trains, rails, stops, locomotive fuel and engine-observed travel/arrival | A straight-line range approximation or instant repositioning |
| Can research progress? | Native force technology/recipe unlocks, real selected research, physically fed powered labs, actual science consumption | Selecting research or crediting SPM based solely on a planner graph |

## Code-level enforcement

- `scripts/core/native_electric_authority_1263.lua` centralizes native
  electricity-network observation and footprint-aware candidate checks for
  `power_setup_1252.lua` and the laboratory pole planner in
  `infrastructure_first_governor_0640.lua`.
- `electric_network_id` takes precedence over geometry. A native machine with
  no observed network identity cannot be called connected just because a pole
  is near it. Pure Lua test fixtures without native methods can use
  geometry-only stubs to verify *candidate* logic, never power output.
- Existing worker `0338` remains the exclusive owner of physical machine/pole
  construction; machine fuel, pipes and energy retain their own original
  services. Do not bypass an incumbent work order or in-transit custody.
- Tests must include negative examples: same-position/wrong electric network;
  same prototype network but out of physical supply area; missing native
  network; blocked native placement; no inventory; and cold, installed
  generators that do not yet supply a powered lab.
- Actual Factorio engine checkpoints are required before claiming end-to-end
  power, robots, mining, train journeys or science-per-minute outcomes. Unit
  tests demonstrate only narrower source contracts.

## Sources and version discipline

Factorio 2.0 runtime and prototype definitions are the compatibility target.
Check engine documentation rather than assuming a newer API property exists
in the current validated Factorio version.

- https://lua-api.factorio.com/latest/classes/LuaEntity.html
- https://lua-api.factorio.com/latest/classes/LuaSurface.html
- https://lua-api.factorio.com/latest/prototypes/ElectricPolePrototype.html
- https://lua-api.factorio.com/latest/classes/LuaWireConnector.html

A failed or incomplete acceptance diagnostic must remain explicitly incomplete
in status reports; do not silently promote a source-only PASS to native proof.
