#!/usr/bin/env python3
"""Apply Stage 5 Repair Batch 1 to the local working tree.

This script intentionally does not commit, package, or bump versions.
It edits only:
  - tech-priests_src/scripts/core/movement_controller.lua
  - tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua
  - tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua
  - tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_1_RESULT.md

Run from repository root:
  python tools/apply_stage5_repair_batch1.py

Then inspect:
  git diff -- tech-priests_src/scripts/core/movement_controller.lua
  git diff -- tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua
  git diff -- tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua
"""

from __future__ import annotations

from pathlib import Path

MOVEMENT = Path("tech-priests_src/scripts/core/movement_controller.lua")
FETCH = Path("tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua")
MACHINE = Path("tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua")
RESULT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_1_RESULT.md")


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


def patch_movement_controller() -> list[str]:
    text = read(MOVEMENT)
    changes: list[str] = []

    old = '''  root.stats.requests = (root.stats.requests or 0) + 1; metric("path_requests",1)
  return true
end

function M.combat_intent(pair, target, reason, opts)
'''
    new = '''  root.stats.requests = (root.stats.requests or 0) + 1; metric("path_requests",1)
  return true, req
end

function M.request_status(pair, owner)
  local root = ensure_root()
  local status = {
    status = "unknown",
    active = false,
    owner_match = false,
    tick = now(),
  }
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then
    status.status = "invalid-pair"
    return status
  end
  local key = pair_key(pair)
  local req = (key and root.requests and root.requests[key]) or pair.movement_request_0418
  status.state = pair.movement_controller_state_0418
  status.clamp = pair.movement_controller_clamp_0418
  if not req then
    status.status = "missing-request"
    status.clamp = clamp_reason(pair) or status.clamp
    pair.movement_controller_status_0418 = status.status
    return status
  end
  status.active = true
  status.owner = req.owner
  status.reason = req.reason
  status.expires_tick = req.expires_tick
  status.last_command_tick = req.last_command_tick
  status.last_distance_sq = req.last_distance_sq
  local expected_owner = owner and tostring(owner) or nil
  status.owner_match = (not expected_owner) or tostring(req.owner or "") == expected_owner
  if expected_owner and not status.owner_match then
    status.status = "replaced-by-other-owner"
    status.active = false
    pair.movement_controller_status_0418 = status.status
    return status
  end
  if req.expires_tick and req.expires_tick < now() then
    status.status = "expired"
    status.active = false
    pair.movement_controller_status_0418 = status.status
    return status
  end
  local d2 = dist_sq(pair.priest.position, req) or 999999999
  local radius = math.max(0.15, tonumber(req.radius) or M.default_radius)
  status.distance_sq = d2
  status.radius = radius
  if d2 <= (radius + M.loiter_radius_pad) * (radius + M.loiter_radius_pad) then
    status.status = "arrived"
    status.arrived = true
    pair.movement_controller_status_0418 = status.status
    return status
  end
  local clamp = clamp_reason(pair)
  if clamp then
    status.status = "clamped"
    status.clamp = clamp
    pair.movement_controller_status_0418 = status.status
    return status
  end
  status.status = "active"
  pair.movement_controller_status_0418 = status.status
  return status
end

function M.combat_intent(pair, target, reason, opts)
'''
    text, changed = replace_once(text, old, new, "movement_controller request_status helper")
    if changed:
      changes.append("Added M.request_status(pair, owner) and optional second return from M.request.")

    old = '''  _G.tech_priests_stop_movement_0418 = function(pair, reason)
    return M.stop(pair, reason)
  end
  _G.tech_priests_route_ground_command_0429 = function(priest, command, owner, opts)
'''
    new = '''  _G.tech_priests_stop_movement_0418 = function(pair, reason)
    return M.stop(pair, reason)
  end
  _G.tech_priests_movement_status_0418 = function(pair, owner)
    return M.request_status(pair, owner)
  end
  _G.tech_priests_route_ground_command_0429 = function(priest, command, owner, opts)
'''
    text, changed = replace_once(text, old, new, "movement_controller status global")
    if changed:
      changes.append("Exported _G.tech_priests_movement_status_0418.")

    old = '''    if req then
      player.print("  request owner=" .. tostring(req.owner) .. " reason=" .. tostring(req.reason) .. " target=" .. string.format("%.2f,%.2f", req.x, req.y) .. " radius=" .. tostring(req.radius) .. " last_cmd=" .. tostring(req.last_command_tick or "nil") .. " d2=" .. tostring(req.last_distance_sq or "nil"))
    else
      player.print("  request=nil")
    end
    local snap = pair.last_ground_snap_0418 or root.last_snap
'''
    new = '''    if req then
      player.print("  request owner=" .. tostring(req.owner) .. " reason=" .. tostring(req.reason) .. " target=" .. string.format("%.2f,%.2f", req.x, req.y) .. " radius=" .. tostring(req.radius) .. " last_cmd=" .. tostring(req.last_command_tick or "nil") .. " d2=" .. tostring(req.last_distance_sq or "nil"))
    else
      player.print("  request=nil")
    end
    local mstatus = M.request_status(pair)
    if mstatus then
      player.print("  status=" .. tostring(mstatus.status or "nil") .. " owner=" .. tostring(mstatus.owner or "nil") .. " match=" .. tostring(mstatus.owner_match) .. " expires=" .. tostring(mstatus.expires_tick or "nil") .. " d2=" .. tostring(mstatus.distance_sq or "nil") .. " clamp=" .. tostring(mstatus.clamp or "none"))
    end
    local snap = pair.last_ground_snap_0418 or root.last_snap
'''
    text, changed = replace_once(text, old, new, "movement_controller diagnostic status print")
    if changed:
      changes.append("Added request status line to /tp-movement-0429.")

    write(MOVEMENT, text)
    return changes


def patch_fetch_0527() -> list[str]:
    text = read(FETCH)
    old = '''  if d2 > M.pickup_radius_sq then
    request_move(pair, src.source, item)
    return true, "moving-to-known-source"
  end
'''
    new = '''  if d2 > M.pickup_radius_sq then
    local moved = request_move(pair, src.source, item)
    if not moved then
      r.cooldowns[key] = now() + math.min(M.cooldown_ticks, 60)
      record(pair, "movement-request-failed-0527", tostring(item) .. " from " .. tostring(src.source.name) .. "#" .. tostring(src.source.unit_number or "?"))
      return false, "movement-request-failed"
    end
    return true, "moving-to-known-source"
  end
'''
    text, changed = replace_once(text, old, new, "0527 moving-to-known-source failure handling")
    write(FETCH, text)
    return ["0527 no longer reports moving-to-known-source after failed movement request."] if changed else []


def patch_machine_0528() -> list[str]:
    text = read(MACHINE)
    changes: list[str] = []

    old = '''    request_move(pair, box, kind == "waste" and "waste-box-deposit-0528" or "retention-box-deposit-0528", 1.25)
    record(pair, "move-to-storage", tostring(kind) .. " " .. tostring(carried.item) .. " x" .. tostring(carried.count) .. " -> " .. machine_label(box))
    return true, "moving-to-storage"
'''
    new = '''    local moved = request_move(pair, box, kind == "waste" and "waste-box-deposit-0528" or "retention-box-deposit-0528", 1.25)
    if not moved then
      record(pair, "movement-request-failed-0528", tostring(kind) .. " " .. tostring(carried.item) .. " x" .. tostring(carried.count) .. " -> " .. machine_label(box))
      return false, "movement-request-failed"
    end
    record(pair, "move-to-storage", tostring(kind) .. " " .. tostring(carried.item) .. " x" .. tostring(carried.count) .. " -> " .. machine_label(box))
    return true, "moving-to-storage"
'''
    text, changed = replace_once(text, old, new, "0528 move-to-storage failure handling")
    if changed:
      changes.append("0528 no longer reports moving-to-storage after failed movement request.")

    old = '''    if dist_sq(pair.priest.position, machine.position) > M.machine_reach_sq then
      request_move(pair, machine, "machine-service-0528", 1.25)
      return true, "moving-to-machine"
    end
'''
    new = '''    if dist_sq(pair.priest.position, machine.position) > M.machine_reach_sq then
      local moved = request_move(pair, machine, "machine-service-0528", 1.25)
      if not moved then
        record(pair, "movement-request-failed-0528", "machine-service " .. machine_label(machine))
        return false, "movement-request-failed"
      end
      return true, "moving-to-machine"
    end
'''
    text, changed = replace_once(text, old, new, "0528 move-to-machine failure handling")
    if changed:
      changes.append("0528 no longer reports moving-to-machine after failed movement request.")

    write(MACHINE, text)
    return changes


def write_result(changes: list[str]) -> None:
    RESULT.parent.mkdir(parents=True, exist_ok=True)
    body = [
        "# Stage 5 Repair Batch 1 Result",
        "",
        "This file is written by `tools/apply_stage5_repair_batch1.py` after applying the local source patch.",
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
        "- No machine output destination prevalidation added.",
        "- No direct acquisition gathered_units/deposit behavior changed.",
        "- No generated legacy files changed.",
        "- No version bump applied.",
        "",
        "## Required inspection",
        "",
        "Run:",
        "",
        "```text",
        "git diff -- tech-priests_src/scripts/core/movement_controller.lua",
        "git diff -- tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua",
        "git diff -- tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua",
        "```",
        "",
        "Then package/test before any version bump.",
        "",
    ])
    write(RESULT, "\n".join(body))


def main() -> int:
    changes: list[str] = []
    changes.extend(patch_movement_controller())
    changes.extend(patch_fetch_0527())
    changes.extend(patch_machine_0528())
    if not changes:
        print("No source changes applied; Batch 1 may already be applied.")
        return 0
    write_result(changes)
    print("Applied Stage 5 Repair Batch 1 source patch locally:")
    for change in changes:
        print(f" - {change}")
    print(f"Wrote {RESULT}")
    print("Inspect git diff before committing. Do not version bump yet.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
