# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-17

## Purpose

This document connects the detailed 0659–0675 Mermaid drilldowns to the later 0680–0739 authority families and the current recovery source. It distinguishes four separate facts:

```mermaid
flowchart LR
    Present[Present in source]
    Installed[Installed or wrapped]
    Authoritative[Owns live behavior]
    Proven[Runtime save-load behavior and performance proven]
    Present --> Installed --> Authoritative --> Proven
```

Source implementation is not runtime proof.

## Current Loader and Hardener Shape

```mermaid
flowchart TD
    Control[control.lua]
    Legacy[22 generated legacy fragments]
    Registry[runtime_event_registry]
    Broker[runtime_tick_broker]
    Core[normal core installers]
    Prearm[planning_constraints_0646 prearm]
    Families[base and specialized family modules]
    FinalHook[task_auspex_0622 final normal installer]
    Finalize[planning_constraints finalize_installation]
    Complete{all required hardeners installed?}
    Enabled[families remain enabled]
    Degraded[classify failed hardener by family]
    Disable[disable affected family]
    Ledger[recovery_installation_0744 and diagnostics]

    Control --> Legacy
    Control --> Registry --> Broker --> Core
    Control --> Prearm
    Core --> Families --> FinalHook --> Finalize --> Complete
    Complete -- yes --> Enabled --> Ledger
    Complete -- no --> Degraded --> Disable --> Ledger
```

Early hardener failures are provisional. The final pass occurs after ordinary installers have loaded while event registration is still legal. A final failure may not leave the affected family running as though fully protected.

## Canonical Recovery Target

```mermaid
flowchart TD
    Event[Factorio event]
    Registry[owner and route keyed event registry]
    Broker[structured-result tick broker]
    Discovery[shared work discovery]
    Reservation[shared reservation]
    Queue[truthful per-pair order queue]
    Classifier[pure read-only action classifier]
    Dispatcher[single dispatcher and canonical_action_0744]
    Executor[one owned family executor]
    Movement[canonical movement request]
    Custody[physical removal and persistent custody]
    Deposit[atomic destination deposit]
    Terminal[one truthful terminal transition]
    Promotion[immediate queue promotion]
    Observe[read-only visual audio and diagnostics]

    Event --> Registry --> Discovery
    Broker --> Discovery
    Discovery --> Reservation --> Queue --> Classifier --> Dispatcher --> Executor
    Executor --> Movement --> Custody --> Deposit --> Terminal --> Promotion --> Queue
    Terminal --> Observe
```

Generated legacy fragments and remaining wrappers are compatibility surfaces beneath this target. They are not authorities to be expanded.

## Stage 1 Transaction and Scheduler Repair

### Emergency production and canonical completion

```mermaid
sequenceDiagram
    participant Q as Order Queue 0469
    participant D as Dispatcher 0510
    participant E as Emergency Production 0514
    participant S as Storage Authority 0686

    Q->>D: current production order
    D->>E: service exact task
    E->>E: require strict recipe metadata
    E->>E: plan complete ingredient removal
    E->>E: remove exact ingredients
    alt removal failure
        E->>E: rollback exact removals
        E->>E: persist return-ingredients custody on shortfall
    else removal success
        E->>E: persist output-held custody
        E->>S: atomic exact output deposit
        alt deposit blocked
            S-->>E: custody retained
        else output deposited
            E->>E: change custody to output-deposited
            E->>Q: request canonical completion
            alt completion rejected or unavailable
                Q-->>E: retain output-deposited custody and task
            else completion accepted
                E->>E: clear task and custody
                Q->>Q: record terminal state and promote immediately
            end
        end
    end
```

The `output-deposited` phase prevents output duplication when scheduler completion is temporarily blocked. Emergency production may not mutate queue internals directly and may not report a failed legacy service as success.

### Order queue truth

```mermaid
flowchart TD
    Submit[submit target-aware order]
    Capacity{capacity available?}
    Reject[return queue-full]
    Duplicate{same complete physical key?}
    Merge[refresh all mutable metadata]
    Priority{higher priority?}
    Pause[losslessly pause current]
    Activate[activate once]
    Pending[append pending]
    Terminal[complete fail or cancel]
    Promote[immediate fair promotion]
    Transition[canonical acquisition to production transition]
    ClearTask[explicitly clear obsolete task reference]

    Submit --> Capacity
    Capacity -- no --> Reject
    Capacity -- yes --> Duplicate
    Duplicate -- yes --> Merge
    Duplicate -- no --> Priority
    Priority -- yes --> Pause --> Activate
    Priority -- no --> Pending
    Activate --> Terminal --> Promote
    Pending --> Promote
    Activate --> Transition --> ClearTask
```

Full queues reject instead of dropping work. Physical target context participates in order identity. Invalid targets fail rather than complete. Initial and promoted callbacks each have exactly one owner.

### Consecration

```mermaid
sequenceDiagram
    participant C as Consecration 0515
    participant Q as Order Queue 0469
    participant M as Movement 0418
    participant S as Storage Authority 0686

    C->>Q: verified target-aware admission
    C->>C: claim by stored physical key
    C->>M: request canonical movement
    alt movement does not explicitly return true
        C->>C: release claim and clear timers
        C->>Q: fail and promote
    else at target
        C->>C: consume exact consecration item
        C->>C: apply with source context
        alt application fails
            C->>S: atomic exact refund
            alt refund blocked
                C->>C: persist refund custody
            else refunded
                C->>Q: fail and promote
            end
        else applied
            C->>C: release claim and clear terminal state
            C->>Q: complete and promote
        end
    end
```

Cooldown is evaluated before target selection. Target or item changes clear rite timers. A protected call is not movement success unless the authority explicitly returns `true`.

### Direct acquisition and production handoff

```mermaid
sequenceDiagram
    participant A as Direct Acquisition 0513
    participant B as Bounds 0511
    participant M as Movement 0418
    participant R as Physical target
    participant S as Storage Authority 0686
    participant Q as Order Queue 0469
    participant P as Emergency Production 0514

    A->>A: require explicit item and exact target identity
    A->>B: require explicit in-bounds result
    A->>M: require explicit movement acceptance
    A->>M: require explicit work-clamp acceptance
    A->>R: mutate only after completed extraction
    R-->>A: exact physical yield
    A->>A: persist carried custody
    A->>M: physically return to station
    A->>S: atomic exact deposit
    alt more units required
        A->>M: return to valid target or replan
    else recipe materials complete
        A->>Q: transition current order with clear_task=true
        A->>A: move task into p.emergency_craft and remove former field
        Q->>P: same parent intent continues in production
    else acquisition complete
        A->>Q: complete and promote
    end
```

Bounds, movement, and work-clamp authorities fail closed. A failed request is not counted as useful work.

## Stage 2 — Shared Runtime Spine

### Owner-keyed event routes

```mermaid
flowchart TD
    Register[register owner plus route]
    Upsert[replace same owner route identity]
    Sort[deterministic numeric priority]
    Dispatch[one Factorio event dispatcher]
    Filter[route-local filter evaluation]
    Call[protected handler call]
    Failed{handler failed?}
    Record[record isolated failure]
    Continue[continue later owners]
    Remove[remove one owner route]

    Register --> Upsert --> Sort --> Dispatch --> Filter --> Call --> Failed
    Failed -- yes --> Record --> Continue
    Failed -- no --> Continue
    Remove --> Sort
```

`first/front` and `last/final` are real priorities. Removing one owner no longer clears unrelated handlers.

### Structured broker truth

```mermaid
flowchart LR
    Service[service result]
    Normalize[processed acted blocked waiting failed exhausted]
    Metrics[truthful counters]
    Pressure[adaptive pressure uses confirmed signals]
    Cadence[replacement preserves next due tick]
    Service --> Normalize --> Metrics --> Pressure
    Normalize --> Cadence
```

Numeric zero, `nil`, waiting, and blocked results are not actions.

## Stage 3 — Canonical Behavioral Authority

```mermaid
flowchart TD
    Order[current order]
    Pure[pure action classifier]
    Record[canonical_action_0744]
    Dispatch[single dispatcher]
    Family{owned family}
    Direct[direct acquisition]
    Production[emergency production]
    Consecrate[consecration]
    Repair[repair]
    CombatRepair[combat repair]
    Compatibility[unmigrated specialized compatibility leaf]
    LegacyGate[gate matching parallel legacy work while nonterminal]

    Order --> Pure --> Record --> Dispatch --> Family
    Family --> Direct
    Family --> Production
    Family --> Consecrate
    Family --> Repair
    Family --> CombatRepair
    Family --> Compatibility
    Dispatch --> LegacyGate
```

The classifier owns no queue mutation, movement request, executor clearing, pair mode write, pair target write, or periodic service. The dispatcher publishes one serializable action record and counts only executor-confirmed actions.

## Stage 4 — Static UPS Recovery Gate

```mermaid
flowchart LR
    Source[current Lua tree]
    Audit[audit_ups_hotspots_0743]
    Routes[periodic and fast routes]
    Scans[risky scans]
    Commands[direct commands]
    Writes[pair mode and target writes]
    Compare[frozen pre-recovery baseline]
    Pass[no tracked metric regressed]
    Fail[source-validation failure]

    Source --> Audit
    Audit --> Routes --> Compare
    Audit --> Scans --> Compare
    Audit --> Commands --> Compare
    Audit --> Writes --> Compare
    Compare -- at or below --> Pass
    Compare -- above --> Fail
```

The frozen baseline is 510 periodic routes, 17 active routes at 30 ticks or faster, 68 risky scans, 916 rewrite sites, 72 direct command sites, 352 `pair.mode` writes, and 177 `pair.target` writes. This proves only that the static authority surface did not regress; it is not profiler evidence.

## Later Specialized Families

```mermaid
flowchart LR
    Machine[Machine logistics 0682-0684]
    Storage[Storage roles and transfer 0686-0687]
    Fluid[Fluid network and routing 0689-0700]
    Item[Item-family logistics 0702-0703]
    Energy[Energy readiness and logistics 0705-0707]
    Silo[Rocket silo 0709-0710]
    Artillery[Artillery 0712-0713]
    Roboport[Roboport 0714-0715]
    Turret[Fluid turret 0716-0719]
    Lifecycle[Command cleanup lifecycle and migration 0720-0738]

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

These families contain strong physical-custody source doctrine but remain runtime-unproven.

## Movement Ownership

```mermaid
flowchart TD
    Action[canonical action and active leaf]
    Intent[movement intent reconciler 0651-0654]
    Request[canonical movement request 0418]
    Controller[movement controller]
    Bounds[movement bounds 0511]
    Enforcement[movement enforcement 0566]
    Economy[unobserved transit 0572]
    Corridor[authority corridor 0574]
    Void[Void movement 0630]
    Visual[visual intent 0657]

    Action --> Intent --> Request --> Controller --> Bounds --> Enforcement --> Economy --> Corridor --> Void
    Intent --> Visual
```

Void movement still requires collision recovery, proxy synchronization, elapsed-time stepping, fair high-count service, save/load proof, and executor recovery tests.

## Remaining Recovery Defect Fronts

```mermaid
flowchart TD
    Source[Stages 0 through 4 source implementation]
    CI[successful full source-validation run]
    Load[clean new-save Factorio load]
    Upgrade[real 0.1.672 upgrade]
    Reload[save and reload both scenarios]
    Stage1[Stage 1 transaction and scheduler matrix]
    Spine[event broker hardener and canonical-action matrix]
    Families[specialized family and movement matrix]
    Profile[idle active and high-count profiler evidence]
    Evidence[accepted recovery evidence manifest]
    Authorization[verified release authorization]
    Package[qualified package and packaged-load repetition]

    Source --> CI --> Load --> Upgrade --> Reload --> Stage1 --> Spine --> Families --> Profile --> Evidence --> Authorization --> Package
```

The remaining defects are evidentiary and runtime-specific unless a validation run exposes new source failures. Another speculative outer wrapper is not an acceptable substitute.

## Documentation and Evidence Connections

```mermaid
flowchart LR
    Recovery[RECOVERY_REPAIR_SEQUENCE.md]
    Standards[STANDARDS_AND_PRACTICES.md]
    History[DEVELOPMENT_HISTORY.md]
    Testing[CURRENT_TESTING_GOALS.md]
    Runbook[RECOVERY_RUNTIME_EVIDENCE.md]
    Continuity[AUTHORITY_REFACTOR_CONTINUITY.md]
    OldMaps[BEHAVIOR_MERMAID series]
    CurrentMap[RECOVERY_AUTHORITY_MAP_CURRENT.md]
    Checker[check_recovery_architecture_0744.py]
    UPS[audit_ups_hotspots_0743.py]
    CI[source-validation.yml]

    Standards --> Recovery --> CurrentMap
    Recovery --> Testing --> Runbook
    Continuity --> CurrentMap
    OldMaps --> CurrentMap
    CurrentMap --> Checker --> CI
    CurrentMap --> UPS --> CI
    CI --> History
```

## Evidence Status

- Stages 0 through 4 are source-implemented and regression-gated on `main`.
- The exact modified Stage 1 Lua blobs were reconstructed locally, matched to GitHub blob hashes, and grammar-parsed.
- No successful Lua 5.2 repository-wide workflow result is recorded for the current head.
- GitHub combined status currently exposes no checks for the current head.
- No Factorio load, migration, save/reload, behavioral, high-count, or profiler evidence is claimed.
- `v0.1.674-rc.3` remains an experimental prerelease, not a verified release candidate.
