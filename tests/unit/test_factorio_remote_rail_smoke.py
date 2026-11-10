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
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "tools"))
from run_factorio_isolated_service_scenario import (
    factorio_runtime_compatible, rail_connected_smoke_verdict,
    rail_smoke_evidence, reset_rail_smoke_diagnostics)
P = "[TP-REMOTE-RAIL-TEST] "
A = P + "PASS first physical rail built and exact stock debited"
B = P + "PASS two distinct 0338-debited native-connected rails"

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
            for name in ("rail-connected-smoke-result.json", "benchmark.log"):
                (output / name).write_text("STALE PASS", encoding="utf-8")
            reset_rail_smoke_diagnostics(output)
            self.assertFalse((output / "benchmark.log").exists())
            self.assertFalse((output / "rail-connected-smoke-result.json").exists())
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
