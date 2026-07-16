# Void Priest Movement Comprehensive Repair Plan

**Status:** Active staged repair plan  
**Authoritative branch:** `main`  
**Development lane:** `0.1.674-dev`  
**Packaged baseline:** `0.1.672`  
**Primary authority:** `scripts/core/void_movement_authority_0630.lua`

## Selected Goal

Make Void Priest movement a reliable, physically legible, save-safe, broker-owned movement authority that can carry a concrete leaf task to an authorized same-surface destination without being cancelled by ground-priest governors, trapped indefinitely by one blocked step, desynchronized from associated entities, or falsely reported as complete.

This plan preserves the current project doctrine that work selection remains with the dispatcher/executor stack. Void movement owns locomotion only. It does not choose work, create resources, complete mining, bypass custody, or broaden Cogitator authorization by itself.

## Repair Invariants

Every stage must preserve these conditions:

1. Development remains sequential on `main`; no concurrent repair branches.
2. `info.json` remains at `0.1.672` until all required release gates have passed.
3. The runtime tick broker remains the periodic timing authority.
4. A concrete leaf-task owner, movement destination, status, and visible intent must agree.
5. Void movement remains same-surface unless a later explicitly approved design introduces surface transfer.
6. Arrival, cancellation, expiry, invalidation, blockage, save/load, and pair destruction must leave no stale movement ownership.
7. Ground-priest movement behavior must not change as a side effect of Void repairs.
8. Source validation, Factorio load validation, behavioral validation, packaging, and release remain separate claims.

## Baseline Failure Model

The original 0.1.630 authority successfully intercepted the canonical movement request API for Void/platform pairs and advanced the visible priest through small same-surface relocations. The evaluation identified these principal defects:

- ordinary ground bounds and enforcement could recall or reject Void movement;
- incoming requests ignored priority and replaced one another unconditionally;
- existing engine movement commands remained active when Void transit began;
- the fixed ten-second lease was shorter than some valid broker-paced trips;
- expiry and invalid pruning could leave stale pair movement fields;
- a blocked straight-line step retried indefinitely without detour logic;
- the hidden combat proxy and flight presentation did not follow each step;
- active-table traversal had no fairness cursor at high pair counts;
- broker telemetry treated numeric zero as acted;
- diagnostics did not expose enough ownership, progress, blockage, or recall evidence.

## Stage 1 — Sovereignty and Request Lifecycle

**Purpose:** Remove contradictory ground ownership and make every request truthful before improving path quality.

### Source work

- Exempt pairs currently classified by the Void movement authority from `movement_bounds_contract_0511` direct-radius and overleash returns.
- Exempt those pairs from `movement_enforcement_0566` service, destination rejection, and enforcement-owned return-home actions.
- Preserve the later authority-corridor guard as the remaining authorization boundary.
- Store request ID, owner, priority, issue/update ticks, target surface, progress tick, failure count, and adaptive expiry.
- Stop any inherited engine movement command when accepting a new Void request.
- Collapse same-owner/same-target refreshes.
- Hold lower-priority or freshly conflicting equal-priority retargets rather than silently replacing active work.
- Scale minimum expiry to the broker’s effective five-tick pulse and remaining travel distance.
- Centralize cleanup for arrival, stop, expiry, surface change, and invalid pruning.
- Return a real Boolean from the broker service.
- Expand command and automatic runtime-report evidence.

### Stage 1 exit evidence

- Lua/static validation passes for the modified authority.
- Integration validation confirms exact-once installation and the existing broker service name.
- A real Factorio load shows `ground_patched=true` without event or require errors.
- A Void/platform pair travels beyond the former 32/36-tile ground work limits without a 0511 or 0566 recall.
- Lower-priority competing requests do not replace the active owner.
- Expired and stopped requests leave both Void and legacy movement request fields clear.

**Current state:** Source implementation begun. Runtime and behavioral evidence remain pending.

## Stage 2 — Eligibility and Authorization Semantics

**Purpose:** Separate who is allowed to use hover locomotion from where that locomotion is authorized to go.

### Planned work

- Split the current combined classifier into explicit predicates such as `is_void_priest(pair)` and `is_space_platform_pair(pair)`.
- Decide and document whether every rank on a platform hovers, only Void Priests hover, or ordinary ranks receive a constrained platform mode.
- Keep corridor authorization separate from locomotion capability.
- Define explicit return, recovery, combat, conversation, and player-directed exceptions.
- Ensure direct-acquisition target selection and movement authorization use the same policy answer.

### Exit evidence

A matrix covering every priest rank on planetary and platform surfaces must show the intended locomotion authority and authorized work envelope without name-substring accidents.

## Stage 3 — Collision-Aware Transit and Blockage Recovery

**Purpose:** Replace indefinite straight-line collision retries with bounded local route recovery.

### Planned work

- Validate each intermediate position before relocation.
- Search deterministic lateral/forward candidate offsets around a blocked step.
- Keep candidate points on the same surface and within the authorized platform/work region.
- Track consecutive failures, last progress, attempted offsets, and blocked duration.
- Distinguish temporary obstruction, local detour, permanently unreachable destination, and vanished target.
- Finish blocked requests through canonical cleanup and return failure ownership to the leaf executor for replanning.
- Avoid unrestricted teleport searches that could cross platform voids or unauthorized structures.

### Exit evidence

Behavioral scenarios must cover open travel, machinery obstruction, pipe clusters, narrow corridors, interrupted platform edges, destination removal, and save/load during a blocked route.

## Stage 4 — Associated Entity Synchronization and Flight Presentation

**Purpose:** Make the functional and visible priest occupy the same place throughout transit.

### Planned work

- Align the hidden combat proxy after each successful movement step or through an equivalent movement-owned cadence.
- Define facing from movement vector.
- Add restrained hover/jetpack visual and sound cues without creating a second timing authority.
- Ensure beams, status text, action claims, and work visuals do not present mining or combat before arrival.
- Clear transit presentation on every terminal outcome.

### Exit evidence

The visible priest, proxy, status, target marker, and leaf task must remain synchronized through travel, arrival, interruption, combat, and save/load.

## Stage 5 — Fairness, Performance, and Serialization

**Purpose:** Make movement stable with many simultaneous Void pairs and across configuration changes.

### Planned work

- Replace unordered first-N active traversal with a persistent serializable fairness cursor or queue.
- Ensure no active request can starve behind the broker budget.
- Measure effective speed from elapsed ticks so cadence changes do not silently alter locomotion.
- Reconcile request leases after save/load and configuration change.
- Prune orphaned request records and migrate older 0.1.630 request shapes safely.
- Add movement pressure and blockage metrics to the broker’s automatic report.

### Exit evidence

Load tests with active counts below, at, and above the service budget must show bounded latency, no starvation, no duplicate services, and no non-serializable state.

## Stage 6 — Executor Integration and Recovery Contracts

**Purpose:** Prove that locomotion hands control back to work executors correctly.

### Planned work

- Verify direct acquisition, repair, construction, consecration, logistics fetch, combat approach, return-to-station, and player-directed movement.
- Require every executor to handle `arrived`, `owner-replaced`, `expired`, `blocked`, `invalid-target`, and `surface-changed` explicitly.
- Ensure reservations and action claims are released or retained according to leaf-task truth.
- Prevent recall guards or stale direct-acquisition pulses from reissuing rejected travel indefinitely.

### Exit evidence

Each executor scenario must show movement, arrival, physical work, custody handling where applicable, return/deposit, interruption, and recovery without stale ownership.

## Stage 7 — Objective Validation and Release Gates

### Static validation

- Lua parsing and project source-validation workflow.
- Integration graph and exact-once broker registration.
- Persistent-state and migration-shape checks.
- Focused Void movement source checker covering ground exemption, cleanup, request ownership, and diagnostics.

### Runtime validation

- New-save load with a real Void/platform pair.
- Upgrade from a disposable copy of a real `0.1.672` save.
- Save during active movement, reload, continue or fail cleanly.
- Unedited logs accepted by the existing runtime-evidence process.

### Behavioral matrix

- short and long open travel;
- competing priorities and owners;
- former ground-leash distances;
- authorized and unauthorized corridor destinations;
- collision detours and permanently blocked destinations;
- proxy synchronization;
- combat interruption;
- target destruction;
- pair/station destruction;
- many simultaneous movers;
- save/reload and configuration change.

### Release boundary

No `0.1.674` package or release claim is permitted until governance, source integration, objective static validation, Factorio load/migration, behavioral integration, and packaged-load evidence are all recorded separately in `docs/DEVELOPMENT_HISTORY.md`.

## Next Sequential Slice

Complete Stage 1 static validation and correct any source or integration failure. After Stage 1 is objectively clean, begin Stage 2 by separating Void identity from platform locomotion eligibility without changing corridor authorization in the same commit.