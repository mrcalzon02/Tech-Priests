# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-17

## Purpose

This map connects the detailed 0659–0675 Mermaid/function drilldowns to the later 0680–0739 authority families and the active recovery changes. It distinguishes source presence, installation, authority, and proof:

```mermaid
flowchart LR
    Present[Present in source]
    Installed[Installed or wrapped]
    Authoritative[Owns live behavior]
    Proven[Runtime save-load and behavior proven]
    Present --> Installed --> Authoritative --> Proven
```

Source implementation is not runtime proof.

## Recovered Runtime Spine

```mermaid
flowchart TD
    World[Factorio event]
    Registry[runtime_event_registry
owner-keyed routes]
    Broker[runtime_tick_broker
structured results and budgets]
    Work[shared work discovery]
    Reserve[shared reservations]
    Queue[order_queue_0469
truthful per-pair intent]
    Classifier[action_state_arbiter_0488
pure read-only classification]
    Dispatcher[single_dispatcher_0510
canonical action and executor owner]
    Executor[one owned family executor]
    Movement[canonical movement request]
    Custody[physical removal and custody]
    Deposit[atomic destination deposit]
    Terminal[one terminal transition and promotion]
    Observe[read-only visual audio diagnostic surfaces]

    World --> Registry --> Work
    Broker --> Work
    Work --> Reserve --> Queue --> Classifier --> Dispatcher --> Executor
    Executor --> Movement --> Custody --> Deposit --> Terminal --> Observe
    Terminal --> Queue
```

The generated legacy fragments and remaining family wrappers are compatibility surfaces beneath this target, not parallel authorities to be expanded.

## Loader and Hardener Recovery

```mermaid
flowchart TD
    Control[control.lua]
    Core[normal core installer sequence]
    Prearm[planning_constraints_0646 prearm]
    Base[base family modules install]
    FinalHook[task_auspex final normal installer]
    Finalize[planning_constraints finalize_installation]
    Complete{all required hardeners installed?}
    Enabled[all families remain enabled]
    Degraded[classify failed hardener by family]
    Disable[disable affected base family only]
    Ledger[recovery_installation_0744 and automatic diagnostics]

    Control --> Prearm
    Control --> Core --> Base --> FinalHook --> Finalize --> Complete
    Complete -- yes --> Enabled --> Ledger
    Complete -- no --> Degraded --> Disable --> Ledger
```

Early installation failures are provisional. The final post-loader pass occurs while event registration remains legal. A final failure no longer permits the affected family to continue as though fully hardened.

## Stage 1 — Physical State and Scheduler Truth

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
        Q-->>Caller: active queued or duplicate-merged
    else full
        Q-->>Caller: rejected queue-full
    end
    Q->>D: current order
    D->>E: service production
    E->>E: require strict recipe metadata
    E->>E: plan complete ingredient removal
    E->>E: remove exact ingredients
    alt removal fails
        E->>E: rollback exact removals
        E->>E: persist rollback custody on shortfall
    else succeeds
        E->>E: persist output-held custody
        E->>S: atomic exact deposit
        alt blocked
            S-->>E: custody retained
        else deposited
            E->>Q: complete current
            Q->>Q: history and immediate promotion
        end
    end
```

### Consecration

```mermaid
sequenceDiagram
    participant C as Consecration 0515
    participant Q as Order Queue 0469
    participant M as Movement 0418
    participant I as Consecration item source
    participant S as Storage Authority 0686

    C->>Q: verified target-aware admission
    C->>C: claim by stored physical key
    C->>M: canonical movement request
    alt movement rejection or invalid target
        C->>C: release claim and clear timers
        C->>Q: fail and promote
    else rite completes
        C->>I: consume exact capsule
        C->>C: apply with source context
        alt application fails
            C->>S: exact atomic refund
            alt storage blocked
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

### Direct acquisition and station-craft handoff

```mermaid
sequenceDiagram
    participant D as Direct Acquisition 0513
    participant M as Movement 0418
    participant R as Physical resource or exact-yield target
    participant S as Storage Authority 0686
    participant Q as Order Queue 0469
    participant P as Emergency Production 0514

    D->>D: require explicit output and exact target identity
    D->>M: canonical travel request
    D->>D: verified work clamp
    D->>R: mutate only at completed extraction
    R-->>D: exact physical yield
    D->>D: persist carried custody
    D->>M: return to station with custody
    D->>S: atomic exact deposit
    S-->>D: deposited or custody retained
    alt more gathered units required
        D->>M: return to same valid target or replan
    else recipe materials complete
        D->>Q: transition current order to station craft
        Q->>P: same parent intent serviced by production
    else acquisition complete
        D->>Q: complete and promote
    end
```

### Stage 1 source invariants

- Full queues reject rather than discard work.
- Order identity includes physical target context and duplicates refresh mutable metadata.
- Preemption cannot lose the interrupted order.
- Invalid targets fail rather than complete.
- Initial callbacks execute once and promoted callbacks execute once.
- Terminal transitions promote immediately.
- Production ingredients and outputs remain transactionally accounted.
- Consecration claims, timers, movement, admission, refunds, and terminal state are explicit.
- Direct acquisition neither invents fallback output nor damages resources during presentation.
- Direct output travels through persistent custody and physical return before deposit.
- Acquisition-to-production handoff is a canonical scheduler transition.

## Stage 2 — Shared Runtime Spine

### Owner-keyed event routes

```mermaid
flowchart TD
    Register[register owner plus route]
    Upsert[replace same owner route id]
    Sort[numeric deterministic priority]
    Dispatch[one Factorio event dispatcher]
    Filter[route-local filter evaluation]
    Call[protected handler call]
    Error{handler failed?}
    Record[record isolated failure]
    Continue[continue later owners]
    Remove[remove one owner route]

    Register --> Upsert --> Sort --> Dispatch --> Filter --> Call --> Error
    Error -- yes --> Record --> Continue
    Error -- no --> Continue
    Remove --> Sort
```

`first/front` and `last/final` are actual priorities. Removing one owner no longer clears all handlers for the event or cadence.

### Structured broker truth

```mermaid
flowchart LR
    Service[service result]
    Normalize[normalize processed acted blocked waiting failed exhausted]
    Metrics[truthful counters]
    Budget[adaptive pressure reads confirmed signals]
    Service --> Normalize --> Metrics --> Budget
```

Numeric zero, `nil`, waiting, or blocked results are not counted as actions. Re-registering a service preserves its next due tick unless explicitly replaced.

## Stage 3 — Canonical Behavioral Authority

```mermaid
flowchart TD
    Order[current per-pair order]
    Pure[pure action classifier]
    Record[canonical_action_0744]
    Dispatch[single dispatcher]
    Family{owned family}
    Direct[direct acquisition]
    Craft[station production]
    Consecrate[consecration]
    Repair[repair]
    CombatRepair[combat repair]
    Compatibility[unmigrated family compatibility leaf]
    LegacyGate[gate matching parallel legacy tick only while owned work is nonterminal]

    Order --> Pure --> Record --> Dispatch --> Family
    Family --> Direct
    Family --> Craft
    Family --> Consecrate
    Family --> Repair
    Family --> CombatRepair
    Family --> Compatibility
    Dispatch --> LegacyGate
```

The classifier owns no queue mutation, movement request, executor clearing, pair mode write, pair target write, or periodic timer. The dispatcher publishes one serializable action record containing action identity, family, owner, phase, status, order, item, target identity, position, source, and timestamps.

Specialized later families remain compatibility leaves until runtime evidence proves their existing wrapper ownership and they can be migrated without jeopardizing physical custody.

## Stage 4 — Static UPS Recovery Gate

```mermaid
flowchart LR
    Source[current Lua tree]
    Audit[audit_ups_hotspots_0743]
    Routes[periodic routes]
    Scans[risky scans]
    Commands[direct commands]
    Writes[pair mode and target writes]
    Compare[compare frozen pre-recovery baseline]
    Pass[no tracked source metric regressed]
    Fail[CI failure]

    Source --> Audit
    Audit --> Routes
    Audit --> Scans
    Audit --> Commands
    Audit --> Writes
    Routes --> Compare
    Scans --> Compare
    Commands --> Compare
    Writes --> Compare
    Compare -- at or below baseline --> Pass
    Compare -- above baseline --> Fail
```

The frozen baseline is 510 periodic routes, 17 active routes at 30 ticks or faster, 68 risky scans, 916 rewrite sites, 72 direct command sites, 352 `pair.mode` writes, and 177 `pair.target` writes. Source-count reduction demonstrates graph simplification only; it does not replace a clean-world profiler run.

## Later Specialized Families

```mermaid
flowchart LR
    Machine[Machine logistics 0682-0684]
    Storage[Storage roles and transfer 0686-0687]
    Fluid[Fluid network and route planning 0689-0700]
    Item[Item-family logistics 0702-0703]
    Energy[Energy readiness and logistics 0705-0707 plus guards]
    Silo[Rocket silo 0709-0710 plus guard]
    Artillery[Artillery 0712-0713 plus guard]
    Roboport[Roboport 0714-0715]
    Turret[Fluid turret 0716-0719 plus integrity]
    Lifecycle[Command cleanup integration lifecycle migration 0720-0738]

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
    Intent[movement intent reconciler and vector 0651-0654]
    Request[canonical movement request 0418]
    Controller[movement_controller]
    Bounds[movement bounds 0511]
    Enforcement[movement enforcement 0566]
    Economy[unobserved transit 0572]
    Corridor[authority corridor 0574]
    Void[Void movement 0630]
    Visual[visual intent 0657]

    Action --> Intent --> Request --> Controller --> Bounds --> Enforcement --> Economy --> Corridor --> Void
    Intent --> Visual
```

Void movement still requires collision recovery, proxy synchronization, elapsed-time stepping, fairness, save/load proof, and executor recovery tests.

## Remaining Boundary

```mermaid
flowchart TD
    Source[Stages 0 through 4 source implementation]
    CI[successful full source-validation run]
    Load[new-save Factorio load]
    Migration[real 0.1.672 upgrade]
    Reload[save and reload both]
    Behavior[transaction family movement overlap and interruption matrix]
    Profile[clean-world and high-count profiler evidence]
    Artifact[verified artifact classification and packaged load]

    Source --> CI --> Load --> Migration --> Reload --> Behavior --> Profile --> Artifact
```

Further claims are blocked on external Factorio and GitHub Actions evidence, not on another speculative source wrapper.

## Documentation and Evidence Connections

```mermaid
flowchart LR
    Recovery[RECOVERY_REPAIR_SEQUENCE.md]
    Standards[docs/STANDARDS_AND_PRACTICES.md]
    History[docs/DEVELOPMENT_HISTORY.md]
    Testing[CURRENT_TESTING_GOALS.md]
    Continuity[AUTHORITY_REFACTOR_CONTINUITY.md]
    OldMaps[BEHAVIOR_MERMAID series]
    CurrentMap[RECOVERY_AUTHORITY_MAP_CURRENT.md]
    Checker[check_recovery_architecture_0744.py]
    UPS[audit_ups_hotspots_0743.py]
    CI[source-validation workflow]

    Standards --> Recovery --> CurrentMap
    Recovery --> Testing
    Continuity --> CurrentMap
    OldMaps --> CurrentMap
    CurrentMap --> Checker --> CI
    CurrentMap --> UPS --> CI
    CI --> History
```

## Evidence Status

- Stages 1 through 4 are source-implemented and source-enforced on `main`.
- Changed Lua modules were grammar-parsed during development, but no successful Lua 5.2 workflow result is recorded for the current head.
- GitHub combined status currently exposes no checks for the current recovery head.
- No Factorio load, migration, save/reload, behavioral, high-count, or profiler evidence is claimed.
- `v0.1.674-rc.3` remains an experimental prerelease, not a verified release candidate.
