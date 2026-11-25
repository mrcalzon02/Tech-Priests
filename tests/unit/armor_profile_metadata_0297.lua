-- The measured 811-tick owner must reuse immutable metadata while recipe
-- enablement, force identity, force-local profiles and event effects stay live.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
local file = assert(io.open("tech-priests_src/scripts/generated/control_legacy_part_019.lua", "r"))
local source = file:read("*a"); file:close()
assert(loadfile("tech-priests_src/scripts/generated/control_legacy_part_019.lua"),
  "the complete generated fragment no longer compiles")
local first = assert(source:find("TECH_PRIESTS_ARMOR_PROFILE_VERSION_0297 =", 1, true))
local last = assert(source:find("-- 0.1.299 Tech-Priest Re-Imprinting", first, true))
local owner_source = source:sub(first, last - 1)

local counts = {items = 0, types = 0, resistances = 0, recipes = 0, unrelated_products = 0}
local item_order, items = {}, {}
local function item(name, kind, decrease, percent, fail_once)
  local remaining_failure = fail_once
  items[name] = setmetatable({}, {__index = function(_, key)
    if key == "type" then counts.types = counts.types + 1; return kind end
    if key == "resistances" then
      counts.resistances = counts.resistances + 1
      if remaining_failure then remaining_failure = false; error("temporary armor metadata failure") end
      return {{type = "physical", decrease = decrease, percent = percent}}
    end
  end})
  item_order[#item_order + 1] = name
end
for index = 1, 2000 do item("ordinary-" .. index, "item") end
item("light-armor", "armor", 1, 10)
item("mod-armor-z", "armor", 2, 20)
item("mod-armor-a", "armor", 2, 20) -- native order wins a tie, not lexical order
item("super-armor", "armor", 5, 40)
item("alias-armor", "armor", 8, 50)
setmetatable(items, {__pairs = function()
  counts.items = counts.items + 1
  local index = 0
  return function()
    index = index + 1
    local name = item_order[index]
    if name then return name, items[name] end
  end
end})

local function force(index, name, z_enabled, a_enabled)
  local names, recipes, settings = {}, {}, {}
  local function add(recipe_name, products, enabled, unrelated)
    local state = {enabled = enabled}
    settings[recipe_name] = state
    recipes[recipe_name] = setmetatable({}, {__index = function(_, key)
      if key == "object_name" then return "LuaRecipe" end
      if key == "name" then return recipe_name end
      if key == "enabled" then return state.enabled end
      if key == "products" then
        if unrelated then counts.unrelated_products = counts.unrelated_products + 1 end
        return products
      end
      if key == "main_product" then error("LuaRecipe has no main_product") end
    end})
    names[#names + 1] = recipe_name
  end
  add("assemble-z", {{name = "byproduct"}, {name = "mod-armor-z"}}, z_enabled)
  add("assemble-a", {{name = "mod-armor-a"}}, a_enabled)
  add("super-armor", {{name = "super-armor"}}, false)
  -- The legacy direct-name shortcut accepts an enabled same-name recipe
  -- even when its product list differs. Keep that public helper contract.
  add("alias-armor", {{name = "different-product"}}, false)
  for n = 1, 1000 do add("unrelated-" .. n, {{name = "product-" .. n}}, n % 2 == 0, true) end
  setmetatable(recipes, {__pairs = function()
    counts.recipes = counts.recipes + 1
    local cursor = 0
    return function()
      cursor = cursor + 1
      local recipe_name = names[cursor]
      if recipe_name then return recipe_name, recipes[recipe_name] end
    end
  end})
  return {valid = true, index = index, name = name, recipes = recipes}, settings
end

local alpha, alpha_recipes = force(1, "alpha", true, true)
local beta, beta_recipes = force(2, "beta", false, true)
local side_effects = {built = 0, radius = 0, mobility = 0, logistics = 0, sanctification = 0}
local function load_owner(item_prototypes, forces, reset_policy)
  if reset_policy then package.loaded["scripts.core.planning_constraints_0646"] = nil end
  local routes, ticks = {}, {}
  local env = setmetatable({
    prototypes = {item = item_prototypes}, storage = {tech_priests = {pairs_by_station = {}}},
    game = {tick = 811, forces = forces, players = setmetatable({}, {
      __pairs = function() error("force armor selection must not inspect or consume player armor") end,
    })}, script = {},
    defines = {events = {on_built_entity = 1, on_robot_built_entity = 2,
      script_raised_built = 3, script_raised_revive = 4, on_research_finished = 5,
      on_technology_effects_reset = 6, on_entity_damaged = 7}},
    on_built = function() side_effects.built = side_effects.built + 1 end,
    log = function() end,
  }, {__index = _G})
  env._G = env
  env.ensure_storage = function() return env.storage end
  env.TechPriestsRuntimeEventRegistry = {
    on_event = function(events, fn)
      if type(events) ~= "table" then events = {events} end
      for _, event in ipairs(events) do routes[event] = fn end
      return true
    end,
    on_nth_tick = function(interval, fn, options)
      ticks[interval] = {fn = fn, options = options}; return true
    end,
  }
  assert(load(owner_source, "@armor-owner-0297", "t", env))()
  return env, routes, ticks
end

local env, routes, ticks = load_owner(items, {alpha = alpha, beta = beta}, true)
assert(ticks[811] and not ticks[810], "the existing armor refresh cadence changed")
ticks[811].fn()
local profiles = env.storage.tech_priests.armor_profiles_0297
assert(profiles.alpha.name == "mod-armor-z" and profiles.beta.name == "mod-armor-a",
  "alternate armor recipes, force isolation or original tie order changed")
assert(counts.items == 1 and counts.recipes == 2,
  "armor refresh repeated whole metadata walks: items=" .. counts.items .. " recipes=" .. counts.recipes)
local initial_types, initial_resistances, initial_products =
  counts.types, counts.resistances, counts.unrelated_products
for iteration = 1, 100 do
  env.game.tick = 811 * (iteration + 1)
  ticks[811].fn()
end
assert(counts.items == 1 and counts.recipes == 2 and counts.types == initial_types
  and counts.resistances == initial_resistances and counts.unrelated_products == initial_products,
  "warm 811 refresh re-enumerated prototypes or unrelated recipe products")
assert(profiles.alpha.tick == env.game.tick and profiles.alpha.reason == "periodic",
  "metadata reuse suppressed the existing profile refresh")
assert(ticks[811].options and ticks[811].options.owner == "armor_profile_0297"
  and ticks[811].options.route == "force-armor-refresh"
  and ticks[811].options.category == "uncategorized",
  "811 route identity is missing or its existing scheduling category changed")

-- All toggles occur without advancing the tick: only immutable membership
-- is retained, never a Boolean answer about currently unlocked armor.
alpha_recipes["assemble-z"].enabled = false
assert(env.tech_priests_0297_refresh_force_armor_profile(alpha).name == "mod-armor-a")
alpha_recipes["assemble-a"].enabled = false
assert(env.tech_priests_0297_refresh_force_armor_profile(alpha).name == "light-armor",
  "starting light-armor floor or live disabling changed")
alpha_recipes["super-armor"].enabled = true
assert(env.tech_priests_0297_refresh_force_armor_profile(alpha).name == "super-armor")
alpha_recipes["alias-armor"].enabled = true
assert(env.tech_priests_0297_refresh_force_armor_profile(alpha).name == "alias-armor",
  "direct-name recipe compatibility changed")
alpha_recipes["alias-armor"].enabled = false
alpha_recipes["super-armor"].enabled = false
alpha_recipes["assemble-z"].enabled = true
local isolated = env.tech_priests_0297_refresh_force_armor_profile(alpha)
isolated.resistances.physical.decrease = 999
local fresh = env.tech_priests_0297_refresh_force_armor_profile(alpha)
assert(fresh.resistances.physical.decrease == 2
  and profiles.beta.resistances.physical.decrease == 2
  and fresh.resistances ~= profiles.beta.resistances,
  "published force profiles aliased private metadata or another force")

local priest = {valid = true, name = "test-priest", unit_number = 10, force = alpha,
  health = 50, prototype = {max_health = 100}}
local pair = {priest = priest, station = {valid = true, force = alpha}}
env.storage.tech_priests.pairs_by_station[1] = pair
env.storage.tech_priests.pairs_by_station[2] = {priest = {valid = true, force = beta},
  station = {valid = true, force = beta}}
env.is_priest = function(entity) return entity == priest end
env.find_pair_for_entity = function(entity) if entity == priest then return pair end end
routes[7]({entity = priest, final_damage_amount = 20, damage_type = {name = "physical"}})
assert(math.abs(priest.health - 55.6) < 0.00001
  and pair.last_armor_mitigation_0297.armor == "mod-armor-z",
  "the existing resistance mitigation or pair receipt changed")
routes[1]({entity = priest})
assert(side_effects.built == 1 and pair.sub_equipment_armor_profile_0297.name == "mod-armor-z",
  "build-wrapper delegation or pair armor annotation changed")

env.RANGE_TECH_BONUSES = {["armor-research"] = 5}
env.TECH_PRIEST_BELT_IMMUNITY_TECH = "armor-research"
env.COGITATOR_LOGISTIC_REQUISITION_TECH = "armor-research"
env.MAX_SANCTIFICATION_TECH_BONUSES = {["armor-research"] = 5}
env.refresh_pair_radius = function(changed) assert(changed == pair); side_effects.radius = side_effects.radius + 1 end
env.upgrade_force_priests_to_current_mobility = function(changed) assert(changed == alpha); side_effects.mobility = side_effects.mobility + 1 end
env.ensure_pair_logistic_caches = function(changed) assert(changed == pair); side_effects.logistics = side_effects.logistics + 1 end
env.is_sanctification_baseline_technology = function(name) return name == "armor-research" end
env.get_base_sanctification_max = function(changed) assert(changed == alpha); return 20 end
env.apply_sanctification_research_to_existing_machines = function(changed, before, after)
  assert(changed == alpha and before == 15 and after == 20)
  side_effects.sanctification = side_effects.sanctification + 1
end
alpha_recipes["super-armor"].enabled = true
routes[5]({research = {force = alpha, name = "armor-research"}})
assert(profiles.alpha.name == "super-armor" and pair.sub_equipment_armor_profile_0297.name == "super-armor"
  and side_effects.radius == 1 and side_effects.mobility == 1
  and side_effects.logistics == 1 and side_effects.sanctification == 1
  and env.storage.tech_priests.last_researched_technology_by_force.alpha == "armor-research",
  "research refresh or preserved legacy research effects changed")
alpha_recipes["super-armor"].enabled = false
routes[6]({force = alpha})
assert(profiles.alpha.name == "mod-armor-z" and profiles.alpha.reason == "technology-effects-reset",
  "technology-effects reset retained an obsolete armor answer")

alpha.name = "renamed-alpha"
assert(env.tech_priests_0297_refresh_force_armor_profile(alpha).force == "renamed-alpha"
  and counts.recipes == 2, "force rename invalidated immutable recipe membership")
alpha.valid = false
local replacement, replacement_recipes = force(1, "replacement", false, false)
replacement_recipes["super-armor"].enabled = true
assert(env.tech_priests_0297_refresh_force_armor_profile(replacement).name == "super-armor"
  and counts.recipes == 3, "a replacement force inherited the removed force's recipes")
assert(env.tech_priests_0297_refresh_force_armor_profile(alpha) == nil,
  "invalid force produced an armor profile")

-- Runtime reload discards immutable local metadata. A transient resistance
-- read failure must also remain retryable instead of freezing a partial list.
local before_reload = counts.items
local reloaded = load_owner(items, {replacement = replacement}, true)
assert(reloaded.tech_priests_0297_refresh_force_armor_profile(replacement).name == "super-armor"
  and counts.items == before_reload + 1, "runtime reload retained obsolete prototype facts")
local temporary = true
local recovery_proto = setmetatable({}, {__index = function(_, key)
  if key == "type" then return "armor" end
  if key == "resistances" then
    if temporary then temporary = false; error("temporary resistance fault") end
    return {{type = "physical", decrease = 3, percent = 30}}
  end
end})
local recovering = load_owner({["light-armor"] = recovery_proto}, {beta = beta}, false)
assert(recovering.tech_priests_0297_refresh_force_armor_profile(beta) == nil)
assert(recovering.tech_priests_0297_refresh_force_armor_profile(beta).name == "light-armor",
  "failed prototype metadata was permanently cached as no armor")
local compatible = load_owner(items, {beta = beta}, false)
compatible.require = function() error("shared recipe metadata unavailable") end
assert(compatible.tech_priests_0297_force_can_use_armor(beta, "mod-armor-a"),
  "unavailable shared metadata removed the legacy alternate-recipe fallback")
print("[armor-profile-metadata-0297] PASS: one item walk; one recipe walk per force;100 periodic refreshes; live unlocks; isolation; effects; damage; force replacement and reload")
