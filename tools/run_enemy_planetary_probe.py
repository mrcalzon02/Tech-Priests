"""Isolated colony placement, save/load, production and research checks.

Uses a disposable mod profile; never changes installed mods or gameplay saves.
Large asset directories use junctions; all executable test code is copied.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", type=Path, default=Path(
        r"C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe"))
    parser.add_argument("--output-dir",type=Path)
    parser.add_argument("--research-intercepts",action="store_true")
    parser.add_argument("--full-research",action="store_true")
    args = parser.parse_args()
    source = ROOT / "tech-priests_src"
    output = (args.output_dir or ROOT / "build/enemy-planets-probe").resolve()
    mod = output / "mods/tech-priests"
    mod.mkdir(parents=True, exist_ok=True)
    (output / "user-data").mkdir(exist_ok=True)
    for item in source.iterdir():
        if item.is_file():
            shutil.copy2(item, mod / item.name)
    for folder in ("scripts", "prototypes", "core", "locale"):
        shutil.copytree(source / folder, mod / folder, dirs_exist_ok=True)
    for folder in ("graphics", "sound"):
        target = mod / folder
        if not target.exists():
            quote = lambda p: "'" + str(p).replace("'", "''") + "'"
            subprocess.run(["powershell", "-NoProfile", "-Command",
                "New-Item -ItemType Junction -Path " + quote(target)
                + " -Target " + quote(source / folder)], check=True)
    fixture="enemy-research-full" if args.full_research else "enemy-research" if args.research_intercepts else "enemy-planets"
    shutil.copy2(ROOT / ("tests/scenarios/"+fixture+"/fixture.lua"), mod / "enemy_probe.lua")
    with (mod / "control.lua").open("a", encoding="utf-8") as stream:
        stream.write('\nrequire("enemy_probe")\n')
    config = output / "config.ini"
    config.write_text("[path]\nread-data=" + str(args.factorio.parents[2] / "data")
                      + "\nwrite-data=" + str(output / "user-data") + "\n")
    common = [str(args.factorio), "--config", str(config),
              "--mod-directory", str(output / "mods")]
    mapgen = output / "map-gen-settings.json"
    mapgen.write_text(json.dumps({"seed": 4242}))
    for label, names in (("space-age", ["base", "quality", "recycler", "elevated-rails",
                                        "space-age", "tech-priests"]),):
        (output / "mods/mod-list.json").write_text(json.dumps({"mods": [
            {"name": name, "enabled": name in names} for name in
            ("base", "quality", "recycler", "elevated-rails", "space-age", "tech-priests")]}))
        save = output / (label + ".zip")
        for phase, command in (
            ("create", ["--create", str(save), "--map-gen-settings", str(mapgen)]),
            ("reload", ["--test-save", str(save), "--test-ticks", "12001" if args.full_research else "601" if args.research_intercepts else "1201"])):
            result = subprocess.run(common + command, capture_output=True, text=True,
                                    timeout=900 if args.full_research else 180)
            text = result.stdout + result.stderr
            (output / (label + "-" + phase + ".log")).write_text(text)
            assert result.returncode == 0, text[-5000:]
            assert "isolated handler failure" not in text, text[-5000:]
            if args.full_research:
                marker=("PASS colony initialized research=automation progress=0" if phase=="create"
                        else "PASS from-zero research, actual construction and native intercept")
                assert marker in text,text[-5000:]
            elif args.research_intercepts:
                marker=("PASS settings, grants, milestone and recipient filters" if phase=="create"
                        else "PASS loaded native player session and exactly one completion")
                assert marker in text,text[-5000:]
            elif phase == "create":
                for planet in ("fulgora", "vulcanus", "nauvis", "gleba"):
                    assert "PASS bound cluster " + planet in text, text[-5000:]
            else:
                assert text.count("PASS native production research and original pairs ")==4, text[-5000:]
            print(label, phase, "PASS", flush=True)
            for line in text.splitlines():
                if "[TP-ENEMY-" in line:
                    print(line, flush=True)


if __name__ == "__main__":
    main()
