#!/usr/bin/env python3
"""Apply Stage 5 Repair Batch 2 to the local working tree.

Batch 2 is intentionally small. It edits only:
  - tech-priests_src/scripts/core/ground_item_hoover_0529.lua
  - tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_2_RESULT.md

It does not commit, package, or bump versions.

Run from repository root:
  python tools/apply_stage5_repair_batch2.py

Then inspect:
  git diff -- tech-priests_src/scripts/core/ground_item_hoover_0529.lua
  git diff -- tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_2_RESULT.md
"""

from __future__ import annotations

from pathlib import Path

HOOVER = Path("tech-priests_src/scripts/core/ground_item_hoover_0529.lua")
RESULT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_2_RESULT.md")


def read(path: Path) -> str:
    if not path.exists():
        raise SystemExit(f"missing file: {path}")
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def replace_once(text: str, old: str, new: str, label: str) -> tuple[str, bool]:
    if new in text:
        print(f"already patched: {label}")
        return text, False
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    print(f"patched: {label}")
    return text.replace(old, new, 1), True


def patch_hoover() -> list[str]:
    text = read(HOOVER)
    changes: list[str] = []

    old = '''  if dist_sq(pair.priest.position,box.position) > M.pickup_radius_sq then
    task.phase="move-to-storage"
    task.storage=box
    request_move(pair,box,"ground-hoover-storage-0529",1.2)
    record(pair,"move-to-storage",tostring(item).." x"..tostring(count).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
    return true,"moving-to-storage"
  end
'''
    new = '''  if dist_sq(pair.priest.position,box.position) > M.pickup_radius_sq then
    task.phase="move-to-storage"
    task.storage=box
    local moved=request_move(pair,box,"ground-hoover-storage-0529",1.2)
    if not moved then
      record(pair,"movement-request-failed-0529",tostring(item).." x"..tostring(count).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
      return false,"movement-request-failed"
    end
    record(pair,"move-to-storage",tostring(item).." x"..tostring(count).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
    return true,"moving-to-storage"
  end
'''
    text, changed = replace_once(text, old, new, "0529 move-to-storage failure handling")
    if changed:
        changes.append("0529 no longer reports moving-to-storage after failed movement request.")

    old = '''    if dist_sq(pair.priest.position,src.position) > M.pickup_radius_sq then
      request_move(pair,src,"ground-hoover-pickup-0529",1.05)
      return true,"moving-to-ground-item"
    end
'''
    new = '''    if dist_sq(pair.priest.position,src.position) > M.pickup_radius_sq then
      local moved=request_move(pair,src,"ground-hoover-pickup-0529",1.05)
      if not moved then
        record(pair,"movement-request-failed-0529",tostring(task.item).." from ground#"..tostring(src.unit_number or "?"))
        return false,"movement-request-failed"
      end
      return true,"moving-to-ground-item"
    end
'''
    text, changed = replace_once(text, old, new, "0529 move-to-item failure handling")
    if changed:
        changes.append("0529 no longer reports moving-to-ground-item after failed movement request.")

    write(HOOVER, text)
    return changes


def write_result(changes: list[str]) -> None:
    RESULT.parent.mkdir(parents=True, exist_ok=True)
    body = [
        "# Stage 5 Repair Batch 2 Result",
        "",
        "This file is written by `tools/apply_stage5_repair_batch2.py` after applying the local source patch.",
        "",
        "No version bump is included in this batch.",
        "",
        "## Applied changes",
        "",
    ]
    body.extend(f"- {change}" for change in changes)
    body.extend([
        "",
        "## Explicitly not changed",
        "",
        "- No timeout behavior added.",
        "- No storage placement behavior changed.",
        "- No deposit behavior changed.",
        "- No logical carried item cleanup changed.",
        "- No generated legacy files changed.",
        "- No version bump applied.",
        "",
        "## Required inspection",
        "",
        "Run:",
        "",
        "```text",
        "git diff -- tech-priests_src/scripts/core/ground_item_hoover_0529.lua",
        "git diff -- tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_2_RESULT.md",
        "```",
        "",
        "Then package/test before any version bump.",
        "",
    ])
    write(RESULT, "\n".join(body))


def main() -> int:
    changes = patch_hoover()
    if not changes:
        print("No source changes applied; Batch 2 may already be applied.")
        return 0
    write_result(changes)
    print("Applied Stage 5 Repair Batch 2 source patch locally:")
    for change in changes:
        print(f" - {change}")
    print(f"Wrote {RESULT}")
    print("Inspect git diff before committing. Do not version bump yet.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
