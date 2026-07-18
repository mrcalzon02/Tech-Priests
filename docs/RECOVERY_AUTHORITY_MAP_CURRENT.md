# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-17

## Purpose

This map connects the detailed 0659–0675 Mermaid/function drilldowns to the later 0680–0739 authority families, current Void movement recovery, and active base-state repairs. It distinguishes four states that must never be conflated:

```mermaid
flowchart LR
    Present[Present in source]
    Installed[Installed or wrapped]
    Authoritative[Owns live behavior]
    Proven[Runtime and save-load proven]
    Present --> Installed --> Authoritative --> Proven
```

## Current Loader and Hardener Shape

```mermaid
flowchart TD
    Control[control.lua]
    Legacy[22 generated legacy fragments]
    Registry[runtime_event_registry]
    Broker[runtime_tick_broker]
    Constraints[planning_constraints_0646]
    Hardener[late hardener and specialized-family chain 0649-0739]
    Queue[work queue + reservations + order queue]
    Dispatcher[single_dispatcher_0510]
    Arbiter[action_state_arbiter_0488]
    Executors[family executors]
    Leaf[active leaf / movement intent / visual truth]
    Movement[movement controller + bounds + corridor + Void]
    Reports[read-only diagnostics and lifecycle audits]

    Control --> Legacy
    Control --> Registry
    Control --> Broker
    Control --> Constraints --> Hardener
    Control --> Queue --> Dispatcher --> Executors --> Leaf --> Movement
    Arbiter --> Dispatcher
    Registry --> Reports
    Broker --> Reports
    Hardener -. wraps .-> Queue
    Hardener -. wraps .-> Dispatcher
    Hardener -. wraps .-> Executors
    Hardener -. wraps .-> Movement
    Legacy -. compatibility writes .-> Dispatcher
    Legacy -. compatibility writes .-> Movement
```

Recovery must correct, replace, or demote existing owners rather than add another outer ring.

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

### Emergency production and order queue

```mermaid
sequenceDiagram
    participant Caller
    participant Q as Order Queue 0469
    participant D as Dispatcher 0510
    participant E as Emergency Production 0514
    participant S as Storage Authority 0686

    Caller->>Q: submit target-aware order
    alt capacity exists
        Q-->>Caller: active / queued / duplicate-merged
    else full
        Q-->>Caller: rejected queue-full
    end
    Q->>D: current intent
    D->>E: service production
    E->>E: require strict recipe metadata
    E->>E: plan all ingredient removals
    E->>E: remove exact ingredients
    alt removal fails
        E->>E: rollback exact removals
        E->>E: persist rollback custody on shortfall
    else succeeds
        E->>E: persist output-held custody
        E->>S: atomic exact deposit
        alt blocked
            S-->>E: rejected; custody retained
        else deposited
            E->>Q: complete current
            Q->>Q: terminal history and immediate promotion
        end
    end
```

### Consecration lifecycle

```mermaid
sequenceDiagram
    participant C as Consecration 0515
    participant Q as Order Queue 0469
    participant M as Movement 0418
    participant I as Consecration Item Source
    participant S as Storage Authority 0686

    C->>Q: submit or adopt target-aware consecration order
    Q-->>C: active / queued / duplicate / rejected
    C->>C: claim target by stored physical key
    C->>M: canonical movement request
    alt movement rejected or target invalid
        C->>C: release claim and clear timers
        C->>Q: fail current and promote
    else in range
        C->>C: run target/item-specific rite timer
        C->>I: consume exact capsule
        C->>C: apply through source-context authority
        alt apply fails
            C->>S: atomic exact refund
            alt refund blocked
                C->>C: persist refund custody
            else refunded
                C->>Q: fail current and promote
            end
        else succeeds
            C->>C: release claim and clear target/timers
            C->>Q: complete current and promote
        end
    end
```

### Stage 1 invariants represented in source

- Full queues reject truthfully.
- Order identity includes pair, surface, family, item, purpose/role, and physical target when available.
- Duplicates refresh mutable metadata.
- Preemption cannot discard the interrupted order.
- Invalid physical targets fail.
- Terminal transitions immediately promote or exhaust the queue.
- Initial callbacks are caller-owned; promoted callbacks execute once.
- Emergency fallback requires strict ingredients, planned removal, rollback, custody, and atomic deposit.
- Facility output collection excludes assembling-machine input inventories.
- Consecration cooldown happens before target acquisition and cannot retain a claim.
- Claims can be released by stored key after the entity becomes invalid.
- Consecration movement accepts only a truthful canonical movement result.
- Target/item changes and terminal failures clear rite timers.
- Failed application refunds atomically or persists exact refund custody.
- Consecration queue and scheduler admission is verified rather than assumed.

## Specialized Runtime Families Added After the Older Mermaid Series

```mermaid
flowchart LR
    Machine[Machine logistics 0682-0684]
    Storage[Storage roles / transfer 0686-0687]
    Fluid[Fluid network and route planning 0689-0700]
    Item[Item-family logistics 0702-0703]
    Energy[Energy readiness/logistics 0705-0707 / 0722 / 0726-0727]
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
    Lifecycle -. audits .-> Machine
    Lifecycle -. audits .-> Fluid
    Lifecycle -. audits .-> Energy
```

These families remain runtime-unproven until Stage 5 evidence exists.

## Movement Ownership During Recovery

```mermaid
flowchart TD
    Leaf[active leaf truth 0655]
    Intent[movement intent / reconciler / vector 0651-0654]
    Request[canonical movement request 0418]
    Controller[movement_controller]
    Bounds[movement_bounds_contract_0511]
    Enforcement[movement_enforcement_0566]
    Economy[unobserved transit 0572]
    Corridor[authority corridor 0574]
    Void[void_movement_authority_0630]
    Visual[visual intent 0657]

    Leaf --> Intent --> Request --> Controller --> Bounds --> Enforcement --> Economy --> Corridor --> Void
    Intent --> Visual
```

Void Stage 1 removes ground-leash ownership while preserving corridor authorization. Collision recovery, proxy synchronization, elapsed-time stepping, fairness, serialization, and executor recovery remain open.

## Remaining Recovery Defect Fronts

```mermaid
flowchart TD
    Direct[Stage 1 direct-acquisition integrity]
    S2[Stage 2 shared runtime spine]
    Registry[Owner-keyed event registration and filter composition]
    Install[Phased fail-closed hardener installation]
    Broker[Strict broker result schema]
    S3[Stage 3 authority consolidation]
    Pure[Pure classifier]
    Action[Canonical action record]
    Demote[Legacy and wrapper demotion]
    S4[Stage 4 UPS reduction]
    S5[Stage 5 runtime evidence]
    S6[Stage 6 artifact doctrine]

    Direct --> S2 --> Registry --> Install --> Broker --> S3 --> Pure --> Action --> Demote --> S4 --> S5 --> S6
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

    Standards --> Recovery --> CurrentMap
    Recovery --> Testing
    Continuity --> CurrentMap
    OldMaps --> CurrentMap
    CurrentMap --> Checker --> CI --> History
```

## Evidence Status

- Emergency production, order queue, and consecration repairs are source-implemented on `main`.
- The three replacement Lua modules were parsed locally with a Lua grammar parser before publication.
- No recorded successful Lua 5.2 workflow result exists for the current recovery head.
- No Factorio load, migration, save/reload, behavioral, or performance evidence is claimed.
- Experimental `0.1.674` prerelease artifacts remain distinct from a verified release candidate.
