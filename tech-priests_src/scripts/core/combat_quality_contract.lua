-- Exact AAI combat-actor Quality identity audit. Read-only, no item changes.
local M = {}

function M.entity_quality_name(entity)
  if not (entity and entity.valid) then return nil end
  local ok, result = pcall(function()
    local quality = entity.quality
    return quality and quality.name or "normal"
  end)
  return ok and type(result) == "string" and result or nil
end

function M.replacement_identity(old_entity, new_entity)
  local old_quality = M.entity_quality_name(old_entity)
  local new_quality = M.entity_quality_name(new_entity)
  if not (old_quality and new_quality) then return nil end
  return {
    before_quality = old_quality,
    after_quality = new_quality,
    equal = old_quality == new_quality,
    old_unit = old_entity.unit_number,
    new_unit = new_entity.unit_number
  }
end

-- Called once from the existing AAI replacement callback, never on tick.
-- Important: changing LuaEntity.quality is not supported by Factorio; do not
-- claim to fix an AAI replacement by minting a different-quality entity.
function M.audit_replacement(storage_root, old_entity, new_entity, tick, reporter)
  local result = M.replacement_identity(old_entity, new_entity)
  if not result or result.equal then return result end
  local state = storage_root.combat_quality_audit or {mismatches = 0}
  state.mismatches = (state.mismatches or 0) + 1
  state.last = {
    before_quality = result.before_quality,
    after_quality = result.after_quality,
    old_unit = result.old_unit,
    new_unit = result.new_unit,
    tick = tick or 0
  }
  storage_root.combat_quality_audit = state
  if reporter and (state.mismatches <= 5 or state.mismatches % 100 == 0) then
    reporter("[Tech-Priests][AAI_QUALITY_MISMATCH] source=" ..
      tostring(result.before_quality) .. " replacement=" ..
      tostring(result.after_quality) .. " source_unit=" ..
      tostring(result.old_unit) .. " new_unit=" ..
      tostring(result.new_unit) .. " count=" .. tostring(state.mismatches))
  end
  return result
end

return M
