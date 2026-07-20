#!/usr/bin/env python3
"""Validate Stage 5 bound-evidence and release-authorization wiring."""
from __future__ import annotations

import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATHS = {
    "index": ROOT / "docs/README.md",
    "runbook": ROOT / "docs/RECOVERY_RUNTIME_EVIDENCE.md",
    "validator": ROOT / "tools/check_recovery_runtime_evidence_0747.py",
    "generator": ROOT / "tools/create_recovery_evidence_template_0748.py",
    "validator_workflow": ROOT / ".github/workflows/recovery-runtime-evidence-self-test.yml",
    "generator_workflow": ROOT / ".github/workflows/recovery-evidence-template-self-test.yml",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "release_checker": ROOT / "tools/check_release_authorization_0745.py",
    "release_example": ROOT / "docs/releases/VERIFIED_RELEASE_AUTHORIZATION.example.json",
    "testing": ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
}


def read(name: str, errors: list[str]) -> str:
    path = PATHS[name]
    if not path.is_file():
        errors.append(f"missing required Stage 5 file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def load_module(path: pathlib.Path, name: str, errors: list[str]):
    if not path.is_file():
        return None
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        errors.append(f"cannot load module: {path.relative_to(ROOT)}")
        return None
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"cannot import {path.relative_to(ROOT)}: {exc}")
        return None
    return module


def check() -> int:
    errors: list[str] = []
    text = {name: read(name, errors) for name in PATHS}
    required = {
        "index": [
            "RECOVERY_RUNTIME_EVIDENCE.md",
            "check_recovery_runtime_evidence_0747.py",
            "create_recovery_evidence_template_0748.py",
            "check_release_authorization_0745.py",
        ],
        "runbook": [
            "tech-priests-recovery-runtime-evidence-0747-v2",
            "TECH-PRIESTS-RECOVERY-SCENARIO",
            "new_save_log_sha256",
            "log_sha256",
            "file_sha256",
            "python3 tools/check_recovery_runtime_evidence_0747.py --self-test",
            "python3 tools/check_recovery_runtime_evidence_0747.py",
            "VERIFIED_RELEASE_AUTHORIZATION",
        ],
        "validator": [
            'SCHEMA = "tech-priests-recovery-runtime-evidence-0747-v2"',
            'SCENARIO_MARKER_PREFIX = "TECH-PRIESTS-RECOVERY-SCENARIO"',
            "REQUIRED_SCENARIOS",
            "REQUIRED_PROFILES",
            "log_sha256",
            "file_sha256",
            "def self_test()",
            "corrupted scenario digest was incorrectly accepted",
            "malformed profiler integer was not cleanly rejected",
            "Recovery runtime evidence accepted.",
        ],
        "generator": [
            "validator.REQUIRED_SCENARIOS",
            "validator.REQUIRED_PROFILES",
            '"status": "pending"',
            '"log_sha256": ""',
            '"file_sha256": ""',
            "This file is not evidence",
        ],
        "validator_workflow": [
            "check_recovery_runtime_evidence_0747.py --self-test",
            "python3 -m py_compile",
        ],
        "generator_workflow": [
            "create_recovery_evidence_template_0748.py",
            "--self-test",
        ],
        "source_workflow": [
            "Self-test complete recovery evidence validator",
            "Self-test recovery evidence template generator",
            "Audit recovery evidence wiring",
            "Self-test bound release authorization",
            "Prove verified release remains blocked",
        ],
        "release_checker": [
            'SCHEMA = "tech-priests-verified-release-authorization-v2"',
            "source_validation_complete",
            "new_save_load_complete",
            "migration_load_complete",
            "save_reload_complete",
            "behavioral_matrix_complete",
            "performance_validation_complete",
            "recovery_evidence",
            "manifest_sha256",
            "validator.validate(evidence_root)",
            "reviewed_by",
            "reviewed_utc",
            "def self_test()",
            "corrupted evidence manifest digest was accepted",
        ],
        "testing": [
            "Stage 5 objective validation",
            "tech-priests-recovery-runtime-evidence-0747-v2",
            "## Gate 6 — Profiler evidence",
            "## Release boundary",
            "TECH-PRIESTS-RECOVERY-SCENARIO",
        ],
    }
    for name, fragments in required.items():
        for fragment in fragments:
            if fragment not in text[name]:
                errors.append(f"{PATHS[name].relative_to(ROOT)} missing wiring: {fragment}")

    try:
        example = json.loads(text["release_example"])
    except json.JSONDecodeError as exc:
        errors.append(f"release authorization example is invalid JSON: {exc}")
        example = {}
    if example.get("schema") != "tech-priests-verified-release-authorization-v2":
        errors.append("release authorization example schema is not v2")
    if example.get("source_validation_complete") is not False:
        errors.append("release example must remain non-authorizing")
    if example.get("classification") != "verified-release-candidate":
        errors.append("release example classification is inconsistent")
    if not isinstance(example.get("source_validation"), dict):
        errors.append("release example lacks structured source_validation")
    if not isinstance(example.get("recovery_evidence"), dict):
        errors.append("release example lacks structured recovery_evidence")

    validator = load_module(PATHS["validator"], "recovery_validator_0747", errors)
    if validator is not None:
        if validator.SCHEMA not in text["runbook"]:
            errors.append("runbook schema differs from validator")
        if len(tuple(validator.REQUIRED_SCENARIOS)) < 40:
            errors.append("complete recovery matrix unexpectedly lost scenarios")
        if tuple(validator.REQUIRED_PROFILES) != ("idle", "active", "high-count"):
            errors.append("recovery profile contract changed unexpectedly")
        if not getattr(validator, "SCENARIO_MARKER_PREFIX", ""):
            errors.append("recovery validator lost scenario marker contract")

    release_checker = load_module(
        PATHS["release_checker"], "release_authorization_0745", errors
    )
    if release_checker is not None:
        if release_checker.SCHEMA != "tech-priests-verified-release-authorization-v2":
            errors.append("release checker schema differs from v2 example")
        if release_checker.BASELINE_VERSION != "0.1.672":
            errors.append("release checker protected baseline changed unexpectedly")

    if (ROOT / "docs/releases/VERIFIED_RELEASE_AUTHORIZATION.json").exists():
        errors.append("actual verified release authorization must remain absent during protected recovery")

    if errors:
        print("Recovery evidence wiring audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("Recovery evidence and release authorization wiring audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(check())
