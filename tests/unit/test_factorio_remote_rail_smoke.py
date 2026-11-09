#!/usr/bin/env python3
"""Focused regression for the existing real-Factorio connected-rail gate.

Run with: python3 -m unittest discover -s tests/unit -p test_factorio_remote_rail_smoke.py
These string-verdict tests are NOT themselves native rail acceptance.
"""
import pathlib
import sys
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "tools"))
from run_factorio_isolated_service_scenario import (
    factorio_runtime_compatible, rail_connected_smoke_verdict)
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
