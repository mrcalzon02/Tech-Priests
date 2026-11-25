#!/usr/bin/env python3
"""Exercise the published-package unit hotfix in real Factorio player mode.

An untouched 1.0.0 distribution creates the upgrade save. The exact candidate
archive then loads that save. Only disposable installations receive the fixture.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "[TP-UNIT-BEHAVIOR] "
PINS = {"aai-programmable-vehicles": "0.9.2", "aai-signals": "0.8.0", "informatron": "0.5.0"}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def install(archive, folder, dependencies):
    folder.mkdir(parents=True)
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        roots = {name.split("/", 1)[0] for name in names}
        if len(roots) != 1 or any(PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts for name in names):
            raise ValueError("Unsafe package paths")
        bundle.extractall(folder)
    mod = folder / roots.pop()
    info = json.loads((mod / "info.json").read_text())
    if info["name"] != "tech-priests":
        raise ValueError("Unexpected mod package")
    for name, version in PINS.items():
        source = dependencies / f"{name}_{version}.zip"
        if not source.is_file():
            raise ValueError("Missing verified dependency " + source.name)
        shutil.copy2(source, folder / source.name)
    (folder / "mod-list.json").write_text(json.dumps({"mods": [
        {"name": name, "enabled": True} for name in ["base", *PINS, "tech-priests"]
    ]}) + "\n")
    shutil.copy2(ROOT / "tests/scenarios/unit-behavior/fixture.lua", mod / "scripts/core/ci_unit_behavior.lua")
    with (mod / "control.lua").open("a") as control:
        control.write('\n-- Isolated verification only; not distributed.\nrequire("scripts.core.ci_unit_behavior").install()\n')
    return mod


def execute(command, logfile):
    with logfile.open("w") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=480)
    content = logfile.read_text(errors="replace")
    markers = [line for line in content.splitlines() if PREFIX in line or "Error" in line or "isolated handler failure" in line]
    for line in markers[-45:]:
        print(line[:1600], flush=True)
    if result.returncode != 0:
        print("\n".join(content.splitlines()[-18:]), flush=True)
        raise RuntimeError(f"Factorio {logfile.name} failed with exit {result.returncode}")
    if PREFIX + "FAIL" in content or "Error while running" in content or "isolated handler failure" in content:
        raise RuntimeError("Native runtime reported a failed event: " + logfile.name)
    return content


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", type=Path, required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--base-package", type=Path, default=Path("base-package/tech-priests_1.0.0.zip"))
    parser.add_argument("--dependency-mods", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    engine = args.factorio.resolve()
    receipt = {"schema": "tech-priests.unit-behavior-native.v1", "passed": False,
               "package_sha256": digest(args.package), "source_commit": os.environ.get("GITHUB_SHA", ""),
               "actual_engine": subprocess.check_output([str(engine), "--version"], text=True).splitlines()[0]}
    try:
        if "2.1.24" not in receipt["actual_engine"]:
            raise ValueError("Expected pinned Factorio 2.1.24")
        old_mods, new_mods = output / "baseline/mods", output / "candidate/mods"
        install(args.base_package, old_mods, args.dependency_mods)
        install(args.package, new_mods, args.dependency_mods)
        write_path = output / "engine-write"
        write_path.mkdir()
        config = output / "config.ini"
        config.write_text("[path]\nread-data=__PATH__executable__/../../data\nwrite-data=" + str(write_path) + "\n")
        settings = output / "map-gen-settings.json"
        settings.write_text(json.dumps({"seed": 2601125, "width": 128, "height": 128,
                                       "peaceful_mode": True, "default_enable_all_autoplace_controls": False}))
        save = output / "upgrade-from-1.0.0.zip"
        base = [str(engine), "--config", str(config)]
        created = execute(base + ["--mod-directory", str(old_mods), "--create", str(save),
                                  "--map-gen-settings", str(settings)], output / "baseline-create.log")
        if PREFIX + "LEGACY_SAVE_SEEDED" not in created:
            raise RuntimeError("Original 1.0.0 did not create the legacy affected unit")
        loaded = execute(base + ["--mod-directory", str(new_mods), "--test-save", str(save),
                                 "--test-ticks", "600"], output / "native-upgrade-pickup.log")
        marker = PREFIX + "PASS "
        lines = [line.split(marker, 1)[1] for line in loaded.splitlines() if marker in line]
        if len(lines) != 1:
            raise RuntimeError("Exactly one complete native acceptance receipt required")
        evidence = json.loads(lines[0])
        if evidence.get("combat_types") != 15 or evidence.get("prototype_forms_mined") != 45 or evidence.get("managed_units_picked_up") != 15 or evidence.get("worker_cells_redeployed") != 4 or not evidence.get("legacy_migration"):
            raise RuntimeError("Native evidence does not cover the requested behavior")
        receipt.update(evidence)
        receipt["passed"] = True
    except Exception as error:
        receipt["error"] = str(error)
    finally:
        (output / "unit-behavior-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
        print("TP_UNIT_BEHAVIOR_RECEIPT " + json.dumps(receipt, sort_keys=True), flush=True)
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
