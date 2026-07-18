# Tech Priests Complete Recovery Runtime Evidence

**Status:** Stable operator runbook for Recovery Stage 5  
**Authoritative work order:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Active test matrix:** `tech-priests_src/docs/CURRENT_TESTING_GOALS.md`  
**Validator:** `tools/check_recovery_runtime_evidence_0747.py`

## Purpose

This runbook defines the evidence required to move Tech Priests beyond source implementation. It does not replace the existing migration runbook. It adds the complete transaction, scheduler, runtime-spine, specialized-family, movement, high-count, and profiler evidence required by the recovery sequence.

The validator does not run Factorio. A human operator must execute the scenarios in Factorio 2.0 against one exact source commit, preserve the resulting unedited logs, and describe the observed evidence in one manifest.

## Evidence Directory

Create one directory outside the repository working tree:

```text
tech-priests-recovery-evidence/
├── recovery-evidence.json
├── new-save-factorio-current.log
├── upgrade-factorio-current.log
├── scenarios/
│   ├── emergency-production-success.log
│   ├── order-queue-full-rejection.log
│   ├── consecration-refund-custody.log
│   ├── direct-acquisition-physical-custody.log
│   └── ... one retained log or extract for every required scenario
└── profiles/
    ├── idle.json
    ├── active.json
    └── high-count.json
```

Scenario records may reference the complete new-save or upgrade log when the relevant evidence is already present there. Do not edit a log merely to make the validator accept it.

## Source Identity

Choose one exact commit and use it for every source, migration, behavior, and profiler run.

Record the full 40-character lowercase SHA in:

- `recovery-evidence.json`;
- both complete Factorio logs;
- every scenario record;
- every profile record.

A scenario or profile produced from another commit is invalid evidence for the selected candidate.

## Required Full Logs

The new-save and upgrade logs must each contain:

- the exact source SHA;
- at least one valid station/priest pair;
- final hardener installation diagnostics with `phase=complete` and zero failed hardeners;
- canonical dispatcher diagnostics;
- pure action-classifier diagnostics;
- direct-acquisition diagnostics;
- consecration diagnostics;
- commandless-runtime diagnostics;
- no Lua, event, handler, broker-service, API, or serialization error.

The upgrade scenario must begin from a disposable copy of a real `0.1.672` save. Both the new-save and upgrade scenarios must be saved, closed, and successfully reloaded.

## Required Scenario Matrix

The validator requires the exact scenario identifiers defined inside `tools/check_recovery_runtime_evidence_0747.py`. The current matrix covers:

- new-save, upgrade, and both reloads;
- final hardener completion;
- event ordering, replacement, owner-specific removal, and handler isolation;
- broker zero/waiting truth and cadence preservation;
- emergency-production success, rollback, and output custody;
- queue-full rejection, preemption, distinct targets, exactly-once callbacks, and acquisition-to-production transition;
- consecration claim cleanup, refund custody, and save/load;
- direct-acquisition custody, return retry, and station-craft transition;
- machine logistics, storage-full recovery, energy automation ownership, rocket silos, artillery, roboports, fluids, and fluid turrets;
- combat interruption and overlapping-station reservations;
- canonical action, movement, status, and visual agreement;
- ordinary and Void movement, obstruction, and high-count fairness;
- broker high-count fairness;
- diagnostic cost and idle, active, and high-count profiler passes.

Each scenario record must contain:

```json
{
  "status": "pass",
  "source_commit": "40-character-sha",
  "evidence": "Concrete observation and relevant automatic diagnostic counters.",
  "log": "relative/path/to/the/evidence.log"
}
```

A checkbox, assertion without a log, screenshot alone, or description copied from expected behavior is not sufficient.

## Profiler Records

The manifest must include `idle`, `active`, and `high-count` profile records. Each record requires:

- the same exact source SHA;
- at least 30 samples;
- nonnegative average and worst milliseconds;
- a positive valid pair count;
- at least 49 valid pairs for the high-count profile.

Example:

```json
{
  "source_commit": "40-character-sha",
  "samples": 60,
  "average_ms": 0.42,
  "worst_ms": 1.81,
  "pair_count": 64
}
```

The static UPS baseline must also pass for the same source. Static source counts and runtime profiler measurements are separate evidence.

## Manifest Skeleton

Generate the full scenario object from the validator’s `REQUIRED_SCENARIOS` tuple rather than manually guessing identifiers. The top level has this shape:

```json
{
  "schema": "tech-priests-recovery-runtime-evidence-0747-v1",
  "source_commit": "40-character-sha",
  "factorio_version": "2.0",
  "new_save_contains_pairs": true,
  "upgrade_contains_pairs": true,
  "unedited_logs": true,
  "static_ups_baseline_passed": true,
  "new_save_log": "new-save-factorio-current.log",
  "upgrade_log": "upgrade-factorio-current.log",
  "scenarios": {},
  "profiles": {
    "idle": {},
    "active": {},
    "high-count": {}
  }
}
```

## Validation Commands

First prove the validator itself still rejects bad evidence:

```bash
python3 tools/check_recovery_runtime_evidence_0747.py --self-test
```

Then validate the real evidence directory:

```bash
python3 tools/check_recovery_runtime_evidence_0747.py \
  /absolute/path/to/tech-priests-recovery-evidence
```

Acceptance produces:

```text
Recovery runtime evidence accepted.
```

Any listed rejection remains release-blocking. Do not edit the evidence to remove a real failure; repair the source, choose a new exact commit, and rerun the affected scenarios.

## Release Handoff

After the recovery evidence validator accepts the directory:

1. Record the accepted evidence location and exact SHA in `docs/DEVELOPMENT_HISTORY.md`.
2. Complete the separate verified-release authorization record required by `tools/check_release_authorization_0745.py`.
3. Advance `info.json` only as part of the qualified version transition.
4. Run the canonical packager.
5. Install the exact archive and repeat clean new-save and real `0.1.672` upgrade load tests.
6. Publish only under the artifact classification actually proven.

Acceptance of this runtime evidence is necessary but does not by itself prove the packaged archive.
