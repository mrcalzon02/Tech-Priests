#!/usr/bin/env python3
"""Offline provenance/permissions gate: listing an asset is not license to import it."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

REQUIRED = {"source_id", "origin", "title", "source_uri", "state", "rights", "license_evidence", "source_medium"}
STATES = {"reference-only", "candidate", "private-source-intake", "approved-import"}


def validate(entry: dict) -> None:
    if not isinstance(entry, dict) or not REQUIRED.issubset(entry):
        raise ValueError("Missing required source provenance fields")
    if entry["origin"] not in {"self-authored-repository", "private-drive", "third-party-website", "user-supplied-archive"}:
        raise ValueError("Invalid origin")
    if entry["state"] not in STATES:
        raise ValueError("Invalid source state")
    if entry["rights"] not in {"owner-controlled", "third-party", "unknown", "third-party-provenance-not-established"}:
        raise ValueError("Invalid rights class")
    if not all(isinstance(entry[k], str) and entry[k] for k in ("source_id", "title", "source_uri", "source_medium")):
        raise ValueError("Blank source metadata")
    if entry["state"] == "approved-import":
        evidence = entry["license_evidence"]
        if not isinstance(evidence, dict) or not evidence.get("license_name") or not evidence.get("evidence_uri"):
            raise ValueError("Import requires recorded licensing evidence")
        if entry.get("derivative_use_reviewed") is not True or entry.get("redistribution_reviewed") is not True:
            raise ValueError("Import requires explicit derivative/redistribution review")
        if entry.get("reviewer") in (None, ""):
            raise ValueError("Approved import requires a named reviewer")
        if entry.get("rights") in {"unknown", "third-party-provenance-not-established"}:
            raise ValueError("Unknown rights cannot be approved")
        if not entry.get("asset_file_or_component_id"):
            raise ValueError("Approval must apply to one exact source file or component")
        if not entry.get("asset_medium") or not entry.get("import_medium"):
            raise ValueError("Asset and import medium must be explicit")
        if entry["asset_medium"].startswith("2d") and entry["import_medium"].startswith("3d"):
            raise ValueError("A finished 2D sprite is not native source 3D geometry")


def validate_registry(path: Path) -> dict:
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    if doc.get("schema") != "fmpl.external-sources.v1":
        raise ValueError("Unsupported external source registry")
    records = doc.get("sources", [])
    ids = [x.get("source_id") for x in records]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate source IDs")
    for record in records:
        validate(record)
    return {"sources": len(records), "approved_imports": sum(x["state"] == "approved-import" for x in records)}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--file", default=str(Path(__file__).parent / "external_sources.json"))
    args = p.parse_args()
    print(json.dumps(validate_registry(Path(args.file)), sort_keys=True))


if __name__ == "__main__":
    main()
