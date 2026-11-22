-- Machine Spirit doctrines: bounded, on-demand module inventory snapshot.
-- No new script events, tick scans, or machine-spirit state authority.
local M = {}

local MODULES = {
  ["tech-priests-order-module-1"] = { order = 10 },
  ["tech-priests-order-module-2"] = { order = 20 },
  ["tech-priests-chaos-module-1"] = { chaos = 12, resilience = 0.12, waste = 0.08 },
  ["tech-priests-chaos-module-2"] = { chaos = 22, resilience = 0.25, waste = 0.14 }
}
local EMPTY = { order = 0, chaos = 0, resilience = 0, waste = 0 }
local SAMPLE_INTERVAL_TICKS = 60

function M.count_contents(contents)
  local snapshot = { order = 0, chaos = 0, resilience = 0, waste = 0 }
  for _, entry in pairs(contents or {}) do
    local spec = entry and MODULES[entry.name]
    if spec then
      local count = math.max(0, math.floor(tonumber(entry.count) or 0))
      for _, field in ipairs({ "order", "chaos", "resilience", "waste" }) do
        snapshot[field] = snapshot[field] + (spec[field] or 0) * count
      end
    end
  end
  snapshot.resilience = math.min(0.70, snapshot.resilience)
  snapshot.waste = math.min(0.45, snapshot.waste)
  return snapshot
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
      record.machine_spirit_module_sample_error = tostring(result)
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

function M.detritus_chance(record, chance)
  chance = math.max(0, math.min(1, tonumber(chance) or 0))
  return math.min(1, chance + (1 - chance) * M.snapshot(record).waste)
end

return M
