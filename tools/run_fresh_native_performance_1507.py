#!/usr/bin/env python3
"""Cache-only, native4-first orchestration around the unchanged Windows launcher.

This file does not publish, fetch packages, discover saves, or install a worker.
The request is a local JSON file. All paths are explicit. The only game input is
a save created by this invocation under its exclusive output directory.

Usage: python run_fresh_native_performance_1507.py --request REQUEST.json

Request schema (all paths absolute on the signed-in Windows worker):
  schema: "tech-priests.fresh-native-request.1507"
  phase: "native4" or "matched100"
  helpers: directory containing the three pinned, unchanged existing helpers
  engine: graphical Factorio 2.1.25 executable
  output: new, invocation-owned directory
  exclusive_lock: shared native-desktop lock used by the worker's serial router
  candidate: {path: mod ZIP, sha256: exact hash, revision: full source commit}
  baseline: same object; required only for matched100, pinned to reviewed main
  dependencies: {"aai-programmable-vehicles": ZIP, "aai-signals": ZIP,
                 "informatron": ZIP}
  four_receipt: native4 receipt path, required only for matched100

native4 is 600 warmup + 1200 measured ticks. matched100 is 600 warmup +
9600 measured ticks per revision, run serially from an identical fresh save.
Every complete 600-tick window must contain real repairs by every original
priest, movement, native production, and powered machines. The workload uses
native damage and canonical repair requests; it never moves workers or calls a
repair executor. This is a maintenance-factory workload, not proof of every
construction, defense, crafting, and sanctification branch.

The existing launcher is called in-process without changing its source. Its
test-only OBSERVER value is supplied by this wrapper. A scoped subprocess proxy
accepts only its exact --load-game command, appends --output-perf-stats to a new
result path, and enables show-fps=always in its new disposable config. Every
other argument and subprocess option is forwarded unchanged. Native CSV units
and phase boundaries must be calibrated against full visible client/HUD video;
the CSV alone is never labeled displayed FPS. A separately routed, already
installed recorder is required. No recorder is installed or started here.

Official references reviewed for the measurement extension:
  https://wiki.factorio.com/Command_line_parameters
  https://wiki.factorio.com/Debug_mode
The installed version's actual HUD remains the test of the debug INI setting.
A successful matched100 activity run remains unaccepted for performance until
external full-window video and calibrated timing evidence are assessed.
"""
from __future__ import annotations

import argparse
import contextlib
import csv
import hashlib
import importlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import time
import zipfile


SCHEMA = "tech-priests.fresh-native-request.1507"
RECEIPT_SCHEMA = "tech-priests.fresh-native-proof.1507"
REVIEWED_MAIN = "025a7a5d613f1df6e3b131aad0b1cc5006760160"
HELPER_SHA256 = {
    "stage_owner_save.py": "b05c208baeb7d221abea04754bcc00b90cfc2898f50ddbd4c84af79fcfc8f823",
    "profile_owner_save.py": "f796a52421ae81ab01658c718718ba5212c902c3de7b89edfc442e6e3ae886d9",
    "open_desktop.py": "ac48e7f612f55f3d8061402c62e14824ab0d6a7d7ffd68438274b84c01c197e7",
}
DEPENDENCIES = {
    "aai-programmable-vehicles": ("0.9.2", "7544a2f26603dfef4f2f3b7f920554ce84bfc568"),
    "aai-signals": ("0.8.0", "6bca17a100a604393b2e93205d5dd851594f57c1"),
    "informatron": ("0.5.0", "70f8f81ae83f2360626d94e03db4b13db6d93b23"),
}
COMPETING_PROCESSES = {
    "factorio.exe", "quasimorph.exe", "blender.exe", "unrealeditor.exe",
    "unity.exe", "3dmark.exe", "furmark.exe",
}
WARMUP = 600
FOUR_TICKS = 1800
HUNDRED_TICKS = 10200


# Disposable scenario code only. The normal mod and the existing launchers are
# unchanged. Elapsed profilers are emitted as evidence, never read for decisions.
FRESH_OBSERVER = r'''
-- Native maintenance-factory fixture 1507; never distributed in the mod.
do
  local registry=require("scripts.core.runtime_event_registry")
  local repair=require("scripts.core.repair_executor_0516")
  local COUNT,TICKS,WARMUP=__COUNT__,__TICKS__,600
  local cells,start_tick,last_tick,wall,total_wall,wall_start,finished
  local markers={}
  local sequence_ok=true
  local function emit(value)
    log("[TP-FRESH-NATIVE-1507] "..helpers.table_to_json(value))
  end
  local function make(surface,name,x,y,force,raised)
    local entity=surface.create_entity{name=name,position={x=x,y=y},force=force,
      raise_built=raised==true}
    assert(entity and entity.valid,"fresh fixture cannot create "..name)
    return entity
  end
  local function insert(entity,inventory,name,count)
    local inv=entity.get_inventory(inventory)
    assert(inv and inv.valid,"fresh fixture inventory missing: "..entity.name)
    assert(inv.insert{name=name,count=count}==count,"fresh fixture stock refused: "..name)
  end
  local function south_inserter(surface,x,y,force)
    local entity=make(surface,"fast-inserter",x,y,force,true)
    local native_y=entity.position.y
    if entity.pickup_position.y>native_y then entity.direction=defines.direction.south end
    if entity.pickup_position.y>native_y then entity.direction=defines.direction.north end
    assert(math.abs(entity.pickup_position.y-(native_y-1))<0.1
      and math.abs(entity.drop_position.y-(native_y+1))<0.1,"native inserter orientation mismatch")
    return entity
  end
  local function setup()
    assert(game.speed==1,"fresh fixture requires normal game speed")
    assert(next(storage.tech_priests.pairs_by_station or {})==nil,
      "fresh fixture refuses a save with existing priests")
    assert(not game.surfaces["tp-fresh-performance-1507"],"fresh fixture already exists")
    local side=math.ceil(math.sqrt(COUNT)); local span=side*32+64
    local surface=game.create_surface("tp-fresh-performance-1507",{
      width=span,height=span,water=0,default_enable_all_autoplace_controls=false,
      autoplace_settings={entity={treat_missing_as_default=false},
        decorative={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},math.ceil(span/64)+1)
    surface.force_generate_chunk_requests(); surface.always_day=true
    local force=game.forces.player
    local ranks={"junior-cogitator-station","intermediate-cogitator-station",
      "senior-cogitator-station","planetary-magos-cogitator-station"}
    cells={}
    for index=1,COUNT do
      local x=((index-1)%side-(side-1)/2)*32
      local y=(math.floor((index-1)/side)-(side-1)/2)*32
      local tiles={}
      for tx=-15,15 do for ty=-14,18 do
        tiles[#tiles+1]={name="grass-1",position={x+tx,y+ty}}
      end end
      surface.set_tiles(tiles,true)
      local station=make(surface,ranks[(index-1)%4+1],x,y,force,true)
      insert(station,defines.inventory.chest,"repair-pack",300)
      insert(station,defines.inventory.chest,"sacred-machine-oil",50)
      local generator=make(surface,"electric-energy-interface",x,y+16,force,false)
      generator.power_production=10000000/60; generator.energy=10000000
      make(surface,"substation",x,y+8,force,true)
      make(surface,"substation",x,y-8,force,true)
      local cell={station=station,machines={},movement_samples=0,target_index=1,target_was_damaged=false}
      for _,offset in ipairs({-6,6}) do
        local machine=make(surface,"assembling-machine-1",x+offset,y+8,force,true)
        machine.set_recipe("iron-gear-wheel")
        local recipe=machine.get_recipe()
        assert(recipe and recipe.name=="iron-gear-wheel","fresh fixture recipe readback failed")
        insert(machine,defines.inventory.crafter_input,"iron-plate",100)
        local input=make(surface,"steel-chest",x+offset,y+5,force,true)
        insert(input,defines.inventory.chest,"iron-plate",4000)
        south_inserter(surface,x+offset,y+6,force)
        south_inserter(surface,x+offset,y+10,force)
        make(surface,"steel-chest",x+offset,y+11,force,true)
        cell.machines[#cell.machines+1]=machine
      end
      local source=make(surface,"steel-chest",x-8,y-8,force,true)
      for _,supply in ipairs({{"iron-plate",400},{"copper-plate",200},{"stone",100},
          {"coal",100},{"wood",100},{"small-electric-pole",20},{"transport-belt",20},
          {"machine-maintenance-litany",20}}) do
        insert(source,defines.inventory.chest,supply[1],supply[2])
      end
      for ox=-1,1 do for oy=-1,1 do
        local ore=surface.create_entity{name="iron-ore",position={x=x+8+ox,y=y-8+oy},amount=10000}
        assert(ore and ore.valid,"fresh fixture ore creation failed")
      end end
      make(surface,"electric-mining-drill",x+8,y-8,force,true)
      make(surface,"steel-chest",x+8,y-10,force,true)
      local pair=storage.tech_priests.pairs_by_station[station.unit_number]
      assert(pair and pair.priest and pair.priest.valid,"canonical original priest missing")
      cell.priest=pair.priest; cell.original_priest=pair.priest.unit_number
      cell.last_position={x=pair.priest.position.x,y=pair.priest.position.y}
      cells[index]=cell
    end
    assert(#game.connected_players>0,"fresh fixture requires a native connected player")
    for _,player in pairs(game.players) do
      assert(player.teleport({0,0},surface),"fresh fixture camera relocation failed")
      player.zoom=COUNT==4 and 0.45 or 0.085
      local frame=player.gui.screen.add{type="frame",name="tp_native_phase_1507",direction="vertical"}
      frame.location={x=16,y=72}
      frame.add{type="label",caption="Tech-Priests native "..COUNT.." / original workers",name="title"}
      local label=frame.add{type="label",caption="WARMUP / elapsed 0 / game tick "..game.tick,name="phase"}
      label.style.font="default-bold"; markers[#markers+1]=label
    end
    emit{phase="fixture",count=COUNT,assemblers=COUNT*2,mining_drills=COUNT,
      generator="native electric-energy-interface, 10MW per cell",surface=surface.name,
      original_priests=true,game_speed=game.speed,direct_executor_calls=false,
      production_timer_changes=false,worker_teleports=false,
      work_source="native damage events and canonical repair requests"}
  end
  local function update_marker(elapsed)
    local phase=elapsed<WARMUP and "WARMUP" or (elapsed<TICKS and "MEASURE" or "COMPLETE")
    for _,label in ipairs(markers) do
      if label.valid then label.caption=phase.." / elapsed "..elapsed.." of "..TICKS.." / game tick "..game.tick end
    end
    if elapsed==WARMUP or elapsed==TICKS then
      emit{phase="visible-boundary",boundary=phase,elapsed_ticks=elapsed,tick=game.tick}
    end
  end
  local function snapshot(elapsed,phase)
    local rows={}; local stable=true; local live=0
    for _,pair in pairs(storage.tech_priests.pairs_by_station or {}) do
      if pair.station and pair.station.valid and pair.priest and pair.priest.valid then live=live+1 end
    end
    for _,cell in ipairs(cells) do
      local station,priest=cell.station,cell.priest
      assert(station.valid and priest.valid,"fixture lost an original entity")
      local pair=storage.tech_priests.pairs_by_station[station.unit_number]
      stable=stable and pair and pair.priest==priest and priest.unit_number==cell.original_priest
      local machines={}
      for _,machine in ipairs(cell.machines) do
        assert(machine.valid,"fixture lost an original machine")
        machines[#machines+1]={unit=machine.unit_number,products=machine.products_finished,
          energy=machine.energy,health=machine.health}
      end
      rows[#rows+1]={station=station.unit_number,station_name=station.name,
        priest=priest.unit_number,position={x=priest.position.x,y=priest.position.y},
        repair_packs_used=pair.repair_0516 and pair.repair_0516.packs_used or 0,
        repair_phase=pair.repair_0516 and pair.repair_0516.phase,
        movement_samples=cell.movement_samples,machines=machines}
    end
    emit{phase=phase,elapsed_ticks=elapsed,tick=game.tick,pairs=rows,live_pairs=live,
      identities_stable=stable and live==COUNT,sequence_valid=sequence_ok,game_speed=game.speed}
  end
  registry.on_event(defines.events.on_tick,function(event)
    if finished then return end
    if last_tick and event.tick~=last_tick+1 then sequence_ok=false end
    last_tick=event.tick
    if not start_tick then
      start_tick=event.tick; total_wall=helpers.create_profiler(false)
      setup(); snapshot(0,"start")
    end
    local elapsed=event.tick-start_tick
    local cell=cells[elapsed%COUNT+1]
    assert(cell.station.valid and cell.priest.valid,"fixture original entity invalid")
    local pair=storage.tech_priests.pairs_by_station[cell.station.unit_number]
    assert(pair and pair.priest==cell.priest,"fixture original priest replaced")
    local pos=cell.priest.position
    if pos.x~=cell.last_position.x or pos.y~=cell.last_position.y then
      cell.movement_samples=cell.movement_samples+1
      cell.last_position={x=pos.x,y=pos.y}
    end
    local target=cell.machines[cell.target_index]
    if cell.target_was_damaged and target.health>=target.max_health-1 then
      cell.target_index=3-cell.target_index;cell.target_was_damaged=false
      target=cell.machines[cell.target_index]
    end
    -- Only damage a fully repaired machine, and alternate after completion.
    -- Re-damaging partially repaired targets would trap workers at one machine.
    if not cell.target_was_damaged and target.health>=target.max_health-1 then
      local before=target.health; target.damage(90,game.forces.neutral,"physical")
      assert(target.health<before,"native damage did not apply")
      cell.target_was_damaged=true
    end
    if target.health<target.max_health-1 then
      repair.submit_or_assign_repair_task(pair,target,"fresh-native-maintenance-1507")
    end
    if elapsed%60==0 then update_marker(elapsed) end
    if elapsed==WARMUP then wall=helpers.create_profiler(false);wall_start=elapsed end
    if elapsed>0 and elapsed%600==0 then
      snapshot(elapsed,elapsed==TICKS and "end" or "sample")
      if wall and elapsed>wall_start then
        wall.stop()
        log{"","[TP-OWNER-WALL] start=",wall_start," finish=",elapsed,
          " ticks=",elapsed-wall_start," duration=",wall}
        wall=helpers.create_profiler(false);wall_start=elapsed
      end
    end
    if elapsed==TICKS then
      total_wall.stop();log{"","[TP-OWNER-TOTAL] ticks=",elapsed," duration=",total_wall}
      game.take_screenshot{surface=cell.station.surface,position={x=0,y=0},
        resolution={1600,1000},zoom=COUNT==4 and 0.45 or 0.085,
        path="owner-profile/four-priests.png",show_entity_info=true,show_gui=true}
      emit{phase="native-screenshot-requested",elapsed_ticks=elapsed,tick=game.tick}
      finished=true
    end
  end,nil,{owner="fresh-native-performance-1507",route="fixture-and-passive-receipts",priority=1000001})
end
'''


def sha(path: Path, algorithm: str = "sha256") -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("Expected a JSON object: " + str(path))
    return value


def inspect_mod(path: Path, expected_name: str, expected_hash: str, algorithm: str = "sha256") -> dict:
    if path.suffix.lower() != ".zip" or not path.is_file() or sha(path, algorithm) != expected_hash:
        raise ValueError("Verified cached mod ZIP required: " + expected_name)
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if not names or len(names) != len(set(names)):
            raise ValueError("Empty archive or duplicate archive members")
        roots = {name.split("/", 1)[0] for name in names}
        if len(roots) != 1 or any("\\" in name or PurePosixPath(name).is_absolute()
                or ".." in PurePosixPath(name).parts for name in names):
            raise ValueError("Invalid mod archive paths")
        if any((entry.external_attr >> 16) & 0o170000 == 0o120000 for entry in archive.infolist()):
            raise ValueError("Mod archives must not contain links")
        if archive.testzip() is not None:
            raise ValueError("Corrupt mod archive")
        root = next(iter(roots))
        info = json.loads(archive.read(root + "/info.json"))
        if info.get("name") != expected_name:
            raise ValueError("Package is not the requested mod: " + expected_name)
        if expected_name == "tech-priests" and root + "/control.lua" not in names:
            raise ValueError("Tech-Priests archive lacks control.lua")
        return {"path": str(path), "name": expected_name, "version": info["version"],
                "sha256": sha(path), "dependencies": info.get("dependencies", ["base"])}


def verify_inputs(request: dict, official: tuple[str, ...]) -> dict:
    if request.get("schema") != SCHEMA or request.get("phase") not in ("native4", "matched100"):
        raise ValueError("Unknown fresh-native request schema or phase")
    allowed = {"schema", "phase", "helpers", "engine", "output", "exclusive_lock", "candidate",
               "baseline", "dependencies", "four_receipt"}
    if set(request) - allowed:
        raise ValueError("Unexpected request fields (save input and download URLs are not accepted)")
    if set(request.get("dependencies", {})) != set(DEPENDENCIES):
        raise ValueError("Exactly the three verified required dependency ZIPs are accepted")
    packages = {}
    for label in ("candidate", "baseline") if request["phase"] == "matched100" else ("candidate",):
        spec = request[label]
        if set(spec) != {"path", "sha256", "revision"} or not re.fullmatch(r"[0-9a-f]{40}", spec["revision"]):
            raise ValueError("Exact package path, hash and full source revision required")
        packages[label] = inspect_mod(Path(spec["path"]).resolve(), "tech-priests", spec["sha256"])
        packages[label]["revision"] = spec["revision"]
    if "baseline" in packages and packages["baseline"]["revision"] != REVIEWED_MAIN:
        raise ValueError("Matched baseline must be reviewed current main " + REVIEWED_MAIN)
    dependencies = {}
    for name, (version, checksum) in DEPENDENCIES.items():
        record = inspect_mod(Path(request["dependencies"][name]).resolve(), name, checksum, "sha1")
        if record["version"] != version:
            raise ValueError("Cached dependency version differs from reviewed hash pin")
        dependencies[name] = record
    versions = {name: "2.1.25" for name in official}
    versions.update({name: value["version"] for name, value in dependencies.items()})
    for package in [*packages.values(), *dependencies.values()]:
        for raw in package["dependencies"]:
            raw = raw.strip()
            if raw.startswith(("?", "(", "!")):
                continue
            match = re.fullmatch(r"~?\s*([A-Za-z0-9_.-]+)(?:\s*(>=|=)\s*(\d+\.\d+\.\d+))?", raw)
            if not match or match[1] not in versions:
                raise ValueError("Unreviewed mandatory dependency: " + raw)
            if match[2]:
                actual = tuple(map(int, versions[match[1]].split(".")))
                wanted = tuple(map(int, match[3].split(".")))
                if actual < wanted or (match[2] == "=" and actual != wanted):
                    raise ValueError("Unsatisfied cached dependency: " + raw)
    return {"packages": packages, "dependencies": dependencies}


def load_helpers(directory: Path):
    for name, expected in HELPER_SHA256.items():
        if sha(directory / name) != expected:
            raise ValueError("Existing helper drift requires source review: " + name)
        old = sys.modules.get(name[:-3])
        if old and Path(old.__file__).resolve() != (directory / name).resolve():
            raise ValueError("A different launcher helper is already imported")
    sys.path.insert(0, str(directory))
    try:
        profile = importlib.import_module("profile_owner_save")
        stage = importlib.import_module("stage_owner_save")
        desktop = importlib.import_module("open_desktop")
        return stage, profile, desktop
    finally:
        sys.path.pop(0)


class NativeLaunchObservation:
    """Forwarding proxy scoped to open_desktop's one exact native invocation.

    Do not replace subprocess.Popen globally: profile.run and a separately
    routed recorder must keep their ordinary subprocess behavior. This object
    replaces only the imported launcher's `subprocess` variable temporarily.
    """
    def __init__(self, real, root: Path, engine: Path):
        self.real, self.root, self.engine = real, root.resolve(), engine.resolve()
        self.records = []
        self.frame_csv = self.root / "native-rendering-frame-stats.csv"

    def __getattr__(self, name):
        return getattr(self.real, name)

    def Popen(self, command, *positional, **options):
        root, engine = self.root, self.engine
        expected = [str(engine), "--config", str(root / "config.ini"),
                    "--mod-directory", str(root / "mods"), "--load-game",
                    str(root / "fresh-nauvis.zip"), "--window-size", "1600x1000"]
        if command != expected or self.records or positional:
            raise RuntimeError("Native launcher invocation drift; measurement hook refused")
        if set(options) != {"cwd", "env", "stdout", "stderr"} or Path(options["cwd"]).resolve() != root:
            raise RuntimeError("Native launcher options/cwd drift; measurement hook refused")
        if not isinstance(options["env"], dict) or options["stderr"] != self.real.STDOUT or Path(
                getattr(options["stdout"], "name", "")).resolve() != root / "native-launch.log":
            raise RuntimeError("Native launcher environment/log route drift; measurement hook refused")
        config = root / "config.ini"
        expected_config = "[path]\nread-data=" + (engine.parents[2] / "data").as_posix() + \
            "\nwrite-data=" + (root / "userdata").as_posix() + "\n[other]\ncheck-updates=false\n"
        if config.is_symlink() or config.read_text(encoding="utf-8") != expected_config:
            raise RuntimeError("Only the exact newly generated launcher config may be instrumented")
        if self.frame_csv.exists():
            raise RuntimeError("Native frame evidence path already exists")
        before_hash = sha(config)
        config.write_text(expected_config + "\n[debug]\nshow-fps=always\n", encoding="utf-8")
        effective = [*command, "--output-perf-stats", str(self.frame_csv)]
        record = {"original_command": command.copy(), "effective_command": effective.copy(),
                  "original_prefix_preserved": effective[:-2] == command,
                  "environment_and_stdio_forwarded_unchanged": True,
                  "config": str(config), "config_before_sha256": before_hash,
                  "config_observed_sha256": sha(config), "native_csv": str(self.frame_csv),
                  "hud_setting_requested": "[debug] show-fps=always",
                  "hud_visibility_verified": False, "displayed_fps_verified": False,
                  "before_popen_perf_counter_ns": time.perf_counter_ns(),
                  "before_popen_utc_ns": time.time_ns()}
        self.records.append(record)
        process = self.real.Popen(effective, **options)
        record.update(game_pid=process.pid, after_popen_perf_counter_ns=time.perf_counter_ns(),
                      after_popen_utc_ns=time.time_ns())
        print("TP_FRESH_NATIVE_PROCESS " + json.dumps(record), flush=True)
        return process


@contextlib.contextmanager
def observe_native_launch(desktop, root: Path, engine: Path):
    original = desktop.subprocess
    observation = NativeLaunchObservation(original, root, engine)
    desktop.subprocess = observation
    try:
        yield observation
    finally:
        desktop.subprocess = original


def assert_no_competing_processes() -> None:
    result = subprocess.run(["tasklist.exe", "/fo", "csv", "/nh"], capture_output=True,
                            text=True, errors="replace", check=True, timeout=15)
    rows = list(csv.reader(result.stdout.splitlines()))
    if not rows or not any(len(row) >= 2 and row[1].isdigit() for row in rows):
        raise RuntimeError("Native process inventory unavailable; no game launched")
    busy = sorted({row[0] for row in rows if row and row[0].lower() in COMPETING_PROCESSES})
    if busy:
        raise RuntimeError("Competing native game/render process present: " + ", ".join(busy))


@contextlib.contextmanager
def desktop_lock(path: Path):
    # Never steal an existing lock or terminate its owner. The worker router must
    # honor this same lock for unrelated native GUI jobs.
    with path.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps({"pid": os.getpid(), "purpose": "fresh-native-performance-1507"}))
    try:
        yield
    finally:
        path.unlink()


def observer(count: int, ticks: int) -> str:
    if count not in (4, 100) or ticks < WARMUP + 1200 or ticks % 600:
        raise ValueError("Fixture requires 4/100 priests and complete measured 600-tick windows")
    return FRESH_OBSERVER.replace("__COUNT__", str(count)).replace("__TICKS__", str(ticks))


def validate_native(log: str, desktop: dict, count: int, ticks: int, wall: dict) -> dict:
    records = [json.loads(line.split("[TP-FRESH-NATIVE-1507] ", 1)[1])
               for line in log.splitlines() if "[TP-FRESH-NATIVE-1507] " in line]
    samples = [item for item in records if item.get("phase") in ("start", "sample", "end")]
    failures = []
    expected = list(range(0, ticks + 1, 600))
    if [item.get("elapsed_ticks") for item in samples] != expected:
        failures.append("incomplete or duplicate native observation window")
    fixtures = [item for item in records if item.get("phase") == "fixture"]
    if len(fixtures) != 1 or fixtures[0].get("count") != count or fixtures[0].get("original_priests") is not True:
        failures.append("fresh original-priest fixture declaration missing")
    if samples and (samples[0].get("phase") != "start" or samples[-1].get("phase") != "end"):
        failures.append("native beginning/end markers missing")
    if not desktop.get("passed") or desktop.get("engine_session") != desktop.get("session_id") or not desktop.get("session_id"):
        failures.append("visible interactive native launch not verified")
    if not desktop.get("engine_image") or min(desktop.get("foreground_client_size", [0, 0])) < 480:
        failures.append("visible native rendered witness missing")
    initial = {row["station"]: row["priest"] for row in samples[0].get("pairs", [])} if samples else {}
    if len(initial) != count or len(set(initial.values())) != count:
        failures.append("original priest count/identity mismatch")
    for item in samples:
        ids = {row["station"]: row["priest"] for row in item.get("pairs", [])}
        if ids != initial or len(item.get("pairs", [])) != count or item.get("live_pairs") != count or item.get("identities_stable") is not True:
            failures.append("an original priest disappeared or was replaced")
        if item.get("sequence_valid") is not True or item.get("game_speed") != 1:
            failures.append("native ticks skipped or game speed changed")
        if samples and item.get("tick") != samples[0].get("tick", 0) + item.get("elapsed_ticks", 0):
            failures.append("native tick/elapsed correlation invalid")
    windows = []
    measured = [sample for sample in samples if sample.get("elapsed_ticks", -1) >= WARMUP]
    for before, after in zip(measured, measured[1:]):
        old = {row["station"]: row for row in before["pairs"]}
        active = moving = producing = powered = 0
        for row in after["pairs"]:
            prior = old.get(row["station"], {})
            active += row.get("repair_packs_used", 0) > prior.get("repair_packs_used", 0)
            moving += row.get("movement_samples", 0) > prior.get("movement_samples", 0)
            machines = {machine["unit"]: machine for machine in prior.get("machines", [])}
            current = row.get("machines", [])
            producing += len(current) == 2 and all(machine["unit"] in machines and
                machine.get("products", 0) > machines[machine["unit"]].get("products", 0) for machine in current)
            powered += len(current) == 2 and all(machine.get("energy", 0) > 0 for machine in current)
        window = {"start_tick": before["elapsed_ticks"], "end_tick": after["elapsed_ticks"],
                  "active_priests": active, "moving_priests": moving,
                  "producing_cells": producing, "powered_cells": powered}
        windows.append(window)
        if any(value != count for value in (active, moving, producing, powered)):
            failures.append("one or more original priests/machines lack real work in a complete window")
    expected_wall = [(start, start + 600) for start in range(WARMUP, ticks, 600)]
    observed_wall = [(window.get("start_tick"), window.get("end_tick")) for window in wall.get("windows", [])]
    if observed_wall != expected_wall or any(window.get("ticks") != 600 or
            not math.isfinite(window.get("elapsed_ms", 0)) or window.get("elapsed_ms", 0) <= 0
            for window in wall.get("windows", [])):
        failures.append("full native elapsed wall windows missing or invalid")
    if len(windows) != len(expected_wall):
        failures.append("measured activity windows incomplete")
    return {"passed": not failures, "failures": sorted(set(failures)), "expected_priests": count,
            "warmup_ticks": WARMUP, "end_tick": ticks, "full_windows": windows,
            "original_identities": initial, "native_wall": wall,
            "displayed_fps_verified": False, "performance_accepted": False,
            "visibility_scope": "unchanged launcher verifies foreground after the final native witness; continuous measured-window presentation needs external capture",
            "frame_evidence_blocker": "native rendering CSV and requested HUD still require full visible video and calibrated phase boundaries",
            "workload": "native damage, canonical repair requests, powered producing maintenance factory"}


def require_four(receipt: dict, candidate: dict, engine_hash: str, dependencies: dict) -> None:
    if receipt.get("schema") != RECEIPT_SCHEMA or receipt.get("phase") != "native4" or receipt.get("passed") is not True:
        raise ValueError("A successful native4 receipt is required before matched100")
    if receipt.get("candidate") != {key: candidate[key] for key in ("revision", "sha256")}:
        raise ValueError("native4 candidate source/package differs from matched100")
    hashes = {name: record["sha256"] for name, record in dependencies.items()}
    if receipt.get("engine_sha256") != engine_hash or receipt.get("dependency_sha256") != hashes:
        raise ValueError("native4 engine/dependency provenance differs from matched100")
    if receipt.get("fixture_sha256") != hashlib.sha256(FRESH_OBSERVER.encode()).hexdigest():
        raise ValueError("native4 fixture differs from matched100")
    if receipt.get("helper_sha256") != HELPER_SHA256:
        raise ValueError("native4 helper provenance differs from matched100")
    runs = receipt.get("runs", [])
    if not isinstance(runs, list) or len(runs) != 1 or runs[0].get("validation", {}).get("passed") is not True or runs[0]["validation"].get("expected_priests") != 4:
        raise ValueError("native4 real-work proof is missing")
    validation = runs[0]["validation"]
    windows = validation.get("full_windows", [])
    if validation.get("warmup_ticks") != WARMUP or validation.get("end_tick") != FOUR_TICKS or len(windows) != 2:
        raise ValueError("native4 complete measured windows are missing")
    for index, window in enumerate(windows):
        if (window.get("start_tick"), window.get("end_tick")) != (600 + index * 600, 1200 + index * 600) or any(
                window.get(field) != 4 for field in ("active_priests", "moving_priests", "producing_cells", "powered_cells")):
            raise ValueError("native4 complete physical activity/power/production proof is missing")


def stage_mods(root: Path, package: dict, dependencies: dict, official: tuple[str, ...]) -> Path:
    mods = root / "baseline-mods"
    mods.mkdir(parents=True, exist_ok=False)
    for record in [package, *dependencies.values()]:
        shutil.copy2(record["path"], mods / (record["name"] + "_" + record["version"] + ".zip"))
    names = [*official, *dependencies, "tech-priests"]
    (mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": name, "enabled": True} for name in names]}), encoding="utf-8")
    return mods


def create_fresh(root: Path, engine: Path, mods: Path, profile) -> Path:
    user = root / "generated-user-data"
    user.mkdir()
    config = root / "fresh-config.ini"
    config.write_text("[path]\nread-data=" + (engine.parents[2] / "data").as_posix() +
                      "\nwrite-data=" + user.as_posix() + "\n[other]\ncheck-updates=false\n", encoding="utf-8")
    (root / "steam_appid.txt").write_text("427520", encoding="ascii")
    save = root / "fresh-nauvis.zip"
    command = [str(engine), "--config", str(config), "--mod-directory", str(mods),
               "--create", str(save), "--map-gen-seed", "907260"]
    result = profile.run(command, root / "fresh-create.log", 180, cwd=root,
                         env={**os.environ, "SteamAppId": "427520", "SteamGameId": "427520"})
    if result["exit_code"] != 0 or not save.is_file():
        raise RuntimeError("Fresh isolated save creation failed")
    return save


def run_desktop(root: Path, stage_root: Path, engine: Path, package: dict, count: int, ticks: int, desktop, profile) -> dict:
    assert_no_competing_processes()
    print("TP_FRESH_NATIVE_RUN_BEGIN " + json.dumps({"revision": package["revision"],
          "package_sha256": package["sha256"], "count": count, "warmup_ticks": WARMUP,
          "end_tick": ticks, "native_log": str(root / "native-launch.log"),
          "capture_requirement": "collect native presentation events for this exclusive factorio.exe process"}), flush=True)
    old_argv, old_observer = sys.argv, desktop.OBSERVER
    desktop.OBSERVER = observer(count, ticks)
    sys.argv = [str(Path(desktop.__file__)), "--engine", str(engine), "--stage", str(stage_root),
                "--output", str(root), "--seconds", "240"]
    launch_error = None
    observation = None
    try:
        with observe_native_launch(desktop, root, engine) as observation:
            desktop.main()
    except Exception as exc:
        launch_error = str(exc)
    finally:
        sys.argv, desktop.OBSERVER = old_argv, old_observer
    proof = read_json(root / "desktop-proof.json") if (root / "desktop-proof.json").is_file() else {}
    log_path = root / "native-launch.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    verdict = validate_native(log, proof, count, ticks, profile.parse_wall_clock(log))
    if launch_error:
        verdict["passed"] = False
        verdict["failures"].append(launch_error)
    if observation is None or len(observation.records) != 1:
        verdict["passed"] = False
        verdict["failures"].append("exact native launch instrumentation was not observed")
    elif proof.get("passed") and proof.get("game_pid") != observation.records[0].get("game_pid"):
        verdict["passed"] = False
        verdict["failures"].append("visible native witness PID differs from the observed process")
    frames = {"available": False, "displayed_fps_verified": False}
    if observation and observation.frame_csv.is_file():
        frames = profile.parse_frame_stats(observation.frame_csv.read_bytes(), 0)
        frames.pop("measured_cpu_frame_raw", None)
        frames.update(available=True, path=str(observation.frame_csv), displayed_fps_verified=False,
                      interpretation="full raw rendering CSV; no assumed frame warmup or phase alignment")
    report = {"package": {key: package[key] for key in ("revision", "sha256")},
              "desktop": proof, "validation": verdict, "log": str(log_path),
              "log_sha256": sha(log_path) if log_path.is_file() else None,
              "launch_observation": observation.records if observation else [], "native_frame_csv": frames}
    (root / "native-validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("TP_FRESH_NATIVE_RUN_END " + json.dumps({"revision": package["revision"],
          "game_pid": proof.get("game_pid"), "activity_passed": verdict["passed"],
          "native_log_sha256": report["log_sha256"], "displayed_fps_verified": False}), flush=True)
    return report


def execute(request: dict) -> dict:
    if os.name != "nt":
        raise RuntimeError("Only the signed-in Windows worker can execute this wrapper")
    helper_dir = Path(request["helpers"]).resolve()
    stage, profile, desktop = load_helpers(helper_dir)
    verified = verify_inputs(request, stage.OFFICIAL)
    engine = Path(request["engine"]).resolve()
    for name in stage.OFFICIAL:
        if read_json(engine.parents[2] / "data" / name / "info.json").get("version") != "2.1.25":
            raise ValueError("Installed Factorio+Space Age official data mismatch: " + name)
    sid = desktop.session(os.getpid())
    if not sid or not desktop.active_session(sid):
        raise RuntimeError("Active signed-in Windows desktop required; Session 0 refused")
    engine_hash = sha(engine)
    packages, dependencies = verified["packages"], verified["dependencies"]
    if request["phase"] == "matched100":
        require_four(read_json(Path(request["four_receipt"])), packages["candidate"], engine_hash, dependencies)
    root = Path(request["output"]).resolve()
    report = {"schema": RECEIPT_SCHEMA, "phase": request["phase"], "passed": False,
              "candidate": {key: packages["candidate"][key] for key in ("revision", "sha256")},
              "engine_sha256": engine_hash,
              "dependency_sha256": {name: record["sha256"] for name, record in dependencies.items()},
              "helper_sha256": HELPER_SHA256,
              "fixture_sha256": hashlib.sha256(FRESH_OBSERVER.encode()).hexdigest(),
              "owner_save": False, "downloads": False, "published": False, "runs": [],
              "displayed_fps_verified": False, "performance_accepted": False,
              "presentation_capture": "must be separately routed by the exclusive native worker",
              "exclusive_scope": "shared router lock plus known game/render process preflight; router must serialize all GUI jobs"}
    with desktop_lock(Path(request["exclusive_lock"]).resolve()):
        assert_no_competing_processes()
        version = subprocess.run([str(engine), "--version"], capture_output=True, text=True,
                                 check=True, timeout=15)
        if not re.search(r"Version:\s*2\.1\.25\b", version.stdout) or "headless" in version.stdout.lower():
            raise RuntimeError("Verified graphical Factorio 2.1.25 required before fresh creation")
        if "steam" in version.stdout.lower() and not desktop.steam_in_session(sid):
            raise RuntimeError("Steam is not already running in the signed-in desktop; no launch attempted")
        root.mkdir(parents=True, exist_ok=False)
        try:
            labels = ("candidate",) if request["phase"] == "native4" else ("baseline", "candidate")
            staged = {}
            for label in labels:
                stage_root = root / (label + "-stage")
                mods = stage_mods(stage_root, packages[label], dependencies, stage.OFFICIAL)
                staged[label] = (stage_root, mods)
            seed_root, seed_mods = staged[labels[0]]
            seed = create_fresh(seed_root, engine, seed_mods, profile)
            report["fresh_save_sha256"] = sha(seed)
            for label in labels:
                stage_root, mods = staged[label]
                if stage_root != seed_root:
                    shutil.copy2(seed, stage_root / "fresh-nauvis.zip")
                    settings = seed_mods / "mod-settings.dat"
                    if settings.is_file():
                        shutil.copy2(settings, mods / settings.name)
                settings = mods / "mod-settings.dat"
                meta = {"fresh": True, "source_sha": packages[label]["revision"],
                        "release_archive_sha256": packages[label]["sha256"],
                        "note": "legacy launcher field names; private source package, not a published release",
                        "save_sha256": sha(stage_root / "fresh-nauvis.zip")}
                (stage_root / "stage-receipt.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
                result = run_desktop(root / (label + "-native"), stage_root, engine, packages[label],
                    4 if request["phase"] == "native4" else 100,
                    FOUR_TICKS if request["phase"] == "native4" else HUNDRED_TICKS, desktop, profile)
                for name, expected_hash in HELPER_SHA256.items():
                    if sha(helper_dir / name) != expected_hash:
                        raise RuntimeError("Existing launcher helper changed during the native run: " + name)
                result["helper_files_unchanged"] = True
                result.update(label=label, fresh_save_sha256=meta["save_sha256"],
                              mod_settings_sha256=sha(settings) if settings.is_file() else None)
                report["runs"].append(result)
                if not result["validation"]["passed"]:
                    break
            report["passed"] = len(report["runs"]) == len(labels) and all(run["validation"]["passed"] for run in report["runs"])
            if len(labels) == 2 and len(report["runs"]) == 2:
                report["matched_inputs"] = all(report["runs"][0][field] == report["runs"][1][field]
                                               for field in ("fresh_save_sha256", "mod_settings_sha256"))
                report["passed"] = report["passed"] and report["matched_inputs"]
        except Exception as exc:
            report["error"] = str(exc)
        finally:
            (root / "fresh-native-proof.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--request", type=Path, required=True)
    args = parser.parse_args()
    report = execute(read_json(args.request))
    print("TP_FRESH_NATIVE_PROOF " + json.dumps(report), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
