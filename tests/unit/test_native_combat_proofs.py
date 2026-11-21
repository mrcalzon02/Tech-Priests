#!/usr/bin/env python3
"""Offline evidence-pipeline regressions; never a Factorio gameplay PASS."""
import importlib.util
import pathlib
import struct
import tempfile
import unittest
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
ENCODER = ROOT / "tools/assemble_native_combat_proofs.py"
LAUNCHER = ROOT / "tools/run_combat_roster_native.py"
FIXTURE = ROOT / "tests/scenarios/combat-roster/batch_visual.lua"

spec = importlib.util.spec_from_file_location("native_combat_proofs", ENCODER)
assert spec and spec.loader
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)


def png_chunk(kind, payload):
    return (struct.pack(">I", len(payload)) + kind + payload +
            struct.pack(">I", zlib.crc32(payload, zlib.crc32(kind)) & 0xFFFFFFFF))


def tiny_valid_png():
    """A synthetic parser fixture ONLY, never source gameplay evidence."""
    w, h = 320, 200
    header = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    rows = (b"\0" + b"\x7F\0\x55" * w) * h
    return (proof.PNG_MAGIC + png_chunk(b"IHDR", header) +
            png_chunk(b"IDAT", zlib.compress(rows)) +
            png_chunk(b"IEND", b""))


class ProofSafety(unittest.TestCase):
    def test_both_python_entrypoints_compile(self):
        for source in (ENCODER, LAUNCHER):
            compile(source.read_text(encoding="utf-8"), str(source), "exec")

    def test_native_png_integrity_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            image = pathlib.Path(tmp) / "frame.png"
            image.write_bytes(tiny_valid_png())
            self.assertEqual(proof.verified_png(image), (320, 200))
            invalid = bytearray(image.read_bytes())
            invalid[-6] ^= 1  # IEND CRC, no valid original PNG.
            image.write_bytes(invalid)
            with self.assertRaises(ValueError):
                proof.verified_png(image)
            image.write_bytes(tiny_valid_png()[:-8])
            with self.assertRaises(ValueError):
                proof.verified_png(image)

    def test_no_missing_or_repeated_frame_receipts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            expected = [{"frame": i, "tick": 100 + i * 20} for i in range(16)]
            with self.assertRaisesRegex(ValueError, "Missing or empty"):
                proof.frame_rows(root, "01-massed-units", expected)
            for i in range(16):
                path = root / "01-massed-units" / ("frame-%04d.png" % i)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(tiny_valid_png() + b"\0" * 4096)
            with self.assertRaisesRegex(ValueError, "trailing bytes"):
                proof.frame_rows(root, "01-massed-units", expected)
            with self.assertRaises(ValueError):
                proof.frame_rows(root, "../fake-proof", expected)

    def test_aai_survivor_accounting_uses_live_managed_body(self):
        fixture = FIXTURE.read_text(encoding="utf-8")
        start = fixture.index("local function snapshot(t)")
        finish = fixture.index("\nlocal function tick(event)", start)
        snapshot = fixture[start:finish]
        self.assertIn('"aai-programmable-vehicles","get_units"', snapshot)
        self.assertIn("managed[rec.unit]", snapshot)
        self.assertIn("entity.force.name==rec.force", snapshot)
        self.assertIn("aai_registry_available=aai_registry_available", snapshot)
        self.assertNotIn("local entity=rec.entity", snapshot)
        self.assertIn("AAI managed unit registry unavailable in native battle",
                      fixture)

    def test_batch_initialization_is_atomic_and_failure_is_not_repeated_per_tick(self):
        fixture = FIXTURE.read_text(encoding="utf-8")
        init_section = fixture.split("local function init()", 1)[1].split(
            "\nlocal function capture(t,elapsed)", 1)[0]
        self.assertIn("SETUP_BEGIN", init_section)
        self.assertIn("SETUP_SURFACE_READY", init_section)
        self.assertIn("SETUP_ACTORS_AND_BUNKERS_READY", init_section)
        self.assertIn("t.ready=true", init_section)
        self.assertLess(init_section.index("t.surface=s.index"),
                        init_section.index("storage.combat_batch_visual=t"))
        self.assertLess(init_section.index("t.expected="),
                        init_section.index("storage.combat_batch_visual=t"))
        self.assertLess(init_section.index("t.ready=true"),
                        init_section.index("storage.combat_batch_visual=t"))
        tick_section = fixture.split("local function tick(event)", 1)[1]
        self.assertIn("t.ready==true", tick_section)
        self.assertIn('type(t.surface)=="number"', tick_section)

    def test_both_real_bunker_lines_precede_aai_actor_commands(self):
        fixture = FIXTURE.read_text(encoding="utf-8")
        setup = fixture.split("local function init()", 1)[1].split(
            "\nlocal function capture(t,elapsed)", 1)[0]
        # Former first failure: opposing side-2 autocannon placement returned
        # no entity after side-1 AAI actors were already activated.
        self.assertEqual(
            setup.count("for side,force in ipairs({player,renegade}) do"), 2)
        self.assertLess(setup.index("SETUP_BUNKER_LINES_READY"),
                        setup.index("for i,u in ipairs(C.units)"))
        self.assertIn("s.can_place_entity", setup)
        self.assertIn("BUNKER_PLACED", setup)
        self.assertIn("BUNKER_POSITION_ADJUST", setup)
        # Native hostile staging must still create actual Factorio turrets.
        # Raised build callbacks belong to player construction acceptance,
        # not to the test fixture's hostile-force deployments.
        self.assertIn("local raise_event=(side==1)", setup)
        self.assertIn("raise_built=raise_event", setup)
        self.assertIn("BunkerVisuals.add(gun)", setup)
        self.assertIn("native-hostile-direct", setup)
        self.assertIn("native bunker absent ", setup)
        self.assertIn("attempts=", setup)
        self.assertIn("SETUP_ACTORS_AND_BUNKERS_READY", setup)
        self.assertIn("t.expected={aai_actors=30,types=15,native_bunkers=14", setup)
        self.assertIn("native_biters=48", setup)
        self.assertIn("local commander=b.commandable", setup)
        self.assertIn("commander.set_command{", setup)
        self.assertNotIn("b.set_command{", setup)
        self.assertIn("check(#t.actors==30 and #t.turrets==14 and #t.biters==48", setup)
        self.assertIn("game.take_screenshot", fixture)

    def test_native_failure_reports_first_fixture_handler_not_unrelated_errors(self):
        launcher = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn("owner=combat-batch-native route=setup", launcher)
        self.assertIn("owner=combat-batch-native route=record-proof", launcher)
        self.assertIn("TP_COMBAT_FIRST_NATIVE_DIAGNOSTIC", launcher)
        self.assertIn("diagnostics[:12]", launcher)
        # Other native scenarios intentionally retain their own broad abort
        # conditions. This regression only owns the graphical batch lane.
        batch_visual = launcher.split("if args.scenario=='batch-visual':", 1)[1].split(
            "\n for label,arguments,marker", 1)[0]
        self.assertNotIn(
            "if 'isolated handler failure' in output or 'Error Util.cpp'",
            batch_visual)

    def test_staggered_genuine_camera_frames_and_matching_launcher_gate(self):
        import re
        fixture = FIXTURE.read_text(encoding="utf-8")
        launcher = LAUNCHER.read_text(encoding="utf-8")
        clips = re.findall(
            r'\{id="(0[123]-[^"]+)",start=(\d+),stop=(\d+),step=(\d+),'
            r'x=[^,]+,y=[^,]+,zoom=[^}]+\}', fixture)
        self.assertEqual(len(clips), 3)
        timestamps = []
        for name, start, stop, step in clips:
            ticks = list(range(int(start), int(stop)+1, int(step)))
            self.assertGreaterEqual(len(ticks), 16, name)
            self.assertLessEqual(len(ticks), 24, name)
            timestamps.extend(ticks)
        self.assertEqual(len(timestamps), len(set(timestamps)),
                         "Never queue two native 960x540 screenshots on one game tick")
        self.assertGreaterEqual(len(timestamps), 48)
        self.assertLessEqual(len(timestamps), 72)
        self.assertIn('resolution={960,540}', fixture)
        self.assertIn('force_render=true', fixture)
        self.assertIn('game.take_screenshot', fixture)
        self.assertIn('count>=48 and actual==count', launcher)
        self.assertIn("len(expected.get(clip, []))>=16", launcher)
        self.assertIn("TP_COMBAT_LIVE_PROGRESS", launcher)
        self.assertIn("TP_COMBAT_FRAME_DIAGNOSTIC", launcher)
        self.assertIn("'frame-*.png'", launcher)

    def test_only_live_native_capture_can_satisfy_visual_gate(self):
        fixture = FIXTURE.read_text(encoding="utf-8")
        self.assertIn("game.take_screenshot", fixture)
        self.assertIn("on_entity_damaged", fixture)
        self.assertIn("NATIVE_COMBAT_COMPLETE", fixture)
        self.assertIn("blockers=blockers", fixture)
        self.assertIn("Bridge.command(", fixture)
        self.assertIn("game.auto_save(", fixture)
        source = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn("batch-visual", source)
        self.assertIn("--source-sha", source)
        self.assertIn("graphical-client.log", source)
        self.assertIn("Refusing to overwrite nonempty test output directory", source)
        self.assertIn("assemble_native_combat_proofs.py", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
