#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

CHECKER = Path("tools/check_governance_prerequisites_0738.py")
HISTORY = Path("docs/DEVELOPMENT_HISTORY.md")
OLD_SHA = "fdf6039be809a80865e8ea96c551dc0d0797d181"

text = CHECKER.read_text(encoding="utf-8")

if "import re\n" not in text:
    anchor = "import pathlib\nimport sys\n"
    if text.count(anchor) != 1:
        raise SystemExit("governance import anchor mismatch")
    text = text.replace(anchor, "import pathlib\nimport re\nimport sys\n", 1)

text = text.replace(f'        "{OLD_SHA}",\n', "")

required_insertions = (
    (
        '        "### Gate 1 source validation accepted — 2026-07-20",\n',
        '        "### Gate 1 source validation accepted — 2026-07-20",\n'
        '        "## 2026-07-23 — Post-Cleanup Inventory and Documentation Reconciliation",\n',
    ),
    (
        '        "## Gate 1 — Full source validation",\n',
        '        "### Post-cleanup authority inventory — 2026-07-23",\n'
        '        "## Gate 1 — Full source validation",\n',
    ),
    (
        '        "## Retired Authority Boundary",\n',
        '        "Planning --> Retired[47 retired authorities]",\n'
        '        "## Retired Authority Boundary",\n'
        '        "## Post-Cleanup Authority Inventory — 2026-07-23",\n',
    ),
)
for anchor, replacement in required_insertions:
    if replacement not in text:
        if text.count(anchor) != 1:
            raise SystemExit(f"governance required-marker anchor mismatch: {anchor!r}")
        text = text.replace(anchor, replacement, 1)

consistency_anchor = '    try:\n        info = json.loads(read("info", errors))\n'
consistency_block = (
    '    accepted_sha = ""\n'
    '    accepted_run = ""\n'
    '    testing_evidence = re.search(\n'
    '        r"\\*\\*Status: passed\\.\\*\\* Exact SHA `([0-9a-f]{40})` completed .*? in run `([0-9]+)`\\.",\n'
    '        texts["testing"],\n'
    '    )\n'
    '    map_evidence = re.search(\n'
    '        r"\\*\\*Source validation evidence:\\*\\* Passed for `([0-9a-f]{40})` in run `([0-9]+)`",\n'
    '        texts["map"],\n'
    '    )\n'
    '    if testing_evidence is None:\n'
    '        errors.append("CURRENT_TESTING_GOALS.md missing parseable accepted Source validation evidence")\n'
    '    if map_evidence is None:\n'
    '        errors.append("RECOVERY_AUTHORITY_MAP_CURRENT.md missing parseable accepted Source validation evidence")\n'
    '    if testing_evidence is not None and map_evidence is not None:\n'
    '        accepted_sha, accepted_run = testing_evidence.groups()\n'
    '        map_sha, map_run = map_evidence.groups()\n'
    '        if (accepted_sha, accepted_run) != (map_sha, map_run):\n'
    '            errors.append(\n'
    '                "testing goals and recovery authority map disagree on accepted Source validation evidence: "\n'
    '                f"testing={accepted_sha}/{accepted_run}, map={map_sha}/{map_run}"\n'
    '            )\n'
    '        if accepted_sha not in texts["history"] or f"run `{accepted_run}`" not in texts["history"]:\n'
    '            errors.append("canonical development history does not record the accepted Source validation SHA and run")\n'
    '\n'
)
if "testing_evidence = re.search(" not in text:
    if text.count(consistency_anchor) != 1:
        raise SystemExit("governance consistency insertion anchor mismatch")
    text = text.replace(consistency_anchor, consistency_block + consistency_anchor, 1)

old_print = (
    '    print(\n'
    '        "Governance prerequisite audit passed. Protected source=0.1.672; "\n'
    '        "accepted Gate1=fdf6039be809a80865e8ea96c551dc0d0797d181; "\n'
    '        "recovery graph=26 active/30 retired; v0.1.674-rc.3=experimental prerelease; "\n'
    '        "authorization=v2 absent."\n'
    '    )\n'
)
new_print = (
    '    print(\n'
    '        "Governance prerequisite audit passed. Protected source=0.1.672; "\n'
    '        f"accepted Gate1={accepted_sha} run={accepted_run}; "\n'
    '        "recovery graph=26 active/47 retired; v0.1.674-rc.3=experimental prerelease; "\n'
    '        "authorization=v2 absent."\n'
    '    )\n'
)
if old_print in text:
    text = text.replace(old_print, new_print, 1)
elif "accepted Gate1={accepted_sha}" not in text:
    raise SystemExit("governance success summary anchor mismatch")

CHECKER.write_text(text, encoding="utf-8")

history = HISTORY.read_text(encoding="utf-8")
heading = "## 2026-07-23 — Milestone 0791: Dynamic Governance Evidence Consistency"
if heading not in history:
    history += (
        f"\n\n{heading}\n\n"
        "Repaired the governance prerequisite audit so accepted Source-validation evidence is parsed and compared across CURRENT_TESTING_GOALS.md, RECOVERY_AUTHORITY_MAP_CURRENT.md, and the canonical development history instead of being hard-coded to the July 20 SHA. The audit now requires the synchronized post-cleanup inventory markers, the 47-retired authority diagram, and a consistent 40-character SHA plus workflow run. Its success summary now reports 26 active and 47 retired authorities. Static validation remains distinct from Factorio runtime evidence.\n"
    )
    HISTORY.write_text(history, encoding="utf-8")

print("0791 dynamic governance evidence repair complete")
