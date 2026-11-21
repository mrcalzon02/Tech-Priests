#!/usr/bin/env python3
"""Source-contract guard for the live AAI recruitable combat roster.

This is deliberately not a substitute for Factorio 2.1 native actor testing.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tech-priests_src"


def read(path):
    return (SOURCE / path).read_text(encoding="utf-8")


class IntegratedCombatRoster(unittest.TestCase):
    def test_aai_is_hard_dependency(self):
        info = json.loads(read("info.json"))
        aai = [d for d in info["dependencies"] if "aai-programmable-vehicles" in d]
        self.assertEqual(aai, ["aai-programmable-vehicles >= 0.9.2"])

    def test_data_stage_has_exactly_one_actor_owner(self):
        data = read("data.lua")
        self.assertEqual(data.count('require("prototypes.combat_roster").register()'), 1)
        self.assertNotIn('require("prototypes.combat_armory").register()', data)
        self.assertEqual(
            read("data-final-fixes.lua").count(
                'require("prototypes.combat_roster").finalize()'), 1)

    def test_all_15_units_and_original_factories(self):
        catalog = read("shared/combat_roster_catalog.lua")
        self.assertEqual(len(re.findall(
            r'\["id"\]="[^"]+"', catalog.split('["ammo"]=', 1)[0])), 15)
        factories = read("prototypes/faction_factories.lua")
        for name in ("martian-manufactorum", "guard-muster-hall", "sororitas-convent"):
            self.assertIn("tech-priests-" + name, factories)
        actor = read("prototypes/combat_roster.lua")
        self.assertIn("data.raw.quality and data.raw.quality.uncommon", actor)
        self.assertIn("AAI composite missing:", actor)

    def test_required_control_installers(self):
        control = read("control.lua")
        for module in ("character_visuals", "combat_roster_bridge",
                       "combat_roster_orders", "combat_muster_gui"):
            self.assertEqual(control.count(
                'require("scripts.core.' + module + '").install()'), 1)

    def test_physical_ownership_preserved(self):
        orders = read("scripts/core/combat_roster_orders.lua")
        constructor = read("scripts/core/construction_planner.lua")
        logistics = read("scripts/core/item_family_logistics_0702.lua")
        dispatcher = read("scripts/core/single_dispatcher_0510.lua")
        self.assertIn("combat_construction_request", orders)
        self.assertIn('"combat_construction_request"', constructor)
        self.assertIn("function M.offer_combat_supply(", logistics)
        self.assertIn("function M.on_combat_replaced(", logistics)
        self.assertIn("local muster=package.loaded", dispatcher)
        self.assertIn("paid-combat-muster", dispatcher)
        self.assertIn("reinforced-unit-needs-exact-native-stack-custody", orders)

    def test_native_battle_fixture_is_not_wip(self):
        self.assertTrue((ROOT / "tests/scenarios/combat-roster/fixture.lua").is_file())
        self.assertTrue((ROOT / "tools/run_combat_roster_native.py").is_file())
        native = (ROOT / "tools/run_combat_roster_native.py").read_text()
        self.assertIn("AAI_NATIVE_DEPENDENCY_MISSING", native)
        self.assertIn("Refusing to overwrite nonempty test output directory", native)


if __name__ == "__main__":
    unittest.main(verbosity=2)
