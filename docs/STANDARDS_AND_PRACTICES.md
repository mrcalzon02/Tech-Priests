# Tech Priests Standards and Practices

**Status:** Authoritative project governance document  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Active development lane:** `0.1.674-dev`  
**Reconstructed:** 2026-06-29 from verified repository behavior and milestone requirements

## Authority and Scope

This document is the canonical engineering and release-governance authority for the Tech Priests project. It replaces the previously missing standards prerequisite identified by the milestone plan. It does not claim to reproduce an unavailable historical document word for word; it records the standards already demonstrated by the source, diagnostics, validation tooling, and current milestone plan.

When another document conflicts with this one, the stricter safety, validation, or evidence requirement governs until the conflict is deliberately resolved on `main` and recorded in `docs/DEVELOPMENT_HISTORY.md`.

## Base-State Recovery Exception

`RECOVERY_REPAIR_SEQUENCE.md` is an explicitly authorized temporary top-level recovery and work-order document. Its creation is a project-owner exception to the ordinary restriction against standalone repair-pass or audit documents.

The exception exists to recover trustworthy base functionality, unify runtime ownership, repair physical-accounting and scheduler defects, reduce overlapping legacy and hardener authority, and require objective runtime evidence before ordinary feature growth resumes.

During the recovery milestone:

- `RECOVERY_REPAIR_SEQUENCE.md` governs development priority and repair order.
- This standards document continues to govern engineering safety, physical honesty, serialization, single-branch work, runtime ownership, validation, packaging, and truthful milestone accounting.
- No unrelated feature expansion may bypass an open recovery stage.
- New outer hardeners, schedulers, queues, reservations, movement authorities, scan loops, or diagnostic authorities are prohibited unless they directly replace or repair an existing owner and reduce the final authority graph.
- Every repair slice must update `docs/DEVELOPMENT_HISTORY.md`, `tech-priests_src/docs/CURRENT_TESTING_GOALS.md`, the relevant Mermaid/function map, and applicable validation evidence.
- Source implementation, static validation, runtime loading, behavioral validation, packaging, and publication must remain separately identified.

This exception does not waive or weaken any safety or evidence requirement in this document. It changes the project work order so consolidation and proof occur before further development.

The recovery exception remains active until all recovery stages are completed, permanent lessons are folded into the governing documents, the final verified state is recorded in `docs/DEVELOPMENT_HISTORY.md`, and the project owner explicitly authorizes a return to ordinary feature development.

## Development Branch Policy

All active development occurs on the single branch named `main`.

Do not create or maintain concurrent development branches. The project treats parallel branches as a code-fracture and merge-conflict risk. A milestone must advance through sequential, reviewable commits on `main`.

Each development slice must be meaningful. A slice should complete a coherent behavior, integrity guard, diagnostic surface, validation tool, governance prerequisite, or runtime-evidence capability. Avoid commits that merely rename, shuffle, or partially scaffold work without moving a milestone gate toward completion.

## Truthful Milestone Accounting

The packaged release baseline and the development lane are separate facts:

- `tech-priests_src/info.json` remains at the last verified packaged version until all release gates pass.
- Development modules may identify themselves as `0.1.674-dev` while the package remains `0.1.672`.
- An unpackaged migration-test copy may use `0.1.673` only to trigger Factorio configuration-change behavior.
- A migration-test copy is not a release candidate and must never be zipped, published, uploaded, or described as released.
- Source validation, runtime validation, behavioral validation, and release packaging are distinct gates. Passing one must never be reported as passing another.

A failed, missing, unavailable, or unobserved validation result must remain recorded as such. Do not convert absence of evidence into a pass.

## Physical Honesty

All logistics and construction behavior must preserve physical truth.

- An item must be removed from a real source before entering priest custody.
- Custody must remain explicit until delivery, return, or a recorded terminal failure.
- Destination inventories must be revalidated immediately before insertion.
- Partial insertion must preserve and return leftovers.
- Failed placement must restore or refund the real item that was removed.
- Fluids must move through real Factorio fluid networks rather than simulated item transfers or silent fluid deletion.
- Storage-full, target-destroyed, source-destroyed, interruption, and save/load paths must not create or erase resources.

Any behavior that cannot prove source removal, custody, destination insertion, and leftover disposition is incomplete.

## Authority Ownership

A concrete leaf task owns the immediate action.

Movement target, active leaf task, status text, and visible intent must identify the same concrete destination. A broad parent objective may remain as context, but it must not override the leaf target.

Existing automation retains ownership unless a system is explicitly designed to cooperate with it. Priests must not silently compete with inserters, loaders, logistics networks, train automation, rocket launch state, or other established control systems.

Specialized entity boundaries are mandatory:

- Artillery wagons may be serviced only while stationary and explicitly in manual control.
- Priest logic must never change train speed, schedule, state, target selection, or manual mode.
- Rocket payload, cargo, launch state, launch settings, and rocket-part state remain outside priest logistics authority except for explicitly approved manual ingredient and trash operations.
- Roboport robot population is monitor-only; repair-pack replenishment must not mutate construction- or logistic-robot strategy.
- Fluid-turret connections must use compatible real networks and valid unused interfaces.

## Runtime Event and Timing Ownership

The project must not accumulate competing event handlers or independent pulse authorities.

- Shared lifecycle events use the canonical runtime event registry.
- Shared periodic work uses the runtime tick broker.
- Broker services are registered idempotently by stable name.
- Configuration changes must not accumulate duplicate services, timers, or event handlers.
- Assertion and audit layers must not quietly become new movement, timing, mutation, recovery, or gameplay authorities.
- `on_load` must not write persistent storage.

New modules that require events or periodic execution must document who owns the event, service name, interval, budget, and why an existing authority cannot perform the work.

## Persistent State and Serialization

Everything stored under Factorio persistent storage must remain serializable.

Do not store functions, coroutines, package modules, cyclic tables, or other non-serializable runtime objects. Entity references may be stored only where Factorio explicitly supports them and must be validated before use.

Every custody-bearing or route-bearing task must survive save/load without duplicating resources, losing ownership, or preserving impossible targets. Diagnostic snapshots should copy primitive evidence rather than retain live module graphs or cyclic references.

## Failure Handling

Failure is a first-class state, not a silent return path.

Every executor must define cleanup for invalid targets, unavailable sources, failed movement, interrupted custody, combat interruption, destination refusal, route blockage, and configuration change. Cleanup must release reservations, preserve or return custody, clear incompatible leaf tasks, and record enough evidence to diagnose what happened.

Recovery code must be deliberately designed and tested. Read-only audits must not silently rewrite live state merely because they discover an inconsistency.

## Commandless Runtime and Diagnostics

Normal gameplay and required diagnostics must not depend on runtime console commands.

Automatic diagnostics are authoritative. They must expose installation state, broker integrity, lifecycle state, pair integrity, custody conflicts, invalid targets, missing modules, surviving commands, and other release-blocking conditions without requiring a player to know or run a command.

Command cleanup must remove only commands confirmed to belong to Tech Priests. Commands owned by unrelated mods must never be removed.

## Factorio API Discipline

All Factorio API use must be validated against the supported game version and exercised in a real load test before release.

Special attention is required for inventory constants, fluidbox geometry, train state, logistic cells, rocket silos, burner and burnt-result inventories, reactors, fusion entities, artillery wagons, roboports, commands, rendering, and configuration-change behavior.

Syntax validity is necessary but not sufficient. A Lua file that parses can still call an invalid runtime API or misuse a valid object in a particular lifecycle stage.

## Validation Gates

Development proceeds through these gates in order:

1. Governance and build prerequisites.
2. Source integration and installation integrity.
3. Objective static validation.
4. Factorio load, migration, save, and reload validation.
5. Behavioral integration scenarios.
6. Release-candidate packaging and final packaged load test.

A later gate must not be declared complete while an earlier gate remains failed or unevidenced.

Static validation must include Lua parsing, JSON parsing, Python compilation, inventory safety, integration graph checks, lifecycle checks, governance checks, and any focused checker added by the active milestone.

Runtime migration validation must include both a new-save scenario and an upgrade from a disposable copy of a real `0.1.672` save. Both must contain at least one valid station/priest pair and must produce unedited logs accepted by the runtime-evidence validator.

Behavioral validation must cover physical logistics, custody return, specialized entity boundaries, fluid networks, overlapping stations, combat interruption, save/load during active tasks, and agreement between movement, status, leaf truth, and visual intent.

## Packaging Rules

`tools/package_local.py` is the canonical local packager.

Packaging must fail closed when governance prerequisites are absent or inconsistent. Packaging must not bypass the standards document or canonical development history.

A package-version bump to `0.1.674` is permitted only after the required static, runtime, migration, behavioral, and packaged-load evidence exists and is recorded honestly in `docs/DEVELOPMENT_HISTORY.md`.

The final archive must have exactly one versioned top-level root, valid metadata, required runtime files, unique watched locale sections and keys, no development logs or caches, and content matching the verified source commit.

The deployable Factorio mod archive name and its top-level archive root must be derived exactly from `info.json` as `{name}_{version}`. For the current local `0.1.674` candidate, the only valid deployable archive identity is `tech-priests_0.1.674.zip` with a `tech-priests_0.1.674/` root. Hyphen-shortened names such as `tech-priests-0.1.674.zip` and smoke/test suffixes such as `tech-priests-0.1.674-local-smoke-...zip` are not valid deployment, runtime-validation, or behavioral-acceptance artifacts.

## Documentation and Development History

`docs/DEVELOPMENT_HISTORY.md` is the single canonical narrative development history.

Focused runbooks, behavior maps, milestone plans, manifests, and audit documents may exist, but they are supporting evidence rather than competing histories. Significant completed slices, validation results, blocked gates, package-version changes, and release decisions must be appended to the canonical history.

`RECOVERY_REPAIR_SEQUENCE.md` is the single explicit temporary exception and sequencing ledger for base-state recovery. It must not be replaced by a growing collection of per-slice repair-history documents.

History entries must distinguish:

- source implementation completed;
- source validation completed;
- runtime validation completed;
- behavioral validation completed;
- package built;
- packaged load test completed;
- release published.

Do not use one of those phrases as a substitute for another.

## Change Standard

Changes to this document require a dedicated commit on `main` and a matching entry in `docs/DEVELOPMENT_HISTORY.md`. A standards change must not silently weaken physical honesty, evidence requirements, single-branch development, serializability, automation ownership, or release truthfulness.