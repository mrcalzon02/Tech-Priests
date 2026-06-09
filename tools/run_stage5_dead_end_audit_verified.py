#!/usr/bin/env python3
"""
Verified runner for the Stage 5 dead-end state field audit.

The Stage 5 report is expected to be large. This wrapper prevents an empty or
failed scanner output from being staged accidentally.

Run from repository root:

    python tools/run_stage5_dead_end_audit_verified.py

It runs:

    tools/audit_dead_end_state_fields.py

Then verifies:

- markdown report exists,
- JSON report exists,
- both files are non-empty,
- JSON parses,
- JSON total_hits is greater than zero,
- markdown contains the expected report title.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path("tech-priests_src")
SCANNER = Path("tools/audit_dead_end_state_fields.py")
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.json")


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    if not ROOT.exists():
        return fail(f"missing source root: {ROOT}")
    if not SCANNER.exists():
        return fail(f"missing scanner: {SCANNER}")

    lua_count = sum(1 for _ in ROOT.rglob("*.lua"))
    if lua_count <= 0:
        return fail(f"no Lua files found under {ROOT}; refusing to run")

    print(f"Running Stage 5 scanner over {lua_count} Lua files...")
    result = subprocess.run([sys.executable, str(SCANNER)], text=True)
    if result.returncode != 0:
        return fail(f"scanner failed with exit code {result.returncode}")

    for path in (MD, JSON_OUT):
        if not path.exists():
            return fail(f"expected output missing: {path}")
        size = path.stat().st_size
        if size < 100:
            return fail(f"expected output is suspiciously small ({size} bytes): {path}")

    md_text = MD.read_text(encoding="utf-8", errors="replace")
    if "# Stage 5 Dead-End State Field Report" not in md_text:
        return fail(f"markdown report does not contain expected title: {MD}")

    try:
        data = json.loads(JSON_OUT.read_text(encoding="utf-8", errors="replace"))
    except Exception as exc:
        return fail(f"JSON report could not be parsed: {exc}")

    total = int(data.get("total_hits") or 0)
    if total <= 0:
        return fail(f"JSON report total_hits is not positive: {total}")

    print(f"Stage 5 audit verified: total_hits={total}")
    print(f"Verified {MD} ({MD.stat().st_size} bytes)")
    print(f"Verified {JSON_OUT} ({JSON_OUT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
