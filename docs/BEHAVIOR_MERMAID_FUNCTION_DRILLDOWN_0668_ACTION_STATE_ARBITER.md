# Tech-Priests Function-Level Mermaid Drilldown: Action State Arbiter 0488

Version: 0.1.668-map-pass-9  
Previous drilldown: `docs/BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_0667_SINGLE_DISPATCHER.md`  
Companion overview: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

Purpose: map the classifier that usually determines the action seen by `single_dispatcher_0510.choose_action()`. This module was introduced as a late-loaded single-action visual arbiter, but it also mutates task state, requests movement, fails stale orders, suppresses lasers/scans, and patches overhead/work visuals.

Mapped module:

- `action_state_arbiter_0488.lua`

Important current-code truths:

1. This arbiter is not merely observational.
2. It runs every eleven ticks in the scheduler category at `priority = last`.
3. It normally outranks the dispatcher's direct/emergency/combat fallback classification because `single_dispatcher_0510.choose_action()` asks this arbiter before those fallback checks.
4. Its active classification order is:
   - invalid pair
   - conversation
   - valid hostile/combat target
   - stale combat order becomes idle
   - actual timed crafting
   - repair
   - acquisition/logistics/emergency/machine-logistics intent
   - consecration
   - idle
5. Acquisition intentionally outranks stale consecration state.
6. `pair.emergency_craft` does not automatically mean crafting. If it still contains a current physical entity/target/source, or no active craft timer/lock exists, the arbiter can classify it as acquisition.
7. When crafting wins, `service_pair()` clears `direct_acquisition_task_0336`, `scavenge`, and `inventory_scan`.
8. The module still registers `/tp-action-state-0488`.

---

## 1. Runtime Position

```mermaid
flowchart TD
    PairState[Pair bookkeeping state]
    Arbiter[action_state_arbiter_0488.action]
    Dispatcher[single_dispatcher_0510.choose_action]
    Service[action_state_arbiter_0488.service_pair every 11 ticks]
    Visuals[scan lines / mining lasers / work visuals]
    Overhead[overhead status governor]

    PairState --> Arbiter
    Arbiter --> Dispatcher
    PairState --> Service
    Service --> PairState
    Arbiter --> Visuals
    Arbiter --> Overhead
```

The dispatcher consumes the action table, while the arbiter's own scheduled service separately enforces visual and bookkeeping consequences.

---

## 2. Function Inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `now`, `valid`, `lower`, `safe`, `dist_sq` | local helpers | Time, validity, text, distance | none |
| `root()` | local storage root | Ensures arbiter configuration/stats | writes `storage.tech_priests.action_state_arbiter_0488` |
| `enabled()` | local predicate | Returns root enabled state | none |
| `stat(k,n)` | local metric | Increments counters | writes root stats |
| `pairs_by_station()` | local accessor | Reads pair map | none |
| `valid_pair(p)` | local predicate | Valid station/priest pair | none |
| `pair_key(p)` | local helper | Station/priest identity key | none |
| `current_order(pair)` | local selector | Gets order queue current or active order | none |
| `item_from(v)` | local extractor | Reads common item fields | none |
| `order_item(o)` | local extractor | Gets item from order or nested task | none |
| `normalize_kind(k)` | local classifier | Normalizes strings into combat/repair/consecration/crafting/acquisition | none |
| `is_hostile(priest,target)` | local predicate | Checks enemy force relationship | none |
| `entity_or_pos(v,seen)` | local recursive extractor | Finds entity or position inside nested task-like tables | none |
| `current_target(pair)` | local selector | Chooses first target/entity/position across ordered pair state fields | none |
| `name_item_from_entity(e)` | local mapper | Infers item/resource from entity | none |
| `actual_crafting(pair)` | local predicate | Distinguishes active timed station craft from acquisition subtask | none |
| `M.action(pair)` | public classifier | Returns one visible action table | none directly |
| `destroy(obj)` | local render helper | Safely destroys render object | destroys render object |
| `M.clear_beams(pair)` | public visual cleanup | Clears scan/mining beam state | destroys pair and work-visual scan lines |
| `request_move(pair,pos,reason)` | local movement helper | Requests movement before remote scan/laser | writes movement through 0418 or direct command fallback |
| `M.allow_scan(pair,target)` | public visual gate | Allows only acquisition scan on matching/near target | may clear beams, request movement, increment stats |
| `M.allow_laser(priest,target,reason)` | public visual/action gate | Allows combat laser only in combat and mining laser only in acquisition/near target | may clear beams, request movement, suppress laser |
| `progress_bar(p,w)` | local formatter | Builds craft status bar | none |
| `M.status(pair)` | public display resolver | Returns action-based overhead text/color | none |
| `M.service_pair(pair)` | public scheduled mutator | Claims action, records action state, fails stale combat, clears beams/tasks | writes pair state and may mutate order/task state |
| `M.tick_all()` | public loop | Services all pairs | calls `M.service_pair` |
| `M.wrap_visuals()` | public wrapper installer | Wraps scan/laser/work visual functions | replaces global/module visual functions |
| `M.wrap_overhead()` | public wrapper installer | Wraps overhead canonical status | replaces governor function |
| `M.wrap_diagnostics()` | public wrapper installer | Adds arbiter state to pair dump | replaces diagnostics function |
| `M.register_commands()` | public command installer | Registers `/tp-action-state-0488` | command surface |
| `M.install()` | public installer | Exposes arbiter, installs wrappers/command, schedules tick | writes `_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488` |

---

## 3. Kind Normalization

```mermaid
flowchart TD
    Kind[normalize_kind lower-case input]
    Kind --> Empty{empty?}
    Empty -- yes --> Idle[idle]
    Empty -- no --> Combat{contains combat / defend / weapon / point?}
    Combat -- yes --> CombatK[combat]
    Combat -- no --> Repair{contains repair?}
    Repair -- yes --> RepairK[repair]
    Repair -- no --> Cons{contains consecr / sanct?}
    Cons -- yes --> ConsK[consecration]
    Cons -- no --> Craft{contains craft / fabric?}
    Craft -- yes --> CraftK[crafting]
    Craft -- no --> Assign{contains assign?}
    Assign -- yes --> Acquisition[acquisition]
    Assign -- no --> Logistics{contains logistic / supply?}
    Logistics -- yes --> Acquisition
    Logistics -- no --> Gather{contains scav / mine / acqui / gather / resource / emergency?}
    Gather -- yes --> Acquisition
    Gather -- no --> Original[return original normalized string]
```

Broad-match consequences:

- Any kind containing `point` becomes combat.
- Any kind containing `emergency` becomes acquisition unless `actual_crafting()` independently wins first.
- Logistics and supply are represented as acquisition, not a separate arbiter family.

---

## 4. Recursive Entity / Position Extraction

```mermaid
flowchart TD
    Input[entity_or_pos value]
    Input --> ValidEntity{valid LuaEntity?}
    ValidEntity -- yes --> ReturnEntity[return entity and entity.position]
    ValidEntity -- no --> Table{table?}
    Table -- no --> None[return nil nil]
    Table -- yes --> Seen{already visited?}
    Seen -- yes --> None
    Seen -- no --> Mark[mark table seen]
    Mark --> XY{contains x and y?}
    XY -- yes --> ReturnPos[return nil and table as position]
    XY -- no --> Position{contains position x/y?}
    Position -- yes --> ReturnNestedPos[return nil and v.position]
    Position -- no --> Keys[scan target, source, entity, resource_entity, mining_target, candidate, current, selected, node, resource, destination]
    Keys --> Recurse[recursive entity_or_pos]
    Recurse --> Found{entity or position found?}
    Found -- yes --> ReturnFound[return first found]
    Found -- no --> None
```

This recursive search permits deeply nested legacy task records to continue influencing current action targeting.

---

## 5. Current Target Priority

```mermaid
flowchart TD
    Target[current_target]
    Target --> OrderTarget[current order target]
    OrderTarget --> OrderTask[current order task]
    OrderTask --> Direct[pair.direct_acquisition_task_0336]
    Direct --> Emergency[pair.emergency_craft]
    Emergency --> Scavenge[pair.scavenge]
    Scavenge --> Active[pair.active_task]
    Active --> Active0285[pair.active_task_0285]
    Active0285 --> Inventory[pair.inventory_scan]
    Inventory --> PairTarget[pair.target]
    PairTarget --> Mining[pair.mining_target]

    OrderTarget -->|first entity or position wins| Return[return entity/position]
    OrderTask -->|first entity or position wins| Return
    Direct -->|first entity or position wins| Return
    Emergency -->|first entity or position wins| Return
    Scavenge -->|first entity or position wins| Return
    Active -->|first entity or position wins| Return
    Active0285 -->|first entity or position wins| Return
    Inventory -->|first entity or position wins| Return
    PairTarget -->|first entity or position wins| Return
    Mining -->|first entity or position wins| Return
```

Risk: a stale target nested in a higher-priority field can hide the physically correct target stored later in the list.

---

## 6. Entity-to-Item Inference

```mermaid
flowchart TD
    Entity[name_item_from_entity]
    Entity --> Resource{entity type resource?}
    Resource -- yes --> ResourceName[return entity.name]
    Resource -- no --> Name[entity.name string]
    Name --> Coal{contains coal?}
    Coal -- yes --> CoalItem[coal]
    Coal -- no --> Iron{contains iron?}
    Iron -- yes --> IronItem[iron-ore]
    Iron -- no --> Copper{contains copper?}
    Copper -- yes --> CopperItem[copper-ore]
    Copper -- no --> Stone{contains rock or stone?}
    Stone -- yes --> StoneItem[stone]
    Stone -- no --> Tree{contains tree?}
    Tree -- yes --> Wood[wood]
    Tree -- no --> Original[return entity name or nil]
```

This inferred item is used for the arbiter's acquisition action display and dispatcher classification.

---

## 7. Actual Crafting Predicate

```mermaid
flowchart TD
    Craft[actual_crafting]
    Craft --> Task[pair.emergency_craft or station_craft_0337 or active_craft_0479]
    Task --> HasTask{task exists?}
    HasTask -- no --> False[return false]
    HasTask -- yes --> Current[task.current or task.entity or task.target]
    Current --> Physical{valid current entity or nested entity/target/source?}
    Physical -- yes --> FalsePhysical[return false]
    Physical -- no --> Due[craft/build/station/due tick]
    Due --> ActiveDue{due exists and due >= now?}
    ActiveDue -- yes --> True[return true]
    ActiveDue -- no --> Mode{pair.mode contains craft?}
    Mode -- yes --> Lock{station craft lock / crafting lock / station craft pending?}
    Lock -- yes --> True
    Lock -- no --> False
    Mode -- no --> False
```

This is the key distinction between:

- an emergency craft object currently driving physical ingredient acquisition, and
- an emergency/station craft object actively timing a craft.

---

## 8. Actual `M.action` Classification Order

```mermaid
flowchart TD
    Action[M.action]
    Action --> Valid{valid pair?}
    Valid -- no --> Invalid[invalid]
    Valid -- yes --> Conversation{idle_player_conversation_0181 or idle_conversation?}
    Conversation -- yes --> ConversationA[conversation]
    Conversation -- no --> Target[current_target]
    Target --> Order[current_order]
    Order --> OKind[normalize order kind/type/source]
    OKind --> ModeKind[normalize pair.mode]

    ModeKind --> Combat{hostile target OR modekind combat, and target valid?}
    Combat -- yes --> CombatA[combat]
    Combat -- no --> Stale{order kind combat, no valid target, mode idle/combat?}
    Stale -- yes --> StaleIdle[idle + stale_combat]
    Stale -- no --> Craft{actual_crafting?}
    Craft -- yes --> CraftA[crafting]
    Craft -- no --> Repair{order kind repair OR mode kind repair?}
    Repair -- yes --> RepairA[repair]
    Repair -- no --> Acquisition{any acquisition/logistics intent active?}
    Acquisition -- yes --> AcquisitionA[acquisition]
    Acquisition -- no --> Consecration{order kind consecration OR active 0515 phase?}
    Consecration -- yes --> ConsA[consecration]
    Consecration -- no --> IdleA[idle]
```

---

## 9. Acquisition Intent Predicate

Acquisition wins when any of the following is true:

```mermaid
flowchart TD
    Acquisition[Acquisition predicate]
    Acquisition --> OKind[normalized order kind acquisition]
    Acquisition --> ModeKind[normalized mode acquisition]
    Acquisition --> Emergency[pair.emergency_craft exists]
    Acquisition --> Direct[pair.direct_acquisition_task_0336 exists]
    Acquisition --> Scavenge[pair.scavenge exists]
    Acquisition --> Inventory[pair.inventory_scan exists]
    Acquisition --> Supply[pair.active_supply_request exists]
    Acquisition --> Logistic[pair.logistic_requested_item exists]
    Acquisition --> Machine[pair.machine_logistics_0528 phase exists and not complete]
```

Item selection inside the returned acquisition action:

1. Infer item from valid target entity.
2. Current order item.
3. Active supply request item.
4. Logistic requested item.
5. Emergency craft item.
6. Direct acquisition task item.

Because the valid target entity wins, a stale target can also produce stale overhead item text.

---

## 10. Consecration Predicate

```mermaid
flowchart TD
    Cons[Consecration predicate]
    Cons --> Order{normalized order kind consecration?}
    Order -- yes --> True[return consecration]
    Order -- no --> State[pair.consecration_0515]
    State --> Active{phase exists and not none/complete/need-item/target-invalid?}
    Active -- yes --> True
    Active -- no --> False[fall through idle]
```

Acquisition is checked before this branch specifically to prevent stale consecration labels from suppressing real acquisition/logistics work.

---

## 11. Returned Action Shapes

| Kind | Important fields |
|---|---|
| `invalid` | `kind` |
| `conversation` | `kind` |
| `combat` | `kind`, `target`, `item = combat` |
| stale combat idle | `kind = idle`, `stale_combat = true` |
| `crafting` | `kind`, selected item |
| `repair` | `kind`, `target`, `item = repair-pack` |
| `acquisition` | `kind`, `target`, `pos`, inferred/requested item |
| `consecration` | `kind`, `target`, `item = sacred-machine-oil` |
| `idle` | `kind`, order item, target, position |

The action table does not contain an executor reference. `single_dispatcher_0510` later normalizes the kind and chooses an executor.

---

## 12. Beam Cleanup

```mermaid
flowchart TD
    Clear[M.clear_beams]
    Clear --> PairScan[destroy pair.scan_line_render]
    Clear --> PairMine[destroy pair.mining_beam_render]
    Clear --> Key[pair_key]
    Key --> Work[storage.tech_priests.tech_priests_work_visuals_0323.scan_lines key]
    Work --> Destroy[destroy stored work visual scan line]
```

The arbiter suppresses incorrect visual ownership by destroying render objects rather than deleting queued tasks.

---

## 13. Movement Before Visual/Work Action

```mermaid
flowchart TD
    Move[request_move]
    Move --> Valid{valid pair and position?}
    Valid -- no --> False[return false]
    Valid -- yes --> Movement{tech_priests_request_movement_0418 exists?}
    Movement -- yes --> Request[owner action-arbiter-0488 priority 720 ttl 600 radius .75]
    Request --> OK{request succeeded?}
    OK -- yes --> Stat[move_requests++]
    OK -- no --> False
    Movement -- no --> Direct{priest.set_command and defines command?}
    Direct -- yes --> Command[direct go_to_location distraction by_enemy]
    Command --> Stat
    Direct -- no --> False
```

Later movement intent/leaf authorities may redirect or overwrite this movement request when a more concrete target exists.

---

## 14. Scan Gate

```mermaid
flowchart TD
    Scan[M.allow_scan]
    Scan --> Enabled{arbiter enabled?}
    Enabled -- no --> Allow[return true]
    Enabled -- yes --> Valid{valid pair?}
    Valid -- no --> Deny[return false]
    Valid -- yes --> Action[M.action]
    Action --> Acquisition{kind acquisition?}
    Acquisition -- no --> Clear[M.clear_beams]
    Clear --> Suppress[scan_suppressed++; return false]
    Acquisition -- yes --> TargetMatch{both targets valid and requested target differs?}
    TargetMatch -- yes --> Mismatch[scan_target_mismatch++; return false]
    TargetMatch -- no --> Distance{valid target farther than close_distance_sq?}
    Distance -- yes --> Move[request_move before scan]
    Distance -- no --> Allow
    Move --> Allow
```

Unlike the laser gate, a remote scan can still be allowed after requesting movement.

---

## 15. Laser Gate

```mermaid
flowchart TD
    Laser[M.allow_laser]
    Laser --> Enabled{arbiter enabled?}
    Enabled -- no --> Allow[return true]
    Enabled -- yes --> Priest{valid priest?}
    Priest -- no --> Deny[return false]
    Priest -- yes --> Pair[pairs_by_priest lookup]
    Pair --> ValidPair{valid pair?}
    ValidPair -- no --> Allow
    ValidPair -- yes --> Hostile[is_hostile]
    Hostile --> Action[M.action]

    Action --> HostileBranch{target hostile?}
    HostileBranch -- yes --> Combat{action kind combat?}
    Combat -- yes --> AllowCombat[return true]
    Combat -- no --> SuppressCombat[combat_laser_suppressed++; return false]

    HostileBranch -- no --> Acquisition{action kind acquisition?}
    Acquisition -- no --> Clear[M.clear_beams]
    Clear --> Wrong[laser_suppressed_wrong_action++; return false]
    Acquisition -- yes --> Match{target matches action target?}
    Match -- no --> Mismatch[laser_target_mismatch++; return false]
    Match -- yes --> Far{distance > close_distance_sq?}
    Far -- yes --> Move[request_move before laser]
    Move --> Remote[remote_laser_suppressed++; return false]
    Far -- no --> AllowMining[return true]
```

Remote mining laser is explicitly suppressed until the priest is close enough.

---

## 16. Status Resolution

```mermaid
flowchart TD
    Status[M.status]
    Status --> Action[M.action]
    Action --> Kind{kind}
    Kind -- conversation --> Conversation[Conversing]
    Kind -- combat --> Combat[Battle rite engaged]
    Kind -- repair --> Repair[Repair litany in progress]
    Kind -- consecration --> Consecration[Consecration rite in progress]
    Kind -- crafting --> Craft[Crafting item seconds progress bar]
    Kind -- acquisition --> Acquire[Acquiring item]
    Kind -- idle/invalid/other --> Nil[return nil nil]
```

This is broad parent-level status. The later `active_leaf_task_truth_0655` patch is intended to supersede it with concrete leaf text when a real leaf task exists.

---

## 17. Scheduled `service_pair` Mutation Flow

```mermaid
flowchart TD
    Service[M.service_pair]
    Service --> Enabled{enabled and valid pair?}
    Enabled -- no --> Exit[return]
    Enabled -- yes --> Action[M.action]
    Action --> Claim[tech_priests_0507_action_claim]
    Claim --> Store[pair.action_state_0488 kind/item/target string/tick]
    Store --> Stale{a.stale_combat?}
    Stale -- yes --> OrderQueue[TECH_PRIESTS_ORDER_QUEUE_0469.fail_current]
    OrderQueue --> StaleStat[stale_combat_failed++]
    Stale -- no --> Beams
    StaleStat --> Beams{kind acquisition?}
    Beams -- no --> Clear[M.clear_beams]
    Beams -- yes --> Craft
    Clear --> Craft{kind crafting?}
    Craft -- yes --> ClearTasks[direct_acquisition_task_0336=nil; scavenge=nil; inventory_scan=nil]
    Craft -- no --> Done[done]
    ClearTasks --> Done
```

This is a real behavior mutation path, not merely visual arbitration.

---

## 18. Stale Combat Failure Path

```mermaid
flowchart TD
    CombatOrder[Order kind normalizes to combat]
    CombatOrder --> Target{valid target?}
    Target -- yes --> Combat[combat action]
    Target -- no --> Mode{mode idle or combat?}
    Mode -- yes --> Stale[idle action stale_combat true]
    Stale --> Service[M.service_pair]
    Service --> Queue[order_queue_0469.fail_current reason stale combat without target]
    Queue --> NextOrder[order queue may advance later]
```

The arbiter can fail scheduler work based on visual/action-state validation.

---

## 19. Visual Wrapper Surface

```mermaid
flowchart TD
    Wrap[M.wrap_visuals]
    Wrap --> ScanGlobal{draw_emergency_craft_scan_line exists and not wrapped?}
    ScanGlobal -- yes --> WrapScan[replace with allow_scan gate]
    Wrap --> LaserGlobal{tech_priests_0312_fire_laser exists and not wrapped?}
    LaserGlobal -- yes --> WrapLaser[replace with allow_laser gate]
    Wrap --> Work[require work_visuals]
    Work --> Status[W.status_for_pair = arbiter status/action target]
    Work --> ScanLine[wrap W.draw_scan_line through allow_scan]
```

`W.status_for_pair` is replaced outright, not wrapped around a previous function.

---

## 20. Overhead Wrapper Order

```mermaid
flowchart TD
    ArbiterInstall[action arbiter installs]
    ArbiterInstall --> SaveArb[save governor canonical_status as canonical_status_0488_previous]
    SaveArb --> ArbWrapper[arbiter canonical_status wrapper]
    LaterLeaf[active_leaf_task_truth_0655 installs later]
    LaterLeaf --> SaveLeaf[save current canonical status including arbiter wrapper]
    SaveLeaf --> LeafWrapper[leaf truth canonical status wrapper]
    LeafWrapper --> HasLeaf{leaf status exists?}
    HasLeaf -- yes --> LeafText[return concrete leaf text]
    HasLeaf -- no --> ArbWrapper
```

This expected ordering means concrete leaf truth should win while retaining arbiter status as fallback. If installation order changes, overhead priority can change.

---

## 21. Diagnostics Wrapper

```mermaid
flowchart TD
    Wrap[M.wrap_diagnostics]
    Wrap --> Diag[TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468]
    Diag --> Exists{pair_dump_lines exists and not wrapped?}
    Exists -- no --> False[return false]
    Exists -- yes --> Save[save previous function]
    Save --> Replace[append arbiter header/stats]
    Replace --> Pairs[for each pair call M.action]
    Pairs --> Lines[action kind item mode target]
    Lines --> Return[return lines]
```

---

## 22. Command Surface

```mermaid
flowchart TD
    Command[M.register_commands]
    Command --> Remove[remove tp-action-state-0488]
    Remove --> Add[add tp-action-state-0488]
    Add --> Param[status / all / on / off]
    Param --> Root[enable or disable arbiter]
    Param --> Selected[selected pair or all pairs]
    Selected --> Print[action kind item mode target]
```

Cleanup target: remove this runtime mutation/inspection command once automatic diagnostics fully replace it.

---

## 23. Install / Scheduling Flow

```mermaid
flowchart TD
    Install[M.install]
    Install --> Root[root]
    Root --> Global[_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488 = M]
    Global --> Visuals[M.wrap_visuals]
    Visuals --> Overhead[M.wrap_overhead]
    Overhead --> Diagnostics[M.wrap_diagnostics]
    Diagnostics --> Commands[M.register_commands]
    Commands --> Registry[RuntimeEventRegistry]
    Registry --> Schedule[on_nth_tick interval 11 category scheduler priority last]
    Schedule --> Tick[M.tick_all + M.wrap_overhead]
```

`M.wrap_overhead()` is retried every arbiter tick, allowing it to patch a governor that loaded after the arbiter.

---

## 24. State Write Matrix

| State field / object | Writer | Meaning | Risk |
|---|---|---|---|
| `storage.tech_priests.action_state_arbiter_0488` | `root` | Enabled flag and suppression stats | High configuration authority |
| `pair.action_state_0488` | `M.service_pair` | Last arbiter kind/item/target string/tick | High diagnostic/action trace |
| current order state | `M.service_pair` via `order_queue.fail_current` | Fails stale combat order | High scheduler mutation |
| `pair.direct_acquisition_task_0336` | `M.service_pair` crafting branch | Cleared when crafting wins | Critical; can cancel direct task |
| `pair.scavenge` | same | Cleared when crafting wins | High |
| `pair.inventory_scan` | same | Cleared when crafting wins | High |
| `pair.scan_line_render` | `M.clear_beams` | Scan visual ownership | Visual |
| `pair.mining_beam_render` | `M.clear_beams` | Mining visual ownership | Visual |
| `work_visuals.scan_lines[key]` | `M.clear_beams` | Stored work scan visual | Visual |
| movement request state | `request_move` through 0418 | Moves before scan/laser | Critical when target stale |
| global scan/laser functions | `M.wrap_visuals` | Gates legacy visuals/actions | Critical wrapper order |
| `work_visuals.status_for_pair` | `M.wrap_visuals` | Broad action status provider | High visual authority |
| overhead canonical status | `M.wrap_overhead` | Broad action overhead fallback | High visual authority |

---

## 25. Action / Side-Effect Matrix

| Arbiter action | Beam behavior | Movement behavior | Task mutation |
|---|---|---|---|
| Invalid | non-acquisition cleanup if serviced | none | none |
| Conversation | clears acquisition beams | none | none |
| Combat | hostile laser allowed; acquisition scan suppressed | combat positioning handled elsewhere | none |
| Stale combat idle | clears beams | none | fails current order |
| Crafting | clears beams | none here | clears direct acquisition, scavenge, inventory scan |
| Repair | clears beams | repair executor later | none here |
| Acquisition | matching scan allowed; matching close laser allowed | requests movement before remote scan/laser | none here |
| Consecration | clears acquisition beams | consecration executor later | none here |
| Idle | clears acquisition beams | none | none |

---

## 26. Interaction with Single Dispatcher

```mermaid
sequenceDiagram
    participant D as single_dispatcher_0510
    participant A as action_state_arbiter_0488
    participant E as family executor
    participant S as arbiter scheduled service

    D->>A: action(pair)
    A-->>D: action kind/target/item
    D->>D: action_family(action)
    D->>E: execute owned family or return legacy-leaf-family

    Note over S,A: Independently every 11 ticks
    S->>A: action(pair)
    S->>S: claim action and write action_state_0488
    S->>S: fail stale combat / clear beams / clear acquisition fields when crafting
```

The dispatcher and scheduled arbiter call the same classifier but execute different consequences.

---

## 27. Actual Broad Classification Diagram After Arbiter Mapping

```mermaid
flowchart TD
    Fetch[0527 logistics wrapper] -->|no fetch action| Dispatcher[single dispatcher]
    Dispatcher --> OrderTick[order_queue_0469.tick_pair]
    OrderTick --> CombatRepair[combat_repair_doctrine_0517 recommendation]
    CombatRepair -->|no tactical repair| Arbiter[action_state_arbiter_0488.action]

    Arbiter --> Conversation{conversation lock?}
    Conversation -- yes --> ConversationA[conversation -> dispatcher legacy family]
    Conversation -- no --> Combat{hostile/combat target valid?}
    Combat -- yes --> CombatA[combat -> dispatcher legacy family]
    Combat -- no --> Stale{stale combat order?}
    Stale -- yes --> IdleA[idle + scheduled fail current]
    Stale -- no --> Craft{actual timed crafting?}
    Craft -- yes --> CraftA[station-craft -> emergency production/craft executor]
    Craft -- no --> Repair{repair intent?}
    Repair -- yes --> RepairA[repair executor]
    Repair -- no --> Acquisition{acquisition/logistics/emergency/machine logistics intent?}
    Acquisition -- yes --> AcquisitionA[direct-acquisition family -> direct executor]
    Acquisition -- no --> Cons{consecration intent active?}
    Cons -- yes --> ConsA[consecration executor]
    Cons -- no --> IdleB[idle -> legacy family]
```

Important mismatch: the arbiter returns `kind = acquisition` for logistics, emergency ingredient work, machine logistics, scavenging, mining, and direct acquisition. The dispatcher then normalizes all of these to `direct-acquisition`, unless the external 0527 logistics wrapper acts first.

---

## 28. Architectural Gaps Exposed

1. **Visual arbiter has behavioral side effects.** It fails orders and clears task fields.
2. **Acquisition is overloaded.** Direct mining, storage fetch, machine logistics, scavenging, and emergency ingredient work share one kind.
3. **Current-target priority can preserve stale targets.** Nested order/task targets outrank later pair fields.
4. **The arbiter runs independently of the dispatcher.** Eleven-tick state mutation continues even if dispatcher timing or ownership differs.
5. **Conversation outranks combat classification.** An active conversation flag returns conversation before evaluating hostile targets.
6. **Repair outranks acquisition, but acquisition outranks consecration.** This is the actual current ordering.
7. **Crafting clears acquisition state.** A misclassified craft can delete direct/scavenge/inventory work.
8. **Remote scan and remote laser differ.** Scan requests movement but remains allowed; laser requests movement and is suppressed.
9. **Broad parent status remains.** Concrete leaf truth must install later to provide precise overhead text.
10. **Wrapper order matters.** Scan, laser, work visual, and overhead functions are globally replaced/wrapped.
11. **Command surface remains.** The arbiter can be disabled at runtime through slash command.
12. **Action kind does not encode ownership.** Dispatcher must infer executor family from a broad string.

---

## 29. Debugging Decision Tree

```mermaid
flowchart TD
    Bug[Wrong action family or visuals] --> Action[M.action pair]
    Action --> Conversation{conversation selected unexpectedly?}
    Conversation -- yes --> ConvFlags[Inspect idle_player_conversation_0181 / idle_conversation]
    Conversation -- no --> Target{current_target is physically correct?}
    Target -- no --> TargetPriority[Inspect ordered target source list for stale nested target]
    Target -- yes --> Kind{order/mode normalized correctly?}
    Kind -- no --> Normalize[Inspect normalize_kind broad substring match]
    Kind -- yes --> Craft{actual_crafting result expected?}
    Craft -- no --> CraftState[Inspect due ticks, locks, and physical current target]
    Craft -- yes --> Acquisition{acquisition predicate unexpectedly true?}
    Acquisition -- yes --> Fields[Inspect emergency_craft/direct/scavenge/inventory/supply/logistics/machine logistics fields]
    Acquisition -- no --> Consecration{consecration active unexpectedly?}
    Consecration -- yes --> ConsState[Inspect 0515 phase/order kind]
    Consecration -- no --> Dispatcher[Inspect dispatcher normalization/executor ownership]

    Dispatcher --> Visual{Only visual wrong?}
    Visual -- yes --> WrapperOrder[Inspect arbiter vs active leaf overhead/work visual wrapper order]
    Visual -- no --> Mutation{Task disappeared?}
    Mutation -- yes --> CraftClear[Check arbiter crafting branch clearing direct/scavenge/inventory]
```

---

## 30. Progressive Development Targets

The next procedural map should cover:

1. `order_queue_0469.lua`, because it mutates scheduler state immediately before dispatcher/arbiter classification and receives stale-combat failure calls from this arbiter.

Then:

2. `emergency_production_executor_0514.lua`.
3. `consecration_executor_0515.lua`.
4. `repair_executor_0516.lua`.
5. `combat_repair_doctrine_0517.lua`.
6. Machine logistics 0528 and inventory steward/catalog systems.
7. Legacy combat and idle/conversation systems.

After those are mapped, the overview Mermaid tree should be regenerated from the verified function maps rather than the earlier intended architecture alone.
