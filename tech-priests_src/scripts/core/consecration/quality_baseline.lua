-- Machine Spirit quality baseline. Pure calculations, no event handlers or stored state.
-- Quality fills a percentage of the headroom between the force's researched
-- starting sanctity and researched maximum. Normal uses the existing start;
-- legendary starts at the existing maximum. Maximum capacity is unchanged.
local M = {}

local FRACTIONS = {
  normal = 0.0,
  uncommon = 0.2,
  rare = 0.4,
  epic = 0.7,
  legendary = 1.0
}

function M.entity_quality_name(entity)
  local ok, name = pcall(function()
    if not (entity and entity.valid) then return nil end
    local quality = entity.quality
    return quality and quality.name or nil
  end)
  if ok and type(name) == "string" and FRACTIONS[name] ~= nil then
    return name
  end
  -- No Quality mod, no prototype, or an unrecognized custom quality:
  -- never grant an invented bonus.
  return "normal"
end

function M.starting_sanctification(base_start, base_max, quality_name)
  local maximum = math.max(1, tonumber(base_max) or 100)
  local starting = math.max(0, math.min(maximum, tonumber(base_start) or 50))
  local fraction = FRACTIONS[quality_name] or 0
  return math.max(0, math.min(maximum, starting + (maximum - starting) * fraction))
end

return M
