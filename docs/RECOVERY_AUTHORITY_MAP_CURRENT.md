# Current Recovery Authority Map

**Source lane:** `0.1.674-dev`  
**Protected packaged baseline:** `0.1.672`  
**Runtime evidence:** Not yet accepted  
**Declarative graph:** **32 declarative active hardeners** and **23 retired source-only authorities**.

The diagrams below describe source ownership. They do not claim successful GitHub Actions, Factorio loading, migration, save/reload, behavioral validation, profiling, packaging, or release.

## Canonical Loader and Runtime Spine

```mermaid
flowchart TD
    Control[control.lua] --> Registry[runtime_event_registry]
    Registry --> Broker[runtime_tick_broker central-pulse]
    Broker --> Planning[planning_constraints_0646]
    Planning --> Prearm[32 active hardeners]
    Planning --> Retired[23 retired authorities]
    Broker --> Dispatcher[single_dispatcher_0510]
    Dispatcher --> Action[canonical_action_0744]
    Arbiter[action_state_arbiter_0488 pure classifier] --> Dispatcher
    Finalizer[hardener_installation_audit_0723] --> Planning
```

The registry is the sole event-composition authority. The broker owns the single central cadence. Hardener installation requires literal `true`; failed families are degraded rather than silently treated as installed.

## Construction Placement and Physical Execution

```mermaid
flowchart LR
    Placement[construction_site_planner read-only effectiveness] --> Candidate[construction_candidate_0338]
    Requests[explicit construction requests] --> Candidate
    Candidate --> Arbiter[action_state_arbiter_0488]
    Arbiter --> Dispatcher[single_dispatcher_0510]
    Dispatcher --> Executor[construction_planner sole physical owner]
    Executor --> Move[literal-true movement]
    Executor --> Custody[construction_custody_0338]
    Executor --> Revalidate[exact coordinate revalidation]
    Revalidate --> Build[entity creation or ghost revival]
    Custody --> Return[source return then physical station return]
```

Defensive placement effectiveness belongs to `construction_site_planner.lua`. It scores perimeter position, threat alignment, spacing, support, power, coverage, and role-specific usefulness for walls, turrets, artillery, radar, mines, and roboports. `construction_planner.lua` alone moves the priest, removes the placeable item, retains custody, revalidates the chosen site and direction, and builds the entity.

## Repair, Acquisition, and Production Transactions

```mermaid
flowchart LR
    Queue[order_queue_0469] --> Dispatcher
    Dispatcher --> Acquisition[direct_acquisition_executor_0513]
    Acquisition --> AcquisitionCustody[direct acquisition custody]
    AcquisitionCustody --> Production[emergency_production_executor_0514]
    Production --> Output[output-deposited custody]
    Output --> Queue
    Dispatcher --> Repair[repair_executor_0516]
    Repair --> RepairCustody[repair_pack_custody_0516]
    Combat[combat_repair_doctrine_0517 tactical only] --> Repair
```

Terminal queue mutation remains scheduler-owned. Physical item removal is always paired with persistent custody and exact return or deposit handling.

## Consolidated Specialized Logistics

```mermaid
flowchart TD
    Machine[machine discovery 0528] --> Arbiter
    Item[item discovery 0702] --> Arbiter
    Energy[energy readiness 0705 and discovery 0707] --> Arbiter
    Silo[silo readiness 0709 and discovery 0710] --> Arbiter
    Artillery[artillery readiness 0712 and discovery 0713] --> Arbiter
    Roboport[roboport readiness 0714 and discovery 0715] --> Arbiter
    Arbiter --> Dispatcher
    Dispatcher --> MachineExec[machine physical execution 0528]
    Dispatcher --> ItemExec[item physical execution 0702]
    Dispatcher --> EnergyExec[energy physical execution 0707]
    Dispatcher --> SiloExec[silo physical execution 0710]
    Dispatcher --> ArtilleryExec[artillery physical execution 0713]
    Dispatcher --> RoboportExec[roboport repair-pack execution 0715]
```

Readiness and discovery broker services do not execute physical work. The classifier is read-only. The dispatcher is the sole caller of each physical executor. Roboport placement remains a construction concern; `0714/0715` inspect and service existing roboports only.

## Fluid-Turret Authority

```mermaid
flowchart LR
    Readiness[0716 corrected read-only readiness] --> Proposal[0717 exact safe proposals]
    Proposal --> Route[0719 wrapper-free route planner]
    Route --> Request[identified construction_request]
    Request --> Construction[construction_planner]
    Construction --> Ledger[construction_last_task_0338]
    Ledger --> Route
    Route --> Connected[verified turret connection]
```

`fluid_turret_readiness_0716` owns accepted attack-fluid, pipeline, contamination, and corrected internal-buffer interpretation. `fluid_turret_connection_proposals_0717` owns exact source segment and free-port identity. `fluid_turret_connection_planner_0719` owns route search, route reservations, request identity, retries, and completion. It publishes `fluid_turret_route_discovery_0719` and ordinary fixed-position construction requests; it never wraps construction, moves priests, carries pipe items, or places pipes.

The retired fluid-turret wrappers are:

- `fluid_turret_internal_buffer_guard_0731`
- `fluid_turret_proposal_integrity_0718`
- `fluid_turret_planner_integrity_0730`

Their useful rules are consolidated into `0716`, `0717`, and `0719` respectively.

## Storage and Transfer Boundaries

```mermaid
flowchart LR
    Containers[station chest and generic containers] --> Storage[storage_role_authority_0686]
    PriestCargo[inventory_transfer_integrity_0687] --> TransferCustody[inventory_transfer_custody_0687]
    TransferCustody --> Storage
    MachineSlots[assembler furnace lab and fuel slots] -. excluded from generic storage .-> Storage
```

Generic storage cannot use machine work inventories. Machine-specific executors may access only the exact target inventory required by their family.

## Retired Authority Boundary

Twenty-three files remain source-preserved but cannot install. They include the direct movement and mutable-leaf chain, remote salvage, construction placement wrapper, repair wrappers, machine wrappers, item integrity wrapper, energy wrappers, silo live-ownership wrapper, artillery train-validity wrapper, and the three fluid-turret wrappers listed above.

A retired authority may be read for historical context, but reintroducing its installer, service, direct event route, command ownership, physical mutation, or wrapper hook is a source-validation failure.

## Stage 5 — Evidence and Release Boundary

Source consolidation is not runtime proof. The remaining objective gates are:

1. One successful complete `Source validation` workflow for the exact tested SHA.
2. New-save and protected `0.1.672` migration loads in Factorio 2.x.
3. Configuration-change and save/reload runs for new and migrated saves.
4. The full behavioral scenario matrix, including construction effectiveness and fluid turret route recovery.
5. Idle, active, and high-count profiler evidence.
6. Digest-bound evidence validation and reviewed release authorization.
7. Qualified version advancement, deterministic packaging, and packaged-load testing.

Until those gates are accepted, `tech-priests_src/info.json` remains `0.1.672`, no package is verified, and no release is authorized.
