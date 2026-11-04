#!/usr/bin/env python3
"""Visualize *actual Factorio engine entity telemetry* as a time-lapse GIF.

Telemetry renderings are schematic overhead maps, NOT in-game screenshots.
If real PNGs were captured by a graphical client, those take precedence.
Never infer machines, recipes, research or science from a fixture preset.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import tempfile
from typing import Any

MARKS = (0, 9000, 18000, 36000, 72000, 108000, 144000, 180000, 216000)
PACKS = ("automation-science-pack", "logistic-science-pack",
         "military-science-pack", "chemical-science-pack")
SCHEMA = "tech-priests-midgame-engine-checkpoint-v1"


def load_frames(directory: Path) -> list[dict[str, Any]]:
    frames = []
    for mark in MARKS:
        p = directory / f"checkpoint-{mark:06d}.json"
        if not p.is_file():
            raise ValueError(f"Missing genuine Factorio checkpoint: {p}")
        data = json.loads(p.read_text(encoding="utf-8"))
        if data.get("schema") != SCHEMA or data.get("elapsed") != mark:
            raise ValueError(f"Invalid or mismatched engine checkpoint: {p}")
        if data.get("visual_source") != "factorio-live-engine-entity-telemetry":
            raise ValueError(f"Non-engine source refused: {p}")
        if data.get("fixture_supply_is_not_production") is not True:
            raise ValueError(f"Stock provenance missing: {p}")
        entities = data.get("entities")
        if not isinstance(entities, list) or len(entities) > 100000:
            raise ValueError(f"Invalid entity set in {p}")
        if not isinstance(data.get("observed_science_spm"), dict):
            raise ValueError(f"Missing measured engine production: {p}")
        frames.append(data)
    ticks = [f["tick"] for f in frames]
    if ticks != sorted(ticks):
        raise ValueError("Checkpoint ticks are out of order")
    return frames


def make_summary(frames: list[dict[str, Any]]) -> dict[str, Any]:
    timeline = []
    for frame in frames:
        flows = frame["observed_science_spm"]
        row = {
            "elapsed": frame["elapsed"], "tick": frame["tick"],
            "entities": len(frame["entities"]),
            "paired_priests": frame.get("paired_priests"),
            "research": frame.get("research", "none"),
            "spm": {name: flows.get(name) for name in PACKS},
        }
        timeline.append(row)
    last = timeline[-1]
    final_frame = frames[-1]
    latest_counts = final_frame.get("entity_counts") or {}
    if not isinstance(latest_counts, dict):
        latest_counts = {}
    final_pair_diagnostics = final_frame.get("pair_diagnostics") or []
    blockers = []
    if (latest_counts.get("lab") or 0) == 0:
        blockers.append("no-physical-laboratory")
    if last["research"] == "none":
        blockers.append("research-not-selected")
    for pair in final_pair_diagnostics:
        if not isinstance(pair, dict):
            continue
        rank = str(pair.get("rank") or "unknown-rank")
        last_detail = str(pair.get("construction_last_detail") or "none")
        if any(part in last_detail for part in
               ("movement-blocked", "construction-timeout",
                "route-denied", "movement-refused")):
            blockers.append(f"{rank}:construction-route:{last_detail}")
        infrastructure = str(pair.get("infrastructure_blocker") or "none")
        if "missing-ingredients" in infrastructure:
            blockers.append(f"{rank}:materials:{infrastructure}")
    all_three_active = all((last["spm"].get(name) or 0) > 0
                           for name in PACKS[:3])
    return {
        "schema": "tech-priests-midgame-evidence-v1",
        "science_objective_status": ("three-sciences-active"
                                     if all_three_active else
                                     "not-achieved"),
        "diagnostic_only_not_release_blocking": True,
        "final_physical_entity_counts": latest_counts,
        "final_observed_blockers": blockers,
        "final_pair_diagnostics": final_pair_diagnostics,
        "max_observed_spm_during_run": {
            name: max((row["spm"].get(name) or 0) for row in timeline)
            for name in PACKS
        },
        "research_selected_at_end": last["research"] != "none",
        "visualization": "schematic-from-factorio-engine-telemetry-not-screenshot",
        "starter_supplies_count_as_output": False,
        "timeline": timeline,
        "all_three_sciences_produced_at_end": all_three_active,
        "chemical_science_produced_at_end":
            (last["spm"].get(PACKS[3]) or 0) > 0,
    }


def render_telemetry(frames: list[dict[str, Any]], output: Path) -> list[Path]:
    from PIL import Image, ImageDraw, ImageFont

    output.mkdir(parents=True, exist_ok=True)
    imgs: list[Path] = []
    palette = {
        "assembling-machine": (234, 170, 65),
        "furnace": (211, 108, 82),
        "mining-drill": (110, 182, 96),
        "lab": (139, 128, 234),
        "electric-pole": (243, 227, 115),
        "generator": (101, 201, 232),
        "boiler": (101, 201, 232),
        "container": (183, 173, 153),
        "transport-belt": (235, 190, 108),
        "inserter": (155, 210, 185),
        "pumpjack": (100, 163, 210),
        "pipe": (87, 145, 189),
    }
    for frame in frames:
        picture = Image.new("RGB", (1280, 810), (19, 27, 36))
        draw = ImageDraw.Draw(picture)
        draw.rectangle((20, 96, 1260, 696), fill=(27, 38, 48),
                       outline=(69, 91, 106), width=2)
        for gx in range(40, 1260, 85):
            draw.line((gx, 98, gx, 695), fill=(39, 55, 65), width=1)
        for gy in range(114, 696, 75):
            draw.line((22, gy, 1258, gy), fill=(39, 55, 65), width=1)
        xmin, xmax, ymin, ymax = -50, 243, -53, 51
        for ent in frame["entities"]:
            if not isinstance(ent, dict):
                continue
            try:
                x, y = float(ent["x"]), float(ent["y"])
            except (ValueError, KeyError, TypeError):
                continue
            if not (xmin <= x <= xmax and ymin <= y <= ymax):
                continue
            px = round(25 + (x - xmin) * 1230 / (xmax - xmin))
            py = round(100 + (y - ymin) * 591 / (ymax - ymin))
            kind = ent.get("type", "")
            color = palette.get(kind, (130, 155, 166))
            r = 4 if kind in ("assembling-machine", "mining-drill",
                             "furnace", "lab", "generator") else 2
            draw.ellipse((px-r, py-r, px+r, py+r), fill=color)
        draw.text((24, 21), "TECH PRIESTS  |  MID-GAME FACTORY TEST",
                  fill=(240, 245, 247))
        t = frame["elapsed"] / 3600  # 60 UPS -> 3600 ticks/minute
        draw.text((24, 54), f"Tick {frame['tick']:,} | Game time {t:.1f} min"
                  f" | Selected research: {frame.get('research', 'none')}",
                  fill=(179, 204, 224))
        flows = frame["observed_science_spm"]
        labels = [f"{name.replace('-science-pack', '').upper()}: "
                  f"{flows.get(name, 0) or 0:.2f} SPM" for name in PACKS]
        draw.text((24, 717), "  |  ".join(labels), fill=(230, 234, 237))
        draw.text((24, 748), "ENGINE TELEMETRY MAP — NOT A GAME SCREENSHOT",
                  fill=(247, 171, 103))
        draw.text((910, 748),
                  f"Entities: {len(frame['entities'])}  "
                  f"Priest pairs: {frame.get('paired_priests', 0)}",
                  fill=(171, 190, 203))
        path = output / f"checkpoint-{frame['elapsed']:06d}.png"
        picture.save(path)
        imgs.append(path)
    return imgs


def create_gif(images: list[Path], destination: Path) -> None:
    from PIL import Image
    if not images:
        raise ValueError("No legitimate images available")
    frames = []
    for image in images:
        with Image.open(image) as opened:
            frames.append(opened.convert("P", palette=Image.Palette.ADAPTIVE,
                                         colors=128))
    destination.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(destination, save_all=True, append_images=frames[1:],
                   duration=1100, loop=0, optimize=False, disposal=2)


def assemble(checkpoints: Path, destination: Path,
             actual_screenshots: Path | None = None) -> dict[str, Any]:
    frames = load_frames(checkpoints)
    destination.mkdir(parents=True, exist_ok=True)
    summary = make_summary(frames)
    actual = []
    if actual_screenshots and actual_screenshots.is_dir():
        actual = [actual_screenshots / f"checkpoint-{mark:06d}.png"
                  for mark in MARKS]
        if not all(x.is_file() for x in actual):
            actual = []
    if actual:
        selected = actual
        summary["visualization"] = "actual-factorio-graphical-screenshots"
    else:
        selected = render_telemetry(frames, destination / "telemetry-frames")
    create_gif(selected, destination / "midgame-science-timelapse.gif")
    summary["gif"] = "midgame-science-timelapse.gif"
    summary["frame_count"] = len(selected)
    print("MIDGAME_OBJECTIVE_EVIDENCE status=" +
          summary["science_objective_status"] +
          " final_blockers=" +
          json.dumps(summary["final_observed_blockers"], separators=(",", ":")) +
          " measured_spm=" +
          json.dumps(summary["timeline"][-1]["spm"], separators=(",", ":")))
    if summary["science_objective_status"] != "three-sciences-active":
        print("::warning::Midgame checkpoint audit passed, but real "
              "three-science production has NOT been demonstrated; "
              "this functional development diagnostic is not a release gate")
    (destination / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8")
    return summary


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="midgame-telemetry-test-") as root:
        directory = Path(root)
        frames = directory / "checkpoints"
        frames.mkdir()
        for mark in MARKS:
            entry = {
                "schema": SCHEMA, "elapsed": mark, "tick": mark + 100,
                "visual_source": "factorio-live-engine-entity-telemetry",
                "fixture_supply_is_not_production": True,
                "observed_science_spm": {n: 0 for n in PACKS},
                "entities": [{"name": "steel-chest", "type": "container",
                              "x": 0, "y": 0}]}
            (frames / f"checkpoint-{mark:06d}.json").write_text(
                json.dumps(entry), encoding="utf-8")
        loaded = load_frames(frames)
        assert len(loaded) == len(MARKS)
        measured = make_summary(loaded)
        assert measured["science_objective_status"] == "not-achieved"
        assert not measured["all_three_sciences_produced_at_end"]
        assert "no-physical-laboratory" in measured["final_observed_blockers"]
        assert "research-not-selected" in measured["final_observed_blockers"]
        assert all(value == 0 for value in
                   measured["max_observed_spm_during_run"].values())
        loaded[-1]["observed_science_spm"].update({
            name: 1 for name in PACKS[:3]})
        successful = make_summary(loaded)
        assert successful["science_objective_status"] == "three-sciences-active"
        assert successful["all_three_sciences_produced_at_end"]
        (frames / "checkpoint-018000.json").unlink()
        try:
            load_frames(frames)
            raise AssertionError("Missing checkpoint was silently accepted")
        except ValueError:
            pass
    print("[midgame-telemetry] PASS strict nine-frame engine provenance, "
          "chronology and missing-checkpoint rejection")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--checkpoints", type=Path)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--screenshots", type=Path)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.checkpoints or not args.output:
        ap.error("--checkpoints and --output are required")
    summary = assemble(args.checkpoints, args.output, args.screenshots)
    print(json.dumps({k: summary[k] for k in
                      ("visualization", "frame_count",
                       "all_three_sciences_produced_at_end",
                       "chemical_science_produced_at_end")},
                     sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
