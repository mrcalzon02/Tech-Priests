-- scripts/core/prototype_compat.lua
-- Tech Priests 0.1.440: Factorio 2.x runtime prototype access shim.
-- Factorio 2.x moved prototype dictionaries from LuaGameScript::*_prototypes
-- to the global LuaPrototypes object (`prototypes.entity`, `prototypes.item`,
-- `prototypes.recipe`, etc.).  Directly touching missing LuaGameScript keys can
-- raise, so all legacy runtime code should use these helpers instead.

local Compat = {}
Compat.version = "0.1.440"

local legacy_names = {
  item = "item_prototypes",
  entity = "entity_prototypes",
  recipe = "recipe_prototypes",
  fluid = "fluid_prototypes",
  technology = "technology_prototypes"
}

local empty = {}

function Compat.table(kind)
  if not kind then return empty end
  local p = rawget(_G, "prototypes")
  if p then
    local ok, t = pcall(function() return p[kind] end)
    if ok and t then return t end
  end
  local g = rawget(_G, "game")
  local legacy = legacy_names[kind]
  if g and legacy then
    local ok, t = pcall(function() return g[legacy] end)
    if ok and t then return t end
  end
  return empty
end

function Compat.get(kind, name)
  if not (kind and name) then return nil end
  local t = Compat.table(kind)
  local ok, proto = pcall(function() return t[name] end)
  if ok then return proto end
  return nil
end

function Compat.exists(kind, name)
  return Compat.get(kind, name) ~= nil
end

function Compat.item(name) return Compat.get("item", name) end
function Compat.entity(name) return Compat.get("entity", name) end
function Compat.recipe(name) return Compat.get("recipe", name) end
function Compat.fluid(name) return Compat.get("fluid", name) end
function Compat.technology(name) return Compat.get("technology", name) end

function Compat.install_globals()
  _G.TechPriestsPrototypeCompat = Compat
  _G.tech_priests_prototype_table_0440 = function(kind) return Compat.table(kind) end
  _G.tech_priests_get_prototype_0440 = function(kind, name) return Compat.get(kind, name) end
  _G.tech_priests_prototype_exists_0440 = function(kind, name) return Compat.exists(kind, name) end
  _G.tech_priests_get_item_prototype_0440 = function(name) return Compat.item(name) end
  _G.tech_priests_get_entity_prototype_0440 = function(name) return Compat.entity(name) end
  _G.tech_priests_get_recipe_prototype_0440 = function(name) return Compat.recipe(name) end
  _G.tech_priests_get_fluid_prototype_0440 = function(name) return Compat.fluid(name) end
  _G.tech_priests_get_technology_prototype_0440 = function(name) return Compat.technology(name) end
  return Compat
end

Compat.install_globals()
return Compat
