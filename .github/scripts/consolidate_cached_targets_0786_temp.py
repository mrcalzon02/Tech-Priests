#!/usr/bin/env python3
"""Temporary guarded transformation for canonical cached target selectors."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PART3_PATH = ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua"
PART14_PATH = ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua"
HISTORY_PATH = ROOT / "docs/DEVELOPMENT_HISTORY.md"
LUA_PATHS = sorted((ROOT / "tech-priests_src").rglob("*.lua"))


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one exact source block, found {count}")
    return text.replace(old, new, 1)


all_before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in LUA_PATHS)
for needle, expected in {
    "function find_damaged_target(station, radius, priest)": 2,
    "find_consecration_target_for_station = function(station, radius, priest)": 2,
}.items():
    actual = all_before.count(needle)
    if actual != expected:
        raise SystemExit(f"pre-patch ownership mismatch: {needle!r} expected {expected}, found {actual}")

part3 = PART3_PATH.read_text(encoding="utf-8")
old_repair = '''function find_damaged_target(station, radius, priest)
  local surface = station.surface
  local force = station.force
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }

  local entities = surface.find_entities_filtered({ area = area, force = force })
  local best = nil
  local best_distance = nil

  for _, entity in pairs(entities) do
    if entity.valid and entity.health and entity.max_health and entity.max_health > 0 then
      if can_fully_use_repair_pack(entity) and not is_priest(entity) and entity.name ~= PROXY_NAME then
        local dx = entity.position.x - position.x
        local dy = entity.position.y - position.y
        local distance_sq = dx * dx + dy * dy
        if distance_sq <= radius * radius then
          local score = distance_sq
          if priest and priest.valid then
            local pdx = entity.position.x - priest.position.x
            local pdy = entity.position.y - priest.position.y
            score = math.min(distance_sq, pdx * pdx + pdy * pdy)
          end
          if not best_distance or score < best_distance then
            best = entity
            best_distance = score
          end
        end
      end
    end
  end

  return best
end'''
part3 = replace_once(
    part3,
    old_repair,
    '''-- 0.1.674-dev / 0786: the original live repair scan is merged into the final
-- 0248 cache-aware selector in fragment 014.
TECH_PRIESTS_BASE_FIND_DAMAGED_TARGET_0248_MERGED = true''',
    "fragment 003 repair selector",
)

old_consecration = '''find_consecration_target_for_station = function(station, radius, priest)
  if not (station and station.valid) then return nil end
  if not station_has_consecration_item(station) then return nil end

  local targets = station.surface.find_entities_filtered({
    name = CONSECRATION_TARGET_NAME_LIST,
    force = station.force,
    position = station.position,
    radius = radius or get_station_consecration_radius(station)
  })

  local best = nil
  local best_ratio = 1.01
  local best_distance = nil

  for _, entity in pairs(targets) do
    local record = get_consecration_record(entity)
    if record then
      local max_value = record.max_sanctification or get_base_sanctification_max()
      local value = record.sanctification or 0
      if max_value > 0 and value < max_value then
        local missing = max_value - value
        local useful_item = get_available_station_consecration_item(station, missing)
        if useful_item then
          local ratio = value / max_value
          local dx = station.position.x - entity.position.x
          local dy = station.position.y - entity.position.y
          local distance = dx * dx + dy * dy
          if priest and priest.valid then
            local pdx = priest.position.x - entity.position.x
            local pdy = priest.position.y - entity.position.y
            distance = math.min(distance, pdx * pdx + pdy * pdy)
          end
          if ratio < best_ratio or (math.abs(ratio - best_ratio) < 0.001 and (not best_distance or distance < best_distance)) then
            best = entity
            best_ratio = ratio
            best_distance = distance
          end
        end
      end
    end
  end

  return best
end'''
part3 = replace_once(
    part3,
    old_consecration,
    '''-- 0.1.674-dev / 0786: the original live consecration scan is merged into the
-- final 0248 cache-aware selector in fragment 014.
TECH_PRIESTS_BASE_FIND_CONSECRATION_TARGET_0248_MERGED = true''',
    "fragment 003 consecration selector",
)
PART3_PATH.write_text(part3, encoding="utf-8")

part14 = PART14_PATH.read_text(encoding="utf-8")
old_wrappers = '''TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248 = find_damaged_target
function find_damaged_target(station, radius, priest)
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "repair_targets", function(entity)
      return tech_priests_0248_is_repair_target(station, entity)
    end)
    if cached then return cached end
  end
  if TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248 then return TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248(station, radius, priest) end
  return nil
end

TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248 = find_consecration_target_for_station
find_consecration_target_for_station = function(station, radius, priest)
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "sanctify_targets", function(entity)
      return tech_priests_0248_is_sanctification_target(entity)
    end)
    if cached then return cached end
  end
  if TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248 then return TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248(station, radius, priest) end
  return nil
end'''
new_selectors = '''-- 0.1.674-dev / 0786: canonical cache-aware plus live target selectors.
TECH_PRIESTS_FIND_DAMAGED_TARGET_PREDECESSOR_RETIRED = true
TECH_PRIESTS_FIND_CONSECRATION_TARGET_PREDECESSOR_RETIRED = true

function tech_priests_0248_target_inside_radius_0786(station, entity, radius)
  if not (station and station.valid and entity and entity.valid and entity.position) then return false end
  radius = radius or 20
  local dx = entity.position.x - station.position.x
  local dy = entity.position.y - station.position.y
  return dx * dx + dy * dy <= radius * radius
end

function tech_priests_0248_repair_score_0786(station, priest, entity)
  local dx = entity.position.x - station.position.x
  local dy = entity.position.y - station.position.y
  local score = dx * dx + dy * dy
  if priest and priest.valid then
    local pdx = entity.position.x - priest.position.x
    local pdy = entity.position.y - priest.position.y
    score = math.min(score, pdx * pdx + pdy * pdy)
  end
  return score
end

function find_damaged_target(station, radius, priest)
  if not (station and station.valid) then return nil end
  radius = radius or 20
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "repair_targets", function(entity)
      return tech_priests_0248_is_repair_target(station, entity)
        and tech_priests_0248_target_inside_radius_0786(station, entity, radius)
    end)
    if cached then return cached end
  end

  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius },
  }
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })
  local best = nil
  local best_score = nil
  for _, entity in pairs(entities or {}) do
    if tech_priests_0248_is_repair_target(station, entity)
      and tech_priests_0248_target_inside_radius_0786(station, entity, radius) then
      local score = tech_priests_0248_repair_score_0786(station, priest, entity)
      if not best_score or score < best_score then
        best = entity
        best_score = score
      end
    end
  end
  return best
end

function tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius)
  if not tech_priests_0248_is_sanctification_target(entity) then return nil end
  if not tech_priests_0248_target_inside_radius_0786(station, entity, radius) then return nil end
  local record = get_consecration_record and get_consecration_record(entity) or nil
  if not record then return nil end
  local max_value = record.max_sanctification or get_base_sanctification_max()
  local value = record.sanctification or 0
  if not (max_value and max_value > 0 and value < max_value) then return nil end
  local missing = max_value - value
  local useful_item = get_available_station_consecration_item and get_available_station_consecration_item(station, missing) or nil
  if not useful_item then return nil end
  local dx = station.position.x - entity.position.x
  local dy = station.position.y - entity.position.y
  local distance = dx * dx + dy * dy
  if priest and priest.valid then
    local pdx = priest.position.x - entity.position.x
    local pdy = priest.position.y - entity.position.y
    distance = math.min(distance, pdx * pdx + pdy * pdy)
  end
  return { entity = entity, ratio = value / max_value, distance = distance, item = useful_item }
end

find_consecration_target_for_station = function(station, radius, priest)
  if not (station and station.valid) then return nil end
  if not (station_has_consecration_item and station_has_consecration_item(station)) then return nil end
  radius = radius or (get_station_consecration_radius and get_station_consecration_radius(station)) or 20
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "sanctify_targets", function(entity)
      return tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius) ~= nil
    end)
    if cached then return cached end
  end

  local targets = station.surface.find_entities_filtered({
    name = CONSECRATION_TARGET_NAME_LIST,
    force = station.force,
    position = station.position,
    radius = radius,
  })
  local best = nil
  local best_ratio = 1.01
  local best_distance = nil
  for _, entity in pairs(targets or {}) do
    local candidate = tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius)
    if candidate and (candidate.ratio < best_ratio
      or (math.abs(candidate.ratio - best_ratio) < 0.001 and (not best_distance or candidate.distance < best_distance))) then
      best = candidate.entity
      best_ratio = candidate.ratio
      best_distance = candidate.distance
    end
  end
  return best
end'''
part14 = replace_once(part14, old_wrappers, new_selectors, "fragment 014 cached target wrappers")
PART14_PATH.write_text(part14, encoding="utf-8")

all_after = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in LUA_PATHS)
for needle, expected in {
    "function find_damaged_target(station, radius, priest)": 1,
    "find_consecration_target_for_station = function(station, radius, priest)": 1,
    "function tech_priests_0248_target_inside_radius_0786(station, entity, radius)": 1,
    "function tech_priests_0248_repair_score_0786(station, priest, entity)": 1,
    "function tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius)": 1,
}.items():
    actual = all_after.count(needle)
    if actual != expected:
        raise SystemExit(f"post-patch ownership mismatch: {needle!r} expected {expected}, found {actual}")
for forbidden in (
    "TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248",
    "TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248",
):
    if forbidden in all_after:
        raise SystemExit(f"post-patch forbidden predecessor remains: {forbidden}")
for required in (
    "TECH_PRIESTS_BASE_FIND_DAMAGED_TARGET_0248_MERGED = true",
    "TECH_PRIESTS_BASE_FIND_CONSECRATION_TARGET_0248_MERGED = true",
    "TECH_PRIESTS_FIND_DAMAGED_TARGET_PREDECESSOR_RETIRED = true",
    "TECH_PRIESTS_FIND_CONSECRATION_TARGET_PREDECESSOR_RETIRED = true",
    'tech_priests_0248_first_valid_from_cache(pair, "repair_targets"',
    'tech_priests_0248_first_valid_from_cache(pair, "sanctify_targets"',
    "tech_priests_0248_target_inside_radius_0786(station, entity, radius)",
    "get_available_station_consecration_item(station, missing)",
    "can_fully_use_repair_pack",
):
    if required not in all_after:
        raise SystemExit(f"post-patch required contract missing: {required}")

history = HISTORY_PATH.read_text(encoding="utf-8")
heading = "## 2026-07-21 — Milestone 0786: Canonical Cached Repair and Consecration Selectors"
if heading not in history:
    history += f'''\n\n{heading}\n\nConsolidated the 0.1.248 repair and consecration target predecessor wrappers into one cache-aware canonical selector for each work family. Fragment 014 now owns cache-first selection plus the original live fallback scans. Cached repair candidates must satisfy force, health, priest/proxy exclusion, useful repair-pack damage, and current station-radius bounds. Cached consecration candidates must satisfy current radius, sanctification record state, incomplete progress, station supply, and useful-item rules before selection. The original fragment 003 selectors and both 0248 predecessor captures are explicitly retired. Static Source validation does not constitute Factorio runtime proof.\n'''
    HISTORY_PATH.write_text(history, encoding="utf-8")

print("0786 transformation complete: one repair selector and one consecration selector")
