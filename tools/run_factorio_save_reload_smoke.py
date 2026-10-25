#!/usr/bin/env python3
"""CI-only Factorio save/reload smoke: real server autosave, separate engine reload."""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import time
import zipfile

SAVE_NAME = "_autosave-tech-priests-ci-persistence.zip"
STRANDED_SAVE_NAME = "_autosave-tech-priests-ci-stranded.zip"
STRANDED_REQUEST_MARKER = "[TP-GROUND-RANK-TEST] CARGO_ENGINE_DEATH_SAVE_REQUESTED"
STRANDED_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_STRANDED_RELOAD"
PASS_MARKER = "[TP-GROUND-RANK-TEST] PASS SAVE_RELOAD_VERIFIED"
CARGO_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_SAVE_RELOAD"
DEATH_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_DEATH_REIMPRINT"
RELOCATION_MARKER = "[TP-GROUND-RANK-TEST] PASS RELOCATION_ENGINE_PHYSICAL"
ORE_RETURN_MARKER = "[TP-GROUND-RANK-TEST] PASS ORE_ENGINE_COUNTED_MAGOS_RETURN"
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


def verify_death_reimprint_log(content: str) -> None:
    """Require a real successor and zero residual fixture stock after death."""
    match = re.search(
        r"\[TP-GROUND-RANK-TEST\] PASS CARGO_ENGINE_DEATH_REIMPRINT"
        r"[^\n]* old_priest=(\d+) new_priest=(\d+)"
        r" held=0 net_fixture_delta=0", content)
    if not match or match.group(1) == match.group(2):
        raise RuntimeError("engine did not prove distinct re-imprinted priest "
                           "and physically conserved recovered cargo")


def verify_relocation_log(content: str) -> None:
    """Require actual mined cargo, a different built station, and the same priest."""
    reservation = re.search(
        r"\[TP-GROUND-RANK-TEST\] RELOCATION_ENGINE_WORKER_RESERVED"
        r"[^\n]* worker=(\d+) writ=(\d+)", content)
    candidate_reservation = re.search(
        r"\[TP-GROUND-RANK-TEST\] RELOCATION_ENGINE_CANDIDATE_RESERVED"
        r"[^\n]* candidate=(\d+) writ=(\d+)", content)
    ghost_proof = re.search(
        r"\[TP-GROUND-RANK-TEST\] RELOCATION_ENGINE_GHOST_POSITION_VERIFIED"
        r"[^\n]* ghost=(\d+) offset_sq=([0-9.]+)", content)
    preflight = re.search(
        r"\[TP-GROUND-RANK-TEST\] RELOCATION_ENGINE_PREFLIGHT_PASS"
        r"[^\n]* ghost=(\d+) worker=(\d+) writ=(\d+)", content)
    if "RELOCATION_ENGINE_MINED" not in content:
        raise RuntimeError("engine did not prove safe remote mining into carried cargo")
    if (not reservation or not candidate_reservation or
            not ghost_proof or not preflight or
            reservation.groups() != preflight.groups()[1:] or
            candidate_reservation.group(2) != reservation.group(2) or
            ghost_proof.group(1) != preflight.group(1) or
            float(ghost_proof.group(2)) > 2.25 or
            not reservation.start() < ghost_proof.start() <
            candidate_reservation.start() < preflight.start() <
            content.index("RELOCATION_ENGINE_MINED")):
        raise RuntimeError("engine did not retain the original exclusive worker writ")
    match = re.search(
        r"\[TP-GROUND-RANK-TEST\] PASS RELOCATION_ENGINE_PHYSICAL"
        r"[^\n]* old_station=(\d+) new_station=(\d+)"
        r" priest=(\d+) held=0 net_station_delta=0", content)
    if not match or match.group(1) == match.group(2) or (
            candidate_reservation and
            match.group(1) != candidate_reservation.group(1)):
        raise RuntimeError("engine did not prove counted physical station redeployment")



def verify_ore_return_log(content: str) -> None:
    """Require naturally generated ore, isolated fixtures and three counted hops."""
    isolated = re.search(
        r"ORE_ENGINE_SITE_ISOLATED[^\n]*"
        r" min_relocation_separation_sq=([0-9.]+) required_sq=([0-9.]+)"
        r" hierarchy_peer_reach=([0-9.]+)", content)
    if not isolated or float(isolated.group(1)) < float(isolated.group(2)) or (
            float(isolated.group(3)) <= 0 or
            float(isolated.group(2)) !=
            math.ceil(float(isolated.group(3)) + 128) ** 2):
        raise RuntimeError("ore fixture intruded on physical station-recovery authority")
    target = re.search(
        r"ORE_ENGINE_NATURAL_TARGET_SELECTED[^\n]*"
        r" resource=iron-ore amount=(\d+)"
        r" magos=(\d+) senior=(\d+) intermediate=(\d+) junior=(\d+)"
        r" fixture_stations_not_construction_credit=true", content)
    route = re.search(
        r"ORE_ENGINE_ROUTE_VERIFIED[^\n]*"
        r" junior=(\d+) intermediate=(\d+) senior=(\d+) magos=(\d+)",
        content)
    mined = re.search(
        r"ORE_ENGINE_MINED[^\n]*natural_before=(\d+)"
        r" natural_after=(\d+) held=1", content)
    hops = re.findall(
        r"ORE_ENGINE_HOP[^\n]*hop=(\d+) from=(\d+) to=(\d+) counted=1",
        content)
    finished = re.search(
        r"PASS ORE_ENGINE_COUNTED_MAGOS_RETURN[^\n]*"
        r"natural_mined=1 physical_hops=3 magos_received=1 held=0", content)
    if not (target and route and mined and finished and len(hops)==3):
        raise RuntimeError("engine did not prove counted natural ore Magos return")
    ids = [int(target.group(i)) for i in (2, 3, 4, 5)]
    if len(set(ids)) != 4 or list(map(int, route.groups())) != ids[::-1]:
        raise RuntimeError("engine return route is not the original four physical ranks")
    if not (int(mined.group(1)) > int(mined.group(2)) >= 0):
        raise RuntimeError("engine did not observe natural ore depletion")
    expected = [(1, ids[3], ids[2]), (2, ids[2], ids[1]),
                (3, ids[1], ids[0])]
    if [tuple(map(int, hop)) for hop in hops] != expected:
        raise RuntimeError("engine skipped, reordered or fabricated a physical hop")
    if not (target.start() < route.start() < mined.start()
            < content.index("ORE_ENGINE_HOP") < finished.start()):
        raise RuntimeError("engine ore return markers out of physical order")


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
    if source.count("local Cargo=CARGO_ENGINE_0824") != 4:
        raise AssertionError("all four runtime cargo stages must use the parsed module")


def verify_death_event_route_boundary() -> None:
    """Require the canonical 0499 death dispatcher after all late installs."""
    root = pathlib.Path(__file__).resolve().parents[1]
    control = (root / "tech-priests_src/control.lua").read_text(encoding="utf-8")
    harness = (root / "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
               ).read_text(encoding="utf-8")
    marker = "registry.reconcile_event(defines.events.on_entity_died)"
    if control.count(marker) != 1 or control.index(marker) < control.index(
            "Reaction.install()==true"):
        raise AssertionError("death dispatcher must be reconciled once after late installs")
    probe = "registry.event_delivery_status(defines.events.on_entity_died)"
    if (harness.count(probe) != 1 or
            "CARGO_DEATH_EVENT_DISPATCH_UNVERIFIED" not in harness or
            harness.index(probe) > harness.index("priest.die(game.forces.enemy)") or
            'route.owner=="priest_lifecycle_authority_0499"' not in harness):
        raise AssertionError("real-engine death probe must verify canonical event delivery")


def self_test() -> int:
    verify_cargo_import_boundary()
    verify_death_event_route_boundary()
    check_engine_log(REQUEST_MARKER + " tick=1800", REQUEST_MARKER)
    check_engine_log(PASS_MARKER + " tick=2700 pairs=4", PASS_MARKER)
    check_engine_log(CARGO_MARKER + " held=0 net_fixture_delta=0", CARGO_MARKER)
    verify_death_reimprint_log(DEATH_MARKER +
        " tick=8400 station=1 old_priest=2 new_priest=3 held=0 net_fixture_delta=0")
    check_engine_log(STRANDED_REQUEST_MARKER + " tick=3000 held=1",
                     STRANDED_REQUEST_MARKER)
    check_engine_log(STRANDED_RELOAD_MARKER + " held=1 chest_delta=0",
                     STRANDED_RELOAD_MARKER)
    verify_relocation_log(
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_WORKER_RESERVED worker=10 writ=41\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_GHOST_POSITION_VERIFIED ghost=20 offset_sq=0.5\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_CANDIDATE_RESERVED candidate=15 writ=41\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_PREFLIGHT_PASS ghost=20 worker=10 writ=41 remote_mining_denied=true\n"
        "RELOCATION_ENGINE_MINED carried=1\n" + RELOCATION_MARKER +
        " tick=10000 old_station=15 new_station=27 priest=33 held=0 net_station_delta=0")
    for bad in ("",
                "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_WORKER_RESERVED worker=10 writ=41\n"
                "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_GHOST_POSITION_VERIFIED ghost=20 offset_sq=0.5\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_CANDIDATE_RESERVED candidate=15 writ=41\n"
                "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_PREFLIGHT_PASS ghost=20 worker=10 writ=42\n"
                "RELOCATION_ENGINE_MINED carried=1\n" + RELOCATION_MARKER +
                " old_station=15 new_station=27 priest=33 held=0 net_station_delta=0",
                RELOCATION_MARKER +
                " old_station=15 new_station=15 priest=33 held=0 net_station_delta=0",
                RELOCATION_MARKER +
                " old_station=15 new_station=27 priest=33 held=1 net_station_delta=0"):
        try:
            verify_relocation_log(bad)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified physical relocation accepted")
    ore_proof = (
        "ORE_ENGINE_SITE_ISOLATED min_relocation_separation_sq=150000 required_sq=121104 hierarchy_peer_reach=220\n"
        "ORE_ENGINE_NATURAL_TARGET_SELECTED resource=iron-ore amount=10 "
        "magos=100 senior=101 intermediate=102 junior=103 "
        "fixture_stations_not_construction_credit=true\n"
        "ORE_ENGINE_ROUTE_VERIFIED junior=103 intermediate=102 senior=101 magos=100\n"
        "ORE_ENGINE_MINED natural_before=10 natural_after=9 held=1\n"
        "ORE_ENGINE_HOP hop=1 from=103 to=102 counted=1\n"
        "ORE_ENGINE_HOP hop=2 from=102 to=101 counted=1\n"
        "ORE_ENGINE_HOP hop=3 from=101 to=100 counted=1\n"
        "PASS ORE_ENGINE_COUNTED_MAGOS_RETURN natural_mined=1 physical_hops=3 "
        "magos_received=1 held=0")
    verify_ore_return_log(ore_proof)
    for broken in (ore_proof.replace("natural_after=9", "natural_after=10"),
                   ore_proof.replace("min_relocation_separation_sq=150000",
                                     "min_relocation_separation_sq=100000"),
                   ore_proof.replace("required_sq=121104", "required_sq=100000"),
                   ore_proof.replace("hierarchy_peer_reach=220",
                                     "hierarchy_peer_reach=400"),
                   ore_proof.replace("ORE_ENGINE_SITE_ISOLATED",
                                     "ORE_ENGINE_SITE_NOT_VERIFIED"),
                   ore_proof.replace("hop=2 from=102 to=101",
                                     "hop=2 from=103 to=101"),
                   ore_proof.replace("magos_received=1", "magos_received=2"),
                   ore_proof.replace("junior=103 intermediate=102 senior=101 magos=100",
                                     "junior=103 intermediate=101 senior=102 magos=100")):
        try:
            verify_ore_return_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("invalid physical ore-return proof accepted")
    harness = (pathlib.Path(__file__).resolve().parents[1] /
               "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
               ).read_text(encoding="utf-8")
    if (harness.count("ore_engine_relocation_separation_sq(pos)") != 2
            or "ORE_ENGINE_FIXTURE_STATION_INTRUDES_RELOCATION_AUTHORITY" not in harness
            or "ORE_ENGINE_SITE_ISOLATED" not in harness
            or "hierarchy.max_link_distance" not in harness
            or "ORE_ENGINE_JUNIOR_PEER_COLLISION" not in harness):
        raise AssertionError("ore fixture must reject station sites near relocation authority")
    if (harness.count('game.auto_save("tech-priests-ci-stranded")') != 1
            or harness.count("PASS CARGO_ENGINE_STRANDED_RELOAD") != 1
            or "CARGO_DEATH_STRANDED_RELOAD_CUSTODY_INVALID" not in harness
            or harness.count("PASS RELOCATION_ENGINE_PHYSICAL") != 1
            or "RELOCATION_ENGINE_REMOTE_MINE_NOT_DENIED" not in harness
            or "RELOCATION_ENGINE_GHOST_UNEXPECTED_DISPLACEMENT" not in harness
            or "RELOCATION_ENGINE_GHOST_POSITION_VERIFIED" not in harness
            or "rec.ghost_position={x=actual_ghost_position.x,y=actual_ghost_position.y}" not in harness
            or "RELOCATION_ENGINE_RESERVATION_STOLEN" not in harness
            or "RELOCATION_ENGINE_WORKER_BUSY_AT_SETUP" not in harness
            or "RELOCATION_ENGINE_REBIND_OR_ACCOUNTING_FAILED" not in harness):
        raise AssertionError("stranded engine checkpoint and custody assertion missing")
    for bad in ("", DEATH_MARKER + " old_priest=2 new_priest=2 held=0 net_fixture_delta=0",
                DEATH_MARKER + " old_priest=2 new_priest=3 held=1 net_fixture_delta=0"):
        try:
            verify_death_reimprint_log(bad)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified death/re-imprint marker accepted")
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
                       server_log: pathlib.Path, seconds: float,
                       save_name: str = SAVE_NAME,
                       request_marker: str = REQUEST_MARKER) -> pathlib.Path:
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
        for path in sorted(game_root.rglob(save_name)):
            if path.stat().st_size < 2048:
                continue
            log = server_log.read_text(encoding="utf-8", errors="replace")
            if request_marker not in log or "Saving finished" not in log:
                continue
            try:
                with zipfile.ZipFile(path) as archive:
                    if archive.testzip() is not None:
                        continue
            except (OSError, zipfile.BadZipFile):
                continue
            check_engine_log(log, request_marker)
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

    def server_checkpoint(source: pathlib.Path, log_path: pathlib.Path,
                          save_name: str, request_marker: str,
                          target_name: str) -> tuple[pathlib.Path, str]:
        # Each phase runs a real server and stops only after a verified
        # on-disk autosave. The next phase uses a different Factorio process.
        cmd = [str(binary), "--mod-directory", str(mods),
               "--start-server", str(source), "--server-settings",
               str(settings), "--bind", "127.0.0.1"]
        with log_path.open("w", encoding="utf-8") as handle:
            process = subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT)
            try:
                saved = wait_for_real_save(
                    process, game_root, log_path, args.server_timeout,
                    save_name=save_name, request_marker=request_marker)
                target = output / target_name
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
        return target, log_path.read_text(encoding="utf-8", errors="replace")

    first, first_log = server_checkpoint(
        initial, work / "factorio-save-server.log", SAVE_NAME,
        REQUEST_MARKER, "tech-priests-ground-ranks-save-checkpoint.zip")
    check_engine_log(first_log, REQUEST_MARKER)

    # A separate engine process verifies ordinary station/cargo persistence,
    # then kills the actual carrier and saves the stranded LuaInventory before
    # re-imprinting. No death or replacement is synthesized by this runner.
    stranded, second_log = server_checkpoint(
        first, work / "factorio-stranded-server.log", STRANDED_SAVE_NAME,
        STRANDED_REQUEST_MARKER,
        "tech-priests-ground-ranks-stranded-checkpoint.zip")
    check_engine_log(second_log, PASS_MARKER)
    check_engine_log(second_log, CARGO_MARKER)
    check_engine_log(second_log, STRANDED_REQUEST_MARKER)
    if "persisted_stations=4 persisted_priests=4" not in second_log:
        raise RuntimeError("reloaded Cogitator pairs were not preserved")
    if "held=0 net_fixture_delta=0" not in second_log:
        raise RuntimeError("ordinary cargo save/reload fixture did not balance")

    # Third independent Factorio process MUST see the original stranded
    # inventory after load, wait for canonical re-imprinting, physically
    # reclaim the same hold, and return the exact item to station storage.
    reload_log = work / "factorio-reload.log"
    with reload_log.open("w", encoding="utf-8") as handle:
        result = subprocess.run([str(binary), "--mod-directory", str(mods),
                                 "--benchmark", str(stranded),
                                 "--benchmark-ticks", "21000"],
                                stdout=handle, stderr=subprocess.STDOUT,
                                check=False, timeout=args.reload_timeout)
    content = reload_log.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(f"Factorio stranded reload failed: exit status {result.returncode}")
    check_engine_log(content, STRANDED_RELOAD_MARKER)
    check_engine_log(content, DEATH_MARKER)
    verify_death_reimprint_log(content)
    check_engine_log(content, RELOCATION_MARKER)
    verify_relocation_log(content)
    check_engine_log(content, ORE_RETURN_MARKER)
    verify_ore_return_log(content)
    if "held=1 chest_delta=0" not in content:
        raise RuntimeError("stranded cargo did not survive independent engine reload")
    if "held=0 net_fixture_delta=0" not in content:
        raise RuntimeError("re-imprinted priest did not return the conserved item")
    print("PASS: three real Factorio processes, two CRC-verified saves, "
          "4 identities preserved, stranded cargo persisted across reload, "
          "distinct re-imprinted priest physically recovered and returned item, "
          "and an existing staffed station was physically mined and redeployed; "
          "natural ore returned through three real physical inventory hops")
    print(f"Checkpoints: {first} ({first.stat().st_size} bytes), "
          f"{stranded} ({stranded.stat().st_size} bytes)")
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
            for name in ("factorio-save-server.log", "factorio-stranded-server.log",
                         "factorio-reload.log"):
                path = pathlib.Path(args.work_dir) / name
                if path.is_file():
                    print(f"--- tail {name} ---", file=sys.stderr)
                    print("\n".join(path.read_text(encoding="utf-8",
                         errors="replace").splitlines()[-35:]), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
