#!/usr/bin/env python3
"""Split oversized GUI Lua files into editable workbench chunks.

Run from repository root after `git pull`:

    python tools/split_gui_sources_0635.py

Output:

    workbench/gui_split_0635/

This tool only reads the source GUI files and writes chunk copies. It does not
modify the mod source files.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

TARGETS = [
    Path("tech-priests_src/scripts/core/consecration/history_gui.lua"),
    Path("tech-priests_src/scripts/core/station_work_inventory.lua"),
]

OUT = Path("workbench/gui_split_0635")
BOUNDARY = re.compile(r"^(local\s+function\s+[A-Za-z_][A-Za-z0-9_]*\s*\(|function\s+[A-Za-z_][A-Za-z0-9_\.]*\s*\()")

IMPORTANT = [
    "tech_priests_machine_spirit_inner_screen_0565",
    "tech_priests_machine_spirit_tabs_0526",
    "local function add_inner_screen_page_0565",
    "tech_priests_workstate_tabs_0410",
    "add_inner_bezel_shell_0567",
    "add_inner_bezel_shell_0536",
]

README = """# GUI Split Workbench 0635

Edit important chunks first.

Machine-Spirit Ledger target:
- remove `tech_priests_machine_spirit_inner_screen_0565`
- place `tech_priests_machine_spirit_tabs_0526` directly under the shell body

Work-State Reliquary target:
- edit `add_inner_screen_page_0565`
- make it create only a scroll pane, not a frame wrapping a scroll pane

After edits, manually copy the changed function chunks back into their source
files or use your editor's compare/replace tools.
"""


def root() -> Path:
    p = Path.cwd().resolve()
    for c in [p, *p.parents]:
        if (c / "tech-priests_src").exists():
            return c
    raise SystemExit("Run from inside the Tech-Priests repository")


def checksum(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def safe(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_\-]+", "_", name.replace(".", "_"))[:80].strip("_") or "chunk"


def source_key(path: Path) -> str:
    return path.as_posix().replace("/", "__").replace(".", "_")


def split_lines(text: str):
    lines = text.splitlines(keepends=True)
    starts = []
    for i, line in enumerate(lines):
        if BOUNDARY.match(line):
            label = line.strip().replace("(", "").replace(")", "")
            label = label.replace("local function ", "").replace("function ", "")
            starts.append((i, label))
    if not starts:
        return [("whole_file", 1, len(lines), text)]
    chunks = []
    if starts[0][0] > 0:
        chunks.append(("preamble", 1, starts[0][0], "".join(lines[:starts[0][0]])))
    for n, (start, label) in enumerate(starts):
        end = starts[n + 1][0] if n + 1 < len(starts) else len(lines)
        chunks.append((label, start + 1, end, "".join(lines[start:end])))
    return chunks


def main() -> int:
    repo = root()
    out = repo / OUT
    out.mkdir(parents=True, exist_ok=True)
    (out / "README.md").write_text(README, encoding="utf-8")
    manifest = {"targets": []}
    for rel in TARGETS:
        src = repo / rel
        text = src.read_text(encoding="utf-8", errors="replace")
        folder = out / source_key(rel)
        folder.mkdir(parents=True, exist_ok=True)
        entries = []
        for i, (label, start, end, body) in enumerate(split_lines(text)):
            important = any(m in body for m in IMPORTANT)
            prefix = "IMPORTANT__" if important else ""
            filename = f"{i:03d}__{prefix}{safe(label)}.lua"
            header = f"-- split source: {rel.as_posix()} lines {start}-{end}\n"
            (folder / filename).write_text(header + body, encoding="utf-8")
            entries.append({"file": filename, "label": label, "start": start, "end": end, "important": important, "sha256": checksum(body)})
        manifest["targets"].append({"source": rel.as_posix(), "sha256": checksum(text), "folder": folder.relative_to(out).as_posix(), "chunks": entries})
        print(f"split {rel} -> {folder.relative_to(repo)}")
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"wrote {OUT / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
