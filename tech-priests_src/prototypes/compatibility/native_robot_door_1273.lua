-- Factorio 2.0 vs 2.1 LogisticContainerPrototype robot door schema.
-- The hidden chests must remain real logistic containers, visually invisible,
-- and preserve native robot delivery. No simulated network coverage.
return function(cache, invisible_animation, base_version)
  assert(type(cache) == "table", "expected real cache prototype")
  assert(type(invisible_animation) == "table", "expected invisible door animation")
  local major, minor = tostring(base_version or ""):match("^(%d+)%.(%d+)")
  assert(major and minor, "cannot choose a robot door schema for unknown base version")
  major, minor = tonumber(major), tonumber(minor)
  if major > 2 or (major == 2 and minor >= 1) then
    cache.animation = nil
    cache.landing_location_offset = nil
    cache.opened_duration = nil
    cache.animation_sound = nil
    cache.robot_door = {
      animation = table.deepcopy(invisible_animation),
      landing_location_offset = {0, 0},
      opened_duration = 0
    }
  else
    cache.robot_door = nil
    cache.animation = nil
    cache.landing_location_offset = {0, 0}
    cache.opened_duration = 0
    cache.animation_sound = nil
  end
  return cache
end
