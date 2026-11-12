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
    PREFIX+"NATIVE_CONNECTED facing=north machine=101 pipe=201 source_x=0.000 source_y=0.000 target_x=1.500 target_y=-0.500 segment=301 segment_state=formed",
    PREFIX+"NATIVE_CONNECTED facing=east machine=102 pipe=202 source_x=18.000 source_y=0.000 target_x=18.500 target_y=1.500 segment=302 segment_state=formed",
    PREFIX+"NATIVE_CONNECTED facing=south machine=103 pipe=203 source_x=0.000 source_y=18.000 target_x=-1.500 target_y=18.500 segment=303 segment_state=formed",
    PREFIX+"NATIVE_CONNECTED facing=west machine=104 pipe=204 source_x=18.000 source_y=18.000 target_x=17.500 target_y=16.500 segment=304 segment_state=formed",
]

def log(records=RECORDS,final=SUCCESS):
    return "\n".join([*records,final])

class FailClosedNativeReceipt(unittest.TestCase):
    def test_exact_cardinal_native_receipt_parser(self):
        result=verify(0,log())
        self.assertTrue(result["accepted"])
        self.assertEqual(result["real_entities"],8)
        self.assertEqual(result["fluid_segments_confirmed"],4)
        self.assertEqual(result["connected_pipes"],4)
        self.assertEqual(set(result["directions"]),{"north","east","south","west"})
    def test_allow_genuine_connected_unformed_segments(self):
        """On Factorio 2.1 on_init, native pipe targets precede fluid segments."""
        unformed = [record.replace("segment=30"+str(i),
                                  "segment=0").replace("segment_state=formed",
                                                       "segment_state=unformed")
                    for i,record in enumerate(RECORDS,1)]
        result=verify(0,log(unformed))
        self.assertEqual(result["connected_pipes"],4)
        self.assertEqual(result["fluid_segments_confirmed"],0)
        self.assertEqual(result["connections_unformed"],4)
    def test_allow_genuine_native_forming_segments_without_fake_ids(self):
        """One-sided native segment creation is a real deferred engine state."""
        forming = [record.replace("segment=30"+str(i),
                                  "segment=0").replace("segment_state=formed",
                                                       "segment_state=forming")
                   for i,record in enumerate(RECORDS,1)]
        result=verify(0,log(forming))
        self.assertEqual(result["real_entities"],8)
        self.assertEqual(result["connected_pipes"],4)
        self.assertEqual(result["fluid_segments_confirmed"],0)
        self.assertEqual(result["connections_unformed"],0)
        self.assertEqual(result["connections_forming"],4)
    def test_reject_fabricated_forming_segment_id(self):
        with self.assertRaisesRegex(ValueError,"fabricated"):
            verify(0,log([RECORDS[0].replace("segment_state=formed",
                                            "segment_state=forming"),*RECORDS[1:]]))
    def test_reject_fabricated_unformed_segment_id(self):
        with self.assertRaisesRegex(ValueError,"fabricated"):
            verify(0,log([RECORDS[0].replace("segment_state=formed",
                                            "segment_state=unformed"),*RECORDS[1:]]))
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
