#!/usr/bin/env python3
"""Regression contracts for source inventory and separate curated-map review.

Every write is confined to a temporary miniature repository. These checks
prove source/fingerprint behavior, not Lua execution or diagram semantics.
"""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import behavior_source_inventory as inventory
from audit_ups_hotspots_0743 import scan_risk


class BehaviorSourceInventoryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="tp-behavior-map-")
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        self.source = self.repo / "tech-priests_src"
        self.docs = self.repo / "docs"
        self.docs.mkdir()
        # Materialize the declared dependency contract without copying the
        # game code or relying on this checkout's generated artifacts.
        for name in inventory.CURATED_MAPS:
            (self.docs / name).write_text("# Reviewed fixture\n", encoding="utf-8")
        for number, dependencies in inventory.DRILLDOWN_SOURCES.items():
            name = f"BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_{number}_FIXTURE.md"
            (self.docs / name).write_text("# Reviewed drilldown fixture\n", encoding="utf-8")
            for dependency in dependencies:
                relative = dependency if dependency.endswith(".lua") else f"scripts/core/{dependency}.lua"
                self.write_source(relative.replace("*", "fixture"), "return {}\n")
        self.worker = self.write_source("scripts/core/inventory_fixture.lua", "return {install=function() end}\n")
        self.write_source("control.lua", 'local worker = require("scripts.core.inventory_fixture")\nworker.install()\n')

    def write_source(self, relative, content):
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def run_inventory(self, **options):
        output = StringIO()
        with redirect_stdout(output):
            result = inventory.run(self.repo, self.source, scan_risk, **options)
        return result, output.getvalue()

    def generated(self):
        return {name: (self.repo / name).read_bytes()
                for name in (inventory.JSON_PATH, inventory.MD_PATH)}

    def approve_fixture(self):
        self.assertEqual(self.run_inventory(write=True, acknowledge=True)[0], 0)
        self.assertEqual(self.run_inventory(check=True)[0], 0)

    def test_only_actual_lexical_calls_create_registrations(self):
        self.write_source("control.lua", '''
-- Broker.register_service({name="comment"})
--[=[ Registry.on_event(99, callback) ]=]
local quoted = "Registry.on_nth_tick(1, callback)"
local long_string = [=[Broker.register_service({name="long-string"})]=]
function Registry.on_event(event, callback) end
function Broker.register_service(specification) end
if type(Broker.register_service) == "function" then
  Broker.register_service{name="worker", category="maintenance", interval=60, budget=4, priority=7}
end
pcall(Broker.register_service, {name="protected-worker", interval=120})
if Registry.on_event then
  Registry.on_event(defines.events.on_tick, function(event) end, nil,
    {owner="fixture", route="clock"})
end
script.on_nth_tick(60, nil)
local worker = require("scripts.core.inventory_fixture")
local unresolved = require(module_name)
worker.install()
''')
        report = inventory.build_inventory(self.source, scan_risk)
        control = next(module for module in report["modules"] if module["module"] == "control")
        services = control["broker_services"]
        self.assertEqual([row["fields"]["name"]["literal"] for row in services],
                         ["worker", "protected-worker"])
        self.assertEqual(services[0]["fields"]["budget"]["literal"], 4)
        self.assertTrue(services[1]["protected_call"])
        self.assertEqual([(row["event"], row["action"]) for row in control["event_routes"]],
                         [("on_event", "register-or-forward"), ("on_nth_tick", "clear")])
        self.assertEqual(control["event_routes"][0]["options"]["owner"]["literal"], "fixture")
        self.assertEqual(len(control["dependencies"]), 1)
        self.assertEqual(control["unresolved_loads"][0]["argument"], "module_name")
        worker = next(module for module in report["modules"] if module["module"] == "scripts.core.inventory_fixture")
        self.assertEqual(worker["reachability"], "potential-literal-require-path")

    def test_generated_outputs_are_deterministic_and_do_not_create_review(self):
        self.assertEqual(self.run_inventory(write=True)[0], 0)
        first = self.generated()
        self.assertEqual(self.run_inventory(write=True)[0], 0)
        self.assertEqual(first, self.generated())
        self.assertFalse((self.repo / inventory.REVIEW_PATH).exists())
        result, output = self.run_inventory(check=True)
        self.assertEqual(result, 1)
        self.assertIn("curated review receipt missing/invalid", output)

    def test_source_drift_rejects_generated_output_and_review(self):
        self.approve_fixture()
        self.worker.write_text("return {install=function() return true end}\n", encoding="utf-8")
        result, output = self.run_inventory(check=True)
        self.assertEqual(result, 1)
        self.assertIn("stale generated artifact", output)
        self.assertIn("curated source/diagram review stale", output)

    def test_regeneration_cannot_acknowledge_changed_source(self):
        self.approve_fixture()
        receipt = self.repo / inventory.REVIEW_PATH
        original_review = receipt.read_bytes()
        self.worker.write_text("return {install=function() return false end}\n", encoding="utf-8")
        self.assertEqual(self.run_inventory(write=True)[0], 0)
        self.assertEqual(receipt.read_bytes(), original_review)
        result, output = self.run_inventory(check=True)
        self.assertEqual(result, 1)
        self.assertNotIn("stale generated artifact", output)
        self.assertIn("curated source/diagram review stale", output)
        self.assertEqual(self.run_inventory(acknowledge=True)[0], 0)
        self.assertEqual(self.run_inventory(check=True)[0], 0)

    def test_diagram_drift_requires_a_separate_review(self):
        self.approve_fixture()
        diagram = self.docs / "BEHAVIOR_MERMAID_MAP_0660.md"
        diagram.write_text('# Changed map\n```mermaid\nflowchart TD\nA["Changed behavior"]\n```\n', encoding="utf-8")
        self.assertEqual(self.run_inventory(write=True)[0], 0)
        result, output = self.run_inventory(check=True)
        self.assertEqual(result, 1)
        self.assertIn("curated source/diagram review stale: docs/BEHAVIOR_MERMAID_MAP_0660.md", output)
        self.assertNotIn("stale generated artifact", output)
        self.assertEqual(self.run_inventory(acknowledge=True)[0], 0)
        self.assertEqual(self.run_inventory(check=True)[0], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
