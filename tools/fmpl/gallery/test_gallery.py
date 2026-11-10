#!/usr/bin/env python3
"""Offline FMPL gallery source contract smoke tests; no Blender/GitHub writes."""
from __future__ import annotations
import ast
import json
from pathlib import Path

def main():
    root=Path(__file__).resolve().parent
    spec=json.loads((root/"repositories.json").read_text(encoding="utf-8"))
    assert spec["schema"]=="fmpl.account-gallery.sources.v1"
    assert len(spec["sources"])==25
    assert spec["private_repositories_exported"]==0
    assert len(set(s["repo"] for s in spec["sources"]))==len(spec["sources"])
    assert all(s["repo"].startswith("mrcalzon02/") and s["visibility"]=="public" for s in spec["sources"])
    for script in ("inventory.py","render_materials.py","render_models.py","generate_index.py","verify_gallery.py","merge_verified_batches.py",
                   "select_model_batch.py","verify_model_batch.py","render_texture_batch.py",
                   "verify_texture_batch.py","combine_gallery_bundles.py"):
        data=(root/script).read_text(encoding="utf-8")
        ast.parse(data,filename=script)
        assert "FMPL" in data or "fmpl" in data
    assert (root/"inventory.py").read_text(encoding="utf-8").count(".blend")>=1
    assert (root/"render_materials.py").read_text(encoding="utf-8").count("76")>=2
    print("FMPL_GITHUB_GALLERY_STATIC_SOURCE_TEST_PASS",len(spec["sources"]))
if __name__=="__main__":main()
