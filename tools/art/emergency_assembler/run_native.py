"""Exercise the real emergency assembler builder and V07 art in Factorio 2.1.

Only the selected production prototype and its real helper/spec blocks are
extracted. No test-only replacement assembler, recipes, fuel or power is used.
The probe has a private config, mods, save and write-data directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


ROOT = Path(__file__).resolve().parents[3]
NAME = "tech-priests-emergency-assembler"
ENGINE = Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe")
TICKS = 5500


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def between(text: str, start: str, end: str) -> str:
    first = text.index(start)
    return text[first:text.index(end, first)]


def selected_spec(text: str, list_name: str) -> str:
    """Take the exact selected top-level Lua spec, including nested ingredients."""
    first = text.index("local " + list_name + " = {")
    match = re.search(r'\{\s*name\s*=\s*"' + re.escape(NAME) + r'"', text[first:])
    if not match:
        raise ValueError("Missing actual production spec: " + list_name)
    begin = first + match.start()
    depth = 0
    quote = None
    escaped = False
    for index in range(begin, len(text)):
        char = text[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[begin:index + 1]
    raise ValueError("Unclosed production spec")


def stage(out: Path, graphical: bool) -> dict:
    source = ROOT / "tech-priests_src"
    generated = source / "prototypes/generated_graphics/emergency-assembler-v07.lua"
    if not generated.is_file():
        raise FileNotFoundError("V07 integration must exist before native testing: " + str(generated))
    if out.exists():
        raise FileExistsError("Preserve the previous native study; choose another --out: " + str(out))
    mod = out / "mods/tech-priests"
    (mod / "prototypes/compatibility").mkdir(parents=True)
    (mod / "prototypes/generated_graphics").mkdir()
    fixture = ROOT / "tests/scenarios/emergency-assembler-v07"
    entity = (source / "prototypes/entity.lua").read_text(encoding="utf-8-sig")
    item = (source / "prototypes/item.lua").read_text(encoding="utf-8-sig")
    recipe = (source / "prototypes/recipe.lua").read_text(encoding="utf-8-sig")
    blocks = [
        between(entity, "local MARTIAN_MICRO_ICON_SIZE", "local TIER_DEFS ="),
        between(entity, "local TECH_PRIESTS_PLANETSIDE_SURFACE_CONDITIONS =", "local function tech_priests_micro_fluid_boxes("),
        between(entity, "local function make_emergency_assembler()", "local function make_emergency_smelter()"),
        'data:extend({make_emergency_assembler()})\n',
        'data:extend({{type="item-subgroup",name="tech-priest-emergency-industry",group="production",order="z"}})\n',
        "local items = {}\nlocal emergency_industry_items = {" + selected_spec(item, "emergency_industry_items") + "}\n",
        between(item, "for _, item in pairs(emergency_industry_items) do", "data:extend(items)"),
        "data:extend(items)\nlocal recipes = {}\nlocal emergency_industry_recipes = {" + selected_spec(recipe, "emergency_industry_recipes") + "}\n",
        between(recipe, "for _, spec in pairs(emergency_industry_recipes) do", "\ntable.insert(recipes, {"),
        "data:extend(recipes)\n",
    ]
    (mod / "prototypes/assembler-source.lua").write_text(
        "-- Exact selected blocks from current production Lua; see source-manifest.json.\n" + "\n".join(blocks), encoding="utf-8")
    dependency = "prototypes/compatibility/native_crafting_categories_1275.lua"
    shutil.copy2(source / dependency, mod / dependency)
    schema = "prototypes/compatibility/native_recipe_schema_1274.lua"
    shutil.copy2(source / schema, mod / schema)
    shutil.copy2(generated, mod / generated.relative_to(source))
    for folder in ("graphics/entity/emergency-assembler-v07",):
        if not (source / folder).is_dir():
            raise FileNotFoundError("Expected installed V07 graphics: " + str(source / folder))
        shutil.copytree(source / folder, mod / folder)
    for relative in (
        "graphics/entity/martian-micro/tech-priests-emergency-assembler.png",
        "graphics/entity/martian-micro/tech-priests-emergency-assembler-shadow.png",
        "graphics/icons/martian-micro/tech-priests-emergency-assembler.png",
    ):
        target = mod / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / relative, target)
    shutil.copy2(fixture / "data.lua", mod / "data.lua")
    (mod / "control.lua").write_text("local GRAPHICAL = " + str(graphical).lower() + "\n" + (fixture / "control.lua").read_text(encoding="utf-8"), encoding="utf-8")
    (mod / "info.json").write_text(json.dumps({"name": "tech-priests", "version": "0.0.1", "title": "Emergency assembler V07 native acceptance", "author": "Tech Priests", "factorio_version": "2.1", "dependencies": ["base >= 2.1.0"]}), encoding="utf-8")
    (out / "mods/mod-list.json").write_text(json.dumps({"mods": [
        {"name": name, "enabled": name in {"base", "tech-priests"}}
        for name in ("base", "elevated-rails", "recycler", "quality", "space-age", "tech-priests")
    ]}), encoding="utf-8")
    manifest = {
        "scope": "Exact production builder, helpers, item and recipe spec/loops, plus unchanged installed V07 graphics module; full priest runtime is not staged.",
        "production_sources": {p: sha(source / p) for p in ("prototypes/entity.lua", "prototypes/item.lua", "prototypes/recipe.lua", dependency, schema, "prototypes/generated_graphics/emergency-assembler-v07.lua")},
        "extracted_lua_sha256": sha(mod / "prototypes/assembler-source.lua"),
        "fixture_sources": {p: sha(fixture / p) for p in ("data.lua", "control.lua")},
        "staged_graphics": {p.relative_to(mod).as_posix(): sha(p) for p in (mod / "graphics").rglob("*.png")},
    }
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def startup_info():
    if os.name != "nt":
        return None
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    return startup


def command(base: list[str], tail: list[str], out: Path, phase: str, timeout: int = 150):
    log = out / (phase + ".log")
    print("ASSEMBLER_NATIVE_START", phase, flush=True)
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(base + tail, cwd=out, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout, startupinfo=startup_info())
    if result.returncode:
        raise RuntimeError(phase + ": " + log.read_text(errors="replace")[-7000:])


def verify_dump(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    prototype = raw["assembling-machine"][NAME]
    graphics = prototype["graphics_set"]
    assert graphics["animation_progress"] == 1
    assert prototype["animation_random_start_frame"] is False
    assert prototype["perceived_performance"] == {"minimum": 1, "maximum": 1}
    frames = {}

    def leaves(node):
        if isinstance(node, dict):
            if "filename" in node:
                yield node
            for value in node.values():
                yield from leaves(value)
        elif isinstance(node, list):
            for value in node:
                yield from leaves(value)

    for direction in ("north", "east", "south", "west"):
        working = list(leaves(graphics["animation"][direction]))
        idle = list(leaves(graphics["idle_animation"][direction]))
        assert working and idle, direction
        for leaf in working:
            assert "/emergency-assembler-v07/" in leaf["filename"]
            assert leaf["frame_count"] == 144
            assert abs(leaf["animation_speed"] - .2) < 1e-8
        for leaf in idle:
            assert "/emergency-assembler-v07/" in leaf["filename"]
            assert leaf.get("frame_count", 1) == 1
            assert leaf.get("repeat_count", 1) == 144
        frames[direction] = {"working": working, "idle": idle}
    assert prototype["energy_source"]["type"] == "burner"
    assert abs(prototype["crafting_speed"] - .17) < 1e-8
    assert prototype["collision_box"] == [[-.35, -.36], [.35, .36]]
    assert prototype["selection_box"] == [[-.5, -.5], [.5, .5]]
    assert prototype["match_animation_speed_to_activity"] is False
    assert "crafting" in prototype["crafting_categories"]
    if "electronics" in raw["recipe-category"]:
        assert "electronics" in prototype["crafting_categories"]
    for kind in ("item", "recipe"):
        assert "/emergency-assembler-v07/" in raw[kind][NAME]["icon"]
    return {"native_data_stage": "PASS", "directions": frames, "crafting_speed": prototype["crafting_speed"], "energy_source": prototype["energy_source"], "collision_box": prototype["collision_box"], "selection_box": prototype["selection_box"], "animation_progress": graphics["animation_progress"], "animation_random_start_frame": prototype["animation_random_start_frame"], "perceived_performance": prototype["perceived_performance"], "rotation_scope": "Four directions before placement; native burner crafting machines cannot rotate after placement.", "cycle_seconds": 144 / .2 / 60}


def read_result(path: Path) -> dict:
    result = json.loads(path.read_text(encoding="utf-8"))
    assert result["status"] == "PASS" and result["production_source"] is True
    assert len(result["sites"]) == 4
    for site in result["sites"]:
        assert site["finished"] >= 10 and site["initial_starvation"] and site["natural_starvation"] and site["recovered"]
        assert site["input_remaining"] == 0 and site["exact_output_accounting"]
    return result


def verify_clock(shots: Path) -> dict:
    anchor = shots / "0352-cycle-anchor.png"
    repeat = shots / "1072-cycle-repeat.png"
    assert anchor.read_bytes() == repeat.read_bytes(), "Native animation did not repeat exactly after 720 ticks"
    return {"status": "PASS", "ticks": [352, 1072], "delta_ticks": 720,
            "simulation_seconds": 12, "comparison": "Exact full native PNG bytes",
            "anchor_sha256": sha(anchor), "repeat_sha256": sha(repeat),
            "continuous_crafting_at_both_anchors": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", type=Path, default=ENGINE)
    parser.add_argument("--out", type=Path, default=ROOT / "build/emergency-assembler-v07" / ("native-" + time.strftime("%Y%m%d-%H%M%S")))
    parser.add_argument("--graphics", action="store_true")
    parser.add_argument("--reload", action="store_true", help="Create a genuine server autosave at tick 520, then benchmark the saved state.")
    parser.add_argument("--resume-graphics", action="store_true", help="Repeat only an interrupted graphical phase from --out after verifying unchanged staged graphics and saved passing proofs.")
    args = parser.parse_args()
    exe, out = args.factorio.resolve(), args.out.resolve()
    assert exe.is_file(), exe
    # Benchmark and server phases always write result.json and do not request
    # images. Change this isolated test-only prefix before the graphical load.
    if args.resume_graphics:
        assert args.graphics, "--resume-graphics requires --graphics"
        manifest = json.loads((out / "source-manifest.json").read_text(encoding="utf-8"))
        for relative, digest in manifest["staged_graphics"].items():
            assert sha(out / "mods/tech-priests" / relative) == digest
            assert sha(ROOT / "tech-priests_src" / relative) == digest
        module = "prototypes/generated_graphics/emergency-assembler-v07.lua"
        assert sha(ROOT / "tech-priests_src" / module) == manifest["production_sources"][module]
    else:
        manifest = stage(out, False)
    user = out / "user-data"
    user.mkdir(exist_ok=args.resume_graphics)
    (out / "steam_appid.txt").write_text("427520", encoding="ascii")
    config = out / "config.ini"
    config.write_text("[path]\nread-data=" + str(exe.parents[2] / "data") + "\nwrite-data=" + str(user) + "\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n", encoding="utf-8")
    base = [str(exe), "--config", str(config), "--mod-directory", str(out / "mods"), "--disable-migration-window"]
    settings = out / "map-gen-settings.json"
    settings.write_text(json.dumps({"seed": 707, "peaceful_mode": True, "water": 0, "autoplace_controls": {"enemy-base": {"frequency": "none", "size": "none", "richness": "none"}}}), encoding="utf-8")
    save = out / "fresh.zip"
    if not args.resume_graphics:
        command(base, ["--create", str(save), "--map-gen-settings", str(settings)], out, "create")
        command(base, ["--dump-data"], out, "data-stage")
    data = verify_dump(user / "script-output/data-raw-dump.json")
    result_path = user / "script-output/emergency-assembler-v07/result.json"
    if args.resume_graphics:
        result = read_result(out / "production.json")
    else:
        command(base, ["--benchmark", str(save), "--benchmark-ticks", str(TICKS), "--benchmark-runs", "1"], out, "production")
        result = read_result(result_path)
        shutil.copy2(result_path, out / "production.json")
    resumed = read_result(out / "save-reload.json") if args.resume_graphics and (out / "save-reload.json").is_file() else None
    if args.reload and not args.resume_graphics:
        server_settings = out / "server-settings.json"
        server_settings.write_text(json.dumps({"name": "Private assembler save test", "description": "Local native acceptance", "visibility": {"public": False, "lan": False}, "auto_pause": False, "require_user_verification": False}), encoding="utf-8")
        checkpoint = user / "saves/_autosave-emergency-assembler-v07-mid-cycle.zip"
        log = out / "save-server.log"
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(base + ["--start-server", str(save), "--server-settings", str(server_settings), "--bind", "127.0.0.1", "--port", "34307"], cwd=out, stdout=stream, stderr=subprocess.STDOUT, startupinfo=startup_info())
            try:
                deadline = time.monotonic() + 45
                while process.poll() is None and time.monotonic() < deadline:
                    if checkpoint.is_file() and "Saving finished" in log.read_text(errors="replace"):
                        break
                    time.sleep(.2)
                assert checkpoint.is_file(), "Real native save missing; inspect save-server.log"
            finally:
                if process.poll() is None:
                    process.terminate()
                process.wait(timeout=10)
        result_path.unlink(missing_ok=True)
        command(base, ["--benchmark", str(checkpoint), "--benchmark-ticks", str(TICKS - 520), "--benchmark-runs", "1"], out, "reload")
        resumed = read_result(result_path)
        assert resumed["resume"]["tick"] == resumed["resume"]["saved_tick"] + 1
        assert resumed["resume"]["working"] == 4
        shutil.copy2(result_path, out / "save-reload.json")
    graphics = None
    if args.graphics:
        control = out / "mods/tech-priests/control.lua"
        fixture_control = ROOT / "tests/scenarios/emergency-assembler-v07/control.lua"
        control.write_text("local GRAPHICAL = true\n" + fixture_control.read_text(encoding="utf-8"), encoding="utf-8")
        manifest["graphical_fixture"] = {"source_sha256": sha(fixture_control), "staged_control_sha256": sha(control), "simulation_speed": 16, "speed_one_windows": [[342, 362], [1062, 1082]], "phase_anchor_ticks": [352, 1072], "stop_at_report_tick": 5400, "hard_timeout_seconds": 60, "until_tick_option": "Not used: Factorio 2.1 --until-tick disables graphical rendering."}
        (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        graphical_proof = user / "script-output/emergency-assembler-v07/graphical.json"
        graphical_proof.unlink(missing_ok=True)
        # --until-tick rewrites its input save on Factorio 2.1. Give each
        # graphical attempt its own new tick-zero save instead of reusing it.
        graphical_save = out / ("graphical-start-" + time.strftime("%Y%m%d-%H%M%S") + ".zip")
        command(base, ["--create", str(graphical_save), "--map-gen-settings", str(settings)], out, "graphics-create")
        log = out / "graphics.log"
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(base + ["--load-game", str(graphical_save), "--window-size", "1600x1000"], cwd=out, stdout=stream, stderr=subprocess.STDOUT, startupinfo=startup_info())
            try:
                deadline = time.monotonic() + 60
                while process.poll() is None and time.monotonic() < deadline and not graphical_proof.is_file():
                    time.sleep(.2)
                assert graphical_proof.is_file(), "Graphical proof missing: " + log.read_text(errors="replace")[-7000:]
                graphics_log = log.read_text(errors="replace")
                assert "Initialised Direct3D" in graphics_log and "Sprites loaded" in graphics_log
                assert "Running in headless mode" not in graphics_log
                graphics = read_result(graphical_proof)
                shots = user / "script-output/emergency-assembler-v07"
                expected = [shots / name for name in graphics["screenshots"]]
                assert len(expected) >= 6
                assert all(path.is_file() and path.stat().st_size > 1000 for path in expected), "Native screenshots missing"
                graphics["native_clock"] = verify_clock(shots)
            finally:
                if process.poll() is None:
                    process.terminate()
                process.wait(timeout=10)
    receipt = {"status": "PASS", "source_manifest_sha256": sha(out / "source-manifest.json"), "source": manifest, "native_data": data, "production": result, "save_reload": resumed, "graphical": graphics, "full_priest_runtime": "not_staged", "visual_acceptance": "Native screenshots require independent visual review; timing/data and gameplay assertions passed."}
    (out / "native-acceptance.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("EMERGENCY_ASSEMBLER_V07_NATIVE_PASS", out / "native-acceptance.json", flush=True)


if __name__ == "__main__":
    main()
