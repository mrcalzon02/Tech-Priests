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
ORE_CARRY_SAVE_NAME = "_autosave-tech-priests-ci-ore-carried.zip"
STRANDED_REQUEST_MARKER = "[TP-GROUND-RANK-TEST] CARGO_ENGINE_DEATH_SAVE_REQUESTED"
STRANDED_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS CARGO_ENGINE_STRANDED_RELOAD"
ORE_CARRY_SAVE_MARKER = "[TP-GROUND-RANK-TEST] ORE_ENGINE_CARRIER_SAVE_REQUESTED"
ORE_CARRY_RELOAD_MARKER = "[TP-GROUND-RANK-TEST] PASS ORE_ENGINE_CARRIER_RELOAD"
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
    """0934: the original Intermediate physically collects exactly one Junior item."""
    ghost = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_GHOST tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+) ghost_unit=(\d+)"
        r" junior_depots=2 carrier=0 rank=2-to-1"
        r" physical_build_not_yet_claimed=true", content)
    pickup = re.search(
        r"PASS REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP tick=(\d+)"
        r" rebuilt_intermediate=(\d+)"
        r" original_intermediate_priest=(\d+)"
        r" original_junior_priest=(\d+)"
        r" child_writ=(\d+)"
        r" source_before=1 source_after=0 carrier_before=0 carrier_after=1"
        r" second_depot=1 distance_sq=([\d.]+)"
        r" original_priest_staged=true", content)
    if not (ghost and pickup and ghost.start() < pickup.start()
            and int(pickup.group(1)) >= int(ghost.group(1)) + 120
            and all(pickup.group(i) == ghost.group(i) for i in (2, 3, 4, 5))
            and pickup.group(3) != pickup.group(4)
            and float(pickup.group(6)) <= 25):
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
    delivered = re.search(
        r"PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick=(\d+)"
        r" original_magos=(\d+) original_priests=5 physical_hops=4"
        r" natural_ore_delta=-1 magos_inventory_delta=1"
        r" delivered_count=1 cargo_empty=true", content)
    if not (built and route and delivered
            and built.start() < route.start() < delivered.start()
            and int(built.group(1)) <= int(route.group(1))
            and int(route.group(1)) < int(delivered.group(1))
            and route.group(6) == built.group(2)
            and route.group(2) == delivered.group(2)
            and int(route.group(7)) > 0
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


def self_test() -> int:
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
        "second_depot=1 distance_sq=4.000 original_priest_staged=true")
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
        "\nPASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick=36500 "
        "original_magos=100 original_priests=5 physical_hops=4 "
        "natural_ore_delta=-1 magos_inventory_delta=1 "
        "delivered_count=1 cargo_empty=true")
    verify_reversal_natural_ore_return_log(reversal_ore_proof)
    for broken in (
        reversal_ore_proof.replace("peer=1007", "peer=1008"),
        reversal_ore_proof.replace("physical_hops=4", "physical_hops=3"),
        reversal_ore_proof.replace("natural_ore_delta=-1",
                                   "natural_ore_delta=0"),
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
        junior_pickup_proof.replace("distance_sq=4.000", "distance_sq=26.000"),
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
                        '_G.TP_CI_SAVE_RELOAD_SMOKE=true\n'
                        '_G.TP_CI_COURIER_RELOAD_PROBE=false\n' + HARNESS_INSTALL)
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

    # Third independent Factorio process resumes the stranded-cargo
    # transaction and saves a naturally mined item still held by its courier.
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

    reload_log = work / "factorio-reload.log"
    with reload_log.open("w", encoding="utf-8") as handle:
        result = subprocess.run([str(binary), "--mod-directory", str(mods),
                                 "--benchmark", str(carried),
                                 "--benchmark-ticks", "48000"],
                                stdout=handle, stderr=subprocess.STDOUT,
                                check=False, timeout=args.reload_timeout)
    content = reload_log.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(f"Factorio ore-carry reload failed: exit status {result.returncode}")
    check_engine_log(content, ORE_CARRY_RELOAD_MARKER)
    verify_ore_carry_reload_log(third_log, content)

    # The third server can advance after requesting its autosave. Only the
    # observations BEFORE that checkpoint belong to the resumed timeline.
    prior_lines = third_log.splitlines(keepends=True)
    save_line = next((i for i, line in enumerate(prior_lines)
                      if ORE_CARRY_SAVE_MARKER in line), None)
    if save_line is None:
        raise RuntimeError("physical ore-carry checkpoint marker missing")
    combined = "".join(prior_lines[:save_line+1]) + "\n" + content
    check_engine_log(combined, STRANDED_RELOAD_MARKER)
    check_engine_log(combined, DEATH_MARKER)
    verify_death_reimprint_log(combined)
    check_engine_log(combined, RELOCATION_MARKER)
    verify_relocation_log(combined)
    check_engine_log(combined, ORE_RETURN_MARKER)
    verify_ore_return_log(combined)
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
    if "held=1 chest_delta=0" not in combined:
        raise RuntimeError("stranded cargo did not survive independent engine reload")
    if "held=0 net_fixture_delta=0" not in combined:
        raise RuntimeError("re-imprinted priest did not return the conserved item")
    print("PASS: four real Factorio processes, three CRC-verified saves, "
          "4 identities preserved, stranded cargo persisted across reload, "
          "a naturally mined ore item persisted in its original engine-owned "
          "courier hold across a separate process, the re-imprinted priest "
          "recovered cargo, a staffed station was physically redeployed, "
          "and ore returned through three real physical inventory hops")
    print(f"Checkpoints: {first} ({first.stat().st_size} bytes), "
          f"{stranded} ({stranded.stat().st_size} bytes), "
          f"{carried} ({carried.stat().st_size} bytes)")
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
                         "factorio-ore-carry-server.log", "factorio-reload.log"):
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


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
