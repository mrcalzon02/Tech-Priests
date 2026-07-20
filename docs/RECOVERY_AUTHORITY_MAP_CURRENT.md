# Tech Priests Current Recovery Authority Map

**Status:** Current architecture map for base-state recovery  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Development lane:** `0.1.674-dev`  
**Work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Mapped:** 2026-07-20

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
    Active[35 declarative active hardeners]
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

Twenty files remain in source for historical comparison but are absent from `HARDENERS`:

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
    K[machine_logistics_integrity_0682]
    L[machine_logistics_candidate_recovery_0683]
    M[machine_logistics_final_authority_0684]
    N[item_family_integrity_0703]
    O[fusion_reactor_readiness_guard_0727]
    P[energy_readiness_diagnostics_0711]
    Q[energy_item_automation_guard_0722]
    S[energy_automation_guard_install_assertion_0726]
    T[rocket_silo_live_ownership_guard_0728]
    U[artillery_train_validity_guard_0724]
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
    K --> R
    L --> R
    M --> R
    N --> R
    O --> R
    P --> R
    Q --> R
    S --> R
    T --> R
    U --> R
```

They were retired because they independently scheduled work, rewrote movement tables, issued commands, cleared queue state, rewrote pair targets or modes, synthesized success, spilled refunds, moved products without canonical custody, wrapped an already recovered executor, or made correctness depend on patch-install order.

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

### Direct acquisition, consecration, and repair

```mermaid
flowchart LR
    Direct[Direct Acquisition 0513]
    DirectCustody[direct_acquisition_custody_0513]
    Consecrate[Consecration 0515]
    Capsule[exact capsule custody]
    Repair[Repair Executor 0516]
    Pack[repair_pack_custody_0516]
    Storage[atomic storage or refund]
    Queue[canonical queue transition]

    Direct --> DirectCustody --> Storage --> Queue
    Consecrate --> Capsule --> Storage --> Queue
    Repair --> Pack --> Storage --> Queue
```

`repair_executor_0516` is the sole physical repair authority. `combat_repair_doctrine_0517` owns only tactical target, cover, and cluster evaluation.

### Machine logistics

```mermaid
flowchart LR
    MachineDiscovery[machine_logistics_discovery_0528]
    MachineCandidate[machine_logistics_candidate_0528]
    Classifier[action_state_arbiter_0488]
    Dispatcher[single_dispatcher_0510]
    Machine[logistics_machine_fulfillment_0528]
    MachineCustody[machine_logistics_custody_0528]
    GenericStorage[container-only storage 0686]

    MachineDiscovery --> MachineCandidate --> Classifier --> Dispatcher --> Machine
    Machine --> MachineCustody --> GenericStorage
```

The retired `0682`, `0683`, and `0684` wrappers may not return to the active graph.

### Proxy ammunition and visible item-family logistics

```mermaid
flowchart TD
    ProxyBroker[proxy_ammo_hardener_0649 broker service]
    ProxyRemove[exact station ammo removal]
    ProxyInsert[checked hidden-proxy insertion]
    ProxyRefund[atomic return or proxy refund custody]

    ItemDiscovery[item_family_discovery_0702]
    ItemCandidate[item_family_candidate_0702]
    ItemClassifier[action_state_arbiter_0488 read-only]
    ItemDispatcher[single_dispatcher_0510]
    ItemExecutor[item_family_logistics_0702]
    ItemMove[literal-true movement]
    ItemRemove[exact home-source removal]
    ItemCustody[item_family_custody_0702]
    VisibleTarget[visible turret ammo or lab science inventory]
    ItemReturn[exact source return or atomic station deposit]

    ProxyBroker --> ProxyRemove --> ProxyInsert --> ProxyRefund
    ItemDiscovery --> ItemCandidate --> ItemClassifier --> ItemDispatcher --> ItemExecutor
    ItemExecutor --> ItemMove --> ItemRemove --> ItemCustody --> VisibleTarget
    VisibleTarget --> ItemReturn
```

Hidden proxy ammunition remains exclusively owned by `proxy_ammo_hardener_0649`. `item_family_logistics_0702` owns only visible unautomated ammunition turrets and laboratories. It performs broker-budgeted discovery only; the classifier recommends without mutation and the dispatcher alone executes. Ammo compatibility, research-change handling, custody recovery, and terminal cleanup were consolidated from retired `item_family_integrity_0703`.

### Energy readiness and physical fuel logistics

```mermaid
flowchart TD
    Readiness[energy_family_readiness_0705]
    Preconditions[fuel burnt-result fluid electric heat and automation inspection]
    Discovery[energy_family_discovery_0707]
    Candidate[energy_family_candidate_0707]
    Classifier[action_state_arbiter_0488 read-only]
    Dispatcher[single_dispatcher_0510]
    Executor[energy_family_logistics_0707]
    Reserve[energy-family-logistics reservation]
    Move[literal-true movement]
    Remove[exact fuel or burnt-result removal]
    Custody[energy_family_custody_0707]
    Target[checked fuel insertion or burnt-result evacuation]
    Return[exact source return or atomic station deposit]

    Readiness --> Preconditions --> Discovery --> Candidate --> Classifier --> Dispatcher --> Executor
    Executor --> Reserve --> Move --> Remove --> Custody --> Target --> Return
```

`energy_family_readiness_0705` is read-only. It incorporates fusion-reactor heat semantics, connected inserter/loader ownership, and corrected diagnostic counters. `energy_family_logistics_0707` owns discovery data and all physical fuel or burnt-result work, but its broker service is discovery-only. The dispatcher alone calls `service_pair`. The retired `0727`, `0711`, `0722`, and `0726` wrappers may not return to the active graph.

### Rocket-silo readiness and physical item logistics

```mermaid
flowchart TD
    Readiness[rocket_silo_readiness_0709]
    Preconditions[recipe deficits trash fluids launch and external ownership]
    Discovery[rocket_silo_discovery_0710]
    Candidate[rocket_silo_candidate_0710]
    Classifier[action_state_arbiter_0488 read-only]
    Dispatcher[single_dispatcher_0510]
    Executor[rocket_silo_logistics_0710]
    Reserve[rocket-silo-logistics reservation]
    Move[literal-true movement]
    Remove[exact home-source or silo-trash removal]
    Custody[rocket_silo_custody_0710]
    Target[checked silo-input insertion or trash evacuation]
    Return[exact source return or atomic station deposit]

    Readiness --> Preconditions --> Discovery --> Candidate --> Classifier --> Dispatcher --> Executor
    Executor --> Reserve --> Move --> Remove --> Custody --> Target --> Return
```

`rocket_silo_readiness_0709` is read-only and reports inspection with `acted=0`. `rocket_silo_logistics_0710` owns candidate data and all physical manual input or trash work, but its broker service is discovery-only. The dispatcher alone calls `service_pair`. Launch activity and external logistics ownership are revalidated before and during execution. The retired `rocket_silo_live_ownership_guard_0728` wrapper may not return to the active graph.

### Artillery readiness and physical ammunition logistics

```mermaid
flowchart TD
    Readiness[artillery_readiness_0712]
    Preconditions[compatible ammo automation and train validity]
    Discovery[artillery_discovery_0713]
    Candidate[artillery_candidate_0713]
    Classifier[action_state_arbiter_0488 read-only]
    Dispatcher[single_dispatcher_0510]
    Executor[artillery_logistics_0713]
    Reserve[artillery-logistics reservation]
    Move[literal-true movement]
    Remove[exact home-source ammunition removal]
    Custody[artillery_custody_0713]
    Target[checked fixed turret or stationary manual wagon insertion]
    Return[exact source return or atomic station deposit]

    Readiness --> Preconditions --> Discovery --> Candidate --> Classifier --> Dispatcher --> Executor
    Executor --> Reserve --> Move --> Remove --> Custody --> Target --> Return
```

`artillery_readiness_0712` is read-only and reports inspection with `acted=0`. Detached or invalid wagons, moving wagons, automatic-mode trains, and externally automated artillery are not manual service targets. `artillery_logistics_0713` owns candidate data and all physical ammunition work, but its broker service is discovery-only. The dispatcher alone calls `service_pair`. The retired `artillery_train_validity_guard_0724` wrapper may not return to the active graph.

### Generic storage and priest cargo

```mermaid
sequenceDiagram
    participant P as Priest inventory
    participant T as Transfer Integrity 0687
    participant S as Storage Authority 0686
    T->>P: remove exact stack
    T->>T: create inventory_transfer_custody_0687
    T->>S: exact container-only deposit
    alt deposit accepted
        T->>T: clear custody
    else deposit blocked
        T->>P: restore exact stack
        alt restore shortfall
            T->>T: retain removed-not-credited custody
        end
    end
```

Generic storage cannot address assembler, furnace, laboratory, fuel, or silo work inventories.

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
    Core[owned physical family executor]
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
2. Continue auditing the 35 retained hardeners for direct timing fallback, unconditional success, unchecked registration, and physical-accounting defects.
3. Audit roboport, fluid, and fluid-turret specialized families for the recovered discovery/classification/dispatcher/custody pattern.
4. Execute clean new-save, real `0.1.672` upgrade, configuration-change, save/reload, behavioral, and profiler scenarios.
5. Validate the bound evidence directory, authorize a qualified version, package deterministically, and repeat tests against the exact archive.

No runtime, migration, save/load, behavioral, profiler, package, or release success is claimed by this map.
