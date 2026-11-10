#!/usr/bin/env python3
"""Dependency-free FMPL Effects registry gates. Run before Blender."""
import json
from pathlib import Path

def main():
    root=Path(__file__).resolve().parent
    data=json.loads((root/"presets.json").read_text(encoding="utf-8"))
    assert data["schema"]=="fmpl.effects.v1" and data["version"]=="1.0.0"
    p=data["presets"];r=data["rigs"]
    assert len(p)==28 and len(r)==5, (len(p),len(r))
    ids=[x["id"] for x in p];assert len(set(ids))==len(ids)
    assert len({x["family"] for x in p})>=8
    for item in p:
        assert item["mode"] in {"surface","volume"}
        assert item["effect"] in {"normal","molten","cracks","heat","volume"}
        assert len(item["base_color"])==3
        assert all(0 <= z <= 1 for z in item["base_color"])
        assert 0<=item["roughness"]<=1 and 0<=item["metallic"]<=1
        assert 0<=item["transmission"]<=1 and 1<=item["ior"]<=2
        assert item["noise_scale"]>0 and 0<=item["bump_distance"]<=.05
        assert item["density"]>=0
        assert item["performance"] in {"sprite-safe","advanced-preview"}
    for rig in r:
        assert rig["material"] in ids and rig["count"] in range(1,9)
        assert rig["loop_frames"]==16
    cap=data["capture"]
    assert cap["pitch_degrees"]==45 and cap["azimuth_degrees"]==0
    assert cap["orthographic"] and len(cap["frames"])==16
    assert cap["frames"]==list(range(1,92,6)) and cap["loop_end_frame"]==97
    assert data["limits"]["default_no_simulation_bake"]
    print("FMPL_EFFECTS_CATALOG_PASS",len(p),"materials",len(r),"rigs")

if __name__=="__main__":
    main()
