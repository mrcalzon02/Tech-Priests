-- Exact native prototype field transition: 2.0 => singular, 2.1 => plural.
local assign = dofile("tech-priests_src/prototypes/compatibility/native_fuel_categories_1272.lua")
for _, version in ipairs({"2.0.77", "2.0.0"}) do
  local item = assign({}, "entropic-extractor-blackstone", version)
  assert(item.fuel_category == "entropic-extractor-blackstone"
    and item.fuel_categories == nil, "2.0 fuel category regressed")
end
for _, version in ipairs({"2.1.24", "2.1.0", "2.2.0"}) do
  local item = assign({}, "entropic-extractor-blackstone", version)
  assert(item.fuel_category == nil and type(item.fuel_categories) == "table"
    and #item.fuel_categories == 1
    and item.fuel_categories[1] == "entropic-extractor-blackstone",
    "2.1+ native fuel schema was not selected")
end
local ok = pcall(assign, {}, "entropic-extractor-blackstone", "unknown")
assert(not ok, "unknown Factorio version must fail closed")
print("[fuel-categories-2.1-1272] PASS 2.0 singular/2.1 plural, invalid schema denied")
