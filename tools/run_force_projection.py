#!/usr/bin/env python3
"""Isolated, seed-recorded multi-force endurance world; never a victory test."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import secrets
import shutil
import subprocess
import time
import zipfile

from run_factorio_isolated_service_scenario import (
    ROOT, factorio_runtime_compatible, free_loopback_udp_port,
    private_robot_server_settings, run,
)

PRESETS = ("2p2b", "1v4-bugs", "2v2", "3v1", "4v4-priests")
TAG = "[TP-FORCE-PROJECTION] "


def parse_process_observations(create_log: str, server_log: str,
                               preset: str, seed: int, ticks: int) -> dict:
    if (create_log.count(TAG + "CONFIG ") != 1 or TAG + "CONFIG " in server_log
            or TAG + "READY " in create_log or TAG + "COMPLETE " in create_log):
        raise ValueError("Arena initialization/server process evidence misplaced")
    return parse_observations(create_log + "\n" + server_log, preset, seed, ticks)


def parse_observations(log: str, preset: str, seed: int, ticks: int) -> dict:
    """Reject incomplete/mismatched telemetry, without requiring AI success."""
    events: dict[str, list[dict]] = {}
    for line in log.splitlines():
        if TAG not in line:
            continue
        kind, _, payload = line.split(TAG, 1)[1].partition(" ")
        events.setdefault(kind, []).append(json.loads(payload))
    if events.get("FAIL"):
        raise ValueError("Native fixture failed: " + str(events["FAIL"]))
    for name in ("CONFIG", "READY", "COMPLETE"):
        if len(events.get(name, [])) != 1:
            raise ValueError("Missing or duplicate native " + name)
    config, ready, end = (events[x][0] for x in ("CONFIG", "READY", "COMPLETE"))
    roster = config["participants"]
    expected = 8 if preset == "4v4-priests" else 5 if preset == "1v4-bugs" else 4
    if (config["preset"] != preset or config["seed"] != seed
            or config["active_ticks"] != ticks or len(roster) != expected
            or len({p["force"] for p in roster}) != expected
            or end["preset"] != preset or end["seed"] != seed
            or ready["participants"] != expected or end["participants"] != expected
            or end["elapsed"] != ticks or end["tick"] - ready["tick"] != ticks):
        raise ValueError("Native seed, roster, duration or chronology mismatch")
    supplies = {x["force"]: x for x in events.get("SUPPLY", [])}
    priests = {x["force"] for x in roster if x["kind"] == "p"}
    if set(supplies) != priests or len(events.get("SUPPLY", [])) != len(priests):
        raise ValueError("Original priest supply manifests missing/duplicated")
    for stock in supplies.values():
        if (not stock["stock"] or stock["refills"] != 0 or
                len({x["slot"] for x in stock["stock"]}) != len(stock["stock"]) or
                any(x["count"] <= 0 for x in stock["stock"])):
            raise ValueError("Invalid actual initial inventory manifest")
    cells = (config["side"] // 256) ** 2
    deposits = events.get("DEPOSIT", [])
    required = {"iron-ore", "copper-ore", "coal", "stone", "crude-oil", "water"}
    seen: set[tuple[int, str]] = set()
    for d in deposits:
        key = (d["cell"], d["name"])
        if key in seen or d["entities_or_tiles"] <= 0:
            raise ValueError("Duplicate or empty resource deposit")
        seen.add(key)
    if seen != {(i, name) for i in range(cells) for name in required}:
        raise ValueError("Predefined resource field incomplete")
    latest = {x["force"]: x for x in events.get("SAMPLE", [])}
    if set(latest) != {x["force"] for x in roster} or any(
            x["elapsed"] != ticks for x in latest.values()):
        raise ValueError("Missing exact final native force observations")
    return {"observation_complete": True, "preset": preset, "seed": seed,
            "active_ticks": ticks, "setup_ticks": ready["tick"],
            "forces": latest, "contacts": events.get("CONTACT", []),
            "supply_manifests": supplies, "resource_deposits": len(deposits),
            "combat_observed": bool(events.get("CONTACT")),
            "expansion_success_not_assumed": True,
            "native_script_ms_per_tick": None,
            "timing_note": "Wall UPS includes setup/telemetry/save costs; script time unmeasured"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--factorio", required=True, type=pathlib.Path)
    ap.add_argument("--preset", choices=PRESETS, default="2p2b")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--active-ticks", type=int, default=216000)
    ap.add_argument("--timeout-seconds", type=int, default=7200)
    ap.add_argument("--dependency-mods", type=pathlib.Path)
    ap.add_argument("--output-dir", type=pathlib.Path,
                    default=ROOT / "test-artifacts" / "force-projection")
    args = ap.parse_args()
    seed = args.seed if args.seed is not None else secrets.randbelow(2**31)
    if not 0 <= seed < 2**31 or not 3600 <= args.active_ticks <= 864000:
        ap.error("Seed must fit uint31; duration must be 1 minute to 4 hours")
    if not args.factorio.is_file() or args.timeout_seconds < 60:
        ap.error("A real local Factorio executable and timeout >=60s are required")
    version = subprocess.run([str(args.factorio), "--version"],
                             capture_output=True, text=True, check=False)
    engine = (version.stdout or version.stderr).strip()
    if version.returncode or not factorio_runtime_compatible(engine, "2.1"):
        ap.error("Native Factorio 2.1 required: " + engine)
    # Fail closed on repeated output paths; never delete prior evidence/saves.
    output = args.output_dir.resolve() / f"{args.preset}-{seed}"
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    result = {"schema": "tech-priests.force-projection.v1", "seed": seed,
              "preset": args.preset, "observation_complete": False,
              "engine_version": engine, "active_ticks": args.active_ticks}
    try:
        source_sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        result["source_sha"] = source_sha
        mods = output / "mods"; mods.mkdir()
        shutil.copytree(ROOT / "tech-priests_src", mods / "tech-priests")
        if args.dependency_mods:
            for p in args.dependency_mods.iterdir():
                if p.name.startswith("tech-priests") or p.name == "base":
                    continue
                if p.is_file() and p.suffix == ".zip":
                    shutil.copy2(p, mods / p.name)
                elif p.is_dir() and (p / "info.json").is_file():
                    shutil.copytree(p, mods / p.name)
        fixture = ROOT / "tests/scenarios/force-projection/fixture.lua"
        result["fixture_sha256"] = hashlib.sha256(fixture.read_bytes()).hexdigest()
        shutil.copy2(fixture, mods / "tech-priests/scripts/core/ci_force_projection.lua")
        control = mods / "tech-priests/control.lua"
        config = json.dumps({"seed": seed, "preset": args.preset,
                             "active_ticks": args.active_ticks})
        # table_from_json is called while control.lua loads, where helpers is
        # available; no game/storage mutation is performed outside on_init.
        control.write_text("_G.TP_FORCE_PROJECTION_CONFIG=helpers.json_to_table(" +
                           json.dumps(config) + ")\n" + control.read_text(encoding="utf-8") +
                           '\nrequire("scripts.core.ci_force_projection").install()\n',
                           encoding="utf-8")
        width = 3072 if args.preset in ("1v4-bugs", "4v4-priests") else 2048
        settings = output / "map-gen-settings.json"
        settings.write_text(json.dumps({"seed": seed, "width": width,
            "height": width, "water": "none", "peaceful_mode": False,
            "cliff_settings": {"cliff_elevation_interval": 0},
            # Disabling individual noise ratios with literal zeros causes
            # Factorio 2.1 coal spotNoise division by zero during --create.
            # Disable entity autoplace as a category instead. All resources,
            # trees and enemies in this fixture are explicitly authored.
            "autoplace_settings": {"entity": {
                "treat_missing_as_default": False, "settings": {}}}}), encoding="utf-8")
        runtime = output / "runtime"; runtime.mkdir()
        ini = output / "config.ini"
        ini.write_text("[path]\nread-data=__PATH__executable__/../../data\nwrite-data=" +
                       runtime.as_posix() + "\n", encoding="utf-8")
        save = output / "arena-initial.zip"
        common = [str(args.factorio), "--config", str(ini), "--mod-directory", str(mods)]
        code = run(common + ["--create", str(save), "--map-gen-settings", str(settings)],
                   output / "create.log", min(args.timeout_seconds, 600))
        result["create_exit"] = code
        if code:
            raise RuntimeError("Native save creation failed; see create.log")
        server_settings = private_robot_server_settings(output)
        log_path = output / "native-server.log"
        terminal_save = runtime / "saves" / f"tp-arena-{args.preset}-{seed}-final.zip"
        reason = "timeout"; actual_exit = None; native_started = time.monotonic()
        observed = ""; offset = 0
        with log_path.open("w", encoding="utf-8") as log_output:
            process = subprocess.Popen(common + ["--start-server", str(save),
                "--server-settings", str(server_settings), "--bind", "127.0.0.1",
                "--port", str(free_loopback_udp_port())], stdin=subprocess.DEVNULL,
                stdout=log_output, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + args.timeout_seconds
                while time.monotonic() < deadline:
                    with log_path.open(encoding="utf-8", errors="replace") as reader:
                        reader.seek(offset); fresh = reader.read(); offset = reader.tell()
                    observed += fresh
                    for line in fresh.splitlines():
                        if any(TAG + kind + " " in line for kind in
                               ("READY", "SAMPLE", "CONTACT", "FAIL", "COMPLETE")):
                            print(line, flush=True)
                    if TAG + "FAIL " in observed:
                        reason = "fixture_failure"; break
                    if TAG + "COMPLETE " in observed and terminal_save.is_file():
                        try:
                            with zipfile.ZipFile(terminal_save) as archive:
                                if archive.testzip() is None:
                                    reason = "complete_with_verified_save"; break
                        except (OSError, zipfile.BadZipFile):
                            pass  # Engine may still be finishing the save.
                    if process.poll() is not None:
                        reason = "unexpected_engine_exit"; break
                    time.sleep(1)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try: process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        process.kill(); process.wait(timeout=15)
                actual_exit = process.returncode
        result.update(engine_exit=actual_exit, driver_stop_reason=reason,
                      native_wall_seconds=round(time.monotonic()-native_started, 3))
        observed = log_path.read_text(encoding="utf-8", errors="replace")
        if reason != "complete_with_verified_save":
            raise RuntimeError("Native endurance incomplete: " + reason)
        # CONFIG is emitted by native on_init during --create; READY and
        # later observations belong to the independently loaded server.
        initial_log=(output / "create.log").read_text(encoding="utf-8", errors="replace")
        result.update(parse_process_observations(initial_log, observed,
                                                 args.preset, seed, args.active_ticks))
        result["checkpoint_save"] = str(terminal_save)
        result["save_sha256"] = hashlib.sha256(terminal_save.read_bytes()).hexdigest()
        result["observed_ups_including_setup"] = round(
            (result["setup_ticks"]+args.active_ticks)/result["native_wall_seconds"], 3)
    except Exception as error:
        result["blocker"] = str(error)
        print("ARENA_BLOCKER " + str(error), flush=True)
        for name in ("create.log", "native-server.log"):
            p = output / name
            if p.is_file():
                for line in p.read_text(encoding="utf-8", errors="replace").splitlines()[-20:]:
                    print("ARENA_ENGINE_TAIL " + line[-1200:], flush=True)
    finally:
        result["total_wall_seconds"] = round(time.monotonic()-started, 3)
        (output / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True),
                                           encoding="utf-8")
        print("ARENA_RESULT " + json.dumps(result, sort_keys=True), flush=True)
    return 0 if result["observation_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
