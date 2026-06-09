#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECKS = [
    ROOT / "tools/check_stage5_movement_failure_batch.py",
    ROOT / "tools/check_stage5_proximity_gates.py",
    ROOT / "tools/check_void_movement_authority_0630.py",
]


def main() -> int:
    print("Stage 5 smoke-check bundle")
    failures: list[Path] = []
    for check in CHECKS:
        if not check.exists():
            print(f"FAIL {check.relative_to(ROOT)}: missing")
            failures.append(check)
            continue
        print(f"\n=== Running {check.relative_to(ROOT)} ===")
        result = subprocess.run([sys.executable, str(check)], cwd=ROOT)
        if result.returncode != 0:
            failures.append(check)
            print(f"FAIL {check.relative_to(ROOT)} exited {result.returncode}")
        else:
            print(f"OK   {check.relative_to(ROOT)}")

    if failures:
        print("\nStage 5 smoke-check bundle FAILED:")
        for check in failures:
            print(f"- {check.relative_to(ROOT)}")
        return 1

    print("\nStage 5 smoke-check bundle passed.")
    print("Proceed to manifest refresh and smoke-test packaging.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
