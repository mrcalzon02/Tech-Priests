#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path("tech-priests_src")

PATCHED_FILES = [
    ROOT / "scripts/core/logistics_fetch_executor_0527.lua",
    ROOT / "scripts/core/logistics_machine_fulfillment_0528.lua",
    ROOT / "scripts/core/ground_item_hoover_0529.lua",
    ROOT / "scripts/core/crafting_executor.lua",
    ROOT / "scripts/core/emergency_production_executor_0514.lua",
    ROOT / "scripts/core/repair_executor_0516.lua",
    ROOT / "scripts/core/consecration_executor_0515.lua",
    ROOT / "scripts/core/construction_planner.lua",
    ROOT / "scripts/core/combat_repair_doctrine_0517.lua",
]

REQUIRED_MARKERS = {
    "logistics_fetch_executor_0527.lua": ["movement-request-failed-0527", "moving-to-known-source"],
    "logistics_machine_fulfillment_0528.lua": ["movement-request-failed-0528", "moving-to-machine", "moving-to-storage"],
    "ground_item_hoover_0529.lua": ["movement-request-failed-0529", "moving-to-ground-item", "moving-to-storage"],
    "crafting_executor.lua": ["craft-return-movement-failed", "movement_request_failed"],
    "emergency_production_executor_0514.lua": ["movement-request-failed-0514", "movement-request-failed"],
    "repair_executor_0516.lua": ["movement-request-failed-0516", "repair-movement-failed"],
    "consecration_executor_0515.lua": ["movement-request-failed-0515", "consecration-movement-failed"],
    "construction_planner.lua": ["movement-request-failed", "construction-movement-failed", "movement_request_failed"],
    "combat_repair_doctrine_0517.lua": ["release_cluster_key", "repair-executor-missing", "repair-error", "combat_repair_target_0517=nil"],
}


def strip_comments_and_strings(src: str) -> str:
    # Lightweight scanner only: enough to catch common accidental token explosions,
    # not a replacement for Factorio/Lua loading.
    out = []
    in_single = False
    in_double = False
    escape = False
    for line in src.splitlines():
        i = 0
        cleaned = []
        while i < len(line):
            ch = line[i]
            nxt = line[i + 1] if i + 1 < len(line) else ""
            if not in_single and not in_double and ch == "-" and nxt == "-":
                break
            if in_single or in_double:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif in_single and ch == "'":
                    in_single = False
                elif in_double and ch == '"':
                    in_double = False
                cleaned.append(" ")
            else:
                if ch == "'":
                    in_single = True
                    cleaned.append(" ")
                elif ch == '"':
                    in_double = True
                    cleaned.append(" ")
                else:
                    cleaned.append(ch)
            i += 1
        out.append("".join(cleaned))
    return "\n".join(out)


def token_count(cleaned: str, token: str) -> int:
    return len(re.findall(r"(?<![A-Za-z0-9_])" + re.escape(token) + r"(?![A-Za-z0-9_])", cleaned))


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    if not path.exists():
        return [f"missing file: {path}"]
    src = path.read_text(encoding="utf-8", errors="replace")
    cleaned = strip_comments_and_strings(src)

    if src.count("(") != src.count(")"):
        errors.append(f"paren count mismatch: (={src.count('(')} )={src.count(')')}")
    if src.count("{") != src.count("}"):
        errors.append(f"brace count mismatch: {{={src.count('{')} }}={src.count('}')}")

    # Heuristic block sanity: exact equality is not expected because if/for/function
    # share end tokens. This catches obvious destructive truncation.
    opens = token_count(cleaned, "function") + token_count(cleaned, "if") + token_count(cleaned, "for") + token_count(cleaned, "while") + token_count(cleaned, "do")
    closes = token_count(cleaned, "end")
    if closes < token_count(cleaned, "function"):
        errors.append("fewer end tokens than function tokens")
    if opens and closes == 0:
        errors.append("block open tokens found but no end tokens")

    markers = REQUIRED_MARKERS.get(path.name, [])
    for marker in markers:
        if marker not in src:
            errors.append(f"missing expected marker: {marker}")

    if "movement-request-failed" in src and "return false" not in src:
        errors.append("movement failure marker present but no return false in file")

    return errors


def main() -> int:
    failures = []
    print("Stage 5 movement-failure batch checker")
    for path in PATCHED_FILES:
        errors = check_file(path)
        if errors:
            failures.append((path, errors))
            print(f"FAIL {path}")
            for e in errors:
                print(f"  - {e}")
        else:
            print(f"OK   {path}")
    if failures:
        print(f"\nFAILED: {len(failures)} files need review")
        return 1
    print("\nAll patched movement-failure files passed lightweight marker/balance checks.")
    print("This does not replace a Factorio load test.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
