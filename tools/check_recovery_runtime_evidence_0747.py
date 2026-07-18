#!/usr/bin/env python3
"""Validate complete Tech Priests recovery runtime evidence.

Accepted evidence requires exact source identity, clean new-save and real
0.1.672-upgrade logs, final installation/action diagnostics, a passed recovery
scenario matrix, save/reload coverage, and measured profiler records. This tool
validates evidence supplied by a human Factorio test run; it does not run the
game itself.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import tempfile

SCHEMA = "tech-priests-recovery-runtime-evidence-0747-v1"
REQUIRED_SCENARIOS = (
    "new-save-load",
    "upgrade-0.1.672-load",
    "new-save-reload",
    "upgrade-save-reload",
    "hardener-final-complete",
    "event-owner-order",
    "event-owner-replacement",
    "event-owner-removal-isolated",
    "event-handler-failure-isolated",
    "broker-zero-not-acted",
    "broker-waiting-not-acted",
    "broker-replacement-preserves-cadence",
    "emergency-production-success",
    "emergency-production-partial-rollback",
    "emergency-production-output-custody",
    "order-queue-full-rejection",
    "order-queue-lossless-preemption",
    "order-queue-distinct-targets",
    "order-callback-exactly-once",
    "order-acquisition-production-transition",
    "consecration-claim-cleanup",
    "consecration-refund-custody",
    "consecration-save-load",
    "direct-acquisition-physical-custody",
    "direct-acquisition-return-retry",
    "direct-acquisition-station-craft-transition",
    "machine-logistics-custody",
    "storage-full-custody-return",
    "energy-external-automation",
    "rocket-silo-launch-interruption",
    "artillery-manual-stationary-only",
    "roboport-repair-pack-only",
    "fluid-contamination-rejection",
    "fluid-turret-final-port-connection",
    "combat-interruption-custody",
    "overlapping-station-reservations",
    "canonical-action-movement-status-visual-agreement",
    "ordinary-movement-obstruction",
    "void-movement-short-open",
    "void-movement-obstruction",
    "void-movement-high-count-fairness",
    "broker-high-count-fairness",
    "diagnostics-nondominant",
    "idle-profiler",
    "active-profiler",
    "high-count-profiler",
)
REQUIRED_PROFILES = ("idle", "active", "high-count")
ERROR_PATTERNS = (
    r"Error while running event",
    r"Lua[A-Za-z]*Error",
    r"stack traceback",
    r"attempt to (?:index|call|perform arithmetic)",
    r"failed to load mod",
    r"non-serializable",
    r"handler failure",
    r"service failure",
)
REQUIRED_LOG_MARKERS = (
    "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723",
    "phase=complete",
    "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510",
    "ACTION-CLASSIFIER-0488 BEGIN pure=true",
    "PAIR-DUMP-0468 DIRECT-ACQUISITION-0513",
    "PAIR-DUMP-0468 CONSECRATION-0515",
    "COMMANDLESS-RUNTIME-0720",
)


def read_json(path: pathlib.Path, errors: list[str]) -> dict:
    if not path.is_file():
        errors.append(f"missing evidence manifest: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid evidence JSON {path}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"evidence manifest must be a JSON object: {path}")
        return {}
    return value


def resolve(root: pathlib.Path, value: object, label: str, errors: list[str]) -> pathlib.Path:
    text = str(value or "").strip()
    if not text:
        errors.append(f"missing path for {label}")
        return root / "__missing__"
    path = pathlib.Path(text)
    return path if path.is_absolute() else root / path


def validate_log(path: pathlib.Path, label: str, source_commit: str, errors: list[str]) -> None:
    if not path.is_file():
        errors.append(f"missing {label} log: {path}")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    if source_commit not in text:
        errors.append(f"{label} log does not identify exact source commit {source_commit}")
    for pattern in ERROR_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            errors.append(f"{label} log contains release-blocking pattern: {pattern}")
    for marker in REQUIRED_LOG_MARKERS:
        if marker not in text:
            errors.append(f"{label} log is missing required marker: {marker}")
    if not re.search(r"pairs(?:=| count=)[1-9][0-9]*", text, re.IGNORECASE):
        errors.append(f"{label} log has no positive station/priest pair count")
    if re.search(r"failed=[1-9][0-9]*", text):
        errors.append(f"{label} log reports failed hardener/runtime records")
    if re.search(r"errors=[1-9][0-9]*", text):
        errors.append(f"{label} log reports nonzero runtime errors")


def validate_scenarios(manifest: dict, root: pathlib.Path, source_commit: str, errors: list[str]) -> None:
    scenarios = manifest.get("scenarios")
    if not isinstance(scenarios, dict):
        errors.append("scenarios must be an object keyed by required scenario id")
        return
    for scenario_id in REQUIRED_SCENARIOS:
        record = scenarios.get(scenario_id)
        if not isinstance(record, dict):
            errors.append(f"missing required scenario: {scenario_id}")
            continue
        if record.get("status") != "pass":
            errors.append(f"scenario did not pass: {scenario_id}")
        if record.get("source_commit") != source_commit:
            errors.append(f"scenario source mismatch: {scenario_id}")
        evidence = str(record.get("evidence") or "").strip()
        if not evidence:
            errors.append(f"scenario has no evidence description: {scenario_id}")
        log_path = resolve(root, record.get("log"), f"scenario {scenario_id} log", errors)
        if not log_path.is_file():
            errors.append(f"scenario evidence log does not exist: {scenario_id}: {log_path}")


def validate_profiles(manifest: dict, source_commit: str, errors: list[str]) -> None:
    profiles = manifest.get("profiles")
    if not isinstance(profiles, dict):
        errors.append("profiles must be an object")
        return
    for profile_id in REQUIRED_PROFILES:
        record = profiles.get(profile_id)
        if not isinstance(record, dict):
            errors.append(f"missing required profile: {profile_id}")
            continue
        if record.get("source_commit") != source_commit:
            errors.append(f"profile source mismatch: {profile_id}")
        if int(record.get("samples") or 0) < 30:
            errors.append(f"profile requires at least 30 samples: {profile_id}")
        for key in ("average_ms", "worst_ms"):
            value = record.get(key)
            if not isinstance(value, (int, float)) or value < 0:
                errors.append(f"profile {profile_id} has invalid {key}")
        if int(record.get("pair_count") or 0) < 1:
            errors.append(f"profile {profile_id} has no active pair count")
    high = profiles.get("high-count") if isinstance(profiles, dict) else None
    if isinstance(high, dict) and int(high.get("pair_count") or 0) < 49:
        errors.append("high-count profile must contain at least 49 valid pairs")


def validate(root: pathlib.Path) -> list[str]:
    errors: list[str] = []
    manifest = read_json(root / "recovery-evidence.json", errors)
    if manifest.get("schema") != SCHEMA:
        errors.append(f"evidence schema must be {SCHEMA}")
    source_commit = str(manifest.get("source_commit") or "")
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        errors.append("source_commit must be an exact 40-character lowercase SHA")
    if manifest.get("factorio_version") != "2.0":
        errors.append("factorio_version must be 2.0")
    if manifest.get("new_save_contains_pairs") is not True:
        errors.append("new-save evidence must contain real pairs")
    if manifest.get("upgrade_contains_pairs") is not True:
        errors.append("upgrade evidence must contain real pairs")
    if manifest.get("unedited_logs") is not True:
        errors.append("logs must be declared unedited")
    if manifest.get("static_ups_baseline_passed") is not True:
        errors.append("static UPS baseline must pass for the same source")

    new_log = resolve(root, manifest.get("new_save_log"), "new-save log", errors)
    upgrade_log = resolve(root, manifest.get("upgrade_log"), "upgrade log", errors)
    validate_log(new_log, "new-save", source_commit, errors)
    validate_log(upgrade_log, "upgrade", source_commit, errors)
    validate_scenarios(manifest, root, source_commit, errors)
    validate_profiles(manifest, source_commit, errors)
    return errors


def report(errors: list[str]) -> int:
    if not errors:
        print("Recovery runtime evidence accepted.")
        return 0
    print("Recovery runtime evidence rejected:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


def self_test() -> int:
    source = "a" * 40
    with tempfile.TemporaryDirectory() as temporary:
        root = pathlib.Path(temporary)
        marker_text = "\n".join((
            source,
            "pairs=2",
            "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723 phase=complete failed=0",
            "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510 errors=0",
            "ACTION-CLASSIFIER-0488 BEGIN pure=true",
            "PAIR-DUMP-0468 DIRECT-ACQUISITION-0513",
            "PAIR-DUMP-0468 CONSECRATION-0515",
            "COMMANDLESS-RUNTIME-0720",
        ))
        (root / "new.log").write_text(marker_text, encoding="utf-8")
        (root / "upgrade.log").write_text(marker_text, encoding="utf-8")
        scenarios = {}
        for scenario_id in REQUIRED_SCENARIOS:
            scenarios[scenario_id] = {
                "status": "pass",
                "source_commit": source,
                "evidence": "self-test evidence",
                "log": "new.log",
            }
        profiles = {
            profile_id: {
                "source_commit": source,
                "samples": 30,
                "average_ms": 0.1,
                "worst_ms": 0.2,
                "pair_count": 49 if profile_id == "high-count" else 2,
            }
            for profile_id in REQUIRED_PROFILES
        }
        manifest = {
            "schema": SCHEMA,
            "source_commit": source,
            "factorio_version": "2.0",
            "new_save_contains_pairs": True,
            "upgrade_contains_pairs": True,
            "unedited_logs": True,
            "static_ups_baseline_passed": True,
            "new_save_log": "new.log",
            "upgrade_log": "upgrade.log",
            "scenarios": scenarios,
            "profiles": profiles,
        }
        (root / "recovery-evidence.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        valid_errors = validate(root)
        if valid_errors:
            print("Recovery evidence self-test valid fixture failed:", file=sys.stderr)
            for error in valid_errors:
                print(f"  - {error}", file=sys.stderr)
            return 1
        manifest["scenarios"][REQUIRED_SCENARIOS[0]]["status"] = "fail"
        (root / "recovery-evidence.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        invalid_errors = validate(root)
        if not invalid_errors:
            print("Recovery evidence self-test invalid fixture was accepted.", file=sys.stderr)
            return 1
    print("Recovery runtime evidence validator self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence_root", nargs="?", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    return report(validate(pathlib.Path(args.evidence_root).resolve()))


if __name__ == "__main__":
    raise SystemExit(main())
