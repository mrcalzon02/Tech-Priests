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
