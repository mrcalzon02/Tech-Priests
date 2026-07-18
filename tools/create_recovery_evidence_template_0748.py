#!/usr/bin/env python3
"""Create a complete Tech Priests recovery-evidence manifest skeleton.

The generated file is not evidence and every scenario begins as pending. It
imports the validator's canonical scenario/profile identifiers so the operator
cannot accidentally omit or misspell a required record.
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
            "log": "",
        }
        for scenario_id in validator.REQUIRED_SCENARIOS
    }
    profiles = {
        profile_id: {
            "source_commit": source_commit,
            "samples": 0,
            "average_ms": 0.0,
            "worst_ms": 0.0,
            "pair_count": 0,
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
        "upgrade_log": "upgrade-factorio-current.log",
        "scenarios": scenarios,
        "profiles": profiles,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_commit")
    parser.add_argument("--output", default="recovery-evidence.json")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    source = "a" * 40 if args.self_test else args.source_commit
    output = pathlib.Path(args.output)
    if output.exists() and not args.overwrite:
        raise RuntimeError(f"output already exists: {output}; pass --overwrite")
    manifest = build(source)
    if args.self_test:
        validator = load_validator()
        if tuple(manifest["scenarios"]) != tuple(validator.REQUIRED_SCENARIOS):
            raise RuntimeError("scenario template order differs from validator")
        if tuple(manifest["profiles"]) != tuple(validator.REQUIRED_PROFILES):
            raise RuntimeError("profile template order differs from validator")
        print("Recovery evidence template generator self-test passed.")
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Created pending recovery evidence template: {output}")
    print("This file is not evidence until every required record is completed from real Factorio runs.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
