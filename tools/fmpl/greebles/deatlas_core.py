"""Pure-Python planning and checkpoint contracts for Greebles scene de-atlasing."""
from __future__ import annotations
import hashlib
import json
import os
import re
import unicodedata
from pathlib import Path

SCHEMA = "fmpl.greebles.part-receipt.v1"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def candidate_id(source_sha256: str, object_name: str) -> str:
    if len(source_sha256) != 64 or not isinstance(object_name, str) or not object_name:
        raise ValueError("A pinned SHA-256 and an exact Blender object name are required")
    slug = unicodedata.normalize("NFKD", object_name).encode("ascii", "ignore").decode().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", slug).strip("-")[:40] or "unnamed"
    short = hashlib.sha256((source_sha256 + "\0" + object_name).encode("utf-8")).hexdigest()[:10]
    return "gb-" + slug + "-" + short


def select_batch(names: list[str], *, offset: int = 0, limit: int = 8) -> list[str]:
    if offset < 0 or limit < 1 or limit > 32:
        raise ValueError("Select a bounded batch: 0 <= offset and 1 <= limit <= 32")
    return sorted(names, key=lambda n: (n.casefold(), n))[offset:offset + limit]


def atomic_json(path: Path, document: dict) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    if temp.exists():
        raise FileExistsError("Stale temporary checkpoint; inspect before retry: " + str(temp))
    try:
        with temp.open("x", encoding="utf-8") as output:
            json.dump(document, output, indent=2, sort_keys=True)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def verified_checkpoint(part_path: Path, receipt_path: Path, source_sha256: str, object_name: str) -> bool:
    part_path = Path(part_path)
    receipt_path = Path(receipt_path)
    if not part_path.exists() and not receipt_path.exists():
        return False
    if not part_path.is_file() or not receipt_path.is_file():
        raise RuntimeError("Incomplete or orphaned part; quarantine for manual inspection")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if (receipt.get("schema") != SCHEMA or receipt.get("source_sha256") != source_sha256
            or receipt.get("source_object") != object_name
            or receipt.get("status") != "extracted-candidate"
            or receipt.get("part_sha256") != sha256_file(part_path)):
        raise RuntimeError("Part checkpoint does not match exact source and output bytes")
    return True
