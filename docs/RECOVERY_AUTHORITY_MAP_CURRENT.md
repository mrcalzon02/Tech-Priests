# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-18

## Purpose

This map distinguishes source presence, active installation, runtime authority, and accepted Factorio evidence.

```mermaid
flowchart LR
    Present[Present in source]
    Active[Present in active HARDENERS table]
    Authority[Owns runtime behavior]
    Proven[Factorio save-load and performance proven]
    Present --> Active --> Authority --> Proven
```

Source presence is not installation. Installation is not behavioral proof.

## Current Loader and Hardener Shape

```mermaid
flowchart TD
    Control[control.lua]
    Planning[planning_constraints_0646]
    Registry[runtime_event_registry]
    Broker[runtime_tick_broker]
    Route[runtime_tick_broker_0600:central-pulse]
    Active[45 declarative active hardeners]
    Core[normal core installers]
    Final[task_auspex final installer]
    Verify[post-loader literal-true verification]
    Complete{broker route complete and every install returned true?}
    Ready[phase complete]
    Degraded[phase degraded]
    Disable[disable affected family]
    Ledger[recovery_installation_0744]

    Control --> Planning --> Registry --> Broker --> Route --> Active --> Core --> Final --> Verify --> Complete
    Complete -- yes --> Ready --> Ledger
    Complete -- no --> Degraded --> Disable --> Ledger
```

The canonical broker route exists before prearm. `nil`, `false`, an exception, a missing service, or an incomplete finalizer is an installation failure.

## Retired Parallel Authorities

Ten files remain in source for historical comparison but are absent from `HARDENERS`:

```mermaid
flowchart TD
    A[direct_acquisition_movement_lock_0650]
    B[movement_vector_enforcer_0651]
    C[movement_target_reconciler_0652]
    D[movement_intent_authority_0654]
    E[active_leaf_task_truth_0655]
    F[construction_placement_authority_0656]
    G[logistics_mineable_source_bridge_0657]
    H[repair_executor_integrity_0673]
    I[combat_repair_integrity_0676]
    J[combat_repair_terminal_cleanup_0677]
    R[RETIRED source-only authorities]
    A --> R
    B --> R
    C --> R
    D --> R
    E --> R
    F --> R
    G --> R
    H --> R
    I --> R
    J --> R
```

They were retired because they independently scheduled work, rewrote movement tables, issued commands, cleared queue state, rewrote pair targets or modes, synthesized success, spilled refunds, or moved products without canonical custody.

## Canonical Recovery Target

```mermaid
flowchart TD
    Event[Factorio event]
    Registry[owner-route registry]
    Broker[one broker cadence]
    Discovery[bounded discovery]
    Reservation[shared reservation]
    Queue[truthful order_queue_0469]
    Classification[read-only action_state_arbiter_0488]
    Dispatcher[single_dispatcher_0510]
    Action[canonical_action_0744]
    Executor[one physical family executor]
    Movement[one movement owner]
    Remove[exact source removal]
    Custody[persistent custody]
    Deposit[atomic deposit or exact return]
    Terminal[one queue terminal transition]
    Observe[read-only visuals and diagnostics]

    Event --> Registry --> Discovery
    Broker --> Discovery
    Discovery --> Reservation --> Queue --> Classification --> Dispatcher --> Action --> Executor
    Executor --> Movement --> Remove --> Custody --> Deposit --> Terminal --> Queue
    Action --> Observe
    Movement --> Observe
```

## Stage 1 Transaction and Scheduler Repair

### Emergency production

```mermaid
sequenceDiagram
    participant Q as Order Queue 0469
    participant E as Emergency Production 0514
    participant S as Atomic Storage
    E->>E: require strict recipe and plan exact removals
    E->>E: remove ingredients
    alt short removal
        E->>E: rollback or retain return-ingredients custody
    else exact removal
        E->>E: create output-held custody
        E->>S: atomic output deposit
        alt deposit blocked
            E->>E: retain output-held custody
        else accepted
            E->>E: mark output-deposited
            E->>Q: complete_current
            alt queue rejects completion
                E->>E: retain output-deposited and retry without reinsertion
            else accepted
                Q->>Q: terminal history and immediate promotion
            end
        end
    end
```

### Direct acquisition and consecration

```mermaid
flowchart LR
    Direct[Direct Acquisition 0513]
    Target[exact physical target]
    DirectCustody[direct_acquisition_custody_0513]
    Storage[atomic storage]
    Transition[queue transition or completion]
    Consecrate[Consecration 0515]
    Claim[physical claim]
    Capsule[exact capsule custody]
    Refund[atomic refund or retained custody]

    Direct --> Target --> DirectCustody --> Storage --> Transition
    Consecrate --> Claim --> Capsule --> Refund --> Transition
```

### Repair and combat repair

```mermaid
sequenceDiagram
    participant D as Dispatcher 0510
    participant C as Combat Doctrine 0517
    participant R as Repair Executor 0516
    participant M as Movement Authority
    participant S as Atomic Storage
    participant Q as Order Queue 0469

    D->>C: select defended damaged wall when combat-repair family is active
    C->>C: verify enemy pressure, real cover, and cluster ownership
    C->>R: service_pair using selected target
    R->>M: movement must return literal true
    R->>R: remove one repair pack and create repair_pack_custody_0516
    alt health mutation succeeds
        R->>R: verify restored health and consume custody
        R->>Q: complete_current when target is repaired
    else mutation, target, or cover fails
        C->>R: abort_pair
        R->>S: atomically return held repair pack
        alt refund blocked
            R->>R: retain return-pack custody and retry
        else refunded
            R->>Q: fail_current when applicable
        end
    end
```

`repair_executor_0516` is the sole physical repair authority. `combat_repair_doctrine_0517` owns only tactical target, cover, and cluster evaluation. The retired `0673`, `0676`, and `0677` wrappers may not return to the active graph.

### Proxy ammunition and visual intent

```mermaid
flowchart LR
    Ammo[Proxy Ammo 0649]
    RemoveAmmo[exact station removal]
    Insert[checked proxy insertion]
    Return[atomic remainder return or refund custody]
    Action[canonical_action_0744]
    Movement[current canonical movement request]
    Visual[Visual Intent 0657]

    Ammo --> RemoveAmmo --> Insert --> Return
    Action --> Visual
    Movement --> Visual
```

Proxy ammunition and visual intent are broker-owned. The visual authority is presentation-only.

## Stage 2 — Shared Runtime Spine

```mermaid
flowchart LR
    Register[register owner-route]
    Upsert[replace same identity]
    Sort[deterministic priority]
    Dispatch[one Factorio route]
    Isolate[isolated handler failure]
    Normalize[processed acted blocked waiting failed exhausted]
    Audit[broker_registry_integrity_0725]
    Register --> Upsert --> Sort --> Dispatch --> Isolate --> Normalize --> Audit
```

Numeric zero, `nil`, waiting, and blocked results are not actions. The broker audit requires one correctly owned central route.

## Stage 3 — Canonical Behavioral Authority

```mermaid
flowchart LR
    Pair[Pair state]
    Classifier[action_state_arbiter_0488]
    Dispatcher[single_dispatcher_0510]
    Record[canonical_action_0744]
    Core[direct production consecration repair combat-repair]
    Pair --> Classifier --> Dispatcher --> Record --> Core
```

The classifier owns no timer, movement request, task clearing, terminal transition, pair target write, or pair mode write.

## Stage 4 — Static Pressure Protection

`audit_ups_hotspots_0743.py` compares periodic routes, frequent routes, risky scans, direct commands, rewrite sites, and pair mode/target writes against the frozen pre-recovery baseline. Static non-regression is not runtime profiler evidence.

## Stage 5 — Evidence and Release Boundary

```mermaid
flowchart TD
    CI[successful source-validation for exact SHA]
    New[clean new-save with real pairs]
    Upgrade[real 0.1.672 disposable upgrade]
    Reload[both save and reload]
    Matrix[complete scenario matrix]
    Profiles[idle active high-count profiles]
    Digests[SHA-256 bound evidence]
    Validator[evidence validator v2]
    Authorization[verified authorization v2]
    Package[deterministic archive]
    PackageTests[exact archive load tests]
    Publish[publish proven artifact class]
    CI --> New --> Upgrade --> Reload --> Matrix --> Profiles --> Digests --> Validator --> Authorization --> Package --> PackageTests --> Publish
```

Authorization revalidates the evidence directory and manifest digest at packaging time. Protected `0.1.672`, absent authorization, mixed source identity, or rejected evidence blocks packaging.

## Remaining Recovery Defect Fronts

1. Obtain a successful complete source-validation run for one exact current SHA.
2. Audit the 45 retained hardeners for direct timing fallback, unconditional success, unchecked registration, and physical-accounting defects.
3. Repair generic storage access that still treats machine input, output, or furnace inventories as ordinary station storage.
4. Execute clean new-save, real `0.1.672` upgrade, configuration-change, save/reload, behavioral, and profiler scenarios.
5. Validate the bound evidence directory, authorize a qualified version, package deterministically, and repeat tests against the exact archive.

No runtime, migration, save/load, behavioral, profiler, package, or release success is claimed by this map.
