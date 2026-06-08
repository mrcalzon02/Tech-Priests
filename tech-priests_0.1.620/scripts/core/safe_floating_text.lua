-- scripts/core/safe_floating_text.lua
-- Tech Priests 0.1.448 runtime-safe floating text bridge.
-- Factorio 2.x no longer guarantees an entity prototype named "flying-text".
-- Use rendering.draw_text first and keep the legacy entity path behind pcall only.

local M = { version = "0.1.448" }

local function valid_surface(surface)
  return surface ~= nil
end

local function normalize_position(position)
  if not position then return nil end
  if position.x and position.y then return { x = position.x, y = position.y } end
  if position[1] and position[2] then return { x = position[1], y = position[2] } end
  return nil
end

function M.draw(surface, position, text, color, opts)
  opts = opts or {}
  local pos = normalize_position(position)
  if not (valid_surface(surface) and pos and text) then return false end
  color = color or { r = 1, g = 0.85, b = 0.25, a = 1 }
  local ttl = tonumber(opts.time_to_live or opts.ttl) or 90
  local scale = tonumber(opts.scale) or 0.78
  if rendering and rendering.draw_text then
    local ok, obj = pcall(function()
      return rendering.draw_text({
        surface = surface,
        target = pos,
        text = tostring(text),
        color = color,
        alignment = opts.alignment or "center",
        scale = scale,
        time_to_live = ttl,
        forces = opts.forces,
        players = opts.players,
        use_rich_text = opts.use_rich_text ~= false
      })
    end)
    if ok and obj then return true, obj end
  end
  -- Last-resort 1.x/legacy path.  Unknown prototype errors stay contained.
  if surface.create_entity then
    local ok = pcall(function()
      surface.create_entity({ name = "flying-text", position = pos, text = tostring(text), color = color })
    end)
    if ok then return true end
  end
  return false
end

function M.install()
  _G.tech_priests_safe_floating_text_0448 = M.draw
  return true
end

return M
