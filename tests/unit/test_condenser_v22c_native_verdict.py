"""Synthetic parser fixtures ONLY; never native Factorio evidence."""
import importlib.util
from pathlib import Path
import unittest

SOURCE=Path(__file__).resolve().parents[2]/'tools/run_factorio_isolated_service_scenario.py'
spec=importlib.util.spec_from_file_location("native_scenario_driver",SOURCE)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
verify=module.verify_condenser_v22c_physical_log
PREFIX="[TP-CONDENSER-V22C-PHYSICAL] "
SUCCESS=PREFIX+"PASS four original 2x2 V22C condensers with native direction-rotated output pipes"
RECORDS=[
    PREFIX+"NATIVE_CONNECTED facing=north machine=101 pipe=201 source_x=0.000 source_y=0.000 target_x=1.500 target_y=-0.500 segment=301",
    PREFIX+"NATIVE_CONNECTED facing=east machine=102 pipe=202 source_x=18.000 source_y=0.000 target_x=18.500 target_y=1.500 segment=302",
    PREFIX+"NATIVE_CONNECTED facing=south machine=103 pipe=203 source_x=0.000 source_y=18.000 target_x=-1.500 target_y=18.500 segment=303",
    PREFIX+"NATIVE_CONNECTED facing=west machine=104 pipe=204 source_x=18.000 source_y=18.000 target_x=17.500 target_y=16.500 segment=304",
]

def log(records=RECORDS,final=SUCCESS):
    return "\n".join([*records,final])

class FailClosedNativeReceipt(unittest.TestCase):
    def test_exact_cardinal_native_receipt_parser(self):
        result=verify(0,log())
        self.assertTrue(result["accepted"])
        self.assertEqual(result["real_entities"],8)
        self.assertEqual(result["fluid_segments"],4)
        self.assertEqual(set(result["directions"]),{"north","east","south","west"})
    def test_reject_one_missing_heading(self):
        with self.assertRaises(ValueError):verify(0,log(RECORDS[:3]))
    def test_reject_repeated_heading(self):
        with self.assertRaises(ValueError):verify(0,log(RECORDS+[RECORDS[0]]))
    def test_reject_fake_exit_or_explicit_failure(self):
        with self.assertRaises(ValueError):verify(1,log())
        with self.assertRaises(ValueError):verify(0,log()+"\n"+PREFIX+"FAIL actual engine")
    def test_reject_wrong_rotated_port(self):
        with self.assertRaisesRegex(ValueError,"rotate outward"):
            verify(0,log([RECORDS[0].replace("target_x=1.500","target_x=-1.500"),*RECORDS[1:]]))
    def test_reject_duplicate_machine_identity(self):
        with self.assertRaises(ValueError):
            verify(0,log([RECORDS[0],RECORDS[1].replace("machine=102","machine=101"),*RECORDS[2:]]))
    def test_reject_fabricated_final_only(self):
        with self.assertRaises(ValueError):verify(0,SUCCESS)

if __name__=="__main__":unittest.main()
