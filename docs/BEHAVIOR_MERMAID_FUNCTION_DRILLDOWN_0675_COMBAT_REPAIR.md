# Tech-Priests Function-Level Mermaid Drilldown: Combat Repair Doctrine 0517

Version: 0.1.675-map-pass-14  
Previous drilldown: `docs/BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_0672_REPAIR.md`  
Companion overview: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

Purpose: map the dispatcher-owned tactical repair doctrine that decides whether a Tech-Priest may temporarily repair a damaged wall or gate under enemy pressure rather than continue fighting.

Mapped module:

- `combat_repair_doctrine_0517.lua`

Physical repair is delegated to:

- `repair_executor_0516.lua`
- `repair_executor_integrity_0673.lua`

Important current-code truths:

1. Combat repair is not ordinary repair selection. It only considers damaged wall/gate-like entities under current enemy pressure.
2. The doctrine requires allied cover by default: either an active/loaded turret or another nearby Tech-Priest considered to be defending.
3. Candidate search is centered on the priest, capped at 26 tiles and 120 wall-like entities.
4. Cluster reservations group nearby wall segments into three-tile cells for 150 ticks.
5. Candidate scoring strongly favors damage ratio, enemy count, active turret cover, and other-priest cover.
6. The selected combat-repair action has dispatcher priority 920, above the ordinary order-queue combat priority table and above normal repair.
7. The doctrine does not directly consume repair packs or write health. It creates/assigns an ordinary repair task and forces `repair_executor_0516.service_pair()` on the selected wall.
8. The module is not independently scheduled by `install()`. It is called by `single_dispatcher_0510.choose_action()` and its combat-repair executor branch.
9. Completion currently marks only the combat-repair state complete; it does not fully clear pair mode, generic target, repair state, task/order state, or the combat-repair target mirror.
10. `/tp-combat-repair-0517` remains installed.

---

## 1. Tactical Doctrine

```mermaid
flowchart TD
    Pressure[Enemy pressure against damaged wall/gate]
    Pressure --> Cover{Allied covering fire or defending priest?}
    Cover -- no --> Combat[Remain in combat]
    Cover -- yes --> Supplies{Station has repair pack?}
    Supplies -- no --> Combat
    Supplies -- yes --> Candidate[Score defended damaged wall]
    Candidate --> Reserve[Reserve wall cluster]
    Reserve --> Repair[Delegate to ordinary repair executor]
    Repair --> CoverCheck{Cover still valid?}
    CoverCheck -- no --> Abort[Abort repair and return to combat]
    CoverCheck -- yes --> Complete{Wall fully repaired?}
    Complete -- no --> Repair
    Complete -- yes --> Cooldown[Target cooldown and cluster release]
```

---

## 2. Configuration and Timing

| Setting | Current value |
|---|---:|
| Search radius around priest | 26 tiles |
| Enemy pressure radius around wall | 9 tiles |
| Turret-cover radius | 8 tiles |
| Other-priest cover radius | 12 tiles |
| Personal danger radius | 4 tiles |
| Repair range | 4 tiles |
| Cluster cell size | 3 tiles |
| Cluster reservation lease | 150 ticks |
| Target cooldown | 90 ticks |
| Minimum wall damage ratio | 4% |
| Critical wall damage ratio | 35% |
| Candidate cap | 120 |
| Dispatcher action priority | 920 |

---

## 3. Function Inventory

| Function | Role | Major side effects |
|---|---|---|
| `M.root` | Ensures doctrine config, stats, reservations, cooldowns | Writes doctrine storage root |
| `stat`, `record` | Metrics and bounded recent history | Writes stats/recent |
| `is_wallish` | Accepts wall/gate type or names containing wall/gate | None |
| `missing_health`, `missing_ratio`, `damaged` | Damage calculations | None |
| `same_force`, `enemyish` | Allied/enemy classification | None |
| `surface_entities`, `box` | Safe area scanning | Surface queries |
| `ammo_inventory_loaded` | Checks turret ammo inventory | None |
| `has_energy` | Checks turret energy above 1000 | None |
| `has_fluid` | Checks any positive turret fluidbox amount | None |
| `turret_active_or_loaded` | Classifies turret cover | None |
| `count_enemies_near` | Counts enemy-like entities and nearest distance | Surface queries |
| `turret_cover` | Counts active/loaded allied turrets near wall | Surface queries |
| `other_priest_cover` | Counts nearby priests in combat/defend state | Reads pair map |
| `cluster_key`, `target_key` | Reservation/cooldown identity | None |
| `cleanup_reservations` | Expires cluster leases and target cooldowns | Mutates doctrine root |
| `cluster_reserved_by_other` | Prevents different station from claiming same cluster | Reads/cleans reservations |
| `reserve_cluster` | Writes cluster lease | Mutates root |
| `release_cluster`, `release_cluster_key` | Deletes cluster lease | Mutates root |
| `station_has_repair_pack` | Uses repair-pack helper or one-inventory fallback | None |
| `eligible_wall` | Full tactical eligibility engine | Reads scans, supplies, reservations, cooldowns |
| `score_wall` | Tactical candidate score | None |
| `M.find_combat_repair_target` | Searches and selects best candidate | Records no-target events |
| `M.abort_pair` | Releases cluster and resets some combat/repair fields | Mutates pair and root |
| `M.recommend_action` | Dispatcher pre-classification recommendation | May abort active combat repair |
| `M.active` | Detects nonterminal combat-repair state | None |
| `clear_if_complete` | Applies cooldown, releases cluster, marks complete | Mutates root/state |
| `M.service_pair` | Selects/reserves target and delegates repair | Broad pair/task/repair effects |
| `install_command` | Registers runtime command | Command surface |
| `wrap_pair_dump` | Adds automatic diagnostic output | Wraps diagnostics |
| `M.install` | Installs command, diagnostics and global export | No periodic service |

---

## 4. Enemy Classification

```mermaid
flowchart TD
    Entity[Nearby entity]
    Entity --> Force{Same force or neutral?}
    Force -- yes --> NotEnemy[Not enemy]
    Force -- no --> Type{unit, unit-spawner, turret, spider-unit?}
    Type -- yes --> Enemy[Enemy-like]
    Type -- no --> Health{Has health and type text contains unit/biter/spitter?}
    Health -- yes --> Enemy
    Health -- no --> NotEnemy
```

Risk: this uses force-name inequality rather than Factorio force diplomacy. A non-neutral allied force with a different name can be counted as hostile.

---

## 5. Turret Cover Classification

```mermaid
flowchart TD
    Turret[Same-force turret]
    Turret --> Shooting{Valid shooting_target?}
    Shooting -- yes --> Covered[Active cover: shooting]
    Shooting -- no --> Ammo{Ammo inventory nonempty?}
    Ammo -- yes --> CoveredAmmo[Active cover: ammo-loaded]
    Ammo -- no --> Energy{Energy > 1000?}
    Energy -- yes --> CoveredEnergy[Active cover: energized]
    Energy -- no --> Fluid{Any fluid amount > 0?}
    Fluid -- yes --> CoveredFluid[Active cover: fluid-ready]
    Fluid -- no --> Unloaded[Not active cover]
```

Risk: disabled, circuit-disabled, inactive, disconnected, or otherwise unable-to-fire turrets can still count as cover merely because they contain ammo, energy, or fluid.

---

## 6. Other-Priest Cover

```mermaid
flowchart TD
    Other[Other valid same-force priest pair]
    Other --> Range{Within 12 tiles of wall?}
    Range -- no --> Ignore[Ignore]
    Range -- yes --> State{Mode contains combat/defend OR target is enemy-like?}
    State -- yes --> Cover[Count as active priest cover]
    State -- no --> Ignore
```

The check does not verify that the other priest has ammunition, a working proxy, line of fire, or an unobstructed path to the threat.

---

## 7. Cluster Reservation

```mermaid
flowchart TD
    Wall[Wall position]
    Wall --> Quantize[Round x/y to nearest 3-tile grid]
    Quantize --> Key[surface:force:cluster-x:cluster-y]
    Key --> Existing{Reservation exists from another station?}
    Existing -- yes --> Block[Cluster reserved]
    Existing -- no --> Reserve[Store station/priest/wall/until tick +150]
```

Reservation ownership compares station IDs, not priest IDs. Priests belonging to the same station would not block one another at this layer.

---

## 8. Wall Eligibility

```mermaid
flowchart TD
    Wall[Potential wall/gate]
    Wall --> Base{Valid, same force, wall-like, damaged?}
    Base -- no --> RejectBase[not-damaged-wall]
    Base -- yes --> Ratio{Missing ratio >=4%?}
    Ratio -- no --> Minor[minor-damage]
    Ratio -- yes --> Pack{Station has repair pack?}
    Pack -- no --> NoPack[no-repair-pack]
    Pack -- yes --> Radius{Inside station radius?}
    Radius -- no --> Outside[outside-station-radius]
    Radius -- yes --> Cooldown{Target cooldown active?}
    Cooldown -- yes --> CD[target-cooldown]
    Cooldown -- no --> Cluster{Cluster reserved by another station?}
    Cluster -- yes --> Reserved[cluster-reserved]
    Cluster -- no --> Enemies{Enemy count within 9 tiles >0?}
    Enemies -- no --> NoPressure[no-enemy-pressure]
    Enemies -- yes --> Cover[Turret cover or other-priest cover]
    Cover --> Required{require_cover and no cover?}
    Required -- yes --> Uncovered[uncovered-under-fire]
    Required -- no --> Personal{Enemies within 4 tiles of this priest, no cover, and wall damage <35%?}
    Personal -- yes --> Danger[priest-personal-danger]
    Personal -- no --> Eligible[Eligible with tactical context]
```

When `require_cover=true`, the personal-danger branch is mostly redundant because uncovered targets are rejected earlier.

---

## 9. Candidate Score

```mermaid
flowchart LR
    Score[Wall score]
    Score --> Ratio[missing ratio ×15000]
    Score --> Missing[missing health ×3]
    Score --> Enemy[enemy count ×450]
    Score --> Turret[active turrets ×900]
    Score --> Priest[active priests ×650]
    Score --> Nearest[minus nearest enemy distance ×40]
    Score --> PriestDistance[minus priest distance ×35]
    Score --> StationDistance[minus station distance ×4]
```

Damage ratio is the largest single factor, followed by tactical pressure and cover.

---

## 10. Candidate Search

```mermaid
flowchart TD
    Search[M.find_combat_repair_target]
    Search --> Radius[min pair radius, 26]
    Radius --> Scan[Scan allied entities around priest]
    Scan --> Wallish{Wall/gate-like?}
    Wallish -- no --> Next[Next]
    Wallish -- yes --> Cap{Checked >120?}
    Cap -- yes --> Stop[Stop scan]
    Cap -- no --> Eligible[eligible_wall]
    Eligible --> Good{Eligible?}
    Good -- no --> Next
    Good -- yes --> Score[score_wall]
    Score --> Best{Higher than current best?}
    Best -- yes --> Keep[Keep wall/context/score]
    Best -- no --> Next
    Keep --> Next
    Next --> Result{Best found?}
    Result -- no --> Record[Record no-combat-repair-target]
    Result -- yes --> Return[Return wall/context/score]
```

The search is centered on the priest rather than the station. Valid defended walls farther than 26 tiles from the priest are invisible even when within station territory.

---

## 11. Dispatcher Recommendation

```mermaid
flowchart TD
    Recommend[M.recommend_action]
    Recommend --> Active{Combat repair state active?}
    Active -- yes --> Target{Active target valid?}
    Target -- yes --> Recheck[eligible_wall]
    Recheck --> Still{Still eligible?}
    Still -- no --> Abort[M.abort_pair cover-lost blocker]
    Abort --> Nil[Return nil, combat remains]
    Still -- yes --> Search
    Target -- no --> Search[Find best combat-repair target]
    Active -- no --> Search
    Search --> Found{Target found?}
    Found -- no --> Nil
    Found -- yes --> Action[kind combat-repair, item repair-pack, priority 920, score/context]
```

Risk: an active state with an invalid stored target is not aborted before searching for a new one, leaving stale state and cluster metadata behind.

---

## 12. Abort Flow

```mermaid
flowchart TD
    Abort[M.abort_pair]
    Abort --> Target[state target or combat repair mirror]
    Target --> Cluster[Release state cluster key and target cluster]
    Cluster --> NewState[Replace combat-repair state with phase failed]
    NewState --> RepairState{Ordinary repair state targets same entity?}
    RepairState -- yes --> PartialClear[Set repair phase none and clear target name/unit]
    RepairState -- no --> Pair
    PartialClear --> Pair[Clear generic target only if exact target]
    Pair --> Mirror[Clear combat-repair target mirror]
    Mirror --> Mode{Pair mode contains repair?}
    Mode -- yes --> AbortMode[combat-repair-aborted]
    Mode -- no --> Record
    AbortMode --> Record[Record aborted]
```

Defects:

- Ordinary repair timers, pack counters, reservations, task records, and repair orders are not cleared.
- Invalid targets cannot be passed to `release_cluster`, so only a stored cluster key can clean that lease.
- The pair can remain with a repair order that the dispatcher or periodic repair service later resumes.

---

## 13. Service Flow

```mermaid
flowchart TD
    Service[M.service_pair]
    Service --> Forced{Forced target valid and eligible?}
    Forced -- yes --> Target[Use forced target]
    Forced -- no --> Search[Find best target]
    Search --> Found{Target found?}
    Found -- no --> NoTarget[Phase no-target; return false]
    Found -- yes --> Target
    Target --> Reserve[Reserve cluster]
    Reserve --> State[Phase repair-via-0516; store target/context]
    State --> Pair[pair combat-repair target; mode combat-repair]
    Pair --> Repair{repair_executor_0516 available?}
    Repair -- no --> Fail[Release cluster; phase failed]
    Repair -- yes --> Submit[Call submit_or_assign_repair_task; result ignored]
    Submit --> Execute[Call repair executor with forced wall]
    Execute --> Error{Call errored?}
    Error -- yes --> RepairError[Release cluster; phase failed]
    Error -- no --> Complete[clear_if_complete]
    Complete --> Record[Record service every call]
    Record --> Return[Return ordinary repair result]
```

---

## 14. Completion Flow

```mermaid
flowchart TD
    Complete[clear_if_complete]
    Complete --> Done{Target invalid or missing health <=0.01?}
    Done -- no --> Return[Keep active]
    Done -- yes --> Cooldown[Set 90-tick target cooldown when key available]
    Cooldown --> Release[Release state cluster key and target cluster]
    Release --> State[Set combat-repair phase complete and completed tick]
    State --> Record[Record complete]
```

Missing cleanup:

- `state.target` and target metadata remain.
- `pair.combat_repair_target_0517` remains.
- `pair.target` remains.
- `pair.mode` remains `combat-repair`.
- Ordinary repair state/task/order cleanup is delegated implicitly and not verified.

---

## 15. Interaction with Ordinary Repair

```mermaid
sequenceDiagram
    participant D as Single Dispatcher
    participant C as Combat Repair 0517
    participant R as Repair Executor 0516 + Integrity 0673
    participant Q as Order Queue 0469

    D->>C: recommend_action(pair)
    C-->>D: combat-repair target, priority 920
    D->>C: service_pair(pair)
    C->>C: reserve three-tile wall cluster
    C->>R: submit_or_assign_repair_task(target)
    C->>R: service_pair(forced target)
    R->>R: reserve physical target, move, consume packs, heal
    R->>Q: complete/promote repair order through 0673 hardener
    C->>C: observe target full and mark combat-repair state complete
```

There are two concurrency controls:

1. Combat repair's three-tile cluster lease.
2. Ordinary repair's exact-target work reservation.

The cluster lease spreads tactical wall work across nearby segments; the exact reservation prevents two repair executors from using the same entity.

---

## 16. State Write Matrix

| State | Writer | Meaning |
|---|---|---|
| Doctrine root flags | `M.root`, slash command | Enabled, dispatcher ownership, cover and cluster policy |
| `cluster_reservations` | Reserve/release helpers | Tactical wall-cluster ownership |
| `target_cooldowns` | Completion | Short wall reselection suppression |
| `pair.combat_repair_0517` | Service, abort, completion | Tactical doctrine phase/context |
| `pair.combat_repair_target_0517` | Service/abort | Mirror of active wall |
| `pair.mode` | Service/abort | `combat-repair` or abort mode |
| `pair.repair_0516` | Ordinary repair executor and partial abort cleanup | Physical repair state |
| Active task/order | Ordinary repair submission | Physical repair scheduling |
| Station repair-pack inventories | Ordinary repair executor | Physical cost |
| Wall health | Ordinary repair executor | Repair result |

---

## 17. Defect and Risk Catalog

| # | Finding | Severity |
|---:|---|---|
| 1 | Enemy detection treats any non-neutral, differently named force as hostile instead of checking force diplomacy. | High |
| 2 | Ammo, energy, or fluid alone can classify a disabled/unable-to-fire turret as active cover. | High |
| 3 | Other-priest cover does not verify ammunition, proxy readiness, line of fire, or actual engagement capability. | Medium-high |
| 4 | Active state with invalid target is not aborted before selecting a replacement. | High |
| 5 | Changing targets does not release the previous cluster reservation. | High |
| 6 | No-target exit does not release or clear an old target/cluster state. | High |
| 7 | `reserve_cluster` result is ignored. | Medium |
| 8 | Repair-task submission result is ignored. | High |
| 9 | Abort only partially clears ordinary repair state and does not clear repair tasks/orders/reservations/timers. | Critical |
| 10 | Completion leaves pair mode and all target mirrors/state references behind. | Critical |
| 11 | Completion does not verify ordinary repair task/order/reservation cleanup. | High |
| 12 | Service events are recorded on every call, flooding recent diagnostics. | Medium |
| 13 | No-target events are recorded on every scan. | Medium |
| 14 | `dispatcher_owned` is configured but never enforced. | Medium |
| 15 | Search is centered on priest and capped at 26 tiles, possibly missing defended station walls. | Design risk |
| 16 | Cluster ownership compares station only, not priest. | Low for one-priest-per-station design |
| 17 | Target cooldown is not written when the target entity becomes invalid. | Low-medium |
| 18 | Runtime slash command can disable cover requirements and cluster spreading. | Medium / architecture |
| 19 | No independent service registration exists. | Reclassification candidate: dispatcher ownership is intentional |
| 20 | Personal-danger check is largely redundant when cover is mandatory. | Low cleanup |

---

## 18. Debugging Decision Tree

```mermaid
flowchart TD
    Problem[Combat repair not selected or priest repairs unsafely]
    Problem --> Pack{Repair pack available across steward sources?}
    Pack -- no --> Supply[Repair supply issue]
    Pack -- yes --> Wall{Damaged wall ratio >=4%?}
    Wall -- no --> Threshold[Below tactical threshold]
    Wall -- yes --> Enemy{Enemy pressure within 9 tiles?}
    Enemy -- no --> Pressure[No tactical pressure]
    Enemy -- yes --> Cover{Turret or priest cover detected?}
    Cover -- no --> Combat[Correctly remain in combat]
    Cover -- yes --> TrueCover{Cover can actually fire/defend?}
    TrueCover -- no --> CoverBug[False-positive cover classification]
    TrueCover -- yes --> Reservation{Cluster reserved elsewhere?}
    Reservation -- yes --> Spread[Different wall cluster needed]
    Reservation -- no --> Dispatcher{Combat-repair action recommended?}
    Dispatcher -- no --> State[Inspect stale active state/invalid target]
    Dispatcher -- yes --> Submit{Ordinary repair task installed?}
    Submit -- no --> SubmissionBug[Ignored submission failure]
    Submit -- yes --> Repair{Repair executor progresses?}
    Repair -- no --> RepairDiagnostics[Inspect repair integrity counters]
    Repair -- yes --> Complete{Wall full and all modes/targets/orders cleared?}
    Complete -- no --> CompletionBug[Combat-repair cleanup defect]
```

---

## 19. Progressive Development Target

The next corrective implementation should add a `combat_repair_integrity_0676.lua` hardener that:

1. Uses Factorio force diplomacy for enemy checks.
2. Tightens turret and other-priest cover validation.
3. Releases previous clusters whenever targets change, vanish, become ineligible, or no target is found.
4. Verifies cluster claim ownership and ordinary repair-task submission.
5. Fully aborts ordinary repair state/tasks/orders/reservations when tactical cover is lost.
6. Fully clears combat-repair mode, targets, state residue, ordinary repair residue, and scheduler state after completion.
7. Compacts repetitive service/no-target history.
8. Enforces `dispatcher_owned`.
9. Removes `/tp-combat-repair-0517`.
10. Adds automatic diagnostics and a remediation-status ledger with runtime validation scenarios.
