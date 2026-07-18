# Tech Priests Recovery Documentation Index

## Governing authority

- [`../RECOVERY_REPAIR_SEQUENCE.md`](../RECOVERY_REPAIR_SEQUENCE.md) — temporary top-level work-order authority.
- [`STANDARDS_AND_PRACTICES.md`](STANDARDS_AND_PRACTICES.md) — permanent engineering, safety, validation, and release-governance authority.
- [`DEVELOPMENT_HISTORY.md`](DEVELOPMENT_HISTORY.md) — canonical narrative record of completed work and evidence.
- [`state-of-mod-master-plan.md`](state-of-mod-master-plan.md) — current source, artifact, gate, and evidence state.

## Current architecture and implementation

- [`RECOVERY_AUTHORITY_MAP_CURRENT.md`](RECOVERY_AUTHORITY_MAP_CURRENT.md) — current Mermaid map through recovery Stages 0–4 and the external evidence boundary.
- [`../tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md`](../tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md) — runtime ownership boundaries.
- [`../tech-priests_src/docs/CURRENT_TESTING_GOALS.md`](../tech-priests_src/docs/CURRENT_TESTING_GOALS.md) — active Stage 5 validation matrix.
- `BEHAVIOR_MERMAID_*` and `BEHAVIOR_FUNCTION_MAP_0659.md` — historical detailed maps of the earlier authority stack.
- [`VOID_PRIEST_MOVEMENT_REPAIR_PLAN.md`](VOID_PRIEST_MOVEMENT_REPAIR_PLAN.md) — focused remaining Void movement stages.

## Runtime and migration evidence

- [`MIGRATION_RUNTIME_VALIDATION.md`](MIGRATION_RUNTIME_VALIDATION.md) — new-save and real `0.1.672` migration log procedure.
- [`RECOVERY_RUNTIME_EVIDENCE.md`](RECOVERY_RUNTIME_EVIDENCE.md) — complete recovery scenario, save/reload, high-count, and profiler evidence procedure.
- [`UPS_VALIDATION_RUNBOOK_0742.md`](UPS_VALIDATION_RUNBOOK_0742.md) — clean-world performance procedure.

## Evidence tooling

- `tools/check_migration_runtime_evidence_0737.py` — migration evidence validator.
- `tools/check_recovery_runtime_evidence_0747.py` — complete recovery evidence validator.
- `tools/create_recovery_evidence_template_0748.py` — exact pending manifest generator.
- `tools/check_recovery_architecture_0744.py` — source recovery contract checker.
- `tools/audit_ups_hotspots_0743.py` — static UPS baseline/regression checker.

## Release governance

- `tools/check_release_authorization_0745.py` — verified-release authorization checker.
- [`releases/VERIFIED_RELEASE_AUTHORIZATION.example.json`](releases/VERIFIED_RELEASE_AUTHORIZATION.example.json) — non-authorizing example only.
- `tools/package_local.py` — canonical packager; blocked during protected `0.1.672` recovery.
- Historical baseline and RC1–RC3 publication workflows are archived and deliberately fail.

## Evidence vocabulary

The following are distinct and must be reported separately:

1. source implementation;
2. source validation;
3. Factorio load;
4. migration;
5. save/reload;
6. behavioral validation;
7. performance validation;
8. package construction;
9. packaged load validation;
10. publication.

No earlier state implies a later one.
