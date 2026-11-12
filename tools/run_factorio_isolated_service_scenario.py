#!/usr/bin/env python3
"""Run exactly one independent Tech-Priests Factorio engine scenario.

Never modifies the live mod folder, gameplay saves, or the shared 108k
endurance harness. Requires a locally installed headless Factorio executable
and any external required dependency mods already acquired by the user.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
CASES = {
    "midgame-science": {
        "fixture": "tests/scenarios/midgame-science/fixture.lua",
        "module": "ci_midgame_science_1194",
        "prefix": "[TP-MIDGAME-SCIENCE]",
        "pass": "PASS fixture, authentic research observations and nine engine checkpoints audited",
        "ticks": 216300,
    },
    "consecration-maintenance": {
        "fixture": "tests/scenarios/consecration-maintenance/fixture.lua",
        "module": "ci_consecration_maintenance",
        "prefix": "[TP-CONSECRATION-TEST]",
        "pass": "PASS active machine consecration and repair from real stocked items ranks=4",
        "ticks": 27000,
    },
    "remote-robot-acquisition": {
        "fixture": "tests/scenarios/remote-robot-acquisition/fixture.lua",
        "module": "ci_remote_robot_acquisition",
        "prefix": "[TP-AUTONOMOUS-ROBOT-1380]",
        "pass": "PASS autonomous original 0259 selected and physical native robot-built Intermediate paired",
        "ticks": 30060,
    },
    "condenser-v22c-physical": {
        "fixture": "tests/scenarios/condenser-v22c-physical/fixture.lua",
        "module": "ci_condenser_v22c_physical",
        "prefix": "[TP-CONDENSER-V22C-PHYSICAL]",
        "pass": "PASS four original 2x2 V22C condensers with native direction-rotated output pipes",
        "ticks": 720,
    },
    "remote-rail-acquisition": {
        "fixture": "tests/scenarios/remote-rail-acquisition/fixture.lua",
        "module": "ci_remote_rail_acquisition",
        "prefix": "[TP-REMOTE-RAIL-TEST]",
        "pass": "PASS planetary Magos built rail, rode train, mined and returned real ore",
        "ticks": 93000,
    },
}


def verify_autonomous_robot_1380_process_logs(
        create_exit: int, create_log: str,
        benchmark_exit: int, benchmark_log: str) -> dict[str, object]:
    """Verify real --create/on_init stock and later native robot receipts.

    A station physically mined during --create is persisted in the save and
    cannot emit that on_init receipt again during --benchmark. Require real
    source provenance on CREATE, production strategy and robot/0338 receipts
    on BENCHMARK; preserve every original inventory/identity assertion.
    """
    tag = "[TP-AUTONOMOUS-ROBOT-1380] "
    source = tag + "NATIVE_PHYSICAL_SOURCE "
    future = (tag + "PASS AUTONOMOUS_0259_SELECTED ",
              tag + "NATIVE_ROBOT_EVENT ",
              tag + "PASS autonomous original 0259 selected and physical ")
    if create_exit != 0 or benchmark_exit != 0:
        raise ValueError("1380 Factorio create or benchmark process failed")
    if create_log.count(source) != 1 or source in benchmark_log:
        raise ValueError("1380 missing/duplicate native create/on_init physical source")
    if any(marker in create_log for marker in future):
        raise ValueError("1380 robot/goal receipt appeared before loaded benchmark")
    if tag + "FAIL " in create_log:
        raise ValueError("1380 refused initial physical site")
    return verify_autonomous_robot_1380_log(
        benchmark_exit, create_log + "\n" + benchmark_log)


def verify_autonomous_robot_1380_log(exit_code: int, log: str) -> dict[str, object]:
    """Reject source/ghost-only credit; require ONE ordered native robot receipt.

    This checks the engine fixture's original Magos/Senior identities, actual
    physically mined station stock, autonomous 0259 selection, and an original
    0338 robot event/paired Intermediate with the same native robot/entity IDs.
    It does not credit ore delivery, script profile or save/reload.
    """
    prefix = r"\[TP-AUTONOMOUS-ROBOT-1380\] "
    def one(expression: str, label: str) -> re.Match[str]:
        found = list(re.finditer(prefix + expression, log))
        if len(found) != 1:
            raise ValueError(f"1380 missing/duplicate {label}: {len(found)}")
        return found[0]

    if exit_code != 0 or "[TP-AUTONOMOUS-ROBOT-1380] FAIL " in log:
        raise ValueError("1380 Factorio process failed or native fixture refused")

    source = one(
        r"NATIVE_PHYSICAL_SOURCE tick=(\d+) seed=(\d+) magos=(\d+) "
        r"senior=(\d+) provider=(\d+) original_source=(\d+) "
        r"item=1 robots_docked=3 natural_ore_unit=(nil|\d+) "
        r"ore_amount=([\d.]+) generated=true chart_forced=false",
        "physical mined source")
    selected = one(
        r"PASS AUTONOMOUS_0259_SELECTED tick=(\d+) original_magos=(\d+) "
        r"original_senior=(\d+) ore=(nil|\d+) original_station_stock=1 "
        r"real_power=true charted=true real_robots=true",
        "autonomous production goal")
    event = one(
        r"NATIVE_ROBOT_EVENT tick=(\d+) station=(\d+) robot=(\d+) "
        r"event=on_robot_built_entity",
        "Factorio native robot event")
    finished = one(
        r"PASS autonomous original 0259 selected and physical native "
        r"robot-built Intermediate paired tick=(\d+) magos=(\d+) "
        r"magos_priest=(\d+) senior=(\d+) senior_priest=(\d+) "
        r"intermediate=(\d+) intermediate_priest=(\d+) native_robot=(\d+) "
        r"material_delta=1 source_stock=0 ghost=0 ore_return_not_credited=true",
        "paired Intermediate and exact material debit")

    if not (int(source[1]) <= int(selected[1]) <= int(event[1])
            <= int(finished[1])):
        raise ValueError("1380 unordered native material/goal/robot/receipt")
    if not (source[3] == selected[2] == finished[2]
            and source[4] == selected[3] == finished[4]
            and source[7] == selected[4]
            and event[2] == finished[6] and event[3] == finished[8]):
        raise ValueError("1380 original identities or event/receipt mismatch")
    if len({finished[2], finished[4], finished[6]}) != 3:
        raise ValueError("1380 duplicate ranked station entity")
    if len({finished[3], finished[5], finished[7]}) != 3:
        raise ValueError("1380 duplicate original/new priest identity")
    return {
        "native_factorio_exit": exit_code,
        "accepted": True,
        "native_0259_selection_tick": int(selected[1]),
        "native_robot_event_tick": int(event[1]),
        "native_paired_station_tick": int(finished[1]),
        "magos_station": int(finished[2]),
        "magos_priest": int(finished[3]),
        "original_senior_station": int(finished[4]),
        "original_senior_priest": int(finished[5]),
        "paired_intermediate_station": int(finished[6]),
        "paired_intermediate_priest": int(finished[7]),
        "native_construction_robot": int(finished[8]),
        "original_stock_debit": 1,
        "natural_ore_return_accepted": False,
        "ore_items_delivered_per_1000_ticks": None,
        "first_delivery_latency_ticks": None,
        "all_mod_script_mean_ms_per_tick": None,
        "all_mod_script_p95_ms_per_tick": None,
        "inventory_discrepancies_in_verified_station_transaction": 0,
        "other_inventory_or_reloaded_cargo_reconciliation": "not exercised",
    }


def verify_condenser_v22c_physical_log(exit_code: int, log: str) -> dict[str, object]:
    """Four actual native Factorio machine/pipe connections, never fake credits."""
    prefix = "[TP-CONDENSER-V22C-PHYSICAL] "
    final = prefix + "PASS four original 2x2 V22C condensers with native direction-rotated output pipes"
    if exit_code != 0 or prefix + "FAIL " in log:
        raise ValueError("Native engine exited unsuccessfully or emitted physical-port FAIL")
    if log.count(final) != 1:
        raise ValueError("Missing or duplicated four-direction native pass")
    pattern = (r"\[TP-CONDENSER-V22C-PHYSICAL\] NATIVE_CONNECTED facing="
               r"(north|east|south|west) machine=(\d+) pipe=(\d+) "
               r"source_x=(-?[\d.]+) source_y=(-?[\d.]+) "
               r"target_x=(-?[\d.]+) target_y=(-?[\d.]+) segment=(\d+)")
    records = re.findall(pattern, log)
    if len(records) != 4 or log.count(prefix + "NATIVE_CONNECTED facing=") != 4:
        raise ValueError("Not exactly four authentic native pipe connection receipts")
    expected = {"north": (0, 0), "east": (18, 0),
                "south": (0, 18), "west": (18, 18)}
    ids, segments, positions = set(), set(), set()
    observed = {}
    for facing, machine, pipe, sx, sy, tx, ty, segment in records:
        if facing in observed:
            raise ValueError("Duplicated native heading " + facing)
        cx, cy = expected[facing]
        sx, sy, tx, ty = map(float, (sx, sy, tx, ty))
        if abs(cx-sx)>0.001 or abs(cy-sy)>0.001:
            raise ValueError("Wrong original test machine center " + facing)
        if facing == "north": outward = tx > cx + 0.75
        elif facing == "east": outward = ty > cy + 0.75
        elif facing == "south": outward = tx < cx - 0.75
        else: outward = ty < cy - 0.75
        if not outward:
            raise ValueError("Native output port did not rotate outward " + facing)
        if int(machine) == 0 or int(pipe) == 0 or int(segment) == 0:
            raise ValueError("Missing unique native entity/segment identity")
        ids.update((int(machine),int(pipe)))
        segments.add(int(segment))
        positions.add((round(tx,3),round(ty,3)))
        observed[facing] = {"machine":int(machine),"pipe":int(pipe),
                            "target":[tx,ty],"segment":int(segment)}
    if set(observed) != set(expected) or len(ids) != 8 or len(positions) != 4:
        raise ValueError("Four cardinal placements or eight distinct entities absent")
    if len(segments) != 4:
        raise ValueError("Independent machine fluid segments unexpectedly merged")
    return {"accepted":True,"native_engine_exit":exit_code,
            "directions":observed,"real_entities":len(ids),"fluid_segments":len(segments)}


def run(argv: list[str], log_file: pathlib.Path, timeout: int) -> int:
    with log_file.open("w", encoding="utf-8") as output:
        try:
            completed = subprocess.run(argv, stdout=output,
                                       stderr=subprocess.STDOUT,
                                       timeout=timeout, check=False)
            return completed.returncode
        except subprocess.TimeoutExpired:
            # Preserve native engine checkpoint files and the live benchmark
            # log. A timeout is FAILURE, but must still yield diagnostic data.
            output.write(f"\nSCENARIO_EXECUTION_TIMEOUT after {timeout} seconds\n")
            return 124



def run_rail_live_server(argv: list[str], log_file: pathlib.Path,
                         timeout: int, poll_interval: float = 1.0,
                         client_argv: list[str] | None = None,
                         client_log_file: pathlib.Path | None = None
                         ) -> tuple[int, str]:
    """Run real headless simulation, stopping only at an observed native gate.

    Factorio --benchmark can leave chart requests queued while game ticks
    advance. A normal private headless server runs the real map/chart update
    lifecycle. Its process is intentionally stopped after a native PASS/FAIL,
    so keep its *actual* exit code separate from the driver stop reason.
    """
    prefix = "[TP-REMOTE-RAIL-TEST] "
    connected = prefix + "PASS two distinct 0338-debited native-connected rails"
    observed = ""
    offset = 0
    deadline = time.monotonic() + timeout
    reason = "timeout"
    if client_argv is not None and client_log_file is None:
        raise ValueError("A loopback client requires its own diagnostic log")
    client_process = None
    client_output = None
    client_attempted = False
    host_seen_at = None
    with log_file.open("w", encoding="utf-8") as output:
        try:
            process = subprocess.Popen(argv, stdin=subprocess.DEVNULL,
                                       stdout=output, stderr=subprocess.STDOUT)
        except OSError as error:
            output.write(f"SERVER_START_FAILED: {error}\n")
            return 127, "launch_error"
        try:
            while time.monotonic() < deadline:
                output.flush()
                with log_file.open("r", encoding="utf-8",
                                   errors="replace") as reader:
                    reader.seek(offset)
                    observed += reader.read()
                    offset = reader.tell()
                # Launch exactly one genuine Factorio client only after the
                # private native host is ready. No player or chart fabrication.
                if "Hosting game at IP ADDR:" in observed and host_seen_at is None:
                    host_seen_at = time.monotonic()
                if client_argv and host_seen_at is not None and not client_attempted:
                    client_attempted = True
                    try:
                        client_output = client_log_file.open("w", encoding="utf-8")
                        client_process = subprocess.Popen(
                            client_argv, stdin=subprocess.DEVNULL,
                            stdout=client_output, stderr=subprocess.STDOUT)
                    except OSError as error:
                        if client_output is not None:
                            client_output.close()
                            client_output = None
                        client_log_file.write_text(
                            f"CLIENT_START_FAILED: {error}\n", encoding="utf-8")
                if prefix + "FAIL " in observed:
                    reason = "fixture_failure"
                    break
                if connected in observed:
                    reason = "native_gate_observed"
                    break
                # A disconnected client must not consume the full 30-minute
                # engine budget while an auto-paused server advances no ticks.
                if (client_argv and host_seen_at is not None
                        and "CHART_LIVE_REQUEST elapsed=" not in observed
                        and time.monotonic() - host_seen_at >= 120):
                    reason = "client_join_timeout"
                    break
                if process.poll() is not None:
                    reason = "unexpected_server_exit"
                    break
                time.sleep(poll_interval)
        finally:
            # Preserve both partial logs, but never leave the genuine local
            # client running after a failed fixture, timeout or accepted gate.
            if client_process is not None and client_process.poll() is None:
                client_process.terminate()
                try:
                    client_process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    client_process.kill()
                    client_process.wait(timeout=15)
            if client_output is not None:
                client_output.close()
            if client_argv and not client_attempted:
                client_log_file.write_text(
                    "CLIENT_NOT_LAUNCHED_NO_HOST\n", encoding="utf-8")
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=15)
        # Do not disguise a deliberate terminate() as a clean Factorio exit.
        return process.returncode, reason


def private_rail_server_settings(output: pathlib.Path) -> pathlib.Path:
    """Private native server; advance only while a real client is connected."""
    path = output / "rail-server-settings.json"
    path.write_text(json.dumps({
        "name": "Tech Priests isolated rail engine acceptance",
        "description": "Private loopback-only functional test",
        "visibility": {"public": False, "lan": False},
        "max_players": 1,
        "require_user_verification": False,
        "auto_pause": True,
        "autosave_interval": 1000,
    }, indent=2), encoding="utf-8")
    return path


def free_loopback_udp_port() -> int:
    """Avoid disturbing any already-running domestic Factorio session."""
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def rail_native_player_test_command(factorio: pathlib.Path, mods: pathlib.Path,
                                    save: pathlib.Path, ticks: int) -> list[str]:
    """Real headless Factorio test-save with one native engine-created player.

    The Steam executable's graphical --mp-connect client relaunches through
    Steam in the runner and never joins. Factorio --test-save is the native
    headless-with-player mode; its tick limit is NOT an acceptance condition.
    """
    return [str(factorio), "--mod-directory", str(mods),
            "--test-save", str(save), "--test-ticks", str(ticks)]


def rail_connected_smoke_verdict(exit_code: int, log: str) -> bool:
    """Accept ONLY two original physical counted connected rails, never a plan."""
    prefix = "[TP-REMOTE-RAIL-TEST] "
    first = prefix + "PASS first physical rail built and exact stock debited"
    connected = prefix + "PASS two distinct 0338-debited native-connected rails"
    return (exit_code == 0 and prefix + "FAIL " not in log
            and first in log and connected in log)


def reset_rail_smoke_diagnostics(output: pathlib.Path) -> None:
    """Start from a fresh native save and evidence, never a prior attempt."""
    # --create targets a stable path. An older scenario-initial.zip can cause
    # the new save creation to fail or be mistaken for the current fixture.
    # Remove it before launching the engine, alongside stale verdict/logs.
    # Failure to remove a file aborts rather than reusing unverified state.
    for name in ("rail-connected-smoke-result.json", "benchmark.log",
                 "native-server.log", "rail-loopback-client.log",
                 "rail-server-settings.json",
                 "create.log", "scenario-initial.zip"):
        (output / name).unlink(missing_ok=True)


def rail_smoke_evidence(create_exit_code: int, benchmark_exit_code: int | None,
                        log: str | None, engine_version: str,
                        required_series: str, ticks_requested: int,
                        engine_mode: str = "benchmark",
                        driver_stop_reason: str | None = None) -> dict:
    """Retain the real engine's partial observation, including create failures."""
    prefix = "[TP-REMOTE-RAIL-TEST] "
    attempted = benchmark_exit_code is not None
    contents = log or ""
    if engine_mode == "live-headless-server":
        # A driver-requested server shutdown is not a Factorio exit=0.
        # Accept only native PASS receipts, without any native FAIL, and
        # an explicitly observed 36k rail-graph gate.
        accepted = (create_exit_code == 0 and attempted
                    and driver_stop_reason == "native_gate_observed"
                    and rail_connected_smoke_verdict(0, contents))
    else:
        accepted = (create_exit_code == 0 and attempted
                    and rail_connected_smoke_verdict(benchmark_exit_code, contents))
    return {
        "scenario": "remote-rail-acquisition",
        "gate": "two-original-connected-item-debited-rails-only",
        "ticks_requested": ticks_requested,
        "engine_version": engine_version,
        "simulation_mode": engine_mode,
        "driver_stop_reason": driver_stop_reason,
        "required_mod_factorio_series": required_series,
        "create_exit_code": create_exit_code,
        "benchmark_attempted": attempted,
        "engine_exit_code": benchmark_exit_code,
        "first_paid_rail": (prefix + "PASS first physical rail built and exact stock debited" in contents
                            if attempted else None),
        "native_connected_pair": (prefix + "PASS two distinct 0338-debited native-connected rails" in contents
                                  if attempted else None),
        "fixture_failed": (prefix + "FAIL " in contents if attempted else None),
        "accepted": accepted,
        "failure_stage": ("create" if create_exit_code != 0 else
                          engine_mode if not accepted else None),
        "train_and_ore_delivery_accepted": False,
    }


def factorio_runtime_compatible(version_line: str, required_series: str) -> bool:
    """Reject wrong game series; retain the archived 2.0.77 acceptance pin."""
    if required_series not in ("2.0", "2.1"):
        return False
    match = re.search(r"\b(\d+)\.(\d+)\.(\d+)\b", version_line)
    if match is None:
        return False
    major, minor, patch = map(int, match.groups())
    return f"{major}.{minor}" == required_series and (required_series != "2.0" or patch == 77)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scenario", choices=tuple(CASES), required=True)
    ap.add_argument("--factorio", default=shutil.which("factorio"),
                    help="Headless executable matching tech-priests_src/info.json")
    ap.add_argument("--dependency-mods", type=pathlib.Path,
                    help="Existing folder of external required mod ZIP files")
    ap.add_argument("--output-dir", type=pathlib.Path,
                    default=ROOT / "test-artifacts" / "isolated-service")
    ap.add_argument("--ticks", type=int,
                    help="Override scenario benchmark duration")
    ap.add_argument("--midgame-smoke", action="store_true",
                    help="Use 18,060 native ticks to audit the three earliest "
                         "bootstrap checkpoints; never accept the factory goal")
    ap.add_argument("--rail-connected-smoke", action="store_true",
                    help="Genuine 36k+ paid-connected-rail gate with extended 60k physical ledger; "
                         "does not accept train travel or ore delivery")
    ap.add_argument("--seed", type=int, default=907260)
    ap.add_argument("--timeout-seconds", type=int, default=1800)
    args = ap.parse_args()

    scenario = CASES[args.scenario]
    factorio = pathlib.Path(args.factorio) if args.factorio else None
    if not (factorio and factorio.is_file()):
        ap.error("Specify --factorio /path/to/factorio for the active mod version")
    if args.midgame_smoke and args.scenario != "midgame-science":
        ap.error("--midgame-smoke is available only for midgame-science")
    if args.rail_connected_smoke and args.scenario != "remote-rail-acquisition":
        ap.error("--rail-connected-smoke requires remote-rail-acquisition")
    tick_count = (args.ticks if args.ticks is not None else
                  (18060 if args.midgame_smoke else
                   60060 if args.rail_connected_smoke else scenario["ticks"]))
    if tick_count < 600:
        ap.error("--ticks must be at least 600")
    if args.midgame_smoke and not 18060 <= tick_count < 36000:
        ap.error("--midgame-smoke must cover native 0/9k/18k marks "
                 "without claiming full nine-checkpoint acceptance")
    if args.rail_connected_smoke and not 36060 <= tick_count < 90000:
        ap.error("--rail-connected-smoke requires the native 36k checkpoint "
                 "and cannot credit the full 90k train expedition")
    # The active mod's declared engine series is the acceptance target.
    # Legacy Factorio 2.0 acceptance remains pinned to exact 2.0.77.
    try:
        mod_info = json.loads(
            (ROOT / "tech-priests_src" / "info.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        ap.error("Cannot read active mod compatibility metadata: " + str(error))
    required_series = mod_info.get("factorio_version")
    version = subprocess.run([str(factorio), "--version"],
                             capture_output=True, text=True, check=False)
    version_line = (version.stdout or version.stderr).splitlines()[0:1]
    engine_version = version_line[0] if version_line else "unidentified executable"
    if version.returncode != 0 or not factorio_runtime_compatible(
            engine_version, required_series):
        ap.error("Factorio version incompatible with mod factorio_version=" +
                 str(required_series) + "; found " + engine_version)

    output = args.output_dir.resolve() / args.scenario
    output.mkdir(parents=True, exist_ok=True)
    rail_result_path = output / "rail-connected-smoke-result.json"
    if args.rail_connected_smoke:
        reset_rail_smoke_diagnostics(output)
    mods = output / "mods"
    if mods.exists():
        shutil.rmtree(mods)
    mods.mkdir()
    shutil.copytree(ROOT / "tech-priests_src", mods / "tech-priests")
    if args.dependency_mods:
        if not args.dependency_mods.is_dir():
            ap.error("--dependency-mods must be an existing directory")
        for source in args.dependency_mods.iterdir():
            if source.name.startswith("tech-priests") or source.name == "base":
                continue
            if source.is_file() and source.suffix.lower() == ".zip":
                shutil.copy2(source, mods / source.name)
            elif source.is_dir() and (source / "info.json").is_file():
                shutil.copytree(source, mods / source.name)
    content = (ROOT / scenario["fixture"]).read_text(encoding="utf-8")
    if "function M.install()" not in content:
        ap.error("Fixture missing explicit install contract")
    dest = mods / "tech-priests" / "scripts" / "core"
    (dest / (scenario["module"] + ".lua")).write_text(content, encoding="utf-8")
    with (mods / "tech-priests" / "control.lua").open(
            "a", encoding="utf-8") as control:
        control.write("\n-- Isolated CI-only scenario; never distributed.\n"
                      f'require("scripts.core.{scenario["module"]}").install()\n')

    # Isolated factory/maintenance/rail scenarios omit random biter camps.
    # The standing mixed-rank endurance test covers hostile combat separately.
    map_settings = output / "map-gen-settings.json"
    map_settings.write_text(json.dumps({
        "seed": args.seed, "peaceful_mode": True,
        "autoplace_controls": {"enemy-base": {
            "frequency": "none", "size": "none", "richness": "none"}},
    }), encoding="utf-8")
    save = output / "scenario-initial.zip"
    created_engine_started = time.monotonic()
    created = run([str(factorio), "--mod-directory", str(mods),
                   "--create", str(save), "--map-gen-settings",
                   str(map_settings)],
                  output / "create.log", args.timeout_seconds)
    create_engine_wall_minutes = round((time.monotonic()-created_engine_started)/60, 6)
    if created:
        if args.rail_connected_smoke:
            evidence = rail_smoke_evidence(
                created, None, None, engine_version, required_series, tick_count)
            rail_result_path.write_text(
                json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8")
        print("FAIL headless save creation; see " + str(output / "create.log"))
        return 1
    if args.rail_connected_smoke:
        # Use Factorio's native headless test-save mode with an actual player.
        # The Steam graphical --mp-connect client restarted before joining;
        # its auto-paused server could never process chart requests. This
        # mode exercises native charting without any synthetic player, map
        # credit, public listener, Steam restart or second controller.
        engine_mode = "native-player-test-save"
        native_log = output / "native-test-save.log"
        engine_status = run(
            rail_native_player_test_command(factorio, mods, save, tick_count),
            native_log, args.timeout_seconds)
        contents = native_log.read_text(encoding="utf-8", errors="replace")
        for line in contents.splitlines():
            if scenario["prefix"] in line:
                print(line[:1200])
        # A clean --test-ticks exit alone never establishes a functional gate:
        # BOTH physically debited originals and their native graph edge must
        # have been independently observed by the original Lua fixture.
        evidence = rail_smoke_evidence(
            0, engine_status, contents, engine_version, required_series,
            tick_count, engine_mode=engine_mode)
        rail_result_path.write_text(
            json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8")
        if not evidence["accepted"]:
            print("FAIL native player test-save physical rail gate; train/ore UNTESTED")
            print("Engine logs: " + str(native_log))
            return 1
        print("PASS two original item-debited native-connected rails ONLY; "
              "train/Magos/ore return UNTESTED")
        print("Engine logs: " + str(native_log))
        return 0
    benchmark_started = time.monotonic()
    benchmark = run([str(factorio), "--mod-directory", str(mods),
                     "--benchmark", str(save), "--benchmark-ticks",
                     str(tick_count)], output / "benchmark.log",
                    args.timeout_seconds)
    benchmark_engine_wall_minutes = round((time.monotonic()-benchmark_started)/60, 6)
    contents = (output / "benchmark.log").read_text(
        encoding="utf-8", errors="replace")
    for line in contents.splitlines():
        if scenario["prefix"] in line:
            print(line[:1200])
    if args.rail_connected_smoke:
        # A failed native process retains the observations it actually made.
        evidence = rail_smoke_evidence(
            0, benchmark, contents, engine_version, required_series, tick_count)
        passed = evidence["accepted"]
        rail_result_path.write_text(
            json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8")

        if not passed:
            print("FAIL real-engine two-paid-rails smoke; train/ore UNTESTED")
            print("Engine logs: " + str(output / "benchmark.log"))
            return 1
        print("PASS two original item-debited native-connected rails ONLY; "
              "train/Magos journey and ore return UNTESTED")
        print("Engine logs: " + str(output / "benchmark.log"))
        return 0
    if args.scenario == "condenser-v22c-physical":
        # The source-locked fixture validates *real entities and native ports*
        # in Factorio's on_init lifecycle during --create, not an artificial
        # broker pulse. Benchmark then ensures that same save reloads without
        # engine failure. Preserve separate phase/exit evidence.
        create_contents = (output / "create.log").read_text(
            encoding="utf-8", errors="replace")
        for line in create_contents.splitlines():
            if scenario["prefix"] in line:
                print("NATIVE_CREATE " + line[:1200])
        native_evidence = create_contents + "\n" + contents
        receipt = {"schema":"tech-priests.condenser-v22c-native-physical-v1",
                   "runtime_engine":engine_version,
                   "native_create_exit":created,
                   "native_benchmark_exit":benchmark,
                   "evidence_phase":"native-factorio-on-init-plus-benchmark",
                   "accepted":False}
        try:
            receipt.update(verify_condenser_v22c_physical_log(
                benchmark, native_evidence))
        except ValueError as error:
            receipt["blocker"] = str(error)
        (output / "condenser-v22c-native-physical-result.json").write_text(
            json.dumps(receipt, indent=2, sort_keys=True)+"\n", encoding="utf-8")
        print("CONDENSER_V22C_NATIVE_PHYSICAL_VERDICT " + json.dumps(receipt, sort_keys=True))
        return 0 if receipt["accepted"] else 1
    if args.scenario == "remote-robot-acquisition":
        create_contents = (output / "create.log").read_text(
            encoding="utf-8", errors="replace")
        for line in create_contents.splitlines():
            if scenario["prefix"] in line and (
                    "NATIVE_PHYSICAL_SOURCE" in line or "FAIL " in line
                    or "NATIVE_ON_INIT" in line):
                print("NATIVE_CREATE_1380 " + line[:1200])
        native = {
            "schema": "tech-priests-1380-native-autonomous-robot-v1",
            "scenario": "production-0259-to-1076-to-0338",
            "native_benchmark_exit": benchmark,
            "native_benchmark_process_wall_minutes": benchmark_engine_wall_minutes,
            "native_create_process_wall_minutes": create_engine_wall_minutes,
            "native_factorio_process_wall_minutes": round(
                benchmark_engine_wall_minutes + create_engine_wall_minutes, 6),
            "new_distinct_ore_delivery_gates": 0,
            "accepted": False,
        }
        try:
            native.update(verify_autonomous_robot_1380_process_logs(
                created, create_contents, benchmark, contents))
            passed = True
        except ValueError as error:
            native["blocker"] = str(error)
            passed = False
        (output / "native-autonomous-robot-result.json").write_text(
            json.dumps(native, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if passed:
            print("PASS true native autonomous 0259 and robot-built paired Intermediate; "
                  "ore return/save reload UNTESTED")
            return 0
        print("FAIL native autonomous robot gate: " + str(native["blocker"]))
        print("Engine logs: " + str(output / "benchmark.log"))
        return 1
    if args.scenario == "midgame-science":
        from midgame_checkpoint_audit import inspect, validate_smoke
        # Factorio HEADLESS DOES NOT render PNG screenshots. Archive its
        # *actual* JSON entity snapshots and generate clearly labeled
        # schematic telemetry maps. A graphical Factorio client can later
        # save real PNGs at the same named checkpoints.
        from render_midgame_science_timelapse import assemble
        paths = [
            pathlib.Path.home() / ".factorio/script-output/tech-priests-midgame",
            pathlib.Path.home() / ".local/share/factorio/script-output/tech-priests-midgame",
            factorio.parent.parent.parent / "script-output/tech-priests-midgame",
            output / "script-output/tech-priests-midgame",
        ]
        available = next((p for p in paths if p.is_dir()), None)
        if not available:
            print("FAIL no actual Factorio telemetry script-output directory; "
                  "expected one of " + str(paths) +
                  "; benchmark_status=" + str(benchmark))
            return 1
        screenshots = output / "screenshots"
        checkpoints = output / "checkpoints"
        screenshots.mkdir(exist_ok=True)
        checkpoints.mkdir(exist_ok=True)
        for original in sorted(available.glob("checkpoint-*.json")):
            shutil.copy2(original, checkpoints / original.name)
        for original in sorted(available.glob("checkpoint-*.png")):
            shutil.copy2(original, screenshots / original.name)
        # Always report the last genuine checkpoint before trying to render
        # the full nine-frame GIF. An incomplete native run is informative
        # evidence, NOT a passing research/factory acceptance.
        try:
            partial = inspect(checkpoints,
                              (0, 9000, 18000) if args.midgame_smoke else ())
            (output / "partial-checkpoint-diagnostics.json").write_text(
                json.dumps(partial, indent=2, sort_keys=True),
                encoding="utf-8")
            print("MIDGAME_PARTIAL_ENGINE_EVIDENCE " + json.dumps(
                partial, sort_keys=True, separators=(",", ":")))
            if args.midgame_smoke:
                validate_smoke(partial)
        except (OSError, ValueError) as error:
            print("FAIL native checkpoint diagnostic: " + str(error))
            return 1
        if args.midgame_smoke:
            if benchmark != 0 or scenario["prefix"] + " FAIL " in contents:
                print("FAIL early midgame smoke benchmark_status=" +
                      str(benchmark))
                return 1
            # The MIDGAME_READY event is emitted during the isolated
            # --create on_init process, not necessarily the later benchmark.
            # The native initial checkpoint and genuine stocked paired
            # checkpoint are the authoritative continuity proof here.
            print("PASS early physical Factorio inventory/decision "
                  "checkpoints 0,9000,18000; FULL SCIENCE OBJECTIVE UNTESTED")
            return 0
        if benchmark != 0:
            print("FAIL full midgame benchmark_status=" + str(benchmark) +
                  " (124 means process timed out); last_native_elapsed=" +
                  str(partial.get("last_elapsed")) +
                  "; FULL SCIENCE OBJECTIVE UNTESTED")
            return 1
        try:
            report = assemble(checkpoints, output / "visual-history",
                              screenshots)
        except (OSError, ValueError, RuntimeError) as error:
            print("FAIL genuine Factorio checkpoints/visual assembly: " +
                  str(error))
            return 1
        # Checkpoint autosaves are REAL only if Factorio wrote ZIPs.
        # A logged game.auto_save request does not make a save file.
        saves = output / "checkpoint-saves"
        saves.mkdir(exist_ok=True)
        possible = [
            pathlib.Path.home() / ".factorio/saves",
            pathlib.Path.home() / ".local/share/factorio/saves",
            factorio.parent.parent.parent / "saves",
        ]
        save_count = 0
        for folder in possible:
            if not folder.is_dir():
                continue
            for save_file in sorted(folder.glob("_autosave-tp-midgame-*.zip")):
                destination = saves / save_file.name
                if not destination.exists():
                    shutil.copy2(save_file, destination)
                    save_count += 1
        print("CHECKPOINT_EVIDENCE frames=" +
              str(report["frame_count"]) +
              " visual_kind=" + report["visualization"] +
              " verified_checkpoint_save_zips=" + str(save_count) +
              " output=" + str(output / "visual-history"))
        print("FACTORY_OBJECTIVES three_pack_output=" +
              str(report["all_three_sciences_produced_at_end"]) +
              " advanced_chemical_output=" +
              str(report["chemical_science_produced_at_end"]))
    fatal = scenario["prefix"] + " FAIL "
    if benchmark or fatal in contents or scenario["prefix"] + " " + scenario["pass"] not in contents:
        print("FAIL scenario=" + args.scenario + " exit=" + str(benchmark) +
              " pass_marker=" + str(scenario["pass"] in contents))
        print("Engine logs: " + str(output / "benchmark.log"))
        return 1
    print("PASS independent engine scenario=" + args.scenario)
    print("Engine logs: " + str(output / "benchmark.log"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
