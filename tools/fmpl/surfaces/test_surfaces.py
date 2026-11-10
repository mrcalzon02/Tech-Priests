#!/usr/bin/env python3
"""Static tests for surfaces and license-only intake metadata. No Blender needed."""
from pathlib import Path
import json
import re

def main():
    root=Path(__file__).resolve().parent
    d=json.loads((root/"catalog.json").read_text(encoding="utf-8"))
    s=json.loads((root/"blendswap_sources.json").read_text(encoding="utf-8"))
    assert d["schema"]=="fmpl.surfaces.v1" and d["candidate_count"]==25
    assert len(d["presets"])==25 and len({x["id"] for x in d["presets"]})==25
    assert d["render"]["camera_elevation"]==45 and d["render"]["azimuth"]==0
    assert d["render"]["no_simulation_bake"] is True
    for p in d["presets"]:
        assert re.fullmatch("[a-z0-9]+(?:-[a-z0-9]+)*",p["id"])
        assert 0<=p["metallic"]<=1 and 0<=p["roughness"]<=1
        assert 0<=p["bump_distance"]<=.03
        assert p["node_style"] in {"wood","stone","metal","granular","pebbles","cracked-mud","cracked-mud-rocks","cracked-rock","paving"}
    assert s["schema"]=="fmpl.surface-sources.v1"
    assert s["no_download_performed"] and not s["source_files_in_repository"]
    assert len(s["candidates"])>=10
    for r in s["candidates"]:
        assert r["listing_url"].startswith("https://blendswap.com/blend/")
        assert r["license"]=="CC0" and r["license_claim"]=="uploader-declared"
        assert r["status"]=="metadata-only-not-downloaded" and r["approval"] is False
        assert r["file_sha256"] is None
    ref=d["source_references"][0]
    assert ref["video_url"]=="https://www.youtube.com/watch?v=iuaZuDiMv6s"
    print("FMPL_SURFACES_STATIC_REGISTRY_PASS",len(d["presets"]),len(s["candidates"]))

if __name__=="__main__":
    main()
