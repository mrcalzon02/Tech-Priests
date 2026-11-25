#!/usr/bin/env python3
"""Load the exact standard/HD ZIPs with an existing local Factorio installation.

Copies or hardlinks already acquired dependency mods into isolated per-profile
folders. Never modifies source ZIPs, strips dependencies, downloads the engine,
or touches the player's normal mods, settings, or saves.
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
import sys
import time
import zipfile


BUILTINS = {"base", "core", "quality", "space-age", "elevated-rails"}


def metadata(path: Path) -> dict:
    if path.is_dir():
        return json.loads((path / "info.json").read_text(encoding="utf-8"))
    with zipfile.ZipFile(path) as archive:
        members = [n for n in archive.namelist()
                   if n.endswith("/info.json") and n.count("/") == 1]
        if len(members) != 1:
            raise ValueError(f"Expected one top-level mod info.json: {path.name}")
        return json.loads(archive.read(members[0]))


def copy_local(source: Path, target: Path) -> None:
    if source.is_dir():
        shutil.copytree(source, target, copy_function=copy_local)
        return
    try:
        os.link(source, target)
    except OSError:
        shutil.copy2(source, target)


def version(value: str) -> tuple[int, ...]:
    return tuple(int(part) for part in value.split("."))


def dependency_names(info: dict) -> list[str]:
    names = []
    for value in info.get("dependencies", ["base"]):
        value = value.strip()
        if value.startswith(("?", "(?)", "!")):
            continue
        value = value.lstrip("~ ")
        name = re.split(r"\s*[<>=]", value, maxsplit=1)[0].strip()
        if name and name not in BUILTINS:
            names.append(name)
    return names


def cached_mods(root: Path) -> dict[str, tuple[Path, dict]]:
    found = {}
    for path in sorted(root.iterdir()):
        if not (path.is_dir() and (path / "info.json").is_file()
                or path.suffix.lower() == ".zip"):
            continue
        try:
            info = metadata(path)
        except (ValueError, KeyError, OSError, zipfile.BadZipFile):
            continue
        name = info["name"]
        if name == "tech-priests" or name.startswith("tech-priests-hd"):
            continue
        if name not in found or version(info["version"]) > version(found[name][1]["version"]):
            found[name] = (path, info)
    return found


def command(argv: list[str], logfile: Path, timeout: int) -> dict:
    started = time.monotonic()
    timed_out = False
    with logfile.open("w", encoding="utf-8") as stream:
        try:
            process = subprocess.run(argv, stdout=stream, stderr=subprocess.STDOUT,
                                     timeout=timeout, check=False)
            status = process.returncode
        except subprocess.TimeoutExpired:
            stream.write("\nTP_GRAPHICS_NATIVE_TIMEOUT\n")
            status = 124
            timed_out = True
    log = logfile.read_text(encoding="utf-8", errors="replace")
    print("\n".join(log.splitlines()[-24:]), flush=True)
    fatal = bool(re.search(r"Error while (?:loading|running)|stack traceback|Failed to load mods", log))
    return {"exit_code": status, "timeout": timed_out, "fatal_log": fatal,
            "seconds": round(time.monotonic() - started, 2),
            "passed": status == 0 and not fatal, "log": logfile.name}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", type=Path, required=True)
    parser.add_argument("--packages", type=Path, required=True)
    parser.add_argument("--dependency-mods", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    args.factorio = args.factorio.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "tech-priests.graphics-packages-native.v1",
              "source_commit": os.environ.get("GITHUB_SHA"),
              "graphical_atlas_verified": False, "passed": False,
              "profiles": {}, "packages": []}
    try:
        check = subprocess.run([str(args.factorio), "--version"], capture_output=True,
                               text=True, timeout=30, check=True)
        report["engine_version"] = (check.stdout + check.stderr).strip()
        if not re.search(r"\b2\.1\.\d+\b", report["engine_version"]):
            raise ValueError("Packaged mods require a local Factorio 2.1 executable")
        game_data = args.factorio.parents[2] / "data"
        if not (game_data / "base" / "info.json").is_file():
            raise ValueError("Factorio installation lacks its local data/base/info.json")
        available = cached_mods(args.dependency_mods)
        packages = {}
        for path in sorted(args.packages.glob("*.zip")):
            if not path.name.startswith("tech-priests"):
                continue
            info = metadata(path)
            if info["name"] != "tech-priests" and not info["name"].startswith("tech-priests-hd"):
                continue
            if info["name"] in packages:
                raise ValueError("Duplicate packaged mod " + info["name"])
            packages[info["name"]] = (path.resolve(), info)
            with path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            report["packages"].append({"name": path.name, "bytes": path.stat().st_size,
                                        "sha256": digest, "mod": info["name"]})
        if "tech-priests" not in packages:
            raise ValueError("No exact standard Tech-Priests ZIP found")
        hd_names = sorted(set(packages) - {"tech-priests"})
        if not hd_names:
            raise ValueError("No separate HD graphics ZIPs found")
        profiles = {"standard": ["tech-priests"],
                    "all-hd": ["tech-priests", *hd_names]}
        if len(hd_names) > 1:
            profiles["partial-hd"] = ["tech-priests", hd_names[0]]
        for profile, selected in profiles.items():
            root = args.output / profile
            mods = root / "mods"
            mods.mkdir(parents=True)
            user_data = root / "user-data"
            user_data.mkdir()
            installed = dict((name, packages[name]) for name in selected)
            pending = [name for _, info in installed.values() for name in dependency_names(info)]
            while pending:
                name = pending.pop(0)
                if name in installed:
                    continue
                if name not in available:
                    raise ValueError("Required dependency absent from existing cache: " + name)
                installed[name] = available[name]
                pending.extend(dependency_names(available[name][1]))
            for path, _ in installed.values():
                copy_local(path, mods / path.name)
            enabled = sorted(set(installed) | {name for name in BUILTINS
                             if name != "core" and (game_data / name / "info.json").is_file()})
            (mods / "mod-list.json").write_text(json.dumps({"mods": [
                {"name": name, "enabled": True} for name in enabled]}, indent=2) + "\n")
            config = root / "config.ini"
            config.write_text("[path]\nread-data=" + game_data.as_posix()
                              + "\nwrite-data=" + user_data.as_posix()
                              + "\n[other]\ncheck-updates=false\n", encoding="utf-8")
            common = [str(args.factorio), "--config", str(config), "--mod-directory", str(mods)]
            save = root / "graphics-native.zip"
            print("TP_GRAPHICS_NATIVE_BEGIN " + profile, flush=True)
            entry = {"mods": enabled, "create": command(common + ["--create", str(save),
                     "--map-gen-seed", "20261125"], root / "create.log", args.timeout)}
            report["profiles"][profile] = entry
            entry["save_created"] = save.is_file() and save.stat().st_size > 0
            if entry["create"]["passed"] and entry["save_created"]:
                entry["reload"] = command(common + ["--benchmark", str(save),
                    "--benchmark-ticks", "60", "--benchmark-runs", "1"],
                    root / "reload.log", args.timeout)
            entry["passed"] = bool(entry["create"]["passed"] and entry["save_created"]
                                    and entry.get("reload", {}).get("passed"))
            print("TP_GRAPHICS_NATIVE_RESULT " + json.dumps({"profile": profile, **entry}), flush=True)
        report["passed"] = all(x["passed"] for x in report["profiles"].values())
    except Exception as exc:
        report["error"] = str(exc)
        print("TP_GRAPHICS_NATIVE_ERROR " + str(exc), flush=True)
    finally:
        (args.output / "native-graphics-receipt.json").write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
