"""Native-independent regression gates for concrete Pipette V1 mesh recipes.

Unlike index tests, these tests generate and inspect actual vertex/face meshes.
Blender/GLB reopen and optical proof remain separate native acceptance gates.
"""
from __future__ import annotations

import math
from pathlib import Path
import tempfile
import unittest

import library_geometry as lib


class LibraryGeometryTests(unittest.TestCase):
    def setUp(self):
        self.rig = lib.source_json("comparison_fixture.v1.json")
        self.a=(-1.2, 0., .65)
        self.b=(1.2, 0., .65)

    def test_recipes_cover_real_source_architectures(self):
        cat=lib.source_json("architecture_catalog.v1.json")
        entries={p["id"] for p in cat["architecture_types"]}
        self.assertTrue(set(lib.RECIPES).issubset(entries))
        self.assertGreaterEqual(len(lib.RECIPES), 18)

    def test_diameter_and_presets_are_relative(self):
        part=lib.tube([self.a,self.b],.12,.20,"smooth","smoke",
                      "pipe_galvanized_threaded")
        self.assertTrue(part["true_open_bore"])
        self.assertAlmostEqual(part["bore_diameter_bu"],.096)
        self.assertFalse(part["preview_only"] is False)

    def test_open_pipe_has_actual_radial_wall_and_open_bore(self):
        part=lib.tube([self.a,self.b],.12,.2,"smooth","pipe",
                      "pipe_galvanized_threaded",sides=20)
        self.assertGreater(len(part["vertices"]),100)
        self.assertGreater(len(part["faces"]),100)
        self.assertEqual(len(part["vertices"])%40,0)
        self.assertEqual(part["role"],"hollow-section")
        self.assertTrue(all(len(f)==4 for f in part["faces"]))

    def test_smooth_corrugated_and_metal_interlocked_not_same_surface(self):
        args=([self.a,self.b],.12,.22)
        smooth=lib.tube(*args,"smooth","straight","conduit_emt_thinwall")
        annular=lib.tube(*args,"annular_polymer","ringed","conduit_ent_corrugated",pitch=.12)
        spiral=lib.tube(*args,"interlocked_metal","helical","conduit_fmc_interlocked",pitch=.12)
        # An annular ring has equal radii around each circular ring; a
        # helically phase-shifted ring does NOT.
        def radii(mesh):
            ring=mesh["vertices"][:20]
            return [math.hypot(x[1],x[2]-.65) for x in ring]
        self.assertLess(max(radii(smooth))-min(radii(smooth)),1e-7)
        self.assertLess(max(radii(annular))-min(radii(annular)),1e-7)
        self.assertGreater(max(radii(spiral))-min(radii(spiral)),.005)

    def test_split_loom_has_longitudinal_gap(self):
        item=lib.tube([self.a,self.b],.12,.20,"split_annular","split loom",
                      "conduit_split_corrugated_loom")
        self.assertTrue(item["longitudinal_slit"])
        n=21
        self.assertEqual(len(item["vertices"])%(n*2),0)
        self.assertTrue(item["true_open_bore"])
        self.assertLess(item["sample_rings"],lib.MAX_RINGS)

    def test_real_helical_wrap_with_air_gaps(self):
        item=lib.helical_ribbon([self.a,self.b],.12,.11,.055,.008,
                    "spiral","conduit_helical_plastic_wrap")
        self.assertEqual(item["profile_kind"],"true-helical-ribbon")
        self.assertFalse(item["true_open_bore"])
        self.assertGreater(len(item["vertices"]),300)
        self.assertGreater(len(item["faces"]),200)

    def test_interlocked_metal_has_separate_seam_mesh(self):
        parts=lib.line_segment(self.a,self.b,"conduit_fmc_interlocked")
        self.assertEqual(len(parts),2)
        self.assertTrue(parts[0]["true_open_bore"])
        self.assertEqual(parts[1]["role"],"metal-interlock-seam")
        self.assertEqual(parts[1]["profile_kind"],"true-helical-ribbon")

    def test_metal_annular_and_metal_helical_are_distinct(self):
        ann=lib.line_segment(self.a,self.b,"hose_metal_annular")
        hel=lib.line_segment(self.a,self.b,"hose_metal_helical")
        self.assertEqual(ann[0]["profile_kind"],"annular_metal")
        self.assertEqual(hel[0]["profile_kind"],"helical_metal")

    def test_eight_strands_have_unique_deterministic_sag(self):
        first=lib.wire_cores(self.a,self.b,"wire_eight_loose_bundle")
        second=lib.wire_cores(self.a,self.b,"wire_eight_loose_bundle")
        self.assertEqual(len(first),8)
        self.assertEqual(len(second),8)
        sags=[p["sag_blender_units"] for p in first]
        self.assertEqual(len(set(sags)),8)
        self.assertTrue(all(p["public_port_centers_unchanged"]
                            ==[list(self.a),list(self.b)] for p in first))
        self.assertEqual([p["vertices"] for p in first],
                         [p["vertices"] for p in second])
        self.assertNotEqual(first[0]["vertices"],first[1]["vertices"])

    def test_cores_fan_within_common_nominal_socket(self):
        parts=lib.wire_cores(self.a,self.b,"wire_eight_loose_bundle")
        for p in parts:
            for endpoint, public in zip((p["centerline_start"],p["centerline_end"]),
                                        (self.a,self.b)):
                self.assertLess(math.dist(endpoint,public),.06)

    def test_flexible_line_sags_but_fixed_metal_does_not(self):
        soft=lib.line_segment(self.a,self.b,"hose_rubber_coolant")[0]
        fixed=lib.line_segment(self.a,self.b,"pipe_galvanized_threaded")[0]
        # Mid-point ring centroid is below the outer anchor plane for hose.
        def center_z(part):
            points=part["vertices"]
            rings=part["sample_rings"]
            ring_size=len(points)//rings
            mid=rings//2
            return sum(p[2] for p in points[mid*ring_size:(mid+1)*ring_size])/ring_size
        self.assertLess(center_z(soft), center_z(fixed)-.10)

    def test_y_public_ports_exact_and_identical_across_different_materials(self):
        keys=("pipe_lead_historical","conduit_fmc_interlocked",
              "conduit_ent_corrugated","wire_eight_loose_bundle")
        demos=[lib.build_demo(k,"wye") for k in keys]
        ports=[m["public_ports"] for m in demos]
        self.assertTrue(all(a==ports[0] for a in ports[1:]))
        self.assertEqual(len(ports[0]),3)
        self.assertEqual(demos[0]["nominal_outer_diameter_bu"],.12)
        self.assertTrue(demos[0]["requires_native_csg_manifold"])
        self.assertFalse(demos[-1]["requires_native_csg_manifold"])
        self.assertTrue(all(m["meshes"] for m in demos))

    def test_all_implemented_recipes_build_actual_straight_meshes(self):
        for name in lib.RECIPES:
            with self.subTest(name=name):
                model=lib.build_demo(name,topology="straight")
                self.assertGreater(len(model["meshes"]),0)
                self.assertTrue(all(part["vertices"] and part["faces"]
                                    for part in model["meshes"]))
                self.assertFalse(model["requires_native_csg_manifold"])

    def test_export_obj_is_real_nonempty_editable_geometry(self):
        model=lib.build_demo("conduit_ent_corrugated","straight")
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/"corrugated.obj"
            lib.export_obj(model,target)
            text=target.read_text()
            self.assertIn("\nv ",text)
            self.assertIn("\nf ",text)
            self.assertGreater(target.stat().st_size,1000)
            with self.assertRaises(FileExistsError):
                lib.export_obj(model,target)

    def test_invalid_dimensions_and_unsupported_names_fail_closed(self):
        with self.assertRaises(ValueError):
            lib.tube([self.a,self.b],-.12,.2,"smooth","x","pipe_galvanized_threaded")
        with self.assertRaises(ValueError):
            lib.helical_ribbon([self.a,self.b],.12,.08,.085,.01,
                               "x","conduit_helical_plastic_wrap")
        with self.assertRaises(ValueError):
            lib.build_demo("unimplemented_holographic_pipe","straight")
        with self.assertRaises(ValueError):
            lib.build_demo("conduit_pvc_rigid","invented-topology")


if __name__=="__main__":
    unittest.main()
