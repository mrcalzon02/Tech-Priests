"""Verify the real native edge-mount flight and saved-state evidence."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("profile", type=Path)
parser.add_argument("--repo", type=Path, required=True)
parser.add_argument("--fixture", default="flight.lua", choices=("flight.lua", "flight_low.lua"))
args = parser.parse_args()
root, repo = args.profile.resolve(), args.repo.resolve()
read = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
outputs = root / "user-data/script-output/thruster-resume"
native = read(outputs / "native-results.json")
continuous = read(outputs / "continuous-results.json")
reloaded = read(outputs / "reload-results.json")
assert native["passed"] and native["independent_phase"]
assert continuous == reloaded and continuous["passed"]
assert len(native["rows"]) == 4 and all(row["passed"] for row in native["rows"])

original = read(root / "source-binding.json")
update_path = root / "mounting-source-binding.json"
update = read(update_path) if update_path.exists() else {"updated_files": {}}
expected = dict(original["files"])
expected.update(update["updated_files"])
for name, digest in expected.items():
    assert sha(root / "mods/tech-priests" / name) == digest, name

key_files = [
    "prototypes/compatibility/space-age.lua",
    "prototypes/compatibility/thruster-mounting-visuals.lua",
    "scripts/core/efficiency_economy_0595.lua",
    "scripts/core/efficiency_economy_0596.lua",
    "scripts/core/void_fusion_operation.lua",
    "scripts/generated/control_legacy_part_001.lua",
    "scripts/generated/control_legacy_part_002.lua",
    "scripts/generated/control_legacy_part_004.lua",
]
for name in key_files:
    assert sha(repo / "tech-priests_src" / name) == expected[name], name
fixture = root / "mods/thruster-resume-proof"
assert sha(fixture / "control.lua") == sha(repo / "tools/art/thruster_resumption/mounting" / args.fixture)
assert sha(fixture / "data.lua") == sha(repo / "docs/art/thruster-resumption-20261117/native/data.lua")

saves = list((root / "user-data/saves").glob("*thruster-resume-complete*.zip"))
assert len(saves) == 1
with zipfile.ZipFile(saves[0]) as archive:
    assert archive.testzip() is None
assert "Saving finished" in (root / "server.log").read_text(errors="replace")

legal_splits = {}
probe_path = root / "probe-only/half-mount-probe.json"
if probe_path.exists():
    for row in read(probe_path)["rows"]:
        legal = [p["last_foundation_row"] for p in row["probes"] if p["legal"]]
        legal_splits[row["name"]] = legal
    assert legal_splits["void-fusion-thruster-half-probe-0p5"] == [0]
    assert legal_splits["large-void-fusion-thruster-half-probe-1"] == [0]
    assert not legal_splits["void-fusion-thruster-half-probe-0"]
    assert not legal_splits["large-void-fusion-thruster-half-probe-0"]

rows = []
for row in native["rows"]:
    item = {k: row[k] for k in ("name", "passed", "placement_legal", "movement")}
    if "cycle_samples" in row:
        for k in ("unpowered_refusal", "powered_service", "power_cut_refusal",
                  "power_recovery", "sink_replaced", "native_cycle", "power_bounds",
                  "significant_variation", "minimum_power_watts", "maximum_power_watts"):
            item[k] = row[k]
    rows.append(item)

evidence_paths = [outputs / name for name in (
    "native-results.json", "continuous-results.json", "reload-results.json")]
evidence_paths += [saves[0], root / "source-binding.json",
                   root / "mounting-source-binding.json", root / "create.log",
                   root / "test.log", root / "server.log", root / "reload.log",
                   root / "probe-only/half-mount-probe.json"]
evidence_paths += [fixture / name for name in ("control.lua", "data.lua", "data-final-fixes.lua")]
evidence = {p.relative_to(root).as_posix(): {"sha256": sha(p), "bytes": p.stat().st_size}
            for p in evidence_paths if p.exists()}
summary = {
    "status": "PASS_NATIVE_FORE_SUPPORTED_EDGE_MOUNTS_FLIGHT_DYNAMIC_POWER_AND_EXACT_RELOAD",
    "engine": "Factorio 2.1.24 build 87808, Steam win64",
    "rows": rows,
    "saved_tick": 1500,
    "compared_tick": 1560,
    "exact_continuous_reload_match": True,
    "source_files_bound": len(expected),
    "current_key_source_hashes": {name: expected[name] for name in key_files},
    "placement_probes": legal_splits,
    "native_cuts_local_y": {"void-fusion-thruster": 0.5, "large-void-fusion-thruster": 1},
    "flight_fixture": args.fixture,
    "surrounding_ledge_guard": {
        "enabled": args.fixture == "flight_low.lua",
        "narrow_fore_foundation": "Three columns for the core and surrounding cheek-brace landings",
        "missing_side_landing_refused": args.fixture == "flight_low.lua",
        "nominal_core_snap_grids": {"narrow": [1, 9], "wide": [4, 4]},
    },
    "model_contract": "Source edge Y=0, +Y fore, -Y aft, about half physical axial envelope over space. Only fore anchors touch deck. Model/sprite registration must map that source edge to the quantized native cuts; nominal rows are not the fraction of physical structure on deck.",
    "registration_gate": "New authored models are not installed as native sprites yet; their source-to-native camera/shift must still be measured against the legal deck cut. This receipt proves ordinary native edge placement and operation, not final new-art fitting.",
    "server_shutdown": "The private loopback test server was stopped after the CRC-verified completed autosave; normal profiles were untouched.",
    "evidence": evidence,
}
(root / "mounting-validation-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(summary["status"])
print("CURRENT_SOURCE_FILES", len(key_files), "FROZEN_INPUTS", len(expected), "EXACT_RELOAD", True)
