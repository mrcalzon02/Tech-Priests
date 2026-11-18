"""Prepare final authored art plus actual per-engine power-controlled effects.

Creates a fresh private profile. Never modifies the original propulsion-verified
snapshot, the owner's source models or a normal Factorio installation/profile.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
parser = argparse.ArgumentParser()
parser.add_argument("--capture", action="append", type=Path, required=True)
parser.add_argument("--frozen-profile", type=Path, required=True)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
out = args.out.resolve()
if out.exists():
    raise ValueError("Fresh isolated profile required")
for path in args.capture:
    receipt = json.loads(path.read_text())
    assert receipt["layers"]["working_light"]["frame_count"] == 64
    kind = receipt["layers"]["field_candidate"].get("kind", "").lower()
    assert "particle" in kind or "ejecta" in kind, "Superseded field-line study"
command = [sys.executable, str(HERE / "prepare_capture_native.py")]
for path in args.capture:
    command.extend(["--capture", str(path.resolve())])
command.extend(["--frozen-profile", str(args.frozen_profile.resolve()), "--out", str(out)])
subprocess.run(command, check=True)

# Exact two-file runtime update already exercised by the native power proof.
proof = json.loads((REPO / "docs/art/thruster-resumption-20261117/animation-capture/native-power/validation.json").read_text())
runtime_updates = {}
for name, expected in proof["updated_runtime_source_hashes"].items():
    source = REPO / "tech-priests_src" / name
    assert sha(source) == expected, "Runtime changed since power-coupling proof"
    target = out / "mods/tech-priests" / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    runtime_updates[name] = expected

mod = out / "mods/model-visual-review_0.1.0"
command = [sys.executable, str(HERE / "import_power_graphics.py")]
for path in args.capture:
    command.extend(["--capture", str(path.resolve())])
command.extend(["--destination-mod", str(mod), "--mod-name", "model-visual-review"])
subprocess.run(command, check=True)
(mod / "data-final-fixes.lua").write_text('require("prototypes.generated_graphics.void-fusion-thrusters-v01")\n')

observer = r'''
-- Private read-only graphics-capture observer; never added to the normal source.
local GraphicsCaptureVisuals=require('scripts.core.void_fusion_visuals')
remote.add_interface('tp-fusion-capture-observer', {
 snapshot=function(unit)
  local tp=storage.tech_priests
  local record=tp and tp.void_fusion_thrusters and tp.void_fusion_thrusters[unit]
  if not record then return nil end
  local result=GraphicsCaptureVisuals.snapshot(record) or {}
  local sample=record.operation or {}
  result.operation={factor=sample.factor,power_watts=sample.power_watts,
    last_tick=sample.last_tick,phase=sample.phase,started_tick=sample.started_tick}
  result.sink_valid=record.sink and record.sink.valid or false
  if result.sink_valid then
   result.sink_power_watts=record.sink.power_usage*60
   result.sink_energy=record.sink.energy
  end
  return result
 end,
})
'''
control = out / "mods/tech-priests/control.lua"
control.write_text(control.read_text() + "\n" + observer, encoding="utf-8")

preparation_path = out / "capture-native-preparation.json"
preparation = json.loads(preparation_path.read_text())
import_manifest = json.loads((mod / "graphics/entity/void-fusion-thrusters-v01/import-manifest.json").read_text())
for binding in preparation["capture_bindings"]:
    name = binding["prototype"]
    prefix = "graphics/entity/void-fusion-thrusters-v01/" + name + "/"
    binding["files"] = [f for f in import_manifest["files"] if f["file"].startswith(prefix)]
    family = next(f for f in import_manifest["families"] if f["prototype"] == name)
    binding["energy_animation"] = family["energy_animation"]
    binding["plume_animation"] = family["plume_animation"]

# Rebind the scenario's immutable input identity after selecting exercised files.
fixture = (HERE / "capture-native-control.lua").read_text()
from prepare_capture_native import lua
fixture = fixture.replace("CAPTURE_FAMILIES_LUA", lua([b["prototype"] for b in preparation["capture_bindings"]]))
fixture = fixture.replace("CAPTURE_BINDINGS_JSON", json.dumps(preparation["capture_bindings"], separators=(",", ":")))
scenario = mod / "scenarios/model-placement/control.lua"
scenario.write_text(fixture, encoding="utf-8")
preparation.update(mode="actual_power_coupled", pilot=False,
    status="PREPARED_POWER_COUPLED_ART_REQUIRES_NATIVE_PIXELS_AND_FIT",
    data_sha256=sha(mod / "data-final-fixes.lua"), control_sha256=sha(scenario),
    graphics_module_sha256=sha(mod / "prototypes/generated_graphics/void-fusion-thrusters-v01.lua"),
    runtime_updates=runtime_updates, private_observer_control_sha256=sha(control),
    native_power_proof_sha256=sha(REPO / "docs/art/thruster-resumption-20261117/animation-capture/native-power/validation.json"))
preparation_path.write_text(json.dumps(preparation, indent=2) + "\n")
print(json.dumps({"status": preparation["status"], "profile": str(out)}))
