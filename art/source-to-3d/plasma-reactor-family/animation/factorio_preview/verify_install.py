"""Verify the packaged reactors with a private Factorio 2.1 installation profile."""
import argparse
import hashlib
import io
import json
import math
import shutil
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZipFile

from PIL import Image, ImageChops

MOD = "mars-reactor-visuals"
# Original FMPL capture width and the uncropped ground shift in Factorio tiles.
CAPTURES = {
    "minoris": (384, 0.5, -1.193242693252299),
    "majoris": (512, 0.6969696969696969, -1.6633079966547197),
    "maximus": (704, 0.9242424242424242, -2.205691039042128),
}
HEADINGS = ("north", "east", "south", "west")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_sheet(archive, member, layer, role, capture, quality, canonical):
    hr, cx, cy = capture
    size, ppt = (hr, 64) if quality == "hr" else (hr // 2, 32)
    side = 4 if role in ("on", "glow") else 1
    w, h = layer["width"], layer["height"]
    sx, sy = layer["shift"]
    x = (sx - cx) * ppt + (size - w) / 2
    y = (sy - cy) * ppt + (size - h) / 2
    require(abs(x - round(x)) < .002 and abs(y - round(y)) < .002, f"Fractional capture offset in {member}")
    x, y = round(x), round(y)
    require(0 <= x <= size - w and 0 <= y <= size - h, f"Outside capture bounds: {member}")
    require(layer["frame_count"] == side**2 and layer["repeat_count"] == 16 // side**2
            and layer["line_length"] == side and math.isclose(layer["animation_speed"], 8 / 60)
            and layer["scale"] == 32 / ppt, f"Wrong registration or timing: {member}")
    if role == "glow":
        require(layer.get("draw_as_glow") and layer.get("blend_mode") == "additive", member)
    if role == "shadow":
        require(layer.get("draw_as_shadow"), member)
    with Image.open(io.BytesIO(archive.read(member))) as image:
        require(image.mode == "RGBA" and image.size == (w * side, h * side), f"Wrong atlas shape: {member}")
        poses = set()
        for i in range(side**2):
            left, top = i % side * w, i // side * h
            cell = image.crop((left, top, left + w, top + h))
            alpha = cell.getchannel("A")
            require(alpha.getbbox(), f"Empty cell {i+1} in {member}")
            if role == "on":
                # A smoke-test atlas contains only four colored pixels on transparency.
                require(sum(alpha.histogram()[32:]) > size**2 / 100 and cell.getcolors(64) is None,
                        f"Fixture or blank reactor artwork in {member} cell {i+1}")
            if side == 4:
                poses.add(hashlib.sha256(cell.tobytes()).digest())
            if canonical is not None:
                source = canonical / (f"layers/{i+1:02d}-{role}.png" if side == 4 else f"{role}.png")
                with Image.open(source) as original:
                    rgba = original.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
                restored = Image.new("L", (size, size))
                restored.paste(alpha, (x, y))
                error = ImageChops.difference(rgba.getchannel("A"), restored).getextrema()[1]
                require(error <= 2, f"Capture alpha mismatch ({error}) in {member} cell {i+1}")
        if side == 4:
            require(len(poses) > 1, f"Static operating sheet: {member}")
    return side**2


def check_graphics(dump, installed, quality, frames):
    generators = json.loads(dump.read_text(encoding="utf-8"))["burner-generator"]
    uses = cells = 0
    with ZipFile(installed) as archive:
        for tier, capture in CAPTURES.items():
            generator = generators["mars-plasma-reactor-" + tier]
            for heading in HEADINGS:
                roles = {}
                for state, expected in (("animation", ["shadow", "on", "glow"]), ("idle_animation", ["shadow", "off"])):
                    layers = generator[state][heading]["layers"]
                    require(len(layers) == len(expected), f"Wrong {state} layers for {tier} {heading}")
                    for role, layer in zip(expected, layers):
                        path = f"graphics/{quality}/{tier}/{heading}-{role}.png"
                        require(layer["filename"] == f"__{MOD}__/{path}", f"Wrong engine asset for {tier} {heading} {role}")
                        if role not in roles:
                            canonical = frames / tier / heading if frames is not None else None
                            cells += check_sheet(archive, f"{installed.stem}/{path}", layer, role,
                                                 capture, quality, canonical)
                            roles[role] = layer
                        else:
                            require(layer == roles[role], f"Idle and operating shadow differ for {tier} {heading}")
                        uses += 1
    return {"engine_layer_uses": uses, "atlas_cells_checked": cells,
            "canonical_cell_alpha_comparisons": cells if frames is not None else 0}


def start(command, *args):
    result = subprocess.run([*command, *args],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            errors="replace", timeout=180)
    if result.returncode:
        raise RuntimeError(f"Factorio exited {result.returncode}\n" + "\n".join(result.stdout.splitlines()[-30:]))
    return result.stdout


def enable(mods, helper=False):
    enabled = {"base", MOD}
    if helper:
        enabled.add("select-sd")
    names = sorted(enabled | {"quality", "elevated-rails", "space-age"})
    (mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": n in enabled} for n in names]}))


def select_sd(command, mods):
    # Let this engine write its settings format. Remove the helper before loading the tested package.
    helper = mods / "select-sd_1.0.0"
    helper.mkdir()
    (helper / "info.json").write_text(json.dumps({"name": "select-sd", "version": "1.0.0",
        "title": "Select SD in this temporary profile", "author": "QA", "factorio_version": "2.1", "dependencies": [MOD]}))
    (helper / "settings-updates.lua").write_text('data.raw["string-setting"]["mars-reactor-sprite-resolution"].default_value="sd"\n')
    enable(mods, helper=True)
    start(command, "--dump-prototype-locale")
    require((mods / "mod-settings.dat").is_file(), "Factorio did not save private startup settings")
    shutil.rmtree(helper)


def check_runtime(log, quality):
    def markers(label):
        return [json.loads(line.split(label, 1)[1]) for line in log.splitlines() if label in line]

    rows, passes = markers("MARS_POWER_CASE "), markers("MARS_POWER_PASS ")
    expected = {(tier, d) for tier in CAPTURES for d in (0, 4, 8, 12)}
    require("Test passed at tick 421" in log and passes == [{"cases": 12, "tick": 420, "sprite_resolution": quality}],
            f"Power-cycle scenario did not finish at {quality}")
    require(len(rows) == 12 and {(r["tier"], r["direction"]) for r in rows} == expected, f"Missing {quality} power case")
    for row in rows:
        require(row["idle_active_idle"] and row["rotation_steps"] == 4 and row["fuel_items"] == 1
                and abs(row["generator_joules"] - 2e6) < 1 and abs(row["load_joules"] - 2e6) < 1, str(row))
    return {"evidence": passes[0], "rows": rows}


def digest(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def verify(exe, package, frames):
    version = subprocess.check_output([str(exe), "--version"], text=True).splitlines()[0]
    read_data = next(((parent / "data").as_posix() for parent in exe.parents
                      if (parent / "data/core/info.json").is_file()), "__PATH__system-read-data__")
    sha = digest(package)
    cases = {}
    for quality in ("hr", "sd"):
        with tempfile.TemporaryDirectory(prefix=f"mars-reactor-{quality}-") as temporary:
            work = Path(temporary)
            mods, user = work / "mods", work / "user"
            mods.mkdir()
            (user / "script-output").mkdir(parents=True)
            installed = Path(shutil.copyfile(package, mods / package.name))
            require(digest(installed) == sha, "Input ZIP changed during verification")
            config = work / "config.ini"
            config.write_text(f"[path]\nread-data={read_data}\nwrite-data={user.as_posix()}\n[other]\ncheck-updates=false\n")
            command = [str(exe), "-c", str(config), "--mod-directory", str(mods)]
            if quality == "sd":
                select_sd(command, mods)
            enable(mods)
            log = start(command, "--test-scenario", MOD + "/reactor-power-cycle", "--test-ticks", "440",
                        "--check-unused-prototype-data")
            cases[quality] = check_runtime(log, quality)
            start(command, "--dump-data")
            cases[quality]["graphics"] = check_graphics(user / "script-output/data-raw-dump.json", installed, quality, frames)
    return {"engine": version, "pass": True, "native_cases": 24, "archive_sha256": sha,
            "archive_bytes": package.stat().st_size, "resolutions": cases,
            "visual_evidence": "Headless engine prototype and power tests; PNG and optional capture-alpha checks run separately."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("factorio", type=Path, help="Factorio 2.1 executable")
    parser.add_argument("mod_zip", type=Path, help="Packaged mars-reactor-visuals ZIP with its original filename")
    parser.add_argument("--frames", type=Path, help="Optional uncropped FMPL frame directory for alpha comparison")
    parser.add_argument("--receipt", type=Path, help="Write the complete JSON result to this path")
    args = parser.parse_args()
    result = verify(args.factorio.resolve(), args.mod_zip.resolve(), args.frames)
    report = json.dumps(result, indent=2) + "\n"
    if args.receipt:
        args.receipt.write_text(report, encoding="utf-8")
    print(f"Passed 24 power cycles and 816 atlas cell checks. ZIP SHA-256 {result['archive_sha256']}")
