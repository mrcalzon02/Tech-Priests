#!/usr/bin/env python3
"""Replay an owner-provided save in a disposable, fully populated mod install.

Never edits the original save or mod directory. No dependencies are removed.
The optional four-station reconstruction is explicit and recorded separately
from original saved entities. Native per-tick timings come only from complete
Factorio verbose output; callback timings are an optional separate diagnostic.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import pathlib
import re
import shutil
import subprocess
import time
import zipfile


OBSERVER = r'''
-- Disposable owner-save benchmark observer. Not part of the shipped mod.
do
  local registry = require("scripts.core.runtime_event_registry")
  local broker = require("scripts.core.runtime_tick_broker")
  local elapsed_start, original_ids, original_count, reconstructed
  local function emit(record)
    log("[TP-OWNER-SAVE] " .. helpers.table_to_json(record))
  end
  local function live_pairs()
    local found={}
    for key,pair in pairs(storage.tech_priests and storage.tech_priests.pairs_by_station or {}) do
      if pair.station and pair.station.valid and pair.priest and pair.priest.valid then
        found[#found+1]={key=key,pair=pair}
      end
    end
    table.sort(found,function(a,b)return a.pair.station.unit_number<b.pair.station.unit_number end)
    return found
  end
  local function snapshot(phase,elapsed)
    local values={}
    local stable=true
    for _,item in ipairs(live_pairs()) do
      local p=item.pair
      local station,priest=p.station,p.priest
      if original_ids and original_ids[station.unit_number]~=priest.unit_number then stable=false end
      values[#values+1]={station=station.unit_number,station_name=station.name,
        priest=priest.unit_number,priest_name=priest.name,
        position={x=priest.position.x,y=priest.position.y},health=priest.health,
        mode=tostring(p.mode),repair_phase=p.repair_0516 and p.repair_0516.phase,
        consecration_phase=p.consecration_0515 and p.consecration_0515.phase,
        task=p.order_queue_0469 and p.order_queue_0469.current and p.order_queue_0469.current.kind}
    end
    if original_count and #values~=original_count then stable=false end
    local tp=storage.tech_priests or {}
    local repair_by_force={}
    for _,by_force in pairs(tp.work_queue_authority_0601 and tp.work_queue_authority_0601.queues or {}) do
      for force_id,categories in pairs(by_force) do
        local count=0
        for _ in pairs(categories.repair or {}) do count=count+1 end
        repair_by_force[tostring(force_id)]=(repair_by_force[tostring(force_id)] or 0)+count
      end
    end
    emit{phase=phase,tick=game.tick,elapsed_ticks=elapsed,live_pairs=#values,
      identities_stable=stable,reconstructed=reconstructed==true,pairs=values,
      connected_players=#game.connected_players,repair_queue_by_force=repair_by_force,
      enemy_force_index=game.forces.enemy.index,
      station_catalog_stats=tp.station_catalog_0327 and tp.station_catalog_0327.stats,
      logistics_fetch_stats=tp.logistics_fetch_executor_0527 and tp.logistics_fetch_executor_0527.stats,
      broker_stats=tp.runtime_tick_broker_0600 and tp.runtime_tick_broker_0600.stats,
      broker_service_stats=(elapsed==0 or elapsed==6000 or elapsed==__TICKS__-1)
        and tp.runtime_tick_broker_0600 and tp.runtime_tick_broker_0600.service_stats or nil,
      event_feeder_stats=tp.event_driven_work_feeder_0608 and tp.event_driven_work_feeder_0608.stats}
  end
  local function deploy()
    local force=game.forces.player
    local surface=game.surfaces.nauvis or game.surfaces[1]
    local specs={
      {name="planetary-magos-cogitator-station",position={x=-27.5,y=-22.5}},
      {name="junior-cogitator-station",position={x=-15.5,y=-22.5}},
      {name="intermediate-cogitator-station",position={x=-3.5,y=-22.5}},
      {name="senior-cogitator-station",position={x=8.5,y=-22.5}},
    }
    for _,spec in ipairs(specs) do
      local pos=surface.find_non_colliding_position(spec.name,spec.position,64,1,false)
      if not pos then error("Owner-save fixture cannot place "..spec.name) end
      local e=surface.create_entity{name=spec.name,position=pos,force=force,raise_built=true}
      if not(e and e.valid) then error("Owner-save fixture creation failed for "..spec.name) end
      emit{phase="reconstructed-station",tick=game.tick,name=spec.name,unit=e.unit_number,
        position={x=e.position.x,y=e.position.y},source="test-only reconstruction on copied pre-placement save"}
    end
    reconstructed=true
  end
  registry.on_event(defines.events.on_tick,function(event)
    if not elapsed_start then
      elapsed_start=event.tick
      emit{phase="loaded",tick=game.tick,saved_pairs=#live_pairs(),mods=script.active_mods,
        deploy_four_requested=__DEPLOY_FOUR__,callback_instrumentation=__INSTRUMENT__}
      if __DEPLOY_FOUR__ and #live_pairs()==0 then deploy() end
      original_ids={};original_count=0
      for _,item in ipairs(live_pairs()) do
        original_ids[item.pair.station.unit_number]=item.pair.priest.unit_number
        original_count=original_count+1
      end
      snapshot("start",0)
    end
    local elapsed=event.tick-elapsed_start
    if elapsed>0 and (elapsed%600==0 or elapsed==__TICKS__-1) then snapshot("sample",elapsed) end
  end,nil,{owner="ci-owner-save-profile",route="observe-original-identities",priority=1000000})
  if __INSTRUMENT__ then
    local function wrap(fn,scope,name,per_pair)
      local call_counts={}
      return function(...)
        local label=name
        if per_pair then
          local pair=select(1,...)
          if type(pair)=="table" and pair.station and pair.station.valid then
            label=name..":station="..pair.station.unit_number..":rank="..pair.station.name
          end
        end
        local calls=(call_counts[label] or 0)+1
        call_counts[label]=calls
        if calls%32~=1 then return fn(...) end
        local profiler=helpers.create_profiler(false)
        local result=table.pack(pcall(fn,...))
        profiler.stop()
        log{"","[TP-OWNER-CALLBACK] tick=",game.tick," scope=",scope,
          " name=",label," call=",calls," duration=",profiler}
        if not result[1] then error(result[2],0) end
        return table.unpack(result,2,result.n)
      end
    end
    for _,service in ipairs(broker.services) do
      service.fn=wrap(service.fn,"broker-service",service.name)
    end
    for kind,routes in pairs{event=registry.event_routes,nth=registry.nth_tick_routes} do
      for interval,entries in pairs(routes) do
        for _,entry in ipairs(entries) do
          if entry.owner~="ci-owner-save-profile" then
            entry.handler=wrap(entry.handler,"registry-"..kind,
              tostring(interval)..":"..entry.owner..":"..entry.route)
          end
        end
      end
    end
    -- These are the current 0510 dispatcher's actual exported owners, not
    -- superseded independent executor pulses. Sample each physical priest
    -- separately so a multiple-of-four cadence cannot alias one rank only.
    local owners={
      {"TechPriestsSingleDispatcher0510","scripts.core.single_dispatcher_0510",{"service_pair"}},
      {"TECH_PRIESTS_ORDER_QUEUE_0469","scripts.core.order_queue_0469",{"tick_pair"}},
      {"TECH_PRIESTS_ACTION_STATE_ARBITER_0488","scripts.core.action_state_arbiter_0488",{"action"}},
      {"TechPriestsDefensePerimeter0259","scripts.defense_perimeter",{"has_pending","service_pair"}},
      {"TechPriestsRemoteRailOutpost0835","scripts.core.remote_rail_outpost_0835",{"observe_pair"}},
      {"TechPriestsRailTrackFrontier0836","scripts.core.rail_track_frontier_0836",{"service_pair"}},
      {"TechPriestsResourceStationChain0820","scripts.core.resource_station_chain_0820",{"service_pair"}},
      {"TECH_PRIESTS_STATION_EXPANSION_0256","scripts.core.station_expansion_0256",{"service_station_expansion_assignment"}},
      {"TechPriestsResourceReturnCourier0837","scripts.core.resource_return_courier_0837",{"service","worker_reserved"}},
      {"TechPriestsConstructionPlanner0338","scripts.core.construction_planner",{"discover_pair","service_pair"}},
      {"TechPriestsDirectAcquisitionExecutor0513","scripts.core.direct_acquisition_executor_0513",{"current_direct_task","service_pair"}},
      {"TechPriestsEmergencyProductionExecutor0514","scripts.core.emergency_production_executor_0514",{"service_pair"}},
      {"TechPriestsCraftingExecutor","scripts.core.crafting_executor",{"service_pair"}},
      {"TechPriestsConsecrationExecutor0515","scripts.core.consecration_executor_0515",{"service_pair"}},
      {"TechPriestsRepairExecutor0516","scripts.core.repair_executor_0516",{"service_pair"}},
      {"TechPriestsCombatRepairDoctrine0517","scripts.core.combat_repair_doctrine_0517",{"service_pair"}},
      {"TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528","scripts.core.logistics_machine_fulfillment_0528",{"service_pair","yield_for_bootstrap"}},
      {"TechPriestsItemFamilyLogistics0702","scripts.core.item_family_logistics_0702",{"service_pair"}},
      {"TechPriestsEnergyFamilyLogistics0707","scripts.core.energy_family_logistics_0707",{"service_pair"}},
      {"TechPriestsRocketSiloLogistics0710","scripts.core.rocket_silo_logistics_0710",{"service_pair"}},
      {"TechPriestsArtilleryLogistics0713","scripts.core.artillery_logistics_0713",{"service_pair"}},
      {"TechPriestsRoboportRepairPackLogistics0715","scripts.core.roboport_repair_pack_logistics_0715",{"service_pair"}},
      {"","scripts.core.combat_roster_orders",{"service_pair","recommend_action"}},
      {"TechPriestsProxyAmmoHardener0649","scripts.core.proxy_ammo_hardener_0649",{"station_ammo","station_has_ammo","proxy_has_ammo","load_proxy_from_station","service_pair"}},
      {"TechPriestsMasterInfrastructurePlan0644","scripts.core.master_infrastructure_plan_0644",{"build_plan","service_pair"}},
      {"TechPriestsStationCatalog","scripts.core.station_catalog",{"scan_pair","get_for_pair","find_known_source"}},
    }
    for _,spec in ipairs(owners) do
      local owner=rawget(_G,spec[1]) or package.loaded[spec[2]]
      if type(owner)=="table" then
        for _,method in ipairs(spec[3]) do
          if type(owner[method])=="function" then
            owner[method]=wrap(owner[method],"dispatcher-branch",spec[2].."."..method,true)
          end
        end
      end
    end
    for _,name in ipairs{
      "tech_priests_0259_resource_expansion_service",
      "tech_priests_0507_action_claim",
      "tech_priests_inventory_steward_sources_for_pair",
      "tech_priests_0293_proxy_has_ammo",
      "tech_priests_0293_station_has_ammo",
      "tech_priests_0295_station_or_proxy_has_ammo",
      "tech_priests_0326_scan_station_catalog",
      "tech_priests_0327_scan_station_catalog",
      "tech_priests_0326_get_station_catalog",
      "tech_priests_0327_get_station_catalog",
      "tech_priests_0326_find_known_source",
      "tech_priests_0327_find_known_source",
    } do
      local fn=rawget(_G,name)
      if type(fn)=="function" then _G[name]=wrap(fn,"dispatcher-global",name,true) end
    end
  end
end
'''


def digest(path: pathlib.Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def distribution(values: list[float]) -> dict:
    values = sorted(values)
    def percentile(p: float) -> float:
        return values[max(0, math.ceil(len(values) * p) - 1)]
    return {"samples": len(values), "mean_ms": sum(values) / len(values),
            "p50_ms": percentile(.50), "p95_ms": percentile(.95),
            "p99_ms": percentile(.99), "max_ms": values[-1],
            "over_16_667_ms": sum(x > 1000 / 60 for x in values),
            "over_50_ms": sum(x > 50 for x in values),
            "over_100_ms": sum(x > 100 for x in values)}


def parse_log(text: str, expected_ticks: int, warmup: int) -> dict:
    result = {"engine_updates": None, "engine_mean_ms": None,
              "engine_benchmark_ups": None, "per_tick_complete": False,
              "timings": {}, "timing_windows": [], "observations": [], "callback_samples": []}
    summary = re.search(r"Performed\s+(\d+)\s+updates in\s+([\d.]+)\s+ms", text)
    if summary:
        updates, elapsed = int(summary[1]), float(summary[2])
        result.update(engine_updates=updates,engine_mean_ms=elapsed/updates,
                      engine_benchmark_ups=1000*updates/elapsed)
    for line in text.splitlines():
        if "[TP-OWNER-SAVE] " in line:
            result["observations"].append(json.loads(line.split("[TP-OWNER-SAVE] ", 1)[1]))
    rows, headers = [], None
    for line in text.splitlines():
        if line.startswith("tick,"):
            if headers is not None:
                return result  # Multiple runs need explicit separate provenance.
            headers = next(csv.reader([line.rstrip(",")]))
        elif headers is not None and re.match(r"^(?:t)?\d+,", line):
            values = next(csv.reader([line.rstrip(",")]))
            if len(values) != len(headers):
                continue
            try:
                tick = int(values[0].removeprefix("t"))
                timings = [float(x) / 1_000_000 for x in values[1:]]
            except ValueError:
                continue
            if not all(math.isfinite(x) and x >= 0 for x in timings):
                continue
            rows.append((tick, timings))
    if headers and len(rows) == expected_ticks and [r[0] for r in rows] == list(range(expected_ticks)):
        result["per_tick_complete"] = True
        result["excluded_warmup_ticks"] = warmup
        for index, name in enumerate(headers[1:]):
            if name=="timestamp":
                continue
            result["timings"][name] = distribution([r[1][index] for r in rows[warmup:]])
        # Keep sustained-cost evidence in the JSON/job log: artifact quotas
        # may prevent later inspection of the complete native CSV. Bounds are
        # benchmark-relative, inclusive start and exclusive end, not game ticks.
        for start, end in ((warmup, min(6000, expected_ticks)),
                           (max(warmup, 6000), expected_ticks)):
            if start >= end:
                continue
            result["timing_windows"].append({
                "start_tick_inclusive": start, "end_tick_exclusive": end,
                "timings": {name: distribution([r[1][index] for r in rows[start:end]])
                            for index, name in enumerate(headers[1:])
                            if name in ("wholeUpdate", "scriptUpdate")}})
    callbacks = {}
    expression = (r"\[TP-OWNER-CALLBACK\] tick=(\d+) scope=(\S+) name=(.*?) call=(\d+) "
                  r"duration=(?:Elapsed|Duration):\s*([\d.]+)\s*ms")
    for tick, scope, name, call, ms in re.findall(expression, text):
        key=(scope,name)
        callbacks.setdefault(key,[]).append(float(ms))
    for (scope,name),values in callbacks.items():
        result["callback_samples"].append({"scope":scope,"name":name,**distribution(values)})
    result["callback_samples"].sort(key=lambda v:v["mean_ms"]*v["samples"],reverse=True)
    return result


def run(args: list[str], log: pathlib.Path, timeout: int) -> dict:
    start = time.monotonic()
    with log.open("w", encoding="utf-8") as stream:
        try:
            proc = subprocess.run(args, stdout=stream, stderr=subprocess.STDOUT,
                                  timeout=timeout, check=False)
            status = proc.returncode
        except subprocess.TimeoutExpired:
            status=124
            stream.write("\nTP_OWNER_SAVE_TIMEOUT\n")
    return {"exit_code":status,"wall_seconds":round(time.monotonic()-start,6),"log":log.name}


def prepare_mods(source: pathlib.Path, target: pathlib.Path) -> pathlib.Path:
    shutil.copytree(source, target)
    directories=[p for p in target.iterdir() if p.is_dir() and (p/"info.json").is_file()
                 and json.loads((p/"info.json").read_text(encoding="utf-8"))["name"]=="tech-priests"]
    packages=list(target.glob("tech-priests_[0-9]*.zip"))
    if directories and packages or len(directories)+len(packages)!=1:
        raise ValueError("Exactly one Tech-Priests package/directory is required")
    if packages:
        with zipfile.ZipFile(packages[0]) as archive:
            # Factorio ZIPs must contain only relative files below one mod root.
            names=archive.namelist()
            roots={n.split("/",1)[0] for n in names}
            if len(roots)!=1 or any(pathlib.PurePosixPath(n).is_absolute() or ".." in pathlib.PurePosixPath(n).parts for n in names):
                raise ValueError("Invalid mod archive paths")
            archive.extractall(target)
        packages[0].unlink()  # Deletes only the just-copied disposable duplicate.
        directories=[target/next(iter(roots))]
    return directories[0]


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio",type=pathlib.Path,required=True)
    parser.add_argument("--save",type=pathlib.Path,required=True)
    parser.add_argument("--mods",type=pathlib.Path,required=True)
    parser.add_argument("--output",type=pathlib.Path,required=True)
    parser.add_argument("--ticks",type=int,default=6000)
    parser.add_argument("--warmup",type=int,default=600)
    parser.add_argument("--timeout",type=int,default=1800)
    parser.add_argument("--deploy-four",action="store_true")
    parser.add_argument("--instrument-callbacks",action="store_true")
    args=parser.parse_args()
    if not 0<=args.warmup<args.ticks:
        parser.error("warmup must be nonnegative and less than ticks")
    for field in ("factorio","save","mods","output"):
        setattr(args,field,getattr(args,field).resolve())
    args.output.mkdir(parents=True,exist_ok=False)
    report={"schema":"tech-priests.owner-save-profile.v1","passed":False,
            "save_sha256":digest(args.save),"requested_ticks":args.ticks,
            "harness_sha256":digest(pathlib.Path(__file__)),
            "reconstruction_requested":args.deploy_four,
            "callback_instrumentation":args.instrument_callbacks,
            "script_scope":"whole-engine-all-installed-mods",
            "callback_scope":("sparse one-in-32 calls, nested scopes overlap; diagnostic overhead present"
                              if args.instrument_callbacks else "disabled")}
    try:
        native=subprocess.run([str(args.factorio),"--version"],capture_output=True,text=True,check=True)
        report["engine_version"]=(native.stdout+native.stderr).strip()
        mod=prepare_mods(args.mods,args.output/"mods")
        report["tech_priests_version"]=json.loads((mod/"info.json").read_text(encoding="utf-8"))["version"]
        with (mod/"control.lua").open("a",encoding="utf-8") as stream:
            stream.write(OBSERVER.replace("__DEPLOY_FOUR__",str(args.deploy_four).lower())
                         .replace("__INSTRUMENT__",str(args.instrument_callbacks).lower())
                         .replace("__TICKS__",str(args.ticks)))
        save=args.output/"input-copy.zip"
        shutil.copy2(args.save,save)
        userdata=args.output/"user-data";userdata.mkdir()
        config=args.output/"config.ini"
        config.write_text("[path]\nread-data="+(args.factorio.parents[2]/"data").as_posix()
                          +"\nwrite-data="+userdata.as_posix()
                          +"\n[other]\ncheck-updates=false\n",encoding="utf-8")
        common=[str(args.factorio),"--config",str(config),"--mod-directory",str(args.output/"mods"),
                "--benchmark",str(save),"--benchmark-ticks",str(args.ticks),"--benchmark-runs","1"]
        verbose=args.output/"benchmark-verbose.log"
        report["verbose_process"]=run(common+["--benchmark-verbose","all"],verbose,args.timeout)
        content=verbose.read_text(encoding="utf-8",errors="replace")
        report["observed"]=parse_log(content,args.ticks,args.warmup)
        exit_code=report["verbose_process"]["exit_code"]
        # Only the engine's previously observed verbose-output crash permits
        # a plain same-save retry. All other errors remain real failures.
        if (exit_code!=0 and "Received SIGSEGV" in content
                and report["observed"]["engine_updates"]==args.ticks
                and "tick," in content and not report["observed"]["per_tick_complete"]):
            plain=args.output/"benchmark-plain.log"
            report["plain_process"]=run(common,plain,args.timeout)
            report["observed_verbose_incomplete"]=report["observed"]
            content=plain.read_text(encoding="utf-8",errors="replace")
            report["observed"]=parse_log(content,args.ticks,args.warmup)
            exit_code=report["plain_process"]["exit_code"]
        snapshots=[v for v in report["observed"]["observations"] if v["phase"] in ("start","sample")]
        report["four_pairs_verified"]=bool(snapshots and snapshots[-1]["elapsed_ticks"]==args.ticks-1
            and all(v["live_pairs"]==4 and v["identities_stable"] for v in snapshots))
        report["original_save_unchanged"]=digest(args.save)==report["save_sha256"]
        report["passed"]=bool(exit_code==0 and report["observed"]["engine_updates"]==args.ticks
            and report["original_save_unchanged"] and snapshots
            and (not args.deploy_four or report["four_pairs_verified"]))
        report["isolated_handler_errors"]=len(re.findall(r"isolated handler failure",content))
        report["native_checksums"]=[line.strip() for line in content.splitlines()
            if "Checksum of " in line or "Checksum for " in line or "Prototype list checksum" in line]
        report["runtime_error_lines"]=[line.strip() for line in content.splitlines()
            if "isolated handler failure" in line or "Error while " in line or "stack traceback" in line]
        if report["runtime_error_lines"]:
            report["passed"] = False
        for line in report["native_checksums"]:
            print("TP_OWNER_NATIVE_CHECKSUM "+line,flush=True)
        for line in report["runtime_error_lines"][:30]:
            print("TP_OWNER_RUNTIME_ERROR "+line,flush=True)
        for observation in report["observed"]["observations"]:
            print("TP_OWNER_SAVE_OBSERVATION "+json.dumps(observation),flush=True)
    except Exception as exc:
        report["error"]=str(exc)
    (args.output/"profile-result.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    # A private job log must retain the full receipt even when GitHub's
    # account-wide artifact quota rejects the optional artifact upload.
    packed=json.dumps(report)
    parts=[packed[i:i+24000] for i in range(0,len(packed),24000)]
    for index,part in enumerate(parts):
        print("TP_OWNER_SAVE_RESULT_JSON_PART "+json.dumps({
            "part":index,"total":len(parts),"data":part}),flush=True)
    observed=report.get("observed",{})
    print("TP_OWNER_SAVE_PROFILE "+json.dumps({
        "passed":report["passed"],"error":report.get("error"),
        "save_sha256":report["save_sha256"],"engine_version":report.get("engine_version"),
        "four_pairs_verified":report.get("four_pairs_verified"),
        "reconstruction_requested":args.deploy_four,"instrumented":args.instrument_callbacks,
        "engine_updates":observed.get("engine_updates"),
        "engine_mean_ms":observed.get("engine_mean_ms"),
        "engine_benchmark_ups":observed.get("engine_benchmark_ups"),
        "per_tick_complete":observed.get("per_tick_complete"),
        "timing_windows":observed.get("timing_windows",[]),
        "timings":{k:v for k,v in observed.get("timings",{}).items()
                   if k in ("wholeUpdate","scriptUpdate","entityUpdate","pathFinder","turretTargetAcquisition","luaGarbageIncremental")},
        "top_callbacks":observed.get("callback_samples",[])[:20]}),flush=True)
    return 0 if report["passed"] else 1


if __name__=="__main__":
    raise SystemExit(main())
