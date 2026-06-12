# Tech-Priests Mermaid Behavior Map

Version: 0.1.660-map-pass-1  
Base behavior map: `docs/BEHAVIOR_FUNCTION_MAP_0659.md`  
Purpose: provide a visual, iterative, code-shaped behavior map of how the Tech-Priest pair systems currently act on each other.

This document is intended to grow over multiple commits. It should be updated whenever a behavior authority, dispatcher wrapper, movement owner, overhead/visual owner, construction owner, logistics owner, or direct-acquisition owner changes.

## Reading Rules

The diagrams use these conventions:

- **Authority** means a module can change pair state, movement target, task ownership, or visible status.
- **Observer** means a module reports state but should not decide behavior.
- **Leaf task** means the actual concrete action being performed right now.
- **Parent order** means the broader objective that created a chain of leaf tasks.
- **Movement truth** means the target the priest's feet and vector enforcer should obey.
- **Visual truth** means the target shown to the player through overhead text and selected intent line.

The existing prose behavior map states the governing rule: each behavior should have a clear entry condition, active owner, movement target, overhead status, and exit condition. If a future patch adds a behavior without placing it in this map, it is probably another hidden competing authority.

---

## 1. Current Authority Install Order

This shows the order currently installed through `planning_constraints_0646.lua` after the 0.1.659 scavenge consolidation.

```mermaid
flowchart TD
    PC[planning_constraints_0646.install]

    PC --> DAPG[direct_acquisition_physical_guard_0649]
    PC --> PAH[proxy_ammo_hardener_0649]
    PC --> DAML[direct_acquisition_movement_lock_0650]
    PC --> MTR[movement_target_reconciler_0652]
    PC --> MIA[movement_intent_authority_0654]
    PC --> CPA[construction_placement_authority_0656]
    PC --> ALTT[active_leaf_task_truth_0655]
    PC --> LMSB[logistics_mineable_source_bridge_0657]
    PC --> VILA[visual_intent_line_authority_0657]
    PC --> MVE[movement_vector_enforcer_0651]

    DAPG --> DirectTruth[physical direct target exists]
    DAML --> DirectTruth
    MTR --> MovementTruth[movement request rewritten]
    MIA --> MovementTruth
    CPA --> ConstructionTruth[construction leaf task published]
    ALTT --> LeafTruth[active_leaf_task_0655]
    LMSB --> SalvageFallback[mineable fallback]
    VILA --> VisualTruth[intent line target]
    MVE --> VectorEnforce[enforce current movement request]

    DirectTruth --> LeafTruth
    ConstructionTruth --> LeafTruth
    LeafTruth --> MovementTruth
    LeafTruth --> VisualTruth
    MovementTruth --> VectorEnforce
```

Critical rule: target/leaf truth must run before vector enforcement. Vector enforcement must never decide the target; it only enforces whatever movement target is already authoritative.

---

## 2. Global Pair Tick / Service Shape

This is the broad order of operations as the pair is serviced by runtime broker / nth-tick handlers and wrapped dispatchers.

```mermaid
flowchart TD
    Tick[Runtime tick / service pulse] --> Valid{Pair valid?}
    Valid -- no --> Invalid[BT-020 cleanup / invalid pair recovery]
    Valid -- yes --> Threat{Combat or survival threat?}

    Threat -- yes --> Combat[BT-100 combat / defense / ammo]
    Combat --> AmmoCheck{Proxy gun has ammo?}
    AmmoCheck -- no --> ProxyAmmo[proxy_ammo_hardener_0649 loads proxy from station]
    AmmoCheck -- yes --> CombatAct[combat behavior continues]

    Threat -- no --> BuildReady{Station has buildable infrastructure item?}
    BuildReady -- yes --> BuildAuthority[construction_placement_authority_0656]
    BuildAuthority --> BuildLeaf[active leaf: walking to build / placing]
    BuildLeaf --> MovementRequest[authoritative movement_request_0418]

    BuildReady -- no --> ExistingLeaf{Concrete active leaf task exists?}
    ExistingLeaf -- yes --> LeafTruth[active_leaf_task_truth_0655]
    ExistingLeaf -- no --> FetchNeed{Needed item missing from station?}

    FetchNeed -- yes --> LogisticsFetch[logistics_fetch_executor_0527]
    LogisticsFetch --> FetchSource{Real inventory / loose stack source found?}
    FetchSource -- yes --> FetchLeaf[active leaf: fetching item from source]
    FetchSource -- no --> MineableFallback{Known source is mineable without inventory?}
    MineableFallback -- yes --> MineableBridge[logistics_mineable_source_bridge_0657]
    MineableFallback -- no --> DirectNeed{Need raw resource?}

    DirectNeed -- yes --> DirectAcq[direct_acquisition_executor_0513]
    DirectAcq --> DirectGuard[physical target guard + movement lock]
    DirectGuard --> MineLeaf[active leaf: mining immediate resource]

    DirectNeed -- no --> Emergency{Need devolved emergency production?}
    Emergency -- yes --> EmergencyProd[emergency_production_executor_0514]
    EmergencyProd --> DevolvedLeaf[leaf task should describe current material step]

    Emergency -- no --> Consecrate{Maintenance / consecration available?}
    Consecrate -- yes --> Consecration[consecration_executor_0515]
    Consecration --> ConsecrateLeaf[active leaf: walking to consecrate / consecrating]

    Consecrate -- no --> Idle[BT-900 idle / waiting / chatter]

    FetchLeaf --> LeafTruth
    MineLeaf --> LeafTruth
    DevolvedLeaf --> LeafTruth
    ConsecrateLeaf --> LeafTruth
    LeafTruth --> MovementRequest
    MovementRequest --> VectorEnforcer[movement_vector_enforcer_0651]
    LeafTruth --> Overhead[overhead_status_governor_0471 patched]
    LeafTruth --> VisualLine[visual_intent_line_authority_0657]
```

This graph is the current desired end-to-end behavior shape. Any module that bypasses this and writes `pair.target` or `pair.movement_request_0418` directly without publishing leaf truth is a candidate for future cleanup.

---

## 3. Behavior Priority Stack

The prose map defines the current intended priority order as pair validity, combat, construction placement, active leaf task, real-inventory logistics fetch, mineable salvage fallback, direct acquisition, emergency production, consecration, and idle.

```mermaid
flowchart TD
    Start[Pair Service] --> P0{Valid pair?}
    P0 -- no --> Cleanup[Pair cleanup / recovery]
    P0 -- yes --> P1{Combat / death / survival?}
    P1 -- yes --> Combat[Combat / defense / rearm]
    P1 -- no --> P2{Buildable structure already in station?}
    P2 -- yes --> Construction[Construction placement authority]
    P2 -- no --> P3{Existing concrete leaf target?}
    P3 -- yes --> Leaf[Active leaf task truth]
    P3 -- no --> P4{Known real inventory source for needed item?}
    P4 -- yes --> Fetch[Logistics fetch executor 0527]
    P4 -- no --> P5{Inventoryless mineable known source?}
    P5 -- yes --> Salvage[Mineable source bridge 0657]
    P5 -- no --> P6{Raw resource acquisition needed?}
    P6 -- yes --> Direct[Direct acquisition + physical guard]
    P6 -- no --> P7{Emergency production needed?}
    P7 -- yes --> Emergency[Emergency production executor]
    P7 -- no --> P8{Consecration / maintenance target?}
    P8 -- yes --> Consecrate[Consecration executor]
    P8 -- no --> Idle[Idle / chatter / wait]

    Combat --> End[End service pulse]
    Construction --> End
    Leaf --> End
    Fetch --> End
    Salvage --> End
    Direct --> End
    Emergency --> End
    Consecrate --> End
    Idle --> End
    Cleanup --> End
```

This is an intended priority stack, not yet a proven single centralized switch statement. Several pieces are still wrappers, broker services, or older subsystem calls. That matters: if behavior still fights, the next audit should identify which legacy module is bypassing this priority stack.

---

## 4. Parent Order to Leaf Task Pipeline

This diagram separates the parent objective from the concrete task the priest is actually doing.

```mermaid
flowchart LR
    Parent[Parent order / broad objective]
    Pending[Pending action / required item / blocked recipe]
    Devolve[Devolve into immediate requirement]
    Leaf[Concrete leaf task]
    Target[Real entity or position target]
    Move[Movement request]
    Display[Overhead + visual intent line]
    Exit[Exit condition]

    Parent --> Pending
    Pending --> Devolve
    Devolve --> Leaf
    Leaf --> Target
    Target --> Move
    Target --> Display
    Move --> Exit
    Display --> Exit

    subgraph Examples
        P1[Make iron plate] --> L1[Mine/fetch iron ore]
        L1 --> L2[Feed smelter]
        L2 --> L3[Retrieve iron plate]
        P2[Consecrate machine] --> L4[Walk to target machine]
        L4 --> L5[Perform rite]
        P3[Build emergency smelter] --> L6[Fetch/place smelter item]
        L6 --> L7[Create entity]
    end
```

Invariant: the overhead text and visual intent line must describe `Leaf`, not `Parent`.

---

## 5. Movement Truth Pipeline

This is the currently intended movement ownership chain.

```mermaid
flowchart TD
    LeafSource{Which module has concrete work?}
    LeafSource -->|Direct acquisition| DirectLock[direct_acquisition_target_lock_0650]
    LeafSource -->|Construction| BuildTask[construction_task_0338 / construction_priority_0656]
    LeafSource -->|Logistics| FetchTask[logistics_fetch_0527]
    LeafSource -->|Consecration| ConsecrateTask[consecration_0515]
    LeafSource -->|Emergency| EmergencyTask[emergency_craft / current subtask]

    DirectLock --> ALTT[active_leaf_task_truth_0655]
    BuildTask --> CPA[construction_placement_authority_0656]
    CPA --> ALTT
    FetchTask --> ALTT
    ConsecrateTask --> ALTT
    EmergencyTask --> ALTT

    ALTT --> PairTarget[pair.target / current_work_target_0655]
    ALTT --> PairMove[pair.movement_request_0418]
    PairMove --> MC[storage.tech_priests.movement_controller_0419.requests[key]]
    MC --> Command[Factorio go_to_location command]
    MC --> MVE[movement_vector_enforcer_0651]
    MVE --> Reissue[Reissue movement if walking away]
    Reissue --> Command
```

Debugging rule: if the priest walks the wrong way, inspect `pair.active_leaf_task_0655`, then `pair.movement_request_0418`, then the vector enforcer. Do not begin by changing the vector enforcer.

---

## 6. Visual Truth Pipeline

```mermaid
flowchart TD
    ALTT[active_leaf_task_truth_0655] --> Status[pair.actual_task_status_0655]
    ALTT --> WorkTarget[pair.current_work_target_0655]

    Status --> OverheadPatch[overhead_status_governor_0471 canonical status patch]
    WorkTarget --> VisualAuthority[visual_intent_line_authority_0657]
    Status --> VisualAuthority
    Movement[pair.movement_request_0418] --> VisualAuthority

    VisualAuthority --> HasLeaf{Active leaf or live movement request?}
    HasLeaf -- yes --> BrightLine[Draw bright line priest -> active target]
    HasLeaf -- no --> HomeLink[Draw subdued station ownership link]

    OverheadPatch --> Text[Draw overhead leaf action text]
```

The bright line is no longer supposed to mean station ownership. It is now meant to represent the current active intent target whenever a current target exists.

---

## 7. Logistics / Inventory Scavenge Flow

This map reflects the 0.1.659 consolidation: `logistics_fetch_executor_0527` owns real inventory scavenging. `nearby_inventory_scavenge_authority_0658` was removed.

```mermaid
flowchart TD
    Need[Active item need] --> Have{Station already has enough?}
    Have -- yes --> Done[Exit: already in station]
    Have -- no --> Catalog{Known catalog storage source?}

    Catalog -- yes --> Source[Source entity + inventory]
    Catalog -- no --> Nearby{Nearby real inventory source?}
    Nearby -- yes --> Source
    Nearby -- no --> Ground{Loose ground item stack?}
    Ground -- yes --> Loose[Loose item entity]
    Ground -- no --> Mineable{Known source mineable but no inventory?}

    Source --> Move[Move priest to source]
    Loose --> Move
    Move --> Adjacent{Priest adjacent?}
    Adjacent -- no --> MoveRequest[Publish logistics fetch movement request]
    MoveRequest --> Move
    Adjacent -- yes --> Remove[Remove item from exact source inventory or stack]
    Remove --> Deposit[Deposit item into Cogitator Station]
    Deposit --> Success[phase = deposited]
    Success --> Clear[Clear stale scavenge / inventory_scan / logistic_requested_item]

    Mineable -- yes --> MineableBridge[logistics_mineable_source_bridge_0657]
    Mineable -- no --> NoSource[Exit: no known fetch source]
    MineableBridge --> Salvage[Mine/salvage source into station]
    Salvage --> Success
```

Inventory source classes now intended to include containers, logistic containers, assembling machines, furnaces, mining drills, labs, cars, spider vehicles, cargo wagons, artillery wagons, rocket silos, roboports, ammo turrets, artillery turrets, character corpses, and loose item stacks.

---

## 8. Direct Acquisition Flow

```mermaid
flowchart TD
    NeedRaw[Need raw resource / immediate material] --> ExistingFetch{Can logistics fetch satisfy it from inventory?}
    ExistingFetch -- yes --> Fetch0527[logistics_fetch_executor_0527]
    ExistingFetch -- no --> CreateDirect[direct_acquisition_executor_0513 task]

    CreateDirect --> HasEntity{Task has valid physical target entity?}
    HasEntity -- no --> PhysicalGuard[direct_acquisition_physical_guard_0649]
    PhysicalGuard --> Adopt{Nearby matching physical target found?}
    Adopt -- yes --> LockTarget[direct_acquisition_movement_lock_0650]
    Adopt -- no --> ClearTask[Clear stale/synthetic direct task]

    HasEntity -- yes --> LockTarget
    LockTarget --> TargetReconcile[movement_target_reconciler_0652]
    TargetReconcile --> IntentAuthority[movement_intent_authority_0654]
    IntentAuthority --> LeafTruth[active_leaf_task_truth_0655]
    LeafTruth --> MoveToTarget[Move to ore / rock / tree]
    MoveToTarget --> Adjacent{At target?}
    Adjacent -- no --> VectorEnforce[movement_vector_enforcer_0651]
    Adjacent -- yes --> Mine[Mine / extract immediate resource]
    Mine --> Deposit[Deposit to station]
    Deposit --> Complete[Direct task complete or parent chain continues]
```

Invariant: if the parent needs iron plate but the direct task is mining ore, the displayed leaf action is `Mining iron ore`.

---

## 9. Construction / Infrastructure Flow

```mermaid
flowchart TD
    Survey[master_infrastructure_plan_0644] --> Stage{Which infrastructure gap?}
    Stage --> Smelting[Smelting capability]
    Stage --> Storage[Storage buffer]
    Stage --> Resource[Resource extraction]
    Stage --> Crafting[Crafting capability]
    Stage --> Research[Research capability]

    Smelting --> Ghost[construction_bootstrap_ghost_planner_0645]
    Storage --> Ghost
    Resource --> Ghost
    Crafting --> Ghost
    Research --> Ghost

    Ghost --> HasItem{Station has placeable item?}
    HasItem -- no --> NeedMaterials[Parent order / emergency production / logistics fetch]
    NeedMaterials --> Logistics0527[Fetch existing items first]
    Logistics0527 --> DirectAcq[Direct acquisition if no inventory source]
    DirectAcq --> EmergencyProd[Emergency production if needed]
    EmergencyProd --> HasItem

    HasItem -- yes --> PlacementAuthority[construction_placement_authority_0656]
    PlacementAuthority --> SitePlanner[construction_site_planner.lua]
    SitePlanner --> Site{Valid site found?}
    Site -- no --> Blocked[Exit: blocked / no site]
    Site -- yes --> ConstructionPlanner[construction_planner.lua]
    ConstructionPlanner --> MoveBuild[Move priest to build site]
    MoveBuild --> AtSite{At site?}
    AtSite -- no --> ConstructionMove[construction movement request]
    ConstructionMove --> MoveBuild
    AtSite -- yes --> RemoveItem[Remove one structure item from station inventory]
    RemoveItem --> CreateEntity[Create entity]
    CreateEntity --> Built[Exit: infrastructure physically placed]
```

Construction should preempt additional acquisition once a buildable structure item exists in the station.

---

## 10. Consecration / Maintenance Flow

```mermaid
flowchart TD
    Candidate[Consecration executor scans/receives machine target] --> ValidTarget{Target machine valid?}
    ValidTarget -- no --> ExitNoTarget[Exit: no target]
    ValidTarget -- yes --> InRange{Priest within rite range?}

    InRange -- no --> WalkLeaf[Leaf: Walking to consecrate machine]
    WalkLeaf --> MoveRequest[Movement request to target machine]
    MoveRequest --> Visual[Intent line priest -> machine]
    MoveRequest --> Overhead[Overhead: Walking to consecrate machine]
    MoveRequest --> InRange

    InRange -- yes --> RiteLeaf[Leaf: Consecrating machine]
    RiteLeaf --> Perform[Perform rite / maintenance]
    Perform --> Complete{Rite complete?}
    Complete -- no --> RiteLeaf
    Complete -- yes --> Exit[Exit: consecration complete]
```

If this behavior visibly points to a station while claiming consecration, the bug is in the leaf truth / movement request / visual intent chain, not in the rite itself.

---

## 11. Combat / Ammo Flow

```mermaid
flowchart TD
    Threat[Threat / combat target / survival mode] --> NeedAmmo{Proxy has usable ammo?}
    NeedAmmo -- yes --> Fight[Engage / defend]
    NeedAmmo -- no --> StationAmmo{Station has ammo?}
    StationAmmo -- yes --> ProxyHardener[proxy_ammo_hardener_0649]
    ProxyHardener --> Load[Move ammo into hidden proxy gun]
    Load --> Fight
    StationAmmo -- no --> AmmoNeed[Need ammo item]
    AmmoNeed --> FetchAmmo[logistics_fetch_executor_0527 fetches existing ammo]
    FetchAmmo --> StationAmmo
    AmmoNeed --> CraftAmmo[Emergency production / direct acquisition if fetch fails]
    CraftAmmo --> StationAmmo
    Fight --> ThreatGone{Threat gone?}
    ThreatGone -- no --> Fight
    ThreatGone -- yes --> NormalPriority[Return to normal behavior priority stack]
```

Combat may preempt normal work. Ammo satisfaction must mean the proxy can actually fire, not merely that ammunition exists somewhere in station storage.

---

## 12. Emergency Production / Devolved Work Flow

```mermaid
flowchart TD
    ParentNeed[Parent item needed] --> CanFetch{Existing source has parent item?}
    CanFetch -- yes --> FetchParent[logistics_fetch_executor_0527]
    CanFetch -- no --> Recipe{Recipe / emergency recipe available?}
    Recipe -- no --> DirectRaw[Direct raw acquisition / salvage]
    Recipe -- yes --> Ingredients{Ingredients available in station?}

    Ingredients -- yes --> Craft[Emergency production executor crafts]
    Ingredients -- no --> Devolve[Create immediate ingredient need]
    Devolve --> IngredientFetch{Ingredient exists in nearby inventory?}
    IngredientFetch -- yes --> FetchIngredient[logistics_fetch_executor_0527]
    IngredientFetch -- no --> IngredientRaw{Ingredient is raw/minable?}
    IngredientRaw -- yes --> MineIngredient[direct_acquisition_executor_0513]
    IngredientRaw -- no --> FurtherDevolve[Further devolve / blocked]

    FetchIngredient --> Ingredients
    MineIngredient --> Ingredients
    FurtherDevolve --> Ingredients
    Craft --> Product[Deposit / make product available]
    Product --> ParentComplete{Parent need satisfied?}
    ParentComplete -- no --> Devolve
    ParentComplete -- yes --> Exit[Exit: parent objective can continue]
```

Display rule: if the priest is currently fetching/mine/crafting an ingredient, overhead shows the ingredient leaf action, not the parent item.

---

## 13. Diagnostics / Debugging Decision Tree

```mermaid
flowchart TD
    Bug[Priest appears wrong] --> LeafQ{active_leaf_task_0655 correct?}
    LeafQ -- no --> FixLeaf[Fix leaf task publisher / parent-to-leaf decomposition]
    LeafQ -- yes --> MoveQ{movement_request_0418 points to leaf target?}
    MoveQ -- no --> FixMove[Fix movement authority / request writer]
    MoveQ -- yes --> VisualQ{Intent line points to movement target?}
    VisualQ -- no --> FixVisual[Fix visual_intent_line_authority_0657 / network visuals]
    VisualQ -- yes --> VectorQ{Vector enforcer moving toward request?}
    VectorQ -- no --> FixVector[Fix movement_vector_enforcer_0651]
    VectorQ -- yes --> ActionQ{At target but not acting?}
    ActionQ -- yes --> FixExecutor[Fix executor exit/action logic]
    ActionQ -- no --> Wait[Observe next tick / inspect broad node]

    FixLeaf --> Retest[Retest same save/log]
    FixMove --> Retest
    FixVisual --> Retest
    FixVector --> Retest
    FixExecutor --> Retest
```

This decision tree is meant to stop repair work from adding duplicate authorities before identifying which layer diverged first.

---

## 14. Known Incomplete Areas For Future Map Passes

The following areas need deeper per-module Mermaid maps in later commits:

1. `single_dispatcher_0510.lua` exact branch order.
2. Combat/defense modules and their interaction with proxy ammo.
3. Inventory steward family and all safe deposit/count helpers.
4. Emergency production recipe decomposition and blocked-item state fields.
5. Station catalog scan/update cycle and known-source selection.
6. Consecration target selection, rite timing, and completion state.
7. Remaining legacy modules that still write `pair.target`, `pair.mode`, or `pair.movement_request_0418` directly.
8. Remaining slash-command cleanup map for old diagnostic modules.

Any one of these can become the next sequential Mermaid-map commit.
