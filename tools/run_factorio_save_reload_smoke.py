#!/usr/bin/env python3
"""CI-only Factorio save/reload smoke: real server autosave, separate engine reload."""
from __future__ import annotations

import argparse
import json
import math
import os
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import time
import zipfile

from ci_performance_reporting_1066 import (write_report as write_ci_performance_report_1066,
                                          self_test as self_test_ci_performance_1066)

SAVE_NAME = "_autosave-tech-priests-ci-persistence.zip"
STRANDED_SAVE_NAME = "_autosave-tech-priests-ci-stranded.zip"
ORE_CARRY_SAVE_NAME = "_autosave-tech-priests-ci-ore-carried.zip"
STOCK_CARRY_SAVE_NAME = "_autosave-tech-priests-ci-stock-carried.zip"
ROBOT_MIDFLIGHT_SAVE_NAME = "_autosave-tech-priests-ci-robot-midflight.zip"
ROBOT_MIDFLIGHT_SAVE_MARKER = "[TP-GROUND-RANK-TEST] ROBOT_ENGINE_S2_MIDFLIGHT_SAVE_REQUESTED_1360"
ROBOT_MIDFLIGHT_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_CUSTODY_1360"
STRANDED_REQUEST_MARKER = "[TP-GROUND-RANK-TEST] CARGO_ENGINE_DEATH_SAVE_REQUESTED"
STRANDED_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_STRANDED_RELOAD"
ORE_CARRY_SAVE_MARKER = "[TP-GROUND-RANK-TEST] ORE_ENGINE_CARRIER_SAVE_REQUESTED"
ORE_CARRY_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS ORE_ENGINE_CARRIER_RELOAD"
STOCK_CARRY_SAVE_MARKER = "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_CARRY_SAVE_REQUESTED"
STOCK_CARRY_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS RELOCATION_ENGINE_STOCK_CARRY_RELOAD"
PASS_MARKER = "[TP-GROUND-RANK-TEST] PASS SAVE_RELOAD_VERIFIED"
CARGO_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_SAVE_RELOAD"
DEATH_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_DEATH_REIMPRINT"
RELOCATION_MARKER = "[TP-GROUND-RANK-TEST] PASS RELOCATION_ENGINE_PHYSICAL"
ORE_RETURN_MARKER = "[TP-GROUND-RANK-TEST] PASS ORE_ENGINE_COUNTED_MAGOS_RETURN"
REQUEST_MARKER = "[TP-GROUND-RANK-TEST] SAVE_RELOAD_REQUESTED"
HARNESS_INSTALL = 'require("scripts.core.ci_ground_rank_harness").install()'



def verify_robot_engine_s2_log(content: str) -> None:
    """Only a real robot event, mined source item and 0338 receipt count."""
    source = re.search(
        r"ROBOT_ENGINE_S2_SOURCE_MINED tick=(\d+) "
        r"source_unit=(\d+) provider_unit=(\d+) "
        r"stock=1 physical_mine=true", content)
    ghost = re.search(
        r"ROBOT_ENGINE_S2_GHOST tick=(\d+) "
        r"magos=(\d+) magos_priest=(\d+) port=(\d+) "
        r"network_stock_before=1 ghost=1", content)
    event = re.search(
        r"ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT tick=(\d+) "
        r"station=(\d+) robot=(\d+)", content)
    completed = re.search(
        r"PASS ROBOT_ENGINE_S2_PHYSICAL_BUILD tick=(\d+) "
        r"magos=(\d+) magos_priest=(\d+) station=(\d+) "
        r"priest=(\d+) robot=(\d+) source_delta=1 "
        r"network_delta=1 ghost=0 hierarchy=direct-senior "
        r"robot_event=on_robot_built_entity", content)
    if not (source and ghost and event and completed):
        raise RuntimeError("S2 native physical robot-build evidence missing")
    s, g, e, c = (
        tuple(map(int, m.groups())) for m in (source, ghost, event, completed)
    )
    if not (s[0] < g[0] <= e[0] <= c[0]
            and g[1] == c[1] and g[2] == c[2]
            and e[1] == c[3] and e[2] == c[5]
            and len({s[1], s[2], g[1], g[2], g[3],
                     c[3], c[4], c[5]}) == 8):
        raise RuntimeError("S2 native robot, hierarchy or custody identity mismatch")
    # 1340: the same original request must refuse construction while ALL
    # three genuine docked robots are held in an engine-owned inventory.
    # This is a distinct native safety gate, not inferred from a later build.
    def exactly_one_native_1340(pattern: str, marker: str) -> tuple[int, ...]:
        if content.count(marker) != 1:
            raise RuntimeError("S2 native robotless evidence missing or duplicated: " + marker)
        matches = list(re.finditer(pattern, content))
        if len(matches) != 1:
            raise RuntimeError("S2 native robotless custody/count mismatch: " + marker)
        return tuple(map(int, matches[0].groups()))

    request = exactly_one_native_1340(
        r"ROBOT_ENGINE_S2_REQUEST tick=(\d+) magos=(\d+) "
        r"priest=(\d+) port=(\d+) powered=true robots=3 network_stock=1",
        "ROBOT_ENGINE_S2_REQUEST tick=")
    robotless_cut = exactly_one_native_1340(
        r"ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_CUT_1340 tick=(\d+) "
        r"magos=(\d+) priest=(\d+) removed_robots=3 "
        r"station_stock=1 request_retained=true",
        "ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_CUT_1340 tick=")
    robotless_refusal = exactly_one_native_1340(
        r"PASS ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_REFUSAL_1340 tick=(\d+) "
        r"magos=(\d+) priest=(\d+) ghost=0 claim=0 station_stock=1 "
        r"removed_robots=3 restored_robots=3 "
        r"request_retained=true item_conserved=true",
        "PASS ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_REFUSAL_1340 tick=")
    if not (s[0] < request[0] == robotless_cut[0]
            and robotless_refusal[0] - robotless_cut[0] >= 180
            and robotless_refusal[0] < g[0]
            and request[1:3] == robotless_cut[1:] == robotless_refusal[1:]
            and request[1:3] == g[1:3] == c[1:3]
            and request[3] == g[3]):
        raise RuntimeError("S2 robotless refusal did not conserve the original "
                           "Magos, three physical robots, pending request, "
                           "station inventory or 180-tick native refusal")



def verify_robot_midflight_reload_1360_log(first: str, reloaded: str) -> None:
    """Require genuine serialized S3 custody and resumed native robot build."""
    pre = checkpointed_pre_save_evidence(
        first, ROBOT_MIDFLIGHT_SAVE_MARKER, ROBOT_MIDFLIGHT_SAVE_NAME)
    def receipt(content: str, marker: str, pattern: str) -> tuple[int, ...]:
        if content.count(marker) != 1:
            raise RuntimeError("S3 missing or duplicated native receipt: " + marker)
        matches = list(re.finditer(pattern, content))
        if len(matches) != 1:
            raise RuntimeError("S3 malformed native receipt: " + marker)
        return tuple(map(int, matches[0].groups()))

    cut = receipt(pre, "ROBOT_ENGINE_S2_MIDFLIGHT_POWER_CUT_1350 tick=",
        r"ROBOT_ENGINE_S2_MIDFLIGHT_POWER_CUT_1350 tick=(\d+) "
        r"magos=(\d+) priest=(\d+) observed_flying_robots=(\d+) "
        r"robot=(\d+) ghost=1 substation_custody=1")
    saved = receipt(pre, "ROBOT_ENGINE_S2_MIDFLIGHT_SAVE_REQUESTED_1360 tick=",
        r"ROBOT_ENGINE_S2_MIDFLIGHT_SAVE_REQUESTED_1360 tick=(\d+) "
        r"magos=(\d+) priest=(\d+) robot=(\d+) "
        r"ghost=1 substation_custody=1")
    observed = receipt(reloaded, "PASS ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_CUSTODY_1360 tick=",
        r"PASS ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_CUSTODY_1360 tick=(\d+) "
        r"magos=(\d+) priest=(\d+) robot=(\d+) "
        r"ghost=1 substation_held=1 "
        r"power_disconnected=true original_task_retained=true "
        r"original_request_retained=true built=0 native_build_event=0")
    restored = receipt(reloaded, "PASS ROBOT_ENGINE_S2_NATIVE_MIDFLIGHT_POWER_RECOVERY_1350 tick=",
        r"PASS ROBOT_ENGINE_S2_NATIVE_MIDFLIGHT_POWER_RECOVERY_1350 tick=(\d+) "
        r"magos=(\d+) priest=(\d+) ghost=1 native_build_event=0 "
        r"substation_mined=1 substation_rebuilt=1 original_task_retained=true "
        r"original_request_retained=true")
    event = receipt(reloaded, "ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT tick=",
        r"ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT tick=(\d+) "
        r"station=(\d+) robot=(\d+)")
    built = receipt(reloaded, "PASS ROBOT_ENGINE_S2_PHYSICAL_BUILD tick=",
        r"PASS ROBOT_ENGINE_S2_PHYSICAL_BUILD tick=(\d+) "
        r"magos=(\d+) magos_priest=(\d+) station=(\d+) "
        r"priest=(\d+) robot=(\d+) source_delta=1 network_delta=1 "
        r"ghost=0 hierarchy=direct-senior robot_event=on_robot_built_entity")
    if not (cut[3] > 0 and cut[4] > 0 and cut[0] == saved[0]
            and saved[0] <= observed[0] < restored[0] < event[0] <= built[0]
            and cut[1:3] == saved[1:3] == observed[1:3]
            == restored[1:] == built[1:3]
            and cut[4] == saved[3] == observed[3]
            and built[3] == event[1] and built[5] == event[2]
            and len({cut[1], cut[2], built[3], built[4], built[5]}) == 5
            and "ROBOT_ENGINE_S2_SOURCE_MINED" not in reloaded
            and "ROBOT_ENGINE_S2_REQUEST tick=" not in reloaded
            and "ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT" not in pre):
        raise RuntimeError("S3 reloaded Magos, task, ghost, substation, "
                           "robot event or exact physical build discrepant")


def verify_robot_frontier_native_1080_log(content: str) -> None:
    """Require real two-hop grid-connected frontier, receipts and per-builder debits."""
    source = re.search(
        r"ROBOT_FRONTIER_1080_SOURCE tick=(\d+) magos=(\d+) "
        r"priest=(\d+) port=(\d+) poles=(\d+) roboports=(\d+) "
        r"magos_poles=(\d+) magos_ports=(\d+) "
        r"senior_poles=(\d+) senior_ports=(\d+) "
        r"senior=(\d+) senior_priest=(\d+) mined=true "
        r"electric=(\d+) logistic=(\d+)", content)
    final = re.search(
        r"PASS ROBOT_FRONTIER_1080_POWERED_COVERAGE tick=(\d+) "
        r"magos=(\d+) priest=(\d+) source_port=(\d+) "
        r"final_port=(\d+) electric=(\d+) logistic=(\d+) "
        r"poles=(\d+) ports=(\d+) successive_port_progress=true "
        r"pole_delta=(\d+) port_delta=(\d+) "
        r"magos_poles=(\d+) magos_ports=(\d+) "
        r"senior_poles=(\d+) senior_ports=(\d+) "
        r"target_covered=true custody=physical-0338", content)
    receipts = list(re.finditer(
        r"ROBOT_FRONTIER_1080_RECEIPT tick=(\d+) "
        r"kind=(pole|port) unit=(\d+) grid=(\d+) "
        r"poles=(\d+) ports=(\d+)", content))
    segments = list(re.finditer(
        r"ROBOT_FRONTIER_1080_SEGMENT_PROGRESS tick=(\d+) "
        r"segment=(\d+) port=(\d+) "
        r"remaining_tiles=([\d.]+) previous_tiles=([\d.]+) "
        r"item_debit=0338-native-receipt", content))
    if not (source and final and receipts and segments):
        # Native 41629437530: a missing final two-port receipt currently
        # collapses to an opaque Python failure even when the real Factorio
        # log records the live 1076/0338 arbitration and custody state.
        # Preserve the hard failure and expose its actual last observations;
        # never turn a missing entity, item debit or receipt into a pass.
        observations = [
            line.strip() for line in content.splitlines()
            if ("ROBOT_FRONTIER_1080_BROKER_OBSERVE" in line
                or "ROBOT_FRONTIER_1080_TIMEOUT" in line
                or "ROBOT_FRONTIER_1080_SOURCE" in line
                or "ROBOT_FRONTIER_1080_RECEIPT" in line
                or "ROBOT_FRONTIER_1080_SEGMENT_PROGRESS" in line
                or "[TP-GROUND-RANK-TEST] ERROR " in line)
        ]
        latest = " | ".join(observations[-5:])[-3000:] if observations else "none"
        raise RuntimeError(
            "native two-roboport frontier evidence missing: "
            f"source={bool(source)} final={bool(final)} "
            f"physical_receipts={len(receipts)} coverage_segments={len(segments)}; "
            f"last_native_observations={latest}")
    s = tuple(map(int, source.groups()))
    f = tuple(map(int, final.groups()))
    # Native network IDs can renumber after ports merge; original electrical
    # grid, native receipt identities and actual target coverage may not.
    if not (s[0] < f[0] and s[1] == f[1] and s[2] == f[2]
            and s[3] == f[3] and s[3] != f[4]
            and s[12] == f[5] and s[12] > 0 and s[13] > 0 and f[6] > 0
            and len({s[1], s[2], s[3], s[10], s[11]}) == 5
            and s[4] == s[6] + s[8] and s[5] == s[7] + s[9]
            and 1 <= f[7] <= s[4] and 2 <= f[8] <= s[5]
            and f[7] == f[9] == f[11] + f[13]
            and f[8] == f[10] == f[12] + f[14]
            and 0 <= f[11] <= s[6] and 0 <= f[12] <= s[7]
            and 0 <= f[13] <= s[8] and 0 <= f[14] <= s[9]):
        raise RuntimeError("native frontier identities, grid or counted builder debits mismatch")
    pole_count = port_count = 0
    units = {s[1], s[2], s[3], s[10], s[11]}
    last_tick = s[0]
    port_receipts = []
    for m in receipts:
        tick, kind, unit, grid, poles, ports = m.groups()
        tick, unit, grid, poles, ports = map(int, (tick, unit, grid, poles, ports))
        if not (last_tick <= tick <= f[0] and grid == s[12]
                and unit not in units):
            raise RuntimeError("native frontier receipt order/grid/identity mismatch")
        units.add(unit)
        last_tick = tick
        pole_count += kind == "pole"
        port_count += kind == "port"
        if poles != pole_count or ports != port_count:
            raise RuntimeError("native frontier missing or duplicate physical receipt")
        if kind == "port":
            port_receipts.append((tick, unit))
    if (pole_count != f[7] or port_count != f[8]
            or f[4] != port_receipts[-1][1]
            or len(segments) != port_count):
        raise RuntimeError("native frontier did not prove each physical pole and port")
    previous_remaining = None
    for index, (segment, (receipt_tick, receipt_unit)) in enumerate(zip(segments, port_receipts), 1):
        tick, number, port, remaining, previous = segment.groups()
        tick, number, port = map(int, (tick, number, port))
        remaining, previous = float(remaining), float(previous)
        if not (tick == receipt_tick and port == receipt_unit
                and number == index and previous - remaining >= 5.0
                and remaining >= 0 and
                (previous_remaining is None or abs(previous - previous_remaining) < 0.1)):
            raise RuntimeError("native frontier segment did not prove successive physical coverage")
        previous_remaining = remaining

def verify_robot_frontier_native_1111_log(content: str) -> None:
    """Require the second ranked outpost to have a real native robot event.

    The 1080 parser independently proves two successive powered ports and
    counted 0338 construction. This gate links that exact original Magos,
    Senior and electrical grid to a *later* native robot-built Intermediate,
    its distinct living priest and the physically debited provider item.
    """
    source = re.search(
        r"ROBOT_FRONTIER_1080_SOURCE tick=(\d+) magos=(\d+) priest=(\d+) "
        r"[^\n]* senior=(\d+) senior_priest=(\d+) mined=true "
        r"electric=(\d+) logistic=(\d+)", content)
    coverage = re.search(
        r"PASS ROBOT_FRONTIER_1080_POWERED_COVERAGE tick=(\d+) "
        r"magos=(\d+) priest=(\d+) [^\n]*electric=(\d+) logistic=(\d+) ",
        content)
    events = list(re.finditer(
        r"ROBOT_FRONTIER_1111_NATIVE_ROBOT_EVENT tick=(\d+) "
        r"robot=(\d+) station=(\d+)", content))
    completions = list(re.finditer(
        r"PASS ROBOT_FRONTIER_1111_REMOTE_ROBOT_OUTPOST tick=(\d+) "
        r"magos=(\d+) magos_priest=(\d+) senior=(\d+) "
        r"senior_priest=(\d+) remote_station=(\d+) "
        r"remote_priest=(\d+) robot=(\d+) "
        r"physical_provider_delta=1 ghost=0 grid=(\d+) "
        r"paired_rank=intermediate", content))
    if not (source and coverage and len(events) == 1
            and len(completions) == 1):
        raise RuntimeError(
            "native robot-built Intermediate station receipt/event missing or duplicate")
    s = tuple(map(int, source.groups()))
    c = tuple(map(int, coverage.groups()))
    e = tuple(map(int, events[0].groups()))
    p = tuple(map(int, completions[0].groups()))
    if not (s[0] < c[0] < e[0] <= p[0]
            and p[0] - c[0] <= 15000
            and s[1:3] == c[1:3] == p[1:3]
            and s[3:5] == p[3:5]
            and s[5] == c[3] == p[8] and p[8] > 0
            and p[5] == e[2] and p[7] == e[1]
            and len({s[1], s[2], s[3], s[4],
                     p[5], p[6], p[7]}) == 7):
        raise RuntimeError(
            "native remote outpost timing, grid, rank, robot or priest identities disagree")



def verify_robot_frontier_seed_retry_1121_source(source: str | None = None) -> None:
    """Regression for real 2.0.77 queued surface deletion, not instant removal.

    A rejected natural-map candidate must be queued for deletion and retried
    on a later broker pulse. Never accept a ghost, scripted ore or a failed
    deletion as a valid seed; preserve the 64-attempt bound.
    """
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    start = source.index("local function robot_engine_s2_place_1071(state)")
    stop = source.index("local function robot_engine_s2_service_1071(state)", start)
    block = source[start:stop]
    required = (
        "state.robot_engine_s2_seed_search_1121=search",
        "if search.awaiting_delete then",
        "if game.tick-(search.delete_tick or game.tick)>600 then",
        "if search.offset>=64 then",
        "settings.seed=1071002+search.offset",
        "if not game.delete_surface(candidate) then",
        "search.offset=search.offset+1",
        "search.awaiting_delete=true",
        "search.delete_tick=game.tick",
        "state.robot_engine_s2_seed_search_1121=nil",
        "ore.valid and ore.amount>=2 and iron_product",
    )
    for item in required:
        if item not in block:
            raise AssertionError("native seed retry invariant missing: " + item)
    if ("ROBOT_FRONTIER_1121_REJECTED_SURFACE_NOT_DELETED" in block or
            "for offset=0,63 do" in block):
        raise AssertionError("native seed retry must await future-tick deletion")
    if not (block.index("if search.awaiting_delete then") <
            block.index("local candidate=game.create_surface") <
            block.index("if not game.delete_surface(candidate) then") <
            block.index("search.awaiting_delete=true")):
        raise AssertionError("native seed cleanup order changed")
    service = source[stop:stop+500]
    if "if not test then return end" not in service:
        raise AssertionError("pending seed search must yield without a test record")


def verify_robot_frontier_native_1120_log(content: str) -> None:
    """Require the native ore patch decrement and two ranked physical receipts."""
    identity = (r"magos=(\d+) magos_priest=(\d+) senior=(\d+) "
                r"senior_priest=(\d+) remote_station=(\d+) remote_priest=(\d+)")
    seed = re.findall(
        r"ROBOT_FRONTIER_1121_NATURAL_SEED_SELECTED tick=(\d+) "
        r"seed=(\d+) ore_x=(-?[0-9.]+) ore_y=(-?[0-9.]+) "
        r"natural_generated=true", content)
    objective = re.findall(
        r"ROBOT_FRONTIER_1120_NATURAL_ORE_OBJECTIVE tick=(\d+) " +
        identity + r" ore=iron-ore patch_before=(\d+) magos_before=(\d+) "
        r"natural_generated=true", content)
    # 1179: native Lua checks real source depletion, two exact inventory
    # receipts, empty carrier and Magos +1 BEFORE emitting this PASS.
    # Keep its separate source_depletion diagnostic in the log contract.
    completed = re.findall(
        r"PASS ROBOT_FRONTIER_1120_NATIVE_ORE_RETURN tick=(\d+) " +
        identity + r" ore=iron-ore patch_before=(\d+) patch_after=(\d+|false) "
        r"magos_before=(\d+) magos_after=(\d+) "
        r"source_depletion=[^\s]+ "
        r"hops=2 receipts=2 source=natural-ore custody=empty", content)
    remote = re.findall(
        r"PASS ROBOT_FRONTIER_1111_REMOTE_ROBOT_OUTPOST tick=(\d+) " +
        identity + r" robot=(\d+) physical_provider_delta=1 ghost=0 "
        r"grid=(\d+) paired_rank=intermediate", content)
    if (len(seed) != 1 or len(objective) != 1
            or len(completed) != 1 or len(remote) != 1):
        raise RuntimeError("native Method II generated-seed, outpost, objective or return missing/duplicate")
    seed_tick, seed_value, seed_x, seed_y = seed[0]
    o = tuple(map(int, objective[0]))
    c_raw = completed[0]
    c = tuple(int(v) if i != 8 else v for i, v in enumerate(c_raw))
    r = tuple(map(int, remote[0]))
    # Factorio invalidates a fully mined native resource entity.  The Lua
    # success marker is emitted only after its real mine, exact two receipts,
    # empty carrier and Magos +1 assertions; patch_after=false is that
    # legitimate invalidated-entity state, not a fabricated ore count.
    patch_after = c[8]
    depleted = (patch_after == "false" or
                (patch_after.isdecimal() and int(patch_after) == o[7] - 1))
    if not (int(seed_tick) < r[0]
            and 1071002 <= int(seed_value) <= 1071065
            and 70 <= float(seed_x) <= 101
            and 12 <= abs(float(seed_y)) <= 21
            and r[0] < o[0] < c[0]
            and o[1:7] == c[1:7] == r[1:7]
            and o[7] >= 2 and c[7] == o[7]
            and depleted
            and c[9] == o[8] and c[10] == o[8] + 1):
        raise RuntimeError("native Method II ore timing, original identity or physical inventory mismatch")


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


    # 1056: empty-station relocation alone is not positive evacuation proof.
    # Demand two separate native-mined fixture stacks, two real carrier
    # pickups and parent deposits, then counted original-priest relocation.
    stock = re.search(
        r"RELOCATION_ENGINE_STOCK_NATIVE_MINED[^\n]* source=(\d+)"
        r" wooden=1 iron=1 native_mines=2 native_transfers=2"
        r" fixture_not_ore_credit=true", content)
    finished = re.search(
        r"PASS RELOCATION_ENGINE_STOCK_EVACUATION[^\n]*"
        r" old_station=(\d+) worker=(\d+)"
        r" wooden=1 iron=1 journeys=2 held=0 source_removed=true", content)
    pickups = list(re.finditer(
        r"RELOCATION_ENGINE_STOCK_PICKUP[^\n]*"
        r" item=(wooden-chest|iron-chest) carrier=(\d+) held=1", content))
    deposits = list(re.finditer(
        r"RELOCATION_ENGINE_STOCK_DEPOSIT[^\n]*"
        r" item=(wooden-chest|iron-chest) worker=(\d+)"
        r" parent=(\d+)[^\n]* native_item_delta=1 held=0", content))
    if not (stock and finished and len(pickups) == len(deposits) == 2
            and [p.group(1) for p in pickups] == ["wooden-chest", "iron-chest"]
            and [d.group(1) for d in deposits] == ["wooden-chest", "iron-chest"]
            and stock.group(1) == finished.group(1) == match.group(1)
            == candidate_reservation.group(1)
            and all(p.group(2) == finished.group(2) for p in pickups)
            and all(d.group(2) == finished.group(2)
                    and d.group(3) == reservation.group(1) for d in deposits)
            and reservation.start() < stock.start() < preflight.start()
            < pickups[0].start() < deposits[0].start()
            < pickups[1].start() < deposits[1].start()
            < content.index("RELOCATION_ENGINE_MINED") < finished.start()
            < match.start()):
        raise RuntimeError("native engine did not prove two counted physical "
                           "stock evacuation journeys before priest rebind")



    # 1060: actual parent capacity refusal and recovery, with real native
    # mined fixture items rather than fabricated inventory or ore credit.
    congested = re.search(
        r"RELOCATION_ENGINE_STOCK_PARENT_CONGESTED tick=(\d+)"
        r" parent=(\d+) slots=(\d+) filler=stone-furnace"
        r" native_mines=(\d+) wooden=1 iron=0", content)
    blocked = re.search(
        r"RELOCATION_ENGINE_STOCK_PARENT_FULL_DENIED tick=(\d+)"
        r" parent=(\d+) worker=(\d+)"
        r" held_iron=1 parent_iron=0 filler=(\d+)", content)
    released = re.search(
        r"RELOCATION_ENGINE_STOCK_PARENT_SPACE_RESTORED tick=(\d+)"
        r" parent=(\d+) worker=(\d+)"
        r" held_iron=1 released_filler=1 native_transfer=true", content)
    congestion_pass = re.search(
        r"PASS RELOCATION_ENGINE_STOCK_CONGESTION tick=(\d+)"
        r" parent=(\d+) worker=(\d+)"
        r" blocked=1 recovered=1 filler=(\d+)"
        r" reserved_filler=1 parent_iron=1 held_iron=0", content)
    if not (congested and blocked and released and congestion_pass
            and int(congested.group(3)) >= 1
            and congested.group(3) == congested.group(4)
            == blocked.group(4) == congestion_pass.group(4)
            and all(m.group(2) == reservation.group(1)
                    for m in (congested, blocked, released, congestion_pass))
            and all(m.group(3) == finished.group(2)
                    for m in (blocked, released, congestion_pass))
            and deposits[0].start() < congested.start()
            < pickups[1].start() < blocked.start()
            < released.start() < deposits[1].start()
            < congestion_pass.start() < finished.start()
            and int(congested.group(1)) < int(blocked.group(1))
            < int(released.group(1)) < int(congestion_pass.group(1))):
        raise RuntimeError("native engine did not prove physical parent "
                           "congestion refusal, carried custody and recovery")

def verify_stock_carry_reload_log(before_save: str, after_reload: str) -> None:
    """Require the identical live stock hold and priest after an independent process."""
    pattern = (r" tick=(\d+) child=(\d+) parent=(\d+) worker=(\d+)"
               r" writ=(\d+) held=1 parent_received=0 child_iron=1")
    saved = re.search(re.escape(STOCK_CARRY_SAVE_MARKER) + pattern, before_save)
    loaded = re.search(re.escape(STOCK_CARRY_RELOAD_MARKER) + pattern, after_reload)
    pickup = re.search(
        r"RELOCATION_ENGINE_STOCK_PICKUP[^\n]*"
        r" item=wooden-chest carrier=(\d+) held=1", before_save)
    mined = re.search(
        r"RELOCATION_ENGINE_STOCK_NATIVE_MINED[^\n]* source=(\d+)",
        before_save)
    if not (saved and loaded and pickup and mined
            and saved.groups()[1:] == loaded.groups()[1:]
            and int(loaded.group(1)) > int(saved.group(1))
            and int(saved.group(2)) == int(mined.group(1))
            and int(saved.group(4)) == int(pickup.group(1))
            and len(set(saved.groups()[1:4])) == 3
            and pickup.start() < saved.start()
            and STOCK_CARRY_RELOAD_MARKER in after_reload
            and not re.search(r"RELOCATION_ENGINE_STOCK_DEPOSIT[^\n]*"
                              r" item=wooden-chest", before_save[:saved.end()])
            and (not re.search(r"RELOCATION_ENGINE_STOCK_DEPOSIT[^\n]*"
                               r" item=wooden-chest", after_reload)
                 or loaded.start() < re.search(
                     r"RELOCATION_ENGINE_STOCK_DEPOSIT[^\n]*"
                     r" item=wooden-chest", after_reload).start())):
        raise RuntimeError("independent Factorio process did not preserve "
                           "the original occupied-station carrier, priest, "
                           "writ and undelivered physical stack")


def checkpointed_pre_save_evidence(content: str, request_marker: str,
                                  save_name: str) -> str:
    """Keep only events emitted before the REAL engine blocking save begins.

    A scenario can request a save partway through a Factorio tick. Other
    independent handlers in that same tick can still complete real inventory
    transfers before Factorio starts serializing the world. Slicing at the
    request marker discards that physically persisted work. Never include
    events after the actual native save begins, or after it finishes.
    """
    lines = content.splitlines(keepends=True)
    requests = [i for i, line in enumerate(lines) if request_marker in line]
    save_start_text = ("Saving to " + pathlib.Path(save_name).stem
                       + " (blocking).")
    starts = [i for i, line in enumerate(lines)
              if "Info AppManager.cpp" in line and save_start_text in line]
    if len(requests) != 1 or len(starts) != 1 or starts[0] <= requests[0]:
        raise RuntimeError(
            "ambiguous native checkpoint request or blocking-save boundary")
    if any("Info AppManager.cpp" in line and "Saving to " in line
           for line in lines[requests[0]+1:starts[0]]):
        raise RuntimeError("another native save preceded the checkpoint")
    if not any("Info AppManagerStates.cpp" in line
               and "Saving finished" in line for line in lines[starts[0]+1:]):
        raise RuntimeError("checkpoint blocking save did not finish")
    return "".join(lines[:starts[0]])


def verify_ore_return_log(content: str) -> None:
    """Require naturally generated ore, isolated fixtures and three counted hops."""
    search = re.search(
        r"ORE_ENGINE_SITE_SEARCH[^\n]*"
        r" regions_checked=(\d+) natural_ore_candidates=(\d+)"
        r" chosen_region=(\d+) bounded=true", content)
    if not search or not (1 <= int(search.group(3)) <=
            int(search.group(1)) <= 4) or int(search.group(2)) < 1:
        raise RuntimeError("engine did not prove bounded natural-ore site search")
    isolated = re.search(
        r"ORE_ENGINE_SITE_ISOLATED[^\n]*"
        r" min_relocation_separation_sq=([0-9.]+) required_sq=([0-9.]+)"
        r" hierarchy_peer_reach=([0-9.]+)", content)
    if not isolated or float(isolated.group(1)) < float(isolated.group(2)) or (
            float(isolated.group(3)) <= 0 or
            float(isolated.group(2)) !=
            math.ceil(float(isolated.group(3)) + 128) ** 2):
        raise RuntimeError("ore fixture intruded on physical station-recovery authority")
    if search.start() >= isolated.start():
        raise RuntimeError("ore site search was not observed before isolation")
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
        r"ORE_ENGINE_HOP[^\n]*hop=(\d+) from=(\d+) to=(\d+) counted=1"
        r" receipt_before=(\d+) receipt_after=(\d+)",
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
    if [tuple(map(int, hop[:3])) for hop in hops] != expected:
        raise RuntimeError("engine skipped, reordered or fabricated a physical hop")
    if any(int(h[4]) != int(h[3])+1 for h in hops):
        raise RuntimeError("engine did not prove exact physical inventory receipt deltas")
    if not (target.start() < route.start() < mined.start()
            < content.index("ORE_ENGINE_HOP") < finished.start()):
        raise RuntimeError("engine ore return markers out of physical order")



def verify_machine_integration_source_0994(source: str | None = None) -> None:
    """Fail closed if the second engine leg loses physical machine custody.

    These guards do not substitute for a real Factorio 2.0.77 run; they
    prevent an innocuous-looking edit from converting its receipt into a
    synthetic stock grant, or silently falling back to direct priest mining.
    """
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    required = (
        "local function ore_engine_machine_prepare_0994(test,chain)",
        "local function ore_engine_machine_wait_0994(test,chain,mission)",
        'name="iron-ore",type="resource",position=test.ore_position,radius=4',
        "surface.can_place_entity(spec)",
        "surface.create_entity(spec)",
        "math.abs(ore.position.x-pos.x)<1",
        "math.abs(ore.position.y-pos.y)<1",
        "x=math.floor(drop.x)+0.5",
        "y=math.floor(drop.y)+0.5",
        'fuel.insert{name="coal",count=5}==5',
        "test.machine_0994={",
        "drill.unit_number==machine.drill_unit",
        "chest.unit_number==machine.chest_unit",
        "ORE_ENGINE_COURIER.drill_source_receipt_0991(",
        "chain[4],mission,machine.drill_unit,machine.chest_unit)",
        "ORE_ENGINE_MACHINE_RECEIPT_PROVENANCE_REJECTED",
        "proof.source_before>=1",
        "remaining<machine.natural_before",
        "ORE_ENGINE_MACHINE_RANKED_DEPOSIT_DIVERTED",
        'test.phase="machine-wait"',
        'test.phase="machine-courier"',
        "ORE_ENGINE_MACHINE_FALLBACK_TO_DIRECT_MINING_FORBIDDEN",
        "local machine_terminal_pickup=test.machine_courier and idx==4",
        "local hop=courier.hop_index or 1",
        "local idx=5-hop",
        "courier.source_station_unit==physical_source.station.unit_number",
        "and source_matches and before and before>=1",
        "local relay_pickup=idx and idx>=2 and idx<=3",
        "courier.drill_receipt_claimed_0991==true",
        "and after==before-1",
        'courier.source_kind_0991=="drill-output"',
        "courier.drill_receipt_claimed_0991",
        "test.machine_receipt_count_0994>=1",
        "ORE_ENGINE_MACHINE_0528_DEPOSIT",
        "ORE_ENGINE_MACHINE_PICKUP",
        "ORE_ENGINE_MACHINE_HOP",
        "PASS ORE_ENGINE_MACHINE_MAGOS_RETURN",
        "M.verify_magos_receipt_1159(",
        "test.machine_magos_count_before=mission.delivered_to_magos_count or 0",
        "total>=baseline+1",
        "local ledger=courier.receipts_0982",
        "rec.destination_after==rec.destination_before+1",
        "tonumber(magos_ore_count)==last.destination_after",
        "test.natural_return_verified=true",
    )
    for invariant in required:
        if invariant not in source:
            raise AssertionError("physical machine-return invariant missing: " +
                                 invariant)
    # The 1159 final-receipt helper also checks drill provenance, but
    # a second check elsewhere must never mask a weakened FIRST-HOP
    # terminal pickup. Inspect this actual 1004 guard in its own block.
    terminal_start = source.index(
        "local machine_terminal_pickup=test.machine_courier and idx==4")
    terminal_end = source.index(
        "local relay_pickup=idx and idx>=2 and idx<=3",
        terminal_start)
    terminal_guard = source[terminal_start:terminal_end]
    if ('courier.drill_receipt_claimed_0991==true' not in terminal_guard
            or 'courier.source_kind_0991=="drill-output"' not in terminal_guard):
        raise AssertionError(
            "physical machine-return invariant missing: exact terminal drill receipt")
    section = source[source.index(
        "local function ore_engine_machine_prepare_0994(test,chain)"):
        source.index("local function ore_engine_service(state)")]
    if ('create_entity{name="iron-ore"' in section
            or 'insert{name="iron-ore"' in section
            or "ore.mine(" in section):
        raise AssertionError("machine acceptance manufactures ore or bypasses drill")
    if "mission.return_courier_0837=nil" in section:
        raise AssertionError("machine acceptance erased prior Magos courier custody")
    if source.index('test.phase="machine-wait"') > source.index(
            "if test.phase==\"machine-wait\" then"):
        raise AssertionError("machine receipt must be awaited after real drill setup")


def verify_machine_return_log_0994(content: str) -> None:
    """Require a second, genuinely drill-sourced three-hop Magos return."""
    prepared = re.search(
        r"ORE_ENGINE_MACHINE_PREPARED[^\n]* drill=(\d+) chest=(\d+)"
        r" natural_before=(\d+) physical_fixture_coal=5", content)
    deposited = re.search(
        r"ORE_ENGINE_MACHINE_0528_DEPOSIT[^\n]* drill=(\d+) chest=(\d+)"
        r" receiver_debit=(\d+) station_deposit=(\d+)"
        r" natural_before=(\d+) natural_after=(\d+) receipt_verified=true",
        content)
    pickup = re.search(
        r"ORE_ENGINE_MACHINE_PICKUP[^\n]* drill=(\d+) chest=(\d+)"
        r" physical_station_debit=1 held=1", content)
    hops = re.findall(
        r"ORE_ENGINE_MACHINE_HOP[^\n]*hop=(\d+) from=(\d+) to=(\d+)"
        r" counted=1 receipt_before=(\d+) receipt_after=(\d+)", content)
    finished = re.search(
        r"PASS ORE_ENGINE_MACHINE_MAGOS_RETURN[^\n]*"
        r"machine_receipt_verified=true physical_hops=3"
        r" magos_received_total=(\d+) baseline=(\d+)"
        r" held=0 original_drill=(\d+)", content)
    route = re.search(
        r"ORE_ENGINE_ROUTE_VERIFIED[^\n]*"
        r" junior=(\d+) intermediate=(\d+) senior=(\d+) magos=(\d+)",
        content)
    if not (prepared and deposited and pickup and finished and route
            and len(hops)==3):
        raise RuntimeError("engine did not prove a second machine-produced Magos return")
    drill, chest, before = map(int, prepared.groups())
    pd, pc, debit, credit, initial, after = map(int, deposited.groups())
    if not (drill>0 and chest>0 and drill!=chest
            and (pd, pc)==(drill, chest)
            and tuple(map(int, pickup.groups()))==(drill, chest)
            and int(finished.group(3))==drill
            and int(finished.group(2))>=1
            and int(finished.group(1))>=int(finished.group(2))+1
            and before==initial and before>after>=0
            and debit==credit>=1):
        raise RuntimeError("drill identity, natural depletion or 0528 deposit invalid")
    junior, intermediate, senior, magos = map(int, route.groups())
    expected = [(1, junior, intermediate), (2, intermediate, senior),
                (3, senior, magos)]
    if [tuple(map(int, h[:3])) for h in hops]!=expected:
        raise RuntimeError("machine-produced ore skipped a ranked physical hop")
    if any(int(h[4])!=int(h[3])+1 for h in hops):
        raise RuntimeError("machine-produced ore inventory receipt not conserved")
    if not (content.index("PASS ORE_ENGINE_COUNTED_MAGOS_RETURN") <
            prepared.start() < deposited.start() < pickup.start() <
            content.index("ORE_ENGINE_MACHINE_HOP") < finished.start()):
        raise RuntimeError("machine output was credited before physical custody")


def verify_native_engine_source_1014(source: str | None = None) -> None:
    """The native engine probe must use real 0338/0528 receipts and inventories."""
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    required = (
        'local ORE_ENGINE_NATIVE_1014=SAVE_RELOAD_SMOKE and require(',
        "local function ore_engine_native_service_1014(state)",
        'drill.mine{inventory=stock,raise_destroy=true}',
        'receiver.mine{inventory=stock,raise_destroy=true}',
        'stock.get_item_count("burner-mining-drill")==drill_before+1',
        'stock.get_item_count("wooden-chest")==chest_before+1',
        'stock.get_item_count("iron-ore")~=iron_before+iron',
        'mission.remote_drill_1011~=nil',
        'ORE_ENGINE_NATIVE_1014.service_pair(magos)',
        'receipt.request_value==task.request',
        'receipt.request_value==task.receiver_request',
        'receipt.built_entity.unit_number==task.drill_unit',
        'receipt.built_entity.unit_number==task.receiver_unit',
        'stock.get_item_count("burner-mining-drill")==native.drill_stock-1',
        'stock.get_item_count("wooden-chest")==native.chest_stock-1',
        'receipt.authority=="physical-machine-fuel-0528"',
        'proof.source_after==proof.source_before-proof.count',
        'proof.destination_after==proof.destination_before+proof.count',
        'ore_engine_native_service_1014(state)',
        'ORE_ENGINE_NATIVE_CONSTRUCTION_FUEL_AND_ORE_RETURN_TIMEOUT',
        'PASS ORE_ENGINE_NATIVE_0338_0528',
        'ORE_ENGINE_COURIER.service(magos)',
        'PASS ORE_ENGINE_NATIVE_MACHINE_MAGOS_RETURN',
    )
    for guard in required:
        if guard not in source:
            raise AssertionError("native physical engine guard missing: " + guard)
    section = source[source.index(
        "local function ore_engine_native_service_1014(state)"):
        source.index("-- CI-only preliminary Method I five-station reversal fixture.")]
    for forbidden in ('create_entity{name="iron-ore"',
                      'insert{name="iron-ore",count=1}',
                      'mission.return_courier_0837=nil'):
        if forbidden in section:
            raise AssertionError("native fixture bypasses physical ore custody: " +
                                 forbidden)


def verify_native_engine_log_1014(content: str) -> None:
    """Require new physical entities built from recovered counted station stock."""
    recovered = re.search(
        r"ORE_ENGINE_NATIVE_RECOVERED[^\n]* drill=(\d+) receiver=(\d+)"
        r" drill_item_delta=1 chest_item_delta=1"
        r" receiver_iron_transferred=(\d+) fixture_coal=(\d+)"
        r" no_ore_created=true", content)
    drill = re.search(
        r"ORE_ENGINE_NATIVE_0338_DRILL[^\n]* built=(\d+) recovered=(\d+)"
        r" physical_item_debit=1", content)
    receiver = re.search(
        r"ORE_ENGINE_NATIVE_0338_RECEIVER[^\n]* built=(\d+) recovered=(\d+)"
        r" physical_item_debit=1", content)
    finished = re.search(
        r"PASS ORE_ENGINE_NATIVE_0338_0528[^\n]*"
        r" drill=(\d+) receiver=(\d+)"
        r" drill_item_debit=1 receiver_item_debit=1"
        r" fuel_station_debit=(\d+) fuel_drill_credit=(\d+)"
        r" fixture_coal=(\d+) physical_builder=true physical_fuel=true",
        content)
    returned = re.search(
        r"PASS ORE_ENGINE_NATIVE_MACHINE_MAGOS_RETURN[^\n]*"
        r" drill=(\d+) receiver=(\d+)"
        r" physical_hops=(\d+) counted_magos_total=(\d+)"
        r" native_machine_source=true no_synthetic_ore=true", content)
    old = re.search(r"PASS ORE_ENGINE_MACHINE_MAGOS_RETURN", content)
    if not (old and recovered and drill and receiver and finished and returned):
        raise RuntimeError("native construction, fuel or counted ore return proof missing")
    old_drill, old_receiver, recovered_ore, fixture_coal = map(
        int, recovered.groups())
    built_drill, source_drill = map(int, drill.groups())
    built_receiver, source_receiver = map(int, receiver.groups())
    final_drill, final_receiver, coal_debit, coal_credit, final_fixture = map(
        int, finished.groups())
    return_drill, return_receiver, hops, magos_total = map(int, returned.groups())
    if not (return_drill==built_drill and return_receiver==built_receiver
            and hops==3 and magos_total>=3
            and finished.start()<returned.start()
            and old_drill>0 and old_receiver>0 and old_drill!=old_receiver
            and source_drill==old_drill and source_receiver==old_receiver
            and built_drill>0 and built_receiver>0
            and built_drill not in (old_drill, old_receiver)
            and built_receiver not in (old_drill, old_receiver, built_drill)
            and (final_drill, final_receiver)==(built_drill, built_receiver)
            and recovered_ore>=0 and 0<=fixture_coal<=5
            and final_fixture==fixture_coal
            and coal_debit==coal_credit>=1
            and old.start()<recovered.start()<drill.start()<
                receiver.start()<finished.start()):
        raise RuntimeError("native build identity, inventory or fuel custody invalid")


def verify_ore_carry_reload_log(before_save: str, after_reload: str) -> None:
    """Require the same physically mined item, priest and route after a new process."""
    pattern = (r"[^\n]* source=(\d+) destination=(\d+) priest=(\d+)"
               r" held=1 hop=1 prior_receipts=0")
    saved = re.search(re.escape(ORE_CARRY_SAVE_MARKER) + pattern, before_save)
    loaded = re.search(re.escape(ORE_CARRY_RELOAD_MARKER) + pattern, after_reload)
    if not (saved and loaded and saved.groups() == loaded.groups()
            and len(set(saved.groups())) == 3):
        raise RuntimeError("independent engine did not preserve the same "
                           "physical ore hold, carrier identity and upstream route")


def verify_drill_first_process_boundary_0986(source: str | None = None) -> None:
    """Require late attach before the first physical save, never after reload.

    The initial game save was created before the isolated CI control flag
    existed; Factorio will not replay on_init when that save is loaded.
    """
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    prepare = "drill_engine_prepare_0985(state)"
    guard = "drill_engine_first_process_attach_0986(state)"
    start = source.index("local function drill_engine_first_process_attach_0986(state)")
    pulse = source.index("local function pulse()")
    if source.count(prepare) != 3 or source.count(guard) != 2:
        raise AssertionError("drill must prepare on_init and once on the first live tick")
    if not (source.index("local function drill_engine_prepare_0985(state)") <
            start < pulse < source.rindex(guard)):
        raise AssertionError("drill first-process guard must precede live pulse")
    condition = source[start:source.index("\nend", start)]
    for clause in (
        "return SAVE_RELOAD_SMOKE and not state.drill_engine_0985",
        "and not state.save_reload_requested",
        "and not state.save_reload_verified",
        "and not state.drill_engine_verified_0985",
        'rawget(_G,"TP_CI_COURIER_RELOAD_PROBE")~=true',
    ):
        if clause not in condition:
            raise AssertionError("unsafe drill preparation after reload boundary: " + clause)
    stage = source[source.rindex(guard):source.index(
        'if rawget(_G,"TP_CI_COURIER_RELOAD_PROBE")==true',
        source.rindex(guard))]
    if prepare not in stage or 'DRILL_ENGINE_0986_LATE_ATTACH' not in stage:
        raise AssertionError("first live smoke tick does not prepare real drill")


def verify_drill_natural_patch_discovery_0987(source: str | None = None) -> None:
    """Guard broad natural-ore discovery and physical receiver geometry.

    The real Factorio runtime decides whether a given ore, drill and chest
    actually work; this source regression rejects narrowed/synthetic search
    or an unsnapped, nonphysical output receiver before launching the engine.
    """
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    start = source.index("local function drill_engine_prepare_0985(state)")
    end = source.index("\nend", start)
    block = source[start:end]
    centers = [(int(x), int(y)) for x, y in
               re.findall(r"\{x=(-?\d+),y=(-?\d+)\}", block)]
    if len(set(centers)) < 20:
        raise AssertionError("drill search narrowed below twenty distinct regions")
    if not all(any(x * sx > 0 and y * sy > 0 for x, y in centers)
               for sx in (-1, 1) for sy in (-1, 1)):
        raise AssertionError("drill search omits a map quadrant")
    required = (
        "surface.request_to_generate_chunks(center,3)",
        "surface.force_generate_chunk_requests()",
        'local ores=surface.find_entities_filtered{\n      name="iron-ore",type="resource",',
        "ore.valid and not in_fixture and ore.amount and ore.amount>=20",
        "base.x>=-28 and base.x<=220",
        "base.y>=-36 and base.y<=40",
        "for dx=-1,1 do for dy=-1,1 do",
        "surface.can_place_entity(spec)",
        "surface.create_entity(spec)",
        'local correct_target=target and target.valid',
        'and target.name=="iron-ore"',
        'if not target then target_missing=target_missing+1',
        'initial_target_unit=chosen_drill.mining_target and',
        '" target_missing="..target_missing',
        "x=math.floor(drop.x)+0.5",
        "y=math.floor(drop.y)+0.5",
        'name="wooden-chest",position=chest_pos,force=force',
        'fuel.insert{name="coal",count=5}==5',
        "DRILL_ENGINE_0987_SITE_SEARCH regions=",
        "DRILL_ENGINE_0985_NO_NATURAL_PATCH_OR_BUILDABLE_RECEIVER:",
        "state.drill_engine_0985={",
    )
    for condition in required:
        if condition not in block:
            raise AssertionError("drill physical source/receiver invariant missing: " +
                                 condition)
    if 'surface.create_entity{name="iron-ore"' in block or "amount=10000" in block:
        raise AssertionError("drill test manufactures its alleged natural ore")


def verify_drill_activation_0989(source: str | None = None) -> None:
    """Guard real ore footprint, post-fueling target and counted engine output."""
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    required = (
        "math.abs(base.x-pos.x)<1",
        "math.abs(base.y-pos.y)<1",
        "footprint_has_ore and surface.can_place_entity(spec)",
        "if (not target or correct_target) and drop then",
        "local function drill_engine_observe_target_0989(state)",
        'if target.name~="iron-ore" then',
        "record.activated_target_tick=game.tick",
        "record.activated_target_tick>record.created_tick",
        "DRILL_ENGINE_0989_TARGET_NEVER_ACTIVATED",
        "drill_engine_observe_target_0989(state)",
        "remaining<record.ore_before and mined>0",
        "record.ore_before-remaining>=mined",
        "DRILL_ENGINE_0985_INDEPENDENT_RELOAD",
        "local function drill_engine_diagnostic_0990(state,reason)",
        "DRILL_ENGINE_0990_LIVE_DIAG tick=",
        'drill_engine_diagnostic_0990(state,"target-never-activated")',
        'drill_engine_diagnostic_0990(state,"no-counted-real-output")',
        'age==120 or age==600 or age==1200',
    )
    for invariant in required:
        if invariant not in source:
            raise AssertionError("drill physical activation invariant missing: " +
                                 invariant)
    pulse = source[source.index("local function pulse()"):]
    if pulse.index("drill_engine_observe_target_0989(state)") > pulse.index(
            "drill_engine_verify_0985(state)"):
        raise AssertionError("live observation must precede engine proof")


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


def verify_reversal_audit_import_boundary(source: str | None = None) -> None:
    """0894: the fourth physical depot must audit in a live Factorio tick.

    A runtime require() aborts the engine even after all four real station
    items have been deposited. Only startup-parsed modules may be used by
    the on_tick recovery service; never replace the four-depot proof with
    a synthetic success marker.
    """
    if source is None:
        source = (pathlib.Path(__file__).resolve().parents[1] /
                  "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                  ).read_text(encoding="utf-8")
    module = 'require("scripts.core.station_starvation_rebuild_0867")'
    startup = ('local REVERSAL_REBUILD_0867=SAVE_RELOAD_SMOKE and ' +
               module + ' or nil')
    audit = 'local audit=REVERSAL_REBUILD_0867'
    finish = 'test.phase="four-depot-audited"'
    if (source.count(module) != 1 or source.count(startup) != 1 or
            source.count(audit) != 1 or source.count(finish) != 1 or
            not source.index(startup) < source.index(audit) <
                source.index(finish)):
        raise AssertionError("fourth-depot audit must use startup-parsed module")
    stage = source[source.index(audit):source.index(finish) + len(finish) + 280]
    if ('local proof,reason=audit.audit(magos,rec)' not in stage or
            'not(proof and proof.stage_count==4)' not in stage or
            'REVERSAL_ENGINE_FOUR_DEPOT_AUDIT_FAILED:' not in stage or
            'PASS REVERSAL_ENGINE_FOUR_DEPOT_AUDIT' not in stage):
        raise AssertionError("fourth-depot physical audit must remain strict")


def verify_reversal_outbound_log(content: str) -> None:
    """0907: require the actual four-depot audit and 120-tick escrow."""
    audited = re.search(
        r"PASS REVERSAL_ENGINE_FOUR_DEPOT_AUDIT tick=(\d+)[^\n]*"
        r"independent_real_items=4 original_priests=4", content)
    carried = re.search(
        r"PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_PICKUP tick=(\d+)[^\n]*"
        r"original_senior=(\d+) original_priest=(\d+)"
        r" source_before=1 source_after=0 carrier_before=0 carrier_after=1"
        r" other_depots=3 ghost_preserved_or_reconciled=true"
        r" station_not_built=true ghost_reconciled_0896=(true|false)"
        r" owned_ghost_replaced_0899=(true|false)", content)
    if not (audited and carried and audited.start() < carried.start()
            and int(carried.group(1))-int(audited.group(1))>=120
            and int(carried.group(2))>0 and int(carried.group(3))>0
            and not (carried.group(5)=="true" and carried.group(4)!="true")):
        raise RuntimeError("engine did not prove escrowed physical Senior outbound pickup")


def verify_reversal_outbound_transit_log(content: str) -> None:
    """0907: same Senior item must reach the ghost by original Magos walking."""
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_PICKUP tick=(\d+)[^\n]*"
        r"original_senior=(\d+) original_priest=(\d+)", content)
    arrived = re.search(
        r"PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_TRANSIT tick=(\d+)[^\n]*"
        r"original_senior=(\d+) original_priest=(\d+)"
        r" magos_priest=(\d+) held=1 source=0 prior_depots=3"
        r" distance_sq=([0-9.]+) ghost_unit=(\d+)", content)
    if not (pickup and arrived and pickup.start()<arrived.start()
            and int(arrived.group(1))>=int(pickup.group(1))
            and arrived.group(2)==pickup.group(2)
            and arrived.group(3)==pickup.group(3)
            and len({arrived.group(3),arrived.group(4)})==2
            and float(arrived.group(5))<=25
            and int(arrived.group(6))>0):
        raise RuntimeError("engine did not prove Magos carried Senior item to ghost")


def verify_reversal_outbound_build_log(content: str) -> None:
    """0908: original Senior priest must own a NEW physically built station."""
    arrived = re.search(
        r"PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_TRANSIT tick=(\d+)[^\n]*"
        r"original_senior=(\d+) original_priest=(\d+)", content)
    built = re.search(
        r"PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_BUILD tick=(\d+)"
        r" original_senior=(\d+) rebuilt_senior=(\d+)"
        r" original_priest=(\d+) source=0 carrier=0 prior_depots=3"
        r" ghost=0 hierarchy=magos-to-original-senior", content)
    if not (arrived and built and arrived.start() < built.start()
            and int(built.group(1)) > int(arrived.group(1))
            and built.group(2) == arrived.group(2)
            and built.group(4) == arrived.group(3)
            and built.group(3) != built.group(2)
            and int(built.group(3)) > 0):
        raise RuntimeError("engine did not prove original Senior physical rebuild and pairing")


def verify_reversal_intermediate_ghost_log(content: str) -> None:
    """0911: original Senior owns a real next-rank ghost; items stay counted."""
    built = re.search(
        r"PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_BUILD tick=(\d+)"
        r" original_senior=(\d+) rebuilt_senior=(\d+)"
        r" original_priest=(\d+)", content)
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_GHOST tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)"
        r" ghost_unit=(\d+) intermediate_depot=1 junior_depots=2"
        r" carrier=0 rank=3-to-2 physical_build_not_yet_claimed=true",
        content)
    # Factorio may complete the Senior build and reserve its child ghost in
    # the SAME tick. The ordered distinct physical engine receipts, not a
    # fabricated one-tick delay, establish sequencing.
    if not (built and ghost and built.start() < ghost.start()
            and int(ghost.group(1)) >= int(built.group(1))
            and ghost.group(2) == built.group(3)
            and ghost.group(3) == built.group(4)
            and ghost.group(3) != ghost.group(4)
            and int(ghost.group(4)) > 0
            and int(ghost.group(5)) > 0
            and int(ghost.group(6)) > 0):
        raise RuntimeError("engine did not prove a conserved original-Intermediate ghost reservation")


def verify_reversal_intermediate_pickup_log(content: str) -> None:
    """0913: real original Senior returns to Magos and carries counted item."""
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_GHOST tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)", content)
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_PICKUP tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)"
        r" source_before=1 source_after=0 carrier_before=0 carrier_after=1"
        r" junior_depots=2 distance_sq=([\d.]+)"
        r" original_priest_staged=true", content)
    if not (ghost and pickup and ghost.start() < pickup.start()
            and int(pickup.group(1)) > int(ghost.group(1))
            and pickup.group(2) == ghost.group(2)
            and pickup.group(3) == ghost.group(3)
            and pickup.group(4) == ghost.group(4)
            and pickup.group(5) == ghost.group(5)
            and float(pickup.group(6)) <= 25):
        raise RuntimeError("engine did not prove physical Intermediate depot pickup")


def verify_reversal_intermediate_transit_log(content: str) -> None:
    """0915: the same counted Intermediate item must reach its owned ghost."""
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_GHOST tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)"
        r" ghost_unit=(\d+)", content)
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_PICKUP tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)", content)
    transit = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_TRANSIT tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)"
        r" held=1 source=0 junior_depots=2 distance_sq=([\d.]+)"
        r" ghost_unit=(\d+) original_priest_staged=true", content)
    if not (ghost and pickup and transit
            and ghost.start() < pickup.start() < transit.start()
            and int(transit.group(1)) >= int(pickup.group(1)) + 120
            and transit.group(2) == pickup.group(2) == ghost.group(2)
            and transit.group(3) == pickup.group(3) == ghost.group(3)
            and transit.group(4) == pickup.group(4) == ghost.group(4)
            and transit.group(5) == pickup.group(5) == ghost.group(5)
            and transit.group(7) == ghost.group(6)
            and float(transit.group(6)) <= 25):
        raise RuntimeError("engine did not prove conserved Intermediate physical outward transit")


def verify_reversal_intermediate_build_log(content: str) -> None:
    """0916: exact original-priest Intermediate constructed from counted cargo."""
    transit = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_TRANSIT tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)", content)
    build = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_BUILD tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)"
        r" rebuilt_intermediate=(\d+) original_intermediate_station=(\d+)"
        r" source=0 carrier=0 junior_depots=2 distance_sq=([\d.]+)"
        r" ghost=0 hierarchy=senior-to-original-intermediate", content)
    if not (transit and build and transit.start() < build.start()
            and int(build.group(1)) > int(transit.group(1))
            and all(build.group(n)==transit.group(n) for n in (2,3,4,5))
            and int(build.group(6))>0
            and int(build.group(7))>0
            and build.group(6)!=build.group(7)
            and float(build.group(8))<0.01):
        raise RuntimeError("engine did not prove original Intermediate physical build and priest pairing")



def verify_reversal_first_junior_ghost_log(content: str) -> None:
    """0919: engine-observed original Junior ghost, two untouched real depots."""
    build = re.search(
        r"PASS REVERSAL_ENGINE_INTERMEDIATE_BUILD tick=(\d+)"
        r" rebuilt_senior=(\d+) original_senior_priest=(\d+)"
        r" original_intermediate_priest=(\d+) child_writ=(\d+)"
        r" rebuilt_intermediate=(\d+)", content)
    junior = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_GHOST tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" junior_depots=2 carrier=0 rank=2-to-1"
        r" physical_build_not_yet_claimed=true", content)
    if not (build and junior and build.start() < junior.start()
            and int(junior.group(1)) >= int(build.group(1)) + 120
            and junior.group(2) == build.group(6)
            and junior.group(3) == build.group(4)
            and all(int(junior.group(i)) > 0 for i in (2, 3, 4, 5, 6))
            and junior.group(4) != junior.group(3)
            and junior.group(5) != build.group(5)):
        raise RuntimeError("engine did not prove original first-Junior ghost and two protected real items")


def verify_reversal_first_junior_pickup_log(content: str) -> None:
    """0968: original Intermediate debits exactly one Junior item at the Magos."""
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_GHOST tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" junior_depots=2 carrier=0 rank=2-to-1"
        r" physical_build_not_yet_claimed=true", content)
    # The first physical depot identifies the real original Magos station.
    # It must precede the Junior ghost and the counted debit.
    depot = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT tick=(\d+)"
        r" old_station=(\d+) priest=(\d+)"
        r" stored_junior=1 magos=(\d+)"
        r" further_stages_not_claimed=true", content)
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+)"
        r" source_before=1 source_after=0 carrier_before=0 carrier_after=1"
        r" second_depot=1 distance_sq=([\d.]+)"
        r" pickup_distance_sq=([\d.]+)"
        r" pickup_station=(\d+) pickup_tick=(\d+)"
        r" original_priest_staged=true", content)
    # 0966's real 0824 cargo record certifies distance AT item debit.
    # The current carrier distance may exceed five tiles after departure;
    # it is neither the pickup distance nor evidence of remote withdrawal.
    if not (depot and ghost and pickup
            and depot.start() < ghost.start() < pickup.start()
            and int(depot.group(1)) <= int(ghost.group(1))
            and int(pickup.group(1)) >= int(ghost.group(1)) + 120
            and all(pickup.group(i) == ghost.group(i) for i in (2, 3, 4, 5))
            and pickup.group(3) != pickup.group(4)
            and int(pickup.group(8)) == int(depot.group(4))
            and int(pickup.group(8)) > 0
            and 0 <= float(pickup.group(7)) <= 25
            and int(ghost.group(1)) <= int(pickup.group(9))
            <= int(pickup.group(1))):
        raise RuntimeError("engine did not prove first Junior Magos pickup, "
                           "original Intermediate carrier and protected second depot")


def verify_reversal_first_junior_transit_log(content: str) -> None:
    """0935: engine-observed first-Junior cargo and original priest at exact ghost."""
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+)", content)
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_GHOST tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)", content)
    transit = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+)"
        r" held=1 source=0 second_depot=1 distance_sq=([\d.]+)"
        r" ghost_unit=(\d+) original_priest_staged=true", content)
    if not (ghost and pickup and transit
            and ghost.start() < pickup.start() < transit.start()
            and int(transit.group(1)) >= int(pickup.group(1)) + 120
            and all(transit.group(n) == pickup.group(n) == ghost.group(n)
                    for n in (2, 3, 4, 5))
            and transit.group(7) == ghost.group(6)
            and float(transit.group(6)) <= 25):
        raise RuntimeError("engine did not prove original first-Junior item "
                           "physically carried from Magos to the exact owned ghost")


def verify_reversal_first_junior_build_log(content: str) -> None:
    """0936: physical Junior station built exactly once with preserved priest."""
    transit = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+)", content)
    built = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_BUILD tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+)"
        r" rebuilt_junior=(\d+) original_junior_station=(\d+)"
        r" source=0 carrier=0 second_depot=1 distance_sq=([\d.]+)"
        r" ghost=0 hierarchy=intermediate-to-original-junior", content)
    if not (transit and built and transit.start() < built.start()
            and int(built.group(1)) > int(transit.group(1))
            and all(built.group(n) == transit.group(n) for n in (2, 3, 4, 5))
            and int(built.group(6)) > 0 and int(built.group(7)) > 0
            and built.group(6) != built.group(7)
            and float(built.group(8)) < 0.01):
        raise RuntimeError("engine did not prove real first Junior station "
                           "construction, original priest reattachment "
                           "and protected second Junior depot")



def verify_reversal_second_junior_ghost_log(content: str) -> None:
    """0943: first Junior built before the real second-peer ghost is reserved."""
    built = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_BUILD tick=(\d+)"
        r".*?original_junior_priest=(\d+)", content)
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_GHOST tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" first_depot=0 second_depot=1 original_second_staged=true", content)
    if not (built and ghost and built.start() < ghost.start()
            and int(ghost.group(1)) > int(built.group(1))
            and ghost.group(2) == built.group(2)
            and int(ghost.group(3)) > 0
            and ghost.group(3) != ghost.group(2)
            and int(ghost.group(4)) > 0
            and int(ghost.group(5)) > 0):
        raise RuntimeError("Factorio did not prove the original first Junior "
                           "built before the second peer's real ghost with "
                           "its separate unspent depot and original priest")

def verify_reversal_second_junior_pickup_log(content: str) -> None:
    """0944: original first Junior physically debits the distinct second depot."""
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_GHOST tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" first_depot=0 second_depot=1 original_second_staged=true", content)
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+)"
        r" first_depot=0 second_depot=0 carrier=1 distance_sq=([\d.]+)"
        r" original_second_staged=true", content)
    if not (ghost and pickup and ghost.start()<pickup.start()
            and int(pickup.group(1))>=int(ghost.group(1))+120
            and all(pickup.group(i)==ghost.group(i) for i in (2,3,4))
            and float(pickup.group(5))<=25):
        raise RuntimeError("Factorio did not prove original first Junior's "
                           "counted physical pickup of the separate second "
                           "Junior station item with original priest staged")



def verify_reversal_second_junior_transit_log(content: str) -> None:
    """0947: original first Junior physically carries the same item to peer ghost."""
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+)"
        r" first_depot=0 second_depot=0 carrier=1 distance_sq=([\d.]+)"
        r" original_second_staged=true", content)
    transit = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_TRANSIT tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" first_depot=0 second_depot=0 carrier=1 distance_sq=([\d.]+)"
        r" original_second_staged=true command_issued=true", content)
    if not (pickup and transit and pickup.start() < transit.start()
            and int(transit.group(1)) >= int(pickup.group(1))+120
            and all(transit.group(i)==pickup.group(i) for i in (2,3,4))
            and int(transit.group(5)) > 0
            and float(transit.group(6)) <= 25):
        raise RuntimeError("Factorio did not prove original first Junior's "
                           "real carried second station item reached its exact "
                           "peer ghost with counted inventory and original priest")

def verify_reversal_second_junior_build_log(content: str) -> None:
    """0948: native station debit, original priest re-pair and peer link."""
    transit = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_TRANSIT tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" first_depot=0 second_depot=0 carrier=1 distance_sq=([\d.]+)"
        r" original_second_staged=true command_issued=true", content)
    built = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_BUILD tick=(\d+)"
        r" original_first_priest=(\d+) original_second_priest=(\d+)"
        r" child_writ=(\d+)"
        r" rebuilt_second_junior=(\d+) original_second_station=(\d+)"
        r" first_depot=0 second_depot=0 carrier=0 distance_sq=([\d.]+)"
        r" ghost=0 hierarchy=original-junior-peer", content)
    if not (transit and built and transit.start() < built.start()
            and int(built.group(1)) >= int(transit.group(1)) + 120
            and all(built.group(i) == transit.group(i) for i in (2, 3, 4))
            and int(built.group(5)) > 0 and int(built.group(6)) > 0
            and built.group(5) != built.group(6)
            and built.group(2) != built.group(3)
            and float(built.group(7)) <= 0.01):
        raise RuntimeError("Factorio did not prove original second Junior's "
                           "native station construction from the counted item, "
                           "original-priest reattachment and rank-1 peer link")



def verify_reversal_natural_ore_return_log(content: str) -> None:
    """0949: same original rebuilt peer must mine natural ore and return it."""
    built = re.search(
        r"PASS REVERSAL_ENGINE_SECOND_JUNIOR_BUILD tick=(\d+)"
        r" original_first_priest=\d+ original_second_priest=\d+"
        r" child_writ=\d+ rebuilt_second_junior=(\d+)", content)
    route = re.search(
        r"PASS REVERSAL_ENGINE_REBUILT_ORE_ROUTE tick=(\d+)"
        r" magos=(\d+) senior=(\d+) intermediate=(\d+)"
        r" junior=(\d+) peer=(\d+)"
        r" original_priests=5 empty_recovery_depots=4"
        r" natural_ore_before=(\d+) magos_ore_before=(\d+)", content)
    atomic = re.search(
        r"REVERSAL_ENGINE_ATOMIC_NATURAL_MINE tick=(\d+)"
        r" patch_before=(\d+) patch_after=(\d+)"
        r" held=1 source=natural-ore native_mine=true", content)
    delivered = re.search(
        r"PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick=(\d+)"
        r" original_magos=(\d+) original_priests=5 physical_hops=4"
        r" courier_natural_ore_delta=-1"
        r" patch_ore_before=(\d+) patch_ore_after=(\d+)"
        r" independent_patch_depletion=(\d+)"
        r" magos_inventory_delta=1"
        r" delivered_count=1 cargo_empty=true", content)
    # Native mine debits exactly one world ore and holds exactly one item.
    # Independent real mining later may deplete additional patch resources,
    # but those units must never be credited to this courier.
    if not (built and route and atomic and delivered
            and built.start() < route.start() < atomic.start() < delivered.start()
            and int(built.group(1)) <= int(route.group(1))
            and int(route.group(1)) <= int(atomic.group(1))
            < int(delivered.group(1))
            and route.group(6) == built.group(2)
            and route.group(2) == delivered.group(2)
            and int(route.group(7)) >= int(atomic.group(2)) > 0
            and int(atomic.group(2)) - int(atomic.group(3)) == 1
            and int(atomic.group(3)) >= int(delivered.group(4)) >= 0
            and int(delivered.group(3)) == int(route.group(7))
            and int(delivered.group(3)) - int(delivered.group(4))
            == int(delivered.group(5)) + 1
            and len(set(route.group(i) for i in range(2, 7))) == 5):
        raise RuntimeError("Factorio did not prove the original rebuilt "
                           "five-station route mined natural ore and returned "
                           "one counted item to the original Magos")


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



def native_efficiency_observation_1062(content: str) -> dict[str, object]:
    """Report measured native timings and deliveries; never infer script cost.

    Diagnostic only. This must not become a release/engine acceptance gate.
    Factorio's regular benchmark measures whole-engine updates. The optional
    verbose scriptUpdate series is an engine measure of ALL active mod scripts,
    never isolated Tech Priests time or broker callback time.
    The five-station reversal is a fixture within a larger mixed population,
    so the benchmark must not be mislabeled a five-priest scaling result.
    """
    result: dict[str, object] = {
        "scenario": "five-station-starvation-reversal",
        "reversal_priests": None,
        "benchmark_population": None,
        "profile_window_paired_priests_start": None,
        "profile_window_paired_priests_end": None,
        "engine_benchmark_updates": None,
        "engine_benchmark_wall_ms": None,
        "engine_update_average_ms_per_tick": None,
        "engine_benchmark_ups": None,
        "script_average_ms_per_tick": None,
        "script_p95_ms_per_tick": None,
        "script_scope": None,
        "script_sample_count": None,
        "script_sample_coverage": None,
        "broker_pulse_sample_count": None,
        "broker_pulse_average_ms_per_sample": None,
        "broker_pulse_p95_ms_per_sample": None,
        "broker_pulse_sample_interval_ticks": None,
        "broker_pulse_population": None,
        # Narrow, sampled service.fn attribution, not whole broker or script.
        "service_callback_samples_1068": None,
        "service_callback_top_1068": None,
        "scan_calls_per_1000_ticks": None,
        "routed_scan_calls_per_1000_ticks": None,
        "direct_surface_scans_per_1000_ticks": None,
        "movement_requests_per_1000_ticks": None,
        "movement_collapses_per_1000_ticks": None,
        "movement_priority_denials_per_1000_ticks": None,
        "movement_stalled_repaths_per_1000_ticks": None,
        "broker_service_blocked_fraction": None,
        "movement_replans_per_1000_ticks": None,
        "movement_denials_per_1000_ticks": None,
        "blocked_fraction": None,
        "idle_fraction": None,
        "deficit_to_first_delivery_ticks": None,
        "fixture_to_first_delivery_ticks": None,
        "delivered_ore": None,
        "delivered_ore_per_1000_ticks": None,
    }
    # This is the actual Factorio benchmark footer, not an estimate from
    # source hotspot counts or a wall-clock CI job duration.
    benchmark = re.search(
        r"^\s*Performed (\d+) updates in ([0-9]+(?:\.[0-9]+)?) ms\s*$",
        content, re.MULTILINE)
    if benchmark:
        updates = int(benchmark.group(1))
        elapsed = float(benchmark.group(2))
        if updates > 0 and math.isfinite(elapsed) and elapsed > 0:
            result["engine_benchmark_updates"] = updates
            result["engine_benchmark_wall_ms"] = round(elapsed, 3)
            result["engine_update_average_ms_per_tick"] = round(elapsed / updates, 6)
            result["engine_benchmark_ups"] = round(1000.0 * updates / elapsed, 3)
    # Factorio 2.0 --benchmark-verbose tick,scriptUpdate outputs one CSV
    # observation per actual benchmark tick in NANOSECONDS. Engine scriptUpdate
    # includes all installed mod scripts; never attribute this to Tech Priests
    # alone, to a five-priest-only population, or to broker callback timing.
    # A missing/malformed trace remains UNMEASURED. Incomplete engine runs
    # retain separately labelled partial measurements, not fictional full runs.
    # Factorio 2.0.77 emits "run 1:", "tick,scriptUpdate,",
    # followed by "t0,3055900," through "t47999,<nanoseconds>,".
    # Older two-column fixtures remain supported without inventing readings.
    headers = list(re.finditer(
        r"(?m)^[ \t]*tick,scriptUpdate(,?)[ \t]*$", content))
    if len(headers) == 1:
        ordered_ticks = []
        durations_ns = []
        native_csv = headers[0].group(1) == ","
        row_pattern = (r"t(\d+),([0-9]+(?:\.[0-9]+)?),"
                       if native_csv else
                       r"(\d+),([0-9]+(?:\.[0-9]+)?)")
        for line in content[headers[0].end():].splitlines():
            row = line.strip()
            match = re.fullmatch(row_pattern, row)
            if not match:
                # Malformed tick rows invalidate the measurement, rather
                # than masquerading as valid partial engine output.
                if re.match(r"^(?:t)?\d+,", row):
                    ordered_ticks = []
                    durations_ns = []
                    break
                if durations_ns:
                    break
                continue
            tick = int(match.group(1))
            duration = float(match.group(2))
            if (not math.isfinite(duration) or duration < 0
                    or (native_csv and not ordered_ticks and tick != 0)
                    or (ordered_ticks and tick != ordered_ticks[-1] + 1)):
                ordered_ticks = []
                durations_ns = []
                break
            ordered_ticks.append(tick)
            durations_ns.append(duration)
        if durations_ns:
            expected = result["engine_benchmark_updates"]
            # Do not claim full coverage if the engine stopped early, or if
            # verbose output is incomplete despite a successful footer.
            if expected is None or len(durations_ns) <= expected:
                ms = sorted(value / 1000000.0 for value in durations_ns)
                result["script_average_ms_per_tick"] = round(sum(ms) / len(ms), 6)
                result["script_p95_ms_per_tick"] = round(
                    ms[math.ceil(0.95 * len(ms)) - 1], 6)
                result["script_scope"] = "engine-all-mods-scriptUpdate"
                result["script_sample_count"] = len(ms)
                result["script_sample_coverage"] = (
                    "complete" if expected == len(ms) else "partial")
    # LuaProfiler is non-numeric inside Lua: read only engine-rendered
    # LocalisedString timings. This samples BROKER dispatch, not whole-script
    # ms/tick, and the five-priest reversal runs in a mixed population.
    samples = []
    for match in re.finditer(
        r"\[TP-RUNTIME-PROFILE-1064\] tick=(\d+) "
        r"scope=broker-pulse duration=(?:Elapsed|Duration):\s*"
        r"([0-9]+(?:\.[0-9]+)?)ms", content):
        duration = float(match.group(2))
        if math.isfinite(duration) and duration >= 0:
            samples.append(duration)
    if samples:
        ordered = sorted(samples)
        result["broker_pulse_sample_count"] = len(ordered)
        result["broker_pulse_average_ms_per_sample"] = round(
            sum(ordered) / len(ordered), 6)
        result["broker_pulse_p95_ms_per_sample"] = round(
            ordered[math.ceil(0.95 * len(ordered)) - 1], 6)
        result["broker_pulse_sample_interval_ticks"] = 60
        result["broker_pulse_population"] = "mixed"
    service_samples = {}
    for match in re.finditer(
        r"\[TP-RUNTIME-SERVICE-1068\] tick=(\d+) "
        r"name=([A-Za-z0-9_-]+) category=([A-Za-z0-9_-]+) "
        r"scope=service-callback duration=(?:Elapsed|Duration):\s*"
        r"([0-9]+(?:\.[0-9]+)?)ms", content):
        duration = float(match.group(4))
        if math.isfinite(duration) and 0 <= duration < 60000:
            name, category = match.group(2), match.group(3)
            service_samples.setdefault((name, category), []).append(duration)
    if service_samples:
        profiles = []
        for (name, category), values in service_samples.items():
            ordered = sorted(values)
            profiles.append({
                "name": name, "category": category, "samples": len(ordered),
                "mean_ms": round(sum(ordered) / len(ordered), 6),
                "p95_ms": round(ordered[math.ceil(0.95 * len(ordered)) - 1], 6),
                "max_ms": round(ordered[-1], 6),
                "scope": "sampled-service-callback-mixed",
            })
        # Top cost signal is diagnostic only, not proof of total cost share.
        profiles.sort(key=lambda x: (-x["p95_ms"], x["name"]))
        result["service_callback_samples_1068"] = sum(
            x["samples"] for x in profiles)
        result["service_callback_top_1068"] = profiles[:12]
    # Only a paired native mixed-population window permits these observations.
    # Routed scans != all scans; priority denials != all movement refusals;
    # broker blocked work != priest blocked/idle time.
    starts = re.findall(
        r"RUNTIME_PROFILE_WINDOW_1064_START tick=(\d+) "
        r"scope=broker-pulse population=mixed reversal_priests=5", content)
    ends = re.findall(
        r"RUNTIME_PROFILE_WINDOW_1064_END tick=(\d+) "
        r"scope=broker-pulse population=mixed reversal_priests=5", content)
    activity = re.findall(
        r"RUNTIME_ACTIVITY_WINDOW_1067 tick=(\d+) start_tick=(\d+) "
        r"population=mixed routed_scans=(-?\d+) direct_scans=(-?\d+) "
        r"movement_requests=(-?\d+) movement_collapses=(-?\d+) "
        r"movement_priority_denials=(-?\d+) movement_stalled_repaths=(-?\d+) "
        r"broker_processed=(-?\d+) broker_blocked=(-?\d+)", content)
    # The Method I reversal is embedded in a larger industrial scenario.
    # Measure the real live paired population at BOTH boundaries, but do
    # not misrepresent this as an isolated 5-priest benchmark or use it as
    # benchmark-wide population provenance for a matched-run comparison.
    population = re.findall(
        r"RUNTIME_PAIRED_POPULATION_1071 boundary=(start|end) "
        r"tick=(\d+) pairs=(\d+) scope=live-paired-all-forces", content)
    if len(population) == 2 and len(starts) == len(ends) == 1:
        beginning, ending = population
        if (beginning[0] == "start" and ending[0] == "end"
                and int(beginning[1]) == int(starts[0])
                and int(ending[1]) == int(ends[0])):
            result["profile_window_paired_priests_start"] = int(beginning[2])
            result["profile_window_paired_priests_end"] = int(ending[2])
    if len(starts) == len(ends) == len(activity) == 1:
        end, start, *counts = map(int, activity[0])
        duration = end - start
        if (start == int(starts[0]) and end == int(ends[0])
                and duration > 0 and all(n >= 0 for n in counts)
                and counts[7] <= counts[6]):
            names = (
                "routed_scan_calls_per_1000_ticks",
                "direct_surface_scans_per_1000_ticks",
                "movement_requests_per_1000_ticks",
                "movement_collapses_per_1000_ticks",
                "movement_priority_denials_per_1000_ticks",
                "movement_stalled_repaths_per_1000_ticks",
            )
            for name, count in zip(names, counts[:6]):
                result[name] = round(count * 1000.0 / duration, 6)
            if counts[6] > 0:
                result["broker_service_blocked_fraction"] = round(
                    counts[7] / counts[6], 6)
    # These are two physical engine receipts, not a plan, source assertion,
    # ghost count or generic "ore mined" event. The denominator is explicitly
    # fixture-to-delivery, NOT the unknown time of first Magos deficit.
    fixture = re.search(
        r"PASS REVERSAL_ENGINE_FIVE_STATION_FIXTURE tick=(\d+)[^\n]*"
        r"station_spares=0[^\n]*original_priests=(\d+)", content)
    delivered = re.search(
        r"PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick=(\d+)[^\n]*"
        r"physical_hops=4[^\n]*magos_inventory_delta=(\d+)"
        r" delivered_count=(\d+) cargo_empty=true", content)
    if fixture and int(fixture.group(2)) == 5:
        result["reversal_priests"] = 5
    if fixture and delivered and result["reversal_priests"] == 5:
        start, end = int(fixture.group(1)), int(delivered.group(1))
        magos_delta, count = int(delivered.group(2)), int(delivered.group(3))
        if end > start and count > 0 and count == magos_delta:
            result["fixture_to_first_delivery_ticks"] = end - start
            result["delivered_ore"] = count
            result["delivered_ore_per_1000_ticks"] = round(
                1000.0 * count / (end - start), 6)
    # A deficit starts at the first accepted PHYSICAL 0256 station-recovery
    # writ with real station_stock=0, NOT at fixture creation or a ghost.
    # This is CI-authorized shortage-to-receipt latency, not a claim that
    # the Magos autonomously discovered the deficit. Never infer a value
    # if any live writ, identity, chronology or four-hop receipt is absent.
    writs = re.findall(
        r"REVERSAL_ENGINE_REAL_WRIT_ASSIGNED tick=(\d+) "
        r"id=(\d+) root=(\d+) station_stock=0 ghost=(\d+)", content)
    returns = re.findall(
        r"PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick=(\d+) "
        r"original_magos=(\d+) original_priests=5 physical_hops=4", content)
    if (len(writs) == len(returns) == 1 and fixture
            and result["delivered_ore"] is not None):
        writ_tick, writ_id, root, ghost = map(int, writs[0])
        return_tick, receipt_root = map(int, returns[0])
        if (writ_id > 0 and root > 0 and ghost > 0
                and root == receipt_root
                and int(fixture.group(1)) <= writ_tick < return_tick
                and return_tick == int(delivered.group(1))):
            result["deficit_to_first_delivery_ticks"] = return_tick - writ_tick
    return result


def self_test_native_efficiency_1062() -> None:
    fixture = (
        "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_FIVE_STATION_FIXTURE "
        "tick=13940 hierarchy=4-3-2-1-1 station_spares=0 components=0 "
        "original_priests=5 fixture_only=true\n"
        "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN "
        "tick=53780 original_magos=899 original_priests=5 physical_hops=4 "
        "magos_inventory_delta=1 delivered_count=1 cargo_empty=true\n"
        "  Performed 48000 updates in 447299.911 ms\n"
        "  avg: 9.319 ms, min: 0.107 ms, max: 7485.600 ms\n")
    observed = native_efficiency_observation_1062(fixture)
    assert observed["reversal_priests"] == 5
    assert observed["benchmark_population"] is None
    assert observed["engine_benchmark_updates"] == 48000
    assert abs(observed["engine_benchmark_ups"] - 107.311) < 0.02
    assert observed["fixture_to_first_delivery_ticks"] == 39840
    assert observed["delivered_ore"] == 1
    assert abs(observed["delivered_ore_per_1000_ticks"] - 0.0251) < 0.0001
    # The real 2.0.77 run 42339417106 recorded a zero-stock 0256 writ
    # at tick 13580 and the original Magos receipt at tick 47360. Demand
    # the same engine-backed identities and physical-four-hop receipt here.
    accepted_writ = (
        "[TP-GROUND-RANK-TEST] REVERSAL_ENGINE_REAL_WRIT_ASSIGNED "
        "tick=14000 id=2 root=899 station_stock=0 ghost=1000\n")
    accepted = native_efficiency_observation_1062(fixture + accepted_writ)
    assert accepted["deficit_to_first_delivery_ticks"] == 39780
    for bad_writ in (
        accepted_writ.replace("root=899", "root=898"),
        accepted_writ.replace("station_stock=0", "station_stock=1"),
        accepted_writ.replace("id=2", "id=0"),
        accepted_writ.replace("ghost=1000", "ghost=0"),
        accepted_writ.replace("tick=14000", "tick=13939"),
        accepted_writ.replace("tick=14000", "tick=53780"),
        accepted_writ + accepted_writ,
        accepted_writ.replace("REAL_WRIT_ASSIGNED", "GHOST_PLANNED"),
    ):
        invalid = native_efficiency_observation_1062(fixture + bad_writ)
        assert invalid["deficit_to_first_delivery_ticks"] is None, bad_writ
        # A wrong diagnostic must not weaken existing native delivery proof.
        assert invalid["delivered_ore"] == 1
    assert native_efficiency_observation_1062(
        fixture.replace("original_magos=899", "original_magos=898")
        + accepted_writ)["deficit_to_first_delivery_ticks"] is None
    assert native_efficiency_observation_1062(
        fixture.replace("physical_hops=4", "physical_hops=3")
        + accepted_writ)["deficit_to_first_delivery_ticks"] is None
    profile_fixture = fixture + (
        "[TP-RUNTIME-PROFILE-1064] tick=18000 scope=broker-pulse "
        "duration=Duration: 0.200ms\n"
        "[TP-RUNTIME-PROFILE-1064] tick=18060 scope=broker-pulse "
        "duration=Elapsed: 0.400ms\n"
        "[TP-RUNTIME-PROFILE-1064] tick=18120 scope=broker-pulse "
        "duration=Duration: 0.600ms\n")
    profiled = native_efficiency_observation_1062(profile_fixture)
    assert profiled["broker_pulse_sample_count"] == 3
    assert profiled["broker_pulse_average_ms_per_sample"] == 0.4
    assert profiled["broker_pulse_p95_ms_per_sample"] == 0.6
    assert profiled["broker_pulse_sample_interval_ticks"] == 60
    assert profiled["broker_pulse_population"] == "mixed"
    assert profiled["script_average_ms_per_tick"] is None
    assert profiled["script_p95_ms_per_tick"] is None
    per_service_fixture = profile_fixture + (
        "[TP-RUNTIME-SERVICE-1068] tick=18000 name=construction_discovery_0338 "
        "category=construction scope=service-callback duration=Duration: 2.000ms\n"
        "[TP-RUNTIME-SERVICE-1068] tick=18060 name=construction_discovery_0338 "
        "category=construction scope=service-callback duration=Elapsed: 3.000ms\n"
        "[TP-RUNTIME-SERVICE-1068] tick=18120 name=remote_rail_outpost_0835 "
        "category=construction scope=service-callback duration=Duration: 5.000ms\n")
    attributed = native_efficiency_observation_1062(per_service_fixture)
    assert attributed["service_callback_samples_1068"] == 3
    assert attributed["service_callback_top_1068"][0]["name"] == "remote_rail_outpost_0835"
    assert attributed["service_callback_top_1068"][0]["p95_ms"] == 5.0
    assert attributed["service_callback_top_1068"][1]["samples"] == 2
    assert attributed["script_average_ms_per_tick"] is None
    invalid = native_efficiency_observation_1062(
        per_service_fixture.replace("scope=service-callback",
                                    "scope=whole-script", 1))
    assert invalid["service_callback_samples_1068"] == 2
    assert native_efficiency_observation_1062(fixture)["service_callback_top_1068"] is None
    activity_fixture = profile_fixture + (
        "[TP-GROUND-RANK-TEST] RUNTIME_PROFILE_WINDOW_1064_START "
        "tick=18000 scope=broker-pulse population=mixed reversal_priests=5\n"
        "[TP-GROUND-RANK-TEST] RUNTIME_PROFILE_WINDOW_1064_END "
        "tick=20000 scope=broker-pulse population=mixed reversal_priests=5\n"
        "[TP-GROUND-RANK-TEST] RUNTIME_ACTIVITY_WINDOW_1067 "
        "tick=20000 start_tick=18000 population=mixed routed_scans=40 "
        "direct_scans=10 movement_requests=20 movement_collapses=4 "
        "movement_priority_denials=6 movement_stalled_repaths=2 "
        "broker_processed=100 broker_blocked=25\n")
    activity = native_efficiency_observation_1062(activity_fixture)
    assert activity["routed_scan_calls_per_1000_ticks"] == 20
    assert activity["direct_surface_scans_per_1000_ticks"] == 5
    assert activity["movement_requests_per_1000_ticks"] == 10
    assert activity["movement_collapses_per_1000_ticks"] == 2
    assert activity["movement_priority_denials_per_1000_ticks"] == 3
    assert activity["movement_stalled_repaths_per_1000_ticks"] == 1
    assert activity["broker_service_blocked_fraction"] == 0.25
    population_fixture = activity_fixture + (
        "[TP-GROUND-RANK-TEST] RUNTIME_PAIRED_POPULATION_1071 "
        "boundary=start tick=18000 pairs=18 scope=live-paired-all-forces\n"
        "[TP-GROUND-RANK-TEST] RUNTIME_PAIRED_POPULATION_1071 "
        "boundary=end tick=20000 pairs=19 scope=live-paired-all-forces\n")
    population = native_efficiency_observation_1062(population_fixture)
    assert population["profile_window_paired_priests_start"] == 18
    assert population["profile_window_paired_priests_end"] == 19
    assert population["benchmark_population"] is None
    for bad_population in (
        population_fixture.replace("boundary=end", "boundary=start"),
        population_fixture.replace("boundary=end tick=20000",
                                   "boundary=end tick=20001"),
        population_fixture.replace("pairs=19 scope=live-paired-all-forces",
                                   "pairs=19 scope=isolated"),
        population_fixture + (
            "[TP-GROUND-RANK-TEST] RUNTIME_PAIRED_POPULATION_1071 "
            "boundary=end tick=20000 pairs=19 scope=live-paired-all-forces\n"),
    ):
        invalid_population = native_efficiency_observation_1062(bad_population)
        assert invalid_population["profile_window_paired_priests_start"] is None
        assert invalid_population["profile_window_paired_priests_end"] is None
    assert activity["scan_calls_per_1000_ticks"] is None
    assert activity["movement_denials_per_1000_ticks"] is None
    assert activity["blocked_fraction"] is None
    for bad in (
        activity_fixture.replace("start_tick=18000", "start_tick=17000"),
        activity_fixture.replace("routed_scans=40", "routed_scans=-1"),
        activity_fixture.replace("broker_blocked=25", "broker_blocked=101"),
        activity_fixture.replace("population=mixed routed_scans=", "population=isolated routed_scans="),
        activity_fixture + "RUNTIME_ACTIVITY_WINDOW_1067 " + activity_fixture.split("RUNTIME_ACTIVITY_WINDOW_1067 ", 1)[1].split("\n", 1)[0] + "\n",
    ):
        negative = native_efficiency_observation_1062(bad)
        assert negative["routed_scan_calls_per_1000_ticks"] is None
        assert negative["broker_service_blocked_fraction"] is None
    for broken in (
        profile_fixture.replace("scope=broker-pulse", "scope=whole-script", 1),
        profile_fixture.replace("Duration: 0.600ms", "Duration: invalidms"),
    ):
        negative_profile = native_efficiency_observation_1062(broken)
        assert negative_profile["broker_pulse_sample_count"] < 3
        assert negative_profile["script_average_ms_per_tick"] is None
    assert observed["broker_pulse_sample_count"] is None
    for field in ("script_average_ms_per_tick", "script_p95_ms_per_tick",
                  "scan_calls_per_1000_ticks", "movement_replans_per_1000_ticks",
                  "movement_denials_per_1000_ticks", "blocked_fraction",
                  "idle_fraction", "deficit_to_first_delivery_ticks"):
        assert observed[field] is None, field
    for altered in (
        fixture.replace("station_spares=0", "station_spares=1"),
        fixture.replace("physical_hops=4", "physical_hops=3"),
        fixture.replace("magos_inventory_delta=1", "magos_inventory_delta=0"),
        fixture.replace("cargo_empty=true", "cargo_empty=false"),
        fixture.replace("tick=53780", "tick=13940"),
    ):
        negative = native_efficiency_observation_1062(altered)
        assert negative["delivered_ore"] is None
        assert negative["delivered_ore_per_1000_ticks"] is None
    missing = native_efficiency_observation_1062("unrelated log\n")
    assert missing["engine_benchmark_ups"] is None
    assert missing["delivered_ore"] is None
    assert missing["script_p95_ms_per_tick"] is None
    # Engine's per-tick scriptUpdate field is nanoseconds for ALL active
    # mods, not one callback or this mod alone. Require monotonic complete CSV.
    measured = native_efficiency_observation_1062(
        "tick,scriptUpdate\n"
        "100,1000000\n101,2000000\n102,3000000\n103,4000000\n"
        "  Performed 4 updates in 20.000 ms\n")
    assert measured["script_average_ms_per_tick"] == 2.5
    assert measured["script_p95_ms_per_tick"] == 4.0
    assert measured["script_sample_count"] == 4
    assert measured["script_sample_coverage"] == "complete"
    assert measured["script_scope"] == "engine-all-mods-scriptUpdate"
    assert measured["broker_pulse_sample_count"] is None
    # Exact Factorio 2.0.77 --benchmark-verbose native CSV envelope,
    # observed in production 2.0.77 run 42335267326 (48,000 rows).
    native = native_efficiency_observation_1062(
        "  Performed 4 updates in 20.000 ms\n"
        "run 1:\n"
        "tick,scriptUpdate,\n"
        "t0,1000000,\nt1,2000000,\nt2,3000000,\nt3,4000000,\n"
        " 583.883 Goodbye\n")
    assert native["script_average_ms_per_tick"] == 2.5
    assert native["script_p95_ms_per_tick"] == 4.0
    assert native["script_sample_count"] == 4
    assert native["script_sample_coverage"] == "complete"
    assert native["script_scope"] == "engine-all-mods-scriptUpdate"
    for bad_native in (
        "t0,1000000,\nt0,2000000,\n",   # duplicate tick
        "t0,1000000,\nt2,2000000,\n",   # missing tick
        "t0,1000000,\nt1,NaN,\n",       # invalid numeric observation
        "t0,1000000,\nt1,-2000000,\n",  # negative nanoseconds
        "t0,1000000,\nt1,2000000\n",    # missing native trailing comma
        "t1,1000000,\nt2,2000000,\n",   # nonzero first native tick
        "t0,1000000,\nt1,2000000,\nt2,3000000,\n"
        "t3,4000000,\nt4,5000000,\n",   # more samples than updates
    ):
        invalid = native_efficiency_observation_1062(
            "  Performed 4 updates in 20.000 ms\n"
            "run 1:\ntick,scriptUpdate,\n" + bad_native)
        assert invalid["script_average_ms_per_tick"] is None, bad_native
    assert native_efficiency_observation_1062(
        "run 1:\ntick,scriptUpdate,\nt0,1000000,\nt1,2000000,\n"
    )["script_sample_coverage"] == "partial"
    for bad_csv in (
        "tick,scriptUpdate\n100,1000000\n100,2000000\n",
        "tick,scriptUpdate\n100,-1000000\n",
        "tick,scriptUpdate\n100,1000000\n102,2000000\n",
        "tick,scriptUpdate\n100,1000000\n101,NaN\n",
        "tick,scriptUpdate\n100,1000000\n101,2000000\n"
        "tick,scriptUpdate\n200,3000000\n",
    ):
        bad = native_efficiency_observation_1062(
            bad_csv + "  Performed 4 updates in 20.000 ms\n")
        assert bad["script_average_ms_per_tick"] is None, bad_csv
    partial = native_efficiency_observation_1062(
        "tick,scriptUpdate\n100,1000000\n101,2000000\n")
    assert partial["script_sample_coverage"] == "partial"
    assert partial["script_sample_count"] == 2
    assert partial["engine_benchmark_updates"] is None
    incomplete = native_efficiency_observation_1062(
        "tick,scriptUpdate\n100,1000000\n101,2000000\n"
        "  Performed 4 updates in 20.000 ms\n")
    assert incomplete["script_sample_coverage"] == "partial"
    assert native_efficiency_observation_1062(
        "tick,scriptUpdate\n100,1000000\n101,2000000\n"
        "  Performed 1 updates in 20.000 ms\n")[
            "script_average_ms_per_tick"] is None
    print("[native-efficiency-1062] PASS optional diagnostic self-test")


def self_test() -> int:
    # 1360 focused regression: independent-process failure must retain its
    # native engine log, checkpoint and separately measured fifth-process data.
    artifact_policy = (pathlib.Path(__file__).resolve().parents[1] /
                       ".github/workflows/factorio-runtime-tests.yml"
                       ).read_text(encoding="utf-8")
    for required in (
        "${{ runner.temp }}/factorio-save-reload/factorio-robot-midflight-save-server.log",
        "${{ runner.temp }}/factorio-save-reload/factorio-robot-midflight-reload.log",
        "test-artifacts/tech-priests-robot-midflight-checkpoint.zip",
        "test-artifacts/performance-s3-preflight-1360.json",
    ):
        if artifact_policy.count(required) != 1:
            raise AssertionError("S3 failure evidence not archived: " + required)
    runner_source = pathlib.Path(__file__).read_text(encoding="utf-8")
    # Search the executable function, not these marker strings in the
    # self-test itself (a previous S3 source regression failed that way).
    execute_start = runner_source.index("\ndef execute(args: argparse.Namespace) -> int:\n")
    measured_boundary = runner_source.index(
        "    # Completed fifth-process evidence survives", execute_start)
    sixth_boundary = runner_source.index(
        "    # Sixth REAL server process checkpoints", execute_start)
    seventh_boundary = runner_source.index(
        "    # Seventh REAL process reopens", execute_start)
    if not measured_boundary < sixth_boundary < seventh_boundary:
        raise AssertionError("S3 engine boundaries reordered")
    previous = runner_source[measured_boundary:sixth_boundary]
    if ("performance-s3-preflight-1360.json" not in previous or
            "NATIVE_EFFICIENCY_1062" not in previous):
        raise AssertionError("fifth-process metrics suppressed on S3 failure")
    native_save = runner_source[sixth_boundary:seventh_boundary]
    if ("server_checkpoint(" not in native_save or
            "stock_carried" not in native_save or
            "ROBOT_MIDFLIGHT_SAVE_MARKER" not in native_save or
            "checkpointed_pre_save_evidence(" not in native_save):
        raise AssertionError("S3 midflight checkpoint not made by a native server")
    if "verify_robot_midflight_reload_1360_log(midflight_server_log, midflight_log)" not in runner_source[seventh_boundary:]:
        raise AssertionError("S3 reload not verified against real server save")
    # 1175: The native fourth-process checkpoint requested a save at tick
    # 9975, then completed ore hop 2 in the SAME tick before the blocking
    # save began. Its fifth-process reload started from that persisted hop
    # and logged hop 3. Do not discard proven same-tick inventory receipts,
    # and NEVER accept events occurring after the native save started.
    checkpoint_fixture = (
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_CARRY_SAVE_REQUESTED "
        "tick=9975\n"
        "[TP-GROUND-RANK-TEST] ORE_ENGINE_HOP tick=9975 hop=2 "
        "from=444 to=443 counted=1 receipt_before=1 receipt_after=2\n"
        "13.357 Info AppManager.cpp:324: Saving to "
        "_autosave-tech-priests-ci-stock-carried (blocking).\n"
        "13.416 Info AppManagerStates.cpp:2111: Saving finished\n"
        "[TP-GROUND-RANK-TEST] ORE_ENGINE_HOP tick=10000 hop=99\n"
    )
    checkpoint_prefix = checkpointed_pre_save_evidence(
        checkpoint_fixture, STOCK_CARRY_SAVE_MARKER,
        STOCK_CARRY_SAVE_NAME)
    assert ("ORE_ENGINE_HOP tick=9975 hop=2" in checkpoint_prefix
            and "ORE_ENGINE_HOP tick=10000" not in checkpoint_prefix
            and "Saving to " not in checkpoint_prefix)
    for invalid in (
        checkpoint_fixture.replace("Saving finished", "Save aborted"),
        checkpoint_fixture.replace("Saving to _autosave-tech-priests-ci-",
                                   "Saving to _autosave-another-ci-", 1),
        checkpoint_fixture.replace(STOCK_CARRY_SAVE_MARKER,
                                   "UNRELATED_SAVE_REQUEST"),
        checkpoint_fixture.replace("13.357 Info AppManager.cpp:324: ",
                                   "13.357 NOT_ENGINE_SAVE: "),
    ):
        try:
            checkpointed_pre_save_evidence(
                invalid, STOCK_CARRY_SAVE_MARKER, STOCK_CARRY_SAVE_NAME)
        except RuntimeError:
            pass
        else:
            raise AssertionError(
                "ambiguous or unfinished native checkpoint accepted")
    verify_robot_frontier_seed_retry_1121_source()
    seed_source = (pathlib.Path(__file__).resolve().parents[1] /
                   "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                   ).read_text(encoding="utf-8")
    for old, replacement in (
        ("if search.awaiting_delete then", "if false then"),
        ("if not game.delete_surface(candidate) then",
         "if game.delete_surface(candidate) then"),
    ):
        mutated = seed_source.replace(old, replacement, 1)
        if mutated == seed_source:
            raise AssertionError("missing seed retry mutation: " + old)
        try:
            verify_robot_frontier_seed_retry_1121_source(mutated)
        except AssertionError:
            pass
        else:
            raise AssertionError("unsafe seed retry mutation accepted: " + old)
    verify_drill_first_process_boundary_0986()
    verify_drill_natural_patch_discovery_0987()
    verify_drill_activation_0989()
    drill_activation_source = (pathlib.Path(__file__).resolve().parents[1] /
                               "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                               ).read_text(encoding="utf-8")
    for old, new in (
        ("math.abs(base.x-pos.x)<1", "true"),
        ("math.abs(base.y-pos.y)<1", "true"),
        ("footprint_has_ore and surface.can_place_entity(spec)",
         "surface.can_place_entity(spec)"),
        ("if (not target or correct_target) and drop then", "if drop then"),
        ("record.activated_target_tick=game.tick", "record.activated_target_tick=nil"),
        ('drill_engine_diagnostic_0990(state,"target-never-activated")',
         '-- missing target diagnosis'),
        ('drill_engine_diagnostic_0990(state,"no-counted-real-output")',
         '-- missing output diagnosis'),
        ("age==120 or age==600 or age==1200", "false"),
        ("record.activated_target_tick>record.created_tick", "true"),
        ("drill_engine_observe_target_0989(state)", "-- no live observation"),
        ("remaining<record.ore_before and mined>0",
         "remaining<=record.ore_before and mined>=0"),
    ):
        mutated = drill_activation_source.replace(old, new, 1)
        if mutated == drill_activation_source:
            raise AssertionError("missing drill mutation fixture: " + old)
        try:
            verify_drill_activation_0989(mutated)
        except AssertionError:
            pass
        else:
            raise AssertionError("unsafe drill activation mutation accepted: " + old)
    drill_search_source = (pathlib.Path(__file__).resolve().parents[1] /
                           "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                           ).read_text(encoding="utf-8")
    for broken in (
        drill_search_source.replace(
            drill_search_source.split("local centers={", 1)[1].split("\n  local regions_checked", 1)[0],
            "{x=160,y=160}}", 1),
        drill_search_source.replace("surface.request_to_generate_chunks(center,3)",
                                    "-- disabled chunk generation", 1),
        drill_search_source.replace('name="iron-ore",type="resource",',
                                    'name="copper-ore",type="resource",', 1),
        drill_search_source.replace("ore.valid and not in_fixture and ore.amount and ore.amount>=20",
                                    "ore.valid", 1),
        drill_search_source.replace("x=math.floor(drop.x)+0.5",
                                    "x=drop.x", 1),
        drill_search_source.replace("y=math.floor(drop.y)+0.5",
                                    "y=drop.y", 1),
        drill_search_source.replace('fuel.insert{name="coal",count=5}==5',
                                    'fuel.insert{name="coal",count=0}==0', 1),
        drill_search_source.replace('surface.create_entity(spec)',
                                    'nil -- no physical drill', 1),
        drill_search_source.replace(
            'local correct_target=target and target.valid',
            'local correct_target=not target or target.valid', 1),
        drill_search_source.replace(
            'if not target then target_missing=target_missing+1',
            'if false then target_missing=target_missing+1', 1),
        drill_search_source.replace(
            'initial_target_unit=chosen_drill.mining_target and',
            'initial_target_unit=nil and', 1),
    ):
        try:
            verify_drill_natural_patch_discovery_0987(broken)
        except AssertionError:
            pass
        else:
            raise AssertionError("unsafe natural drill search mutation accepted")
    drill_source = (pathlib.Path(__file__).resolve().parents[1] /
                    "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                    ).read_text(encoding="utf-8")
    for broken in (
        drill_source.replace(
            "if drill_engine_first_process_attach_0986(state) then",
            "if false then"),
        drill_source.replace("and not state.save_reload_requested",
                             "and true"),
        drill_source.replace("and not state.save_reload_verified",
                             "and true"),
        drill_source.replace('TP_CI_COURIER_RELOAD_PROBE")~=true',
                             'TP_CI_COURIER_RELOAD_PROBE")==true'),
        drill_source.replace("and not state.drill_engine_0985",
                             "and true"),
    ):
        try:
            verify_drill_first_process_boundary_0986(broken)
        except AssertionError:
            pass
        else:
            raise AssertionError("unsafe drill first-process mutation accepted")
    verify_cargo_import_boundary()
    verify_reversal_audit_import_boundary()
    audit_source = (pathlib.Path(__file__).resolve().parents[1] /
                    "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                    ).read_text(encoding="utf-8")
    for broken in (
        audit_source.replace(
            'local audit=REVERSAL_REBUILD_0867',
            'local audit=require("scripts.core.station_starvation_rebuild_0867")'),
        audit_source.replace('local audit=REVERSAL_REBUILD_0867',
                             'local audit=nil'),
        audit_source.replace('not(proof and proof.stage_count==4)',
                             'not(proof)'),
    ):
        try:
            verify_reversal_audit_import_boundary(broken)
        except AssertionError:
            pass
        else:
            raise AssertionError("unsafe fourth-depot audit mutation accepted")
    outbound_proof = (
        "PASS REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT tick=29000 "
        "old_station=500 priest=889 stored_junior=1 magos=100 "
        "further_stages_not_claimed=true\n"
        "PASS REVERSAL_ENGINE_FOUR_DEPOT_AUDIT tick=30075 "
        "independent_real_items=4 original_priests=4\n"
        "PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_PICKUP tick=30195 "
        "original_senior=873 original_priest=886 "
        "source_before=1 source_after=0 carrier_before=0 carrier_after=1 "
        "other_depots=3 ghost_preserved_or_reconciled=true station_not_built=true "
        "ghost_reconciled_0896=true owned_ghost_replaced_0899=true\n"
        "PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_TRANSIT tick=30555 "
        "original_senior=873 original_priest=886 magos_priest=885 "
        "held=1 source=0 prior_depots=3 distance_sq=2.250 ghost_unit=987\n"
        "PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_BUILD tick=30975 "
        "original_senior=873 rebuilt_senior=990 original_priest=886 "
        "source=0 carrier=0 prior_depots=3 ghost=0 "
        "hierarchy=magos-to-original-senior\n"
        "PASS REVERSAL_ENGINE_INTERMEDIATE_GHOST tick=31035 "
        "rebuilt_senior=990 original_senior_priest=886 "
        "original_intermediate_priest=887 child_writ=10 ghost_unit=991 "
        "intermediate_depot=1 junior_depots=2 carrier=0 rank=3-to-2 "
        "physical_build_not_yet_claimed=true")
    verify_reversal_outbound_log(outbound_proof)
    verify_reversal_outbound_transit_log(outbound_proof)
    verify_reversal_outbound_build_log(outbound_proof)
    verify_reversal_intermediate_ghost_log(outbound_proof)
    verify_reversal_intermediate_ghost_log(
        outbound_proof.replace("tick=31035", "tick=30975"))
    pickup_proof = outbound_proof + (
        "\nPASS REVERSAL_ENGINE_INTERMEDIATE_PICKUP tick=31200 "
        "rebuilt_senior=990 original_senior_priest=886 "
        "original_intermediate_priest=887 child_writ=10 "
        "source_before=1 source_after=0 carrier_before=0 carrier_after=1 "
        "junior_depots=2 distance_sq=3.250 original_priest_staged=true")
    verify_reversal_intermediate_pickup_log(pickup_proof)
    transit_proof = pickup_proof + (
        "\nPASS REVERSAL_ENGINE_INTERMEDIATE_TRANSIT tick=31440 "
        "rebuilt_senior=990 original_senior_priest=886 "
        "original_intermediate_priest=887 child_writ=10 "
        "held=1 source=0 junior_depots=2 distance_sq=4.000 "
        "ghost_unit=991 original_priest_staged=true")
    verify_reversal_intermediate_transit_log(transit_proof)
    intermediate_build_proof = transit_proof + (
        "\nPASS REVERSAL_ENGINE_INTERMEDIATE_BUILD tick=31800 "
        "rebuilt_senior=990 original_senior_priest=886 "
        "original_intermediate_priest=887 child_writ=10 "
        "rebuilt_intermediate=1002 original_intermediate_station=300 "
        "source=0 carrier=0 junior_depots=2 distance_sq=0.000 "
        "ghost=0 hierarchy=senior-to-original-intermediate")
    verify_reversal_intermediate_build_log(intermediate_build_proof)

    junior_ghost_proof = intermediate_build_proof + (
        "\nPASS REVERSAL_ENGINE_FIRST_JUNIOR_GHOST tick=31920 "
        "rebuilt_intermediate=1002 original_intermediate_priest=887 "
        "original_junior_priest=888 child_writ=11 ghost_unit=1003 "
        "junior_depots=2 carrier=0 rank=2-to-1 "
        "physical_build_not_yet_claimed=true")
    verify_reversal_first_junior_ghost_log(junior_ghost_proof)
    junior_pickup_proof = junior_ghost_proof + (
        "\nPASS REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP tick=32100 "
        "rebuilt_intermediate=1002 original_intermediate_priest=887 "
        "original_junior_priest=888 child_writ=11 "
        "source_before=1 source_after=0 carrier_before=0 carrier_after=1 "
        "second_depot=1 distance_sq=27.760 pickup_distance_sq=24.664 "
        "pickup_station=100 pickup_tick=32090 original_priest_staged=true")
    verify_reversal_first_junior_pickup_log(junior_pickup_proof)
    junior_transit_proof = junior_pickup_proof + (
        "\nPASS REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT tick=32400 "
        "rebuilt_intermediate=1002 original_intermediate_priest=887 "
        "original_junior_priest=888 child_writ=11 "
        "held=1 source=0 second_depot=1 distance_sq=3.250 "
        "ghost_unit=1003 original_priest_staged=true")
    verify_reversal_first_junior_transit_log(junior_transit_proof)
    junior_build_proof = junior_transit_proof + (
        "\nPASS REVERSAL_ENGINE_FIRST_JUNIOR_BUILD tick=32700 "
        "rebuilt_intermediate=1002 original_intermediate_priest=887 "
        "original_junior_priest=888 child_writ=11 "
        "rebuilt_junior=1005 original_junior_station=400 "
        "source=0 carrier=0 second_depot=1 distance_sq=0.000 "
        "ghost=0 hierarchy=intermediate-to-original-junior")
    verify_reversal_first_junior_build_log(junior_build_proof)
    second_ghost_proof = junior_build_proof + (
        "\nPASS REVERSAL_ENGINE_SECOND_JUNIOR_GHOST tick=33000 "
        "original_first_priest=888 original_second_priest=889 "
        "child_writ=12 ghost_unit=1006 "
        "first_depot=0 second_depot=1 original_second_staged=true")
    verify_reversal_second_junior_ghost_log(second_ghost_proof)
    second_pickup_proof = second_ghost_proof + (
        "\nPASS REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP tick=33300 "
        "original_first_priest=888 original_second_priest=889 "
        "child_writ=12 first_depot=0 second_depot=0 carrier=1 "
        "distance_sq=4.000 original_second_staged=true")
    verify_reversal_second_junior_pickup_log(second_pickup_proof)
    second_transit_proof = second_pickup_proof + (
        "\nPASS REVERSAL_ENGINE_SECOND_JUNIOR_TRANSIT tick=33600 "
        "original_first_priest=888 original_second_priest=889 "
        "child_writ=12 ghost_unit=1006 "
        "first_depot=0 second_depot=0 carrier=1 distance_sq=4.000 "
        "original_second_staged=true command_issued=true")
    verify_reversal_second_junior_transit_log(second_transit_proof)
    second_build_proof = second_transit_proof + (
        "\nPASS REVERSAL_ENGINE_SECOND_JUNIOR_BUILD tick=33900 "
        "original_first_priest=888 original_second_priest=889 "
        "child_writ=12 rebuilt_second_junior=1007 "
        "original_second_station=500 first_depot=0 second_depot=0 "
        "carrier=0 distance_sq=0.000 ghost=0 "
        "hierarchy=original-junior-peer")
    verify_reversal_second_junior_build_log(second_build_proof)
    reversal_ore_proof = second_build_proof + (
        "\nPASS REVERSAL_ENGINE_REBUILT_ORE_ROUTE tick=34100 "
        "magos=100 senior=1004 intermediate=1005 junior=1006 peer=1007 "
        "original_priests=5 empty_recovery_depots=4 "
        "natural_ore_before=500 magos_ore_before=0"
        "\nREVERSAL_ENGINE_ATOMIC_NATURAL_MINE tick=35000 "
        "patch_before=499 patch_after=498 "
        "held=1 source=natural-ore native_mine=true"
        "\nPASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick=36500 "
        "original_magos=100 original_priests=5 physical_hops=4 "
        "courier_natural_ore_delta=-1 "
        "patch_ore_before=500 patch_ore_after=497 "
        "independent_patch_depletion=2 magos_inventory_delta=1 "
        "delivered_count=1 cargo_empty=true")
    verify_reversal_natural_ore_return_log(reversal_ore_proof)
    for broken in (
        reversal_ore_proof.replace("peer=1007", "peer=1008"),
        reversal_ore_proof.replace("physical_hops=4", "physical_hops=3"),
        reversal_ore_proof.replace("courier_natural_ore_delta=-1",
                                   "courier_natural_ore_delta=0"),
        reversal_ore_proof.replace("patch_before=499 patch_after=498",
                                   "patch_before=499 patch_after=497"),
        reversal_ore_proof.replace("held=1 source=natural-ore",
                                   "held=0 source=natural-ore"),
        reversal_ore_proof.replace("patch_ore_after=497",
                                   "patch_ore_after=499"),
        reversal_ore_proof.replace("independent_patch_depletion=2",
                                   "independent_patch_depletion=1"),
        reversal_ore_proof.replace("tick=35000", "tick=34000"),
        reversal_ore_proof.replace(
            "REVERSAL_ENGINE_ATOMIC_NATURAL_MINE", "MISSING_ATOMIC_MINE"),
        reversal_ore_proof.replace("original_magos=100 original_priests=5",
                                   "original_magos=999 original_priests=5"),
        reversal_ore_proof.replace("tick=36500", "tick=34000"),
        second_build_proof,
    ):
        try:
            verify_reversal_natural_ore_return_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified reversal natural ore return accepted")
    for broken in (
        second_build_proof.replace("BUILD tick=33900", "BUILD tick=33600"),
        second_build_proof.replace("rebuilt_second_junior=1007",
                                   "rebuilt_second_junior=500"),
        second_build_proof.replace("original_second_priest=889 "
                                   "child_writ=12 rebuilt_second_junior",
                                   "original_second_priest=777 "
                                   "child_writ=12 rebuilt_second_junior"),
        second_build_proof.replace("carrier=0 distance_sq=0.000 ghost=0",
                                   "carrier=1 distance_sq=0.000 ghost=0"),
        second_build_proof.replace("distance_sq=0.000 ghost=0",
                                   "distance_sq=9.000 ghost=0"),
        second_build_proof.replace("ghost=0 hierarchy=original-junior-peer",
                                   "ghost=1 hierarchy=original-junior-peer"),
        second_build_proof.replace("hierarchy=original-junior-peer",
                                   "hierarchy=unpaired"),
        second_build_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_second_junior_build_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified second-Junior native build accepted")
    for broken in (
        second_transit_proof.replace("tick=33600", "tick=33300"),
        second_transit_proof.replace(
            "SECOND_JUNIOR_TRANSIT tick=33600 original_first_priest=888",
            "SECOND_JUNIOR_TRANSIT tick=33600 original_first_priest=777"),
        second_transit_proof.replace("ghost_unit=1006", "ghost_unit=0"),
        second_transit_proof.replace("carrier=1 distance_sq=4.000",
                                     "carrier=0 distance_sq=4.000"),
        second_transit_proof.replace("distance_sq=4.000 original_second_staged=true command_issued=true",
                                     "distance_sq=26.000 original_second_staged=true command_issued=true"),
        second_transit_proof.replace("command_issued=true", "command_issued=false"),
        second_transit_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_second_junior_transit_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified second-Junior physical transit accepted")
    for broken in (
        second_pickup_proof.replace("tick=33300", "tick=33000"),
        second_pickup_proof.replace(
            "PASS REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP tick=33300 "
            "original_first_priest=888",
            "PASS REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP tick=33300 "
            "original_first_priest=777"),
        second_pickup_proof.replace("second_depot=0 carrier=1",
                                    "second_depot=1 carrier=1"),
        second_pickup_proof.replace("carrier=1", "carrier=0"),
        second_pickup_proof.replace("distance_sq=4.000", "distance_sq=26.000"),
        second_pickup_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_second_junior_pickup_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified second-Junior physical pickup accepted")
    for broken in (
        second_ghost_proof.replace("tick=33000", "tick=32400"),
        second_ghost_proof.replace("original_first_priest=888",
                                   "original_first_priest=777"),
        second_ghost_proof.replace("second_depot=1", "second_depot=0"),
        second_ghost_proof.replace("original_second_staged=true",
                                   "original_second_staged=false"),
    ):
        try:
            verify_reversal_second_junior_ghost_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified second Junior ghost accepted")
    for broken in (
        junior_build_proof.replace("tick=32700", "tick=32400"),
        junior_build_proof.replace("rebuilt_junior=1005", "rebuilt_junior=400"),
        junior_build_proof.replace("original_junior_station=400",
                                   "original_junior_station=1005"),
        junior_build_proof.replace("source=0 carrier=0 second_depot=1",
                                   "source=1 carrier=0 second_depot=1"),
        junior_build_proof.replace("second_depot=1 distance_sq=0.000",
                                   "second_depot=0 distance_sq=0.000"),
        junior_build_proof.replace("distance_sq=0.000", "distance_sq=5.000"),
        junior_build_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_first_junior_build_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified first-Junior native build accepted")
    for broken in (
        junior_transit_proof.replace("tick=32400", "tick=32100"),
        junior_transit_proof.replace(
            "PASS REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT tick=32400 "
            "rebuilt_intermediate=1002",
            "PASS REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT tick=32400 "
            "rebuilt_intermediate=1004"),
        junior_transit_proof.replace("held=1 source=0", "held=0 source=0"),
        junior_transit_proof.replace("second_depot=1", "second_depot=0"),
        junior_transit_proof.replace("distance_sq=3.250", "distance_sq=26.000"),
        junior_transit_proof.replace("ghost_unit=1003 original_priest_staged=true",
                                     "ghost_unit=1004 original_priest_staged=true"),
        junior_transit_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_first_junior_transit_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified first-Junior physical transit accepted")
    for broken in (
        junior_pickup_proof.replace("tick=32100", "tick=31920"),
        junior_pickup_proof.replace("rebuilt_intermediate=1002 original_intermediate_priest=887 "
            "original_junior_priest=888 child_writ=11 source_before",
            "rebuilt_intermediate=1004 original_intermediate_priest=887 "
            "original_junior_priest=888 child_writ=11 source_before"),
        junior_pickup_proof.replace("child_writ=11 source_before", "child_writ=12 source_before"),
        junior_pickup_proof.replace("source_after=0", "source_after=1"),
        junior_pickup_proof.replace("carrier_after=1", "carrier_after=0"),
        junior_pickup_proof.replace("second_depot=1", "second_depot=0"),
        junior_pickup_proof.replace("pickup_distance_sq=24.664",
                                    "pickup_distance_sq=25.001"),
        junior_pickup_proof.replace("pickup_distance_sq=24.664",
                                    "pickup_distance_sq=-1"),
        junior_pickup_proof.replace("pickup_station=100", "pickup_station=101"),
        junior_pickup_proof.replace("pickup_station=100", "pickup_station=0"),
        junior_pickup_proof.replace("pickup_tick=32090", "pickup_tick=31900"),
        junior_pickup_proof.replace("pickup_tick=32090", "pickup_tick=32101"),
        junior_pickup_proof.replace(" pickup_distance_sq=24.664", ""),
        junior_pickup_proof.replace(
            "PASS REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT",
            "UNVERIFIED REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT"),
        junior_pickup_proof.replace("original_priest_staged=true",
                                    "original_priest_staged=false"),
        junior_pickup_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_first_junior_pickup_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified first-Junior real-item pickup accepted")
    for broken in (
        junior_ghost_proof.replace("tick=31920", "tick=31860"),
        junior_ghost_proof.replace("rebuilt_intermediate=1002 original_intermediate_priest=887 "
            "original_junior_priest=888", "rebuilt_intermediate=1004 "
            "original_intermediate_priest=887 original_junior_priest=888"),
        junior_ghost_proof.replace("original_junior_priest=888", "original_junior_priest=887"),
        junior_ghost_proof.replace("junior_depots=2", "junior_depots=1"),
        junior_ghost_proof.replace("carrier=0", "carrier=1"),
        junior_ghost_proof.replace("rank=2-to-1", "rank=3-to-1"),
        junior_ghost_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_first_junior_ghost_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified first-Junior physical ghost accepted")

    for broken in (
        intermediate_build_proof.replace("tick=31800", "tick=31440"),
        intermediate_build_proof.replace("rebuilt_intermediate=1002", "rebuilt_intermediate=300"),
        intermediate_build_proof.replace("original_intermediate_priest=887 child_writ=10 rebuilt_intermediate=",
            "original_intermediate_priest=999 child_writ=10 rebuilt_intermediate="),
        intermediate_build_proof.replace("source=0 carrier=0 junior_depots=2",
            "source=1 carrier=0 junior_depots=2"),
        intermediate_build_proof.replace("distance_sq=0.000", "distance_sq=12.000"),
        intermediate_build_proof.replace("ghost=0 hierarchy", "ghost=1 hierarchy"),
        intermediate_build_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_intermediate_build_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified Intermediate physical build accepted")
    for broken in (
        transit_proof.replace("tick=31440", "tick=31260"),
        transit_proof.replace("held=1 source=0", "held=0 source=1"),
        transit_proof.replace("junior_depots=2 distance_sq", "junior_depots=1 distance_sq"),
        transit_proof.replace("distance_sq=4.000", "distance_sq=26.000"),
        transit_proof.replace("ghost_unit=991 original_priest", "ghost_unit=992 original_priest"),
        transit_proof.replace("original_priest_staged=true", "original_priest_staged=false"),
        transit_proof.replace("child_writ=10 held=1", "child_writ=11 held=1"),
        transit_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_intermediate_transit_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified Intermediate physical transit accepted")
    for broken in (
        pickup_proof.replace("source_after=0", "source_after=1"),
        pickup_proof.replace("carrier_after=1", "carrier_after=2"),
        pickup_proof.replace("junior_depots=2 distance_sq", "junior_depots=1 distance_sq"),
        pickup_proof.replace("distance_sq=3.250", "distance_sq=26.000"),
        pickup_proof.replace("original_priest_staged=true", "original_priest_staged=false"),
        pickup_proof.replace("tick=31200", "tick=31035"),
        pickup_proof.replace("child_writ=10 source_before", "child_writ=11 source_before"),
        pickup_proof.split("\n")[-1],
    ):
        try:
            verify_reversal_intermediate_pickup_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified Intermediate physical pickup accepted")
    for broken in (
        outbound_proof.replace("source_after=0", "source_after=1"),
        outbound_proof.replace("carrier_after=1", "carrier_after=2"),
        outbound_proof.replace("other_depots=3", "other_depots=2"),
        outbound_proof.replace("ghost_preserved_or_reconciled=true", "ghost_preserved_or_reconciled=false"),
        outbound_proof.replace("station_not_built=true", "station_not_built=false"),
        outbound_proof.replace("tick=30195", "tick=30194"),
        outbound_proof.replace("ghost_reconciled_0896=true", "ghost_reconciled_0896=false"),
        outbound_proof.split("\n")[1],
    ):
        try:
            verify_reversal_outbound_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unsafe Senior outbound custody proof accepted")
    for broken in (
        outbound_proof.replace("held=1 source=0", "held=0 source=1"),
        outbound_proof.replace("distance_sq=2.250", "distance_sq=25.500"),
        outbound_proof.replace("magos_priest=885", "magos_priest=886"),
        outbound_proof.replace("tick=30555", "tick=30194"),
        outbound_proof.replace("original_senior=873 original_priest=886 magos_priest",
                               "original_senior=874 original_priest=886 magos_priest"),
        outbound_proof.split("\n")[2],
    ):
        try:
            verify_reversal_outbound_transit_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unsafe Senior physical transit proof accepted")
    for broken in (
        outbound_proof.replace("rebuilt_senior=990", "rebuilt_senior=873"),
        outbound_proof.replace("source=0 carrier=0", "source=0 carrier=1"),
        outbound_proof.replace("prior_depots=3 ghost=0", "prior_depots=2 ghost=1"),
        outbound_proof.replace("hierarchy=magos-to-original-senior",
                               "hierarchy=unknown"),
        outbound_proof.replace("tick=30975", "tick=30554"),
        outbound_proof.split("\n")[3],
    ):
        try:
            verify_reversal_outbound_build_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unsafe Senior physical rebuild proof accepted")
    for broken in (
        outbound_proof.replace("intermediate_depot=1", "intermediate_depot=0"),
        outbound_proof.replace("junior_depots=2", "junior_depots=1"),
        outbound_proof.replace("carrier=0 rank=3-to-2", "carrier=1 rank=3-to-2"),
        outbound_proof.replace("rank=3-to-2", "rank=4-to-2"),
        outbound_proof.replace("rebuilt_senior=990 original_senior_priest=886",
                               "rebuilt_senior=991 original_senior_priest=886"),
        outbound_proof.replace("original_intermediate_priest=887",
                               "original_intermediate_priest=886"),
        outbound_proof.replace("tick=31035", "tick=30974"),
        outbound_proof.split("\n")[4],
    ):
        try:
            verify_reversal_intermediate_ghost_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified Intermediate physical ghost accepted")
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
    # 1057: the stock checkpoint is not a same-process Lua reload. It
    # requires the first physical pickup before saving, a distinct next tick,
    # unchanged child/parent/priest/writ, and no pre-save parent deposit.
    saved_stock = (
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_NATIVE_MINED source=15 wooden=1 iron=1\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_PICKUP item=wooden-chest carrier=77 held=1\n"
        + STOCK_CARRY_SAVE_MARKER
        + " tick=10000 child=15 parent=10 worker=77 writ=41 held=1 parent_received=0 child_iron=1\n")
    loaded_stock = (
        STOCK_CARRY_RELOAD_MARKER
        + " tick=10001 child=15 parent=10 worker=77 writ=41 held=1 parent_received=0 child_iron=1\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_DEPOSIT item=wooden-chest worker=77 parent=10 native_item_delta=1 held=0\n")
    verify_stock_carry_reload_log(saved_stock, loaded_stock)
    for bad_before, bad_after in (
        (saved_stock, loaded_stock.replace("worker=77", "worker=78")),
        (saved_stock, loaded_stock.replace("writ=41", "writ=42")),
        (saved_stock, loaded_stock.replace("child=15", "child=16")),
        (saved_stock, loaded_stock.replace("parent=10", "parent=11")),
        (saved_stock, loaded_stock.replace("tick=10001", "tick=10000")),
        (saved_stock.replace("RELOCATION_ENGINE_STOCK_PICKUP", "MISSING_PICKUP"), loaded_stock),
        (saved_stock.replace("held=1", "held=0"), loaded_stock),
        (saved_stock.replace("STOCK_CARRY_SAVE_REQUESTED", "NO_SAVE"), loaded_stock),
        (saved_stock.replace("STOCK_PICKUP item=", "STOCK_DEPOSIT item="), loaded_stock),
        (saved_stock, loaded_stock.replace("STOCK_CARRY_RELOAD", "NO_RELOAD")),
        (saved_stock, loaded_stock.replace("held=1", "held=0")),
    ):
        try:
            verify_stock_carry_reload_log(bad_before, bad_after)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified independent stock-carry reload accepted")
    good_stock_relocation = (
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_WORKER_RESERVED worker=10 writ=41\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_NATIVE_MINED source=15 wooden=1 iron=1 native_mines=2 native_transfers=2 fixture_not_ore_credit=true\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_GHOST_POSITION_VERIFIED ghost=20 offset_sq=0.5\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_CANDIDATE_RESERVED candidate=15 writ=41\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_PREFLIGHT_PASS ghost=20 worker=10 writ=41 remote_mining_denied=true\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_PICKUP item=wooden-chest carrier=77 held=1\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_DEPOSIT item=wooden-chest worker=77 parent=10 native_item_delta=1 held=0\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_PARENT_CONGESTED tick=10010 parent=10 slots=19 filler=stone-furnace native_mines=19 wooden=1 iron=0\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_PICKUP item=iron-chest carrier=77 held=1\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_PARENT_FULL_DENIED tick=10020 parent=10 worker=77 held_iron=1 parent_iron=0 filler=19\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_PARENT_SPACE_RESTORED tick=10080 parent=10 worker=77 held_iron=1 released_filler=1 native_transfer=true\n"
        "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_DEPOSIT item=iron-chest worker=77 parent=10 native_item_delta=1 held=0\n"
        "[TP-GROUND-RANK-TEST] PASS RELOCATION_ENGINE_STOCK_CONGESTION tick=10100 parent=10 worker=77 blocked=1 recovered=1 filler=19 reserved_filler=1 parent_iron=1 held_iron=0\n"
        "RELOCATION_ENGINE_MINED carried=1\n"
        "[TP-GROUND-RANK-TEST] PASS RELOCATION_ENGINE_STOCK_EVACUATION old_station=15 worker=77 wooden=1 iron=1 journeys=2 held=0 source_removed=true\n"
        + RELOCATION_MARKER +
        " tick=10000 old_station=15 new_station=27 priest=33 held=0 net_station_delta=0")
    verify_relocation_log(good_stock_relocation)
    for bad in ("",
                good_stock_relocation.replace("STOCK_PARENT_FULL_DENIED", "NO_FULL_DENIAL"),
                good_stock_relocation.replace("STOCK_PARENT_SPACE_RESTORED", "NO_SPACE_RESTORED"),
                good_stock_relocation.replace("native_mines=19", "native_mines=18"),
                good_stock_relocation.replace("filler=19", "filler=18"),
                good_stock_relocation.replace("tick=10080", "tick=10020"),
                good_stock_relocation.replace(
                    "STOCK_PARENT_CONGESTED tick=10010",
                    "STOCK_PARENT_CONGESTED tick=10021"),
                good_stock_relocation.replace(
                    "STOCK_PARENT_FULL_DENIED tick=10020",
                    "STOCK_PARENT_FULL_DENIED tick=10009"),
                good_stock_relocation.replace(
                    "STOCK_PARENT_SPACE_RESTORED tick=10080",
                    "STOCK_PARENT_SPACE_RESTORED tick=10101"),
                good_stock_relocation.replace(
                    "STOCK_CONGESTION tick=10100",
                    "STOCK_CONGESTION tick=10079"),
                good_stock_relocation.replace(
                    "STOCK_PARENT_CONGESTED tick=10010 parent=10",
                    "STOCK_PARENT_CONGESTED tick=10010 parent=11"),
                good_stock_relocation.replace(
                    "STOCK_PARENT_FULL_DENIED tick=10020 parent=10 worker=77",
                    "STOCK_PARENT_FULL_DENIED tick=10020 parent=10 worker=78"),
                good_stock_relocation.replace("reserved_filler=1", "reserved_filler=0"),
                good_stock_relocation.replace(
                    "[TP-GROUND-RANK-TEST] RELOCATION_ENGINE_STOCK_DEPOSIT item=iron-chest worker=77 parent=10 native_item_delta=1 held=0\n", ""),
                good_stock_relocation.replace("journeys=2", "journeys=1"),
                good_stock_relocation.replace("native_item_delta=1", "native_item_delta=0", 1),
                good_stock_relocation.replace("native_item_delta=1", "native_item_delta=2", 1),
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
        "ORE_ENGINE_SITE_SEARCH regions_checked=2 natural_ore_candidates=17 chosen_region=2 bounded=true\n"
        "ORE_ENGINE_SITE_ISOLATED min_relocation_separation_sq=150000 required_sq=121104 hierarchy_peer_reach=220\n"
        "ORE_ENGINE_NATURAL_TARGET_SELECTED resource=iron-ore amount=10 "
        "magos=100 senior=101 intermediate=102 junior=103 "
        "fixture_stations_not_construction_credit=true\n"
        "ORE_ENGINE_ROUTE_VERIFIED junior=103 intermediate=102 senior=101 magos=100\n"
        "ORE_ENGINE_MINED natural_before=10 natural_after=9 held=1\n"
        "ORE_ENGINE_HOP hop=1 from=103 to=102 counted=1 receipt_before=0 receipt_after=1\n"
        "ORE_ENGINE_HOP hop=2 from=102 to=101 counted=1 receipt_before=4 receipt_after=5\n"
        "ORE_ENGINE_HOP hop=3 from=101 to=100 counted=1 receipt_before=0 receipt_after=1\n"
        "PASS ORE_ENGINE_COUNTED_MAGOS_RETURN natural_mined=1 physical_hops=3 "
        "magos_received=1 held=0")
    verify_ore_return_log(ore_proof)
    verify_machine_integration_source_0994()
    fixture_source = (pathlib.Path(__file__).resolve().parents[1] /
                      "tests/scenarios/all-ground-ranks/ground_rank_harness.lua"
                      ).read_text(encoding="utf-8")
    try:
        verify_machine_integration_source_0994(
            fixture_source.replace(
                'test.machine_courier=true',
                'mission.return_courier_0837=nil\\n    test.machine_courier=true', 1))
    except AssertionError as exc:
        if "erased prior Magos courier custody" not in str(exc):
            raise
    else:
        raise AssertionError("0997 reset of completed physical courier was accepted")
    # 0999: a broad, unfiltered receipt can belong to an unrelated drill.
    # Reject an engine fixture that drops either exact physical source ID.
    for broken_source in (
        fixture_source.replace(
            "chain[4],mission,machine.drill_unit,machine.chest_unit)",
            "chain[4],mission)", 1),
        fixture_source.replace(
            "ORE_ENGINE_MACHINE_RECEIPT_PROVENANCE_REJECTED",
            "ORE_ENGINE_MACHINE_RECEIPT_IGNORED", 1),
    ):
        try:
            verify_machine_integration_source_0994(broken_source)
        except AssertionError as exc:
            if "physical machine-return invariant missing" not in str(exc):
                raise
        else:
            raise AssertionError("0999 unscoped or unguarded drill receipt accepted")
    # 1003: A first machine-produced station debit occurs at terminal
    # index 4. Regressions must reject a fixture that accidentally treats
    # that physical pickup as an upstream-only index 2/3 transfer, skips
    # the claimed drill receipt, or drops its exact source inventory delta.
    for broken_source in (
        fixture_source.replace(
            "local machine_terminal_pickup=test.machine_courier and idx==4",
            "local machine_terminal_pickup=false", 1),
        fixture_source.replace(
            "local machine_terminal_pickup=test.machine_courier and idx==4\n"
            '      and courier.source_kind_0991=="drill-output"\n'
            "      and courier.drill_receipt_claimed_0991==true",
            "local machine_terminal_pickup=test.machine_courier and idx==4\n"
            '      and courier.source_kind_0991=="drill-output"\n'
            "      and courier.drill_receipt_claimed_0991~=nil", 1),
        fixture_source.replace("and after==before-1",
                               "and after>=0", 1),
        fixture_source.replace("local hop=courier.hop_index or 1",
                               "local hop=courier.hop_index", 1),
        fixture_source.replace(
            "courier.source_station_unit==physical_source.station.unit_number",
            "true", 1),
        fixture_source.replace("and source_matches and before and before>=1",
                               "and before and before>=1", 1),
    ):
        try:
            verify_machine_integration_source_0994(broken_source)
        except AssertionError as exc:
            if "physical machine-return invariant missing" not in str(exc):
                raise
        else:
            raise AssertionError("1004 unverified machine terminal pickup accepted")
    machine_proof = (
        ore_proof + "\n"
        "ORE_ENGINE_MACHINE_PREPARED drill=901 chest=902 natural_before=30 physical_fixture_coal=5\n"
        "ORE_ENGINE_MACHINE_0528_DEPOSIT drill=901 chest=902 receiver_debit=2 station_deposit=2 "
        "natural_before=30 natural_after=28 receipt_verified=true\n"
        "ORE_ENGINE_MACHINE_PICKUP drill=901 chest=902 physical_station_debit=1 held=1\n"
        "ORE_ENGINE_MACHINE_HOP hop=1 from=103 to=102 counted=1 receipt_before=0 receipt_after=1\n"
        "ORE_ENGINE_MACHINE_HOP hop=2 from=102 to=101 counted=1 receipt_before=1 receipt_after=2\n"
        "ORE_ENGINE_MACHINE_HOP hop=3 from=101 to=100 counted=1 receipt_before=1 receipt_after=2\n"
        "PASS ORE_ENGINE_MACHINE_MAGOS_RETURN machine_receipt_verified=true physical_hops=3 "
        "magos_received_total=2 baseline=1 held=0 original_drill=901")
    verify_machine_return_log_0994(machine_proof)
    verify_native_engine_source_1014()
    native_proof = (machine_proof + "\n"
        "ORE_ENGINE_NATIVE_RECOVERED drill=901 receiver=902 drill_item_delta=1 "
        "chest_item_delta=1 receiver_iron_transferred=2 fixture_coal=4 no_ore_created=true\n"
        "ORE_ENGINE_NATIVE_0338_DRILL built=1001 recovered=901 physical_item_debit=1\n"
        "ORE_ENGINE_NATIVE_0338_RECEIVER built=1002 recovered=902 physical_item_debit=1\n"
        "PASS ORE_ENGINE_NATIVE_0338_0528 drill=1001 receiver=1002 "
        "drill_item_debit=1 receiver_item_debit=1 fuel_station_debit=2 "
        "fuel_drill_credit=2 fixture_coal=4 physical_builder=true physical_fuel=true\n"
        "PASS ORE_ENGINE_NATIVE_MACHINE_MAGOS_RETURN drill=1001 receiver=1002 "
        "physical_hops=3 counted_magos_total=3 "
        "native_machine_source=true no_synthetic_ore=true")
    verify_native_engine_log_1014(native_proof)
    for mutation in (
        native_proof.replace("built=1001 recovered=901", "built=901 recovered=901"),
        native_proof.replace("built=1002 recovered=902", "built=1002 recovered=903"),
        native_proof.replace("fuel_drill_credit=2", "fuel_drill_credit=3"),
        native_proof.replace("drill_item_debit=1", "drill_item_debit=0"),
        native_proof.replace("fixture_coal=4 physical_builder",
                             "fixture_coal=7 physical_builder"),
        native_proof.replace("ORE_ENGINE_NATIVE_0338_RECEIVER",
                             "ORE_ENGINE_NATIVE_UNVERIFIED_RECEIVER"),
        native_proof.replace("physical_hops=3 counted_magos_total=3",
                             "physical_hops=2 counted_magos_total=3"),
        native_proof.replace("counted_magos_total=3",
                             "counted_magos_total=2"),
        native_proof.replace("MAGOS_RETURN drill=1001 receiver=1002",
                             "MAGOS_RETURN drill=901 receiver=1002"),
        native_proof.replace("PASS ORE_ENGINE_NATIVE_MACHINE_MAGOS_RETURN",
                             "UNVERIFIED ORE_ENGINE_NATIVE_MACHINE_MAGOS_RETURN"),
    ):
        try:
            verify_native_engine_log_1014(mutation)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified native 0338/0528 engine claim accepted")
    for removed in (
        'receipt.request_value==task.request',
        'receipt.request_value==task.receiver_request',
        'proof.source_after==proof.source_before-proof.count',
        'proof.destination_after==proof.destination_before+proof.count',
    ):
        try:
            verify_native_engine_source_1014(fixture_source.replace(removed, "true", 1))
        except AssertionError:
            pass
        else:
            raise AssertionError("native engine fixture custody guard removal accepted")
    for broken in (
        machine_proof.replace("drill=901 chest=902 receiver_debit",
                              "drill=903 chest=902 receiver_debit"),
        machine_proof.replace("natural_after=28", "natural_after=30"),
        machine_proof.replace("station_deposit=2", "station_deposit=3"),
        machine_proof.replace("physical_station_debit=1", "physical_station_debit=0"),
        machine_proof.replace("hop=2 from=102 to=101", "hop=2 from=103 to=101"),
        machine_proof.replace("receipt_after=2", "receipt_after=3"),
        machine_proof.replace("magos_received_total=2", "magos_received_total=1"),
        machine_proof.replace("baseline=1", "baseline=2"),
        machine_proof.replace("machine_receipt_verified=true", "machine_receipt_verified=false"),
        machine_proof.replace("ORE_ENGINE_MACHINE_0528_DEPOSIT", "UNVERIFIED_DEPOSIT"),
        machine_proof.replace("ORE_ENGINE_MACHINE_PICKUP", "UNVERIFIED_PICKUP"),
    ):
        try:
            verify_machine_return_log_0994(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError("invalid machine-source physical proof accepted")
    save_line = (ORE_CARRY_SAVE_MARKER +
        " tick=10100 source=103 destination=102 priest=1103 held=1 hop=1 prior_receipts=0")
    reload_line = (ORE_CARRY_RELOAD_MARKER +
        " tick=10101 source=103 destination=102 priest=1103 held=1 hop=1 prior_receipts=0")
    verify_ore_carry_reload_log(save_line, reload_line)
    for invalid in (reload_line.replace("priest=1103", "priest=1104"),
                    reload_line.replace("held=1", "held=0"),
                    reload_line.replace("source=103", "source=104"),
                    reload_line.replace("prior_receipts=0", "prior_receipts=1"),
                    ""):
        try:
            verify_ore_carry_reload_log(save_line, invalid)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unverified carried-ore reload accepted")
    for broken in (ore_proof.replace("natural_after=9", "natural_after=10"),
                   ore_proof.replace("regions_checked=2", "regions_checked=5"),
                   ore_proof.replace("chosen_region=2", "chosen_region=3"),
                   ore_proof.replace("natural_ore_candidates=17", "natural_ore_candidates=0"),
                   ore_proof.replace("ORE_ENGINE_SITE_SEARCH", "ORE_ENGINE_SEARCH_UNVERIFIED"),
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
    if (harness.count("radius=10") < 4
            or "ORE_ENGINE_NO_NATURAL_ORE_WITH_BUILDABLE_ROUTE regions=" not in harness
            or "ORE_ENGINE_SITE_SEARCH" not in harness):
        raise AssertionError("bounded distant natural-ore search regression")
    if (harness.count('game.auto_save("tech-priests-ci-ore-carried")') != 1
            or harness.count("PASS ORE_ENGINE_CARRIER_RELOAD") != 1
            or "ORE_ENGINE_CARRIED_RELOAD_CUSTODY_INVALID" not in harness):
        raise AssertionError("independent physical ore-custody reload gate missing")
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

    robot_positive = (
        "ROBOT_ENGINE_S2_SOURCE_MINED tick=100 source_unit=10 "
        "provider_unit=11 stock=1 physical_mine=true\n"
        "ROBOT_ENGINE_S2_REQUEST tick=110 magos=20 priest=21 port=22 "
        "powered=true robots=3 network_stock=1\n"
        "ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_CUT_1340 tick=110 "
        "magos=20 priest=21 removed_robots=3 station_stock=1 "
        "request_retained=true\n"
        "PASS ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_REFUSAL_1340 tick=290 "
        "magos=20 priest=21 ghost=0 claim=0 station_stock=1 "
        "removed_robots=3 restored_robots=3 request_retained=true "
        "item_conserved=true\n"
        "ROBOT_ENGINE_S2_GHOST tick=310 magos=20 magos_priest=21 "
        "port=22 network_stock_before=1 ghost=1\n"
        "ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT tick=320 station=30 robot=31\n"
        "PASS ROBOT_ENGINE_S2_PHYSICAL_BUILD tick=340 magos=20 "
        "magos_priest=21 station=30 priest=32 robot=31 "
        "source_delta=1 network_delta=1 ghost=0 "
        "hierarchy=direct-senior robot_event=on_robot_built_entity"
    )
    verify_robot_engine_s2_log(robot_positive)
    for old, new in (
        ("physical_mine=true", "physical_mine=false"),
        ("network_stock_before=1", "network_stock_before=0"),
        ("robot=31 source_delta=1", "robot=31 source_delta=0"),
        ("network_delta=1", "network_delta=0"),
        ("ghost=0 hierarchy", "ghost=1 hierarchy"),
        ("hierarchy=direct-senior", "hierarchy=unpaired"),
        ("robot_event=on_robot_built_entity", "robot_event=script"),
        ("station=30 priest=32", "station=33 priest=32"),
        ("robot=31 source_delta=1", "robot=34 source_delta=1"),
        ("tick=320 station=30", "tick=90 station=30"),
        ("ROBOT_ENGINE_S2_REQUEST tick=110", "NO_REQUEST tick=110"),
        ("powered=true robots=3", "powered=true robots=0"),
        ("ROBOTLESS_CUT_1340 tick=110", "ROBOTLESS_CUT_1340 tick=111"),
        ("removed_robots=3 station_stock=1", "removed_robots=2 station_stock=1"),
        ("REFUSAL_1340 tick=290", "REFUSAL_1340 tick=289"),
        ("ghost=0 claim=0 station_stock=1", "ghost=1 claim=0 station_stock=1"),
        ("ghost=0 claim=0 station_stock=1", "ghost=0 claim=1 station_stock=1"),
        ("removed_robots=3 restored_robots=3", "removed_robots=3 restored_robots=2"),
        ("request_retained=true item_conserved=true",
         "request_retained=true item_conserved=false"),
        ("REFUSAL_1340 tick=290 magos=20 priest=21",
         "REFUSAL_1340 tick=290 magos=20 priest=22"),
        ("ROBOT_ENGINE_S2_GHOST tick=310", "ROBOT_ENGINE_S2_GHOST tick=289"),
        ("ROBOT_ENGINE_S2_REQUEST tick=110 magos=20 priest=21 port=22",
         "ROBOT_ENGINE_S2_REQUEST tick=110 magos=20 priest=21 port=23"),
    ):
        bad = robot_positive.replace(old, new, 1)
        try:
            verify_robot_engine_s2_log(bad)
        except RuntimeError:
            pass
        else:
            raise AssertionError("S2 unsafe native robot evidence accepted: " + old)
    # Duplicate native receipt events may not falsely establish one refusal.
    receipt = robot_positive.split(
        "PASS ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_REFUSAL_1340", 1)[1]
    receipt = "PASS ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_REFUSAL_1340" + receipt.split("\n", 1)[0]
    try:
        verify_robot_engine_s2_log(robot_positive + "\n" + receipt)
    except RuntimeError:
        pass
    else:
        raise AssertionError("duplicate native robotless refusal was credited")


    # 1360: a separate engine process, not a second fixture setup, must
    # read the original mid-flight ghost/task/substation custody and then
    # observe genuine power restoration and native robot construction.
    s3_before = (
        "ROBOT_ENGINE_S2_MIDFLIGHT_POWER_CUT_1350 tick=400 "
        "magos=20 priest=21 observed_flying_robots=1 "
        "robot=25 ghost=1 substation_custody=1\n"
        "[TP-GROUND-RANK-TEST] ROBOT_ENGINE_S2_MIDFLIGHT_SAVE_REQUESTED_1360 tick=400 "
        "magos=20 priest=21 robot=25 ghost=1 substation_custody=1\n"
        "1.111 Info AppManager.cpp:324: Saving to "
        "_autosave-tech-priests-ci-robot-midflight (blocking).\n"
        "1.222 Info AppManagerStates.cpp:2111: Saving finished\n"
    )
    s3_after = (
        "PASS ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_CUSTODY_1360 tick=460 "
        "magos=20 priest=21 robot=25 ghost=1 substation_held=1 "
        "power_disconnected=true original_task_retained=true "
        "original_request_retained=true built=0 native_build_event=0\n"
        "PASS ROBOT_ENGINE_S2_NATIVE_MIDFLIGHT_POWER_RECOVERY_1350 tick=520 "
        "magos=20 priest=21 ghost=1 native_build_event=0 "
        "substation_mined=1 substation_rebuilt=1 original_task_retained=true "
        "original_request_retained=true\n"
        "ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT tick=700 station=30 robot=31\n"
        "PASS ROBOT_ENGINE_S2_PHYSICAL_BUILD tick=740 magos=20 "
        "magos_priest=21 station=30 priest=32 robot=31 "
        "source_delta=1 network_delta=1 ghost=0 hierarchy=direct-senior "
        "robot_event=on_robot_built_entity\n"
    )
    verify_robot_midflight_reload_1360_log(s3_before, s3_after)
    for old, new in (
        ("substation_held=1", "substation_held=0"),
        ("original_task_retained=true", "original_task_retained=false"),
        ("power_disconnected=true", "power_disconnected=false"),
        ("built=0 native_build_event=0", "built=1 native_build_event=0"),
        ("magos=20 priest=21 robot=25 ghost=1", "magos=20 priest=21 robot=26 ghost=1"),
        ("magos=20 priest=21 robot=25 ghost=1", "magos=20 priest=99 robot=25 ghost=1"),
        ("tick=520 magos=20", "tick=400 magos=20"),
        ("station=30 robot=31", "station=31 robot=31"),
        ("ghost=0 hierarchy=direct-senior", "ghost=1 hierarchy=direct-senior"),
    ):
        bad = s3_after.replace(old, new, 1)
        try:
            verify_robot_midflight_reload_1360_log(s3_before, bad)
        except RuntimeError:
            pass
        else:
            raise AssertionError("S3 forged reload receipt accepted: " + old)
    for bad_before in (
        s3_before.replace("Saving finished", "Saving aborted"),
        s3_before.replace("observed_flying_robots=1", "observed_flying_robots=0"),
        s3_before.replace("robot=25 ghost=1", "robot=26 ghost=1", 1),
        s3_before.replace("SAVE_REQUESTED_1360", "UNRELATED_SAVE_1360"),
    ):
        try:
            verify_robot_midflight_reload_1360_log(bad_before, s3_after)
        except RuntimeError:
            pass
        else:
            raise AssertionError("S3 missing physical pre-save evidence accepted")

    frontier_positive = (
        "ROBOT_FRONTIER_1080_SOURCE tick=200 magos=20 priest=21 "
        "port=22 poles=8 roboports=4 magos_poles=4 magos_ports=2 "
        "senior_poles=4 senior_ports=2 senior=23 senior_priest=24 "
        "mined=true electric=7 logistic=9\n"
        "ROBOT_FRONTIER_1080_RECEIPT tick=300 kind=pole unit=40 "
        "grid=7 poles=1 ports=0\n"
        "ROBOT_FRONTIER_1080_SEGMENT_PROGRESS tick=400 segment=1 "
        "port=41 remaining_tiles=35.00 previous_tiles=70.00 "
        "item_debit=0338-native-receipt\n"
        "ROBOT_FRONTIER_1080_RECEIPT tick=400 kind=port unit=41 "
        "grid=7 poles=1 ports=1\n"
        "ROBOT_FRONTIER_1080_RECEIPT tick=500 kind=pole unit=42 "
        "grid=7 poles=2 ports=1\n"
        "ROBOT_FRONTIER_1080_SEGMENT_PROGRESS tick=600 segment=2 "
        "port=43 remaining_tiles=10.00 previous_tiles=35.00 "
        "item_debit=0338-native-receipt\n"
        "ROBOT_FRONTIER_1080_RECEIPT tick=600 kind=port unit=43 "
        "grid=7 poles=2 ports=2\n"
        "PASS ROBOT_FRONTIER_1080_POWERED_COVERAGE tick=700 "
        "magos=20 priest=21 source_port=22 final_port=43 "
        "electric=7 logistic=10 poles=2 ports=2 successive_port_progress=true "
        "pole_delta=2 port_delta=2 magos_poles=1 magos_ports=0 "
        "senior_poles=1 senior_ports=2 target_covered=true custody=physical-0338"
    )
    verify_robot_frontier_native_1080_log(frontier_positive)
    # The failed native two-port boundary must expose the real last broker
    # observation while still rejecting absent physical construction proof.
    missing_native = (
        frontier_positive.split("PASS ROBOT_FRONTIER_1080_POWERED_COVERAGE")[0]
        + "ROBOT_FRONTIER_1080_BROKER_OBSERVE tick=680 "
        + "pending_kind=pole senior_task_phase=move-source "
        + "senior_order=assignment senior_dispatch=acquisition"
    )
    try:
        verify_robot_frontier_native_1080_log(missing_native)
    except RuntimeError as exc:
        diagnostic = str(exc)
        assert ("final=False" in diagnostic
                and "last_native_observations=" in diagnostic
                and "senior_task_phase=move-source" in diagnostic), diagnostic
    else:
        raise AssertionError("missing native two-port evidence accepted")
    for old, new in (
        ("mined=true", "mined=false"),
        ("senior_priest=24", "senior_priest=21"),
        ("grid=7 poles=2 ports=2", "grid=8 poles=2 ports=2"),
        ("pole_delta=2", "pole_delta=1"),
        ("port_delta=2", "port_delta=1"),
        ("magos_poles=1 magos_ports=0", "magos_poles=2 magos_ports=0"),
        ("senior_poles=1 senior_ports=2", "senior_poles=1 senior_ports=1"),
        ("source_port=22 final_port=43", "source_port=22 final_port=22"),
        ("kind=port unit=43", "kind=port unit=41"),
        ("tick=600 kind=port", "tick=100 kind=port"),
        ("target_covered=true", "target_covered=false"),
        ("successive_port_progress=true", "successive_port_progress=false"),
        ("ports=2 successive_port_progress", "ports=1 successive_port_progress"),
        ("segment=2 port=43", "segment=2 port=42"),
        ("remaining_tiles=10.00 previous_tiles=35.00",
         "remaining_tiles=35.00 previous_tiles=35.00"),
        ("remaining_tiles=10.00 previous_tiles=35.00",
         "remaining_tiles=10.00 previous_tiles=40.00"),
        ("item_debit=0338-native-receipt", "item_debit=planned-only"),
        ("electric=7 logistic=10", "electric=8 logistic=10"),
    ):
        try:
            verify_robot_frontier_native_1080_log(
                frontier_positive.replace(old, new, 1))
        except RuntimeError:
            pass
        else:
            raise AssertionError("unsafe native frontier evidence accepted: " + old)
    remote_positive = frontier_positive + (
        "\nROBOT_FRONTIER_1111_NATIVE_ROBOT_EVENT tick=800 "
        "robot=56 station=57\n"
        "PASS ROBOT_FRONTIER_1111_REMOTE_ROBOT_OUTPOST tick=900 "
        "magos=20 magos_priest=21 senior=23 senior_priest=24 "
        "remote_station=57 remote_priest=58 robot=56 "
        "physical_provider_delta=1 ghost=0 grid=7 paired_rank=intermediate"
    )
    verify_robot_frontier_native_1111_log(remote_positive)
    for bad in (
        remote_positive.replace(
            "ROBOT_FRONTIER_1111_NATIVE_ROBOT_EVENT tick=800 robot=56 station=57\n",
            ""),
        remote_positive.replace("remote_station=57", "remote_station=59"),
        remote_positive.replace("remote_priest=58", "remote_priest=24"),
        remote_positive.replace("robot=56 station=57", "robot=59 station=57"),
        remote_positive.replace("ghost=0 grid=7", "ghost=1 grid=7"),
        remote_positive.replace("physical_provider_delta=1",
                                "physical_provider_delta=0"),
        remote_positive.replace("ghost=0 grid=7", "ghost=0 grid=8"),
        remote_positive.replace("tick=900 magos=20", "tick=799 magos=20"),
        remote_positive + "\nROBOT_FRONTIER_1111_NATIVE_ROBOT_EVENT "
                          "tick=801 robot=60 station=61",
    ):
        try:
            verify_robot_frontier_native_1111_log(bad)
        except RuntimeError:
            pass
        else:
            raise AssertionError("unsafe native robot outpost evidence accepted")


    ore_positive = (
        "ROBOT_FRONTIER_1121_NATURAL_SEED_SELECTED tick=100 "
        "seed=1071002 ore_x=88.5 ore_y=17.5 natural_generated=true\n"
        + remote_positive) + (
        "\nROBOT_FRONTIER_1120_NATURAL_ORE_OBJECTIVE tick=950 "
        "magos=20 magos_priest=21 senior=23 senior_priest=24 "
        "remote_station=57 remote_priest=58 ore=iron-ore "
        "patch_before=40 magos_before=0 natural_generated=true\n"
        "PASS ROBOT_FRONTIER_1120_NATIVE_ORE_RETURN tick=1200 "
        "magos=20 magos_priest=21 senior=23 senior_priest=24 "
        "remote_station=57 remote_priest=58 ore=iron-ore "
        "patch_before=40 patch_after=39 magos_before=0 magos_after=1 "
        "source_depletion=nil "
        "hops=2 receipts=2 source=natural-ore custody=empty"
    )
    verify_robot_frontier_native_1120_log(ore_positive)
    for case_number, broken in enumerate((
        ore_positive.replace("ROBOT_FRONTIER_1121_NATURAL_SEED_SELECTED",
                             "ROBOT_FRONTIER_1121_NO_SEED"),
        ore_positive.replace("seed=1071002", "seed=1072002"),
        ore_positive.replace("ore_y=17.5", "ore_y=0.5"),
        ore_positive.replace("natural_generated=true", "natural_generated=false", 1),
        ore_positive.replace("patch_after=39", "patch_after=40"),
        ore_positive.replace(" source_depletion=nil", ""),
        ore_positive.replace("magos_after=1", "magos_after=2"),
        ore_positive.replace("remote_priest=58 ore=iron-ore patch_before=40 patch_after",
                             "remote_priest=24 ore=iron-ore patch_before=40 patch_after"),
        ore_positive.replace("hops=2 receipts=2", "hops=1 receipts=1"),
        ore_positive.replace("source=natural-ore", "source=drill-output"),
        ore_positive.replace("natural_generated=true", "natural_generated=false"),
        ore_positive + "\\nPASS ROBOT_FRONTIER_1120_NATIVE_ORE_RETURN tick=1201 "
            "magos=20 magos_priest=21 senior=23 senior_priest=24 "
            "remote_station=57 remote_priest=58 ore=iron-ore "
            "patch_before=40 patch_after=39 magos_before=0 magos_after=1 "
            "source_depletion=nil "
            "hops=2 receipts=2 source=natural-ore custody=empty",
    ), start=1):
        try:
            verify_robot_frontier_native_1120_log(broken)
        except RuntimeError:
            pass
        else:
            raise AssertionError(
                "unsafe native Method II ore evidence accepted: mutation "
                + str(case_number))

    print("save/reload runner self-test PASS")
    return 0



def ci_stable_pair_script_1291(content: str, start: int, end: int,
                               population: int,
                               creation_log: str | None) -> dict[str, object] | None:
    """Measure native all-mod scriptUpdate in the verified paired interval.

    The actual Factorio --create log, not the later --benchmark log, proves
    that the CI-only save began at game tick zero. Match that physical save
    provenance before aligning verbose benchmark ticks with game.tick.
    This remains diagnostic and cannot satisfy construction or ore gates.
    """
    created = re.findall(
        r"CI_FIVE_PROFILE_1291_CREATED tick=(\d+) stations="
        + str(population) + r" requested=" + str(population)
        + r" setup=ci-only-real-entities", creation_log or "")
    if created != ["0"] or not (0 <= start < end <= 30000):
        return None
    headers = re.findall(r"(?m)^[ \t]*tick,scriptUpdate(,?)[ \t]*$", content)
    if len(headers) != 1:
        return None
    native_csv = headers[0] == ","
    pattern = (r"(?m)^t(\d+),([0-9]+(?:\.[0-9]+)?),$" if native_csv
               else r"(?m)^(\d+),([0-9]+(?:\.[0-9]+)?)$")
    rows = re.findall(pattern, content)
    if len(rows) != 30000:
        return None
    durations = []
    for index, (tick_text, duration_text) in enumerate(rows):
        if int(tick_text) != index:
            return None
        duration = float(duration_text)
        if not math.isfinite(duration) or duration < 0:
            return None
        if start <= index < end:
            durations.append(duration / 1000000.0)
    if len(durations) != end - start:
        return None
    ordered = sorted(durations)
    return {
        "stable_all_mod_script_mean_ms_per_tick":
            round(sum(ordered) / len(ordered), 6),
        "stable_all_mod_script_p95_ms_per_tick":
            round(ordered[math.ceil(0.95 * len(ordered)) - 1], 6),
        "stable_all_mod_script_sample_count": len(ordered),
    }


def ci_five_observation_1291(content: str, expected: int = 5, *,
                             creation_log: str | None = None) -> dict[str, object]:
    """Native 5/25/100-pair population, no earned resource receipt."""
    if expected not in (5, 25, 100):
        raise ValueError("unproven profiling population")
    native = native_efficiency_observation_1062(content)
    starts = re.findall(
        r"CI_FIVE_PROFILE_1291_START tick=(\d+) all=(\d+) "
        r"original=(\d+) requested=" + str(expected), content)
    ends = re.findall(
        r"CI_FIVE_PROFILE_1291_END tick=(\d+) all=(\d+) "
        r"original=(\d+) requested=" + str(expected) + r" samples=(\d+) "
        r"bad=(\d+) identity_stable=(true|false) interval=60", content)
    result = {
        "schema": "ci-paired-performance-1291-v1",
        "scenario": f"separate-ci-initialized-{expected}-station-autonomy",
        "requested_population": expected,
        "paired_population_verified": None,
        "observed_interval_ticks": 60,
        "engine_ups_including_warmup": native["engine_benchmark_ups"],
        "engine_mean_ms_per_update_including_warmup":
            native["engine_update_average_ms_per_tick"],
        "all_mod_script_mean_ms_per_tick_including_warmup":
            native["script_average_ms_per_tick"],
        "all_mod_script_p95_ms_per_tick_including_warmup":
            native["script_p95_ms_per_tick"],
        "script_sample_coverage": native["script_sample_coverage"],
        "script_sample_count": native["script_sample_count"],
        "stable_all_mod_script_mean_ms_per_tick": None,
        "stable_all_mod_script_p95_ms_per_tick": None,
        "stable_all_mod_script_sample_count": None,
        "ore_per_1000_ticks": None,
        "first_delivery_ticks": None,
        "notes": "CI-created initial stations, authentic paired priests and engine "
                 "timings (including authentic startup); no physical station "
                 "construction or counted ore delivery. "
                 "Count/identity sampled every 60 ticks after actual pairing; "
                 "whole-run UPS and all-mod script timings include warmup. "
                 "Verified paired-window all-mod script timing is separate.",
    }
    if len(starts)==len(ends)==1:
        a,at,ao=map(int,starts[0])
        b,bt,bo,n,bad,stable=ends[0]
        b,bt,bo,n,bad=map(int,(b,bt,bo,n,bad))
        if (a>=600 and b>=11880 and b>a and (b-a)%60==0
                and n==(b-a)//60+1 and n>=180
                and at==ao==bt==bo==expected and bad==0
                and stable=="true" and "CI_FIVE_PROFILE_1291_UNAVAILABLE" not in content
                and native["engine_benchmark_updates"]==30000
                and native["script_sample_coverage"]=="complete"):
            result["paired_population_verified"]=expected
            result["first_observed_tick"]=a
            result["last_observed_tick"]=b
            result["observed_samples"]=n
            # Whole-run script cost includes population-dependent startup.
            # Publish a comparable 11,280-tick paired-window cost only when
            # the benchmark tick origin and all native samples are verified.
            stable = ci_stable_pair_script_1291(
                content, a, b, expected, creation_log)
            if stable is not None:
                result.update(stable)

    # Count only authentic source counters in the proven stable five-pair
    # interval. Missing data stays null; engine script timing includes warmup.
    activity_keys = ("routed_scans", "direct_scans", "movement_requests", "movement_collapses", "movement_priority_denials", "movement_stalled_repaths", "broker_processed", "broker_blocked")
    for key in activity_keys:
        result[key + "_per_1000_ticks"] = None
    result["broker_service_blocked_fraction"] = None
    activity_pattern = (
        r"CI_FIVE_PROFILE_1291_ACTIVITY start_tick=(\d+) end_tick=(\d+) "
        + " ".join(key + r"=(\d+|unmeasured)" for key in activity_keys))
    activity = re.findall(activity_pattern, content)
    if result["paired_population_verified"] == expected and len(activity) == 1:
        start, end, *observations = activity[0]
        start, end = int(start), int(end)
        if (start == result["first_observed_tick"]
                and end == result["last_observed_tick"] and end > start):
            elapsed = end - start
            counts = {}
            for key, val in zip(activity_keys, observations):
                if val != "unmeasured":
                    counts[key] = int(val)
                    result[key + "_per_1000_ticks"] = round(
                        counts[key] * 1000 / elapsed, 6)
            if counts.get("broker_processed", 0) > 0 and "broker_blocked" in counts:
                result["broker_service_blocked_fraction"] = round(
                    counts["broker_blocked"] / counts["broker_processed"], 6)
    return result


def self_test_ci_five_1291() -> None:
    log = (
        "CI_FIVE_PROFILE_1291_WAITING tick=600 all=0 original=0 requested=5\n"
        "CI_FIVE_PROFILE_1291_START tick=7200 all=5 original=5 requested=5\n"
        "CI_FIVE_PROFILE_1291_END tick=18480 all=5 original=5 "
        "requested=5 samples=189 bad=0 identity_stable=true interval=60\n"
        "CI_FIVE_PROFILE_1291_ACTIVITY start_tick=7200 end_tick=18480 "
        "routed_scans=120 direct_scans=6 movement_requests=12 "
        "movement_collapses=3 movement_priority_denials=2 "
        "movement_stalled_repaths=unmeasured broker_processed=160 "
        "broker_blocked=4\n"
        "  Performed 30000 updates in 150000.000 ms\n"
        "tick,scriptUpdate\n"
        + "".join(f"{i},1000000\n" for i in range(30000)))
    observed = ci_five_observation_1291(log)
    assert observed["paired_population_verified"] == 5
    assert observed["first_observed_tick"] == 7200
    assert observed["last_observed_tick"] == 18480
    assert observed["routed_scans_per_1000_ticks"] == round(120000 / 11280, 6)
    assert observed["movement_requests_per_1000_ticks"] == round(12000 / 11280, 6)
    assert observed["movement_stalled_repaths_per_1000_ticks"] is None
    assert observed["broker_service_blocked_fraction"] == 0.025
    assert observed["stable_all_mod_script_mean_ms_per_tick"] is None
    # Native 2.0.77 CSV, with startup at 1ms and the actual stable pair
    # interval at 3ms; a whole-run average cannot represent paired costs.
    source_rows = "".join(f"{i},1000000\n" for i in range(30000))
    native_rows = "".join(
        f"t{i},{3000000 if 7200 <= i < 18480 else 1000000},\n"
        for i in range(30000))
    # The real Factorio --create process writes CREATED to its own log.
    # The subsequent --benchmark log has START/END and native verbose CSV,
    # but must not be expected to repeat the creation-time marker.
    creation_log = (
        "CI_FIVE_PROFILE_1291_CREATED tick=0 stations=5 requested=5 "
        "setup=ci-only-real-entities\n")
    native_log = log.replace("tick,scriptUpdate\n" + source_rows,
                             "run 1:\ntick,scriptUpdate,\n" + native_rows)
    paired = ci_five_observation_1291(
        native_log, creation_log=creation_log)
    assert paired["paired_population_verified"] == 5
    assert paired["stable_all_mod_script_mean_ms_per_tick"] == 3.0
    assert paired["stable_all_mod_script_p95_ms_per_tick"] == 3.0
    assert paired["stable_all_mod_script_sample_count"] == 11280
    assert ci_five_observation_1291(native_log)[
        "stable_all_mod_script_mean_ms_per_tick"] is None
    # A forged marker in benchmark output cannot substitute for the distinct
    # actual --create log, and a wrong/duplicate creation marker cannot pass.
    assert ci_five_observation_1291(creation_log + native_log)[
        "stable_all_mod_script_mean_ms_per_tick"] is None
    for invalid_creation in (
        creation_log.replace("tick=0", "tick=60"),
        creation_log.replace("stations=5", "stations=25"),
        creation_log.replace("requested=5", "requested=25"),
        creation_log + creation_log,
        "",
    ):
        assert ci_five_observation_1291(
            native_log, creation_log=invalid_creation)[
                "stable_all_mod_script_mean_ms_per_tick"] is None
    for invalid_native in (
        native_log.replace("identity_stable=true", "identity_stable=false"),
        native_log.replace("t7200,3000000,", "t7200,garbled,"),
    ):
        assert ci_five_observation_1291(
            invalid_native, creation_log=creation_log)[
                "stable_all_mod_script_mean_ms_per_tick"] is None
    for malformed in (
        log.replace("routed_scans=120", "routed_scans=unmeasured"),
        log.replace("routed_scans=120", "routed_scans=-1"),
        log.replace("end_tick=18480", "end_tick=11820"),
        log.replace("CI_FIVE_PROFILE_1291_ACTIVITY", "INVALID_ACTIVITY"),
        log + "CI_FIVE_PROFILE_1291_ACTIVITY start_tick=600 end_tick=18480 "
              "routed_scans=120 direct_scans=6 movement_requests=12 "
              "movement_collapses=3 movement_priority_denials=2 "
              "movement_stalled_repaths=unmeasured broker_processed=160 "
              "broker_blocked=4\\n",
    ):
        assert ci_five_observation_1291(malformed)["routed_scans_per_1000_ticks"] is None
    for tampered in (
        log.replace("CI_FIVE_PROFILE_1291_WAITING tick=600 all=0 original=0 requested=5",
                    "CI_FIVE_PROFILE_1291_START tick=600 all=0 original=0 requested=5"),
        log.replace("all=5", "all=6", 1),
        log.replace("bad=0", "bad=1", 1),
        log.replace("identity_stable=true", "identity_stable=false", 1),
        log.replace("samples=189", "samples=188", 1),
        log.replace("tick=18480", "tick=11820", 1),
        log+"CI_FIVE_PROFILE_1291_END tick=18480 all=5 original=5 "
            "requested=5 samples=189 bad=0 identity_stable=true interval=60\n"):
        assert ci_five_observation_1291(tampered)["paired_population_verified"] is None
    scaled = (log.replace("all=5", "all=25")
              .replace("original=5", "original=25")
              .replace("requested=5", "requested=25"))
    assert ci_five_observation_1291(scaled, expected=25)["paired_population_verified"] == 25
    assert ci_five_observation_1291(log, expected=25)["paired_population_verified"] is None
    assert ci_five_observation_1291(
        scaled.replace("all=25", "all=24", 1), expected=25
    )["paired_population_verified"] is None
    assert ci_five_observation_1291(
        scaled.replace("identity_stable=true", "identity_stable=false"),
        expected=25)["paired_population_verified"] is None
    hundred = (scaled.replace("all=25", "all=100")
               .replace("original=25", "original=100")
               .replace("requested=25", "requested=100"))
    assert ci_five_observation_1291(hundred, expected=100)["paired_population_verified"] == 100
    assert ci_five_observation_1291(scaled, expected=100)["paired_population_verified"] is None
    assert ci_five_observation_1291(
        hundred.replace("identity_stable=true", "identity_stable=false"),
        expected=100)["paired_population_verified"] is None
    native_hundred = (native_log.replace("all=5", "all=100")
                      .replace("original=5", "original=100")
                      .replace("requested=5", "requested=100"))
    creation_hundred = (creation_log.replace("stations=5", "stations=100")
                        .replace("requested=5", "requested=100"))
    assert ci_five_observation_1291(
        native_hundred, expected=100,
        creation_log=creation_hundred)["stable_all_mod_script_mean_ms_per_tick"] == 3.0
    assert ci_five_observation_1291(
        native_hundred.replace("t7200,3000000,", "t7200,garbled,"),
        expected=100,
        creation_log=creation_hundred)["stable_all_mod_script_mean_ms_per_tick"] is None
    try:
        ci_five_observation_1291(log, expected=101)
    except ValueError:
        pass
    else:
        raise AssertionError("unsupported 101-priest profiling accepted")
    # Profiling must refuse unsafe scale-up even when the five-priest
    # diagnostic crashes or returns an identity-incomplete native receipt.
    # This is a focused runner contract regression, not native acceptance.
    from unittest.mock import patch
    with tempfile.TemporaryDirectory() as root:
        output = pathlib.Path(root) / "artifacts"
        calls = []
        def incomplete_five(binary, mods, work, out, population=5):
            calls.append(population)
            (out / "performance-ci-five.json").write_text(
                json.dumps({"paired_population_verified": None,
                            "engine_exit_status": 0,
                            "script_sample_coverage": "complete"}),
                encoding="utf-8")
        with patch(__name__ + ".run_ci_five_1291",
                   side_effect=incomplete_five):
            diagnostics = run_ci_profile_campaign_1291(
                pathlib.Path("unused"), pathlib.Path("unused"),
                pathlib.Path(root) / "work", output)
        assert calls == [5], calls
        assert diagnostics[25]["paired_population_verified"] is None
        assert diagnostics[100]["paired_population_verified"] is None
        assert "safety unavailable" in diagnostics[25]["reason"]
        # Native provenance, not source-test return code alone, controls 25.
        calls.clear()
        def complete_small(binary, mods, work, out, population=5):
            calls.append(population)
            suffix = "five" if population == 5 else str(population)
            (out / f"performance-ci-{suffix}.json").write_text(
                json.dumps({"paired_population_verified": population,
                            "engine_exit_status": 0,
                            "script_sample_coverage": "complete",
                            "stable_all_mod_script_sample_count": 11280}),
                encoding="utf-8")
        with patch(__name__ + ".run_ci_five_1291",
                   side_effect=complete_small):
            diagnostics = run_ci_profile_campaign_1291(
                pathlib.Path("unused"), pathlib.Path("unused"),
                pathlib.Path(root) / "work", output)
        assert calls == [5, 25, 100], calls
        assert diagnostics[100]["paired_population_verified"] == 100
    print("[ci-five-1291] PASS native 5/25/100 provenance positive/negative")


def run_ci_five_1291(binary: pathlib.Path, source_mods: pathlib.Path,
                     work: pathlib.Path, output: pathlib.Path,
                     population: int = 5) -> None:
    """Serial native 5/25/100-pair runs: matched seed, ticks, hardware."""
    if population not in (5, 25, 100):
        raise ValueError("unproven profiling population")
    suffix="five" if population==5 else str(population)
    area=work/("ci-"+suffix)
    area.mkdir(parents=True,exist_ok=True)
    mods=area/"mods"
    install_smoke_mod(source_mods,mods)
    control=mods/"tech-priests"/"control.lua"
    src=control.read_text(encoding="utf-8")
    if src.count("_G.TP_CI_SAVE_RELOAD_SMOKE=true")!=1:
        raise RuntimeError("ambiguous isolated CI smoke flag")
    if src.count(HARNESS_INSTALL)!=1:
        raise RuntimeError("ambiguous isolated CI harness entry")
    src=src.replace("_G.TP_CI_SAVE_RELOAD_SMOKE=true",
                    "_G.TP_CI_SAVE_RELOAD_SMOKE=false",1)
    src=src.replace(HARNESS_INSTALL,
                    "_G.TP_CI_LATE_COMBAT=false\n"
                    "_G.TP_CI_FIVE_PROFILE_1291=true\n"
                    + (f"_G.TP_CI_PROFILE_POPULATION_1291={population}\n"
                       if population in (25, 100) else "")
                    +HARNESS_INSTALL,1)
    control.write_text(src,encoding="utf-8")
    save=area/(suffix+"-pair-start.zip")
    creation_log_path=output/("factorio-ci-"+suffix+"-create.log")
    with creation_log_path.open("w",encoding="utf-8") as handle:
        created=subprocess.run([str(binary),"--mod-directory",str(mods),
            "--create",str(save),"--map-gen-seed","907260"],
            stdout=handle,stderr=subprocess.STDOUT,check=False,timeout=120)
    if created.returncode!=0 or not save.is_file():
        raise RuntimeError(f"native isolated {population}-pair save creation failed")
    log_path=output/("factorio-ci-"+suffix+".log")
    timeout_seconds=1500 if population==100 else 450
    timed_out=False
    engine_exit_status=None
    with log_path.open("w",encoding="utf-8") as handle:
        try:
            measured=subprocess.run([str(binary),"--mod-directory",str(mods),
                "--benchmark",str(save),"--benchmark-ticks","30000",
                "--benchmark-verbose","tick,scriptUpdate"],
                stdout=handle,stderr=subprocess.STDOUT,check=False,
                timeout=timeout_seconds)
            engine_exit_status=measured.returncode
        except subprocess.TimeoutExpired:
            # Retain the native partial verbose CSV and explicitly reject
            # full-window acceptance; profiling never blocks functionality.
            timed_out=True
    report=ci_five_observation_1291(
        log_path.read_text(encoding="utf-8",errors="replace"),
        expected=population,
        creation_log=creation_log_path.read_text(
            encoding="utf-8",errors="replace"))
    report["engine_exit_status"]=engine_exit_status
    report["engine_timeout_seconds"]=timeout_seconds if timed_out else None
    report["performance_is_release_blocking"]=False
    (output/("performance-ci-"+suffix+".json")).write_text(
        json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(("CI_FIVE_1291 " if population==5 else f"CI_{population}_1291 ")+
          json.dumps(report,sort_keys=True))


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
                        '_G.TP_CI_SAVE_RELOAD_SMOKE=true\n'
                        '_G.TP_CI_STRANDED_RELOAD_PROBE=false\n'
                        '_G.TP_CI_COURIER_RELOAD_PROBE=false\n'
                        '_G.TP_CI_STOCK_RELOAD_PROBE=false\n'
                        '_G.TP_CI_S2_MIDFLIGHT_RELOAD_PROBE=false\n' + HARNESS_INSTALL)
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
    # The initial world predates CI flag injection, so on_init cannot
    # establish the drill. Require one physical preparation in this process
    # before accepting its first persisted checkpoint.
    prepared = "[TP-GROUND-RANK-TEST] DRILL_ENGINE_0985_PREPARED"
    if first_log.count(prepared) != 1 or first_log.index(prepared) > first_log.index(REQUEST_MARKER):
        raise RuntimeError("real drill not prepared exactly once before first physical save")

    # A separate engine process verifies ordinary station/cargo persistence,
    # then kills the actual carrier and saves the stranded LuaInventory before
    # re-imprinting. No death or replacement is synthesized by this runner.
    stranded, second_log = server_checkpoint(
        first, work / "factorio-stranded-server.log", STRANDED_SAVE_NAME,
        STRANDED_REQUEST_MARKER,
        "tech-priests-ground-ranks-stranded-checkpoint.zip")
    check_engine_log(second_log, PASS_MARKER)
    check_engine_log(second_log, CARGO_MARKER)
    if prepared in second_log:
        raise RuntimeError("drill recreated after independent Factorio restart")
    check_engine_log(second_log, "[TP-GROUND-RANK-TEST] PASS DRILL_ENGINE_0985_NATURAL_FUELED_MINING")
    check_engine_log(second_log, STRANDED_REQUEST_MARKER)
    if "persisted_stations=4 persisted_priests=4" not in second_log:
        raise RuntimeError("reloaded Cogitator pairs were not preserved")
    if "held=0 net_fixture_delta=0" not in second_log:
        raise RuntimeError("ordinary cargo save/reload fixture did not balance")

    # Third independent Factorio process resumes the stranded-cargo
    # transaction and saves a naturally mined item still held by its courier.
    # The preceding server may create the checkpoint but cannot verify reload.
    control = mods / "tech-priests" / "control.lua"
    control_source = control.read_text(encoding="utf-8")
    stranded_flag = "_G.TP_CI_STRANDED_RELOAD_PROBE=false"
    if control_source.count(stranded_flag) != 1:
        raise RuntimeError("isolated stranded reload probe flag missing")
    control.write_text(control_source.replace(
        stranded_flag, "_G.TP_CI_STRANDED_RELOAD_PROBE=true"),
        encoding="utf-8")
    carried, third_log = server_checkpoint(
        stranded, work / "factorio-ore-carry-server.log", ORE_CARRY_SAVE_NAME,
        ORE_CARRY_SAVE_MARKER,
        "tech-priests-ground-ranks-ore-carry-checkpoint.zip")
    check_engine_log(third_log, STRANDED_RELOAD_MARKER)
    check_engine_log(third_log, ORE_CARRY_SAVE_MARKER)

    # Only the fourth, independently loaded process may emit reload proof.
    # This flag is changed exclusively in the isolated CI installation.
    control = mods / "tech-priests" / "control.lua"
    control_source = control.read_text(encoding="utf-8")
    flag = "_G.TP_CI_COURIER_RELOAD_PROBE=false"
    if control_source.count(flag) != 1:
        raise RuntimeError("isolated courier reload probe flag missing")
    control.write_text(control_source.replace(
        flag, "_G.TP_CI_COURIER_RELOAD_PROBE=true"), encoding="utf-8")

    # Fourth real process proves the ore-carry reload, then checkpoints the
    # original Junior's *occupied* station cargo during the first outward
    # journey, before any parent deposit. A fifth process must resume it.
    stock_carried, fourth_log = server_checkpoint(
        carried, work / "factorio-stock-carry-server.log",
        STOCK_CARRY_SAVE_NAME, STOCK_CARRY_SAVE_MARKER,
        "tech-priests-ground-ranks-stock-carry-checkpoint.zip")
    check_engine_log(fourth_log, ORE_CARRY_RELOAD_MARKER)
    check_engine_log(fourth_log, "[TP-GROUND-RANK-TEST] PASS DRILL_ENGINE_0985_INDEPENDENT_RELOAD")
    verify_ore_carry_reload_log(third_log, fourth_log)
    check_engine_log(fourth_log, STOCK_CARRY_SAVE_MARKER)

    # Only this fifth, independently loaded engine process can claim the
    # persistent occupied-station carrier readback.
    control_source = control.read_text(encoding="utf-8")
    stock_flag = "_G.TP_CI_STOCK_RELOAD_PROBE=false"
    if control_source.count(stock_flag) != 1:
        raise RuntimeError("isolated stock-carry reload probe flag missing")
    control.write_text(control_source.replace(
        stock_flag, "_G.TP_CI_STOCK_RELOAD_PROBE=true"), encoding="utf-8")
    reload_log = work / "factorio-reload.log"
    with reload_log.open("w", encoding="utf-8") as handle:
        result = subprocess.run([str(binary), "--mod-directory", str(mods),
                                 "--benchmark", str(stock_carried),
                                 "--benchmark-ticks", "48000",
                                 "--benchmark-verbose", "tick,scriptUpdate"],
                                stdout=handle, stderr=subprocess.STDOUT,
                                check=False, timeout=args.reload_timeout)
    content = reload_log.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(f"Factorio stock-carry reload failed: exit status {result.returncode}")
    check_engine_log(content, STOCK_CARRY_RELOAD_MARKER)
    verify_stock_carry_reload_log(fourth_log, content)

    # Factorio writes its blocking save AFTER all handlers in the current
    # tick. Preserve receipt evidence up to the ENGINE'S actual save start,
    # not merely the earlier scenario request. Never use post-save events
    # from a process that may have advanced beyond the resumed checkpoint.
    third_evidence = checkpointed_pre_save_evidence(
        third_log, ORE_CARRY_SAVE_MARKER, ORE_CARRY_SAVE_NAME)
    fourth_evidence = checkpointed_pre_save_evidence(
        fourth_log, STOCK_CARRY_SAVE_MARKER, STOCK_CARRY_SAVE_NAME)
    combined = third_evidence + "\n" + fourth_evidence + "\n" + content
    check_engine_log(combined, STRANDED_RELOAD_MARKER)
    check_engine_log(combined, DEATH_MARKER)
    verify_death_reimprint_log(combined)
    check_engine_log(combined, RELOCATION_MARKER)
    verify_relocation_log(combined)
    check_engine_log(combined, ORE_RETURN_MARKER)
    verify_ore_return_log(combined)
    verify_machine_return_log_0994(combined)
    verify_native_engine_log_1014(combined)
    check_engine_log(combined, "[TP-GROUND-RANK-TEST] REVERSAL_ENGINE_QUIET_SITE_SELECTED")
    check_engine_log(combined, "[TP-GROUND-RANK-TEST] REVERSAL_ENGINE_PRODUCTION_IDLE_VERIFIED")
    check_engine_log(combined, "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_FIVE_STATION_FIXTURE")
    check_engine_log(combined, "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT")
    check_engine_log(combined, "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_SECOND_PHYSICAL_DEPOT")
    verify_reversal_outbound_log(combined)
    verify_reversal_outbound_transit_log(combined)
    verify_reversal_outbound_build_log(combined)
    verify_reversal_intermediate_ghost_log(combined)
    verify_reversal_intermediate_pickup_log(combined)
    verify_reversal_intermediate_transit_log(combined)
    verify_reversal_intermediate_build_log(combined)
    verify_reversal_first_junior_ghost_log(combined)
    verify_reversal_first_junior_pickup_log(combined)
    verify_reversal_first_junior_transit_log(combined)
    verify_reversal_first_junior_build_log(combined)
    verify_reversal_second_junior_ghost_log(combined)
    verify_reversal_second_junior_pickup_log(combined)
    verify_reversal_second_junior_transit_log(combined)
    verify_reversal_second_junior_build_log(combined)
    verify_reversal_natural_ore_return_log(combined)
    verify_robot_engine_s2_log(combined)
    verify_robot_frontier_native_1080_log(combined)
    verify_robot_frontier_native_1111_log(combined)
    verify_robot_frontier_native_1120_log(combined)
    # Completed fifth-process evidence survives a failed independent S3 reload.
    # No script/broker timing claim is attributed to the sixth process.
    preflight_path = output / "performance-s3-preflight-1360.json"
    try:
        preflight_metrics = native_efficiency_observation_1062(content)
        preflight_path.write_text(json.dumps({
            "scope": "completed-fifth-process-only",
            "s3_sixth_process_accepted": False,
            "measurements": preflight_metrics,
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("NATIVE_EFFICIENCY_1062 " +
              json.dumps(preflight_metrics, sort_keys=True), flush=True)
    except Exception as exc:
        preflight_path.write_text(json.dumps({
            "scope": "completed-fifth-process-only",
            "s3_sixth_process_accepted": False,
            "measurements": None, "reason": str(exc),
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("NATIVE_EFFICIENCY_1062 UNMEASURED: " + str(exc), flush=True)
    # Sixth REAL server process checkpoints the identical fourth-process
    # world at the physical mid-flight cut. Factorio --benchmark DOES NOT
    # persist game.auto_save() requests (observed 42412909755), so the
    # measured 48k fifth benchmark remains untouched and is not treated as
    # a source of serialized custody. This is a genuine native server save.
    midflight_copy, midflight_server_log = server_checkpoint(
        stock_carried, work / "factorio-robot-midflight-save-server.log",
        ROBOT_MIDFLIGHT_SAVE_NAME, ROBOT_MIDFLIGHT_SAVE_MARKER,
        "tech-priests-robot-midflight-checkpoint.zip")
    checkpointed_pre_save_evidence(midflight_server_log,
                                   ROBOT_MIDFLIGHT_SAVE_MARKER,
                                   ROBOT_MIDFLIGHT_SAVE_NAME)
    # Seventh REAL process reopens this CRC-checked midflight checkpoint.
    # The saved world, not a freshly created fixture, owns the original
    # 0338 task, unpowered ghost, held material and priest identity.
    midflight_control = control.read_text(encoding="utf-8")
    midflight_flag = "_G.TP_CI_S2_MIDFLIGHT_RELOAD_PROBE=false"
    if midflight_control.count(midflight_flag) != 1:
        raise RuntimeError("isolated S3 independent reload flag missing")
    control.write_text(midflight_control.replace(
        midflight_flag, "_G.TP_CI_S2_MIDFLIGHT_RELOAD_PROBE=true"),
        encoding="utf-8")
    midflight_log_path = work / "factorio-robot-midflight-reload.log"
    with midflight_log_path.open("w", encoding="utf-8") as handle:
        midflight_result = subprocess.run(
            [str(binary), "--mod-directory", str(mods),
             "--benchmark", str(midflight_copy),
             "--benchmark-ticks", "3000"],
            stdout=handle, stderr=subprocess.STDOUT,
            check=False, timeout=args.reload_timeout)
    midflight_log = midflight_log_path.read_text(
        encoding="utf-8", errors="replace")
    if midflight_result.returncode != 0:
        raise RuntimeError("S3 independent native reload process failed: "
                           + str(midflight_result.returncode))
    check_engine_log(midflight_log, ROBOT_MIDFLIGHT_RELOAD_MARKER)
    verify_robot_midflight_reload_1360_log(midflight_server_log, midflight_log)
    print("PASS S3/1360: independently saved native server checkpoint and "
          "separate Factorio process resumed original "
          "unpowered robot-dispatch ghost with counted substation held, "
          "then restored power and built one real ranked Senior")
    if "held=1 chest_delta=0" not in combined:
        raise RuntimeError("stranded cargo did not survive independent engine reload")
    if "held=0 net_fixture_delta=0" not in combined:
        raise RuntimeError("re-imprinted priest did not return the conserved item")
    print("PASS: five real Factorio processes, four CRC-verified saves, "
          "4 identities preserved, stranded cargo persisted across reload, "
          "a naturally mined ore item persisted in its original engine-owned "
          "courier hold across a separate process, the re-imprinted priest "
          "recovered cargo, occupied-station cargo survived an independent mid-carry reload, a staffed station was physically redeployed, "
          "and ore returned through three real physical inventory hops; "
          "a fuel-powered drill mined natural map ore into a real chest "
          "whose identity and mined inventory survived independent reload; "
          "a second live 0528 machine-output receipt supplied a separate "
          "three-hop physical Magos delivery")
    print(f"Checkpoints: {first} ({first.stat().st_size} bytes), "
          f"{stranded} ({stranded.stat().st_size} bytes), "
          f"{carried} ({carried.stat().st_size} bytes), "
          f"{stock_carried} ({stock_carried.stat().st_size} bytes)")
    # Optional native profiles are diagnostics, not prerequisite to the
    # independently accepted physical save/reload and inventory gates.
    run_ci_profile_campaign_1291(binary, pathlib.Path(args.mod_dir).resolve(),
                                 work, output)
    return 0



def run_ci_profile_campaign_1291(
        binary: pathlib.Path, source_mods: pathlib.Path,
        work: pathlib.Path, output: pathlib.Path) -> dict[int, dict[str, object]]:
    """Bounded, nonblocking native 5/25/100 diagnostics without five-process prerequisite.

    Profile-only runs the already-authorized CI construction of *initial*
    real stations/priests, not the separately guarded physical remote-ore
    acceptance. Every population requires an independent native identity and
    scriptUpdate receipt before the next larger population is attempted.
    Failed engine attempts retain partial logs and explicit missing metrics.
    """
    output.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    reports: dict[int, dict[str, object]] = {}

    def unmeasured(population: int, reason: str) -> dict[str, object]:
        report = {
            "schema": "ci-paired-performance-1291-v1",
            "requested_population": population,
            "paired_population_verified": None,
            "engine_exit_status": None,
            "script_sample_coverage": None,
            "performance_is_release_blocking": False,
            "reason": reason,
        }
        suffix = "five" if population == 5 else str(population)
        (output / f"performance-ci-{suffix}.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n",
            encoding="utf-8")
        print(f"CI_{population}_1291 UNMEASURED: {reason}")
        return report

    def measure(population: int) -> dict[str, object]:
        suffix = "five" if population == 5 else str(population)
        try:
            run_ci_five_1291(binary, source_mods, work, output,
                             population=population)
            return json.loads((output / f"performance-ci-{suffix}.json").read_text(
                encoding="utf-8"))
        except Exception as exc:
            # The original Factorio create/benchmark logs are retained even on
            # timeout; an absent or partial report must never count as zero cost.
            return unmeasured(population, str(exc))

    def safe_to_scale(report: dict[str, object], population: int) -> bool:
        return (report.get("paired_population_verified") == population
                and report.get("engine_exit_status") == 0
                and report.get("script_sample_coverage") == "complete"
                and isinstance(report.get("stable_all_mod_script_sample_count"),
                               int)
                and report["stable_all_mod_script_sample_count"] > 0)

    reports[5] = measure(5)
    if safe_to_scale(reports[5], 5):
        reports[25] = measure(25)
    else:
        reports[25] = unmeasured(25, "same-run 5-pair native identity/script safety unavailable")
    if safe_to_scale(reports[25], 25):
        reports[100] = measure(100)
    else:
        reports[100] = unmeasured(100, "same-run 25-pair native identity/script safety unavailable")
    return reports


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--self-test-efficiency", action="store_true")
    parser.add_argument("--profile-only", action="store_true",
                        help="measure existing authentic CI 5/25/100 priests without rerunning physical recovery")
    parser.add_argument("--efficiency-log", help="Existing real Factorio log; diagnostics only")
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
    if args.self_test_efficiency:
        self_test_native_efficiency_1062()
        self_test_ci_performance_1066(native_efficiency_observation_1062)
        self_test_ci_five_1291()
        return 0
    if args.efficiency_log:
        source = pathlib.Path(args.efficiency_log)
        print("NATIVE_EFFICIENCY_1062 "+json.dumps(
            native_efficiency_observation_1062(source.read_text(
                encoding="utf-8", errors="replace")), sort_keys=True))
        return 0
    if args.profile_only:
        for key in ("binary", "mod_dir", "work_dir", "artifact_dir"):
            if not getattr(args, key):
                parser.error(f"--{key.replace('_', '-')} is required")
        reports = run_ci_profile_campaign_1291(
            pathlib.Path(args.binary).resolve(),
            pathlib.Path(args.mod_dir).resolve(),
            pathlib.Path(args.work_dir).resolve(),
            pathlib.Path(args.artifact_dir).resolve())
        print("CI_PROFILE_CAMPAIGN_1291 " + json.dumps({
            "native_populations_verified": [
                n for n in (5, 25, 100)
                if reports[n].get("paired_population_verified") == n
                and reports[n].get("engine_exit_status") == 0
                and reports[n].get("script_sample_coverage") == "complete"],
            "performance_is_release_blocking": False,
            "functional_remote_ore_gates_accepted": 0,
        }, sort_keys=True))
        return 0
    for key in ("binary", "mod_dir", "initial_save", "work_dir", "artifact_dir"):
        if not getattr(args, key):
            parser.error(f"--{key.replace('_', '-')} is required")
    success = False
    try:
        result = execute(args)
        success = result == 0
        return result
    except (OSError, RuntimeError, TimeoutError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL save/reload smoke: {exc}", file=sys.stderr)
        if args.work_dir:
            for name in ("factorio-save-server.log", "factorio-stranded-server.log",
                         "factorio-ore-carry-server.log", "factorio-stock-carry-server.log",
                         "factorio-reload.log",
                         "factorio-robot-midflight-reload.log"):
                path = pathlib.Path(args.work_dir) / name
                if path.is_file():
                    print(f"--- tail {name} ---", file=sys.stderr)
                    lines = path.read_text(encoding="utf-8",
                                           errors="replace").splitlines()
                    print("\n".join(lines[-35:]), file=sys.stderr)
                    # The fatal timeout may occur thousands of ticks after
                    # the courier's first blocked duty. Always expose its
                    # bounded engine diagnostics in the Actions job output,
                    # not only inside the downloadable ZIP artifact.
                    evidence = [line for line in lines
                                if "[TP-GROUND-RANK-TEST] ORE_ENGINE_" in line
                                or "[TP-GROUND-RANK-TEST] REVERSAL_ENGINE_" in line
                                or "[TP-GROUND-RANK-TEST] FAIL " in line
                                or "[TP-GROUND-RANK-TEST] ERROR " in line]
                    if evidence:
                        print(f"--- physical-engine evidence {name} "
                              f"(latest {min(90, len(evidence))}"
                              f"/{len(evidence)} markers) ---",
                              file=sys.stderr)
                        print("\n".join(evidence[-90:]), file=sys.stderr)
        return 1
    finally:
        # All CI outcomes, including early failed physical scenarios, retain
        # observed metrics in the same artifact directory. Never override an
        # engine acceptance verdict with a performance reporting exception.
        try:
            summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
            report = write_ci_performance_report_1066(
                pathlib.Path(args.work_dir), pathlib.Path(args.artifact_dir),
                native_efficiency_observation_1062, success,
                os.environ.get("GITHUB_SHA", "unknown"),
                pathlib.Path(summary_path) if summary_path else None)
            print("CI_PERFORMANCE_1066 " + json.dumps({
                "status": report["functional_status"],
                "primary": report["primary"],
                "warnings": report["performance_warnings"],
                "stages": list(report["stage_observations"]),
            }, sort_keys=True))
        except Exception as diagnostic_error:
            print("WARN: nonblocking native performance report unavailable: "
                  + str(diagnostic_error), file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
