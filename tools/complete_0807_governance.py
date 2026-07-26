#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = Path("/tmp/source-validation-0807.yml")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8")


def append_once(path: str, marker: str, section: str) -> None:
    text = read(path)
    if marker in text:
        print(f"already registered: {path}: {marker}")
        return
    write(path, text.rstrip() + "\n\n" + section.strip() + "\n")
    print(f"registered: {path}: {marker}")


def prepare_source_validation_artifact() -> None:
    text = read(".github/workflows/source-validation.yml")
    checker = "check_status_state_sanity_ownership_0807.py"
    if checker not in text:
        old = (
            "      - name: Audit canonical infrastructure route ownership\n"
            "        run: python3 tools/check_infrastructure_route_ownership_0806.py\n\n"
            "      - name: Audit development integration graph\n"
        )
        new = (
            "      - name: Audit canonical infrastructure route ownership\n"
            "        run: python3 tools/check_infrastructure_route_ownership_0806.py\n\n"
            "      - name: Audit canonical status-state sanity ownership\n"
            "        run: python3 tools/check_status_state_sanity_ownership_0807.py\n\n"
            "      - name: Audit development integration graph\n"
        )
        if old not in text:
            raise RuntimeError("canonical Source-validation insertion boundary not found")
        text = text.replace(old, new, 1)
    ARTIFACT.write_text(text, encoding="utf-8")
    print(f"prepared connector workflow artifact: {ARTIFACT}")


HISTORY = """
## Milestone 0807 — Status-State Sanity Ownership — 2026-07-26

- `64a35abe1244310561d736f272eda1179a80fd2c` — consolidated `status_state_sanity_0448` under one fail-closed `runtime_event_registry` cadence, removed its raw `script.on_nth_tick` fallback, delayed global and wrapper publication until route acceptance, returned structured service truth, and made the visual-classifier adapter read-only.
- `223f47558a4db07a12ca3524fd16a441b34c951e` — added `check_status_state_sanity_ownership_0807.py` to forbid raw route fallback, mutable visual classification, publication before route acceptance, and unstructured service results.
- `28a875c3f9bd5b333a81710d43d564c674e39bd2` — added the dedicated ownership validation lane. At this exact source head, `tech-priests/status-state-sanity-ownership` passed in workflow run `30190776270`, and the then-current full `tech-priests/source-validation` passed in run `30190776290`.

The focused checker is prepared for registration in canonical Source validation through the workflow-authorized GitHub connector. This is static source evidence only. No Factorio load, configuration-change, migration, save/reload, behavioral, profiler, packaging, or release claim is made. The next bounded source audit is station supply and inventory stewardship ownership, beginning with `station_supply_satisfaction_0639`, `emergency_supply_reserve_0497`, `inventory_steward`, and `stone_cache_filter_0534`.
"""

TESTING = """
## Milestone 0807 — Status-state sanity ownership

- `status_state_sanity_0448` owns one named 31-tick `runtime_event_registry` cadence and has no raw timer fallback.
- Installation fails closed before global or wrapper publication when canonical route ownership is unavailable or rejected.
- The visual-classifier adapter is read-only; stale combat-state mutation remains in the cadence-owned service rather than display classification.
- The service reports structured `processed`, `acted`, `blocked`, `failed`, and `exhausted` truth.
- The focused checker is prepared for canonical Source-validation registration through the GitHub connector.
- Static validation is not Factorio runtime proof.

The next live target is new-save and protected-upgrade evidence that invalid or friendly combat targets are cleared through the canonical cadence, visual classification never mutates pair state, configuration changes do not duplicate the route, and save/reload preserves consistent idle/combat status. The next bounded source tranche audits station supply and inventory stewardship routes before Gate 2 evidence collection proceeds.
"""

AUTHORITY = """
## Milestone 0807 — Status-State Sanity Ownership

```mermaid
flowchart LR
    Registry[runtime_event_registry] -->|31-tick named route| Sanity[status_state_sanity_0448]
    Sanity --> Mutation[stale combat-state cleanup]
    Visual[classify_priest_visual_state adapter] -->|read-only observation| Display[combat or idle visual state]
```

`status_state_sanity_0448` owns one fail-closed registry cadence named `stale-combat-status-sanity`. Route acceptance occurs before global or wrapper publication. The visual classifier no longer calls the mutating inspection path; it only suppresses a stale combat presentation when the observed target is not hostile. No raw `script.on_nth_tick` fallback remains. This is source ownership evidence only.
"""

RECOVERY = """
Source implementation has now consolidated `status_state_sanity_0448` under one fail-closed canonical registry cadence. Its raw timer fallback is removed, publication follows route acceptance, service results are structured, and visual classification is read-only. Milestone 0807 has focused static validation but remains without Factorio runtime proof. The next bounded source audit targets station supply and inventory stewardship ownership before Gate 2 evidence collection.
"""


def main() -> int:
    prepare_source_validation_artifact()
    append_once("docs/DEVELOPMENT_HISTORY.md", "## Milestone 0807 — Status-State Sanity Ownership", HISTORY)
    append_once("tech-priests_src/docs/CURRENT_TESTING_GOALS.md", "## Milestone 0807 — Status-state sanity ownership", TESTING)
    append_once("docs/RECOVERY_AUTHORITY_MAP_CURRENT.md", "## Milestone 0807 — Status-State Sanity Ownership", AUTHORITY)

    recovery_path = "RECOVERY_REPAIR_SEQUENCE.md"
    recovery_text = read(recovery_path)
    recovery_marker = "Source implementation has now consolidated `status_state_sanity_0448`"
    if recovery_marker not in recovery_text:
        boundary = "\n# Completion and Retirement\n"
        if boundary not in recovery_text:
            raise RuntimeError("recovery completion boundary not found")
        write(recovery_path, recovery_text.replace(boundary, "\n" + RECOVERY.strip() + "\n" + boundary, 1))
        print("registered: RECOVERY_REPAIR_SEQUENCE.md: Milestone 0807")

    for temporary in (".github/0807-governance.trigger", "tools/complete_0807_governance.py"):
        path = ROOT / temporary
        if path.exists():
            path.unlink()
            print(f"removed temporary non-workflow carrier: {temporary}")

    print("Milestone 0807 document governance prepared")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
