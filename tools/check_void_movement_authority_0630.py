#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path("tech-priests_src")
VOID_AUTHORITY = ROOT / "scripts/core/void_movement_authority_0630.lua"
MOVEMENT_ENFORCEMENT = ROOT / "scripts/core/movement_enforcement_0566.lua"

VOID_MARKERS = [
    "M.storage_key = \"void_movement_authority_0630\"",
    "function M.is_void_pair",
    "function M.request",
    "function M.stop",
    "function M.status",
    "function M.service",
    "function M.patch_globals",
    "function M.install",
    "void_movement_request_0630",
    "void-movement-request",
    "void-movement-arrived",
    "void-jetpack-transit",
    "TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630",
    "tech_priests_request_movement_0418=function",
    "tech_priests_movement_status_0418=function",
]

ENFORCEMENT_MARKERS = [
    "local function install_void_movement_authority()",
    "require, \"scripts.core.void_movement_authority_0630\"",
    "Void0630.install()",
    "install_void_movement_authority()",
]

FORBIDDEN_VOID_MARKERS = [
    "defines.command.go_to_location",
    "commandable.set_command({type=defines.command.go_to_location",
    "commandable.set_command({ type=defines.command.go_to_location",
]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def check_markers(path: Path, markers: list[str]) -> list[str]:
    if not path.exists():
        return [f"missing file: {path}"]
    src = read(path)
    return [f"{path}: missing marker: {m}" for m in markers if m not in src]


def main() -> int:
    failures: list[str] = []
    print("Void Movement Authority 0630 checker")

    failures.extend(check_markers(VOID_AUTHORITY, VOID_MARKERS))
    failures.extend(check_markers(MOVEMENT_ENFORCEMENT, ENFORCEMENT_MARKERS))

    if VOID_AUTHORITY.exists():
        src = read(VOID_AUTHORITY)
        for marker in FORBIDDEN_VOID_MARKERS:
            if marker in src:
                failures.append(f"{VOID_AUTHORITY}: forbidden ground-pathing marker present: {marker}")
        if "M.service_interval = 1" not in src:
            failures.append(f"{VOID_AUTHORITY}: expected tick-level service interval is missing")
        if "pair.movement_controller_state_0418=\"void-arrived\"" not in src and "void-arrived" not in src:
            failures.append(f"{VOID_AUTHORITY}: arrival state marker missing")

    if failures:
        print("FAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("OK   void_movement_authority_0630.lua exposes separate Void movement API/state/service markers")
    print("OK   movement_enforcement_0566.lua installs the Void authority after the ground wrapper")
    print("OK   no forbidden go_to_location ground-pathing marker was found in the Void authority")
    print("\nThis is a marker/load-risk check, not an in-game movement test.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
