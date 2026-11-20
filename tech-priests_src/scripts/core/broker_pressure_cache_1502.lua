-- Per-pulse adaptive budget pressure memo. Transient and save-independent.
-- Invalidate only when external runtime pressure counters actually change.
local M = {}
local pressure_metrics = {
  event_repair_submitted = true, directed_wake_issued = true,
  event_construction_submitted = true, directed_wake_construction_issued = true,
  event_sanctify_submitted = true, directed_wake_sanctify_issued = true,
  event_pickup_submitted = true, directed_wake_pickup_issued = true,
  path_requests = true, movement_active_requests_processed = true,
  combat_targets_seen = true, combat_wake_issued = true,
}
local entries = {}
local revision = 0

function M.begin_pulse()
  -- Separate pulse invocations may execute at the same game tick. Never
  -- reuse a sampled budget across callbacks to the broker's public pulse.
  entries = {}
  revision = 0
end

function M.note_external_metric(metric)
  if pressure_metrics[metric] then revision = revision + 1 end
end

function M.read(category, compute)
  if category == nil then category = "" end
  local result = entries[category]
  if result and result.revision == revision then return result.value end
  local value = compute(category)
  entries[category] = {revision = revision, value = value}
  return value
end

return M
