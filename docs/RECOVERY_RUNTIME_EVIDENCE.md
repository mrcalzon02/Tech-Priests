# Tech Priests Complete Recovery Runtime Evidence

**Status:** Stable operator runbook for Recovery Stage 5  
**Authoritative work order:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Active test matrix:** `tech-priests_src/docs/CURRENT_TESTING_GOALS.md`  
**Validator:** `tools/check_recovery_runtime_evidence_0747.py`  
**Schema:** `tech-priests-recovery-runtime-evidence-0747-v2`

## Purpose

This runbook defines the evidence required to move Tech Priests beyond source implementation. The validator does not run Factorio. A human operator must execute every scenario in Factorio 2.0 against one exact source commit, preserve the relevant logs and profiler records, calculate their SHA-256 digests, and complete one manifest.

Version 2 binds every accepted record to the exact retained file. A path without a matching digest is not evidence.

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
│   └── ... one retained record or shared marked log for every scenario
└── profiles/
    ├── idle.json
    ├── active.json
    └── high-count.json
```

A scenario may reference a complete new-save or upgrade log when that log contains the exact scenario marker. Do not edit a failure out of a log. A deliberately produced scenario extract must retain the exact source SHA, exact pass marker, relevant automatic diagnostics, and no release-blocking error pattern.

## Source Identity

Choose one full 40-character lowercase commit SHA and use it for every source, migration, behavior, and profiler run.

Record it in:

- `recovery-evidence.json`;
- both complete Factorio logs;
- every scenario record and retained scenario file;
- every profiler record and profiler JSON file.

Evidence from another commit is invalid for the selected candidate.

## Required Full Logs

The new-save and upgrade logs must each contain:

- the exact source SHA;
- a positive station/priest pair count;
- final hardener diagnostics with `phase=complete` and zero failed hardeners;
- canonical dispatcher diagnostics;
- pure classifier diagnostics;
- direct-acquisition diagnostics;
- consecration diagnostics;
- commandless-runtime diagnostics;
- no Lua, event, handler, broker-service, API, or serialization error.

Both complete logs require matching manifest fields:

```json
{
  "new_save_log": "new-save-factorio-current.log",
  "new_save_log_sha256": "64-character-lowercase-sha256",
  "upgrade_log": "upgrade-factorio-current.log",
  "upgrade_log_sha256": "64-character-lowercase-sha256"
}
```

The upgrade scenario must begin from a disposable copy of a real `0.1.672` save. Both scenarios must be saved, closed, restarted, and reloaded successfully.

## Scenario Pass Markers

Every required scenario must have a retained file containing this exact line:

```text
TECH-PRIESTS-RECOVERY-SCENARIO <scenario-id> PASS
```

For example:

```text
TECH-PRIESTS-RECOVERY-SCENARIO emergency-production-success PASS
```

The same retained file must contain the exact source SHA and relevant diagnostics. A checkbox, screenshot, prose claim, or manifest status without the exact retained-file marker is insufficient.

Each manifest scenario record has this shape:

```json
{
  "status": "pass",
  "source_commit": "40-character-source-sha",
  "evidence": "Concrete observation describing physical state, terminal result, and relevant counters.",
  "log": "scenarios/emergency-production-success.log",
  "log_sha256": "64-character-lowercase-sha256"
}
```

Evidence descriptions must be concrete and at least twenty characters. The validator rejects unknown scenario identifiers, missing markers, mixed source commits, digest mismatches, and release-blocking error patterns.

## Required Scenario Matrix

The canonical identifiers live in `tools/check_recovery_runtime_evidence_0747.py`. They cover:

- new-save, real `0.1.672` upgrade, and both reloads;
- final hardener completion;
- event ordering, replacement, isolated owner removal, and handler failure isolation;
- broker zero/waiting truth and cadence preservation;
- emergency-production success, rollback, and output custody;
- queue-full rejection, lossless preemption, distinct targets, exactly-once callbacks, and acquisition-to-production transition;
- consecration claim cleanup, refund custody, and save/load;
- direct-acquisition custody, return retry, and station-craft transition;
- machine logistics, storage-full recovery, energy, silos, artillery, roboports, fluids, and fluid turrets;
- combat interruption and overlapping reservations;
- canonical action, movement, status, and visual agreement;
- ordinary and Void movement, obstruction, and high-count fairness;
- broker fairness, diagnostic cost, and all three profiler scenarios.

Generate the template from the validator rather than typing identifiers manually.

## Profiler Records

The manifest requires exactly `idle`, `active`, and `high-count`. Each record requires:

- the same exact source SHA;
- at least 30 samples;
- nonnegative `average_ms` and `worst_ms`;
- `worst_ms` not below `average_ms`;
- a positive valid pair count;
- at least 49 valid pairs for `high-count`;
- a retained profiler JSON path and matching `file_sha256`.

Example manifest record:

```json
{
  "profile_id": "high-count",
  "source_commit": "40-character-source-sha",
  "samples": 60,
  "average_ms": 0.42,
  "worst_ms": 1.81,
  "pair_count": 64,
  "file": "profiles/high-count.json",
  "file_sha256": "64-character-lowercase-sha256"
}
```

The retained profile JSON must contain the same `profile_id`, source commit, sample count, average, worst value, and pair count. The static UPS baseline must pass for the same source, but static source counts and runtime profiler measurements remain separate evidence.

## Generate the Pending Template

From the repository root:

```bash
python3 tools/create_recovery_evidence_template_0748.py \
  <40-character-source-sha> \
  --output /absolute/path/to/tech-priests-recovery-evidence/recovery-evidence.json
```

The generator creates:

- every required scenario as `pending`;
- empty `log_sha256` fields;
- pending `idle`, `active`, and `high-count` profiler JSON files;
- empty `file_sha256` fields.

The generated files are not evidence.

## Calculate Digests

Use a trusted SHA-256 utility after each retained file is finalized:

```bash
sha256sum new-save-factorio-current.log
sha256sum upgrade-factorio-current.log
sha256sum scenarios/*.log
sha256sum profiles/*.json
```

Copy the lowercase digest into the corresponding manifest field. Any later file modification invalidates the digest and must be investigated, not concealed.

## Manifest Skeleton

```json
{
  "schema": "tech-priests-recovery-runtime-evidence-0747-v2",
  "source_commit": "40-character-source-sha",
  "factorio_version": "2.0",
  "new_save_contains_pairs": true,
  "upgrade_contains_pairs": true,
  "unedited_logs": true,
  "static_ups_baseline_passed": true,
  "new_save_log": "new-save-factorio-current.log",
  "new_save_log_sha256": "64-character-sha256",
  "upgrade_log": "upgrade-factorio-current.log",
  "upgrade_log_sha256": "64-character-sha256",
  "scenarios": {},
  "profiles": {
    "idle": {},
    "active": {},
    "high-count": {}
  }
}
```

## Validation Commands

Prove the validator rejects corrupted evidence:

```bash
python3 tools/check_recovery_runtime_evidence_0747.py --self-test
```

Prove the template and documentation wiring:

```bash
python3 tools/create_recovery_evidence_template_0748.py \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --self-test
python3 tools/check_recovery_evidence_wiring_0749.py
```

Validate the real evidence directory:

```bash
python3 tools/check_recovery_runtime_evidence_0747.py \
  /absolute/path/to/tech-priests-recovery-evidence
```

Acceptance prints:

```text
Recovery runtime evidence accepted.
```

Any rejection remains release-blocking. Do not edit evidence to remove a real failure; repair source, select a new exact commit, and rerun affected scenarios.

## Release Handoff

After the validator accepts one directory:

1. record the accepted evidence location, digests, and exact SHA in `docs/DEVELOPMENT_HISTORY.md`;
2. complete the separate `VERIFIED_RELEASE_AUTHORIZATION.json` required by `tools/check_release_authorization_0745.py`;
3. advance `info.json` only through the qualified version transition;
4. run the canonical packager;
5. install the exact archive and repeat clean new-save and real `0.1.672` upgrade load tests;
6. publish only under the artifact classification actually proven.

Accepted runtime evidence is necessary but does not by itself prove the packaged archive.
