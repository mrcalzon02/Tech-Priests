#!/usr/bin/env python3
"""Fail closed if the protected 0.1.672 installation baseline has changed."""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import zipfile


def verify(root: pathlib.Path) -> None:
    package = root / "dist" / "tech-priests_0.1.672.zip"
    manifest = json.loads((root / "docs" / "releases" /
                           "v0.1.672-published.json").read_text(encoding="utf-8"))
    if manifest.get("historical_baseline") is not True or manifest.get("asset") != package.name:
        raise ValueError("protected package publication metadata disagrees with baseline")
    expected = manifest.get("sha256")
    with package.open("rb") as handle:
        actual = hashlib.file_digest(handle, "sha256").hexdigest()
    if actual != expected:
        raise ValueError(f"baseline SHA-256 differs: expected={expected} actual={actual}")
    with zipfile.ZipFile(package) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f"protected archive CRC failed: {bad}")
        names = archive.namelist()
        prefix = "tech-priests_0.1.672/"
        if any(not name.startswith(prefix) for name in names):
            raise ValueError("protected archive has unexpected top-level root")
        info = json.loads(archive.read(prefix + "info.json").decode("utf-8"))
        if info.get("name") != "tech-priests" or info.get("version") != "0.1.672":
            raise ValueError("protected archive info.json has changed")
        if prefix + "control.lua" not in names:
            raise ValueError("protected archive is missing control.lua")
    print("PASS protected 0.1.672 baseline unchanged, CRC and structure valid")
    print("SHA-256: " + actual)


if __name__ == "__main__":
    try:
        verify(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "."))
    except (OSError, ValueError, KeyError, json.JSONDecodeError, zipfile.BadZipFile) as e:
        print("FAIL protected baseline integrity: " + str(e), file=sys.stderr)
        raise SystemExit(1)
