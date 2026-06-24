#!/usr/bin/env python3
"""Static guard for generic Tech-Priest inventory deposit paths.

Generic storage, reserve, fetch, and loose-item modules must not treat machine
input/output/fuel inventories as arbitrary storage. Dedicated machine-family
executors may use those inventories because they revalidate exact targets and
own the corresponding physical task.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass

SOURCE_DIR = "tech-priests_src"

GENERIC_MODULE_HINTS = {
    "station_work_inventory",
    "inventory_steward",
    "storage_role_authority",
    "inventory_transfer_integrity",
    "emergency_supply_reserve",
    "logistics_fetch_executor",
    "ground_item_hoover",
    "retention",
}

FORBIDDEN_INVENTORIES = {
    "assembling_machine_input",
    "assembling_machine_output",
    "furnace_source",
    "furnace_result",
    "fuel",
    "burnt_result",
    "rocket_silo_input",
    "rocket_silo_output",
    "rocket_silo_rocket",
    "rocket_silo_trash",
    "artillery_turret_ammo",
    "artillery_wagon_ammo",
    "roboport_robot",
    "roboport_material",
}

INVENTORY_PATTERN = re.compile(
    r"defines\s*\.\s*inventory\s*\.\s*(?P<name>[A-Za-z0-9_]+)"
)


@dataclass(frozen=True)
class Finding:
    path: pathlib.Path
    line: int
    inventory: str
    text: str


def resolve_root(project_root: pathlib.Path) -> pathlib.Path:
    root = project_root.resolve()
    candidate = root / SOURCE_DIR
    if candidate.is_dir():
        return candidate
    if (root / "info.json").is_file():
        return root
    raise FileNotFoundError(f"could not locate {SOURCE_DIR} below {root}")


def is_generic_module(path: pathlib.Path) -> bool:
    stem = path.stem.lower()
    return any(hint in stem for hint in GENERIC_MODULE_HINTS)


def inspect_file(path: pathlib.Path) -> list[Finding]:
    findings: list[Finding] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for line_no, line in enumerate(text.splitlines(), start=1):
        code = line.split("--", 1)[0]
        for match in INVENTORY_PATTERN.finditer(code):
            inventory = match.group("name")
            if inventory in FORBIDDEN_INVENTORIES:
                findings.append(
                    Finding(
                        path=path,
                        line=line_no,
                        inventory=inventory,
                        text=line.strip(),
                    )
                )
    return findings


def run(project_root: pathlib.Path) -> int:
    mod_root = resolve_root(project_root)
    candidates = [
        path
        for path in sorted(mod_root.rglob("*.lua"))
        if is_generic_module(path)
    ]
    if not candidates:
        print("ERROR: no generic inventory modules matched the safety audit", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    for path in candidates:
        findings.extend(inspect_file(path))

    print(f"Inventory safety audit scanned {len(candidates)} generic modules.")
    if not findings:
        print("Inventory safety audit passed: no generic machine-inventory references found.")
        return 0

    print(
        "ERROR: generic inventory modules reference machine-specific inventories:",
        file=sys.stderr,
    )
    for finding in findings:
        rel = finding.path.relative_to(project_root.resolve())
        print(
            f"  {rel}:{finding.line}: defines.inventory.{finding.inventory}: "
            f"{finding.text}",
            file=sys.stderr,
        )
    print(
        "Move this access into a dedicated machine-family executor or explicitly "
        "remove the generic module from the deposit path.",
        file=sys.stderr,
    )
    return 1


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reject machine inventory constants in generic Tech-Priest storage paths."
    )
    parser.add_argument(
        "project_root",
        nargs="?",
        default=".",
        help="Repository root or mod root. Default: current directory",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        return run(pathlib.Path(args.project_root))
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
