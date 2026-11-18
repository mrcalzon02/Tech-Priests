"""Prepare two focused V07 commits without touching the working index or branch.

Default: report required local inputs. --prepare writes local Git objects and
refs/checkpoints/emergency-assembler-v07. This program never fetches or pushes.
Shared-file changes are derived from --base bytes, never dirty working copies.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
ASSET = "art/source-to-3d/emergency-assembler/v07"
SOURCE_NAME = "tech_priests_emergency_assembler_v07_animated.blend"
GRAPHICS = "tech-priests_src/graphics/entity/emergency-assembler-v07"
MODULE = "tech-priests_src/prototypes/generated_graphics/emergency-assembler-v07.lua"
EXPECTED_SOURCE = "00d047b9aa80e13bd148b1dcbd2e5440b4a5e0414d744b446f273b0fc741845d"
REPOSITORY = "mrcalzon02/Tech-Priests"
OUT = ROOT / "build/assembler-v07-publication"


def git(*args: str, env: dict | None = None, data: bytes | None = None) -> bytes:
    result = subprocess.run(["git", *args], cwd=ROOT, env=env, input=data,
                            capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError("git " + " ".join(args) + "\n" +
                           result.stderr.decode(errors="replace"))
    return result.stdout


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def required_files() -> list[str]:
    names = ["inspect_source.py", "capture.py", "pack.py", "audit_motion.py",
             "run_native.py", "checkpoint.py"]
    paths = ["tools/art/emergency_assembler/" + name for name in names]
    paths += ["tests/scenarios/emergency-assembler-v07/" + name
              for name in ("data.lua", "control.lua")]
    paths += [MODULE]
    paths += [GRAPHICS + "/" + kind + "-" + direction + ".png"
              for direction in ("north", "east", "south", "west")
              for kind in ("idle", "working")]
    paths += [GRAPHICS + "/icon.png"]
    paths += [ASSET + "/" + name for name in (
        SOURCE_NAME, "source-inspection.json", "motion-audit.json",
        "atlas-manifest.json", "README.md", "surface-plan.json",
        "visual-review.json", "four-direction-cycle-review.png",
        "emergency-assembler-v07-four-directions.gif", "review-front-rear.png",
        "captures/receipt-0-1-2-3.json")]
    return paths


def input_files() -> tuple[list[str], list[str]]:
    paths = required_files()
    missing = [path for path in paths if not (ROOT / path).is_file()]
    native = ROOT / ASSET / "native-evidence"
    evidence = sorted(path for path in native.glob("*")
                      if path.is_file() and path.suffix.lower() in {".json", ".png"})
    if not any(path.suffix.lower() == ".json" for path in evidence):
        missing.append(ASSET + "/native-evidence/<final-proof.json>")
    if not any(path.suffix.lower() == ".png" for path in evidence):
        missing.append(ASSET + "/native-evidence/<final-screenshot.png>")
    for path in evidence:
        if path.stat().st_size > 8 * 1024 * 1024:
            raise ValueError("Native proof exceeds the small-proof limit: " + str(path))
        paths.append(path.relative_to(ROOT).as_posix())
    return sorted(paths), missing


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise ValueError("Expected one unchanged base " + label + "; review the new main")
    return text.replace(old, new, 1)


def edit_text(raw: bytes, transform) -> bytes:
    text = raw.decode("utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    text = transform(text.replace("\r\n", "\n"))
    return text.replace("\n", newline).encode("utf-8")


def registration(raw: bytes) -> bytes:
    return edit_text(raw, lambda text: replace_once(text,
        '-- Final registration: do not let legacy micro-art rescaling erase sprite shifts.\n'
        'require("prototypes.workbench_graphics")',
        '-- Exact owner-supplied V07 assembler; register after legacy micro-art rescaling.\n'
        'require("prototypes.generated_graphics.emergency-assembler-v07")',
        "workbench registration"))


def exact_byte_attributes(raw: bytes) -> bytes:
    """Preserve hash-bound writer bytes on subsequent cross-platform checkouts."""
    marker = b"# Exact Emergency Assembler V07 source, capture and native-proof writer bytes."
    if marker in raw:
        raise ValueError("Base already contains the V07 exact-byte attributes")
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    patterns = (
        ASSET + "/**",
        "tools/art/emergency_assembler/*.py",
        "tests/scenarios/emergency-assembler-v07/*.lua",
        MODULE,
        GRAPHICS + "/*",
    )
    block = [marker] + [(path + " -text whitespace=cr-at-eol").encode() for path in patterns]
    separator = newline if raw.endswith(b"\n") else newline + newline
    return raw + separator + newline.join(block) + newline


def image_verifier(raw: bytes) -> bytes:
    def apply(text: str) -> str:
        replacements = [
            ('Verify installed boiler/workbench/bunker image cells and source registration.',
             'Verify installed boiler/assembler/bunker image cells and source registration.'),
            ("sheet(gfx/f'timber-workbench/working-{direction}.png',128,12,8)",
             "sheet(gfx/f'emergency-assembler-v07/working-{direction}.png',256,12,12)"),
            ("sheet(gfx/f'timber-workbench/idle-{direction}.png',128,1,1)",
             "sheet(gfx/f'emergency-assembler-v07/idle-{direction}.png',256,1,1)"),
            ('assert \'require("prototypes.workbench_graphics")\' in final',
             'assert \'require("prototypes.generated_graphics.emergency-assembler-v07")\' in final\n'
             'assert \'require("prototypes.workbench_graphics")\' not in final'),
            ("wb=(root/'tech-priests_src/prototypes/workbench_graphics.lua').read_text()",
             "wb=(root/'tech-priests_src/prototypes/generated_graphics/emergency-assembler-v07.lua').read_text()"),
            ("assert 'animation_speed = 0.2' in wb and 'scale = 0.5' in wb and 'frame_count = idle and 1 or 96' in wb",
             "assert 'animation_speed = 0.2' in wb and 'scale = 0.1875' in wb and 'frame_count = idle and 1 or 144' in wb"),
        ]
        for old, new in replacements:
            text = replace_once(text, old, new, "image verifier clause")
        return text
    return edit_text(raw, apply)


def ledger(raw: bytes, native_paths: list[str]) -> bytes:
    summary = (
        "## Emergency Assembler V07 source and native integration — 2026-11-17\n\n"
        "The exact owner-supplied V07 animated Blender scene is archived unchanged at\n"
        f"`{ASSET}/{SOURCE_NAME}` (SHA-256 `{EXPECTED_SOURCE}`). Its hinged mechanical\n"
        "arm, knobbly capsule, opening hatches, electrical arcs, localized heat, and\n"
        "steam during discharge are preserved. The 288-frame, 24-fps source cycle is\n"
        "captured as 144 frames at 12 fps in four directions with the fixed FMPL camera.\n\n"
        "The emergency assembler now loads its own V07 graphics and matching icon\n"
        "instead of the unrelated timber workbench. The one-tile grid, burner and recipes\n"
        "are retained; collision depth changes only from 0.70 to 0.72 tile to allow native\n"
        "directional placement before construction (in-place rotation is unsupported).\n"
        "Source preservation, motion checks, atlas hashes, viewed renders,\n"
        "and the specific native operation/save-reload evidence are retained under\n"
        f"`{ASSET}`. Technical verification and owner visual acceptance remain distinct.\n"
        "This is a focused source/art checkpoint; no mod version bump, packaged-release\n"
        "claim, or GitHub Actions change is included.\n\n"
    )
    if b"## Emergency Assembler V07 source and native integration" in raw:
        raise ValueError("Base already includes this delivery; inspect before preparing again")
    return summary.encode("utf-8") + raw


def replace_model_entry(raw: bytes, entry: dict) -> bytes:
    """Replace one JSON model object without reformatting unrelated registry bytes."""
    text = raw.decode("utf-8")
    needle = '"id": "emergency-assembler"'
    if text.count(needle) != 1:
        raise ValueError("Expected one assembler entry in base FMPL registry")
    anchor = text.index(needle)
    start = text.rfind("{", 0, anchor)
    _, length = json.JSONDecoder().raw_decode(text[start:])
    block = json.dumps(entry, indent=2, ensure_ascii=False)
    # The object's existing first-line indentation precedes `start`.
    block = block.replace("\n", "\n    ")
    newline = "\r\n" if "\r\n" in text else "\n"
    if newline == "\r\n":
        block = block.replace("\n", "\r\n")
    updated = text[:start] + block + text[start + length:]
    before, after = json.loads(text), json.loads(updated)
    old = next(model for model in before["models"] if model["id"] == "emergency-assembler")
    old.clear(); old.update(entry)
    if before != after:
        raise AssertionError("FMPL replacement changed another record")
    return updated.encode("utf-8")


def fmpl_files(base_registry: bytes, base_readme: bytes, source_commit: str,
               native_paths: list[str]) -> dict[str, bytes]:
    def ref(path: str) -> dict:
        return dict(repository=REPOSITORY, ref=source_commit, path=path)
    entry = dict(
        id="emergency-assembler", status="game-sprites-installed-with-specific-native-checks",
        source=ref(ASSET + "/" + SOURCE_NAME),
        source_sha256=EXPECTED_SOURCE,
        evidence=[ref(ASSET + "/" + name) for name in (
            "README.md", "source-inspection.json", "motion-audit.json",
            "atlas-manifest.json", "visual-review.json", "surface-plan.json")]
            + [ref(path) for path in native_paths],
        footprint=[1, 1],
        purpose="Exact owner-supplied V07 hinged-arm and knobbly-capsule assembler; 12-second four-direction native animation. Preserve this distinct model; never substitute the timber workbench.",
    )
    updated_registry = replace_model_entry(base_registry, entry)
    def readme(text: str) -> str:
        text = replace_once(text,
            "**Assembler:** reference sprite exists, but no distinct approved 3D source found in the verified repository paths. Do **not** substitute the timber workbench source.",
            "**Assembler:** the exact owner-supplied V07 animated source is recovered and permanently pinned in FMPL.json. Its hinged arm, knobbly capsule, electrical arcs, heat, and steam are captured as a 12-second four-direction animation, with source, motion, atlas, visual-review, and specific native evidence. The runtime loads the assembler's own graphics; do **not** substitute the timber workbench source.",
            "FMPL README assembler summary")
        return replace_once(text,
            "The emergency assembler remains a sprite-only reference until its correct native source is recovered.",
            "The emergency assembler's distinct V07 source is now recovered; its source and native evidence are pinned separately in the model record.",
            "FMPL README historical assembler state")
    return {"tools/fmpl/FMPL.json": updated_registry,
            "tools/fmpl/README.md": edit_text(base_readme, readme)}


def verify_inputs(paths: list[str]) -> None:
    source = (ROOT / ASSET / SOURCE_NAME).read_bytes()
    if digest(source) != EXPECTED_SOURCE:
        raise ValueError("Supplied immutable V07 Blender source bytes changed")
    audit = json.loads((ROOT / ASSET / "motion-audit.json").read_text())
    if (audit.get("source_sha256") != EXPECTED_SOURCE or audit.get("failures")
            or any(value is False for value in audit.get("preservation", {}).values())):
        raise ValueError("Motion evidence does not pass against the exact V07 source")
    atlas = json.loads((ROOT / ASSET / "atlas-manifest.json").read_text())
    if (atlas.get("status") != "PASS" or atlas.get("source_sha256") != EXPECTED_SOURCE
            or atlas.get("runtime_frames") != 144 or atlas.get("duration_seconds") != 12
            or atlas.get("scale") != .1875):
        raise ValueError("Atlas manifest does not describe the expected verified V07 capture")
    for record in atlas["files"]:
        path = ROOT / GRAPHICS / record["file"]
        if path.relative_to(ROOT).as_posix() not in paths or digest(path.read_bytes()) != record["sha256"]:
            raise ValueError("Runtime PNG hash differs from captured manifest: " + str(path))
    native = [json.loads((ROOT / path).read_text()) for path in paths
              if "/native-evidence/" in path and path.endswith(".json")]
    if any(record.get("status") in {"FAIL", "FAILED"} or record.get("passed") is False
           or record.get("failures") for record in native):
        raise ValueError("A copied final native proof still records failure")
    if not any(record.get("status") == "PASS" or record.get("passed") is True for record in native):
        raise ValueError("No passing final native proof is present")
    acceptance = json.loads((ROOT / ASSET / "native-evidence/native-acceptance.json").read_text())
    tested_module = acceptance["source"]["production_sources"]["prototypes/generated_graphics/emergency-assembler-v07.lua"]
    if digest((ROOT / MODULE).read_bytes()) != tested_module:
        raise ValueError("Current graphics module differs from the native-tested module")
    if any(acceptance.get(key, {}).get("status") != "PASS" for key in ("production", "save_reload", "graphical")):
        raise ValueError("Fresh production, actual save/reload and renderer must all pass")
    for path, expected in acceptance["source"]["staged_graphics"].items():
        if path.startswith("graphics/entity/emergency-assembler-v07/"):
            if digest((ROOT / "tech-priests_src" / path).read_bytes()) != expected:
                raise ValueError("Current runtime image differs from native-tested image: " + path)
    review = json.loads((ROOT / ASSET / "visual-review.json").read_text())
    if review.get("status") != "PASS":
        raise ValueError("Independent final visual review must pass before checkpoint")


def stage_bytes(env: dict, path: str, data: bytes) -> str:
    blob = git("hash-object", "-w", "--no-filters", "--stdin", data=data).decode().strip()
    git("update-index", "--add", "--cacheinfo", "100644", blob, path, env=env)
    # This catches accidental normalization of PNG/source/proof bytes immediately,
    # including the complete immutable 32-MB Blender source. No checkout is needed.
    if digest(git("cat-file", "blob", blob)) != digest(data):
        raise AssertionError("Staged Git blob differs from exact writer bytes: " + path)
    return blob


def whitespace_check(env: dict, parent: str) -> None:
    # Some inherited base JSON blobs are intentionally CRLF. Permit only the CR
    # line terminator while retaining blank-at-EOL/EOF and space-before-tab checks.
    git("-c", "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol",
        "diff", "--cached", "--check", parent, env=env)


def checkpoint(base: str, paths: list[str]) -> dict:
    verify_inputs(paths)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="index-", dir=OUT) as temporary:
        env = os.environ.copy()
        env["GIT_INDEX_FILE"] = str(Path(temporary) / "publication.index")
        env["GIT_OPTIONAL_LOCKS"] = "0"
        git("read-tree", base, env=env)
        read_base = lambda path: git("show", base + ":" + path)
        native_paths = [path for path in paths if "/native-evidence/" in path]
        shared = {
            ".gitattributes": exact_byte_attributes(read_base(".gitattributes")),
            "tech-priests_src/data-final-fixes.lua": registration(read_base("tech-priests_src/data-final-fixes.lua")),
            "tools/art/verify_installed_model_sprites.py": image_verifier(read_base("tools/art/verify_installed_model_sprites.py")),
            "docs/art/MODEL_COMPLETION_LEDGER.md": ledger(read_base("docs/art/MODEL_COMPLETION_LEDGER.md"), native_paths),
        }
        manifest = []
        for path in paths:
            data = (ROOT / path).read_bytes()
            blob = stage_bytes(env, path, data)
            manifest.append(dict(path=path, sha256=digest(data), bytes=len(data),
                                 git_blob=blob, verified_raw_git_blob_bytes=True))
        for path, data in shared.items():
            blob = stage_bytes(env, path, data)
            (OUT / path.replace("/", "__")).write_bytes(data)
            manifest.append(dict(path=path, sha256=digest(data), bytes=len(data), git_blob=blob,
                                 verified_raw_git_blob_bytes=True,
                                 provenance="focused edit of base Git bytes"))
        whitespace_check(env, base)
        first_tree = git("write-tree", env=env).decode().strip()
        first = git("commit-tree", first_tree, "-p", base,
                    data=b"Integrate exact owner-supplied Emergency Assembler V07 animation and native evidence\n").decode().strip()
        registry = fmpl_files(read_base("tools/fmpl/FMPL.json"),
                              read_base("tools/fmpl/README.md"), first, native_paths)
        registry_manifest = []
        for path, data in registry.items():
            blob = stage_bytes(env, path, data)
            (OUT / path.replace("/", "__")).write_bytes(data)
            registry_manifest.append(dict(path=path, sha256=digest(data), bytes=len(data), git_blob=blob,
                                          verified_raw_git_blob_bytes=True))
        whitespace_check(env, first)
        second_tree = git("write-tree", env=env).decode().strip()
        second = git("commit-tree", second_tree, "-p", first,
                     data=b"Register recovered V07 emergency assembler source and native evidence in FMPL\n").decode().strip()
        changed = git("diff-tree", "--no-commit-id", "--name-only", "-r", first, second).decode().splitlines()
        if sorted(changed) != ["tools/fmpl/FMPL.json", "tools/fmpl/README.md"]:
            raise AssertionError("Second commit must contain only FMPL registration")
        git("update-ref", "refs/checkpoints/emergency-assembler-v07-source", first)
        git("update-ref", "refs/checkpoints/emergency-assembler-v07", second)
    report = dict(status="LOCAL_CHECKPOINT_ONLY", base=base, source_commit=first,
                  source_tree=first_tree, commit=second, tree=second_tree,
                  source_sha256=EXPECTED_SOURCE, files=manifest,
                  registry_files=registry_manifest, version_bump=False,
                  scope="Exact V07 source, runtime graphics, tools, tests and evidence only; shared edits derived from base. No raw frame captures, render studies, derived production blend, other chats' work, release ZIP or workflow changes.",
                  publication="Not pushed; caller must verify remote main and perform a fast-forward publication.")
    (ROOT / "build/assembler-v07-publication.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--prepare", action="store_true",
                        help="Create the focused two-commit local checkpoint after all inputs exist")
    args = parser.parse_args()
    base = git("rev-parse", args.base + "^{commit}").decode().strip()
    paths, missing = input_files()
    if missing:
        print(json.dumps(dict(status="INPUTS_PENDING", base=base, missing=missing,
                              existing_files=len(paths) - len([p for p in missing if "<" not in p])), indent=2))
        if args.prepare:
            raise SystemExit(2)
        return
    if not args.prepare:
        verify_inputs(paths)
        print(json.dumps(dict(status="READY_FOR_LOCAL_CHECKPOINT", base=base,
                              files=paths, mutation="None; pass --prepare to create local commits"), indent=2))
        return
    report = checkpoint(base, paths)
    print(json.dumps({key: report[key] for key in ("status", "base", "source_commit", "commit", "source_sha256")}, indent=2))


if __name__ == "__main__":
    main()
