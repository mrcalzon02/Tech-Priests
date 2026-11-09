#!/usr/bin/env python3
"""FMPL versioned asset and pipeline registry. Standard library only."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODULE = HERE / "FMPL.json"
EVENTS = HERE / "checkpoints.json"
KINDS = {"model": "models", "program": "programs", "pipeline": "pipelines", "library": "external_blender_libraries"}
EVENT_KINDS = {"model", "part", "material", "sprite", "prototype", "pipeline", "program"}
EVENT_STATES = {"candidate", "verified", "approved", "installed"}
HEX = set("0123456789abcdef")


def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def digest(path=EVENTS):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def records(reg, kind=None):
    if kind:
        return reg[KINDS[kind]]
    return [x for k in KINDS.values() for x in reg[k]]


def validate(root=None, check_files=False):
    reg = load_json(MODULE)
    assert reg["schema"] == "fmpl.module.v1"
    assert reg["short_name"] == "FMPL"
    assert reg["asset_units"]["one_blender_unit"] == "one Factorio tile"
    assert reg["policy"]["no_unreviewed_promotion"] is True
    assert reg["policy"]["no_extra_workflows"] is True
    assert len(reg["source_commit"]) == 40 and set(reg["source_commit"]) <= HEX
    all_records = records(reg)
    ids = [x["id"] for x in all_records]
    assert len(ids) == len(set(ids)), "duplicate asset IDs"
    for kind, coll in KINDS.items():
        for x in reg[coll]:
            assert x["id"] and (x.get("source") or x.get("entrypoint"))
            if kind == "library":
                assert x["provider"] == "google_drive"
                assert x["registry"] and x["indexer"] and x["append_adapter"]
                assert len(x["source"]["original_sha256"]) == 64
                continue
            src = x["source"] if kind != "pipeline" else x["entrypoint"]
            assert src["repository"] and src["path"] and len(src["ref"]) == 40
            assert set(src["ref"]) <= HEX
            if kind == "model":
                assert x["status"] in reg["status_vocabulary"]
                assert "purpose" in x
            if kind == "pipeline":
                assert x["stages"] and x["gate"]
    assert len(reg.get("external_blender_libraries", [])) == reg["inventory"].get("external_blender_libraries", 0)
    for field, coll in (("model_records", "models"), ("program_records", "programs"), ("pipeline_records", "pipelines")):
        assert len(reg[coll]) == reg["inventory"][field]
    if root is not None:
        root = Path(root).resolve()
        catalog = load_json(root / reg["material_catalog"])
        assert len(catalog["materials"]) == reg["inventory"]["materials"] == 23
        assert len(catalog["candidates"]) == reg["inventory"]["component_candidates_total"] == 39
        assert sum(p["origin"].startswith("martian-heavy") for p in catalog["candidates"]) == reg["inventory"]["bunker_component_candidates"] == 21
        assert reg["inventory"]["emergency_component_candidates"] == 18
        assert catalog["map_count"] == reg["inventory"]["pbr_maps"] == 69
        parts = load_json(root / reg["parts_registry"])
        assert len(parts.get("parts", [])) == reg["inventory"]["verified_shared_components"] == 0
        if check_files:
            for item in reg["models"] + reg["programs"]:
                src = item["source"]
                if src["repository"] == reg["canonical_repo"]:
                    assert (root / src["path"]).is_file(), src["path"]
            for item in reg["pipelines"]:
                src = item["entrypoint"]
                if src["repository"] == reg["canonical_repo"]:
                    assert (root / src["path"]).is_file(), src["path"]
            for mat in catalog["materials"]:
                for tex in mat["maps"].values():
                    p = root / tex["source_path"]
                    assert p.is_file() and p.stat().st_size == tex["size_bytes"], str(p)
    ledger = load_json(EVENTS)
    assert ledger["schema"] == "fmpl.checkpoints.v1"
    eids = [x["event_id"] for x in ledger["events"]]
    assert len(eids) == len(set(eids))
    return reg


def validate_event(e):
    required = ("event_id", "asset_id", "asset_kind", "revision", "state", "source_sha256", "evidence")
    if not isinstance(e, dict) or not all(k in e for k in required):
        raise ValueError("event is missing required provenance")
    if e["asset_kind"] not in EVENT_KINDS or e["state"] not in EVENT_STATES:
        raise ValueError("unknown asset kind or evidence state")
    if not all(isinstance(e[k], str) and e[k].strip() for k in ("event_id","asset_id","revision")):
        raise ValueError("blank stable event identity")
    if not isinstance(e["source_sha256"], str) or len(e["source_sha256"]) != 64 or set(e["source_sha256"].lower()) - HEX:
        raise ValueError("source_sha256 must be a genuine 64-digit hex digest")
    if not isinstance(e["evidence"], dict):
        raise ValueError("evidence must be a mapping")
    if e["state"] in ("verified", "approved", "installed"):
        if not e["evidence"].get("native_reopen_verified") or not e["evidence"].get("source_artifact_sha256"):
            raise ValueError("verified artifact requires exact native reopen and source hash")
    if e["state"] in ("approved", "installed"):
        if e["evidence"].get("owner_visual_approval") is not True:
            raise ValueError("approval requires explicit owner visual acceptance")
    if e["state"] == "installed":
        if not e["evidence"].get("factorio_runtime_verified"):
            raise ValueError("installed requires native Factorio runtime proof")


def add_event(event, expected_sha256):
    validate_event(event)
    old = EVENTS.read_bytes()
    if hashlib.sha256(old).hexdigest() != expected_sha256:
        raise RuntimeError("FMPL checkpoint has changed: refresh before writing")
    ledger = json.loads(old.decode("utf-8-sig"))
    if any(x["event_id"] == event["event_id"] for x in ledger["events"]):
        raise RuntimeError("event ID already exists (no overwrite)")
    ledger["events"].append(event)
    # optimistic concurrency check immediately before atomic replace
    if hashlib.sha256(EVENTS.read_bytes()).hexdigest() != expected_sha256:
        raise RuntimeError("FMPL checkpoint changed during registration")
    temp = EVENTS.with_name(EVENTS.name + ".tmp")
    try:
        temp.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(temp, EVENTS)
    finally:
        if temp.exists():
            temp.unlink()
    return digest()


def main(argv=None):
    p = argparse.ArgumentParser(description="FMPL: Factorio Modeling Production Library")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("summary")
    ls = sub.add_parser("list"); ls.add_argument("--kind", choices=tuple(KINDS))
    show = sub.add_parser("show"); show.add_argument("id")
    val = sub.add_parser("validate"); val.add_argument("--root", default=str(HERE.parents[1])); val.add_argument("--check-files", action="store_true")
    sub.add_parser("digest")
    add = sub.add_parser("record"); add.add_argument("--file", required=True); add.add_argument("--expected-sha256", required=True)
    a = p.parse_args(argv)
    if a.command == "digest":
        print(digest());return 0
    if a.command == "record":
        print("RECORDED", add_event(load_json(a.file), a.expected_sha256));return 0
    reg = validate(a.root if a.command == "validate" else None, bool(getattr(a, "check_files", False)))
    if a.command == "summary":
        print("FMPL", reg["version"], "| libraries",len(reg.get("external_blender_libraries", [])), "| models",len(reg["models"]),"| programs",len(reg["programs"]),
              "| pipelines",len(reg["pipelines"]),"| PBR materials",reg["inventory"]["materials"],
              "| PBR maps",reg["inventory"]["pbr_maps"],"| verified shared parts",reg["inventory"]["verified_shared_components"])
    elif a.command == "list":
        for x in records(reg, a.kind):
            src=x.get("source",x.get("entrypoint",{}))
            print(x["id"], x.get("status",x.get("kind","pipeline")), src.get("repository",src.get("provider","unknown")) )
    elif a.command == "show":
        hits = [x for x in records(reg) if x["id"] == a.id]
        if not hits:
            p.error("FMPL item not found: " + a.id)
        print(json.dumps(hits[0], indent=2))
    else:
        print("FMPL_VALIDATED", reg["version"], "records", len(records(reg)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
