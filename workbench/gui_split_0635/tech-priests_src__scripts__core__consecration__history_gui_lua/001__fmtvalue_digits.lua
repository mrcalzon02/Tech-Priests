-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 16-21
local function fmt(value, digits)
  value = tonumber(value)
  if not value then return "n/a" end
  return string.format("%." .. tostring(digits or 1) .. "f", value)
end

