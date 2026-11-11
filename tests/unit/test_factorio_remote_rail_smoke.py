#!/usr/bin/env python3
"""Focused regression for the existing real-Factorio connected-rail gate.

Run with: python3 -m unittest discover -s tests/unit -p test_factorio_remote_rail_smoke.py
These string-verdict tests are NOT themselves native rail acceptance.
"""
import json
import pathlib
import sys
import tempfile
import unittest
import subprocess
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "tools"))
from run_factorio_isolated_service_scenario import (
    factorio_runtime_compatible, rail_connected_smoke_verdict,
    rail_smoke_evidence, reset_rail_smoke_diagnostics,
    run_rail_live_server, private_rail_server_settings,
    rail_native_player_test_command)
P = "[TP-REMOTE-RAIL-TEST] "
A = P + "PASS first physical rail built and exact stock debited"
B = P + "PASS two distinct 0338-debited native-connected rails"



class OriginalRailLiveAdmissionTraceTests(unittest.TestCase):
    def test_broker_plan_and_dispatcher_handoff_are_distinguished_without_ownership_changes(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        frontier = (root / "tech-priests_src/scripts/core/"
                    "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        dispatcher = (root / "tech-priests_src/scripts/core/"
                      "single_dispatcher_0510.lua").read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/"
                   "fixture.lua").read_text(encoding="utf-8")
        plan = frontier.split("local planned,reason=M.plan_next(pair)", 1)[1].split(
            "if planned~=true then", 1)[0]
        self.assertIn("m.last_plan_trace_0836={", plan)
        self.assertIn("reason=tostring(reason)", plan)
        self.assertIn("pending=m.pending_rail_0836~=nil", plan)
        self.assertIn("request=pair.construction_request~=nil", plan)
        self.assertIn(">=600", plan)
        self.assertNotIn("pair.construction_request=", plan)
        self.assertNotIn("pair.construction_candidate_0338=", plan)
        self.assertIn("rail_mission.last_dispatch_entry_tick_0510=now()", dispatcher)
        handoff = dispatcher.split("local pending=m and m.pending_rail_0836", 1)[1].split(
            "-- Record the EXACT canonical admission refusal", 1)[0]
        self.assertIn("m.last_frontier_dispatch_0510={", handoff)
        self.assertIn("active=active==true", handoff)
        self.assertIn("request_matches=pending~=nil", handoff)
        self.assertNotIn("pair.construction_request=", handoff)
        self.assertIn("RAIL_LIVE_ADMISSION elapsed=", fixture)
        self.assertIn("dispatcher_frontier_result=", fixture)
        self.assertIn("plan_result=", fixture)
        self.assertIn("RAIL_NATIVE_CUSTODY_NOT_CONSERVED", fixture)
        self.assertIn("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN", fixture)


class CanonicalFundedConstructionCandidateRefreshTests(unittest.TestCase):
    def test_unstarted_unfunded_bootstrap_cannot_hide_funded_prior_writ(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/"
                  "construction_planner.lua").read_text(encoding="utf-8")
        start = source.index("local function refresh_funded_prior_over_unfunded_bootstrap_0338")
        end = source.index("-- Discovery can run between the frontier", start)
        refresh = source[start:end]
        self.assertIn('candidate.request_field=="construction_bootstrap_ghost_0645"', refresh)
        self.assertIn('not source_for_item(pair,candidate.item_name)', refresh)
        for custody in (
            "pair.construction_task_0338", "pair.construction_custody_0338",
            "pair.robot_network_task_0338", "pair.robot_network_request_0338",
            "pair.construction_task",
        ):
            self.assertIn(custody, refresh)
        # Cached discovery does not own a move. An expired/persisted 0418
        # request must not permanently pin an unfunded 0338 candidate.
        # This does NOT cancel 0418 authority or admit a physical builder.
        self.assertNotIn("or pair.movement_request_0418", refresh)
        self.assertNotIn("pair.movement_request_0418=nil", refresh)
        self.assertNotIn("pair.construction_task_0338=", refresh)
        self.assertIn("pair.construction_candidate_0338=nil", refresh)
        self.assertIn('"structure_construction_requested_item"', refresh)
        self.assertIn('"construction_requested_item"', refresh)
        self.assertIn('placeable and source_for_item(pair,placeable.item_name)', refresh)
        self.assertIn('pair.construction_candidate_0338=nil', refresh)
        self.assertNotIn('pair.construction_requested_item=nil', refresh)
        self.assertNotIn('pair.structure_construction_requested_item=nil', refresh)
        self.assertNotIn('remove_item(', refresh)
        self.assertNotIn('insert_item(', refresh)
        self.assertNotIn('q.current=', refresh)
        self.assertIn('if refresh_funded_prior_over_unfunded_bootstrap_0338(pair) then force=true end', source)
        self.assertIn('  refresh_funded_prior_over_unfunded_bootstrap_0338(pair)\n  local c=', source)
        self.assertIn('local request=construction_request(pair);if not request', source)

class QueueOwnedOriginalRailYieldTests(unittest.TestCase):
    def test_exact_ammo_wait_only_preserves_0469_order_and_0338_custody(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        q = (root / "tech-priests_src/scripts/core/order_queue_0469.lua"
             ).read_text(encoding="utf-8")
        f = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
             ).read_text(encoding="utf-8")
        self.assertIn('function M.can_yield_uncommitted_rail_0836(p,request)', q)
        self.assertIn('o.source=="emergency_acquire"', q)
        self.assertIn('o.item=="firearm-magazine"', q)
        self.assertIn('and o.target==nil and o.request==nil', q)
        self.assertIn('and type(o.task)=="table" and o.task.type=="logistics"', q)
        self.assertIn('and o.task.item==o.item and tonumber(o.task.count)==1', q)
        self.assertIn('and o.task.target==nil and o.task.entity==nil', q)
        self.assertIn('not passive_supply_request_1038(p)', q)
        self.assertIn('p.construction_task_0338 or p.construction_custody_0338', q)
        self.assertIn('p.direct_acquisition_custody_0513', q)
        self.assertIn('p.movement_request_0418', q)
        self.assertNotIn('q.current=nil', q[q.index('function M.can_yield_uncommitted_rail_0836'):q.index('function M.can_pause_uncommitted_relay_0974')])
        self.assertIn('order_authority.can_yield_uncommitted_rail_0836', f)
        self.assertIn('not yielding and (pair.active_order_0469', f)
        self.assertIn('pair.rail_order_yield_observed_0836={', f)
        self.assertIn('return false,"original-magos-incumbent-duty"', f)


    def test_queue_owned_pre_writ_yield_is_limited_to_source_less_ammo(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        queue = (root / "tech-priests_src/scripts/core/order_queue_0469.lua"
                 ).read_text(encoding="utf-8")
        frontier = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                    ).read_text(encoding="utf-8")
        # No new queue owner or assignment mutation. A new rail writ may be
        # PLANNED only between actual segments, under the same full 0469
        # source-less automatic-ammo and physical-lease refusal predicate.
        pre = queue.split('if request==nil then', 1)[1].split(
            'elseif not (pending', 1)[0]
        self.assertIn('mission.root_station_unit==p.station.unit_number', pre)
        self.assertIn('mission.surface_index==p.station.surface.index', pre)
        self.assertIn('mission.force_index==p.station.force.index', pre)
        self.assertIn('mission.status=="starvation-confirmed"', pre)
        self.assertIn('mission.status=="building-physical-rail"', pre)
        self.assertIn('pending==nil and p.construction_request==nil', pre)
        for required in (
            'o.source=="emergency_acquire"',
            'o.item=="firearm-magazine"',
            'o.target==nil and o.request==nil',
            'not passive_supply_request_1038(p)',
            'p.construction_task_0338 or p.construction_custody_0338',
            'p.direct_acquisition_custody_0513',
            'p.movement_request_0418',
        ):
            self.assertIn(required, queue)
        self.assertIn('local original_request=pending and pending.request or nil',
                      frontier)
        self.assertIn('pair,original_request)', frontier)
        self.assertIn('not yielding and (pair.active_order_0469', frontier)
        self.assertIn('return false,"original-magos-incumbent-duty"', frontier)
        self.assertNotIn('q.current=nil', queue[queue.index(
            'function M.can_yield_uncommitted_rail_0836'
        ):queue.index('function M.can_pause_uncommitted_relay_0974')])


class CanonicalRailAdmissionRefusalTraceTests(unittest.TestCase):
    def test_pending_exact_rail_records_original_order_without_preemption(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        dispatcher = (root / "tech-priests_src/scripts/core/"
                      "single_dispatcher_0510.lua").read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/"
                   "fixture.lua").read_text(encoding="utf-8")
        self.assertIn('pair.construction_request==pending.request and not active', dispatcher)
        self.assertIn('pair.remote_rail_admission_refusal_0510={', dispatcher)
        self.assertIn('order_kind=safe(o and o.kind)', dispatcher)
        self.assertIn('order_source=safe(o and o.source)', dispatcher)
        self.assertIn('construction_custody=pair.construction_custody_0338~=nil', dispatcher)
        self.assertIn('movement_owner=safe(pair.movement_request_0418', dispatcher)
        self.assertIn('" rail_refusal="..tostring(refusal and refusal.reason)', fixture)
        self.assertIn('" order_kind="..tostring(order and order.kind)', fixture)
        self.assertIn('" order_queue_current="..tostring(queue and queue.current~=nil)', fixture)
        self.assertIn('RAIL_FIRST_ENGINE_CONSTRUCTION_NOT_PROVEN', fixture)
        self.assertIn('TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN', fixture)

class OriginalRailPhysicalCarryBatchTests(unittest.TestCase):
    def test_native_batch_cannot_bypass_single_rail_debit_or_original_identity(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        src = (root / "tech-priests_src/scripts/core/"
               "construction_planner.lua").read_text(encoding="utf-8")
        frontier = (root / "tech-priests_src/scripts/core/"
                    "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        self.assertIn('local function original_rail_cargo_0836(pair,item)', src)
        self.assertIn('pending.request==request', src)
        self.assertIn('held.priest_unit~=pair.priest.unit_number', src)
        self.assertIn('held.station_unit~=pair.station.unit_number', src)
        self.assertIn('held.inventory and held.inventory.valid', src)
        self.assertIn('if invalid then return nil', src)
        self.assertIn('game.create_inventory(1)', src)
        self.assertIn('pair.rail_material_cargo_0836=held', src)
        self.assertIn('removed=remove_item(source,"rail",amount)', src)
        self.assertIn('inserted=insert_item(inventory,"rail",removed)', src)
        self.assertIn('refunded~=uninserted', src)
        self.assertIn('held.quarantine="rail-stage-physical-custody-ambiguous"', src)
        self.assertIn('if not stage_original_rail_supply_0836(pair,task)', src)
        self.assertIn('removed=remove_item(task.source_inv,task.item_name,1)', src)
        self.assertIn('before-after==1', src)
        self.assertIn('pending.original_paid_completion_0836={', src)
        self.assertIn('connected_straight_rails(predecessor,actual)', frontier)
        self.assertNotIn('surface.create_entity{name="straight-rail"', frontier)

    def test_bounded_long_range_native_stack_reserves_original_source(self):
        src = (pathlib.Path(__file__).resolve().parents[2]
               / "tech-priests_src/scripts/core/construction_planner.lua"
               ).read_text(encoding="utf-8")
        self.assertIn('local stack_capacity=prototype and tonumber(prototype.stack_size) or 0', src)
        self.assertIn('local amount=math.min(100,math.max(0,before-1),math.max(0,stack_capacity))', src)
        self.assertIn('if item_count(existing.inventory,"rail")>0', src)
        self.assertIn('or task.source_inv==existing.inventory then return true end', src)
        self.assertIn('removed=remove_item(source,"rail",amount)', src)
        self.assertIn('local held_after=item_count(inventory,"rail")', src)
        self.assertIn('source_after~=before-removed+refunded', src)
        self.assertIn('held_after~=inserted or refunded~=uninserted', src)
        self.assertIn('removed~=inserted+refunded', src)
        self.assertIn('held.quarantine="rail-stage-physical-custody-ambiguous"', src)
        self.assertIn('before-after==1', src)


class NativePlayerTestSaveSelectionTests(unittest.TestCase):
    def test_native_headless_player_does_not_restart_graphical_steam_client(self):
        argv = rail_native_player_test_command(
            pathlib.Path("Factorio.exe"), pathlib.Path("physical-mods"),
            pathlib.Path("original-save.zip"), 36060)
        self.assertEqual(argv, ["Factorio.exe", "--mod-directory", "physical-mods",
                                "--test-save", "original-save.zip",
                                "--test-ticks", "36060"])
        self.assertNotIn("--mp-connect", argv)
        self.assertNotIn("--start-server", argv)
        self.assertNotIn("--benchmark", argv)

    def test_native_player_test_save_requires_actual_engine_receipts(self):
        base = dict(engine_version="2.1.24", required_series="2.1",
                    ticks_requested=36060, engine_mode="native-player-test-save")
        self.assertFalse(rail_smoke_evidence(0, 0, "Test ticks finished", **base)["accepted"])
        self.assertFalse(rail_smoke_evidence(0, 0, A, **base)["accepted"])
        self.assertFalse(rail_smoke_evidence(0, 1, A + "\n" + B, **base)["accepted"])
        self.assertFalse(rail_smoke_evidence(0, 0, A + "\n" + B + "\n" + P +
                                             "FAIL native graph", **base)["accepted"])
        accepted = rail_smoke_evidence(0, 0, A + "\n" + B, **base)
        self.assertTrue(accepted["accepted"])
        self.assertTrue(accepted["first_paid_rail"])
        self.assertTrue(accepted["native_connected_pair"])
        self.assertEqual(accepted["simulation_mode"], "native-player-test-save")

class RailRestockAndNativeCustodyBoundaryTests(unittest.TestCase):
    def test_original_hold_must_refill_from_native_source(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        src = (root / "tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        self.assertIn("local existing=pair.rail_material_cargo_0836", src)
        self.assertIn('if item_count(existing.inventory,"rail")>0', src)
        self.assertIn("or task.source_inv==existing.inventory then return true end", src)
        self.assertIn("local inventory=existing and existing.inventory or nil", src)
        self.assertIn("held.restock_cycles_0836=", src)
        self.assertIn('removed=remove_item(source,"rail",amount)', src)
        self.assertIn("held_after~=inserted or refunded~=uninserted", src)
    def test_native_census_checks_actual_persistent_lua_inventory(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        src = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        self.assertIn("local hold=p.rail_material_cargo_0836", src)
        self.assertIn('hold.inventory.get_item_count("rail")', src)
        self.assertIn("s.depot_entity=depot", src)
        self.assertIn("depot.unit_number==s.depot_unit", src)
        self.assertNotIn('surface.find_entity("steel-chest"', src)
        self.assertIn('if not units[frontier.built_units[i]]', src)
        self.assertIn("total==expected", src)
        self.assertIn("RAIL_NATIVE_CUSTODY_NOT_CONSERVED", src)
        self.assertIn("PASS original physical rail cargo and native segment census conserved", src)
        self.assertNotIn('surface.create_entity{name="straight-rail"', src)


class NativeRailSmokeVerdictTests(unittest.TestCase):
    def test_accept_both_native_receipts_only(self):
        self.assertTrue(rail_connected_smoke_verdict(0, A + "\n" + B))
    def test_reject_only_one_physical_rail(self):
        self.assertFalse(rail_connected_smoke_verdict(0, A))
    def test_reject_unpaid_claim(self):
        self.assertFalse(rail_connected_smoke_verdict(0, B))
    def test_reject_plan_or_ghost(self):
        self.assertFalse(rail_connected_smoke_verdict(0, "rail-segment-requested"))
    def test_reject_failed_or_timed_out_engine(self):
        self.assertFalse(rail_connected_smoke_verdict(1, A + "\n" + B))
        self.assertFalse(rail_connected_smoke_verdict(124, A + "\n" + B))
    def test_reject_fatal_fixture_even_with_both_receipts(self):
        self.assertFalse(rail_connected_smoke_verdict(0, A + "\n" + B + "\n" + P + "FAIL no train"))
    def test_reject_unprefixed_markers(self):
        self.assertFalse(rail_connected_smoke_verdict(0, A + "\n" + B.replace(P, "")))

class NativeRailPartialDiagnosticsTests(unittest.TestCase):
    def test_failed_save_creation_overwrites_stale_rail_proof(self):
        with tempfile.TemporaryDirectory() as root:
            output = pathlib.Path(root)
            stale = ("rail-connected-smoke-result.json", "benchmark.log",
                     "rail-loopback-client.log", "create.log", "scenario-initial.zip")
            for name in stale:
                (output / name).write_text("STALE PASS", encoding="utf-8")
            # Reset must not destroy unrelated fixture settings or logs.
            (output / "keep-this.json").write_text("keep", encoding="utf-8")
            reset_rail_smoke_diagnostics(output)
            for name in stale:
                self.assertFalse((output / name).exists(), name)
            self.assertEqual((output / "keep-this.json").read_text(
                encoding="utf-8"), "keep")
            evidence = rail_smoke_evidence(1, None, None, "2.1.24", "2.1", 36060)
            result = output / "rail-connected-smoke-result.json"
            result.write_text(json.dumps(evidence), encoding="utf-8")
            recovered = json.loads(result.read_text(encoding="utf-8"))
            self.assertEqual(recovered["failure_stage"], "create")
            self.assertIsNone(recovered["engine_exit_code"])
            self.assertIsNone(recovered["first_paid_rail"])
            self.assertIsNone(recovered["native_connected_pair"])
            self.assertIsNone(recovered["fixture_failed"])
            self.assertFalse(recovered["benchmark_attempted"])
            self.assertFalse(recovered["accepted"])

    def test_timed_out_benchmark_preserves_only_observed_first_rail(self):
        evidence = rail_smoke_evidence(0, 124, A, "2.1.24", "2.1", 36060)
        self.assertTrue(evidence["first_paid_rail"])
        self.assertFalse(evidence["native_connected_pair"])
        self.assertFalse(evidence["accepted"])
        self.assertEqual(evidence["failure_stage"], "benchmark")

    def test_complete_native_markers_retain_original_verdict(self):
        evidence = rail_smoke_evidence(0, 0, A + "\n" + B, "2.1.24", "2.1", 36060)
        self.assertTrue(evidence["accepted"])
        self.assertIsNone(evidence["failure_stage"])
        failed = rail_smoke_evidence(
            0, 0, A + "\n" + B + "\n" + P + "FAIL native graph",
            "2.1.24", "2.1", 36060)
        self.assertFalse(failed["accepted"])
        self.assertTrue(failed["fixture_failed"])

class NativeRailFixtureSyntaxTests(unittest.TestCase):
    def test_native_local_ore_refusal_filter_is_well_formed(self):
        # The Factorio 2.1.24 --create parser rejected an unclosed filter.
        # Keep both the closed Lua options table and the physical refusal.
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        compact = "".join(source.split())
        self.assertIn(
            'ifcount(surface,{type="resource",area={{-64,STATION.y-64},'
            '{64,STATION.y+64}}})~=0thenfail("UNEXPECTED_NEARBY_ORE")',
            compact)


class NativeRailNaturalOreAdmissionTests(unittest.TestCase):
    def test_generated_patch_on_a_rebased_even_latitude_remains_physical(self):
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        self.assertIn('find_natural_patch(-96,96)', source)
        self.assertIn('surface.request_to_generate_chunks({x=x,y=latitude},3)', source)
        self.assertIn('local origin={x=0,y=math.floor(e.position.y/2)*2}', source)
        self.assertIn('Frontier.required_segments_for_target(origin,e.position)', source)
        self.assertIn('s.station_y=STATION.y', source)
        self.assertIn('position={x=0,y=s.station_y or 0}', source)
        self.assertIn('area={{-64,STATION.y-64},{64,STATION.y+64}}', source)
        self.assertIn('NATURAL_ORE_SOURCE_DAMAGED_DURING_FIXTURE_ISOLATION', source)
        self.assertIn('NO_NATURALLY_GENERATED_EASTBOUND_IRON_PATCH', source)
        self.assertNotIn('surface.create_entity{name="iron-ore"', source)


class NativeRailDeferredChartAdmissionTests(unittest.TestCase):
    def test_live_broker_chart_request_requires_completed_native_chunk(self):
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        self.assertIn('CHART_PREPARED target_chunk=', source)
        self.assertIn('s.chart_target_chunk=target_chunk', source)
        self.assertIn('if elapsed>=60 and not s.chart_live_request_issued then', source)
        self.assertIn('surface.is_chunk_generated(target_chunk)', source)
        self.assertIn('force.chart(surface,{{target_chunk.x*32,target_chunk.y*32},', source)
        self.assertIn('{target_chunk.x*32+31,target_chunk.y*32+31}})', source)
        self.assertIn('s.chart_live_request_issued=true', source)
        self.assertIn('CHART_LIVE_REQUEST elapsed=', source)
        self.assertNotIn('force.chart_all(surface)', source)
        self.assertIn('if elapsed>=1800 and not s.chart_verified then', source)
        self.assertIn('station.force.is_chunk_charted(', source)
        self.assertIn('station.force.is_chunk_requested_for_charting(', source)
        self.assertIn('fail("REMOTE_ORE_NOT_CHARTED_AFTER_TICKS="', source)
        self.assertIn('s.chart_verified=true', source)
        self.assertLess(source.index('s.chart_target_chunk=target_chunk'),
                        source.index('s.started=game.tick'))
        self.assertGreater(source.index('if elapsed>=60 and not s.chart_live_request_issued'),
                           source.index('local function pulse()'))
        self.assertGreater(source.index('if elapsed>=1800 and not s.chart_verified'),
                           source.index('local function inspect(s,elapsed)'))
        self.assertNotIn('surface.create_entity{name="iron-ore"', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)


class NativeRailChartLifecycleDiagnosticsTests(unittest.TestCase):
    def test_native_chart_control_is_observed_without_bypassing_target_gate(self):
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        self.assertIn("s.chart_control_chunk={x=0,y=math.floor(STATION.y/32)}", source)
        self.assertIn("force.chart(surface,{{control.x*32,control.y*32},", source)
        self.assertIn("registry.on_event(defines.events.on_chunk_charted", source)
        self.assertIn('route="native-chart-observer"', source)
        self.assertIn("CHART_NATIVE_DIAG elapsed=", source)
        self.assertIn("events_target=", source)
        self.assertIn("events_control=", source)
        self.assertIn("target_raw_chart=", source)
        self.assertIn("control_raw_chart=", source)
        self.assertIn("connected_players=", source)
        self.assertIn("CHART_NATIVE_EVENT_OBSERVER registered=", source)
        self.assertLess(source.index("CHART_NATIVE_DIAG elapsed="),
                        source.index("for _,mark in ipairs({1800,9000,18000"))
        self.assertIn("if elapsed>=1800 and not s.chart_verified then", source)
        self.assertIn('fail("REMOTE_ORE_NOT_CHARTED_AFTER_TICKS="', source)
        self.assertNotIn("surface.create_entity{name=\"iron-ore\"", source)
        self.assertNotIn("surface.create_entity{name=\"straight-rail\"", source)


class NativeRailPoweredChartingTests(unittest.TestCase):
    def test_real_radar_and_solar_power_without_intelligence_bypass(self):
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        self.assertIn("seed_native_radar_chart_infrastructure", source)
        self.assertIn('entries={{name="radar",position=base}', source)
        self.assertIn('{name="substation",position={x=base.x+6,y=base.y}}', source)
        self.assertIn('entries[#entries+1]={name="solar-panel"', source)
        self.assertIn("surface.can_place_entity{", source)
        self.assertIn("surface.create_entity{", source)
        self.assertIn('count(surface,{type="resource",area=area})==0', source)
        self.assertIn('surface.daytime=0.85', source)
        self.assertNotIn("surface.freeze_daytime=true", source)
        self.assertIn('CHART_RADAR_NATIVE_DIAG elapsed=', source)
        self.assertIn('radar.energy', source)
        self.assertIn('radar.electric_network_id', source)
        self.assertIn('if elapsed>=1800 and not s.chart_verified then', source)
        self.assertIn('station.force.is_chunk_charted(', source)
        self.assertIn('fail("REMOTE_ORE_NOT_CHARTED_AFTER_TICKS="', source)
        self.assertNotIn('force.set_chunk_charted', source)
        self.assertNotIn('surface.create_entity{name="iron-ore"', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)

class NativeRailPhysicalSupplyCapacityTests(unittest.TestCase):
    def test_full_manifest_uses_real_seven_slot_station_and_nearby_depot(self):
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        self.assertIn('name="steel-chest",position={x=-8,y=STATION.y+8}', source)
        self.assertIn('local station_quantity=item[1]=="rail" and 600 or 0', source)
        self.assertIn('local depot_quantity=item[2]-station_quantity', source)
        self.assertIn('inventory.insert{name=item[1],count=station_quantity}', source)
        self.assertIn('depot_inventory.insert{name=item[1],count=depot_quantity}', source)
        self.assertIn('STATION_PRESTOCK_CAPACITY', source)
        self.assertIn('DEPOT_PRESTOCK_CAPACITY', source)
        self.assertIn('PHYSICAL_PRESTOCK_RECONCILIATION', source)
        self.assertIn('{"rail",700},{"locomotive",2},{"cargo-wagon",3}', source)
        self.assertIn('{"steel-chest",19}', source)
        self.assertIn('s.start_rail=inventory.get_item_count("rail")', source)
        self.assertIn('s.depot_unit=depot.unit_number', source)
        self.assertIn('s.start_rail-current_rail>=2', source)
        self.assertIn('neighbor==second', source)
        self.assertNotIn('inventory.resize(', source)
        self.assertNotIn('surface.create_entity{name="iron-ore"', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)


class NativeRailBlockedLocalMineAdmissionTests(unittest.TestCase):
    def test_original_0338_yields_only_identical_unplaceable_local_miner(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/construction_planner.lua").read_text(
            encoding="utf-8")
        self.assertIn("blocked_local_miner_yields_to_rail_0836(", source)
        self.assertIn('field=="construction_requested_item"', source)
        self.assertIn('refusal.field==field and refusal.request==value', source)
        self.assertIn('refusal.reason=="no-miner-site"', source)
        self.assertIn('at<=now() and now()-at<=600', source)
        self.assertIn('entity_type(item.entity_name)=="mining-drill"', source)
        self.assertIn("owned_pending_rail_0836(pair,rail)", source)
        self.assertIn('source_for_item(pair,"rail")~=nil', source)
        self.assertIn("or pair.construction_custody_0338", source)
        self.assertIn("or pair.robot_network_task_0338", source)
        self.assertIn("pair.construction_site_refusal_0338={", source)
        self.assertIn("field=request.field,request=request.value,reason=why", source)
        self.assertIn("pair.construction_site_refusal_0338=nil", source)
        self.assertIn('not (blocked_miner and field=="construction_requested_item")', source)
        self.assertIn("if remote~=nil then", source)
        self.assertNotIn("blocked_local_remote_site_yields_rail_0836", source)

    def test_native_fixture_retains_hard_rail_gate_and_reports_miner_owner(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(
            encoding="utf-8")
        for evidence in ("remote_drill_present=", "remote_drill_positioned=",
                         "blocked_site_field=", "blocked_site_reason=",
                         "blocked_site_matches_remote="):
            self.assertIn(evidence, source)
        self.assertIn('fail("RAIL_FIRST_ENGINE_CONSTRUCTION_NOT_PROVEN"', source)
        self.assertIn('fail("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN"', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)




class NativeRailDurablePaidReceiptTests(unittest.TestCase):
    def test_only_measured_engine_debit_and_exact_original_paid_build_are_retained(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/construction_planner.lua"
                  ).read_text(encoding="utf-8")
        self.assertIn("before=original_rail and item_count(task.source_inv,task.item_name)", source)
        self.assertIn("before-after==1", source)
        self.assertIn('M.abort_pair(pair,"rail-native-source-debit-unreconciled")', source)
        self.assertIn("pending.request==task.request_value", source)
        self.assertIn('task.request_field=="construction_request"', source)
        self.assertIn("task.creative_build~=true", source)
        self.assertIn("pending.original_paid_completion_0836={", source)
        self.assertIn("built_entity=built,built_unit=built.unit_number", source)
        self.assertIn("native_0338_paid=true", source)
        self.assertNotIn("pending.original_paid_completion_0836={\n    phase", source)

    def test_saved_receipt_requires_original_request_entity_and_counted_source(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                  ).read_text(encoding="utf-8")
        self.assertIn("saved.request_value==pending.request", source)
        self.assertIn("saved.native_0338_paid==true", source)
        self.assertIn("saved.source_before-saved.source_after==1", source)
        self.assertIn("saved.built_entity.unit_number==saved.built_unit", source)
        self.assertIn("if saved_matches then previous=saved end", source)
        self.assertIn("saved_matches and pair.construction_request~=pending.request", source)
        self.assertIn("local actual=track_at(pair,pending.position,pending.direction)", source)
        self.assertIn("if not (actual and actual==previous.built_entity)", source)
        self.assertIn("connected_straight_rails(predecessor,actual)", source)
        self.assertIn('return reject(m,"pending-original-rail-request-lost")', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)


class NativeRailFreshNativeLookupTests(unittest.TestCase):
    def test_index_lag_uses_real_bounded_native_entity_and_keeps_identity_gate(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        frontier = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                    ).read_text(encoding="utf-8")
        self.assertIn('surface.find_entities_filtered{', frontier)
        self.assertIn('name="straight-rail",position=point,radius=0.25', frontier)
        self.assertIn('if indexed then return indexed end', frontier)
        self.assertIn('if ok then return exact_native_rail(native) end', frontier)
        self.assertIn('and e.force==pair.station.force and e.surface==surface', frontier)
        self.assertIn('if not (actual and actual==previous.built_entity)', frontier)
        self.assertIn('return reject(m,"physical-rail-not-at-committed-site")', frontier)
        self.assertIn('connected_straight_rails(predecessor,actual)', frontier)
        self.assertIn('NATIVE_SITE_REFUSAL', frontier)
        self.assertNotIn('surface.create_entity{name="straight-rail"', frontier)


class NativeRailFirstLossCustodyTraceTests(unittest.TestCase):
    def test_exact_original_builder_captures_terminal_before_generic_clear(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/construction_planner.lua"
                  ).read_text(encoding="utf-8")
        trace = source.index("pending.original_terminal_trace_0836={")
        clear = source.index("if built then clear_request(pair,task)end", trace)
        self.assertLess(trace, clear)
        self.assertIn("pending.request==task.request_value", source[trace-650:trace])
        self.assertIn("source_readback=source_now", source[trace:trace+900])
        self.assertIn("request_owned_before_clear=", source[trace:trace+900])
        self.assertIn("original_rail_source_debit_0836", source)
        self.assertNotIn("pending.original_paid_completion_0836={\\n    phase", source)

    def test_first_lost_writ_is_fail_closed_and_censuses_real_depot_stock(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        frontier = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                    ).read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua"
                   ).read_text(encoding="utf-8")
        self.assertIn("if not pending.first_loss_snapshot_0836 then", frontier)
        self.assertIn("last_is_original=last and last.request_value==pending.request", frontier)
        self.assertIn('return reject(m,"pending-original-rail-request-lost")', frontier)
        self.assertIn('surface.find_entity("steel-chest",', fixture)
        self.assertIn('get_item_count("rail")', fixture)
        self.assertIn("RAIL_ORIGINAL_CUSTODY_DIAG elapsed=", fixture)
        self.assertIn('fail("RAIL_FIRST_ENGINE_CONSTRUCTION_NOT_PROVEN"', fixture)
        self.assertIn('fail("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN"', fixture)


class NativeRailTerminalReceiptHandoffTests(unittest.TestCase):
    def test_original_paid_rail_receipt_reconciled_before_0338_overwrites_it(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        builder = (root / "tech-priests_src/scripts/core/construction_planner.lua"
                   ).read_text(encoding="utf-8")
        frontier = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                    ).read_text(encoding="utf-8")
        receipt = builder.index("pair.construction_last_task_0338=task")
        handoff = builder.index(
            'if built and marked_rail_request_0836(task)',
            builder.index('record(pair,built and "built" or "aborted",reason)', receipt))
        self.assertLess(receipt, handoff)
        self.assertIn("pending.request==task.request_value", builder[handoff:handoff+700])
        self.assertIn('type(rail.verify_pending)=="function"', builder[handoff:handoff+700])
        self.assertIn("pcall(rail.verify_pending,pair)", builder[handoff:handoff+700])
        self.assertIn('physical-rail-reconciliation-refused-0836', builder)
        self.assertIn('previous.request_value==pending.request', frontier)
        self.assertIn('valid(previous.built_entity)', frontier)
        self.assertIn('previous.phase=="complete"', frontier)
        self.assertIn('and pair.construction_request==nil', frontier)
        self.assertIn('local actual=track_at(pair,pending.position,pending.direction)', frontier)
        self.assertIn('connected_straight_rails(predecessor,actual)', frontier)
        self.assertNotIn('surface.create_entity{name="straight-rail"', frontier)



class NativeRailUnfundedCandidateAdmissionTests(unittest.TestCase):
    def test_original_0338_only_yields_unfunded_unstarted_candidate(self):
        path = (pathlib.Path(__file__).resolve().parents[2]
                / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua")
        source = path.read_text(encoding="utf-8")
        self.assertIn("builder.yield_unfunded_frontier_candidate_0338,pair", source)
        self.assertIn("not (pair.construction_task_0338", source)
        self.assertIn("or pair.construction_custody_0338 or pair.construction_request", source)
        self.assertIn('return false,"other-physical-construction-active"', source)
        self.assertIn('return false,"rail-unfunded-candidate-yield-error"', source)
        self.assertNotIn("pair.construction_candidate_0338=nil", source)

    def test_existing_native_gate_reports_actual_admission_without_weakening_proof(self):
        fixture = (pathlib.Path(__file__).resolve().parents[2]
                   / "tests/scenarios/remote-rail-acquisition/fixture.lua")
        source = fixture.read_text(encoding="utf-8")
        self.assertIn("RAIL_ADMISSION_DIAG elapsed=", source)
        self.assertIn("authority.can_yield_uncommitted_rail_0836,p,pending.request", source)
        self.assertIn("queue_yield_allowed=", source)
        self.assertIn("queue_yield_reason=", source)
        self.assertIn("active_supply_source=", source)
        self.assertIn("active_supply_target=", source)
        for key in ("request_matches=", "candidate=", "builder_phase=",
                    "active_task=", "current_task=", "machine_custody=",
                    "last_builder_detail=", "source_rail="):
            self.assertIn(key, source)
        self.assertIn('fail("RAIL_FIRST_ENGINE_CONSTRUCTION_NOT_PROVEN"', source)
        self.assertIn('fail("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN"', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)


class FactorioRuntimeCompatibilityTests(unittest.TestCase):
    def test_current_21_mod_accepts_matching_native_engine(self):
        self.assertTrue(factorio_runtime_compatible(
            "Version: 2.1.24 (build 99999, linux64)", "2.1"))

    def test_current_21_mod_rejects_archived_2077_engine(self):
        self.assertFalse(factorio_runtime_compatible(
            "Version: 2.0.77 (build 99999, linux64)", "2.1"))

    def test_archived_20_mod_retains_exact_2077_pin(self):
        self.assertTrue(factorio_runtime_compatible(
            "Version: 2.0.77 (build 99999, linux64)", "2.0"))
        self.assertFalse(factorio_runtime_compatible(
            "Version: 2.0.78 (build 99999, linux64)", "2.0"))
        self.assertFalse(factorio_runtime_compatible(
            "Version: 2.1.24 (build 99999, linux64)", "2.0"))

    def test_invalid_or_future_engine_version_fails_closed(self):
        for observed, target in (
            ("", "2.1"), ("Version: 2.1", "2.1"),
            ("Version: 2.2.0", "2.1"),
            ("Version: 2.1.24", "3.0"),
        ):
            self.assertFalse(factorio_runtime_compatible(observed, target))


class NativeRailPrewritAdmissionTraceTests(unittest.TestCase):
    def test_native_60k_stall_samples_actual_nil_request_0469_gate_read_only(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        fixture = (root / "tests/scenarios/remote-rail-acquisition/"
                   "fixture.lua").read_text(encoding="utf-8")
        queue = (root / "tech-priests_src/scripts/core/"
                 "order_queue_0469.lua").read_text(encoding="utf-8")
        self.assertIn("local function trace_uncommitted_rail_gap(s,elapsed)", fixture)
        self.assertIn("if elapsed>=36000 and elapsed<=60000 and elapsed%600==0 then", fixture)
        self.assertIn("trace_uncommitted_rail_gap(s,elapsed)", fixture)
        self.assertIn("RAIL_PREWRIT_GAP elapsed=", fixture)
        self.assertIn("queue_reason=", fixture)
        self.assertIn("prewrite_refusal=", fixture)
        self.assertIn("generic_construction_task=", fixture)
        frontier = (root / "tech-priests_src/scripts/core/"
                    "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        self.assertIn("local ok,yielded,reason=pcall(", frontier)
        self.assertIn("if yielded~=true then", frontier)
        self.assertIn('"rail-unfunded-candidate-yield-refused:"..tostring(reason)', frontier)
        self.assertIn("m.last_prewrite_refusal_0836", frontier)
        self.assertIn("local planned,reason=M.plan_next(pair)", frontier)
        self.assertIn("return planned,reason", frontier)
        self.assertIn("queue_gate=", fixture)
        self.assertIn("candidate_station_count=", fixture)
        self.assertIn("active_order_matches=", fixture)
        self.assertIn("move_owner=", fixture)
        self.assertIn("candidate_field=", fixture)
        self.assertIn("local request=pending and pending.request or nil", fixture)
        self.assertIn("authority.can_yield_uncommitted_rail_0836,p,request", fixture)
        self.assertIn("function M.can_yield_uncommitted_rail_0836(p,request)", queue)
        sampler = fixture.split("local function trace_uncommitted_rail_gap", 1)[1].split(
            "local function inspect(s,elapsed)", 1)[0]
        self.assertNotIn("pair.construction_request=", sampler)
        self.assertNotIn("p.construction_request=", sampler)
        self.assertNotIn("construction_candidate_0338=nil", sampler)
        self.assertNotIn("yield_unfunded_frontier_candidate_0338", sampler)
        self.assertNotIn("surface.create_entity", sampler)
        self.assertIn("RAIL_PREWRIT_0338_OWNER elapsed=", fixture)
        for field in ("prior_item=", "prior_depot_stock=",
                      "refused_matches_prior=", "robot_task_phase=",
                      "candidate_matches_prior=", "cooldown_remaining=",
                      "builder_last_result="):
            self.assertIn(field, fixture)
        trace = fixture.split("RAIL_PREWRIT_0338_OWNER elapsed=", 1)[1].split(
            "local function inspect(s,elapsed)", 1)[0]
        for forbidden in ("p.construction_candidate_0338=nil",
                          "p.construction_requested_item=nil",
                          "p.construction_request=", "surface.create_entity",
                          "game.create_inventory",
                          "p.robot_network_task_0338=nil"):
            self.assertNotIn(forbidden, trace)
        self.assertIn("RAIL_NATIVE_CUSTODY_NOT_CONSERVED", fixture)
        self.assertIn("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN", fixture)

    def test_prewrite_incumbent_receipt_is_bounded_and_cannot_release_custody(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        frontier = (root / "tech-priests_src/scripts/core/"
                    "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/"
                   "fixture.lua").read_text(encoding="utf-8")
        block = frontier.split("function M.service_pair(pair)", 1)[1].split(
            "function M.verify_pending(", 1)[0] if False else frontier.split(
                "function M.service_pair(pair)", 1)[1]
        self.assertIn("last_service_sample_tick_0836", block)
        self.assertIn("last_incumbent_refusal_0836", block)
        self.assertIn('or pair.inventory_transfer_custody_0687 and "0687-transfer-custody"', block)
        self.assertIn('or pair.construction_task_0340 and "0340-construction-task"', block)
        self.assertIn('return false,"original-magos-incumbent-duty"', block)
        for receipt in ("live_incumbent_owner=", "live_incumbent_tick=",
                        "last_0836_service_tick=", "last_0836_service_pending=",
                        "transfer_custody_0687=", "construction_task_0340=",
                        "active_acquisition_0333=", "direct_task_0336="):
            self.assertIn(receipt, fixture)
        sampler = fixture.split("local function trace_uncommitted_rail_gap", 1)[1].split(
            "local function inspect(s,elapsed)", 1)[0]
        for forbidden in ("p.inventory_transfer_custody_0687=nil",
                          "p.construction_task_0340=nil",
                          "p.construction_request=", "surface.create_entity",
                          "game.create_inventory"):
            self.assertNotIn(forbidden, sampler)


if __name__ == "__main__":
    unittest.main()


class NativeRailLiveServerTests(unittest.TestCase):
    def test_gate_receipts_stop_live_process_without_faking_clean_exit(self):
        with tempfile.TemporaryDirectory() as dirname:
            log = pathlib.Path(dirname) / "native-server.log"
            command = [sys.executable, "-u", "-c",
                       "import time; print(" + repr(A + "\\n" + B) +
                       ", flush=True); time.sleep(20)"]
            code, reason = run_rail_live_server(
                command, log, timeout=5, poll_interval=0.05)
            self.assertEqual(reason, "native_gate_observed")
            self.assertNotEqual(code, 0)  # Driver terminated the live process.
            contents = log.read_text(encoding="utf-8")
            evidence = rail_smoke_evidence(
                0, code, contents, "2.1.24", "2.1", 36060,
                engine_mode="live-headless-server", driver_stop_reason=reason)
            self.assertTrue(evidence["accepted"])
            self.assertEqual(evidence["engine_exit_code"], code)
            self.assertEqual(evidence["simulation_mode"], "live-headless-server")

    def test_fixture_failure_retains_partial_server_diagnostics(self):
        with tempfile.TemporaryDirectory() as dirname:
            log = pathlib.Path(dirname) / "native-server.log"
            command = [sys.executable, "-u", "-c",
                       "import time; print(" + repr(P + "FAIL chart_pending") +
                       ", flush=True); time.sleep(20)"]
            code, reason = run_rail_live_server(
                command, log, timeout=5, poll_interval=0.05)
            self.assertEqual(reason, "fixture_failure")
            evidence = rail_smoke_evidence(
                0, code, log.read_text(encoding="utf-8"),
                "2.1.24", "2.1", 36060, engine_mode="live-headless-server",
                driver_stop_reason=reason)
            self.assertFalse(evidence["accepted"])
            self.assertTrue(evidence["fixture_failed"])

    def test_server_settings_private_and_unpaused_without_rcon(self):
        with tempfile.TemporaryDirectory() as dirname:
            cfg = json.loads(private_rail_server_settings(
                pathlib.Path(dirname)).read_text(encoding="utf-8"))
            self.assertEqual(cfg["visibility"], {"public": False, "lan": False})
            self.assertTrue(cfg["auto_pause"])  # Real connected client required.
            self.assertNotIn("token", cfg)
            self.assertNotIn("rcon_port", cfg)

    def test_server_gate_requires_explicit_driver_receipt(self):
        content = A + "\\n" + B
        proof = rail_smoke_evidence(
            0, 1, content, "2.1.24", "2.1", 36060,
            engine_mode="live-headless-server",
            driver_stop_reason="unexpected_server_exit")
        self.assertFalse(proof["accepted"])
        failure = rail_smoke_evidence(
            0, 1, content + "\\n" + P + "FAIL native_disconnected",
            "2.1.24", "2.1", 36060, engine_mode="live-headless-server",
            driver_stop_reason="native_gate_observed")
        self.assertFalse(failure["accepted"])

    def test_real_local_client_launches_once_after_private_server_host(self):
        with tempfile.TemporaryDirectory() as dirname:
            root = pathlib.Path(dirname)
            server_log, client_log = root / "server.log", root / "client.log"
            host = ("import time; "
                    "print('Hosting game at IP ADDR:({127.0.0.1:61670})', flush=True); "
                    "time.sleep(0.8); "
                    "print('[TP-REMOTE-RAIL-TEST] FAIL pending_chart', flush=True); "
                    "time.sleep(10)")
            client = ("import time; print('CLIENT_PROCESS_STARTED', flush=True); "
                      "time.sleep(10)")
            code, reason = run_rail_live_server(
                [sys.executable, "-u", "-c", host], server_log, timeout=5,
                poll_interval=0.02,
                client_argv=[sys.executable, "-u", "-c", client],
                client_log_file=client_log)
            self.assertEqual(reason, "fixture_failure")
            self.assertNotEqual(code, 0)
            self.assertIn("CLIENT_PROCESS_STARTED",
                          client_log.read_text(encoding="utf-8"))
            self.assertNotIn("PASS two distinct",
                             server_log.read_text(encoding="utf-8"))

    def test_does_not_launch_client_if_native_server_never_hosts(self):
        with tempfile.TemporaryDirectory() as dirname:
            root = pathlib.Path(dirname)
            server_log, client_log = root / "server.log", root / "client.log"
            code, reason = run_rail_live_server(
                [sys.executable, "-u", "-c",
                 "print('[TP-REMOTE-RAIL-TEST] FAIL host_absent', flush=True)"],
                server_log, timeout=5, poll_interval=0.02,
                client_argv=[sys.executable, "-u", "-c",
                             "print('NEVER_START')"],
                client_log_file=client_log)
            self.assertEqual(reason, "fixture_failure")
            self.assertEqual(client_log.read_text(encoding="utf-8"),
                             "CLIENT_NOT_LAUNCHED_NO_HOST\n")
            self.assertNotEqual(code, 0)


class NativeRailOriginalGuardPredicateTests(unittest.TestCase):
    def test_first_original_paid_completion_refusal_records_geometry_and_custody(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                  ).read_text(encoding="utf-8")
        diagnostic = source.index("ORIGINAL_GUARD_REFUSAL")
        guard = source.index('if not(previous and previous.request_value==pending.request')
        rejection = source.index('return reject(m,"pending-original-rail-request-lost")')
        self.assertLess(guard, diagnostic)
        self.assertLess(diagnostic, rejection)
        for predicate in (
            "built_valid=", "built_unit=", "built_name=", "built_direction=",
            "position_matches=", "direction_matches=", "name_matches=",
            "request_cleared=", "same_force=", "same_surface=",
            "native_at_requested_unit=", "original_debit_before=",
            "original_debit_after=",
        ):
            self.assertIn(predicate, source[guard:rejection])
        self.assertIn("pending.original_guard_refusal_0836={", source)
        self.assertIn("native=track_at(pair,pending.position,pending.direction)", source)
        self.assertIn('if not pending.original_guard_refusal_0836', source)
        self.assertIn('if not (actual and actual==previous.built_entity)', source)
        self.assertIn('connected_straight_rails(predecessor,actual)', source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)



class NativeRailOriginalContactAuthorityTests(unittest.TestCase):
    def test_0574_only_accepts_next_physically_paid_original_rail_contact(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        frontier = (root / "tech-priests_src/scripts/core/"
                    "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        corridor = (root / "tech-priests_src/scripts/core/"
                    "authority_corridor_pathing_0574.lua").read_text(encoding="utf-8")
        predicate = frontier.split(
            "function M.authorized_paid_rail_contact_0836", 1)[1].split(
            "local function reject(objective,reason)", 1)[0]
        for guard in ('reason~="construction-site-standoff-0338"',
                      'opts.owner=="construction-planner-0338"',
                      'mission.status~="building-physical-rail"',
                      'pair.construction_request~=pending.request',
                      'task.request_value~=pending.request',
                      'task.phase~="move-site"',
                      'task.carried.count==1',
                      'task.source_inv and task.source_inv.valid',
                      'debit.before-debit.after~=1',
                      'pending.segment~=route.segment+1',
                      '#route.built_units~=route.segment',
                      'last.unit_number==route.built_units[route.segment]',
                      'connected_straight_rails(before,last)',
                      'site_dx*site_dx+site_dy*site_dy>9',
                      'dx*dx+dy*dy>25'):
            self.assertIn(guard, predicate)
        self.assertIn('frontier.authorized_paid_rail_contact_0836,pair,pos,reason,opts',
                      corridor)
        self.assertIn('if checked and authorized==true then', corridor)
        self.assertIn('role="physical-original-rail-0836"', corridor)
        self.assertIn('or rec.role == "physical-original-rail-0836"', corridor)
        self.assertIn('return false, best, source', corridor)
        self.assertNotIn('surface.create_entity', predicate)
        self.assertNotIn('bounds_exempt', predicate)

    def test_0566_preserves_only_active_exact_rail_contact_and_normal_safety(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        movement = (root / "tech-priests_src/scripts/core/"
                    "movement_controller.lua").read_text(encoding="utf-8")
        enforce = movement.split("function M.enforce_pair(pair, reason)", 1)[1]
        permitted = enforce.split(
            'return false,"original-paid-rail-contact-owned-0836"', 1)[0]
        self.assertIn('request.owner=="construction-planner-0338"', permitted)
        self.assertIn('request.reason=="construction-site-standoff-0338"', permitted)
        self.assertIn(
            'frontier.authorized_paid_rail_contact_0836,pair,', permitted)
        self.assertIn('pair.priest.position,request.reason,{owner=request.owner}',
                      permitted)
        self.assertIn('if checked and authorized==true then', permitted)
        self.assertIn('M.stop(pair, "movement-overleash-0566")', enforce)
        self.assertIn('M.request(pair, pair.station.position,', enforce)
        self.assertIn('return moved == true, "overleash-return"', enforce)


class NativeRailGridAlignedConstructionTests(unittest.TestCase):
    def test_original_request_uses_factorio_native_center_and_unchanged_physical_gates(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                  ).read_text(encoding="utf-8")
        self.assertIn("local function native_first_rail_center(start)", source)
        self.assertIn("start.x+M.start_offset+1,math.floor(start.y/2)*2+1", source)
        self.assertIn("local first=native_first_rail_center(start)", source)
        self.assertIn("start_position=native_first_rail_center(start)", source)
        self.assertIn("local forward=target.x-first.x", source)
        self.assertIn("local lateral=math.abs(target.y-first.y)", source)
        self.assertIn("(forward-x_clearance)/M.segment_step", source)
        self.assertIn("and close(previous.built_entity.position,pending.position)", source)
        self.assertIn("and previous.built_entity.direction==pending.direction", source)
        self.assertIn("source_before-saved.source_after==1", source)
        self.assertIn("if not (actual and actual==previous.built_entity)", source)
        self.assertIn("connected_straight_rails(predecessor,actual)", source)
        self.assertNotIn('surface.create_entity{name="straight-rail"', source)


class NativeRailExtendedCustodyCheckpointTests(unittest.TestCase):
    def test_60k_smoke_continues_real_rail_custody_without_relaxing_36k_gate(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        fixture = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        runner = (root / "tools/run_factorio_isolated_service_scenario.py").read_text(encoding="utf-8")
        self.assertIn('60060 if args.rail_connected_smoke else scenario["ticks"]', runner)
        self.assertIn('if args.rail_connected_smoke and not 36060 <= tick_count < 90000:', runner)
        self.assertIn('for _,mark in ipairs({1800,9000,18000,36000,60000,90000})', fixture)
        self.assertIn('if elapsed>=36000 then', fixture)
        self.assertNotIn('if elapsed>=36000 and not s.rail_custody_verified then', fixture)
        self.assertIn('if not s.rail_custody_verified then', fixture)
        self.assertIn('total==expected', fixture)
        self.assertIn('RAIL_NATIVE_CUSTODY_NOT_CONSERVED', fixture)
        self.assertIn('RAIL_LINE_NEVER_REACHED_REMOTE_PATCH', fixture)
        self.assertIn('TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN', fixture)
        self.assertIn('"train_and_ore_delivery_accepted": False', runner)
