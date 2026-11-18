"""Recover committed sparse sources and audit the current thruster delivery.

Read-only with respect to Git and the personal Factorio profile. Recovery only
creates missing files with their exact committed bytes; existing files are never
overwritten. A local origin/main ref is evidence of a local snapshot, not a fresh
remote publication check.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import pathlib
import subprocess
from datetime import datetime, timezone

from PIL import Image


def git(repo: pathlib.Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args])


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def tree(repo: pathlib.Path, ref: str, *paths: str) -> dict[str, str]:
    entries = git(repo, "ls-tree", "-r", "-z", ref, "--", *paths)
    result = {}
    for entry in entries.split(b"\0"):
        if entry:
            meta, path = entry.split(b"\t", 1)
            result[path.decode("utf-8")] = meta.split()[2].decode("ascii")
    return result


FAMILIES = {
    "hydrogen-thruster": {
        "footprint": [4, 4],
        "source": "art/source-to-3d/space-platform-engines/hydrogen-thruster/v01",
        "runtime": "tech-priests_src/graphics/entity/hydrogen-thruster-v01",
        "module": "tech-priests_src/prototypes/generated_graphics/hydrogen-thruster-v01.lua",
        "evidence": "docs/art/hydrogen-thruster-v01/validation.json",
        "runtime_png_count": 4,
        "required_models": ["hydrogen-thruster-v01.blend", "hydrogen-thruster-v01.glb"],
        "art_state": "Integrated V01; static physical GLB and seven light-only poses. Full mechanical animation remains open.",
    },
    "thetazine-thruster": {
        "footprint": [5, 5],
        "source": "art/source-to-3d/space-platform-engines/thetazine-thruster/v04-regenerative-study",
        "runtime": "tech-priests_src/graphics/entity/thetazine-thruster-v04",
        "module": "tech-priests_src/prototypes/generated_graphics/thetazine-thruster-v04.lua",
        "evidence": "docs/art/thetazine-thruster-v04/CHECKPOINT.json",
        "runtime_png_count": 9,
        "required_models": ["thetazine-v04-regenerative-study.blend", "thetazine-v04-regenerative-study.glb"],
        "art_state": "Integrated source35; 64-frame body/heat/projected shadow and native state evidence. Final owner appearance and bespoke remnant/icon remain open.",
    },
    "void-fusion-thruster": {
        "footprint": [1, 9],
        "runtime": "tech-priests_src/graphics/entity/void-fusion-thruster",
        "runtime_names": ["void-fusion-thruster-idle.png", "void-fusion-thruster-run.png"],
        "runtime_png_count": 2,
        "art_state": "Legacy sprites; independent narrow authored construction and animation remain open.",
    },
    "large-void-fusion-thruster": {
        "footprint": [4, 4],
        "runtime": "tech-priests_src/graphics/entity/void-fusion-thruster",
        "runtime_names": ["void-fusion-thruster-wide-idle.png", "void-fusion-thruster-wide-run.png"],
        "runtime_png_count": 2,
        "art_state": "Legacy wide sprites; independent wide authored construction and animation remain open.",
    },
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[3])
    parser.add_argument("--out", type=pathlib.Path, required=True)
    parser.add_argument("--recover-sources", action="store_true")
    args = parser.parse_args()
    repo = args.repo.resolve()
    head = git(repo, "rev-parse", "HEAD").decode().strip()
    tracked = tree(repo, head)
    try:
        remote_snapshot = git(repo, "rev-parse", "origin/main").decode().strip()
        remote_tree = tree(repo, remote_snapshot)
    except subprocess.CalledProcessError:
        remote_snapshot, remote_tree = None, {}
    failures, recovered, families = [], [], {}

    for name, spec in FAMILIES.items():
        paths = [p for p in tracked if p.startswith(spec["runtime"] + "/")]
        if "runtime_names" in spec:
            paths = [p for p in paths if pathlib.PurePosixPath(p).name in spec["runtime_names"]]
        runtime_pngs = [p for p in paths if p.endswith(".png")]
        if len(runtime_pngs) != spec["runtime_png_count"]:
            failures.append({"family": name, "reason": "runtime PNG set incomplete", "expected": spec["runtime_png_count"], "actual": len(runtime_pngs)})
        if "source" in spec:
            paths += [p for p in tracked if p.startswith(spec["source"] + "/")]
            paths += [spec["module"], spec["evidence"]]
            paths += [spec["source"] + "/" + p for p in spec["required_models"]]
        records = []
        for path in sorted(set(paths)):
            if path not in tracked:
                failures.append({"path": path, "reason": "not committed at HEAD"})
                continue
            blob = git(repo, "cat-file", "blob", tracked[path])
            local = repo / pathlib.PurePosixPath(path)
            is_source = "source" in spec and path.startswith(spec["source"] + "/")
            existed = local.is_file()
            if args.recover_sources and is_source and not existed:
                local.parent.mkdir(parents=True, exist_ok=True)
                local.write_bytes(blob)
                recovered.append(path)
            current = local.read_bytes() if local.is_file() else None
            is_binary = pathlib.PurePosixPath(path).suffix.lower() in {".png", ".blend", ".glb", ".zip"}
            match = current == blob if is_binary else current is not None and current.replace(b"\r\n", b"\n") == blob.replace(b"\r\n", b"\n")
            row = {
                "path": path, "git_blob": tracked[path], "committed_sha256": sha(blob),
                "committed_bytes": len(blob), "present_before_recovery": existed,
                "present_now": current is not None, "matches_commit": match,
                "local_origin_main_has_same_blob": remote_tree.get(path) == tracked[path],
            }
            # Verify delivery images against committed bytes, not merely filenames.
            if path.startswith(spec["runtime"] + "/") and path.endswith(".png"):
                try:
                    with Image.open(io.BytesIO(current or b"")) as im:
                        im.load()
                        row["png"] = {"size": list(im.size), "mode": im.mode}
                except Exception as exc:
                    failures.append({"path": path, "reason": "PNG decode failed", "detail": str(exc)})
            if current is not None and not match:
                failures.append({"path": path, "reason": "working copy differs from committed asset"})
            records.append(row)
        families[name] = {**spec, "files": records}

    final_fixes = (repo / "tech-priests_src/data-final-fixes.lua").read_text(encoding="utf-8-sig")
    imports = {}
    for name, spec in FAMILIES.items():
        if "module" in spec:
            module_name = pathlib.PurePosixPath(spec["module"]).stem
            imports[name] = "prototypes.generated_graphics." + module_name in final_fixes
            if not imports[name]:
                failures.append({"family": name, "reason": "late generated graphics import missing"})
    result = {
        "status": "FAIL" if failures else "PASS_COMMITTED_ASSET_AND_IMPORT_AUDIT",
        "created_utc": datetime.now(timezone.utc).isoformat(), "repository": str(repo),
        "head": head, "local_origin_main": remote_snapshot,
        "remote_verification": "No fetch or remote publication verification performed.",
        "scope": "Committed artifact identity, sparse-source recovery, runtime PNG decode and textual late imports. Native data-stage/propulsion checks are separate; this is not final art acceptance.",
        "recover_sources": args.recover_sources, "recovered_files": recovered,
        "late_imports": imports, "families": families, "failures": failures,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "families": len(families), "files": sum(len(f["files"]) for f in families.values()), "recovered": len(recovered), "failures": failures, "out": str(args.out)}, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
