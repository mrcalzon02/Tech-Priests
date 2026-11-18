"""Bind real graphical-client pixels to the actual power-controlled animations."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("profile", type=Path)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
root, out = args.profile.resolve(), args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
prep = json.loads((root / "capture-native-preparation.json").read_text())
assert prep["mode"] == "actual_power_coupled" and not prep["pilot"]
mod = root / "mods/model-visual-review_0.1.0"
assert sha(mod / "data-final-fixes.lua") == prep["data_sha256"]
assert sha(mod / "scenarios/model-placement/control.lua") == prep["control_sha256"]
assert sha(mod / "prototypes/generated_graphics/void-fusion-thrusters-v01.lua") == prep["graphics_module_sha256"]
assert sha(root / "mods/tech-priests/control.lua") == prep["private_observer_control_sha256"]
for relative, expected in prep["runtime_updates"].items():
    assert sha(root / "mods/tech-priests" / relative) == expected
log = (root / "user-data/factorio-current.log").read_text(errors="replace")
assert re.search(r"Graphics options: \[Graphics quality: high\]", log)
assert '"--low-vram"' not in log
source = root / "user-data/script-output"
native = json.loads((source / "fusion-capture-native/receipt.json").read_text())
expected_bindings = {b["prototype"]: b for b in prep["capture_bindings"]}
assert {b["prototype"] for b in native["bindings"]} == expected_bindings.keys()
assert len(native["rows"]) == len(expected_bindings), "Missing or duplicate native family rows"
assert {row["name"] for row in native["rows"]} == expected_bindings.keys(), "Native family coverage differs"
for binding in native["bindings"]:
    expected = expected_bindings[binding["prototype"]]
    assert binding["receipt_sha256"] == expected["receipt_sha256"]
    assert binding["input_glb"]["sha256"] == expected["input_glb"]["sha256"]
for binding in expected_bindings.values():
    for row in binding["files"]:
        assert sha(mod / row["file"]) == row["sha256"]

results = []
for row in native["rows"]:
    name = row["name"]
    binding = expected_bindings[name]
    checked, powered, plume, frames, clock_shots = [], [], [], [], []
    max_tint_error = max_watt_error = 0.0
    for shot in row["shots"]:
        path = source / shot["file"]
        with Image.open(path) as image:
            image.verify()
        image = Image.open(path).convert("RGB")
        values = shot["snapshot"]
        visuals = values.get("visuals")
        assert visuals and not visuals.get("render_errors"), (name, shot["tick"], visuals)
        operation = visuals["operation"]
        assert visuals["last_tick"] == operation["last_tick"]
        assert 0 <= values["game_tick"] - visuals["last_tick"] <= 10
        assert abs(visuals["factor"] - operation["factor"]) <= 1e-12
        watt_error = abs(values["power_watts"] - operation["power_watts"])
        max_watt_error = max(max_watt_error, watt_error)
        assert watt_error < 1e-6
        level = operation["factor"] / 1.5 if visuals["powered"] else 0
        for key, animation in [("energy", binding["energy_animation"]), ("plume", binding["plume_animation"])]:
            actual = visuals[key]
            assert actual.get("id") and actual["animation"] == animation
            assert abs(actual["animation_speed"] - 32 / 60) < 1e-12
            for channel in ("r", "g", "b", "a"):
                error = abs(actual["color"][channel] - level)
                max_tint_error = max(max_tint_error, error)
                assert error < 1e-6
        assert visuals["energy"]["visible"] == visuals["powered"]
        if not visuals["powered"]:
            assert not visuals["plume"]["visible"]
        checked.append(dict(shot, sha256=sha(path)))
        if visuals["powered"]:
            powered.append(operation["factor"])
        if visuals["plume"]["visible"]:
            plume.append(shot["tick"])
        if shot["label"] == "clock":
            frames.append(image)
            clock_shots.append(shot)
        else:
            image.save(out / (name + "-" + shot["label"] + ".png"))
    assert len(frames) == 256, "Incomplete actual screenshot sequence"
    assert len(powered) > 20 and max(powered) - min(powered) > .15
    assert plume, "No actual working/plume state captured"
    states = {s["label"]: s["snapshot"]["visuals"] for s in checked if s["label"] != "clock"}
    assert not states["idle"]["powered"] and not states["idle"]["energy"]["visible"]
    assert states["restart"]["powered"]
    assert states["paused-powered"]["powered"] and states["paused-powered"]["energy"]["visible"]
    assert not states["paused-powered"]["plume"]["visible"]
    paused = next(s for s in checked if s["label"] == "paused-powered")
    assert paused["snapshot"]["platform_paused"] is True
    # This GIF is chronological native pixels. It is not a reordered source loop.
    # Select a contiguous interval with the most genuine working plume frames.
    # This keeps real chronological power/motion and avoids leading with an
    # arrival/waiting interval when an uninterrupted flight interval is present.
    start = max(range(len(frames) - 127), key=lambda i: sum(
        s["snapshot"]["visuals"]["plume"]["visible"] for s in clock_shots[i:i + 128]))
    gif_frames = [im.resize((320, 550), Image.Resampling.LANCZOS) for im in frames[start:start + 128:2]]
    gif = out / (name + "-native-power-working.gif")
    gif_frames[0].save(gif, save_all=True, append_images=gif_frames[1:],
                       duration=[33, 33, 34] * 21 + [33], loop=0)
    results.append({"prototype": name, "checked_screenshots": checked,
        "powered_factor_range": [min(powered), max(powered)], "plume_visible_ticks": plume,
        "maximum_actual_tint_error": max_tint_error, "maximum_same_sink_watt_error": max_watt_error,
        "gif_sha256": sha(gif), "gif_native_tick_interval": [clock_shots[start]["tick"], clock_shots[start + 127]["tick"]],
        "gif_selection": "Contiguous128tick native interval maximizing actual plume-visible samples; chronological every2ticks, no source-loop substitution.",
        "registration": binding["registration"]})
report = {"status": "PASS_NATIVE_POWER_CONTROLLED_ART_REQUIRES_ACTUAL_IMAGE_FIT_REVIEW",
    "preparation_sha256": sha(root / "capture-native-preparation.json"),
    "native_receipt_sha256": sha(source / "fusion-capture-native/receipt.json"),
    "high_quality_actual_log_verified": True, "families": results,
    "scope": "Actual ordinary serviced drives, real sink/operation, native render color/visibility and chronological graphical-client screenshots. Full64 source-cell/wrap validation and save/reload are separate bound reports. Final appearance/fit requires viewing these actual images."}
(out / "native-power-art-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "families": [r["prototype"] for r in results]}))
