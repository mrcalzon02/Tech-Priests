#!/usr/bin/env python3
"""Apply Stage 5 Repair Batch 3: crafting station-return movement failure handling.

This patch is intentionally narrow:
- crafting_executor.lua records failed station-return movement requests.
- failed movement no longer sets mode to returning-to-station-for-craft.
- the guard still returns true to block unsafe legacy field crafting.
- no timeout, inventory, crafting, version, or generated-file behavior changes.

Run from repository root:
    python tools/apply_stage5_repair_batch3_crafting_return.py
"""

from __future__ import annotations

from pathlib import Path

SRC = Path("tech-priests_src/scripts/core/crafting_executor.lua")
RESULT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_3_RESULT.md")


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
    old = '''local function move_to_station(pair, reason)
  if not valid_pair(pair) then return false end
  local stale = (not pair.last_station_craft_command_0337) or (now() - (pair.last_station_craft_command_0337.tick or 0) >= Craft.move_refresh_ticks)
  if stale then
    local ok = false
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pair.station.position, reason or "station-craft", { radius = 1.15, owner = "crafting-executor", priority = 65, distraction = defines.distraction.none })
    else
      local command = { type = defines.command.go_to_location, destination = pair.station.position, radius = 1.15, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "crafting-executor-fallback-0616", { pair = pair, priority = 65, ttl = 600 })
        ok = ok_route and res ~= false
      else
        ok = pcall(function() pair.priest.set_command(command) end)
      end
    end
    if ok then pair.last_station_craft_command_0337 = { tick = now(), reason = reason or "station-craft" } end
  end
  pair.mode = "returning-to-station-for-craft"
  local d = math.sqrt(dist_sq(pair.priest.position, pair.station.position))
  local item = pair.emergency_craft and (pair.emergency_craft.output_item or pair.emergency_craft.item_name) or nil
  draw_text(pair, string.format("%s returning to station to craft %.1fm", item_text(item), d), 28)
  return true
end
'''
    new = '''local function move_to_station(pair, reason)
  if not valid_pair(pair) then return false end
  local stale = (not pair.last_station_craft_command_0337) or (now() - (pair.last_station_craft_command_0337.tick or 0) >= Craft.move_refresh_ticks)
  local attempted = false
  local ok = true
  if stale then
    attempted = true
    ok = false
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pair.station.position, reason or "station-craft", { radius = 1.15, owner = "crafting-executor", priority = 65, distraction = defines.distraction.none })
    else
      local command = { type = defines.command.go_to_location, destination = pair.station.position, radius = 1.15, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "crafting-executor-fallback-0616", { pair = pair, priority = 65, ttl = 600 })
        ok = ok_route and res ~= false
      else
        ok = pcall(function() pair.priest.set_command(command) end)
      end
    end
    if ok then pair.last_station_craft_command_0337 = { tick = now(), reason = reason or "station-craft" } end
  end
  local d = math.sqrt(dist_sq(pair.priest.position, pair.station.position))
  local item = pair.emergency_craft and (pair.emergency_craft.output_item or pair.emergency_craft.item_name) or nil
  if attempted and not ok then
    local root = ensure_root()
    root.stats.movement_request_failed = (root.stats.movement_request_failed or 0) + 1
    root.stats.last_movement_request_failed_tick = now()
    pair.mode = "crafting-movement-request-failed"
    pair.last_station_craft_move_failed_0337 = { tick = now(), reason = reason or "station-craft", distance = d }
    draw_text(pair, string.format("%s cannot path to station to craft %.1fm", item_text(item), d), 28)
    return true
  end
  pair.mode = "returning-to-station-for-craft"
  draw_text(pair, string.format("%s returning to station to craft %.1fm", item_text(item), d), 28)
  return true
end
'''
    text, changed = replace_once(text, old, new, "crafting station-return movement failure handling")
    if not changed:
        print("No changes applied; Batch 3 may already be applied.")
        return 0
    write(SRC, text)
    RESULT.parent.mkdir(parents=True, exist_ok=True)
    write(RESULT, "\n".join([
        "# Stage 5 Repair Batch 3 Result",
        "",
        "Applied by `tools/apply_stage5_repair_batch3_crafting_return.py`.",
        "",
        "## Applied changes",
        "",
        "- `crafting_executor.lua` now records station-return movement request failure.",
        "- Failed station-return movement no longer sets `pair.mode` to `returning-to-station-for-craft`.",
        "- Failed station-return movement sets `pair.mode` to `crafting-movement-request-failed` and records `pair.last_station_craft_move_failed_0337`.",
        "- The guard still returns true after failure so legacy emergency crafting does not continue in the field.",
        "",
        "## Explicitly not changed",
        "",
        "- No timeout behavior added.",
        "- No craft completion behavior changed.",
        "- No inventory accounting changed.",
        "- No generated legacy files changed.",
        "- No version bump applied.",
        "",
    ]))
    print("Applied Stage 5 Repair Batch 3: crafting return movement failure handling")
    print(f"Wrote {RESULT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
