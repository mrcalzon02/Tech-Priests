# Tech Priests Source Code Audit Plan

This document defines the staged audit plan for the current `tech-priests_src` source tree. The goal is not to add features, bump versions, package a release, or compare the source tree against the manually copied release candidate. The goal is to understand the runtime authority graph, identify conflicts and dead-end states, and produce a safe repair order before changing behavior.

## Source of truth

- Canonical edit target: `tech-priests_src/`
- Release/output copy: `tech-priests_0.1.620/`
- Current assumption: source and release copy were manually synchronized immediately before this audit, so source/output drift is not part of the first audit pass.
- No new branches unless explicitly requested.
- No version increment until a repair batch is ready for packaging/testing.

## Audit principles

1. Audit before coding when ownership is unclear.
2. Prefer source-truth over narrative memory.
3. Classify behavior ownership by actual load path, not file name or comment intent.
4. Treat `pcall(require(...))` as a possible silent failure point until verified.
5. Treat legacy generated fragments as active unless a later wrapper demonstrably gates or replaces them.
6. Treat direct `script.on_event` and `script.on_nth_tick` usage as high-risk unless it is a documented bootstrap fallback.
7. Treat every priest `.destroy()` path as suspect unless it is clearly inside authorized Cogitator Station cleanup.
8. Separate lore/UI/reporting modules from behavior authorities.
9. Every identified problem should receive one of these dispositions: safe, intentional legacy fallback, fragile but working, probable bug, confirmed bug, or requires live test.

## Stage 0 — Audit baseline and manifest verification

Purpose: confirm the indexed source tree is usable and establish a repeatable audit surface.

Tasks:

- Verify `GITHUB_FILE_MANIFEST.md` indexes `tech-priests_src/`.
- Confirm the expected source roots, text-file count, and major source directories.
- Use the manifest as the file discovery layer, but use direct source file reads for evidence.
- Do not modify runtime code.

Deliverables:

- Baseline summary in chat.
- Any future machine-generated audit script/report should live under `tools/` or `tech-priests_src/docs/` only after the manual pass defines what the script must detect.

Exit criteria:

- Source tree is searchable.
- We know the real runtime entry points.

## Stage 1 — Runtime load graph

Purpose: identify what is actually loaded, in what order, and through what mechanism.

Entry points to map:

- `settings.lua`
- `settings-updates.lua`
- `settings-final-fixes.lua`
- `data.lua`
- `data-updates.lua`
- `data-final-fixes.lua`
- `control.lua`
- `scripts/generated/control_legacy_part_001.lua` through `control_legacy_part_022.lua`
- `scripts/core/bootstrap_runtime.lua`
- all modules required by `control.lua` and `bootstrap_runtime.lua`

Classifications:

- Hard loaded with plain `require(...)`
- Soft loaded with `pcall(require(...))`
- Required repeatedly by historical installer sections
- Dynamically referenced through `_G`
- Command-only or diagnostics-only
- Asset/prototype/locale only
- Candidate unused

Known first-pass concerns:

- `control.lua` loads generated legacy fragments before late authority modules.
- `bootstrap_runtime.lua` still performs a long sequence of historical installer calls.
- Many later modules install through `pcall`, which can hide failed authorities until runtime diagnostics are checked.

Deliverables:

- Runtime load graph.
- Module classification table.
- List of `pcall(require(...))` modules whose failure would silently remove a major authority.

Exit criteria:

- We can answer which modules are live, optional, repeated, or likely dead.

## Stage 2 — Event and timing authority audit

Purpose: identify direct event/tick registrations that bypass the runtime registry or broker.

Canonical authorities:

- `scripts/core/runtime_event_registry.lua`
- `scripts/core/runtime_tick_broker.lua`

Audit searches:

- `script.on_event`
- `script.on_nth_tick`
- `script.on_init`
- `script.on_configuration_changed`
- `runtime_event_registry.on_event`
- `runtime_event_registry.on_nth_tick`
- `register_service`

Classifications:

- Registry-owned event route
- Broker-owned recurring service
- Legacy fallback guarded by registry absence
- Direct event override risk
- Direct nth-tick override risk
- One-off bootstrap exception

Known first-pass concerns:

- `workstate_gui_radar_recovery_0465.lua` directly registers GUI events.
- `bootstrap_runtime.lua` contains direct selected-entity/capsule event registrations.
- Direct event registration can overwrite or be overwritten by other handlers because Factorio permits one handler per event id/cadence.

Deliverables:

- Event route inventory.
- Nth-tick route inventory.
- Direct registration risk list.
- Recommended migration order for direct registrations.

Exit criteria:

- We know which event/tick paths are canonical and which still bypass the canonical layer.

## Stage 3 — Behavior authority and ownership map

Purpose: map each behavior family to exactly one intended owner and identify overlaps.

Behavior families:

- Pair lifecycle and recovery
- Movement requests and movement enforcement
- Direct acquisition/mining
- Emergency production/station crafting
- Consecration/sanctification
- Repair
- Combat repair
- Ordinary combat
- Construction placement
- Logistics fetch
- Machine logistics fulfillment
- Dropped item pickup/ground hoover
- Machine-spirit ledger/state updates
- GUI display/update paths
- Sound/reporting/visual overlays

Canonical runtime boundary from standards:

```text
Work Queue finds jobs.
Reservation claims jobs.
Order Queue executes jobs.
```

Expanded current candidates:

- `work_queue_authority.lua` owns shared world-work discovery/backlog.
- `work_reservations.lua` owns short-lived target claims.
- `order_queue_0469.lua` owns per-pair action/order stack.
- `single_dispatcher_0510.lua` owns migrated per-pair dispatch.
- Executors own physical execution of selected work.
- Legacy generated fragments remain active unless gated.

Known first-pass concerns:

- `task_scheduler.lua` describes a canonical scheduler but defaults to observe-only.
- `single_dispatcher_0510.lua` is the live dispatcher for migrated families.
- Combat and construction are still explicitly described as legacy leaf families in the dispatcher.
- Multiple efficiency governors exist and must be distinguished from behavior owners.

Deliverables:

- Behavior ownership matrix.
- Overlap/conflict list.
- Dead-end risk list by behavior family.

Exit criteria:

- For each behavior family, we know whether it is dispatcher-owned, legacy-owned, mixed, reporting-only, or unclear.

## Stage 4 — Pair lifecycle, recovery, and destruction audit

Purpose: isolate all paths that can destroy, replace, recall, teleport, respawn, invalidate, or strand a Tech-Priest pair.

Audit searches:

- `.destroy(`
- `raise_destroy`
- `respawn_pair_priest`
- `remove_pair_for_entity`
- `create_pair`
- `stuck`
- `recall`
- `orphan`
- `missing_priest`
- `teleport`
- `set_command`
- `destructible`
- `active = false`

Primary invariant:

A visible Tech-Priest should only be destroyed as part of authorized Cogitator Station pickup/death/destruction cleanup.

Known first-pass concerns:

- `priest_lifecycle_seal_0500.lua` blocks unauthorized priest destruction and disables stuck/recall flags.
- Recovery systems may still exist around the seal, creating possible situations where recovery expects replacement while the seal preserves or blocks the replacement path.

Deliverables:

- Destruction-path inventory.
- Recovery/stuck/respawn ownership table.
- Pair state fields that can strand behavior.
- First repair candidates for vanish prevention or recovery simplification.

Exit criteria:

- Every priest destroy/replacement path is classified as authorized, blocked, legacy fallback, or bug.

## Stage 5 — State machine and dead-end behavior audit

Purpose: identify pair states that can be entered without a matching completion, cancel, timeout, retry, or cleanup.

State fields to inspect:

- `pair.mode`
- `pair.active_task`
- `pair.active_task_0285`
- `pair.order_queue_0469`
- `pair.emergency_craft`
- `pair.direct_acquisition_task_0336`
- `pair.scavenge`
- `pair.cram`
- `pair.logistic_requested_item`
- `pair.movement_*`
- `pair.dispatcher_0510`
- `pair.lifecycle_*`
- `pair.recovery_*`
- `pair.target`
- `pair.combat_target`

Dead-end categories:

- Target invalid but task remains active.
- Reservation held but work abandoned.
- Queue order expired but pair still believes it has a task.
- Movement lease stale but action waits forever.
- Craft/production task waits for impossible ingredient.
- Consecration task waits for invalid target or missing capsule.
- Repair task waits for missing repair pack or non-repairable entity.
- Legacy state suppresses dispatcher state or dispatcher state suppresses legacy cleanup.

Known first-pass concerns:

- Work queue includes an `emergency` category while reservation categories omit it.
- Dispatcher gates legacy only for recent dispatcher-owned action families.
- The observe-only scheduler can adopt legacy state without being the live execution owner.

Deliverables:

- Dead-end state inventory.
- Required timeout/cancel cleanup points.
- First repair batch proposal.

Exit criteria:

- We have an actionable list of stranded-state risks ranked by severity.

## Stage 6 — GUI authority and containment audit

Purpose: map every custom GUI owner and identify direct event ownership, nested frame misuse, escaping panels, and state refresh conflicts.

Audit searches:

- `player.gui`
- `add{ type = "frame"`
- `scroll-pane`
- `tabbed-pane`
- `on_gui_click`
- `on_gui_opened`
- `on_gui_closed`
- `destroy()` on GUI elements
- Work State GUI names
- Machine-Spirit ledger GUI names

Known first-pass concerns:

- The Machine-Spirit Ledger has visible containment/frame-nesting problems.
- GUI recovery currently direct-registers GUI events instead of routing through the event registry.
- Decorative Cogitator shell frames must be distinguished from accidental nested native frames.

Deliverables:

- GUI ownership map.
- Frame nesting hotspot list.
- Containment repair candidates.
- Event-router consolidation recommendation.

Exit criteria:

- We know which GUI issue is visual-only, event-routing, state-refresh, or layout containment.

## Stage 7 — Prototype, locale, and asset reference audit

Purpose: catch load-breaking data-stage issues before any release candidate.

Audit targets:

- `info.json`
- `settings*.lua`
- `data*.lua`
- `prototypes/**/*.lua`
- `locale/en/*.cfg`
- referenced graphics and sound assets

Checks:

- Duplicate locale section headers.
- Duplicate locale keys inside each section.
- Missing locale names/descriptions for loaded prototypes.
- Missing sprite/sound file references.
- Data-stage prototype clone fields that are invalid for Factorio 2.0.
- Optional dependency conditionals.

Deliverables:

- Locale/prototype risk list.
- Asset missing-reference list.
- Release-blocking data-stage issues.

Exit criteria:

- We know whether the source can safely package after runtime repairs.

## Stage 8 — Repair staging plan

Purpose: convert audit findings into small, testable repair batches.

Repair batch rules:

- One ownership family per batch where possible.
- No version bump until the batch is ready for test packaging.
- No broad cleanup commits that mix behavior, GUI, locale, and assets.
- Each repair must state whether it changes runtime behavior, GUI presentation, diagnostics, data-stage prototypes, or documentation only.
- Each repair must include a live-test target and expected observation.

Likely first repair batches, subject to audit evidence:

1. Align work queue/reservation category sets if `emergency` reservations are reachable.
2. Consolidate direct GUI event registration under the runtime event registry.
3. Inventory and reduce duplicate installer calls that are not idempotent.
4. Simplify or clarify scheduler-versus-dispatcher ownership documentation and diagnostics.
5. Classify and seal remaining unauthorized priest destruction/recovery paths.
6. Fix Machine-Spirit Ledger containment through the owning GUI module rather than a broad visual shim, once the GUI ownership map is complete.

## Stage execution record

Use this section to track audit progress without creating separate per-pass audit files unless explicitly requested.

- Stage 0: Complete — baseline manifest verified; `tech-priests_src/` is indexed and searchable; runtime entry points identified.
- Stage 1: In progress — data-stage entry files mapped; `control.lua` traced from early austerity hook through generated legacy fragments, bootstrap handoff, dispatcher/executor migration seam, lifecycle guard chain, and 0.1.580–0.1.599 efficiency/governor stack. Current finding: generated fragments are active behavior, not dead archive; `control.lua` still contains many soft-loaded authorities whose failure may only appear in log output.
- Stage 2: Pending
- Stage 3: Pending
- Stage 4: Pending
- Stage 5: Pending
- Stage 6: Pending
- Stage 7: Pending
- Stage 8: Pending
