# Tech Priests Migration Runtime Validation

## Purpose

This runbook covers the mandatory Factorio runtime evidence gate for the `0.1.674-dev` milestone. Source validation can prove that modules parse and are wired correctly, but it cannot prove that Factorio accepts the APIs, restores persistent state, invokes configuration-change handlers, or preserves every Cogitator and Tech-Priest pair across save migration.

The authoritative source remains packaged as `0.1.672`. Runtime migration testing uses the unpackaged `0.1.673` test copy created by `tools/prepare_migration_test_mod.py`. That directory is test-only and must never be zipped, published, or treated as a release.

## Required Scenarios

Both scenarios must pass against the same source commit.

### Scenario A: new save

1. Remove or disable any older unpackaged Tech Priests development copy.
2. Create a fresh `tech-priests_0.1.673` migration-test directory from the current `main` source.
3. Start Factorio with the migration-test directory enabled.
4. Create a new game and place enough Tech Priests infrastructure to produce at least one valid station/priest pair when practical.
5. Allow the automatic diagnostics to run, save the game, reload it once, and allow diagnostics to run again.
6. Exit Factorio normally and preserve the resulting unedited `factorio-current.log` as the new-save evidence log.

The validator requires the lifecycle checkpoint to report `last_reason=on-init`, no old or new migration version, a complete installation, a complete event registry, and clean hardener, broker, planner, integration, commandless, and migration-pair audits.

### Scenario B: upgrade from 0.1.672

1. Make a copy of a real save last written with packaged Tech Priests `0.1.672`.
2. Confirm the copied save contains every station/priest pair and representative active state that must survive migration.
3. Replace the packaged baseline with the unpackaged `tech-priests_0.1.673` migration-test directory.
4. Load only the copied save. Never use the original save as the migration test target.
5. Allow configuration-change processing and automatic diagnostics to finish.
6. Save under a new test filename, reload that migrated save once, and allow diagnostics to run again.
7. Exit Factorio normally and preserve the resulting unedited `factorio-current.log` as the upgrade evidence log.

The validator requires the lifecycle checkpoint to report `last_reason=configuration-changed`, `old_version=0.1.672`, and `new_version=0.1.673`. Pair entries, valid pairs, stations, and priests must agree exactly, with zero invalid pairs and zero migration issues.

## Build the Test Copy

From the repository root:

```bash
python tools/prepare_migration_test_mod.py . \
  --output-root build/migration-test \
  --source-ref <current-main-commit> \
  --overwrite
```

The output directory must be named `tech-priests_0.1.673` and must contain `MIGRATION_TEST_ONLY.json`. The authoritative `tech-priests_src/info.json` must remain at `0.1.672`.

On Windows PowerShell, the same operation can be run as one line:

```powershell
python tools/prepare_migration_test_mod.py . --output-root build/migration-test --source-ref <current-main-commit> --overwrite
```

## Validate the Runtime Logs

Run the checker separately for each unedited log:

```bash
python tools/check_migration_runtime_evidence_0737.py path/to/new-save/factorio-current.log \
  --scenario new-save \
  --source-ref <current-main-commit> \
  --json-output build/migration-evidence/new-save.json
```

```bash
python tools/check_migration_runtime_evidence_0737.py path/to/upgrade/factorio-current.log \
  --scenario upgrade-0.1.672 \
  --source-ref <current-main-commit> \
  --json-output build/migration-evidence/upgrade-0.1.672.json
```

The checker hashes each source log and records the exact accepted diagnostic lines in the JSON result. A failed result must remain failed until a new Factorio run produces new evidence; do not hand-edit the log or the JSON record.

## Evidence Acceptance Rules

A scenario passes only when all of the following are true:

- Factorio reports no failed-mod load, control-stage failure, Lua traceback, Lua runtime error, or event-handler error.
- Every planning hardener reports successful installation, with attempted and passed counts equal and zero failures.
- The migration pair audit, lifecycle checkpoint, broker audit, and migration assertion all report successful activation.
- The assertion layer reports zero mutations and zero timing authorities of its own.
- The automatic hardener diagnostic is complete with zero failures.
- The automatic lifecycle diagnostic is complete and all subordinate audits pass.
- The automatic migration-pair diagnostic is read-only, complete, and reports zero invalid pairs and zero issues.
- Pair entries, valid pairs, station count, and priest count agree exactly.
- The automatic broker diagnostic reports zero missing, duplicate, or malformed services.
- The scenario-specific lifecycle reason and versions match the actual test performed.

## Evidence Retention

Keep the following together for each accepted scenario:

- the exact source commit SHA;
- the unedited `factorio-current.log`;
- the generated JSON validation record;
- the test save filename and whether it was new or migrated;
- the Factorio version and enabled mod list;
- a note confirming the migrated save was a disposable copy.

Do not commit personal save data or full local filesystem paths to the public repository. The JSON record includes the local log path for operator traceability, so review it before publishing and keep public history limited to the source commit, hashes, pass/fail result, Factorio version, and sanitized test notes.

## Milestone Boundary

Passing both runtime scenarios completes the migration load-and-persistence portion of Gate 4. It does not by itself complete the behavioral integration matrix, justify a package-version bump, or authorize a `0.1.674` release archive. The next milestone work must proceed to focused behavioral scenarios only after both migration evidence records pass.
