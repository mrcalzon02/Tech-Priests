#!/usr/bin/env python3
"""Validate complete, file-bound Tech Priests recovery runtime evidence.

Accepted evidence requires exact source identity, cryptographic binding to retained
logs and profiler files, explicit scenario pass markers, clean new-save and real
0.1.672-upgrade logs, save/reload coverage, and measured profiler records. This
tool validates evidence supplied by a Factorio test operator; it does not run the
game itself.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
import tempfile

SCHEMA = "tech-priests-recovery-runtime-evidence-0747-v2"
SCENARIO_MARKER_PREFIX = "TECH-PRIESTS-RECOVERY-SCENARIO"
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
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")


def read_json(path: pathlib.Path, errors: list[str], label: str = "evidence manifest") -> dict:
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON for {label} {path}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{label} must be a JSON object: {path}")
        return {}
    return value


def resolve(root: pathlib.Path, value: object, label: str, errors: list[str]) -> pathlib.Path:
    text = str(value or "").strip()
    if not text:
        errors.append(f"missing path for {label}")
        return root / "__missing__"
    path = pathlib.Path(text)
    return path if path.is_absolute() else root / path


def file_sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_digest(path: pathlib.Path, expected: object, label: str, errors: list[str]) -> None:
    text = str(expected or "").strip()
    if not SHA256_PATTERN.fullmatch(text):
        errors.append(f"{label} must record a lowercase 64-character SHA-256 digest")
        return
    if path.is_file() and file_sha256(path) != text:
        errors.append(f"{label} SHA-256 does not match retained file: {path}")


def contains_errors(text: str, label: str, errors: list[str]) -> None:
    for pattern in ERROR_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            errors.append(f"{label} contains release-blocking pattern: {pattern}")


def validate_log(
    path: pathlib.Path,
    label: str,
    source_commit: str,
    expected_digest: object,
    errors: list[str],
) -> None:
    if not path.is_file():
        errors.append(f"missing {label} log: {path}")
        return
    validate_digest(path, expected_digest, f"{label} log", errors)
    text = path.read_text(encoding="utf-8", errors="replace")
    if source_commit not in text:
        errors.append(f"{label} log does not identify exact source commit {source_commit}")
    contains_errors(text, f"{label} log", errors)
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
    unknown = sorted(set(scenarios) - set(REQUIRED_SCENARIOS))
    if unknown:
        errors.append("unknown scenario ids: " + ", ".join(unknown))
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
        if len(evidence) < 20:
            errors.append(f"scenario evidence description is too short: {scenario_id}")
        log_path = resolve(root, record.get("log"), f"scenario {scenario_id} log", errors)
        if not log_path.is_file():
            errors.append(f"scenario evidence log does not exist: {scenario_id}: {log_path}")
            continue
        validate_digest(log_path, record.get("log_sha256"), f"scenario {scenario_id} log", errors)
        text = log_path.read_text(encoding="utf-8", errors="replace")
        if source_commit not in text:
            errors.append(f"scenario log source mismatch: {scenario_id}")
        marker = f"{SCENARIO_MARKER_PREFIX} {scenario_id} PASS"
        if marker not in text:
            errors.append(f"scenario log is missing exact pass marker: {marker}")
        contains_errors(text, f"scenario {scenario_id} log", errors)


def numeric(record: dict, key: str, profile_id: str, errors: list[str]) -> float | None:
    value = record.get(key)
    if not isinstance(value, (int, float)) or isinstance(value, bool) or value < 0:
        errors.append(f"profile {profile_id} has invalid {key}")
        return None
    return float(value)


def validate_profiles(manifest: dict, root: pathlib.Path, source_commit: str, errors: list[str]) -> None:
    profiles = manifest.get("profiles")
    if not isinstance(profiles, dict):
        errors.append("profiles must be an object")
        return
    if set(profiles) != set(REQUIRED_PROFILES):
        errors.append("profiles must contain exactly idle, active, and high-count")
    for profile_id in REQUIRED_PROFILES:
        record = profiles.get(profile_id)
        if not isinstance(record, dict):
            errors.append(f"missing required profile: {profile_id}")
            continue
        if record.get("source_commit") != source_commit:
            errors.append(f"profile source mismatch: {profile_id}")
        samples = int(record.get("samples") or 0)
        if samples < 30:
            errors.append(f"profile requires at least 30 samples: {profile_id}")
        average = numeric(record, "average_ms", profile_id, errors)
        worst = numeric(record, "worst_ms", profile_id, errors)
        if average is not None and worst is not None and worst < average:
            errors.append(f"profile {profile_id} worst_ms is below average_ms")
        pair_count = int(record.get("pair_count") or 0)
        if pair_count < 1:
            errors.append(f"profile {profile_id} has no active pair count")
        if profile_id == "high-count" and pair_count < 49:
            errors.append("high-count profile must contain at least 49 valid pairs")
        profile_path = resolve(root, record.get("file"), f"profile {profile_id} file", errors)
        if not profile_path.is_file():
            errors.append(f"profile evidence file does not exist: {profile_id}: {profile_path}")
            continue
        validate_digest(profile_path, record.get("file_sha256"), f"profile {profile_id} file", errors)
        file_record = read_json(profile_path, errors, f"profile {profile_id} evidence")
        expected = {
            "profile_id": profile_id,
            "source_commit": source_commit,
            "samples": samples,
            "average_ms": record.get("average_ms"),
            "worst_ms": record.get("worst_ms"),
            "pair_count": pair_count,
        }
        for key, value in expected.items():
            if file_record.get(key) != value:
                errors.append(f"profile {profile_id} file mismatch for {key}")


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
    validate_log(new_log, "new-save", source_commit, manifest.get("new_save_log_sha256"), errors)
    validate_log(upgrade_log, "upgrade", source_commit, manifest.get("upgrade_log_sha256"), errors)
    validate_scenarios(manifest, root, source_commit, errors)
    validate_profiles(manifest, root, source_commit, errors)
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
        marker_lines = [
            source,
            "pairs=2",
            "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723 phase=complete failed=0",
            "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510 errors=0",
            "ACTION-CLASSIFIER-0488 BEGIN pure=true",
            "PAIR-DUMP-0468 DIRECT-ACQUISITION-0513",
            "PAIR-DUMP-0468 CONSECRATION-0515",
            "COMMANDLESS-RUNTIME-0720",
        ]
        marker_lines.extend(f"{SCENARIO_MARKER_PREFIX} {scenario_id} PASS" for scenario_id in REQUIRED_SCENARIOS)
        marker_text = "\n".join(marker_lines) + "\n"
        new_log = root / "new.log"
        upgrade_log = root / "upgrade.log"
        new_log.write_text(marker_text, encoding="utf-8")
        upgrade_log.write_text(marker_text, encoding="utf-8")
        log_digest = file_sha256(new_log)
        scenarios = {
            scenario_id: {
                "status": "pass",
                "source_commit": source,
                "evidence": f"self-test retained evidence for {scenario_id}",
                "log": "new.log",
                "log_sha256": log_digest,
            }
            for scenario_id in REQUIRED_SCENARIOS
        }
        profiles = {}
        for profile_id in REQUIRED_PROFILES:
            record = {
                "profile_id": profile_id,
                "source_commit": source,
                "samples": 30,
                "average_ms": 0.1,
                "worst_ms": 0.2,
                "pair_count": 49 if profile_id == "high-count" else 2,
            }
            path = root / f"{profile_id}.json"
            path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
            profiles[profile_id] = {
                **record,
                "file": path.name,
                "file_sha256": file_sha256(path),
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
            "new_save_log_sha256": log_digest,
            "upgrade_log": "upgrade.log",
            "upgrade_log_sha256": file_sha256(upgrade_log),
            "scenarios": scenarios,
            "profiles": profiles,
        }
        manifest_path = root / "recovery-evidence.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        errors = validate(root)
        if errors:
            raise RuntimeError("valid self-test evidence rejected: " + "; ".join(errors))
        manifest["scenarios"][REQUIRED_SCENARIOS[0]]["log_sha256"] = "0" * 64
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        if not validate(root):
            raise RuntimeError("corrupted scenario digest was incorrectly accepted")
    print("Recovery runtime evidence validator self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    try:
        return self_test() if args.self_test else report(validate(pathlib.Path(args.root).resolve()))
    except RuntimeError as exc:
        print(f"Recovery runtime evidence self-test failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
