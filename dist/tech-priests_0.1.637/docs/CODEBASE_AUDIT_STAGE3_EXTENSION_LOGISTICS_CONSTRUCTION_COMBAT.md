# Stage 3 Extension — Logistics, Machine Logistics, Construction, Combat, and Direct Commands

This document extends the Stage 3 behavior authority map for the requested next targets:

1. logistics and machine-logistics authority modules,
2. construction ownership/contracts,
3. ordinary combat ownership,
4. direct `set_command` ownership outside the movement controller,
5. the `emergency` work queue / reservation category mismatch.

This is documentation/tooling only. No runtime behavior has been changed by this note.

## Plain-English result

The newly inspected families mostly confirm the current doctrine:

```text
Dispatcher owns priority/routing for migrated families.
Executors and contracts perform leaf behavior.
Legacy fragments remain helper/fallback surfaces unless wrapped or suppressed.
Movement Controller is the intended movement command owner.
```

Logistics and machine logistics are dispatcher-priority wrappers, not free-running controllers. Construction is partially dispatcher-wrapped through a contract layer but still uses the older construction planner as the leaf executor. Ordinary combat is still legacy/proxy-turret controlled and wrapped by combat safety/staging modules rather than fully migrated into a dispatcher executor.

## Logistics / known-source fetch

File: `scripts/core/logistics_fetch_executor_0527.lua`

Classification: dispatcher-priority logistics fetch executor.

Purpose:

- If the scheduler/dispatcher wants an item and the station catalog already knows a source, the priest physically fetches it before raw mining, primitive fallback, or emergency crafting.
- Sources include known containers, machine inventories, vehicle trunks, corpse inventories, and loose ground stacks.
- The item is credited to station inventory only after the priest walks to the source and withdraws it.

Ownership shape:

- Patches `single_dispatcher_0510.service_pair` as a high-priority wrapper.
- If it acts, it records `pair.dispatcher_0510.action = "logistics-fetch"` and `family = "logistics"`.
- If it cannot act, it falls through to the previous dispatcher service.
- Requests movement through `tech_priests_request_movement_0418` rather than directly commanding the priest.

Disposition: dispatcher-priority executor/leaf behavior, not independent free-running controller.

Stage 5 concerns:

- Fetch source becomes invalid/empty while movement is in progress.
- Partial withdrawal/deposit rollback when station insertion fails.
- `pair.logistic_requested_item` is cleared after successful insert, but related active order completion interaction should be checked.

## Machine logistics fulfillment

File: `scripts/core/logistics_machine_fulfillment_0528.lua`

Classification: dispatcher-priority machine logistics executor/wrapper.

Purpose:

- Services non-automated local assemblers/furnaces by clearing outputs, routing detritus/waste, supplying fuel, and supplying item ingredients from station-known stock.
- If a needed item exists elsewhere in the catalog, it expresses that need so `logistics_fetch_executor_0527` can physically fetch it before raw acquisition.

Ownership shape:

- Describes itself as dispatcher-owned and not a new free-running controller.
- Acts as a high-priority dispatcher wrapper before raw acquisition/emergency crafting.
- Sets `pair.machine_logistics_0528` phases such as:
  - `waiting-known-source-fetch`,
  - `move-to-machine`,
  - `move-to-storage`,
  - `complete`.
- Requests movement through `tech_priests_request_movement_0418`.
- Uses known-source fetch handoff for missing fuel/ingredients.

Disposition: dispatcher-priority machine logistics executor/leaf behavior.

Stage 5 concerns:

- `waiting-known-source-fetch` can become stranded if the fetch never produces the requested item.
- `move-to-storage` can become stranded if the chosen retention/waste box disappears or becomes full.
- Output clearing should be checked for partial transfers and carried-item cleanup.

## Logistics / construction physical-access contract

File: `scripts/core/logistics_construction_contract_0519.lua`

Classification: logistics/construction contract and dispatcher construction wrapper.

Purpose:

- Supplies from ground stacks or remote inventories must be physically fetched before being deposited into the station inventory.
- Construction/expansion planning may not project unreachable fantasy work.
- A build can be placed from station-known inventory, or deferred until the required item is unlocked/producible/available.

Ownership shape:

- Wraps scavenge/ground stockpile withdrawal to require physical source access first.
- Wraps older construction planner service calls.
- Suppresses independent construction pulses unless the call is dispatcher/manual/command-authorized.
- Patches `single_dispatcher_0510.service_pair` so construction can become a dispatcher family when `M.has_constructible_pair(pair)` is true.
- Still calls the older `TECH_PRIESTS_CONSTRUCTION_PLANNER_0359.service_pair` as the actual leaf.

Disposition: construction is dispatcher-wrapped but not fully migrated into a standalone modern executor. It remains mixed: dispatcher-priority contract plus legacy construction planner leaf.

Stage 5 concerns:

- `moving-to-construction-source` can strand if source disappears.
- `deferred-missing-station-item` can strand if retry/producibility never changes.
- Created ghosts should be reconciled with construction task completion/cancel paths.

## Ordinary combat ownership

Relevant files inspected:

- `scripts/core/behavior_mutex_0466.lua`
- `scripts/core/combat_magos_movement_authority_0472.lua`
- `scripts/core/combat_repair_doctrine_0517.lua`

Classification: ordinary combat remains legacy/proxy-turret controlled and wrapped/staged, not fully dispatcher-executor migrated.

Current shape:

- `behavior_mutex_0466.lua` makes combat top of the activity stack and pauses acquisition while hostile combat is active.
- It wraps old scan/laser/desperation craft/fallback combat functions to suppress acquisition while combat owns the pair.
- `combat_magos_movement_authority_0472.lua` stages proxy-turret sustain, point-blank combat throttling, and Magos subordinate-area authority.
- It routes visible attack commands away from the visible priest AI and into the hidden proxy/movement controller model.
- `combat_repair_doctrine_0517.lua` is dispatcher-owned, but only for the special wall/gate-under-fire repair case.

Disposition: ordinary combat remains mixed/legacy-controlled with safety wrappers. Do not migrate or timing-edit casually.

Stage 4/5 concerns:

- Proxy entity lifecycle, teleport/sustain, and target fields must be audited.
- Combat target invalidation must be checked against `pair.target`, `pair.combat_target`, proxy shooting target, and mode state.
- Combat can clear acquisition surfaces; order queue resume behavior must be verified.

## Direct `set_command` / movement command audit

Repository search did not reliably return known `set_command` hits even though `movement_controller.lua` contains them. A local scanner has been added:

```text
tools/audit_direct_command_ownership.py
```

Run locally:

```bash
python tools/audit_direct_command_ownership.py
python tools/update_github_manifest.py
```

Expected outputs:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE3_DIRECT_COMMAND_REPORT.md
tech-priests_src/docs/CODEBASE_AUDIT_STAGE3_DIRECT_COMMAND_REPORT.json
```

Preliminary source-read classification:

- `movement_controller.lua` is the canonical direct movement command owner.
- `behavior_contracts_0479.lua` contains a direct `set_command` fallback when `tech_priests_request_movement_0418` is unavailable.
- `action_state_arbiter_0488.lua` contains a similar movement-request-then-direct-command fallback.
- `combat_magos_movement_authority_0472.lua` wraps `issue_priest_command` for attack commands and routes visible attack ownership into the proxy/movement model.

Disposition: direct command inventory requires local scanner output before any code change.

## Emergency reservation category mismatch

Observed mismatch:

```text
work_queue_authority categories:
  repair, sanctify, resource, construction, pickup, emergency, combat

work_reservations categories:
  repair, sanctify, resource, construction, pickup, combat
```

Current reachability evidence:

- `event_driven_work_feeder_0608.lua` submits `repair`, `construction`, `sanctify`, and `pickup` work.
- Inspected logistics/machine-logistics paths express item needs through active pair fields and dispatcher wrappers rather than obvious `work_queue_authority.submit("emergency", ...)` calls.
- Search did not prove a direct `claim_nearest(..., "emergency")` path, but repository search has been unreliable and should not be treated as exhaustive.

Technical interpretation:

- `work_reservations.claim(category, ...)` dynamically creates category buckets, so an `emergency` claim would probably work at creation time.
- However, reservation root initialization and cleanup/reporting rotate only through declared `M.categories`.
- Therefore an `emergency` reservation, if reachable, may be underreported or not cleaned during category-rotated cleanup.

Decision:

Do not patch yet solely from static suspicion. Classify as probable small repair candidate pending scanner/search confirmation.

Safe repair shape if confirmed reachable:

```lua
M.categories = { "repair", "sanctify", "resource", "construction", "pickup", "emergency", "combat" }
```

This would align reservation categories with work queue categories and likely be low risk, but should be committed only after confirming whether `emergency` reservations are actually created or claimed.

## Updated Stage 3 ownership matrix additions

| Behavior family | Current owner classification | Primary owner / path | Notes |
|---|---|---|---|
| Known-source logistics fetch | Dispatcher-priority executor | `logistics_fetch_executor_0527.lua` wrapper around `single_dispatcher_0510.service_pair` | Physically fetches known item sources before raw acquisition/emergency craft. |
| Machine logistics fulfillment | Dispatcher-priority executor | `logistics_machine_fulfillment_0528.lua` wrapper around dispatcher | Services unautomated local machines; hands missing item needs to known-source fetch. |
| Construction | Mixed dispatcher-wrapped legacy leaf | `logistics_construction_contract_0519.lua` + `TECH_PRIESTS_CONSTRUCTION_PLANNER_0359` | Contract suppresses independent pulses and routes construction through dispatcher, but leaf remains older planner. |
| Ordinary combat | Legacy/proxy-turret controlled with wrappers | `behavior_mutex_0466.lua`, `combat_magos_movement_authority_0472.lua`, legacy combat functions | Combat repair is dispatcher-owned, ordinary combat is not fully migrated. |
| Direct movement commands | Movement-controller owned, with fallback review | `movement_controller.lua`; fallbacks in contracts/arbiters | Local direct-command scanner added for authoritative inventory. |

## Immediate next actions

1. Run `tools/audit_direct_command_ownership.py` locally and push the generated report.
2. Run a targeted local grep/search for `submit("emergency"`, `claim_nearest(... emergency`, `claim("emergency"`, and `category = "emergency"` if the scanner does not cover this.
3. If emergency reservations are reachable, prepare a tiny category-alignment patch for `work_reservations.lua`.
4. Continue Stage 3 into ordinary combat/proxy lifecycle only as audit, not code migration.
5. Keep Stage 4 blocked until direct command and lifecycle/destruction inventories exist.
