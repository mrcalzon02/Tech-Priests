-- The base game uses an absolute tick on the individual pellet. With native
-- spoilage enabled Factorio owns the deadline, including time spent on belts.
local Clock = {native = script.feature_flags.spoiling}
local function tags_of(stack)
  return stack.is_item_with_tags and stack.tags or {}
end

function Clock.deadline(stack)
  if Clock.native then return stack.spoil_tick end
  return tags_of(stack).mh7_spoil_tick or 0
end

function Clock.set_deadline(stack, tick)
  if Clock.native then
    stack.spoil_tick = tick
  else
    local tags = tags_of(stack)
    tags.mh7_spoil_tick = tick
    stack.tags = tags
  end
end

return Clock
