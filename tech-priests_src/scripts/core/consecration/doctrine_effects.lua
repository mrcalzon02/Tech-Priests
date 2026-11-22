-- Machine Spirit doctrines: bounded, on-demand module inventory snapshot.
-- No new script events, tick scans, or machine-spirit state authority.
local M = {}

local MODULES = {
  ["tech-priests-order-module-1"] = { order = 10 },
  ["tech-priests-order-module-2"] = { order = 20 },
  ["tech-priests-chaos-module-1"] = { chaos = 12, resilience = 0.12, waste = 0.08, extraction = 0.20 },
  ["tech-priests-chaos-module-2"] = { chaos = 22, resilience = 0.25, waste = 0.14, extraction = 0.40 }
}
local EMPTY = { order = 0, chaos = 0, resilience = 0, waste = 0, extraction = 0 }
local SAMPLE_INTERVAL_TICKS = 60
local FAILED_SAMPLE_RETRY_TICKS = 15
local EFFECT_FIELDS = { "order", "chaos", "resilience", "waste", "extraction" }
-- Factorio's native module effects scale with the module item's own quality.
-- Scale these separate scripted Machine Spirit effects by item quality too.
-- The five standard levels give Normal 1.0x through Legendary 1.5x.
local STANDARD_QUALITY_LEVELS = {normal=0,uncommon=1,rare=2,epic=3,legendary=5}

function M.quality_multiplier(quality_name)
  local level = STANDARD_QUALITY_LEVELS[quality_name] or 0
  -- Support custom Quality prototypes without inventing a bonus for unknown
  -- quality names; level is deliberately capped to bound balance.
  if prototypes and prototypes.quality and prototypes.quality[quality_name] then
    level = tonumber(prototypes.quality[quality_name].level) or level
  end
  level = math.max(0, math.min(5, level))
  return 1 + 0.10 * level
end

function M.count_contents(contents)
  local snapshot = { order = 0, chaos = 0, resilience = 0, waste = 0, extraction = 0 }
  for _, entry in pairs(contents or {}) do
    local spec = entry and MODULES[entry.name]
    if spec then
      local count = math.max(0, math.floor(tonumber(entry.count) or 0))
      local quality_multiplier = M.quality_multiplier(entry.quality)
      for _, field in ipairs(EFFECT_FIELDS) do
        snapshot[field] = snapshot[field] + (spec[field] or 0) * count * quality_multiplier
      end
    end
  end
  snapshot.resilience = math.min(0.70, snapshot.resilience)
  snapshot.waste = math.min(0.45, snapshot.waste)
  snapshot.extraction = math.min(1, snapshot.extraction)
  return snapshot
end

-- A direct, entity-specific inventory interaction may invalidate one record.
-- Preserve the last good snapshot until a fresh engine inventory read succeeds.
-- Indirect robot/script changes still use the existing 60-tick fallback.
function M.invalidate(record)
  if not record then return false end
  record.machine_spirit_module_resample_tick = nil
  return true
end

function M.snapshot_changed(before, after)
  for _, field in ipairs(EFFECT_FIELDS) do
    if (before and before[field] or 0) ~= (after and after[field] or 0) then
      return true
    end
  end
  return false
end

function M.snapshot(record)
  if not record then return EMPTY end
  local now = game and game.tick or 0
  if record.machine_spirit_module_snapshot
    and now < (record.machine_spirit_module_resample_tick or 0) then
    return record.machine_spirit_module_snapshot
  end
  local contents = nil
  local entity = record.entity
  if entity and entity.valid then
    local ok, result = pcall(function()
      local inventory = entity.get_module_inventory()
      return inventory and inventory.get_contents() or nil
    end)
    if ok then
      contents = result
      record.machine_spirit_module_sample_error = nil
    else
      -- A transient inventory API failure must not silently drop paid module
      -- benefits or penalties. Retry on the next serviced access after 15 ticks,
      -- never from an added tick loop or global scan.
      record.machine_spirit_module_sample_error = tostring(result)
      record.machine_spirit_module_resample_tick = now + FAILED_SAMPLE_RETRY_TICKS
      -- A never-sampled record must also honor the bounded retry interval.
      record.machine_spirit_module_snapshot = record.machine_spirit_module_snapshot or M.count_contents(nil)
      return record.machine_spirit_module_snapshot
    end
  end
  local snapshot = M.count_contents(contents)
  record.machine_spirit_module_snapshot = snapshot
  record.machine_spirit_module_resample_tick = now + SAMPLE_INTERVAL_TICKS
  return snapshot
end

function M.effective_value(record)
  if not record then return 0 end
  local maximum = math.max(1, tonumber(record.max_sanctification) or 100)
  local mods = M.snapshot(record)
  local current = tonumber(record.sanctification) or 0
  return math.max(0, math.min(maximum, current + mods.order - mods.chaos))
end

function M.performance_ratio(record, ratio)
  ratio = math.max(0, math.min(1, tonumber(ratio) or 0))
  local mods = M.snapshot(record)
  return math.min(1, ratio + (1 - ratio) * mods.resilience)
end

-- Chaos lowers *effective* sanctity for extraction, not the stored machine
-- condition. Suppressing sanctity for a doctrine must not itself inflict more
-- physical wear than the same machine had before its profane module was fitted.
-- Order may protect against wear through its positive effective sanctity.
function M.damage_value(record)
  if not record then return 0 end
  local maximum = math.max(1, tonumber(record.max_sanctification) or 100)
  local current = math.max(0, math.min(maximum, tonumber(record.sanctification) or 0))
  return math.max(current, M.effective_value(record))
end

function M.damage_multiplier(record)
  return math.max(0.30, 1 - M.snapshot(record).resilience)
end

-- Distinguish a deliberately profane production stance from the physical
-- condition that can destroy stored fuel or disable an occupied vehicle.
-- Order may improve safety; Chaos never manufactures additional hazard merely
-- by reducing effective sanctity for extraction. Clamp to the established
-- engine-facing minimum so all hazards retain a nonzero failure possibility.
function M.hazard_ratio(record, minimum_ratio)
  local floor = math.max(0, math.min(1, tonumber(minimum_ratio) or 0))
  if not record then return floor end
  local maximum = math.max(1, tonumber(record.max_sanctification) or 100)
  return math.max(floor, math.min(1, M.damage_value(record) / maximum))
end

-- A single capped resilience factor applies to each independently rolled
-- malfunction hazard, not just the physical damage branch. Retain a 30%
-- residual chance even at maximum Chaos resilience; never grant immunity.
function M.hazard_chance(record, chance)
  local base_chance = math.max(0, math.min(1, tonumber(chance) or 0))
  return base_chance * M.damage_multiplier(record)
end

-- At very low sanctity the ordinary detritus chance already reaches 100%.
-- Raising probability alone would make Chaos extraction bonuses inert.
-- Increase operation-linked physical detritus quantity instead; preserve
-- recipe product-slot and output-inventory enforcement by the existing owner.
function M.detritus_quantity_multiplier(record, ratio)
  ratio = math.max(0, math.min(1, tonumber(ratio) or 1))
  return 1 + M.snapshot(record).extraction * (1 - ratio)
end

function M.detritus_chance(record, chance)
  chance = math.max(0, math.min(1, tonumber(chance) or 0))
  return math.min(1, chance + (1 - chance) * M.snapshot(record).waste)
end


-- Expose doctrine effects without confusing stored machine condition with the
-- effective sanctity used for performance and low-sanctity output decisions.
function M.status_line(record)
  if not record then return "" end
  local current = tonumber(record.sanctification) or 0
  local maximum = math.max(1, tonumber(record.max_sanctification) or 100)
  local modifiers = M.snapshot(record)
  if modifiers.order == 0 and modifiers.chaos == 0 then
    return string.format("%.1f / %.1f", current, maximum)
  end
  return string.format("%.1f / %.1f (eff %.1f)", current, maximum, M.effective_value(record))
end

return M
