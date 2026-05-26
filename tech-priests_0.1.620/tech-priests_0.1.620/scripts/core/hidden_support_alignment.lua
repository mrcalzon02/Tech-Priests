-- Tech Priests — hidden support entity alignment authority.
-- 0.1.430: owns non-priest invisible/support entity alignment such as hidden
-- logistic caches and hidden electric loads following their visible anchors.
-- These are not movement-controller responsibilities because no visible priest
-- unit is being moved.

local HiddenSupportAlignment = {}

local function now()
  return (game and game.tick) or 0
end

local function valid_entity(entity)
  return entity and entity.valid
end

function HiddenSupportAlignment.align(hidden, anchor, reason, record)
  if not (valid_entity(hidden) and valid_entity(anchor)) then return false end
  if hidden.surface ~= anchor.surface then return false end
  local ok, moved = pcall(function() return hidden.teleport(anchor.position) end)
  if ok and moved ~= false then
    if record then
      record.last_hidden_support_alignment_0430 = {
        tick = now(),
        reason = reason or "hidden support alignment",
        hidden = hidden.name,
        anchor = anchor.name,
        hidden_unit = hidden.unit_number,
        anchor_unit = anchor.unit_number
      }
    end
    return true
  end
  if record then
    record.last_hidden_support_alignment_0430 = {
      tick = now(),
      reason = reason or "hidden support alignment failed",
      failed = true,
      hidden = hidden.name,
      anchor = anchor.name,
      hidden_unit = hidden.unit_number,
      anchor_unit = anchor.unit_number
    }
  end
  return false
end

function HiddenSupportAlignment.install()
  _G.tech_priests_align_hidden_support_0430 = function(hidden, anchor, reason, record)
    return HiddenSupportAlignment.align(hidden, anchor, reason, record)
  end
end

return HiddenSupportAlignment
