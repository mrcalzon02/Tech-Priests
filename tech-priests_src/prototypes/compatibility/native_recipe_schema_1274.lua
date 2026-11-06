-- Factorio 2.1 removed recipe category/additional_categories and renamed
-- item/fluid product probability to independent_probability. Preserve 2.0.
local function version_21(base_version)
  local major, minor = tostring(base_version or ""):match("^(%d+)%.(%d+)")
  assert(major and minor, "missing Factorio base version for native recipe schema")
  return tonumber(major) > 2 or (tonumber(major) == 2 and tonumber(minor) >= 1)
end

local function product_probability(product)
  if type(product) ~= "table" or product.probability == nil then return 0 end
  if product.independent_probability ~= nil
      and product.independent_probability ~= product.probability then
    error("conflicting native independent_probability on recipe product "
      .. tostring(product.name))
  end
  product.independent_probability = product.probability
  product.probability = nil
  return 1
end

local function normalize_recipe(recipe)
  if type(recipe) ~= "table" then return 0, 0 end
  local categories = {}
  local seen = {}
  local function add_category(category)
    if type(category) == "string" and category ~= "" and not seen[category] then
      categories[#categories + 1] = category
      seen[category] = true
    end
  end
  for _, category in ipairs(recipe.categories or {}) do add_category(category) end
  add_category(recipe.category)
  if type(recipe.additional_categories) == "table" then
    for _, category in ipairs(recipe.additional_categories) do add_category(category) end
  else
    add_category(recipe.additional_categories)
  end
  local count = 0
  if #categories > 0 and (recipe.category ~= nil or recipe.additional_categories ~= nil) then
    recipe.categories = categories
    count = 1
  end
  recipe.category = nil
  recipe.additional_categories = nil
  -- These 2.0 visual switches no longer exist on 2.1 recipes.
  recipe.always_show_products = nil
  recipe.show_amount_in_title = nil
  local migrated = 0
  for _, product in ipairs(recipe.results or {}) do
    migrated = migrated + product_probability(product)
  end
  return count, migrated
end

return function(recipes, base_version)
  assert(type(recipes) == "table", "expected Factorio data.raw.recipe")
  if not version_21(base_version) then return 0, 0 end
  local categories, products = 0, 0
  for _, recipe in pairs(recipes) do
    local c, p = normalize_recipe(recipe)
    categories, products = categories + c, products + p
  end
  return categories, products
end
