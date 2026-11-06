#!/usr/bin/env python3
"""Factorio 2.1.24 headless migration probe and fail-closed modpack audit.

Keep shipping metadata on 2.0 while an isolated copy is tested against 2.1.
Portal metadata, installed files, and an engine smoke are distinct evidence.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "tests/modpacks/required_21_1271.json"
SOURCE_INFO = ROOT / "tech-priests_src/info.json"
PORTAL = "https://mods.factorio.com"
BUILTIN = {"base", "core", "quality", "space-age", "elevated-rails"}
HEADERS = {"User-Agent": "Tech-Priests-2.1.24-migration/1.0"}


def version_tuple(raw):
    parts = str(raw).split(".")
    if not parts or not all(p.isdecimal() for p in parts):
        raise ValueError("Unrecognized version string " + repr(raw))
    return tuple(int(p) for p in parts)


def stage_native_dependencies():
    """Keep native DLC prototype load order in the disposable 2.1 test copy.

    A core-only test may omit third-party mods, but MUST NOT strip optional
    Space Age/Quality/Elevated Rails ordering: the shipped mod uses those
    native expansion prototypes (including the vanilla thruster donor).
    """
    return [
        "base >= 2.1.0",
        "? space-age >= 2.1.0",
        "? quality >= 2.1.0",
        "? elevated-rails >= 2.1.0",
    ]


def read_json(path):
    return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))


def static_contract():
    data, info = read_json(CONTRACT), read_json(SOURCE_INFO)
    assert data["target_factorio"] == "2.1.24"
    assert data["target_factorio_family"] == "2.1"
    assert info["factorio_version"] == "2.0", "Do not change release metadata before native proof"
    assert "mechanicus-reborn" in data["mandatory_mod_ids"], "Latest Mechanicus must be required"
    assert "mechanicist-factorio" in data["mandatory_mod_ids"]
    assert "tanks_for_bob_fork" in data["mandatory_mod_ids"]
    assert "kj_servoskull" in data["mandatory_mod_ids"]
    assert len(data["mandatory_mod_ids"]) == len(set(data["mandatory_mod_ids"]))
    assert data["mandated_aai_fix"] == "40kvehicles-AAI-fix"
    assert "? space-age >= 2.1.0" in stage_native_dependencies(), (
        "Migration staging must preserve the shipped Space Age load order")
    assert "? quality >= 2.1.0" in stage_native_dependencies()
    assert data["latest_known_factorio_21"]["mechanicus-reborn"] == "0.0.3"
    assert select_latest(
        [{"version": "0.0.1", "info_json": {"factorio_version": "2.0"}},
         {"version": "0.0.3", "info_json": {"factorio_version": "2.1"}},
         {"version": "0.0.2", "info_json": {"factorio_version": "2.1"}}],
        "2.1")["version"] == "0.0.3", "Release selection downgraded from latest 2.1"
    assert select_latest(
        [{"version": "0.0.1", "info_json": {"factorio_version": "2.0"}}],
        "2.1") is None, "A 2.0-only mod must not pass as 2.1"
    print("[TP-2.1-MIGRATION] STATIC PASS target 2.1.24, Mechanicus latest, strict 2.1 filter")
    return data


def select_latest(releases, family):
    choices = [r for r in releases if r.get("info_json", {}).get("factorio_version") == family]
    return max(choices, key=lambda r: version_tuple(r["version"])) if choices else None


def fetch_metadata(name):
    quoted = urllib.parse.quote(name, safe="")
    req = urllib.request.Request(PORTAL + "/api/mods/" + quoted + "/full", headers=HEADERS)
    with urllib.request.urlopen(req, timeout=35) as response:
        return json.load(response)


def dependency_name(declaration):
    text = declaration.strip()
    if not text or text[0] in "?!~":
        return None
    name = re.split(r"\s*[<>=]", text, maxsplit=1)[0].strip()
    return name if name and name not in BUILTIN else None


def portal_audit(data, output):
    names = list(dict.fromkeys(data["mandatory_mod_ids"] + [data["mandated_aai_fix"]]))
    report = {
        "target_factorio": data["target_factorio"],
        "kind": "remote_mod_portal_metadata_only_not_runtime_proof",
        "mods": {},
        "blockers": [],
        "runtime_acceptance": False
    }
    for name in names:
        try:
            metadata = fetch_metadata(name)
            release = select_latest(metadata.get("releases", []), "2.1")
            if release:
                record = {"status": "available-2.1",
                          "version": release["version"],
                          "factorio_version": "2.1",
                          "required_dependencies": [
                              child for dep in release.get("info_json", {}).get("dependencies", [])
                              if (child := dependency_name(dep))
                          ]}
                expected = data["latest_known_factorio_21"].get(name)
                if expected and version_tuple(release["version"]) < version_tuple(expected):
                    report["blockers"].append(
                        name + ": 2.1 release regressed below last known " + expected)
            else:
                found = sorted({r.get("info_json", {}).get("factorio_version", "?")
                                for r in metadata.get("releases", [])})
                record = {"status": "missing-2.1",
                          "versions_available": found}
                report["blockers"].append(name + ": no published 2.1 release")
        except (OSError, ValueError, KeyError, TimeoutError, urllib.error.URLError) as exc:
            record = {"status": "metadata-error", "error": str(exc)}
            report["blockers"].append(name + ": remote metadata failed: " + str(exc))
        report["mods"][name] = record
        print("[TP-2.1-MIGRATION] PORTAL", name, record, flush=True)
    report["blockers"].append(
        "Even if every mod has a release, full 2.1 native movement, robot delivery, "
        "123k endurance and separate-process save/reload are NOT yet proven.")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("[TP-2.1-MIGRATION] AUDIT report=", output, "blockers=", len(report["blockers"]))
    return report


def download_modpack(mods_dir, name, report, username, token):
    if not username or not token:
        raise ValueError("FACTORIO_USERNAME / FACTORIO_TOKEN required for Mechanicus Reborn 2.1 download")
    known = report["mods"].get(name, {})
    if known.get("status") != "available-2.1":
        raise ValueError(name + ": no verified Factorio 2.1 release in public metadata audit")
    pending = [name]
    resolved = {}
    while pending:
        item = pending.pop(0)
        if item in BUILTIN or item in resolved:
            continue
        full = fetch_metadata(item)
        release = select_latest(full.get("releases", []), "2.1")
        if release is None:
            raise ValueError("Transitive requirement has no 2.1 release: " + item)
        resolved[item] = release["version"]
        pending.extend(filter(None, (dependency_name(d) for d in
                       release.get("info_json", {}).get("dependencies", []))))
        url = urllib.parse.urljoin(PORTAL, release["download_url"])
        query = urllib.parse.urlencode({"username": username, "token": token})
        target = mods_dir / (item + "_" + release["version"] + ".zip")
        with urllib.request.urlopen(
                urllib.request.Request(url + "?" + query, headers=HEADERS),
                timeout=120) as response:
            target.write_bytes(response.read())
        if not zipfile.is_zipfile(target):
            raise ValueError("Not a valid Factorio Mod Portal ZIP: " + item)
    if resolved.get(name) != known.get("version"):
        raise ValueError("Mechanicus release changed during audit; retry against a stable snapshot")
    print("[TP-2.1-MIGRATION] INSTALLED versions (not engine proof)", resolved)
    return resolved


def run_logged(argv, logfile, timeout):
    with logfile.open("w", encoding="utf-8") as output:
        try:
            proc = subprocess.run(argv, stdout=output, stderr=subprocess.STDOUT,
                                  timeout=timeout, check=False)
            result = proc.returncode
        except subprocess.TimeoutExpired:
            output.write("\nMIGRATION_TIMEOUT\n")
            result = 124
    tail = logfile.read_text(encoding="utf-8", errors="replace").splitlines()[-40:]
    print("\n".join(tail), flush=True)
    if result != 0:
        raise ValueError("Native Factorio returned exit code " + str(result)
                         + "; see " + str(logfile))
    if any(needle in logfile.read_text(encoding="utf-8", errors="replace")
           for needle in ("Error while loading", "Error while running", "stack traceback")):
        raise ValueError("Fatal Factorio runtime error in " + str(logfile))


def native_probe(data, binary, root, profile, report):
    check = subprocess.run([str(binary), "--version"], capture_output=True,
                           text=True, check=False)
    version = (check.stdout or check.stderr).splitlines()
    if check.returncode or not version or not re.search(
            r"(?<!\d)2\.1\.24(?!\d)", version[0]):
        raise ValueError("Expected Factorio 2.1.24 headless, got " + repr(version[:1]))
    print("[TP-2.1-MIGRATION] ENGINE", version[0], flush=True)
    dest = root / profile
    mods = dest / "mods"
    mods.mkdir(parents=True, exist_ok=True)
    staged = mods / "tech-priests"
    shutil.copytree(ROOT / "tech-priests_src", staged, dirs_exist_ok=True)
    meta = read_json(staged / "info.json")
    meta["factorio_version"] = "2.1"
    meta["dependencies"] = stage_native_dependencies()
    # Temporary metadata is in a disposable runner directory; never ship it.
    installed = {}
    if profile == "mechanicus":
        installed = download_modpack(mods, "mechanicus-reborn", report,
                                     os.environ.get("FACTORIO_USERNAME", ""),
                                     os.environ.get("FACTORIO_TOKEN", ""))
        meta["dependencies"] += [f"{name} >= {version}"
                                 for name, version in sorted(installed.items())]
    (staged / "info.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    enabled = [{"name": "base", "enabled": True},
               {"name": "tech-priests", "enabled": True}]
    enabled += [{"name": mid, "enabled": True} for mid in sorted(installed)]
    (mods / "mod-list.json").write_text(
        json.dumps({"mods": enabled}, indent=2) + "\n", encoding="utf-8")
    endurance = profile == "core-endurance"
    feed_probe = profile == "core-feed-probe"
    if endurance or feed_probe:
        # Install the EXISTING 2.0 ground-rank harness in a disposable 2.1
        # copy. The real in-game runtime and resource accounting stay unchanged.
        harness = staged / "scripts/core/ci_ground_rank_harness.lua"
        shutil.copy2(ROOT / "tests/scenarios/all-ground-ranks/ground_rank_harness.lua",
                     harness)
        with (staged / "control.lua").open("a", encoding="utf-8") as control:
            control.write("\n_G.TP_CI_LATE_COMBAT=true\n")
            control.write('require("scripts.core.ci_ground_rank_harness").install()\n')
    save = dest / "migration-initial.zip"
    run_logged([str(binary), "--mod-directory", str(mods), "--create",
                str(save), "--map-gen-seed", "907260"], dest / "create.log", 180)
    if not save.is_file():
        raise ValueError("No genuine initial save after Factorio --create")
    ticks = 123000 if endurance else 12000 if feed_probe else 600
    benchmark_log = dest / "benchmark.log"
    run_logged([str(binary), "--mod-directory", str(mods), "--benchmark",
                str(save), "--benchmark-ticks", str(ticks)], benchmark_log,
               1800 if endurance else 300)
    if feed_probe:
        probe_log = benchmark_log.read_text(encoding="utf-8", errors="replace")
        observations = [
            line for line in probe_log.splitlines()
            if "[TP-GROUND-RANK-TEST] FEED_PROBE_1280 rank=" in line
        ]
        if len(observations) < 2 or "[TP-GROUND-RANK-TEST] FAIL " in probe_log:
            raise ValueError("Real furnace feed probe missing observations "
                             "or failed native fixture; see " + str(benchmark_log))
        result = {
            "target": data["target_factorio"], "profile": profile,
            "native_12000_ticks": True, "observed_stations": len(observations),
            "scope": "read-only furnace feed diagnostics, not full industrial acceptance"
        }
        (dest / "result.json").write_text(
            json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print("[TP-2.1-MIGRATION] FEED PROBE 1280 NATIVE PASS: "
              + str(len(observations))
              + " physical station observations; not smelting acceptance",
              flush=True)
        for line in observations:
            print(line[-900:], flush=True)
        return
    if endurance:
        log = benchmark_log.read_text(encoding="utf-8", errors="replace")
        markers = [
            "[TP-GROUND-RANK-TEST] PASS ground ranks with live pairs=4",
            "[TP-GROUND-RANK-TEST] PASS recovery assessments=",
            "[TP-GROUND-RANK-TEST] DURATION_DIAGNOSIS verdict=",
            "[TP-GROUND-RANK-TEST] PASS autonomous bootstrap-to-science",
            "[TP-GROUND-RANK-TEST] PASS CONCLAVE_NATIVE_1187_GENUINE_RESEARCH_AND_FORCE_SCHISM",
            "[TP-GROUND-RANK-TEST] PASS hostile-damage defensive establishment",
        ]
        missing = [marker for marker in markers if marker not in log]
        fatal = [signature for signature in
                 ("[TP-GROUND-RANK-TEST] FAIL ", "[TP-GROUND-RANK-TEST] ERROR ",
                  "[Tech-Priests][CRITICAL]", "stack traceback")
                 if signature in log]
        if missing or fatal:
            raise ValueError("Native 2.1 123k ground-rank acceptance failed: "
                             + "missing=" + repr(missing)
                             + " fatal=" + repr(fatal))
        print("[TP-2.1-MIGRATION] 123K NATIVE PASS six required science/combat "
              "milestone groups; beginning independent save/reload", flush=True)
        run_logged([
            sys.executable, str(ROOT / "tools/run_factorio_save_reload_smoke.py"),
            "--binary", str(binary),
            "--mod-dir", str(mods),
            "--initial-save", str(save),
            "--work-dir", str(dest / "save-reload"),
            "--artifact-dir", str(dest / "test-artifacts"),
            "--reload-timeout", "900"
        ], dest / "save-reload-driver.log", 1800)
        result = {"target": data["target_factorio"], "profile": profile,
                  "installed": installed, "native_create": True,
                  "native_123000_ticks": True, "save_reload_complete": True,
                  "required_markers": markers,
                  "scope": "native 2.1 123k science/combat and real save/reload; "
                           "NOT the complete third-party modpack"}
        print("[TP-2.1-MIGRATION] 123K + SAVE/RELOAD NATIVE PASS "
              "core-endurance", flush=True)
    else:
        result = {"target": data["target_factorio"], "profile": profile,
                  "installed": installed, "native_create": True,
                  "native_600_ticks": True,
                  "scope": "isolated migration smoke, NOT full modpack or 123k proof"}
        print("[TP-2.1-MIGRATION] NATIVE SMOKE PASS",
              profile, "not full release acceptance", flush=True)
    (dest / "result.json").write_text(json.dumps(result, indent=2) + "\n",
                                      encoding="utf-8")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument("--static", action="store_true")
    group.add_argument("--audit", type=pathlib.Path)
    group.add_argument("--gate", type=pathlib.Path)
    group.add_argument("--profile", choices=("core", "mechanicus", "core-feed-probe", "core-endurance"))
    p.add_argument("--factorio", type=pathlib.Path)
    p.add_argument("--report", type=pathlib.Path)
    p.add_argument("--output-dir", type=pathlib.Path)
    args = p.parse_args()
    try:
        data = static_contract()
        if args.audit:
            portal_audit(data, args.audit)
        if args.gate:
            status = read_json(args.gate)
            if status.get("target_factorio") != data["target_factorio"]:
                raise ValueError("Portal audit evidence did not match target engine")
            if status.get("blockers"):
                raise ValueError("Mandatory 2.1.24 modpack BLOCKED: "
                                 + "; ".join(status["blockers"]))
            raise ValueError("No end-to-end 2.1.24 gameplay proof available")
        if args.profile:
            if not args.factorio or not args.output_dir:
                raise ValueError("--profile requires --factorio and --output-dir")
            report = read_json(args.report) if args.report else {"mods": {}}
            native_probe(data, args.factorio, args.output_dir, args.profile, report)
        return 0
    except (OSError, ValueError, AssertionError, json.JSONDecodeError) as exc:
        print("[TP-2.1-MIGRATION] FAIL", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
