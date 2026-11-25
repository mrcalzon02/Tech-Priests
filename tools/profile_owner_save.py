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
import base64
import hashlib
import io
import json
import math
import os
import pathlib
import re
import shutil
import subprocess
import time
import zipfile
import zlib


WINDOWS_GRAPHICS_FLAGS = ("--force-opengl", "--fullscreen=false", "--disable-audio", "--gfx-safe-mode")
FRAME_METRICS = ("update", "prepare", "cpu-render", "cpu-flip", "sleep", "cpu-frame", "gpu-frame")
FRAME_TIMING_UNITS = "unconfirmed native CSV units; no conversion applied"


def parse_frame_stats(raw: bytes, warmup_frames: int) -> dict:
    """Validate native graphical frame rows without inventing game-tick timing."""
    result={"csv_valid":False,"file_sha256":hashlib.sha256(raw).hexdigest(),"file_bytes":len(raw),
        "raw_headers":[],"row_count":0,"measured_frame_count":0,"metrics":{},
        "nonmetric_metadata_columns":["config-key","config-value"],
        "timing_units":FRAME_TIMING_UNITS,"unit_source":None,
        "row_index_basis":"zero-based native CSV data row; not a game tick",
        "game_tick_correlation":"unavailable","script_update_timing":"unavailable",
        "excluded_warmup_frames":warmup_frames,
        "warmup_basis":"first N graphical CSV frame rows; independent of game-tick observation warmup"}
    try:
        if warmup_frames<0:
            raise ValueError("Negative frame warmup")
        rows=csv.reader(io.StringIO(raw.decode("utf-8-sig")),strict=True)
        header=next(rows,[])
        result["raw_headers"]=header
        if not header or any(not name for name in header) or len(set(header))!=len(header):
            raise ValueError("Missing or duplicate frame CSV headers")
        if not all(name in header for name in FRAME_METRICS):
            raise ValueError("Native graphical frame metric columns missing")
        numeric=[i for i,name in enumerate(header) if name not in ("config-key","config-value")]
        frames=[]
        for index,row in enumerate(rows):
            if len(row)!=len(header):
                raise ValueError(f"Frame row {index} has an incorrect column count")
            values={header[i]:float(row[i]) for i in numeric}
            if any(not math.isfinite(value) or value<0 for value in values.values()):
                raise ValueError(f"Frame row {index} contains nonfinite or negative numeric values")
            frames.append({name:values[name] for name in FRAME_METRICS})
        result["row_count"]=len(frames)
        if not frames:
            raise ValueError("Native graphical frame CSV has no data rows")
        result["csv_valid"]=True
        measured=frames[warmup_frames:]
        result["measured_frame_count"]=len(measured)
        for name in FRAME_METRICS:
            if not measured:
                break
            values=sorted(row[name] for row in measured)
            result["metrics"][name]={"samples":len(values),"mean":sum(values)/len(values),
                "p50":values[max(0,math.ceil(len(values)*.50)-1)],
                "p95":values[max(0,math.ceil(len(values)*.95)-1)],
                "p99":values[max(0,math.ceil(len(values)*.99)-1)],"max":values[-1]}
        largest=sorted(enumerate(frames),key=lambda item:(-item[1]["update"],item[0]))[:100]
        result["largest_update_frames"]=[{"frame_row_index":index,
            "phase":"frame-warmup" if index<warmup_frames else "measured-frames",**values}
            for index,values in largest]
    except (UnicodeDecodeError,csv.Error,ValueError) as exc:
        result["error"]=str(exc)
    return result


def emit_compressed_evidence(raw: bytes, marker: str, kind: str) -> dict:
    """Keep complete native bytes in bounded log records when artifacts fail."""
    compressed=zlib.compress(raw,9)
    encoded=base64.b64encode(compressed).decode("ascii")
    chunks=[encoded[i:i+16000] for i in range(0,len(encoded),16000)]
    receipt={"kind":kind,"encoding":"zlib+base64","raw_sha256":hashlib.sha256(raw).hexdigest(),
             "raw_bytes":len(raw),"compressed_sha256":hashlib.sha256(compressed).hexdigest(),
             "compressed_bytes":len(compressed),"parts":len(chunks)}
    for index,chunk in enumerate(chunks):
        print(marker+" "+json.dumps({"part":index,"total":len(chunks),"kind":kind,
            "sha256":receipt["raw_sha256"],"compressed_sha256":receipt["compressed_sha256"],
            "encoding":"zlib+base64","data":chunk}),flush=True)
    return receipt


def emit_frame_csv(raw: bytes) -> dict:
    return emit_compressed_evidence(raw,"TP_OWNER_FRAME_CSV_PART","native-graphical-frame-csv")


def emit_native_log(raw: bytes) -> dict:
    return emit_compressed_evidence(raw,"TP_OWNER_NATIVE_LOG_PART","native-update-benchmark-log")


def windows_session_id(pid: int | None = None) -> int | None:
    """Read the real process session; never acquire or impersonate a token."""
    if os.name != "nt":
        return None
    import ctypes
    from ctypes import wintypes
    session = wintypes.DWORD()
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    if not kernel.ProcessIdToSessionId(pid or os.getpid(), ctypes.byref(session)):
        raise ctypes.WinError(ctypes.get_last_error())
    return session.value


def refuse_running_factorio() -> None:
    """Refuse concurrent games; do not stop or attach to existing processes."""
    if os.name != "nt":
        return
    result = subprocess.run(["tasklist.exe", "/fo", "csv", "/nh", "/fi", "IMAGENAME eq factorio.exe"],
                            capture_output=True, text=True, errors="replace", check=True, timeout=15)
    if not result.stdout.strip():
        raise RuntimeError("FACTORIO_PROCESS_CHECK_UNAVAILABLE: no tasklist response")
    if any(row and row[0].lower() == "factorio.exe" for row in csv.reader(result.stdout.splitlines())):
        raise RuntimeError("FACTORIO_ALREADY_RUNNING: existing game was not interrupted")


def graphics_evidence(text: str) -> dict:
    """Only a native initialization line identifies the observed backend."""
    lines = [line.strip() for line in text.splitlines()
             if any(term in line for term in ("Direct3D", "OpenGL", "Vulkan", "Graphics backend", "Video memory", "Graphics Adapter"))][:40]
    match = re.search(r"(?im)^.*?\bInitiali[sz]ed\s+(OpenGL|Direct3D(?:\s*\d+)?|Vulkan)\s*:\s*(.+)$", text)
    return {"observed_backend": match[1] if match else None,
            "renderer_identity": match[2].strip() if match else None,
            "initialization_lines": lines}


OBSERVER = r'''
-- Disposable owner-save benchmark observer. Not part of the shipped mod.
do
  local registry = require("scripts.core.runtime_event_registry")
  local broker = require("scripts.core.runtime_tick_broker")
  local installed_local_hooks
  local elapsed_start, original_ids, original_count, reconstructed
  local observed_tick_count,last_observed_tick,observed_tick_sequence_valid=0,nil,true
  -- Read existing owners only. These are receipts from the physical mutation
  -- paths, not manufactured test work or an extra entity-discovery pass.
  local counter_specs={
    direct_acquired={"direct_acquisition_executor_0513","physical-custody-acquired-0513"},
    direct_deposited={"direct_acquisition_executor_0513","custody-deposited-0513"},
    repair_complete={"repair_executor_0516","complete"},
    repair_packs_applied={"repair_executor_0516","packs-applied"},
    consecration_complete={"consecration_executor_0515","complete"},
    entities_built={"construction_planner","entities-built"},
    emergency_transactions_complete={"emergency_production_executor_0514","transaction-complete-0514"},
    machine_supply_complete={"logistics_machine_fulfillment_0528","supply-complete"},
    machine_output_complete={"logistics_machine_fulfillment_0528","output-complete"},
    machine_items_inserted={"logistics_machine_fulfillment_0528","machine_items_inserted"},
    machine_output_removed={"logistics_machine_fulfillment_0528","machine_output_removed"},
  }
  local stock_items={"iron-plate","copper-plate","stone","coal",
    "iron-gear-wheel","repair-pack","automation-science-pack"}
  local function station_stock(station)
    local ok,inv=pcall(function()return station.get_inventory(defines.inventory.chest)end)
    if not(ok and inv and inv.valid) then return nil end
    local counts={}
    for _,name in ipairs(stock_items) do
      local counted,n=pcall(function()return inv.get_item_count(name)end)
      if counted and type(n)=="number" then counts[name]=n end
    end
    return counts
  end
  local function behavior_counters()
    local tp=storage.tech_priests or {}
    local counters,owners={},{}
    for label,spec in pairs(counter_specs) do
      local owner=tp[spec[1]]
      owners[spec[1]]={available=type(owner)=="table",enabled=owner and owner.enabled}
      if owner and type(owner.stats)=="table" then
        counters[label]=tonumber(owner.stats[spec[2]]) or 0
      end
    end
    return counters,owners
  end
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
      local catalog_root=storage.tech_priests and storage.tech_priests.station_catalog_0327
      local current=catalog_root and catalog_root.stations and catalog_root.stations[station.unit_number]
      local pending=catalog_root and catalog_root.pending_scans and catalog_root.pending_scans[station.unit_number]
      local partial=catalog_root and catalog_root.partial_stations and catalog_root.partial_stations[station.unit_number]
      local pending_info=pending and (pending.scan_info or (pending.dense and pending.dense.info))
      if original_ids and original_ids[station.unit_number]~=priest.unit_number then stable=false end
      values[#values+1]={station=station.unit_number,station_name=station.name,
        priest=priest.unit_number,priest_name=priest.name,
        station_position={x=station.position.x,y=station.position.y},
        surface_index=station.surface.index,force_index=station.force.index,
        position={x=priest.position.x,y=priest.position.y},health=priest.health,
        mode=tostring(p.mode),repair_phase=p.repair_0516 and p.repair_0516.phase,
        consecration_phase=p.consecration_0515 and p.consecration_0515.phase,
        direct_phase=p.dispatcher_direct_0513 and p.dispatcher_direct_0513.phase,
        direct_custody=p.direct_acquisition_custody_0513 and {
          item=p.direct_acquisition_custody_0513.item,count=p.direct_acquisition_custody_0513.count},
        catalog_observation={published_present=current~=nil,
          published_started_tick=current and current.scan_started_tick,
          published_completed_tick=current and current.scan_completed_tick,
          published_incomplete=current and current.scan_incomplete_1478,
          published_reason=current and current.scan_reason_1478,
          published_queries=current and current.scan_queries_1478,
          published_entities=current and current.scan_entities_1478,
          published_collisions=current and current.scan_identity_collisions_1481,
          partial_completed_tick=partial and partial.scan_completed_tick,
          partial_incomplete=partial and partial.scan_incomplete_1478,
          partial_reason=partial and partial.scan_reason_1478,
          partial_queries=partial and partial.scan_queries_1478,
          partial_entities=partial and partial.scan_entities_1478,
          partial_collisions=partial and partial.scan_identity_collisions_1481,
          pending_phase=pending and pending.phase,
          pending_started_tick=pending and pending.started_tick,
          pending_age_ticks=pending and (game.tick-pending.started_tick),
          pending_processed=pending and pending.processed,
          pending_queries=pending_info and pending_info.queries,
          -- The in-progress coverage flag is not a completed certificate.
          pending_scan_done=pending and pending.dense and pending.dense.done==true,
          pending_scan_complete=pending_info and pending_info.complete,
          pending_scan_reason=pending_info and pending_info.reason,
          pending_scan_entities=pending_info and pending_info.unique,
          pending_scan_collisions=pending_info and pending_info.identity_collisions,
          pending_scan_splits=pending_info and pending_info.splits,
          pending_saturated_queries=pending_info and pending_info.saturated_queries,
          pending_truncated_leaves=pending_info and pending_info.truncated_leaves,
          pending_budget_exhausted=pending_info and pending_info.budget_exhausted==true,
          pending_invalidated=pending and pending.invalidated==true,
          pending_invalid_entity=pending and pending.invalid_entity==true,
          pending_ownership_conflict=pending and pending.ownership_conflict==true},
        station_chest_items=station_stock(station),
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
    local counters,owners=behavior_counters()
    emit{phase=phase,tick=game.tick,elapsed_ticks=elapsed,live_pairs=#values,
      observed_tick_count=__GRAPHICS__ and observed_tick_count or nil,
      observed_tick_sequence_valid=__GRAPHICS__ and observed_tick_sequence_valid or nil,
      identities_stable=stable,reconstructed=reconstructed==true,pairs=values,
      behavior_counters=counters,behavior_owners=owners,
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
    if __GRAPHICS__ then
      observed_tick_count=observed_tick_count+1
      if last_observed_tick and event.tick~=last_observed_tick+1 then observed_tick_sequence_valid=false end
      last_observed_tick=event.tick
    end
    if not elapsed_start then
      elapsed_start=event.tick
      if __INSTRUMENT__ then
        assert(installed_local_hooks and #installed_local_hooks==8,
          "Owner-save diagnostic local instrumentation was not installed")
        emit{phase="instrumentation-ready",tick=game.tick,
          local_hook_names=installed_local_hooks}
      end
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
    if __GRAPHICS__ and elapsed==300 then
      local pairs=live_pairs()
      if #pairs>0 then
        local x,y=0,0
        for _,entry in ipairs(pairs) do x=x+entry.pair.station.position.x;y=y+entry.pair.station.position.y end
        game.take_screenshot{surface=pairs[1].pair.station.surface,
          position={x=x/#pairs,y=y/#pairs},resolution={1600,1000},zoom=0.65,
          path="owner-profile/four-priests.png",show_entity_info=true,show_gui=false}
        emit{phase="native-screenshot-requested",tick=game.tick,elapsed_ticks=elapsed,
          path="owner-profile/four-priests.png"}
      end
    end
    if elapsed>0 and (elapsed%600==0 or elapsed==__WARMUP__ or elapsed==__TICKS__-1) then
      snapshot(__GRAPHICS__ and elapsed==__TICKS__-1 and "end" or "sample",elapsed)
    end
  end,nil,{owner="ci-owner-save-profile",route="observe-original-identities",priority=1000000})
  if __INSTRUMENT__ then
    local function wrap(fn,scope,name,per_pair)
      local call_counts={}
      -- Rare scheduled owners need every invocation to avoid sampling away a
      -- complete warm replay. All wrappers are absent in comparison mode.
      local interval=scope=="registry-nth" and tonumber(name:match("^(%d+):"))
      local every_call=(interval and interval>=60)
        or (scope=="registry-nth" and name=="5:runtime_tick_broker_0600:central-pulse")
        or scope=="dispatcher-branch"
        or scope=="broker-service"
        or (scope=="infrastructure-local" and name:sub(1,5)=="0644.")
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
        if not every_call and calls%32~=1 then return fn(...) end
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
      {"TechPriestsSingleDispatcher0510","scripts.core.single_dispatcher_0510",{"service_pair",
        "TECH_PRIESTS_0519_PRE_SERVICE_PAIR","TECH_PRIESTS_0527_PRE_SERVICE_PAIR","TECH_PRIESTS_0529_PRE_GROUND_HOOVER"}},
      {"TECH_PRIESTS_LOGISTICS_FETCH_EXECUTOR_0527","scripts.core.logistics_fetch_executor_0527",{"service_pair"}},
      {"TECH_PRIESTS_GROUND_ITEM_HOOVER_0529","scripts.core.ground_item_hoover_0529",{"service_pair"}},
      {"TECH_PRIESTS_LOGISTICS_CONSTRUCTION_CONTRACT_0519","scripts.core.logistics_construction_contract_0519",
        {"has_constructible_pair","item_available_or_producible","service_construction"}},
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
      {"TechPriestsStationCatalog","scripts.core.station_catalog",{"scan_pair","step_pair","publish_pending","inventory_candidates","get_for_pair","find_known_source"}},
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
    local infrastructure=rawget(_G,"TechPriestsMasterInfrastructurePlan0644")
      or package.loaded["scripts.core.master_infrastructure_plan_0644"]
    assert(infrastructure and type(infrastructure.__tp_owner_profile_locals)=="function",
      "Owner-save diagnostic infrastructure local hooks are unavailable")
    installed_local_hooks=infrastructure.__tp_owner_profile_locals(wrap)
    log("[TP-OWNER-PROFILE-LOCALS] owner=master_infrastructure_plan_0644 active="
      ..table.concat(installed_local_hooks,","))
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


LOCAL_PROFILE_FUNCTIONS_0644 = (
    "scan_resources", "scan_roles", "choose", "cheapest_available_science",
    "craft_feasibility", "unlocked_recipe", "station_count", "uncovered_drill_output")


def callback_sampling_policy(enabled: bool) -> dict | None:
    if not enabled:
        return None
    return {"default":"calls 1, 33, 65, ... per label",
        "every_call":[
            {"scope":"registry-nth","minimum_interval_ticks":60},
            {"scope":"registry-nth","name":"5:runtime_tick_broker_0600:central-pulse"},
            {"scope":"dispatcher-branch"},
            {"scope":"broker-service"},
            *({"scope":"infrastructure-local","name":"0644."+name} for name in LOCAL_PROFILE_FUNCTIONS_0644)],
        "warmup_included":True,
        "overlap":"nested service/local scopes overlap; final step_pair includes publish_pending; do not sum these durations"}


def instrument_infrastructure_locals(mod: pathlib.Path) -> None:
    """Expose existing local closures only inside the disposable test copy."""
    path=mod/"scripts/core/master_infrastructure_plan_0644.lua"
    source=path.read_text(encoding="utf-8")
    for name in LOCAL_PROFILE_FUNCTIONS_0644:
        if not re.search(r"local function "+re.escape(name)+r"\(",source):
            raise ValueError("Infrastructure local missing from test target: "+name)
    end=re.search(r"\nreturn M\s*$",source)
    if not end:
        raise ValueError("Infrastructure module return not found in test target")
    hook="\n-- Test-only hooks, injected into the private disposable benchmark copy.\n"
    hook+="M.__tp_owner_profile_locals=function(wrap)\n"
    for name in LOCAL_PROFILE_FUNCTIONS_0644:
        hook+=f'  {name}=wrap({name},"infrastructure-local","0644.{name}",true)\n'
    hook+="  return {"+",".join(json.dumps(name) for name in LOCAL_PROFILE_FUNCTIONS_0644)+"}\n"
    hook+="end\n"
    path.write_text(source[:end.start()]+hook+source[end.start():],encoding="utf-8")


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
              "timings": {}, "timing_windows": [], "slowest_ticks": [],
              "slowest_warm_ticks": [], "observations": [], "callback_samples": [],
              "callback_sample_rows": [], "callback_samples_after_warmup": [],
              "spike_evidence": {"available": False}}
    summary = re.search(r"Performed\s+(\d+)\s+updates in\s+([\d.]+)\s+ms", text)
    if summary:
        updates, elapsed = int(summary[1]), float(summary[2])
        result.update(engine_updates=updates,engine_mean_ms=elapsed/updates,
                      engine_benchmark_ups=1000*updates/elapsed)
    for line in text.splitlines():
        if "[TP-OWNER-SAVE] " in line:
            result["observations"].append(json.loads(line.split("[TP-OWNER-SAVE] ", 1)[1]))
    starts=[row.get("tick") for row in result["observations"] if row.get("phase")=="start"]
    start_tick=starts[0] if len(starts)==1 and isinstance(starts[0],int) else None
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
        positions = {name: index for index, name in enumerate(headers[1:])}
        if "wholeUpdate" in positions:
            retained_columns = ("wholeUpdate", "scriptUpdate", "entityUpdate",
                                "luaGarbageIncremental", "pathFinder", "mapGenerator")
            def slowest(source_rows):
                selected = sorted(source_rows,
                                  key=lambda row: row[1][positions["wholeUpdate"]],
                                  reverse=True)[:40]
                return [{"benchmark_tick": tick,
                         "timings_ms": {name: values[positions[name]]
                                        for name in retained_columns if name in positions}}
                        for tick, values in selected]
            result["slowest_ticks"] = slowest(rows)
            result["slowest_warm_ticks"] = slowest(rows[warmup:])
        for index, name in enumerate(headers[1:]):
            if name=="timestamp":
                continue
            result["timings"][name] = distribution([r[1][index] for r in rows[warmup:]])
        # Keep sustained-cost evidence even if artifact storage is unavailable.
        # Window bounds are benchmark-relative: inclusive start, exclusive end.
        for start, end in ((warmup, min(6000, expected_ticks)),
                           (max(warmup, 6000), expected_ticks)):
            if start >= end:
                continue
            result["timing_windows"].append({
                "start_tick_inclusive": start, "end_tick_exclusive": end,
                "timings": {name: distribution([r[1][index] for r in rows[start:end]])
                            for index, name in enumerate(headers[1:])
                            if name in ("wholeUpdate", "scriptUpdate")}})
        # Preserve exact costly rows when artifact quota discards the full CSV.
        # Benchmark row zero is the first update; observer elapsed zero is its
        # on_tick snapshot. Warmup attribution uses that same zero-based index.
        indexes={name:index for index,name in enumerate(headers[1:]) if name!="timestamp"}
        if all(name in indexes for name in ("wholeUpdate","scriptUpdate")):
            spikes=[]
            counts={phase:{"over_33_333_ms":0,"over_100_ms":0} for phase in ("all","warmup","measured")}
            for tick,values in rows:
                duration=max(values[indexes["wholeUpdate"]],values[indexes["scriptUpdate"]])
                if duration<=33.333:
                    continue
                phase="warmup" if tick<warmup else "measured"
                for scope in ("all",phase):
                    counts[scope]["over_33_333_ms"]+=1
                    counts[scope]["over_100_ms"]+=int(duration>100)
                names=list(indexes) if len(indexes)<=48 else ["wholeUpdate","scriptUpdate"]
                spikes.append({"csv_row_index":tick,"elapsed_tick":tick,
                    "game_tick":start_tick+tick if start_tick is not None else None,
                    "phase":phase,"duration_ms":duration,
                    "timings_ms":{name:values[indexes[name]] for name in names}})
            spikes.sort(key=lambda row:(-row["duration_ms"],row["csv_row_index"]))
            result["spike_evidence"]={"available":True,"threshold_ms":33.333,"row_limit":100,
                "row_index_basis":"zero-based native benchmark update; game_tick anchored to unique observer start",
                "counts":counts,"retained_rows":spikes[:100],"truncated":len(spikes)>100,
                "all_timing_columns_retained":len(indexes)<=48}
    callbacks, warm_callbacks = {}, {}
    expression = (r"\[TP-OWNER-CALLBACK\] tick=(\d+) scope=(\S+) name=(.*?) call=(\d+) "
                  r"duration=(?:Elapsed|Duration):\s*([\d.]+)\s*ms")
    for tick, scope, name, call, ms in re.findall(expression, text):
        key=(scope,name)
        callbacks.setdefault(key,[]).append(float(ms))
        elapsed=int(tick)-start_tick if start_tick is not None else None
        result["callback_sample_rows"].append({"tick":int(tick),"elapsed_tick":elapsed,
            "scope":scope,"name":name,"call":int(call),"duration_ms":float(ms)})
        if elapsed is not None and elapsed>=warmup:
            warm_callbacks.setdefault(key,[]).append(float(ms))
    for (scope,name),values in callbacks.items():
        result["callback_samples"].append({"scope":scope,"name":name,**distribution(values)})
    result["callback_samples"].sort(key=lambda v:v["mean_ms"]*v["samples"],reverse=True)
    for (scope,name),values in warm_callbacks.items():
        result["callback_samples_after_warmup"].append({"scope":scope,"name":name,**distribution(values)})
    result["callback_samples_after_warmup"].sort(key=lambda v:v["mean_ms"]*v["samples"],reverse=True)
    return result


def run(args: list[str], log: pathlib.Path, timeout: int, *,
        cwd: pathlib.Path | None = None, env: dict | None = None) -> dict:
    refuse_running_factorio()
    parent_session=windows_session_id()
    start = time.monotonic()
    with log.open("w", encoding="utf-8") as stream:
        proc = subprocess.Popen(args, stdout=stream, stderr=subprocess.STDOUT, cwd=cwd, env=env)
        try:
            child_session=windows_session_id(proc.pid)
            if child_session!=parent_session:
                raise RuntimeError("Native child did not remain in the launcher's Windows session")
            status=proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()  # Only the child created by this invocation.
            proc.wait()
            status=124
            stream.write("\nTP_OWNER_SAVE_TIMEOUT\n")
        except Exception:
            if proc.poll() is None:
                proc.kill()
            proc.wait()
            raise
    return {"exit_code":status,"wall_seconds":round(time.monotonic()-start,6),"log":log.name,
            "process_id":proc.pid,"launcher_session_id":parent_session,"native_session_id":child_session,
            "same_windows_session_verified":parent_session is not None and parent_session==child_session}


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


COMPLETION_COUNTERS = (
    "direct_deposited", "repair_complete", "consecration_complete",
    "entities_built", "emergency_transactions_complete",
    "machine_supply_complete", "machine_output_complete",
)


def behavior_summary(snapshots: list[dict], warmup: int) -> dict:
    """Separate movement/state observations from existing completion receipts."""
    result = {"observed": False, "moved_stations": [], "state_changed_stations": [],
              "station_chest_changes": [], "counter_deltas": {},
              "completion_receipts_observed": [], "counter_resets": [],
              "scope": "sampled movement, station chest only, and existing owner counters; "
                       "movement or state changes alone do not prove completed work"}
    if not snapshots:
        return result
    first, last = snapshots[0], snapshots[-1]
    result["observed"] = len(snapshots) > 1
    result["elapsed_ticks"] = [first["elapsed_ticks"], last["elapsed_ticks"]]
    start_pairs = {p["station"]: p for p in first.get("pairs", [])}
    moved, changed = set(), set()
    state_fields = ("mode", "task", "direct_phase", "repair_phase", "consecration_phase")
    for snapshot in snapshots[1:]:
        for pair in snapshot.get("pairs", []):
            before = start_pairs.get(pair["station"])
            if before:
                if pair.get("position") != before.get("position"):
                    moved.add(pair["station"])
                if any(pair.get(field) != before.get(field) for field in state_fields):
                    changed.add(pair["station"])
    result["moved_stations"] = sorted(moved)
    result["state_changed_stations"] = sorted(changed)
    for pair in last.get("pairs", []):
        before = start_pairs.get(pair["station"], {}).get("station_chest_items", {})
        after = pair.get("station_chest_items", {})
        for item in sorted(before.keys() & after.keys()):
            if before[item] != after[item]:
                result["station_chest_changes"].append({"station": pair["station"],
                    "item": item, "before": before[item], "after": after[item]})
    start_counters, end_counters = first.get("behavior_counters", {}), last.get("behavior_counters", {})
    for key in sorted(start_counters.keys() & end_counters.keys()):
        delta = end_counters[key] - start_counters[key]
        result["counter_deltas"][key] = delta
        if delta < 0:
            result["counter_resets"].append(key)
        elif key in COMPLETION_COUNTERS and delta > 0:
            result["completion_receipts_observed"].append(key)
    result["unavailable_counters"] = sorted(set(COMPLETION_COUNTERS) - result["counter_deltas"].keys())
    warm = next((s for s in snapshots if s["elapsed_ticks"] == warmup), None)
    if warm is not None:
        result["measured_window_counter_deltas"] = {
            key: end_counters[key] - value
            for key, value in warm.get("behavior_counters", {}).items()
            if key in end_counters
        }
    return result


def validate_observations(observed: dict, ticks: int, warmup: int, *, graphics: bool = False) -> tuple[bool, list[dict]]:
    phases=("start","sample","end") if graphics else ("start","sample")
    snapshots = [v for v in observed["observations"] if v.get("phase") in phases]
    expected = sorted({0, ticks - 1, warmup, *range(600, ticks, 600)})
    complete = bool(snapshots and snapshots[0].get("phase") == "start"
        and [s.get("elapsed_ticks") for s in snapshots] == expected
        and all(s.get("tick") == snapshots[0]["tick"] + s["elapsed_ticks"] for s in snapshots))
    if graphics:
        complete=bool(complete and snapshots[-1].get("phase")=="end"
            and snapshots[-1].get("observed_tick_count")==ticks
            and all(s.get("observed_tick_count")==s["elapsed_ticks"]+1
                    and s.get("observed_tick_sequence_valid") is True for s in snapshots)
            and all(s.get("phase")==("start" if i==0 else "end" if i==len(snapshots)-1 else "sample")
                    for i,s in enumerate(snapshots)))
    return complete, snapshots


def initial_fixture(report: dict) -> dict | None:
    observations = report.get("observed", {}).get("observations", [])
    loaded = [v for v in observations if v.get("phase") == "loaded"]
    starts = [v for v in observations if v.get("phase") == "start" and v.get("elapsed_ticks") == 0]
    if len(loaded) != 1 or len(starts) != 1:
        return None
    fields = ("station", "station_name", "priest", "priest_name", "position",
              "station_position", "surface_index", "force_index", "health")
    pairs = starts[0].get("pairs", [])
    if len(pairs) != 4 or any(any(key not in pair for key in fields) for pair in pairs):
        return None
    return {"loaded_tick": loaded[0]["tick"], "saved_pairs": loaded[0]["saved_pairs"],
            "reconstructed": starts[0]["reconstructed"],
            "connected_players": starts[0]["connected_players"],
            "pairs": [{key: pair[key] for key in fields} for pair in sorted(pairs, key=lambda p: p["station"])]}


def compare_reports(baseline: dict, candidate: dict) -> dict:
    """A valid comparison is not itself a performance or behavior acceptance."""
    fields = ("save_sha256", "engine_binary_sha256", "engine_version",
              "requested_ticks", "warmup_ticks", "graphical_benchmark",
              "callback_instrumentation", "reconstruction_requested",
              "tech_priests_version", "active_mods", "non_tech_priests_mods_sha256",
              "mod_settings_sha256", "observer_sha256", "worker_sha256", "benchmark_options",
              "run_provenance", "launch_method", "steam_app_id", "callback_sampling_policy",
              "process_session_id", "native_session_id", "graphics_backend", "graphics_renderer")
    result = {"schema": "tech-priests.owner-save-comparison.v1", "passed": False,
              "comparison_valid": False, "performance_acceptance": "not-evaluated",
              "scope": "matched instrumented diagnostic" if candidate.get("callback_instrumentation")
                       else "matched observer-equipped replay; callback profiling disabled",
              "mismatches": [], "matched_fields": [], "timings": {}}
    graphical=candidate.get("graphical_benchmark") is True
    if graphical:
        result["scope"]="matched graphical frame statistics; no game-tick correlation or scriptUpdate timing"
        result["frame_metrics"]={}
    for label, report in (("baseline", baseline), ("candidate", candidate)):
        if report.get("passed") is not True:
            result["mismatches"].append(label + ":replay-did-not-pass")
        if graphical:
            frames=report.get("graphical_frames",{})
            complete,_=validate_observations(report.get("observed",{"observations":[]}),
                report.get("requested_ticks",0),report.get("warmup_ticks",0),graphics=True)
            if not complete or report.get("four_pairs_verified") is not True:
                result["mismatches"].append(label+":incomplete-graphical-simulation-observations")
            if (not frames.get("csv_valid") or frames.get("measured_frame_count",0)<=0
                    or frames.get("measured_frame_count")!=frames.get("row_count",0)-frames.get("excluded_warmup_frames",0)):
                result["mismatches"].append(label+":incomplete-native-frame-evidence")
            if report.get("screenshot",{}).get("png_1600x1000") is not True:
                result["mismatches"].append(label+":missing-native-screenshot")
        elif report.get("observed", {}).get("per_tick_complete") is not True:
            result["mismatches"].append(label + ":incomplete-per-tick-evidence")
    for field in fields:
        if field not in baseline or field not in candidate or baseline[field] != candidate[field]:
            result["mismatches"].append(field)
        else:
            result["matched_fields"].append(field)
    provenance = baseline.get("run_provenance", {})
    result["same_run_and_runner_verified"] = bool(provenance.get("github_run_id")
        and provenance.get("runner_name") and provenance == candidate.get("run_provenance"))
    if not result["same_run_and_runner_verified"]:
        result["mismatches"].append("same-run-and-runner-provenance-unavailable")
    first, second = initial_fixture(baseline), initial_fixture(candidate)
    if first is None or second is None or first != second:
        result["mismatches"].append("initial-fixture-identities-and-positions")
    else:
        result["matched_fields"].append("initial-fixture-identities-and-positions")
    if graphical:
        first_frames,second_frames=(r.get("graphical_frames",{}) for r in (baseline,candidate))
        for field in ("raw_headers","excluded_warmup_frames","timing_units","unit_source"):
            if field not in first_frames or field not in second_frames or first_frames[field]!=second_frames[field]:
                result["mismatches"].append("graphical-frames:"+field)
            else:
                result["matched_fields"].append("graphical-frames:"+field)
        result["frame_sampling"]={"baseline_rows":first_frames.get("row_count"),
            "candidate_rows":second_frames.get("row_count"),"excluded_warmup_frames":first_frames.get("excluded_warmup_frames"),
            "frame_count_delta":second_frames.get("row_count",0)-first_frames.get("row_count",0),
            "timing_units":first_frames.get("timing_units"),"game_tick_correlation":"unavailable",
            "raw_csv_sha256":{"baseline":first_frames.get("file_sha256"),"candidate":second_frames.get("file_sha256")}}
        for name in FRAME_METRICS:
            a,b=first_frames.get("metrics",{}).get(name),second_frames.get("metrics",{}).get(name)
            if not a or not b or a.get("samples")!=first_frames.get("measured_frame_count") or b.get("samples")!=second_frames.get("measured_frame_count"):
                result["mismatches"].append(name+":incomplete-measured-frame-window")
                continue
            result["frame_metrics"][name]={metric:{"baseline":a[metric],"candidate":b[metric],
                "delta":b[metric]-a[metric],"reduction_percent":(a[metric]-b[metric])/a[metric]*100 if a[metric] else None}
                for metric in ("mean","p50","p95","p99","max")}
    before = baseline.get("observed", {}).get("timings", {})
    after = candidate.get("observed", {}).get("timings", {})
    for name in (() if graphical else ("wholeUpdate", "scriptUpdate")):
        a, b = before.get(name), after.get(name)
        if not a or not b or a.get("samples") != baseline.get("requested_ticks", 0) - baseline.get("warmup_ticks", 0) or b.get("samples") != candidate.get("requested_ticks", 0) - candidate.get("warmup_ticks", 0):
            result["mismatches"].append(name + ":incomplete-measured-window")
            continue
        result["timings"][name] = {}
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms", "over_16_667_ms", "over_50_ms", "over_100_ms"):
            result["timings"][name][metric] = {"baseline": a[metric], "candidate": b[metric],
                "delta": b[metric] - a[metric],
                "reduction_percent": (a[metric] - b[metric]) / a[metric] * 100 if a[metric] else None}
    result["behavior"] = {"baseline": baseline.get("behavior"), "candidate": candidate.get("behavior"),
        "interpretation": "completion counters and movement are observations, not an assertion of equivalent useful throughput"}
    result["tech_priests_source_digests"] = {"baseline": baseline.get("tech_priests_source_digest"),
                                           "candidate": candidate.get("tech_priests_source_digest")}
    result["source_changed"] = bool(baseline.get("tech_priests_source_digest")
        and candidate.get("tech_priests_source_digest")
        and baseline["tech_priests_source_digest"] != candidate["tech_priests_source_digest"])
    result["comparison_valid"] = not result["mismatches"]
    result["passed"] = result["comparison_valid"]
    return result


def compare_files(paths: list[pathlib.Path], output: pathlib.Path) -> int:
    output.mkdir(parents=True, exist_ok=False)
    result = {"schema": "tech-priests.owner-save-comparison.v1", "passed": False,
              "comparison_valid": False}
    try:
        resolved = [p / "profile-result.json" if p.is_dir() else p for p in paths]
        reports = [json.loads(p.read_text(encoding="utf-8")) for p in resolved]
        result = compare_reports(*reports)
        result["inputs"] = [{"path": str(p.resolve()), "sha256": digest(p)} for p in resolved]
    except Exception as exc:
        result.update(passed=False, comparison_valid=False, error=str(exc))
    packed = json.dumps(result, indent=2) + "\n"
    (output / "comparison-result.json").write_text(packed, encoding="utf-8")
    line = "TP_OWNER_SAVE_COMPARISON " + json.dumps(result)
    (output / "comparison.log").write_text(line + "\n", encoding="utf-8")
    print(line, flush=True)
    return 0 if result["passed"] else 1


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio",type=pathlib.Path)
    parser.add_argument("--save",type=pathlib.Path)
    parser.add_argument("--mods",type=pathlib.Path)
    parser.add_argument("--output",type=pathlib.Path,required=True)
    parser.add_argument("--compare",nargs=2,type=pathlib.Path,metavar=("BASELINE","CANDIDATE"),
        help="Compare two existing profile directories or JSON receipts; performs no replay")
    parser.add_argument("--ticks",type=int,default=6000)
    parser.add_argument("--warmup",type=int,default=600,
        help="Tick warmup for update benchmark; graphics excludes this many frame rows independently of game ticks")
    parser.add_argument("--timeout",type=int,default=1800)
    parser.add_argument("--deploy-four",action="store_true")
    parser.add_argument("--instrument-callbacks",action="store_true")
    parser.add_argument("--graphics",action="store_true",
        help="Use the actual graphical engine benchmark and capture the four stations during warmup")
    args=parser.parse_args()
    if args.compare:
        return compare_files(args.compare,args.output.resolve())
    if not all((args.factorio,args.save,args.mods)):
        parser.error("--factorio, --save and --mods are required for a replay")
    if not 0<=args.warmup<args.ticks:
        parser.error("warmup must be nonnegative and less than ticks")
    for field in ("factorio","save","mods","output"):
        setattr(args,field,getattr(args,field).resolve())
    args.output.mkdir(parents=True,exist_ok=False)
    report={"schema":"tech-priests.owner-save-profile.v1","passed":False,
            "save_sha256":digest(args.save),"requested_ticks":args.ticks,
            "warmup_ticks":args.warmup,
            "reconstruction_requested":args.deploy_four,
            "callback_instrumentation":args.instrument_callbacks,
            "graphical_benchmark":args.graphics,
            "script_scope":"unavailable in graphical frame CSV" if args.graphics else "whole-engine-all-installed-mods",
            "timing_evidence_scope":"native graphical frame CSV; no game-tick correlation" if args.graphics else "native per-game-tick update benchmark",
            "callback_scope":("all broker services and outer broker pulse, every listed dispatcher branch including 0519/0527/0529 wrappers and saved dispatcher delegates, 0644 locals, and registry nth-tick callbacks with interval at least 60 ticks; other owners one-in-32 including warmup; nested scopes overlap; diagnostic overhead present"
                              if args.instrument_callbacks else "disabled"),
            "callback_sampling_policy":callback_sampling_policy(args.instrument_callbacks),
            "graphics_backend":None,"graphics_renderer":None,
            "performance_scope":"observer-equipped replay; instrumented runs do not establish diagnostics-off production performance",
            "run_provenance":{"github_run_id":os.environ.get("GITHUB_RUN_ID"),
                "github_run_attempt":os.environ.get("GITHUB_RUN_ATTEMPT"),
                "worker_repository":os.environ.get("GITHUB_REPOSITORY"),
                "worker_repository_sha":os.environ.get("GITHUB_SHA"),
                "runner_name":os.environ.get("RUNNER_NAME"),"runner_os":os.environ.get("RUNNER_OS")},
            "commands":[]}
    try:
        refuse_running_factorio()
        report["process_session_id"]=windows_session_id()
        report["engine_binary_sha256"]=digest(args.factorio)
        report["worker_sha256"]=digest(pathlib.Path(__file__))
        report["harness_sha256"]=report["worker_sha256"]
        version_command=[str(args.factorio),"--version"]
        report["commands"].append(version_command)
        native=subprocess.run(version_command,capture_output=True,text=True,check=True,cwd=args.output,timeout=30)
        report["engine_version"]=(native.stdout+native.stderr).strip()
        launch_env=None
        report["launch_method"]="direct-native-executable"
        report["steam_app_id"]=None
        if args.graphics and re.search(r"\bsteam\b",report["engine_version"],re.IGNORECASE):
            # Valve's supported development launch path prevents Steam's
            # RestartAppIfNecessary from discarding these benchmark arguments.
            # Keep the native client/license checks; never edit the installation.
            (args.output/"steam_appid.txt").write_text("427520",encoding="ascii")
            launch_env=os.environ.copy()
            launch_env.update(SteamAppId="427520",SteamGameId="427520")
            report["launch_method"]="steam-native-job-local-appid-and-working-directory"
            report["steam_app_id"]=427520
        report["process_working_directory"]=str(args.output)
        mod=prepare_mods(args.mods,args.output/"mods")
        report["tech_priests_version"]=json.loads((mod/"info.json").read_text(encoding="utf-8"))["version"]
        report["non_tech_priests_mods_sha256"]={p.name:digest(p)
            for p in sorted((args.output/"mods").glob("*.zip"))}
        settings=args.output/"mods/mod-settings.dat"
        report["mod_settings_sha256"]=digest(settings) if settings.is_file() else None
        source_digest=hashlib.sha256()
        for path in sorted(p for p in mod.rglob("*") if p.is_file() and p.suffix in (".lua",".json",".cfg")):
            source_digest.update(path.relative_to(mod).as_posix().encode()+b"\0"+digest(path).encode()+b"\n")
        report["tech_priests_source_digest"]=source_digest.hexdigest()
        if args.instrument_callbacks:
            instrument_infrastructure_locals(mod)
        observer=(OBSERVER.replace("__DEPLOY_FOUR__",str(args.deploy_four).lower())
                  .replace("__INSTRUMENT__",str(args.instrument_callbacks).lower())
                  .replace("__GRAPHICS__",str(args.graphics).lower())
                  .replace("__TICKS__",str(args.ticks)).replace("__WARMUP__",str(args.warmup)))
        report["observer_sha256"]=hashlib.sha256(observer.encode()).hexdigest()
        with (mod/"control.lua").open("a",encoding="utf-8") as stream:
            stream.write(observer)
        save=args.output/"input-copy.zip"
        shutil.copy2(args.save,save)
        userdata=args.output/"user-data";userdata.mkdir()
        config=args.output/"config.ini"
        config.write_text("[path]\nread-data="+(args.factorio.parents[2]/"data").as_posix()
                          +"\nwrite-data="+userdata.as_posix()
                          +"\n[other]\ncheck-updates=false\n",encoding="utf-8")
        common=[str(args.factorio),"--config",str(config),"--mod-directory",str(args.output/"mods"),
                "--benchmark-graphics" if args.graphics else "--benchmark",str(save),
                "--benchmark-ticks",str(args.ticks),"--benchmark-runs","1"]
        frame_stats=args.output/"native-frame-stats.csv"
        if args.graphics:
            common += ["--window-size","1600x1000","--output-perf-stats",str(frame_stats)]
            common += list(WINDOWS_GRAPHICS_FLAGS) if os.name=="nt" else ["--disable-audio"]
        report["benchmark_options"]={"mode":"graphics" if args.graphics else "headless",
            "ticks":args.ticks,"runs":1,"verbose":"all",
            "window_size":"1600x1000" if args.graphics else None,"audio_disabled":args.graphics,
            "windows_graphics_flags":list(WINDOWS_GRAPHICS_FLAGS) if args.graphics and os.name=="nt" else [],
            "frame_warmup_rows":args.warmup if args.graphics else None,
            "graphical_stats_format":"native output-perf-stats CSV" if args.graphics else None,
            "screenshot_tick":300 if args.graphics else None,
            "screenshot_in_measured_window":None if args.graphics else False,
            "screenshot_frame_window":"unknown; no game-tick/frame correlation" if args.graphics else None}
        verbose=args.output/"benchmark-verbose.log"
        verbose_command=common+["--benchmark-verbose","all"]
        report["commands"].append(verbose_command)
        report["verbose_process"]=run(verbose_command,verbose,args.timeout,cwd=args.output,env=launch_env)
        native_bytes=verbose.read_bytes()
        content=native_bytes.decode("utf-8",errors="replace")
        if not args.graphics:
            report["native_log_captures"]=[{"file":verbose.name,**emit_native_log(native_bytes)}]
        report["observed"]=parse_log(content,args.ticks,args.warmup)
        exit_code=report["verbose_process"]["exit_code"]
        # Only the engine's previously observed verbose-output crash permits
        # a plain same-save retry. All other errors remain real failures.
        if (not args.graphics and exit_code!=0 and "Received SIGSEGV" in content
                and report["observed"]["engine_updates"]==args.ticks
                and "tick," in content and not report["observed"]["per_tick_complete"]):
            plain=args.output/"benchmark-plain.log"
            report["commands"].append(common)
            report["plain_process"]=run(common,plain,args.timeout,cwd=args.output,env=launch_env)
            report["observed_verbose_incomplete"]=report["observed"]
            native_bytes=plain.read_bytes()
            report["native_log_captures"].append({"file":plain.name,**emit_native_log(native_bytes)})
            content=native_bytes.decode("utf-8",errors="replace")
            report["observed"]=parse_log(content,args.ticks,args.warmup)
            exit_code=report["plain_process"]["exit_code"]
        active_process=report.get("plain_process",report["verbose_process"])
        report["native_session_id"]=active_process["native_session_id"]
        if args.graphics:
            raw_frames=frame_stats.read_bytes() if frame_stats.is_file() else b""
            report["graphical_frames"]=parse_frame_stats(raw_frames,args.warmup)
            if frame_stats.is_file():
                report["frame_csv_log_capture"]=emit_frame_csv(raw_frames)
        report["active_local_hooks"]=next((v["local_hook_names"]
            for v in report["observed"]["observations"] if v.get("phase")=="instrumentation-ready"),[])
        report["observation_complete"],snapshots=validate_observations(report["observed"],args.ticks,args.warmup,graphics=args.graphics)
        if args.graphics:
            report["observed_simulation_tick_count"]=snapshots[-1].get("observed_tick_count") if snapshots else None
        report["four_pairs_verified"]=bool(report["observation_complete"]
            and all(v.get("live_pairs")==4 and len(v.get("pairs",[]))==4 and v.get("identities_stable") is True for v in snapshots))
        loaded=[v for v in report["observed"]["observations"] if v.get("phase")=="loaded"]
        report["active_mods"]=loaded[0].get("mods") if len(loaded)==1 else None
        report["behavior"]=behavior_summary(snapshots,args.warmup)
        report["timing_evidence_complete"]=bool(report["observed"]["per_tick_complete"]
            and all(report["observed"]["timings"].get(name,{}).get("samples")==args.ticks-args.warmup
                    for name in ("wholeUpdate","scriptUpdate")))
        if args.graphics:
            report["timing_evidence_complete"]=bool(report["graphical_frames"]["csv_valid"]
                and report["graphical_frames"]["measured_frame_count"]>0)
        report["original_save_unchanged"]=digest(args.save)==report["save_sha256"]
        simulation_complete=(report["observed_simulation_tick_count"]==args.ticks and report["observation_complete"]
                             if args.graphics else report["observed"]["engine_updates"]==args.ticks)
        report["passed"]=bool(exit_code==0 and simulation_complete
            and report["original_save_unchanged"] and report["active_mods"]
            and report["four_pairs_verified"] and report["timing_evidence_complete"]
            and (not args.instrument_callbacks
                 or report["active_local_hooks"]==list(LOCAL_PROFILE_FUNCTIONS_0644)))
        report["isolated_handler_errors"]=len(re.findall(r"isolated handler failure",content))
        report["isolated_service_errors"]=len(re.findall(r"isolated service failure",content))
        report["native_checksums"]=[line.strip() for line in content.splitlines()
            if "Checksum of " in line or "Checksum for " in line or "Prototype list checksum" in line]
        report["runtime_error_lines"]=[line.strip() for line in content.splitlines()
            if "isolated handler failure" in line or "isolated service failure" in line
            or "Error while " in line or "stack traceback" in line]
        if report["runtime_error_lines"]:
            report["passed"] = False
        screenshot=userdata/"script-output/owner-profile/four-priests.png"
        if args.graphics:
            graphics=graphics_evidence(content)
            report["graphics_initialization_lines"]=graphics["initialization_lines"]
            report["graphics_backend"]=graphics["observed_backend"]
            report["graphics_renderer"]=graphics["renderer_identity"]
            if os.name=="nt" and (report["graphics_backend"]!="OpenGL"
                    or not active_process["same_windows_session_verified"]):
                report["passed"]=False
                report["graphics_context_error"]="Native OpenGL initialization in the launcher's session was not verified"
            report["screenshot"]={"exists":screenshot.is_file(),
                "sha256":digest(screenshot) if screenshot.is_file() else None}
            if not screenshot.is_file():
                report["passed"]=False
            else:
                pixels=screenshot.read_bytes()
                valid_png=(len(pixels)>=24 and pixels[:8]==b"\x89PNG\r\n\x1a\n"
                    and pixels[12:16]==b"IHDR" and int.from_bytes(pixels[16:20],"big")==1600
                    and int.from_bytes(pixels[20:24],"big")==1000)
                report["screenshot"]["png_1600x1000"]=valid_png
                if not valid_png:
                    report["passed"]=False
                encoded=base64.b64encode(pixels).decode("ascii")
                chunks=[encoded[i:i+16000] for i in range(0,len(encoded),16000)]
                for index,chunk in enumerate(chunks):
                    print("TP_OWNER_SCREENSHOT_PART "+json.dumps({"part":index,
                        "total":len(chunks),"sha256":report["screenshot"]["sha256"],
                        "data":chunk}),flush=True)
        for line in report["native_checksums"]:
            print("TP_OWNER_NATIVE_CHECKSUM "+line,flush=True)
        for line in report["runtime_error_lines"][:30]:
            print("TP_OWNER_RUNTIME_ERROR "+line,flush=True)
        for observation in report["observed"]["observations"]:
            print("TP_OWNER_SAVE_OBSERVATION "+json.dumps(observation),flush=True)
    except Exception as exc:
        report["passed"]=False
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
        "observation_complete":report.get("observation_complete"),
        "timing_evidence_complete":report.get("timing_evidence_complete"),
        "timing_evidence_scope":report.get("timing_evidence_scope"),
        "observed_simulation_tick_count":report.get("observed_simulation_tick_count"),
        "graphical_frames":report.get("graphical_frames"),
        "reconstruction_requested":args.deploy_four,"instrumented":args.instrument_callbacks,
        "engine_updates":observed.get("engine_updates"),
        "engine_mean_ms":observed.get("engine_mean_ms"),
        "engine_benchmark_ups":observed.get("engine_benchmark_ups"),
        "per_tick_complete":observed.get("per_tick_complete"),
        "timing_windows":observed.get("timing_windows",[]),
        "slowest_ticks":observed.get("slowest_ticks",[]),
        "slowest_warm_ticks":observed.get("slowest_warm_ticks",[]),
        "spike_evidence":observed.get("spike_evidence",{}),
        "callback_sampling_policy":report.get("callback_sampling_policy"),
        "native_session_id":report.get("native_session_id"),
        "graphics_backend":report.get("graphics_backend"),"graphics_renderer":report.get("graphics_renderer"),
        "behavior":report.get("behavior"),
        "timings":{k:v for k,v in observed.get("timings",{}).items()
                   if k in ("wholeUpdate","scriptUpdate","entityUpdate","pathFinder","turretTargetAcquisition","luaGarbageIncremental")},
        "top_callbacks":observed.get("callback_samples",[])[:20],
        "top_callbacks_after_warmup":observed.get("callback_samples_after_warmup",[])[:20]}),flush=True)
    return 0 if report["passed"] else 1


if __name__=="__main__":
    raise SystemExit(main())
