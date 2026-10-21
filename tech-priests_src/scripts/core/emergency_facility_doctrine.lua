-- scripts/core/emergency_facility_doctrine.lua
-- Tech Priests 0.1.343 Martian emergency facility doctrine with micro-smelter.
--
-- This module lets scavenge/acquisition mode reuse emergency equipment placed
-- and tagged by its own Cogitator Station. If no suitable owned equipment is
-- available, it asks the construction planner to place the necessary Martian
-- emergency hardware. It deliberately starts with conservative equipment use:
-- miners, atmospheric condenser, boiler, steam engine, emergency assembler,
-- emergency power grid, and laboratorium are tagged and tracked; recipes and
-- inventories are nudged only when the target entity exposes safe Factorio API
-- calls.

local M = {}
M.version = "0.1.348"
M.storage_key = "emergency_facility_doctrine_0343"
M.service_period = 11
M.max_per_pulse = 12
M.station_close_distance_sq = 9.0
M.default_radius = 36

local EMERGENCY_ENTITIES = {
  ["tech-priests-emergency-miner"] = { role = "miner", item = "tech-priests-emergency-miner" },
  ["tech-priests-atmospheric-water-condenser"] = { role = "condenser", item = "tech-priests-atmospheric-water-condenser" },
  ["tech-priests-emergency-boiler"] = { role = "boiler", item = "tech-priests-emergency-boiler" },
  ["tech-priests-emergency-steam-engine"] = { role = "steam-engine", item = "tech-priests-emergency-steam-engine" },
  ["tech-priests-emergency-smelter"] = { role = "smelter", item = "tech-priests-emergency-smelter" },
  ["tech-priests-emergency-assembler"] = { role = "assembler", item = "tech-priests-emergency-assembler" },
  ["tech-priests-emergency-laboratorium"] = { role = "lab", item = "tech-priests-emergency-laboratorium" },
  ["tech-priests-emergency-power-grid"] = { role = "power-grid", item = "tech-priests-emergency-power-grid" },
}

local REQUIRED_CORE = {
  "tech-priests-emergency-miner",
  -- 0.1.343: the smelter is the first true industry unlock after crude
  -- mining, because plates should come from ore + fuel in a machine instead
  -- of hand/substitute crafting.
  "tech-priests-emergency-smelter",
  "tech-priests-atmospheric-water-condenser",
  "tech-priests-emergency-boiler",
  "tech-priests-emergency-steam-engine",
  "tech-priests-emergency-power-grid",
  "tech-priests-emergency-assembler",
}

local BASIC_FUELS = { "coal", "wood", "solid-fuel" }
local REQUEST_ITEMS = { "iron-ore", "copper-ore", "coal", "stone", "wood", "iron-plate", "copper-plate", "firearm-magazine" }


local function debug_chat_allowed_0626(root)
  if not (root and root.debug_chat) then return false end
  if _G and _G.tech_priests_runtime_debug_enabled_0626 then
    local ok, enabled = pcall(_G.tech_priests_runtime_debug_enabled_0626, "verbose")
    if ok then return enabled == true end
  end
  return root.debug_chat == true
end
local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function pairs_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function unit(pair) return pair and pair.station and pair.station.valid and pair.station.unit_number end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function role_of(e)
  if not valid(e) then return nil end
  local emergency=EMERGENCY_ENTITIES[e.name]
  if emergency then return emergency.role end
  -- A real, locally owned furnace is useful smelting equipment; it need not
  -- have the bespoke emergency-smelter entity name to feed ordinary ore.
  if e.type=="furnace" then return "smelter" end
  return nil
end
local function is_emergency_name(name) return EMERGENCY_ENTITIES[name] ~= nil end
local function item_for_entity(name) return EMERGENCY_ENTITIES[name] and EMERGENCY_ENTITIES[name].item or name end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    debug_chat = true,
    facilities = {},
    by_station = {},
    stats = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.facilities = root.facilities or {}
  root.by_station = root.by_station or {}
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function entity_key(entity)
  if _G.TECH_PRIESTS_STATION_CATALOG_0327 and _G.TECH_PRIESTS_STATION_CATALOG_0327.entity_key then
    local ok, key = pcall(_G.TECH_PRIESTS_STATION_CATALOG_0327.entity_key, entity)
    if ok and key then return key end
  end
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface) .. ":" .. tostring(entity.name or entity.type) .. ":" .. tostring(math.floor((p.x or 0) * 10)) .. ":" .. tostring(math.floor((p.y or 0) * 10))
end

local function radius_for(pair)
  if not valid_pair(pair) then return M.default_radius end
  if _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, tonumber(r)) end
  end
  return tonumber(pair.radius) or M.default_radius
end

local function draw(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    return _G.tech_priests_emit_overhead_status_0473(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, ttl or 90, 0.62, "emergency-facility-doctrine")
  end
  if _G.TECH_PRIESTS_WORK_VISUALS and _G.TECH_PRIESTS_WORK_VISUALS.show then pcall(_G.TECH_PRIESTS_WORK_VISUALS.show, pair, text, ttl or 90) end
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
end

local function print_msg(pair, text)
  local root = ensure_root(); if not debug_chat_allowed_0626(root) then return end
  if game and game.print then game.print(text) end
  if log then log(text) end
end

local function safe_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function inventory_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function insert_item(inv, item, count)
  if not (inv and inv.valid and item) then return 0 end
  local ok, inserted = pcall(function() return inv.insert({ name = item, count = count or 1 }) end)
  return ok and (tonumber(inserted) or 0) or 0
end

local function remove_item(inv, item, count)
  if not (inv and inv.valid and item) then return 0 end
  local ok, removed = pcall(function() return inv.remove({ name = item, count = count or 1 }) end)
  return ok and (tonumber(removed) or 0) or 0
end

local function inventories(entity)
  -- The Cogitator is also a machine: its recipe inputs, outputs and fuel
  -- are NOT general storage. Only the real chest inventory can supply or
  -- receive unrelated materials.
  local out = {}
  local ids = defines and defines.inventory
  local inv = ids and safe_inventory(entity, ids.chest)
  if inv then out[1] = { id = ids.chest, inv = inv, entity = entity } end
  return out
end

local function managed_sources(pair)
  local authority = rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  local sources
  if authority and type(authority.generic_storage_sources) == "function" then
    local ok, found = pcall(authority.generic_storage_sources, pair)
    if ok and type(found) == "table" then sources = found end
  end
  if not sources then return inventories(pair.station) end
  local out, seen = {}, {}
  for _, source in ipairs(sources) do
    local entity = source and source.entity
    local inv = source and source.inv
    if inv and inv.valid and entity and entity.valid and not seen[inv]
       and entity.surface == pair.station.surface
       and entity.force == pair.station.force then
      seen[inv] = true
      out[#out+1] = { inv = inv, entity = entity,
        -- Existing stone caches are the ordinary stock location; the
        -- Cogitator chest is an operational fallback.
        priority = entity == pair.station and 100
          or (tostring(entity.name or ""):find("stone%-cache") and 1 or 10) }
    end
  end
  table.sort(out, function(a,b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    local pa, pb = a.entity.position, b.entity.position
    local station = pair.station.position
    local da = pa and ((pa.x-station.x)^2+(pa.y-station.y)^2) or 0
    local db = pb and ((pb.x-station.x)^2+(pb.y-station.y)^2) or 0
    return da < db
  end)
  return out
end

local function source_inventory_for(pair, item)
  -- Use precisely the managed storage authority's general supply inventory.
  -- The stone caches, not machine source/result or fuel buffers, hold the
  -- stock the acquisition governor counts toward its production requests.
  if _G.tech_priests_inventory_steward_unload then
    pcall(_G.tech_priests_inventory_steward_unload, pair, "emergency-facility-source")
  end
  for _, slot in ipairs(managed_sources(pair)) do
    if inventory_count(slot.inv, item) > 0 then return slot.inv end
  end
  return nil
end

function M.tag_built_entity(pair, entity, reason)
  if not (valid_pair(pair) and valid(entity)) then return false end
  local r = radius_for(pair)
  if dist_sq(entity.position, pair.station.position) > r * r then return false end
  local root = ensure_root()
  local key = entity_key(entity); if not key then return false end
  local u = unit(pair); if not u then return false end
  local role = role_of(entity) or "built"
  root.facilities[key] = {
    key = key,
    station_unit = u,
    entity = entity,
    name = entity.name,
    role = role,
    reason = reason or "built",
    tick = now(),
  }
  root.by_station[u] = root.by_station[u] or {}
  root.by_station[u][key] = true
  pair.emergency_facility_keys_0339 = pair.emergency_facility_keys_0339 or {}
  pair.emergency_facility_keys_0339[key] = true
  if _G.TECH_PRIESTS_STATION_CATALOG_0327 and _G.TECH_PRIESTS_STATION_CATALOG_0327.claim_built_entity then
    pcall(_G.TECH_PRIESTS_STATION_CATALOG_0327.claim_built_entity, pair, entity, "built-facility")
  end
  root.stats.tagged = (root.stats.tagged or 0) + 1
  draw(pair, "tagged facility: " .. tostring(entity.name), 90)
  return true
end

local function forget_invalid(root)
  for key, rec in pairs(root.facilities or {}) do
    if not (rec.entity and rec.entity.valid) then
      local by = root.by_station[rec.station_unit]
      if by then by[key] = nil end
      root.facilities[key] = nil
    end
  end
end

local function scan_owned_emergency(pair)
  local root = ensure_root(); if not valid_pair(pair) then return {} end
  local u = unit(pair); local found = {}
  local r = radius_for(pair)
  local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r }) end)
  if not ok or not ents then return found end
  for _, e in pairs(ents) do
    if valid(e) and (is_emergency_name(e.name) or e.type=="furnace")
        and e.force==pair.station.force then
      local key = entity_key(e)
      local rec = key and root.facilities[key] or nil
      if rec and rec.station_unit == u then
        rec.entity = e
        if e.type=="furnace" then rec.role="smelter" end
        found[#found+1] = rec
      elseif not rec and dist_sq(e.position, pair.station.position) <= r*r then
        -- Shared-force standard furnaces may be near several Cogitators. Only
        -- the nearest live station may adopt an unclaimed machine. The durable
        -- by_station ledger prevents a second priest from feeding it later.
        local nearest=u
        local best=dist_sq(e.position,pair.station.position)
        for _, other in pairs(pairs_map()) do
          if other~=pair and valid_pair(other)
              and other.station.force==pair.station.force
              and other.station.surface==pair.station.surface then
            local distance=dist_sq(e.position,other.station.position)
            local candidate=unit(other)
            if distance<best or (distance==best and candidate and nearest and candidate<nearest) then
              nearest=candidate;best=distance
            end
          end
        end
        if nearest==u then
          M.tag_built_entity(pair,e,e.type=="furnace" and "local-standard-furnace" or "local-scan")
          if root.facilities[key] then found[#found+1]=root.facilities[key] end
        end
      end
    end
  end
  return found
end

local function recipe_exists(name)
  if not name then return false end
  if prototypes and prototypes.recipe then
    local ok, p = pcall(function() return prototypes.recipe[name] end)
    return ok and p ~= nil
  end
  return false
end

local function safe_suffix(item)
  return tostring(item or ""):gsub("[^%w%-_]", "-")
end

local function recipe_for(role, item)
  item = item or "iron-ore"
  if role == "miner" then
    local r = "tech-priests-emergency-mine-" .. safe_suffix(item)
    if recipe_exists(r) then return r end
    for _, alt in ipairs({ "iron-ore", "coal", "stone", "wood", "copper-ore" }) do
      r = "tech-priests-emergency-mine-" .. safe_suffix(alt)
      if recipe_exists(r) then return r end
    end
  elseif role == "smelter" then
    if item == "iron-plate" then return "tech-priests-emergency-smelt-iron-ore-to-iron-plate" end
    if item == "copper-plate" then return "tech-priests-emergency-smelt-copper-ore-to-copper-plate" end
    if item == "stone-brick" then return "tech-priests-emergency-smelt-stone-to-stone-brick" end
  elseif role == "assembler" then
    -- Factorio exposes smelting recipes globally, but the emergency workshop
    -- does not support that category. Routing plates here leaves no recipe
    -- selected and diverts scarce burner coal from the real furnace.
    if item=="iron-plate" or item=="copper-plate" or item=="stone-brick" then
      return nil
    end
    local prototype=prototypes and prototypes.recipe and prototypes.recipe[item]
    local category=prototype and prototype.category
    if category=="smelting" or category=="tech-priests-emergency-smelting" then
      return nil
    end
    if item == "repair-pack" and recipe_exists("tech-priests-emergency-repair-pack") then return "tech-priests-emergency-repair-pack" end
    if recipe_exists(item) then return item end
  elseif role == "condenser" then
    if recipe_exists("tech-priests-atmospheric-water-condensation") then return "tech-priests-atmospheric-water-condensation" end
    if recipe_exists("tech-priests-condense-water") then return "tech-priests-condense-water" end
  end
  return nil
end

local function record_recipe_selection(pair, entity, recipe, phase, detail)
  -- Primitive, saveable diagnostics only. This observes engine selection and
  -- ownership results without claiming another machine or changing recipes.
  if type(pair)=="table" then
    pair.emergency_facility_recipe_diagnostic_0357={
      tick=now(),machine=valid(entity) and entity.name or "invalid",
      recipe=tostring(recipe or "nil"),phase=tostring(phase),
      reason=tostring(detail or "none"),
    }
  end
end

local function set_recipe(entity, recipe, pair, reason)
  if not (valid(entity) and recipe and entity.set_recipe) then
    record_recipe_selection(pair,entity,recipe,"no-selector","missing entity, recipe or API")
    return false
  end
  -- Machine claim remains mandatory: this telemetry never bypasses it.
  if _G.tech_priests_0576_claim_machine_for_recipe then
    local ok_claim, allowed, why = pcall(_G.tech_priests_0576_claim_machine_for_recipe,
      pair,entity,recipe,reason or "emergency-facility-doctrine")
    if not ok_claim or allowed==false then
      record_recipe_selection(pair,entity,recipe,"claim-rejected",
        ok_claim and why or allowed)
      return false,ok_claim and why or allowed
    end
  end
  local current=nil
  pcall(function()
    local r=entity.get_recipe and entity.get_recipe()
    current=type(r)=="string" and r or (r and r.name)
  end)
  if current==recipe then
    record_recipe_selection(pair,entity,recipe,"already-selected","engine-confirmed")
    return true
  end
  local ok,result=pcall(function()return entity.set_recipe(recipe)end)
  if not ok or result==false then
    record_recipe_selection(pair,entity,recipe,"engine-rejected",
      ok and "set_recipe returned false" or result)
    return false
  end
  -- set_recipe may return successfully even when the real entity has not
  -- retained the requested recipe. Read back the engine-selected recipe
  -- before claiming work has started or consuming its ingredients/fuel.
  -- The compatibility path without get_recipe is only for standalone mocks;
  -- every real Factorio assembling-machine exposes this getter.
  if entity.get_recipe then
    local read_ok,selected=pcall(function()
      local r=entity.get_recipe()
      return type(r)=="string" and r or (r and r.name)
    end)
    if not read_ok or selected~=recipe then
      local proto=prototypes and prototypes.recipe and prototypes.recipe[recipe]
      record_recipe_selection(pair,entity,recipe,"engine-unconfirmed",
        "selected="..tostring(selected).." category="..
        tostring(proto and proto.category).." set_return="..tostring(result)..
        (not read_ok and " read-error" or ""))
      return false
    end
  end
  record_recipe_selection(pair,entity,recipe,"engine-confirmed",
    "selected after set_recipe")
  return true
end

-- Physical station feed: preflight, refund rejected items, and retain any
-- blocked refund as primitive saveable custody before another feed can begin.
local function restore_feed_custody(pair)
  local c = pair.emergency_facility_feed_custody_0357
  if c == nil then return true end
  if type(c) ~= "table" or type(c.item) ~= "string"
      or type(c.count) ~= "number" or c.count <= 0
      or c.count ~= math.floor(c.count) then return false end
  for _, slot in ipairs(managed_sources(pair)) do
    local n = math.max(0, math.min(c.count, insert_item(slot.inv, c.item, c.count)))
    c.count = c.count - n
    if c.count == 0 then
      pair.emergency_facility_feed_custody_0357 = nil
      return true
    end
  end
  c.last_retry_tick = now()
  return false
end

local function transfer_station_item(pair, target, item, desired)
  if pair.emergency_facility_feed_custody_0357
      or not (target and target.valid and target.can_insert) then return 0 end
  local src = source_inventory_for(pair, item)
  if not src then return 0 end
  local n = math.min(math.max(0, math.floor(tonumber(desired) or 0)), inventory_count(src, item))
  while n > 0 do
    local ok, fits = pcall(function() return target.can_insert({name=item, count=n}) end)
    if ok and fits == true then break end
    n = n - 1
  end
  if n == 0 then return 0 end
  local removed = remove_item(src, item, n)
  if removed <= 0 then return 0 end
  local inserted = math.max(0, math.min(removed, insert_item(target, item, removed)))
  local remaining = removed - inserted
  if remaining > 0 then
    remaining = remaining - math.max(0, math.min(remaining, insert_item(src, item, remaining)))
    if remaining > 0 then
      pair.emergency_facility_feed_custody_0357 = {
        item=item, count=remaining, created_tick=now(),
        reason="facility-feed-refund-blocked",
      }
    end
  end
  return inserted
end

local function feed_fuel_from_pair(pair, entity)
  local fuel = safe_inventory(entity, defines.inventory.fuel)
  if not fuel then return 0 end
  local inserted = 0
  for _, f in ipairs(BASIC_FUELS) do
    if inventory_count(fuel, f) < 2 then
      local moved = transfer_station_item(pair, fuel, f,
        2 - inventory_count(fuel, f))
      inserted = inserted + moved
      if moved > 0 then
        local stats = ensure_root().stats
        stats["fuel-fed:" .. f] = (stats["fuel-fed:" .. f] or 0) + moved
      end
    end
  end
  return inserted
end

-- A furnace loaded with iron ore AND completed iron plates cannot select
-- copper until both incompatible inventories have been emptied. Return real
-- items through the canonical storage authority, preserving rollback custody
-- if the station cannot accept them. Never mutate the engine recipe or create
-- an item outside an actual inventory transfer.
local function return_furnace_item(pair, inv, item, reason)
  local n=inventory_count(inv,item)
  if n<=0 then return true end
  if pair.emergency_facility_feed_custody_0357
      or type(_G.tech_priests_safe_deposit_item)~="function" then return false end
  local removed=remove_item(inv,item,n)
  if removed<=0 then return false end
  local ok,accepted,why,amount=pcall(_G.tech_priests_safe_deposit_item,
    pair,item,removed,reason)
  local deposited=ok and math.max(0,math.min(removed,
    tonumber(amount) or (accepted==true and removed or 0))) or 0
  local missing=removed-deposited
  if missing>0 then
    missing=missing-math.max(0,math.min(missing,
      insert_item(inv,item,missing)))
    if missing>0 then
      pair.emergency_facility_feed_custody_0357={
        item=item,count=missing,created_tick=now(),
        reason="furnace-reconfiguration-rollback-blocked",
      }
    end
  end
  if deposited>0 then
    local stats=ensure_root().stats
    local prefix=reason=="local-owned-electronics-output-return-0357"
        and "local-electronics-output-return:"
      or reason=="local-owned-laboratorium-output-return-0357"
        and "local-laboratorium-output-return:"
      or reason=="local-owned-science-output-return-0357"
        and "local-science-output-return:"
      or "furnace-return-for-copper:"
    local key=prefix..item
    stats[key]=(stats[key] or 0)+deposited
  end
  return ok and accepted==true and deposited==removed
    and not pair.emergency_facility_feed_custody_0357
end

-- Return already-produced Electronics intermediates from a *locally owned*
-- emergency assembler to this station's managed general storage. The existing
-- executor already returns finished outputs from owned facilities; this
-- maintenance closes the gap when the assigned production item has changed
-- to copper plates while completed cable remains in the old output slot.
-- Never move between Cogitator stations or steal an active machine-logistics
-- reservation/custody. Exact deposits and rollback are handled by the same
-- conservative ledger as furnace output returns.
local function settle_local_electronics_outputs(pair, facilities)
  -- This helper runs before the module's later find_role declaration;
  -- inspect its already-owned records directly rather than resolving a
  -- not-yet-bound local function as an absent Lua global.
  local assembler=nil
  for _,rec in ipairs(facilities or {}) do
    if rec.role=="assembler" and valid(rec.entity) then
      assembler=rec.entity
      break
    end
  end
  if not (valid(assembler) and assembler.position and pair.station.position)
      or dist_sq(assembler.position,pair.station.position)>64
      or pair.machine_logistics_custody_0528 then return 0 end
  local route=pair.machine_logistics_0528
  if type(route)=="table" and route.machine==assembler
      and route.phase~="complete" and route.phase~="failed"
      and route.phase~="idle" then return 0 end
  local output=safe_inventory(assembler,defines.inventory.assembling_machine_output)
  if not output then return 0 end
  local restored,electronics_restored,labs_restored,science_restored,parts_restored=
    0,0,0,0,0
  -- Return only genuinely engine-completed production from our own
  -- assembler, including the first red science batch. This inventory
  -- transfer never grants science, technologies or machine output.
  for _,item in ipairs({"copper-cable","electronic-circuit",
      "iron-gear-wheel","transport-belt",
      "tech-priests-emergency-laboratorium","lab",
      "automation-science-pack","logistic-science-pack"}) do
    local amount=inventory_count(output,item)
    if amount>0 then
      local is_lab=item=="tech-priests-emergency-laboratorium"
        or item=="lab"
      local is_science=item=="automation-science-pack"
        or item=="logistic-science-pack"
      local is_part=item=="iron-gear-wheel" or item=="transport-belt"
      local ok=return_furnace_item(pair,output,item,
        is_lab and "local-owned-laboratorium-output-return-0357"
          or is_science and "local-owned-science-output-return-0357"
          or "local-owned-electronics-output-return-0357")
      if not ok then break end
      restored=restored+amount
      if is_lab then labs_restored=labs_restored+amount
      elseif is_science then science_restored=science_restored+amount
      elseif is_part then parts_restored=parts_restored+amount
      else electronics_restored=electronics_restored+amount end
    end
  end
  if restored>0 then
    local stats=ensure_root().stats
    if electronics_restored>0 then
      stats["local-electronics-output-settled-0357"]=
        (stats["local-electronics-output-settled-0357"] or 0)+electronics_restored
    end
    if labs_restored>0 then
      stats["local-laboratorium-output-settled-0357"]=
        (stats["local-laboratorium-output-settled-0357"] or 0)+labs_restored
    end
    if science_restored>0 then
      stats["local-science-output-settled-0357"]=
        (stats["local-science-output-settled-0357"] or 0)+science_restored
    end
    if parts_restored>0 then
      stats["local-lab-parts-output-settled-0357"]=
        (stats["local-lab-parts-output-settled-0357"] or 0)+parts_restored
    end
  end
  return restored
end

-- Once a genuine laboratory exists, supply its real input slot from
-- that station's managed general stock. Keep all science movement local and
-- inventory-backed. The engine alone decides whether laboratory energy,
-- research and science consumption actually progress.
local function feed_owned_laboratories(pair,facilities)
  if not (defines and defines.inventory
      and defines.inventory.lab_input)
      or pair.emergency_facility_feed_custody_0357 then return 0 end
  local fed=0
  for _,rec in ipairs(facilities or {}) do
    local lab=rec.entity
    if rec.role=="lab" and valid(lab)
        and lab.surface==pair.station.surface
        and lab.force==pair.station.force then
      local input=safe_inventory(lab,defines.inventory.lab_input)
      if input then
        for _,pack in ipairs({"automation-science-pack",
            "logistic-science-pack"}) do
          local needed=2-inventory_count(input,pack)
          if needed>0 then
            local amount=transfer_station_item(pair,input,pack,needed)
            if amount>0 then
              fed=fed+amount
              local stats=ensure_root().stats
              local key="physical-science-fed:"..pack
              stats[key]=(stats[key] or 0)+amount
            end
          end
        end
        -- Labs with no real science packs cannot make research progress.
        -- Do not park the last physical coal in an empty laboratory while
        -- the furnace and assembler still need burner fuel. Supply coal
        -- after a genuine pack arrives in the engine-owned input inventory.
        if inventory_count(input,"automation-science-pack")>0
            or inventory_count(input,"logistic-science-pack")>0 then
          local fuel_fed=feed_fuel_from_pair(pair,lab)
          if fuel_fed>0 then
            local stats=ensure_root().stats
            stats["physical-laboratory-fuel-fed"]=
              (stats["physical-laboratory-fuel-fed"] or 0)+fuel_fed
          end
        end
      end
    end
  end
  return fed
end

local function release_furnace_iron_for_copper(pair, entity, input)
  if pair.emergency_facility_feed_custody_0357
      or (not source_inventory_for(pair,"copper-ore")
        and inventory_count(input,"copper-ore")<=0) then return false end
  local ok_progress,progress=pcall(function()return entity.crafting_progress end)
  if ok_progress and tonumber(progress) and progress>0 then
    return false -- Finish an already-progressing iron smelt first.
  end
  local result=safe_inventory(entity,defines.inventory.furnace_result)
  -- Returning finished iron plates is essential: the old output also locks
  -- Factorio's automatic furnace recipe selection, even after source swap.
  if not return_furnace_item(pair,result,"iron-plate",
      "physical-furnace-iron-output-return-0357") then return false end
  return return_furnace_item(pair,input,"iron-ore",
    "physical-furnace-copper-priority-return-0357")
end

-- Electronics may consume the last iron plate while its only furnace
-- still contains copper ore and finished copper plates. The return path must
-- work in both directions or the genuine circuit iron prerequisite deadlocks.
-- Never interrupt a running smelt; return exact real inventory items first.
local function release_furnace_copper_for_iron(pair, entity, input)
  -- The ten genuine copper plates are Factorio 2.0's Electronics trigger.
  -- A parallel early gear/iron request must not tear down copper production
  -- before research. Reverse only for the confirmed circuit iron prerequisite.
  local electronics=pair.station.force and pair.station.force.technologies
    and pair.station.force.technologies["electronics"]
  local request=pair.infrastructure_recipe_request_0647
  local gate=pair.local_infrastructure_gate_0640
  local circuit_iron=(type(request)=="table"
      and request.item=="electronic-circuit" and request.missing=="iron-plate")
    or (type(gate)=="table" and gate.item=="iron-plate"
      and gate.why=="first-electronics-physical-iron-smelting")
  if not (electronics and electronics.researched==true and circuit_iron) then
    return true
  end
  if pair.emergency_facility_feed_custody_0357
      or (not source_inventory_for(pair,"iron-ore")
        and inventory_count(input,"iron-ore")<=0) then return false end
  local ok_progress,progress=pcall(function()return entity.crafting_progress end)
  if ok_progress and tonumber(progress) and progress>0 then
    return false
  end
  local result=safe_inventory(entity,defines.inventory.furnace_result)
  if not return_furnace_item(pair,result,"copper-plate",
      "physical-furnace-copper-output-return-0357") then return false end
  return return_furnace_item(pair,input,"copper-ore",
    "physical-furnace-iron-priority-return-0357")
end

local function feed_inputs_from_pair(pair, entity, want_item)
  local input = safe_inventory(entity, defines.inventory.assembling_machine_input) or safe_inventory(entity, defines.inventory.furnace_source)
  if not input then return 0 end
  if entity.type=="furnace" then
    if want_item=="copper-plate"
        and not release_furnace_iron_for_copper(pair,entity,input) then
      return 0
    end
    if want_item=="iron-plate"
        and not release_furnace_copper_for_iron(pair,entity,input) then
      return 0
    end
  end
  local inserted = 0
  -- Furnaces autonomously select a recipe from their source inventory. Feed
  -- only the real input for the requested product: never mix copper/stone
  -- into an iron-smelting furnace as a generic fallback.
  local candidates
  if entity.type == "furnace" then
    local input_item = (want_item == "iron-plate" and "iron-ore")
      or (want_item == "copper-plate" and "copper-ore")
      or (want_item == "stone-brick" and "stone") or nil
    candidates = input_item and { input_item } or {}
  else
    -- A running assembler consumes the selected, actual Factorio recipe.
    -- Feeding an arbitrary ore/plate list cannot manufacture electronic
    -- circuits: copper cable never appears in that generic list.
    local recipe
    pcall(function() recipe=entity.get_recipe and entity.get_recipe() end)
    if not recipe then return 0 end
    candidates = {}
    local seen = {}
    for _, ingredient in pairs(recipe.ingredients or {}) do
      if ingredient.name and ingredient.type ~= "fluid"
          and not seen[ingredient.name] then
        seen[ingredient.name] = true
        candidates[#candidates+1] = {
          name=ingredient.name, count=math.max(1,math.ceil(tonumber(ingredient.amount)or 1))
        }
      end
    end
  end
  for _, it in ipairs(candidates) do
    local item=type(it)=="table" and it.name or it
    local count=type(it)=="table" and it.count or 4
    if item and inventory_count(input, item) < count then
      inserted = inserted + transfer_station_item(pair, input, item,
        count - inventory_count(input, item))
    end
  end
  return inserted
end

local function choose_request_item(pair)
  -- The pending smelter output is authoritative while the priest hand-mines
  -- its physical ore/fuel inputs. Otherwise direct acquisition requests for
  -- "iron-ore" replace the desired smelting product ("iron-plate"), and no
  -- smelter recipe is selected even after real materials arrive.
  local production=pair and pair.emergency_craft
  if type(production)=="table"
      and (production.facility_only_0647==true or production.strict_recipe_0647==true) then
    -- A live authorized recipe outranks a stale direct-acquisition alias.
    -- This includes the first copper-cable and electronic-circuit operations;
    -- otherwise the assembler keeps selecting ore (or no recipe at all).
    local wanted=production.output_item or production.item_name
    if type(wanted)=="string" and wanted~="" then return wanted end
  end
  local task = pair and (pair.station_crafting_task_0337 or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333 or pair.emergency_operation or pair.independent_emergency_operation)
  if type(task) == "table" then
    return task.item or task.item_name or task.craft or task.requested_item or task.output or task.target_item
  end
  if type(task) == "string" then return task end
  for _, it in ipairs(REQUEST_ITEMS) do return it end
  return "iron-ore"
end

local function find_role(facilities, role)
  for _, rec in pairs(facilities or {}) do
    if rec and rec.role == role and rec.entity and rec.entity.valid then return rec.entity end
  end
  return nil
end

local function has_role(facilities, role)
  return find_role(facilities, role) ~= nil
end

local function missing_core_items(facilities)
  local have = {}
  for _, rec in pairs(facilities or {}) do if rec and rec.name then have[rec.name] = true end end
  local missing = {}
  for _, name in ipairs(REQUIRED_CORE) do if not have[name] then missing[#missing+1] = item_for_entity(name) end end
  return missing
end

local function give_build_order(pair, item)
  -- If the construction planner sees the item in the bound station inventory, it
  -- will place it. This module does not fabricate items; crafting/acquisition
  -- modules remain responsible for producing them.
  local planner = _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0357 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0343 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0342 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0340 or _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0338
  if planner and planner.service_pair then
    pcall(planner.service_pair, pair, "emergency-facility-doctrine")
  end
  draw(pair, "placing emergency facility: [item=" .. tostring(item) .. "]", 90)
end

-- A single recipe selector is shared by the dispatcher-driven facility
-- service and the independent, machine-only maintenance pulse. Otherwise
-- the former assigns iron before the latter can inspect real furnace fuel.
local function initial_miner_recipe(pair, facilities, miner, request_item)
  if request_item=="coal" or request_item=="copper-ore"
      or request_item=="stone" or request_item=="wood" then
    return recipe_for("miner",request_item)
  end
  local root=ensure_root()
  -- Select an initial mining rite from physical bootstrap demand.
  -- An existing furnace with ore but no coal is a blocked industrial
  -- input, not permission to fabricate fuel. The unfueled emergency
  -- miner can make coal with its normal, slow, inventory-backed recipe.
  -- Do not change an already-selected priest/player recipe.
  local preferred = "iron-ore"
  if defines and defines.inventory then
    -- Read the same cache-backed general stock used by physical facility
    -- feeding. Ore in a stone cache must influence the very first miner's
    -- iron-versus-coal choice; Cogitator manufacturing buffers are not stock.
    local iron, coal = 0, 0
    for _, source in ipairs(managed_sources(pair)) do
      iron = iron + inventory_count(source.inv, "iron-ore")
      coal = coal + inventory_count(source.inv, "coal")
    end
    for _, rec in pairs(facilities) do
      if rec and rec.role == "smelter" and valid(rec.entity) then
        iron = iron + inventory_count(
          safe_inventory(rec.entity, defines.inventory.furnace_source), "iron-ore")
        coal = coal + inventory_count(
          safe_inventory(rec.entity, defines.inventory.fuel), "coal")
      end
    end
    -- Each physically present shared-force station requires a sustained
    -- fuel supply, not merely a few coal items in its caches at startup.
    -- Balance the initial automatic miners across iron and coal. The first
    -- starts on iron; the next unconfigured peer starts on coal, etc. This
    -- happens only before any recipe is selected, so a priest/player recipe
    -- is never overwritten by periodic maintenance.
    local peer_count, iron_miners, coal_miners, copper_miners = 0, 0, 0, 0
    for _, other in pairs(pairs_map()) do
      if valid_pair(other) and other.station.force==pair.station.force
          and other.station.surface==pair.station.surface then
        peer_count=peer_count+1
      end
    end
    -- Reuse the established bounded per-station facility scan to
    -- reconcile and count actual miner recipes. No new whole-surface scan
    -- site or separate owner is introduced; the existing nearest-station
    -- claim arbitration remains authoritative.
    local observed_miners,seen_miners={},{}
    for _,peer in pairs(pairs_map()) do
      if valid_pair(peer) and peer.station.surface==pair.station.surface
          and peer.station.force==pair.station.force then
        for _,record in ipairs(scan_owned_emergency(peer)) do
          local entity=record and record.entity
          if valid(entity) and entity.name=="tech-priests-emergency-miner"
              and not seen_miners[entity] then
            seen_miners[entity]=true
            observed_miners[#observed_miners+1]=entity
          end
        end
      end
    end
    local scanned=#observed_miners>0
    for _,other in pairs(observed_miners) do
      if valid(other) and other~=miner
          and other.name=="tech-priests-emergency-miner"
          and other.force==pair.station.force
          and other.surface==pair.station.surface then
        local ok, selected=pcall(function()
          local r=other.get_recipe and other.get_recipe()
          return type(r)=="string" and r or (r and r.name)
        end)
        if ok and selected=="tech-priests-emergency-mine-iron-ore" then
          iron_miners=iron_miners+1
        elseif ok and selected=="tech-priests-emergency-mine-coal" then
          coal_miners=coal_miners+1
        elseif ok and selected=="tech-priests-emergency-mine-copper-ore" then
          copper_miners=copper_miners+1
        end
      end
    end
    if peer_count>1 then
      -- First establish actual iron and burner fuel income. With three or
      -- more independent stations, dedicate the next unconfigured miner to
      -- real copper extraction if that engine recipe exists; otherwise all
      -- copper for cables and circuits is hand-mined while the production
      -- chain starves. Count already-selected miners across owned stations,
      -- but never retarget an active/player-selected recipe.
      if peer_count>=3 and iron_miners>0 and coal_miners>0
          and copper_miners==0
          and recipe_exists("tech-priests-emergency-mine-copper-ore") then
        preferred="copper-ore"
      elseif copper_miners>0 and coal_miners<=iron_miners then
        -- A third specialist expands copper demand, including furnace and
        -- workshop fuel. Reserve the fourth independent miner for actual coal
        -- supply rather than leaving one coal mine feeding four workshops.
        -- Do not change any miner with an engine-selected recipe.
        preferred="coal"
      elseif iron_miners>coal_miners then
        preferred="coal"
      end
    elseif iron>=2 and coal<4 then
      -- A lone miner must supply fuel for an ore-filled real smelter even
      -- if one or two stranded coal items still remain in general stock.
      preferred="coal"
    end
    -- Save the selection inputs, never synthetic inventories or research.
    -- This single-assignment diagnostic can explain a mistaken miner split.
    pair.emergency_miner_allocation_diagnostic_0357={
      tick=now(),peers=peer_count,iron=iron_miners,coal=coal_miners,
      copper=copper_miners,selected=preferred,
      has_copper_recipe=recipe_exists("tech-priests-emergency-mine-copper-ore"),
      scanned=scanned,
    }
  end
  return recipe_for("miner", preferred)
end

local function use_owned_facilities(pair, facilities, request_item)
  local used = false
  local smelter = find_role(facilities, "smelter")
  local smelter_request=request_item
  -- A copper-cable recipe needs plates supplied by a separately owned real
  -- furnace. The parent assembler can be running while its furnace still
  -- manufactures copper: selecting only the active assembler output here
  -- otherwise leaves a fueled furnace idle with real copper ore in storage.
  -- An explicit iron/copper smelt remains authoritative; this only services
  -- the immediately dependent copper-cable request.
  if smelter and request_item=="copper-cable" then
    local source=safe_inventory(smelter,defines.inventory.furnace_source)
    if inventory_count(source,"copper-ore")>0
        or source_inventory_for(pair,"copper-ore") then
      smelter_request="copper-plate"
    end
  end
  -- The first ten engine-crafted copper plates are a technology prerequisite.
  -- When copper smelting is the currently authorized physical transaction,
  -- put real coal into its furnace before routine miner replenishment. A
  -- miner otherwise takes the last available coal and leaves copper blocked.
  -- No fuel is reserved synthetically or removed from another machine.
  if smelter and smelter_request=="copper-plate" then
    local source=safe_inventory(smelter,defines.inventory.furnace_source)
    if inventory_count(source,"copper-ore")>0
        or source_inventory_for(pair,"copper-ore") then
      feed_fuel_from_pair(pair,smelter)
    end
  end
  local miner = find_role(facilities, "miner")
  if miner then
    local current = nil
    pcall(function()
      local r = miner.get_recipe and miner.get_recipe()
      current = type(r) == "string" and r or (r and r.name)
    end)
    -- Never overwrite any already-selected player/priest mining recipe.
    -- The first assignment uses the same physical ore/fuel decision as
    -- ongoing miner continuity, regardless of which service arrives first.
    local recipe = current or initial_miner_recipe(pair, facilities, miner, request_item)
    if recipe and (current or set_recipe(miner, recipe, pair, "micro-miner-default")) then
      feed_fuel_from_pair(pair, miner)
      draw(pair, "emergency miner: " .. tostring(recipe), 90)
      used = true
    end
  end

  if smelter then
    local recipe = recipe_for("smelter", smelter_request)
    -- LuaEntity.set_recipe() is assembling-machine-only in Factorio 2.0.
    -- Furnaces select their recipe from the actual source inventory. A failed
    -- set_recipe() must never prevent physically depositing ore and fuel.
    if recipe and (smelter.type == "furnace"
        or set_recipe(smelter, recipe, pair, "emergency-smelter")) then
      feed_fuel_from_pair(pair, smelter)
      feed_inputs_from_pair(pair, smelter, smelter_request)
      draw(pair, "emergency smelter: " .. tostring(recipe), 90)
      used = true
    end
  end

  local assembler = find_role(facilities, "assembler")
  if assembler then
    local recipe = recipe_for("assembler", request_item)
    if (request_item=="copper-cable" or request_item=="electronic-circuit")
        and not recipe then
      record_recipe_selection(pair,assembler,request_item,
        "prototype-unavailable","recipe not in prototypes.recipe")
    end
    if recipe and set_recipe(assembler, recipe, pair, "emergency-assembler") then
      feed_fuel_from_pair(pair, assembler)
      feed_inputs_from_pair(pair, assembler, request_item)
      draw(pair, "emergency assembler: " .. tostring(recipe), 90)
      used = true
    end
  end

  local condenser = find_role(facilities, "condenser")
  if condenser then
    local recipe = recipe_for("condenser", "water")
    if recipe then set_recipe(condenser, recipe, pair, "emergency-condenser") end
    feed_fuel_from_pair(pair, condenser)
    used = true
  end

  local boiler = find_role(facilities, "boiler")
  if boiler then feed_fuel_from_pair(pair, boiler); used = true end
  return used
end

local function service_pair(pair, reason)
  local root = ensure_root(); if root.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  if not restore_feed_custody(pair) then return false, "feed-custody-blocked" end
  forget_invalid(root)

  local facilities = scan_owned_emergency(pair)
  local request_item = choose_request_item(pair)
  if #facilities > 0 and use_owned_facilities(pair, facilities, request_item) then
    if pair.emergency_facility_feed_custody_0357 then return false, "feed-custody-retained" end
    root.stats.used = (root.stats.used or 0) + 1
    return true, "used-owned-facilities"
  end

  local missing = missing_core_items(facilities)
  if #missing > 0 then
    for _, item in ipairs(missing) do
      -- Only ask for the next missing item. Repeated pulses will advance the
      -- chain after construction/crafting catches up.
      give_build_order(pair, item)
      root.stats.requested_build = (root.stats.requested_build or 0) + 1
      return true, "requested-" .. tostring(item)
    end
  end

  return false, "no-emergency-facility-action"
end

-- The existing facility broker may maintain already-placed emergency miners
-- without assigning new construction or production orders. The dispatcher still
-- owns every priest action; this only selects the machine's real Factorio recipe.
function M.service_owned_miners_all(reason)
  local root = ensure_root(); if root.enabled == false then return 0 end
  local acted, checked = 0, 0
  for _, pair in pairs(pairs_map()) do
    if checked >= M.max_per_pulse then break end
    if valid_pair(pair) and now() >= (tonumber(pair.emergency_miner_next_service_tick_0357) or 0) then
      checked = checked + 1
      pair.emergency_miner_next_service_tick_0357 = now() + 120
      local facilities = scan_owned_emergency(pair)
      local settled=0
      if restore_feed_custody(pair) then
        settled=settle_local_electronics_outputs(pair,facilities)
        if settled>0 then acted=acted+1 end
        local science_fed=feed_owned_laboratories(pair,facilities)
        if science_fed>0 then acted=acted+1 end
      end
      -- The dispatcher suppresses independent strategic facility pulses.
      -- Existing machines still need their physical ingredient/fuel service
      -- while the priest completes a separate mining or custody movement.
      -- This maintenance never invents work, places entities or changes a
      -- priest's movement owner: it only services an existing authorized
      -- facility-only/strict recipe through the normal exact-transfer ledger.
      local task=pair.emergency_craft
      if type(task)=="table" and task.infrastructure_first_0640==true
          and (task.facility_only_0647==true
            or task.strict_recipe_0647==true)
          and restore_feed_custody(pair) then
        local request=task.output_item or task.item_name
        if request and use_owned_facilities(pair,facilities,request) then
          root.stats["ongoing-production-machine-service"]=
            (root.stats["ongoing-production-machine-service"] or 0)+1
          acted=acted+1
        end
      end
      local miner = find_role(facilities, "miner")
      if miner and valid(miner) then
        local selected
        pcall(function()
          local recipe = miner.get_recipe and miner.get_recipe()
          selected = type(recipe) == "string" and recipe or (recipe and recipe.name)
        end)
        -- Respect a running player/priest selected mining rite. Configure
        -- a safe default only when the new machine has no recipe at all.
        if not selected then
          local recipe = initial_miner_recipe(pair, facilities, miner, nil)
          if recipe and set_recipe(miner, recipe, pair, "owned-miner-continuity") then
            root.stats.miner_recipes_started = (root.stats.miner_recipes_started or 0) + 1
            acted = acted + 1
          end
        end
      end
    end
  end
  return acted
end

function M.service_pair(pair, reason) return service_pair(pair, reason or "external") end

function M.service_all(reason)
  local root = ensure_root(); if root.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pairs_map()) do
    if n >= M.max_per_pulse then break end
    local ok = service_pair(pair, reason or "pulse")
    if ok then n = n + 1 end
  end
  return n
end

local function selected_pair(player)
  if not (player and player.valid and player.selected) then return nil end
  local sel = player.selected
  for _, pair in pairs(pairs_map()) do
    if pair and ((valid(pair.station) and pair.station == sel) or (valid(pair.priest) and pair.priest == sel)) then return pair end
  end
  return nil
end

local function describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local facilities = scan_owned_emergency(pair)
  local roles = {}
  for _, rec in ipairs(facilities) do roles[#roles+1] = tostring(rec.role) .. ":" .. tostring(rec.name) end
  return "station=" .. tostring(pair.station.unit_number) .. " facilities=" .. tostring(#facilities) .. " request=" .. tostring(choose_request_item(pair)) .. " :: " .. table.concat(roles, ", ")
end

function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-emergency-facilities-0339") end)
  commands.add_command("tp-emergency-facilities-0339", "Tech-Priests Martian emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[tp-emergency-facilities-0339] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[tp-emergency-facilities-0339] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[tp-emergency-facilities-0339] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[tp-emergency-facilities-0339] debug chat off") return end
    if arg == "all" then player.print("[tp-emergency-facilities-0339] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-emergency-facilities-0339] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[tp-emergency-facilities-0339] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[tp-emergency-facilities-0339] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end)

  pcall(function() commands.remove_command("tp-emergency-facilities-0340") end)
  commands.add_command("tp-emergency-facilities-0340", "Tech-Priests 0.1.340 Martian emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[tp-emergency-facilities-0340] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[tp-emergency-facilities-0340] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[tp-emergency-facilities-0340] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[tp-emergency-facilities-0340] debug chat off") return end
    if arg == "all" then player.print("[tp-emergency-facilities-0340] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-emergency-facilities-0340] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[tp-emergency-facilities-0340] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[tp-emergency-facilities-0340] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end)

  local function handle_0357(event, label)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[" .. label .. "] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[" .. label .. "] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[" .. label .. "] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[" .. label .. "] debug chat off") return end
    if arg == "all" then player.print("[" .. label .. "] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[" .. label .. "] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[" .. label .. "] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[" .. label .. "] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end
  pcall(function() commands.remove_command("tp-emergency-facilities-0343") end)
  pcall(function() commands.remove_command("tp-emergency-facilities-0357") end)
  commands.add_command("tp-emergency-facilities-0357", "Tech-Priests 0.1.357 emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_0357(event, "tp-emergency-facilities-0357") end)
  commands.add_command("tp-emergency-facilities-0343", "Tech-Priests 0.1.342 Martian emergency facility doctrine status/kick/all/enable/disable/debug-on/debug-off", function(event)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[tp-emergency-facilities-0343] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[tp-emergency-facilities-0343] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[tp-emergency-facilities-0343] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[tp-emergency-facilities-0343] debug chat off") return end
    if arg == "all" then player.print("[tp-emergency-facilities-0343] serviced " .. tostring(M.service_all("command-all")) .. " pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-emergency-facilities-0343] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then local ok, why = service_pair(pair, "command-kick"); player.print("[tp-emergency-facilities-0343] kick=" .. tostring(ok) .. " reason=" .. tostring(why)); player.print(describe_pair(pair)); return end
    player.print("[tp-emergency-facilities-0343] enabled=" .. tostring(root.enabled) .. " tagged=" .. tostring(root.stats.tagged or 0) .. " used=" .. tostring(root.stats.used or 0) .. " requested-build=" .. tostring(root.stats.requested_build or 0))
    player.print(describe_pair(pair))
  end)
end

function M.install()
  ensure_root()
  M.install_commands()
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0339 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0357 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0340 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0342 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343 = M
  _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0348 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "emergency_facility_doctrine_0357", category = "emergency", interval = M.service_period or 60, priority = 60, budget = 8, fn = function(event, budget) return M.service_all("broker-periodic") end, note = "Martian emergency facility doctrine migrated from direct nth-tick" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(M.service_period, function() M.service_all("registry-periodic") end, { owner = "emergency_facility_doctrine_0357", category = "emergency", note = "fallback until runtime broker is available", priority = "normal" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.service_period, function() M.service_all("periodic") end)
    end
  end
  if log then log("[Tech-Priests 0.1.357] Martian emergency facility doctrine station-bound inventory source lookup loaded") end
end

return M
