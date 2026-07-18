#!/usr/bin/env python3
"""Create a complete, pending Tech Priests recovery-evidence v2 skeleton.

The generated files are not evidence. Every scenario begins pending, every digest
is empty, and every profiler record requires a separate retained JSON file.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "tools/check_recovery_runtime_evidence_0747.py"


def load_validator():
    spec = importlib.util.spec_from_file_location("recovery_validator_0747", VALIDATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load validator: {VALIDATOR}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build(source_commit: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise RuntimeError("source commit must be a 40-character lowercase SHA")
    validator = load_validator()
    scenarios = {
        scenario_id: {
            "status": "pending",
            "source_commit": source_commit,
            "evidence": "",
            "log": f"scenarios/{scenario_id}.log",
            "log_sha256": "",
        }
        for scenario_id in validator.REQUIRED_SCENARIOS
    }
    profiles = {
        profile_id: {
            "profile_id": profile_id,
            "source_commit": source_commit,
            "samples": 0,
            "average_ms": 0.0,
            "worst_ms": 0.0,
            "pair_count": 0,
            "file": f"profiles/{profile_id}.json",
            "file_sha256": "",
        }
        for profile_id in validator.REQUIRED_PROFILES
    }
    return {
        "schema": validator.SCHEMA,
        "source_commit": source_commit,
        "factorio_version": "2.0",
        "new_save_contains_pairs": False,
        "upgrade_contains_pairs": False,
        "unedited_logs": True,
        "static_ups_baseline_passed": False,
        "new_save_log": "new-save-factorio-current.log",
        "new_save_log_sha256": "",
        "upgrade_log": "upgrade-factorio-current.log",
        "upgrade_log_sha256": "",
        "scenarios": scenarios,
        "profiles": profiles,
    }


def write_pending_profile_files(output: pathlib.Path, manifest: dict, overwrite: bool) -> None:
    root = output.parent
    for profile_id, record in manifest["profiles"].items():
        path = root / record["file"]
        if path.exists() and not overwrite:
            raise RuntimeError(f"profile template already exists: {path}; pass --overwrite")
        path.parent.mkdir(parents=True, exist_ok=True)
        pending = {
            "profile_id": profile_id,
            "source_commit": record["source_commit"],
            "samples": 0,
            "average_ms": 0.0,
            "worst_ms": 0.0,
            "pair_count": 0,
        }
        path.write_text(json.dumps(pending, indent=2) + "\n", encoding="utf-8")
    (root / "scenarios").mkdir(parents=True, exist_ok=True)


def self_test() -> int:
    validator = load_validator()
    manifest = build("a" * 40)
    if manifest["schema"] != validator.SCHEMA:
        raise RuntimeError("template schema differs from validator")
    if tuple(manifest["scenarios"]) != tuple(validator.REQUIRED_SCENARIOS):
        raise RuntimeError("scenario template order differs from validator")
    if tuple(manifest["profiles"]) != tuple(validator.REQUIRED_PROFILES):
        raise RuntimeError("profile template order differs from validator")
    if any(record["status"] != "pending" or record["log_sha256"] for record in manifest["scenarios"].values()):
        raise RuntimeError("scenario templates are not safely pending")
    if any(record["file_sha256"] for record in manifest["profiles"].values()):
        raise RuntimeError("profile templates unexpectedly contain evidence digests")
    print("Recovery evidence template generator self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_commit")
    parser.add_argument("--output", default="recovery-evidence.json")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    output = pathlib.Path(args.output)
    if output.exists() and not args.overwrite:
        raise RuntimeError(f"output already exists: {output}; pass --overwrite")
    manifest = build(args.source_commit)
    output.parent.mkdir(parents=True, exist_ok=True)
    write_pending_profile_files(output, manifest, args.overwrite)
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Created pending recovery evidence template: {output}")
    print("This file is not evidence until every record and retained-file digest comes from real Factorio runs.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
