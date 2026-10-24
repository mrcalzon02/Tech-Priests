#!/usr/bin/env python3
"""CI-only Factorio save/reload smoke: real server autosave, separate engine reload."""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import signal
import subprocess
import sys
import time
import zipfile

SAVE_NAME = "_autosave-tech-priests-ci-persistence.zip"
PASS_MARKER = "[TP-GROUND-RANK-TEST] PASS SAVE_RELOAD_VERIFIED"
CARGO_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_SAVE_RELOAD"
REQUEST_MARKER = "[TP-GROUND-RANK-TEST] SAVE_RELOAD_REQUESTED"
HARNESS_INSTALL = 'require("scripts.core.ci_ground_rank_harness").install()'


def check_engine_log(content: str, expected: str) -> None:
    if expected not in content:
        raise RuntimeError(f"engine log does not contain {expected!r}")
    for marker in ("[TP-GROUND-RANK-TEST] FAIL ",
                   "[TP-GROUND-RANK-TEST] ERROR ", "stack traceback",
                   "Error while loading", "Failed to load"):
        if marker in content:
            raise RuntimeError(f"engine reported fatal marker {marker!r}")


def verify_cargo_import_boundary() -> None:
    """Regression: the real Factorio engine rejects require() in tick callbacks."""
    harness = (pathlib.Path(__file__).resolve().parents[1] /
               "tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
    source = harness.read_text(encoding="utf-8")
    parse_stage = ('local CARGO_ENGINE_0824=SAVE_RELOAD_SMOKE and '
                   'require("scripts.core.station_cargo_0824") or nil')
    if source.count('require("scripts.core.station_cargo_0824")') != 1:
        raise AssertionError("cargo API must be imported exactly once during control parsing")
    if parse_stage not in source or source.index(parse_stage) > source.index(
            "local function cargo_engine_prepare(state)"):
        raise AssertionError("cargo API must be imported before the runtime fixture")
    if source.count("local Cargo=CARGO_ENGINE_0824") != 2:
        raise AssertionError("both runtime cargo stages must use the parsed module")


def self_test() -> int:
    verify_cargo_import_boundary()
    check_engine_log(REQUEST_MARKER + " tick=1800", REQUEST_MARKER)
    check_engine_log(PASS_MARKER + " tick=2700 pairs=4", PASS_MARKER)
    check_engine_log(CARGO_MARKER + " held=0 net_fixture_delta=0", CARGO_MARKER)
    for bad in ("", "[TP-GROUND-RANK-TEST] FAIL bad", "stack traceback"):
        try:
            check_engine_log(PASS_MARKER + " pairs=4\n" + bad if bad else bad,
                             PASS_MARKER)
        except RuntimeError:
            pass
        else:
            raise AssertionError(f"invalid smoke log accepted: {bad!r}")
    print("save/reload runner self-test PASS")
    return 0


def install_smoke_mod(source_mods: pathlib.Path, dest_mods: pathlib.Path) -> None:
    dest_mods.mkdir(parents=True, exist_ok=True)
    for item in source_mods.iterdir():
        dest = dest_mods / item.name
        if item.is_dir():
            if item.name == "tech-priests":
                shutil.copytree(item, dest)
            else:
                dest.symlink_to(item, target_is_directory=True)
        elif item.name.lower().endswith(".zip"):
            dest.symlink_to(item)
    control = dest_mods / "tech-priests" / "control.lua"
    text = control.read_text(encoding="utf-8")
    if text.count(HARNESS_INSTALL) != 1:
        raise RuntimeError("isolated installation missing one CI harness entrypoint")
    text = text.replace(HARNESS_INSTALL,
                        '_G.TP_CI_SAVE_RELOAD_SMOKE=true\n' + HARNESS_INSTALL)
    control.write_text(text, encoding="utf-8")


def prepare_server_settings(game_root: pathlib.Path, target: pathlib.Path) -> None:
    template = game_root / "data" / "server-settings.example.json"
    data = json.loads(template.read_text(encoding="utf-8"))
    data.update({"name": "Tech Priests isolated CI",
                 "description": "Local-only save/reload check",
                 "visibility": {"public": False, "lan": False},
                 "auto_pause": False, "require_user_verification": False,
                 "autosave_interval": 10, "non_blocking_saving": False})
    target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def wait_for_real_save(process: subprocess.Popen, game_root: pathlib.Path,
                       server_log: pathlib.Path, seconds: float) -> pathlib.Path:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Factorio exited before saving: {process.returncode}")
        # A fatal fixture assertion can stop its tick service while Factorio
        # continues running. Report that root cause immediately, not a
        # misleading six-minute "autosave timeout" with the failure off-tail.
        if server_log.is_file():
            log_now = server_log.read_text(encoding="utf-8", errors="replace")
            for marker in ("[TP-GROUND-RANK-TEST] FAIL ",
                           "[TP-GROUND-RANK-TEST] ERROR ",
                           "Error while running", "stack traceback"):
                for line in log_now.splitlines():
                    if marker in line:
                        raise RuntimeError("Factorio server failed before save: " +
                                           line[-500:])
        for path in sorted(game_root.rglob(SAVE_NAME)):
            if path.stat().st_size < 2048:
                continue
            log = server_log.read_text(encoding="utf-8", errors="replace")
            if REQUEST_MARKER not in log or "Saving finished" not in log:
                continue
            try:
                with zipfile.ZipFile(path) as archive:
                    if archive.testzip() is not None:
                        continue
            except (OSError, zipfile.BadZipFile):
                continue
            check_engine_log(log, REQUEST_MARKER)
            return path
        time.sleep(0.25)
    raise TimeoutError("Factorio server did not write a validated requested autosave")


def execute(args: argparse.Namespace) -> int:
    binary = pathlib.Path(args.binary).resolve()
    game_root = binary.parents[2]
    initial = pathlib.Path(args.initial_save).resolve()
    work = pathlib.Path(args.work_dir).resolve()
    output = pathlib.Path(args.artifact_dir).resolve()
    if not binary.is_file() or not initial.is_file():
        raise FileNotFoundError("Factorio binary or initial save not found")
    work.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    mods = work / "mods"
    install_smoke_mod(pathlib.Path(args.mod_dir).resolve(), mods)
    settings = work / "server-settings.json"
    prepare_server_settings(game_root, settings)
    server_log = work / "factorio-save-server.log"
    cmd = [str(binary), "--mod-directory", str(mods), "--start-server", str(initial),
           "--server-settings", str(settings), "--bind", "127.0.0.1"]
    with server_log.open("w", encoding="utf-8") as handle:
        process = subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT)
        try:
            saved = wait_for_real_save(process, game_root, server_log, args.server_timeout)
            target = output / "tech-priests-ground-ranks-save-checkpoint.zip"
            shutil.copy2(saved, target)
            with zipfile.ZipFile(target) as archive:
                if archive.testzip() is not None:
                    raise RuntimeError("copied autosave failed ZIP CRC")
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=35)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
    reload_log = work / "factorio-reload.log"
    with reload_log.open("w", encoding="utf-8") as handle:
        result = subprocess.run([str(binary), "--mod-directory", str(mods),
                                 "--benchmark", str(target), "--benchmark-ticks", "2400"],
                                stdout=handle, stderr=subprocess.STDOUT,
                                check=False, timeout=args.reload_timeout)
    content = reload_log.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(f"Factorio reload failed: exit status {result.returncode}")
    check_engine_log(content, PASS_MARKER)
    check_engine_log(content, CARGO_MARKER)
    if "held=0 net_fixture_delta=0" not in content:
        raise RuntimeError("engine cargo item was not physically returned and fixture-balanced")
    if "persisted_stations=4 persisted_priests=4" not in content:
        raise RuntimeError("reloaded Cogitator pairs were not preserved")
    print("PASS: real server save, separate-process reload, 4 identities preserved, station cargo conserved")
    print(f"Checkpoint: {target} ({target.stat().st_size} bytes)")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--binary")
    parser.add_argument("--mod-dir")
    parser.add_argument("--initial-save")
    parser.add_argument("--work-dir")
    parser.add_argument("--artifact-dir")
    parser.add_argument("--server-timeout", type=int, default=360)
    parser.add_argument("--reload-timeout", type=int, default=300)
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    for key in ("binary", "mod_dir", "initial_save", "work_dir", "artifact_dir"):
        if not getattr(args, key):
            parser.error(f"--{key.replace('_', '-')} is required")
    try:
        return execute(args)
    except (OSError, RuntimeError, TimeoutError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL save/reload smoke: {exc}", file=sys.stderr)
        if args.work_dir:
            for name in ("factorio-save-server.log", "factorio-reload.log"):
                path = pathlib.Path(args.work_dir) / name
                if path.is_file():
                    print(f"--- tail {name} ---", file=sys.stderr)
                    print("\n".join(path.read_text(encoding="utf-8",
                         errors="replace").splitlines()[-35:]), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
