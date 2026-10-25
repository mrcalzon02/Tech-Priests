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
        except subprocess.TimeoutExpired as error:
            output.write(f"\nSCENARIO_EXECUTION_TIMEOUT after {timeout} seconds\n")
            raise RuntimeError("Factorio headless timeout") from error


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
    ap.add_argument("--seed", type=int, default=907260)
    ap.add_argument("--timeout-seconds", type=int, default=1800)
    args = ap.parse_args()

    scenario = CASES[args.scenario]
    factorio = pathlib.Path(args.factorio) if args.factorio else None
    if not (factorio and factorio.is_file()):
        ap.error("Specify --factorio /path/to/factorio (Factorio 2.0.77)")
    tick_count = args.ticks if args.ticks is not None else scenario["ticks"]
    if tick_count < 600:
        ap.error("--ticks must be at least 600")
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

    # Neither service scenario should inherit random biter camps. All
    # defenses and survival supplies remain physical, but hostile combat
    # belongs exclusively to the separate battle endurance acceptance.
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
