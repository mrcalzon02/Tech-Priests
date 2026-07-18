#!/usr/bin/env python3
"""Fail closed unless Tech Priests has explicit verified release authorization.

The authorization file is intentionally absent during recovery. Creating it is
not sufficient by itself: this checker requires exact evidence fields and a
source version beyond the protected 0.1.672 baseline. Runtime evidence remains
external and must be reviewed before the authorization is committed.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

AUTH_PATH = pathlib.Path("docs/releases/VERIFIED_RELEASE_AUTHORIZATION.json")
INFO_PATH = pathlib.Path("tech-priests_src/info.json")
REQUIRED_TRUE = (
    "source_validation_complete",
    "new_save_load_complete",
    "migration_load_complete",
    "save_reload_complete",
    "behavioral_matrix_complete",
    "performance_validation_complete",
    "packaged_load_required",
)


def check(project_root: pathlib.Path) -> int:
    root = project_root.resolve()
    auth_path = root / AUTH_PATH
    info_path = root / INFO_PATH
    errors: list[str] = []
    if not auth_path.is_file():
        errors.append(
            "verified release authorization is absent; recovery Gates 1-5 must "
            "pass before packaging or publication"
        )
        return report(errors)
    try:
        auth = json.loads(auth_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid authorization JSON: {exc}")
        return report(errors)
    try:
        info = json.loads(info_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"cannot read source metadata: {exc}")
        return report(errors)

    if auth.get("schema") != "tech-priests-verified-release-authorization-v1":
        errors.append("authorization schema is missing or unsupported")
    if auth.get("classification") != "verified-release-candidate":
        errors.append("classification must be verified-release-candidate")
    version = str(info.get("version") or "")
    if version == "0.1.672":
        errors.append("protected 0.1.672 development source may not be packaged")
    if auth.get("version") != version:
        errors.append(
            f"authorization version {auth.get('version')!r} does not match "
            f"source version {version!r}"
        )
    source_commit = str(auth.get("source_commit") or "")
    if len(source_commit) != 40:
        errors.append("authorization must record the exact 40-character source commit")
    for key in REQUIRED_TRUE:
        if auth.get(key) is not True:
            errors.append(f"authorization evidence field must be true: {key}")
    required_records = (
        "source_validation_run",
        "new_save_evidence",
        "migration_evidence",
        "behavioral_evidence",
        "performance_evidence",
    )
    for key in required_records:
        if not str(auth.get(key) or "").strip():
            errors.append(f"authorization must identify evidence record: {key}")
    return report(errors)


def report(errors: list[str]) -> int:
    if not errors:
        print("Verified release authorization passed.")
        return 0
    print("Verified release authorization failed:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args(argv)
    return check(pathlib.Path(args.project_root))


if __name__ == "__main__":
    raise SystemExit(main())
