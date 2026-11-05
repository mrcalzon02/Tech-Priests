#!/usr/bin/env python3
"""Run exactly one independent Tech-Priests Factorio 2.0 scenario.

Never modifies the live mod folder, gameplay saves, or the shared 108k
endurance harness. Requires a locally installed headless Factorio executable
and any external required dependency mods already acquired by the user.
"""
from __future__ import annotations

import argparse
import json
import pathlib
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
    "remote-rail-acquisition": {
        "fixture": "tests/scenarios/remote-rail-acquisition/fixture.lua",
        "module": "ci_remote_rail_acquisition",
        "prefix": "[TP-REMOTE-RAIL-TEST]",
        "pass": "PASS planetary Magos built rail, rode train, mined and returned real ore",
        "ticks": 93000,
    },
}


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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scenario", choices=tuple(CASES), required=True)
    ap.add_argument("--factorio", default=shutil.which("factorio"),
                    help="Factorio 2.0.77 headless executable")
    ap.add_argument("--dependency-mods", type=pathlib.Path,
                    help="Existing folder of external required mod ZIP files")
    ap.add_argument("--output-dir", type=pathlib.Path,
                    default=ROOT / "test-artifacts" / "isolated-service")
    ap.add_argument("--ticks", type=int,
                    help="Override scenario benchmark duration")
    ap.add_argument("--midgame-smoke", action="store_true",
                    help="Use 18,060 native ticks to audit the three earliest "
                         "bootstrap checkpoints; never accept the factory goal")
    ap.add_argument("--seed", type=int, default=907260)
    ap.add_argument("--timeout-seconds", type=int, default=1800)
    args = ap.parse_args()

    scenario = CASES[args.scenario]
    factorio = pathlib.Path(args.factorio) if args.factorio else None
    if not (factorio and factorio.is_file()):
        ap.error("Specify --factorio /path/to/factorio (Factorio 2.0.77)")
    if args.midgame_smoke and args.scenario != "midgame-science":
        ap.error("--midgame-smoke is available only for midgame-science")
    tick_count = (args.ticks if args.ticks is not None else
                  (18060 if args.midgame_smoke else scenario["ticks"]))
    if tick_count < 600:
        ap.error("--ticks must be at least 600")
    if args.midgame_smoke and not 18060 <= tick_count < 36000:
        ap.error("--midgame-smoke must cover native 0/9k/18k marks "
                 "without claiming full nine-checkpoint acceptance")
    version = subprocess.run([str(factorio), "--version"],
                             capture_output=True, text=True, check=False)
    version_line = (version.stdout or version.stderr).splitlines()[0:1]
    if not version_line or "2.0.77" not in version_line[0]:
        ap.error("Acceptance requires Factorio 2.0.77; found " +
                 (version_line[0] if version_line else "unidentified executable"))

    output = args.output_dir.resolve() / args.scenario
    output.mkdir(parents=True, exist_ok=True)
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
    created = run([str(factorio), "--mod-directory", str(mods),
                   "--create", str(save), "--map-gen-settings",
                   str(map_settings)],
                  output / "create.log", args.timeout_seconds)
    if created:
        print("FAIL headless save creation; see " + str(output / "create.log"))
        return 1
    benchmark = run([str(factorio), "--mod-directory", str(mods),
                     "--benchmark", str(save), "--benchmark-ticks",
                     str(tick_count)], output / "benchmark.log",
                    args.timeout_seconds)
    contents = (output / "benchmark.log").read_text(
        encoding="utf-8", errors="replace")
    for line in contents.splitlines():
        if scenario["prefix"] in line:
            print(line[:1200])
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
            if scenario["prefix"] + " MIDGAME_READY " not in contents:
                print("FAIL early midgame readiness event unavailable")
                return 1
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
