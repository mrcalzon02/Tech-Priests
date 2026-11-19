-- Canonical deterministic identity for objects omitted from unit_number.
-- Never use object addresses or coarse tile rounding for resource ownership.
local M = {}
local function numeric(v)
  -- MapPosition is stored as a signed fixed-point integer (8 fractional bits).
  -- Convert back to its exact engine coordinate instead of formatting floats.
  return tostring(math.floor((tonumber(v) or 0) * 256 + 0.5))
end
function M.key(entity)
  if not (entity and entity.valid) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or {}
  local surface = entity.surface
  local force = entity.force
  local surface_id = surface and (surface.index or surface.name) or "?"
  local force_id = force and (force.index or force.name) or "?"
  local name = tostring(entity.name or entity.type or "?")
  local kind = tostring(entity.type or "?")
  return "p:" .. tostring(surface_id) .. ":" .. tostring(force_id)
    .. ":" .. tostring(#name) .. ":" .. name
    .. ":" .. tostring(#kind) .. ":" .. kind
    .. ":" .. numeric(p.x or p[1]) .. ":" .. numeric(p.y or p[2])
end
return M
