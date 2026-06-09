#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tech-priests_src"
INFO = SRC / "info.json"
REQUIRED_FILES = [
    ROOT / "tools/check_stage5_smoke_bundle.py",
    ROOT / "tools/check_stage5_movement_failure_batch.py",
    ROOT / "tools/check_stage5_proximity_gates.py",
    ROOT / "tools/check_void_movement_authority_0630.py",
    ROOT / "docs/STAGE5_SMOKE_TEST_PACKAGE_CHECKLIST.md",
    SRC / "scripts/core/void_movement_authority_0630.lua",
    SRC / "scripts/core/movement_enforcement_0566.lua",
]


def main() -> int:
    failures: list[str] = []
    print("Stage 5 package-readiness checker")

    for path in REQUIRED_FILES:
        if not path.exists():
            failures.append(f"missing required file: {path.relative_to(ROOT)}")
        else:
            print(f"OK   {path.relative_to(ROOT)}")

    if not INFO.exists():
        failures.append("missing tech-priests_src/info.json")
    else:
        try:
            info = json.loads(INFO.read_text(encoding="utf-8"))
            version = str(info.get("version", "")).strip()
            print(f"INFO version={version}")
            if not version:
                failures.append("info.json version is empty")
            if version != "0.1.628":
                failures.append(f"info.json version is {version}; expected pre-smoke version 0.1.628 before final bump")
        except Exception as exc:
            failures.append(f"could not parse info.json: {exc}")

    if failures:
        print("\nFAIL package readiness")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("\nPackage readiness markers are present.")
    print("Next local command: python tools/check_stage5_smoke_bundle.py")
    print("After that passes, follow docs/STAGE5_SMOKE_TEST_PACKAGE_CHECKLIST.md to create the smoke ZIP.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
