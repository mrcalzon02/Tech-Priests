"""Read-only source acceptance of Tech-Priests custom damage types and roster.

Run: python -m unittest discover -s tests/unit -p test_combat_damage_taxonomy_contract.py
Does not load a Factorio prototype or claim a native combat balance result.
"""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools import check_combat_damage_taxonomy as audit


SOURCES = (audit.TAXONOMY, audit.REGISTRATION, audit.ENTRY,
           audit.CATALOG, audit.ARMORY, audit.LOCALE)


class DamageTaxonomySourceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name in SOURCES:
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(audit.ROOT / name, destination)

    def replace(self, name, original, new):
        file = self.root / name
        raw = file.read_text(encoding="utf-8-sig")
        self.assertIn(original, raw)
        file.write_text(raw.replace(original, new, 1), encoding="utf-8")

    def test_exact_four_types_ten_ammo_families_and_fifteen_actors(self):
        result = audit.inspect(self.root)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["combat_units"], 15)
        self.assertEqual(set(result["current_ammo_families"]), set(audit.FAMILIES))
        self.assertEqual(tuple(result["damage_types_declared"]), audit.CUSTOM)
        self.assertFalse(result["roster_damage_reclassified"])
        self.assertFalse(result["prototype_engine_tested"])
        self.assertFalse(result["wall_variants_implemented"])

    def test_source_audit_does_not_write_or_modify_any_input(self):
        before = {name: (self.root / name).read_bytes() for name in SOURCES}
        audit.inspect(self.root)
        self.assertEqual(before, {name: (self.root / name).read_bytes() for name in SOURCES})

    def test_missing_english_damage_type_locale_is_rejected(self):
        self.replace(audit.LOCALE, "tech-priests-corrosive=Corrosive",
                     "tech-priests-corrosion=Corrosion")
        with self.assertRaisesRegex(audit.ContractError, "localized"):
            audit.inspect(self.root)

    def test_type_registry_drift_requires_explicit_audit_update(self):
        self.replace(audit.REGISTRATION, 'name="tech-priests-gravitic"',
                     'name="tech-priests-gravity"')
        with self.assertRaisesRegex(audit.ContractError, "definitions"):
            audit.inspect(self.root)

    def test_damage_types_must_load_before_bunkers(self):
        file = self.root / audit.ENTRY
        raw = file.read_text()
        statement = 'require("prototypes.combat_damage_types").register()\n'
        self.assertEqual(raw.count(statement), 1)
        raw = raw.replace(statement, "")
        raw += "\n" + statement
        file.write_text(raw)
        with self.assertRaisesRegex(audit.ContractError, "before custom combat"):
            audit.inspect(self.root)

    def test_roster_ammo_retyping_requires_reviewed_source_update(self):
        self.replace(audit.CATALOG, '["damage_type"]="poison"',
                     '["damage_type"]="tech-priests-radiation"')
        with self.assertRaisesRegex(audit.ContractError, "differs from generated source"):
            audit.inspect(self.root)

    def test_review_cannot_claim_live_ammo_conversion_without_evidence(self):
        file = self.root / audit.TAXONOMY
        record = json.loads(file.read_text())
        record["ammo_families"][0]["implemented_in_ammo"] = True
        file.write_text(json.dumps(record))
        with self.assertRaisesRegex(audit.ContractError, "not a live weapon"):
            audit.inspect(self.root)

    def test_invalid_damage_component_budget_rejected(self):
        file = self.root / audit.TAXONOMY
        record = json.loads(file.read_text())
        record["ammo_families"][0]["proposed_damage_components"][0]["portion"] = 1.2
        file.write_text(json.dumps(record))
        with self.assertRaisesRegex(audit.ContractError, "sum to one"):
            audit.inspect(self.root)

    def test_wall_prototype_does_not_appear_built_because_it_is_planned(self):
        file = self.root / audit.TAXONOMY
        record = json.loads(file.read_text())
        record["wall_profile_targets"][0]["status"] = "implemented"
        file.write_text(json.dumps(record))
        with self.assertRaisesRegex(audit.ContractError, "masquerade"):
            audit.inspect(self.root)

    def test_duplicate_generated_ammo_family_rejected(self):
        self.replace(audit.CATALOG, '["galvanic"]={', '["bolt"]={')
        with self.assertRaisesRegex(audit.ContractError, "duplicate|Unexpected"):
            audit.inspect(self.root)


if __name__ == "__main__":
    unittest.main()
