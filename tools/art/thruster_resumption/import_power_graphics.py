"""Build reviewed power-coupled fusion graphics in a source or private mod.

Does not add a require to the normal mod or install a profile. The caller first
loads the generated module in a disposable native fitting fixture.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image
from prepare_capture_native import lua

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
parser = argparse.ArgumentParser()
parser.add_argument("--capture", action="append", type=Path, required=True)
parser.add_argument("--destination-mod", type=Path, required=True)
parser.add_argument("--mod-name", required=True)
args = parser.parse_args()
destination = args.destination_mod.resolve()
rows, blocks, all_files = [], [], []
for input_path in args.capture:
    input_path = input_path.resolve()
    receipt = json.loads(input_path.read_text())
    check = json.loads((input_path.parent / "package-validation.json").read_text())
    assert receipt["schema"] == "fusion_capture_v1"
    assert check["status"].startswith("PASS_FINAL"), "Final complete source capture required"
    name = receipt["prototype"]
    assert name in {"void-fusion-thruster", "large-void-fusion-thruster"}
    assert name not in [r["prototype"] for r in rows]
    assert check["input_glb_sha256"] == receipt["input_glb"]["sha256"]
    assert check["master_sha256"] == receipt["master_sha256"]
    assert check["registration"] == receipt["registration"], "Changed post-package registration"
    assert check["layers"] == receipt["layers"], "Changed post-package layer specification"
    assert sha(Path(receipt["input_glb"]["path"])) == receipt["input_glb"]["sha256"]
    layers = receipt["layers"]
    assert layers["working_light"]["frame_count"] == layers["field_candidate"]["frame_count"] == 64
    kind = layers["field_candidate"].get("kind", "").lower()
    assert ("particle" in kind or "ejecta" in kind) and "filament" not in kind, "Superseded loop/tube field capture"
    registration = receipt["registration"]
    folder = destination / "graphics/entity/void-fusion-thrusters-v01" / name
    folder.mkdir(parents=True, exist_ok=True)

    def sprite(key):
        spec = layers[key]
        paths = spec.get("files") or [spec["file"]]
        output_paths = []
        for relative in paths:
            source = input_path.parent / relative
            expected = spec.get("sha256") if len(paths) == 1 else spec["file_sha256"][relative]
            assert sha(source) == expected, "Changed atlas: " + relative
            with Image.open(source) as image:
                image.verify()
            target = folder / source.name
            if target.exists():
                assert sha(target) == expected, "Refusing to overwrite another source capture"
            else:
                shutil.copy2(source, target)
            local = target.relative_to(destination).as_posix()
            all_files.append({"file": local, "sha256": expected})
            output_paths.append("__" + args.mod_name + "__/" + local)
        result = {"width": registration["cell"][0], "height": registration["cell"][1],
                  "frame_count": spec["frame_count"], "scale": registration["scale"],
                  "shift": registration["shift_tiles"]}
        result["filename" if len(paths) == 1 else "filenames"] = output_paths[0] if len(paths) == 1 else output_paths
        if spec["frame_count"] > 1:
            for key in ("line_length", "lines_per_file", "animation_speed"):
                result[key] = spec[key]
        return result

    body, shadow, underlay = sprite("cold_body"), sprite("deck_shadow"), sprite("service_underlay")
    shadow["draw_as_shadow"] = True
    energy, plume = sprite("working_light"), sprite("field_candidate")
    for animation in (energy, plume):
        animation.update(type="animation", blend_mode="additive", draw_as_glow=True,
                         apply_runtime_tint=True)
    energy["name"] = "tp-" + name + "-energy-v01"
    plume["name"] = "tp-" + name + "-plume-v01"
    static = {"north": {"layers": [body, shadow]}}
    # Camera/crop projection bounds, not guessed footprint dimensions.
    w, h = registration["cell"]
    scale = registration["scale"]
    sx, sy = registration["shift_tiles"]
    bounds = [[sx - w * scale / 64, sy - h * scale / 64],
              [sx + w * scale / 64, sy + h * scale / 64]]
    blocks.append("do\nlocal p=data.raw.thruster and data.raw.thruster[" + lua(name) + "]\nif p then\n"
        "p.graphics_set.animation=" + lua(static) + "\n"
        "p.graphics_set.idle_animation=" + lua(copy.deepcopy(static)) + "\n"
        "p.graphics_set.always_draw_idle_animation=false\n"
        "p.graphics_set.animation_random_start_frame=false\n"
        "p.graphics_set.working_visualisations=" + lua([{"name": "authored-fusion-service-well", "always_draw": True,
            "render_layer": "floor", "animation": underlay}]) + "\n"
        "p.graphics_set.integration_patch=nil\np.graphics_set.flame_effect=nil\np.plumes=nil\n"
        "p.drawing_box=" + lua(bounds) + "\n"
        "data:extend(" + lua([energy, plume]) + ")\nend\nend\n")
    rows.append({"prototype": name, "capture_receipt": str(input_path), "receipt_sha256": sha(input_path),
                 "input_glb": receipt["input_glb"], "registration": registration,
                 "energy_animation": energy["name"], "plume_animation": plume["name"], "plume_kind": kind})

module = destination / "prototypes/generated_graphics/void-fusion-thrusters-v01.lua"
module.parent.mkdir(parents=True, exist_ok=True)
text = ("-- Authored fixed-north fusion bodies and separate power-coupled runtime effects.\n"
        "-- Rigid bodies/underlays/shadows are static; energy/ejecta are 64-frame animations.\n"
        "-- scripts.core.void_fusion_visuals supplies the actual per-engine draw tint.\n" + "\n".join(blocks))
if module.exists():
    assert module.read_text() == text, "Refusing to overwrite another graphics module"
else:
    module.write_text(text, encoding="utf-8")
report = {"status": "GENERATED_REQUIRES_NATIVE_POWER_COUPLING_AND_FITTING_PROOF",
          "module": str(module), "module_sha256": sha(module), "families": rows, "files": all_files,
          "scope": "Source/private-mod graphics only. No normal-profile installation or late-import activation performed."}
(destination / "graphics/entity/void-fusion-thrusters-v01/import-manifest.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "module": str(module), "families": len(rows)}))
