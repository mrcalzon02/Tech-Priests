# Tech-Priests Function-Level Mermaid Drilldown: Movement Controller

Version: 0.1.664-map-pass-5  
Previous drilldown: `docs/BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_0663_DIRECT_EXECUTOR.md`  
Companion overview: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

Purpose: map the core ground movement controller. This file is the movement request store, command issuer, legacy command router, clamp manager, speed/snap sampler, combat-positioning adapter, and remaining movement diagnostic command surface.

Mapped module:

- `movement_controller.lua`

Important finding:

- This module was designed around the doctrine that one module owns ground-priest go-to-location commands, while other systems submit movement intent.
- It still contains `M.commands()` and registers `/tp-movement-0429`, so this remains a command cleanup target.
- Its retarget-hold logic can preserve an existing request unless a later authority writes directly into `pair.movement_request_0418` and the movement-controller request table. This is why the later 0652/0654/0655/0656 layers overwrite both places.

---

## 1. Movement Controller Doctrine

The header states the design doctrine:

```mermaid
flowchart TD
    Doctrine[Movement Controller Doctrine]
    Doctrine --> OneOwner[One module owns ground go_to_location commands]
    Doctrine --> Intent[Other systems submit movement intent]
    Doctrine --> Clamps[Conversation mining crafting stabilisation are clamp bands]
    Doctrine --> GroundOnly[Ground controller only; space-platform hover/pathing excluded]

    Intent --> Request[M.request]
    Request --> Store[store movement request]
    Store --> Service[M.service]
    Service --> Apply[apply_request]
    Apply --> Command[direct_go_to or direct_stop]
```

---

## 2. Function Inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `now`, `valid`, `metric`, `dist_sq` | local helpers | Time/entity/metrics/distance | may call `_G.tech_priests_runtime_metric_0606` |
| `ensure_root()` | local storage root | Ensures movement controller storage | writes `storage.tech_priests.movement_controller_0419` |
| `pairs_by_station()` | local accessor | Reads station pair map | reads storage |
| `pair_by_request_key(key)` | local resolver | Converts request key to pair | reads pairs by station/priest |
| `note_active_request(root,key,pair)` | local marker | Marks active request and bucket priority | writes `root.active_request_ids`; may call bucket registry |
| `clear_active_request(root,key)` | local marker | Clears active request id | writes `root.active_request_ids` |
| `count_table(t)` | local helper | Counts table keys | none |
| `pair_key(pair)` | local key builder | station unit or priest unit fallback | none |
| `selected_pair(player)` | local command helper | Finds selected station/priest pair | reads selection and globals |
| `pair_for_priest(priest)` | local resolver | Finds pair by priest entity | reads storage/global finder |
| `is_space_pair(pair)` | local predicate | Detects platform/space pair | calls `_G.tech_priests_pair_on_space_platform_0204` |
| `direct_stop(priest)` | local command | Stops priest command/walking state | calls commandable/set_command and walking_state |
| `direct_go_to(priest,pos,radius,distraction)` | local command | Issues Factorio go_to_location | calls commandable/set_command |
| `current_work_position(pair)` | local extractor | Reads emergency craft current work target | none |
| `conversation_locked(pair)` | local clamp predicate | Checks idle conversation fields | none |
| `work_clamped(pair)` | local clamp predicate | Checks mining/craft locks and close direct work target | reads work/task fields |
| `clamp_reason(pair)` | local clamp selector | Computes active clamp reason | clears stale movement lockdown fields |
| `M.request(pair,destination,reason,opts)` | public request writer | Submits movement intent | writes `root.requests[key]`, `pair.movement_request_0418`, owner/reason fields |
| `M.request_status(pair,owner)` | public status | Returns status for active request | writes `pair.movement_controller_status_0418` |
| `M.combat_intent(pair,target,reason,opts)` | public combat movement adapter | Positions priest near combat target or stops in range | writes `pair.combat_target`, `pair.target`, combat intent trace, mode |
| `M.stop(pair,reason)` | public stop | Clears request and stops priest | writes movement request/state reason; calls direct_stop |
| `apply_request(pair,req)` | local service helper | Applies stored request to engine command or stop/loiter | writes last distance, state, clamp, last command |
| `M.service(event,budget)` | public service loop | Services active request ids only | prunes invalid/expired/empty requests; calls apply_request |
| `M.sample(event,budget)` | public sampler | Samples active request pairs for huge visual snap/high-speed audit | writes samples, last snap, clears stale request on huge jumps |
| `destination_from_entity_or_position(target)` | local adapter | Converts entity/position target | none |
| `M.route_command(priest,command,owner,opts)` | public command router | Converts legacy go_to/attack/stop commands into movement requests | writes movement/combat state through request/combat/stop |
| `M.patch_globals()` | public wrapper installer | Exposes globals and wraps legacy commands | writes multiple `_G.*` movement functions |
| `M.commands()` | public command installer | Registers `/tp-movement-0429` diagnostic | command surface remains |
| `M.report_lines()` | public diagnostics | Runtime report summary | none |
| `M.install()` | public installer | Patches globals, installs command, registers broker services | writes globals and services |

---

## 3. Storage Root and Active Request Registry

```mermaid
flowchart TD
    Root[ensure_root] --> Storage[storage.tech_priests.movement_controller_0419]
    Storage --> Stats[root.stats]
    Storage --> Samples[root.samples]
    Storage --> Requests[root.requests]
    Storage --> Active[root.active_request_ids]
    Root --> Migrate{_active_request_ids_migrated_0611?}
    Migrate -- no --> Copy[for each root.requests key set active_request_ids key true]
    Copy --> MarkMigrated[root._active_request_ids_migrated_0611 = true]
    Migrate -- yes --> Return[root]
    MarkMigrated --> Return

    Note[note_active_request] --> ActiveSet[root.active_request_ids key = true]
    Note --> Bucket[PairBucketRegistry.force_bucket movement]
    Clear[clear_active_request] --> ActiveNil[root.active_request_ids key = nil]
```

The active request table is important because `M.service` and `M.sample` iterate active ids, not all pairs.

---

## 4. Clamp Reason Chain

```mermaid
flowchart TD
    Clamp[clamp_reason] --> Valid{pair valid?}
    Valid -- no --> Invalid[return invalid]
    Valid -- yes --> Space{space pair?}
    Space -- yes --> None[return nil]
    Space -- no --> Stabilize{movement_stabilize_until active?}
    Stabilize -- yes --> Stabilizing[return movement-stabilizing]
    Stabilize -- no --> ClearLegacy[clear stale movement_lockdown_until_0416/reason]
    ClearLegacy --> Conversation{conversation_locked?}
    Conversation -- yes --> Conv[return conversation]
    Conversation -- no --> Work[work_clamped]
    Work --> IsWork{clamped?}
    IsWork -- yes --> WorkReason[return mining/craft/work reason]
    IsWork -- no --> None
```

### Work clamp detail

```mermaid
flowchart TD
    Work[work_clamped] --> Mining{pair.mining_lock_0315?}
    Mining -- yes --> MiningLock[return mining-lock]
    Mining -- no --> StationCraft{pair.station_craft_lock_0337?}
    StationCraft -- yes --> StationCraftLock[return station-craft-lock]
    StationCraft -- no --> Crafting{pair.crafting_lock_0418?}
    Crafting -- yes --> CraftingLock[return crafting-lock]
    Crafting -- no --> CurrentWork[current_work_position]
    CurrentWork --> Close{close to direct work target?}
    Close -- yes --> Observed[return false close-to-work-target-observed]
    Close -- no --> NoClamp[return false]
```

Note: direct work target proximity intentionally avoids clamping here; the direct acquisition executor owns the work clamp through `stop_for_work`.

---

## 5. `M.request` Retarget / Priority Flow

```mermaid
flowchart TD
    Request[M.request] --> Valid{pair priest destination valid?}
    Valid -- no --> False[return false]
    Valid -- yes --> Space{space pair and not forced ground?}
    Space -- yes --> DirectGo[direct_go_to immediate]
    Space -- no --> Root[ensure_root]
    Root --> Key[pair_key]
    Key --> HasKey{key?}
    HasKey -- no --> False
    HasKey -- yes --> Current[root.requests key]
    Current --> Transition{TaskTransition locked and priority < 800 and current alive?}
    Transition -- yes --> HoldTransition[hold current request; state task-transition-retarget-held]
    Transition -- no --> CurrentAlive{current request alive?}

    CurrentAlive -- yes --> SameTarget{new target near current and current priority >= new priority?}
    SameTarget -- yes --> Collapse[collapse request; refresh reason/tick]
    Collapse --> Note[note_active_request]
    Note --> ReturnTrue[return true]

    SameTarget -- no --> FreshLow{age < retarget_hold_ticks and priority <= current_priority + 10?}
    FreshLow -- yes --> Suppress[store suppressed target; state retarget-held]
    Suppress --> Note2[note_active_request]
    Note2 --> ReturnTrue

    CurrentAlive -- no --> NewReq[build req]
    FreshLow -- no --> NewReq
    NewReq --> Store[root.requests key = req]
    Store --> Active[note_active_request]
    Active --> PairReq[pair.movement_request_0418 = req]
    PairReq --> Owner[pair.movement_controller_owner/reason_0418]
    Owner --> ReturnReq[return true, req]
```

Key audit point: this retarget logic can preserve a stale request unless a higher-priority authority bypasses it or writes both `pair.movement_request_0418` and `root.requests[key]` directly. That is why the 0652/0654/0655/0656 repair layers update both fields.

---

## 6. Request Status Flow

```mermaid
flowchart TD
    Status[M.request_status] --> Valid{valid pair?}
    Valid -- no --> Invalid[status invalid-pair]
    Valid -- yes --> Req[request from root.requests or pair.movement_request_0418]
    Req --> HasReq{request exists?}
    HasReq -- no --> Missing[status missing-request + clamp_reason]
    HasReq -- yes --> Owner{expected owner matches?}
    Owner -- no --> Replaced[status replaced-by-other-owner]
    Owner -- yes --> Expired{request expired?}
    Expired -- yes --> ExpiredStatus[status expired]
    Expired -- no --> Distance[distance to request]
    Distance --> Arrived{inside radius + loiter pad?}
    Arrived -- yes --> ArrivedStatus[status arrived]
    Arrived -- no --> Clamp[clamp_reason]
    Clamp --> Clamped{clamp exists?}
    Clamped -- yes --> ClampedStatus[status clamped]
    Clamped -- no --> Active[status active]
```

This is diagnostic/status only; it does not prune the request.

---

## 7. Combat Intent Flow

```mermaid
flowchart TD
    Combat[M.combat_intent] --> Valid{valid pair/priest/target and ground pair?}
    Valid -- no --> False[return false]
    Valid -- yes --> Range[compute fire range and approach radius]
    Range --> Trace[pair.combat_target / pair.target / combat trace]
    Trace --> Far{distance > fire_range?}
    Far -- yes --> Move[pair.mode = moving-to-combat]
    Move --> Request[M.request owner combat-intent priority 85]
    Far -- no --> Defend[pair.mode = defending]
    Defend --> Stop[M.stop combat-in-range-proxy-owns-damage]
```

Combat does not issue attack commands through the ground priest. Proxy turret damage owns damage; movement controller owns positioning.

---

## 8. Stop and Apply Request Flow

```mermaid
flowchart TD
    Stop[M.stop] --> Valid{valid pair/priest?}
    Valid -- no --> False[return false]
    Valid -- yes --> Root[ensure_root]
    Root --> Key[pair_key]
    Key --> ClearReq[root.requests key nil + active id clear]
    ClearReq --> PairNil[pair.movement_request_0418 = nil]
    PairNil --> Reason[pair.movement_controller_reason_0418 = reason]
    Reason --> DirectStop[direct_stop]

    Apply[apply_request] --> Valid2{valid pair/priest/request?}
    Valid2 -- no --> False2[return false]
    Valid2 -- yes --> Clamp[clamp_reason]
    Clamp --> HasClamp{clamped?}
    HasClamp -- yes --> StopPriest[set clamp; direct_stop; return false]
    HasClamp -- no --> ClearClamp[pair.movement_controller_clamp_0418 = nil]
    ClearClamp --> Distance[distance to request]
    Distance --> Arrived{inside radius + loiter pad?}
    Arrived -- yes --> Loiter[state loitering; direct_stop; return true]
    Arrived -- no --> Refresh{command refresh elapsed?}
    Refresh -- no --> False3[return false]
    Refresh -- yes --> Go[direct_go_to]
    Go --> GoOK{ok?}
    GoOK -- yes --> Moving[state moving; last command trace; stats commands]
    GoOK -- no --> False3
```

---

## 9. Service Loop Flow

```mermaid
flowchart TD
    Service[M.service] --> Root[ensure_root]
    Root --> Active[root.active_request_ids]
    Active --> Loop[for key in active ids]
    Loop --> Budget{processed >= budget?}
    Budget -- yes --> BudgetExhausted[return budget-exhausted]
    Budget -- no --> Pair[pair_by_request_key]
    Pair --> Req[root.requests key or pair.movement_request_0418]
    Req --> ValidPair{valid pair/priest/station and not space?}
    ValidPair -- no --> PruneInvalid[remove request + active id; invalid_request_pruned]
    ValidPair -- yes --> Expired{req expired?}
    Expired -- yes --> PruneExpired[remove request + active id + pair request nil]
    Expired -- no --> HasReq{req exists?}
    HasReq -- yes --> Apply[apply_request]
    Apply --> Acted{true?}
    Acted -- yes --> IncActed[acted += 1]
    Acted -- no --> Next[next key]
    HasReq -- no --> PruneEmpty[clear active id; empty_request_pruned]
    PruneInvalid --> Next
    PruneExpired --> Next
    IncActed --> Next
    PruneEmpty --> Next
    Next --> Done{loop done?}
    Done -- yes --> Return[return acted or empty]
```

---

## 10. Snap / Speed Sample Flow

```mermaid
flowchart TD
    Sample[M.sample] --> Root[ensure_root]
    Root --> Active[root.active_request_ids]
    Active --> Loop[for active key]
    Loop --> Budget{processed >= budget?}
    Budget -- yes --> BudgetExhausted[return budget-exhausted]
    Budget -- no --> Pair[pair_by_request_key]
    Pair --> Valid{valid ground pair?}
    Valid -- no --> Clear[clear active request id]
    Valid -- yes --> Prev[root.samples key]
    Prev --> HasPrev{previous sample same surface/priest?}
    HasPrev -- no --> Store[store current sample]
    HasPrev -- yes --> Delta[compute d2, dt, allowed step]
    Delta --> Huge{dt <= 90 and d2 > max 36 or allowed_sq?}
    Huge -- yes --> RecordSnap[record last_snap and pair.last_ground_snap_0418]
    RecordSnap --> Stabilize[pair.movement_stabilize_until_0418 = now + stabilize_ticks]
    Stabilize --> ClearReq[root.requests key nil; active id clear; pair request nil]
    ClearReq --> State[pair.movement_controller_state = speed-governed]
    State --> Store
    Huge -- no --> Store
    Store --> Next[next key]
```

This no longer teleports the priest backwards; it records the jump, clears the stale request, and lets behavior resubmit a sane route.

---

## 11. Legacy Command Routing Flow

```mermaid
flowchart TD
    Route[M.route_command] --> Valid{valid priest and command?}
    Valid -- no --> Invalid[return false]
    Valid -- yes --> Pair[pair from opts or pair_for_priest]
    Pair --> Ground{ground pair?}
    Ground -- yes --> Type{command type}
    Type -- go_to_location --> Req[M.request destination owner legacy]
    Type -- attack --> Combat[M.combat_intent]
    Type -- stop --> Stop[M.stop]
    Ground -- no --> Fallback[direct engine command fallback]
    Type -- other --> Fallback
```

The route command is the bridge that turns older direct engine command calls into movement-controller requests.

---

## 12. Global Patch Surface

```mermaid
flowchart TD
    Patch[M.patch_globals] --> GlobalController[_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418 = M]
    Patch --> RequestGlobal[_G.tech_priests_request_movement_0418 -> M.request]
    Patch --> StopGlobal[_G.tech_priests_stop_movement_0418 -> M.stop]
    Patch --> StatusGlobal[_G.tech_priests_movement_status_0418 -> M.request_status]
    Patch --> RouteGlobal[_G.tech_priests_route_ground_command_0429 -> M.route_command]

    Patch --> Issue{_G.issue_priest_command exists?}
    Issue -- yes --> WrapIssue[wrap go_to/attack/stop through route_command]
    Patch --> Move{_G.move_priest_to exists?}
    Move -- yes --> WrapMove[wrap into M.request move-priest-to]
    Patch --> Return{_G.return_to_station exists?}
    Return -- yes --> WrapReturn[wrap into M.request return-to-station]
    Patch --> Proxy0292{proxy attack 0292 exists?}
    Proxy0292 -- yes --> WrapProxy292[after proxy attack, call combat_intent]
    Patch --> Proxy0293{proxy attack 0293 exists?}
    Proxy0293 -- yes --> WrapProxy293[after proxy attack, call combat_intent]
```

Risk: because this file installs global wrappers, later movement repair modules that also wrap `_G.tech_priests_request_movement_0418` and `M.route_command` must preserve wrapper ordering.

---

## 13. Diagnostic Command Surface

```mermaid
flowchart TD
    Commands[M.commands] --> RemoveOld[remove tp-movement-0418/0419/0429]
    RemoveOld --> Add[add tp-movement-0429]
    Add --> Selected[selected_pair]
    Selected --> HasPair{pair selected?}
    HasPair -- no --> PrintStats[print root stats]
    HasPair -- yes --> PrintPair[print mode/state/clamp/station/priest]
    PrintPair --> PrintReq[print movement_request_0418]
    PrintReq --> Status[M.request_status]
    Status --> PrintStatus[print request status]
    PrintStatus --> PrintSnap[print last snap]
    PrintSnap --> PrintStats2[print stats]
```

Cleanup note: this command still exists and should be removed if commandless runtime remains the project standard.

---

## 14. Install Flow

```mermaid
flowchart TD
    Install[M.install] --> Root[ensure_root]
    Root --> Patch[M.patch_globals]
    Patch --> Commands[M.commands]
    Commands --> Broker{runtime tick broker exists?}
    Broker -- yes --> ServiceReg[register movement_controller_service_0611]
    Broker -- yes --> SampleReg[register movement_controller_sample_0611]
    Broker -- no --> Registry{runtime event registry exists?}
    Registry -- yes --> NthService[on_nth_tick service]
    Registry -- yes --> NthSample[on_nth_tick sample]
    Registry -- no --> Script[script.on_nth_tick service/sample]
```

---

## 15. Movement State Write Matrix

| State field | Writer | Meaning | Risk |
|---|---|---|---|
| `storage.tech_priests.movement_controller_0419.requests[key]` | `M.request`, `M.stop`, `M.service`, `M.sample`, late authority modules | Backing active movement request | Critical |
| `storage.tech_priests.movement_controller_0419.active_request_ids[key]` | `note_active_request`, `clear_active_request`, `M.service`, `M.sample` | Service loop registry | High |
| `pair.movement_request_0418` | `M.request`, `M.stop`, `M.service`, `M.sample`, late authority modules | Pair-facing request | Critical |
| `pair.movement_controller_owner_0418` | `M.request`, late authority modules | Request owner | High |
| `pair.movement_controller_reason_0418` | `M.request`, `M.stop`, route wrappers | Request reason | High |
| `pair.movement_controller_state_0418` | `M.request`, `apply_request`, `M.sample`, late authority modules | Moving/loiter/held/clamped/speed-governed state | High |
| `pair.movement_controller_clamp_0418` | `M.request`, `apply_request`, `clamp_reason`, `M.sample` | Current clamp/reason | High |
| `pair.movement_controller_status_0418` | `M.request_status` | Diagnostic status | Medium |
| `pair.movement_controller_last_command_0418` | `apply_request`, late authority modules | Last engine command trace | Medium |
| `pair.combat_target` | `M.combat_intent` | Active combat target | High during combat |
| `pair.target` | `M.combat_intent`, legacy wrappers, other modules | Generic current target | Critical due legacy readers |
| `pair.movement_stabilize_until_0418` | `M.sample` | Post-snap stabilization clamp | Medium-high; stale value can briefly clamp |
| `pair.last_ground_snap_0418` | `M.sample` | Snap audit record | Diagnostic |

---

## 16. Request Failure / Exit Matrix

| Exit/status | Trigger | State change | Expected next behavior |
|---|---|---|---|
| `M.request false` | invalid pair/destination/key | none | caller should fail or fallback |
| `task-transition-retarget-held` | task transition lock + low priority + active current request | preserves current request | higher-priority authority may override |
| `request_collapsed` | new target very close and lower/equal priority | refreshes current request | movement continues same target |
| `retarget-held` | request too fresh and lower/equal priority | suppresses target | movement continues older target |
| `request_status missing-request` | no request | status only | scheduler may submit request |
| `request_status replaced-by-other-owner` | owner mismatch | status inactive | caller should stop claiming movement |
| `request_status expired` | expired request | status inactive | service will prune on tick |
| `request_status arrived` | within radius + loiter pad | status arrived | executor should perform work |
| `request_status clamped` | clamp reason exists | status clamped | wait for clamp release |
| `apply_request false clamped` | clamp reason exists | direct_stop called | movement paused |
| `apply_request true loitering` | within radius | direct_stop called | executor should act |
| `M.service budget-exhausted` | active ids exceed budget | partial processing | next tick continues |
| `M.service empty` | no active processed | none | idle |
| `M.sample speed-governed` | huge displacement sample | clears request and stabilizes | scheduler must repath |

---

## 17. Movement Debugging Decision Tree

```mermaid
flowchart TD
    Problem[Movement problem] --> Req{pair.movement_request_0418 exists?}
    Req -- no --> Scheduler[Upstream scheduler/leaf task failed to request movement]
    Req -- yes --> Backing{root.requests key matches pair request?}
    Backing -- no --> BackingBug[Late authority or movement controller table mismatch]
    Backing -- yes --> Owner{owner/reason expected?}
    Owner -- no --> WrongOwner[Find stale writer / wrapper order]
    Owner -- yes --> Status[M.request_status]
    Status --> Arrived{arrived?}
    Arrived -- yes --> Executor[Executor should act at target]
    Arrived -- no --> Clamped{clamped?}
    Clamped -- yes --> ClampBug[Inspect clamp_reason: conversation craft mining stabilize]
    Clamped -- no --> Service{M.service issuing commands?}
    Service -- no --> ActiveId{active_request_ids contains key?}
    ActiveId -- no --> ActiveBug[note_active_request missing]
    ActiveId -- yes --> BudgetOrCooldown[budget/command_refresh not elapsed]
    Service -- yes --> Walking{priest walking toward request?}
    Walking -- no --> Vector[Check movement_vector_enforcer_0651 and Factorio pathing]
    Walking -- yes --> Observe[Wait / inspect executor exit]
```

---

## 18. Cleanup Targets

1. Remove `/tp-movement-0429` command block if commandless runtime remains the standard.
2. Review retarget-hold interaction with high-priority leaf truth authorities. It may be safe only because later modules overwrite both pair and backing request tables.
3. Reduce wrapper layering once `active_leaf_task_truth_0655` has proven stable.
4. Audit any module still calling `commandable.set_command` directly instead of `M.request` or `M.route_command`, except explicit fallback layers.
5. Confirm stale `movement_controller_clamp_0418` values are not mistaken for active clamps; true clamp must come from `clamp_reason`.
6. Confirm active request ids are always written when late authority modules install requests directly into backing tables.
7. Review speed-governed request clearing against vector enforcement so a huge displacement does not create a silent idle state.
