#!/usr/bin/env python3
"""Apply Stage 5 Repair Batch 2: ground_item_hoover_0529 movement request failure handling.

This patch is intentionally narrow:
- ground-hoover move-to-storage checks request_move return.
- ground-hoover move-to-item checks request_move return.
- records movement-request-failed-0529.
- does not change storage/deposit, timeout, inventory, version, or generated files.

Run from repository root:
    python tools/apply_stage5_repair_batch2_ground_hoover.py
"""

from __future__ import annotations

from pathlib import Path

SRC = Path("tech-priests_src/scripts/core/ground_item_hoover_0529.lua")
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


def main() -> int:
    text = read(SRC)
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
      record(pair,"movement-request-failed-0529",tostring(item).." x"..tostring(count).." -> storage "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
      return false,"movement-request-failed"
    end
    record(pair,"move-to-storage",tostring(item).." x"..tostring(count).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
    return true,"moving-to-storage"
  end
'''
    text, changed = replace_once(text, old, new, "ground hoover move-to-storage failure handling")
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
    text, changed = replace_once(text, old, new, "ground hoover move-to-item failure handling")
    if changed:
        changes.append("0529 no longer reports moving-to-ground-item after failed movement request.")

    if not changes:
        print("No changes applied; Batch 2 may already be applied.")
        return 0

    write(SRC, text)
    RESULT.parent.mkdir(parents=True, exist_ok=True)
    write(RESULT, "\n".join([
        "# Stage 5 Repair Batch 2 Result",
        "",
        "Applied by `tools/apply_stage5_repair_batch2_ground_hoover.py`.",
        "",
        "## Applied changes",
        "",
        *[f"- {c}" for c in changes],
        "",
        "## Explicitly not changed",
        "",
        "- No timeout behavior added.",
        "- No storage/deposit behavior changed.",
        "- No inventory accounting changed.",
        "- No generated legacy files changed.",
        "- No version bump applied.",
        "",
    ]))
    print("Applied Stage 5 Repair Batch 2:")
    for c in changes:
        print(f" - {c}")
    print(f"Wrote {RESULT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
