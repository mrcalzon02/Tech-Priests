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
    rail_smoke_evidence, original_rail_native_refusals, reset_rail_smoke_diagnostics,
    run_rail_live_server, private_rail_server_settings,
    rail_native_player_test_command)
P = "[TP-REMOTE-RAIL-TEST] "
A = P + "PASS first physical rail built and exact stock debited"
B = P + "PASS two distinct 0338-debited native-connected rails"



class OriginalNativeRailFailureRetentionTests(unittest.TestCase):
    def test_genuine_0469_0836_0338_refusals_are_retained_without_rail_credit(self):
        log = "\n".join([
            P + "RAIL_ADMISSION_DIAG elapsed=1800 queue_yield_reason=0527-occupied",
            P + "RAIL_ADMISSION_DIAG elapsed=9000 queue_yield_reason=foreign-custody",
            P + "RAIL_ADMISSION_DIAG elapsed=18000 queue_yield_reason=live-duty",
            P + "RAIL_LIVE_ADMISSION elapsed=9000 plan_result=rail-unadmitted",
            P + "RAIL_PREWRIT_GAP elapsed=36000 queue_reason=active",
            P + "RAIL_PREWRIT_0338_OWNER elapsed=36000 builder_phase=nil",
            P + "RAIL_ORIGINAL_CUSTODY_DIAG elapsed=36000 station_rail=600",
            P + "FAIL no-native-connected-original-rail",
            "OTHER FIXTURE RAIL_ADMISSION_DIAG unrelated",
        ])
        data = original_rail_native_refusals(log)
        self.assertEqual(data["native_first_fixture_failure"],
                         "FAIL no-native-connected-original-rail")
        samples = data["native_admission_refusal_receipts"]
        self.assertEqual(len(samples["RAIL_ADMISSION_DIAG"]), 2)
        self.assertIn("elapsed=9000", samples["RAIL_ADMISSION_DIAG"][0])
        self.assertIn("elapsed=18000", samples["RAIL_ADMISSION_DIAG"][1])
        self.assertEqual(len(samples), 5)
        result = rail_smoke_evidence(
            0, 1, log, "Factorio 2.1.24", "2.1", 36060,
            engine_mode="native-player-test-save",
            create_process_wall_minutes=0.075,
            test_process_wall_minutes=2.345)
        self.assertFalse(result["accepted"])
        self.assertTrue(result["fixture_failed"])
        self.assertEqual(result["native_factorio_process_wall_minutes"], 2.42)
        self.assertEqual(result["native_admission_refusal_receipts"], samples)
        self.assertNotIn("OTHER FIXTURE", repr(samples))

    def test_absent_native_process_and_unobserved_receipts_stay_unmeasured(self):
        partial = rail_smoke_evidence(
            1, None, "", "Factorio 2.1.24", "2.1", 36060,
            create_process_wall_minutes=0.1)
        self.assertIsNone(partial["native_test_process_wall_minutes"])
        self.assertIsNone(partial["native_factorio_process_wall_minutes"])
        self.assertIsNone(partial["native_first_fixture_failure"])
        self.assertEqual(partial["native_admission_refusal_receipts"], {})
        self.assertFalse(partial["accepted"])

    def test_authentic_rail_success_unchanged_by_diagnostics_and_timing(self):
        result = rail_smoke_evidence(
            0, 0, A + "\n" + B, "Factorio 2.1.24", "2.1", 36060,
            engine_mode="native-player-test-save",
            create_process_wall_minutes=0.08,
            test_process_wall_minutes=3.1)
        self.assertTrue(result["accepted"])
        self.assertEqual(result["native_factorio_process_wall_minutes"], 3.18)
        self.assertEqual(result["native_admission_refusal_receipts"], {})



class OriginalRailItemFamilyAdmissionTests(unittest.TestCase):
    def test_live_original_0835_expedition_defers_only_new_0702_work(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/"
                  "item_family_logistics_0702.lua").read_text(encoding="utf-8")
        guard = source.split(
            "local function original_rail_expedition_reserved_0836(pair)", 1
        )[1].split("local function pause_unladen_item_family_for_rail_0836(pair,task)", 1)[0]
        discover = source.split("local function discover_pair(pair)", 1)[1].split(
            "local function request_move(", 1)[0]
        service = source.split("function M.service_pair(pair, reason)", 1)[1].split(
            "local function action_target(", 1)[0]
        self.assertIn('mission.status=="starvation-confirmed"', guard)
        self.assertIn('mission.status=="rail-track-established"', guard)
        self.assertIn('mission.status=="building-physical-rail"', guard)
        self.assertIn('mission.root_station_unit==station_unit(pair)', guard)
        self.assertIn('mission.surface_index==pair.station.surface.index', guard)
        self.assertIn('mission.force_index==pair.station.force.index', guard)
        self.assertIn('valid(pair.combat_target)', guard)
        self.assertIn('mission.resource_unit', guard)
        # Genuine natural ore entities need not have a Factorio unit_number.
        # The original charted prototype/coordinates and rail mission must
        # still be owned by the exact registered Magos before yielding 0702.
        self.assertIn('mission.resource_unit==nil or type(mission.resource_unit)=="number"', guard)
        self.assertIn('mission.resource_name==mission.item', guard)
        self.assertIn('type(mission.target.x)=="number"', guard)
        self.assertIn('type(mission.target.y)=="number"', guard)
        self.assertNotIn('and type(mission.resource_unit)=="number"', guard)
        self.assertIn('back.phase=="native-original-home-arrived-after-roundtrip"', guard)
        self.assertNotIn("pair.item_family_logistics_0702=", guard)
        self.assertNotIn("pair.item_family_custody_0702=", guard)
        self.assertNotIn("controller.stop", guard)
        self.assertNotIn("request_move", guard)
        self.assertNotIn("remove_inventory", guard)
        self.assertIn('if original_rail_expedition_reserved_0836(pair) then', discover)
        self.assertIn('if original_rail_expedition_reserved_0836(pair) then', service)
        self.assertLess(service.index("return continue_task(pair,task)"),
                        service.rindex('if original_rail_expedition_reserved_0836(pair) then'))
        self.assertLess(service.index("if reversal_future_worker_reserved_0962(pair) then"),
                        service.rindex('if original_rail_expedition_reserved_0836(pair) then'))
        self.assertLess(service.rindex('if original_rail_expedition_reserved_0836(pair) then'),
                        service.index("return begin_task(pair, candidate"))
        self.assertNotIn("pair.item_family_candidate_0702 = nil", guard)
        self.assertNotIn("pair.item_family_logistics_0702 = nil", service)



class ExistingUnladen0702RailYieldTests(unittest.TestCase):
    def test_preexisting_magazine_source_approach_yields_without_cargo_or_task_loss(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        src = (root / "tech-priests_src/scripts/core/"
               "item_family_logistics_0702.lua").read_text(encoding="utf-8")
        yield_block = src.split(
            "local function pause_unladen_item_family_for_rail_0836(pair,task)", 1
        )[1].split("local function discover_pair(pair)", 1)[0]
        service = src.split("function M.service_pair(pair, reason)", 1)[1].split(
            "local function action_target(", 1)[0]
        classifier = src.split("function M.recommend_action(pair)", 1)[1].split(
            "local function discover_pairs(budget)", 1)[0]
        for field in (
            'task.phase~="move-to-source"',
            "task.carried~=nil", "pair.item_family_custody_0702~=nil",
            "task.relay_paused_order_1042~=nil",
            "valid(task.source_entity)", "valid(task.target)",
            'request.owner=="item-family-logistics-0702"',
            'status.owner_match==true',
            'status.owner=="item-family-logistics-0702"',
            'pair.movement_request_0418==nil',
            "task.rail_deferred_0836=true",
        ):
            self.assertIn(field, yield_block)
        for forbidden in ("task.phase=", "task.carried=", "task.source_inv=",
                          "pair.item_family_logistics_0702=", "pair.item_family_custody_0702=",
                          "inv_remove(", "inv_insert(", "create_entity(", "teleport("):
            self.assertNotIn(forbidden, yield_block)
        self.assertIn("task.rail_deferred_0836=nil", service)
        self.assertIn("return continue_task(pair,task)", service)
        self.assertIn('task.rail_deferred_0836==true', classifier)
        self.assertIn("original_rail_expedition_reserved_0836(pair)", classifier)
        self.assertLess(classifier.index("task.rail_deferred_0836==true"),
                        classifier.index("local candidate = pair.item_family_candidate_0702"))
        self.assertLess(service.index("pause_unladen_item_family_for_rail_0836(pair,task)"),
                        service.index("return continue_task(pair,task)"))


    def test_original_boarding_handoff_invokes_only_0702_owner_custody_preflight(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        family = (root / "tech-priests_src/scripts/core/"
                  "item_family_logistics_0702.lua").read_text(encoding="utf-8")
        rail = (root / "tech-priests_src/scripts/core/"
                "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        exported = family.split(
            "function M.pause_unladen_for_original_rail_0836(pair)", 1
        )[1].split("local function discover_pair(pair)", 1)[0]
        board = rail.split(
            "function M.service_first_train_board_0836(pair)", 1
        )[1].split("-- First outward expedition:", 1)[0]
        self.assertIn(
            "return pause_unladen_item_family_for_rail_0836(", exported)
        self.assertIn("pair and pair.item_family_logistics_0702", exported)
        self.assertIn("if pair.item_family_logistics_0702 then", board)
        self.assertIn(
            "family.pause_unladen_for_original_rail_0836,pair", board)
        self.assertIn("state.last_item_family_yield_reason_0836=", board)
        self.assertIn(
            "family.release_orphaned_movement_for_rail_0836,pair", board)
        self.assertLess(
            board.index("family.pause_unladen_for_original_rail_0836,pair"),
            board.index('state.last_blocker="boarding-foreign-movement-owned"'))
        self.assertLess(
            board.index("family.pause_unladen_for_original_rail_0836,pair"),
            board.index('owner="rail-track-frontier-0836",priority=710'))
        self.assertNotIn("pair.item_family_logistics_0702=nil", board)
        self.assertNotIn("pair.item_family_custody_0702=nil", board)
        self.assertNotIn("teleport(", board)
        self.assertNotIn("create_entity(", board)


class OriginalRailOwnerYieldEvidenceTests(unittest.TestCase):
    def test_native_log_carries_0702_owner_refusal_with_custody_checks_not_rail_credit(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        fixture = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        board = fixture.split('emit("BOARD_NATIVE_0836 elapsed="', 1)[1].split(
            'emit("OUTBOUND_NATIVE_0836 elapsed="', 1)[0]
        for field in (
            "item_family_yield_0836", "item_family_yield_reason_0836",
            "item_family_source_valid_0702", "item_family_target_valid_0702",
            "item_family_held_0702", "item_family_relay_0702",
            "item_family_custody_present_0702", "rail_resource_unit_0835",
        ):
            self.assertIn('"' + " " + field + '="..tostring(', board)
        self.assertIn("native_driver==p.priest", board)
        self.assertIn("loco_entity.get_driver()", board)
        self.assertNotIn('first_board.last_item_family_yield_0836==true)', board)
        self.assertNotIn('first_board.last_item_family_yield_reason_0836==nil)', board)


class OriginalTrainLiveFuelRefusalTests(unittest.TestCase):
    def test_native_boarding_checks_live_traction_not_only_historical_fuel_receipt(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        source = (root / "tech-priests_src/scripts/core/"
                  "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        block = source.split("function M.service_first_train_board_0836(pair)", 1)[1].split(
            "function M.service_pair(pair)", 1)[0]
        fuel = block.split("-- A prior 0528 delivery receipt is historical", 1)[1].split(
            "if pair.construction_task_0338", 1)[0]
        self.assertIn("entity.get_inventory(fuel_slot)", fuel)
        self.assertIn('inv.get_item_count("coal")', fuel)
        self.assertIn("burner.remaining_burning_fuel", fuel)
        self.assertIn("if not fuel_read or fuel_now~=true then", fuel)
        self.assertIn("original-train-out-of-live-fuel", fuel)
        self.assertIn("original-train-live-fuel-unobservable", fuel)
        self.assertNotIn("set_driver(", fuel)
        self.assertNotIn("create_entity(", fuel)
        self.assertNotIn("insert(", fuel)
        self.assertNotIn("teleport(", fuel)
        # Never misrepresent original unit boarding as successful.
        self.assertIn('if priest.type~="character" then', block)
        self.assertIn('state.phase="native-boarding-unsupported-original-unit"', block)
        # Readback occurs only before new movement/boarding, not as an
        # excuse to forget an already physically confirmed native driver.
        self.assertLess(block.index("if driver==priest then"), block.index("local fuel_slot="))
        self.assertLess(block.index("local fuel_slot="), block.index(
            "if priest.type~=\"character\" then"))
        # The paid, fueled original train cannot take a native unit Magos.
        # An unrelated 0702 move must not hide this underlying API blocker.
        self.assertLess(block.index('if priest.type~="character" then'),
                        block.index("if pair.construction_task_0338"))
        self.assertLess(block.index('if priest.type~="character" then'),
                        block.index('state.last_blocker="boarding-foreign-movement-owned"'))


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
        self.assertNotIn("pair.construction_request=nil", handoff)
        self.assertIn("RAIL_LIVE_ADMISSION elapsed=", fixture)
        self.assertIn("dispatcher_frontier_result=", fixture)
        self.assertIn("plan_result=", fixture)
        self.assertIn("RAIL_NATIVE_CUSTODY_NOT_CONSERVED", fixture)
        self.assertIn("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN", fixture)


class UncommittedOriginalRailNilPendingRegressionTests(unittest.TestCase):
    def test_new_original_rail_planning_yield_cannot_index_absent_pending(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        f = (root / "tech-priests_src/scripts/core/"
             "rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/"
                   "fixture.lua").read_text(encoding="utf-8")
        section = f.split("if yielding and not pair.rail_order_yield_observed_0836 then", 1)[1].split(
            "local incumbent=", 1)[0]
        self.assertIn("request_segment=pending and pending.segment or nil", section)
        self.assertNotIn("request_segment=pending.segment", section)
        self.assertIn("order_authority.can_yield_uncommitted_rail_0836", f)
        self.assertIn("pair.construction_request=request", f)
        for field in ("rail_yield_observed=", "expansion_status=",
                      "facility_feed_custody=", "defense_task=", "frontier_error="):
            self.assertIn(field, fixture)
        # These are observations, not permission to skip real custody or build.
        self.assertIn('return false,"original-magos-incumbent-duty"', f)
        self.assertIn("local planned,reason=M.plan_next(pair)", f)


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
        identity = queue.split('local same_root=', 1)[1].split(
            'local rail_request=', 1)[0]
        pre = queue.split('if request==nil then', 1)[1].split(
            'elseif not(same_root', 1)[0]
        self.assertIn('mission.root_station_unit==p.station.unit_number', identity)
        self.assertIn('mission.surface_index==p.station.surface.index', identity)
        self.assertIn('mission.force_index==p.station.force.index', identity)
        self.assertIn('same_root and type(mission.target)', pre)
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
        # The fixture pins the original real depot entity and checks its exact
        # unit, force and surface rather than finding an unrelated chest.
        self.assertIn('local depot=s.depot_entity', fixture)
        self.assertIn('depot.unit_number==s.depot_unit', fixture)
        self.assertIn('depot.force==station.force', fixture)
        self.assertIn('depot.surface==surface', fixture)
        self.assertIn('depot_inv.get_item_count("rail")', fixture)
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
        # A completed original rail may be reconciled while a NEW unrelated
        # construction request is live, but never borrowed for the pending rail.
        self.assertIn('and (pair.construction_request==nil', frontier)
        self.assertIn('or (saved_matches and pair.construction_request~=pending.request)', frontier)
        self.assertIn('saved.request_value==pending.request', frontier)
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
            # A fake host printing FAIL can exit naturally with code 0.
            # Preserve that native process exit separately from the strict
            # fixture_failure verdict and insist no physical-rail credit.
            self.assertFalse(rail_connected_smoke_verdict(
                code, server_log.read_text(encoding="utf-8")))


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
        self.assertIn('for _,mark in ipairs({1800,9000,18000,36000,60000,72000,90000})', fixture)
        self.assertIn('if elapsed>=36000 then', fixture)
        self.assertNotIn('if elapsed>=36000 and not s.rail_custody_verified then', fixture)
        self.assertIn('if not s.rail_custody_verified then', fixture)
        self.assertIn('total==expected', fixture)
        self.assertIn('RAIL_NATIVE_CUSTODY_NOT_CONSERVED', fixture)
        self.assertIn('RAIL_LINE_NEVER_REACHED_REMOTE_PATCH', fixture)
        self.assertIn('TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN', fixture)
        self.assertIn('"train_and_ore_delivery_accepted": False', runner)


class NativeReverseLocomotive0836ContractTests(unittest.TestCase):
    def test_reverse_traction_is_second_original_paid_physical_entity(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        builder=(root/"tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        dispatch=(root/"tech-priests_src/scripts/core/single_dispatcher_0510.lua").read_text(encoding="utf-8")
        queue=(root/"tech-priests_src/scripts/core/order_queue_0469.lua").read_text(encoding="utf-8")
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        source=rail.split("function M.service_return_locomotive_0836(pair)",1)[1].split(
            "function M.service_first_wagon_0836(pair)",1)[0]
        for expected in ("receipt.before-receipt.after==1",
                         "math.abs(((entity.orientation-lead.built_entity.orientation)%1)-0.5)",
                         "entity.train.id==lead.built_entity.train.id",
                         'site_reason="original-return-locomotive-0836"',
                         "pair.construction_request=request"):
            self.assertIn(expected,source)
        for forbidden in ("surface.create_entity","train.speed=","teleport",
                          "entity.direction==(route.direction+8)%16"):
            self.assertNotIn(forbidden,source)
        self.assertIn("return M.service_return_locomotive_0836(pair)",rail)
        for checked in (builder,dispatch,queue):
            self.assertIn("original-return-locomotive-0836",checked)
        self.assertIn("REVERSE_LOCO_NATIVE_0836",fixture)
        self.assertIn("native_opposite=",fixture)
        self.assertIn("rear_orientation=",fixture)
        self.assertIn("NO_GENUINE_ORE_DELIVERED_BY_RAIL",fixture)


    def test_0528_original_fuel_walk_requires_exact_paid_train(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        movement=(root/"tech-priests_src/scripts/core/movement_controller.lua").read_text(encoding="utf-8")
        fuel=(root/"tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua").read_text(encoding="utf-8")
        guard=rail.split("function M.authorized_original_train_fuel_walk_0836(pair,point,movement)",1)[1].split(
            "-- 0836 train stops extend",1)[0]
        for required in (
            'movement.owner=="logistics_machine_fulfillment_0528"',
            'movement.reason=="machine-logistics-move-to-machine-0528"',
            'and state.phase=="move-to-machine"',
            'and state.original_train_fuel_0836==true',
            'and state.action=="supply-fuel" and state.item=="coal"',
            'and state.machine==locomotive',
            'and custody==pair.machine_logistics_custody_0528',
            'source.source_before-source.source_after==custody.count',
            'lead.paid_completion_0836.native_0338_paid==true',
            'wagon.paid_completion_0836.native_0338_paid==true',
            'locomotive.train.id==wagon.built_entity.train.id',
            'goal.x-locomotive.position.x',
            'before.unit_number==route.built_units[index-1]',
            'center.unit_number==route.built_units[index]',
            'after.unit_number==route.built_units[index+1]',
            'connected_straight_rails(before,center)',
            'connected_straight_rails(center,after)',
        ):
            self.assertIn(required,guard)
        for forbidden in ('bounds_exempt', 'surface.create_entity', 'teleport',
                          'train.speed=', 'state.custody=nil', 'inventory.remove'):
            self.assertNotIn(forbidden,guard)
        self.assertIn('owner = "logistics_machine_fulfillment_0528"',fuel)
        self.assertIn('"machine-logistics-move-to-machine-0528"',fuel)
        allowed=movement.split("function M.position_allowed(pair, pos, reason, opts)",1)[1].split(
            "local function proxy_prime_allowed",1)[0]
        self.assertIn('rail.authorized_original_train_fuel_walk_0836,pair,pos',allowed)
        self.assertIn('if ok and allowed==true then return true,nil,nil end',allowed)
        enforcement=movement.split("function M.enforce_pair(pair, reason)",1)[1].split(
            'local courier_ok,courier_authorized=pcall(',1)[0]
        self.assertIn('frontier.authorized_original_train_fuel_walk_0836,pair,',enforcement)
        self.assertIn('pair.priest.position,request)',enforcement)
        self.assertIn('return false,"original-paid-train-fuel-walk-owned-0836"',enforcement)
        corridor=(root/"tech-priests_src/scripts/core/authority_corridor_pathing_0574.lua").read_text(encoding="utf-8")
        auth=corridor.split("function M.authorization_for_destination(pair, pos, reason, opts)",1)[1].split(
            "function M.position_allowed(pair, pos, reason, opts)",1)[0]
        self.assertIn('opts.owner=="logistics_machine_fulfillment_0528"',auth)
        self.assertIn('reason=="machine-logistics-move-to-machine-0528"',auth)
        self.assertIn('frontier.authorized_original_train_fuel_walk_0836,pair,pos',auth)
        self.assertIn('"native-paid-original-locomotive-fuel-0836"',auth)
        self.assertIn('role="physical-original-rail-0836"',auth)
        self.assertIn('if allowed == false then',movement)
        self.assertIn('if corridor_rejected then allowed = false end',movement)
        self.assertIn('M.stop(pair, "movement-overleash-0566")',movement)


class NativePaidFirstLocomotive0836ContractTests(unittest.TestCase):
    def test_train_first_requires_original_paid_builder_native_rails_and_stock(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        source=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        builder=(root/"tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        section=source.split("function M.service_first_locomotive_0836(pair)",1)[1].split("function M.service_pair(pair)",1)[0]
        for guard in ("route.chain_audit_completed_tick_0836",
                      "previous.unit_number==route.built_units[index-1]",
                      "rail.unit_number==route.built_units[index]",
                      "connected_straight_rails(previous,rail)",
                      "connected_straight_rails(rail,next_rail)",
                      'return false,"no-real-locomotive-item"',
                      "pair.construction_request=request",
                      "receipt.before-receipt.after==1",
                      "entity.train and entity.train.valid",
                      "pair.construction_request~=state.request"):
            self.assertIn(guard,section)
        self.assertNotIn("surface.create_entity",section)
        self.assertIn('local original_loco=task.item_name=="locomotive"',builder)
        self.assertIn("locomotive_before-after==1",builder)
        self.assertIn('return M.abort_pair(pair,"native-locomotive-source-debit-unreconciled")',builder)
        self.assertIn("state.paid_completion_0836={",builder)
        self.assertIn("native_0338_paid=true",builder)
        self.assertIn("return M.service_first_locomotive_0836(pair)",source)

    def test_recent_refused_miner_is_parked_not_erased_for_original_paid_loco(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        src=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        builder=(root/"tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        dispatch=(root/"tech-priests_src/scripts/core/single_dispatcher_0510.lua").read_text(encoding="utf-8")
        queue=(root/"tech-priests_src/scripts/core/order_queue_0469.lua").read_text(encoding="utf-8")
        loco=src.split("function M.service_first_locomotive_0836(pair)",1)[1].split("function M.service_pair(pair)",1)[0]
        self.assertIn('refusal.request==prior and refusal.reason=="no-miner-site"',loco)
        self.assertIn("now()-age<=600",loco)
        self.assertIn("pair.construction_request=request",loco)
        self.assertNotIn("pair.construction_requested_item=",loco)
        self.assertIn("owned_pending_locomotive_0836(pair,rail)",builder)
        self.assertIn("owned_pending_locomotive_0836(pair,frontier)",builder)
        self.assertIn('task.request_field=="construction_request"',builder)
        self.assertIn("locomotive-original-physical-request-stale",builder)
        self.assertIn('and not((request.site_reason=="original-first-locomotive-0836"',builder)
        self.assertIn('or (request.site_reason=="original-first-wagon-0836"',builder)
        self.assertIn('if locomotive_writ or c.site_reason=="original-first-locomotive-0836"',builder)
        self.assertIn('and owned_pending_locomotive_0836(pair,c.request_value)',builder)
        self.assertIn("locomotive_before-after==1",builder)
        self.assertIn("loco.request==request",queue)
        self.assertIn('route.chain_audit_completed_tick_0836',queue)
        self.assertNotIn("p.construction_requested_item=nil",queue)
        self.assertIn("locomotive-order-yield-refused",dispatch)
        self.assertIn("locomotive-original-candidate-refused",dispatch)
        self.assertIn("dispatch-first-native-locomotive-0836",dispatch)

    def test_native_locomotive_standoff_respects_rotated_body_and_priest(self):
        """The 0338 contact correction must not relax engine placement/custody."""
        root=pathlib.Path(__file__).resolve().parents[2]
        builder=(root/"tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        geometry=builder.split("local function wide_entity_collision_bounds_1204(task)",1)[1].split(
            "local function non_ghost_standoff(pair,task,avoid,reach_recovery)",1)[0]
        self.assertIn('if task.entity_name=="locomotive" or task.entity_name=="cargo-wagon" then',geometry)
        self.assertIn('task.direction==d.east or task.direction==d.west',geometry)
        self.assertIn("x0,y0,x1,y1=-y1,x0,-y0,x1",geometry)
        self.assertIn("return nil -- Do not guess at a non-cardinal train footprint.",geometry)
        self.assertIn("local function locomotive_contact_clears_priest_0836",geometry)
        self.assertIn("return px1+gap<=sx0 or px0-gap>=sx1",geometry)
        self.assertIn("or py1+gap<=sy0 or py0-gap>=sy1",geometry)
        self.assertIn("and locomotive_contact_clears_priest_0836(pair,task,pos)",builder)
        self.assertIn("site_build_distance_sq(pos,task)<=M.build_reach_sq",builder)
        self.assertIn('return ok and can==true,ok and"engine-revalidated"or"engine-check-failed"',builder)
        self.assertIn("custody-returned-source",builder)
        # Cardinal east/west transforms a long N-S rolling-stock box into
        # its long E-W footprint. A formerly legal north/south contact may
        # now be inside that train footprint and must not be offered.
        north=(-0.7,-2.6,0.7,2.6)
        east=(-north[3],north[0],-north[1],north[2])
        self.assertEqual(east,(-2.6,-0.7,2.6,0.7))
        self.assertTrue(-2.6<1.6<2.6) # x=1.6 would overlap the loco
        self.assertFalse(-2.6<3.6<2.6) # x=3.6 clears the rotated box

class NativePaidWagon0836ContractTests(unittest.TestCase):
    """Source regressions cannot replace real Factorio wagon/coupling evidence."""
    def test_original_wagon_receipt_coupling_and_native_source(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        frontier=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        builder=(root/"tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        dispatch=(root/"tech-priests_src/scripts/core/single_dispatcher_0510.lua").read_text(encoding="utf-8")
        order=(root/"tech-priests_src/scripts/core/order_queue_0469.lua").read_text(encoding="utf-8")
        wagon=frontier.split("function M.service_first_wagon_0836(pair)",1)[1].split("function M.service_pair(pair)",1)[0]
        for marker in ('parent.phase=="native-paid-locomotive-verified"',
                       "route.chain_audit_completed_tick_0836",
                       'return false,"no-real-cargo-wagon-item"',
                       'name="cargo-wagon",position=point',
                       "connected_straight_rails(previous,rail)",
                       "receipt.before-receipt.after==1",
                       "entity.train.id==parent.built_entity.train.id",
                       "has_loco and has_wagon",
                       "pair.construction_request=request"):
            self.assertIn(marker,wagon)
        self.assertNotIn("surface.create_entity",wagon)
        for marker in ("owned_pending_wagon_0836(pair,request)",
                       "wagon-original-physical-request-stale",
                       "wagon_before-after==1",
                       "if original_wagon then",
                       "native-wagon-source-debit-unreconciled",
                       "task.original_wagon_debit_0836={",
                       "custody-returned-source"):
            self.assertIn(marker,builder)
        self.assertIn("wagon_request",order)
        self.assertIn("wagon-order-yield-refused",dispatch)
        self.assertIn("dispatcher-0510:first-original-paid-wagon-0836",dispatch)

    def test_original_full_expedition_engine_gates_not_diluted(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        for gate in ("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN",
                     "TRAIN_NEVER_ASSEMBLED",
                     "MAGOS_PHYSICAL_TRAIN_RIDE_NOT_PROVEN",
                     "NO_GENUINE_ORE_DELIVERED_BY_RAIL"):
            self.assertIn(gate,fixture)


class NativePaidTrainFuel0836ContractTests(unittest.TestCase):
    def test_original_coupled_train_fuel_uses_existing_physical_0528_and_0510(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        src=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        fuel=(root/"tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua").read_text(encoding="utf-8")
        dispatch=(root/"tech-priests_src/scripts/core/single_dispatcher_0510.lua").read_text(encoding="utf-8")
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        section=src.split("function M.service_first_train_fuel_0836(pair)",1)[1].split("function M.service_pair(pair)",1)[0]
        for marker in ('wagon.phase=="native-paid-wagon-verified"',
                       "entity.train.id==wagon.built_entity.train.id",
                       "entity.train and entity.train.valid",
                       "wagon.built_entity.train and wagon.built_entity.train.valid",
                       "receipt.source_before-receipt.source_after==receipt.count",
                       "receipt.destination_after-receipt.destination_before==receipt.count",
                       'receipt.authority=="physical-machine-fuel-0528"',
                       'fuel.get_item_count,"coal"',
                       "offer_original_locomotive_fuel_0836"):
            self.assertIn(marker,section)
        self.assertNotIn("surface.create_entity",section)
        self.assertNotIn("inventory.insert",section)
        self.assertIn('locomotive = true, -- explicitly owned original 0836 fuel only',fuel)
        self.assertIn('candidate.source="original-locomotive-fuel-0836"',fuel)
        self.assertIn("exact_original_train_0836(pair,state.machine)",fuel)
        self.assertIn("remove_generic(pair,state.item,state.count)",fuel.replace(" ",""))
        self.assertIn("insert_inventory(destination, custody.item, custody.count)",fuel)
        self.assertIn("destination_after == destination_before + inserted",fuel)
        self.assertIn("dispatcher-0510:original-coupled-train-fuel-0836",dispatch)
        self.assertIn("train-fuel-order-yield-refused",dispatch)
        # A completed 0528 task leaves a saved diagnostic table; it cannot
        # suppress a future authentic fuel request, unlike active custody.
        self.assertIn('pair.machine_logistics_0528.phase~="complete"',dispatch)
        self.assertIn('pair.machine_logistics_0528.phase~="failed"',dispatch)
        self.assertIn('or pair.machine_logistics_custody_0528',dispatch)
        self.assertIn("FUEL_NATIVE_0836 elapsed=",fixture)
        # Real 60k engine stall: the unrelated 0528 coal supply still had an
        # unladen move-to-station state from tick 15605, with no live move at 60k.
        # Only 0528 can retire that exact old task, never cargo or movement.
        # Canonical 0528 owns releasing its own stale unladen job. The rail
        # frontier only requests the release after genuine original train
        # fuel verification; no independent 0836 movement/custody override.
        original=fuel.split("local function retire_unladen_abandoned_fuel_0836",1)[1].split(
            "function M.offer_original_locomotive_fuel_0836",1)[0]
        for guard in ('state.phase=="move-to-station"', 'state.action=="supply-fuel"',
                      'state.item=="coal"', 'state.machine~=locomotive',
                      'now()-state.started_tick>=(min_age_ticks or 60*120)', 'state.custody',
                      'pair.machine_logistics_custody_0528',
                      'pair.construction_task_0338', 'pair.direct_acquisition_custody_0513',
                      'pair.movement_request_0418', 'movement.request_status',
                      'status.active~=false', 'M.abort_pair(pair,',
                      'not active_state(pair)'):
            self.assertIn(guard,original)
        self.assertIn('fuel.phase=="native-paid-locomotive-fueled"', original)
        self.assertIn('fuel.train_id==locomotive.train.id', original)
        self.assertIn('retire_unladen_abandoned_fuel_0836(pair,locomotive,60*30)', original)
        # Native snapshots must expose the current 0528 owner, not just a
        # stale 0836 fuel phase or aggregate work counters. No new pass gate.
        for diagnostic in ("offer_reason=", "machine_phase=", "machine_action=",
                           "machine_blocker=", "machine_train_owned=",
                           "machine_custody=", "candidate_source=",
                           "construction_active=", "movement_owner="):
            self.assertIn(diagnostic, fixture)
        self.assertIn('fail("TRAIN_NOT_NATIVE_FUELED")',fixture)

    def test_fuel_refuses_uncoupled_unpaid_or_other_custody(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        src=(root/"tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua").read_text(encoding="utf-8")
        section=src.split("local function exact_original_train_0836(pair,locomotive)",1)[1].split("-- 1153:",1)[0]
        for marker in ("route.chain_audit_completed_tick_0836",
                       'loco.paid_completion_0836.native_0338_paid==true',
                       'wagon.paid_completion_0836.native_0338_paid==true',
                       "locomotive.train.id==wagon.built_entity.train.id",
                       "has_loco and has_wagon",
                       "pair.machine_logistics_custody_0528",
                       "pair.direct_acquisition_custody_0513",
                       "other-machine-candidate-owned",
                       "no-counted-original-coal-or-fuel-not-needed"):
            self.assertIn(marker,section)


class NativeReverseLocomotivePhysicalFuel0836ContractTests(unittest.TestCase):
    """Only real 0528 coal can propel the original paid train home."""

    def test_same_original_two_headed_consist_and_0528_custody(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        logistics=(root/"tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua").read_text(encoding="utf-8")
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        exact=logistics.split("local function exact_original_train_0836(pair,locomotive)",1)[1].split(
            "local function retire_unladen_abandoned_fuel_0836",1)[0]
        for required in (
            'reverse.phase=="native-paid-return-locomotive-verified"',
            'reverse.paid_completion_0836.native_0338_paid==true',
            'reverse.built_entity==locomotive',
            'locomotive.unit_number==reverse.built_unit',
            'locomotive.train.id==loco.built_entity.train.id',
            'has_loco and has_wagon and has_lead',
        ):
            self.assertIn(required,exact)
        self.assertIn('locomotive==loco.built_entity',exact)
        walk=rail.split("function M.authorized_original_train_fuel_walk_0836(pair,point,movement)",1)[1].split(
            "local function authorized_paid_stop_contact_0836",1)[0]
        for required in (
            'movement.owner=="logistics_machine_fulfillment_0528"',
            'state.original_train_fuel_0836==true',
            'source.source_before-source.source_after==custody.count',
            'reverse.paid_completion_0836.native_0338_paid==true',
            'locomotive==reverse.built_entity',
            'locomotive.train.id==lead.built_entity.train.id',
            'connected_straight_rails(before,center)',
        ):
            self.assertIn(required,walk)
        for forbidden in ("create_entity(", "inventory.insert(", "teleport(", "bounds_exempt"):
            self.assertNotIn(forbidden,walk)

    def test_second_unique_real_native_coal_receipt_precedes_boarding(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        logistics=(root/"tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua").read_text(encoding="utf-8")
        fuel=rail.split("function M.service_return_train_fuel_0836(pair)",1)[1].split(
            "-- First 0836 native Magos boarding.",1)[0]
        for required in (
            'reverse.paid_completion_0836.native_0338_paid==true',
            'entity.train.id==lead.built_entity.train.id',
            'entity.train.id==wagon.built_entity.train.id',
            'receipt.machine_unit==entity.unit_number',
            'receipt.station_unit==pair.station.unit_number',
            'receipt.priest_unit==pair.priest.unit_number',
            'receipt.authority=="physical-machine-fuel-0528"',
            'receipt.source_before-receipt.source_after==receipt.count',
            'receipt.destination_after-receipt.destination_before==receipt.count',
            'receipt.tick>=reverse.verified_tick',
            'inventory.get_item_count,"coal"',
            'state.phase="native-paid-return-locomotive-fueled"',
            'logistics.offer_original_locomotive_fuel_0836,pair,entity',
        ):
            self.assertIn(required,fuel)
        self.assertIn('candidate=fuel_candidate(pair,locomotive)',logistics)
        self.assertIn('destination_after == destination_before + inserted',logistics)
        service=rail.split("function M.service_pair(pair)",1)[1]
        self.assertLess(service.index("return M.service_return_train_fuel_0836(pair)"),
                        service.index("return M.service_first_train_stop_0836(pair)"))
        self.assertIn('return M.service_first_train_return_0836(pair)',service)
        for forbidden in ("create_entity(", "insert(", "teleport(", "set_driver("):
            self.assertNotIn(forbidden,fuel)

    def test_return_refuses_empty_reverse_fuel_and_unrelated_stock(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        body=rail.split("function M.service_first_train_return_0836(pair)",1)[1].split(
            "function M.service_pair(pair)",1)[0]
        for required in (
            'reverse_fuel.phase=="native-paid-return-locomotive-fueled"',
            'reverse_fuel.locomotive_unit==reverse.built_unit',
            'reverse.built_entity.train.id',
            'math.abs(((reverse.built_entity.orientation-engine.orientation)%1)-0.5)',
            'reverse.built_entity.get_inventory(slot)',
            'reverse.built_entity.burner',
            '"native-homeward-original-reverse-fuel-missing"',
            'outward.phase=="native-original-outbound-arrived-at-paid-remote-stop"',
            'driver==priest',
            'train.station==origin',
            'state.lowest_x<state.remote_x-32',
        ):
            self.assertIn(required,body)
        self.assertLess(body.index('reverse.built_entity.get_inventory(slot)'),
                        body.index('schedule.go_to_station(2)'))
        for forbidden in ("create_entity(", "insert(", "teleport(", "train.speed="):
            self.assertNotIn(forbidden,body)


class NativeOriginalMagosBoarding0836ContractTests(unittest.TestCase):
    """Native driver readback, not flags or script relocation, proves boarding."""
    def test_original_priest_can_board_only_at_real_train_contact(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        src=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        section=src.split("function M.service_first_train_board_0836(pair)",1)[1].split("function M.service_pair(pair)",1)[0]
        for marker in ('fuel.phase=="native-paid-locomotive-fueled"',
                       'loco.phase=="native-paid-locomotive-verified"',
                       'wagon.phase=="native-paid-wagon-verified"',
                       'entity.train.id==wagon.built_entity.train.id',
                       "driver and driver~=priest",
                       "pair.machine_logistics_custody_0528",
                       "pair.direct_acquisition_custody_0513",
                       "pair.construction_custody_0338",
                       'distance_sq>3.3*3.3',
                       '"tech_priests_request_movement_0418"',
                       "entity.set_driver(priest)",
                       "actual==priest",
                       "priest.unit_number==pair.priest.unit_number",
                       "retry_after_tick=now()+300",
                       "physical_boarding_confirmed=true"):
            self.assertIn(marker,section)
        # Native Factorio 2.1.24 rejected set_driver(original unit).
        # Fail closed before any impossible write or movement lease.
        blocker='if priest.type~="character" then'
        self.assertIn(blocker,section)
        prototype_guard=section.split(blocker,1)[1].split("  end",1)[0]
        for required in ('state.phase="native-boarding-unsupported-original-unit"',
                         'state.priest_unit=priest.unit_number',
                         'state.unsupported_since_tick=state.unsupported_since_tick or now()',
                         '"native-driver-requires-original-character:"..priest.type',
                         'return false,state.last_blocker'):
            self.assertIn(required,prototype_guard)
        self.assertLess(section.index(blocker),
                        section.index("local dx=priest.position.x-entity.position.x"))
        self.assertLess(section.index(blocker),
                        section.index("entity.set_driver(priest)"))
        for unsafe in ("teleport", "create_entity", "set_driver",
                       "physical_boarding_confirmed", "remove_item", "insert"):
            self.assertNotIn(unsafe,prototype_guard)
        self.assertIn("unsupported_priest_type=",fixture)
        self.assertIn("original_priest_identity_intact=",fixture)
        for bypass in ("teleport","surface.create_entity","train.speed="):
            self.assertNotIn(bypass,section)
        self.assertIn("return M.service_first_train_board_0836(pair)",src)
        self.assertIn("BOARD_NATIVE_0836 elapsed=",fixture)
        self.assertIn("native_boarded=observed and actual_driver==p.priest",fixture)
        self.assertIn("and native_boarded then",fixture)
        for gate in ("TRAIN_NOT_NATIVE_FUELED",
                     "MAGOS_PHYSICAL_TRAIN_RIDE_NOT_PROVEN",
                     "NO_GENUINE_ORE_DELIVERED_BY_RAIL"):
            self.assertIn(gate,fixture)


class NativePaidTrainStop0836ContractTests(unittest.TestCase):

    def test_paid_stop_contact_respects_audited_native_rail_and_original_custody(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        rail = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                ).read_text(encoding="utf-8")
        corridor = (root / "tech-priests_src/scripts/core/authority_corridor_pathing_0574.lua"
                    ).read_text(encoding="utf-8")
        helper = rail.split(
            "local function authorized_paid_stop_contact_0836(pair,point)", 1
        )[1].split("-- A physical railway has a narrow", 1)[0]
        authorizer = rail.split(
            "function M.authorized_paid_rail_contact_0836(pair,point,reason,opts)", 1
        )[1].split("local function reject(objective,reason)", 1)[0]
        for guard in ('mission.status=="rail-track-established"',
                      'stop.phase=="awaiting-original-0338"',
                      'route.chain_audit_completed_tick_0836',
                      'task.phase=="move-site"',
                      'task.request_value==stop.request',
                      'pair.construction_request==stop.request',
                      'task.site_reason=="original-first-train-stop-0836"',
                      'task.creative_build~=true',
                      'task.carried.item_name=="train-stop"',
                      'task.carried.count==1',
                      'debit.before-debit.after==1',
                      'task.source_entity.unit_number==debit.source_unit',
                      'stop.request.rail_mission_station_unit_0836==pair.station.unit_number',
                      'dx*dx+dy*dy>9',
                      'rail.unit_number==route.built_units[index]',
                      'before.unit_number==route.built_units[index-1]',
                      'after.unit_number==route.built_units[index+1]',
                      'connected_straight_rails(before,rail)',
                      'connected_straight_rails(rail,after)'):
            self.assertIn(guard, helper)
        for forbidden in ('teleport(', 'surface.create_entity',
                          'insert_item(', 'remove_item(', 'set_driver(',
                          'task.carried.count=0', 'station.radius='):
            self.assertNotIn(forbidden, helper)
        self.assertIn('reason~="construction-site-standoff-0338"', authorizer)
        self.assertIn('opts.owner=="construction-planner-0338"', authorizer)
        self.assertIn('if authorized_paid_stop_contact_0836(pair,point) then return true end',
                      authorizer)
        self.assertLess(
            authorizer.index('if authorized_paid_stop_contact_0836(pair,point)'),
            authorizer.index('local pending=mission.pending_rail_0836'))
        self.assertIn(
            'frontier.authorized_paid_rail_contact_0836,pair,pos,reason,opts',
            corridor)
        self.assertIn('if checked and authorized==true then', corridor)

    def test_original_stop_receives_canonical_dispatch_without_stealing_real_orders(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        builder = (root / "tech-priests_src/scripts/core/construction_planner.lua"
                   ).read_text(encoding="utf-8")
        dispatcher = (root / "tech-priests_src/scripts/core/single_dispatcher_0510.lua"
                      ).read_text(encoding="utf-8")
        queue = (root / "tech-priests_src/scripts/core/order_queue_0469.lua"
                 ).read_text(encoding="utf-8")
        admission = queue.split(
            "function M.can_yield_uncommitted_rail_0836(p,request)", 1
        )[1].split("function M.can_pause_uncommitted_relay_0974", 1)[0]
        for required in ('stop.request==request', 'stop.phase=="awaiting-original-0338"',
                         'fuel.phase=="native-paid-locomotive-fueled"',
                         'route.segment==#route.built_units',
                         'or wagon_request or stop_request',
                         'o.item=="firearm-magazine"',
                         'p.construction_custody_0338', 'p.movement_request_0418'):
            self.assertIn(required, admission)
        self.assertNotIn("p.order_queue_0469.current=nil", admission)
        self.assertNotIn("p.active_order_0469=nil", admission)
        self.assertNotIn("p.construction_request=nil", admission)
        self.assertIn('owned_pending_stop_0836(pair,rail)', builder)
        self.assertIn('source_for_item(pair,"train-stop")~=nil', builder)
        self.assertGreaterEqual(
            builder.count("owned_pending_stop_0836(pair,frontier)"), 2)
        stop = dispatcher.split(
            "-- The exact original 0836 train-stop writ needs a 0338 dispatch pulse", 1
        )[1].split("  local fuel=m and m.first_fuel_0836", 1)[0]
        for required in ('pair.construction_request==stop_req',
                         'task.request_value==stop_req',
                         'carrying.request_value==stop_req',
                         'owner.can_yield_uncommitted_rail_0836,pair,stop_req',
                         'pair.direct_acquisition_custody_0513',
                         'pair.machine_logistics_custody_0528',
                         'pair.movement_request_0418',
                         'candidate.request_field=="construction_request"',
                         'candidate.request_value==stop_req',
                         'candidate.item_name=="train-stop"',
                         'execute(pair,"construction"',
                         'dispatcher-0510:first-original-paid-train-stop-0836'):
            self.assertIn(required, stop)
        for forbidden in ('surface.create_entity', 'pair.active_order_0469=nil',
                          'pair.construction_custody_0338=nil',
                          'pair.construction_request=nil', 'teleport('):
            self.assertNotIn(forbidden, stop)

    def test_train_stop_faces_native_track_from_the_correct_side(self):
        # 43130874362: a physically paid native train stop was built, but
        # connected_rail was nil. Collision clearance is not rail binding.
        root = pathlib.Path(__file__).resolve().parents[2]
        rail = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua"
                ).read_text(encoding="utf-8")
        stop = rail.split("function M.service_first_train_stop_0836(pair,role)", 1)[1].split(
            "function M.service_first_train_board_0836(pair)", 1)[0]
        self.assertIn('local heading=offset<0 and cardinal.west or cardinal.east', stop)
        self.assertIn('return false,"original-native-train-stop-requires-horizontal-track"', stop)
        self.assertNotIn('for _,heading in ipairs({route.direction,(route.direction+8)%16})', stop)
        self.assertIn('can_place_entity{', stop)
        self.assertIn('connected_original(stop)', stop)
        self.assertIn('receipt.before-receipt.after==1', stop)
        self.assertIn('state.phase="blocked"', stop)
        self.assertNotIn('surface.create_entity', stop)
        self.assertNotIn('teleport(', stop)

    def test_stop_is_original_0338_paid_and_native_connected_before_boarding(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        rail = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        builder = (root / "tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        stop = rail.split("function M.service_first_train_stop_0836(pair,role)", 1)[1].split("function M.service_first_train_board_0836(pair)", 1)[0]
        for part in ('receipt.before-receipt.after==1', 'stop.connected_rail',
                     'unit==rail.unit_number', 'no-real-train-stop-item',
                     'original-first-train-stop-0836', 'pair.construction_request=request',
                     'native-paid-original-train-stop-verified'):
            self.assertIn(part, stop)
        for part in ('owned_pending_stop_0836', 'original_stop_debit_0836',
                     'stop_before-after==1', 'train-stop-creative-item-bypass-forbidden',
                     'train-stop-original-physical-request-stale'):
            self.assertIn(part, builder)
        self.assertIn('return M.service_first_train_stop_0836(pair)', rail)
        self.assertIn('STOP_NATIVE_0836 elapsed=', fixture)
        self.assertNotIn('surface.create_entity', stop)
        self.assertNotIn('teleport(', stop)


    def test_remote_stop_requires_distinct_paid_0338_receipt_and_real_far_rail(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        rail = (root / "tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        builder = (root / "tech-priests_src/scripts/core/construction_planner.lua").read_text(encoding="utf-8")
        fixture = (root / "tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        stop = rail.split("function M.service_first_train_stop_0836(pair,role)", 1)[1].split(
            "function M.service_first_train_board_0836(pair)", 1)[0]
        for required in (
            'local remote=role=="remote"',
            'route.segment-16',
            'route.segment-22',
            'm.remote_stop_0836=record',
            'rail_stop_role_0836=remote and "remote" or "home"',
            'receipt.native_0338_paid==true',
            'receipt.before-receipt.after==1',
            'connected_original(stop)',
            'original-home-stop-not-verified',
            'return false,"no-real-train-stop-item"',
        ):
            self.assertIn(required, stop)
        for required in (
            'if role=="remote" then state=mission.remote_stop_0836',
            'if stop_role=="remote" then first_stop=mission.remote_stop_0836',
            'and state.request==request and pair.construction_request==request',
            'stop_before-after==1',
            'train-stop-original-physical-request-stale',
        ):
            self.assertIn(required, builder)
        self.assertIn('M.service_first_train_stop_0836(pair,"remote")', rail)
        self.assertIn('if remote then state=m.remote_stop_0836', stop)
        self.assertIn('else state=m.first_stop_0836 end', stop)
        self.assertNotIn('remote and m.remote_stop_0836 or m.first_stop_0836', stop)
        self.assertIn('if far.phase~="native-paid-original-train-stop-verified"then', rail)
        contact = rail.split("local function authorized_paid_stop_contact_0836(pair,point)",1)[1].split(
            "function M.authorized_paid_rail_contact_0836(pair,point,reason,opts)",1)[0]
        for required in (
            'if role=="remote" then stop=mission.remote_stop_0836',
            'else stop=mission.first_stop_0836 end',
            'stop.request.rail_stop_role_0836==role',
            'role~="remote" or (mission.first_stop_0836',
            'route.segment-16',
            'route.segment-22',
            'task.carried.item_name=="train-stop"',
            'debit.before-debit.after==1',
            'connected_straight_rails(before,rail)',
            'connected_straight_rails(rail,after)',
        ):
            self.assertIn(required, contact)
        self.assertNotIn('role=="remote" and mission.remote_stop_0836 or mission.first_stop_0836',contact)
        self.assertIn("REMOTE_STOP_NATIVE_0836 elapsed=", fixture)
        self.assertNotIn('surface.create_entity', stop)
        self.assertNotIn('teleport(', stop)


class OriginalRailCharacterBirthContractTests(unittest.TestCase):
    def test_only_opted_in_new_magos_uses_native_character(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        settings=(root/"tech-priests_src/settings.lua").read_text(encoding="utf-8")
        config=(root/"tech-priests_src/scripts/generated/control_legacy_part_001.lua").read_text(encoding="utf-8")
        entity=(root/"tech-priests_src/prototypes/entity.lua").read_text(encoding="utf-8")
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        self.assertIn('name="tech-priests-original-magos-rail-character"',settings)
        self.assertIn('default_value=false',settings.split('name="tech-priests-original-magos-rail-character"')[1][:160])
        self.assertIn('data.raw["character"]["character"]',entity)
        self.assertIn('make_original_rail_character_magos(def,false)',entity)
        self.assertIn('config.tier=="planetary-magos" and option and option.value==true',config)
        self.assertIn('["planetary-magos-tech-priest-rail-character"]',config)
        self.assertLess(fixture.index('settings.global["tech-priests-original-magos-rail-character"]={value=true}'),
                        fixture.index('local station=surface.create_entity{'))
        self.assertNotIn('priest.teleport(',entity)
    def test_original_character_is_walked_only_by_canonical_controller(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        move=(root/"tech-priests_src/scripts/core/movement_controller.lua").read_text(encoding="utf-8")
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        self.assertIn('priest.walking_state={walking=true,direction=heading}',move)
        self.assertIn('original-character-native-walk-recovery-only',move)
        self.assertIn('native-original-character-onboard',move)
        self.assertIn('if priest.type~="character" then',rail)
        self.assertIn('entity.set_driver(priest)',rail)
        self.assertIn('actual==priest',rail)

class OriginalCharacterObstacleNavigationRegression(unittest.TestCase):
    def test_character_collision_probe_is_physical_and_bounded(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        move=(root/"tech-priests_src/scripts/core/movement_controller.lua").read_text(encoding="utf-8")
        block=move.split('if priest.type=="character" then',1)[1].split('local command = {',1)[0]
        self.assertIn('surface.can_place_entity{',block)
        self.assertIn('name=priest.name,position=probe,force=priest.force',block)
        self.assertIn('if not clear_step(vectors[direct_index]) then',block)
        self.assertIn('for index,v in ipairs(vectors)do',block)
        self.assertIn('priest.walking_state={walking=true,direction=heading}',block)
        self.assertNotIn('priest.teleport(',block)
        self.assertNotIn('surface.create_entity',block)
        self.assertNotIn('entity.set_driver',block)
    def test_live_original_fixture_reads_both_positions_and_lease(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        block=fixture.split('emit("BOARD_NATIVE_0836 elapsed="',1)[1].split('local drills=',1)[0]
        for key in ('priest_x=', 'priest_y=', 'loco_x=', 'loco_y=',
                    'move_x=', 'move_y=', 'move_state='):
            self.assertIn(key,block)


class NativeOriginalHomeward0836ContractTests(unittest.TestCase):
    """A schedule and an old train receipt cannot prove physical return."""
    def test_original_paid_arrival_and_native_driver_precede_home_order(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        block=rail.split("function M.service_first_train_return_0836(pair)",1)[1].split(
            "function M.service_pair(pair)",1)[0]
        for guard in (
            'outward.phase=="native-original-outbound-arrived-at-paid-remote-stop"',
            'outward.highest_x>outward.origin_x+32',
            'loco.phase=="native-paid-locomotive-verified"',
            'wagon.phase=="native-paid-wagon-verified"',
            'far.phase=="native-paid-original-train-stop-verified"',
            'home.phase=="native-paid-original-train-stop-verified"',
            'engine.train.id==outward.train_id',
            'driver==priest',
            'ride.physical_boarding_confirmed==true',
            'stop.connected_rail',
            'paid[rail.unit_number]',
            'train.station~=remote',
            'records[1].station==remote_name',
            'schedule.add_record{station=home_name',
            'schedule.go_to_station(2)',
            'train.station==origin',
            'state.lowest_x<state.remote_x-32',
            'native-homeward-no-physical-path'):
            self.assertIn(guard,block)
        for forbidden in ('surface.create_entity', 'train.speed=', 'priest.teleport(',
                          'set_driver(', 'game.create_inventory('):
            self.assertNotIn(forbidden,block)
        self.assertIn('return M.service_first_train_return_0836(pair)',rail)
        self.assertIn('RETURN_NATIVE_0836 elapsed=',fixture)
        self.assertIn('fail("HOMEWARD_CLAIM_WITHOUT_ORIGINAL_NATIVE_TRAIN_ARRIVAL")',fixture)
        self.assertIn('train.station==(objective.first_stop_0836',fixture)
        for old in ('s.returned=true end', 'if s.outbound and loco.position.x<=28'):
            self.assertNotIn(old,fixture)

    def test_historical_outbound_native_receipt_survives_only_identical_homeward_train(self):
        # Once the actual train begins the original homeward order, Factorio
        # clears train.station. That cannot erase a previously witnessed native
        # outbound arrival or authorize a substituted driver/stop/train.
        root=pathlib.Path(__file__).resolve().parents[2]
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        block=fixture.split('local outbound=objective and objective.first_outbound_0836',1)[1].split(
            'local drills=surface.find_entities_filtered{',1)[0]
        for required in (
            'outbound.arrived_tick~=nil',
            'outbound.highest_x>outbound.origin_x+32',
            'native_driver==p.priest',
            'moving_train.station==remote_entity',
            'homeward.home_order_written==true',
            'homeward.train_id==moving_train.id',
            'outbound.train_id==moving_train.id',
            'homeward.priest_unit==p.priest.unit_number',
            'homeward.remote_stop_unit==remote_entity.unit_number',
            'homeward.home_stop_unit==home_entity.unit_number',
            'fail("OUTBOUND_CLAIM_WITHOUT_ORIGINAL_NATIVE_TRAIN_ARRIVAL")'):
            self.assertIn(required,block)
        self.assertNotIn('or outbound.phase==',block)
        self.assertIn('HOMEWARD_CLAIM_WITHOUT_ORIGINAL_NATIVE_TRAIN_ARRIVAL',block)
        self.assertIn('train.station==(objective.first_stop_0836',fixture)

    def test_historical_outbound_gate_parentheses_parse_boundary(self):
        # Real Factorio save creation loads the CI fixture as Lua, whereas
        # earlier source-only assertions did not parse it. The native run
        # 43569268892 failed before a test-save process or engine checkpoint.
        # Ensure the original historical-arrival Boolean gate remains
        # syntactically balanced while keeping ALL identity requirements.
        root=pathlib.Path(__file__).resolve().parents[2]
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(
            encoding="utf-8")
        gate=fixture.split('  if outbound and outbound.phase==\n',1)[1].split(
            'then\n    fail("OUTBOUND_CLAIM_WITHOUT_ORIGINAL_NATIVE_TRAIN_ARRIVAL")',1)[0]
        depth=0
        for char in gate:
            if char=="(": depth+=1
            if char==")":
                depth-=1
                self.assertGreaterEqual(depth,0,"extra Lua close parenthesis in native gate")
        self.assertEqual(depth,0,"unclosed Lua gate parenthesis")
        for proof in ("homeward.home_order_written==true",
                      "native_driver==p.priest",
                      "homeward.train_id==moving_train.id",
                      "homeward.home_stop_unit==home_entity.unit_number"):
            self.assertIn(proof,gate)

    def test_homeward_refuses_schedule_or_identity_mutation_without_claiming_return(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        block=rail.split('function M.service_first_train_return_0836(pair)',1)[1].split(
            'function M.service_pair(pair)',1)[0]
        for refusal in ('native-homeward-original-identity-or-outward-gate-missing',
                        'native-homeward-original-magos-not-driver',
                        'native-homeward-paid-stop-disconnected',
                        'native-homeward-schedule-foreign-or-unreadable',
                        'native-homeward-original-identity-changed',
                        'native-homeward-two-stop-readback-failed',
                        'native-homeward-departure-native-refusal'):
            self.assertIn(refusal,block)
        self.assertIn('state.home_order_written=true',block)
        self.assertLess(block.index('state.home_order_written=true'),
                        block.index('schedule.add_record{station=home_name'))

class OriginalNativeOutboundScheduleGuardTests(unittest.TestCase):
    """Focused boundaries only; actual travel requires real Factorio readback."""
    def test_paid_remote_stop_original_driver_and_live_fuel_precede_schedule_write(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        block=rail.split("function M.service_first_train_outbound_0836(pair)",1)[1].split(
            "function M.service_pair(pair)",1)[0]
        for required in (
            'far.phase=="native-paid-original-train-stop-verified"',
            'home.phase=="native-paid-original-train-stop-verified"',
            'engine.train.id==wagon.built_entity.train.id',
            'driver==priest',
            'ride.physical_boarding_confirmed==true',
            'ride.boarded_priest_unit==priest.unit_number',
            'remote.connected_rail',
            'unit==remote_rail.unit_number',
            'original-outbound-identity-changed',
            'original-outbound-no-observed-native-fuel',
            'original-train-has-foreign-schedule',
            'schedule.add_record{station=unique',
            'schedule.get_records()',
            'schedule.go_to_station(1)',
            'train.station==remote',
        ):
            self.assertIn(required,block)
        self.assertLess(block.index('original-train-has-foreign-schedule'),
                        block.index('remote.backer_name=unique'))
        self.assertLess(block.index('original-outbound-no-observed-native-fuel'),
                        block.index('remote.backer_name=unique'))
        self.assertLess(block.index('state.schedule_write_attempted=true'),
                        block.index('schedule.add_record{station=unique'))
        self.assertLess(block.index('schedule.get_records()',block.index('schedule.add_record')),
                        block.index('schedule.go_to_station(1)'))
        self.assertNotIn('train.speed=',block)
        self.assertNotIn('train.schedule=',block)
        self.assertNotIn('priest.teleport(',block)
        self.assertNotIn('create_entity(',block)
        self.assertNotIn('inventory.insert',block)

    def test_original_outbound_only_after_native_boarding_and_pays_no_ghost_credit(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        run=rail.split("function M.service_pair(pair)",1)[1]
        self.assertIn('if boarded and boarded.phase=="native-original-magos-boarded"then',run)
        self.assertIn("return M.service_first_train_outbound_0836(pair)",run)
        self.assertIn("return M.service_first_train_board_0836(pair)",run)
        self.assertLess(run.index('M.service_first_train_stop_0836(pair,"remote")'),
                        run.index("M.service_first_train_outbound_0836(pair)"))

    def test_fixture_requires_real_train_coordinates_driver_and_station(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        block=fixture.split('emit("OUTBOUND_NATIVE_0836 elapsed="',1)[1].split(
            'local drills=',1)[0]
        for token in ('original_priest_driver=', 'locomotive_x=', 'origin_x=',
                      'highest_x=', 'speed=', 'has_path=', 'actual_station_unit=',
                      'remote_stop_unit=', 'schedule_station=', 'blocked='):
            self.assertIn(token,block)
        self.assertIn("OUTBOUND_CLAIM_WITHOUT_ORIGINAL_NATIVE_TRAIN_ARRIVAL",block)
        self.assertIn('moving_train.station==remote_entity',block)
        self.assertIn('native_driver==p.priest',block)
        self.assertIn('{1800,9000,18000,36000,60000,72000,90000}',fixture)
        self.assertNotIn('surface.create_entity{name="iron-ore"',fixture)


class NativeRailDirectionalStopAdmissionTests(unittest.TestCase):
    def test_distant_stop_faces_original_eastbound_train_and_home_faces_return(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        source=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        stop=source.split("function M.service_first_train_stop_0836(pair,role)",1)[1].split(
            "function M.service_first_train_board_0836(pair)",1)[0]
        self.assertIn("local offsets=remote and {2,3} or {-2,-3}",stop)
        self.assertIn("local heading=offset<0 and cardinal.west or cardinal.east",stop)
        self.assertIn("surface.can_place_entity{",stop)
        self.assertIn("if not chosen then return false",stop)
        self.assertNotIn("for _,offset in ipairs({-2,2,-3,3})",stop)
        self.assertNotIn("surface.create_entity(",stop)
        self.assertNotIn("teleport(",stop)


class NativeRailOrphan0702HandoffTests(unittest.TestCase):
    def test_original_0702_alone_may_release_finished_unladen_route(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        family=(root/"tech-priests_src/scripts/core/item_family_logistics_0702.lua").read_text(encoding="utf-8")
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        fixture=(root/"tests/scenarios/remote-rail-acquisition/fixture.lua").read_text(encoding="utf-8")
        section=family.split("function M.release_orphaned_movement_for_rail_0836(pair)",1)[1].split(
            "function M.abort_pair(pair, reason)",1)[0]
        for marker in ('pair.item_family_logistics_0702~=nil',
                       'pair.item_family_custody_0702~=nil',
                       'request.owner~="item-family-logistics-0702"',
                       'type(controller.request_status)=="function"',
                       'type(controller.stop)=="function"',
                       'status.owner_match==true',
                       'status.owner=="item-family-logistics-0702"',
                       'pcall(controller.stop,pair,"orphan-0702-after-physical-task")',
                       'pair.movement_request_0418==nil',
                       'return false,"canonical-route-owner-mismatch"'):
            self.assertIn(marker,section)
        for forbidden in ("remove_item(", "insert(", "destroy(", "teleport(",
                          "pair.item_family_logistics_0702=nil",
                          "pair.item_family_custody_0702=nil"):
            self.assertNotIn(forbidden,section)
        board=rail.split("function M.service_first_train_board_0836(pair)",1)[1].split(
            "function M.service_first_train_outbound_0836(pair)",1)[0]
        self.assertLess(board.index('fuel_now~=true'),board.index(
            'release_orphaned_movement_for_rail_0836'))
        self.assertLess(board.index('pair.machine_logistics_custody_0528'),board.index(
            'release_orphaned_movement_for_rail_0836'))
        self.assertLess(board.index('release_orphaned_movement_for_rail_0836'),board.index(
            'state.last_blocker="boarding-foreign-movement-owned"'))
        for marker in ("item_family_phase_0702=", "item_family_item_0702=",
                       "item_family_custody_0702="):
            self.assertIn(marker,fixture)

class NativeRailBoardingLeashAuthority0836Tests(unittest.TestCase):
    """Existing 0418/0566/0574 must honor only the original paid boarding lane."""

    def test_paid_boarding_requires_native_stops_train_fuel_original_priest_and_no_custody(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        rail=(root/"tech-priests_src/scripts/core/rail_track_frontier_0836.lua").read_text(encoding="utf-8")
        block=rail.split("function M.authorized_original_train_boarding_walk_0836(pair,point,movement)",1)[1].split(
            "function M.service_first_train_board_0836(pair)",1)[0]
        for marker in ('storage.tech_priests.pairs_by_station[pair.station.unit_number]==pair',
                       'pair.priest.type=="character"',
                       'movement.reason=="original-train-physical-boarding-0836"',
                       'movement.reason=="movement-enforcement-overleash-return-0566"',
                       'pair.movement_request_0418==movement',
                       'and route.chain_audit_completed_tick_0836',
                       'route.segment==#route.built_units',
                       'lead.paid_completion_0836.native_0338_paid==true',
                       'wagon.paid_completion_0836.native_0338_paid==true',
                       'home.phase=="native-paid-original-train-stop-verified"',
                       'remote.phase=="native-paid-original-train-stop-verified"',
                       'receipt.before-receipt.after==1',
                       'entity.connected_rail',
                       'loco.train.id==wagon.built_entity.train.id',
                       'inv.get_item_count("coal")',
                       'not pair.machine_logistics_custody_0528',
                       'not pair.construction_custody_0338',
                       'not pair.item_family_logistics_0702',
                       'pair.item_family_logistics_0702.rail_deferred_0836==true',
                       'pair.item_family_logistics_0702.phase=="move-to-source"',
                       'pair.item_family_logistics_0702.carried==nil',
                       'valid(pair.item_family_logistics_0702.source_entity)',
                       'valid(pair.item_family_logistics_0702.target)',
                       'not pair.item_family_custody_0702',
                       'connected_straight_rails(before,middle)',
                       'connected_straight_rails(middle,after)'):
            self.assertIn(marker,block)
        for forbidden in ('teleport(', 'create_entity(', 'set_driver(', 'insert(', 'remove_item(',
                          'bounds_exempt', 'force_retarget'):
            self.assertNotIn(forbidden,block)

    def test_canonical_enforcement_releases_only_own_safety_and_preserves_live_boarding(self):
        root=pathlib.Path(__file__).resolve().parents[2]
        controller=(root/"tech-priests_src/scripts/core/movement_controller.lua").read_text(encoding="utf-8")
        corridor=(root/"tech-priests_src/scripts/core/authority_corridor_pathing_0574.lua").read_text(encoding="utf-8")
        enforce=controller.split("function M.enforce_pair(pair, reason)",1)[1]
        self.assertLess(enforce.index("original-paid-train-boarding-safety-handoff-0836"),
                        enforce.index("if distance > M.hard_leash(pair)"))
        self.assertIn('M.stop(pair,"original-paid-train-boarding-safety-handoff-0836")',enforce)
        self.assertIn('request.owner=="rail-track-frontier-0836"',enforce)
        self.assertIn('return false,"original-paid-train-boarding-route-owned-0836"',enforce)
        self.assertIn('M.stop(pair, "movement-overleash-0566")',enforce)
        self.assertIn('return moved == true, "overleash-return"',enforce)
        position=controller.split("function M.position_allowed(pair, pos, reason, opts)",1)[1].split(
            "local function proxy_prime_allowed",1)[0]
        self.assertIn('opts.owner=="rail-track-frontier-0836"',position)
        self.assertIn('frontier.authorized_original_train_boarding_walk_0836,pair,pos',position)
        auth=corridor.split("function M.authorization_for_destination(pair, pos, reason, opts)",1)[1].split(
            "function M.position_allowed",1)[0]
        self.assertIn('opts.owner=="rail-track-frontier-0836"',auth)
        self.assertIn('frontier.authorized_original_train_boarding_walk_0836,pair,pos',auth)
        self.assertNotIn('bounds_exempt',auth)

