"""Offline catalog integrity validation without Blender or external packages."""
from __future__ import annotations
import argparse
import json
from pathlib import Path


def validate(repo_root):
    root = Path(repo_root).resolve()
    manifest = json.loads((Path(__file__).resolve().parent / "catalog.json").read_text(encoding="utf-8"))
    assert manifest["schema"] == "tp-industrial-asset-catalog.v1"
    assert len(manifest["materials"]) == manifest["material_count"] == 23
    material_ids = [m["material_id"] for m in manifest["materials"]]
    assert len(set(material_ids)) == len(material_ids)
    map_paths = []
    for entry in manifest["materials"]:
        assert set(entry["maps"]) == {"albedo", "orm", "normal"}
        for info in entry["maps"].values():
            file = root / info["source_path"]
            assert file.is_file(), f"missing texture: {file}"
            assert file.stat().st_size == info["size_bytes"], f"size mismatch: {file}"
            assert len(info["git_blob_sha"]) == 40
            map_paths.append(info["source_path"])
    assert len(map_paths) == manifest["map_count"] == 69
    assert len(set(map_paths)) == len(map_paths)
    for p in manifest["candidates"]:
        assert p["status"] == "candidate" and p["measured_anchors"] is None
        assert (root / p["source_scene"]).is_file(), "missing native scene"
    for donor in manifest["source_donors"]:
        assert (root / donor["path"]).is_file(), "missing donor: " + donor["path"]
    assert manifest["limits"]["verified_reusable_parts"] == 0
    print(f"LIBRARY_CATALOG_PASS materials={len(material_ids)} maps={len(map_paths)} candidate_parts={len(manifest['candidates'])} donors={len(manifest['source_donors'])}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--repo-root", required=True)
    validate(p.parse_args().repo_root)
