#!/usr/bin/env python3
"""Fail-closed required Mechanicist/AAI/40K compatibility gate for Factorio 2.0.

Static assertions are NOT Factorio runtime evidence. --portal checks public
metadata without credentials. --installed checks the actual isolated runner
directory; neither can substitute for a real engine behavior scenario.
"""
import argparse
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "tests/modpacks/required_40k_1270.json"
INFO = ROOT / "tech-priests_src/info.json"
FIX = "40kvehicles-AAI-fix"

def load_contract():
    data = json.loads(CONTRACT.read_text(encoding="utf-8"))
    info = json.loads(INFO.read_text(encoding="utf-8"))
    required = data["required_mod_ids"]
    if not required or len(required) != len(set(required)):
        raise ValueError("Empty or duplicate required mod IDs")
    if info["factorio_version"] != data["factorio_version"] or data["headless_version"] != "2.0.77":
        raise ValueError("Factorio source/engine version disagreement")
    deps = info.get("dependencies", [])
    hard = set()
    for value in deps:
        value = value.strip()
        if value and not value.startswith(("?", "!", "~", "(")):
            hard.add(re.split(r"\s*[<>=]", value, maxsplit=1)[0].strip())
    missing = set(required) - hard
    if missing:
        raise ValueError("Required mods absent from info.json hard dependencies: " + ", ".join(sorted(missing)))
    if FIX in hard:
        raise ValueError("Impossible 1.1-only fix is a strict 2.0 dependency; use a verified port instead")
    fix = data["required_compatibility_behavior"]
    if fix["upstream_mod_id"] != FIX or fix["resolution"] != "blocked-awaiting-verified-factorio-2.0-port-or-equivalent":
        raise ValueError("Cannot mark the unverified AAI compatibility fix accepted")
    if set(fix["vehicle_ids"]) != {"kj_40kpredator", "kj_40klemanruss", "kj_40kdreadnought"}:
        raise ValueError("AAI fix's three required vehicles are not represented")
    if not any("Servo-Skull" in item for item in data["functional_acceptance"]):
        raise ValueError("Servo-Skull robot-network acceptance is missing")
    print("[40K-MODPACK] STATIC PASS: eight hard mod dependencies; legacy fix explicitly unresolved")
    return data

def installed_check(required, folder):
    if not folder.is_dir():
        raise ValueError("Missing isolated mod directory: " + str(folder))
    names = {p.name for p in folder.iterdir()}
    missing = [mid for mid in required if not (
        mid in names or any(n.startswith(mid + "_") and n.endswith(".zip") for n in names)
    )]
    if missing:
        raise ValueError("Required external Mod Portal ZIPs not physically installed: " + ", ".join(missing))
    print("[40K-MODPACK] INSTALLED PASS: all eight required mod packages are present (NOT engine proof)")

def fetch_versions(mod_id, timeout):
    url = "https://mods.factorio.com/api/mods/" + mod_id + "/full"
    request = urllib.request.Request(url, headers={"User-Agent": "Tech-Priests-CI-required-modpack/1"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    return [(r["version"], r.get("info_json", {}).get("factorio_version")) for r in payload.get("releases", [])]

def portal_check(data):
    problems = []
    for mid in data["required_mod_ids"] + [FIX]:
        try:
            versions = fetch_versions(mid, 30)
        except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as exc:
            problems.append(mid + ": Mod Portal metadata unreachable: " + str(exc))
            continue
        compatible = [v for v, game in versions if game == "2.0"]
        if compatible:
            print("[40K-MODPACK] PORTAL 2.0", mid, "releases:", ", ".join(compatible[-4:]))
        else:
            problems.append(mid + ": NO official Factorio 2.0 version")
    # Portal metadata alone cannot verify behavior even if a future port exists.
    problems.append(
        "AAI fix behavior is not yet proven in Factorio 2.0: require real "
        "Predator/Leman Russ/Dreadnought AAI route/stop/restart engine evidence"
    )
    if problems:
        raise ValueError("; ".join(problems))

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--installed", type=pathlib.Path, help="Check downloaded ZIPs in isolated Factorio mod directory")
    ap.add_argument("--portal", action="store_true", help="Strict remote compatibility gate; fails until 2.0 AAI fix behavior is proven")
    args = ap.parse_args()
    try:
        contract = load_contract()
        if args.installed:
            installed_check(contract["required_mod_ids"], args.installed)
        if args.portal:
            portal_check(contract)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print("[40K-MODPACK] FAIL:", exc, file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
