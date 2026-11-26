"""Fail-closed orchestration/proof tests; no Factorio or remote job is launched."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile


SOURCE = Path(__file__).resolve().parents[2] / "tools" / "run_fresh_native_performance_1507.py"
SPEC = importlib.util.spec_from_file_location("fresh_native_1507", SOURCE)
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)
OFFICIAL = ("base", "quality", "elevated-rails", "recycler", "space-age")


def package(path, name, dependencies=None, extra=None):
    root = name + "_1.0.0"
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(root + "/info.json", json.dumps({"name": name, "version": "1.0.0",
                          "dependencies": dependencies or ["base >= 2.1.18"]}))
        archive.writestr(root + "/control.lua", "-- inert test archive\n")
        for key, value in (extra or {}).items():
            archive.writestr(key, value)
    return path


def observations(count=4, ticks=worker.FOUR_TICKS):
    records = [{"phase": "fixture", "count": count, "original_priests": True}]
    for elapsed in range(0, ticks + 1, 600):
        step = elapsed // 600
        rows = []
        for index in range(count):
            rows.append({"station": index + 1, "priest": index + 1001,
                         "repair_packs_used": step, "movement_samples": step * 3,
                         "machines": [{"unit": index * 2 + offset, "products": step * 20, "energy": 1000}
                                      for offset in (5001, 5002)]})
        records.append({"phase": "start" if elapsed == 0 else "end" if elapsed == ticks else "sample",
                        "elapsed_ticks": elapsed, "tick": 1000 + elapsed,
                        "pairs": rows, "live_pairs": count, "identities_stable": True,
                        "sequence_valid": True, "game_speed": 1})
    wall = {"windows": [{"start_tick": start, "end_tick": start + 600, "ticks": 600,
                          "elapsed_ms": 10000, "actual_ups": 60}
                         for start in range(worker.WARMUP, ticks, 600)],
            "minimum_window_ups": 60, "mean_ups": 60}
    desktop = {"passed": True, "session_id": 1, "engine_session": 1,
               "engine_image": True, "foreground_client_size": [1600, 1000], "fps_verified": False}
    return records, wall, desktop


def native_log(records):
    return "\n".join("10.000 Script @control.lua: [TP-FRESH-NATIVE-1507] " + json.dumps(record)
                     for record in records)


def native_inputs(root, engine):
    root.mkdir()
    (root / "userdata").mkdir()
    (root / "mods").mkdir()
    (root / "fresh-nauvis.zip").write_bytes(b"generated-test-placeholder")
    config = "[path]\nread-data=" + (engine.parents[2] / "data").as_posix() + \
        "\nwrite-data=" + (root / "userdata").as_posix() + "\n[other]\ncheck-updates=false\n"
    (root / "config.ini").write_text(config)
    command = [str(engine), "--config", str(root / "config.ini"), "--mod-directory", str(root / "mods"),
               "--load-game", str(root / "fresh-nauvis.zip"), "--window-size", "1600x1000"]
    return command, config


class NativeProofTests(unittest.TestCase):
    def verdict(self, records=None, wall=None, desktop=None):
        initial_records, initial_wall, initial_desktop = observations()
        return worker.validate_native(native_log(records if records is not None else initial_records),
                                      desktop if desktop is not None else initial_desktop, 4, worker.FOUR_TICKS,
                                      wall if wall is not None else initial_wall)

    def test_real_four_priest_work_passes_but_does_not_claim_fps(self):
        result = self.verdict()
        self.assertTrue(result["passed"], result)
        self.assertEqual(len(result["full_windows"]), 2)
        self.assertFalse(result["displayed_fps_verified"])
        self.assertFalse(result["performance_accepted"])

    def test_idle_priest_is_not_hidden_by_aggregate_repairs(self):
        records, _, _ = observations()
        records[-1]["pairs"][0]["repair_packs_used"] = records[-2]["pairs"][0]["repair_packs_used"]
        records[-1]["pairs"][1]["repair_packs_used"] += 1000
        self.assertFalse(self.verdict(records=records)["passed"])

    def test_one_stalled_full_window_fails_even_if_end_total_is_good(self):
        records, _, _ = observations()
        records[-2]["pairs"][0]["repair_packs_used"] = records[-3]["pairs"][0]["repair_packs_used"]
        records[-1]["pairs"][0]["repair_packs_used"] = 20
        self.assertFalse(self.verdict(records=records)["passed"])

    def test_movement_power_and_production_are_independent_requirements(self):
        for field in ("movement_samples", "energy", "products"):
            with self.subTest(field=field):
                records, _, _ = observations()
                if field == "movement_samples":
                    records[-1]["pairs"][0][field] = records[-2]["pairs"][0][field]
                elif field == "energy":
                    records[-1]["pairs"][0]["machines"][0][field] = 0
                else:
                    records[-1]["pairs"][0]["machines"][0][field] = records[-2]["pairs"][0]["machines"][0][field]
                self.assertFalse(self.verdict(records=records)["passed"])

    def test_replacing_priest_or_machine_is_not_success(self):
        for entity in ("priest", "machine"):
            with self.subTest(entity=entity):
                records, _, _ = observations()
                if entity == "priest":
                    records[-1]["pairs"][0]["priest"] = 99999
                else:
                    records[-1]["pairs"][0]["machines"][0]["unit"] = 99999
                self.assertFalse(self.verdict(records=records)["passed"])

    def test_screenshot_or_aggregate_wall_only_cannot_pass(self):
        self.assertFalse(self.verdict(records=[])["passed"])
        self.assertFalse(self.verdict(wall={"total_elapsed_ms": 30000, "mean_ups": 60})["passed"])

    def test_missing_duplicate_and_nonfinite_wall_windows_fail(self):
        _, wall, _ = observations()
        for windows in (wall["windows"][:1], wall["windows"] * 2,
                        [{**window, "elapsed_ms": float("nan")} for window in wall["windows"]]):
            with self.subTest(windows=windows):
                self.assertFalse(self.verdict(wall={"windows": windows})["passed"])

    def test_skipped_ticks_acceleration_or_session_zero_fail(self):
        for kind in ("sequence_valid", "game_speed", "tick", "session"):
            with self.subTest(kind=kind):
                records, _, desktop = observations()
                if kind == "session":
                    desktop["session_id"] = desktop["engine_session"] = 0
                else:
                    records[-1][kind] = {"sequence_valid": False, "game_speed": 2, "tick": 9999}[kind]
                self.assertFalse(self.verdict(records=records, desktop=desktop)["passed"])

    def test_fixture_has_no_unresolved_launcher_tokens_or_forced_worker_movement(self):
        code = worker.observer(4, worker.FOUR_TICKS)
        self.assertNotIn("__", code)
        self.assertNotIn("priest.teleport", code)
        self.assertNotIn("service_pair(", code)
        self.assertIn("submit_or_assign_repair_task(", code)
        self.assertIn("products_finished", code)
        self.assertIn("game.speed==1", code)
        with self.assertRaises(ValueError):
            worker.observer(100, 1201)


class ProvenanceGateTests(unittest.TestCase):
    def setUp(self):
        self.candidate = {"revision": "a" * 40, "sha256": "b" * 64}
        self.dependencies = {name: {"sha256": str(index) * 64} for index, name in enumerate(worker.DEPENDENCIES)}
        records, wall, desktop = observations()
        validation = worker.validate_native(native_log(records), desktop, 4, worker.FOUR_TICKS, wall)
        self.receipt = {"schema": worker.RECEIPT_SCHEMA, "phase": "native4", "passed": True,
                        "candidate": self.candidate.copy(), "engine_sha256": "e" * 64,
                        "dependency_sha256": {name: value["sha256"] for name, value in self.dependencies.items()},
                        "fixture_sha256": worker.hashlib.sha256(worker.FRESH_OBSERVER.encode()).hexdigest(),
                        "helper_sha256": worker.HELPER_SHA256,
                        "displayed_fps_verified": False,
                        "runs": [{"validation": validation}]}

    def gate(self, receipt=None):
        return worker.require_four(receipt or self.receipt, self.candidate, "e" * 64, self.dependencies)

    def test_four_activity_is_prerequisite_not_a_fabricated_fps_gate(self):
        self.gate()

    def test_wrong_revision_engine_dependency_or_fixture_cannot_unlock_100(self):
        for field in ("candidate", "engine_sha256", "dependency_sha256", "fixture_sha256", "helper_sha256", "runs", "passed"):
            with self.subTest(field=field):
                receipt = copy.deepcopy(self.receipt)
                receipt[field] = None
                with self.assertRaises(ValueError):
                    self.gate(receipt)

    def test_aggregate_success_without_full_four_windows_cannot_unlock_100(self):
        receipt = copy.deepcopy(self.receipt)
        receipt["runs"][0]["validation"]["full_windows"] = []
        with self.assertRaises(ValueError):
            self.gate(receipt)


class CacheAndExclusivityTests(unittest.TestCase):
    def test_archive_hash_type_and_paths_are_checked_without_fetching(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = package(root / "mod.zip", "tech-priests")
            self.assertEqual(worker.inspect_mod(archive, "tech-priests", worker.sha(archive))["name"], "tech-priests")
            for target, checksum in ((archive, "0" * 64), (root, worker.sha(archive))):
                with self.assertRaises(ValueError):
                    worker.inspect_mod(target, "tech-priests", checksum)
            unsafe = package(root / "unsafe.zip", "tech-priests", extra={"../escape.lua": ""})
            with self.assertRaises(ValueError):
                worker.inspect_mod(unsafe, "tech-priests", worker.sha(unsafe))

    def test_only_reviewed_required_cache_and_baseline_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            main = package(root / "tech.zip", "tech-priests", ["base >= 2.1.18", "aai-programmable-vehicles", "? optional-mod"])
            dependencies = {name: package(root / (name + ".zip"), name) for name in worker.DEPENDENCIES}
            pins = {name: ("1.0.0", worker.sha(path, "sha1")) for name, path in dependencies.items()}
            spec = {"path": str(main), "sha256": worker.sha(main), "revision": worker.REVIEWED_MAIN}
            request = {"schema": worker.SCHEMA, "phase": "matched100", "candidate": spec.copy(),
                       "baseline": spec.copy(), "dependencies": {name: str(path) for name, path in dependencies.items()}}
            with patch.object(worker, "DEPENDENCIES", pins):
                result = worker.verify_inputs(request, OFFICIAL)
                self.assertEqual(set(result["dependencies"]), set(dependencies))
                for change in ("optional", "save", "baseline"):
                    changed = copy.deepcopy(request)
                    if change == "optional":
                        changed["dependencies"]["optional-mod"] = str(main)
                    elif change == "save":
                        changed["save"] = "personal-save.zip"
                    else:
                        changed["baseline"]["revision"] = "0" * 40
                    with self.assertRaises(ValueError):
                        worker.verify_inputs(changed, OFFICIAL)

    def test_desktop_lock_never_steals_existing_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "desktop.lock"
            path.write_text("other-game-owner", encoding="utf-8")
            with self.assertRaises(FileExistsError):
                with worker.desktop_lock(path):
                    self.fail("existing lock was entered")
            self.assertEqual(path.read_text(), "other-game-owner")
            path.unlink()
            with worker.desktop_lock(path):
                self.assertTrue(path.is_file())
            self.assertFalse(path.exists())

    def test_process_preflight_refuses_game_render_or_unknown_inventory(self):
        for output in ('"factorio.exe","123","Console","1","10 K"',
                       '"Quasimorph.exe","124","Console","1","10 K"',
                       '"blender.exe","125","Console","1","10 K"', ""):
            with self.subTest(output=output), patch.object(worker.subprocess, "run", return_value=SimpleNamespace(stdout=output)):
                with self.assertRaises(RuntimeError):
                    worker.assert_no_competing_processes()
        with patch.object(worker.subprocess, "run", return_value=SimpleNamespace(stdout='"python.exe","321","Console","1","10 K"')):
            worker.assert_no_competing_processes()

    def test_existing_launcher_main_is_called_and_restored_without_file_edits(self):
        records, wall, desktop_proof = observations()
        desktop_proof["game_pid"] = 918
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "native"
            calls = []
            engine = (Path(directory) / "engine" / "bin" / "x64" / "factorio.exe").resolve()
            real = SimpleNamespace(Popen=lambda command, **options: SimpleNamespace(pid=918), STDOUT=subprocess.STDOUT)
            desktop = SimpleNamespace(OBSERVER="original observer", __file__="unchanged/open_desktop.py", subprocess=real)
            def existing_main():
                calls.append(list(worker.sys.argv))
                self.assertIn("products_finished", desktop.OBSERVER)
                self.assertNotIn("__COUNT__", desktop.OBSERVER)
                command, _ = native_inputs(root, engine)
                with (root / "native-launch.log").open("w") as stream:
                    desktop.subprocess.Popen(command, cwd=root, env={"original": "environment"},
                                             stdout=stream, stderr=desktop.subprocess.STDOUT)
                    stream.write(native_log(records))
                (root / "desktop-proof.json").write_text(json.dumps(desktop_proof))
                return 0
            desktop.main = existing_main
            profile = SimpleNamespace(parse_wall_clock=lambda text: wall)
            old_argv = worker.sys.argv
            with patch.object(worker, "assert_no_competing_processes"), patch("builtins.print"):
                result = worker.run_desktop(root, Path(directory), engine,
                    {"revision": "a" * 40, "sha256": "b" * 64}, 4, worker.FOUR_TICKS, desktop, profile)
            self.assertTrue(result["validation"]["passed"], result)
            self.assertEqual(len(calls), 1)
            self.assertEqual(desktop.OBSERVER, "original observer")
            self.assertIs(worker.sys.argv, old_argv)
            self.assertIs(desktop.subprocess, real)
            self.assertTrue(result["launch_observation"][0]["original_prefix_preserved"])


class NativeLaunchInstrumentationTests(unittest.TestCase):
    def setUp(self):
        quiet = patch("builtins.print")
        quiet.start()
        self.addCleanup(quiet.stop)

    def test_only_perf_argument_and_owned_debug_config_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root = (Path(directory) / "native").resolve()
            engine = (Path(directory) / "engine" / "bin" / "x64" / "factorio.exe").resolve()
            command, original_config = native_inputs(root, engine)
            environment = {"SteamAppId": "427520", "opaque_test_value": "preserved"}
            forwarded = []
            def popen(args, **options):
                forwarded.append((args, options))
                return SimpleNamespace(pid=123)
            real = SimpleNamespace(Popen=popen, STDOUT=subprocess.STDOUT, untouched=object())
            proxy = worker.NativeLaunchObservation(real, root, engine)
            with (root / "native-launch.log").open("wb") as stream:
                process = proxy.Popen(command, cwd=root, env=environment, stdout=stream, stderr=real.STDOUT)
                self.assertIs(forwarded[0][1]["stdout"], stream)
            self.assertEqual(process.pid, 123)
            self.assertEqual(forwarded[0][0][:-2], command)
            self.assertEqual(forwarded[0][0][-2:], ["--output-perf-stats", str(root / "native-rendering-frame-stats.csv")])
            self.assertIs(forwarded[0][1]["env"], environment)
            self.assertIs(proxy.untouched, real.untouched)
            self.assertEqual((root / "config.ini").read_text(), original_config + "\n[debug]\nshow-fps=always\n")
            self.assertFalse(proxy.records[0]["displayed_fps_verified"])
            self.assertFalse(proxy.records[0]["hud_visibility_verified"])

    def test_wrong_command_user_config_duplicate_or_wrong_log_is_refused(self):
        for kind in ("benchmark", "config-command", "config-content", "prior-csv", "wrong-log", "repeat"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                root = (Path(directory) / "native").resolve()
                engine = (Path(directory) / "engine" / "bin" / "x64" / "factorio.exe").resolve()
                command, _ = native_inputs(root, engine)
                created = []
                def popen(args, **options):
                    created.append(args)
                    return SimpleNamespace(pid=123)
                real = SimpleNamespace(Popen=popen, STDOUT=subprocess.STDOUT)
                proxy = worker.NativeLaunchObservation(real, root, engine)
                if kind == "benchmark":
                    command[5] = "--benchmark-graphics"
                elif kind == "config-command":
                    command[2] = str(Path(directory) / "personal-config.ini")
                elif kind == "config-content":
                    (root / "config.ini").write_text("[path]\nwrite-data=C:/personal-data\n")
                elif kind == "prior-csv":
                    proxy.frame_csv.write_text("previous evidence")
                filename = "wrong.log" if kind == "wrong-log" else "native-launch.log"
                with (root / filename).open("wb") as stream:
                    options = {"cwd": root, "env": {}, "stdout": stream, "stderr": real.STDOUT}
                    if kind == "repeat":
                        proxy.Popen(command, **options)
                    with self.assertRaises(RuntimeError):
                        proxy.Popen(command, **options)
                self.assertEqual(len(created), 1 if kind == "repeat" else 0)

    def test_proxy_and_observer_restored_after_native_exception(self):
        with tempfile.TemporaryDirectory() as directory:
            root = (Path(directory) / "native").resolve()
            engine = (Path(directory) / "engine" / "bin" / "x64" / "factorio.exe").resolve()
            real = SimpleNamespace(STDOUT=subprocess.STDOUT)
            desktop = SimpleNamespace(subprocess=real)
            with self.assertRaisesRegex(RuntimeError, "native failure"):
                with worker.observe_native_launch(desktop, root, engine):
                    self.assertIsNot(desktop.subprocess, real)
                    raise RuntimeError("native failure")
            self.assertIs(desktop.subprocess, real)

    def test_actual_caller_restores_observer_and_proxy_when_launcher_raises(self):
        with tempfile.TemporaryDirectory() as directory:
            root = (Path(directory) / "native").resolve()
            engine = (Path(directory) / "engine" / "bin" / "x64" / "factorio.exe").resolve()
            real = SimpleNamespace(STDOUT=subprocess.STDOUT)
            desktop = SimpleNamespace(subprocess=real, OBSERVER="preserved", __file__="unchanged/open_desktop.py")
            def failed_main():
                root.mkdir()
                raise RuntimeError("native refused to launch")
            desktop.main = failed_main
            old_argv = worker.sys.argv
            with patch.object(worker, "assert_no_competing_processes"):
                result = worker.run_desktop(root, root.parent, engine,
                    {"revision": "a" * 40, "sha256": "b" * 64}, 4, worker.FOUR_TICKS,
                    desktop, SimpleNamespace(parse_wall_clock=lambda text: {}))
            self.assertFalse(result["validation"]["passed"])
            self.assertIn("native refused to launch", result["validation"]["failures"])
            self.assertIs(desktop.subprocess, real)
            self.assertEqual(desktop.OBSERVER, "preserved")
            self.assertIs(worker.sys.argv, old_argv)


if __name__ == "__main__":
    unittest.main()
