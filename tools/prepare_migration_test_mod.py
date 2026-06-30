#!/usr/bin/env python3
"""Create an unpackaged migration-test copy of the Tech Priests mod.

The authoritative source metadata remains at the packaged 0.1.672 baseline until
all release gates pass. Factorio only emits a real mod-version configuration
change when the loaded version changes, so this tool copies the source into a
separate development directory and rewrites only the copied info.json to 0.1.673
by default. It never creates a ZIP and the output is marked test-only.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import shutil
import sys
from typing import Any

SOURCE_DIR = "tech-priests_src"
DEFAULT_TEST_VERSION = "0.1.673"
BASELINE_VERSION = "0.1.672"
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
MARKER_NAME = "MIGRATION_TEST_ONLY.json"
RUNTIME_CHECKER = "tools/check_migration_runtime_evidence_0737.py"
RUNTIME_RUNBOOK = "docs/MIGRATION_RUNTIME_VALIDATION.md"
REQUIRED_SCENARIOS = ["new-save", "upgrade-0.1.672"]


def parse_version(value: str) -> tuple[int, int, int]:
    if not VERSION_RE.fullmatch(value):
        raise ValueError(f"Factorio mod version must be numeric x.y.z, got {value!r}")
    return tuple(int(part) for part in value.split("."))  # type: ignore[return-value]


def resolve_source(project_root: pathlib.Path) -> pathlib.Path:
    root = project_root.resolve()
    candidate = root / SOURCE_DIR
    if (candidate / "info.json").is_file():
        return candidate
    if (root / "info.json").is_file():
        return root
    raise FileNotFoundError(f"could not locate {SOURCE_DIR}/info.json below {root}")


def read_json(path: pathlib.Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return value


def write_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def copy_ignore(_: str, names: list[str]) -> set[str]:
    ignored = {name for name in names if name in {"__pycache__", ".DS_Store"}}
    ignored.update(name for name in names if name.endswith((".pyc", ".pyo", ".zip")))
    return ignored


def build_test_copy(
    project_root: pathlib.Path,
    output_root: pathlib.Path,
    test_version: str,
    source_ref: str | None,
    overwrite: bool,
) -> pathlib.Path:
    source = resolve_source(project_root)
    source_info_path = source / "info.json"
    source_info = read_json(source_info_path)
    source_version = str(source_info.get("version", ""))
    mod_name = str(source_info.get("name", ""))

    if source_version != BASELINE_VERSION:
        raise ValueError(
            f"authoritative source must remain at baseline {BASELINE_VERSION}; "
            f"found {source_version!r}"
        )
    if not mod_name:
        raise ValueError("source info.json has no mod name")
    if parse_version(test_version) <= parse_version(source_version):
        raise ValueError(
            f"test version {test_version} must be greater than source {source_version}"
        )

    destination_root = output_root.resolve()
    destination = destination_root / f"{mod_name}_{test_version}"
    if destination == source or source in destination.parents:
        raise ValueError("migration-test output may not be created inside authoritative source")

    if destination.exists():
        if not overwrite:
            raise FileExistsError(
                f"migration-test output already exists: {destination}; use --overwrite"
            )
        shutil.rmtree(destination)
    destination_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination, ignore=copy_ignore)

    copied_info_path = destination / "info.json"
    copied_info = read_json(copied_info_path)
    copied_info["version"] = test_version
    description = str(copied_info.get("description", "")).strip()
    warning = "MIGRATION TEST ONLY - NOT A RELEASE."
    copied_info["description"] = f"{warning} {description}".strip()
    write_json(copied_info_path, copied_info)

    manifest = {
        "test_only": True,
        "packaging_allowed": False,
        "source_directory": str(source),
        "source_version": source_version,
        "test_version": test_version,
        "source_ref": source_ref or "unrecorded",
        "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "validation_contract": {
            "schema": "tech-priests-migration-runtime-evidence-0737-v1",
            "checker": RUNTIME_CHECKER,
            "runbook": RUNTIME_RUNBOOK,
            "required_scenarios": REQUIRED_SCENARIOS,
            "required_log": "factorio-current.log",
            "result_pattern": "migration-runtime-<scenario>.json",
            "requires_unedited_log": True,
            "requires_same_source_ref": True,
        },
        "instructions": [
            "Install this unpackaged directory only for migration testing.",
            "Run both the new-save and upgrade-0.1.672 scenarios from the runtime validation runbook.",
            "Load only a disposable copy of an existing 0.1.672 save for the upgrade scenario.",
            "Capture a separate unedited factorio-current.log for each scenario.",
            "Validate both logs with tools/check_migration_runtime_evidence_0737.py.",
            "Do not upload, publish, zip, or treat this directory as a release.",
            "Delete the directory after migration evidence is captured.",
        ],
    }
    write_json(destination / MARKER_NAME, manifest)

    # Prove the authoritative source was not modified by the copy rewrite.
    unchanged = read_json(source_info_path)
    if str(unchanged.get("version", "")) != source_version:
        raise RuntimeError("authoritative source info.json changed during test-copy creation")

    return destination


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument(
        "--output-root",
        default="build/migration-test",
        help="Parent directory for the unpackaged test mod",
    )
    parser.add_argument("--version", default=DEFAULT_TEST_VERSION)
    parser.add_argument("--source-ref", default=None)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        destination = build_test_copy(
            pathlib.Path(args.project_root),
            pathlib.Path(args.output_root),
            args.version,
            args.source_ref,
            args.overwrite,
        )
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Migration-test mod created: {destination}")
    print(f"Marker: {destination / MARKER_NAME}")
    print("Required runtime scenarios: " + ", ".join(REQUIRED_SCENARIOS))
    print(f"Runtime evidence checker: {RUNTIME_CHECKER}")
    print("No ZIP was created; authoritative source remains at 0.1.672.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
