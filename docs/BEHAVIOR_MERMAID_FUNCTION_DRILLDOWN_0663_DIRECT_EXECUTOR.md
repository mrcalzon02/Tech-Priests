# Tech-Priests Function-Level Mermaid Drilldown: Direct Acquisition Executor 0513

Version: 0.1.663-map-pass-4  
Previous drilldown: `docs/BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_0662_DIRECT_MOVEMENT.md`  
Companion overview: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

Purpose: map the base direct-acquisition executor itself. The previous pass mapped the repair layers that force the direct target and movement request to agree. This pass maps the executor that actually decides whether the priest walks, works, damages/mines the target, deposits the output, returns for crafting, or completes.

Mapped module:

- `direct_acquisition_executor_0513.lua`

Important finding:

- This executor still contains `install_command()` for `/tp-direct-acquisition-0513`. This document maps it as existing behavior/control surface. Cleanup can remove it in a later code pass.

---

## 1. Module Purpose and High-Level Phase Machine

The file describes itself as a dispatcher-owned phase machine:

> choose/adopt target -> walk to target -> work over time -> deposit -> return or yield to station craft

```mermaid
flowchart TD
    Task[Current direct task exists] --> Validate[Validate target entity / position / bounds]
    Validate --> Far{Priest far from target?}
    Far -- yes --> Travel[Phase: walk-to-target]
    Travel --> RequestMove[request_movement]
    RequestMove --> TravelHold[hold/repath until adjacent]
    TravelHold --> Far

    Far -- no --> Clamp[stop_for_work]
    Clamp --> WorkStart{direct_due_tick_0513 exists?}
    WorkStart -- no --> BeginWork[set due tick + started tick]
    WorkStart -- yes --> WorkLoop
    BeginWork --> WorkLoop[Phase: work-target]
    WorkLoop --> Due{work due reached?}
    Due -- no --> VisualHit[mine_hit non-final + extracting status]
    VisualHit --> WorkLoop
    Due -- yes --> FinalHit[mine_hit final]
    FinalHit --> Deposit[deposit item to station]
    Deposit --> DepositOK{deposit ok?}
    DepositOK -- no --> DepositBlocked[Phase: deposit-blocked]
    DepositOK -- yes --> Count[task.gathered_units += 1]
    Count --> Enough{gathered required units?}
    Enough -- no --> Continue[continue work-target]
    Enough -- yes --> CraftNeeded{task.recipe and task.output_item?}
    CraftNeeded -- yes --> ReturnCraft[Phase: return-for-craft]
    CraftNeeded -- no --> Complete[Phase: complete]
    ReturnCraft --> ReturnStation[return_to_station]
    Complete --> ReturnStation
```

---

## 2. Function Inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `now`, `valid`, `safe`, `lower`, `unit`, `station_unit`, `priest_unit`, `pair_map`, `valid_pair`, `dist_sq`, `dist` | local helpers | Time/entity/string/distance/pair helpers | none |
| `item_exists(name)` | local prototype helper | Checks item prototype existence | reads `prototypes.item` |
| `M.root()` | public storage root | Ensures direct acquisition executor state | writes `storage.tech_priests.direct_acquisition_executor_0513` |
| `stat(name,n)` | local metric | Increments counters | writes root stats |
| `record(action,pair,detail,force)` | local metric/log | Stores recent events and throttled log lines | writes root recent/last_log |
| `current_direct_task(pair)` / `M.current_direct_task` | public/local selector | Finds current direct task from `emergency_craft`, `direct_acquisition_task_0336`, `active_acquisition_0333` | none |
| `target_entity(cur)` | local extractor | Reads `cur.entity`, `cur.target`, or `cur.source` | none |
| `target_position(pair,cur)` | local extractor | Uses target entity, current position, or `pair.target` | none |
| `target_label(cur)` | local formatter | Builds diagnostic target label | none |
| `output_item(task,cur)` | local resolver | Determines item produced by current target/task | may infer resource from entity name/type |
| `required_units(task)` | local resolver | Determines how many units must be gathered | none |
| `clear_direct_due(task)` | local cleanup | Clears old direct timers | writes task direct timer fields |
| `set_phase(pair,phase,detail)` | local state writer | Updates direct dispatcher phase | writes `pair.dispatcher_action`, `pair.dispatcher_phase`, `pair.dispatcher_direct_0513` |
| `show(pair,text,target,opts)` | local visual/status helper | Emits status and optional scan line | calls `_G.tech_priests_draw_emergency_operation_status_0184`, `_G.draw_emergency_craft_scan_line` |
| `deposit(pair,item,count)` | local deposit | Deposits gathered item into station | uses `_G.tech_priests_safe_deposit_item` or station inventory fallback |
| `mine_visual(pair,cur,final)` | local visual helper | Draws mining line/smoke | calls scan/smoke globals or surface smoke |
| `mine_hit(pair,cur,final)` | local work helper | Applies mining/damage effect | reduces resource amount or damages entity |
| `stop_for_work(pair,reason)` | local movement clamp | Stops movement before work phase | clears movement request/lease; issues stop command |
| `request_movement(pair,pos,reason)` | local movement writer | Requests movement to direct target | writes mode/target/reason; calls movement request or ground route/fallback command |
| `return_to_station(pair,reason)` | local movement writer | Requests return movement to station | writes mode/target/phase; calls movement request or route/fallback command |
| `within_bounds(pair,pos)` | local boundary check | Uses movement bounds authority if present | calls `TechPriestsMovementBounds0511.target_within_bounds` |
| `M.service_pair(pair,reason)` | public executor | Main phase machine | validates, walks, works, deposits, returns, clears tasks |
| `M.service_all(reason)` | public loop | Services all pairs with current direct task | calls `M.service_pair` |
| `should_block_legacy(pair)` | local guard | Determines whether older direct controllers should be blocked | reads dispatcher/direct state |
| `wrap_acquisition_executor()` | local wrapper | Wraps older `acquisition_executor` service | replaces `Exec.service_pair` with 0513 service when enabled |
| `wrap_legacy_direct_functions()` | local wrapper | Blocks old global direct functions | wraps `_G.tech_priests_0273/0312/0315_service_direct_current` |
| `selected_pair(player)` | local command helper | Finds selected pair for command diagnostics | reads selection/pair maps |
| `install_command()` | local command installer | Installs `/tp-direct-acquisition-0513` | registers slash command; remaining cleanup target |
| `wrap_pair_dump()` | local diagnostics wrapper | Adds direct 0513 info to pair dump | patches diagnostic `pair_dump_lines` |
| `M.install()` | public installer | Installs wrappers/diagnostics/command and exposes module | writes `_G.TechPriestsDirectAcquisitionExecutor0513` |

---

## 3. Current Task Selection

```mermaid
flowchart TD
    Current[current_direct_task] --> Emergency[pair.emergency_craft]
    Emergency --> Cur1{task.current or task has direct kind?}
    Cur1 -- yes --> Return1[return task, cur, emergency_craft]
    Cur1 -- no --> Direct0336[pair.direct_acquisition_task_0336]
    Direct0336 --> Cur2{task.current or task has direct kind?}
    Cur2 -- yes --> Return2[return task, cur, direct_acquisition_task_0336]
    Cur2 -- no --> Active0333[pair.active_acquisition_0333]
    Active0333 --> Cur3{task.current or task has direct kind?}
    Cur3 -- yes --> Return3[return task, cur, active_acquisition_0333]
    Cur3 -- no --> None[return nil]
```

Direct kinds currently accepted:

- `direct-mine-0273`
- `direct-dirt-0273`
- `dirt`
- `direct-mine-0336`

---

## 4. Output Item Resolution

```mermaid
flowchart TD
    Output[output_item] --> CurItem{cur output/item/wanted/requested item exists?}
    CurItem -- yes --> CurExists{item prototype exists?}
    CurExists -- yes --> ReturnCur[return cur item]
    CurExists -- no --> TaskItem{task output/item/wanted/requested item exists?}
    CurItem -- no --> TaskItem
    TaskItem -- yes --> TaskExists{item prototype exists?}
    TaskExists -- yes --> ReturnTask[return task item]
    TaskExists -- no --> Entity[target_entity]
    TaskItem -- no --> Entity
    Entity --> Resource{entity.type == resource and item exists?}
    Resource -- yes --> ReturnResource[return entity.name]
    Resource -- no --> NameHeuristic[tree/rock/stone/coal/iron/copper name inference]
    NameHeuristic --> Inferred{inferred item exists?}
    Inferred -- yes --> ReturnInferred[return inferred item]
    Inferred -- no --> StoneFallback{stone exists?}
    StoneFallback -- yes --> ReturnStone[return stone]
    StoneFallback -- no --> Nil[return nil]
```

Risk: the stone fallback can hide bad task naming. If a direct task has no valid item and no useful entity inference, it may silently become stone.

---

## 5. Movement and Work Clamp Helpers

```mermaid
flowchart TD
    Request[request_movement] --> Valid{valid pair and pos?}
    Valid -- no --> False[return false]
    Valid -- yes --> Mode[pair.mode = travelling-to-direct-acquisition]
    Mode --> Target[pair.target = target_entity current task]
    Target --> Claim[action_claim movement direct_acquisition_executor_0513]
    Claim --> HasRequest{_G.tech_priests_request_movement_0418 exists?}
    HasRequest -- yes --> Request0418[call movement request radius .75 owner direct-acquisition-0513 priority 650]
    HasRequest -- no --> GroundRoute{_G.tech_priests_route_ground_command_0429 exists?}
    GroundRoute -- yes --> Route[route ground command]
    GroundRoute -- no --> DirectCommand[commandable.set_command go_to_location]
    Request0418 --> ReturnOK[return ok]
    Route --> ReturnOK
    DirectCommand --> ReturnOK

    Stop[stop_for_work] --> ClearReq[pair.movement_request_0418 = nil]
    Stop --> ClearPath[pair.pathing_target_0418 = nil]
    Stop --> Clamp[pair.movement_controller_state_0418 = work-clamped]
    Stop --> ClearLease[clear movement lease or pair.movement_lease_0518 = nil]
    Stop --> StopCommand[stop movement through helper or command stop]
```

Movement repair modules added later intercept the `request_movement` call path by wrapping `_G.tech_priests_request_movement_0418` and movement controller routing.

---

## 6. Main `M.service_pair` Phase Machine

```mermaid
flowchart TD
    Service[M.service_pair] --> Enabled{root enabled?}
    Enabled -- no --> Disabled[return disabled]
    Enabled -- yes --> Valid{valid pair?}
    Valid -- no --> Invalid[return invalid-pair]
    Valid -- yes --> Current[current_direct_task]
    Current --> HasTask{task and cur?}
    HasTask -- no --> None[set phase none; return no-direct-task]
    HasTask -- yes --> Claim[action_claim direct-acquisition]
    Claim --> State[initialize dispatcher_direct_0513 item/target/reason]

    State --> EntityInvalid{cur.entity exists but invalid?}
    EntityInvalid -- yes --> Replan[clear_due; task.current=nil; pair.target=nil; mode=replan; phase target-invalid]
    Replan --> ReturnInvalid[return target-invalid]
    EntityInvalid -- no --> Position[target_position]
    Position --> HasPos{position?}
    HasPos -- no --> NeedTarget[clear_due; task.current=nil; pair.target=nil; phase need-target]
    NeedTarget --> ReturnNoPos[return no-target-position]
    HasPos -- yes --> Bounds[within_bounds]
    Bounds --> Inside{inside?}
    Inside -- no --> Reject[clear_due; task.current=nil; pair.target=nil; mode target-rejected; phase target-rejected]
    Reject --> ReturnReject[return target-out-of-bounds]

    Inside -- yes --> Distance[distance priest to target]
    Distance --> Far{d2 > close_distance_sq?}
    Far -- yes --> Travel[travel branch]
    Far -- no --> Work[work branch]
```

---

## 7. Travel Branch

```mermaid
flowchart TD
    Travel[travel branch] --> ClearDue[clear_direct_due]
    ClearDue --> Progress[compare distance to last_distance]
    Progress --> MadeProgress{made progress?}
    MadeProgress -- yes --> LastProgress[state.last_progress_tick = now]
    MadeProgress -- no --> CheckStall[check stall_ticks]
    LastProgress --> Refresh
    CheckStall --> Refresh[stale or stalled?]
    Refresh --> NeedMove{stale or stalled?}
    NeedMove -- no --> Held[stat travel-held-0513]
    NeedMove -- yes --> Request[request_movement]
    Request --> Moved{moved?}
    Moved -- no --> Failed[pair.mode = direct-acquisition-movement-failed; phase movement-request-failed]
    Failed --> ShowFail[show movement failed no_line]
    ShowFail --> ReturnFailed[return movement-request-failed]
    Moved -- yes --> RecordTravel[record travel-request or travel-repath]
    Held --> PhaseWalk[set phase walk-to-target]
    RecordTravel --> PhaseWalk
    PhaseWalk --> ShowWalk[show walking to direct target no_line]
    ShowWalk --> ReturnWalking[return walking]
```

Important interaction: `show(..., no_line=true)` prevents the old scan/mining line while walking. Movement/intent line should instead be owned by `active_leaf_task_truth_0655` and `visual_intent_line_authority_0657`.

---

## 8. Work Branch

```mermaid
flowchart TD
    Work[work branch] --> Stop[stop_for_work]
    Stop --> Mode[pair.mode = direct-acquisition-working]
    Mode --> Target[pair.target = target_entity cur]
    Target --> Phase[set phase work-target]
    Phase --> DueExists{task.direct_due_tick_0513 exists?}
    DueExists -- no --> Start[set due_tick = now + work_ticks; started tick; record work-started]
    DueExists -- yes --> CheckDue
    Start --> CheckDue{now < due_tick?}
    CheckDue -- yes --> VisualDue{visual tick elapsed?}
    VisualDue -- yes --> MineHitPartial[mine_hit final=false]
    VisualDue -- no --> Remain[compute remaining seconds]
    MineHitPartial --> Remain
    Remain --> ShowExtract[show extracting status]
    ShowExtract --> ReturnWorking[return working]
    CheckDue -- no --> MineHitFinal[mine_hit final=true]
    MineHitFinal --> Item[output_item]
    Item --> Deposit[deposit item count 1]
    Deposit --> ClearTimers[clear direct due timers]
    ClearTimers --> DepositOK{deposit ok?}
    DepositOK -- no --> Blocked[mode deposit-blocked; phase deposit-blocked; record deposit-failed]
    Blocked --> ReturnBlocked[return deposit-blocked]
    DepositOK -- yes --> Increment[task.gathered_units += 1]
    Increment --> NeedMore{gathered < required_units and target still valid?}
    NeedMore -- yes --> Continue[phase work-target continue count]
    Continue --> ReturnContinue[return continue]
    NeedMore -- no --> Recipe{task.recipe and task.output_item?}
    Recipe -- yes --> CraftPending[task.current=nil; station_craft_pending flags; mode returning-for-craft]
    CraftPending --> ReturnCraft[return_to_station reason return-for-craft]
    Recipe -- no --> Complete[clear task fields; pair.target=nil; phase complete]
    Complete --> ReturnComplete[return_to_station reason complete]
```

---

## 9. Mine/Damage and Deposit Detail

```mermaid
flowchart TD
    MineHit[mine_hit] --> Visual[mine_visual]
    Visual --> Entity{target entity valid?}
    Entity -- no --> Done[return]
    Entity -- yes --> Type{entity.type resource?}
    Type -- resource --> Amount[reduce resource amount by 2 or 20]
    Type -- not resource --> Health{entity has health > 1?}
    Health -- yes --> Damage[damage entity impact 5 or 35]
    Health -- no --> Done
    Amount --> Done
    Damage --> Done

    Deposit[deposit] --> Valid{valid pair, item exists?}
    Valid -- no --> ReturnFalse[false]
    Valid -- yes --> Safe{tech_priests_safe_deposit_item exists?}
    Safe -- yes --> SafeDeposit[call safe deposit]
    SafeDeposit --> SafeOK{ok?}
    SafeOK -- yes --> True[true]
    SafeOK -- no --> ShowBlocked[show direct acquisition deposit blocked]
    ShowBlocked --> False[false]
    Safe -- no --> FallbackInv[station chest or assembling input/output]
    FallbackInv --> CanInsert{can_insert?}
    CanInsert -- yes --> Insert[inv.insert]
    Insert --> Inserted{inserted > 0?}
    Inserted -- yes --> True
    Inserted -- no --> False
    CanInsert -- no --> False
```

Audit warning: the fallback deposit path still tries station chest, assembling input, and assembling output. The safe deposit helper should normally exist and should be preferred. If safe deposit is missing, this fallback should be reviewed against the earlier inventory safety policy.

---

## 10. Return / Completion Flow

```mermaid
flowchart TD
    UnitCollected[unit collected] --> Enough{required units reached?}
    Enough -- no --> Continue[continue work target]
    Enough -- yes --> Recipe{task.recipe and task.output_item?}
    Recipe -- yes --> CraftPending[station_craft_pending_0337 and 0513 true]
    CraftPending --> ModeCraft[pair.mode = returning-to-station-for-craft]
    ModeCraft --> PhaseCraft[phase return-for-craft]
    PhaseCraft --> ReturnToStation[return_to_station]
    ReturnToStation --> ReturnOK{movement request ok?}
    ReturnOK -- yes --> ReadyCraft[return ready-to-craft]
    ReturnOK -- no --> ReturnFail[return movement failed]

    Recipe -- no --> ClearDirect[clear emergency/direct/active acquisition task fields]
    ClearDirect --> PairTargetNil[pair.target = nil]
    PairTargetNil --> PhaseComplete[phase complete]
    PhaseComplete --> ReturnToStation2[return_to_station]
    ReturnToStation2 --> CompleteOK{movement request ok?}
    CompleteOK -- yes --> Done[return complete]
    CompleteOK -- no --> ReturnFail
```

---

## 11. Service Loop and Legacy Blocking

```mermaid
flowchart TD
    ServiceAll[M.service_all] --> Enabled{enabled?}
    Enabled -- no --> Zero[return 0]
    Enabled -- yes --> Loop[pair_map loop]
    Loop --> HasDirect{valid pair and current_direct_task?}
    HasDirect -- yes --> Service[M.service_pair]
    HasDirect -- no --> Next[next pair]
    Service --> Count[n += 1 if pcall ok]
    Count --> Limit{max_pairs_per_pulse reached?}
    Limit -- yes --> ReturnN[return n]
    Limit -- no --> Next

    ShouldBlock[should_block_legacy] --> Enabled2{enabled and block_legacy?}
    Enabled2 -- no --> NoBlock[false]
    Enabled2 -- yes --> HasTask{current direct task?}
    HasTask -- no --> NoBlock
    HasTask -- yes --> Phase{dispatcher_direct phase not none?}
    Phase -- yes --> Block[true]
    Phase -- no --> Dispatcher{dispatcher_0510 family direct-acquisition recent?}
    Dispatcher -- yes --> Block
    Dispatcher -- no --> NoBlock
```

### Wrapper graph

```mermaid
flowchart TD
    Install[M.install] --> Root[M.root]
    Install --> WrapAcq[wrap_acquisition_executor]
    Install --> WrapLegacy[wrap_legacy_direct_functions]
    Install --> PairDump[wrap_pair_dump]
    Install --> Command[install_command]
    Install --> Global[_G.TechPriestsDirectAcquisitionExecutor0513 = M]

    WrapAcq --> Require[require scripts.core.acquisition_executor]
    Require --> HasService{service_pair exists and not wrapped?}
    HasService -- yes --> Replace[Exec.service_pair = M.service_pair when enabled]
    HasService -- no --> Noop[return false]

    WrapLegacy --> Wrap0273[wrap tech_priests_0273_service_direct_current]
    WrapLegacy --> Wrap0312[wrap tech_priests_0312_service_direct_current]
    WrapLegacy --> Wrap0315[wrap tech_priests_0315_service_direct_current]
    Wrap0273 --> BlockCheck[should_block_legacy]
    Wrap0312 --> BlockCheck
    Wrap0315 --> BlockCheck
    BlockCheck --> Blocked{blocked?}
    Blocked -- yes --> ReturnTrue[record legacy-direct-blocked and return true]
    Blocked -- no --> OldFn[call previous legacy function]
```

---

## 12. Remaining Slash Command Surface

```mermaid
flowchart TD
    Install[M.install] --> Command[install_command]
    Command --> Add[commands.add_command tp-direct-acquisition-0513]
    Add --> Params[on / off / all / legacy-on / legacy-off / status]
    Params --> Root[M.root]
    Params --> ManualAll[M.service_all manual-all]
    Params --> Selected[selected_pair]
    Selected --> Print[print status lines]
```

Cleanup note: this is a remaining slash command block. It belongs on the command cleanup list if commandless runtime is still the target architecture.

---

## 13. State Write Matrix

| State field | Writer | Meaning | Risk |
|---|---|---|---|
| `pair.dispatcher_action` | `set_phase` | Broad action marker | Medium |
| `pair.dispatcher_phase` | `set_phase` | Broad phase marker | Medium |
| `pair.dispatcher_direct_0513` | `set_phase`, `M.service_pair` | Direct acquisition phase trace | High; 0650/0652 read phase |
| `pair.mode` | travel/work/return/failure branches | Coarse pair mode | High; many legacy modules inspect mode |
| `pair.target` | request movement, return, work, invalid/complete cleanup | Generic target pointer | Critical; legacy modules and visuals may read it |
| `pair.movement_request_0418` | `stop_for_work` clears; request helper writes through movement system | Movement target | Critical; vector enforcer obeys it |
| `pair.pathing_target_0418` | `stop_for_work` clears | Old pathing target | Medium |
| `pair.movement_controller_state_0418` | `stop_for_work` | Work clamp marker | High while working |
| `pair.movement_controller_clamp_0418` | `stop_for_work` | Prevents movement during work | High; stale clamp would freeze priest |
| `task.direct_due_tick_0513` | work branch | Work completion timer | High; controls extraction duration |
| `task.gathered_units` | work completion branch | Progress toward required units | High |
| `task.station_craft_pending_0337/0513` | return-for-craft branch | Signals materials acquired for crafting | High |
| `pair.emergency_craft`, `pair.direct_acquisition_task_0336`, `pair.active_acquisition_0333` | complete branch | Clears direct task fields | High |

---

## 14. Failure / Exit Matrix

| Exit | Trigger | State change | Next expected behavior |
|---|---|---|---|
| `disabled` | root disabled | none | dispatcher/other systems continue |
| `invalid-pair` | invalid station/priest | none | cleanup/recovery should handle |
| `no-direct-task` | no current direct task | phase none | dispatcher chooses next work |
| `target-invalid` | cur.entity exists but invalid | task current nil, target nil, mode replan | upstream should replan direct task |
| `no-target-position` | no entity/position/pair target | task current nil, target nil, phase need-target | 0649/parent planner should provide physical target |
| `target-out-of-bounds` | bounds authority rejects target | task current nil, target nil, rejected mode | upstream should choose closer target |
| `movement-request-failed` | request_movement false | mode movement-failed, phase movement-request-failed | 0650 may force fallback movement |
| `walking` | target far and movement ok/held | phase walk-to-target | continue until adjacent |
| `working` | work timer not done | phase work-target | continue extraction |
| `continue` | one unit deposited but more required | phase work-target | continue extracting same target if valid |
| `deposit-blocked` | deposit failed | mode deposit-blocked | inventory/station deposit bug |
| `ready-to-craft` | gathered recipe materials | return-for-craft, station craft pending flags | station crafting executor should craft output |
| `complete` | gathered direct item without recipe | clears direct tasks, returns to station | dispatcher chooses next behavior |
| `return-movement-request-failed` | return_to_station failed | return movement failure phase | movement system/fallback must recover |

---

## 15. Direct Executor Debugging Decision Tree

```mermaid
flowchart TD
    Bug[Direct acquisition visible but not completing] --> Current{current_direct_task exists?}
    Current -- no --> Upstream[Upstream scheduler/decomposition bug]
    Current -- yes --> Target{target_entity or target_position exists?}
    Target -- no --> PhysicalGuard[Check 0649 physical guard and target planning]
    Target -- yes --> Bounds{within_bounds accepts target?}
    Bounds -- no --> BoundsBug[Movement bounds/station radius rejected target]
    Bounds -- yes --> Distance{priest distance > close?}
    Distance -- yes --> Move{movement_request issued and moving?}
    Move -- no --> MovementStack[Check 0650/0652/0654/0651 movement stack]
    Move -- yes --> WaitTravel[Travel should continue]
    Distance -- no --> Clamp{movement clamped for work?}
    Clamp -- no --> StopBug[stop_for_work or movement lease bug]
    Clamp -- yes --> Due{direct_due_tick set?}
    Due -- no --> StartBug[work-start branch not firing]
    Due -- yes --> DueReached{due tick reached?}
    DueReached -- no --> WaitWork[Work timer still running]
    DueReached -- yes --> Deposit{deposit succeeds?}
    Deposit -- no --> DepositBug[Safe deposit / station inventory bug]
    Deposit -- yes --> Units{gathered_units >= required_units?}
    Units -- no --> Continue[Should continue same target]
    Units -- yes --> Recipe{recipe output pending?}
    Recipe -- yes --> CraftHandoff[Check station craft pending executor]
    Recipe -- no --> Complete[Should clear task and return]
```

---

## 16. Direct Executor Cleanup Targets

1. Remove `/tp-direct-acquisition-0513` command block if commandless runtime remains the standard.
2. Review fallback `deposit()` path that can insert into station assembling input/output if safe deposit helper is missing.
3. Review `output_item()` stone fallback; bad direct task metadata should probably fail loudly instead of silently becoming stone.
4. Ensure `show()` parent text is fully superseded by `active_leaf_task_truth_0655` overhead where applicable.
5. Confirm `stop_for_work()` clamp is reliably released after work/complete/return transitions.
6. Confirm `task.current = nil` behavior is correct for all three task containers: `emergency_craft`, `direct_acquisition_task_0336`, and `active_acquisition_0333`.
7. Confirm return-for-craft handoff is consumed by the station crafting executor and does not strand `station_craft_pending_0337/0513`.
