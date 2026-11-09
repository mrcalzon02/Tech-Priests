#!/usr/bin/env python3
"""Confirm a local private Greebles donor matches the pinned Drive snapshot."""
import argparse
import hashlib
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
META = HERE / "source.json"
ZSTD_MAGIC = bytes.fromhex("28b52ffd")

def probe(path, *, verify_hash=True):
    info = json.loads(META.read_text(encoding="utf-8"))
    p = Path(path).expanduser().resolve()
    if not p.is_file():
        raise FileNotFoundError(str(p))
    with p.open("rb") as stream:
        prefix = stream.read(20)
    if not (prefix.startswith(ZSTD_MAGIC) or prefix.startswith(b"BLENDER")):
        raise ValueError("Unknown Blender source format")
    if p.stat().st_size != info["payload_bytes"]:
        raise ValueError("Drive source byte size mismatch")
    if verify_hash:
        digest = hashlib.sha256()
        with p.open("rb") as stream:
            for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != info["sha256"]:
            raise ValueError("Source revision mismatches pinned SHA-256")
    return {"path":str(p), "asset_id":info["id"], "size_bytes":p.stat().st_size,
            "sha256_checked":verify_hash}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",default=os.environ.get("FMPL_GREEBLES_BLEND"))
    parser.add_argument("--skip-hash",action="store_true")
    a=parser.parse_args()
    if not a.source:
        parser.error("Supply --source or FMPL_GREEBLES_BLEND")
    print(json.dumps(probe(a.source,verify_hash=not a.skip_hash),indent=2))

if __name__ == "__main__":
    main()
