# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-17

## Purpose

This map connects the historical 0659–0675 drilldowns to the current recovered runtime spine, retained specialized families, explicitly retired authorities, and Stage 5 evidence boundary.

```mermaid
flowchart LR
    Present[Present in source]
    Active[Present in active HARDENERS table]
    Authority[Owns runtime behavior]
    Proven[Factorio save-load behavior and performance proven]
    Present --> Active --> Authority --> Proven
```

Source presence is not installation. Installation is not behavioral proof.

## Current Loader and Hardener Shape

```mermaid
flowchart TD
    Control[control.lua]
    Planning[planning_constraints_0646]
    Registry[runtime_event_registry self-initializes]
    Broker[runtime_tick_broker install]
    Route[runtime_tick_broker_0600:central-pulse]
    Prearm[prearm declarative HARDENERS]
    Core[normal installers]
    Final[task_auspex final installer]
    Verify[post-loader broker and hardener verification]
    Complete{broker route complete and every install returned literal true?}
    Ready[phase complete]
    Degraded[phase degraded]
    Quarantine[disable affected runtime family]
    Ledger[recovery_installation_0744 and diagnostics]

    Control --> Planning --> Registry --> Broker --> Route --> Prearm --> Core --> Final --> Verify --> Complete
    Complete -- yes --> Ready --> Ledger
    Complete -- no --> Degraded --> Quarantine --> Ledger
```

The canonical broker route exists before prearm. A periodic hardener therefore has no valid reason to register a direct `script.on_nth_tick` fallback during normal loading. `nil`, `false`, an error, a missing broker service, or an incomplete finalizer is an installation failure.

## Retired Parallel Authorities

The following files remain in source for history and comparison but are absent from the active `HARDENERS` table:

```mermaid
flowchart TD
    A[direct_acquisition_movement_lock_0650]
    B[movement_vector_enforcer_0651]
    C[movement_target_reconciler_0652]
    D[movement_intent_authority_0654]
    E[active_leaf_task_truth_0655]
    F[logistics_mineable_source_bridge_0657]
    R[RETIRED source-only authorities]
    A --> R
    B --> R
    C --> R
    D --> R
    E --> R
    F --> R
```

They were retired because they independently wrote movement tables, issued commands, rewrote pair targets and modes, synthesized successful movement, or moved mined output directly into station storage without carried custody.

Their replacement is the canonical chain:

```mermaid
flowchart LR
    Queue[order_queue_0469]
    Classifier[action_state_arbiter_0488 read-only]
    Dispatcher[single_dispatcher_0510]
    Action[canonical_action_0744]
    Executor[one owned executor]
    Movement[canonical movement controller or Void authority]
    Custody[persistent physical custody]
    Storage[atomic storage authority]
    Visual[visual_intent_line_authority_0657 read-only]

    Queue --> Classifier --> Dispatcher --> Action --> Executor --> Movement
    Executor --> Custody --> Storage
    Action --> Visual
    Movement --> Visual
```

## Canonical Recovery Target

```mermaid
flowchart TD
    Event[Factorio event]
    Registry[owner and route keyed registry]
    Broker[one central broker cadence]
    Discovery[bounded work discovery]
    Reservation[shared reservation]
    Queue[truthful order queue]
    Classification[pure classification]
    Dispatcher[canonical dispatcher]
    Action[canonical_action_0744]
    Executor[one family executor]
    Move[one movement owner]
    Remove[exact source removal]
    Carry[persistent custody]
    Revalidate[destination revalidation]
    Deposit[atomic destination deposit]
    Terminal[one terminal transition]
    Observe[read-only visuals and diagnostics]

    Event --> Registry --> Discovery
    Broker --> Discovery
    Discovery --> Reservation --> Queue --> Classification --> Dispatcher --> Action --> Executor
    Executor --> Move --> Remove --> Carry --> Revalidate --> Deposit --> Terminal --> Queue
    Action --> Observe
    Move --> Observe
```

## Stage 1 Transaction and Scheduler Repair

### Emergency production

```mermaid
sequenceDiagram
    participant Q as Order Queue 0469
    participant E as Emergency Production 0514
    participant S as Atomic Storage

    E->>E: require strict recipe and plan complete removal
    E->>E: remove exact ingredients
    alt removal short
        E->>E: rollback and retain return-ingredients custody on shortfall
    else removal complete
        E->>E: create output-held custody
        E->>S: atomic output deposit
        alt deposit blocked
            E->>E: retain output-held custody
        else output accepted
            E->>E: change to output-deposited
            E->>Q: canonical complete_current
            alt queue rejects completion
                E->>E: retain output-deposited and retry without reinsertion
            else queue accepts completion
                Q->>Q: terminal history and immediate promotion
                E->>E: clear task and custody
            end
        end
    end
```

### Direct acquisition and production handoff

```mermaid
sequenceDiagram
    participant A as Direct Acquisition 0513
    participant M as Movement 0418 or Void authority
    participant R as Exact physical target
    participant S as Atomic Storage
    participant Q as Order Queue 0469
    participant P as Emergency Production 0514

    A->>A: require explicit item target bounds and clamp
    A->>M: movement must return literal true
    A->>R: mutate only when extraction completes
    R-->>A: exact physical yield
    A->>A: persist carried custody
    A->>M: physically return to station
    A->>S: atomic exact deposit
    alt recipe materials complete
        A->>Q: transition current order and clear obsolete task
        A->>A: transfer task to p.emergency_craft
        Q->>P: same parent intent continues
    else acquisition complete
        A->>Q: complete and promote
    end
```

### Consecration and proxy ammunition

```mermaid
flowchart LR
    Consecrate[Consecration 0515]
    Claim[stored physical claim]
    Move[literal true movement]
    Apply[consume and apply exact capsule]
    Refund[atomic refund or persistent custody]
    Terminal[canonical terminal queue handoff]

    Ammo[Proxy Ammo 0649]
    Remove[exact station removal]
    Insert[checked proxy insertion]
    Remainder[atomic return or refund custody]

    Consecrate --> Claim --> Move --> Apply --> Refund --> Terminal
    Ammo --> Remove --> Insert --> Remainder
```

Proxy ammunition and visual intent are broker-owned and have no direct timing fallback. The visual authority reads `canonical_action_0744` or the current movement request and does not mutate work state.

## Stage 2 — Shared Runtime Spine

```mermaid
flowchart TD
    Register[register owner and route]
    Upsert[replace same owner-route identity]
    Sort[deterministic priority]
    Dispatch[one Factorio dispatcher]
    Filter[route-local filter]
    Call[isolated protected handler]
    BrokerRoute[exactly one runtime_tick_broker_0600 central-pulse route]
    Normalize[processed acted blocked waiting failed exhausted]
    Audit[broker_registry_integrity_0725]

    Register --> Upsert --> Sort --> Dispatch --> Filter --> Call
    BrokerRoute --> Normalize --> Audit
```

Numeric zero, `nil`, waiting, and blocked results are not actions. Service replacement preserves cadence. The broker audit requires one correctly owned central route and a complete broker installation ledger.

## Stage 3 — Canonical Behavioral Authority

```mermaid
flowchart LR
    Pair[Pair state]
    Classifier[action_state_arbiter_0488]
    Dispatcher[single_dispatcher_0510]
    Record[canonical_action_0744]
    Core[direct acquisition production consecration repair combat repair]
    Legacy[matching legacy controller]

    Pair --> Classifier --> Dispatcher --> Record --> Core
    Record -. gates duplicate nonterminal work .-> Legacy
```

The classifier owns no timer, movement request, task clearing, order mutation, pair target write, or pair mode write.

## Stage 4 — Static Pressure Protection

`audit_ups_hotspots_0743.py` compares periodic routes, fast routes, risky scans, direct commands, rewrite sites, and pair mode/target writes against the frozen pre-recovery baseline. A non-regressing static surface is not runtime profiler evidence.

## Stage 5 — Evidence and Release Boundary

```mermaid
flowchart TD
    CI[successful source-validation.yml for exact SHA]
    New[clean new-save with real pairs]
    Upgrade[real 0.1.672 disposable upgrade]
    Reload[both save and reload]
    Matrix[complete scenario matrix]
    Profiles[idle active and high-count profiles]
    Digests[SHA-256 bound evidence files]
    Validator[recovery evidence validator v2]
    Authorization[verified release authorization v2]
    Package[deterministic canonical archive]
    PackageTests[exact archive new-save and upgrade tests]
    Publish[publish proven artifact class]

    CI --> New --> Upgrade --> Reload --> Matrix --> Profiles --> Digests --> Validator --> Authorization --> Package --> PackageTests --> Publish
```

Authorization revalidates the bound evidence directory and manifest digest at packaging time. Protected `0.1.672`, absent authorization, rejected evidence, or mixed source identity blocks packaging.

## Remaining Recovery Defect Fronts

1. Obtain a successful complete source-validation run against one exact current SHA.
2. Repair every retained hardener that fails the literal-true install contract.
3. Remove any remaining direct periodic route or synthetic-success result in retained authorities.
4. Execute new-save, real `0.1.672` upgrade, configuration-change, and both reloads.
5. Execute Stage 1 transaction, queue, consecration, acquisition, and proxy-ammunition scenarios.
6. Prove event ordering, broker ownership, hardener completion, canonical-action agreement, and fairness.
7. Validate specialized machine, storage, item, energy, silo, artillery, roboport, fluid, turret, combat, overlap, ordinary movement, and Void movement behavior.
8. Capture idle, active, and high-count profiler evidence.
9. Validate the digest-bound evidence directory, authorize a qualified version, package deterministically, and repeat tests against the exact archive.

No runtime, migration, save/load, behavioral, profiler, package, or release success is claimed by this map.
