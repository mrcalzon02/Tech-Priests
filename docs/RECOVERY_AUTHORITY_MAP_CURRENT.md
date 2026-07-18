# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-17

## Purpose

This map supersedes the older Mermaid series only for the current recovery milestone. The earlier function drilldowns remain detailed historical evidence for the 0659–0675 stack. This document connects that stack to the later 0680–0739 authority families, the current Void movement repair, and the first base-state transaction and scheduler repairs.

It distinguishes four states that must never be conflated:

```mermaid
flowchart LR
    Present[Present in source]
    Installed[Installed or wrapped]
    Authoritative[Owns live behavior]
    Proven[Runtime and save-load proven]
    Present --> Installed --> Authoritative --> Proven
```

A module may be present without installing, installed without winning the wrapper chain, or authoritative without runtime proof.

## Current Loader and Hardener Shape

```mermaid
flowchart TD
    Control[control.lua]
    Legacy[22 generated legacy fragments]
    Registry[runtime_event_registry]
    Broker[runtime_tick_broker]
    Constraints[planning_constraints_0646]
    Hardener[late hardener and specialized-family chain 0649-0739]
    Queue[work_queue + reservations + order_queue_0469]
    Dispatcher[single_dispatcher_0510]
    Arbiter[action_state_arbiter_0488]
    Executors[family executors]
    Leaf[active leaf / movement intent / visual truth]
    Movement[movement controller + bounds + corridor + Void authority]
    Reports[read-only diagnostics and lifecycle audits]

    Control --> Legacy
    Control --> Registry
    Control --> Broker
    Control --> Constraints
    Constraints --> Hardener
    Control --> Queue
    Queue --> Dispatcher
    Arbiter --> Dispatcher
    Dispatcher --> Executors
    Executors --> Leaf
    Leaf --> Movement
    Registry --> Reports
    Broker --> Reports
    Hardener -. wraps and constrains .-> Queue
    Hardener -. wraps and constrains .-> Dispatcher
    Hardener -. wraps and constrains .-> Executors
    Hardener -. wraps and constrains .-> Movement
    Legacy -. compatibility writes remain .-> Dispatcher
    Legacy -. compatibility writes remain .-> Movement
```

The recovery target is not to add another outer ring. Each stage must correct, replace, or demote an existing owner until the dashed compatibility and hardener edges can be removed.

## Canonical Recovery Target

```mermaid
flowchart TD
    Event[World event or broker service]
    Discovery[Shared work discovery]
    Reservation[Reservation]
    Order[One per-pair order]
    Select[Pure action-family selection]
    Execute[One family executor]
    Move[One movement lease to one physical leaf target]
    Custody[Source removal and explicit custody]
    Deposit[Destination revalidation and exact insertion]
    Terminal[One terminal cleanup and immediate promotion]
    Observe[Read-only status visuals audio diagnostics]

    Event --> Discovery --> Reservation --> Order --> Select --> Execute --> Move --> Custody --> Deposit --> Terminal --> Observe
```

## Stage 1 Transaction and Scheduler Repair

```mermaid
sequenceDiagram
    participant Caller
    participant Q as Order Queue 0469
    participant D as Dispatcher 0510
    participant E as Emergency Production 0514
    participant S as Storage Authority 0686

    Caller->>Q: submit order
    alt queue has capacity
        Q-->>Caller: active / queued / duplicate-merged
    else queue full
        Q-->>Caller: rejected queue-full
    end
    Q->>D: current intent
    D->>E: service selected production family
    E->>E: require strict recipe metadata
    E->>E: plan all ingredient removals
    E->>E: remove exact ingredients
    alt any removal fails
        E->>E: rollback exact removals
        E->>E: persist rollback custody on shortfall
    else transaction succeeds
        E->>E: persist output-held custody
        E->>S: atomic exact deposit
        alt destination blocked
            S-->>E: rejected; custody retained
        else deposited
            S-->>E: complete exact count
            E->>Q: complete current order
            Q->>Q: terminal history and immediate promotion
        end
    end
```

### Stage 1 invariants now represented in source

- A full pending queue returns `queue-full`; it does not report a discarded order as queued.
- Order identity includes family, pair, surface, item, purpose or role, and physical target identity when available.
- Duplicate submissions refresh mutable order metadata.
- Preemption is refused when the interrupted order cannot be retained.
- Invalid physical targets fail rather than complete.
- Terminal transitions immediately promote or explicitly exhaust the queue.
- Initial submission callbacks are caller-owned and execute once; promoted orders execute their stored callback once.
- Timed emergency production requires strict ingredient metadata.
- Ingredient removals are planned before mutation and rolled back on partial failure.
- Any rollback shortfall or completed output remains in persistent custody.
- Facility collection excludes assembling-machine input inventories.
- Output is deposited only through the exact atomic storage authority.

## Specialized Runtime Families Added After the Older Mermaid Series

```mermaid
flowchart LR
    Machine[Machine logistics 0682-0684]
    Storage[Storage roles / transfer 0686-0687]
    Fluid[Fluid network and route planning 0689-0700]
    Item[Item-family logistics 0702-0703]
    Energy[Energy readiness and logistics 0705-0707 / 0722 / 0726-0727]
    Silo[Rocket silo 0709-0710 / 0728]
    Artillery[Artillery 0712-0713 / 0724]
    Roboport[Roboport 0714-0715]
    Turret[Fluid turret 0716-0719 / 0730-0731]
    Lifecycle[Command cleanup / integration / lifecycle / migration 0720-0738]

    Storage --> Machine
    Fluid --> Machine
    Item --> Storage
    Energy --> Storage
    Silo --> Storage
    Artillery --> Storage
    Roboport --> Storage
    Turret --> Fluid
    Lifecycle -. audits installation and state .-> Machine
    Lifecycle -. audits installation and state .-> Fluid
    Lifecycle -. audits installation and state .-> Energy
```

These families have strong source-level physical-custody doctrine but remain runtime-unproven until Stage 5 evidence exists.

## Movement Ownership During Recovery

```mermaid
flowchart TD
    Request[Canonical movement request 0418]
    Controller[movement_controller]
    Bounds[movement_bounds_contract_0511]
    Enforcement[movement_enforcement_0566]
    Economy[unobserved transit 0572]
    Corridor[authority corridor 0574]
    Void[void_movement_authority_0630]
    Intent[movement intent / reconciler / vector 0651-0654]
    Leaf[active leaf truth 0655]
    Visual[visual intent 0657]

    Leaf --> Intent --> Request --> Controller
    Controller --> Bounds --> Enforcement --> Economy --> Corridor
    Corridor --> Void
    Intent --> Visual
```

Void Stage 1 removes ground-leash ownership while preserving corridor authorization. Collision recovery, proxy synchronization, elapsed-time stepping, fairness, serialization, and executor recovery remain open under `docs/VOID_PRIEST_MOVEMENT_REPAIR_PLAN.md`.

## Remaining Recovery Defect Fronts

```mermaid
flowchart TD
    S1[Stage 1 physical and scheduler truth]
    Consecration[Consecration lifecycle]
    Direct[Direct acquisition integrity]
    S2[Stage 2 shared runtime spine]
    Registry[Owner-keyed event registration and filter composition]
    Install[Phased fail-closed hardener installation]
    Broker[Strict broker result schema]
    S3[Stage 3 authority consolidation]
    Pure[Pure classifier]
    Action[Canonical action record]
    Demote[Legacy and redundant wrapper demotion]
    S4[Stage 4 UPS reduction]
    S5[Stage 5 runtime evidence]
    S6[Stage 6 artifact doctrine]

    S1 --> Consecration --> Direct --> S2
    S2 --> Registry --> Install --> Broker --> S3
    S3 --> Pure --> Action --> Demote --> S4 --> S5 --> S6
```

## Documentation and Evidence Connections

```mermaid
flowchart LR
    Recovery[RECOVERY_REPAIR_SEQUENCE.md]
    Standards[docs/STANDARDS_AND_PRACTICES.md]
    History[docs/DEVELOPMENT_HISTORY.md]
    Testing[tech-priests_src/docs/CURRENT_TESTING_GOALS.md]
    Continuity[tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md]
    OldMaps[docs/BEHAVIOR_MERMAID_*]
    CurrentMap[docs/RECOVERY_AUTHORITY_MAP_CURRENT.md]
    Checker[tools/check_recovery_architecture_0744.py]
    CI[.github/workflows/source-validation.yml]

    Recovery --> CurrentMap
    Standards --> Recovery
    Recovery --> Testing
    Continuity --> CurrentMap
    OldMaps --> CurrentMap
    CurrentMap --> Checker --> CI
    CI --> History
```

## Evidence Status

- Emergency production and order-queue repairs are source-implemented on `main`.
- Both replacement Lua modules were parsed locally with a Lua grammar parser before publication.
- The project Lua 5.2 compiler workflow has not yet produced a recorded successful result for this recovery head.
- No Factorio load, migration, save/reload, behavioral, or performance evidence is claimed by this map.
- Experimental `0.1.674` prerelease artifacts remain distinct from a verified release candidate.
