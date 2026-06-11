# Standards and Practices

**Before every generated build, read this file first and follow it. Do not skip it because the requested change looks small.**

## Locale rule

Factorio locale files may not contain duplicate section headers or duplicate keys inside the same section. Before packaging a release candidate, run a locale validation pass that confirms every `locale/*/*.cfg` file has exactly one instance of each section header and no repeated keys within that section.

When adding a new item, entity, recipe, technology, setting, or GUI string, append the new key to the existing section. Never create a second `[item-name]`, `[item-description]`, `[entity-name]`, `[entity-description]`, `[recipe-name]`, `[recipe-description]`, `[mod-setting-name]`, or `[mod-setting-description]` block.

## Packaging rule

After any runtime, prototype, locale, or data-stage edit, validate the package root, `info.json` version, ZIP integrity, and locale uniqueness before surfacing the zip.

## Behavior-development rule

New task systems must route through the current authority layers where they exist: order queue, action arbiter, overhead status authority, sound manager, visual lease cleanup, and inventory steward. Do not add a new independent beam, text, sound, or dump-to-ground path unless it is explicitly temporary and documented as such.
## Locale validation rule

Before packaging a release zip, validate locale coverage for every new prototype category touched by the pass. For technologies, every prototype in `data.raw.technology` introduced by this mod must have exactly one `[technology-name]` entry and one `[technology-description]` entry in `locale/en/base.cfg`. Never append a second section header; merge new keys into the existing canonical section.

## Documentation history rule

Do not create a new standalone history, audit, implementation-pass, rollback, asset-pass, or locale-audit document for ordinary build notes. Append build history, audit summaries, and implementation notes to `docs/DEVELOPMENT_HISTORY.md`. Update `docs/CURRENT_TESTING_GOALS.md` only when the next live-test target actually changes.

Standalone documentation files may only be added when the user explicitly requests a separate document or when the document is a stable user-facing manual rather than a per-build history/audit note.

## Standards modification rule

Only add new rules to this Standards and Practices file when the user explicitly instructs it, or when the rule directly prevents a game-load failure such as duplicate locale sections, duplicate locale keys, invalid prototype definitions, broken ZIP roots, or missing required localization for loaded prototypes. Do not expand this file casually for ordinary feature notes.

## Pre-build standards checkpoint rule

Before compiling a new release zip, read this file and surface a concise summary of its current rules so the build starts with these standards in recent working context.

## Authority-refactor continuity rule

During the Tech-Priest behavior refactor, read `docs/AUTHORITY_REFACTOR_CONTINUITY.md` before changing runtime behavior modules. New or repaired behavior must route through the dispatcher/scheduler/action-arbiter/executor scheme rather than adding another independent `tick_pair`, direct acquisition, recovery, teleport, visual, or GUI control loop. Legacy generated fragments may remain temporarily as leaf helpers, but once a behavior family is dispatcher-owned, do not reintroduce a parallel legacy controller for that same family.

## Efficiency and cooperative parallelization rule

When adding or repairing runtime behavior, prefer cooperative parallelization over broad per-tick scanning. Factorio mod Lua must remain deterministic and cannot use normal background threads, so parallelization in this project means bucketed scheduling, per-force/per-surface/per-station work queues, shared target reservations, dirty-region caches, short-lived query caches, and global per-category budgets. New systems must be able to sleep when no relevant Tech-Priest runtime entity exists, must avoid every priest independently scanning for the same target, and must expose clear diagnostic counters for skipped/deferred work when practical.

Do not solve performance problems by adding another periodic controller that scans all pairs, all surfaces, or all machines. Route new work through the scheduler/orchestrator/dispatcher economy path, keep visible behavior deterministic, and make idle or offscreen work cheap by default.

### Shared work reservations and queue-first task claims

Runtime-heavy work categories must prefer shared reservation and queue authorities before issuing movement/pathfinding commands. Repair, sanctification, resource acquisition, construction ghosts, dropped-item pickup, and combat target selection should claim a short-lived reservation before acting. Newly discovered work should be submitted to a surface/force/category work queue where duplicate submissions fold into one order. A priest should claim queued work before scanning broadly, and any new scan-based discovery must be budgeted, bucketed, and followed by a reservation claim before pathing.

## Efficiency authority inventory rule

Before adding any new runtime efficiency, scheduling, queuing, reservation, caching, throttling, sleep-state, visibility-tier, or delayed-processing system, first inventory the current authority modules and document which existing system already owns the behavior being optimized. Do not layer a second efficiency system on top of an existing one that delays, queues, budgets, reserves, caches, or suppresses the same work unless the new system explicitly replaces the old one or is registered as a leaf helper beneath the owning authority.

Every efficiency pass must answer these questions in the development history before implementation:

1. Which existing module currently owns this work?
2. Does a scheduler, bucket, queue, reservation, cache, throttle, or sleep state already apply?
3. Is the change replacing that authority, feeding it, or merely duplicating it?
4. What old loop/controller/path is being removed, disabled, or demoted to a leaf helper?
5. Which diagnostic counter will show that the new change reduced work instead of only delaying work twice?

If the answer is unclear, stop and audit before coding. Efficiency systems must simplify the runtime authority graph, not create a chain of nested procrastination engines where one optimizer delays work for another optimizer that delays the same work again.


## Runtime authority boundary rule

Runtime efficiency authorities must keep a single clear ownership boundary. For the current Tech-Priest runtime economy, the governing rule is:

```text
Work Queue finds jobs.
Reservation claims jobs.
Order Queue executes jobs.
```

Expanded ownership:

- `runtime_tick_broker.lua` owns when services run and how much budget they receive. It must not choose targets or execute priest behavior.
- `pair_bucket_registry.lua` owns which priest/station pairs are eligible for a category of service. It must not discover world jobs or execute them.
- `work_queue_authority.lua` owns shared world-work discovery and backlog storage by surface, force, and category. It may scan or receive discovered candidates, fold duplicates, and expose claimable orders. It must not mutate priest execution state, issue movement, consume items, or complete tasks.
- `work_reservations.lua` owns short-lived target locks. It must not discover jobs, assign orders, move priests, or perform work.
- `order_queue_0469.lua` owns the individual priest/pair action stack. It may start, pause, promote, complete, or fail per-pair orders. It must not perform global/shared work discovery.
- Executors such as `repair_executor_0516.lua` own performance of already-selected work. They may request discovery from the work queue authority and may consume/complete their own execution target, but they must not maintain a separate shared discovery queue or broad duplicate scan path when the work queue authority exists.

If a module needs work it does not own, it must ask the owning authority rather than reimplementing that layer locally. Legacy fallback paths may remain only as compatibility shims and should be clearly identified as fallbacks, not competing authorities.

## Timing Authority Consolidation Standard — 0.1.605

Before adding or revising any periodic/runtime efficiency behavior, review the existing timing authorities and route the change through the correct layer. Do not add another `script.on_nth_tick` handler when the behavior can be registered as a broker service. The canonical split is:

- `runtime_event_registry.lua` owns the low-level Factorio event/nth-tick registration surface.
- `runtime_tick_broker.lua` owns budgeted service execution and recurring service cadence.
- `efficiency_economy_0595/0598` own dormant whole-runtime and route-budget gates around registry routes.
- Individual modules own behavior logic only; they should not create independent timing authority.

Direct `script.on_nth_tick` use is allowed only as a legacy fallback when both the broker and registry are unavailable, or for a clearly documented one-off bootstrap/initialization case. New high-frequency recurring services must register with the broker. Existing high-frequency direct timers should be migrated in small testable batches, with `/tp-runtime-report` used to verify broker service count, registry route count, and remaining direct fallback audit count.

Sleep ownership remains:

- `efficiency_economy_0595` = whole runtime dormant gate when no Tech-Priest runtime assets exist.
- `efficiency_economy_0599` = individual pair/priest adaptive sleep state.
- `efficiency_economy_0582` = legacy calm/idle skip compatibility shim.
- `pair_bucket_registry.sleeping` = classification only; it must not become a second sleep decision-maker.

## Distributed subordinate assignment rule

When multiple same-rank superior Tech-Priests are within valid command range of multiple eligible lower-rank subordinates, subordinate assignment must distribute load across the eligible superior chains before filling one superior to capacity. Proximity remains a tie-breaker after command-chain load/fill ratio, not the sole assignment rule.

The canonical owner is `command_hierarchy_0480.lua`. Other systems such as subordinate scheduling, emergency cascade, combat-area authority, or future squad/task delegation must consume the hierarchy's direct-subordinate slate instead of independently claiming every nearby lower-rank unit. This prevents one senior from hoarding all intermediates or one intermediate from hoarding all juniors when peer superiors are present and eligible.



### Debug UI austerity rule

Diegetic debug menus such as the Task Auspex must read existing telemetry only and must not become active runtime authorities. Default overview tabs should render compact summaries; expensive ledgers, selected-pair histories, scan/path details, and queue inventories should render lazily only when their submenu is selected. GUI refresh actions should be throttled where practical so debug observability does not become a UPS cost source.

## Reserved Factorio global rule

Do not assign to, replace, or wrap engine-provided globals such as `log`, `game`, `script`, `settings`, `remote`, `commands`, `helpers`, `defines`, `storage`, or `prototypes`. Factorio may reject the mod at load time when reserved globals are modified. Debug suppression, profiling, and telemetry must use Tech-Priests-owned wrapper functions, broker/registry hooks, or project-local modules instead of replacing engine globals.
