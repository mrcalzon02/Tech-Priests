#!/usr/bin/env python3
"""Validate *observed* Factorio midgame checkpoints, including partial runs.

A partial report is only diagnostic. It never grants full midgame acceptance,
manufactures science or marks a timed-out benchmark successful.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import tempfile

SCHEMA = "tech-priests-midgame-engine-checkpoint-v1"
VISUAL_SOURCE = "factorio-live-engine-entity-telemetry"
MARKS = (0, 9000, 18000, 36000, 72000, 108000, 144000, 180000, 216000)
PACKS = ("automation-science-pack", "logistic-science-pack",
         "military-science-pack", "chemical-science-pack")
NAME = re.compile(r"checkpoint-(\d{6})\.json$")


def _finite_count(value: object) -> float:
    if not isinstance(value, (float, int)) or isinstance(value, bool):
        raise ValueError("Engine counter was not numeric")
    if value < 0 or value != value or value == float("inf"):
        raise ValueError("Invalid engine counter value")
    return float(value)


def inspect(directory: Path, required: tuple[int, ...] = ()) -> dict:
    frames = []
    for file in sorted(directory.glob("checkpoint-*.json")):
        match = NAME.fullmatch(file.name)
        if not match:
            raise ValueError("Unrecognized engine checkpoint filename " + file.name)
        elapsed = int(match.group(1))
        if elapsed not in MARKS:
            raise ValueError("Unscheduled engine checkpoint " + file.name)
        frame = json.loads(file.read_text(encoding="utf-8"))
        if (frame.get("schema") != SCHEMA
                or frame.get("visual_source") != VISUAL_SOURCE
                or frame.get("fixture_supply_is_not_production") is not True
                or frame.get("elapsed") != elapsed):
            raise ValueError("Unverified engine checkpoint provenance: " + file.name)
        if not isinstance(frame.get("tick"), int) or frame["tick"] < 0:
            raise ValueError("Missing native tick: " + file.name)
        for key in ("entities", "pair_diagnostics"):
            if not isinstance(frame.get(key), list):
                raise ValueError("Missing native " + key + ": " + file.name)
        flows = frame.get("observed_science_spm")
        if not isinstance(flows, dict):
            raise ValueError("Missing native production statistics: " + file.name)
        for name in PACKS:
            _finite_count(flows.get(name))
        frames.append(frame)
    marks = [f["elapsed"] for f in frames]
    ticks = [f["tick"] for f in frames]
    if len(set(marks)) != len(marks) or ticks != sorted(set(ticks)):
        raise ValueError("Repeated or nonmonotonic engine checkpoint timeline")
    missing = sorted(set(required) - set(marks))
    if missing:
        raise ValueError("Missing required native milestones: " + repr(missing))
    if not frames:
        return {"status": "no-engine-checkpoints", "frames": 0,
                "last_elapsed": None, "last_tick": None,
                "remaining_marks": list(MARKS)}
    first = frames[0]
    last = frames[-1]
    # At elapsed=0 the on_init-created stations may not have their
    # on_built paired-priest records yet. Preserve that genuine zero-pair
    # checkpoint but obtain stock proof at the FIRST later native checkpoint
    # where the original three ranks are actually paired. Never fill the
    # initial record with invented stock or pretend those pairs existed at 0.
    stocked_frame = next((
        frame for frame in frames
        if len(frame["pair_diagnostics"]) == 3 and all(
            pair.get("paired") is True
            for pair in frame["pair_diagnostics"])
    ), first)
    stored = {}
    for pair in stocked_frame["pair_diagnostics"]:
        rank = pair.get("rank", "unknown")
        stock = pair.get("stocked_installable") or {}
        if not isinstance(stock, dict):
            raise ValueError("Malformed stock inventory diagnostic")
        stored[rank] = {k: _finite_count(v) for k, v in stock.items()}
    last_pairs = []
    for pair in last["pair_diagnostics"]:
        last_pairs.append({
            "rank": pair.get("rank"),
            "stage": pair.get("infrastructure_stage"),
            "blocker": pair.get("infrastructure_blocker"),
            "target": pair.get("infrastructure_item"),
            "ghost": pair.get("ghost_entity"),
            "construction_request": pair.get("construction_request"),
            "construction_phase": pair.get("construction_task_phase"),
            "science_reason": pair.get("science_pulse_reason"),
            "stocked_installable": pair.get("stocked_installable", {}),
        })
    research_gate = last.get("bootstrap_research_exit_1224") or {}
    power = last.get("physical_power_readiness_1250")
    if power is not None:
        if not isinstance(power, dict):
            raise ValueError("Malformed native physical lab power audit")
        for key in ("installed_labs", "powered_labs", "electric_poles",
                    "generators", "boilers", "offshore_pumps",
                    "native_generator_output_last_tick"):
            _finite_count(power.get(key))
        if _finite_count(power["powered_labs"]) > _finite_count(power["installed_labs"]):
            raise ValueError("Powered lab count exceeded physical machines")
        if not isinstance(power.get("blocker"), str):
            raise ValueError("Physical lab power blocker not observed")
    summary = {
        "status": "partial-engine-evidence" if len(frames) < len(MARKS)
                  else "all-engine-checkpoints-observed",
        "frames": len(frames), "marks": marks,
        "last_elapsed": last["elapsed"], "last_tick": last["tick"],
        "initial_engine_starter_crates": len(first.get("starter_crates") or [])
            if isinstance(first.get("starter_crates"), list) else 0,
        "remaining_marks": [x for x in MARKS if x not in marks],
        "initial_stored_hardware_by_rank": stored,
        "first_paired_stock_checkpoint": stocked_frame["elapsed"],
        "last_entity_counts": last.get("entity_counts"),
        "last_paired_priests": last.get("paired_priests"),
        "last_science_spm": {name: _finite_count(
            last["observed_science_spm"][name]) for name in PACKS},
        "last_selected_research": last.get("research"),
        "last_research_finishes": len(last.get("research_finished") or []),
        "last_power_readiness": power,
        "last_research_exit": {
            "emergency_acquisition_exit":
                research_gate.get("emergency_acquisition_exit"),
            "sustained_research": research_gate.get("sustained_research"),
            "blocker": research_gate.get("blocker"),
        },
        "last_pair_diagnostics": last_pairs,
        "full_midgame_acceptance": False,  # Never grant via partial audit.
    }
    return summary


def validate_smoke(summary: dict) -> None:
    if summary["status"] != "partial-engine-evidence":
        raise ValueError("Short bootstrap observer must remain non-acceptance")
    if not {0, 9000, 18000}.issubset(set(summary["marks"])):
        raise ValueError("Short run omitted the early native checkpoint sequence")
    if summary["initial_engine_starter_crates"] != 8:
        raise ValueError("Original eight physical starter crates not verified")
    ranks = summary["initial_stored_hardware_by_rank"]
    total = sum(sum(stock.values()) for stock in ranks.values())
    if total < 1:
        raise ValueError("No real starter hardware visible to any Cogitator")
    if len(ranks) != 3:
        raise ValueError("Original three ranked priest diagnostics unavailable")
    if any(not isinstance(x, dict) for x in summary["last_pair_diagnostics"]):
        raise ValueError("Missing worker diagnostic record")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="tp-midgame-checkpoint-audit-") as td:
        root = Path(td)
        def put(mark: int, science: float = 0) -> None:
            frame = {
                "schema": SCHEMA, "visual_source": VISUAL_SOURCE,
                "fixture_supply_is_not_production": True,
                "elapsed": mark, "tick": 100 + mark,
                "starter_crates": [{"kind": f"fixture-crate-{i}"}
                                   for i in range(8)],
                "entities": [], "pair_diagnostics": [
                    {"rank": r, "paired": mark != 0,
                     "stocked_installable": (
                        {"stone-furnace": 1} if (mark != 0 and r == "junior")
                        else {})}
                    for r in ("junior", "senior", "magos")],
                "observed_science_spm": {name: science for name in PACKS},
                "physical_power_readiness_1250": {
                    "installed_labs": 1, "powered_labs": 0,
                    "electric_poles": 0, "generators": 0,
                    "boilers": 0, "offshore_pumps": 0,
                    "native_generator_output_last_tick": 0,
                    "blocker": "no-physical-generator",
                },
                "research": "none",
            }
            (root / f"checkpoint-{mark:06d}.json").write_text(
                json.dumps(frame), encoding="utf-8")
        put(0); put(9000)
        try:
            inspect(root, (0, 9000, 18000))
        except ValueError:
            pass
        else:
            raise AssertionError("Missing engine checkpoint was not rejected")
        put(18000)
        summary = inspect(root, (0, 9000, 18000))
        validate_smoke(summary)
        assert summary["first_paired_stock_checkpoint"] == 9000
        assert summary["full_midgame_acceptance"] is False
        assert summary["last_science_spm"][PACKS[0]] == 0
        assert summary["last_power_readiness"]["powered_labs"] == 0
        assert summary["last_power_readiness"]["blocker"] == "no-physical-generator"
        p = root / "checkpoint-018000.json"
        value = json.loads(p.read_text(encoding="utf-8"))
        value["visual_source"] = "synthetic"
        p.write_text(json.dumps(value), encoding="utf-8")
        try:
            inspect(root)
        except ValueError:
            pass
        else:
            raise AssertionError("Forged checkpoint provenance was accepted")
    print("[midgame-checkpoint-audit] PASS partial chronology, inventory proof, missing frames and forged provenance rejected")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if args.directory is None:
        parser.error("directory required unless --self-test")
    try:
        summary = inspect(args.directory,
                          (0, 9000, 18000) if args.smoke else ())
        if args.smoke:
            validate_smoke(summary)
    except (OSError, ValueError) as error:
        print("FAIL checkpoint evidence: " + str(error))
        return 1
    print("MIDGAME_PARTIAL_ENGINE_EVIDENCE " + json.dumps(
        summary, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
