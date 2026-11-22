-- Machine Spirit state custody during native Factorio on_entity_cloned.
-- This copies only physical wear, never machine IDs, history or module cache.
local M = {}

local function finite_nonnegative(value)
  local n = tonumber(value)
  if not n or n ~= n or n == math.huge or n == -math.huge or n < 0 then return nil end
  return n
end

function M.transfer(source_record, destination_record, source, destination)
  if not (source_record and destination_record and source and destination
    and source.valid and destination.valid and source.unit_number and destination.unit_number
    and source.unit_number ~= destination.unit_number
    and source.name == destination.name and source.type == destination.type
    and source.force == destination.force
    and source_record.unit_number == source.unit_number
    and destination_record.unit_number == destination.unit_number) then
    return false, "incompatible-or-untracked-clone"
  end

  local previous_max = finite_nonnegative(source_record.max_sanctification)
  local previous_value = finite_nonnegative(source_record.sanctification)
  local destination_max = finite_nonnegative(destination_record.max_sanctification)
  if not (previous_max and previous_max > 0 and previous_value and destination_max and destination_max > 0) then
    return false, "invalid-sanctity-state"
  end

  -- Preserve damage, never restore a lost cap. Also respect a destination
  -- force's currently configured/researched cap without creating extra energy.
  local maximum = math.min(previous_max, destination_max)
  destination_record.max_sanctification = maximum
  destination_record.sanctification = math.min(previous_value, maximum)
  -- A scarred clone with a surviving cap <= 50 is not an obsolete 50-point
  -- save. Prevent the canonical normalizer from scaling its scar back to 100.
  destination_record.legacy_50_cap_migrated = true
  return true
end

return M
