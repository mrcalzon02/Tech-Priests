#!/usr/bin/env python3
"""Parse *actual* Factorio --test-scenario read-only observations.

The census is not a combat test. Do not mark remote methods safe to call
just because their names appear here.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

MARKER = re.compile(r"\[WAR-OBS\]\s+([A-Z]+)\|([^|\r\n]*)\|([^\r\n]*)")


def collect(log_text: str) -> dict:
    records: dict[str, dict[str, str]] = {}
    for match in MARKER.finditer(log_text):
        category, name, value = match.groups()
        records.setdefault(category, {})[name] = value.strip()
    return records


def verdict(records: dict) -> list[str]:
    problems = []
    if records.get("STATUS", {}).get("phase") != "COMPLETE":
        problems.append("native script did not report COMPLETE")
    if records.get("MOD", {}).get("aai-programmable-vehicles") != "0.9.2":
        problems.append("AAI 0.9.2 was not read back from native script.active_mods")
    for name in ("kj_40kpredator", "kj_40klemanruss", "kj_40kbaneblade", "kj_40kdreadnought"):
        if name not in records.get("MOD", {}):
            problems.append(f"missing mod readback: {name}")
    for name in ("tank", "car"):
        if name not in records.get("VEHICLE", {}):
            problems.append(f"missing vanilla car prototype: {name}")
    if len(records.get("TURRET", {})) < 4:
        problems.append("fewer than four native turret families observed")
    if "registered_count" not in records.get("REMOTE", {}):
        problems.append("remote interface table was not inspected")
    return problems


def summarize(records: dict, errors: list[str]) -> dict:
    interfaces = records.get("INTERFACE", {})
    aai = {
        name: [fn for fn in funcs.split(",") if fn]
        for name, funcs in interfaces.items()
        if ("aai" in name.lower() or "vehicle" in name.lower())
    }
    return {
        "probe": "isolated-factorio-2.1-readonly-census",
        "census_pass": not errors,
        "gameplay_behavior_proven": False,
        "remote_interface_names_are_callable_proof": False,
        "vehicle_control_method_signatures_confirmed": False,
        "errors": errors,
        "observed_mods": records.get("MOD", {}),
        "remote_registered_count": records.get("REMOTE", {}).get("registered_count"),
        "all_remote_interface_names": sorted(interfaces),
        "aai_related_remote_interfaces": aai,
        "vehicles_and_ai_units": records.get("VEHICLE", {}),
        "vehicle_counts": records.get("COUNT", {}),
        "turret_prototypes": records.get("TURRET", {}),
        "schema_notes": records.get("SCHEMA", {}),
        "limitations": [
            "No vehicle, Skitarii, bunker, turret, projectile or item created or controlled",
            "Reading remote.interfaces reveals registered names only, not call signatures",
            "No AAI movement, multi-gun fire, remote possession, circuit reach, or combat proven",
            "Test pack contains ephemeral Factorio-2.1 metadata staging for domestic mods",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("native_log", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()
    records = collect(args.native_log.read_text(encoding="utf-8", errors="replace"))
    errors = verdict(records)
    out = summarize(records, errors)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n",
                                encoding="utf-8")
    print("[WAR-READONLY] " + ("PASS" if not errors else "FAIL"))
    print(f"[WAR-READONLY] {len(out['all_remote_interface_names'])} registered interfaces")
    for name, funcs in out["aai_related_remote_interfaces"].items():
        print(f"[WAR-READONLY] AAI interface {name}: {', '.join(funcs)}")
    print(f"[WAR-READONLY] {len(out['vehicles_and_ai_units'])} candidate cars/units")
    for name, value in sorted(out["vehicles_and_ai_units"].items()):
        if (name in ("car", "tank", "spidertron") or name.startswith("kj_40k")):
            print(f"[WAR-READONLY] VEHICLE {name}: {value}")
    for err in errors:
        print("[WAR-READONLY] BLOCKED", err)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
