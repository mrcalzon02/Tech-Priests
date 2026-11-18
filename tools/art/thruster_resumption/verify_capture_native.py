"""Decode actual graphical-client layer clocks and bind capture evidence."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("profile", type=Path)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
root, out = args.profile.resolve(), args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
prep = json.loads((root / "capture-native-preparation.json").read_text())
mod = root / "mods/model-visual-review_0.1.0"
assert sha(mod / "data-final-fixes.lua") == prep["data_sha256"]
assert sha(mod / "scenarios/model-placement/control.lua") == prep["control_sha256"]
log = (root / "user-data/factorio-current.log").read_text(errors="replace")
assert re.search(r"Graphics options: \[Graphics quality: high\]", log), "Actual client did not use high quality"
assert '"--low-vram"' not in log, "Reduced quality launch cannot establish appearance"
output = root / "user-data/script-output"
receipt = json.loads((output / "fusion-capture-native/receipt.json").read_text())


def same_binding(a, b):
    # Lua JSON parse/write can change a double by one ULP. Hashes, paths and
    # structure remain exact; numerical registration allows only 1e-12 units.
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same_binding(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same_binding(x, y) for x, y in zip(a, b))
    if type(a) in (int, float) and type(b) in (int, float):
        return math.isclose(a, b, rel_tol=0, abs_tol=1e-12)
    return type(a) is type(b) and a == b


assert same_binding(receipt["bindings"], prep["capture_bindings"])
for binding in prep["capture_bindings"]:
    for row in binding["files"]:
        assert sha(mod / row["file"]) == row["sha256"], row["file"]


def decode(image, center_x):
    # Fixture: 640x1100,zoom2; entity-centeredX, cameraY=entityY+2.5.
    # Marker sprite32x16,scale.5,shiftY=-5: centers atY70.
    levels = []
    for bit in range(6):
        x = round(center_x - 16 + 5.5 + bit * 4)
        patch = image.crop((x, 68, x + 2, 72)).convert("RGB")
        values = list(patch.getdata())
        levels.append(sum(sum(v) / 3 for v in values) / len(values))
    assert all(v < 55 or v > 200 for v in levels), ("Ambiguous clock readback", levels)
    return sum(1 << bit for bit, value in enumerate(levels) if value > 128), levels


results = []
for row in receipt["rows"]:
    name = row["name"]
    binding = next(v for v in prep["capture_bindings"] if v["prototype"] == name)
    clocks = []
    originals = []
    for shot in row["shots"]:
        path = output / shot["file"]
        assert path.exists()
        if shot["label"] != "clock":
            continue
        image = Image.open(path).convert("RGB")
        assert image.size == (640, 1100)
        body, body_levels = decode(image, 128)
        light, light_levels = decode(image, 320)
        field, field_levels = decode(image, 512) if binding["has_field_candidate"] else (None, [])
        clocks.append({"tick": shot["tick"], "file": shot["file"], "sha256": sha(path),
                       "body_clock": body, "light_clock": light, "field_clock": field,
                       "levels": [body_levels, light_levels, field_levels]})
        originals.append(image)
    assert len(clocks) == 256
    assert all(v["body_clock"] == v["light_clock"] and
               (v["field_clock"] is None or v["body_clock"] == v["field_clock"]) for v in clocks), "Native layer phase mismatch"
    unique = len({v["body_clock"] for v in clocks})
    assert unique == 64, (name, "Incomplete native clock coverage", unique)
    # Preserve real chronological native screenshots, including engine timing.
    frames = [image.resize((320, 550), Image.Resampling.LANCZOS) for image in originals[:128:2]]
    dest = out / (name + "-native-working.gif")
    frames[0].save(dest, save_all=True, append_images=frames[1:], duration=[33, 33, 34] * 21 + [33], loop=0)
    states = []
    for shot in row["shots"]:
        if shot["label"] == "clock":
            continue
        path = output / shot["file"]
        states.append(dict(shot, sha256=sha(path)))
        Image.open(path).save(out / (name + "-" + shot["label"] + ".png"))
    results.append({"prototype": name, "clocks": clocks, "unique_clock_frames": unique,
                    "all_three_clocks_equal": True, "states": states, "final": row["final"],
                    "gif_sha256": sha(dest), "registration": binding["registration"]})
report = {"status": "PASS_NATIVE_LAYER_CLOCKS_REQUIRES_FIT_AND_IMAGE_REVIEW",
          "preparation_sha256": sha(root / "capture-native-preparation.json"),
          "native_receipt_sha256": sha(output / "fusion-capture-native/receipt.json"),
          "high_quality_actual_log_verified": True, "families": results,
          "scope": "Actual ordinary serviced-drive sprite clocks on disposable edge-mounted platforms. Body geometry is rigid; counters prove layer clocks, not moving machinery. Field art is stylized, not actual background refraction. Owner appearance and projected mounting fit remain separate."}
(out / "native-capture-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "families": [r["prototype"] for r in results]}))
