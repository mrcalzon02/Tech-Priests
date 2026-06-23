# Tech-Priests Function-Level Mermaid Drilldown: Master Infrastructure Plan + Bootstrap Ghost Planner

Version: 0.1.666-map-pass-7  
Previous drilldown: `docs/BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_0665_CONSTRUCTION.md`  
Companion overview: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

Purpose: map the upstream infrastructure-planning chain that decides what station-local capability should exist next and turns that decision into one persistent construction planning ghost.

Mapped modules:

- `master_infrastructure_plan_0644.lua`
- `construction_bootstrap_ghost_planner_0645.lua`

Downstream modules already mapped:

- `construction_site_planner.lua`
- `construction_planner.lua`
- `construction_placement_authority_0656.lua`

Important current-code truth:

- The active infrastructure sequence is still a fixed bootstrap spine:
  1. smelting
  2. storage
  3. resource extraction when a local resource exists
  4. crafting
  5. research
- `next_small_science_objective()` is calculated and stored on the bootstrap ghost record, but it does **not currently select or decompose the infrastructure plan**. It is metadata, not yet an active planning authority.
- The ghost planner creates only one station-local planning ghost at a time.

---

## 1. End-to-End Planning Chain

```mermaid
flowchart TD
    Survey[master_infrastructure_plan_0644 survey]
    Resources[scan_resources]
    Roles[scan_roles]
    Choose[choose next missing bootstrap role]
    Plan[pair.master_infrastructure_plan_0644]
    GhostPlanner[construction_bootstrap_ghost_planner_0645]
    SitePlanner[construction_site_planner.plan_site]
    Ghost[one entity-ghost]
    Construction[construction_planner]
    Placement[construction_placement_authority_0656]
    Built[physical infrastructure entity]

    Survey --> Resources
    Survey --> Roles
    Resources --> Choose
    Roles --> Choose
    Choose --> Plan
    Plan --> GhostPlanner
    GhostPlanner --> SitePlanner
    SitePlanner --> Ghost
    Ghost --> Construction
    Construction --> Placement
    Placement --> Built
    Built --> Survey
```

Once the physical entity exists, the next survey should detect the completed role and advance to the next missing role.

---

## 2. Fixed Bootstrap Target Table

```mermaid
flowchart LR
    Smelter[smelting
stage bootstrap-smelting
preferred emergency smelter
fallback stone furnace]
    Storage[storage
stage bootstrap-storage
preferred Martian stone cache
fallback wooden chest]
    Miner[resource extraction
stage bootstrap-mining
preferred emergency miner
fallback burner mining drill]
    Assembler[crafting
stage basic-crafting
preferred emergency assembler
fallback assembling machine 1]
    Lab[research
stage research-readiness
preferred emergency laboratorium
fallback lab]

    Smelter --> Storage --> Miner --> Assembler --> Lab
```

Delivery metadata stored on targets:

| Target | Delivery metadata |
|---|---|
| Smelter | `direct-ore-and-fuel-service` |
| Storage | `place-near-station` |
| Miner | `direct-service-until-belts` |
| Assembler | `place-near-storage` |
| Lab | `place-after-basic-crafting` |

These delivery strings are currently plan metadata. They do not themselves execute belt, inserter, train, or priest-transfer construction.

---

## 3. `master_infrastructure_plan_0644.lua` Function Inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `now`, `valid`, `safe`, `pair_map`, `valid_pair`, `station_unit`, `priest_unit`, `dist_sq` | local helpers | Time, entity, formatting, pair identity, distance | none |
| `root()` | local storage root | Ensures planner state | writes `storage.tech_priests.master_infrastructure_plan_0644` |
| `stat(name,n)` | local metric | Increments planner stats | writes root stats |
| `record(action,pair,detail)` | local metric/history | Stores recent planning events | writes root recent |
| `radius_for(pair)` | local helper | Gets station operating radius | calls `_G.get_station_operating_radius` or pair radius |
| `safe_inventory(entity,id)` | local inventory helper | Gets inventory safely | none |
| `inv_count(inv,item)` | local inventory count | Counts item | none |
| `station_count(pair,item)` | local aggregate count | Counts preferred/fallback item across steward sources and station chest | reads inventory steward sources and station chest |
| `item_available(pair,preferred,fallback)` | local selector | Chooses preferred item, fallback item, or missing preferred | none |
| `scan_resources(pair)` | local survey | Summarizes resource entities in station radius | scans surface resources |
| `entity_role(e)` | local classifier | Converts nearby entity into infrastructure role | none |
| `scan_roles(pair)` | local survey | Counts nearby infrastructure roles | scans same-force entities in radius |
| `has_role(roles,a,b)` | local predicate | Tests whether either role exists | none |
| `first_resource(resources)` | local selector | Chooses highest-priority local resource | none |
| `choose(pair,resources,roles)` | local planner | Selects first missing infrastructure target | reads station inventory for item availability |
| `summarize(t)` | local formatter | Makes resource/role summary strings | none |
| `M.build_plan(pair,reason)` | public planner | Builds full station survey plan | writes `pair.master_infrastructure_plan_0644` |
| `M.service_pair(pair,reason)` | public service | Builds plan and records outcome | writes stats/recent through helpers |
| `M.service_all(reason)` | public loop | Services valid pairs | calls `M.service_pair` |
| `install_bootstrap()` | local installer | Requires and installs ghost planner | invokes `construction_bootstrap_ghost_planner_0645.install` |
| `M.install()` | public installer | Exposes module and registers periodic survey | writes `_G.TechPriestsMasterInfrastructurePlan0644` |

---

## 4. Resource Survey Flow

```mermaid
flowchart TD
    Scan[scan_resources] --> Valid{valid pair?}
    Valid -- no --> Empty[return empty table]
    Valid -- yes --> Radius[radius_for]
    Radius --> Find[find resource entities around station]
    Find --> Loop[for each resource]
    Loop --> ResourceValid{valid, inside radius, amount > 0?}
    ResourceValid -- no --> Next[next resource]
    ResourceValid -- yes --> Bucket[out resource name]
    Bucket --> Count[count entities]
    Bucket --> Amount[sum resource amount]
    Count --> Next
    Amount --> Next
    Next --> Done{all resources processed?}
    Done -- yes --> Return[return resource summary]
```

### Resource priority

```mermaid
flowchart LR
    Iron[iron ore priority 10] --> Copper[copper ore priority 20]
    Copper --> Coal[coal priority 30]
    Coal --> Stone[stone priority 40]
    Stone --> Uranium[uranium ore priority 90]
    Uranium --> Other[other resource priority 1000]
```

`first_resource()` sorts only the names found in the resource survey. It does not choose a patch position; physical miner placement is delegated to the construction site planner.

---

## 5. Infrastructure Role Classification

```mermaid
flowchart TD
    Entity[entity_role] --> Type{entity.type}
    Type -- mining-drill --> MinerName{emergency miner name?}
    MinerName -- yes --> EmergencyMiner[emergency-miner]
    MinerName -- no --> NormalMiner[normal-miner]

    Type -- furnace --> NormalSmelter[normal-smelter]

    Type -- assembling-machine --> AssemblerName{name}
    AssemblerName -- emergency smelter --> EmergencySmelter[emergency-smelter]
    AssemblerName -- emergency miner --> EmergencyMiner2[emergency-miner]
    AssemblerName -- emergency assembler --> EmergencyAssembler[emergency-assembler]
    AssemblerName -- other --> NormalAssembler[normal-assembler]

    Type -- container/logistic-container --> Storage[storage]
    Type -- lab --> Lab[lab]
    Type -- other --> None[no role]
```

The emergency smelter is recognized as an assembling-machine by Factorio type but explicitly reclassified as `emergency-smelter` by name.

---

## 6. Role Survey Flow

```mermaid
flowchart TD
    Scan[scan_roles] --> Valid{valid pair?}
    Valid -- no --> Empty[return empty roles]
    Valid -- yes --> Radius[radius_for]
    Radius --> Find[find same-force entities in station radius]
    Find --> Loop[for each entity]
    Loop --> Role[entity_role]
    Role --> HasRole{recognized role and entity not station?}
    HasRole -- yes --> Increment[roles role += 1]
    HasRole -- no --> Next[next entity]
    Increment --> Next
    Next --> Done{all processed?}
    Done -- yes --> Return[return roles]
```

Role existence is counted, not evaluated for operational condition. A damaged, unpowered, unconfigured, or inaccessible machine can still satisfy the role survey if it exists and is recognized.

---

## 7. Item Availability / Preferred-Fallback Flow

```mermaid
flowchart TD
    Available[item_available preferred fallback] --> Preferred{preferred item count > 0?}
    Preferred -- yes --> UsePreferred[return preferred, nil]
    Preferred -- no --> Fallback{fallback item count > 0?}
    Fallback -- yes --> UseFallback[return fallback, preferred]
    Fallback -- no --> Missing[return preferred or fallback, alternate fallback metadata]
```

Meaning of returned fields inside the target plan:

- `preferred_item` becomes the item that should actually be used next.
- `fallback_item` is populated when the chosen item is a fallback or when both names are being recorded for a missing target.
- `blocker` is cleared only when the selected `preferred_item` is already present in station inventory.

Potential naming confusion: when a fallback item is physically available, the returned `preferred_item` becomes that fallback item, while `fallback_item` stores the original emergency/preferred item.

---

## 8. Master Target Selection Flow

```mermaid
flowchart TD
    Choose[choose] --> Smelter{has emergency or normal smelter?}
    Smelter -- no --> TargetSmelter[TARGETS.smelter]
    Smelter -- yes --> Storage{has storage?}
    Storage -- no --> TargetStorage[TARGETS.storage]
    Storage -- yes --> Resource{first_resource exists?}
    Resource -- yes --> Miner{has emergency or normal miner?}
    Miner -- no --> TargetMiner[TARGETS.miner]
    Miner -- yes --> Assembler
    Resource -- no --> Assembler{has emergency or normal assembler?}
    Assembler -- no --> TargetAssembler[TARGETS.assembler]
    Assembler -- yes --> Lab{has lab?}
    Lab -- no --> TargetLab[TARGETS.lab]
    Lab -- yes --> Ready[stage ready; local bootstrap spine appears present]

    TargetSmelter --> Availability[item_available]
    TargetStorage --> Availability
    TargetMiner --> Availability
    TargetAssembler --> Availability
    TargetLab --> Availability
    Availability --> Result[planned target with class, stage, item, resource, blocker, delivery]
```

Important detail: when no local resource exists, the miner branch is skipped and the planner proceeds to assembler. The fixed sequence is therefore conditional at the miner stage.

---

## 9. Master Plan Build Flow

```mermaid
flowchart TD
    Build[M.build_plan] --> Valid{valid pair?}
    Valid -- no --> Invalid[return invalid-pair]
    Valid -- yes --> Resources[scan_resources]
    Resources --> Roles[scan_roles]
    Roles --> Target[choose]
    Target --> Plan[assemble plan record]
    Plan --> Fields[version tick station priest radius reason resources roles summaries target stage status blocker]
    Fields --> Store[pair.master_infrastructure_plan_0644 = plan]
    Store --> Return[return plan planned]
```

### Stored plan shape

```mermaid
flowchart LR
    Plan[pair.master_infrastructure_plan_0644]
    Plan --> Identity[version / tick / station / priest]
    Plan --> Survey[radius / resources / roles]
    Plan --> Summaries[resource_summary / role_summary]
    Plan --> Target[target table]
    Plan --> Phase[stage / status / blocker]
    Plan --> Reason[reason]
```

---

## 10. Master Planner Service / Install Flow

```mermaid
flowchart TD
    Service[M.service_pair] --> Enabled{root enabled?}
    Enabled -- no --> Disabled[return disabled]
    Enabled -- yes --> Build[M.build_plan]
    Build --> Plan{plan created?}
    Plan -- yes --> Stats[plans_built + record plan-built-0644]
    Stats --> Success[return true]
    Plan -- no --> Failed[plans_failed]
    Failed --> ReturnFail[return false]

    Install[M.install] --> Root[root]
    Root --> Global[_G.TechPriestsMasterInfrastructurePlan0644 = M]
    Global --> Bootstrap[install_bootstrap]
    Bootstrap --> RequireGhost[require ghost planner and call install]
    RequireGhost --> Broker{runtime tick broker?}
    Broker -- yes --> Register[register master planner category diagnostics priority 980 interval 97]
    Broker -- no --> Registry[register nth tick fallback]
```

The master planner is registered in the `diagnostics` category at very late priority, despite producing active plan state. The ghost planner can call `M.build_plan` directly, so it does not depend on the late periodic survey having already run.

---

## 11. `construction_bootstrap_ghost_planner_0645.lua` Function Inventory

| Function | Type | Role | Major side effects |
|---|---:|---|---|
| `now`, `valid`, `safe`, `lower`, `pair_map`, `valid_pair`, `station_unit`, `priest_unit` | local helpers | Time/entity/formatting/pair access | none |
| `planning_constraints()` | local dependency | Gets constraints module | may require `planning_constraints_0646` |
| `root()` | local storage root | Ensures ghost planner state | writes `storage.tech_priests.construction_bootstrap_ghost_planner_0645` |
| `stat`, `record` | local metrics/history | Tracks ghost events | writes root stats/recent |
| `entity_exists(name)` | local prototype helper | Checks entity prototype | reads prototypes |
| `entity_name_for_item(item)` | local mapper | Converts item or entity name into placeable entity name | reads item `place_result` |
| `category_for(entity_name,class)` | local classifier | Chooses construction site category | reads explicit name map and entity type |
| `build_plan(pair,reason)` | local planner dependency | Calls master infrastructure `build_plan` or uses stored plan | may write `pair.master_infrastructure_plan_0644` |
| `plan_site(pair,entity_name,category)` | local site dependency | Calls construction site planner | none |
| `active_ghost(pair)` | local ghost resolver | Finds valid stored ghost or reacquires entity-ghost at recorded position | may update `rec.ghost` |
| `target_complete(pair,rec)` | local completion test | Checks for built target entity near recorded position | scans world |
| `science_pack_name(ingredient)` | local extractor | Reads science pack name | none |
| `technology_unlocked(tech)` | local predicate | Checks researched flag | none |
| `prerequisites_met(tech)` | local predicate | Checks all technology prerequisites researched | none |
| `next_small_science_objective(pair)` | local selector | Chooses lowest-score available technology | reads force technologies |
| `should_bootstrap(pair,plan)` | local predicate | Requires valid pair, target, and stage not ready | none |
| `create_planning_ghost(pair,entity_name,pos)` | local world mutator | Creates non-expiring entity ghost | mutates surface |
| `make_record(pair,plan,entity_name,pos,why,ghost)` | local writer | Creates bootstrap ghost record | writes `pair.construction_bootstrap_ghost_0645` |
| `M.service_pair(pair,reason)` | public service | Maintains existing ghost or creates next one | writes/clears ghost record and world ghost |
| `M.service_all(reason)` | public loop | Services valid pairs | calls `M.service_pair` |
| `M.install()` | public installer | Exposes module and registers service | writes `_G.TechPriestsConstructionBootstrapGhostPlanner0645` |

---

## 12. Item-to-Entity and Category Mapping

```mermaid
flowchart TD
    Item[entity_name_for_item] --> EntityPrototype{item string is already entity prototype?}
    EntityPrototype -- yes --> ReturnSame[return item as entity name]
    EntityPrototype -- no --> ItemPrototype{item prototype exists?}
    ItemPrototype -- no --> Nil[return nil]
    ItemPrototype -- yes --> PlaceResult[item.place_result.name]
    PlaceResult --> ResultExists{entity prototype exists?}
    ResultExists -- yes --> ReturnResult[return entity name]
    ResultExists -- no --> Nil

    Category[category_for] --> Explicit{ENTITY_CATEGORY_BY_NAME hit?}
    Explicit -- yes --> ReturnExplicit[return mapped emergency category]
    Explicit -- no --> Base[CATEGORY_BY_CLASS or generic]
    Base --> Prototype{entity prototype exists?}
    Prototype -- no --> ReturnBase[return base]
    Prototype -- yes --> Type{entity type}
    Type -- mining-drill --> Miner[miner]
    Type -- furnace --> Furnace[furnace]
    Type -- assembling-machine --> Assembler[assembler]
    Type -- container/logistic-container --> Storage[storage]
    Type -- lab --> Lab[lab]
    Type -- electric-pole --> Pole[emergency-power-pole]
    Type -- other --> ReturnBase
```

---

## 13. Active Ghost Resolution Flow

```mermaid
flowchart TD
    Active[active_ghost] --> Record{pair.construction_bootstrap_ghost_0645 is table?}
    Record -- no --> ReturnNone[return nil and raw value]
    Record -- yes --> Ghost{rec.ghost valid?}
    Ghost -- yes --> ReturnGhost[return ghost and record]
    Ghost -- no --> Unit{rec.unit_number and valid pair?}
    Unit -- no --> ReturnMissing[return nil and record]
    Unit -- yes --> Find[find entity-ghost at rec.position]
    Find --> Found{valid ghost?}
    Found -- yes --> Rebind[rec.ghost = found]
    Rebind --> ReturnFound[return found and record]
    Found -- no --> ReturnMissing
```

The reacquisition condition checks `rec.unit_number`, but `surface.find_entity` uses only ghost name and recorded position. The stored unit number is acting as a marker that a real ghost had once existed.

---

## 14. Built Target Completion Flow

```mermaid
flowchart TD
    Complete[target_complete] --> Valid{valid pair record and entity_name?}
    Valid -- no --> False[return false]
    Valid -- yes --> Find[find same-force entity by name within 2.25 of recorded position]
    Find --> Exists{one or more found?}
    Exists -- yes --> True[return true]
    Exists -- no --> False
```

Completion is based on a matching physical entity near the planned position, not on ghost disappearance alone.

---

## 15. Science Objective Selector

```mermaid
flowchart TD
    Science[next_small_science_objective] --> Valid{valid pair and force technologies?}
    Valid -- no --> Nil[return nil]
    Valid -- yes --> Loop[for each force technology]
    Loop --> Candidate{valid, unresearched, prerequisites met, enabled?}
    Candidate -- no --> Next[next technology]
    Candidate -- yes --> Count[read research_unit_count]
    Count --> Packs[collect research_unit_ingredients]
    Packs --> Score[score = unit_count + pack_count * 10000]
    Score --> Better{lower score or name tie-break?}
    Better -- yes --> Best[store technology name/count/packs/score]
    Better -- no --> Next
    Best --> Next
    Next --> Done{all technologies processed?}
    Done -- yes --> Return[return best]
```

### Current science authority boundary

```mermaid
flowchart LR
    ScienceSelector[next_small_science_objective]
    GhostRecord[pair.construction_bootstrap_ghost_0645.next_science]
    MasterChoose[master infrastructure choose]
    ActualTarget[plan.target]

    ScienceSelector --> GhostRecord
    MasterChoose --> ActualTarget
    GhostRecord -. currently does not drive .-> MasterChoose
```

The score heavily prioritizes technologies requiring fewer distinct science pack types, because every science pack ingredient adds 10,000 points. Research unit count is a secondary factor.

---

## 16. Ghost Creation and Record Flow

```mermaid
flowchart TD
    Create[create_planning_ghost] --> Valid{valid pair/entity/position?}
    Valid -- no --> Invalid[return invalid]
    Valid -- yes --> World[create entity-ghost]
    World --> Created{ghost valid?}
    Created -- yes --> Success[return ghost-created]
    Created -- no --> Failed[return ghost-create-failed]

    Record[make_record] --> Target[read plan.target]
    Target --> Fields[version tick station entity item class stage fallback resource delivery blocker reason site_reason position status ghost unit]
    Fields --> Science[next_small_science_objective]
    Science --> Connection[connection_mode manual-priest-transfer]
    Connection --> Note[one station-local planning ghost; not completed infrastructure]
    Note --> Store[pair.construction_bootstrap_ghost_0645 = record]
```

`connection_mode = manual-priest-transfer` is currently metadata. It does not actively build belts, dispatch trains, or create interstation logistics.

---

## 17. Ghost Planner Main Service Flow

```mermaid
flowchart TD
    Service[M.service_pair] --> Enabled{root enabled?}
    Enabled -- no --> Disabled[return disabled]
    Enabled -- yes --> Valid{valid pair?}
    Valid -- no --> Invalid[return invalid-pair]
    Valid -- yes --> Existing[active_ghost]
    Existing --> HasGhost{valid ghost and record?}
    HasGhost -- yes --> Refresh[rec.status ghosted; rec.last_seen_tick now]
    Refresh --> ActiveExit[return active-ghost-present]

    HasGhost -- no --> HasRecord{record exists?}
    HasRecord -- yes --> Complete[target_complete]
    Complete --> Built{target physical entity exists?}
    Built -- yes --> MarkBuilt[rec.status built; completed_tick; record event]
    MarkBuilt --> ClearBuilt[pair.construction_bootstrap_ghost_0645 = nil]
    Built -- no --> Retry{now - rec.tick < retry_ticks?}
    Retry -- yes --> Cooldown[return ghost-missing-cooldown]
    Retry -- no --> Lost[record lost event; clear record]
    HasRecord -- no --> Build
    ClearBuilt --> Build[build_plan]
    Lost --> Build

    Build --> Bootstrap{should_bootstrap: target and stage not ready?}
    Bootstrap -- no --> NotBootstrap[return not-bootstrap]
    Bootstrap -- yes --> Target[plan.target preferred_item]
    Target --> Entity[entity_name_for_item]
    Entity --> Placeable{entity name found?}
    Placeable -- no --> NoEntity[record no-entity event; return target-not-placeable]
    Placeable -- yes --> Unlock{planning constraints entity_unlocked?}
    Unlock -- no --> Locked[record technology locked; return reason]
    Unlock -- yes --> Site[plan_site]
    Site --> HasSite{position found?}
    HasSite -- no --> BlockRecord[store blocked-no-site record with next_science]
    BlockRecord --> NoSite[return no-site reason]
    HasSite -- yes --> Create[create_planning_ghost]
    Create --> Make[make_record]
    Make --> GhostCreated{new ghost exists?}
    GhostCreated -- yes --> RecordCreated[record created event with stage/science]
    RecordCreated --> Success[return true ghost-created]
    GhostCreated -- no --> RecordFailed[record ghost-create-failed]
    RecordFailed --> Fail[return false]
```

---

## 18. Blocked-No-Site Record Flow

```mermaid
flowchart TD
    NoSite[plan_site returned nil] --> Record[pair.construction_bootstrap_ghost_0645]
    Record --> Fields[version tick station entity item class stage]
    Record --> Status[status blocked-no-site]
    Record --> Blocker[blocker = site planner reason]
    Record --> Science[next_science metadata]
    Record --> Event[bootstrap-ghost-no-site-0645]
```

Because this creates a record without a valid ghost, subsequent service calls enter the missing-record retry cooldown for ten seconds before trying again.

---

## 19. Ghost Planner Service / Install Flow

```mermaid
flowchart TD
    ServiceAll[M.service_all] --> Enabled{enabled?}
    Enabled -- no --> Zero[return 0]
    Enabled -- yes --> Loop[pair_map up to max pairs]
    Loop --> Valid{valid pair?}
    Valid -- yes --> Service[M.service_pair]
    Valid -- no --> Next[next]
    Service --> Acted{pcall ok and acted?}
    Acted -- yes --> Increment[n += 1]
    Acted -- no --> Next
    Increment --> Next
    Next --> Done{loop done?}
    Done -- yes --> LastTick[root.last_service_tick = now]
    LastTick --> Return[return n]

    Install[M.install] --> Root[root]
    Root --> Global[_G.TechPriestsConstructionBootstrapGhostPlanner0645 = M]
    Global --> Broker{runtime broker?}
    Broker -- yes --> Register[register category construction priority 60 interval 83]
    Broker -- no --> Registry[register nth tick early fallback]
```

---

## 20. Cross-Module Sequence

```mermaid
sequenceDiagram
    participant GP as Ghost Planner 0645
    participant MP as Master Plan 0644
    participant PC as Planning Constraints 0646
    participant SP as Site Planner
    participant W as Factorio World
    participant CP as Construction Planner
    participant CPA as Placement Authority 0656

    GP->>MP: build_plan(pair)
    MP->>MP: scan_resources + scan_roles
    MP->>MP: choose first missing bootstrap role
    MP-->>GP: plan.target
    GP->>GP: entity_name_for_item(target.preferred_item)
    GP->>PC: entity_unlocked(pair, entity)
    PC-->>GP: unlocked / reason
    GP->>SP: plan_site(pair, entity, category)
    SP-->>GP: position / reason
    GP->>W: create entity-ghost
    GP->>GP: store construction_bootstrap_ghost_0645
    CP->>CP: choose_placeable adopts matching ghost when item exists
    CPA->>CP: service construction aggressively
    CP->>W: remove item + destroy ghost + create physical entity
    CP->>GP: last success / matching built entity visible next survey
    GP->>GP: target_complete -> clear ghost record
    MP->>MP: next survey advances bootstrap stage
```

---

## 21. Infrastructure Planning State Write Matrix

| State field | Writer | Meaning | Risk |
|---|---|---|---|
| `pair.master_infrastructure_plan_0644` | `M.build_plan` | Latest station survey and next target | Critical upstream planning state |
| `plan.resources` | master planner | Resource counts/amounts in radius | Medium; stale only until next survey/build |
| `plan.roles` | master planner | Existing infrastructure role counts | High; drives target selection |
| `plan.target` | `choose` via `build_plan` | Next fixed bootstrap target | Critical |
| `plan.stage/status/blocker` | master planner | Planning state and missing item reason | High |
| `pair.construction_bootstrap_ghost_0645` | ghost planner | Current one-ghost plan record | Critical construction handoff |
| `rec.ghost` | `make_record`, `active_ghost` | LuaEntity ghost reference | High; can become invalid |
| `rec.status` | ghost service | ghosted/built/planned-no-ghost/blocked-no-site | High |
| `rec.next_science` | `make_record` or blocked record | Informational smallest technology objective | Medium; not active authority yet |
| `rec.connection_mode` | `make_record` | Manual priest transfer metadata | Low; not executed |
| `root.stats/recent` | both modules | Planner/ghost metrics | Diagnostic |

---

## 22. Failure / Exit Matrix

### Master planner

| Exit | Trigger | State change | Expected next behavior |
|---|---|---|---|
| `invalid-pair` | station/priest invalid | no plan | pair cleanup |
| `disabled` | root disabled | no new plan | old plan may remain |
| `planned` missing item | selected role absent and item not present | blocker `missing <item>` | fetch/craft/acquisition should obtain item |
| `planned` item present | selected role absent and item present | blocker nil | ghost/construction should proceed |
| `ready` | all surveyed roles present | stage ready | bootstrap ghost planner exits not-bootstrap |

### Ghost planner

| Exit | Trigger | State change | Expected next behavior |
|---|---|---|---|
| `disabled` | root disabled | no changes | no ghost planning |
| `invalid-pair` | invalid pair | no changes | cleanup |
| `active-ghost-present` | valid stored ghost exists | refresh last_seen_tick | wait for construction |
| `ghost-missing-cooldown` | record exists, ghost missing, retry under ten seconds | record retained | wait before retry |
| `not-bootstrap` | plan ready/no target | no new ghost | idle or other planning |
| `target-not-placeable` | target item has no entity/place_result | event only | plan/item mapping bug |
| `technology-locked` | constraints reject entity | event only | choose unlocked fallback or await research |
| `no-site` | site planner cannot place entity | blocked-no-site record | retry after cooldown/site change |
| `ghost-created` | ghost entity created | full record stored | construction planner waits for item/adopts ghost |
| `ghost-create-failed` | world creation failed | planned-no-ghost record | retry after cooldown |
| built cleanup | physical entity found near planned position | marks built then clears record | master plan advances next stage |

---

## 23. Infrastructure Planning Debugging Decision Tree

```mermaid
flowchart TD
    Bug[No planned structure / wrong planned structure] --> Plan{pair.master_infrastructure_plan_0644 exists?}
    Plan -- no --> MasterInstall[Check master planner install/service/build_plan]
    Plan -- yes --> Roles{plan.roles matches actual local entities?}
    Roles -- no --> RoleScan[Check entity_role classification and radius]
    Roles -- yes --> Resources{plan.resources matches local patches?}
    Resources -- no --> ResourceScan[Check scan_resources and radius]
    Resources -- yes --> Target{plan.target is expected fixed next role?}
    Target -- no --> ChooseBug[Check choose fixed priority and role names]
    Target -- yes --> Item{target.preferred_item correct and available?}
    Item -- no --> Availability[Check item_available fallback semantics/station_count]
    Item -- yes --> GhostRec{construction_bootstrap_ghost_0645 exists?}
    GhostRec -- no --> GhostService[Check ghost planner install/should_bootstrap]
    GhostRec -- yes --> Status{record status}
    Status -- ghosted --> Visible{ghost entity visible/valid?}
    Visible -- no --> Reacquire[active_ghost/unit marker/position issue]
    Visible -- yes --> Construction[Check construction planner adoption and item stock]
    Status -- blocked-no-site --> Site[Check site planner blocker]
    Status -- planned-no-ghost --> GhostCreate[Check surface.create_entity entity-ghost]
    Status -- built --> Clear[Record should clear and master plan advance]
```

---

## 24. Current Architectural Gaps Exposed by the Map

1. **Science objective is informational only.** `next_small_science_objective` does not currently decompose recipes, choose science infrastructure, or coordinate production across stations.
2. **The bootstrap sequence is fixed.** It does not yet derive the smallest viable production layout for the chosen science pack.
3. **Role existence is not operational readiness.** An entity can satisfy a role even if unpowered, unfueled, damaged, recipe-less, or disconnected.
4. **Storage is any container.** The survey does not distinguish usable station-owned storage from unrelated same-force containers in range.
5. **Any miner satisfies extraction.** It does not confirm that the miner covers the resource chosen in `plan.target.resource` or that output can be collected.
6. **Any assembler satisfies crafting.** It does not check recipes, inputs, power, or output routing.
7. **Any lab satisfies research.** It does not check science-pack production or lab supply.
8. **Delivery metadata is not execution.** Strings such as `direct-service-until-belts` and `place-near-storage` do not build transfer infrastructure.
9. **Blocked-no-site uses the same record field as a real ghost.** This works through cooldown logic but conflates planning failure state with active ghost state.
10. **Planner category mismatch.** The master planner registers under diagnostics despite being active planning state; service order should be reviewed before future expansion.

---

## 25. Next Mapping Targets

The next logical drilldown should cover one of these connected branches:

1. `emergency_production_executor_0514.lua` and station crafting handoff, to map how missing target items are actually produced.
2. `station_catalog` and inventory steward modules, to map how station inventory availability and nearby infrastructure are represented.
3. `consecration_executor_0515.lua`, to finish the primary maintenance branch.
4. `single_dispatcher_0510.lua`, to compare the intended priority order against the actual arbitration code.

The highest-value next pass is `single_dispatcher_0510.lua`, because it will reveal the actual broad branch order that invokes these already-mapped executors.
