# Tech-Priests Function-Level Mermaid Drilldown: Direct Acquisition Movement Stack

Version: 0.1.662-map-pass-3  
Previous drilldown: `docs/BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_0661.md`  
Companion overview: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

Purpose: map the direct-acquisition movement repair stack function-by-function. This is the stack that tries to prevent the priest from saying it is acquiring a resource while walking to a station, stale arbiter point, or unrelated target.

Mapped in this pass:

1. `direct_acquisition_physical_guard_0649.lua`
2. `direct_acquisition_movement_lock_0650.lua`
3. `movement_target_reconciler_0652.lua`
4. `movement_intent_authority_0654.lua`

These modules sit between the direct acquisition executor and the movement/vector system.

---

## 1. Direct Acquisition Movement Stack Overview

```mermaid
flowchart TD
    DAE[direct_acquisition_executor_0513 current task]
    DAE --> PG[direct_acquisition_physical_guard_0649]
    PG --> Physical{valid physical target entity?}
    Physical -- no --> Adopt[adopt nearby resource/rock/tree target]
    Physical -- no and none found --> Clear[clear stale/synthetic direct task]
    Physical -- yes --> ML[direct_acquisition_movement_lock_0650]
    Adopt --> ML
    ML --> Lock[pair.direct_acquisition_target_lock_0650]
    Lock --> Reconcile[movement_target_reconciler_0652]
    Reconcile --> RequestA[pair.movement_request_0418 direct-target-reconciler]
    Lock --> Intent[movement_intent_authority_0654]
    Intent --> RequestB[pair.movement_request_0418 direct-acquisition-intent]
    RequestA --> Leaf[active_leaf_task_truth_0655]
    RequestB --> Leaf
    Leaf --> Vector[movement_vector_enforcer_0651]
    Vector --> Feet[priest go_to_location toward locked target]
```

The stack has intentionally redundant layers because older systems were writing stale station/action-arbiter movement requests after the direct task had already picked a target. The correct cleanup later is not to remove layers blindly; it is to prove which layer still has unique work, then consolidate.

---

## 2. `direct_acquisition_physical_guard_0649.lua`

### Function inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `root()` | local storage root | Ensures module storage | writes `storage.tech_priests.direct_acquisition_physical_guard_0649` |
| `stat(name,n)` | local metric | Increments stats | writes module stats |
| `record(action,pair,detail)` | local metric | Stores recent guard events | writes module recent |
| `item_exists(name)` | local prototype helper | Checks item prototype existence | reads `prototypes.item` |
| `current_direct_task(pair)` | local selector | Finds current direct task | calls `TechPriestsDirectAcquisitionExecutor0513.current_direct_task` or scans `emergency_craft`, `direct_acquisition_task_0336`, `active_acquisition_0333` |
| `output_item(task,cur)` | local extractor | Finds item/resource output for direct task | none |
| `target_entity(cur)` | local extractor | Gets entity/target/source from task | none |
| `target_position(cur)` | local extractor | Gets target position from entity or task position | none |
| `entity_matches_item(entity,item)` | local predicate | Determines whether target entity can produce the requested item | checks resource/tree/rock/name heuristics |
| `find_physical_target(pair,pos,item)` | local scanner | Searches near intended position for matching physical entity | calls `surface.find_entities_filtered` |
| `M.guard_pair(pair,reason)` | public guard | Enforces real target requirement | adopts entity or clears stale task |
| `wrap_direct_executor()` | local wrapper | Wraps direct executor service | blocks executor when no physical target exists and guard fails |
| `M.service_pair(pair,reason)` | public service | Calls guard | same side effects as guard |
| `M.service_all(reason)` | public loop | Services all pairs | none beyond guard |
| `M.install()` | public installer | Installs wrapper and tick service | writes `_G.TechPriestsDirectAcquisitionPhysicalGuard0649` |

### Physical target adoption graph

```mermaid
flowchart TD
    Guard[M.guard_pair] --> Enabled{enabled?}
    Enabled -- no --> Disabled[return disabled]
    Enabled -- yes --> Valid{valid pair?}
    Valid -- no --> Invalid[return invalid-pair]
    Valid -- yes --> Current[current_direct_task]
    Current --> HasTask{direct task?}
    HasTask -- no --> NoTask[return no-direct-task]
    HasTask -- yes --> Item[output_item]
    Item --> Resource{item nil or resource item?}
    Resource -- no --> NotResource[return not-resource-acquisition]
    Resource -- yes --> Entity[target_entity]
    Entity --> EntityValid{valid entity?}
    EntityValid -- yes --> Matches{entity_matches_item?}
    Matches -- yes --> HasPhysical[return has-physical-target]
    Matches -- no --> ClearBad[cur.entity/target/source = nil]
    EntityValid -- no --> Position[target_position]
    ClearBad --> Position
    Position --> Find[find_physical_target near pos]
    Find --> Found{found?}
    Found -- yes --> Adopt[cur.entity/target/source/position = found]
    Adopt --> PairTarget[pair.target = found]
    PairTarget --> ReturnAdopted[return adopted]
    Found -- no --> ClearTask[clear task.current or pair task field]
    ClearTask --> ClearTarget[pair.target = nil]
    ClearTarget --> Mode[pair.mode = direct-acquisition-needs-physical-target-0649]
    Mode --> Dispatcher[pair.dispatcher_direct_0513 phase need-physical-target]
    Dispatcher --> ReturnCleared[return cleared-stale-target]
```

### Direct executor wrapper graph

```mermaid
flowchart TD
    Install[M.install] --> Root[root]
    Install --> Wrap[wrap_direct_executor]
    Install --> Global[_G.TechPriestsDirectAcquisitionPhysicalGuard0649]
    Wrap --> Exec[TechPriestsDirectAcquisitionExecutor0513]
    Exec --> HasService{service_pair exists and not wrapped?}
    HasService -- no --> ReturnFalse[return false]
    HasService -- yes --> SavePrev[save previous service_pair]
    SavePrev --> Wrapped[Exec.service_pair wrapper]
    Wrapped --> Current[current_direct_task]
    Current --> NeedsGuard{direct task and no target_entity?}
    NeedsGuard -- yes --> Guard[M.guard_pair]
    Guard --> ActedBad{acted and why not adopted?}
    ActedBad -- yes --> Stop[return false, why]
    ActedBad -- no --> Prev[previous direct executor service_pair]
    NeedsGuard -- no --> Prev
```

### Side-effect map

```mermaid
flowchart LR
    Adopt[physical target adopted] --> CurEntity[cur.entity = found]
    Adopt --> CurTarget[cur.target = found]
    Adopt --> CurSource[cur.source = found]
    Adopt --> CurPos[cur.position = found.position]
    Adopt --> PairTarget[pair.target = found]

    Missing[physical target missing] --> ClearCurrent[task.current nil or pair task field nil]
    Missing --> PairTargetNil[pair.target = nil]
    Missing --> Mode[pair.mode = direct-acquisition-needs-physical-target-0649]
    Missing --> Dispatcher[pair.dispatcher_direct_0513 phase/detail/item/tick]
```

Risk: this module writes `pair.target` directly. It should usually be followed by 0650/0652/0654/0655 so movement and display agree with that target.

---

## 3. `direct_acquisition_movement_lock_0650.lua`

### Function inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `root`, `stat`, `record` | local storage/metrics | Storage and event history | writes module storage |
| `get_exec()` | local loader | Gets direct acquisition executor | may require `direct_acquisition_executor_0513` |
| `current_direct_task(pair)` | local selector | Finds active direct task | calls executor or scans pair fields |
| `target_entity(cur)` | local extractor | Reads task entity/target/source | none |
| `target_position(cur)` | local extractor | Reads task position | none |
| `output_item(task,cur)` | local extractor | Gets requested/output item | none |
| `target_label(e,pos)` | local formatter | Label for logging | none |
| `lock_current_target(pair,task,cur,reason)` | local writer | Creates/refreshes target lock | writes `pair.direct_acquisition_target_lock_0650` |
| `clear_lock(pair,reason)` | local writer | Clears target lock | writes `pair.direct_acquisition_target_lock_0650 = nil` |
| `restore_locked_target(pair,task,cur,reason)` | local writer | Restores task entity fields to locked entity | writes task target fields, `pair.target`, `pair.mode`, dispatcher phase |
| `force_direct_command(pair,pos,reason)` | local movement fallback | Forces Factorio go-to command | writes pair movement state and `direct_acquisition_force_move_0650` |
| `wrap_movement_request()` | local wrapper | Adds forced fallback when movement request fails | wraps `_G.tech_priests_request_movement_0418` |
| `wrap_executor()` | local wrapper | Wraps direct executor service to restore/lock target | wraps executor `service_pair` |
| `M.service_pair(pair,reason)` | public service | Maintains lock and forced movement | restores target and commands if stale/far |
| `M.service_all(reason)` | public loop | Runs wrappers and services pairs | none beyond service |
| `M.install()` | public installer | Installs wrappers/tick service | writes `_G.TechPriestsDirectAcquisitionMovementLock0650` |

### Lock lifecycle graph

```mermaid
flowchart TD
    Service[M.service_pair] --> Enabled{enabled and valid?}
    Enabled -- no --> ExitFalse[return false]
    Enabled -- yes --> Current[current_direct_task]
    Current --> HasTask{task and current?}
    HasTask -- no --> ClearNoTask[clear_lock service-no-task]
    HasTask -- yes --> Restore[restore_locked_target]
    Restore --> Lock{existing lock valid?}
    Lock -- yes --> CurSame{task target already lock.entity?}
    CurSame -- yes --> CheckFar[check distance to lock]
    CurSame -- no --> Rewrite[cur.entity/target/source/position = lock.entity]
    Rewrite --> PairTarget[pair.target = lock.entity]
    PairTarget --> Mode[pair.mode = travelling-to-direct-acquisition]
    Mode --> CheckFar
    Lock -- no --> CheckEntity{target_entity current valid?}
    CheckEntity -- yes --> LockCurrent[lock_current_target]
    CheckEntity -- no --> ExitFalse
    CheckFar --> Far{far from lock and stale forced command?}
    Far -- yes --> Force[force_direct_command]
    Far -- no --> MaybeLock{target_entity exists?}
    MaybeLock -- yes --> LockCurrent
    MaybeLock -- no --> ExitFalse
```

### Executor wrapper graph

```mermaid
flowchart TD
    Wrap[wrap_executor] --> Exec[get_exec]
    Exec --> ServiceExists{Exec.service_pair exists and not wrapped?}
    ServiceExists -- no --> ReturnFalse[return false]
    ServiceExists -- yes --> SavePrev[save previous Exec.service_pair]
    SavePrev --> Wrapped[Exec.service_pair wrapper]
    Wrapped --> Enabled{lock enabled?}
    Enabled -- no --> Prev[previous service_pair]
    Enabled -- yes --> Current[current_direct_task]
    Current --> HasTask{task exists?}
    HasTask -- no --> Clear[clear_lock no-direct-task]
    Clear --> Prev
    HasTask -- yes --> Restore[restore_locked_target before service]
    Restore --> PrevCall[call previous service_pair]
    PrevCall --> ReRead[current_direct_task again]
    ReRead --> Phase{dispatcher phase walk/work?}
    Phase -- yes --> LockCurrent[lock_current_target]
    Phase -- complete/return/inactive --> ClearLock[clear_lock]
    Phase -- movement-request-failed --> Force[force_direct_command to lock]
    LockCurrent --> Return[return ok, why]
    ClearLock --> Return
    Force --> Return
```

### Movement request fallback graph

```mermaid
flowchart TD
    WrapReq[wrap_movement_request] --> MovementFunc[_G.tech_priests_request_movement_0418]
    MovementFunc --> Wrapped[wrapper calls previous request]
    Wrapped --> Ok{previous returned false?}
    Ok -- no --> ReturnOk[return ok]
    Ok -- yes --> DirectReason{reason/owner contains direct-acquisition?}
    DirectReason -- no --> ReturnFalse[return false]
    DirectReason -- yes --> Force[force_direct_command]
    Force --> Forced{forced ok?}
    Forced -- yes --> ReturnTrue[return true]
    Forced -- no --> ReturnFalse
```

### Side-effect map

```mermaid
flowchart LR
    LockCurrent[lock_current_target] --> LockField[pair.direct_acquisition_target_lock_0650]
    Restore[restore_locked_target] --> CurEntity[cur.entity/target/source]
    Restore --> CurPosition[cur.position]
    Restore --> PairTarget[pair.target]
    Restore --> PairMode[pair.mode travelling-to-direct-acquisition]
    Restore --> Dispatcher[pair.dispatcher_direct_0513 phase walk-to-target]
    Force[force_direct_command] --> Factorio[commandable.set_command go_to_location]
    Force --> Reason[pair.movement_controller_reason_0418]
    Force --> LastMove[pair.direct_acquisition_force_move_0650]
```

---

## 4. `movement_target_reconciler_0652.lua`

### Function inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `root`, `stat`, `record` | local storage/metrics | Storage and logs | writes module root/recent |
| `movement_root()` | local movement root | Ensures movement request storage | writes `storage.tech_priests.movement_controller_0419` |
| `lock_active(pair)` | local selector | Determines whether direct target lock should still control movement | reads lock, dispatcher phase, pair mode, lock age |
| `request_owner(req)` | local helper | Gets lower-case request owner/reason | none |
| `request_is_direct(req)` | local predicate | Determines whether request already direct/reconciler owned | none |
| `request_points_to_lock(req,lock)` | local predicate | Checks request coordinates against lock position | none |
| `make_lock_request(pair,lock,reason)` | local writer | Creates direct-target movement request | writes pair request and movement controller request table |
| `force_go_to(pair,req,reason)` | local movement | Commands priest to request target | writes movement state/last command |
| `M.reconcile_pair(pair,reason)` | public service | Replaces stale movement request with lock request | writes `pair.target`, `pair.acquisition_target_0652`, request table |
| `wrap_movement_request()` | local wrapper | Redirects non-exempt non-direct movement away from stale target | wraps `_G.tech_priests_request_movement_0418` |
| `M.service_all(reason)` | public loop | Wraps request and reconciles all pairs | none beyond reconcile |
| `M.install()` | public installer | Registers service | writes `_G.TechPriestsMovementTargetReconciler0652` |

### Active lock selection graph

```mermaid
flowchart TD
    LockActive[lock_active] --> HasLock{lock with valid entity and position?}
    HasLock -- no --> Nil[return nil]
    HasLock -- yes --> Phase{dispatcher phase complete/return?}
    Phase -- yes --> Nil
    Phase -- no --> Mode{mode direct/acquisition/travelling/infrastructure?}
    Mode -- yes --> ReturnLock[return lock]
    Mode -- no --> Fresh{lock seen within 4 minutes?}
    Fresh -- yes --> ReturnLock
    Fresh -- no --> Nil
```

### Reconcile graph

```mermaid
flowchart TD
    Reconcile[M.reconcile_pair] --> Enabled{enabled?}
    Enabled -- no --> Disabled[disabled]
    Enabled -- yes --> Valid{valid pair?}
    Valid -- no --> Invalid[invalid-pair]
    Valid -- yes --> Active[lock_active]
    Active --> HasLock{lock?}
    HasLock -- no --> NoLock[no-active-lock]
    HasLock -- yes --> Current[current movement_request_0418]
    Current --> PairTarget[pair.target = lock.entity]
    PairTarget --> AcqTarget[pair.acquisition_target_0652 = lock.entity]
    AcqTarget --> Trace[pair.direct_target_reconciler_0652 trace]
    Trace --> Already{request points to lock and is direct?}
    Already -- yes --> Refresh[refresh current ttl]
    Refresh --> ReturnAlready[already-direct-lock-request]
    Already -- no --> Make[make_lock_request]
    Make --> Force[force_go_to]
    Force --> Record[record movement-target-reconciled-0652]
    Record --> ReturnReconciled[return reconciled]
```

### Movement wrapper graph

```mermaid
flowchart TD
    Wrap[wrap_movement_request] --> Prev[_G.tech_priests_request_movement_0418 previous]
    Prev --> New[wrapper]
    New --> Lock[lock_active]
    Lock --> HasLock{lock exists and destination not lock?}
    HasLock -- no --> CallPrev[call previous request]
    HasLock -- yes --> Reason[reason/owner text]
    Reason --> Exempt{combat/death/respawn/void?}
    Exempt -- yes --> CallPrev
    Exempt -- no --> Directish{direct-ish request?}
    Directish -- yes --> CallPrev
    Directish -- no --> Reconcile[M.reconcile_pair request-wrapper-redirect]
    Reconcile --> ReturnTrue[return true, movement_request_0418]
```

---

## 5. `movement_intent_authority_0654.lua`

### Function inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `root`, `stat`, `record` | local storage/metrics | Module storage and logs | writes module root/recent |
| `movement_root()` | local movement root | Ensures movement request storage | writes movement controller root |
| `target_entity`, `target_position` | local extractors | Read entity/position from task | none |
| `current_direct_task(pair)` | local selector | Finds current direct acquisition task | calls direct executor or scans pair fields |
| `output_item(task,cur)` | local extractor | Gets target item | none |
| `lock_truth(pair)` | local selector | Chooses direct movement truth from lock or task | reads `direct_acquisition_target_lock_0650` and task state |
| `request_points_to_truth(req,truth)` | local predicate | Checks whether request is already direct and at truth | none |
| `make_request(pair,truth)` | local builder | Builds direct acquisition intent request | none |
| `install_request(pair,truth,reason)` | local writer | Writes direct intent movement request and target fields | writes request table, `pair.target`, `current_target`, `current_work_target_0654`, trace |
| `issue_command(pair,req,reason)` | local movement | Sends Factorio go-to command | writes last command fields |
| `M.service_pair(pair,reason)` | public service | Applies truth to one pair | calls `lock_truth`, `install_request`, `issue_command` |
| `request_exempt(reason,opts)` | local predicate | Exempts combat/death/respawn/void/return movement | none |
| `destination_points_to_truth(destination,truth)` | local predicate | Checks if command target already truth | none |
| `wrap_request()` | local wrapper | Redirects movement requests away from stale targets | wraps `_G.tech_priests_request_movement_0418` |
| `wrap_route()` | local wrapper | Redirects movement controller `route_command` | wraps `TECH_PRIESTS_MOVEMENT_CONTROLLER_0418.route_command` |
| `M.service_all(reason)` | public loop | Runs wrappers and services all pairs | none beyond service |
| `M.install()` | public installer | Registers service | writes `_G.TechPriestsMovementIntentAuthority0654` |

### Truth source graph

```mermaid
flowchart TD
    LockTruth[lock_truth] --> Lock{valid direct_acquisition_target_lock_0650?}
    Lock -- yes --> Phase{phase complete/return?}
    Phase -- no --> ReturnLock[return truth source direct-lock-0650]
    Phase -- yes --> Task[current_direct_task]
    Lock -- no --> Task
    Task --> DirectKind{direct task kind?}
    DirectKind -- no --> Nil[return nil]
    DirectKind -- yes --> Entity{valid target entity and position?}
    Entity -- yes --> ReturnTask[return truth source direct-task]
    Entity -- no --> Nil
```

### Intent request graph

```mermaid
flowchart TD
    Service[M.service_pair] --> Enabled{enabled and valid pair?}
    Enabled -- no --> ExitFalse[return false]
    Enabled -- yes --> Truth[lock_truth]
    Truth --> HasTruth{truth?}
    HasTruth -- no --> ExitFalse
    HasTruth -- yes --> Install[install_request]
    Install --> Existing{old request points to truth and owner direct?}
    Existing -- yes --> Refresh[refresh ttl]
    Existing -- no --> Make[make_request direct-acquisition-intent-0654]
    Make --> MovementRoot[storage movement_controller_0419.requests key]
    Make --> PairReq[pair.movement_request_0418]
    Make --> PairTarget[pair.target/current_target/current_work_target_0654]
    Make --> Trace[pair.movement_intent_target_0654]
    Refresh --> Issue[issue_command]
    Trace --> Issue
    Issue --> ReturnChanged[return changed]
```

### Request and route wrapper graph

```mermaid
flowchart TD
    WrapReq[wrap_request] --> ReqPrev[previous _G.tech_priests_request_movement_0418]
    ReqPrev --> ReqWrapper[request wrapper]
    ReqWrapper --> TruthA[lock_truth]
    TruthA --> RedirectA{truth exists and destination disagrees and not exempt?}
    RedirectA -- yes --> InstallA[install_request request-redirect-0654]
    InstallA --> CommandA[issue_command]
    CommandA --> ReturnA[return true, req]
    RedirectA -- no --> ReqPrevCall[call previous request]

    WrapRoute[wrap_route] --> RoutePrev[previous MC.route_command]
    RoutePrev --> RouteWrapper[route wrapper]
    RouteWrapper --> FindPair[opts.pair or pairs_by_priest]
    FindPair --> TruthB[lock_truth]
    TruthB --> RedirectB{go_to command disagrees and not exempt?}
    RedirectB -- yes --> InstallB[install_request route-redirect-0654]
    InstallB --> CommandB[issue_command]
    CommandB --> ReturnTrue[return true]
    RedirectB -- no --> RoutePrevCall[call previous route]
```

---

## 6. Combined Direct Movement State Write Matrix

| State field | Writer | Meaning | Risk |
|---|---|---|---|
| `cur.entity`, `cur.target`, `cur.source`, `cur.position` | 0649 adoption, 0650 restore | Current direct task's physical target | Critical: direct executor mines whatever is here |
| `pair.target` | 0649, 0650, 0652, 0654 | Generic active target | Critical: legacy visual/movement code may read it |
| `pair.mode` | 0649, 0650 | Direct acquisition mode marker | Medium-high: used by lock/reconciler heuristics |
| `pair.dispatcher_direct_0513` | 0649, 0650 | Direct executor phase/detail trace | High: lock activity depends on phase |
| `pair.direct_acquisition_target_lock_0650` | 0650 | Locked physical target entity/position/item | Critical: 0652/0654/0655 read it |
| `pair.movement_request_0418` | 0652, 0654 | Active movement target | Critical: vector enforcer obeys it |
| `storage.tech_priests.movement_controller_0419.requests[key]` | 0652, 0654 | Backing movement request table | Critical: stale table causes wrong movement |
| `pair.acquisition_target_0652` | 0652 | Reconciler trace target | Medium: diagnostic/target trace |
| `pair.movement_intent_target_0654` | 0654 | Intent trace target | Medium: diagnostic/intent trace |
| `pair.direct_acquisition_force_move_0650` | 0650 | Forced movement throttle/trace | Medium: can suppress repeated commands |

---

## 7. Direct Movement Debugging Decision Tree

```mermaid
flowchart TD
    Problem[Priest says acquiring resource but moves wrong] --> Task{current direct task exists?}
    Task -- no --> ParentBug[Bug is upstream parent scheduler / emergency decomposition]
    Task -- yes --> CurTarget{cur.entity/target/source valid?}
    CurTarget -- no --> Guard[Check 0649 physical guard adoption]
    Guard --> Adopted{physical-target-adopted-0649 event?}
    Adopted -- no --> NoPhysical[No physical target near planned position / task should clear]
    Adopted -- yes --> LockCheck
    CurTarget -- yes --> Match{entity matches requested item?}
    Match -- no --> GuardMismatch[0649 should clear mismatch]
    Match -- yes --> LockCheck{direct_acquisition_target_lock_0650 valid?}
    LockCheck -- no --> LockBug[Check 0650 lock_current_target / dispatcher phase]
    LockCheck -- yes --> ReqCheck{movement_request_0418 points to lock?}
    ReqCheck -- no --> Reconciler[Check 0652 and 0654 wrappers]
    ReqCheck -- yes --> LeafCheck{active_leaf_task_0655 says Mining actual item?}
    LeafCheck -- no --> LeafBug[Check active_leaf_task_truth_0655 direct_truth]
    LeafCheck -- yes --> Vector{vector enforcer correcting toward request?}
    Vector -- no --> VectorBug[Check movement_vector_enforcer_0651]
    Vector -- yes --> Executor{At target but not mining?}
    Executor -- yes --> DirectExecutorBug[Map/fix direct_acquisition_executor_0513 next]
    Executor -- no --> Observe[Continue observing]
```

---

## 8. Remaining Direct-Acquisition Drilldown Needed

This pass maps the repair stack, not the base direct acquisition executor. The next direct-acquisition pass must map:

- `direct_acquisition_executor_0513.lua`
- how it chooses current tasks
- how it decides walking vs working
- how it mines/collects from the target
- how it deposits to station
- how it marks parent tasks complete
- how it names `output_item`, `item_name`, `wanted_item`, and `requested_item`

Until that executor is mapped, we have verified the target/movement repair layers but not the actual mining/action completion loop.
