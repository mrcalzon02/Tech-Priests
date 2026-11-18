"""Verify a complete 64-cell source capture without claiming native art fit."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
try:
    from PIL import Image
except ImportError:
    sys.path.insert(0, str(REPO.parent / "local-validation/deps"))
    from PIL import Image


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path)
args = parser.parse_args()
root = args.directory.resolve()
receipt_path = root / "capture-receipt.json"
package_path = root / "package-validation.json"
receipt = json.loads(receipt_path.read_text())
package = json.loads(package_path.read_text())
assert receipt["stage"] == "FINAL_CAPTURE_CANDIDATE"
assert package["status"].startswith("PASS_FINAL")
assert receipt["timeline"]["output_frames"] == 64
assert package["input_glb_sha256"] == receipt["input_glb"]["sha256"]
assert package["master_sha256"] == receipt["master_sha256"]
assert package["registration"] == receipt["registration"]
assert package["layers"] == receipt["layers"]
assert sha(receipt["input_glb"]["path"]) == receipt["input_glb"]["sha256"]
assert sha(root / "capture-master.blend") == receipt["master_sha256"]
assert package["physical_coverage_witness_exact"] is True
assert package["working_energy_preserves_body_coverage"] is True
assert package["rendered_wrap"] == {"working_light": True, "field": True}

dynamic = {}
white_clipped = 0
for row in receipt["frames"]:
    assert sha(root / row["file"]) == row["sha256"], ("Changed source PNG", row["file"])
    assert row["physical_digest"] == receipt["physical_digest"]
    assert row["camera"] == receipt["camera"]
for layer in ("working_light", "field"):
    rows = [row for row in receipt["frames"] if row["layer"] == layer]
    assert len(rows) == 65 and {r["index"] for r in rows} == set(range(65))
    dynamic[layer] = {row["index"]: row for row in rows}
    raw_wrap = []
    for row in rows:
        path = root / row["file"]
        with Image.open(path) as source:
            image = source.convert("RGBA")
            image.load()
        if row["index"] in (0, 64):
            raw_wrap.append((row["index"], image.tobytes()))
        if layer == "field":
            white_clipped += sum(p[3] > 0 and p[:3] == (255, 255, 255)
                                 for p in image.getdata())
    assert len(raw_wrap) == 2 and raw_wrap[0][1] == raw_wrap[1][1]
assert white_clipped == 0

axis = receipt["plume"]["axis"]
states = [{v["object"]: v for v in dynamic["field"][i]["plume_state"]}
          for i in range(65)]
assert states[0] == states[64], "Real lifecycle wrap state differs"
names = [name for name, value in states[0].items() if not value.get("core")]
motion = []
acceleration = []
for name in names:
    previous_speed = None
    fades = []
    positions = []
    for before, after in zip(states, states[1:]):
        v, w = before[name], after[name]
        fades.append(v["fade"])
        positions.append(v["axial_distance"])
        if w["age_fraction"] <= v["age_fraction"]:
            previous_speed = None
            continue
        displacement = sum((w["position"][a] - v["position"][a]) * axis[a]
                           for a in range(3))
        assert displacement > 0, ("Nonrecycled ejecta moved upstream", name)
        motion.append(displacement)
        if previous_speed is not None:
            delta = displacement - previous_speed
            assert delta > 0, ("Downstream motion did not accelerate", name, delta)
            acceleration.append(delta)
        previous_speed = displacement
    assert min(fades) < .1 and max(fades) > .9, ("Lifetime fade is absent", name)
    assert max(positions) > receipt["plume"]["length"] * .9
assert len(names) == receipt["plume"]["particle_count"] + receipt["plume"]["wisp_count"]
assert motion and acceleration

anchors = [anchor for arc in receipt["arcs"]["arcs"]
           for anchor in (arc["a"], arc["b"], arc.get("branch")) if anchor]
maximum_ray_error = max(v["actual_local_surface_ray_error"] for v in anchors)
assert maximum_ray_error < .005
native_path = REPO / "docs/art/thruster-resumption-20261117/animation-capture/native-power/validation.json"
native = json.loads(native_path.read_text())
assert native["status"] == "PASS_NATIVE_REAL_VISUAL_POWER_RGBA_LIFECYCLE_AND_SAVE_RELOAD"
report = {
    "status": "PASS_FINAL64_ADVECTING_SOURCE_AND_COVERAGE",
    "prototype": receipt["prototype"],
    "body_glb": receipt["input_glb"],
    "capture_receipt_sha256": sha(receipt_path),
    "package_validation_sha256": sha(package_path),
    "verifier_sha256": sha(__file__),
    "master_sha256": receipt["master_sha256"],
    "actual_source_pngs_checked": len(receipt["frames"]),
    "actual_dynamic_pngs_checked": 130,
    "actual_rendered_wrap": package["rendered_wrap"],
    "actual_physical_coverage_witness_exact": True,
    "actual_working_energy_preserves_body_coverage": True,
    "advecting_objects": len(names),
    "nonrecycled_adjacent_motion_witnesses": len(motion),
    "strict_downstream_displacement_range": [min(motion), max(motion)],
    "strict_acceleration_witnesses": len(acceleration),
    "strict_acceleration_range": [min(acceleration), max(acceleration)],
    "actual_surface_arc_count": len(receipt["arcs"]["arcs"]),
    "maximum_actual_surface_ray_error": maximum_ray_error,
    "white_clipped_ejecta_pixels": white_clipped,
    "field_renderer": dynamic["field"][0]["renderer"],
    "field_renderer_settings": dynamic["field"][0]["eevee_settings"],
    "registration": receipt["registration"],
    "brightness_contract": receipt["brightness_contract"],
    "separate_native_draw_control_evidence": {"path": str(native_path), "sha256": sha(native_path)},
    "scope": "Complete source-derived 64-cell capture, real wrap/coverage, actual surface anchors and downstream motion. Real electrical control is separately native-proved. Final detailed-body pixels, fit, native assembly and owner appearance acceptance remain separate gates. No physical fluid simulation or background refraction is claimed."
}
(root / "advecting-capture-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(report["status"], receipt["prototype"], len(motion), "motion witnesses")
