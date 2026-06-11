-- 0.1.592 Conclave Center runtime scaffold.
-- GUI/research governance layer only.  It gates remote Shift+Y access behind a
-- placed Conclave Center, opens the management overview from the physical
-- console, and maintains lightweight doctrine vote/loyalty ledgers.  It does
-- not move priests, create construction/acquisition work, or bypass the
-- dispatcher/order-queue/action-arbiter authority stack.

local M = {}

local ENTITY = "tech-priests-conclave-center"
local FRAME = "tech_priests_conclave_center_0558"
local CLOSE = "tech_priests_conclave_center_close_0558"
local OPEN_OVERVIEW = "tech_priests_conclave_center_open_overview_0558"
local PLAYER_VOTE_PREFIX = "tech_priests_conclave_vote_0558_"

local VOTE_THRESHOLD = 20
local CYCLE_TICKS = 60 * 60 * 30       -- about thirty minutes between major conclaves
local VOTE_TICKS = 60 * 5              -- five minute visible voting window

local FAMILIES = {
  { key = "logistics", label = "Logistics Reliquary", needles = { "logistic", "rail", "transport", "robot", "belt", "inserter", "cargo" } },
  { key = "industry", label = "Forge-Industry", needles = { "automation", "manufactur", "production", "module", "smelt", "furnace", "assembler", "foundry" } },
  { key = "energy", label = "Motive Force", needles = { "electric", "energy", "power", "solar", "steam", "nuclear", "accumulator", "fusion" } },
  { key = "military", label = "Ballistic Litany", needles = { "military", "damage", "weapon", "turret", "armor", "ammo", "laser", "explosive" } },
  { key = "science", label = "Noospheric Inquiry", needles = { "science", "research", "lab", "chemical", "advanced", "processing" } },
  { key = "space", label = "Void Doctrine", needles = { "space", "rocket", "asteroid", "platform", "orbital", "void" } },
  { key = "sanctification", label = "Machine-Spirit Rite", needles = { "cogitator", "tech-priest", "sanct", "machine", "ritual", "litany", "conclave" } }
}

local function ensure()
  storage.tech_priests = storage.tech_priests or {}
  local root = storage.tech_priests.conclave_center_0558 or {}
  storage.tech_priests.conclave_center_0558 = root
  root.centers_by_force = root.centers_by_force or {}
  root.force_state = root.force_state or {}
  root.player_vote = root.player_vote or {}
  return root
end

local function force_key(force)
  return force and force.valid and force.name or "player"
end

local function setting_bool_0589(name, default)
  if settings and settings.global and settings.global[name] ~= nil then
    local ok, value = pcall(function() return settings.global[name].value end)
    if ok and value ~= nil then return not not value end
  end
  return not not default
end

local function rebellions_enabled_0589()
  return setting_bool_0589("tech-priests-enable-doctrine-rebellions", true)
end

local function steal_machines_enabled_0589()
  -- Player-facing setting is protective: ON means defectors do not seize machines.
  -- If an older dev build's explicit steal setting exists, honor it; otherwise invert the protection setting.
  if settings and settings.global and settings.global["tech-priests-rogue-doctrines-steal-machines"] ~= nil then
    return setting_bool_0589("tech-priests-rogue-doctrines-steal-machines", false)
  end
  return not setting_bool_0589("tech-priests-dont-touch-my-toys", true)
end

local function doctrine_is_hard_loyal_0591(family)
  return tostring(family or "") == "space"
end

local function get_force_state(force)
  local root = ensure()
  local key = force_key(force)
  local state = root.force_state[key]
  if not state then
    state = { loyalty = {}, emergency_constructed = {}, next_conclave_tick = (game and game.tick or 0) + CYCLE_TICKS, phase = "waiting", votes = {}, tech_family_map = {}, tech_family_basis = {} }
    for _, fam in pairs(FAMILIES) do
      state.loyalty[fam.key] = 100
      state.emergency_constructed[fam.key] = 0
    end
    state.loyalty.space = 100
    root.force_state[key] = state
  end
  return state
end

local function count_centers(force)
  local root = ensure()
  local key = force_key(force)
  local list = root.centers_by_force[key] or {}
  local n = 0
  for unit, ent in pairs(list) do
    if ent and ent.valid then n = n + 1 else list[unit] = nil end
  end
  return n
end

local function has_center(force)
  return count_centers(force) > 0
end

local function register_center(entity)
  if not (entity and entity.valid and entity.name == ENTITY and entity.force) then return end
  local root = ensure()
  local key = force_key(entity.force)
  root.centers_by_force[key] = root.centers_by_force[key] or {}
  root.centers_by_force[key][entity.unit_number or ("pos:" .. entity.position.x .. ":" .. entity.position.y)] = entity
  get_force_state(entity.force)
end

local function unregister_center(entity)
  if not (entity and entity.name == ENTITY and entity.force) then return end
  local root = ensure()
  local list = root.centers_by_force[force_key(entity.force)]
  if list then list[entity.unit_number or 0] = nil end
end

local function pair_family(pair)
  local d = (pair and (pair.doctrine or pair.doctrine_family or pair.camp or pair.alignment)) or ""
  d = tostring(d):lower()
  if d:find("void", 1, true) then return "space" end
  if d:find("logistic", 1, true) or d:find("reliquary", 1, true) then return "logistics" end
  if d:find("quality", 1, true) or d:find("forge", 1, true) then return "industry" end
  if d:find("military", 1, true) or d:find("ballistic", 1, true) then return "military" end
  local station = pair and pair.station and pair.station.valid and pair.station.name or ""
  if station:find("void", 1, true) then return "space" end
  if station:find("planetary%-magos", 1, false) then return "sanctification" end
  if station:find("senior", 1, true) then return "industry" end
  if station:find("intermediate", 1, true) then return "logistics" end
  return "sanctification"
end

local function doctrine_counts(force)
  local counts = {}
  for _, fam in pairs(FAMILIES) do counts[fam.key] = 0 end
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return counts, 0 end
  local total = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.station and pair.station.valid and pair.station.force == force and pair.priest and pair.priest.valid then
      local fam = pair_family(pair)
      counts[fam] = (counts[fam] or 0) + 1
      total = total + 1
    end
  end
  return counts, total
end


local function family_keys()
  local out = {}
  for _, fam in pairs(FAMILIES) do out[#out + 1] = fam.key end
  return out
end

local function hash_string(text, seed)
  local h = tonumber(seed) or 0
  text = tostring(text or "")
  for i = 1, #text do
    h = (h * 131 + string.byte(text, i)) % 2147483647
  end
  return h
end

local function force_seed(force)
  local seed = 0
  pcall(function() seed = game and game.surfaces and game.surfaces[1] and game.surfaces[1].map_gen_settings and game.surfaces[1].map_gen_settings.seed or 0 end)
  return tonumber(seed) or hash_string(force_key(force), 561)
end

local function classify_technology_static(tech)
  local lname = tostring(tech and tech.name or ""):lower()
  for _, fam in pairs(FAMILIES) do
    for _, needle in pairs(fam.needles) do
      if lname:find(needle, 1, true) then return fam.key end
    end
  end
  if tech and tech.effects then
    for _, effect in pairs(tech.effects) do
      local text = tostring(effect.recipe or effect.type or ""):lower()
      for _, fam in pairs(FAMILIES) do
        for _, needle in pairs(fam.needles) do
          if text:find(needle, 1, true) then return fam.key end
        end
      end
    end
  end
  return "science"
end

local function family_for_technology(force, tech)
  if not tech then return "science" end
  local proto = tech.prototype or tech
  local name = tostring(proto.name or tech.name or "unknown")
  local state = get_force_state(force)
  state.tech_family_map = state.tech_family_map or {}
  state.tech_family_basis = state.tech_family_basis or {}
  if state.tech_family_map[name] then return state.tech_family_map[name] end
  local static = classify_technology_static(proto)
  local keys = family_keys()
  local h = hash_string(name, force_seed(force) + 561)
  local assigned = static
  local basis = "keyword"
  -- Most technologies remain with the obvious doctrine, but a small seed-bound
  -- chance lets each save acquire its own doctrine politics without changing
  -- prototypes or forcing a migration. This is deterministic per map/force.
  if #keys > 0 and (h % 100) < 18 then
    assigned = keys[(h % #keys) + 1]
    basis = "seed-divergence-from-" .. tostring(static)
  end
  state.tech_family_map[name] = assigned
  state.tech_family_basis[name] = basis
  return assigned
end

local function classify_technology(tech)
  return classify_technology_static(tech)
end

local function next_tech_for_family(force, family)
  if not (force and force.valid and force.technologies) then return nil end
  local fallback = nil
  for name, tech in pairs(force.technologies) do
    if tech and tech.valid and tech.enabled and not tech.researched and tech.research_unit_count and tech.research_unit_count > 0 then
      if not fallback then fallback = tech end
      if family_for_technology(force, tech) == family then return tech end
    end
  end
  return fallback
end



local function apply_style_0564(element, style_name)
  if not (element and element.valid and style_name) then return false end
  return pcall(function() element.style = style_name end)
end

local function apply_screen_scroll_style_0564(element)
  if not (element and element.valid) then return false end
  apply_style_0564(element, "tech_priests_cogitator_screen_scroll_0564")
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.vertically_stretchable = true end)
  pcall(function() element.style.padding = 8 end)
  return true
end

local function apply_screen_table_style_0564(element)
  if not (element and element.valid) then return false end
  apply_style_0564(element, "tech_priests_cogitator_screen_table_0564")
  pcall(function() element.style.cell_padding = 4 end)
  pcall(function() element.style.horizontal_spacing = 6 end)
  pcall(function() element.style.vertical_spacing = 4 end)
  return true
end

local function green(text)
  return "[color=0,255,64]" .. tostring(text or "") .. "[/color]"
end

local function boot_spinner_sprite_0559(tick)
  local frame = (math.floor((tonumber(tick) or 0) / 15) % 12) + 1
  return string.format("tech-priests-gui-boot-spinner-0526-%02d", frame)
end

local function set_wrap(label, width)
  if not (label and label.valid and label.style) then return end
  pcall(function() label.style.single_line = false end)
  pcall(function() label.style.width = width end)
end

local function fmt_ticks(ticks)
  ticks = math.max(0, math.floor(tonumber(ticks) or 0))
  local s = math.floor(ticks / 60)
  local m = math.floor(s / 60)
  s = s % 60
  return string.format("%02d:%02d", m, s)
end

local function family_label(key)
  for _, fam in pairs(FAMILIES) do if fam.key == key then return fam.label end end
  return tostring(key)
end


local DOCTRINE_ENEMIES_0588 = {
  logistics = { military = true, space = true },
  industry = { science = true, sanctification = true },
  energy = { logistics = true, space = true },
  military = { logistics = true, science = true },
  science = { industry = true, military = true, sanctification = true },
  space = { energy = true, logistics = true },
  sanctification = { industry = true, science = true },
}

local function family_dislikes(family)
  local out = {}
  local map = DOCTRINE_ENEMIES_0588[family] or {}
  for _, fam in pairs(FAMILIES) do if map[fam.key] then out[#out+1] = fam.key end end
  return out
end

local function doctrine_web_root_0588(state)
  state.doctrine_web_0588 = state.doctrine_web_0588 or { last_events = {}, rogue = {}, schism_waves = {}, family_recent = {} }
  state.doctrine_web_0588.last_events = state.doctrine_web_0588.last_events or {}
  state.doctrine_web_0588.rogue = state.doctrine_web_0588.rogue or {}
  state.doctrine_web_0588.schism_waves = state.doctrine_web_0588.schism_waves or {}
  state.doctrine_web_0588.family_recent = state.doctrine_web_0588.family_recent or {}
  return state.doctrine_web_0588
end

local function remember_doctrine_event_0588(state, text)
  local web = doctrine_web_root_0588(state)
  web.last_events[#web.last_events+1] = { tick = game and game.tick or 0, text = tostring(text or "") }
  while #web.last_events > 20 do table.remove(web.last_events, 1) end
end

local function remember_doctrine_family_event_0592(state, family, text, delta)
  remember_doctrine_event_0588(state, text)
  local web = doctrine_web_root_0588(state)
  local key = tostring(family or "unknown")
  web.family_recent[key] = { tick = game and game.tick or 0, text = tostring(text or ""), delta = tonumber(delta) or 0 }
end

local function doctrine_relation_rows_0592(force)
  local state = get_force_state(force)
  local web = doctrine_web_root_0588(state)
  local rows = {}
  for _, fam in pairs(FAMILIES) do
    local dislikes = {}
    for _, k in ipairs(family_dislikes(fam.key)) do dislikes[#dislikes + 1] = family_label(k) end
    local recent = web.family_recent and web.family_recent[fam.key]
    rows[#rows + 1] = {
      family = fam.key,
      label = fam.label,
      loyalty = (state.loyalty and state.loyalty[fam.key]) or 100,
      dislikes = dislikes,
      recent_tick = recent and recent.tick or nil,
      recent_text = recent and recent.text or "no recent loyalty movement",
      hard_loyal = doctrine_is_hard_loyal_0591(fam.key)
    }
  end
  return rows
end

local function known_research_for_web_0588(force, limit)
  local out = {}
  if not (force and force.valid and force.technologies) then return out end
  limit = tonumber(limit) or 36
  for name, tech in pairs(force.technologies) do
    if #out >= limit then break end
    if tech and tech.valid and tech.enabled and not tech.researched and tech.research_unit_count and tech.research_unit_count > 0 then
      local fam = family_for_technology(force, tech)
      out[#out+1] = { name = name, tech = tech, family = fam }
    end
  end
  table.sort(out, function(a,b) return tostring(a.name) < tostring(b.name) end)
  return out
end

local function force_is_rogue_doctrine_0590(force)
  return force and force.valid and tostring(force.name or ""):sub(1, 19) == "tech-priests-rogue-"
end

local function inherit_force_technology_0590(source, rogue)
  if not (source and source.valid and rogue and rogue.valid) then return end
  if source.technologies and rogue.technologies then
    for name, tech in pairs(source.technologies) do
      local rt = rogue.technologies[name]
      if tech and rt then
        pcall(function() rt.researched = tech.researched end)
        pcall(function() rt.enabled = tech.enabled end)
      end
    end
  end
  if source.recipes and rogue.recipes then
    for name, recipe in pairs(source.recipes) do
      local rr = rogue.recipes[name]
      if recipe and rr then pcall(function() rr.enabled = recipe.enabled end) end
    end
  end
end

local function set_rogue_hostility_0590(source, rogue)
  if not (rogue and rogue.valid) then return end
  if source and source.valid and source ~= rogue then
    pcall(function() source.set_cease_fire(rogue, false) end)
    pcall(function() rogue.set_cease_fire(source, false) end)
    pcall(function() source.set_friend(rogue, false) end)
    pcall(function() rogue.set_friend(source, false) end)
  end
  if game and game.forces then
    for _, other in pairs(game.forces) do
      if other and other.valid and other ~= rogue and force_is_rogue_doctrine_0590(other) then
        pcall(function() other.set_cease_fire(rogue, false) end)
        pcall(function() rogue.set_cease_fire(other, false) end)
        pcall(function() other.set_friend(rogue, false) end)
        pcall(function() rogue.set_friend(other, false) end)
      end
    end
  end
end

local function ensure_rogue_force_0588(force, family)
  if not (game and force and force.valid and family) then return nil end
  local name = "tech-priests-rogue-" .. tostring(family)
  local rogue = game.forces[name]
  if not rogue then
    local ok, created = pcall(function() return game.create_force(name) end)
    if ok then rogue = created end
  end
  if rogue and rogue.valid then
    inherit_force_technology_0590(force, rogue)
    set_rogue_hostility_0590(force, rogue)
  end
  return rogue
end

local SCHISM_SEIZABLE_TYPES_0589 = {
  ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true, ["lab"] = true,
  ["beacon"] = true, ["boiler"] = true, ["generator"] = true, ["storage-tank"] = true,
  ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true,
  ["electric-pole"] = true, ["inserter"] = true, ["transport-belt"] = true, ["splitter"] = true,
  ["underground-belt"] = true, ["loader"] = true, ["loader-1x1"] = true,
  ["container"] = true, ["logistic-container"] = true, ["pipe"] = true, ["pipe-to-ground"] = true,
  ["reactor"] = true, ["rocket-silo"] = true, ["solar-panel"] = true, ["accumulator"] = true,
  ["pump"] = true, ["offshore-pump"] = true, ["radar"] = true, ["wall"] = true, ["gate"] = true,
  ["programmable-speaker"] = true, ["constant-combinator"] = true, ["arithmetic-combinator"] = true, ["decider-combinator"] = true,
}

local function radius_for_pair_0589(pair)
  local r = tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius)
  if not r and pair and pair.station and pair.station.valid and _G.get_station_operating_radius then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  if not r and _G.refresh_pair_radius and pair then
    local ok, got = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  return math.max(8, math.min(96, tonumber(r) or 32))
end

local function seize_station_radius_assets_0589(force, rogue, pair)
  if not (steal_machines_enabled_0589() and force and force.valid and rogue and rogue.valid and pair and pair.station and pair.station.valid) then return 0 end
  local station = pair.station
  local surface = station.surface
  local radius = radius_for_pair_0589(pair)
  local ents = {}
  local ok = pcall(function()
    ents = surface.find_entities_filtered({ position = station.position, radius = radius, force = force }) or {}
  end)
  if not ok then return 0 end
  local seized = 0
  for _, ent in pairs(ents) do
    if ent and ent.valid and ent.force == force and ent ~= station then
      local typ = ent.type
      if SCHISM_SEIZABLE_TYPES_0589[typ] and not ent.name:find("tech%-priest", 1, false) then
        local changed = pcall(function() ent.force = rogue end)
        if changed then seized = seized + 1 end
      end
    end
  end
  return seized
end


local function majority_surface_for_family_0592(force, family)
  local counts = {}
  local best_surface, best_count = nil, 0
  for _, pair in pairs((storage and storage.tech_priests and storage.tech_priests.pairs_by_station) or {}) do
    if pair and pair.station and pair.station.valid and pair.station.force == force and pair_family(pair) == family then
      local surface = pair.station.surface
      local key = surface and (surface.index or surface.name) or "unknown"
      counts[key] = counts[key] or { surface = surface, count = 0 }
      counts[key].count = counts[key].count + 1
      if counts[key].count > best_count then
        best_count = counts[key].count
        best_surface = surface
      end
    end
  end
  return best_surface, best_count, counts
end

local function set_pair_full_emergency_self_sustainment_0590(pair, family, rogue)
  if not pair then return end
  pair.rogue_doctrine_0588 = true
  pair.rogue_family_0588 = family
  pair.rogue_force_0589 = rogue and rogue.valid and rogue.name or pair.rogue_force_0589
  pair.mode = "rogue-emergency-self-sustainment"
  pair.emergency = true
  pair.emergency_reason = "doctrine-schism-0590"
  pair.emergency_phase = "self-sustainment"
  pair.last_blocker_0590 = nil
  pair.next_resource_expansion_tick_0557 = nil
  pair.next_passive_refresh_tick_0556 = nil
  pair.schism_self_sustainment_since_0590 = game and game.tick or 0
end

local function convert_doctrine_family_to_rogue_0588(force, family, state)
  if not (force and force.valid and family) then return 0 end
  state = state or get_force_state(force)
  if doctrine_is_hard_loyal_0591(family) then
    state.loyalty = state.loyalty or {}
    state.loyalty[family] = 100
    remember_doctrine_event_0588(state, family_label(family) .. " is internally hard-loyal; schism threshold ignored and loyalty reset to baseline.")
    return 0
  end
  if not rebellions_enabled_0589() then
    state.loyalty = state.loyalty or {}
    state.loyalty[family] = 100
    remember_doctrine_event_0588(state, family_label(family) .. " reached schism threshold, but doctrine rebellions are disabled; loyalty reset to baseline instead of defecting.")
    return 0
  end
  local web = doctrine_web_root_0588(state)
  local rogue = ensure_rogue_force_0588(force, family)
  if not (rogue and rogue.valid) then return 0 end
  local majority_surface, majority_count = majority_surface_for_family_0592(force, family)
  local surface_name = majority_surface and majority_surface.name or "unknown-surface"
  local changed = 0
  local seized_total = 0
  for _, pair in pairs((storage and storage.tech_priests and storage.tech_priests.pairs_by_station) or {}) do
    if pair and pair.station and pair.station.valid and pair.station.force == force and pair_family(pair) == family and (not majority_surface or pair.station.surface == majority_surface) then
      seized_total = seized_total + seize_station_radius_assets_0589(force, rogue, pair)
      if pair.priest and pair.priest.valid then pcall(function() pair.priest.force = rogue end); changed = changed + 1 end
      if pair.station and pair.station.valid then pcall(function() pair.station.force = rogue end) end
      if pair.proxy_turret and pair.proxy_turret.valid then pcall(function() pair.proxy_turret.force = rogue end) end
      pair.rogue_original_force_0588 = force.name
      pair.schism_surface_0592 = surface_name
      set_pair_full_emergency_self_sustainment_0590(pair, family, rogue)
    end
  end
  web.rogue[family] = { tick = game and game.tick or 0, force = rogue.name, converted = changed, seized = seized_total, surface = surface_name, majority = majority_count }
  web.schism_waves[#web.schism_waves + 1] = { tick = game and game.tick or 0, family = family, force = rogue.name, converted = changed, seized = seized_total, surface = surface_name, majority = majority_count }
  while #web.schism_waves > 12 do table.remove(web.schism_waves, 1) end
  state.loyalty = state.loyalty or {}
  state.loyalty[family] = 100
  state.emergency_constructed = state.emergency_constructed or {}
  state.emergency_constructed[family] = 0
  remember_doctrine_family_event_0592(state, family, family_label(family) .. " crossed the schism threshold on surface " .. tostring(surface_name) .. "; " .. tostring(changed) .. " existing priests defected to " .. rogue.name .. ". " .. tostring(seized_total) .. " local machines seized. Loyal " .. family_label(family) .. " doctrine resets to baseline for newly placed priests.", 0)
  return changed
end

local function apply_opposed_research_pressure_0588(force, state, researched_family, research_name)
  if not (force and force.valid and researched_family) then return end
  state.loyalty = state.loyalty or {}
  local seed = force_seed(force) + hash_string(tostring(research_name or "") .. ":" .. tostring(game and game.tick or 0), 588)
  for _, fam in pairs(FAMILIES) do
    local key = fam.key
    if key ~= researched_family and not doctrine_is_hard_loyal_0591(key) and (DOCTRINE_ENEMIES_0588[key] or {})[researched_family] then
      -- Small deterministic-per-event chance.  It is deliberately low so the web
      -- adds politics without becoming a constant punishment machine.
      local h = hash_string(key .. ":hates:" .. researched_family, seed)
      if (h % 100) < 8 then
        state.loyalty[key] = math.max(0, (state.loyalty[key] or 100) - 1)
        remember_doctrine_family_event_0592(state, key, family_label(key) .. " loses 1 loyalty: disliked research completed for " .. family_label(researched_family) .. " (" .. tostring(research_name or "?") .. ").", -1)
      end
    end
  end
end

local function appeasement_family_from_technology_name(name)
  local prefix = "tech-priests-doctrine-appeasement-"
  name = tostring(name or "")
  if name:sub(1, #prefix) == prefix then return name:sub(#prefix + 1) end
  return nil
end

local function destroy(player)
  local f = player and player.valid and player.gui.screen[FRAME]
  if f and f.valid then f.destroy() end
end

local function build_gui(player)
  if not (player and player.valid) then return end
  destroy(player)
  local force = player.force
  local state = get_force_state(force)
  local counts, total = doctrine_counts(force)
  local now = game.tick

  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical", caption = {"gui.tech-priests-conclave-title"} })
  frame.auto_center = true
  frame.style.width = 860
  frame.style.height = 620

  local top = frame.add({ type = "flow", direction = "horizontal" })
  top.style.horizontally_stretchable = true
  local status = top.add({ type = "label", name = "tech_priests_conclave_status_0559", caption = green("NOOSPHERIC SYNOD ANCHORS: " .. count_centers(force) .. "  // PRIEST SIGNALS: " .. total .. "  // NEXT CONCLAVE CHIME: " .. fmt_ticks((state.vote_ends_tick or state.next_conclave_tick or now) - now)) })
  status.style.horizontally_stretchable = true
  set_wrap(status, 560)
  top.add({ type = "button", name = OPEN_OVERVIEW, caption = {"gui.tech-priests-conclave-open-overview"} })
  top.add({ type = "button", name = CLOSE, caption = {"gui.tech-priests-conclave-close"} })

  local tabs = frame.add({ type = "tabbed-pane", name = "tech_priests_conclave_tabs_0558" })
  apply_style_0564(tabs, "tech_priests_cogitator_tabbed_pane_0532")
  tabs.style.horizontally_stretchable = true
  tabs.style.vertically_stretchable = true

  local ladder_tab = tabs.add({ type = "tab", caption = {"gui.tech-priests-conclave-doctrine-ladder"} })
  local ladder = tabs.add({ type = "scroll-pane", direction = "vertical" })
  apply_screen_scroll_style_0564(ladder)
  ladder.style.height = 500
  ladder.add({ type = "label", caption = green("DOCTRINAL LADDER // compatible research auguries by school, faith-pressure, and observed factory desire") })
  local table1 = ladder.add({ type = "table", column_count = 5 })
  apply_screen_table_style_0564(table1)
  table1.add({ type = "label", caption = green("Doctrine reliquary") })
  table1.add({ type = "label", caption = green("Vox signatures") })
  table1.add({ type = "label", caption = green("Compatibility runes") })
  table1.add({ type = "label", caption = green("Next sanctioned research") })
  table1.add({ type = "label", caption = green("Seed writ") })
  for _, fam in pairs(FAMILIES) do
    table1.add({ type = "label", caption = green(fam.label) })
    table1.add({ type = "label", caption = green(tostring(counts[fam.key] or 0)) })
    local needles = table.concat(fam.needles, ", ")
    local n = table1.add({ type = "label", caption = green(needles) })
    n.style.single_line = false; n.style.width = 300
    local tech = next_tech_for_family(force, fam.key)
    table1.add({ type = "label", caption = tech and tech.localised_name or green("no sanctioned candidate visible") })
    local basis = tech and ((state.tech_family_basis or {})[tech.name] or "keyword") or "none"
    local b = table1.add({ type = "label", caption = green(basis) })
    b.style.single_line = false; b.style.width = 150
  end
  tabs.add_tab(ladder_tab, ladder)

  local vote_tab = tabs.add({ type = "tab", caption = {"gui.tech-priests-conclave-vote"} })
  local vote = tabs.add({ type = "scroll-pane", direction = "vertical" })
  apply_screen_scroll_style_0564(vote)
  vote.style.height = 500
  local timer_row = vote.add({ type = "flow", name = "tech_priests_conclave_timer_row_0559", direction = "horizontal" })
  local spinner = timer_row.add({ type = "sprite", name = "tech_priests_conclave_timer_spinner_0559", sprite = boot_spinner_sprite_0559(now) })
  pcall(function() spinner.style.width = 56 end)
  pcall(function() spinner.style.height = 56 end)
  local timer_text = timer_row.add({ type = "label", name = "tech_priests_conclave_timer_text_0559", caption = green("CONCLAVE CHRONO-LITANY // phase=" .. tostring(state.phase or "waiting") .. " // threshold=" .. VOTE_THRESHOLD .. "+ priest-signals // remaining=" .. fmt_ticks((state.vote_ends_tick or state.next_conclave_tick or now) - now)) })
  set_wrap(timer_text, 650)
  local table2 = vote.add({ type = "table", column_count = 4 })
  apply_screen_table_style_0564(table2)
  table2.add({ type = "label", caption = green("Doctrine reliquary") })
  table2.add({ type = "label", caption = green("Ballot tally") })
  table2.add({ type = "label", caption = green("High Fabricator writ") })
  table2.add({ type = "label", caption = green("Research omen") })
  for _, fam in pairs(FAMILIES) do
    table2.add({ type = "label", caption = green(fam.label) })
    table2.add({ type = "label", caption = green(tostring((state.votes and state.votes[fam.key]) or 0)) })
    table2.add({ type = "button", name = PLAYER_VOTE_PREFIX .. fam.key, caption = {"gui.tech-priests-conclave-cast-writ"} })
    local tech = next_tech_for_family(force, fam.key)
    table2.add({ type = "label", caption = tech and tech.localised_name or green("no sanctioned candidate visible") })
  end
  tabs.add_tab(vote_tab, vote)


  local web_tab = tabs.add({ type = "tab", caption = {"gui.tech-priests-conclave-doctrine-web"} })
  local webpane = tabs.add({ type = "scroll-pane", direction = "vertical" })
  apply_screen_scroll_style_0564(webpane)
  webpane.style.height = 500
  local webnote = webpane.add({ type = "label", caption = green("DOCTRINE WEB // visible research affinities, current dislikes, and schism risk. Research loved by one family may rarely irritate families that doctrinally oppose it.") })
  set_wrap(webnote, 760)
  local policy = webpane.add({ type = "label", caption = green("SCHISM EDICTS // Rebellions: " .. (rebellions_enabled_0589() and "ENABLED" or "DISABLED") .. " // Don't Touch My Toys: " .. (steal_machines_enabled_0589() and "OFF - defectors may seize local machines" or "ON - player machines remain yours") .. ". Enemy priests/stations are hostile foreign-force assets outside the loyal Conclave. Void Doctrine is hard-loyal. Data Spikes are player-only timed claims: base 90s, -20s per reclamation tier after I, +10s per defender-hardening level.") })
  set_wrap(policy, 760)
  local family_table = webpane.add({ type = "table", column_count = 5 })
  apply_screen_table_style_0564(family_table)
  family_table.add({ type = "label", caption = green("Doctrine") })
  family_table.add({ type = "label", caption = green("Loyalty") })
  family_table.add({ type = "label", caption = green("Dislikes") })
  family_table.add({ type = "label", caption = green("Rogue state") })
  family_table.add({ type = "label", caption = green("Recent influence") })
  local webstate = doctrine_web_root_0588(state)
  for _, fam in pairs(FAMILIES) do
    local dislikes = {}
    for _, k in ipairs(family_dislikes(fam.key)) do dislikes[#dislikes+1] = family_label(k) end
    local rogue = webstate.rogue and webstate.rogue[fam.key]
    family_table.add({ type = "label", caption = green(fam.label) })
    family_table.add({ type = "label", caption = green(tostring((state.loyalty and state.loyalty[fam.key]) or 100) .. "/100") })
    local dlab = family_table.add({ type = "label", caption = green(#dislikes > 0 and table.concat(dislikes, ", ") or "none recorded") })
    set_wrap(dlab, 260)
    family_table.add({ type = "label", caption = green(doctrine_is_hard_loyal_0591(fam.key) and "hard-loyal // no schism" or (rogue and ("ROGUE: " .. tostring(rogue.force or "unknown") .. " @ " .. tostring(rogue.surface or "surface?")) or "loyal force")) })
    local recent = webstate.family_recent and webstate.family_recent[fam.key]
    local rlab = family_table.add({ type = "label", caption = green(recent and tostring(recent.text or "") or "no recent loyalty movement") })
    set_wrap(rlab, 260)
  end
  webpane.add({ type = "label", caption = green("RESEARCH AUGURY // currently available technologies and the doctrine family that will claim credit or provoke dislike rolls.") })
  local tech_table = webpane.add({ type = "table", column_count = 4 })
  apply_screen_table_style_0564(tech_table)
  tech_table.add({ type = "label", caption = green("Research") })
  tech_table.add({ type = "label", caption = green("Favored doctrine") })
  tech_table.add({ type = "label", caption = green("Seed basis") })
  tech_table.add({ type = "label", caption = green("Opposed families") })
  for _, rec in ipairs(known_research_for_web_0588(force, 42)) do
    tech_table.add({ type = "label", caption = rec.tech and rec.tech.localised_name or green(rec.name) })
    tech_table.add({ type = "label", caption = green(family_label(rec.family)) })
    tech_table.add({ type = "label", caption = green(tostring((state.tech_family_basis or {})[rec.name] or "keyword")) })
    local opposed = {}
    for _, fam in pairs(FAMILIES) do if (DOCTRINE_ENEMIES_0588[fam.key] or {})[rec.family] then opposed[#opposed+1] = fam.label end end
    local olab = tech_table.add({ type = "label", caption = green(#opposed > 0 and table.concat(opposed, ", ") or "none") })
    set_wrap(olab, 260)
  end
  if webstate.schism_waves and #webstate.schism_waves > 0 then
    webpane.add({ type = "label", caption = green("RECENT SCHISM WAVES") })
    for i = #webstate.schism_waves, math.max(1, #webstate.schism_waves - 5), -1 do
      local ev = webstate.schism_waves[i]
      local lab = webpane.add({ type = "label", caption = green("tick " .. tostring(ev.tick or "?") .. " // " .. family_label(ev.family) .. " -> " .. tostring(ev.force or "?") .. " @ " .. tostring(ev.surface or "surface?") .. " // priests=" .. tostring(ev.converted or 0) .. " // seized-machines=" .. tostring(ev.seized or 0)) })
      set_wrap(lab, 760)
    end
  end
  if webstate.last_events and #webstate.last_events > 0 then
    webpane.add({ type = "label", caption = green("RECENT DOCTRINAL INCIDENTS") })
    for i = #webstate.last_events, math.max(1, #webstate.last_events - 7), -1 do
      local ev = webstate.last_events[i]
      local lab = webpane.add({ type = "label", caption = green("tick " .. tostring(ev.tick or "?") .. " // " .. tostring(ev.text or "")) })
      set_wrap(lab, 760)
    end
  end
  tabs.add_tab(web_tab, webpane)

  local history_tab = tabs.add({ type = "tab", caption = {"gui.tech-priests-conclave-order-history"} })
  local history = tabs.add({ type = "scroll-pane", direction = "vertical" })
  apply_screen_scroll_style_0564(history)
  history.style.height = 500
  local hnote = history.add({ type = "label", caption = green("SANCTIONED ORDER HISTORY // compact service ledger. The Conclave records completed writs only; authority awakens at 1 / 10 / 100 / 1000 / 10000 completed tasks, maximum five bonus order sockets.") })
  set_wrap(hnote, 760)
  local ledgers = {}
  if _G.tech_priests_0561_sanctioned_order_history and _G.tech_priests_0561_sanctioned_order_history.get_ledgers then
    local ok, out = pcall(_G.tech_priests_0561_sanctioned_order_history.get_ledgers, force)
    if ok and type(out) == "table" then ledgers = out end
  end
  local tableh = history.add({ type = "table", column_count = 6 })
  apply_screen_table_style_0564(tableh)
  tableh.add({ type = "label", caption = green("Rank seal") })
  tableh.add({ type = "label", caption = green("Station") })
  tableh.add({ type = "label", caption = green("Base authority") })
  tableh.add({ type = "label", caption = green("Service total") })
  tableh.add({ type = "label", caption = green("Authority marks") })
  tableh.add({ type = "label", caption = green("Order sockets") })
  for _, l in pairs(ledgers) do
    tableh.add({ type = "label", caption = green(l.rank_label or "Tech-Priest") })
    tableh.add({ type = "label", caption = green(tostring(l.station_unit or "?")) })
    tableh.add({ type = "label", caption = green(tostring(l.base_authority or 1)) })
    tableh.add({ type = "label", caption = green(tostring(l.tasks_total or 0)) })
    tableh.add({ type = "label", caption = green(tostring(l.authority_points or 0) .. "/5") })
    tableh.add({ type = "label", caption = green(tostring(l.authority_rank or l.order_capacity or l.base_authority or 1)) })
  end
  tabs.add_tab(history_tab, history)

  local unrest_tab = tabs.add({ type = "tab", caption = {"gui.tech-priests-conclave-unrest"} })
  local unrest = tabs.add({ type = "scroll-pane", direction = "vertical" })
  apply_screen_scroll_style_0564(unrest)
  unrest.style.height = 500
  local unrest_note = unrest.add({ type = "label", caption = green("UNREST LEDGER // emergency construction beyond fifty rites erodes doctrine loyalty; successful aligned research returns one measure of obedience. At zero loyalty, existing members of that doctrine defect to a named rogue force; newly placed priests remain loyal until they themselves are driven into schism.") })
  set_wrap(unrest_note, 760)
  local table3 = unrest.add({ type = "table", column_count = 4 })
  apply_screen_table_style_0564(table3)
  table3.add({ type = "label", caption = green("Doctrine reliquary") })
  table3.add({ type = "label", caption = green("Loyalty charge") })
  table3.add({ type = "label", caption = green("Emergency fabrications") })
  table3.add({ type = "label", caption = green("Machine-cult mood") })
  for _, fam in pairs(FAMILIES) do
    local loyalty = state.loyalty[fam.key] or 100
    table3.add({ type = "label", caption = green(fam.label) })
    table3.add({ type = "label", caption = green(tostring(loyalty) .. "/100") })
    table3.add({ type = "label", caption = green(tostring((state.emergency_constructed and state.emergency_constructed[fam.key]) or 0)) })
    table3.add({ type = "label", caption = green(loyalty <= 0 and "ROGUE THRESHOLD REACHED" or (loyalty < 25 and "DANGEROUS UNREST" or "obedient within tolerances")) })
  end
  tabs.add_tab(unrest_tab, unrest)
end

local function cast_player_vote(player, family)
  if not (player and player.valid and family) then return end
  local root = ensure()
  local state = get_force_state(player.force)
  if state.phase ~= "voting" then player.print("[Conclave] The ballot cogitator is dormant; no five-minute writ window is open."); return end
  root.player_vote[player.force.name] = root.player_vote[player.force.name] or {}
  if root.player_vote[player.force.name][player.index] then player.print("[Conclave] Your command writ is already etched into this ballot cycle."); return end
  root.player_vote[player.force.name][player.index] = family
  state.votes[family] = (state.votes[family] or 0) + 5
  player.print("[Conclave] High Fabricator writ committed to " .. family_label(family) .. ".")
  build_gui(player)
end

local function start_vote(force)
  local state = get_force_state(force)
  local counts, total = doctrine_counts(force)
  if total < VOTE_THRESHOLD then
    state.next_conclave_tick = game.tick + CYCLE_TICKS
    state.phase = "waiting"
    return
  end
  state.phase = "voting"
  state.vote_ends_tick = game.tick + VOTE_TICKS
  state.votes = {}
  for _, fam in pairs(FAMILIES) do state.votes[fam.key] = 0 end
  for family, n in pairs(counts) do
    state.votes[family] = (state.votes[family] or 0) + n
    if n and n > 0 then
      local h = hash_string(tostring(family) .. ":" .. tostring(game.tick), force_seed(force) + n)
      if (h % 100) < 2 then
        local keys = family_keys()
        local stray = keys[(h % #keys) + 1] or family
        if stray ~= family then state.votes[stray] = (state.votes[stray] or 0) + 1 end
      end
    end
  end
  ensure().player_vote[force.name] = {}
  force.print("[Tech-Priests] Mechanicus Conclave bell tolls. Five minutes remain before the doctrine tally is sealed.")
end

local function finish_vote(force)
  local state = get_force_state(force)
  local winner, best = nil, -1
  for family, votes in pairs(state.votes or {}) do
    if votes > best then winner, best = family, votes end
  end
  winner = winner or "science"
  local tech = next_tech_for_family(force, winner)
  if tech and not force.current_research then
    force.current_research = tech.name
    force.print("[Tech-Priests] Conclave verdict sealed: " .. family_label(winner) .. " claims the research altar for " .. tech.name .. ".")
  else
    force.print("[Tech-Priests] Conclave verdict sealed: " .. family_label(winner) .. " wins, but the research altar was already occupied or no sanctioned candidate was visible.")
  end
  state.phase = "waiting"
  state.vote_ends_tick = nil
  state.next_conclave_tick = game.tick + CYCLE_TICKS
end

local function refresh_open_conclave_guis()
  if not (game and game.connected_players) then return end
  for _, player in pairs(game.connected_players) do
    local frame = player.gui and player.gui.screen and player.gui.screen[FRAME]
    if frame and frame.valid then
      local state = get_force_state(player.force)
      local counts, total = doctrine_counts(player.force)
      local now = game.tick
      local remaining = (state.vote_ends_tick or state.next_conclave_tick or now) - now
      local status = nil
      local timer_spinner = nil
      local timer_text = nil
      pcall(function()
        -- Recursive GUI search is small here and runs only once every refresh tick.
        local function walk(e)
          if not (e and e.valid) then return end
          if e.name == "tech_priests_conclave_status_0559" then status = e end
          if e.name == "tech_priests_conclave_timer_spinner_0559" then timer_spinner = e end
          if e.name == "tech_priests_conclave_timer_text_0559" then timer_text = e end
          if e.children then for _, c in pairs(e.children) do walk(c) end end
        end
        walk(frame)
      end)
      if status and status.valid then
        status.caption = green("NOOSPHERIC SYNOD ANCHORS: " .. count_centers(player.force) .. "  // PRIEST SIGNALS: " .. total .. "  // NEXT CONCLAVE CHIME: " .. fmt_ticks(remaining))
      end
      if timer_spinner and timer_spinner.valid then timer_spinner.sprite = boot_spinner_sprite_0559(now) end
      if timer_text and timer_text.valid then
        timer_text.caption = green("CONCLAVE CHRONO-LITANY // phase=" .. tostring(state.phase or "waiting") .. " // threshold=" .. VOTE_THRESHOLD .. "+ priest-signals // remaining=" .. fmt_ticks(remaining))
      end
    end
  end
end


local function apply_emergency_construction_pressure(force, state)
  if not (_G.tech_priests_0561_sanctioned_order_history and _G.tech_priests_0561_sanctioned_order_history.get_ledgers) then return end
  local ok, ledgers = pcall(_G.tech_priests_0561_sanctioned_order_history.get_ledgers, force)
  if not (ok and type(ledgers) == "table") then return end
  state.emergency_constructed = state.emergency_constructed or {}
  state.emergency_construction_seen_0561 = state.emergency_construction_seen_0561 or {}
  state.loyalty = state.loyalty or {}
  for _, l in pairs(ledgers) do
    local fam = l.family or "sanctification"
    local current = tonumber(l.emergency_constructions or 0) or 0
    local key = tostring(l.priest_key or l.station_unit or "?")
    local seen = tonumber(state.emergency_construction_seen_0561[key]) or 0
    if current > seen then
      local delta = current - seen
      state.emergency_construction_seen_0561[key] = current
      state.emergency_constructed[fam] = (state.emergency_constructed[fam] or 0) + delta
      local excess_before = math.max(0, seen - 50)
      local excess_after = math.max(0, current - 50)
      local penalty = excess_after - excess_before
      if penalty > 0 then
        state.loyalty[fam] = math.max(0, (state.loyalty[fam] or 100) - penalty)
        remember_doctrine_family_event_0592(state, fam, family_label(fam) .. " loses " .. tostring(penalty) .. " loyalty from prolonged emergency construction beyond sanctioned tolerance.", -penalty)
      end
    end
  end
end

local CORE_AMMO_ITEMS_0592 = { "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine", "tech-priests-emergency-ammo" }
local CORE_REPAIR_ITEMS_0592 = { "repair-pack" }
local CORE_CONSECRATION_ITEMS_0592 = { "tech-priests-sacred-machine-oil", "sacred-machine-oil", "tech-priests-machine-maintenance-litany", "machine-maintenance-litany", "tech-priests-ritual-of-machine-appeasement", "ritual-of-machine-appeasement" }

local function entity_has_any_item_0592(ent, items)
  if not (ent and ent.valid) then return false end
  local invs = { defines.inventory.chest, defines.inventory.cargo_wagon, defines.inventory.car_trunk, defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output, defines.inventory.furnace_source, defines.inventory.furnace_result, defines.inventory.fuel }
  for _, inv_id in ipairs(invs) do
    local ok, inv = pcall(function() return ent.get_inventory(inv_id) end)
    if ok and inv and inv.valid then
      for _, item in ipairs(items) do
        local ok_count, count = pcall(function() return inv.get_item_count(item) end)
        if ok_count and (tonumber(count) or 0) > 0 then return true end
      end
    end
  end
  return false
end

local function pair_core_needs_met_0592(pair)
  local station = pair and pair.station
  if not (station and station.valid) then return false end
  return entity_has_any_item_0592(station, CORE_AMMO_ITEMS_0592)
     and entity_has_any_item_0592(station, CORE_REPAIR_ITEMS_0592)
     and entity_has_any_item_0592(station, CORE_CONSECRATION_ITEMS_0592)
end

local function seeded_emergency_exit_delay_0592(pair, force)
  local seed = force_seed(force) + hash_string(tostring(pair and pair.station and pair.station.unit_number or "?") .. ":emergency-exit", 592)
  return 60 * (60 + (seed % (14 * 60 + 1))) -- 1 to 15 minutes
end

local function pair_is_emergency_self_sustainment_0592(pair)
  if not pair then return false end
  if pair.rogue_doctrine_0588 then return false end
  if pair.independent_emergency_operation_0184 and pair.independent_emergency_operation_0184.enabled then return true end
  if pair.emergency or pair.emergency_craft or pair.emergency_reason then return true end
  local mode = tostring(pair.mode or "")
  return mode:find("emergency", 1, true) ~= nil or mode == "independent-emergency-operation"
end

local function service_emergency_standdown_0592(force, state)
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local now = game and game.tick or 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.station and pair.station.valid and pair.station.force == force and pair_is_emergency_self_sustainment_0592(pair) then
      local fam = pair_family(pair)
      if pair_core_needs_met_0592(pair) then
        if not pair.emergency_standdown_due_tick_0592 then
          pair.emergency_standdown_due_tick_0592 = now + seeded_emergency_exit_delay_0592(pair, force)
          remember_doctrine_family_event_0592(state, fam, family_label(fam) .. " station " .. tostring(pair.station.unit_number or "?") .. " reports ammo, repair packs, and appeasement oil stocked; emergency stand-down timer armed.", 0)
        elseif now >= pair.emergency_standdown_due_tick_0592 then
          if pair.independent_emergency_operation_0184 then pair.independent_emergency_operation_0184.enabled = false end
          pair.emergency = false
          pair.emergency_reason = nil
          pair.emergency_phase = nil
          pair.emergency_craft = nil
          pair.last_blocker_0590 = nil
          pair.mode = "returning"
          pair.emergency_standdown_due_tick_0592 = nil
          remember_doctrine_family_event_0592(state, fam, family_label(fam) .. " station " .. tostring(pair.station.unit_number or "?") .. " exits emergency construction posture after stocked stability interval.", 0)
        end
      else
        pair.emergency_standdown_due_tick_0592 = nil
      end
    end
  end
end

local function conclave_tick()
  local root = ensure()
  if not game or not game.forces then return end
  for _, force in pairs(game.forces) do
    if has_center(force) then
      local state = get_force_state(force)
      apply_emergency_construction_pressure(force, state)
      service_emergency_standdown_0592(force, state)
      for _, fam in pairs(FAMILIES) do
        if (state.loyalty[fam.key] or 100) <= 0 then convert_doctrine_family_to_rogue_0588(force, fam.key, state) end
      end
      if state.phase == "voting" then
        -- Slow visible vote accumulation: every 10 seconds one doctrine column
        -- receives an extra vote proportional to its priests. This is purely
        -- governance state, not work creation.
        if game.tick % 600 == 0 then
          local counts = doctrine_counts(force)
          for family, n in pairs(counts) do
            if n > 0 then state.votes[family] = (state.votes[family] or 0) + math.max(1, math.floor(n / 6)) end
          end
        end
        if game.tick >= (state.vote_ends_tick or 0) then finish_vote(force) end
      elseif game.tick >= (state.next_conclave_tick or (game.tick + CYCLE_TICKS)) then
        start_vote(force)
      end
    end
  end
end

local function on_research_finished(event)
  local research = event and event.research
  local force = research and research.force
  if not (force and force.valid and has_center(force)) then return end
  local state = get_force_state(force)
  local fam = appeasement_family_from_technology_name(research.name) or family_for_technology(force, research)
  state.loyalty[fam] = math.min(100, (state.loyalty[fam] or 100) + 1)
  state.last_research_family = fam
  remember_doctrine_family_event_0592(state, fam, family_label(fam) .. " gains 1 loyalty from completed research " .. tostring(research.name or "?") .. ".", 1)
  apply_opposed_research_pressure_0588(force, state, fam, research.name)
  for _, f in pairs(FAMILIES) do
    if (state.loyalty[f.key] or 100) <= 0 then convert_doctrine_family_to_rogue_0588(force, f.key, state) end
  end
  -- Successful research is a pressure relief valve: all families are allowed to
  -- stand down from emergency posture without this module directly touching pair
  -- movement or construction state.
  state.last_research_tick = game.tick
end


local function pair_for_entity_0590(ent)
  if not (ent and ent.valid and storage and storage.tech_priests) then return nil end
  local tp = storage.tech_priests
  if ent.unit_number then
    return (tp.pairs_by_station and tp.pairs_by_station[ent.unit_number])
        or (tp.pairs_by_priest and tp.pairs_by_priest[ent.unit_number])
        or nil
  end
  for _, pair in pairs(tp.pairs_by_station or {}) do
    if pair and ((pair.station and pair.station.valid and pair.station == ent)
      or (pair.priest and pair.priest.valid and pair.priest == ent)
      or (pair.proxy_turret and pair.proxy_turret.valid and pair.proxy_turret == ent)) then
      return pair
    end
  end
  return nil
end

local function update_pair_maps_after_capture_0590(pair)
  if not (pair and storage and storage.tech_priests) then return end
  local tp = storage.tech_priests
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  if pair.station and pair.station.valid and pair.station.unit_number then tp.pairs_by_station[pair.station.unit_number] = pair end
  if pair.priest and pair.priest.valid and pair.priest.unit_number then tp.pairs_by_priest[pair.priest.unit_number] = pair end
end

local function capture_pair_with_data_spike_0590(pair, new_force)
  if not (pair and new_force and new_force.valid) then return 0 end
  local captured = 0
  if pair.station and pair.station.valid and pair.station.force ~= new_force then pcall(function() pair.station.force = new_force end); captured = captured + 1 end
  if pair.priest and pair.priest.valid and pair.priest.force ~= new_force then pcall(function() pair.priest.force = new_force end); captured = captured + 1 end
  if pair.proxy_turret and pair.proxy_turret.valid and pair.proxy_turret.force ~= new_force then pcall(function() pair.proxy_turret.force = new_force end); captured = captured + 1 end
  pair.rogue_doctrine_0588 = nil
  pair.rogue_original_force_0588 = nil
  pair.rogue_family_0588 = nil
  pair.rogue_force_0589 = nil
  pair.mode = "returning"
  pair.emergency = false
  pair.emergency_reason = nil
  pair.emergency_phase = nil
  pair.data_spike_reclaimed_tick_0590 = game and game.tick or 0
  update_pair_maps_after_capture_0590(pair)
  return captured
end

local DATA_SPIKE_RECLAIMABLE_TYPES_0590 = {
  ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true, ["lab"] = true,
  ["beacon"] = true, ["boiler"] = true, ["generator"] = true, ["storage-tank"] = true,
  ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true,
  ["electric-pole"] = true, ["inserter"] = true, ["transport-belt"] = true, ["splitter"] = true,
  ["underground-belt"] = true, ["loader"] = true, ["loader-1x1"] = true,
  ["container"] = true, ["logistic-container"] = true, ["pipe"] = true, ["pipe-to-ground"] = true,
  ["reactor"] = true, ["rocket-silo"] = true, ["solar-panel"] = true, ["accumulator"] = true,
  ["pump"] = true, ["offshore-pump"] = true, ["radar"] = true, ["wall"] = true, ["gate"] = true,
  ["programmable-speaker"] = true, ["constant-combinator"] = true, ["arithmetic-combinator"] = true, ["decider-combinator"] = true,
}

local function nearest_reclaimable_target_0590(surface, pos, source_force)
  if not (surface and pos and source_force and source_force.valid) then return nil end
  local ents = surface.find_entities_filtered({ position = pos, radius = 2.5 }) or {}
  for _, ent in pairs(ents) do
    if ent and ent.valid and ent.force ~= source_force then
      if pair_for_entity_0590(ent) or DATA_SPIKE_RECLAIMABLE_TYPES_0590[ent.type] then return ent end
    end
  end
  return nil
end

local function data_spike_source_force_0590(event)
  local src = event and event.source_entity
  if src and src.valid and src.force and src.force.valid then return src.force end
  if event and event.source_player_index and game then
    local player = game.get_player(event.source_player_index)
    if player and player.valid and player.force and player.force.valid then return player.force end
  end
  return nil
end


local function data_spike_reclamation_level_0591(force)
  if not (force and force.valid and force.technologies) then return 0 end
  local level = 0
  for i = 1, 4 do
    local tech = force.technologies["tech-priests-data-spike-reclamation-" .. i]
    if tech and tech.researched then level = i end
  end
  return level
end

local function data_spike_defense_level_0591(force)
  if not (force and force.valid and force.technologies) then return 0 end
  local tech = force.technologies["tech-priests-data-spike-defense"]
  if not tech then return 0 end
  if tech.researched and tonumber(tech.level) then return math.max(1, tonumber(tech.level) or 1) end
  return 0
end

local function data_spike_capture_seconds_0591(attacker, defender)
  local base = 90
  local atk = data_spike_reclamation_level_0591(attacker)
  local def = data_spike_defense_level_0591(defender)
  local reduction = math.max(0, atk - 1) * 20
  local hardening = math.max(0, def) * 10
  return math.max(30, base - reduction + hardening)
end

local function data_spike_pending_root_0591()
  local root = ensure()
  root.data_spike_pending_0591 = root.data_spike_pending_0591 or {}
  return root.data_spike_pending_0591
end

local function data_spike_key_0591(entity)
  if not (entity and entity.valid) then return nil end
  return tostring(entity.surface and entity.surface.index or 0) .. ":" .. tostring(entity.unit_number or (entity.name .. ":" .. math.floor(entity.position.x*32) .. ":" .. math.floor(entity.position.y*32)))
end

local function destroy_render_object_0591(obj)
  if obj then pcall(function() if obj.valid == nil or obj.valid then obj.destroy() end end) end
end

local function data_spike_cancel_for_entity_0591(entity, reason)
  local key = data_spike_key_0591(entity)
  if not key then return end
  local pending = data_spike_pending_root_0591()
  local old = pending[key]
  if old then
    destroy_render_object_0591(old.render_id)
    pending[key] = nil
  end
end

local function data_spike_draw_countdown_0591(target, seconds, force_name)
  if not (target and target.valid and rendering and rendering.draw_text) then return nil end
  local text = "DATA-SPIKE CLAIM // " .. tostring(math.max(0, math.ceil(seconds or 0))) .. "s // " .. tostring(force_name or "unknown")
  local ok, obj = pcall(function()
    return rendering.draw_text({
      text = text,
      surface = target.surface,
      target = { entity = target, offset = { 0, -1.35 } },
      color = { r = 0.15, g = 1.0, b = 0.25, a = 0.95 },
      scale = 0.78,
      alignment = "center",
      time_to_live = 75
    })
  end)
  if ok then return obj end
  return nil
end

local function start_data_spike_claim_0591(source_force, target, source_player_index)
  if not (source_force and source_force.valid and target and target.valid and target.force and target.force.valid and target.force ~= source_force) then return false end
  if not (pair_for_entity_0590(target) or DATA_SPIKE_RECLAIMABLE_TYPES_0590[target.type]) then return false end
  if data_spike_reclamation_level_0591(source_force) < 1 then return false end
  local key = data_spike_key_0591(target)
  if not key then return false end
  local pending = data_spike_pending_root_0591()
  local old = pending[key]
  if old then destroy_render_object_0591(old.render_id) end
  local seconds = data_spike_capture_seconds_0591(source_force, target.force)
  pending[key] = {
    key = key,
    target = target,
    target_unit_number = target.unit_number,
    target_name = target.name,
    target_force_name = target.force.name,
    source_force_name = source_force.name,
    source_player_index = source_player_index,
    started_tick = game and game.tick or 0,
    ends_tick = (game and game.tick or 0) + seconds * 60,
    last_render_second = -1,
    render_id = data_spike_draw_countdown_0591(target, seconds, source_force.name)
  }
  local state = get_force_state(source_force)
  remember_doctrine_event_0588(state, "Data Spike latched onto " .. tostring(target.localised_name or target.name or "entity") .. "; noospheric claim matures in " .. tostring(seconds) .. " seconds unless counter-spiked or removed.")
  return true
end

local function complete_data_spike_capture_0591(entry)
  if not entry then return false end
  local source_force = game and game.forces and game.forces[entry.source_force_name]
  local target = entry.target
  if not (source_force and source_force.valid and target and target.valid and target.force and target.force.valid and target.force ~= source_force) then return false end
  local pair = pair_for_entity_0590(target)
  local captured = 0
  if pair then
    captured = capture_pair_with_data_spike_0590(pair, source_force)
  elseif DATA_SPIKE_RECLAIMABLE_TYPES_0590[target.type] then
    local ok = pcall(function() target.force = source_force end)
    if ok then captured = 1 end
  end
  if captured > 0 then
    local state = get_force_state(source_force)
    remember_doctrine_event_0588(state, "Data Spike claim matured; reclaimed " .. tostring(target.localised_name or target.name or "entity") .. " for " .. tostring(source_force.name) .. ".")
    return true
  end
  return false
end

local function tick_data_spike_claims_0591()
  local pending = data_spike_pending_root_0591()
  local now = game and game.tick or 0
  local processed = 0
  for key, entry in pairs(pending) do
    processed = processed + 1
    if processed > 24 then break end
    local target = entry.target
    if not (target and target.valid) then
      destroy_render_object_0591(entry.render_id)
      pending[key] = nil
    elseif target.force and target.force.valid and target.force.name ~= entry.target_force_name and target.force.name ~= entry.source_force_name then
      -- Ownership changed by a third party; the old spike no longer has a coherent target.
      destroy_render_object_0591(entry.render_id)
      pending[key] = nil
    elseif now >= (entry.ends_tick or now) then
      destroy_render_object_0591(entry.render_id)
      complete_data_spike_capture_0591(entry)
      pending[key] = nil
    else
      local remaining = math.max(0, math.ceil(((entry.ends_tick or now) - now) / 60))
      if remaining ~= entry.last_render_second then
        destroy_render_object_0591(entry.render_id)
        entry.render_id = data_spike_draw_countdown_0591(target, remaining, entry.source_force_name)
        entry.last_render_second = remaining
      end
    end
  end
end

local function apply_data_spike_impact_0590(event)
  if not (event and event.effect_id == "tech-priests-data-spike-impact") then return end
  -- Data Spikes are explicitly player-only. Script/AI projectile impacts are ignored.
  if not event.source_player_index then return end
  local player = game and game.get_player(event.source_player_index)
  if not (player and player.valid and player.force and player.force.valid) then return end
  local source_force = player.force
  local target = event.target_entity
  if not (target and target.valid) then
    local surface = (event.surface_index and game and game.surfaces[event.surface_index]) or (event.source_entity and event.source_entity.valid and event.source_entity.surface)
    target = nearest_reclaimable_target_0590(surface, event.target_position or event.source_position, source_force)
  end
  if not (target and target.valid and target.force and target.force.valid and target.force ~= source_force) then return end
  start_data_spike_claim_0591(source_force, target, event.source_player_index)
end

function M.install()
  if script and defines and defines.events and TechPriestsRuntimeEventRegistry then
    TechPriestsRuntimeEventRegistry.on_event({ defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built, defines.events.script_raised_revive }, function(event)
      register_center(event.entity or event.created_entity or event.destination)
    end)
    TechPriestsRuntimeEventRegistry.on_event({ defines.events.on_entity_died, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.script_raised_destroy }, function(event)
      unregister_center(event.entity)
      data_spike_cancel_for_entity_0591(event.entity, "removed")
    end)
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_opened, function(event)
      local player = game.get_player(event.player_index)
      local entity = event.entity
      if player and entity and entity.valid and entity.name == ENTITY then
        player.opened = nil
        build_gui(player)
      end
    end)
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_finished, on_research_finished)
    if TechPriestsRuntimeEventRegistry.on_nth_tick then
      TechPriestsRuntimeEventRegistry.on_nth_tick(607, conclave_tick, { owner = "conclave_center_0558", category = "governance" })
      TechPriestsRuntimeEventRegistry.on_nth_tick(60, tick_data_spike_claims_0591, { owner = "conclave_center_0591", category = "governance" })
      TechPriestsRuntimeEventRegistry.on_nth_tick(30, refresh_open_conclave_guis, { owner = "conclave_center_0559", category = "gui" })
    end
  end

  if TechPriestsGuiRouter then
    TechPriestsGuiRouter.register("click", function(event)
      local element = event.element
      if not (element and element.valid) then return end
      local name = element.name or ""
      local player = game.get_player(event.player_index)
      if not (player and player.valid) then return end
      if name == CLOSE then destroy(player); return end
      if name == OPEN_OVERVIEW then
        destroy(player)
        if tech_priests_build_command_overview_0189 then tech_priests_build_command_overview_0189(player) end
        return
      end
      if name:sub(1, #PLAYER_VOTE_PREFIX) == PLAYER_VOTE_PREFIX then
        cast_player_vote(player, name:sub(#PLAYER_VOTE_PREFIX + 1))
        return
      end
    end)
  end

  -- Gate the existing remote hotkey without deleting it. The physical console
  -- opens the panel directly; Shift+Y becomes a remote convenience after at
  -- least one center exists for the force.
  if tech_priests_toggle_command_overview_0189 and not _G.tech_priests_toggle_command_overview_0558_wrapped then
    local previous = tech_priests_toggle_command_overview_0189
    _G.tech_priests_toggle_command_overview_0558_wrapped = true
    function tech_priests_toggle_command_overview_0189(player)
      if not (player and player.valid) then return end
      if not has_center(player.force) then
        player.print("[Tech-Priests] Remote command lattice denied. Place a Conclave Center before invoking Shift+Y from afar.")
        return
      end
      return previous(player)
    end
  end

  if commands then
    pcall(function() commands.remove_command("tp-conclave-0558") end)
    commands.add_command("tp-conclave-0558", "Open/report the Tech-Priests Conclave Center doctrine scaffold.", function(cmd)
      local player = cmd.player_index and game.get_player(cmd.player_index) or nil
      if player then build_gui(player) end
    end)
  end

  _G.tech_priests_conclave_0588_family_for_technology = family_for_technology
  _G.tech_priests_conclave_0588_family_label = family_label
  _G.tech_priests_conclave_0588_doctrine_dislikes = family_dislikes
  _G.tech_priests_conclave_0588_ensure_rogue_force = ensure_rogue_force_0588
  _G.tech_priests_conclave_0589_rebellions_enabled = rebellions_enabled_0589
  _G.tech_priests_conclave_0589_steal_machines_enabled = steal_machines_enabled_0589
  _G.tech_priests_conclave_0590_apply_data_spike = apply_data_spike_impact_0590
  _G.tech_priests_conclave_0590_inherit_force_technology = inherit_force_technology_0590
  _G.tech_priests_conclave_0592_doctrine_relation_rows = doctrine_relation_rows_0592
  if TechPriestsRuntimeEventRegistry and defines and defines.events and defines.events.on_script_trigger_effect then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_script_trigger_effect, apply_data_spike_impact_0590)
  elseif script and defines and defines.events and defines.events.on_script_trigger_effect then
    script.on_event(defines.events.on_script_trigger_effect, apply_data_spike_impact_0590)
  end
  if commands then
    pcall(function() commands.remove_command("tp-schism-0590") end)
    commands.add_command("tp-schism-0590", "Tech Priests: report Conclave schism/data-spike governance status.", function(cmd)
      local player = cmd.player_index and game.get_player(cmd.player_index) or nil
      if not player then return end
      local state = get_force_state(player.force)
      local web = doctrine_web_root_0588(state)
      player.print("[tp-schism-0590] rebellions=" .. tostring(rebellions_enabled_0589()) .. " seize-machines=" .. tostring(steal_machines_enabled_0589()) .. " schism-waves=" .. tostring(#(web.schism_waves or {})))
    end)
  end
  if log then log("[Tech-Priests 0.1.592] surface-scoped schisms, stocked emergency stand-down timers, and doctrine relation memory loaded") end
end

return M
