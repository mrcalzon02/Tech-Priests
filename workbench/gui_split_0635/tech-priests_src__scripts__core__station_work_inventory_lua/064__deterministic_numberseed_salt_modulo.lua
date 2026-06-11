-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 809-818
local function deterministic_number(seed, salt, modulo)
  local text = tostring(seed or "0") .. ":" .. tostring(salt or "")
  local n = 0
  for i = 1, #text do
    n = (n * 33 + string.byte(text, i)) % 2147483647
  end
  if modulo and modulo > 0 then return (n % modulo) + 1 end
  return n
end

