-- Tech Priests common entity helpers.
-- 0.1.421: shared utility module introduced during control.lua cleanup.

local M = {}

function M.valid(entity)
  return entity ~= nil and entity.valid
end

function M.unit_number(entity)
  if entity and entity.valid then return entity.unit_number end
  return nil
end

function M.position(entity_or_position)
  if not entity_or_position then return nil end
  if entity_or_position.valid and entity_or_position.position then return entity_or_position.position end
  if entity_or_position.x and entity_or_position.y then return entity_or_position end
  return nil
end

function M.entity_label(entity)
  if not (entity and entity.valid) then return "<invalid>" end
  return tostring(entity.name or "entity") .. "#" .. tostring(entity.unit_number or "?")
end

function M.safe_destroy(object)
  if object and object.valid then
    pcall(function() object.destroy() end)
  end
end

return M
