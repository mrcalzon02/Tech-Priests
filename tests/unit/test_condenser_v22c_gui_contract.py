"""Static regression only. NOT evidence of a graphical Factorio run."""
from __future__ import annotations
import ast
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
CAPTURE=ROOT/"ci/condenser_v22c/visual_capture.py"
FIXTURE=ROOT/"ci/condenser_v22c/visual_client_control.lua"
LAUNCH=ROOT/"ci/condenser_v22c/launch_from_interactive_desktop.ps1"
CMD=ROOT/"RUN_CONDENSER_V22C_IN_GAME_CAPTURE.cmd"

class SourceLockedGuiFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.python=CAPTURE.read_text(encoding="utf-8")
        cls.lua=FIXTURE.read_text(encoding="utf-8")
        cls.ps=LAUNCH.read_text(encoding="utf-8")
        cls.cmd=CMD.read_text(encoding="utf-8")

    def test_python_compiles_without_executing_factorio(self):
        ast.parse(self.python, filename=str(CAPTURE))
    def test_eight_real_machines_and_sockets_are_required(self):
        self.assertIn("ensure(machines==8 and pipes==8 and working==4 and #shots==16",self.lua)
        self.assertIn("machine.get_fluid_box_pipe_connections(1)",self.lua)
        self.assertIn("machine.get_fluid_box_neighbours(1)",self.lua)
        self.assertIn('name="pipe"',self.lua)
        self.assertIn('burner.inventory.insert{name="coal",count=30}',self.lua)
        self.assertIn("game.take_screenshot{",self.lua)
        self.assertIn("game.set_wait_for_screenshots_to_finish()",self.lua)
    def test_four_direction_two_state_two_zoom_contract(self):
        self.assertIn('DIRECTIONS = ("north", "east", "south", "west")',self.python)
        self.assertIn('STATES = ("idle", "working")',self.python)
        self.assertIn('ZOOMS = ("normal", "close")',self.python)
        self.assertIn('local STATES={"idle","working"}',self.lua)
        self.assertIn('local ZOOMS={{"normal",1.0},{"close",2.7}}',self.lua)
    def test_no_renaming_of_real_pngs_and_headless_rejected(self):
        self.assertIn('target=userdata/"script-output"/"condenser-v22c"',self.python)
        self.assertIn("require_interactive_desktop()",self.python)
        self.assertIn("NO VERIFIED GRAPHICAL FACTORIO 2.1 CLIENT",self.python)
        self.assertIn("client-capture-error.json",self.python)
        self.assertIn("digest(candidate)!=digest(out/name)",self.python)
        self.assertIn("source_sha256",self.python)
        self.assertIn("original_blender_source_sha256",self.python)
        self.assertIn("visual_alignment_human_approved",self.python)
    def test_output_bundle_agrees_with_launcher(self):
        for name in ("condenser-v22c-real-game-four-directions.png",
                     "client-vs-approved-v22c-blender.png"):
            self.assertIn(name,self.python)
            self.assertIn(name,self.ps)
        self.assertIn("client-capture-qa.json",self.ps)
        self.assertIn("native_connected_pipes -ne 8",self.ps)
        self.assertIn("launch_from_interactive_desktop.ps1",self.cmd)
        self.assertIn("ci/condenser_v22c/visual-client-$stamp",self.ps)
    def test_screenshot_generator_does_not_mutate_project_source(self):
        self.assertIn("shutil.copytree(MOD,mods/\"tech-priests\")",self.python)
        self.assertIn('"--load-scenario","tp-condenser-v22c-visual/condenser-capture"',self.python)
        self.assertIn('temp/"user-data"',self.python)
        self.assertIn("if proc.poll() is None:",self.python)
        self.assertIn("proc.terminate()",self.python)

if __name__ == "__main__":
    unittest.main()
