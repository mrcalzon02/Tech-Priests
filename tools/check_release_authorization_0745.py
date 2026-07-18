#!/usr/bin/env python3
"""Fail closed unless Tech Priests has verified release-candidate authorization.

Authorization v2 revalidates the complete bound runtime-evidence directory at
packaging time. The authorization file is intentionally absent during recovery.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import pathlib
import re
import shutil
import sys
import tempfile
from typing import Any

AUTH_PATH = pathlib.Path("docs/releases/VERIFIED_RELEASE_AUTHORIZATION.json")
INFO_PATH = pathlib.Path("tech-priests_src/info.json")
VALIDATOR_PATH = pathlib.Path("tools/check_recovery_runtime_evidence_0747.py")
BASELINE_VERSION = "0.1.672"
SCHEMA = "tech-priests-verified-release-authorization-v2"
CLASSIFICATION = "verified-release-candidate"
SOURCE_RE = re.compile(r"[0-9a-f]{40}")
SHA256_RE = re.compile(r"[0-9a-f]{64}")
VERSION_RE = re.compile(r"\d+\.\d+\.\d+")
UTC_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z")
RUN_URL_RE = re.compile(
    r"https://github\.com/mrcalzon02/Tech-Priests/actions/runs/[0-9]+"
)
REQUIRED_TRUE = (
    "source_validation_complete",
    "new_save_load_complete",
    "migration_load_complete",
    "save_reload_complete",
    "behavioral_matrix_complete",
    "performance_validation_complete",
    "packaged_load_required",
)


def read_object(path: pathlib.Path, label: str, errors: list[str]) -> dict[str, Any]:
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"invalid {label} JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{label} must be a JSON object")
        return {}
    return value


def version_tuple(value: str) -> tuple[int, int, int] | None:
    if not VERSION_RE.fullmatch(value):
        return None
    return tuple(int(part) for part in value.split("."))  # type: ignore[return-value]


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve(root: pathlib.Path, value: object, label: str, errors: list[str]) -> pathlib.Path:
    text = str(value or "").strip()
    if not text:
        errors.append(f"authorization must identify {label}")
        return root / "__missing__"
    path = pathlib.Path(text)
    return path if path.is_absolute() else root / path


def load_validator(root: pathlib.Path, errors: list[str]):
    path = root / VALIDATOR_PATH
    if not path.is_file():
        errors.append(f"runtime evidence validator is missing: {path}")
        return None
    spec = importlib.util.spec_from_file_location("recovery_validator_0747_release", path)
    if spec is None or spec.loader is None:
        errors.append("cannot load runtime evidence validator")
        return None
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"cannot import runtime evidence validator: {exc}")
        return None
    return module


def validate(project_root: pathlib.Path) -> list[str]:
    root = project_root.resolve()
    errors: list[str] = []
    auth = read_object(root / AUTH_PATH, "verified release authorization", errors)
    info = read_object(root / INFO_PATH, "source metadata", errors)
    if not auth or not info:
        return errors

    if auth.get("schema") != SCHEMA:
        errors.append(f"authorization schema must be {SCHEMA}")
    if auth.get("classification") != CLASSIFICATION:
        errors.append(f"classification must be {CLASSIFICATION}")

    source_version = str(info.get("version") or "")
    auth_version = str(auth.get("version") or "")
    parsed_source = version_tuple(source_version)
    parsed_baseline = version_tuple(BASELINE_VERSION)
    if parsed_source is None:
        errors.append(f"source version is not numeric x.y.z: {source_version!r}")
    elif parsed_baseline is not None and parsed_source <= parsed_baseline:
        errors.append(
            f"source version must be greater than protected baseline {BASELINE_VERSION}"
        )
    if auth_version != source_version:
        errors.append(
            f"authorization version {auth_version!r} does not match "
            f"source version {source_version!r}"
        )

    source_commit = str(auth.get("source_commit") or "")
    if not SOURCE_RE.fullmatch(source_commit):
        errors.append("authorization must record an exact lowercase 40-character source SHA")

    for key in REQUIRED_TRUE:
        if auth.get(key) is not True:
            errors.append(f"authorization evidence field must be true: {key}")

    source_validation = auth.get("source_validation")
    if not isinstance(source_validation, dict):
        errors.append("authorization source_validation must be an object")
    else:
        if source_validation.get("status") != "success":
            errors.append("source_validation status must be success")
        if source_validation.get("source_commit") != source_commit:
            errors.append("source_validation source_commit mismatch")
        if source_validation.get("workflow") != "source-validation.yml":
            errors.append("source_validation workflow must be source-validation.yml")
        run_url = str(source_validation.get("run_url") or "")
        if not RUN_URL_RE.fullmatch(run_url):
            errors.append("source_validation run_url is missing or not a repository Actions run")

    reviewer = str(auth.get("reviewed_by") or "").strip()
    if len(reviewer) < 2:
        errors.append("authorization must identify reviewed_by")
    reviewed_utc = str(auth.get("reviewed_utc") or "")
    if not UTC_RE.fullmatch(reviewed_utc):
        errors.append("authorization reviewed_utc must be an ISO-8601 UTC timestamp ending Z")

    evidence = auth.get("recovery_evidence")
    if not isinstance(evidence, dict):
        errors.append("authorization recovery_evidence must be an object")
        return errors
    if evidence.get("source_commit") != source_commit:
        errors.append("recovery_evidence source_commit mismatch")
    evidence_root = resolve(root, evidence.get("root"), "recovery evidence root", errors)
    manifest_name = str(evidence.get("manifest") or "recovery-evidence.json")
    manifest_path = evidence_root / manifest_name
    if not evidence_root.is_dir():
        errors.append(f"recovery evidence root does not exist: {evidence_root}")
        return errors
    if not manifest_path.is_file():
        errors.append(f"recovery evidence manifest does not exist: {manifest_path}")
        return errors
    expected_digest = str(evidence.get("manifest_sha256") or "")
    if not SHA256_RE.fullmatch(expected_digest):
        errors.append("recovery evidence manifest_sha256 must be lowercase SHA-256")
    elif sha256(manifest_path) != expected_digest:
        errors.append("recovery evidence manifest digest mismatch")

    manifest = read_object(manifest_path, "recovery evidence manifest", errors)
    if manifest.get("source_commit") != source_commit:
        errors.append("recovery evidence manifest source_commit mismatch")

    validator = load_validator(root, errors)
    if validator is not None:
        if manifest.get("schema") != validator.SCHEMA:
            errors.append("recovery evidence manifest schema differs from validator")
        try:
            evidence_errors = validator.validate(evidence_root)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"runtime evidence validator raised an exception: {exc}")
        else:
            errors.extend(
                f"runtime evidence rejected: {error}" for error in evidence_errors
            )
    return errors


def report(errors: list[str]) -> int:
    if not errors:
        print("Verified release authorization passed.")
        return 0
    print("Verified release authorization failed:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


def self_test() -> int:
    source_commit = "a" * 40
    source_validator = pathlib.Path(__file__).with_name(
        "check_recovery_runtime_evidence_0747.py"
    )
    spec = importlib.util.spec_from_file_location(
        "recovery_validator_0747_self_test", source_validator
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load source recovery validator for self-test")
    validator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator)

    with tempfile.TemporaryDirectory() as temporary:
        root = pathlib.Path(temporary)
        (root / "tools").mkdir(parents=True)
        (root / "docs/releases").mkdir(parents=True)
        (root / "tech-priests_src").mkdir(parents=True)
        shutil.copy2(source_validator, root / VALIDATOR_PATH)

        evidence_root = root / "evidence"
        evidence_root.mkdir()
        manifest_path = validator._write_fixture(evidence_root, source_commit)
        manifest_digest = sha256(manifest_path)
        (root / INFO_PATH).write_text(
            json.dumps({"name": "tech-priests", "version": "0.1.674"}, indent=2) + "\n",
            encoding="utf-8",
        )
        auth = {
            "schema": SCHEMA,
            "classification": CLASSIFICATION,
            "version": "0.1.674",
            "source_commit": source_commit,
            **{key: True for key in REQUIRED_TRUE},
            "source_validation": {
                "status": "success",
                "source_commit": source_commit,
                "workflow": "source-validation.yml",
                "run_url": "https://github.com/mrcalzon02/Tech-Priests/actions/runs/1",
            },
            "recovery_evidence": {
                "root": "evidence",
                "manifest": "recovery-evidence.json",
                "manifest_sha256": manifest_digest,
                "source_commit": source_commit,
            },
            "reviewed_by": "self-test",
            "reviewed_utc": "2026-07-18T00:00:00Z",
        }
        auth_path = root / AUTH_PATH
        auth_path.write_text(json.dumps(auth, indent=2) + "\n", encoding="utf-8")
        errors = validate(root)
        if errors:
            raise RuntimeError("valid authorization fixture rejected: " + "; ".join(errors))

        auth["recovery_evidence"]["manifest_sha256"] = "0" * 64
        auth_path.write_text(json.dumps(auth, indent=2) + "\n", encoding="utf-8")
        bad = validate(root)
        if not any("manifest digest mismatch" in error for error in bad):
            raise RuntimeError("corrupted evidence manifest digest was accepted")
    print("Verified release authorization self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    try:
        return self_test() if args.self_test else report(validate(pathlib.Path(args.project_root)))
    except RuntimeError as exc:
        print(f"Verified release authorization self-test failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
