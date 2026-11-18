"""Prepare an isolated graphical fitting fixture from hash-bound fusion captures.

Ordinary prototypes are changed only inside a disposable review profile. The
frozen propulsion-validated source is copied, never linked or modified in place.
No personal Factorio profile, save or repository graphics is installed here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def lua(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", type=Path, action="append", required=True,
                        help="One capture-receipt.json per fusion family")
    parser.add_argument("--frozen-profile", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--allow-pilot", action="store_true")
    args = parser.parse_args()
    out, frozen = args.out.resolve(), args.frozen_profile.resolve()
    if out.exists():
        raise ValueError("Fresh output profile required; existing data will not be replaced")
    source = frozen / "mods/tech-priests"
    binding = json.loads((frozen / "source-binding.json").read_text())
    binding["files"].update(json.loads((frozen / "mounting-source-binding.json").read_text())["updated_files"])
    for name, digest in binding["files"].items():
        if sha(source / name) != digest:
            raise ValueError("Frozen source changed: " + name)

    captures = []
    allowed = {"void-fusion-thruster", "large-void-fusion-thruster"}
    for path in args.capture:
        path = path.resolve()
        receipt = json.loads(path.read_text())
        if receipt.get("schema") != "fusion_capture_v1" or receipt["prototype"] not in allowed:
            raise ValueError("Unexpected capture receipt " + str(path))
        if any(c[1]["prototype"] == receipt["prototype"] for c in captures):
            raise ValueError("Duplicate family")
        if receipt["layers"]["working_light"]["frame_count"] != 64:
            raise ValueError("Native clock fixture requires 64 final light samples")
        validation_path = path.parent / "package-validation.json"
        validation = json.loads(validation_path.read_text())
        if not validation.get("status", "").startswith("PASS"):
            raise ValueError("Capture package validation is incomplete")
        if (validation.get("input_glb_sha256") != receipt["input_glb"]["sha256"] or
                validation.get("master_sha256") != receipt.get("master_sha256")):
            raise ValueError("Capture package validation belongs to another model or master")
        if not args.allow_pilot and "PILOT" in str(receipt.get("stage", "")).upper():
            raise ValueError("Pilot input requires explicit --allow-pilot")
        if not args.allow_pilot and "service_underlay" not in receipt["layers"]:
            raise ValueError("Source-specific service underlay missing; pilot override required")
        glb = Path(receipt["input_glb"]["path"])
        if not glb.is_absolute():
            glb = path.parent / glb
        if sha(glb) != receipt["input_glb"]["sha256"]:
            raise ValueError("Capture input model changed")
        captures.append((path, receipt))

    mod = out / "mods/model-visual-review_0.1.0"
    mod.mkdir(parents=True)
    shutil.copytree(source, out / "mods/tech-priests")
    shutil.copy2(frozen / "source-binding.json", out / "source-binding.json")
    shutil.copy2(frozen / "mounting-source-binding.json", out / "mounting-source-binding.json")
    (mod / "info.json").write_text(json.dumps({"name": "model-visual-review", "version": "0.1.0",
        "title": "Private fusion capture fitting", "author": "Local review", "factorio_version": "2.1",
        "dependencies": ["base", "space-age", "tech-priests"]}, indent=2) + "\n")
    (mod / "data.lua").write_text((frozen / "mods/thruster-resume-proof/data.lua").read_text())
    shutil.copy2(frozen / "mods/mod-settings.dat", out / "mods/mod-settings.dat")
    (out / "mods/mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True}
        for n in ["base", "quality", "elevated-rails", "space-age", "tech-priests", "model-visual-review"]]}, indent=2))

    counter = Image.new("RGBA", (256, 128), (0, 0, 0, 255))
    draw = ImageDraw.Draw(counter)
    for frame in range(64):
        x, y = frame % 8 * 32, frame // 8 * 16
        for bit in range(6):
            draw.rectangle((x + 4 + bit * 4, y + 4, x + 7 + bit * 4, y + 11),
                           fill=(255, 255, 255, 255) if frame & (1 << bit) else (0, 0, 0, 255))
    (mod / "graphics").mkdir()
    counter.save(mod / "graphics/frame-counter.png")
    defs, capture_bindings = [], []
    for path, receipt in captures:
        name = receipt["prototype"]
        folder = mod / "graphics" / name
        folder.mkdir()
        reg = receipt["registration"]
        common = {"width": reg["cell"][0], "height": reg["cell"][1],
                  "scale": reg["scale"], "shift": reg["shift_tiles"]}
        local_files = []

        def layer(key: str):
            spec = receipt["layers"][key]
            files = spec.get("files") or [spec["file"]]
            names = []
            for relative in files:
                src = path.parent / relative
                expected = spec.get("sha256") if len(files) == 1 else spec.get("file_sha256", {}).get(relative)
                if not expected or sha(src) != expected:
                    raise ValueError("Capture package image changed: " + str(src))
                with Image.open(src) as image:
                    image.verify()
                target = folder / src.name
                shutil.copy2(src, target)
                local_files.append({"file": str(target.relative_to(mod)).replace("\\", "/"), "sha256": sha(target)})
                names.append("__model-visual-review__/graphics/" + name + "/" + target.name)
            result = dict(common, frame_count=spec["frame_count"])
            result["filename" if len(names) == 1 else "filenames"] = names[0] if len(names) == 1 else names
            if spec["frame_count"] > 1:
                for k in ("line_length", "lines_per_file", "animation_speed"):
                    result[k] = spec[k]
            return result

        cold, shadow, light = layer("cold_body"), layer("deck_shadow"), layer("working_light")
        shadow["draw_as_shadow"] = True
        speed = receipt["layers"]["working_light"]["animation_speed"]
        body = dict(cold, repeat_count=64, animation_speed=speed)
        moving_shadow = dict(shadow, repeat_count=64, animation_speed=speed)
        light.update(draw_as_glow=True, blend_mode="additive")

        def marker(x):
            return {"filename": "__model-visual-review__/graphics/frame-counter.png", "width": 32,
                    "height": 16, "line_length": 8, "frame_count": 64,
                    "animation_speed": speed, "scale": .5, "shift": [x, -5]}

        working = [{"name": "capture-green-strobe", "fadeout": True,
                    "animation": {"layers": [light, marker(0)]}}]
        if "service_underlay" in receipt["layers"]:
            working.insert(0, {"name": "capture-service-underlay", "always_draw": True,
                               "render_layer": "floor", "animation": layer("service_underlay")})
        if "field_candidate" in receipt["layers"]:
            field = layer("field_candidate")
            field.update(draw_as_glow=True, blend_mode="additive")
            working.append({"name": "capture-field-candidate", "fadeout": True,
                            "animation": {"layers": [field, marker(3)]}})
        defs.append("do\nlocal p=data.raw.thruster[" + lua(name) + "]\nassert(p)\n"
                    "p.graphics_set.animation=" + lua({"north": {"layers": [body, moving_shadow, marker(-3)]}}) + "\n"
                    "p.graphics_set.idle_animation=" + lua({"north": {"layers": [dict(cold, repeat_count=64, animation_speed=speed), dict(shadow, repeat_count=64, animation_speed=speed)]}}) + "\n"
                    "p.graphics_set.working_visualisations=" + lua(working) + "\n"
                    "p.graphics_set.always_draw_idle_animation=false\n"
                    "p.graphics_set.animation_random_start_frame=false\n"
                    "p.graphics_set.flame_effect=nil\np.plumes=nil\n"
                    "p.drawing_box={{-8,-9},{8,16}}\nend\n")
        capture_bindings.append({"prototype": name, "receipt_path": str(path), "receipt_sha256": sha(path),
                                 "input_glb": receipt["input_glb"], "registration": reg,
                                 "files": local_files, "has_field_candidate": "field_candidate" in receipt["layers"]})
    (mod / "data-final-fixes.lua").write_text("\n".join(defs), encoding="utf-8")
    scenario = mod / "scenarios/model-placement"
    scenario.mkdir(parents=True)
    fixture = Path(__file__).with_name("capture-native-control.lua").read_text()
    fixture = fixture.replace("CAPTURE_FAMILIES_LUA", lua([c["prototype"] for c in capture_bindings]))
    fixture = fixture.replace("CAPTURE_BINDINGS_JSON", json.dumps(capture_bindings, separators=(",", ":")))
    (scenario / "control.lua").write_text(fixture, encoding="utf-8")
    userdata = out / "user-data"
    userdata.mkdir()
    (out / "config.ini").write_text("[path]\nread-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data\n"
        + "write-data=" + str(userdata).replace("\\", "/") + "\n[other]\ncheck-updates=false\n"
        "[graphics]\ngraphics-quality=high\noptimize-for-low-vram=false\nvideo-memory-usage=low\n")
    proof = {"status": "PREPARED_REQUIRES_ACTUAL_HIGH_QUALITY_NATIVE_LOAD_AND_CAPTURE", "pilot": args.allow_pilot,
             "frozen_profile": str(frozen), "capture_bindings": capture_bindings,
             "data_sha256": sha(mod / "data-final-fixes.lua"), "control_sha256": sha(scenario / "control.lua"),
             "scope": "Ordinary registered fusion names in disposable profile; real servicing and route. Native shaders/refraction not claimed. No normal installation."}
    (out / "capture-native-preparation.json").write_text(json.dumps(proof, indent=2) + "\n")
    print(json.dumps({"status": proof["status"], "profile": str(out), "families": len(captures)}))


if __name__ == "__main__":
    main()
