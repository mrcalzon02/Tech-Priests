-- Immutable prototype memberships built incrementally by the force planner.
-- Availability, quantities, force research and world entities remain live.
local Q = require("scripts.core.force_planning_queue")
local M = {}
local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests.planning_metadata_1507
  if not r then r = { recipes = {}, epoch = 1 }; storage.tech_priests.planning_metadata_1507 = r end
  return r
end
-- Recreate native LuaCustomTable iterators; never save a function/coroutine.
function M.next_entry(map, key)
  if not map then return nil end
  local iterator, owner = pairs(map)
  return iterator(owner, key)
end
local function add(index, item, recipe)
  if type(item) ~= "string" then return end
  local list = index[item]
  if not list then list = {}; index[item] = list end
  list[#list + 1] = recipe
end
Q.register("planning-items", function(job)
  local s, r = job.state, root()
  if job.payload.epoch ~= r.epoch then return {done=true,processed=1} end
  s.index = s.index or {}
  local name, item = M.next_entry(prototypes and prototypes.item or {}, s.key)
  if not name then r.items = s.index; return {done=true,processed=1} end
  s.key = name
  local result = item.place_result
  if result and result.name and not s.index[result.name] then s.index[result.name] = name end
  return {processed=1}
end)
Q.register("planning-recipes", function(job)
  local s, r, force = job.state, root(), job.payload.force
  if job.payload.epoch ~= r.epoch or not (force and force.valid) then return {done=true,processed=1} end
  s.index = s.index or {force=force,products={},with_main_product={}}
  if not s.name then
    local name, recipe = M.next_entry(force.recipes or {}, s.key)
    if not name then r.recipes[force.index] = s.index; return {done=true,processed=1} end
    s.key, s.name, s.product, s.seen = name, name, 1, {}
    -- Native property access materializes one recipe's product array. Each
    -- returned row is subsequently charged, including duplicate products.
    s.products = recipe.products or {}
  elseif s.products[s.product] then
    local p = s.products[s.product]
    local name = p.name or p[1]
    if name and not s.seen[name] then
      s.seen[name] = true
      add(s.index.products, name, s.name)
      add(s.index.with_main_product, name, s.name)
    end
    s.product = s.product + 1
  else
    local recipe = force.recipes[s.name]
    if recipe and recipe.object_name ~= "LuaRecipe" then
      local main = recipe.main_product
      local name = type(main) == "string" and main or main and main.name
      if name and not s.seen[name] then add(s.index.with_main_product, name, s.name) end
    end
    s.name, s.products, s.seen = nil, nil, nil
  end
  return {processed=1}
end)
function M.item_index()
  local r = root()
  if not r.items then
    Q.submit_dependency(0,"planning-items",tostring(r.epoch),{epoch=r.epoch})
  end
  return r.items
end
function M.ready(force)
  if not (force and force.valid) then return false end
  M.item_index()
  local r = root()
  local names = r.recipes[force.index]
  if not (names and names.force == force) then
    Q.submit_dependency(force.index,"planning-recipes",tostring(r.epoch),{force=force,epoch=r.epoch})
  end
  return r.items ~= nil and names ~= nil and names.force == force
end
function M.indices(force)
  if not M.ready(force) then return nil end
  local r = root()
  return r.items, r.recipes[force.index]
end
function M.item_for_entity(name) local r = root(); return r.items and r.items[name] end
function M.epoch()return root().epoch end
function M.recipe_names(force, item, products_only)
  if not M.ready(force) then return nil end
  local index = root().recipes[force.index]
  return (products_only and index.products or index.with_main_product)[item] or {}
end
function M.reset()
  local r = root()
  r.items, r.recipes, r.epoch = nil, {}, r.epoch + 1
end
function M.install()
  Q.install()
  local registry = rawget(_G,"TechPriestsRuntimeEventRegistry")
    or require("scripts.core.runtime_event_registry")
  if registry.on_configuration_changed then
    registry.on_configuration_changed(M.reset,{owner="planning_metadata_1507",route="invalidate-prototypes"})
  end
  return true
end
return M
