#!/usr/bin/env python3
"""Validate Factorio runtime evidence for Tech Priests migration gates.

The checker consumes an unedited factorio-current.log produced by the unpackaged
0.1.673 migration-test copy. It verifies installation, lifecycle, broker, and
pair-integrity diagnostics without mutating the mod or treating the test copy as
a release.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Any

SCENARIOS = ("new-save", "upgrade-0.1.672")

FATAL_PATTERNS = {
    "failed-to-load-mods": re.compile(r"Failed to load mods", re.IGNORECASE),
    "runtime-event-error": re.compile(r"Error while running event", re.IGNORECASE),
    "lua-error": re.compile(r"\bLuaError\b", re.IGNORECASE),
    "lua-traceback": re.compile(r"stack traceback:", re.IGNORECASE),
    "control-load-error": re.compile(r"Error loading control\.lua", re.IGNORECASE),
}

STARTUP_PATTERNS = {
    "hardener-install-summary": re.compile(
        r"planning constraints hardener installation attempted=(?P<attempted>\d+) "
        r"passed=(?P<passed>\d+) failed=(?P<failed>\d+) "
        r"complete=(?P<complete>true|false)"
    ),
    "migration-audit-armed": re.compile(
        r"migration pair integrity audit armed diagnostics=(?P<diagnostics>true|false) "
        r"broker=(?P<broker>true|false).*mutations=(?P<mutations>\d+)"
    ),
    "lifecycle-checkpoint-armed": re.compile(
        r"development lifecycle checkpoint armed init=(?P<init>true|false) "
        r"configuration=(?P<configuration>true|false) "
        r"diagnostics=(?P<diagnostics>true|false) broker=(?P<broker>true|false)"
    ),
    "broker-audit-armed": re.compile(
        r"broker registry integrity audit armed diagnostics=(?P<diagnostics>true|false) "
        r"broker=(?P<broker>true|false)"
    ),
    "migration-assertion-armed": re.compile(
        r"migration lifecycle assertion armed lifecycle=(?P<lifecycle>true|false) "
        r"broker=(?P<broker>true|false) mutations=(?P<mutations>\d+) "
        r"timing_authorities=(?P<timing_authorities>\d+)"
    ),
}

DIAGNOSTIC_MARKERS = {
    "hardener": "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723",
    "lifecycle": "PAIR-DUMP-0468 DEVELOPMENT-LIFECYCLE-0733",
    "migration": "PAIR-DUMP-0468 MIGRATION-PAIR-INTEGRITY-0734",
    "broker": "PAIR-DUMP-0468 BROKER-REGISTRY-0725",
}

KEY_VALUE_RE = re.compile(r"(?P<key>[A-Za-z0-9_-]+)=(?P<value>[^\s]+)")


@dataclass(frozen=True)
class ValidationResult:
    scenario: str
    passed: bool
    errors: list[str]
    startup: dict[str, dict[str, str]]
    diagnostics: dict[str, dict[str, str]]
    evidence_lines: dict[str, str]


def parse_key_values(line: str) -> dict[str, str]:
    return {
        match.group("key"): match.group("value")
        for match in KEY_VALUE_RE.finditer(line)
    }


def last_matching_line(lines: list[str], marker: str) -> str | None:
    for line in reversed(lines):
        if marker in line:
            return line
    return None


def expect_value(
    values: dict[str, str],
    key: str,
    expected: str,
    label: str,
    errors: list[str],
) -> None:
    actual = values.get(key)
    if actual != expected:
        errors.append(f"{label}: expected {key}={expected}, found {actual!r}")


def validate_text(text: str, scenario: str) -> ValidationResult:
    if scenario not in SCENARIOS:
        raise ValueError(f"unknown scenario {scenario!r}")

    lines = text.splitlines()
    errors: list[str] = []
    startup: dict[str, dict[str, str]] = {}
    diagnostics: dict[str, dict[str, str]] = {}
    evidence_lines: dict[str, str] = {}

    for label, pattern in FATAL_PATTERNS.items():
        match = pattern.search(text)
        if match:
            line_number = text[: match.start()].count("\n") + 1
            errors.append(f"fatal log signature {label} at line {line_number}")

    for label, pattern in STARTUP_PATTERNS.items():
        matches = list(pattern.finditer(text))
        if not matches:
            errors.append(f"missing startup evidence: {label}")
            continue
        match = matches[-1]
        startup[label] = match.groupdict()
        line_start = text.rfind("\n", 0, match.start()) + 1
        line_end = text.find("\n", match.end())
        if line_end < 0:
            line_end = len(text)
        evidence_lines[label] = text[line_start:line_end]

    summary = startup.get("hardener-install-summary", {})
    if summary:
        attempted = int(summary.get("attempted", "0"))
        passed = int(summary.get("passed", "0"))
        failed = int(summary.get("failed", "-1"))
        if attempted < 1:
            errors.append("hardener-install-summary: attempted must be greater than zero")
        if attempted != passed:
            errors.append(
                f"hardener-install-summary: attempted={attempted} does not equal passed={passed}"
            )
        if failed != 0:
            errors.append(f"hardener-install-summary: failed={failed}, expected 0")
        expect_value(summary, "complete", "true", "hardener-install-summary", errors)

    for label, required in {
        "migration-audit-armed": {
            "diagnostics": "true",
            "broker": "true",
            "mutations": "0",
        },
        "lifecycle-checkpoint-armed": {
            "init": "true",
            "configuration": "true",
            "diagnostics": "true",
            "broker": "true",
        },
        "broker-audit-armed": {"diagnostics": "true", "broker": "true"},
        "migration-assertion-armed": {
            "lifecycle": "true",
            "broker": "true",
            "mutations": "0",
            "timing_authorities": "0",
        },
    }.items():
        values = startup.get(label)
        if not values:
            continue
        for key, expected in required.items():
            expect_value(values, key, expected, label, errors)

    for label, marker in DIAGNOSTIC_MARKERS.items():
        line = last_matching_line(lines, marker)
        if line is None:
            errors.append(f"missing automatic diagnostic evidence: {marker}")
            continue
        diagnostics[label] = parse_key_values(line)
        evidence_lines[label] = line

    hardener = diagnostics.get("hardener", {})
    if hardener:
        for key, expected in {
            "complete": "true",
            "failed": "0",
        }.items():
            expect_value(hardener, key, expected, "hardener diagnostic", errors)
        attempted = int(hardener.get("attempted", "0"))
        passed = int(hardener.get("passed", "-1"))
        if attempted < 1 or attempted != passed:
            errors.append(
                "hardener diagnostic: attempted and passed must be equal and greater than zero"
            )

    lifecycle = diagnostics.get("lifecycle", {})
    if lifecycle:
        for key, expected in {
            "complete": "true",
            "install_complete": "true",
            "install_failed": "0",
            "registry_complete": "true",
            "hardener_passed": "true",
            "broker_passed": "true",
            "planner_passed": "true",
            "integration_passed": "true",
            "commandless_passed": "true",
            "on_load_writes": "0",
        }.items():
            expect_value(lifecycle, key, expected, "lifecycle diagnostic", errors)

        if scenario == "new-save":
            expect_value(lifecycle, "last_reason", "on-init", "new-save lifecycle", errors)
            expect_value(lifecycle, "old_version", "none", "new-save lifecycle", errors)
            expect_value(lifecycle, "new_version", "none", "new-save lifecycle", errors)
        else:
            expect_value(
                lifecycle,
                "last_reason",
                "configuration-changed",
                "upgrade lifecycle",
                errors,
            )
            expect_value(
                lifecycle,
                "old_version",
                "0.1.672",
                "upgrade lifecycle",
                errors,
            )
            expect_value(
                lifecycle,
                "new_version",
                "0.1.673",
                "upgrade lifecycle",
                errors,
            )

    migration = diagnostics.get("migration", {})
    if migration:
        for key, expected in {
            "enabled": "true",
            "read_only": "true",
            "complete": "true",
            "invalid_pairs": "0",
            "issues": "0",
            "mutations": "0",
        }.items():
            expect_value(migration, key, expected, "migration diagnostic", errors)
        entries = int(migration.get("entries", "0"))
        stations = int(migration.get("stations", "0"))
        priests = int(migration.get("priests", "0"))
        valid_pairs = int(migration.get("valid_pairs", "0"))
        if entries < 1:
            errors.append(
                "migration diagnostic: at least one valid station/priest pair is required"
            )
        if entries != valid_pairs or entries != stations or entries != priests:
            errors.append(
                "migration diagnostic: entries, valid_pairs, stations, and priests must agree "
                f"({entries}, {valid_pairs}, {stations}, {priests})"
            )

    broker = diagnostics.get("broker", {})
    if broker:
        for key, expected in {
            "enabled": "true",
            "broker_available": "true",
            "complete": "true",
            "missing": "0",
            "duplicates": "0",
            "malformed": "0",
        }.items():
            expect_value(broker, key, expected, "broker diagnostic", errors)
        total = int(broker.get("total_services", "0"))
        critical = int(broker.get("critical_expected", "0"))
        if total < critical or critical < 1:
            errors.append(
                f"broker diagnostic: total_services={total} must cover critical_expected={critical}"
            )

    return ValidationResult(
        scenario=scenario,
        passed=not errors,
        errors=errors,
        startup=startup,
        diagnostics=diagnostics,
        evidence_lines=evidence_lines,
    )


def result_document(
    result: ValidationResult,
    log_path: pathlib.Path,
    log_bytes: bytes,
    source_ref: str | None,
) -> dict[str, Any]:
    return {
        "schema": "tech-priests-migration-runtime-evidence-0737-v1",
        "scenario": result.scenario,
        "passed": result.passed,
        "source_ref": source_ref or "unrecorded",
        "checked_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "log_path": str(log_path),
        "log_sha256": hashlib.sha256(log_bytes).hexdigest(),
        "errors": result.errors,
        "startup": result.startup,
        "diagnostics": result.diagnostics,
        "evidence_lines": result.evidence_lines,
    }


def write_json(path: pathlib.Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(document, handle, indent=2, ensure_ascii=False, sort_keys=True)
        handle.write("\n")


def synthetic_log(scenario: str, *, fail: bool = False) -> str:
    reason = "on-init" if scenario == "new-save" else "configuration-changed"
    old_version = "none" if scenario == "new-save" else "0.1.672"
    new_version = "none" if scenario == "new-save" else "0.1.673"
    issue_count = "1" if fail else "0"
    complete = "false" if fail else "true"
    return "\n".join(
        [
            "[Tech-Priests 0.1.672] planning constraints hardener installation attempted=54 passed=54 failed=0 complete=true",
            "[Tech-Priests 0.1.674-dev] migration pair integrity audit armed diagnostics=true broker=true control_storage_writes=0 mutations=0",
            "[Tech-Priests 0.1.674-dev] development lifecycle checkpoint armed init=true configuration=true diagnostics=true broker=true on_load_writes=0",
            "[Tech-Priests 0.1.674-dev] broker registry integrity audit armed diagnostics=true broker=true control_storage_writes=0",
            "[Tech-Priests 0.1.674-dev] migration lifecycle assertion armed lifecycle=true broker=true mutations=0 timing_authorities=0",
            "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723 enabled=true available=true complete=true attempted=54 passed=54 failed=0",
            "PAIR-DUMP-0468 DEVELOPMENT-LIFECYCLE-0733 enabled=true source_revision=0.1.674-dev-lifecycle-0733-b+migration-0735 checkpoints=1 "
            f"last_reason={reason} complete=true install_complete=true install_failed=0 registry_complete=true init_handlers=1 configuration_handlers=1 "
            "hardener_passed=true broker_passed=true planner_passed=true integration_passed=true commandless_passed=true "
            f"old_version={old_version} new_version={new_version} on_load_writes=0",
            "PAIR-DUMP-0468 MIGRATION-PAIR-INTEGRITY-0734 enabled=true read_only=true "
            f"complete={complete} entries=2 valid_pairs=2 invalid_pairs=0 stations=2 priests=2 issues={issue_count} mutations=0",
            "PAIR-DUMP-0468 BROKER-REGISTRY-0725 enabled=true broker_available=true complete=true total_services=22 critical_expected=18 missing=0 duplicates=0 malformed=0",
        ]
    )


def run_self_test() -> int:
    failures: list[str] = []
    for scenario in SCENARIOS:
        result = validate_text(synthetic_log(scenario), scenario)
        if not result.passed:
            failures.append(f"expected passing {scenario}: {result.errors}")
    rejected = validate_text(synthetic_log("upgrade-0.1.672", fail=True), "upgrade-0.1.672")
    if rejected.passed:
        failures.append("expected failing migration evidence to be rejected")
    empty_log = synthetic_log("new-save").replace(
        "entries=2 valid_pairs=2 invalid_pairs=0 stations=2 priests=2",
        "entries=0 valid_pairs=0 invalid_pairs=0 stations=0 priests=0",
    )
    empty = validate_text(empty_log, "new-save")
    if empty.passed:
        failures.append("expected zero-pair migration evidence to be rejected")
    if failures:
        print("Migration runtime evidence checker self-test failed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print("Migration runtime evidence checker self-test passed.")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", nargs="?", help="Path to an unedited factorio-current.log")
    parser.add_argument("--scenario", choices=SCENARIOS)
    parser.add_argument("--source-ref", default=None)
    parser.add_argument("--json-output", default=None)
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.self_test:
        return run_self_test()
    if not args.log or not args.scenario:
        print("ERROR: log and --scenario are required unless --self-test is used", file=sys.stderr)
        return 2

    log_path = pathlib.Path(args.log).resolve()
    try:
        log_bytes = log_path.read_bytes()
        text = log_bytes.decode("utf-8", errors="replace")
        result = validate_text(text, args.scenario)
        document = result_document(result, log_path, log_bytes, args.source_ref)
        if args.json_output:
            write_json(pathlib.Path(args.json_output), document)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print(
        f"Migration runtime evidence scenario={result.scenario} "
        f"passed={str(result.passed).lower()} errors={len(result.errors)}"
    )
    if result.passed:
        print("Migration runtime evidence accepted.")
        return 0
    print("Migration runtime evidence rejected:", file=sys.stderr)
    for error in result.errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
